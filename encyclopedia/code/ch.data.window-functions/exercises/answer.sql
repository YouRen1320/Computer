-- TODO: intentionally wrong starter.
SELECT
  w.work_order_id,
  w.technician_id,
  w.created_at,
  w.status,
  ROW_NUMBER() OVER (
    ORDER BY w.created_at
  ) AS technician_sequence,
  w.created_at - LAG(w.created_at) OVER (
    ORDER BY w.created_at
  ) AS since_previous,
  LEAD(w.created_at) OVER (
    ORDER BY w.created_at
  ) - w.created_at AS until_next,
  SUM(CASE WHEN w.status = 'CLOSED' THEN 1 ELSE 0 END) OVER (
    ORDER BY w.created_at
  ) AS completed_so_far
FROM factorycare.work_order AS w
ORDER BY w.created_at;
