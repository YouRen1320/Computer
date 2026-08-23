# frozen_string_literal: true

require_relative "contract_model"

device = {
  "id" => "DEV-001",
  "display_name" => "一号循环泵",
  "status" => "ACTIVE",
  "location" => "A-01"
}

v1 = ApiContractLab.device_representation(device, version: "v1")
v1_1 = ApiContractLab.device_representation(device, version: "v1.1")
broken = ApiContractLab.broken_v2_representation(device)
abort "api-contract verification: FAIL: additive version rejected" unless ApiContractLab.compatible_addition?(v1, v1_1)
abort "api-contract verification: FAIL: breaking rename accepted" if ApiContractLab.compatible_addition?(v1, broken)

internal = RuntimeError.new("SQL password=not-a-real-secret at InternalRepo:42")
public_problem = ApiContractLab.unknown_internal_problem(instance: "/problems/INC-001")
serialized_problem = JSON.generate(public_problem)
abort "api-contract verification: FAIL: unstable Problem shape" unless public_problem.keys == %w[type title status detail instance code]
leak_markers = [internal.message, internal.class.name, "InternalRepo"]
abort "api-contract verification: FAIL: internal detail leaked" if leak_markers.any? { |marker| serialized_problem.include?(marker) }

rows = [
  { "id" => "A", "createdAt" => "2026-07-16T08:00:00Z" },
  { "id" => "B", "createdAt" => "2026-07-16T09:00:00Z" },
  { "id" => "C", "createdAt" => "2026-07-16T10:00:00Z" },
  { "id" => "D", "createdAt" => "2026-07-16T11:00:00Z" }
]
pager = ApiContractLab::CursorPager.new(rows)
first = pager.cursor_page(limit: 2)
abort "api-contract verification: FAIL: first cursor page" unless first.fetch("items").map { |row| row.fetch("id") } == %w[D C]

pager.insert("id" => "E", "createdAt" => "2026-07-16T12:00:00Z")
drifted = pager.offset_page(offset: 2, limit: 2).map { |row| row.fetch("id") }
abort "api-contract verification: FAIL: offset drift was not exposed" unless drifted == %w[C B]
second = pager.cursor_page(after: first.fetch("nextCursor"), limit: 2)
abort "api-contract verification: FAIL: cursor page repeated an item" unless second.fetch("items").map { |row| row.fetch("id") } == %w[B A]
last_cursor = pager.cursor_for(second.fetch("items").last)
empty = pager.cursor_page(after: last_cursor, limit: 2)
abort "api-contract verification: FAIL: empty final page" unless empty == { "items" => [], "nextCursor" => nil }
invalid = pager.cursor_page(after: "not-base64", limit: 2)
abort "api-contract verification: FAIL: invalid cursor Problem" unless invalid.dig("problem", "code") == "invalid-cursor"

cache = ApiContractLab::CacheContract.new(device)
fresh = cache.get
not_modified = cache.get(if_none_match: fresh.fetch("headers").fetch("ETag"))
abort "api-contract verification: FAIL: cache miss" unless fresh.fetch("status") == 200 && fresh.fetch("body")
abort "api-contract verification: FAIL: cache validator" unless not_modified == {
  "status" => 304,
  "headers" => { "ETag" => fresh.fetch("headers").fetch("ETag") },
  "body" => nil
}

payload = { "deviceId" => "DEV-001", "summary" => "轴承温度过高" }
unsafe = ApiContractLab::WorkOrderCreator.new
unsafe_first = unsafe.unsafe_create(payload)
unsafe_second = unsafe.unsafe_create(payload)
abort "api-contract verification: FAIL: duplicate-risk fixture" if unsafe_first.fetch("id") == unsafe_second.fetch("id")

safe = ApiContractLab::WorkOrderCreator.new
created = safe.create(payload, idempotency_key: "demo-operation-001")
replayed = safe.create(payload, idempotency_key: "demo-operation-001")
abort "api-contract verification: FAIL: idempotent replay created a duplicate" unless safe.records.length == 1
abort "api-contract verification: FAIL: replay result changed identity" unless created.dig("body", "id") == replayed.dig("body", "id") && replayed.dig("body", "replayed")
conflict = safe.create(payload.merge("summary" => "不同故障"), idempotency_key: "demo-operation-001")
abort "api-contract verification: FAIL: key conflict not rejected" unless conflict.fetch("status") == 409 && safe.records.length == 1

puts "resource/version: v1 stable; additive v1.1 accepted; field rename rejected"
puts "error: unknown internal exception mapped to stable, non-leaking Problem"
puts "pagination: offset duplicate C exposed; cursor pages D,C then B,A; final page empty"
puts "cache: 200 with ETag -> matching validator gives 304 with no body"
puts "idempotency: unsafe retry duplicated; stable key replayed one FC identity; changed payload got 409"
puts "api-contract-basics verification: PASS"
