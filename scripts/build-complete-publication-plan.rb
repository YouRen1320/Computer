#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

require_relative "../publication/lib/complete_plan_builder"

options = { check: false }
OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/build-complete-publication-plan.rb [--check]"
  parser.on("--check", "Verify the canonical plan without replacing rendered outputs") { options[:check] = true }
end.parse!

begin
  root = File.expand_path("..", __dir__)
  builder = Publication::CompletePlanBuilder.new(root)
  plan = builder.build
  if options[:check]
    builder.check(plan)
    puts "internal-complete publication plan is canonical"
  else
    path = builder.write(plan)
    puts "wrote #{path} (#{plan.fetch('chapters').length} chapters, #{plan.fetch('volumes').length} volumes, #{plan.fetch('companions').length} tracked companions)"
  end
rescue Publication::ContractError => e
  warn e.diagnostic
  exit 1
end
