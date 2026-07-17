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
errors << "semantic exercise shell drifted" unless html.match?(/<html\b[^>]*lang="zh-CN"/i) && html.match?(/<main\b/i)
errors << "normal-flow fixture must establish flow-root" unless css.match?(/\.normal-flow\s*\{[^}]*display:\s*flow-root;/m)
errors << "card must use the 300px border-box contract" unless css.match?(/\.card\s*\{[^}]*box-sizing:\s*border-box;[^}]*width:\s*300px;/m)
errors << "stage must establish the badge containing block" unless css.match?(/\.stage\s*\{[^}]*position:\s*relative;/m)
errors << "badge must remain absolute" unless css.match?(/\.badge\s*\{[^}]*position:\s*absolute;/m)
stack_ok = css.include?(".panel-a { position: relative; z-index: 1; }") && css.include?(".tooltip { position: absolute; z-index: 9999; }") && css.include?(".panel-b { position: relative; z-index: 2; }")
errors << "stacking tree must compare panel-a z=1 with panel-b z=2" unless stack_ok
overflow_ok = css.match?(/\.overflow-hidden\s*\{[^}]*overflow:\s*hidden;/m) && css.match?(/\.overflow-clip\s*\{[^}]*overflow:\s*clip;[^}]*display:\s*flow-root;/m)
errors << "overflow fixture must contrast hidden with clip plus flow-root" unless overflow_ok

errors << "300px border-box content width must be 256" unless answer["border_box_content_width"] == 256
errors << "300px border-box outer width with 8px margins must be 316" unless answer["border_box_outer_width"] == 316
errors << "adjacent positive 24px/16px block margins must collapse to 24" unless answer["collapsed_margin_gap"] == 24
errors << "DOM parent must not be treated as automatic containing block" unless answer["dom_parent_always_containing_block"] == false
errors << "leaf z-index must not escape its parent stacking context" unless answer["leaf_z_escapes_parent_context"] == false
errors << "overflow hidden must remain distinct from clip" unless answer["overflow_hidden_equals_clip"] == false
errors << "real DevTools and screenshot evidence must remain unverified" unless answer["real_devtools_and_screenshot_unverified"] == true

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_BOX_POSITION_EXERCISE=RED (#{errors.length} violations)"
  exit 1
end

puts "intent-and-semantic-contract: PASS"
puts "box-and-margin-calculation: PASS"
puts "containing-block-contract: PASS"
puts "stacking-context-contract: PASS"
puts "overflow-hidden-clip-contract: PASS"
puts "browser-evidence-boundary: PASS"
puts "CSS_BOX_POSITION_EXERCISE=PASS"
