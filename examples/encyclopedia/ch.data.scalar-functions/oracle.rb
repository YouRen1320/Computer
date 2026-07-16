# frozen_string_literal: true

require "bigdecimal"
require "csv"
require "json"
require "time"

ROOT = File.expand_path(__dir__)
OPERATION_NAMES = %w[normalize round display band localize-truncate cast-date].freeze

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

def rounded_numeric(value)
  return "NULL" if value.nil?

  BigDecimal(value).round(1, BigDecimal::ROUND_HALF_UP).to_s("F")
end

def display_name(row)
  alias_name = row["alias"]&.strip
  alias_name.nil? || alias_name.empty? ? row["raw_name"].strip : alias_name
end

def temperature_band(value)
  return "UNKNOWN" if value.nil?

  numeric = BigDecimal(value)
  return "FREEZING" if numeric < 0
  return "HOT" if numeric >= 30

  "NORMAL"
end

sql = File.read(File.join(ROOT, "query.sql"))
flat = sql.gsub(/\s+/, " ")
check(sql.include?("lower(btrim(d.raw_name)) AS normalized_name"), "text normalization")
check(sql.include?("round(d.temperature_c, 1) AS temperature_c_1dp"), "numeric rounding")
check(sql.include?("COALESCE(") && sql.include?("NULLIF(btrim(d.alias), '')"), "NULL display rule")
check(sql.include?("WHEN d.temperature_c IS NULL THEN 'UNKNOWN'"), "NULL CASE branch")
check(sql.include?("WHEN d.temperature_c < NUMERIC '0' THEN 'FREEZING'"), "freezing branch")
check(sql.include?("WHEN d.temperature_c >= NUMERIC '30' THEN 'HOT'"), "hot branch")
check(flat.include?("date_trunc( 'day', d.last_seen_at AT TIME ZONE 'Asia/Shanghai' ) AS local_day_start"),
      "timezone before date_trunc")
check(flat.include?("CAST( d.last_seen_at AT TIME ZONE 'Asia/Shanghai' AS date ) AS local_date"),
      "timezone before date cast")
check(sql.include?("FROM factorycare.device_reading AS d"), "schema-qualified source")

operations = JSON.parse(File.read(File.join(ROOT, "operations.json")))
check(operations.map { |item| item.fetch("output") } ==
      %w[normalized_name temperature_c_1dp display_name temperature_band local_day_start local_date],
      "operation report fields")

boundaries = JSON.parse(File.read(File.join(ROOT, "boundaries.json")))
check(boundaries.fetch("volatility").map { |item| [item.fetch("expression"), item.fetch("category")] } ==
      [["CURRENT_TIMESTAMP", "STABLE"], ["statement_timestamp()", "STABLE"], ["clock_timestamp()", "VOLATILE"]],
      "volatility contract")
check(boundaries.dig("timezone", "offline_fixed_offset") == "+08:00", "offline offset")
check(boundaries.dig("timezone", "iana_rules_verified") == false, "IANA boundary must stay unverified")
check(boundaries.dig("index_expression", "ordinary_raw_name_index_matches") == false, "index match boundary")
check(boundaries.dig("index_expression", "functions_must_be_immutable") == true, "index volatility boundary")

rows = CSV.read(File.join(ROOT, "devices.csv"), headers: true)
records = rows.sort_by { |row| row["device_id"] }.map do |row|
  local = Time.iso8601(row["last_seen_at"]).getlocal("+08:00")
  {
    id: row["device_id"],
    input_name: row["raw_name"].inspect,
    input_alias: row["alias"].nil? ? "NULL" : row["alias"].inspect,
    input_temperature: row["temperature_c"].nil? ? "NULL" : row["temperature_c"].inspect,
    input_last_seen: row["last_seen_at"],
    normalized: row["raw_name"].strip.downcase,
    rounded: rounded_numeric(row["temperature_c"]),
    display: display_name(row),
    band: temperature_band(row["temperature_c"]),
    day_start: local.strftime("%Y-%m-%d 00:00:00"),
    local_date: local.strftime("%Y-%m-%d")
  }
end

check(records.length == rows.length, "scalar expressions changed row count")
check(records[0].fetch(:rounded) == "23.5", "positive numeric half rule")
check(records[1].fetch(:rounded) == "-2.3", "negative numeric half rule")
check(records[2].fetch(:rounded) == "NULL", "NULL numeric rule")
check(records[1].fetch(:local_date) == "2026-07-17", "Shanghai midnight boundary")

puts "input-rows=#{rows.length}"
puts "output-rows=#{records.length}"
puts "operations=#{OPERATION_NAMES.join(",")}"
records.each do |record|
  puts [
    "record=#{record.fetch(:id)}",
    "input-name=#{record.fetch(:input_name)}",
    "input-alias=#{record.fetch(:input_alias)}",
    "input-temperature=#{record.fetch(:input_temperature)}",
    "input-last-seen=#{record.fetch(:input_last_seen)}",
    "normalized=#{record.fetch(:normalized)}",
    "rounded=#{record.fetch(:rounded)}",
    "display=#{record.fetch(:display)}",
    "band=#{record.fetch(:band)}",
    "day-start=#{record.fetch(:day_start)}",
    "local-date=#{record.fetch(:local_date)}"
  ].join("|")
end
puts "scalar-functions-example=PASS"
