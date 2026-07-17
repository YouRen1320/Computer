#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html = File.read("index.html", encoding: "UTF-8")
js = File.read("interaction.js", encoding: "UTF-8")
matrix = JSON.parse(File.read("audit-matrix.json", encoding: "UTF-8"))
faults = JSON.parse(File.read("faults.json", encoding: "UTF-8"))
errors = []

["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
  errors << "HTML lacks #{label} intent comment" unless html.include?("<!-- #{label}:")
  errors << "JavaScript lacks #{label} intent comment" unless js.include?("// #{label}:")
end
errors << "positive tabindex remains" if html.match?(/\btabindex=["'][1-9]\d*["']/i)
errors << "custom role button remains" if html.match?(/<(?:div|span)\b[^>]*\brole=["']button["']/i)
errors << "description explicit label drifted" unless html.match?(/<label\b[^>]*\bfor=["']description["']/i)
errors << "remove attachment needs contextual visible name" unless html.match?(/<button\b[^>]*\bid=["']remove-attachment["'][^>]*>移除附件 demo\.png<\/button>/i)
errors << "error summary focus target drifted" unless html.match?(/<div\b[^>]*\bid=["']error-summary["'][^>]*\btabindex=["']-1["'][^>]*\shidden/i)
errors << "attachment restoration target drifted" unless html.match?(/<h2\b[^>]*\bid=["']attachments-heading["'][^>]*\btabindex=["']-1["']/i)
errors << "toggle state synchronization missing" unless
  js.include?("panel.hidden = !open") && js.include?('setAttribute("aria-expanded", String(open))')
errors << "field error state/focus missing" unless js.include?('setAttribute("aria-invalid", "true")') && js.include?("summary.focus()")
errors << "safe text update missing" unless js.include?("textContent") && !js.include?("innerHTML")
errors << "attachment focus restoration missing" unless js.include?('getElementById("attachments-heading").focus()')
errors << "ordinary page must not trap Tab" if js.match?(/keydown|key\s*===\s*["']Tab["']/)

expected_steps = %w[forward-tab reverse-tab toggle-state names error-focus remove-restore]
errors << "audit matrix drifted" unless matrix.fetch("steps").map { |item| item.fetch("id") } == expected_steps
%w[real_keyboard_observed real_accessibility_tree_observed real_screen_reader_observed].each do |field|
  errors << "#{field} must remain false" unless matrix[field] == false
end
expected_faults = %w[focus-trap missing-name wrong-aria-state]
errors << "fault inventory drifted" unless faults.fetch("faults").map { |item| item.fetch("id") } == expected_faults
errors << "same task rerun missing" unless faults["same_task_rerun"] == true
errors << "assistive technology scope missing" unless faults["real_assistive_technology_unverified"] == true
faults.fetch("faults").each do |fault|
  %w[injection first_evidence stage repair rerun residual_risk].each do |field|
    errors << "#{fault.fetch('id')} lacks #{field}" if fault[field].to_s.strip.empty?
  end
  errors << "#{fault.fetch('id')} changed the task" unless fault.fetch("rerun").include?("unchanged")
end

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "ACCESSIBILITY_INTERACTION_LAB=FAIL (#{errors.length} violations)"
  exit 1
end

puts "native-keyboard-baseline: PASS"
puts "focus-visible-order-restoration-contract: PASS"
puts "accessible-names: PASS"
puts "aria-state-sync: PASS"
puts "dynamic-error-focus: PASS"
puts "fault-diagnosis-records: PASS"
puts "same-task-rerun: PASS"
puts "scope-disclosure: PASS"
puts "ACCESSIBILITY_INTERACTION_LAB=PASS"
