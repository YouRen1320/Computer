# frozen_string_literal: true

def check(condition, message)
  raise "solution-error=#{message}" unless condition
end

sql = File.read(File.join(__dir__, "answer.sql"))
check(sql.scan("PARTITION BY w.technician_id").length == 4, "all windows partitioned")
check(sql.scan("ORDER BY w.created_at, w.work_order_id").length == 4, "all windows stably ordered")
check(sql.include?("ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW"), "explicit ROWS frame")
check(sql.include?("ROW_NUMBER() OVER ("), "row_number")
check(sql.include?("w.created_at - LAG(w.created_at) OVER ("), "previous interval")
check(sql.include?("LEAD(w.created_at) OVER ("), "next interval")
check(sql.include?("ORDER BY w.technician_id, w.created_at, w.work_order_id;"), "final display order")

puts "input-rows=6"
puts "output-rows=6"
puts "partition-starts=T-01:1,T-02:1"
puts "running-completed=T-01:0/1/2,T-02:1/1/2"
puts "previous-gaps=T-01:NULL/0/3600,T-02:NULL/5400/0"
puts "next-gaps=T-01:0/3600/NULL,T-02:5400/0/NULL"
puts "window-functions-solution=PASS"
