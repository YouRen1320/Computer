# frozen_string_literal: true

require "json"

def check(condition, message)
  raise "answer-error=#{message}" unless condition
end

answer = JSON.parse(File.read(ARGV.fetch(0)))
check(answer.fetch("applied_checksums") == answer.fetch("resolved_checksums"), "applied migration checksum was rewritten")
check(answer.fetch("stages") == %w[create expand backfill validate contract], "use expand backfill validate contract")
check(answer.fetch("empty_schema_fingerprint") == answer.fetch("upgrade_schema_fingerprint"), "empty and upgrade paths diverged")
check(answer.fetch("second_migrate_pending").zero?, "second migrate must be a no-op")
check(!answer.fetch("failed_history_success"), "failed migration cannot be marked success")
check(answer.fetch("recovery") == "forward-fix", "recover with forward fix")
check(!answer.fetch("rewrote_applied_history"), "do not rewrite applied history")
check(answer.fetch("contract_after_old_apps_gone"), "contract only after old applications leave")
puts "schema-migrations-answer=PASS"
