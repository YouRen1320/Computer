# frozen_string_literal: true

require "json"

def check(condition, message)
  raise "lab-error=#{message}" unless condition
end

scenarios = JSON.parse(File.read(File.join(__dir__, "scenarios.json")))

wrong_parameter = scenarios.fetch("wrong_parameter")
check(wrong_parameter.fetch("outcome") == "BINDING_FAIL", "wrong parameter must fail during binding")
check(!wrong_parameter.fetch("database_called"), "binding failure must precede the database")
check(wrong_parameter.fetch("repair") == "filter.status", "parameter repair must match @Param path")
check(wrong_parameter.fetch("statement_id").end_with?("WorkOrderMapper.search"), "statement id missing")

wrong_column = scenarios.fetch("wrong_result_column")
check(wrong_column.fetch("returned_column") == wrong_column.fetch("repair"), "repair must use returned column label")
check(wrong_column.fetch("actual_assignee_id").nil? && wrong_column.fetch("expected_assignee_id") == 73, "wrong column must be observable")

dangling = scenarios.fetch("dangling_where")
check(dangling.fetch("final_sql").end_with?(" WHERE"), "fault must preserve dangling WHERE")
check(dangling.fetch("sqlstate") == "42601" && dangling.fetch("repair") == "<where>", "syntax failure repair is wrong")

substitution = scenarios.fetch("text_substitution")
check(substitution.fetch("template").include?('${sort}'), "fault must use text substitution")
check(substitution.fetch("structure_changed") && substitution.fetch("repair") == "enum-allowlist", "sort repair must freeze structure")

n_plus_one = scenarios.fetch("n_plus_one")
check(n_plus_one.fetch("nested_select_queries") == n_plus_one.fetch("rows") + 1, "N+1 count is not reproducible")
check(n_plus_one.fetch("repaired_queries") <= n_plus_one.fetch("maximum_queries"), "query budget still fails")

puts "wrong-param=BINDING_FAIL|statement=#{wrong_parameter.fetch("statement_id")}|database-called:false|repair=filter.status"
puts "wrong-column=MAPPING_FAIL|returned:assignee_id|mapped:assignee|repair=assignee_id"
puts "dangling-where=sqlstate:42601|repair:<where>"
puts "text-substitution=STRUCTURE_CHANGED|repair=enum-allowlist"
puts "n-plus-one=rows:#{n_plus_one.fetch("rows")}|before:#{n_plus_one.fetch("nested_select_queries")}|after:#{n_plus_one.fetch("repaired_queries")}"
puts "mybatis-core-lab=PASS"
