# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

RUBY = "/usr/bin/ruby"
ZSH = "/bin/zsh"
SOURCE = Pathname(__dir__).join("workspace").freeze
EVIDENCE = Pathname(__dir__).join("navigation-evidence.txt").freeze
PROBLEMS = Pathname(__dir__).join("problems.txt").freeze
FIXED_ENV = {
  "HOME" => "/nonexistent/factorycare-home",
  "LANG" => "C",
  "LC_ALL" => "C",
  "PATH" => "/usr/bin:/bin",
  "TZ" => "UTC"
}.freeze

abort "editor navigation lab: FAIL: fixed Ruby unavailable" unless File.executable?(RUBY)
abort "editor navigation lab: FAIL: fixed zsh unavailable" unless File.executable?(ZSH)
[SOURCE, EVIDENCE, PROBLEMS].each do |path|
  abort "editor navigation lab: FAIL: missing or symlinked input" unless path.exist? && !path.symlink?
end

def parse_pairs(path)
  path.each_line(chomp: true).reject(&:empty?).to_h do |line|
    key, value = line.split("=", 2)
    abort "editor navigation lab: FAIL: malformed evidence line" if key.nil? || value.nil?
    [key, value]
  end
end

def expect(label, actual, expected)
  return if actual == expected

  abort "editor navigation lab: FAIL: #{label}\nexpected=#{expected.inspect}\nactual=#{actual.inspect}"
end

expected = {
  "project_root" => "workspace",
  "root_marker" => ".factorycare-root",
  "source_definition" => "src/main/java/com/factorycare/navigation/WorkOrderLabel.java:5",
  "test_reference" => "src/test/java/com/factorycare/navigation/WorkOrderLabelTest.java:6",
  "generated_candidate" => "target/generated-sources/com/factorycare/navigation/WorkOrderLabel.java",
  "wrong_root_marker" => "missing",
  "problem_producer" => "javac",
  "first_credible_location" => "workspace/src/test/java/com/factorycare/navigation/WorkOrderLabelTest.java:6:30",
  "generated_action" => "do-not-edit"
}.freeze

Dir.mktmpdir("factorycare-editor-lab-") do |directory|
  temp = Pathname(directory)
  root = temp.join("workspace")
  FileUtils.cp_r(SOURCE, root, preserve: false)
  generated = root.join("target/generated-sources/com/factorycare/navigation/WorkOrderLabel.java")
  generated.dirname.mkpath
  generated.write(<<~JAVA)
    package com.factorycare.navigation;

    final class WorkOrderLabel {
        // DERIVED_DO_NOT_EDIT: generated navigation decoy
        static String label(String status) {
            return "generated-work-order:" + status;
        }
    }
  JAVA
  FileUtils.cp(EVIDENCE, temp.join("navigation-evidence.txt"))
  FileUtils.cp(PROBLEMS, temp.join("problems.txt"))

  stdout, stderr, status = Open3.capture3(
    FIXED_ENV,
    ZSH,
    "-f",
    "-c",
    "/bin/pwd -P",
    chdir: root.to_s,
    unsetenv_others: true
  )
  expect("root shell exit", status.exitstatus, 0)
  expect("root shell stderr", stderr, "")
  expect("root shell stdout", stdout, "#{root.realpath}\n")
  expect("root marker exists", root.join(".factorycare-root").file?, true)
  expect("expected failure boundary: src is not root", root.join("src/.factorycare-root").exist?, false)

  source_text = root.join("src/main/java/com/factorycare/navigation/WorkOrderLabel.java").read
  generated_text = generated.read
  expect("source role", source_text.include?("SOURCE_OF_TRUTH"), true)
  expect("generated role", generated_text.include?("DERIVED_DO_NOT_EDIT"), true)

  actual = parse_pairs(temp.join("navigation-evidence.txt"))
  expect("closed evidence keys", actual.keys.sort, expected.keys.sort)
  expected.each { |key, value| expect(key, actual.fetch(key), value) }
end

puts "navigation evidence: root, definition, reference, problem and generated boundary matched"
puts "expected failure observed: workspace/src has no root marker"
puts "editor navigation lab: PASS"
