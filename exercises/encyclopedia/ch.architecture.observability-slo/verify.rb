#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

answer = JSON.parse(File.read(ARGV.fetch(0), encoding: "UTF-8"))
errors = []

required_log_fields = %w[timestamp severity service event outcome trace_id span_id]
unless (required_log_fields - answer.fetch("log_fields", [])).empty?
  errors << "logs must include stable fields plus real trace_id/span_id"
end

trace = answer.fetch("trace", {})
errors << "one trace must preserve causality across async work" unless trace["one_trace_across_async"] == true
errors << "every log span_id must exist in the trace" unless trace["log_span_ids_exist"] == true
required_boundaries = %w[http executor outbox consumer python]
unless (required_boundaries - trace.fetch("propagation_boundaries", [])).empty?
  errors << "context propagation boundaries are incomplete"
end

metrics = answer.fetch("metrics", {})
banned_labels = %w[trace_id span_id request_id user_id tenant_id work_order_id raw_url exception_message]
unless (metrics.fetch("labels", []) & banned_labels).empty?
  errors << "metric labels contain high-cardinality request or business IDs"
end
errors << "HTTP route metric must use a route template" unless metrics["route_is_template"] == true

health = answer.fetch("health", {})
unless health.fetch("liveness_external_dependencies", []).empty?
  errors << "liveness must not depend on external systems"
end
unless health.fetch("readiness_required_dependencies", []) == ["postgres"]
  errors << "readiness must require only the core PostgreSQL dependency in this scenario"
end
unless health.fetch("optional_dependencies", []) == ["python-ai"]
  errors << "Python AI must be declared optional"
end
unless health["python_status"] == "DEGRADED" && health["core_readiness"] == "UP"
  errors << "optional Python degradation must leave core readiness UP"
end

slo = answer.fetch("slo", {})
eligible = slo.fetch("eligible", 0)
bad = slo.fetch("bad", 0)
target = slo.fetch("target", 0.0)
if eligible.positive?
  calculated_availability = (eligible - bad).fdiv(eligible)
  calculated_budget = ((1.0 - target) * eligible).round
  calculated_remaining = calculated_budget - bad
  correct = (slo.fetch("availability", -1.0) - calculated_availability).abs < 1e-12 &&
    slo["total_budget"] == calculated_budget &&
    slo["remaining_budget"] == calculated_remaining &&
    eligible == 10_000 && bad == 8 && (target - 0.999).abs < 1e-12
  errors << "SLI/error-budget values must recompute to 99.92%, 10 total and 2 remaining" unless correct
else
  errors << "SLI eligible count must be positive"
end

alert = answer.fetch("alert", {})
errors << "page rule must require both long and short burn windows" unless alert["requires_long_and_short"] == true
errors << "a short transient spike must not page" unless alert["transient_pages"] == false
errors << "a sustained long-and-short-window burn must page" unless alert["sustained_pages"] == true
errors << "page alert must have an owner" if alert.fetch("owner", "").strip.empty?
errors << "page alert must have a runbook" if alert.fetch("runbook", "").strip.empty?

required_feedback = %w[detect triage mitigate recover learn verify]
unless (required_feedback - answer.fetch("incident_feedback", [])).empty?
  errors << "incident feedback must cover detect/triage/mitigate/recover/learn/verify"
end

privacy = answer.fetch("privacy", {})
errors << "forbidden secrets and full PII must be absent" unless privacy["forbidden_fields_absent"] == true
errors << "telemetry must enforce a field allowlist" unless privacy["field_allowlist_enforced"] == true

unless errors.empty?
  errors.each { |error| puts "ERROR: #{error}" }
  puts "EXERCISE_VERIFIER=RED (#{errors.length} violations)"
  exit 1
end

puts "log-trace-correlation: PASS"
puts "metric-cardinality: PASS"
puts "health-dependencies: PASS"
puts "sli-error-budget: PASS (99.92%, budget=10, remaining=2)"
puts "alert-actionability: PASS"
puts "incident-feedback: PASS"
puts "privacy-minimization: PASS"
puts "EXERCISE_VERIFIER=PASS"
