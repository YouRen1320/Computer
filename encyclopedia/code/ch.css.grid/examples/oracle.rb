#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html = File.read("index.html", encoding: "UTF-8")
css = File.read("styles.css", encoding: "UTF-8")
matrix = JSON.parse(File.read("grid-matrix.json", encoding: "UTF-8"))
errors = []

[[html, "<!--"], [css, "/*"]].each_with_index do |(document, prefix), index|
  ["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
    errors << "document #{index + 1} lacks #{label} intent comment" unless document.include?("#{prefix} #{label}:")
  end
end
errors << "semantic grid fixture drifted" unless html.match?(/<main\b[^>]*class="layout"/i) && html.match?(/<aside\b[^>]*class="detail"/i)
errors << "explicit track contract drifted" unless css.include?("grid-template-columns: 240px minmax(0, 1fr) minmax(0, 2fr);")
errors << "area template drifted" unless css.match?(/grid-template-areas:\s*"filters filters filters"\s*"list\s+content detail";/m)
errors << "layout gap/content width drifted" unless css.match?(/\.layout\s*\{[^}]*gap:\s*24px;[^}]*inline-size:\s*960px;/m)
errors << "sparse auto-placement fixture drifted" unless css.match?(/\.auto-board\s*\{[^}]*grid-template-columns:\s*repeat\(3, minmax\(0, 1fr\)\);[^}]*grid-auto-flow:\s*row;[^}]*grid-auto-rows:\s*96px;/m)

track = matrix.fetch("track_case")
leftover = track.fetch("container_content_inline") - track.fetch("fixed_tracks").sum - track.fetch("gap") * track.fetch("gap_count")
fr_unit = leftover.to_f / track.fetch("fr_factors").sum
tracks = track.fetch("fixed_tracks") + track.fetch("fr_factors").map { |factor| fr_unit * factor }
errors << "track leftover drifted" unless leftover == track.fetch("expected_leftover")
errors << "fr track calculation drifted" unless tracks == track.fetch("expected_tracks")

rows = matrix.fetch("areas").fetch("rows")
errors << "area rows must have equal column counts" unless rows.map(&:length).uniq == [3]
rows.flatten.uniq.each do |name|
  cells = []
  rows.each_with_index { |row, r| row.each_with_index { |cell, c| cells << [r, c] if cell == name } }
  rs = cells.map(&:first); cs = cells.map(&:last)
  rectangle = (rs.min..rs.max).all? { |r| (cs.min..cs.max).all? { |c| rows[r][c] == name } }
  errors << "area #{name} is not rectangular" unless rectangle
end

def place(items, columns, dense)
  occupied = {}
  cursor = 0
  items.map do |item|
    index = dense ? 0 : cursor
    loop do
      row = index / columns
      column = index % columns
      if column + item.fetch("span") <= columns && (column...(column + item.fetch("span"))).none? { |c| occupied[[row, c]] }
        (column...(column + item.fetch("span"))).each { |c| occupied[[row, c]] = true }
        cursor = index + item.fetch("span") unless dense
        break({"id"=>item.fetch("id"), "row"=>row + 1, "column"=>column + 1})
      end
      index += 1
    end
  end
end

items = matrix.fetch("auto_items")
errors << "sparse auto-placement drifted" unless place(items, 3, false) == matrix.fetch("sparse_expected")
errors << "dense auto-placement drifted" unless place(items, 3, true) == matrix.fetch("dense_expected")
subgrid = matrix.fetch("subgrid_boundary")
errors << "subgrid boundary drifted" unless subgrid == {"adopts_parent_tracks_in_selected_axis"=>true, "ordinary_nested_grid_shares_parent_tracks"=>false, "fallback_and_support_unverified"=>true}
%w[real_browser_tracks_recorded real_grid_overlay_recorded real_subgrid_recorded real_keyboard_order_recorded real_visual_diff_recorded].each do |field|
  errors << "#{field} must remain false" unless matrix[field] == false
end

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_GRID_EXAMPLE=FAIL (#{errors.length} violations)"
  exit 1
end

puts "intent-and-grid-fixture: PASS"
puts "fixed-gap-fr-tracks: PASS"
puts "rectangular-areas: PASS"
puts "sparse-dense-placement: PASS"
puts "subgrid-boundary: PASS"
puts "browser-evidence-boundary: PASS"
puts "CSS_GRID_EXAMPLE=PASS"
