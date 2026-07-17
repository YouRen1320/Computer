#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

def check(condition, message)
  raise message unless condition
end

faults = JSON.parse(File.read(File.join(__dir__, "faults.json"), encoding: "UTF-8")).fetch("faults")
expected_ids = %w[wrong-origin wrong-samesite-expectation stale-unchanged-url missing-vary-origin]
check(faults.map { |fault| fault.fetch("id") } == expected_ids, "fault set/order differs")

faults.each do |fault|
  id = fault.fetch("id")
  injected = fault.fetch("injected")
  check(!fault.fetch("first_evidence").strip.empty?, "#{id} lacks first evidence")
  check(!fault.fetch("repair").strip.empty?, "#{id} lacks repair")
  check(!fault.fetch("replay").strip.empty?, "#{id} lacks replay")

  case id
  when "wrong-origin"
    check(injected.fetch("allowlist_value").end_with?("/"), "wrong Origin path fault is absent")
    check(injected.fetch("request_origin") + "/" == injected.fetch("allowlist_value"), "Origin mismatch is not controlled")
    check(injected.fetch("server_received_request") && !injected.fetch("script_readable"),
          "fixture must distinguish server receipt from browser sharing")
  when "wrong-samesite-expectation"
    check(injected.fetch("page_site") != injected.fetch("target_site"), "SameSite fault is not cross-site")
    check(injected.fetch("credentials") == "include" && injected.fetch("cookie_same_site") == "Lax",
          "SameSite fault lacks include + Lax")
    check(injected.fetch("expected_by_buggy_app") != injected.fetch("actual"), "buggy expectation accidentally matches")
  when "stale-unchanged-url"
    check(injected.fetch("url") == "/app.css" && injected.fetch("cache_control").include?("max-age=86400"),
          "stale URL/freshness fault is absent")
    check(injected.fetch("cached_version") != injected.fetch("origin_version"), "origin content did not change")
    check(!injected.fetch("second_network_request") && injected.fetch("rendered_version") == injected.fetch("cached_version"),
          "fresh cache did not produce the stale representation")
  when "missing-vary-origin"
    check(injected.fetch("dynamic_allow_origin") && !injected.fetch("vary").include?("Origin"), "missing Vary fault is absent")
    check(injected.fetch("cached_for") != injected.fetch("reused_for"), "cache was not reused across Origins")
  else
    raise "unknown fault #{id}"
  end

  puts "#{id}: RED detected; first evidence, repair and replay are fixed"
end
puts "ORIGIN_COOKIE_CACHE_LAB=PASS"
