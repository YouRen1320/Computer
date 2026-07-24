# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "pathname"
require "shellwords"
require "stringio"
require "tmpdir"
require "uri"

require_relative "../../scripts/audit-chapter-markdown-links"

class ChapterMarkdownLinkAuditTest < Minitest::Test
  ROOT = Pathname(__dir__).join("../..").expand_path

  class RaisingProbe
    def call(_url)
      raise "structure-only mode must not use the network probe"
    end
  end

  class FakeProbe
    def initialize(results = {})
      @results = results
    end

    def call(url)
      @results.fetch(url) { probe_result(url: url, status: 206) }
    end

    private

    def probe_result(url:, status:)
      VersionSourceAudit::ProbeResult.new(
        exit_code: 0,
        http_status: status,
        effective_url: url,
        ssl_verify_result: 0,
        request_mode: "range-get",
        error: ""
      )
    end
  end

  class RuntimeRaisingProbe
    def call(_url)
      raise RuntimeError, "injected diagnostic that must not become a backtrace"
    end
  end

  class ConcurrencyProbe
    attr_reader :maximum_total, :maximum_by_host

    def initialize
      @mutex = Mutex.new
      @active_total = 0
      @active_by_host = Hash.new(0)
      @maximum_total = 0
      @maximum_by_host = Hash.new(0)
    end

    def call(url)
      host = URI.parse(url).host
      @mutex.synchronize do
        @active_total += 1
        @active_by_host[host] += 1
        @maximum_total = [@maximum_total, @active_total].max
        @maximum_by_host[host] = [@maximum_by_host[host], @active_by_host[host]].max
      end
      sleep 0.03
      VersionSourceAudit::ProbeResult.new(
        exit_code: 0,
        http_status: 206,
        effective_url: url,
        ssl_verify_result: 0,
        request_mode: "range-get",
        error: ""
      )
    ensure
      @mutex.synchronize do
        @active_total -= 1
        @active_by_host[host] -= 1
      end
    end
  end

  def test_current_p8_ast_has_a_deterministic_bound_structure_inventory
    report = ChapterMarkdownLinkAudit::Auditor.new(
      root: ROOT,
      mode: "structure-only",
      probe: RaisingProbe.new
    ).report(observation_date: "2026-07-24")

    assert_equal 2, report.fetch("schema_version")
    assert_equal "passed", report.fetch("status")
    assert_equal 255, report.dig("summary", "planned_chapter_count")
    assert_equal 255, report.dig("summary", "ast_chapter_count")
    assert_operator report.dig("summary", "ast_link_node_count"), :>, 1_000
    assert_equal(
      report.dig("summary", "ast_link_node_count") + report.dig("summary", "ast_image_node_count"),
      report.dig("summary", "ast_node_count")
    )
    assert_operator report.dig("summary", "unique_external_https_target_count"), :>, 1_000
    assert_equal 0, report.dig("summary", "structure_invalid_count")
    assert_equal Digest::SHA256.file(ROOT.join(ChapterMarkdownLinkAudit::PLAN_PATH)).hexdigest,
                 report.dig("publication_binding", "manifest_plan_sha256")
    assert_equal "ast/book.json", report.dig("publication_binding", "canonical_ast", "output_path")
    assert report.fetch("targets").all? do |target|
      target.fetch("occurrences").all? do |occurrence|
        %w[Link Image].include?(occurrence.fetch("node_kind")) &&
          occurrence.fetch("source_chapter_id").start_with?("ch.") &&
          occurrence.fetch("ast_pointer").start_with?("/blocks/")
      end
    end

    serialized = JSON.generate(ChapterMarkdownLinkAudit::CLI.canonicalize(report))
    refute_match(%r{/Users/|/home/|(?:\A|["\s])[A-Za-z]:[\\/]}, serialized)
    refute_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/, serialized)
    refute_match(%r{://[^/@\s]+:[^/@\s]+@}, serialized)
  end

  def test_final_link_and_image_nodes_are_distinct_and_markdown_is_not_reparsed
    with_fixture(
      [
        link("https://example.test/kept?token=must-not-appear"),
        link("https://example.test/kept?token=must-not-appear"),
        image("https://cdn.example.test/final.png"),
        link("#ch.fixture.one")
      ]
    ) do |root|
      first = auditor(root).report(observation_date: "2026-07-24")
      second = auditor(root).report(observation_date: "2026-07-24")
      serialized = JSON.generate(ChapterMarkdownLinkAudit::CLI.canonicalize(first))
      queried = first.fetch("targets").find { |target| target.fetch("query_redacted") }
      image_target = first.fetch("targets").find { |target| target.fetch("node_kinds") == ["Image"] }

      assert_equal serialized, JSON.generate(ChapterMarkdownLinkAudit::CLI.canonicalize(second))
      assert_equal "passed", first.fetch("status")
      assert_equal 4, first.dig("summary", "ast_node_count")
      assert_equal 3, first.dig("summary", "ast_link_node_count")
      assert_equal 1, first.dig("summary", "ast_image_node_count")
      assert_equal 3, first.dig("summary", "external_https_occurrence_count")
      assert_equal 2, first.dig("summary", "unique_external_https_target_count")
      assert_equal 2, queried.fetch("occurrence_count")
      assert_equal "https://example.test/kept", queried.fetch("target")
      assert_equal "Image", image_target.dig("occurrences", 0, "node_kind")
      assert_equal "ch.fixture.one", image_target.dig("occurrences", 0, "source_chapter_id")
      assert_match(%r{\A/blocks/0/}, image_target.dig("occurrences", 0, "ast_pointer"))
      assert_equal "forbidden", first.dig("extraction_policy", "source_markdown_reparse")
      assert_includes first.dig("extraction_policy", "image_node_semantics"), "final nodes"
      refute_includes serialized, "must-not-appear"
    end
  end

  def test_live_mode_separates_pass_manual_review_failure_and_downgrade
    urls = {
      ok_206: "https://one.example.test/ok",
      ok_200: "https://two.example.test/ok",
      forbidden: "https://three.example.test/forbidden",
      missing: "https://four.example.test/missing",
      downgrade: "https://five.example.test/downgrade"
    }
    with_fixture(urls.values.map { |url| link(url) }) do |root|
      results = {
        urls.fetch(:ok_206) => result(urls.fetch(:ok_206), 206),
        urls.fetch(:ok_200) => result(urls.fetch(:ok_200), 200),
        urls.fetch(:forbidden) => result(urls.fetch(:forbidden), 403, request_mode: "get-fallback"),
        urls.fetch(:missing) => result(urls.fetch(:missing), 404),
        urls.fetch(:downgrade) => result("http://five.example.test/downgrade", 200)
      }
      report = auditor(root, mode: "live", probe: FakeProbe.new(results)).report(observation_date: "2026-07-24")
      by_target = report.fetch("targets").to_h { |target| [target.fetch("target"), target] }

      assert_equal "failed", report.fetch("status")
      assert_equal 2, report.dig("summary", "passed_count")
      assert_equal 1, report.dig("summary", "manual_review_count")
      assert_equal 2, report.dig("summary", "failure_count")
      assert_equal "manual-review", by_target.fetch(urls.fetch(:forbidden)).fetch("outcome")
      assert_equal "http-403", by_target.fetch(urls.fetch(:forbidden)).fetch("reason")
      assert_equal "failed", by_target.fetch(urls.fetch(:downgrade)).fetch("outcome")
      assert_equal "effective-url-is-not-https", by_target.fetch(urls.fetch(:downgrade)).fetch("reason")
    end
  end

  def test_transport_inconclusive_remains_manual_review_and_is_not_auto_passed
    urls = {
      accepted: "https://accepted.example.test/source",
      processing: "https://processing.example.test/source",
      timeout: "https://timeout.example.test/source"
    }
    with_fixture(urls.values.map { |url| link(url) }) do |root|
      results = {
        urls.fetch(:accepted) => result(urls.fetch(:accepted), 206),
        urls.fetch(:processing) => result(urls.fetch(:processing), 202),
        urls.fetch(:timeout) => result(urls.fetch(:timeout), 0, exit_code: 28, error: "secret diagnostic")
      }
      report = auditor(root, mode: "live", probe: FakeProbe.new(results)).report(observation_date: "2026-07-24")
      by_target = report.fetch("targets").to_h { |target| [target.fetch("target"), target] }

      assert_equal "needs-review", report.fetch("status")
      assert_equal 1, report.dig("summary", "passed_count")
      assert_equal 2, report.dig("summary", "manual_review_count")
      assert_equal 2, report.dig("summary", "transport_inconclusive_count")
      assert_equal "transport-inconclusive-http-202", by_target.fetch(urls.fetch(:processing)).fetch("reason")
      assert_equal "transport-inconclusive-curl-exit-28", by_target.fetch(urls.fetch(:timeout)).fetch("reason")
      assert_equal true, by_target.fetch(urls.fetch(:timeout)).dig("probe", "error_present")
      refute_includes JSON.generate(report), "secret diagnostic"
      assert_equal "forbidden-without-human-review", report.dig("evidence_classification", "promotion")
    end
  end

  def test_userinfo_target_fails_structure_and_credentials_and_query_are_redacted
    unsafe = "https://alice:super-secret@example.test/source?token=never-print"
    with_fixture([link(unsafe)]) do |root|
      report = auditor(root).report(observation_date: "2026-07-24")
      serialized = JSON.generate(report)
      target = report.fetch("targets").first

      assert_equal "failed", report.fetch("status")
      assert_equal 1, report.dig("summary", "structure_invalid_count")
      assert_equal "https://example.test/source", target.fetch("target")
      assert_equal "invalid-target", target.fetch("reason")
      refute_includes serialized, "alice"
      refute_includes serialized, "super-secret"
      refute_includes serialized, "never-print"
    end
  end

  def test_plan_manifest_and_ast_drift_fail_closed
    with_fixture([link("https://example.test/source")]) do |root|
      plan_path = root.join(ChapterMarkdownLinkAudit::PLAN_PATH)
      plan = JSON.parse(plan_path.read)
      plan["edition"] = "drift"
      plan_path.write(JSON.generate(plan))

      error = assert_raises(ChapterMarkdownLinkAudit::AuditError) do
        auditor(root).report(observation_date: "2026-07-24")
      end
      assert_includes error.message, "plan_sha256"
    end

    with_fixture([link("https://example.test/source")]) do |root|
      root.join(ChapterMarkdownLinkAudit::OUTPUT_ROOT, ChapterMarkdownLinkAudit::CANONICAL_AST_OUTPUT_PATH)
          .open("ab") { |file| file.write(" ") }

      error = assert_raises(ChapterMarkdownLinkAudit::AuditError) do
        auditor(root).report(observation_date: "2026-07-24")
      end
      assert_includes error.message, "output manifest sha256"
    end
  end

  def test_duplicate_output_and_duplicate_json_member_fail_closed
    with_fixture([link("https://example.test/source")]) do |root|
      manifest_path = root.join(ChapterMarkdownLinkAudit::OUTPUT_MANIFEST_PATH)
      manifest = JSON.parse(manifest_path.read)
      manifest.fetch("outputs") << manifest.fetch("outputs").first.dup
      manifest["output_count"] = 2
      manifest_path.write(JSON.generate(manifest))

      error = assert_raises(ChapterMarkdownLinkAudit::AuditError) do
        auditor(root).report(observation_date: "2026-07-24")
      end
      assert_includes error.message, "output paths must be unique"
    end

    with_fixture([link("https://example.test/source")]) do |root|
      ast_path = root.join(ChapterMarkdownLinkAudit::OUTPUT_ROOT, ChapterMarkdownLinkAudit::CANONICAL_AST_OUTPUT_PATH)
      duplicate_json = '{"pandoc-api-version":[1,23],"meta":{},"blocks":[],"blocks":[]}'
      ast_path.write(duplicate_json)
      rebind_ast_manifest(root, duplicate_json)

      error = assert_raises(ChapterMarkdownLinkAudit::AuditError) do
        auditor(root).report(observation_date: "2026-07-24")
      end
      assert_includes error.message, "invalid strict JSON"
    end
  end

  def test_missing_or_semantically_wrong_canonical_output_entry_fails_closed
    with_fixture([link("https://example.test/source")]) do |root|
      FileUtils.rm_f(root.join(ChapterMarkdownLinkAudit::OUTPUT_ROOT, ChapterMarkdownLinkAudit::CANONICAL_AST_OUTPUT_PATH))

      error = assert_raises(ChapterMarkdownLinkAudit::AuditError) do
        auditor(root).report(observation_date: "2026-07-24")
      end
      assert_includes error.message, "required file is missing"
    end

    with_fixture([link("https://example.test/source")]) do |root|
      manifest_path = root.join(ChapterMarkdownLinkAudit::OUTPUT_MANIFEST_PATH)
      manifest = JSON.parse(manifest_path.read)
      manifest.fetch("outputs").first["media_type"] = "text/plain"
      manifest_path.write(JSON.generate(manifest))

      error = assert_raises(ChapterMarkdownLinkAudit::AuditError) do
        auditor(root).report(observation_date: "2026-07-24")
      end
      assert_includes error.message, "unsupported semantics"
    end
  end

  def test_ast_chapter_identity_mismatch_and_outside_link_fail_closed
    with_fixture([link("https://example.test/source")]) do |root|
      ast_path = root.join(ChapterMarkdownLinkAudit::OUTPUT_ROOT, ChapterMarkdownLinkAudit::CANONICAL_AST_OUTPUT_PATH)
      ast = JSON.parse(ast_path.read)
      ast.fetch("blocks").first.fetch("c").first.fetch(2).first[1] = "ch.fixture.changed"
      bytes = JSON.generate(ast)
      ast_path.write(bytes)
      rebind_ast_manifest(root, bytes)

      error = assert_raises(ChapterMarkdownLinkAudit::AuditError) do
        auditor(root).report(observation_date: "2026-07-24")
      end
      assert_includes error.message, "chapter order/identity"
    end

    with_fixture([link("https://example.test/source")]) do |root|
      ast_path = root.join(ChapterMarkdownLinkAudit::OUTPUT_ROOT, ChapterMarkdownLinkAudit::CANONICAL_AST_OUTPUT_PATH)
      ast = JSON.parse(ast_path.read)
      ast.fetch("blocks").unshift({ "t" => "Para", "c" => [link("https://outside.example.test")] })
      bytes = JSON.generate(ast)
      ast_path.write(bytes)
      rebind_ast_manifest(root, bytes)

      error = assert_raises(ChapterMarkdownLinkAudit::AuditError) do
        auditor(root).report(observation_date: "2026-07-24")
      end
      assert_includes error.message, "outside a chapter"
    end
  end

  def test_live_scheduler_caps_total_and_per_host_concurrency
    urls = 6.times.flat_map do |host_index|
      4.times.map { |path_index| "https://host#{host_index}.example.test/path#{path_index}" }
    end
    with_fixture(urls.map { |url| link(url) }) do |root|
      probe = ConcurrencyProbe.new
      report = auditor(root, mode: "live", probe: probe).report(observation_date: "2026-07-24")

      assert_equal "passed", report.fetch("status")
      assert_operator probe.maximum_total, :<=, 8
      assert_operator probe.maximum_total, :>=, 3
      assert probe.maximum_by_host.values.all? { |maximum| maximum <= 2 }
      assert_includes probe.maximum_by_host.values, 2
    end
  end

  def test_shared_curl_probe_uses_https_protocol_guards_and_get_fallback
    Dir.mktmpdir("chapter-link-fake-curl-") do |directory|
      root = Pathname(directory)
      executable = root.join("fake-curl")
      argument_log = root.join("arguments.log")
      executable.write(<<~SH)
        #!/bin/sh
        printf 'CALL\\n' >> #{Shellwords.escape(argument_log.to_s)}
        for argument in "$@"; do
          printf 'ARG=%s\\n' "$argument" >> #{Shellwords.escape(argument_log.to_s)}
        done
        case " $* " in
          *" --range "*) code=403 ;;
          *) code=206 ;;
        esac
        printf '%s\\thttps://example.test/final\\t0' "$code"
      SH
      executable.chmod(0o755)

      response = VersionSourceAudit::CurlProbe.new(
        curl: executable.to_s,
        connect_timeout: 1,
        max_time: 2
      ).call("https://example.test/source")
      arguments = argument_log.read

      assert_equal 206, response.http_status
      assert_equal "get-fallback", response.request_mode
      assert_equal 2, arguments.lines.count { |line| line == "CALL\n" }
      assert_includes arguments, "ARG=--range\n"
      assert_includes arguments, "ARG=--proto\nARG==https\n"
      assert_includes arguments, "ARG=--proto-redir\nARG==https\n"
      refute_includes arguments, "ARG=--head\n"
    end
  end

  def test_cli_requires_date_and_probe_error_is_a_concise_operational_failure
    with_fixture([link("https://example.test/source")]) do |root|
      stdout = StringIO.new
      stderr = StringIO.new
      exit_code = ChapterMarkdownLinkAudit::CLI.run(
        ["--root", root.to_s],
        stdout: stdout,
        stderr: stderr
      )
      assert_equal 2, exit_code
      assert_includes stderr.string, "--observation-date is required"

      stdout = StringIO.new
      stderr = StringIO.new
      exit_code = ChapterMarkdownLinkAudit::CLI.run(
        ["--root", root.to_s, "--mode", "live", "--observation-date", "2026-07-24"],
        stdout: stdout,
        stderr: stderr,
        probe: RuntimeRaisingProbe.new
      )
      assert_equal 2, exit_code
      assert_empty stdout.string
      assert_equal "CHAPTER PANDOC AST LINK AUDIT FAILED: probe worker failed (RuntimeError)\n", stderr.string
      refute_includes stderr.string, "test_chapter_markdown_link_audit.rb"
    end
  end

  def test_schema_rejects_timestamp_and_unexpected_fields
    with_fixture([link("https://example.test/source")]) do |root|
      report = auditor(root).report(observation_date: "2026-07-24")
      report["generated_at"] = "2026-07-24T12:00:00Z"

      error = assert_raises(Verification::ContractError) do
        Verification::MachineReportSchema.validate!(
          root: root,
          schema_path: ChapterMarkdownLinkAudit::REPORT_SCHEMA_PATH,
          document: report
        )
      end
      assert_equal "E_MACHINE_REPORT_SCHEMA", error.code
    end
  end

  private

  def auditor(root, mode: "structure-only", probe: RaisingProbe.new)
    ChapterMarkdownLinkAudit::Auditor.new(root: root, mode: mode, probe: probe)
  end

  def with_fixture(nodes)
    Dir.mktmpdir("chapter-pandoc-link-audit-") do |directory|
      root = Pathname(directory).realpath
      schema_directory = root.join("schemas")
      schema_directory.mkpath
      FileUtils.cp(ROOT.join(ChapterMarkdownLinkAudit::REPORT_SCHEMA_PATH), schema_directory)

      chapter_id = "ch.fixture.one"
      ast = {
        "pandoc-api-version" => [1, 23, 1, 1],
        "meta" => {},
        "blocks" => [chapter_div(chapter_id, nodes)]
      }
      ast_bytes = JSON.generate(ast)
      ast_path = root.join(ChapterMarkdownLinkAudit::OUTPUT_ROOT, ChapterMarkdownLinkAudit::CANONICAL_AST_OUTPUT_PATH)
      ast_path.dirname.mkpath
      ast_path.write(ast_bytes)

      planned_entry = {
        "path" => ChapterMarkdownLinkAudit::CANONICAL_AST_OUTPUT_PATH,
        "kind" => "canonical-ast",
        "format" => "internal",
        "distribution" => "internal-review-candidate"
      }
      plan = {
        "schema_version" => 2,
        "plan_id" => ChapterMarkdownLinkAudit::PLAN_ID,
        "profile_id" => ChapterMarkdownLinkAudit::PROFILE_ID,
        "output_root" => ChapterMarkdownLinkAudit::OUTPUT_ROOT,
        "chapters" => [{ "id" => chapter_id }],
        "planned_outputs" => [planned_entry]
      }
      plan_bytes = JSON.generate(plan)
      plan_path = root.join(ChapterMarkdownLinkAudit::PLAN_PATH)
      plan_path.dirname.mkpath
      plan_path.write(plan_bytes)

      manifest = {
        "schema_version" => 2,
        "manifest_id" => ChapterMarkdownLinkAudit::MANIFEST_ID,
        "profile_id" => ChapterMarkdownLinkAudit::PROFILE_ID,
        "plan_id" => ChapterMarkdownLinkAudit::PLAN_ID,
        "plan_sha256" => Digest::SHA256.hexdigest(plan_bytes),
        "output_count" => 1,
        "outputs" => [
          planned_entry.merge(
            "media_type" => "application/json",
            "sha256" => Digest::SHA256.hexdigest(ast_bytes),
            "size_bytes" => ast_bytes.bytesize
          )
        ]
      }
      root.join(ChapterMarkdownLinkAudit::OUTPUT_MANIFEST_PATH).write(JSON.generate(manifest))
      yield root
    end
  end

  def chapter_div(chapter_id, nodes)
    {
      "t" => "Div",
      "c" => [
        [chapter_id, ["chapter"], [["data-chapter-id", chapter_id], ["data-status", "drafting"]]],
        nodes.map { |node| { "t" => "Para", "c" => [node] } }
      ]
    }
  end

  def link(target)
    pandoc_node("Link", target)
  end

  def image(target)
    pandoc_node("Image", target)
  end

  def pandoc_node(kind, target)
    {
      "t" => kind,
      "c" => [
        ["", [], []],
        [{ "t" => "Str", "c" => "fixture" }],
        [target, ""]
      ]
    }
  end

  def rebind_ast_manifest(root, ast_bytes)
    manifest_path = root.join(ChapterMarkdownLinkAudit::OUTPUT_MANIFEST_PATH)
    manifest = JSON.parse(manifest_path.read)
    entry = manifest.fetch("outputs").first
    entry["sha256"] = Digest::SHA256.hexdigest(ast_bytes)
    entry["size_bytes"] = ast_bytes.bytesize
    manifest_path.write(JSON.generate(manifest))
  end

  def result(
    effective_url,
    status,
    request_mode: "range-get",
    exit_code: 0,
    ssl_verify_result: 0,
    error: ""
  )
    VersionSourceAudit::ProbeResult.new(
      exit_code: exit_code,
      http_status: status,
      effective_url: effective_url,
      ssl_verify_result: ssl_verify_result,
      request_mode: request_mode,
      error: error
    )
  end
end
