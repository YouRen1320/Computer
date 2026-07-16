# frozen_string_literal: true

require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "lab-failure=#{message}" unless condition
end

scenarios = JSON.parse(File.read(File.join(ROOT, "scenarios.json")))
check(scenarios.map { |item| item.fetch("id") } == %w[low-selectivity-single-column wrong-composite-order function-on-indexed-column], "fault ids")

low = scenarios.fetch(0)
selectivity = low.fetch("matched_rows").fdiv(low.fetch("dataset_rows"))
check(selectivity == 0.85, "low-selectivity evidence")
check(low.fetch("candidate_shared_blocks") >= low.fetch("baseline_shared_blocks"), "no resource benefit")
check(low.fetch("expected") == "REJECT:no-resource-benefit", "reject decision")

order = scenarios.fetch(1)
check(order.fetch("query_shape") == "status-equality+created-at-range+stable-order", "query shape")
check(order.fetch("broken_index").start_with?("(created_at"), "broken order")
check(order.fetch("repair_index").start_with?("(status, created_at DESC"), "repair order")
check(order.fetch("repair_index_rows_examined") < order.fetch("broken_index_rows_examined"), "row work reduction")
check(order.fetch("expected") == "REPAIR:leading-equality-then-range-order", "order diagnosis")

function = scenarios.fetch(2)
check(!function.fetch("broken_index_condition"), "function mismatch")
check(function.fetch("repair_predicate").include?("created_at>=") && function.fetch("repair_predicate").include?("created_at<"), "half-open range")
check(function.fetch("repair_index_condition") && function.fetch("expected") == "REPAIR:half-open-range", "function repair")

puts "low-selectivity=REJECT|selectivity=#{format("%.2f", selectivity)}|blocks=#{low.fetch("baseline_shared_blocks")}->#{low.fetch("candidate_shared_blocks")}"
puts "wrong-column-order=REPAIR|examined=#{order.fetch("broken_index_rows_examined")}->#{order.fetch("repair_index_rows_examined")}"
puts "function-on-column=REPAIR|predicate=half-open-range"
puts "indexes-explain-lab=PASS"
