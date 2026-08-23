-- TODO: intentionally wrong starter
SELECT
  s.category AS category,
  s.device_id AS device_id,
  COUNT(s.duration_minutes) AS enabled_event_count
FROM factorycare.device_maintenance_sample AS s
WHERE s.enabled IS TRUE
  AND COUNT(DISTINCT s.device_id) >= 2
GROUP BY s.category
ORDER BY s.category;
