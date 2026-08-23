#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html = File.read("index.html", encoding: "UTF-8")
css = File.read("styles.css", encoding: "UTF-8")
matrix = JSON.parse(File.read("theme-matrix.json", encoding: "UTF-8"))
errors = []

[[html, "<!--"], [css, "/*"]].each_with_index do |(document, prefix), index|
  ["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
    errors << "document #{index + 1} lacks #{label} intent comment" unless document.include?("#{prefix} #{label}:")
  end
end

errors << "semantic theme fixture drifted" unless html.match?(/<main\b[^>]*class="page-shell"/i) && html.match?(/<section\b[^>]*danger-zone/i)
errors << "root light token contract drifted" unless css.match?(/:root\s*\{[^}]*color-scheme:\s*light dark;[^}]*--color-canvas:\s*#ffffff;[^}]*--color-text:\s*#172033;/m)
errors << "dark preference contract drifted" unless css.match?(/@media\s*\(prefers-color-scheme:\s*dark\)\s*\{\s*:root\s*\{[^}]*--color-canvas:\s*#0f172a;[^}]*--color-text:\s*#f8fafc;/m)
errors << "explicit light override drifted" unless css.include?(':root[data-theme="light"]')
errors << "explicit dark override drifted" unless css.include?(':root[data-theme="dark"]')
errors << "nested fallback contract drifted" unless css.include?("var(--panel-surface, var(--color-surface, Canvas))")
errors << "local override contract drifted" unless css.match?(/\.danger-zone\s*\{[^}]*--color-accent:\s*#b42318;[^}]*--color-on-accent:\s*#ffffff;/m)
errors << "forced colors contract drifted" unless css.match?(/@media\s*\(forced-colors:\s*active\)[\s\S]*CanvasText[\s\S]*ButtonText[\s\S]*Highlight/m)
errors << "global forced-color opt-out is forbidden" if css.match?(/:root\s*\{[^}]*forced-color-adjust:\s*none/m)

expected_light = {"canvas"=>"#ffffff", "text"=>"#172033", "surface"=>"#f4f7fb", "accent"=>"#0b5cad", "on_accent"=>"#ffffff"}
expected_dark = {"canvas"=>"#0f172a", "text"=>"#f8fafc", "surface"=>"#1e293b", "accent"=>"#60a5fa", "on_accent"=>"#0f172a"}
errors << "light scenario drifted" unless matrix.dig("scenarios", "light") == expected_light
errors << "dark scenario drifted" unless matrix.dig("scenarios", "dark") == expected_dark
errors << "explicit override matrix drifted" unless matrix.dig("scenarios", "explicit_override") == {
  "system_dark_plus_data_theme_light_resolves_to"=>"light",
  "system_light_plus_data_theme_dark_resolves_to"=>"dark"
}
errors << "missing token matrix drifted" unless matrix.dig("scenarios", "missing_token", "missing_both_resolves_to") == "Canvas"
errors << "local override leaked to sibling" unless matrix.dig("scenarios", "local_override", "sibling_inherits_override") == false

def relative_luminance(hex)
  channels = hex.delete_prefix("#").scan(/../).map { |pair| pair.to_i(16) / 255.0 }
  linear = channels.map { |value| value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4 }
  0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
end

ratios = {}
matrix.fetch("contrast_cases").each do |entry|
  foreground = relative_luminance(entry.fetch("foreground"))
  background = relative_luminance(entry.fetch("background"))
  lighter, darker = [foreground, background].sort.reverse
  ratio = (lighter + 0.05) / (darker + 0.05)
  ratios[entry.fetch("id")] = ratio
  errors << "contrast #{entry.fetch('id')} below #{entry.fetch('minimum')}" unless ratio >= entry.fetch("minimum")
end

expected_ratios = {"light-body"=>16.2685, "dark-body"=>17.0629, "light-action"=>6.6698, "dark-action"=>7.0219, "danger-action"=>6.5743}
expected_ratios.each do |id, expected|
  errors << "contrast #{id} calculation drifted" unless (ratios.fetch(id) - expected).abs < 0.0001
end

forced = matrix.fetch("forced_colors")
errors << "forced colors query drifted" unless forced.fetch("query") == "forced-colors: active"
errors << "forced colors must not globally opt out" unless forced.fetch("global_opt_out") == false
%w[real_browser_computed_recorded real_forced_colors_recorded real_wide_gamut_recorded real_screen_reader_recorded real_visual_review_recorded].each do |field|
  errors << "#{field} must remain false until real evidence exists" unless matrix[field] == false
end

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_THEME_EXAMPLE=FAIL (#{errors.length} violations)"
  exit 1
end

puts "intent-and-theme-source: PASS"
puts "scope-fallback-override-matrix: PASS"
puts "contrast light-body=16.2685 dark-body=17.0629: PASS"
puts "contrast light-action=6.6698 dark-action=7.0219 danger-action=6.5743: PASS"
puts "forced-colors-boundary: PASS"
puts "browser-evidence-boundary: PASS"
puts "CSS_THEME_EXAMPLE=PASS"
