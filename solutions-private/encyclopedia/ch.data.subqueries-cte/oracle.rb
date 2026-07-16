# frozen_string_literal: true

def check(condition, message)
  raise "solution-error=#{message}" unless condition
end

sql = File.read(File.join(__dir__, "answer.sql"))
check(sql.scan("w.device_id = d.device_id").length == 2, "correlated predicates")
check(!sql.include?("w.device_id = w.device_id"), "no self-comparison")
check(sql.scan("w.status IN ('OPEN', 'IN_PROGRESS')").length == 2, "unfinished status set")
check(sql.include?("WITH unfinished_devices AS ("), "first CTE")
check(sql.include?("category_counts AS ("), "second CTE")
check(sql.include?("FROM unfinished_devices\n  GROUP BY category"), "CTE data flow")
check(sql.include?("WHERE device_count >= 2"), "final threshold")
check(!sql.match?(/\bNOT IN\s*\(/), "nullable anti-join boundary")

puts "unfinished-devices=D-01,D-02,D-05"
puts "category-counts=compressor:1,pump:2"
puts "final-result=pump:2"
puts "subqueries-cte-solution=PASS"
