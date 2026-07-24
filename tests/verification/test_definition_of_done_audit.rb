# frozen_string_literal: true

require "json"
require "minitest/autorun"

require_relative "../../verification/lib/definition_of_done_audit"

class DefinitionOfDoneAuditTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def setup
    @report = Verification::DefinitionOfDoneAudit.new(ROOT).report
  end

  def test_report_covers_all_chapters_and_all_checks_without_semantic_promotion
    assert_equal 255, @report.fetch("chapter_total")
    assert_equal 255, @report.fetch("chapters").length
    assert_equal "machine-structural-inventory", @report.dig("evidence_classification", "class")
    assert_equal "forbidden-without-human-review", @report.dig("evidence_classification", "promotion")
    assert_equal 0, @report.fetch("semantic_approval_count")
    assert_equal "incomplete", @report.fetch("status")
    assert_equal 16, @report.fetch("check_catalog").length
    assert_equal 16 * 255, @report.fetch("state_counts").values.sum
  end

  def test_review_batches_are_balanced_and_cover_catalog_order_once
    batches = @report.fetch("review_batches")
    sizes = batches.map { |batch| batch.fetch("chapter_ids").length }

    assert_equal 42, batches.length
    assert sizes.all? { |size| (5..8).cover?(size) }
    assert_equal [6, 7], sizes.uniq.sort
    assert_equal @report.fetch("chapters").map { |chapter| chapter.fetch("chapter_id") },
                 batches.flat_map { |batch| batch.fetch("chapter_ids") }
  end

  def test_every_chapter_has_the_exact_check_catalog_and_human_review_boundary
    expected = @report.fetch("check_catalog").map { |check| check.fetch("id") }
    @report.fetch("chapters").each do |chapter|
      checks = chapter.fetch("checks")
      assert_equal expected, checks.map { |check| check.fetch("id") }
      human = checks.select { |check| check.fetch("class") == "human-review" }
      assert_equal 8, human.length
      assert human.all? { |check| check.fetch("state") == "human-review-required" }
      assert human.all? { |check| !check.fetch("reason").empty? }
    end
  end

  def test_machine_report_is_canonical_and_has_no_absolute_paths_or_timestamps
    bytes = Verification::Canonical.json(@report)
    assert_equal bytes, Verification::Canonical.json(JSON.parse(bytes))
    refute_includes bytes, ROOT
    refute_match(/"(?:generated|checked|observed)_at"/, bytes)
    assert_match(/\A[0-9a-f]{64}\z/, @report.dig("source_set", "sha256"))
  end

  def test_not_applicable_state_requires_a_reason_in_the_schema
    broken = Marshal.load(Marshal.dump(@report))
    check = broken.fetch("chapters").first.fetch("checks").find { |item| item.fetch("class") == "human-review" }
    check["state"] = "not-applicable"
    check.delete("reason")

    error = assert_raises(Verification::ContractError) do
      Verification::MachineReportSchema.validate!(
        root: ROOT,
        schema_path: Verification::DefinitionOfDoneAudit::SCHEMA_PATH,
        document: broken
      )
    end
    assert_equal "E_MACHINE_REPORT_SCHEMA", error.code
  end
end
