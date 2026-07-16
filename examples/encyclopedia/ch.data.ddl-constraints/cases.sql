-- 先执行 schema.sql 的 CREATE 部分并提交；以下每个负例应在独立事务中执行后 ROLLBACK。
INSERT INTO factorycare.device (device_id, serial_number, display_name, status)
VALUES ('D-01', 'SN-001', 'East Pump', 'ACTIVE');

INSERT INTO factorycare.work_order (work_order_id, device_id, summary, status)
VALUES ('W-01', 'D-01', 'Inspect vibration', 'OPEN');

INSERT INTO factorycare.work_order (work_order_id, device_id, summary, status)
VALUES ('W-99', 'D-99', 'Orphan', 'OPEN');

INSERT INTO factorycare.device (device_id, serial_number, display_name, status)
VALUES ('D-02', 'SN-001', 'Duplicate', 'ACTIVE');

INSERT INTO factorycare.device (device_id, serial_number, display_name, status)
VALUES ('D-03', 'SN-003', 'Bad state', 'BROKEN');

INSERT INTO factorycare.work_order (work_order_id, device_id, summary, status)
VALUES ('W-02', 'D-01', 'Bad state', 'UNKNOWN');

INSERT INTO factorycare.work_order (work_order_id, device_id, summary, status)
VALUES ('W-03', 'D-01', NULL, 'OPEN');
