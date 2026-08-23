# frozen_string_literal: true

require "open3"
require "pathname"

root = Pathname(__dir__)
fixture = root.join("fixture/Factory Care")
probe = root.join("argv_probe.rb")
abort "terminal-shell lab fixture: FAIL: unexpected symlink" if [fixture, probe].any?(&:symlink?)
abort "terminal-shell lab fixture: FAIL: missing fixed directory" unless fixture.directory?

expected_names = ["fan status.txt", "literal*.note", "pump status.txt"]
abort "terminal-shell lab fixture: FAIL: fixture names changed" unless fixture.children.map { |path| path.basename.to_s }.sort == expected_names

env = { "HOME" => "/nonexistent/factorycare-home", "LANG" => "C", "LC_ALL" => "C", "PATH" => "/usr/bin:/bin", "TZ" => "UTC" }
stdout, stderr, status = Open3.capture3(
  env,
  "/bin/zsh",
  "-f",
  "-c",
  %q{/usr/bin/ruby ../../argv_probe.rb 'pump status.txt' '*' \*},
  chdir: fixture.to_s,
  unsetenv_others: true
)
expected = "argc=3\nargv[0]=\"pump status.txt\"\nargv[1]=\"*\"\nargv[2]=\"*\"\n"
abort "terminal-shell lab fixture: FAIL: fixed command failed" unless status.success? && stderr.empty? && stdout == expected

puts "fixture: three fixed names present"
puts "argv: quoted space and two literal stars preserved"
puts "manual worksheet and teach-back: NOT CHECKED"
puts "terminal-shell lab fixture: PASS"
