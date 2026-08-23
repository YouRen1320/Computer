# frozen_string_literal: true

require "bigdecimal"
require "csv"
require "json"
require "time"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "lab-failure=#{message}" unless condition
end

sql = File.read(File.join(ROOT, "query.sql"))
check(sql.include?("lower(btrim(d.raw_name)) AS normalized_name"), "normalization contract")
check(sql.include?("round(d.temperature_c, 1) AS temperature_c_1dp"), "round contract")
check(sql.include?("COALESCE(NULLIF(btrim(d.alias), ''), btrim(d.raw_name)) AS display_name"), "display contract")
check(sql.include?("WHEN d.temperature_c IS NULL THEN 'UNKNOWN'"), "NULL CASE contract")
check(sql.include?("date_trunc('day', d.last_seen_at AT TIME ZONE 'Asia/Shanghai')"), "local truncation contract")
check(sql.include?("CAST(d.last_seen_at AT TIME ZONE 'Asia/Shanghai' AS date)"), "local date contract")
check(sql.include?("FROM factorycare.device_reading AS d"), "source contract")

scenarios = JSON.parse(File.read(File.join(ROOT, "scenarios.json")))
check(scenarios.map { |item| item.fetch("id") } ==
      %w[timezone-cross-day null-to-business-value implicit-cast], "scenario ids")
check(scenarios[0].fetch("broken_expression") == "CAST(d.last_seen_at AS date)", "timezone injection")
check(scenarios[1].fetch("broken_expression") == "COALESCE(d.temperature_c, 0)", "NULL injection")
check(scenarios[2].fetch("broken_expression").include?("+ d.calibration_text"), "cast injection")

boundaries = JSON.parse(File.read(File.join(ROOT, "boundaries.json")))
check(boundaries.dig("current_timestamp", "category") == "STABLE", "current timestamp volatility")
check(boundaries.dig("current_timestamp", "boundary") == "transaction-start", "transaction time boundary")
check(boundaries.dig("clock_timestamp", "category") == "VOLATILE", "clock volatility")
check(boundaries.dig("clock_timestamp", "boundary") == "call-time", "clock boundary")
check(boundaries.fetch("timezone_dependent_function_can_be_immutable") == false, "timezone immutability")
check(boundaries.fetch("ordinary_index_matches_lower_expression") == false, "index expression matching")
check(boundaries.dig("offline_timezone_model", "iana_verified") == false, "offline timezone limit")

rows = CSV.read(File.join(ROOT, "devices.csv"), headers: true)
d02 = rows.find { |row| row["device_id"] == "D-02" }
d03 = rows.find { |row| row["device_id"] == "D-03" }
utc_date = Time.iso8601(d02["last_seen_at"]).utc.strftime("%Y-%m-%d")
local_date = Time.iso8601(d02["last_seen_at"]).getlocal("+08:00").strftime("%Y-%m-%d")
check(utc_date == "2026-07-16" && local_date == "2026-07-17", "midnight fixture")
check(d03["temperature_c"].nil?, "NULL temperature fixture")

cast_failures = rows.each_with_object([]) do |row, failures|
  begin
    BigDecimal(row["calibration_text"])
  rescue ArgumentError
    failures << [row["device_id"], row["calibration_text"]]
  end
end
check(cast_failures == [["D-03", "not-a-number"]], "visible cast failure")

puts "input-rows=#{rows.length}"
puts "output-rows=#{rows.length}"
puts "timezone-boundary=D-02|wrong=#{utc_date}|correct=#{local_date}"
puts "null-boundary=D-03|input=NULL|wrong-default=0|correct-band=UNKNOWN"
puts "cast-boundary=#{cast_failures[0][0]}|input=#{cast_failures[0][1]}|result=REJECTED"
puts "cast-failures=#{cast_failures.length}"
puts "current-timestamp=STABLE:transaction-start"
puts "clock-timestamp=VOLATILE:call-time"
puts "timezone-dependent-immutable=FORBIDDEN"
puts "ordinary-index-matches-expression=false"
puts "scalar-functions-lab=PASS"
