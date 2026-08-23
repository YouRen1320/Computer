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
errors << "normal-flow fixture missing" unless css.include?(".normal-flow { display: flow-root; }") && html.include?('class="normal-flow"')
errors << "border-box repair missing" unless css.match?(/\.inspection-card\s*\{[^}]*box-sizing:\s*border-box;/m)
errors << "containing-block repair missing" unless css.match?(/\.inspection-card\s*\{[^}]*position:\s*relative;/m) && css.match?(/\.inspection-card__badge\s*\{[^}]*position:\s*absolute;/m)
errors << "stacking-context fixture drifted" unless css.include?(".panel-a { position: relative; z-index: 1; opacity: 0.99; }") && css.include?(".panel-a__tooltip { position: absolute; z-index: 9999; }") && css.include?(".panel-b { position: relative; z-index: 2; }")

cases = matrix.fetch("cases").to_h { |item| [item.fetch("id"), item] }
box = cases.fetch("border-box")
content = box.fetch("declared_width") - 2 * box.fetch("padding_inline_each") - 2 * box.fetch("border_inline_each")
border = box.fetch("declared_width")
outer = border + 2 * box.fetch("margin_inline_each")
errors << "border-box content formula drifted" unless content == box.fetch("expected_content_width")
errors << "border-box width formula drifted" unless border == box.fetch("expected_border_width")
errors << "outer width formula drifted" unless outer == box.fetch("expected_outer_width")

collapse = cases.fetch("margin-collapse")
gap = [collapse.fetch("first_bottom"), collapse.fetch("second_top")].max
errors << "margin collapse prediction drifted" unless gap == collapse.fetch("expected_gap")
containing = cases.fetch("containing-block")
errors << "containing block prediction drifted" unless containing.fetch("expected") == ".inspection-card" && containing.fetch("reason") == "nearest-position-relative-ancestor"
stack = cases.fetch("stack-front")
front = stack.fetch("parent_z") > stack.fetch("sibling_z") ? ".panel-a" : stack.fetch("sibling_context")
errors << "stacking context prediction drifted" unless front == stack.fetch("expected_front")

expected_faults = %w[box-sizing-overflow containing-block-drift stacking-context-error]
errors << "fault inventory drifted" unless faults.fetch("faults").map { |item| item.fetch("id") } == expected_faults
faults.fetch("faults").each do |fault|
  %w[injected_change expected_failure first_trusted_evidence root_cause repair rerun residual_risk].each do |field|
    errors << "#{fault.fetch('id')} lacks #{field}" if fault.fetch(field).strip.empty?
  end
  errors << "#{fault.fetch('id')} must rerun same verifier" unless fault.fetch("rerun").include?("same verify.sh")
end

%w[real_devtools_box_model_recorded real_dom_rects_recorded real_screenshot_diff_recorded].each do |field|
  errors << "#{field} must remain false" unless matrix[field] == false
end
required = matrix.fetch("required_real_evidence")
errors << "real evidence checklist drifted" unless %w[browser-name-version box-model dom-rects visual-diff].all? { |item| required.include?(item) }

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_BOX_POSITION_LAB=FAIL (#{errors.length} violations)"
  exit 1
end

puts "intent-and-normal-flow-fixture: PASS"
puts "box-sizing-and-outer-width: PASS"
puts "margin-collapse-prediction: PASS"
puts "containing-block-repair: PASS"
puts "stacking-context-repair: PASS"
puts "fault-rerun-and-evidence-boundary: PASS"
puts "CSS_BOX_POSITION_LAB=PASS"
