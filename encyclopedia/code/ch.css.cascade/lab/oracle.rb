#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html = File.read("index.html", encoding: "UTF-8")
css = File.read("styles.css", encoding: "UTF-8")
faults = JSON.parse(File.read("faults.json", encoding: "UTF-8"))
matrix = JSON.parse(File.read("observation-matrix.json", encoding: "UTF-8"))
errors = []

[[html, "<!--"], [css, "/*"]].each_with_index do |(document, prefix), index|
  ["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
    errors << "document #{index + 1} lacks #{label} intent comment" unless document.include?("#{prefix} #{label}:")
  end
end

errors << "lab semantic target drifted" unless html.match?(/<article\b[^>]*class="incident is-critical"[^>]*data-state="open"/i)
errors << "explicit layer order missing" unless css.include?("@layer base, components, utilities;")
errors << "priority repair missing" unless css.match?(/@layer utilities\s*\{[^}]*\.is-critical\s*>\s*\.incident__title\s*\{\s*color:\s*#b91c1c;/m)
errors << "inheritance repair missing" unless css.match?(/\.incident__summary\s*\{\s*color:\s*inherit;/m)
code_rules = css.scan(/\.incident__code\s*\{\s*color:\s*(#[0-9a-f]{6});\s*\}/i).flatten
errors << "source-order fixture drifted" unless code_rules == %w[#64748b #0f172a]

expected_fault_ids = %w[priority-misread inheritance-misread source-order-misread]
errors << "fault inventory drifted" unless faults.fetch("faults").map { |item| item.fetch("id") } == expected_fault_ids
faults.fetch("faults").each do |fault|
  %w[injected_change expected_failure first_trusted_evidence root_cause repair rerun residual_risk].each do |field|
    errors << "#{fault.fetch('id')} lacks #{field}" if fault.fetch(field).strip.empty?
  end
  errors << "#{fault.fetch('id')} must rerun same verifier" unless fault.fetch("rerun").include?("same verify.sh")
end

expected_cases = {
  "priority" => ["#b91c1c", "#166534"],
  "inheritance" => ["#334155", "#334155"],
  "source-order" => ["#0f172a", "#64748b"]
}
matrix.fetch("cases").each do |item|
  expected = expected_cases[item.fetch("id")]
  errors << "matrix case drifted for #{item.fetch('id')}" unless expected == [item.fetch("expected"), item.fetch("remove_winner_expected")]
end
errors << "matrix must disclose computed style unverified" unless matrix["real_browser_observations_recorded"] == false
errors << "matrix must disclose visual diff unverified" unless matrix["real_visual_diff_recorded"] == false
errors << "real evidence checklist drifted" unless matrix.fetch("required_real_evidence").include?("browser-name-version") && matrix.fetch("required_real_evidence").include?("visual-diff")

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_CASCADE_LAB=FAIL (#{errors.length} violations)"
  exit 1
end

puts "intent-and-dom-contract: PASS"
puts "priority-repair: PASS"
puts "inheritance-repair: PASS"
puts "source-order-repair: PASS"
puts "fault-evidence-rerun-records: PASS"
puts "observation-boundary: PASS"
puts "CSS_CASCADE_LAB=PASS"
