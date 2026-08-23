#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html = File.read("index.html", encoding: "UTF-8")
js = File.read("interaction.js", encoding: "UTF-8")
problem = JSON.parse(File.read("problem.json", encoding: "UTF-8"))
matrix = JSON.parse(File.read("audit-matrix.json", encoding: "UTF-8"))
errors = []

def attribute(tag, name)
  match = tag.to_s.match(/\b#{Regexp.escape(name)}\s*=\s*(["'])(.*?)\1/im)
  match && match[2]
end

["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
  errors << "HTML lacks #{label} intent comment" unless html.include?("<!-- #{label}:")
  errors << "JavaScript lacks #{label} intent comment" unless js.include?("// #{label}:")
end
errors << "semantic shell and skip link drifted" unless
  html.match?(/<html\b[^>]*\blang=["']zh-CN["']/i) && html.match?(/<main\b[^>]*\bid=["']main["']/i) &&
  html.match?(/<h1\b/i) && html.match?(/<a\b[^>]*\bhref=["']#main["']/i)
errors << "positive tabindex is forbidden" if html.match?(/\btabindex=["'](?:[1-9]\d*)["']/i)
errors << "div/span role=button must not replace native button" if html.match?(/<(?:div|span)\b[^>]*\brole=["']button["']/i)

toggle = html.scan(/<button\b[^>]*>/i).find { |tag| attribute(tag, "id") == "instructions-toggle" }
errors << "toggle native button contract drifted" unless
  attribute(toggle, "type") == "button" && attribute(toggle, "aria-expanded") == "false" &&
  attribute(toggle, "aria-controls") == "instructions-panel"
errors << "controlled instructions panel must start hidden" unless html.match?(/<section\b[^>]*\bid=["']instructions-panel["'][^>]*\shidden(?:\s|>)/i)

%w[asset-id description].each do |id|
  errors << "#{id} needs an explicit visible label" unless html.match?(/<label\b[^>]*\bfor=["']#{id}["'][^>]*>/i)
  control = html.scan(/<(?:input|textarea)\b[^>]*>/i).find { |tag| attribute(tag, "id") == id }
  errors << "#{id} needs required and aria-describedby" unless control&.match?(/\srequired(?:\s|>|=)/i) && attribute(control, "aria-describedby")
end
summary = html[/<div\b[^>]*\bid=["']error-summary["'][^>]*>/i]
errors << "error summary must be script-focusable and initially hidden" unless attribute(summary, "tabindex") == "-1" && summary&.match?(/\shidden(?:\s|>)/i)
live = html[/<p\b[^>]*\bid=["']submit-status["'][^>]*>/i]
errors << "submit status needs a polite live region" unless attribute(live, "aria-live") == "polite" && attribute(live, "aria-atomic") == "true"

errors << "JavaScript needs a fixed fieldMap allowlist" unless js.include?("const fieldMap = Object.freeze") && js.include?("assetId:") && js.include?("description:")
errors << "dynamic messages must use textContent, not innerHTML" unless js.include?("textContent") && !js.include?("innerHTML")
errors << "field errors must synchronize aria-invalid" unless js.include?('setAttribute("aria-invalid", "true")') && js.include?('removeAttribute("aria-invalid")')
errors << "toggle must synchronize hidden and aria-expanded" unless js.include?("panel.hidden = !willOpen") && js.include?('setAttribute("aria-expanded", String(willOpen))')
errors << "user-triggered server errors must focus the summary" unless js.include?("summary.focus()")
errors << "script must not trap Tab" if js.match?(/keydown[\s\S]{0,300}(?:key\s*===\s*["']Tab["']|preventDefault\(\))/)

errors << "Problem shape drifted" unless
  problem.fetch("status") == 400 && problem.fetch("fieldErrors").map { |item| item.fetch("field") } == %w[assetId description]
expected_steps = %w[skip-link toggle-open field-names native-invalid server-errors reverse-exit]
errors << "audit task inventory drifted" unless matrix.fetch("steps").map { |item| item.fetch("id") } == expected_steps
%w[real_keyboard_observed real_accessibility_tree_observed real_screen_reader_observed].each do |field|
  errors << "#{field} must remain false in offline evidence" unless matrix[field] == false
end

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "ACCESSIBILITY_INTERACTION_EXAMPLE=FAIL (#{errors.length} violations)"
  exit 1
end

puts "native-semantics-and-labels: PASS"
puts "keyboard-order-no-positive-tabindex: PASS"
puts "focus-targets-and-restoration-contract: PASS"
puts "accessible-name-description-state: PASS"
puts "problem-field-allowlist: PASS"
puts "safe-dynamic-error-update: PASS"
puts "audit-task-matrix: PASS"
puts "scope-disclosure: PASS"
puts "ACCESSIBILITY_INTERACTION_EXAMPLE=PASS"
