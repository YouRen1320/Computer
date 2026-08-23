# 耗尽、迁移与 readiness 实验

实验在 max=1/2 的有限 Hikari 池中重放借还和耗尽，并从空库证明 `migration -> readiness -> traffic`。关闭池模拟数据库不可用，readiness 必须转为 false。

唯一入口 `./verify.sh` 离线执行十项验收。H2 只承担稳定 JDBC 替身；PostgreSQL 18 方言、隔离和生产容量不在本实验结论内。
