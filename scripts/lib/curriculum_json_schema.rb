# frozen_string_literal: true

require "json"
require "set"

module Curriculum
  class StrictJson
    class DuplicateKeyError < StandardError; end

    class Object < Hash
      def []=(key, value)
        raise DuplicateKeyError, "duplicate JSON object key #{key.inspect}" if key?(key)

        super
      end
    end

    def self.load(source)
      JSON.parse(source, object_class: Object)
    end
  end

  # A deliberately small JSON Schema 2020-12 evaluator for the keywords used
  # by curriculum/migrations/migration.schema.json. Keeping this local avoids
  # making validation depend on an unpinned gem while still executing the
  # checked-in schema instead of duplicating it as ad-hoc Ruby conditionals.
  class JsonSchema
    Error = Struct.new(:pointer, :message)
    ALLOWED_KEYWORDS = Set.new(%w[
      $schema $id title description type additionalProperties required properties $defs $ref
      const enum pattern minLength minimum items minItems maxItems uniqueItems allOf if then
    ]).freeze

    def initialize(schema)
      @root = schema
      validate_schema_definition!(schema, "#")
    end

    def validate(instance)
      errors = []
      validate_node(instance, @root, "", errors)
      errors
    end

    private

    def validate_schema_definition!(schema, pointer)
      raise ArgumentError, "schema at #{pointer} must be an object; boolean schemas are unsupported" unless schema.is_a?(Hash)

      unknown = schema.keys.reject { |key| ALLOWED_KEYWORDS.include?(key) }
      raise ArgumentError, "unsupported JSON Schema keyword(s) at #{pointer}: #{unknown.join(',')}" unless unknown.empty?
      if schema.key?("$ref")
        raise ArgumentError, "$ref at #{pointer} must be a string" unless schema["$ref"].is_a?(String)
        resolve_ref(schema["$ref"])
      end
      if schema.key?("pattern")
        raise ArgumentError, "pattern at #{pointer} must be a string" unless schema["pattern"].is_a?(String)
        Regexp.new(schema["pattern"])
      end
      if schema.key?("type") && !%w[object array string integer number boolean null].include?(schema["type"])
        raise ArgumentError, "unsupported type at #{pointer}: #{schema['type'].inspect}"
      end
      %w[properties $defs].each do |container|
        if schema.key?(container) && !schema[container].is_a?(Hash)
          raise ArgumentError, "#{container} at #{pointer} must be an object"
        end
      end
      if schema.key?("required") && !(schema["required"].is_a?(Array) && schema["required"].all? { |item| item.is_a?(String) })
        raise ArgumentError, "required at #{pointer} must be an array of strings"
      end
      if schema.key?("enum") && !schema["enum"].is_a?(Array)
        raise ArgumentError, "enum at #{pointer} must be an array"
      end
      if schema.key?("items") && !schema["items"].is_a?(Hash)
        raise ArgumentError, "items at #{pointer} must be a schema object"
      end
      if schema.key?("additionalProperties") && ![true, false].include?(schema["additionalProperties"])
        raise ArgumentError, "schema-valued additionalProperties at #{pointer} is unsupported"
      end
      if schema.key?("allOf") && !(schema["allOf"].is_a?(Array) && schema["allOf"].all? { |item| item.is_a?(Hash) })
        raise ArgumentError, "allOf at #{pointer} must be an array of schema objects"
      end
      %w[if then].each do |keyword|
        if schema.key?(keyword) && !schema[keyword].is_a?(Hash)
          raise ArgumentError, "#{keyword} at #{pointer} must be a schema object"
        end
      end

      %w[properties $defs].each do |container|
        schema.fetch(container, {}).each do |name, child|
          validate_schema_definition!(child, "#{pointer}/#{container}/#{name}")
        end
      end
      %w[items if then].each do |keyword|
        validate_schema_definition!(schema[keyword], "#{pointer}/#{keyword}") if schema[keyword].is_a?(Hash)
      end
      schema.fetch("allOf", []).each_with_index do |child, index|
        validate_schema_definition!(child, "#{pointer}/allOf/#{index}")
      end
    rescue RegexpError, KeyError => e
      raise ArgumentError, "invalid schema at #{pointer}: #{e.message}"
    end

    def validate_node(instance, schema, pointer, errors)
      return unless schema.is_a?(Hash)

      schema = resolve_ref(schema.fetch("$ref")) if schema.key?("$ref")
      schema.fetch("allOf", []).each { |part| validate_node(instance, part, pointer, errors) }
      if schema.key?("if") && matches?(instance, schema.fetch("if"))
        validate_node(instance, schema.fetch("then", {}), pointer, errors)
      end

      validate_const_enum(instance, schema, pointer, errors)
      return unless type_valid?(instance, schema["type"], pointer, errors)

      case instance
      when Hash
        validate_object(instance, schema, pointer, errors)
      when Array
        validate_array(instance, schema, pointer, errors)
      when String
        validate_string(instance, schema, pointer, errors)
      when Numeric
        if schema.key?("minimum") && instance < schema.fetch("minimum")
          errors << Error.new(display_pointer(pointer), "must be >= #{schema.fetch('minimum')}")
        end
      end
    end

    def validate_const_enum(instance, schema, pointer, errors)
      if schema.key?("const") && instance != schema.fetch("const")
        errors << Error.new(display_pointer(pointer), "must equal #{schema.fetch('const').inspect}")
      end
      if schema.key?("enum") && !schema.fetch("enum").include?(instance)
        errors << Error.new(display_pointer(pointer), "must be one of #{schema.fetch('enum').inspect}")
      end
    end

    def type_valid?(instance, expected, pointer, errors)
      return true unless expected

      valid = case expected
      when "object" then instance.is_a?(Hash)
      when "array" then instance.is_a?(Array)
      when "string" then instance.is_a?(String)
      when "integer" then instance.is_a?(Integer)
      when "number" then instance.is_a?(Numeric)
      when "boolean" then instance == true || instance == false
      when "null" then instance.nil?
      else false
      end
      errors << Error.new(display_pointer(pointer), "must have type #{expected}") unless valid
      valid
    end

    def validate_object(instance, schema, pointer, errors)
      schema.fetch("required", []).each do |key|
        errors << Error.new(child_pointer(pointer, key), "is required") unless instance.key?(key)
      end
      properties = schema.fetch("properties", {})
      if schema["additionalProperties"] == false
        (instance.keys - properties.keys).each do |key|
          errors << Error.new(child_pointer(pointer, key), "is not an allowed property")
        end
      end
      properties.each do |key, property_schema|
        validate_node(instance[key], property_schema, child_pointer(pointer, key), errors) if instance.key?(key)
      end
    end

    def validate_array(instance, schema, pointer, errors)
      if schema.key?("minItems") && instance.length < schema.fetch("minItems")
        errors << Error.new(display_pointer(pointer), "must contain at least #{schema.fetch('minItems')} item(s)")
      end
      if schema.key?("maxItems") && instance.length > schema.fetch("maxItems")
        errors << Error.new(display_pointer(pointer), "must contain at most #{schema.fetch('maxItems')} item(s)")
      end
      if schema["uniqueItems"] && instance.uniq.length != instance.length
        errors << Error.new(display_pointer(pointer), "must contain unique items")
      end
      item_schema = schema["items"]
      instance.each_with_index do |item, index|
        validate_node(item, item_schema, child_pointer(pointer, index), errors) if item_schema
      end
    end

    def validate_string(instance, schema, pointer, errors)
      if schema.key?("minLength") && instance.length < schema.fetch("minLength")
        errors << Error.new(display_pointer(pointer), "must contain at least #{schema.fetch('minLength')} character(s)")
      end
      if schema.key?("pattern") && !Regexp.new(schema.fetch("pattern")).match?(instance)
        errors << Error.new(display_pointer(pointer), "must match #{schema.fetch('pattern').inspect}")
      end
    rescue RegexpError => e
      errors << Error.new(display_pointer(pointer), "schema pattern is invalid: #{e.message}")
    end

    def matches?(instance, schema)
      errors = []
      validate_node(instance, schema, "", errors)
      errors.empty?
    end

    def resolve_ref(reference)
      unless reference.start_with?("#/")
        raise ArgumentError, "only local JSON Schema references are supported: #{reference}"
      end

      reference.delete_prefix("#/").split("/").inject(@root) do |value, part|
        value.fetch(part.gsub("~1", "/").gsub("~0", "~"))
      end
    end

    def child_pointer(pointer, part)
      encoded = part.to_s.gsub("~", "~0").gsub("/", "~1")
      "#{pointer}/#{encoded}"
    end

    def display_pointer(pointer)
      pointer.empty? ? "/" : pointer
    end
  end
end
