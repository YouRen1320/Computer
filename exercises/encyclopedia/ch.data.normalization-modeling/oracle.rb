# frozen_string_literal: true

require "json"

def check(condition, message)
  raise "answer-error=#{message}" unless condition
end

answer = JSON.parse(File.read(ARGV.fetch(0)))
relations = answer.fetch("relations")
check(relations.key?("technician"), "technician fact needs its own relation")
check(relations.keys.sort == %w[device technician work_order], "do not invent or omit facts")
check(relations.fetch("device").fetch("attributes") == %w[device_id serial_number device_name], "device attributes")
check(relations.fetch("technician").fetch("attributes") == %w[technician_id technician_name technician_phone], "technician attributes")
check(relations.fetch("work_order").fetch("attributes") == %w[work_order_id device_id technician_id summary order_status], "work order keeps assignment")
check(relations.fetch("device").fetch("alternate_keys") == [["serial_number"]], "serial number candidate key")
check(answer.fetch("foreign_keys").length == 2, "two foreign keys")
puts "normalization-answer=PASS"
