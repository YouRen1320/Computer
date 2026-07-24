#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "digest"
require "json"
require "optparse"
require "pathname"
require "tempfile"
require "thread"
require "uri"

require_relative "audit-version-sources"
require_relative "../verification/lib/machine_report_schema"

module ChapterMarkdownLinkAudit
  class AuditError < StandardError; end

  PLAN_PATH = "build/publication/internal-complete/publication-plan-v2.json"
  OUTPUT_MANIFEST_PATH = "build/publication/internal-complete/publication-output-manifest-v2.json"
  REPORT_SCHEMA_PATH = "schemas/chapter-pandoc-link-audit-v2.schema.json"
  CANONICAL_AST_OUTPUT_PATH = "ast/book.json"
  PROFILE_ID = "internal-complete"
  PLAN_ID = "publication-plan.internal-complete"
  MANIFEST_ID = "publication-output.internal-complete"
  OUTPUT_ROOT = "build/publication/internal-complete"

  Occurrence = Struct.new(
    :node_kind, :source_chapter_id, :ast_pointer, :raw_target,
    keyword_init: true
  )
  Target = Struct.new(
    :raw_target, :target_sha256, :safe_target, :host, :target_scope,
    :query_redacted, :fragment_redacted, :occurrences, :structure_error,
    keyword_init: true
  )

  # JSON.parse normally keeps the last duplicate member. Publication evidence
  # cannot permit that ambiguity, so all three bound JSON inputs are strict.
  module StrictJson
    class DuplicateMemberError < StandardError; end

    class Object < Hash
      def []=(key, value)
        raise DuplicateMemberError, "duplicate JSON object member #{key.inspect}" if key?(key)

        super
      end
    end

    module_function

    def parse(bytes, label)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      raise AuditError, "#{label}: invalid UTF-8" unless text.valid_encoding?

      JSON.parse(text, object_class: Object)
    rescue JSON::ParserError, DuplicateMemberError => e
      raise AuditError, "#{label}: invalid strict JSON (#{e.class.name.split('::').last})"
    end
  end

  # Reads only repository-relative, non-symlink regular files and retains the
  # exact bytes so a concurrent rewrite is detected before a report is emitted.
  class RepositoryReader
    attr_reader :root, :snapshots

    def initialize(root)
      @root = File.realpath(root)
      @snapshots = {}
    end

    def read(relative)
      validate_relative!(relative)
      reject_symlink_components!(relative)
      absolute = File.expand_path(relative, root)
      unless absolute.start_with?(root + File::SEPARATOR)
        raise AuditError, "#{relative}: path escapes repository root"
      end
      stat = File.lstat(absolute)
      raise AuditError, "#{relative}: symbolic links are forbidden" if stat.symlink?
      raise AuditError, "#{relative}: expected a regular file" unless stat.file?

      flags = File::RDONLY
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      bytes = File.open(absolute, flags) do |file|
        opened = file.stat
        unless opened.file? && opened.dev == stat.dev && opened.ino == stat.ino
          raise AuditError, "#{relative}: file changed while opening"
        end
        file.binmode
        file.read
      end
      snapshots[relative] = bytes
      bytes
    rescue Errno::ENOENT
      raise AuditError, "#{relative}: required file is missing"
    rescue Errno::ELOOP
      raise AuditError, "#{relative}: symbolic-link path is forbidden"
    end

    def verify_unchanged!
      snapshots.each do |relative, expected|
        reject_symlink_components!(relative)
        actual = File.binread(File.join(root, relative))
        raise AuditError, "#{relative}: input drifted during audit" unless actual == expected
      end
      true
    rescue Errno::ENOENT
      raise AuditError, "bound publication input disappeared during audit"
    end

    private

    def validate_relative!(relative)
      unless relative.is_a?(String) && !relative.empty? && !Pathname(relative).absolute? &&
             !relative.include?("\\") &&
             relative.split("/", -1).none? { |part| part.empty? || part == "." || part == ".." }
        raise AuditError, "publication input path must be a safe repository-relative path"
      end
    end

    def reject_symlink_components!(relative)
      cursor = root
      relative.split("/").each do |part|
        cursor = File.join(cursor, part)
        break unless File.exist?(cursor) || File.symlink?(cursor)

        raise AuditError, "#{relative}: symbolic-link path is forbidden" if File.lstat(cursor).symlink?
      end
    end
  end

  # Loads the P8 plan, output manifest and the exact canonical-AST output entry.
  # No fallback to source Markdown or a nearby AST is allowed.
  class BoundPublication
    attr_reader :reader, :plan, :manifest, :ast, :plan_bytes, :manifest_bytes,
                :ast_bytes, :ast_entry, :chapter_ids

    def initialize(root)
      @reader = RepositoryReader.new(root)
    end

    def load!
      @plan_bytes = reader.read(PLAN_PATH)
      @manifest_bytes = reader.read(OUTPUT_MANIFEST_PATH)
      @plan = StrictJson.parse(plan_bytes, PLAN_PATH)
      @manifest = StrictJson.parse(manifest_bytes, OUTPUT_MANIFEST_PATH)
      validate_plan_and_manifest!

      ast_repository_path = File.join(OUTPUT_ROOT, ast_entry.fetch("path"))
      @ast_bytes = reader.read(ast_repository_path)
      validate_ast_output_entry!(ast_repository_path)
      @ast = StrictJson.parse(ast_bytes, ast_repository_path)
      validate_ast_shape!
      reader.verify_unchanged!
      self
    rescue KeyError, TypeError => e
      raise AuditError, "P8 publication binding has an invalid shape (#{e.class})"
    end

    def binding_document
      {
        "profile_id" => PROFILE_ID,
        "plan_path" => PLAN_PATH,
        "plan_sha256" => Digest::SHA256.hexdigest(plan_bytes),
        "output_manifest_path" => OUTPUT_MANIFEST_PATH,
        "output_manifest_sha256" => Digest::SHA256.hexdigest(manifest_bytes),
        "manifest_plan_sha256" => manifest.fetch("plan_sha256"),
        "canonical_ast" => {
          "repository_path" => File.join(OUTPUT_ROOT, ast_entry.fetch("path")),
          "output_path" => ast_entry.fetch("path"),
          "kind" => ast_entry.fetch("kind"),
          "format" => ast_entry.fetch("format"),
          "media_type" => ast_entry.fetch("media_type"),
          "distribution" => ast_entry.fetch("distribution"),
          "sha256" => ast_entry.fetch("sha256"),
          "size_bytes" => ast_entry.fetch("size_bytes")
        },
        "pandoc_api_version" => ast.fetch("pandoc-api-version").join(".")
      }
    end

    private

    def validate_plan_and_manifest!
      require_value!(plan, "schema_version", 2, "plan")
      require_value!(plan, "plan_id", PLAN_ID, "plan")
      require_value!(plan, "profile_id", PROFILE_ID, "plan")
      require_value!(plan, "output_root", OUTPUT_ROOT, "plan")
      require_value!(manifest, "schema_version", 2, "output manifest")
      require_value!(manifest, "manifest_id", MANIFEST_ID, "output manifest")
      require_value!(manifest, "plan_id", PLAN_ID, "output manifest")
      require_value!(manifest, "profile_id", PROFILE_ID, "output manifest")

      actual_plan_sha = Digest::SHA256.hexdigest(plan_bytes)
      unless manifest.fetch("plan_sha256") == actual_plan_sha
        raise AuditError, "P8 output manifest plan_sha256 does not match current plan bytes"
      end

      planned_outputs = require_array!(plan, "planned_outputs", "plan")
      outputs = require_array!(manifest, "outputs", "output manifest")
      validate_unique_output_paths!(planned_outputs, "plan")
      validate_unique_output_paths!(outputs, "output manifest")
      unless manifest.fetch("output_count") == outputs.length
        raise AuditError, "P8 output manifest output_count does not match outputs"
      end

      planned = canonical_entries(planned_outputs, "plan")
      emitted = canonical_entries(outputs, "output manifest")
      raise AuditError, "P8 plan must contain exactly one canonical AST output" unless planned.length == 1
      raise AuditError, "P8 output manifest must contain exactly one canonical AST output" unless emitted.length == 1

      planned_entry = planned.first
      @ast_entry = emitted.first
      %w[path kind format distribution].each do |field|
        unless planned_entry.fetch(field) == ast_entry.fetch(field)
          raise AuditError, "P8 canonical AST #{field} differs between plan and output manifest"
        end
      end

      chapters = require_array!(plan, "chapters", "plan")
      @chapter_ids = chapters.map { |chapter| chapter.fetch("id") }
      if chapter_ids.empty? || chapter_ids.uniq.length != chapter_ids.length ||
         chapter_ids.any? { |id| !id.is_a?(String) || !id.match?(/\Ach\.[a-z0-9.-]+\z/) }
        raise AuditError, "P8 plan chapter IDs must be non-empty, unique and valid"
      end
    end

    def validate_ast_output_entry!(repository_path)
      unless ast_entry.fetch("path") == CANONICAL_AST_OUTPUT_PATH &&
             ast_entry.fetch("kind") == "canonical-ast" &&
             ast_entry.fetch("format") == "internal" &&
             ast_entry.fetch("media_type") == "application/json" &&
             ast_entry.fetch("distribution") == "internal-review-candidate"
        raise AuditError, "P8 canonical AST output entry has unsupported semantics"
      end
      unless ast_entry.fetch("sha256") == Digest::SHA256.hexdigest(ast_bytes)
        raise AuditError, "#{repository_path}: bytes drift from output manifest sha256"
      end
      unless ast_entry.fetch("size_bytes") == ast_bytes.bytesize
        raise AuditError, "#{repository_path}: size drifts from output manifest"
      end
    end

    def validate_ast_shape!
      unless ast.is_a?(Hash) && ast.keys.sort == %w[blocks meta pandoc-api-version] &&
             ast.fetch("pandoc-api-version").is_a?(Array) &&
             ast.fetch("pandoc-api-version").all? { |value| value.is_a?(Integer) && value >= 0 } &&
             ast.fetch("meta").is_a?(Hash) && ast.fetch("blocks").is_a?(Array)
        raise AuditError, "canonical Pandoc AST has an invalid root shape"
      end
    end

    def require_value!(document, key, expected, label)
      return if document.fetch(key) == expected

      raise AuditError, "P8 #{label} #{key} is unsupported"
    end

    def require_array!(document, key, label)
      value = document.fetch(key)
      raise AuditError, "P8 #{label} #{key} must be an array" unless value.is_a?(Array)

      value
    end

    def validate_unique_output_paths!(outputs, label)
      paths = outputs.map { |entry| entry.fetch("path") }
      unless paths.all? { |path| path.is_a?(String) } && paths.uniq.length == paths.length
        raise AuditError, "P8 #{label} output paths must be unique"
      end
    end

    def canonical_entries(outputs, label)
      outputs.select do |entry|
        unless entry.is_a?(Hash)
          raise AuditError, "P8 #{label} output entries must be objects"
        end
        entry["path"] == CANONICAL_AST_OUTPUT_PATH || entry["kind"] == "canonical-ast"
      end
    end
  end

  module PandocAstInventory
    module_function

    def extract(ast, expected_chapter_ids)
      occurrences = []
      chapter_ids = []
      chapter_depth = 0
      stack = [[ast, "", nil, false]]
      until stack.empty?
        node, pointer, chapter_id, leaving_chapter = stack.pop
        if leaving_chapter
          chapter_depth -= 1
          next
        end

        case node
        when Hash
          if chapter_div?(node)
            raise AuditError, "canonical AST contains nested chapter containers" if chapter_depth.positive?

            chapter_id = chapter_id_for(node)
            chapter_ids << chapter_id
            chapter_depth += 1
            stack << [nil, pointer, nil, true]
          end
          if %w[Link Image].include?(node["t"])
            raise AuditError, "#{display_pointer(pointer)}: Link/Image node is outside a chapter" unless chapter_id

            occurrences << occurrence_for(node, pointer, chapter_id)
          end
          node.keys.reverse_each do |key|
            stack << [node.fetch(key), pointer_child(pointer, key), chapter_id, false]
          end
        when Array
          (node.length - 1).downto(0) do |index|
            stack << [node[index], pointer_child(pointer, index), chapter_id, false]
          end
        end
      end

      unless chapter_depth.zero?
        raise AuditError, "canonical AST chapter traversal did not close cleanly"
      end
      unless chapter_ids == expected_chapter_ids
        raise AuditError, "canonical AST chapter order/identity differs from the bound P8 plan"
      end
      pointers = occurrences.map(&:ast_pointer)
      raise AuditError, "canonical AST produced duplicate Link/Image pointers" unless pointers.uniq.length == pointers.length

      occurrences
    end

    def chapter_div?(node)
      return false unless node["t"] == "Div" && node["c"].is_a?(Array)

      attr = node["c"][0]
      attr.is_a?(Array) && attr[1].is_a?(Array) && attr[1].include?("chapter")
    end

    def chapter_id_for(node)
      attr = node.fetch("c").fetch(0)
      key_values = attr.fetch(2)
      unless key_values.is_a?(Array) && key_values.all? do |pair|
        pair.is_a?(Array) && pair.length == 2 && pair.all? { |value| value.is_a?(String) }
      end
        raise AuditError, "canonical AST chapter attributes are malformed"
      end
      values = key_values.each_with_object({}) do |pair, memo|
        raise AuditError, "canonical AST chapter attribute is duplicated" if memo.key?(pair[0])

        memo[pair[0]] = pair[1]
      end
      chapter_id = values["data-chapter-id"] || attr[0]
      unless chapter_id.is_a?(String) && chapter_id.match?(/\Ach\.[a-z0-9.-]+\z/)
        raise AuditError, "canonical AST chapter has an invalid ID"
      end

      chapter_id
    end

    def occurrence_for(node, pointer, chapter_id)
      content = node["c"]
      target = content.is_a?(Array) ? content[2] : nil
      unless content.is_a?(Array) && content.length == 3 && target.is_a?(Array) &&
             target.length == 2 && target.all? { |value| value.is_a?(String) }
        raise AuditError, "#{display_pointer(pointer)}: malformed Pandoc #{node['t']} node"
      end

      Occurrence.new(
        node_kind: node.fetch("t"),
        source_chapter_id: chapter_id,
        ast_pointer: display_pointer(pointer),
        raw_target: target.fetch(0)
      )
    end

    def pointer_child(pointer, part)
      token = part.to_s.gsub("~", "~0").gsub("/", "~1")
      "#{pointer}/#{token}"
    end

    def display_pointer(pointer)
      pointer.empty? ? "/" : pointer
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

    def call(targets)
      queue = Queue.new
      targets.each_with_index { |target, index| queue << [index, target] }
      results = Array.new(targets.length)
      errors = Array.new(targets.length)
      host_mutex = Mutex.new
      active_by_host = Hash.new(0)

      threads = [workers, targets.length].min.times.map do
        Thread.new do
          loop do
            index, target = queue.pop(true)
            acquired = host_mutex.synchronize do
              next false if active_by_host.fetch(target.host, 0) >= per_host_limit

              active_by_host[target.host] += 1
              true
            end
            unless acquired
              queue << [index, target]
              sleep 0.001
              next
            end
            begin
              results[index] = probe.call(target.raw_target)
            rescue StandardError => e
              errors[index] = e
            ensure
              host_mutex.synchronize { active_by_host[target.host] -= 1 }
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

    def report(observation_date:)
      date = Date.iso8601(observation_date.to_s).iso8601
      publication = BoundPublication.new(root).load!
      occurrences = PandocAstInventory.extract(publication.ast, publication.chapter_ids)
      targets = build_targets(occurrences)
      probeable = targets.select { |target| target.target_scope == "external-https" && target.structure_error.nil? }
      probe_results = if mode == "live"
                        HostLimitedProbeRunner.new(
                          probe: probe,
                          workers: workers,
                          per_host_limit: per_host_limit
                        ).call(probeable)
                      else
                        []
                      end
      probe_by_sha = probeable.each_with_index.each_with_object({}) do |(target, index), memo|
        memo[target.target_sha256] = probe_results[index]
      end
      target_documents = targets.map { |target| target_document(target, probe_by_sha[target.target_sha256]) }
      outcome_counts = fixed_counts(
        count_by(target_documents, "outcome"),
        %w[failed manual-review not-applicable not-probed passed]
      )
      scope_counts = fixed_counts(
        count_by(target_documents, "target_scope"),
        %w[embedded-resource external-https internal-reference invalid-external relative-reference]
      )
      node_kind_counts = fixed_counts(count_occurrences(occurrences, &:node_kind), %w[Image Link])
      http_status_counts = target_documents.each_with_object(Hash.new(0)) do |item, memo|
        status = item.dig("probe", "http_status")
        memo[status.to_s] += 1 unless status.nil?
      end.sort.to_h
      failed_items = target_documents.select { |item| item.fetch("outcome") == "failed" }
      manual_items = target_documents.select { |item| item.fetch("outcome") == "manual-review" }
      transport_items = manual_items.select { |item| item.fetch("reason").start_with?("transport-inconclusive-") }
      status = if failed_items.any?
                 "failed"
               elsif manual_items.any?
                 "needs-review"
               else
                 "passed"
               end

      report = {
        "schema_version" => 2,
        "audit_id" => "p9-pandoc-ast-link-audit",
        "generated_by" => "scripts/audit-chapter-markdown-links.rb",
        "observation_date" => date,
        "mode" => mode,
        "status" => status,
        "evidence_classification" => {
          "state" => "observed-unreviewed",
          "kind" => "machine-only-not-learner-evidence",
          "promotion" => "forbidden-without-human-review"
        },
        "publication_binding" => publication.binding_document,
        "summary" => {
          "planned_chapter_count" => publication.chapter_ids.length,
          "ast_chapter_count" => publication.chapter_ids.length,
          "ast_node_count" => occurrences.length,
          "ast_link_node_count" => node_kind_counts.fetch("Link", 0),
          "ast_image_node_count" => node_kind_counts.fetch("Image", 0),
          "external_https_occurrence_count" => occurrences.count { |item| target_scope(item.raw_target) == "external-https" },
          "unique_target_count" => targets.length,
          "unique_external_https_target_count" => scope_counts.fetch("external-https", 0),
          "internal_reference_target_count" => scope_counts.fetch("internal-reference", 0),
          "relative_reference_target_count" => scope_counts.fetch("relative-reference", 0),
          "embedded_resource_target_count" => scope_counts.fetch("embedded-resource", 0),
          "host_count" => probeable.map(&:host).uniq.length,
          "structure_invalid_count" => targets.count { |target| !target.structure_error.nil? },
          "http_200_count" => http_status_counts.fetch("200", 0),
          "http_206_count" => http_status_counts.fetch("206", 0),
          "passed_count" => outcome_counts.fetch("passed", 0),
          "failure_count" => failed_items.length,
          "manual_review_count" => manual_items.length,
          "transport_inconclusive_count" => transport_items.length,
          "not_probed_count" => outcome_counts.fetch("not-probed", 0),
          "not_applicable_count" => outcome_counts.fetch("not-applicable", 0)
        },
        "node_kind_counts" => node_kind_counts,
        "target_scope_counts" => scope_counts,
        "http_status_counts" => http_status_counts,
        "outcome_counts" => outcome_counts,
        "probe_policy" => probe_policy,
        "extraction_policy" => extraction_policy(node_kind_counts.fetch("Image", 0)),
        "manual_review_items" => manual_items.map { |item| compact_issue(item) },
        "failed_items" => failed_items.map { |item| compact_issue(item) },
        "targets" => target_documents,
        "replay_commands" => replay_commands(date),
        "evidence_boundary" => evidence_boundary
      }
      validate_report!(report)
      publication.reader.verify_unchanged!
      report
    rescue ArgumentError => e
      raise AuditError, "observation-date must be an ISO date: #{e.message.lines.first.to_s.strip}"
    rescue URI::InvalidURIError => e
      raise AuditError, "canonical AST contains an invalid target (#{e.class})"
    end

    private

    def build_targets(occurrences)
      grouped = occurrences.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |occurrence, memo|
        memo[occurrence.raw_target] << occurrence
      end
      grouped.keys.sort_by { |raw| Digest::SHA256.hexdigest(raw) }.map do |raw|
        scope = target_scope(raw)
        parsed = parse_target(raw)
        error = structure_error(raw, scope, parsed)
        Target.new(
          raw_target: raw,
          target_sha256: Digest::SHA256.hexdigest(raw),
          safe_target: safe_target(raw, scope, parsed),
          host: scope == "external-https" && error.nil? ? parsed.host.downcase : nil,
          target_scope: scope,
          query_redacted: parsed && !parsed.query.nil?,
          fragment_redacted: scope == "external-https" && parsed && !parsed.fragment.nil?,
          occurrences: grouped.fetch(raw),
          structure_error: error
        )
      end
    end

    def parse_target(raw)
      URI.parse(raw)
    rescue URI::InvalidURIError
      nil
    end

    def target_scope(raw)
      return "internal-reference" if raw.start_with?("#")
      return "embedded-resource" if raw.start_with?("data:")

      uri = parse_target(raw)
      return "invalid-external" unless uri
      return "external-https" if uri.scheme.to_s.downcase == "https"
      return "relative-reference" if uri.scheme.nil? && uri.host.nil?

      "invalid-external"
    end

    def structure_error(raw, scope, uri)
      case scope
      when "external-https"
        return "external HTTPS target must have a host and no userinfo" unless uri && uri.host && !uri.host.empty? && uri.userinfo.nil?
      when "internal-reference"
        return "internal reference must contain a fragment identifier" if raw.length <= 1
      when "relative-reference"
        return "relative reference must be non-empty and contain no backslash" if raw.empty? || raw.include?("\\")
      when "embedded-resource"
        return nil
      else
        return "only HTTPS is allowed for external targets"
      end
      nil
    end

    def safe_target(raw, scope, uri)
      case scope
      when "external-https"
        return "https://[redacted-invalid-target]" unless uri && uri.host

        clean = uri.dup
        clean.user = nil
        clean.password = nil
        clean.query = nil
        clean.fragment = nil
        clean.to_s
      when "internal-reference"
        raw
      when "relative-reference"
        clean = uri.dup
        clean.query = nil
        clean.fragment = nil
        clean.to_s.empty? ? "[redacted-invalid-target]" : clean.to_s
      when "embedded-resource"
        "data:[redacted-embedded-resource]"
      else
        if uri && uri.scheme
          "#{uri.scheme.downcase}:[redacted-non-https-target]"
        else
          "[redacted-invalid-target]"
        end
      end
    rescue URI::InvalidComponentError
      "[redacted-invalid-target]"
    end

    def target_document(target, result)
      occurrences = target.occurrences.map do |occurrence|
        {
          "node_kind" => occurrence.node_kind,
          "source_chapter_id" => occurrence.source_chapter_id,
          "ast_pointer" => occurrence.ast_pointer
        }
      end
      base = {
        "target" => target.safe_target,
        "target_sha256" => target.target_sha256,
        "target_scope" => target.target_scope,
        "query_redacted" => target.query_redacted,
        "fragment_redacted" => target.fragment_redacted,
        "host" => target.host,
        "occurrence_count" => occurrences.length,
        "node_kinds" => occurrences.map { |item| item.fetch("node_kind") }.uniq.sort,
        "occurrences" => occurrences,
        "structure_valid" => target.structure_error.nil?,
        "structure_error" => target.structure_error
      }
      return base.merge("outcome" => "failed", "reason" => "invalid-target", "probe" => nil) if target.structure_error
      unless target.target_scope == "external-https"
        return base.merge("outcome" => "not-applicable", "reason" => target.target_scope, "probe" => nil)
      end
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
          "effective_url" => safe_external_url(result.effective_url),
          "effective_https" => effective_https,
          "error_present" => !result.error.to_s.empty?,
          "error_sha256" => Digest::SHA256.hexdigest(result.error.to_s)
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
        "target" => item.fetch("target"),
        "target_sha256" => item.fetch("target_sha256"),
        "target_scope" => item.fetch("target_scope"),
        "host" => item.fetch("host"),
        "reason" => item.fetch("reason"),
        "http_status" => item.dig("probe", "http_status"),
        "curl_exit_code" => item.dig("probe", "curl_exit_code"),
        "node_kinds" => item.fetch("node_kinds"),
        "chapter_ids" => item.fetch("occurrences").map { |entry| entry.fetch("source_chapter_id") }.uniq.sort
      }
    end

    def https_without_userinfo?(value)
      uri = URI.parse(value.to_s)
      uri.is_a?(URI::HTTPS) && uri.host && !uri.host.empty? && uri.userinfo.nil?
    rescue URI::InvalidURIError
      false
    end

    def safe_external_url(value)
      uri = URI.parse(value.to_s)
      return nil unless uri.is_a?(URI::HTTPS) && uri.host && !uri.host.empty?

      clean = uri.dup
      clean.user = nil
      clean.password = nil
      clean.query = nil
      clean.fragment = nil
      clean.to_s
    rescue URI::InvalidURIError, URI::InvalidComponentError
      nil
    end

    def count_by(documents, field)
      documents.each_with_object(Hash.new(0)) { |item, memo| memo[item.fetch(field)] += 1 }.sort.to_h
    end

    def count_occurrences(occurrences)
      occurrences.each_with_object(Hash.new(0)) { |item, memo| memo[yield(item)] += 1 }.sort.to_h
    end

    def fixed_counts(observed, keys)
      keys.each_with_object({}) { |key, memo| memo[key] = observed.fetch(key, 0) }
    end

    def probe_policy
      {
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
        "redirect_protocol_policy" => "HTTPS only; HTTP downgrade is blocked and rejected"
      }
    end

    def extraction_policy(image_count)
      {
        "source" => "bound P8 canonical Pandoc AST output",
        "traversal" => "all final Link and Image nodes inside ordered chapter Div containers",
        "deduplication" => "exact final AST target string; node occurrences remain distinct",
        "network_probe_scope" => "valid external HTTPS targets only",
        "source_markdown_reparse" => "forbidden",
        "image_node_semantics" => if image_count.zero?
                                    "canonical AST contains zero Image nodes; final Link nodes are reported without reconstructing source Markdown image syntax"
                                  else
                                    "canonical AST Image nodes are reported exactly as final nodes without reconstructing source Markdown syntax"
                                  end
      }
    end

    def replay_commands(date)
      base = "ruby scripts/audit-chapter-markdown-links.rb --root . --observation-date #{date}"
      {
        "structure_only" => "#{base} --mode structure-only --output records/encyclopedia/evidence/machine/chapter-ast-links-v2-#{date}.json --pretty --workers #{workers} --per-host #{per_host_limit} --connect-timeout #{connect_timeout} --max-time #{max_time}",
        "live" => "#{base} --mode live --output records/encyclopedia/evidence/machine/chapter-ast-links-v2-#{date}.json --pretty --workers #{workers} --per-host #{per_host_limit} --connect-timeout #{connect_timeout} --max-time #{max_time}"
      }
    end

    def evidence_boundary
      "This v2 report inventories final Pandoc Link/Image nodes and binds the exact P8 plan, output manifest and canonical AST bytes. Structure-only mode proves that deterministic inventory and target syntax, not reachability. Live mode records one bounded observation per unique valid external HTTPS target. HTTP 200/206 does not prove source authority, citation entailment, content truth, accessibility or future availability. Inconclusive and access-controlled results require human review and are never auto-passed. Zero final Image nodes does not prove source Markdown contained no image syntax because v2 never reconstructs pre-publication syntax. Machine results cannot promote chapters or learner progress."
    end

    def validate_report!(report)
      reject_sensitive_report_values!(report)
      Verification::MachineReportSchema.validate!(
        root: root,
        schema_path: REPORT_SCHEMA_PATH,
        document: report
      )
    rescue Verification::ContractError => e
      raise AuditError, "v2 report schema rejected generated output (#{e.code})"
    end

    def reject_sensitive_report_values!(value, path = "$" )
      case value
      when Hash
        value.each { |key, child| reject_sensitive_report_values!(child, "#{path}/#{key}") }
      when Array
        value.each_with_index { |child, index| reject_sensitive_report_values!(child, "#{path}/#{index}") }
      when String
        without_https_urls = value.gsub(%r{https://[^\s]+}, "[https-url]")
        if without_https_urls.match?(%r{(?:\A|[^A-Za-z0-9])/(?:Users|home|private|var|tmp|opt|Applications|Library)/}) ||
           without_https_urls.match?(/(?:\A|\s)[A-Za-z]:[\\\/]/)
          raise AuditError, "generated report contains an absolute filesystem path at #{path}"
        end
        if value.match?(/\d{4}-\d{2}-\d{2}[Tt ][0-2]\d:[0-5]\d/)
          raise AuditError, "generated report contains a timestamp at #{path}"
        end
        if value.match?(%r{://[^/@\s]+:[^/@\s]+@})
          raise AuditError, "generated report contains URL credentials at #{path}"
        end
      end
      true
    end
  end

  module CLI
    module_function

    def run(argv, stdout: $stdout, stderr: $stderr, probe: nil)
      options = {
        root: File.expand_path("..", __dir__),
        mode: "structure-only",
        observation_date: nil,
        output: nil,
        pretty: false,
        workers: 8,
        per_host_limit: 2,
        connect_timeout: 10,
        max_time: 25,
        curl: "curl"
      }
      parser = OptionParser.new do |command|
        command.banner = "Usage: ruby scripts/audit-chapter-markdown-links.rb --observation-date YYYY-MM-DD [options]"
        command.on("--root PATH", "Repository root") { |value| options[:root] = value }
        command.on("--mode MODE", "structure-only or live") { |value| options[:mode] = value }
        command.on("--observation-date DATE", "Explicit deterministic evidence date (required)") { |value| options[:observation_date] = value }
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
      raise AuditError, "--observation-date is required" if options[:observation_date].to_s.empty?

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
      ).report(observation_date: options.fetch(:observation_date))
      canonical = canonicalize(report)
      bytes = options.fetch(:pretty) ? JSON.pretty_generate(canonical) + "\n" : JSON.generate(canonical) + "\n"
      if options[:output]
        destination = File.expand_path(options.fetch(:output))
        atomic_write(destination, bytes)
        stdout.puts "CHAPTER PANDOC AST LINK AUDIT #{report.fetch('status').upcase}"
        stdout.puts "report=#{destination}"
      else
        stdout.write(bytes)
      end
      report.fetch("status") == "passed" ? 0 : 1
    rescue OptionParser::ParseError, AuditError, VersionSourceAudit::AuditError, Errno::ENOENT => e
      stderr.puts "CHAPTER PANDOC AST LINK AUDIT FAILED: #{e.message.lines.first.to_s.strip}"
      2
    end

    def canonicalize(value)
      case value
      when Hash
        value.keys.sort.each_with_object({}) { |key, memo| memo[key] = canonicalize(value.fetch(key)) }
      when Array
        value.map { |item| canonicalize(item) }
      else
        value
      end
    end

    def atomic_write(destination, bytes)
      directory = File.dirname(destination)
      raise AuditError, "output directory does not exist" unless Dir.exist?(directory)

      temporary = Tempfile.new([".chapter-pandoc-links-", ".tmp"], directory)
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
