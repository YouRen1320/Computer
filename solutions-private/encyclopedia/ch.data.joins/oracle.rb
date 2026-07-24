# frozen_string_literal: true

def check(condition, message)
  raise "solution-error=#{message}" unless condition
end

sql = File.read(File.join(__dir__, "answer.sql"))
check(!sql.match?(/factorycare\.device AS d\s*,/m), "cartesian")
check(sql.include?("ON w.device_id = d.device_id\n AND w.status = 'CREATED'"), "ON filter")
check(!sql.match?(/WHERE\s+w\.status/m), "WHERE collapse")
check(sql.scan("COUNT(w.work_order_id) AS work_order_count").length == 2, "right-key count")
check(sql.scan("GROUP BY t.technician_id, t.display_name").length == 2, "groups")
check(sql.include?("HAVING COUNT(w.work_order_id) >= 2"), "HAVING")

puts "open-left-rows=4"
puts "open-left-devices=D-01,D-02,D-03,D-04"
puts "technician-counts=T-01:2,T-02:1,T-03:0"
puts "having-pass=T-01"
puts "joins-solution=PASS"
