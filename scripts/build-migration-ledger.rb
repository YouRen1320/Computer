#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "yaml"

ROOT = File.expand_path("..", __dir__)
require File.join(ROOT, "scripts", "lib", "curriculum_migration_audit")

options = { output: File.join(ROOT, "curriculum", "migrations", "2026.1-to-2026.2.yml") }
OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/build-migration-ledger.rb [--stdout]"
  parser.on("--stdout", "print the deterministic ledger instead of writing it") { options[:stdout] = true }
end.parse!

audit_path = "records/encyclopedia/reviews/P1R-migration-ledger-audit.md"
audit_source = File.binread(File.join(ROOT, audit_path))
components = Curriculum::MigrationAudit.parse(audit_source)

entries = components.map do |component|
  policy = case component.type
  when "preserve" then "automatic-one-to-one"
  when "split", "repartition" then "regenerate-from-frozen-source-inventory"
  when "merge" then "automatic-merge-with-provenance"
  when "new" then "not-applicable"
  else raise "unsupported audit component type #{component.type.inspect}"
  end
  entry = {
    "component_id" => component.id,
    "action" => component.type,
    "from" => component.old_ids,
    "to" => component.new_ids,
    "chapter_edges" => component.edges.map { |from_id, to_id| { "from" => from_id, "to" => to_id } },
    "reason" => "采用独立迁移审计 #{component.id} 的精确顶点与边",
    "source_mapping_policy" => policy
  }
  entry["source_rebuild_id"] = "frozen-notes-to-2026.2-candidates" if %w[split repartition].include?(component.type)
  entry
end

evidence = {
  "source_inventory_path" => "curriculum/migrations/evidence/2026.2-source-inventory.yml",
  "source_build_path" => "curriculum/migrations/evidence/2026.2-source-build.yml",
  "candidate_manifest_path" => "curriculum/migrations/evidence/2026.2-candidate-manifest.yml"
}
evidence_digests = evidence.transform_values do |relative|
  "sha256:#{Digest::SHA256.file(File.join(ROOT, relative)).hexdigest}"
end

document = {
  "schema_version" => 2,
  "migration_id" => "catalog-2026.1-to-2026.2-semantic-ids",
  "from_edition" => "2026.1-draft",
  "to_edition" => "2026.2-draft",
  "status" => "ready",
  "compatibility" => "none",
  "legacy_source_commit" => "61d6f853481cf522a388904ad93ab449688d88b1",
  "legacy_manifest_path" => "curriculum/migrations/legacy-2026.1-manifest.yml",
  "legacy_manifest_digest" => "sha256:d06a4422292ae6a25bd110ecaea9e627089b62eeec430218b6e6f4c2306f9d7c",
  "mapping_audit_path" => audit_path,
  "mapping_audit_digest" => Curriculum::MigrationAudit.digest(audit_source),
  "expected_component_count" => components.length,
  "expected_edge_count" => components.inject(0) { |sum, component| sum + component.edges.length },
  "expected_legacy_id_count" => components.flat_map(&:old_ids).length,
  "expected_active_id_count" => components.flat_map(&:new_ids).length,
  "entries" => entries,
  "section_overrides" => [],
  "source_rebuilds" => [{
    "id" => "frozen-notes-to-2026.2-candidates",
    "source_commits" => {
      "note" => "72b27e3bad732fa86d5fd9d9c990c6d5ecaf9f96",
      "java-note" => "3c4928bf78b24d6550538ea388240fe3b4ce407e"
    },
    "builder_path" => "scripts/build-source-inventory.rb",
    "builder_digest" => "sha256:#{Digest::SHA256.file(File.join(ROOT, 'scripts/build-source-inventory.rb')).hexdigest}",
    "rendered_catalog_projection_digest" => "sha256:2e78f80cd4dc4db6c5686464844843316911e0b3dff20df2271bd1d0db652102",
    "source_inventory_path" => evidence.fetch("source_inventory_path"),
    "source_inventory_digest" => evidence_digests.fetch("source_inventory_path"),
    "source_build_path" => evidence.fetch("source_build_path"),
    "source_build_digest" => evidence_digests.fetch("source_build_path"),
    "candidate_manifest_path" => evidence.fetch("candidate_manifest_path"),
    "candidate_manifest_digest" => evidence_digests.fetch("candidate_manifest_path"),
    "candidate_statuses" => ["unreviewed"],
    "automatic_promotion" => false
  }]
}

output = Psych.dump(document, nil, line_width: -1)
if options[:stdout]
  $stdout.write(output)
else
  File.binwrite(options[:output], output)
  puts "wrote #{options[:output]} (#{entries.length} audited components, source candidates remain unreviewed)"
end
