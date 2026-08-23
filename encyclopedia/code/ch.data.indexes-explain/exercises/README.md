# 练习：索引证据决策
+
## 同一命令完成红—绿闭环

只修改本目录 README 指定的可编辑答案文件，然后始终运行 `./verify.sh`；无需猜测或改用隐藏的 oracle 命令。

- `0` + `EXERCISE_GREEN`：公开 oracle 接受当前答案；
- `41` + `EXPECTED_RED`：精确识别到教材 starter 的首个失败；
- `43`：部分修复、语法/文件/依赖异常或其他未知失败，需要阅读 stderr 继续定位。

本练习是离线语义 oracle；即使返回 0，也不等于已经在 PostgreSQL 18、pgJDBC、MyBatis 或 Flyway 上执行。真实数据库证据以正文和 lab 明示的实机门为准。

当前 `answer.json` 是故意失败的 starter。执行 `./verify.sh` 应得到 `EXPECTED_RED`；第一处错误是建前后结果指纹不同，证明正确性优先于性能结论。

修复时保持固定分布，按“status 等值、created_at 范围、稳定排序”选择复合列顺序；只有 buffers 证据改善才保留候选；拒绝无收益状态索引；把函数谓词改为半开时间范围，并写出回滚 DDL。
