SELECT
  w.work_order_id,
  w.technician_id,
  w.created_at,
  w.status,
  ROW_NUMBER() OVER (
    PARTITION BY w.technician_id
    ORDER BY w.created_at, w.work_order_id
  ) AS technician_sequence,
  LAG(w.work_order_id) OVER (
    PARTITION BY w.technician_id
    ORDER BY w.created_at, w.work_order_id
  ) AS previous_work_order_id,
  LEAD(w.work_order_id) OVER (
    PARTITION BY w.technician_id
    ORDER BY w.created_at, w.work_order_id
  ) AS next_work_order_id,
  w.created_at - LAG(w.created_at) OVER (
    PARTITION BY w.technician_id
    ORDER BY w.created_at, w.work_order_id
  ) AS since_previous,
  LEAD(w.created_at) OVER (
    PARTITION BY w.technician_id
    ORDER BY w.created_at, w.work_order_id
  ) - w.created_at AS until_next,
  SUM(CASE WHEN w.status = 'CLOSED' THEN 1 ELSE 0 END) OVER (
    PARTITION BY w.technician_id
    ORDER BY w.created_at, w.work_order_id
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS completed_so_far
FROM factorycare.work_order AS w
ORDER BY w.technician_id, w.created_at, w.work_order_id;

-- 三种破坏性改写及预测见 scenarios.json；不要把故障查询混入正确查询批次。
