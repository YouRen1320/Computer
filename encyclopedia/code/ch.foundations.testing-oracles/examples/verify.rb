# frozen_string_literal: true

require "open3"
require "rbconfig"

runner = File.join(__dir__, "run_tests.rb")

def execute(runner, *arguments)
  Open3.capture3(RbConfig.ruby, runner, *arguments)
end

green_out, green_err, green_status = execute(runner)
abort "testing-oracles verification: FAIL: initial green run" unless green_status.success?
abort "testing-oracles verification: FAIL: initial summary" unless green_out.include?("Tests run: 8, Failures: 0, Errors: 0")
abort "testing-oracles verification: FAIL: unexpected initial stderr" unless green_err.empty?

red_out, red_err, red_status = execute(runner, "--inject-fault")
abort "testing-oracles verification: FAIL: injected fault stayed green" if red_status.success?
abort "testing-oracles verification: FAIL: wrong red summary" unless red_out.include?("Tests run: 8, Failures: 2, Errors: 0")
abort "testing-oracles verification: FAIL: boundary failure not located" unless red_out.include?("one-minute") && red_out.include?("thirty-one-minutes")
abort "testing-oracles verification: FAIL: unexpected red stderr" unless red_err.empty?

restored_out, restored_err, restored_status = execute(runner)
abort "testing-oracles verification: FAIL: restored run" unless restored_status.success?
abort "testing-oracles verification: FAIL: restored summary" unless restored_out.include?("Tests run: 8, Failures: 0, Errors: 0")
abort "testing-oracles verification: FAIL: unexpected restored stderr" unless restored_err.empty?

puts "green: Tests run=8 Failures=0 Errors=0 exit=0"
puts "red: injected round-down fault produced 2 boundary failures exit=1"
puts "green: restored implementation produced 8/0/0 exit=0"
puts "testing-oracles verification: PASS"
