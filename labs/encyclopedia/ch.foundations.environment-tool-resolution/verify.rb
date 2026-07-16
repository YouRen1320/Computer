# frozen_string_literal: true

require "open3"
require "pathname"
require "tmpdir"

def write_tool(path, label)
  path.dirname.mkpath
  path.write("#!/bin/sh\nprintf 'tool=#{label}\\n'\n", encoding: "UTF-8")
  path.chmod(0o700)
end

Dir.mktmpdir("factorycare-env-lab-") do |directory|
  root = Pathname(directory)
  a = root.join("a/bin/demo-tool")
  b = root.join("b/bin/demo-tool")
  write_tool(a, "A")
  write_tool(b, "B")
  env = {
    "DEMO_MARKER" => "parent",
    "HOME" => "/nonexistent/factorycare-home",
    "LANG" => "C",
    "LC_ALL" => "C",
    "PATH" => "#{a.dirname}:#{b.dirname}:/usr/bin:/bin",
    "TZ" => "UTC"
  }
  stdout, stderr, status = Open3.capture3(
    env,
    "/bin/zsh",
    "-f",
    "-c",
    "command -v demo-tool; demo-tool; " \
    "DEMO_MARKER=child /usr/bin/ruby -e 'puts ENV.fetch(\"DEMO_MARKER\")'; " \
    "/usr/bin/printf '%s\\n' $DEMO_MARKER",
    unsetenv_others: true
  )
  normalized = stdout.gsub(root.to_s, "<TMP>")
  expected = "<TMP>/a/bin/demo-tool\ntool=A\nchild\nparent\n"
  abort "environment lab fixture: FAIL: fixed snapshot" unless status.success? && stderr.empty? && normalized == expected
end

puts "fixture: isolated A/B tool roots created and removed"
puts "inheritance: child override observed; parent remained parent"
puts "manual PATH reversal, JAVA_HOME diagnosis and teach-back: NOT CHECKED"
puts "environment-tool-resolution lab fixture: PASS"
