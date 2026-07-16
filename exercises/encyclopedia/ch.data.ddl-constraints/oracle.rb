# frozen_string_literal: true

def check(condition, message)
  raise "answer-error=#{message}" unless condition
end

sql = File.read(ARGV.fetch(0))
check(sql.include?("REFERENCES factorycare.device (device_id)"),
      "work_order foreign key must reference device primary key")
check(sql.include?("CONSTRAINT device_pkey PRIMARY KEY (device_id)"), "device primary key must be named")
check(sql.include?("CONSTRAINT device_serial_number_not_null NOT NULL"), "serial number must be required")
check(sql.include?("CONSTRAINT device_serial_number_key UNIQUE (serial_number)"), "serial number must be unique")
check(sql.include?("CONSTRAINT device_status_not_null NOT NULL"), "device status must be required")
check(sql.include?("CONSTRAINT device_status_check CHECK"), "device status needs named check")
check(sql.include?("CONSTRAINT work_order_pkey PRIMARY KEY (work_order_id)"), "work order primary key must be named")
check(sql.include?("CONSTRAINT work_order_device_id_not_null NOT NULL"), "work order device must be required")
check(sql.include?("CONSTRAINT work_order_summary_not_null NOT NULL"), "summary must be required")
check(sql.include?("CONSTRAINT work_order_status_check CHECK"), "work order status needs named check")
check(sql.include?("ON DELETE RESTRICT"), "foreign key delete policy")
check(sql.start_with?("BEGIN;") && sql.rstrip.end_with?("ROLLBACK;"), "rebuild must be rollback-safe")
puts "ddl-constraints-answer=PASS"
