#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "set"
require "digest"

ROOT = File.expand_path("..", __dir__)
CATALOG_PATH = File.join(__dir__, "catalog.yml")
ROUTE_DIR = File.join(__dir__, "routes")
GATES_PATH = File.join(__dir__, "gates.yml")
VERSIONS_PATH = File.join(ROOT, "versions", "registry.yml")

errors = []

load_yaml = lambda do |path|
  YAML.safe_load(File.read(path, encoding: "UTF-8"), aliases: false)
rescue StandardError => e
  errors << "#{path.delete_prefix(ROOT + "/")}: YAML load failed: #{e.message}"
  nil
end

catalog = load_yaml.call(CATALOG_PATH)
versions = load_yaml.call(VERSIONS_PATH)
abort(errors.join("\n")) unless catalog && versions

chapters = catalog.fetch("chapters")
ids = chapters.map { |chapter| chapter["id"] }
known = ids.to_set
by_id = chapters.to_h { |chapter| [chapter.fetch("id"), chapter] }
version_ids = versions.fetch("entries").map { |entry| entry.fetch("id") }.to_set

required_fields = %w[id title volume order level prerequisites recommended_after outcomes status route_tags stable_core versioned_surface teaches_capabilities uses_capabilities path]
allowed_levels = %w[L1 L2 L2+ L3 L1-L2]
allowed_statuses = %w[planned drafting review verified]
phase_statuses = {
  "architecture" => %w[planned],
  "authoring" => allowed_statuses,
  "release-candidate" => %w[review verified],
  "published" => %w[verified]
}.freeze
expected_volumes = (0..15).map { |number| format("%02d", number) }

errors << "catalog_id must remain factorycare-encyclopedia" unless catalog["catalog_id"] == "factorycare-encyclopedia"
errors << "edition must remain 2026.1-draft" unless catalog["edition"] == "2026.1-draft"
errors << "catalog must be canonical" unless catalog["canonical"] == true
catalog_phase = catalog["status"]
allowed_for_phase = phase_statuses[catalog_phase]
errors << "invalid catalog phase #{catalog_phase.inspect}" unless allowed_for_phase
errors << "chapter count #{chapters.length} is outside 140..170" unless (140..170).cover?(chapters.length)

duplicate_ids = ids.each_with_object(Hash.new(0)) { |id, counts| counts[id] += 1 }.select { |_id, count| count > 1 }
errors << "duplicate chapter ids: #{duplicate_ids.keys.join(", ")}" unless duplicate_ids.empty?

paths = []
outcome_fingerprints = []
chapters.each_with_index do |chapter, index|
  id = chapter["id"] || "chapter-#{index + 1}"
  missing = required_fields.reject { |field| chapter.key?(field) }
  errors << "#{id}: missing fields #{missing.join(", ")}" unless missing.empty?
  next unless missing.empty?

  errors << "#{id}: invalid stable id" unless id.match?(/\Av\d{2}\.c\d{2}\.[a-z0-9-]+\z/)
  errors << "#{id}: id volume differs from volume field" unless id[1, 2] == chapter["volume"]
  errors << "#{id}: invalid level #{chapter["level"]}" unless allowed_levels.include?(chapter["level"])
  errors << "#{id}: invalid status #{chapter["status"]}" unless allowed_statuses.include?(chapter["status"])
  if allowed_for_phase && !allowed_for_phase.include?(chapter["status"])
    errors << "#{id}: status #{chapter["status"]} is not allowed while catalog phase is #{catalog_phase}"
  end
  errors << "#{id}: order must be a positive integer" unless chapter["order"].is_a?(Integer) && chapter["order"].positive?
  errors << "#{id}: stable_core must be boolean" unless [true, false].include?(chapter["stable_core"])

  %w[prerequisites recommended_after route_tags versioned_surface teaches_capabilities uses_capabilities].each do |field|
    value = chapter[field]
    errors << "#{id}: #{field} must be an array" unless value.is_a?(Array)
    errors << "#{id}: #{field} contains duplicates" if value.is_a?(Array) && value.uniq.length != value.length
  end

  outcomes = chapter["outcomes"]
  if !outcomes.is_a?(Array) || outcomes.length != 3 || outcomes.any? { |outcome| !outcome.is_a?(String) || outcome.strip.empty? }
    errors << "#{id}: outcomes must be exactly three non-empty strings"
  else
    errors << "#{id}: concept outcome must be time-bounded and state a boundary" unless outcomes[0].include?("120 秒内") && outcomes[0].include?("边界")
    errors << "#{id}: artifact outcome must require independent work and reproducible evidence" unless outcomes[1].start_with?("独立") && outcomes[1].include?("保存源码、命令")
    errors << "#{id}: diagnosis outcome must require injected failure, first evidence, fix, and rerun" unless outcomes[2].include?("面对注入的故障") && outcomes[2].include?("失败阶段、首个可信证据") && outcomes[2].include?("重跑原验证")
    forbidden = ["解释核心模型", "完成本章最小实验", "了解本章", "掌握本章"]
    forbidden.each { |phrase| errors << "#{id}: generic outcome phrase #{phrase}" if outcomes.any? { |text| text.include?(phrase) } }
    outcome_fingerprints << Digest::SHA256.hexdigest(outcomes.join("\0"))
  end

  unknown_versions = chapter["versioned_surface"].reject { |version| version_ids.include?(version) }
  errors << "#{id}: unknown version ids #{unknown_versions.join(", ")}" unless unknown_versions.empty?
  path = chapter["path"]
  errors << "#{id}: path must stay in book/ and end in #{id}.md" unless path.is_a?(String) && path.start_with?("book/") && path.end_with?("/#{id}.md")
  paths << path
end

errors << "chapter paths must be unique" unless paths.uniq.length == paths.length
errors << "all chapter outcome triples must be chapter-specific" unless outcome_fingerprints.uniq.length == chapters.length

actual_volumes = chapters.map { |chapter| chapter.fetch("volume") }.uniq.sort
errors << "volumes mismatch: expected #{expected_volumes.inspect}, got #{actual_volumes.inspect}" unless actual_volumes == expected_volumes
volume_counts = {}
expected_volumes.each do |volume|
  volume_chapters = chapters.select { |chapter| chapter["volume"] == volume }
  volume_counts[volume] = volume_chapters.length
  errors << "volume #{volume}: chapter count must be 6..15, got #{volume_chapters.length}" unless (6..15).cover?(volume_chapters.length)
  orders = volume_chapters.map { |chapter| chapter.fetch("order") }.sort
  errors << "volume #{volume}: orders must be continuous 1..N, got #{orders.inspect}" unless orders == (1..volume_chapters.length).to_a
end
errors << "volume counts must reflect subject scope; exact-count template detected" if volume_counts.values.uniq.length == 1
catalog_order = chapters.map { |chapter| [chapter.fetch("volume"), chapter.fetch("order")] }
errors << "catalog chapters must be sorted by volume and order" unless catalog_order == catalog_order.sort

%w[prerequisites recommended_after].each do |field|
  chapters.each do |chapter|
    chapter.fetch(field).each do |dependency|
      errors << "#{chapter["id"]}: unknown #{field} #{dependency}" unless known.include?(dependency)
      errors << "#{chapter["id"]}: self reference in #{field}" if dependency == chapter["id"]
    end
  end
end

recommended_edges = chapters.sum { |chapter| chapter.fetch("recommended_after").length }
chapters.each do |chapter|
  recommended = chapter.fetch("recommended_after")
  if chapter.fetch("order") == 1
    errors << "#{chapter["id"]}: first chapter in volume must not have recommended_after" unless recommended.empty?
  else
    expected_previous = chapters.find { |candidate| candidate["volume"] == chapter["volume"] && candidate["order"] == chapter["order"] - 1 }
    errors << "#{chapter["id"]}: recommended_after must identify the prior in-volume reading chapter" unless recommended == [expected_previous&.fetch("id")]
  end
end

cycle_check = lambda do |field|
  visiting = Set.new
  visited = Set.new
  visit = nil
  visit = lambda do |id, trail|
    if visiting.include?(id)
      errors << "#{field} cycle: #{(trail + [id]).join(" -> ")}"
      return
    end
    return if visited.include?(id)
    visiting << id
    by_id.fetch(id).fetch(field).each { |dep| visit.call(dep, trail + [id]) if known.include?(dep) }
    visiting.delete(id)
    visited << id
  end
  ids.each { |id| visit.call(id, []) }
  visited.length
end
hard_nodes = cycle_check.call("prerequisites")
cycle_check.call("recommended_after")
hard_cycle_present = errors.any? { |error| error.start_with?("prerequisites cycle:") }

ancestor_memo = {}
ancestors = nil
ancestors = lambda do |id|
  return Set.new if hard_cycle_present
  return ancestor_memo[id] if ancestor_memo.key?(id)
  ancestor_memo[id] = Set.new
  by_id.fetch(id).fetch("prerequisites").each do |dep|
    next unless known.include?(dep)
    ancestor_memo[id] << dep
    ancestor_memo[id].merge(ancestors.call(dep))
  end
  ancestor_memo[id]
end

depth_memo = {}
depth = nil
depth = lambda do |id|
  return 0 if hard_cycle_present
  return depth_memo[id] if depth_memo.key?(id)
  dependencies = by_id.fetch(id).fetch("prerequisites").select { |dep| known.include?(dep) }
  depth_memo[id] = dependencies.empty? ? 1 : 1 + dependencies.map { |dep| depth.call(dep) }.max
end

hard_edges = chapters.sum { |chapter| chapter.fetch("prerequisites").length }
hard_roots = chapters.count { |chapter| chapter.fetch("prerequisites").empty? }
longest_chain = hard_cycle_present ? 0 : ids.map { |id| depth.call(id) }.max
indegree_one_ratio = chapters.count { |chapter| chapter.fetch("prerequisites").length == 1 }.fdiv(chapters.length)
errors << "hard prerequisite graph regressed to a single root" if hard_roots < 3
errors << "hard prerequisite graph is too dense for a prerequisite graph" if hard_edges > chapters.length * 3
errors << "hard prerequisite graph still behaves like a mechanical chain" if indegree_one_ratio > 0.80 || longest_chain > 40
errors << "recommended-order mechanism is incomplete" if recommended_edges != chapters.length - expected_volumes.length

critical_edges = {
  "v05.c08.services-transactions-aop"=>%w[v04.c09.transactions-locks v03.c12.java-testing-mocking],
  "v14.c06.retrieval-rerank"=>%w[v04.c01.relational-model v04.c08.indexes-explain],
  "v10.c03.network-auth-storage"=>%w[v06.c01.auth-session-password v06.c02.web-security-threats],
  "v15.c09.deployment-rollback-incident"=>%w[v04.c10.migration-jdbc-mybatis],
  "v09.c01.vite-sfc-app"=>%w[v07.c05.css-cascade v07.c06.box-position-stacking]
}
critical_edges.each do |consumer, required|
  missing = required - by_id.fetch(consumer).fetch("prerequisites")
  errors << "#{consumer}: missing adjudicated hard prerequisites #{missing.join(", ")}" unless missing.empty?
end

network_id = "v03.c11.java-networking"
network_terms = %w[InetAddress TCP UDP Socket ServerSocket Datagram URL]
unless known.include?(network_id)
  errors << "canonical Java networking chapter is missing"
else
  missing_terms = network_terms.reject { |term| by_id.fetch(network_id).fetch("title").include?(term) }
  errors << "#{network_id}: missing canonical networking terms #{missing_terms.join(", ")}" unless missing_terms.empty?
end
%w[v00.c11.docker-foundations v00.c12.ai-collaboration-verification v04.c11.jdbc-pool-mybatis v11.c11.flutter-network-storage v11.c12.flutter-device-apis v11.c13.flutter-testing-performance-release v15.c11.portfolio-interview].each do |id|
  errors << "missing scope-splitting chapter #{id}" unless known.include?(id)
end

capability_teachers = Hash.new { |hash, key| hash[key] = [] }
chapters.each { |chapter| chapter.fetch("teaches_capabilities").each { |capability| capability_teachers[capability] << chapter.fetch("id") } }
used_capabilities = chapters.flat_map { |chapter| chapter.fetch("uses_capabilities") }.to_set
required_capabilities = %w[terminal git http build-tool-basics docker psql database-transactions db-indexing db-migrations devtools css-cascade css-box-model node pnpm esm tsc tsconfig auth-foundations web-threat-model dart-cli pubspec uv numpy pandas linear-algebra probability-statistics gradients java-io].to_set
errors << "capability set missing #{(required_capabilities - capability_teachers.keys.to_set).to_a.join(", ")}" unless required_capabilities.subset?(capability_teachers.keys.to_set)
(capability_teachers.keys.to_set - used_capabilities).each { |capability| errors << "capability #{capability} is taught but never used" }
used_capabilities.each do |capability|
  teachers = capability_teachers[capability]
  errors << "capability #{capability} must have exactly one teaching chapter, got #{teachers.inspect}" unless teachers.length == 1
end
chapters.each do |chapter|
  chapter.fetch("uses_capabilities").each do |capability|
    teacher = capability_teachers[capability]&.first
    next unless teacher
    errors << "#{chapter["id"]}: hidden prerequisite #{capability} is not reachable from hard prerequisites (teacher #{teacher})" unless ancestors.call(chapter.fetch("id")).include?(teacher)
  end
end

required_version_mappings = {
  "v03.c12.java-testing-mocking"=>%w[junit-6 mockito],
  "v05.c10.testing-openapi-actuator"=>%w[testcontainers openapi],
  "v06.c09.events-outbox-messaging"=>%w[rabbitmq],
  "v09.c09.testing-a11y-performance"=>%w[vitest playwright],
  "v12.c07.typing-testing-logging"=>%w[pytest],
  "v12.c09.fastapi-pydantic"=>%w[pydantic-2 pytest],
  "v14.c06.retrieval-rerank"=>%w[pgvector]
}
required_version_mappings.each do |id, required|
  missing = required - by_id.fetch(id).fetch("versioned_surface")
  errors << "#{id}: missing required version mappings #{missing.join(", ")}" unless missing.empty?
end

route_files = Dir.glob(File.join(ROUTE_DIR, "*.yml")).sort
routes = route_files.map { |path| load_yaml.call(path) }.compact
route_by_id = routes.to_h { |route| [route.fetch("route_id"), route] }
expected_routes = %w[accelerated-48 factorycare-project reference zero-base]
errors << "route set mismatch" unless route_by_id.keys.sort == expected_routes.sort

ordered_sequence_check = lambda do |route_id, sequence, require_recommended|
  unknown = sequence.reject { |id| known.include?(id) }
  errors << "#{route_id}: unknown chapter ids #{unknown.uniq.join(", ")}" unless unknown.empty?
  duplicates = sequence.each_with_object(Hash.new(0)) { |id, counts| counts[id] += 1 }.select { |_id, count| count > 1 }
  errors << "#{route_id}: duplicate chapter ids #{duplicates.keys.join(", ")}" unless duplicates.empty?
  seen = Set.new
  sequence.each do |id|
    next unless known.include?(id)
    missing_hard = by_id.fetch(id).fetch("prerequisites").reject { |dep| seen.include?(dep) }
    errors << "#{route_id}: #{id} precedes hard prerequisites #{missing_hard.join(", ")}" unless missing_hard.empty?
    if require_recommended
      missing_soft = by_id.fetch(id).fetch("recommended_after").reject { |dep| seen.include?(dep) }
      errors << "#{route_id}: #{id} violates recommended reading order #{missing_soft.join(", ")}" unless missing_soft.empty?
    end
    seen << id
  end
  errors << "#{route_id}: complete ordered route must cover all chapters" unless sequence.to_set == known
end

zero_sequence = []
if (route = route_by_id["zero-base"])
  errors << "zero-base: wrong route_kind" unless route["route_kind"] == "zero-base"
  errors << "zero-base: must be complete ordered-learning" unless route["coverage"] == "complete" && route["navigation_semantics"] == "ordered-learning"
  units = route["units"]
  errors << "zero-base: units must be an array" unless units.is_a?(Array)
  zero_sequence = units.to_a.flat_map { |unit| unit.fetch("chapter_ids") }
  ordered_sequence_check.call("zero-base", zero_sequence, true)
  errors << "zero-base: unit ids must be unique" unless units.to_a.map { |unit| unit["id"] }.uniq.length == units.to_a.length
  expected_stage_gates = {"z-v00"=>"G0", "z-v03"=>"G1", "z-v05"=>"G2", "z-v06"=>"G3", "z-v09"=>"G4", "z-v11"=>"G5", "z-v14"=>"G6", "z-v15"=>"G7"}
  actual_stage_gates = units.to_a.select { |unit| unit.key?("stage_gate_id") }.to_h { |unit| [unit["id"], unit["stage_gate_id"]] }
  errors << "zero-base: stage gate boundaries must align with G0..G7" unless actual_stage_gates == expected_stage_gates
  errors << "zero-base: final unit must reference G8" unless units.to_a.last&.fetch("final_gate_id", nil) == "G8"
end

accelerated_sequence = []
if (route = route_by_id["accelerated-48"])
  errors << "accelerated-48: wrong route_kind" unless route["route_kind"] == "accelerated"
  modules = route["modules"]
  errors << "accelerated-48: must declare exactly 48 modules" unless route["module_count"] == 48 && modules.is_a?(Array) && modules.length == 48
  modules.to_a.each do |mod|
    mid = mod["id"]
    chapter_ids = mod["chapter_ids"].to_a
    partition = mod["teach_chapter_ids"].to_a + mod["diagnostic_chapter_ids"].to_a
    errors << "accelerated-48 #{mid}: teach/diagnostic must partition chapter_ids" unless partition.to_set == chapter_ids.to_set && partition.length == chapter_ids.length
    errors << "accelerated-48 #{mid}: refresh must cover module chapters" unless mod["refresh_chapter_ids"].to_a.to_set == chapter_ids.to_set
    diagnostic = mod["diagnostic"].to_h
    errors << "accelerated-48 #{mid}: diagnostic contract incomplete" unless diagnostic["assessment_id"]&.start_with?("diag-") && diagnostic["assessment_path"]&.start_with?("assessments/accelerated/") && diagnostic["pass_threshold"].to_i >= 80 && diagnostic["valid_for_days"].to_i.positive?
    waiver = mod["waiver"].to_h
    errors << "accelerated-48 #{mid}: waiver must only waive instruction and require three evidence kinds" unless waiver["allowed"] == true && waiver["scope"] == "instruction-only" && waiver["required_evidence"].to_a.length >= 3 && waiver["evidence_path"]&.start_with?("evidence/")
    errors << "accelerated-48 #{mid}: completion evidence incomplete" unless mod["completion_evidence_paths"].to_a.length >= 3
    remediation = mod["remediation"].to_h
    errors << "accelerated-48 #{mid}: remediation must name chapters and plan" unless remediation["chapter_ids"].to_a.to_set == chapter_ids.to_set && remediation["plan_path"]&.start_with?("assessments/")
    retest = mod["retest"].to_h
    errors << "accelerated-48 #{mid}: retest must be delayed, new-variant, bounded and evidenced" unless retest["new_variant"] == true && retest["delay_hours"].to_i >= 24 && retest["max_attempts"].to_i == 2 && retest["assessment_id"]&.start_with?("retest-") && retest["evidence_path"]&.start_with?("evidence/")
  end
  accelerated_sequence = modules.to_a.flat_map { |mod| mod.fetch("chapter_ids") }
  ordered_sequence_check.call("accelerated-48", accelerated_sequence, false)
end
errors << "zero-base and accelerated routes must not expand to the same sequence" if !zero_sequence.empty? && zero_sequence == accelerated_sequence

factory_ids = Set.new
if (route = route_by_id["factorycare-project"])
  errors << "factorycare-project: wrong route_kind/coverage" unless route["route_kind"] == "project" && route["coverage"] == "selective"
  stages = route["stages"].to_a
  expected_stage_ids = %w[fc-01-foundation fc-02-users fc-03-devices fc-04-work-orders fc-05-sla-events fc-06-multiclient fc-07-ai fc-08-deploy]
  errors << "factorycare-project: business vertical stages mismatch" unless stages.map { |stage| stage["id"] } == expected_stage_ids
  cumulative = Set.new
  primary_seen = Set.new
  stages.each do |stage|
    sid = stage["id"]
    primary = stage["primary_chapter_ids"].to_a
    support = stage["supporting_chapter_ids"].to_a
    errors << "factorycare-project #{sid}: primary/support overlap" unless (primary.to_set & support.to_set).empty?
    repeated_primary = primary.select { |id| primary_seen.include?(id) }
    errors << "factorycare-project #{sid}: repeated primary ids #{repeated_primary.join(", ")}" unless repeated_primary.empty?
    primary_seen.merge(primary)
    stage_ids = (primary + support).to_set
    unknown = stage_ids.reject { |id| known.include?(id) }
    errors << "factorycare-project #{sid}: unknown chapters #{unknown.to_a.join(", ")}" unless unknown.empty?
    available = cumulative | stage_ids
    stage_ids.each do |id|
      next unless known.include?(id)
      missing = by_id.fetch(id).fetch("prerequisites").reject { |dep| available.include?(dep) }
      errors << "factorycare-project #{sid}: #{id} lacks cumulative hard prerequisites #{missing.join(", ")}" unless missing.empty?
    end
    cumulative.merge(stage_ids)
    factory_ids.merge(stage_ids)
    artifacts = stage["project_artifacts"].to_a
    errors << "factorycare-project #{sid}: needs at least two accepted project artifacts" unless artifacts.length >= 2 && artifacts.all? { |a| a["id"] && a["path"]&.start_with?("evidence/factorycare/") && a["acceptance"]&.length.to_i >= 15 }
    errors << "factorycare-project #{sid}: evidence paths incomplete" unless stage["evidence_paths"].to_a.length >= 3
    errors << "factorycare-project #{sid}: missing stage gate id" unless stage["stage_gate_id"]&.match?(/\Afc-stage-\d{2}\z/)
  end
  errors << "factorycare-project must remain selective, not copy the complete catalog" unless factory_ids.length < chapters.length
end

if (route = route_by_id["reference"])
  errors << "reference: wrong non-linear semantics" unless route["route_kind"] == "reference" && route["coverage"] == "generated-complete" && route["navigation_semantics"] == "non-linear-index"
  errors << "reference: must not contain ordered units or modules" if route.key?("units") || route.key?("modules")
  index = route["chapter_index"].to_h
  errors << "reference: chapter index must cover catalog exactly" unless index.keys.to_set == known
  errors << "reference: index paths must match catalog" unless index.all? { |id, entry| by_id[id] && entry["path"] == by_id[id]["path"] }
  expected_facets = %w[concept error command api version factorycare].to_set
  errors << "reference: query facets mismatch" unless route["facets"].to_a.map { |facet| facet["id"] }.to_set == expected_facets
end

chapters.each do |chapter|
  expected_tags = %w[zero-base accelerated-48 reference]
  expected_tags << "factorycare-project" if factory_ids.include?(chapter.fetch("id"))
  errors << "#{chapter["id"]}: route_tags drift from route ownership" unless chapter.fetch("route_tags") == expected_tags
end

gates_doc = load_yaml.call(GATES_PATH)
if gates_doc
  gates = gates_doc.fetch("gates")
  expected_gate_ids = (0..8).map { |n| "G#{n}" }
  errors << "stage gate ids must be canonical G0..G8" unless gates.map { |gate| gate["id"] } == expected_gate_ids
  errors << "gates must cite ASSESSMENTS.md and PROGRESS.md" unless gates_doc["canonical_source"]&.include?("ASSESSMENTS.md") && gates_doc["canonical_source"]&.include?("PROGRESS.md")
  assessment_ids = []
  artifact_ids = []
  artifact_paths = []
  evidence_stores = []
  rubric_hashes = []
  expected_gate_volumes = {"G0"=>%w[00],"G1"=>%w[01 02 03],"G2"=>%w[04 05],"G3"=>%w[06],"G4"=>%w[07 08 09],"G5"=>%w[10 11],"G6"=>%w[12 13 14],"G7"=>%w[15],"G8"=>expected_volumes}
  gates.each_with_index do |gate, index|
    gid = gate["id"]
    expected_prereq = index.zero? ? [] : ["G#{index - 1}"]
    errors << "#{gid}: prerequisite gate chain mismatch" unless gate["prerequisite_gate_ids"] == expected_prereq
    assessment = gate["assessment"].to_h
    assessment_ids << assessment["id"]
    errors << "#{gid}: assessment id/path/mode incomplete" unless assessment["id"]&.match?(/\Aassessment-g[0-8]\z/) && assessment["path"]&.start_with?("ASSESSMENTS.md#") && assessment["mode"]
    gate_volumes = expected_gate_volumes.fetch(gid, [])
    expected_chapters = gate_volumes.flat_map { |volume| chapters.select { |chapter| chapter["volume"] == volume }.map { |chapter| chapter["id"] } }
    expected_chapters -= ["v00.c11.docker-foundations"] if gid == "G0" # G0 explicitly does not require all optional toolchains to be installed.
    expected_chapters = expected_chapters.take_while { |id| id != "v15.c10.system-design-portfolio" } if gid == "G7" # G7 ends at production drills; final design/portfolio belongs to G8.
    errors << "#{gid}: required chapters do not match canonical stage volumes" unless gate["required_chapter_ids"].to_a == expected_chapters
    artifacts = gate["required_artifacts"].to_a
    errors << "#{gid}: requires two distinct accepted artifacts" unless artifacts.length >= 2 && artifacts.all? { |a| a["id"] && a["path"]&.start_with?("evidence/gates/") && a["acceptance"]&.length.to_i >= 20 }
    artifact_ids.concat(artifacts.map { |a| a["id"] })
    artifact_paths.concat(artifacts.map { |a| a["path"] })
    errors << "#{gid}: mandatory evidence paths incomplete" unless gate["mandatory_evidence_paths"].to_a.length >= 4 && gate["mandatory_evidence_paths"].all? { |path| path.start_with?("evidence/gates/") }
    errors << "#{gid}: critical failures incomplete" unless %w[fabricated-evidence secret-exposure cross-tenant-access data-loss-without-recovery].all? { |failure| gate["critical_failures"].to_a.include?(failure) }
    rubric = gate["rubric"].to_h
    dimensions = rubric["dimensions"].to_a
    errors << "#{gid}: rubric must contain four volume/stage-specific dimensions" unless dimensions.length == 4 && dimensions.map { |d| d["id"] }.uniq.length == 4 && dimensions.sum { |d| d["weight"].to_i } == 100 && dimensions.all? { |d| d["criterion"]&.length.to_i >= 8 }
    thresholds = rubric["thresholds"].to_h
    expected_thresholds = gate["level"] == "L3" ? [85, 80] : [80, 75]
    errors << "#{gid}: depth threshold mismatch" unless [thresholds["min_total"], thresholds["min_critical_dimension"]] == expected_thresholds
    rubric_hashes << Digest::SHA256.hexdigest(dimensions.map { |d| d["criterion"] }.join("\0"))
    retest = gate["retest"].to_h
    errors << "#{gid}: retest must be narrow, delayed, new-variant, bounded and evidenced" unless retest["scope"] == "failed-claims-only" && retest["delay_hours"].to_i >= 24 && retest["new_variant"] == true && retest["max_attempts"] == 2 && retest["remediation_path"]&.start_with?("evidence/gates/") && retest["evidence_path"]&.start_with?("evidence/gates/")
    errors << "#{gid}: evidence_store missing" unless gate["evidence_store"]&.start_with?("evidence/gates/")
    evidence_stores << gate["evidence_store"]
  end
  errors << "gate assessment ids must be unique" unless assessment_ids.compact.uniq.length == gates.length
  errors << "gate artifact ids must be unique" unless artifact_ids.uniq.length == artifact_ids.length
  errors << "gate artifact paths must be unique" unless artifact_paths.uniq.length == artifact_paths.length
  errors << "gate evidence stores must be unique" unless evidence_stores.uniq.length == gates.length
  errors << "gate rubrics must not be copied templates" unless rubric_hashes.uniq.length == gates.length

  assessments = File.read(File.join(ROOT, "ASSESSMENTS.md"), encoding: "UTF-8")
  progress = File.read(File.join(ROOT, "PROGRESS.md"), encoding: "UTF-8")
  expected_gate_ids.each do |gid|
    errors << "#{gid}: missing from ASSESSMENTS.md" unless assessments.include?("阶段门 #{gid}") || assessments.include?("最终考核 #{gid}")
    errors << "#{gid}: missing from PROGRESS.md" unless progress.include?("| #{gid} ")
  end
end

chapters.each do |chapter|
  chapter_path = File.join(ROOT, chapter.fetch("path"))
  unless File.file?(chapter_path)
    errors << "#{chapter["id"]}: missing chapter file #{chapter["path"]}"
    next
  end
  body = File.read(chapter_path, encoding: "UTF-8")
  match = body.match(/\A---\s*\n(.*?)\n---\s*\n/m)
  unless match
    errors << "#{chapter["id"]}: missing YAML front matter"
    next
  end
  metadata = YAML.safe_load(match[1], aliases: false)
  %w[id title volume order level status].each do |field|
    errors << "#{chapter["id"]}: placeholder #{field} differs from catalog" unless metadata[field] == chapter[field]
  end
  absent_statement = body.include?("尚无教材正文") || body.include?("尚未包含教材正文")
  if chapter["status"] == "planned"
    errors << "#{chapter["id"]}: planned placeholder must honestly state that正文 is absent" unless absent_statement && body.include?("不能作为")
  elsif absent_statement
    errors << "#{chapter["id"]}: #{chapter["status"]} chapter must not retain planned-placeholder text"
  end
end

chapter_files = Dir.glob(File.join(ROOT, "book", "volume-*", "chapters", "*.md"))
errors << "chapter placeholder count differs from catalog: files=#{chapter_files.length}, catalog=#{chapters.length}" unless chapter_files.length == chapters.length

expected_volumes.each do |volume|
  volume_chapters = chapters.select { |chapter| chapter.fetch("volume") == volume }
  readmes = Dir.glob(File.join(ROOT, "book", "volume-#{volume}-*", "README.md"))
  if readmes.length != 1
    errors << "volume #{volume}: expected one README, got #{readmes.length}"
    next
  end
  body = File.read(readmes.first, encoding: "UTF-8")
  volume_chapters.each { |chapter| errors << "volume #{volume} README missing #{chapter["id"]}" unless body.include?(chapter["id"]) }
end

Dir.glob(File.join(ROOT, "{book,curriculum}", "**", "*.md")).sort.each do |markdown_path|
  body = File.read(markdown_path, encoding: "UTF-8")
  body.scan(/\[[^\]]*\]\(([^)]+)\)/).flatten.each do |target|
    next if target.match?(%r{\A(?:https?://|mailto:|#)})
    clean_target = target.split("#", 2).first
    resolved = File.expand_path(clean_target, File.dirname(markdown_path))
    errors << "#{markdown_path.delete_prefix(ROOT + "/")}: broken local link #{target}" unless File.exist?(resolved)
  end
end

Dir.glob(File.join(ROOT, "{book,curriculum}", "**", "*.{md,yml,rb}")).sort.each do |path|
  body = File.read(path, encoding: "UTF-8")
  relative = path.delete_prefix(ROOT + "/")
  errors << "#{relative}: missing final newline" unless body.end_with?("\n")
  body.lines.each_with_index { |line, index| errors << "#{relative}:#{index + 1}: trailing whitespace" if line.match?(/[ \t]+(?:\r?\n)?\z/) }
end

if errors.empty?
  puts "CATALOG VALID"
  puts "catalog_id=#{catalog.fetch("catalog_id")} edition=#{catalog.fetch("edition")} phase=#{catalog_phase}"
  puts "chapters=#{chapters.length} volumes=#{actual_volumes.length} volume_counts=#{volume_counts.values.join(",")}"
  puts "hard_nodes=#{hard_nodes} hard_edges=#{hard_edges} hard_roots=#{hard_roots} longest_hard_chain=#{longest_chain} indegree_one_ratio=#{format("%.3f", indegree_one_ratio)}"
  puts "recommended_edges=#{recommended_edges} capability_contracts=#{capability_teachers.length} hidden_first_use_failures=0"
  puts "version_registry_ids=#{version_ids.length} referenced_versions=#{chapters.flat_map { |chapter| chapter.fetch("versioned_surface") }.uniq.length} unknown_version_refs=0"
  puts "route=zero-base chapters=#{zero_sequence.length} semantics=ordered-learning"
  puts "route=accelerated-48 modules=48 chapters=#{accelerated_sequence.length} semantics=ordered-with-evidence-waivers"
  puts "route=factorycare-project stages=8 chapters=#{factory_ids.length} semantics=selective-business-verticals"
  puts "route=reference chapters=#{known.length} semantics=non-linear-index"
  planned_count = chapters.count { |chapter| chapter["status"] == "planned" }
  puts "routes_same_sequence=false gates=9 gate_ids=G0..G8 chapter_files=#{chapter_files.length} planned=#{planned_count}"
  exit 0
end

warn "CATALOG INVALID (#{errors.length} error(s))"
errors.each { |error| warn "- #{error}" }
exit 1
