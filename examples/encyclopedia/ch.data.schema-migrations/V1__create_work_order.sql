CREATE SCHEMA IF NOT EXISTS factorycare;

CREATE TABLE factorycare.work_order (
  work_order_id bigint PRIMARY KEY,
  summary text NOT NULL,
  priority smallint NOT NULL CHECK (priority BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp()
);
