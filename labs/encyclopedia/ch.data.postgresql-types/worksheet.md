# 实验记录表

1. 为 UUID、JSONB、数组、domain 与 enum 的合法值、SQL `NULL`、非法值写出预测，再运行 verifier 对照。
2. 对三项故障注入逐一写出：被破坏的查询或约束需求、诊断证据、替代模型。
3. 解释为什么 JSONB 顶层 JSON `null` 与 SQL `NULL` 不同，为什么空数组与 SQL `NULL` 也不同。
4. 为每项 PostgreSQL 专用类型记录迁移到另一数据库时的转换边界与数据回填办法。
