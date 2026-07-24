#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"

require File.expand_path("../verification/lib/private_runner", __dir__)

module Verification
  module PrivateApplication
    module_function

    def run(argv, root: File.expand_path("..", __dir__), stdout: $stdout, stderr: $stderr,
            command_runner: nil, evidence_writer: nil, environment: ENV)
      options = parse_options(argv, environment)
      loader = PrivateContractLoader.new(root)
      if options.fetch(:check)
        chapters = loader.discover
        summary = {
          "success" => true,
          "mode" => "private-contract-check",
          "chapter_count" => chapters.length,
          "recipe_count" => chapters.length,
          "commands_executed" => 0,
          "evidence_written" => false
        }
      else
        runner = PrivateRunner.new(
          root: root,
          loader: loader,
          command_runner: command_runner || LocalCommandRunner.new(timeout_seconds: options.fetch(:timeout_seconds)),
          evidence_writer: evidence_writer,
          cache_overrides: options.fetch(:cache_overrides),
          environment: environment
        )
        result = runner.run
        summary = result.reject { |key, _value| key == "evidence" }.merge(
          "mode" => "private-execute",
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

    def parse_options(argv, environment)
      options = {
        check: false,
        json: false,
        timeout_seconds: positive_timeout(environment.fetch("FACTORYCARE_VERIFICATION_TIMEOUT", "300")),
        cache_overrides: {}
      }
      parser = OptionParser.new do |value|
        value.banner = usage
        value.on("--check", "validate internal inventory without executing private answers") { options[:check] = true }
        value.on("--json", "emit a safe machine-readable summary") { options[:json] = true }
        value.on("--timeout SECONDS", Float, "per-answer timeout") do |seconds|
          options[:timeout_seconds] = positive_timeout(seconds)
        end
        value.on("--pnpm-store PATH", "fixed pnpm store") { |path| options[:cache_overrides][:pnpm_store] = path }
        value.on("--dart-pub-cache PATH", "fixed Dart Pub cache") { |path| options[:cache_overrides][:dart_pub_cache] = path }
        value.on("--uv-cache PATH", "fixed uv cache") { |path| options[:cache_overrides][:uv_cache] = path }
        value.on("--maven-repo PATH", "fixed Maven local repository") { |path| options[:cache_overrides][:maven_repo] = path }
      end
      parser.parse!(argv)
      raise OptionParser::InvalidArgument, "unexpected positional arguments" unless argv.empty?

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
      elsif summary.fetch("mode") == "private-contract-check"
        stdout.puts("PRIVATE VERIFICATION CONTRACT VALID chapters=#{summary.fetch('chapter_count')} commands=0")
      else
        stdout.puts("PRIVATE VERIFICATION PASS chapters=#{summary.fetch('chapter_count')}")
        stdout.puts("evidence=#{summary.fetch('evidence_path')}")
        stdout.puts("evidence_sha256=#{summary.fetch('evidence_sha256')}")
        stdout.puts("visibility=internal-only")
      end
    end

    def usage
      "Usage: ruby scripts/run-private-verification.rb [--check] [--json] [--timeout SECONDS] " \
        "[--pnpm-store PATH] [--dart-pub-cache PATH] [--uv-cache PATH] [--maven-repo PATH]"
    end
  end
end

exit Verification::PrivateApplication.run(ARGV) if $PROGRAM_NAME == __FILE__
