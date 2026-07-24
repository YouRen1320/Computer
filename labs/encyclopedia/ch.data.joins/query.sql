SELECT
  d.device_id,
  w.work_order_id
FROM factorycare.device AS d
LEFT JOIN factorycare.work_order AS w
  ON w.device_id = d.device_id
 AND w.status = 'CREATED'
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
  COUNT(w.work_order_id) AS work_order_count
FROM factorycare.technician AS t
LEFT JOIN factorycare.work_order AS w
  ON w.technician_id = t.technician_id
GROUP BY t.technician_id
HAVING COUNT(w.work_order_id) >= 2
ORDER BY t.technician_id;
