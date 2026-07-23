# expand-contract 与 canary 内存模型

本目录用内存 schema 演示增加新列、旧版写入、新版双写/回退读、带 checkpoint 的分批回填、canary 自动门禁、contract 前置条件和应用回滚边界。

已验证：新旧版本能在 expand 阶段共存；失败回填从最后确认 checkpoint 重跑；坏 canary 被拒绝；只有所有证据为绿才允许删旧列。

未验证：没有运行 Flyway、PostgreSQL、Docker、Compose、Nginx、GitHub Actions 或真实流量。内存 `set` 和 `dict` 不模拟 DDL 锁、事务、复制延迟与实际发布平台。
