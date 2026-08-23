# frozen_string_literal: true

def check(condition, message)
  raise "solution-error=#{message}" unless condition
end

sql = File.read(File.join(__dir__, "answer.sql"))
flat = sql.gsub(/\s+/, " ")

check(!sql.match?(/=\s*NULL/i), "NULL comparison")
check(sql.scan("FROM factorycare.device AS d").length == 2, "source")
check(sql.scan("d.enabled IS TRUE").length == 2, "enabled")
check(sql.scan("d.retired_at IS NULL").length == 2, "NULL")
check(flat.scan(/AND \( d\.retired_at IS NULL OR d\.retired_at > TIMESTAMPTZ '2026-07-17 00:00:00\+00' \)/).length == 2,
      "grouping")
check(sql.scan("ORDER BY d.created_at ASC, d.device_id ASC").length == 2, "total order")
check(sql.include?("LIMIT 2 OFFSET 0") && sql.include?("LIMIT 2 OFFSET 2"), "slices")

ordered_ids = %w[D-01 D-02 D-05 D-06]
page_1 = ordered_ids.slice(0, 2)
page_2 = ordered_ids.slice(2, 2)
check((page_1 + page_2) == ordered_ids, "page closure")

puts "page-1=#{page_1.join(",")}"
puts "page-2=#{page_2.join(",")}"
puts "page-union=#{(page_1 + page_2).join(",")}"
puts "select-rowsets-solution=PASS"
