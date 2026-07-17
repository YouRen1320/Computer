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

errors << "semantic motion fixture drifted" unless html.match?(/<button\b[^>]*aria-expanded="true"[^>]*aria-controls="motion-panel"/i) && html.match?(/<section\b[^>]*class="motion-card"[^>]*data-state="open"/i)
errors << "explicit transition property contract drifted" unless css.match?(/\.motion-card\s*\{[^}]*transition-property:\s*opacity, transform;[^}]*transition-duration:\s*180ms;[^}]*transition-timing-function:\s*ease-out;/m)
errors << "open state transform contract drifted" unless css.match?(/\.motion-card\[data-state="open"\]\s*\{[^}]*opacity:\s*1;[^}]*transform:\s*translateY\(0\);/m)
errors << "keyframes contract drifted" unless css.match?(/@keyframes\s+badge-enter\s*\{[\s\S]*0%[\s\S]*65%[\s\S]*100%/m)
errors << "finite animation contract drifted" unless css.match?(/\.status-badge\.is-new\s*\{[^}]*animation-name:\s*badge-enter;[^}]*animation-duration:\s*240ms;[^}]*animation-iteration-count:\s*1;[^}]*animation-fill-mode:\s*both;/m)
errors << "focus-visible contract drifted" unless css.match?(/:focus-visible[\s\S]*outline:\s*3px solid/m)
errors << "reduced motion contract drifted" unless css.match?(/@media\s*\(prefers-reduced-motion:\s*reduce\)[\s\S]*transition:\s*none;[\s\S]*animation:\s*none;[\s\S]*transform:\s*none;/m)
errors << "transition all is forbidden" if css.match?(/transition(?:-property)?\s*:\s*all\b/)
errors << "infinite animation is forbidden" if css.match?(/animation-iteration-count:\s*infinite|animation:[^;]*\binfinite\b/)
errors << "persistent will-change is outside this contract" if css.match?(/will-change\s*:/)
errors << "layout-affecting transition is forbidden" if css.match?(/transition-property:[^;]*(?:width|height|top|left|margin)/)

normal = matrix.fetch("normal_mode")
errors << "normal transition matrix drifted" unless normal.fetch("transition_properties") == %w[opacity transform] && normal.fetch("duration_ms") == 180
errors << "normal closed state drifted" unless normal.fetch("closed") == {"opacity"=>0, "transform"=>"translateY(0.75rem)"}
errors << "normal open state drifted" unless normal.fetch("open") == {"opacity"=>1, "transform"=>"translateY(0)"}
errors << "status animation matrix drifted" unless normal.fetch("status_animation") == {"name"=>"badge-enter", "duration_ms"=>240, "iterations"=>1, "fill_mode"=>"both"}
reduced = matrix.fetch("reduced_mode")
errors << "reduced mode must remove transform" unless reduced.dig("open", "transform") == "none"
errors << "reduced mode must preserve immediate visible state" unless reduced.dig("open", "opacity") == 1 && reduced.fetch("meaning_preserved_by").include?("immediate state")
focus = matrix.fetch("focus_contract")
errors << "focus must not participate in transition" unless focus.fetch("participates_in_transition") == false && focus.fetch("must_remain_visible_during_motion") == true
interrupt = matrix.fetch("interruptibility")
errors << "interruptibility contract drifted" unless interrupt.fetch("rapid_sequence") == %w[open close open] && interrupt.fetch("transitioncancel_allowed") == true && interrupt.fetch("business_logic_depends_on_transitionend") == false
performance = matrix.fetch("performance_contract")
errors << "performance candidate contract drifted" unless performance.fetch("source_candidates") == %w[opacity transform] && performance.fetch("layout_affecting_animated_properties") == []
errors << "layer promotion cannot be guaranteed" unless performance.fetch("layer_promotion_guaranteed") == false

%w[real_performance_trace_recorded real_layer_observation_recorded real_transition_events_recorded real_keyboard_focus_recorded real_screen_reader_recorded real_user_motion_review_recorded].each do |field|
  errors << "#{field} must remain false until real evidence exists" unless matrix[field] == false
end

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_MOTION_EXAMPLE=FAIL (#{errors.length} violations)"
  exit 1
end

puts "intent-and-motion-source: PASS"
puts "transition-keyframes-contract: PASS"
puts "reduced-motion-state-matrix: PASS"
puts "focus-and-interruptibility: PASS"
puts "compositor-candidate-boundary: PASS"
puts "browser-evidence-boundary: PASS"
puts "CSS_MOTION_EXAMPLE=PASS"
