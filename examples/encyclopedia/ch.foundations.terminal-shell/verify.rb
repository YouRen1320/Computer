# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

ZSH = "/bin/zsh"
RUBY = "/usr/bin/ruby"
PROBE = Pathname(__dir__).join("argv_probe.rb").freeze
FIXED_ENV = {
  "HOME" => "/nonexistent/factorycare-home",
  "LANG" => "C",
  "LC_ALL" => "C",
  "PATH" => "/usr/bin:/bin",
  "TZ" => "UTC"
}.freeze

abort "terminal-shell verification: FAIL: /bin/zsh is unavailable" unless File.executable?(ZSH)
abort "terminal-shell verification: FAIL: /usr/bin/ruby is unavailable" unless File.executable?(RUBY)
abort "terminal-shell verification: FAIL: argv probe is missing" unless PROBE.file? && !PROBE.symlink?

def run_zsh(script, directory)
  stdout, stderr, status = Open3.capture3(
    FIXED_ENV,
    ZSH,
    "-f",
    "-c",
    script,
    chdir: directory,
    unsetenv_others: true
  )
  abort "terminal-shell verification: FAIL: unexpected shell diagnostic #{stderr.dump}" unless stderr.empty?
  abort "terminal-shell verification: FAIL: fixed command did not complete" unless status.success?
  stdout
end

def expect(label, actual, expected)
  return if actual == expected

  abort "terminal-shell verification: FAIL: #{label}\nexpected=#{expected.dump}\nactual=#{actual.dump}"
end

Dir.mktmpdir("factorycare-shell-") do |directory|
  root = Pathname(directory)
  room = root.join("Factory Care")
  room.mkpath
  room.join("pump.txt").write("pump\n", encoding: "UTF-8")
  room.join("fan.txt").write("fan\n", encoding: "UTF-8")
  room.join("literal*.note").write("literal star\n", encoding: "UTF-8")
  FileUtils.cp(PROBE, root.join("argv_probe.rb"))

  pwd = run_zsh("/bin/pwd", root.to_s).strip
  expect("working directory", pwd, root.realpath.to_s)

  quoted_space = run_zsh(%q{/usr/bin/ruby argv_probe.rb 'Factory Care'}, root.to_s)
  expect("single-quoted space", quoted_space, "argc=1\nargv[0]=\"Factory Care\"\n")

  double_quoted_space = run_zsh(%q{/usr/bin/ruby argv_probe.rb "Factory Care"}, root.to_s)
  expect("double-quoted space", double_quoted_space, quoted_space)

  escaped_space = run_zsh(%q{/usr/bin/ruby argv_probe.rb Factory\ Care}, root.to_s)
  expect("escaped space", escaped_space, quoted_space)

  unquoted_space = run_zsh(%q{/usr/bin/ruby argv_probe.rb Factory Care}, root.to_s)
  expect("expected unquoted-space fault", unquoted_space, "argc=2\nargv[0]=\"Factory\"\nargv[1]=\"Care\"\n")

  literal_star = run_zsh(%q{/usr/bin/ruby ../argv_probe.rb '*'}, room.to_s)
  expect("quoted literal star", literal_star, "argc=1\nargv[0]=\"*\"\n")

  escaped_star = run_zsh(%q{/usr/bin/ruby ../argv_probe.rb \*}, room.to_s)
  expect("escaped literal star", escaped_star, literal_star)

  expanded_glob = run_zsh(%q{/usr/bin/ruby ../argv_probe.rb *.txt}, room.to_s)
  expect(
    "expected glob expansion",
    expanded_glob,
    "argc=2\nargv[0]=\"fan.txt\"\nargv[1]=\"pump.txt\"\n"
  )

  changed = run_zsh(%q{cd 'Factory Care'; /bin/pwd}, root.to_s).strip
  expect("cd changes shell working directory", changed, room.realpath.to_s)
end

puts "cwd: fixed root and quoted cd target observed"
puts "argv: ordinary, space-containing and literal-star arguments observed"
puts "expected faults: unquoted space split; unquoted glob expanded"
puts "terminal-shell verification: PASS"
