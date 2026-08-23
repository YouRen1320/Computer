# frozen_string_literal: true

require_relative "test_cases"
require_relative "work_order_amount"

# A deliberately incorrect implementation used only to prove that boundary
# oracles turn red. It rounds labor down instead of billing started blocks.
module FaultyRoundDownAmount
  module_function

  def quote(labor_minutes:, block_rate_cents:, parts_cents:)
    WorkOrderAmount.validate_inputs!(labor_minutes, block_rate_cents, parts_cents)
    blocks = labor_minutes / 30
    blocks * block_rate_cents + parts_cents
  end
end

class MiniRunner
  attr_reader :tests_run, :failures, :errors

  def initialize(calculator)
    @calculator = calculator
    @tests_run = 0
    @failures = []
    @errors = []
  end

  def run(cases)
    cases.each { |test_case| run_case(test_case) }
    self
  end

  def summary
    "Tests run: #{tests_run}, Failures: #{failures.length}, Errors: #{errors.length}"
  end

  private

  def run_case(test_case)
    @tests_run += 1
    actual = @calculator.quote(**test_case.fetch(:arrange))
    if test_case.key?(:expected_error)
      @failures << "#{test_case.fetch(:name)} expected #{test_case.fetch(:expected_error)}, but returned #{actual.inspect}"
    elsif actual != test_case.fetch(:expected)
      @failures << "#{test_case.fetch(:name)} expected=#{test_case.fetch(:expected)} actual=#{actual}"
    end
  rescue StandardError => error
    expected_error = test_case[:expected_error]
    return if expected_error && error.is_a?(expected_error)

    @errors << "#{test_case.fetch(:name)} #{error.class}: #{error.message}"
  end
end

fault_injected = ARGV == ["--inject-fault"]
abort "Usage: ruby run_tests.rb [--inject-fault]" unless ARGV.empty? || fault_injected

calculator = fault_injected ? FaultyRoundDownAmount : WorkOrderAmount
runner = MiniRunner.new(calculator).run(TEST_CASES)
runner.failures.each { |failure| puts "FAIL: #{failure}" }
runner.errors.each { |error| puts "ERROR: #{error}" }
puts runner.summary
exit(runner.failures.empty? && runner.errors.empty? ? 0 : 1)
