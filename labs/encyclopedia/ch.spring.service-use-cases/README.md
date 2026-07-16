# 派单事务与分层实验

实验使用 Spring Framework 7 的真实事务 interceptor、DataSourceTransactionManager、JdbcTemplate 和 H2。成功时工单、核心审计与 outbox 一起提交；audit/outbox 故障时全部回滚。

唯一入口 `./verify.sh` 离线执行十项验收。H2 不证明 PostgreSQL 18 的并发隔离、锁、错误码或执行计划。
