#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html = File.read("index.html", encoding: "UTF-8")
css = File.read("styles.css", encoding: "UTF-8")
data = JSON.parse(File.read("faults.json", encoding: "UTF-8"))
errors = []

[[html, "<!--"], [css, "/*"]].each_with_index do |(document, prefix), index|
  ["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
    errors << "document #{index + 1} lacks #{label} intent comment" unless document.include?("#{prefix} #{label}:")
  end
end

errors << "lab semantic fixture drifted" unless html.match?(/class="panel sibling"/) && html.match?(/class="panel danger-zone"/) && html.match?(/class="panel missing-private-token"/)
errors << "scope fix drifted" unless css.match?(/\.danger-zone\s*\{[^}]*--color-accent:\s*#b42318;/m)
errors << "scope leak returned" if css.match?(/\.page-shell\s*\{[^}]*--color-accent:/m)
errors << "nested fallback fix drifted" unless css.include?("var(--panel-surface, var(--color-surface, Canvas))")
errors << "invalid private token returned" if css.match?(/\.missing-private-token\s*\{[^}]*--panel-surface:\s*12px/m)
errors << "dark theme fix drifted" unless css.match?(/prefers-color-scheme:\s*dark[\s\S]*--color-text:\s*#f8fafc;/m)
errors << "forced colors boundary drifted" unless css.match?(/forced-colors:\s*active[\s\S]*CanvasText[\s\S]*ButtonText/m)

faults = data.fetch("faults")
errors << "fault id set drifted" unless faults.map { |fault| fault.fetch("id") } == %w[token-scope-error var-fallback-type-error insufficient-contrast]
faults.each do |fault|
  %w[injected first_trustworthy_evidence expected_fix].each do |field|
    errors << "#{fault.fetch('id')} lacks #{field}" if fault.fetch(field).strip.empty?
  end
end
errors << "rerun must use same oracle" unless data.fetch("same_oracle_rerun") == true

def luminance(hex)
  rgb = hex.delete_prefix("#").scan(/../).map { |pair| pair.to_i(16) / 255.0 }
  linear = rgb.map { |value| value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4 }
  0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
end

data.fetch("fixed_contrast_cases").each do |entry|
  values = [luminance(entry.fetch("foreground")), luminance(entry.fetch("background"))].sort.reverse
  ratio = (values[0] + 0.05) / (values[1] + 0.05)
  errors << "fixed contrast #{entry.fetch('id')} remains below threshold" unless ratio >= entry.fetch("minimum")
end

%w[real_browser_computed_recorded real_forced_colors_recorded real_screen_reader_recorded real_visual_review_recorded].each do |field|
  errors << "#{field} must remain false until real evidence exists" unless data[field] == false
end

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_THEME_LAB=FAIL (#{errors.length} violations)"
  exit 1
end

puts "fault-records-and-first-evidence: PASS"
puts "scope-fix-and-sibling-boundary: PASS"
puts "missing-token-nested-fallback: PASS"
puts "fixed-contrast-matrix: PASS"
puts "same-oracle-rerun-contract: PASS"
puts "browser-evidence-boundary: PASS"
puts "CSS_THEME_LAB=PASS"
