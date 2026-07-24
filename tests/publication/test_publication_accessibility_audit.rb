# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "pathname"
require "tmpdir"

require_relative "../../scripts/audit-publication-accessibility"

class PublicationAccessibilityAuditTest < Minitest::Test
  ROOT = Pathname(__dir__).join("../..").expand_path
  Audit = PublicationAccessibilityAudit

  class FakeToolObserver
    def observe(toolchain)
      toolchain.tools.map do |tool|
        id = tool.fetch("id")
        version = tool.fetch("expected_version_prefix")
        output_digest = Digest::SHA256.hexdigest("version-output:#{id}")
        entrypoint_digest = Digest::SHA256.hexdigest("entrypoint:#{id}")
        Audit::ObservedTool.new(
          id: id,
          role: tool.fetch("role"),
          version: version,
          version_output_sha256: output_digest,
          entrypoint_sha256: entrypoint_digest,
          identity_sha256: Digest::SHA256.hexdigest(
            [id, version, output_digest, entrypoint_digest].join("\0") + "\0"
          ),
          resolved_path: "/fake/#{id}"
        )
      end.sort_by(&:id)
    end

    def verify_unchanged!(_toolchain, _expected)
      true
    end
  end

  class FakeRunner
    attr_reader :calls

    def initialize
      @calls = []
      @mutex = Mutex.new
    end

    def call(engine_id:, artifact:, bytes:)
      raise "fixture bytes must be non-empty" if bytes.empty?

      @mutex.synchronize { calls << [engine_id, artifact.document.fetch("path")] }
      Audit::Invocation.new(exit_code: 0, payload: "fake-structured-output")
    end
  end

  class DriftingToolObserver < FakeToolObserver
    def verify_unchanged!(_toolchain, _expected)
      raise Audit::AuditError, "accessibility tool identities drifted during audit"
    end
  end

  class CapturingExecutor
    attr_reader :argv, :timeout_seconds

    def call(argv, environment:, timeout_seconds:)
      raise "stable environment is required" unless environment.fetch("NO_PROXY") == "*"

      @argv = argv
      @timeout_seconds = timeout_seconds
      [JSON.generate([{ "testEngine" => { "version" => "4.12.1" }, "violations" => [],
                        "incomplete" => [], "passes" => [], "inapplicable" => [] }]), "", 0]
    end
  end

  class FakeParser
    ENGINE_VERSIONS = {
      "axe-core" => "4.12.1",
      "epubcheck" => "EPUBCheck v5.3.0",
      "ace" => "1.4.6",
      "verapdf" => "veraPDF 1.30.0"
    }.freeze

    def initialize(outcomes = {})
      @outcomes = outcomes
    end

    def call(engine_id:, invocation:)
      raise "fake runner contract drifted" unless invocation.payload == "fake-structured-output"

      outcome = @outcomes.fetch(engine_id, "passed")
      {
        "engine_version" => ENGINE_VERSIONS.fetch(engine_id),
        "outcome" => outcome,
        "finding_count" => outcome == "failed" ? 1 : 0,
        "manual_review_signal_count" => outcome == "manual-review-required" ? 1 : 0,
        "finding_ids" => outcome == "passed" ? [] : ["fixture:#{outcome}"],
        "metrics" => { "fixture" => 1 }
      }
    end
  end

  class BrokenParser
    def call(engine_id:, invocation:)
      raise Audit::AuditError, "#{engine_id}: injected parse failure" if invocation
    end
  end

  class DriftingRunner < FakeRunner
    def initialize(root, path)
      super()
      @root = root
      @path = path
      @drifted = false
      @drift_mutex = Mutex.new
    end

    def call(engine_id:, artifact:, bytes:)
      @drift_mutex.synchronize do
        unless @drifted
          File.binwrite(File.join(@root, Audit::OUTPUT_ROOT, @path), "drifted")
          @drifted = true
        end
      end
      super
    end
  end

  def test_fake_pipeline_recomputes_and_binds_exact_307_artifacts_and_324_checks
    with_fixture do |root|
      runner = FakeRunner.new
      report = auditor(root, runner: runner).report

      assert_equal "machine-passed", report.fetch("status")
      assert_equal 307, report.dig("publication_binding", "artifact_count")
      assert_equal 307, report.fetch("artifacts").length
      assert_equal({ "html" => 273, "epub" => 17, "pdf" => 17 }, report.dig("audit_contract", "artifacts_by_format"))
      assert_equal 324, report.fetch("checks").length
      assert_equal({ "axe-core" => 273, "epubcheck" => 17, "ace" => 17, "verapdf" => 17 }, report.dig("audit_contract", "checks_by_engine"))
      assert_equal 324, runner.calls.length
      assert_equal 6, report.dig("toolchain_binding", "tool_count")
      assert_equal "machine-only-not-certification", report.dig("claim_boundary", "evidence_classification")
      assert_equal "forbidden-without-human-review", report.dig("claim_boundary", "promotion_policy")
      assert_equal "required", report.dig("claim_boundary", "human_review")
      assert_equal Audit::AXE_RULE_TAGS, report.dig("audit_contract", "execution_policy", "axe_rule_tags")
      assert_equal 10, report.dig("audit_contract", "execution_policy", "per_invocation_timeout_seconds")

      repeated = auditor(root, runner: FakeRunner.new).report
      assert_equal Audit::Canonical.json(report), Audit::Canonical.json(repeated)

      serialized = Audit::Canonical.json(report)
      refute_match(%r{(?:^|["\s])/(?!/)[a-zA-Z0-9._-]+(?:/[a-zA-Z0-9._-]+)+}, serialized)
      refute_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/, serialized)
      refute_match(/"(?:stdout|stderr|raw_output|raw_log|command)"\s*:/, serialized)
    end
  end

  def test_machine_findings_never_promote_the_report
    with_fixture do |root|
      report = auditor(
        root,
        runner: FakeRunner.new,
        parser: FakeParser.new("verapdf" => "failed", "axe-core" => "manual-review-required")
      ).report

      assert_equal "machine-findings", report.fetch("status")
      assert_equal 17, report.dig("summary", "failed_count")
      assert_equal 273, report.dig("summary", "manual_review_required_count")
      assert_equal "not-certified", report.dig("claim_boundary", "certification_status")
      assert_equal "forbidden-without-human-review", report.dig("claim_boundary", "promotion_policy")
    end
  end

  def test_missing_artifact_fails_before_any_tool_execution
    with_fixture do |root|
      missing = fixture_artifacts.first.fetch("path")
      FileUtils.rm_f(File.join(root, Audit::OUTPUT_ROOT, missing))
      error = assert_raises(Audit::AuditError) { auditor(root, runner: FakeRunner.new) }
      assert_includes error.message, "required file is missing"
      refute_includes error.message, root
    end
  end

  def test_duplicate_manifest_path_fails_closed
    with_fixture do |root|
      path = File.join(root, Audit::OUTPUT_MANIFEST_PATH)
      manifest = JSON.parse(File.read(path))
      manifest.fetch("outputs") << manifest.fetch("outputs").first.dup
      manifest["output_count"] = manifest.fetch("outputs").length
      File.binwrite(path, Audit::Canonical.json(manifest))

      error = assert_raises(Audit::AuditError) { auditor(root, runner: FakeRunner.new) }
      assert_includes error.message, "contain duplicates"
    end
  end

  def test_artifact_drift_during_tool_execution_fails_closed
    with_fixture do |root|
      path = fixture_artifacts.find { |artifact| artifact.fetch("format") == "html" }.fetch("path")
      runner = DriftingRunner.new(root, path)
      error = assert_raises(Audit::AuditError) { auditor(root, runner: runner).report }
      assert_match(/drift/, error.message)
    end
  end

  def test_structured_output_parse_failure_fails_closed_without_a_partial_report
    with_fixture do |root|
      error = assert_raises(Audit::AuditError) do
        auditor(root, runner: FakeRunner.new, parser: BrokenParser.new).report
      end
      assert_includes error.message, "injected parse failure"
    end
  end

  def test_tool_identity_drift_after_checks_fails_closed
    with_fixture do |root|
      error = assert_raises(Audit::AuditError) do
        Audit::Auditor.new(
          root: root,
          tool_observer: DriftingToolObserver.new,
          runner: FakeRunner.new,
          parser: FakeParser.new,
          jobs: 4,
          timeout_seconds: 10
        ).report
      end
      assert_includes error.message, "tool identities drifted"
    end
  end

  def test_toolchain_duplicate_and_semantic_drift_are_rejected
    with_fixture do |root|
      path = File.join(root, Audit::TOOLCHAIN_PATH)
      value = StrictYaml.safe_load(File.read(path), label: path)
      value.fetch("tools")[5] = JSON.parse(JSON.generate(value.fetch("tools")[0]))
      File.binwrite(path, YAML.dump(value))

      error = assert_raises(Audit::AuditError) { auditor(root, runner: FakeRunner.new) }
      assert_match(/schema validation|duplicate tool/, error.message)
    end
  end

  def test_real_result_parsers_reduce_dynamic_raw_reports_to_stable_semantics
    parser = Audit::ResultParser.new
    axe = parser.call(
      engine_id: "axe-core",
      invocation: invocation(1, JSON.generate([
        {
          "testEngine" => { "version" => "4.12.1" },
          "violations" => [{ "id" => "color-contrast", "nodes" => [{ "html" => "/Users/redacted" }] }],
          "incomplete" => [], "passes" => [], "inapplicable" => []
        }
      ]))
    )
    epubcheck = parser.call(
      engine_id: "epubcheck",
      invocation: invocation(0, JSON.generate(
        "checker" => {
          "checkerVersion" => "5.3.0", "checkDate" => "dynamic",
          "nFatal" => 0, "nError" => 0, "nWarning" => 0, "nUsage" => 0
        },
        "messages" => []
      ))
    )
    ace = parser.call(
      engine_id: "ace",
      invocation: invocation(0, JSON.generate(
        "@type" => "earl:report",
        "earl:assertedBy" => { "doap:release" => { "doap:revision" => "1.4.6" } },
        "earl:result" => { "earl:outcome" => "pass" },
        "a11y-metadata" => { "missing" => ["a11y:certifiedBy"] },
        "assertions" => [{ "@type" => "earl:assertion", "earl:result" => { "earl:outcome" => "pass" } }]
      ))
    )
    verapdf = parser.call(
      engine_id: "verapdf",
      invocation: invocation(0, JSON.generate(
        "report" => {
          "buildInformation" => { "releaseDetails" => [{ "id" => "apps", "version" => "1.30.0" }] },
          "jobs" => [{
            "itemDetails" => { "name" => "/Users/redacted.pdf" },
            "validationResult" => [{
              "jobEndStatus" => "normal", "profileName" => "PDF/UA-1 validation profile",
              "compliant" => true,
              "details" => { "passedRules" => 106, "failedRules" => 0, "passedChecks" => 942_454, "failedChecks" => 0 }
            }]
          }]
        }
      ))
    )

    assert_equal "failed", axe.fetch("outcome")
    assert_equal ["violation:color-contrast"], axe.fetch("finding_ids")
    assert_equal "passed", epubcheck.fetch("outcome")
    assert_equal 1, ace.fetch("manual_review_signal_count")
    assert_equal "passed", verapdf.fetch("outcome")
    normalized = Audit::Canonical.json([axe, epubcheck, ace, verapdf])
    refute_includes normalized, "/Users/"
    refute_includes normalized, "checkDate"
    refute_includes normalized, "dynamic"
  end

  def test_real_runner_pins_wcag_a_aa_tags_and_bounded_timeout
    executor = CapturingExecutor.new
    observed = %w[axe-core chrome chromedriver].map do |id|
      Audit::ObservedTool.new(id: id, role: "fixture", version: "fixture",
                              version_output_sha256: "0" * 64, entrypoint_sha256: "1" * 64,
                              identity_sha256: "2" * 64, resolved_path: "/fake/#{id}")
    end
    runner = Audit::RealRunner.new(observed, executor: executor, timeout_seconds: Audit::DEFAULT_TIMEOUT_SECONDS)
    artifact = Audit::Artifact.new(document: { "format" => "html", "path" => "html/index.html" })

    runner.call(engine_id: "axe-core", artifact: artifact, bytes: "<!doctype html><title>x</title>")

    tags_index = executor.argv.index("--tags")
    assert_equal Audit::AXE_RULE_TAGS.join(","), executor.argv.fetch(tags_index + 1)
    assert_equal Audit::DEFAULT_TIMEOUT_SECONDS, executor.timeout_seconds
  end

  def test_real_parser_rejects_invalid_json_and_exit_result_disagreement
    parser = Audit::ResultParser.new
    assert_raises(Audit::AuditError) do
      parser.call(engine_id: "axe-core", invocation: invocation(0, "not-json"))
    end
    assert_raises(Audit::AuditError) do
      parser.call(
        engine_id: "axe-core",
        invocation: invocation(0, JSON.generate([
          {
            "testEngine" => { "version" => "4.12.1" },
            "violations" => [{ "id" => "rule", "nodes" => [] }],
            "incomplete" => [], "passes" => [], "inapplicable" => []
          }
        ]))
      )
    end
  end

  private

  def auditor(root, runner:, parser: FakeParser.new)
    Audit::Auditor.new(
      root: root,
      tool_observer: FakeToolObserver.new,
      runner: runner,
      parser: parser,
      jobs: 4,
      timeout_seconds: 10
    )
  end

  def invocation(exit_code, payload)
    Audit::Invocation.new(exit_code: exit_code, payload: payload)
  end

  def with_fixture
    Dir.mktmpdir("publication-accessibility-") do |directory|
      root = File.join(directory, "repository")
      copy_contract_files(root)
      write_publication_fixture(root)
      yield root
    end
  end

  def copy_contract_files(root)
    [Audit::TOOLCHAIN_PATH, Audit::TOOLCHAIN_SCHEMA_PATH, Audit::REPORT_SCHEMA_PATH].each do |relative|
      destination = File.join(root, relative)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(ROOT.join(relative), destination)
    end
  end

  def write_publication_fixture(root)
    artifacts = fixture_artifacts.map do |specification|
      bytes = fixture_bytes(specification)
      destination = File.join(root, Audit::OUTPUT_ROOT, specification.fetch("path"))
      FileUtils.mkdir_p(File.dirname(destination))
      File.binwrite(destination, bytes)
      specification.merge(
        "media_type" => Audit::FORMAT_MEDIA_TYPES.fetch(specification.fetch("format")),
        "distribution" => "internal-review-candidate",
        "sha256" => Digest::SHA256.hexdigest(bytes),
        "size_bytes" => bytes.bytesize
      )
    end
    internal = 37.times.map do |index|
      {
        "path" => format("internal/fixture-%02d.json", index),
        "kind" => "fixture-internal",
        "format" => "internal",
        "media_type" => "application/json",
        "distribution" => "internal-review-candidate",
        "sha256" => Digest::SHA256.hexdigest("internal-#{index}"),
        "size_bytes" => 1
      }
    end
    outputs = artifacts + internal
    planned = outputs.map do |entry|
      entry.select { |key, _value| %w[path kind format distribution].include?(key) }
    end
    planned << {
      "path" => "publication-output-manifest-v2.json",
      "kind" => "output-manifest",
      "format" => "internal",
      "distribution" => "internal-review-candidate"
    }
    plan = {
      "schema_version" => 2,
      "plan_id" => Audit::PLAN_ID,
      "profile_id" => Audit::PROFILE_ID,
      "output_root" => Audit::OUTPUT_ROOT,
      "planned_outputs" => planned
    }
    plan_bytes = Audit::Canonical.json(plan)
    plan_path = File.join(root, Audit::PLAN_PATH)
    FileUtils.mkdir_p(File.dirname(plan_path))
    File.binwrite(plan_path, plan_bytes)
    manifest = {
      "schema_version" => 2,
      "manifest_id" => Audit::MANIFEST_ID,
      "plan_id" => Audit::PLAN_ID,
      "profile_id" => Audit::PROFILE_ID,
      "plan_sha256" => Digest::SHA256.hexdigest(plan_bytes),
      "build_status" => "succeeded",
      "output_count" => outputs.length,
      "outputs" => outputs
    }
    File.binwrite(File.join(root, Audit::OUTPUT_MANIFEST_PATH), Audit::Canonical.json(manifest))
  end

  def fixture_artifacts
    @fixture_artifacts ||= begin
      artifacts = [
        artifact("output/html/index.html", "html-index", "html"),
        artifact("output/html/book.html", "whole-html", "html")
      ]
      16.times { |index| artifacts << artifact(format("output/html/volumes/volume-%02d.html", index), "volume-html", "html") }
      255.times { |index| artifacts << artifact(format("output/html/chapters/ch.fixture-%03d.html", index), "chapter-html", "html") }
      artifacts << artifact("output/epub/book.epub", "whole-epub", "epub")
      16.times { |index| artifacts << artifact(format("output/epub/volumes/volume-%02d.epub", index), "volume-epub", "epub") }
      artifacts << artifact("output/pdf/book.pdf", "whole-pdf-candidate", "pdf")
      16.times { |index| artifacts << artifact(format("output/pdf/volumes/volume-%02d.pdf", index), "volume-pdf-candidate", "pdf") }
      artifacts.freeze
    end
  end

  def artifact(path, kind, format)
    { "path" => path, "kind" => kind, "format" => format }
  end

  def fixture_bytes(specification)
    path = specification.fetch("path")
    case specification.fetch("format")
    when "html" then "<!doctype html><html lang=\"zh-CN\"><body>#{path}</body></html>"
    when "epub" then "PK\x03\x04#{path}".b
    when "pdf" then "%PDF-1.7\n#{path}\n%%EOF\n".b
    end
  end
end
