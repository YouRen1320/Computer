# frozen_string_literal: true

require "csv"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

sql = File.read(File.join(ROOT, "query.sql"))
check(sql.include?("INNER JOIN factorycare.work_order AS w"), "INNER JOIN")
check(sql.scan("LEFT JOIN factorycare.work_order AS w").length == 2, "LEFT work order joins")
check(sql.include?("LEFT JOIN factorycare.technician AS t"), "LEFT technician join")
check(sql.include?("ON w.device_id = d.device_id"), "device key")
check(sql.include?("ON t.technician_id = w.technician_id"), "technician key")
check(sql.include?("COUNT(w.work_order_id) AS work_order_count"), "right-key count")
check(sql.include?("FULL JOIN factorycare.work_order AS w"), "FULL JOIN")

devices = CSV.read(File.join(ROOT, "devices.csv"), headers: true)
orders = CSV.read(File.join(ROOT, "work_orders.csv"), headers: true)
technicians = CSV.read(File.join(ROOT, "technicians.csv"), headers: true)
orders_by_device = orders.group_by { |row| row["device_id"] }
technician_by_id = technicians.each_with_object({}) { |row, memo| memo[row["technician_id"]] = row }

inner = devices.flat_map { |device| orders_by_device.fetch(device["device_id"], []).map { |order| [device, order] } }
details = devices.flat_map do |device|
  matches = orders_by_device.fetch(device["device_id"], [])
  matches.empty? ? [[device, nil, nil]] : matches.map { |order| [device, order, technician_by_id[order["technician_id"]]] }
end
counts = technicians.map do |technician|
  [technician["technician_id"], orders.count { |order| order["technician_id"] == technician["technician_id"] }]
end
unmatched_technicians = technicians.reject { |technician| orders.any? { |order| order["technician_id"] == technician["technician_id"] } }
unmatched_orders = orders.reject { |order| technician_by_id.key?(order["technician_id"]) }

check(inner.length == 4, "INNER cardinality")
check(details.length == 5, "LEFT detail cardinality")
check(counts == [["T-01", 2], ["T-02", 1], ["T-03", 0]], "technician counts")
check(unmatched_technicians.map { |row| row["technician_id"] } == ["T-03"], "FULL left-only")
check(unmatched_orders.map { |row| row["work_order_id"] } == ["W-04"], "FULL right-only")

puts "devices=#{devices.length}"
puts "work-orders=#{orders.length}"
puts "technicians=#{technicians.length}"
puts "inner-device-work-order-rows=#{inner.length}"
puts "left-detail-rows=#{details.length}"
details.each do |device, order, technician|
  puts "detail=#{device["device_id"]}|#{order&.fetch("work_order_id") || "NULL"}|#{technician&.fetch("technician_id") || "NULL"}"
end
puts "technician-counts=#{counts.map { |id, count| "#{id}:#{count}" }.join(",")}"
puts "full-left-only=#{unmatched_technicians.map { |row| row["technician_id"] }.join(",")}"
puts "full-right-only=#{unmatched_orders.map { |row| row["work_order_id"] }.join(",")}"
puts "joins-example=PASS"
