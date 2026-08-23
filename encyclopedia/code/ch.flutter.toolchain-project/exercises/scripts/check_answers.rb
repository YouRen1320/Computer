#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
root = File.expand_path("..", __dir__)
answers = YAML.safe_load(File.read(File.join(root, "answers.yml"))).fetch("answers")
todo = answers.flat_map { |id, fields| fields.map { |key, value| "#{id}.#{key}" if value == "TODO" } }.compact
abort "EXPECTED RED: complete #{todo.join(', ')}" unless todo.empty?

oracle = {
  "wrong-sdk" => {"first_stage" => "sdk-resolution", "first_evidence" => "type-a-and-version", "recovery" => "align-terminal-ide-ci-sdk"},
  "missing-device" => {"first_stage" => "target-selection", "first_evidence" => "flutter-devices", "recovery" => "select-valid-device-id"},
  "changed-native-permission-after-reload" => {"first_stage" => "platform-runtime", "first_evidence" => "platform-config-and-run-log", "recovery" => "full-rebuild"}
}
abort "answers differ from oracle" unless answers == oracle
puts "PASS: diagnosis matrix is correct"
