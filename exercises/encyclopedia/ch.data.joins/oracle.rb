# frozen_string_literal: true

def check(condition, message)
  raise "answer-error=#{message}" unless condition
end

sql = File.read(ARGV.fetch(0))
check(!sql.match?(/factorycare\.device AS d\s*,\s*factorycare\.work_order AS w/m),
      "cartesian source must be replaced by explicit JOIN ON")
check(sql.include?("ON w.device_id = d.device_id"), "device join key")
check(sql.include?("AND w.status = 'OPEN'"), "OPEN filter must be in LEFT JOIN ON")
check(!sql.match?(/WHERE\s+w\.status\s*=\s*'OPEN'/m), "WHERE must not remove unmatched devices")
check(sql.scan("COUNT(w.work_order_id) AS work_order_count").length >= 2, "count matching right keys")
check(sql.include?("GROUP BY t.technician_id, t.display_name"), "technician grouping")
check(sql.include?("HAVING COUNT(w.work_order_id) >= 2"), "technician HAVING")
puts "joins-answer=PASS"
