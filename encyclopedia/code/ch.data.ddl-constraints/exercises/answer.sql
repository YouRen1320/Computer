BEGIN;

DROP TABLE IF EXISTS factorycare.work_order;
DROP TABLE IF EXISTS factorycare.device;

-- TODO: intentionally incomplete starter.
CREATE TABLE factorycare.device (
  device_id text PRIMARY KEY,
  serial_number text,
  display_name text,
  status text,
  version integer DEFAULT 1
);

CREATE TABLE factorycare.work_order (
  work_order_id text PRIMARY KEY,
  device_id text,
  summary text,
  status text,
  CONSTRAINT work_order_device_fk FOREIGN KEY (device_id)
    REFERENCES factorycare.work_order (work_order_id)
);

ROLLBACK;
