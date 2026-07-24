# frozen_string_literal: true

require "digest"
require "json"

require_relative "test_helper"

class PublicationPlanTest < Minitest::Test
  include PublicationFixture

  P2_NAMES = Publication::PlanBuilder::P2_FILE_SET.freeze

  def test_builds_exact_gold_plan_with_separate_content_and_publisher_inputs
    with_publication_fixture do |root|
      builder = fixture_builder(root)
      first = builder.build
      first_bytes = builder.render(first)
      second_bytes = builder.render(builder.build)

      assert_equal first_bytes.b, second_bytes.b
      assert_equal Publication::P3_GOLD_IDS, first.fetch("chapters").map { |chapter| chapter.fetch("id") }
      assert_equal 54, first.fetch("chapters").sum { |chapter| chapter.fetch("artifacts").length }
      assert_equal 88, first.fetch("input_count")
      assert_equal 58, first.fetch("inputs").count { |entry| entry.fetch("scope") == "content" }
      assert_equal 30, first.fetch("inputs").count { |entry| entry.fetch("scope") == "publisher-contract" }
      assert_equal 10, first.fetch("planned_outputs").length
      assert_equal false, first.fetch("distribution_allowed")
      assert_equal "internal-preview", first.fetch("publication_mode")
      assert_equal "forbidden", first.fetch("resource_policy").fetch("build_network")
      assert_equal "noindex,nofollow", first.fetch("notice").fetch("robots")
      assert_equal [0], first.fetch("security").values.uniq

      paths = first.fetch("inputs").map { |entry| entry.fetch("path") }
      assert_equal paths.uniq.sort, paths.sort
      Publication::PlanBuilder::IMPLEMENTATION_INPUTS.each { |path| assert_includes paths, path }
      refute_match(%r{/Users/|solutions-private/|sources/private/}, first_bytes)
      refute_match(Publication::PRIVATE_CANARY_PATTERN, first_bytes)
    end
  end

  def test_content_and_publisher_digests_change_only_for_their_own_inputs
    with_publication_fixture do |root|
      builder = fixture_builder(root)
      baseline = builder.build

      chapter_path = root.join("book/volume-01-java-language/chapters/ch.java.platform-toolchain.md")
      File.open(chapter_path, "ab") { |file| file.write("\n<!-- fixture content change -->\n") }
      content_changed = fixture_builder(root).build
      refute_equal baseline.fetch("content_input_digest"), content_changed.fetch("content_input_digest")
      assert_equal baseline.fetch("publisher_input_digest"), content_changed.fetch("publisher_input_digest")
      refute_equal baseline.fetch("build_input_digest"), content_changed.fetch("build_input_digest")

      File.binwrite(chapter_path, File.binread(PublicationFixture::ROOT.join("book/volume-01-java-language/chapters/ch.java.platform-toolchain.md")))
      manifest_path = "publication/manifests/public-artifacts/ch.java.platform-toolchain.yml"
      manifest = read_yaml(root, manifest_path)
      manifest.fetch("artifacts").first["presentation"] = "download"
      write_yaml(root, manifest_path, manifest)
      publisher_changed = fixture_builder(root).build
      assert_equal baseline.fetch("content_input_digest"), publisher_changed.fetch("content_input_digest")
      refute_equal baseline.fetch("publisher_input_digest"), publisher_changed.fetch("publisher_input_digest")
      refute_equal baseline.fetch("build_input_digest"), publisher_changed.fetch("build_input_digest")
    end
  end

  def test_rejects_noncanonical_selection_and_planned_chapter
    with_publication_fixture do |root|
      profile = read_yaml(root, PROFILE_PATH)
      profile["chapter_ids"] = profile.fetch("chapter_ids").first(3)
      profile["drafting_allowlist"] = profile.fetch("drafting_allowlist").first(3)
      write_yaml(root, PROFILE_PATH, profile)
      assert_contract_code("E_P3_ALLOWLIST") { fixture_builder(root).build }
    end

    with_publication_fixture do |root|
      catalog = read_yaml(root, "curriculum/catalog.yml")
      selected = catalog.fetch("chapters").find { |chapter| chapter.fetch("id") == Publication::P3_GOLD_IDS.first }
      selected["status"] = "planned"
      write_yaml(root, "curriculum/catalog.yml", catalog)
      assert_contract_code("E_STATUS_PLANNED") { fixture_builder(root).build }
    end
  end

  def test_status_gate_accepts_review_and_rejects_verified_for_internal_preview
    with_publication_fixture do |root|
      catalog = read_yaml(root, "curriculum/catalog.yml")
      catalog.fetch("chapters").each do |chapter|
        chapter["status"] = "review" if Publication::P3_GOLD_IDS.include?(chapter.fetch("id"))
      end
      write_yaml(root, "curriculum/catalog.yml", catalog)
      profile = read_yaml(root, PROFILE_PATH)
      profile["drafting_allowlist"] = []
      write_yaml(root, PROFILE_PATH, profile)

      plan = fixture_builder(root).build
      assert_equal ["review"], plan.fetch("chapters").map { |chapter| chapter.fetch("status") }.uniq
    end

    with_publication_fixture do |root|
      catalog = read_yaml(root, "curriculum/catalog.yml")
      catalog.fetch("chapters").each do |chapter|
        chapter["status"] = "verified" if Publication::P3_GOLD_IDS.include?(chapter.fetch("id"))
      end
      write_yaml(root, "curriculum/catalog.yml", catalog)
      profile = read_yaml(root, PROFILE_PATH)
      profile["drafting_allowlist"] = []
      write_yaml(root, PROFILE_PATH, profile)

      assert_contract_code("E_STATUS_INTERNAL") { fixture_builder(root).build }
    end
  end

  def test_rejects_extra_or_missing_p2_output_even_when_external_checker_passes
    with_publication_fixture do |root|
      File.binwrite(root.join("site/generated/stale.json"), "{}\n")
      assert_contract_code("E_P2_OUTPUT_EXTRA") { fixture_builder(root).build }
    end

    with_publication_fixture do |root|
      FileUtils.rm_f(root.join("site/generated/search-index.json"))
      assert_contract_code("E_P2_OUTPUT_MISSING") { fixture_builder(root).build }
    end
  end

  def test_rejects_required_tool_version_mismatch
    with_publication_fixture do |root|
      observer = ->(_command) { ["ruby 3.4.0", true] }
      assert_contract_code("E_TOOL_VERSION") { fixture_builder(root, tool_observer: observer).build }
    end
  end

  def test_rejects_tool_command_tampering_before_any_command_runs
    with_publication_fixture do |root|
      toolchain = read_yaml(root, "publication/toolchain.yml")
      ruby_tool = toolchain.fetch("tools").find { |tool| tool.fetch("id") == "ruby" }
      ruby_tool["command"] = ["sh", "-c", "exit 99"]
      write_yaml(root, "publication/toolchain.yml", toolchain)
      observer_called = false
      observer = lambda do |_command|
        observer_called = true
        ["ruby 2.6.10p210", true]
      end

      assert_contract_code("E_TOOL_POLICY") { fixture_builder(root, tool_observer: observer).build }
      refute observer_called
    end
  end

  def test_rejects_private_canary_in_notice_and_release_mode_in_schema_v1
    with_publication_fixture do |root|
      profile = read_yaml(root, PROFILE_PATH)
      profile.fetch("notice")["text"] = "PRIVATE_SOLUTION_DO_NOT_PUBLISH_FIXTURE"
      write_yaml(root, PROFILE_PATH, profile)
      assert_contract_code("E_PRIVATE_CANARY") { fixture_builder(root).build }
    end

    with_publication_fixture do |root|
      profile = read_yaml(root, PROFILE_PATH)
      profile["publication_mode"] = "release"
      profile["visibility"] = "public"
      profile["distribution_allowed"] = true
      write_yaml(root, PROFILE_PATH, profile)
      assert_contract_code("E_SCHEMA_INSTANCE") { fixture_builder(root).build }
    end
  end

  def test_rejects_an_input_change_during_plan_assembly
    mutating_builder = Class.new(Publication::PlanBuilder) do
      private

      def entries_digest(entries)
        unless defined?(@fixture_mutated)
          @fixture_mutated = true
          path = File.join(root, "book/volume-01-java-language/chapters/ch.java.platform-toolchain.md")
          File.open(path, "ab") { |file| file.write("\n<!-- concurrent fixture mutation -->\n") }
        end
        super
      end
    end

    with_publication_fixture do |root|
      builder = mutating_builder.new(
        root.to_s,
        profile_path: PROFILE_PATH,
        p2_checker: -> { true },
        tool_observer: ->(_command) { ["ruby 2.6.10p210", true] }
      )
      assert_contract_code("E_INPUT_CHANGED") { builder.build }
    end
  end

  def test_file_mode_is_not_a_build_input
    with_publication_fixture do |root|
      builder = fixture_builder(root)
      baseline = builder.render(builder.build)
      script = root.join("examples/encyclopedia/ch.java.platform-toolchain/scripts/verify.sh")
      File.chmod(0o600, script)
      after_mode_change = fixture_builder(root).render

      assert_equal baseline.b, after_mode_change.b
    end
  end

  def test_production_plan_build_does_not_change_the_p2_five_file_bytes
    before = p2_snapshot(PublicationFixture::ROOT)
    Publication::PlanBuilder.new(
      PublicationFixture::ROOT.to_s,
      profile_path: PROFILE_PATH
    ).build
    assert_equal before, p2_snapshot(PublicationFixture::ROOT)
  end

  private

  def p2_snapshot(root)
    P2_NAMES.to_h do |name|
      [name, Digest::SHA256.file(root.join("site/generated", name)).hexdigest]
    end
  end
end
