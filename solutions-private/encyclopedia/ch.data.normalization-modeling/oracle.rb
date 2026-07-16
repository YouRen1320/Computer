# frozen_string_literal: true

require "json"

def check(condition, message)
  raise "solution-error=#{message}" unless condition
end

answer = JSON.parse(File.read(File.join(__dir__, "answer.json")))
relations = answer.fetch("relations")
check(relations.keys.sort == %w[device technician work_order], "relations")
check(relations.fetch("device").fetch("attributes") == %w[device_id serial_number device_name], "device fact")
check(relations.fetch("technician").fetch("attributes") == %w[technician_id technician_name technician_phone], "technician fact")
check(relations.fetch("work_order").fetch("attributes") == %w[work_order_id device_id technician_id summary order_status], "work order fact")
check(relations.fetch("device").fetch("alternate_keys") == [["serial_number"]], "candidate key")
check(answer.fetch("foreign_keys") == [
  {"from" => "work_order.device_id", "to" => "device.device_id"},
  {"from" => "work_order.technician_id", "to" => "technician.technician_id"}
], "foreign keys")

puts "relations=device,technician,work_order"
puts "candidate-keys=device_id/serial_number,technician_id,work_order_id"
puts "foreign-keys=work_order.device_id,work_order.technician_id"
puts "reconstructed-rows=3|lossless=PASS"
puts "normalization-solution=PASS"
