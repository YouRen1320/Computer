# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

RUBY = "/usr/bin/ruby"
ZSH = "/bin/zsh"
SOURCE = Pathname(__dir__).join("sample-project").freeze
MAP = Pathname(__dir__).join("navigation-map.txt").freeze
FIXED_ENV = {
  "HOME" => "/nonexistent/factorycare-home",
  "LANG" => "C",
  "LC_ALL" => "C",
  "PATH" => "/usr/bin:/bin",
  "TZ" => "UTC"
}.freeze

abort "editor navigation example: FAIL: fixed Ruby unavailable" unless File.executable?(RUBY)
abort "editor navigation example: FAIL: fixed zsh unavailable" unless File.executable?(ZSH)
abort "editor navigation example: FAIL: sample missing or symlinked" unless SOURCE.directory? && !SOURCE.symlink?
abort "editor navigation example: FAIL: map missing or symlinked" unless MAP.file? && !MAP.symlink?

def expect(label, actual, expected)
  return if actual == expected

  abort "editor navigation example: FAIL: #{label}\nexpected=#{expected.inspect}\nactual=#{actual.inspect}"
end

def relative_files(root)
  root.glob("**/*", File::FNM_DOTMATCH)
      .select(&:file?)
      .reject(&:symlink?)
      .map { |path| path.relative_path_from(root).to_s }
      .sort
end

Dir.mktmpdir("factorycare-editor-example-") do |directory|
  temp = Pathname(directory)
  root = temp.join("sample-project")
  FileUtils.cp_r(SOURCE, root, preserve: false)

  expected_files = [
    ".factorycare-root",
    "src/main/java/com/factorycare/navigation/DeviceStatusFormatter.java",
    "src/test/java/com/factorycare/navigation/DeviceStatusFormatterTest.java",
    "target/generated-sources/com/factorycare/navigation/DeviceStatusFormatter.java"
  ]
  expect("closed file inventory", relative_files(root), expected_files)

  stdout, stderr, status = Open3.capture3(
    FIXED_ENV,
    ZSH,
    "-f",
    "-c",
    "/bin/pwd -P",
    chdir: root.to_s,
    unsetenv_others: true
  )
  expect("root observation exit", status.exitstatus, 0)
  expect("root observation stderr", stderr, "")
  expect("root observation stdout", stdout, "#{root.realpath}\n")

  production = root.join(expected_files[1])
  test = root.join(expected_files[2])
  generated = root.join(expected_files[3])
  expect("root marker", root.join(".factorycare-root").read, "training-project=editor-navigation\n")
  expect("production role marker", production.read.include?("SOURCE_OF_TRUTH"), true)
  expect("test role marker", test.read.include?("TEST_REFERENCE"), true)
  expect("generated role marker", generated.read.include?("DERIVED_DO_NOT_EDIT"), true)

  candidates = [production, test, generated].select { |path| path.read.include?("DeviceStatusFormatter") }
  expect("filename/text candidate count", candidates.length, 3)
  semantic_sources = candidates.reject { |path| path.to_s.include?("/target/") }
  expect("source and test semantic scope", semantic_sources.map { |path| path.relative_path_from(root).to_s }, expected_files[1, 2])

  wrong_root = root.join("src")
  expect("expected failure: wrong root lacks marker", wrong_root.join(".factorycare-root").exist?, false)
  expect("expected failure: generated is not source of truth", generated.read.include?("SOURCE_OF_TRUTH"), false)

  expect("sample input unchanged", relative_files(root), expected_files)
end

puts "navigation: project root, production source, test reference and generated boundary observed"
puts "expected failure: src-only root has no .factorycare-root"
puts "expected failure: target/generated-sources is not SOURCE_OF_TRUTH"
puts "editor navigation example: PASS"
