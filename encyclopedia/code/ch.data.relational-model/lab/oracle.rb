# frozen_string_literal: true

require "csv"
require "json"
require "set"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

def read_csv(name)
  CSV.read(File.join(ROOT, "data", name), headers: true)
end

answer = JSON.parse(File.read(File.join(ROOT, "observations.json")))
wide = read_csv("wide_work_order.csv")
devices = read_csv("device.csv")
work_orders = read_csv("work_order.csv")

check(answer.fetch("wide_row_meaning") == "one work order mixed with copied device facts",
      "wide row meaning is ambiguous")
check(answer.fetch("device_primary_key") == ["device_id"], "wrong device primary key")
check(answer.fetch("work_order_primary_key") == ["work_order_id"], "wrong work order primary key")
check(answer.dig("foreign_key", "from") == "work_order.device_id", "foreign key starts on wrong table")
check(answer.dig("foreign_key", "to") == "device.device_id", "foreign key target is wrong")
check(answer.fetch("cardinality") == "device 1 -> 0..N work_order", "wrong cardinality")

device_ids = devices.map { |row| row["device_id"] }
work_order_ids = work_orders.map { |row| row["work_order_id"] }
check(device_ids.compact.uniq.length == devices.length, "clean device keys are not unique")
check(work_order_ids.compact.uniq.length == work_orders.length, "clean work order keys are not unique")
check(work_orders.all? { |row| device_ids.include?(row["device_id"]) }, "clean data has orphan reference")
check(work_orders.count { |row| row["device_id"] == "D-01" } == 2, "one-to-many witness missing")
check(work_orders.count { |row| row["resolved_at"].nil? } == 1, "NULL count differs")
check(work_orders.count { |row| row["summary"] == "" } == 1, "empty string count differs")

d01_wide = wide.select { |row| row["device_id"] == "D-01" }
d01_areas = d01_wide.map { |row| row["area"] }.uniq.sort
check(d01_wide.length == 2, "wide table lacks repeated D-01 fact")
check(d01_areas == %w[A-1 A-9], "wide table lacks conflicting D-01 area")
check(answer.fetch("anomalies").include?("repeated device facts"), "repetition not diagnosed")
check(answer.fetch("anomalies").include?("conflicting area for D-01"), "conflict not diagnosed")
check(answer.fetch("anomalies").include?("a device without a work order cannot be represented in the wide table"),
      "insertion anomaly not diagnosed")

puts "wide-rows=#{wide.length}"
puts "d01-wide-copies=#{d01_wide.length}"
puts "d01-conflicting-areas=#{d01_areas.join("|")}"
puts "clean-device-rows=#{devices.length}"
puts "clean-work-order-rows=#{work_orders.length}"
puts "foreign-key=work_order.device_id->device.device_id"
puts "cardinality=device 1 -> 0..N work_order"
puts "null-vs-empty=PASS"
puts "relational-model-lab=PASS"
