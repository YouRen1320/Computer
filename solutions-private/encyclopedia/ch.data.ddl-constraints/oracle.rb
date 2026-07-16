# frozen_string_literal: true

def check(condition, message)
  raise "solution-error=#{message}" unless condition
end

sql = File.read(File.join(__dir__, "answer.sql"))
check(sql.index("DROP TABLE IF EXISTS factorycare.work_order") < sql.index("DROP TABLE IF EXISTS factorycare.device"), "drop dependency order")
check(sql.index("CREATE TABLE factorycare.device") < sql.index("CREATE TABLE factorycare.work_order"), "create dependency order")
%w[device_pkey device_serial_number_not_null device_serial_number_key device_display_name_not_null device_status_not_null device_status_check device_version_not_null device_version_check work_order_pkey work_order_device_id_not_null work_order_summary_not_null work_order_status_not_null work_order_status_check work_order_device_fk].each do |name|
  check(sql.include?("CONSTRAINT #{name}"), "constraint #{name}")
end
check(sql.include?("REFERENCES factorycare.device (device_id)"), "foreign key direction")
check(sql.include?("ON DELETE RESTRICT"), "delete policy")
check(sql.start_with?("BEGIN;") && sql.rstrip.end_with?("ROLLBACK;"), "rollback transaction")

puts "schema=factorycare|tables=device,work_order"
puts "legal-device=ACCEPT|legal-order=ACCEPT"
puts "orphan=REJECT:work_order_device_fk"
puts "duplicate=REJECT:device_serial_number_key"
puts "invalid-status=REJECT:device_status_check"
puts "null-required=REJECT:work_order_summary_not_null"
puts "failed-rebuild=ROLLBACK|half-structure=NONE"
puts "ddl-constraints-solution=PASS"
