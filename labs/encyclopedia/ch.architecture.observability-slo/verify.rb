#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

def check(condition, message)
  raise message unless condition
end

faults = JSON.parse(File.read(ARGV.fetch(0), encoding: "UTF-8")).fetch("faults")
expected_ids = %w[
  log-missing-trace
  metric-high-cardinality
  async-trace-break
  liveness-external-dependency
  sli-denominator-omits-system-errors
  transient-spike-pages
]
check(faults.map { |fault| fault.fetch("id") } == expected_ids, "fault set/order differs")

faults.each do |fault|
  id = fault.fetch("id")
  injected = fault.fetch("injected")
  check(!fault.fetch("diagnosis").strip.empty?, "#{id} has no diagnosis")
  check(!fault.fetch("repair").strip.empty?, "#{id} has no repair")
  check(!fault.fetch("replay_assertion").strip.empty?, "#{id} has no replay assertion")

  case id
  when "log-missing-trace"
    fields = injected.fetch("log_fields")
    check(!fields.include?("trace_id") && !fields.include?("span_id"), "missing-trace fault is not injected")
  when "metric-high-cardinality"
    labels = injected.fetch("labels")
    check((labels & %w[trace_id work_order_id]).sort == %w[trace_id work_order_id], "high-cardinality labels are absent")
  when "async-trace-break"
    check(injected["consumer_parent_span_id"].nil? && injected.fetch("consumer_links").empty?, "async trace is still connected")
  when "liveness-external-dependency"
    check(injected.fetch("liveness_external_dependencies").include?("postgres"), "external liveness dependency is absent")
    check(injected.fetch("on_postgres_down") == "RESTART_ALL_INSTANCES", "restart-storm consequence is absent")
  when "sli-denominator-omits-system-errors"
    check(injected.fetch("eligible_requests") + injected.fetch("system_errors") == injected.fetch("observed_requests"),
          "fixture does not prove omitted system errors")
    check(injected.fetch("excluded_outcomes").include?("system_error"), "system errors are not excluded")
  when "transient-spike-pages"
    long = injected.fetch("long_window_burn_rate")
    short = injected.fetch("short_window_burn_rate")
    threshold = injected.fetch("threshold")
    check(long < threshold && short >= threshold && injected.fetch("configured_page"), "transient page fault is not injected")
  else
    raise "unknown fault: #{id}"
  end

  puts "#{id}: RED detected; repair and replay assertion present"
end

puts "fault-lab: PASS (6 injected failures are detectable)"
