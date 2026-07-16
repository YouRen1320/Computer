# 修复“假集成测试”

当前 fixture 名义上测试 Repository，实际注入了内存 fake，根本没有执行 SQL。运行 `./verify.sh` 会稳定得到 2 个测试中的 1 个失败，哨兵为 `EXPECTED_REAL_SQL_BOUNDARY`。

只修改 `RepositoryBoundary.open()`：为临时 H2 建表、写入 fixture，并返回 `JdbcWorkOrders`。目标是两个测试全绿。H2 只用来练习“测试必须越过所宣称的边界”；它仍不能替代同章 PostgreSQL 18 lab。
