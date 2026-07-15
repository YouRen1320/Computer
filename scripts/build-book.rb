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
    output_relative = config.fetch("output")
    ensure_safe_output!(output_relative)
    files = render_files(catalog, registry, config)
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

  def render_files(catalog, registry, config)
    chapters = catalog.fetch("chapters").sort_by { |chapter| [chapter.fetch("volume"), chapter.fetch("order")] }
    publish_statuses = config.fetch("publish_statuses")
    inputs = EncyclopediaInputSet.files(@root, catalog)
    validate_manifest_inputs!(inputs)
    input_digest = EncyclopediaInputSet.digest(@root, inputs)
    input_digests = EncyclopediaInputSet.digests(@root, inputs)
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
      "schema_version" => 1,
      "site_id" => config.fetch("site_id"),
      "title" => config.fetch("title"),
      "edition" => config.fetch("edition"),
      "language" => config.fetch("language"),
      "input_digest" => input_digest,
      "chapter_count" => records.length,
      "publishable_count" => publishable_count,
      "counts_by_status" => counts,
      "volumes" => volumes
    }
    navigation = {
      "schema_version" => 1,
      "edition" => config.fetch("edition"),
      "input_digest" => input_digest,
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
    search_index = chapters.select { |chapter| publish_statuses.include?(chapter["status"]) }.map do |chapter|
      search_record(chapter)
    end

    rendered = {
      "catalog.json" => pretty_json(generated_catalog),
      "navigation.json" => pretty_json(navigation),
      "search-index.json" => pretty_json(search_index),
      "README.md" => generated_readme(config, records.length, publishable_count, input_digest)
    }
    output_digests = rendered.each_with_object({}) do |(name, content), memo|
      memo[name] = Digest::SHA256.hexdigest(content)
    end
    manifest = {
      "schema_version" => 1,
      "site_id" => config.fetch("site_id"),
      "edition" => config.fetch("edition"),
      "deterministic" => true,
      "input_digest" => input_digest,
      "input_count" => inputs.length,
      "inputs" => input_digests,
      "outputs" => output_digests,
      "chapter_count" => records.length,
      "publishable_count" => publishable_count,
      "counts_by_status" => counts,
      "registry_entry_count" => registry.fetch("entries").length,
      "registry_verified_at" => registry.fetch("verified_at")
    }
    rendered["publication-manifest.json"] = pretty_json(manifest)
    rendered
  end

  def validate_manifest_inputs!(inputs)
    private_inputs = inputs.select { |relative| relative.start_with?("solutions-private/") }
    raise "private solutions must never enter the publication manifest: #{private_inputs.join(", ")}" unless private_inputs.empty?

    patterns = [
      %r{\A(?:ASSESSMENTS|PROGRESS)\.md\z},
      %r{\A(?:book|curriculum|schemas|scripts|site|versions)/[a-zA-Z0-9._/-]+\z},
      %r{\A(?:examples|labs|exercises)/encyclopedia/[a-zA-Z0-9._/-]+\z},
      %r{\Arecords/encyclopedia/evidence/[a-zA-Z0-9._/-]+\z}
    ]
    inputs.each do |relative|
      issues = @path_policy.validate_regular_file(relative, label: "manifest input #{relative}", patterns: patterns)
      raise issues.join("; ") unless issues.empty?
    end
  end

  def catalog_record(chapter, publish_statuses)
    {
      "id" => chapter.fetch("id"),
      "title" => chapter.fetch("title"),
      "volume" => chapter.fetch("volume"),
      "order" => chapter.fetch("order"),
      "level" => chapter.fetch("level"),
      "status" => chapter.fetch("status"),
      "prerequisites" => catalog_prerequisites(chapter),
      "outcomes" => Array(chapter["outcomes"]),
      "route_tags" => chapter.fetch("route_tags"),
      "stable_core" => chapter.fetch("stable_core"),
      "versioned_surface" => catalog_version_surfaces(chapter),
      "path" => chapter.fetch("path"),
      "publishable" => publish_statuses.include?(chapter.fetch("status"))
    }
  end

  def catalog_prerequisites(chapter)
    Array(chapter["prerequisites"])
  end

  def catalog_version_surfaces(chapter)
    Array(chapter["versioned_surface"])
  end

  def search_record(chapter)
    path = chapter.fetch("path")
    issues = @path_policy.validate_regular_file(
      path,
      label: "published chapter #{chapter.fetch("id")}",
      patterns: [%r{\Abook/volume-[0-9]{2}-[a-z0-9-]+/chapters/v[0-9]{2}\.c[0-9]{2}\.[a-z0-9-]+\.md\z}]
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

    heading = File.foreach(candidates.first, encoding: "UTF-8").first.to_s.strip
    match = heading.match(/\A#\s+卷\s+\d{2}：(.+)\z/)
    raise "volume #{volume} README has an invalid heading" unless match

    match[1]
  end

  def pretty_json(value)
    JSON.pretty_generate(value) + "\n"
  end

  def generated_readme(config, chapter_count, publishable_count, digest)
    <<~MARKDOWN
      # 生成的发布数据

      本目录由 `ruby scripts/build-book.rb` 从 manifest 列出的规范输入确定性生成，请勿手工编辑。

      - 站点：#{config.fetch("title")}
      - 版本：#{config.fetch("edition")}
      - 章节：#{chapter_count}
      - 可发布章节：#{publishable_count}
      - 输入摘要：`#{digest}`

      `planned` 占位不会进入 `search-index.json`；只有 `#{config.fetch("publish_statuses").join(", ")}` 状态可以进入公开搜索数据。答案目录不属于发布输入或输出。
    MARKDOWN
  end

  def check_files(output_relative, files)
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
    raise "temporary backup path already exists" if File.exist?(backup) || File.symlink?(backup)
    files.each { |name, content| File.binwrite(File.join(staging, name), content) }
    File.rename(output, backup) if File.exist?(output)
    begin
      File.rename(staging, output)
      staging = nil
      FileUtils.rm_rf(backup) if File.exist?(backup)
    rescue StandardError
      File.rename(backup, output) if File.exist?(backup) && !File.exist?(output)
      raise
    ensure
      FileUtils.rm_rf(staging) if staging && File.exist?(staging)
    end
    puts "BOOK BUILD OK"
    puts "output=#{output_relative}"
    puts "files=#{files.length}"
    true
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
