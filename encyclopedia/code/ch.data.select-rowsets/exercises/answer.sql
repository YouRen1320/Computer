-- TODO: this starter is intentionally wrong.
SELECT
  d.device_id AS id,
  d.category AS category,
  d.created_at AS created_at
FROM factorycare.device AS d
WHERE d.enabled IS TRUE
  AND d.retired_at = NULL
  OR d.retired_at > TIMESTAMPTZ '2026-07-17 00:00:00+00'
ORDER BY d.created_at ASC
LIMIT 2 OFFSET 0;
