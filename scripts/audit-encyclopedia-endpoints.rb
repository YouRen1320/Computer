#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "optparse"
require "pathname"
require "psych"
require "securerandom"
require "tmpdir"
require "tempfile"
require "thread"
require "timeout"
require "time"

module EncyclopediaEndpointAudit
  ROLE_ROOTS = {
    "example" => "examples",
    "exercise" => "exercises",
    "lab" => "labs",
    "private-solution" => "solutions-private"
  }.freeze
  GREEN_ROLES = %w[example lab private-solution].freeze
  EXPECTED_CHAPTERS = 255

  class AuditError < StandardError; end

  Endpoint = Struct.new(:chapter_id, :role, :relative_path, :absolute_path, keyword_init: true)

  class Inventory
    attr_reader :root

    def initialize(root)
      @root = File.realpath(root)
    end

    def chapter_ids
      bytes = File.binread(File.join(root, "curriculum/catalog.yml"))
      catalog = Psych.safe_load(bytes.force_encoding(Encoding::UTF_8))
      chapters = catalog.fetch("chapters")
      ids = chapters.map { |chapter| chapter.fetch("id") }
      unless ids.length == EXPECTED_CHAPTERS && ids.uniq.length == ids.length
        raise AuditError, "catalog must contain exactly #{EXPECTED_CHAPTERS} unique chapters"
      end
      ids.sort
    rescue KeyError, Psych::Exception => e
      raise AuditError, "catalog cannot be read: #{e.message.lines.first.to_s.strip}"
    end

    def endpoints
      ids = chapter_ids
      records = []
      ROLE_ROOTS.each do |role, directory|
        ids.each do |chapter_id|
          chapter_root = File.join(root, directory, "encyclopedia", chapter_id)
          verify = discover_one_verify(chapter_root, directory, chapter_id)
          relative = Pathname.new(verify).relative_path_from(Pathname.new(root)).to_s
          records << Endpoint.new(
            chapter_id: chapter_id,
            role: role,
            relative_path: relative,
            absolute_path: verify
          )
        end
      end
      records.sort_by { |endpoint| [endpoint.chapter_id, endpoint.role] }
    end

    private

    def discover_one_verify(chapter_root, directory, chapter_id)
      stat = File.lstat(chapter_root)
      if stat.symlink? || !stat.directory?
        raise AuditError, "#{directory}/encyclopedia/#{chapter_id} must be a real directory"
      end
      matches = Dir.glob(File.join(chapter_root, "**", "verify.sh")).sort
      unless matches.length == 1
        raise AuditError, "#{directory}/encyclopedia/#{chapter_id} must contain exactly one verify.sh"
      end
      verify = matches.first
      symlink = Dir.glob(File.join(chapter_root, "**", "*"), File::FNM_DOTMATCH).find do |path|
        ![".", ".."].include?(File.basename(path)) && File.lstat(path).symlink?
      end
      if symlink
        relative = symlink.delete_prefix(root + File::SEPARATOR)
        raise AuditError, "symbolic links are forbidden in endpoint roots: #{relative}"
      end
      verify_stat = File.lstat(verify)
      unless verify_stat.file? && !verify_stat.symlink? && verify_stat.executable?
        raise AuditError, "#{verify.delete_prefix(root + File::SEPARATOR)} must be an executable regular file"
      end
      verify
    rescue Errno::ENOENT
      raise AuditError, "missing asset root #{directory}/encyclopedia/#{chapter_id}"
    end
  end

  class ProcessRunner
    def initialize(timeout_seconds:, environment: {})
      @timeout_seconds = timeout_seconds
      @environment = environment
    end

    def call(endpoint)
      staged_root = nil
      execution_directory = File.dirname(endpoint.absolute_path)
      executable = endpoint.absolute_path
      if endpoint.role == "exercise"
        staged_root = Dir.mktmpdir("factorycare-exercise-repeat-")
        FileUtils.cp_r(File.join(execution_directory, "."), staged_root, preserve: true)
        execution_directory = staged_root
        executable = File.join(staged_root, File.basename(endpoint.absolute_path))
      end
      stdout_file = Tempfile.new("factorycare-endpoint-stdout")
      stderr_file = Tempfile.new("factorycare-endpoint-stderr")
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      pid = Process.spawn(
        @environment,
        executable,
        chdir: execution_directory,
        out: stdout_file,
        err: stderr_file,
        pgroup: true
      )
      status = wait(pid)
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      stdout_file.rewind
      stderr_file.rewind
      {
        "exit_code" => status ? status.exitstatus : nil,
        "timed_out" => status.nil?,
        "duration_ms" => (duration * 1000).round,
        "stdout" => stdout_file.read.b,
        "stderr" => stderr_file.read.b,
        "normalization_roots" => [execution_directory, File.dirname(endpoint.absolute_path)].uniq
      }
    ensure
      stdout_file.close! if stdout_file
      stderr_file.close! if stderr_file
      FileUtils.rm_rf(staged_root) if staged_root && File.directory?(staged_root) && !File.symlink?(staged_root)
    end

    private

    def wait(pid)
      Timeout.timeout(@timeout_seconds) do
        _waited, status = Process.wait2(pid)
        return status
      end
    rescue Timeout::Error
      terminate_group(pid)
      nil
    end

    def terminate_group(pid)
      Process.kill("TERM", -pid)
      begin
        Timeout.timeout(2) { Process.wait(pid) }
      rescue Timeout::Error
        Process.kill("KILL", -pid)
        Process.wait(pid)
      rescue Errno::ECHILD, Errno::ESRCH
        nil
      end
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
  end

  class Auditor
    attr_reader :root, :jobs, :timeout_seconds, :runner

    def initialize(root:, jobs:, timeout_seconds:, runner: nil, environment: nil)
      @root = File.realpath(root)
      @jobs = jobs
      @timeout_seconds = timeout_seconds
      @runner = runner || ProcessRunner.new(
        timeout_seconds: timeout_seconds,
        environment: environment || self.class.fixed_environment
      )
    end

    def run
      inventory = Inventory.new(root)
      endpoints = inventory.endpoints
      expected_total = EXPECTED_CHAPTERS * ROLE_ROOTS.length
      raise AuditError, "expected #{expected_total} endpoints, found #{endpoints.length}" unless endpoints.length == expected_total

      queue = Queue.new
      endpoints.each { |endpoint| queue << endpoint }
      results = []
      mutex = Mutex.new
      workers = Array.new([jobs, endpoints.length].min) do
        Thread.new do
          loop do
            endpoint = queue.pop(true)
            record = audit(endpoint)
            mutex.synchronize { results << record }
          rescue ThreadError
            break
          rescue StandardError => e
            mutex.synchronize do
              results << failure_record(endpoint, "runner raised #{e.class}: #{e.message.lines.first.to_s.strip}")
            end
          end
        end
      end
      workers.each(&:join)
      build_report(results.sort_by { |record| [record.fetch("chapter_id"), record.fetch("role")] })
    end

    def self.fixed_environment
      home = Dir.home
      java_home = ENV.fetch("FACTORYCARE_JAVA_HOME", "/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home")
      node_bin = newest_node_24_bin(home)
      path_prefixes = [
        ENV["FACTORYCARE_AUDIT_TOOL_BIN"],
        File.join(java_home, "bin"), node_bin,
        File.join(home, "Library/pnpm"), File.join(home, ".local/bin")
      ].compact
      environment = {
        "CI" => "true",
        "JAVA_HOME" => java_home,
        "LANG" => "C.UTF-8",
        "LC_ALL" => "C.UTF-8",
        "PATH" => (path_prefixes + ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)).uniq.join(File::PATH_SEPARATOR),
        "PYTHONDONTWRITEBYTECODE" => "1",
        "TZ" => "UTC"
      }
      if ENV["FACTORYCARE_PNPM_STORE_DIR"]
        environment["npm_config_store_dir"] = File.expand_path(ENV.fetch("FACTORYCARE_PNPM_STORE_DIR"))
      end
      environment
    end

    def self.newest_node_24_bin(home)
      candidates = Dir.glob(File.join(home, ".nvm/versions/node/v24.*/bin"))
      candidates.max_by do |path|
        File.basename(File.dirname(path)).delete_prefix("v").split(".").map(&:to_i)
      end
    end

    private

    def audit(endpoint)
      first = runner.call(endpoint)
      failures = contract_failures(endpoint, first)
      repeat = nil
      if endpoint.role == "exercise" && failures.empty?
        repeat = runner.call(endpoint)
        failures.concat(contract_failures(endpoint, repeat))
        unless comparable(first) == comparable(repeat)
          failures << "expected-red repeat changed exit code or normalized diagnostic lines"
        end
      end
      summarized(endpoint, first, repeat, failures)
    end

    def contract_failures(endpoint, result)
      failures = []
      failures << "timed out after #{timeout_seconds}s" if result.fetch("timed_out")
      if endpoint.role == "exercise"
        unless result.fetch("exit_code").is_a?(Integer) && result.fetch("exit_code") != 0
          failures << "expected a stable nonzero exit, got #{result.fetch('exit_code').inspect}"
        end
      elsif !result.fetch("timed_out") && result.fetch("exit_code") != 0
        failures << "expected exit 0, got #{result.fetch('exit_code').inspect}"
      end
      failures
    end

    def comparable(result)
      [
        result.fetch("exit_code"),
        normalized_diagnostic(result.fetch("stdout"), result).lines.sort,
        normalized_diagnostic(result.fetch("stderr"), result).lines.sort
      ]
    end

    def normalized_diagnostic(bytes, result)
      text = bytes.dup.force_encoding(Encoding::UTF_8).scrub
      roots = result.fetch("normalization_roots", []).flat_map do |path|
        expanded = File.expand_path(path)
        real = File.realpath(path) rescue expanded
        [expanded, real]
      end.uniq.sort_by { |path| -path.length }
      roots.each { |path| text.gsub!(path, "$ASSET_ROOT") }
      text.gsub!(%r{file://(?:/private)?/var/folders/[^\s:]+/T/[^/\s:]+}, "file://$TMP")
      text.gsub!(%r{(?:/private)?/var/folders/[^\s:]+/T/[^/\s:]+}, "$TMP")
      text.gsub!(%r{(?:/private)?/tmp/[A-Za-z0-9._-]+}, "$TMP")
      # Dart prints only the temporary project basename in its analyzer banner,
      # so the full-path substitutions above cannot make clean-copy runs equal.
      # Keep this deliberately scoped to that banner instead of hiding arbitrary
      # filenames elsewhere in a diagnostic.
      text.gsub!(
        /^Analyzing (?:factorycare-exercise-repeat-[^\r\n]+|tmp\.[A-Za-z0-9]+)\.\.\.$/,
        "Analyzing <TEMP_PROJECT>..."
      )
      text.gsub!(/0x[0-9a-f]+/i, "0x<ADDRESS>")
      text.lines.map do |line|
        if line.match?(/^Formatted \d+ files? \(\d+ changed\) in \d+(?:\.\d+)? seconds\.$/)
          line = line.gsub(/\bin \d+(?:\.\d+)? seconds\./, "in <DURATION> seconds.")
        end
        if line.match?(/(?:\bDuration\b|\bStart at\b|\bRan \d+ tests? in\b|\bfailed in\b|\bpassed in\b)/i)
          line = line.gsub(/\b\d{1,2}:\d{2}:\d{2}\b/, "<CLOCK>")
          line = line.gsub(/\b\d+(?:\.\d+)?(?:ms|s)\b/, "<DURATION>")
        end
        line
      end.join
    end

    def summarized(endpoint, first, repeat, failures)
      {
        "chapter_id" => endpoint.chapter_id,
        "role" => endpoint.role,
        "verify_path" => endpoint.relative_path,
        "status" => failures.empty? ? "passed" : "failed",
        "expected_exit_code" => endpoint.role == "exercise" ? "nonzero" : 0,
        "expected_red_marker_observed" => endpoint.role == "exercise" &&
          (first.fetch("stdout") + first.fetch("stderr")).include?("EXPECTED_RED".b),
        "first_run" => result_summary(first),
        "repeat_run" => repeat && result_summary(repeat),
        "failures" => failures,
        "diagnostic_excerpt" => failures.empty? ? nil : diagnostic_excerpt(first)
      }
    end

    def failure_record(endpoint, message)
      {
        "chapter_id" => endpoint ? endpoint.chapter_id : "unknown",
        "role" => endpoint ? endpoint.role : "unknown",
        "verify_path" => endpoint ? endpoint.relative_path : "unknown",
        "status" => "failed",
        "expected_exit_code" => endpoint && endpoint.role == "exercise" ? "nonzero" : 0,
        "expected_red_marker_observed" => false,
        "first_run" => nil,
        "repeat_run" => nil,
        "failures" => [message],
        "diagnostic_excerpt" => nil
      }
    end

    def result_summary(result)
      normalized_stdout = normalized_diagnostic(result.fetch("stdout"), result)
      normalized_stderr = normalized_diagnostic(result.fetch("stderr"), result)
      {
        "exit_code" => result.fetch("exit_code"),
        "timed_out" => result.fetch("timed_out"),
        "duration_ms" => result.fetch("duration_ms"),
        "stdout_bytes" => result.fetch("stdout").bytesize,
        "stdout_sha256" => Digest::SHA256.hexdigest(result.fetch("stdout")),
        "stderr_bytes" => result.fetch("stderr").bytesize,
        "stderr_sha256" => Digest::SHA256.hexdigest(result.fetch("stderr")),
        "normalized_stdout_sha256" => Digest::SHA256.hexdigest(normalized_stdout.lines.sort.join),
        "normalized_stderr_sha256" => Digest::SHA256.hexdigest(normalized_stderr.lines.sort.join)
      }
    end

    def diagnostic_excerpt(result)
      combined = result.fetch("stdout") + result.fetch("stderr")
      combined.force_encoding(Encoding::UTF_8).scrub.lines.first(12).join.byteslice(0, 2000)
    end

    def build_report(results)
      failed = results.reject { |record| record.fetch("status") == "passed" }
      role_counts = ROLE_ROOTS.keys.sort.each_with_object({}) do |role, counts|
        selected = results.select { |record| record.fetch("role") == role }
        counts[role] = {
          "total" => selected.length,
          "passed" => selected.count { |record| record.fetch("status") == "passed" },
          "failed" => selected.count { |record| record.fetch("status") == "failed" }
        }
      end
      {
        "schema_version" => 1,
        "audit_id" => "p9-encyclopedia-endpoints",
        "generated_by" => "scripts/audit-encyclopedia-endpoints.rb",
        "generated_at" => Time.now.utc.iso8601,
        "chapter_count" => EXPECTED_CHAPTERS,
        "endpoint_count" => results.length,
        "expected_red_repeat_policy" => "clean-copy runs; same nonzero exit and same normalized diagnostic line multiset",
        "diagnostic_normalization" => [
          "replace execution and system temporary roots",
          "replace Dart analyzer banners derived from temporary project names",
          "replace duration only in Dart formatter summary lines",
          "replace process-specific hexadecimal object addresses",
          "replace clock and duration fields only on test-summary lines",
          "compare the resulting diagnostic line multiset"
        ],
        "passed_count" => results.length - failed.length,
        "failed_count" => failed.length,
        "role_counts" => role_counts,
        "status" => failed.empty? ? "passed" : "failed",
        "results" => results
      }
    end
  end

  module CLI
    module_function

    def run(argv, stdout: $stdout, stderr: $stderr)
      options = {
        root: File.expand_path("..", __dir__),
        jobs: Integer(ENV.fetch("FACTORYCARE_AUDIT_JOBS", "6")),
        timeout_seconds: Integer(ENV.fetch("FACTORYCARE_AUDIT_TIMEOUT", "300")),
        output: nil
      }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: ruby scripts/audit-encyclopedia-endpoints.rb [options]"
        opts.on("--root PATH", "Repository copy to audit") { |value| options[:root] = value }
        opts.on("--jobs N", Integer, "Parallel workers") { |value| options[:jobs] = value }
        opts.on("--timeout SECONDS", Integer, "Per-run timeout") { |value| options[:timeout_seconds] = value }
        opts.on("--output PATH", "Write canonical JSON report") { |value| options[:output] = value }
      end
      parser.parse!(argv)
      raise AuditError, "unexpected positional arguments" unless argv.empty?
      raise AuditError, "jobs must be positive" unless options.fetch(:jobs).positive?
      raise AuditError, "timeout must be positive" unless options.fetch(:timeout_seconds).positive?

      report = Auditor.new(
        root: options.fetch(:root),
        jobs: options.fetch(:jobs),
        timeout_seconds: options.fetch(:timeout_seconds)
      ).run
      bytes = JSON.generate(report) + "\n"
      if options[:output]
        write_atomic(options.fetch(:output), bytes)
        stdout.puts "ENDPOINT AUDIT #{report.fetch('status').upcase}: #{report.fetch('passed_count')}/#{report.fetch('endpoint_count')} passed"
        stdout.puts "report=#{File.expand_path(options.fetch(:output))}"
      else
        stdout.write(bytes)
      end
      report.fetch("status") == "passed" ? 0 : 1
    rescue OptionParser::ParseError, AuditError, Errno::ENOENT => e
      stderr.puts "ENDPOINT AUDIT FAILED: #{e.message.lines.first.to_s.strip}"
      2
    end

    def write_atomic(path, bytes)
      absolute = File.expand_path(path)
      FileUtils.mkdir_p(File.dirname(absolute))
      temporary = "#{absolute}.tmp-#{$$}-#{SecureRandom.hex(6)}"
      File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o644) do |file|
        file.binmode
        file.write(bytes)
        file.flush
        file.fsync
      end
      File.rename(temporary, absolute)
    ensure
      FileUtils.rm_f(temporary) if defined?(temporary) && temporary
    end
  end
end

if $PROGRAM_NAME == __FILE__
  exit EncyclopediaEndpointAudit::CLI.run(ARGV)
end
