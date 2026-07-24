#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "optparse"
require "tempfile"

require_relative "../verification/lib/definition_of_done_audit"

module Verification
  module DefinitionOfDoneCli
    module_function

    def run(argv, root: File.expand_path("..", __dir__), stdout: $stdout, stderr: $stderr)
      options = parse_options(argv)
      report = DefinitionOfDoneAudit.new(root).report
      bytes = Canonical.json(report)
      if options.fetch(:check)
        current = File.binread(resolve_output(root, options.fetch(:check)))
        unless current == bytes
          stderr.puts("[definition-of-done/E_DOD_REPORT_DRIFT]: existing report differs from current inputs")
          return 1
        end
        stdout.puts("DEFINITION OF DONE CHECK OK chapters=#{report.fetch('chapter_total')} structurally_ready=#{report.fetch('structurally_ready_count')} approved=#{report.fetch('semantic_approval_count')}")
      elsif options.fetch(:output)
        atomic_write(resolve_output(root, options.fetch(:output)), bytes)
        stdout.puts("DEFINITION OF DONE WRITE OK chapters=#{report.fetch('chapter_total')} structurally_ready=#{report.fetch('structurally_ready_count')} approved=#{report.fetch('semantic_approval_count')}")
      else
        stdout.write(bytes)
      end
      report.fetch("status") == "semantically-approved" ? 0 : 1
    rescue Verification::ContractError, KeyError, JSON::ParserError, Errno::ENOENT => e
      diagnostic = e.respond_to?(:diagnostic) ? e.diagnostic : "[definition-of-done/E_DOD_AUDIT]: #{e.message.lines.first.to_s.strip}"
      stderr.puts(diagnostic)
      1
    rescue OptionParser::ParseError => e
      stderr.puts(e.message)
      64
    end

    def parse_options(argv)
      options = { output: nil, check: nil }
      OptionParser.new do |parser|
        parser.banner = "Usage: ruby scripts/audit-encyclopedia-definition-of-done.rb [--output PATH | --check PATH]"
        parser.on("--output PATH", "atomically write canonical JSON") { |value| options[:output] = value }
        parser.on("--check PATH", "compare an existing report with current inputs") { |value| options[:check] = value }
      end.parse!(argv)
      raise OptionParser::InvalidOption, "--output and --check are mutually exclusive" if options[:output] && options[:check]
      raise OptionParser::InvalidOption, "unexpected arguments: #{argv.join(' ')}" unless argv.empty?

      options
    end

    def resolve_output(root, value)
      raise OptionParser::InvalidArgument, "report path must be repository-relative" if Pathname(value).absolute?

      absolute = File.expand_path(value, root)
      unless absolute.start_with?(File.realpath(root) + File::SEPARATOR)
        raise OptionParser::InvalidArgument, "report path escapes repository"
      end
      absolute
    end

    def atomic_write(path, bytes)
      FileUtils.mkdir_p(File.dirname(path))
      Tempfile.create(["definition-of-done", ".json"], File.dirname(path)) do |file|
        file.binmode
        file.write(bytes)
        file.flush
        file.fsync
        File.rename(file.path, path)
      end
    end
  end
end

exit Verification::DefinitionOfDoneCli.run(ARGV) if $PROGRAM_NAME == __FILE__
