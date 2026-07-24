# frozen_string_literal: true

require "minitest/autorun"
require "pathname"
require "tmpdir"

require_relative "../../scripts/audit-encyclopedia-endpoints"

class EncyclopediaEndpointAuditTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
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

  def test_public_roles_run_twice_and_private_solution_runs_once
    endpoints = %w[example exercise lab private-solution].map do |role|
      FakeEndpoint.new(chapter_id: "ch.fixture", role: role, relative_path: "#{role}/verify.sh", absolute_path: "/fixture")
    end
    records = {}
    endpoints.each do |endpoint|
      result = endpoint.role == "exercise" ? run_result(7, "intentionally incomplete\n") : run_result(0, "PASS\n")
      records[[endpoint.chapter_id, endpoint.role]] =
        EncyclopediaEndpointAudit::REPEAT_ROLES.include?(endpoint.role) ? [result, result.dup] : [result]
    end
    auditor = EncyclopediaEndpointAudit::Auditor.allocate
    auditor.instance_variable_set(:@timeout_seconds, 5)
    auditor.instance_variable_set(:@runner, FakeRunner.new(records))

    output = endpoints.map { |endpoint| auditor.send(:audit, endpoint) }

    assert output.all? { |record| record.fetch("status") == "passed" }
    refute_nil output.find { |record| record.fetch("role") == "example" }.fetch("repeat_run")
    refute_nil output.find { |record| record.fetch("role") == "exercise" }.fetch("repeat_run")
    refute_nil output.find { |record| record.fetch("role") == "lab" }.fetch("repeat_run")
    assert_nil output.find { |record| record.fetch("role") == "private-solution" }.fetch("repeat_run")
  end

  def test_default_inventory_fails_closed_for_1019_or_1021_endpoints
    [1019, 1021].each do |count|
      inventory = Struct.new(:endpoints).new(Array.new(count))
      auditor = EncyclopediaEndpointAudit::Auditor.new(
        root: ROOT,
        jobs: 1,
        timeout_seconds: 5,
        runner: FakeRunner.new({})
      )

      error = EncyclopediaEndpointAudit::Inventory.stub(:new, inventory) do
        assert_raises(EncyclopediaEndpointAudit::AuditError) { auditor.run }
      end

      assert_equal "expected 1020 endpoints, found #{count}", error.message
    end
  end

  def test_catalog_rejects_noncanonical_chapter_id_before_path_construction
    Dir.mktmpdir("endpoint-catalog-test-") do |directory|
      root = Pathname(File.realpath(directory))
      root.join("curriculum").mkpath
      chapters = Array.new(255) { |index| { "id" => format("ch.fixture.topic-%03d", index) } }
      chapters.fetch(17)["id"] = "../escape"
      root.join("curriculum/catalog.yml").write(Psych.dump("chapters" => chapters))

      error = assert_raises(EncyclopediaEndpointAudit::AuditError) do
        EncyclopediaEndpointAudit::Inventory.new(root).chapter_ids
      end

      assert_includes error.message, "canonical chapter ids"
    end
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
    assert_includes record.fetch("failures"), "fresh-copy repeat changed exit code, normalized diagnostics, or output closure"
    assert_equal record.fetch("failures").uniq, record.fetch("failures")
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
    assert_equal "1", environment.fetch("NODE_DISABLE_COMPILE_CACHE")
    assert_equal "1", environment.fetch("NO_COLOR")
    assert_equal before, ENV.to_h
  end

  def test_pnpm_runtime_is_explicit_preseeded_and_redacted
    Dir.mktmpdir("endpoint-runtime-test-") do |directory|
      base = Pathname(File.realpath(directory))
      repository = base.join("repository")
      repository.mkdir
      runtime = base.join("runtime")
      runtime.join("bin").mkpath
      runtime.join("corepack/v1/pnpm/10.18.0").mkpath
      runtime.join("corepack/v1/pnpm/11.11.0").mkpath
      entry = runtime.join("bin/pnpm")
      entry.write("#!/bin/sh\nexit 0\n")
      entry.chmod(0o755)

      missing = assert_raises(EncyclopediaEndpointAudit::AuditError) do
        EncyclopediaEndpointAudit::PnpmRuntimePolicy.resolve(root: repository, env: {})
      end
      assert_includes missing.message, "FACTORYCARE_PNPM_RUNTIME_ROOT"

      policy = EncyclopediaEndpointAudit::PnpmRuntimePolicy.resolve(
        root: repository,
        env: { "FACTORYCARE_PNPM_RUNTIME_ROOT" => runtime.to_s }
      )
      environment = policy.apply("PATH" => "/usr/bin:/bin")
      summary = policy.evidence_summary

      assert_equal runtime.join("corepack").to_s, environment.fetch("COREPACK_HOME")
      assert_equal "0", environment.fetch("COREPACK_ENABLE_NETWORK")
      assert environment.fetch("PATH").start_with?(runtime.join("bin").to_s)
      assert_equal %w[10.18.0 11.11.0], summary.fetch("available_versions")
      assert_match(/\A[0-9a-f]{64}\z/, summary.fetch("pnpm_entry_sha256"))
      assert_equal 1, summary.fetch("cli_file_count")
      assert_match(/\A[0-9a-f]{64}\z/, summary.fetch("cli_tree_sha256"))
      refute_includes JSON.generate(summary), runtime.to_s
    end
  end

  def test_docker_compose_runtime_is_explicit_regular_hashed_and_redacted
    Dir.mktmpdir("endpoint-docker-runtime-test-") do |directory|
      base = Pathname(File.realpath(directory))
      repository = base.join("repository")
      repository.mkdir
      plugin = base.join("docker-compose")
      plugin.write("#!/bin/sh\nprintf 'compose fixture\\n'\n")
      plugin.chmod(0o755)

      missing = assert_raises(EncyclopediaEndpointAudit::AuditError) do
        EncyclopediaEndpointAudit::DockerComposeRuntimePolicy.resolve(root: repository, env: {})
      end
      assert_includes missing.message, "FACTORYCARE_DOCKER_COMPOSE_PLUGIN"

      policy = EncyclopediaEndpointAudit::DockerComposeRuntimePolicy.resolve(
        root: repository,
        env: { "FACTORYCARE_DOCKER_COMPOSE_PLUGIN" => plugin.to_s }
      )
      summary = policy.evidence_summary

      assert_equal Digest::SHA256.file(plugin).hexdigest, summary.fetch("plugin_sha256")
      assert_equal summary.fetch("plugin_sha256"), summary.fetch("staged_plugin_sha256")
      assert_equal plugin.size, summary.fetch("plugin_size_bytes")
      refute_includes JSON.generate(summary), plugin.to_s

      staged = base.join("staged-docker-compose")
      policy.copy_verified_plugin_to!(staged.to_s)
      assert_equal summary.fetch("plugin_sha256"), Digest::SHA256.file(staged).hexdigest
      plugin.write("#!/bin/sh\nprintf 'changed after freeze\\n'\n")
      changed = assert_raises(EncyclopediaEndpointAudit::AuditError) do
        policy.copy_verified_plugin_to!(base.join("changed-copy").to_s)
      end
      assert_includes changed.message, "changed after identity freeze"

      link = base.join("docker-compose-link")
      link.make_symlink(plugin)
      error = assert_raises(EncyclopediaEndpointAudit::AuditError) do
        EncyclopediaEndpointAudit::DockerComposeRuntimePolicy.resolve(
          root: repository,
          env: { "FACTORYCARE_DOCKER_COMPOSE_PLUGIN" => link.to_s }
        )
      end
      assert_includes error.message, "symbolic link"
    end
  end

  def test_docker_compose_endpoint_gets_only_a_staged_plugin_and_credential_free_config
    with_process_endpoint(role: "example", script: <<~'SH') do |source, endpoint, _runner|
      #!/bin/sh
      set -eu
      test -f "$HOME/.docker/config.json"
      test -x "$HOME/.docker/cli-plugins/docker-compose"
      test "$(find "$HOME/.docker/cli-plugins" -type f | wc -l | tr -d ' ')" = 1
      ! grep -Eq 'auths|credsStore|currentContext' "$HOME/.docker/config.json"
      printf 'DOCKER_RUNTIME_PASS\n'
    SH
      plugin = source.dirname.join("docker-compose-runtime")
      plugin.write("#!/bin/sh\nexit 0\n")
      plugin.chmod(0o755)
      policy = EncyclopediaEndpointAudit::DockerComposeRuntimePolicy.resolve(
        root: source,
        env: { "FACTORYCARE_DOCKER_COMPOSE_PLUGIN" => plugin.to_s }
      )
      endpoint.chapter_id = "ch.ops.compose-services"
      runner = EncyclopediaEndpointAudit::ProcessRunner.new(
        timeout_seconds: 5,
        environment: { "PATH" => "/usr/bin:/bin", "LANG" => "C", "LC_ALL" => "C" },
        docker_compose_runtime_policy: policy
      )

      result = runner.call(endpoint)

      assert_equal 0, result.fetch("exit_code")
      assert_equal "DOCKER_RUNTIME_PASS\n", result.fetch("stdout")
      assert_equal 0, result.fetch("generated_output_count")
      assert_equal 0, result.fetch("tool_owned_runtime_scratch_count")
    end
  end

  def test_only_exact_dart_server_home_prefix_is_classified_as_tool_scratch
    runner = EncyclopediaEndpointAudit::ProcessRunner.allocate
    before = {}
    after = {
      "home/.dartServer" => { "kind" => "directory" },
      "home/.dartServer/.analysis-driver/cache" => { "kind" => "file", "sha256" => "a" * 64, "size_bytes" => 1 },
      "home/.dartServer-neighbor/cache" => { "kind" => "file", "sha256" => "b" * 64, "size_bytes" => 1 },
      "home/nested/.dartServer/cache" => { "kind" => "file", "sha256" => "c" * 64, "size_bytes" => 1 },
      "tmp/.dartServer/cache" => { "kind" => "file", "sha256" => "d" * 64, "size_bytes" => 1 }
    }

    failures, semantic, scratch = runner.send(:output_delta, before, after)

    assert_empty failures
    assert_equal [
      "home/.dartServer",
      "home/.dartServer/.analysis-driver/cache"
    ], scratch.map { |entry| entry.fetch("path") }
    assert_equal [
      "home/.dartServer-neighbor/cache",
      "home/nested/.dartServer/cache",
      "tmp/.dartServer/cache"
    ], semantic.map { |entry| entry.fetch("path") }
  end

  def test_endpoint_report_schema_requires_public_repeat_run_and_private_null
    report = valid_endpoint_report
    Verification::MachineReportSchema.validate!(
      root: ROOT,
      schema_path: "schemas/encyclopedia-endpoint-audit.schema.json",
      document: report
    )

    bad_public = Marshal.load(Marshal.dump(report))
    bad_public.fetch("results").find { |record| record.fetch("role") == "example" }["repeat_run"] = "not-a-run"
    assert_raises(Verification::ContractError) do
      Verification::MachineReportSchema.validate!(
        root: ROOT,
        schema_path: "schemas/encyclopedia-endpoint-audit.schema.json",
        document: bad_public
      )
    end

    bad_private = Marshal.load(Marshal.dump(report))
    private_record = bad_private.fetch("results").find { |record| record.fetch("role") == "private-solution" }
    private_record["repeat_run"] = private_record.fetch("first_run")
    assert_raises(Verification::ContractError) do
      Verification::MachineReportSchema.validate!(
        root: ROOT,
        schema_path: "schemas/encyclopedia-endpoint-audit.schema.json",
        document: bad_private
      )
    end
  end

  def test_executes_the_declared_shebang_instead_of_forcing_bash
    with_process_endpoint(role: "example", script: <<~'SH') do |_source, endpoint, runner|
      #!/bin/zsh -f
      set -eu
      SCRIPT_DIR=${0:A:h}
      print -r -- "$SCRIPT_DIR"
    SH
      result = runner.call(endpoint)

      assert_equal 0, result.fetch("exit_code")
      assert_equal ["./verify.sh"], result.fetch("command")
    end
  end

  def test_process_environment_uses_ephemeral_home_and_tmp_without_parent_secrets
    previous = ENV["FACTORYCARE_PARENT_SECRET"]
    ENV["FACTORYCARE_PARENT_SECRET"] = "must-not-reach-child"
    with_process_endpoint(role: "example", script: <<~'SH') do |_source, endpoint, runner|
      #!/bin/sh
      set -eu
      test -z "${FACTORYCARE_PARENT_SECRET+x}"
      case "$HOME" in *factorycare-endpoint-copy-*/home) ;; *) exit 7 ;; esac
      case "$TMPDIR" in *factorycare-endpoint-copy-*/tmp) ;; *) exit 8 ;; esac
      printf 'MINIMAL_ENV_PASS\n'
    SH
      result = runner.call(endpoint)

      assert_equal 0, result.fetch("exit_code")
      assert_equal "MINIMAL_ENV_PASS\n", result.fetch("stdout")
    end
  ensure
    previous.nil? ? ENV.delete("FACTORYCARE_PARENT_SECRET") : ENV["FACTORYCARE_PARENT_SECRET"] = previous
  end

  def test_public_same_chapter_closure_includes_only_public_roles_and_excludes_other_chapters
    with_chapter_repository(role: "example", script: <<~'SH') do |root, endpoint, runner|
      #!/bin/sh
      set -eu
      test -f ../../../exercises/encyclopedia/ch.fixture/exercise.txt
      test -f ../../../labs/encyclopedia/ch.fixture/lab.txt
      test ! -e ../../../solutions-private/encyclopedia/ch.fixture/secret.txt
      test ! -e ../../../examples/encyclopedia/ch.other/outside.txt
      printf 'PUBLIC_CLOSURE_PASS\n'
    SH
      root.join("exercises/encyclopedia/ch.fixture/exercise.txt").write("exercise\n")
      root.join("labs/encyclopedia/ch.fixture/lab.txt").write("lab\n")
      root.join("solutions-private/encyclopedia/ch.fixture/secret.txt").write(
        "PRIVATE_SOLUTION_DO_NOT_PUBLISH_FIXTURE\n"
      )
      outside = root.join("examples/encyclopedia/ch.other")
      outside.mkpath
      outside.join("outside.txt").write("outside\n")

      result = runner.call(endpoint)

      assert_equal 0, result.fetch("exit_code")
      assert_equal "PUBLIC_CLOSURE_PASS\n", result.fetch("stdout")
      refute_includes result.fetch("stdout") + result.fetch("stderr"), "PRIVATE_SOLUTION_DO_NOT_PUBLISH"
    end
  end

  def test_private_same_chapter_closure_can_read_public_inputs_and_its_private_root
    with_chapter_repository(role: "private-solution", script: <<~'SH') do |root, endpoint, runner|
      #!/bin/sh
      set -eu
      test -f ../../../examples/encyclopedia/ch.fixture/example.txt
      test -f ../../../exercises/encyclopedia/ch.fixture/exercise.txt
      test -f secret.txt
      printf 'PRIVATE_CLOSURE_PASS\n'
    SH
      root.join("examples/encyclopedia/ch.fixture/example.txt").write("example\n")
      root.join("exercises/encyclopedia/ch.fixture/exercise.txt").write("exercise\n")
      root.join("solutions-private/encyclopedia/ch.fixture/secret.txt").write("secret\n")

      result = runner.call(endpoint)

      assert_equal 0, result.fetch("exit_code")
      assert_equal "PRIVATE_CLOSURE_PASS\n", result.fetch("stdout")
    end
  end

  def test_normalizes_only_declared_diff_timestamps_and_nonbenchmark_inference_metrics
    endpoint = FakeEndpoint.new(
      chapter_id: "ch.fixture", role: "example", relative_path: "examples/verify.sh", absolute_path: "/fixture"
    )
    first = run_result(
      0,
      "--- expected\t2026-07-24 03:19:14\n+++ actual\t2026-07-24 03:19:16\n" \
        "PASS inference CPU example: local_sanity_ms=3.631, local_items_per_second=55077.5 (not a production benchmark)\n"
    )
    second = run_result(
      0,
      "--- expected\t2026-07-24 03:20:18\n+++ actual\t2026-07-24 03:20:21\n" \
        "PASS inference CPU example: local_sanity_ms=3.506, local_items_per_second=57049.8 (not a production benchmark)\n"
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

  def test_normalizes_only_the_duration_on_vitest_per_file_result_lines
    endpoint = FakeEndpoint.new(
      chapter_id: "ch.fixture", role: "lab", relative_path: "labs/verify.sh", absolute_path: "/fixture"
    )
    first = run_result(0, " \e[32m✓\e[39m tests/api.test.ts \e[2m(\e[22m7 tests\e[2m)\e[22m\e[32m 3\e[2mms\e[22m\e[39m\n")
    second = run_result(0, " \e[32m✓\e[39m tests/api.test.ts \e[2m(\e[22m7 tests\e[2m)\e[22m\e[32m 2\e[2mms\e[22m\e[39m\n")
    auditor = EncyclopediaEndpointAudit::Auditor.allocate
    auditor.instance_variable_set(:@timeout_seconds, 5)
    auditor.instance_variable_set(:@runner, FakeRunner.new(
      [endpoint.chapter_id, endpoint.role] => [first, second]
    ))

    record = auditor.send(:audit, endpoint)

    assert_equal "passed", record.fetch("status")
    assert_equal record.dig("first_run", "normalized_stdout_sha256"), record.dig("repeat_run", "normalized_stdout_sha256")
  end

  def test_every_role_runs_in_a_fresh_copy_without_polluting_the_source
    %w[example exercise lab private-solution].each do |role|
      with_process_endpoint(role: role, script: <<~'SH') do |source, endpoint, runner|
        #!/bin/sh
        set -eu
        mkdir -p build
        printf 'generated\n' > build/result.txt
        pwd
      SH
        result = runner.call(endpoint)

        assert_equal 0, result.fetch("exit_code"), role
        assert_empty result.fetch("closure_failures"), role
        assert_equal 2, result.fetch("generated_output_count"), role
        refute source.join("build").exist?, role
        refute_equal source.to_s, result.fetch("stdout").strip, role
        assert_includes result.fetch("stdout"), "factorycare-endpoint-copy-", role
      end
    end
  end

  def test_input_mutation_marks_output_closure_failed_but_leaves_source_untouched
    with_process_endpoint(role: "example", script: <<~'SH', extra_files: { "input.txt" => "stable\n" }) do |source, endpoint, runner|
      #!/bin/sh
      set -eu
      printf 'changed\n' > input.txt
      printf 'PASS\n'
    SH
      result = runner.call(endpoint)
      auditor = EncyclopediaEndpointAudit::Auditor.allocate
      auditor.instance_variable_set(:@timeout_seconds, 5)

      assert_equal ["contracted input was modified or deleted"], result.fetch("closure_failures")
      assert_includes auditor.send(:contract_failures, endpoint, result), "contracted input was modified or deleted"
      assert_equal "stable\n", source.join("input.txt").read
    end
  end

  def test_generated_symlink_that_escapes_copy_is_rejected
    with_process_endpoint(role: "lab", script: <<~'SH') do |_source, endpoint, runner|
      #!/bin/sh
      set -eu
      ln -s /tmp escaped-link
      printf 'PASS\n'
    SH
      error = assert_raises(EncyclopediaEndpointAudit::AuditError) { runner.call(endpoint) }

      assert_equal "generated symbolic link escapes the staged asset root", error.message
    end
  end

  def test_dart_server_scratch_still_rejects_symlinks_and_special_files
    with_process_endpoint(role: "lab", script: <<~'SH') do |_source, endpoint, runner|
      #!/bin/sh
      set -eu
      mkdir -p "$HOME/.dartServer"
      ln -s /tmp "$HOME/.dartServer/escape"
    SH
      error = assert_raises(EncyclopediaEndpointAudit::AuditError) { runner.call(endpoint) }
      assert_equal "generated symbolic link escapes the staged asset root", error.message
    end

    with_process_endpoint(role: "lab", script: <<~'SH') do |_source, endpoint, runner|
      #!/bin/sh
      set -eu
      mkdir -p "$HOME/.dartServer"
      mkfifo "$HOME/.dartServer/fifo"
    SH
      error = assert_raises(EncyclopediaEndpointAudit::AuditError) { runner.call(endpoint) }
      assert_equal "generated special filesystem entries are forbidden", error.message
    end
  end

  def test_timeout_kills_background_processes_from_the_staged_copy
    Dir.mktmpdir("endpoint-timeout-test-") do |directory|
      marker = Pathname(File.realpath(directory)).join("marker")
      script = <<~SH
        #!/bin/sh
        trap '' TERM
        printf x >> #{marker}
        (
          trap '' TERM
          while :; do
            printf x >> #{marker}
            /bin/sleep 0.02
          done
        ) &
        while :; do /bin/sleep 1; done
      SH
      with_process_endpoint(role: "private-solution", script: script) do |_source, endpoint, _runner|
        runner = EncyclopediaEndpointAudit::ProcessRunner.new(
          # Leave enough scheduling headroom for the shell to create the
          # external heartbeat even when other endpoint tests are hashing
          # large tool caches concurrently on a loaded CI host.
          timeout_seconds: 5.0,
          termination_grace_seconds: 0.05,
          environment: { "PATH" => "/usr/bin:/bin", "LANG" => "C", "LC_ALL" => "C" }
        )

        result = runner.call(endpoint)
        size_after_return = marker.size?
        sleep 0.12

        assert_equal true, result.fetch("timed_out")
        assert_operator size_after_return.to_i, :>, 0
        assert_equal size_after_return, marker.size?
      end
    end
  end

  private

  def valid_endpoint_report
    auditor = EncyclopediaEndpointAudit::Auditor.allocate
    auditor.instance_variable_set(:@timeout_seconds, 5)
    results = Array.new(255).each_index.flat_map do |index|
      chapter_id = format("ch.fixture.topic-%03d", index)
      %w[example exercise lab private-solution].map do |role|
        endpoint = FakeEndpoint.new(
          chapter_id: chapter_id,
          role: role,
          relative_path: "#{role}/encyclopedia/#{chapter_id}/verify.sh",
          absolute_path: "/fixture"
        )
        observed = role == "exercise" ? run_result(1, "EXPECTED_RED\n") : run_result(0, "PASS\n")
        repeat = EncyclopediaEndpointAudit::REPEAT_ROLES.include?(role) ? observed.dup : nil
        auditor.send(:summarized, endpoint, observed, repeat, [])
      end
    end
    auditor.send(:build_report, results)
  end

  def with_process_endpoint(role:, script:, extra_files: {})
    Dir.mktmpdir("endpoint-process-test-") do |directory|
      source = Pathname(File.realpath(directory)).join("asset")
      source.mkdir
      verify = source.join("verify.sh")
      verify.write(script)
      verify.chmod(0o755)
      extra_files.each { |name, bytes| source.join(name).write(bytes) }
      endpoint = FakeEndpoint.new(
        chapter_id: "ch.fixture",
        role: role,
        relative_path: "#{role}/verify.sh",
        absolute_path: verify.to_s,
        asset_root: source.to_s
      )
      runner = EncyclopediaEndpointAudit::ProcessRunner.new(
        timeout_seconds: 5,
        environment: { "PATH" => "/usr/bin:/bin", "LANG" => "C", "LC_ALL" => "C" }
      )

      yield source, endpoint, runner
    end
  end

  def with_chapter_repository(role:, script:)
    Dir.mktmpdir("endpoint-chapter-closure-test-") do |directory|
      root = Pathname(File.realpath(directory))
      EncyclopediaEndpointAudit::ROLE_ROOTS.each_value do |asset|
        root.join(asset, "encyclopedia", "ch.fixture").mkpath
      end
      asset = EncyclopediaEndpointAudit::ROLE_ROOTS.fetch(role)
      source = root.join(asset, "encyclopedia", "ch.fixture")
      verify = source.join("verify.sh")
      verify.write(script)
      verify.chmod(0o755)
      endpoint = FakeEndpoint.new(
        chapter_id: "ch.fixture",
        role: role,
        relative_path: "#{asset}/encyclopedia/ch.fixture/verify.sh",
        absolute_path: verify.to_s,
        asset_root: source.to_s
      )
      runner = EncyclopediaEndpointAudit::ProcessRunner.new(
        timeout_seconds: 5,
        environment: { "PATH" => "/usr/bin:/bin", "LANG" => "C", "LC_ALL" => "C" }
      )

      yield root, endpoint, runner
    end
  end

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
