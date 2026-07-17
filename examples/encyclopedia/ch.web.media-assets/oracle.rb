#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html = File.read("index.html", encoding: "UTF-8")
transcript = File.read("inspection-transcript.html", encoding: "UTF-8")
manifest = JSON.parse(File.read("manifest.json", encoding: "UTF-8"))
matrix = JSON.parse(File.read("observation-matrix.json", encoding: "UTF-8"))
vtt = File.read("assets/inspection.zh-CN.vtt", encoding: "UTF-8")
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

errors << "picture/source/img structure is required" unless html.match?(/<picture\b/i) && html.match?(/<source\b[^>]*\bmedia=/i)
image = html.scan(/<img\b[^>]*>/i).find { |tag| attribute(tag, "id") == "incident-photo" }
errors << "informative image is missing" unless image
if image
  errors << "informative alt drifted" unless attribute(image, "alt") == "冷却泵进水接口下方有一条深色油迹"
  errors << "responsive image needs src, srcset and sizes" unless attribute(image, "src") && attribute(image, "srcset")&.include?("480w") && attribute(image, "sizes")
  errors << "intrinsic dimensions drifted" unless attribute(image, "width") == "960" && attribute(image, "height") == "640"
end
decorative = html.scan(/<img\b[^>]*>/i).find { |tag| attribute(tag, "src") == "./assets/separator.svg" }
errors << "decorative image must use explicit empty alt" unless decorative && attribute(decorative, "alt") == ""

video = html[/<video\b[^>]*>/i]
errors << "video must expose native controls" unless video&.match?(/\scontrols(?:\s|>)/i)
sources = html.scan(/<source\b[^>]*>/i).select { |tag| attribute(tag, "src") }
errors << "video must declare WebM and MP4 sources" unless sources.map { |tag| attribute(tag, "type") } == %w[video/webm video/mp4]
track = html[/<track\b[^>]*>/i]
errors << "caption track contract drifted" unless
  attribute(track, "kind") == "captions" && attribute(track, "src") == "./assets/inspection.zh-CN.vtt" &&
  attribute(track, "srclang") == "zh-CN" && track&.match?(/\sdefault(?:\s|>)/i)
errors << "visible external transcript link is required" unless html.match?(/<a\b[^>]*\bid=["']transcript-link["'][^>]*\bhref=["']\.\/inspection-transcript\.html["']/i)
errors << "WebVTT header or cues drifted" unless vtt.start_with?("WEBVTT\n\n") && vtt.scan(/\d\d:\d\d\.\d{3} --> \d\d:\d\d\.\d{3}/).length == 3

manifest.fetch("assets").each do |asset|
  next unless asset.fetch("offline_present")

  path = asset.fetch("url").sub(%r{\A\./}, "")
  errors << "declared offline asset missing: #{path}" unless File.file?(path)
end
errors << "fixture must not claim real video binaries" unless manifest["real_media_binaries_present"] == false
errors << "HTTP/codec scope disclosure missing" unless manifest["real_http_and_codec_unverified"] == true
errors << "private attachment authorization boundary missing" unless manifest.fetch("private_attachment_policy").include?("never replace")

expected_cases = %w[narrow-1x narrow-2x wide-1x image-404 video-mime captions-404]
errors << "observation matrix inventory drifted" unless matrix.fetch("cases").map { |item| item.fetch("id") } == expected_cases
errors << "matrix must not pretend browser observations" unless matrix["real_browser_observations_recorded"] == false

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "MEDIA_ASSETS_EXAMPLE=FAIL (#{errors.length} violations)"
  exit 1
end

puts "image-alt-and-art-direction: PASS"
puts "srcset-sizes-and-dimensions: PASS"
puts "decorative-image: PASS"
puts "video-controls-sources-track: PASS"
puts "webvtt-and-transcript: PASS"
puts "asset-manifest-boundary: PASS"
puts "failure-observation-matrix: PASS"
puts "scope-disclosure: PASS"
puts "MEDIA_ASSETS_EXAMPLE=PASS"
