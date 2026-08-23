# 三层测试职责观察台

这个最小工程把三种问题分开：MockMvc 只验证 Controller 路由与 HTTP 结果；JdbcTemplate 测试执行真实 SQL；Spring `ApplicationContext` smoke test 只验证关键 Bean 图和一次贯通调用。示例故意使用 H2，因此它**不构成 PostgreSQL 方言证据**；真实 PostgreSQL 18 证据在同章 lab。

运行 `./verify.sh`。固定结果为 8 个测试全部通过，并打印三层各自的 oracle。
