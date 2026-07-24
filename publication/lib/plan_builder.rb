# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "rbconfig"
require "set"

require_relative "contract"

module Publication
  class PlanBuilder
    CATALOG_PATH = "curriculum/catalog.yml"
    P2_MANIFEST_PATH = "site/generated/publication-manifest.json"
    P2_FILE_SET = %w[
      README.md
      catalog.json
      navigation.json
      publication-manifest.json
      search-index.json
    ].freeze
    PROFILE_PATTERN = %r{\Apublication/profiles/[a-z0-9]+(?:-[a-z0-9]+)*\.yml\z}.freeze
    PUBLIC_ROOT_KINDS = %w[examples labs exercises].freeze
    GENERATED_COMPONENTS = %w[build target dist out work coverage].freeze
    IMPLEMENTATION_INPUTS = %w[
      publication/lib/atomic_tree_writer.rb
      publication/lib/contract.rb
      publication/lib/deterministic_weasyprint.py
      publication/lib/plan_builder.rb
      publication/lib/renderer.rb
      publication/styles/p3-gold-epub.css
      publication/styles/p3-gold-print.css
      publication/styles/p3-gold-screen.css
      publication/templates/p3-gold.html5
      scripts/build-publication-plan.rb
      scripts/build-publication.rb
      scripts/lib/chapter_prerequisite_block.rb
      scripts/validate-encyclopedia.rb
    ].freeze
    STAGE_ORDER = { "R1-A" => 0, "R1-B" => 1, "R2" => 2, "R3" => 3 }.freeze
    TOOL_POLICIES = {
      "ace" => { "state" => "deferred", "required_from" => "R3", "command" => %w[ace --version] },
      "axe-core" => { "state" => "deferred", "required_from" => "R3", "command" => %w[axe --version] },
      "bash" => { "state" => "observed-current", "required_from" => "R1-B", "command" => %w[bash --version] },
      "epubcheck" => { "state" => "deferred", "required_from" => "R3", "command" => %w[epubcheck --version] },
      "java" => { "state" => "observed-current", "required_from" => "R1-B", "command" => %w[java -version] },
      "javac" => { "state" => "observed-current", "required_from" => "R1-B", "command" => %w[javac -version] },
      "maven" => { "state" => "observed-current", "required_from" => "R1-B", "command" => %w[mvn -v] },
      "pandoc" => { "state" => "observed-current", "required_from" => "R2", "command" => %w[pandoc --version] },
      "poppler" => { "state" => "deferred", "required_from" => "R3", "command" => %w[pdfinfo -v] },
      "python" => { "state" => "observed-current", "required_from" => "R2", "command" => %w[dpy --version] },
      "ruby" => { "state" => "observed-current", "required_from" => "R1-A", "command" => %w[ruby -v] },
      "verapdf" => { "state" => "deferred", "required_from" => "R3", "command" => %w[verapdf --version] },
      "weasyprint" => { "state" => "observed-current", "required_from" => "R2", "command" => %w[weasyprint --version] }
    }.freeze

    attr_reader :root, :profile_path, :loader, :guard, :tool_observer

    def initialize(root, profile_path:, p2_checker: nil, tool_observer: nil)
      @root = File.realpath(root)
      @profile_path = profile_path
      @loader = ContractLoader.new(@root)
      @guard = loader.guard
      @p2_checker = p2_checker || method(:default_p2_check)
      @tool_observer = tool_observer || method(:default_tool_observer)
      @input_snapshots = {}
    end

    def build
      @input_snapshots = {}
      validate_p2_baseline!
      loader.validate_schema_set!
      profile, profile_bytes = load_profile
      snapshot!(profile_path, profile_bytes)
      catalog, catalog_bytes = load_catalog
      toolchain, toolchain_bytes = loader.load_yaml_with_bytes(profile.fetch("toolchain_lock"), TOOLCHAIN_SCHEMA)
      snapshot!(profile.fetch("toolchain_lock"), toolchain_bytes)
      validate_toolchain!(toolchain)
      selected = select_chapters!(profile, catalog)

      publisher_entries = base_publisher_entries(profile, toolchain)
      content_entries = []
      chapter_records = selected.map do |chapter|
        build_chapter_record(chapter, profile, publisher_entries, content_entries)
      end
      content_entries = unique_entries(content_entries)
      publisher_entries = unique_entries(publisher_entries)
      all_entries = unique_entries(content_entries + publisher_entries)

      projection = selected.map do |chapter|
        chapter.slice("id", "title", "volume", "order", "status", "path")
      end
      p2_manifest_bytes = snapshot_bytes(P2_MANIFEST_PATH)
      p2_manifest = StrictJson.parse(p2_manifest_bytes)
      plan = {
        "schema_version" => 1,
        "plan_id" => "publication-plan.#{profile.fetch('profile_id')}",
        "profile_id" => profile.fetch("profile_id"),
        "site_id" => "factorycare-encyclopedia",
        "edition" => profile.fetch("edition"),
        "publication_mode" => profile.fetch("publication_mode"),
        "visibility" => profile.fetch("visibility"),
        "distribution_allowed" => profile.fetch("distribution_allowed"),
        "language" => profile.fetch("language"),
        "deterministic" => true,
        "generated_by" => "scripts/build-publication-plan.rb",
        "output_root" => "build/publication/#{profile.fetch('profile_id')}",
        "source_date_epoch" => profile.fetch("source_date_epoch"),
        "resource_policy" => profile.fetch("resource_policy"),
        "notice" => profile.fetch("notice"),
        "digest_algorithm" => DIGEST_ALGORITHM,
        "profile" => path_digest(profile_path),
        "catalog" => {
          "path" => CATALOG_PATH,
          "source_sha256" => Canonical.sha256(catalog_bytes),
          "selected_projection_sha256" => Canonical.sha256(Canonical.json(projection))
        },
        "p2_baseline" => {
          "manifest_path" => P2_MANIFEST_PATH,
          "manifest_sha256" => Canonical.sha256(p2_manifest_bytes),
          "input_digest" => fetch_sha256(p2_manifest, "input_digest", P2_MANIFEST_PATH),
          "file_count" => P2_FILE_SET.length
        },
        "toolchain_lock" => path_digest(profile.fetch("toolchain_lock")),
        "tool_requirements" => canonical_tool_requirements(toolchain),
        "chapters" => chapter_records,
        "inputs" => all_entries,
        "input_count" => all_entries.length,
        "content_input_digest" => entries_digest(content_entries),
        "publisher_input_digest" => entries_digest(publisher_entries),
        "build_input_digest" => entries_digest(all_entries),
        "planned_outputs" => planned_outputs(profile, selected),
        "security" => {
          "private_path_count" => 0,
          "private_canary_count" => 0,
          "absolute_repository_path_count" => 0,
          "symlink_input_count" => 0
        }
      }
      validate_input_snapshots!(all_entries)
      validate_plan!(plan)
      plan
    rescue JSON::ParserError, StrictJson::DuplicateMemberError => e
      raise ContractError.new("schema", "E_JSON_PARSE", e.message.lines.first.to_s.strip, path: P2_MANIFEST_PATH)
    end

    def render(plan = build)
      Canonical.json(plan)
    end

    private

    def validate_p2_baseline!
      unless @p2_checker.call
        raise ContractError.new("catalog-validation", "E_P2_BASELINE", "P2 canonical validation or byte check failed")
      end

      validate_p2_file_set!
      true
    rescue ContractError
      raise
    rescue StandardError => e
      raise ContractError.new("catalog-validation", "E_P2_BASELINE", "P2 baseline check failed (#{e.class})")
    end

    def validate_p2_file_set!
      relative_root = "site/generated"
      absolute_root = File.join(root, relative_root)
      stat = File.lstat(absolute_root)
      if stat.symlink?
        raise ContractError.new("catalog-validation", "E_P2_OUTPUT_SYMLINK", "P2 output root cannot be a symbolic link", path: relative_root)
      end
      unless stat.directory?
        raise ContractError.new("catalog-validation", "E_P2_OUTPUT_ROOT", "P2 output root must be a directory", path: relative_root)
      end

      actual = Dir.children(absolute_root).sort
      extra = actual - P2_FILE_SET
      missing = P2_FILE_SET - actual
      unless extra.empty?
        raise ContractError.new("catalog-validation", "E_P2_OUTPUT_EXTRA", "P2 output contains an unexpected entry", path: "#{relative_root}/#{extra.first}")
      end
      unless missing.empty?
        raise ContractError.new("catalog-validation", "E_P2_OUTPUT_MISSING", "P2 output is missing a canonical file", path: "#{relative_root}/#{missing.first}")
      end

      P2_FILE_SET.each { |name| read_exact("#{relative_root}/#{name}") }
    rescue Errno::ENOENT
      raise ContractError.new("catalog-validation", "E_P2_OUTPUT_MISSING", "P2 output root is missing", path: relative_root)
    end

    def default_p2_check
      command = [RbConfig.ruby, File.join(root, "scripts", "build-book.rb"), "--check"]
      _stdout, _stderr, status = Open3.capture3(*command, chdir: root)
      status.success?
    end

    def load_profile
      guard.validate_shape!(profile_path, "publication profile")
      unless PROFILE_PATTERN.match?(profile_path)
        raise ContractError.new("schema", "E_PROFILE_PATH", "profile must live below publication/profiles", path: profile_path)
      end
      profile, bytes = loader.load_yaml_with_bytes(profile_path, PROFILE_SCHEMA)
      expected_path = "publication/profiles/#{profile.fetch('profile_id')}.yml"
      unless profile_path == expected_path
        raise ContractError.new("selection", "E_PROFILE_FILENAME", "profile filename must match profile_id", path: profile_path)
      end
      [profile, bytes]
    end

    def load_catalog
      bytes, = read_exact(CATALOG_PATH)
      snapshot!(CATALOG_PATH, bytes)
      catalog = StrictYaml.safe_load(bytes.force_encoding(Encoding::UTF_8), label: CATALOG_PATH)
      unless catalog.is_a?(Hash) && catalog["chapters"].is_a?(Array)
        raise ContractError.new("catalog-validation", "E_CATALOG_SHAPE", "catalog must contain a chapter array", path: CATALOG_PATH)
      end
      [catalog, bytes]
    rescue Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError => e
      raise ContractError.new("catalog-validation", "E_CATALOG_PARSE", e.message.lines.first.to_s.strip, path: CATALOG_PATH)
    end

    def validate_toolchain!(toolchain)
      tools = toolchain.fetch("tools")
      duplicate = duplicate_value(tools.map { |tool| tool.fetch("id") })
      raise ContractError.new("schema", "E_TOOL_DUPLICATE", "tool ids must be unique") if duplicate
      unless tools.map { |tool| tool.fetch("id") }.sort == TOOL_POLICIES.keys.sort
        raise ContractError.new("schema", "E_TOOL_SET", "toolchain must contain the exact publication tool set")
      end

      tools.each do |tool|
        policy = TOOL_POLICIES.fetch(tool.fetch("id"))
        %w[state required_from command].each do |field|
          next if tool.fetch(field) == policy.fetch(field)

          raise ContractError.new("schema", "E_TOOL_POLICY", "tool #{field} differs from the executable allowlist")
        end
        observed = tool.fetch("state") == "observed-current"
        has_prefix = tool.key?("expected_version_prefix")
        if observed != has_prefix
          raise ContractError.new("schema", "E_TOOL_VERSION_POLICY", "observed tools require a version prefix and deferred tools forbid one")
        end
        next unless observed && STAGE_ORDER.fetch(tool.fetch("required_from")) <= STAGE_ORDER.fetch("R1-A")

        output, success = tool_observer.call(tool.fetch("command"))
        unless success && output.start_with?(tool.fetch("expected_version_prefix"))
          raise ContractError.new("runner-preflight", "E_TOOL_VERSION", "required R1-A tool version does not match its lock")
        end
      end
    end

    def default_tool_observer(command)
      stdout, stderr, status = Open3.capture3(*command, chdir: root)
      [[stdout, stderr].reject(&:empty?).join("\n"), status.success?]
    end

    def select_chapters!(profile, catalog)
      raise ContractError.new("selection", "E_EDITION_MISMATCH", "profile edition must match catalog edition") unless profile.fetch("edition") == catalog["edition"]

      by_id = catalog.fetch("chapters").each_with_object({}) do |chapter, memo|
        id = chapter["id"]
        raise ContractError.new("catalog-validation", "E_CATALOG_CHAPTER", "catalog chapter is missing an id") unless id.is_a?(String)
        raise ContractError.new("catalog-validation", "E_CATALOG_DUPLICATE", "catalog chapter ids must be unique") if memo.key?(id)
        memo[id] = chapter
      end
      ids = profile.fetch("chapter_ids")
      selected = ids.map do |id|
        by_id.fetch(id) do
          raise ContractError.new("selection", "E_CHAPTER_UNKNOWN", "profile selects an unknown chapter", path: id)
        end
      end
      canonical = selected.sort_by { |chapter| [chapter.fetch("volume"), chapter.fetch("order"), chapter.fetch("id")] }
      unless selected == canonical
        raise ContractError.new("selection", "E_CHAPTER_ORDER", "chapter_ids must follow canonical catalog order")
      end
      if selected.any? { |chapter| chapter.fetch("status") == "planned" }
        raise ContractError.new("selection", "E_STATUS_PLANNED", "planned chapters can never enter a publication plan")
      end

      unless profile.fetch("publication_mode") == "internal-preview"
        raise ContractError.new("selection", "E_MODE_UNAVAILABLE", "publication schema v1 supports only the P3 internal preview")
      end
      unless profile.fetch("profile_id") == "p3-gold" && ids == P3_GOLD_IDS
        raise ContractError.new("selection", "E_P3_ALLOWLIST", "internal-preview is restricted to the exact P3 gold allowlist")
      end
      invalid = selected.reject { |chapter| %w[drafting review].include?(chapter.fetch("status")) }
      raise ContractError.new("selection", "E_STATUS_INTERNAL", "internal preview accepts only drafting or review chapters") unless invalid.empty?
      drafting = selected.select { |chapter| chapter.fetch("status") == "drafting" }.map { |chapter| chapter.fetch("id") }
      unless profile.fetch("drafting_allowlist") == drafting
        raise ContractError.new("selection", "E_DRAFTING_ALLOWLIST", "drafting_allowlist must exactly match selected drafting chapters")
      end
      selected
    end

    def build_chapter_record(chapter, profile, publisher_entries, content_entries)
      id = chapter.fetch("id")
      source_path = chapter.fetch("path")
      source_bytes, = guard.read(
        source_path,
        label: "chapter source",
        patterns: [%r{\Abook/volume-#{Regexp.escape(chapter.fetch('volume'))}-[a-z0-9-]+/chapters/#{Regexp.escape(id)}\.md\z}]
      )
      reject_canary!(source_bytes, source_path)
      content_entries << entry(source_path, "content", "chapter-source", source_bytes)

      manifest_path = "publication/manifests/public-artifacts/#{id}.yml"
      manifest, manifest_bytes = loader.load_yaml_with_bytes(manifest_path, ARTIFACT_SCHEMA)
      snapshot!(manifest_path, manifest_bytes)
      validate_manifest_identity!(manifest, manifest_path, chapter, profile)
      publisher_entries << entry(manifest_path, "publisher-contract", "public-artifact-manifest", manifest_bytes)

      artifacts = validate_manifest_inventory!(manifest, chapter, publisher_entries, content_entries)
      {
        "id" => id,
        "title" => chapter.fetch("title"),
        "volume" => chapter.fetch("volume"),
        "order" => chapter.fetch("order"),
        "status" => chapter.fetch("status"),
        "source_path" => source_path,
        "source_sha256" => Canonical.sha256(source_bytes),
        "public_artifact_manifest" => {
          "path" => manifest_path,
          "sha256" => Canonical.sha256(manifest_bytes)
        },
        "artifacts" => artifacts
      }
    end

    def validate_manifest_identity!(manifest, manifest_path, chapter, profile)
      id = chapter.fetch("id")
      checks = {
        "manifest_id" => "public-artifacts.#{id}",
        "chapter_id" => id,
        "chapter_path" => chapter.fetch("path"),
        "edition" => profile.fetch("edition")
      }
      checks.each do |field, expected|
        next if manifest[field] == expected

        raise ContractError.new("inventory", "E_MANIFEST_IDENTITY", "#{field} does not match the selected chapter", path: manifest_path)
      end
      expected_roots = PUBLIC_ROOT_KINDS.map { |kind| "#{kind}/encyclopedia/#{id}" }
      unless manifest.fetch("managed_roots") == expected_roots
        raise ContractError.new("inventory", "E_MANAGED_ROOTS", "managed roots must be the canonical example/lab/exercise roots", path: manifest_path)
      end
    end

    def validate_manifest_inventory!(manifest, chapter, publisher_entries, content_entries)
      id = chapter.fetch("id")
      roots = manifest.fetch("managed_roots")
      artifacts = manifest.fetch("artifacts")
      artifact_ids = artifacts.map { |artifact| artifact.fetch("artifact_id") }
      paths = artifacts.map { |artifact| artifact.fetch("source_path") }
      raise ContractError.new("inventory", "E_ARTIFACT_ID_DUPLICATE", "artifact ids must be unique") if duplicate_value(artifact_ids)
      raise ContractError.new("inventory", "E_ARTIFACT_PATH_DUPLICATE", "artifact paths must be unique") if duplicate_value(paths.map(&:downcase))

      records = artifacts.map do |artifact|
        path = artifact.fetch("source_path")
        validate_artifact_semantics!(artifact, id, roots)
        bytes, = guard.read(path, label: "public artifact", patterns: roots.map { |root_path| root_pattern(root_path) })
        reject_canary!(bytes, path)
        content_entries << entry(path, "content", "artifact:#{artifact.fetch('role')}", bytes)
        artifact.merge(
          "sha256" => Canonical.sha256(bytes),
          "size_bytes" => bytes.bytesize
        )
      end.sort_by { |artifact| artifact.fetch("source_path") }

      metadata = manifest.fetch("repository_metadata")
      raise ContractError.new("inventory", "E_METADATA_DUPLICATE", "repository metadata paths must be unique") if duplicate_value(metadata.map(&:downcase))
      metadata.each do |path|
        unless File.basename(path) == ".gitignore" && roots.any? { |root_path| path.start_with?(root_path + "/") }
          raise ContractError.new("inventory", "E_METADATA_PATH", "only explicitly owned .gitignore metadata is allowed", path: path)
        end
        bytes, = guard.read(path, label: "repository metadata", patterns: roots.map { |root_path| root_pattern(root_path) })
        reject_canary!(bytes, path)
        publisher_entries << entry(path, "publisher-contract", "repository-metadata", bytes)
      end

      actual = roots.flat_map do |root_path|
        guard.inventory(root_path, label: "managed public root", pattern: exact_pattern(root_path))
      end.sort
      declared = (paths + metadata).sort
      extra = actual - declared
      missing = declared - actual
      raise ContractError.new("inventory", "E_ARTIFACT_EXTRA", "managed root contains an undeclared file", path: extra.first) unless extra.empty?
      raise ContractError.new("inventory", "E_ARTIFACT_MISSING", "manifest declares a missing file", path: missing.first) unless missing.empty?
      records
    end

    def validate_artifact_semantics!(artifact, chapter_id, roots)
      path = artifact.fetch("source_path")
      guard.validate_shape!(path, "public artifact")
      if path.split("/").any? { |component| component.start_with?(".") }
        raise ContractError.new("inventory", "E_ARTIFACT_HIDDEN", "hidden files cannot be public artifacts", path: path)
      end
      if (path.split("/") & GENERATED_COMPONENTS).any? || path.match?(/\.(?:class|jar|log|tmp)\z/i)
        raise ContractError.new("inventory", "E_ARTIFACT_GENERATED", "generated files cannot be public artifacts", path: path)
      end
      owner_root = roots.find { |root_path| path.start_with?(root_path + "/") }
      raise ContractError.new("inventory", "E_PATH_OWNERSHIP", "artifact is not owned by this chapter", path: path) unless owner_root

      kind = owner_root.split("/").first
      allowed_roles = {
        "examples" => %w[example-source runner-support oracle],
        "labs" => %w[lab-source runner-support oracle],
        "exercises" => %w[exercise-source runner-support oracle]
      }.fetch(kind)
      unless allowed_roles.include?(artifact.fetch("role"))
        raise ContractError.new("inventory", "E_ARTIFACT_ROLE", "artifact role does not match its owned root", path: path)
      end
      unless artifact.fetch("target_formats") == %w[html epub pdf]
        raise ContractError.new("inventory", "E_FORMAT_ORDER", "artifact target formats must use canonical order", path: path)
      end
      validate_media_type!(artifact, path)
      unless path.include?("/#{chapter_id}/")
        raise ContractError.new("inventory", "E_PATH_OWNERSHIP", "artifact path chapter id does not match manifest owner", path: path)
      end
    end

    def validate_media_type!(artifact, path)
      expected = case path
                 when /\.md\z/ then "text/markdown"
                 when /\.java\z/ then "text/x-java-source"
                 when /\.sh\z/ then "text/x-shellscript"
                 when /\.xml\z/ then "application/xml"
                 when /\.txt\z/ then "text/plain"
                 end
      unless expected && artifact.fetch("media_type") == expected
        raise ContractError.new("inventory", "E_MEDIA_TYPE", "media type does not match the file extension", path: path)
      end
    end

    def base_publisher_entries(profile, toolchain)
      paths = SCHEMA_PATHS + IMPLEMENTATION_INPUTS + [profile_path, profile.fetch("toolchain_lock"), CATALOG_PATH, P2_MANIFEST_PATH]
      paths.uniq.map do |path|
        bytes, = read_exact(path)
        role = if SCHEMA_PATHS.include?(path)
                 "schema"
               elsif path == CATALOG_PATH
                 "canonical-catalog"
               elsif path == P2_MANIFEST_PATH
                 "p2-baseline-manifest"
               elsif path == profile_path
                 "profile"
               elsif path == profile.fetch("toolchain_lock")
                 "toolchain-lock"
               else
                 "publisher-implementation"
               end
        entry(path, "publisher-contract", role, bytes)
      end
    end

    def canonical_tool_requirements(toolchain)
      toolchain.fetch("tools").sort_by { |tool| tool.fetch("id") }.map do |tool|
        result = tool.slice("id", "state", "required_from", "command", "note")
        result["expected_version_prefix"] = tool.fetch("expected_version_prefix") if tool.key?("expected_version_prefix")
        result
      end
    end

    def planned_outputs(profile, selected)
      profile_id = profile.fetch("profile_id")
      outputs = [
        { "path" => "ast/book.json", "kind" => "canonical-ast", "format" => "internal", "distribution" => "internal" },
        { "path" => "output/html/index.html", "kind" => "html-index", "format" => "html", "distribution" => "internal-review-candidate" },
        { "path" => "output/epub/factorycare-#{profile_id}.epub", "kind" => "epub", "format" => "epub", "distribution" => "internal-review-candidate" },
        { "path" => "intermediate/print/book.html", "kind" => "print-html", "format" => "internal", "distribution" => "internal" },
        { "path" => "output/pdf/factorycare-#{profile_id}.pdf", "kind" => "pdf-candidate", "format" => "pdf", "distribution" => "internal-review-candidate" },
        { "path" => "publication-output-manifest.json", "kind" => "output-manifest", "format" => "internal", "distribution" => "internal" }
      ]
      selected.each do |chapter|
        outputs << {
          "path" => "output/html/chapters/#{chapter.fetch('id')}.html",
          "kind" => "chapter-html",
          "format" => "html",
          "distribution" => "internal-review-candidate"
        }
      end
      outputs.sort_by { |output| output.fetch("path") }
    end

    def validate_plan!(plan)
      loader.validate_value!(plan, PLAN_SCHEMA, "generated publication plan")
      serialized = Canonical.json(plan)
      if PRIVATE_PATH_PREFIXES.any? { |prefix| serialized.include?(prefix) }
        raise ContractError.new("plan-assembly", "E_PRIVATE_PATH", "publication plan contains a private path")
      end
      if PRIVATE_CANARY_PATTERN.match?(serialized)
        raise ContractError.new("plan-assembly", "E_PRIVATE_CANARY", "publication plan contains a private canary")
      end
      if serialized.include?(root)
        raise ContractError.new("plan-assembly", "E_ABSOLUTE_PATH", "publication plan contains the absolute repository root")
      end
      true
    end

    def entry(path, scope, role, bytes)
      snapshot!(path, bytes)
      {
        "path" => path,
        "scope" => scope,
        "role" => role,
        "sha256" => Canonical.sha256(bytes),
        "size_bytes" => bytes.bytesize
      }
    end

    def entries_digest(entries)
      Canonical.path_bytes_digest(entries, lambda { |path| snapshot_bytes(path) })
    end

    def unique_entries(entries)
      grouped = entries.group_by { |entry| entry.fetch("path") }
      duplicate = grouped.find { |_path, values| values.map { |value| [value.fetch("scope"), value.fetch("role")] }.uniq.length > 1 }
      if duplicate
        raise ContractError.new("plan-assembly", "E_INPUT_ROLE_CONFLICT", "one input path has conflicting scopes or roles", path: duplicate.first)
      end
      grouped.values.map(&:first).sort_by { |entry| entry.fetch("path") }
    end

    def path_digest(path)
      bytes = snapshot_bytes(path)
      { "path" => path, "sha256" => Canonical.sha256(bytes) }
    end

    def read_exact(path)
      guard.read(path, label: "publication input", patterns: [/\A#{Regexp.escape(path)}\z/])
    end

    def snapshot!(path, bytes)
      frozen_bytes = bytes.dup.b.freeze
      existing = @input_snapshots[path]
      if existing && existing != frozen_bytes
        raise ContractError.new("plan-assembly", "E_INPUT_CHANGED", "input changed while the publication plan was assembled", path: path)
      end
      @input_snapshots[path] ||= frozen_bytes
    end

    def snapshot_bytes(path)
      @input_snapshots.fetch(path) do
        bytes, = read_exact(path)
        snapshot!(path, bytes)
      end
    end

    def validate_input_snapshots!(entries)
      entries.each do |entry_record|
        path = entry_record.fetch("path")
        expected = snapshot_bytes(path)
        unless entry_record.fetch("sha256") == Canonical.sha256(expected) &&
               entry_record.fetch("size_bytes") == expected.bytesize
          raise ContractError.new("plan-assembly", "E_SNAPSHOT_INVARIANT", "input record differs from its frozen snapshot", path: path)
        end

        current, = read_exact(path)
        next if current.b == expected

        raise ContractError.new("plan-assembly", "E_INPUT_CHANGED", "input changed while the publication plan was assembled", path: path)
      end
      true
    end

    def root_pattern(root_path)
      /\A#{Regexp.escape(root_path)}(?:\/[a-zA-Z0-9._-]+)+\z/
    end

    def exact_pattern(path)
      /\A#{Regexp.escape(path)}\z/
    end

    def reject_canary!(bytes, path)
      return unless PRIVATE_CANARY_PATTERN.match?(bytes)

      raise ContractError.new("inventory", "E_PRIVATE_CANARY", "public input contains a private canary", path: path)
    end

    def fetch_sha256(object, key, path)
      value = object[key]
      return value if value.is_a?(String) && /\A[0-9a-f]{64}\z/.match?(value)

      raise ContractError.new("catalog-validation", "E_P2_MANIFEST", "P2 manifest #{key} is missing or invalid", path: path)
    end

    def duplicate_value(values)
      seen = Set.new
      values.find { |value| !seen.add?(value) }
    end
  end
end
