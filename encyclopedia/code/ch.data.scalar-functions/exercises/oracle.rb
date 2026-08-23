# frozen_string_literal: true

def check(condition, message)
  raise "answer-error=#{message}" unless condition
end

sql = File.read(ARGV.fetch(0))

check(sql.scan("AT TIME ZONE 'Asia/Shanghai'").length >= 2,
      "timezone must be converted before truncation and date cast")
check(sql.include?("d.raw_name AS raw_name"), "raw_name must remain in report")
check(sql.include?("d.alias AS alias"), "alias must remain in report")
check(sql.include?("d.temperature_c AS temperature_c"), "temperature must remain in report")
check(sql.include?("d.last_seen_at AS last_seen_at"), "timestamp must remain in report")
check(sql.include?("lower(btrim(d.raw_name)) AS normalized_name"), "normalization")
check(sql.include?("round(d.temperature_c, 1) AS temperature_c_1dp"), "rounding")
check(sql.include?("COALESCE(") && sql.include?("NULLIF(btrim(d.alias), '')"), "blank alias rule")
check(sql.include?("WHEN d.temperature_c IS NULL THEN 'UNKNOWN'"), "NULL CASE branch")
check(sql.include?("date_trunc(") && sql.include?("AS local_day_start"), "local day truncation")
check(sql.include?("CAST(") && sql.include?("AS local_date"), "explicit local date cast")
check(!sql.include?("d.temperature_c + d.calibration_text"), "implicit numeric/text conversion")
check(sql.include?("FROM factorycare.device_reading AS d"), "schema-qualified source")

puts "scalar-functions-answer=PASS"
