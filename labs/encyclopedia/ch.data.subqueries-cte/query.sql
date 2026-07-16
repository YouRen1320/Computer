-- 正确的存在性筛选。
SELECT d.device_id, d.category
FROM factorycare.device AS d
WHERE EXISTS (
  SELECT 1
  FROM factorycare.work_order AS w
  WHERE w.device_id = d.device_id
    AND w.status IN ('OPEN', 'IN_PROGRESS')
)
ORDER BY d.device_id;

-- 正确拆解；先单独运行 unfinished_devices，再核对 category_counts。
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

-- NULL-safe anti-join；NULL 排除键不会匹配任何非 NULL 设备键。
SELECT d.device_id
FROM factorycare.device AS d
WHERE NOT EXISTS (
  SELECT 1
  FROM factorycare.exclusion AS e
  WHERE e.device_id = d.device_id
)
ORDER BY d.device_id;

-- 故障注入写在 scenarios.json：NOT IN + NULL、错层相关、错误 CTE 状态。
