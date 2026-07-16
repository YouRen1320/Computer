# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

RUBY = "/usr/bin/ruby"
ZSH = "/bin/zsh"
PROBE = Pathname(__dir__).join("env_probe.rb").freeze
BASE_ENV = {
  "DEMO_MARKER" => "parent",
  "HOME" => "/nonexistent/factorycare-home",
  "LANG" => "C",
  "LC_ALL" => "C",
  "PATH" => "/usr/bin:/bin",
  "TZ" => "UTC"
}.freeze

abort "environment verification: FAIL: fixed Ruby unavailable" unless File.executable?(RUBY)
abort "environment verification: FAIL: fixed zsh unavailable" unless File.executable?(ZSH)
abort "environment verification: FAIL: probe missing or symlinked" unless PROBE.file? && !PROBE.symlink?

def expect(label, actual, expected)
  return if actual == expected

  abort "environment verification: FAIL: #{label}\nexpected=#{expected.inspect}\nactual=#{actual.inspect}"
end

def write_executable(path, body)
  path.write(body, encoding: "UTF-8")
  path.chmod(0o700)
end

def create_tool_root(root, label)
  bin = root.join("bin")
  bin.mkpath
  write_executable(bin.join("demo-tool"), "#!/bin/sh\nprintf 'demo-tool=#{label}\\n'\n")
  write_executable(bin.join("java"), "#!/bin/sh\nprintf '#{label}\\n'\n")
end

def run_zsh(env, script, directory)
  Open3.capture3(env, ZSH, "-f", "-c", script, chdir: directory, unsetenv_others: true)
end

Dir.mktmpdir("factorycare-environment-") do |directory|
  root = Pathname(directory)
  FileUtils.cp(PROBE, root.join("env_probe.rb"))
  tool_a = root.join("tool-a")
  tool_b = root.join("tool-b")
  create_tool_root(tool_a, "JDK_A")
  create_tool_root(tool_b, "JDK_B")

  write_executable(
    tool_a.join("bin/mvn-simulator"),
    <<~SH
      #!/bin/sh
      if [ -z "${JAVA_HOME:-}" ] || [ ! -x "$JAVA_HOME/bin/java" ]; then
        printf 'invalid JAVA_HOME\n' >&2
        exit 66
      fi
      printf 'maven-runtime='
      exec "$JAVA_HOME/bin/java"
    SH
  )

  stdout, stderr, status = run_zsh(
    BASE_ENV,
    "/usr/bin/ruby env_probe.rb DEMO_MARKER; " \
    "DEMO_MARKER=child /usr/bin/ruby env_probe.rb DEMO_MARKER; " \
    "/usr/bin/ruby env_probe.rb DEMO_MARKER",
    root.to_s
  )
  expect("parent/child status", status.exitstatus, 0)
  expect("parent/child stderr", stderr, "")
  expect(
    "child override does not modify shell environment",
    stdout,
    "DEMO_MARKER=parent\nDEMO_MARKER=child\nDEMO_MARKER=parent\n"
  )

  stdout, stderr, status = run_zsh(
    BASE_ENV,
    "LOCAL_ONLY=shell-only; /usr/bin/ruby env_probe.rb LOCAL_ONLY; " \
    "export LOCAL_ONLY; /usr/bin/ruby env_probe.rb LOCAL_ONLY",
    root.to_s
  )
  expect("export status", status.exitstatus, 0)
  expect("export stderr", stderr, "")
  expect("ordinary versus exported", stdout, "LOCAL_ONLY=<unset>\nLOCAL_ONLY=shell-only\n")

  path_a_first = "#{tool_a}/bin:#{tool_b}/bin:/usr/bin:/bin"
  stdout, stderr, status = run_zsh(
    BASE_ENV.merge("PATH" => path_a_first),
    "type -a demo-tool; command -v demo-tool; demo-tool",
    root.to_s
  )
  normalized = stdout.gsub(root.to_s, "<TMP>")
  expected = "demo-tool is <TMP>/tool-a/bin/demo-tool\n" \
             "demo-tool is <TMP>/tool-b/bin/demo-tool\n" \
             "<TMP>/tool-a/bin/demo-tool\n" \
             "demo-tool=JDK_A\n"
  expect("A-first resolution status", status.exitstatus, 0)
  expect("A-first resolution stderr", stderr, "")
  expect("type/command/path order", normalized, expected)

  path_b_first = "#{tool_b}/bin:#{tool_a}/bin:/usr/bin:/bin"
  stdout, stderr, status = run_zsh(
    BASE_ENV.merge("PATH" => path_b_first),
    "command -v demo-tool; demo-tool; '#{tool_a}/bin/demo-tool'",
    root.to_s
  )
  normalized = stdout.gsub(root.to_s, "<TMP>")
  expect("B-first status", status.exitstatus, 0)
  expect("B-first stderr", stderr, "")
  expect(
    "PATH order and absolute path",
    normalized,
    "<TMP>/tool-b/bin/demo-tool\ndemo-tool=JDK_B\ndemo-tool=JDK_A\n"
  )

  stdout, stderr, status = run_zsh(
    BASE_ENV.merge("PATH" => path_a_first, "JAVA_HOME" => tool_b.to_s),
    "printf 'direct-java='; java; mvn-simulator",
    root.to_s
  )
  expect("simulated conflict status", status.exitstatus, 0)
  expect("simulated conflict stderr", stderr, "")
  expect("PATH/JAVA_HOME split", stdout, "direct-java=JDK_A\nmaven-runtime=JDK_B\n")

  stdout, stderr, status = run_zsh(
    BASE_ENV.merge("PATH" => "#{tool_b}/bin:/usr/bin:/bin", "JAVA_HOME" => tool_b.to_s),
    "printf 'direct-java='; java; '#{tool_a}/bin/mvn-simulator'",
    root.to_s
  )
  expect("aligned environment status", status.exitstatus, 0)
  expect("aligned environment stderr", stderr, "")
  expect("aligned runtime", stdout, "direct-java=JDK_B\nmaven-runtime=JDK_B\n")

  stdout, stderr, status = run_zsh(
    BASE_ENV.merge("PATH" => "/usr/bin:/bin", "JAVA_HOME" => tool_b.to_s),
    "demo-tool",
    root.to_s
  )
  expect("missing command stdout", stdout, "")
  expect("missing command status", status.exitstatus, 127)
  abort "environment verification: FAIL: missing-command diagnostic absent" unless stderr.include?("command not found")
end

puts "inheritance: parent/child override and export boundary observed"
puts "resolution: type -a, command -v, PATH order and absolute entry observed"
puts "expected conflict: direct java=JDK_A; simulated Maven runtime=JDK_B"
puts "session repair: PATH and JAVA_HOME aligned to JDK_B without parent mutation"
puts "environment-tool-resolution verification: PASS"
