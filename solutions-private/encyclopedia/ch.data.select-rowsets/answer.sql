SELECT
  d.device_id AS id,
  d.category AS category,
  d.created_at AS created_at
FROM factorycare.device AS d
WHERE d.enabled IS TRUE
  AND (
    d.retired_at IS NULL
    OR d.retired_at > TIMESTAMPTZ '2026-07-17 00:00:00+00'
  )
ORDER BY d.created_at ASC, d.device_id ASC
LIMIT 2 OFFSET 0;

SELECT
  d.device_id AS id,
  d.category AS category,
  d.created_at AS created_at
FROM factorycare.device AS d
WHERE d.enabled IS TRUE
  AND (
    d.retired_at IS NULL
    OR d.retired_at > TIMESTAMPTZ '2026-07-17 00:00:00+00'
  )
ORDER BY d.created_at ASC, d.device_id ASC
LIMIT 2 OFFSET 2;
