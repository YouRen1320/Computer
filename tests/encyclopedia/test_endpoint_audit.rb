# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"

require_relative "../../scripts/audit-encyclopedia-endpoints"

class EncyclopediaEndpointAuditTest < Minitest::Test
  FakeEndpoint = EncyclopediaEndpointAudit::Endpoint

  class FakeRunner
    def initialize(records)
      @records = records
      @calls = Hash.new(0)
    end

    def call(endpoint)
      key = [endpoint.chapter_id, endpoint.role]
      index = @calls[key]
      @calls[key] += 1
      @records.fetch(key).fetch(index)
    end
  end

  def test_green_roles_run_once_and_expected_red_runs_twice
    endpoints = %w[example exercise lab private-solution].map do |role|
      FakeEndpoint.new(chapter_id: "ch.fixture", role: role, relative_path: "#{role}/verify.sh", absolute_path: "/fixture")
    end
    records = {}
    endpoints.each do |endpoint|
      result = endpoint.role == "exercise" ? run_result(7, "intentionally incomplete\n") : run_result(0, "PASS\n")
      records[[endpoint.chapter_id, endpoint.role]] = endpoint.role == "exercise" ? [result, result.dup] : [result]
    end
    auditor = EncyclopediaEndpointAudit::Auditor.allocate
    auditor.instance_variable_set(:@timeout_seconds, 5)
    auditor.instance_variable_set(:@runner, FakeRunner.new(records))

    output = endpoints.map { |endpoint| auditor.send(:audit, endpoint) }

    assert output.all? { |record| record.fetch("status") == "passed" }
    assert_nil output.find { |record| record.fetch("role") == "example" }.fetch("repeat_run")
    refute_nil output.find { |record| record.fetch("role") == "exercise" }.fetch("repeat_run")
  end

  def test_expected_red_must_be_nonzero_and_byte_stable
    endpoint = FakeEndpoint.new(
      chapter_id: "ch.fixture", role: "exercise", relative_path: "exercises/verify.sh", absolute_path: "/fixture"
    )
    runner = FakeRunner.new(
      [endpoint.chapter_id, endpoint.role] => [
        run_result(7, "first diagnostic\n"),
        run_result(7, "second diagnostic\n")
      ]
    )
    auditor = EncyclopediaEndpointAudit::Auditor.allocate
    auditor.instance_variable_set(:@timeout_seconds, 5)
    auditor.instance_variable_set(:@runner, runner)

    record = auditor.send(:audit, endpoint)

    assert_equal "failed", record.fetch("status")
    assert_includes record.fetch("failures"), "expected-red repeat changed exit code or normalized diagnostic lines"
  end

  def test_expected_red_normalizes_paths_addresses_timings_and_unordered_lines
    endpoint = FakeEndpoint.new(
      chapter_id: "ch.fixture", role: "exercise", relative_path: "exercises/verify.sh", absolute_path: "/fixture"
    )
    first = run_result(1, "-second\n+first\nfailed in 0.65s at 0x1069def00 /tmp/run-a/file.py\n")
    second = run_result(1, "+first\n-second\nfailed in 0.53s at 0x10a79f7a0 /tmp/run-b/file.py\n")
    first["normalization_roots"] = ["/tmp/run-a"]
    second["normalization_roots"] = ["/tmp/run-b"]
    auditor = EncyclopediaEndpointAudit::Auditor.allocate
    auditor.instance_variable_set(:@timeout_seconds, 5)
    auditor.instance_variable_set(:@runner, FakeRunner.new(
      [endpoint.chapter_id, endpoint.role] => [first, second]
    ))

    record = auditor.send(:audit, endpoint)

    assert_equal "passed", record.fetch("status")
    refute_equal record.dig("first_run", "stdout_sha256"), record.dig("repeat_run", "stdout_sha256")
    assert_equal record.dig("first_run", "normalized_stdout_sha256"), record.dig("repeat_run", "normalized_stdout_sha256")
  end

  def test_expected_red_normalizes_dart_analyzer_temporary_project_names
    endpoint = FakeEndpoint.new(
      chapter_id: "ch.fixture", role: "exercise", relative_path: "exercises/verify.sh", absolute_path: "/fixture"
    )
    first = run_result(
      1,
      "Formatted 2 files (0 changed) in 0.08 seconds.\n" \
        "Analyzing factorycare-exercise-repeat-20260724-123-a1b2c3...\nNo issues found!\n"
    )
    second = run_result(
      1,
      "Formatted 2 files (0 changed) in 0.09 seconds.\n" \
        "Analyzing factorycare-exercise-repeat-20260724-123-z9y8x7...\nNo issues found!\n"
    )
    auditor = EncyclopediaEndpointAudit::Auditor.allocate
    auditor.instance_variable_set(:@timeout_seconds, 5)
    auditor.instance_variable_set(:@runner, FakeRunner.new(
      [endpoint.chapter_id, endpoint.role] => [first, second]
    ))

    record = auditor.send(:audit, endpoint)

    assert_equal "passed", record.fetch("status")
    assert_equal record.dig("first_run", "normalized_stdout_sha256"), record.dig("repeat_run", "normalized_stdout_sha256")
  end

  def test_expected_red_normalizes_flutter_analyzer_mktemp_project_names
    endpoint = FakeEndpoint.new(
      chapter_id: "ch.fixture", role: "exercise", relative_path: "exercises/verify.sh", absolute_path: "/fixture"
    )
    first = run_result(41, "Analyzing tmp.Mf0LfxVT5J...\nNo issues found!\n")
    second = run_result(41, "Analyzing tmp.zfI0uRtdGf...\nNo issues found!\n")
    auditor = EncyclopediaEndpointAudit::Auditor.allocate
    auditor.instance_variable_set(:@timeout_seconds, 5)
    auditor.instance_variable_set(:@runner, FakeRunner.new(
      [endpoint.chapter_id, endpoint.role] => [first, second]
    ))

    record = auditor.send(:audit, endpoint)

    assert_equal "passed", record.fetch("status")
    assert_equal record.dig("first_run", "normalized_stdout_sha256"), record.dig("repeat_run", "normalized_stdout_sha256")
  end

  def test_zero_exit_is_not_an_expected_red_baseline
    endpoint = FakeEndpoint.new(
      chapter_id: "ch.fixture", role: "exercise", relative_path: "exercises/verify.sh", absolute_path: "/fixture"
    )
    auditor = EncyclopediaEndpointAudit::Auditor.allocate
    auditor.instance_variable_set(:@timeout_seconds, 5)
    auditor.instance_variable_set(:@runner, FakeRunner.new(
      [endpoint.chapter_id, endpoint.role] => [run_result(0, "green by accident\n")]
    ))

    record = auditor.send(:audit, endpoint)

    assert_equal "failed", record.fetch("status")
    assert_includes record.fetch("failures"), "expected a stable nonzero exit, got 0"
  end

  def test_fixed_environment_prefers_jdk_25_without_changing_parent_environment
    before = ENV.to_h
    environment = EncyclopediaEndpointAudit::Auditor.fixed_environment

    assert_equal "/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home", environment.fetch("JAVA_HOME")
    assert environment.fetch("PATH").start_with?("/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home/bin")
    assert_equal before, ENV.to_h
  end

  private

  def run_result(exit_code, stdout, stderr = "")
    {
      "exit_code" => exit_code,
      "timed_out" => false,
      "duration_ms" => 1,
      "stdout" => stdout.b,
      "stderr" => stderr.b
    }
  end
end
