# frozen_string_literal: true

require "csv"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

sql = File.read(File.join(ROOT, "query.sql"))
check(sql.scan("WHERE EXISTS (").length == 3, "three EXISTS predicates")
check(sql.include?("w.device_id = d.device_id"), "correlated device key")
check(sql.scan("w.status IN ('OPEN', 'IN_PROGRESS')").length == 3, "unfinished status predicate")
check(sql.include?("SELECT COUNT(*)\n    FROM factorycare.work_order AS w"), "scalar count")
check(sql.include?("WITH unfinished_devices AS ("), "first CTE")
check(sql.include?("category_counts AS ("), "second CTE")
check(sql.include?("HAVING COUNT(*) >= 2"), "flat threshold")
check(sql.include?("WHERE device_count >= 2"), "CTE threshold")

devices = CSV.read(File.join(ROOT, "devices.csv"), headers: true)
orders = CSV.read(File.join(ROOT, "work_orders.csv"), headers: true)
unfinished_statuses = ["OPEN", "IN_PROGRESS"]

unfinished = devices.select do |device|
  orders.any? do |order|
    order["device_id"] == device["device_id"] && unfinished_statuses.include?(order["status"])
  end
end

counts = devices.map do |device|
  [device["device_id"], orders.count { |order| order["device_id"] == device["device_id"] }]
end

grouped = unfinished.group_by { |device| device["category"] }.map do |category, rows|
  [category, rows.length]
end.sort_by(&:first)
flat_result = grouped.select { |_category, count| count >= 2 }
cte_result = grouped.select { |_category, count| count >= 2 }

check(devices.length == 5 && orders.length == 6, "fixture cardinality")
check(unfinished.map { |row| row["device_id"] } == %w[D-01 D-02 D-05], "unfinished device set")
check(counts == [["D-01", 2], ["D-02", 1], ["D-03", 2], ["D-04", 0], ["D-05", 1]], "scalar counts")
check(grouped == [["compressor", 1], ["pump", 2]], "category intermediate")
check(flat_result == [["pump", 2]] && cte_result == flat_result, "decomposition equivalence")

puts "devices=#{devices.length}"
puts "work-orders=#{orders.length}"
puts "unfinished-devices=#{unfinished.map { |row| row["device_id"] }.join(",")}"
puts "work-order-counts=#{counts.map { |id, count| "#{id}:#{count}" }.join(",")}"
puts "category-counts=#{grouped.map { |category, count| "#{category}:#{count}" }.join(",")}"
puts "flat-result=#{flat_result.map { |category, count| "#{category}:#{count}" }.join(",")}"
puts "cte-result=#{cte_result.map { |category, count| "#{category}:#{count}" }.join(",")}"
puts "equivalent-result=PASS"
puts "subqueries-cte-example=PASS"
