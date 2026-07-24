#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "optparse"
require "tempfile"
require "yaml"

require File.expand_path("../verification/lib/contract", __dir__)
require File.expand_path("../verification/lib/coverage_audit", __dir__)

module Verification
  # This helper intentionally does not infer commands, exit codes, observations,
  # or output closure. Those are executable contracts and require human review.
  # It only refreshes file modes, per-file digests, counts, and the input-set
  # digest after an author has explicitly written a complete manifest.
  module ManifestGenerator
    module_function

    def run(argv, root: File.expand_path("..", __dir__), stdout: $stdout, stderr: $stderr)
      options = parse_options(argv)
      loader = ManifestLoader.new(root)
      if options.fetch(:coverage)
        report = CoverageAudit.new(root, loader: loader).report
        emit_coverage(report, options.fetch(:json), stdout)
        return report.fetch("contract_complete") ? 0 : 1
      end
      if options.fetch(:bootstrap)
        catalog = CoverageAudit.new(root, loader: loader).candidate_catalog
        stdout.write(Canonical.json(catalog))
        return 0
      end
      if options.fetch(:check)
        manifests = loader.discover
        stdout.puts("VERIFICATION MANIFEST CHECK OK manifests=#{manifests.length}")
        return 0
      end

      paths = manifest_paths(root)
      rendered = paths.each_with_object({}) do |relative, memo|
        bytes, = loader.guard.read_contract(relative)
        data = StrictYaml.safe_load(bytes.force_encoding(Encoding::UTF_8), label: relative)
        unless data.is_a?(Hash)
          raise ContractError.new("schema", "E_MANIFEST_ROOT", "manifest root must be a mapping", path: relative)
        end
        input_entries = data.fetch("inputs")
        digest_entries = input_entries.map do |input|
          path = input.fetch("path")
          loader.guard.validate_public_path!(path)
          source_bytes, stat = loader.guard.read_contract(path)
          input["sha256"] = Canonical.sha256(source_bytes)
          input["mode"] = format("%04o", stat.mode & 0o777)
          { "path" => path, "bytes" => source_bytes }
        end
        data["input_count"] = input_entries.length
        data["input_set_sha256"] = Canonical.path_bytes_digest(digest_entries)
        loader.validate_document(data, relative)
        memo[relative] = YAML.dump(data)
      end
      rendered.each { |relative, bytes| atomic_replace(root, relative, bytes) }
      loader.discover
      stdout.puts("VERIFICATION MANIFEST WRITE OK manifests=#{rendered.length}")
      0
    rescue ContractError, KeyError, Psych::Exception => e
      diagnostic = e.respond_to?(:diagnostic) ? e.diagnostic : "[generation/E_GENERATE]: #{e.message.lines.first.to_s.strip}"
      stderr.puts(diagnostic)
      1
    rescue OptionParser::ParseError => e
      stderr.puts(e.message)
      stderr.puts(usage)
      64
    end

    def parse_options(argv)
      options = { check: false, write: false, coverage: false, bootstrap: false, json: false }
      OptionParser.new do |parser|
        parser.banner = usage
        parser.on("--check", "validate existing manifests without changing bytes") { options[:check] = true }
        parser.on("--write", "refresh only modes and digests in reviewed existing manifests") { options[:write] = true }
        parser.on("--coverage", "compare final manifests with all canonical chapters; incomplete coverage exits 1") { options[:coverage] = true }
        parser.on("--bootstrap-candidates", "emit per-chapter unreviewed candidate inventory without writing") { options[:bootstrap] = true }
        parser.on("--json", "emit JSON for coverage or candidates") { options[:json] = true }
      end.parse!(argv)
      primary = %i[check write coverage bootstrap].count { |key| options.fetch(key) }
      raise OptionParser::InvalidOption, "choose exactly one primary operation" unless primary == 1
      if options.fetch(:json) && !(options.fetch(:coverage) || options.fetch(:bootstrap))
        raise OptionParser::InvalidOption, "--json is only valid with --coverage or --bootstrap-candidates"
      end
      raise OptionParser::InvalidOption, "unexpected arguments: #{argv.join(' ')}" unless argv.empty?

      options
    end

    def manifest_paths(root)
      directory = File.join(root, MANIFEST_DIRECTORY)
      names = Dir.children(directory).sort
      unless names.all? { |name| name.end_with?(".yml") } && !names.empty?
        raise ContractError.new("inventory", "E_MANIFEST_SET", "manifest directory must contain only .yml files")
      end
      names.map { |name| File.join(MANIFEST_DIRECTORY, name) }
    end

    def atomic_replace(root, relative, bytes)
      absolute = File.join(root, relative)
      directory = File.dirname(absolute)
      Tempfile.create([".verification-manifest-", ".yml"], directory) do |file|
        file.binmode
        file.write(bytes)
        file.flush
        file.fsync
        File.chmod(0o644, file.path)
        File.rename(file.path, absolute)
      end
      File.open(directory, File::RDONLY) { |dir| dir.fsync }
    rescue Errno::EINVAL, Errno::EISDIR
      nil
    end

    def emit_coverage(report, json, stdout)
      if json
        stdout.write(Canonical.json(report))
        return
      end
      stdout.puts(
        "VERIFICATION COVERAGE final=#{report.fetch('final_manifest_count')}/#{report.fetch('chapter_total')} " \
        "candidates=#{report.fetch('bootstrap_candidate_count')} complete=#{report.fetch('contract_complete')}"
      )
      report.fetch("missing_final_manifest_ids").each { |id| stdout.puts("MISSING_FINAL #{id}") }
      stdout.puts("boundary=#{report.fetch('boundary')}")
    end

    def usage
      "Usage: ruby scripts/generate-verification-manifests.rb " \
        "(--check|--write|--coverage|--bootstrap-candidates) [--json]"
    end
  end
end

exit Verification::ManifestGenerator.run(ARGV) if $PROGRAM_NAME == __FILE__
