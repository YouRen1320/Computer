#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "json"

html = File.read("page.html", encoding: "UTF-8")
outline = JSON.parse(File.read("expected-outline.json", encoding: "UTF-8"))
record = JSON.parse(File.read("faults.json", encoding: "UTF-8"))
errors = []

def clean_text(value)
  CGI.unescapeHTML(value.gsub(/<[^>]+>/m, "").gsub(/\s+/, " ").strip)
end

lang = html[/<html\b[^>]*\blang=["']([^"']+)["']/i, 1]
errors << "root document language drifted" unless lang == outline.fetch("language")
errors << "doctype missing" unless html.match?(/\A\s*<!doctype\s+html>/i)

headings = html.scan(/<h([1-6])\b[^>]*>(.*?)<\/h\1\s*>/im).map do |level, value|
  [level.to_i, clean_text(value)]
end
errors << "heading outline drifted" unless headings == outline.fetch("headings")

outline.fetch("required_regions").each do |name|
  errors << "missing native #{name} region" unless html.match?(/<#{Regexp.escape(name)}\b/i)
end

metadata_checks = {
  "charset" => /<meta\b[^>]*\bcharset=["']?utf-8/i,
  "viewport" => /<meta\b[^>]*\bname=["']viewport["'][^>]*\bcontent=["']width=device-width, initial-scale=1["']/i,
  "title" => /<title\b[^>]*>[^<]+<\/title>/i,
  "description" => /<meta\b[^>]*\bname=["']description["']/i,
  "canonical" => /<link\b[^>]*\brel=["']canonical["']/i
}
outline.fetch("required_metadata").each do |name|
  errors << "missing #{name} metadata" unless html.match?(metadata_checks.fetch(name))
end

%w[Responsibility Mapping].each do |label|
  errors << "missing #{label} intent comment" unless html.include?("<!-- #{label}:")
end
%w[Data\ source Side\ effects].each do |label|
  errors << "missing #{label} intent comment" unless html.include?("<!-- #{label}:")
end
errors << "CSS, forms, scripts and ARIA roles are outside this lab" if html.match?(/<(?:style|form|script)\b|\srole\s*=/i)

expected_faults = %w[div-soup heading-skip missing-language]
actual_faults = record.fetch("faults").map { |fault| fault.fetch("id") }
errors << "fault inventory drifted" unless actual_faults == expected_faults
errors << "lab must retain the same-verifier rerun" unless record["same_verifier_rerun"] == true
errors << "lab must disclose real-browser scope" unless record["real_browser_unverified"] == true
record.fetch("faults").each do |fault|
  %w[injected_change predicted_first_evidence failure_stage repair rerun residual_risk].each do |field|
    errors << "#{fault.fetch('id')} lacks #{field}" if fault[field].to_s.strip.empty?
  end
  errors << "#{fault.fetch('id')} rerun changed the verifier" unless fault.fetch("rerun").include?("unchanged verify.sh")
end

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "SEMANTIC_HTML_LAB=FAIL (#{errors.length} violations)"
  exit 1
end

puts "repaired-structure: PASS"
puts "metadata-and-outline: PASS"
puts "fault-div-soup: PASS"
puts "fault-heading-skip: PASS"
puts "fault-missing-language: PASS"
puts "same-verifier-rerun: PASS"
puts "scope-disclosure: PASS"
puts "SEMANTIC_HTML_LAB=PASS"
