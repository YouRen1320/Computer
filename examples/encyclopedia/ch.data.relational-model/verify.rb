# frozen_string_literal: true

require "csv"
require "json"
require "set"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

def rows(name)
  CSV.read(File.join(ROOT, "data", "#{name}.csv"), headers: true)
end

def assert_unique(records, columns, label)
  keys = records.map { |row| columns.map { |column| row[column] } }
  check(keys.all? { |key| key.none? { |value| value.nil? || value.empty? } },
        "#{label} contains a blank key")
  check(keys.uniq.length == keys.length, "#{label} contains a duplicate key")
end

model = JSON.parse(File.read(File.join(ROOT, "data", "model.json")))
devices = rows("device")
work_orders = rows("work_order")

check(model.fetch("database") == "factorycare_training", "wrong database boundary")
check(model.fetch("schema") == "factorycare", "wrong schema boundary")
check(model.fetch("tables").keys == %w[device work_order], "unexpected table set")
check(devices.headers == model.dig("tables", "device", "columns"), "device columns differ")
check(work_orders.headers == model.dig("tables", "work_order", "columns"), "work_order columns differ")

assert_unique(devices, model.dig("tables", "device", "primary_key"), "device primary key")
assert_unique(devices, ["asset_code"], "device asset_code candidate key")
assert_unique(work_orders, model.dig("tables", "work_order", "primary_key"), "work_order primary key")

device_ids = devices.map { |row| row["device_id"] }.to_set
references = work_orders.map { |row| row["device_id"] }
check(references.all? { |device_id| device_ids.include?(device_id) }, "orphan device reference")

relationship = model.fetch("relationships").fetch(0)
check(relationship.fetch("from") == "work_order.device_id", "foreign key starts on wrong side")
check(relationship.fetch("to") == "device.device_id", "foreign key points to wrong key")
check(references.count("D-01") == 2, "sample does not prove one-to-many")

null_resolved = work_orders.count { |row| row["resolved_at"].nil? }
empty_summary = work_orders.count { |row| row["summary"] == "" }
check(null_resolved == 1, "NULL resolved_at count differs")
check(empty_summary == 1, "empty summary count differs")
check(work_orders.none? { |row| row["resolved_at"] == "" }, "NULL was collapsed to empty string")

puts "tables=#{model.fetch("tables").keys.join(",")}"
puts "device-rows=#{devices.length}"
puts "work-order-rows=#{work_orders.length}"
puts "primary-keys=PASS"
puts "foreign-keys=PASS"
puts "cardinality=#{relationship.fetch("cardinality")}"
puts "null-resolved-at=#{null_resolved}"
puts "empty-summary=#{empty_summary}"
puts "relational-model-example=PASS"
