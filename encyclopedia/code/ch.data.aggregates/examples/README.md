# 聚合正确示例

`query.sql` 保存目标 PostgreSQL 18 查询；`oracle.rb` 不解析 SQL，而是检查任务结构后独立对固定 CSV 分组。运行 `./verify.sh`。

PASS 只证明单表样例的计数、NULL、平均值和 HAVING 预言一致，真实 PostgreSQL 未执行。
