# frozen_string_literal: true

raw = $stdin.read
if raw.empty?
  warn "missing status"
  exit 64
end

status = raw.end_with?("\n") ? raw.delete_suffix("\n") : raw
unless ["ASSIGNED", "IN_PROGRESS"].include?(status) && !status.include?("\n")
  warn "invalid status"
  exit 65
end

puts "accepted=#{status}"
