# DML 写入安全故障实验

先填 `worksheet.md`，再运行 `./verify.sh`。实验覆盖新增、更新、冲突、零影响，以及漏 WHERE、UPSERT 覆盖不可变字段和忽略 affected rows。oracle 在内存状态机中重放并证明 ROLLBACK 基线；不连接 PostgreSQL。
