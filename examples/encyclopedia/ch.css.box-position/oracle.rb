#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html = File.read("index.html", encoding: "UTF-8")
css = File.read("styles.css", encoding: "UTF-8")
matrix = JSON.parse(File.read("geometry-matrix.json", encoding: "UTF-8"))
errors = []

[[html, "<!--"], [css, "/*"]].each_with_index do |(document, prefix), index|
  ["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
    errors << "document #{index + 1} lacks #{label} intent comment" unless document.include?("#{prefix} #{label}:")
  end
end
errors << "semantic fixture shell drifted" unless html.match?(/<html\b[^>]*lang="zh-CN"/i) && html.match?(/<main\b/i)
errors << "both box-sizing fixtures are required" unless css.include?(".box--content { box-sizing: content-box; }") && css.include?(".box--border { box-sizing: border-box; }")
errors << "position-card must establish containing block" unless css.match?(/\.position-card\s*\{[^}]*position:\s*relative;/m)
errors << "badge must be absolute" unless css.match?(/\.position-card__badge\s*\{[^}]*position:\s*absolute;/m)
errors << "stacking fixture drifted" unless css.include?(".stack-a { position: relative; z-index: 1; }") && css.include?(".stack-a__tooltip { position: absolute; z-index: 9999; }") && css.include?(".stack-b { position: relative; z-index: 2; }")
errors << "overflow hidden/clip contrast drifted" unless css.include?("overflow: hidden") && css.include?("overflow: clip") && css.include?("display: flow-root")

matrix.fetch("boxes").each do |box|
  padding = box.fetch("padding_left") + box.fetch("padding_right")
  border = box.fetch("border_left") + box.fetch("border_right")
  margin = box.fetch("margin_left") + box.fetch("margin_right")
  if box.fetch("box_sizing") == "content-box"
    content_width = box.fetch("declared_width")
    border_width = content_width + padding + border
  else
    border_width = box.fetch("declared_width")
    content_width = [0, border_width - padding - border].max
  end
  outer_width = border_width + margin
  errors << "content width drifted for #{box.fetch('id')}" unless content_width == box.fetch("expected_content_width")
  errors << "border width drifted for #{box.fetch('id')}" unless border_width == box.fetch("expected_border_width")
  errors << "outer width drifted for #{box.fetch('id')}" unless outer_width == box.fetch("expected_outer_width")
end

blocks = matrix.fetch("containing_blocks")
errors << "absolute containing block prediction drifted" unless blocks[0] == {"target"=>".position-card__badge", "position"=>"absolute", "expected"=>".position-card", "establishing_reason"=>"position-relative"}
errors << "fixed viewport boundary missing" unless blocks[1].fetch("expected") == "layout-viewport" && blocks[1].fetch("establishing_reason") == "no-fixed-containing-block-ancestor"

tree = matrix.fetch("stacking_contexts").fetch("tree")
by_id = tree.to_h { |node| [node.fetch("id"), node] }
tooltip_parent = by_id.fetch("tooltip").fetch("parent")
root_children = tree.select { |node| node["parent"] == "root" }
front = root_children.max_by { |node| node.fetch("z_index") }.fetch("id")
errors << "tooltip must remain inside stack-a" unless tooltip_parent == "stack-a"
errors << "front context prediction drifted" unless front == matrix.fetch("stacking_contexts").fetch("expected_front_at_overlap")

overflow = matrix.fetch("overflow_cases").to_h { |item| [item.fetch("value"), item] }
errors << "hidden must remain programmatically scrollable" unless overflow.fetch("hidden").fetch("scroll_container") && overflow.fetch("hidden").fetch("programmatic_scroll")
errors << "clip must not be a scroll container" if overflow.fetch("clip").fetch("scroll_container") || overflow.fetch("clip").fetch("programmatic_scroll")
errors << "clip alone must not establish formatting context" if overflow.fetch("clip").fetch("establishes_formatting_context")

%w[real_browser_box_model_recorded real_browser_geometry_recorded real_screenshot_diff_recorded].each do |field|
  errors << "#{field} must remain false" unless matrix[field] == false
end

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_BOX_POSITION_EXAMPLE=FAIL (#{errors.length} violations)"
  exit 1
end

puts "intent-and-semantic-fixture: PASS"
puts "box-model-calculation: PASS"
puts "containing-block-prediction: PASS"
puts "stacking-context-tree: PASS"
puts "overflow-hidden-clip-boundary: PASS"
puts "browser-visual-evidence-boundary: PASS"
puts "CSS_BOX_POSITION_EXAMPLE=PASS"
