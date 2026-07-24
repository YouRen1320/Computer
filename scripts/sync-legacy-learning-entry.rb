#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/legacy_week_compiler"

USAGE = "usage: ruby scripts/sync-legacy-learning-entry.rb --write|--check".freeze
mode = ARGV.first
unless ARGV.length == 1 && %w[--write --check].include?(mode)
  warn USAGE
  exit 2
end

root = File.expand_path("..", __dir__)

begin
  compiler = Curriculum::LegacyWeekCompiler.new(root: root).load_and_validate!
  if mode == "--write"
    compiler.write!
    summary = compiler.coverage_summary
    puts "legacy outcome-slice entry synchronized: weeks=#{summary['weeks']} chapters=#{summary['chapters']} primary_outcomes=#{summary['primary_outcomes']} concept-adapters=9"
  else
    compiler.check!
    summary = compiler.coverage_summary
    puts "legacy outcome-slice entry OK: weeks=#{summary['weeks']} chapters=#{summary['chapters']} primary_outcomes=#{summary['primary_outcomes']} concept-adapters=9"
  end
rescue Curriculum::LegacyWeekCompiler::ValidationError, Curriculum::DiagnosticError => error
  warn error.message
  exit 1
end
