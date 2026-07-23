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
puts "PASS: latest request wins and stale completion cannot overwrite it"
