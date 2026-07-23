#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
root = File.expand_path("..", __dir__)
actual = YAML.safe_load(File.read(File.join(root, "cases.yml"))).fetch("cases")
oracle = {
  "build-method-text" => ["hot-reload", true],
  "initState-initial-value" => ["hot-restart", false],
  "android-manifest-permission" => ["full-rebuild", false],
  "native-plugin-registration" => ["full-rebuild", false]
}

actual.each do |item|
  expected = oracle.fetch(item.fetch("change"))
  got = [item.fetch("minimum_action"), item.fetch("preserves_dart_state")]
  abort "FAIL #{item['change']}: expected #{expected.inspect}, got #{got.inspect}" unless got == expected
end
abort "missing cases" unless actual.length == oracle.length
puts "PASS: reload/restart/rebuild decisions match the oracle"
