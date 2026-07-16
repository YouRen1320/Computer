# frozen_string_literal: true

require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

workload = JSON.parse(File.read(File.join(ROOT, "workload.json")))
evidence = JSON.parse(File.read(File.join(ROOT, "evidence.json")))
schema = File.read(File.join(ROOT, "schema.sql"))

dataset = workload.fetch("dataset")
counts = dataset.fetch("status_counts")
check(counts.values.sum == dataset.fetch("rows"), "status distribution sum")
check(counts == {"DONE" => 85000, "OPEN" => 8000, "IN_PROGRESS" => 5000, "CANCELLED" => 2000}, "fixed distribution")

query = workload.fetch("query")
check(query.fetch("order") == ["created_at DESC", "work_order_id DESC"], "deterministic order")
check(query.fetch("limit") == 50, "fixed limit")
result = workload.fetch("result")
check(result.fetch("before_rows") == result.fetch("after_rows"), "result row count")
check(result.fetch("before_fingerprint") == result.fetch("after_fingerprint"), "result fingerprint")

check(evidence.fetch("source") == "teaching-fixture-not-postgresql-server-output", "evidence provenance")
baseline = evidence.fetch("baseline")
candidate = evidence.fetch("composite_candidate")
check(baseline.fetch("nodes").include?("Seq Scan"), "baseline scan")
check(candidate.fetch("ddl").start_with?("(status, created_at DESC"), "composite leading equality")
check(candidate.fetch("index_condition").length == 3, "index conditions")
check(candidate.fetch("shared_blocks") < baseline.fetch("shared_blocks"), "fixture resource reduction")
check(candidate.fetch("result_fingerprint_equal") && candidate.fetch("decision") == "KEEP", "keep decision")

rejected = evidence.fetch("low_selectivity_candidate")
check(rejected.fetch("matched_rows").fdiv(dataset.fetch("rows")) == rejected.fetch("selectivity"), "selectivity")
check(rejected.fetch("candidate_shared_blocks") >= rejected.fetch("baseline_shared_blocks"), "no benefit evidence")
check(rejected.fetch("decision") == "REJECT" && rejected.fetch("rollback").start_with?("DROP INDEX"), "reject and rollback")

%w[generate_series ANALYZE EXPLAIN\ \(ANALYZE CREATE\ INDEX ROLLBACK].each do |token|
  check(schema.include?(token.gsub("\\", "")), "schema contract #{token}")
end

puts "dataset=100000|DONE=85000|OPEN=8000|IN_PROGRESS=5000|CANCELLED=2000"
puts "result-contract=rows:50|fingerprint-equal:PASS"
puts "composite-index=KEEP|shared-blocks=#{baseline.fetch("shared_blocks")}->#{candidate.fetch("shared_blocks")}"
puts "low-selectivity-index=REJECT|selectivity=#{format("%.2f", rejected.fetch("selectivity"))}"
puts "indexes-explain-example=PASS"
