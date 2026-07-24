# frozen_string_literal: true

require "fileutils"
require "pathname"
require "rbconfig"
require "tmpdir"

require_relative "atomic_evidence_writer"
require_relative "cache_policy"
require_relative "private_contract"
require_relative "runner"

module Verification
  class PrivateRunner
    CONTROL_PLANE_PATHS = %w[
      scripts/lib/chapter_prerequisite_block.rb
      scripts/lib/factorycare_status_contract.rb
      scripts/run-private-verification.rb
      scripts/validate-encyclopedia.rb
      verification/lib/atomic_evidence_writer.rb
      verification/lib/cache_policy.rb
      verification/lib/contract.rb
      verification/lib/private_contract.rb
      verification/lib/private_runner.rb
      verification/lib/runner.rb
      verification/private-contract.yml
    ].freeze
    LIMITATIONS = [
      "internal-only-not-public-d5-evidence",
      "private-output-content-is-hashed-not-disclosed",
      "generated-output-set-is-opaque-not-predeclared",
      "network-policy-not-os-enforced",
      "filesystem-policy-not-os-sandboxed",
      "verify-scripts-own-tool-version-assertions"
    ].freeze

    attr_reader :root, :loader, :command_runner, :evidence_writer, :cache_overrides, :environment

    def initialize(root:, loader: nil, command_runner: LocalCommandRunner.new, evidence_writer: nil,
                   cache_overrides: {}, environment: ENV)
      @root = File.realpath(root)
      @loader = loader || PrivateContractLoader.new(@root)
      @command_runner = command_runner
      @evidence_writer = evidence_writer || AtomicEvidenceWriter.new(
        @root,
        evidence_directory: PRIVATE_EVIDENCE_DIRECTORY
      )
      @cache_overrides = cache_overrides
      @environment = environment
    end

    def validate_contract
      loader.discover
    end

    def run(write_evidence: true)
      chapters = loader.discover
      @cache_policy = CachePolicy.resolve(
        root: root,
        tool_ids: chapters.flat_map(&:cache_tool_ids),
        overrides: cache_overrides,
        env: environment
      )
      results = chapters.map { |chapter| run_chapter(chapter) }
      evidence = build_evidence(chapters, results)
      bytes = Canonical.json(evidence)
      reject_evidence_leaks!(bytes)
      evidence_path = write_evidence ? evidence_writer.write(bytes) : nil
      {
        "success" => true,
        "chapter_count" => chapters.length,
        "recipe_count" => results.length,
        "evidence_path" => evidence_path,
        "evidence_sha256" => Canonical.sha256(bytes),
        "evidence" => evidence
      }
    end

    private

    def run_chapter(chapter)
      Dir.mktmpdir("factorycare-private-verification-") do |directory|
        sandbox = File.realpath(directory)
        repository = File.join(sandbox, "answer")
        runtime_tmp = File.join(sandbox, "tmp")
        runtime_home = File.join(sandbox, "home")
        [repository, runtime_tmp, runtime_home].each { |path| Dir.mkdir(path, 0o700) }
        copy_inputs!(chapter, repository)
        before = snapshot(repository, sandbox)
        result = command_runner.call(
          env: execution_environment(runtime_tmp, runtime_home),
          argv: ["bash", chapter.verify_relative],
          chdir: repository
        )
        validate_result!(result, chapter.chapter_id)
        after = snapshot(repository, sandbox)
        outputs = validate_delta!(before, after, chapter.chapter_id)
        stdout = normalize_ephemeral_paths(result.stdout, sandbox)
        stderr = normalize_ephemeral_paths(result.stderr, sandbox)
        {
          "chapter_id" => chapter.chapter_id,
          "status" => "succeeded",
          "expected_exit_code" => 0,
          "actual_exit_code" => result.exit_code,
          "input_count" => chapter.inputs.length,
          "input_set_sha256" => input_set_digest(chapter.inputs),
          "entrypoint_sha256" => Canonical.sha256(
            chapter.inputs.find { |entry| entry.fetch("relative") == chapter.verify_relative }.fetch("bytes")
          ),
          "cache_tool_ids" => chapter.cache_tool_ids.sort,
          "normalized_stdout_sha256" => Canonical.sha256(stdout),
          "normalized_stdout_size_bytes" => stdout.bytesize,
          "normalized_stderr_sha256" => Canonical.sha256(stderr),
          "normalized_stderr_size_bytes" => stderr.bytesize,
          "generated_output_count" => outputs.length,
          "generated_output_set_sha256" => opaque_output_digest(outputs)
        }
      end
    rescue ContractError
      raise
    rescue StandardError => e
      raise ContractError.new(
        "private-execution", "E_PRIVATE_RECIPE_EXECUTION",
        "private recipe execution failed (#{e.class})",
        path: chapter.chapter_id
      )
    end

    def copy_inputs!(chapter, destination_root)
      chapter.inputs.each do |entry|
        destination = File.join(destination_root, entry.fetch("relative"))
        FileUtils.mkdir_p(File.dirname(destination), mode: 0o755)
        mode = entry.fetch("mode").to_i(8)
        File.open(destination, File::WRONLY | File::CREAT | File::EXCL, mode) do |file|
          file.binmode
          file.write(entry.fetch("bytes"))
        end
        File.chmod(mode, destination)
      end
    end

    def validate_result!(result, chapter_id)
      unless result.is_a?(CommandResult)
        raise ContractError.new("private-execution", "E_PRIVATE_COMMAND_RESULT", "command runner returned an invalid result", path: chapter_id)
      end
      if result.timed_out
        raise ContractError.new("private-execution", "E_PRIVATE_RECIPE_TIMEOUT", "private recipe exceeded its timeout", path: chapter_id)
      end
      unless result.exit_code == 0
        raise ContractError.new("private-execution", "E_PRIVATE_EXIT", "private recipe returned a nonzero exit", path: chapter_id)
      end
    end

    def snapshot(repository, sandbox)
      entries = {}
      Dir.glob(File.join(repository, "**", "*"), File::FNM_DOTMATCH).sort.each do |absolute|
        relative = absolute.delete_prefix(repository + File::SEPARATOR)
        next if relative.empty? || relative.split("/").any? { |segment| segment == "." || segment == ".." }

        stat = File.lstat(absolute)
        entries[relative] = if stat.directory?
                              { "kind" => "directory" }
                            elsif stat.file?
                              bytes = File.binread(absolute)
                              normalized = normalize_ephemeral_paths(bytes, sandbox)
                              {
                                "kind" => "file",
                                "sha256" => Canonical.sha256(bytes),
                                "normalized_sha256" => Canonical.sha256(normalized),
                                "size_bytes" => bytes.bytesize,
                                "mode" => format("%04o", stat.mode & 0o777)
                              }
                            elsif stat.symlink?
                              target = File.readlink(absolute)
                              resolved = File.realpath(absolute)
                              unless contained?(resolved, repository)
                                raise ContractError.new("private-output", "E_PRIVATE_OUTPUT_SYMLINK_ESCAPE", "generated symbolic link escapes the clean copy")
                              end
                              { "kind" => "symlink", "target_sha256" => Canonical.sha256(target.b) }
                            else
                              raise ContractError.new("private-output", "E_PRIVATE_OUTPUT_SPECIAL", "generated special filesystem entry is forbidden")
                            end
      end
      entries
    rescue Errno::ENOENT, Errno::ELOOP
      raise ContractError.new("private-output", "E_PRIVATE_OUTPUT_SYMLINK", "generated symbolic link is dangling or cyclic")
    end

    def validate_delta!(before, after, chapter_id)
      before.each do |relative, entry|
        current = after[relative]
        unless current == entry
          raise ContractError.new(
            "private-output", "E_PRIVATE_INPUT_MUTATION",
            "private recipe modified or deleted a contracted input",
            path: chapter_id
          )
        end
      end
      (after.keys - before.keys).sort.map do |relative|
        after.fetch(relative).merge("path" => relative)
      end
    end

    def input_set_digest(inputs)
      Canonical.path_bytes_digest(
        inputs.map { |entry| { "path" => entry.fetch("relative"), "bytes" => entry.fetch("bytes") } }
      )
    end

    def opaque_output_digest(outputs)
      digest = Digest::SHA256.new
      outputs.sort_by { |entry| entry.fetch("path") }.each do |entry|
        digest << entry.fetch("path") << "\0" << entry.fetch("kind") << "\0"
        digest << entry.fetch("normalized_sha256", entry.fetch("target_sha256", "")) << "\0"
        digest << entry.fetch("size_bytes", 0).to_s << "\0"
      end
      digest.hexdigest
    end

    def build_evidence(chapters, results)
      control_plane = CONTROL_PLANE_PATHS.map do |relative|
        bytes, = loader.guard.read_contract(relative)
        {
          "path" => relative,
          "sha256" => Canonical.sha256(bytes),
          "size_bytes" => bytes.bytesize,
          "bytes" => bytes
        }
      end
      {
        "schema_version" => 1,
        "evidence_id" => "verification.private-solutions.last-run",
        "generated_by" => "scripts/run-private-verification.rb",
        "visibility" => "internal-only",
        "result" => "succeeded",
        "scope" => "private-solutions-clean-copy-only",
        "digest_algorithm" => DIGEST_ALGORITHM,
        "environment" => {
          "os" => RbConfig::CONFIG.fetch("host_os"),
          "arch" => RbConfig::CONFIG.fetch("host_cpu"),
          "locale" => Runner::FIXED_ENVIRONMENT.fetch("LC_ALL"),
          "timezone" => Runner::FIXED_ENVIRONMENT.fetch("TZ"),
          "runner_runtime" => runner_runtime,
          "path_sha256" => Canonical.sha256(sanitized_path.b),
          "network_isolation" => "not-os-enforced",
          "filesystem_isolation" => "clean-copy-not-os-sandboxed"
        },
        "execution_policy" => command_execution_policy,
        "cache_policy" => @cache_policy.evidence_summary,
        "limitations" => LIMITATIONS,
        "contract_sha256" => Canonical.sha256(loader.contract_bytes),
        "control_plane_count" => control_plane.length,
        "control_plane_digest" => Canonical.path_bytes_digest(control_plane),
        "control_plane" => control_plane.map { |entry| entry.reject { |key, _value| key == "bytes" } },
        "chapter_count" => chapters.length,
        "recipe_count" => results.length,
        "recipes" => results
      }
    end

    def execution_environment(runtime_tmp, runtime_home)
      result = Runner::FIXED_ENVIRONMENT.merge(
        "CI" => "true",
        "PYTHONDONTWRITEBYTECODE" => "1",
        "TMPDIR" => runtime_tmp,
        "HOME" => runtime_home,
        "PATH" => sanitized_path
      ).merge(@cache_policy.execution_environment)
      result["JAVA_HOME"] = environment.fetch("JAVA_HOME") if environment["JAVA_HOME"] && !environment.fetch("JAVA_HOME").empty?
      result
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
          "private-evidence", "E_PRIVATE_EXECUTION_POLICY",
          "command runner must disclose its effective timeout and termination grace"
        )
      end

      policy = command_runner.execution_policy
      expected_keys = %w[termination_grace_seconds timeout_seconds]
      unless policy.is_a?(Hash) && policy.keys.sort == expected_keys &&
             expected_keys.all? { |key| policy.fetch(key).is_a?(Numeric) && policy.fetch(key).positive? && policy.fetch(key).finite? }
        raise ContractError.new(
          "private-evidence", "E_PRIVATE_EXECUTION_POLICY",
          "command runner disclosed an invalid execution policy"
        )
      end
      policy
    end

    def sanitized_path
      @sanitized_path ||= environment.fetch("PATH", "").split(File::PATH_SEPARATOR).select do |directory|
        !directory.empty? && Pathname(directory).absolute? && File.directory?(directory) && !File.symlink?(directory)
      end.uniq.concat(%w[/usr/bin /bin /usr/sbin /sbin]).uniq.join(File::PATH_SEPARATOR)
    end

    def normalize_ephemeral_paths(bytes, sandbox)
      bytes.b.gsub(sandbox.b, "<SANDBOX>".b)
    end

    def reject_evidence_leaks!(bytes)
      if bytes.match?(PRIVATE_CANARY) || bytes.include?("solutions-private/") || bytes.include?("sources/private/") ||
         bytes.match?(%r{/(?:Users|home|private|tmp|var/folders)/})
        raise ContractError.new("private-evidence", "E_PRIVATE_EVIDENCE_LEAK", "internal evidence contains a private or absolute path")
      end
    end

    def contained?(candidate, base)
      candidate == base || candidate.start_with?(base + File::SEPARATOR)
    end
  end
end
