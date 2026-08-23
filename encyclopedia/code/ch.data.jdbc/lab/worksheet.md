# JDBC 故障记录

运行前预测：

1. 注入字符串怎样从值变成 SQL 结构？
2. 100 次查询不关闭三个资源会留下什么证据？
3. SQL NULL 经 `getLong` 且不调用 `wasNull` 会变成什么？
4. autoCommit=false 时 history 失败但不 rollback，为什么 close 不是可移植恢复？
5. 0 行怎样显式表示？

每项记录 operation、SQL 模板、参数类型、SQLState、事务动作、资源 close 次数和数据库最终状态。
