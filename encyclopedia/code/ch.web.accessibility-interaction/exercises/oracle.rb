#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html_path = ARGV.fetch(0, "answer.html")
js_path = ARGV.fetch(1, "answer.js")
json_path = ARGV.fetch(2, "answer.json")
html = File.read(html_path, encoding: "UTF-8")
js = File.read(js_path, encoding: "UTF-8")
answer = JSON.parse(File.read(json_path, encoding: "UTF-8"))
errors = []

def attribute(tag, name)
  match = tag.to_s.match(/\b#{Regexp.escape(name)}\s*=\s*(["'])(.*?)\1/im)
  match && match[2]
end

["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
  errors << "HTML lacks #{label} intent comment" unless html.include?("<!-- #{label}:")
  errors << "JavaScript lacks #{label} intent comment" unless js.include?("// #{label}:")
end
errors << "semantic shell must contain lang=zh-CN, main and h1" unless
  html.match?(/<html\b[^>]*\blang=["']zh-CN["']/i) && html.match?(/<main\b/i) && html.match?(/<h1\b/i)
errors << "positive tabindex must be removed" if html.match?(/\btabindex=["'][1-9]\d*["']/i)

toggle = html.scan(/<button\b[^>]*>/i).find { |tag| attribute(tag, "id") == "toggle" }
errors << "help toggle must be a native type=button" unless attribute(toggle, "type") == "button"
panel = html[/<section\b[^>]*\bid=["']panel["'][^>]*>/i]
errors << "initial aria-expanded=false must match a hidden panel" unless attribute(toggle, "aria-expanded") == "false" && panel&.match?(/\shidden(?:\s|>)/i)
errors << "description needs an explicit visible label" unless html.match?(/<label\b[^>]*\bfor=["']description["']/i)
summary = html[/<div\b[^>]*\bid=["']error-summary["'][^>]*>/i]
errors << "error summary must be tabindex=-1 and initially hidden" unless attribute(summary, "tabindex") == "-1" && summary&.match?(/\shidden(?:\s|>)/i)
remove = html.scan(/<button\b[^>]*>.*?<\/button>/im).find { |tag| attribute(tag, "id") == "remove" }
errors << "remove button needs a visible contextual accessible name" unless remove&.match?(/移除附件 demo\.png/)
live = html[/<p\b[^>]*\bid=["']status["'][^>]*>/i]
errors << "dynamic status must use aria-live=polite" unless attribute(live, "aria-live") == "polite"

errors << "ordinary page must not intercept or trap Tab" if js.match?(/key\s*===\s*["']Tab["']|keydown/)
errors << "toggle must synchronize panel.hidden and aria-expanded" unless
  js.include?("panel.hidden = !open") && js.include?('setAttribute("aria-expanded", String(open))')
errors << "field errors need a fixed allowlist, not a server-field selector" unless js.include?("const fieldMap = Object.freeze") && !js.include?("querySelector(`#${fieldError.field}`)")
errors << "dynamic error text must use textContent, never innerHTML" unless js.include?("textContent") && !js.include?("innerHTML")
errors << "field errors must synchronize aria-invalid" unless js.include?('setAttribute("aria-invalid", "true")')
errors << "user-triggered errors must focus the summary" unless js.include?("summary.focus()")
errors << "removing the focused attachment must restore a stable focus target" unless js.include?('getElementById("attachments-heading").focus()')

errors << "positive tabindex must not be approved" unless answer["positive_tabindex_is_ok"] == false
errors << "role=button must not be treated as native behavior" unless answer["role_button_has_native_behavior"] == false
errors << "visible text must be preferred over blanket aria-label" unless answer["aria_label_is_always_better_than_visible_text"] == false
errors << "accessibility tree must remain distinct from a screen-reader task" unless answer["accessibility_tree_equals_screen_reader_task"] == false
errors << "scanner output must not be treated as WCAG conformance" unless answer["zero_scanner_findings_means_wcag_conformance"] == false
errors << "unknown server fields must degrade to the global summary" unless answer["unknown_server_field_policy"] == "global-summary"
errors << "attachment removal must restore focus to attachments-heading" unless answer["focus_after_removing_current_attachment"] == "attachments-heading"
%w[real_keyboard_observed real_accessibility_tree_observed real_screen_reader_observed].each do |field|
  errors << "#{field} must remain false in an offline answer" unless answer[field] == false
end

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "ACCESSIBILITY_INTERACTION_EXERCISE=RED (#{errors.length} violations)"
  exit 1
end

puts "native-controls-and-labels: PASS"
puts "keyboard-order-no-trap: PASS"
puts "focus-target-and-restoration: PASS"
puts "accessible-name-and-state: PASS"
puts "safe-field-error-mapping: PASS"
puts "evidence-boundaries: PASS"
puts "scope-disclosure: PASS"
puts "ACCESSIBILITY_INTERACTION_EXERCISE=PASS"
