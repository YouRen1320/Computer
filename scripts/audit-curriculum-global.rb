#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "optparse"
require "psych"
require "set"

module GlobalCurriculumAudit
  EXPECTED_ROUTE_IDS = %w[accelerated-48 factorycare-project reference zero-base].freeze
  COMPLETE_ROUTES = %w[accelerated-48 reference zero-base].freeze
  EXPECTED_MODULE_IDS = (1..48).map { |index| format("m%02d", index) }.freeze
  EXPECTED_FACTORYCARE_STAGES = 8
  GENERATED_PREREQUISITE_BLOCK = /<!-- BEGIN GENERATED LEARNING PREREQUISITES -->.*?<!-- END GENERATED LEARNING PREREQUISITES -->/m
  CODE_FENCE = /^(?<fence>`{3,}|~{3,}).*?^\k<fence>\s*$/m
  FORBIDDEN_CANONICAL_PATTERNS = {
    "react" => /\breact\b/i,
    "nextjs" => /\bnext(?:\.js|js)\b/i,
    "kafka" => /\bkafka\b/i,
    "kubernetes" => /\b(?:kubernetes|k8s)\b/i,
    "java-microservice" => /\b(?:java\s+microservices?|java\s+微服务)\b/i
  }.freeze

  class AuditError < StandardError; end

  class Auditor
    attr_reader :root, :failures

    def initialize(root)
      @root = File.realpath(root)
      @failures = []
    end

    def report
      @failures = []
      catalog = load_yaml("curriculum/catalog.yml")
      volumes = load_yaml("curriculum/volumes.yml")
      capabilities = load_yaml("curriculum/capabilities.yml")
      chapters = catalog.fetch("chapters")
      chapter_ids = chapters.map { |chapter| chapter.fetch("id") }
      chapter_set = chapter_ids.to_set

      catalog_report = audit_catalog(catalog, chapters, chapter_ids)
      volume_report = audit_volumes(volumes, chapters)
      capability_report = audit_capabilities(capabilities, chapters, chapter_set)
      prerequisite_report = audit_prerequisites(chapters, chapter_set)
      route_report = audit_routes(chapters, chapter_set)
      content_report = audit_content(chapters)
      similarity_source_report = audit_similarity_and_sources
      alignment_report = audit_alignment(chapters)

      {
        "schema_version" => 1,
        "audit_id" => "p9-global-curriculum",
        "generated_by" => "scripts/audit-curriculum-global.rb",
        "status" => failures.empty? ? "passed" : "failed",
        "catalog" => catalog_report,
        "volumes" => volume_report,
        "capabilities" => capability_report,
        "prerequisites" => prerequisite_report,
        "routes" => route_report,
        "content" => content_report,
        "similarity_and_sources" => similarity_source_report,
        "goal_alignment" => alignment_report,
        "failures" => failures.sort,
        "evidence_boundary" => "structure, routing, exact-long-paragraph duplication, exact all-pair Unicode-shingle metrics, syntactic direct-HTTPS presence, and canonical-stack drift only; content truth, source authority, citation entailment, originality, and human learnability are not asserted"
      }
    rescue KeyError, Psych::Exception, Errno::ENOENT => e
      raise AuditError, e.message.lines.first.to_s.strip
    end

    private

    def load_yaml(relative)
      path = File.join(root, relative)
      value = Psych.safe_load(File.binread(path).force_encoding(Encoding::UTF_8), aliases: false)
      raise AuditError, "#{relative} must contain a mapping" unless value.is_a?(Hash)

      value
    end

    def audit_catalog(catalog, chapters, chapter_ids)
      target = Integer(catalog.fetch("chapter_count_target"))
      duplicate_ids = duplicates(chapter_ids)
      fail_if(chapters.length != target, "catalog chapter count #{chapters.length} does not match target #{target}")
      fail_if(!duplicate_ids.empty?, "catalog contains duplicate chapter ids: #{duplicate_ids.join(', ')}")
      missing_paths = chapters.each_with_object([]) do |chapter, memo|
        path = chapter.fetch("path")
        memo << path unless File.file?(File.join(root, path))
      end
      fail_if(!missing_paths.empty?, "catalog references missing chapter files: #{missing_paths.first(5).join(', ')}")
      {
        "edition" => catalog.fetch("edition"),
        "target" => target,
        "actual" => chapters.length,
        "unique_ids" => chapter_ids.uniq.length,
        "missing_paths" => missing_paths
      }
    end

    def audit_volumes(volume_document, chapters)
      declared = volume_document.fetch("volumes")
      actual_counts = chapters.group_by { |chapter| chapter.fetch("volume") }
                              .transform_values(&:length)
      rows = declared.map do |volume|
        id = volume.fetch("id").to_s.rjust(2, "0")
        expected = Integer(volume.fetch("expected_chapter_count"))
        actual = actual_counts.fetch(id, 0)
        fail_if(actual != expected, "volume #{id} has #{actual} chapters; expected #{expected}")
        { "id" => id, "expected" => expected, "actual" => actual }
      end
      declared_ids = rows.map { |row| row.fetch("id") }
      extra = actual_counts.keys - declared_ids
      fail_if(!extra.empty?, "catalog contains undeclared volumes: #{extra.sort.join(', ')}")
      fail_if(declared_ids != (0..15).map { |index| format("%02d", index) }, "volume ids must be 00 through 15")
      { "count" => rows.length, "chapter_total" => rows.sum { |row| row.fetch("actual") }, "items" => rows }
    end

    def audit_capabilities(document, chapters, chapter_set)
      items = document.fetch("capabilities")
      ids = items.map { |item| item.fetch("id") }
      declared_count = Integer(document.fetch("capability_count"))
      fail_if(items.length != declared_count, "capability count #{items.length} does not match #{declared_count}")
      fail_if(!duplicates(ids).empty?, "capability ids must be unique")
      id_set = ids.to_set
      bad_teachers = items.each_with_object([]) do |item, memo|
        teacher = item.fetch("teacher_chapter_id")
        memo << "#{item.fetch('id')}=>#{teacher}" unless chapter_set.include?(teacher)
      end
      bad_requires = items.flat_map do |item|
        Array(item.fetch("requires")).reject { |id| id_set.include?(id) }
          .map { |id| "#{item.fetch('id')}=>#{id}" }
      end
      chapter_refs = chapters.flat_map do |chapter|
        capabilities = chapter.fetch("capabilities")
        Array(capabilities.fetch("teaches")) + Array(capabilities.fetch("uses"))
      end
      invalid_chapter_refs = chapter_refs.reject { |id| id_set.include?(id) }.uniq.sort
      fail_if(!bad_teachers.empty?, "capabilities reference unknown teacher chapters: #{bad_teachers.first(5).join(', ')}")
      fail_if(!bad_requires.empty?, "capabilities reference unknown prerequisites: #{bad_requires.first(5).join(', ')}")
      fail_if(!invalid_chapter_refs.empty?, "chapters reference unknown capabilities: #{invalid_chapter_refs.first(5).join(', ')}")
      {
        "declared" => declared_count,
        "actual" => items.length,
        "chapter_reference_count" => chapter_refs.length,
        "invalid_reference_count" => bad_teachers.length + bad_requires.length + invalid_chapter_refs.length
      }
    end

    def audit_prerequisites(chapters, chapter_set)
      graph = chapters.to_h { |chapter| [chapter.fetch("id"), Array(chapter.fetch("prerequisites"))] }
      invalid = graph.flat_map do |id, prerequisites|
        prerequisites.reject { |prerequisite| chapter_set.include?(prerequisite) }
                     .map { |prerequisite| "#{id}=>#{prerequisite}" }
      end
      self_edges = graph.each_with_object([]) do |(id, prerequisites), memo|
        memo << id if prerequisites.include?(id)
      end
      fail_if(!invalid.empty?, "prerequisite graph contains unknown ids: #{invalid.first(5).join(', ')}")
      fail_if(!self_edges.empty?, "prerequisite graph contains self edges: #{self_edges.first(5).join(', ')}")

      indegree = graph.transform_values(&:length)
      dependents = Hash.new { |hash, key| hash[key] = [] }
      graph.each { |id, prerequisites| prerequisites.each { |prerequisite| dependents[prerequisite] << id } }
      queue = indegree.select { |_id, degree| degree.zero? }.keys.sort
      visited = []
      until queue.empty?
        id = queue.shift
        visited << id
        dependents.fetch(id, []).sort.each do |dependent|
          indegree[dependent] -= 1
          queue << dependent if indegree[dependent].zero?
        end
        queue.sort!
      end
      fail_if(visited.length != graph.length, "prerequisite graph contains a cycle")
      {
        "edge_count" => graph.values.sum(&:length),
        "root_count" => graph.values.count(&:empty?),
        "topological_count" => visited.length,
        "acyclic" => visited.length == graph.length,
        "invalid_edge_count" => invalid.length,
        "self_edge_count" => self_edges.length
      }
    end

    def audit_routes(chapters, chapter_set)
      by_tag = Hash.new { |hash, key| hash[key] = Set.new }
      chapters.each do |chapter|
        Array(chapter.fetch("route_tags")).each { |tag| by_tag[tag] << chapter.fetch("id") }
      end
      route_files = Dir.glob(File.join(root, "curriculum/routes/*.yml")).sort
      route_ids = route_files.map { |path| File.basename(path, ".yml") }
      fail_if(route_ids != EXPECTED_ROUTE_IDS, "route set must be #{EXPECTED_ROUTE_IDS.join(', ')}")

      items = route_files.map do |path|
        relative = path.delete_prefix(root + File::SEPARATOR)
        document = load_yaml(relative)
        route_id = document.fetch("route_id")
        references = route_id == "reference" ? document.fetch("chapter_index").keys : collect_chapter_references(document)
        unique = references.to_set
        invalid = unique.reject { |id| chapter_set.include?(id) }.to_a.sort
        missing = chapter_set - unique
        fail_if(!invalid.empty?, "route #{route_id} references unknown chapters: #{invalid.first(5).join(', ')}")
        fail_if(COMPLETE_ROUTES.include?(route_id) && !missing.empty?, "complete route #{route_id} misses #{missing.length} chapters")
        tagged = by_tag.fetch(route_id, Set.new)
        fail_if(tagged != unique, "route tag projection differs from route #{route_id}")

        if route_id == "accelerated-48"
          module_ids = document.fetch("modules").map { |item| item.fetch("id") }
          fail_if(module_ids != EXPECTED_MODULE_IDS, "accelerated route module ids must be m01 through m48")
        elsif route_id == "factorycare-project"
          stages = document.fetch("stages")
          fail_if(stages.length != EXPECTED_FACTORYCARE_STAGES, "FactoryCare route must contain #{EXPECTED_FACTORYCARE_STAGES} stages")
          fail_if(!duplicates(stages.map { |item| item.fetch("id") }).empty?, "FactoryCare stage ids must be unique")
        end
        {
          "route_id" => route_id,
          "coverage_policy" => document.fetch("coverage"),
          "raw_reference_count" => references.length,
          "unique_chapter_count" => unique.length,
          "coverage_percent" => ((unique.length.fdiv(chapter_set.length)) * 100).round(2),
          "invalid_ids" => invalid,
          "missing_ids" => missing.to_a.sort
        }
      end
      { "count" => items.length, "items" => items }
    end

    def collect_chapter_references(value, parent_key = nil, output = [])
      case value
      when Hash
        value.each { |key, child| collect_chapter_references(child, key.to_s, output) }
      when Array
        if parent_key == "chapter_ids" || parent_key&.end_with?("_chapter_ids")
          output.concat(value.select { |item| item.is_a?(String) })
        else
          value.each { |child| collect_chapter_references(child, parent_key, output) }
        end
      end
      output
    end

    def audit_content(chapters)
      characters = {}
      paragraph_owners = Hash.new { |hash, key| hash[key] = Set.new }
      comparable_paragraph_count = 0
      chapters.each do |chapter|
        id = chapter.fetch("id")
        body = File.binread(File.join(root, chapter.fetch("path"))).force_encoding(Encoding::UTF_8)
        body = strip_front_matter(body)
        body = body.gsub(GENERATED_PREREQUISITE_BLOCK, "\n")
        body = body.gsub(CODE_FENCE, "\n")
        characters[id] = body.length
        body.split(/\n\s*\n+/).each do |paragraph|
          normalized = normalize_paragraph(paragraph)
          next if normalized.length < 120
          next if normalized.start_with?("#", "|", ">", "- ", "* ", "+ ")

          comparable_paragraph_count += 1
          paragraph_owners[normalized] << id
        end
      end
      duplicates_found = paragraph_owners.each_with_object([]) do |(text, owners), memo|
        next unless owners.length > 1

        memo << { "chapter_ids" => owners.to_a.sort, "characters" => text.length, "text_sha256" => require_digest(text) }
      end.sort_by { |item| [item.fetch("chapter_ids"), item.fetch("text_sha256")] }
      fail_if(!duplicates_found.empty?, "content contains #{duplicates_found.length} exact cross-chapter long-paragraph duplicate groups")
      minimum = characters.min_by { |_id, count| count }
      maximum = characters.max_by { |_id, count| count }
      under_minimum = characters.select { |_id, count| count < 10_000 }.keys.sort
      {
        "chapter_character_total" => characters.values.sum,
        "minimum_chapter" => { "id" => minimum.first, "characters" => minimum.last },
        "maximum_chapter" => { "id" => maximum.first, "characters" => maximum.last },
        "under_10000_count" => under_minimum.length,
        "comparable_long_paragraph_count" => comparable_paragraph_count,
        "exact_cross_chapter_duplicate_group_count" => duplicates_found.length,
        "exact_cross_chapter_duplicate_groups" => duplicates_found
      }
    end

    def audit_alignment(chapters)
      canonical_text = chapters.map { |chapter| "#{chapter.fetch('id')} #{chapter.fetch('title')}" }
      hits = FORBIDDEN_CANONICAL_PATTERNS.each_with_object({}) do |(name, pattern), memo|
        matched = canonical_text.select { |text| pattern.match?(text) }
        memo[name] = matched unless matched.empty?
      end
      fail_if(!hits.empty?, "canonical catalog contains out-of-scope stack chapters: #{hits.keys.sort.join(', ')}")
      required_prefixes = %w[
        ch.foundations. ch.java. ch.java-oop. ch.java-engineering. ch.data. ch.spring. ch.security.
        ch.web. ch.js. ch.ts. ch.vue. ch.nuxt. ch.uniapp. ch.dart. ch.flutter. ch.python.
        ch.ml. ch.pytorch. ch.llm. ch.rag. ch.agent. ch.ops. ch.release.
      ]
      ids = chapters.map { |chapter| chapter.fetch("id") }
      missing_prefixes = required_prefixes.reject { |prefix| ids.any? { |id| id.start_with?(prefix) } }
      fail_if(!missing_prefixes.empty?, "canonical stack is missing chapter namespaces: #{missing_prefixes.join(', ')}")
      {
        "required_namespace_count" => required_prefixes.length,
        "missing_namespaces" => missing_prefixes,
        "out_of_scope_canonical_hits" => hits
      }
    end

    def audit_similarity_and_sources
      script = File.expand_path("audit-chapter-similarity.py", __dir__)
      python = ENV.fetch("PYTHON", "python3")
      stdout, stderr, status = Open3.capture3(
        { "PYTHONHASHSEED" => "0" },
        python,
        script,
        "--root",
        root,
        "--summary"
      )
      unless [0, 1].include?(status.exitstatus)
        detail = stderr.lines.first.to_s.strip
        raise AuditError, "chapter similarity/source audit could not run#{detail.empty? ? '' : ": #{detail}"}"
      end

      report = JSON.parse(stdout)
      raise AuditError, "chapter similarity/source audit returned an unexpected audit_id" unless report["audit_id"] == "p9-chapter-similarity-sources"

      expected_exit = report.fetch("status") == "passed" ? 0 : 1
      raise AuditError, "chapter similarity/source audit exit/status mismatch" unless status.exitstatus == expected_exit

      Array(report.fetch("failures")).each do |failure|
        failures << "similarity/source audit: #{failure}"
      end
      {
        "audit_id" => report.fetch("audit_id"),
        "status" => report.fetch("status"),
        "parameters" => report.fetch("parameters"),
        "summary" => report.fetch("summary"),
        "top_pairs" => report.fetch("top_pairs"),
        "missing_source_chapter_ids" => report.fetch("missing_source_chapter_ids"),
        "similarity_violations" => report.fetch("similarity_violations"),
        "failures" => report.fetch("failures"),
        "replay_command" => "python3 scripts/audit-chapter-similarity.py --root . --output /tmp/factorycare-chapter-similarity.json --pretty",
        "evidence_boundary" => report.fetch("evidence_boundary")
      }
    rescue JSON::ParserError => e
      raise AuditError, "chapter similarity/source audit returned invalid JSON: #{e.message.lines.first.to_s.strip}"
    rescue Errno::ENOENT => e
      raise AuditError, "chapter similarity/source audit interpreter is unavailable: #{e.message.lines.first.to_s.strip}"
    end

    def strip_front_matter(body)
      body.sub(/\A---\s*\n.*?\n---\s*\n/m, "")
    end

    def normalize_paragraph(paragraph)
      paragraph.gsub(/\[[^\]]+\]\([^)]+\)/) { |match| match[/\[([^\]]+)\]/, 1].to_s }
               .gsub(/[[:space:]]+/u, " ")
               .gsub(/[[:punct:]]+/u, " ")
               .strip
               .downcase
    end

    def require_digest(text)
      require "digest"
      Digest::SHA256.hexdigest(text)
    end

    def duplicates(values)
      values.group_by(&:itself).select { |_value, occurrences| occurrences.length > 1 }.keys.sort
    end

    def fail_if(condition, message)
      failures << message if condition
    end
  end

  module CLI
    module_function

    def run(argv, stdout: $stdout, stderr: $stderr)
      options = { root: File.expand_path("..", __dir__), output: nil, pretty: false }
      parser = OptionParser.new do |command|
        command.banner = "Usage: ruby scripts/audit-curriculum-global.rb [--root PATH] [--output PATH] [--pretty]"
        command.on("--root PATH", "Repository root") { |value| options[:root] = value }
        command.on("--output PATH", "Write JSON report") { |value| options[:output] = value }
        command.on("--pretty", "Pretty-print JSON") { options[:pretty] = true }
      end
      parser.parse!(argv)
      raise AuditError, "unexpected positional arguments" unless argv.empty?

      report = Auditor.new(options.fetch(:root)).report
      bytes = options.fetch(:pretty) ? JSON.pretty_generate(report) + "\n" : JSON.generate(report) + "\n"
      if options[:output]
        File.binwrite(File.expand_path(options.fetch(:output)), bytes)
        stdout.puts "GLOBAL CURRICULUM AUDIT #{report.fetch('status').upcase}"
        stdout.puts "report=#{File.expand_path(options.fetch(:output))}"
      else
        stdout.write(bytes)
      end
      report.fetch("status") == "passed" ? 0 : 1
    rescue OptionParser::ParseError, AuditError, Errno::ENOENT => e
      stderr.puts "GLOBAL CURRICULUM AUDIT FAILED: #{e.message.lines.first.to_s.strip}"
      2
    end
  end
end

exit GlobalCurriculumAudit::CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
