#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "digest"
require "json"
require "open3"
require "optparse"
require "pathname"
require "rbconfig"
require "set"
require "uri"
require "yaml"
require_relative "lib/chapter_prerequisite_block"
require_relative "lib/factorycare_status_contract"

ROOT = File.expand_path("..", __dir__) unless defined?(ROOT)
CATALOG_RELATIVE = "curriculum/catalog.yml"
REGISTRY_RELATIVE = "versions/registry.yml"
SITE_CONFIG_RELATIVE = "site/config.yml"
CHAPTER_SCHEMA_RELATIVE = "schemas/chapter.schema.json"
REGISTRY_SCHEMA_RELATIVE = "schemas/version-registry.schema.json"
SITE_CONFIG_SCHEMA_RELATIVE = "schemas/site-config.schema.json"
SITE_GENERATED_SCHEMA_RELATIVE = "schemas/site-publication-manifest-v3.schema.json"
GENERATED_FILES = %w[catalog.json navigation.json publication-manifest.json README.md search-index.json].freeze
CHAPTER_ID_PATTERN = /\Ach\.[a-z0-9]+(?:-[a-z0-9]+)*\.[a-z0-9]+(?:-[a-z0-9]+)*\z/.freeze
LEGACY_CHAPTER_ID_PATTERN = /v\d{2}\.c\d{2}\.[a-z0-9-]+/.freeze
CURRICULUM_GENERATOR = "scripts/generate-curriculum.rb"
PLANNED_PLACEHOLDER_MARKER = "GENERATED: factorycare-planned-placeholder; safe-to-overwrite: planned-only"
BASE_CATALOG_FIELDS = %w[
  id title responsibility volume order level prerequisites prerequisite_rationales outcomes status route_tags stable_core
  version_surfaces path recommended_after capabilities spec_digest
].freeze
BASE_FRONT_MATTER_FIELDS = %w[
  schema_version edition id title responsibility volume order level status path catalog
  prerequisites version_surfaces route_tags
].freeze
AUTHORING_FIELDS = %w[stable_core outcomes].freeze
REVIEW_FIELDS = %w[verified_versions source_refs examples labs exercises solutions_private author last_reviewed verification].freeze
VERIFICATION_GATES = %w[
  technical pedagogical code security accessibility version_sources publication_navigation
].freeze
MANDATORY_PASSED_GATES = %w[technical pedagogical code version_sources publication_navigation].freeze
CONDITIONAL_GATES = %w[security accessibility].freeze
ALLOWED_LEVELS = %w[L1 L2 L2+ L3 L1-L2].freeze
ALLOWED_STATUSES = %w[planned drafting review verified].freeze
ALLOWED_GATE_STATUSES = %w[pending passed not-applicable].freeze
PLACEHOLDER_MARKERS = ["架构占位", "尚未包含教材正文", "尚无教材正文"].freeze
PLACEHOLDER_LINE_PATTERN = /\A\s*(?:[#>*+\-]\s*)?(?:TODO|TBD|待补充|待完善|待编写)(?:\s*[:：].*)?\s*\z/i.freeze

module StrictJson
  class DuplicateMemberError < StandardError; end

  class Object < Hash
    def []=(key, value)
      raise DuplicateMemberError, "duplicate JSON object member #{key.inspect}" if key?(key)

      super
    end
  end

  module_function

  def parse(contents)
    JSON.parse(contents, object_class: Object)
  end
end

# Psych normally keeps the last value for duplicate mapping keys. That is unsafe
# for policy and publication metadata, so every YAML document is inspected before
# conversion to Ruby objects.
module StrictYaml
  class DuplicateKeyError < StandardError; end
  class UnsupportedKeyError < StandardError; end

  module_function

  def safe_load(contents, label:)
    validate_unique_keys!(contents, label: label)
    YAML.safe_load(contents, aliases: false)
  end

  def validate_unique_keys!(contents, label:)
    stream = Psych.parse_stream(contents, label)
    walk(stream, label)
    true
  end

  def walk(node, label)
    if node.is_a?(Psych::Nodes::Mapping)
      seen = {}
      node.children.each_slice(2) do |key_node, value_node|
        identity, display = key_identity(key_node, label)
        if seen.key?(identity)
          first_line = seen.fetch(identity)
          raise DuplicateKeyError,
                "#{label}: duplicate mapping key #{display.inspect} at line #{key_node.start_line + 1} (first at line #{first_line})"
        end
        seen[identity] = key_node.start_line + 1
        walk(value_node, label)
      end
      return
    end

    Array(node.children).each { |child| walk(child, label) }
  end

  def key_identity(node, label)
    unless node.is_a?(Psych::Nodes::Scalar)
      raise UnsupportedKeyError, "#{label}: non-scalar YAML mapping keys are forbidden at line #{node.start_line + 1}"
    end

    resolved = if node.quoted || node.tag == "tag:yaml.org,2002:str"
                 node.value
               else
                 resolve_plain_scalar(node.value)
               end
    [[resolved.class.name, resolved.to_s], node.value]
  end

  def resolve_plain_scalar(value)
    YAML.safe_load("--- #{value}\n", aliases: false)
  rescue Psych::Exception
    value
  end
end

# Executes the exact JSON Schema subset used by schemas/. Unsupported keywords or
# invalid schema definitions fail closed, so a schema edit cannot silently drift
# away from runtime validation.
class ExecutableJsonSchema
  SUPPORTED_KEYWORDS = Set.new(%w[
    $schema $id $ref $defs title description type additionalProperties required
    properties const enum pattern minLength minimum minItems maxItems uniqueItems items
    format allOf if then
  ]).freeze
  SUPPORTED_TYPES = %w[object array string integer number boolean null].freeze

  attr_reader :definition_errors

  def initialize(schema, label)
    @schema = schema
    @label = label
    @definition_errors = []
    validate_definition(schema, "#")
  end

  def validate(instance)
    errors = []
    evaluate(@schema, instance, "$", errors)
    errors
  end

  # Some contracts keep closely related generated documents in one schema.
  # Validate a named local definition without weakening the schema subset or
  # introducing cross-file references.
  def validate_subschema(reference, instance)
    errors = []
    evaluate(resolve_reference(reference), instance, "$", errors)
    errors
  rescue KeyError, TypeError
    ["#{reference}: unresolved local schema reference"]
  end

  private

  def validate_definition(schema, path)
    return if schema == true || schema == false

    unless schema.is_a?(Hash)
      definition_errors << "#{@label} #{path}: schema node must be an object or boolean"
      return
    end

    unknown = schema.keys.reject { |key| SUPPORTED_KEYWORDS.include?(key) }
    unknown.each { |key| definition_errors << "#{@label} #{path}: unsupported schema keyword #{key}" }

    if schema.key?("type") && !valid_type_definition?(schema["type"])
      definition_errors << "#{@label} #{path}: unsupported type #{schema["type"].inspect}"
    end
    if schema.key?("required") && !(schema["required"].is_a?(Array) && schema["required"].all? { |item| item.is_a?(String) })
      definition_errors << "#{@label} #{path}: required must be an array of strings"
    end
    if schema.key?("properties") && !schema["properties"].is_a?(Hash)
      definition_errors << "#{@label} #{path}: properties must be an object"
    end
    if schema.key?("$defs") && !schema["$defs"].is_a?(Hash)
      definition_errors << "#{@label} #{path}: $defs must be an object"
    end
    if schema.key?("allOf") && !schema["allOf"].is_a?(Array)
      definition_errors << "#{@label} #{path}: allOf must be an array"
    end
    if schema.key?("additionalProperties") && ![true, false].include?(schema["additionalProperties"]) && !schema["additionalProperties"].is_a?(Hash)
      definition_errors << "#{@label} #{path}: additionalProperties must be boolean or a schema"
    end
    if schema.key?("pattern") && !schema["pattern"].is_a?(String)
      definition_errors << "#{@label} #{path}: pattern must be a string"
    elsif schema.key?("pattern")
      begin
        Regexp.new(schema["pattern"])
      rescue RegexpError
        definition_errors << "#{@label} #{path}: pattern is not a valid regular expression"
      end
    end
    if schema.key?("format") && schema["format"] != "date"
      definition_errors << "#{@label} #{path}: unsupported format #{schema["format"].inspect}"
    end
    %w[$schema $id title description].each do |keyword|
      definition_errors << "#{@label} #{path}: #{keyword} must be a string" if schema.key?(keyword) && !schema[keyword].is_a?(String)
    end
    %w[minLength minItems maxItems].each do |keyword|
      value = schema[keyword]
      definition_errors << "#{@label} #{path}: #{keyword} must be a non-negative integer" if schema.key?(keyword) && !(value.is_a?(Integer) && value >= 0)
    end
    if schema.key?("minimum") && !schema["minimum"].is_a?(Numeric)
      definition_errors << "#{@label} #{path}: minimum must be numeric"
    end
    if schema.key?("uniqueItems") && ![true, false].include?(schema["uniqueItems"])
      definition_errors << "#{@label} #{path}: uniqueItems must be boolean"
    end
    if schema.key?("enum") && !(schema["enum"].is_a?(Array) && !schema["enum"].empty?)
      definition_errors << "#{@label} #{path}: enum must be a non-empty array"
    end
    %w[items if then].each do |keyword|
      definition_errors << "#{@label} #{path}: #{keyword} must be an object or boolean schema" if schema.key?(keyword) && !schema_node?(schema[keyword])
    end
    validate_reference(schema["$ref"], path) if schema.key?("$ref")

    properties = schema["properties"].is_a?(Hash) ? schema["properties"] : {}
    definitions = schema["$defs"].is_a?(Hash) ? schema["$defs"] : {}
    all_of = schema["allOf"].is_a?(Array) ? schema["allOf"] : []
    properties.each { |key, child| validate_definition(child, "#{path}/properties/#{escape_pointer(key)}") }
    definitions.each { |key, child| validate_definition(child, "#{path}/$defs/#{escape_pointer(key)}") }
    all_of.each_with_index { |child, index| validate_definition(child, "#{path}/allOf/#{index}") }
    %w[items if then].each { |key| validate_definition(schema[key], "#{path}/#{key}") if schema_node?(schema[key]) }
    validate_definition(schema["additionalProperties"], "#{path}/additionalProperties") if schema["additionalProperties"].is_a?(Hash)
  end

  def validate_reference(reference, path)
    unless reference.is_a?(String) && reference.start_with?("#/")
      definition_errors << "#{@label} #{path}: only local JSON pointers are supported"
      return
    end
    resolve_reference(reference)
  rescue KeyError, TypeError
    definition_errors << "#{@label} #{path}: unresolved reference #{reference}"
  end

  def evaluate(schema, value, path, errors)
    return if schema == true
    if schema == false
      errors << "#{path}: rejected by false schema"
      return
    end

    if schema.key?("$ref")
      evaluate(resolve_reference(schema["$ref"]), value, path, errors)
    end

    Array(schema["allOf"]).each { |child| evaluate(child, value, path, errors) }
    if schema_node?(schema["if"])
      probe = []
      evaluate(schema["if"], value, path, probe)
      evaluate(schema["then"], value, path, errors) if probe.empty? && schema_node?(schema["then"])
    end

    expected_type = schema["type"]
    if expected_type && !type_matches?(expected_type, value)
      errors << "#{path}: expected #{expected_type}, got #{ruby_type(value)}"
      return
    end
    errors << "#{path}: must equal #{schema["const"].inspect}" if schema.key?("const") && value != schema["const"]
    errors << "#{path}: value #{value.inspect} is not in enum" if schema["enum"].is_a?(Array) && !schema["enum"].include?(value)

    case value
    when Hash
      validate_object(schema, value, path, errors)
    when Array
      validate_array(schema, value, path, errors)
    when String
      validate_string(schema, value, path, errors)
    when Numeric
      if schema.key?("minimum") && value < schema["minimum"]
        errors << "#{path}: must be >= #{schema["minimum"]}"
      end
    end
  end

  def validate_object(schema, value, path, errors)
    Array(schema["required"]).each do |field|
      errors << "#{path}: missing required property #{field}" unless value.key?(field)
    end
    properties = schema["properties"].is_a?(Hash) ? schema["properties"] : {}
    value.each do |key, child_value|
      if properties.key?(key)
        evaluate(properties[key], child_value, "#{path}/#{escape_pointer(key)}", errors)
      elsif schema["additionalProperties"] == false
        errors << "#{path}: additional property #{key} is not allowed"
      elsif schema["additionalProperties"].is_a?(Hash)
        evaluate(schema["additionalProperties"], child_value, "#{path}/#{escape_pointer(key)}", errors)
      end
    end
  end

  def validate_array(schema, value, path, errors)
    if schema.key?("minItems") && value.length < schema["minItems"]
      errors << "#{path}: must contain at least #{schema["minItems"]} item(s)"
    end
    if schema.key?("maxItems") && value.length > schema["maxItems"]
      errors << "#{path}: must contain at most #{schema["maxItems"]} item(s)"
    end
    if schema["uniqueItems"] == true
      fingerprints = value.map { |item| JSON.generate(canonical(item)) }
      errors << "#{path}: items must be unique" unless fingerprints.uniq.length == fingerprints.length
    end
    value.each_with_index { |item, index| evaluate(schema["items"], item, "#{path}/#{index}", errors) } if schema_node?(schema["items"])
  end

  def validate_string(schema, value, path, errors)
    errors << "#{path}: must contain at least #{schema["minLength"]} character(s)" if schema.key?("minLength") && value.length < schema["minLength"]
    if schema.key?("pattern") && !Regexp.new(schema["pattern"]).match?(value)
      errors << "#{path}: does not match required pattern"
    end
    return unless schema["format"] == "date"

    parsed = Date.iso8601(value)
    errors << "#{path}: date must use YYYY-MM-DD" unless parsed.strftime("%Y-%m-%d") == value
  rescue ArgumentError
    errors << "#{path}: is not a valid ISO date"
  end

  def resolve_reference(reference)
    reference.delete_prefix("#/").split("/").reduce(@schema) do |cursor, token|
      cursor.fetch(token.gsub("~1", "/").gsub("~0", "~"))
    end
  end

  def type_matches?(type, value)
    return type.any? { |candidate| type_matches?(candidate, value) } if type.is_a?(Array)

    case type
    when "object" then value.is_a?(Hash)
    when "array" then value.is_a?(Array)
    when "string" then value.is_a?(String)
    when "integer" then value.is_a?(Integer)
    when "number" then value.is_a?(Numeric)
    when "boolean" then value == true || value == false
    when "null" then value.nil?
    else false
    end
  end

  def valid_type_definition?(type)
    return SUPPORTED_TYPES.include?(type) if type.is_a?(String)

    type.is_a?(Array) && !type.empty? && type.uniq.length == type.length &&
      type.all? { |candidate| candidate.is_a?(String) && SUPPORTED_TYPES.include?(candidate) }
  end

  def ruby_type(value)
    return "null" if value.nil?
    return "boolean" if value == true || value == false

    value.class.name
  end

  def canonical(value)
    case value
    when Hash then value.keys.sort.each_with_object({}) { |key, memo| memo[key] = canonical(value[key]) }
    when Array then value.map { |item| canonical(item) }
    else value
    end
  end

  def escape_pointer(value)
    value.to_s.gsub("~", "~0").gsub("/", "~1")
  end

  def schema_node?(value)
    value.is_a?(Hash) || value == true || value == false
  end
end

class RepositoryPathPolicy
  attr_reader :root_real

  def initialize(root)
    @root_real = File.realpath(root)
  end

  def validate_regular_file(relative, label:, patterns:, require_nonblank: false)
    issues = validate_relative_shape(relative, label)
    return issues unless issues.empty?

    issues << "#{label}: path is outside its allowed directory" unless patterns.any? { |pattern| pattern.match?(relative) }
    issues.concat(validate_components(relative, label))
    absolute = File.expand_path(relative, root_real)
    unless File.file?(absolute)
      issues << "#{label}: file does not exist"
      return issues
    end
    stat = File.lstat(absolute)
    issues << "#{label}: symbolic links are forbidden" if stat.symlink?
    issues << "#{label}: must be a regular file" unless stat.file?
    real = File.realpath(absolute)
    issues << "#{label}: resolved path escapes repository" unless contained?(real, root_real)
    if require_nonblank && stat.file? && !nonblank_regular_file?(absolute)
      issues << "#{label}: file must contain non-whitespace content"
    end
    issues
  rescue Errno::ENOENT, Errno::ELOOP => e
    issues << "#{label}: cannot resolve path (#{e.class})"
    issues
  end

  # Review artifacts may be a concrete file or a small project directory. A
  # directory is evidence only when it contains at least one visible regular
  # file; symlinks anywhere below it are rejected.
  def validate_artifact(relative, label:, patterns:)
    issues = validate_relative_shape(relative, label)
    return issues unless issues.empty?

    issues << "#{label}: path is outside its allowed chapter artifact directory" unless patterns.any? { |pattern| pattern.match?(relative) }
    issues.concat(validate_components(relative, label))
    absolute = File.expand_path(relative, root_real)
    unless File.exist?(absolute) || File.symlink?(absolute)
      issues << "#{label}: artifact does not exist"
      return issues
    end

    stat = File.lstat(absolute)
    issues << "#{label}: symbolic links are forbidden" if stat.symlink?
    return issues if stat.symlink?

    real = File.realpath(absolute)
    issues << "#{label}: resolved path escapes repository" unless contained?(real, root_real)
    if stat.file?
      issues << "#{label}: artifact file must contain non-whitespace content" unless nonblank_regular_file?(absolute)
      return issues
    elsif !stat.directory?
      issues << "#{label}: must be a regular file or directory"
      return issues
    end

    visible_regular_files = []
    Dir.glob(File.join(absolute, "**", "*"), File::FNM_DOTMATCH).sort.each do |entry|
      relative_entry = entry.delete_prefix(absolute + File::SEPARATOR)
      next if relative_entry.empty? || relative_entry.split(File::SEPARATOR).any? { |part| [".", ".."].include?(part) }

      entry_stat = File.lstat(entry)
      if entry_stat.symlink?
        issues << "#{label}: artifact directory contains a symbolic link: #{relative_entry}"
      elsif entry_stat.file? && relative_entry.split(File::SEPARATOR).none? { |part| part.start_with?(".") } && nonblank_regular_file?(entry)
        visible_regular_files << entry
      end
    end
    issues << "#{label}: artifact directory must contain a non-hidden, non-whitespace regular file" if visible_regular_files.empty?
    issues
  rescue Errno::ENOENT, Errno::ELOOP => e
    issues << "#{label}: cannot resolve artifact (#{e.class})"
    issues
  end

  def validate_output_directory(relative, label: "site output")
    issues = validate_relative_shape(relative, label)
    return issues unless issues.empty?

    site_real = File.realpath(File.join(root_real, "site"))
    lexical = File.expand_path(relative, root_real)
    issues << "#{label}: must remain below site/" unless contained?(lexical, site_real) && lexical != site_real
    issues.concat(validate_components(relative, label, allow_missing: true))
    if File.exist?(lexical) || File.symlink?(lexical)
      stat = File.lstat(lexical)
      issues << "#{label}: symbolic links are forbidden" if stat.symlink?
      issues << "#{label}: must be a directory" unless stat.directory?
      issues << "#{label}: resolved path escapes site/" if stat.directory? && !contained?(File.realpath(lexical), site_real)
    end
    issues
  rescue Errno::ENOENT, Errno::ELOOP => e
    issues << "#{label}: cannot resolve path (#{e.class})"
    issues
  end

  def absolute(relative)
    File.expand_path(relative, root_real)
  end

  private

  def validate_relative_shape(relative, label)
    return ["#{label}: must be a non-empty relative path"] unless relative.is_a?(String) && !relative.empty?
    return ["#{label}: absolute paths are forbidden"] if Pathname.new(relative).absolute?
    return ["#{label}: control characters are forbidden"] if relative.match?(/[[:cntrl:]]/)
    return ["#{label}: dot segments and empty segments are forbidden"] if relative.split("/", -1).any? { |part| part.empty? || part == "." || part == ".." }

    []
  end

  def validate_components(relative, label, allow_missing: false)
    issues = []
    cursor = root_real
    relative.split("/").each do |component|
      cursor = File.join(cursor, component)
      unless File.exist?(cursor) || File.symlink?(cursor)
        break if allow_missing
        next
      end
      if File.lstat(cursor).symlink?
        issues << "#{label}: symbolic link component is forbidden: #{component}"
        break
      end
    end
    issues
  end

  def contained?(candidate, base)
    candidate == base || candidate.start_with?(base + File::SEPARATOR)
  end

  def nonblank_regular_file?(path)
    bytes = File.binread(path)
    return false if bytes.empty?

    text = bytes.dup.force_encoding(Encoding::UTF_8)
    if text.valid_encoding?
      !text.gsub(/[[:space:]]/u, "").empty?
    else
      bytes.each_byte.any? { |byte| ![9, 10, 11, 12, 13, 32].include?(byte) }
    end
  end
end

module EncyclopediaInputSet
  class ContractError < StandardError; end

  CATEGORY_ORDER = %w[content audit_security build_control].freeze
  CATEGORY_DIGEST_ALGORITHM = "sha256-path-nul-content-sha256-nul-v1"
  TOTAL_DIGEST_ALGORITHM = "sha256-category-nul-digest-nul-v1"
  PUBLIC_ARTIFACT_SCHEMA_RELATIVE = "schemas/public-artifact-manifest.schema.json"
  PUBLIC_ARTIFACT_MANIFEST_ROOT = "publication/manifests/public-artifacts"
  GENERATED_COMPONENTS = %w[
    build target dist out work coverage node_modules .gradle .idea .venv
    __pycache__ .dart_tool generated
  ].freeze
  GENERATED_SUFFIX = /(?:\.(?:class|jar|log|tmp|swp)|~)\z/i

  module_function

  # Return one authoritative, disjoint input inventory. Callers must not
  # rebuild these categories from path guesses because the category names and
  # aggregate digest order are part of the P2 schema-v3 contract.
  def inventory(root, catalog)
    expected = base_inputs(root, catalog)
    public = public_review_partition(root, catalog)
    validate_explicit_partition!(public)
    expected.concat(public.values.flatten)
    expected.reject! { |path| path.start_with?("solutions-private/") }
    expected = expected.uniq.sort

    categories = CATEGORY_ORDER.to_h { |category| [category, []] }
    expected.each do |path|
      category = explicit_public_category(path, public) || category_for(path)
      raise ContractError, "E_INPUT_CATEGORY_UNKNOWN #{path}: no P2 input category" unless category

      categories.fetch(category) << path
    end
    categories.transform_values! { |paths| paths.uniq.sort }
    validate_partition!(categories, expected)
    validate_tracked!(root, expected)
    { categories: categories, expected: expected }
  end

  def files(root, catalog)
    inventory(root, catalog).fetch(:expected)
  end

  def categories(root, catalog)
    inventory(root, catalog).fetch(:categories)
  end

  def base_inputs(root, catalog)
    paths = [
      "ASSESSMENTS.md",
      "PROGRESS.md",
      CATALOG_RELATIVE,
      REGISTRY_RELATIVE,
      SITE_CONFIG_RELATIVE,
      CHAPTER_SCHEMA_RELATIVE,
      REGISTRY_SCHEMA_RELATIVE,
      SITE_CONFIG_SCHEMA_RELATIVE,
      SITE_GENERATED_SCHEMA_RELATIVE,
      PUBLIC_ARTIFACT_SCHEMA_RELATIVE,
      "curriculum/gates.yml",
      "curriculum/validate_catalog.rb",
      "scripts/build-book.rb",
      "scripts/validate-encyclopedia.rb",
      "site/index.html",
      "site/assets/site.css",
      "site/assets/site.js"
    ]
    # The manifest must cover every repository file read or scanned by the
    # strict curriculum validator, not only the three primary YAML documents.
    strict_inputs = Dir.glob(File.join(root, "{book,curriculum}", "**", "*.{md,yml,json,rb}"), File::FNM_EXTGLOB)
                       .select { |path| File.file?(path) || File.symlink?(path) }
                       .map { |path| relative(root, path) }
    paths.concat(strict_inputs)
    paths.concat(Dir.glob(File.join(root, "scripts/lib/**/*.rb")).map { |path| relative(root, path) })
    paths.concat(external_curriculum_inputs(root))
    paths.concat(Dir.glob(File.join(root, "curriculum/routes/*.yml")).map { |path| relative(root, path) })
    paths.concat(Dir.glob(File.join(root, "book/volume-*/README.md")).map { |path| relative(root, path) })
    chapter_paths = Array(catalog["chapters"]).each_with_object([]) do |chapter, memo|
      memo << chapter["path"] if chapter.is_a?(Hash) && chapter["path"].is_a?(String)
    end
    paths.concat(chapter_paths)
    paths.uniq.sort
  end

  def external_curriculum_inputs(root)
    edition_path = File.join(root, "curriculum/edition.yml")
    edition = StrictYaml.safe_load(File.read(edition_path, encoding: "UTF-8"), label: "curriculum/edition.yml")
    ledger_relative = edition["migration_ledger"]
    return [] unless ledger_relative.is_a?(String)

    ledger_path = File.join(root, ledger_relative)
    ledger = StrictYaml.safe_load(File.read(ledger_path, encoding: "UTF-8"), label: ledger_relative)
    # These two files are read directly by Curriculum::SpecSet while the P2
    # validator checks the canonical catalog. Keep them in the P2 closure even
    # though they live outside curriculum/ and the core site schemas.
    paths = [
      "schemas/factorycare-stage-gates.schema.json",
      "factorycare-design/testing/acceptance-catalog.md",
      ledger["mapping_audit_path"]
    ]
    Array(ledger["source_rebuilds"]).each do |rebuild|
      next unless rebuild.is_a?(Hash)

      %w[source_inventory_path source_build_path candidate_manifest_path builder_path].each do |field|
        paths << rebuild[field]
      end
    end
    paths.select { |path| path.is_a?(String) }
  end

  def public_review_partition(root, catalog)
    partition = CATEGORY_ORDER.to_h { |category| [category, []] }
    Array(catalog["chapters"]).each do |chapter|
      next unless chapter.is_a?(Hash) && %w[review verified].include?(chapter["status"])

      metadata = chapter_metadata(root, chapter["path"])
      public = explicit_public_artifacts(root, chapter, metadata)
      partition.fetch("content").concat(public.fetch(:artifacts))
      partition.fetch("build_control") << public.fetch(:manifest)
      partition.fetch("build_control").concat(public.fetch(:repository_metadata))

      Array(metadata["verified_versions"]).each do |entry|
        partition.fetch("audit_security") << entry["evidence"] if entry.is_a?(Hash) && entry["evidence"].is_a?(String)
      end
      verification = metadata["verification"]
      next unless verification.is_a?(Hash)

      verification.each_value do |gate|
        next unless gate.is_a?(Hash)

        Array(gate["evidence"]).each { |path| partition.fetch("audit_security") << path if path.is_a?(String) }
        coverage = gate["coverage"]
        next unless coverage.is_a?(Hash)

        coverage.each_value do |check|
          next unless check.is_a?(Hash)

          Array(check["evidence"]).each { |path| partition.fetch("audit_security") << path if path.is_a?(String) }
        end
      end
    end
    partition.transform_values { |paths| paths.uniq.sort }
  end

  def chapter_metadata(root, relative)
    body = File.read(File.join(root, relative), encoding: "UTF-8")
    match = body.match(/\A---\s*\n(.*?)\n---\s*\n/m)
    return {} unless match

    StrictYaml.safe_load(match[1], label: relative) || {}
  rescue Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError => e
    raise ContractError, "E_CHAPTER_METADATA #{relative}: #{e.message.lines.first.to_s.strip}"
  end

  def explicit_public_artifacts(root, chapter, metadata)
    id = chapter.fetch("id")
    manifest_relative = "#{PUBLIC_ARTIFACT_MANIFEST_ROOT}/#{id}.yml"
    manifest_path = File.join(root, manifest_relative)
    unless File.file?(manifest_path) && !File.symlink?(manifest_path)
      raise ContractError, "E_PUBLIC_MANIFEST_MISSING #{manifest_relative}: review/verified chapter requires an explicit public artifact manifest"
    end

    manifest = StrictYaml.safe_load(File.read(manifest_path, encoding: "UTF-8"), label: manifest_relative)
    unless manifest.is_a?(Hash)
      raise ContractError, "E_PUBLIC_MANIFEST_SCHEMA #{manifest_relative}: root must be a mapping"
    end
    schema_path = File.join(root, PUBLIC_ARTIFACT_SCHEMA_RELATIVE)
    schema = StrictJson.parse(File.read(schema_path, encoding: "UTF-8"))
    evaluator = ExecutableJsonSchema.new(schema, PUBLIC_ARTIFACT_SCHEMA_RELATIVE)
    definition_error = evaluator.definition_errors.first
    raise ContractError, "E_PUBLIC_MANIFEST_SCHEMA #{definition_error}" if definition_error
    instance_error = evaluator.validate(manifest).first
    raise ContractError, "E_PUBLIC_MANIFEST_SCHEMA #{manifest_relative}: #{instance_error}" if instance_error

    expected_identity = {
      "manifest_id" => "public-artifacts.#{id}",
      "edition" => chapter.fetch("edition", metadata["edition"]),
      "chapter_id" => id,
      "chapter_path" => chapter.fetch("path")
    }
    expected_identity.each do |field, value|
      unless manifest[field] == value
        raise ContractError, "E_PUBLIC_MANIFEST_IDENTITY #{manifest_relative}: #{field} must equal #{value.inspect}"
      end
    end

    expected_roots = %w[examples labs exercises].map { |kind| "#{kind}/encyclopedia/#{id}" }
    %w[examples labs exercises].zip(expected_roots).each do |field, expected_root|
      unless metadata[field] == [expected_root]
        raise ContractError, "E_PUBLIC_ROOT_DECLARATION #{chapter.fetch('path')}: #{field} must explicitly declare only #{expected_root}"
      end
    end
    unless manifest.fetch("managed_roots") == expected_roots
      raise ContractError, "E_PUBLIC_ROOT_DECLARATION #{manifest_relative}: managed_roots must use canonical examples/labs/exercises order"
    end

    artifact_paths = manifest.fetch("artifacts").map { |artifact| artifact.fetch("source_path") }
    metadata_paths = manifest.fetch("repository_metadata")
    duplicate = duplicate_value(artifact_paths + metadata_paths)
    raise ContractError, "E_PUBLIC_INPUT_DUPLICATE #{duplicate}: public input is declared more than once" if duplicate
    (artifact_paths + metadata_paths).each do |path|
      unless expected_roots.any? { |managed_root| path.start_with?(managed_root + "/") }
        raise ContractError, "E_PUBLIC_INPUT_OWNER #{path}: public input is outside the chapter managed roots"
      end
      validate_not_generated!(path)
    end

    actual = expected_roots.flat_map { |managed_root| managed_root_inventory(root, managed_root) }.sort
    declared = (artifact_paths + metadata_paths).sort
    extra = actual - declared
    missing = declared - actual
    raise ContractError, "E_PUBLIC_INPUT_OMITTED #{extra.first}: managed root contains an undeclared file" unless extra.empty?
    raise ContractError, "E_PUBLIC_INPUT_MISSING #{missing.first}: manifest declares a missing file" unless missing.empty?

    { manifest: manifest_relative, artifacts: artifact_paths.sort, repository_metadata: metadata_paths.sort }
  rescue JSON::ParserError, StrictJson::DuplicateMemberError => e
    raise ContractError, "E_PUBLIC_MANIFEST_SCHEMA #{PUBLIC_ARTIFACT_SCHEMA_RELATIVE}: #{e.message.lines.first.to_s.strip}"
  rescue Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError => e
    raise ContractError, "E_PUBLIC_MANIFEST_SCHEMA #{manifest_relative}: #{e.message.lines.first.to_s.strip}"
  end

  def managed_root_inventory(root, relative_root)
    absolute_root = File.join(root, relative_root)
    stat = File.lstat(absolute_root)
    raise ContractError, "E_PUBLIC_ROOT_SYMLINK #{relative_root}: symbolic links are forbidden" if stat.symlink?
    raise ContractError, "E_PUBLIC_ROOT_TYPE #{relative_root}: managed root must be a directory" unless stat.directory?

    paths = Dir.glob(File.join(absolute_root, "**", "*"), File::FNM_DOTMATCH).sort.each_with_object([]) do |path, memo|
      relative_path = relative(root, path)
      entry_stat = File.lstat(path)
      next if entry_stat.directory? && !entry_stat.symlink?
      if entry_stat.symlink?
        raise ContractError, "E_PUBLIC_INPUT_SYMLINK #{relative_path}: symbolic links are forbidden"
      end
      unless entry_stat.file?
        raise ContractError, "E_PUBLIC_INPUT_TYPE #{relative_path}: managed roots may contain only regular files"
      end
      memo << relative_path
    end
    collision = paths.group_by(&:downcase).values.find { |items| items.length > 1 }
    raise ContractError, "E_PUBLIC_INPUT_CASE #{collision.sort.first}: case-folded paths collide" if collision
    paths
  rescue Errno::ENOENT
    raise ContractError, "E_PUBLIC_ROOT_MISSING #{relative_root}: managed root is missing"
  end

  def category_for(path)
    case path
    when %r{\Abook/}, %r{\Aversions/}
      "content"
    when %r{\A(?:examples|labs|exercises)/encyclopedia/}
      "content"
    when "ASSESSMENTS.md", "PROGRESS.md", "curriculum/gates.yml", "curriculum/route-plans/gates.yml",
         "curriculum/review-p1.md"
      "audit_security"
    when %r{\Acurriculum/migrations/}, %r{\Arecords/encyclopedia/(?:evidence|reviews)/}
      "audit_security"
    when "factorycare-design/testing/acceptance-catalog.md"
      "audit_security"
    when %r{\Acurriculum/}
      path.end_with?(".rb") ? "build_control" : "content"
    when %r{\A(?:schemas|scripts|site)/}, %r{\Apublication/manifests/public-artifacts/}
      "build_control"
    end
  end

  def explicit_public_category(path, partition)
    CATEGORY_ORDER.find { |category| partition.fetch(category).include?(path) }
  end

  def validate_explicit_partition!(partition)
    owners = Hash.new { |hash, key| hash[key] = [] }
    partition.each { |category, paths| paths.each { |path| owners[path] << category } }
    overlap = owners.find { |_path, categories| categories.uniq.length > 1 }
    return true unless overlap

    raise ContractError,
          "E_INPUT_CATEGORY_OVERLAP #{overlap.first}: explicitly declared in #{overlap.last.uniq.join(', ')}"
  end

  def validate_partition!(categories, expected)
    unless categories.is_a?(Hash) && categories.keys == CATEGORY_ORDER
      raise ContractError, "E_INPUT_CATEGORY_SET: categories must appear exactly as #{CATEGORY_ORDER.join(', ')}"
    end
    categories.each do |category, paths|
      unless paths.is_a?(Array) && paths.all? { |path| path.is_a?(String) }
        raise ContractError, "E_INPUT_CATEGORY_SHAPE #{category}: category must be an array of repository paths"
      end
      duplicate = duplicate_value(paths)
      raise ContractError, "E_INPUT_CATEGORY_DUPLICATE #{duplicate}: duplicate path inside #{category}" if duplicate
    end

    owners = Hash.new { |hash, key| hash[key] = [] }
    categories.each { |category, paths| paths.each { |path| owners[path] << category } }
    overlap = owners.find { |_path, category_names| category_names.length > 1 }
    if overlap
      raise ContractError, "E_INPUT_CATEGORY_OVERLAP #{overlap.first}: appears in #{overlap.last.join(', ')}"
    end

    actual = owners.keys.sort
    expected = expected.uniq.sort
    missing = expected - actual
    extra = actual - expected
    raise ContractError, "E_INPUT_CATEGORY_OMISSION #{missing.first}: expected input is uncategorized" unless missing.empty?
    raise ContractError, "E_INPUT_CATEGORY_EXTRA #{extra.first}: categorized input is outside the authoritative inventory" unless extra.empty?

    collision = actual.group_by(&:downcase).values.find { |items| items.length > 1 }
    raise ContractError, "E_INPUT_CASE_COLLISION #{collision.sort.first}: case-folded paths collide" if collision
    actual.each do |path|
      raise ContractError, "E_PRIVATE_INPUT #{path}: private inputs are forbidden" if path.start_with?("solutions-private/")
      validate_not_generated!(path)
    end
    true
  end

  def validate_tracked!(root, paths)
    stdout, stderr, status = Open3.capture3("git", "-C", root, "ls-files", "-z", "--")
    raise ContractError, "E_GIT_INDEX: cannot enumerate tracked P2 inputs: #{stderr.lines.first.to_s.strip}" unless status.success?

    tracked = stdout.split("\0").to_set
    untracked = paths.find { |path| !tracked.include?(path) }
    raise ContractError, "E_INPUT_UNTRACKED #{untracked}: P2 inputs must be Git tracked" if untracked
    true
  end

  def snapshots(root, categories)
    categories.values.flatten.sort.to_h do |path|
      [path, File.binread(File.join(root, path)).b.freeze]
    end
  end

  def file_digests(categories, snapshots)
    CATEGORY_ORDER.to_h do |category|
      entries = categories.fetch(category).sort.to_h do |path|
        [path, Digest::SHA256.hexdigest(snapshots.fetch(path))]
      end
      [category, entries]
    end
  end

  def category_digests(file_digests)
    CATEGORY_ORDER.to_h do |category|
      sha = Digest::SHA256.new
      file_digests.fetch(category).sort.each do |path, content_sha256|
        sha << path << "\0" << content_sha256 << "\0"
      end
      [category, sha.hexdigest]
    end
  end

  def total_digest(category_digests)
    sha = Digest::SHA256.new
    CATEGORY_ORDER.each do |category|
      sha << category << "\0" << category_digests.fetch(category) << "\0"
    end
    sha.hexdigest
  end

  def validate_snapshots!(root, snapshots)
    changed = snapshots.find do |path, bytes|
      absolute = File.join(root, path)
      !File.file?(absolute) || File.symlink?(absolute) || File.binread(absolute).b != bytes
    end
    raise ContractError, "E_INPUT_CHANGED #{changed.first}: input changed during P2 build" if changed
    true
  end

  def validate_not_generated!(path)
    components = path.split("/")
    if (components & GENERATED_COMPONENTS).any? || path.match?(GENERATED_SUFFIX) || components.include?(".DS_Store")
      raise ContractError, "E_INPUT_TEMPORARY #{path}: generated, cache, log and temporary inputs are forbidden"
    end
  end

  def duplicate_value(values)
    seen = Set.new
    values.find { |value| !seen.add?(value) }
  end

  def relative(root, path)
    path.delete_prefix(File.expand_path(root) + File::SEPARATOR)
  end
end

class EncyclopediaValidator
  attr_reader :errors, :warnings, :stats

  def initialize(root, check_generated: false, quiet: false)
    @root = File.realpath(root)
    @check_generated = check_generated
    @quiet = quiet
    @errors = []
    @warnings = []
    @stats = {}
    @schemas = {}
    @path_policy = RepositoryPathPolicy.new(@root)
  end

  def run
    unless validate_fixed_canonical_inputs
      report
      return false
    end
    validate_auxiliary_yaml_documents
    validate_strict_catalog if errors.empty?
    validate_schema_documents
    registry = validate_registry
    catalog = validate_catalog_and_chapters(registry)
    validate_canonical_input_set(catalog) if errors.empty?
    site_config = validate_site_config(catalog)
    validate_edition_alignment(registry, catalog, site_config)
    status_contract = FactoryCareStatusContract.validate(@root)
    errors.concat(status_contract.fetch(:errors))
    stats[:factorycare_status_files] = status_contract.fetch(:scanned_files)
    validate_generated if @check_generated && errors.empty?
    report
    errors.empty?
  rescue StandardError => e
    errors << "validator crashed: #{e.class}: #{e.message}"
    report
    false
  end

  private

  def validate_fixed_canonical_inputs
    paths = %w[
      ASSESSMENTS.md
      PROGRESS.md
      curriculum/catalog.yml
      curriculum/gates.yml
      curriculum/validate_catalog.rb
      curriculum/routes/accelerated-48.yml
      curriculum/routes/factorycare-project.yml
      curriculum/routes/reference.yml
      curriculum/routes/zero-base.yml
      versions/registry.yml
      site/config.yml
      schemas/chapter.schema.json
      schemas/public-artifact-manifest.schema.json
      schemas/site-publication-manifest-v3.schema.json
      schemas/version-registry.schema.json
      schemas/site-config.schema.json
      scripts/build-book.rb
      scripts/validate-encyclopedia.rb
      site/index.html
      site/assets/site.css
      site/assets/site.js
    ]
    strict_scan = Dir.glob(absolute("{book,curriculum}/**/*.{md,yml,json,rb}"), File::FNM_EXTGLOB)
                     .select { |path| File.file?(path) || File.symlink?(path) }
                     .map { |path| relative_to_root(path) }
    paths.concat(strict_scan)
    paths.concat(Dir.glob(absolute("scripts/lib/**/*.rb")).map { |path| relative_to_root(path) })
    before = errors.length
    paths.uniq.sort.each { |relative| validate_canonical_regular_file(relative) }
    return false unless errors.length == before

    catalog = StrictYaml.safe_load(File.read(absolute(CATALOG_RELATIVE), encoding: "UTF-8"), label: CATALOG_RELATIVE)
    unless catalog.is_a?(Hash)
      errors << "#{CATALOG_RELATIVE}: root must be a mapping during canonical input preflight"
      return false
    end
    chapter_paths = Array(catalog["chapters"]).each_with_object([]) do |chapter, memo|
      memo << chapter["path"] if chapter.is_a?(Hash) && chapter["path"].is_a?(String)
    end
    volume_readmes = chapter_paths.map { |path| File.join(File.dirname(File.dirname(path)), "README.md") }
    (chapter_paths + volume_readmes).uniq.sort.each { |relative| validate_canonical_regular_file(relative) }
    errors.length == before
  rescue Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError => e
    errors << "#{CATALOG_RELATIVE}: invalid YAML during canonical input preflight: #{e.message.lines.first.to_s.strip}"
    false
  end

  def validate_canonical_input_set(catalog)
    inventory = EncyclopediaInputSet.inventory(@root, catalog)
    inventory.fetch(:expected).each { |relative| validate_canonical_regular_file(relative) }
    stats[:p2_input_categories] = inventory.fetch(:categories).transform_values(&:length)
  rescue EncyclopediaInputSet::ContractError => e
    errors << "P2 input contract: #{e.message}"
  end

  def validate_canonical_regular_file(relative)
    errors.concat(@path_policy.validate_regular_file(
      relative,
      label: "canonical input #{relative}",
      patterns: [Regexp.new("\\A#{Regexp.escape(relative)}\\z")]
    ))
  end

  def absolute(relative)
    File.expand_path(relative, @root)
  end

  def load_yaml(relative)
    path = absolute(relative)
    unless File.file?(path)
      errors << "missing YAML file #{relative}"
      return {}
    end
    data = StrictYaml.safe_load(File.read(path, encoding: "UTF-8"), label: relative)
    unless data.is_a?(Hash)
      errors << "#{relative}: root must be a mapping"
      return {}
    end
    data
  rescue Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError => e
    errors << "#{relative}: invalid YAML: #{e.message.lines.first.to_s.strip}"
    {}
  end

  def validate_auxiliary_yaml_documents
    paths = (Dir.glob(absolute("curriculum/**/*.yml")).sort - [absolute(CATALOG_RELATIVE)]) + [
      absolute(REGISTRY_RELATIVE),
      absolute(SITE_CONFIG_RELATIVE)
    ]
    paths.each do |path|
      relative = relative_to_root(path)
      StrictYaml.validate_unique_keys!(File.read(path, encoding: "UTF-8"), label: relative)
    rescue Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError => e
      errors << "#{relative}: invalid YAML: #{e.message.lines.first.to_s.strip}"
    end
  end

  def validate_strict_catalog
    command = [RbConfig.ruby, absolute("curriculum/validate_catalog.rb")]
    stdout, stderr, status = Open3.capture3(*command, chdir: @root)
    return if status.success?

    message = [stdout, stderr].reject(&:empty?).join("\n").strip
    errors << "strict curriculum validation failed\n#{message}"
  end

  def load_json(relative)
    path = absolute(relative)
    unless File.file?(path)
      errors << "missing JSON file #{relative}"
      return nil
    end
    StrictJson.parse(File.read(path, encoding: "UTF-8"))
  rescue JSON::ParserError, StrictJson::DuplicateMemberError => e
    errors << "#{relative}: invalid JSON: #{e.message}"
    nil
  end

  def validate_schema_documents
    {
      CHAPTER_SCHEMA_RELATIVE => "https://factorycare.local/schemas/chapter.schema.json",
      REGISTRY_SCHEMA_RELATIVE => "https://factorycare.local/schemas/version-registry.schema.json",
      SITE_CONFIG_SCHEMA_RELATIVE => "https://factorycare.local/schemas/site-config.schema.json",
      EncyclopediaInputSet::PUBLIC_ARTIFACT_SCHEMA_RELATIVE => "https://factorycare.local/schemas/public-artifact-manifest.schema.json",
      SITE_GENERATED_SCHEMA_RELATIVE => "https://factorycare.local/schemas/site-publication-manifest-v3.schema.json"
    }.each do |relative, expected_id|
      schema = load_json(relative)
      next unless schema

      unless schema.is_a?(Hash)
        errors << "#{relative}: schema document root must be an object containing the canonical $id"
        next
      end

      errors << "#{relative}: unexpected $id" unless schema["$id"] == expected_id
      errors << "#{relative}: must declare JSON Schema draft 2020-12" unless schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
      executable = ExecutableJsonSchema.new(schema, relative)
      errors.concat(executable.definition_errors)
      @schemas[relative] = executable if executable.definition_errors.empty?
    end
    stats[:schemas_executed] = @schemas.length
  end

  def apply_schema(schema_relative, value, label)
    schema = @schemas[schema_relative]
    return unless schema

    schema.validate(value).each { |message| errors << "#{label}: #{message}" }
  end

  def validate_registry
    registry = load_yaml(REGISTRY_RELATIVE)
    apply_schema(REGISTRY_SCHEMA_RELATIVE, registry, REGISTRY_RELATIVE)
    validate_date(registry["reviewed_at"], "#{REGISTRY_RELATIVE}: reviewed_at")
    entries = registry["entries"].is_a?(Array) ? registry["entries"] : []
    ids = entries.select { |entry| entry.is_a?(Hash) }.map { |entry| entry["id"] }.compact
    duplicate_values(ids).each { |id| errors << "#{REGISTRY_RELATIVE}: duplicate entry id #{id}" }
    entries.each_with_index do |entry, index|
      next unless entry.is_a?(Hash)

      entry_label = "#{REGISTRY_RELATIVE}: entry ##{index + 1}"
      validate_date(entry["reviewed_at"], "#{entry_label} reviewed_at")
      validate_date_not_after(entry["reviewed_at"], registry["reviewed_at"], "#{entry_label} reviewed_at", "registry reviewed_at")
      sources = entry["sources"].is_a?(Array) ? entry["sources"] : []
      source_ids = sources.select { |source| source.is_a?(Hash) }.map { |source| source["id"] }.compact
      duplicate_values(source_ids).each { |source_id| errors << "#{entry_label} has duplicate source id #{source_id}" }
      sources.each_with_index do |source, source_index|
        next unless source.is_a?(Hash)

        source_label = "#{entry_label} source ##{source_index + 1}"
        validate_date(source["checked_at"], "#{source_label} checked_at")
        validate_date_not_after(source["checked_at"], entry["reviewed_at"], "#{source_label} checked_at", "entry reviewed_at")
        validate_https_source_url(source["url"], "#{source_label} url")
      end
    end
    stats[:registry_entries] = entries.length
    stats[:registry_sources] = entries.sum do |entry|
      entry.is_a?(Hash) && entry["sources"].is_a?(Array) ? entry["sources"].length : 0
    end
    registry.merge("entries" => entries)
  end

  def validate_catalog_and_chapters(registry)
    catalog = load_yaml(CATALOG_RELATIVE)
    @catalog_edition = catalog["edition"]
    expected_catalog_header = {
      "schema_version" => 2,
      "canonical" => true,
      "generated" => true,
      "generated_by" => CURRICULUM_GENERATOR
    }
    expected_catalog_header.each do |field, expected|
      errors << "#{CATALOG_RELATIVE}: #{field} must equal #{expected.inspect}" unless catalog[field] == expected
    end
    unless catalog["generated_spec_digest"].is_a?(String) && catalog["generated_spec_digest"].match?(/\A[0-9a-f]{64}\z/)
      errors << "#{CATALOG_RELATIVE}: generated_spec_digest must be a lowercase SHA-256 digest"
    end
    chapters = catalog["chapters"]
    unless chapters.is_a?(Array)
      errors << "#{CATALOG_RELATIVE}: chapters must be an array"
      stats[:chapters] = 0
      return catalog.merge("chapters" => [])
    end

    @chapters_by_id = chapters.select { |chapter| chapter.is_a?(Hash) && chapter["id"].is_a?(String) }
                              .each_with_object({}) { |chapter, memo| memo[chapter["id"]] = chapter }

    registry_entries = registry.fetch("entries", []).select { |entry| entry.is_a?(Hash) && entry["id"].is_a?(String) }
    registry_by_id = registry_entries.each_with_object({}) { |entry, memo| memo[entry["id"]] = entry }
    registry_ids = registry_by_id.keys.to_set
    ids = []
    expected_paths = []
    status_counts = Hash.new(0)
    referenced_surfaces = Set.new

    chapters.each_with_index do |chapter, index|
      unless chapter.is_a?(Hash)
        errors << "#{CATALOG_RELATIVE}: chapter ##{index + 1} must be a mapping"
        next
      end
      missing = BASE_CATALOG_FIELDS.reject { |field| chapter.key?(field) }
      errors << "#{CATALOG_RELATIVE}: chapter ##{index + 1} missing #{missing.join(", ")}" unless missing.empty?
      id = chapter["id"]
      ids << id if id.is_a?(String)
      status_counts[chapter["status"]] += 1
      errors << "#{CATALOG_RELATIVE}: #{id || "chapter ##{index + 1}"} has invalid semantic id" unless id.is_a?(String) && id.match?(CHAPTER_ID_PATTERN)
      errors << "#{CATALOG_RELATIVE}: #{id} uses retired versioned_surface field" if chapter.key?("versioned_surface")
      unless chapter["responsibility"].is_a?(String) && chapter["responsibility"].length >= 12
        errors << "#{CATALOG_RELATIVE}: #{id} responsibility must describe a concrete boundary"
      end
      unless chapter["spec_digest"].is_a?(String) && chapter["spec_digest"].match?(/\A[0-9a-f]{64}\z/)
        errors << "#{CATALOG_RELATIVE}: #{id} spec_digest must be a lowercase SHA-256 digest"
      end
      errors << "#{CATALOG_RELATIVE}: #{id} has invalid level #{chapter["level"].inspect}" unless ALLOWED_LEVELS.include?(chapter["level"])
      errors << "#{CATALOG_RELATIVE}: #{id} has invalid status #{chapter["status"].inspect}" unless ALLOWED_STATUSES.include?(chapter["status"])
      validate_outcome_contract("#{CATALOG_RELATIVE}: #{id}", catalog_outcomes(chapter), chapter)
      prerequisites = catalog_prerequisites(chapter)
      rationales = chapter["prerequisite_rationales"]
      unless rationales.is_a?(Hash) && rationales.keys.sort == prerequisites.sort
        errors << "#{CATALOG_RELATIVE}: #{id} prerequisite rationale keys must exactly match prerequisites"
      end
      prerequisites.each do |dependency|
        unless dependency.is_a?(String) && dependency.match?(CHAPTER_ID_PATTERN)
          errors << "#{CATALOG_RELATIVE}: #{id} has invalid semantic prerequisite #{dependency.inspect}"
        end
        errors << "#{CATALOG_RELATIVE}: #{id} references unknown prerequisite #{dependency}" unless @chapters_by_id.key?(dependency)
        rationale = rationales.is_a?(Hash) ? rationales[dependency] : nil
        reason = rationale.is_a?(Hash) ? rationale["reason"] : nil
        unless reason.is_a?(String) && !reason.strip.empty? && !reason.include?("\n")
          errors << "#{CATALOG_RELATIVE}: #{id} prerequisite #{dependency} must have a one-line reason"
        end
      end
      recommended_after = chapter["recommended_after"]
      unless recommended_after.is_a?(Array) && recommended_after.uniq.length == recommended_after.length
        errors << "#{CATALOG_RELATIVE}: #{id} recommended_after must be a unique array"
      end
      Array(recommended_after).each do |recommendation|
        unless recommendation.is_a?(String) && recommendation.match?(CHAPTER_ID_PATTERN)
          errors << "#{CATALOG_RELATIVE}: #{id} has invalid semantic recommended_after #{recommendation.inspect}"
        end
      end

      surfaces = catalog_version_surfaces(chapter)
      duplicate_values(surfaces).each { |surface| errors << "#{CATALOG_RELATIVE}: #{id} repeats versioned surface #{surface}" }
      surfaces.each do |surface|
        referenced_surfaces << surface
        errors << "#{CATALOG_RELATIVE}: #{id} references unknown version surface #{surface}" unless registry_ids.include?(surface)
      end

      relative = chapter["path"]
      expected_path_pattern = if id.is_a?(String) && chapter["volume"].is_a?(String)
                                %r{\Abook/volume-#{Regexp.escape(chapter["volume"])}-[a-z0-9-]+/chapters/#{Regexp.escape(id)}\.md\z}
                              else
                                /\A\b\B/
                              end
      path_issues = @path_policy.validate_regular_file(
        relative,
        label: "#{CATALOG_RELATIVE}: #{id} chapter path",
        patterns: [expected_path_pattern]
      )
      errors.concat(path_issues)
      next unless path_issues.empty?

      expected_paths << relative
      validate_chapter_file(chapter, relative, registry_ids, registry_by_id)
    end

    duplicate_values(ids).each { |id| errors << "#{CATALOG_RELATIVE}: duplicate chapter id #{id}" }
    duplicate_values(expected_paths).each { |path| errors << "#{CATALOG_RELATIVE}: duplicate chapter path #{path}" }
    validate_verified_prerequisite_closure(chapters)
    actual_paths = Dir.glob(absolute("book/volume-*/chapters/*.md")).sort.map { |path| relative_to_root(path) }
    (actual_paths - expected_paths).each { |path| errors << "chapter file is absent from catalog: #{path}" }
    (expected_paths - actual_paths).each { |path| errors << "catalog chapter file is missing: #{path}" }

    stats[:chapters] = chapters.length
    stats[:status_counts] = status_counts
    stats[:referenced_surfaces] = referenced_surfaces.length
    stats[:unreferenced_registry_entries] = [registry_ids.length - referenced_surfaces.length, 0].max
    catalog
  end

  def validate_verified_prerequisite_closure(chapters)
    by_id = chapters.select { |chapter| chapter.is_a?(Hash) && chapter["id"].is_a?(String) }
                    .each_with_object({}) { |chapter, memo| memo[chapter["id"]] = chapter }
    by_id.each_value do |chapter|
      next unless chapter["status"] == "verified"

      visited = Set.new
      pending = Array(chapter["prerequisites"]).dup
      not_verified = []
      until pending.empty?
        dependency_id = pending.shift
        next if visited.include?(dependency_id)

        visited << dependency_id
        dependency = by_id[dependency_id]
        next unless dependency

        not_verified << "#{dependency_id}(#{dependency["status"]})" unless dependency["status"] == "verified"
        pending.concat(Array(dependency["prerequisites"]))
      end
      next if not_verified.empty?

      errors << "#{CATALOG_RELATIVE}: #{chapter["id"]} verified hard-prerequisite closure contains non-verified chapters: #{not_verified.sort.join(", ")}"
    end
  end

  def catalog_prerequisites(chapter)
    value = chapter["prerequisites"]
    value.is_a?(Array) ? value : []
  end

  def catalog_outcomes(chapter)
    chapter["outcomes"].is_a?(Array) ? chapter["outcomes"] : []
  end

  def catalog_version_surfaces(chapter)
    value = chapter["version_surfaces"]
    value.is_a?(Array) ? value : []
  end

  def validate_outcome_contract(label, outcomes, chapter)
    expected_ids = %w[explain build diagnose]
    expected_kinds = %w[concept independent-build fault-diagnosis]
    unless outcomes.is_a?(Array) && outcomes.length == 3
      errors << "#{label}: outcomes must contain exactly three structured entries"
      return
    end

    ids = outcomes.map { |outcome| outcome.is_a?(Hash) ? outcome["id"] : nil }
    kinds = outcomes.map { |outcome| outcome.is_a?(Hash) ? outcome["kind"] : nil }
    errors << "#{label}: outcome ids must appear exactly as #{expected_ids.join(', ')}" unless ids == expected_ids
    errors << "#{label}: outcome kinds must align exactly as #{expected_kinds.join(', ')}" unless kinds == expected_kinds

    capability_contract = chapter["capabilities"].is_a?(Hash) ? chapter["capabilities"] : {}
    allowed_capabilities = (Array(capability_contract["teaches"]) + Array(capability_contract["uses"])).to_set
    outcomes.each_with_index do |outcome, index|
      next unless outcome.is_a?(Hash)

      uses = outcome["uses_capabilities"]
      next unless uses.is_a?(Array)

      unauthorized = uses.reject { |capability| allowed_capabilities.include?(capability) }
      unless unauthorized.empty?
        errors << "#{label}: outcome ##{index + 1} uses capabilities outside the chapter contract: #{unauthorized.join(', ')}"
      end
    end
  end

  def validate_chapter_file(chapter, relative, registry_ids, registry_by_id)
    body = File.read(absolute(relative), encoding: "UTF-8")
    match = body.match(/\A---\s*\n(.*?)\n---\s*\n/m)
    unless match
      errors << "#{relative}: missing YAML front matter"
      return
    end
    metadata = StrictYaml.safe_load(match[1], label: relative)
    unless metadata.is_a?(Hash)
      errors << "#{relative}: front matter must be a mapping"
      return
    end
    apply_schema(CHAPTER_SCHEMA_RELATIVE, metadata, relative)

    missing = BASE_FRONT_MATTER_FIELDS.reject { |field| metadata.key?(field) }
    errors << "#{relative}: front matter missing #{missing.join(", ")}" unless missing.empty?
    %w[id title responsibility volume order level status path].each do |field|
      errors << "#{relative}: #{field} differs from catalog" unless metadata[field] == chapter[field]
    end
    errors << "#{relative}: schema_version must be 2" unless metadata["schema_version"] == 2
    errors << "#{relative}: edition differs from catalog" unless metadata["edition"] == @catalog_edition
    if metadata["catalog"].is_a?(String)
      resolved_catalog = File.expand_path(metadata["catalog"], File.dirname(absolute(relative)))
      errors << "#{relative}: catalog reference does not resolve to #{CATALOG_RELATIVE}" unless resolved_catalog == absolute(CATALOG_RELATIVE)
    end

    canonical = {
      "prerequisites" => catalog_prerequisites(chapter),
      "outcomes" => catalog_outcomes(chapter),
      "route_tags" => chapter["route_tags"],
      "stable_core" => chapter["stable_core"],
      "version_surfaces" => catalog_version_surfaces(chapter)
    }
    canonical.each do |field, value|
      errors << "#{relative}: #{field} differs from catalog" if metadata.key?(field) && metadata[field] != value
    end
    Array(metadata["version_surfaces"]).each do |surface|
      errors << "#{relative}: front matter references unknown version surface #{surface}" unless registry_ids.include?(surface)
    end

    status = chapter["status"]
    if status == "planned"
      forbidden = (AUTHORING_FIELDS + REVIEW_FIELDS) & metadata.keys
      errors << "#{relative}: planned placeholder contains human authoring fields #{forbidden.join(', ')}" unless forbidden.empty?
      errors << "#{relative}: planned chapter must carry the exact generator ownership marker" unless body.include?(PLANNED_PLACEHOLDER_MARKER)
      errors << "#{relative}: planned chapter generated_by differs from the canonical generator" unless metadata["generated_by"] == CURRICULUM_GENERATOR
      errors << "#{relative}: planned chapter generated_spec_digest differs from catalog" unless metadata["generated_spec_digest"] == chapter["spec_digest"]
      return
    end

    if metadata.key?("generated_by") || metadata.key?("generated_spec_digest") || body.include?(PLANNED_PLACEHOLDER_MARKER)
      errors << "#{relative}: human-authored #{status} chapter must not carry planned-placeholder ownership"
    end
    authoring_missing = AUTHORING_FIELDS.reject { |field| metadata.key?(field) }
    errors << "#{relative}: #{status} chapter missing authoring metadata #{authoring_missing.join(", ")}" unless authoring_missing.empty?
    validate_outcome_contract(relative, metadata["outcomes"], chapter) if metadata.key?("outcomes")
    validate_learning_prerequisite_block(chapter, relative, body)
    return unless %w[review verified].include?(status)

    review_missing = REVIEW_FIELDS.reject { |field| metadata.key?(field) }
    errors << "#{relative}: #{status} chapter missing review metadata #{review_missing.join(", ")}" unless review_missing.empty?
    validate_review_metadata(relative, metadata, chapter, registry_ids, registry_by_id, verified: status == "verified")
    validate_review_body(relative, body, status)
  rescue Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError => e
    errors << "#{relative}: invalid front matter YAML: #{e.message.lines.first.to_s.strip}"
  end

  def validate_learning_prerequisite_block(chapter, relative, body)
    expected = ChapterPrerequisiteBlock.synchronize(
      body,
      chapter: chapter,
      chapters_by_id: @chapters_by_id
    )
    unless expected == body
      errors << "#{relative}: learning prerequisite block must appear exactly once after the H1 and match catalog titles, links, and reasons"
    end

    catalog_prerequisites(chapter).each do |dependency_id|
      dependency = @chapters_by_id[dependency_id]
      next unless dependency

      link = ChapterPrerequisiteBlock.relative_link(relative, dependency.fetch("path"))
      resolved = File.expand_path(link, File.dirname(absolute(relative)))
      unless resolved == absolute(dependency.fetch("path")) && File.file?(resolved)
        errors << "#{relative}: prerequisite link for #{dependency_id} does not resolve to its catalog chapter"
      end
    end
  rescue ChapterPrerequisiteBlock::ContractError, KeyError => e
    errors << "#{relative}: invalid learning prerequisite block contract: #{e.message}"
  end

  def validate_review_metadata(relative, metadata, chapter, registry_ids, registry_by_id, verified:)
    validate_date(metadata["last_reviewed"], "#{relative}: last_reviewed")
    author = metadata["author"]
    validate_identity(author, "#{relative}: author")
    artifact_root = Regexp.escape(chapter.fetch("id"))
    evidence_root = Regexp.escape(chapter.fetch("id"))
    {
      "examples" => "examples",
      "labs" => "labs",
      "exercises" => "exercises",
      "solutions_private" => "solutions-private"
    }.each do |field, root|
      validate_artifact_list(relative, field, metadata[field], [
        %r{\A#{Regexp.escape(root)}/encyclopedia/#{artifact_root}(?:/[a-zA-Z0-9._/-]+)?\z}
      ])
    end

    source_ids = []
    Array(metadata["source_refs"]).each_with_index do |source, index|
      next unless source.is_a?(Hash)

      source_ids << source["id"] if source["id"].is_a?(String)
      validate_date(source["checked_at"], "#{relative}: source_refs ##{index + 1} checked_at")
      validate_https_source_url(source["url"], "#{relative}: source_refs ##{index + 1} url")
    end
    duplicate_values(source_ids).each { |id| errors << "#{relative}: duplicate source_refs id #{id}" }

    version_ids = []
    Array(metadata["verified_versions"]).each_with_index do |entry, index|
      next unless entry.is_a?(Hash)

      version_ids << entry["id"]
      validate_date(entry["verified_at"], "#{relative}: verified_versions ##{index + 1} verified_at")
      registry_entry = registry_by_id[entry["id"]]
      if registry_entry && entry["constraint"] != registry_entry["constraint"]
        errors << "#{relative}: verified_versions ##{index + 1} constraint must exactly match registry constraint #{registry_entry["constraint"].inspect}"
      end
      errors.concat(@path_policy.validate_regular_file(
        entry["evidence"],
        label: "#{relative}: verified_versions ##{index + 1} evidence",
        patterns: [%r{\Arecords/encyclopedia/evidence/#{evidence_root}/[a-zA-Z0-9._/-]+\z}],
        require_nonblank: true
      )) if entry["evidence"].is_a?(String)
      reject_legacy_id_in_path(entry["evidence"], "#{relative}: verified_versions ##{index + 1} evidence")
    end
    duplicate_values(version_ids.compact).each { |id| errors << "#{relative}: duplicate verified version #{id}" }
    catalog_version_surfaces(chapter).each do |surface|
      errors << "#{relative}: version surface #{surface} lacks chapter-level verification" unless version_ids.include?(surface)
    end
    version_ids.compact.each { |id| errors << "#{relative}: verified_versions references unknown surface #{id}" unless registry_ids.include?(id) }

    verification = metadata["verification"]
    return unless verification.is_a?(Hash)

    VERIFICATION_GATES.each do |gate|
      record = verification[gate]
      next unless record.is_a?(Hash)

      status = record["status"]
      validate_date(record["checked_at"], "#{relative}: verification #{gate} checked_at")
      reviewer = record["reviewer"]
      validate_identity(reviewer, "#{relative}: verification #{gate} reviewer")
      if valid_identity?(reviewer) && valid_identity?(author) && normalized_identity(reviewer) == normalized_identity(author)
        errors << "#{relative}: verification #{gate} reviewer must be independent from author"
      end
      validate_evidence_list(relative, "verification #{gate} evidence", record["evidence"], [
        %r{\Arecords/encyclopedia/evidence/#{evidence_root}/[a-zA-Z0-9._/-]+\z}
      ])
      validate_publication_coverage(relative, record, chapter_id: chapter.fetch("id"), verified: verified) if gate == "publication_navigation"
      next unless verified

      errors << "#{relative}: verified chapter requires #{gate} gate to pass" if MANDATORY_PASSED_GATES.include?(gate) && status != "passed"
      if CONDITIONAL_GATES.include?(gate) && status == "not-applicable"
        reason = record["applicability_reason"]
        errors << "#{relative}: not-applicable #{gate} gate needs a specific reason" unless reason.is_a?(String) && reason.strip.length >= 10
      elsif CONDITIONAL_GATES.include?(gate) && status != "passed"
        errors << "#{relative}: verified chapter has unresolved #{gate} gate"
      end
    end
  end

  def validate_artifact_list(relative, field, values, patterns)
    return unless values.is_a?(Array)

    values.each_with_index do |path, index|
      next unless path.is_a?(String)

      reject_legacy_id_in_path(path, "#{relative}: #{field} ##{index + 1}")
      errors.concat(@path_policy.validate_artifact(path, label: "#{relative}: #{field} ##{index + 1}", patterns: patterns))
    end
  end

  def validate_evidence_list(relative, field, values, patterns)
    return unless values.is_a?(Array)

    values.each_with_index do |path, index|
      next unless path.is_a?(String)

      reject_legacy_id_in_path(path, "#{relative}: #{field} ##{index + 1}")
      errors.concat(@path_policy.validate_regular_file(
        path,
        label: "#{relative}: #{field} ##{index + 1}",
        patterns: patterns,
        require_nonblank: true
      ))
    end
  end

  def validate_publication_coverage(relative, record, chapter_id:, verified:)
    coverage = record["coverage"]
    return unless coverage.is_a?(Hash)

    %w[links keyboard_semantics rendering].each do |name|
      check = coverage[name]
      next unless check.is_a?(Hash)

      validate_evidence_list(relative, "publication_navigation #{name} evidence", check["evidence"], [
        %r{\Arecords/encyclopedia/evidence/#{Regexp.escape(chapter_id)}/[a-zA-Z0-9._/-]+\z}
      ])
      next unless verified

      status = check["status"]
      if name == "keyboard_semantics" && status == "not-applicable"
        reason = check["applicability_reason"]
        errors << "#{relative}: not-applicable publication keyboard/semantics check needs a specific reason" unless reason.is_a?(String) && reason.strip.length >= 10
      elsif status != "passed"
        errors << "#{relative}: verified publication_navigation requires #{name} coverage to pass"
      end
    end
  end

  def validate_review_body(relative, body, status)
    prose = body.sub(/\A---\s*\n.*?\n---\s*\n/m, "")
    prose_without_code = prose.gsub(/```.*?```/m, " ")
    PLACEHOLDER_MARKERS.each do |marker|
      errors << "#{relative}: #{status} chapter must not contain placeholder marker #{marker.inspect}" if prose_without_code.include?(marker)
    end
    if prose_without_code.lines.any? { |line| PLACEHOLDER_LINE_PATTERN.match?(line) }
      errors << "#{relative}: #{status} chapter must not contain standalone TODO/TBD placeholder lines"
    end
    normalized = prose_without_code
                      .gsub(/[#>*_`|\[\]()-]/, " ")
                      .gsub(/[[:space:]]+/u, " ")
                      .strip
    errors << "#{relative}: #{status} chapter body must contain non-whitespace prose" if normalized.empty?
    heading_count = prose.lines.count { |line| line.match?(/\A##\s+/) }
    errors << "#{relative}: #{status} chapter needs at least two level-2 sections" if heading_count < 2
    errors << "#{relative}: #{status} chapter prose is too small for review (minimum 200 normalized characters)" if normalized.length < 200
  end

  def reject_legacy_id_in_path(path, label)
    return unless path.is_a?(String) && path.match?(LEGACY_CHAPTER_ID_PATTERN)

    errors << "#{label}: retired chapter IDs are forbidden in runtime paths"
  end

  def validate_site_config(catalog)
    config = load_yaml(SITE_CONFIG_RELATIVE)
    apply_schema(SITE_CONFIG_SCHEMA_RELATIVE, config, SITE_CONFIG_RELATIVE)
    errors << "#{SITE_CONFIG_RELATIVE}: site_id must match catalog_id" unless config["site_id"] == catalog["catalog_id"]
    errors << "#{SITE_CONFIG_RELATIVE}: edition must match catalog" unless config["edition"] == catalog["edition"]
    errors.concat(@path_policy.validate_output_directory(config["output"])) if config["output"].is_a?(String)
    config
  end

  def validate_edition_alignment(registry, catalog, site_config)
    editions = {
      REGISTRY_RELATIVE => registry["edition"],
      CATALOG_RELATIVE => catalog["edition"],
      SITE_CONFIG_RELATIVE => site_config["edition"]
    }
    return if editions.values.uniq.length == 1

    errors << "edition mismatch across registry/catalog/site: #{editions.map { |path, value| "#{path}=#{value.inspect}" }.join(", ")}"
  end

  def validate_generated
    command = [RbConfig.ruby, absolute("scripts/build-book.rb"), "--check"]
    stdout, stderr, status = Open3.capture3(*command, chdir: @root)
    if status.success?
      stats[:generated] = "checked-byte-for-byte"
      GENERATED_FILES.each do |name|
        relative = File.join("site/generated", name)
        next unless File.file?(absolute(relative))

        errors << "#{relative}: retired chapter ID leaked into runtime output" if File.read(absolute(relative), encoding: "UTF-8").match?(LEGACY_CHAPTER_ID_PATTERN)
      end
      return
    end

    message = [stdout, stderr].reject(&:empty?).join("\n").strip
    errors << "generated build check failed\n#{message}"
  end

  def validate_date(value, label)
    unless value.is_a?(String)
      errors << "#{label} must be a quoted ISO date"
      return
    end
    parsed = Date.iso8601(value)
    errors << "#{label} must use YYYY-MM-DD" unless parsed.strftime("%Y-%m-%d") == value
    errors << "#{label} cannot be in the future" if parsed > Date.today
  rescue ArgumentError
    errors << "#{label} is not a valid ISO date"
  end

  def validate_date_not_after(value, boundary, label, boundary_label)
    return unless value.is_a?(String) && boundary.is_a?(String)

    parsed = Date.iso8601(value)
    parsed_boundary = Date.iso8601(boundary)
    errors << "#{label} cannot be after #{boundary_label}" if parsed > parsed_boundary
  rescue ArgumentError
    # validate_date reports malformed dates with the more useful field label.
  end

  def validate_identity(value, label)
    errors << "#{label} must contain at least two non-whitespace characters" unless valid_identity?(value)
  end

  def validate_https_source_url(value, label)
    unless value.is_a?(String)
      errors << "#{label} must be an absolute HTTPS URI with a non-empty host"
      return
    end

    uri = URI.parse(value)
    valid = uri.is_a?(URI::HTTPS) && uri.host.is_a?(String) && !uri.host.empty? && uri.userinfo.nil?
    errors << "#{label} must be an absolute HTTPS URI with a non-empty host and no userinfo" unless valid
  rescue URI::InvalidURIError
    errors << "#{label} must be a valid absolute HTTPS URI"
  end

  def valid_identity?(value)
    value.is_a?(String) && unicode_trim(value.unicode_normalize(:nfkc)).length >= 2
  end

  def normalized_identity(value)
    unicode_trim(value.unicode_normalize(:nfkc)).downcase(:fold)
  end

  def unicode_trim(value)
    value.gsub(/\A[[:space:]]+/u, "").gsub(/[[:space:]]+\z/u, "")
  end

  def duplicate_values(values)
    counts = values.each_with_object(Hash.new(0)) { |value, memo| memo[value] += 1 }
    counts.select { |_value, count| count > 1 }.keys
  end

  def relative_to_root(path)
    path.delete_prefix(@root + File::SEPARATOR)
  end

  def report
    unless errors.empty?
      warn "ENCYCLOPEDIA INVALID (#{errors.length} error(s))"
      errors.each { |error| warn "- #{error}" }
      warnings.each { |warning| warn "WARN: #{warning}" }
      return
    end
    return if @quiet

    puts "ENCYCLOPEDIA VALID"
    puts "schemas_executed=#{stats.fetch(:schemas_executed, 0)}"
    puts "chapters=#{stats.fetch(:chapters, 0)}"
    ALLOWED_STATUSES.each do |status|
      puts "status_#{status}=#{stats.fetch(:status_counts, {}).fetch(status, 0)}"
    end
    puts "registry_entries=#{stats.fetch(:registry_entries, 0)}"
    puts "registry_sources=#{stats.fetch(:registry_sources, 0)}"
    puts "referenced_version_surfaces=#{stats.fetch(:referenced_surfaces, 0)}"
    puts "supplemental_registry_entries=#{stats.fetch(:unreferenced_registry_entries, 0)}"
    puts "factorycare_status_files=#{stats.fetch(:factorycare_status_files, 0)}"
    puts "generated=#{stats.fetch(:generated, @check_generated ? "missing" : "not-checked") }"
    puts "content_truth=not-asserted"
    warnings.each { |warning| puts "WARN: #{warning}" }
  end
end

if $PROGRAM_NAME == __FILE__
  options = { check_generated: false, quiet: false }
  OptionParser.new do |parser|
    parser.banner = "Usage: ruby scripts/validate-encyclopedia.rb [options]"
    parser.on("--check-generated", "also compare generated publication files byte-for-byte") { options[:check_generated] = true }
    parser.on("--quiet", "print only failures") { options[:quiet] = true }
  end.parse!

  validator = EncyclopediaValidator.new(ROOT, **options)
  exit(validator.run ? 0 : 1)
end
