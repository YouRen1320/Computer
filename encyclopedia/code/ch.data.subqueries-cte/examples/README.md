# 子查询与 CTE 可运行示例

`query.sql` 给出 EXISTS、标量计数、扁平聚合与两层 CTE 四个查询。`devices.csv` 和 `work_orders.csv` 是固定 FactoryCare 夹具。

运行 `./verify.sh`。离线 oracle 会核对 SQL 的关键语义结构，独立计算每个中间集合，并证明扁平版与 CTE 版结果一致；它不会连接 PostgreSQL 或验证执行计划。
