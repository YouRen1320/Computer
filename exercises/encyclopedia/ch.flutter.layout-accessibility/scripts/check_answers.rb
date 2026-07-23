#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
root = File.expand_path("..", __dir__)
answers = YAML.safe_load(File.read(File.join(root, "answers.yml"))).fetch("answers")
todo = answers.flat_map { |id, fields| fields.map { |key, value| "#{id}.#{key}" if value == "TODO" } }.compact
abort "EXPECTED RED: complete #{todo.join(', ')}" unless todo.empty?
oracle = {
  "row-overflow" => {"first_evidence" => "renderflex-direction-and-constraints", "fix" => "allocate-or-reflow-content"},
  "flex-in-unbounded-scroll-axis" => {"first_evidence" => "unbounded-flex-exception-and-scroll-ancestor", "fix" => "choose-one-scroll-owner-and-finite-flex-contract"},
  "icon-only-custom-tap-target" => {"first_evidence" => "semantics-and-hit-target-inspection", "fix" => "semantic-button-with-name-and-minimum-target"},
  "fixed-height-large-text" => {"first_evidence" => "large-text-overflow-at-fixed-height", "fix" => "allow-natural-growth-and-responsive-reflow"}
}
abort "answers differ from oracle" unless answers == oracle
puts "PASS: layout diagnoses are evidence based"
