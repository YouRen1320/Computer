# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "tmpdir"
require "yaml"

class ValidateCatalogTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  WORKSPACE_ENTRIES = %w[ASSESSMENTS.md PROGRESS.md book curriculum versions].freeze

  def with_workspace
    Dir.mktmpdir("catalog-validation-") do |workspace|
      WORKSPACE_ENTRIES.each do |entry|
        FileUtils.cp_r(File.join(ROOT, entry), File.join(workspace, entry))
      end
      yield workspace
    end
  end

  def load_yaml(path)
    YAML.safe_load(File.read(path, encoding: "UTF-8"), aliases: false)
  end

  def write_yaml(path, document)
    File.write(path, YAML.dump(document), mode: "w", encoding: "UTF-8")
  end

  def mutate_catalog(workspace)
    path = File.join(workspace, "curriculum", "catalog.yml")
    catalog = load_yaml(path)
    yield catalog
    write_yaml(path, catalog)
  end

  def replace_chapter(workspace, chapter, status:, placeholder:)
    path = File.join(workspace, chapter.fetch("path"))
    body = File.read(path, encoding: "UTF-8")
    match = body.match(/\A---\s*\n(.*?)\n---\s*\n/m)
    raise "missing front matter in #{path}" unless match

    metadata = YAML.safe_load(match[1], aliases: false)
    metadata["status"] = status
    content = if placeholder
      "# #{chapter.fetch("title")}\n\n本章尚无教材正文，不能作为已完成学习材料。\n"
    else
      "# #{chapter.fetch("title")}\n\n## 可观察目标\n\n这是一段用于验证目录状态迁移的真实正文。\n\n## 验证\n\n读者可以观察并复核该状态迁移。\n"
    end
    front_matter = YAML.dump(metadata).delete_prefix("---\n")
    File.write(path, "---\n#{front_matter}---\n#{content}", mode: "w", encoding: "UTF-8")
  end

  def run_validator(workspace)
    Open3.capture3("ruby", "curriculum/validate_catalog.rb", chdir: workspace)
  end

  def assert_invalid(workspace, message)
    stdout, stderr, status = run_validator(workspace)
    refute status.success?, "expected validation failure, got:\n#{stdout}\n#{stderr}"
    assert_includes "#{stdout}\n#{stderr}", message
  end

  def test_repository_baseline_is_valid
    with_workspace do |workspace|
      stdout, stderr, status = run_validator(workspace)
      assert status.success?, "#{stdout}\n#{stderr}"
      assert_includes stdout, "chapters=170"
      assert_includes stdout, "phase=architecture"
    end
  end

  def test_architecture_phase_rejects_non_planned_chapter
    with_workspace do |workspace|
      chapter = nil
      mutate_catalog(workspace) do |catalog|
        chapter = catalog.fetch("chapters").first
        chapter["status"] = "drafting"
      end
      replace_chapter(workspace, chapter, status: "drafting", placeholder: false)
      assert_invalid(workspace, "status drafting is not allowed while catalog phase is architecture")
    end
  end

  def test_authoring_phase_accepts_real_drafting_chapter
    with_workspace do |workspace|
      chapter = nil
      mutate_catalog(workspace) do |catalog|
        catalog["status"] = "authoring"
        chapter = catalog.fetch("chapters").first
        chapter["status"] = "drafting"
      end
      replace_chapter(workspace, chapter, status: "drafting", placeholder: false)

      stdout, stderr, status = run_validator(workspace)
      assert status.success?, "#{stdout}\n#{stderr}"
      assert_includes stdout, "phase=authoring"
      assert_includes stdout, "planned=169"
    end
  end

  def test_non_planned_chapter_cannot_retain_placeholder_text
    with_workspace do |workspace|
      chapter = nil
      mutate_catalog(workspace) do |catalog|
        catalog["status"] = "authoring"
        chapter = catalog.fetch("chapters").first
        chapter["status"] = "drafting"
      end
      replace_chapter(workspace, chapter, status: "drafting", placeholder: true)
      assert_invalid(workspace, "drafting chapter must not retain planned-placeholder text")
    end
  end

  def test_unknown_hard_prerequisite_is_rejected
    with_workspace do |workspace|
      mutate_catalog(workspace) do |catalog|
        catalog.fetch("chapters")[10]["prerequisites"] << "v99.c99.missing"
      end
      assert_invalid(workspace, "unknown prerequisites v99.c99.missing")
    end
  end

  def test_hard_prerequisite_cycle_is_rejected
    with_workspace do |workspace|
      mutate_catalog(workspace) do |catalog|
        by_id = catalog.fetch("chapters").to_h { |chapter| [chapter.fetch("id"), chapter] }
        by_id.fetch("v01.c01.java-platform")["prerequisites"] << "v01.c02.program-structure"
      end
      assert_invalid(workspace, "prerequisites cycle")
    end
  end

  def test_unknown_version_reference_is_rejected
    with_workspace do |workspace|
      mutate_catalog(workspace) do |catalog|
        catalog.fetch("chapters").first["versioned_surface"] << "invented-runtime-999"
      end
      assert_invalid(workspace, "unknown version ids invented-runtime-999")
    end
  end

  def test_spring_transaction_chapter_requires_database_and_test_prerequisites
    with_workspace do |workspace|
      mutate_catalog(workspace) do |catalog|
        chapter = catalog.fetch("chapters").find { |entry| entry["id"] == "v05.c08.services-transactions-aop" }
        chapter.fetch("prerequisites").delete("v03.c12.java-testing-mocking")
      end
      assert_invalid(workspace, "missing adjudicated hard prerequisites v03.c12.java-testing-mocking")
    end
  end

  def test_gate_chapter_drift_is_rejected
    with_workspace do |workspace|
      path = File.join(workspace, "curriculum", "gates.yml")
      gates = load_yaml(path)
      gates.fetch("gates").first.fetch("required_chapter_ids").pop
      write_yaml(path, gates)
      assert_invalid(workspace, "G0: required chapters do not match canonical stage volumes")
    end
  end

  def test_yaml_alias_is_rejected
    with_workspace do |workspace|
      path = File.join(workspace, "curriculum", "catalog.yml")
      body = File.read(path, encoding: "UTF-8")
      body.sub!("catalog_id: factorycare-encyclopedia", "catalog_id: &catalog_id factorycare-encyclopedia")
      body.sub!("edition: 2026.1-draft", "edition: *catalog_id")
      File.write(path, body, mode: "w", encoding: "UTF-8")
      assert_invalid(workspace, "YAML load failed")
    end
  end
end
