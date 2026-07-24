# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "pathname"
require "tmpdir"
require "yaml"

require_relative "../../scripts/audit-curriculum-global"

class GlobalCurriculumAuditTest < Minitest::Test
  ROOT = Pathname(__dir__).join("../..").expand_path

  def test_current_curriculum_passes_reproducible_global_audit
    report = GlobalCurriculumAudit::Auditor.new(ROOT.to_s).report

    assert_equal "passed", report.fetch("status"), report.fetch("failures").join("\n")
    assert_equal 255, report.dig("catalog", "actual")
    assert_equal 16, report.dig("volumes", "count")
    assert_equal 94, report.dig("capabilities", "actual")
    assert_equal 393, report.dig("prerequisites", "edge_count")
    assert_equal 0, report.dig("content", "exact_cross_chapter_duplicate_group_count")
    assert_equal "passed", report.dig("similarity_and_sources", "status")
    assert_equal 255, report.dig("similarity_and_sources", "summary", "chapter_count")
    assert_equal 32_385, report.dig("similarity_and_sources", "summary", "evaluated_pair_count")
    assert_equal 0, report.dig("similarity_and_sources", "summary", "missing_source_chapter_count")
    assert_equal 0, report.dig("similarity_and_sources", "summary", "similarity_violation_count")
    assert_equal 7, report.dig("similarity_and_sources", "parameters", "shingle_size_unicode_characters")
    assert_includes report.dig("similarity_and_sources", "replay_command"), "audit-chapter-similarity.py"
    assert_equal({}, report.dig("goal_alignment", "out_of_scope_canonical_hits"))
  end

  def test_route_inventory_has_three_complete_routes_and_one_selective_project_route
    report = GlobalCurriculumAudit::Auditor.new(ROOT.to_s).report
    routes = report.dig("routes", "items").to_h { |route| [route.fetch("route_id"), route] }

    %w[zero-base accelerated-48 reference].each do |route_id|
      assert_equal 255, routes.fetch(route_id).fetch("unique_chapter_count")
      assert_empty routes.fetch(route_id).fetch("missing_ids")
    end
    assert_equal "selective", routes.fetch("factorycare-project").fetch("coverage_policy")
    assert_equal 205, routes.fetch("factorycare-project").fetch("unique_chapter_count")
  end

  def test_complete_route_drift_fails_closed
    Dir.mktmpdir("global-curriculum-audit-") do |temporary|
      %w[curriculum book].each do |directory|
        FileUtils.cp_r(ROOT.join(directory), temporary, preserve: true)
      end
      route_path = File.join(temporary, "curriculum/routes/zero-base.yml")
      route = YAML.safe_load(File.read(route_path), aliases: false)
      route.fetch("units").first.fetch("chapter_ids").shift
      File.write(route_path, YAML.dump(route))

      report = GlobalCurriculumAudit::Auditor.new(temporary).report

      assert_equal "failed", report.fetch("status")
      assert report.fetch("failures").any? { |failure| failure.include?("complete route zero-base misses 1 chapters") }
    end
  end

  def test_similarity_source_failure_is_propagated_into_global_failures
    Dir.mktmpdir("global-similarity-source-audit-") do |temporary|
      directory = Pathname(temporary).join("book/volume-00-fixture/chapters")
      directory.mkpath
      directory.join("ch.fixture.no-source.md").write(<<~MARKDOWN)
        ---
        schema_version: 2
        id: ch.fixture.no-source
        title: no source fixture
        ---
        # Fixture

        这段夹具正文足以生成七字符切片，但故意没有任何直接 HTTPS 来源。
      MARKDOWN
      auditor = GlobalCurriculumAudit::Auditor.allocate
      auditor.instance_variable_set(:@root, Pathname(temporary).realpath.to_s)
      auditor.instance_variable_set(:@failures, [])

      report = auditor.send(:audit_similarity_and_sources)

      assert_equal "failed", report.fetch("status")
      assert_equal 1, report.dig("summary", "missing_source_chapter_count")
      assert auditor.failures.any? { |failure| failure.include?("ch.fixture.no-source has no direct HTTPS source") }
    end
  end
end
