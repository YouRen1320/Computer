# 传播、回滚规则与提交后行为实验

实验在真实 Spring transaction proxy 与 JDBC 连接上验证 FactoryCare“创建工单 + 核心审计”边界：`REQUIRED` 与外层一起回滚；独立 collaborator 的 `REQUIRES_NEW` 可在外层回滚时单独提交；受检异常默认提交，而 `rollbackFor` 会回滚；`afterCommit` 只在成功提交后发生；self-invocation 不会产生声明的内部新事务。

运行 `./verify.sh`，固定结果为 10 个测试全部通过。实验用 H2 保持离线和确定性，未验证 PostgreSQL 18 的锁等待、隔离 anomaly 或方言；这些必须另用真实 PostgreSQL 集成测试证明。
