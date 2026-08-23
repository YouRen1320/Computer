# frozen_string_literal: true

require "digest"
require "json"
require "pathname"
require "timeout"
require "tmpdir"

RUBY = "/usr/bin/ruby"
ROOT = Pathname(__dir__)
PROGRAM = ROOT.join("child_probe.rb").freeze
CASES = ROOT.join("resource-cases.json").freeze
FIXED_ENV = {
  "HOME" => "/nonexistent/factorycare-home",
  "LANG" => "C",
  "LC_ALL" => "C",
  "PATH" => "/usr/bin:/bin",
  "TZ" => "UTC"
}.freeze

abort "process-model verification: FAIL: /usr/bin/ruby is unavailable" unless File.executable?(RUBY)
[PROGRAM, CASES].each do |path|
  abort "process-model verification: FAIL: missing or linked fixture #{path.basename}" unless path.file? && !path.symlink?
end

def wait_for_file(path)
  Timeout.timeout(3) do
    sleep 0.01 until path.file? && path.size.positive?
  end
end

def process_alive?(pid)
  Process.kill(0, pid)
  true
rescue Errno::ESRCH
  false
end

def run_child(program, directory, duration, label)
  record_path = Pathname(directory).join("#{label}.json")
  pid = Process.spawn(
    FIXED_ENV,
    RUBY,
    program.to_s,
    record_path.to_s,
    duration.to_s,
    label,
    unsetenv_others: true
  )
  wait_for_file(record_path)
  [pid, record_path, JSON.parse(record_path.read(encoding: "UTF-8"))]
end

def wait_for_child(pid)
  Timeout.timeout(3) { Process.wait(pid) }
rescue Timeout::Error
  Process.kill("TERM", pid) if process_alive?(pid)
  Process.wait(pid)
  abort "process-model verification: FAIL: child exceeded fixed duration"
end

program_digest_before = Digest::SHA256.file(PROGRAM).hexdigest
observed_pids = []

Dir.mktmpdir("factorycare-process-") do |directory|
  short_pid, short_record_path, short_record = run_child(PROGRAM, directory, 0.05, "short")
  observed_pids << short_pid
  abort "process-model verification: FAIL: short child PID mismatch" unless short_record.fetch("pid") == short_pid
  abort "process-model verification: FAIL: short child parent mismatch" unless short_record.fetch("ppid") == Process.pid
  wait_for_child(short_pid)
  abort "process-model verification: FAIL: short child still appears alive" if process_alive?(short_pid)

  sustained_pid, sustained_record_path, sustained_record = run_child(PROGRAM, directory, 0.40, "sustained")
  observed_pids << sustained_pid
  abort "process-model verification: FAIL: sustained child was not observable while running" unless process_alive?(sustained_pid)
  abort "process-model verification: FAIL: sustained PID mismatch" unless sustained_record.fetch("pid") == sustained_pid
  abort "process-model verification: FAIL: sustained parent mismatch" unless sustained_record.fetch("ppid") == Process.pid
  wait_for_child(sustained_pid)
  abort "process-model verification: FAIL: sustained child still appears alive" if process_alive?(sustained_pid)

  abort "process-model verification: FAIL: two launches reused one observed PID" unless observed_pids.uniq.length == 2
  abort "process-model verification: FAIL: process record was not stored as a file" unless short_record_path.file? && sustained_record_path.file?
end

program_digest_after = Digest::SHA256.file(PROGRAM).hexdigest
abort "process-model verification: FAIL: program bytes changed while processes ran" unless program_digest_before == program_digest_after

resource_cases = JSON.parse(CASES.read(encoding: "UTF-8"))
resource_cases.each do |item|
  actual = if item.fetch("disk_free_mib") < item.fetch("disk_required_mib")
             "disk"
           elsif item.fetch("resident_mib") >= item.fetch("memory_limit_mib") * 0.95
             "memory"
           elsif item.fetch("cpu_percent") >= 90
             "cpu"
           else
             "undetermined"
           end
  abort "process-model verification: FAIL: resource case #{item.fetch('id')} classified as #{actual}" unless actual == item.fetch("expected_bottleneck")
end

puts "program/process: one persistent program produced two distinct child PIDs"
puts "lifecycle: running children were observable; re-observation after wait produced expected absence"
puts "parent/child: both child records named the verifier PID as PPID"
puts "resources: fixed CPU, memory and disk cases remained distinct"
puts "process-model verification: PASS"
