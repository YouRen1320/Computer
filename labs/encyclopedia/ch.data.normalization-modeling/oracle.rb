# frozen_string_literal: true

require "csv"
require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "lab-failure=#{message}" unless condition
end

wide = CSV.read(File.join(ROOT, "wide.csv"), headers: true).map(&:to_h)
model = JSON.parse(File.read(File.join(ROOT, "model.json")))
scenarios = JSON.parse(File.read(File.join(ROOT, "scenarios.json")))
check(scenarios.map { |item| item.fetch("id") } == %w[update-anomaly insert-anomaly delete-anomaly wrong-functional-dependency lossy-decomposition denormalize-without-evidence], "scenario ids")
check(model.fetch("relations").keys.sort == %w[device technician work_order], "model relations")

broken_update = wide.map(&:dup)
broken_update.find { |row| row["work_order_id"] == "W-01" }["device_name"] = "East Pump A"
d01_names = broken_update.select { |row| row["device_id"] == "D-01" }.map { |row| row["device_name"] }.uniq.sort

after_delete = wide.reject { |row| row["work_order_id"] == "W-03" }
d02_survives = after_delete.any? { |row| row["device_id"] == "D-02" }
wrong_fd_values = wide.select { |row| row["device_id"] == "D-01" }.map { |row| row["technician_id"] }.uniq.sort

order_device = wide.map { |row| [row["work_order_id"], row["device_id"]] }.uniq
device_technician = wide.map { |row| [row["device_id"], row["technician_id"]] }.uniq
lossy = order_device.flat_map do |work_order_id, device_id|
  device_technician.select { |candidate_device, _technician| candidate_device == device_id }.map do |_candidate_device, technician_id|
    [work_order_id, device_id, technician_id]
  end
end
original_pairs = wide.map { |row| [row["work_order_id"], row["device_id"], row["technician_id"]] }
spurious = lossy - original_pairs

devices = wide.map { |row| row.slice("device_id", "serial_number", "device_name") }.uniq
technicians = wide.map { |row| row.slice("technician_id", "technician_name", "technician_phone") }.uniq
orders = wide.map { |row| row.slice("work_order_id", "device_id", "technician_id", "summary", "order_status") }
device_by_id = devices.each_with_object({}) { |row, memo| memo[row["device_id"]] = row }
technician_by_id = technicians.each_with_object({}) { |row, memo| memo[row["technician_id"]] = row }
reconstructed = orders.map { |row| row.merge(device_by_id.fetch(row["device_id"])).merge(technician_by_id.fetch(row["technician_id"])) }

check(d01_names == ["East Pump", "East Pump A"], "update anomaly")
check(!d02_survives, "delete anomaly")
check(wrong_fd_values == %w[T-01 T-02], "wrong dependency counterexample")
check(lossy.length == 5 && spurious == [["W-01", "D-01", "T-02"], ["W-02", "D-01", "T-01"]], "spurious rows")
check(reconstructed.length == wide.length, "normalized row count")
check(reconstructed.all? { |row| wide.any? { |source| source.to_h == row } }, "normalized exact reconstruction")

puts "update-anomaly=D-01:names=#{d01_names.join("/")}"
puts "insert-anomaly=T-03:no-truthful-work-order-key"
puts "delete-anomaly=remove-W-03|D-02-facts-lost=#{!d02_survives}"
puts "wrong-fd=device_id->technician_id|D-01=#{wrong_fd_values.join("/")}|verdict=FALSE"
puts "lossy-join-rows=#{lossy.length}|original=#{original_pairs.length}|spurious=#{spurious.map { |row| "#{row[0]}-#{row[2]}" }.join(",")}"
puts "normalized-reconstruction=#{reconstructed.length}|lossless=PASS"
puts "denormalization-without-evidence=REJECT"
puts "normalization-lab=PASS"
