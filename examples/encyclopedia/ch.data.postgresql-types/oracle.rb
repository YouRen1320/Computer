# frozen_string_literal: true

require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

def accepted?(test_case)
  value = test_case.fetch("value")
  case test_case.fetch("kind")
  when "uuid"
    value.is_a?(String) && value.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
  when "jsonb"
    value.nil? || (value.is_a?(Hash) && !value.key?("__json_scalar__"))
  when "array"
    value.nil? || (value.is_a?(Array) && value.length <= 5 && value.none?(&:nil?))
  when "asset-code"
    value.is_a?(String) && value.match?(/\ASN-[0-9]{3}\z/)
  when "status"
    %w[ACTIVE MAINTENANCE RETIRED].include?(value)
  else
    raise "oracle-failure=unknown kind"
  end
end

decisions = JSON.parse(File.read(File.join(ROOT, "decisions.json")))
cases = JSON.parse(File.read(File.join(ROOT, "cases.json")))
schema = File.read(File.join(ROOT, "schema.sql"))

check(decisions.map { |item| item.fetch("fact") } == %w[device-id vendor-metadata search-aliases core-tags device-status serial-number], "decision coverage")
check(decisions.all? { |item| !item.fetch("constraints").empty? && !item.fetch("portability").empty? }, "constraint and portability records")
%w[uuidv7() jsonb_typeof cardinality array_position CREATE\ DOMAIN device_tag].each do |token|
  check(schema.include?(token.gsub("\\", "")), "schema token #{token}")
end

results = cases.map { |item| accepted?(item) ? "ACCEPT" : "REJECT" }
check(results == cases.map { |item| item.fetch("expected") }, "legal, NULL, and invalid cases")

puts "decision-records=#{decisions.length}"
puts "types-tested=#{cases.map { |item| item.fetch("kind") }.uniq.sort.join(",")}"
puts "case-count=#{cases.length}|accept=#{results.count("ACCEPT")}|reject=#{results.count("REJECT")}"
puts "core-tags=relation-table|verdict=PASS"
puts "constraints-and-portability=PASS"
puts "postgresql-types-example=PASS"
