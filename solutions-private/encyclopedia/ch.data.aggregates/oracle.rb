# frozen_string_literal: true

def check(condition, message)
  raise "solution-error=#{message}" unless condition
end

sql = File.read(File.join(__dir__, "answer.sql"))
check(sql.include?("COUNT(*) AS enabled_event_count"), "event count")
check(sql.include?("COUNT(DISTINCT s.device_id) AS enabled_device_count"), "device count")
check(sql.include?("COUNT(s.duration_minutes) AS duration_sample_count"), "duration count")
check(sql.include?("SUM(s.duration_minutes)"), "sum")
check(sql.include?("ROUND(AVG(s.duration_minutes), 2)"), "average")
check(sql.include?("WHERE s.enabled IS TRUE"), "WHERE")
check(sql.include?("GROUP BY s.category"), "GROUP BY")
check(sql.include?("HAVING COUNT(DISTINCT s.device_id) >= 2"), "HAVING")
check(sql.include?("NULLS LAST"), "NULL ordering")

puts "result-groups=compressor,pump,sensor,<NULL>"
puts "event-counts=2,3,2,2"
puts "device-counts=2,2,2,2"
puts "duration-counts=2,2,0,1"
puts "having-rejected=valve"
puts "aggregates-solution=PASS"
