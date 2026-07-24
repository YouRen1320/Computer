#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "rbconfig"
require "tmpdir"
require "yaml"

require File.expand_path("validate-encyclopedia", __dir__)

STATUS_ORDER = %w[planned drafting review verified].freeze unless defined?(STATUS_ORDER)
SITE_RUNTIME_SCHEMA_VERSION = 3 unless defined?(SITE_RUNTIME_SCHEMA_VERSION)
SITE_CONFIG_SCHEMA_VERSION = 2 unless defined?(SITE_CONFIG_SCHEMA_VERSION)
RETIRED_RUNTIME_KEYS = %w[alias aliases redirect redirects].freeze unless defined?(RETIRED_RUNTIME_KEYS)
V2_VOLUME_README_MARKER = "<!-- GENERATED: factorycare-curriculum; DO NOT EDIT -->" unless defined?(V2_VOLUME_README_MARKER)

class BookBuilder
  def initialize(root, check: false)
    @root = File.realpath(root)
    @check = check
    @path_policy = RepositoryPathPolicy.new(@root)
  end

  def run
    validate_inputs!
    catalog = load_yaml(CATALOG_RELATIVE)
    registry = load_yaml(REGISTRY_RELATIVE)
    config = load_yaml(SITE_CONFIG_RELATIVE)
    validate_contract_alignment!(catalog, registry, config)
    output_relative = config.fetch("output")
    ensure_safe_output!(output_relative)
    files = render_files(catalog, registry, config)
    validate_build_inputs_unchanged!
    @check ? check_files(output_relative, files) : write_files(output_relative, files)
  rescue StandardError => e
    warn "BOOK BUILD FAILED: #{e.message}"
    false
  end

  private

  def absolute(relative)
    File.expand_path(relative, @root)
  end

  def load_yaml(relative)
    data = StrictYaml.safe_load(File.read(absolute(relative), encoding: "UTF-8"), label: relative)
    raise "#{relative} root must be a mapping" unless data.is_a?(Hash)

    data
  end

  def validate_inputs!
    commands = [
      ["encyclopedia contract (includes strict curriculum validation)", [RbConfig.ruby, absolute("scripts/validate-encyclopedia.rb"), "--quiet"]]
    ]
    commands.each do |label, command|
      stdout, stderr, status = Open3.capture3(*command, chdir: @root)
      next if status.success?

      message = [stdout, stderr].reject(&:empty?).join("\n").strip
      raise "#{label} validation failed\n#{message}"
    end
  end

  def ensure_safe_output!(relative)
    issues = @path_policy.validate_output_directory(relative)
    raise issues.join("; ") unless issues.empty?
  end

  def validate_contract_alignment!(catalog, registry, config)
    raise "#{CATALOG_RELATIVE} schema_version must be 2" unless catalog["schema_version"] == 2
    raise "#{SITE_CONFIG_RELATIVE} schema_version must be 2" unless config["schema_version"] == SITE_CONFIG_SCHEMA_VERSION
    raise "#{SITE_CONFIG_RELATIVE} site_id must match catalog_id" unless config["site_id"] == catalog["catalog_id"]

    editions = {
      CATALOG_RELATIVE => catalog["edition"],
      REGISTRY_RELATIVE => registry["edition"],
      SITE_CONFIG_RELATIVE => config["edition"]
    }
    return if editions.values.uniq.length == 1

    raise "edition mismatch across catalog, registry and site: #{editions.map { |path, value| "#{path}=#{value.inspect}" }.join(", ")}"
  end

  def render_files(catalog, registry, config)
    chapters = catalog.fetch("chapters").sort_by { |chapter| [chapter.fetch("volume"), chapter.fetch("order")] }
    publish_statuses = config.fetch("publish_statuses")
    raise "planned chapters must never be publishable or searchable" if publish_statuses.include?("planned")

    inventory = manifest_input_inventory(catalog)
    validate_manifest_inputs!(inventory)
    categories = inventory.fetch(:categories)
    @input_snapshots = EncyclopediaInputSet.snapshots(@root, categories)
    input_files = EncyclopediaInputSet.file_digests(categories, @input_snapshots)
    category_digests = EncyclopediaInputSet.category_digests(input_files)
    total_digest = EncyclopediaInputSet.total_digest(category_digests)
    input_digests = category_digests.merge("total" => total_digest)
    counts = STATUS_ORDER.each_with_object({}) do |status, memo|
      memo[status] = chapters.count { |chapter| chapter["status"] == status }
    end
    records = chapters.map { |chapter| catalog_record(chapter, publish_statuses) }
    volumes = records.group_by { |record| record.fetch("volume") }.sort.map do |volume, volume_chapters|
      {
        "id" => volume,
        "title" => volume_title(volume),
        "chapters" => volume_chapters
      }
    end
    publishable_count = records.count { |record| record["publishable"] }

    generated_catalog = {
      "schema_version" => SITE_RUNTIME_SCHEMA_VERSION,
      "site_id" => config.fetch("site_id"),
      "title" => config.fetch("title"),
      "edition" => config.fetch("edition"),
      "language" => config.fetch("language"),
      "input_digests" => input_digests,
      "chapter_count" => records.length,
      "publishable_count" => publishable_count,
      "counts_by_status" => counts,
      "volumes" => volumes
    }
    navigation = {
      "schema_version" => SITE_RUNTIME_SCHEMA_VERSION,
      "edition" => config.fetch("edition"),
      "input_digests" => input_digests,
      "volumes" => volumes.map do |volume|
        {
          "id" => volume.fetch("id"),
          "title" => volume.fetch("title"),
          "chapters" => volume.fetch("chapters").map do |chapter|
            chapter.slice("id", "title", "order", "level", "status", "path", "publishable")
          end
        }
      end
    }
    search_records = chapters.select { |chapter| publish_statuses.include?(chapter["status"]) }.map do |chapter|
      search_record(chapter)
    end
    search_index = {
      "schema_version" => SITE_RUNTIME_SCHEMA_VERSION,
      "site_id" => config.fetch("site_id"),
      "edition" => config.fetch("edition"),
      "input_digests" => input_digests,
      "record_count" => search_records.length,
      "records" => search_records
    }

    rendered = {
      "catalog.json" => pretty_json(generated_catalog),
      "navigation.json" => pretty_json(navigation),
      "search-index.json" => pretty_json(search_index),
      "README.md" => generated_readme(config, records.length, publishable_count, input_digests)
    }
    output_digests = rendered.each_with_object({}) do |(name, content), memo|
      memo[name] = Digest::SHA256.hexdigest(content)
    end
    manifest = {
      "schema_version" => SITE_RUNTIME_SCHEMA_VERSION,
      "site_id" => config.fetch("site_id"),
      "edition" => config.fetch("edition"),
      "deterministic" => true,
      "generated_by" => "scripts/build-book.rb",
      "digest_algorithms" => {
        "category" => EncyclopediaInputSet::CATEGORY_DIGEST_ALGORITHM,
        "total" => EncyclopediaInputSet::TOTAL_DIGEST_ALGORITHM
      },
      "input_digests" => input_digests,
      "input_counts" => EncyclopediaInputSet::CATEGORY_ORDER.to_h { |category| [category, categories.fetch(category).length] }
                                                        .merge("total" => categories.values.sum(&:length)),
      "inputs" => input_files,
      "outputs" => output_digests,
      "chapter_count" => records.length,
      "publishable_count" => publishable_count,
      "counts_by_status" => counts,
      "registry_entry_count" => registry.fetch("entries").length,
      "registry_reviewed_at" => registry.fetch("reviewed_at")
    }
    rendered["publication-manifest.json"] = pretty_json(manifest)
    validate_runtime_outputs!(rendered, inventory: inventory)
    rendered
  end

  def manifest_input_inventory(catalog)
    EncyclopediaInputSet.inventory(@root, catalog)
  end

  def validate_manifest_inputs!(inventory)
    categories = inventory.fetch(:categories)
    expected = inventory.fetch(:expected)
    EncyclopediaInputSet.validate_partition!(categories, expected)
    EncyclopediaInputSet.validate_tracked!(@root, expected)
    private_inputs = expected.select { |relative| relative.start_with?("solutions-private/") }
    raise "private solutions must never enter the publication manifest: #{private_inputs.join(", ")}" unless private_inputs.empty?

    patterns = [
      %r{\A(?:ASSESSMENTS|PROGRESS)\.md\z},
      %r{\A(?:book|curriculum|publication/manifests/public-artifacts|schemas|scripts|site|versions)/[a-zA-Z0-9._/-]+\z},
      %r{\A(?:examples|labs|exercises)/encyclopedia/[a-zA-Z0-9._/-]+\z},
      %r{\Afactorycare-design/testing/acceptance-catalog\.md\z},
      %r{\Arecords/encyclopedia/evidence/[a-zA-Z0-9._/-]+\z},
      %r{\Arecords/encyclopedia/reviews/P1R-migration-ledger-audit\.md\z}
    ]
    expected.each do |relative|
      issues = @path_policy.validate_regular_file(relative, label: "manifest input #{relative}", patterns: patterns)
      raise issues.join("; ") unless issues.empty?
    end
  end

  def catalog_record(chapter, publish_statuses)
    validate_semantic_chapter!(chapter)
    {
      "id" => chapter.fetch("id"),
      "title" => chapter.fetch("title"),
      "responsibility" => chapter.fetch("responsibility"),
      "volume" => chapter.fetch("volume"),
      "order" => chapter.fetch("order"),
      "level" => chapter.fetch("level"),
      "status" => chapter.fetch("status"),
      "prerequisites" => catalog_prerequisites(chapter),
      # Structured explain/build/diagnose outcomes are a public contract. Keep
      # every field and value exactly as emitted by the canonical compiler.
      "outcomes" => chapter.fetch("outcomes"),
      "route_tags" => chapter.fetch("route_tags"),
      "stable_core" => chapter.fetch("stable_core"),
      "version_surfaces" => catalog_version_surfaces(chapter),
      "path" => chapter.fetch("path"),
      "publishable" => publish_statuses.include?(chapter.fetch("status"))
    }
  end

  def catalog_prerequisites(chapter)
    Array(chapter["prerequisites"])
  end

  def catalog_version_surfaces(chapter)
    raise "#{chapter.fetch('id', 'chapter')} uses retired versioned_surface field" if chapter.key?("versioned_surface")

    chapter.fetch("version_surfaces")
  end

  def search_record(chapter)
    validate_semantic_chapter!(chapter)
    path = chapter.fetch("path")
    issues = @path_policy.validate_regular_file(
      path,
      label: "published chapter #{chapter.fetch("id")}",
      patterns: [%r{\Abook/volume-#{Regexp.escape(chapter.fetch("volume"))}-[a-z0-9-]+/chapters/#{Regexp.escape(chapter.fetch("id"))}\.md\z}]
    )
    raise issues.join("; ") unless issues.empty?

    body = File.read(absolute(path), encoding: "UTF-8")
    without_front_matter = body.sub(/\A---\s*\n.*?\n---\s*\n/m, "")
    headings = without_front_matter.lines.each_with_object([]) do |line, memo|
      match = line.match(/\A[#]{2,6}\s+(.+?)\s*\z/)
      memo << match[1] if match
    end
    {
      "id" => chapter.fetch("id"),
      "title" => chapter.fetch("title"),
      "volume" => chapter.fetch("volume"),
      "status" => chapter.fetch("status"),
      "path" => path,
      "route_tags" => chapter.fetch("route_tags"),
      "headings" => headings,
      "summary" => first_prose_paragraph(without_front_matter)
    }
  end

  def validate_semantic_chapter!(chapter)
    id = chapter.fetch("id")
    unless id.is_a?(String) && CHAPTER_ID_PATTERN.match?(id)
      raise "chapter id #{id.inspect} must use semantic ch.<domain>.<slug> form"
    end

    raise "#{id} uses retired versioned_surface field" if chapter.key?("versioned_surface")
    retired_keys = RETIRED_RUNTIME_KEYS & chapter.keys
    raise "#{id} contains retired runtime compatibility fields: #{retired_keys.join(', ')}" unless retired_keys.empty?

    expected = %r{\Abook/volume-#{Regexp.escape(chapter.fetch("volume"))}-[a-z0-9-]+/chapters/#{Regexp.escape(id)}\.md\z}
    path = chapter.fetch("path")
    raise "#{id} path must use its semantic id filename" unless path.is_a?(String) && expected.match?(path)
  end

  def validate_runtime_outputs!(rendered, inventory:)
    documents = rendered.select { |name, _content| name.end_with?(".json") }
                        .transform_values { |content| StrictJson.parse(content) }
    manifest = documents.fetch("publication-manifest.json")
    validate_runtime_schema!(documents)
    validate_runtime_input_contract!(documents, manifest, inventory, rendered)

    rendered.each do |name, content|
      if content.match?(LEGACY_CHAPTER_ID_PATTERN)
        raise "#{name} contains a retired chapter id"
      end
      next unless name.end_with?(".json")

      document = StrictJson.parse(content)
      retired = runtime_compatibility_keys(document)
      raise "#{name} contains retired alias/redirect fields: #{retired.uniq.sort.join(', ')}" unless retired.empty?
    end
  end

  def validate_runtime_schema!(documents)
    schema = StrictJson.parse(File.read(absolute(SITE_GENERATED_SCHEMA_RELATIVE), encoding: "UTF-8"))
    evaluator = ExecutableJsonSchema.new(schema, SITE_GENERATED_SCHEMA_RELATIVE)
    unless evaluator.definition_errors.empty?
      raise "#{SITE_GENERATED_SCHEMA_RELATIVE}: #{evaluator.definition_errors.first}"
    end
    checks = {
      "publication-manifest.json" => [nil, documents.fetch("publication-manifest.json")],
      "catalog.json" => ["#/$defs/catalog_document", documents.fetch("catalog.json")],
      "navigation.json" => ["#/$defs/navigation_document", documents.fetch("navigation.json")],
      "search-index.json" => ["#/$defs/search_document", documents.fetch("search-index.json")]
    }
    checks.each do |name, (reference, document)|
      errors = reference ? evaluator.validate_subschema(reference, document) : evaluator.validate(document)
      raise "#{name}: schema v3 violation: #{errors.first}" unless errors.empty?
    end
  end

  def validate_runtime_input_contract!(documents, manifest, inventory, rendered)
    if manifest.key?("input_digest") || documents.any? { |_name, document| document.key?("input_digest") }
      raise "runtime schema v3 forbids legacy input_digest"
    end

    categories = inventory.fetch(:categories)
    expected_files = EncyclopediaInputSet.file_digests(categories, @input_snapshots)
    actual_files = manifest.fetch("inputs")
    unless actual_files == expected_files
      raise "publication-manifest.json input categories differ from the authoritative inventory"
    end

    expected_counts = EncyclopediaInputSet::CATEGORY_ORDER.to_h { |category| [category, categories.fetch(category).length] }
                                                       .merge("total" => categories.values.sum(&:length))
    unless manifest.fetch("input_counts") == expected_counts
      raise "publication-manifest.json input counts differ from the categorized input sets"
    end

    paths = actual_files.values.flat_map(&:keys)
    unless paths.uniq.length == paths.length
      raise "publication-manifest.json input categories overlap"
    end

    category_digests = EncyclopediaInputSet.category_digests(actual_files)
    expected_digests = category_digests.merge("total" => EncyclopediaInputSet.total_digest(category_digests))
    unless manifest.fetch("input_digests") == expected_digests
      raise "publication-manifest.json input digests are not recomputable from categorized file digests"
    end
    unless manifest.fetch("digest_algorithms") == {
      "category" => EncyclopediaInputSet::CATEGORY_DIGEST_ALGORITHM,
      "total" => EncyclopediaInputSet::TOTAL_DIGEST_ALGORITHM
    }
      raise "publication-manifest.json digest algorithms differ from the schema-v3 contract"
    end
    documents.each do |name, document|
      next if name == "publication-manifest.json"
      unless document.fetch("input_digests") == expected_digests
        raise "#{name} input digests differ from publication-manifest.json"
      end
    end

    expected_outputs = rendered.reject { |name, _content| name == "publication-manifest.json" }
                               .transform_values { |content| Digest::SHA256.hexdigest(content) }
    unless manifest.fetch("outputs") == expected_outputs
      raise "publication-manifest.json output digests differ from the four non-manifest generated files"
    end
  end

  def runtime_compatibility_keys(value, found = [])
    case value
    when Hash
      value.each do |key, child|
        found << key if RETIRED_RUNTIME_KEYS.include?(key)
        runtime_compatibility_keys(child, found)
      end
    when Array
      value.each { |child| runtime_compatibility_keys(child, found) }
    end
    found
  end

  def first_prose_paragraph(markdown)
    paragraphs = markdown.split(/\n\s*\n/).map(&:strip)
    candidate = paragraphs.find do |paragraph|
      !paragraph.empty? && !paragraph.start_with?("#", ">", "```", "- ", "* ", "|")
    end
    clean = candidate.to_s.gsub(/[`*_\[\]]/, "").gsub(/\((https?:\/\/[^)]+)\)/, "").gsub(/\s+/, " ").strip
    clean.length > 240 ? "#{clean[0, 237]}..." : clean
  end

  def volume_title(volume)
    candidates = Dir.glob(absolute("book/volume-#{volume}-*/README.md")).sort
    raise "volume #{volume} must have exactly one README" unless candidates.length == 1

    relative = candidates.first.delete_prefix(@root + File::SEPARATOR)
    issues = @path_policy.validate_regular_file(
      relative,
      label: "volume #{volume} README",
      patterns: [%r{\Abook/volume-[0-9]{2}-[a-z0-9-]+/README\.md\z}]
    )
    raise issues.join("; ") unless issues.empty?

    lines = File.readlines(candidates.first, encoding: "UTF-8")
    raise "volume #{volume} README lacks the v2 generator marker" unless lines.first.to_s.strip == V2_VOLUME_README_MARKER

    heading = lines.fetch(1, "").strip
    match = heading.match(/\A#\s+卷\s+\d{2}：(.+)\z/)
    raise "volume #{volume} README has an invalid heading" unless match

    match[1]
  end

  def pretty_json(value)
    JSON.pretty_generate(value) + "\n"
  end

  def generated_readme(config, chapter_count, publishable_count, digests)
    <<~MARKDOWN
      # 生成的发布数据

      本目录由 `ruby scripts/build-book.rb` 从 manifest 列出的规范输入确定性生成，请勿手工编辑。

      - 站点：#{config.fetch("title")}
      - 版本：#{config.fetch("edition")}
      - 章节：#{chapter_count}
      - 可发布章节：#{publishable_count}
      - 内容输入摘要：`#{digests.fetch("content")}`
      - 审计/安全输入摘要：`#{digests.fetch("audit_security")}`
      - 构建/控制输入摘要：`#{digests.fetch("build_control")}`
      - 总输入摘要：`#{digests.fetch("total")}`

      `planned` 占位不会进入 `search-index.json`；只有 `#{config.fetch("publish_statuses").join(", ")}` 状态可以进入公开搜索数据。答案目录不属于发布输入或输出。

      运行时 JSON 使用 schema v3 和语义章节 ID；输入按 content、audit_security、build_control 三类互斥记录，不读取旧 `input_digest`，也不提供旧 ID、重定向或 schema v2 兼容分支。
    MARKDOWN
  end

  def validate_build_inputs_unchanged!
    return true unless @input_snapshots

    EncyclopediaInputSet.validate_snapshots!(@root, @input_snapshots)
  end

  def check_files(output_relative, files)
    validate_build_inputs_unchanged!
    ensure_safe_output!(output_relative)
    output = absolute(output_relative)
    unless File.directory?(output)
      warn "BOOK BUILD CHECK FAILED (missing output directory #{output_relative})"
      return false
    end

    expected_names = files.keys.sort
    actual_names = Dir.children(output).sort
    mismatches = []
    (actual_names - expected_names).each { |name| mismatches << "unexpected #{File.join(output_relative, name)}" }
    (expected_names - actual_names).each { |name| mismatches << "missing #{File.join(output_relative, name)}" }
    (expected_names & actual_names).each do |name|
      path = File.join(output, name)
      stat = File.lstat(path)
      if stat.symlink? || !stat.file?
        mismatches << "unsafe #{File.join(output_relative, name)}"
      elsif Digest::SHA256.file(path).hexdigest != Digest::SHA256.hexdigest(files.fetch(name))
        mismatches << "stale #{File.join(output_relative, name)}"
      end
    end
    if mismatches.empty?
      puts "BOOK BUILD CHECK OK"
      puts "files=#{files.length}"
      return true
    end
    warn "BOOK BUILD CHECK FAILED (#{mismatches.length} mismatch(es))"
    mismatches.each { |message| warn "- #{message}" }
    false
  end

  def write_files(output_relative, files)
    ensure_safe_output!(output_relative)
    output = absolute(output_relative)
    parent = File.dirname(output)
    FileUtils.mkdir_p(parent)
    ensure_safe_output!(output_relative)

    staging = Dir.mktmpdir(".encyclopedia-stage-", parent)
    backup = File.join(parent, ".encyclopedia-backup-#{$$}-#{rand(1_000_000)}")
    backup_created = false
    begin
      raise "temporary backup path already exists" if File.exist?(backup) || File.symlink?(backup)

      files.each { |name, content| File.binwrite(File.join(staging, name), content) }
      validate_build_inputs_unchanged!
      if File.exist?(output)
        rename_directory(output, backup)
        backup_created = true
      end
      rename_directory(staging, output)
      staging = nil
      FileUtils.rm_rf(backup) if File.exist?(backup)
    rescue StandardError
      rename_directory(backup, output) if backup_created && File.exist?(backup) && !File.exist?(output)
      raise
    ensure
      FileUtils.rm_rf(staging) if staging && File.exist?(staging)
    end
    puts "BOOK BUILD OK"
    puts "output=#{output_relative}"
    puts "files=#{files.length}"
    true
  end

  def rename_directory(source, destination)
    File.rename(source, destination)
  end
end

if $PROGRAM_NAME == __FILE__
  options = { check: false }
  OptionParser.new do |parser|
    parser.banner = "Usage: ruby scripts/build-book.rb [options]"
    parser.on("--check", "fail if generated files differ from canonical inputs or contain extras") { options[:check] = true }
  end.parse!

  builder = BookBuilder.new(ROOT, **options)
  exit(builder.run ? 0 : 1)
end
