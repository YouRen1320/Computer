#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
root = File.expand_path("..", __dir__)
data = YAML.safe_load(File.read(File.join(root, "operations.yml")))
mounted = data.fetch("initial_mounted")
current = nil
visible = []
committed = []
ignored = []

data.fetch("events").each do |event|
  case event.fetch("type")
  when "start" then current = event.fetch("operation")
  when "complete"
    if mounted && current == event.fetch("operation")
      visible = event.fetch("result")
      committed << event.fetch("operation")
    else
      ignored << event.fetch("operation")
    end
  when "dispose" then mounted = false
  else abort "unknown event"
  end
end
oracle = data.fetch("oracle")
abort "visible result drift" unless visible == oracle.fetch("visible_items")
abort "commit drift" unless committed == oracle.fetch("committed_operations")
abort "ignore drift" unless ignored == oracle.fetch("ignored_operations")

identity = data.fetch("list_identity")
state_by_key = identity.fetch("before").to_h do |item|
  [item.fetch("key"), item.fetch("local_state")]
end
reordered = identity.fetch("reordered_keys").map do |key|
  { "key" => key, "local_state" => state_by_key.fetch(key) }
end
abort "stable-key state drift after reorder" unless reordered == identity.fetch("oracle")

puts "PASS: latest request wins; stable keys keep local state with the business item"
