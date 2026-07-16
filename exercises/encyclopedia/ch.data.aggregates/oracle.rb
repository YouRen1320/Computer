# frozen_string_literal: true

def check(condition, message)
  raise "answer-error=#{message}" unless condition
end

sql = File.read(ARGV.fetch(0))
check(!sql.match?(/s\.device_id\s+AS\s+device_id/), "ungrouped device_id must not be selected")
where_segment = sql[/WHERE(.*?)GROUP BY/m, 1].to_s
check(!where_segment.include?("COUNT("), "aggregate threshold belongs in HAVING")
check(sql.include?("COUNT(*) AS enabled_event_count"), "event count must use COUNT star")
check(sql.include?("COUNT(DISTINCT s.device_id) AS enabled_device_count"), "distinct device count")
check(sql.include?("COUNT(s.duration_minutes) AS duration_sample_count"), "duration count")
check(sql.include?("SUM(s.duration_minutes) AS total_duration_minutes"), "duration sum")
check(sql.include?("AVG(s.duration_minutes)"), "duration average")
check(sql.include?("WHERE s.enabled IS TRUE"), "enabled row filter")
check(sql.include?("GROUP BY s.category"), "category group")
check(sql.include?("HAVING COUNT(DISTINCT s.device_id) >= 2"), "group threshold")
puts "aggregates-answer=PASS"
