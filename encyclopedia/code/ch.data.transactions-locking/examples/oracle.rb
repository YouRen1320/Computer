# frozen_string_literal: true

require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

def execute(scenario)
  before = Marshal.load(Marshal.dump(scenario.fetch("before")))
  working = Marshal.load(Marshal.dump(before))
  command = scenario.fetch("command")
  working["status"] = command.fetch("to_status")
  working["assigned_to"] = command.fetch("assigned_to")
  working["version"] += 1

  duplicate = working.fetch("history_commands").include?(command.fetch("command_id"))
  error = duplicate ? "23505" : nil
  working.fetch("history_commands") << command.fetch("command_id") unless duplicate
  [error ? before : working, error]
end

scenarios = JSON.parse(File.read(File.join(ROOT, "scenarios.json")))
protocol = File.read(File.join(ROOT, "protocol.sql"))
check(scenarios.map { |item| item.fetch("id") } == %w[commit-assignment rollback-on-history-failure], "scenario ids")
check(scenarios.all? { |item| item.fetch("boundary") == "whole-transaction" }, "transaction boundary")

results = scenarios.map do |scenario|
  state, error = execute(scenario)
  check(state == scenario.fetch("expected"), "#{scenario.fetch("id")} state")
  check(error == scenario.fetch("inject_error"), "#{scenario.fetch("id")} error")
  [scenario.fetch("id"), state, error]
end

check(protocol.scan(/^BEGIN;/).length == 2, "two explicit transactions")
check(protocol.include?("COMMIT;") && protocol.include?("ROLLBACK;"), "commit and rollback")
check(protocol.include?("23505"), "failure evidence")

commit = results.fetch(0)
rollback = results.fetch(1)
puts "commit=status:#{commit[1].fetch("status")}|version:#{commit[1].fetch("version")}|history:#{commit[1].fetch("history_commands").length}"
puts "rollback=sqlstate:#{rollback[2]}|status:#{rollback[1].fetch("status")}|version:#{rollback[1].fetch("version")}|history-unchanged:PASS"
puts "transaction-boundary=whole-transaction|verdict=PASS"
puts "transactions-locking-example=PASS"
