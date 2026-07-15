#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/curriculum_compiler"

USAGE = "Usage: ruby scripts/generate-curriculum.rb (--plan|--check|--write)".freeze
MODES = {
  "--plan" => :plan,
  "--check" => :check,
  "--write" => :write
}.freeze

unless ARGV.length == 1 && MODES.key?(ARGV.first)
  warn USAGE
  exit 2
end

root = File.expand_path("..", __dir__)
exit Curriculum::Generator.new(root: root, mode: MODES.fetch(ARGV.first)).run
