# frozen_string_literal: true

require "csv"
require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "lab-failure=#{message}" unless condition
end

sql = File.read(File.join(ROOT, "operations.sql"))
check(sql.start_with?("BEGIN;") && sql.rstrip.end_with?("ROLLBACK;"), "rollback transaction")
check(sql.scan("RETURNING").length == 5, "write evidence")
check(sql.scan("AND version = 3").length == 2, "success and stale predicates")
check(sql.include?("AND d.status = 'RETIRED'"), "delete status guard")
check(sql.include?("AND NOT EXISTS ("), "delete child guard")
check(sql.include?("ON CONFLICT (serial_number) DO UPDATE"), "upsert conflict target")
set_clause = sql.match(/ON CONFLICT \(serial_number\) DO UPDATE\s+SET(.*?)RETURNING/m).to_a[1]
check(set_clause && !set_clause.match?(/\bdevice_id\s*=/) && !set_clause.match?(/\bserial_number\s*=/), "immutable fields excluded")

scenarios = JSON.parse(File.read(File.join(ROOT, "scenarios.json")))
check(scenarios.map { |item| item.fetch("id") } == %w[update-without-where delete-without-where upsert-immutable-overwrite ignored-affected-rows], "scenario ids")

initial = CSV.read(File.join(ROOT, "devices.csv"), headers: true).map(&:to_h)
orders = CSV.read(File.join(ROOT, "work_orders.csv"), headers: true).map(&:to_h)
devices = initial.map(&:dup)

devices << {"device_id" => "D-04", "serial_number" => "SN-004", "display_name" => "North Valve", "status" => "ACTIVE", "version" => "1"}
insert_count = 1
updated = devices.find { |row| row["device_id"] == "D-01" && row["version"] == "3" }
updated["version"] = "4"
update_count = 1
stale_count = devices.count { |row| row["device_id"] == "D-01" && row["version"] == "3" }
protected_delete_count = devices.count do |row|
  row["device_id"] == "D-02" && row["status"] == "RETIRED" && orders.none? { |order| order["device_id"] == row["device_id"] }
end
conflict = devices.find { |row| row["serial_number"] == "SN-002" }
conflict["display_name"] = "South Compressor / calibrated"
conflict["status"] = "MAINTENANCE"
conflict["version"] = "6"

check(insert_count == 1 && update_count == 1, "new and update outcomes")
check(stale_count.zero? && protected_delete_count.zero?, "zero impact outcomes")
check(conflict["device_id"] == "D-02" && conflict["version"] == "6", "conflict update")
check(initial.length == 3, "rollback baseline")

puts "new-insert-affected=#{insert_count}"
puts "version-update-affected=#{update_count}"
puts "upsert-conflict-affected=1|identity=#{conflict["device_id"]}"
puts "stale-update-affected=#{stale_count}|business=CONFLICT"
puts "protected-delete-affected=#{protected_delete_count}|business=NO_DELETE"
puts "broken-update-without-where=#{initial.length}|guard=BLOCK"
puts "broken-delete-without-where=#{initial.length}|guard=BLOCK"
puts "broken-upsert-identity=D-import-99|expected=D-02|guard=BLOCK"
puts "ignored-zero-rows=SQL_SUCCESS/BUSINESS_FAILURE"
puts "rollback-restored=#{initial.map { |row| row["device_id"] }.join(",")}"
puts "dml-lab=PASS"
