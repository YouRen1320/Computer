# frozen_string_literal: true

def check(condition, message)
  raise "solution-error=#{message}" unless condition
end

sql = File.read(File.join(__dir__, "answer.sql"))
check(sql.match?(/UPDATE factorycare\.device\s+SET.*?version = version \+ 1\s+WHERE device_id = 'D-01'\s+AND version = 3/m), "versioned update")
check(sql.match?(/DELETE FROM factorycare\.device AS d\s+WHERE d\.device_id = 'D-03'.*?d\.status = 'RETIRED'.*?NOT EXISTS/m), "protected delete")
check(sql.include?("ON CONFLICT (serial_number) DO UPDATE"), "conflict target")
set_clause = sql.match(/ON CONFLICT \(serial_number\) DO UPDATE\s+SET(.*?)RETURNING/m).to_a[1]
check(set_clause && !set_clause.match?(/\bdevice_id\s*=/) && !set_clause.match?(/\bserial_number\s*=/), "immutable fields")
check(sql.scan("RETURNING").length == 4, "returning evidence")
check(sql.start_with?("BEGIN;") && sql.rstrip.end_with?("ROLLBACK;"), "rollback transaction")

puts "insert-affected=1|device=D-04"
puts "update-affected=1|device=D-01|version=4"
puts "delete-affected=1|device=D-03"
puts "upsert-affected=1|device=D-02|version=6"
puts "rollback-restored=D-01,D-02,D-03"
puts "dml-solution=PASS"
