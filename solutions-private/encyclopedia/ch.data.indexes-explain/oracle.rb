# frozen_string_literal: true

require "json"

def check(condition, message)
  raise "answer-error=#{message}" unless condition
end

answer = JSON.parse(File.read(ARGV.fetch(0)))
dataset = answer.fetch("dataset")
check(dataset.fetch("status_counts").values.sum == dataset.fetch("rows"), "distribution must sum to dataset size")
result = answer.fetch("result")
check(result.fetch("before_fingerprint") == result.fetch("after_fingerprint"), "query result fingerprint changed")
candidate = answer.fetch("candidate")
check(candidate.fetch("index_columns") == ["status", "created_at DESC", "work_order_id DESC"], "composite order must match equality range and stable sort")
check(candidate.fetch("candidate_shared_blocks") < candidate.fetch("baseline_shared_blocks"), "candidate needs resource evidence")
check(candidate.fetch("decision") == "KEEP", "beneficial candidate should be kept")
check(answer.fetch("low_selectivity_status_index") == "REJECT", "low-selectivity index must be rejected")
check(answer.fetch("function_repair") == "half-open-created-at-range", "function predicate needs a half-open range")
check(answer.fetch("rollback").start_with?("DROP INDEX"), "record rollback DDL")
puts "indexes-explain-answer=PASS"
