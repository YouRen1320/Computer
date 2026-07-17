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

errors << "nested fallback contract missing" unless css.include?("var(--panel-surface, var(--color-surface, Canvas))")
errors << "local override must be scoped to .danger-zone" unless css.match?(/\.danger-zone\s*\{[^}]*--color-accent:\s*#b42318;[^}]*--color-on-accent:\s*#ffffff;/m) && !css.match?(/\.page-shell\s*\{[^}]*--color-accent:/m)
errors << "dark preference contract missing" unless css.match?(/@media\s*\(prefers-color-scheme:\s*dark\)[\s\S]*--color-canvas:\s*#0f172a;[\s\S]*--color-on-accent:\s*#0f172a;/m)
errors << "explicit light override missing" unless css.include?(':root[data-theme="light"]')
errors << "forced colors system mapping missing" unless css.match?(/@media\s*\(forced-colors:\s*active\)[\s\S]*CanvasText[\s\S]*ButtonText/m)
errors << "global forced-color-adjust opt-out forbidden" if css.match?(/:root\s*\{[^}]*forced-color-adjust:\s*none;/m)

root = css.match(/:root\s*\{(?<body>[^}]*)\}/m)&.named_captures&.fetch("body", "") || ""
foreground = root[/--color-text:\s*(#[0-9a-fA-F]{6})/, 1]
background = root[/--color-canvas:\s*(#[0-9a-fA-F]{6})/, 1]

def luminance(hex)
  channels = hex.delete_prefix("#").scan(/../).map { |pair| pair.to_i(16) / 255.0 }
  linear = channels.map { |value| value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4 }
  0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
end

if foreground && background
  light, dark = [luminance(foreground), luminance(background)].sort.reverse
  ratio = (light + 0.05) / (dark + 0.05)
  errors << format("root body contrast %.4f is below %.1f", ratio, matrix.fetch("minimum_body_contrast")) unless ratio >= matrix.fetch("minimum_body_contrast")
else
  errors << "root opaque sRGB body pair missing"
end

%w[real_browser_computed_recorded real_forced_colors_recorded real_screen_reader_recorded].each do |field|
  errors << "#{field} must remain false until real evidence exists" unless matrix[field] == false
end

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_THEME_EXERCISE=FAIL (#{errors.length} violations)"
  exit 1
end

puts "theme-source-and-intent: PASS"
puts "scope-and-fallback-contract: PASS"
puts "dark-and-explicit-override-contract: PASS"
puts "forced-colors-boundary: PASS"
puts "root-body-contrast: PASS"
puts "browser-evidence-boundary: PASS"
puts "CSS_THEME_EXERCISE=PASS"
