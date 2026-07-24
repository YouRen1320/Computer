# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "set"
require "tempfile"
require "time"
require "tmpdir"
require "yaml"

require_relative "curriculum_strict_yaml"
require_relative "curriculum_json_schema"
require_relative "curriculum_spec_quality"
require_relative "curriculum_migration_audit"

module Curriculum
  GENERATED_BY = "scripts/generate-curriculum.rb"
  GENERATED_MARKER = "GENERATED: factorycare-curriculum; DO NOT EDIT"
  PLACEHOLDER_MARKER = "GENERATED: factorycare-planned-placeholder; safe-to-overwrite: planned-only"
  CHAPTER_STATUSES = %w[planned drafting review verified].freeze
  EDITION_PHASE_STATUSES = {
    "architecture" => %w[planned].freeze,
    "authoring" => CHAPTER_STATUSES,
    "release-candidate" => %w[review verified].freeze,
    "published" => %w[verified].freeze
  }.freeze
  ACCELERATED_MASTERY_PROFILES = {
    "L1-L2" => %w[timed-teach-back guided-experiment boundary-diagnosis].freeze,
    "L2" => %w[timed-teach-back runnable-artifact boundary-test].freeze,
    "L2+" => %w[timed-teach-back runnable-artifact fault-diagnosis requirement-change].freeze,
    "L3" => %w[timed-teach-back independent-build fault-diagnosis requirement-change tradeoff-defense].freeze
  }.freeze
  ACCELERATED_MASTERY_ASSIGNMENTS = {
    "machine_learning" => {
      "modules" => %w[m37 m38 m39].freeze,
      "required_mastery" => "L1-L2"
    }.freeze,
    "artificial_intelligence" => {
      "modules" => %w[m40 m41 m42 m43 m44].freeze,
      "required_mastery" => "L2+"
    }.freeze
  }.freeze
  STATIC_GENERATED_OUTPUTS = %w[
    curriculum/catalog.yml
    curriculum/routes/zero-base.yml
    curriculum/routes/accelerated-48.yml
    curriculum/routes/factorycare-project.yml
    curriculum/routes/reference.yml
    curriculum/gates.yml
    curriculum/concept-graph.md
    curriculum/README.md
  ].freeze
  GENERATED_YAML_KEYS = {
    "curriculum/catalog.yml" => %w[schema_version generated generated_by generated_spec_digest edition catalog_id canonical status chapter_count_target dependency_semantics chapters],
    "curriculum/routes/zero-base.yml" => %w[schema_version generated generated_by generated_spec_digest edition route_id route_kind title coverage navigation_semantics waiver_policy units],
    "curriculum/routes/accelerated-48.yml" => %w[schema_version generated generated_by generated_spec_digest edition route_id route_kind coverage navigation_semantics mastery_policy module_count modules],
    "curriculum/routes/factorycare-project.yml" => %w[schema_version generated generated_by generated_spec_digest edition route_id route_kind coverage navigation_semantics artifact_policy gate_registry_id acceptance_catalog_path stages],
    "curriculum/routes/reference.yml" => %w[schema_version generated generated_by generated_spec_digest edition route_id route_kind coverage navigation_semantics facets chapter_index],
    "curriculum/gates.yml" => %w[schema_version generated generated_by generated_spec_digest edition gates_id canonical_source policy gates]
  }.freeze

  Issue = Struct.new(:code, :path, :message) do
    def to_s
      location = path ? " #{path}" : ""
      "[#{code}]#{location}: #{message}"
    end
  end

  class ValidationFailure < StandardError
    attr_reader :issues

    def initialize(issues)
      @issues = issues
      super("curriculum validation failed with #{issues.length} issue(s)")
    end
  end

  class IssueCollector
    attr_reader :errors, :warnings

    def initialize
      @errors = []
      @warnings = []
    end

    def error(code, path, message)
      @errors << Issue.new(code, path, message)
    end

    def warn(code, path, message)
      @warnings << Issue.new(code, path, message)
    end

    def raise_if_errors!
      raise ValidationFailure.new(errors) unless errors.empty?
    end
  end

  # Loads only canonical v2 inputs. It deliberately never falls back to the
  # legacy generated catalog because doing so would make a missing volume spec
  # look like a successful 170-chapter build.
  class SpecSet
    BASE_PATHS = {
      edition: "curriculum/edition.yml",
      volumes: "curriculum/volumes.yml",
      capabilities: "curriculum/capabilities.yml",
      topics: "curriculum/topics.yml",
      id_registry: "curriculum/id-registry.yml",
      accelerated_plan: "curriculum/route-plans/accelerated-48.yml",
      factorycare_plan: "curriculum/route-plans/factorycare-project.yml",
      factorycare_gate_registry: "curriculum/factorycare-stage-gates.yml",
      gates_plan: "curriculum/route-plans/gates.yml",
      versions: "versions/registry.yml"
    }.freeze

    attr_reader :root, :edition, :volumes, :capabilities, :topics, :id_registry,
                :accelerated_plan, :factorycare_plan, :factorycare_gate_registry, :gates_plan, :migration,
                :legacy_manifest, :migration_audit, :versions, :volume_specs, :chapters, :collector, :input_paths,
                :migration_schema, :application_receipt_schema, :application_receipt, :input_contents,
                :accelerated_route_schema, :factorycare_gate_schema, :factorycare_acceptance_catalog_source

    def initialize(root)
      @root = File.expand_path(root)
      @collector = IssueCollector.new
      @input_paths = []
      @input_contents = {}
      @volume_specs = {}
      @chapters = []
    end

    def load!
      load_base_documents!
      load_accelerated_route_schema!
      load_factorycare_gate_schema!
      load_factorycare_acceptance_catalog!
      load_migration_schema!
      load_application_receipt_schema!
      load_migration!
      load_application_receipt!
      load_migration_audit!
      load_legacy_manifest!
      load_source_rebuild_evidence!
      load_volume_specs!
      validate_top_level!
      enrich_chapters!
      validate_chapters!
      validate_dependency_graph!
      validate_capabilities!
      validate_topic_contracts!
      validate_id_registry!
      validate_migration!
      validate_route_plans!
      collector.raise_if_errors!
      self
    end

    def spec_digest
      digest = Digest::SHA256.new
      input_paths.sort.each do |relative|
        digest << relative << "\0" << input_contents.fetch(relative) << "\0"
      end
      digest.hexdigest
    end

    def volume_by_id
      @volume_by_id ||= volumes.fetch("volumes").each_with_object({}) do |volume, result|
        result[volume.fetch("id")] = volume
      end
    end

    def chapter_by_id
      @chapter_by_id ||= chapters.each_with_object({}) { |chapter, result| result[chapter.fetch("id")] = chapter }
    end

    def capability_by_id
      @capability_by_id ||= capabilities.fetch("capabilities").each_with_object({}) do |capability, result|
        result[capability.fetch("id")] = capability
      end
    end

    def ancestors(id, memo = {}, visiting = Set.new)
      return memo[id] if memo.key?(id)
      return Set.new if visiting.include?(id)

      visiting.add(id)
      result = Set.new
      chapter = chapter_by_id[id]
      if chapter
        chapter.fetch("prerequisites").each do |dependency|
          next unless chapter_by_id.key?(dependency)

          result.add(dependency)
          result.merge(ancestors(dependency, memo, visiting))
        end
      end
      visiting.delete(id)
      memo[id] = result
    end

    private

    def load_base_documents!
      BASE_PATHS.each do |name, relative|
        value = load_yaml(relative)
        instance_variable_set("@#{name}", value)
      end
    rescue DiagnosticError => e
      raise ValidationFailure.new([Issue.new(e.code, e.path, e.message)])
    end

    def load_factorycare_gate_schema!
      relative = "schemas/factorycare-stage-gates.schema.json"
      source = read_input(relative).dup.force_encoding(Encoding::UTF_8)
      @factorycare_gate_schema = StrictJson.load(source)
    rescue JSON::ParserError, StrictJson::DuplicateKeyError => e
      raise ValidationFailure.new([Issue.new("E_FACTORYCARE_GATE_SCHEMA", relative, e.message)])
    rescue DiagnosticError => e
      raise ValidationFailure.new([Issue.new(e.code, e.path, e.message)])
    end

    def load_accelerated_route_schema!
      relative = "schemas/accelerated-route-plan.schema.json"
      source = read_input(relative).dup.force_encoding(Encoding::UTF_8)
      @accelerated_route_schema = StrictJson.load(source)
    rescue JSON::ParserError, StrictJson::DuplicateKeyError => e
      raise ValidationFailure.new([Issue.new("E_ACCELERATED_ROUTE_SCHEMA", relative, e.message)])
    rescue DiagnosticError => e
      raise ValidationFailure.new([Issue.new(e.code, e.path, e.message)])
    end

    def load_factorycare_acceptance_catalog!
      relative = factorycare_gate_registry.is_a?(Hash) ? factorycare_gate_registry["acceptance_catalog_path"] : nil
      unless relative == "factorycare-design/testing/acceptance-catalog.md"
        raise ValidationFailure.new([Issue.new(
          "E_FACTORYCARE_ACCEPTANCE_CATALOG",
          "curriculum/factorycare-stage-gates.yml",
          "acceptance_catalog_path must name the canonical FactoryCare acceptance catalog"
        )])
      end
      @factorycare_acceptance_catalog_source = read_input(relative).dup.force_encoding(Encoding::UTF_8)
      unless @factorycare_acceptance_catalog_source.valid_encoding?
        raise ValidationFailure.new([Issue.new("E_FACTORYCARE_ACCEPTANCE_CATALOG", relative, "catalog must be valid UTF-8")])
      end
    rescue DiagnosticError => e
      raise ValidationFailure.new([Issue.new(e.code, e.path, e.message)])
    end

    def load_migration!
      relative = edition["migration_ledger"] || "curriculum/migrations/2026.1-to-2026.2.yml"
      @migration = load_yaml(relative)
    rescue DiagnosticError => e
      raise ValidationFailure.new([Issue.new(e.code, e.path, e.message)])
    end

    def load_legacy_manifest!
      relative = migration["legacy_manifest_path"]
      @legacy_manifest = relative ? load_yaml(relative) : {}
    rescue DiagnosticError => e
      raise ValidationFailure.new([Issue.new(e.code, e.path, e.message)])
    end

    def load_application_receipt!
      relative = migration["application_receipt_path"]
      @application_receipt = relative ? load_yaml(relative) : nil
    rescue DiagnosticError => e
      raise ValidationFailure.new([Issue.new(e.code, e.path, e.message)])
    end

    def load_migration_audit!
      relative = migration["mapping_audit_path"]
      source = read_input(relative)
      @migration_audit = MigrationAudit.parse(source)
    rescue ArgumentError => e
      raise ValidationFailure.new([Issue.new("E_MIGRATION_AUDIT", relative, e.message)])
    rescue DiagnosticError => e
      raise ValidationFailure.new([Issue.new(e.code, e.path, e.message)])
    end

    def load_source_rebuild_evidence!
      array(migration["source_rebuilds"]).each do |rebuild|
        next unless rebuild.is_a?(Hash)

        %w[source_inventory_path source_build_path candidate_manifest_path].each do |field|
          read_input(rebuild[field]) if rebuild[field].is_a?(String)
        end
        read_input(rebuild["builder_path"]) if rebuild["builder_path"].is_a?(String)
      end
    rescue DiagnosticError => e
      raise ValidationFailure.new([Issue.new(e.code, e.path, e.message)])
    end

    def load_migration_schema!
      relative = "curriculum/migrations/migration.schema.json"
      source = read_input(relative).dup.force_encoding(Encoding::UTF_8)
      @migration_schema = StrictJson.load(source)
    rescue JSON::ParserError, StrictJson::DuplicateKeyError => e
      raise ValidationFailure.new([Issue.new("E_MIGRATION_SCHEMA", relative, e.message)])
    rescue DiagnosticError => e
      raise ValidationFailure.new([Issue.new(e.code, e.path, e.message)])
    end

    def load_application_receipt_schema!
      relative = "curriculum/migrations/application-receipt.schema.json"
      source = read_input(relative).dup.force_encoding(Encoding::UTF_8)
      @application_receipt_schema = StrictJson.load(source)
    rescue JSON::ParserError, StrictJson::DuplicateKeyError => e
      raise ValidationFailure.new([Issue.new("E_MIGRATION_RECEIPT_SCHEMA", relative, e.message)])
    rescue DiagnosticError => e
      raise ValidationFailure.new([Issue.new(e.code, e.path, e.message)])
    end

    def load_volume_specs!
      expected_ids = array(edition["volume_ids"])
      expected = expected_ids.map { |id| "curriculum/chapters/volume-#{id}.yml" }
      actual = Dir.glob(File.join(root, "curriculum", "chapters", "volume-*.yml")).map do |path|
        relative(path)
      end.sort
      missing = expected - actual
      extra = actual - expected
      unless missing.empty? && extra.empty?
        details = []
        details << "missing=#{missing.join(',')}" unless missing.empty?
        details << "extra=#{extra.join(',')}" unless extra.empty?
        raise ValidationFailure.new([Issue.new(
          "E_VOLUME_SPEC_SET",
          "curriculum/chapters",
          "expected #{expected.length} exact volume specs; #{details.join(' ')}"
        )])
      end

      expected_ids.each do |id|
        relative_path = "curriculum/chapters/volume-#{id}.yml"
        @volume_specs[id] = load_yaml(relative_path)
      rescue DiagnosticError => e
        raise ValidationFailure.new([Issue.new(e.code, e.path, e.message)])
      end
    end

    def load_yaml(relative_path)
      source = read_input(relative_path).dup.force_encoding(Encoding::UTF_8)
      StrictYaml.load(source, display_path: relative_path)
    end

    def read_input(relative_path)
      validate_relative_input_path!(relative_path)
      return input_contents.fetch(relative_path) if input_contents.key?(relative_path)

      absolute = File.join(root, relative_path)
      current = absolute
      while current.start_with?(root + File::SEPARATOR)
        if File.symlink?(current)
          raise DiagnosticError.new("E_INPUT_SYMLINK", "canonical inputs and their parents must not be symbolic links", path: relative_path)
        end
        current = File.dirname(current)
      end
      unless File.file?(absolute)
        raise DiagnosticError.new("E_INPUT_TYPE", "canonical input must be a regular file", path: relative_path)
      end
      source = File.binread(absolute)
      input_paths << relative_path
      input_contents[relative_path] = source.freeze
    rescue Errno::ENOENT
      raise DiagnosticError.new("E_INPUT_MISSING", "required input file is missing", path: relative_path)
    end

    def validate_relative_input_path!(relative_path)
      clean = Pathname.new(relative_path.to_s).cleanpath.to_s
      unless relative_path.is_a?(String) && !Pathname.new(relative_path).absolute? && clean == relative_path && !clean.start_with?("../")
        raise DiagnosticError.new("E_INPUT_PATH", "input path must be a normalized path inside the workspace", path: relative_path.to_s)
      end
    end

    def validate_top_level!
      expect_hash(edition, "curriculum/edition.yml", "/")
      reject_unknown_keys(edition, %w[
        schema_version catalog_id edition canonical status chapter_count_target capability_count_target
        volume_ids chapter_id_pattern allowed_levels allowed_roles
        outcome_contract scope_limits verification_levels generated_outputs migration_ledger compatibility
      ], "curriculum/edition.yml", "/")
      expect_equal(edition["schema_version"], 2, "curriculum/edition.yml", "/schema_version")
      expect_equal(edition["edition"], "2026.2-draft", "curriculum/edition.yml", "/edition")
      expect_equal(edition["generated_outputs"], STATIC_GENERATED_OUTPUTS, "curriculum/edition.yml", "/generated_outputs")
      expect_equal(edition["compatibility"], "none", "curriculum/edition.yml", "/compatibility")
      unless EDITION_PHASE_STATUSES.key?(edition["status"])
        collector.error(
          "E_SCHEMA",
          "curriculum/edition.yml",
          "/status must be one of #{EDITION_PHASE_STATUSES.keys.join(', ')}, got #{edition['status'].inspect}"
        )
      end
      unless edition["chapter_count_target"].is_a?(Integer) && edition["chapter_count_target"].positive?
        collector.error("E_SCHEMA", "curriculum/edition.yml", "/chapter_count_target must be a positive integer")
      end
      unless edition["capability_count_target"].is_a?(Integer) && edition["capability_count_target"].positive?
        collector.error("E_SCHEMA", "curriculum/edition.yml", "/capability_count_target must be a positive integer")
      end

      volume_entries = array(volumes["volumes"])
      reject_unknown_keys(volumes, %w[schema_version edition volumes], "curriculum/volumes.yml", "/")
      expect_equal(volumes["schema_version"], 2, "curriculum/volumes.yml", "/schema_version")
      expect_equal(volumes["edition"], edition["edition"], "curriculum/volumes.yml", "/edition")
      expected_ids = array(edition["volume_ids"])
      actual_ids = volume_entries.map { |entry| entry["id"] }
      collector.error("E_VOLUME_SET", "curriculum/volumes.yml", "volume ids must equal edition volume_ids") unless actual_ids == expected_ids
      volume_entries.each_with_index do |entry, index|
        reject_unknown_keys(entry, %w[id slug title description expected_chapter_count zero_base_unit_id stage_gate_id final_gate_id], "curriculum/volumes.yml", "/volumes/#{index}")
        slug = entry["slug"]
        unless slug.is_a?(String) && slug.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
          collector.error("E_OUTPUT_PATH", "curriculum/volumes.yml", "/volumes/#{index}/slug must be a safe semantic slug")
        end
        %w[title description zero_base_unit_id].each do |field|
          collector.error("E_SCHEMA", "curriculum/volumes.yml", "/volumes/#{index}/#{field} must be non-empty") unless nonempty_string?(entry[field])
        end
        unless entry["expected_chapter_count"].is_a?(Integer) && entry["expected_chapter_count"].positive?
          collector.error("E_SCHEMA", "curriculum/volumes.yml", "/volumes/#{index}/expected_chapter_count must be a positive integer")
        end
      end
      count_sum = volume_entries.inject(0) do |sum, entry|
        sum + (entry["expected_chapter_count"].is_a?(Integer) ? entry["expected_chapter_count"] : 0)
      end
      if count_sum != edition["chapter_count_target"].to_i
        collector.error("E_CHAPTER_COUNT", "curriculum/volumes.yml", "volume targets sum to #{count_sum}, expected #{edition['chapter_count_target']}")
      end

      expected_ids.each do |id|
        spec = volume_specs[id]
        path = "curriculum/chapters/volume-#{id}.yml"
        expect_hash(spec, path, "/")
        expect_equal(spec["schema_version"], 2, path, "/schema_version")
        expect_equal(spec["edition"], edition["edition"], path, "/edition")
        expect_equal(spec["volume"], id, path, "/volume")
        collector.error("E_SCHEMA", path, "/chapters must be an array") unless spec["chapters"].is_a?(Array)
      end

      cap_entries = array(capabilities["capabilities"])
      reject_unknown_keys(capabilities, %w[schema_version edition registry_id capability_count policy capabilities], "curriculum/capabilities.yml", "/")
      expect_equal(capabilities["schema_version"], 2, "curriculum/capabilities.yml", "/schema_version")
      expect_equal(capabilities["edition"], edition["edition"], "curriculum/capabilities.yml", "/edition")
      unless capabilities["capability_count"].is_a?(Integer) && capabilities["capability_count"].positive?
        collector.error("E_SCHEMA", "curriculum/capabilities.yml", "/capability_count must be a positive integer")
      end
      expected_capability_count = capabilities["capability_count"].to_i
      edition_capability_count = edition["capability_count_target"].to_i
      if expected_capability_count != edition_capability_count || cap_entries.length != expected_capability_count
        collector.error("E_CAPABILITY_COUNT", "curriculum/capabilities.yml", "edition=#{edition_capability_count} declared=#{expected_capability_count} actual=#{cap_entries.length}")
      end
      duplicate_values(cap_entries.map { |entry| entry["id"] }).each do |id|
        collector.error("E_DUPLICATE_CAPABILITY", "curriculum/capabilities.yml", "duplicate capability id #{id.inspect}")
      end
      cap_entries.each_with_index do |entry, index|
        pointer = "/capabilities/#{index}"
        reject_unknown_keys(entry, %w[id title category status teacher_chapter_id requires threshold evidence_kinds required_topic_ids], "curriculum/capabilities.yml", pointer)
        required = %w[id title category status teacher_chapter_id requires threshold evidence_kinds required_topic_ids]
        missing = required.reject { |field| entry.is_a?(Hash) && entry.key?(field) }
        collector.error("E_SCHEMA", "curriculum/capabilities.yml", "#{pointer} missing fields #{missing.join(',')}") unless missing.empty?
        next unless entry.is_a?(Hash)

        collector.error("E_SCHEMA", "curriculum/capabilities.yml", "#{pointer}/terms is obsolete; use canonical required_topic_ids") if entry.key?("terms")
        collector.error("E_SCHEMA", "curriculum/capabilities.yml", "#{pointer}/id must be semantic") unless entry["id"].is_a?(String) && entry["id"].match?(/\A[a-z][a-z0-9-]*\.[a-z0-9]+(?:-[a-z0-9]+)*\z/)
        %w[title category teacher_chapter_id threshold].each do |field|
          collector.error("E_SCHEMA", "curriculum/capabilities.yml", "#{pointer}/#{field} must be non-empty") unless nonempty_string?(entry[field])
        end
        collector.error("E_SCHEMA", "curriculum/capabilities.yml", "#{pointer}/status must be active") unless entry["status"] == "active"
        validate_unique_string_array(entry["requires"], "curriculum/capabilities.yml", "#{pointer}/requires")
        validate_unique_string_array(entry["evidence_kinds"], "curriculum/capabilities.yml", "#{pointer}/evidence_kinds", nonempty: true)
        validate_unique_string_array(entry["required_topic_ids"], "curriculum/capabilities.yml", "#{pointer}/required_topic_ids", nonempty: true)
      end

      expect_equal(topics["schema_version"], 2, "curriculum/topics.yml", "/schema_version")
      reject_unknown_keys(topics, %w[schema_version edition registry_id topic_count policy topics], "curriculum/topics.yml", "/")
      expect_equal(topics["edition"], edition["edition"], "curriculum/topics.yml", "/edition")
      topic_entries = array(topics["topics"])
      unless topics["topic_count"].is_a?(Integer) && topics["topic_count"] == topic_entries.length
        collector.error("E_TOPIC_COUNT", "curriculum/topics.yml", "topic_count must equal the registered topic list length")
      end
      topic_entries.each_with_index do |entry, index|
        id = entry.is_a?(Hash) ? entry["id"] : entry
        unless id.is_a?(String) && id.match?(/\A[a-z][a-z0-9-]*\.[a-z0-9]+(?:[-.][a-z0-9]+)*\z/)
          collector.error("E_TOPIC_ID", "curriculum/topics.yml", "/topics/#{index} invalid canonical topic id #{id.inspect}")
        end
      end

      reject_unknown_keys(id_registry, %w[schema_version edition registry_id policy entries], "curriculum/id-registry.yml", "/")
      expect_equal(id_registry["schema_version"], 2, "curriculum/id-registry.yml", "/schema_version")
      expect_equal(id_registry["edition"], edition["edition"], "curriculum/id-registry.yml", "/edition")
    end

    def enrich_chapters!
      seen = {}
      expected_ids = array(edition["volume_ids"])
      expected_ids.each do |volume_id|
        spec = volume_specs.fetch(volume_id)
        volume = volume_by_id[volume_id]
        next unless volume

        previous = nil
        array(spec["chapters"]).each_with_index do |raw, index|
          chapter = raw.is_a?(Hash) ? deep_copy(raw) : {}
          id = chapter["id"] || "chapter-#{volume_id}-#{index + 1}"
          path = "book/volume-#{volume_id}-#{volume.fetch('slug')}/chapters/#{id}.md"
          chapter["volume"] = volume_id
          chapter["order"] = index + 1
          chapter["path"] = path
          chapter["recommended_after"] = previous ? [previous] : []
          chapter["spec_digest"] = Digest::SHA256.hexdigest(Psych.dump(raw, nil, line_width: -1))
          chapter["source_spec"] = "curriculum/chapters/volume-#{volume_id}.yml"
          if seen.key?(id)
            collector.error("E_DUPLICATE_CHAPTER_ID", chapter["source_spec"], "duplicate chapter id #{id}; first seen in #{seen[id]}")
          else
            seen[id] = chapter["source_spec"]
          end
          @chapters << chapter
          previous = id
        end
      end

      expected = edition["chapter_count_target"].to_i
      if chapters.length != expected
        collector.error("E_CHAPTER_COUNT", "curriculum/chapters", "expected #{expected} chapters, got #{chapters.length}")
      end
      volume_by_id.each do |id, volume|
        actual = chapters.count { |chapter| chapter["volume"] == id }
        expected_count = volume["expected_chapter_count"].to_i
        if actual != expected_count
          collector.error("E_CHAPTER_COUNT", "curriculum/chapters/volume-#{id}.yml", "expected #{expected_count} chapters, got #{actual}")
        end
      end
    end

    def validate_chapters!
      allowed_input = %w[
        id title role responsibility level status stable_core topic_groups topics_taught
        topics_used prerequisites prerequisite_rationales capabilities borrowed_scaffolds
        lab_requirements gate_requirements verification_mode version_surfaces outcomes
        scope_exception
      ]
      derived = %w[volume order path route_tags recommended_after generated spec_digest]
      required = allowed_input - ["scope_exception"]
      id_pattern = compile_pattern(edition["chapter_id_pattern"])
      allowed_roles = array(edition["allowed_roles"])
      allowed_levels = array(edition["allowed_levels"])
      phase_statuses = EDITION_PHASE_STATUSES[edition["status"]]
      version_ids = array(versions["entries"]).map { |entry| entry["id"] }.to_set

      volume_specs.each do |volume_id, spec|
        source = "curriculum/chapters/volume-#{volume_id}.yml"
        array(spec["chapters"]).each_with_index do |raw, index|
          pointer = "/chapters/#{index}"
          unless raw.is_a?(Hash)
            collector.error("E_SCHEMA", source, "#{pointer} must be a mapping")
            next
          end

          missing = required.reject { |field| raw.key?(field) }
          collector.error("E_SCHEMA", source, "#{pointer} missing fields #{missing.join(',')}") unless missing.empty?
          unknown = raw.keys - allowed_input
          collector.error("E_SCHEMA", source, "#{pointer} unknown fields #{unknown.join(',')}") unless unknown.empty?
          forbidden = raw.keys & derived
          collector.error("E_SCHEMA", source, "#{pointer} contains derived fields #{forbidden.join(',')}") unless forbidden.empty?

          id = raw["id"]
          unless id.is_a?(String) && id_pattern && id_pattern.match?(id)
            collector.error("E_ID_FORMAT", source, "#{pointer}/id invalid semantic id #{id.inspect}")
          end
          if id.to_s.match?(/(?:^|\.)v\d|c\d|\b20\d{2}\b/)
            collector.error("E_ID_SEMANTICS", source, "#{pointer}/id must not encode volume, order, or version")
          end
          collector.error("E_SCHEMA", source, "#{pointer}/title must be non-empty") unless nonempty_string?(raw["title"])
          collector.error("E_SCHEMA", source, "#{pointer}/responsibility must be a concrete boundary") unless nonempty_string?(raw["responsibility"]) && raw["responsibility"].length >= 12
          collector.error("E_SCHEMA", source, "#{pointer}/role invalid") unless allowed_roles.include?(raw["role"])
          collector.error("E_SCHEMA", source, "#{pointer}/level invalid") unless allowed_levels.include?(raw["level"])
          status = raw["status"]
          status_known = CHAPTER_STATUSES.include?(status)
          collector.error("E_SCHEMA", source, "#{pointer}/status invalid") unless status_known
          if status_known && phase_statuses && !phase_statuses.include?(status)
            collector.error("E_STATUS_PHASE", source, "#{pointer}/status #{status.inspect} is not allowed in #{edition['status']}")
          end
          collector.error("E_SCHEMA", source, "#{pointer}/stable_core must be boolean") unless [true, false].include?(raw["stable_core"])

          validate_unique_string_array(raw["topics_taught"], source, "#{pointer}/topics_taught")
          validate_unique_string_array(raw["topics_used"], source, "#{pointer}/topics_used")
          validate_unique_string_array(raw["prerequisites"], source, "#{pointer}/prerequisites")
          validate_unique_string_array(raw["version_surfaces"], source, "#{pointer}/version_surfaces")
          unknown_versions = array(raw["version_surfaces"]).reject { |version| version_ids.include?(version) }
          collector.error("E_VERSION_REFERENCE", source, "#{pointer}/version_surfaces unknown #{unknown_versions.join(',')}") unless unknown_versions.empty?

          validate_topic_groups(raw, source, pointer)
          validate_prerequisite_rationales(raw, source, pointer)
          validate_chapter_capabilities(raw, source, pointer)
          validate_borrowed_scaffolds(raw, source, pointer)
          validate_lab_gate_verification(raw, source, pointer)
          validate_outcomes(raw, source, pointer)
          validate_scope(raw, source, pointer)
        end
      end
    end

    def validate_topic_groups(raw, source, pointer)
      groups = raw["topic_groups"]
      unless groups.is_a?(Array) && !groups.empty?
        collector.error("E_SCHEMA", source, "#{pointer}/topic_groups must be a non-empty array")
        return
      end
      ids = []
      groups.each_with_index do |group, index|
        gp = "#{pointer}/topic_groups/#{index}"
        unless group.is_a?(Hash)
          collector.error("E_SCHEMA", source, "#{gp} must be a mapping")
          next
        end
        ids << group["id"]
        collector.error("E_SCHEMA", source, "#{gp}/id must be non-empty") unless nonempty_string?(group["id"])
        collector.error("E_SCHEMA", source, "#{gp}/title must be non-empty") unless nonempty_string?(group["title"])
        validate_unique_string_array(group["topics"], source, "#{gp}/topics", nonempty: true)
      end
      duplicate_values(ids).each { |id| collector.error("E_SCHEMA", source, "#{pointer}/topic_groups duplicate id #{id.inspect}") }
    end

    def validate_prerequisite_rationales(raw, source, pointer)
      prerequisites = array(raw["prerequisites"])
      rationales = raw["prerequisite_rationales"]
      unless rationales.is_a?(Hash)
        collector.error("E_SCHEMA", source, "#{pointer}/prerequisite_rationales must be a mapping")
        return
      end
      if rationales.keys.sort != prerequisites.sort
        collector.error("E_PREREQUISITE_RATIONALE", source, "#{pointer} rationale keys must exactly match prerequisites")
      end
      rationales.each do |dependency, rationale|
        rp = "#{pointer}/prerequisite_rationales/#{dependency}"
        unless rationale.is_a?(Hash)
          collector.error("E_SCHEMA", source, "#{rp} must be a mapping")
          next
        end
        collector.error("E_PREREQUISITE_RATIONALE", source, "#{rp}/reason must be concrete") unless nonempty_string?(rationale["reason"]) && rationale["reason"].length >= 8
        capabilities = array(rationale["capabilities"])
        topics = array(rationale["topics"])
        outcomes = array(rationale["outcome_ids"])
        validate_unique_string_array(rationale["capabilities"], source, "#{rp}/capabilities")
        validate_unique_string_array(rationale["topics"], source, "#{rp}/topics")
        validate_unique_string_array(rationale["outcome_ids"], source, "#{rp}/outcome_ids")
        if capabilities.empty? && topics.empty? && outcomes.empty?
          collector.error("E_PREREQUISITE_RATIONALE", source, "#{rp} must support a capability, topic, or outcome")
        end
        unknown_outcomes = outcomes - %w[explain build diagnose]
        collector.error("E_SCHEMA", source, "#{rp}/outcome_ids unknown #{unknown_outcomes.join(',')}") unless unknown_outcomes.empty?
        unknown_capabilities = capabilities.reject { |id| capability_by_id.key?(id) }
        collector.error("E_PREREQUISITE_RATIONALE", source, "#{rp} references unknown capabilities #{unknown_capabilities.join(',')}") unless unknown_capabilities.empty?
        dependency_chapters = [dependency] + ancestors(dependency).to_a
        provided_capabilities = dependency_chapters.flat_map do |id|
          chapter = chapter_by_id[id]
          chapter && chapter["capabilities"].is_a?(Hash) ? array(chapter["capabilities"]["teaches"]) : []
        end.to_set
        unsupported_capabilities = capabilities.to_set - provided_capabilities
        collector.error("E_PREREQUISITE_RATIONALE", source, "#{rp} dependency closure does not provide capabilities #{unsupported_capabilities.to_a.join(',')}") unless unsupported_capabilities.empty?
        provided_topics = dependency_chapters.flat_map do |id|
          chapter = chapter_by_id[id]
          chapter ? array(chapter["topics_taught"]) : []
        end.to_set
        unsupported_topics = topics.to_set - provided_topics
        collector.error("E_PREREQUISITE_RATIONALE", source, "#{rp} dependency closure does not provide topics #{unsupported_topics.to_a.join(',')}") unless unsupported_topics.empty?
      end
    end

    def validate_chapter_capabilities(raw, source, pointer)
      contract = raw["capabilities"]
      unless contract.is_a?(Hash)
        collector.error("E_SCHEMA", source, "#{pointer}/capabilities must be a mapping")
        return
      end
      validate_unique_string_array(contract["teaches"], source, "#{pointer}/capabilities/teaches")
      validate_unique_string_array(contract["uses"], source, "#{pointer}/capabilities/uses")
      if array(contract["teaches"]).length > edition.dig("scope_limits", "teaches_capabilities").to_i
        collector.error("E_SCOPE", source, "#{pointer} teaches more than the configured capability limit")
      end
    end

    def validate_borrowed_scaffolds(raw, source, pointer)
      scaffolds = raw["borrowed_scaffolds"]
      unless scaffolds.is_a?(Array)
        collector.error("E_SCHEMA", source, "#{pointer}/borrowed_scaffolds must be an array")
        return
      end
      scaffolds.each_with_index do |scaffold, index|
        sp = "#{pointer}/borrowed_scaffolds/#{index}"
        unless scaffold.is_a?(Hash)
          collector.error("E_SCHEMA", source, "#{sp} must be a mapping")
          next
        end
        %w[topic later_teacher_chapter_id allowed_action rationale].each do |field|
          collector.error("E_SCHEMA", source, "#{sp}/#{field} must be non-empty") unless nonempty_string?(scaffold[field])
        end
        collector.error("E_BORROWED_SCAFFOLD", source, "#{sp}/allowed_action must be copy-run-only") unless scaffold["allowed_action"] == "copy-run-only"
      end
    end

    def validate_lab_gate_verification(raw, source, pointer)
      lab = raw["lab_requirements"]
      unless lab.is_a?(Hash) && [true, false].include?(lab["required"])
        collector.error("E_SCHEMA", source, "#{pointer}/lab_requirements invalid")
      else
        validate_unique_string_array(lab["artifact_paths"], source, "#{pointer}/lab_requirements/artifact_paths")
        validate_unique_string_array(lab["acceptance"], source, "#{pointer}/lab_requirements/acceptance")
        if lab["required"] && (array(lab["artifact_paths"]).empty? || array(lab["acceptance"]).empty?)
          collector.error("E_SCHEMA", source, "#{pointer}/lab_requirements required lab needs paths and acceptance")
        end
        array(lab["artifact_paths"]).each do |path|
          unless valid_contract_path?(path) && path.start_with?("labs/encyclopedia/#{raw['id']}/")
            collector.error("E_ARTIFACT_PATH", source, "#{pointer}/lab_requirements/artifact_paths must stay under labs/encyclopedia/#{raw['id']}/")
          end
        end
        array(lab["acceptance"]).each_with_index do |acceptance, index|
          issue = SpecQuality.acceptance_issue(acceptance)
          collector.error("E_ACCEPTANCE_GENERIC", source, "#{pointer}/lab_requirements/acceptance/#{index} #{issue}") if issue
        end
      end

      gate = raw["gate_requirements"]
      unless gate.is_a?(Hash)
        collector.error("E_SCHEMA", source, "#{pointer}/gate_requirements must be a mapping")
      else
        %w[gate_ids evidence_paths critical_failure_modes].each do |field|
          validate_unique_string_array(gate[field], source, "#{pointer}/gate_requirements/#{field}")
        end
        array(gate["evidence_paths"]).each do |path|
          collector.error("E_ARTIFACT_PATH", source, "#{pointer}/gate_requirements/evidence_paths contains an unsafe path") unless valid_contract_path?(path)
        end
      end

      verification = raw["verification_mode"]
      unless verification.is_a?(Hash)
        collector.error("E_SCHEMA", source, "#{pointer}/verification_mode must be a mapping")
        return
      end
      unless array(edition["verification_levels"]).include?(verification["test_level"])
        collector.error("E_TEST_LEVEL", source, "#{pointer}/verification_mode/test_level invalid")
      end
      validate_unique_string_array(verification["methods"], source, "#{pointer}/verification_mode/methods", nonempty: true)
      collector.error("E_SCHEMA", source, "#{pointer}/verification_mode/oracle must be concrete") unless nonempty_string?(verification["oracle"]) && verification["oracle"].length >= 8
    end

    def validate_outcomes(raw, source, pointer)
      outcomes = raw["outcomes"]
      expected_ids = array(edition.dig("outcome_contract", "ids"))
      expected_kinds = array(edition.dig("outcome_contract", "kinds"))
      unless outcomes.is_a?(Array) && outcomes.length == 3
        collector.error("E_OUTCOME_CONTRACT", source, "#{pointer}/outcomes must contain exactly three structured outcomes")
        return
      end
      ids = outcomes.map { |outcome| outcome.is_a?(Hash) ? outcome["id"] : nil }
      collector.error("E_OUTCOME_CONTRACT", source, "#{pointer}/outcomes ids must be #{expected_ids.inspect}") unless ids == expected_ids
      borrowed_topics = array(raw["borrowed_scaffolds"]).map { |item| item.is_a?(Hash) ? item["topic"] : nil }.compact
      group_topics = array(raw["topic_groups"]).each_with_object({}) do |group, result|
        next unless group.is_a?(Hash)

        result[group["id"]] = array(group["topics"])
      end
      covered_groups = Set.new
      outcomes.each_with_index do |outcome, index|
        op = "#{pointer}/outcomes/#{index}"
        unless outcome.is_a?(Hash)
          collector.error("E_SCHEMA", source, "#{op} must be a mapping")
          next
        end
        required = %w[id kind text covers_topic_groups covers_topics uses_capabilities evidence_kind verification_mode]
        reject_unknown_keys(outcome, required, source, op)
        missing = required.reject { |field| outcome.key?(field) }
        collector.error("E_SCHEMA", source, "#{op} missing fields #{missing.join(',')}") unless missing.empty?
        collector.error("E_OUTCOME_CONTRACT", source, "#{op}/kind must be #{expected_kinds[index].inspect}") unless outcome["kind"] == expected_kinds[index]
        collector.error("E_OUTCOME_CONTRACT", source, "#{op}/text must be concrete") unless nonempty_string?(outcome["text"]) && outcome["text"].length >= 20
        quality_issue = SpecQuality.outcome_issue(outcome, raw)
        collector.error("E_OUTCOME_GENERIC", source, "#{op}/text #{quality_issue}") if quality_issue
        groups = array(outcome["covers_topic_groups"])
        topics = array(outcome["covers_topics"])
        validate_unique_string_array(outcome["covers_topic_groups"], source, "#{op}/covers_topic_groups", nonempty: true)
        validate_unique_string_array(outcome["covers_topics"], source, "#{op}/covers_topics", nonempty: true)
        collector.error("E_TOPIC_COVERAGE", source, "#{op}/covers_topic_groups cannot be empty") if groups.empty?
        groups.each { |group| covered_groups.add(group) }
        unknown_groups = groups - group_topics.keys
        collector.error("E_TOPIC_COVERAGE", source, "#{op} unknown groups #{unknown_groups.join(',')}") unless unknown_groups.empty?
        allowed_topics = groups.flat_map { |group| group_topics[group] || [] }.uniq
        outside = topics - allowed_topics
        collector.error("E_TOPIC_COVERAGE", source, "#{op} topics outside covered groups #{outside.join(',')}") unless outside.empty?
        borrowed_in_outcome = topics & borrowed_topics
        unless borrowed_in_outcome.empty?
          collector.error("E_BORROWED_SCAFFOLD", source, "#{op} independently assesses borrowed topics #{borrowed_in_outcome.join(',')}")
        end
        validate_unique_string_array(outcome["uses_capabilities"], source, "#{op}/uses_capabilities")
        chapter_capabilities = if raw["capabilities"].is_a?(Hash)
          array(raw["capabilities"]["teaches"]) + array(raw["capabilities"]["uses"])
        else
          []
        end
        undeclared_capabilities = array(outcome["uses_capabilities"]) - chapter_capabilities
        unless undeclared_capabilities.empty?
          collector.error("E_CAPABILITY_UNKNOWN", source, "#{op} uses capabilities absent from the chapter contract #{undeclared_capabilities.join(',')}")
        end
        collector.error("E_SCHEMA", source, "#{op}/evidence_kind must be non-empty") unless nonempty_string?(outcome["evidence_kind"])
        collector.error("E_SCHEMA", source, "#{op}/verification_mode must be non-empty") unless nonempty_string?(outcome["verification_mode"])
      end
      missing_groups = group_topics.keys.reject { |group| covered_groups.include?(group) }
      collector.error("E_TOPIC_COVERAGE", source, "#{pointer} groups not covered by outcomes #{missing_groups.join(',')}") unless missing_groups.empty?
    end

    def validate_scope(raw, source, pointer)
      ordinary_limit = edition.dig("scope_limits", "ordinary_topic_groups").to_i
      synthesis_limit = edition.dig("scope_limits", "synthesis_topic_groups").to_i
      broad = %w[synthesis review project].include?(raw["role"])
      limit = broad ? synthesis_limit : ordinary_limit
      groups = array(raw["topic_groups"])
      # Integration chapters may be the unique teacher of an integration
      # capability. Their wider topic budget and the global two-capability
      # teacher limit already provide the intended scope control.
      violation = groups.length > limit
      exception = raw["scope_exception"]
      valid_exception = exception.is_a?(Hash) && %w[reason reviewer expires_in_edition].all? { |field| nonempty_string?(exception[field]) }
      if violation && !valid_exception
        collector.error("E_SCOPE", source, "#{pointer} exceeds scope limits without a complete expiring exception")
      end
      return unless exception.is_a?(Hash)

      reject_unknown_keys(exception, %w[reason reviewer expires_in_edition], source, "#{pointer}/scope_exception")
      expiry = parse_edition_number(exception["expires_in_edition"], allow_draft: false)
      active = parse_edition_number(edition["edition"], allow_draft: true)
      unless expiry && active && (expiry <=> active) == 1
        collector.error("E_SCOPE", source, "#{pointer}/scope_exception expires_in_edition must use YYYY.N and be later than #{edition['edition']}")
      end
    end

    def parse_edition_number(value, allow_draft:)
      suffix = allow_draft ? "(?:-draft)?" : ""
      match = value.to_s.match(/\A(\d{4})\.([1-9]\d*)#{suffix}\z/)
      match ? [match[1].to_i, match[2].to_i] : nil
    end

    def validate_dependency_graph!
      known = chapters.map { |chapter| chapter["id"] }.to_set
      position = {}
      chapters.each_with_index { |chapter, index| position[chapter["id"]] = index }
      chapters.each do |chapter|
        source = chapter["source_spec"]
        chapter.fetch("prerequisites").each do |dependency|
          collector.error("E_PREREQUISITE_UNKNOWN", source, "#{chapter['id']} references unknown prerequisite #{dependency}") unless known.include?(dependency)
          collector.error("E_PREREQUISITE_SELF", source, "#{chapter['id']} references itself") if dependency == chapter["id"]
          if position.key?(dependency) && position[dependency] >= position[chapter["id"]]
            collector.error("E_ZERO_BASE_ORDER", source, "#{chapter['id']} appears before prerequisite #{dependency}")
          end
        end
        chapter.fetch("prerequisites").each do |dependency|
          redundant_via = chapter.fetch("prerequisites").find do |other|
            other != dependency && ancestors(other).include?(dependency)
          end
          if redundant_via
            collector.warn("W_REDUNDANT_PREREQUISITE", source, "#{chapter['id']} direct edge #{dependency} is already provided through #{redundant_via}")
          end
        end
        array(chapter["borrowed_scaffolds"]).each do |scaffold|
          next unless scaffold.is_a?(Hash)

          later_teacher = scaffold["later_teacher_chapter_id"]
          topic = scaffold["topic"]
          unless known.include?(later_teacher)
            collector.error("E_BORROWED_SCAFFOLD", source, "#{chapter['id']} borrows #{topic} from unknown teacher #{later_teacher}")
            next
          end
          unless position[later_teacher] > position[chapter["id"]]
            collector.error("E_BORROWED_SCAFFOLD", source, "#{chapter['id']} borrowed teacher #{later_teacher} must occur later")
          end
          unless array(chapter_by_id[later_teacher]["topics_taught"]).include?(topic)
            collector.error("E_BORROWED_SCAFFOLD", source, "#{later_teacher} does not teach borrowed topic #{topic}")
          end
        end
      end
      cycle_paths("prerequisites", chapters.each_with_object({}) { |chapter, result| result[chapter["id"]] = chapter["prerequisites"] }).each do |cycle|
        collector.error("E_PREREQUISITE_CYCLE", "curriculum/chapters", cycle.join(" -> "))
      end
    end

    def validate_capabilities!
      known_capabilities = capability_by_id.keys.to_set
      known_chapters = chapter_by_id.keys.to_set
      teachers_from_chapters = Hash.new { |hash, key| hash[key] = [] }
      chapters.each do |chapter|
        contract = chapter["capabilities"].is_a?(Hash) ? chapter["capabilities"] : {}
        taught = array(contract["teaches"])
        used = array(contract["uses"])
        (taught + used).each do |capability|
          collector.error("E_CAPABILITY_UNKNOWN", chapter["source_spec"], "#{chapter['id']} references unknown capability #{capability}") unless known_capabilities.include?(capability)
        end
        taught.each { |capability| teachers_from_chapters[capability] << chapter["id"] }
      end

      capability_graph = {}
      capability_by_id.each do |id, capability|
        requires = array(capability["requires"])
        capability_graph[id] = requires
        unknown = requires.reject { |required| known_capabilities.include?(required) }
        collector.error("E_CAPABILITY_UNKNOWN", "curriculum/capabilities.yml", "#{id} requires unknown capabilities #{unknown.join(',')}") unless unknown.empty?
        teacher = capability["teacher_chapter_id"]
        collector.error("E_CAPABILITY_TEACHER", "curriculum/capabilities.yml", "#{id} teacher #{teacher.inspect} is not an active chapter") unless known_chapters.include?(teacher)
        actual = teachers_from_chapters[id]
        unless actual == [teacher]
          collector.error("E_CAPABILITY_TEACHER", "curriculum/capabilities.yml", "#{id} expected teacher #{teacher.inspect}, chapter declarations=#{actual.inspect}")
        end
      end
      cycle_paths("capability", capability_graph).each do |cycle|
        collector.error("E_CAPABILITY_CYCLE", "curriculum/capabilities.yml", cycle.join(" -> "))
      end

      position = {}
      chapters.each_with_index { |chapter, index| position[chapter["id"]] = index }
      capability_by_id.each do |id, capability|
        teacher = capability["teacher_chapter_id"]
        next unless position.key?(teacher)

        teacher_ancestors = ancestors(teacher)
        array(capability["requires"]).each do |required_id|
          required = capability_by_id[required_id]
          required_teacher = required && required["teacher_chapter_id"]
          next unless position.key?(required_teacher)

          if position[required_teacher] >= position[teacher]
            collector.error(
              "E_CAPABILITY_TEACHER_ORDER",
              "curriculum/capabilities.yml",
              "#{id} teacher #{teacher} appears before required #{required_id} teacher #{required_teacher}"
            )
          end
          unless teacher_ancestors.include?(required_teacher)
            collector.error(
              "E_CAPABILITY_TEACHER_PREREQUISITE",
              "curriculum/capabilities.yml",
              "#{id} teacher #{teacher} lacks required teacher #{required_teacher} in its hard prerequisite closure"
            )
          end
        end

        available_topics = ([teacher] + teacher_ancestors.to_a).flat_map do |chapter_id|
          chapter = chapter_by_id[chapter_id]
          chapter ? array(chapter["topics_taught"]) : []
        end.to_set
        missing_topics = array(capability["required_topic_ids"]).reject { |topic_id| available_topics.include?(topic_id) }
        unless missing_topics.empty?
          collector.error(
            "E_CAPABILITY_TERM_COVERAGE",
            "curriculum/capabilities.yml",
            "#{id} teacher #{teacher} and its hard prerequisites do not teach required topics #{missing_topics.join(',')}"
          )
        end
      end

      ancestor_memo = {}
      chapters.each do |chapter|
        contract = chapter["capabilities"].is_a?(Hash) ? chapter["capabilities"] : {}
        taught = array(contract["teaches"])
        used = array(contract["uses"])
        reachable = ancestors(chapter["id"], ancestor_memo)
        used.each do |capability_id|
          capability = capability_by_id[capability_id]
          next unless capability

          teacher = capability["teacher_chapter_id"]
          unless taught.include?(capability_id) || reachable.include?(teacher)
            collector.error("E_CAPABILITY_FIRST_USE", chapter["source_spec"], "#{chapter['id']} uses #{capability_id} before teacher #{teacher} is in the hard prerequisite closure")
          end
        end
        taught.each do |capability_id|
          evidence_outcome_ids = array(chapter["outcomes"]).each_with_object(Set.new) do |outcome, ids|
            if outcome.is_a?(Hash) && %w[build diagnose].include?(outcome["id"]) && array(outcome["uses_capabilities"]).include?(capability_id)
              ids.add(outcome["id"])
            end
          end
          unless evidence_outcome_ids == Set.new(%w[build diagnose])
            collector.error("E_CAPABILITY_EVIDENCE", chapter["source_spec"], "#{chapter['id']} teaches #{capability_id} without both build and diagnose evidence")
          end
        end
      end
    end

    def validate_topic_contracts!
      entries = array(topics["topics"])
      registered_ids = entries.map { |topic| topic.is_a?(Hash) ? topic["id"] : topic }
      validate_unique_string_array(registered_ids, "curriculum/topics.yml", "/topics")
      registered = registered_ids.select { |id| nonempty_string?(id) }.to_set
      require_registration = topics.dig("policy", "require_explicit_registration") == true
      collector.warn("W_TOPIC_REGISTRY_EMPTY", "curriculum/topics.yml", "topic registry is empty; alias/title checks remain incomplete") if registered.empty?
      topic_teachers = Hash.new { |hash, key| hash[key] = [] }
      chapters.each { |chapter| array(chapter["topics_taught"]).each { |topic| topic_teachers[topic] << chapter["id"] } }
      declared_topics = Set.new
      chapters.each do |chapter|
        declared = array(chapter["topics_taught"]) + array(chapter["topics_used"])
        array(chapter["topic_groups"]).each { |group| declared.concat(array(group["topics"])) if group.is_a?(Hash) }
        declared_topics.merge(declared)
        if require_registration
          unknown = declared.uniq.reject { |topic| registered.include?(topic) }
          collector.error("E_TOPIC_UNKNOWN", chapter["source_spec"], "#{chapter['id']} references unregistered topics #{unknown.join(',')}") unless unknown.empty?
        end
        borrowed = array(chapter["borrowed_scaffolds"]).map { |item| item.is_a?(Hash) ? item["topic"] : nil }.compact
        reachable = ancestors(chapter["id"])
        array(chapter["topics_used"]).each do |topic|
          next if array(chapter["topics_taught"]).include?(topic) || borrowed.include?(topic)

          teachers = topic_teachers[topic]
          if teachers.empty? || teachers.none? { |teacher| reachable.include?(teacher) }
            collector.error("E_TOPIC_FIRST_USE", chapter["source_spec"], "#{chapter['id']} uses topic #{topic} before a teacher is in the hard prerequisite closure")
          end
        end
      end
      if topics.dig("policy", "allow_unreferenced") == false
        stale = registered - declared_topics
        collector.error("E_TOPIC_STALE", "curriculum/topics.yml", "registry contains unreferenced topics #{stale.to_a.join(',')}") unless stale.empty?
      end
      capability_required = capability_by_id.values.flat_map { |capability| array(capability["required_topic_ids"]) }.to_set
      unregistered_required = capability_required - registered
      collector.error("E_CAPABILITY_TERM_COVERAGE", "curriculum/topics.yml", "capabilities require unregistered topics #{unregistered_required.to_a.join(',')}") unless unregistered_required.empty?
    end

    def validate_id_registry!
      entries = array(id_registry["entries"])
      if entries.empty? && edition["status"] == "architecture"
        collector.warn("W_ID_REGISTRY_DRAFT", "curriculum/id-registry.yml", "registry is empty until the #{edition['chapter_count_target']} chapter specs are frozen")
        return
      end
      ids = entries.map { |entry| entry.is_a?(Hash) ? entry["id"] : nil }
      duplicate_values(ids).each do |id|
        collector.error("E_ID_REGISTRY", "curriculum/id-registry.yml", "duplicate registry id #{id.inspect}")
      end
      entries.each_with_index do |entry, index|
        pointer = "/entries/#{index}"
        unless entry.is_a?(Hash)
          collector.error("E_SCHEMA", "curriculum/id-registry.yml", "#{pointer} must be a mapping")
          next
        end
        allowed = entry["status"] == "active" ? %w[id status introduced_in source_spec] : %w[id status introduced_in retired_in]
        reject_unknown_keys(entry, allowed, "curriculum/id-registry.yml", pointer)
        unless %w[active retired].include?(entry["status"])
          collector.error("E_ID_REGISTRY", "curriculum/id-registry.yml", "#{pointer}/status must be active or retired")
        end
        collector.error("E_ID_REGISTRY", "curriculum/id-registry.yml", "#{pointer}/introduced_in must be non-empty") unless nonempty_string?(entry["introduced_in"])
        if entry["status"] == "active"
          collector.error("E_ID_REGISTRY", "curriculum/id-registry.yml", "#{pointer}/source_spec must be a volume spec path") unless entry["source_spec"].to_s.match?(%r{\Acurriculum/chapters/volume-\d{2}\.yml\z})
        else
          collector.error("E_ID_REGISTRY", "curriculum/id-registry.yml", "#{pointer}/id must be a legacy semantic id") unless entry["id"].to_s.match?(/\Av\d{2}\.c\d{2}\.[a-z0-9-]+\z/)
          collector.error("E_ID_REGISTRY", "curriculum/id-registry.yml", "#{pointer}/retired_in must equal the active edition") unless entry["retired_in"] == edition["edition"]
        end
      end
      active = entries.select { |entry| entry["status"] == "active" }.map { |entry| entry["id"] }.to_set
      retired = entries.select { |entry| entry["status"] == "retired" }.map { |entry| entry["id"] }.to_set
      chapter_ids = chapters.map { |chapter| chapter["id"] }.to_set
      missing = chapter_ids - active
      stale = active - chapter_ids
      revived = chapter_ids & retired
      collector.error("E_ID_REGISTRY", "curriculum/id-registry.yml", "active registry missing #{missing.to_a.join(',')}") unless missing.empty?
      collector.error("E_ID_REGISTRY", "curriculum/id-registry.yml", "registry has stale active ids #{stale.to_a.join(',')}") unless stale.empty?
      collector.error("E_ID_REUSE", "curriculum/id-registry.yml", "retired ids revived #{revived.to_a.join(',')}") unless revived.empty?
    end

    def validate_migration!
      schema_validator = JsonSchema.new(migration_schema)
      schema_validator.validate(migration).each do |error|
        collector.error("E_MIGRATION_SCHEMA", edition["migration_ledger"], "#{error.pointer} #{error.message}")
      end
    rescue ArgumentError => e
      collector.error("E_MIGRATION_SCHEMA", "curriculum/migrations/migration.schema.json", e.message)
    ensure
      validate_migration_semantics! if schema_validator
    end

    def validate_migration_semantics!
      validate_legacy_manifest!
      validate_migration_audit!
      validate_application_receipt!
      unless migration["to_edition"] == edition["edition"]
        collector.error("E_MIGRATION_EDITION", edition["migration_ledger"], "to_edition must equal #{edition['edition'].inspect}")
      end
      unless nonempty_string?(migration["from_edition"]) && migration["from_edition"] != migration["to_edition"]
        collector.error("E_MIGRATION_EDITION", edition["migration_ledger"], "from_edition must name a distinct predecessor")
      end
      expected_new = migration["expected_active_id_count"].to_i
      unless expected_new == edition["chapter_count_target"].to_i && expected_new == chapters.length
        collector.error("E_MIGRATION_COVERAGE", edition["migration_ledger"], "expected_active_id_count must equal the compiled chapter target")
      end
      unless migration["compatibility"] == "none"
        collector.error("E_MIGRATION_COMPATIBILITY", edition["migration_ledger"], "runtime compatibility must be none")
      end
      entries = array(migration["entries"])
      if migration["status"] == "drafting" && entries.empty?
        collector.warn("W_MIGRATION_DRAFT", edition["migration_ledger"], "migration ledger is intentionally incomplete")
        return
      end
      from_ids = entries.flat_map { |entry| array(entry["from"]) }
      to_ids = entries.flat_map { |entry| array(entry["to"]) }
      expected_old = migration["expected_legacy_id_count"].to_i
      active_ids = chapters.map { |chapter| chapter["id"] }.to_set
      if %w[ready applied].include?(migration["status"])
        frozen_legacy_ids = array(legacy_manifest["files"]).select { |file| file["kind"] == "legacy-chapter" }.map { |file| file["legacy_id"] }.to_set
        collector.error("E_MIGRATION_COVERAGE", edition["migration_ledger"], "legacy mapping must equal the frozen manifest ID set") unless from_ids.length == from_ids.uniq.length && from_ids.to_set == frozen_legacy_ids && frozen_legacy_ids.length == expected_old
        collector.error("E_MIGRATION_COVERAGE", edition["migration_ledger"], "active target coverage expected #{expected_new}, got #{to_ids.uniq.length}") unless to_ids.length == to_ids.uniq.length && to_ids.to_set == active_ids && active_ids.length == expected_new
      else
        collector.error("E_MIGRATION_COVERAGE", edition["migration_ledger"], "draft entries repeat legacy ids") unless from_ids.length == from_ids.uniq.length
        collector.error("E_MIGRATION_COVERAGE", edition["migration_ledger"], "draft entries repeat active ids") unless to_ids.length == to_ids.uniq.length
        unknown_targets = to_ids.to_set - active_ids
        collector.error("E_MIGRATION_COVERAGE", edition["migration_ledger"], "draft entries target unknown active ids #{unknown_targets.to_a.join(',')}") unless unknown_targets.empty?
      end
      rebuilds = array(migration["source_rebuilds"])
      rebuild_by_id = rebuilds.each_with_object({}) do |rebuild, result|
        id = rebuild.is_a?(Hash) ? rebuild["id"] : nil
        if result.key?(id)
          collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "duplicate source_rebuild id #{id.inspect}")
        else
          result[id] = rebuild
        end
      end
      regeneration_policy = "regenerate-from-frozen-source-inventory"
      entries.each do |entry|
        validate_migration_action_cardinality(entry)
        policy = entry["source_mapping_policy"]
        if %w[split repartition].include?(entry["action"]) && !%w[manual-section-override regenerate-from-frozen-source-inventory].include?(policy)
          collector.error("E_MIGRATION_OVERRIDE", edition["migration_ledger"], "#{entry['action']} must use a reviewed section override or frozen-source regeneration")
        end
        next unless policy == regeneration_policy

        rebuild_id = entry["source_rebuild_id"]
        unless rebuild_id && rebuild_by_id.key?(rebuild_id)
          collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "regeneration entry must reference a declared source_rebuild_id")
        end
      end
      overrides = array(migration["section_overrides"])
      entries.select { |entry| entry["source_mapping_policy"] == "manual-section-override" }.each do |entry|
        related = overrides.select do |override|
          array(entry["from"]).include?(override["from_chapter_id"]) && (array(override["to_chapter_ids"]) - array(entry["to"])).empty?
        end
        collector.error("E_MIGRATION_OVERRIDE", edition["migration_ledger"], "manual mapping #{array(entry['from']).join(',')} has no related section override") if related.empty?
      end
      overrides.each do |override|
        unless from_ids.include?(override["from_chapter_id"]) && (array(override["to_chapter_ids"]) - to_ids).empty?
          collector.error("E_MIGRATION_OVERRIDE", edition["migration_ledger"], "section override references IDs outside migration entries")
        end
      end
      final_status = %w[ready applied].include?(migration["status"])
      if final_status && array(migration["section_overrides"]).any? { |entry| entry["review_status"] == "manual-review-required" }
        collector.error("E_MIGRATION_OVERRIDE", edition["migration_ledger"], "#{migration['status']} migration contains unresolved section overrides")
      end
      if final_status
        referenced_rebuild_ids = entries.select { |entry| entry["source_mapping_policy"] == regeneration_policy }.map { |entry| entry["source_rebuild_id"] }.compact.to_set
        referenced_rebuild_ids.each do |rebuild_id|
          rebuild = rebuild_by_id[rebuild_id]
          next unless rebuild.is_a?(Hash)

          source_commits = rebuild["source_commits"]
          unless source_commits.is_a?(Hash) && source_commits.keys.sort == %w[java-note note] && source_commits.values.all? { |commit| commit.to_s.match?(/\A[0-9a-f]{40}\z/) }
            collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} source_commits must freeze Note and Java-Note commits")
          end
          %w[source_inventory_digest source_build_digest candidate_manifest_digest].each do |field|
            unless rebuild[field].to_s.match?(/\Asha256:[0-9a-f]{64}\z/)
              collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} #{field} must be a sha256 digest")
            end
          end
          {
            "source_inventory_path" => "source_inventory_digest",
            "source_build_path" => "source_build_digest",
            "candidate_manifest_path" => "candidate_manifest_digest"
          }.each do |path_field, digest_field|
            evidence_path = rebuild[path_field]
            unless nonempty_string?(evidence_path) && valid_contract_path?(evidence_path)
              collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} #{path_field} is missing or unsafe")
              next
            end
            evidence = input_contents[evidence_path]
            expected = rebuild[digest_field].to_s.delete_prefix("sha256:")
            unless evidence && Digest::SHA256.hexdigest(evidence) == expected
              collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} #{path_field} does not match #{digest_field}")
            end
          end
          builder_path = rebuild["builder_path"]
          unless builder_path == "scripts/build-source-inventory.rb" && input_contents[builder_path]
            collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} builder_path must reference the snapshotted source inventory builder")
          else
            expected_builder_digest = rebuild["builder_digest"].to_s.delete_prefix("sha256:")
            unless Digest::SHA256.hexdigest(input_contents.fetch(builder_path)) == expected_builder_digest
              collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} builder bytes do not match builder_digest")
            end
          end
          validate_source_rebuild_evidence_semantics!(rebuild_id, rebuild, source_commits)
          statuses = array(rebuild["candidate_statuses"])
          allowed_statuses = %w[unreviewed manual-review-required]
          unless !statuses.empty? && statuses.all? { |status| allowed_statuses.include?(status) }
            collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} candidates must remain unreviewed or manual-review-required")
          end
          unless rebuild["automatic_promotion"] == false
            collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} automatic candidate promotion is forbidden")
          end
        end
      end
    end

    def validate_application_receipt!
      path = migration["application_receipt_path"]
      digest = migration["application_receipt_digest"]
      if migration["status"] != "applied"
        if path || digest || application_receipt
          collector.error("E_MIGRATION_RECEIPT", edition["migration_ledger"], "only an applied migration may carry an application receipt")
        end
        return
      end

      unless nonempty_string?(path) && digest.to_s.match?(/\Asha256:[0-9a-f]{64}\z/) && application_receipt.is_a?(Hash)
        collector.error("E_MIGRATION_RECEIPT", edition["migration_ledger"], "applied migration requires application_receipt_path and application_receipt_digest")
        return
      end
      source = input_contents[path]
      unless source && "sha256:#{Digest::SHA256.hexdigest(source)}" == digest
        collector.error("E_MIGRATION_RECEIPT", path, "receipt bytes do not match application_receipt_digest")
      end
      begin
        JsonSchema.new(application_receipt_schema).validate(application_receipt).each do |error|
          collector.error("E_MIGRATION_RECEIPT_SCHEMA", path, "#{error.pointer} #{error.message}")
        end
      rescue ArgumentError => e
        collector.error("E_MIGRATION_RECEIPT_SCHEMA", "curriculum/migrations/application-receipt.schema.json", e.message)
      end

      receipt = application_receipt
      expect_receipt_equal(receipt["receipt_id"], "#{migration['migration_id']}.application", path, "/receipt_id")
      expect_receipt_equal(receipt["migration_id"], migration["migration_id"], path, "/migration_id")
      ready_digests = array(migration["source_rebuilds"]).map { |rebuild| rebuild["rendered_catalog_projection_digest"] }.uniq
      expected_ready_digest = ready_digests.length == 1 ? ready_digests.first : nil
      expect_receipt_equal(receipt["ready_catalog_projection_digest"], expected_ready_digest, path, "/ready_catalog_projection_digest")
      expect_receipt_equal(receipt["legacy_manifest_digest"], migration["legacy_manifest_digest"], path, "/legacy_manifest_digest")
      expect_receipt_equal(receipt["mapping_audit_digest"], migration["mapping_audit_digest"], path, "/mapping_audit_digest")

      plan = receipt["plan"].is_a?(Hash) ? receipt["plan"] : {}
      actions = array(plan["actions"])
      canonical_actions = actions.sort_by { |action| [action.is_a?(Hash) ? action["path"].to_s : "", action.is_a?(Hash) ? action["action"].to_s : ""] }
      collector.error("E_MIGRATION_RECEIPT", path, "/plan/actions must use deterministic path/action order") unless actions == canonical_actions
      action_counts = %w[create update delete conflict unchanged].each_with_object({}) do |action, result|
        result[action] = actions.count { |entry| entry.is_a?(Hash) && entry["action"] == action }
      end
      expect_receipt_equal(plan["action_counts"], action_counts, path, "/plan/action_counts")
      expect_receipt_equal(plan["plan_digest"], canonical_evidence_digest(actions), path, "/plan/plan_digest")
      validate_receipt_plan_actions!(actions, path)

      write = receipt["write"].is_a?(Hash) ? receipt["write"] : {}
      output_manifest = array(write["output_manifest"])
      canonical_outputs = output_manifest.sort_by { |entry| entry.is_a?(Hash) ? entry["path"].to_s : "" }
      collector.error("E_MIGRATION_RECEIPT", path, "/write/output_manifest must use deterministic path order") unless output_manifest == canonical_outputs
      expect_receipt_equal(write["output_manifest_digest"], canonical_evidence_digest(output_manifest), path, "/write/output_manifest_digest")
      validate_receipt_output_manifest!(actions, output_manifest, path)

      expected_output_count = chapters.length + array(legacy_manifest["files"]).count { |file| file["kind"] == "generated-output" }
      expect_receipt_equal(receipt.dig("check", "exit_code"), 0, path, "/check/exit_code")
      expect_receipt_equal(receipt.dig("check", "unchanged_count"), expected_output_count, path, "/check/unchanged_count")
      expect_receipt_equal(receipt.dig("write", "exit_code"), 0, path, "/write/exit_code")
      expect_receipt_equal(receipt.dig("postconditions", "legacy_chapter_count"), 0, path, "/postconditions/legacy_chapter_count")
      expect_receipt_equal(receipt.dig("postconditions", "semantic_chapter_count"), migration["expected_active_id_count"], path, "/postconditions/semantic_chapter_count")
      collector.error("E_MIGRATION_RECEIPT", path, "/applied_at must be a real UTC timestamp in YYYY-MM-DDTHH:MM:SSZ form") unless valid_receipt_timestamp?(receipt["applied_at"])
      collector.error("E_MIGRATION_RECEIPT", path, "/applied_by must be non-blank, trimmed, and free of control characters") unless valid_receipt_actor?(receipt["applied_by"])
    end

    def validate_receipt_plan_actions!(actions, path)
      legacy_files = array(legacy_manifest["files"])
      generated = legacy_files.select { |file| file["kind"] == "generated-output" }
      legacy = legacy_files.select { |file| file["kind"] == "legacy-chapter" }
      expected_paths = {
        "create" => chapters.map { |chapter| chapter["path"] }.sort,
        "update" => generated.map { |file| file["path"] }.sort,
        "delete" => legacy.map { |file| file["path"] }.sort,
        "conflict" => [],
        "unchanged" => []
      }
      expected_paths.each do |action, paths|
        actual = actions.select { |entry| entry.is_a?(Hash) && entry["action"] == action }.map { |entry| entry["path"] }.sort
        expect_receipt_equal(actual, paths, path, "/plan/actions/#{action}-paths")
      end
      manifest_by_path = legacy_files.each_with_object({}) { |file, result| result[file["path"]] = file }
      actions.each_with_index do |entry, index|
        next unless entry.is_a?(Hash)

        pointer = "/plan/actions/#{index}"
        collector.error("E_MIGRATION_RECEIPT", path, "#{pointer}/path is unsafe") unless valid_contract_path?(entry["path"])
        case entry["action"]
        when "create"
          expect_receipt_equal(entry["before"], "missing", path, "#{pointer}/before")
        when "update", "delete"
          frozen = manifest_by_path[entry["path"]]
          expect_receipt_equal(entry["before"], frozen ? "sha256:#{frozen['sha256']}" : nil, path, "#{pointer}/before")
        end
        expect_receipt_equal(entry["after"], "deleted", path, "#{pointer}/after") if entry["action"] == "delete"
      end
    end

    def validate_receipt_output_manifest!(actions, output_manifest, path)
      expected_paths = (chapters.map { |chapter| chapter["path"] } + array(legacy_manifest["files"]).select { |file| file["kind"] == "generated-output" }.map { |file| file["path"] }).sort
      actual_paths = output_manifest.map { |entry| entry.is_a?(Hash) ? entry["path"] : nil }
      expect_receipt_equal(actual_paths, expected_paths, path, "/write/output_manifest/paths")
      if actual_paths.uniq.length != actual_paths.length
        collector.error("E_MIGRATION_RECEIPT", path, "/write/output_manifest repeats paths")
      end
      output_by_path = output_manifest.each_with_object({}) do |entry, result|
        result[entry["path"]] = entry["sha256"] if entry.is_a?(Hash)
      end
      actions.select { |entry| entry.is_a?(Hash) && %w[create update].include?(entry["action"]) }.each_with_index do |entry, index|
        expect_receipt_equal(entry["after"], "sha256:#{output_by_path[entry['path']]}", path, "/plan/output-after/#{index}")
      end
    end

    def expect_receipt_equal(actual, expected, path, pointer)
      collector.error("E_MIGRATION_RECEIPT", path, "#{pointer} expected #{expected.inspect}, got #{actual.inspect}") unless actual == expected
    end

    def canonical_evidence_digest(value)
      "sha256:#{Digest::SHA256.hexdigest(JSON.generate(canonical_evidence_value(value)))}"
    end

    def canonical_evidence_value(value)
      case value
      when Hash
        value.keys.sort.each_with_object({}) { |key, result| result[key] = canonical_evidence_value(value.fetch(key)) }
      when Array
        value.map { |item| canonical_evidence_value(item) }
      else
        value
      end
    end

    def valid_receipt_timestamp?(value)
      return false unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)

      parsed = Time.iso8601(value)
      parsed.utc? && parsed.iso8601 == value
    rescue ArgumentError
      false
    end

    def valid_receipt_actor?(value)
      nonempty_string?(value) && value == value.strip && value.each_codepoint.none? { |codepoint| codepoint < 0x20 || codepoint == 0x7f }
    end

    def validate_source_rebuild_evidence_semantics!(rebuild_id, rebuild, source_commits)
      inventory = parse_evidence_yaml(rebuild["source_inventory_path"], rebuild_id)
      build = parse_evidence_yaml(rebuild["source_build_path"], rebuild_id)
      candidate = parse_evidence_yaml(rebuild["candidate_manifest_path"], rebuild_id)
      return unless inventory && build && candidate && source_commits.is_a?(Hash)

      [inventory, build, candidate].each do |document|
        collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} evidence catalog_edition must equal active edition") unless document["catalog_edition"] == edition["edition"]
      end
      actual_inventory_commits = {
        "note" => inventory.dig("repositories", "note", "commit"),
        "java-note" => inventory.dig("repositories", "java-note", "commit")
      }
      collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} inventory commits differ from source_commits") unless actual_inventory_commits == source_commits
      build_inputs = build["inputs"].is_a?(Hash) ? build["inputs"] : {}
      unless build_inputs["note_commit"] == source_commits["note"] && build_inputs["java_note_commit"] == source_commits["java-note"]
        collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} build inputs differ from source_commits")
      end
      unless build.dig("builder", "path") == rebuild["builder_path"] && "sha256:#{build.dig('builder', 'sha256')}" == rebuild["builder_digest"]
        collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} build evidence differs from frozen builder")
      end
      unless "sha256:#{build_inputs['rendered_catalog_projection_sha256']}" == rebuild["rendered_catalog_projection_digest"]
        collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} build evidence differs from rendered_catalog_projection_digest")
      end
      unless build.dig("outputs", "mappings_csv_sha256") == candidate["candidate_csv_sha256"]
        collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} candidate manifest does not identify the built mapping bytes")
      end
      statuses = array(rebuild["candidate_statuses"])
      status_counts = candidate["review_status_counts"]
      unless status_counts.is_a?(Hash) && status_counts["reviewed"] == 0 && status_counts["unreviewed"].is_a?(Integer) && status_counts["unreviewed"].positive? && statuses == ["unreviewed"]
        collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} candidates must remain entirely unreviewed")
      end
      unless candidate["mapping_count"] == status_counts["unreviewed"] && candidate["automatic_promotion"] == false
        collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} candidate counts/promotion policy are inconsistent")
      end
    end

    def parse_evidence_yaml(path, rebuild_id)
      source = input_contents[path]
      return nil unless source

      document = StrictYaml.load(source.dup.force_encoding(Encoding::UTF_8), display_path: path)
      return document if document.is_a?(Hash)

      collector.error("E_MIGRATION_REBUILD", edition["migration_ledger"], "#{rebuild_id} #{path} must contain a mapping")
      nil
    rescue DiagnosticError => e
      collector.error(e.code, e.path, e.message)
      nil
    end

    def validate_migration_audit!
      path = migration["mapping_audit_path"]
      source = input_contents[path]
      expected_digest = migration["mapping_audit_digest"]
      unless source && MigrationAudit.digest(source) == expected_digest
        collector.error("E_MIGRATION_AUDIT", path, "audit bytes do not match mapping_audit_digest")
      end
      unless migration["expected_component_count"] == migration_audit.length
        collector.error("E_MIGRATION_AUDIT", path, "expected_component_count must equal parsed audit components")
      end
      audit_edge_count = migration_audit.inject(0) { |sum, component| sum + component.edges.length }
      unless migration["expected_edge_count"] == audit_edge_count
        collector.error("E_MIGRATION_AUDIT", path, "expected_edge_count must equal parsed explicit edges")
      end

      entries = array(migration["entries"])
      entries_by_component = entries.each_with_object({}) do |entry, result|
        component_id = entry.is_a?(Hash) ? entry["component_id"] : nil
        if result.key?(component_id)
          collector.error("E_MIGRATION_AUDIT", edition["migration_ledger"], "duplicate ledger component #{component_id.inspect}")
        else
          result[component_id] = entry
        end
      end
      expected_component_ids = migration_audit.map(&:id)
      unless entries_by_component.keys.to_set == expected_component_ids.to_set
        collector.error("E_MIGRATION_AUDIT", edition["migration_ledger"], "ledger components must exactly equal the independent audit")
      end

      migration_audit.each do |component|
        entry = entries_by_component[component.id]
        next unless entry.is_a?(Hash)

        unless entry["action"] == component.type && array(entry["from"]) == component.old_ids && array(entry["to"]) == component.new_ids
          collector.error("E_MIGRATION_AUDIT", edition["migration_ledger"], "#{component.id} vertices/action differ from the independent audit")
        end
        actual_edges = array(entry["chapter_edges"]).map do |edge|
          edge.is_a?(Hash) ? [edge["from"], edge["to"]] : [nil, nil]
        end
        unless actual_edges == component.edges
          collector.error("E_MIGRATION_AUDIT", edition["migration_ledger"], "#{component.id} explicit edges differ from the independent audit")
        end
      end
    end

    def validate_legacy_manifest!
      path = migration["legacy_manifest_path"]
      source = input_contents[path]
      expected_digest = migration["legacy_manifest_digest"].to_s.delete_prefix("sha256:")
      unless source && Digest::SHA256.hexdigest(source) == expected_digest
        collector.error("E_MIGRATION_MANIFEST", path, "manifest bytes do not match legacy_manifest_digest")
      end
      expect_equal(legacy_manifest["schema_version"], 2, path, "/schema_version")
      expect_equal(legacy_manifest["edition"], migration["from_edition"], path, "/edition")
      expect_equal(legacy_manifest["source_commit"], migration["legacy_source_commit"], path, "/source_commit")
      files = array(legacy_manifest["files"])
      unless legacy_manifest["file_count"].is_a?(Integer) && legacy_manifest["file_count"] == files.length
        collector.error("E_MIGRATION_MANIFEST", path, "file_count must equal files length")
      end
      paths = files.map { |file| file.is_a?(Hash) ? file["path"] : nil }
      duplicate_values(paths).each { |duplicate| collector.error("E_MIGRATION_MANIFEST", path, "duplicate file path #{duplicate.inspect}") }
      legacy_ids = []
      files.each_with_index do |file, index|
        pointer = "/files/#{index}"
        unless file.is_a?(Hash)
          collector.error("E_MIGRATION_MANIFEST", path, "#{pointer} must be a mapping")
          next
        end
        allowed = file["kind"] == "legacy-chapter" ? %w[path sha256 kind legacy_id] : %w[path sha256 kind]
        reject_unknown_keys(file, allowed, path, pointer)
        collector.error("E_MIGRATION_MANIFEST", path, "#{pointer}/path is unsafe") unless valid_contract_path?(file["path"])
        collector.error("E_MIGRATION_MANIFEST", path, "#{pointer}/sha256 must be lowercase SHA-256") unless file["sha256"].to_s.match?(/\A[0-9a-f]{64}\z/)
        unless %w[legacy-chapter generated-output].include?(file["kind"])
          collector.error("E_MIGRATION_MANIFEST", path, "#{pointer}/kind is invalid")
        end
        if file["kind"] == "legacy-chapter"
          legacy_ids << file["legacy_id"]
          collector.error("E_MIGRATION_MANIFEST", path, "#{pointer}/legacy_id must match its filename") unless file["legacy_id"] == File.basename(file["path"].to_s, ".md")
        end
        next unless nonempty_string?(file["path"])

        frozen, error_text, status = Open3.capture3("git", "show", "#{migration['legacy_source_commit']}:#{file['path']}", chdir: root)
        unless status.success? && Digest::SHA256.hexdigest(frozen) == file["sha256"]
          collector.error("E_MIGRATION_MANIFEST", path, "#{pointer} does not match frozen Git source: #{error_text.strip}")
        end
      end
      unless legacy_manifest["legacy_id_count"].is_a?(Integer) && legacy_manifest["legacy_id_count"] == legacy_ids.uniq.length
        collector.error("E_MIGRATION_MANIFEST", path, "legacy_id_count must equal unique legacy chapter IDs")
      end
      retired_ids = array(id_registry["entries"]).select { |entry| entry.is_a?(Hash) && entry["status"] == "retired" }.map { |entry| entry["id"] }.to_set
      unless retired_ids == legacy_ids.to_set
        collector.error("E_MIGRATION_MANIFEST", path, "retired ID registry must exactly equal manifest legacy IDs")
      end
    end

    def validate_migration_action_cardinality(entry)
      from_count = array(entry["from"]).length
      to_count = array(entry["to"]).length
      valid = case entry["action"]
      when "preserve", "replace" then from_count == 1 && to_count == 1
      when "split" then from_count == 1 && to_count >= 2
      when "merge" then from_count >= 2 && to_count == 1
      when "repartition" then from_count >= 1 && to_count >= 1 && (from_count > 1 || to_count > 1)
      when "remove" then from_count >= 1 && to_count.zero?
      when "new" then from_count.zero? && to_count >= 1
      else false
      end
      collector.error("E_MIGRATION_CARDINALITY", edition["migration_ledger"], "#{entry['action'].inspect} has invalid #{from_count}→#{to_count} cardinality") unless valid

      allowed_policies = case entry["action"]
      when "preserve", "replace" then %w[automatic-one-to-one]
      when "merge" then %w[automatic-merge-with-provenance manual-section-override]
      when "split", "repartition" then %w[manual-section-override regenerate-from-frozen-source-inventory]
      when "remove", "new" then %w[not-applicable]
      else []
      end
      unless allowed_policies.include?(entry["source_mapping_policy"])
        collector.error("E_MIGRATION_POLICY", edition["migration_ledger"], "#{entry['action'].inspect} cannot use #{entry['source_mapping_policy'].inspect}")
      end
    end

    def validate_route_plans!
      validate_route_plan_shapes!
      validate_factorycare_gate_registry!
      known_chapters = chapter_by_id.keys.to_set
      {
        "curriculum/route-plans/accelerated-48.yml" => accelerated_plan,
        "curriculum/route-plans/factorycare-project.yml" => factorycare_plan,
        "curriculum/route-plans/gates.yml" => gates_plan
      }.each do |path, plan|
        expect_equal(plan["schema_version"], 2, path, "/schema_version")
        expect_equal(plan["edition"], edition["edition"], path, "/edition")
      end
      expected_modules = (1..48).map { |number| format("m%02d", number) }
      modules = array(accelerated_plan["modules"])
      unless accelerated_plan["module_count"].is_a?(Integer) && accelerated_plan["module_count"] == modules.length && modules.length == 48
        collector.error("E_ACCELERATED_MODULES", "curriculum/route-plans/accelerated-48.yml", "module_count must equal the 48 declared modules")
      end
      actual_modules = modules.map { |mod| mod["id"] }
      collector.error("E_ACCELERATED_MODULES", "curriculum/route-plans/accelerated-48.yml", "module ids must be m01..m48") unless actual_modules == expected_modules
      modules.each_with_index do |mod, index|
        pointer = "/modules/#{index}"
        validate_unique_string_array(mod["required_capabilities"], "curriculum/route-plans/accelerated-48.yml", "#{pointer}/required_capabilities", nonempty: true)
        validate_unique_string_array(mod["anchor_chapter_ids"], "curriculum/route-plans/accelerated-48.yml", "#{pointer}/anchor_chapter_ids", nonempty: true)
        unknown = array(mod["anchor_chapter_ids"]).reject { |id| known_chapters.include?(id) }
        collector.error("E_ACCELERATED_ANCHOR", "curriculum/route-plans/accelerated-48.yml", "#{pointer} unknown anchors #{unknown.join(',')}") unless unknown.empty?
      end
      declared_caps = modules.flat_map { |mod| array(mod["required_capabilities"]) }.to_set
      missing_caps = capability_by_id.keys.to_set - declared_caps
      collector.error("E_ACCELERATED_MODULES", "curriculum/route-plans/accelerated-48.yml", "capabilities absent from modules #{missing_caps.to_a.join(',')}") unless missing_caps.empty?
      stages = array(factorycare_plan["stages"])
      expected_stages = %w[fc-01-foundation fc-02-users fc-03-devices fc-04-work-orders fc-05-sla-events fc-06-multiclient fc-07-ai fc-08-deploy]
      collector.error("E_FACTORYCARE_STAGES", "curriculum/route-plans/factorycare-project.yml", "stage ids must remain the eight business stages") unless stages.map { |stage| stage["id"] } == expected_stages
      primary_owner = {}
      factory_gate_ids = []
      stages.each_with_index do |stage, index|
        pointer = "/stages/#{index}"
        validate_unique_string_array(stage["required_capabilities"], "curriculum/route-plans/factorycare-project.yml", "#{pointer}/required_capabilities", nonempty: true)
        validate_unique_string_array(stage["primary_anchor_chapter_ids"], "curriculum/route-plans/factorycare-project.yml", "#{pointer}/primary_anchor_chapter_ids", nonempty: true)
        array(stage["primary_anchor_chapter_ids"]).each do |id|
          collector.error("E_FACTORYCARE_PRIMARY", "curriculum/route-plans/factorycare-project.yml", "#{pointer} unknown primary anchor #{id}") unless known_chapters.include?(id)
          if primary_owner.key?(id)
            collector.error("E_FACTORYCARE_PRIMARY", "curriculum/route-plans/factorycare-project.yml", "#{pointer} repeats #{id} first owned by #{primary_owner[id]}")
          else
            primary_owner[id] = stage["id"]
          end
        end
        gate_id = stage["gate_id"]
        if nonempty_string?(gate_id)
          factory_gate_ids << gate_id
        else
          collector.error("E_FACTORYCARE_PLAN", "curriculum/route-plans/factorycare-project.yml", "#{pointer}/gate_id must name a stage gate")
        end
      end
      duplicate_values(factory_gate_ids).each do |id|
        collector.error("E_FACTORYCARE_PLAN", "curriculum/route-plans/factorycare-project.yml", "duplicate stage gate id #{id.inspect}")
      end
      gates = array(gates_plan["gates"])
      collector.error("E_GATE_SET", "curriculum/route-plans/gates.yml", "gate ids must be G0..G8") unless gates.map { |gate| gate["id"] } == (0..8).map { |number| "G#{number}" }
      known_gate_ids = gates.map { |gate| gate["id"] }.to_set
      gate_position = gates.each_with_index.each_with_object({}) { |(gate, index), positions| positions[gate["id"]] = index }
      gates.each_with_index do |gate, index|
        pointer = "/gates/#{index}"
        validate_unique_string_array(gate["required_capabilities"], "curriculum/route-plans/gates.yml", "#{pointer}/required_capabilities")
        validate_unique_string_array(gate["prerequisite_gate_ids"], "curriculum/route-plans/gates.yml", "#{pointer}/prerequisite_gate_ids")
        array(gate["prerequisite_gate_ids"]).each do |id|
          if !known_gate_ids.include?(id)
            collector.error("E_GATE_PREREQUISITE", "curriculum/route-plans/gates.yml", "#{pointer} references unknown prerequisite gate #{id}")
          elsif gate_position[id] >= index
            collector.error("E_GATE_PREREQUISITE", "curriculum/route-plans/gates.yml", "#{pointer} prerequisite #{id} must occur earlier")
          end
        end
        collector.error("E_GATE_ASSESSMENT", "curriculum/route-plans/gates.yml", "#{pointer}/assessment_anchor must be non-empty") unless nonempty_string?(gate["assessment_anchor"])
        unless [nil, "all-active-chapters"].include?(gate["coverage"])
          collector.error("E_GATE_COVERAGE", "curriculum/route-plans/gates.yml", "#{pointer}/coverage must be all-active-chapters when present")
        end
        validate_unique_string_array(gate["artifact_focus"], "curriculum/route-plans/gates.yml", "#{pointer}/artifact_focus", nonempty: true)
        validate_unique_string_array(gate["rubric_focus"], "curriculum/route-plans/gates.yml", "#{pointer}/rubric_focus", nonempty: true)
        unless array(gate["rubric_focus"]).length == 4
          collector.error("E_GATE_RUBRIC", "curriculum/route-plans/gates.yml", "#{pointer}/rubric_focus must contain exactly four weighted dimensions")
        end
      end
      cycle_paths("gate", gates.each_with_object({}) { |gate, graph| graph[gate["id"]] = array(gate["prerequisite_gate_ids"]) }).each do |cycle|
        collector.error("E_GATE_PREREQUISITE", "curriculum/route-plans/gates.yml", cycle.join(" -> "))
      end
      volume_by_id.each do |volume_id, volume|
        %w[stage_gate_id final_gate_id].each do |field|
          next unless volume[field]

          collector.error("E_GATE_REFERENCE", "curriculum/volumes.yml", "volume #{volume_id} references unknown #{field} #{volume[field]}") unless known_gate_ids.include?(volume[field])
        end
      end
      chapters.each do |chapter|
        unknown = array(chapter.dig("gate_requirements", "gate_ids")).reject { |id| known_gate_ids.include?(id) }
        collector.error("E_GATE_REFERENCE", chapter["source_spec"], "#{chapter['id']} references unknown gates #{unknown.join(',')}") unless unknown.empty?
      end

      [accelerated_plan, factorycare_plan, gates_plan].each do |plan|
        plan_caps = []
        plan_caps.concat(array(plan["modules"]).flat_map { |item| array(item["required_capabilities"]) })
        plan_caps.concat(array(plan["stages"]).flat_map { |item| array(item["required_capabilities"]) })
        plan_caps.concat(array(plan["gates"]).flat_map { |item| array(item["required_capabilities"]) })
        unknown = plan_caps.uniq.reject { |id| capability_by_id.key?(id) }
        collector.error("E_CAPABILITY_UNKNOWN", "curriculum/route-plans", "route plan references unknown capabilities #{unknown.join(',')}") unless unknown.empty?
      end
    end

    def validate_factorycare_gate_registry!
      registry_path = "curriculum/factorycare-stage-gates.yml"
      schema_path = "schemas/factorycare-stage-gates.schema.json"
      begin
        JsonSchema.new(factorycare_gate_schema).validate(factorycare_gate_registry).each do |error|
          collector.error("E_FACTORYCARE_GATE_SCHEMA", registry_path, "#{error.pointer} #{error.message}")
        end
      rescue ArgumentError => e
        collector.error("E_FACTORYCARE_GATE_SCHEMA", schema_path, e.message)
      end
      return unless factorycare_gate_registry.is_a?(Hash)

      expected_gate_ids = (1..8).map { |number| format("fc-stage-%02d", number) }
      expected_stage_ids = %w[
        fc-01-foundation fc-02-users fc-03-devices fc-04-work-orders
        fc-05-sla-events fc-06-multiclient fc-07-ai fc-08-deploy
      ]
      gates = array(factorycare_gate_registry["gates"])
      collector.error("E_FACTORYCARE_GATE_SET", registry_path, "gate ids must remain fc-stage-01..fc-stage-08") unless gates.map { |gate| gate["id"] } == expected_gate_ids
      collector.error("E_FACTORYCARE_GATE_SET", registry_path, "route stage ids must match the eight business stages in order") unless gates.map { |gate| gate["route_stage_id"] } == expected_stage_ids

      catalog_ids = factorycare_acceptance_catalog_source.to_s.each_line.each_with_object([]) do |line, ids|
        match = /^\| (FC-[A-Z]+-[0-9]{3}) \|/.match(line)
        ids << match[1] if match
      end
      duplicate_values(catalog_ids).each do |id|
        collector.error("E_FACTORYCARE_ACCEPTANCE_DUPLICATE", factorycare_gate_registry["acceptance_catalog_path"], "duplicate acceptance id #{id}")
      end
      unless catalog_ids.length == 93 && catalog_ids.uniq.length == 93
        collector.error("E_FACTORYCARE_ACCEPTANCE_COUNT", factorycare_gate_registry["acceptance_catalog_path"], "acceptance catalog must contain exactly 93 unique FC ids")
      end
      known_acceptance_ids = catalog_ids.to_set
      allowed_evidence_kinds = array(factorycare_gate_registry["allowed_evidence_kinds"])
      expected_evidence_kinds = %w[runnable-slice negative-path decision-record teach-back]
      unless allowed_evidence_kinds == expected_evidence_kinds
        collector.error("E_FACTORYCARE_EVIDENCE_KIND", registry_path, "allowed_evidence_kinds must use the fixed ordered four-kind contract")
      end

      route_stages = array(factorycare_plan["stages"])
      route_by_id = route_stages.each_with_object({}) do |stage, result|
        result[stage["id"]] = stage if stage.is_a?(Hash) && nonempty_string?(stage["id"])
      end
      primary_owner = {}
      gates.each_with_index do |gate, index|
        next unless gate.is_a?(Hash)

        pointer = "/gates/#{index}"
        route_stage_id = gate["route_stage_id"]
        route_stage = route_by_id[route_stage_id]
        if route_stage.nil?
          collector.error("E_FACTORYCARE_GATE_ROUTE", registry_path, "#{pointer}/route_stage_id references no project stage")
        elsif route_stage["gate_id"] != gate["id"]
          collector.error("E_FACTORYCARE_GATE_ROUTE", "curriculum/route-plans/factorycare-project.yml", "stage #{route_stage_id} must reference #{gate['id']}")
        end

        primary_ids = array(gate["primary_acceptance_ids"])
        secondary_ids = array(gate["secondary_acceptance_ids"])
        validate_unique_string_array(primary_ids, registry_path, "#{pointer}/primary_acceptance_ids", nonempty: true)
        validate_unique_string_array(secondary_ids, registry_path, "#{pointer}/secondary_acceptance_ids")
        overlap = primary_ids & secondary_ids
        collector.error("E_FACTORYCARE_ACCEPTANCE_SECONDARY", registry_path, "#{pointer} repeats primary ids as secondary #{overlap.join(',')}") unless overlap.empty?
        unknown = (primary_ids + secondary_ids).uniq.reject { |id| known_acceptance_ids.include?(id) }
        collector.error("E_FACTORYCARE_ACCEPTANCE_UNKNOWN", registry_path, "#{pointer} references unknown acceptance ids #{unknown.join(',')}") unless unknown.empty?
        primary_ids.each do |id|
          if primary_owner.key?(id)
            collector.error("E_FACTORYCARE_ACCEPTANCE_PRIMARY", registry_path, "#{id} has primary stages #{primary_owner[id]} and #{gate['id']}")
          else
            primary_owner[id] = gate["id"]
          end
        end

        evidence_kinds = array(gate["required_evidence_kinds"])
        validate_unique_string_array(evidence_kinds, registry_path, "#{pointer}/required_evidence_kinds", nonempty: true)
        unless evidence_kinds == expected_evidence_kinds
          collector.error("E_FACTORYCARE_EVIDENCE_KIND", registry_path, "#{pointer}/required_evidence_kinds must require all four fixed kinds in order")
        end
        validate_unique_string_array(gate["negative_scenarios"], registry_path, "#{pointer}/negative_scenarios", nonempty: true)
        validate_unique_string_array(gate["artifact_paths"], registry_path, "#{pointer}/artifact_paths", nonempty: true)
        artifact_root = route_stage_id.to_s.sub(/\Afc-/, "")
        array(gate["artifact_paths"]).each do |artifact_path|
          unless valid_contract_path?(artifact_path) && artifact_path.start_with?("evidence/factorycare/#{artifact_root}/")
            collector.error("E_FACTORYCARE_PATH", registry_path, "#{pointer}/artifact_paths must stay under evidence/factorycare/#{artifact_root}/")
          end
        end
      end

      missing = known_acceptance_ids - primary_owner.keys.to_set
      extra = primary_owner.keys.to_set - known_acceptance_ids
      collector.error("E_FACTORYCARE_ACCEPTANCE_COVERAGE", registry_path, "missing primary acceptance ids #{missing.to_a.sort.join(',')}") unless missing.empty?
      collector.error("E_FACTORYCARE_ACCEPTANCE_UNKNOWN", registry_path, "unknown primary acceptance ids #{extra.to_a.sort.join(',')}") unless extra.empty?
      unless primary_owner.length == 93
        collector.error("E_FACTORYCARE_ACCEPTANCE_COVERAGE", registry_path, "primary stage ownership must cover 93/93 acceptance ids, got #{primary_owner.length}")
      end
    end

    def validate_route_plan_shapes!
      accelerated_path = "curriculum/route-plans/accelerated-48.yml"
      reject_unknown_keys(accelerated_plan, %w[schema_version edition route_id route_kind module_count ownership_policy mastery_policy module_defaults modules], accelerated_path, "/")
      expect_equal(accelerated_plan["route_id"], "accelerated-48", accelerated_path, "/route_id")
      expect_equal(accelerated_plan["route_kind"], "accelerated", accelerated_path, "/route_kind")
      ownership = accelerated_plan["ownership_policy"]
      reject_unknown_keys(ownership, %w[strategy every_active_chapter_has_one_primary_owner support_closure_may_repeat unanchored_tail_owner chapter_roles], accelerated_path, "/ownership_policy")
      expect_equal(ownership["strategy"], "ordered-anchor-boundaries", accelerated_path, "/ownership_policy/strategy") if ownership.is_a?(Hash)
      expect_equal(ownership["unanchored_tail_owner"], "m48", accelerated_path, "/ownership_policy/unanchored_tail_owner") if ownership.is_a?(Hash)
      validate_boolean_fields(ownership, %w[every_active_chapter_has_one_primary_owner support_closure_may_repeat], accelerated_path, "/ownership_policy")
      validate_unique_string_array(ownership["chapter_roles"], accelerated_path, "/ownership_policy/chapter_roles", nonempty: true) if ownership.is_a?(Hash)

      defaults = accelerated_plan["module_defaults"]
      reject_unknown_keys(defaults, %w[diagnostic_policy waiver_policy retest_policy], accelerated_path, "/module_defaults")
      if defaults.is_a?(Hash)
        reject_unknown_keys(defaults["diagnostic_policy"], %w[pass_threshold valid_for_days evidence_kinds], accelerated_path, "/module_defaults/diagnostic_policy")
        reject_unknown_keys(defaults["waiver_policy"], %w[allowed scope required_evidence], accelerated_path, "/module_defaults/waiver_policy")
        reject_unknown_keys(defaults["retest_policy"], %w[delay_hours new_variant max_attempts], accelerated_path, "/module_defaults/retest_policy")
      end
      validate_accelerated_mastery_policy!
      array(accelerated_plan["modules"]).each_with_index do |mod, index|
        reject_unknown_keys(mod, %w[id title required_mastery evidence_requirements required_capabilities anchor_chapter_ids], accelerated_path, "/modules/#{index}")
        collector.error("E_SCHEMA", accelerated_path, "/modules/#{index}/title must be non-empty") unless mod.is_a?(Hash) && nonempty_string?(mod["title"])
      end

      factory_path = "curriculum/route-plans/factorycare-project.yml"
      reject_unknown_keys(factorycare_plan, %w[schema_version edition route_id route_kind coverage support_policy stage_defaults stages], factory_path, "/")
      expect_equal(factorycare_plan["route_id"], "factorycare-project", factory_path, "/route_id")
      expect_equal(factorycare_plan["route_kind"], "project", factory_path, "/route_kind")
      expect_equal(factorycare_plan["coverage"], "selective", factory_path, "/coverage")
      support = factorycare_plan["support_policy"]
      reject_unknown_keys(support, %w[include_hard_prerequisite_closure primary_owner_unique_across_stages supporting_chapters_may_repeat require_teacher_before_use_within_stage], factory_path, "/support_policy")
      validate_boolean_fields(support, %w[include_hard_prerequisite_closure primary_owner_unique_across_stages supporting_chapters_may_repeat require_teacher_before_use_within_stage], factory_path, "/support_policy")
      stage_defaults = factorycare_plan["stage_defaults"]
      reject_unknown_keys(stage_defaults, %w[artifact_root artifact_policy], factory_path, "/stage_defaults")
      expect_equal(stage_defaults["artifact_root"], "evidence/factorycare", factory_path, "/stage_defaults/artifact_root") if stage_defaults.is_a?(Hash)
      if stage_defaults.is_a?(Hash)
        artifact_policy = stage_defaults["artifact_policy"]
        reject_unknown_keys(artifact_policy, %w[owner lifecycle prepopulation absence_before_stage], factory_path, "/stage_defaults/artifact_policy")
        if artifact_policy.is_a?(Hash)
          expect_equal(artifact_policy["owner"], "learner", factory_path, "/stage_defaults/artifact_policy/owner")
          expect_equal(artifact_policy["lifecycle"], "produced-during-study", factory_path, "/stage_defaults/artifact_policy/lifecycle")
          expect_equal(artifact_policy["prepopulation"], "forbidden", factory_path, "/stage_defaults/artifact_policy/prepopulation")
          expect_equal(artifact_policy["absence_before_stage"], "expected", factory_path, "/stage_defaults/artifact_policy/absence_before_stage")
        end
      end
      array(factorycare_plan["stages"]).each_with_index do |stage, index|
        pointer = "/stages/#{index}"
        reject_unknown_keys(stage, %w[id title required_capabilities primary_anchor_chapter_ids business_deliverables gate_id], factory_path, pointer)
        validate_unique_string_array(stage["business_deliverables"], factory_path, "#{pointer}/business_deliverables", nonempty: true) if stage.is_a?(Hash)
        collector.error("E_SCHEMA", factory_path, "#{pointer}/gate_id must be non-empty") unless stage.is_a?(Hash) && nonempty_string?(stage["gate_id"])
      end

      gates_path = "curriculum/route-plans/gates.yml"
      reject_unknown_keys(gates_plan, %w[schema_version edition gates_id canonical_source policy gate_defaults gates], gates_path, "/")
      expect_equal(gates_plan["gates_id"], "factorycare-stage-gates", gates_path, "/gates_id")
      collector.error("E_SCHEMA", gates_path, "/canonical_source must be non-empty") unless nonempty_string?(gates_plan["canonical_source"])
      policy = gates_plan["policy"]
      policy_keys = %w[derive_required_chapters_from_capability_teachers include_hard_prerequisite_closure progress_is_evidence_based no_auto_pass_from_document_completion critical_failure_cannot_be_offset_by_score]
      reject_unknown_keys(policy, policy_keys, gates_path, "/policy")
      validate_boolean_fields(policy, policy_keys, gates_path, "/policy")
      gate_defaults = gates_plan["gate_defaults"]
      reject_unknown_keys(gate_defaults, %w[assessment_mode mandatory_evidence_kinds critical_failures rubric retest], gates_path, "/gate_defaults")
      if gate_defaults.is_a?(Hash)
        validate_unique_string_array(gate_defaults["mandatory_evidence_kinds"], gates_path, "/gate_defaults/mandatory_evidence_kinds", nonempty: true)
        validate_unique_string_array(gate_defaults["critical_failures"], gates_path, "/gate_defaults/critical_failures", nonempty: true)
        rubric = gate_defaults["rubric"]
        reject_unknown_keys(rubric, %w[min_total min_critical_dimension dimension_weights critical_dimension_count], gates_path, "/gate_defaults/rubric")
        if rubric.is_a?(Hash)
          weights = rubric["dimension_weights"]
          valid_weights = weights.is_a?(Array) && weights.length == 4 && weights.all? { |weight| weight.is_a?(Integer) && weight.positive? } && weights.inject(0, :+) == 100
          collector.error("E_GATE_RUBRIC", gates_path, "/gate_defaults/rubric/dimension_weights must contain four positive integers totaling 100") unless valid_weights
          %w[min_total min_critical_dimension].each do |field|
            value = rubric[field]
            collector.error("E_GATE_RUBRIC", gates_path, "/gate_defaults/rubric/#{field} must be an integer from 1 to 100") unless value.is_a?(Integer) && value.between?(1, 100)
          end
          critical = rubric["critical_dimension_count"]
          collector.error("E_GATE_RUBRIC", gates_path, "/gate_defaults/rubric/critical_dimension_count must be 1..4") unless critical.is_a?(Integer) && critical.between?(1, 4)
        end
        retest = gate_defaults["retest"]
        reject_unknown_keys(retest, %w[scope delay_hours new_variant max_attempts], gates_path, "/gate_defaults/retest")
      end
      array(gates_plan["gates"]).each_with_index do |gate, index|
        reject_unknown_keys(gate, %w[id title level prerequisite_gate_ids required_capabilities assessment_anchor artifact_focus rubric_focus coverage], gates_path, "/gates/#{index}")
      end
    end

    def validate_accelerated_mastery_policy!
      path = "curriculum/route-plans/accelerated-48.yml"
      schema_path = "schemas/accelerated-route-plan.schema.json"
      begin
        JsonSchema.new(accelerated_route_schema).validate(accelerated_plan).each do |error|
          collector.error("E_ACCELERATED_ROUTE_SCHEMA", path, "#{error.pointer} #{error.message}")
        end
      rescue ArgumentError => e
        collector.error("E_ACCELERATED_ROUTE_SCHEMA", schema_path, e.message)
      end

      policy = accelerated_plan["mastery_policy"]
      unless policy.is_a?(Hash)
        collector.error("E_ROUTE_MASTERY_POLICY", path, "/mastery_policy must be a mapping")
        return
      end

      reject_unknown_keys(
        policy,
        %w[reference_depth_source route_required_mastery_field profiles required_assignments],
        path,
        "/mastery_policy"
      )
      unless policy["reference_depth_source"] == "curriculum/catalog.yml#/chapters/*/level"
        collector.error(
          "E_ROUTE_MASTERY_POLICY",
          path,
          "/mastery_policy/reference_depth_source must preserve chapter level as encyclopedia reference depth"
        )
      end
      unless policy["route_required_mastery_field"] == "required_mastery"
        collector.error(
          "E_ROUTE_MASTERY_POLICY",
          path,
          "/mastery_policy/route_required_mastery_field must be required_mastery"
        )
      end

      profiles = policy["profiles"]
      unless profiles.is_a?(Hash)
        collector.error("E_ROUTE_MASTERY_POLICY", path, "/mastery_policy/profiles must be a mapping")
        profiles = {}
      end
      extra_profiles = profiles.keys - ACCELERATED_MASTERY_PROFILES.keys
      missing_profiles = ACCELERATED_MASTERY_PROFILES.keys - profiles.keys
      unless extra_profiles.empty? && missing_profiles.empty?
        collector.error(
          "E_ROUTE_MASTERY_POLICY",
          path,
          "/mastery_policy/profiles must define exactly #{ACCELERATED_MASTERY_PROFILES.keys.join(',')}"
        )
      end
      ACCELERATED_MASTERY_PROFILES.each do |level, expected_evidence|
        next if profiles[level] == expected_evidence

        collector.error(
          "E_ROUTE_MASTERY_EVIDENCE",
          path,
          "/mastery_policy/profiles/#{level} must equal #{expected_evidence.join(',')} in order"
        )
      end

      assignments = policy["required_assignments"]
      unless assignments.is_a?(Hash)
        collector.error("E_ROUTE_MASTERY_POLICY", path, "/mastery_policy/required_assignments must be a mapping")
        assignments = {}
      end
      reject_unknown_keys(assignments, ACCELERATED_MASTERY_ASSIGNMENTS.keys, path, "/mastery_policy/required_assignments")
      ACCELERATED_MASTERY_ASSIGNMENTS.each do |domain, expected|
        actual = assignments[domain]
        unless actual.is_a?(Hash)
          collector.error("E_ROUTE_MASTERY_ASSIGNMENT", path, "/mastery_policy/required_assignments/#{domain} must be a mapping")
          next
        end
        reject_unknown_keys(actual, %w[modules required_mastery], path, "/mastery_policy/required_assignments/#{domain}")
        unless actual["modules"] == expected["modules"] && actual["required_mastery"] == expected["required_mastery"]
          collector.error(
            "E_ROUTE_MASTERY_ASSIGNMENT",
            path,
            "/mastery_policy/required_assignments/#{domain} must assign #{expected['modules'].join(',')} to #{expected['required_mastery']}"
          )
        end
      end

      modules = array(accelerated_plan["modules"])
      modules.each_with_index do |mod, index|
        pointer = "/modules/#{index}"
        unless mod.is_a?(Hash) && ACCELERATED_MASTERY_PROFILES.key?(mod["required_mastery"])
          collector.error(
            "E_ROUTE_MASTERY",
            path,
            "#{pointer}/required_mastery must be one of #{ACCELERATED_MASTERY_PROFILES.keys.join(',')}"
          )
          next
        end
        evidence = mod["evidence_requirements"]
        validate_unique_string_array(evidence, path, "#{pointer}/evidence_requirements", nonempty: true)
        expected_evidence = ACCELERATED_MASTERY_PROFILES.fetch(mod["required_mastery"])
        next if evidence == expected_evidence

        collector.error(
          "E_ROUTE_MASTERY_EVIDENCE",
          path,
          "#{pointer}/evidence_requirements must match #{mod['required_mastery']} profile exactly"
        )
      end

      by_id = modules.each_with_object({}) do |mod, result|
        result[mod["id"]] = mod if mod.is_a?(Hash) && nonempty_string?(mod["id"])
      end
      ACCELERATED_MASTERY_ASSIGNMENTS.each do |domain, assignment|
        assignment["modules"].each do |module_id|
          actual = by_id.dig(module_id, "required_mastery")
          next if actual == assignment["required_mastery"]

          collector.error(
            "E_ROUTE_MASTERY_ASSIGNMENT",
            path,
            "#{domain} requires #{module_id}=#{assignment['required_mastery']}, got #{actual.inspect}"
          )
        end
      end
    end

    def validate_boolean_fields(value, fields, path, pointer)
      return unless value.is_a?(Hash)

      fields.each do |field|
        collector.error("E_SCHEMA", path, "#{pointer}/#{field} must be boolean") unless value[field] == true || value[field] == false
      end
    end

    def cycle_paths(_name, graph)
      state = {}
      stack = []
      cycles = []
      visit = nil
      visit = lambda do |node|
        case state[node]
        when :visiting
          start = stack.index(node) || 0
          cycles << stack[start..-1] + [node]
          return
        when :done
          return
        end
        state[node] = :visiting
        stack << node
        array(graph[node]).each { |dependency| visit.call(dependency) if graph.key?(dependency) }
        stack.pop
        state[node] = :done
      end
      graph.keys.each { |node| visit.call(node) }
      cycles.uniq
    end

    def expect_hash(value, path, pointer)
      collector.error("E_SCHEMA", path, "#{pointer} must be a mapping") unless value.is_a?(Hash)
    end

    def expect_equal(actual, expected, path, pointer)
      collector.error("E_SCHEMA", path, "#{pointer} expected #{expected.inspect}, got #{actual.inspect}") unless actual == expected
    end

    def reject_unknown_keys(value, allowed, path, pointer)
      unless value.is_a?(Hash)
        collector.error("E_SCHEMA", path, "#{pointer} must be a mapping")
        return
      end

      unknown = value.keys - allowed
      collector.error("E_SCHEMA", path, "#{pointer} unknown fields #{unknown.join(',')}") unless unknown.empty?
    end

    def validate_unique_string_array(value, source, pointer, nonempty: false)
      unless value.is_a?(Array) && value.all? { |item| nonempty_string?(item) }
        collector.error("E_SCHEMA", source, "#{pointer} must be an array of non-empty strings")
        return
      end
      collector.error("E_SCHEMA", source, "#{pointer} contains duplicates") unless value.uniq.length == value.length
      collector.error("E_SCHEMA", source, "#{pointer} cannot be empty") if nonempty && value.empty?
    end

    def compile_pattern(pattern)
      Regexp.new(pattern.to_s)
    rescue RegexpError => e
      collector.error("E_SCHEMA", "curriculum/edition.yml", "invalid chapter_id_pattern: #{e.message}")
      nil
    end

    def nonempty_string?(value)
      value.is_a?(String) && !value.strip.empty?
    end

    def valid_contract_path?(value)
      return false unless nonempty_string?(value)
      return false if value.each_codepoint.any? { |codepoint| codepoint < 0x20 || codepoint == 0x7f }
      return false if value.include?("\\") || value.include?("//")

      normalized = value.end_with?("/") ? value[0...-1] : value
      return false if normalized.empty? || normalized.split("/").any? { |part| part == "." || part == ".." }

      clean = Pathname.new(normalized).cleanpath.to_s
      !Pathname.new(normalized).absolute? && clean == normalized && !clean.start_with?("../")
    end

    def duplicate_values(values)
      counts = Hash.new(0)
      values.each { |value| counts[value] += 1 }
      counts.select { |_value, count| count > 1 }.keys
    end

    def array(value)
      value.is_a?(Array) ? value : []
    end

    def deep_copy(value)
      Marshal.load(Marshal.dump(value))
    end

    def relative(path)
      path.delete_prefix(root + File::SEPARATOR)
    end
  end

  class Compiler
    attr_reader :spec, :digest, :route_data, :factorycare_ids

    def initialize(spec)
      @spec = spec
      @digest = spec.spec_digest
      @factorycare_ids = Set.new
    end

    def render_outputs
      compile_routes!
      outputs = {}
      outputs["curriculum/catalog.yml"] = yaml(render_catalog)
      validate_rendered_catalog_evidence!(outputs.fetch("curriculum/catalog.yml"))
      outputs["curriculum/routes/zero-base.yml"] = yaml(route_data.fetch("zero-base"))
      outputs["curriculum/routes/accelerated-48.yml"] = yaml(route_data.fetch("accelerated-48"))
      outputs["curriculum/routes/factorycare-project.yml"] = yaml(route_data.fetch("factorycare-project"))
      outputs["curriculum/routes/reference.yml"] = yaml(route_data.fetch("reference"))
      outputs["curriculum/gates.yml"] = yaml(render_gates)
      outputs["curriculum/concept-graph.md"] = render_concept_graph
      outputs["curriculum/README.md"] = render_curriculum_readme
      render_volume_readmes.each { |path, body| outputs[path] = body }
      render_placeholders.each { |path, body| outputs[path] = body }
      outputs
    end

    def human_required_chapters
      spec.chapters.reject { |chapter| chapter["status"] == "planned" }
    end

    def chapter_frontmatter_contract(chapter)
      tags = %w[zero-base accelerated-48 reference]
      tags << "factorycare-project" if factorycare_ids.include?(chapter["id"])
      {
        "schema_version" => 2,
        "edition" => spec.edition.fetch("edition"),
        "id" => chapter["id"],
        "title" => chapter["title"],
        "responsibility" => chapter["responsibility"],
        "volume" => chapter["volume"],
        "order" => chapter["order"],
        "level" => chapter["level"],
        "status" => chapter["status"],
        "path" => chapter["path"],
        "catalog" => "../../../curriculum/catalog.yml",
        "prerequisites" => deep_copy(chapter["prerequisites"]),
        "version_surfaces" => deep_copy(chapter["version_surfaces"]),
        "route_tags" => tags
      }
    end

    private

    def validate_rendered_catalog_evidence!(catalog_body)
      # The frozen source rebuild proves the one-time ready migration input.
      # Once that migration is recorded as applied, normal chapter authoring
      # must be free to change the catalog without rewriting historical proof.
      return unless spec.migration["status"] == "ready"

      actual = catalog_projection_digest(catalog_body)
      spec.migration.fetch("source_rebuilds", []).each do |rebuild|
        next unless rebuild.is_a?(Hash)
        next if rebuild["rendered_catalog_projection_digest"] == actual

        raise DiagnosticError.new(
          "E_MIGRATION_REBUILD",
          "rendered catalog bytes differ from frozen source-rebuild evidence",
          path: spec.edition.fetch("migration_ledger")
        )
      end
    end

    def catalog_projection_digest(catalog_body)
      document = StrictYaml.load(catalog_body.dup.force_encoding(Encoding::UTF_8), display_path: "rendered:curriculum/catalog.yml")
      projection = deep_copy(document)
      projection.delete("generated_spec_digest")
      "sha256:#{Digest::SHA256.hexdigest(JSON.generate(canonical_json_value(projection)))}"
    end

    def canonical_json_value(value)
      case value
      when Hash
        value.keys.sort.each_with_object({}) { |key, result| result[key] = canonical_json_value(value.fetch(key)) }
      when Array
        value.map { |item| canonical_json_value(item) }
      else
        value
      end
    end

    def compile_routes!
      zero = render_zero_base
      accelerated = render_accelerated
      factorycare = render_factorycare
      reference = render_reference
      @route_data = {
        "zero-base" => zero,
        "accelerated-48" => accelerated,
        "factorycare-project" => factorycare,
        "reference" => reference
      }
    end

    def generated_header
      {
        "schema_version" => 2,
        "generated" => true,
        "generated_by" => GENERATED_BY,
        "generated_spec_digest" => digest,
        "edition" => spec.edition.fetch("edition")
      }
    end

    def render_catalog
      chapters = spec.chapters.map do |chapter|
        result = deep_copy(chapter)
        result.delete("source_spec")
        result["route_tags"] = %w[zero-base accelerated-48 reference]
        result["route_tags"] << "factorycare-project" if factorycare_ids.include?(chapter["id"])
        result
      end
      generated_header.merge(
        "catalog_id" => spec.edition.fetch("catalog_id"),
        "canonical" => true,
        "status" => spec.edition.fetch("status"),
        "chapter_count_target" => spec.edition.fetch("chapter_count_target"),
        "dependency_semantics" => {
          "prerequisites" => "hard semantic prerequisite with an explicit rationale",
          "recommended_after" => "generated reading order only; never authorizes capability use",
          "capabilities" => "independent use requires the unique teacher in the hard prerequisite closure"
        },
        "chapters" => chapters
      )
    end

    def render_zero_base
      units = spec.edition.fetch("volume_ids").map do |volume_id|
        volume = spec.volume_by_id.fetch(volume_id)
        unit = {
          "id" => volume.fetch("zero_base_unit_id"),
          "title" => volume.fetch("title"),
          "chapter_ids" => spec.chapters.select { |chapter| chapter["volume"] == volume_id }.map { |chapter| chapter["id"] },
          "entry_check_path" => "assessments/zero-base/v#{volume_id}-entry.md",
          "exit_check_id" => "review-v#{volume_id}"
        }
        unit["stage_gate_id"] = volume["stage_gate_id"] if volume["stage_gate_id"]
        unit["final_gate_id"] = volume["final_gate_id"] if volume["final_gate_id"]
        unit
      end
      generated_header.merge(
        "route_id" => "zero-base",
        "route_kind" => "zero-base",
        "title" => "零基础完整路线",
        "coverage" => "complete",
        "navigation_semantics" => "ordered-learning",
        "waiver_policy" => "no-implicit-waiver",
        "units" => units
      )
    end

    def render_accelerated
      plan = spec.accelerated_plan
      modules = plan.fetch("modules")
      position = {}
      spec.chapters.each_with_index { |chapter, index| position[chapter["id"]] = index }
      previous_boundary = -1
      rendered = []
      modules.each_with_index do |mod, index|
        anchors = mod.fetch("anchor_chapter_ids")
        anchor_positions = anchors.map { |id| position.fetch(id) }
        if anchor_positions.any? { |anchor_position| anchor_position <= previous_boundary }
          raise DiagnosticError.new(
            "E_ACCELERATED_ANCHOR_ORDER",
            "#{mod['id']} contains an anchor already owned by an earlier module",
            path: "curriculum/route-plans/accelerated-48.yml"
          )
        end
        unless anchor_positions == anchor_positions.sort && anchor_positions.uniq.length == anchor_positions.length
          raise DiagnosticError.new(
            "E_ACCELERATED_ANCHOR_ORDER",
            "#{mod['id']} anchors must be unique and follow canonical chapter order",
            path: "curriculum/route-plans/accelerated-48.yml"
          )
        end
        boundary = index == modules.length - 1 ? spec.chapters.length - 1 : anchor_positions.max
        if boundary < previous_boundary
          raise DiagnosticError.new(
            "E_ACCELERATED_ANCHOR_ORDER",
            "#{mod['id']} anchor boundary #{boundary} precedes prior boundary #{previous_boundary}",
            path: "curriculum/route-plans/accelerated-48.yml"
          )
        end
        primary = spec.chapters[(previous_boundary + 1)..boundary].to_a.map { |chapter| chapter["id"] }
        required = mod.fetch("required_capabilities")
        teacher_ids = required.map { |id| spec.capability_by_id.fetch(id).fetch("teacher_chapter_id") }
        future_teachers = teacher_ids.select { |id| position.fetch(id) > boundary }
        unless future_teachers.empty?
          raise DiagnosticError.new(
            "E_ACCELERATED_CAPABILITY_ORDER",
            "#{mod['id']} requires capabilities whose teachers occur after its boundary: #{future_teachers.join(',')}",
            path: "curriculum/route-plans/accelerated-48.yml"
          )
        end
        closure = prerequisite_closure(primary + teacher_ids)
        support = (closure + teacher_ids).uniq.reject { |id| primary.include?(id) }.sort_by { |id| position.fetch(id) }
        chapter_ids = (support + primary).uniq.sort_by { |id| position.fetch(id) }
        roles = chapter_ids.each_with_object({}) do |id, result|
          if support.include?(id)
            result[id] = "support"
          else
            chapter = spec.chapter_by_id.fetch(id)
            taught = chapter.dig("capabilities", "teaches") || []
            result[id] = if !(taught & required).empty?
              "teach"
            elsif chapter["role"] == "practice"
              "practice"
            elsif %w[review synthesis project].include?(chapter["role"])
              "diagnose"
            else
              "refresh"
            end
          end
        end
        rendered << {
          "id" => mod.fetch("id"),
          "title" => mod.fetch("title"),
          "required_mastery" => mod.fetch("required_mastery"),
          "required_capabilities" => required,
          "anchor_chapter_ids" => anchors,
          "primary_chapter_ids" => primary,
          "supporting_chapter_ids" => support,
          "chapter_ids" => chapter_ids,
          "chapter_roles" => roles,
          "diagnostic" => plan.fetch("module_defaults").fetch("diagnostic_policy").merge(
            "assessment_id" => "diag-#{mod.fetch('id')}",
            "assessment_path" => "assessments/accelerated/#{mod.fetch('id')}/diagnostic.md"
          ),
          "waiver" => plan.fetch("module_defaults").fetch("waiver_policy"),
          "completion_evidence" => mod.fetch("evidence_requirements"),
          "retest" => plan.fetch("module_defaults").fetch("retest_policy").merge(
            "assessment_id" => "retest-#{mod.fetch('id')}",
            "evidence_path" => "evidence/accelerated/#{mod.fetch('id')}/retest/"
          )
        }
        previous_boundary = boundary
      end
      generated_header.merge(
        "route_id" => "accelerated-48",
        "route_kind" => "accelerated",
        "coverage" => "complete-with-support-repetition",
        "navigation_semantics" => "ordered-anchor-boundaries",
        "mastery_policy" => deep_copy(plan.fetch("mastery_policy")).merge(
          "depth_semantics" => {
            "chapter_level" => "encyclopedia-reference-depth",
            "required_mastery" => "route-minimum-exit-evidence"
          }
        ),
        "module_count" => plan.fetch("module_count"),
        "modules" => rendered
      )
    rescue KeyError => e
      raise DiagnosticError.new("E_ACCELERATED_ANCHOR", e.message, path: "curriculum/route-plans/accelerated-48.yml")
    end

    def render_factorycare
      plan = spec.factorycare_plan
      gate_registry = spec.factorycare_gate_registry
      gate_by_id = gate_registry.fetch("gates").each_with_object({}) do |gate, result|
        result[gate.fetch("id")] = gate
      end
      position = {}
      spec.chapters.each_with_index { |chapter, index| position[chapter["id"]] = index }
      primary_seen = Set.new
      stages = plan.fetch("stages").map.with_index do |stage, index|
        primary = stage.fetch("primary_anchor_chapter_ids")
        duplicate = primary.select { |id| primary_seen.include?(id) }
        unless duplicate.empty?
          raise DiagnosticError.new("E_FACTORYCARE_PRIMARY", "repeated primary ids #{duplicate.join(',')}", path: "curriculum/route-plans/factorycare-project.yml")
        end
        primary_seen.merge(primary)
        teacher_ids = stage.fetch("required_capabilities").map do |capability_id|
          spec.capability_by_id.fetch(capability_id).fetch("teacher_chapter_id")
        end
        closure = prerequisite_closure(primary + teacher_ids)
        support = (closure + teacher_ids).uniq.reject { |id| primary.include?(id) }.sort_by { |id| position.fetch(id) }
        all_ids = (support + primary).uniq.sort_by { |id| position.fetch(id) }
        factorycare_ids.merge(all_ids)
        root = format("%02d-%s", index + 1, stage.fetch("id").sub(/\Afc-\d{2}-/, ""))
        gate = gate_by_id.fetch(stage.fetch("gate_id"))
        evidence_paths = gate.fetch("required_evidence_kinds").map do |kind|
          case kind
          when "runnable-slice" then "evidence/factorycare/#{root}/run/"
          when "negative-path" then "evidence/factorycare/#{root}/negative/"
          when "decision-record" then "evidence/factorycare/#{root}/decision-record.md"
          when "teach-back" then "evidence/factorycare/#{root}/teach-back.md"
          else
            raise DiagnosticError.new("E_FACTORYCARE_EVIDENCE_KIND", "unknown evidence kind #{kind}", path: "curriculum/factorycare-stage-gates.yml")
          end
        end
        {
          "id" => stage.fetch("id"),
          "title" => stage.fetch("title"),
          "required_capabilities" => stage.fetch("required_capabilities"),
          "primary_chapter_ids" => primary,
          "supporting_chapter_ids" => support,
          "business_deliverables" => stage.fetch("business_deliverables"),
          "negative_scenarios" => gate.fetch("negative_scenarios"),
          "project_artifacts" => gate.fetch("artifact_paths").each_with_index.map do |path, artifact_index|
            {
              "id" => "#{stage.fetch('id')}-artifact-#{artifact_index + 1}",
              "path" => path,
              "acceptance" => "可从空环境复现 #{stage.fetch('business_deliverables').join('、')}，并保留成功与负向路径证据"
            }
          end,
          "evidence_paths" => evidence_paths,
          "stage_gate" => {
            "id" => gate.fetch("id"),
            "acceptance_catalog_path" => gate_registry.fetch("acceptance_catalog_path"),
            "primary_acceptance_ids" => gate.fetch("primary_acceptance_ids"),
            "secondary_acceptance_ids" => gate.fetch("secondary_acceptance_ids"),
            "required_evidence_kinds" => gate.fetch("required_evidence_kinds"),
            "negative_scenarios" => gate.fetch("negative_scenarios"),
            "artifact_paths" => gate.fetch("artifact_paths")
          }
        }
      end
      if factorycare_ids.length >= spec.chapters.length
        raise DiagnosticError.new("E_FACTORYCARE_SELECTIVE", "project route expanded to the complete catalog", path: "curriculum/route-plans/factorycare-project.yml")
      end
      generated_header.merge(
        "route_id" => "factorycare-project",
        "route_kind" => "project",
        "coverage" => "selective",
        "navigation_semantics" => "stage-gated-with-generated-support-closure",
        "artifact_policy" => deep_copy(plan.fetch("stage_defaults").fetch("artifact_policy")),
        "gate_registry_id" => gate_registry.fetch("registry_id"),
        "acceptance_catalog_path" => gate_registry.fetch("acceptance_catalog_path"),
        "stages" => stages
      )
    rescue KeyError => e
      raise DiagnosticError.new("E_FACTORYCARE_PLAN", e.message, path: "curriculum/route-plans/factorycare-project.yml")
    end

    def render_reference
      index = spec.chapters.each_with_object({}) do |chapter, result|
        result[chapter["id"]] = {
          "title" => chapter["title"],
          "path" => chapter["path"],
          "topics" => (chapter["topics_taught"] + chapter["topics_used"]).uniq,
          "capabilities" => (chapter.dig("capabilities", "teaches") + chapter.dig("capabilities", "uses")).uniq,
          "versions" => chapter["version_surfaces"]
        }
      end
      generated_header.merge(
        "route_id" => "reference",
        "route_kind" => "reference",
        "coverage" => "generated-complete",
        "navigation_semantics" => "non-linear-index",
        "facets" => %w[concept error command api version factorycare].map { |id| { "id" => id } },
        "chapter_index" => index
      )
    end

    def render_gates
      plan = spec.gates_plan
      gates = plan.fetch("gates").map do |gate|
        ids = if gate["coverage"] == "all-active-chapters"
          spec.chapters.map { |chapter| chapter["id"] }
        else
          teachers = gate.fetch("required_capabilities").map { |id| spec.capability_by_id.fetch(id).fetch("teacher_chapter_id") }
          (prerequisite_closure(teachers) + teachers).uniq.sort_by { |id| spec.chapters.index(spec.chapter_by_id.fetch(id)) }
        end
        focus = gate.fetch("artifact_focus")
        rubric = gate.fetch("rubric_focus")
        rubric_policy = plan.fetch("gate_defaults").fetch("rubric")
        {
          "id" => gate.fetch("id"),
          "title" => gate.fetch("title"),
          "kind" => "stage-gate",
          "level" => gate.fetch("level"),
          "prerequisite_gate_ids" => gate.fetch("prerequisite_gate_ids"),
          "assessment" => {
            "id" => "assessment-#{gate.fetch('id').downcase}",
            "path" => gate.fetch("assessment_anchor"),
            "mode" => plan.fetch("gate_defaults").fetch("assessment_mode")
          },
          "required_capability_ids" => gate.fetch("required_capabilities"),
          "required_chapter_ids" => ids,
          "required_artifacts" => focus.each_with_index.map do |name, index|
            {
              "id" => "#{gate.fetch('id').downcase}-artifact-#{index + 1}",
              "path" => "evidence/gates/#{gate.fetch('id').downcase}/artifact-#{index + 1}/",
              "acceptance" => "#{name}可从空环境复现，成功、边界与故障路径都有可信 oracle"
            }
          end,
          "mandatory_evidence_paths" => plan.fetch("gate_defaults").fetch("mandatory_evidence_kinds").map do |kind|
            "evidence/gates/#{gate.fetch('id').downcase}/#{kind}/"
          end,
          "critical_failures" => plan.fetch("gate_defaults").fetch("critical_failures"),
          "rubric" => {
            "thresholds" => {
              "min_total" => rubric_policy.fetch("min_total"),
              "min_critical_dimension" => rubric_policy.fetch("min_critical_dimension")
            },
            "dimensions" => rubric.each_with_index.map do |criterion, index|
              {
                "id" => "#{gate.fetch('id').downcase}-dimension-#{index + 1}",
                "weight" => rubric_policy.fetch("dimension_weights").fetch(index),
                "critical" => index < rubric_policy.fetch("critical_dimension_count"),
                "criterion" => criterion
              }
            end
          },
          "retest" => plan.fetch("gate_defaults").fetch("retest").merge(
            "remediation_path" => "evidence/gates/#{gate.fetch('id').downcase}/remediation.md",
            "evidence_path" => "evidence/gates/#{gate.fetch('id').downcase}/retest/"
          ),
          "evidence_store" => "evidence/gates/#{gate.fetch('id').downcase}/index.yml"
        }
      end
      generated_header.merge(
        "gates_id" => plan.fetch("gates_id"),
        "canonical_source" => plan.fetch("canonical_source"),
        "policy" => plan.fetch("policy"),
        "gates" => gates
      )
    end

    def render_concept_graph
      lines = [
        "<!-- #{GENERATED_MARKER} -->",
        "# FactoryCare 课程概念与依赖图",
        "",
        "- edition: `#{spec.edition.fetch('edition')}`",
        "- chapters: #{spec.chapters.length}",
        "- capabilities: #{spec.capabilities.fetch('capabilities').length}",
        "- spec digest: `#{digest}`",
        "",
        "## Capability teachers",
        "",
        "| Capability | Teacher | Requires |",
        "| --- | --- | --- |"
      ]
      spec.capabilities.fetch("capabilities").each do |capability|
        lines << "| `#{capability.fetch('id')}` | `#{capability.fetch('teacher_chapter_id')}` | #{capability.fetch('requires').map { |id| "`#{id}`" }.join(', ')} |"
      end
      lines.concat(["", "## Chapter hard prerequisites", ""])
      spec.edition.fetch("volume_ids").each do |volume_id|
        volume = spec.volume_by_id.fetch(volume_id)
        lines << "### #{volume_id} #{volume.fetch('title')}"
        lines << ""
        spec.chapters.select { |chapter| chapter["volume"] == volume_id }.each do |chapter|
          dependencies = chapter["prerequisites"].empty? ? "root" : chapter["prerequisites"].map { |id| "`#{id}`" }.join(", ")
          lines << "- `#{chapter['id']}` ← #{dependencies}"
        end
        lines << ""
      end
      lines.pop while lines.last == ""
      lines.join("\n") + "\n"
    end

    def render_curriculum_readme
      lines = [
        "<!-- #{GENERATED_MARKER} -->",
        "# FactoryCare 编程百科课程架构",
        "",
        "本目录由 canonical specs 确定性生成。当前 edition 为 `#{spec.edition.fetch('edition')}`，目标与实际均为 #{spec.chapters.length} 章。目录和 placeholder 不是学习完成证据。",
        "",
        "## 规范输入",
        "",
        "- [Edition policy](edition.yml)",
        "- [Volumes](volumes.yml)",
        "- [Capabilities](capabilities.yml)",
        "- [Topics](topics.yml)",
        "- [Chapter spec contract](chapters/README.md)",
        "- [Route plans](route-plans/README.md)",
        "- [Migration ledger](migrations/README.md)",
        "",
        "## 生成物",
        "",
        "- [课程目录](catalog.yml)",
        "- [概念与依赖图](concept-graph.md)",
        "- [阶段门 G0—G8](gates.yml)",
        "- [零基础路线](routes/zero-base.yml)",
        "- [48 模块加速路线](routes/accelerated-48.yml)",
        "- [FactoryCare 项目路线](routes/factorycare-project.yml)",
        "- [非线性参考索引](routes/reference.yml)",
        "",
        "## 命令",
        "",
        "```bash",
        "ruby scripts/generate-curriculum.rb --plan",
        "ruby scripts/generate-curriculum.rb --check",
        "ruby scripts/generate-curriculum.rb --write",
        "ruby curriculum/validate_catalog.rb",
        "```"
      ]
      lines.join("\n") + "\n"
    end

    def render_volume_readmes
      spec.edition.fetch("volume_ids").each_with_object({}) do |volume_id, outputs|
        volume = spec.volume_by_id.fetch(volume_id)
        directory = "book/volume-#{volume_id}-#{volume.fetch('slug')}"
        lines = [
          "<!-- #{GENERATED_MARKER} -->",
          "# 卷 #{volume_id}：#{volume.fetch('title')}",
          "",
          "> edition `#{spec.edition.fetch('edition')}`；本页是生成目录，不是正文完成或过关证据。",
          "",
          volume.fetch("description"),
          "",
          "## 章节",
          ""
        ]
        spec.chapters.select { |chapter| chapter["volume"] == volume_id }.each do |chapter|
          filename = File.basename(chapter["path"])
          lines << format("%d. [%s](chapters/%s) — `%s` · `%s`", chapter["order"], chapter["title"], filename, chapter["id"], chapter["status"])
        end
        outputs[File.join(directory, "README.md")] = lines.join("\n") + "\n"
      end
    end

    def render_placeholders
      spec.chapters.each_with_object({}) do |chapter, outputs|
        next unless chapter["status"] == "planned"

        metadata = chapter_frontmatter_contract(chapter).merge(
          "generated_by" => GENERATED_BY,
          "generated_spec_digest" => chapter["spec_digest"]
        )
        body = Psych.dump(metadata, nil, line_width: -1)
        body << "---\n"
        body << "<!-- #{PLACEHOLDER_MARKER} -->\n"
        body << "# #{chapter['title']}\n\n"
        body << "> 架构占位：本文件尚未包含教材正文，不能作为学习或考核完成证据。\n\n"
        body << "- 语义 ID：`#{chapter['id']}`\n"
        body << "- 唯一职责：#{chapter['responsibility']}\n"
        body << "- 规范输入摘要：`#{chapter['spec_digest']}`\n"
        outputs[chapter["path"]] = body
      end
    end

    def prerequisite_closure(ids)
      result = Set.new
      visit = nil
      visit = lambda do |id|
        chapter = spec.chapter_by_id.fetch(id)
        chapter.fetch("prerequisites").each do |dependency|
          next if result.include?(dependency)

          result.add(dependency)
          visit.call(dependency)
        end
      end
      ids.each { |id| visit.call(id) }
      result.to_a
    end

    def yaml(document)
      # Marshal preserves shared references, which makes Psych emit anchors
      # and aliases. Generated contracts must remain consumable by the same
      # aliases:false policy as canonical inputs, so rebuild every branch.
      Psych.dump(unshared_copy(document), nil, line_width: -1)
    end

    def unshared_copy(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, item), copy| copy[unshared_copy(key)] = unshared_copy(item) }
      when Array
        value.map { |item| unshared_copy(item) }
      when Set
        value.to_a.map { |item| unshared_copy(item) }
      else
        value.dup
      end
    rescue TypeError
      value
    end

    def deep_copy(value)
      Marshal.load(Marshal.dump(value))
    end
  end

  # Deterministic evidence primitives shared by the explicit migration
  # capture/finalize CLIs and receipt validation tests.
  module MigrationReceipt
    module_function

    def canonical_value(value)
      case value
      when Hash
        value.keys.sort.each_with_object({}) { |key, result| result[key] = canonical_value(value.fetch(key)) }
      when Array
        value.map { |item| canonical_value(item) }
      else
        value
      end
    end

    def digest(value)
      "sha256:#{Digest::SHA256.hexdigest(JSON.generate(canonical_value(value)))}"
    end

    def output_manifest(outputs)
      outputs.keys.sort.map do |path|
        { "path" => path, "sha256" => Digest::SHA256.hexdigest(outputs.fetch(path)) }
      end
    end

    def expected_ready_plan(spec, outputs)
      manifest_files = spec.legacy_manifest.fetch("files")
      actions = []
      spec.chapters.each do |chapter|
        path = chapter.fetch("path")
        actions << action("create", path, "missing", output_digest(outputs, path))
      end
      manifest_files.each do |file|
        path = file.fetch("path")
        before = "sha256:#{file.fetch('sha256')}"
        if file.fetch("kind") == "generated-output"
          actions << action("update", path, before, output_digest(outputs, path))
        else
          actions << action("delete", path, before, "deleted")
        end
      end
      plan(actions)
    end

    def from_changes(changes, outputs)
      actions = changes.map do |change|
        before = change.expected_kind == :missing ? "missing" : "sha256:#{change.expected_digest}"
        after = if change.action == :delete
          "deleted"
        elsif outputs.key?(change.path)
          output_digest(outputs, change.path)
        else
          before
        end
        action(change.action.to_s, change.path, before, after)
      end
      plan(actions)
    end

    def plan(actions)
      ordered = actions.sort_by { |entry| [entry.fetch("path"), entry.fetch("action")] }
      counts = %w[create update delete conflict unchanged].each_with_object({}) do |name, result|
        result[name] = ordered.count { |entry| entry.fetch("action") == name }
      end
      { "action_counts" => counts, "plan_digest" => digest(ordered), "actions" => ordered }
    end

    def build(spec:, plan:, outputs:, applied_at:, applied_by:, write_exit_code: 0, check_exit_code: 0)
      manifest = output_manifest(outputs)
      ready_digests = spec.migration.fetch("source_rebuilds").map { |rebuild| rebuild.fetch("rendered_catalog_projection_digest") }.uniq
      raise ArgumentError, "source rebuilds must agree on one ready catalog projection" unless ready_digests.length == 1

      {
        "schema_version" => 1,
        "receipt_id" => "#{spec.migration.fetch('migration_id')}.application",
        "migration_id" => spec.migration.fetch("migration_id"),
        "ready_catalog_projection_digest" => ready_digests.first,
        "legacy_manifest_digest" => spec.migration.fetch("legacy_manifest_digest"),
        "mapping_audit_digest" => spec.migration.fetch("mapping_audit_digest"),
        "plan" => plan,
        "write" => {
          "exit_code" => write_exit_code,
          "output_manifest_digest" => digest(manifest),
          "output_manifest" => manifest
        },
        "check" => { "exit_code" => check_exit_code, "unchanged_count" => manifest.length },
        "postconditions" => {
          "legacy_chapter_count" => 0,
          "semantic_chapter_count" => spec.migration.fetch("expected_active_id_count")
        },
        "applied_at" => applied_at,
        "applied_by" => applied_by
      }
    end

    def action(name, path, before, after)
      { "action" => name, "path" => path, "before" => before, "after" => after }
    end

    def output_digest(outputs, path)
      "sha256:#{Digest::SHA256.hexdigest(outputs.fetch(path))}"
    end
    private_class_method :action, :output_digest
  end

  Change = Struct.new(:action, :path, :reason, :expected_kind, :expected_digest) do
    def to_s
      suffix = reason ? " (#{reason})" : ""
      "#{action.to_s.upcase.ljust(9)} #{path}#{suffix}"
    end
  end

  class Generator
    attr_reader :root, :mode, :out, :err, :commit_hook

    def initialize(root:, mode:, out: $stdout, err: $stderr, commit_hook: nil)
      expanded = File.expand_path(root)
      @root = File.exist?(expanded) ? File.realpath(expanded) : expanded
      @mode = mode
      @out = out
      @err = err
      @commit_hook = commit_hook
    end

    def capture_plan_evidence
      spec = SpecSet.new(root).load!
      unless spec.migration["status"] == "ready"
        raise DiagnosticError.new("E_MIGRATION_RECEIPT", "plan evidence can only be captured from a ready migration", path: spec.edition.fetch("migration_ledger"))
      end
      compiler = Compiler.new(spec)
      outputs = compiler.render_outputs
      actual_plan = nil
      with_staging(outputs) do |stage|
        changes = plan_changes(stage, outputs, compiler)
        conflicts = changes.select { |change| change.action == :conflict }
        unless conflicts.empty?
          raise DiagnosticError.new("E_MIGRATION_RECEIPT", "ready plan contains #{conflicts.length} conflict(s)", path: spec.edition.fetch("migration_ledger"))
        end
        actual_plan = MigrationReceipt.from_changes(changes, outputs)
      end
      expected_plan = MigrationReceipt.expected_ready_plan(spec, outputs)
      unless actual_plan == expected_plan
        raise DiagnosticError.new("E_MIGRATION_RECEIPT", "captured plan differs from the frozen initial migration plan", path: spec.edition.fetch("migration_ledger"))
      end
      ready_digests = spec.migration.fetch("source_rebuilds").map { |rebuild| rebuild.fetch("rendered_catalog_projection_digest") }.uniq
      {
        "schema_version" => 1,
        "migration_id" => spec.migration.fetch("migration_id"),
        "ready_catalog_projection_digest" => ready_digests.fetch(0),
        "plan" => actual_plan
      }
    end

    def run
      spec = SpecSet.new(root).load!
      compiler = Compiler.new(spec)
      outputs = compiler.render_outputs
      changes = nil
      with_staging(outputs) do |stage|
        changes = plan_changes(stage, outputs, compiler)
        print_summary(spec, changes)
        case mode
        when :plan
          return changes.any? { |change| change.action == :conflict } ? 1 : 0
        when :check
          drift = changes.any? { |change| change.action != :unchanged }
          if drift
            err.puts "[E_GENERATED_DRIFT] generated outputs differ from canonical specs"
            return 1
          end
          out.puts "CURRICULUM CHECK OK"
          return 0
        when :write
          readiness = write_readiness_issues(spec)
          unless readiness.empty?
            readiness.each { |message| err.puts "[E_WRITE_NOT_READY] #{message}" }
            return 1
          end
          conflicts = changes.select { |change| change.action == :conflict }
          unless conflicts.empty?
            conflicts.each { |change| err.puts "[E_PLACEHOLDER_CONFLICT] #{change.path}: #{change.reason}" }
            return 1
          end
          commit!(stage, changes, spec)
          out.puts "CURRICULUM WRITE OK"
          return 0
        else
          raise ArgumentError, "unknown mode #{mode.inspect}"
        end
      end
    rescue ValidationFailure => e
      e.issues.each { |issue| err.puts issue }
      1
    rescue DiagnosticError => e
      err.puts e
      1
    rescue StandardError => e
      err.puts "[E_STAGING_ABORTED] #{e.class}: #{e.message}"
      1
    end

    private

    def with_staging(outputs)
      stage = Dir.mktmpdir("factorycare-curriculum-stage-")
      outputs.sort.each do |relative, content|
        path = safe_join(stage, relative, check_symlinks: false)
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, content)
        if File.extname(relative) == ".yml"
          StrictYaml.load(content, display_path: "staging:#{relative}")
        end
      end
      yield stage
    ensure
      FileUtils.rm_rf(stage) if stage && File.exist?(stage)
    end

    def plan_changes(stage, outputs, compiler)
      changes = []
      outputs.keys.sort.each do |relative|
        target = safe_join(root, relative)
        expected = File.binread(safe_join(stage, relative, check_symlinks: false))
        stat = safe_target_stat(target, relative)
        unless stat
          changes << Change.new(:create, relative, nil, :missing, nil)
          next
        end
        actual = File.binread(target)
        digest = Digest::SHA256.hexdigest(actual)
        if actual == expected
          changes << Change.new(:unchanged, relative, nil, :file, digest)
        elsif placeholder_path?(relative) && !safe_owned_placeholder?(actual, relative)
          changes << Change.new(:conflict, relative, "existing file is not an owned planned placeholder", :file, digest)
        elsif !placeholder_path?(relative) && !safe_owned_generated_output?(actual, relative) && !adoptable_legacy_file?(compiler.spec, relative, actual, "generated-output")
          reason = if frozen_legacy_match?(compiler.spec, relative, actual, "generated-output")
            "generated-output target matches the frozen manifest but awaits a reviewed migration ledger"
          else
            "existing generated-output target has no valid ownership marker"
          end
          changes << Change.new(:conflict, relative, reason, :file, digest)
        else
          changes << Change.new(:update, relative, nil, :file, digest)
        end
      end

      compiler.human_required_chapters.sort_by { |chapter| chapter["path"] }.each do |chapter|
        relative = chapter["path"]
        target = safe_join(root, relative)
        stat = safe_target_stat(target, relative)
        if !stat
          changes << Change.new(:conflict, relative, "non-planned chapter body is missing", :missing, nil)
        else
          body = File.binread(target)
          digest = Digest::SHA256.hexdigest(body)
          reason = human_chapter_conflict(body, compiler.chapter_frontmatter_contract(chapter))
          changes << Change.new(:conflict, relative, reason, :file, digest) if reason
        end
      end

      expected_placeholders = outputs.keys.select { |path| placeholder_path?(path) }.to_set
      generated_placeholder_paths.each do |relative|
        next if expected_placeholders.include?(relative)

        body = File.binread(safe_join(root, relative))
        digest = Digest::SHA256.hexdigest(body)
        if safe_owned_placeholder?(body, relative)
          changes << Change.new(:delete, relative, "orphan generated planned placeholder", :file, digest)
        else
          changes << Change.new(:conflict, relative, "orphan placeholder ownership cannot be verified", :file, digest)
        end
      end
      legacy_chapter_paths.each do |relative|
        target = safe_join(root, relative)
        body = File.binread(target)
        digest = Digest::SHA256.hexdigest(body)
        if adoptable_legacy_file?(compiler.spec, relative, body, "legacy-chapter")
          changes << Change.new(:delete, relative, "retire frozen legacy chapter through reviewed migration", :file, digest)
        elsif frozen_legacy_match?(compiler.spec, relative, body, "legacy-chapter")
          changes << Change.new(:conflict, relative, "legacy chapter matches the frozen manifest but awaits a reviewed migration ledger", :file, digest)
        else
          changes << Change.new(:conflict, relative, "legacy chapter differs from the frozen migration manifest", :file, digest)
        end
      end
      changes.sort_by { |change| [change.path, change.action.to_s] }
    end

    def print_summary(spec, changes)
      out.puts "CURRICULUM #{mode.to_s.upcase}"
      out.puts "edition=#{spec.edition.fetch('edition')} chapters=#{spec.chapters.length} volumes=#{spec.volume_by_id.length} capabilities=#{spec.capability_by_id.length} modules=#{spec.accelerated_plan.fetch('modules').length} factorycare_stages=#{spec.factorycare_plan.fetch('stages').length}"
      spec.collector.warnings.each { |warning| out.puts warning }
      changes.each { |change| out.puts change }
    end

    def commit!(stage, changes, spec = nil)
      actionable = changes.select { |change| %i[create update delete].include?(change.action) }
      lock_path = File.join(Dir.tmpdir, "factorycare-curriculum-#{Digest::SHA256.hexdigest(root)}.lock")
      File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        revalidate_target_snapshots!(changes.reject { |change| change.action == :conflict }, spec)
        revalidate_input_snapshot!(spec) if spec
        snapshots = {}
        actionable.each do |change|
          target = safe_join(root, change.path)
          snapshots[change.path] = if File.file?(target)
            { body: File.binread(target), mode: File.stat(target).mode & 0o777 }
          end
        end
        applied = []
        begin
          actionable.each_with_index do |change, index|
            target = safe_join(root, change.path)
            case change.action
            when :create, :update
              atomic_write(target, File.binread(safe_join(stage, change.path, check_symlinks: false)))
            when :delete
              File.delete(target) if File.exist?(target)
              fsync_directory(File.dirname(target))
            end
            applied << change.path
            commit_hook.call(index + 1, change) if commit_hook
          end
        rescue StandardError
          applied.reverse_each do |relative|
            target = safe_join(root, relative)
            snapshot = snapshots[relative]
            if snapshot.nil?
              File.delete(target) if File.exist?(target)
              fsync_directory(File.dirname(target))
            else
              atomic_write(target, snapshot.fetch(:body), mode: snapshot.fetch(:mode))
            end
          end
          raise
        end
      end
    end

    def atomic_write(path, content, mode: nil)
      FileUtils.mkdir_p(File.dirname(path))
      target_mode = mode || (File.file?(path) ? (File.stat(path).mode & 0o777) : 0o644)
      temp = Tempfile.new([".curriculum-write-", ".tmp"], File.dirname(path))
      begin
        temp.binmode
        temp.chmod(target_mode)
        temp.write(content)
        temp.flush
        temp.fsync
        temp.close
        File.rename(temp.path, path)
        fsync_directory(File.dirname(path))
      ensure
        temp.close! if temp
      end
    end

    def placeholder_path?(relative)
      relative.match?(%r{\Abook/volume-[^/]+/chapters/ch\.[^/]+\.md\z})
    end

    def safe_owned_generated_output?(body, relative)
      if File.extname(relative) == ".yml"
        metadata = StrictYaml.load(body.dup.force_encoding(Encoding::UTF_8), display_path: relative)
        required_keys = GENERATED_YAML_KEYS[relative]
        metadata.is_a?(Hash) && required_keys && metadata.keys.sort == required_keys.sort &&
          metadata["schema_version"] == 2 && metadata["generated"] == true &&
          metadata["generated_by"] == GENERATED_BY &&
          metadata["edition"].is_a?(String) && !metadata["edition"].strip.empty? &&
          metadata["generated_spec_digest"].to_s.match?(/\A[0-9a-f]{64}\z/)
      else
        body.start_with?("<!-- #{GENERATED_MARKER} -->\n")
      end
    rescue DiagnosticError
      false
    end

    def safe_owned_placeholder?(body, relative)
      return false unless body.include?(PLACEHOLDER_MARKER)
      metadata = placeholder_metadata(body, relative)
      return false unless metadata.is_a?(Hash)
      return false unless metadata["generated_by"] == GENERATED_BY
      return false unless metadata["status"] == "planned"
      return false unless metadata["path"] == relative
      required_keys = %w[
        schema_version edition id title responsibility volume order level status path catalog
        prerequisites version_surfaces route_tags generated_by generated_spec_digest
      ]
      return false unless metadata.keys.sort == required_keys.sort
      return false unless metadata["schema_version"] == 2
      return false unless metadata["catalog"] == "../../../curriculum/catalog.yml"
      return false unless metadata["generated_spec_digest"].to_s.match?(/\A[0-9a-f]{64}\z/)

      metadata["id"] == File.basename(relative, ".md") && generated_placeholder_body_shape?(body, metadata)
    end

    def placeholder_metadata(body, relative)
      frontmatter_metadata(body, relative)
    end

    def generated_placeholder_body_shape?(body, metadata)
      closing = body.index("\n---\n", 4)
      return false unless closing

      content = body[(closing + 5)..-1]
      expected_prefix = "<!-- #{PLACEHOLDER_MARKER} -->\n" \
        "# #{metadata.fetch('title')}\n\n" \
        "> 架构占位：本文件尚未包含教材正文，不能作为学习或考核完成证据。\n\n" \
        "- 语义 ID：`#{metadata.fetch('id')}`\n"
      expected_suffix = "- 规范输入摘要：`#{metadata.fetch('generated_spec_digest')}`\n"
      return false unless content.start_with?(expected_prefix) && content.end_with?(expected_suffix)

      middle = content[expected_prefix.length...(content.length - expected_suffix.length)]
      middle == "- 唯一职责：#{metadata.fetch('responsibility')}\n"
    end

    def generated_placeholder_paths
      pattern = File.join(root, "book", "volume-*", "chapters", "ch.*.md")
      Dir.glob(pattern).sort.select do |path|
        stat = File.lstat(path)
        if stat.symlink?
          raise DiagnosticError.new("E_OUTPUT_SYMLINK", "orphan chapter path is a symbolic link", path: path.delete_prefix(root + File::SEPARATOR))
        end
        stat.file? && File.read(path, encoding: "UTF-8").include?(PLACEHOLDER_MARKER)
      rescue Errno::ENOENT
        false
      end.map { |path| path.delete_prefix(root + File::SEPARATOR) }
    end

    def legacy_chapter_paths
      Dir.glob(File.join(root, "book", "volume-*", "chapters", "v*.md")).sort.select do |path|
        stat = File.lstat(path)
        if stat.symlink?
          raise DiagnosticError.new("E_OUTPUT_SYMLINK", "legacy chapter path is a symbolic link", path: path.delete_prefix(root + File::SEPARATOR))
        end
        stat.file?
      rescue Errno::ENOENT
        false
      end.map do |path|
        path.delete_prefix(root + File::SEPARATOR)
      end
    end

    def write_readiness_issues(spec)
      issues = []
      unless %w[ready applied].include?(spec.migration["status"])
        issues << "migration ledger must be ready or applied"
      end
      active_registry = spec.id_registry.fetch("entries", []).select { |entry| entry["status"] == "active" }.map { |entry| entry["id"] }.to_set
      expected_ids = spec.chapters.map { |chapter| chapter["id"] }.to_set
      issues << "chapter ID registry must be frozen to the exact active chapter set" unless active_registry == expected_ids
      issues
    end

    def adoptable_legacy_file?(spec, relative, body, kind)
      return false unless %w[ready applied].include?(spec.migration["status"])

      frozen_legacy_match?(spec, relative, body, kind)
    end

    def frozen_legacy_match?(spec, relative, body, kind)
      entry = spec.legacy_manifest.fetch("files", []).find { |file| file["path"] == relative }
      entry && entry["kind"] == kind && entry["sha256"] == Digest::SHA256.hexdigest(body)
    end

    def human_chapter_conflict(body, expected)
      return "non-planned chapter still contains a generated marker" if body.include?(PLACEHOLDER_MARKER) || body.include?(GENERATED_MARKER)

      metadata = frontmatter_metadata(body, expected["path"])
      return "non-planned chapter requires valid YAML front matter" unless metadata.is_a?(Hash)

      mismatches = expected.reject { |key, value| metadata[key] == value }.keys
      return "front matter differs from canonical fields #{mismatches.join(',')}" unless mismatches.empty?

      nil
    end

    def revalidate_target_snapshots!(changes, spec = nil)
      changes.each do |change|
        target = safe_join(root, change.path)
        stat = safe_target_stat(target, change.path)
        current_kind = stat ? :file : :missing
        current_digest = stat ? Digest::SHA256.hexdigest(File.binread(target)) : nil
        unless current_kind == change.expected_kind && current_digest == change.expected_digest
          raise DiagnosticError.new("E_CONCURRENT_TARGET", "target changed after planning", path: change.path)
        end
        if change.action == :update
          body = File.binread(target)
          owned = if placeholder_path?(change.path)
            safe_owned_placeholder?(body, change.path)
          else
            safe_owned_generated_output?(body, change.path) || (spec && adoptable_legacy_file?(spec, change.path, body, "generated-output"))
          end
          raise DiagnosticError.new("E_OUTPUT_OWNERSHIP", "target ownership changed after planning", path: change.path) unless owned
        end
      end
    end

    def revalidate_input_snapshot!(spec)
      spec.input_contents.each do |relative, expected|
        path = safe_join(root, relative)
        safe_target_stat(path, relative)
        actual = File.binread(path)
        unless Digest::SHA256.hexdigest(actual) == Digest::SHA256.hexdigest(expected)
          raise DiagnosticError.new("E_CONCURRENT_INPUT", "canonical input changed after compilation", path: relative)
        end
      end
    end

    def safe_join(base, relative, check_symlinks: true)
      value = relative.to_s
      clean = Pathname.new(value).cleanpath.to_s
      if value.empty? || Pathname.new(value).absolute? || clean != value || clean.start_with?("../") || value.include?("\\")
        raise DiagnosticError.new("E_OUTPUT_PATH", "output path must be normalized and relative", path: value)
      end
      expanded_base = File.expand_path(base)
      target = File.expand_path(value, expanded_base)
      unless target.start_with?(expanded_base + File::SEPARATOR)
        raise DiagnosticError.new("E_OUTPUT_PATH", "output path escapes its staging root", path: value)
      end
      reject_symlink_ancestors!(expanded_base, target, value) if check_symlinks
      target
    end

    def reject_symlink_ancestors!(base, target, relative)
      current = File.dirname(target)
      while current.start_with?(base + File::SEPARATOR)
        if File.symlink?(current)
          raise DiagnosticError.new("E_OUTPUT_SYMLINK", "output parent is a symbolic link", path: relative)
        end
        current = File.dirname(current)
      end
    end

    def safe_target_stat(target, relative)
      return nil unless File.exist?(target) || File.symlink?(target)

      stat = File.lstat(target)
      unless stat.file? && !stat.symlink?
        raise DiagnosticError.new("E_OUTPUT_TYPE", "output target must be a regular file", path: relative)
      end
      stat
    end

    def fsync_directory(directory)
      File.open(directory, File::RDONLY) { |handle| handle.fsync }
    rescue SystemCallError, IOError
      # Some filesystems do not expose directory fsync. Atomic rename remains
      # valid, but crash durability is then delegated to the filesystem.
      nil
    end

    def frontmatter_metadata(body, relative)
      return nil unless body.start_with?("---\n")

      closing = body.index("\n---\n", 4)
      return nil unless closing

      StrictYaml.load(body[0...closing] + "\n", display_path: relative)
    rescue DiagnosticError
      nil
    end
  end
end
