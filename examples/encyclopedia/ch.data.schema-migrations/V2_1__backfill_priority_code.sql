UPDATE factorycare.work_order
SET priority_code = 'P' || priority::text
WHERE priority_code IS NULL;
