#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
root = File.expand_path("..", __dir__)
events = YAML.safe_load(File.read(File.join(root, "trace.yml"))).fetch("events")
abort "sequence not monotonic" unless events.map { |e| e.fetch("seq") } == (1..events.length).to_a

mounted = false
current = nil
cancelled = []
events.each do |event|
  case event.fetch("type")
  when "mount" then mounted = true
  when "start" then current = event.fetch("operation")
  when "cancel" then cancelled << event.fetch("operation")
  when "dispose" then mounted = false
  when "complete"
    operation = event.fetch("operation")
    permitted = mounted && current == operation && !cancelled.include?(operation)
    abort "illegal UI commit for #{operation}" unless event.fetch("commit_ui") == permitted
  else abort "unknown event"
  end
end
abort "current work not cancelled on dispose" unless cancelled.include?("B")
puts "PASS: lifecycle trace enforces owner, cancellation and mounted boundaries"
