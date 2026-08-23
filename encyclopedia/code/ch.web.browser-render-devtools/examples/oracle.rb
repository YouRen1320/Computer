#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

def check(condition, message)
  raise message unless condition
end

root = File.expand_path(__dir__)
html = File.read(File.join(root, "public/index.html"), encoding: "UTF-8")
css = File.read(File.join(root, "public/styles.css"), encoding: "UTF-8")
check(html.include?('href="./styles.css"'), "HTML must reference the expected stylesheet")
check(html.include?('src="./status.svg"'), "HTML must reference the expected SVG")
check(html.match?(%r{<main\s+class="work-order">}), "main work-order node is absent")
check(html.match?(%r{<p\s+class="status">}), "status node is absent")
check(html.include?('alt="处理中状态示意"'), "image alternative text is absent")
check(css.match?(/\.status\s*\{[^}]*color:\s*#075985/m), "status style is absent")
puts "page-inputs: PASS (HTML, CSS, SVG references are stable)"

har = JSON.parse(File.read(File.join(root, "evidence/network.har.json"), encoding: "UTF-8"))
entries = har.dig("log", "entries")
expected = {
  "http://127.0.0.1:4173/index.html" => ["text/html", "navigation"],
  "http://127.0.0.1:4173/styles.css" => ["text/css", "link"],
  "http://127.0.0.1:4173/status.svg" => ["image/svg+xml", "img"]
}
check(entries.length == expected.length, "HAR request count differs")
entries.each do |entry|
  check(entry.dig("request", "method") == "GET", "fixture only expects GET")
  url = entry.dig("request", "url")
  check(expected.key?(url), "unexpected HAR URL: #{url}")
  mime, initiator = expected.fetch(url)
  check(entry.dig("response", "status") == 200, "#{url} did not return 200")
  check(entry.dig("response", "content", "mimeType") == mime, "#{url} MIME differs")
  check(entry.fetch("_initiator") == initiator, "#{url} initiator differs")
end
puts "network-har: PASS (3 expected 200 responses)"

dom = JSON.parse(File.read(File.join(root, "evidence/dom.json"), encoding: "UTF-8"))
nodes = dom.fetch("nodes").to_h { |node| [node.fetch("selector"), node] }
check(nodes.keys.sort == ["img", "main.work-order", "main.work-order > h1", "p.status"].sort,
      "DOM selector set differs")
check(nodes.dig("p.status", "computed_color") == "rgb(7, 89, 133)", "computed status color differs")
check(nodes.dig("img", "alt") == "处理中状态示意", "DOM image alt differs")
puts "dom-cssom: PASS (live DOM summary matches computed style)"

timeline = JSON.parse(File.read(File.join(root, "evidence/timeline.json"), encoding: "UTF-8"))
check(timeline.fetch("kind") == "synthetic-not-browser-recording", "synthetic evidence must be labeled honestly")
events = timeline.fetch("events")
phases = events.map { |event| event.fetch("phase") }
check(phases == %w[navigation parse-html style layout paint composite], "render phase sequence differs")
check(events.map { |event| event.fetch("at_ms") } == events.map { |event| event.fetch("at_ms") }.sort,
      "timeline timestamps are not monotonic")
check(timeline.fetch("screenshots").map { |shot| shot.fetch("state") } == %w[document-partial styled-composite],
      "screenshot states differ")
puts "render-timeline: PASS (parse->style->layout->paint->composite)"

serialized = [har, dom, timeline].map { |value| JSON.generate(value).downcase }.join(" ")
%w[authorization cookie set-cookie access_token refresh_token password client_secret].each do |secret|
  check(!serialized.include?(secret), "evidence contains forbidden field: #{secret}")
end
puts "artifact-safety: PASS (synthetic label present, secret fields absent)"
