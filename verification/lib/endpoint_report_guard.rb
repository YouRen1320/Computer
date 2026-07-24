# frozen_string_literal: true

require_relative "contract"

module Verification
  # Derived machine reports may only bind to a complete, successful endpoint
  # audit. Schema validity alone is insufficient because count fields and
  # per-result statuses could still describe a failed source run.
  module EndpointReportGuard
    EXPECTED_CHAPTER_COUNT = 255
    EXPECTED_ENDPOINT_COUNT = 1020
    EXPECTED_ROLES = %w[example exercise lab private-solution].freeze

    module_function

    def require_full_pass!(report)
      results = report.fetch("results")
      role_counts = report.fetch("role_counts")
      complete = report.fetch("status") == "passed" &&
        report.fetch("chapter_count") == EXPECTED_CHAPTER_COUNT &&
        report.fetch("endpoint_count") == EXPECTED_ENDPOINT_COUNT &&
        report.fetch("passed_count") == EXPECTED_ENDPOINT_COUNT &&
        report.fetch("failed_count").zero? &&
        report.fetch("infrastructure_failures").empty? &&
        results.length == EXPECTED_ENDPOINT_COUNT &&
        results.all? { |result| result.fetch("status") == "passed" } &&
        EXPECTED_ROLES.all? do |role|
          counts = role_counts.fetch(role)
          counts.fetch("total") == EXPECTED_CHAPTER_COUNT &&
            counts.fetch("passed") == EXPECTED_CHAPTER_COUNT &&
            counts.fetch("failed").zero?
        end
      return report if complete

      raise ContractError.new(
        "derived-machine-report",
        "E_ENDPOINT_SOURCE_NOT_FULL_PASS",
        "source endpoint report must be a full passed 1020-endpoint audit with no infrastructure failures"
      )
    rescue KeyError, NoMethodError
      raise ContractError.new(
        "derived-machine-report",
        "E_ENDPOINT_SOURCE_NOT_FULL_PASS",
        "source endpoint report is missing full-pass semantic fields"
      )
    end
  end
end
