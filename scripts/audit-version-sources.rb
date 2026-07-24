#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "digest"
require "json"
require "open3"
require "optparse"
require "psych"
require "tempfile"
require "uri"

module VersionSourceAudit
  class AuditError < StandardError; end

  ProbeResult = Struct.new(
    :exit_code,
    :http_status,
    :effective_url,
    :ssl_verify_result,
    :request_mode,
    :error,
    keyword_init: true
  )

  class CurlProbe
    FORMAT = "%{http_code}\t%{url_effective}\t%{ssl_verify_result}".freeze

    def initialize(curl: "curl", connect_timeout: 10, max_time: 25)
      @curl = curl
      @connect_timeout = Integer(connect_timeout)
      @max_time = Integer(max_time)
    end

    def call(url)
      result = perform(url, range: true)
      return result unless result.exit_code.zero? && [403, 405, 416].include?(result.http_status)

      perform(url, range: false)
    end

    private

    def perform(url, range:)
      arguments = [
        @curl,
        "--silent",
        "--show-error",
        "--location",
        "--proto", "=https",
        "--proto-redir", "=https"
      ]
      arguments.concat(["--range", "0-0"]) if range
      arguments.concat([
        "--connect-timeout", @connect_timeout.to_s,
        "--max-time", @max_time.to_s,
        "--output", File::NULL,
        "--write-out", FORMAT,
        url
      ])
      stdout, stderr, status = Open3.capture3(
        *arguments
      )
      fields = stdout.to_s.strip.split("\t", 3)
      ProbeResult.new(
        exit_code: status.exitstatus,
        http_status: fields.fetch(0, "000").to_i,
        effective_url: fields.fetch(1, ""),
        ssl_verify_result: fields.fetch(2, "").to_i,
        request_mode: range ? "range-get" : "get-fallback",
        error: sanitize_error(stderr)
      )
    rescue Errno::ENOENT => e
      raise AuditError, "curl executable not found: #{e.message.lines.first.to_s.strip}"
    end

    def sanitize_error(value)
      value.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")
           .lines.first.to_s.strip[0, 300]
    end
  end

  class Auditor
    SUCCESS_STATUSES = [200, 206].freeze

    attr_reader :root, :probe, :workers

    def initialize(root:, probe: CurlProbe.new, workers: 8)
      @root = File.realpath(root)
      @probe = probe
      @workers = Integer(workers)
      raise AuditError, "workers must be between 1 and 32" unless (1..32).cover?(@workers)
    end

    def report(checked_at:)
      date = Date.iso8601(checked_at.to_s).iso8601
      registry_path = File.join(root, "versions/registry.yml")
      registry_bytes = File.binread(registry_path)
      registry = Psych.safe_load(registry_bytes.force_encoding(Encoding::UTF_8), aliases: false)
      entries = registry.fetch("entries")
      raise AuditError, "versions/registry.yml entries must be an array" unless entries.is_a?(Array)

      queue = Queue.new
      entries.each_with_index { |entry, index| queue << [index, validate_entry(entry, index)] }
      results = Array.new(entries.length)
      threads = [workers, entries.length].min.times.map do
        Thread.new do
          loop do
            index, entry = queue.pop(true)
            results[index] = result_for(entry, probe.call(entry.fetch("source_url")))
          rescue ThreadError
            break
          end
        end.tap { |thread| thread.report_on_exception = false }
      end
      threads.each(&:value)

      failures = results.reject { |item| item.fetch("reachable") }
      status_counts = results.group_by { |item| item.fetch("http_status").to_s }
                             .transform_values(&:length)
                             .sort.to_h
      {
        "schema_version" => 1,
        "audit_id" => "p9-version-source-reachability",
        "checked_at" => date,
        "registry_path" => "versions/registry.yml",
        "registry_sha256" => Digest::SHA256.hexdigest(registry_bytes),
        "entry_count" => results.length,
        "reachable_count" => results.length - failures.length,
        "failure_count" => failures.length,
        "http_status_counts" => status_counts,
        "status" => failures.empty? ? "passed" : "failed",
        "entries" => results,
        "evidence_boundary" => "A successful probe proves only that the registered HTTPS URL returned HTTP 200/206 on the stated date; it does not verify source authority, page meaning, version compatibility, or chapter truth."
      }
    rescue ArgumentError => e
      raise AuditError, "checked-at must be an ISO date: #{e.message.lines.first.to_s.strip}"
    rescue KeyError, Psych::Exception, Errno::ENOENT => e
      raise AuditError, e.message.lines.first.to_s.strip
    end

    private

    def validate_entry(entry, index)
      raise AuditError, "entry ##{index + 1} must be a mapping" unless entry.is_a?(Hash)

      id = entry.fetch("id")
      url = entry.fetch("source_url")
      uri = URI.parse(url)
      unless uri.is_a?(URI::HTTPS) && uri.host && !uri.host.empty? && uri.userinfo.nil?
        raise AuditError, "entry #{id} source_url must be an absolute HTTPS URL without userinfo"
      end
      { "id" => id, "source_url" => url }
    rescue URI::InvalidURIError => e
      raise AuditError, "entry ##{index + 1} source_url is invalid: #{e.message.lines.first.to_s.strip}"
    end

    def result_for(entry, result)
      effective_https = begin
        uri = URI.parse(result.effective_url.to_s)
        uri.is_a?(URI::HTTPS) && uri.host && !uri.host.empty? && uri.userinfo.nil?
      rescue URI::InvalidURIError
        false
      end
      reachable = result.exit_code.zero? && SUCCESS_STATUSES.include?(result.http_status) &&
                  result.ssl_verify_result.zero? && effective_https
      {
        "id" => entry.fetch("id"),
        "source_url" => entry.fetch("source_url"),
        "effective_url" => result.effective_url,
        "effective_https" => effective_https,
        "http_status" => result.http_status,
        "ssl_verify_result" => result.ssl_verify_result,
        "request_mode" => result.request_mode || "injected-probe",
        "curl_exit_code" => result.exit_code,
        "reachable" => reachable,
        "error" => result.error
      }
    end
  end

  module CLI
    module_function

    def run(argv, stdout: $stdout, stderr: $stderr)
      options = {
        root: File.expand_path("..", __dir__),
        checked_at: Date.today.iso8601,
        output: nil,
        pretty: false,
        workers: 8,
        curl: "curl"
      }
      parser = OptionParser.new do |command|
        command.banner = "Usage: ruby scripts/audit-version-sources.rb [options]"
        command.on("--root PATH", "Repository root") { |value| options[:root] = value }
        command.on("--checked-at DATE", "Evidence date (YYYY-MM-DD)") { |value| options[:checked_at] = value }
        command.on("--output PATH", "Write JSON report") { |value| options[:output] = value }
        command.on("--workers N", Integer, "Concurrent read-only probes") { |value| options[:workers] = value }
        command.on("--curl PATH", "curl executable") { |value| options[:curl] = value }
        command.on("--pretty", "Pretty-print JSON") { options[:pretty] = true }
      end
      parser.parse!(argv)
      raise AuditError, "unexpected positional arguments" unless argv.empty?

      report = Auditor.new(
        root: options.fetch(:root),
        probe: CurlProbe.new(curl: options.fetch(:curl)),
        workers: options.fetch(:workers)
      ).report(checked_at: options.fetch(:checked_at))
      bytes = options.fetch(:pretty) ? JSON.pretty_generate(report) + "\n" : JSON.generate(report) + "\n"
      if options[:output]
        destination = File.expand_path(options.fetch(:output))
        atomic_write(destination, bytes)
        stdout.puts "VERSION SOURCE AUDIT #{report.fetch('status').upcase}"
        stdout.puts "report=#{destination}"
      else
        stdout.write(bytes)
      end
      report.fetch("status") == "passed" ? 0 : 1
    rescue OptionParser::ParseError, AuditError, Errno::ENOENT => e
      stderr.puts "VERSION SOURCE AUDIT FAILED: #{e.message.lines.first.to_s.strip}"
      2
    end

    def atomic_write(destination, bytes)
      directory = File.dirname(destination)
      raise AuditError, "output directory does not exist: #{directory}" unless Dir.exist?(directory)

      temporary = Tempfile.new([".version-source-audit-", ".tmp"], directory)
      temporary.binmode
      temporary.write(bytes)
      temporary.flush
      temporary.fsync
      temporary.close
      File.rename(temporary.path, destination)
    ensure
      temporary&.close!
    end
  end
end

exit VersionSourceAudit::CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
