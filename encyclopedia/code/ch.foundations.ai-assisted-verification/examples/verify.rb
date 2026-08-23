# frozen_string_literal: true

require "json"
require_relative "review_model"

ROOT = File.expand_path(__dir__)

def load_json(name)
  JSON.parse(File.read(File.join(ROOT, name)))
end

def assert(condition, message)
  raise "ASSERTION FAILED: #{message}" unless condition
end

policy = load_json("policy.json")
project = load_json("baseline_project.json")
brief = load_json("task_brief.json")
unsafe_brief = load_json("unsafe_task_brief.json")
candidates = load_json("candidates.json")
baseline = ProjectState.new(project.fetch("files"))
reviewer = CandidateReviewer.new(policy: policy, baseline: baseline, brief: brief)

assert(TaskBriefValidator.new(policy).validate(brief).empty?, "safe task brief should pass local classification")
unsafe_reasons = TaskBriefValidator.new(policy).validate(unsafe_brief)
assert(unsafe_reasons.any? { |reason| reason.include?("classification=secret") }, "secret-classified context must be rejected")
puts "prompt boundary: safe brief accepted; synthetic secret-classified brief rejected before model use"

baseline_oracle = reviewer.oracle
baseline_suite = baseline_oracle.fetch("suites").find { |suite| suite.fetch("suite") == "baseline-regression" }
feature_suite = baseline_oracle.fetch("suites").find { |suite| suite.fetch("suite") == "requested-feature" }
assert(baseline_suite.fetch("passed"), "known baseline regression suite must start green")
assert(!feature_suite.fetch("passed"), "pre-written feature oracle must start red")
puts "oracle before patch: baseline-regression=PASS requested-feature=FAIL(expected)"

expected = {
  "accepted-zero-fix" => "accept",
  "rejected-hidden-network" => "reject",
  "rejected-delete-negative-test" => "reject",
  "rejected-fabricated-success" => "reject",
  "rejected-unlicensed-dependency" => "reject"
}

first_run = candidates.map { |candidate| reviewer.review(candidate) }
second_run = candidates.map { |candidate| reviewer.review(candidate) }
assert(CanonicalJSON.digest(first_run) == CanonicalJSON.digest(second_run), "same inputs must produce the same review report")

first_run.each do |result|
  id = result.fetch("candidate_id")
  assert(result.fetch("decision") == expected.fetch(id), "#{id} decision should be #{expected.fetch(id)}")
  assert(result.fetch("hunks").all? { |hunk| %w[accept reject].include?(hunk.fetch("decision")) }, "#{id} must have a final decision for every hunk")
  assert(result.fetch("hunks").all? { |hunk| !hunk.fetch("reasons").empty? }, "#{id} must preserve a reason for every hunk decision")
  if result.fetch("decision") == "reject"
    assert(result.fetch("worktree_unchanged"), "rejected #{id} must not enter the worktree")
  end
  puts "candidate: #{id}=#{result.fetch("decision").upcase} reasons=#{result.fetch("reasons").length}"
end

hidden = first_run.find { |result| result.fetch("candidate_id") == "rejected-hidden-network" }
assert(hidden.fetch("reasons").any? { |reason| reason.include?("network_request") }, "hidden network request must be independently found")

deleted_test = first_run.find { |result| result.fetch("candidate_id") == "rejected-delete-negative-test" }
assert(deleted_test.fetch("reasons").any? { |reason| reason.include?("protected oracle") }, "deleted negative oracle must be found")

fabricated = first_run.find { |result| result.fetch("candidate_id") == "rejected-fabricated-success" }
assert(fabricated.fetch("claims_are_untrusted_input").any? { |claim| claim.include?("ALL TESTS PASS") }, "fixture must contain the fabricated success claim")
assert(fabricated.fetch("oracle") && !fabricated.fetch("oracle").fetch("passed"), "independent oracle must contradict fabricated success")

unlicensed = first_run.find { |result| result.fetch("candidate_id") == "rejected-unlicensed-dependency" }
assert(unlicensed.fetch("reasons").any? { |reason| reason.include?("manual review required") }, "unknown provenance/license must reach the dependency gate")

accepted_candidate = candidates.find { |candidate| candidate.fetch("id") == "accepted-zero-fix" }
accepted_state = reviewer.apply_accepted(accepted_candidate)
accepted_oracle = reviewer.oracle(accepted_state)
assert(accepted_oracle.fetch("passed"), "accepted isolated worktree must pass both suites")
assert(accepted_state.digest != baseline.digest, "accepted patch must actually change the worktree")
puts "accepted patch: baseline-regression=PASS requested-feature=PASS"

# Rollback restores exact bytes. The old regression suite remains green while
# the not-yet-applied feature becomes red again, proving the rollback was real.
rolled_back = baseline.copy
rollback_oracle = reviewer.oracle(rolled_back)
rollback_baseline = rollback_oracle.fetch("suites").find { |suite| suite.fetch("suite") == "baseline-regression" }
rollback_feature = rollback_oracle.fetch("suites").find { |suite| suite.fetch("suite") == "requested-feature" }
assert(rolled_back.digest == baseline.digest, "rollback must restore the exact baseline digest")
assert(rollback_baseline.fetch("passed"), "rollback must preserve the known-good regression baseline")
assert(!rollback_feature.fetch("passed"), "rolled-back feature oracle must become red again")
puts "rollback: digest=RESTORED baseline-regression=PASS requested-feature=FAIL(expected)"

puts "repeatability: review-report-sha256=#{CanonicalJSON.digest(first_run)}"
puts "ai-assisted-verification: PASS (offline fixtures only; no model, network, or credentials)"
