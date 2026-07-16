#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "pathname"
require "tmpdir"

# Runs the executable teaching assets for the four P3 Java gold chapters.
# The recipe catalog is intentionally code-owned: command lines cannot be
# supplied by chapter metadata or command-line arguments.
module GoldSampleVerification
  SOURCE_DATE_EPOCH = "1767225600" # 2026-01-01T00:00:00Z
  FIXED_ENVIRONMENT = {
    "LANG" => "en_US.UTF-8",
    "LC_ALL" => "en_US.UTF-8",
    "TZ" => "UTC",
    "SOURCE_DATE_EPOCH" => SOURCE_DATE_EPOCH,
    "MAVEN_ARGS" => "--offline --batch-mode --no-transfer-progress"
  }.freeze

  CopySpec = Struct.new(:source, :destination, keyword_init: true)
  Recipe = Struct.new(
    :id,
    :executor,
    :script_entry,
    :copies,
    :run_script,
    :arguments,
    :expected_exit,
    keyword_init: true
  )
  CommandResult = Struct.new(:stdout, :stderr, :exit_code, keyword_init: true)

  module Catalog
    module_function

    def copy(source, destination = "workspace")
      CopySpec.new(source: source.freeze, destination: destination.freeze).freeze
    end

    def recipe(id:, copies:, executor: :script, script_entry: nil, run_script: nil,
               arguments: [], expected_exit: 0)
      Recipe.new(
        id: id.freeze,
        executor: executor,
        script_entry: script_entry.freeze,
        copies: copies.freeze,
        run_script: run_script.freeze,
        arguments: arguments.map(&:freeze).freeze,
        expected_exit: expected_exit
      ).freeze
    end

    RECIPES = [
      recipe(
        id: "java-platform-toolchain-example",
        script_entry: "examples/encyclopedia/ch.java.platform-toolchain/scripts/verify.sh",
        copies: [copy("examples/encyclopedia/ch.java.platform-toolchain")],
        run_script: "workspace/scripts/verify.sh"
      ),
      recipe(
        id: "java-program-structure-example",
        script_entry: "examples/encyclopedia/ch.java.program-structure/verify.sh",
        copies: [copy("examples/encyclopedia/ch.java.program-structure")],
        run_script: "workspace/verify.sh"
      ),
      recipe(
        id: "java-program-structure-faults",
        script_entry: "labs/encyclopedia/ch.java.program-structure/verify-failures.sh",
        copies: [copy("labs/encyclopedia/ch.java.program-structure")],
        run_script: "workspace/verify-failures.sh"
      ),
      recipe(
        id: "java-program-structure-private-solution",
        script_entry: "solutions-private/encyclopedia/ch.java.program-structure/verify.sh",
        copies: [copy("solutions-private/encyclopedia/ch.java.program-structure")],
        run_script: "workspace/verify.sh"
      ),
      recipe(
        id: "java-values-types-example",
        executor: :values_example,
        copies: [copy("examples/encyclopedia/ch.java.values-variables-types")]
      ),
      recipe(
        id: "java-values-types-starter",
        script_entry: "labs/encyclopedia/ch.java.values-variables-types/verify.sh",
        copies: [copy("labs/encyclopedia/ch.java.values-variables-types")],
        run_script: "workspace/verify.sh",
        expected_exit: 1
      ),
      recipe(
        id: "java-values-types-private-solution",
        script_entry: "labs/encyclopedia/ch.java.values-variables-types/verify.sh",
        copies: [
          copy("labs/encyclopedia/ch.java.values-variables-types", "lab"),
          copy("solutions-private/encyclopedia/ch.java.values-variables-types", "target")
        ],
        run_script: "lab/verify.sh",
        arguments: ["target/lab-solution"]
      ),
      recipe(
        id: "java-expressions-conversions-example",
        script_entry: "examples/encyclopedia/ch.java.expressions-conversions/verify.sh",
        copies: [copy("examples/encyclopedia/ch.java.expressions-conversions")],
        run_script: "workspace/verify.sh"
      ),
      recipe(
        id: "java-expressions-conversions-lab",
        script_entry: "labs/encyclopedia/ch.java.expressions-conversions/verify.sh",
        copies: [copy("labs/encyclopedia/ch.java.expressions-conversions")],
        run_script: "workspace/verify.sh"
      ),
      recipe(
        id: "java-expressions-conversions-private-solution",
        script_entry: "solutions-private/encyclopedia/ch.java.expressions-conversions/verify.sh",
        copies: [copy("solutions-private/encyclopedia/ch.java.expressions-conversions")],
        run_script: "workspace/verify.sh"
      )
    ].freeze
  end

  class LocalCommandRunner
    def call(env:, argv:, chdir:)
      stdout, stderr, status = Open3.capture3(env, *argv, chdir: chdir)
      exit_code = status.exitstatus || (128 + status.termsig.to_i)
      CommandResult.new(stdout: stdout, stderr: stderr, exit_code: exit_code)
    end
  end

  class Runner
    SAFE_PATH = /\A[a-zA-Z0-9][a-zA-Z0-9._\/-]*\z/.freeze
    SAFE_ID = /\A[a-z0-9][a-z0-9.-]*\z/.freeze

    attr_reader :root, :recipes

    def initialize(root:, recipes: Catalog::RECIPES, command_runner: LocalCommandRunner.new)
      @root = Pathname(root).expand_path
      @recipes = recipes
      @command_runner = command_runner
    end

    def run
      catalog_error = validate_catalog
      return summary_for_catalog_error(catalog_error) if catalog_error

      results = recipes.map { |recipe| run_recipe(recipe) }
      build_summary(results)
    end

    private

    def validate_catalog
      return "empty_catalog" unless recipes.is_a?(Array) && !recipes.empty?
      return "duplicate_recipe_id" unless recipes.map(&:id).uniq.length == recipes.length

      recipes.each do |recipe|
        return "invalid_recipe_id" unless recipe.id.is_a?(String) && SAFE_ID.match?(recipe.id)
        return "invalid_executor" unless %i[script values_example].include?(recipe.executor)
        return "invalid_expected_exit" unless recipe.expected_exit.is_a?(Integer) && recipe.expected_exit.between?(0, 255)
        return "invalid_copies" unless recipe.copies.is_a?(Array) && !recipe.copies.empty?
        return "invalid_arguments" unless recipe.arguments.is_a?(Array) && recipe.arguments.all? { |arg| safe_relative_path?(arg) }

        if recipe.executor == :script
          return "invalid_script_entry" unless safe_relative_path?(recipe.script_entry)
          return "invalid_run_script" unless safe_relative_path?(recipe.run_script)
        else
          valid_direct_recipe = recipe.id == "java-values-types-example" &&
                                recipe.script_entry.nil? && recipe.run_script.nil? &&
                                recipe.arguments.empty? && recipe.expected_exit.zero?
          return "invalid_direct_recipe" unless valid_direct_recipe
        end

        recipe.copies.each do |copy|
          return "invalid_copy_source" unless safe_relative_path?(copy.source)
          return "invalid_copy_destination" unless safe_relative_path?(copy.destination)
        end
      end
      nil
    end

    def safe_relative_path?(value)
      value.is_a?(String) && SAFE_PATH.match?(value) &&
        !Pathname(value).absolute? &&
        value.split("/", -1).none? { |segment| segment.empty? || segment == "." || segment == ".." }
    end

    def run_recipe(recipe)
      Dir.mktmpdir("gold-sample-") do |directory|
        sandbox = Pathname(directory)
        runtime_tmp = sandbox.join("tmp")
        FileUtils.mkdir_p(runtime_tmp)
        copy_inputs(recipe, sandbox)

        environment = FIXED_ENVIRONMENT.merge("TMPDIR" => runtime_tmp.to_s)
        return run_values_example(recipe, sandbox, environment) if recipe.executor == :values_example

        command = sandbox.join(recipe.run_script)
        unless command.file? && !command.symlink?
          return result(recipe, nil, false, "missing_run_script")
        end

        argv = [command.to_s] + recipe.arguments
        execution = @command_runner.call(env: environment, argv: argv, chdir: sandbox.to_s)
        passed = execution.exit_code == recipe.expected_exit
        result(recipe, execution.exit_code, passed, passed ? nil : "exit_mismatch")
      end
    rescue StandardError
      result(recipe, nil, false, "execution_error")
    end

    def copy_inputs(recipe, sandbox)
      if recipe.script_entry
        entry = root.join(recipe.script_entry)
        raise "missing script entry" unless entry.file? && !entry.symlink?
      end

      recipe.copies.each do |copy|
        source = root.join(copy.source)
        raise "missing copy source" unless source.directory? && !source.symlink?

        destination = sandbox.join(copy.destination)
        FileUtils.mkdir_p(destination.dirname)
        FileUtils.cp_r(source, destination, preserve: true)
      end
    end

    def run_values_example(recipe, sandbox, environment)
      workspace = sandbox.join("workspace")
      build = @command_runner.call(
        env: environment,
        argv: ["mvn", "-q", "-f", workspace.join("pom.xml").to_s, "clean", "package"],
        chdir: sandbox.to_s
      )
      return result(recipe, build.exit_code, false, "exit_mismatch") unless build.exit_code.zero?

      snapshot = @command_runner.call(
        env: environment,
        argv: [
          "java", "-cp", workspace.join("target/classes").to_s,
          "com.factorycare.learning.DeviceSnapshot"
        ],
        chdir: sandbox.to_s
      )
      expected_snapshot = File.binread(workspace.join("expected-output.txt"))
      return result(recipe, snapshot.exit_code, false, "exit_mismatch") unless snapshot.exit_code.zero?
      unless snapshot.stderr.empty? && snapshot.stdout.b == expected_snapshot.b
        return result(recipe, 1, false, "oracle_mismatch")
      end

      boundary = @command_runner.call(
        env: environment,
        argv: [
          "java", "-cp", workspace.join("target/classes").to_s,
          "com.factorycare.learning.FieldDefaultBoundary"
        ],
        chdir: sandbox.to_s
      )
      return result(recipe, boundary.exit_code, false, "exit_mismatch") unless boundary.exit_code.zero?
      unless boundary.stderr.empty? && boundary.stdout == "ticketCount=0, enabled=false, note=null\n"
        return result(recipe, 1, false, "oracle_mismatch")
      end

      result(recipe, 0, true, nil)
    end

    def result(recipe, actual_exit, passed, error)
      {
        "id" => recipe.id,
        "expected_exit" => recipe.expected_exit,
        "actual_exit" => actual_exit,
        "passed" => passed,
        "error" => error
      }
    end

    def summary_for_catalog_error(error)
      {
        "schema_version" => 1,
        "success" => false,
        "script_entry_count" => 0,
        "recipe_total" => recipes.is_a?(Array) ? recipes.length : 0,
        "passed" => 0,
        "failed" => recipes.is_a?(Array) ? recipes.length : 0,
        "expected_nonzero" => 0,
        "expected_nonzero_passed" => 0,
        "catalog_error" => error,
        "results" => []
      }
    end

    def build_summary(results)
      passed = results.count { |item| item.fetch("passed") }
      expected_nonzero_ids = recipes.select { |recipe| recipe.expected_exit != 0 }.map(&:id)
      expected_nonzero_passed = results.count do |item|
        expected_nonzero_ids.include?(item.fetch("id")) && item.fetch("passed")
      end
      {
        "schema_version" => 1,
        "success" => passed == recipes.length,
        "script_entry_count" => recipes.map(&:script_entry).compact.uniq.length,
        "recipe_total" => recipes.length,
        "passed" => passed,
        "failed" => recipes.length - passed,
        "expected_nonzero" => expected_nonzero_ids.length,
        "expected_nonzero_passed" => expected_nonzero_passed,
        "catalog_error" => nil,
        "results" => results
      }
    end
  end

  class Application
    USAGE = "Usage: ruby scripts/verify-gold-samples.rb [--json]".freeze

    def self.run(argv, root: Pathname(__dir__).join("..").expand_path,
                 stdout: $stdout, stderr: $stderr, command_runner: LocalCommandRunner.new,
                 recipes: Catalog::RECIPES)
      unless argv.empty? || argv == ["--json"]
        stderr.puts(USAGE)
        return 64
      end

      summary = Runner.new(root: root, recipes: recipes, command_runner: command_runner).run
      if argv == ["--json"]
        stdout.write(JSON.pretty_generate(summary))
        stdout.write("\n")
      else
        write_text(summary, stdout)
      end
      summary.fetch("success") ? 0 : 1
    end

    def self.write_text(summary, output)
      output.puts(
        "GOLD SAMPLE VERIFY recipes=#{summary.fetch("recipe_total")} " \
        "script_entries=#{summary.fetch("script_entry_count")}"
      )
      if summary["catalog_error"]
        output.puts("FAIL catalog error=#{summary.fetch("catalog_error")}")
      end
      summary.fetch("results").each do |item|
        state = item.fetch("passed") ? "PASS" : "FAIL"
        actual = item.fetch("actual_exit").nil? ? "unavailable" : item.fetch("actual_exit")
        line = "#{state} #{item.fetch("id")} expected_exit=#{item.fetch("expected_exit")} actual_exit=#{actual}"
        line += " error=#{item.fetch("error")}" if item["error"]
        output.puts(line)
      end
      output.puts(
        "SUMMARY recipes=#{summary.fetch("recipe_total")} passed=#{summary.fetch("passed")} " \
        "failed=#{summary.fetch("failed")} expected_nonzero=#{summary.fetch("expected_nonzero")} " \
        "expected_nonzero_passed=#{summary.fetch("expected_nonzero_passed")}"
      )
      output.puts(summary.fetch("success") ? "GOLD SAMPLE VERIFY PASS" : "GOLD SAMPLE VERIFY FAIL")
    end

    private_class_method :write_text
  end
end

exit GoldSampleVerification::Application.run(ARGV) if $PROGRAM_NAME == __FILE__
