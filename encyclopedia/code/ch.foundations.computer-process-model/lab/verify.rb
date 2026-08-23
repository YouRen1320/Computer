# frozen_string_literal: true

require "json"
require "pathname"
require "timeout"
require "tmpdir"

program = Pathname(__dir__).join("child_probe.rb")
abort "process-model lab fixture: FAIL: child probe missing or linked" unless program.file? && !program.symlink?

def alive?(pid)
  Process.kill(0, pid)
  true
rescue Errno::ESRCH
  false
end

Dir.mktmpdir("factorycare-process-lab-") do |directory|
  record_path = File.join(directory, "record.json")
  env = { "HOME" => "/nonexistent/factorycare-home", "LANG" => "C", "LC_ALL" => "C", "PATH" => "/usr/bin:/bin", "TZ" => "UTC" }
  pid = Process.spawn(env, "/usr/bin/ruby", program.to_s, record_path, "0.30", unsetenv_others: true)
  Timeout.timeout(3) { sleep 0.01 until File.file?(record_path) && File.size(record_path).positive? }
  record = JSON.parse(File.read(record_path, encoding: "UTF-8"))
  abort "process-model lab fixture: FAIL: live PID mismatch" unless alive?(pid) && record.fetch("pid") == pid
  abort "process-model lab fixture: FAIL: parent PID mismatch" unless record.fetch("ppid") == Process.pid
  Timeout.timeout(3) { Process.wait(pid) }
  abort "process-model lab fixture: FAIL: process remained alive after wait" if alive?(pid)
end

puts "lifecycle: created -> running -> exited observed"
puts "parent/child: child PPID matched verifier PID"
puts "expected failure: exited PID is no longer observable as live"
puts "manual resource diagnosis and teach-back: NOT CHECKED"
puts "process-model lab fixture: PASS"
