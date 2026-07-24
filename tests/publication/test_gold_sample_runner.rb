# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "stringio"
require "tmpdir"

require_relative "../../scripts/verify-gold-samples"

class GoldSampleRunnerTest < Minitest::Test
  CommandResult = GoldSampleVerification::CommandResult
  CopySpec = GoldSampleVerification::CopySpec
  Recipe = GoldSampleVerification::Recipe

  class QueuedCommandRunner
    attr_reader :calls

    def initialize(responses)
      @responses = responses.map do |response|
        response.is_a?(CommandResult) ? response : CommandResult.new(stdout: "ignored", stderr: "ignored", exit_code: response)
      end
      @calls = []
    end

    def call(env:, argv:, chdir:)
      @calls << { env: env, argv: argv, chdir: chdir }
      @responses.shift
    end
  end

  def test_fixed_catalog_has_eleven_recipes_and_nine_physical_script_entries
    recipes = GoldSampleVerification::Catalog::RECIPES

    assert_equal 11, recipes.length
    assert_equal 9, recipes.map(&:script_entry).compact.uniq.length
    assert_equal :values_example, recipes.find { |recipe| recipe.id == "java-values-types-example" }.executor
    assert_equal ["java-values-types-exercise"], recipes.select { |recipe| recipe.expected_exit != 0 }.map(&:id)
    assert_equal 0, recipes.find { |recipe| recipe.id == "java-values-types-starter" }.expected_exit
    assert_equal 41, recipes.find { |recipe| recipe.id == "java-values-types-exercise" }.expected_exit
  end

  def test_values_example_uses_fixed_maven_and_two_exact_output_oracles
    with_fixture do |root|
      example = root.join("values-example")
      FileUtils.mkdir_p(example)
      File.write(example.join("pom.xml"), "<project/>\n")
      expected = "设备快照\n"
      File.binwrite(example.join("expected-output.txt"), expected)
      recipe = Recipe.new(
        id: "java-values-types-example",
        executor: :values_example,
        script_entry: nil,
        copies: [CopySpec.new(source: "values-example", destination: "workspace")],
        run_script: nil,
        arguments: [],
        expected_exit: 0
      )
      command_runner = QueuedCommandRunner.new([
        CommandResult.new(stdout: "", stderr: "", exit_code: 0),
        CommandResult.new(stdout: expected, stderr: "", exit_code: 0),
        CommandResult.new(stdout: "ticketCount=0, enabled=false, note=null\n", stderr: "", exit_code: 0)
      ])
      stdout = StringIO.new

      status = GoldSampleVerification::Application.run(
        ["--json"], root: root, stdout: stdout, stderr: StringIO.new,
        command_runner: command_runner, recipes: [recipe]
      )
      summary = JSON.parse(stdout.string)

      assert_equal 0, status
      assert_equal true, summary.fetch("success")
      assert_equal 0, summary.fetch("script_entry_count")
      assert_equal 3, command_runner.calls.length
      assert_equal "mvn", command_runner.calls[0].fetch(:argv)[0]
      assert_includes command_runner.calls[0].fetch(:env).fetch("MAVEN_ARGS"), "--offline"
      assert_equal "com.factorycare.learning.DeviceSnapshot", command_runner.calls[1].fetch(:argv).last
      assert_equal "com.factorycare.learning.FieldDefaultBoundary", command_runner.calls[2].fetch(:argv).last
    end
  end

  def test_success_contract_counts_expected_nonzero_and_fixes_environment
    with_fixture do |root|
      recipes = [fixture_recipe("normal", 0), fixture_recipe("expected-failure", 1)]
      command_runner = QueuedCommandRunner.new([0, 1])
      stdout = StringIO.new
      stderr = StringIO.new

      status = GoldSampleVerification::Application.run(
        ["--json"],
        root: root,
        stdout: stdout,
        stderr: stderr,
        command_runner: command_runner,
        recipes: recipes
      )
      summary = JSON.parse(stdout.string)

      assert_equal 0, status
      assert_empty stderr.string
      assert_equal true, summary.fetch("success")
      assert_equal 2, summary.fetch("recipe_total")
      assert_equal 2, summary.fetch("script_entry_count")
      assert_equal 2, summary.fetch("passed")
      assert_equal 0, summary.fetch("failed")
      assert_equal 1, summary.fetch("expected_nonzero")
      assert_equal 1, summary.fetch("expected_nonzero_passed")
      assert_equal 2, command_runner.calls.length
      command_runner.calls.each do |call|
        assert_equal "en_US.UTF-8", call.fetch(:env).fetch("LC_ALL")
        assert_equal "UTC", call.fetch(:env).fetch("TZ")
        assert_equal GoldSampleVerification::SOURCE_DATE_EPOCH,
                     call.fetch(:env).fetch("SOURCE_DATE_EPOCH")
        assert_equal "--offline --batch-mode --no-transfer-progress",
                     call.fetch(:env).fetch("MAVEN_ARGS")
        assert call.fetch(:env).fetch("TMPDIR").start_with?(call.fetch(:chdir) + "/")
      end
    end
  end

  def test_unknown_argument_is_usage_error_without_running_commands
    command_runner = QueuedCommandRunner.new([])
    stdout = StringIO.new
    stderr = StringIO.new

    status = GoldSampleVerification::Application.run(
      ["--manifest", "anything.yml"],
      stdout: stdout,
      stderr: stderr,
      command_runner: command_runner
    )

    assert_equal 64, status
    assert_empty stdout.string
    assert_equal "Usage: ruby scripts/verify-gold-samples.rb [--json]\n", stderr.string
    assert_empty command_runner.calls
  end

  def test_tampered_recipe_with_missing_run_script_fails_without_leaking_temp_path
    with_fixture do |root|
      recipe = fixture_recipe("tampered", 0, run_script: "owner/missing.sh")
      command_runner = QueuedCommandRunner.new([])
      stdout = StringIO.new

      status = GoldSampleVerification::Application.run(
        [],
        root: root,
        stdout: stdout,
        stderr: StringIO.new,
        command_runner: command_runner,
        recipes: [recipe]
      )

      assert_equal 1, status
      assert_includes stdout.string, "FAIL tampered expected_exit=0 actual_exit=unavailable error=missing_run_script"
      refute_match(%r{/var/folders|/private/tmp|gold-sample-}, stdout.string)
      assert_empty command_runner.calls
    end
  end

  def test_unexpected_exit_fails_and_json_contains_only_safe_summary
    with_fixture do |root|
      command_runner = QueuedCommandRunner.new([0])
      stdout = StringIO.new
      recipe = fixture_recipe("expected-failure", 1)

      status = GoldSampleVerification::Application.run(
        ["--json"],
        root: root,
        stdout: stdout,
        stderr: StringIO.new,
        command_runner: command_runner,
        recipes: [recipe]
      )
      summary = JSON.parse(stdout.string)

      assert_equal 1, status
      assert_equal false, summary.fetch("success")
      assert_equal 0, summary.fetch("passed")
      assert_equal 1, summary.fetch("failed")
      assert_equal 1, summary.fetch("expected_nonzero")
      assert_equal 0, summary.fetch("expected_nonzero_passed")
      assert_equal "exit_mismatch", summary.fetch("results").first.fetch("error")
      refute_match(%r{/var/folders|/private/tmp|gold-sample-}, stdout.string)
    end
  end

  private

  def with_fixture
    Dir.mktmpdir("gold-runner-test-") do |directory|
      root = Pathname(directory)
      %w[normal expected-failure tampered].each do |name|
        owner = root.join(name)
        FileUtils.mkdir_p(owner)
        File.write(owner.join("verify.sh"), "#!/bin/sh\nexit 0\n")
        FileUtils.chmod(0o755, owner.join("verify.sh"))
      end
      yield root
    end
  end

  def fixture_recipe(id, expected_exit, run_script: "owner/verify.sh")
    Recipe.new(
      id: id,
      executor: :script,
      script_entry: "#{id}/verify.sh",
      copies: [CopySpec.new(source: id, destination: "owner")],
      run_script: run_script,
      arguments: [],
      expected_exit: expected_exit
    )
  end
end
