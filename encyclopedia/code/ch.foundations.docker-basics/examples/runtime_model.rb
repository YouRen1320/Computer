# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"

class DockerModelError < StandardError; end
class ReachabilityError < DockerModelError; end

Image = Struct.new(:name, :layers, :digest)
Volume = Struct.new(:name, :data)
Network = Struct.new(:name)
Container = Struct.new(
  :name, :image_name, :service_port, :publish, :mount, :network,
  :running, :writable, :logs,
  keyword_init: true
)

# An in-process Docker teaching model. It makes storage and network boundaries
# observable without contacting a daemon, registry, or public network.
class DockerRuntimeModel
  OWNED_PREFIX = "fc-basics-"

  attr_reader :images, :containers, :volumes, :networks

  def initialize(allowed_bind_root:)
    @allowed_bind_root = File.expand_path(allowed_bind_root)
    FileUtils.mkdir_p(@allowed_bind_root)
    @images = {}
    @containers = {}
    @volumes = {}
    @networks = {}
  end

  def create_image(name, layers)
    ensure_owned!(name)
    raise DockerModelError, "image already exists: #{name}" if @images.key?(name)

    immutable_layers = Marshal.load(Marshal.dump(layers)).map { |layer| deep_freeze(layer) }.freeze
    digest = Digest::SHA256.hexdigest(JSON.generate(immutable_layers))
    @images[name] = Image.new(name, immutable_layers, digest).freeze
  end

  def create_volume(name)
    ensure_owned!(name)
    raise DockerModelError, "volume already exists: #{name}" if @volumes.key?(name)

    @volumes[name] = Volume.new(name, {})
  end

  def create_network(name)
    ensure_owned!(name)
    raise DockerModelError, "network already exists: #{name}" if @networks.key?(name)

    @networks[name] = Network.new(name)
  end

  def run(name:, image:, service_port: nil, publish: nil, mount: nil, network: nil)
    ensure_owned!(name)
    raise DockerModelError, "container already exists: #{name}" if @containers.key?(name)
    raise DockerModelError, "unknown image: #{image}" unless @images.key?(image)
    validate_publish!(publish, service_port)
    validate_mount!(mount)
    raise DockerModelError, "unknown network: #{network}" if network && !@networks.key?(network)

    container = Container.new(
      name: name,
      image_name: image,
      service_port: service_port,
      publish: publish,
      mount: mount,
      network: network,
      running: true,
      writable: {},
      logs: ["process started"]
    )
    @containers[name] = container
  end

  def write(container_name, path, content)
    container = running_container(container_name)
    normalized = normalize_container_path(path)
    storage, relative = storage_for(container, normalized)
    if storage.is_a?(Hash)
      storage[relative] = content
    else
      host_path = safe_bind_path(storage, relative)
      FileUtils.mkdir_p(File.dirname(host_path))
      File.write(host_path, content)
    end
    container.logs << "write #{normalized}"
  end

  def read(container_name, path)
    container = running_container(container_name)
    normalized = normalize_container_path(path)
    storage, relative = storage_for(container, normalized)
    storage.is_a?(Hash) ? storage[relative] : read_bind(storage, relative)
  end

  def host_request(host_ip, host_port)
    container = @containers.values.find do |candidate|
      candidate.running && candidate.publish &&
        candidate.publish.fetch("host_ip") == host_ip &&
        candidate.publish.fetch("host_port") == host_port &&
        candidate.publish.fetch("container_port") == candidate.service_port
    end
    raise ReachabilityError, "no published service at #{host_ip}:#{host_port}" unless container

    "HTTP 200 from #{container.name}"
  end

  def network_request(from:, target:, port:)
    source = running_container(from)
    destination = running_container(target)
    same_network = source.network && source.network == destination.network
    raise ReachabilityError, "containers do not share a user-defined network" unless same_network
    raise ReachabilityError, "target port is not listening" unless destination.service_port == port

    "HTTP 200 from #{target} via #{source.network} DNS"
  end

  def stop(name)
    container = @containers.fetch(name) { raise DockerModelError, "unknown container: #{name}" }
    container.running = false
    container.logs << "process stopped"
  end

  def remove_container(name)
    ensure_owned!(name)
    container = @containers.fetch(name) { raise DockerModelError, "unknown container: #{name}" }
    raise DockerModelError, "stop container before removal: #{name}" if container.running

    @containers.delete(name)
  end

  def remove_volume(name)
    ensure_owned!(name)
    in_use = @containers.values.any? do |container|
      container.mount && container.mount["type"] == "volume" && container.mount["source"] == name
    end
    raise DockerModelError, "volume still referenced: #{name}" if in_use

    @volumes.delete(name) || raise(DockerModelError, "unknown volume: #{name}")
  end

  def remove_network(name)
    ensure_owned!(name)
    raise DockerModelError, "network still referenced: #{name}" if @containers.values.any? { |container| container.network == name }

    @networks.delete(name) || raise(DockerModelError, "unknown network: #{name}")
  end

  def remove_image(name)
    ensure_owned!(name)
    raise DockerModelError, "image still referenced: #{name}" if @containers.values.any? { |container| container.image_name == name }

    @images.delete(name) || raise(DockerModelError, "unknown image: #{name}")
  end

  def inspect_container(name)
    container = @containers.fetch(name)
    {
      "name" => container.name,
      "image_digest" => @images.fetch(container.image_name).digest,
      "running" => container.running,
      "writable_paths" => container.writable.keys.sort,
      "mount" => container.mount,
      "publish" => container.publish,
      "network" => container.network
    }
  end

  def logs_for(name)
    @containers.fetch(name).logs.dup
  end

  private

  def validate_publish!(publish, service_port)
    return unless publish

    raise DockerModelError, "published service needs a container port" unless service_port
    raise DockerModelError, "teaching lab only binds host loopback" unless publish["host_ip"] == "127.0.0.1"
    ports = [publish["host_port"], publish["container_port"]]
    raise DockerModelError, "ports must be integers in 1..65535" unless ports.all? { |port| port.is_a?(Integer) && port.between?(1, 65_535) }
  end

  def validate_mount!(mount)
    return unless mount

    type = mount.fetch("type")
    source = mount.fetch("source")
    normalize_container_path(mount.fetch("target"))
    case type
    when "volume"
      raise DockerModelError, "unknown volume: #{source}" unless @volumes.key?(source)
    when "bind"
      expanded = File.expand_path(source)
      allowed = expanded == @allowed_bind_root || expanded.start_with?("#{@allowed_bind_root}#{File::SEPARATOR}")
      raise DockerModelError, "bind source is outside the owned temporary root" unless allowed
      FileUtils.mkdir_p(expanded)
    else
      raise DockerModelError, "unsupported mount type: #{type}"
    end
  end

  def storage_for(container, path)
    mount = container.mount
    if mount && mounted_path?(path, mount.fetch("target"))
      relative = relative_to_mount(path, mount.fetch("target"))
      storage = mount.fetch("type") == "volume" ? @volumes.fetch(mount.fetch("source")).data : mount.fetch("source")
      [storage, relative]
    else
      [container.writable, path]
    end
  end

  def mounted_path?(path, target)
    path == target || path.start_with?("#{target}/")
  end

  def relative_to_mount(path, target)
    path.delete_prefix(target).delete_prefix("/")
  end

  def normalize_container_path(path)
    raise DockerModelError, "container path must be absolute" unless path.start_with?("/")
    parts = path.split("/").reject(&:empty?)
    raise DockerModelError, "container path traversal is forbidden" if parts.include?("..")

    "/#{parts.join("/")}"
  end

  def safe_bind_path(source, relative)
    path = File.expand_path(relative, source)
    root = File.expand_path(source)
    allowed = path == root || path.start_with?("#{root}#{File::SEPARATOR}")
    raise DockerModelError, "bind write escaped its source" unless allowed

    path
  end

  def read_bind(source, relative)
    path = safe_bind_path(source, relative)
    File.file?(path) ? File.read(path) : nil
  end

  def running_container(name)
    container = @containers.fetch(name) { raise DockerModelError, "unknown container: #{name}" }
    raise DockerModelError, "container is stopped: #{name}" unless container.running

    container
  end

  def ensure_owned!(name)
    raise DockerModelError, "resource name must start with #{OWNED_PREFIX}" unless name.start_with?(OWNED_PREFIX)
  end

  def deep_freeze(value)
    case value
    when Hash
      value.each { |key, item| deep_freeze(key); deep_freeze(item) }
    when Array
      value.each { |item| deep_freeze(item) }
    end
    value.freeze
  end
end
