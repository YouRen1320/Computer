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
errors << "semantic exercise form drifted" unless html.match?(/<form\b[^>]*class="toolbar"/i) && html.scan(/<button\b/i).length == 2
errors << "toolbar must use row wrap with a 12px gap" unless css.match?(/\.toolbar\s*\{[^}]*display:\s*flex;[^}]*flex-flow:\s*row wrap;[^}]*gap:\s*12px;/m)
errors << "query must allow flex shrink below its automatic minimum" unless css.match?(/\.query\s*\{[^}]*flex:\s*1 1 240px;[^}]*min-inline-size:\s*0;/m)
errors << "buttons must keep content size without visual reordering" unless css.match?(/\.toolbar\s*>\s*button\s*\{[^}]*flex:\s*0 0 auto;/m)
errors << "order/reverse must not split visual and DOM order" if css.match?(/(?:^|[;{\s])order\s*:|row-reverse|column-reverse/m)
errors << "cards must wrap with a 12px gap" unless css.match?(/\.cards\s*\{[^}]*display:\s*flex;[^}]*flex-wrap:\s*wrap;[^}]*gap:\s*12px;/m)

errors << "positive free space must subtract bases and gaps" unless answer["positive_free_space"] == 88
errors << "grow targets must be 182, 284, 222" unless answer["grow_targets"] == [182, 284, 222]
errors << "grow factor distributes free space, not final size ratio" unless answer["grow_factor_is_final_size_ratio"] == false
errors << "shrink must use basis-scaled factors" unless answer["shrink_uses_naked_factor_only"] == false
errors << "align-content must not be treated as single-line item alignment" unless answer["align_content_moves_items_in_single_line"] == false
errors << "gap must not be treated as container edge padding" unless answer["gap_adds_container_edge_spacing"] == false
errors << "visual order must not be treated as default Tab order" unless answer["visual_order_changes_default_tab_order"] == false
errors << "real browser, keyboard and visual evidence must remain unverified" unless answer["real_browser_keyboard_visual_unverified"] == true

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_FLEXBOX_EXERCISE=RED (#{errors.length} violations)"
  exit 1
end

puts "intent-and-semantic-contract: PASS"
puts "wrap-gap-and-min-size: PASS"
puts "grow-and-scaled-shrink: PASS"
puts "alignment-boundary: PASS"
puts "dom-visual-tab-order: PASS"
puts "browser-evidence-boundary: PASS"
puts "CSS_FLEXBOX_EXERCISE=PASS"
