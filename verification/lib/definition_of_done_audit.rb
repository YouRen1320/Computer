# frozen_string_literal: true

require "digest"

require_relative "coverage_audit"
require_relative "machine_report_schema"

module Verification
  # Produces a deterministic inventory of chapter completion inputs. Structural
  # presence is deliberately separate from human review and semantic approval.
  class DefinitionOfDoneAudit
    CATALOG_PATH = "curriculum/catalog.yml"
    SCHEMA_PATH = "schemas/encyclopedia-definition-of-done.schema.json"
    CHECKS = [
      ["canonical-catalog-entry", "structural", "Canonical catalog entry exists."],
      ["chapter-source", "structural", "Generated or authored chapter source exists."],
      ["three-learning-outcomes", "structural", "Catalog declares explain, build and diagnose outcomes."],
      ["public-example-endpoint", "structural", "Public example has one executable verification entry."],
      ["public-exercise-endpoint", "structural", "Public exercise has one executable verification entry."],
      ["public-lab-endpoint", "structural", "Public lab has one executable verification entry."],
      ["private-solution-endpoint", "structural", "Private solution has one executable verification entry."],
      ["final-verification-manifest", "structural", "Reviewed final verification manifest is present and valid."],
      ["technical-review", "human-review", "Technical claims and failure explanations are independently reviewed."],
      ["pedagogical-review", "human-review", "A zero-foundation reader can follow the teaching sequence."],
      ["code-review", "human-review", "Examples, exercises and solutions are reviewed for intent and correctness."],
      ["security-review", "human-review", "Security boundaries and negative paths are independently reviewed."],
      ["accessibility-review", "human-review", "Keyboard, semantics and assistive-technology behavior are reviewed."],
      ["version-sources-review", "human-review", "Version claims are checked against supporting primary sources."],
      ["publication-navigation-review", "human-review", "Links, navigation and rendered output are reviewed."],
      ["final-semantic-approval", "human-review", "A human reviewer approves the chapter as a teaching artifact."]
    ].freeze
    STRUCTURAL_IDS = CHECKS.select { |_id, type, _description| type == "structural" }.map(&:first).freeze
    HUMAN_IDS = CHECKS.select { |_id, type, _description| type == "human-review" }.map(&:first).freeze
    ASSET_ROOTS = {
      "public-example-endpoint" => "examples",
      "public-exercise-endpoint" => "exercises",
      "public-lab-endpoint" => "labs",
      "private-solution-endpoint" => "solutions-private"
    }.freeze
    HUMAN_GATE_KEYS = {
      "technical-review" => "technical",
      "pedagogical-review" => "pedagogical",
      "code-review" => "code",
      "security-review" => "security",
      "accessibility-review" => "accessibility",
      "version-sources-review" => "version_sources",
      "publication-navigation-review" => "publication_navigation"
    }.freeze

    attr_reader :root, :guard

    def initialize(root)
      @root = File.realpath(root)
      @guard = PathGuard.new(@root)
      @source_entries = {}
    end

    def report
      catalog_bytes, chapters = load_catalog
      catalog_evidence = evidence_for(CATALOG_PATH, bytes: catalog_bytes)
      batches, batch_by_chapter = balanced_batches(chapters.map { |chapter| chapter.fetch("id") })
      chapter_records = chapters.map do |chapter|
        chapter_record(chapter, batch_by_chapter.fetch(chapter.fetch("id")))
      end
      states = Hash.new(0)
      chapter_records.each do |chapter|
        chapter.fetch("checks").each { |check| states[check.fetch("state")] += 1 }
      end
      structurally_ready = chapter_records.count { |chapter| chapter.fetch("structural_status") == "ready-for-human-review" }
      semantically_approved = chapter_records.count { |chapter| chapter.fetch("semantic_status") == "approved" }
      status = if semantically_approved == chapter_records.length
                 "semantically-approved"
               elsif structurally_ready == chapter_records.length
                 "structurally-ready-human-review-required"
               else
                 "incomplete"
               end
      document = {
        "schema_version" => 1,
        "audit_id" => "p9-encyclopedia-definition-of-done",
        "generated_by" => "scripts/audit-encyclopedia-definition-of-done.rb",
        "status" => status,
        "evidence_classification" => {
          "class" => "machine-structural-inventory",
          "promotion" => "forbidden-without-human-review",
          "boundary" => "Structural green proves only the listed files and contracts exist; it is not semantic, pedagogical, accessibility, learner or publication approval."
        },
        "catalog" => catalog_evidence,
        "chapter_total" => chapter_records.length,
        "review_batch_policy" => {
          "minimum_chapters" => 5,
          "maximum_chapters" => 8,
          "batch_count" => batches.length,
          "assignment" => "catalog-order-balanced-deterministic"
        },
        "review_batches" => batches,
        "check_catalog" => CHECKS.map { |id, type, description| { "id" => id, "class" => type, "description" => description } },
        "state_counts" => %w[present missing human-review-required not-applicable].to_h { |state| [state, states.fetch(state, 0)] },
        "structurally_ready_count" => structurally_ready,
        "semantic_approval_count" => semantically_approved,
        "chapters" => chapter_records,
        "source_set" => {
          "algorithm" => DIGEST_ALGORITHM,
          "source_count" => @source_entries.length,
          "sha256" => Canonical.path_bytes_digest(@source_entries.values)
        }
      }
      MachineReportSchema.validate!(root: root, schema_path: SCHEMA_PATH, document: document)
      validate_semantics!(document)
      document
    end

    private

    def load_catalog
      bytes, = guard.read_contract(CATALOG_PATH)
      data = StrictYaml.safe_load(bytes.force_encoding(Encoding::UTF_8), label: CATALOG_PATH)
      chapters = data.fetch("chapters")
      unless data.fetch("chapter_count_target") == 255 && chapters.length == 255
        raise ContractError.new("definition-of-done", "E_DOD_CHAPTER_COUNT", "catalog must contain exactly 255 chapters", path: CATALOG_PATH)
      end
      ids = chapters.map { |chapter| chapter.fetch("id") }
      unless ids.uniq.length == ids.length && ids.all? { |id| CHAPTER_ID.match?(id) }
        raise ContractError.new("definition-of-done", "E_DOD_CHAPTER_IDS", "catalog chapter ids are duplicated or invalid", path: CATALOG_PATH)
      end
      [bytes, chapters]
    rescue KeyError, Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError => e
      raise ContractError.new("definition-of-done", "E_DOD_CATALOG", e.message.lines.first.to_s.strip, path: CATALOG_PATH)
    end

    def balanced_batches(ids)
      batch_count = 42
      base = ids.length / batch_count
      extra = ids.length % batch_count
      cursor = 0
      batches = batch_count.times.map do |index|
        size = base + (index < extra ? 1 : 0)
        members = ids.slice(cursor, size)
        cursor += size
        { "id" => format("batch-%02d", index + 1), "chapter_ids" => members }
      end
      mapping = batches.each_with_object({}) do |batch, memo|
        batch.fetch("chapter_ids").each { |chapter_id| memo[chapter_id] = batch.fetch("id") }
      end
      [batches, mapping]
    end

    def chapter_record(chapter, batch_id)
      chapter_id = chapter.fetch("id")
      chapter_path = chapter.fetch("path")
      chapter_evidence = evidence_for(chapter_path)
      front_matter = parse_front_matter(chapter_path)
      checks = []
      checks << present_check("canonical-catalog-entry", [evidence_for(CATALOG_PATH)])
      checks << present_check("chapter-source", [chapter_evidence])
      outcomes = chapter.fetch("outcomes", [])
      if outcomes.map { |outcome| outcome["id"] } == %w[explain build diagnose]
        checks << present_check("three-learning-outcomes", [evidence_for(CATALOG_PATH)])
      else
        checks << missing_check("three-learning-outcomes", "Catalog does not declare the exact explain/build/diagnose outcome sequence.")
      end
      ASSET_ROOTS.each do |check_id, asset_root|
        checks << endpoint_check(check_id, asset_root, chapter_id)
      end
      checks << final_manifest_check(chapter_id)
      HUMAN_GATE_KEYS.each do |check_id, gate_key|
        checks << human_gate_check(check_id, gate_key, front_matter, chapter_evidence)
      end
      human_states = checks.select { |check| check.fetch("class") == "human-review" }.map { |check| check.fetch("state") }
      if human_states.all? { |state| state == "present" } && front_matter["status"] == "verified"
        checks << present_check("final-semantic-approval", [chapter_evidence], type: "human-review")
      else
        checks << human_required_check("final-semantic-approval", "Machine structure cannot approve a chapter as a teaching artifact.")
      end
      structural_ready = checks.select { |check| check.fetch("class") == "structural" }.all? { |check| check.fetch("state") == "present" }
      semantic_approved = checks.select { |check| check.fetch("class") == "human-review" }.all? { |check| check.fetch("state") == "present" }
      {
        "chapter_id" => chapter_id,
        "volume" => chapter.fetch("volume"),
        "order" => chapter.fetch("order"),
        "review_batch_id" => batch_id,
        "structural_status" => structural_ready ? "ready-for-human-review" : "incomplete",
        "semantic_status" => semantic_approved ? "approved" : "human-review-required",
        "checks" => checks
      }
    end

    def parse_front_matter(path)
      bytes, = guard.read_contract(path)
      text = bytes.force_encoding(Encoding::UTF_8)
      lines = text.lines
      unless lines.first&.strip == "---"
        raise ContractError.new("definition-of-done", "E_DOD_FRONT_MATTER", "chapter is missing YAML front matter", path: path)
      end
      closing = lines[1..].index { |line| line.strip == "---" }
      unless closing
        raise ContractError.new("definition-of-done", "E_DOD_FRONT_MATTER", "chapter front matter is not closed", path: path)
      end
      yaml = lines[1, closing].join
      data = StrictYaml.safe_load(yaml, label: path)
      unless data.is_a?(Hash)
        raise ContractError.new("definition-of-done", "E_DOD_FRONT_MATTER", "chapter front matter must be a mapping", path: path)
      end
      data
    rescue Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError => e
      raise ContractError.new("definition-of-done", "E_DOD_FRONT_MATTER", e.message.lines.first.to_s.strip, path: path)
    end

    def endpoint_check(check_id, asset_root, chapter_id)
      root_relative = "#{asset_root}/encyclopedia/#{chapter_id}"
      absolute = File.join(root, root_relative)
      unless File.directory?(absolute) && !File.symlink?(absolute)
        return missing_check(check_id, "Chapter-owned endpoint directory is missing or unsafe.")
      end
      matches = Dir.glob(File.join(absolute, "**", "verify.sh")).select { |path| File.file?(path) && !File.symlink?(path) }.sort
      unless matches.length == 1
        return missing_check(check_id, "Expected exactly one regular verify.sh, found #{matches.length}.")
      end
      relative = matches.first.delete_prefix(root + File::SEPARATOR)
      stat = File.stat(matches.first)
      unless stat.executable?
        return missing_check(check_id, "The unique verify.sh is not executable.", [evidence_for(relative)])
      end
      present_check(check_id, [evidence_for(relative)])
    end

    def final_manifest_check(chapter_id)
      relative = "#{MANIFEST_DIRECTORY}/#{chapter_id}.yml"
      absolute = File.join(root, relative)
      return missing_check("final-verification-manifest", "No reviewed final verification manifest exists.") unless File.file?(absolute) && !File.symlink?(absolute)

      evidence = evidence_for(relative)
      ManifestLoader.new(root).load(relative)
      present_check("final-verification-manifest", [evidence])
    rescue ContractError => e
      missing_check(
        "final-verification-manifest",
        "The final manifest exists but fails its executable contract (#{e.code}).",
        [evidence].compact
      )
    end

    def human_gate_check(check_id, gate_key, front_matter, chapter_evidence)
      gate = front_matter.fetch("verification", {}).fetch(gate_key, nil)
      if gate.is_a?(Hash) && gate["status"] == "passed"
        present_check(check_id, [chapter_evidence], type: "human-review")
      elsif gate.is_a?(Hash) && gate["status"] == "not-applicable"
        reason = gate["applicability_reason"].to_s.strip
        return not_applicable_check(check_id, reason, [chapter_evidence]) unless reason.empty?

        human_required_check(check_id, "A not-applicable decision has no concrete applicability reason.")
      else
        human_required_check(check_id, "No independently passed human review gate is recorded.")
      end
    end

    def present_check(id, evidence, type: check_type(id))
      { "id" => id, "class" => type, "state" => "present", "evidence" => evidence }
    end

    def missing_check(id, reason, evidence = [])
      { "id" => id, "class" => "structural", "state" => "missing", "evidence" => evidence, "reason" => reason }
    end

    def human_required_check(id, reason)
      { "id" => id, "class" => "human-review", "state" => "human-review-required", "evidence" => [], "reason" => reason }
    end

    def not_applicable_check(id, reason, evidence)
      { "id" => id, "class" => "human-review", "state" => "not-applicable", "evidence" => evidence, "reason" => reason }
    end

    def check_type(id)
      STRUCTURAL_IDS.include?(id) ? "structural" : "human-review"
    end

    def evidence_for(relative, bytes: nil)
      bytes ||= guard.read_contract(relative).first
      entry = {
        "path" => relative,
        "sha256" => Canonical.sha256(bytes),
        "size_bytes" => bytes.bytesize
      }
      @source_entries[relative] = { "path" => relative, "bytes" => bytes }
      entry
    end

    def validate_semantics!(document)
      chapters = document.fetch("chapters")
      check_ids = CHECKS.map(&:first)
      unless chapters.map { |chapter| chapter.fetch("chapter_id") }.uniq.length == chapters.length
        raise ContractError.new("definition-of-done", "E_DOD_DUPLICATE_CHAPTER", "chapter records must be unique")
      end
      chapters.each do |chapter|
        actual_ids = chapter.fetch("checks").map { |check| check.fetch("id") }
        unless actual_ids == check_ids
          raise ContractError.new("definition-of-done", "E_DOD_CHECK_SET", "chapter check set or order is incomplete", path: chapter.fetch("chapter_id"))
        end
      end
      assigned = document.fetch("review_batches").flat_map { |batch| batch.fetch("chapter_ids") }
      unless assigned == chapters.map { |chapter| chapter.fetch("chapter_id") }
        raise ContractError.new("definition-of-done", "E_DOD_BATCH_COVERAGE", "review batches must cover catalog order exactly once")
      end
      true
    end
  end
end
