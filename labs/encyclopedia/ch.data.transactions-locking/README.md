# 事务、锁与死锁实验

先按 `two-session.md` 预测每一步，再执行 `./verify.sh` 检查确定性调度模型。资产覆盖 Read Committed 不可重复读、正常锁等待、读后写丢更新、相反锁顺序死锁，以及回滚后整事务重试的一次副作用。

离线 oracle 不连接 PostgreSQL；真实验收仍需两个 psql 业务会话和一个观察会话，并保存 SQLSTATE、blocking PID、锁视图与最终状态。
