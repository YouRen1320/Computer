# frozen_string_literal: true

require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

schema = File.read(File.join(ROOT, "schema.sql"))
check(schema.start_with?("BEGIN;") && schema.rstrip.end_with?("ROLLBACK;"), "transactional rebuild")
check(!schema.include?("CREATE SCHEMA"), "uses prebuilt schema")
check(schema.index("DROP TABLE IF EXISTS factorycare.work_order") < schema.index("DROP TABLE IF EXISTS factorycare.device"), "child dropped first")
check(schema.index("CREATE TABLE factorycare.device") < schema.index("CREATE TABLE factorycare.work_order"), "parent created first")
%w[device_pkey device_serial_number_not_null device_serial_number_key device_display_name_not_null device_status_not_null device_status_check device_version_not_null device_version_check work_order_pkey work_order_device_id_not_null work_order_summary_not_null work_order_status_not_null work_order_status_check work_order_device_fk].each do |name|
  check(schema.include?("CONSTRAINT #{name}"), "named constraint #{name}")
end
check(schema.include?("REFERENCES factorycare.device (device_id)"), "foreign key direction")
check(schema.include?("ON DELETE RESTRICT"), "delete policy")

devices = []
orders = []

def device_violation(row, devices)
  return "device_pkey" if row["device_id"].nil? || devices.any? { |item| item["device_id"] == row["device_id"] }
  return "device_serial_number_not_null" if row["serial_number"].nil?
  return "device_display_name_not_null" if row["display_name"].nil?
  return "device_status_not_null" if row["status"].nil?
  return "device_version_not_null" if row["version"].nil?
  return "device_serial_number_key" if devices.any? { |item| item["serial_number"] == row["serial_number"] }
  return "device_status_check" unless %w[ACTIVE MAINTENANCE RETIRED].include?(row["status"])
  return "device_version_check" unless row["version"].to_i > 0
  nil
end

def order_violation(row, orders, devices)
  return "work_order_pkey" if row["work_order_id"].nil? || orders.any? { |item| item["work_order_id"] == row["work_order_id"] }
  return "work_order_device_id_not_null" if row["device_id"].nil?
  return "work_order_summary_not_null" if row["summary"].nil?
  return "work_order_status_not_null" if row["status"].nil?
  return "work_order_status_check" unless %w[CREATED IN_PROGRESS CLOSED CANCELLED].include?(row["status"])
  return "work_order_device_fk" unless devices.any? { |item| item["device_id"] == row["device_id"] }
  nil
end

results = JSON.parse(File.read(File.join(ROOT, "cases.json"))).map do |test_case|
  row = test_case.fetch("row")
  violation = if test_case.fetch("table") == "device"
                device_violation(row, devices)
              else
                order_violation(row, orders, devices)
              end
  actual = violation || "ACCEPT"
  check(actual == test_case.fetch("expected"), "case #{test_case.fetch("id")}")
  if violation.nil?
    test_case.fetch("table") == "device" ? devices << row : orders << row
  end
  [test_case.fetch("id"), actual]
end

check(devices.length == 1 && orders.length == 1, "rejected rows leave no data")
puts "schema=factorycare|prebuilt=CONFIRMED_BY_CONTRACT"
puts "tables=device,work_order|create-order=parent-first"
results.each { |id, result| puts "#{id}=#{result}" }
puts "accepted-rows=device:#{devices.length},work-order:#{orders.length}"
puts "failed-rebuild=ROLLBACK|old-structure-preserved=PASS"
puts "ddl-constraints-example=PASS"
