#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "digest"
require "json"
require "optparse"
require "tempfile"
require "thread"
require "uri"

require_relative "audit-version-sources"

module ChapterMarkdownLinkAudit
  class AuditError < StandardError; end

  Link = Struct.new(:url, :url_sha256, :safe_url, :host, :occurrences, :structure_error, keyword_init: true)

  module MarkdownExtractor
    module_function

    FRONT_MATTER = /\A---\s*\n.*?\n---\s*(?:\n|\z)/m
    FRONT_MATTER_ID = /^id:\s*['"]?([^'"\s]+)['"]?\s*$/
    HTML_COMMENT = /<!--[\s\S]*?-->/
    FENCE_OPEN = /\A\s{0,3}(?<marker>`{3,}|~{3,})/
    INLINE_CODE = /(?<ticks>`+)[^\n]*?\k<ticks>/
    MARKDOWN_HTTPS_LINK = %r{
      !?\[[^\]\n]*\]
      \(\s*
      (?<target>https://[^\s)\n]+)
      (?:\s+(?:"[^"\n]*"|'[^'\n]*'|\([^\)\n]*\)))?
      \s*\)
    }x

    def chapter_id(text, relative_path)
      front_matter = FRONT_MATTER.match(text)&.[](0)
      raise AuditError, "#{relative_path}: missing YAML front matter" unless front_matter

      match = FRONT_MATTER_ID.match(front_matter)
      raise AuditError, "#{relative_path}: front matter is missing a scalar id" unless match

      match[1]
    end

    def extract(text)
      masked = text.sub(FRONT_MATTER) { |value| mask(value) }
                   .gsub(HTML_COMMENT) { |value| mask(value) }
      masked = mask_fenced_code(masked)
      masked = masked.gsub(INLINE_CODE) { |value| mask(value) }

      occurrences = []
      masked.each_line.with_index(1) do |line, line_number|
        line.to_enum(:scan, MARKDOWN_HTTPS_LINK).each do
          occurrences << { "target" => Regexp.last_match[:target], "line" => line_number }
        end
      end
      occurrences
    end

    def mask_fenced_code(text)
      fence_character = nil
      fence_length = 0
      text.lines.map do |line|
        if fence_character
          closing = /\A\s{0,3}#{Regexp.escape(fence_character)}{#{fence_length},}\s*\z/
          if closing.match?(line.chomp)
            fence_character = nil
            fence_length = 0
          end
          mask(line)
        elsif (opening = FENCE_OPEN.match(line))
          marker = opening[:marker]
          fence_character = marker[0]
          fence_length = marker.length
          mask(line)
        else
          line
        end
      end.join
    end

    def mask(value)
      value.gsub(/[^\n]/, " ")
    end
  end

  class HostLimitedProbeRunner
    attr_reader :probe, :workers, :per_host_limit

    def initialize(probe:, workers:, per_host_limit:)
      @probe = probe
      @workers = Integer(workers)
      @per_host_limit = Integer(per_host_limit)
      raise AuditError, "workers must be between 1 and 8" unless (1..8).cover?(@workers)
      raise AuditError, "per-host limit must be between 1 and 2" unless (1..2).cover?(@per_host_limit)
    end

    def call(links)
      queue = Queue.new
      links.each_with_index { |link, index| queue << [index, link] }
      results = Array.new(links.length)
      errors = Array.new(links.length)
      host_mutex = Mutex.new
      active_by_host = Hash.new(0)

      threads = [workers, links.length].min.times.map do
        Thread.new do
          loop do
            index, link = queue.pop(true)
            acquired = host_mutex.synchronize do
              next false if active_by_host.fetch(link.host, 0) >= per_host_limit

              active_by_host[link.host] += 1
              true
            end
            unless acquired
              queue << [index, link]
              sleep 0.001
              next
            end
            begin
              results[index] = probe.call(link.url)
            rescue StandardError => e
              errors[index] = e
            ensure
              host_mutex.synchronize do
                active_by_host[link.host] -= 1
              end
            end
          rescue ThreadError
            break
          end
        end.tap { |thread| thread.report_on_exception = false }
      end
      threads.each(&:value)
      first_error = errors.compact.first
      raise AuditError, "probe worker failed (#{first_error.class})" if first_error

      results
    end
  end

  class Auditor
    MODES = %w[structure-only live].freeze
    ACCEPTED_HTTP_STATUSES = [200, 206].freeze
    MANUAL_REVIEW_HTTP_STATUSES = [401, 403, 405, 416, 429].freeze
    TRANSPORT_INCONCLUSIVE_HTTP_STATUSES = [202].freeze
    # Explicit allowlist: these codes describe an inconclusive network/transport
    # observation, not proof that the cited HTTPS resource is missing.
    TRANSPORT_INCONCLUSIVE_CURL_EXIT_CODES = [5, 6, 7, 16, 28, 35, 52, 55, 56, 92].freeze
    CERTIFICATE_HARD_FAILURE_CURL_EXIT_CODES = [51, 58, 59, 60, 66, 77, 82, 83, 90, 91].freeze

    attr_reader :root, :mode, :probe, :workers, :per_host_limit, :connect_timeout, :max_time

    def initialize(
      root:,
      mode: "structure-only",
      probe: nil,
      workers: 8,
      per_host_limit: 2,
      connect_timeout: 10,
      max_time: 25
    )
      @root = File.realpath(root)
      @mode = mode.to_s
      @workers = Integer(workers)
      @per_host_limit = Integer(per_host_limit)
      @connect_timeout = Integer(connect_timeout)
      @max_time = Integer(max_time)
      raise AuditError, "mode must be structure-only or live" unless MODES.include?(@mode)
      raise AuditError, "workers must be between 1 and 8" unless (1..8).cover?(@workers)
      raise AuditError, "per-host limit must be between 1 and 2" unless (1..2).cover?(@per_host_limit)
      raise AuditError, "connect timeout must be positive" unless @connect_timeout.positive?
      raise AuditError, "max time must be positive" unless @max_time.positive?

      @probe = probe
      raise AuditError, "live mode requires a probe" if @mode == "live" && @probe.nil?
    end

    def report(checked_at:)
      checked_date = Date.iso8601(checked_at.to_s).iso8601
      chapters, links, corpus_sha256, occurrence_count = inventory
      valid_links = links.reject(&:structure_error)
      probe_results = if mode == "live"
                        HostLimitedProbeRunner.new(
                          probe: probe,
                          workers: workers,
                          per_host_limit: per_host_limit
                        ).call(valid_links)
                      else
                        []
                      end
      probe_by_sha = valid_links.each_with_index.to_h do |link, index|
        [link.url_sha256, probe_results[index]]
      end

      link_documents = links.map do |link|
        result = probe_by_sha[link.url_sha256]
        link_document(link, result)
      end
      outcome_counts = link_documents.group_by { |item| item.fetch("outcome") }
                                     .transform_values(&:length)
                                     .sort.to_h
      http_statuses = link_documents.each_with_object([]) do |item, memo|
        status = item.dig("probe", "http_status")
        memo << status unless status.nil?
      end
      http_status_counts = http_statuses.group_by(&:to_s)
                                           .transform_values(&:length)
                                           .sort.to_h
      failed_items = link_documents.select { |item| item.fetch("outcome") == "failed" }
      manual_items = link_documents.select { |item| item.fetch("outcome") == "manual-review" }
      transport_inconclusive_items = manual_items.select do |item|
        item.fetch("reason").start_with?("transport-inconclusive-")
      end
      status = if failed_items.any?
                 "failed"
               elsif manual_items.any?
                 "needs-review"
               else
                 "passed"
               end

      {
        "schema_version" => 1,
        "audit_id" => "p9-chapter-markdown-direct-links",
        "generated_by" => "scripts/audit-chapter-markdown-links.rb",
        "checked_at" => checked_date,
        "mode" => mode,
        "status" => status,
        "evidence_classification" => {
          "state" => "observed-unreviewed",
          "kind" => "machine-only-not-learner-evidence",
          "promotion" => "forbidden-without-human-review"
        },
        "chapter_glob" => "book/volume-*/chapters/ch.*.md",
        "corpus_sha256" => corpus_sha256,
        "summary" => {
          "chapter_count" => chapters.length,
          "markdown_https_occurrence_count" => occurrence_count,
          "unique_markdown_https_target_count" => links.length,
          "host_count" => valid_links.map(&:host).uniq.length,
          "structure_invalid_count" => links.length - valid_links.length,
          "http_200_count" => http_status_counts.fetch("200", 0),
          "http_206_count" => http_status_counts.fetch("206", 0),
          "passed_count" => outcome_counts.fetch("passed", 0),
          "failure_count" => failed_items.length,
          "manual_review_count" => manual_items.length,
          "transport_inconclusive_count" => transport_inconclusive_items.length,
          "not_probed_count" => outcome_counts.fetch("not-probed", 0)
        },
        "http_status_counts" => http_status_counts,
        "outcome_counts" => outcome_counts,
        "probe_policy" => {
          "implementation" => mode == "live" ? probe.class.name : nil,
          "total_concurrency_limit" => workers,
          "per_host_concurrency_limit" => per_host_limit,
          "connect_timeout_seconds" => connect_timeout,
          "max_time_seconds" => max_time,
          "primary_request" => "GET with Range: bytes=0-0",
          "get_fallback_http_statuses" => [403, 405, 416],
          "accepted_http_statuses" => ACCEPTED_HTTP_STATUSES,
          "manual_review_http_statuses" => MANUAL_REVIEW_HTTP_STATUSES,
          "transport_inconclusive_http_statuses" => TRANSPORT_INCONCLUSIVE_HTTP_STATUSES,
          "transport_inconclusive_curl_exit_codes" => TRANSPORT_INCONCLUSIVE_CURL_EXIT_CODES,
          "certificate_hard_failure_curl_exit_codes" => CERTIFICATE_HARD_FAILURE_CURL_EXIT_CODES,
          "redirect_protocol_policy" => "HTTPS only; HTTP downgrade is blocked by curl and rejected from injected results"
        },
        "extraction_policy" => {
          "included" => "inline Markdown link and image destinations beginning with https://",
          "excluded_regions" => ["YAML front matter", "fenced code", "inline code", "HTML comments"],
          "deduplication" => "exact target string across all chapters"
        },
        "manual_review_items" => manual_items.map { |item| compact_issue(item) },
        "failed_items" => failed_items.map { |item| compact_issue(item) },
        "links" => link_documents,
        "replay_commands" => {
          "structure_only" => "ruby scripts/audit-chapter-markdown-links.rb --mode structure-only --checked-at #{checked_date} --root . --output /tmp/factorycare-chapter-links-structure.json --pretty",
          "live" => "ruby scripts/audit-chapter-markdown-links.rb --mode live --checked-at #{checked_date} --root . --output /tmp/factorycare-chapter-links-live.json --pretty"
        },
        "evidence_boundary" => "Structure-only mode proves deterministic extraction and HTTPS target syntax only. Live mode records one bounded read-only observation per exact target. HTTP 200/206 does not prove source authority, citation entailment, page meaning, content truth, or future availability. HTTP 202 and the explicit network-transport curl allowlist are transport-inconclusive and require human review; 401/403/405/416/429 also require human review. Certificate failures, HTTPS downgrade, unknown nonzero curl exits, and other non-accepted HTTP statuses remain failures. Manual-review results are never auto-passed."
      }
    rescue ArgumentError => e
      raise AuditError, "checked-at must be an ISO date: #{e.message.lines.first.to_s.strip}"
    rescue Errno::ENOENT, URI::InvalidURIError => e
      raise AuditError, e.message.lines.first.to_s.strip
    end

    private

    def inventory
      chapter_paths = Dir.glob(File.join(root, "book/volume-*/chapters/ch.*.md")).sort
      raise AuditError, "no chapter Markdown files found" if chapter_paths.empty?

      occurrences_by_url = Hash.new { |hash, key| hash[key] = [] }
      chapter_records = []
      seen_ids = {}
      chapter_paths.each do |path|
        resolved = File.realpath(path)
        unless resolved.start_with?(root + File::SEPARATOR)
          raise AuditError, "chapter path escapes repository root: #{path}"
        end

        relative = path.delete_prefix(root + File::SEPARATOR)
        bytes = File.binread(resolved)
        text = bytes.force_encoding(Encoding::UTF_8)
        raise AuditError, "#{relative}: invalid UTF-8" unless text.valid_encoding?

        chapter_id = MarkdownExtractor.chapter_id(text, relative)
        raise AuditError, "duplicate chapter id: #{chapter_id}" if seen_ids.key?(chapter_id)

        seen_ids[chapter_id] = true
        chapter_sha256 = Digest::SHA256.hexdigest(bytes)
        chapter_records << [relative, chapter_id, chapter_sha256]
        MarkdownExtractor.extract(text).each do |occurrence|
          occurrences_by_url[occurrence.fetch("target")] << {
            "chapter_id" => chapter_id,
            "path" => relative,
            "line" => occurrence.fetch("line")
          }
        end
      end

      corpus_material = chapter_records.map { |path, id, digest| [path, id, digest].join("\0") }.join("\n")
      links = occurrences_by_url.keys.sort.map do |url|
        build_link(url, occurrences_by_url.fetch(url))
      end
      [chapter_records, links, Digest::SHA256.hexdigest(corpus_material), occurrences_by_url.values.sum(&:length)]
    end

    def build_link(url, occurrences)
      digest = Digest::SHA256.hexdigest(url)
      uri = URI.parse(url)
      valid = uri.is_a?(URI::HTTPS) && uri.host && !uri.host.empty? && uri.userinfo.nil?
      error = valid ? nil : "target must be an absolute HTTPS URL without userinfo"
      Link.new(
        url: url,
        url_sha256: digest,
        safe_url: safe_url(url),
        host: valid ? uri.host.downcase : nil,
        occurrences: occurrences.sort_by { |item| [item.fetch("chapter_id"), item.fetch("line"), item.fetch("path")] },
        structure_error: error
      )
    rescue URI::InvalidURIError => e
      Link.new(
        url: url,
        url_sha256: digest,
        safe_url: nil,
        host: nil,
        occurrences: occurrences,
        structure_error: "invalid HTTPS target: #{e.message.lines.first.to_s.strip}"
      )
    end

    def link_document(link, result)
      base = {
        "url" => link.safe_url,
        "url_sha256" => link.url_sha256,
        "query_redacted" => query_present?(link.url),
        "host" => link.host,
        "occurrence_count" => link.occurrences.length,
        "occurrences" => link.occurrences,
        "structure_valid" => link.structure_error.nil?,
        "structure_error" => link.structure_error
      }
      return base.merge("outcome" => "failed", "reason" => "invalid-target", "probe" => nil) if link.structure_error
      return base.merge("outcome" => "not-probed", "reason" => "structure-only-mode", "probe" => nil) unless result

      effective_https = https_without_userinfo?(result.effective_url)
      outcome, reason = classify_probe(result, effective_https)
      base.merge(
        "outcome" => outcome,
        "reason" => reason,
        "probe" => {
          "http_status" => result.http_status,
          "curl_exit_code" => result.exit_code,
          "ssl_verify_result" => result.ssl_verify_result,
          "request_mode" => result.request_mode || "injected-probe",
          "effective_url" => safe_url(result.effective_url),
          "effective_https" => effective_https,
          "error" => sanitize_error(result.error)
        }
      )
    end

    def classify_probe(result, effective_https)
      return ["failed", "effective-url-is-not-https"] unless result.effective_url.to_s.empty? || effective_https
      if CERTIFICATE_HARD_FAILURE_CURL_EXIT_CODES.include?(result.exit_code)
        return ["failed", "certificate-validation-curl-exit-#{result.exit_code}"]
      end
      if TRANSPORT_INCONCLUSIVE_CURL_EXIT_CODES.include?(result.exit_code)
        return ["manual-review", "transport-inconclusive-curl-exit-#{result.exit_code}"]
      end
      return ["failed", "curl-exit-#{result.exit_code}"] unless result.exit_code.zero?
      return ["failed", "tls-verification-failed"] unless result.ssl_verify_result.zero?
      return ["failed", "missing-effective-https-url"] unless effective_https
      return ["passed", "http-#{result.http_status}"] if ACCEPTED_HTTP_STATUSES.include?(result.http_status)
      if TRANSPORT_INCONCLUSIVE_HTTP_STATUSES.include?(result.http_status)
        return ["manual-review", "transport-inconclusive-http-#{result.http_status}"]
      end
      return ["manual-review", "http-#{result.http_status}"] if MANUAL_REVIEW_HTTP_STATUSES.include?(result.http_status)

      ["failed", "http-#{result.http_status}-not-accepted"]
    end

    def compact_issue(item)
      {
        "url" => item.fetch("url"),
        "url_sha256" => item.fetch("url_sha256"),
        "host" => item.fetch("host"),
        "reason" => item.fetch("reason"),
        "http_status" => item.dig("probe", "http_status"),
        "curl_exit_code" => item.dig("probe", "curl_exit_code"),
        "chapter_ids" => item.fetch("occurrences").map { |occurrence| occurrence.fetch("chapter_id") }.uniq.sort
      }
    end

    def https_without_userinfo?(value)
      uri = URI.parse(value.to_s)
      uri.is_a?(URI::HTTPS) && uri.host && !uri.host.empty? && uri.userinfo.nil?
    rescue URI::InvalidURIError
      false
    end

    def safe_url(value)
      uri = URI.parse(value.to_s)
      return nil unless uri.is_a?(URI::HTTPS) && uri.host && !uri.host.empty?

      clean = uri.dup
      clean.user = nil
      clean.password = nil
      clean.query = nil if clean.query
      clean.to_s
    rescue URI::InvalidURIError
      nil
    end

    def query_present?(value)
      !URI.parse(value).query.nil?
    rescue URI::InvalidURIError
      false
    end

    def sanitize_error(value)
      text = value.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")
                     .lines.first.to_s.strip[0, 300]
      text.gsub(%r{https://[^\s]+}) { |url| safe_url(url) || "[redacted-url]" }
    end
  end

  module CLI
    module_function

    def run(argv, stdout: $stdout, stderr: $stderr, probe: nil)
      options = {
        root: File.expand_path("..", __dir__),
        mode: "structure-only",
        checked_at: nil,
        output: nil,
        pretty: false,
        workers: 8,
        per_host_limit: 2,
        connect_timeout: 10,
        max_time: 25,
        curl: "curl"
      }
      parser = OptionParser.new do |command|
        command.banner = "Usage: ruby scripts/audit-chapter-markdown-links.rb --checked-at YYYY-MM-DD [options]"
        command.on("--root PATH", "Repository root") { |value| options[:root] = value }
        command.on("--mode MODE", "structure-only or live") { |value| options[:mode] = value }
        command.on("--checked-at DATE", "Explicit evidence date (required)") { |value| options[:checked_at] = value }
        command.on("--output PATH", "Write deterministic JSON report") { |value| options[:output] = value }
        command.on("--workers N", Integer, "Total concurrency, maximum 8") { |value| options[:workers] = value }
        command.on("--per-host N", Integer, "Per-host concurrency, maximum 2") { |value| options[:per_host_limit] = value }
        command.on("--connect-timeout N", Integer, "curl connect timeout in seconds") { |value| options[:connect_timeout] = value }
        command.on("--max-time N", Integer, "curl total timeout per request in seconds") { |value| options[:max_time] = value }
        command.on("--curl PATH", "curl executable") { |value| options[:curl] = value }
        command.on("--pretty", "Pretty-print JSON") { options[:pretty] = true }
      end
      parser.parse!(argv)
      raise AuditError, "unexpected positional arguments" unless argv.empty?
      raise AuditError, "--checked-at is required" if options[:checked_at].to_s.empty?

      selected_probe = probe
      if options.fetch(:mode) == "live" && selected_probe.nil?
        selected_probe = VersionSourceAudit::CurlProbe.new(
          curl: options.fetch(:curl),
          connect_timeout: options.fetch(:connect_timeout),
          max_time: options.fetch(:max_time)
        )
      end
      report = Auditor.new(
        root: options.fetch(:root),
        mode: options.fetch(:mode),
        probe: selected_probe,
        workers: options.fetch(:workers),
        per_host_limit: options.fetch(:per_host_limit),
        connect_timeout: options.fetch(:connect_timeout),
        max_time: options.fetch(:max_time)
      ).report(checked_at: options.fetch(:checked_at))
      canonical = canonicalize(report)
      bytes = options.fetch(:pretty) ? JSON.pretty_generate(canonical) + "\n" : JSON.generate(canonical) + "\n"
      if options[:output]
        destination = File.expand_path(options.fetch(:output))
        atomic_write(destination, bytes)
        stdout.puts "CHAPTER MARKDOWN LINK AUDIT #{report.fetch('status').upcase}"
        stdout.puts "report=#{destination}"
      else
        stdout.write(bytes)
      end
      report.fetch("status") == "passed" ? 0 : 1
    rescue OptionParser::ParseError, AuditError, VersionSourceAudit::AuditError, Errno::ENOENT => e
      stderr.puts "CHAPTER MARKDOWN LINK AUDIT FAILED: #{e.message.lines.first.to_s.strip}"
      2
    end

    def canonicalize(value)
      case value
      when Hash
        value.keys.sort.to_h { |key| [key, canonicalize(value.fetch(key))] }
      when Array
        value.map { |item| canonicalize(item) }
      else
        value
      end
    end

    def atomic_write(destination, bytes)
      directory = File.dirname(destination)
      raise AuditError, "output directory does not exist: #{directory}" unless Dir.exist?(directory)

      temporary = Tempfile.new([".chapter-markdown-links-", ".tmp"], directory)
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

exit ChapterMarkdownLinkAudit::CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
