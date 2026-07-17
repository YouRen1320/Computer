#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html_path = ARGV.fetch(0, "answer.html")
json_path = ARGV.fetch(1, "answer.json")
html = File.read(html_path, encoding: "UTF-8")
answer = JSON.parse(File.read(json_path, encoding: "UTF-8"))
errors = []

def attribute(tag, name)
  match = tag.to_s.match(/\b#{Regexp.escape(name)}\s*=\s*(["'])(.*?)\1/im)
  match && match[2]
end

def control(html, id)
  html.scan(/<(?:input|select|textarea|button)\b[^>]*>/im).find { |tag| attribute(tag, "id") == id }
end

["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
  errors << "missing #{label} intent comment" unless html.include?("<!-- #{label}:")
end
errors << "semantic shell must contain one main and one h1" unless html.scan(/<main\b/i).length == 1 && html.scan(/<h1\b/i).length == 1

form = html[/<form\b[^>]*>/i]
errors << "form action must target the teaching receiver, not the production JSON API" unless attribute(form, "action") == "/teaching/exercise/report-submissions"
errors << "form method must be post" unless attribute(form, "method")&.casecmp?("post")
errors << "file teaching form must use multipart/form-data" unless attribute(form, "enctype") == "multipart/form-data"
errors << "novalidate must not disable the ordinary native-validation path" if form&.match?(/\bnovalidate\b/i)

expected_names = {
  "asset-id" => "assetId",
  "priority" => "priority",
  "description" => "description",
  "observed-date" => "observedDate",
  "evidence-files" => "evidenceFiles"
}
expected_names.each do |id, name|
  tag = control(html, id)
  errors << "missing control #{id}" unless tag
  next unless tag

  errors << "#{id} must have a visible explicit label" unless html.match?(/<label\b[^>]*\bfor=["']#{Regexp.escape(id)}["'][^>]*>/i)
  errors << "#{id} name must be #{name}" unless attribute(tag, "name") == name
end

%w[asset-id priority description observed-date].each do |id|
  errors << "#{id} must retain required" unless control(html, id)&.match?(/\srequired(?:\s|>|=)/i)
end
description = control(html, "description")
errors << "description length contract must be 10..5000" unless attribute(description, "minlength") == "10" && attribute(description, "maxlength") == "5000"
date = control(html, "observed-date")
errors << "observed-date must be a fixed-range date teaching control" unless
  attribute(date, "type") == "date" && attribute(date, "min") == "2026-01-01" && attribute(date, "max") == "2026-12-31"
file = control(html, "evidence-files")
errors << "file control must hint PNG/JPEG and allow repeated file entries" unless
  attribute(file, "type") == "file" && attribute(file, "accept") == "image/png,image/jpeg" && file&.match?(/\smultiple(?:\s|>)/i)

submitter = html.scan(/<button\b[^>]*>/i).find { |tag| attribute(tag, "type") == "submit" }
errors << "submitter must explicitly contribute intent=create" unless
  submitter && attribute(submitter, "name") == "intent" && attribute(submitter, "value") == "create"
errors << "custom scripts are outside this exercise" if html.match?(/<script\b/i)

expected_entries = %w[assetId priority description observedDate evidenceFiles intent]
errors << "predicted request entry names must match the teaching contract" unless answer["expected_entry_names"] == expected_entries
errors << "placeholder must not be treated as a label" unless answer["placeholder_is_a_label"] == false
errors << "client validation must not be treated as a security boundary" unless answer["client_validation_is_security_boundary"] == false
errors << "accept must not be treated as server file validation" unless answer["accept_proves_server_file_safe"] == false
errors << "direct multipart must remain distinct from FactoryCare JSON plus upload-intent" unless answer["direct_multipart_matches_factorycare_api"] == false
errors << "button disabling must not be treated as complete duplicate prevention" unless answer["disabled_button_prevents_all_duplicates"] == false
errors << "bypassed invalid input must be rejected by server validation" unless answer["bypass_invalid_server_result"] == "400-fieldErrors-description"
errors << "same key and same request must not create a second report" unless answer["duplicate_same_key_server_result"] == "same-result-no-second-create"
errors << "real browser and receiver behavior must remain unverified" unless answer["real_browser_unverified"] == true
errors << "production adapter must remain unverified" unless answer["production_adapter_unverified"] == true

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "FORMS_VALIDATION_EXERCISE=RED (#{errors.length} violations)"
  exit 1
end

puts "intent-boundaries: PASS"
puts "form-owner-and-encoding: PASS"
puts "labels-names-and-values: PASS"
puts "native-constraints: PASS"
puts "text-select-date-file-controls: PASS"
puts "server-validation-boundary: PASS"
puts "factorycare-upload-and-idempotency-boundary: PASS"
puts "scope-disclosure: PASS"
puts "FORMS_VALIDATION_EXERCISE=PASS"
