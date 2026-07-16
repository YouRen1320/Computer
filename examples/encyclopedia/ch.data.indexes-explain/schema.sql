BEGIN;

CREATE SCHEMA IF NOT EXISTS factorycare;
DROP TABLE IF EXISTS factorycare.work_order;

CREATE TABLE factorycare.work_order (
  work_order_id bigint PRIMARY KEY,
  device_id bigint NOT NULL,
  status text NOT NULL CHECK (status IN ('OPEN', 'IN_PROGRESS', 'DONE', 'CANCELLED')),
  priority smallint NOT NULL CHECK (priority BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL,
  summary text NOT NULL
);

INSERT INTO factorycare.work_order
  (work_order_id, device_id, status, priority, created_at, summary)
SELECT n,
       (n % 5000) + 1,
       CASE
         WHEN n <= 85000 THEN 'DONE'
         WHEN n <= 93000 THEN 'OPEN'
         WHEN n <= 98000 THEN 'IN_PROGRESS'
         ELSE 'CANCELLED'
       END,
       ((n % 5) + 1)::smallint,
       TIMESTAMPTZ '2026-01-01 00:00:00+08'
         + ((n % 180) * INTERVAL '1 day')
         + ((n % 86400) * INTERVAL '1 second'),
       'fixture-' || n
FROM generate_series(1, 100000) AS g(n);

ANALYZE factorycare.work_order;

EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT work_order_id, status, created_at, device_id, priority
FROM factorycare.work_order
WHERE status = 'OPEN'
  AND created_at >= TIMESTAMPTZ '2026-06-01 00:00:00+08'
  AND created_at <  TIMESTAMPTZ '2026-07-01 00:00:00+08'
ORDER BY created_at DESC, work_order_id DESC
LIMIT 50;

CREATE INDEX work_order_status_created_id_idx
ON factorycare.work_order (status, created_at DESC, work_order_id DESC)
INCLUDE (device_id, priority);

ANALYZE factorycare.work_order;

EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT work_order_id, status, created_at, device_id, priority
FROM factorycare.work_order
WHERE status = 'OPEN'
  AND created_at >= TIMESTAMPTZ '2026-06-01 00:00:00+08'
  AND created_at <  TIMESTAMPTZ '2026-07-01 00:00:00+08'
ORDER BY created_at DESC, work_order_id DESC
LIMIT 50;

ROLLBACK;
