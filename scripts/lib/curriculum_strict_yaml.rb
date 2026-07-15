# frozen_string_literal: true

require "psych"

module Curriculum
  class DiagnosticError < StandardError
    attr_reader :code, :path, :details

    def initialize(code, message, path: nil, details: {})
      @code = code
      @path = path
      @details = details
      super(message)
    end

    def to_s
      location = path ? " #{path}" : ""
      "[#{code}]#{location}: #{super}"
    end
  end

  # Psych accepts duplicate mapping keys by keeping the last value. Curriculum
  # specs are contracts, so silently replacing an earlier value is unsafe.
  class StrictYaml
    class << self
      def load_file(path, display_path: nil)
        display_path ||= path
        source = File.read(path, encoding: "UTF-8")
        load(source, display_path: display_path)
      rescue Errno::ENOENT
        raise DiagnosticError.new("E_INPUT_MISSING", "required YAML file is missing", path: display_path)
      end

      def load(source, display_path: "(yaml)")
        stream = Psych.parse_stream(source, filename: display_path)
        documents = stream.children
        if documents.length != 1
          raise DiagnosticError.new(
            "E_YAML_DOCUMENT_COUNT",
            "expected exactly one YAML document, got #{documents.length}",
            path: display_path
          )
        end

        inspect_node(documents.first.root, display_path, [])
        Psych.safe_load(
          source,
          permitted_classes: [],
          permitted_symbols: [],
          aliases: false,
          filename: display_path
        )
      rescue DiagnosticError
        raise
      rescue Psych::Exception => e
        raise DiagnosticError.new("E_YAML_PARSE", e.message, path: display_path)
      end

      private

      def inspect_node(node, display_path, pointer)
        return if node.nil?

        case node
        when Psych::Nodes::Alias
          raise DiagnosticError.new(
            "E_YAML_ALIAS",
            "aliases and merge keys are forbidden at #{json_pointer(pointer)}",
            path: display_path
          )
        when Psych::Nodes::Mapping
          inspect_mapping(node, display_path, pointer)
        when Psych::Nodes::Sequence
          node.children.each_with_index do |child, index|
            inspect_node(child, display_path, pointer + [index])
          end
        end
      end

      def inspect_mapping(node, display_path, pointer)
        seen = {}
        node.children.each_slice(2) do |key_node, value_node|
          unless key_node.is_a?(Psych::Nodes::Scalar)
            raise DiagnosticError.new(
              "E_YAML_NON_SCALAR_KEY",
              "mapping keys must be scalar at #{json_pointer(pointer)}",
              path: display_path
            )
          end

          key = key_node.value
          resolved_key = if key_node.quoted
            key
          else
            Psych.safe_load(
              key,
              permitted_classes: [],
              permitted_symbols: [],
              aliases: false
            )
          end
          unless resolved_key.is_a?(String)
            raise DiagnosticError.new(
              "E_YAML_KEY_TYPE",
              "mapping keys must resolve to strings; quote #{key.inspect} at #{json_pointer(pointer)}",
              path: display_path
            )
          end
          if key == "<<"
            raise DiagnosticError.new(
              "E_YAML_ALIAS",
              "YAML merge keys are forbidden at #{json_pointer(pointer + [key])}",
              path: display_path
            )
          end
          if seen.key?(key)
            first_line = seen.fetch(key)
            duplicate_line = key_node.start_line.to_i + 1
            raise DiagnosticError.new(
              "E_YAML_DUPLICATE_KEY",
              "duplicate key #{key.inspect} at #{json_pointer(pointer)} " \
              "(first line #{first_line}, duplicate line #{duplicate_line})",
              path: display_path,
              details: { key: key, first_line: first_line, duplicate_line: duplicate_line }
            )
          end

          seen[key] = key_node.start_line.to_i + 1
          inspect_node(value_node, display_path, pointer + [key])
        end
      end

      def json_pointer(parts)
        return "/" if parts.empty?

        "/" + parts.map { |part| part.to_s.gsub("~", "~0").gsub("/", "~1") }.join("/")
      end
    end
  end
end
