#!/usr/bin/env ruby
# frozen_string_literal: true

# The catalog is generated state, so its strongest validation is byte-for-byte
# comparison with a fully validated canonical spec compilation. This command is
# intentionally read-only and shares the exact same schema, graph, route, gate,
# migration, content-quality, and placeholder checks as --check.
require_relative "../scripts/lib/curriculum_compiler"

root = File.expand_path("..", __dir__)
status = Curriculum::Generator.new(root: root, mode: :check).run
puts "CATALOG VALID" if status.zero?
exit status
