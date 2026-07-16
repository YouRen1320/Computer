# frozen_string_literal: true

require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "lab-failure=#{message}" unless condition
end

def accepted?(item)
  value = item.fetch("value")
  case item.fetch("kind")
  when "uuid"
    value.is_a?(String) && value.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
  when "jsonb"
    value.nil? || (value.is_a?(Hash) && !value.key?("__json_scalar__"))
  when "array"
    value.nil? || (value.is_a?(Array) && value.length <= 5 && value.none?(&:nil?))
  when "domain"
    value.is_a?(String) && value.match?(/\ASN-[0-9]{3}\z/)
  when "enum"
    %w[ACTIVE MAINTENANCE RETIRED].include?(value)
  else
    raise "lab-failure=unknown boundary kind"
  end
end

input = JSON.parse(File.read(File.join(ROOT, "scenarios.json")))
cases = input.fetch("boundary_cases")
classes_by_kind = cases.group_by { |item| item.fetch("kind") }.transform_values do |items|
  items.map { |item| item.fetch("class") }.sort
end
check(classes_by_kind.keys.sort == %w[array domain enum jsonb uuid], "five type families")
check(classes_by_kind.values.all? { |classes| classes == %w[invalid legal sql-null] }, "legal NULL invalid coverage")

results = cases.map { |item| accepted?(item) ? "ACCEPT" : "REJECT" }
check(results == cases.map { |item| item.fetch("expected") }, "boundary results")

injections = input.fetch("failure_injections")
expected_injections = {
  "high-frequency-relations-in-jsonb" => "REMODEL:ordinary-relations",
  "unbounded-tags-in-array" => "REMODEL:device_tag",
  "remove-and-reorder-enum-labels" => "BLOCKED:rebuild-or-rechoose"
}
check(injections.to_h { |item| [item.fetch("id"), item.fetch("expected")] } == expected_injections, "diagnostic decisions")
check(injections.all? { |item| item.fetch("evidence").length >= 3 }, "diagnostic evidence")

portability = input.fetch("portability_records")
check(portability.map { |item| item.fetch("type") }.sort == %w[array domain enum jsonb uuid], "portability coverage")
check(portability.all? { |item| !item.fetch("plan").empty? }, "portability plans")

puts "boundary-cases=#{cases.length}|accept=#{results.count("ACCEPT")}|reject=#{results.count("REJECT")}"
injections.each { |item| puts "#{item.fetch("id")}=#{item.fetch("expected")}" }
puts "portability-records=#{portability.length}|verdict=PASS"
puts "postgresql-types-lab=PASS"
