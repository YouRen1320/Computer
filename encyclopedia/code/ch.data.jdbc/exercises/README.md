# 练习：修复 JDBC 边界
+
## 同一命令完成红—绿闭环

只修改本目录 README 指定的可编辑答案文件，然后始终运行 `./verify.sh`；无需猜测或改用隐藏的 oracle 命令。

- `0` + `EXERCISE_GREEN`：公开 oracle 接受当前答案；
- `41` + `EXPECTED_RED`：精确识别到教材 starter 的首个失败；
- `43`：部分修复、语法/文件/依赖异常或其他未知失败，需要阅读 stderr 继续定位。

本练习是离线语义 oracle；即使返回 0，也不等于已经在 PostgreSQL 18、pgJDBC、MyBatis 或 Flyway 上执行。真实数据库证据以正文和 lab 明示的实机门为准。

当前 `answer.json` 故意拼接不可信输入。执行 `./verify.sh` 应得到 `EXPECTED_RED`。

修复要求：一个参数槽且 SQL 结构不变；NULL/OffsetDateTime 正确映射；空结果显式；三个资源各关闭一次；多语句使用同一 Connection、autoCommit=false、失败 rollback；按 SQLState 分类并保留原 cause。
