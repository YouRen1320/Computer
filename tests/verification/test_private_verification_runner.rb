# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "pathname"
require "stringio"
require "tmpdir"
require "yaml"

require_relative "../../scripts/run-private-verification"

class PrivateVerificationRunnerTest < Minitest::Test
  SOURCE_ROOT = Pathname(File.expand_path("../..", __dir__)).freeze
  CHAPTER_ID = "ch.java.sample-topic"
  PRIVATE_CANARY_TEXT = "PRIVATE_SOLUTION_DO_NOT_PUBLISH_FIXTURE"
  PRIVATE_CONTROL_PLANE = %w[
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

  class FakeCommandRunner
    attr_reader :calls

    def initialize(exit_code: 0, stdout: "PRIVATE PASS\n", stderr: "", timed_out: false, &action)
      @exit_code = exit_code
      @stdout = stdout
      @stderr = stderr
      @timed_out = timed_out
      @action = action
      @calls = []
    end

    def call(env:, argv:, chdir:)
      @calls << { env: env, argv: argv, chdir: chdir }
      @action.call(Pathname(chdir)) if @action
      Verification::CommandResult.new(
        stdout: @stdout,
        stderr: @stderr,
        exit_code: @timed_out ? nil : @exit_code,
        timed_out: @timed_out
      )
    end

    def execution_policy
      { "timeout_seconds" => 23.0, "termination_grace_seconds" => 0.5 }
    end
  end

  def test_control_plane_exactly_matches_fresh_process_local_require_closure
    script = <<~'RUBY'
      require "json"
      root = File.realpath(ARGV.fetch(0))
      require File.join(root, "verification/lib/private_runner")
      prefix = root + File::SEPARATOR
      loaded = $LOADED_FEATURES.map do |feature|
        feature.delete_prefix(prefix) if feature.start_with?(prefix)
      end.compact
      STDOUT.write(JSON.generate(loaded.sort))
    RUBY
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-e", script, SOURCE_ROOT.to_s)

    assert status.success?, stderr
    require_closure = JSON.parse(stdout)
    closure = (require_closure + %w[
      scripts/run-private-verification.rb
      verification/private-contract.yml
    ]).uniq.sort
    assert_equal PRIVATE_CONTROL_PLANE.sort, closure
    assert_equal PRIVATE_CONTROL_PLANE, Verification::PrivateRunner::CONTROL_PLANE_PATHS
  end

  def test_check_validates_internal_inventory_without_execution_or_evidence
    with_fixture do |root|
      commands = FakeCommandRunner.new
      stdout = StringIO.new

      status = Verification::PrivateApplication.run(
        ["--check", "--json"],
        root: root,
        stdout: stdout,
        stderr: StringIO.new,
        command_runner: commands,
        environment: { "PATH" => ENV.fetch("PATH", "") }
      )
      summary = JSON.parse(stdout.string)

      assert_equal 0, status
      assert_equal "private-contract-check", summary.fetch("mode")
      assert_equal 1, summary.fetch("chapter_count")
      assert_equal 0, summary.fetch("commands_executed")
      assert_empty commands.calls
      refute root.join("verification/private-evidence/last-run").exist?
    end
  end

  def test_execute_uses_clean_copy_and_writes_only_opaque_internal_evidence
    with_fixture do |root, fixture|
      source_answer = root.join(fixture.fetch(:chapter_root), "answer-secret.txt")
      commands = FakeCommandRunner.new(stdout: "#{PRIVATE_CANARY_TEXT} #{source_answer}\n") do |workdir|
        workdir.join("build").mkpath
        workdir.join("build/result.txt").write("generated\n")
      end

      result = Verification::PrivateRunner.new(
        root: root,
        command_runner: commands,
        environment: { "PATH" => ENV.fetch("PATH", "") }
      ).run
      evidence_path = root.join(result.fetch("evidence_path"))
      bytes = evidence_path.binread
      evidence = JSON.parse(bytes)

      assert_equal 1, result.fetch("chapter_count")
      assert_equal 1, commands.calls.length
      refute_includes commands.calls.first.fetch(:chdir), "solutions-private"
      refute root.join(fixture.fetch(:chapter_root), "build").exist?
      assert_equal "internal-only", evidence.fetch("visibility")
      assert_equal 11, evidence.fetch("control_plane_count")
      assert_equal PRIVATE_CONTROL_PLANE, evidence.fetch("control_plane").map { |entry| entry.fetch("path") }
      expected_control_entries = PRIVATE_CONTROL_PLANE.map do |relative|
        payload = root.join(relative).binread
        {
          "path" => relative,
          "sha256" => Digest::SHA256.hexdigest(payload),
          "size_bytes" => payload.bytesize
        }
      end
      assert_equal expected_control_entries, evidence.fetch("control_plane")
      assert_equal(
        Verification::Canonical.path_bytes_digest(
          PRIVATE_CONTROL_PLANE.map { |relative| { "path" => relative, "bytes" => root.join(relative).binread } }
        ),
        evidence.fetch("control_plane_digest")
      )
      runtime = evidence.fetch("environment").fetch("runner_runtime")
      assert_equal RUBY_ENGINE, runtime.fetch("ruby_engine")
      assert_equal RUBY_VERSION, runtime.fetch("ruby_version")
      assert_equal RUBY_PATCHLEVEL, runtime.fetch("ruby_patchlevel")
      assert_equal RUBY_PLATFORM, runtime.fetch("ruby_platform")
      assert_equal RUBY_DESCRIPTION, runtime.fetch("ruby_description")
      assert_equal(
        { "termination_grace_seconds" => 0.5, "timeout_seconds" => 23.0 },
        evidence.fetch("execution_policy")
      )
      assert_equal 2, evidence.fetch("recipes").first.fetch("generated_output_count")
      refute_includes bytes, PRIVATE_CANARY_TEXT
      refute_includes bytes, "answer-secret.txt"
      refute_includes bytes, "solutions-private/"
      refute_includes bytes, source_answer.to_s
      refute_includes bytes, "PRIVATE PASS"
      refute root.join("verification/evidence/last-run").exist?
    end
  end

  def test_timeout_fails_without_replacing_internal_evidence
    with_fixture do |root|
      previous = root.join("verification/private-evidence/last-run")
      previous.mkpath
      previous.join("evidence.json").write("previous\n")

      error = assert_raises(Verification::ContractError) do
        Verification::PrivateRunner.new(
          root: root,
          command_runner: FakeCommandRunner.new(timed_out: true),
          environment: { "PATH" => ENV.fetch("PATH", "") }
        ).run
      end

      assert_equal "E_PRIVATE_RECIPE_TIMEOUT", error.code
      assert_equal "previous\n", previous.join("evidence.json").read
    end
  end

  def test_private_input_symlink_is_rejected_before_execution
    with_fixture do |root, fixture|
      answer = root.join(fixture.fetch(:chapter_root), "answer-secret.txt")
      replacement = root.join("replacement.txt")
      replacement.write("replacement\n")
      answer.delete
      File.symlink(replacement, answer)
      commands = FakeCommandRunner.new

      error = assert_raises(Verification::ContractError) do
        Verification::PrivateRunner.new(
          root: root,
          command_runner: commands,
          environment: { "PATH" => ENV.fetch("PATH", "") }
        ).run
      end

      assert_equal "E_PRIVATE_INPUT_SYMLINK", error.code
      assert_empty commands.calls
    end
  end

  def test_detected_package_manager_requires_explicit_fixed_cache
    with_fixture(verify_body: "#!/usr/bin/env bash\npnpm --version\n") do |root|
      commands = FakeCommandRunner.new

      error = assert_raises(Verification::ContractError) do
        Verification::PrivateRunner.new(
          root: root,
          command_runner: commands,
          environment: { "PATH" => ENV.fetch("PATH", "") }
        ).run
      end

      assert_equal "E_CACHE_REQUIRED", error.code
      assert_equal "pnpm", error.path
      assert_empty commands.calls
    end
  end

  def test_dart_pub_is_detected_as_the_dart_pub_cache_tool
    with_fixture(verify_body: "#!/usr/bin/env bash\ndart pub get --offline\n") do |root|
      commands = FakeCommandRunner.new

      error = assert_raises(Verification::ContractError) do
        Verification::PrivateRunner.new(
          root: root,
          command_runner: commands,
          environment: { "PATH" => ENV.fetch("PATH", "") }
        ).run
      end

      assert_equal "E_CACHE_REQUIRED", error.code
      assert_equal "dart-pub", error.path
      assert_empty commands.calls
    end
  end

  def test_private_cli_accepts_explicit_dart_pub_cache_override
    options = Verification::PrivateApplication.parse_options(
      ["--check", "--dart-pub-cache", "/tmp/factorycare-dart-pub"],
      {}
    )

    assert_equal "/tmp/factorycare-dart-pub", options.fetch(:cache_overrides).fetch(:dart_pub_cache)
    assert_includes Verification::PrivateApplication.usage, "--dart-pub-cache PATH"
  end

  def test_contract_count_mismatch_fails_closed
    with_fixture do |root|
      path = root.join("verification/private-contract.yml")
      contract = YAML.safe_load(path.read)
      contract["expected_chapter_count"] = 2
      path.write(YAML.dump(contract))

      error = assert_raises(Verification::ContractError) do
        Verification::PrivateContractLoader.new(root).discover
      end

      assert_equal "E_PRIVATE_CHAPTER_COUNT", error.code
    end
  end

  private

  def with_fixture(verify_body: "#!/usr/bin/env bash\nprintf 'PRIVATE PASS\\n'\n")
    Dir.mktmpdir("private-verification-test-") do |directory|
      root = Pathname(File.realpath(directory))
      Verification::PrivateRunner::CONTROL_PLANE_PATHS.each do |relative|
        destination = root.join(relative)
        destination.dirname.mkpath
        FileUtils.cp(SOURCE_ROOT.join(relative), destination)
      end

      contract_path = root.join("verification/private-contract.yml")
      contract = YAML.safe_load(contract_path.read)
      contract["expected_chapter_count"] = 1
      contract_path.write(YAML.dump(contract))

      catalog = root.join("curriculum/catalog.yml")
      catalog.dirname.mkpath
      catalog.write(YAML.dump("chapters" => [{ "id" => CHAPTER_ID }]))

      chapter_root = "solutions-private/encyclopedia/#{CHAPTER_ID}"
      chapter = root.join(chapter_root)
      chapter.mkpath
      verify = chapter.join("verify.sh")
      verify.write(verify_body)
      verify.chmod(0o755)
      chapter.join("answer-secret.txt").write("#{PRIVATE_CANARY_TEXT}\n")

      yield root, { chapter_root: chapter_root }
    end
  end
end
