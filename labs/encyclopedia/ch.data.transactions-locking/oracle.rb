# frozen_string_literal: true

require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "lab-failure=#{message}" unless condition
end

schedule = JSON.parse(File.read(File.join(ROOT, "schedule.json")))

read = schedule.fetch("read_committed")
check(read.fetch("session_a_reads") == %w[OPEN IN_PROGRESS], "read committed observations")
check(read.fetch("session_b_commit_between_reads") && read.fetch("expected") == "NONREPEATABLE_READ", "statement snapshots")

wait = schedule.fetch("lock_wait")
check(wait.fetch("holder") != wait.fetch("waiter"), "holder and waiter")
check(!wait.fetch("waiter_granted") && wait.fetch("blocking_pids_observed"), "wait evidence")
check(wait.fetch("expected") == "WAIT_NOT_DEADLOCK", "wait classification")

lost = schedule.fetch("lost_update")
check(lost.fetch("reads").uniq == [2] && lost.fetch("writes").uniq == [3], "lost update schedule")
check(lost.fetch("observed") < lost.fetch("expected_without_loss"), "lost update evidence")
check(lost.fetch("repair") == "atomic-update-or-version-check", "lost update repair")

deadlock = schedule.fetch("deadlock")
broken = deadlock.fetch("broken_lock_orders")
check(broken.fetch("A") == broken.fetch("B").reverse, "opposite lock order")
check(deadlock.fetch("wait_edges").sort == [["A", "B"], ["B", "A"]], "wait cycle")
check(deadlock.fetch("sqlstate") == "40P01", "deadlock sqlstate")
repaired = deadlock.fetch("repaired_lock_orders")
check(repaired.fetch("A") == [42, 43] && repaired.fetch("A") == repaired.fetch("B"), "consistent lock order")
check(deadlock.fetch("retry_scope") == "whole-transaction" && deadlock.fetch("rollback_before_retry"), "safe retry boundary")
check(deadlock.fetch("attempts") == 2 && deadlock.fetch("final_history_count") == 1, "single side effect after retry")
check(deadlock.fetch("final_version_increments").values == [1, 1], "single version increments")
check(schedule.fetch("retriable_sqlstates").sort == %w[40001 40P01], "retriable sqlstates")

puts "read-committed=OPEN->IN_PROGRESS|anomaly=NONREPEATABLE_READ"
puts "lock-wait=holder:A|waiter:B|classification=WAIT_NOT_DEADLOCK"
puts "lost-update=observed:#{lost.fetch("observed")}|expected:#{lost.fetch("expected_without_loss")}|repair=PASS"
puts "deadlock=cycle:A-B-A|sqlstate:#{deadlock.fetch("sqlstate")}|order-repair=PASS"
puts "retry=whole-transaction|attempts:2|history:1|versions:1/1"
puts "transactions-locking-lab=PASS"
