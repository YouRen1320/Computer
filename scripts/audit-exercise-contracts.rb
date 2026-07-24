#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "optparse"
require "securerandom"

require File.expand_path("audit-encyclopedia-endpoints", __dir__)
require File.expand_path("../verification/lib/endpoint_report_guard", __dir__)
require File.expand_path("../verification/lib/exercise_contract_audit", __dir__)
require File.expand_path("../verification/lib/machine_report_schema", __dir__)

module Verification
  module ExerciseContractCLI
    module_function

    def run(argv, stdout: $stdout, stderr: $stderr)
      options = parse_options(argv)
      root = File.realpath(options.fetch(:root))
      endpoint_report, source_bytes = if options[:endpoint_report]
                                        bytes = File.binread(File.expand_path(options.fetch(:endpoint_report)))
                                        [StrictJson.parse(bytes), bytes]
                                      else
                                        document = EncyclopediaEndpointAudit::Auditor.new(
                                          root: root,
                                          jobs: options.fetch(:jobs),
                                          timeout_seconds: options.fetch(:timeout_seconds)
                                        ).run
                                        [document, Canonical.json(document)]
                                      end
      MachineReportSchema.validate!(
        root: root,
        schema_path: "schemas/encyclopedia-endpoint-audit.schema.json",
        document: endpoint_report
      )
      EndpointReportGuard.require_full_pass!(endpoint_report)
      report = ExerciseContractAudit.build(
        endpoint_report,
        source_endpoint_report_sha256: Canonical.sha256(source_bytes)
      )
      MachineReportSchema.validate!(
        root: root,
        schema_path: "schemas/exercise-contract-audit.schema.json",
        document: report
      )
      bytes = Canonical.json(report)
      write_atomic(options.fetch(:output), bytes) if options[:output]
      stdout.write(options[:output] ? "EXERCISE CONTRACT AUDIT #{report.fetch('status')} chapters=#{report.fetch('chapter_count')}\n" : bytes)
      report.fetch("mechanical_failure_count").zero? ? 0 : 1
    rescue OptionParser::ParseError, ContractError, EncyclopediaEndpointAudit::AuditError, Errno::ENOENT => e
      diagnostic = e.respond_to?(:diagnostic) ? e.diagnostic : "EXERCISE CONTRACT AUDIT FAILED: #{e.message.lines.first.to_s.strip}"
      stderr.puts(diagnostic)
      2
    end

    def parse_options(argv)
      options = {
        root: File.expand_path("..", __dir__),
        jobs: Integer(ENV.fetch("FACTORYCARE_AUDIT_JOBS", "6")),
        timeout_seconds: Integer(ENV.fetch("FACTORYCARE_AUDIT_TIMEOUT", "300")),
        output: nil,
        endpoint_report: nil
      }
      OptionParser.new do |parser|
        parser.banner = "Usage: ruby scripts/audit-exercise-contracts.rb [options]"
        parser.on("--root PATH") { |value| options[:root] = value }
        parser.on("--jobs N", Integer) { |value| options[:jobs] = value }
        parser.on("--timeout SECONDS", Integer) { |value| options[:timeout_seconds] = value }
        parser.on("--output PATH") { |value| options[:output] = value }
        parser.on("--endpoint-report PATH", "Reuse a full endpoint report containing two fresh exercise runs") do |value|
          options[:endpoint_report] = value
        end
      end.parse!(argv)
      raise OptionParser::InvalidArgument, "unexpected positional arguments" unless argv.empty?
      raise OptionParser::InvalidArgument, "jobs and timeout must be positive" unless options.fetch(:jobs).positive? && options.fetch(:timeout_seconds).positive?
      options
    end

    def write_atomic(path, bytes)
      absolute = File.expand_path(path)
      FileUtils.mkdir_p(File.dirname(absolute))
      temporary = "#{absolute}.tmp-#{$$}-#{SecureRandom.hex(6)}"
      File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o644) do |file|
        file.binmode
        file.write(bytes)
        file.flush
        file.fsync
      end
      File.rename(temporary, absolute)
    ensure
      FileUtils.rm_f(temporary) if defined?(temporary) && temporary
    end
  end
end

exit Verification::ExerciseContractCLI.run(ARGV) if $PROGRAM_NAME == __FILE__
