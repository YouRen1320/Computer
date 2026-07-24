# frozen_string_literal: true

require "pathname"
require "tmpdir"

require_relative "runner"

module Verification
  # Captures exact, replayable tool-version observations without treating a
  # successful probe as human approval of a candidate manifest.
  class ObservedToolProbe
    attr_reader :root, :command_runner, :environment

    def initialize(root:, command_runner: LocalCommandRunner.new, environment: ENV)
      @root = File.realpath(root)
      @command_runner = command_runner
      @environment = environment
    end

    def call(tool_ids)
      Dir.mktmpdir("factorycare-tool-probe-") do |directory|
        home = File.join(directory, "home")
        tmp = File.join(directory, "tmp")
        [home, tmp].each { |path| Dir.mkdir(path, 0o700) }
        tool_ids.uniq.sort.map { |tool_id| probe(tool_id, home, tmp) }
      end
    end

    private

    def probe(tool_id, home, tmp)
      argv = TOOL_VERSION_COMMANDS.fetch(tool_id)
      result = command_runner.call(env: probe_environment(home, tmp), argv: argv, chdir: root)
      combined = normalize_output(result.stdout + result.stderr, home, tmp)
      {
        "id" => tool_id,
        "version_argv" => argv,
        "status" => !result.timed_out && result.exit_code == 0 ? "observed" : "failed",
        "timed_out" => !!result.timed_out,
        "exit_code" => result.exit_code,
        "observed_first_line" => first_nonempty_line(combined),
        "normalized_version_output_sha256" => Canonical.sha256(combined),
        "normalized_version_output_size_bytes" => combined.bytesize,
        "normalization_policy" => "replace probe root, repository root, home root, and system temporary roots"
      }
    rescue KeyError
      raise ContractError.new("tool-probe", "E_TOOL_NOT_ALLOWLISTED", "candidate references a tool outside the fixed probe allowlist", path: tool_id)
    rescue StandardError => e
      {
        "id" => tool_id,
        "version_argv" => TOOL_VERSION_COMMANDS.fetch(tool_id, []),
        "status" => "failed",
        "timed_out" => false,
        "exit_code" => nil,
        "observed_first_line" => "",
        "normalized_version_output_sha256" => Canonical.sha256(""),
        "normalized_version_output_size_bytes" => 0,
        "normalization_policy" => "replace probe root, repository root, home root, and system temporary roots",
        "failure_class" => e.class.name
      }
    end

    def probe_environment(home, tmp)
      result = Runner::FIXED_ENVIRONMENT.merge(
        "HOME" => home,
        "TMPDIR" => tmp,
        "PATH" => sanitized_path,
        "npm_config_manage_package_manager_versions" => "false",
        "pnpm_config_manage_package_manager_versions" => "false"
      )
      result["JAVA_HOME"] = environment.fetch("JAVA_HOME") if environment["JAVA_HOME"] && !environment.fetch("JAVA_HOME").empty?
      result["COREPACK_HOME"] = environment.fetch("COREPACK_HOME") if environment["COREPACK_HOME"] && !environment.fetch("COREPACK_HOME").empty?
      result["COREPACK_ENABLE_NETWORK"] = "0" if result["COREPACK_HOME"]
      result
    end

    def sanitized_path
      @sanitized_path ||= begin
        commands = TOOL_VERSION_COMMANDS.values.map(&:first).uniq
        # Filter in caller order so duplicate tool names resolve exactly as they do on the incoming PATH.
        directories = environment.fetch("PATH", "").to_s.split(File::PATH_SEPARATOR).each_with_object([]) do |directory, memo|
          next if directory.empty? || !Pathname(directory).absolute?
          next unless commands.any? { |command| executable_in_directory?(directory, command) }

          memo << directory unless memo.include?(directory)
        end
        (directories + %w[/usr/bin /bin /usr/sbin /sbin]).uniq.join(File::PATH_SEPARATOR)
      end
    end

    def executable_in_directory?(directory, command)
      candidate = File.join(directory, command)
      File.file?(candidate) && File.executable?(candidate)
    end

    def first_nonempty_line(bytes)
      bytes.dup.force_encoding(Encoding::UTF_8).scrub.lines.map(&:strip).find { |line| !line.empty? }.to_s
    end

    def normalize_output(bytes, home, tmp)
      text = bytes.dup.force_encoding(Encoding::UTF_8).scrub
      replacements = {
        File.dirname(home) => "$PROBE_ROOT",
        root => "$REPOSITORY_ROOT",
        Dir.home => "$HOME",
        tmp => "$TMP"
      }
      replacements.keys.sort_by { |path| -path.length }.each do |path|
        text.gsub!(path, replacements.fetch(path)) unless path.empty?
      end
      text.gsub!(%r{(?:/private)?/var/folders/[^\s:]+/T/[^/\s:]+}, "$TMP")
      text.gsub!(%r{(?:/private)?/tmp/[A-Za-z0-9._-]+}, "$TMP")
      text
    end
  end
end
