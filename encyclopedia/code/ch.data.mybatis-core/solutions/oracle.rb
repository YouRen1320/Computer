# frozen_string_literal: true

require "json"

def check(condition, message)
  raise "answer-error=#{message}" unless condition
end

answer = JSON.parse(File.read(ARGV.fetch(0)))
statement_id = "com.factorycare.workorder.persistence.WorkOrderMapper.search"

check(answer.fetch("value_binding") == '#{}' && !answer.fetch("contains_text_substitution"), 'values must use #{} bound parameters')
check(answer.fetch("statement_id") == statement_id, "use the fully qualified statement id")
check(answer.fetch("namespace_matches_interface") && answer.fetch("statement_id_matches_method"), "namespace and id must match the mapper method")
required_paths = %w[filter.status filter.assigneeId filter.createdFrom pattern id]
check(answer.fetch("bound_paths") == required_paths, "bound parameter paths are incomplete")
check(!answer.fetch("final_sql_structure_changed_by_injection"), "injection input cannot change SQL structure")
check(answer.fetch("dynamic_root") == "where" && answer.fetch("all_conditions_absent") == "legal-no-where", "optional conditions must produce legal SQL")
check(answer.fetch("empty_ids_policy") == "return-empty-before-mapper", "empty ids must not become an unfiltered query")

expected_mapping = {
  "id" => "id",
  "number" => "work_order_no",
  "status" => "status",
  "assigneeId" => "assignee_id",
  "createdAt" => "created_at"
}
check(answer.fetch("result_mapping") == expected_mapping, "record result columns are wrong")
cardinality = answer.fetch("cardinality")
check(cardinality.values_at("empty", "single", "multiple") == [0, 1, 3], "empty/single/multiple results are wrong")
check(cardinality.fetch("unassigned_assignee_id").nil?, "SQL NULL must stay null")
check(answer.fetch("sort_policy") == "enum-fixed-branches", "sorting needs a fixed allowlist")

budget = answer.fetch("query_budget")
check(budget.fetch("actual_queries") <= budget.fetch("maximum_queries"), "N+1 query budget exceeded")
check(budget.fetch("rows") == 50, "query-budget fixture changed")
evidence = answer.fetch("failure_evidence")
check(evidence.fetch("statement_id_present") && evidence.fetch("same_input_rerun") == "PASS", "failure evidence and rerun are required")
check(answer.fetch("transaction_ownership") == "service-boundary" && !answer.fetch("mapper_has_transaction_annotation"), "transaction proxy is outside this mapper chapter")

puts "mybatis-core-answer=PASS"
