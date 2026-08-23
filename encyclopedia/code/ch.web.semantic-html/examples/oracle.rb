#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "json"

html = File.read("page.html", encoding: "UTF-8")
expected = JSON.parse(File.read("expected.json", encoding: "UTF-8"))
errors = []

def text_content(value)
  CGI.unescapeHTML(value.gsub(/<[^>]+>/m, "").gsub(/\s+/, " ").strip)
end

def attribute(tag, name)
  match = tag.match(/\b#{Regexp.escape(name)}\s*=\s*(["'])(.*?)\1/im)
  match && match[2]
end

errors << "doctype must select standards mode" unless html.match?(/\A\s*<!doctype\s+html>/i)
root_tag = html[/<html\b[^>]*>/i]
errors << "document language must match the prediction" unless root_tag && attribute(root_tag, "lang") == expected.fetch("language")

charset_tag = html.scan(/<meta\b[^>]*>/i).find { |tag| attribute(tag, "charset") }
errors << "UTF-8 metadata must be present" unless charset_tag && attribute(charset_tag, "charset").casecmp?("utf-8")

metadata = html.scan(/<meta\b[^>]*>/i)
viewport = metadata.find { |tag| attribute(tag, "name")&.casecmp?("viewport") }
description = metadata.find { |tag| attribute(tag, "name")&.casecmp?("description") }
errors << "viewport metadata drifted" unless viewport && attribute(viewport, "content") == expected.fetch("viewport")
errors << "description metadata drifted" unless description && attribute(description, "content") == expected.fetch("description")

titles = html.scan(/<title\b[^>]*>(.*?)<\/title\s*>/im).flatten.map { |value| text_content(value) }
errors << "document must have one predicted title" unless titles == [expected.fetch("title")]

canonical = html.scan(/<link\b[^>]*>/i).find { |tag| attribute(tag, "rel")&.split&.include?("canonical") }
errors << "canonical link metadata drifted" unless canonical && attribute(canonical, "href") == expected.fetch("canonical")

comments = %w[Responsibility Data\ source Mapping Side\ effects]
comments.each do |label|
  errors << "missing #{label.tr('\\', ' ')} intent comment" unless html.include?("<!-- #{label.tr('\\', ' ')}:")
end

expected.fetch("minimum_elements").each do |name, minimum|
  count = html.scan(/<#{Regexp.escape(name)}\b/i).length
  errors << "#{name} count #{count} is below #{minimum}" if count < minimum
end

expected.fetch("forbidden_elements").each do |name|
  errors << "#{name} is outside this chapter boundary" if html.match?(/<#{Regexp.escape(name)}\b/i)
end
expected.fetch("forbidden_attributes").each do |name|
  errors << "#{name} attribute is outside this example contract" if html.match?(/\s#{Regexp.escape(name)}\s*=/i)
end

headings = html.scan(/<h([1-6])\b[^>]*>(.*?)<\/h\1\s*>/im).map do |level, value|
  { "level" => level.to_i, "text" => text_content(value) }
end
errors << "explicit heading outline drifted" unless headings == expected.fetch("headings")

errors << "main must be unique" unless html.scan(/<main\b/i).length == 1
errors << "h1 must be unique" unless html.scan(/<h1\b/i).length == 1
errors << "time values need machine-readable datetime" unless html.scan(/<time\b/i).length == html.scan(/<time\b[^>]*\bdatetime\s*=/i).length

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "SEMANTIC_HTML_EXAMPLE=FAIL (#{errors.length} violations)"
  exit 1
end

puts "metadata: PASS"
puts "native-regions: PASS"
puts "explicit-heading-outline: PASS"
puts "text-semantics: PASS"
puts "intent-boundaries: PASS"
puts "offline-scope: PASS (real validator, browser DOM, accessibility tree and screen reader remain unverified)"
puts "SEMANTIC_HTML_EXAMPLE=PASS"
