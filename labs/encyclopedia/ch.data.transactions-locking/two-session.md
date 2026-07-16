# 两会话执行顺序

1. A：`BEGIN ISOLATION LEVEL READ COMMITTED;`，读取 W-42 状态。
2. B：`BEGIN; UPDATE ... W-42; COMMIT;`。
3. A：再次读取 W-42，记录不可重复读，然后 `ROLLBACK`。
4. 重置夹具。A 先 `SELECT ... W-42 FOR UPDATE`；B 更新 W-42 并等待；观察会话保存 `wait_event_type`、`pg_blocking_pids` 与 `pg_locks.granted`。
5. 重置夹具。A 锁 W-42，B 锁 W-43，A 请求 W-43，B 请求 W-42；保存被中止方 SQLSTATE `40P01`。
6. 双方改为按 42、43 升序锁定；失败方先回滚，再从 `BEGIN` 重试完整命令 `C-100`。
7. 断言最终每张工单只增加一个版本，`command_id=C-100` 的 history 恰好一条。

本文件是操作合同，不是实机日志。实际运行需记录 PostgreSQL 版本、会话 PID、每步输入/输出和最终断言。
