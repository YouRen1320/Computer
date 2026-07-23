#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
root = File.expand_path("..", __dir__)
data = YAML.safe_load(File.read(File.join(root, "reconciliation.yml")))
before = data.fetch("before")
order = data.fetch("after_order")

without_key = order.each_with_index.map do |id, index|
  {"order_id" => id, "expanded" => before.fetch(index).fetch("expanded")}
end
state_by_id = before.to_h { |item| [item.fetch("order_id"), item.fetch("expanded")] }
with_key = order.map { |id| {"order_id" => id, "expanded" => state_by_id.fetch(id)} }

expected = data.fetch("expectations")
abort "position reconciliation changed" unless without_key == expected.fetch("without_key")
abort "key reconciliation changed" unless with_key == expected.fetch("with_value_key")
puts "PASS: stable ValueKey keeps State attached to the business identity"
