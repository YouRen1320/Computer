BEGIN;

INSERT INTO factorycare.device (
  device_id, serial_number, display_name, status
)
VALUES ('D-04', 'SN-004', 'North Valve', 'ACTIVE')
RETURNING device_id, serial_number, status, version;

UPDATE factorycare.device
SET display_name = 'East Pump / inspected',
    version = version + 1
WHERE device_id = 'D-01'
  AND version = 3
RETURNING WITH (OLD AS o, NEW AS n)
  n.device_id, o.version AS old_version, n.version AS new_version;

-- 同一旧版本再次提交，预期零行而不是 SQL 错误。
UPDATE factorycare.device
SET display_name = 'stale overwrite',
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
RETURNING d.device_id, d.serial_number, d.status;

-- ACTIVE 的 D-02 不满足保护谓词，预期零行。
DELETE FROM factorycare.device AS d
WHERE d.device_id = 'D-02'
  AND d.status = 'RETIRED'
  AND NOT EXISTS (
    SELECT 1 FROM factorycare.work_order AS w
    WHERE w.device_id = d.device_id
  )
RETURNING d.device_id;

INSERT INTO factorycare.device AS d (
  device_id, serial_number, display_name, status
)
VALUES (
  'D-import-99', 'SN-002', 'South Compressor / calibrated', 'MAINTENANCE'
)
ON CONFLICT (serial_number) DO UPDATE
SET display_name = EXCLUDED.display_name,
    status = EXCLUDED.status,
    version = d.version + 1
RETURNING d.device_id, d.serial_number, d.display_name, d.status, d.version;

ROLLBACK;
