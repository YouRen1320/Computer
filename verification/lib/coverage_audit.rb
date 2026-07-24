# frozen_string_literal: true

require "digest"

require_relative "contract"

module Verification
  # Bootstrap candidates are inventory observations, not executable manifests.
  # They deliberately leave transitive inputs, exact tool versions, output
  # closure, and semantic observations unresolved for chapter-by-chapter review.
  class CoverageAudit
    CATALOG_PATH = "curriculum/catalog.yml"
    ROLES = {
      "example" => "examples",
      "exercise" => "exercises",
      "lab" => "labs"
    }.freeze
    TOOL_HINT_PATTERNS = {
      "curl" => /(?<![a-zA-Z0-9_-])curl(?![a-zA-Z0-9_-])/,
      "dart" => /(?<![a-zA-Z0-9_-])dart(?![a-zA-Z0-9_-])/,
      "docker" => /(?<![a-zA-Z0-9_-])docker(?![a-zA-Z0-9_-])/,
      "flutter" => /(?<![a-zA-Z0-9_-])flutter(?![a-zA-Z0-9_-])/,
      "java" => /(?<![a-zA-Z0-9_-])java(?![a-zA-Z0-9_-])/,
      "javac" => /(?<![a-zA-Z0-9_-])javac(?![a-zA-Z0-9_-])/,
      "javap" => /(?<![a-zA-Z0-9_-])javap(?![a-zA-Z0-9_-])/,
      "maven" => /(?<![a-zA-Z0-9_-])mvn(?![a-zA-Z0-9_-])/,
      "node" => /(?<![a-zA-Z0-9_-])node(?![a-zA-Z0-9_-])/,
      "pnpm" => /(?<![a-zA-Z0-9_-])pnpm(?![a-zA-Z0-9_-])/,
      "python" => /(?<![a-zA-Z0-9_-])python(?:3)?(?![a-zA-Z0-9_-])/,
      "ruby" => /(?<![a-zA-Z0-9_-])ruby(?![a-zA-Z0-9_-])/,
      "uv" => /(?<![a-zA-Z0-9_-])uv(?![a-zA-Z0-9_-])/
    }.freeze
    REVIEW_REQUIRED = [
      "expand-and-lock-all-transitive-public-inputs",
      "confirm-complete-tool-set-and-exact-versions",
      "run-in-clean-copy-and-confirm-exact-exit-code",
      "define-semantic-stdout-stderr-observations",
      "observe-and-lock-complete-filesystem-output-delta",
      "perform-human-contract-review-before-promotion"
    ].freeze

    attr_reader :root, :loader, :guard

    def initialize(root, loader: nil)
      @root = File.realpath(root)
      @loader = loader || ManifestLoader.new(@root)
      @guard = @loader.guard
    end

    def report
      catalog_bytes, chapter_ids = load_catalog
      manifests = loader.discover
      final_ids = manifests.map { |manifest| manifest.data.fetch("chapter_id") }.sort
      unknown = final_ids - chapter_ids
      unless unknown.empty?
        raise ContractError.new("coverage", "E_MANIFEST_UNKNOWN_CHAPTER", "manifest references a chapter outside the catalog", path: unknown.first)
      end
      missing = chapter_ids - final_ids
      candidates = missing.map { |chapter_id| candidate_for(chapter_id) }
      tool_counts = Hash.new(0)
      candidates.each do |candidate|
        candidate.fetch("endpoints").each do |endpoint|
          endpoint.fetch("tool_hints").each { |tool| tool_counts[tool] += 1 }
        end
      end
      {
        "schema_version" => 1,
        "audit_id" => "p9-d5-verification-coverage",
        "generated_by" => "scripts/generate-verification-manifests.rb --coverage",
        "catalog_path" => CATALOG_PATH,
        "catalog_sha256" => Canonical.sha256(catalog_bytes),
        "chapter_total" => chapter_ids.length,
        "final_manifest_count" => final_ids.length,
        "final_manifest_ids" => final_ids,
        "missing_final_manifest_count" => missing.length,
        "missing_final_manifest_ids" => missing,
        "bootstrap_candidate_count" => candidates.length,
        "bootstrap_candidate_endpoint_count" => candidates.sum { |candidate| candidate.fetch("endpoints").length },
        "bootstrap_candidate_ids" => candidates.map { |candidate| candidate.fetch("chapter_id") },
        "candidate_tool_hint_endpoint_counts" => tool_counts.keys.sort.each_with_object({}) { |key, memo| memo[key] = tool_counts.fetch(key) },
        "missing_without_candidate_count" => 0,
        "missing_without_candidate_ids" => [],
        "contract_complete" => missing.empty?,
        "candidate_status" => "bootstrap-observed-unreviewed",
        "boundary" => "candidate inventory is not an executable contract or review evidence"
      }
    end

    def candidates
      _catalog_bytes, chapter_ids = load_catalog
      final_ids = loader.discover.map { |manifest| manifest.data.fetch("chapter_id") }
      (chapter_ids - final_ids).map { |chapter_id| candidate_for(chapter_id) }
    end

    def candidate_catalog
      records = candidates
      {
        "schema_version" => 1,
        "candidate_catalog_id" => "p9-d5-bootstrap-candidates",
        "generated_by" => "scripts/generate-verification-manifests.rb --bootstrap-candidates",
        "status" => "bootstrap-observed-unreviewed",
        "candidate_count" => records.length,
        "warning" => "Do not copy candidates into verification/manifests until every review_required item is closed.",
        "candidates" => records
      }
    end

    def require_complete!
      result = report
      return result if result.fetch("contract_complete")

      raise ContractError.new(
        "coverage", "E_MANIFEST_COVERAGE",
        "#{result.fetch('missing_final_manifest_count')} of #{result.fetch('chapter_total')} chapters lack final manifests; run coverage JSON for exact ids"
      )
    end

    private

    def load_catalog
      bytes, = guard.read_contract(CATALOG_PATH)
      data = StrictYaml.safe_load(bytes.force_encoding(Encoding::UTF_8), label: CATALOG_PATH)
      unless data.is_a?(Hash) && data.fetch("chapters", nil).is_a?(Array)
        raise ContractError.new("coverage", "E_CATALOG_SHAPE", "catalog must contain a chapters array", path: CATALOG_PATH)
      end
      ids = data.fetch("chapters").map { |chapter| chapter.fetch("id") }
      unless ids.length == data.fetch("chapter_count_target") && ids.uniq.length == ids.length && ids.all? { |id| CHAPTER_ID.match?(id) }
        raise ContractError.new("coverage", "E_CATALOG_IDS", "catalog chapter ids are incomplete, duplicated, or invalid", path: CATALOG_PATH)
      end
      [bytes, ids.sort]
    rescue KeyError, Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError => e
      raise ContractError.new("coverage", "E_CATALOG_PARSE", e.message.lines.first.to_s.strip, path: CATALOG_PATH)
    end

    def candidate_for(chapter_id)
      endpoints = ROLES.keys.sort.map do |role|
        asset = ROLES.fetch(role)
        root_relative = "#{asset}/encyclopedia/#{chapter_id}"
        root_absolute = File.join(root, root_relative)
        validate_asset_tree!(root_relative, root_absolute)
        matches = Dir.glob(File.join(root_absolute, "**", "verify.sh")).sort
        unless matches.length == 1
          raise ContractError.new(
            "coverage", "E_VERIFY_ENTRY_COUNT",
            "public asset root must contain exactly one verify.sh, found #{matches.length}", path: root_relative
          )
        end
        relative = matches.first.delete_prefix(root + File::SEPARATOR)
        guard.validate_public_path!(relative)
        bytes, stat = guard.read_contract(relative)
        unless stat.executable?
          raise ContractError.new("coverage", "E_VERIFY_NOT_EXECUTABLE", "verify.sh must be executable", path: relative)
        end
        {
          "role" => role,
          "verify_path" => relative,
          "verify_sha256" => Canonical.sha256(bytes),
          "verify_mode" => format("%04o", stat.mode & 0o777),
          "shebang" => bytes.lines.first.to_s.strip,
          "suggested_expected_exit_code_unreviewed" => role == "exercise" ? 41 : 0,
          "tool_hints" => tool_hints(bytes)
        }
      end
      {
        "chapter_id" => chapter_id,
        "status" => "bootstrap-observed-unreviewed",
        "endpoints" => endpoints,
        "review_required" => REVIEW_REQUIRED
      }
    end

    def validate_asset_tree!(relative, absolute)
      stat = File.lstat(absolute)
      raise ContractError.new("coverage", "E_ASSET_SYMLINK", "public asset root cannot be a symbolic link", path: relative) if stat.symlink?
      raise ContractError.new("coverage", "E_ASSET_NOT_DIRECTORY", "public asset root must be a directory", path: relative) unless stat.directory?

      Dir.glob(File.join(absolute, "**", "*"), File::FNM_DOTMATCH).each do |entry|
        next if entry.split(File::SEPARATOR).last == "." || entry.split(File::SEPARATOR).last == ".."
        next unless File.lstat(entry).symlink?

        path = entry.delete_prefix(root + File::SEPARATOR)
        raise ContractError.new("coverage", "E_ASSET_SYMLINK", "symbolic links are forbidden in public asset roots", path: path)
      end
    rescue Errno::ENOENT
      raise ContractError.new("coverage", "E_ASSET_MISSING", "public asset root is missing", path: relative)
    end

    def tool_hints(bytes)
      text = bytes.force_encoding(Encoding::UTF_8)
      hints = TOOL_HINT_PATTERNS.each_with_object(["bash"]) do |(tool, pattern), memo|
        memo << tool if text.match?(pattern)
      end
      hints.uniq.sort
    end
  end
end
