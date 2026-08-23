# frozen_string_literal: true

require "json"

output_path, duration_text, label = ARGV
abort "child_probe requires output path, duration and label" unless output_path && duration_text && label

duration = Float(duration_text)
abort "duration must be between 0.05 and 1.0 seconds" unless duration.between?(0.05, 1.0)

record = {
  "pid" => Process.pid,
  "ppid" => Process.ppid,
  "label" => label,
  "phase" => "running"
}
File.write(output_path, JSON.generate(record), mode: "w", encoding: "UTF-8")
sleep duration
