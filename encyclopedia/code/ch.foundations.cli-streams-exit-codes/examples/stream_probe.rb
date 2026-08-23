# frozen_string_literal: true

# A deliberately small CLI contract: one status on stdin, normalized business
# data on stdout, safe diagnostics on stderr, and distinct non-zero failures.
raw = $stdin.read
if raw.empty?
  warn "missing status"
  exit 64
end

status = raw.end_with?("\n") ? raw.delete_suffix("\n") : raw
if status.include?("\n")
  warn "expected exactly one status"
  exit 65
end

unless ["ASSIGNED", "IN_PROGRESS"].include?(status)
  warn "invalid status"
  exit 65
end

puts "accepted=#{status}"
