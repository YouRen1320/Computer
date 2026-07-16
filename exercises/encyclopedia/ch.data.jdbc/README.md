# 练习：修复 JDBC 边界

当前 `answer.json` 故意拼接不可信输入。执行 `./verify.sh` 应得到 `EXPECTED_RED`。

修复要求：一个参数槽且 SQL 结构不变；NULL/OffsetDateTime 正确映射；空结果显式；三个资源各关闭一次；多语句使用同一 Connection、autoCommit=false、失败 rollback；按 SQLState 分类并保留原 cause。
