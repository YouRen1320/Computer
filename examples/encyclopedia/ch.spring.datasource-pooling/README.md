# 连接池与启动门观察台

这里用 Spring Boot 4.1.0 管理的 HikariCP 和嵌入式数据库观察真实借还、并发、耗尽超时、迁移先行与 readiness。它不把 H2 结果冒充 PostgreSQL 18 方言或生产容量证据。

先预测事件顺序和池指标，再运行 `./verify.sh`。唯一验证入口要求 JDK 25、Maven 3.9.16，并以 `--offline` 执行。
