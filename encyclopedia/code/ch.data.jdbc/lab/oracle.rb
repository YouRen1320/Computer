# frozen_string_literal: true

require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "lab-failure=#{message}" unless condition
end

scenarios = JSON.parse(File.read(File.join(ROOT, "scenarios.json")))
check(scenarios.map { |item| item.fetch("id") } == %w[string-concatenation resource-leak wrong-null-mapping missing-rollback empty-result], "fault ids")

injection = scenarios.fetch(0)
check(injection.fetch("input").include?("OR") && injection.fetch("structure_changed"), "injection evidence")
check(injection.fetch("returned_rows") > 1 && injection.fetch("repair").start_with?("PreparedStatement"), "injection repair")

leak = scenarios.fetch(1)
check(leak.fetch("closed").values.all?(&:zero?), "leak evidence")
check(leak.fetch("repair") == "nested-try-with-resources", "resource repair")

mapping = scenarios.fetch(2)
check(mapping.fetch("sql_value").nil? && mapping.fetch("actual_java_value") == 0, "NULL collapsed to primitive")
check(mapping.fetch("expected_java_value").nil? && mapping.fetch("repair").include?("wasNull"), "NULL repair")

transaction = scenarios.fetch(3)
check(!transaction.fetch("auto_commit") && transaction.fetch("history_sqlstate") == "23505", "transaction failure")
check(!transaction.fetch("rollback_called") && transaction.fetch("close_with_active_transaction") == "implementation-defined", "missing rollback")
check(transaction.fetch("repair") == "rollback-preserve-primary-exception", "rollback repair")

empty = scenarios.fetch(4)
check(empty.fetch("result_rows").zero? && empty.fetch("broken_return") == "null", "empty result bug")
check(empty.fetch("expected_return") == "OPTIONAL_EMPTY", "empty result repair")

puts "string-concat=INJECTION|rows:#{injection.fetch("returned_rows")}|repair=PreparedStatement"
puts "resource-leak=close-counts:0/0/0|repair=try-with-resources"
puts "null-mapping=SQL_NULL->0|repair=nullable-mapping"
puts "missing-rollback=sqlstate:23505|close-active:implementation-defined|repair=PASS"
puts "empty-result=null->OPTIONAL_EMPTY|repair=PASS"
puts "jdbc-lab=PASS"
