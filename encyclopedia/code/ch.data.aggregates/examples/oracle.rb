# frozen_string_literal: true

require "bigdecimal"
require "csv"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

def label(category)
  category.nil? ? "<NULL>" : category
end

def numeric_sum(values)
  values.reduce(BigDecimal("0")) { |sum, value| sum + BigDecimal(value) }
end

sql = File.read(File.join(ROOT, "query.sql"))
check(sql.include?("COUNT(*) AS enabled_event_count"), "row count")
check(sql.include?("COUNT(DISTINCT s.device_id) AS enabled_device_count"), "distinct device count")
check(sql.include?("COUNT(s.duration_minutes) AS duration_sample_count"), "nonnull count")
check(sql.include?("SUM(s.duration_minutes) AS total_duration_minutes"), "sum")
check(sql.include?("ROUND(AVG(s.duration_minutes), 2) AS avg_duration_minutes"), "average")
check(sql.include?("WHERE s.enabled IS TRUE"), "row filter")
check(sql.include?("GROUP BY s.category"), "grouping")
check(sql.include?("HAVING COUNT(DISTINCT s.device_id) >= 2"), "group filter")
check(sql.include?("ORDER BY s.category ASC NULLS LAST"), "deterministic output")

rows = CSV.read(File.join(ROOT, "samples.csv"), headers: true)
enabled = rows.select { |row| row["enabled"] == "true" }
groups = enabled.group_by { |row| row["category"] }
ordered_keys = groups.keys.compact.sort + [nil]

stats = ordered_keys.map do |category|
  members = groups.fetch(category)
  durations = members.map { |row| row["duration_minutes"] }.compact
  sum = durations.empty? ? nil : numeric_sum(durations)
  {
    category: category,
    events: members.length,
    devices: members.map { |row| row["device_id"] }.compact.uniq.length,
    samples: durations.length,
    sum: sum,
    avg: sum.nil? ? nil : sum / durations.length
  }
end

check(rows.length == 12, "fixture row count")
check(enabled.length == 10, "enabled row count")
check(stats.sum { |item| item.fetch(:events) } == enabled.length, "group rows do not close")
check(stats.sum { |item| item.fetch(:samples) } == 6, "nonnull duration total")
result = stats.select { |item| item.fetch(:devices) >= 2 }
check(result.map { |item| label(item.fetch(:category)) } == %w[compressor pump sensor] + ["<NULL>"],
      "HAVING result")

puts "input-rows=#{rows.length}"
puts "enabled-rows=#{enabled.length}"
puts "all-group-event-sum=#{stats.sum { |item| item.fetch(:events) }}"
puts "all-group-duration-samples=#{stats.sum { |item| item.fetch(:samples) }}"
result.each do |item|
  sum = item.fetch(:sum)&.to_s("F") || "NULL"
  avg = item.fetch(:avg)&.round(2)&.to_s("F") || "NULL"
  puts "group=#{label(item.fetch(:category))}|events=#{item.fetch(:events)}|devices=#{item.fetch(:devices)}|duration-samples=#{item.fetch(:samples)}|sum=#{sum}|avg=#{avg}"
end
puts "having-rejected=valve"
puts "aggregates-example=PASS"
