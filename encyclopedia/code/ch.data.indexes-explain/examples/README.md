# 索引与 EXPLAIN 可重放示例

`schema.sql` 给出 PostgreSQL 18 的确定性数据生成、建前/建后 `EXPLAIN (ANALYZE, BUFFERS)` 与候选索引；`workload.json` 固定查询和结果指纹；`evidence.json` 是明确标注的教学证据夹具，不是伪装成实机输出的计划。

执行 `./verify.sh` 会验证规模与分布、结果不变、复合索引证据，以及低选择性单列索引因无收益被拒绝。离线 PASS 不证明本机 PostgreSQL 实际计划或延迟。
