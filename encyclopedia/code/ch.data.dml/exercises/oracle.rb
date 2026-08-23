# frozen_string_literal: true

def check(condition, message)
  raise "answer-error=#{message}" unless condition
end

sql = File.read(ARGV.fetch(0))
check(sql.match?(/UPDATE factorycare\.device\s+SET.*?version = version \+ 1\s+WHERE device_id = 'D-01'\s+AND version = 3/m),
      "versioned UPDATE must include device_id and version predicate")
check(sql.match?(/DELETE FROM factorycare\.device AS d\s+WHERE d\.device_id = 'D-03'.*?d\.status = 'RETIRED'.*?NOT EXISTS/m),
      "DELETE must include id, retired status, and child guard")
check(sql.include?("ON CONFLICT (serial_number) DO UPDATE"), "UPSERT needs serial conflict target")
set_clause = sql.match(/ON CONFLICT \(serial_number\) DO UPDATE\s+SET(.*?)RETURNING/m).to_a[1]
check(set_clause, "UPSERT needs RETURNING after SET")
check(!set_clause.match?(/\bdevice_id\s*=/), "UPSERT must not overwrite immutable device_id")
check(!set_clause.match?(/\bserial_number\s*=/), "UPSERT must not overwrite immutable serial_number")
check(sql.scan("RETURNING").length >= 4, "every write path needs returning evidence")
check(sql.start_with?("BEGIN;") && sql.rstrip.end_with?("ROLLBACK;"), "exercise must be rollback-safe")
puts "dml-answer=PASS"
