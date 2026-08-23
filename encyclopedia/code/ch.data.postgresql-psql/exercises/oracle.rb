# frozen_string_literal: true

require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "plan-error=#{message}" unless condition
end

plan = JSON.parse(File.read(File.join(ROOT, "plan.json")))
script = File.read(File.join(ROOT, "scripts", "inspect-session.sql"))
command = plan.fetch("command")

check(command.include?("-X"), "missing -X")
check(command.include?("--no-password"), "missing --no-password")
check(command.include?("--set=ON_ERROR_STOP=1"), "missing ON_ERROR_STOP")
check(command.include?("--host=127.0.0.1"), "wrong host")
check(command.include?("--port=55432"), "wrong port")
check(command.include?("--username=factorycare_reader"), "wrong role")
check(command.include?("--dbname=factorycare_training"), "wrong database")
check(command.include?("--file=scripts/inspect-session.sql"), "wrong script")
check(plan.fetch("environment") == { "PGCONNECT_TIMEOUT" => "2" }, "timeout differs")
check(plan.fetch("transaction_owner") == "script", "transaction owner differs")
check(!command.include?("--single-transaction"), "transaction ownership overlaps")
check(script.include?("\\set ON_ERROR_STOP on"), "script stop-on-error missing")
check(script.include?("\\conninfo"), "connection evidence missing")
check(script.include?("current_database()"), "database probe missing")
check(script.include?("current_user"), "role probe missing")
check(script.include?("current_schema"), "schema probe missing")
check(script.include?("BEGIN TRANSACTION READ ONLY;"), "read-only transaction missing")
check(script.include?("COMMIT;"), "commit missing")
check(script !~ /\b(?:CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|TRUNCATE|GRANT|REVOKE)\b/i,
      "forbidden SQL present")

puts "psql-plan=PASS"
