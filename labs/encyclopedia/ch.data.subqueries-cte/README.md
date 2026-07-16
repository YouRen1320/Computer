# 子查询、CTE 与集合拆解故障实验

先在 `worksheet.md` 写预测，再运行 `./verify.sh`。实验覆盖空子集、多匹配、NOT IN 右集合含 NULL、相关列引用错层、CTE 第一层行集错误，以及拆分前后等价性。

oracle 独立按固定 CSV 计算结果并检查 `query.sql` 的关键结构，不执行 PostgreSQL。真实数据库解析、执行计划与 CTE 是否被折叠不在此离线证据中。
