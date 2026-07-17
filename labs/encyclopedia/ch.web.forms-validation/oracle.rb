#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html = File.read("report-form.html", encoding: "UTF-8")
matrix = JSON.parse(File.read("submission-matrix.json", encoding: "UTF-8"))
faults = JSON.parse(File.read("faults.json", encoding: "UTF-8"))
errors = []

def attribute(tag, name)
  match = tag.to_s.match(/\b#{Regexp.escape(name)}\s*=\s*(["'])(.*?)\1/im)
  match && match[2]
end

def control(html, id)
  html.scan(/<(?:input|select|textarea|button)\b[^>]*>/im).find { |tag| attribute(tag, "id") == id }
end

form = html[/<form\b[^>]*>/i]
errors << "form owner id drifted" unless attribute(form, "id") == "report-form"
errors << "form submission contract drifted" unless
  attribute(form, "action") == "/teaching/lab/report-submissions" &&
  attribute(form, "method")&.casecmp?("post") &&
  attribute(form, "enctype") == "multipart/form-data"

expected_names = {
  "asset-id" => "assetId",
  "category" => "category",
  "priority" => "priority",
  "description" => "description",
  "observed-date" => "observedDate",
  "evidence-files" => "evidenceFiles"
}
expected_names.each do |id, name|
  tag = control(html, id)
  errors << "missing control #{id}" unless tag
  next unless tag

  errors << "#{id} name drifted" unless attribute(tag, "name") == name
  errors << "#{id} label association drifted" unless html.match?(/<label\b[^>]*\bfor=["']#{Regexp.escape(id)}["'][^>]*>/i)
end
%w[asset-id category priority description observed-date].each do |id|
  errors << "#{id} required constraint drifted" unless control(html, id)&.match?(/\srequired(?:\s|>|=)/i)
end

submitter = html.scan(/<button\b[^>]*>/i).find { |tag| attribute(tag, "type") == "submit" }
errors << "external submitter owner drifted" unless
  attribute(submitter, "form") == "report-form" &&
  attribute(submitter, "name") == "intent" &&
  attribute(submitter, "value") == "create"
errors << "custom scripts and novalidate are outside the lab" if html.match?(/<script\b|\bnovalidate\b/i)
["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
  errors << "missing #{label} intent comment" unless html.include?("<!-- #{label}:")
end

expected_cases = %w[valid missing-description invalid-date wrong-name bypass-invalid duplicate-same-key]
case_ids = matrix.fetch("cases").map { |item| item.fetch("id") }
errors << "matrix case inventory drifted" unless case_ids == expected_cases
errors << "browser prediction disclosure missing" unless matrix["observations_are_predictions_until_browser_run"] == true
cases = matrix.fetch("cases").to_h { |item| [item.fetch("id"), item] }
errors << "valid case encoding drifted" unless cases.dig("valid", "content_type") == "multipart/form-data; boundary=<browser-generated>"
errors << "missing case must be valueMissing with no request" unless
  cases.dig("missing-description", "validity") == "description.valueMissing" && cases.dig("missing-description", "ordinary_request") == false
errors << "format case must be rangeOverflow with no request" unless
  cases.dig("invalid-date", "validity") == "observedDate.rangeOverflow" && cases.dig("invalid-date", "ordinary_request") == false
wrong_names = cases.dig("wrong-name", "entry_names") || []
errors << "wrong-name payload prediction drifted" unless wrong_names.include?("severity") && !wrong_names.include?("priority")
errors << "bypass must be rejected by server validation" unless
  cases.dig("bypass-invalid", "direct_request") == true && cases.dig("bypass-invalid", "server_result") == "400-fieldErrors-description"
errors << "duplicate must use the same key and result" unless
  cases.dig("duplicate-same-key", "attempts") == 2 &&
  cases.dig("duplicate-same-key", "idempotency_key") == "lab-fixed-key-001" &&
  cases.dig("duplicate-same-key", "server_result") == "same-result-no-second-create"

expected_faults = %w[missing-label wrong-name validation-bypass]
fault_ids = faults.fetch("faults").map { |fault| fault.fetch("id") }
errors << "fault inventory drifted" unless fault_ids == expected_faults
errors << "same verifier must be reused" unless faults["same_verifier_rerun"] == true
errors << "receiver scope disclosure missing" unless faults["real_receiver_unverified"] == true
faults.fetch("faults").each do |fault|
  %w[injection first_evidence stage repair rerun residual_risk].each do |field|
    errors << "#{fault.fetch('id')} lacks #{field}" if fault[field].to_s.strip.empty?
  end
  errors << "#{fault.fetch('id')} changed the verifier" unless fault.fetch("rerun").include?("unchanged verify.sh")
end

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "FORMS_VALIDATION_LAB=FAIL (#{errors.length} violations)"
  exit 1
end

puts "form-owner-label-name: PASS"
puts "native-constraint-baseline: PASS"
puts "valid-missing-format-predictions: PASS"
puts "wrong-name-payload-prediction: PASS"
puts "validation-bypass-boundary: PASS"
puts "duplicate-idempotency-boundary: PASS"
puts "fault-repair-rerun-records: PASS"
puts "scope-disclosure: PASS"
puts "FORMS_VALIDATION_LAB=PASS"
