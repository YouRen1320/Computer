SELECT
  d.device_id AS device_id,
  d.raw_name AS raw_name,
  d.alias AS alias,
  d.temperature_c AS temperature_c,
  d.last_seen_at AS last_seen_at,
  lower(btrim(d.raw_name)) AS normalized_name,
  round(d.temperature_c, 1) AS temperature_c_1dp,
  COALESCE(
    NULLIF(btrim(d.alias), ''),
    btrim(d.raw_name)
  ) AS display_name,
  CASE
    WHEN d.temperature_c IS NULL THEN 'UNKNOWN'
    WHEN d.temperature_c < NUMERIC '0' THEN 'FREEZING'
    WHEN d.temperature_c >= NUMERIC '30' THEN 'HOT'
    ELSE 'NORMAL'
  END AS temperature_band,
  date_trunc(
    'day',
    d.last_seen_at AT TIME ZONE 'Asia/Shanghai'
  ) AS local_day_start,
  CAST(
    d.last_seen_at AT TIME ZONE 'Asia/Shanghai'
    AS date
  ) AS local_date
FROM factorycare.device_reading AS d
ORDER BY d.device_id ASC;
