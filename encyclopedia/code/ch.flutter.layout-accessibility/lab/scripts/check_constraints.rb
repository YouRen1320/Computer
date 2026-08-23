#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
root = File.expand_path("..", __dir__)
data = YAML.safe_load(File.read(File.join(root, "boxes.yml")))
viewport = data.fetch("viewport")
abort "viewport must be tight" unless viewport.fetch("min_width") == viewport.fetch("max_width")
row_width = viewport.fetch("max_width") - data.dig("padding", "start") - data.dig("padding", "end")
fixed = data.dig("row", "fixed_children").sum { |item| item.fetch("reported_width") }
gap = data.dig("row", "gap")
title_max = row_width - fixed - gap
title_width = data.dig("row", "flex_child", "reported_width")
abort "child violates constraints: #{title_width} > #{title_max}" unless title_width.between?(0, title_max)
oracle = data.fetch("oracle")
abort "row oracle drift" unless row_width == oracle.fetch("row_width")
abort "title oracle drift" unless title_max == oracle.fetch("title_max_width")
puts "PASS: constraints go down, chosen sizes stay in range, parent owns position"
