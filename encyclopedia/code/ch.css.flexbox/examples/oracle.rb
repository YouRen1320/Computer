#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html = File.read("index.html", encoding: "UTF-8")
css = File.read("styles.css", encoding: "UTF-8")
matrix = JSON.parse(File.read("layout-matrix.json", encoding: "UTF-8"))
errors = []

[[html, "<!--"], [css, "/*"]].each_with_index do |(document, prefix), index|
  ["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
    errors << "document #{index + 1} lacks #{label} intent comment" unless document.include?("#{prefix} #{label}:")
  end
end
errors << "semantic toolbar fixture drifted" unless html.match?(/<form\b[^>]*class="toolbar"/i) && html.scan(/<button\b/i).length == 2
errors << "toolbar flex contract drifted" unless css.match?(/\.toolbar\s*\{[^}]*display:\s*flex;[^}]*flex-flow:\s*row wrap;[^}]*align-items:\s*end;[^}]*gap:\s*16px;/m)
errors << "auto-min repair missing" unless css.match?(/\.toolbar__query\s*\{[^}]*flex:\s*1 1 288px;[^}]*min-inline-size:\s*0;/m)
errors << "card wrapping contract drifted" unless css.match?(/\.card-row\s*\{[^}]*display:\s*flex;[^}]*flex-wrap:\s*wrap;[^}]*gap:\s*16px;/m)
errors << "visual order properties are forbidden in this fixture" if css.match?(/(?:^|[;{\s])order\s*:|row-reverse|column-reverse/m)

grow = matrix.fetch("grow_case")
free = grow.fetch("container_main") - grow.fetch("gap_total") - grow.fetch("bases").sum
sum = grow.fetch("grow").sum.to_f
targets = grow.fetch("bases").zip(grow.fetch("grow")).map { |base, factor| base + free * factor / sum }
errors << "grow free space drifted" unless free == grow.fetch("expected_free_space")
errors << "grow targets drifted" unless targets == grow.fetch("expected_targets")

shrink = matrix.fetch("shrink_case")
negative = shrink.fetch("container_main") - shrink.fetch("gap_total") - shrink.fetch("bases").sum
scaled = shrink.fetch("bases").zip(shrink.fetch("shrink")).map { |base, factor| base * factor }
targets = shrink.fetch("bases").zip(scaled).map { |base, factor| base + negative * factor / scaled.sum.to_f }
errors << "negative free space drifted" unless negative == shrink.fetch("expected_negative_space")
targets.zip(shrink.fetch("expected_targets")).each_with_index do |(actual, expected), index|
  errors << "shrink target #{index} drifted" if (actual - expected).abs > shrink.fetch("tolerance")
end

def collect_lines(width, item_size, gap, count)
  lines = [[]]
  count.times do |index|
    used = lines.last.length * item_size + [lines.last.length - 1, 0].max * gap
    needed = lines.last.empty? ? item_size : gap + item_size
    lines << [] if !lines.last.empty? && used + needed > width
    lines.last << index
  end
  lines
end

matrix.fetch("wrap_cases").each do |item|
  actual = collect_lines(item.fetch("container_main"), item.fetch("item_outer_hypothetical"), item.fetch("gap"), item.fetch("item_count"))
  errors << "wrap case #{item.fetch('container_main')} drifted" unless actual == item.fetch("expected_lines")
end
order = matrix.fetch("order_case")
errors << "DOM/visual/tab order must remain aligned" unless order.fetch("dom") == order.fetch("visual") && order.fetch("dom") == order.fetch("tab")
alignment = matrix.fetch("alignment_case")
errors << "alignment pipeline drifted" unless alignment == {"justify_content_stage"=>"after-flexing", "align_content_requires_multiple_lines"=>true, "auto_margin_precedes_justify_content"=>true}
%w[real_browser_computed_style_recorded real_flex_overlay_recorded real_keyboard_order_recorded real_visual_diff_recorded].each do |field|
  errors << "#{field} must remain false" unless matrix[field] == false
end

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_FLEXBOX_EXAMPLE=FAIL (#{errors.length} violations)"
  exit 1
end

puts "intent-and-flex-fixture: PASS"
puts "positive-free-space-grow: PASS"
puts "scaled-shrink: PASS"
puts "line-collection-and-gap: PASS"
puts "alignment-and-order-boundary: PASS"
puts "browser-evidence-boundary: PASS"
puts "CSS_FLEXBOX_EXAMPLE=PASS"
