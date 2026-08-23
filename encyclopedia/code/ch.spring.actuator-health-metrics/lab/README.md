# Boot 4.1 Actuator HTTP 实验

实验启动真实 Boot 4.1 HTTP server，匿名读取最小 health/liveness/readiness，受认证运维用户读取 metrics；`env` 即使认证也未暴露。受控 database indicator DOWN 时 readiness 为 503 而 liveness 保持 200。工单 counter 只使用固定 priority/result 标签。

先预热 Maven 依赖，再运行 `./verify.sh`。固定结果为 10 个测试全绿。数据库 indicator 是受控 fake，不能表述为 PostgreSQL 已验证。
