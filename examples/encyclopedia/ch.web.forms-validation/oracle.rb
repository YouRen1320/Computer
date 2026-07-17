#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html = File.read("report-form.html", encoding: "UTF-8")
matrix = JSON.parse(File.read("submission-matrix.json", encoding: "UTF-8"))
errors = []

def attribute(tag, name)
  match = tag.to_s.match(/\b#{Regexp.escape(name)}\s*=\s*(["'])(.*?)\1/im)
  match && match[2]
end

def opening_tag(html, id)
  html.scan(/<(?:input|select|textarea|button)\b[^>]*>/im).find { |tag| attribute(tag, "id") == id }
end

form = html[/<form\b[^>]*>/i]
errors << "teaching form is missing" unless form
if form
  errors << "form action drifted" unless attribute(form, "action") == "/teaching/report-submissions"
  errors << "form method must be post" unless attribute(form, "method")&.casecmp?("post")
  errors << "file teaching form must use multipart/form-data" unless attribute(form, "enctype") == "multipart/form-data"
  errors << "novalidate would bypass the example contract" if form.match?(/\bnovalidate\b/i)
end

errors << "semantic shell requires one main and one h1" unless html.scan(/<main\b/i).length == 1 && html.scan(/<h1\b/i).length == 1
errors << "fieldset and legend must group the controls" unless html.match?(/<fieldset\b/i) && html.match?(/<legend\b/i)
["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
  errors << "missing #{label} intent comment" unless html.include?("<!-- #{label}:")
end
errors << "custom JavaScript validation is outside this example" if html.match?(/<script\b/i)

controls = {
  "asset-id" => ["assetId", "text"],
  "category" => ["category", nil],
  "priority" => ["priority", nil],
  "description" => ["description", nil],
  "observed-date" => ["observedDate", "date"],
  "evidence-files" => ["evidenceFiles", "file"],
  "contact" => ["contact", "text"]
}
controls.each do |id, (name, type)|
  tag = opening_tag(html, id)
  errors << "missing control ##{id}" unless tag
  next unless tag

  errors << "#{id} name must be #{name}" unless attribute(tag, "name") == name
  errors << "#{id} type must be #{type}" if type && attribute(tag, "type") != type
  errors << "label must explicitly target #{id}" unless html.match?(/<label\b[^>]*\bfor=["']#{Regexp.escape(id)}["'][^>]*>/i)
end

%w[asset-id category priority description observed-date].each do |id|
  tag = opening_tag(html, id)
  errors << "#{id} must be required" unless tag&.match?(/\srequired(?:\s|>|=)/i)
end
description = opening_tag(html, "description")
errors << "description length contract drifted" unless attribute(description, "minlength") == "10" && attribute(description, "maxlength") == "5000"
date = opening_tag(html, "observed-date")
errors << "fixed date range drifted" unless attribute(date, "min") == "2026-01-01" && attribute(date, "max") == "2026-12-31"
file = opening_tag(html, "evidence-files")
errors << "file hint must allow fixed PNG/JPEG types" unless attribute(file, "accept") == "image/png,image/jpeg" && file&.match?(/\smultiple(?:\s|>)/i)

submitter = html.scan(/<button\b[^>]*>/i).find { |tag| attribute(tag, "type") == "submit" }
errors << "explicit submitter contract drifted" unless submitter && attribute(submitter, "name") == "intent" && attribute(submitter, "value") == "create"

ids = matrix.fetch("cases").map { |item| item.fetch("id") }
expected_ids = %w[valid missing-description invalid-date wrong-name bypass-invalid duplicate-same-key]
errors << "submission matrix cases drifted" unless ids == expected_ids
errors << "real browser scope must remain disclosed" unless matrix["real_browser_unverified"] == true
errors << "production adapter scope must remain disclosed" unless matrix["production_adapter_unverified"] == true

by_id = matrix.fetch("cases").to_h { |item| [item.fetch("id"), item] }
errors << "missing case must predict valueMissing and no ordinary request" unless
  by_id.dig("missing-description", "validity_flags") == ["description.valueMissing"] &&
  by_id.dig("missing-description", "ordinary_submit_emits_request") == false
errors << "format case must predict rangeOverflow and no ordinary request" unless
  by_id.dig("invalid-date", "validity_flags") == ["observedDate.rangeOverflow"] &&
  by_id.dig("invalid-date", "ordinary_submit_emits_request") == false
errors << "wrong-name case must expose severity and miss priority" unless begin
  names = by_id.dig("wrong-name", "request_entry_names") || []
  names.include?("severity") && !names.include?("priority") && by_id.dig("wrong-name", "server_outcome") == "reject-missing-priority"
end
errors << "bypass must reach server and be rejected" unless
  by_id.dig("bypass-invalid", "bypass_request_emitted") == true &&
  by_id.dig("bypass-invalid", "server_outcome") == "reject-server-validation"
errors << "duplicate case must require receiver idempotency" unless
  by_id.dig("duplicate-same-key", "attempts") == 2 &&
  by_id.dig("duplicate-same-key", "idempotency_key_source") == "approved receiver harness, not native HTML" &&
  by_id.dig("duplicate-same-key", "server_outcome") == "same-result-no-second-create"

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "FORMS_VALIDATION_EXAMPLE=FAIL (#{errors.length} violations)"
  exit 1
end

puts "form-owner-and-encoding: PASS"
puts "labels-and-control-names: PASS"
puts "native-constraints: PASS"
puts "text-select-date-file-controls: PASS"
puts "valid-missing-format-matrix: PASS"
puts "wrong-name-and-bypass-matrix: PASS"
puts "duplicate-idempotency-boundary: PASS"
puts "scope-disclosure: PASS"
puts "FORMS_VALIDATION_EXAMPLE=PASS"
