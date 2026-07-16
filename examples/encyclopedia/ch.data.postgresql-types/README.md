# PostgreSQL 类型选择：可重放示例

`decisions.json` 记录 FactoryCare 设备事实的类型、约束与可移植性决策；`cases.json` 固定合法值、SQL `NULL` 和非法值；`schema.sql` 给出 PostgreSQL 18 DDL。执行 `./verify.sh` 会用离线语义 oracle 检查决策矩阵、边界用例与关键 DDL 约束，并与 `expected.out` 比较。

此示例不连接 PostgreSQL，因此证明的是类型决策和边界断言可重放，不证明本机 PostgreSQL 18 实际执行结果。
