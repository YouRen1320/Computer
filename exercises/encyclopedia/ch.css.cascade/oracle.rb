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
errors << "semantic exercise shell drifted" unless html.match?(/<html\b[^>]*lang="zh-CN"/i) && html.match?(/<main\b[^>]*id="exercise"/i) && html.include?('data-state="open"')

errors << "explicit layer order must be base, components, utilities" unless css.include?("@layer base, components, utilities;")
errors << "zero-specificity boundary must use :where(#exercise, .shell) .title" unless css.include?(":where(#exercise, .shell) .title")
errors << "critical state must use a direct-child utility selector" unless css.include?(".is-critical > .title")
errors << "!important is forbidden in this architecture exercise" if css.match?(/!important/i)
errors << "brittle ID-descendant title selector must be removed" if css.match?(/#exercise\s+article\s+\.title/)
errors << "summary must explicitly inherit the parent computed color" unless css.match?(/\.summary\s*\{\s*color:\s*inherit;\s*\}/m)
code_rules = css.scan(/\.code\s*\{\s*color:\s*(#[0-9a-f]{6});\s*\}/i).flatten
errors << "source-order exercise must end with #0f172a after #64748b" unless code_rules == %w[#64748b #0f172a]

errors << "!important must remain separate from specificity" unless answer["important_is_specificity"] == false
errors << "later source must not be treated as unconditional winner" unless answer["later_source_always_wins"] == false
errors << "parent specificity must not compete with a child declaration" unless answer["parent_specificity_competes_with_child_declaration"] == false
errors << "unset must depend on whether the property naturally inherits" unless answer["unset_always_initial"] == false
errors << "real browser computed style must remain explicitly unverified" unless answer["real_browser_computed_style_unverified"] == true

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_CASCADE_EXERCISE=RED (#{errors.length} violations)"
  exit 1
end

puts "intent-and-semantic-contract: PASS"
puts "layer-and-low-specificity-contract: PASS"
puts "inheritance-and-source-order: PASS"
puts "cascade-concept-boundaries: PASS"
puts "browser-evidence-boundary: PASS"
puts "CSS_CASCADE_EXERCISE=PASS"
