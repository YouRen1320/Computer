# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "pathname"
require "stringio"
require "tmpdir"
require "yaml"

require_relative "../../verification/lib/application"
require_relative "../../scripts/generate-verification-manifests"

class VerificationRunnerTest < Minitest::Test
  SOURCE_ROOT = Pathname(File.expand_path("../..", __dir__)).freeze

  class FakeCommandRunner
    attr_reader :calls

    def initialize(version: "fake bash 1", exit_code: 0, stdout: "PASS\n", stderr: "", &action)
      @version = version
      @exit_code = exit_code
      @stdout = stdout
      @stderr = stderr
      @action = action
      @calls = []
    end

    def call(env:, argv:, chdir:)
      @calls << { env: env, argv: argv, chdir: chdir }
      if argv == ["bash", "--version"]
        return Verification::CommandResult.new(stdout: "#{@version}\n", stderr: "", exit_code: 0)
      end

      @action.call(Pathname(chdir)) if @action
      Verification::CommandResult.new(stdout: @stdout, stderr: @stderr, exit_code: @exit_code)
    end
  end

  def test_valid_contract_loads_and_check_mode_executes_no_commands
    with_fixture do |root|
      runner = FakeCommandRunner.new
      stdout = StringIO.new

      status = Verification::Application.run(
        ["--check", "--json"], root: root, stdout: stdout, stderr: StringIO.new,
        command_runner: runner
      )
      summary = JSON.parse(stdout.string)

      assert_equal 0, status
      assert_equal 1, summary.fetch("manifest_count")
      assert_equal 1, summary.fetch("recipe_count")
      assert_equal 0, summary.fetch("commands_executed")
      assert_empty runner.calls
    end
  end

  def test_duplicate_yaml_key_fails_closed
    with_fixture do |root, fixture|
      path = root.join(fixture.fetch(:manifest_path))
      bytes = path.read
      path.write(bytes.sub("schema_version: 1\n", "schema_version: 1\nschema_version: 1\n"))

      error = assert_raises(Verification::ContractError) do
        Verification::ManifestLoader.new(root).discover
      end

      assert_equal "E_MANIFEST_YAML", error.code
    end
  end

  def test_absolute_and_private_paths_are_rejected
    with_fixture do |root, fixture|
      data = fixture.fetch(:data)
      data.fetch("inputs").first["path"] = "/tmp/verify.sh"
      write_manifest(root, fixture.fetch(:manifest_path), data)

      error = assert_raises(Verification::ContractError) { Verification::ManifestLoader.new(root).discover }
      assert_includes %w[E_MANIFEST_SCHEMA E_FORBIDDEN_STRING E_PATH_ABSOLUTE], error.code
    end

    with_fixture do |root, fixture|
      data = fixture.fetch(:data)
      data.fetch("inputs").first["path"] = "solutions-private/encyclopedia/ch.java.sample-topic/verify.sh"
      write_manifest(root, fixture.fetch(:manifest_path), data)

      error = assert_raises(Verification::ContractError) { Verification::ManifestLoader.new(root).discover }
      assert_includes %w[E_PRIVATE_REFERENCE E_MANIFEST_SCHEMA], error.code
    end
  end

  def test_symbolic_link_input_is_rejected
    with_fixture do |root, fixture|
      input = root.join(fixture.fetch(:input_path))
      real = root.join("outside.sh")
      real.write("#!/usr/bin/env bash\n")
      input.delete
      File.symlink(real, input)

      error = assert_raises(Verification::ContractError) { Verification::ManifestLoader.new(root).discover }
      assert_equal "E_PATH_SYMLINK", error.code
    end
  end

  def test_digest_drift_fails_before_any_tool_or_recipe_command
    with_fixture do |root, fixture|
      root.join(fixture.fetch(:input_path)).write("changed\n")
      commands = FakeCommandRunner.new

      error = assert_raises(Verification::ContractError) do
        Verification::Runner.new(root: root, command_runner: commands).run
      end

      assert_equal "E_INPUT_DIGEST", error.code
      assert_empty commands.calls
      refute root.join("verification/evidence/last-run").exist?
    end
  end

  def test_tool_version_mismatch_fails_before_recipe_and_does_not_write_evidence
    with_fixture do |root|
      commands = FakeCommandRunner.new(version: "different")

      error = assert_raises(Verification::ContractError) do
        Verification::Runner.new(root: root, command_runner: commands).run
      end

      assert_equal "E_TOOL_VERSION", error.code
      assert_equal [["bash", "--version"]], commands.calls.map { |call| call.fetch(:argv) }
      refute root.join("verification/evidence/last-run").exist?
    end
  end

  def test_exact_declared_output_and_observation_produce_safe_atomic_evidence
    with_fixture(outputs: [
      { "path" => "examples/encyclopedia/ch.java.sample-topic/build", "kind" => "directory" },
      { "path" => "examples/encyclopedia/ch.java.sample-topic/build/result.txt", "kind" => "file" }
    ]) do |root|
      commands = FakeCommandRunner.new do |workdir|
        workdir.join("build").mkpath
        workdir.join("build/result.txt").binwrite("stable\n")
      end
      result = Verification::Runner.new(root: root, command_runner: commands).run
      evidence_path = root.join(result.fetch("evidence_path"))
      bytes = evidence_path.binread
      evidence = JSON.parse(bytes)

      assert_equal true, result.fetch("success")
      assert_equal 1, result.fetch("recipe_count")
      assert_equal 0, result.fetch("expected_nonzero_count")
      assert_equal "succeeded", evidence.fetch("result")
      assert_equal 6, evidence.fetch("control_plane").length
      assert_match(/\A[0-9a-f]{64}\z/, evidence.fetch("control_plane_digest"))
      assert_equal 2, evidence.fetch("recipes").first.fetch("output_count")
      assert_equal Digest::SHA256.hexdigest(bytes), result.fetch("evidence_sha256")
      refute_match(%r{/(?:Users|home|private|tmp|var/folders)/}, bytes)
      refute_includes bytes, "solutions-private/"
      assert_equal ["evidence.json"], evidence_path.dirname.children.map(&:basename).map(&:to_s)
    end
  end

  def test_same_fake_run_produces_same_evidence_bytes
    with_fixture do |root|
      first = Verification::Runner.new(root: root, command_runner: FakeCommandRunner.new).run
      first_bytes = root.join(first.fetch("evidence_path")).binread
      second = Verification::Runner.new(root: root, command_runner: FakeCommandRunner.new).run
      second_bytes = root.join(second.fetch("evidence_path")).binread

      assert_equal first.fetch("evidence_sha256"), second.fetch("evidence_sha256")
      assert_equal first_bytes, second_bytes
    end
  end

  def test_undeclared_output_fails_and_preserves_previous_evidence
    with_fixture do |root|
      previous = root.join("verification/evidence/last-run")
      previous.mkpath
      previous.join("evidence.json").write("previous\n")
      commands = FakeCommandRunner.new do |workdir|
        workdir.join("surprise.txt").write("unexpected\n")
      end

      error = assert_raises(Verification::ContractError) do
        Verification::Runner.new(root: root, command_runner: commands).run
      end

      assert_equal "E_OUTPUT_UNDECLARED", error.code
      assert_equal "previous\n", previous.join("evidence.json").read
      assert_empty previous.dirname.children.select { |path| path.basename.to_s.start_with?(".last-run.") }
    end
  end

  def test_input_mutation_and_exit_mismatch_fail_without_evidence_replacement
    with_fixture do |root|
      commands = FakeCommandRunner.new do |workdir|
        workdir.join("verify.sh").write("mutated\n")
      end
      error = assert_raises(Verification::ContractError) do
        Verification::Runner.new(root: root, command_runner: commands).run
      end
      assert_equal "E_INPUT_MODIFIED", error.code
      refute root.join("verification/evidence/last-run").exist?
    end

    with_fixture do |root|
      commands = FakeCommandRunner.new(exit_code: 9)
      error = assert_raises(Verification::ContractError) do
        Verification::Runner.new(root: root, command_runner: commands).run
      end
      assert_equal "E_EXIT_MISMATCH", error.code
      refute root.join("verification/evidence/last-run").exist?
    end
  end

  def test_observation_count_is_exact
    with_fixture do |root|
      commands = FakeCommandRunner.new(stdout: "PASS\nPASS\n")
      error = assert_raises(Verification::ContractError) do
        Verification::Runner.new(root: root, command_runner: commands).run
      end
      assert_equal "E_OBSERVATION", error.code
    end
  end

  def test_arbitrary_interpreter_is_rejected_by_semantic_contract
    with_fixture do |root, fixture|
      data = fixture.fetch(:data)
      data.fetch("recipes").first["argv"] = ["sh", "verify.sh"]
      write_manifest(root, fixture.fetch(:manifest_path), data)

      error = assert_raises(Verification::ContractError) { Verification::ManifestLoader.new(root).discover }
      assert_equal "E_RECIPE_ARGV", error.code
    end
  end

  def test_atomic_promotion_failure_restores_previous_tree
    Dir.mktmpdir("verification-writer-") do |directory|
      root = Pathname(directory)
      previous = root.join("verification/evidence/last-run")
      previous.mkpath
      previous.join("evidence.json").write("old\n")
      rename_count = 0
      renamer = lambda do |source, destination|
        rename_count += 1
        raise IOError, "injected" if rename_count == 2

        File.rename(source, destination)
      end
      writer = Verification::AtomicEvidenceWriter.new(root, renamer: renamer)

      error = assert_raises(Verification::ContractError) { writer.write("new\n") }

      assert_equal "E_ATOMIC_PROMOTION", error.code
      assert_equal "old\n", previous.join("evidence.json").read
      assert_empty previous.dirname.children.select { |path| path.basename.to_s.start_with?(".last-run.") }
    end
  end

  def test_generator_check_validates_without_rewriting_manifest
    with_fixture do |root, fixture|
      path = root.join(fixture.fetch(:manifest_path))
      before = path.binread
      stdout = StringIO.new

      status = Verification::ManifestGenerator.run(["--check"], root: root, stdout: stdout, stderr: StringIO.new)

      assert_equal 0, status
      assert_equal before, path.binread
      assert_equal "VERIFICATION MANIFEST CHECK OK manifests=1\n", stdout.string
    end
  end

  def test_generator_write_refreshes_only_reviewed_manifest_input_locks
    with_fixture do |root, fixture|
      input = root.join(fixture.fetch(:input_path))
      input.write("#!/usr/bin/env bash\nprintf 'PASS\\n'\n# reviewed change\n")
      input.chmod(0o755)
      stdout = StringIO.new

      status = Verification::ManifestGenerator.run(["--write"], root: root, stdout: stdout, stderr: StringIO.new)
      manifest = Verification::ManifestLoader.new(root).discover.first

      assert_equal 0, status
      assert_equal "VERIFICATION MANIFEST WRITE OK manifests=1\n", stdout.string
      assert_equal Digest::SHA256.hexdigest(input.binread), manifest.data.fetch("inputs").first.fetch("sha256")
      assert_equal "0755", manifest.data.fetch("inputs").first.fetch("mode")
    end
  end

  def test_symbolic_link_output_is_rejected
    with_fixture(outputs: [
      { "path" => "examples/encyclopedia/ch.java.sample-topic/result.txt", "kind" => "file" }
    ]) do |root|
      commands = FakeCommandRunner.new do |workdir|
        File.symlink("verify.sh", workdir.join("result.txt"))
      end

      error = assert_raises(Verification::ContractError) do
        Verification::Runner.new(root: root, command_runner: commands).run
      end

      assert_equal "E_OUTPUT_SYMLINK", error.code
      refute root.join("verification/evidence/last-run").exist?
    end
  end

  private

  def with_fixture(outputs: [])
    Dir.mktmpdir("verification-test-") do |directory|
      root = Pathname(directory)
      Verification::Runner::CONTROL_PLANE_PATHS.each do |relative|
        destination = root.join(relative)
        destination.dirname.mkpath
        FileUtils.cp(SOURCE_ROOT.join(relative), destination)
      end
      input_path = "examples/encyclopedia/ch.java.sample-topic/verify.sh"
      input = root.join(input_path)
      input.dirname.mkpath
      input.write("#!/usr/bin/env bash\nprintf 'PASS\\n'\n")
      input.chmod(0o755)
      manifest_path = "verification/manifests/ch.java.sample-topic.yml"
      data = fixture_manifest(input_path, input.binread, outputs)
      write_manifest(root, manifest_path, data)
      fixture = { input_path: input_path, manifest_path: manifest_path, data: deep_copy(data) }
      yield root, fixture
    end
  end

  def fixture_manifest(input_path, bytes, outputs)
    {
      "schema_version" => 1,
      "manifest_id" => "verification.ch.java.sample-topic",
      "chapter_id" => "ch.java.sample-topic",
      "edition" => "test",
      "visibility" => "internal-evidence",
      "digest_algorithm" => Verification::DIGEST_ALGORITHM,
      "input_count" => 1,
      "input_set_sha256" => path_bytes_digest(input_path, bytes),
      "inputs" => [
        { "path" => input_path, "sha256" => Digest::SHA256.hexdigest(bytes), "mode" => "0755" }
      ],
      "tools" => [
        { "id" => "bash", "version_argv" => ["bash", "--version"], "expected_version" => "fake bash 1" }
      ],
      "recipes" => [
        {
          "id" => "sample-example",
          "role" => "example",
          "input_paths" => [input_path],
          "workdir" => "examples/encyclopedia/ch.java.sample-topic",
          "argv" => ["bash", "verify.sh"],
          "tool_ids" => ["bash"],
          "expected_exit_code" => 0,
          "stderr_policy" => "empty",
          "observations" => [{ "stream" => "stdout", "literal" => "PASS", "count" => 1 }],
          "declared_outputs" => outputs
        }
      ]
    }
  end

  def write_manifest(root, relative, data)
    path = root.join(relative)
    path.dirname.mkpath
    path.write(YAML.dump(data))
  end

  def path_bytes_digest(path, bytes)
    digest = Digest::SHA256.new
    digest << path << "\0" << bytes << "\0"
    digest.hexdigest
  end

  def deep_copy(value)
    Marshal.load(Marshal.dump(value))
  end
end
