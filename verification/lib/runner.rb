# frozen_string_literal: true

require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

require_relative "atomic_evidence_writer"

module Verification
  CommandResult = Struct.new(:stdout, :stderr, :exit_code, keyword_init: true)

  class LocalCommandRunner
    def call(env:, argv:, chdir:)
      stdout, stderr, status = Open3.capture3(env, *argv, chdir: chdir)
      exit_code = status.exitstatus || (128 + status.termsig.to_i)
      CommandResult.new(stdout: stdout.b, stderr: stderr.b, exit_code: exit_code)
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
      scripts/run-verification.rb
      verification/lib/application.rb
      verification/lib/atomic_evidence_writer.rb
      verification/lib/contract.rb
      verification/lib/runner.rb
    ].freeze

    attr_reader :root, :loader, :command_runner, :evidence_writer

    def initialize(root:, loader: nil, command_runner: LocalCommandRunner.new, evidence_writer: nil)
      @root = File.realpath(root)
      @loader = loader || ManifestLoader.new(@root)
      @command_runner = command_runner
      @evidence_writer = evidence_writer || AtomicEvidenceWriter.new(@root)
    end

    def validate_contracts
      loader.discover
    end

    def run(write_evidence: true)
      manifests = loader.discover
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
      by_id.keys.sort.map do |id|
        variants = by_id.fetch(id).uniq
        unless variants.length == 1
          raise ContractError.new("tool", "E_TOOL_DECLARATION_DRIFT", "tool declarations differ between manifests", path: id)
        end
        declaration = variants.first
        argv = declaration.fetch("version_argv")
        result = command_runner.call(env: probe_environment, argv: argv, chdir: root)
        unless result.exit_code.zero?
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
          "network_isolation" => "not-os-enforced",
          "filesystem_isolation" => "clean-copy-not-os-sandboxed"
        },
        "limitations" => LIMITATIONS,
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
      )
      environment["JAVA_HOME"] = ENV.fetch("JAVA_HOME") if ENV["JAVA_HOME"] && !ENV.fetch("JAVA_HOME").empty?
      environment
    end

    def probe_environment
      FIXED_ENVIRONMENT.merge("PATH" => sanitized_path)
    end

    def sanitized_path
      @sanitized_path ||= begin
        candidates = TOOL_VERSION_COMMANDS.values.map(&:first)
        directories = candidates.map { |command| executable_directory(command) }.compact
        (directories + %w[/usr/bin /bin /usr/sbin /sbin]).uniq.join(File::PATH_SEPARATOR)
      end
    end

    def executable_directory(command)
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |directory|
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
