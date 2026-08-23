# 可重复恢复演练模型

`backup_drill.py` 用确定性内存数据演示外置密钥引用、摘要与认证标签、隔离恢复、RPO/RTO 计算以及 FactoryCare 工单不变量。它使用明确标为 test-only 的异或流与 HMAC，只能验证控制流程，不能作为生产密码学实现。

已验证：本目录单元测试能恢复夹具，能拒绝篡改、生产目标、非空目标、业务不变量破坏和超出目标的时间线。

未验证：PostgreSQL 18、`pg_basebackup`、`pg_verifybackup`、WAL/PITR、对象存储、KMS、Docker、Ubuntu Server 以及真实数据规模均未在此目录启动或操作。
