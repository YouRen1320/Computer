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
errors << "semantic form fixture drifted" unless html.match?(/<form\b[^>]*class="fault-toolbar"/i) && html.scan(/<button\b/i).length == 2
errors << "flex wrap/gap contract drifted" unless css.match?(/\.fault-toolbar\s*\{[^}]*display:\s*flex;[^}]*flex-flow:\s*row wrap;[^}]*gap:\s*12px;/m)
errors << "min-size repair missing" unless css.match?(/\.fault-toolbar__query\s*\{[^}]*flex:\s*1 1 240px;[^}]*min-inline-size:\s*0;/m)
errors << "card flex contract drifted" unless css.match?(/\.fault-cards\s*\{[^}]*display:\s*flex;[^}]*flex-wrap:\s*wrap;[^}]*gap:\s*12px;/m)
errors << "visual order repair regressed" if css.match?(/(?:^|[;{\s])order\s*:|row-reverse|column-reverse/m)

expected_faults = %w[auto-min-overflow scaled-shrink-misread visual-dom-order-mismatch]
errors << "fault inventory drifted" unless faults.fetch("faults").map { |item| item.fetch("id") } == expected_faults
faults.fetch("faults").each do |fault|
  %w[injected_change expected_failure first_trusted_evidence root_cause repair rerun residual_risk].each do |field|
    errors << "#{fault.fetch('id')} lacks #{field}" if fault.fetch(field).strip.empty?
  end
  errors << "#{fault.fetch('id')} must rerun same verifier" unless fault.fetch("rerun").include?("same verify.sh")
end

cases = matrix.fetch("cases").to_h { |item| [item.fetch("id"), item] }
errors << "wide case drifted" unless cases.fetch("wide-short").values_at("expected_lines", "expected_overflow") == [1, false]
errors << "narrow case drifted" unless cases.fetch("narrow-short").values_at("expected_lines", "expected_overflow") == [2, false]
errors << "long content case must record min-inline-size zero" unless cases.fetch("narrow-long").values_at("min_inline_size", "expected_overflow") == [0, false]
order = cases.fetch("order")
errors << "DOM/visual/tab order drifted" unless order.fetch("dom") == order.fetch("visual") && order.fetch("dom") == order.fetch("tab")
%w[real_browser_observations_recorded real_keyboard_traversal_recorded real_visual_diff_recorded].each do |field|
  errors << "#{field} must remain false" unless matrix[field] == false
end
required = matrix.fetch("required_real_evidence")
errors << "real evidence checklist drifted" unless %w[browser-name-version flex-overlay dom-visual-tab-order visual-diff].all? { |item| required.include?(item) }

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_FLEXBOX_LAB=FAIL (#{errors.length} violations)"
  exit 1
end

puts "intent-and-flex-form: PASS"
puts "min-size-and-wrap-repair: PASS"
puts "scaled-shrink-fault-record: PASS"
puts "dom-visual-tab-order: PASS"
puts "fault-rerun-records: PASS"
puts "browser-evidence-boundary: PASS"
puts "CSS_FLEXBOX_LAB=PASS"
