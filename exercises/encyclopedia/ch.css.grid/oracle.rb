#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html_path = ARGV.fetch(0, "answer.html")
css_path = ARGV.fetch(1, "answer.css")
json_path = ARGV.fetch(2, "answer.json")
html = File.read(html_path, encoding: "UTF-8")
css = File.read(css_path, encoding: "UTF-8")
answer = JSON.parse(File.read(json_path, encoding: "UTF-8"))
errors = []

["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
  errors << "HTML lacks #{label} intent comment" unless html.include?("<!-- #{label}:")
  errors << "CSS lacks #{label} intent comment" unless css.include?("/* #{label}:")
end
errors << "semantic grid shell drifted" unless html.match?(/<main\b[^>]*class="layout"/i) && html.match?(/<aside\b[^>]*class="detail"/i)
layout_ok = css.match?(/\.layout\s*\{[^}]*display:\s*grid;[^}]*grid-template-columns:\s*240px minmax\(0, 1fr\);[^}]*grid-template-areas:\s*"filters filters"\s*"orders\s+detail";[^}]*gap:\s*16px;[^}]*inline-size:\s*800px;/m)
errors << "layout must use the exact two-column rectangular area contract" unless layout_ok
errors << "orders and detail must allow the content track to shrink" unless css.match?(/\.orders\s*\{[^}]*min-inline-size:\s*0;[^}]*overflow-wrap:\s*anywhere;/m) && css.match?(/\.detail\s*\{[^}]*min-inline-size:\s*0;/m)
auto_ok = css.match?(/\.auto-list\s*\{[^}]*display:\s*grid;[^}]*grid-template-columns:\s*repeat\(3, minmax\(0, 1fr\)\);[^}]*grid-template-rows:\s*80px;[^}]*grid-auto-flow:\s*row;[^}]*grid-auto-rows:\s*80px;[^}]*gap:\s*12px;/m)
errors << "auto-list must allow one explicit and fixed-size implicit rows" unless auto_ok
errors << "dense/order visual reordering is forbidden in this task list" if css.match?(/grid-auto-flow\s*:[^;]*dense|(?:^|[;{\s])order\s*:/m)

errors << "track leftover must subtract fixed track and gap" unless answer["track_leftover"] == 544
errors << "track sizes must be 240 and 544" unless answer["track_sizes"] == [240, 544]
errors << "two tracks must have three grid lines" unless answer["two_tracks_have_three_lines"] == true
errors << "1fr must not be treated as an unconditional 50 percent" unless answer["one_fr_is_always_fifty_percent"] == false
errors << "negative line -1 must target the explicit grid end" unless answer["negative_one_targets_explicit_grid_end"] == true
errors << "dense placement must not promise visual source order" unless answer["dense_preserves_visual_source_order"] == false
errors << "ordinary nested grid must not be treated as sharing parent tracks" unless answer["ordinary_nested_grid_shares_parent_tracks"] == false
errors << "subgrid support and fallback must remain unverified" unless answer["subgrid_support_and_fallback_unverified"] == true
errors << "real browser Grid and visual evidence must remain unverified" unless answer["real_browser_grid_visual_unverified"] == true

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_GRID_EXERCISE=RED (#{errors.length} violations)"
  exit 1
end

puts "intent-and-semantic-contract: PASS"
puts "track-gap-and-min-content: PASS"
puts "rectangular-area-and-lines: PASS"
puts "implicit-row-and-order-boundary: PASS"
puts "subgrid-boundary: PASS"
puts "browser-evidence-boundary: PASS"
puts "CSS_GRID_EXERCISE=PASS"
