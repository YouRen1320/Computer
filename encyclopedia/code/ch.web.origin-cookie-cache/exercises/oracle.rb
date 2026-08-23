#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

answer = JSON.parse(File.read(ARGV.fetch(0), encoding: "UTF-8"))
errors = []

origin = answer.fetch("origin", {})
errors << "HTTP(S) Origin tuple must be scheme, host and port" unless origin["tuple_fields"] == %w[scheme host port]
errors << "different localhost ports must be cross-origin" unless origin["localhost_port_changes_origin"] == true
errors << "same-site URLs can still be cross-origin" unless origin["same_site_can_be_cross_origin"] == true

sop = answer.fetch("sop_cors", {})
errors << "CORS failure does not prove the server never received the request" unless sop["cors_failure_means_request_never_arrived"] == false
errors << "CORS must not be treated as server authorization" unless sop["cors_is_server_authorization"] == false

fetch = answer.fetch("fetch", {})
errors << "Fetch default credentials mode must be same-origin" unless fetch["default_credentials"] == "same-origin"
errors << "cross-origin cookie processing requires include in this matrix" unless fetch["cross_origin_cookie_requires_include"] == true
errors << "credentialed CORS must reject wildcard ACAO" unless fetch["credentialed_wildcard_allowed"] == false
errors << "cross-origin preflight must not authenticate with target session Cookie" unless fetch["preflight_uses_target_session_cookie"] == false

cookie = answer.fetch("cookie", {})
errors << "Cookie matching must not use port as a boundary" unless cookie["port_is_cookie_boundary"] == false
errors << "Cookie Path must not be treated as a security boundary" unless cookie["path_is_security_boundary"] == false
errors << "omitting Domain must create a host-only Cookie" unless cookie["domain_omitted_is_host_only"] == true
errors << "Max-Age must take precedence over Expires" unless cookie["max_age_overrides_expires"] == true
errors << "SameSite=None must require Secure" unless cookie["same_site_none_requires_secure"] == true
errors << "HttpOnly must still allow matching HTTP attachment" unless cookie["http_only_prevents_http_attachment"] == false

cache = answer.fetch("cache", {})
errors << "no-cache must allow storage but require validation" unless cache["no_cache_means_no_store"] == false
errors << "no-store and private must remain distinct" unless cache["no_store_equals_private"] == false
errors << "304 must reuse the stored representation body" unless cache["status_304_reuses_stored_body"] == true
errors << "dynamic ACAO must require Vary: Origin" unless cache["dynamic_acao_requires_vary_origin"] == true

factorycare = answer.fetch("factorycare", {})
errors << "FactoryCare production Cookie/CORS/cache values are still undecided" unless factorycare["production_cookie_values_already_decided"] == false
errors << "CORS must not replace Java authorization" unless factorycare["cors_replaces_java_authorization"] == false
errors << "Redis cache-aside must remain separate from browser HTTP cache" unless factorycare["redis_cache_is_browser_http_cache"] == false
errors << "write-concurrency ETag must remain separate from GET cache validation" unless
  factorycare["write_concurrency_etag_equals_get_cache_validation"] == false

required_evidence = %w[network console response-headers server-log]
errors << "evidence must combine Network, Console, response headers and server log" unless
  (required_evidence - answer.fetch("evidence", [])).empty?
errors << "offline answer must mark real browser behavior unverified" unless answer["real_browser_behavior_unverified"] == true

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "ORIGIN_COOKIE_CACHE_EXERCISE=RED (#{errors.length} violations)"
  exit 1
end

puts "origin-site: PASS"
puts "sop-cors-boundary: PASS"
puts "fetch-credentials-preflight: PASS"
puts "cookie-attachment: PASS"
puts "cache-validation-vary: PASS"
puts "factorycare-boundaries: PASS"
puts "evidence-honesty: PASS"
puts "ORIGIN_COOKIE_CACHE_EXERCISE=PASS"
