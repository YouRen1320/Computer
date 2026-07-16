-- TODO: intentionally wrong starter; repair the first correlated predicate first.
SELECT d.device_id, d.category
FROM factorycare.device AS d
WHERE EXISTS (
  SELECT 1
  FROM factorycare.work_order AS w
  WHERE w.device_id = w.device_id
    AND w.status = 'DONE'
)
ORDER BY d.device_id;

WITH unfinished_devices AS (
  SELECT d.device_id, d.category
  FROM factorycare.device AS d
  WHERE EXISTS (
    SELECT 1
    FROM factorycare.work_order AS w
    WHERE w.device_id = w.device_id
      AND w.status = 'DONE'
  )
),
category_counts AS (
  SELECT category, COUNT(*) AS device_count
  FROM unfinished_devices
  GROUP BY category
)
SELECT category, device_count
FROM category_counts
WHERE device_count >= 2
ORDER BY category;
