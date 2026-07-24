# frozen_string_literal: true

require "fileutils"
require "rbconfig"
require "tempfile"
require "timeout"
require "tmpdir"

require_relative "atomic_evidence_writer"
require_relative "cache_policy"

module Verification
  CommandResult = Struct.new(:stdout, :stderr, :exit_code, :timed_out, keyword_init: true)

  class LocalCommandRunner
    DEFAULT_TIMEOUT_SECONDS = 300.0
    DEFAULT_TERMINATION_GRACE_SECONDS = 2.0

    attr_reader :timeout_seconds, :termination_grace_seconds

    def initialize(timeout_seconds: DEFAULT_TIMEOUT_SECONDS,
                   termination_grace_seconds: DEFAULT_TERMINATION_GRACE_SECONDS)
      @timeout_seconds = positive_number!(timeout_seconds, "timeout")
      @termination_grace_seconds = positive_number!(termination_grace_seconds, "termination grace")
    end

    def execution_policy
      {
        "timeout_seconds" => timeout_seconds,
        "termination_grace_seconds" => termination_grace_seconds
      }
    end

    def call(env:, argv:, chdir:)
      stdout_file = Tempfile.new("factorycare-command-stdout")
      stderr_file = Tempfile.new("factorycare-command-stderr")
      [stdout_file, stderr_file].each(&:binmode)
      pid = Process.spawn(
        env, *argv,
        chdir: chdir,
        out: stdout_file,
        err: stderr_file,
        pgroup: true,
        unsetenv_others: true
      )
      timed_out = false
      status = nil
      begin
        Timeout.timeout(@timeout_seconds) { _waited, status = Process.wait2(pid) }
      rescue Timeout::Error
        timed_out = true
        terminate_process_group(pid)
        begin
          _waited, status = Process.wait2(pid)
        rescue Errno::ECHILD
          status = nil
        end
      ensure
        terminate_process_group(pid) if process_group_alive?(pid)
      end
      stdout_file.flush
      stderr_file.flush
      stdout_file.rewind
      stderr_file.rewind
      exit_code = if timed_out
                    nil
                  elsif status
                    status.exitstatus || (128 + status.termsig.to_i)
                  end
      CommandResult.new(
        stdout: stdout_file.read.b,
        stderr: stderr_file.read.b,
        exit_code: exit_code,
        timed_out: timed_out
      )
    ensure
      stdout_file&.close!
      stderr_file&.close!
    end

    private

    def positive_number!(value, label)
      number = Float(value)
      raise ArgumentError, "#{label} must be positive" unless number.positive? && number.finite?

      number
    rescue ArgumentError, TypeError
      raise ArgumentError, "#{label} must be a positive number"
    end

    def terminate_process_group(pid)
      signal_group("TERM", pid)
      deadline = monotonic_time + @termination_grace_seconds
      sleep(0.01) while process_group_alive?(pid) && monotonic_time < deadline
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

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  class Runner
    FIXED_ENVIRONMENT = {
      "LANG" => "en_US.UTF-8",
      "LC_ALL" => "en_US.UTF-8",
      "TZ" => "UTC",
      "SOURCE_DATE_EPOCH" => "1767225600",
      "MAVEN_ARGS" => "--offline --batch-mode --no-transfer-progress"
    }.freeze
    LIMITATIONS = [
      "automated-local-evidence-only",
      "network-policy-not-os-enforced",
      "filesystem-policy-not-os-sandboxed",
      "no-human-pedagogy-accessibility-or-cross-platform-claim",
      "generated-output-bytes-may-contain-tool-or-temporary-path-variance"
    ].freeze
    CONTROL_PLANE_PATHS = %w[
      schemas/verification-manifest.schema.json
      scripts/lib/chapter_prerequisite_block.rb
      scripts/lib/factorycare_status_contract.rb
      scripts/run-verification.rb
      scripts/validate-encyclopedia.rb
      verification/lib/application.rb
      verification/lib/atomic_evidence_writer.rb
      verification/lib/cache_policy.rb
      verification/lib/contract.rb
      verification/lib/coverage_audit.rb
      verification/lib/runner.rb
    ].freeze

    attr_reader :root, :loader, :command_runner, :evidence_writer, :cache_overrides, :environment

    def initialize(root:, loader: nil, command_runner: LocalCommandRunner.new, evidence_writer: nil,
                   cache_overrides: {}, environment: ENV)
      @root = File.realpath(root)
      @loader = loader || ManifestLoader.new(@root)
      @command_runner = command_runner
      @evidence_writer = evidence_writer || AtomicEvidenceWriter.new(@root)
      @cache_overrides = cache_overrides
      @environment = environment
    end

    def validate_contracts
      loader.discover
    end

    def run(write_evidence: true)
      manifests = loader.discover
      @cache_policy = CachePolicy.resolve(
        root: root,
        tool_ids: manifests.flat_map { |manifest| manifest.data.fetch("tools").map { |tool| tool.fetch("id") } },
        overrides: cache_overrides,
        env: environment
      )
      tools = probe_tools(manifests)
      results = manifests.flat_map do |manifest|
        manifest.data.fetch("recipes").map { |recipe| run_recipe(manifest, recipe) }
      end
      evidence = build_evidence(manifests, tools, results)
      bytes = Canonical.json(evidence)
      reject_evidence_leaks!(bytes)
      evidence_path = write_evidence ? evidence_writer.write(bytes) : nil
      {
        "success" => true,
        "manifest_count" => manifests.length,
        "recipe_count" => results.length,
        "expected_nonzero_count" => results.count { |result| result.fetch("expected_exit_code") != 0 },
        "evidence_path" => evidence_path,
        "evidence_sha256" => Canonical.sha256(bytes),
        "evidence" => evidence
      }
    end

    private

    def probe_tools(manifests)
      declared = manifests.flat_map { |manifest| manifest.data.fetch("tools") }
      by_id = declared.group_by { |tool| tool.fetch("id") }
      Dir.mktmpdir("factorycare-verification-probe-") do |directory|
        runtime_tmp = File.join(directory, "tmp")
        runtime_home = File.join(directory, "home")
        [runtime_tmp, runtime_home].each { |path| Dir.mkdir(path, 0o700) }
        by_id.keys.sort.map do |id|
          variants = by_id.fetch(id).uniq
          unless variants.length == 1
            raise ContractError.new("tool", "E_TOOL_DECLARATION_DRIFT", "tool declarations differ between manifests", path: id)
          end
          declaration = variants.first
          argv = declaration.fetch("version_argv")
          result = command_runner.call(env: probe_environment(runtime_tmp, runtime_home), argv: argv, chdir: root)
          if result.timed_out
            raise ContractError.new("tool", "E_TOOL_TIMEOUT", "tool version probe exceeded its timeout", path: id)
          end
          unless result.exit_code&.zero?
            raise ContractError.new("tool", "E_TOOL_PROBE_EXIT", "tool version probe returned a nonzero exit", path: id)
          end
          combined = result.stdout + result.stderr
          version = first_nonempty_line(combined)
          unless version == declaration.fetch("expected_version")
            raise ContractError.new("tool", "E_TOOL_VERSION", "observed tool version differs from the manifest", path: id)
          end
          {
            "id" => id,
            "version" => version,
            "version_output_sha256" => Canonical.sha256(combined)
          }
        end
      end
    end

    def run_recipe(manifest, recipe)
      Dir.mktmpdir("factorycare-verification-") do |directory|
        sandbox = File.realpath(directory)
        repository = File.join(sandbox, "repo")
        runtime_tmp = File.join(sandbox, "tmp")
        runtime_home = File.join(sandbox, "home")
        [repository, runtime_tmp, runtime_home].each { |path| Dir.mkdir(path, 0o700) }
        copy_inputs!(manifest, recipe, repository)
        before = snapshot(repository, sandbox)
        working_directory = File.join(repository, recipe.fetch("workdir"))
        unless File.directory?(working_directory) && contained?(File.realpath(working_directory), repository)
          raise ContractError.new("execution", "E_WORKDIR", "recipe workdir is missing or unsafe", path: recipe.fetch("id"))
        end

        environment = execution_environment(runtime_tmp, runtime_home)
        result = command_runner.call(
          env: environment,
          argv: recipe.fetch("argv"),
          chdir: working_directory
        )
        after = snapshot(repository, sandbox)
        outputs = validate_filesystem_delta!(before, after, recipe)
        validate_result!(result, recipe)
        normalized_stdout = normalize_ephemeral_paths(result.stdout, sandbox)
        normalized_stderr = normalize_ephemeral_paths(result.stderr, sandbox)
        {
          "chapter_id" => manifest.data.fetch("chapter_id"),
          "recipe_id" => recipe.fetch("id"),
          "role" => recipe.fetch("role"),
          "argv" => recipe.fetch("argv"),
          "expected_exit_code" => recipe.fetch("expected_exit_code"),
          "actual_exit_code" => result.exit_code,
          "normalized_stdout_sha256" => Canonical.sha256(normalized_stdout),
          "normalized_stdout_size_bytes" => normalized_stdout.bytesize,
          "normalized_stderr_sha256" => Canonical.sha256(normalized_stderr),
          "normalized_stderr_size_bytes" => normalized_stderr.bytesize,
          "observation_count" => recipe.fetch("observations").length,
          "output_count" => outputs.length,
          "output_set_digest" => Canonical.output_set_digest(outputs),
          "outputs" => outputs
        }
      end
    rescue ContractError
      raise
    rescue StandardError => e
      raise ContractError.new("execution", "E_RECIPE_EXECUTION", "recipe execution failed (#{e.class})", path: recipe.fetch("id"))
    end

    def copy_inputs!(manifest, recipe, repository)
      recipe.fetch("input_paths").each do |relative|
        declared = manifest.inputs_by_path.fetch(relative)
        bytes, stat = loader.guard.read_public_input(
          relative,
          expected_sha256: declared.fetch("sha256"),
          expected_mode: declared.fetch("mode")
        )
        destination = File.join(repository, relative)
        FileUtils.mkdir_p(File.dirname(destination), mode: 0o755)
        File.open(destination, File::WRONLY | File::CREAT | File::EXCL, stat.mode & 0o777) do |file|
          file.binmode
          file.write(bytes)
        end
        File.chmod(stat.mode & 0o777, destination)
      end
    end

    def snapshot(repository, sandbox)
      entries = {}
      Dir.glob(File.join(repository, "**", "*"), File::FNM_DOTMATCH).sort.each do |absolute|
        relative = absolute.delete_prefix(repository + File::SEPARATOR)
        next if relative.empty?
        next if relative.split("/").any? { |segment| segment == "." || segment == ".." }

        stat = File.lstat(absolute)
        if stat.symlink?
          raise ContractError.new("output", "E_OUTPUT_SYMLINK", "symbolic-link output is forbidden", path: relative)
        elsif stat.directory?
          entries[relative] = { "kind" => "directory" }
        elsif stat.file?
          bytes = File.binread(absolute)
          normalized = normalize_ephemeral_paths(bytes, sandbox)
          entries[relative] = {
            "kind" => "file",
            "sha256" => Canonical.sha256(bytes),
            "size_bytes" => bytes.bytesize,
            "normalized_sha256" => Canonical.sha256(normalized),
            "normalized_size_bytes" => normalized.bytesize,
            "mode" => format("%04o", stat.mode & 0o777)
          }
        else
          raise ContractError.new("output", "E_OUTPUT_SPECIAL", "special filesystem entries are forbidden", path: relative)
        end
      end
      entries
    end

    def validate_filesystem_delta!(before, after, recipe)
      before.each do |path, entry|
        current = after[path]
        unless current
          raise ContractError.new("output", "E_INPUT_DELETED", "recipe deleted an input or input directory", path: path)
        end
        next if entry.fetch("kind") == "directory" && current.fetch("kind") == "directory"

        unless current == entry
          raise ContractError.new("output", "E_INPUT_MODIFIED", "recipe modified an input file", path: path)
        end
      end

      actual_paths = (after.keys - before.keys).sort
      declared = recipe.fetch("declared_outputs")
      declared_paths = declared.map { |item| item.fetch("path") }
      missing = declared_paths - actual_paths
      extra = actual_paths - declared_paths
      unless missing.empty?
        raise ContractError.new("output", "E_OUTPUT_MISSING", "declared output was not produced", path: missing.first)
      end
      unless extra.empty?
        raise ContractError.new("output", "E_OUTPUT_UNDECLARED", "recipe produced an undeclared output", path: extra.first)
      end

      declared.map do |item|
        actual = after.fetch(item.fetch("path"))
        unless actual.fetch("kind") == item.fetch("kind")
          raise ContractError.new("output", "E_OUTPUT_KIND", "output kind differs from the manifest", path: item.fetch("path"))
        end
        evidence = { "path" => item.fetch("path"), "kind" => item.fetch("kind") }
        if actual.fetch("kind") == "file"
          evidence["normalized_sha256"] = actual.fetch("normalized_sha256")
          evidence["normalized_size_bytes"] = actual.fetch("normalized_size_bytes")
        end
        evidence
      end
    end

    def validate_result!(result, recipe)
      unless result.is_a?(CommandResult)
        raise ContractError.new("execution", "E_COMMAND_RESULT", "command runner returned an invalid result", path: recipe.fetch("id"))
      end
      if result.timed_out
        raise ContractError.new("execution", "E_RECIPE_TIMEOUT", "recipe exceeded its timeout", path: recipe.fetch("id"))
      end
      unless result.exit_code == recipe.fetch("expected_exit_code")
        raise ContractError.new("execution", "E_EXIT_MISMATCH", "actual exit code differs from the manifest", path: recipe.fetch("id"))
      end
      if recipe.fetch("stderr_policy") == "empty" && !result.stderr.empty?
        raise ContractError.new("execution", "E_STDERR_NOT_EMPTY", "recipe wrote unexpected stderr bytes", path: recipe.fetch("id"))
      end
      recipe.fetch("observations").each do |observation|
        stream = observation.fetch("stream") == "stdout" ? result.stdout : result.stderr
        actual_count = literal_count(stream, observation.fetch("literal").b)
        unless actual_count == observation.fetch("count")
          raise ContractError.new("execution", "E_OBSERVATION", "recipe output did not satisfy an exact observation", path: recipe.fetch("id"))
        end
      end
    end

    def build_evidence(manifests, tools, results)
      control_plane = CONTROL_PLANE_PATHS.map do |path|
        bytes, = loader.guard.read_contract(path)
        { "path" => path, "sha256" => Canonical.sha256(bytes), "size_bytes" => bytes.bytesize, "bytes" => bytes }
      end
      {
        "schema_version" => 1,
        "evidence_id" => "verification.last-run",
        "generated_by" => "scripts/run-verification.rb",
        "result" => "succeeded",
        "scope" => "automated-local-only",
        "digest_algorithm" => DIGEST_ALGORITHM,
        "ephemeral_path_normalization" => "replace-sandbox-prefix-and-random-tmp-child-with-placeholders-before-output-digests-v1",
        "environment" => {
          "os" => RbConfig::CONFIG.fetch("host_os"),
          "arch" => RbConfig::CONFIG.fetch("host_cpu"),
          "locale" => FIXED_ENVIRONMENT.fetch("LC_ALL"),
          "timezone" => FIXED_ENVIRONMENT.fetch("TZ"),
          "runner_runtime" => runner_runtime,
          "network_isolation" => "not-os-enforced",
          "filesystem_isolation" => "clean-copy-not-os-sandboxed"
        },
        "execution_policy" => command_execution_policy,
        "cache_policy" => @cache_policy.evidence_summary,
        "limitations" => LIMITATIONS,
        "control_plane_count" => control_plane.length,
        "control_plane_digest" => Canonical.path_bytes_digest(control_plane),
        "control_plane" => control_plane.map { |entry| entry.reject { |key, _value| key == "bytes" } },
        "manifest_count" => manifests.length,
        "recipe_count" => results.length,
        "expected_nonzero_count" => results.count { |result| result.fetch("expected_exit_code") != 0 },
        "tools" => tools,
        "manifests" => manifests.map do |manifest|
          {
            "path" => manifest.path,
            "sha256" => Canonical.sha256(manifest.bytes),
            "chapter_id" => manifest.data.fetch("chapter_id"),
            "input_count" => manifest.data.fetch("input_count"),
            "input_set_sha256" => manifest.data.fetch("input_set_sha256")
          }
        end,
        "recipes" => results
      }
    end

    def execution_environment(runtime_tmp, runtime_home)
      environment = FIXED_ENVIRONMENT.merge(
        "TMPDIR" => runtime_tmp,
        "HOME" => runtime_home,
        "PATH" => sanitized_path
      ).merge(@cache_policy.execution_environment)
      environment["JAVA_HOME"] = self.environment.fetch("JAVA_HOME") if self.environment["JAVA_HOME"] && !self.environment.fetch("JAVA_HOME").empty?
      environment
    end

    def runner_runtime
      {
        "ruby_engine" => RUBY_ENGINE,
        "ruby_version" => RUBY_VERSION,
        "ruby_patchlevel" => RUBY_PATCHLEVEL,
        "ruby_platform" => RUBY_PLATFORM,
        "ruby_description" => RUBY_DESCRIPTION
      }
    end

    def command_execution_policy
      unless command_runner.respond_to?(:execution_policy)
        raise ContractError.new(
          "evidence", "E_EXECUTION_POLICY",
          "command runner must disclose its effective timeout and termination grace"
        )
      end

      policy = command_runner.execution_policy
      expected_keys = %w[termination_grace_seconds timeout_seconds]
      unless policy.is_a?(Hash) && policy.keys.sort == expected_keys &&
             expected_keys.all? { |key| policy.fetch(key).is_a?(Numeric) && policy.fetch(key).positive? && policy.fetch(key).finite? }
        raise ContractError.new(
          "evidence", "E_EXECUTION_POLICY",
          "command runner disclosed an invalid execution policy"
        )
      end
      policy
    end

    def probe_environment(runtime_tmp, runtime_home)
      execution_environment(runtime_tmp, runtime_home)
    end

    def sanitized_path
      @sanitized_path ||= begin
        candidates = TOOL_VERSION_COMMANDS.values.map(&:first)
        directories = candidates.map { |command| executable_directory(command) }.compact
        (directories + %w[/usr/bin /bin /usr/sbin /sbin]).uniq.join(File::PATH_SEPARATOR)
      end
    end

    def executable_directory(command)
      environment.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |directory|
        next if directory.empty? || !Pathname(directory).absolute?

        candidate = File.join(directory, command)
        return directory if File.file?(candidate) && File.executable?(candidate)
      end
      nil
    end

    def literal_count(haystack, needle)
      count = 0
      offset = 0
      while (index = haystack.index(needle, offset))
        count += 1
        offset = index + needle.bytesize
      end
      count
    end

    def normalize_ephemeral_paths(bytes, sandbox)
      normalized = bytes.b.gsub(sandbox.b, "<SANDBOX>".b)
      normalized = normalized.gsub(%r{<SANDBOX>/tmp/[a-zA-Z0-9._-]+}n, "<SANDBOX>/tmp/<EPHEMERAL>".b)
      normalized = normalized.gsub(/^--- <SANDBOX>\/.*$/n, "--- <DIFF_HEADER>".b)
      normalized.gsub(/^\+\+\+ <SANDBOX>\/.*$/n, "+++ <DIFF_HEADER>".b)
    end

    def first_nonempty_line(bytes)
      bytes.force_encoding(Encoding::UTF_8).lines.map(&:strip).find { |line| !line.empty? }.to_s
    end

    def reject_evidence_leaks!(bytes)
      if bytes.match?(PRIVATE_CANARY) || PRIVATE_PREFIXES.any? { |prefix| bytes.include?(prefix) } ||
         bytes.match?(%r{/(?:Users|home|private|tmp|var/folders)/})
        raise ContractError.new("evidence", "E_EVIDENCE_LEAK", "evidence contains an absolute or private path")
      end
    end

    def contained?(candidate, base)
      candidate == base || candidate.start_with?(base + File::SEPARATOR)
    end
  end
end
