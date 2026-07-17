#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html = File.read("index.html", encoding: "UTF-8")
css = File.read("styles.css", encoding: "UTF-8")
matrix = JSON.parse(File.read("matrix.json", encoding: "UTF-8"))
errors = []

[html, css].each_with_index do |document, index|
  ["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
    marker = index.zero? ? "<!-- #{label}:" : "/* #{label}:"
    errors << "document #{index + 1} lacks #{label} intent comment" unless document.include?(marker)
  end
end

errors << "semantic fixture shell drifted" unless html.match?(/<html\b[^>]*lang="zh-CN"/i) && html.match?(/<main\b[^>]*id="app"/i)
errors << "layer declaration drifted" unless css.include?("@layer reset, base, components, utilities;")
errors << "fixture must expose severity state" unless html.include?('data-severity="high"')
errors << "fixture must include disabled pseudo-class target" unless html.match?(/<button\b[^>]*\bdisabled\b/i)

def strip_function(selector, name)
  loop do
    start = selector.index(":#{name}(")
    break selector unless start
    cursor = start + name.length + 2
    depth = 1
    cursor += 1 while cursor < selector.length && depth.positive? && (depth += 1 if selector[cursor] == "("; depth -= 1 if selector[cursor] == ")"; depth.positive?)
    content = selector[(start + name.length + 2)...(cursor - 1)]
    replacement = block_given? ? yield(content) : ""
    selector = selector[0...start] + replacement + selector[cursor..]
  end
end

def specificity(selector)
  work = strip_function(selector.dup, "where") { "" }
  %w[is not has].each do |name|
    work = strip_function(work, name) do |content|
      best = content.split(",").map { |part| specificity(part.strip) }.max || [0, 0, 0]
      ("#x" * best[0]) + (".x" * best[1]) + (" x" * best[2])
    end
  end
  ids = work.scan(/#[\w-]+/).length
  classes = work.scan(/\.[\w-]+/).length + work.scan(/\[[^\]]+\]/).length
  pseudos = work.scan(/(?<!:):(?!:)[\w-]+(?:\([^)]*\))?/).length
  pseudo_elements = work.scan(/::[\w-]+/).length
  cleaned = work.gsub(/#[\w-]+|\.[\w-]+|\[[^\]]+\]|::?[\w-]+(?:\([^)]*\))?|[*>+~]/, " ")
  types = cleaned.scan(/(?:^|\s)([a-zA-Z][\w-]*)/).length
  [ids, classes + pseudos, types + pseudo_elements]
end

matrix.fetch("specificity_cases").each do |item|
  actual = specificity(item.fetch("selector"))
  errors << "specificity drift for #{item.fetch('selector')}: #{actual.inspect}" unless actual == item.fetch("expected")
end

LEVEL = {
  "ua-normal" => 0,
  "user-normal" => 1,
  "author-normal" => 2,
  "animation" => 3,
  "author-important" => 4,
  "user-important" => 5,
  "ua-important" => 6,
  "transition" => 7
}.freeze

layers = matrix.fetch("layer_order")
def rank(candidate, layers)
  level = LEVEL.fetch(candidate.fetch("level"))
  layer_index = layers.index(candidate.fetch("layer")) || -1
  important = candidate.fetch("level").end_with?("important")
  effective_layer = important ? -layer_index : layer_index
  [level, effective_layer, *candidate.fetch("specificity"), candidate.fetch("order")]
end

matrix.fetch("cascade_cases").each do |item|
  sorted = item.fetch("candidates").sort_by { |candidate| rank(candidate, layers) }.reverse
  errors << "cascade winner drifted for #{item.fetch('id')}" unless sorted[0].fetch("value") == item.fetch("expected")
  errors << "remove-winner prediction drifted for #{item.fetch('id')}" unless sorted[1].fetch("value") == item.fetch("after_remove_expected")
end

matrix.fetch("defaulting_cases").each do |item|
  actual = case item["keyword"]
           when "inherit" then item.fetch("parent_computed")
           when "initial" then item.fetch("initial")
           when "unset" then item.fetch("property_inherited") ? item.fetch("parent_computed") : item.fetch("initial")
           else item.fetch("property_inherited") ? item.fetch("parent_computed") : item.fetch("initial")
           end
  errors << "defaulting drifted for #{item.fetch('id')}" unless actual == item.fetch("expected")
end

errors << "matrix must not claim browser computed style" unless matrix["real_browser_computed_style_recorded"] == false
errors << "matrix must not claim visual diff" unless matrix["real_visual_diff_recorded"] == false

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_CASCADE_EXAMPLE=FAIL (#{errors.length} violations)"
  exit 1
end

puts "intent-and-semantic-fixture: PASS"
puts "specificity-matrix: PASS"
puts "origin-layer-order-matrix: PASS"
puts "remove-winner-prediction: PASS"
puts "inheritance-defaulting-matrix: PASS"
puts "browser-evidence-boundary: PASS"
puts "CSS_CASCADE_EXAMPLE=PASS"
