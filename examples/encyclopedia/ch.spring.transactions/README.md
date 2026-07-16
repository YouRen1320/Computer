# 声明式事务边界观察台

示例用 Spring Framework 7 的真实 `TransactionInterceptor`、`DataSourceTransactionManager`、CGLIB proxy、JdbcTemplate 与 H2 展示三个事实：成功时工单和审计一起提交；运行时异常让两表一起回滚；外部动作只在 `afterCommit` 发生。直接调用 target 的反例会绕过 proxy，因此数据库写入与外部动作都无法被声明式事务保护。

运行 `./verify.sh`，固定结果为 8 个测试全部通过。H2 只验证本地 JDBC 事务/代理语义，不宣称等同 PostgreSQL 隔离或锁行为。
