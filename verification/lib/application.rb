# frozen_string_literal: true

require "json"
require "optparse"

require_relative "runner"
require_relative "coverage_audit"

module Verification
  module Application
    module_function

    def run(argv, root: File.expand_path("../..", __dir__), stdout: $stdout, stderr: $stderr,
            command_runner: nil, evidence_writer: nil, environment: ENV)
      options = parse_options(argv, stderr, environment)
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
          command_runner: command_runner || LocalCommandRunner.new(timeout_seconds: options.fetch(:timeout_seconds)),
          evidence_writer: evidence_writer,
          cache_overrides: options.fetch(:cache_overrides),
          environment: environment
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

    def parse_options(argv, stderr, environment = ENV)
      options = {
        check: false,
        json: false,
        require_complete: false,
        timeout_seconds: positive_timeout(environment.fetch("FACTORYCARE_VERIFICATION_TIMEOUT", "300")),
        cache_overrides: {}
      }
      parser = OptionParser.new do |value|
        value.banner = usage
        value.on("--check", "validate schema, semantics, paths, modes, and input digests without executing") { options[:check] = true }
        value.on("--json", "emit a machine-readable safe summary") { options[:json] = true }
        value.on("--require-complete", "fail unless all 255 catalog chapters have final manifests") { options[:require_complete] = true }
        value.on("--timeout SECONDS", Float, "per-command timeout (default: 300 or FACTORYCARE_VERIFICATION_TIMEOUT)") do |seconds|
          options[:timeout_seconds] = positive_timeout(seconds)
        end
        value.on("--pnpm-store PATH", "fixed pnpm store (or FACTORYCARE_PNPM_STORE_DIR)") do |path|
          options[:cache_overrides][:pnpm_store] = path
        end
        value.on("--dart-pub-cache PATH", "fixed Dart Pub cache (or FACTORYCARE_DART_PUB_CACHE)") do |path|
          options[:cache_overrides][:dart_pub_cache] = path
        end
        value.on("--uv-cache PATH", "fixed uv cache (or FACTORYCARE_UV_CACHE_DIR)") do |path|
          options[:cache_overrides][:uv_cache] = path
        end
        value.on("--maven-repo PATH", "fixed Maven local repository (or FACTORYCARE_MAVEN_REPO)") do |path|
          options[:cache_overrides][:maven_repo] = path
        end
      end
      parser.parse!(argv)
      unless argv.empty?
        stderr.puts("unexpected arguments: #{argv.join(' ')}")
        stderr.puts(usage)
        return nil
      end
      options
    end

    def positive_timeout(value)
      number = Float(value)
      unless number.positive? && number.finite?
        raise OptionParser::InvalidArgument, "timeout must be a positive finite number"
      end

      number
    rescue ArgumentError, TypeError
      raise OptionParser::InvalidArgument, "timeout must be a positive finite number"
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
      "Usage: ruby scripts/run-verification.rb [--check] [--require-complete] [--json] " \
        "[--timeout SECONDS] [--pnpm-store PATH] [--dart-pub-cache PATH] [--uv-cache PATH] [--maven-repo PATH]"
    end
  end
end
