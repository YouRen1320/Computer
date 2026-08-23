# JOIN 独立练习（红色 starter）
+
## 同一命令完成红—绿闭环

只修改本目录 README 指定的可编辑答案文件，然后始终运行 `./verify.sh`；无需猜测或改用隐藏的 oracle 命令。

- `0` + `EXERCISE_GREEN`：公开 oracle 接受当前答案；
- `41` + `EXPECTED_RED`：精确识别到教材 starter 的首个失败；
- `43`：部分修复、语法/文件/依赖异常或其他未知失败，需要阅读 stderr 继续定位。

本练习是离线语义 oracle；即使返回 0，也不等于已经在 PostgreSQL 18、pgJDBC、MyBatis 或 Flyway 上执行。真实数据库证据以正文和 lab 明示的实机门为准。

修复 `answer.sql`：

- 用显式 JOIN ... ON 连接设备与工单；
- CREATED 条件放在 LEFT JOIN 的 ON 中以保留无匹配设备；
- 技师计数使用 COUNT(w.work_order_id)；
- 输出全体技师计数，并用 HAVING >=2 输出高负载组。

`./verify.sh` 在 starter 上以 41 返回 `EXPECTED_RED`；修正后同一命令以 0 返回 `EXERCISE_GREEN`。
