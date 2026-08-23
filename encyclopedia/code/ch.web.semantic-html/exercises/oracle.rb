#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"

path = ARGV.fetch(0, "answer.html")
html = File.read(path, encoding: "UTF-8")
errors = []

def clean(value)
  CGI.unescapeHTML(value.to_s.gsub(/<[^>]+>/m, "").gsub(/\s+/, " ").strip)
end

errors << "root html must declare lang=zh-CN" unless html.match?(/<html\b[^>]*\blang=["']zh-CN["']/i)
errors << "viewport metadata must use device width and initial scale" unless html.match?(/<meta\b[^>]*\bname=["']viewport["'][^>]*\bcontent=["']width=device-width, initial-scale=1["']/i)
title = clean(html[/<title\b[^>]*>(.*?)<\/title>/im, 1])
errors << "title must identify WO-EX-004 and the exercise context" unless title == "工单 WO-EX-004｜语义练习"
errors << "description metadata is required" unless html.match?(/<meta\b[^>]*\bname=["']description["']/i)
errors << "canonical link metadata is required" unless html.match?(/<link\b[^>]*\brel=["']canonical["']/i)

["Responsibility", "Data source", "Mapping", "Side effects"].each do |label|
  errors << "missing #{label} intent comment" unless html.include?("<!-- #{label}:")
end

%w[header nav main article section footer].each do |name|
  errors << "missing native #{name} element" unless html.match?(/<#{name}\b/i)
end

headings = html.scan(/<h([1-6])\b[^>]*>(.*?)<\/h\1\s*>/im).map { |level, value| [level.to_i, clean(value)] }
expected_headings = [[1, "工单 WO-EX-004"], [2, "故障摘要"], [2, "流转记录"], [3, "已创建"]]
errors << "heading sequence must be h1,h2,h2,h3 with the predicted text" unless headings == expected_headings
errors << "ARIA role must not patch this native-HTML exercise" if html.match?(/\srole\s*=/i)
errors << "CSS, forms and scripts are outside this exercise" if html.match?(/<(?:style|form|script)\b/i)
errors << "work-order summary must use a description list" unless html.match?(/<dl\b/i)
errors << "transition history must use an ordered list" unless html.match?(/<ol\b/i)
errors << "machine-readable time requires time[datetime]" unless html.match?(/<time\b[^>]*\bdatetime\s*=/i)

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "SEMANTIC_HTML_EXERCISE=RED (#{errors.length} violations)"
  exit 1
end

puts "metadata: PASS"
puts "intent-comments: PASS"
puts "native-regions: PASS"
puts "explicit-heading-outline: PASS"
puts "text-semantics: PASS"
puts "chapter-boundary: PASS"
puts "SEMANTIC_HTML_EXERCISE=PASS"
