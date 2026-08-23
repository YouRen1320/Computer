# MyBatis core 独立练习
+
## 同一命令完成红—绿闭环

只修改本目录 README 指定的可编辑答案文件，然后始终运行 `./verify.sh`；无需猜测或改用隐藏的 oracle 命令。

- `0` + `EXERCISE_GREEN`：公开 oracle 接受当前答案；
- `41` + `EXPECTED_RED`：精确识别到教材 starter 的首个失败；
- `43`：部分修复、语法/文件/依赖异常或其他未知失败，需要阅读 stderr 继续定位。

本练习是离线语义 oracle；即使返回 0，也不等于已经在 PostgreSQL 18、pgJDBC、MyBatis 或 Flyway 上执行。真实数据库证据以正文和 lab 明示的实机门为准。

`answer.json` 是故意错误的 starter。先预测第一条失败规则，再逐项修复 mapper 合同：

- 完整 statement id 与 namespace/id；
- `#{}` 路径、动态 WHERE 和空 ids 语义；
- record 列映射与空/单/多基数；
- 固定排序白名单与 N+1 查询预算；
- 带 statement id 的失败证据和同输入重跑；
- mapper 不拥有 Spring 事务代理。

运行 `./verify.sh` 应得到 `EXPECTED_RED`，这证明 starter 确实不能冒充答案。私有答案不在本目录。
