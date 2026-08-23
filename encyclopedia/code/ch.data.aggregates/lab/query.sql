SELECT
  s.category AS category,
  COUNT(*) AS enabled_event_count,
  COUNT(DISTINCT s.device_id) AS enabled_device_count,
  COUNT(s.duration_minutes) AS duration_sample_count,
  SUM(s.duration_minutes) AS total_duration_minutes,
  ROUND(AVG(s.duration_minutes), 2) AS avg_duration_minutes
FROM factorycare.device_maintenance_sample AS s
WHERE s.enabled IS TRUE
GROUP BY s.category
HAVING COUNT(DISTINCT s.device_id) >= 2
ORDER BY s.category ASC NULLS LAST;
