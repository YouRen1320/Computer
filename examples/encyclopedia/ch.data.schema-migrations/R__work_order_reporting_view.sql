CREATE OR REPLACE VIEW factorycare.work_order_reporting AS
SELECT work_order_id, summary, priority_code, created_at
FROM factorycare.work_order;
