# frozen_string_literal: true

require "cgi"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "rbconfig"
require "securerandom"
require "set"

require_relative "complete_plan_builder"

module Publication
  # Renders all 255 chapters from one Pandoc JSON AST. Chapter and volume
  # projections clone only their selected blocks, avoiding the old O(N²)
  # deep-copy of the complete document for every chapter.
  class CompleteRenderer
    PLAN_PATH = CompletePlanBuilder::PLAN_PATH
    PLAN_SCHEMA = CompletePlanBuilder::PLAN_SCHEMA
    OUTPUT_SCHEMA = CompletePlanBuilder::OUTPUT_SCHEMA
    OUTPUT_ROOT = CompletePlanBuilder::OUTPUT_ROOT
    TOOL_IDS = CompletePlanBuilder::REQUIRED_TOOLS
    TEMPLATE = "publication/templates/internal-complete.html5"
    SCREEN_CSS = "publication/styles/internal-complete-screen.css"
    PRINT_CSS = "publication/styles/internal-complete-print.css"
    EPUB_CSS = "publication/styles/internal-complete-epub.css"
    FIXED_ENVIRONMENT = {
      "LANG" => "C.UTF-8",
      "LC_ALL" => "C.UTF-8",
      "PYTHONHASHSEED" => "0",
      "TZ" => "UTC"
    }.freeze
    SAFE_LINK_SCHEMES = %w[http https mailto].freeze
    SAFE_DATA_IMAGE = %r{\Adata:image/(?:png|jpeg|gif|webp);base64,[A-Za-z0-9+/=]+\z}i.freeze
    GENERATED_PREREQUISITE_COMMENT = /\A<!-- (?:BEGIN|END) GENERATED LEARNING PREREQUISITES -->\z/.freeze
    TYPE_PLACEHOLDER_HTML = /\A<(?:[A-Z][A-Za-z0-9]*|redacted)(?:\s*,\s*[A-Z][A-Za-z0-9]*)*>\z/.freeze
    MEDIA_TYPES = {
      "internal" => "application/json",
      "html" => "text/html; charset=utf-8",
      "epub" => "application/epub+zip",
      "pdf" => "application/pdf"
    }.freeze

    attr_reader :root, :loader, :command_runner

    def initialize(root, command_runner: nil, renamer: nil)
      @root = File.realpath(root)
      @loader = ContractLoader.new(@root)
      @command_runner = command_runner || method(:default_command_runner)
      @renamer = renamer || lambda { |source, destination| File.rename(source, destination) }
      @command_records = []
    end

    def build
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @command_records = []
      plan, plan_bytes = load_canonical_plan!
      snapshots = snapshot_inputs(plan)
      tools = observe_tools!(plan)
      environment = FIXED_ENVIRONMENT.merge("SOURCE_DATE_EPOCH" => plan.fetch("source_date_epoch").to_s)
      result = nil
      stage_and_promote do |staging|
        write_file!(File.join(staging, "publication-plan-v2.json"), plan_bytes)
        render_tree!(staging, plan, environment)
        validate_inputs_unchanged!(plan, snapshots)
        manifest = write_output_manifest!(staging, plan, plan_bytes, tools)
        validate_staged_tree!(staging, plan, manifest)
        result = {
          "manifest" => manifest,
          "elapsed_seconds" => elapsed_since(started).round(3),
          "output_root" => OUTPUT_ROOT,
          "manifest_path" => "#{OUTPUT_ROOT}/publication-output-manifest-v2.json"
        }
      end
      result
    end

    # Re-validates an existing internal tree without rendering or mutating it.
    # This is the production integration gate used after a long full build.
    def check
      plan, = load_canonical_plan!
      output = File.join(root, OUTPUT_ROOT)
      stat = File.lstat(output)
      unless stat.directory? && !stat.symlink?
        raise ContractError.new("check", "E_OUTPUT_UNSAFE", "complete publication output must be a regular directory")
      end
      manifest_path = File.join(output, "publication-output-manifest-v2.json")
      manifest_bytes = File.binread(manifest_path)
      manifest = StrictJson.parse(manifest_bytes.dup)
      loader.validate_value!(manifest, OUTPUT_SCHEMA, "#{OUTPUT_ROOT}/publication-output-manifest-v2.json")
      unless manifest_bytes == Canonical.json(manifest).b
        raise ContractError.new("check", "E_MANIFEST_NONCANONICAL", "output manifest bytes are not canonical")
      end
      validate_manifest_summary!(manifest, plan, observed_tools: observe_tools!(plan))
      validate_staged_tree!(output, plan, manifest)
      true
    rescue Errno::ENOENT
      raise ContractError.new("check", "E_OUTPUT_MISSING", "complete publication output is missing")
    rescue JSON::ParserError, StrictJson::DuplicateMemberError => e
      raise ContractError.new("check", "E_MANIFEST_PARSE", e.message.lines.first.to_s.strip)
    end

    private

    def load_canonical_plan!
      absolute = safe_existing_file!(PLAN_PATH)
      plan_bytes = File.binread(absolute)
      plan = StrictJson.parse(plan_bytes.dup)
      loader.validate_value!(plan, PLAN_SCHEMA, PLAN_PATH)
      expected = CompletePlanBuilder.new(root).build
      expected_bytes = Canonical.json(expected).b
      unless plan_bytes == expected_bytes
        raise ContractError.new("plan-validation", "E_PLAN_STALE", "publication plan differs from current canonical inputs", path: PLAN_PATH)
      end
      [plan, plan_bytes]
    rescue JSON::ParserError, StrictJson::DuplicateMemberError => e
      raise ContractError.new("plan-validation", "E_PLAN_PARSE", e.message.lines.first.to_s.strip, path: PLAN_PATH)
    end

    def snapshot_inputs(plan)
      plan.fetch("inputs").each_with_object({}) do |entry, memo|
        path = entry.fetch("path")
        bytes = read_planned_input(path)
        unless bytes.bytesize == entry.fetch("size_bytes") && Canonical.sha256(bytes) == entry.fetch("sha256")
          raise ContractError.new("plan-validation", "E_INPUT_DRIFT", "planned input differs from its digest", path: path)
        end
        reject_canary!(bytes, path)
        memo[path] = bytes
      end
    end

    def read_planned_input(relative)
      validate_relative_path!(relative)
      absolute = File.join(root, relative)
      cursor = root
      relative.split("/").each do |component|
        cursor = File.join(cursor, component)
        if File.symlink?(cursor)
          raise ContractError.new("inventory", "E_PATH_SYMLINK", "planned input path contains a symbolic link", path: relative)
        end
      end
      stat = File.lstat(absolute)
      unless stat.file? && !stat.symlink?
        raise ContractError.new("inventory", "E_PATH_NOT_FILE", "planned input is not a regular file", path: relative)
      end
      flags = File::RDONLY
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      File.open(absolute, flags) do |file|
        opened = file.stat
        unless opened.file? && opened.dev == stat.dev && opened.ino == stat.ino
          raise ContractError.new("inventory", "E_PATH_CHANGED", "planned input changed while opening", path: relative)
        end
        file.binmode
        file.read
      end
    rescue Errno::ENOENT
      raise ContractError.new("inventory", "E_PATH_MISSING", "planned input is missing", path: relative)
    rescue Errno::ELOOP
      raise ContractError.new("inventory", "E_PATH_SYMLINK", "planned input cannot be followed", path: relative)
    end

    def validate_relative_path!(relative)
      unless relative.is_a?(String) && !relative.empty? && !relative.start_with?("/") && !relative.include?("\\")
        raise ContractError.new("schema", "E_PATH_GRAMMAR", "planned input must be a safe relative POSIX path")
      end
      if relative.split("/", -1).any? { |part| part.empty? || part == "." || part == ".." }
        raise ContractError.new("schema", "E_PATH_SEGMENT", "planned input has an unsafe path segment", path: relative)
      end
      if PRIVATE_PATH_PREFIXES.any? { |prefix| relative.start_with?(prefix) }
        raise ContractError.new("inventory", "E_PRIVATE_INPUT", "private inputs are forbidden", path: relative)
      end
    end

    def validate_inputs_unchanged!(plan, snapshots)
      plan.fetch("inputs").each do |entry|
        path = entry.fetch("path")
        next if read_planned_input(path) == snapshots.fetch(path)

        raise ContractError.new("stage-validation", "E_INPUT_CHANGED", "planned input changed during rendering", path: path)
      end
    end

    def observe_tools!(plan)
      requirements = plan.fetch("tool_requirements").each_with_object({}) { |tool, memo| memo[tool.fetch("id")] = tool }
      TOOL_IDS.map do |id|
        requirement = requirements.fetch(id) { raise ContractError.new("tool-preflight", "E_TOOL_MISSING", "required tool is absent from plan") }
        stdout, stderr, exit_code = invoke(requirement.fetch("command"), environment: FIXED_ENVIRONMENT)
        output = combine_output(stdout, stderr)
        unless exit_code == 0 && output.start_with?(requirement.fetch("expected_version_prefix"))
          raise ContractError.new("tool-preflight", "E_TOOL_VERSION", "#{id} version differs from the reviewed toolchain lock")
        end
        {
          "id" => id,
          "version" => output.lines.first.to_s.strip,
          "version_output_sha256" => Canonical.sha256(output)
        }
      end
    end

    def render_tree!(staging, plan, environment)
      work = File.join(staging, ".render-work")
      FileUtils.mkdir_p(work)
      raw_ast = File.join(work, "pandoc-raw.json")
      chapter_paths = plan.fetch("chapters").map { |chapter| chapter.fetch("source_path") }
      run_render_command!(
        "pandoc-parse-canonical-ast",
        ["pandoc", "--sandbox", "--from=markdown+yaml_metadata_block", "--to=json", "--file-scope"] +
          chapter_paths + ["--output", raw_ast],
        environment: environment,
        expected_output: raw_ast
      )
      canonical = canonicalize_ast!(raw_ast, plan)
      ast_path = staged_path(staging, "ast/book.json")
      write_file!(ast_path, Canonical.json(canonical))
      FileUtils.rm_f(raw_ast)

      divisions = canonical_chapter_map(canonical, plan)
      render_indexes!(staging, plan, canonical, divisions)
      write_volume_asts!(staging, plan, canonical, divisions)
      render_whole_and_volume_html!(staging, plan, environment)
      render_epubs!(staging, plan, canonical, divisions, environment)
      render_print_and_pdfs!(staging, plan, canonical, divisions, environment)
      render_chapter_html!(staging, work, plan, canonical, divisions, environment)
    ensure
      FileUtils.rm_rf(work) if work && File.directory?(work) && !File.symlink?(work)
    end

    def canonicalize_ast!(raw_ast_path, plan)
      raw = StrictJson.parse(File.binread(raw_ast_path))
      unless raw.is_a?(Hash) && raw["pandoc-api-version"].is_a?(Array) && raw["blocks"].is_a?(Array)
        raise ContractError.new("ast", "E_AST_SHAPE", "Pandoc JSON has an invalid document shape")
      end
      sanitized = sanitize_sensitive_references(raw)
      normalize_raw_html_literals!(sanitized)
      validate_raw_ast!(sanitized)
      divisions = wrap_chapter_blocks!(sanitized.fetch("blocks"), plan.fetch("chapters"))
      rewrite_publication_links!(divisions, plan)
      append_companion_summaries!(divisions, plan)
      sanitized["meta"] = canonical_metadata(plan, "[内部候选] FactoryCare 编程百科 · 全 255 章")
      sanitized["blocks"] = [notice_block(plan.fetch("notice").fetch("text"))] + divisions
      reject_output_leaks!(Canonical.json(sanitized), phase: "ast", code: "E_AST_LEAK")
      sanitized
    rescue JSON::ParserError, StrictJson::DuplicateMemberError => e
      raise ContractError.new("ast", "E_AST_PARSE", e.message.lines.first.to_s.strip)
    end

    def validate_raw_ast!(document)
      walk_nodes(document) do |node|
        if %w[RawBlock RawInline].include?(node["t"])
          format, raw = node.fetch("c")
          next unless format == "html"
          next if GENERATED_PREREQUISITE_COMMENT.match?(raw.to_s)

          raise ContractError.new("ast", "E_UNSAFE_RAW_HTML", "unreviewed raw HTML is forbidden")
        elsif node["t"] == "Link"
          validate_link_scheme!(node.dig("c", 2, 0).to_s)
        end
      end
    end

    # Markdown treats angle-bracketed generic type names as raw HTML. Preserve
    # their visible spelling as code while allowing only the two generated
    # prerequisite boundary comments to remain raw HTML.
    def normalize_raw_html_literals!(document)
      walk_nodes(document) do |node|
        next unless %w[RawBlock RawInline].include?(node["t"])

        format, raw = node.fetch("c")
        next unless format == "html"
        next if GENERATED_PREREQUISITE_COMMENT.match?(raw.to_s)
        unless TYPE_PLACEHOLDER_HTML.match?(raw.to_s)
          raise ContractError.new("ast", "E_UNSAFE_RAW_HTML", "unreviewed raw HTML is forbidden")
        end

        if node["t"] == "RawInline"
          node["t"] = "Code"
          node["c"] = [["", ["publication-type-placeholder"], []], raw]
        else
          node["t"] = "CodeBlock"
          node["c"] = [["", ["publication-type-placeholder"], []], raw]
        end
      end
      document
    end

    def wrap_chapter_blocks!(blocks, chapters)
      indexes = []
      blocks.each_with_index do |block, index|
        next unless block.is_a?(Hash) && block["t"] == "Header" && block.dig("c", 0) == 1

        expected = chapters[indexes.length]
        next unless expected && normalized_inline_text(block.dig("c", 2)) == normalize_text(expected.fetch("title"))

        indexes << index
      end
      unless indexes.length == chapters.length && indexes.first == 0
        raise ContractError.new("ast", "E_AST_CHAPTER_BOUNDARY", "chapter headings are missing, duplicated, or out of catalog order")
      end
      chapters.each_with_index.map do |chapter, index|
        first = indexes.fetch(index)
        limit = indexes[index + 1] || blocks.length
        section = blocks[first...limit]
        section.first.fetch("c").fetch(1)[0] = chapter.fetch("id")
        {
          "t" => "Div",
          "c" => [
            [chapter.fetch("id"), ["chapter"], [["data-chapter-id", chapter.fetch("id")], ["data-status", chapter.fetch("status")]]],
            section
          ]
        }
      end
    end

    def rewrite_publication_links!(divisions, plan)
      chapter_targets = plan.fetch("chapters").each_with_object({}) do |chapter, memo|
        memo[chapter.fetch("source_path")] = chapter.fetch("id")
      end
      companions = plan.fetch("companions").map { |entry| entry.fetch("path") }.to_set
      divisions.each_with_index do |division, index|
        source_path = plan.fetch("chapters").fetch(index).fetch("source_path")
        walk_nodes(division) do |node|
          if node["t"] == "Image"
            rewrite_image_as_safe_reference!(node)
            next
          end
          next unless node["t"] == "Link"

          target = node.dig("c", 2, 0).to_s
          next if target.start_with?("#")
          scheme = target[/\A([A-Za-z][A-Za-z0-9+.-]*):/, 1]
          next if scheme && SAFE_LINK_SCHEMES.include?(scheme.downcase)

          path_part = target.sub(/[?#].*\z/, "")
          suffix = target.delete_prefix(path_part)
          if path_part.empty? || path_part.start_with?("/") || path_part.include?("%") || path_part.include?("\\")
            replace_link_with_note!(node, "（不安全的本地链接已移除）")
            next
          end
          resolved = Pathname.new(File.dirname(source_path)).join(path_part).cleanpath.to_s
          if resolved == ".." || resolved.start_with?("../") || PRIVATE_PATH_PREFIXES.any? { |prefix| resolved.start_with?(prefix) }
            replace_link_with_note!(node, "（私有或越界链接已移除）")
          elsif chapter_targets.key?(resolved)
            node.fetch("c").fetch(2)[0] = "##{chapter_targets.fetch(resolved)}#{suffix}"
          elsif companions.include?(resolved) || (path_part.end_with?("/") && companions.include?("#{resolved}/README.md"))
            replace_link_with_note!(node, "（配套工件见摘要索引）")
          else
            replace_link_with_note!(node, "（未纳入内部出版输出）")
          end
        end
      end
    end

    def rewrite_image_as_safe_reference!(node)
      target = node.dig("c", 2, 0).to_s
      return if SAFE_DATA_IMAGE.match?(target)

      label = node.dig("c", 1) || []
      scheme = target[/\A([A-Za-z][A-Za-z0-9+.-]*):/, 1]
      if scheme && %w[http https].include?(scheme.downcase)
        node["t"] = "Link"
        node["c"] = [["", ["remote-image-link"], []], label, [target, ""]]
      else
        node["t"] = "Span"
        node["c"] = [["", ["unavailable-local-image"], []], label + note_inlines("（本地图片未内联）")]
      end
    end

    def replace_link_with_note!(node, note)
      label = node.dig("c", 1) || []
      node["t"] = "Span"
      node["c"] = [["", ["unavailable-local-reference"], []], label + note_inlines(note)]
    end

    def note_inlines(note)
      [{ "t" => "Space" }, { "t" => "Str", "c" => note }]
    end

    def append_companion_summaries!(divisions, plan)
      counts = plan.fetch("companions").group_by { |entry| entry.fetch("chapter_id") }
      divisions.each_with_index do |division, index|
        chapter = plan.fetch("chapters").fetch(index)
        count = counts.fetch(chapter.fetch("id"), []).length
        blocks = division.fetch("c").fetch(1)
        blocks << {
          "t" => "Div",
          "c" => [
            ["#{chapter.fetch('id')}-companion-summary", ["companion-summary"], []],
            [{ "t" => "Para", "c" => [
              { "t" => "Strong", "c" => [{ "t" => "Str", "c" => "配套工件索引：" }] },
              { "t" => "Str", "c" => "本章有 #{count} 个 Git 已跟踪公开工件；正文未内联其内容，路径与 SHA-256 见 publication plan 和 companions.json。" }
            ] }]
          ]
        }
      end
    end

    def canonical_chapter_map(canonical, plan)
      result = {}
      canonical.fetch("blocks").each do |block|
        next unless block.is_a?(Hash) && block["t"] == "Div"

        id = block.dig("c", 0, 0)
        result[id] = block if plan.fetch("chapters").any? { |chapter| chapter.fetch("id") == id }
      end
      unless result.length == plan.fetch("chapters").length
        raise ContractError.new("ast", "E_AST_CHAPTER_SET", "canonical AST does not contain every planned chapter exactly once")
      end
      result
    end

    def render_indexes!(staging, plan, canonical, divisions)
      navigation = {
        "schema_version" => 1,
        "profile_id" => plan.fetch("profile_id"),
        "notice" => plan.fetch("notice").fetch("text"),
        "whole_book" => "../html/book.html",
        "volumes" => plan.fetch("volumes").map do |volume|
          {
            "id" => volume.fetch("id"),
            "title" => volume.fetch("title"),
            "href" => "../html/volumes/volume-#{volume.fetch('id')}.html",
            "chapters" => volume.fetch("chapter_ids").map do |id|
              chapter = plan.fetch("chapters").find { |item| item.fetch("id") == id }
              { "id" => id, "title" => chapter.fetch("title"), "status" => chapter.fetch("status"), "href" => "../html/chapters/#{id}.html" }
            end
          }
        end
      }
      search = {
        "schema_version" => 1,
        "profile_id" => plan.fetch("profile_id"),
        "record_count" => plan.fetch("chapters").length,
        "records" => plan.fetch("chapters").map do |chapter|
          text = plain_text(divisions.fetch(chapter.fetch("id")))
          {
            "id" => chapter.fetch("id"),
            "title" => chapter.fetch("title"),
            "volume" => chapter.fetch("volume"),
            "status" => chapter.fetch("status"),
            "href" => "../html/chapters/#{chapter.fetch('id')}.html",
            "text" => text
          }
        end
      }
      companions = {
        "schema_version" => 1,
        "profile_id" => plan.fetch("profile_id"),
        "source" => "git-tracked-only",
        "presentation" => "digest-index-only",
        "record_count" => plan.fetch("companions").length,
        "records" => plan.fetch("companions")
      }
      write_file!(staged_path(staging, "output/index/navigation.json"), Canonical.json(navigation))
      write_file!(staged_path(staging, "output/index/search-index.json"), Canonical.json(search))
      write_file!(staged_path(staging, "output/index/companions.json"), Canonical.json(companions))
      write_file!(staged_path(staging, "output/html/index.html"), landing_html(plan))
      [navigation, search, companions, canonical].each do |value|
        reject_output_leaks!(Canonical.json(value), phase: "index", code: "E_INDEX_LEAK")
      end
    end

    def landing_html(plan)
      volumes = plan.fetch("volumes").map do |volume|
        chapter_links = volume.fetch("chapter_ids").map do |id|
          chapter = plan.fetch("chapters").find { |item| item.fetch("id") == id }
          %(<li><a href="chapters/#{html(id)}.html">#{html(chapter.fetch("title"))}</a> <small>#{html(chapter.fetch("status"))}</small></li>)
        end.join("\n")
        <<~HTML
          <section>
            <h2><a href="volumes/volume-#{html(volume.fetch('id'))}.html">#{html(volume.fetch("title"))}</a></h2>
            <ol>#{chapter_links}</ol>
          </section>
        HTML
      end.join("\n")
      css = File.binread(File.join(root, SCREEN_CSS)).force_encoding(Encoding::UTF_8)
      <<~HTML
        <!doctype html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="robots" content="noindex,nofollow">
          <meta name="description" content="#{html(plan.fetch('notice').fetch('text'))}">
          <title>[内部候选] FactoryCare 编程百科 · 全 255 章</title>
          <style>#{css}</style>
        </head>
        <body>
          <a class="skip-link" href="#main-content">跳到正文</a>
          <header class="site-header"><p class="review-badge">#{html(plan.fetch('notice').fetch('text'))}</p><p class="site-name">FactoryCare 编程百科 · 内部完整候选物</p></header>
          <main id="main-content">
            <h1>FactoryCare 编程百科 · 全 255 章内部导航</h1>
            <div class="publication-summary"><p>共 16 卷、255 章。所有章节仍按目录中的真实状态展示；此页面不构成公开发布或质量门禁通过声明。</p><p><a href="book.html">打开整书 HTML</a></p></div>
            <div class="volume-index">#{volumes}</div>
          </main>
          <footer><p>内部构建候选物；尚未完成人工评审、无障碍与独立复现门禁。</p></footer>
        </body>
        </html>
      HTML
    end

    def write_volume_asts!(staging, plan, canonical, divisions)
      plan.fetch("volumes").each do |volume|
        document = projection_document(canonical, volume.fetch("chapter_ids").map { |id| divisions.fetch(id) })
        document["meta"] = canonical_metadata(plan, "[内部候选] #{volume.fetch('title')}")
        rewrite_volume_links!(document, volume.fetch("chapter_ids"), plan)
        ast = staged_path(staging, "ast/volumes/volume-#{volume.fetch('id')}.json")
        write_file!(ast, Canonical.json(document))
      end
    end

    def render_whole_and_volume_html!(staging, plan, environment)
      ast_path = staged_path(staging, "ast/book.json")
      run_render_command!(
        "pandoc-html-whole-book",
        pandoc_html_command(ast_path, staged_path(staging, "output/html/book.html"), SCREEN_CSS),
        environment: environment,
        expected_output: staged_path(staging, "output/html/book.html")
      )

      plan.fetch("volumes").each do |volume|
        ast = staged_path(staging, "ast/volumes/volume-#{volume.fetch('id')}.json")
        output = staged_path(staging, "output/html/volumes/volume-#{volume.fetch('id')}.html")
        run_render_command!(
          "pandoc-html-volume-#{volume.fetch('id')}",
          pandoc_html_command(ast, output, SCREEN_CSS),
          environment: environment,
          expected_output: output
        )
      end
    end

    def render_chapter_html!(staging, work, plan, canonical, divisions, environment)
      chapters = plan.fetch("chapters")
      chapters.each_with_index do |chapter, index|
        document = projection_document(canonical, [divisions.fetch(chapter.fetch("id"))])
        document["meta"] = canonical_metadata(plan, "[内部候选] #{chapter.fetch('title')}")
        add_chapter_navigation!(document, chapters, index)
        rewrite_chapter_links!(document, chapter.fetch("id"), chapters)
        derived = File.join(work, "chapter-#{chapter.fetch('id')}.json")
        write_file!(derived, Canonical.json(document))
        output = staged_path(staging, "output/html/chapters/#{chapter.fetch('id')}.html")
        run_render_command!(
          "pandoc-html-chapter-#{chapter.fetch('id')}",
          pandoc_html_command(derived, output, SCREEN_CSS),
          environment: environment,
          expected_output: output
        )
        FileUtils.rm_f(derived)
      end
    end

    def render_epubs!(staging, plan, canonical, divisions, environment)
      render_epub_command!(
        "pandoc-epub-whole-book",
        staged_path(staging, "ast/book.json"),
        staged_path(staging, "output/epub/factorycare-internal-complete.epub"),
        environment
      )
      plan.fetch("volumes").each do |volume|
        ast = staged_path(staging, "ast/volumes/volume-#{volume.fetch('id')}.json")
        render_epub_command!(
          "pandoc-epub-volume-#{volume.fetch('id')}",
          ast,
          staged_path(staging, "output/epub/volumes/factorycare-volume-#{volume.fetch('id')}.epub"),
          environment
        )
      end
    end

    def render_epub_command!(id, ast, output, environment)
      run_render_command!(
        id,
        ["pandoc", "--from=json", "--to=epub3", "--standalone", "--css", File.join(root, EPUB_CSS), "--split-level=1", "--output", output, ast],
        environment: environment,
        expected_output: output
      )
    end

    def render_print_and_pdfs!(staging, plan, canonical, divisions, environment)
      # Produce all 16 bounded volume candidates before attempting the much
      # heavier whole-book PDF. A failure remains a failed atomic build.
      plan.fetch("volumes").each do |volume|
        ast = staged_path(staging, "ast/volumes/volume-#{volume.fetch('id')}.json")
        print = staged_path(staging, "intermediate/print/volumes/volume-#{volume.fetch('id')}.html")
        render_print_html!("pandoc-print-volume-#{volume.fetch('id')}", ast, print, environment)
        render_pdf!(
          "weasyprint-pdf-volume-#{volume.fetch('id')}",
          print,
          staged_path(staging, "output/pdf/volumes/factorycare-volume-#{volume.fetch('id')}.pdf"),
          "urn:factorycare:publication:internal-complete:volume-#{volume.fetch('id')}:#{plan.fetch('edition')}",
          environment
        )
      end
      whole_print = staged_path(staging, "intermediate/print/book.html")
      render_print_html!("pandoc-print-whole-book", staged_path(staging, "ast/book.json"), whole_print, environment)
      render_pdf!(
        "weasyprint-pdf-whole-book",
        whole_print,
        staged_path(staging, "output/pdf/factorycare-internal-complete.pdf"),
        "urn:factorycare:publication:internal-complete:#{plan.fetch('edition')}",
        environment
      )
    end

    def render_print_html!(id, ast, output, environment)
      run_render_command!(id, pandoc_html_command(ast, output, PRINT_CSS, toc: false), environment: environment, expected_output: output)
    end

    def render_pdf!(id, input, output, identifier, environment)
      run_render_command!(
        id,
        [
          "dpy", File.join(root, "publication/lib/deterministic_weasyprint.py"),
          "--encoding", "UTF-8", "--media-type", "print", "--pdf-identifier", identifier,
          "--pdf-variant", "pdf/ua-1", "--pdf-tags", "--custom-metadata",
          "--allowed-protocols", "file,data", "--no-http-redirects", "--fail-on-http-errors",
          input, output
        ],
        environment: environment,
        expected_output: output
      )
    end

    def pandoc_html_command(input, output, stylesheet, toc: true)
      command = [
        "pandoc", "--from=json", "--to=html5", "--standalone",
        "--template", File.join(root, TEMPLATE), "--embed-resources", "--css", File.join(root, stylesheet)
      ]
      command.concat(["--toc", "--toc-depth=3"]) if toc
      command.concat(["--output", output, input])
    end

    def projection_document(canonical, divisions)
      notice = canonical.fetch("blocks").first
      {
        "pandoc-api-version" => deep_copy(canonical.fetch("pandoc-api-version")),
        "meta" => deep_copy(canonical.fetch("meta")),
        "blocks" => [deep_copy(notice)] + divisions.map { |division| deep_copy(division) }
      }
    end

    def rewrite_chapter_links!(document, current_id, chapters)
      ids = chapters.map { |chapter| chapter.fetch("id") }
      walk_nodes(document) do |node|
        next unless node["t"] == "Link"

        target = node.dig("c", 2, 0).to_s
        matched = ids.find { |id| target == "##{id}" || target.start_with?("##{id}#") }
        next unless matched && matched != current_id

        suffix = target.delete_prefix("##{matched}")
        node.fetch("c").fetch(2)[0] = "#{matched}.html#{suffix}"
      end
    end

    def rewrite_volume_links!(document, included_ids, plan)
      all_ids = plan.fetch("chapters").map { |chapter| chapter.fetch("id") }
      walk_nodes(document) do |node|
        next unless node["t"] == "Link"

        target = node.dig("c", 2, 0).to_s
        matched = all_ids.find { |id| target == "##{id}" || target.start_with?("##{id}#") }
        replace_link_with_note!(node, "（另卷章节见整书或章节站点）") if matched && !included_ids.include?(matched)
      end
    end

    def add_chapter_navigation!(document, chapters, index)
      meta = document.fetch("meta")
      if index.positive?
        previous = chapters.fetch(index - 1)
        meta["previous-url"] = meta_string("#{previous.fetch('id')}.html")
        meta["previous-title"] = meta_string(previous.fetch("title"))
      end
      if index + 1 < chapters.length
        following = chapters.fetch(index + 1)
        meta["next-url"] = meta_string("#{following.fetch('id')}.html")
        meta["next-title"] = meta_string(following.fetch("title"))
      end
    end

    def canonical_metadata(plan, title)
      timestamp = Time.at(plan.fetch("source_date_epoch")).utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      notice = plan.fetch("notice").fetch("text")
      {
        "date" => meta_string(timestamp),
        "description" => meta_string(notice),
        "identifier" => meta_string("urn:factorycare:publication:internal-complete:#{plan.fetch('edition')}"),
        "lang" => meta_string(plan.fetch("language")),
        "notice" => meta_string(notice),
        "publication-label" => meta_string("FactoryCare 编程百科 · 内部完整候选物"),
        "robots" => meta_string(plan.fetch("notice").fetch("robots")),
        "subtitle" => meta_string(notice),
        "title" => meta_string(title)
      }
    end

    def notice_block(text)
      {
        "t" => "Div",
        "c" => [
          ["publication-notice", ["publication-notice"], [["role", "note"]]],
          [{ "t" => "Para", "c" => [{ "t" => "Strong", "c" => [{ "t" => "Str", "c" => text }] }] }]
        ]
      }
    end

    def meta_string(value)
      { "t" => "MetaString", "c" => value }
    end

    def plain_text(value)
      fragments = []
      collect_inline_text(value, fragments)
      normalize_text(fragments.join(" "))
    end

    def normalized_inline_text(value)
      fragments = []
      collect_inline_text(value, fragments)
      normalize_text(fragments.join)
    end

    def collect_inline_text(value, fragments)
      case value
      when Array
        value.each { |child| collect_inline_text(child, fragments) }
      when Hash
        case value["t"]
        when "Str"
          fragments << value["c"].to_s
        when "Code"
          fragments << value.dig("c", 1).to_s
        when "Space", "SoftBreak", "LineBreak"
          fragments << " "
        else
          value.each_value { |child| collect_inline_text(child, fragments) }
        end
      end
    end

    def normalize_text(value)
      value.to_s.unicode_normalize(:nfc).gsub(/[[:space:]]+/u, " ").strip
    end

    def sanitize_sensitive_references(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, child), memo| memo[key] = sanitize_sensitive_references(child) }
      when Array
        value.map { |child| sanitize_sensitive_references(child) }
      when String
        text = value.gsub(%r{solutions-private(?:/[A-Za-z0-9._/-]*)?}, "[私有答案路径已从候选物移除]")
        text = text.gsub(%r{sources/private(?:/[A-Za-z0-9._/-]*)?}, "[私有来源路径已从候选物移除]")
        text.gsub(%r{/Users/[A-Za-z0-9._-]+(?:/[A-Za-z0-9._ -]+)*}, "[本机绝对路径已从候选物移除]")
      else
        value
      end
    end

    def validate_link_scheme!(target)
      if target.start_with?("//") || target.include?("\\") || target.match?(/javascript\s*:/i)
        raise ContractError.new("ast", "E_UNSAFE_LINK", "link uses an unsafe target form")
      end
      match = target.match(/\A([A-Za-z][A-Za-z0-9+.-]*):/)
      return unless match
      return if SAFE_LINK_SCHEMES.include?(match[1].downcase)

      raise ContractError.new("ast", "E_UNSAFE_LINK", "link uses a forbidden URI scheme")
    end

    def walk_nodes(value, &block)
      case value
      when Hash
        yield value if value.key?("t")
        value.each_value { |child| walk_nodes(child, &block) }
      when Array
        value.each { |child| walk_nodes(child, &block) }
      end
    end

    def deep_copy(value)
      JSON.parse(JSON.generate(value))
    end

    def write_output_manifest!(staging, plan, plan_bytes, tools)
      manifest_relative = "publication-output-manifest-v2.json"
      outputs = plan.fetch("planned_outputs").reject { |output| output.fetch("path") == manifest_relative }.map do |planned|
        path = planned.fetch("path")
        absolute = staged_path(staging, path)
        bytes = File.binread(absolute)
        {
          "path" => path,
          "kind" => planned.fetch("kind"),
          "format" => planned.fetch("format"),
          "media_type" => MEDIA_TYPES.fetch(planned.fetch("format")),
          "distribution" => planned.fetch("distribution"),
          "sha256" => Canonical.sha256(bytes),
          "size_bytes" => bytes.bytesize
        }
      end
      manifest = {
        "schema_version" => 2,
        "manifest_id" => "publication-output.internal-complete",
        "profile_id" => plan.fetch("profile_id"),
        "plan_id" => plan.fetch("plan_id"),
        "plan_sha256" => Canonical.sha256(plan_bytes),
        "build_input_digest" => plan.fetch("build_input_digest"),
        "build_status" => "succeeded",
        "generated_by" => "scripts/build-complete-publication.rb",
        "source_date_epoch" => plan.fetch("source_date_epoch"),
        "environment" => manifest_environment,
        "tools_observed" => tools,
        "commands" => @command_records,
        "output_count" => outputs.length,
        "output_set_digest" => Canonical.path_bytes_digest(outputs, lambda { |path| File.binread(staged_path(staging, path)) }),
        "outputs" => outputs
      }
      loader.validate_value!(manifest, OUTPUT_SCHEMA, "#{OUTPUT_ROOT}/#{manifest_relative}")
      validate_manifest_summary!(manifest, plan, observed_tools: tools)
      bytes = Canonical.json(manifest)
      reject_output_leaks!(bytes, phase: "manifest", code: "E_MANIFEST_LEAK")
      write_file!(staged_path(staging, manifest_relative), bytes)
      manifest
    end

    def validate_staged_tree!(staging, plan, manifest)
      actual = recursive_files(staging)
      expected = (["publication-plan-v2.json"] + plan.fetch("planned_outputs").map { |entry| entry.fetch("path") }).sort
      extra = actual - expected
      missing = expected - actual
      raise ContractError.new("stage-validation", "E_STAGE_EXTRA", "staged tree has an unexpected file", path: extra.first) unless extra.empty?
      raise ContractError.new("stage-validation", "E_STAGE_MISSING", "staged tree is missing a planned file", path: missing.first) unless missing.empty?

      actual.each do |relative|
        absolute = staged_path(staging, relative)
        stat = File.lstat(absolute)
        unless stat.file? && !stat.symlink? && stat.size.positive?
          raise ContractError.new("stage-validation", "E_STAGE_UNSAFE", "staged output must be a non-empty regular file", path: relative)
        end
        reject_output_leaks!(File.binread(absolute), phase: "stage-validation", code: "E_OUTPUT_LEAK")
      end
      validate_html_outputs!(staging, plan)
      validate_binary_outputs!(staging, plan)
      validate_manifest_digests!(staging, plan, manifest)
    end

    def recursive_files(staging)
      Dir.glob(File.join(staging, "**", "*"), File::FNM_DOTMATCH).sort.each_with_object([]) do |path, memo|
        relative = path.delete_prefix(staging + File::SEPARATOR)
        next if relative.split("/").any? { |segment| segment == "." || segment == ".." }
        stat = File.lstat(path)
        raise ContractError.new("stage-validation", "E_STAGE_SYMLINK", "staged tree contains a symbolic link", path: relative) if stat.symlink?
        memo << relative if stat.file?
      end
    end

    def validate_html_outputs!(staging, plan)
      html_paths = plan.fetch("planned_outputs").select { |output| output.fetch("format") == "html" }.map { |output| output.fetch("path") }
      cache = {}
      html_paths.each do |relative|
        bytes = File.binread(staged_path(staging, relative))
        text = bytes.dup.force_encoding(Encoding::UTF_8)
        unless text.valid_encoding? && text.match?(/<!doctype html>/i) && text.match?(/<html\s+lang="zh-CN">/i) &&
               text.include?("noindex,nofollow") && text.include?("id=\"main-content\"") && !text.match?(/<script\b/i)
          raise ContractError.new("stage-validation", "E_HTML_CONTRACT", "HTML output failed the fixed internal contract", path: relative)
        end
        ids = text.scan(/\sid="([^"]+)"/i).flatten
        duplicate = ids.group_by(&:itself).find { |_id, values| values.length > 1 }
        raise ContractError.new("stage-validation", "E_HTML_DUPLICATE_ID", "HTML contains a duplicate id", path: relative) if duplicate
        cache[relative] = { "text" => text, "ids" => ids.to_set }
      end
      cache.each do |relative, document|
        document.fetch("text").scan(/\shref="([^"]+)"/i).flatten.each do |target|
          validate_html_link!(target, relative, cache)
        end
      end
    end

    def validate_html_link!(target, source, cache)
      return if target.start_with?("mailto:") || target.match?(/\Ahttps?:/i)
      if target.start_with?("#")
        fragment = target.delete_prefix("#")
        unless cache.fetch(source).fetch("ids").include?(fragment)
          raise ContractError.new("stage-validation", "E_HTML_BROKEN_LINK", "HTML fragment target is missing", path: source)
        end
        return
      end
      path_part, fragment = target.split("#", 2)
      resolved = Pathname.new(File.dirname(source)).join(CGI.unescapeHTML(path_part)).cleanpath.to_s
      target_document = cache[resolved]
      unless target_document
        raise ContractError.new("stage-validation", "E_HTML_BROKEN_LINK", "HTML local target is missing", path: source)
      end
      return unless fragment
      unless target_document.fetch("ids").include?(CGI.unescapeHTML(fragment))
        raise ContractError.new("stage-validation", "E_HTML_BROKEN_LINK", "HTML cross-page fragment is missing", path: source)
      end
    end

    def validate_binary_outputs!(staging, plan)
      plan.fetch("planned_outputs").select { |output| output.fetch("format") == "epub" }.each do |output|
        bytes = File.binread(staged_path(staging, output.fetch("path")))
        raise ContractError.new("stage-validation", "E_EPUB_SIGNATURE", "EPUB has no ZIP signature", path: output.fetch("path")) unless bytes.start_with?("PK".b)
      end
      plan.fetch("planned_outputs").select { |output| output.fetch("format") == "pdf" }.each do |output|
        bytes = File.binread(staged_path(staging, output.fetch("path")))
        tail = bytes.bytesize > 2048 ? bytes.byteslice(-2048, 2048) : bytes
        unless bytes.start_with?("%PDF-".b) && tail.include?("%%EOF")
          raise ContractError.new("stage-validation", "E_PDF_SIGNATURE", "PDF candidate has an invalid signature", path: output.fetch("path"))
        end
      end
    end

    def validate_manifest_digests!(staging, plan, manifest)
      planned = plan.fetch("planned_outputs").reject { |output| output.fetch("kind") == "output-manifest" }
      plan_bytes = File.binread(staged_path(staging, "publication-plan-v2.json"))
      unless manifest.fetch("plan_sha256") == Canonical.sha256(plan_bytes) &&
             manifest.fetch("build_input_digest") == plan.fetch("build_input_digest")
        raise ContractError.new("stage-validation", "E_MANIFEST_PLAN", "manifest does not bind the staged plan and build inputs")
      end
      actual_projection = manifest.fetch("outputs").map do |output|
        output.slice("path", "kind", "format", "distribution")
      end
      unless actual_projection == planned
        raise ContractError.new("stage-validation", "E_MANIFEST_OUTPUT_SET", "manifest output contract differs from the plan")
      end
      manifest.fetch("outputs").each do |entry|
        unless entry.fetch("media_type") == MEDIA_TYPES.fetch(entry.fetch("format"))
          raise ContractError.new("stage-validation", "E_MANIFEST_MEDIA_TYPE", "manifest media type differs from the fixed format mapping", path: entry.fetch("path"))
        end
        bytes = File.binread(staged_path(staging, entry.fetch("path")))
        unless bytes.bytesize == entry.fetch("size_bytes") && Canonical.sha256(bytes) == entry.fetch("sha256")
          raise ContractError.new("stage-validation", "E_MANIFEST_DIGEST", "manifest output digest differs from staged bytes", path: entry.fetch("path"))
        end
      end
      expected_set_digest = Canonical.path_bytes_digest(
        manifest.fetch("outputs"),
        lambda { |path| File.binread(staged_path(staging, path)) }
      )
      unless manifest.fetch("output_set_digest") == expected_set_digest
        raise ContractError.new("stage-validation", "E_MANIFEST_SET_DIGEST", "manifest output-set digest differs from staged bytes")
      end
    end

    def validate_manifest_summary!(manifest, plan, observed_tools:)
      unless manifest.fetch("tools_observed") == observed_tools
        raise ContractError.new("stage-validation", "E_MANIFEST_TOOLS", "manifest tool observations differ from the current fixed toolchain")
      end
      unless manifest.fetch("environment") == manifest_environment
        raise ContractError.new("stage-validation", "E_MANIFEST_ENVIRONMENT", "manifest environment differs from the fixed local observation")
      end
      unless manifest.fetch("output_count") == manifest.fetch("outputs").length
        raise ContractError.new("stage-validation", "E_MANIFEST_OUTPUT_COUNT", "manifest output_count differs from its output records")
      end
      command_ids = manifest.fetch("commands").map { |command| command.fetch("id") }
      unless command_ids == expected_command_ids(plan)
        raise ContractError.new("stage-validation", "E_MANIFEST_COMMAND_SET", "manifest commands differ from the fixed complete render sequence")
      end
      true
    end

    def manifest_environment
      {
        "os" => RbConfig::CONFIG.fetch("host_os"),
        "arch" => RbConfig::CONFIG.fetch("host_cpu"),
        "locale" => "C.UTF-8",
        "timezone" => "UTC",
        "network_policy" => "forbidden",
        "network_isolation" => "not-os-enforced"
      }
    end

    def expected_command_ids(plan)
      ids = ["pandoc-parse-canonical-ast", "pandoc-html-whole-book"]
      ids.concat(plan.fetch("volumes").map { |volume| "pandoc-html-volume-#{volume.fetch('id')}" })
      ids << "pandoc-epub-whole-book"
      ids.concat(plan.fetch("volumes").map { |volume| "pandoc-epub-volume-#{volume.fetch('id')}" })
      plan.fetch("volumes").each do |volume|
        ids << "pandoc-print-volume-#{volume.fetch('id')}"
        ids << "weasyprint-pdf-volume-#{volume.fetch('id')}"
      end
      ids.concat(%w[pandoc-print-whole-book weasyprint-pdf-whole-book])
      ids.concat(plan.fetch("chapters").map { |chapter| "pandoc-html-chapter-#{chapter.fetch('id')}" })
      ids
    end

    def run_render_command!(id, argv, environment:, expected_output:)
      FileUtils.mkdir_p(File.dirname(expected_output))
      stdout, stderr, exit_code = invoke(argv, environment: environment)
      unless exit_code == 0
        # Preserve a bounded traceback so a failed long-running volume render
        # remains diagnosable without leaking an unbounded tool log.
        detail = combine_output(stdout, stderr).lines.first(80).join.strip
        raise ContractError.new("render", "E_COMMAND_FAILED", "#{id} failed#{detail.empty? ? '' : ": #{detail}"}")
      end
      unless File.file?(expected_output) && !File.symlink?(expected_output) && File.size(expected_output).positive?
        raise ContractError.new("render", "E_OUTPUT_MISSING", "#{id} did not create a non-empty regular output")
      end
      @command_records << {
        "id" => id,
        "argv" => logical_argv(argv),
        "exit_code" => 0
      }
    end

    def invoke(argv, environment:)
      result = command_runner.call(environment, argv, root)
      if result.is_a?(Array) && result.length == 3
        stdout, stderr, status = result
        code = status.respond_to?(:exitstatus) ? status.exitstatus : status.to_i
        [stdout.to_s.b, stderr.to_s.b, code]
      else
        raise ContractError.new("render", "E_RUNNER_RESULT", "command runner returned an invalid result")
      end
    rescue Errno::ENOENT
      raise ContractError.new("tool-preflight", "E_TOOL_NOT_FOUND", "required command is not available")
    end

    def default_command_runner(environment, argv, working_directory)
      Open3.capture3(environment, *argv, chdir: working_directory)
    end

    def logical_argv(argv)
      argv.map do |value|
        logical = value.to_s.gsub(root, "<repo>")
        logical.gsub(%r{<repo>/build/publication/\.internal-complete\.stage-[^/]+}, "<stage>")
      end
    end

    def combine_output(stdout, stderr)
      [stdout, stderr].reject(&:empty?).join("\n").b
    end

    def stage_and_promote
      parent = publication_parent!
      output = File.join(root, OUTPUT_ROOT)
      token = "#{$$}-#{SecureRandom.hex(6)}"
      staging = File.join(parent, ".internal-complete.stage-#{token}")
      backup = File.join(parent, ".internal-complete.backup-#{token}")
      [staging, backup].each do |path|
        raise ContractError.new("commit", "E_TEMP_EXISTS", "temporary publication path already exists") if File.exist?(path) || File.symlink?(path)
      end
      Dir.mkdir(staging, 0o755)
      backup_created = false
      promoted = false
      begin
        yield staging
        if File.exist?(output) || File.symlink?(output)
          stat = File.lstat(output)
          raise ContractError.new("commit", "E_OUTPUT_SYMLINK", "existing output cannot be a symbolic link") if stat.symlink?
          raise ContractError.new("commit", "E_OUTPUT_NOT_DIRECTORY", "existing output must be a directory") unless stat.directory?
          @renamer.call(output, backup)
          backup_created = true
        end
        begin
          @renamer.call(staging, output)
          promoted = true
        rescue StandardError => e
          @renamer.call(backup, output) if backup_created && !File.exist?(output)
          backup_created = false if File.exist?(output)
          raise ContractError.new("commit", "E_ATOMIC_PROMOTION", "publication promotion failed (#{e.class})")
        end
        File.open(parent, File::RDONLY) { |directory| directory.fsync }
        FileUtils.rm_rf(backup) if backup_created && File.directory?(backup) && !File.symlink?(backup)
      ensure
        FileUtils.rm_rf(staging) if !promoted && File.directory?(staging) && !File.symlink?(staging)
      end
    end

    def publication_parent!
      cursor = root
      %w[build publication].each do |component|
        cursor = File.join(cursor, component)
        if File.exist?(cursor) || File.symlink?(cursor)
          stat = File.lstat(cursor)
          raise ContractError.new("commit", "E_OUTPUT_SYMLINK", "publication parent contains a symbolic link") if stat.symlink?
          raise ContractError.new("commit", "E_OUTPUT_NOT_DIRECTORY", "publication parent component is not a directory") unless stat.directory?
        else
          Dir.mkdir(cursor, 0o755)
        end
      end
      cursor
    end

    def staged_path(staging, relative)
      unless relative.is_a?(String) && relative.match?(/\A[a-zA-Z0-9][a-zA-Z0-9._-]*(?:\/[a-zA-Z0-9_][a-zA-Z0-9._-]*)*\z/)
        raise ContractError.new("stage-validation", "E_OUTPUT_PATH", "planned output path is unsafe")
      end
      File.join(staging, relative)
    end

    def write_file!(path, bytes)
      FileUtils.mkdir_p(File.dirname(path))
      if File.exist?(path) || File.symlink?(path)
        raise ContractError.new("render", "E_OUTPUT_EXISTS", "renderer refuses to overwrite a staged path")
      end
      File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o644) do |file|
        file.binmode
        file.write(bytes)
      end
    end

    def safe_existing_file!(relative)
      validate_relative_path!(relative)
      absolute = File.join(root, relative)
      stat = File.lstat(absolute)
      unless stat.file? && !stat.symlink?
        raise ContractError.new("plan-validation", "E_PLAN_UNSAFE", "plan must be a regular file", path: relative)
      end
      absolute
    rescue Errno::ENOENT
      raise ContractError.new("plan-validation", "E_PLAN_MISSING", "publication plan is missing", path: relative)
    end

    def reject_canary!(bytes, path)
      return unless bytes.match?(PRIVATE_CANARY_PATTERN)

      raise ContractError.new("inventory", "E_PRIVATE_CANARY", "private canary detected in a publication input", path: path)
    end

    def reject_output_leaks!(bytes, phase:, code:)
      text = bytes.to_s.b
      leaked = PRIVATE_PATH_PREFIXES.any? { |prefix| text.include?(prefix.b) } ||
               PRIVATE_CANARY_PATTERN.match?(text) || text.include?(root.b) || text.match?(%r{/Users/[A-Za-z0-9._-]+/})
      raise ContractError.new(phase, code, "publication output contains a private or machine-absolute path marker") if leaked
    end

    def html(value)
      CGI.escapeHTML(value.to_s)
    end

    def elapsed_since(started)
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    end
  end
end
