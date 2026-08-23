BEGIN;

INSERT INTO factorycare.device (device_id, serial_number, display_name, status)
VALUES ('D-04', 'SN-004', 'North Valve', 'ACTIVE');

-- TODO: intentionally unsafe starter.
UPDATE factorycare.device
SET display_name = 'East Pump / inspected';

DELETE FROM factorycare.device;

INSERT INTO factorycare.device AS d (
  device_id, serial_number, display_name, status
)
VALUES ('D-import-99', 'SN-002', 'South Compressor / calibrated', 'MAINTENANCE')
ON CONFLICT (serial_number) DO UPDATE
SET device_id = EXCLUDED.device_id,
    serial_number = EXCLUDED.serial_number,
    display_name = EXCLUDED.display_name;

ROLLBACK;
