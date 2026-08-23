# frozen_string_literal: true

require "csv"
require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

wide = CSV.read(File.join(ROOT, "wide.csv"), headers: true).map(&:to_h)
model = JSON.parse(File.read(File.join(ROOT, "model.json")))
relations = model.fetch("relations")
check(relations.keys.sort == %w[device technician work_order], "three facts only")
check(relations.fetch("device").fetch("primary_key") == ["device_id"], "device key")
check(relations.fetch("device").fetch("alternate_keys") == [["serial_number"]], "serial candidate key")
check(relations.fetch("technician").fetch("primary_key") == ["technician_id"], "technician key")
check(relations.fetch("work_order").fetch("primary_key") == ["work_order_id"], "work order key")
check(model.fetch("foreign_keys") == [
  {"from" => "work_order.device_id", "to" => "device.device_id"},
  {"from" => "work_order.technician_id", "to" => "technician.technician_id"}
], "foreign keys")

devices = wide.map { |row| row.slice("device_id", "serial_number", "device_name") }.uniq
technicians = wide.map { |row| row.slice("technician_id", "technician_name", "technician_phone") }.uniq
orders = wide.map { |row| row.slice("work_order_id", "device_id", "technician_id", "summary", "order_status") }

check(devices.group_by { |row| row["device_id"] }.values.all? { |rows| rows.length == 1 }, "device dependency")
check(technicians.group_by { |row| row["technician_id"] }.values.all? { |rows| rows.length == 1 }, "technician dependency")
check(orders.map { |row| row["work_order_id"] }.uniq.length == orders.length, "work order key uniqueness")

device_by_id = devices.each_with_object({}) { |row, memo| memo[row["device_id"]] = row }
technician_by_id = technicians.each_with_object({}) { |row, memo| memo[row["technician_id"]] = row }
reconstructed = orders.map do |order|
  order.merge(device_by_id.fetch(order["device_id"])).merge(technician_by_id.fetch(order["technician_id"]))
end
columns = %w[
  work_order_id device_id serial_number device_name technician_id
  technician_name technician_phone summary order_status
]
canonical = ->(rows) { rows.map { |row| columns.map { |column| row[column] }.join("|") }.sort }
check(canonical.call(reconstructed) == canonical.call(wide), "lossless reconstruction")

puts "wide-rows=#{wide.length}"
puts "candidate-keys=wide:work_order_id,device:device_id/serial_number,technician:technician_id"
puts "decomposed-rows=device:#{devices.length},technician:#{technicians.length},work-order:#{orders.length}"
puts "device-dependency=device_id->serial_number/device_name:PASS"
puts "technician-dependency=technician_id->name/phone:PASS"
puts "work-order-dependency=work_order_id->device/technician/summary/status:PASS"
puts "reconstructed-rows=#{reconstructed.length}"
puts "lossless-join=PASS"
puts "normalization-example=PASS"
