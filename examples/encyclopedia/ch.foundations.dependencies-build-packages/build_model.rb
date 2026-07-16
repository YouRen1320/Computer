# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"

# Produces stable JSON bytes so digests do not depend on hash insertion order.
module CanonicalJSON
  module_function

  def normalize(value)
    case value
    when Hash
      value.keys.sort.each_with_object({}) { |key, result| result[key] = normalize(value.fetch(key)) }
    when Array
      value.map { |item| normalize(item) }
    else
      value
    end
  end

  def dump(value)
    "#{JSON.generate(normalize(value))}\n"
  end

  def digest(value)
    Digest::SHA256.hexdigest(dump(value))
  end
end

class DependencyError < StandardError; end
class BuildFailure < StandardError; end
class TestFailure < BuildFailure; end

# Resolves a deliberately small teaching repository. Its 1.x constraint is a
# local model, not Maven/npm/uv syntax; real tools have different algorithms.
class DependencyResolver
  def initialize(repository, project)
    @repository = repository.fetch("packages")
    @project = project
  end

  def build_lock(strategy: :lowest)
    selected = {}
    direct_names = @project.fetch("direct_dependencies").keys
    direct_names.sort.each do |name|
      resolve(name, @project.fetch("direct_dependencies").fetch(name), selected, strategy)
    end

    {
      "format" => 1,
      "root" => @project.fetch("name"),
      "packages" => selected.keys.sort.map do |name|
        version = selected.fetch(name)
        record = package_record(name, version)
        {
          "name" => name,
          "version" => version,
          "sha256" => CanonicalJSON.digest(record),
          "direct" => direct_names.include?(name)
        }
      end
    }
  end

  private

  def resolve(name, constraint, selected, strategy)
    version = choose_version(name, constraint, strategy)
    previous = selected[name]
    raise DependencyError, "conflicting constraints for #{name}: #{previous} vs #{version}" if previous && previous != version
    return if previous

    selected[name] = version
    package_record(name, version).fetch("dependencies").sort.each do |child_name, child_constraint|
      resolve(child_name, child_constraint, selected, strategy)
    end
  end

  def choose_version(name, constraint, strategy)
    versions = @repository.fetch(name) { raise DependencyError, "unknown package #{name}" }.keys
    matches = versions.select { |version| matches?(version, constraint) }.sort_by { |version| version.split(".").map(&:to_i) }
    raise DependencyError, "no version for #{name} matches #{constraint}" if matches.empty?

    strategy == :highest ? matches.last : matches.first
  end

  def matches?(version, constraint)
    return version == constraint unless constraint.end_with?(".x")

    version.split(".").first == constraint.split(".").first
  end

  def package_record(name, version)
    @repository.fetch(name).fetch(version) { raise DependencyError, "missing #{name}@#{version}" }
  end
end

# Represents a local package cache. A hit deliberately avoids consulting the
# source repository, which lets the verifier expose cache-masked omissions.
class PackageCache
  attr_reader :hits

  def initialize(repository, directory)
    @repository = repository.fetch("packages")
    @directory = directory
    @hits = []
  end

  def fetch(entry)
    name = entry.fetch("name")
    version = entry.fetch("version")
    path = File.join(@directory, name, "#{version}.json")
    if File.file?(path)
      record = JSON.parse(File.read(path))
      @hits << true
    else
      record = @repository.fetch(name) { raise DependencyError, "source repository misses #{name}" }
        .fetch(version) { raise DependencyError, "source repository misses #{name}@#{version}" }
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, CanonicalJSON.dump(record))
      @hits << false
    end
    actual = CanonicalJSON.digest(record)
    expected = entry.fetch("sha256")
    raise DependencyError, "digest mismatch for #{name}@#{version}" unless actual == expected

    record
  end
end

# Runs an explicit clean -> validate -> compile -> test -> package lifecycle.
# Every output is derived from declared inputs and excludes clock/path values.
class BuildLifecycle
  PHASES = %w[clean validate compile test package].freeze

  def initialize(source:, lock:, repository:, cache_dir:, output_dir:, profile:, inject_test_failure: false)
    @source = source
    @lock = lock
    @repository = repository
    @cache_dir = cache_dir
    @output_dir = output_dir
    @profile = profile
    @inject_test_failure = inject_test_failure
    @phase_results = []
  end

  def run
    FileUtils.mkdir_p(@output_dir)
    clean
    validate
    compile
    test
    package
    report("passed")
  rescue DependencyError, BuildFailure => error
    @phase_results << { "phase" => current_phase, "status" => "failed", "message" => error.message }
    remaining_phases.each { |phase| @phase_results << { "phase" => phase, "status" => "not-run" } }
    report("failed")
  end

  private

  def clean
    @current_phase = "clean"
    FileUtils.rm_f([compiled_path, artifact_path, report_path])
    pass("clean")
  end

  def validate
    @current_phase = "validate"
    raise BuildFailure, "FACTORYCARE_BUILD_PROFILE must be offline" unless @profile == "offline"

    @cache = PackageCache.new(@repository, @cache_dir)
    @records = @lock.fetch("packages").map { |entry| [entry, @cache.fetch(entry)] }
    pass("validate")
  end

  def compile
    @current_phase = "compile"
    source_bytes = File.read(@source)
    @compiled = {
      "format" => 1,
      "source_sha256" => Digest::SHA256.hexdigest(source_bytes),
      "dependencies" => @lock.fetch("packages").map { |entry| entry.slice("name", "version", "sha256") }
    }
    File.write(compiled_path, CanonicalJSON.dump(@compiled))
    pass("compile")
  end

  def test
    @current_phase = "test"
    source_bytes = File.read(@source)
    raise TestFailure, "injected test oracle rejected rounding rule" if @inject_test_failure
    raise TestFailure, "source rule oracle failed" unless source_bytes.include?("RULE=started-30-minute-blocks")

    pass("test")
  end

  def package
    @current_phase = "package"
    artifact = {
      "format" => 1,
      "profile" => @profile,
      "compiled_sha256" => CanonicalJSON.digest(@compiled),
      "dependency_payloads" => @records.map do |entry, record|
        { "name" => entry.fetch("name"), "version" => entry.fetch("version"), "payload" => record.fetch("payload") }
      end
    }
    File.write(artifact_path, CanonicalJSON.dump(artifact))
    pass("package")
  end

  def pass(phase)
    @phase_results << { "phase" => phase, "status" => "passed" }
  end

  def current_phase
    @current_phase || "validate"
  end

  def remaining_phases
    index = PHASES.index(current_phase) || 0
    PHASES.drop(index + 1)
  end

  def report(status)
    artifact_sha = File.file?(artifact_path) ? Digest::SHA256.file(artifact_path).hexdigest : nil
    value = {
      "format" => 1,
      "status" => status,
      "inputs" => {
        "source_sha256" => Digest::SHA256.file(@source).hexdigest,
        "lock_sha256" => CanonicalJSON.digest(@lock),
        "profile" => @profile
      },
      "cache_hits" => @cache ? @cache.hits : [],
      "phases" => @phase_results,
      "artifact_sha256" => artifact_sha
    }
    File.write(report_path, CanonicalJSON.dump(value))
    value
  end

  def compiled_path
    File.join(@output_dir, "compiled.json")
  end

  def artifact_path
    File.join(@output_dir, "factorycare-package.json")
  end

  def report_path
    File.join(@output_dir, "build-report.json")
  end
end

module ToolResolution
  module_function

  def find(name, path_value)
    path_value.split(File::PATH_SEPARATOR).each do |directory|
      candidate = File.join(directory, name)
      return candidate if File.file?(candidate) && File.executable?(candidate)
    end
    nil
  end
end
