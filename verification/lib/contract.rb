# frozen_string_literal: true

require "digest"
require "json"
require "pathname"
require "set"

require File.expand_path("../../scripts/validate-encyclopedia", __dir__)

module Verification
  SCHEMA_PATH = "schemas/verification-manifest.schema.json"
  MANIFEST_DIRECTORY = "verification/manifests"
  EVIDENCE_DIRECTORY = "verification/evidence/last-run"
  DIGEST_ALGORITHM = "sha256-path-nul-bytes-nul-v1"
  PRIVATE_PREFIXES = %w[solutions-private/ sources/private/].freeze
  PRIVATE_CANARY = /PRIVATE_SOLUTION_DO_NOT_PUBLISH_[A-Z0-9_-]+/.freeze
  PUBLIC_PATH = %r{\A(?:examples|labs|exercises)/encyclopedia/ch\.[a-z0-9.-]+/[a-zA-Z0-9_][a-zA-Z0-9._-]*(?:/[a-zA-Z0-9_][a-zA-Z0-9._-]*)*\z}.freeze
  CHAPTER_ID = /\Ach\.[a-z0-9]+(?:-[a-z0-9]+)*\.[a-z0-9]+(?:-[a-z0-9]+)*\z/.freeze
  SAFE_ID = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/.freeze
  SHA256 = /\A[0-9a-f]{64}\z/.freeze

  TOOL_VERSION_COMMANDS = {
    "bash" => ["bash", "--version"],
    "curl" => ["curl", "--version"],
    "dart" => ["dart", "--version"],
    "docker" => ["docker", "--version"],
    "flutter" => ["flutter", "--version"],
    "java" => ["java", "-version"],
    "javac" => ["javac", "-version"],
    "javap" => ["javap", "-version"],
    "maven" => ["mvn", "-v"],
    "node" => ["node", "--version"],
    "pnpm" => ["pnpm", "--version"],
    "python" => ["python3", "--version"],
    "ruby" => ["ruby", "--version"],
    "uv" => ["uv", "--version"]
  }.freeze

  class ContractError < StandardError
    attr_reader :phase, :code, :path

    def initialize(phase, code, message, path: nil)
      @phase = phase
      @code = code
      @path = path
      super(message)
    end

    def diagnostic
      location = path ? " #{safe_path(path)}" : ""
      "[#{phase}/#{code}]#{location}: #{message}"
    end

    private

    def safe_path(value)
      string = value.to_s
      return string if string.match?(/\A[a-zA-Z0-9][a-zA-Z0-9._\/-]*\z/) &&
                       string.split("/", -1).none? { |part| part.empty? || part == "." || part == ".." }

      "<redacted-path>"
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

    def path_bytes_digest(entries)
      digest = Digest::SHA256.new
      entries.sort_by { |entry| entry.fetch("path") }.each do |entry|
        digest << entry.fetch("path") << "\0" << entry.fetch("bytes") << "\0"
      end
      digest.hexdigest
    end

    def output_set_digest(outputs)
      digest = Digest::SHA256.new
      outputs.sort_by { |item| item.fetch("path") }.each do |item|
        digest << item.fetch("path") << "\0" << item.fetch("kind") << "\0"
        if item.fetch("kind") == "file"
          digest << item.fetch("normalized_sha256") << "\0" << item.fetch("normalized_size_bytes").to_s << "\0"
        end
      end
      digest.hexdigest
    end
  end

  class PathGuard
    attr_reader :root

    def initialize(root)
      @root = File.realpath(root)
    end

    def read_contract(relative)
      read_regular_file(relative, public_only: false)
    end

    def read_public_input(relative, expected_sha256:, expected_mode:)
      validate_public_path!(relative)
      bytes, stat = read_regular_file(relative, public_only: true)
      actual_sha256 = Canonical.sha256(bytes)
      unless actual_sha256 == expected_sha256
        raise ContractError.new("input", "E_INPUT_DIGEST", "input bytes differ from the manifest", path: relative)
      end
      actual_mode = format("%04o", stat.mode & 0o777)
      unless actual_mode == expected_mode
        raise ContractError.new("input", "E_INPUT_MODE", "input mode differs from the manifest", path: relative)
      end
      if bytes.match?(PRIVATE_CANARY)
        raise ContractError.new("input", "E_PRIVATE_CANARY", "private canary is forbidden in verification inputs", path: relative)
      end
      [bytes, stat]
    end

    def validate_public_path!(relative)
      validate_relative_shape!(relative)
      unless PUBLIC_PATH.match?(relative)
        raise ContractError.new("path", "E_PATH_OWNERSHIP", "path is outside public encyclopedia assets", path: relative)
      end
      if PRIVATE_PREFIXES.any? { |prefix| relative.start_with?(prefix) }
        raise ContractError.new("path", "E_PRIVATE_PATH", "private paths are forbidden", path: relative)
      end
      true
    end

    def validate_relative_shape!(relative)
      unless relative.is_a?(String) && !relative.empty?
        raise ContractError.new("path", "E_PATH_EMPTY", "path must be a non-empty string")
      end
      if Pathname(relative).absolute? || relative.match?(/\A[A-Za-z]:[\\\/]/) || relative.start_with?("\\\\")
        raise ContractError.new("path", "E_PATH_ABSOLUTE", "absolute paths are forbidden", path: relative)
      end
      if relative.include?("\\") || relative.split("/", -1).any? { |part| part.empty? || part == "." || part == ".." }
        raise ContractError.new("path", "E_PATH_SEGMENT", "backslashes, dot segments, and empty segments are forbidden", path: relative)
      end
      true
    end

    private

    def read_regular_file(relative, public_only:)
      validate_relative_shape!(relative)
      validate_components!(relative)
      absolute = File.expand_path(relative, root)
      unless contained?(absolute, root)
        raise ContractError.new("path", "E_PATH_ESCAPE", "path escapes the repository", path: relative)
      end
      stat = File.lstat(absolute)
      raise ContractError.new("path", "E_PATH_SYMLINK", "symbolic links are forbidden", path: relative) if stat.symlink?
      raise ContractError.new("path", "E_PATH_NOT_FILE", "expected a regular file", path: relative) unless stat.file?

      flags = File::RDONLY
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      bytes = File.open(absolute, flags) do |file|
        opened = file.stat
        unless opened.file? && opened.dev == stat.dev && opened.ino == stat.ino
          raise ContractError.new("input", "E_INPUT_CHANGED", "file changed while it was opened", path: relative)
        end
        file.binmode
        file.read
      end
      if public_only && PRIVATE_PREFIXES.any? { |prefix| relative.start_with?(prefix) }
        raise ContractError.new("path", "E_PRIVATE_PATH", "private paths are forbidden", path: relative)
      end
      [bytes, stat]
    rescue Errno::ENOENT
      raise ContractError.new("path", "E_PATH_MISSING", "required file is missing", path: relative)
    rescue Errno::ELOOP
      raise ContractError.new("path", "E_PATH_SYMLINK", "symbolic-link path is forbidden", path: relative)
    end

    def validate_components!(relative)
      cursor = root
      relative.split("/").each do |component|
        cursor = File.join(cursor, component)
        break unless File.exist?(cursor) || File.symlink?(cursor)

        if File.lstat(cursor).symlink?
          raise ContractError.new("path", "E_PATH_SYMLINK", "symbolic-link path components are forbidden", path: relative)
        end
      end
    end

    def contained?(candidate, base)
      candidate == base || candidate.start_with?(base + File::SEPARATOR)
    end
  end

  Manifest = Struct.new(:path, :bytes, :data, :inputs_by_path, keyword_init: true)

  class ManifestLoader
    attr_reader :root, :guard

    def initialize(root)
      @root = File.realpath(root)
      @guard = PathGuard.new(@root)
      @schema = load_schema
    end

    def discover
      absolute = File.join(root, MANIFEST_DIRECTORY)
      unless File.directory?(absolute) && !File.symlink?(absolute)
        raise ContractError.new("inventory", "E_MANIFEST_DIRECTORY", "manifest directory is missing or unsafe")
      end
      paths = Dir.children(absolute).sort.map { |name| File.join(MANIFEST_DIRECTORY, name) }
      unless paths.all? { |path| path.end_with?(".yml") }
        raise ContractError.new("inventory", "E_MANIFEST_EXTRA", "manifest directory may contain only .yml files")
      end
      raise ContractError.new("inventory", "E_MANIFEST_EMPTY", "no verification manifests were found") if paths.empty?

      manifests = paths.map { |path| load(path) }
      ids = manifests.map { |manifest| manifest.data.fetch("chapter_id") }
      duplicate = duplicate_value(ids)
      raise ContractError.new("semantic", "E_CHAPTER_DUPLICATE", "chapter manifest is duplicated", path: duplicate) if duplicate
      manifests
    end

    def load(relative)
      bytes, = guard.read_contract(relative)
      if bytes.match?(PRIVATE_CANARY) || bytes.include?("solutions-private/") || bytes.include?("sources/private/")
        raise ContractError.new("security", "E_PRIVATE_REFERENCE", "private references are forbidden", path: relative)
      end
      data = StrictYaml.safe_load(bytes.force_encoding(Encoding::UTF_8), label: relative)
      unless data.is_a?(Hash)
        raise ContractError.new("schema", "E_MANIFEST_ROOT", "manifest root must be a mapping", path: relative)
      end
      validate_document(data, relative)

      inputs = data.fetch("inputs").each_with_object({}) do |input, memo|
        bytes_for_input, stat = guard.read_public_input(
          input.fetch("path"),
          expected_sha256: input.fetch("sha256"),
          expected_mode: input.fetch("mode")
        )
        memo[input.fetch("path")] = input.merge("bytes" => bytes_for_input, "stat" => stat)
      end
      actual_digest = Canonical.path_bytes_digest(inputs.values)
      unless actual_digest == data.fetch("input_set_sha256")
        raise ContractError.new("input", "E_INPUT_SET_DIGEST", "input-set digest differs from the manifest", path: relative)
      end
      Manifest.new(path: relative, bytes: bytes, data: data, inputs_by_path: inputs)
    rescue Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError => e
      raise ContractError.new("schema", "E_MANIFEST_YAML", e.message.lines.first.to_s.strip, path: relative)
    end

    def validate_document(data, relative)
      schema_errors = @schema.validate(data)
      unless schema_errors.empty?
        raise ContractError.new("schema", "E_MANIFEST_SCHEMA", schema_errors.first, path: relative)
      end
      reject_forbidden_strings!(data, relative)
      validate_semantics!(data, relative)
      true
    end

    private

    def load_schema
      bytes, = guard.read_contract(SCHEMA_PATH)
      document = StrictJson.parse(bytes)
      evaluator = ExecutableJsonSchema.new(document, SCHEMA_PATH)
      unless evaluator.definition_errors.empty?
        raise ContractError.new("schema", "E_SCHEMA_DEFINITION", evaluator.definition_errors.first, path: SCHEMA_PATH)
      end
      evaluator
    rescue JSON::ParserError, StrictJson::DuplicateMemberError => e
      raise ContractError.new("schema", "E_SCHEMA_JSON", e.message, path: SCHEMA_PATH)
    end

    def validate_semantics!(data, relative)
      chapter_id = data.fetch("chapter_id")
      expected_path = File.join(MANIFEST_DIRECTORY, "#{chapter_id}.yml")
      unless relative == expected_path && data.fetch("manifest_id") == "verification.#{chapter_id}"
        raise ContractError.new("semantic", "E_MANIFEST_IDENTITY", "manifest path and identity must match the chapter", path: relative)
      end

      inputs = data.fetch("inputs")
      input_paths = inputs.map { |input| input.fetch("path") }
      validate_sorted_unique_paths!(input_paths, "E_INPUT_ORDER", relative)
      unless data.fetch("input_count") == inputs.length
        raise ContractError.new("semantic", "E_INPUT_COUNT", "input_count does not match inputs", path: relative)
      end

      tools = data.fetch("tools")
      tool_ids = tools.map { |tool| tool.fetch("id") }
      unless tool_ids == tool_ids.sort && tool_ids.uniq.length == tool_ids.length
        raise ContractError.new("semantic", "E_TOOL_ORDER", "tools must be unique and sorted by id", path: relative)
      end
      tools.each do |tool|
        unless TOOL_VERSION_COMMANDS.fetch(tool.fetch("id")) == tool.fetch("version_argv")
          raise ContractError.new("semantic", "E_TOOL_COMMAND", "tool version command is not the fixed allowlist command", path: relative)
        end
      end

      recipes = data.fetch("recipes")
      recipe_ids = recipes.map { |recipe| recipe.fetch("id") }
      unless recipe_ids == recipe_ids.sort && recipe_ids.uniq.length == recipe_ids.length
        raise ContractError.new("semantic", "E_RECIPE_ORDER", "recipes must be unique and sorted by id", path: relative)
      end
      used_inputs = Set.new
      used_tools = Set.new
      recipes.each do |recipe|
        validate_recipe!(recipe, chapter_id, input_paths, tool_ids, relative)
        used_inputs.merge(recipe.fetch("input_paths"))
        used_tools.merge(recipe.fetch("tool_ids"))
      end
      unless used_inputs == input_paths.to_set
        raise ContractError.new("semantic", "E_INPUT_UNUSED", "every declared input must belong to at least one recipe", path: relative)
      end
      unless used_tools == tool_ids.to_set
        raise ContractError.new("semantic", "E_TOOL_UNUSED", "every declared tool must belong to at least one recipe", path: relative)
      end
    end

    def validate_recipe!(recipe, chapter_id, input_paths, tool_ids, relative)
      role = recipe.fetch("role")
      expected_root = "#{role == 'exercise' ? 'exercises' : role + 's'}/encyclopedia/#{chapter_id}"
      workdir = recipe.fetch("workdir")
      unless workdir == expected_root
        raise ContractError.new("semantic", "E_RECIPE_OWNER", "recipe workdir must be its chapter-owned public root", path: relative)
      end

      recipe_inputs = recipe.fetch("input_paths")
      validate_sorted_unique_paths!(recipe_inputs, "E_RECIPE_INPUT_ORDER", relative)
      unless recipe_inputs.all? { |path| input_paths.include?(path) }
        raise ContractError.new("semantic", "E_RECIPE_INPUT_REFERENCE", "recipe references an undeclared input", path: relative)
      end

      argv = recipe.fetch("argv")
      unless argv.first == "bash" && safe_script_argument?(argv.last)
        raise ContractError.new("semantic", "E_RECIPE_ARGV", "recipes must use bash with one safe relative script path", path: relative)
      end
      script_input = File.join(workdir, argv.last)
      unless recipe_inputs.include?(script_input)
        raise ContractError.new("semantic", "E_RECIPE_SCRIPT_INPUT", "recipe script must be a declared recipe input", path: relative)
      end

      recipe_tools = recipe.fetch("tool_ids")
      unless recipe_tools == recipe_tools.sort && recipe_tools.uniq.length == recipe_tools.length &&
             recipe_tools.all? { |id| tool_ids.include?(id) } && recipe_tools.include?("bash")
        raise ContractError.new("semantic", "E_RECIPE_TOOLS", "recipe tools must be sorted declared tools and include bash", path: relative)
      end
      exit_code = recipe.fetch("expected_exit_code")
      unless exit_code.between?(0, 255)
        raise ContractError.new("semantic", "E_EXIT_CODE", "expected exit code must be between 0 and 255", path: relative)
      end
      if role == "exercise" && exit_code != 41
        raise ContractError.new("semantic", "E_EXERCISE_RED", "public drafting exercises must use the stable expected-red exit 41", path: relative)
      end

      outputs = recipe.fetch("declared_outputs")
      output_paths = outputs.map { |output| output.fetch("path") }
      validate_sorted_unique_paths!(output_paths, "E_OUTPUT_ORDER", relative)
      outputs.each do |output|
        unless output.fetch("path").start_with?(workdir + "/")
          raise ContractError.new("semantic", "E_OUTPUT_OWNER", "declared output must remain inside its recipe workdir", path: relative)
        end
        if input_paths.include?(output.fetch("path"))
          raise ContractError.new("semantic", "E_OUTPUT_INPUT_OVERLAP", "an output cannot overwrite a declared input", path: relative)
        end
      end
    end

    def validate_sorted_unique_paths!(paths, code, relative)
      collision = duplicate_value(paths.map(&:downcase))
      unless paths == paths.sort && paths.uniq.length == paths.length && collision.nil?
        raise ContractError.new("semantic", code, "paths must be byte-sorted, unique, and case-fold unique", path: relative)
      end
    end

    def safe_script_argument?(value)
      value.is_a?(String) && value.match?(/\A[a-zA-Z0-9_][a-zA-Z0-9._-]*(?:\/[a-zA-Z0-9_][a-zA-Z0-9._-]*)*\z/) &&
        !value.split("/").any? { |part| part == "." || part == ".." }
    end

    def reject_forbidden_strings!(value, relative)
      strings = case value
                when Hash then value.flat_map { |key, item| [key] + reject_forbidden_strings!(item, relative) }
                when Array then value.flat_map { |item| reject_forbidden_strings!(item, relative) }
                when String then [value]
                else []
                end
      forbidden = strings.find do |string|
        string.start_with?("/") || string.match?(/\A[A-Za-z]:[\\\/]/) || string.start_with?("\\\\") ||
          PRIVATE_PREFIXES.any? { |prefix| string.include?(prefix) } || string.match?(PRIVATE_CANARY)
      end
      if forbidden
        raise ContractError.new("security", "E_FORBIDDEN_STRING", "absolute or private strings are forbidden", path: relative)
      end
      strings
    end

    def duplicate_value(values)
      counts = values.each_with_object(Hash.new(0)) { |value, memo| memo[value] += 1 }
      counts.find { |_value, count| count > 1 }&.first
    end
  end
end
