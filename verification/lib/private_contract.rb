# frozen_string_literal: true

require "pathname"
require "set"

require_relative "contract"

module Verification
  PRIVATE_CONTRACT_PATH = "verification/private-contract.yml"

  PrivateChapter = Struct.new(
    :chapter_id, :root, :verify_relative, :inputs, :cache_tool_ids,
    keyword_init: true
  )

  # Loads the internal answer contract. It intentionally does not reuse public
  # manifests: private source paths and output text must never enter public D5
  # evidence.
  class PrivateContractLoader
    EXACT_KEYS = %w[
      catalog_path contract_id entrypoint_name entrypoint_policy
      evidence_disclosure expected_chapter_count expected_exit_code
      generated_output_policy ignored_generated_names schema_version source_root
      visibility
    ].sort.freeze
    FIXED_VALUES = {
      "schema_version" => 1,
      "contract_id" => "verification.private-solutions",
      "visibility" => "internal-only",
      "catalog_path" => "curriculum/catalog.yml",
      "source_root" => "solutions-private/encyclopedia",
      "entrypoint_name" => "verify.sh",
      "entrypoint_policy" => "exactly-one-recursive",
      "expected_exit_code" => 0,
      "generated_output_policy" => "opaque-delta-inside-clean-copy",
      "evidence_disclosure" => "hashes-counts-and-public-chapter-ids-only"
    }.freeze
    TOOL_PATTERNS = {
      "dart-pub" => /(?:\A|[^a-zA-Z0-9_.-])dart[[:space:]]+pub(?:[[:space:]]|\z)/,
      "maven" => /(?:\A|[^a-zA-Z0-9_.-])mvn(?:\s|\z)/,
      "pnpm" => /(?:\A|[^a-zA-Z0-9_.-])pnpm(?:\s|\z)/,
      "uv" => /(?:\A|[^a-zA-Z0-9_.-])uv(?:\s|\z)/
    }.freeze

    attr_reader :root, :guard, :contract, :contract_bytes

    def initialize(root, contract_path: PRIVATE_CONTRACT_PATH)
      @root = File.realpath(root)
      @guard = PathGuard.new(@root)
      @contract_path = contract_path
    end

    def discover
      load_contract!
      ids = catalog_ids
      expected = contract.fetch("expected_chapter_count")
      unless expected.is_a?(Integer) && expected.positive? && ids.length == expected
        raise ContractError.new("private-inventory", "E_PRIVATE_CHAPTER_COUNT", "catalog count differs from the private contract")
      end
      validate_source_inventory!(ids)
      ids.sort.map { |chapter_id| load_chapter(chapter_id) }
    end

    private

    def load_contract!
      @contract_bytes, = guard.read_contract(@contract_path)
      @contract = StrictYaml.safe_load(@contract_bytes.force_encoding(Encoding::UTF_8), label: @contract_path)
      unless contract.is_a?(Hash) && contract.keys.sort == EXACT_KEYS
        raise ContractError.new("private-contract", "E_PRIVATE_CONTRACT_SHAPE", "private contract keys differ from the fixed schema")
      end
      FIXED_VALUES.each do |key, value|
        unless contract[key] == value
          raise ContractError.new("private-contract", "E_PRIVATE_CONTRACT_VALUE", "private contract has an unsupported fixed value")
        end
      end
      ignored = contract.fetch("ignored_generated_names")
      unless ignored.is_a?(Array) && ignored == ignored.sort && ignored.uniq.length == ignored.length &&
             ignored.all? { |name| safe_name?(name) }
        raise ContractError.new("private-contract", "E_PRIVATE_IGNORE_POLICY", "ignored generated names must be sorted, unique safe basenames")
      end
      true
    rescue Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError => e
      raise ContractError.new("private-contract", "E_PRIVATE_CONTRACT_YAML", e.message.lines.first.to_s.strip)
    end

    def catalog_ids
      bytes, = guard.read_contract(contract.fetch("catalog_path"))
      data = StrictYaml.safe_load(bytes.force_encoding(Encoding::UTF_8), label: contract.fetch("catalog_path"))
      chapters = data.fetch("chapters")
      ids = chapters.map { |chapter| chapter.fetch("id") }
      unless ids.uniq.length == ids.length && ids.all? { |id| id.is_a?(String) && id.match?(CHAPTER_ID) }
        raise ContractError.new("private-inventory", "E_PRIVATE_CATALOG_IDS", "catalog chapter IDs must be unique and valid")
      end
      ids
    rescue KeyError, Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError
      raise ContractError.new("private-inventory", "E_PRIVATE_CATALOG", "catalog cannot be loaded for private verification")
    end

    def validate_source_inventory!(ids)
      source = absolute_source_root
      entries = Dir.children(source).sort
      unless entries == ids.sort
        raise ContractError.new("private-inventory", "E_PRIVATE_SOURCE_INVENTORY", "private chapter roots differ from the catalog")
      end
      entries.each do |entry|
        stat = File.lstat(File.join(source, entry))
        unless stat.directory? && !stat.symlink?
          raise ContractError.new("private-inventory", "E_PRIVATE_CHAPTER_ROOT", "private chapter root must be a real directory", path: entry)
        end
      end
    rescue Errno::ENOENT
      raise ContractError.new("private-inventory", "E_PRIVATE_SOURCE_ROOT", "private source root is missing")
    end

    def load_chapter(chapter_id)
      chapter_root = File.join(absolute_source_root, chapter_id)
      ignored = contract.fetch("ignored_generated_names").to_set
      files = []
      walk(chapter_root, "", ignored, files)
      verifies = files.select { |entry| File.basename(entry.fetch("relative")) == contract.fetch("entrypoint_name") }
      unless verifies.length == 1
        raise ContractError.new("private-inventory", "E_PRIVATE_VERIFY_COUNT", "chapter must contain exactly one verify entrypoint", path: chapter_id)
      end
      verify = verifies.first
      unless (verify.fetch("mode").to_i(8) & 0o111).positive?
        raise ContractError.new("private-inventory", "E_PRIVATE_VERIFY_MODE", "verify entrypoint must be executable", path: chapter_id)
      end
      PrivateChapter.new(
        chapter_id: chapter_id,
        root: chapter_root,
        verify_relative: verify.fetch("relative"),
        inputs: files.freeze,
        cache_tool_ids: detect_cache_tools(files).freeze
      )
    end

    def walk(directory, relative_directory, ignored, files)
      Dir.children(directory).sort.each do |name|
        absolute = File.join(directory, name)
        relative = relative_directory.empty? ? name : File.join(relative_directory, name)
        stat = File.lstat(absolute)
        if stat.symlink?
          raise ContractError.new("private-inventory", "E_PRIVATE_INPUT_SYMLINK", "private inputs cannot contain symbolic links")
        elsif ignored.include?(name)
          next
        elsif stat.directory?
          walk(absolute, relative, ignored, files)
        elsif stat.file?
          bytes = File.binread(absolute)
          files << {
            "relative" => relative,
            "bytes" => bytes,
            "sha256" => Canonical.sha256(bytes),
            "size_bytes" => bytes.bytesize,
            "mode" => format("%04o", stat.mode & 0o777)
          }
        else
          raise ContractError.new("private-inventory", "E_PRIVATE_INPUT_SPECIAL", "private inputs cannot contain special filesystem entries")
        end
      end
    end

    def detect_cache_tools(files)
      combined = files.map { |entry| entry.fetch("bytes") }.join("\n").force_encoding(Encoding::UTF_8).scrub
      TOOL_PATTERNS.keys.select { |id| combined.match?(TOOL_PATTERNS.fetch(id)) }
    end

    def absolute_source_root
      @absolute_source_root ||= begin
        relative = contract.fetch("source_root")
        guard.validate_relative_shape!(relative)
        absolute = File.expand_path(relative, root)
        unless absolute.start_with?(root + File::SEPARATOR)
          raise ContractError.new("private-inventory", "E_PRIVATE_SOURCE_ESCAPE", "private source root escapes the repository")
        end
        cursor = root
        relative.split("/").each do |component|
          cursor = File.join(cursor, component)
          stat = File.lstat(cursor)
          if stat.symlink?
            raise ContractError.new("private-inventory", "E_PRIVATE_SOURCE_SYMLINK", "private source path contains a symbolic link")
          end
        end
        unless File.directory?(absolute)
          raise ContractError.new("private-inventory", "E_PRIVATE_SOURCE_ROOT", "private source root is not a directory")
        end
        absolute
      end
    rescue Errno::ENOENT
      raise ContractError.new("private-inventory", "E_PRIVATE_SOURCE_ROOT", "private source root is missing")
    end

    def safe_name?(name)
      name.is_a?(String) && name.match?(/\A(?:\.?[a-zA-Z0-9_][a-zA-Z0-9._-]*)\z/) && !%w[. ..].include?(name)
    end
  end
end
