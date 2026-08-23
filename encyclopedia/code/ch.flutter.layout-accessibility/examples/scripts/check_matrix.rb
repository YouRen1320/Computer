#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
root = File.expand_path("..", __dir__)
data = YAML.safe_load(File.read(File.join(root, "matrix.yml")))
abort "schema drift" unless data["schema"] == "factorycare.layout-a11y-matrix/v1"
cases = data.fetch("cases").to_h { |item| [item.fetch("id"), item] }
required = %w[narrow-long-text wide rtl keyboard screen-reader]
abort "missing case" unless (required - cases.keys).empty?
abort "narrow stress case too weak" unless cases.fetch("narrow-long-text").fetch("width") <= 320 && cases.fetch("narrow-long-text").fetch("text_scale") >= 2.0
abort "RTL not represented" unless cases.fetch("rtl").fetch("direction") == "rtl"
abort "repository must not claim live execution" unless cases.values.all? { |item| item.fetch("execution") == "unverified" }
live = data.dig("evidence_boundary", "live_required") || []
abort "missing live boundary" unless %w[flutter-widget-test device-smoke talkback-or-voiceover].all? { |x| live.include?(x) }
puts "PASS: layout/a11y matrix is complete and live checks remain unverified"
