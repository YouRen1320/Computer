# frozen_string_literal: true

require "digest"
require "json"

# Produces stable bytes so a repeated review can be compared without timestamps.
module CanonicalJSON
  module_function

  def normalize(value)
    case value
    when Hash
      value.keys.sort.each_with_object({}) { |key, result| result[key] = normalize(value.fetch(key)) }
    when Array
      value.map { |item| normalize(item) }
    else
      value
    end
  end

  def dump(value)
    "#{JSON.generate(normalize(value))}\n"
  end

  def digest(value)
    Digest::SHA256.hexdigest(dump(value))
  end
end

# Keeps an isolated, in-memory worktree. Rejected candidates never mutate it.
class ProjectState
  attr_reader :files

  def initialize(files)
    @files = deep_copy(files)
  end

  def copy
    self.class.new(@files)
  end

  def digest
    CanonicalJSON.digest(@files)
  end

  def apply_hunk(hunk)
    path = hunk.fetch("path")
    case hunk.fetch("operation")
    when "replace"
      @files[path] = deep_copy(hunk.fetch("after"))
    when "delete"
      @files.delete(path)
    else
      raise ArgumentError, "unsupported operation #{hunk.fetch("operation")}"
    end
  end

  private

  def deep_copy(value)
    Marshal.load(Marshal.dump(value))
  end
end

# Rejects disallowed context before any model interaction. The detector is a
# small teaching guard, not a replacement for data classification or DLP.
class TaskBriefValidator
  def initialize(policy)
    @safe_classifications = policy.fetch("safe_context_classifications")
  end

  def validate(brief)
    reasons = []
    brief.fetch("context", []).each_with_index do |item, index|
      classification = item.fetch("classification", "unclassified")
      next if @safe_classifications.include?(classification)

      reasons << "context[#{index}] classification=#{classification} is not allowed"
    end
    reasons
  end
end

# Executes a deliberately narrow FactoryCare pricing model. Candidate content
# is data, never eval'ed Ruby or a shell command.
class QuoteOracle
  SOURCE_PATH = "src/quote_rule.json"
  BASELINE_PATH = "test/quote_rule_baseline_oracle.json"
  FEATURE_PATH = "test/zero_minutes_feature_oracle.json"

  def run(state)
    implementation = state.files.fetch(SOURCE_PATH)
    suites = [BASELINE_PATH, FEATURE_PATH].map do |path|
      suite = state.files.fetch(path)
      rows = suite.fetch("cases").map { |test_case| evaluate_case(implementation, test_case) }
      {
        "suite" => suite.fetch("suite"),
        "passed" => rows.all? { |row| row.fetch("passed") },
        "cases" => rows
      }
    end
    { "passed" => suites.all? { |suite| suite.fetch("passed") }, "suites" => suites }
  rescue KeyError => error
    { "passed" => false, "suites" => [], "error" => "missing required input: #{error.message}" }
  end

  private

  def evaluate_case(implementation, test_case)
    actual = quote(implementation, test_case.fetch("minutes"))
    expected = test_case.fetch("expected")
    {
      "name" => test_case.fetch("name"),
      "expected" => expected,
      "actual" => actual,
      "passed" => actual == expected
    }
  rescue ArgumentError => error
    expected_error = test_case["expected_error"]
    {
      "name" => test_case.fetch("name"),
      "expected_error" => expected_error,
      "actual_error" => error.message,
      "passed" => error.message == expected_error
    }
  end

  def quote(rule, minutes)
    if minutes.negative?
      raise ArgumentError, "minutes must be non-negative" if rule.fetch("negative_minutes") == "reject"
    end
    return rule.fetch("zero_minutes_amount") if minutes.zero?

    block_minutes = rule.fetch("block_minutes")
    rate = rule.fetch("amount_per_started_block")
    ((minutes + block_minutes - 1) / block_minutes) * rate
  end
end

# Reviews every candidate hunk before applying it to an isolated copy, then
# treats the independent oracle—not candidate prose—as the authority.
class CandidateReviewer
  def initialize(policy:, baseline:, brief:)
    @policy = policy
    @baseline = baseline
    @brief = brief
    @oracle = QuoteOracle.new
  end

  def review(candidate)
    initial_digest = @baseline.digest
    brief_reasons = TaskBriefValidator.new(@policy).validate(@brief)
    hunk_decisions = candidate.fetch("hunks").map { |hunk| review_hunk(hunk) }
    dependency_reasons = review_dependencies(candidate.fetch("dependency_changes", []))
    candidate_context_reasons = TaskBriefValidator.new(@policy).validate(
      "context" => candidate.fetch("context", [])
    )
    reasons = brief_reasons + candidate_context_reasons + dependency_reasons
    reasons.concat(hunk_decisions.flat_map { |decision| decision.fetch("reasons") })

    proposed = @baseline.copy
    oracle_result = nil
    if reasons.empty?
      candidate.fetch("hunks").each { |hunk| proposed.apply_hunk(hunk) }
      oracle_result = @oracle.run(proposed)
      reasons << "independent oracle rejected candidate" unless oracle_result.fetch("passed")
    end

    accepted = reasons.empty?
    finalize_hunk_decisions(hunk_decisions, accepted: accepted, oracle_result: oracle_result)
    final_state = accepted ? proposed : @baseline.copy
    {
      "candidate_id" => candidate.fetch("id"),
      "decision" => accepted ? "accept" : "reject",
      "claims_are_untrusted_input" => candidate.fetch("claims", []),
      "hunks" => hunk_decisions,
      "oracle" => oracle_result,
      "reasons" => reasons,
      "baseline_digest_before" => initial_digest,
      "worktree_digest_after" => final_state.digest,
      "worktree_unchanged" => final_state.digest == initial_digest
    }
  end

  def oracle(state = @baseline)
    @oracle.run(state)
  end

  def apply_accepted(candidate)
    result = review(candidate)
    raise "candidate #{candidate.fetch("id")} was not accepted" unless result.fetch("decision") == "accept"

    state = @baseline.copy
    candidate.fetch("hunks").each { |hunk| state.apply_hunk(hunk) }
    state
  end

  private

  def review_hunk(hunk)
    path = hunk.fetch("path")
    operation = hunk.fetch("operation")
    reasons = []
    reasons << "path #{path} is outside allowed task scope" unless @policy.fetch("allowed_paths").include?(path)
    reasons << "protected oracle #{path} must not change" if @policy.fetch("protected_paths").include?(path)
    reasons << "operation #{operation} is not allowed" unless @policy.fetch("allowed_operations").include?(operation)

    serialized = CanonicalJSON.dump(hunk)
    @policy.fetch("forbidden_tokens").each do |token|
      reasons << "hunk contains forbidden token #{token.inspect}" if serialized.include?(token)
    end
    if path == QuoteOracle::SOURCE_PATH && operation == "replace" && hunk.key?("after")
      actual_keys = hunk.fetch("after").keys.sort
      expected_keys = @policy.fetch("source_schema").sort
      reasons << "source schema changed from #{expected_keys.inspect} to #{actual_keys.inspect}" unless actual_keys == expected_keys
    end

    {
      "hunk_id" => hunk.fetch("id"),
      "path" => path,
      "decision" => reasons.empty? ? "eligible-for-oracle" : "reject",
      "reasons" => reasons
    }
  end

  def review_dependencies(changes)
    return [] if changes.empty?

    changes.map do |dependency|
      name = dependency.fetch("name", "unknown")
      provenance = dependency["provenance"] || "missing"
      license = dependency["license"] || "missing"
      "dependency #{name} is outside scope; provenance=#{provenance}, license=#{license}, manual review required"
    end
  end

  def finalize_hunk_decisions(decisions, accepted:, oracle_result:)
    decisions.each do |decision|
      next if decision.fetch("decision") == "reject"

      if accepted
        decision["decision"] = "accept"
        decision["reasons"] = ["scope, side-effect, schema, dependency, context, and independent oracle gates passed"]
      elsif oracle_result
        decision["decision"] = "reject"
        decision["reasons"] = ["independent oracle rejected the candidate behavior"]
      else
        decision["decision"] = "reject"
        decision["reasons"] = ["a candidate-level context, dependency, or sibling-hunk gate rejected the candidate before execution"]
      end
    end
  end
end
