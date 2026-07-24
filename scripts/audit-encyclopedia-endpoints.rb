#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "optparse"
require "pathname"
require "psych"
require "securerandom"
require "tmpdir"
require "tempfile"
require "thread"
require "timeout"
require "time"

require File.expand_path("../verification/lib/cache_policy", __dir__)
require File.expand_path("../verification/lib/machine_report_schema", __dir__)

module EncyclopediaEndpointAudit
  ROLE_ROOTS = {
    "example" => "examples",
    "exercise" => "exercises",
    "lab" => "labs",
    "private-solution" => "solutions-private"
  }.freeze
  GREEN_ROLES = %w[example lab private-solution].freeze
  REPEAT_ROLES = %w[example exercise lab].freeze
  EXPECTED_CHAPTERS = 255
  CHAPTER_ID = /\Ach\.[a-z0-9]+(?:-[a-z0-9]+)*\.[a-z0-9]+(?:-[a-z0-9]+)*\z/
  GENERATED_NAMES = %w[
    .dart_tool .verify.log .venv __pycache__ build build-evidence coverage dist node_modules target
  ].freeze
  DART_SERVER_SCRATCH_ROOT = "home/.dartServer"

  class AuditError < StandardError; end

  # The pnpm store and the pnpm CLI are separate replay inputs. Corepack can
  # otherwise download or switch the package manager before pnpm's own
  # `--offline` policy takes effect, so the endpoint audit requires a
  # pre-seeded runtime root as well as a fixed package store.
  class PnpmRuntimePolicy
    POLICY_ID = "explicit-preseeded-corepack-runtime-v1"
    VARIABLE = "FACTORYCARE_PNPM_RUNTIME_ROOT"

    attr_reader :root, :runtime_root, :bin_directory, :corepack_home, :versions

    def self.resolve(root:, env: ENV)
      configured = env[VARIABLE].to_s
      if configured.empty?
        raise AuditError, "required pre-seeded pnpm runtime is not configured; set #{VARIABLE}"
      end

      new(root: root, configured: configured)
    end

    def initialize(root:, configured:)
      @root = File.realpath(root)
      @runtime_root = validate_runtime_root!(configured)
      @bin_directory = File.join(runtime_root, "bin")
      @corepack_home = File.join(runtime_root, "corepack")
      @pnpm_entry = File.join(bin_directory, "pnpm")
      unless File.file?(@pnpm_entry) && !File.symlink?(@pnpm_entry) && File.executable?(@pnpm_entry)
        raise AuditError, "pre-seeded pnpm runtime must contain executable bin/pnpm"
      end
      unless File.directory?(corepack_home) && !File.symlink?(corepack_home)
        raise AuditError, "pre-seeded pnpm runtime must contain a real corepack directory"
      end
      @versions = Dir.glob(File.join(corepack_home, "v1/pnpm/*")).select do |path|
        File.directory?(path) && !File.symlink?(path)
      end.map { |path| File.basename(path) }.sort.freeze
      raise AuditError, "pre-seeded pnpm runtime contains no pnpm CLI releases" if versions.empty?
      @cli_file_count, @cli_tree_sha256 = cli_tree_identity
    end

    def apply(environment)
      environment.merge(
        "COREPACK_HOME" => corepack_home,
        "COREPACK_ENABLE_NETWORK" => "0",
        "PATH" => ([bin_directory] + environment.fetch("PATH", "").split(File::PATH_SEPARATOR)).uniq.join(File::PATH_SEPARATOR)
      )
    end

    def evidence_summary
      version_bytes = versions.join("\0")
      {
        "policy" => POLICY_ID,
        "network_mode" => "preseeded-corepack-cli-no-runtime-download-intended",
        "location_sha256" => Digest::SHA256.hexdigest(runtime_root.b),
        "pnpm_entry_sha256" => Digest::SHA256.file(@pnpm_entry).hexdigest,
        "cli_file_count" => @cli_file_count,
        "cli_tree_sha256" => @cli_tree_sha256,
        "available_versions" => versions,
        "available_version_set_sha256" => Digest::SHA256.hexdigest(version_bytes)
      }
    end

    private

    def validate_runtime_root!(configured)
      value = configured.to_s
      if value.match?(/[\x00-\x20]/)
        raise AuditError, "pnpm runtime path contains unsupported characters"
      end
      unless Pathname(value).absolute?
        raise AuditError, "pnpm runtime path must be absolute"
      end

      reject_symlink_components!(value)
      real = File.realpath(value)
      unless File.directory?(real) && File.readable?(real)
        raise AuditError, "pnpm runtime path must be a readable directory"
      end
      if real == root || real.start_with?(root + File::SEPARATOR)
        raise AuditError, "pnpm runtime path must be outside the repository"
      end
      real
    rescue Errno::ENOENT
      raise AuditError, "pnpm runtime path does not exist"
    end

    def reject_symlink_components!(value)
      cursor = File::SEPARATOR
      Pathname(value).each_filename do |component|
        cursor = File.join(cursor, component)
        break unless File.exist?(cursor) || File.symlink?(cursor)

        raise AuditError, "pnpm runtime path contains a symbolic link" if File.lstat(cursor).symlink?
      end
    end

    def cli_tree_identity
      digest = Digest::SHA256.new
      files = %w[bin corepack].flat_map do |directory|
        Dir.glob(File.join(runtime_root, directory, "**", "*"), File::FNM_DOTMATCH)
      end.sort
      count = 0
      files.each do |absolute|
        relative = absolute.delete_prefix(runtime_root + File::SEPARATOR)
        next if relative.empty? || relative.split(File::SEPARATOR).any? { |part| part == "." || part == ".." }

        stat = File.lstat(absolute)
        next if stat.directory?
        unless stat.file? && !stat.symlink?
          raise AuditError, "pre-seeded pnpm CLI tree contains a symbolic link or special entry"
        end
        bytes = File.binread(absolute)
        digest << relative << "\0" << format("%04o", stat.mode & 0o777) << "\0"
        digest << Digest::SHA256.hexdigest(bytes) << "\0" << bytes.bytesize.to_s << "\0"
        count += 1
      end
      [count, digest.hexdigest]
    end
  end

  # Docker Desktop installs Compose as a CLI plugin below the application
  # bundle. A deliberately empty HOME cannot discover the user's symlinks in
  # ~/.docker/cli-plugins, so the audit accepts one explicit, hashed plugin and
  # copies only that verified binary into a private plugin directory and writes
  # a credential-free config into each fresh HOME that needs Compose.
  class DockerComposeRuntimePolicy
    POLICY_ID = "explicit-hashed-compose-plugin-with-credential-free-config-v1"
    VARIABLE = "FACTORYCARE_DOCKER_COMPOSE_PLUGIN"

    attr_reader :root, :plugin, :plugin_sha256, :plugin_size_bytes

    def self.resolve(root:, env: ENV)
      configured = env[VARIABLE].to_s
      if configured.empty?
        raise AuditError, "required Docker Compose plugin is not configured; set #{VARIABLE}"
      end

      new(root: root, configured: configured)
    end

    def initialize(root:, configured:)
      @root = File.realpath(root)
      @plugin = validate_plugin!(configured)
      @plugin_sha256, @plugin_size_bytes = freeze_plugin_identity
    end

    def config_bytes(staged_plugin_directory)
      JSON.generate("cliPluginsExtraDirs" => [staged_plugin_directory]) + "\n"
    end

    def evidence_summary
      {
        "policy" => POLICY_ID,
        "discovery_mode" => "fresh-home-credential-free-config",
        "location_sha256" => Digest::SHA256.hexdigest(plugin.b),
        "plugin_sha256" => plugin_sha256,
        "plugin_size_bytes" => plugin_size_bytes,
        "staged_plugin_sha256" => plugin_sha256
      }
    end

    def copy_verified_plugin_to!(destination)
      flags = File::RDONLY
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      File.open(plugin, flags) do |source|
        stat = source.stat
        unless stat.file? && stat.size == plugin_size_bytes
          raise AuditError, "Docker Compose plugin changed after identity freeze"
        end
        File.open(destination, File::WRONLY | File::CREAT | File::EXCL, 0o700) do |target|
          IO.copy_stream(source, target)
        end
      end
      staged_sha256 = Digest::SHA256.file(destination).hexdigest
      staged_size = File.size(destination)
      unless staged_sha256 == plugin_sha256 && staged_size == plugin_size_bytes
        raise AuditError, "staged Docker Compose plugin does not match frozen identity"
      end
      File.chmod(0o700, destination)
    rescue Errno::ELOOP
      raise AuditError, "Docker Compose plugin became a symbolic link"
    end

    private

    def freeze_plugin_identity
      flags = File::RDONLY
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      digest = Digest::SHA256.new
      size = 0
      File.open(plugin, flags) do |source|
        while (chunk = source.read(1024 * 1024))
          digest << chunk
          size += chunk.bytesize
        end
        stat = source.stat
        unless stat.file? && stat.size == size
          raise AuditError, "Docker Compose plugin changed while freezing identity"
        end
      end
      [digest.hexdigest, size]
    rescue Errno::ELOOP
      raise AuditError, "Docker Compose plugin became a symbolic link"
    end

    def validate_plugin!(configured)
      value = configured.to_s
      raise AuditError, "Docker Compose plugin path contains a null byte" if value.include?("\0")
      raise AuditError, "Docker Compose plugin path must be absolute" unless Pathname(value).absolute?

      reject_symlink_components!(value)
      real = File.realpath(value)
      stat = File.lstat(real)
      unless stat.file? && !stat.symlink? && File.executable?(real)
        raise AuditError, "Docker Compose plugin must be an executable regular file"
      end
      if real == root || real.start_with?(root + File::SEPARATOR)
        raise AuditError, "Docker Compose plugin must be outside the repository"
      end
      real
    rescue Errno::ENOENT
      raise AuditError, "Docker Compose plugin path does not exist"
    end

    def reject_symlink_components!(value)
      cursor = File::SEPARATOR
      Pathname(value).each_filename do |component|
        cursor = File.join(cursor, component)
        break unless File.exist?(cursor) || File.symlink?(cursor)

        raise AuditError, "Docker Compose plugin path contains a symbolic link" if File.lstat(cursor).symlink?
      end
    end
  end

  Endpoint = Struct.new(:chapter_id, :role, :relative_path, :absolute_path, :asset_root, keyword_init: true)

  class Inventory
    attr_reader :root

    def initialize(root)
      @root = File.realpath(root)
    end

    def chapter_ids
      bytes = File.binread(File.join(root, "curriculum/catalog.yml"))
      catalog = Psych.safe_load(bytes.force_encoding(Encoding::UTF_8))
      chapters = catalog.fetch("chapters")
      ids = chapters.map { |chapter| chapter.fetch("id") }
      unless ids.length == EXPECTED_CHAPTERS && ids.uniq.length == ids.length && ids.all? { |id| CHAPTER_ID.match?(id) }
        raise AuditError, "catalog must contain exactly #{EXPECTED_CHAPTERS} unique canonical chapter ids"
      end
      ids.sort
    rescue KeyError, Psych::Exception => e
      raise AuditError, "catalog cannot be read: #{e.message.lines.first.to_s.strip}"
    end

    def endpoints
      ids = chapter_ids
      records = []
      ROLE_ROOTS.each do |role, directory|
        ids.each do |chapter_id|
          chapter_root = File.join(root, directory, "encyclopedia", chapter_id)
          verify = discover_one_verify(chapter_root, directory, chapter_id)
          relative = Pathname.new(verify).relative_path_from(Pathname.new(root)).to_s
          records << Endpoint.new(
            chapter_id: chapter_id,
            role: role,
            relative_path: relative,
            absolute_path: verify,
            asset_root: chapter_root
          )
        end
      end
      records.sort_by { |endpoint| [endpoint.chapter_id, endpoint.role] }
    end

    private

    def discover_one_verify(chapter_root, directory, chapter_id)
      stat = File.lstat(chapter_root)
      if stat.symlink? || !stat.directory?
        raise AuditError, "#{directory}/encyclopedia/#{chapter_id} must be a real directory"
      end
      matches = Dir.glob(File.join(chapter_root, "**", "verify.sh")).sort
      unless matches.length == 1
        raise AuditError, "#{directory}/encyclopedia/#{chapter_id} must contain exactly one verify.sh"
      end
      verify = matches.first
      symlink = Dir.glob(File.join(chapter_root, "**", "*"), File::FNM_DOTMATCH).find do |path|
        ![".", ".."].include?(File.basename(path)) && File.lstat(path).symlink?
      end
      if symlink
        relative = symlink.delete_prefix(root + File::SEPARATOR)
        raise AuditError, "symbolic links are forbidden in endpoint roots: #{relative}"
      end
      verify_stat = File.lstat(verify)
      unless verify_stat.file? && !verify_stat.symlink? && verify_stat.executable?
        raise AuditError, "#{verify.delete_prefix(root + File::SEPARATOR)} must be an executable regular file"
      end
      verify
    rescue Errno::ENOENT
      raise AuditError, "missing asset root #{directory}/encyclopedia/#{chapter_id}"
    end
  end

  class ProcessRunner
    def initialize(timeout_seconds:, environment: {}, termination_grace_seconds: 2,
                   docker_compose_runtime_policy: nil)
      @timeout_seconds = timeout_seconds
      @environment = environment
      @termination_grace_seconds = termination_grace_seconds
      @docker_compose_runtime_policy = docker_compose_runtime_policy
    end

    def call(endpoint)
      staged_container = File.realpath(Dir.mktmpdir("factorycare-endpoint-copy-"))
      staged_root = File.join(staged_container, "repository")
      Dir.mkdir(staged_root, 0o700)
      runtime_home = File.join(staged_container, "home")
      runtime_tmp = File.join(staged_container, "tmp")
      [runtime_home, runtime_tmp].each { |path| Dir.mkdir(path, 0o700) }
      prepare_docker_config!(endpoint, runtime_home)
      staged_relative_path = stage_static_closure!(endpoint, staged_root)
      executable = File.join(staged_root, staged_relative_path)
      execution_directory = File.dirname(executable)
      unless File.file?(executable) && !File.symlink?(executable) && File.executable?(executable)
        raise AuditError, "staged verify entrypoint is missing or unsafe"
      end
      before = snapshot(staged_container)
      stdout_file = Tempfile.new("factorycare-endpoint-stdout")
      stderr_file = Tempfile.new("factorycare-endpoint-stderr")
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      command = ["./#{File.basename(executable)}"]
      execution_environment = @environment.merge(
        "HOME" => runtime_home,
        "TMPDIR" => runtime_tmp,
        "TMP" => runtime_tmp,
        "TEMP" => runtime_tmp
      )
      pid = Process.spawn(
        execution_environment,
        *command,
        chdir: execution_directory,
        out: stdout_file,
        err: stderr_file,
        pgroup: true,
        unsetenv_others: true
      )
      status = wait(pid)
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      stabilize_dart_server_for_snapshot!(runtime_home)
      after = snapshot(staged_container)
      closure_failures, outputs, tool_scratch = output_delta(before, after)
      stdout_file.rewind
      stderr_file.rewind
      {
        "exit_code" => status ? (status.exitstatus || (128 + status.termsig.to_i)) : nil,
        "timed_out" => status.nil?,
        "duration_ms" => (duration * 1000).round,
        "stdout" => stdout_file.read.b,
        "stderr" => stderr_file.read.b,
        "normalization_roots" => [execution_directory, File.dirname(endpoint.absolute_path), staged_root, staged_container].uniq,
        "command" => command,
        "closure_failures" => closure_failures,
        "generated_output_count" => outputs.length,
        "generated_output_set_sha256" => output_set_digest(outputs),
        "generated_output_sha256" => output_digest(outputs),
        "tool_owned_runtime_scratch_count" => tool_scratch.length,
        "tool_owned_runtime_scratch_set_sha256" => output_set_digest(tool_scratch),
        "tool_owned_runtime_scratch_sha256" => output_digest(tool_scratch)
      }
    ensure
      stdout_file.close! if stdout_file
      stderr_file.close! if stderr_file
      if staged_container && File.directory?(staged_container) && !File.symlink?(staged_container)
        FileUtils.rm_rf(staged_container)
      end
    end

    private

    def prepare_docker_config!(endpoint, runtime_home)
      return unless endpoint.chapter_id == "ch.ops.compose-services"
      unless @docker_compose_runtime_policy
        raise AuditError, "Docker Compose endpoint requires an explicit runtime policy"
      end

      config_directory = File.join(runtime_home, ".docker")
      Dir.mkdir(config_directory, 0o700)
      plugin_directory = File.join(config_directory, "cli-plugins")
      Dir.mkdir(plugin_directory, 0o700)
      staged_plugin = File.join(plugin_directory, "docker-compose")
      @docker_compose_runtime_policy.copy_verified_plugin_to!(staged_plugin)
      File.open(File.join(config_directory, "config.json"), File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
        file.write(@docker_compose_runtime_policy.config_bytes(plugin_directory))
      end
    end

    def stabilize_dart_server_for_snapshot!(runtime_home)
      dart_server_root = File.join(runtime_home, ".dartServer")
      return unless File.directory?(dart_server_root) && !File.symlink?(dart_server_root)

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3.0
      previous = nil
      stable_samples = 0
      loop do
        current = snapshot(dart_server_root)
        if current == previous
          stable_samples += 1
          return if stable_samples >= 3
        else
          stable_samples = 0
          previous = current
        end
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.05
      rescue AuditError => e
        raise unless e.message == "generated symbolic link is dangling or cyclic"

        previous = nil
        stable_samples = 0
        sleep 0.05
      end
      raise AuditError, "Dart tool-owned runtime scratch did not become stable enough to snapshot"
    end

    def stage_static_closure!(endpoint, staged_root)
      unless canonical_endpoint?(endpoint)
        destination = File.join(staged_root, "asset")
        copy_clean_tree!(endpoint.asset_root || File.dirname(endpoint.absolute_path), destination)
        return File.join("asset", File.basename(endpoint.absolute_path))
      end

      repository_root = File.expand_path("../../..", endpoint.asset_root)
      roles = %w[example exercise lab]
      roles << "private-solution" if endpoint.role == "private-solution"
      roles.each do |role|
        directory = ROLE_ROOTS.fetch(role)
        source = File.join(repository_root, directory, "encyclopedia", endpoint.chapter_id)
        relative = File.join(directory, "encyclopedia", endpoint.chapter_id)
        destination = File.join(staged_root, relative)
        FileUtils.mkdir_p(File.dirname(destination), mode: 0o755)
        copy_clean_tree!(source, destination)
      end
      endpoint.relative_path
    end

    def canonical_endpoint?(endpoint)
      return false unless ROLE_ROOTS[endpoint.role]

      expected_prefix = File.join(
        ROLE_ROOTS.fetch(endpoint.role), "encyclopedia", endpoint.chapter_id
      ) + File::SEPARATOR
      endpoint.relative_path.start_with?(expected_prefix)
    end

    def wait(pid)
      status = nil
      timed_out = false
      begin
        Timeout.timeout(@timeout_seconds) do
          _waited, status = Process.wait2(pid)
        end
      rescue Timeout::Error
        timed_out = true
        terminate_group(pid)
      ensure
        terminate_group(pid) if process_group_alive?(pid)
        if status.nil?
          begin
            _waited, status = Process.wait2(pid)
          rescue Errno::ECHILD
            status = nil
          end
        end
      end
      timed_out ? nil : status
    end

    def terminate_group(pid)
      signal_group("TERM", pid)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @termination_grace_seconds
      sleep(0.01) while process_group_alive?(pid) && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      signal_group("KILL", pid) if process_group_alive?(pid)
    end

    def signal_group(signal, pid)
      Process.kill(signal, -pid)
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end

    def process_group_alive?(pid)
      Process.kill(0, -pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end

    def copy_clean_tree!(source_root, destination_root)
      source_stat = File.lstat(source_root)
      unless source_stat.directory? && !source_stat.symlink?
        raise AuditError, "asset root must be a real directory"
      end
      Dir.mkdir(destination_root, source_stat.mode & 0o777)
      copy_directory_entries!(source_root, destination_root)
    rescue Errno::ENOENT
      raise AuditError, "asset root is missing"
    end

    def copy_directory_entries!(source, destination)
      Dir.children(source).sort.each do |name|
        source_path = File.join(source, name)
        destination_path = File.join(destination, name)
        stat = File.lstat(source_path)
        if stat.symlink?
          raise AuditError, "symbolic links are forbidden in endpoint inputs"
        elsif GENERATED_NAMES.include?(name)
          next
        elsif stat.directory?
          Dir.mkdir(destination_path, stat.mode & 0o777)
          copy_directory_entries!(source_path, destination_path)
        elsif stat.file?
          flags = File::RDONLY
          flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
          bytes = File.open(source_path, flags, &:read)
          File.open(destination_path, File::WRONLY | File::CREAT | File::EXCL, stat.mode & 0o777) do |file|
            file.binmode
            file.write(bytes)
          end
          File.chmod(stat.mode & 0o777, destination_path)
        else
          raise AuditError, "special filesystem entries are forbidden in endpoint inputs"
        end
      end
    rescue Errno::ELOOP
      raise AuditError, "symbolic links are forbidden in endpoint inputs"
    end

    def snapshot(root)
      entries = {}
      Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH).sort.each do |absolute|
        relative = absolute.delete_prefix(root + File::SEPARATOR)
        next if relative.empty? || relative.split("/").any? { |part| part == "." || part == ".." }

        stat = File.lstat(absolute)
        entries[relative] = if stat.directory?
                              { "kind" => "directory", "mode" => format("%04o", stat.mode & 0o777) }
                            elsif stat.file?
                              bytes = File.binread(absolute)
                              {
                                "kind" => "file",
                                "sha256" => Digest::SHA256.hexdigest(bytes),
                                "size_bytes" => bytes.bytesize,
                                "mode" => format("%04o", stat.mode & 0o777)
                              }
                            elsif stat.symlink?
                              resolved = File.realpath(absolute)
                              unless contained?(resolved, root)
                                raise AuditError, "generated symbolic link escapes the staged asset root"
                              end
                              {
                                "kind" => "symlink",
                                "target_sha256" => Digest::SHA256.hexdigest(File.readlink(absolute))
                              }
                            else
                              raise AuditError, "generated special filesystem entries are forbidden"
                            end
      end
      entries
    rescue Errno::ENOENT, Errno::ELOOP
      raise AuditError, "generated symbolic link is dangling or cyclic"
    end

    def output_delta(before, after)
      failures = []
      before.each do |path, entry|
        failures << "contracted input was modified or deleted" unless after[path] == entry
      end
      additions = (after.keys - before.keys).sort.map { |path| after.fetch(path).merge("path" => path) }
      tool_scratch, outputs = additions.partition { |entry| dart_server_scratch?(entry.fetch("path")) }
      [failures.uniq, outputs, tool_scratch]
    end

    def output_digest(outputs)
      digest = Digest::SHA256.new
      outputs.each do |entry|
        digest << entry.fetch("path") << "\0" << entry.fetch("kind") << "\0"
        digest << entry.fetch("sha256", entry.fetch("target_sha256", "")) << "\0"
        digest << entry.fetch("size_bytes", 0).to_s << "\0"
      end
      digest.hexdigest
    end

    def output_set_digest(outputs)
      digest = Digest::SHA256.new
      outputs.each do |entry|
        digest << entry.fetch("path") << "\0" << entry.fetch("kind") << "\0"
      end
      digest.hexdigest
    end

    def dart_server_scratch?(path)
      path == DART_SERVER_SCRATCH_ROOT || path.start_with?(DART_SERVER_SCRATCH_ROOT + File::SEPARATOR)
    end

    def contained?(candidate, base)
      candidate == base || candidate.start_with?(base + File::SEPARATOR)
    end
  end

  class Auditor
    attr_reader :root, :jobs, :timeout_seconds, :runner, :cache_policy, :pnpm_runtime_policy,
                :docker_compose_runtime_policy, :pnpm_store_inventory, :dart_pub_cache_inventory

    def initialize(root:, jobs:, timeout_seconds:, runner: nil, environment: nil)
      @root = File.realpath(root)
      @jobs = jobs
      @timeout_seconds = timeout_seconds
      @cache_policy = nil
      @pnpm_runtime_policy = nil
      @docker_compose_runtime_policy = nil
      @pnpm_store_inventory = nil
      @dart_pub_cache_inventory = nil
      @runner = if runner
                  runner
                else
                  @cache_policy = Verification::CachePolicy.resolve(
                    root: @root,
                    tool_ids: %w[dart-pub maven pnpm uv]
                  )
                  @pnpm_store_inventory = @cache_policy.pnpm_store_inventory_summary
                  @dart_pub_cache_inventory = @cache_policy.dart_pub_cache_inventory_summary
                  @pnpm_runtime_policy = PnpmRuntimePolicy.resolve(root: @root)
                  @docker_compose_runtime_policy = DockerComposeRuntimePolicy.resolve(root: @root)
                  execution_environment = @pnpm_runtime_policy.apply(environment || self.class.fixed_environment)
                  ProcessRunner.new(
                    timeout_seconds: timeout_seconds,
                    environment: execution_environment.merge(@cache_policy.execution_environment),
                    docker_compose_runtime_policy: @docker_compose_runtime_policy
                  )
                end
    end

    def run(endpoints: nil)
      explicit_subset = !endpoints.nil?
      endpoints ||= Inventory.new(root).endpoints
      unless explicit_subset
        expected_total = EXPECTED_CHAPTERS * ROLE_ROOTS.length
        raise AuditError, "expected #{expected_total} endpoints, found #{endpoints.length}" unless endpoints.length == expected_total
      end

      queue = Queue.new
      endpoints.each { |endpoint| queue << endpoint }
      results = []
      mutex = Mutex.new
      workers = Array.new([jobs, endpoints.length].min) do
        Thread.new do
          loop do
            endpoint = queue.pop(true)
            record = audit(endpoint)
            mutex.synchronize { results << record }
          rescue ThreadError
            break
          rescue StandardError => e
            mutex.synchronize do
              results << failure_record(endpoint, "runner raised #{e.class}: #{e.message.lines.first.to_s.strip}")
            end
          end
        end
      end
      workers.each(&:join)
      build_report(results.sort_by { |record| [record.fetch("chapter_id"), record.fetch("role")] })
    end

    def self.fixed_environment
      home = Dir.home
      java_home = ENV.fetch("FACTORYCARE_JAVA_HOME", "/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home")
      node_bin = newest_node_24_bin(home)
      path_prefixes = [
        ENV["FACTORYCARE_AUDIT_TOOL_BIN"],
        File.join(java_home, "bin"), node_bin,
        File.join(home, "Library/pnpm"), File.join(home, ".local/bin")
      ].compact
      environment = {
        "CI" => "true",
        "JAVA_HOME" => java_home,
        "LANG" => "C.UTF-8",
        "LC_ALL" => "C.UTF-8",
        "NODE_DISABLE_COMPILE_CACHE" => "1",
        "NO_COLOR" => "1",
        "PATH" => (path_prefixes + ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)).uniq.join(File::PATH_SEPARATOR),
        "PYTHONDONTWRITEBYTECODE" => "1",
        "TZ" => "UTC"
      }
      environment
    end

    def self.newest_node_24_bin(home)
      candidates = Dir.glob(File.join(home, ".nvm/versions/node/v24.*/bin"))
      candidates.max_by do |path|
        File.basename(File.dirname(path)).delete_prefix("v").split(".").map(&:to_i)
      end
    end

    private

    def audit(endpoint)
      first = observed_call(endpoint)
      failures = contract_failures(endpoint, first)
      repeat = nil
      if REPEAT_ROLES.include?(endpoint.role)
        repeat = observed_call(endpoint)
        failures.concat(contract_failures(endpoint, repeat))
        unless comparable(first) == comparable(repeat)
          failures << "fresh-copy repeat changed exit code, normalized diagnostics, or output closure"
        end
      end
      summarized(endpoint, first, repeat, failures)
    end

    def observed_call(endpoint)
      runner.call(endpoint)
    rescue StandardError => e
      {
        "attempted" => true,
        "exit_code" => nil,
        "timed_out" => false,
        "stdout" => "".b,
        "stderr" => "".b,
        "normalization_roots" => [],
        "command" => ["./#{File.basename(endpoint.relative_path)}"],
        "closure_failures" => ["runner raised #{e.class}"],
        "generated_output_count" => 0,
        "generated_output_set_sha256" => Digest::SHA256.hexdigest(""),
        "generated_output_sha256" => Digest::SHA256.hexdigest(""),
        "tool_owned_runtime_scratch_count" => 0,
        "tool_owned_runtime_scratch_set_sha256" => Digest::SHA256.hexdigest(""),
        "tool_owned_runtime_scratch_sha256" => Digest::SHA256.hexdigest("")
      }
    end

    def contract_failures(endpoint, result)
      failures = result.fetch("closure_failures", []).dup
      failures << "timed out after #{timeout_seconds}s" if result.fetch("timed_out")
      if endpoint.role == "exercise"
        unless result.fetch("exit_code").is_a?(Integer) && result.fetch("exit_code") != 0
          failures << "expected a stable nonzero exit, got #{result.fetch('exit_code').inspect}"
        end
      elsif !result.fetch("timed_out") && result.fetch("exit_code") != 0
        failures << "expected exit 0, got #{result.fetch('exit_code').inspect}"
      end
      failures
    end

    def comparable(result)
      [
        result.fetch("exit_code"),
        normalized_diagnostic(result.fetch("stdout"), result).lines.sort,
        normalized_diagnostic(result.fetch("stderr"), result).lines.sort,
        result.fetch("closure_failures", []),
        result.fetch("generated_output_count", 0),
        result.fetch("generated_output_set_sha256", Digest::SHA256.hexdigest(""))
      ]
    end

    def normalized_diagnostic(bytes, result)
      text = bytes.dup.force_encoding(Encoding::UTF_8).scrub
      roots = result.fetch("normalization_roots", []).flat_map do |path|
        expanded = File.expand_path(path)
        real = File.realpath(path) rescue expanded
        [expanded, real]
      end.uniq.sort_by { |path| -path.length }
      roots.each { |path| text.gsub!(path, "$ASSET_ROOT") }
      text.gsub!(%r{file://(?:/private)?/var/folders/[^\s:]+/T/+[^/\s:]+}, "file://$TMP")
      text.gsub!(%r{(?:/private)?/var/folders/[^\s:]+/T/+[^/\s:]+}, "$TMP")
      text.gsub!(%r{(?:/private)?/tmp/[A-Za-z0-9._-]+}, "$TMP")
      # Dart prints only the temporary project basename in its analyzer banner,
      # so the full-path substitutions above cannot make clean-copy runs equal.
      # Keep this deliberately scoped to that banner instead of hiding arbitrary
      # filenames elsewhere in a diagnostic.
      text.gsub!(
        /^Analyzing (?:factorycare-(?:exercise-repeat|endpoint-copy)-[^\r\n]+|tmp\.[A-Za-z0-9]+)\.\.\.$/,
        "Analyzing <TEMP_PROJECT>..."
      )
      text.gsub!(/0x[0-9a-f]+/i, "0x<ADDRESS>")
      text.lines.map do |line|
        if line.start_with?("--- ", "+++ ")
          line = line.gsub(/\t\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d+)?(?: [+-]\d{4})?/, "\t<TIMESTAMP>")
        end
        if line.start_with?("PASS inference CPU example:")
          line = line.gsub(/local_sanity_ms=\d+(?:\.\d+)?/, "local_sanity_ms=<DURATION>")
          line = line.gsub(/local_items_per_second=\d+(?:\.\d+)?/, "local_items_per_second=<THROUGHPUT>")
        end
        if line.match?(/^Formatted \d+ files? \(\d+ changed\) in \d+(?:\.\d+)? seconds\.$/)
          line = line.gsub(/\bin \d+(?:\.\d+)? seconds\./, "in <DURATION> seconds.")
        end
        if line.match?(/(?:\bDuration\b|\bStart at\b|\bRan \d+ tests? in\b|\bfailed in\b|\bpassed in\b)/i)
          line = line.gsub(/\b\d{1,2}:\d{2}:\d{2}\b/, "<CLOCK>")
          line = line.gsub(/\b\d+(?:\.\d+)?(?:ms|s)\b/, "<DURATION>")
        end
        plain = line.gsub(/\e\[[0-9;]*m/, "")
        if plain.match?(/^\s*[✓✔] .+\(\d+ tests?\)\s+\d+(?:\.\d+)?ms\s*$/)
          line = line.gsub(/\b\d+(?:\.\d+)?(?=(?:\e\[[0-9;]*m)*ms\b)/, "<DURATION>")
        end
        line
      end.join
    end

    def summarized(endpoint, first, repeat, failures)
      first_expected_red = expected_red_marker?(endpoint, first)
      repeat_expected_red = repeat && expected_red_marker?(endpoint, repeat)
      {
        "chapter_id" => endpoint.chapter_id,
        "role" => endpoint.role,
        "verify_path" => endpoint.relative_path,
        "status" => failures.empty? ? "passed" : "failed",
        "expected_exit_code" => endpoint.role == "exercise" ? "nonzero" : 0,
        "command" => first.fetch("command", ["./#{File.basename(endpoint.relative_path)}"]),
        "expected_red_marker_observed" => !!(first_expected_red && repeat_expected_red),
        "expected_red_marker_first_run" => first_expected_red,
        "expected_red_marker_repeat_run" => repeat_expected_red,
        "first_run" => result_summary(first),
        "repeat_run" => repeat && result_summary(repeat),
        "failures" => failures.uniq,
        "diagnostic_excerpt" => nil
      }
    end

    def expected_red_marker?(endpoint, result)
      endpoint.role == "exercise" &&
        (result.fetch("stdout") + result.fetch("stderr")).include?("EXPECTED_RED".b)
    end

    def failure_record(endpoint, message)
      unavailable = result_summary(
        "attempted" => false,
        "exit_code" => nil,
        "timed_out" => false,
        "stdout" => "".b,
        "stderr" => "".b,
        "normalization_roots" => [],
        "closure_failures" => ["auditor internal failure"],
        "generated_output_count" => 0,
        "generated_output_set_sha256" => Digest::SHA256.hexdigest(""),
        "generated_output_sha256" => Digest::SHA256.hexdigest(""),
        "tool_owned_runtime_scratch_count" => 0,
        "tool_owned_runtime_scratch_set_sha256" => Digest::SHA256.hexdigest(""),
        "tool_owned_runtime_scratch_sha256" => Digest::SHA256.hexdigest("")
      )
      {
        "chapter_id" => endpoint ? endpoint.chapter_id : "unknown",
        "role" => endpoint ? endpoint.role : "unknown",
        "verify_path" => endpoint ? endpoint.relative_path : "unknown",
        "status" => "failed",
        "expected_exit_code" => endpoint && endpoint.role == "exercise" ? "nonzero" : 0,
        "command" => ["./verify.sh"],
        "expected_red_marker_observed" => false,
        "expected_red_marker_first_run" => false,
        "expected_red_marker_repeat_run" => false,
        "first_run" => unavailable,
        "repeat_run" => nil,
        "failures" => [message.sub(/: .*/, "")],
        "diagnostic_excerpt" => nil
      }
    end

    def result_summary(result)
      normalized_stdout = normalized_diagnostic(result.fetch("stdout"), result)
      normalized_stderr = normalized_diagnostic(result.fetch("stderr"), result)
      diagnostic_set = normalized_stdout.lines.sort.join + "\0" + normalized_stderr.lines.sort.join
      {
        "attempted" => result.fetch("attempted", true),
        "exit_code" => result.fetch("exit_code"),
        "timed_out" => result.fetch("timed_out"),
        "stdout_bytes" => result.fetch("stdout").bytesize,
        "stdout_sha256" => Digest::SHA256.hexdigest(result.fetch("stdout")),
        "stderr_bytes" => result.fetch("stderr").bytesize,
        "stderr_sha256" => Digest::SHA256.hexdigest(result.fetch("stderr")),
        "normalized_stdout_sha256" => Digest::SHA256.hexdigest(normalized_stdout.lines.sort.join),
        "normalized_stderr_sha256" => Digest::SHA256.hexdigest(normalized_stderr.lines.sort.join),
        "normalized_diagnostic_set_sha256" => Digest::SHA256.hexdigest(diagnostic_set),
        "generated_output_count" => result.fetch("generated_output_count", 0),
        "generated_output_set_sha256" => result.fetch(
          "generated_output_set_sha256",
          Digest::SHA256.hexdigest("")
        ),
        "generated_output_sha256" => result.fetch(
          "generated_output_sha256",
          Digest::SHA256.hexdigest("")
        ),
        "tool_owned_runtime_scratch_count" => result.fetch("tool_owned_runtime_scratch_count", 0),
        "tool_owned_runtime_scratch_set_sha256" => result.fetch(
          "tool_owned_runtime_scratch_set_sha256",
          Digest::SHA256.hexdigest("")
        ),
        "tool_owned_runtime_scratch_sha256" => result.fetch(
          "tool_owned_runtime_scratch_sha256",
          Digest::SHA256.hexdigest("")
        ),
        "output_closure_status" => result.fetch("closure_failures", []).empty? ? "closed" : "failed"
      }
    end

    def diagnostic_excerpt(result)
      combined = result.fetch("stdout") + result.fetch("stderr")
      combined.force_encoding(Encoding::UTF_8).scrub.lines.first(12).join.byteslice(0, 2000)
    end

    def build_report(results)
      failed = results.reject { |record| record.fetch("status") == "passed" }
      store_inventory = pnpm_store_inventory_record
      dart_inventory = dart_pub_cache_inventory_record
      infrastructure_failures = []
      if cache_policy && !store_inventory.fetch("post_run_matches_pre_run")
        infrastructure_failures << "pnpm package-content/index inventory changed during audit"
      end
      if cache_policy && !dart_inventory.fetch("post_run_matches_pre_run")
        infrastructure_failures << "Dart Pub package-content inventory changed during audit"
      end
      role_counts = ROLE_ROOTS.keys.sort.each_with_object({}) do |role, counts|
        selected = results.select { |record| record.fetch("role") == role }
        counts[role] = {
          "total" => selected.length,
          "passed" => selected.count { |record| record.fetch("status") == "passed" },
          "failed" => selected.count { |record| record.fetch("status") == "failed" }
        }
      end
      {
        "schema_version" => 1,
        "audit_id" => "p9-encyclopedia-endpoints",
        "generated_by" => "scripts/audit-encyclopedia-endpoints.rb",
        "chapter_count" => EXPECTED_CHAPTERS,
        "endpoint_count" => results.length,
        "repeat_policy" => "public roles run twice from independent fresh copies; private solution runs once",
        "expected_red_repeat_policy" => "same exact nonzero exit, normalized diagnostic line multiset, and output-closure digest",
        "execution_copy_policy" => "public runs stage the same chapter's example/exercise/lab roots only; private runs add the same chapter's private root; generated names are excluded",
        "output_closure_policy" => "observes the staged repository, HOME, and TMP trees only; contracted inputs are immutable; escaping symlinks and special files fail; writes to arbitrary absolute paths are neither OS-prevented nor observed; repeat consistency compares semantic generated path/kind sets while retaining per-run exact-byte digests and separately recording exact Dart runtime scratch digests",
        "cache_policy" => cache_policy ? cache_policy.evidence_summary : {
          "policy" => "injected-runner-no-cache-observation",
          "network_mode" => "not-observed",
          "content_identity" => "not-observed",
          "configured" => {}
        },
        "pnpm_runtime_policy" => pnpm_runtime_policy ? pnpm_runtime_policy.evidence_summary : {
          "policy" => "injected-runner-no-runtime-observation",
          "network_mode" => "not-observed",
          "location_sha256" => Digest::SHA256.hexdigest(""),
          "pnpm_entry_sha256" => Digest::SHA256.hexdigest(""),
          "cli_file_count" => 0,
          "cli_tree_sha256" => Digest::SHA256.hexdigest(""),
          "available_versions" => [],
          "available_version_set_sha256" => Digest::SHA256.hexdigest("")
        },
        "docker_compose_runtime_policy" => docker_compose_runtime_policy ? docker_compose_runtime_policy.evidence_summary : {
          "policy" => "injected-runner-no-docker-compose-runtime-observation",
          "discovery_mode" => "not-observed",
          "location_sha256" => Digest::SHA256.hexdigest(""),
          "plugin_sha256" => Digest::SHA256.hexdigest(""),
          "plugin_size_bytes" => 0,
          "staged_plugin_sha256" => Digest::SHA256.hexdigest("")
        },
        "pnpm_store_inventory" => store_inventory,
        "dart_pub_cache_inventory" => dart_inventory,
        "infrastructure_failures" => infrastructure_failures,
        "diagnostic_normalization" => [
          "replace execution and system temporary roots",
          "replace Dart analyzer banners derived from temporary project names",
          "replace duration only in Dart formatter summary lines",
          "replace process-specific hexadecimal object addresses",
          "replace clock and duration fields only on test-summary lines",
          "replace duration only on Vitest per-file result lines",
          "replace timestamps only on unified-diff header lines",
          "replace explicitly non-benchmark PyTorch local sanity timing and throughput fields",
          "compare the resulting diagnostic line multiset"
        ],
        "generated_output_classification" => [
          "validate all staged HOME entries for escaping symlinks and special files before classification",
          "classify only home/.dartServer and its descendants as tool_owned_runtime_scratch",
          "exclude that exact tool-owned prefix from semantic generated output count/set and repeat equality",
          "retain each run's raw scratch count, exact path/kind set digest, and exact path-and-byte digest",
          "a bounded stability wait makes the scratch tree safe to snapshot but does not assert semantic determinism"
        ],
        "passed_count" => results.length - failed.length,
        "failed_count" => failed.length,
        "role_counts" => role_counts,
        "status" => failed.empty? && infrastructure_failures.empty? ? "passed" : "failed",
        "results" => results
      }
    end

    def pnpm_store_inventory_record
      if cache_policy && pnpm_store_inventory
        post_run = cache_policy.pnpm_store_inventory_summary
        return pnpm_store_inventory.merge(
          "snapshot_phase" => "pre-run",
          "post_run_matches_pre_run" => post_run == pnpm_store_inventory
        )
      end

      {
        "policy" => "injected-runner-no-store-observation",
        "content_file_count" => 0,
        "index_file_count" => 0,
        "inventory_sha256" => Digest::SHA256.hexdigest(""),
        "excluded_mutable_scope" => "not-observed",
        "snapshot_phase" => "not-observed",
        "post_run_matches_pre_run" => false
      }
    end

    def dart_pub_cache_inventory_record
      if cache_policy && dart_pub_cache_inventory
        post_run = cache_policy.dart_pub_cache_inventory_summary
        return dart_pub_cache_inventory.merge(
          "snapshot_phase" => "pre-run",
          "post_run_matches_pre_run" => post_run == dart_pub_cache_inventory
        )
      end

      {
        "policy" => "injected-runner-no-dart-pub-cache-observation",
        "included_roots" => [],
        "excluded_mutable_roots" => [],
        "file_count" => 0,
        "directory_count" => 0,
        "inventory_sha256" => Digest::SHA256.hexdigest(""),
        "snapshot_phase" => "not-observed",
        "post_run_matches_pre_run" => false
      }
    end
  end

  module CLI
    module_function

    def run(argv, stdout: $stdout, stderr: $stderr)
      options = {
        root: File.expand_path("..", __dir__),
        jobs: Integer(ENV.fetch("FACTORYCARE_AUDIT_JOBS", "6")),
        timeout_seconds: Integer(ENV.fetch("FACTORYCARE_AUDIT_TIMEOUT", "300")),
        output: nil
      }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: ruby scripts/audit-encyclopedia-endpoints.rb [options]"
        opts.on("--root PATH", "Repository copy to audit") { |value| options[:root] = value }
        opts.on("--jobs N", Integer, "Parallel workers") { |value| options[:jobs] = value }
        opts.on("--timeout SECONDS", Integer, "Per-run timeout") { |value| options[:timeout_seconds] = value }
        opts.on("--output PATH", "Write canonical JSON report") { |value| options[:output] = value }
      end
      parser.parse!(argv)
      raise AuditError, "unexpected positional arguments" unless argv.empty?
      raise AuditError, "jobs must be positive" unless options.fetch(:jobs).positive?
      raise AuditError, "timeout must be positive" unless options.fetch(:timeout_seconds).positive?

      report = Auditor.new(
        root: options.fetch(:root),
        jobs: options.fetch(:jobs),
        timeout_seconds: options.fetch(:timeout_seconds)
      ).run
      Verification::MachineReportSchema.validate!(
        root: options.fetch(:root),
        schema_path: "schemas/encyclopedia-endpoint-audit.schema.json",
        document: report
      )
      bytes = JSON.pretty_generate(canonical(report)) + "\n"
      if options[:output]
        write_atomic(options.fetch(:output), bytes)
        stdout.puts "ENDPOINT AUDIT #{report.fetch('status').upcase}: #{report.fetch('passed_count')}/#{report.fetch('endpoint_count')} passed"
        stdout.puts "report=#{File.expand_path(options.fetch(:output))}"
      else
        stdout.write(bytes)
      end
      report.fetch("status") == "passed" ? 0 : 1
    rescue OptionParser::ParseError, AuditError, Verification::ContractError, Errno::ENOENT => e
      stderr.puts "ENDPOINT AUDIT FAILED: #{e.message.lines.first.to_s.strip}"
      2
    end

    def write_atomic(path, bytes)
      absolute = File.expand_path(path)
      FileUtils.mkdir_p(File.dirname(absolute))
      temporary = "#{absolute}.tmp-#{$$}-#{SecureRandom.hex(6)}"
      File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o644) do |file|
        file.binmode
        file.write(bytes)
        file.flush
        file.fsync
      end
      File.rename(temporary, absolute)
    ensure
      FileUtils.rm_f(temporary) if defined?(temporary) && temporary
    end

    def canonical(value)
      case value
      when Hash
        value.keys.sort.each_with_object({}) { |key, memo| memo[key] = canonical(value.fetch(key)) }
      when Array
        value.map { |item| canonical(item) }
      else
        value
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  exit EncyclopediaEndpointAudit::CLI.run(ARGV)
end
