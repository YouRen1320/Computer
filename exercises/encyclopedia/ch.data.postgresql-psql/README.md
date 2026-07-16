# 练习：修复 psql 执行计划

starter 故意依赖默认目标、读取启动文件、允许密码提示、遇错继续，并缺少只读事务。

只修改 `plan.json` 与 `scripts/inspect-session.sql`，使其满足：

- 目标为 `factorycare_reader@127.0.0.1:55432/factorycare_training`；
- 连接上限 2 秒；
- `-X --no-password --set=ON_ERROR_STOP=1 --file=...`；
- 连接/会话身份探针；
- 脚本显式拥有一段只读事务，不叠加 `--single-transaction`；
- 无密码、DDL、DML、角色管理或外部连接。

初始 `./verify.sh` 应打印 `PSQL EXERCISE STARTER EXPECTED FAILURE` 并退出 0。
