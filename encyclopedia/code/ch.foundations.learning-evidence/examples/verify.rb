# frozen_string_literal: true

require "yaml"

begin
path = ARGV.fetch(0, "valid-ledger.yml")
abort "ledger verification: FAIL: file not found" unless File.file?(path)

ledger = YAML.safe_load(File.read(path, encoding: "UTF-8"), permitted_classes: [], aliases: false)
abort "ledger verification: FAIL: root must be a mapping" unless ledger.is_a?(Hash)

required = %w[schema_version claim scope evidence experiment artifact_exists mastery_decision boundary reviews]
missing = required.reject { |key| ledger.key?(key) }
abort "ledger verification: FAIL: missing #{missing.join(', ')}" unless missing.empty?

abort "ledger verification: FAIL: claim is too vague" unless ledger.fetch("claim").length >= 30
abort "ledger verification: FAIL: file existence cannot be the mastery decision" unless ledger["mastery_decision"] == "supported-for-stated-scope"

evidence = ledger.fetch("evidence")
%w[explain build diagnose].each do |kind|
  entry = evidence[kind]
  abort "ledger verification: FAIL: missing evidence.#{kind}" unless entry.is_a?(Hash)
  abort "ledger verification: FAIL: #{kind} was not observed" unless entry["status"] == "observed"
  abort "ledger verification: FAIL: #{kind} task is empty" if entry["task"].to_s.strip.empty?
end

experiment = ledger.fetch("experiment")
%w[input prediction observation first_trustworthy_evidence repair rerun].each do |key|
  abort "ledger verification: FAIL: experiment.#{key} is empty" if experiment[key].to_s.strip.empty?
end
abort "ledger verification: FAIL: rerun did not pass" unless experiment["rerun"] == "pass"
abort "ledger verification: FAIL: unverified boundary is missing" unless Array(ledger["boundary"]).length >= 1

days = Array(ledger["reviews"]).map { |entry| entry.is_a?(Hash) ? entry["day"] : nil }
abort "ledger verification: FAIL: review days must be 1,3,7" unless days == [1, 3, 7]
abort "ledger verification: FAIL: retrieval prompt is missing" unless ledger["reviews"].all? { |entry| entry["retrieval"].to_s.length >= 10 }

puts "claim: scoped"
puts "evidence: explain/build/diagnose observed"
puts "rerun: pass"
puts "boundary: declared"
puts "reviews: 1/3/7"
puts "ledger verification: PASS"
rescue Psych::Exception => e
  abort "ledger verification: FAIL: invalid YAML (#{e.class})"
end
