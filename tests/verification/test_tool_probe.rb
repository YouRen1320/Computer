# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"

require_relative "../../verification/lib/tool_probe"

class ObservedToolProbeTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  class FakeRunner
    attr_reader :calls

    def initialize
      @calls = []
    end

    def call(env:, argv:, chdir:)
      @calls << { env: env, argv: argv, chdir: chdir }
      Verification::CommandResult.new(
        stdout: "tool 1.2 at #{env.fetch('HOME')}/state\n",
        stderr: "",
        exit_code: 0,
        timed_out: false
      )
    end
  end

  def test_probes_fixed_allowlisted_commands_and_normalizes_ephemeral_paths
    runner = FakeRunner.new
    probes = Verification::ObservedToolProbe.new(
      root: ROOT,
      command_runner: runner,
      environment: { "PATH" => ENV.fetch("PATH", "") }
    ).call(%w[ruby bash ruby])

    assert_equal %w[bash ruby], probes.map { |probe| probe.fetch("id") }
    assert_equal [["bash", "--version"], ["ruby", "--version"]], probes.map { |probe| probe.fetch("version_argv") }
    assert probes.all? { |probe| probe.fetch("status") == "observed" }
    assert probes.all? { |probe| probe.fetch("observed_first_line").include?("$PROBE_ROOT") }
    assert probes.all? { |probe| probe.fetch("normalized_version_output_sha256").match?(/\A[0-9a-f]{64}\z/) }
    assert runner.calls.all? { |call| call.fetch(:env).fetch("HOME").include?("factorycare-tool-probe-") }
    assert runner.calls.all? { |call| call.fetch(:chdir) == ROOT }
  end

  def test_unknown_tool_fails_closed
    error = assert_raises(Verification::ContractError) do
      Verification::ObservedToolProbe.new(root: ROOT, command_runner: FakeRunner.new).call(["unknown"])
    end

    assert_equal "E_TOOL_NOT_ALLOWLISTED", error.code
  end

  def test_pnpm_probe_uses_preseeded_corepack_without_network
    runner = FakeRunner.new
    Verification::ObservedToolProbe.new(
      root: ROOT,
      command_runner: runner,
      environment: {
        "PATH" => ENV.fetch("PATH", ""),
        "COREPACK_HOME" => "/fixed/corepack"
      }
    ).call(["pnpm"])

    environment = runner.calls.fetch(0).fetch(:env)
    assert_equal "/fixed/corepack", environment.fetch("COREPACK_HOME")
    assert_equal "0", environment.fetch("COREPACK_ENABLE_NETWORK")
    assert_equal "false", environment.fetch("pnpm_config_manage_package_manager_versions")
  end

  def test_sanitized_path_preserves_incoming_priority_for_conflicting_executables
    Dir.mktmpdir("tool-probe-path-") do |directory|
      preferred = File.join(directory, "preferred")
      secondary = File.join(directory, "secondary")
      unrelated = File.join(directory, "unrelated")
      [preferred, secondary, unrelated].each { |path| Dir.mkdir(path) }
      make_executable(File.join(preferred, "node"))
      make_executable(File.join(secondary, "dart"))
      make_executable(File.join(secondary, "node"))
      make_executable(File.join(unrelated, "not-allowlisted"))

      runner = FakeRunner.new
      Verification::ObservedToolProbe.new(
        root: ROOT,
        command_runner: runner,
        environment: {
          "PATH" => [preferred, unrelated, secondary, "relative-bin"].join(File::PATH_SEPARATOR)
        }
      ).call(["node"])

      sanitized = runner.calls.fetch(0).fetch(:env).fetch("PATH").split(File::PATH_SEPARATOR)
      assert_operator sanitized.index(preferred), :<, sanitized.index(secondary)
      refute_includes sanitized, unrelated
      refute_includes sanitized, "relative-bin"
      assert_equal %w[/usr/bin /bin /usr/sbin /sbin], sanitized.last(4)
      assert_equal File.join(preferred, "node"), resolved_executable(sanitized, "node")
      assert_equal File.join(secondary, "dart"), resolved_executable(sanitized, "dart")
    end
  end

  private

  def make_executable(path)
    File.write(path, "#!/bin/sh\nexit 0\n")
    File.chmod(0o755, path)
  end

  def resolved_executable(path_entries, command)
    directory = path_entries.find do |entry|
      candidate = File.join(entry, command)
      File.file?(candidate) && File.executable?(candidate)
    end
    File.join(directory, command) if directory
  end
end
