# frozen_string_literal: true

require "json"

def check(condition, message)
  raise "answer-error=#{message}" unless condition
end

answer = JSON.parse(File.read(ARGV.fetch(0)))
orders = answer.fetch("lock_orders")
check(orders.fetch("A") == [42, 43] && orders.fetch("A") == orders.fetch("B"), "all transactions must lock in the same order")
check(answer.fetch("deadlock_sqlstate") == "40P01", "classify deadlock by SQLSTATE")
check(answer.fetch("retry_scope") == "whole-transaction", "retry the whole transaction")
check(answer.fetch("rollback_before_retry"), "rollback before retry")
check(answer.fetch("retriable_sqlstates").sort == %w[40001 40P01], "handle serialization and deadlock rollback")
check(answer.fetch("max_attempts").between?(2, 5), "bound retry attempts")
check(answer.fetch("command_id") == "C-100", "use the stable command id")
check(answer.fetch("attempts") == 2, "record both attempts")
check(answer.fetch("final_history_count") == 1, "retry must leave one history side effect")
check(answer.fetch("final_version_increments").values.all? { |value| value == 1 }, "each version increments once")
puts "transactions-locking-answer=PASS"
