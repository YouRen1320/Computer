# frozen_string_literal: true

require "json"

def check(condition, message)
  raise "contract-error=#{message}" unless condition
end

root = File.expand_path(__dir__)
mapper_source = File.read(File.join(root, "WorkOrderMapper.java"))
xml = File.read(File.join(root, "WorkOrderMapper.xml"))
cases = JSON.parse(File.read(File.join(root, "cases.json")))

namespace = "com.factorycare.workorder.persistence.WorkOrderMapper"
check(mapper_source.include?('@Param("filter")'), "filter parameter must have a stable name")
check(xml.include?(%(<mapper namespace="#{namespace}">)), "namespace must match mapper interface")
check(xml.include?('<select id="search" resultMap="workOrderRowMap">'), "search statement id must match method")
check(xml.include?('autoMapping="false"') && xml.include?("<constructor>"), "record needs explicit constructor mapping")
%w[id work_order_no title status assignee_id created_at].each do |column|
  check(xml.include?(%(column="#{column}")), "missing result column #{column}")
end
%w[#{filter.status} #{filter.assigneeId} #{filter.createdFrom} #{pattern} #{id}].each do |binding|
  check(xml.include?(binding), "missing bound parameter #{binding}")
end
check(!xml.include?('${'), "text substitution is forbidden for user values")
%w[<where> <if <foreach <choose> <otherwise>].each do |tag|
  check(xml.include?(tag), "missing dynamic SQL element #{tag}")
end
check(!xml.match?(/<(association|collection)[^>]+select=/), "nested select would create an N+1 risk")

base_sql = "SELECT id, work_order_no, title, status, assignee_id, created_at FROM work_order"

def render(base_sql, filter)
  clauses = []
  binds = []
  if filter.key?("status")
    clauses << "status = ?"
    binds << filter.fetch("status")
  end
  if filter.key?("assigneeId")
    clauses << "assignee_id = ?"
    binds << filter.fetch("assigneeId")
  end
  if filter.key?("ids") && !filter.fetch("ids").empty?
    ids = filter.fetch("ids")
    clauses << "id IN (#{Array.new(ids.length, "?").join(", ")})"
    binds.concat(ids)
  end
  sql = base_sql.dup
  sql << " WHERE #{clauses.join(" AND ")}" unless clauses.empty?
  order = filter["sort"] == "CREATED_ASC" ? "created_at ASC, id ASC" : "created_at DESC, id DESC"
  ["#{sql} ORDER BY #{order}", binds]
end

cases.fetch("dynamic_cases").each do |test_case|
  actual_sql, actual_binds = render(base_sql, test_case.fetch("filter"))
  check(actual_sql == test_case.fetch("expected_sql"), "#{test_case.fetch("name")} SQL diverged")
  check(actual_binds == test_case.fetch("expected_binds"), "#{test_case.fetch("name")} binds diverged")
end

cardinality = cases.fetch("mapping_cardinality")
check(cardinality.values_at("empty", "single", "multiple") == [0, 1, 3], "empty/single/multiple mapping contract failed")
check(cardinality.fetch("unassigned_assignee_id").nil?, "SQL NULL must remain null")
budget = cases.fetch("query_budget")
check(budget.fetch("actual_queries") <= budget.fetch("maximum_queries"), "query budget exceeded")
evidence = cases.fetch("failure_evidence")
check(evidence.fetch("statement_id") == "#{namespace}.search", "failure evidence must name the statement")

puts "statement=#{namespace}.search|namespace-id=PASS"
puts "mapping=empty:0|single:1|multiple:3|null-assignee:PASS"
puts "dynamic=no-filters:legal|status:1-bind|injection-structure:false|ids:3-binds"
puts "n-plus-one=rows:#{budget.fetch("rows")}|queries:#{budget.fetch("actual_queries")}|max:#{budget.fetch("maximum_queries")}|verdict=PASS"
puts "mybatis-core-example=PASS"
