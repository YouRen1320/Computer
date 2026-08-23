# 聚合独立练习（红色 starter）
+
## 同一命令完成红—绿闭环

只修改本目录 README 指定的可编辑答案文件，然后始终运行 `./verify.sh`；无需猜测或改用隐藏的 oracle 命令。

- `0` + `EXERCISE_GREEN`：公开 oracle 接受当前答案；
- `41` + `EXPECTED_RED`：精确识别到教材 starter 的首个失败；
- `43`：部分修复、语法/文件/依赖异常或其他未知失败，需要阅读 stderr 继续定位。

本练习是离线语义 oracle；即使返回 0，也不等于已经在 PostgreSQL 18、pgJDBC、MyBatis 或 Flyway 上执行。真实数据库证据以正文和 lab 明示的实机门为准。

修复 `answer.sql`：只选择分组键与 aggregate；WHERE 只过滤 enabled 行；HAVING 过滤至少两台不同设备的组；同时输出事件数、不同设备数、非 NULL 时长数、总和与平均值。

`./verify.sh` 在 starter 上以 41 返回 `EXPECTED_RED`；修正后仍运行同一命令，并以 0 返回 `EXERCISE_GREEN`。
