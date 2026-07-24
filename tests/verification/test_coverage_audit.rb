# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "stringio"

require_relative "../../verification/lib/coverage_audit"
require_relative "../../scripts/generate-verification-manifests"

class VerificationCoverageAuditTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
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
end
