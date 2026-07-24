# frozen_string_literal: true

require "json"
require "optparse"

require_relative "runner"
require_relative "coverage_audit"

module Verification
  module Application
    module_function

    def run(argv, root: File.expand_path("../..", __dir__), stdout: $stdout, stderr: $stderr,
            command_runner: LocalCommandRunner.new, evidence_writer: nil)
      options = parse_options(argv, stderr)
      return 64 unless options

      loader = ManifestLoader.new(root)
      CoverageAudit.new(root, loader: loader).require_complete! if options.fetch(:require_complete)
      if options.fetch(:check)
        manifests = loader.discover
        summary = {
          "success" => true,
          "mode" => "contract-check",
          "manifest_count" => manifests.length,
          "recipe_count" => manifests.sum { |manifest| manifest.data.fetch("recipes").length },
          "input_count" => manifests.sum { |manifest| manifest.data.fetch("inputs").length },
          "commands_executed" => 0,
          "evidence_written" => false
        }
      else
        runner = Runner.new(
          root: root,
          loader: loader,
          command_runner: command_runner,
          evidence_writer: evidence_writer
        )
        result = runner.run(write_evidence: true)
        summary = result.reject { |key, _value| key == "evidence" }.merge(
          "mode" => "execute",
          "evidence_written" => true
        )
      end
      emit(summary, options.fetch(:json), stdout)
      0
    rescue ContractError => e
      stderr.puts(e.diagnostic)
      1
    rescue OptionParser::ParseError => e
      stderr.puts(e.message)
      stderr.puts(usage)
      64
    end

    def parse_options(argv, stderr)
      options = { check: false, json: false, require_complete: false }
      parser = OptionParser.new do |value|
        value.banner = usage
        value.on("--check", "validate schema, semantics, paths, modes, and input digests without executing") { options[:check] = true }
        value.on("--json", "emit a machine-readable safe summary") { options[:json] = true }
        value.on("--require-complete", "fail unless all 255 catalog chapters have final manifests") { options[:require_complete] = true }
      end
      parser.parse!(argv)
      unless argv.empty?
        stderr.puts("unexpected arguments: #{argv.join(' ')}")
        stderr.puts(usage)
        return nil
      end
      options
    end

    def emit(summary, json, stdout)
      if json
        stdout.write(Canonical.json(summary))
      elsif summary.fetch("mode") == "contract-check"
        stdout.puts(
          "VERIFICATION CONTRACTS VALID manifests=#{summary.fetch('manifest_count')} " \
          "recipes=#{summary.fetch('recipe_count')} inputs=#{summary.fetch('input_count')} commands=0"
        )
      else
        stdout.puts(
          "VERIFICATION PASS manifests=#{summary.fetch('manifest_count')} " \
          "recipes=#{summary.fetch('recipe_count')} expected_nonzero=#{summary.fetch('expected_nonzero_count')}"
        )
        stdout.puts("evidence=#{summary.fetch('evidence_path')}")
        stdout.puts("evidence_sha256=#{summary.fetch('evidence_sha256')}")
        stdout.puts("boundary=automated-local-only")
      end
    end

    def usage
      "Usage: ruby scripts/run-verification.rb [--check] [--require-complete] [--json]"
    end
  end
end
