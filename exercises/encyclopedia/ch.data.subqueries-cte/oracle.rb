# frozen_string_literal: true

def check(condition, message)
  raise "answer-error=#{message}" unless condition
end

sql = File.read(ARGV.fetch(0))
check(sql.scan("w.device_id = d.device_id").length >= 2,
      "correlated predicate must reference outer d.device_id")
check(!sql.include?("w.device_id = w.device_id"), "self-comparison must be removed")
check(sql.scan("w.status IN ('OPEN', 'IN_PROGRESS')").length >= 2,
      "unfinished status set must be OPEN and IN_PROGRESS")
check(sql.include?("WITH unfinished_devices AS ("), "first CTE must be named unfinished_devices")
check(sql.include?("category_counts AS ("), "second CTE must be named category_counts")
check(sql.include?("FROM unfinished_devices\n  GROUP BY category"), "aggregate must consume first CTE")
check(sql.include?("WHERE device_count >= 2"), "final threshold must consume aggregate alias")
check(!sql.match?(/\bNOT IN\s*\(/), "NOT IN is unsafe for nullable exclusion sets")
puts "subqueries-cte-answer=PASS"
