#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html = File.read("index.html", encoding: "UTF-8")
css = File.read("styles.css", encoding: "UTF-8")
faults = JSON.parse(File.read("faults.json", encoding: "UTF-8"))
matrix = JSON.parse(File.read("observation-matrix.json", encoding: "UTF-8"))
errors = []

[[html, "<!--"], [css, "/*"]].each_with_index do |(document, prefix), index|
  ["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
    errors << "document #{index + 1} lacks #{label} intent comment" unless document.include?("#{prefix} #{label}:")
  end
end
errors << "semantic work layout drifted" unless html.match?(/<main\b[^>]*class="work-layout"/i) && html.match?(/<aside\b[^>]*class="detail"/i)
errors << "min-content track repair missing" unless css.include?("grid-template-columns: 240px minmax(0, 1fr);")
errors << "area name repair missing" unless css.match?(/grid-template-areas:\s*"filters filters"\s*"orders\s+detail";/m) && %w[filters orders detail].all? { |name| css.match?(/\.#{name}\s*\{\s*grid-area:\s*#{name};/) }
errors << "item min-inline-size repair missing" unless css.match?(/\.orders\s*\{[^}]*min-inline-size:\s*0;[^}]*overflow-wrap:\s*anywhere;/m)
errors << "implicit row contract drifted" unless css.match?(/\.auto-list\s*\{[^}]*grid-template-columns:\s*repeat\(3, minmax\(0, 1fr\)\);[^}]*grid-template-rows:\s*80px;[^}]*grid-auto-flow:\s*row;[^}]*grid-auto-rows:\s*80px;/m)

track = matrix.fetch("track_case")
flexible = track.fetch("container_content_inline") - track.fetch("fixed") - track.fetch("gap")
errors << "flexible track calculation drifted" unless flexible == track.fetch("expected_flexible") && track.fetch("fixed") + track.fetch("gap") + flexible == track.fetch("expected_total")
rows = matrix.fetch("area_case").fetch("rows")
errors << "area row width drifted" unless rows.map(&:length).uniq == [2]
rows.flatten.uniq.each do |name|
  cells = []
  rows.each_with_index { |row, r| row.each_with_index { |cell, c| cells << [r, c] if cell == name } }
  rs = cells.map(&:first); cs = cells.map(&:last)
  rectangle = (rs.min..rs.max).all? { |r| (cs.min..cs.max).all? { |c| rows[r][c] == name } }
  errors << "area #{name} must be rectangular" unless rectangle
end
implicit = matrix.fetch("implicit_case")
rows_needed = (implicit.fetch("item_count").to_f / implicit.fetch("explicit_columns")).ceil
errors << "implicit track prediction drifted" unless implicit.fetch("expected_implicit_columns") == 0 && implicit.fetch("expected_implicit_rows") == [rows_needed - 1, 0].max && implicit.fetch("grid_auto_rows") == 80

expected_faults = %w[implicit-column-drift min-content-overflow area-name-mismatch]
errors << "fault inventory drifted" unless faults.fetch("faults").map { |item| item.fetch("id") } == expected_faults
faults.fetch("faults").each do |fault|
  %w[injected_change expected_failure first_trusted_evidence root_cause repair rerun residual_risk].each do |field|
    errors << "#{fault.fetch('id')} lacks #{field}" if fault.fetch(field).strip.empty?
  end
  errors << "#{fault.fetch('id')} must rerun same verifier" unless fault.fetch("rerun").include?("same verify.sh")
end
%w[real_browser_tracks_recorded real_grid_overlay_recorded real_keyboard_order_recorded real_visual_diff_recorded].each do |field|
  errors << "#{field} must remain false" unless matrix[field] == false
end
required = matrix.fetch("required_real_evidence")
errors << "real evidence checklist drifted" unless %w[browser-name-version grid-overlay dom-visual-tab-order visual-diff].all? { |item| required.include?(item) }

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "CSS_GRID_LAB=FAIL (#{errors.length} violations)"
  exit 1
end

puts "intent-and-grid-layout: PASS"
puts "track-and-min-content-repair: PASS"
puts "rectangular-area-contract: PASS"
puts "implicit-row-contract: PASS"
puts "fault-rerun-records: PASS"
puts "browser-evidence-boundary: PASS"
puts "CSS_GRID_LAB=PASS"
