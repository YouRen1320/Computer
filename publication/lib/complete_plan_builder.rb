# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "set"

require_relative "contract"

module Publication
  # Builds the internal, all-catalog publication contract. Unlike the P3
  # sample, companions are represented by tracked path/digest records and are
  # never expanded into the book body.
  class CompletePlanBuilder
    PROFILE_PATH = "publication/profiles/internal-complete.yml"
    PROFILE_SCHEMA = "schemas/publication-profile-v2.schema.json"
    PLAN_SCHEMA = "schemas/publication-plan-v2.schema.json"
    OUTPUT_SCHEMA = "schemas/publication-output-manifest-v2.schema.json"
    CATALOG_PATH = "curriculum/catalog.yml"
    OUTPUT_ROOT = "build/publication/internal-complete"
    PLAN_PATH = "#{OUTPUT_ROOT}/publication-plan-v2.json"
    REQUIRED_TOOLS = %w[pandoc python ruby weasyprint].freeze
    COMPANION_KIND = {
      "examples/encyclopedia" => "example",
      "labs/encyclopedia" => "lab",
      "exercises/encyclopedia" => "exercise"
    }.freeze
    GENERATED_COMPONENTS = %w[
      build target dist out coverage node_modules .gradle .idea .venv
      __pycache__ .dart_tool generated
    ].freeze
    VOLUME_TITLES = {
      "00" => "卷 00：计算机、工具与验证基础",
      "01" => "卷 01：Java 语言基础",
      "02" => "卷 02：Java 对象模型",
      "03" => "卷 03：Java 工程能力",
      "04" => "卷 04：关系数据、SQL 与 PostgreSQL",
      "05" => "卷 05：Spring Web、数据与事务",
      "06" => "卷 06：安全与企业架构",
      "07" => "卷 07：Web 平台、HTML 与 CSS",
      "08" => "卷 08：JavaScript 与 TypeScript",
      "09" => "卷 09：Vue 3 与 Nuxt",
      "10" => "卷 10：小程序与 uni-app",
      "11" => "卷 11：Dart 与 Flutter",
      "12" => "卷 12：Python、FastAPI 与数据工具",
      "13" => "卷 13：数学、机器学习与 PyTorch",
      "14" => "卷 14：LLM、RAG 与 Agent",
      "15" => "卷 15：生产化与 FactoryCare 验收"
    }.freeze
    IMPLEMENTATION_INPUTS = %w[
      schemas/publication-profile-v2.schema.json
      schemas/publication-plan-v2.schema.json
      schemas/publication-output-manifest-v2.schema.json
      schemas/publication-toolchain.schema.json
      publication/lib/contract.rb
      publication/lib/complete_plan_builder.rb
      publication/lib/complete_renderer.rb
      publication/lib/deterministic_weasyprint.py
      publication/templates/internal-complete.html5
      publication/styles/internal-complete-screen.css
      publication/styles/internal-complete-print.css
      publication/styles/internal-complete-epub.css
      scripts/build-complete-publication-plan.rb
      scripts/build-complete-publication.rb
      scripts/lib/chapter_prerequisite_block.rb
      scripts/lib/factorycare_status_contract.rb
      scripts/validate-encyclopedia.rb
    ].freeze

    attr_reader :root, :loader, :guard, :profile_path

    def initialize(root, profile_path: PROFILE_PATH)
      @root = File.realpath(root)
      @loader = ContractLoader.new(@root)
      @guard = loader.guard
      @profile_path = profile_path
      @snapshots = {}
    end

    def build
      @snapshots = {}
      validate_v2_schemas!
      profile, profile_bytes = loader.load_yaml_with_bytes(profile_path, PROFILE_SCHEMA)
      snapshot!(profile_path, profile_bytes)
      validate_profile_filename!(profile)
      catalog, catalog_bytes = load_catalog
      chapters = select_all_chapters!(profile, catalog)
      companions = tracked_companions!(profile, chapters)
      chapter_records = chapter_records(chapters, companions)
      volumes = volume_records(profile, chapter_records)
      toolchain, toolchain_bytes = loader.load_yaml_with_bytes(profile.fetch("toolchain_lock"), Publication::TOOLCHAIN_SCHEMA)
      snapshot!(profile.fetch("toolchain_lock"), toolchain_bytes)
      tool_requirements = required_tools(toolchain)

      content_entries = chapter_records.map do |chapter|
        input_entry(chapter.fetch("source_path"), "content", "chapter-markdown")
      end
      companion_entries = companions.map do |entry|
        input_entry(entry.fetch("path"), "companion-index", "git-tracked-#{entry.fetch('kind')}")
      end
      publisher_paths = ([profile_path, CATALOG_PATH, profile.fetch("toolchain_lock")] + IMPLEMENTATION_INPUTS).uniq.sort
      publisher_entries = publisher_paths.map { |path| input_entry(path, "publisher-contract", publisher_role(path)) }
      all_entries = unique_entries(content_entries + companion_entries + publisher_entries)
      validate_snapshots!(all_entries)

      projection = chapters.map { |chapter| chapter.slice("id", "title", "volume", "order", "status", "path") }
      plan = {
        "schema_version" => 2,
        "plan_id" => "publication-plan.internal-complete",
        "profile_id" => profile.fetch("profile_id"),
        "site_id" => "factorycare-encyclopedia",
        "edition" => profile.fetch("edition"),
        "publication_mode" => profile.fetch("publication_mode"),
        "visibility" => profile.fetch("visibility"),
        "distribution_allowed" => profile.fetch("distribution_allowed"),
        "language" => profile.fetch("language"),
        "deterministic" => true,
        "generated_by" => "scripts/build-complete-publication-plan.rb",
        "output_root" => OUTPUT_ROOT,
        "source_date_epoch" => profile.fetch("source_date_epoch"),
        "resource_policy" => profile.fetch("resource_policy"),
        "notice" => profile.fetch("notice"),
        "digest_algorithm" => DIGEST_ALGORITHM,
        "profile" => path_digest(profile_path),
        "catalog" => {
          "path" => CATALOG_PATH,
          "source_sha256" => Canonical.sha256(catalog_bytes),
          "selected_projection_sha256" => Canonical.sha256(Canonical.json(projection)),
          "chapter_count" => chapter_records.length
        },
        "toolchain_lock" => path_digest(profile.fetch("toolchain_lock")),
        "tool_requirements" => tool_requirements,
        "chapters" => chapter_records,
        "volumes" => volumes,
        "companions" => companions,
        "inputs" => all_entries,
        "input_count" => all_entries.length,
        "content_input_digest" => entries_digest(content_entries + companion_entries),
        "publisher_input_digest" => entries_digest(publisher_entries),
        "build_input_digest" => entries_digest(all_entries),
        "planned_outputs" => planned_outputs(chapter_records, volumes),
        "security" => {
          "private_input_count" => 0,
          "private_canary_count" => 0,
          "absolute_input_path_count" => 0,
          "symlink_input_count" => 0,
          "untracked_companion_count" => 0,
          "generated_input_count" => 0
        }
      }
      validate_plan!(plan)
      plan
    rescue JSON::ParserError, StrictJson::DuplicateMemberError => e
      raise ContractError.new("schema", "E_JSON_PARSE", e.message.lines.first.to_s.strip)
    end

    def render(plan = build)
      Canonical.json(plan)
    end

    # The plan sidecar is updated independently so `--check` never replaces or
    # rejects the renderer's larger exact output tree.
    def write(plan = build)
      bytes = Canonical.json(plan).b
      output = safe_output_directory!(create: true)
      target = File.join(output, "publication-plan-v2.json")
      temporary = File.join(output, ".publication-plan-v2.json.#{$$}.tmp")
      raise ContractError.new("commit", "E_TEMP_EXISTS", "temporary plan path already exists") if File.exist?(temporary) || File.symlink?(temporary)

      begin
        File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o644) do |file|
          file.binmode
          file.write(bytes)
          file.flush
          file.fsync
        end
        File.rename(temporary, target)
        File.open(output, File::RDONLY) { |directory| directory.fsync }
      ensure
        File.unlink(temporary) if File.file?(temporary) && !File.symlink?(temporary)
      end
      PLAN_PATH
    end

    def check(plan = build)
      output = safe_output_directory!(create: false)
      target = File.join(output, "publication-plan-v2.json")
      stat = File.lstat(target)
      unless stat.file? && !stat.symlink?
        raise ContractError.new("check", "E_OUTPUT_UNSAFE", "publication plan must be a regular file", path: PLAN_PATH)
      end
      unless File.binread(target) == Canonical.json(plan).b
        raise ContractError.new("check", "E_OUTPUT_STALE", "publication plan differs from canonical inputs", path: PLAN_PATH)
      end
      true
    rescue Errno::ENOENT
      raise ContractError.new("check", "E_OUTPUT_MISSING", "publication plan is missing", path: PLAN_PATH)
    end

    private

    def validate_v2_schemas!
      [PROFILE_SCHEMA, PLAN_SCHEMA, OUTPUT_SCHEMA].each { |path| loader.schema(path) }
    end

    def validate_profile_filename!(profile)
      expected = "publication/profiles/#{profile.fetch('profile_id')}.yml"
      return if profile_path == expected

      raise ContractError.new("selection", "E_PROFILE_FILENAME", "profile filename must match profile_id", path: profile_path)
    end

    def load_catalog
      bytes, = guard.read(CATALOG_PATH, label: "canonical catalog", patterns: [exact(CATALOG_PATH)])
      snapshot!(CATALOG_PATH, bytes)
      catalog = StrictYaml.safe_load(bytes.force_encoding(Encoding::UTF_8), label: CATALOG_PATH)
      unless catalog.is_a?(Hash) && catalog["chapters"].is_a?(Array)
        raise ContractError.new("catalog-validation", "E_CATALOG_SHAPE", "catalog must contain a chapter array", path: CATALOG_PATH)
      end
      [catalog, bytes]
    rescue Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError => e
      raise ContractError.new("catalog-validation", "E_CATALOG_PARSE", e.message.lines.first.to_s.strip, path: CATALOG_PATH)
    end

    def select_all_chapters!(profile, catalog)
      selection = profile.fetch("selection")
      unless selection.fetch("kind") == "catalog-all"
        raise ContractError.new("selection", "E_SELECTION_KIND", "complete profile must select catalog-all")
      end
      chapters = catalog.fetch("chapters")
      expected_count = selection.fetch("expected_chapter_count")
      unless chapters.length == expected_count
        raise ContractError.new("selection", "E_CHAPTER_COUNT", "catalog chapter count differs from the fixed complete profile")
      end
      ids = chapters.map { |chapter| chapter.fetch("id") }
      unless ids.uniq.length == ids.length
        raise ContractError.new("selection", "E_CHAPTER_DUPLICATE", "catalog chapter ids must be unique")
      end
      volumes = chapters.map { |chapter| chapter.fetch("volume") }.uniq
      unless volumes == selection.fetch("expected_volume_ids")
        raise ContractError.new("selection", "E_VOLUME_SET", "catalog volume order differs from the fixed complete profile")
      end
      status_counts = { "drafting" => 0, "review" => 0, "verified" => 0 }
      chapters.each { |chapter| status_counts[chapter.fetch("status")] = status_counts.fetch(chapter.fetch("status"), 0) + 1 }
      unless status_counts == selection.fetch("expected_status_counts")
        raise ContractError.new("selection", "E_STATUS_COUNTS", "catalog status counts differ from the explicitly reviewed profile")
      end
      chapters
    end

    def tracked_companions!(profile, chapters)
      roots = profile.fetch("companion_inventory").fetch("roots")
      unless roots == COMPANION_KIND.keys
        raise ContractError.new("inventory", "E_COMPANION_ROOTS", "companion roots differ from the fixed public roots")
      end
      stdout, stderr, status = Open3.capture3("git", "-C", root, "ls-files", "-s", "-z", "--", *roots)
      unless status.success?
        raise ContractError.new("inventory", "E_GIT_INVENTORY", "git tracked inventory failed: #{stderr.lines.first.to_s.strip}")
      end
      chapter_ids = chapters.map { |chapter| chapter.fetch("id") }.to_set
      records = stdout.split("\0").reject(&:empty?).map do |line|
        metadata, path = line.split("\t", 2)
        mode, blob, stage = metadata.to_s.split(" ")
        unless path && stage == "0"
          raise ContractError.new("inventory", "E_GIT_RECORD", "git tracked inventory returned an invalid index record")
        end
        validate_companion_path!(path, roots)
        unless %w[100644 100755].include?(mode)
          code = mode == "120000" ? "E_PATH_SYMLINK" : "E_GIT_MODE"
          raise ContractError.new("inventory", code, "tracked companion must be a regular file", path: path)
        end
        root_path = roots.find { |candidate| path.start_with?(candidate + "/") }
        chapter_id = path.delete_prefix(root_path + "/").split("/", 2).first
        unless chapter_ids.include?(chapter_id)
          raise ContractError.new("inventory", "E_COMPANION_OWNER", "tracked companion has no selected chapter owner", path: path)
        end
        bytes = read_companion!(path)
        reject_canary!(bytes, path)
        snapshot!(path, bytes)
        {
          "chapter_id" => chapter_id,
          "kind" => COMPANION_KIND.fetch(root_path),
          "path" => path,
          "git_mode" => mode,
          "git_blob" => blob,
          "sha256" => Canonical.sha256(bytes),
          "size_bytes" => bytes.bytesize
        }
      end
      collision = records.group_by { |record| record.fetch("path").downcase }.values.find { |items| items.length > 1 }
      if collision
        raise ContractError.new("inventory", "E_PATH_CASE_COLLISION", "case-folded companion paths collide", path: collision.first.fetch("path"))
      end
      records.sort_by { |record| record.fetch("path") }
    end

    def validate_companion_path!(path, roots)
      text = path.dup.force_encoding(Encoding::UTF_8)
      unless text.valid_encoding? && !text.empty? && !text.start_with?("/") && !text.include?("\\") &&
             !text.match?(/[[:cntrl:]]/)
        raise ContractError.new("inventory", "E_PATH_GRAMMAR", "tracked companion path is not a safe POSIX relative path")
      end
      if text.split("/", -1).any? { |segment| segment.empty? || segment == "." || segment == ".." }
        raise ContractError.new("inventory", "E_PATH_SEGMENT", "tracked companion path contains an unsafe segment", path: text)
      end
      if text.split("/").any? { |segment| GENERATED_COMPONENTS.include?(segment) }
        raise ContractError.new("inventory", "E_COMPANION_GENERATED", "generated output cannot enter the companion inventory", path: text)
      end
      unless roots.any? { |candidate| text.start_with?(candidate + "/") }
        raise ContractError.new("inventory", "E_PATH_OWNERSHIP", "tracked companion is outside the fixed roots", path: text)
      end
      reject_private_path!(text)
    end

    def read_companion!(relative)
      absolute = File.join(root, relative)
      cursor = root
      relative.split("/").each do |component|
        cursor = File.join(cursor, component)
        if File.symlink?(cursor)
          raise ContractError.new("inventory", "E_PATH_SYMLINK", "companion path components cannot be symbolic links", path: relative)
        end
      end
      stat = File.lstat(absolute)
      unless stat.file? && !stat.symlink?
        raise ContractError.new("inventory", "E_PATH_NOT_FILE", "tracked companion must be a regular file", path: relative)
      end
      flags = File::RDONLY
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      File.open(absolute, flags) do |file|
        opened = file.stat
        unless opened.file? && opened.dev == stat.dev && opened.ino == stat.ino
          raise ContractError.new("inventory", "E_PATH_CHANGED", "companion changed while opening", path: relative)
        end
        file.binmode
        file.read
      end
    rescue Errno::ENOENT
      raise ContractError.new("inventory", "E_PATH_MISSING", "tracked companion is missing", path: relative)
    rescue Errno::ELOOP
      raise ContractError.new("inventory", "E_PATH_SYMLINK", "companion path cannot be followed", path: relative)
    end

    def chapter_records(chapters, companions)
      counts = companions.group_by { |entry| entry.fetch("chapter_id") }
      chapters.map do |chapter|
        path = chapter.fetch("path")
        bytes, = guard.read(path, label: "chapter Markdown", patterns: [exact(path)])
        reject_canary!(bytes, path)
        snapshot!(path, bytes)
        {
          "id" => chapter.fetch("id"),
          "title" => chapter.fetch("title"),
          "volume" => chapter.fetch("volume"),
          "order" => chapter.fetch("order"),
          "status" => chapter.fetch("status"),
          "source_path" => path,
          "source_sha256" => Canonical.sha256(bytes),
          "companion_count" => counts.fetch(chapter.fetch("id"), []).length
        }
      end
    end

    def volume_records(profile, chapters)
      expected = profile.fetch("selection").fetch("expected_volume_ids")
      expected.map do |id|
        selected = chapters.select { |chapter| chapter.fetch("volume") == id }
        raise ContractError.new("selection", "E_VOLUME_EMPTY", "complete volume cannot be empty") if selected.empty?
        {
          "id" => id,
          "title" => VOLUME_TITLES.fetch(id),
          "chapter_ids" => selected.map { |chapter| chapter.fetch("id") },
          "chapter_count" => selected.length
        }
      end
    end

    def required_tools(toolchain)
      tools = toolchain.fetch("tools").each_with_object({}) { |tool, memo| memo[tool.fetch("id")] = tool }
      REQUIRED_TOOLS.map do |id|
        tool = tools.fetch(id) { raise ContractError.new("tool-preflight", "E_TOOL_MISSING", "required R2 tool is absent") }
        unless tool.fetch("state") == "observed-current" && tool["expected_version_prefix"]
          raise ContractError.new("tool-preflight", "E_TOOL_STATE", "required R2 tool is not observed-current")
        end
        {
          "id" => id,
          "command" => tool.fetch("command"),
          "expected_version_prefix" => tool.fetch("expected_version_prefix")
        }
      end
    end

    def planned_outputs(chapters, volumes)
      outputs = []
      outputs << planned("ast/book.json", "canonical-ast", "internal")
      volumes.each { |volume| outputs << planned("ast/volumes/volume-#{volume.fetch('id')}.json", "volume-ast", "internal") }
      outputs << planned("intermediate/print/book.html", "whole-print-html", "internal")
      volumes.each { |volume| outputs << planned("intermediate/print/volumes/volume-#{volume.fetch('id')}.html", "volume-print-html", "internal") }
      outputs << planned("output/html/index.html", "html-index", "html")
      outputs << planned("output/html/book.html", "whole-html", "html")
      volumes.each { |volume| outputs << planned("output/html/volumes/volume-#{volume.fetch('id')}.html", "volume-html", "html") }
      chapters.each { |chapter| outputs << planned("output/html/chapters/#{chapter.fetch('id')}.html", "chapter-html", "html") }
      outputs << planned("output/index/navigation.json", "navigation-index", "internal")
      outputs << planned("output/index/search-index.json", "search-index", "internal")
      outputs << planned("output/index/companions.json", "companion-index", "internal")
      outputs << planned("output/epub/factorycare-internal-complete.epub", "whole-epub", "epub")
      volumes.each { |volume| outputs << planned("output/epub/volumes/factorycare-volume-#{volume.fetch('id')}.epub", "volume-epub", "epub") }
      outputs << planned("output/pdf/factorycare-internal-complete.pdf", "whole-pdf-candidate", "pdf")
      volumes.each { |volume| outputs << planned("output/pdf/volumes/factorycare-volume-#{volume.fetch('id')}.pdf", "volume-pdf-candidate", "pdf") }
      outputs << planned("publication-output-manifest-v2.json", "output-manifest", "internal")
      outputs
    end

    def planned(path, kind, format)
      { "path" => path, "kind" => kind, "format" => format, "distribution" => "internal-review-candidate" }
    end

    def input_entry(path, scope, role)
      bytes = @snapshots[path]
      unless bytes
        bytes = if path.start_with?(*COMPANION_KIND.keys)
                  read_companion!(path)
                else
                  guard.read(path, label: "publication input", patterns: [exact(path)], require_nonblank: false).first
                end
        snapshot!(path, bytes)
      end
      { "path" => path, "scope" => scope, "role" => role, "sha256" => Canonical.sha256(bytes), "size_bytes" => bytes.bytesize }
    end

    def publisher_role(path)
      return "profile" if path == profile_path
      return "catalog" if path == CATALOG_PATH
      return "toolchain-lock" if path == "publication/toolchain.yml"
      return "schema" if path.start_with?("schemas/")
      return "style" if path.start_with?("publication/styles/")
      return "template" if path.start_with?("publication/templates/")

      "implementation"
    end

    def path_digest(path)
      { "path" => path, "sha256" => Canonical.sha256(@snapshots.fetch(path)) }
    end

    def entries_digest(entries)
      Canonical.path_bytes_digest(entries, lambda { |path| @snapshots.fetch(path) })
    end

    def unique_entries(entries)
      grouped = entries.group_by { |entry| entry.fetch("path") }
      duplicate = grouped.find { |_path, values| values.length > 1 && values.uniq.length > 1 }
      if duplicate
        raise ContractError.new("inventory", "E_INPUT_ROLE_COLLISION", "one input was assigned conflicting roles", path: duplicate.first)
      end
      grouped.values.map(&:first).sort_by { |entry| entry.fetch("path") }
    end

    def snapshot!(path, bytes)
      existing = @snapshots[path]
      if existing && existing != bytes
        raise ContractError.new("inventory", "E_INPUT_CHANGED", "input changed during planning", path: path)
      end
      @snapshots[path] = bytes.b
    end

    def validate_snapshots!(entries)
      entries.each do |entry|
        path = entry.fetch("path")
        reject_private_path!(path)
        bytes = @snapshots.fetch(path)
        reject_canary!(bytes, path)
        unless bytes.bytesize == entry.fetch("size_bytes") && Canonical.sha256(bytes) == entry.fetch("sha256")
          raise ContractError.new("inventory", "E_INPUT_DIGEST", "input snapshot does not match its plan entry", path: path)
        end
      end
    end

    def validate_plan!(plan)
      loader.validate_value!(plan, PLAN_SCHEMA, PLAN_PATH)
      unless plan.fetch("chapters").map { |chapter| chapter.fetch("id") }.uniq.length == 255
        raise ContractError.new("plan-validation", "E_CHAPTER_SET", "complete plan must contain 255 unique chapters")
      end
      unless plan.fetch("companions").map { |entry| entry.fetch("path") }.uniq.length == plan.fetch("companions").length
        raise ContractError.new("plan-validation", "E_COMPANION_SET", "companion paths must be unique")
      end
      unless plan.fetch("planned_outputs") == planned_outputs(plan.fetch("chapters"), plan.fetch("volumes"))
        raise ContractError.new("plan-validation", "E_OUTPUT_SET", "planned output set differs from the complete contract")
      end
      serialized = Canonical.json(plan)
      if PRIVATE_PATH_PREFIXES.any? { |prefix| serialized.include?(prefix) } || serialized.match?(%r{(?:^|["'])/(?:Users|home)/})
        raise ContractError.new("plan-validation", "E_PLAN_LEAK", "plan contains a private or absolute path marker")
      end
      true
    end

    def safe_output_directory!(create:)
      cursor = root
      %w[build publication internal-complete].each do |component|
        cursor = File.join(cursor, component)
        if File.exist?(cursor) || File.symlink?(cursor)
          stat = File.lstat(cursor)
          raise ContractError.new("inventory", "E_OUTPUT_SYMLINK", "output path contains a symbolic link") if stat.symlink?
          raise ContractError.new("inventory", "E_OUTPUT_NOT_DIRECTORY", "output path component is not a directory") unless stat.directory?
        elsif create
          Dir.mkdir(cursor, 0o755)
        else
          raise ContractError.new("check", "E_OUTPUT_MISSING", "publication output directory is missing")
        end
      end
      cursor
    end

    def reject_private_path!(path)
      if PRIVATE_PATH_PREFIXES.any? { |prefix| path == prefix.delete_suffix("/") || path.start_with?(prefix) }
        raise ContractError.new("inventory", "E_PRIVATE_INPUT", "private inputs are forbidden", path: path)
      end
      if path.start_with?("/") || path.match?(/\A[A-Za-z]:[\\\/]/)
        raise ContractError.new("inventory", "E_ABSOLUTE_INPUT", "absolute input paths are forbidden", path: path)
      end
    end

    def reject_canary!(bytes, path)
      if bytes.match?(PRIVATE_CANARY_PATTERN)
        raise ContractError.new("inventory", "E_PRIVATE_CANARY", "private canary detected in a publication input", path: path)
      end
    end

    def exact(path)
      /\A#{Regexp.escape(path)}\z/
    end
  end
end
