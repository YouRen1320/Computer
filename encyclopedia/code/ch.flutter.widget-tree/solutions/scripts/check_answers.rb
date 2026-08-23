#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
root = File.expand_path("..", __dir__)
answers = YAML.safe_load(File.read(File.join(root, "answers.yml"))).fetch("answers")
oracle = {
  "widget_is_mutable_screen_object" => false,
  "context_can_find_descendant" => false,
  "stateless_widget_can_rebuild" => true,
  "build_may_run_many_times" => true,
  "stable_value_key_can_follow_order_id" => true,
  "hot_reload_always_recreates_state" => false
}
abort "private solution drift" unless answers == oracle
puts "PASS: private widget-tree solution"
