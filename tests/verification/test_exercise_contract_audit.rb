# frozen_string_literal: true

require "json"
require "minitest/autorun"

require_relative "../../verification/lib/exercise_contract_audit"
require_relative "../../verification/lib/endpoint_report_guard"
require_relative "../../verification/lib/machine_report_schema"

class ExerciseContractAuditTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  SHA = "a" * 64

  def test_builds_255_sorted_deterministic_observations_without_promoting_them
    endpoint_report = report_fixture
    endpoint_report.fetch("results").reverse!

    report = Verification::ExerciseContractAudit.build(endpoint_report, source_endpoint_report_sha256: SHA)

    assert_equal 255, report.fetch("chapter_count")
    assert_equal 510, report.fetch("run_count")
    assert_equal "observed-unreviewed", report.fetch("status")
    assert_equal "machine-only-not-learner-evidence", report.fetch("evidence_class")
    assert_equal "forbidden-without-human-review", report.fetch("promotion_status")
    assert_equal SHA, report.fetch("source_endpoint_report_sha256")
    assert_equal 254, report.fetch("safe_standardization_candidate_count")
    assert_equal 1, report.fetch("expected_red_marker_missing_count")
    assert_equal 1, report.fetch("nonstandard_exit_41_count")
    assert_equal({ "7" => 1, "41" => 254 }, report.fetch("observed_exit_code_distribution"))
    assert_equal report.fetch("results").sort_by { |record| record.fetch("chapter_id") }, report.fetch("results")
    assert_equal Verification::Canonical.json(report), Verification::Canonical.json(
      Verification::ExerciseContractAudit.build(endpoint_report, source_endpoint_report_sha256: SHA)
    )
    assert_same report, Verification::MachineReportSchema.validate!(
      root: ROOT,
      schema_path: "schemas/exercise-contract-audit.schema.json",
      document: report
    )
  end

  def test_missing_repeat_is_recorded_as_a_mechanical_gap_instead_of_becoming_final
    endpoint_report = report_fixture
    record = endpoint_report.fetch("results").first
    record["repeat_run"] = nil
    record["expected_red_marker_observed"] = false
    record["expected_red_marker_repeat_run"] = false

    report = Verification::ExerciseContractAudit.build(endpoint_report, source_endpoint_report_sha256: SHA)
    observed = report.fetch("results").find { |item| item.fetch("chapter_id") == record.fetch("chapter_id") }

    assert_equal "mechanical-failures-observed", report.fetch("status")
    assert_equal "failed", observed.fetch("mechanical_status")
    assert_equal 1, observed.fetch("observed_run_count")
    assert_equal false, observed.fetch("fresh_copy_consistent")
    assert_includes report.fetch("mechanical_failure_ids"), record.fetch("chapter_id")
    assert_same report, Verification::MachineReportSchema.validate!(
      root: ROOT,
      schema_path: "schemas/exercise-contract-audit.schema.json",
      document: report
    )
  end

  def test_requires_exactly_255_unique_exercises
    endpoint_report = report_fixture
    endpoint_report.fetch("results").pop

    error = assert_raises(Verification::ContractError) do
      Verification::ExerciseContractAudit.build(endpoint_report, source_endpoint_report_sha256: SHA)
    end

    assert_equal "E_EXERCISE_OBSERVATION_COUNT", error.code
  end

  def test_schema_rejects_non_nullable_junk_in_observation_fields
    report = Verification::ExerciseContractAudit.build(report_fixture, source_endpoint_report_sha256: SHA)
    report.fetch("results").first["observed_exact_exit_code"] = "41"

    error = assert_raises(Verification::ContractError) do
      Verification::MachineReportSchema.validate!(
        root: ROOT,
        schema_path: "schemas/exercise-contract-audit.schema.json",
        document: report
      )
    end

    assert_equal "E_MACHINE_REPORT_SCHEMA", error.code
  end

  def test_endpoint_source_guard_requires_full_clean_pass
    report = full_pass_report_fixture
    assert_same report, Verification::EndpointReportGuard.require_full_pass!(report)

    mutations = [
      ->(item) { item["status"] = "failed" },
      ->(item) { item["endpoint_count"] = 1019 },
      ->(item) { item["passed_count"] = 1019 },
      ->(item) { item["failed_count"] = 1 },
      ->(item) { item["infrastructure_failures"] = ["cache changed"] }
    ]
    mutations.each do |mutate|
      rejected = full_pass_report_fixture
      mutate.call(rejected)
      error = assert_raises(Verification::ContractError) do
        Verification::EndpointReportGuard.require_full_pass!(rejected)
      end
      assert_equal "E_ENDPOINT_SOURCE_NOT_FULL_PASS", error.code
    end
  end

  private

  def report_fixture
    {
      "results" => Array.new(255) do |index|
        exit_code = index.zero? ? 7 : 41
        marker = !index.zero?
        {
          "chapter_id" => format("ch.fixture.topic-%03d", index),
          "role" => "exercise",
          "status" => "passed",
          "command" => ["./verify.sh"],
          "expected_red_marker_observed" => marker,
          "expected_red_marker_first_run" => marker,
          "expected_red_marker_repeat_run" => marker,
          "first_run" => run_fixture(exit_code),
          "repeat_run" => run_fixture(exit_code)
        }
      end
    }
  end

  def run_fixture(exit_code)
    {
      "attempted" => true,
      "exit_code" => exit_code,
      "timed_out" => false,
      "normalized_diagnostic_set_sha256" => SHA,
      "output_closure_status" => "closed",
      "generated_output_count" => 0,
      "generated_output_set_sha256" => SHA,
      "generated_output_sha256" => SHA
    }
  end

  def full_pass_report_fixture
    roles = %w[example exercise lab private-solution]
    {
      "status" => "passed",
      "chapter_count" => 255,
      "endpoint_count" => 1020,
      "passed_count" => 1020,
      "failed_count" => 0,
      "infrastructure_failures" => [],
      "role_counts" => roles.to_h do |role|
        [role, { "total" => 255, "passed" => 255, "failed" => 0 }]
      end,
      "results" => roles.flat_map do |role|
        Array.new(255) { { "role" => role, "status" => "passed" } }
      end
    }
  end
end
