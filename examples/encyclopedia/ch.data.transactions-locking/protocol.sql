-- PostgreSQL 18 teaching protocol; run only on a disposable schema.
BEGIN;
UPDATE factorycare.work_order
SET status = 'IN_PROGRESS', assigned_to = 7, version = version + 1
WHERE work_order_id = 42 AND status = 'OPEN';
INSERT INTO factorycare.work_order_history
  (command_id, work_order_id, from_status, to_status, assigned_to)
VALUES
  ('01947b2a-7b20-7cc3-98f2-9f4d4a71e801', 42, 'OPEN', 'IN_PROGRESS', 7);
COMMIT;

-- Reset the disposable fixture, then inject a duplicate command_id.
BEGIN;
UPDATE factorycare.work_order
SET status = 'IN_PROGRESS', assigned_to = 7, version = version + 1
WHERE work_order_id = 42 AND status = 'OPEN';
INSERT INTO factorycare.work_order_history
  (command_id, work_order_id, from_status, to_status, assigned_to)
VALUES
  ('01947b2a-7b20-7cc3-98f2-9f4d4a71e801', 42, 'OPEN', 'IN_PROGRESS', 7);
-- Expected SQLSTATE: 23505. Do not continue the business operation.
ROLLBACK;
