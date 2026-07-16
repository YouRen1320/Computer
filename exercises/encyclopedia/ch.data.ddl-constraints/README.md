# DDL 与约束独立练习（红色 starter）

修复 `answer.sql`：外键从 work_order.device_id 指向 device.device_id；命名两表主键；为序列号加 NOT NULL+UNIQUE；为状态加 NOT NULL+CHECK；为工单设备和摘要加 NOT NULL；声明 RESTRICT；保留回滚事务。`./verify.sh` 先证明 starter 因外键方向被拒绝。
