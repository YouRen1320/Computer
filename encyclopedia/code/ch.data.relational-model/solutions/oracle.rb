# frozen_string_literal: true

require "json"

def check(condition, message)
  raise "solution-error=#{message}" unless condition
end

answer = JSON.parse(File.read(ARGV.fetch(0)))
check(answer.fetch("work_order_row_meaning") == "one maintenance request", "work order row meaning")
check(answer.fetch("device_primary_key") == ["device_id"], "device primary key")
check(answer.fetch("work_order_primary_key") == ["work_order_id"], "work order primary key")
check(answer.dig("foreign_key", "from") == "work_order.device_id", "foreign key source")
check(answer.dig("foreign_key", "to") == "device.device_id", "foreign key target")
check(answer.fetch("cardinality") == "device 1 -> 0..N work_order", "cardinality")
check(answer.fetch("resolved_at_null_means") == "unknown until resolved", "NULL contract")

puts "RELATIONAL PRIVATE SOLUTION PASS"
