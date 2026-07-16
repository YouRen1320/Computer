# frozen_string_literal: true

require "json"

record_path, duration_text = ARGV
abort "usage: child_probe.rb RECORD_PATH DURATION" unless record_path && duration_text
duration = Float(duration_text)
abort "duration outside safe lab range" unless duration.between?(0.1, 1.0)

File.write(
  record_path,
  JSON.generate("pid" => Process.pid, "ppid" => Process.ppid, "phase" => "running"),
  encoding: "UTF-8"
)
sleep duration
