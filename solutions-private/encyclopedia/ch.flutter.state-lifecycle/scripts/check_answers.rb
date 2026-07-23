#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
root = File.expand_path("..", __dir__)
answers = YAML.safe_load(File.read(File.join(root, "answers.yml"))).fetch("answers")
oracle = {
  "mounted_is_boolean" => true,
  "mounted_means_route_is_visible" => false,
  "mounted_cancels_http" => false,
  "mounted_prevents_duplicate_calls" => false,
  "mounted_can_guard_post_dispose_set_state" => true,
  "finally_needs_operation_identity_check" => true,
  "dispose_should_release_owned_resources" => true,
  "stable_key_keeps_state_with_business_item" => true
}
abort "private solution drift" unless answers == oracle
puts "PASS: private lifecycle solution"
