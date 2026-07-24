#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

require_relative "../publication/lib/complete_renderer"

options = { check: false }
OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/build-complete-publication.rb [--check]"
  parser.on("--check", "Validate the existing complete output without rendering") { options[:check] = true }
end.parse!

begin
  root = File.expand_path("..", __dir__)
  renderer = Publication::CompleteRenderer.new(root)
  if options[:check]
    renderer.check
    puts "internal-complete publication output is valid"
  else
    result = renderer.build
    manifest = result.fetch("manifest")
    puts "built #{result.fetch('output_root')}"
    puts "outputs=#{manifest.fetch('output_count')} commands=#{manifest.fetch('commands').length} elapsed=#{result.fetch('elapsed_seconds')}s"
    puts "manifest=#{result.fetch('manifest_path')}"
  end
rescue Publication::ContractError => e
  warn e.diagnostic
  exit 1
end
