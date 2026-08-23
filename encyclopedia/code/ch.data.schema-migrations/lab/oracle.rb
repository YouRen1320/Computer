# frozen_string_literal: true

require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "lab-failure=#{message}" unless condition
end

scenarios = JSON.parse(File.read(File.join(ROOT, "scenarios.json")))
check(scenarios.map { |item| item.fetch("id") } == %w[applied-checksum-edited one-step-not-null backfill-fails-midway], "fault ids")

checksum = scenarios.fetch(0)
check(checksum.fetch("history").fetch("checksum") != checksum.fetch("resolved").fetch("checksum"), "checksum changed")
check(checksum.fetch("expected") == "VALIDATE_FAIL:checksum-mismatch", "validate failure")
check(checksum.fetch("recovery").include?("restore-original"), "restore history")

not_null = scenarios.fetch(1)
check(not_null.fetch("existing_rows") == not_null.fetch("existing_nulls_for_new_column"), "old rows lack values")
check(not_null.fetch("sql").include?("NOT NULL"), "unsafe single step")
check(not_null.fetch("recovery") == %w[expand-nullable dual-write backfill validate contract], "expand contract")

backfill = scenarios.fetch(2)
check(backfill.fetch("priorities").any? { |value| !value.between?(1, 5) }, "invalid backfill input")
check(backfill.fetch("transaction") == "rolled-back", "transaction rollback")
check(!backfill.fetch("history_success"), "failed is not success")
check(backfill.fetch("persisted_priority_codes").all?(&:nil?), "no partial commit")
check(backfill.fetch("recovery").start_with?("V2_3__"), "forward fix")

puts "checksum-edit=VALIDATE_FAIL|history-success-preserved:PASS"
puts "one-step-not-null=MIGRATION_FAIL|repair=expand,dual-write,backfill,validate,contract"
puts "backfill-failure=ROLLED_BACK|history-success:false|partial-data:false"
puts "forward-fix=V2_3|verdict=PASS"
puts "schema-migrations-lab=PASS"
