-- TODO: intentionally wrong starter
SELECT d.device_id, w.work_order_id
FROM factorycare.device AS d, factorycare.work_order AS w;

SELECT d.device_id, w.work_order_id
FROM factorycare.device AS d
LEFT JOIN factorycare.work_order AS w
  ON w.device_id = d.device_id
WHERE w.status = 'OPEN';

SELECT t.technician_id, COUNT(*) AS work_order_count
FROM factorycare.technician AS t
LEFT JOIN factorycare.work_order AS w
  ON w.technician_id = t.technician_id
GROUP BY t.technician_id;
