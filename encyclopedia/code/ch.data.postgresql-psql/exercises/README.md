# 练习：修复 psql 执行计划
+
## 同一命令完成红—绿闭环

只修改本目录 README 指定的可编辑答案文件，然后始终运行 `./verify.sh`；无需猜测或改用隐藏的 oracle 命令。

- `0` + `EXERCISE_GREEN`：公开 oracle 接受当前答案；
- `41` + `EXPECTED_RED`：精确识别到教材 starter 的首个失败；
- `43`：部分修复、语法/文件/依赖异常或其他未知失败，需要阅读 stderr 继续定位。

本练习是离线语义 oracle；即使返回 0，也不等于已经在 PostgreSQL 18、pgJDBC、MyBatis 或 Flyway 上执行。真实数据库证据以正文和 lab 明示的实机门为准。

starter 故意依赖默认目标、读取启动文件、允许密码提示、遇错继续，并缺少只读事务。

只修改 `plan.json` 与 `scripts/inspect-session.sql`，使其满足：

- 目标为 `factorycare_reader@127.0.0.1:55432/factorycare_training`；
- 连接上限 2 秒；
- `-X --no-password --set=ON_ERROR_STOP=1 --file=...`；
- 连接/会话身份探针；
- 脚本显式拥有一段只读事务，不叠加 `--single-transaction`；
- 无密码、DDL、DML、角色管理或外部连接。

初始 `./verify.sh` 应打印 `EXPECTED_RED` 并退出 41；修正 `plan.json` 与 SQL 后，仍运行同一命令并得到 `EXERCISE_GREEN` 与退出 0。
