# frozen_string_literal: true

require "csv"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

sql = File.read(File.join(ROOT, "operations.sql"))
check(sql.start_with?("BEGIN;"), "transaction begins")
check(sql.rstrip.end_with?("ROLLBACK;"), "example rolls back")
check(sql.include?("device_id, serial_number, display_name, status"), "explicit insert columns")
check(sql.scan("AND version = 3").length == 2, "version predicates")
check(sql.scan("version = version + 1").length == 2, "version increments")
check(sql.scan("AND d.status = 'RETIRED'").length == 2, "delete status guards")
check(sql.scan("AND NOT EXISTS (").length == 2, "delete child guards")
check(sql.include?("ON CONFLICT (serial_number) DO UPDATE"), "upsert arbiter")
check(sql.scan("RETURNING").length == 6, "all writes return evidence")
set_clause = sql.match(/ON CONFLICT \(serial_number\) DO UPDATE\s+SET(.*?)RETURNING/m).to_a[1]
check(set_clause, "upsert SET clause")
check(!set_clause.match?(/\bdevice_id\s*=/), "immutable device id")
check(!set_clause.match?(/\bserial_number\s*=/), "immutable serial")

initial = CSV.read(File.join(ROOT, "devices.csv"), headers: true).map(&:to_h)
orders = CSV.read(File.join(ROOT, "work_orders.csv"), headers: true).map(&:to_h)
devices = initial.map(&:dup)

devices << {
  "device_id" => "D-04", "serial_number" => "SN-004", "display_name" => "North Valve",
  "status" => "ACTIVE", "version" => "1"
}
inserted = devices.last

update = devices.find { |row| row["device_id"] == "D-01" && row["version"] == "3" }
old_version = update["version"].to_i
update["display_name"] = "East Pump / inspected"
update["version"] = (old_version + 1).to_s
stale_count = devices.count { |row| row["device_id"] == "D-01" && row["version"] == "3" }

before_delete = devices.length
devices.reject! do |row|
  row["device_id"] == "D-03" && row["status"] == "RETIRED" &&
    orders.none? { |order| order["device_id"] == row["device_id"] }
end
deleted_count = before_delete - devices.length
protected_delete_count = devices.count do |row|
  row["device_id"] == "D-02" && row["status"] == "RETIRED" &&
    orders.none? { |order| order["device_id"] == row["device_id"] }
end

conflict = devices.find { |row| row["serial_number"] == "SN-002" }
conflict["display_name"] = "South Compressor / calibrated"
conflict["status"] = "MAINTENANCE"
conflict["version"] = (conflict["version"].to_i + 1).to_s

check(inserted["version"] == "1", "insert default version")
check(update["version"] == "4" && old_version == 3, "versioned update")
check(stale_count.zero?, "stale update")
check(deleted_count == 1 && protected_delete_count.zero?, "protected deletes")
check(conflict["device_id"] == "D-02" && conflict["version"] == "6", "upsert preserves identity")
check(devices.map { |row| row["device_id"] }.sort == %w[D-01 D-02 D-04], "transaction working set")
check(initial.map { |row| row["device_id"] } == %w[D-01 D-02 D-03], "rollback baseline")

puts "initial-rows=#{initial.length}"
puts "insert=D-04|affected=1|version=#{inserted["version"]}"
puts "version-update=D-01|affected=1|old=3|new=#{update["version"]}"
puts "stale-update=D-01|affected=#{stale_count}|returning=EMPTY"
puts "restricted-delete=D-03|affected=#{deleted_count}"
puts "protected-delete=D-02|affected=#{protected_delete_count}"
puts "upsert-conflict=SN-002|affected=1|device-id=#{conflict["device_id"]}|version=#{conflict["version"]}"
puts "working-set=#{devices.map { |row| row["device_id"] }.sort.join(",")}"
puts "rollback-restored=#{initial.map { |row| row["device_id"] }.join(",")}"
puts "dml-example=PASS"
