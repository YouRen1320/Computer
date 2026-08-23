# SELECT 行集独立练习（红色 starter）
+
## 同一命令完成红—绿闭环

只修改本目录 README 指定的可编辑答案文件，然后始终运行 `./verify.sh`；无需猜测或改用隐藏的 oracle 命令。

- `0` + `EXERCISE_GREEN`：公开 oracle 接受当前答案；
- `41` + `EXPECTED_RED`：精确识别到教材 starter 的首个失败；
- `43`：部分修复、语法/文件/依赖异常或其他未知失败，需要阅读 stderr 继续定位。

本练习是离线语义 oracle；即使返回 0，也不等于已经在 PostgreSQL 18、pgJDBC、MyBatis 或 Flyway 上执行。真实数据库证据以正文和 lab 明示的实机门为准。

修复 `answer.sql`，使它：

- 显式投影 `id/category/created_at`；
- 只查询 schema-qualified 的设备关系；
- 正确处理启用条件和 NULL 退役时刻；
- 用括号固定 AND/OR 分组；
- 以 `created_at, device_id` 形成全序；
- 提供 offset 0 与 2 的两页。

初始文件故意使用 `= NULL`、缺少括号并只按非唯一时间排序。运行 `./verify.sh` 时，starter 应以 41 被精确拒绝；完成答案仍由同一命令验证并以 0 结束。
