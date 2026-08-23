# DDL 与约束独立练习（红色 starter）
+
## 同一命令完成红—绿闭环

只修改本目录 README 指定的可编辑答案文件，然后始终运行 `./verify.sh`；无需猜测或改用隐藏的 oracle 命令。

- `0` + `EXERCISE_GREEN`：公开 oracle 接受当前答案；
- `41` + `EXPECTED_RED`：精确识别到教材 starter 的首个失败；
- `43`：部分修复、语法/文件/依赖异常或其他未知失败，需要阅读 stderr 继续定位。

本练习是离线语义 oracle；即使返回 0，也不等于已经在 PostgreSQL 18、pgJDBC、MyBatis 或 Flyway 上执行。真实数据库证据以正文和 lab 明示的实机门为准。

修复 `answer.sql`：外键从 work_order.device_id 指向 device.device_id；命名两表主键；为序列号加 NOT NULL+UNIQUE；为状态加 NOT NULL+CHECK；为工单设备和摘要加 NOT NULL；声明 RESTRICT；保留回滚事务。`./verify.sh` 先证明 starter 因外键方向被拒绝。
