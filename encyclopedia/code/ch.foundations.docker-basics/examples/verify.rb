# frozen_string_literal: true

require "tmpdir"
require_relative "runtime_model"

def assert(condition, message)
  raise "ASSERTION FAILED: #{message}" unless condition
end

def expect_error(error_class, message)
  yield
  raise "ASSERTION FAILED: #{message}"
rescue error_class
  true
end

Dir.mktmpdir("fc-docker-model-") do |temporary|
  runtime = DockerRuntimeModel.new(allowed_bind_root: temporary)
  image_name = "fc-basics-image"
  image = runtime.create_image(
    image_name,
    [
      { "instruction" => "FROM local-base@sha256:teaching", "changes" => ["/usr/bin/python3"] },
      { "instruction" => "COPY index.html /srv/factorycare/", "changes" => ["/srv/factorycare/index.html"] }
    ]
  )
  original_image_digest = image.digest

  runtime.run(name: "fc-basics-ephemeral-a", image: image_name)
  runtime.write("fc-basics-ephemeral-a", "/data/state.txt", "temporary")
  assert(runtime.inspect_container("fc-basics-ephemeral-a").fetch("writable_paths") == ["/data/state.txt"], "unmounted write belongs to the container layer")
  runtime.stop("fc-basics-ephemeral-a")
  runtime.remove_container("fc-basics-ephemeral-a")
  runtime.run(name: "fc-basics-ephemeral-b", image: image_name)
  assert(runtime.read("fc-basics-ephemeral-b", "/data/state.txt").nil?, "new container must not inherit another writable layer")
  assert(runtime.images.fetch(image_name).digest == original_image_digest, "container writes must not mutate the image")
  puts "image/container: image digest stable; unmounted data disappeared after container replacement"

  volume_name = "fc-basics-data"
  runtime.create_volume(volume_name)
  correct_mount = { "type" => "volume", "source" => volume_name, "target" => "/data" }
  runtime.run(name: "fc-basics-volume-a", image: image_name, mount: correct_mount)
  runtime.write("fc-basics-volume-a", "/data/work-order.txt", "WO-100")
  runtime.stop("fc-basics-volume-a")
  runtime.remove_container("fc-basics-volume-a")
  runtime.run(name: "fc-basics-volume-b", image: image_name, mount: correct_mount)
  assert(runtime.read("fc-basics-volume-b", "/data/work-order.txt") == "WO-100", "named volume data should outlive a container")
  puts "volume: WO-100 survived stop, remove, and replacement container"

  wrong_mount = { "type" => "volume", "source" => volume_name, "target" => "/wrong" }
  runtime.run(name: "fc-basics-wrong-mount", image: image_name, mount: wrong_mount)
  runtime.write("fc-basics-wrong-mount", "/expected/new.txt", "written-to-container-layer")
  wrong_inspect = runtime.inspect_container("fc-basics-wrong-mount")
  assert(wrong_inspect.fetch("mount").fetch("target") == "/wrong", "inspect should expose the wrong target")
  assert(wrong_inspect.fetch("writable_paths") == ["/expected/new.txt"], "wrong target should leave application data in writable layer")
  puts "mount diagnosis: inspect target=/wrong while application wrote /expected/new.txt in writable layer"

  bind_source = File.join(temporary, "bind-data")
  bind_mount = { "type" => "bind", "source" => bind_source, "target" => "/exchange" }
  runtime.run(name: "fc-basics-bind", image: image_name, mount: bind_mount)
  runtime.write("fc-basics-bind", "/exchange/host-visible.txt", "visible-on-host")
  assert(File.read(File.join(bind_source, "host-visible.txt")) == "visible-on-host", "bind data should be visible at the owned host path")
  expect_error(DockerModelError, "bind mounts outside the owned temporary root must be rejected") do
    runtime.run(
      name: "fc-basics-unsafe-bind",
      image: image_name,
      mount: { "type" => "bind", "source" => "/etc", "target" => "/host" }
    )
  end
  puts "bind: owned temporary path visible; /etc bind rejected"

  network_name = "fc-basics-net"
  other_network = "fc-basics-other-net"
  runtime.create_network(network_name)
  runtime.create_network(other_network)
  runtime.run(name: "fc-basics-api-unpublished", image: image_name, service_port: 8080, network: network_name)
  runtime.run(name: "fc-basics-client", image: image_name, network: network_name)
  runtime.run(name: "fc-basics-outsider", image: image_name, network: other_network)
  expect_error(ReachabilityError, "host access without publish must fail") do
    runtime.host_request("127.0.0.1", 18_080)
  end
  internal = runtime.network_request(from: "fc-basics-client", target: "fc-basics-api-unpublished", port: 8080)
  assert(internal.include?("HTTP 200"), "same user-defined network should resolve the container name")
  expect_error(ReachabilityError, "different networks must remain isolated") do
    runtime.network_request(from: "fc-basics-outsider", target: "fc-basics-api-unpublished", port: 8080)
  end
  puts "network: host without publish failed; same-network DNS passed; other network failed"

  publish = { "host_ip" => "127.0.0.1", "host_port" => 18_080, "container_port" => 8080 }
  runtime.run(name: "fc-basics-api-published", image: image_name, service_port: 8080, publish: publish, network: network_name)
  assert(runtime.host_request("127.0.0.1", 18_080).include?("HTTP 200"), "loopback-published service should be reachable")
  expect_error(DockerModelError, "all-interface publish should be rejected by the safe teaching model") do
    runtime.run(
      name: "fc-basics-public-bind",
      image: image_name,
      service_port: 8080,
      publish: { "host_ip" => "0.0.0.0", "host_port" => 18_081, "container_port" => 8080 }
    )
  end
  puts "port: 127.0.0.1:18080→8080 passed; all-interface publish rejected"

  expect_error(DockerModelError, "cleanup must not accept unrelated resource names") do
    runtime.remove_container("unrelated-container")
  end
  runtime.containers.keys.sort.each do |name|
    runtime.stop(name) if runtime.containers.fetch(name).running
    runtime.remove_container(name)
  end
  runtime.remove_volume(volume_name)
  runtime.remove_network(network_name)
  runtime.remove_network(other_network)
  runtime.remove_image(image_name)
  assert(runtime.containers.empty? && runtime.volumes.empty? && runtime.networks.empty? && runtime.images.empty?, "owned resources should be removed exactly")
  puts "cleanup: exact fc-basics-* resources removed; unrelated name refused; no prune/force"
end

puts "docker-basics offline verification: PASS"
