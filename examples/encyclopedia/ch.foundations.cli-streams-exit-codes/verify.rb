# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

RUBY = "/usr/bin/ruby"
ZSH = "/bin/zsh"
SOURCE = Pathname(__dir__).join("stream_probe.rb").freeze
FIXED_ENV = {
  "HOME" => "/nonexistent/factorycare-home",
  "LANG" => "C",
  "LC_ALL" => "C",
  "PATH" => "/usr/bin:/bin",
  "TZ" => "UTC"
}.freeze

abort "cli-streams verification: FAIL: fixed Ruby unavailable" unless File.executable?(RUBY)
abort "cli-streams verification: FAIL: fixed zsh unavailable" unless File.executable?(ZSH)
abort "cli-streams verification: FAIL: probe missing or symlinked" unless SOURCE.file? && !SOURCE.symlink?

def expect(label, actual, expected)
  return if actual == expected

  abort "cli-streams verification: FAIL: #{label}\nexpected=#{expected.inspect}\nactual=#{actual.inspect}"
end

def run_probe(input, directory)
  Open3.capture3(
    FIXED_ENV,
    RUBY,
    "stream_probe.rb",
    stdin_data: input,
    chdir: directory,
    unsetenv_others: true
  )
end

def run_zsh(script, directory)
  Open3.capture3(
    FIXED_ENV,
    ZSH,
    "-f",
    "-c",
    script,
    chdir: directory,
    unsetenv_others: true
  )
end

Dir.mktmpdir("factorycare-streams-") do |directory|
  root = Pathname(directory)
  FileUtils.cp(SOURCE, root.join("stream_probe.rb"))
  root.join("valid status.txt").write("IN_PROGRESS\n", encoding: "UTF-8")
  root.join("invalid status.txt").write("CLOSED\n", encoding: "UTF-8")

  stdout, stderr, status = run_probe("ASSIGNED\n", root.to_s)
  expect("valid stdout", stdout, "accepted=ASSIGNED\n")
  expect("valid stderr", stderr, "")
  expect("valid exit", status.exitstatus, 0)

  stdout, stderr, status = run_probe("CLOSED\n", root.to_s)
  expect("invalid stdout", stdout, "")
  expect("invalid stderr", stderr, "invalid status\n")
  expect("invalid exit", status.exitstatus, 65)

  stdout, stderr, status = run_probe("", root.to_s)
  expect("empty stdout", stdout, "")
  expect("empty stderr", stderr, "missing status\n")
  expect("empty exit", status.exitstatus, 64)

  stdout, stderr, status = run_zsh(
    "/usr/bin/ruby stream_probe.rb < 'valid status.txt' > result.txt 2> diagnostic.txt; " \
    "/usr/bin/printf 'child_status=%s\\n' $?",
    root.to_s
  )
  expect("redirection controller status", status.exitstatus, 0)
  expect("redirection shell stdout", stdout, "child_status=0\n")
  expect("redirection shell stderr", stderr, "")
  expect("redirected stdout file", root.join("result.txt").read, "accepted=IN_PROGRESS\n")
  expect("redirected stderr file", root.join("diagnostic.txt").read, "")

  root.join("append.txt").write("header\n", encoding: "UTF-8")
  stdout, stderr, status = run_zsh(
    "/usr/bin/ruby stream_probe.rb < 'valid status.txt' >> append.txt 2> append.err; " \
    "/usr/bin/ruby stream_probe.rb < 'valid status.txt' >> append.txt 2>> append.err",
    root.to_s
  )
  expect("append controller status", status.exitstatus, 0)
  expect("append controller stdout", stdout, "")
  expect("append controller stderr", stderr, "")
  expect("append content", root.join("append.txt").read, "header\naccepted=IN_PROGRESS\naccepted=IN_PROGRESS\n")
  expect("append diagnostic", root.join("append.err").read, "")

  stdout, stderr, status = run_zsh(
    "/usr/bin/ruby stream_probe.rb < 'invalid status.txt' 2> producer.err | /usr/bin/true; " \
    "/usr/bin/printf 'pipeline_status=%s\\n' $?",
    root.to_s
  )
  expect("default pipeline controller status", status.exitstatus, 0)
  expect("default pipeline masks producer", stdout, "pipeline_status=0\n")
  expect("default pipeline shell stderr", stderr, "")
  expect("producer diagnostic retained", root.join("producer.err").read, "invalid status\n")

  stdout, stderr, status = run_zsh(
    "setopt PIPE_FAIL; " \
    "/usr/bin/ruby stream_probe.rb < 'invalid status.txt' 2> pipefail.err | /usr/bin/true; " \
    "result=$?; /usr/bin/printf 'pipeline_status=%s\\n' $result; exit $result",
    root.to_s
  )
  expect("pipefail status", status.exitstatus, 65)
  expect("pipefail visible status", stdout, "pipeline_status=65\n")
  expect("pipefail shell stderr", stderr, "")
  expect("pipefail producer diagnostic", root.join("pipefail.err").read, "invalid status\n")

  stdout, stderr, status = run_zsh(
    "/usr/bin/false && /usr/bin/printf 'wrong\\n'; " \
    "/usr/bin/false || /usr/bin/printf 'recovered\\n'",
    root.to_s
  )
  expect("short-circuit status", status.exitstatus, 0)
  expect("short-circuit output", stdout, "recovered\n")
  expect("short-circuit diagnostic", stderr, "")
end

puts "streams: valid stdout/0; invalid and empty stderr/non-zero observed"
puts "redirection: overwrite, append and separated diagnostics observed"
puts "expected failures: invalid=65; empty=64; default pipeline masks; PIPE_FAIL exposes"
puts "short-circuit: failed && skipped; failed || continued"
puts "cli-streams verification: PASS"
