#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

ROOT = File.expand_path("..", __dir__)

require File.join(ROOT, "publication", "lib", "atomic_tree_writer")
require File.join(ROOT, "publication", "lib", "plan_builder")

options = { check: false }
parser = OptionParser.new do |command|
  command.banner = "Usage: ruby scripts/build-publication-plan.rb --profile PATH [--check]"
  command.on("--profile PATH", "Repository-relative publication profile") do |path|
    options[:profile] = path
  end
  command.on("--check", "Verify that the committed sidecar bytes are current") do
    options[:check] = true
  end
end

begin
  parser.parse!(ARGV)
  raise OptionParser::InvalidArgument, "unexpected positional arguments" unless ARGV.empty?
  raise OptionParser::MissingArgument, "--profile" unless options[:profile]

  builder = Publication::PlanBuilder.new(ROOT, profile_path: options.fetch(:profile))
  plan = builder.build
  rendered = builder.render(plan)
  writer = Publication::AtomicTreeWriter.new(ROOT)

  if options.fetch(:check)
    writer.check(plan.fetch("profile_id"), rendered)
    result = "PUBLICATION PLAN CHECK OK"
  else
    writer.write(plan.fetch("profile_id"), rendered)
    result = "PUBLICATION PLAN OK"
  end

  puts result
  puts "profile=#{plan.fetch('profile_id')} chapters=#{plan.fetch('chapters').length} inputs=#{plan.fetch('input_count')}"
rescue OptionParser::ParseError => e
  warn "PUBLICATION PLAN FAILED: invalid command-line arguments (#{e.class})"
  warn parser
  exit 2
rescue Publication::ContractError => e
  warn "PUBLICATION PLAN FAILED: #{e.diagnostic}"
  exit 1
rescue StandardError => e
  # Unexpected failures identify only the class so local paths or content are
  # not copied into CI logs before a maintainer performs a private diagnosis.
  warn "PUBLICATION PLAN FAILED: [internal/E_UNEXPECTED] #{e.class}"
  exit 1
end
