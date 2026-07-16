#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

def check(condition, message)
  raise message unless condition
end

data = JSON.parse(File.read(ARGV.fetch(0), encoding: "UTF-8"))
logs = data.fetch("logs")
spans = data.fetch("spans")

trace_ids = (logs + spans).map { |item| item.fetch("trace_id") }.uniq
check(trace_ids.length == 1, "all logs and spans must share one trace")
check(trace_ids.first.match?(/\A[0-9a-f]{32}\z/), "trace_id must be 32 lowercase hex characters")

span_by_id = spans.to_h { |span| [span.fetch("span_id"), span] }
check(span_by_id.length == spans.length, "span IDs must be unique")
check(spans.count { |span| span["parent_span_id"].nil? } == 1, "trace must have exactly one root")

logs.each do |log|
  %w[timestamp severity service event outcome trace_id span_id].each do |field|
    check(log.key?(field), "log is missing #{field}")
  end
  span = span_by_id[log.fetch("span_id")]
  check(!span.nil?, "log span_id is absent from trace")
  check(span.fetch("trace_id") == log.fetch("trace_id"), "log and span trace_id differ")
end

spans.each do |span|
  check(span.fetch("span_id").match?(/\A[0-9a-f]{16}\z/), "span_id must be 16 lowercase hex characters")
  seen = {}
  current = span
  while current["parent_span_id"]
    parent_id = current.fetch("parent_span_id")
    check(!seen[parent_id], "span ancestry contains a cycle")
    seen[parent_id] = true
    current = span_by_id[parent_id]
    check(!current.nil?, "span parent is missing")
  end
end

expected_events = %w[
  http.work_order.create.received
  work_order.create.validated
  work_order.create.committed
  outbox.work_order_created.published
  work_order_created.consumed
  ai.draft.degraded
]
check(logs.map { |log| log.fetch("event") }.sort == expected_events.sort, "cross-boundary events are incomplete")
puts "correlation: PASS (6 logs, 6 spans, 1 trace)"

allowed_labels = {
  "factorycare_http_server_requests_total" => %w[route method outcome status_class],
  "factorycare_http_server_request_duration_seconds_bucket" => %w[route method le],
  "factorycare_dependency_requests_total" => %w[dependency outcome],
  "factorycare_outbox_backlog" => []
}
banned_labels = %w[trace_id span_id request_id user_id tenant_id work_order_id raw_url exception_message]
data.fetch("metrics").each do |series|
  name = series.fetch("name")
  labels = series.fetch("labels")
  check(allowed_labels.key?(name), "unknown metric schema: #{name}")
  check((labels.keys - allowed_labels.fetch(name)).empty?, "metric #{name} has an unapproved label")
  check((labels.keys & banned_labels).empty?, "metric #{name} has a high-cardinality label")
  if labels.key?("route")
    check(!labels.fetch("route").match?(%r{/\d+}), "metric route must be a template")
  end
end
puts "metric-cardinality: PASS (label allowlist is bounded)"

health = data.fetch("health")
check(health.dig("liveness", "status") == "UP", "liveness must be UP in this fixture")
check(health.dig("liveness", "external_dependencies") == [], "liveness must not depend on external systems")
check(health.dig("readiness", "required_dependencies") == ["postgres"], "readiness must name the core dependency")
check(health.fetch("optional_dependencies") == ["python-ai"], "python-ai must be optional")
check(health.dig("dependencies", "python-ai") == "DEGRADED", "optional Python dependency must be visibly degraded")
check(health.dig("readiness", "status") == "UP", "optional degradation must not make the core API unready")
puts "health-semantics: PASS (core ready, optional Python degraded)"

slo = data.fetch("slo")
eligible = slo.fetch("eligible")
bad = slo.fetch("bad")
target = slo.fetch("target")
availability = (eligible - bad).fdiv(eligible)
total_budget = ((1.0 - target) * eligible).round
remaining_budget = total_budget - bad
check((availability - slo.fetch("expected_availability")).abs < 1e-12, "availability calculation differs")
check(total_budget == slo.fetch("expected_total_budget"), "total error budget differs")
check(remaining_budget == slo.fetch("expected_remaining_budget"), "remaining error budget differs")
puts format("sli-error-budget: PASS (availability=%.2f%%, remaining=%d)", availability * 100, remaining_budget)

alerts = data.fetch("alerts")
alerts.each do |alert|
  triggered = alert.fetch("long_window_burn_rate") >= alert.fetch("threshold") &&
    alert.fetch("short_window_burn_rate") >= alert.fetch("threshold")
  check(triggered == alert.fetch("expected_page"), "#{alert.fetch('name')} page decision differs")
  next unless triggered

  check(!alert.fetch("owner", "").empty?, "triggered page needs an owner")
  check(!alert.fetch("runbook", "").empty?, "triggered page needs a runbook")
end
check(alerts.find { |alert| alert.fetch("name") == "transient-spike" }.fetch("expected_page") == false,
      "transient spike must not page")
puts "alert-sustainment: PASS (transient=no page, sustained=page)"

serialized = JSON.generate(data).downcase
%w[password authorization cookie access_token refresh_token client_secret prompt attachment_body].each do |secret|
  check(!serialized.include?(secret), "telemetry contains forbidden secret field: #{secret}")
end
puts "privacy-minimization: PASS (forbidden secret fields absent)"
