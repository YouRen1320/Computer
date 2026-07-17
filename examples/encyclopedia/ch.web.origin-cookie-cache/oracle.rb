#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "uri"

def check(condition, message)
  raise message unless condition
end

data = JSON.parse(File.read(File.join(__dir__, "matrix.json"), encoding: "UTF-8"))
origins = data.fetch("origins")

def tuple(url)
  uri = URI(url)
  [uri.scheme, uri.host, uri.port]
end

check(tuple(origins.dig("A", "url")) == ["https", "app.factorycare.test", 8443], "Origin A tuple differs")
check(tuple(origins.dig("B", "url")) == ["https", "api.factorycare.test", 9443], "Origin B tuple differs")
check(tuple(origins.dig("C", "url")) == ["https", "api.vendor.test", 9443], "Origin C tuple differs")
check(tuple(origins.dig("A", "url")) != tuple(origins.dig("B", "url")), "A and B must be cross-origin")
check(origins.dig("A", "site") == origins.dig("B", "site"), "A and B must be same-site")
check(origins.dig("A", "site") != origins.dig("C", "site"), "A and C must be cross-site")
puts "origin-site-model: PASS (A/B cross-origin same-site; A/C cross-site)"

def cookie_candidate?(request, page_origin, target_origin, same_site)
  cookie = request["cookie"]
  return false if cookie.nil?

  cross_origin = tuple(page_origin) != tuple(target_origin)
  return false if request.fetch("credentials") == "omit"
  return false if cross_origin && request.fetch("credentials") != "include"

  target = URI(target_origin)
  return false unless cookie.fetch("host") == target.host
  return false unless request.fetch("target_path").start_with?(cookie.fetch("path"))
  return false if cookie.fetch("secure") && target.scheme != "https"
  return false if !same_site && cookie.fetch("same_site") != "None"
  return false if cookie.fetch("same_site") == "None" && !cookie.fetch("secure")

  true
end

def preflight?(request)
  return true unless %w[GET HEAD POST].include?(request.fetch("method"))

  request.fetch("headers").any? do |header|
    name, value = header.split(":", 2).map(&:strip)
    !%w[Accept Accept-Language Content-Language].include?(name) &&
      !(name == "Content-Type" && %w[application/x-www-form-urlencoded multipart/form-data text/plain].include?(value))
  end
end

def cors_readable?(request, page_origin, target_origin)
  return true if tuple(page_origin) == tuple(target_origin)

  cors = request["cors"] || {}
  allow_origin = cors["allow_origin"]
  credentialed = request.fetch("credentials") == "include"
  origin_allowed = allow_origin == page_origin || (allow_origin == "*" && !credentialed)
  credentials_allowed = !credentialed || cors["allow_credentials"] == true
  origin_allowed && credentials_allowed
end

data.fetch("requests").each do |request|
  page = origins.fetch(request.fetch("page"))
  target = origins.fetch(request.fetch("target"))
  same_site = page.fetch("site") == target.fetch("site")
  actual_cookie = cookie_candidate?(request, page.fetch("url"), target.fetch("url"), same_site)
  actual_preflight = preflight?(request)
  actual_readable = cors_readable?(request, page.fetch("url"), target.fetch("url"))
  check(actual_cookie == request.fetch("expected_cookie"), "#{request.fetch('id')} cookie decision differs")
  check(actual_preflight == request.fetch("expected_preflight"), "#{request.fetch('id')} preflight decision differs")
  check(actual_readable == request.fetch("expected_readable"), "#{request.fetch('id')} CORS decision differs")
  if request.fetch("expected_readable") && tuple(page.fetch("url")) != tuple(target.fetch("url"))
    check(request.dig("cors", "vary").include?("Origin"), "#{request.fetch('id')} readable dynamic CORS response lacks Vary")
  end
end
puts "request-matrix: PASS (7 cookie/credentials/CORS decisions)"
puts "preflight: PASS (state write requires OPTIONS; GET cases do not)"

cache = data.fetch("cache")
first = cache.fetch("first")
repeat_request = cache.fetch("repeat")
check(first.fetch("cache_control") == "no-cache" && first.fetch("stored"), "no-cache must allow storage in this fixture")
check(repeat_request.fetch("if_none_match") == first.fetch("etag"), "If-None-Match must use stored ETag")
check(repeat_request.fetch("status") == 304 && repeat_request["response_body"].nil?, "repeat must be a bodyless 304")
check(repeat_request.fetch("representation_source") == "stored-200-body", "304 must reuse the stored representation")
check(repeat_request.fetch("expected_body") == first.fetch("body"), "reused body differs from stored 200")
check(cache.dig("dynamic_cors", "vary") == ["Origin"], "dynamic CORS response must Vary on Origin")
puts "cache-validation: PASS (200 stored -> If-None-Match -> 304 reuses body)"
puts "vary-origin: PASS (dynamic ACAO cache key is separated)"

boundary = data.fetch("evidence_boundary")
check(boundary.fetch("kind") == "synthetic-not-browser-recording", "synthetic boundary label is absent")
check(boundary.fetch("real_browser_cookie_policy_verified") == false, "fixture must not claim real browser verification")
check(boundary.fetch("factorycare_production_values_decided") == false, "fixture must not invent production policy")
puts "evidence-boundary: PASS (synthetic only; production policy undecided)"
