# 实验：pgvector 合同与受控 ANN 夹具

`verify.sh` 验证距离数学、Embedding 空间隔离、SQL 结构合同、精确基准与受控近似候选的 `recall@k`。版本基线是 2026-07-24 查阅官方资料得到的 PostgreSQL 18.4 与 pgvector 0.8.2。

```bash
./verify.sh
```

## 证据边界

本目录**没有启动数据库服务**，`ann_fixture.py` 只是确定性候选夹具；`service_evidence.json` 明确记录 `real_service_verified=false`。因此这里没有验证扩展安装、真实 HNSW/IVFFlat 构建、规划器选路、并发、磁盘、缓存或真实延迟。完成 T4 门禁仍必须用固定镜像启动 PostgreSQL，执行 `schema.sql`，保存 `SELECT version()`、`SELECT extversion`、真实 `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)`、精确/近似逐查询排名、recall 与延迟分布。

FactoryCare 的工单状态、ACL 与业务事实仍归 Java；该表是可删除重建的检索投影，每次查询必须接收 Java 已授权的 chunk ID 集合。
