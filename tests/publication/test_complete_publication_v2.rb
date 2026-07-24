# frozen_string_literal: true

require "json"
require "open3"

require_relative "test_helper"
require_relative "../../publication/lib/complete_plan_builder"
require_relative "../../publication/lib/complete_renderer"

class CompletePublicationV2Test < Minitest::Test
  include PublicationFixture

  def test_complete_screen_css_reflows_code_and_tables_without_scroll_regions
    css = File.read(PublicationFixture::ROOT.join("publication/styles/internal-complete-screen.css"))

    refute_match(/overflow-x:\s*auto/, css)
    assert_match(/table-layout:\s*fixed/, css)
    assert_match(/code\.sourceCode span\s*\{\s*color:\s*inherit;/, css)
    assert_match(/body\s*\{[^}]*overflow-wrap:\s*anywhere;/m, css)
  end

  def test_production_plan_is_deterministic_and_covers_the_complete_catalog
    builder = Publication::CompletePlanBuilder.new(PublicationFixture::ROOT.to_s)
    first = builder.build
    second = builder.build

    assert_equal builder.render(first).b, builder.render(second).b
    assert_equal 255, first.fetch("chapters").length
    assert_equal 16, first.fetch("volumes").length
    assert_equal 4_123, first.fetch("companions").length
    assert_equal 4_398, first.fetch("inputs").length
    assert_equal 345, first.fetch("planned_outputs").length
    assert_equal ["drafting"], first.fetch("chapters").map { |chapter| chapter.fetch("status") }.uniq
    assert_equal false, first.fetch("distribution_allowed")
    assert_equal "internal-complete", first.fetch("profile_id")
    refute_match(%r{/Users/|solutions-private/|sources/private/}, builder.render(first))
  end

  def test_companion_inventory_exactly_matches_git_tracked_public_roots
    plan = Publication::CompletePlanBuilder.new(PublicationFixture::ROOT.to_s).build
    stdout, stderr, status = Open3.capture3(
      "git", "-C", PublicationFixture::ROOT.to_s, "ls-files", "-z", "--",
      "examples/encyclopedia", "labs/encyclopedia", "exercises/encyclopedia"
    )
    assert status.success?, stderr
    expected = stdout.split("\0").reject(&:empty?).sort
    actual = plan.fetch("companions").map { |entry| entry.fetch("path") }.sort

    assert_equal expected, actual
    assert plan.fetch("companions").all? { |entry| %w[100644 100755].include?(entry.fetch("git_mode")) }
  end

  def test_plan_write_and_check_preserve_an_existing_render_tree
    Dir.mktmpdir("complete-plan-writer-") do |directory|
      root = Pathname(directory).join("repository")
      FileUtils.mkdir_p(root.join("build/publication/internal-complete/output/html"))
      marker = root.join("build/publication/internal-complete/output/html/existing.html")
      File.binwrite(marker, "existing\n")
      builder = Publication::CompletePlanBuilder.new(root.to_s)
      plan = { "fixture" => "内部计划" }

      builder.write(plan)
      assert builder.check(plan)
      assert_equal "existing\n", File.binread(marker)
    end
  end

  def test_git_inventory_ignores_untracked_files_and_accepts_tracked_regular_files
    with_companion_git_fixture do |root, builder, profile, chapters|
      owner = root.join("examples/encyclopedia/ch.fixture")
      File.binwrite(owner.join("tracked.txt"), "tracked\n")
      File.binwrite(owner.join("untracked.txt"), "PRIVATE_SOLUTION_DO_NOT_PUBLISH_UNTRACKED\n")
      git!(root, "add", "examples/encyclopedia/ch.fixture/tracked.txt")

      records = builder.send(:tracked_companions!, profile, chapters)
      assert_equal ["examples/encyclopedia/ch.fixture/tracked.txt"], records.map { |record| record.fetch("path") }
    end
  end

  def test_git_inventory_rejects_working_tree_bytes_that_differ_from_the_index
    with_companion_git_fixture do |root, builder, profile, chapters|
      path = "examples/encyclopedia/ch.fixture/tracked.txt"
      absolute = root.join(path)
      File.binwrite(absolute, "indexed\n")
      git!(root, "add", path)
      File.binwrite(absolute, "working-tree-only\n")

      assert_contract_code("E_COMPANION_INDEX_DRIFT") do
        builder.send(:tracked_companions!, profile, chapters)
      end

      git!(root, "add", path)
      record = builder.send(:tracked_companions!, profile, chapters).fetch(0)
      stdout, stderr, status = Open3.capture3("git", "-C", root.to_s, "hash-object", "--", path)
      assert status.success?, stderr
      assert_equal stdout.strip, record.fetch("git_blob")
      assert_equal Digest::SHA256.hexdigest("working-tree-only\n"), record.fetch("sha256")
    end
  end

  def test_git_inventory_rejects_tracked_symlinks_and_private_canaries
    with_companion_git_fixture do |root, builder, profile, chapters|
      owner = root.join("examples/encyclopedia/ch.fixture")
      File.binwrite(owner.join("target.txt"), "target\n")
      File.symlink("target.txt", owner.join("linked.txt"))
      git!(root, "add", "examples/encyclopedia/ch.fixture/linked.txt")

      assert_contract_code("E_PATH_SYMLINK") { builder.send(:tracked_companions!, profile, chapters) }
    end

    with_companion_git_fixture do |root, builder, profile, chapters|
      owner = root.join("examples/encyclopedia/ch.fixture")
      File.binwrite(owner.join("canary.txt"), "PRIVATE_SOLUTION_DO_NOT_PUBLISH_FIXTURE\n")
      git!(root, "add", "examples/encyclopedia/ch.fixture/canary.txt")

      assert_contract_code("E_PRIVATE_CANARY") { builder.send(:tracked_companions!, profile, chapters) }
    end
  end

  def test_git_inventory_rejects_tracked_generated_output
    with_companion_git_fixture do |root, builder, profile, chapters|
      generated = root.join("examples/encyclopedia/ch.fixture/build/generated.txt")
      FileUtils.mkdir_p(generated.dirname)
      File.binwrite(generated, "generated\n")
      git!(root, "add", "-f", "examples/encyclopedia/ch.fixture/build/generated.txt")

      assert_contract_code("E_COMPANION_GENERATED") { builder.send(:tracked_companions!, profile, chapters) }
    end
  end

  def test_projection_copies_only_selected_blocks_and_sanitizes_sensitive_references
    renderer = Publication::CompleteRenderer.new(PublicationFixture::ROOT.to_s)
    notice = { "t" => "Div", "c" => [["publication-notice", [], []], []] }
    selected = { "t" => "Div", "c" => [["ch.selected", [], []], [{ "t" => "Para", "c" => [] }]] }
    other = { "t" => "Div", "c" => [["ch.other", [], []], []] }
    canonical = { "pandoc-api-version" => [1, 23, 1], "meta" => {}, "blocks" => [notice, selected, other] }

    projection = renderer.send(:projection_document, canonical, [selected])
    assert_equal 2, projection.fetch("blocks").length
    assert_equal "ch.selected", projection.fetch("blocks").last.dig("c", 0, 0)
    projection.fetch("blocks").last.fetch("c").first[0] = "changed"
    assert_equal "ch.selected", selected.dig("c", 0, 0), "projection must not mutate the canonical AST"

    sanitized = renderer.send(
      :sanitize_sensitive_references,
      { "text" => "solutions-private/encyclopedia/ch.fixture/README.md /Users/example/project" }
    )
    refute_includes sanitized.fetch("text"), "solutions-private"
    refute_includes sanitized.fetch("text"), "/Users/"
  end

  def test_raw_html_type_placeholders_become_code_and_other_raw_html_is_rejected
    renderer = Publication::CompleteRenderer.new(PublicationFixture::ROOT.to_s)
    document = {
      "blocks" => [
        { "t" => "RawBlock", "c" => ["html", "<!-- BEGIN GENERATED LEARNING PREREQUISITES -->"] },
        { "t" => "Para", "c" => [{ "t" => "RawInline", "c" => ["html", "<WorkOrder>"] }] }
      ]
    }

    renderer.send(:normalize_raw_html_literals!, document)
    literal = document.dig("blocks", 1, "c", 0)
    assert_equal "Code", literal.fetch("t")
    assert_equal "<WorkOrder>", literal.dig("c", 1)
    renderer.send(:validate_raw_ast!, document)

    unsafe = { "blocks" => [{ "t" => "RawBlock", "c" => ["html", "<img src='https://example.invalid/x'>"] }] }
    assert_contract_code("E_UNSAFE_RAW_HTML") { renderer.send(:normalize_raw_html_literals!, unsafe) }
  end

  def test_complete_epub_metadata_uses_a_nonempty_calendar_date
    renderer = Publication::CompleteRenderer.new(PublicationFixture::ROOT.to_s)
    plan = {
      "source_date_epoch" => 1_784_160_000,
      "notice" => { "text" => "internal", "robots" => "noindex,nofollow" },
      "language" => "zh-CN",
      "edition" => "2026.2-draft"
    }

    metadata = renderer.send(:canonical_metadata, plan, "title")

    assert_equal "2026-07-16", metadata.fetch("date").fetch("c")
  end

  def test_complete_epub_metadata_describes_accessibility_without_claiming_conformance
    renderer = Publication::CompleteRenderer.allocate
    plan = {
      "source_date_epoch" => Time.utc(2026, 7, 16).to_i,
      "notice" => { "text" => "内部候选", "robots" => "noindex,nofollow,noarchive" },
      "edition" => "2026.07",
      "language" => "zh-CN"
    }

    metadata = renderer.send(:canonical_metadata, plan, "title")
    summary = metadata.fetch("accessibilitySummary").fetch("c")

    assert_includes summary, "尚未完成独立人工检查"
    refute metadata.key?("conformsTo")
    refute metadata.key?("certifiedBy")
    refute metadata.key?("certifierCredential")
    refute metadata.key?("certifierReport")
  end

  def test_existing_production_tree_passes_the_full_non_mutating_gate
    output = PublicationFixture::ROOT.join("build/publication/internal-complete/publication-output-manifest-v2.json")
    skip "run scripts/build-complete-publication.rb before this integration check" unless output.file?

    assert Publication::CompleteRenderer.new(PublicationFixture::ROOT.to_s).check
    manifest = JSON.parse(File.read(output, encoding: "UTF-8"))
    assert_equal 344, manifest.fetch("output_count")
    assert_equal 324, manifest.fetch("commands").length
  end

  def test_full_production_entity_generation_when_explicitly_requested
    skip "set FACTORYCARE_REBUILD_COMPLETE_PUBLICATION=1 for the approximately eight-minute build" unless ENV["FACTORYCARE_REBUILD_COMPLETE_PUBLICATION"] == "1"

    builder = Publication::CompletePlanBuilder.new(PublicationFixture::ROOT.to_s)
    builder.write(builder.build)
    result = Publication::CompleteRenderer.new(PublicationFixture::ROOT.to_s).build
    assert_equal 344, result.fetch("manifest").fetch("output_count")
    assert Publication::CompleteRenderer.new(PublicationFixture::ROOT.to_s).check
  end

  private

  def with_companion_git_fixture
    Dir.mktmpdir("complete-companion-") do |directory|
      root = Pathname(directory).join("repository")
      FileUtils.mkdir_p(root.join("examples/encyclopedia/ch.fixture"))
      FileUtils.mkdir_p(root.join("labs/encyclopedia/ch.fixture"))
      FileUtils.mkdir_p(root.join("exercises/encyclopedia/ch.fixture"))
      git!(root, "init", "-q")
      profile = {
        "companion_inventory" => {
          "roots" => ["examples/encyclopedia", "labs/encyclopedia", "exercises/encyclopedia"]
        }
      }
      chapters = [{ "id" => "ch.fixture" }]
      yield root, Publication::CompletePlanBuilder.new(root.to_s), profile, chapters
    end
  end

  def git!(root, *arguments)
    _stdout, stderr, status = Open3.capture3("git", "-C", root.to_s, *arguments)
    raise stderr unless status.success?
  end
end
