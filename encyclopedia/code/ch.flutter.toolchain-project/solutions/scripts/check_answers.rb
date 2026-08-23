#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
root = File.expand_path("..", __dir__)
answers = YAML.safe_load(File.read(File.join(root, "answers.yml"))).fetch("answers")
oracle = {
  "wrong-sdk" => {"first_stage" => "sdk-resolution", "first_evidence" => "type-a-and-version", "recovery" => "align-terminal-ide-ci-sdk"},
  "missing-device" => {"first_stage" => "target-selection", "first_evidence" => "flutter-devices", "recovery" => "select-valid-device-id"},
  "changed-native-permission-after-reload" => {"first_stage" => "platform-runtime", "first_evidence" => "platform-config-and-run-log", "recovery" => "full-rebuild"}
}
abort "private solution drift" unless answers == oracle
puts "PASS: private toolchain diagnosis solution"
