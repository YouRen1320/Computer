ALTER TABLE factorycare.work_order
  ADD COLUMN priority_code text;

ALTER TABLE factorycare.work_order
  ADD CONSTRAINT work_order_priority_code_check
  CHECK (priority_code IS NULL OR priority_code IN ('P1', 'P2', 'P3', 'P4', 'P5'))
  NOT VALID;
