# frozen_string_literal: true

require "open3"
require "pathname"
require "tmpdir"

GIT = "/usr/bin/git"
EVIDENCE = Pathname(__dir__).join("git-evidence.txt").freeze
PLACEHOLDER = "TRAINING_REVOKED_PLACEHOLDER"

abort "git collaboration lab: FAIL: fixed Git unavailable" unless File.executable?(GIT)
abort "git collaboration lab: FAIL: evidence missing or symlinked" unless EVIDENCE.file? && !EVIDENCE.symlink?

def expect(label, actual, expected)
  return if actual == expected

  abort "git collaboration lab: FAIL: #{label}\nexpected=#{expected.inspect}\nactual=#{actual.inspect}"
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

def parse_pairs(path)
  path.each_line(chomp: true).reject(&:empty?).to_h do |line|
    key, value = line.split("=", 2)
    abort "git collaboration lab: FAIL: malformed evidence line" if key.nil? || value.nil?
    [key, value]
  end
end

def write(path, content)
  Pathname(path).write(content, encoding: "UTF-8")
end

observed = {}

Dir.mktmpdir("factorycare-git-lab-") do |directory|
  root = Pathname(directory)
  repo = root.join("repo")
  home = root.join("home")
  repo.mkdir
  home.mkdir
  env = {
    "GIT_AUTHOR_DATE" => "2026-01-01T00:00:00Z",
    "GIT_COMMITTER_DATE" => "2026-01-01T00:00:00Z",
    "GIT_CONFIG_GLOBAL" => "/dev/null",
    "GIT_CONFIG_NOSYSTEM" => "1",
    "GIT_TERMINAL_PROMPT" => "0",
    "HOME" => home.to_s,
    "LANG" => "C",
    "LC_ALL" => "C",
    "PATH" => "/usr/bin:/bin",
    "TZ" => "UTC"
  }.freeze

  run_git(repo, env, "init", "--quiet", "--initial-branch=main")
  run_git(repo, env, "config", "user.name", "FactoryCare Training")
  run_git(repo, env, "config", "user.email", "training@example.invalid")

  work_order = repo.join("work-order.txt")
  write(work_order, "priority=normal\n")
  observed["untracked"] = run_git(repo, env, "status", "--porcelain=v1").first.chomp
  run_git(repo, env, "add", "--", "work-order.txt")
  observed["after_add"] = run_git(repo, env, "status", "--porcelain=v1").first.chomp
  run_git(repo, env, "commit", "--quiet", "-m", "Baseline")

  write(work_order, "priority=high\n")
  run_git(repo, env, "add", "--", "work-order.txt")
  write(work_order, "priority=urgent\n")
  observed["after_second_edit"] = run_git(repo, env, "status", "--porcelain=v1").first.chomp
  write(work_order, "priority=normal\n")
  run_git(repo, env, "restore", "--staged", "--", "work-order.txt")

  run_git(repo, env, "switch", "--quiet", "-c", "feature/safety")
  write(work_order, "priority=normal\nsafety=always-urgent\n")
  run_git(repo, env, "add", "--", "work-order.txt")
  run_git(repo, env, "commit", "--quiet", "-m", "Safety rule")
  run_git(repo, env, "switch", "--quiet", "main")
  write(work_order, "priority=urgent\nfallback=high\n")
  run_git(repo, env, "add", "--", "work-order.txt")
  run_git(repo, env, "commit", "--quiet", "-m", "Urgent threshold")
  _merge_out, _merge_err, merge_exit = run_git(repo, env, "merge", "--no-edit", "feature/safety", expected_exit: 1)
  observed["merge_exit"] = merge_exit.to_s
  observed["merge_status"] = run_git(repo, env, "status", "--porcelain=v1").first.chomp
  write(work_order, "priority=urgent\nsafety=always-urgent\nfallback=high\n")
  observed["resolved_rules"] = "priority=urgent;safety=always-urgent;fallback=high"
  run_git(repo, env, "add", "--", "work-order.txt")
  run_git(repo, env, "commit", "--quiet", "-m", "Preserve both rules")

  local_env = repo.join("local.env")
  write(local_env, "DEMO_TOKEN=#{PLACEHOLDER}\n")
  run_git(repo, env, "add", "--", "local.env")
  run_git(repo, env, "commit", "--quiet", "-m", "Training fixture")
  write(repo.join(".gitignore"), "local.env\n")
  run_git(repo, env, "add", "--", ".gitignore")
  run_git(repo, env, "commit", "--quiet", "-m", "Ignore future local config")
  write(local_env, "DEMO_TOKEN=#{PLACEHOLDER}_CHANGED\n")
  observed["tracked_after_ignore"] = run_git(repo, env, "status", "--porcelain=v1").first.chomp
  run_git(repo, env, "rm", "--cached", "--quiet", "--", "local.env")
  observed["after_rm_cached"] = run_git(repo, env, "status", "--porcelain=v1").first.chomp
  observed["worktree_copy"] = local_env.file? ? "present" : "missing"
  run_git(repo, env, "commit", "--quiet", "-m", "Stop tracking local config")
  old_value = run_git(repo, env, "show", "HEAD~1:local.env").first
  observed["old_history_contains_placeholder"] = old_value.include?(PLACEHOLDER) ? "yes" : "no"
  observed["credential_first_action"] = "simulate-revoke-or-rotate"
  observed["remote_count"] = run_git(repo, env, "remote").first.lines.length.to_s
end

expected = {
  "untracked" => "?? work-order.txt",
  "after_add" => "A  work-order.txt",
  "after_second_edit" => "MM work-order.txt",
  "merge_exit" => "1",
  "merge_status" => "UU work-order.txt",
  "resolved_rules" => "priority=urgent;safety=always-urgent;fallback=high",
  "tracked_after_ignore" => " M local.env",
  "after_rm_cached" => "D  local.env",
  "worktree_copy" => "present",
  "old_history_contains_placeholder" => "yes",
  "credential_first_action" => "simulate-revoke-or-rotate",
  "remote_count" => "0"
}.freeze

expect("scenario oracle", observed, expected)
submitted = parse_pairs(EVIDENCE)
expect("closed evidence keys", submitted.keys.sort, expected.keys.sort)
expected.each { |key, value| expect(key, submitted.fetch(key), value) }

puts "state evidence: working tree, index, commit, branch and merge matched"
puts "expected failures observed: conflict non-zero; tracked ignore; old snapshot retained"
puts "security evidence: simulated revoke/rotate first; remotes=0; no real credential"
puts "git collaboration lab: PASS"
