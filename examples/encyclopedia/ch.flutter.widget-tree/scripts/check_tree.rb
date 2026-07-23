#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
root = File.expand_path("..", __dir__)
data = YAML.safe_load(File.read(File.join(root, "tree.yml")))
nodes = data.fetch("nodes").to_h { |node| [node.fetch("id"), node] }

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
end
puts "PASS: widget tree identities and ancestor lookups are coherent"
