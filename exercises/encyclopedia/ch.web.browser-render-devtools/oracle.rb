#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

answer = JSON.parse(File.read(ARGV.fetch(0), encoding: "UTF-8"))
errors = []

required_requests = %w[/index.html /styles.css /status.svg]
errors << "prediction must list HTML, CSS and SVG requests" unless (required_requests - answer.fetch("expected_requests", [])).empty?

required_environment = %w[browser-version viewport cache reload]
errors << "environment must fix browser version, viewport, cache and reload" unless
  (required_environment - answer.fetch("environment", [])).empty?

fault = answer.fetch("fault", {})
errors << "fault must preserve the requested /assets/styles.css URL and 404" unless
  fault["requested_url"] == "/assets/styles.css" && fault["status"] == 404
errors << "first trustworthy panel must be Network" unless fault["first_evidence_panel"] == "Network"
errors << "CSS 404 must leave the status DOM node present" unless fault["dom_status_exists"] == true
errors << "CSS 404 must remove the target computed style" unless fault["computed_style_present"] == false
errors << "diagnosis must identify resource-path" unless fault["diagnosis"] == "resource-path"

repair = answer.fetch("repair", {})
errors << "repair must change source and restore /styles.css 200" unless
  repair["source_file_changed"] == true && repair["requested_url"] == "/styles.css" && repair["status"] == 200
errors << "repair must restore computed style" unless repair["computed_style_present"] == true
errors << "repair must rerun the same inputs" unless repair["same_inputs_rerun"] == true

required_artifacts = %w[har dom-summary timeline screenshot]
errors << "evidence must include HAR, DOM summary, timeline and screenshot" unless
  (required_artifacts - answer.fetch("artifacts", [])).empty?

safety = answer.fetch("safety", {})
errors << "artifacts must be synthetic or sanitized" unless safety["synthetic_or_sanitized"] == true
errors << "secret fields must be absent" unless safety["secret_fields_absent"] == true

boundary = answer.fetch("boundary", {})
errors << "chapter must not claim JavaScript optimization" unless boundary["does_not_claim_javascript_optimization"] == true
errors << "offline answer must mark real browser recording unverified" unless boundary["real_browser_recording_unverified"] == true

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "BROWSER_RENDER_EXERCISE=RED (#{errors.length} violations)"
  exit 1
end

puts "prediction-environment: PASS"
puts "network-first-evidence: PASS"
puts "dom-cssom-difference: PASS"
puts "source-fix-original-rerun: PASS"
puts "four-artifacts-and-safety: PASS"
puts "scope-boundary: PASS"
puts "BROWSER_RENDER_EXERCISE=PASS"
