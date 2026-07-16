-- 1. EXISTS 保留每台外层设备至多一次。
SELECT d.device_id, d.category
FROM factorycare.device AS d
WHERE EXISTS (
  SELECT 1
  FROM factorycare.work_order AS w
  WHERE w.device_id = d.device_id
    AND w.status IN ('OPEN', 'IN_PROGRESS')
)
ORDER BY d.device_id;

-- 2. COUNT(*) 无 GROUP BY 时总是返回一行，可安全作为标量子查询。
SELECT
  d.device_id,
  (
    SELECT COUNT(*)
    FROM factorycare.work_order AS w
    WHERE w.device_id = d.device_id
  ) AS work_order_count
FROM factorycare.device AS d
ORDER BY d.device_id;

-- 3. 扁平版本：作为拆分等价性的对照。
SELECT d.category, COUNT(*) AS device_count
FROM factorycare.device AS d
WHERE EXISTS (
  SELECT 1
  FROM factorycare.work_order AS w
  WHERE w.device_id = d.device_id
    AND w.status IN ('OPEN', 'IN_PROGRESS')
)
GROUP BY d.category
HAVING COUNT(*) >= 2
ORDER BY d.category;

-- 4. 命名 CTE 版本：每层都可以独立改写为 SELECT 检查。
WITH unfinished_devices AS (
  SELECT d.device_id, d.category
  FROM factorycare.device AS d
  WHERE EXISTS (
    SELECT 1
    FROM factorycare.work_order AS w
    WHERE w.device_id = d.device_id
      AND w.status IN ('OPEN', 'IN_PROGRESS')
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
