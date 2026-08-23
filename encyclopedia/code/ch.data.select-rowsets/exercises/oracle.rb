# frozen_string_literal: true

def check(condition, message)
  raise "answer-error=#{message}" unless condition
end

sql = File.read(ARGV.fetch(0))
flat = sql.gsub(/\s+/, " ")

check(!sql.match?(/=\s*NULL/i), "NULL must be tested with IS NULL")
check(sql.scan("d.device_id AS id").length >= 2, "both pages need id projection")
check(sql.scan("d.category AS category").length >= 2, "both pages need category projection")
check(sql.scan("d.created_at AS created_at").length >= 2, "both pages need created_at projection")
check(sql.scan("FROM factorycare.device AS d").length >= 2, "both pages need schema-qualified source")
check(sql.scan("d.enabled IS TRUE").length >= 2, "both pages need enabled predicate")
check(sql.scan("d.retired_at IS NULL").length >= 2, "both pages need NULL predicate")
check(flat.scan(/AND \( d\.retired_at IS NULL OR d\.retired_at > TIMESTAMPTZ '2026-07-17 00:00:00\+00' \)/).length >= 2,
      "AND/OR business rule needs parentheses")
check(sql.scan("ORDER BY d.created_at ASC, d.device_id ASC").length >= 2,
      "both pages need a unique tie-breaker")
check(sql.include?("LIMIT 2 OFFSET 0"), "page 1 slice")
check(sql.include?("LIMIT 2 OFFSET 2"), "page 2 slice")

puts "select-rowsets-answer=PASS"
