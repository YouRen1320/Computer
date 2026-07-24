# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "stringio"

require_relative "../../verification/lib/coverage_audit"
require_relative "../../verification/lib/machine_report_schema"
require_relative "../../scripts/generate-verification-manifests"

class VerificationCoverageAuditTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  SHA = "f" * 64
  FINAL_IDS = %w[
    ch.java.expressions-conversions
    ch.java.platform-toolchain
    ch.java.program-structure
    ch.java.values-variables-types
  ].freeze

  def test_current_255_chapter_coverage_is_exact_and_incomplete_by_design
    report = Verification::CoverageAudit.new(ROOT).report

    assert_equal 255, report.fetch("chapter_total")
    assert_equal 4, report.fetch("final_manifest_count")
    assert_equal FINAL_IDS, report.fetch("final_manifest_ids")
    assert_equal 251, report.fetch("missing_final_manifest_count")
    assert_equal 251, report.fetch("missing_final_manifest_ids").length
    assert_equal 251, report.fetch("bootstrap_candidate_count")
    assert_equal 753, report.fetch("bootstrap_candidate_endpoint_count")
    assert_equal 0, report.fetch("missing_without_candidate_count")
    assert_equal false, report.fetch("contract_complete")
    assert_equal "bootstrap-observed-unreviewed", report.fetch("candidate_status")
    assert_equal report.fetch("missing_final_manifest_ids"), report.fetch("bootstrap_candidate_ids")
    assert_equal 753, report.fetch("candidate_tool_hint_endpoint_counts").fetch("bash")
    assert_operator report.fetch("candidate_tool_hint_endpoint_counts").fetch("python"), :>, 0
    assert_operator report.fetch("candidate_tool_hint_endpoint_counts").fetch("node"), :>, 0
    assert_operator report.fetch("candidate_tool_hint_endpoint_counts").fetch("dart"), :>, 0
  end

  def test_every_bootstrap_candidate_is_chapter_owned_and_requires_human_promotion_review
    candidates = Verification::CoverageAudit.new(ROOT).candidates
    allowed_tools = Verification::TOOL_VERSION_COMMANDS.keys

    assert_equal 251, candidates.length
    candidates.each do |candidate|
      chapter_id = candidate.fetch("chapter_id")
      assert_equal "bootstrap-observed-unreviewed", candidate.fetch("status")
      assert_equal 3, candidate.fetch("endpoints").length
      assert_equal 6, candidate.fetch("review_required").length
      candidate.fetch("endpoints").each do |endpoint|
        assert_includes endpoint.fetch("verify_path"), "/#{chapter_id}/"
        assert_match(/\A[0-9a-f]{64}\z/, endpoint.fetch("verify_sha256"))
        assert_equal "0755", endpoint.fetch("verify_mode")
        assert_equal 41, endpoint.fetch("suggested_expected_exit_code_unreviewed") if endpoint.fetch("role") == "exercise"
        assert_empty(endpoint.fetch("tool_hints") - allowed_tools)
        refute_includes endpoint.fetch("verify_path"), "solutions-private"
      end
    end
  end

  def test_coverage_cli_returns_nonzero_and_machine_readable_exact_gap_list
    stdout = StringIO.new
    stderr = StringIO.new

    status = Verification::ManifestGenerator.run(
      ["--coverage", "--json"], root: ROOT, stdout: stdout, stderr: stderr
    )
    report = JSON.parse(stdout.string)

    assert_equal 1, status
    assert_empty stderr.string
    assert_equal 251, report.fetch("missing_final_manifest_count")
    assert_equal 251, report.fetch("missing_final_manifest_ids").length
    assert_equal false, report.fetch("contract_complete")
  end

  def test_require_complete_is_a_hard_failure_not_a_warning
    error = assert_raises(Verification::ContractError) do
      Verification::CoverageAudit.new(ROOT).require_complete!
    end

    assert_equal "E_MANIFEST_COVERAGE", error.code
    assert_includes error.message, "251 of 255"
  end

  def test_candidate_v2_contains_full_static_inputs_repeated_observations_and_tool_probes_without_promotion
    audit = Verification::CoverageAudit.new(ROOT)
    candidates = audit.candidates
    endpoint_report = endpoint_report_for(candidates)
    probes = tool_probes_for(candidates)
    manifest_names_before = Dir.children(File.join(ROOT, Verification::MANIFEST_DIRECTORY)).sort

    report = audit.candidate_catalog_v2(
      endpoint_report: endpoint_report,
      tool_probes: probes,
      source_endpoint_report_sha256: SHA
    )
    report["endpoint_observation_set_sha256"] = audit.observation_set_sha256(endpoint_report)

    assert_equal 2, report.fetch("schema_version")
    assert_equal 251, report.fetch("candidate_count")
    assert_equal 753, report.fetch("endpoint_count")
    assert_equal 0, report.fetch("mechanical_gap_candidate_count")
    assert_equal "forbidden-without-human-review", report.fetch("promotion_status")
    assert_equal SHA, report.fetch("source_endpoint_report_sha256")
    report.fetch("candidates").each do |candidate|
      assert_equal "observed-unreviewed-candidate-v2", candidate.fetch("status")
      candidate.fetch("endpoints").each do |endpoint|
        assert_equal endpoint.fetch("input_count"), endpoint.fetch("inputs").length
        assert_includes endpoint.fetch("inputs").map { |input| input.fetch("path") }, endpoint.fetch("verify_path")
        assert_equal ["./verify.sh"], endpoint.fetch("command")
        assert_includes endpoint.fetch("static_input_closure_policy"), "public example/exercise/lab"
        assert_equal 2, endpoint.fetch("observed_run_count")
        assert_equal true, endpoint.fetch("two_fresh_copy_runs_consistent")
        refute_empty endpoint.fetch("tool_probes")
      end
    end
    assert_operator report.fetch("candidates").flat_map { |candidate| candidate.fetch("endpoints") }
      .count { |endpoint| endpoint.fetch("input_count") > 1 }, :>, 0
    assert_equal manifest_names_before, Dir.children(File.join(ROOT, Verification::MANIFEST_DIRECTORY)).sort
    assert_same report, Verification::MachineReportSchema.validate!(
      root: ROOT,
      schema_path: "schemas/observed-verification-candidates-v2.schema.json",
      document: report
    )
  end

  def test_candidate_v2_records_missing_repeat_as_a_mechanical_gap
    audit = Verification::CoverageAudit.new(ROOT)
    candidates = audit.candidates
    endpoint_report = endpoint_report_for(candidates)
    endpoint_report.fetch("results").first["repeat_run"] = nil

    report = audit.candidate_catalog_v2(
      endpoint_report: endpoint_report,
      tool_probes: tool_probes_for(candidates),
      source_endpoint_report_sha256: SHA
    )

    assert_equal "observed-unreviewed-candidate-v2-with-mechanical-gaps", report.fetch("status")
    assert_equal 1, report.fetch("mechanical_gap_candidate_count")
    assert_equal 1, report.fetch("mechanical_gap_endpoint_count")
  end

  def test_candidate_v2_never_accepts_an_exercise_failure_without_expected_red_marker
    audit = Verification::CoverageAudit.new(ROOT)
    candidates = audit.candidates
    endpoint_report = endpoint_report_for(candidates)
    exercise = endpoint_report.fetch("results").find { |result| result.fetch("role") == "exercise" }
    exercise["expected_red_marker_observed"] = false

    report = audit.candidate_catalog_v2(
      endpoint_report: endpoint_report,
      tool_probes: tool_probes_for(candidates),
      source_endpoint_report_sha256: SHA
    )

    assert_equal "observed-unreviewed-candidate-v2-with-mechanical-gaps", report.fetch("status")
    assert_equal 1, report.fetch("mechanical_gap_candidate_count")
    assert_equal 1, report.fetch("mechanical_gap_endpoint_count")
    assert_equal ["#{exercise.fetch('chapter_id')}:exercise"], report.fetch("mechanical_gap_endpoint_ids")
  end

  def test_candidate_schema_accepts_null_observations_but_rejects_other_types
    audit = Verification::CoverageAudit.new(ROOT)
    candidates = audit.candidates
    endpoint_report = endpoint_report_for(candidates)
    endpoint_report.fetch("results").first["repeat_run"] = nil
    report = audit.candidate_catalog_v2(
      endpoint_report: endpoint_report,
      tool_probes: tool_probes_for(candidates),
      source_endpoint_report_sha256: SHA
    )
    report["endpoint_observation_set_sha256"] = audit.observation_set_sha256(endpoint_report)
    assert_same report, Verification::MachineReportSchema.validate!(
      root: ROOT,
      schema_path: "schemas/observed-verification-candidates-v2.schema.json",
      document: report
    )

    report.fetch("candidates").first.fetch("endpoints").first
      .fetch("stable_observations")["repeat_normalized_diagnostic_set_sha256"] = false
    error = assert_raises(Verification::ContractError) do
      Verification::MachineReportSchema.validate!(
        root: ROOT,
        schema_path: "schemas/observed-verification-candidates-v2.schema.json",
        document: report
      )
    end
    assert_equal "E_MACHINE_REPORT_SCHEMA", error.code
  end

  private

  def endpoint_report_for(candidates)
    {
      "results" => candidates.flat_map do |candidate|
        candidate.fetch("endpoints").map do |endpoint|
          {
            "chapter_id" => candidate.fetch("chapter_id"),
            "role" => endpoint.fetch("role"),
            "status" => "passed",
            "command" => ["bash", "verify.sh"],
            "expected_red_marker_observed" => endpoint.fetch("role") == "exercise",
            "first_run" => endpoint_run,
            "repeat_run" => endpoint_run,
            "failures" => []
          }
        end
      end
    }
  end

  def endpoint_run
    {
      "attempted" => true,
      "exit_code" => 0,
      "normalized_stdout_sha256" => "a" * 64,
      "normalized_stderr_sha256" => "b" * 64,
      "normalized_diagnostic_set_sha256" => "c" * 64,
      "output_closure_status" => "closed",
      "generated_output_count" => 0,
      "generated_output_set_sha256" => "d" * 64,
      "generated_output_sha256" => "d" * 64
    }
  end

  def tool_probes_for(candidates)
    candidates.flat_map do |candidate|
      candidate.fetch("endpoints").flat_map { |endpoint| endpoint.fetch("tool_hints") }
    end.uniq.sort.map do |id|
      {
        "id" => id,
        "version_argv" => Verification::TOOL_VERSION_COMMANDS.fetch(id),
        "status" => "observed",
        "timed_out" => false,
        "exit_code" => 0,
        "observed_first_line" => "observed",
        "normalized_version_output_sha256" => "e" * 64,
        "normalized_version_output_size_bytes" => 8,
        "normalization_policy" => "fixture"
      }
    end
  end
end
