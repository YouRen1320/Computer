# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "ostruct"
require "tmpdir"

ROOT = File.expand_path("../..", __dir__) unless defined?(ROOT)
require File.join(ROOT, "scripts", "lib", "curriculum_compiler")

class CurriculumCompilerTest < Minitest::Test
  def test_strict_yaml_rejects_top_level_duplicate_key
    error = assert_raises(Curriculum::DiagnosticError) do
      Curriculum::StrictYaml.load("---\nedition: one\nedition: two\n", display_path: "fixture.yml")
    end

    assert_equal "E_YAML_DUPLICATE_KEY", error.code
    assert_equal "edition", error.details.fetch(:key)
    assert_includes error.message, "first line 2"
    assert_includes error.message, "duplicate line 3"
  end

  def test_strict_yaml_rejects_nested_duplicate_key
    source = <<~YAML
      ---
      chapter:
        outcomes:
          build: first
          build: second
    YAML
    error = assert_raises(Curriculum::DiagnosticError) do
      Curriculum::StrictYaml.load(source, display_path: "fixture.yml")
    end

    assert_equal "E_YAML_DUPLICATE_KEY", error.code
    assert_includes error.message, "/chapter/outcomes"
  end

  def test_strict_yaml_rejects_aliases
    error = assert_raises(Curriculum::DiagnosticError) do
      Curriculum::StrictYaml.load("---\nbase: &base value\ncopy: *base\n", display_path: "fixture.yml")
    end

    assert_equal "E_YAML_ALIAS", error.code
  end

  def test_missing_volume_specs_fail_closed_without_legacy_catalog_fallback
    Dir.mktmpdir("curriculum-missing-specs-") do |workspace|
      copy_canonical_inputs(workspace)
      FileUtils.rm_f(Dir[File.join(workspace, "curriculum", "chapters", "volume-*.yml")])

      failure = assert_raises(Curriculum::ValidationFailure) do
        Curriculum::SpecSet.new(workspace).load!
      end
      assert_equal ["E_VOLUME_SPEC_SET"], failure.issues.map(&:code).uniq
      assert_includes failure.issues.first.message, "missing=curriculum/chapters/volume-00.yml"
    end
  end

  def test_chapter_and_capability_targets_are_read_from_edition
    spec = Curriculum::SpecSet.new(ROOT)
    spec.instance_variable_set(:@edition, {
      "schema_version" => 2,
      "edition" => "2026.2-draft",
      "volume_ids" => ["00"],
      "chapter_count_target" => 2,
      "capability_count_target" => 1
    })
    spec.instance_variable_set(:@volumes, {
      "volumes" => [{ "id" => "00", "expected_chapter_count" => 2 }]
    })
    spec.instance_variable_set(:@volume_specs, {
      "00" => {
        "schema_version" => 2,
        "edition" => "2026.2-draft",
        "volume" => "00",
        "chapters" => [{}, {}]
      }
    })
    spec.instance_variable_set(:@capabilities, {
      "capability_count" => 1,
      "capabilities" => [{
        "id" => "fixture.capability",
        "title" => "Fixture",
        "category" => "fixture",
        "status" => "active",
        "teacher_chapter_id" => "ch.fixture.teacher",
        "requires" => [],
        "threshold" => "fixture threshold",
        "evidence_kinds" => ["fixture"],
        "required_topic_ids" => ["fixture.topic"]
      }]
    })
    spec.instance_variable_set(:@topics, {
      "schema_version" => 2,
      "edition" => "2026.2-draft",
      "topic_count" => 1,
      "topics" => ["fixture.topic"]
    })
    spec.instance_variable_set(:@id_registry, {
      "schema_version" => 2,
      "edition" => "2026.2-draft",
      "registry_id" => "fixture-registry",
      "policy" => {},
      "entries" => []
    })

    spec.send(:validate_top_level!)
    count_errors = spec.collector.errors.select { |issue| %w[E_CHAPTER_COUNT E_CAPABILITY_COUNT].include?(issue.code) }
    assert_empty count_errors
  end

  def test_known_generic_build_outcome_is_rejected
    outcome = { "id" => "build", "text" => "独立完成本章最小可运行工件并保存运行结果作为证据" }
    issue = Curriculum::SpecQuality.outcome_issue(outcome, {})

    assert_includes issue, "placeholder"
  end

  def test_build_outcome_requires_action_and_artifact
    outcome = { "id" => "build", "text" => "理解边界并说明自己的选择以及验证思路" }
    assert_includes Curriculum::SpecQuality.outcome_issue(outcome, {}), "action"

    valid = { "id" => "build", "text" => "编写 OrderAmountCalculator 类和 JUnit 测试，并运行测试保存输出" }
    assert_nil Curriculum::SpecQuality.outcome_issue(valid, {})
  end

  def test_generic_diagnosis_requires_a_concrete_failure_mode
    outcome = {
      "id" => "diagnose",
      "text" => "面对注入的本章知识故障，指出失败阶段、首个可信证据、修复动作并重跑原验证"
    }
    issue = Curriculum::SpecQuality.outcome_issue(outcome, { "gate_requirements" => { "critical_failure_modes" => [] } })
    assert_includes issue, "failure mode"

    concrete = outcome.merge("text" => "定位 CORS 预检状态码错误，指出首个失败请求并修复后重跑断言")
    assert_nil Curriculum::SpecQuality.outcome_issue(concrete, {})
  end

  def test_acceptance_rejects_generic_evidence_sentence_and_requires_oracle
    generic = "计算器的成功、边界与故障场景均保存为证据"
    assert_includes Curriculum::SpecQuality.acceptance_issue(generic), "generic"
    assert_includes Curriculum::SpecQuality.acceptance_issue("保存命令和截图"), "oracle"
    assert_nil Curriculum::SpecQuality.acceptance_issue("mvn test 输出 Tests run: 2, Failures: 0")
  end

  def test_owned_placeholder_requires_exact_id_and_path_metadata
    generator = Curriculum::Generator.new(root: ROOT, mode: :plan)
    path = "book/volume-00-foundations/chapters/ch.fixture.example.md"
    valid = placeholder_body(path, "ch.fixture.example")
    assert generator.send(:safe_owned_placeholder?, valid, path)
    refute generator.send(:safe_owned_placeholder?, valid, path.sub("volume-00", "volume-01"))
    refute generator.send(:safe_owned_placeholder?, placeholder_body(path, "ch.fixture.other"), path)
  end

  def test_generated_output_ownership_requires_exact_header_shape
    generator = Curriculum::Generator.new(root: ROOT, mode: :plan)
    marker = "<!-- #{Curriculum::GENERATED_MARKER} -->"
    refute generator.send(:safe_owned_generated_output?, "human note\n#{marker}\n", "curriculum/README.md")

    document = {
      "schema_version" => 2,
      "generated" => true,
      "generated_by" => Curriculum::GENERATED_BY,
      "generated_spec_digest" => "a" * 64,
      "edition" => "2026.2-draft",
      "gates_id" => "fixture",
      "canonical_source" => "fixture",
      "policy" => {},
      "gates" => [],
      "human_note" => "must not be overwritten"
    }
    refute generator.send(:safe_owned_generated_output?, YAML.dump(document), "curriculum/gates.yml")
  end

  def test_contract_paths_reject_control_characters_and_traversal
    spec = Curriculum::SpecSet.new(ROOT)
    assert spec.send(:valid_contract_path?, "evidence/factorycare/stage/")
    refute spec.send(:valid_contract_path?, "../../secrets/")
    refute spec.send(:valid_contract_path?, "evidence/factorycare/\u0000secret")
    refute spec.send(:valid_contract_path?, "evidence/factorycare/line\nbreak")
  end

  def test_factorycare_artifact_paths_cannot_escape_evidence_root
    spec = Curriculum::SpecSet.new(ROOT).load!
    spec.factorycare_plan.fetch("stages").first.fetch("gate_contract")["artifact_paths"] = ["../../secrets/"]
    spec.collector.errors.clear

    spec.send(:validate_route_plans!)

    assert_includes spec.collector.errors.map(&:code), "E_FACTORYCARE_PATH"
  end

  def test_route_plan_rejects_unknown_fields_and_wrong_identity
    spec = Curriculum::SpecSet.new(ROOT).load!
    spec.accelerated_plan["route_id"] = "wrong"
    spec.accelerated_plan["mystery_policy"] = true
    spec.collector.errors.clear

    spec.send(:validate_route_plan_shapes!)

    messages = spec.collector.errors.map(&:message).join("\n")
    assert_includes messages, "unknown fields mystery_policy"
    assert_includes messages, "/route_id expected \"accelerated-48\""
  end

  def test_migration_ledger_matches_independent_audit_exactly
    spec = Curriculum::SpecSet.new(ROOT).load!
    entries = spec.migration.fetch("entries")

    assert_equal 151, entries.length
    assert_equal 275, entries.sum { |entry| entry.fetch("chapter_edges").length }
    assert_empty spec.migration.fetch("section_overrides")
    assert_equal ["unreviewed"], spec.migration.fetch("source_rebuilds").first.fetch("candidate_statuses")
    assert_equal false, spec.migration.fetch("source_rebuilds").first.fetch("automatic_promotion")
  end

  def test_frozen_generated_output_is_revalidated_with_same_adoption_rule_as_plan
    Dir.mktmpdir("curriculum-adoption-") do |workspace|
      relative = "curriculum/catalog.yml"
      target = File.join(workspace, relative)
      FileUtils.mkdir_p(File.dirname(target))
      body = "legacy generated bytes"
      File.binwrite(target, body)
      digest = Digest::SHA256.hexdigest(body)
      spec = OpenStruct.new(
        migration: { "status" => "ready" },
        legacy_manifest: { "files" => [{ "path" => relative, "kind" => "generated-output", "sha256" => digest }] }
      )
      change = Curriculum::Change.new(:update, relative, nil, :file, digest)
      generator = Curriculum::Generator.new(root: workspace, mode: :write)

      generator.send(:revalidate_target_snapshots!, [change], spec)
    end
  end

  def test_write_rollback_restores_every_applied_file
    Dir.mktmpdir("curriculum-rollback-") do |workspace|
      stage = File.join(workspace, "stage")
      FileUtils.mkdir_p(File.join(stage, "curriculum"))
      FileUtils.mkdir_p(File.join(workspace, "curriculum"))
      before = "<!-- #{Curriculum::GENERATED_MARKER} -->\nbefore\n"
      after = "<!-- #{Curriculum::GENERATED_MARKER} -->\nafter\n"
      File.write(File.join(workspace, "curriculum", "README.md"), before)
      File.write(File.join(stage, "curriculum", "README.md"), after)
      File.write(File.join(stage, "curriculum", "concept-graph.md"), "generated")
      changes = [
        Curriculum::Change.new(:update, "curriculum/README.md", nil, :file, Digest::SHA256.hexdigest(before)),
        Curriculum::Change.new(:create, "curriculum/concept-graph.md", nil, :missing, nil)
      ]
      generator = Curriculum::Generator.new(
        root: workspace,
        mode: :write,
        commit_hook: lambda { |index, _change| raise "injected commit failure" if index == 2 }
      )

      assert_raises(RuntimeError) { generator.send(:commit!, stage, changes) }
      assert_equal before, File.read(File.join(workspace, "curriculum", "README.md"))
      refute File.exist?(File.join(workspace, "curriculum", "concept-graph.md"))
    end
  end

  def test_write_rollback_restores_deleted_file_bytes_and_mode
    Dir.mktmpdir("curriculum-delete-rollback-") do |workspace|
      stage = File.join(workspace, "stage")
      FileUtils.mkdir_p(File.join(stage, "curriculum"))
      legacy = File.join(workspace, "legacy.md")
      created = File.join(stage, "curriculum", "README.md")
      File.binwrite(legacy, "legacy bytes")
      File.chmod(0o600, legacy)
      File.binwrite(created, "new output")
      changes = [
        Curriculum::Change.new(:delete, "legacy.md", nil, :file, Digest::SHA256.hexdigest("legacy bytes")),
        Curriculum::Change.new(:create, "curriculum/README.md", nil, :missing, nil)
      ]
      generator = Curriculum::Generator.new(
        root: workspace,
        mode: :write,
        commit_hook: lambda { |index, _change| raise "injected commit failure" if index == 2 }
      )

      assert_raises(RuntimeError) { generator.send(:commit!, stage, changes) }
      assert_equal "legacy bytes", File.binread(legacy)
      assert_equal 0o600, File.stat(legacy).mode & 0o777
      refute File.exist?(File.join(workspace, "curriculum", "README.md"))
    end
  end

  def test_rendering_is_byte_deterministic_and_alias_free
    first_spec = Curriculum::SpecSet.new(ROOT).load!
    second_spec = Curriculum::SpecSet.new(ROOT).load!
    first = Curriculum::Compiler.new(first_spec).render_outputs
    second = Curriculum::Compiler.new(second_spec).render_outputs

    assert_equal first, second
    first.each do |path, body|
      next unless File.extname(path) == ".yml"

      Curriculum::StrictYaml.load(body, display_path: path)
    end
  end

  def test_ready_migration_rejects_catalog_projection_tampering
    spec = ready_spec_fixture
    spec.chapters.first["status"] = "verified"

    error = assert_raises(Curriculum::DiagnosticError) do
      Curriculum::Compiler.new(spec).render_outputs
    end

    assert_equal "E_MIGRATION_REBUILD", error.code
    assert_includes error.message, "rendered catalog bytes differ"
  end

  def test_changing_only_migration_status_to_applied_fails_without_receipt
    spec = ready_spec_fixture
    spec.migration["status"] = "applied"

    errors = application_receipt_errors(spec)

    assert_equal ["E_MIGRATION_RECEIPT"], errors.map(&:code).uniq
    assert_includes errors.first.message, "requires application_receipt_path"
  end

  def test_ready_migration_forbids_application_receipt
    spec, _outputs, receipt = ready_application_receipt_fixture
    attach_application_receipt(spec, receipt, status: "ready")

    errors = application_receipt_errors(spec)

    assert_equal ["E_MIGRATION_RECEIPT"], errors.map(&:code).uniq
    assert_includes errors.first.message, "only an applied migration"
  end

  def test_semantically_tampered_application_receipt_fails_even_with_matching_byte_digest
    spec, _outputs, receipt = ready_application_receipt_fixture
    receipt["postconditions"]["semantic_chapter_count"] -= 1
    attach_application_receipt(spec, receipt, status: "applied")

    errors = application_receipt_errors(spec)

    assert errors.any? { |issue| issue.message.include?("/postconditions/semantic_chapter_count") }
  end

  def test_application_receipt_identity_timestamp_and_actor_are_semantically_validated
    spec, _outputs, valid_receipt = ready_application_receipt_fixture
    mutations = {
      "/receipt_id" => ->(receipt) { receipt["receipt_id"] = "unrelated.application" },
      "/applied_at" => ->(receipt) { receipt["applied_at"] = "2026-02-31T12:00:00Z" },
      "/applied_by blank" => ->(receipt) { receipt["applied_by"] = "   " },
      "/applied_by control" => ->(receipt) { receipt["applied_by"] = "test\nactor" }
    }

    mutations.each do |label, mutate|
      receipt = Marshal.load(Marshal.dump(valid_receipt))
      mutate.call(receipt)
      attach_application_receipt(spec, receipt, status: "applied")
      errors = application_receipt_errors(spec)
      pointer = label.split.first
      assert errors.any? { |issue| issue.message.include?(pointer) }, "#{label} should be rejected"
    end
  end

  def test_applied_migration_releases_one_time_projection_lock_for_authoring
    spec, _outputs, receipt = ready_application_receipt_fixture
    attach_application_receipt(spec, receipt, status: "applied")
    assert_empty application_receipt_errors(spec)

    chapter = spec.chapters.first
    chapter["status"] = "verified"

    outputs = Curriculum::Compiler.new(spec).render_outputs
    catalog = Curriculum::StrictYaml.load(outputs.fetch("curriculum/catalog.yml"), display_path: "rendered:catalog.yml")
    rendered_chapter = catalog.fetch("chapters").find { |entry| entry.fetch("id") == chapter.fetch("id") }

    assert_equal "verified", rendered_chapter.fetch("status")
    refute outputs.key?(chapter.fetch("path"))
  end

  def test_scope_exception_expiry_rejects_malformed_current_and_past_editions
    ["garbage", "2026.3-draft", "2026.02", "2026.2", "2026.1", "2025.99"].each do |expiry|
      errors = scope_exception_errors(expiry)
      assert errors.any? { |issue| issue.code == "E_SCOPE" && issue.message.include?("must use YYYY.N") }, "#{expiry.inspect} should be rejected"
    end
  end

  def test_scope_exception_expiry_accepts_only_a_strictly_later_numbered_edition
    assert_empty scope_exception_errors("2026.3")
    assert_empty scope_exception_errors("2027.1")
  end

  def test_cli_requires_exactly_one_mode
    _stdout, stderr, status = Open3.capture3("ruby", "scripts/generate-curriculum.rb", "--plan", "--check", chdir: ROOT)
    assert_equal 2, status.exitstatus
    assert_includes stderr, "Usage:"
  end

  def test_migration_schema_is_valid_json_and_exposes_frozen_source_regeneration
    schema = JSON.parse(File.read(File.join(ROOT, "curriculum", "migrations", "migration.schema.json"), encoding: "UTF-8"))
    policies = schema.dig("$defs", "entry", "properties", "source_mapping_policy", "enum")
    assert_includes policies, "regenerate-from-frozen-source-inventory"
    assert schema.dig("$defs", "sourceRebuild", "properties", "automatic_promotion").key?("const")
    assert_equal false, schema.dig("$defs", "sourceRebuild", "properties", "automatic_promotion", "const")
  end

  private

  # Lifecycle tests must construct the state they exercise instead of
  # inheriting whether the real repository is currently ready or applied.
  def ready_spec_fixture
    spec = Curriculum::SpecSet.new(ROOT).load!
    receipt_path = spec.migration.delete("application_receipt_path")
    spec.migration.delete("application_receipt_digest")
    spec.migration["status"] = "ready"
    if receipt_path
      spec.input_paths.delete(receipt_path)
      spec.input_contents.delete(receipt_path)
    end
    spec.instance_variable_set(:@application_receipt, nil)
    spec
  end

  def ready_application_receipt_fixture
    spec = ready_spec_fixture
    outputs = Curriculum::Compiler.new(spec).render_outputs
    plan = Curriculum::MigrationReceipt.expected_ready_plan(spec, outputs)
    receipt = Curriculum::MigrationReceipt.build(
      spec: spec,
      plan: plan,
      outputs: outputs,
      applied_at: "2026-07-16T12:00:00Z",
      applied_by: "test:curriculum-compiler"
    )
    [spec, outputs, receipt]
  end

  def attach_application_receipt(spec, receipt, status:)
    path = "curriculum/migrations/receipts/test-application.yml"
    body = Psych.dump(receipt, nil, line_width: -1)
    spec.migration["status"] = status
    spec.migration["application_receipt_path"] = path
    spec.migration["application_receipt_digest"] = "sha256:#{Digest::SHA256.hexdigest(body)}"
    spec.input_contents[path] = body.freeze
    spec.input_paths << path unless spec.input_paths.include?(path)
    spec.instance_variable_set(:@application_receipt, receipt)
  end

  def application_receipt_errors(spec)
    spec.collector.errors.clear
    spec.send(:validate_application_receipt!)
    spec.collector.errors.dup
  end

  def scope_exception_errors(expiry)
    spec = Curriculum::SpecSet.new(ROOT)
    spec.instance_variable_set(:@edition, {
      "edition" => "2026.2-draft",
      "scope_limits" => { "ordinary_topic_groups" => 3, "synthesis_topic_groups" => 4 }
    })
    chapter = {
      "role" => "foundation",
      "topic_groups" => [{ "id" => "fixture" }],
      "scope_exception" => {
        "reason" => "fixture exception",
        "reviewer" => "fixture reviewer",
        "expires_in_edition" => expiry
      }
    }
    spec.send(:validate_scope, chapter, "fixture.yml", "/chapters/0")
    spec.collector.errors
  end

  def copy_canonical_inputs(workspace)
    Curriculum::SpecSet::BASE_PATHS.values.each do |relative|
      source = File.join(ROOT, relative)
      target = File.join(workspace, relative)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(source, target)
    end
    migration = "curriculum/migrations/2026.1-to-2026.2.yml"
    FileUtils.mkdir_p(File.dirname(File.join(workspace, migration)))
    FileUtils.cp(File.join(ROOT, migration), File.join(workspace, migration))
    migration_document = Curriculum::StrictYaml.load(
      File.read(File.join(ROOT, migration), encoding: "UTF-8"),
      display_path: migration
    )
    receipt = migration_document["application_receipt_path"]
    if receipt
      FileUtils.mkdir_p(File.dirname(File.join(workspace, receipt)))
      FileUtils.cp(File.join(ROOT, receipt), File.join(workspace, receipt))
    end
    legacy_manifest = "curriculum/migrations/legacy-2026.1-manifest.yml"
    FileUtils.cp(File.join(ROOT, legacy_manifest), File.join(workspace, legacy_manifest))
    migration_schema = "curriculum/migrations/migration.schema.json"
    FileUtils.cp(File.join(ROOT, migration_schema), File.join(workspace, migration_schema))
    receipt_schema = "curriculum/migrations/application-receipt.schema.json"
    FileUtils.cp(File.join(ROOT, receipt_schema), File.join(workspace, receipt_schema))
    audit = "records/encyclopedia/reviews/P1R-migration-ledger-audit.md"
    FileUtils.mkdir_p(File.dirname(File.join(workspace, audit)))
    FileUtils.cp(File.join(ROOT, audit), File.join(workspace, audit))
    Dir[File.join(ROOT, "curriculum", "migrations", "evidence", "*.yml")].each do |source|
      relative = source.delete_prefix(ROOT + File::SEPARATOR)
      FileUtils.mkdir_p(File.dirname(File.join(workspace, relative)))
      FileUtils.cp(source, File.join(workspace, relative))
    end
    builder = "scripts/build-source-inventory.rb"
    FileUtils.mkdir_p(File.dirname(File.join(workspace, builder)))
    FileUtils.cp(File.join(ROOT, builder), File.join(workspace, builder))
    FileUtils.mkdir_p(File.join(workspace, "curriculum", "chapters"))
  end

  def placeholder_body(path, id)
    digest = "a" * 64
    <<~BODY
      ---
      schema_version: 2
      edition: 2026.2-draft
      id: #{id}
      title: Fixture
      responsibility: fixture responsibility
      volume: "00"
      order: 1
      level: L1
      status: planned
      path: #{path}
      catalog: ../../../curriculum/catalog.yml
      prerequisites: []
      version_surfaces: []
      route_tags:
        - zero-base
        - accelerated-48
        - reference
      generated_by: scripts/generate-curriculum.rb
      generated_spec_digest: #{digest}
      ---
      <!-- #{Curriculum::PLACEHOLDER_MARKER} -->
      # Fixture

      > 架构占位：本文件尚未包含教材正文，不能作为学习或考核完成证据。

      - 语义 ID：`#{id}`
      - 唯一职责：fixture responsibility
      - 规范输入摘要：`#{digest}`
    BODY
  end
end
