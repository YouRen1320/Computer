# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "build_model"

ROOT = File.expand_path(__dir__)

def assert(condition, message)
  raise "ASSERTION FAILED: #{message}" unless condition
end

def load_json(name)
  JSON.parse(File.read(File.join(ROOT, name)))
end

def build(repository:, lock:, cache_dir:, output_dir:, profile: "offline", inject_test_failure: false)
  BuildLifecycle.new(
    source: File.join(ROOT, "work_order_source.txt"),
    lock: lock,
    repository: repository,
    cache_dir: cache_dir,
    output_dir: output_dir,
    profile: profile,
    inject_test_failure: inject_test_failure
  ).run
end

repository = load_json("source_repository.json")
project = load_json("project.json")
committed_lock = load_json("project.lock.json")

Dir.mktmpdir("fc-dependency-build-") do |temporary|
  wrong_bin = File.join(temporary, "wrong-bin")
  right_bin = File.join(temporary, "right-bin")
  FileUtils.mkdir_p([wrong_bin, right_bin])
  wrong_tool = File.join(wrong_bin, "fc-build")
  right_tool = File.join(right_bin, "fc-build")
  File.write(wrong_tool, "fc-build 0.8\n")
  File.write(right_tool, "fc-build 1.0\n")
  FileUtils.chmod(0o755, [wrong_tool, right_tool])
  wrong_path = [wrong_bin, right_bin].join(File::PATH_SEPARATOR)
  right_path = [right_bin, wrong_bin].join(File::PATH_SEPARATOR)
  assert(ToolResolution.find("fc-build", wrong_path) == wrong_tool, "PATH order should expose the wrong tool")
  assert(ToolResolution.find("fc-build", right_path) == right_tool, "PATH order should recover the expected tool")
  puts "tool: wrong PATH selected 0.8; corrected PATH selected 1.0"

  child = 'exit(ENV["FACTORYCARE_BUILD_PROFILE"] == "offline" ? 0 : 9)'
  _out, _err, inherited = Open3.capture3({ "FACTORYCARE_BUILD_PROFILE" => "offline" }, RbConfig.ruby, "-e", child)
  _out, _err, missing = Open3.capture3({ "FACTORYCARE_BUILD_PROFILE" => nil }, RbConfig.ruby, "-e", child)
  assert(inherited.success?, "child should observe the explicitly inherited build profile")
  assert(missing.exitstatus == 9, "child without the environment value should fail predictably")
  puts "environment: inherited profile exit=0; removed profile exit=9"

  generated_lock = DependencyResolver.new(repository, project).build_lock(strategy: :lowest)
  assert(generated_lock == committed_lock, "committed lock must equal deterministic lowest-version resolution")
  direct = committed_lock.fetch("packages").select { |entry| entry.fetch("direct") }.map { |entry| entry.fetch("name") }
  transitive = committed_lock.fetch("packages").reject { |entry| entry.fetch("direct") }.map { |entry| entry.fetch("name") }
  assert(direct == ["fc-report"], "fc-report should be direct")
  assert(transitive == ["fc-format"], "fc-format should be transitive")
  puts "resolution: direct=fc-report@1.0.0 transitive=fc-format@1.0.0 lock=stable"

  cache = File.join(temporary, "cache")
  cold = build(repository: repository, lock: committed_lock, cache_dir: cache, output_dir: File.join(temporary, "cold"))
  hot = build(repository: repository, lock: committed_lock, cache_dir: cache, output_dir: File.join(temporary, "hot"))
  assert(cold.fetch("status") == "passed", "cold-cache build should pass from the local source repository")
  assert(hot.fetch("status") == "passed", "hot-cache build should pass")
  assert(cold.fetch("cache_hits") == [false, false], "cold build should fetch both locked packages")
  assert(hot.fetch("cache_hits") == [true, true], "hot build should reuse both cached packages")
  assert(cold.fetch("artifact_sha256") == hot.fetch("artifact_sha256"), "cold and hot artifacts must match")
  puts "cache: cold=[miss,miss] hot=[hit,hit] artifact=#{cold.fetch("artifact_sha256")[0, 12]}…"

  incomplete_repository = Marshal.load(Marshal.dump(repository))
  incomplete_repository.fetch("packages").fetch("fc-format").delete("1.0.0")
  masked = build(
    repository: incomplete_repository,
    lock: committed_lock,
    cache_dir: cache,
    output_dir: File.join(temporary, "masked")
  )
  exposed = build(
    repository: incomplete_repository,
    lock: committed_lock,
    cache_dir: File.join(temporary, "empty-cache"),
    output_dir: File.join(temporary, "exposed")
  )
  assert(masked.fetch("status") == "passed", "warm cache should demonstrate the missing-source masking risk")
  assert(exposed.fetch("status") == "failed", "cold cache must expose the missing locked package")
  assert(exposed.fetch("phases").any? { |phase| phase["phase"] == "package" && phase["status"] == "not-run" }, "failed validation must prevent packaging")
  puts "cache diagnosis: warm cache masked missing source; cold cache failed at validate; package not-run"

  drifted_repository = Marshal.load(Marshal.dump(repository))
  drifted_repository.fetch("packages").fetch("fc-format")["1.2.0"] = {
    "dependencies" => {}, "payload" => "factorycare-format-v1.2"
  }
  drifted_repository.fetch("packages").fetch("fc-report")["1.2.0"] = {
    "dependencies" => { "fc-format" => "1.2.0" }, "payload" => "factorycare-report-v1.2"
  }
  base_unlocked = DependencyResolver.new(repository, project).build_lock(strategy: :highest)
  drifted_unlocked = DependencyResolver.new(drifted_repository, project).build_lock(strategy: :highest)
  assert(base_unlocked != drifted_unlocked, "unlocked highest-version resolution should drift when repository contents change")
  locked_after_drift = build(
    repository: drifted_repository,
    lock: committed_lock,
    cache_dir: File.join(temporary, "drift-cache"),
    output_dir: File.join(temporary, "locked-after-drift")
  )
  assert(locked_after_drift.fetch("artifact_sha256") == cold.fetch("artifact_sha256"), "lock should preserve the artifact after new versions appear")
  puts "version drift: unlocked 1.1.0→1.2.0; committed lock stayed 1.0.0 with identical artifact"

  failed_test = build(
    repository: repository,
    lock: committed_lock,
    cache_dir: File.join(temporary, "failure-cache"),
    output_dir: File.join(temporary, "failure"),
    inject_test_failure: true
  )
  assert(failed_test.fetch("status") == "failed", "injected oracle failure should fail the build")
  test_phase = failed_test.fetch("phases").find { |phase| phase.fetch("phase") == "test" }
  package_phase = failed_test.fetch("phases").find { |phase| phase.fetch("phase") == "package" }
  assert(test_phase.fetch("status") == "failed", "test phase should carry the first trustworthy failure")
  assert(package_phase.fetch("status") == "not-run", "package must not run after test failure")
  assert(failed_test.fetch("artifact_sha256").nil?, "failed test must not produce an artifact")
  puts "lifecycle: clean→validate→compile→test failed; package not-run; artifact absent"
end

puts "dependencies-build-packages verification: PASS"
