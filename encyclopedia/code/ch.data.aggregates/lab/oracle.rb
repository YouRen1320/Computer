# frozen_string_literal: true

require "csv"
require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "lab-failure=#{message}" unless condition
end

sql = File.read(File.join(ROOT, "query.sql"))
check(sql.include?("COUNT(*) AS enabled_event_count"), "COUNT star")
check(sql.include?("COUNT(DISTINCT s.device_id)"), "distinct device")
check(sql.include?("COUNT(s.duration_minutes) AS duration_sample_count"), "nonnull count")
check(sql.index("WHERE s.enabled IS TRUE") < sql.index("GROUP BY s.category"), "WHERE stage")
check(sql.index("GROUP BY s.category") < sql.index("HAVING COUNT(DISTINCT s.device_id) >= 2"), "HAVING stage")

scenarios = JSON.parse(File.read(File.join(ROOT, "scenarios.json")))
check(scenarios.map { |item| item.fetch("id") } == %w[ungrouped-column aggregate-in-where count-null],
      "scenario ids")

rows = CSV.read(File.join(ROOT, "samples.csv"), headers: true)
enabled = rows.select { |row| row["enabled"] == "true" }
groups = enabled.group_by { |row| row["category"] }
event_counts = groups.transform_values(&:length)
duration_counts = groups.transform_values { |members| members.count { |row| !row["duration_minutes"].nil? } }
device_counts = groups.transform_values { |members| members.map { |row| row["device_id"] }.uniq.length }

check(event_counts.values.sum == enabled.length, "group closure")
check(duration_counts.values.sum == 6, "duration closure")
check(event_counts["sensor"] == 2 && duration_counts["sensor"] == 0, "sensor NULL boundary")
check(event_counts["pump"] == 3 && device_counts["pump"] == 2, "distinct device boundary")
check(event_counts[nil] == 2, "NULL grouping key")
passed = device_counts.select { |_category, count| count >= 2 }.keys
rejected = device_counts.select { |_category, count| count < 2 }.keys
check(passed.length == 4 && rejected == ["valve"], "HAVING threshold")

puts "enabled-total=#{enabled.length}"
puts "group-event-sum=#{event_counts.values.sum}"
puts "group-duration-sum=#{duration_counts.values.sum}"
puts "sensor=events:#{event_counts["sensor"]},duration-count:#{duration_counts["sensor"]},avg:NULL"
puts "pump=events:#{event_counts["pump"]},devices:#{device_counts["pump"]}"
puts "null-category=events:#{event_counts[nil]},devices:#{device_counts[nil]}"
puts "having-pass=compressor,pump,sensor,<NULL>"
puts "having-reject=valve"
puts "empty-without-group=count:0,avg:NULL,rows:1"
puts "empty-with-group=rows:0"
puts "injections=ungrouped-column,aggregate-in-where,count-null"
puts "aggregates-lab=PASS"
