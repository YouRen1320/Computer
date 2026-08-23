SELECT d.device_id, w.work_order_id
FROM factorycare.device AS d
INNER JOIN factorycare.work_order AS w
  ON w.device_id = d.device_id
ORDER BY d.device_id, w.work_order_id;

SELECT
  d.device_id,
  d.category,
  w.work_order_id,
  w.status AS work_order_status,
  t.technician_id,
  t.display_name AS technician_name
FROM factorycare.device AS d
LEFT JOIN factorycare.work_order AS w
  ON w.device_id = d.device_id
LEFT JOIN factorycare.technician AS t
  ON t.technician_id = w.technician_id
ORDER BY d.device_id, w.work_order_id;

SELECT
  t.technician_id,
  t.display_name,
  COUNT(w.work_order_id) AS work_order_count
FROM factorycare.technician AS t
LEFT JOIN factorycare.work_order AS w
  ON w.technician_id = t.technician_id
GROUP BY t.technician_id, t.display_name
ORDER BY t.technician_id;

SELECT
  t.technician_id,
  w.work_order_id
FROM factorycare.technician AS t
FULL JOIN factorycare.work_order AS w
  ON w.technician_id = t.technician_id
ORDER BY t.technician_id NULLS LAST, w.work_order_id;
