#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html = File.read("index.html", encoding: "UTF-8")
transcript = File.read("transcript.html", encoding: "UTF-8")
matrix = JSON.parse(File.read("observation-matrix.json", encoding: "UTF-8"))
faults = JSON.parse(File.read("faults.json", encoding: "UTF-8"))
vtt = File.read("assets/lab.zh-CN.vtt", encoding: "UTF-8")
errors = []

def attribute(tag, name)
  match = tag.to_s.match(/\b#{Regexp.escape(name)}\s*=\s*(["'])(.*?)\1/im)
  match && match[2]
end

[html, transcript].each_with_index do |document, index|
  ["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
    errors << "document #{index + 1} lacks #{label} intent comment" unless document.include?("<!-- #{label}:")
  end
end
image = html.scan(/<img\b[^>]*>/i).find { |tag| attribute(tag, "id") == "incident" }
errors << "repaired informative alt drifted" unless attribute(image, "alt") == "泵体接口下方有深色油迹"
errors << "repaired width srcset/sizes drifted" unless
  attribute(image, "srcset") == "./assets/incident.svg 480w" && attribute(image, "sizes")&.include?("100vw")
errors << "picture source is missing" unless html.match?(/<picture\b.*?<source\b[^>]*\bmedia=/im)
video = html[/<video\b[^>]*>/i]
errors << "native video controls are missing" unless video&.match?(/\scontrols(?:\s|>)/i)
track = html[/<track\b[^>]*>/i]
errors << "caption track drifted" unless attribute(track, "kind") == "captions" && attribute(track, "src") == "./assets/lab.zh-CN.vtt"
errors << "external transcript is missing" unless html.match?(/<a\b[^>]*\bid=["']transcript["']/i)
errors << "WebVTT baseline drifted" unless vtt.start_with?("WEBVTT\n\n") && vtt.scan(/-->/).length == 2
%w[assets/incident.svg assets/poster.svg assets/lab.zh-CN.vtt transcript.html].each do |path|
  errors << "offline fixture missing #{path}" unless File.file?(path)
end

expected_cases = %w[baseline-narrow invalid-srcset missing-alt mime-mismatch captions-unavailable]
errors << "observation matrix drifted" unless matrix.fetch("cases").map { |item| item.fetch("id") } == expected_cases
errors << "matrix must remain a prediction" unless matrix["browser_observations_are_predictions"] == true
expected_faults = %w[invalid-srcset missing-alt mime-mismatch]
errors << "fault inventory drifted" unless faults.fetch("faults").map { |item| item.fetch("id") } == expected_faults
errors << "same verifier rerun missing" unless faults["same_verifier_rerun"] == true
errors << "browser scope disclosure missing" unless faults["real_browser_unverified"] == true
faults.fetch("faults").each do |fault|
  %w[injection first_evidence stage repair rerun residual_risk].each do |field|
    errors << "#{fault.fetch('id')} lacks #{field}" if fault[field].to_s.strip.empty?
  end
  errors << "#{fault.fetch('id')} changed the verifier" unless fault.fetch("rerun").include?("unchanged verify.sh")
end

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "MEDIA_ASSETS_LAB=FAIL (#{errors.length} violations)"
  exit 1
end

puts "repaired-responsive-image: PASS"
puts "repaired-video-track-transcript: PASS"
puts "prediction-matrix: PASS"
puts "fault-invalid-srcset: PASS"
puts "fault-missing-alt: PASS"
puts "fault-mime-mismatch: PASS"
puts "same-verifier-rerun: PASS"
puts "scope-disclosure: PASS"
puts "MEDIA_ASSETS_LAB=PASS"
