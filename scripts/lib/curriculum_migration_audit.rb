# frozen_string_literal: true

require "digest"

module Curriculum
  # Parses the independently reviewed migration graph from its frozen Markdown
  # table. The ledger is checked against this graph so it cannot prove its own
  # completeness merely by listing every old and new ID once.
  module MigrationAudit
    Component = Struct.new(:id, :type, :old_ids, :new_ids, :edges, keyword_init: true)

    COMPONENT_PATTERN = /\AC\d{3}\z/.freeze
    LEGACY_ID_PATTERN = /\Av\d{2}\.c\d{2}\.[a-z0-9-]+\z/.freeze
    SEMANTIC_ID_PATTERN = /\Ach\.[a-z0-9]+(?:-[a-z0-9]+)*\.[a-z0-9]+(?:-[a-z0-9]+)*\z/.freeze
    TYPES = %w[preserve split merge repartition new].freeze

    module_function

    def parse(source)
      text = source.dup.force_encoding(Encoding::UTF_8)
      raise ArgumentError, "migration audit is not valid UTF-8" unless text.valid_encoding?

      rows = text.each_line.map { |line| parse_row(line) }.compact
      raise ArgumentError, "migration audit contains no component rows" if rows.empty?

      duplicates = rows.group_by(&:id).select { |_id, values| values.length > 1 }.keys
      raise ArgumentError, "migration audit repeats components #{duplicates.join(',')}" unless duplicates.empty?

      expected = (1..rows.length).map { |number| format("C%03d", number) }
      actual = rows.map(&:id)
      raise ArgumentError, "migration audit components must be contiguous C001..#{expected.last}" unless actual == expected

      rows
    end

    def parse_row(line)
      return nil unless line.match?(/^\| C\d{3} \|/)

      cells = line.strip.split("|").map(&:strip)
      # A Markdown table row has empty leading/trailing cells.
      cells.shift if cells.first == ""
      cells.pop if cells.last == ""
      raise ArgumentError, "malformed migration audit row #{line.inspect}" unless cells.length == 5

      component_id, type, old_cell, new_cell, edge_cell = cells
      raise ArgumentError, "invalid migration component #{component_id.inspect}" unless component_id.match?(COMPONENT_PATTERN)
      raise ArgumentError, "invalid migration type #{type.inspect} for #{component_id}" unless TYPES.include?(type)

      old_ids = indexed_ids(old_cell, "O", LEGACY_ID_PATTERN, component_id)
      new_ids = indexed_ids(new_cell, "N", SEMANTIC_ID_PATTERN, component_id)
      edges = parse_edges(edge_cell, old_ids, new_ids, component_id)
      validate_shape!(type, old_ids, new_ids, edges, component_id)
      Component.new(id: component_id, type: type, old_ids: old_ids, new_ids: new_ids, edges: edges)
    end

    def indexed_ids(cell, prefix, pattern, component_id)
      return [] if cell == "∅"

      matches = cell.scan(/#{prefix}(\d+) `([^`]+)`/)
      raise ArgumentError, "#{component_id} has no #{prefix} vertices" if matches.empty?

      expected_indexes = (1..matches.length).map(&:to_s)
      indexes = matches.map(&:first)
      raise ArgumentError, "#{component_id} #{prefix} indexes are not contiguous" unless indexes == expected_indexes

      ids = matches.map(&:last)
      invalid = ids.reject { |id| id.match?(pattern) }
      raise ArgumentError, "#{component_id} has invalid #{prefix} IDs #{invalid.join(',')}" unless invalid.empty?
      raise ArgumentError, "#{component_id} repeats #{prefix} IDs" unless ids.uniq.length == ids.length

      ids
    end

    def parse_edges(cell, old_ids, new_ids, component_id)
      return [] if old_ids.empty? && cell == "∅→N1" && new_ids.length == 1

      edges = cell.split("<br>").flat_map do |group|
        tokens = group.split(",")
        first = tokens.shift
        match = first.match(/\AO(\d+)→N(\d+)\z/)
        raise ArgumentError, "#{component_id} has malformed edge #{first.inspect}" unless match

        old_number = match[1]
        target_numbers = [match[2]] + tokens.map do |token|
          target = token.match(/\AN(\d+)\z/)
          raise ArgumentError, "#{component_id} has malformed edge target #{token.inspect}" unless target

          target[1]
        end
        target_numbers.map do |new_number|
          old_index = old_number.to_i - 1
          new_index = new_number.to_i - 1
          unless old_index.between?(0, old_ids.length - 1) && new_index.between?(0, new_ids.length - 1)
            raise ArgumentError, "#{component_id} edge O#{old_number}→N#{new_number} references an unknown vertex"
          end
          [old_ids.fetch(old_index), new_ids.fetch(new_index)]
        end
      end
      raise ArgumentError, "#{component_id} repeats migration edges" unless edges.uniq.length == edges.length

      edges
    end

    def validate_shape!(type, old_ids, new_ids, edges, component_id)
      valid = case type
      when "preserve" then old_ids.length == 1 && new_ids.length == 1 && edges.length == 1
      when "split" then old_ids.length == 1 && new_ids.length >= 2
      when "merge" then old_ids.length >= 2 && new_ids.length == 1
      when "repartition" then old_ids.length >= 2 && new_ids.length >= 2
      when "new" then old_ids.empty? && new_ids.length == 1 && edges.empty?
      else false
      end
      raise ArgumentError, "#{component_id} has invalid #{type} topology" unless valid

      if type != "new"
        old_with_edges = edges.map(&:first).uniq
        new_with_edges = edges.map(&:last).uniq
        unless old_with_edges.sort == old_ids.sort && new_with_edges.sort == new_ids.sort
          raise ArgumentError, "#{component_id} contains an isolated migration vertex"
        end
      end
    end

    def digest(source)
      "sha256:#{Digest::SHA256.hexdigest(source)}"
    end
  end
end
