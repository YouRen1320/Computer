# 事务原子性示例

`scenarios.json` 固定成功提交和 history 唯一冲突后的整体回滚；`protocol.sql` 给出 PostgreSQL 18 两个显式事务的操作顺序。执行 `./verify.sh` 会用离线状态机证明工单与 history 一起提交或一起回滚。

oracle 不连接 PostgreSQL，因此不能证明真实 MVCC、约束错误或持久化行为；SQL 脚本只应在可丢弃夹具上执行。
