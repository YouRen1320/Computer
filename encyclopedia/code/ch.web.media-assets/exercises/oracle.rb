#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

html_path = ARGV.fetch(0, "answer.html")
json_path = ARGV.fetch(1, "answer.json")
base = File.dirname(html_path)
html = File.read(html_path, encoding: "UTF-8")
answer = JSON.parse(File.read(json_path, encoding: "UTF-8"))
errors = []

def attribute(tag, name)
  match = tag.to_s.match(/\b#{Regexp.escape(name)}\s*=\s*(["'])(.*?)\1/im)
  match && match[2]
end

["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
  errors << "missing #{label} intent comment" unless html.include?("<!-- #{label}:")
end
errors << "semantic shell must contain lang=zh-CN, main and h1" unless
  html.match?(/<html\b[^>]*\blang=["']zh-CN["']/i) && html.match?(/<main\b/i) && html.match?(/<h1\b/i)

picture_source = html.scan(/<source\b[^>]*>/i).find { |tag| attribute(tag, "type")&.start_with?("image/") }
errors << "picture source must use srcset and must not use src" unless
  attribute(picture_source, "srcset") && attribute(picture_source, "src").nil?
image = html.scan(/<img\b[^>]*>/i).find { |tag| attribute(tag, "id") == "incident" }
errors << "informative incident image needs a factual non-empty alt" unless attribute(image, "alt") == "泵体接口下方有深色油迹"
srcset = attribute(image, "srcset").to_s
errors << "incident srcset must use width descriptors only" unless srcset.include?("480w") && srcset.include?("960w") && !srcset.match?(/\s\d+(?:\.\d+)?x(?:\s|,|$)/)
errors << "width-descriptor srcset needs a sizes contract" unless attribute(image, "sizes")&.include?("100vw")
errors << "incident image needs intrinsic width and height" unless attribute(image, "width") == "960" && attribute(image, "height") == "640"
decorative = html.scan(/<img\b[^>]*>/i).find { |tag| attribute(tag, "id") == "separator" }
errors << "decorative separator must use explicit empty alt" unless decorative && attribute(decorative, "alt") == ""

video = html[/<video\b[^>]*>/i]
errors << "video must expose native controls" unless video&.match?(/\scontrols(?:\s|>)/i)
media_sources = html.scan(/<source\b[^>]*>/i).select { |tag| attribute(tag, "src")&.match?(/\.(?:webm|mp4)\z/) }
errors << "video source MIME declarations must be video/webm then video/mp4" unless media_sources.map { |tag| attribute(tag, "type") } == %w[video/webm video/mp4]
track = html[/<track\b[^>]*>/i]
errors << "video needs a default zh-CN captions track" unless
  attribute(track, "kind") == "captions" && attribute(track, "src") == "./captions.vtt" &&
  attribute(track, "srclang") == "zh-CN" && track&.match?(/\sdefault(?:\s|>)/i)
errors << "video needs a visible external transcript link" unless html.match?(/<a\b[^>]*\bhref=["']\.\/transcript\.html["']/i)

caption_path = File.join(base, "captions.vtt")
transcript_path = File.join(base, "transcript.html")
errors << "captions.vtt must exist beside the answer" unless File.file?(caption_path)
if File.file?(caption_path)
  errors << "captions.vtt must have a WebVTT header and cues" unless File.read(caption_path, encoding: "UTF-8").match?(/\AWEBVTT\n\n.*-->/m)
end
errors << "transcript.html must exist beside the answer" unless File.file?(transcript_path)
if File.file?(transcript_path)
  transcript = File.read(transcript_path, encoding: "UTF-8")
  ["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
    errors << "transcript lacks #{label} intent comment" unless transcript.include?("<!-- #{label}:")
  end
end

errors << "browser, not the author, makes the final currentSrc choice" unless answer["browser_current_src_is_exactly_author_controlled"] == false
errors << "sizes must not be treated as CSS layout" unless answer["sizes_changes_css_layout"] == false
errors << "explicit empty alt must remain distinct from missing alt" unless answer["empty_alt_equals_missing_alt"] == false
errors << "file extension must not be trusted as response MIME" unless answer["file_extension_proves_response_mime"] == false
errors << "video inner fallback must not promise all source-failure recovery" unless answer["video_inner_fallback_covers_all_source_failures"] == false
errors << "download attribute must not be treated as attachment authorization" unless answer["download_attribute_is_attachment_authorization"] == false
errors << "real browser, HTTP and codec behavior must remain unverified" unless answer["real_browser_http_codec_unverified"] == true

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "MEDIA_ASSETS_EXERCISE=RED (#{errors.length} violations)"
  exit 1
end

puts "picture-srcset-sizes: PASS"
puts "informative-and-decorative-alt: PASS"
puts "video-controls-and-mime: PASS"
puts "captions-and-transcript: PASS"
puts "browser-selection-boundary: PASS"
puts "http-and-download-boundary: PASS"
puts "scope-disclosure: PASS"
puts "MEDIA_ASSETS_EXERCISE=PASS"
