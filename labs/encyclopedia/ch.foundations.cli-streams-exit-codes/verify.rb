# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

root = Pathname(__dir__)
probe = root.join("stream_probe.rb")
valid = root.join("fixtures/valid status.txt")
invalid = root.join("fixtures/invalid status.txt")
abort "cli-streams lab fixture: FAIL: unexpected symlink" if [probe, valid, invalid].any?(&:symlink?)
abort "cli-streams lab fixture: FAIL: probe changed" unless probe.file?
abort "cli-streams lab fixture: FAIL: valid fixture changed" unless valid.read == "IN_PROGRESS\n"
abort "cli-streams lab fixture: FAIL: invalid fixture changed" unless invalid.read == "CLOSED\n"

env = {
  "HOME" => "/nonexistent/factorycare-home",
  "LANG" => "C",
  "LC_ALL" => "C",
  "PATH" => "/usr/bin:/bin",
  "TZ" => "UTC"
}

Dir.mktmpdir("factorycare-stream-lab-") do |directory|
  work = Pathname(directory)
  FileUtils.cp(probe, work.join("stream_probe.rb"))
  FileUtils.cp(valid, work.join("valid status.txt"))
  FileUtils.cp(invalid, work.join("invalid status.txt"))

  stdout, stderr, status = Open3.capture3(
    env,
    "/bin/zsh",
    "-f",
    "-c",
    "/usr/bin/ruby stream_probe.rb < 'valid status.txt' > result.txt 2> diagnostic.txt",
    chdir: work.to_s,
    unsetenv_others: true
  )
  abort "cli-streams lab fixture: FAIL: valid command" unless status.success? && stdout.empty? && stderr.empty?
  abort "cli-streams lab fixture: FAIL: valid stdout" unless work.join("result.txt").read == "accepted=IN_PROGRESS\n"
  abort "cli-streams lab fixture: FAIL: valid stderr" unless work.join("diagnostic.txt").read.empty?

  stdout, stderr, status = Open3.capture3(
    env,
    "/bin/zsh",
    "-f",
    "-c",
    "setopt PIPE_FAIL; /usr/bin/ruby stream_probe.rb < 'invalid status.txt' 2> failure.txt | /usr/bin/true",
    chdir: work.to_s,
    unsetenv_others: true
  )
  abort "cli-streams lab fixture: FAIL: expected pipe failure missing" unless status.exitstatus == 65
  abort "cli-streams lab fixture: FAIL: unexpected pipeline output" unless stdout.empty? && stderr.empty?
  abort "cli-streams lab fixture: FAIL: diagnostic changed" unless work.join("failure.txt").read == "invalid status\n"
end

puts "fixture: valid and invalid status files fixed"
puts "streams: separated stdout/stderr and exit 0/65 observed"
puts "manual worksheet, requirement change and teach-back: NOT CHECKED"
puts "cli-streams lab fixture: PASS"
