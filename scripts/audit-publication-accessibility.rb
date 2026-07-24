#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "pathname"
require "securerandom"
require "set"
require "tmpdir"
require "timeout"

require File.expand_path("validate-encyclopedia", __dir__)

module PublicationAccessibilityAudit
  class AuditError < StandardError; end

  PLAN_PATH = "build/publication/internal-complete/publication-plan-v2.json"
  OUTPUT_MANIFEST_PATH = "build/publication/internal-complete/publication-output-manifest-v2.json"
  OUTPUT_ROOT = "build/publication/internal-complete"
  TOOLCHAIN_PATH = "publication/accessibility-toolchain.yml"
  TOOLCHAIN_SCHEMA_PATH = "schemas/publication-accessibility-toolchain.schema.json"
  REPORT_SCHEMA_PATH = "schemas/publication-accessibility-audit.schema.json"
  PROFILE_ID = "internal-complete"
  PLAN_ID = "publication-plan.internal-complete"
  MANIFEST_ID = "publication-output.internal-complete"
  EXPECTED_ARTIFACT_COUNTS = { "html" => 273, "epub" => 17, "pdf" => 17 }.freeze
  EXPECTED_CHECK_COUNTS = { "axe-core" => 273, "epubcheck" => 17, "ace" => 17, "verapdf" => 17 }.freeze
  AXE_RULE_TAGS = %w[wcag2a wcag2aa wcag21a wcag21aa wcag22a wcag22aa].freeze
  DEFAULT_TIMEOUT_SECONDS = 600
  EXPECTED_KIND_COUNTS = {
    "html-index" => 1,
    "whole-html" => 1,
    "volume-html" => 16,
    "chapter-html" => 255,
    "whole-epub" => 1,
    "volume-epub" => 16,
    "whole-pdf-candidate" => 1,
    "volume-pdf-candidate" => 16
  }.freeze
  FORMAT_MEDIA_TYPES = {
    "html" => "text/html; charset=utf-8",
    "epub" => "application/epub+zip",
    "pdf" => "application/pdf"
  }.freeze
  FORMAT_ENGINES = {
    "html" => ["axe-core"],
    "epub" => %w[epubcheck ace],
    "pdf" => ["verapdf"]
  }.freeze
  EXPECTED_TOOLS = {
    "axe-core" => ["audit-engine", "env-directory", "FACTORYCARE_ACCESSIBILITY_NODE_BIN", "axe", "axe-cli-json-v1", ["html"], 1],
    "epubcheck" => ["audit-engine", "path", "PATH", "epubcheck", "epubcheck-json-v5", ["epub"], 1],
    "ace" => ["audit-engine", "env-directory", "FACTORYCARE_ACCESSIBILITY_NODE_BIN", "ace", "ace-report-json-v1", ["epub"], 1],
    "verapdf" => ["audit-engine", "path", "PATH", "verapdf", "verapdf-json-v1", ["pdf"], 1],
    "chrome" => ["runtime-dependency", "env-file", "FACTORYCARE_CHROME_EXECUTABLE", "chrome", "not-applicable", [], 0],
    "chromedriver" => ["runtime-dependency", "env-file", "FACTORYCARE_CHROMEDRIVER", "chromedriver", "not-applicable", [], 0]
  }.freeze
  MAX_TOOL_OUTPUT_BYTES = 256 * 1024 * 1024

  Artifact = Struct.new(:document, :identity_sha256, keyword_init: true)
  CheckTask = Struct.new(:check_id, :engine_id, :artifact, keyword_init: true)
  Invocation = Struct.new(:exit_code, :payload, keyword_init: true)
  ObservedTool = Struct.new(
    :id, :role, :version, :version_output_sha256, :entrypoint_sha256,
    :identity_sha256, :resolved_path, keyword_init: true
  ) do
    def report_projection
      {
        "id" => id,
        "role" => role,
        "version" => version,
        "version_output_sha256" => version_output_sha256,
        "entrypoint_sha256" => entrypoint_sha256,
        "identity_sha256" => identity_sha256
      }
    end
  end

  module Canonical
    module_function

    def object(value)
      case value
      when Hash
        value.keys.sort.each_with_object({}) { |key, result| result[key] = object(value.fetch(key)) }
      when Array
        value.map { |item| object(item) }
      else
        value
      end
    end

    def json(value)
      JSON.pretty_generate(object(value)) + "\n"
    end

    def compact_json(value)
      JSON.generate(object(value))
    end

    def sha256(value)
      Digest::SHA256.hexdigest(value)
    end

    def identity_set(entries, id_key, digest_key)
      digest = Digest::SHA256.new
      entries.sort_by { |entry| entry.fetch(id_key) }.each do |entry|
        digest << entry.fetch(id_key) << "\0" << entry.fetch(digest_key) << "\0"
      end
      digest.hexdigest
    end
  end

  # Publication evidence must not silently accept symlinks, path traversal, or
  # bytes that drift from the output manifest while the external tools run.
  class RepositoryReader
    SAFE_PATH = /\A[a-zA-Z0-9][a-zA-Z0-9._-]*(?:\/[a-zA-Z0-9_][a-zA-Z0-9._-]*)*\z/.freeze

    attr_reader :root

    def initialize(root)
      @root = File.realpath(root)
      @snapshots = {}
      @identities = {}
    end

    def read(relative, snapshot: true)
      bytes, = open_and_read(relative)
      @snapshots[relative] = bytes if snapshot
      bytes
    end

    def bind_identity(relative, sha256:, size_bytes:)
      actual_sha256, actual_size = digest_file(relative)
      unless actual_sha256 == sha256 && actual_size == size_bytes
        raise AuditError, "#{relative}: bytes drift from the P8 output manifest"
      end
      @identities[relative] = [sha256, size_bytes]
      true
    end

    def read_bound(relative, sha256:, size_bytes:)
      bytes = read(relative, snapshot: false)
      unless bytes.bytesize == size_bytes && Canonical.sha256(bytes) == sha256
        raise AuditError, "#{relative}: bytes drift from the P8 output manifest"
      end
      bytes
    end

    def verify_unchanged!
      @snapshots.each do |relative, expected|
        actual = read(relative, snapshot: false)
        raise AuditError, "#{relative}: bound contract drifted during audit" unless actual == expected
      end
      @identities.each do |relative, expected|
        actual = digest_file(relative)
        raise AuditError, "#{relative}: bound artifact drifted during audit" unless actual == expected
      end
      true
    end

    private

    def digest_file(relative)
      absolute, stat = guarded_path(relative)
      digest = Digest::SHA256.new
      size = 0
      flags = File::RDONLY
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      File.open(absolute, flags) do |file|
        opened = file.stat
        validate_descriptor!(relative, stat, opened)
        file.binmode
        while (chunk = file.read(1024 * 1024))
          digest << chunk
          size += chunk.bytesize
        end
      end
      [digest.hexdigest, size]
    rescue Errno::ENOENT
      raise AuditError, "#{relative}: required file is missing"
    rescue Errno::ELOOP
      raise AuditError, "#{relative}: symbolic-link path is forbidden"
    end

    def open_and_read(relative)
      absolute, stat = guarded_path(relative)
      flags = File::RDONLY
      flags |= File::NOFOLLOW if File.const_defined?(:NOFOLLOW)
      bytes = File.open(absolute, flags) do |file|
        validate_descriptor!(relative, stat, file.stat)
        file.binmode
        file.read
      end
      [bytes, stat]
    rescue Errno::ENOENT
      raise AuditError, "#{relative}: required file is missing"
    rescue Errno::ELOOP
      raise AuditError, "#{relative}: symbolic-link path is forbidden"
    end

    def guarded_path(relative)
      validate_relative!(relative)
      cursor = root
      relative.split("/").each do |part|
        cursor = File.join(cursor, part)
        break unless File.exist?(cursor) || File.symlink?(cursor)

        raise AuditError, "#{relative}: symbolic-link path is forbidden" if File.lstat(cursor).symlink?
      end
      absolute = File.expand_path(relative, root)
      unless absolute.start_with?(root + File::SEPARATOR)
        raise AuditError, "#{relative}: path escapes repository root"
      end
      stat = File.lstat(absolute)
      raise AuditError, "#{relative}: symbolic links are forbidden" if stat.symlink?
      raise AuditError, "#{relative}: expected a regular file" unless stat.file?

      [absolute, stat]
    end

    def validate_relative!(relative)
      unless relative.is_a?(String) && SAFE_PATH.match?(relative) &&
             !Pathname(relative).absolute? && !relative.include?("\\") &&
             relative.split("/", -1).none? { |part| part.empty? || part == "." || part == ".." }
        raise AuditError, "publication input path must be a safe repository-relative path"
      end
    end

    def validate_descriptor!(relative, expected, opened)
      return if opened.file? && opened.dev == expected.dev && opened.ino == expected.ino

      raise AuditError, "#{relative}: file changed while opening"
    end
  end

  module ContractDocuments
    module_function

    def strict_json(bytes, label)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      raise AuditError, "#{label}: invalid UTF-8" unless text.valid_encoding?

      StrictJson.parse(text)
    rescue JSON::ParserError, StrictJson::DuplicateMemberError => e
      raise AuditError, "#{label}: invalid strict JSON (#{e.class.name.split('::').last})"
    end

    def strict_yaml(bytes, label)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      raise AuditError, "#{label}: invalid UTF-8" unless text.valid_encoding?

      value = StrictYaml.safe_load(text, label: label)
      raise AuditError, "#{label}: root must be an object" unless value.is_a?(Hash)

      value
    rescue Psych::Exception, StrictYaml::DuplicateKeyError, StrictYaml::UnsupportedKeyError => e
      raise AuditError, "#{label}: invalid strict YAML (#{e.class.name.split('::').last})"
    end

    def validate_schema!(instance, schema_bytes, schema_path, instance_path)
      schema = strict_json(schema_bytes, schema_path)
      evaluator = ExecutableJsonSchema.new(schema, schema_path)
      unless evaluator.definition_errors.empty?
        raise AuditError, "#{schema_path}: invalid schema definition: #{evaluator.definition_errors.first}"
      end
      errors = evaluator.validate(instance)
      raise AuditError, "#{instance_path}: schema validation failed: #{errors.first}" unless errors.empty?

      true
    end
  end

  # Selects only end-user delivery artifacts from the complete P8 manifest.
  # AST, indexes used only as data, and print-intermediate HTML remain outside
  # the accessibility tool matrix and are reported as 37 unselected outputs.
  class BoundPublication
    attr_reader :reader, :plan, :manifest, :plan_bytes, :manifest_bytes, :artifacts

    def initialize(reader)
      @reader = reader
    end

    def load!
      @plan_bytes = reader.read(PLAN_PATH)
      @manifest_bytes = reader.read(OUTPUT_MANIFEST_PATH)
      @plan = ContractDocuments.strict_json(plan_bytes, PLAN_PATH)
      @manifest = ContractDocuments.strict_json(manifest_bytes, OUTPUT_MANIFEST_PATH)
      validate_headers!
      validate_output_sets!
      validate_artifact_files!
      self
    rescue KeyError, TypeError => e
      raise AuditError, "P8 publication binding has an invalid shape (#{e.class})"
    end

    def binding_document
      reports = artifact_reports
      {
        "plan_path" => PLAN_PATH,
        "plan_sha256" => Canonical.sha256(plan_bytes),
        "output_manifest_path" => OUTPUT_MANIFEST_PATH,
        "output_manifest_sha256" => Canonical.sha256(manifest_bytes),
        "manifest_plan_sha256" => manifest.fetch("plan_sha256"),
        "artifact_count" => reports.length,
        "artifact_set_sha256" => Canonical.identity_set(reports, "path", "identity_sha256")
      }
    end

    def artifact_reports
      artifacts.map(&:document)
    end

    def unselected_manifest_output_count
      manifest.fetch("outputs").length - artifacts.length
    end

    private

    def validate_headers!
      require_value!(plan, "schema_version", 2, "plan")
      require_value!(plan, "plan_id", PLAN_ID, "plan")
      require_value!(plan, "profile_id", PROFILE_ID, "plan")
      require_value!(plan, "output_root", OUTPUT_ROOT, "plan")
      require_value!(manifest, "schema_version", 2, "output manifest")
      require_value!(manifest, "manifest_id", MANIFEST_ID, "output manifest")
      require_value!(manifest, "plan_id", PLAN_ID, "output manifest")
      require_value!(manifest, "profile_id", PROFILE_ID, "output manifest")
      require_value!(manifest, "build_status", "succeeded", "output manifest")
      unless manifest.fetch("plan_sha256") == Canonical.sha256(plan_bytes)
        raise AuditError, "P8 output manifest plan_sha256 does not match current plan bytes"
      end
    end

    def validate_output_sets!
      planned = require_array!(plan, "planned_outputs", "plan")
      emitted = require_array!(manifest, "outputs", "output manifest")
      validate_unique_paths!(planned, "plan")
      validate_unique_paths!(emitted, "output manifest")
      unless planned.length == 345 && emitted.length == 344 && manifest.fetch("output_count") == emitted.length
        raise AuditError, "P8 plan/output manifest must contain exactly 345 planned paths and 344 non-self outputs"
      end

      planned_manifests = planned.select { |entry| entry.fetch("kind") == "output-manifest" }
      unless planned_manifests.length == 1 && planned_manifests.first.fetch("path") == "publication-output-manifest-v2.json"
        raise AuditError, "P8 plan must contain exactly one non-self-summarized output manifest"
      end
      full_planned_projection = planned.reject { |entry| entry.fetch("kind") == "output-manifest" }.map { |entry| projection(entry) }
      full_emitted_projection = emitted.map { |entry| projection(entry) }
      unless full_planned_projection == full_emitted_projection
        raise AuditError, "P8 output manifest does not exactly project the current 345-path plan"
      end

      planned_selected = planned.select { |entry| EXPECTED_ARTIFACT_COUNTS.key?(entry.fetch("format")) }
      emitted_selected = emitted.select { |entry| EXPECTED_ARTIFACT_COUNTS.key?(entry.fetch("format")) }
      validate_distribution!(planned_selected, emitted_selected)

      planned_projection = planned_selected.map { |entry| projection(entry) }
      emitted_projection = emitted_selected.map { |entry| projection(entry) }
      unless planned_projection == emitted_projection
        raise AuditError, "P8 accessibility artifact set differs between plan and output manifest"
      end

      @artifacts = emitted_selected.map do |entry|
        validate_entry!(entry)
        report = entry.select { |key, _value| %w[path kind format media_type distribution sha256 size_bytes].include?(key) }
        report["identity_sha256"] = Canonical.sha256(Canonical.compact_json(report))
        Artifact.new(document: report, identity_sha256: report.fetch("identity_sha256"))
      end
    end

    def validate_distribution!(planned, emitted)
      [planned, emitted].each_with_index do |entries, index|
        label = index.zero? ? "plan" : "output manifest"
        by_format = entries.group_by { |entry| entry.fetch("format") }.transform_values(&:length)
        by_kind = entries.group_by { |entry| entry.fetch("kind") }.transform_values(&:length)
        unless by_format == EXPECTED_ARTIFACT_COUNTS
          raise AuditError, "P8 #{label} must select exactly 273 HTML, 17 EPUB and 17 PDF artifacts"
        end
        unless by_kind == EXPECTED_KIND_COUNTS
          raise AuditError, "P8 #{label} accessibility artifact kinds drifted from the fixed 307-artifact contract"
        end
      end
    end

    def validate_entry!(entry)
      format = entry.fetch("format")
      unless entry.fetch("media_type") == FORMAT_MEDIA_TYPES.fetch(format) &&
             entry.fetch("distribution") == "internal-review-candidate" &&
             entry.fetch("sha256").is_a?(String) && entry.fetch("sha256").match?(/\A[0-9a-f]{64}\z/) &&
             entry.fetch("size_bytes").is_a?(Integer) && entry.fetch("size_bytes").positive?
        raise AuditError, "#{entry.fetch('path')}: output manifest artifact metadata is invalid"
      end
    end

    def validate_artifact_files!
      artifacts.each do |artifact|
        entry = artifact.document
        reader.bind_identity(
          File.join(OUTPUT_ROOT, entry.fetch("path")),
          sha256: entry.fetch("sha256"),
          size_bytes: entry.fetch("size_bytes")
        )
      end
    end

    def require_value!(document, key, expected, label)
      return if document.fetch(key) == expected

      raise AuditError, "P8 #{label} #{key} is unsupported"
    end

    def require_array!(document, key, label)
      value = document.fetch(key)
      raise AuditError, "P8 #{label} #{key} must be an array" unless value.is_a?(Array)

      value
    end

    def validate_unique_paths!(entries, label)
      unless entries.all? { |entry| entry.is_a?(Hash) && entry["path"].is_a?(String) }
        raise AuditError, "P8 #{label} output entries must be objects with paths"
      end
      paths = entries.map { |entry| entry.fetch("path") }
      raise AuditError, "P8 #{label} output paths contain duplicates" unless paths.uniq.length == paths.length
    end

    def projection(entry)
      entry.select { |key, _value| %w[path kind format distribution].include?(key) }
    end
  end

  class Toolchain
    attr_reader :reader, :path, :bytes, :document

    def initialize(reader, path: TOOLCHAIN_PATH)
      @reader = reader
      @path = path
    end

    def load!
      @bytes = reader.read(path)
      @document = ContractDocuments.strict_yaml(bytes, path)
      schema_bytes = reader.read(TOOLCHAIN_SCHEMA_PATH)
      ContractDocuments.validate_schema!(document, schema_bytes, TOOLCHAIN_SCHEMA_PATH, path)
      validate_semantics!
      self
    end

    def tools
      document.fetch("tools")
    end

    def contract
      document.fetch("contract")
    end

    private

    def validate_semantics!
      unless document.fetch("evidence_classification") == "machine-only-not-certification" &&
             document.fetch("promotion_policy") == "forbidden-without-human-review" &&
             document.fetch("network_policy") == "forbidden-by-contract-not-os-enforced"
        raise AuditError, "P9 toolchain claim boundary is unsupported"
      end
      unless contract.fetch("artifact_count") == EXPECTED_ARTIFACT_COUNTS.values.sum &&
             contract.fetch("artifacts_by_format") == EXPECTED_ARTIFACT_COUNTS &&
             contract.fetch("check_count") == EXPECTED_CHECK_COUNTS.values.sum &&
             contract.fetch("checks_by_engine") == EXPECTED_CHECK_COUNTS &&
             contract.fetch("axe_rule_tags") == AXE_RULE_TAGS &&
             contract.fetch("default_timeout_seconds") == DEFAULT_TIMEOUT_SECONDS &&
             contract.fetch("transient_tool_output_limit_bytes") == MAX_TOOL_OUTPUT_BYTES
        raise AuditError, "P9 toolchain 307-artifact/324-check formula drifted"
      end

      by_id = tools.each_with_object({}) do |tool, result|
        id = tool.fetch("id")
        raise AuditError, "P9 toolchain contains duplicate tool #{id}" if result.key?(id)

        result[id] = tool
      end
      unless by_id.keys.sort == EXPECTED_TOOLS.keys.sort
        raise AuditError, "P9 toolchain must declare exactly four engines and two axe runtime dependencies"
      end
      EXPECTED_TOOLS.each do |id, expected|
        tool = by_id.fetch(id)
        actual = [
          tool.fetch("role"), tool.fetch("resolver"), tool.fetch("environment_variable"),
          tool.fetch("executable"), tool.fetch("parser"), tool.fetch("formats"),
          tool.fetch("checks_per_artifact")
        ]
        raise AuditError, "P9 toolchain semantics drifted for #{id}" unless actual == expected
      end
    rescue KeyError, TypeError => e
      raise AuditError, "P9 toolchain has an invalid shape (#{e.class})"
    end
  end

  class CommandExecutor
    def call(argv, environment:, timeout_seconds:)
      stdout = +""
      stderr = +""
      exit_code = nil
      Open3.popen3(environment, *argv, pgroup: true) do |stdin, out, err, wait_thread|
        stdin.close
        readers = [
          Thread.new { stdout << out.read },
          Thread.new { stderr << err.read }
        ]
        begin
          Timeout.timeout(timeout_seconds) do
            exit_code = wait_thread.value.exitstatus
            readers.each(&:join)
          end
        rescue Timeout::Error
          begin
            Process.kill("TERM", -wait_thread.pid)
            Process.kill("KILL", -wait_thread.pid)
          rescue Errno::ESRCH
            # The child may exit between the timeout and termination attempt.
          end
          readers.each do |thread|
            thread.join(1)
            thread.kill if thread.alive?
          end
          wait_thread.join(1)
          raise AuditError, "external accessibility tool timed out"
        end
      end
      if stdout.bytesize > MAX_TOOL_OUTPUT_BYTES || stderr.bytesize > MAX_TOOL_OUTPUT_BYTES
        raise AuditError, "external accessibility tool exceeded the bounded output limit"
      end
      [stdout, stderr, exit_code]
    rescue Errno::ENOENT
      raise AuditError, "external accessibility tool entrypoint disappeared"
    end
  end

  class ToolObserver
    attr_reader :executor, :environment, :timeout_seconds

    def initialize(executor: CommandExecutor.new, environment: ENV, timeout_seconds: 30)
      @executor = executor
      @environment = environment
      @timeout_seconds = timeout_seconds
    end

    def observe(toolchain)
      toolchain.tools.map { |tool| observe_tool(tool) }.sort_by(&:id)
    end

    def verify_unchanged!(toolchain, expected)
      actual = observe(toolchain)
      expected_projection = expected.map(&:report_projection).sort_by { |tool| tool.fetch("id") }
      actual_projection = actual.map(&:report_projection).sort_by { |tool| tool.fetch("id") }
      raise AuditError, "accessibility tool identities drifted during audit" unless actual_projection == expected_projection

      true
    end

    private

    def observe_tool(tool)
      resolved = resolve(tool)
      stdout, stderr, exit_code = executor.call(
        [resolved] + tool.fetch("version_arguments"),
        environment: stable_environment,
        timeout_seconds: timeout_seconds
      )
      raise AuditError, "#{tool.fetch('id')}: version probe failed" unless exit_code.zero?

      raw_version = stdout + stderr
      version = raw_version.lines.map(&:strip).find { |line| !line.empty? }.to_s
      unless version.start_with?(tool.fetch("expected_version_prefix"))
        raise AuditError, "#{tool.fetch('id')}: observed version drifted from accessibility-toolchain.yml"
      end
      version_output_sha256 = Canonical.sha256(raw_version)
      entrypoint_sha256 = Digest::SHA256.file(File.realpath(resolved)).hexdigest
      identity_sha256 = Canonical.sha256(
        [tool.fetch("id"), version, version_output_sha256, entrypoint_sha256].join("\0") + "\0"
      )
      ObservedTool.new(
        id: tool.fetch("id"), role: tool.fetch("role"), version: version,
        version_output_sha256: version_output_sha256,
        entrypoint_sha256: entrypoint_sha256,
        identity_sha256: identity_sha256,
        resolved_path: resolved
      )
    rescue Errno::ENOENT, Errno::EACCES
      raise AuditError, "#{tool.fetch('id')}: executable is unavailable"
    end

    def resolve(tool)
      case tool.fetch("resolver")
      when "path"
        executable = tool.fetch("executable")
        candidate = environment.fetch("PATH", "").split(File::PATH_SEPARATOR).map do |directory|
          File.join(directory, executable)
        end.find { |path| File.file?(path) && File.executable?(path) }
        raise AuditError, "#{tool.fetch('id')}: executable is not available on PATH" unless candidate

        candidate
      when "env-directory"
        directory = required_environment(tool)
        raise AuditError, "#{tool.fetch('id')}: environment directory must be absolute" unless Pathname(directory).absolute?

        candidate = File.join(directory, tool.fetch("executable"))
        raise AuditError, "#{tool.fetch('id')}: executable is unavailable" unless File.file?(candidate) && File.executable?(candidate)

        candidate
      when "env-file"
        candidate = required_environment(tool)
        raise AuditError, "#{tool.fetch('id')}: environment file must be absolute" unless Pathname(candidate).absolute?
        raise AuditError, "#{tool.fetch('id')}: executable is unavailable" unless File.file?(candidate) && File.executable?(candidate)

        candidate
      else
        raise AuditError, "#{tool.fetch('id')}: unsupported resolver"
      end
    end

    def required_environment(tool)
      key = tool.fetch("environment_variable")
      value = environment.fetch(key, "")
      raise AuditError, "#{tool.fetch('id')}: required environment variable #{key} is missing" if value.empty?

      value
    end

    def stable_environment
      {
        "LC_ALL" => "C.UTF-8",
        "LANG" => "C.UTF-8",
        "TZ" => "UTC",
        "HTTP_PROXY" => nil,
        "HTTPS_PROXY" => nil,
        "ALL_PROXY" => nil,
        "NO_PROXY" => "*"
      }
    end
  end

  class RealRunner
    attr_reader :tools, :executor, :timeout_seconds

    def initialize(observed_tools, executor: CommandExecutor.new, timeout_seconds: DEFAULT_TIMEOUT_SECONDS)
      @tools = observed_tools.each_with_object({}) { |tool, result| result[tool.id] = tool }
      @executor = executor
      @timeout_seconds = timeout_seconds
    end

    def call(engine_id:, artifact:, bytes:)
      Dir.mktmpdir("factorycare-accessibility-") do |directory|
        input = File.join(directory, "artifact.#{artifact.document.fetch('format')}")
        File.binwrite(input, bytes)
        case engine_id
        when "axe-core" then run_axe(input)
        when "epubcheck" then run_epubcheck(input, directory)
        when "ace" then run_ace(input, directory)
        when "verapdf" then run_verapdf(input)
        else raise AuditError, "unsupported accessibility engine #{engine_id}"
        end
      end
    end

    private

    def run_axe(input)
      argv = [
        path("axe-core"), "file://#{input}", "--stdout", "--exit",
        "--tags", AXE_RULE_TAGS.join(","),
        "--chromedriver-path", path("chromedriver"), "--chrome-path", path("chrome"),
        "--chrome-options", "headless,no-sandbox,disable-dev-shm-usage,disable-background-networking",
        "--timeout", timeout_seconds.to_s
      ]
      stdout, _stderr, exit_code = invoke(argv)
      Invocation.new(exit_code: exit_code, payload: stdout)
    end

    def run_epubcheck(input, directory)
      output = File.join(directory, "epubcheck.json")
      _stdout, _stderr, exit_code = invoke(
        [path("epubcheck"), input, "--json", output, "--failonwarnings", "--quiet"]
      )
      Invocation.new(exit_code: exit_code, payload: bounded_file(output, "EPUBCheck"))
    end

    def run_ace(input, directory)
      output = File.join(directory, "ace-report")
      _stdout, _stderr, exit_code = invoke(
        [path("ace"), "--outdir", output, "--force", "--silent", "--exiterror2", input]
      )
      Invocation.new(exit_code: exit_code, payload: bounded_file(File.join(output, "report.json"), "Ace"))
    end

    def run_verapdf(input)
      stdout, _stderr, exit_code = invoke(
        [path("verapdf"), "--format", "json", "--flavour", "ua1", "--maxfailuresdisplayed", "1", input]
      )
      Invocation.new(exit_code: exit_code, payload: stdout)
    end

    def invoke(argv)
      executor.call(
        argv,
        environment: {
          "LC_ALL" => "C.UTF-8", "LANG" => "C.UTF-8", "TZ" => "UTC",
          "HTTP_PROXY" => nil, "HTTPS_PROXY" => nil, "ALL_PROXY" => nil,
          "NO_PROXY" => "*"
        },
        timeout_seconds: timeout_seconds
      )
    end

    def bounded_file(path, label)
      stat = File.stat(path)
      raise AuditError, "#{label} structured report exceeded the bounded output limit" if stat.size > MAX_TOOL_OUTPUT_BYTES

      File.binread(path)
    rescue Errno::ENOENT
      raise AuditError, "#{label} did not emit its required structured report"
    end

    def path(id)
      tools.fetch(id).resolved_path
    end
  end

  class ResultParser
    SAFE_FINDING = /\A[a-zA-Z0-9][a-zA-Z0-9._:-]{0,159}\z/.freeze

    def call(engine_id:, invocation:)
      case engine_id
      when "axe-core" then parse_axe(invocation)
      when "epubcheck" then parse_epubcheck(invocation)
      when "ace" then parse_ace(invocation)
      when "verapdf" then parse_verapdf(invocation)
      else raise AuditError, "unsupported accessibility result parser #{engine_id}"
      end
    rescue KeyError, TypeError, NoMethodError => e
      raise AuditError, "#{engine_id}: structured result has an invalid shape (#{e.class})"
    end

    private

    def parse_axe(invocation)
      document = parse_json(invocation.payload, "axe-core")
      raise AuditError, "axe-core: expected one JSON result" unless document.is_a?(Array) && document.length == 1

      result = document.first
      violations = array!(result, "violations", "axe-core")
      incomplete = array!(result, "incomplete", "axe-core")
      passes = array!(result, "passes", "axe-core")
      inapplicable = array!(result, "inapplicable", "axe-core")
      finding_ids = violations.map { |item| finding_id("violation", item.fetch("id")) }
      finding_ids.concat(incomplete.map { |item| finding_id("incomplete", item.fetch("id")) })
      violation_nodes = violations.sum { |item| array!(item, "nodes", "axe-core violation").length }
      incomplete_nodes = incomplete.sum { |item| array!(item, "nodes", "axe-core incomplete").length }
      outcome = violations.empty? ? (incomplete.empty? ? "passed" : "manual-review-required") : "failed"
      expected_exit = violations.empty? ? 0 : 1
      raise AuditError, "axe-core: exit status disagrees with structured findings" unless invocation.exit_code == expected_exit

      normalized(
        engine_version: result.fetch("testEngine").fetch("version").to_s,
        outcome: outcome,
        finding_count: violations.length,
        manual_review_signal_count: incomplete.length,
        finding_ids: finding_ids,
        metrics: {
          "violation_rule_count" => violations.length,
          "violation_node_count" => violation_nodes,
          "incomplete_rule_count" => incomplete.length,
          "incomplete_node_count" => incomplete_nodes,
          "pass_rule_count" => passes.length,
          "inapplicable_rule_count" => inapplicable.length
        }
      )
    end

    def parse_epubcheck(invocation)
      document = parse_json(invocation.payload, "epubcheck")
      checker = hash!(document, "checker", "epubcheck")
      messages = array!(document, "messages", "epubcheck")
      counts = %w[nFatal nError nWarning nUsage].each_with_object({}) do |name, result|
        value = checker.fetch(name)
        raise AuditError, "epubcheck: #{name} must be a non-negative integer" unless value.is_a?(Integer) && value >= 0

        result[name] = value
      end
      finding_count = counts.fetch("nFatal") + counts.fetch("nError") + counts.fetch("nWarning")
      unless messages.length == counts.values.sum
        raise AuditError, "epubcheck: message inventory disagrees with checker counters"
      end
      outcome = finding_count.zero? ? "passed" : "failed"
      expected_exit = finding_count.zero? ? 0 : 1
      raise AuditError, "epubcheck: exit status disagrees with structured findings" unless invocation.exit_code == expected_exit

      finding_ids = messages.map do |message|
        raw = message.is_a?(Hash) ? (message["ID"] || message["id"] || message["messageId"]) : nil
        finding_id("message", raw || Canonical.sha256(Canonical.compact_json(message))[0, 16])
      end
      normalized(
        engine_version: "EPUBCheck v#{checker.fetch('checkerVersion')}",
        outcome: outcome,
        finding_count: finding_count,
        manual_review_signal_count: 0,
        finding_ids: finding_ids,
        metrics: counts.merge("message_count" => messages.length)
      )
    end

    def parse_ace(invocation)
      document = parse_json(invocation.payload, "ace")
      raise AuditError, "ace: report root type is unsupported" unless document.fetch("@type") == "earl:report"

      revision = document.fetch("earl:assertedBy").fetch("doap:release").fetch("doap:revision").to_s
      root_outcome = document.fetch("earl:result").fetch("earl:outcome").to_s
      assertions = collect_ace_assertions(document)
      non_pass = assertions.reject { |assertion| assertion.dig("earl:result", "earl:outcome") == "pass" }
      metadata = hash!(document, "a11y-metadata", "ace")
      missing_metadata = array!(metadata, "missing", "ace a11y-metadata")
      unless missing_metadata.all? { |value| value.is_a?(String) && !value.empty? }
        raise AuditError, "ace: missing metadata inventory must contain non-empty names"
      end
      case root_outcome
      when "pass"
        raise AuditError, "ace: passing root contains non-passing assertions" unless non_pass.empty?
        raise AuditError, "ace: exit status disagrees with structured findings" unless invocation.exit_code.zero?
        outcome = "passed"
      when "fail"
        raise AuditError, "ace: exit status disagrees with structured findings" unless invocation.exit_code == 2
        outcome = "failed"
      when "cantTell", "untested", "inapplicable"
        raise AuditError, "ace: exit status disagrees with structured findings" unless [0, 2].include?(invocation.exit_code)
        outcome = "manual-review-required"
      else
        raise AuditError, "ace: unsupported EARL outcome"
      end
      finding_ids = non_pass.map do |assertion|
        finding_id("assertion", Canonical.sha256(Canonical.compact_json(assertion))[0, 16])
      end
      missing_metadata.each { |name| finding_ids << finding_id("metadata-missing", name.to_s) }
      normalized(
        engine_version: revision,
        outcome: outcome,
        finding_count: non_pass.length,
        manual_review_signal_count: missing_metadata.length,
        finding_ids: finding_ids,
        metrics: {
          "assertion_count" => assertions.length,
          "non_pass_assertion_count" => non_pass.length,
          "missing_metadata_count" => missing_metadata.length
        }
      )
    end

    def parse_verapdf(invocation)
      document = parse_json(invocation.payload, "verapdf")
      report = hash!(document, "report", "verapdf")
      jobs = array!(report, "jobs", "verapdf")
      raise AuditError, "verapdf: expected exactly one job" unless jobs.length == 1

      job = jobs.first
      results = array!(job, "validationResult", "verapdf")
      raise AuditError, "verapdf: expected exactly one validation result" unless results.length == 1

      result = results.first
      raise AuditError, "verapdf: validation job did not end normally" unless result.fetch("jobEndStatus") == "normal"
      raise AuditError, "verapdf: PDF/UA-1 profile was not used" unless result.fetch("profileName") == "PDF/UA-1 validation profile"

      details = hash!(result, "details", "verapdf")
      metrics = %w[passedRules failedRules passedChecks failedChecks].each_with_object({}) do |name, values|
        value = details.fetch(name)
        raise AuditError, "verapdf: #{name} must be a non-negative integer" unless value.is_a?(Integer) && value >= 0

        values[name] = value
      end
      compliant = result.fetch("compliant")
      raise AuditError, "verapdf: compliant must be boolean" unless [true, false].include?(compliant)
      mechanically_compliant = metrics.fetch("failedRules").zero? && metrics.fetch("failedChecks").zero?
      unless compliant == mechanically_compliant
        raise AuditError, "verapdf: compliance flag disagrees with failed rule/check counters"
      end
      expected_exit = compliant ? 0 : 1
      raise AuditError, "verapdf: exit status disagrees with structured findings" unless invocation.exit_code == expected_exit

      summaries = Array(details["ruleSummaries"])
      failed = summaries.select { |summary| summary["status"] == "failed" || summary["ruleStatus"] == "FAILED" }
      finding_ids = failed.map do |summary|
        finding_id("rule", [summary["clause"], summary["testNumber"]].compact.join("."))
      end
      apps = Array(report.dig("buildInformation", "releaseDetails")).find { |item| item["id"] == "apps" }
      raise AuditError, "verapdf: apps version is missing" unless apps && apps["version"]

      normalized(
        engine_version: "veraPDF #{apps.fetch('version')}",
        outcome: compliant ? "passed" : "failed",
        finding_count: metrics.fetch("failedChecks"),
        manual_review_signal_count: 0,
        finding_ids: finding_ids,
        metrics: metrics
      )
    end

    def parse_json(bytes, label)
      ContractDocuments.strict_json(bytes, "#{label} structured output")
    rescue AuditError
      raise AuditError, "#{label}: structured output could not be parsed"
    end

    def array!(document, key, label)
      value = document.fetch(key)
      raise AuditError, "#{label}: #{key} must be an array" unless value.is_a?(Array)

      value
    end

    def hash!(document, key, label)
      value = document.fetch(key)
      raise AuditError, "#{label}: #{key} must be an object" unless value.is_a?(Hash)

      value
    end

    def collect_ace_assertions(document)
      found = []
      stack = [document]
      until stack.empty?
        node = stack.pop
        case node
        when Hash
          found << node if node["@type"] == "earl:assertion"
          node.each_value { |value| stack << value }
        when Array
          node.each { |value| stack << value }
        end
      end
      found
    end

    def finding_id(prefix, raw)
      candidate = "#{prefix}:#{raw}".gsub(/[^a-zA-Z0-9._:-]/, "-")
      return candidate if SAFE_FINDING.match?(candidate)

      "#{prefix}:#{Canonical.sha256(raw.to_s)[0, 24]}"
    end

    def normalized(engine_version:, outcome:, finding_count:, manual_review_signal_count:, finding_ids:, metrics:)
      {
        "engine_version" => engine_version,
        "outcome" => outcome,
        "finding_count" => finding_count,
        "manual_review_signal_count" => manual_review_signal_count,
        "finding_ids" => finding_ids.uniq.sort,
        "metrics" => metrics
      }
    end
  end

  class Auditor
    attr_reader :reader, :publication, :toolchain, :tool_observer, :runner,
                :parser, :jobs, :timeout_seconds

    def initialize(root:, toolchain_path: TOOLCHAIN_PATH, tool_observer: nil,
                   runner: nil, parser: ResultParser.new, jobs: 4, timeout_seconds: DEFAULT_TIMEOUT_SECONDS)
      unless jobs.between?(1, 64) && timeout_seconds.between?(1, 3600)
        raise AuditError, "jobs must be 1..64 and timeout must be 1..3600 seconds"
      end

      @reader = RepositoryReader.new(root)
      @publication = BoundPublication.new(reader).load!
      @toolchain = Toolchain.new(reader, path: toolchain_path).load!
      @tool_observer = tool_observer || ToolObserver.new(timeout_seconds: [timeout_seconds, 30].min)
      @runner = runner
      @parser = parser
      @jobs = jobs
      @timeout_seconds = timeout_seconds
    end

    def report
      observed_tools = tool_observer.observe(toolchain)
      validate_observed_tools!(observed_tools)
      active_runner = runner || RealRunner.new(observed_tools, timeout_seconds: timeout_seconds)
      tasks = build_tasks
      results = execute(tasks, active_runner, observed_tools)
      tool_observer.verify_unchanged!(toolchain, observed_tools)
      reader.verify_unchanged!
      document = build_report(results, observed_tools)
      validate_report!(document)
      document
    end

    private

    def build_tasks
      tasks = publication.artifacts.flat_map do |artifact|
        FORMAT_ENGINES.fetch(artifact.document.fetch("format")).map do |engine_id|
          CheckTask.new(
            check_id: "#{engine_id}:#{artifact.document.fetch('path')}",
            engine_id: engine_id,
            artifact: artifact
          )
        end
      end.sort_by(&:check_id)
      counts = tasks.group_by(&:engine_id).transform_values(&:length)
      unless tasks.length == 324 && counts == EXPECTED_CHECK_COUNTS && tasks.map(&:check_id).uniq.length == tasks.length
        raise AuditError, "P9 check matrix does not recompute to the fixed 324-check contract"
      end
      tasks
    end

    def execute(tasks, active_runner, observed_tools)
      queue = Queue.new
      tasks.each { |task| queue << task }
      [jobs, tasks.length].min.times { queue << nil }
      results = []
      failures = []
      mutex = Mutex.new
      observations = observed_tools.each_with_object({}) { |tool, result| result[tool.id] = tool }
      workers = [jobs, tasks.length].min.times.map do
        Thread.new do
          while (task = queue.pop)
            next unless failures.empty?

            begin
              result = execute_one(task, active_runner, observations)
              mutex.synchronize { results << result }
            rescue StandardError => e
              mutex.synchronize { failures << e }
            end
          end
        end
      end
      workers.each(&:join)
      unless failures.empty?
        failure = failures.first
        raise failure if failure.is_a?(AuditError)

        raise AuditError, "accessibility audit worker failed (#{failure.class})"
      end
      raise AuditError, "P9 audit did not produce all 324 structured checks" unless results.length == tasks.length

      results.sort_by { |result| result.fetch("check_id") }
    end

    def execute_one(task, active_runner, observations)
      artifact = task.artifact.document
      repository_path = File.join(OUTPUT_ROOT, artifact.fetch("path"))
      bytes = reader.read_bound(
        repository_path,
        sha256: artifact.fetch("sha256"),
        size_bytes: artifact.fetch("size_bytes")
      )
      invocation = active_runner.call(engine_id: task.engine_id, artifact: task.artifact, bytes: bytes)
      unless invocation.is_a?(Invocation) && invocation.exit_code.is_a?(Integer) && invocation.payload.is_a?(String)
        raise AuditError, "#{task.engine_id}: runner returned an invalid structured invocation"
      end
      normalized = parser.call(engine_id: task.engine_id, invocation: invocation)
      validate_normalized!(task.engine_id, normalized, observations.fetch(task.engine_id).version)
      {
        "check_id" => task.check_id,
        "engine_id" => task.engine_id,
        "artifact_path" => artifact.fetch("path"),
        "artifact_identity_sha256" => artifact.fetch("identity_sha256"),
        "outcome" => normalized.fetch("outcome"),
        "finding_count" => normalized.fetch("finding_count"),
        "manual_review_signal_count" => normalized.fetch("manual_review_signal_count"),
        "finding_ids" => normalized.fetch("finding_ids"),
        "result_sha256" => Canonical.sha256(Canonical.compact_json(normalized))
      }
    rescue AuditError => e
      raise AuditError, "#{task.check_id}: #{e.message}"
    end

    def validate_normalized!(engine_id, result, observed_version)
      unless result.is_a?(Hash) && result.keys.sort == %w[engine_version finding_count finding_ids manual_review_signal_count metrics outcome] &&
             result.fetch("engine_version") == observed_version &&
             %w[passed failed manual-review-required].include?(result.fetch("outcome")) &&
             result.fetch("finding_count").is_a?(Integer) && result.fetch("finding_count") >= 0 &&
             result.fetch("manual_review_signal_count").is_a?(Integer) && result.fetch("manual_review_signal_count") >= 0 &&
             result.fetch("finding_ids").is_a?(Array) && result.fetch("finding_ids").uniq.length == result.fetch("finding_ids").length &&
             result.fetch("finding_ids").all? { |id| ResultParser::SAFE_FINDING.match?(id) } &&
             result.fetch("metrics").is_a?(Hash)
        raise AuditError, "#{engine_id}: normalized result contract is invalid"
      end
    end

    def validate_observed_tools!(observed_tools)
      ids = observed_tools.map(&:id)
      unless ids.sort == EXPECTED_TOOLS.keys.sort && ids.uniq.length == ids.length
        raise AuditError, "observed tool identities do not match the P9 toolchain"
      end
      roles = toolchain.tools.to_h { |tool| [tool.fetch("id"), tool.fetch("role")] }
      observed_tools.each do |tool|
        unless tool.role == roles.fetch(tool.id) && tool.version.is_a?(String) && !tool.version.empty? &&
               [tool.version_output_sha256, tool.entrypoint_sha256, tool.identity_sha256].all? { |value| value.to_s.match?(/\A[0-9a-f]{64}\z/) }
          raise AuditError, "#{tool.id}: observed tool identity is invalid"
        end
      end
    end

    def build_report(results, observed_tools)
      tool_reports = observed_tools.map(&:report_projection).sort_by { |tool| tool.fetch("id") }
      passed = results.count { |result| result.fetch("outcome") == "passed" }
      failed = results.count { |result| result.fetch("outcome") == "failed" }
      manual = results.count { |result| result.fetch("outcome") == "manual-review-required" }
      {
        "schema_version" => 1,
        "report_id" => "publication-accessibility.internal-complete",
        "profile_id" => PROFILE_ID,
        "status" => failed.zero? && manual.zero? ? "machine-passed" : "machine-findings",
        "claim_boundary" => {
          "evidence_classification" => "machine-only-not-certification",
          "certification_status" => "not-certified",
          "human_review" => "required",
          "promotion_policy" => "forbidden-without-human-review"
        },
        "publication_binding" => publication.binding_document,
        "toolchain_binding" => {
          "path" => toolchain.path,
          "sha256" => Canonical.sha256(toolchain.bytes),
          "toolchain_id" => toolchain.document.fetch("toolchain_id"),
          "tool_count" => tool_reports.length,
          "tool_identity_set_sha256" => Canonical.identity_set(tool_reports, "id", "identity_sha256"),
          "tools" => tool_reports
        },
        "audit_contract" => {
          "artifact_count" => 307,
          "artifacts_by_format" => EXPECTED_ARTIFACT_COUNTS,
          "check_count" => 324,
          "checks_by_engine" => EXPECTED_CHECK_COUNTS,
          "formula" => "273 axe + 17 EPUBCheck + 17 Ace + 17 veraPDF = 324 checks over 307 artifacts",
          "unselected_manifest_output_count" => publication.unselected_manifest_output_count,
          "input_drift_policy" => "fail-closed",
          "duplicate_policy" => "fail-closed",
          "parse_failure_policy" => "fail-closed",
          "raw_log_retention" => "forbidden",
          "transient_tool_output_limit_bytes" => MAX_TOOL_OUTPUT_BYTES,
          "execution_policy" => {
            "jobs" => jobs,
            "per_invocation_timeout_seconds" => timeout_seconds,
            "axe_rule_tags" => AXE_RULE_TAGS
          }
        },
        "summary" => {
          "artifact_count" => publication.artifacts.length,
          "check_count" => results.length,
          "passed_count" => passed,
          "failed_count" => failed,
          "manual_review_required_count" => manual,
          "manual_review_signal_count" => results.sum { |result| result.fetch("manual_review_signal_count") }
        },
        "artifacts" => publication.artifact_reports.sort_by { |artifact| artifact.fetch("path") },
        "checks" => results,
        "check_set_sha256" => Canonical.identity_set(results, "check_id", "result_sha256")
      }
    end

    def validate_report!(document)
      schema_bytes = reader.read(REPORT_SCHEMA_PATH)
      ContractDocuments.validate_schema!(document, schema_bytes, REPORT_SCHEMA_PATH, "P9 accessibility report")
      validate_report_semantics!(document)
      serialized = Canonical.json(document)
      if serialized.match?(%r{(?:^|["\s])/(?!/)[a-zA-Z0-9._-]+(?:/[a-zA-Z0-9._-]+)+}) ||
         serialized.match?(/[A-Za-z]:[\\\/]/) ||
         serialized.match?(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/)
        raise AuditError, "P9 accessibility report contains an absolute path or timestamp"
      end
      if forbidden_report_key?(document)
        raise AuditError, "P9 accessibility report contains raw command/log material"
      end
      reader.verify_unchanged!
      true
    end

    def validate_report_semantics!(document)
      artifacts = document.fetch("artifacts")
      checks = document.fetch("checks")
      unless artifacts.map { |item| item.fetch("path") }.uniq.length == 307 &&
             artifacts.group_by { |item| item.fetch("format") }.transform_values(&:length) == EXPECTED_ARTIFACT_COUNTS &&
             checks.map { |item| item.fetch("check_id") }.uniq.length == 324 &&
             checks.group_by { |item| item.fetch("engine_id") }.transform_values(&:length) == EXPECTED_CHECK_COUNTS
        raise AuditError, "P9 accessibility report coverage drifted from 307 artifacts / 324 checks"
      end
      artifact_by_path = artifacts.to_h { |artifact| [artifact.fetch("path"), artifact] }
      checks.each do |check|
        artifact = artifact_by_path.fetch(check.fetch("artifact_path"))
        unless check.fetch("artifact_identity_sha256") == artifact.fetch("identity_sha256") &&
               FORMAT_ENGINES.fetch(artifact.fetch("format")).include?(check.fetch("engine_id"))
          raise AuditError, "P9 accessibility check is not bound to the declared artifact/tool matrix"
        end
      end
      summary = document.fetch("summary")
      unless summary.fetch("passed_count") + summary.fetch("failed_count") + summary.fetch("manual_review_required_count") == 324
        raise AuditError, "P9 accessibility summary does not account for every check"
      end
      execution = document.fetch("audit_contract").fetch("execution_policy")
      unless execution.fetch("jobs").between?(1, 64) &&
             execution.fetch("per_invocation_timeout_seconds").between?(1, 3600) &&
             execution.fetch("axe_rule_tags") == AXE_RULE_TAGS
        raise AuditError, "P9 accessibility execution policy is unsupported"
      end
    end

    def forbidden_report_key?(value)
      case value
      when Hash
        value.any? do |key, child|
          %w[stdout stderr raw_output raw_log command command_line].include?(key) || forbidden_report_key?(child)
        end
      when Array
        value.any? { |child| forbidden_report_key?(child) }
      else
        false
      end
    end
  end

  module CLI
    module_function

    def run(argv, stdout: $stdout, stderr: $stderr)
      options = parse_options(argv)
      report = Auditor.new(
        root: options.fetch(:root),
        toolchain_path: options.fetch(:toolchain),
        jobs: options.fetch(:jobs),
        timeout_seconds: options.fetch(:timeout_seconds)
      ).report
      bytes = Canonical.json(report)
      if options[:output]
        write_atomic(options.fetch(:output), bytes)
        stdout.puts "PUBLICATION ACCESSIBILITY #{report.fetch('status')} artifacts=307 checks=324"
      else
        stdout.write(bytes)
      end
      report.fetch("status") == "machine-passed" ? 0 : 1
    rescue OptionParser::ParseError, AuditError, Errno::ENOENT, Errno::EACCES => e
      stderr.puts "PUBLICATION ACCESSIBILITY AUDIT FAILED: #{e.message.lines.first.to_s.strip}"
      2
    end

    def parse_options(argv)
      options = {
        root: File.expand_path("..", __dir__),
        toolchain: TOOLCHAIN_PATH,
        output: nil,
        jobs: Integer(ENV.fetch("FACTORYCARE_ACCESSIBILITY_JOBS", "4")),
        timeout_seconds: Integer(ENV.fetch("FACTORYCARE_ACCESSIBILITY_TIMEOUT", DEFAULT_TIMEOUT_SECONDS.to_s))
      }
      OptionParser.new do |parser|
        parser.banner = "Usage: ruby scripts/audit-publication-accessibility.rb [options]"
        parser.on("--root PATH") { |value| options[:root] = value }
        parser.on("--toolchain PATH") { |value| options[:toolchain] = value }
        parser.on("--output PATH") { |value| options[:output] = value }
        parser.on("--jobs N", Integer) { |value| options[:jobs] = value }
        parser.on("--timeout SECONDS", Integer) { |value| options[:timeout_seconds] = value }
      end.parse!(argv)
      raise OptionParser::InvalidArgument, "unexpected positional arguments" unless argv.empty?
      unless options.fetch(:jobs).positive? && options.fetch(:timeout_seconds).positive?
        raise OptionParser::InvalidArgument, "jobs and timeout must be positive"
      end
      options
    rescue ArgumentError => e
      raise OptionParser::InvalidArgument, e.message
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

exit PublicationAccessibilityAudit::CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
