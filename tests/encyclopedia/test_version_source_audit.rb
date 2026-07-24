# frozen_string_literal: true

require "minitest/autorun"
require "digest"
require "fileutils"
require "pathname"
require "tmpdir"

require_relative "../../scripts/audit-version-sources"

class VersionSourceAuditTest < Minitest::Test
  ROOT = Pathname(__dir__).join("../..").expand_path

  class FakeProbe
    attr_reader :calls

    def initialize(overrides = {})
      @overrides = overrides
      @calls = []
    end

    def call(url)
      calls << url
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

  def test_current_registry_enumerates_every_source_and_binds_exact_bytes
    bytes = ROOT.join("versions/registry.yml").binread
    probe = FakeProbe.new
    report = VersionSourceAudit::Auditor.new(root: ROOT, probe: probe, workers: 4)
                                        .report(checked_at: "2026-07-24")

    assert_equal "passed", report.fetch("status")
    assert_equal 71, report.fetch("registry_entry_count")
    assert_equal 93, report.fetch("source_count")
    assert_equal 93, report.fetch("reachable_count")
    assert_equal({ "206" => 93 }, report.fetch("http_status_counts"))
    assert_equal 93, probe.calls.length
    assert_equal Digest::SHA256.hexdigest(bytes), report.fetch("registry_sha256")
    assert_equal "manual-only", report.dig("policy_snapshot", "promotion_mode")
    assert_equal false, report.dig("policy_snapshot", "automatic_promotion")
    assert_equal "forbidden-without-human-review", report.dig("evidence_classification", "promotion")
    assert_match(/does not verify/, report.fetch("evidence_boundary"))
  end

  def test_audit_is_read_only_and_never_promotes_registry_status
    before = ROOT.join("versions/registry.yml").binread
    before_statuses = report_statuses(before)

    report = VersionSourceAudit::Auditor.new(root: ROOT, probe: FakeProbe.new, workers: 2)
                                        .report(checked_at: "2026-07-24")

    assert_equal before, ROOT.join("versions/registry.yml").binread
    assert_equal before_statuses, report.fetch("registry_status_counts")
    assert_operator report.fetch("registry_status_counts").fetch("conceptual"), :>, 0
    assert_operator report.fetch("registry_status_counts").fetch("provisional"), :>, 0
  end

  def test_unreachable_source_fails_closed_without_hiding_other_sources
    first_url = "https://example.invalid/first"
    second_url = "https://example.invalid/second"
    with_registry(sources: [source("first", first_url), source("second", second_url)]) do |directory|
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
        probe: FakeProbe.new(first_url => failure),
        workers: 1
      ).report(checked_at: "2026-07-24")

      assert_equal "failed", report.fetch("status")
      assert_equal 2, report.fetch("source_count")
      assert_equal 1, report.fetch("failure_count")
      failed = report.fetch("sources").find { |item| item.fetch("source_id") == "first" }
      assert_equal false, failed.fetch("reachable")
      assert_equal "timeout", failed.fetch("error")
      assert_equal "Exact supported claim for first.", failed.fetch("claim")
    end
  end

  def test_non_https_source_is_rejected_before_probe
    with_registry(sources: [source("bad", "http://example.com/source")]) do |directory|
      error = assert_raises(VersionSourceAudit::AuditError) do
        VersionSourceAudit::Auditor.new(root: directory, probe: FakeProbe.new, workers: 1)
                                   .report(checked_at: "2026-07-24")
      end
      assert_match(/absolute HTTPS URL|url: does not match required pattern/, error.message)
    end
  end

  def test_https_source_that_redirects_to_http_fails_closed
    source_url = "https://example.test/source"
    with_registry(sources: [source("downgrade", source_url)]) do |directory|
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
      assert_equal false, report.fetch("sources").first.fetch("effective_https")
    end
  end

  def test_duplicate_yaml_key_fails_closed
    with_raw_registry(<<~YAML) do |directory|
      schema_version: 2
      schema_version: 2
      registry_id: factorycare-version-registry
      policy:
        source_authority: official-or-primary-only
        promotion_mode: manual-only
        automatic_promotion: false
      entries: []
    YAML
      error = assert_raises(VersionSourceAudit::AuditError) do
        VersionSourceAudit::Auditor.new(root: directory, probe: FakeProbe.new, workers: 1)
                                   .report(checked_at: "2026-07-24")
      end
      assert_match(/duplicate mapping key/, error.message)
    end
  end

  def test_duplicate_source_id_fails_closed
    with_registry(sources: [source("same", "https://example.test/a"), source("same", "https://example.test/b")]) do |directory|
      error = assert_raises(VersionSourceAudit::AuditError) do
        VersionSourceAudit::Auditor.new(root: directory, probe: FakeProbe.new, workers: 1)
                                   .report(checked_at: "2026-07-24")
      end
      assert_match(/duplicate source id same/, error.message)
    end
  end

  def test_legacy_source_url_is_forbidden
    with_raw_registry(<<~YAML) do |directory|
      schema_version: 2
      registry_id: factorycare-version-registry
      edition: 2026.2-draft
      reviewed_at: '2026-07-24'
      policy:
        stable_only: true
        patch_resolution: at-chapter-verification
        recheck_before_use: true
        source_authority: official-or-primary-only
        promotion_mode: manual-only
        automatic_promotion: false
      entries:
        - id: legacy
          name: Legacy sample
          kind: tool
          constraint: exact fixture
          channel: stable
          status: provisional
          reviewed_at: '2026-07-24'
          source_url: https://example.test/legacy
          sources:
            - id: official
              type: documentation
              publisher: Example
              authority: official-or-primary
              checked_at: '2026-07-24'
              claim: Exact supported claim.
              url: https://example.test/new
          notes: Test fixture.
    YAML
      error = assert_raises(VersionSourceAudit::AuditError) do
        VersionSourceAudit::Auditor.new(root: directory, probe: FakeProbe.new, workers: 1)
                                   .report(checked_at: "2026-07-24")
      end
      assert_match(/source_url/, error.message)
    end
  end

  def test_automatic_promotion_policy_is_rejected
    with_registry(sources: [source("official", "https://example.test/source")]) do |directory|
      path = File.join(directory, "versions/registry.yml")
      registry = YAML.safe_load(File.read(path), aliases: false)
      registry.fetch("policy")["automatic_promotion"] = true
      File.write(path, registry.to_yaml)

      error = assert_raises(VersionSourceAudit::AuditError) do
        VersionSourceAudit::Auditor.new(root: directory, probe: FakeProbe.new, workers: 1)
                                   .report(checked_at: "2026-07-24")
      end
      assert_match(/automatic_promotion|manual-only promotion/, error.message)
    end
  end

  def test_missing_claim_and_non_primary_authority_fail_closed
    bad = source("bad", "https://example.test/source").merge("claim" => "", "authority" => "secondary")
    with_registry(sources: [bad]) do |directory|
      error = assert_raises(VersionSourceAudit::AuditError) do
        VersionSourceAudit::Auditor.new(root: directory, probe: FakeProbe.new, workers: 1)
                                   .report(checked_at: "2026-07-24")
      end
      assert_match(/claim must be a non-empty string|authority(?: must equal|: must equal) \"official-or-primary\"/, error.message)
    end
  end

  def test_worker_probe_errors_are_not_silently_lost
    error = assert_raises(VersionSourceAudit::AuditError) do
      VersionSourceAudit::Auditor.new(root: ROOT, probe: RaisingProbe.new, workers: 2)
                                 .report(checked_at: "2026-07-24")
    end
    assert_match(/injected probe failure/, error.message)
  end

  private

  def source(id, url)
    {
      "id" => id,
      "type" => "documentation",
      "publisher" => "Example primary publisher",
      "authority" => "official-or-primary",
      "checked_at" => "2026-07-24",
      "claim" => "Exact supported claim for #{id}.",
      "url" => url
    }
  end

  def with_registry(sources:)
    yaml = {
      "schema_version" => 2,
      "registry_id" => "factorycare-version-registry",
      "edition" => "2026.2-draft",
      "reviewed_at" => "2026-07-24",
      "policy" => {
        "stable_only" => true,
        "patch_resolution" => "at-chapter-verification",
        "recheck_before_use" => true,
        "source_authority" => "official-or-primary-only",
        "promotion_mode" => "manual-only",
        "automatic_promotion" => false
      },
      "entries" => [{
        "id" => "sample",
        "name" => "Sample tool",
        "kind" => "tool",
        "constraint" => "exact fixture",
        "channel" => "stable",
        "status" => "provisional",
        "reviewed_at" => "2026-07-24",
        "sources" => sources,
        "notes" => "Test fixture."
      }]
    }.to_yaml
    with_raw_registry(yaml) { |directory| yield directory }
  end

  def with_raw_registry(yaml)
    Dir.mktmpdir("version-source-audit-") do |directory|
      FileUtils.mkdir_p(File.join(directory, "versions"))
      FileUtils.mkdir_p(File.join(directory, "schemas"))
      File.write(File.join(directory, "versions/registry.yml"), yaml)
      FileUtils.cp(ROOT.join("schemas/version-registry.schema.json"), File.join(directory, "schemas"))
      yield directory
    end
  end

  def report_statuses(bytes)
    YAML.safe_load(bytes, aliases: false).fetch("entries")
        .group_by { |entry| entry.fetch("status") }
        .transform_values(&:length)
        .sort.to_h
  end
end
