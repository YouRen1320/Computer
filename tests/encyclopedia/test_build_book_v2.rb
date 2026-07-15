# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "pathname"
require "tmpdir"
require "yaml"

require_relative "../../scripts/build-book"

class BuildBookV2Test < Minitest::Test
  EDITION = "2026.2-draft"
  GENERATED_NAMES = %w[README.md catalog.json navigation.json publication-manifest.json search-index.json].freeze

  # The production builder obtains this set from the strict encyclopedia
  # validator. This seam keeps the unit fixture small while exercising the
  # same path checks, hashing, rendering and atomic output switch.
  class FixtureBookBuilder < BookBuilder
    def initialize(root, inputs:, fail_on_rename: nil, **options)
      @fixture_inputs = inputs
      @fail_on_rename = fail_on_rename
      @rename_count = 0
      super(root, **options)
    end

    private

    def validate_inputs!
      true
    end

    def manifest_inputs(_catalog)
      @fixture_inputs.sort
    end

    def rename_directory(source, destination)
      @rename_count += 1
      raise "injected directory rename failure ##{@rename_count}" if @rename_count == @fail_on_rename

      super
    end
  end

  def with_fixture
    Dir.mktmpdir("build-book-v2-") do |directory|
      root = Pathname(directory).join("repository")
      FileUtils.mkdir_p(root.join("site"))
      inputs = write_fixture(root)
      yield root, inputs
    end
  end

  def write_fixture(root)
    verified_path = "book/volume-00-foundations/chapters/ch.foundations.verified.md"
    planned_path = "book/volume-00-foundations/chapters/ch.foundations.planned.md"
    outcomes = structured_outcomes("verified")
    catalog = {
      "schema_version" => 2,
      "catalog_id" => "factorycare-encyclopedia",
      "edition" => EDITION,
      "chapters" => [
        chapter("ch.foundations.verified", 1, "verified", verified_path, outcomes, ["ruby"]),
        chapter("ch.foundations.planned", 2, "planned", planned_path, structured_outcomes("planned"), [])
      ]
    }
    registry = {
      "schema_version" => 1,
      "registry_id" => "factorycare-version-registry",
      "edition" => EDITION,
      "verified_at" => "2026-07-16",
      "entries" => [{ "id" => "ruby", "name" => "Ruby" }]
    }
    config = {
      "schema_version" => 2,
      "site_id" => "factorycare-encyclopedia",
      "title" => "Fixture Encyclopedia",
      "edition" => EDITION,
      "language" => "zh-CN",
      "catalog" => "curriculum/catalog.yml",
      "version_registry" => "versions/registry.yml",
      "output" => "site/generated",
      "publish_statuses" => ["verified"],
      "preview_statuses" => ["review"],
      "formats" => ["static-json"]
    }

    write_yaml(root, "curriculum/catalog.yml", catalog)
    write_yaml(root, "versions/registry.yml", registry)
    write_yaml(root, "site/config.yml", config)
    write(root, "book/volume-00-foundations/README.md", <<~MARKDOWN)
      <!-- GENERATED: factorycare-curriculum; DO NOT EDIT -->
      # 卷 00：基础卷
    MARKDOWN
    write(root, verified_path, <<~MARKDOWN)
      ---
      id: ch.foundations.verified
      ---
      # 已验证章节

      这是用于搜索摘要的已验证正文，包含稳定且可重复检查的公开说明。

      ## 核心模型

      正文模型。

      ## 故障诊断

      故障路径。
    MARKDOWN
    write(root, planned_path, <<~MARKDOWN)
      ---
      id: ch.foundations.planned
      ---
      # 规划章节

      GENERATED: factorycare-planned-placeholder; safe-to-overwrite: planned-only
    MARKDOWN
    write(root, "curriculum/migrations/application-receipt.schema.json", "{\"schema_version\":1}\n")
    write(root, "curriculum/migrations/receipts/2026.2-application.yml", "schema_version: 1\n")
    write(root, "records/encyclopedia/reviews/P1R-migration-ledger-audit.md", "# Reviewed migration input\n")
    # The production manifest covers the builder itself because changing the
    # renderer changes every output contract.
    write(root, "scripts/build-book.rb", "# fixture renderer input\n")

    [
      "book/volume-00-foundations/README.md",
      verified_path,
      planned_path,
      "curriculum/catalog.yml",
      "curriculum/migrations/application-receipt.schema.json",
      "curriculum/migrations/receipts/2026.2-application.yml",
      "records/encyclopedia/reviews/P1R-migration-ledger-audit.md",
      "scripts/build-book.rb",
      "site/config.yml",
      "versions/registry.yml"
    ]
  end

  def chapter(id, order, status, path, outcomes, version_surfaces)
    {
      "id" => id,
      "title" => "#{status} chapter",
      "responsibility" => "用隔离 fixture 验证站点 v2 的确定性公共契约",
      "volume" => "00",
      "order" => order,
      "level" => "L1",
      "status" => status,
      "prerequisites" => [],
      "outcomes" => outcomes,
      "route_tags" => %w[zero-base reference],
      "stable_core" => true,
      "version_surfaces" => version_surfaces,
      "path" => path
    }
  end

  def structured_outcomes(prefix)
    [
      {
        "id" => "explain",
        "kind" => "concept",
        "text" => "#{prefix} explain outcome",
        "covers_topic_groups" => ["contract"],
        "covers_topics" => ["site.runtime-contract"],
        "uses_capabilities" => [],
        "evidence_kind" => "teach-back",
        "verification_mode" => "oral"
      },
      {
        "id" => "build",
        "kind" => "independent-build",
        "text" => "#{prefix} build outcome",
        "covers_topic_groups" => ["contract"],
        "covers_topics" => ["site.runtime-contract"],
        "uses_capabilities" => [],
        "evidence_kind" => "artifact",
        "verification_mode" => "byte-check"
      },
      {
        "id" => "diagnose",
        "kind" => "fault-diagnosis",
        "text" => "#{prefix} diagnose outcome",
        "covers_topic_groups" => ["contract"],
        "covers_topics" => ["site.runtime-contract"],
        "uses_capabilities" => [],
        "evidence_kind" => "failure-log",
        "verification_mode" => "inject-and-rerun"
      }
    ]
  end

  def write_yaml(root, relative, value)
    write(root, relative, YAML.dump(value))
  end

  def write(root, relative, contents)
    path = root.join(relative)
    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, contents)
  end

  def load_yaml(root, relative)
    YAML.safe_load(File.read(root.join(relative), encoding: "UTF-8"), aliases: false)
  end

  def load_json(root, name)
    JSON.parse(File.read(root.join("site/generated", name), encoding: "UTF-8"))
  end

  def run_builder(root, inputs, **options)
    result = nil
    stdout, stderr = capture_io do
      result = FixtureBookBuilder.new(root.to_s, inputs: inputs, **options).run
    end
    [result, stdout, stderr]
  end

  def generated_snapshot(root)
    GENERATED_NAMES.to_h do |name|
      [name, Digest::SHA256.file(root.join("site/generated", name)).hexdigest]
    end
  end

  def test_builds_schema_v2_runtime_without_legacy_compatibility_and_excludes_planned_search
    with_fixture do |root, inputs|
      result, _stdout, stderr = run_builder(root, inputs)
      assert result, stderr

      catalog = load_json(root, "catalog.json")
      navigation = load_json(root, "navigation.json")
      search = load_json(root, "search-index.json")
      manifest = load_json(root, "publication-manifest.json")
      [catalog, navigation, search, manifest].each { |document| assert_equal 2, document.fetch("schema_version") }

      source = load_yaml(root, "curriculum/catalog.yml").fetch("chapters").first
      record = catalog.fetch("volumes").first.fetch("chapters").first
      assert_equal source.fetch("outcomes"), record.fetch("outcomes")
      assert_equal source.fetch("version_surfaces"), record.fetch("version_surfaces")
      refute record.key?("versioned_surface")

      assert_equal 1, search.fetch("record_count")
      assert_equal ["ch.foundations.verified"], search.fetch("records").map { |entry| entry.fetch("id") }
      assert_equal inputs.sort, manifest.fetch("inputs").keys.sort
      assert_equal inputs.length, manifest.fetch("input_count")

      public_bytes = GENERATED_NAMES.map { |name| File.binread(root.join("site/generated", name)) }.join("\n")
      refute_match(/v\d{2}\.c\d{2}\.[a-z0-9-]+/, public_bytes)
      refute_match(/"(?:alias(?:es)?|redirect(?:s)?)"\s*:/, public_bytes)

      first_snapshot = generated_snapshot(root)
      result, _stdout, stderr = run_builder(root, inputs)
      assert result, stderr
      assert_equal first_snapshot, generated_snapshot(root)

      result, _stdout, stderr = run_builder(root, inputs, check: true)
      assert result, stderr
    end
  end

  def test_manifest_digest_changes_when_a_real_input_changes
    with_fixture do |root, inputs|
      result, _stdout, stderr = run_builder(root, inputs)
      assert result, stderr
      before = load_json(root, "publication-manifest.json").fetch("input_digest")

      File.open(root.join("book/volume-00-foundations/README.md"), "ab") { |file| file.write("\n<!-- changed input -->\n") }
      result, _stdout, stderr = run_builder(root, inputs)
      assert result, stderr
      after = load_json(root, "publication-manifest.json").fetch("input_digest")
      refute_equal before, after
    end
  end

  def test_rejects_site_config_v1_retired_version_field_and_legacy_chapter_id
    with_fixture do |root, inputs|
      config = load_yaml(root, "site/config.yml")
      config["schema_version"] = 1
      write_yaml(root, "site/config.yml", config)
      result, _stdout, stderr = run_builder(root, inputs)
      refute result
      assert_match(/site\/config\.yml schema_version must be 2/, stderr)
    end

    with_fixture do |root, inputs|
      config = load_yaml(root, "site/config.yml")
      config["publish_statuses"] = %w[verified planned]
      write_yaml(root, "site/config.yml", config)
      result, _stdout, stderr = run_builder(root, inputs)
      refute result
      assert_match(/planned chapters must never be publishable or searchable/, stderr)
    end

    with_fixture do |root, inputs|
      catalog = load_yaml(root, "curriculum/catalog.yml")
      chapter = catalog.fetch("chapters").first
      chapter["versioned_surface"] = chapter.delete("version_surfaces")
      write_yaml(root, "curriculum/catalog.yml", catalog)
      result, _stdout, stderr = run_builder(root, inputs)
      refute result
      assert_match(/retired versioned_surface field/, stderr)
    end

    with_fixture do |root, inputs|
      catalog = load_yaml(root, "curriculum/catalog.yml")
      catalog.fetch("chapters").first["id"] = "v00.c01.legacy"
      write_yaml(root, "curriculum/catalog.yml", catalog)
      result, _stdout, stderr = run_builder(root, inputs)
      refute result
      assert_match(/must use semantic ch\.<domain>\.<slug> form/, stderr)
    end
  end

  def test_failed_directory_promotion_restores_previous_generated_bytes
    with_fixture do |root, inputs|
      result, _stdout, stderr = run_builder(root, inputs)
      assert result, stderr
      before = generated_snapshot(root)

      catalog = load_yaml(root, "curriculum/catalog.yml")
      catalog.fetch("chapters").first["title"] = "changed title that must not publish"
      write_yaml(root, "curriculum/catalog.yml", catalog)

      result, _stdout, stderr = run_builder(root, inputs, fail_on_rename: 2)
      refute result
      assert_match(/injected directory rename failure #2/, stderr)
      assert_equal before, generated_snapshot(root)
      assert_empty Dir.glob(root.join("site/.encyclopedia-stage-*").to_s)
      assert_empty Dir.glob(root.join("site/.encyclopedia-backup-*").to_s)
    end

    with_fixture do |root, inputs|
      result, _stdout, stderr = run_builder(root, inputs)
      assert result, stderr
      before = generated_snapshot(root)

      result, _stdout, stderr = run_builder(root, inputs, fail_on_rename: 1)
      refute result
      assert_match(/injected directory rename failure #1/, stderr)
      assert_equal before, generated_snapshot(root)
      assert_empty Dir.glob(root.join("site/.encyclopedia-stage-*").to_s)
      assert_empty Dir.glob(root.join("site/.encyclopedia-backup-*").to_s)
    end
  end

  def test_rejects_alias_and_redirect_compatibility_fields_at_any_output_depth
    with_fixture do |root, inputs|
      catalog = load_yaml(root, "curriculum/catalog.yml")
      catalog.fetch("chapters").first["redirect"] = "ch.foundations.planned"
      write_yaml(root, "curriculum/catalog.yml", catalog)
      result, _stdout, stderr = run_builder(root, inputs)
      refute result
      assert_match(/retired runtime compatibility fields: redirect/, stderr)
    end

    with_fixture do |root, inputs|
      catalog = load_yaml(root, "curriculum/catalog.yml")
      catalog.fetch("chapters").first.fetch("outcomes").first["alias"] = "legacy-outcome"
      write_yaml(root, "curriculum/catalog.yml", catalog)
      result, _stdout, stderr = run_builder(root, inputs)
      refute result
      assert_match(/catalog\.json contains retired alias\/redirect fields: alias/, stderr)
    end
  end

  def test_manifest_allowlist_rejects_untrusted_review_and_private_record_paths
    with_fixture do |root, inputs|
      untrusted = "records/encyclopedia/reviews/untrusted.md"
      write(root, untrusted, "# Not a canonical migration audit\n")
      result, _stdout, stderr = run_builder(root, inputs + [untrusted])
      refute result
      assert_match(/manifest input .*untrusted\.md: path is outside its allowed directory/, stderr)
    end

    with_fixture do |root, inputs|
      private_record = "records/encyclopedia/private/operator-notes.md"
      write(root, private_record, "private notes\n")
      result, _stdout, stderr = run_builder(root, inputs + [private_record])
      refute result
      assert_match(/manifest input .*operator-notes\.md: path is outside its allowed directory/, stderr)
    end
  end
end
