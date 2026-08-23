# frozen_string_literal: true

require "csv"
require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "lab-failure=#{message}" unless condition
end

sql = File.read(File.join(ROOT, "query.sql"))
check(sql.include?("LEFT JOIN factorycare.work_order AS w"), "LEFT JOIN")
check(sql.include?("ON w.device_id = d.device_id\n AND w.status = 'CREATED'"), "CREATED belongs in ON")
check(sql.scan("COUNT(w.work_order_id) AS work_order_count").length == 2, "right-key counts")
check(sql.include?("HAVING COUNT(w.work_order_id) >= 2"), "HAVING threshold")
scenarios = JSON.parse(File.read(File.join(ROOT, "scenarios.json")))
check(scenarios.map { |item| item.fetch("id") } == %w[cartesian left-filter-in-where count-star], "scenario ids")

devices = CSV.read(File.join(ROOT, "devices.csv"), headers: true)
orders = CSV.read(File.join(ROOT, "work_orders.csv"), headers: true)
technicians = CSV.read(File.join(ROOT, "technicians.csv"), headers: true)

cartesian_count = devices.length * orders.length
key_matches = devices.sum { |device| orders.count { |order| order["device_id"] == device["device_id"] } }
all_left_rows = devices.sum do |device|
  [1, orders.count { |order| order["device_id"] == device["device_id"] }].max
end
on_open_rows = devices.sum do |device|
  [1, orders.count { |order| order["device_id"] == device["device_id"] && order["status"] == "CREATED" }].max
end
where_open_rows = orders.count { |order| order["status"] == "CREATED" && devices.any? { |device| device["device_id"] == order["device_id"] } }
correct_counts = technicians.map do |technician|
  [technician["technician_id"], orders.count { |order| order["technician_id"] == technician["technician_id"] }]
end
wrong_counts = correct_counts.map { |id, count| [id, [1, count].max] }

check(cartesian_count == 16 && key_matches == 4, "cartesian injection")
check(all_left_rows == 5, "1:N LEFT cardinality")
check(on_open_rows == 4 && where_open_rows == 3, "ON/WHERE placement")
check(correct_counts.last == ["T-03", 0] && wrong_counts.last == ["T-03", 1], "COUNT star boundary")

puts "key-match-rows=#{key_matches}"
puts "left-detail-rows=#{all_left_rows}"
puts "cartesian-rows=#{cartesian_count}"
puts "open-filter-in-on-rows=#{on_open_rows}"
puts "open-filter-in-where-rows=#{where_open_rows}"
puts "lost-device=D-03"
puts "technician-correct=#{correct_counts.map { |id, count| "#{id}:#{count}" }.join(",")}"
puts "technician-count-star=#{wrong_counts.map { |id, count| "#{id}:#{count}" }.join(",")}"
puts "having-pass=T-01"
puts "joins-lab=PASS"
