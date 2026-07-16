# frozen_string_literal: true

require "json"

def check(condition, message)
  raise "answer-error=#{message}" unless condition
end

answer = JSON.parse(File.read(ARGV.fetch(0)))
check(answer.fetch("sql_mode") == "prepared" && answer.fetch("parameter_slots") == 1, "untrusted value must use a parameter slot")
check(!answer.fetch("injection_structure_changed"), "injection input cannot change SQL structure")
check(answer.fetch("mapped_assigned_to").nil?, "SQL NULL must stay null")
check(answer.fetch("mapped_created_at").end_with?("+08:00"), "timestamptz must keep offset")
check(answer.fetch("empty_result") == "OPTIONAL_EMPTY", "empty result must be explicit")
check(answer.fetch("resource_closes").values.all? { |count| count == 1 }, "close all resources exactly once")
transaction = answer.fetch("transaction")
check(!transaction.fetch("auto_commit") && transaction.fetch("same_connection"), "multi-statement work needs one explicit transaction")
check(transaction.fetch("rollback_on_failure") && transaction.fetch("final_state_unchanged"), "failure must roll back")
check(answer.fetch("sqlstate_actions") == {"23505" => "CONFLICT", "40001" => "RETRY_WHOLE_TRANSACTION", "40P01" => "RETRY_WHOLE_TRANSACTION"}, "translate SQLState")
check(answer.fetch("preserve_cause"), "preserve SQLException cause")
puts "jdbc-answer=PASS"
