# frozen_string_literal: true

require "csv"
require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "pathname"
require "tempfile"
require "tmpdir"
require "yaml"

require_relative "../../scripts/build-source-inventory"

class SourceInventoryTest < Minitest::Test
  ROOT = Pathname(__dir__).join("../..").expand_path.freeze
  CATALOG_PATH = ROOT.join("curriculum/catalog.yml").freeze
  Fixture = Struct.new(:root, :repository_paths, :commits, keyword_init: true)

  NOTE_FILES = {
    "02.JS/RAW_PATH_NEVER_PUBLIC_71A9.md" => <<~MARKDOWN,
      # RAW_HEADING_NEVER_PUBLIC_7F31
      ## Promise 与事件循环
    MARKDOWN
    "04.Vue/components.md" => <<~MARKDOWN,
      # Vue 组件
      ## 生命周期与清理
    MARKDOWN
    "04.Vue/no-extension-image" => "\x89PNG\r\n\x1A\nfixture".b,
    "08.鸿蒙开发/future.md" => "# HarmonyOS future extension\n",
    "target/module.kotlin_module" => "compiled fixture\n"
  }.freeze

  JAVA_NOTE_FILES = {
    "1.java基础/第10章_多线程.md" => "# 多线程的生命周期\n",
    "1.java基础/第15章_File类与IO流.md" => "# InputStream 与 IO 流\n",
    "4.web框架核心技术/pro004-Spring/chapter.md" => "# Spring 组件与依赖注入\n",
    "8.面试题/questions.md" => "# Interview coverage signal\n"
  }.freeze

  def with_markdown(contents)
    Tempfile.create(["source-inventory", ".md"]) do |file|
      file.binmode
      file.write(contents)
      file.flush
      yield file.path
    end
  end

  def with_binary(contents, suffix = "")
    Tempfile.create(["source-inventory", suffix]) do |file|
      file.binmode
      file.write(contents)
      file.flush
      yield file.path
    end
  end

  def with_fixture
    root = Pathname(Dir.mktmpdir("source-inventory-test-"))
    note = root.join("Note")
    java_note = root.join("Java-Note")
    note_commit = create_repository(note, NOTE_FILES, "https://local.invalid/first-note.git")
    java_commit = create_repository(java_note, JAVA_NOTE_FILES, "https://local.invalid/first-java-note.git")
    fixture = Fixture.new(
      root: root,
      repository_paths: { "note" => note.to_s, "java-note" => java_note.to_s },
      commits: { "note" => note_commit, "java-note" => java_commit }
    )
    yield fixture
  ensure
    FileUtils.rm_rf(root) if root
  end

  def create_repository(root, files, remote_url)
    FileUtils.mkdir_p(root)
    files.each do |relative_path, contents|
      path = root.join(relative_path)
      FileUtils.mkdir_p(path.dirname)
      File.binwrite(path, contents)
    end
    git!(root, "init", "--quiet")
    git!(root, "config", "user.name", "Source Inventory Test")
    git!(root, "config", "user.email", "source-inventory-test@example.invalid")
    git!(root, "add", "--force", "--all")
    git!(root, "commit", "--quiet", "-m", "fixture")
    git!(root, "remote", "add", "origin", remote_url)
    git!(root, "rev-parse", "HEAD").strip
  end

  def git!(root, *arguments)
    output, error, status = Open3.capture3("git", "-C", root.to_s, *arguments)
    raise "git #{arguments.join(" ")} failed: #{error}" unless status.success?

    output
  end

  def builder_for(fixture, output:, check: false, include_private: false,
                  expected_commits: fixture.commits, repository_paths: fixture.repository_paths,
                  builder_class: SourceInventory::Builder)
    builder_class.new(
      repository_paths: repository_paths,
      expected_commits: expected_commits,
      output_root: output,
      catalog_path: CATALOG_PATH,
      check: check,
      include_private: include_private,
      quiet: true
    )
  end

  def csv_rows(path)
    CSV.read(path, headers: true).map(&:to_h)
  end

  def yaml(path)
    YAML.safe_load(File.read(path, encoding: "UTF-8"), aliases: false)
  end

  def public_snapshot(output)
    SourceInventory::PUBLIC_FILES.sort.each_with_object({}) do |name, memo|
      path = Pathname(output).join(name)
      memo[name] = Digest::SHA256.file(path).hexdigest
    end
  end

  def all_public_text(output)
    SourceInventory::PUBLIC_FILES.map { |name| File.binread(Pathname(output).join(name)) }.join("\n")
  end

  def test_extracts_atx_and_setext_headings_but_ignores_fenced_code
    markdown = <<~MARKDOWN
      # Java 循环

      ```java
      # 不是标题
      ```

      Promise 与 async
      -----------------

      ### Vue 生命周期 ###
    MARKDOWN

    with_markdown(markdown) do |path|
      headings = SourceInventory.extract_markdown_headings(path)

      assert_equal ["Java 循环", "Promise 与 async", "Vue 生命周期"], headings.map { |item| item.fetch("heading") }
      assert_equal [1, 2, 3], headings.map { |item| item.fetch("level") }
      assert_equal [1, 7, 10], headings.map { |item| item.fetch("line") }
    end
  end

  def test_ignores_front_matter_horizontal_rules_image_only_headings_and_fenced_content
    markdown = <<~MARKDOWN
      ---
      title: 不是标题
      ---

      ![example](assets/example.png)
      ---

      ### ![screenshot](D:\\private\\screenshot.png)
      ## [Promise](https://example.invalid/promise) 基础

      ~~~text
      ~~~ruby
      # 仍然不是标题
      ~~~
      # 真正标题
    MARKDOWN

    with_markdown(markdown) do |path|
      headings = SourceInventory.extract_markdown_headings(path)

      assert_equal ["Promise 基础", "真正标题"], headings.map { |item| item.fetch("heading") }
    end
  end

  def test_ids_are_stable_and_sensitive_to_their_locators
    first = SourceInventory.file_id("note", "abc", "04.Vue/响应式.md")
    assert_equal first, SourceInventory.file_id("note", "abc", "04.Vue/响应式.md")
    refute_equal first, SourceInventory.file_id("note", "def", "04.Vue/响应式.md")

    section = SourceInventory.section_id(first, 10, "生命周期")
    assert_equal section, SourceInventory.section_id(first, 10, "生命周期")
    refute_equal section, SourceInventory.section_id(first, 11, "生命周期")

    composed = "caf\u00E9.md"
    decomposed = "cafe\u0301.md"
    assert_equal SourceInventory.file_id("note", "abc", composed),
                 SourceInventory.file_id("note", "abc", decomposed)
  end

  def test_domains_are_classified_and_targets_are_resolved_from_the_canonical_catalog
    index = SourceInventory::CatalogIndex.new(CATALOG_PATH)
    cases = {
      ["note", "04.Vue/组合式API.md"] => ["vue", "09"],
      ["note", "10.Flutter/Flutter教程.pdf"] => ["flutter", "11"],
      ["java-note", "1.java基础/IDEA的安装.md"] => ["developer-tooling", "00"],
      ["java-note", "1.java基础/第03章_流程控制语句.md"] => ["java-foundations", "01"],
      ["java-note", "1.java基础/第11章_常用类和基础API.md"] => ["java-object-model", "02"],
      ["java-note", "1.java基础/第12章_集合框架.md"] => ["java-engineering-runtime", "03"],
      ["java-note", "1.java基础/第15章_File类与IO流.md"] => ["java-engineering-runtime", "03"],
      ["java-note", "1.java基础/Tomcat快速部署.docx"] => ["legacy-java-web", "05"],
      ["java-note", "4.web框架核心技术/pro002-MyBatis/chapter.md"] => ["mybatis", "05"],
      ["java-note", "4.web框架核心技术/配套资料/pro006-Linux/chapter01/index.md"] => ["linux", "15"]
    }

    cases.each do |(repository, path), (expected_domain, volume)|
      domain = SourceInventory.domain_for(repository, path)
      destination = SourceInventory.destination_for(domain, index)
      assert_equal expected_domain, domain
      assert_equal "volume", destination.fetch("kind")
      assert_equal index.volume_slug(volume), destination.fetch("id")
    end

    appendix = SourceInventory.destination_for("interview-material", index)
    assert_equal({ "kind" => "appendix", "id" => "interview-evidence" }, appendix)
  end

  def test_volume_slugs_are_not_duplicated_in_source_policy
    Dir.mktmpdir("source-catalog-") do |directory|
      path = Pathname(directory).join("catalog.yml")
      volumes = SourceInventory::DOMAIN_DESTINATIONS.values
                               .select { |item| item.fetch("kind") == "volume" }
                               .map { |item| item.fetch("volume") }.uniq.sort
      chapters = volumes.map do |volume|
        {
          "id" => "fixture.v#{volume}.c01",
          "title" => "Fixture #{volume}",
          "volume" => volume,
          "order" => 1,
          "path" => "book/volume-#{volume}-fixture-slug/chapters/fixture.md"
        }
      end
      File.binwrite(path, {
        "catalog_id" => "fixture-catalog",
        "edition" => "fixture",
        "chapters" => chapters
      }.to_yaml)

      index = SourceInventory::CatalogIndex.new(path)
      destination = SourceInventory.destination_for("vue", index)
      assert_equal "volume-09-fixture-slug", destination.fetch("id")
      assert_equal ["fixture.v09.c01"], index.chapters_for_volume("09").map { |chapter| chapter.fetch("id") }
    end
  end

  def test_catalog_index_rejects_missing_required_volume_and_duplicate_chapter_id
    Dir.mktmpdir("source-invalid-catalog-") do |directory|
      path = Pathname(directory).join("catalog.yml")
      File.binwrite(path, {
        "catalog_id" => "invalid",
        "edition" => "invalid",
        "chapters" => [
          { "id" => "duplicate", "title" => "A", "volume" => "01", "order" => 1,
            "path" => "book/volume-01-a/chapters/a.md" },
          { "id" => "duplicate", "title" => "B", "volume" => "01", "order" => 2,
            "path" => "book/volume-01-a/chapters/b.md" }
        ]
      }.to_yaml)

      error = assert_raises(RuntimeError) { SourceInventory::CatalogIndex.new(path) }
      assert_match(/duplicate chapter IDs/, error.message)
    end
  end

  def test_catalog_index_rejects_a_slug_shared_by_multiple_volumes
    Dir.mktmpdir("source-duplicate-slug-catalog-") do |directory|
      path = Pathname(directory).join("catalog.yml")
      volumes = SourceInventory::DOMAIN_DESTINATIONS.values
                               .select { |item| item.fetch("kind") == "volume" }
                               .map { |item| item.fetch("volume") }.uniq.sort
      chapters = volumes.map do |volume|
        slug = %w[01 02].include?(volume) ? "volume-shared" : "volume-#{volume}-unique"
        {
          "id" => "fixture.v#{volume}.c01",
          "title" => "Fixture #{volume}",
          "volume" => volume,
          "order" => 1,
          "path" => "book/#{slug}/chapters/fixture.md"
        }
      end
      File.binwrite(path, {
        "catalog_id" => "fixture-catalog",
        "edition" => "fixture",
        "chapters" => chapters
      }.to_yaml)

      error = assert_raises(RuntimeError) { SourceInventory::CatalogIndex.new(path) }
      assert_match(/reuses book volume slugs/, error.message)
    end
  end

  def test_concept_rules_are_domain_aware_and_do_not_cross_language_boundaries
    java_lifecycle = SourceInventory.concept_candidates(
      "1.java基础/第10章_多线程.md", "多线程的生命周期", "java-engineering-runtime"
    )
    assert_includes java_lifecycle, "java.threads-jmm"
    refute_includes java_lifecycle, "vue.lifecycle"

    java_io = SourceInventory.concept_candidates(
      "1.java基础/第15章_File类与IO流.md", "InputStream", "java-engineering-runtime"
    )
    assert_includes java_io, "java.io-nio"
    refute_includes java_io, "dart.async"

    spring = SourceInventory.concept_candidates(
      "4.web框架核心技术/pro004-Spring/chapter.md", "Spring 组件", "spring"
    )
    assert_includes spring, "spring.ioc-di"
    refute_includes spring, "vue.components"

    javascript = SourceInventory.concept_candidates("02.JS/变量.md", "变量", "javascript")
    assert_includes javascript, "js.values-types"
    refute javascript.any? { |concept| concept.start_with?("java.") }
  end

  def test_concept_candidates_are_deterministic_and_deduplicated
    first = SourceInventory.concept_candidates("02.JS/异步.md", "Promise 与事件循环", "javascript")
    second = SourceInventory.concept_candidates("02.JS/异步.md", "Promise 与事件循环", "javascript")

    assert_equal first, second
    assert_equal first.uniq, first
    assert_includes first, "js.event-loop-promises"
  end

  def test_magic_bytes_and_build_outputs_are_conservatively_excluded
    with_binary("\x89PNG\r\n\x1A\nfixture".b) do |path|
      risk, action, _reason, kind = SourceInventory.file_policy(
        "note", "04.Vue/image-without-extension", "vue", absolute_path: path
      )
      assert_equal "image/png", kind
      assert_equal "exclude-binary-asset", action
      assert_match(/binary/i, risk)
    end

    with_binary("compiled fixture", ".kotlin_module") do |path|
      _risk, action, _reason, kind = SourceInventory.file_policy(
        "java-note", "target/module.kotlin_module", "java-engineering-runtime", absolute_path: path
      )
      assert_equal "compiled/kotlin_module", kind
      assert_equal "exclude-generated-build-output", action
    end

    with_binary("\xCA\xFE\xBA\xBEfixture".b) do |path|
      _risk, action, _reason, kind = SourceInventory.file_policy(
        "java-note", "mystery", "unclassified", absolute_path: path
      )
      assert_equal "binary/java-class", kind
      assert_equal "exclude-generated-build-output", action
    end

    with_binary("") do |path|
      _risk, action, _reason, kind = SourceInventory.file_policy(
        "note", "04.Vue/empty", "vue", absolute_path: path
      )
      assert_equal "empty", kind
      assert_equal "exclude-empty-file", action
    end
  end

  def test_file_policy_never_authorizes_verbatim_copying
    paths = [
      ["note", "04.Vue/响应式.md", "vue"],
      ["note", "10.Flutter/教程.pdf", "flutter"],
      ["java-note", "1.java基础/语言概述.md", "java-foundations"],
      ["java-note", "assets/course.png", "unclassified"]
    ]

    paths.each do |repository, path, domain|
      _risk, action, _reason, _kind = SourceInventory.file_policy(repository, path, domain)
      refute_match(/copy-as-is|direct-copy|reuse-verbatim/, action)
    end
  end

  def test_csv_cells_that_could_execute_formulas_are_neutralized
    {
      "=1+1" => "'=1+1",
      "+cmd" => "'+cmd",
      "-2+3" => "'-2+3",
      "@SUM(A1:A2)" => "'@SUM(A1:A2)",
      "\t=1+1" => "'\t=1+1",
      "\r=1+1" => "'\r=1+1",
      "\n=1+1" => "'\n=1+1",
      "plain" => "plain",
      "" => ""
    }.each do |input, expected|
      assert_equal expected, SourceInventory.csv_safe_cell(input)
    end
  end

  def test_private_output_and_atomic_swap_paths_are_gitignored
    paths = [
      ROOT.join("sources/private/.source-inventory-safety-check"),
      ROOT.join(".sources.stage-safety-check/private/ledger"),
      ROOT.join(".sources.backup-safety-check/private/ledger")
    ]
    paths.each do |path|
      _output, error, status = Open3.capture3(
        "git", "-C", ROOT.to_s, "check-ignore", "--quiet", "--no-index", path.to_s
      )
      assert status.success?, "expected #{path} to be ignored: #{error}"
    end
  end

  def test_private_generation_fails_closed_inside_a_git_worktree_without_ignore_rules
    with_fixture do |fixture|
      workspace = fixture.root.join("workspace")
      FileUtils.mkdir_p(workspace)
      git!(workspace, "init", "--quiet")
      output = workspace.join("sources")

      error = assert_raises(RuntimeError) do
        builder_for(fixture, output: output, include_private: true).run
      end
      assert_match(/must be Git-ignored/, error.message)
      refute output.exist?
    end
  end

  def test_full_fixture_build_has_canonical_foreign_keys_reconciled_totals_and_no_public_raw_ledger
    with_fixture do |fixture|
      output = fixture.root.join("sources")
      assert builder_for(fixture, output: output, include_private: true).run

      files = csv_rows(output.join("files.csv"))
      mappings = csv_rows(output.join("mappings.csv"))
      catalog = yaml(output.join("catalog.yml"))
      index = SourceInventory::CatalogIndex.new(CATALOG_PATH)
      files_by_id = files.each_with_object({}) { |row, memo| memo[row.fetch("file_id")] = row }

      assert_equal NOTE_FILES.length + JAVA_NOTE_FILES.length, files.length
      assert_equal files.length, catalog.fetch("totals").fetch("file_count")
      assert_equal mappings.length, catalog.fetch("totals").fetch("section_mapping_count")
      assert_equal mappings.length, catalog.fetch("totals").fetch("unreviewed_mapping_count")
      assert_equal files.length, catalog.fetch("repositories").values.sum { |row| row.fetch("file_count") }
      assert_equal mappings.length, catalog.fetch("repositories").values.sum { |row| row.fetch("section_mapping_count") }

      assert_equal SourceInventory::FILE_COLUMNS, CSV.open(output.join("files.csv"), &:readline)
      assert_equal SourceInventory::MAPPING_COLUMNS, CSV.open(output.join("mappings.csv"), &:readline)
      refute_includes SourceInventory::FILE_COLUMNS, "path"
      refute_includes SourceInventory::MAPPING_COLUMNS, "heading"
      refute output.join("sections.csv").exist?

      files.each do |row|
        assert_match(/\Afile-[0-9a-f]{64}\z/, row.fetch("file_id"))
        assert_match(/\A[0-9a-f]{64}\z/, row.fetch("path_sha256"))
        assert_match(/\A[0-9a-f]{64}\z/, row.fetch("content_sha256"))
        if row.fetch("target_kind") == "volume"
          assert_includes index.volume_slugs, row.fetch("target_id")
        end
      end

      mappings.each do |row|
        assert files_by_id.key?(row.fetch("file_id")), "mapping refers to an unknown file"
        assert_equal "unreviewed", row.fetch("review_status")
        assert_match(/\A(?:heuristic|policy)/, row.fetch("mapping_confidence"))
        assert_match(/coverage-only\z/, row.fetch("copyright_state"))
        assert_includes %w[required-not-linked not-applicable], row.fetch("official_source_state")
        assert_includes %w[required-not-run not-applicable], row.fetch("verification_state")
        refute_empty row.fetch("decision_reason")
        chapter_ids = row.fetch("chapter_ids").split("|").reject(&:empty?)
        if row.fetch("target_kind") == "volume"
          refute_empty chapter_ids
          chapter_ids.each do |chapter_id|
            assert_includes index.chapter_ids, chapter_id
            assert_equal row.fetch("target_id"), index.chapter_volume_slug(chapter_id)
          end
        else
          assert_empty chapter_ids
        end
      end

      public_text = all_public_text(output)
      refute_includes public_text, "RAW_PATH_NEVER_PUBLIC_71A9"
      refute_includes public_text, "RAW_HEADING_NEVER_PUBLIC_7F31"

      raw_files = File.readlines(output.join("private/files.raw.jsonl"), chomp: true).map { |line| JSON.parse(line) }
      raw_sections = File.readlines(output.join("private/sections.raw.jsonl"), chomp: true).map { |line| JSON.parse(line) }
      assert_equal files.length, raw_files.length
      assert_equal mappings.length, raw_sections.length
      assert raw_files.any? { |row| row.fetch("path").include?("RAW_PATH_NEVER_PUBLIC_71A9") }
      assert raw_sections.any? { |row| row.fetch("heading") == "RAW_HEADING_NEVER_PUBLIC_7F31" }
      assert_equal 0o755, File.stat(output).mode & 0o777
      assert_equal 0o700, File.stat(output.join("private")).mode & 0o777
      SourceInventory::PRIVATE_FILES.each do |name|
        assert_equal 0o600, File.stat(output.join("private", name)).mode & 0o777
      end

      catalog.fetch("public_artifacts").each do |name, expected_digest|
        assert_equal expected_digest, Digest::SHA256.file(output.join(name)).hexdigest
      end

      raw_by_path = raw_files.each_with_object({}) { |row, memo| memo[row.fetch("path")] = files_by_id.fetch(row.fetch("file_id")) }
      assert_equal "future-extension", raw_by_path.fetch("08.鸿蒙开发/future.md").fetch("target_kind")
      assert_equal "appendix", raw_by_path.fetch("8.面试题/questions.md").fetch("target_kind")
      assert_equal "exclude-binary-asset", raw_by_path.fetch("04.Vue/no-extension-image").fetch("default_action")
      assert_equal "exclude-generated-build-output", raw_by_path.fetch("target/module.kotlin_module").fetch("default_action")
    end
  end

  def test_inventory_validator_rejects_a_mapping_whose_file_foreign_key_is_unknown
    with_fixture do |fixture|
      builder = builder_for(fixture, output: fixture.root.join("sources"))
      builder.send(:load_repositories)
      builder.send(:inventory_files)
      mapping = builder.instance_variable_get(:@mappings).first
      mapping["file_id"] = "file-#{"0" * 64}"

      error = assert_raises(RuntimeError) { builder.send(:validate_inventory!) }
      assert_match(/unknown file foreign key/, error.message)
    end
  end

  def test_inventory_validator_rejects_noncanonical_targets_and_chapter_ids
    with_fixture do |fixture|
      builder = builder_for(fixture, output: fixture.root.join("bad-target"))
      builder.send(:load_repositories)
      builder.send(:inventory_files)
      file = builder.instance_variable_get(:@files).find { |row| row.fetch("target_kind") == "volume" }
      file["target_id"] = "volume-99-invented"

      error = assert_raises(RuntimeError) { builder.send(:validate_inventory!) }
      assert_match(/target does not match domain policy/, error.message)
    end

    with_fixture do |fixture|
      builder = builder_for(fixture, output: fixture.root.join("bad-chapter"))
      builder.send(:load_repositories)
      builder.send(:inventory_files)
      mapping = builder.instance_variable_get(:@mappings).find { |row| row.fetch("target_kind") == "volume" }
      mapping["chapter_ids"] = "v99.c99.invented"

      error = assert_raises(RuntimeError) { builder.send(:validate_inventory!) }
      assert_match(/unknown canonical chapter/, error.message)
    end
  end

  def test_local_remote_changes_do_not_change_public_artifacts
    with_fixture do |fixture|
      first_output = fixture.root.join("first")
      second_output = fixture.root.join("second")
      builder_for(fixture, output: first_output).run

      fixture.repository_paths.each_value do |repository|
        git!(Pathname(repository), "remote", "set-url", "origin", "ssh://changed.invalid/private/repository.git")
      end
      builder_for(fixture, output: second_output).run

      assert_equal public_snapshot(first_output), public_snapshot(second_output)
      catalog = yaml(second_output.join("catalog.yml"))
      SourceInventory::CANONICAL_REPOSITORIES.each do |key, settings|
        assert_equal settings.fetch("url"), catalog.fetch("repositories").fetch(key).fetch("canonical_url")
      end
    end
  end

  def test_wrong_commit_is_rejected_before_generation
    with_fixture do |fixture|
      output = fixture.root.join("sources")
      expected = fixture.commits.merge("note" => "0" * 40)
      error = assert_raises(RuntimeError) do
        builder_for(fixture, output: output, expected_commits: expected).run
      end
      assert_match(/note commit mismatch/, error.message)
      refute output.exist?
    end
  end

  def test_modified_and_untracked_source_worktrees_are_rejected
    with_fixture do |fixture|
      note = Pathname(fixture.repository_paths.fetch("note"))
      File.open(note.join("04.Vue/components.md"), "ab") { |file| file.write("\nchanged\n") }
      error = assert_raises(RuntimeError) { builder_for(fixture, output: fixture.root.join("modified")).run }
      assert_match(/worktree must be clean/, error.message)
    end

    with_fixture do |fixture|
      note = Pathname(fixture.repository_paths.fetch("note"))
      File.binwrite(note.join("untracked-secret.md"), "# must reject\n")
      error = assert_raises(RuntimeError) { builder_for(fixture, output: fixture.root.join("untracked")).run }
      assert_match(/worktree must be clean/, error.message)
    end
  end

  def test_missing_repository_is_rejected
    with_fixture do |fixture|
      paths = fixture.repository_paths.merge("note" => fixture.root.join("missing-note").to_s)
      error = assert_raises(RuntimeError) do
        builder_for(fixture, output: fixture.root.join("sources"), repository_paths: paths).run
      end
      assert_match(/repository directory does not exist/, error.message)
    end
  end

  def test_tracked_symbolic_links_are_rejected_instead_of_followed
    with_fixture do |fixture|
      note = Pathname(fixture.repository_paths.fetch("note"))
      File.symlink("components.md", note.join("04.Vue/components-link.md"))
      git!(note, "add", "--force", "--all")
      git!(note, "commit", "--quiet", "-m", "add symlink")
      fixture.commits["note"] = git!(note, "rev-parse", "HEAD").strip

      error = assert_raises(RuntimeError) do
        builder_for(fixture, output: fixture.root.join("sources")).run
      end
      assert_match(/symbolic links are not allowed/, error.message)
    end
  end

  def test_check_mode_accepts_current_output_and_rejects_stale_or_extra_public_files
    with_fixture do |fixture|
      output = fixture.root.join("sources")
      builder_for(fixture, output: output, include_private: true).run
      assert builder_for(fixture, output: output, check: true, include_private: true).run

      File.open(output.join("files.csv"), "ab") { |file| file.write("stale") }
      error = assert_raises(RuntimeError) do
        builder_for(fixture, output: output, check: true, include_private: true).run
      end
      assert_match(/stale .*files\.csv/, error.message)

      builder_for(fixture, output: output, include_private: true).run
      File.binwrite(output.join("sections.csv"), "legacy raw public ledger")
      error = assert_raises(RuntimeError) do
        builder_for(fixture, output: output, check: true, include_private: true).run
      end
      assert_match(/unexpected public artifact .*sections\.csv/, error.message)

      FileUtils.rm_f(output.join("sections.csv"))
      File.binwrite(output.join("private/unexpected.txt"), "must be rejected")
      error = assert_raises(RuntimeError) do
        builder_for(fixture, output: output, check: true, include_private: true).run
      end
      assert_match(/unexpected private audit artifact .*unexpected\.txt/, error.message)

      FileUtils.rm_f(output.join("private/unexpected.txt"))
      private_readme = output.join("private/README.md")
      outside_copy = fixture.root.join("outside-private-readme.md")
      FileUtils.cp(private_readme, outside_copy)
      FileUtils.rm_f(private_readme)
      File.symlink(outside_copy, private_readme)
      error = assert_raises(RuntimeError) do
        builder_for(fixture, output: output, check: true, include_private: true).run
      end
      assert_match(/symbolic link is not allowed in private audit output/, error.message)
    end
  end

  def test_rebuild_removes_legacy_public_ledger_and_preserves_private_ledger_when_not_requested
    with_fixture do |fixture|
      output = fixture.root.join("sources")
      builder_for(fixture, output: output, include_private: true).run
      private_before = SourceInventory::PRIVATE_FILES.each_with_object({}) do |name, memo|
        memo[name] = Digest::SHA256.file(output.join("private", name)).hexdigest
      end
      File.binwrite(output.join("sections.csv"), "legacy raw public ledger")

      builder_for(fixture, output: output, include_private: false).run

      refute output.join("sections.csv").exist?
      private_after = SourceInventory::PRIVATE_FILES.each_with_object({}) do |name, memo|
        memo[name] = Digest::SHA256.file(output.join("private", name)).hexdigest
      end
      assert_equal private_before, private_after
    end
  end

  def test_staging_failure_preserves_previous_output_and_cleans_temporary_directory
    with_fixture do |fixture|
      output = fixture.root.join("sources")
      builder_for(fixture, output: output).run
      before = public_snapshot(output)

      failing_builder = Class.new(SourceInventory::Builder) do
        private

        def write_file(path, content, **options)
          @test_write_count = (@test_write_count || 0) + 1
          raise "injected staging failure" if @test_write_count == 2

          super(path, content, **options)
        end
      end

      error = assert_raises(RuntimeError) do
        builder_for(fixture, output: output, builder_class: failing_builder).run
      end
      assert_match(/injected staging failure/, error.message)
      assert_equal before, public_snapshot(output)
      assert_empty Dir.glob(fixture.root.join(".sources.stage-*").to_s)
    end
  end

  def test_actual_pinned_repositories_complete_a_full_build_when_available
    paths = SourceInventory::DEFAULT_REPOSITORIES
    skip "pinned audit repositories are not available" unless paths.values.all? { |path| File.directory?(path) }
    skip "pinned audit repositories are dirty" unless paths.values.all? do |path|
      output, _error, status = Open3.capture3(
        "git", "-C", path, "status", "--porcelain", "--untracked-files=all"
      )
      status.success? && output.empty?
    end

    Dir.mktmpdir("source-inventory-full-build-") do |directory|
      output = Pathname(directory).join("sources")
      SourceInventory::Builder.new(
        repository_paths: paths,
        expected_commits: SourceInventory::EXPECTED_COMMITS,
        output_root: output,
        catalog_path: CATALOG_PATH,
        include_private: false,
        quiet: true
      ).run

      catalog = yaml(output.join("catalog.yml"))
      totals = catalog.fetch("totals")
      assert_equal 3424, totals.fetch("file_count")
      assert_equal 443, totals.fetch("markdown_count")
      assert_equal 14, totals.fetch("pdf_count")
      assert_equal 9174, totals.fetch("section_mapping_count")
      assert_equal 9174, totals.fetch("unreviewed_mapping_count")
      assert_equal 3424, csv_rows(output.join("files.csv")).length
      assert_equal 9174, csv_rows(output.join("mappings.csv")).length
      refute output.join("sections.csv").exist?
      refute output.join("private").exist?
    end
  end
end
