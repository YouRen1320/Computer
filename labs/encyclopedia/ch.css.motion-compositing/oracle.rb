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

errors << "lab semantic fixture drifted" unless html.match?(/aria-expanded="true"/) && html.match?(/class="drawer" data-state="open"/) && html.match?(/class="status is-updated"/)
errors << "fixed transition contract drifted" unless css.match?(/\.drawer\s*\{[^}]*transition-property:\s*opacity, transform;[^}]*transition-duration:\s*160ms;/m)
errors << "layout-affecting transition returned" if css.match?(/transition-property:[^;]*(?:width|height|top|right|bottom|left|margin)/)
errors << "finite status animation drifted" unless css.match?(/\.status\.is-updated\s*\{[^}]*animation-name:\s*status-enter;[^}]*animation-duration:\s*200ms;[^}]*animation-iteration-count:\s*1;[^}]*animation-fill-mode:\s*both;/m)
errors << "infinite animation returned" if css.match?(/animation-iteration-count:\s*infinite|animation:[^;]*\binfinite\b/)
errors << "focus-visible fix drifted" unless css.match?(/:focus-visible[\s\S]*outline:\s*3px solid/m)
errors << "outline suppression returned" if css.match?(/outline:\s*(?:none|0)\b/)
errors << "reduced motion fix drifted" unless css.match?(/@media\s*\(prefers-reduced-motion:\s*reduce\)[\s\S]*transition:\s*none;[\s\S]*animation:\s*none;[\s\S]*transform:\s*none;/m)
errors << "persistent will-change returned" if css.match?(/will-change\s*:/)

faults = data.fetch("faults")
expected_ids = %w[layout-animation-jank motion-accessibility-violation focus-hidden-during-motion transitionend-business-coupling]
errors << "fault id set drifted" unless faults.map { |fault| fault.fetch("id") } == expected_ids
faults.each do |fault|
  %w[injected first_trustworthy_evidence expected_fix].each do |field|
    errors << "#{fault.fetch('id')} lacks #{field}" if fault.fetch(field).strip.empty?
  end
end

fixed = data.fetch("fixed_contract")
errors << "fixed property set drifted" unless fixed.fetch("animated_properties") == %w[opacity transform] && fixed.fetch("layout_affecting_animated_properties") == []
errors << "fixed status must be finite" unless fixed.fetch("status_iterations") == 1
errors << "fixed reduce contract drifted" unless [fixed.fetch("reduce_transition"), fixed.fetch("reduce_animation"), fixed.fetch("reduce_transform")] == %w[none none none]
errors << "fixed focus contract drifted" unless fixed.fetch("focus_participates_in_transition") == false
errors << "fixed interruption contract drifted" unless fixed.fetch("transitioncancel_allowed") == true && fixed.fetch("business_logic_depends_on_transitionend") == false
errors << "rerun must use the same oracle" unless data.fetch("same_oracle_rerun") == true

%w[real_performance_trace_recorded real_layer_observation_recorded real_transition_events_recorded real_keyboard_focus_recorded real_screen_reader_recorded].each do |field|
  errors << "#{field} must remain false until real evidence exists" unless data[field] == false
end

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_MOTION_LAB=FAIL (#{errors.length} violations)"
  exit 1
end

puts "fault-records-and-first-evidence: PASS"
puts "transform-opacity-fix: PASS"
puts "finite-animation-and-reduce-fix: PASS"
puts "focus-and-cancel-boundary: PASS"
puts "same-oracle-rerun-contract: PASS"
puts "browser-evidence-boundary: PASS"
puts "CSS_MOTION_LAB=PASS"
