# DDL 与约束故障实验

先填 `worksheet.md`，再运行 `./verify.sh`。实验覆盖外键方向错误、缺状态 CHECK、ALTER 遭遇 BROKEN 存量行，以及失败重建回滚。oracle 只模拟约束与原子结构替换，不连接 PostgreSQL。
