# frozen_string_literal: true

require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

plan = JSON.parse(File.read(File.join(ROOT, "plan.json")))
script = File.read(File.join(ROOT, "scripts", "inspect-session.sql"))
transcripts = JSON.parse(File.read(File.join(ROOT, "transcripts.json")))

expected_command = [
  "psql",
  "-X",
  "--no-password",
  "--set=ON_ERROR_STOP=1",
  "--host=127.0.0.1",
  "--port=55432",
  "--username=factorycare_reader",
  "--dbname=factorycare_training",
  "--file=scripts/inspect-session.sql"
]

check(plan.fetch("environment") == { "PGCONNECT_TIMEOUT" => "2" }, "connection timeout is not bounded")
check(plan.fetch("command") == expected_command, "command differs from explicit safe plan")
check(plan.fetch("transaction_owner") == "script", "transaction ownership is ambiguous")
check(!plan.fetch("command").include?("--single-transaction"), "runner overlaps script transaction")
check(plan.dig("expected_target", "mode") == "read-only", "target is not read-only")

serialized = JSON.generate(plan)
check(serialized !~ %r{postgres(?:ql)?://[^/@:]+:[^/@]+@}i, "password appears in URI")
check(!plan.key?("password"), "password field is forbidden")

required_fragments = [
  "\\set ON_ERROR_STOP on",
  "\\conninfo",
  "current_database()",
  "current_user",
  "current_schema",
  "server_version_num",
  "search_path",
  "\\dn",
  "\\dt factorycare.*",
  "BEGIN TRANSACTION READ ONLY;",
  "COMMIT;"
]
required_fragments.each { |fragment| check(script.include?(fragment), "script missing #{fragment}") }
check(script !~ /\b(?:CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|TRUNCATE|GRANT|REVOKE)\b/i,
      "destructive or out-of-scope SQL present")

expected_exits = {
  "success" => ["complete", 0],
  "missing-file" => ["client-file", 1],
  "wrong-port" => ["connect", 2],
  "syntax-error" => ["server-sql", 3]
}
transcripts.each do |transcript|
  expected = expected_exits.fetch(transcript.fetch("name"))
  check([transcript.fetch("stage"), transcript.fetch("exit")] == expected,
        "wrong stage/exit for #{transcript.fetch("name")}")
end
check(transcripts.find { |item| item["name"] == "syntax-error" }.fetch("sqlstate") == "42601",
      "syntax SQLSTATE differs")
check(transcripts.find { |item| item["name"] == "syntax-error" }.fetch("committed") == false,
      "failed transaction was marked committed")

puts "target=127.0.0.1:55432/factorycare_training"
puts "role=factorycare_reader"
puts "startup-files=disabled"
puts "password-prompt=disabled"
puts "stop-on-error=enabled"
puts "transaction-owner=script-read-only"
puts "exit-contract=0:complete|1:client|2:connect|3:script"
puts "psql-offline-example=PASS"
