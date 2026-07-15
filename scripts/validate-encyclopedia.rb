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

ROOT = File.expand_path("..", __dir__) unless defined?(ROOT)
CATALOG_RELATIVE = "curriculum/catalog.yml"
REGISTRY_RELATIVE = "versions/registry.yml"
SITE_CONFIG_RELATIVE = "site/config.yml"
CHAPTER_SCHEMA_RELATIVE = "schemas/chapter.schema.json"
REGISTRY_SCHEMA_RELATIVE = "schemas/version-registry.schema.json"
SITE_CONFIG_SCHEMA_RELATIVE = "schemas/site-config.schema.json"
GENERATED_FILES = %w[catalog.json navigation.json publication-manifest.json README.md search-index.json].freeze
BASE_CATALOG_FIELDS = %w[
  id title volume order level prerequisites outcomes status route_tags stable_core versioned_surface path
].freeze
BASE_FRONT_MATTER_FIELDS = %w[id title volume order level status catalog].freeze
AUTHORING_FIELDS = %w[schema_version prerequisites outcomes route_tags stable_core versioned_surface].freeze
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
    properties const enum pattern minLength minimum minItems uniqueItems items
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

  private

  def validate_definition(schema, path)
    return if schema == true || schema == false

    unless schema.is_a?(Hash)
      definition_errors << "#{@label} #{path}: schema node must be an object or boolean"
      return
    end

    unknown = schema.keys.reject { |key| SUPPORTED_KEYWORDS.include?(key) }
    unknown.each { |key| definition_errors << "#{@label} #{path}: unsupported schema keyword #{key}" }

    if schema.key?("type") && !SUPPORTED_TYPES.include?(schema["type"])
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
    %w[minLength minItems].each do |keyword|
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
    return ["#{label}: dot segments, empty segments and NUL bytes are forbidden"] if relative.include?("\0") || relative.split("/", -1).any? { |part| part.empty? || part == "." || part == ".." }

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
  module_function

  def files(root, catalog)
    paths = [
      "ASSESSMENTS.md",
      "PROGRESS.md",
      CATALOG_RELATIVE,
      REGISTRY_RELATIVE,
      SITE_CONFIG_RELATIVE,
      CHAPTER_SCHEMA_RELATIVE,
      REGISTRY_SCHEMA_RELATIVE,
      SITE_CONFIG_SCHEMA_RELATIVE,
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
    strict_inputs = Dir.glob(File.join(root, "{book,curriculum}", "**", "*.{md,yml,rb}"), File::FNM_EXTGLOB)
                       .select { |path| File.file?(path) || File.symlink?(path) }
                       .map { |path| relative(root, path) }
    paths.concat(strict_inputs)
    paths.concat(Dir.glob(File.join(root, "curriculum/routes/*.yml")).map { |path| relative(root, path) })
    paths.concat(Dir.glob(File.join(root, "book/volume-*/README.md")).map { |path| relative(root, path) })
    chapter_paths = Array(catalog["chapters"]).each_with_object([]) do |chapter, memo|
      memo << chapter["path"] if chapter.is_a?(Hash) && chapter["path"].is_a?(String)
    end
    paths.concat(chapter_paths)
    paths.concat(public_review_inputs(root, catalog))
    paths.reject! { |path| path.start_with?("solutions-private/") }
    paths.uniq.sort
  end

  def public_review_inputs(root, catalog)
    Array(catalog["chapters"]).each_with_object([]) do |chapter, memo|
      next unless chapter.is_a?(Hash) && %w[review verified].include?(chapter["status"])

      metadata = chapter_metadata(root, chapter["path"])
      %w[examples labs exercises].each do |field|
        Array(metadata[field]).each { |path| memo.concat(expand_public_path(root, path)) if path.is_a?(String) }
      end
      Array(metadata["verified_versions"]).each do |entry|
        memo.concat(expand_public_path(root, entry["evidence"])) if entry.is_a?(Hash) && entry["evidence"].is_a?(String)
      end
      verification = metadata["verification"]
      next unless verification.is_a?(Hash)

      verification.each_value do |gate|
        next unless gate.is_a?(Hash)

        Array(gate["evidence"]).each { |path| memo.concat(expand_public_path(root, path)) if path.is_a?(String) }
        coverage = gate["coverage"]
        next unless coverage.is_a?(Hash)

        coverage.each_value do |check|
          next unless check.is_a?(Hash)

          Array(check["evidence"]).each { |path| memo.concat(expand_public_path(root, path)) if path.is_a?(String) }
        end
      end
    end
  end

  def chapter_metadata(root, relative)
    body = File.read(File.join(root, relative), encoding: "UTF-8")
    match = body.match(/\A---\s*\n(.*?)\n---\s*\n/m)
    return {} unless match

    StrictYaml.safe_load(match[1], label: relative) || {}
  rescue StandardError
    {}
  end

  def expand_public_path(root, relative)
    return [] unless relative.is_a?(String)
    return [] if relative.start_with?("solutions-private/")

    absolute = File.join(root, relative)
    return [relative] if File.file?(absolute) || File.symlink?(absolute)
    return [] unless File.directory?(absolute)

    Dir.glob(File.join(absolute, "**", "*"), File::FNM_DOTMATCH).sort.each_with_object([]) do |path, memo|
      next unless File.file?(path) || File.symlink?(path)

      memo << self.relative(root, path)
    end
  end

  def digest(root, paths)
    sha = Digest::SHA256.new
    paths.each do |relative|
      sha << relative << "\0" << File.binread(File.join(root, relative)) << "\0"
    end
    sha.hexdigest
  end

  def digests(root, paths)
    paths.each_with_object({}) { |relative, memo| memo[relative] = Digest::SHA256.file(File.join(root, relative)).hexdigest }
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
    validate_canonical_input_set(catalog)
    site_config = validate_site_config(catalog)
    validate_edition_alignment(registry, catalog, site_config)
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
      schemas/version-registry.schema.json
      schemas/site-config.schema.json
      scripts/build-book.rb
      scripts/validate-encyclopedia.rb
      site/index.html
      site/assets/site.css
      site/assets/site.js
    ]
    strict_scan = Dir.glob(absolute("{book,curriculum}/**/*.{md,yml,rb}"), File::FNM_EXTGLOB)
                     .select { |path| File.file?(path) || File.symlink?(path) }
                     .map { |path| relative_to_root(path) }
    paths.concat(strict_scan)
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
    EncyclopediaInputSet.files(@root, catalog).each { |relative| validate_canonical_regular_file(relative) }
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
      SITE_CONFIG_SCHEMA_RELATIVE => "https://factorycare.local/schemas/site-config.schema.json"
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
    validate_date(registry["verified_at"], "#{REGISTRY_RELATIVE}: verified_at")
    entries = registry["entries"].is_a?(Array) ? registry["entries"] : []
    ids = entries.select { |entry| entry.is_a?(Hash) }.map { |entry| entry["id"] }.compact
    duplicate_values(ids).each { |id| errors << "#{REGISTRY_RELATIVE}: duplicate entry id #{id}" }
    entries.each_with_index do |entry, index|
      next unless entry.is_a?(Hash)

      validate_date(entry["verified_at"], "#{REGISTRY_RELATIVE}: entry ##{index + 1} verified_at")
      validate_https_source_url(entry["source_url"], "#{REGISTRY_RELATIVE}: entry ##{index + 1} source_url")
    end
    stats[:registry_entries] = entries.length
    registry.merge("entries" => entries)
  end

  def validate_catalog_and_chapters(registry)
    catalog = load_yaml(CATALOG_RELATIVE)
    chapters = catalog["chapters"]
    unless chapters.is_a?(Array)
      errors << "#{CATALOG_RELATIVE}: chapters must be an array"
      stats[:chapters] = 0
      return catalog.merge("chapters" => [])
    end

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
      errors << "#{CATALOG_RELATIVE}: #{id || "chapter ##{index + 1}"} has invalid id" unless id.is_a?(String) && id.match?(/\Av\d{2}\.c\d{2}\.[a-z0-9-]+\z/)
      errors << "#{CATALOG_RELATIVE}: #{id} has invalid level #{chapter["level"].inspect}" unless ALLOWED_LEVELS.include?(chapter["level"])
      errors << "#{CATALOG_RELATIVE}: #{id} has invalid status #{chapter["status"].inspect}" unless ALLOWED_STATUSES.include?(chapter["status"])

      surfaces = catalog_version_surfaces(chapter)
      duplicate_values(surfaces).each { |surface| errors << "#{CATALOG_RELATIVE}: #{id} repeats versioned surface #{surface}" }
      surfaces.each do |surface|
        referenced_surfaces << surface
        errors << "#{CATALOG_RELATIVE}: #{id} references unknown version surface #{surface}" unless registry_ids.include?(surface)
      end

      relative = chapter["path"]
      path_issues = @path_policy.validate_regular_file(
        relative,
        label: "#{CATALOG_RELATIVE}: #{id} chapter path",
        patterns: [%r{\Abook/volume-[0-9]{2}-[a-z0-9-]+/chapters/v[0-9]{2}\.c[0-9]{2}\.[a-z0-9-]+\.md\z}]
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
    value = chapter["versioned_surface"]
    value.is_a?(Array) ? value : []
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
    %w[id title volume order level status].each do |field|
      errors << "#{relative}: #{field} differs from catalog" unless metadata[field] == chapter[field]
    end
    if metadata["catalog"].is_a?(String)
      resolved_catalog = File.expand_path(metadata["catalog"], File.dirname(absolute(relative)))
      errors << "#{relative}: catalog reference does not resolve to #{CATALOG_RELATIVE}" unless resolved_catalog == absolute(CATALOG_RELATIVE)
    end

    canonical = {
      "prerequisites" => catalog_prerequisites(chapter),
      "outcomes" => catalog_outcomes(chapter),
      "route_tags" => chapter["route_tags"],
      "stable_core" => chapter["stable_core"],
      "versioned_surface" => catalog_version_surfaces(chapter)
    }
    canonical.each do |field, value|
      errors << "#{relative}: #{field} differs from catalog" if metadata.key?(field) && metadata[field] != value
    end
    Array(metadata["versioned_surface"]).each do |surface|
      errors << "#{relative}: front matter references unknown version surface #{surface}" unless registry_ids.include?(surface)
    end

    status = chapter["status"]
    if status == "planned"
      errors << "#{relative}: planned chapter must visibly state that it is an architecture placeholder" unless body.include?("架构占位")
      return
    end

    authoring_missing = AUTHORING_FIELDS.reject { |field| metadata.key?(field) }
    errors << "#{relative}: #{status} chapter missing authoring metadata #{authoring_missing.join(", ")}" unless authoring_missing.empty?
    return unless %w[review verified].include?(status)

    review_missing = REVIEW_FIELDS.reject { |field| metadata.key?(field) }
    errors << "#{relative}: #{status} chapter missing review metadata #{review_missing.join(", ")}" unless review_missing.empty?
    validate_review_metadata(relative, metadata, chapter, registry_ids, registry_by_id, verified: status == "verified")
    validate_review_body(relative, body, status)
  rescue Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError => e
    errors << "#{relative}: invalid front matter YAML: #{e.message.lines.first.to_s.strip}"
  end

  def validate_review_metadata(relative, metadata, chapter, registry_ids, registry_by_id, verified:)
    validate_date(metadata["last_reviewed"], "#{relative}: last_reviewed")
    author = metadata["author"]
    validate_identity(author, "#{relative}: author")
    artifact_root = Regexp.escape(chapter.fetch("id"))
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
        patterns: [%r{\Arecords/encyclopedia/evidence/[a-zA-Z0-9._/-]+\z}],
        require_nonblank: true
      )) if entry["evidence"].is_a?(String)
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
        %r{\Arecords/encyclopedia/evidence/[a-zA-Z0-9._/-]+\z}
      ])
      validate_publication_coverage(relative, record, verified: verified) if gate == "publication_navigation"
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

      errors.concat(@path_policy.validate_artifact(path, label: "#{relative}: #{field} ##{index + 1}", patterns: patterns))
    end
  end

  def validate_evidence_list(relative, field, values, patterns)
    return unless values.is_a?(Array)

    values.each_with_index do |path, index|
      next unless path.is_a?(String)

      errors.concat(@path_policy.validate_regular_file(
        path,
        label: "#{relative}: #{field} ##{index + 1}",
        patterns: patterns,
        require_nonblank: true
      ))
    end
  end

  def validate_publication_coverage(relative, record, verified:)
    coverage = record["coverage"]
    return unless coverage.is_a?(Hash)

    %w[links keyboard_semantics rendering].each do |name|
      check = coverage[name]
      next unless check.is_a?(Hash)

      validate_evidence_list(relative, "publication_navigation #{name} evidence", check["evidence"], [
        %r{\Arecords/encyclopedia/evidence/[a-zA-Z0-9._/-]+\z}
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
    puts "referenced_version_surfaces=#{stats.fetch(:referenced_surfaces, 0)}"
    puts "supplemental_registry_entries=#{stats.fetch(:unreferenced_registry_entries, 0)}"
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
