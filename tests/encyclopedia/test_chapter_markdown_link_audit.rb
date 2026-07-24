# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "pathname"
require "shellwords"
require "stringio"
require "tmpdir"

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

  def test_current_chapters_have_a_deterministic_structure_only_inventory
    report = ChapterMarkdownLinkAudit::Auditor.new(
      root: ROOT,
      mode: "structure-only",
      probe: RaisingProbe.new
    ).report(checked_at: "2026-07-24")

    assert_equal "passed", report.fetch("status")
    assert_equal 255, report.dig("summary", "chapter_count")
    assert_equal 1_493, report.dig("summary", "markdown_https_occurrence_count")
    assert_equal 1_138, report.dig("summary", "unique_markdown_https_target_count")
    assert_equal 127, report.dig("summary", "host_count")
    assert_equal 0, report.dig("summary", "structure_invalid_count")
    assert_equal({ "not-probed" => 1_138 }, report.fetch("outcome_counts"))
    assert_includes report.dig("replay_commands", "live"), "--workers 8 --per-host 2 --connect-timeout 10 --max-time 25"
  end

  def test_extraction_excludes_non_markdown_and_masked_regions_and_deduplicates_targets
    with_fixture do |root|
      write_chapter(root, "ch.fixture.links", <<~'MARKDOWN')
        [kept](https://example.test/kept)
        [duplicate](https://example.test/kept)
        ![image](https://cdn.example.test/image.png)
        [query](https://example.test/query?token=must-not-appear)

        Bare URL is outside this audit: https://example.test/bare
        Autolink is outside this audit: <https://example.test/autolink>
        `[inline code](https://example.test/inline-code)`

        ```text
        [fenced](https://example.test/fenced)
        ```

        <!-- [comment](https://example.test/comment) -->
      MARKDOWN

      first = root.join("first.json")
      second = root.join("second.json")
      first_status = run_cli(root, first)
      second_status = run_cli(root, second)
      report = JSON.parse(first.read)
      kept = report.fetch("links").find { |item| item.fetch("url") == "https://example.test/kept" }
      query = report.fetch("links").find { |item| item.fetch("query_redacted") }

      assert_equal 0, first_status
      assert_equal 0, second_status
      assert_equal first.binread, second.binread
      assert_equal 4, report.dig("summary", "markdown_https_occurrence_count")
      assert_equal 3, report.dig("summary", "unique_markdown_https_target_count")
      assert_equal 2, kept.fetch("occurrence_count")
      assert_equal "https://example.test/query", query.fetch("url")
      refute_includes first.read, "must-not-appear"
    end
  end

  def test_live_mode_separates_pass_manual_review_failure_and_downgrade
    with_fixture do |root|
      urls = {
        ok_206: "https://one.example.test/ok",
        ok_200: "https://two.example.test/ok",
        forbidden: "https://three.example.test/forbidden",
        missing: "https://four.example.test/missing",
        downgrade: "https://five.example.test/downgrade"
      }
      body = urls.map { |name, url| "[#{name}](#{url})" }.join("\n")
      write_chapter(root, "ch.fixture.live", body)
      results = {
        urls.fetch(:ok_206) => result(urls.fetch(:ok_206), 206),
        urls.fetch(:ok_200) => result(urls.fetch(:ok_200), 200),
        urls.fetch(:forbidden) => result(urls.fetch(:forbidden), 403, request_mode: "get-fallback"),
        urls.fetch(:missing) => result(urls.fetch(:missing), 404),
        urls.fetch(:downgrade) => result("http://five.example.test/downgrade", 200)
      }

      auditor = ChapterMarkdownLinkAudit::Auditor.new(
        root: root,
        mode: "live",
        probe: FakeProbe.new(results),
        workers: 8,
        per_host_limit: 2
      )
      report = auditor.report(checked_at: "2026-07-24")
      repeat_report = auditor.report(checked_at: "2026-07-24")
      forbidden = report.fetch("links").find { |item| item.fetch("url") == urls.fetch(:forbidden) }
      downgrade = report.fetch("links").find { |item| item.fetch("url") == urls.fetch(:downgrade) }

      assert_equal(
        JSON.generate(ChapterMarkdownLinkAudit::CLI.canonicalize(report)),
        JSON.generate(ChapterMarkdownLinkAudit::CLI.canonicalize(repeat_report))
      )
      assert_equal "failed", report.fetch("status")
      assert_equal 2, report.dig("summary", "passed_count")
      assert_equal 1, report.dig("summary", "manual_review_count")
      assert_equal 2, report.dig("summary", "failure_count")
      assert_equal "manual-review", forbidden.fetch("outcome")
      assert_equal "http-403", forbidden.fetch("reason")
      assert_equal "failed", downgrade.fetch("outcome")
      assert_equal "effective-url-is-not-https", downgrade.fetch("reason")
      assert_equal false, downgrade.dig("probe", "effective_https")
    end
  end

  def test_transport_inconclusive_results_require_manual_review_without_hiding_real_failures
    with_fixture do |root|
      urls = {
        accepted: "https://accepted.example.test/source",
        accepted_for_processing: "https://processing.example.test/source",
        timeout: "https://timeout.example.test/source",
        empty_reply: "https://empty.example.test/source",
        http2_stream_error: "https://http2.example.test/source",
        dns_failure: "https://dns.example.test/source",
        not_found: "https://missing.example.test/source",
        certificate_error: "https://certificate.example.test/source",
        unknown_curl_error: "https://unknown-curl.example.test/source",
        tls_verification_error: "https://tls.example.test/source",
        downgrade: "https://downgrade.example.test/source"
      }
      write_chapter(
        root,
        "ch.fixture.transport",
        urls.map { |name, url| "[#{name}](#{url})" }.join("\n")
      )
      results = {
        urls.fetch(:accepted) => result(urls.fetch(:accepted), 206),
        urls.fetch(:accepted_for_processing) => result(urls.fetch(:accepted_for_processing), 202),
        urls.fetch(:timeout) => result(
          urls.fetch(:timeout),
          0,
          exit_code: 28,
          ssl_verify_result: 1,
          error: "curl: (28) SSL connection timeout"
        ),
        urls.fetch(:empty_reply) => result(
          urls.fetch(:empty_reply),
          0,
          exit_code: 52,
          error: "curl: (52) Empty reply from server"
        ),
        urls.fetch(:http2_stream_error) => result(
          urls.fetch(:http2_stream_error),
          206,
          exit_code: 92,
          error: "curl: (92) HTTP/2 stream was not closed cleanly"
        ),
        urls.fetch(:dns_failure) => result(
          urls.fetch(:dns_failure),
          0,
          exit_code: 6,
          error: "curl: (6) Could not resolve host"
        ),
        urls.fetch(:not_found) => result(urls.fetch(:not_found), 404),
        urls.fetch(:certificate_error) => result(
          urls.fetch(:certificate_error),
          0,
          exit_code: 60,
          ssl_verify_result: 20,
          error: "curl: (60) certificate problem"
        ),
        urls.fetch(:unknown_curl_error) => result(
          urls.fetch(:unknown_curl_error),
          0,
          exit_code: 99,
          error: "curl: (99) unknown injected failure"
        ),
        urls.fetch(:tls_verification_error) => result(
          urls.fetch(:tls_verification_error),
          200,
          ssl_verify_result: 20
        ),
        urls.fetch(:downgrade) => result(
          "http://downgrade.example.test/source",
          302,
          exit_code: 28
        )
      }

      report = ChapterMarkdownLinkAudit::Auditor.new(
        root: root,
        mode: "live",
        probe: FakeProbe.new(results)
      ).report(checked_at: "2026-07-24")
      by_url = report.fetch("links").to_h { |item| [item.fetch("url"), item] }

      assert_equal "failed", report.fetch("status")
      assert_equal 1, report.dig("summary", "passed_count")
      assert_equal 5, report.dig("summary", "manual_review_count")
      assert_equal 5, report.dig("summary", "transport_inconclusive_count")
      assert_equal 5, report.dig("summary", "failure_count")
      assert_equal "transport-inconclusive-http-202", by_url.fetch(urls.fetch(:accepted_for_processing)).fetch("reason")
      assert_equal "transport-inconclusive-curl-exit-28", by_url.fetch(urls.fetch(:timeout)).fetch("reason")
      assert_equal "transport-inconclusive-curl-exit-52", by_url.fetch(urls.fetch(:empty_reply)).fetch("reason")
      assert_equal "transport-inconclusive-curl-exit-92", by_url.fetch(urls.fetch(:http2_stream_error)).fetch("reason")
      assert_equal "transport-inconclusive-curl-exit-6", by_url.fetch(urls.fetch(:dns_failure)).fetch("reason")
      assert_equal "failed", by_url.fetch(urls.fetch(:not_found)).fetch("outcome")
      assert_equal "http-404-not-accepted", by_url.fetch(urls.fetch(:not_found)).fetch("reason")
      assert_equal "failed", by_url.fetch(urls.fetch(:certificate_error)).fetch("outcome")
      assert_equal "certificate-validation-curl-exit-60", by_url.fetch(urls.fetch(:certificate_error)).fetch("reason")
      assert_equal "failed", by_url.fetch(urls.fetch(:unknown_curl_error)).fetch("outcome")
      assert_equal "curl-exit-99", by_url.fetch(urls.fetch(:unknown_curl_error)).fetch("reason")
      assert_equal "failed", by_url.fetch(urls.fetch(:tls_verification_error)).fetch("outcome")
      assert_equal "tls-verification-failed", by_url.fetch(urls.fetch(:tls_verification_error)).fetch("reason")
      assert_equal "failed", by_url.fetch(urls.fetch(:downgrade)).fetch("outcome")
      assert_equal "effective-url-is-not-https", by_url.fetch(urls.fetch(:downgrade)).fetch("reason")
      assert_includes report.fetch("evidence_boundary"), "transport-inconclusive"
      assert_equal [202], report.dig("probe_policy", "transport_inconclusive_http_statuses")
      assert_equal [5, 6, 7, 16, 28, 35, 52, 55, 56, 92], report.dig("probe_policy", "transport_inconclusive_curl_exit_codes")
      assert_includes report.dig("probe_policy", "certificate_hard_failure_curl_exit_codes"), 60
    end
  end

  def test_userinfo_target_fails_structure_and_credentials_are_redacted
    with_fixture do |root|
      write_chapter(
        root,
        "ch.fixture.credentials",
        "[unsafe](https://alice:super-secret@example.test/source)"
      )

      report = ChapterMarkdownLinkAudit::Auditor.new(
        root: root,
        mode: "structure-only"
      ).report(checked_at: "2026-07-24")
      serialized = JSON.generate(ChapterMarkdownLinkAudit::CLI.canonicalize(report))

      assert_equal "failed", report.fetch("status")
      assert_equal 1, report.dig("summary", "structure_invalid_count")
      assert_equal "https://example.test/source", report.fetch("links").first.fetch("url")
      refute_includes serialized, "alice"
      refute_includes serialized, "super-secret"
    end
  end

  def test_live_scheduler_caps_total_and_per_host_concurrency
    with_fixture do |root|
      urls = 6.times.flat_map do |host_index|
        4.times.map { |path_index| "https://host#{host_index}.example.test/path#{path_index}" }
      end
      write_chapter(root, "ch.fixture.concurrent", urls.map.with_index { |url, index| "[link#{index}](#{url})" }.join("\n"))
      probe = ConcurrencyProbe.new

      report = ChapterMarkdownLinkAudit::Auditor.new(
        root: root,
        mode: "live",
        probe: probe,
        workers: 8,
        per_host_limit: 2
      ).report(checked_at: "2026-07-24")

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

  def test_checked_at_is_mandatory_and_invalid_limits_fail_closed
    stdout = StringIO.new
    stderr = StringIO.new

    exit_code = ChapterMarkdownLinkAudit::CLI.run(
      ["--root", ROOT.to_s],
      stdout: stdout,
      stderr: stderr
    )

    assert_equal 2, exit_code
    assert_includes stderr.string, "--checked-at is required"
    assert_raises(ChapterMarkdownLinkAudit::AuditError) do
      ChapterMarkdownLinkAudit::Auditor.new(root: ROOT, workers: 9)
    end
    assert_raises(ChapterMarkdownLinkAudit::AuditError) do
      ChapterMarkdownLinkAudit::Auditor.new(root: ROOT, per_host_limit: 3)
    end
  end

  def test_runtime_probe_error_becomes_a_concise_cli_operational_failure
    with_fixture do |root|
      write_chapter(root, "ch.fixture.raise", "[source](https://example.test/source)")
      stdout = StringIO.new
      stderr = StringIO.new

      exit_code = ChapterMarkdownLinkAudit::CLI.run(
        ["--root", root.to_s, "--mode", "live", "--checked-at", "2026-07-24"],
        stdout: stdout,
        stderr: stderr,
        probe: RuntimeRaisingProbe.new
      )

      assert_equal 2, exit_code
      assert_empty stdout.string
      assert_equal "CHAPTER MARKDOWN LINK AUDIT FAILED: probe worker failed (RuntimeError)\n", stderr.string
      refute_includes stderr.string, "test_chapter_markdown_link_audit.rb"
    end
  end

  def test_version_source_atomic_writer_replaces_the_destination
    Dir.mktmpdir("version-source-atomic-output-") do |directory|
      destination = File.join(directory, "report.json")

      VersionSourceAudit::CLI.atomic_write(destination, "first\n")
      VersionSourceAudit::CLI.atomic_write(destination, "second\n")

      assert_equal "second\n", File.binread(destination)
      assert_empty Dir.glob(File.join(directory, ".version-source-audit-*.tmp"))
    end
  end

  private

  def with_fixture
    Dir.mktmpdir("chapter-markdown-link-audit-") do |directory|
      yield Pathname(directory).realpath
    end
  end

  def write_chapter(root, chapter_id, body)
    directory = root.join("book/volume-00-fixture/chapters")
    directory.mkpath
    directory.join("#{chapter_id}.md").write(<<~MARKDOWN)
      ---
      schema_version: 2
      id: #{chapter_id}
      title: fixture
      ---
      # Fixture

      #{body}
    MARKDOWN
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

  def run_cli(root, output)
    ChapterMarkdownLinkAudit::CLI.run(
      [
        "--root", root.to_s,
        "--mode", "structure-only",
        "--checked-at", "2026-07-24",
        "--output", output.to_s,
        "--pretty"
      ],
      stdout: StringIO.new,
      stderr: StringIO.new
    )
  end
end
