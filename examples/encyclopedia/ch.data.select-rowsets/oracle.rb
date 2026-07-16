# frozen_string_literal: true

require "csv"
require "time"

ROOT = File.expand_path(__dir__)
CUTOFF = Time.iso8601("2026-07-17T00:00:00Z")

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

sql = File.read(File.join(ROOT, "query.sql"))
flat_sql = sql.gsub(/\s+/, " ")

check(sql.include?("d.device_id AS id"), "id projection missing")
check(sql.include?("d.category AS category"), "category projection missing")
check(sql.include?("d.created_at AS created_at"), "created_at projection missing")
check(sql.scan("FROM factorycare.device AS d").length == 3, "schema-qualified source or alias differs")
check(sql.scan("d.enabled IS TRUE").length == 3, "enabled predicate differs")
check(sql.scan("d.retired_at IS NULL").length == 3, "NULL predicate differs")
check(flat_sql.include?("AND ( d.retired_at IS NULL OR d.retired_at > TIMESTAMPTZ '2026-07-17 00:00:00+00' )"),
      "AND/OR grouping differs")
check(sql.scan("ORDER BY d.created_at ASC, d.device_id ASC").length == 2, "total order differs")
check(sql.include?("LIMIT 2 OFFSET 0"), "page 1 slice missing")
check(sql.include?("LIMIT 2 OFFSET 2"), "page 2 slice missing")
check(sql.include?("SELECT DISTINCT"), "DISTINCT category query missing")

rows = CSV.read(File.join(ROOT, "devices.csv"), headers: true)
eligible = rows.select do |row|
  retired_at = row["retired_at"] && Time.iso8601(row["retired_at"])
  row["enabled"] == "true" && (retired_at.nil? || retired_at > CUTOFF)
end
eligible.sort_by! { |row| [Time.iso8601(row["created_at"]), row["device_id"]] }

ids = eligible.map { |row| row["device_id"] }
page_1 = ids.slice(0, 2)
page_2 = ids.slice(2, 2)
categories = eligible.map { |row| row["category"] }.uniq.sort
null_retired = eligible.select { |row| row["retired_at"].nil? }.map { |row| row["device_id"] }

check(ids == %w[D-01 D-02 D-05 D-06], "eligible total order differs")
check((page_1 + page_2) == ids, "page union has a duplicate or omission")
check(ids.uniq.length == ids.length, "eligible ids are not unique")
check(rows.none? { |row| row["category"] == "unknown" }, "empty-set fixture changed")
check(eligible.count { |row| row["category"] == "compressor" } == 1, "single-set fixture changed")
check(eligible.count { |row| row["category"] == "pump" } == 3, "multi-set fixture changed")

puts "input-rows=#{rows.length}"
puts "eligible-order=#{ids.join(",")}"
puts "page-1=#{page_1.join(",")}"
puts "page-2=#{page_2.join(",")}"
puts "empty-category=#{eligible.count { |row| row["category"] == "unknown" }}"
puts "single-category=#{eligible.select { |row| row["category"] == "compressor" }.map { |row| row["device_id"] }.join(",")}"
puts "multi-category=#{eligible.select { |row| row["category"] == "pump" }.map { |row| row["device_id"] }.join(",")}"
puts "null-retired=#{null_retired.join(",")}"
puts "distinct-categories=#{categories.join(",")}"
puts "repeat-order=#{ids == eligible.sort_by { |row| [Time.iso8601(row["created_at"]), row["device_id"]] }.map { |row| row["device_id"] } ? "PASS" : "FAIL"}"
puts "select-rowsets-example=PASS"
