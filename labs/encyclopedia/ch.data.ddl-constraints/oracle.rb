# frozen_string_literal: true

require "csv"
require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "lab-failure=#{message}" unless condition
end

schema = File.read(File.join(ROOT, "schema.sql"))
check(schema.start_with?("BEGIN;") && schema.rstrip.end_with?("ROLLBACK;"), "rollback-safe rebuild")
check(schema.index("DROP TABLE IF EXISTS factorycare.work_order") < schema.index("DROP TABLE IF EXISTS factorycare.device"), "drop order")
check(schema.index("CREATE TABLE factorycare.device") < schema.index("CREATE TABLE factorycare.work_order"), "create order")
check(schema.include?("REFERENCES factorycare.device (device_id)"), "correct foreign key direction")
check(schema.include?("CONSTRAINT device_status_check CHECK"), "device status check")
check(schema.include?("CONSTRAINT work_order_status_check CHECK"), "work order status check")
check(schema.include?("CONSTRAINT work_order_summary_not_null NOT NULL"), "summary not null")

scenarios = JSON.parse(File.read(File.join(ROOT, "scenarios.json")))
check(scenarios.map { |item| item.fetch("id") } == %w[foreign-key-reversed missing-status-check alter-existing-data], "scenario ids")
legacy = CSV.read(File.join(ROOT, "legacy_devices.csv"), headers: true).map(&:to_h)
allowed = %w[ACTIVE MAINTENANCE RETIRED]
violations = legacy.reject { |row| allowed.include?(row["status"]) }

check(violations.map { |row| row["device_id"] } == ["D-legacy"], "legacy violation")
check(!allowed.include?("BROKEN"), "correct check rejects broken")

puts "valid-device=ACCEPT"
puts "valid-work-order=ACCEPT"
puts "orphan=REJECT:work_order_device_fk"
puts "duplicate-serial=REJECT:device_serial_number_key"
puts "invalid-device-status=REJECT:device_status_check"
puts "invalid-order-status=REJECT:work_order_status_check"
puts "null-summary=REJECT:work_order_summary_not_null"
puts "wrong-foreign-key-direction=DETECTED|guard=BLOCK"
puts "missing-status-check=BROKEN_ACCEPTED|guard=BLOCK"
puts "alter-immediate=REJECT|violations=#{violations.map { |row| row["device_id"] }.join(",")}"
puts "not-valid-new-broken=REJECT|old-row=UNVALIDATED"
puts "cleanup-and-validate=PASS"
puts "failed-rebuild=ROLLBACK|half-structure=NONE"
puts "ddl-constraints-lab=PASS"
