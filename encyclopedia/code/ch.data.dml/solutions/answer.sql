BEGIN;

INSERT INTO factorycare.device (device_id, serial_number, display_name, status)
VALUES ('D-04', 'SN-004', 'North Valve', 'ACTIVE')
RETURNING device_id, serial_number, status, version;

UPDATE factorycare.device
SET display_name = 'East Pump / inspected',
    version = version + 1
WHERE device_id = 'D-01'
  AND version = 3
RETURNING device_id, version;

DELETE FROM factorycare.device AS d
WHERE d.device_id = 'D-03'
  AND d.status = 'RETIRED'
  AND NOT EXISTS (
    SELECT 1 FROM factorycare.work_order AS w
    WHERE w.device_id = d.device_id
  )
RETURNING d.device_id, d.status;

INSERT INTO factorycare.device AS d (
  device_id, serial_number, display_name, status
)
VALUES ('D-import-99', 'SN-002', 'South Compressor / calibrated', 'MAINTENANCE')
ON CONFLICT (serial_number) DO UPDATE
SET display_name = EXCLUDED.display_name,
    status = EXCLUDED.status,
    version = d.version + 1
RETURNING d.device_id, d.serial_number, d.version;

ROLLBACK;
