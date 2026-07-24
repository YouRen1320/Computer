# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "pathname"
require "tmpdir"

require_relative "../../scripts/audit-version-sources"

class VersionSourceAuditTest < Minitest::Test
  ROOT = Pathname(__dir__).join("../..").expand_path

  class FakeProbe
    def initialize(overrides = {})
      @overrides = overrides
    end

    def call(url)
      @overrides.fetch(url) do
        VersionSourceAudit::ProbeResult.new(
          exit_code: 0,
          http_status: 206,
          effective_url: url,
          ssl_verify_result: 0,
          request_mode: "range-get",
          error: ""
        )
      end
    end
  end

  class RaisingProbe
    def call(_url)
      raise VersionSourceAudit::AuditError, "injected probe failure"
    end
  end

  def test_current_registry_is_fully_enumerated_without_live_network
    report = VersionSourceAudit::Auditor.new(root: ROOT, probe: FakeProbe.new, workers: 4)
                                        .report(checked_at: "2026-07-24")

    assert_equal "passed", report.fetch("status")
    assert_equal 62, report.fetch("entry_count")
    assert_equal 62, report.fetch("reachable_count")
    assert_equal({ "206" => 62 }, report.fetch("http_status_counts"))
    assert_match(/does not verify/, report.fetch("evidence_boundary"))
  end

  def test_unreachable_source_fails_closed_and_is_preserved_in_report
    source_url = "https://example.invalid/source"
    Dir.mktmpdir("version-source-audit-") do |directory|
      FileUtils.mkdir_p(File.join(directory, "versions"))
      File.write(
        File.join(directory, "versions/registry.yml"),
        <<~YAML
          entries:
            - id: broken
              source_url: #{source_url}
        YAML
      )
      failure = VersionSourceAudit::ProbeResult.new(
        exit_code: 28,
        http_status: 0,
        effective_url: "",
        ssl_verify_result: 0,
        request_mode: "range-get",
        error: "timeout"
      )

      report = VersionSourceAudit::Auditor.new(
        root: directory,
        probe: FakeProbe.new(source_url => failure),
        workers: 1
      ).report(checked_at: "2026-07-24")

      assert_equal "failed", report.fetch("status")
      assert_equal 1, report.fetch("failure_count")
      assert_equal false, report.fetch("entries").first.fetch("reachable")
      assert_equal "timeout", report.fetch("entries").first.fetch("error")
    end
  end

  def test_non_https_source_is_rejected_before_probe
    Dir.mktmpdir("version-source-audit-") do |directory|
      FileUtils.mkdir_p(File.join(directory, "versions"))
      File.write(
        File.join(directory, "versions/registry.yml"),
        "entries:\n  - id: bad\n    source_url: http://example.com/source\n"
      )

      error = assert_raises(VersionSourceAudit::AuditError) do
        VersionSourceAudit::Auditor.new(root: directory, probe: FakeProbe.new, workers: 1)
                                   .report(checked_at: "2026-07-24")
      end
      assert_match(/absolute HTTPS URL/, error.message)
    end
  end

  def test_https_source_that_redirects_to_http_fails_closed
    source_url = "https://example.test/source"
    Dir.mktmpdir("version-source-audit-") do |directory|
      FileUtils.mkdir_p(File.join(directory, "versions"))
      File.write(
        File.join(directory, "versions/registry.yml"),
        "entries:\n  - id: downgrade\n    source_url: #{source_url}\n"
      )
      downgraded = VersionSourceAudit::ProbeResult.new(
        exit_code: 0,
        http_status: 200,
        effective_url: "http://example.test/source",
        ssl_verify_result: 0,
        request_mode: "range-get",
        error: ""
      )

      report = VersionSourceAudit::Auditor.new(
        root: directory,
        probe: FakeProbe.new(source_url => downgraded),
        workers: 1
      ).report(checked_at: "2026-07-24")

      assert_equal "failed", report.fetch("status")
      assert_equal false, report.fetch("entries").first.fetch("effective_https")
    end
  end

  def test_worker_probe_errors_are_not_silently_lost
    error = assert_raises(VersionSourceAudit::AuditError) do
      VersionSourceAudit::Auditor.new(root: ROOT, probe: RaisingProbe.new, workers: 2)
                                 .report(checked_at: "2026-07-24")
    end
    assert_match(/injected probe failure/, error.message)
  end
end
