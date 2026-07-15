#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "optparse"
require "pathname"
require "stringio"
require "tempfile"
require "time"
require "yaml"

require_relative "lib/curriculum_compiler"

options = {}
OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/finalize-curriculum-migration.rb --plan-evidence PATH --output curriculum/migrations/receipts/NAME.yml --write-exit 0 --applied-at YYYY-MM-DDTHH:MM:SSZ --applied-by ACTOR"
  parser.on("--plan-evidence PATH", "evidence captured before the ready write") { |value| options[:plan_evidence] = value }
  parser.on("--output PATH", "new application receipt") { |value| options[:output] = value }
  parser.on("--write-exit CODE", Integer, "exit code from the explicit ready write") { |value| options[:write_exit] = value }
  parser.on("--applied-at VALUE", "explicit UTC timestamp") { |value| options[:applied_at] = value }
  parser.on("--applied-by VALUE", "explicit human/automation actor") { |value| options[:applied_by] = value }
end.parse!

required = %i[plan_evidence output write_exit applied_at applied_by]
missing = required.reject { |key| options.key?(key) && !options[key].to_s.empty? }
abort "missing required options: #{missing.join(', ')}" unless missing.empty?
abort "--write-exit must be 0" unless options[:write_exit] == 0
valid_timestamp = begin
  parsed_timestamp = Time.iso8601(options[:applied_at])
  options[:applied_at].match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/) && parsed_timestamp.utc? && parsed_timestamp.iso8601 == options[:applied_at]
rescue ArgumentError
  false
end
abort "--applied-at must be a real UTC timestamp in YYYY-MM-DDTHH:MM:SSZ form" unless valid_timestamp
actor = options[:applied_by]
valid_actor = !actor.strip.empty? && actor == actor.strip && actor.each_codepoint.none? { |codepoint| codepoint < 0x20 || codepoint == 0x7f }
abort "--applied-by must be non-blank, trimmed, and free of control characters" unless valid_actor

root = File.expand_path("..", __dir__)
relative_output = Pathname.new(File.expand_path(options.fetch(:output), root)).relative_path_from(Pathname.new(root)).to_s
unless relative_output.match?(%r{\Acurriculum/migrations/receipts/[a-z0-9][a-z0-9.-]*\.yml\z})
  abort "--output must be a normalized receipt path under curriculum/migrations/receipts/"
end
output = File.join(root, relative_output)
abort "refusing to overwrite existing receipt: #{output}" if File.exist?(output) || File.symlink?(output)

spec = Curriculum::SpecSet.new(root).load!
abort "migration must remain ready while finalizing" unless spec.migration["status"] == "ready"
compiler = Curriculum::Compiler.new(spec)
outputs = compiler.render_outputs

plan_path = File.expand_path(options.fetch(:plan_evidence), root)
plan_evidence = Curriculum::StrictYaml.load(File.binread(plan_path).force_encoding(Encoding::UTF_8), display_path: plan_path)
expected_plan = Curriculum::MigrationReceipt.expected_ready_plan(spec, outputs)
unless plan_evidence.is_a?(Hash) && plan_evidence.keys.sort == %w[migration_id plan ready_catalog_projection_digest schema_version].sort &&
    plan_evidence["schema_version"] == 1 && plan_evidence["migration_id"] == spec.migration["migration_id"] &&
    plan_evidence["ready_catalog_projection_digest"] == spec.migration.fetch("source_rebuilds").first.fetch("rendered_catalog_projection_digest") &&
    plan_evidence["plan"] == expected_plan
  abort "plan evidence does not match the frozen ready migration"
end

check_out = StringIO.new
check_err = StringIO.new
check_exit = Curriculum::Generator.new(root: root, mode: :check, out: check_out, err: check_err).run
abort "strict generated-tree check failed:\n#{check_err.string}" unless check_exit.zero?

legacy_count = Dir.glob(File.join(root, "book", "volume-*", "chapters", "v*.md")).count { |path| File.file?(path) }
semantic_count = Dir.glob(File.join(root, "book", "volume-*", "chapters", "ch.*.md")).count { |path| File.file?(path) }
abort "postcondition failed: legacy chapters=#{legacy_count}" unless legacy_count.zero?
abort "postcondition failed: semantic chapters=#{semantic_count}" unless semantic_count == spec.migration["expected_active_id_count"]

receipt = Curriculum::MigrationReceipt.build(
  spec: spec,
  plan: expected_plan,
  outputs: outputs,
  applied_at: options.fetch(:applied_at),
  applied_by: options.fetch(:applied_by),
  write_exit_code: options.fetch(:write_exit),
  check_exit_code: check_exit
)
schema_errors = Curriculum::JsonSchema.new(spec.application_receipt_schema).validate(receipt)
abort "generated receipt failed schema: #{schema_errors.map(&:message).join('; ')}" unless schema_errors.empty?

body = Psych.dump(receipt, nil, line_width: -1)
Curriculum::StrictYaml.load(body, display_path: relative_output)
FileUtils.mkdir_p(File.dirname(output))
temp = Tempfile.new([".migration-receipt-", ".yml"], File.dirname(output))
begin
  temp.binmode
  temp.write(body)
  temp.flush
  temp.fsync
  temp.close
  File.rename(temp.path, output)
ensure
  temp.close! if temp
end

puts "MIGRATION APPLICATION RECEIPT OK"
puts "path=#{relative_output}"
puts "digest=sha256:#{Digest::SHA256.hexdigest(body)}"
puts "next=add application_receipt_path/digest to the ledger and change status ready -> applied"
