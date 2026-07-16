# frozen_string_literal: true

require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "solution-error=#{message}" unless condition
end

plan = JSON.parse(File.read(File.join(ROOT, "plan.json")))
script = File.read(File.join(ROOT, "scripts", "inspect-session.sql"))
command = plan.fetch("command")

%w[-X --no-password --set=ON_ERROR_STOP=1 --host=127.0.0.1 --port=55432
   --username=factorycare_reader --dbname=factorycare_training
   --file=scripts/inspect-session.sql].each do |flag|
  check(command.include?(flag), "missing #{flag}")
end
check(plan.fetch("environment") == { "PGCONNECT_TIMEOUT" => "2" }, "timeout differs")
check(plan.fetch("transaction_owner") == "script", "transaction owner differs")
check(!command.include?("--single-transaction"), "transaction ownership overlaps")
%w[\\set \\conninfo current_database() current_user current_schema
   server_version_num].each { |fragment| check(script.include?(fragment), "missing #{fragment}") }
check(script.scan(/BEGIN TRANSACTION READ ONLY;/).length == 1, "read-only BEGIN differs")
check(script.scan(/COMMIT;/).length == 1, "COMMIT differs")
check(script !~ /\b(?:CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|TRUNCATE|GRANT|REVOKE)\b/i,
      "forbidden SQL present")

puts "PSQL PRIVATE SOLUTION PASS"
