#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "optparse"
require "tempfile"
require "yaml"

require_relative "lib/curriculum_compiler"

options = {}
OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/capture-curriculum-migration-plan.rb --output PATH"
  parser.on("--output PATH", "new plan evidence file") { |value| options[:output] = value }
end.parse!

abort "--output is required" unless options[:output]
root = File.expand_path("..", __dir__)
output = File.expand_path(options.fetch(:output), root)
abort "refusing to overwrite existing plan evidence: #{output}" if File.exist?(output) || File.symlink?(output)

evidence = Curriculum::Generator.new(root: root, mode: :plan).capture_plan_evidence
body = Psych.dump(evidence, nil, line_width: -1)
Curriculum::StrictYaml.load(body, display_path: output)
FileUtils.mkdir_p(File.dirname(output))
temp = Tempfile.new([".migration-plan-", ".yml"], File.dirname(output))
begin
  temp.binmode
  temp.write(body)
  temp.flush
  temp.fsync
  temp.close
  File.rename(temp.path, output)
ensure
  temp.close! if temp
end

puts "MIGRATION PLAN EVIDENCE OK"
puts "path=#{output}"
puts "plan_digest=#{evidence.fetch('plan').fetch('plan_digest')}"
