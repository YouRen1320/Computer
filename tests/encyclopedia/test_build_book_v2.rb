# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "pathname"
require "tmpdir"
require "yaml"

require_relative "../../scripts/build-book"

class BuildBookV3Test < Minitest::Test
  ROOT = Pathname(__dir__).join("../..").expand_path.freeze
  EDITION = "2026.2-draft"
  GENERATED_NAMES = %w[README.md catalog.json navigation.json publication-manifest.json search-index.json].freeze

  # The production builder obtains this set from the strict encyclopedia
  # validator. This seam keeps the unit fixture small while exercising the
  # same path checks, hashing, rendering and atomic output switch.
  class FixtureBookBuilder < BookBuilder
    def initialize(root, inputs:, categories: nil, fail_on_rename: nil, **options)
      @fixture_inputs = inputs
      @fixture_categories = categories
      @fail_on_rename = fail_on_rename
      @rename_count = 0
      super(root, **options)
    end

    private

    def validate_inputs!
      true
    end

    def manifest_input_inventory(_catalog)
      categories = @fixture_categories || @fixture_inputs.each_with_object(
        EncyclopediaInputSet::CATEGORY_ORDER.to_h { |category| [category, []] }
      ) do |path, memo|
        category = EncyclopediaInputSet.category_for(path)
        raise "fixture input lacks a category: #{path}" unless category

        memo.fetch(category) << path
      end
      categories = categories.transform_values(&:sort)
      { categories: categories, expected: @fixture_inputs.sort }
    end

    def rename_directory(source, destination)
      @rename_count += 1
      raise "injected directory rename failure ##{@rename_count}" if @rename_count == @fail_on_rename

      super
    end
  end

  def with_fixture
    Dir.mktmpdir("build-book-v3-") do |directory|
      root = Pathname(directory).join("repository")
      FileUtils.mkdir_p(root.join("site"))
      inputs = write_fixture(root)
      track_fixture(root)
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
      "reviewed_at" => "2026-07-24",
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
    write(root, "schemas/public-artifact-manifest.schema.json", File.binread(ROOT.join("schemas/public-artifact-manifest.schema.json")))
    write(root, "schemas/site-publication-manifest-v3.schema.json", File.binread(ROOT.join("schemas/site-publication-manifest-v3.schema.json")))

    [
      "book/volume-00-foundations/README.md",
      verified_path,
      planned_path,
      "curriculum/catalog.yml",
      "curriculum/migrations/application-receipt.schema.json",
      "curriculum/migrations/receipts/2026.2-application.yml",
      "records/encyclopedia/reviews/P1R-migration-ledger-audit.md",
      "schemas/public-artifact-manifest.schema.json",
      "schemas/site-publication-manifest-v3.schema.json",
      "scripts/build-book.rb",
      "site/config.yml",
      "versions/registry.yml"
    ]
  end

  def track_fixture(root)
    _stdout, stderr, status = Open3.capture3("git", "init", "--quiet", chdir: root.to_s)
    raise "fixture git init failed: #{stderr}" unless status.success?
    _stdout, stderr, status = Open3.capture3("git", "add", "--all", chdir: root.to_s)
    raise "fixture git add failed: #{stderr}" unless status.success?
  end

  def chapter(id, order, status, path, outcomes, version_surfaces)
    {
      "id" => id,
      "title" => "#{status} chapter",
      "responsibility" => "用隔离 fixture 验证站点 v3 的确定性公共契约",
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

  def run_builder(root, inputs, categories: nil, **options)
    result = nil
    stdout, stderr = capture_io do
      result = FixtureBookBuilder.new(root.to_s, inputs: inputs, categories: categories, **options).run
    end
    [result, stdout, stderr]
  end

  def generated_snapshot(root)
    GENERATED_NAMES.to_h do |name|
      [name, Digest::SHA256.file(root.join("site/generated", name)).hexdigest]
    end
  end

  def test_builds_schema_v3_runtime_with_disjoint_inputs_and_excludes_planned_search
    with_fixture do |root, inputs|
      result, _stdout, stderr = run_builder(root, inputs)
      assert result, stderr

      catalog = load_json(root, "catalog.json")
      navigation = load_json(root, "navigation.json")
      search = load_json(root, "search-index.json")
      manifest = load_json(root, "publication-manifest.json")
      [catalog, navigation, search, manifest].each { |document| assert_equal 3, document.fetch("schema_version") }

      source = load_yaml(root, "curriculum/catalog.yml").fetch("chapters").first
      record = catalog.fetch("volumes").first.fetch("chapters").first
      assert_equal source.fetch("outcomes"), record.fetch("outcomes")
      assert_equal source.fetch("version_surfaces"), record.fetch("version_surfaces")
      refute record.key?("versioned_surface")

      assert_equal 1, search.fetch("record_count")
      assert_equal ["ch.foundations.verified"], search.fetch("records").map { |entry| entry.fetch("id") }
      categorized_paths = manifest.fetch("inputs").values.flat_map(&:keys)
      assert_equal inputs.sort, categorized_paths.sort
      assert_equal inputs.length, manifest.fetch("input_counts").fetch("total")
      assert_equal categorized_paths.length, categorized_paths.uniq.length
      assert_equal EncyclopediaInputSet::CATEGORY_ORDER, manifest.fetch("inputs").keys
      assert_equal EncyclopediaInputSet::CATEGORY_DIGEST_ALGORITHM,
                   manifest.fetch("digest_algorithms").fetch("category")
      assert_equal EncyclopediaInputSet::TOTAL_DIGEST_ALGORITHM,
                   manifest.fetch("digest_algorithms").fetch("total")
      refute manifest.key?("input_digest")
      [catalog, navigation, search].each do |document|
        assert_equal manifest.fetch("input_digests"), document.fetch("input_digests")
        refute document.key?("input_digest")
      end

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

  def test_only_the_owning_category_and_total_digest_change_for_an_input
    with_fixture do |root, inputs|
      result, _stdout, stderr = run_builder(root, inputs)
      assert result, stderr
      before = load_json(root, "publication-manifest.json").fetch("input_digests")

      File.open(root.join("book/volume-00-foundations/README.md"), "ab") { |file| file.write("\n<!-- changed input -->\n") }
      result, _stdout, stderr = run_builder(root, inputs)
      assert result, stderr
      after = load_json(root, "publication-manifest.json").fetch("input_digests")
      refute_equal before.fetch("content"), after.fetch("content")
      assert_equal before.fetch("audit_security"), after.fetch("audit_security")
      assert_equal before.fetch("build_control"), after.fetch("build_control")
      refute_equal before.fetch("total"), after.fetch("total")
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
      assert_match(/catalog\.json: schema v3 violation: .*additional property alias is not allowed/, stderr)
    end
  end

  def test_manifest_allowlist_rejects_untrusted_review_and_private_record_paths
    with_fixture do |root, inputs|
      untrusted = "records/encyclopedia/reviews/untrusted.md"
      write(root, untrusted, "# Not a canonical migration audit\n")
      _stdout, git_stderr, git_status = Open3.capture3("git", "add", untrusted, chdir: root.to_s)
      assert git_status.success?, git_stderr
      result, _stdout, stderr = run_builder(root, inputs + [untrusted])
      refute result
      assert_match(/manifest input .*untrusted\.md: path is outside its allowed directory/, stderr)
    end

    with_fixture do |root, inputs|
      private_record = "records/encyclopedia/private/operator-notes.md"
      write(root, private_record, "private notes\n")
      _stdout, git_stderr, git_status = Open3.capture3("git", "add", private_record, chdir: root.to_s)
      assert git_status.success?, git_stderr
      categories = categories_for(inputs)
      categories.fetch("audit_security") << private_record
      result, _stdout, stderr = run_builder(root, inputs + [private_record], categories: categories)
      refute result
      assert_match(/manifest input .*operator-notes\.md: path is outside its allowed directory/, stderr)
    end
  end

  def test_rejects_category_overlap_and_omission_before_hashing
    with_fixture do |root, inputs|
      categories = categories_for(inputs)
      overlap = categories.fetch("content").first
      categories.fetch("audit_security") << overlap
      result, _stdout, stderr = run_builder(root, inputs, categories: categories)
      refute result
      assert_match(/E_INPUT_CATEGORY_OVERLAP.*#{Regexp.escape(overlap)}/, stderr)
    end

    with_fixture do |root, inputs|
      categories = categories_for(inputs)
      omitted = categories.fetch("content").first
      categories.fetch("content").delete(omitted)
      result, _stdout, stderr = run_builder(root, inputs, categories: categories)
      refute result
      assert_match(/E_INPUT_CATEGORY_OMISSION.*#{Regexp.escape(omitted)}/, stderr)
    end
  end

  def test_rejects_untracked_temporary_and_symbolic_link_inputs
    with_fixture do |root, inputs|
      untracked = "book/volume-00-foundations/chapters/ch.foundations.untracked.md"
      write(root, untracked, "# untracked\n")
      result, _stdout, stderr = run_builder(root, inputs + [untracked])
      refute result
      assert_match(/E_INPUT_UNTRACKED.*untracked\.md/, stderr)
    end

    with_fixture do |root, inputs|
      temporary = "book/volume-00-foundations/build/cache.tmp"
      write(root, temporary, "temporary\n")
      _stdout, stderr, status = Open3.capture3("git", "add", temporary, chdir: root.to_s)
      assert status.success?, stderr
      result, _stdout, stderr = run_builder(root, inputs + [temporary])
      refute result
      assert_match(/E_INPUT_TEMPORARY.*cache\.tmp/, stderr)
    end

    with_fixture do |root, inputs|
      linked = "book/volume-00-foundations/chapters/ch.foundations.linked.md"
      File.symlink("ch.foundations.verified.md", root.join(linked))
      _stdout, stderr, status = Open3.capture3("git", "add", linked, chdir: root.to_s)
      assert status.success?, stderr
      result, _stdout, stderr = run_builder(root, inputs + [linked])
      refute result
      assert_match(/symbolic links are forbidden/, stderr)
    end
  end

  def test_rejects_category_and_digest_drift_in_schema_v3_outputs
    with_fixture do |root, inputs|
      builder = FixtureBookBuilder.new(root.to_s, inputs: inputs)
      catalog = builder.send(:load_yaml, "curriculum/catalog.yml")
      registry = builder.send(:load_yaml, "versions/registry.yml")
      config = builder.send(:load_yaml, "site/config.yml")
      inventory = builder.send(:manifest_input_inventory, catalog)
      rendered = builder.send(:render_files, catalog, registry, config)

      manifest = JSON.parse(rendered.fetch("publication-manifest.json"))
      path, sha256 = manifest.fetch("inputs").fetch("content").first
      manifest.fetch("inputs").fetch("content").delete(path)
      manifest.fetch("inputs").fetch("audit_security")[path] = sha256
      rendered["publication-manifest.json"] = JSON.pretty_generate(manifest) + "\n"
      error = assert_raises(RuntimeError) do
        builder.send(:validate_runtime_outputs!, rendered, inventory: inventory)
      end
      assert_match(/input categories differ from the authoritative inventory/, error.message)

      rendered = builder.send(:render_files, catalog, registry, config)
      documents = %w[catalog.json navigation.json search-index.json publication-manifest.json].to_h do |name|
        [name, JSON.parse(rendered.fetch(name))]
      end
      documents.each_value { |document| document.fetch("input_digests")["total"] = "0" * 64 }
      documents.each { |name, document| rendered[name] = JSON.pretty_generate(document) + "\n" }
      error = assert_raises(RuntimeError) do
        builder.send(:validate_runtime_outputs!, rendered, inventory: inventory)
      end
      assert_match(/input digests are not recomputable/, error.message)
    end
  end

  private

  def categories_for(inputs)
    categories = EncyclopediaInputSet::CATEGORY_ORDER.to_h { |category| [category, []] }
    inputs.each { |path| categories.fetch(EncyclopediaInputSet.category_for(path)) << path }
    categories.transform_values(&:sort)
  end
end
