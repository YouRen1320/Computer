#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

def check(condition, message)
  raise message unless condition
end

data = JSON.parse(File.read(File.join(__dir__, "scenario.json"), encoding: "UTF-8"))
baseline = data.fetch("baseline")
check(baseline.fetch("requests").map { |item| item.fetch("status") }.all? { |status| status == 200 },
      "baseline resources must all be 200")
check(baseline.fetch("dom_status_exists"), "baseline DOM status node must exist")
check(baseline.fetch("computed_status_color") == "rgb(7, 89, 133)", "baseline computed color differs")
puts "baseline: PASS (network, DOM and render prediction is fixed)"

path_fault, blocking_fault = data.fetch("faults")
check(path_fault.fetch("id") == "wrong-resource-path", "first fault ID differs")
injected = path_fault.fetch("injected")
repair = path_fault.fetch("repair")
check(injected.fetch("requested_path") == "/assets/styles.css" && injected.fetch("status") == 404,
      "path fault is not a deterministic 404")
check(injected.fetch("dom_status_exists") && injected.fetch("computed_status_color") != baseline.fetch("computed_status_color"),
      "path fault must retain DOM but lose target computed style")
check(path_fault.fetch("first_evidence").start_with?("Network"), "path fault must begin with Network evidence")
check(repair.fetch("requested_path") == "/styles.css" && repair.fetch("status") == 200,
      "path repair does not restore the expected URL/status")
check(repair.fetch("computed_status_color") == baseline.fetch("computed_status_color"), "path repair color differs")
check(path_fault.fetch("replay").sort == %w[same-cache same-dom-and-color-assertions same-url same-viewport].sort,
      "path repair did not preserve replay inputs")
puts "wrong-resource-path: RED detected -> repaired -> original oracle replayable"

check(blocking_fault.fetch("id") == "blocking-stylesheet", "second fault ID differs")
slow = blocking_fault.fetch("injected")
fast = blocking_fault.fetch("repair")
check(slow.fetch("status") == 200, "blocking fixture must distinguish delay from HTTP failure")
check(slow.fetch("css_wait_ms") > baseline.fetch("requests").find { |item| item["path"] == "/styles.css" }.fetch("wait_ms"),
      "blocking fixture is not slower than baseline")
check(slow.fetch("first_paint_ms") > baseline.fetch("first_paint_ms"), "blocking fixture does not delay first paint")
check(blocking_fault.fetch("first_evidence").include?("Network Timing"), "blocking fault lacks timing evidence")
check(fast.fetch("css_wait_ms") == 5 && fast.fetch("first_paint_ms") == baseline.fetch("first_paint_ms"),
      "blocking repair does not restore baseline")
check(blocking_fault.fetch("replay").sort == %w[same-cache same-timeline-phases same-url same-viewport].sort,
      "blocking repair did not preserve replay inputs")
puts "blocking-stylesheet: RED detected -> repaired -> original oracle replayable"
puts "BROWSER_RENDER_LAB=PASS"
