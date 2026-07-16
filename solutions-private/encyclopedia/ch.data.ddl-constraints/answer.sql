BEGIN;

DROP TABLE IF EXISTS factorycare.work_order;
DROP TABLE IF EXISTS factorycare.device;

CREATE TABLE factorycare.device (
  device_id text,
  serial_number text CONSTRAINT device_serial_number_not_null NOT NULL,
  display_name text CONSTRAINT device_display_name_not_null NOT NULL,
  status text CONSTRAINT device_status_not_null NOT NULL,
  version integer DEFAULT 1 CONSTRAINT device_version_not_null NOT NULL,
  CONSTRAINT device_pkey PRIMARY KEY (device_id),
  CONSTRAINT device_serial_number_key UNIQUE (serial_number),
  CONSTRAINT device_status_check CHECK (status IN ('ACTIVE', 'MAINTENANCE', 'RETIRED')),
  CONSTRAINT device_version_check CHECK (version > 0)
);

CREATE TABLE factorycare.work_order (
  work_order_id text,
  device_id text CONSTRAINT work_order_device_id_not_null NOT NULL,
  summary text CONSTRAINT work_order_summary_not_null NOT NULL,
  status text CONSTRAINT work_order_status_not_null NOT NULL,
  CONSTRAINT work_order_pkey PRIMARY KEY (work_order_id),
  CONSTRAINT work_order_status_check CHECK (status IN ('OPEN', 'IN_PROGRESS', 'DONE', 'CANCELLED')),
  CONSTRAINT work_order_device_fk FOREIGN KEY (device_id)
    REFERENCES factorycare.device (device_id)
    ON DELETE RESTRICT
);

ROLLBACK;
