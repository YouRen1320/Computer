#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html = File.read("index.html", encoding: "UTF-8")
css = File.read("styles.css", encoding: "UTF-8")
matrix = JSON.parse(File.read("motion-matrix.json", encoding: "UTF-8"))
errors = []

[[html, "<!--"], [css, "/*"]].each_with_index do |(document, prefix), index|
  ["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
    errors << "document #{index + 1} lacks #{label} intent comment" unless document.include?("#{prefix} #{label}:")
  end
end

errors << "explicit transform/opacity transition contract missing" unless css.match?(/\.drawer\s*\{[^}]*transform:\s*translateX\([^)]*\);[^}]*transition-property:\s*opacity, transform;[^}]*transition-duration:\s*160ms;/m)
errors << "transition all is forbidden" if css.match?(/transition(?:-property)?\s*:\s*all\b/)
errors << "layout-affecting keyframes are forbidden" if css.match?(/@keyframes[\s\S]*(?:width|height|top|right|bottom|left|margin)\s*:/m)
errors << "finite status animation contract missing" unless css.match?(/\.status\.is-updated\s*\{[^}]*animation-name:\s*status-enter;[^}]*animation-duration:\s*200ms;[^}]*animation-iteration-count:\s*1;[^}]*animation-fill-mode:\s*both;/m)
errors << "infinite animation is forbidden" if css.match?(/animation-iteration-count:\s*infinite|animation:[^;]*\binfinite\b/)
errors << "visible focus outline contract missing" unless css.match?(/:focus-visible[\s\S]*outline:\s*3px solid/m)
errors << "outline suppression is forbidden" if css.match?(/outline:\s*(?:none|0)\b/)
errors << "reduced motion contract missing" unless css.match?(/@media\s*\(prefers-reduced-motion:\s*reduce\)[\s\S]*transition:\s*none;[\s\S]*animation:\s*none;[\s\S]*transform:\s*none;[\s\S]*opacity:\s*1;/m)
errors << "persistent will-change is forbidden without measured lifecycle" if css.match?(/will-change\s*:/)

errors << "matrix transition contract drifted" unless matrix.fetch("transition_properties") == %w[opacity transform] && matrix.fetch("transition_duration_ms") == 160
errors << "matrix animation contract drifted" unless matrix.fetch("status_animation") == {"iterations"=>1, "fill_mode"=>"both"}
errors << "matrix reduced mode drifted" unless matrix.fetch("reduced_mode") == {"transition"=>"none", "animation"=>"none", "transform"=>"none", "open_opacity"=>1}
errors << "matrix focus boundary drifted" unless matrix.dig("focus", "participates_in_transition") == false
errors << "matrix interruption boundary drifted" unless matrix.dig("interruptibility", "transitioncancel_allowed") == true && matrix.dig("interruptibility", "business_logic_depends_on_transitionend") == false
errors << "matrix performance boundary drifted" unless matrix.dig("performance", "layout_affecting_animated_properties") == [] && matrix.dig("performance", "layer_promotion_guaranteed") == false

%w[real_performance_trace_recorded real_layer_observation_recorded real_transition_events_recorded real_keyboard_focus_recorded real_screen_reader_recorded].each do |field|
  errors << "#{field} must remain false until real evidence exists" unless matrix[field] == false
end

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_MOTION_EXERCISE=FAIL (#{errors.length} violations)"
  exit 1
end

puts "motion-source-and-intent: PASS"
puts "finite-transform-opacity-contract: PASS"
puts "reduced-motion-contract: PASS"
puts "focus-and-interruptibility: PASS"
puts "performance-claim-boundary: PASS"
puts "browser-evidence-boundary: PASS"
puts "CSS_MOTION_EXERCISE=PASS"
