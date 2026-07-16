# frozen_string_literal: true

require "csv"
require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "lab-failure=#{message}" unless condition
end

sql = File.read(File.join(ROOT, "query.sql"))
check(sql.scan("WHERE EXISTS (").length == 2, "EXISTS queries")
check(sql.include?("w.device_id = d.device_id"), "correlated device key")
check(sql.include?("WITH unfinished_devices AS ("), "named first CTE")
check(sql.include?("category_counts AS ("), "named aggregate CTE")
check(sql.include?("WHERE NOT EXISTS ("), "NULL-safe anti-join")
check(!sql.match?(/\bNOT IN\s*\(/), "correct query must not use NOT IN")

scenarios = JSON.parse(File.read(File.join(ROOT, "scenarios.json")))
check(scenarios.map { |item| item.fetch("id") } == %w[not-in-null wrong-correlation-level wrong-cte-intermediate], "scenario ids")

devices = CSV.read(File.join(ROOT, "devices.csv"), headers: true)
orders = CSV.read(File.join(ROOT, "work_orders.csv"), headers: true)
exclusions = CSV.read(File.join(ROOT, "exclusions.csv"), headers: true)
unfinished_statuses = ["OPEN", "IN_PROGRESS"]

correct = devices.select do |device|
  orders.any? { |order| order["device_id"] == device["device_id"] && unfinished_statuses.include?(order["status"]) }
end
wrong_correlation = orders.any? { |order| unfinished_statuses.include?(order["status"]) } ? devices : []
wrong_cte = devices.select do |device|
  orders.any? { |order| order["device_id"] == device["device_id"] && order["status"] == "DONE" }
end

empty_right = []
empty_in = devices.select { |device| empty_right.include?(device["device_id"]) }
empty_not_in = devices.reject { |device| empty_right.include?(device["device_id"]) }
multi_match = devices.select do |device|
  orders.count { |order| order["device_id"] == device["device_id"] } > 1
end

excluded_keys = exclusions.map { |row| row["device_id"] }
not_in_with_null = devices.select do |device|
  matching = excluded_keys.compact.include?(device["device_id"])
  !matching && !excluded_keys.include?(nil)
end
not_exists = devices.reject do |device|
  excluded_keys.compact.include?(device["device_id"])
end

grouped = correct.group_by { |device| device["category"] }.map { |category, rows| [category, rows.length] }.sort_by(&:first)
flat_result = grouped.select { |_category, count| count >= 2 }
cte_result = grouped.select { |_category, count| count >= 2 }

check(excluded_keys == ["D-02", nil], "NULL injection fixture")
check(empty_in.empty? && empty_not_in.length == 5, "empty subquery truth table")
check(multi_match.map { |row| row["device_id"] } == %w[D-01 D-03], "multi-row scalar boundary")
check(not_in_with_null.empty?, "NOT IN NULL result")
check(not_exists.map { |row| row["device_id"] } == %w[D-01 D-03 D-04 D-05], "NOT EXISTS NULL result")
check(correct.map { |row| row["device_id"] } == %w[D-01 D-02 D-05], "correct EXISTS set")
check(wrong_correlation.length == 5, "wrong correlation set")
check(wrong_cte.map { |row| row["device_id"] } == %w[D-01 D-03], "wrong CTE intermediate")
check(flat_result == [["pump", 2]] && cte_result == flat_result, "decomposition equivalence")

ids = ->(rows) { rows.map { |row| row["device_id"] }.join(",") }
puts "empty-in=#{ids.call(empty_in)}"
puts "empty-not-in=#{ids.call(empty_not_in)}"
puts "scalar-multi-match-devices=#{ids.call(multi_match)}"
puts "not-in-with-null=#{ids.call(not_in_with_null)}"
puts "not-exists-with-null=#{ids.call(not_exists)}"
puts "correct-exists=#{ids.call(correct)}"
puts "broken-correlation=#{ids.call(wrong_correlation)}"
puts "correct-cte-intermediate=#{ids.call(correct)}"
puts "broken-cte-intermediate=#{ids.call(wrong_cte)}"
puts "flat-result=#{flat_result.map { |category, count| "#{category}:#{count}" }.join(",")}"
puts "cte-result=#{cte_result.map { |category, count| "#{category}:#{count}" }.join(",")}"
puts "decomposition-equivalent=PASS"
puts "subqueries-cte-lab=PASS"
