#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
root = File.expand_path("..", __dir__)
data = YAML.safe_load(File.read(File.join(root, "tree.yml")))
nodes = data.fetch("nodes").to_h { |node| [node.fetch("id"), node] }
framework_oracle = {
  "MaterialApp" => ["StatefulElement", true],
  "Scaffold" => ["StatefulElement", true]
}.freeze

def ancestors(nodes, id)
  result = []
  parent = nodes.fetch(id)["parent"]
  while parent
    abort "cycle or missing node" if result.include?(parent) || !nodes.key?(parent)
    result << parent
    parent = nodes.fetch(parent)["parent"]
  end
  result
end

data.fetch("lookups").each do |lookup|
  found = ancestors(nodes, lookup.fetch("from")).include?(lookup.fetch("ancestor"))
  expected = lookup.fetch("expected") == "found"
  abort "context lookup drift: #{lookup}" unless found == expected
end

nodes.each_value do |node|
  expected_state = node.fetch("element") == "StatefulElement"
  abort "state/element mismatch: #{node['id']}" unless node.fetch("state") == expected_state
  known = framework_oracle[node.fetch("widget")]
  next unless known

  abort "known Flutter widget oracle drift: #{node['widget']}" unless
    [node.fetch("element"), node.fetch("state")] == known
end
puts "PASS: widget tree identities and ancestor lookups are coherent"
