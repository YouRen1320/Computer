# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

GIT = "/usr/bin/git"
PLACEHOLDER = "TRAINING_REVOKED_PLACEHOLDER"
FIXED_DATES = {
  "GIT_AUTHOR_DATE" => "2026-01-01T00:00:00Z",
  "GIT_COMMITTER_DATE" => "2026-01-01T00:00:00Z"
}.freeze

abort "git collaboration example: FAIL: fixed Git unavailable" unless File.executable?(GIT)

def expect(label, actual, expected)
  return if actual == expected

  abort "git collaboration example: FAIL: #{label}\nexpected=#{expected.inspect}\nactual=#{actual.inspect}"
end

def run_git(repo, env, *arguments, expected_exit: 0)
  stdout, stderr, status = Open3.capture3(
    env,
    GIT,
    "-c",
    "core.hooksPath=/dev/null",
    *arguments,
    chdir: repo.to_s,
    unsetenv_others: true
  )
  expect("git #{arguments.first} exit", status.exitstatus, expected_exit)
  [stdout, stderr, status.exitstatus]
end

def write(path, content)
  Pathname(path).write(content, encoding: "UTF-8")
end

Dir.mktmpdir("factorycare-git-example-") do |directory|
  root = Pathname(directory)
  repo = root.join("repo")
  home = root.join("home")
  repo.mkdir
  home.mkdir
  env = {
    "GIT_CONFIG_NOSYSTEM" => "1",
    "GIT_CONFIG_GLOBAL" => "/dev/null",
    "GIT_TERMINAL_PROMPT" => "0",
    "HOME" => home.to_s,
    "LANG" => "C",
    "LC_ALL" => "C",
    "PATH" => "/usr/bin:/bin",
    "TZ" => "UTC"
  }.merge(FIXED_DATES).freeze

  run_git(repo, env, "init", "--quiet", "--initial-branch=main")
  run_git(repo, env, "config", "user.name", "FactoryCare Training")
  run_git(repo, env, "config", "user.email", "training@example.invalid")
  expect("no remote", run_git(repo, env, "remote").first, "")

  work_order = repo.join("work-order.txt")
  write(work_order, "priority=normal\n")
  expect("untracked", run_git(repo, env, "status", "--porcelain=v1").first, "?? work-order.txt\n")
  run_git(repo, env, "add", "--", "work-order.txt")
  expect("staged add", run_git(repo, env, "status", "--porcelain=v1").first, "A  work-order.txt\n")
  expect("cached path", run_git(repo, env, "diff", "--cached", "--name-only").first, "work-order.txt\n")
  run_git(repo, env, "commit", "--quiet", "-m", "Add baseline priority")
  expect("baseline clean", run_git(repo, env, "status", "--porcelain=v1").first, "")

  write(work_order, "priority=high\n")
  run_git(repo, env, "add", "--", "work-order.txt")
  write(work_order, "priority=urgent\n")
  expect("staged plus unstaged", run_git(repo, env, "status", "--porcelain=v1").first, "MM work-order.txt\n")
  expect("cached sees high", run_git(repo, env, "diff", "--cached").first.include?("+priority=high"), true)
  expect("working diff sees urgent", run_git(repo, env, "diff").first.include?("+priority=urgent"), true)
  write(work_order, "priority=normal\n")
  run_git(repo, env, "restore", "--staged", "--", "work-order.txt")
  expect("restored baseline", run_git(repo, env, "status", "--porcelain=v1").first, "")

  run_git(repo, env, "switch", "--quiet", "-c", "feature/safety-rule")
  write(work_order, "priority=normal\nsafety=always-urgent\n")
  run_git(repo, env, "add", "--", "work-order.txt")
  run_git(repo, env, "commit", "--quiet", "-m", "Add safety priority rule")
  run_git(repo, env, "switch", "--quiet", "main")
  write(work_order, "priority=urgent\nfallback=high\n")
  run_git(repo, env, "add", "--", "work-order.txt")
  run_git(repo, env, "commit", "--quiet", "-m", "Raise ordinary priority")

  merge_stdout, merge_stderr, merge_exit = run_git(
    repo,
    env,
    "merge",
    "--no-edit",
    "feature/safety-rule",
    expected_exit: 1
  )
  expect("expected conflict diagnostic", (merge_stdout + merge_stderr).include?("CONFLICT"), true)
  expect("expected conflict exit", merge_exit, 1)
  expect("unmerged status", run_git(repo, env, "status", "--porcelain=v1").first, "UU work-order.txt\n")
  conflicted = work_order.read
  expect("current side retained in markers", conflicted.include?("priority=urgent"), true)
  expect("feature side retained in markers", conflicted.include?("safety=always-urgent"), true)

  write(work_order, "priority=urgent\nsafety=always-urgent\nfallback=high\n")
  run_git(repo, env, "add", "--", "work-order.txt")
  expect("conflict markers removed", work_order.read.match?(/^(<<<<<<<|=======|>>>>>>>)/), false)
  run_git(repo, env, "commit", "--quiet", "-m", "Merge safety and threshold rules")
  expect("merge clean", run_git(repo, env, "status", "--porcelain=v1").first, "")

  local_env = repo.join("local.env")
  write(local_env, "DEMO_TOKEN=#{PLACEHOLDER}\n")
  run_git(repo, env, "add", "--", "local.env")
  run_git(repo, env, "commit", "--quiet", "-m", "Add training configuration fixture")
  write(repo.join(".gitignore"), "local.env\n")
  run_git(repo, env, "add", "--", ".gitignore")
  run_git(repo, env, "commit", "--quiet", "-m", "Ignore future local configuration")

  write(local_env, "DEMO_TOKEN=#{PLACEHOLDER}_CHANGED\n")
  expect("expected failure: tracked file still reported", run_git(repo, env, "status", "--porcelain=v1").first, " M local.env\n")
  _ignored_stdout, _ignored_stderr, ignored_exit = run_git(
    repo,
    env,
    "check-ignore",
    "--",
    "local.env",
    expected_exit: 1
  )
  expect("expected failure: tracked path not ordinary ignore candidate", ignored_exit, 1)

  run_git(repo, env, "rm", "--cached", "--quiet", "--", "local.env")
  expect("cached removal staged", run_git(repo, env, "status", "--porcelain=v1").first, "D  local.env\n")
  expect("working file retained", local_env.file?, true)
  run_git(repo, env, "commit", "--quiet", "-m", "Stop tracking local configuration")
  expect("latest status hides ignored working copy", run_git(repo, env, "status", "--porcelain=v1").first, "")
  expect("working copy still retained", local_env.read, "DEMO_TOKEN=#{PLACEHOLDER}_CHANGED\n")

  previous = run_git(repo, env, "show", "HEAD~1:local.env").first
  expect("expected failure: old history still contains placeholder", previous, "DEMO_TOKEN=#{PLACEHOLDER}\n")
  response = root.join("credential-response.txt")
  write(response, "value_recorded=no\nprovider_action=simulated-revoke-before-cleanup\nremote_contacted=no\n")
  expect("response never records placeholder", response.read.include?(PLACEHOLDER), false)
  expect("no remote after scenario", run_git(repo, env, "remote").first, "")
end

puts "state: working tree, index, commits and branch references observed"
puts "expected failure: merge conflict returned non-zero before both rules were preserved"
puts "expected failure: .gitignore did not cancel existing tracking"
puts "expected failure: current deletion did not erase the previous snapshot"
puts "security: simulated revoke/rotate action preceded cleanup; no remote or real credential used"
puts "git collaboration example: PASS"
