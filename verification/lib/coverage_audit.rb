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
      "rg" => /(?<![a-zA-Z0-9_-])rg(?![a-zA-Z0-9_-])/,
      "ruby" => /(?<![a-zA-Z0-9_-])ruby(?![a-zA-Z0-9_-])/,
      "uv" => /(?<![a-zA-Z0-9_-])uv(?![a-zA-Z0-9_-])/
    }.freeze
    REVIEW_REQUIRED = [
      "review-static-input-closure-for-semantic-completeness",
      "review-observed-tool-set-and-version-probes",
      "review-two-fresh-copy-exact-exit-observation",
      "replace-digest-observations-with-semantic-literal-oracles",
      "review-observed-filesystem-output-closure",
      "perform-human-contract-review-before-promotion"
    ].freeze
    GENERATED_NAMES = %w[
      .dart_tool .verify.log .venv __pycache__ build build-evidence coverage dist node_modules target
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

    def candidate_catalog_v2(endpoint_report:, tool_probes:, source_endpoint_report_sha256:)
      unless source_endpoint_report_sha256.is_a?(String) && source_endpoint_report_sha256.match?(SHA256)
        raise ContractError.new("candidate-v2", "E_ENDPOINT_SOURCE_DIGEST", "source endpoint report digest must be SHA-256")
      end
      records = candidates
      observations = endpoint_report.fetch("results").each_with_object({}) do |record, memo|
        next unless ROLES.key?(record.fetch("role"))

        memo[[record.fetch("chapter_id"), record.fetch("role")]] = record
      end
      probes = tool_probes.each_with_object({}) { |probe, memo| memo[probe.fetch("id")] = probe }
      observed = records.map do |candidate|
        endpoints = candidate.fetch("endpoints").map do |endpoint|
          observation = observations.fetch([candidate.fetch("chapter_id"), endpoint.fetch("role")]) do
            raise ContractError.new("candidate-v2", "E_CANDIDATE_OBSERVATION_MISSING", "public endpoint observation is missing", path: candidate.fetch("chapter_id"))
          end
          first = observation.fetch("first_run") || unavailable_observation
          repeat = observation.fetch("repeat_run") || unavailable_observation
          endpoint_probes = endpoint.fetch("tool_hints").map do |tool_id|
            probes.fetch(tool_id) do
              raise ContractError.new("candidate-v2", "E_CANDIDATE_TOOL_PROBE_MISSING", "tool probe is missing", path: tool_id)
            end
          end
          endpoint.merge(
            "observation_status" => observation.fetch("status"),
            "observed_exact_exit_code" => first.fetch("exit_code"),
            "repeat_exact_exit_code" => repeat.fetch("exit_code"),
            "observed_run_count" => [first, repeat].count { |run| run.fetch("attempted", false) },
            "expected_red_marker_present" => observation.fetch("expected_red_marker_observed"),
            "stable_observations" => {
              "normalized_stdout_sha256" => first.fetch("normalized_stdout_sha256"),
              "normalized_stderr_sha256" => first.fetch("normalized_stderr_sha256"),
              "normalized_diagnostic_set_sha256" => first.fetch("normalized_diagnostic_set_sha256"),
              "repeat_normalized_diagnostic_set_sha256" => repeat.fetch("normalized_diagnostic_set_sha256")
            },
            "output_closure" => {
              "first_status" => first.fetch("output_closure_status"),
              "repeat_status" => repeat.fetch("output_closure_status"),
              "first_generated_output_count" => first.fetch("generated_output_count"),
              "repeat_generated_output_count" => repeat.fetch("generated_output_count"),
              "first_generated_output_set_sha256" => first.fetch("generated_output_set_sha256"),
              "repeat_generated_output_set_sha256" => repeat.fetch("generated_output_set_sha256"),
              "first_generated_output_sha256" => first.fetch("generated_output_sha256"),
              "repeat_generated_output_sha256" => repeat.fetch("generated_output_sha256")
            },
            "two_fresh_copy_runs_consistent" => comparable_observation(first) == comparable_observation(repeat),
            "tool_probes" => endpoint_probes
          )
        end
        candidate.merge(
          "status" => endpoints.all? { |endpoint| endpoint_mechanically_complete?(endpoint) } ?
            "observed-unreviewed-candidate-v2" : "observed-unreviewed-candidate-v2-with-mechanical-gaps",
          "endpoints" => endpoints
        )
      end
      gap_candidates = observed.reject { |candidate| candidate.fetch("status") == "observed-unreviewed-candidate-v2" }
      gap_endpoints = observed.flat_map do |candidate|
        candidate.fetch("endpoints").select do |endpoint|
          !endpoint_mechanically_complete?(endpoint)
        end.map { |endpoint| "#{candidate.fetch('chapter_id')}:#{endpoint.fetch('role')}" }
      end
      {
        "schema_version" => 2,
        "candidate_catalog_id" => "p9-d5-observed-unreviewed-candidates-v2",
        "generated_by" => "scripts/generate-verification-manifests.rb --bootstrap-candidates --endpoint-report",
        "status" => gap_candidates.empty? ?
          "observed-unreviewed-candidate-v2" : "observed-unreviewed-candidate-v2-with-mechanical-gaps",
        "evidence_class" => "machine-only-not-learner-evidence",
        "promotion_status" => "forbidden-without-human-review",
        "source_endpoint_report_sha256" => source_endpoint_report_sha256,
        "candidate_count" => observed.length,
        "endpoint_count" => observed.sum { |candidate| candidate.fetch("endpoints").length },
        "mechanical_gap_candidate_count" => gap_candidates.length,
        "mechanical_gap_candidate_ids" => gap_candidates.map { |candidate| candidate.fetch("chapter_id") },
        "mechanical_gap_endpoint_count" => gap_endpoints.length,
        "mechanical_gap_endpoint_ids" => gap_endpoints,
        "warning" => "Observed candidates must not enter verification/manifests or count as final until every review_required item is closed.",
        "tool_probes" => tool_probes.sort_by { |probe| probe.fetch("id") },
        "candidates" => observed
      }
    end

    def observation_set_sha256(endpoint_report)
      records = endpoint_report.fetch("results").select { |record| ROLES.key?(record.fetch("role")) }.map do |record|
        {
          "chapter_id" => record.fetch("chapter_id"),
          "role" => record.fetch("role"),
          "status" => record.fetch("status"),
          "command" => record.fetch("command"),
          "expected_red_marker_observed" => record.fetch("expected_red_marker_observed"),
          "first_run" => stable_run_projection(record.fetch("first_run")),
          "repeat_run" => stable_run_projection(record.fetch("repeat_run")),
          "failures" => record.fetch("failures")
        }
      end.sort_by { |record| [record.fetch("chapter_id"), record.fetch("role")] }
      Canonical.sha256(Canonical.json(records))
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
      chapter_inputs = public_chapter_inputs(chapter_id)
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
          "command" => ["./#{File.basename(relative)}"],
          "static_input_closure_policy" => "all chapter-owned public example/exercise/lab files excluding generated-name components",
          "input_count" => chapter_inputs.length,
          "input_set_sha256" => Canonical.path_bytes_digest(chapter_inputs.map { |input| { "path" => input.fetch("path"), "bytes" => input.fetch("bytes") } }),
          "inputs" => chapter_inputs.map { |input| input.reject { |key, _value| key == "bytes" } },
          "tool_hints" => tool_hints(chapter_inputs.map { |input| input.fetch("bytes") }.join("\n"))
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
      text = bytes.dup.force_encoding(Encoding::UTF_8).scrub
      hints = TOOL_HINT_PATTERNS.each_with_object(["bash"]) do |(tool, pattern), memo|
        memo << tool if text.match?(pattern)
      end
      hints.uniq.sort
    end

    def static_inputs(root_relative)
      @static_inputs ||= {}
      @static_inputs[root_relative] ||= begin
        root_absolute = File.join(root, root_relative)
        entries = []
        Dir.glob(File.join(root_absolute, "**", "*"), File::FNM_DOTMATCH).sort.each do |absolute|
          relative_from_asset = absolute.delete_prefix(root_absolute + File::SEPARATOR)
          next if relative_from_asset.empty?
          next if relative_from_asset.split("/").any? { |part| GENERATED_NAMES.include?(part) || part == "." || part == ".." }

          stat = File.lstat(absolute)
          next if stat.directory?
          if stat.symlink? || !stat.file?
            relative = absolute.delete_prefix(root + File::SEPARATOR)
            raise ContractError.new("coverage", "E_STATIC_INPUT_KIND", "static input closure contains a symbolic link or special file", path: relative)
          end
          relative = absolute.delete_prefix(root + File::SEPARATOR)
          guard.validate_relative_shape!(relative)
          unless relative.start_with?(root_relative + "/")
            raise ContractError.new("coverage", "E_STATIC_INPUT_OWNER", "static input escapes its public endpoint root", path: relative)
          end
          bytes = File.binread(absolute)
          entries << {
            "path" => relative,
            "sha256" => Canonical.sha256(bytes),
            "size_bytes" => bytes.bytesize,
            "mode" => format("%04o", stat.mode & 0o777),
            "bytes" => bytes
          }
        end
        entries
      end
    end

    def public_chapter_inputs(chapter_id)
      @public_chapter_inputs ||= {}
      @public_chapter_inputs[chapter_id] ||= ROLES.values.sort.flat_map do |asset|
        static_inputs("#{asset}/encyclopedia/#{chapter_id}")
      end.sort_by { |input| input.fetch("path") }
    end

    def comparable_observation(result)
      %w[
        exit_code normalized_diagnostic_set_sha256 output_closure_status
        generated_output_count generated_output_set_sha256
      ].map { |key| result.fetch(key) }
    end

    def endpoint_mechanically_complete?(endpoint)
      endpoint.fetch("observation_status") == "passed" &&
        endpoint.fetch("observed_run_count") == 2 &&
        endpoint.fetch("two_fresh_copy_runs_consistent") &&
        (endpoint.fetch("role") != "exercise" || endpoint.fetch("expected_red_marker_present")) &&
        endpoint.fetch("tool_probes").all? { |probe| probe.fetch("status") == "observed" }
    end

    def unavailable_observation
      {
        "attempted" => false,
        "exit_code" => nil,
        "normalized_stdout_sha256" => nil,
        "normalized_stderr_sha256" => nil,
        "normalized_diagnostic_set_sha256" => nil,
        "output_closure_status" => "unavailable",
        "generated_output_count" => 0,
        "generated_output_set_sha256" => nil,
        "generated_output_sha256" => nil
      }
    end

    def stable_run_projection(result)
      return nil unless result

      result.select do |key, _value|
        %w[
          attempted exit_code timed_out normalized_stdout_sha256 normalized_stderr_sha256
          normalized_diagnostic_set_sha256 generated_output_count generated_output_set_sha256
          generated_output_sha256
          output_closure_status
        ].include?(key)
      end
    end
  end
end
