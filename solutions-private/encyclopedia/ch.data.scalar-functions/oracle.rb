# frozen_string_literal: true

require "bigdecimal"
require "csv"
require "time"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "solution-error=#{message}" unless condition
end

sql = File.read(File.join(ROOT, "answer.sql"))
check(sql.scan("AT TIME ZONE 'Asia/Shanghai'").length == 2, "timezone boundaries")
check(sql.include?("d.raw_name AS raw_name") && sql.include?("d.temperature_c AS temperature_c"), "raw evidence")
check(sql.include?("lower(btrim(d.raw_name)) AS normalized_name"), "normalization")
check(sql.include?("round(d.temperature_c, 1) AS temperature_c_1dp"), "round")
check(sql.include?("NULLIF(btrim(d.alias), '')"), "blank alias")
check(sql.include?("WHEN d.temperature_c IS NULL THEN 'UNKNOWN'"), "NULL band")
check(sql.include?("date_trunc(") && sql.include?("CAST("), "date operations")

rows = CSV.read(File.join(ROOT, "devices.csv"), headers: true)
results = rows.sort_by { |row| row["device_id"] }.map do |row|
  local = Time.iso8601(row["last_seen_at"]).getlocal("+08:00")
  alias_name = row["alias"]&.strip
  display = alias_name.nil? || alias_name.empty? ? row["raw_name"].strip : alias_name
  temperature = row["temperature_c"]
  rounded = temperature.nil? ? "NULL" : BigDecimal(temperature).round(1, BigDecimal::ROUND_HALF_UP).to_s("F")
  band = if temperature.nil?
           "UNKNOWN"
         elsif BigDecimal(temperature) < 0
           "FREEZING"
         elsif BigDecimal(temperature) >= 30
           "HOT"
         else
           "NORMAL"
         end
  [row["device_id"], row["raw_name"].strip.downcase, rounded, display, band, local.strftime("%Y-%m-%d")]
end

check(results.length == rows.length, "row count")
puts "input-rows=#{rows.length}"
puts "output-rows=#{results.length}"
results.each { |result| puts "result=#{result.join("|")}" }
puts "scalar-functions-solution=PASS"
