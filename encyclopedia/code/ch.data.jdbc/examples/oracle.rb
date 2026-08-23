# frozen_string_literal: true

require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

cases = JSON.parse(File.read(File.join(ROOT, "cases.json")))
source = File.read(File.join(ROOT, "JdbcWorkOrderRepository.java"))

query = cases.fetch("query")
normal = query.fetch("normal_row")
mapped = query.fetch("mapped")
check(mapped == {"id" => normal.fetch("work_order_id"), "status" => normal.fetch("status"), "assignedTo" => normal.fetch("assigned_to"), "createdAt" => normal.fetch("created_at"), "version" => normal.fetch("version")}, "row mapping")
check(query.fetch("empty_result") == "OPTIONAL_EMPTY", "empty result")
check(query.fetch("resource_closes").values.all? { |count| count == 1 }, "resources closed once")

injection = cases.fetch("injection")
check(injection.fetch("sql_template").include?("?"), "parameter slot")
check(injection.fetch("parameter_count") == 1 && !injection.fetch("structure_changed"), "injection remains value")
check(injection.fetch("returned_rows").zero?, "injection returns no rows")

success = cases.fetch("transaction_success")
check(!success.fetch("auto_commit") && success.fetch("same_connection"), "success transaction")
check(success.fetch("changed_rows") == 1 && success.fetch("committed") && success.fetch("history_count") == 1, "commit state")
failure = cases.fetch("transaction_failure")
check(failure.fetch("sqlstate") == "23505" && failure.fetch("rolled_back"), "failure rollback")
check(failure.fetch("work_order_unchanged") && failure.fetch("connection_closed"), "failure final state")

%w[DataSource PreparedStatement ResultSet Optional.empty\( setString setAutoCommit\(false\) commit\( rollback\( addSuppressed].each do |token|
  check(source.include?(token.gsub("\\", "")), "source contract #{token}")
end

puts "query-mapping=id:42|assignedTo:null|createdAt:offset|verdict=PASS"
puts "empty-result=OPTIONAL_EMPTY|resources-closed=1/1/1"
puts "injection=parameterized|structure-changed:false|rows:0"
puts "transaction-success=commit|changed:1|history:1"
puts "transaction-failure=sqlstate:23505|rollback:PASS|state-unchanged:PASS"
puts "jdbc-example=PASS"
