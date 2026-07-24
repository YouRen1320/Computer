# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "rbconfig"
require "securerandom"

require_relative "contract"
require_relative "plan_builder"

module Publication
  # Renders the fixed P3 gold publication plan. Markdown is admitted only by
  # the single Pandoc-to-JSON command; every format writer receives that JSON
  # AST or a deterministic chapter projection derived from it.
  class Renderer
    PLAN_PATH = "build/publication/p3-gold/publication-plan.json"
    PROFILE_ID = "p3-gold"
    OUTPUT_ROOT = "build/publication/p3-gold"
    GOLD_IDS = P3_GOLD_IDS.freeze
    TOOL_IDS = %w[pandoc python ruby weasyprint].freeze
    RENDERER_INPUTS = %w[
      publication/lib/deterministic_weasyprint.py
      publication/templates/p3-gold.html5
      publication/styles/p3-gold-screen.css
      publication/styles/p3-gold-print.css
      publication/styles/p3-gold-epub.css
    ].freeze
    SAFE_LINK_SCHEMES = %w[http https mailto].freeze
    SAFE_DATA_IMAGE = %r{\Adata:image/(?:png|jpeg|gif|webp);base64,[A-Za-z0-9+/=]+\z}i.freeze
    FIXED_ENVIRONMENT = {
      "LANG" => "C.UTF-8",
      "LC_ALL" => "C.UTF-8",
      "PYTHONHASHSEED" => "0",
      "TZ" => "UTC"
    }.freeze
    MEDIA_TYPES = {
      "canonical-ast" => "application/json",
      "chapter-html" => "text/html; charset=utf-8",
      "epub" => "application/epub+zip",
      "html-index" => "text/html; charset=utf-8",
      "pdf-candidate" => "application/pdf",
      "print-html" => "text/html; charset=utf-8"
    }.freeze

    attr_reader :root, :loader, :guard, :command_runner

    def initialize(root, command_runner: nil, renamer: nil)
      @root = File.realpath(root)
      @loader = ContractLoader.new(@root)
      @guard = loader.guard
      @command_runner = command_runner || method(:default_command_runner)
      @renamer = renamer || lambda { |source, destination| File.rename(source, destination) }
      @command_records = []
    end

    def build
      @command_records = []
      plan, plan_bytes, snapshots = load_and_validate_plan!
      validate_exact_plan_input_set!(plan)
      renderer_snapshots = validate_renderer_inputs!(snapshots)
      tools = observe_tools!(plan)
      environment = FIXED_ENVIRONMENT.merge("SOURCE_DATE_EPOCH" => plan.fetch("source_date_epoch").to_s)

      result = nil
      stage_and_promote(plan.fetch("profile_id")) do |staging|
        write_file!(File.join(staging, "publication-plan.json"), plan_bytes)
        render_tree!(staging, plan, snapshots, environment)
        validate_renderer_inputs_unchanged!(renderer_snapshots)
        validate_plan_inputs_unchanged!(plan, snapshots)
        result = write_output_manifest!(staging, plan, plan_bytes, tools)
        validate_staged_tree!(staging, plan)
      end
      result.merge("manifest_path" => File.join(OUTPUT_ROOT, "publication-output-manifest.json"))
    end

    private

    def load_and_validate_plan!
      plan_bytes, = guard.read(PLAN_PATH, label: "publication plan", patterns: [exact(PLAN_PATH)])
      # StrictJson validates UTF-8 by changing the supplied String's encoding.
      # Keep the frozen byte snapshot binary so byte-exact plan checks remain
      # independent of Ruby's cross-encoding equality rules.
      plan = StrictJson.parse(plan_bytes.dup)
      loader.validate_value!(plan, PLAN_SCHEMA, PLAN_PATH)
      unless plan_bytes == Canonical.json(plan).b
        raise ContractError.new("plan-validation", "E_PLAN_NONCANONICAL", "publication plan bytes are not canonical")
      end
      validate_plan_summary!(plan)
      snapshots = validate_plan_inputs!(plan)
      validate_plan_cross_references!(plan, snapshots)
      [plan, plan_bytes, snapshots]
    rescue JSON::ParserError, StrictJson::DuplicateMemberError => e
      raise ContractError.new("plan-validation", "E_PLAN_PARSE", e.message.lines.first.to_s.strip, path: PLAN_PATH)
    end

    def validate_plan_summary!(plan)
      fixed = {
        "schema_version" => 1,
        "plan_id" => "publication-plan.p3-gold",
        "profile_id" => PROFILE_ID,
        "publication_mode" => "internal-preview",
        "visibility" => "internal",
        "distribution_allowed" => false,
        "deterministic" => true,
        "output_root" => OUTPUT_ROOT,
        "language" => "zh-CN",
        "digest_algorithm" => DIGEST_ALGORITHM
      }
      fixed.each do |field, expected|
        next if plan.fetch(field) == expected

        raise ContractError.new("plan-validation", "E_PLAN_SUMMARY", "#{field} differs from the fixed p3-gold contract")
      end
      unless plan.fetch("chapters").map { |chapter| chapter.fetch("id") } == GOLD_IDS
        raise ContractError.new("plan-validation", "E_PLAN_CHAPTERS", "plan must contain the exact ordered p3-gold chapter set")
      end
      unless plan.fetch("resource_policy") == {
        "allowed_local_schemes" => %w[file data],
        "build_network" => "forbidden",
        "remote_resources" => "link-only"
      }
        raise ContractError.new("plan-validation", "E_PLAN_RESOURCE_POLICY", "plan resource policy is not the fixed offline policy")
      end
      security = plan.fetch("security")
      unless security.values.all? { |value| value == 0 }
        raise ContractError.new("plan-validation", "E_PLAN_SECURITY", "plan security counters must all be zero")
      end
      unless plan.fetch("planned_outputs") == expected_planned_outputs
        raise ContractError.new("plan-validation", "E_PLAN_OUTPUT_SET", "planned output set differs from the fixed p3-gold contract")
      end

      serialized = Canonical.json(plan)
      reject_private_or_absolute!(serialized, phase: "plan-validation", code: "E_PLAN_LEAK")
    end

    def validate_plan_inputs!(plan)
      entries = plan.fetch("inputs")
      unless entries.length == plan.fetch("input_count") && entries.map { |entry| entry.fetch("path") }.uniq.length == entries.length
        raise ContractError.new("plan-validation", "E_INPUT_SET", "plan input count or uniqueness is invalid")
      end

      snapshots = {}
      entries.each do |entry|
        path = entry.fetch("path")
        reject_private_input_path!(path)
        bytes, = guard.read(path, label: "planned publication input", patterns: [exact(path)])
        reject_canary!(bytes, path)
        unless bytes.bytesize == entry.fetch("size_bytes")
          raise ContractError.new("plan-validation", "E_INPUT_SIZE", "planned input size has drifted", path: path)
        end
        unless Canonical.sha256(bytes) == entry.fetch("sha256")
          raise ContractError.new("plan-validation", "E_INPUT_DIGEST", "planned input digest has drifted", path: path)
        end
        snapshots[path] = bytes
      end

      content = entries.select { |entry| entry.fetch("scope") == "content" }
      publisher = entries.select { |entry| entry.fetch("scope") == "publisher-contract" }
      compare_digest!(plan, "content_input_digest", content, snapshots)
      compare_digest!(plan, "publisher_input_digest", publisher, snapshots)
      compare_digest!(plan, "build_input_digest", entries, snapshots)
      snapshots
    end

    def validate_plan_cross_references!(plan, snapshots)
      plan.fetch("chapters").each do |chapter|
        source_path = chapter.fetch("source_path")
        source_bytes = snapshots.fetch(source_path) do
          raise ContractError.new("plan-validation", "E_CHAPTER_INPUT", "chapter source is absent from plan inputs", path: source_path)
        end
        unless Canonical.sha256(source_bytes) == chapter.fetch("source_sha256")
          raise ContractError.new("plan-validation", "E_CHAPTER_DIGEST", "chapter summary digest differs from its input entry", path: source_path)
        end
        chapter.fetch("artifacts").each do |artifact|
          path = artifact.fetch("source_path")
          bytes = snapshots.fetch(path) do
            raise ContractError.new("plan-validation", "E_ARTIFACT_INPUT", "artifact is absent from plan inputs", path: path)
          end
          unless bytes.bytesize == artifact.fetch("size_bytes") && Canonical.sha256(bytes) == artifact.fetch("sha256")
            raise ContractError.new("plan-validation", "E_ARTIFACT_DIGEST", "artifact summary differs from its input entry", path: path)
          end
        end
      end
    end

    def validate_exact_plan_input_set!(plan)
      entries = plan.fetch("inputs")
      content_entries = entries.select { |entry| entry.fetch("scope") == "content" }
      publisher_entries = entries.select { |entry| entry.fetch("scope") == "publisher-contract" }

      expected_content = plan.fetch("chapters").flat_map do |chapter|
        [chapter.fetch("source_path")] + chapter.fetch("artifacts").map { |artifact| artifact.fetch("source_path") }
      end.sort
      actual_content = content_entries.map { |entry| entry.fetch("path") }.sort
      unless actual_content == expected_content
        raise ContractError.new(
          "plan-validation",
          "E_CONTENT_INPUT_SET",
          "content inputs must exactly match the four chapter sources and their declared public artifacts"
        )
      end

      fixed_publisher = (
        SCHEMA_PATHS +
        PlanBuilder::IMPLEMENTATION_INPUTS +
        [
          plan.fetch("profile").fetch("path"),
          plan.fetch("catalog").fetch("path"),
          plan.fetch("p2_baseline").fetch("manifest_path"),
          plan.fetch("toolchain_lock").fetch("path")
        ] +
        plan.fetch("chapters").map { |chapter| chapter.fetch("public_artifact_manifest").fetch("path") }
      ).uniq.sort
      metadata = publisher_entries.select { |entry| entry.fetch("role") == "repository-metadata" }
      metadata_paths = metadata.map { |entry| entry.fetch("path") }.sort
      unless metadata_paths.length == 4
        raise ContractError.new(
          "plan-validation",
          "E_METADATA_INPUT_SET",
          "publisher inputs must contain the four explicitly declared repository metadata files"
        )
      end
      metadata_paths.each do |path|
        pattern = %r{\A(?:examples|labs|exercises)/encyclopedia/(?:#{GOLD_IDS.map { |id| Regexp.escape(id) }.join('|')})/\.gitignore\z}
        unless pattern.match?(path)
          raise ContractError.new(
            "plan-validation",
            "E_METADATA_INPUT_SET",
            "repository metadata input is outside the fixed gold chapter roots",
            path: path
          )
        end
      end

      expected_publisher = (fixed_publisher + metadata_paths).sort
      actual_publisher = publisher_entries.map { |entry| entry.fetch("path") }.sort
      unless actual_publisher == expected_publisher
        raise ContractError.new(
          "plan-validation",
          "E_PUBLISHER_INPUT_SET",
          "publisher inputs differ from the fixed schemas, implementation, contracts, and metadata set"
        )
      end
      unless entries.length == expected_content.length + expected_publisher.length
        raise ContractError.new("plan-validation", "E_INPUT_SET", "publication input count differs from the exact fixed set")
      end
    end

    def validate_renderer_inputs!(plan_snapshots)
      missing = PlanBuilder::IMPLEMENTATION_INPUTS.reject { |path| plan_snapshots.key?(path) }
      unless missing.empty?
        raise ContractError.new(
          "renderer-preflight",
          "E_RENDERER_INPUT_UNPLANNED",
          "renderer implementation input is absent from the signed plan",
          path: missing.first
        )
      end

      RENDERER_INPUTS.each_with_object({}) do |path, memo|
        unless plan_snapshots.key?(path)
          raise ContractError.new(
            "renderer-preflight",
            "E_RENDERER_INPUT_UNPLANNED",
            "renderer presentation input is absent from the signed plan",
            path: path
          )
        end
        bytes, = guard.read(path, label: "fixed renderer input", patterns: [exact(path)])
        unless bytes == plan_snapshots.fetch(path)
          raise ContractError.new(
            "renderer-preflight",
            "E_RENDERER_INPUT_CHANGED",
            "renderer presentation input differs from the signed plan",
            path: path
          )
        end
        reject_canary!(bytes, path)
        reject_private_or_absolute!(bytes, phase: "renderer-preflight", code: "E_RENDERER_INPUT_LEAK")
        if bytes.match?(/(?:url\s*\(|@import\s+|(?:src|href)\s*=\s*["'])\s*https?:/i)
          raise ContractError.new("renderer-preflight", "E_REMOTE_RENDERER_INPUT", "renderer inputs may not load remote resources", path: path)
        end
        memo[path] = bytes
      end
    end

    def validate_renderer_inputs_unchanged!(snapshots)
      snapshots.each do |path, expected|
        actual, = guard.read(path, label: "fixed renderer input", patterns: [exact(path)])
        next if actual == expected

        raise ContractError.new("stage-validation", "E_RENDERER_INPUT_CHANGED", "renderer input changed during build", path: path)
      end
    end

    def validate_plan_inputs_unchanged!(plan, snapshots)
      plan.fetch("inputs").each do |entry|
        path = entry.fetch("path")
        actual, = guard.read(path, label: "planned publication input", patterns: [exact(path)])
        next if actual == snapshots.fetch(path)

        raise ContractError.new("stage-validation", "E_INPUT_CHANGED", "planned input changed during build", path: path)
      end
    end

    def observe_tools!(plan)
      requirements = plan.fetch("tool_requirements").each_with_object({}) do |tool, memo|
        memo[tool.fetch("id")] = tool
      end
      TOOL_IDS.sort.map do |id|
        tool = requirements.fetch(id) do
          raise ContractError.new("tool-preflight", "E_TOOL_MISSING", "required R2 tool is absent from the plan")
        end
        unless tool.fetch("state") == "observed-current" && tool.key?("expected_version_prefix")
          raise ContractError.new("tool-preflight", "E_TOOL_STATE", "required R2 tool is not observed-current")
        end
        stdout, stderr, exit_code = invoke(tool.fetch("command"), environment: FIXED_ENVIRONMENT)
        output = combine_output(stdout, stderr)
        unless exit_code == 0 && output.start_with?(tool.fetch("expected_version_prefix"))
          raise ContractError.new("tool-preflight", "E_TOOL_VERSION", "required R2 tool version does not match the plan lock")
        end
        {
          "id" => id,
          "version" => output.lines.first.to_s.strip,
          "version_output_sha256" => Canonical.sha256(output)
        }
      end
    end

    def render_tree!(staging, plan, snapshots, environment)
      work = File.join(staging, ".render-work")
      FileUtils.mkdir_p(work)
      ast_path = staged_path(staging, output_for(plan, "canonical-ast").fetch("path"))
      raw_ast_path = File.join(work, "pandoc-raw.json")
      chapter_paths = plan.fetch("chapters").map { |chapter| chapter.fetch("source_path") }

      run_render_command!(
        "pandoc-parse-canonical-ast",
        ["pandoc", "--sandbox", "--from=markdown+yaml_metadata_block", "--to=json", "--file-scope"] +
          chapter_paths + ["--output", raw_ast_path],
        environment: environment,
        expected_output: raw_ast_path
      )
      canonical_document = canonicalize_ast!(raw_ast_path, plan, snapshots)
      write_file!(ast_path, Canonical.json(canonical_document))
      FileUtils.rm_f(raw_ast_path)

      render_html_index!(staging, plan, ast_path, environment)
      render_chapter_html!(staging, work, plan, canonical_document, environment)
      render_epub!(staging, plan, ast_path, environment)
      print_path = render_print_html!(staging, plan, ast_path, environment)
      render_pdf!(staging, plan, print_path, environment)
      validate_rendered_outputs!(staging, plan)
      FileUtils.rm_rf(work)
    ensure
      FileUtils.rm_rf(work) if work && File.directory?(work) && !File.symlink?(work)
    end

    def canonicalize_ast!(raw_ast_path, plan, snapshots)
      raw = StrictJson.parse(File.binread(raw_ast_path))
      unless raw.is_a?(Hash) && raw["pandoc-api-version"].is_a?(Array) && raw["blocks"].is_a?(Array)
        raise ContractError.new("ast", "E_AST_SHAPE", "Pandoc JSON output has an invalid document shape")
      end
      validate_ast_safety!(raw)
      sanitized = sanitize_private_references(raw)
      chapters = wrap_chapter_blocks!(sanitized.fetch("blocks"), plan.fetch("chapters"))
      rewrite_publication_links!(chapters, plan.fetch("chapters"))
      append_public_artifacts!(chapters, plan.fetch("chapters"), snapshots)
      sanitized["meta"] = canonical_metadata(plan)
      sanitized["blocks"] = [notice_block(plan.fetch("notice").fetch("text"))] + chapters
      bytes = Canonical.json(sanitized)
      reject_private_or_absolute!(bytes, phase: "ast", code: "E_AST_LEAK")
      sanitized
    rescue JSON::ParserError, StrictJson::DuplicateMemberError => e
      raise ContractError.new("ast", "E_AST_PARSE", e.message.lines.first.to_s.strip)
    end

    def wrap_chapter_blocks!(blocks, chapters)
      header_indexes = []
      blocks.each_with_index do |block, index|
        next unless block.is_a?(Hash) && block["t"] == "Header" && block.dig("c", 0) == 1

        title = normalized_inline_text(block.dig("c", 2))
        expected = chapters[header_indexes.length]
        next unless expected && title == normalize_text(expected.fetch("title"))

        header_indexes << index
      end
      unless header_indexes.length == chapters.length && header_indexes.first == 0
        raise ContractError.new("ast", "E_AST_CHAPTER_BOUNDARY", "canonical chapter headings are missing or out of order")
      end

      chapters.each_with_index.map do |chapter, index|
        first = header_indexes.fetch(index)
        limit = header_indexes[index + 1] || blocks.length
        section = blocks[first...limit]
        section.first.fetch("c").fetch(1)[0] = chapter.fetch("id")
        {
          "t" => "Div",
          "c" => [
            [chapter.fetch("id"), ["chapter"], [["data-chapter-id", chapter.fetch("id")]]],
            section
          ]
        }
      end
    end

    def render_html_index!(staging, plan, ast_path, environment)
      output = output_for(plan, "html-index")
      path = staged_path(staging, output.fetch("path"))
      run_render_command!(
        "pandoc-html-index",
        pandoc_html_command(ast_path, path, "publication/styles/p3-gold-screen.css"),
        environment: environment,
        expected_output: path
      )
    end

    def render_chapter_html!(staging, work, plan, canonical_document, environment)
      chapters = plan.fetch("chapters")
      chapters.each_with_index do |chapter, index|
        document = chapter_document(canonical_document, chapters, index)
        derived_ast = File.join(work, "#{chapter.fetch('id')}.json")
        write_file!(derived_ast, Canonical.json(document))
        output = output_for(plan, "chapter-html", chapter.fetch("id"))
        path = staged_path(staging, output.fetch("path"))
        run_render_command!(
          "pandoc-html-chapter-#{chapter.fetch('id')}",
          pandoc_html_command(derived_ast, path, "publication/styles/p3-gold-screen.css"),
          environment: environment,
          expected_output: path
        )
      end
    end

    def render_epub!(staging, plan, ast_path, environment)
      output = output_for(plan, "epub")
      path = staged_path(staging, output.fetch("path"))
      run_render_command!(
        "pandoc-epub",
        [
          "pandoc", "--from=json", "--to=epub3", "--standalone",
          "--css", File.join(root, "publication/styles/p3-gold-epub.css"), "--split-level=1",
          "--output", path, ast_path
        ],
        environment: environment,
        expected_output: path
      )
    end

    def render_print_html!(staging, plan, ast_path, environment)
      output = output_for(plan, "print-html")
      path = staged_path(staging, output.fetch("path"))
      run_render_command!(
        "pandoc-print-html",
        pandoc_html_command(ast_path, path, "publication/styles/p3-gold-print.css", toc: false),
        environment: environment,
        expected_output: path
      )
      path
    end

    def render_pdf!(staging, plan, print_path, environment)
      output = output_for(plan, "pdf-candidate")
      path = staged_path(staging, output.fetch("path"))
      identifier = "urn:factorycare:publication:p3-gold:#{plan.fetch('edition')}"
      run_render_command!(
        "weasyprint-pdf-candidate",
        [
          "dpy", File.join(root, "publication/lib/deterministic_weasyprint.py"),
          "--encoding", "UTF-8", "--media-type", "print",
          "--pdf-identifier", identifier, "--pdf-variant", "pdf/ua-1", "--pdf-tags",
          "--custom-metadata", "--allowed-protocols", "file,data", "--no-http-redirects",
          "--fail-on-http-errors", print_path, path
        ],
        environment: environment,
        expected_output: path
      )
    end

    def validate_rendered_outputs!(staging, plan)
      html_outputs = plan.fetch("planned_outputs").select do |output|
        %w[html-index chapter-html print-html].include?(output.fetch("kind"))
      end
      html_outputs.each do |output|
        relative = output.fetch("path")
        validate_html_output!(staged_path(staging, relative), relative, staging, plan)
      end

      epub = File.binread(staged_path(staging, output_for(plan, "epub").fetch("path")))
      unless epub.start_with?("PK".b)
        raise ContractError.new("stage-validation", "E_EPUB_SIGNATURE", "EPUB output has no ZIP signature")
      end
      pdf = File.binread(staged_path(staging, output_for(plan, "pdf-candidate").fetch("path")))
      pdf_tail = pdf.bytesize > 2048 ? pdf.byteslice(-2048, 2048) : pdf
      unless pdf.start_with?("%PDF-".b) && pdf_tail.include?("%%EOF")
        raise ContractError.new("stage-validation", "E_PDF_SIGNATURE", "PDF candidate has an invalid file signature")
      end
    end

    def validate_html_output!(path, relative, staging, plan)
      bytes = File.binread(path)
      html = bytes.dup.force_encoding(Encoding::UTF_8)
      unless html.valid_encoding?
        raise ContractError.new("stage-validation", "E_HTML_ENCODING", "HTML output is not valid UTF-8", path: relative)
      end
      checks = {
        "doctype" => html.scan(/<!doctype html>/i).length == 1,
        "language" => html.scan(/<html\s+lang="zh-CN">/i).length == 1,
        "title" => html.scan(/<title\b/i).length == 1,
        "robots" => html.scan(/<meta\s+name="robots"\s+content="noindex,nofollow">/i).length == 1,
        "skip-link" => html.scan(/<a\s+class="skip-link"\s+href="#main-content">/i).length == 1,
        "header" => html.scan(/<header\b/i).length == 1,
        "main" => html.scan(/<main\s+id="main-content">/i).length == 1,
        "footer" => html.scan(/<footer\b/i).length == 1,
        "notice" => html.include?(plan.fetch("notice").fetch("text")),
        "no-script" => !html.match?(/<script\b/i)
      }
      failure = checks.find { |_name, passed| !passed }
      if failure
        raise ContractError.new(
          "stage-validation",
          "E_HTML_CONTRACT",
          "HTML output failed its fixed #{failure.first} contract",
          path: relative
        )
      end

      ids = html.scan(/\sid="([^"]+)"/i).flatten
      duplicate = ids.group_by(&:itself).find { |_id, values| values.length > 1 }
      if duplicate
        raise ContractError.new("stage-validation", "E_HTML_DUPLICATE_ID", "HTML output contains a duplicate id", path: relative)
      end
      validate_html_links!(html, ids, path, relative, staging)
    end

    def validate_html_links!(html, ids, path, relative, staging)
      html.scan(/\shref="([^"]+)"/i).flatten.each do |target|
        if target.start_with?("#")
          fragment = target.delete_prefix("#")
          unless ids.include?(fragment)
            raise ContractError.new("stage-validation", "E_HTML_BROKEN_LINK", "HTML fragment target is missing", path: relative)
          end
          next
        end
        scheme = target[/\A([A-Za-z][A-Za-z0-9+.-]*):/, 1]
        next if scheme && SAFE_LINK_SCHEMES.include?(scheme.downcase)

        local_path, fragment = target.split("#", 2)
        resolved = File.expand_path(local_path, File.dirname(path))
        unless resolved.start_with?(staging + File::SEPARATOR) && File.file?(resolved) && !File.symlink?(resolved)
          raise ContractError.new("stage-validation", "E_HTML_BROKEN_LINK", "HTML local target is missing", path: relative)
        end
        next unless fragment

        target_html = File.binread(resolved).force_encoding(Encoding::UTF_8)
        target_ids = target_html.scan(/\sid="([^"]+)"/i).flatten
        unless target_ids.include?(fragment)
          raise ContractError.new("stage-validation", "E_HTML_BROKEN_LINK", "HTML cross-page fragment is missing", path: relative)
        end
      end
    end

    def pandoc_html_command(input, output, stylesheet, toc: true)
      command = [
        "pandoc", "--from=json", "--to=html5", "--standalone",
        "--template", File.join(root, "publication/templates/p3-gold.html5"), "--embed-resources",
        "--css", File.join(root, stylesheet)
      ]
      command.concat(["--toc", "--toc-depth=3"]) if toc
      command.concat(["--output", output, input])
    end

    def chapter_document(canonical_document, chapters, index)
      document = JSON.parse(JSON.generate(canonical_document))
      chapter = chapters.fetch(index)
      notice = document.fetch("blocks").find { |block| block.is_a?(Hash) && block.dig("c", 0, 0) == "publication-notice" }
      section = document.fetch("blocks").find { |block| block.is_a?(Hash) && block.dig("c", 0, 0) == chapter.fetch("id") }
      raise ContractError.new("ast", "E_AST_CHAPTER", "chapter projection is absent from canonical AST") unless notice && section

      document["blocks"] = [notice, section]
      document.fetch("meta")["title"] = meta_string("[内部审查] #{chapter.fetch('title')}")
      rewrite_projected_chapter_links!(document, chapter.fetch("id"), chapters)
      if index.positive?
        previous = chapters.fetch(index - 1)
        document.fetch("meta")["previous-url"] = meta_string("#{previous.fetch('id')}.html")
        document.fetch("meta")["previous-title"] = meta_string(previous.fetch("title"))
      end
      if index + 1 < chapters.length
        following = chapters.fetch(index + 1)
        document.fetch("meta")["next-url"] = meta_string("#{following.fetch('id')}.html")
        document.fetch("meta")["next-title"] = meta_string(following.fetch("title"))
      end
      document
    end

    def rewrite_projected_chapter_links!(document, current_id, chapters)
      chapter_ids = chapters.map { |chapter| chapter.fetch("id") }
      walk_nodes(document) do |node|
        next unless node["t"] == "Link"

        target = node.dig("c", 2, 0).to_s
        matched = chapter_ids.find { |id| target == "##{id}" || target.start_with?("##{id}#") }
        next unless matched && matched != current_id

        suffix = target.delete_prefix("##{matched}")
        node.fetch("c").fetch(2)[0] = "#{matched}.html#{suffix}"
      end
    end

    def canonical_metadata(plan)
      notice = plan.fetch("notice").fetch("text")
      publication_date = Time.at(plan.fetch("source_date_epoch")).utc.strftime("%Y-%m-%d")
      {
        "accessibilitySummary" => meta_string(
          "本 EPUB 提供结构化目录、标题层级和可重排文本；尚未完成独立人工检查、阅读系统或屏幕阅读器测试，也未取得无障碍合规认证。自动化检查结果不能替代人工验证。"
        ),
        "date" => meta_string(publication_date),
        "description" => meta_string("#{notice}；尚未完成无障碍合规评估"),
        "identifier" => meta_string("urn:factorycare:publication:p3-gold:#{plan.fetch('edition')}"),
        "lang" => meta_string(plan.fetch("language")),
        "notice" => meta_string(notice),
        "robots" => meta_string(plan.fetch("notice").fetch("robots")),
        "subtitle" => meta_string(notice),
        "title" => meta_string("[内部审查] FactoryCare 编程百科 · P3 黄金样章")
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

    def validate_ast_safety!(document)
      walk_nodes(document) do |node|
        if node["t"] == "Image"
          target = node.dig("c", 2, 0).to_s
          if target.match?(/\Ahttps?:/i)
            raise ContractError.new("ast", "E_REMOTE_RESOURCE", "remote images are forbidden during publication builds")
          end
          if target.match?(/\Afile:\/\//i) || target.start_with?("/") || target.match?(/\A[A-Za-z]:[\\\/]/)
            raise ContractError.new("ast", "E_ABSOLUTE_RESOURCE", "absolute image resources are forbidden")
          end
          unless SAFE_DATA_IMAGE.match?(target)
            raise ContractError.new(
              "ast",
              "E_LOCAL_RESOURCE",
              "gold publication images must be self-contained safe raster data URIs"
            )
          end
        elsif node["t"] == "Link"
          target = node.dig("c", 2, 0).to_s
          if PRIVATE_PATH_PREFIXES.any? { |prefix| target.include?(prefix) }
            raise ContractError.new("ast", "E_PRIVATE_RESOURCE", "links to private repository paths are forbidden")
          end
          validate_link_scheme!(target)
        elsif %w[RawBlock RawInline].include?(node["t"])
          raw = node.dig("c", 1).to_s
          if raw.match?(/<(?:script|iframe|object|embed|link|style|img|source|video|audio)\b/i) ||
             raw.match?(/\son[a-z]+\s*=|\sstyle\s*=|javascript\s*:/i)
            raise ContractError.new("ast", "E_UNSAFE_RAW_HTML", "resource-bearing or executable raw HTML is forbidden")
          end
        end
      end
    end

    def validate_link_scheme!(target)
      if target.start_with?("//") || target.include?("\\")
        raise ContractError.new("ast", "E_UNSAFE_LINK", "protocol-relative and backslash link targets are forbidden")
      end
      match = target.match(/\A([A-Za-z][A-Za-z0-9+.-]*):/)
      return unless match
      return if SAFE_LINK_SCHEMES.include?(match[1].downcase)

      raise ContractError.new("ast", "E_UNSAFE_LINK", "link target uses a forbidden URI scheme")
    end

    def rewrite_publication_links!(chapter_divs, chapters)
      artifact_targets = {}
      chapters.each do |chapter|
        chapter.fetch("artifacts").each do |artifact|
          artifact_targets[artifact.fetch("source_path")] = artifact_anchor(chapter, artifact)
        end
      end
      chapter_targets = chapters.to_h { |chapter| [chapter.fetch("source_path"), chapter.fetch("id")] }

      chapter_divs.each_with_index do |division, index|
        chapter = chapters.fetch(index)
        walk_nodes(division) do |node|
          next unless node["t"] == "Link"

          target = node.dig("c", 2, 0).to_s
          replacement = rewrite_link_target(
            target,
            source_path: chapter.fetch("source_path"),
            artifact_targets: artifact_targets,
            chapter_targets: chapter_targets
          )
          if replacement
            node.fetch("c").fetch(2)[0] = replacement
          else
            label = node.dig("c", 1) || []
            node["t"] = "Span"
            node["c"] = [
              ["", ["unavailable-local-reference"], [["data-publication-note", "not-in-gold-preview"]]],
              label + [{ "t" => "Space" }, { "t" => "Str", "c" => "（未收入本黄金样章）" }]
            ]
          end
        end
      end
    end

    def rewrite_link_target(target, source_path:, artifact_targets:, chapter_targets:)
      return target if target.start_with?("#")
      scheme = target[/\A([A-Za-z][A-Za-z0-9+.-]*):/, 1]
      return target if scheme && SAFE_LINK_SCHEMES.include?(scheme.downcase)

      path_part = target.sub(/[?#].*\z/, "")
      suffix = target.delete_prefix(path_part)
      if path_part.empty? || path_part.start_with?("/") || path_part.include?("%")
        raise ContractError.new("ast", "E_UNSAFE_LINK", "local link target has an unsafe path form")
      end
      resolved = Pathname.new(File.dirname(source_path)).join(path_part).cleanpath.to_s
      if resolved == ".." || resolved.start_with?("../") || PRIVATE_PATH_PREFIXES.any? { |prefix| resolved.start_with?(prefix) }
        raise ContractError.new("ast", "E_LOCAL_LINK_ESCAPE", "local link target escapes the public repository boundary")
      end

      if artifact_targets.key?(resolved)
        return "##{artifact_targets.fetch(resolved)}#{suffix}"
      end
      if path_part.end_with?("/")
        readme = artifact_targets.keys.find { |path| path == "#{resolved}/README.md" }
        return "##{artifact_targets.fetch(readme)}#{suffix}" if readme
      end
      return "##{chapter_targets.fetch(resolved)}#{suffix}" if chapter_targets.key?(resolved)

      nil
    end

    def append_public_artifacts!(chapter_divs, chapters, snapshots)
      chapter_divs.each_with_index do |division, index|
        chapter = chapters.fetch(index)
        blocks = division.fetch("c").fetch(1)
        blocks << { "t" => "HorizontalRule" }
        blocks << {
          "t" => "Header",
          "c" => [
            2,
            ["#{chapter.fetch('id')}-public-artifacts", [], []],
            [{ "t" => "Str", "c" => "公开工件附录" }]
          ]
        }
        blocks << {
          "t" => "Para",
          "c" => [
            { "t" => "Str", "c" => "以下内容来自本章显式公共工件清单，并与本次构建输入摘要绑定。" }
          ]
        }
        chapter.fetch("artifacts").each do |artifact|
          source_path = artifact.fetch("source_path")
          bytes = snapshots.fetch(source_path)
          reject_private_or_absolute!(bytes, phase: "ast", code: "E_ARTIFACT_LEAK")
          text = bytes.dup.force_encoding(Encoding::UTF_8)
          unless text.valid_encoding?
            raise ContractError.new("ast", "E_ARTIFACT_ENCODING", "public text artifact is not valid UTF-8", path: source_path)
          end
          anchor = artifact_anchor(chapter, artifact)
          blocks << {
            "t" => "Header",
            "c" => [3, [anchor, [], []], [{ "t" => "Code", "c" => [["", [], []], source_path] }]]
          }
          blocks << {
            "t" => "Para",
            "c" => [
              { "t" => "Str", "c" => "角色：#{artifact.fetch('role')}；媒体类型：#{artifact.fetch('media_type')}。" }
            ]
          }
          blocks << {
            "t" => "CodeBlock",
            "c" => [
              ["#{anchor}-listing", [artifact_language(artifact.fetch("media_type")), "artifact-listing"], [["data-source-path", source_path]]],
              text
            ]
          }
        end
      end
    end

    def artifact_anchor(chapter, artifact)
      "artifact-#{chapter.fetch('id')}-#{artifact.fetch('artifact_id')}"
    end

    def artifact_language(media_type)
      {
        "application/xml" => "xml",
        "text/markdown" => "markdown",
        "text/plain" => "text",
        "text/x-java-source" => "java",
        "text/x-shellscript" => "bash"
      }.fetch(media_type)
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

    def sanitize_private_references(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, child), memo| memo[key] = sanitize_private_references(child) }
      when Array
        value.map { |child| sanitize_private_references(child) }
      when String
        sanitized = value.gsub(%r{solutions-private/[A-Za-z0-9._/-]*}, "[私有答案路径已从预览移除]")
        sanitized.gsub(%r{sources/private/[A-Za-z0-9._/-]*}, "[私有来源路径已从预览移除]")
      else
        value
      end
    end

    def normalized_inline_text(inlines)
      fragments = []
      collect_inline_text(inlines, fragments)
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
          collect_inline_text(value["c"], fragments) if value.key?("c")
        end
      end
    end

    def normalize_text(value)
      value.to_s.gsub(/[[:space:]]+/u, " ").strip
    end

    def write_output_manifest!(staging, plan, plan_bytes, tools)
      planned_artifacts = plan.fetch("planned_outputs").reject { |output| output.fetch("kind") == "output-manifest" }
      outputs = planned_artifacts.sort_by { |output| output.fetch("path") }.map do |output|
        path = staged_path(staging, output.fetch("path"))
        validate_regular_nonempty!(path, "E_OUTPUT_MISSING")
        bytes = File.binread(path)
        reject_private_or_absolute!(bytes, phase: "stage-validation", code: "E_OUTPUT_LEAK")
        output.merge(
          "media_type" => MEDIA_TYPES.fetch(output.fetch("kind")),
          "sha256" => Canonical.sha256(bytes),
          "size_bytes" => bytes.bytesize
        )
      end
      manifest = {
        "schema_version" => 1,
        "manifest_id" => "publication-output.p3-gold",
        "profile_id" => PROFILE_ID,
        "plan_id" => plan.fetch("plan_id"),
        "plan_sha256" => Canonical.sha256(plan_bytes),
        "build_input_digest" => plan.fetch("build_input_digest"),
        "build_status" => "succeeded",
        "generated_by" => "scripts/build-publication.rb",
        "source_date_epoch" => plan.fetch("source_date_epoch"),
        "environment" => {
          "os" => RbConfig::CONFIG.fetch("host_os"),
          "arch" => RbConfig::CONFIG.fetch("host_cpu"),
          "locale" => FIXED_ENVIRONMENT.fetch("LC_ALL"),
          "timezone" => "UTC",
          "network_policy" => "forbidden",
          "network_isolation" => "not-os-enforced"
        },
        "tools_observed" => tools.sort_by { |tool| tool.fetch("id") },
        "commands" => @command_records.sort_by { |command| command.fetch("id") },
        "output_count" => outputs.length,
        "output_set_digest" => output_set_digest(outputs, staging),
        "outputs" => outputs
      }
      loader.validate_value!(manifest, OUTPUT_SCHEMA, "generated publication output manifest")
      manifest_bytes = Canonical.json(manifest)
      reject_private_or_absolute!(manifest_bytes, phase: "stage-validation", code: "E_MANIFEST_LEAK")
      path = staged_path(staging, output_for(plan, "output-manifest").fetch("path"))
      write_file!(path, manifest_bytes)
      { "manifest" => manifest, "manifest_bytes" => manifest_bytes }
    end

    def output_set_digest(outputs, staging)
      digest = Digest::SHA256.new
      outputs.sort_by { |output| output.fetch("path") }.each do |output|
        path = output.fetch("path")
        digest << path << "\0" << File.binread(staged_path(staging, path)) << "\0"
      end
      digest.hexdigest
    end

    def run_render_command!(id, argv, environment:, expected_output:)
      FileUtils.mkdir_p(File.dirname(expected_output))
      stdout, stderr, exit_code = invoke(argv, environment: environment)
      unless exit_code == 0
        raise ContractError.new("render", "E_COMMAND_FAILED", "#{id} failed with exit code #{exit_code}")
      end
      validate_regular_nonempty!(expected_output, "E_COMMAND_OUTPUT")
      @command_records << {
        "id" => id,
        "argv" => logical_argv(argv),
        "exit_code" => 0
      }
      [stdout, stderr]
    end

    def invoke(argv, environment:)
      stdout, stderr, status = command_runner.call(argv, chdir: root, env: environment)
      exit_code = status.respond_to?(:exitstatus) ? status.exitstatus : Integer(status)
      [stdout.to_s.b, stderr.to_s.b, exit_code]
    rescue ContractError
      raise
    rescue StandardError => e
      raise ContractError.new("render", "E_COMMAND_START", "command could not start (#{e.class})")
    end

    def default_command_runner(argv, chdir:, env:)
      Open3.capture3(env, *argv, chdir: chdir)
    end

    def logical_argv(argv)
      argv.map do |argument|
        value = argument.to_s
        if value.start_with?(root + File::SEPARATOR)
          relative = value.delete_prefix(root + File::SEPARATOR)
          stage_match = relative.match(%r{\Abuild/publication/\.p3-gold\.render-stage-[^/]+/(.+)\z})
          stage_match ? "$STAGING/#{stage_match[1]}" : "$REPOSITORY/#{relative}"
        else
          value
        end
      end
    end

    def combine_output(stdout, stderr)
      parts = [stdout, stderr].reject(&:empty?)
      parts.join("\n").b
    end

    def validate_staged_tree!(staging, plan)
      expected = (["publication-plan.json"] + plan.fetch("planned_outputs").map { |output| output.fetch("path") }).sort
      actual = staged_files(staging)
      extra = actual - expected
      missing = expected - actual
      raise ContractError.new("stage-validation", "E_STAGE_EXTRA", "staging contains an unplanned output", path: extra.first) unless extra.empty?
      raise ContractError.new("stage-validation", "E_STAGE_MISSING", "staging is missing a planned output", path: missing.first) unless missing.empty?

      actual.each do |relative|
        path = File.join(staging, relative)
        validate_regular_nonempty!(path, "E_STAGE_UNSAFE")
        reject_private_or_absolute!(File.binread(path), phase: "stage-validation", code: "E_STAGE_LEAK")
      end
      fsync_tree(staging)
    end

    def staged_files(staging)
      Dir.glob(File.join(staging, "**", "*"), File::FNM_DOTMATCH).sort.each_with_object([]) do |path, memo|
        relative = path.delete_prefix(staging + File::SEPARATOR)
        next if relative.split("/").any? { |component| component == "." || component == ".." }

        stat = File.lstat(path)
        if stat.symlink?
          raise ContractError.new("stage-validation", "E_STAGE_SYMLINK", "staging may not contain symbolic links", path: relative)
        end
        memo << relative if stat.file?
      end
    end

    def stage_and_promote(profile_id)
      raise ContractError.new("commit", "E_PROFILE_ID", "renderer is restricted to p3-gold") unless profile_id == PROFILE_ID

      parent = publication_parent
      output = File.join(parent, profile_id)
      token = "#{$$}-#{SecureRandom.hex(6)}"
      staging = File.join(parent, ".#{profile_id}.render-stage-#{token}")
      backup = File.join(parent, ".#{profile_id}.render-backup-#{token}")
      [staging, backup].each do |path|
        raise ContractError.new("commit", "E_TEMP_EXISTS", "temporary render path already exists") if File.exist?(path) || File.symlink?(path)
      end

      Dir.mkdir(staging, 0o755)
      staging_present = true
      backup_created = false
      committed = false
      preserve_recovery = false
      begin
        yield staging
        validate_existing_output!(output) if File.exist?(output) || File.symlink?(output)
        if File.exist?(output) || File.symlink?(output)
          @renamer.call(output, backup)
          backup_created = true
        end
        begin
          @renamer.call(staging, output)
          staging_present = false
          fsync_directory(parent)
          committed = true
        rescue StandardError => promotion_error
          begin
            if (File.exist?(output) || File.symlink?(output)) && !File.exist?(staging) && !File.symlink?(staging)
              @renamer.call(output, staging)
              staging_present = true
            end
            if backup_created
              @renamer.call(backup, output)
              backup_created = false
            end
            fsync_directory(parent)
          rescue StandardError
            preserve_recovery = true
            raise ContractError.new("rollback", "E_ROLLBACK_FAILED", "render promotion failed and recovery trees were preserved")
          end
          raise ContractError.new("commit", "E_ATOMIC_PROMOTION", "atomic render promotion failed (#{promotion_error.class})")
        end
        FileUtils.rm_rf(backup) if backup_created && File.directory?(backup) && !File.symlink?(backup)
        backup_created = false
      ensure
        unless preserve_recovery
          FileUtils.rm_rf(staging) if staging_present && File.directory?(staging) && !File.symlink?(staging)
          FileUtils.rm_rf(backup) if committed && File.directory?(backup) && !File.symlink?(backup)
        end
      end
    end

    def publication_parent
      cursor = root
      %w[build publication].each do |component|
        cursor = File.join(cursor, component)
        if File.exist?(cursor) || File.symlink?(cursor)
          stat = File.lstat(cursor)
          raise ContractError.new("commit", "E_OUTPUT_SYMLINK", "publication output path contains a symbolic link") if stat.symlink?
          raise ContractError.new("commit", "E_OUTPUT_NOT_DIRECTORY", "publication output parent is not a directory") unless stat.directory?
        else
          Dir.mkdir(cursor, 0o755)
        end
      end
      cursor
    end

    def validate_existing_output!(path)
      stat = File.lstat(path)
      raise ContractError.new("commit", "E_OUTPUT_SYMLINK", "profile output cannot be a symbolic link") if stat.symlink?
      raise ContractError.new("commit", "E_OUTPUT_NOT_DIRECTORY", "profile output must be a directory") unless stat.directory?
    end

    def fsync_tree(root_path)
      directories = [root_path]
      Dir.glob(File.join(root_path, "**", "*"), File::FNM_DOTMATCH).sort.each do |path|
        next if [".", ".."].include?(File.basename(path))
        stat = File.lstat(path)
        if stat.file?
          File.open(path, File::RDONLY) { |file| file.fsync }
        elsif stat.directory?
          directories << path
        end
      end
      directories.reverse_each { |directory| fsync_directory(directory) }
    end

    def fsync_directory(directory)
      File.open(directory, File::RDONLY) { |dir| dir.fsync }
    rescue Errno::EINVAL, Errno::EISDIR
      nil
    end

    def write_file!(path, bytes)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o644) do |file|
        file.binmode
        file.write(bytes)
        file.flush
        file.fsync
      end
    rescue Errno::EEXIST
      raise ContractError.new("stage-validation", "E_OUTPUT_EXISTS", "renderer attempted to overwrite a staged output")
    end

    def validate_regular_nonempty!(path, code)
      stat = File.lstat(path)
      unless stat.file? && !stat.symlink? && stat.size.positive?
        raise ContractError.new("stage-validation", code, "expected a non-empty regular output file")
      end
    rescue Errno::ENOENT
      raise ContractError.new("stage-validation", code, "expected output file is missing")
    end

    def compare_digest!(plan, field, entries, snapshots)
      actual = Canonical.path_bytes_digest(entries, ->(path) { snapshots.fetch(path) })
      return if actual == plan.fetch(field)

      raise ContractError.new("plan-validation", "E_INPUT_SET_DIGEST", "#{field} has drifted from the planned input set")
    end

    def reject_canary!(bytes, path)
      return unless PRIVATE_CANARY_PATTERN.match?(bytes)

      raise ContractError.new("plan-validation", "E_PRIVATE_CANARY", "planned input contains a private canary", path: path)
    end

    def reject_private_input_path!(path)
      return unless PRIVATE_PATH_PREFIXES.any? { |prefix| path.start_with?(prefix) }

      raise ContractError.new("plan-validation", "E_PRIVATE_PATH", "private paths are forbidden publication inputs")
    end

    def reject_private_or_absolute!(bytes, phase:, code:)
      text = bytes.to_s.dup.force_encoding(Encoding::BINARY)
      leaked = PRIVATE_PATH_PREFIXES.any? { |prefix| text.include?(prefix) } ||
               PRIVATE_CANARY_PATTERN.match?(text) || text.include?(root.b) || text.match?(%r{/Users/[A-Za-z0-9._-]+/})
      raise ContractError.new(phase, code, "publication bytes contain a private or absolute path marker") if leaked
    end

    def output_for(plan, kind, chapter_id = nil)
      candidates = plan.fetch("planned_outputs").select { |output| output.fetch("kind") == kind }
      candidates = candidates.select { |output| output.fetch("path").include?(chapter_id) } if chapter_id
      unless candidates.length == 1
        raise ContractError.new("plan-validation", "E_PLAN_OUTPUT_LOOKUP", "planned output lookup is ambiguous")
      end
      candidates.first
    end

    def staged_path(staging, relative)
      guard.validate_shape!(relative, "planned output")
      path = File.expand_path(relative, staging)
      unless path.start_with?(staging + File::SEPARATOR)
        raise ContractError.new("stage-validation", "E_OUTPUT_ESCAPE", "planned output escapes staging")
      end
      path
    end

    def expected_planned_outputs
      outputs = [
        { "path" => "ast/book.json", "kind" => "canonical-ast", "format" => "internal", "distribution" => "internal" },
        { "path" => "intermediate/print/book.html", "kind" => "print-html", "format" => "internal", "distribution" => "internal" },
        { "path" => "output/epub/factorycare-p3-gold.epub", "kind" => "epub", "format" => "epub", "distribution" => "internal-review-candidate" },
        { "path" => "output/html/index.html", "kind" => "html-index", "format" => "html", "distribution" => "internal-review-candidate" },
        { "path" => "output/pdf/factorycare-p3-gold.pdf", "kind" => "pdf-candidate", "format" => "pdf", "distribution" => "internal-review-candidate" },
        { "path" => "publication-output-manifest.json", "kind" => "output-manifest", "format" => "internal", "distribution" => "internal" }
      ]
      GOLD_IDS.each do |id|
        outputs << {
          "path" => "output/html/chapters/#{id}.html",
          "kind" => "chapter-html",
          "format" => "html",
          "distribution" => "internal-review-candidate"
        }
      end
      outputs.sort_by { |output| output.fetch("path") }
    end

    def exact(relative)
      /\A#{Regexp.escape(relative)}\z/
    end
  end
end
