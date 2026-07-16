# frozen_string_literal: true

require "digest"
require "json"
require "pathname"
require "set"

require File.expand_path("../../scripts/validate-encyclopedia", __dir__)

module Publication
  PROFILE_SCHEMA = "schemas/publication-profile.schema.json"
  ARTIFACT_SCHEMA = "schemas/public-artifact-manifest.schema.json"
  TOOLCHAIN_SCHEMA = "schemas/publication-toolchain.schema.json"
  PLAN_SCHEMA = "schemas/publication-plan.schema.json"
  OUTPUT_SCHEMA = "schemas/publication-output-manifest.schema.json"
  SCHEMA_PATHS = [PROFILE_SCHEMA, ARTIFACT_SCHEMA, TOOLCHAIN_SCHEMA, PLAN_SCHEMA, OUTPUT_SCHEMA].freeze
  P3_GOLD_IDS = %w[
    ch.java.platform-toolchain
    ch.java.program-structure
    ch.java.values-variables-types
    ch.java.expressions-conversions
  ].freeze
  PRIVATE_PATH_PREFIXES = %w[solutions-private/ sources/private/].freeze
  PRIVATE_CANARY_PATTERN = /PRIVATE_SOLUTION_DO_NOT_PUBLISH_[A-Z0-9_-]+/.freeze
  DIGEST_ALGORITHM = "sha256-path-nul-bytes-nul-v1"

  class ContractError < StandardError
    attr_reader :phase, :code, :path

    def initialize(phase, code, message, path: nil)
      @phase = phase
      @code = code
      @path = path
      super(message)
    end

    def diagnostic
      location = path ? " #{safe_diagnostic_path}" : ""
      "[#{phase}/#{code}]#{location}: #{message}"
    end

    private

    def safe_diagnostic_path
      value = path.to_s
      segments = value.split("/", -1)
      safe = /\A[a-zA-Z0-9][a-zA-Z0-9._\/-]*\z/.match?(value) &&
             segments.none? { |segment| segment.empty? || segment == "." || segment == ".." }
      safe ? value : "<redacted-path>"
    end
  end

  module Canonical
    module_function

    def object(value)
      case value
      when Hash
        value.keys.sort.each_with_object({}) { |key, memo| memo[key] = object(value.fetch(key)) }
      when Array
        value.map { |item| object(item) }
      else
        value
      end
    end

    def json(value)
      JSON.pretty_generate(object(value)) + "\n"
    end

    def sha256(bytes)
      Digest::SHA256.hexdigest(bytes)
    end

    def path_bytes_digest(entries, reader)
      digest = Digest::SHA256.new
      entries.sort_by { |entry| entry.fetch("path") }.each do |entry|
        path = entry.fetch("path")
        digest << path << "\0" << reader.call(path) << "\0"
      end
      digest.hexdigest
    end
  end

  # Publication inputs use a stricter ASCII repository-path grammar than the
  # general validator. This makes the same manifest safe on case-insensitive
  # hosts and rejects Windows paths even when the builder runs on POSIX.
  class PathGuard
    REPOSITORY_PATH = /\A[a-zA-Z0-9][a-zA-Z0-9._\/-]*\z/.freeze

    attr_reader :root

    def initialize(root)
      @root = File.realpath(root)
    end

    def read(relative, label:, patterns:, require_nonblank: true)
      validate_shape!(relative, label)
      unless patterns.any? { |pattern| pattern.match?(relative) }
        raise ContractError.new("inventory", "E_PATH_OWNERSHIP", "path is outside its allowed owner", path: relative)
      end
      absolute = File.expand_path(relative, root)
      validate_components!(relative, label)
      stat = File.lstat(absolute)
      raise ContractError.new("inventory", "E_PATH_SYMLINK", "symbolic links are forbidden", path: relative) if stat.symlink?
      raise ContractError.new("inventory", "E_PATH_NOT_FILE", "expected a regular file", path: relative) unless stat.file?
      real = File.realpath(absolute)
      unless contained?(real, root)
        raise ContractError.new("inventory", "E_PATH_ESCAPE", "resolved path escapes the repository", path: relative)
      end

      flags = File::RDONLY
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      bytes = File.open(absolute, flags) do |io|
        descriptor_stat = io.stat
        unless descriptor_stat.file? && descriptor_stat.dev == stat.dev && descriptor_stat.ino == stat.ino
          raise ContractError.new("inventory", "E_PATH_CHANGED", "file changed while it was being opened", path: relative)
        end
        io.binmode
        io.read
      end
      if require_nonblank && blank?(bytes)
        raise ContractError.new("inventory", "E_FILE_BLANK", "file must contain non-whitespace content", path: relative)
      end
      [bytes, stat]
    rescue Errno::ENOENT
      raise ContractError.new("inventory", "E_PATH_MISSING", "required file is missing", path: relative)
    rescue Errno::ELOOP
      raise ContractError.new("inventory", "E_PATH_SYMLINK", "cannot follow symbolic-link path", path: relative)
    end

    def inventory(relative, label:, pattern:)
      validate_shape!(relative, label)
      unless pattern.match?(relative)
        raise ContractError.new("inventory", "E_ROOT_OWNERSHIP", "managed root has the wrong chapter owner", path: relative)
      end
      validate_components!(relative, label)
      absolute = File.expand_path(relative, root)
      stat = File.lstat(absolute)
      raise ContractError.new("inventory", "E_PATH_SYMLINK", "managed root cannot be a symbolic link", path: relative) if stat.symlink?
      raise ContractError.new("inventory", "E_ROOT_NOT_DIRECTORY", "managed root must be a directory", path: relative) unless stat.directory?

      paths = Dir.glob(File.join(absolute, "**", "*"), File::FNM_DOTMATCH).sort.each_with_object([]) do |entry, memo|
        rel = entry.delete_prefix(root + File::SEPARATOR)
        next if rel.split("/").any? { |segment| segment == "." || segment == ".." }

        entry_stat = File.lstat(entry)
        next if entry_stat.directory? && !entry_stat.symlink?
        unless entry_stat.file? || entry_stat.symlink?
          raise ContractError.new("inventory", "E_PATH_NOT_FILE", "managed roots may contain only regular files", path: rel)
        end
        memo << rel
      end
      collision = paths.group_by { |path| path.downcase }.values.find { |items| items.length > 1 }
      if collision
        raise ContractError.new("inventory", "E_PATH_CASE_COLLISION", "case-folded paths collide", path: collision.sort.first)
      end
      paths
    rescue Errno::ENOENT
      raise ContractError.new("inventory", "E_ROOT_MISSING", "managed root is missing", path: relative)
    end

    def validate_shape!(relative, label)
      unless relative.is_a?(String) && !relative.empty?
        raise ContractError.new("schema", "E_PATH_EMPTY", "#{label} must be a non-empty relative path")
      end
      if Pathname.new(relative).absolute? || relative.match?(/\A[A-Za-z]:[\\\/]/) || relative.start_with?("\\\\")
        raise ContractError.new("schema", "E_PATH_ABSOLUTE", "absolute paths are forbidden", path: relative)
      end
      if relative.include?("\\") || !REPOSITORY_PATH.match?(relative)
        raise ContractError.new("schema", "E_PATH_GRAMMAR", "path must use the strict ASCII repository grammar", path: relative)
      end
      if relative.split("/", -1).any? { |part| part.empty? || part == "." || part == ".." }
        raise ContractError.new("schema", "E_PATH_SEGMENT", "dot and empty path segments are forbidden", path: relative)
      end
      true
    end

    private

    def validate_components!(relative, _label)
      cursor = root
      relative.split("/").each do |component|
        cursor = File.join(cursor, component)
        break unless File.exist?(cursor) || File.symlink?(cursor)
        if File.lstat(cursor).symlink?
          raise ContractError.new("inventory", "E_PATH_SYMLINK", "symbolic-link path components are forbidden", path: relative)
        end
      end
    end

    def contained?(candidate, base)
      candidate == base || candidate.start_with?(base + File::SEPARATOR)
    end

    def blank?(bytes)
      return true if bytes.empty?

      text = bytes.dup.force_encoding(Encoding::UTF_8)
      return bytes.each_byte.none? { |byte| ![9, 10, 11, 12, 13, 32].include?(byte) } unless text.valid_encoding?

      text.gsub(/[[:space:]]/u, "").empty?
    end
  end

  class ContractLoader
    attr_reader :root, :guard

    def initialize(root)
      @root = File.realpath(root)
      @guard = PathGuard.new(@root)
      @schema_cache = {}
    end

    def load_yaml(relative, schema_relative)
      load_yaml_with_bytes(relative, schema_relative).first
    end

    def load_yaml_with_bytes(relative, schema_relative)
      bytes, = guard.read(relative, label: "YAML contract", patterns: [exact(relative)])
      value = StrictYaml.safe_load(bytes.force_encoding(Encoding::UTF_8), label: relative)
      unless value.is_a?(Hash)
        raise ContractError.new("schema", "E_YAML_ROOT", "contract root must be a mapping", path: relative)
      end
      validate_instance!(value, schema_relative, relative)
      [value, bytes]
    rescue Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError => e
      raise ContractError.new("schema", "E_YAML_PARSE", e.message.lines.first.to_s.strip, path: relative)
    end

    def load_json(relative, schema_relative = nil)
      bytes, = guard.read(relative, label: "JSON contract", patterns: [exact(relative)])
      value = StrictJson.parse(bytes)
      validate_instance!(value, schema_relative, relative) if schema_relative
      value
    rescue JSON::ParserError, StrictJson::DuplicateMemberError => e
      raise ContractError.new("schema", "E_JSON_PARSE", e.message.lines.first.to_s.strip, path: relative)
    end

    def schema(relative)
      @schema_cache[relative] ||= begin
        bytes, = guard.read(relative, label: "JSON Schema", patterns: [exact(relative)])
        document = StrictJson.parse(bytes)
        evaluator = ExecutableJsonSchema.new(document, relative)
        unless evaluator.definition_errors.empty?
          raise ContractError.new("schema", "E_SCHEMA_DEFINITION", evaluator.definition_errors.first, path: relative)
        end
        [document, evaluator]
      rescue JSON::ParserError, StrictJson::DuplicateMemberError => e
        raise ContractError.new("schema", "E_SCHEMA_PARSE", e.message.lines.first.to_s.strip, path: relative)
      end
    end

    def validate_schema_set!
      SCHEMA_PATHS.each { |path| schema(path) }
      true
    end

    def validate_value!(value, schema_relative, instance_path)
      validate_instance!(value, schema_relative, instance_path)
      true
    end

    private

    def validate_instance!(value, schema_relative, instance_path)
      _, evaluator = schema(schema_relative)
      errors = evaluator.validate(value)
      return if errors.empty?

      raise ContractError.new("schema", "E_SCHEMA_INSTANCE", errors.first, path: instance_path)
    end

    def exact(relative)
      /\A#{Regexp.escape(relative)}\z/
    end
  end
end
