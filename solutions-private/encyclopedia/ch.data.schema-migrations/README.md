# 私有参考解

参考解保持已应用 checksum 不变，按 expand/backfill/validate/contract 前进；空库和升级库汇合，第二次 migrate 无 pending，失败不冒充成功，所有旧应用退场后才 contract。

执行 `./verify.sh` 应通过。该答案不替代真实 Flyway/PostgreSQL 集成测试。
