# frozen_string_literal: true

require_relative "contract"

module Verification
  # Converts repeated clean-copy endpoint observations into a deterministic
  # machine-only exercise report. It never promotes an observed exit or marker
  # into a reviewed manifest contract.
  module ExerciseContractAudit
    module_function

    def build(endpoint_report, source_endpoint_report_sha256:)
      unless source_endpoint_report_sha256.is_a?(String) && source_endpoint_report_sha256.match?(SHA256)
        raise ContractError.new("exercise-audit", "E_ENDPOINT_SOURCE_DIGEST", "source endpoint report digest must be SHA-256")
      end
      records = endpoint_report.fetch("results").select { |record| record.fetch("role") == "exercise" }
      records = records.sort_by { |record| record.fetch("chapter_id") }
      unless records.length == 255 && records.map { |record| record.fetch("chapter_id") }.uniq.length == 255
        raise ContractError.new("exercise-audit", "E_EXERCISE_OBSERVATION_COUNT", "expected 255 unique exercise observations")
      end

      results = records.map { |record| exercise_record(record) }
      marker_missing = results.reject { |record| record.fetch("expected_red_marker_present") }.map { |record| record.fetch("chapter_id") }
      nonstandard_exit = results.reject { |record| record.fetch("observed_exact_exit_code") == 41 }.map { |record| record.fetch("chapter_id") }
      mechanical_failures = results.reject { |record| record.fetch("mechanical_status") == "passed" }.map { |record| record.fetch("chapter_id") }
      safe = results.select do |record|
        record.fetch("mechanical_status") == "passed" &&
          record.fetch("observed_exact_exit_code") == 41 &&
          record.fetch("expected_red_marker_present")
      end.map { |record| record.fetch("chapter_id") }
      distribution = results.each_with_object(Hash.new(0)) do |record, counts|
        exit_code = record.fetch("observed_exact_exit_code")
        counts[exit_code.nil? ? "unavailable" : exit_code.to_s] += 1
      end

      {
        "schema_version" => 1,
        "report_id" => "p9-exercise-contract-observations",
        "generated_by" => "scripts/audit-exercise-contracts.rb",
        "status" => mechanical_failures.empty? ? "observed-unreviewed" : "mechanical-failures-observed",
        "evidence_class" => "machine-only-not-learner-evidence",
        "promotion_status" => "forbidden-without-human-review",
        "source_endpoint_report_sha256" => source_endpoint_report_sha256,
        "chapter_count" => results.length,
        "run_count" => results.sum { |record| record.fetch("observed_run_count") },
        "fresh_copy_runs_per_chapter" => 2,
        "mechanical_failure_count" => mechanical_failures.length,
        "mechanical_failure_ids" => mechanical_failures,
        "expected_red_marker_present_count" => results.length - marker_missing.length,
        "expected_red_marker_missing_count" => marker_missing.length,
        "expected_red_marker_missing_ids" => marker_missing,
        "observed_exit_code_distribution" => distribution.keys.sort.each_with_object({}) { |key, memo| memo[key] = distribution.fetch(key) },
        "nonstandard_exit_41_count" => nonstandard_exit.length,
        "nonstandard_exit_41_ids" => nonstandard_exit,
        "safe_standardization_candidate_count" => safe.length,
        "safe_standardization_candidate_ids" => safe,
        "boundary" => "observed exact behavior is not a reviewed pedagogical or final verification contract",
        "results" => results
      }
    end

    def exercise_record(record)
      first = record.fetch("first_run")
      repeat = record.fetch("repeat_run")
      first ||= unavailable_observation
      repeat ||= unavailable_observation
      consistent = comparable_summary(first) == comparable_summary(repeat)
      mechanically_passed = record.fetch("status") == "passed" &&
        first.fetch("attempted", false) && repeat.fetch("attempted", false) && consistent
      {
        "chapter_id" => record.fetch("chapter_id"),
        "mechanical_status" => mechanically_passed ? "passed" : "failed",
        "command" => record.fetch("command"),
        "observed_exact_exit_code" => first.fetch("exit_code"),
        "repeat_exact_exit_code" => repeat.fetch("exit_code"),
        "observed_run_count" => [first, repeat].count { |run| run.fetch("attempted", false) },
        "timed_out" => first.fetch("timed_out") || repeat.fetch("timed_out"),
        "expected_red_marker_present" => record.fetch("expected_red_marker_observed"),
        "expected_red_marker_first_run" => record.fetch("expected_red_marker_first_run"),
        "expected_red_marker_repeat_run" => record.fetch("expected_red_marker_repeat_run"),
        "normalized_diagnostic_set_sha256" => first.fetch("normalized_diagnostic_set_sha256"),
        "repeat_normalized_diagnostic_set_sha256" => repeat.fetch("normalized_diagnostic_set_sha256"),
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
        "fresh_copy_consistent" => consistent
      }
    end

    def comparable_summary(result)
      %w[
        exit_code normalized_diagnostic_set_sha256 output_closure_status
        generated_output_count generated_output_set_sha256
      ].map { |key| result.fetch(key) }
    end

    def unavailable_observation
      {
        "attempted" => false,
        "exit_code" => nil,
        "timed_out" => false,
        "normalized_diagnostic_set_sha256" => nil,
        "output_closure_status" => "unavailable",
        "generated_output_count" => 0,
        "generated_output_set_sha256" => nil,
        "generated_output_sha256" => nil
      }
    end
  end
end
