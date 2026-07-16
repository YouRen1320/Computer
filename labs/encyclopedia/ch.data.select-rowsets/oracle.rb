# frozen_string_literal: true

require "csv"
require "json"
require "time"

ROOT = File.expand_path(__dir__)
CUTOFF = Time.iso8601("2026-07-17T00:00:00Z")

def check(condition, message)
  raise "lab-failure=#{message}" unless condition
end

sql = File.read(File.join(ROOT, "query.sql"))
flat_sql = sql.gsub(/\s+/, " ")
check(sql.scan("FROM factorycare.device AS d").length == 2, "source contract")
check(sql.scan("d.retired_at IS NULL").length == 2, "NULL contract")
check(flat_sql.include?("AND ( d.retired_at IS NULL OR d.retired_at > TIMESTAMPTZ '2026-07-17 00:00:00+00' )"),
      "boolean grouping")
check(sql.scan("ORDER BY d.created_at ASC, d.device_id ASC").length == 2, "total-order contract")
check(sql.include?("LIMIT 2 OFFSET 0") && sql.include?("LIMIT 2 OFFSET 2"), "page slices")

scenarios = JSON.parse(File.read(File.join(ROOT, "scenarios.json")))
check(scenarios.map { |item| item.fetch("id") } == %w[null-equality missing-parentheses nonunique-order],
      "scenario ids")
check(scenarios[0].fetch("broken_predicate").include?("= NULL"), "NULL injection")
check(!scenarios[1].fetch("broken_predicate").include?("("), "parentheses injection")
check(!scenarios[2].fetch("broken_order").include?("device_id"), "ordering injection")

rows = CSV.read(File.join(ROOT, "devices.csv"), headers: true)
retired = lambda do |row|
  row["retired_at"] && Time.iso8601(row["retired_at"])
end
eligible = rows.select do |row|
  row["enabled"] == "true" && (retired.call(row).nil? || retired.call(row) > CUTOFF)
end
eligible.sort_by! { |row| [Time.iso8601(row["created_at"]), row["device_id"]] }
ids = eligible.map { |row| row["device_id"] }

# Simulate the actual precedence of: (enabled AND is_null) OR retired_after_cutoff.
leaky = rows.select do |row|
  (row["enabled"] == "true" && retired.call(row).nil?) ||
    (!retired.call(row).nil? && retired.call(row) > CUTOFF)
end.map { |row| row["device_id"] }.sort

# Both sequences are legal when created_at ties; separate page requests can see either.
legal_run_for_page_1 = %w[D-01 D-02 D-05 D-06]
legal_run_for_page_2 = %w[D-05 D-01 D-02 D-06]
unstable_page_1 = legal_run_for_page_1.slice(0, 2)
unstable_page_2 = legal_run_for_page_2.slice(2, 2)
unstable_union = unstable_page_1 + unstable_page_2
counts = unstable_union.each_with_object(Hash.new(0)) { |id, memo| memo[id] += 1 }
duplicates = counts.select { |_id, count| count > 1 }.keys
omitted = ids - unstable_union

fixed_page_1 = ids.slice(0, 2)
fixed_page_2 = ids.slice(2, 2)
check(ids == %w[D-01 D-02 D-05 D-06], "baseline rowset")
check(leaky.include?("D-07"), "missing-parentheses injection did not leak D-07")
check(duplicates == ["D-02"], "nonunique order duplicate")
check(omitted == ["D-05"], "nonunique order omission")
check((fixed_page_1 + fixed_page_2) == ids, "fixed pages do not close")

puts "baseline-empty=#{eligible.count { |row| row["category"] == "unknown" }}"
puts "baseline-single=#{eligible.select { |row| row["category"] == "compressor" }.map { |row| row["device_id"] }.join(",")}"
puts "baseline-multi=#{eligible.select { |row| row["category"] == "pump" }.map { |row| row["device_id"] }.join(",")}"
puts "baseline-null=#{eligible.select { |row| row["retired_at"].nil? }.map { |row| row["device_id"] }.join(",")}"
puts "injection-null-equality=EMPTY"
puts "injection-unparenthesized-leak=#{(leaky - ids).join(",")}"
puts "injection-nonunique-page1=#{unstable_page_1.join(",")}"
puts "injection-nonunique-page2=#{unstable_page_2.join(",")}"
puts "injection-duplicate=#{duplicates.join(",")}"
puts "injection-omitted=#{omitted.join(",")}"
puts "fixed-page-union=#{(fixed_page_1 + fixed_page_2).join(",")}"
puts "fixed-repeat=#{ids == eligible.sort_by { |row| [Time.iso8601(row["created_at"]), row["device_id"]] }.map { |row| row["device_id"] } ? "PASS" : "FAIL"}"
puts "select-rowsets-lab=PASS"
