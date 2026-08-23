#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

root = File.expand_path("..", __dir__)
contract = YAML.safe_load(File.read(File.join(root, "evidence-contract.yml")))
abort "wrong schema" unless contract["schema"] == "factorycare.flutter-toolchain-evidence/v1"
abort "unexpected Flutter surface" unless contract.dig("version_surface", "flutter") == "3.44.x"

ids = contract.fetch("required_evidence").map { |item| item.fetch("id") }
expected = %w[sdk-resolution doctor devices analyze-test run reload-contrast]
abort "missing evidence step: #{expected - ids}" unless (expected - ids).empty?
abort "live evidence must start pending" unless contract["actual"] == "pending"

forbidden = contract.dig("redaction", "forbidden_fields") || []
abort "redaction contract incomplete" unless %w[token password cookie private_key].all? { |key| forbidden.include?(key) }

puts "PASS: offline evidence contract is complete; device execution remains explicitly unverified"
