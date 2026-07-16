# frozen_string_literal: true

def check(condition, message)
  raise "answer-error=#{message}" unless condition
end

sql = File.read(ARGV.fetch(0))
check(sql.scan("PARTITION BY w.technician_id").length >= 4,
      "every analytical window must partition by technician")
check(sql.scan("ORDER BY w.created_at, w.work_order_id").length >= 4,
      "every analytical window needs the work_order_id tiebreaker")
check(sql.include?("ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW"),
      "running completion needs an explicit ROWS frame")
check(sql.include?("ROW_NUMBER() OVER ("), "row_number result")
check(sql.include?("w.created_at - LAG(w.created_at) OVER ("), "previous interval")
check(sql.include?("LEAD(w.created_at) OVER ("), "next interval")
check(sql.include?("AS completed_so_far"), "running completion alias")
check(sql.include?("ORDER BY w.technician_id, w.created_at, w.work_order_id;"), "stable final display order")
puts "window-functions-answer=PASS"
