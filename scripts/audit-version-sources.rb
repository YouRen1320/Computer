#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "digest"
require "json"
require "open3"
require "optparse"
require "tempfile"
require "uri"
require_relative "validate-encyclopedia"

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
      stdout, stderr, status = Open3.capture3(*arguments)
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
    REGISTRY_RELATIVE = "versions/registry.yml"
    REGISTRY_SCHEMA_RELATIVE = "schemas/version-registry.schema.json"
    ID_PATTERN = /\A[a-z0-9][a-z0-9.-]*\z/.freeze
    SOURCE_TYPES = %w[compatibility distribution documentation lifecycle release specification status].freeze

    attr_reader :root, :probe, :workers

    def initialize(root:, probe: CurlProbe.new, workers: 8)
      @root = File.realpath(root)
      @probe = probe
      @workers = Integer(workers)
      raise AuditError, "workers must be between 1 and 32" unless (1..32).cover?(@workers)
    end

    def report(checked_at:)
      date = Date.iso8601(checked_at.to_s).iso8601
      registry_path = File.join(root, REGISTRY_RELATIVE)
      registry_bytes = File.binread(registry_path)
      registry = StrictYaml.safe_load(
        registry_bytes.force_encoding(Encoding::UTF_8),
        label: REGISTRY_RELATIVE
      )
      validate_registry_schema(registry)
      validate_registry_header(registry)
      registry_reviewed_at = iso_date(registry.fetch("reviewed_at"), "registry reviewed_at")
      audit_date = Date.iso8601(date)
      raise AuditError, "registry reviewed_at cannot be after audit checked_at" if registry_reviewed_at > audit_date

      jobs, registry_status_counts = jobs_for(
        registry.fetch("entries"),
        audit_date: audit_date,
        registry_reviewed_at: registry_reviewed_at
      )

      queue = Queue.new
      jobs.each_with_index { |job, index| queue << [index, job] }
      results = Array.new(jobs.length)
      threads = [workers, jobs.length].min.times.map do
        Thread.new do
          loop do
            index, job = queue.pop(true)
            results[index] = result_for(job, probe.call(job.fetch("registered_url")))
          rescue ThreadError
            break
          rescue StandardError => e
            raise AuditError,
                  "probe failed for #{job&.fetch('entry_id', 'unknown')}/#{job&.fetch('source_id', 'unknown')}: #{e.message.lines.first.to_s.strip}"
          end
        end.tap { |thread| thread.report_on_exception = false }
      end
      threads.each(&:value)

      failures = results.reject { |item| item.fetch("reachable") }
      http_status_counts = results.group_by { |item| item.fetch("http_status").to_s }
                                  .transform_values(&:length)
                                  .sort.to_h
      {
        "schema_version" => 2,
        "audit_id" => "p9-version-source-reachability-v2",
        "checked_at" => date,
        "registry_path" => REGISTRY_RELATIVE,
        "registry_sha256" => Digest::SHA256.hexdigest(registry_bytes),
        "registry_schema_version" => registry.fetch("schema_version"),
        "registry_entry_count" => registry.fetch("entries").length,
        "source_count" => results.length,
        "reachable_count" => results.length - failures.length,
        "failure_count" => failures.length,
        "http_status_counts" => http_status_counts,
        "registry_status_counts" => registry_status_counts,
        "status" => failures.empty? ? "passed" : "failed",
        "policy_snapshot" => {
          "source_authority" => registry.dig("policy", "source_authority"),
          "promotion_mode" => registry.dig("policy", "promotion_mode"),
          "automatic_promotion" => registry.dig("policy", "automatic_promotion")
        },
        "sources" => results,
        "evidence_classification" => {
          "state" => "observed",
          "kind" => "network-reachability-only",
          "promotion" => "forbidden-without-human-review"
        },
        "evidence_boundary" => "A successful probe proves only that every registered official-or-primary HTTPS source returned HTTP 200/206 on the stated date. It does not verify a claim's meaning, compatibility, chapter truth, or justify changing conceptual/provisional status to verified."
      }
    rescue ArgumentError => e
      raise AuditError, "checked-at must be an ISO date: #{e.message.lines.first.to_s.strip}"
    rescue KeyError, TypeError, JSON::ParserError, StrictJson::DuplicateMemberError,
           Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError,
           Errno::ENOENT => e
      raise AuditError, e.message.lines.first.to_s.strip
    end

    private

    def validate_registry_schema(registry)
      schema_path = File.join(root, REGISTRY_SCHEMA_RELATIVE)
      schema = StrictJson.parse(File.read(schema_path, encoding: "UTF-8"))
      evaluator = ExecutableJsonSchema.new(schema, REGISTRY_SCHEMA_RELATIVE)
      unless evaluator.definition_errors.empty?
        raise AuditError, "invalid registry schema: #{evaluator.definition_errors.first}"
      end

      instance_errors = evaluator.validate(registry)
      raise AuditError, "registry schema violation: #{instance_errors.first}" unless instance_errors.empty?
    end

    def validate_registry_header(registry)
      raise AuditError, "#{REGISTRY_RELATIVE} must be a mapping" unless registry.is_a?(Hash)
      raise AuditError, "#{REGISTRY_RELATIVE} schema_version must equal 2" unless registry["schema_version"] == 2
      unless registry["registry_id"] == "factorycare-version-registry"
        raise AuditError, "#{REGISTRY_RELATIVE} registry_id must equal factorycare-version-registry"
      end

      policy = registry.fetch("policy")
      unless policy.is_a?(Hash) && policy["source_authority"] == "official-or-primary-only" &&
             policy["promotion_mode"] == "manual-only" && policy["automatic_promotion"] == false
        raise AuditError, "#{REGISTRY_RELATIVE} must enforce official-or-primary sources and manual-only promotion"
      end
      entries = registry.fetch("entries")
      raise AuditError, "#{REGISTRY_RELATIVE} entries must be a non-empty array" unless entries.is_a?(Array) && !entries.empty?
    end

    def jobs_for(entries, audit_date:, registry_reviewed_at:)
      entry_ids = {}
      jobs = []
      statuses = Hash.new(0)
      entries.each_with_index do |entry, entry_index|
        raise AuditError, "entry ##{entry_index + 1} must be a mapping" unless entry.is_a?(Hash)

        id = required_string(entry, "id", "entry ##{entry_index + 1}")
        raise AuditError, "entry ##{entry_index + 1} id has invalid syntax" unless id.match?(ID_PATTERN)
        raise AuditError, "duplicate entry id #{id}" if entry_ids.key?(id)
        raise AuditError, "entry #{id} uses forbidden legacy source_url" if entry.key?("source_url")

        entry_ids[id] = true
        status = required_string(entry, "status", "entry #{id}")
        unless %w[verified provisional conceptual].include?(status)
          raise AuditError, "entry #{id} has unsupported status #{status.inspect}"
        end
        statuses[status] += 1
        reviewed_at = iso_date(entry.fetch("reviewed_at"), "entry #{id} reviewed_at")
        if reviewed_at > registry_reviewed_at
          raise AuditError, "entry #{id} reviewed_at cannot be after registry reviewed_at"
        end
        if reviewed_at > audit_date
          raise AuditError, "entry #{id} reviewed_at cannot be after audit checked_at"
        end
        sources = entry.fetch("sources")
        raise AuditError, "entry #{id} sources must be a non-empty array" unless sources.is_a?(Array) && !sources.empty?

        source_ids = {}
        sources.each_with_index do |source, source_index|
          job = validate_source(
            source,
            entry_id: id,
            entry_status: status,
            entry_reviewed_at: reviewed_at,
            source_index: source_index
          )
          source_id = job.fetch("source_id")
          raise AuditError, "entry #{id} has duplicate source id #{source_id}" if source_ids.key?(source_id)

          source_ids[source_id] = true
          jobs << job
        end
      end
      [jobs, statuses.sort.to_h]
    end

    def validate_source(source, entry_id:, entry_status:, entry_reviewed_at:, source_index:)
      label = "entry #{entry_id} source ##{source_index + 1}"
      raise AuditError, "#{label} must be a mapping" unless source.is_a?(Hash)

      source_id = required_string(source, "id", label)
      raise AuditError, "#{label} id has invalid syntax" unless source_id.match?(ID_PATTERN)
      source_type = required_string(source, "type", label)
      raise AuditError, "#{label} type is unsupported" unless SOURCE_TYPES.include?(source_type)
      publisher = required_string(source, "publisher", label)
      claim = required_string(source, "claim", label)
      raise AuditError, "#{label} publisher must contain at least two characters" if publisher.strip.length < 2
      raise AuditError, "#{label} claim must contain at least twelve characters" if claim.strip.length < 12
      authority = required_string(source, "authority", label)
      raise AuditError, "#{label} authority must equal official-or-primary" unless authority == "official-or-primary"
      checked_at = iso_date(source.fetch("checked_at"), "#{label} checked_at")
      raise AuditError, "#{label} checked_at cannot be after entry reviewed_at" if checked_at > entry_reviewed_at

      url = required_string(source, "url", label)
      uri = URI.parse(url)
      unless uri.is_a?(URI::HTTPS) && uri.host && !uri.host.empty? && uri.userinfo.nil?
        raise AuditError, "#{label} url must be an absolute HTTPS URL without userinfo"
      end
      {
        "entry_id" => entry_id,
        "entry_status" => entry_status,
        "source_id" => source_id,
        "source_type" => source_type,
        "publisher" => publisher,
        "authority" => authority,
        "source_checked_at" => checked_at.iso8601,
        "claim" => claim,
        "registered_url" => url
      }
    rescue URI::InvalidURIError => e
      raise AuditError, "#{label} url is invalid: #{e.message.lines.first.to_s.strip}"
    end

    def required_string(mapping, key, label)
      value = mapping.fetch(key)
      raise AuditError, "#{label} #{key} must be a non-empty string" unless value.is_a?(String) && !value.strip.empty?

      value
    end

    def iso_date(value, label)
      raise AuditError, "#{label} must be a quoted ISO date" unless value.is_a?(String)

      parsed = Date.iso8601(value)
      raise AuditError, "#{label} must use YYYY-MM-DD" unless parsed.iso8601 == value

      parsed
    rescue ArgumentError
      raise AuditError, "#{label} is not a valid ISO date"
    end

    def result_for(job, result)
      effective_https = begin
        uri = URI.parse(result.effective_url.to_s)
        uri.is_a?(URI::HTTPS) && uri.host && !uri.host.empty? && uri.userinfo.nil?
      rescue URI::InvalidURIError
        false
      end
      reachable = result.exit_code.zero? && SUCCESS_STATUSES.include?(result.http_status) &&
                  result.ssl_verify_result.zero? && effective_https
      job.merge(
        "effective_url" => result.effective_url,
        "effective_https" => effective_https,
        "http_status" => result.http_status,
        "ssl_verify_result" => result.ssl_verify_result,
        "request_mode" => result.request_mode || "injected-probe",
        "curl_exit_code" => result.exit_code,
        "reachable" => reachable,
        "error" => result.error
      )
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
