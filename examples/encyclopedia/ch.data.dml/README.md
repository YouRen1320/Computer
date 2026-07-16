# DML 可运行示例

`operations.sql` 在一个回滚事务中演示显式列 INSERT、版本 UPDATE、零影响旧版本、受限 DELETE、保护性零删除和按序列号 UPSERT。运行 `./verify.sh`；oracle 独立模拟固定状态并静态检查 SQL，不连接 PostgreSQL。
