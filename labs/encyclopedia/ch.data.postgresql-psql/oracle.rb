# frozen_string_literal: true

require "csv"
require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

plan = JSON.parse(File.read(File.join(ROOT, "plan.json")))
ok_script = File.read(File.join(ROOT, "scripts", "inspect-session.sql"))
broken_script = File.read(File.join(ROOT, "scripts", "broken-session.sql"))
copy_contract = JSON.parse(File.read(File.join(ROOT, "copy-contract.json")))
scenarios = JSON.parse(File.read(File.join(ROOT, "scenarios.json")))
fixture = CSV.read(File.join(ROOT, "fixtures", "device-import.csv"), headers: true)

command = plan.fetch("command")
%w[-X --no-password --set=ON_ERROR_STOP=1 --host=127.0.0.1 --port=55432
   --username=factorycare_reader --dbname=factorycare_training
   --file=scripts/inspect-session.sql].each do |flag|
  check(command.include?(flag), "missing command flag #{flag}")
end
check(plan.fetch("environment") == { "PGCONNECT_TIMEOUT" => "2" }, "connect timeout differs")
check(plan.fetch("transaction_owner") == "script", "transaction owner differs")
check(!command.include?("--single-transaction"), "double transaction ownership")
check(JSON.generate(plan) !~ %r{postgres(?:ql)?://[^/@:]+:[^/@]+@}i, "password URI present")

%w[\\conninfo current_database() current_user current_schema server_version_num search_path
   \\dn].each { |fragment| check(ok_script.include?(fragment), "ok script missing #{fragment}") }
check(ok_script.include?("\\dt factorycare.*"), "schema-qualified table observation missing")
check(ok_script.scan(/BEGIN TRANSACTION READ ONLY;/).length == 1, "read-only BEGIN count differs")
check(ok_script.scan(/COMMIT;/).length == 1, "COMMIT count differs")
check(ok_script !~ /\b(?:CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|TRUNCATE|GRANT|REVOKE)\b/i,
      "ok script contains forbidden SQL")
check(broken_script.include?("SELEC deliberate_syntax_error;"), "failure injection moved")
check(broken_script.index("BEGIN TRANSACTION READ ONLY;") < broken_script.index("SELEC deliberate_syntax_error;"),
      "failure is not inside transaction")
check(broken_script.index("SELEC deliberate_syntax_error;") < broken_script.index("COMMIT;"),
      "failure is not before commit")

check(copy_contract.fetch("client_command") == "\\copy", "copy must be client-side")
check(copy_contract.fetch("format") == "csv", "copy format differs")
check(copy_contract.fetch("header") == true, "CSV header contract missing")
check(copy_contract.fetch("null_marker") == "\\N", "NULL marker differs")
check(copy_contract.fetch("program_allowed") == false, "PROGRAM must be forbidden")
check(copy_contract.fetch("plans").map { |item| item.fetch("direction") } == %w[import export],
      "import/export plans differ")
copy_contract.fetch("plans").each do |item|
  check(item.fetch("columns").any?, "#{item.fetch("direction")} lacks explicit columns")
  check(item.fetch("client_file") !~ %r{\A/}, "#{item.fetch("direction")} uses absolute external path")
end
check(fixture.headers == %w[device_id asset_code name], "fixture columns differ")
check(fixture.length == 2, "fixture row count differs")

expected = {
  "ok" => ["complete", 0, true],
  "wrong-database" => ["connect", 2, false],
  "missing-script" => ["client-file", 1, false],
  "middle-syntax-error" => ["server-sql", 3, true]
}
scenarios.each do |scenario|
  actual = [scenario.fetch("stage"), scenario.fetch("exit"), scenario.fetch("connected")]
  check(actual == expected.fetch(scenario.fetch("name")), "scenario #{scenario.fetch("name")} differs")
end
middle = scenarios.find { |scenario| scenario["name"] == "middle-syntax-error" }
check(middle.fetch("sqlstate") == "42601", "syntax SQLSTATE differs")
check(middle.fetch("statements_before_failure") == 2, "statement boundary differs")
check(middle.fetch("committed") == false, "failed transaction marked committed")

puts "safe-target=factorycare_reader@127.0.0.1:55432/factorycare_training"
puts "ok=complete:0"
puts "wrong-database=connect:2:zero-statements"
puts "missing-script=client-file:1"
puts "middle-syntax-error=server-sql:3:sqlstate-42601:rollback"
puts "copy=client-side:import+export:null-\\N"
puts "psql-offline-lab=PASS"
