ALTER TABLE factorycare.work_order
  ALTER COLUMN priority_code SET NOT NULL;

ALTER TABLE factorycare.work_order
  DROP COLUMN priority;
