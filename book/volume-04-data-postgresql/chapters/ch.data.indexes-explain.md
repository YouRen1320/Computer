---
schema_version: 2
edition: 2026.2-draft
id: ch.data.indexes-explain
title: 索引、查询计划、EXPLAIN 与性能证据
responsibility: 教授用真实计划和数据分布判断索引价值，不以索引数量或单次耗时替代证据
volume: '04'
order: 13
level: L2
status: drafting
path: book/volume-04-data-postgresql/chapters/ch.data.indexes-explain.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.data.select-rowsets
- ch.data.ddl-constraints
- ch.foundations.testing-oracles
version_surfaces:
- postgresql-18
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释索引、查询计划、EXPLAIN 与性能证据的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - data-index
  - data-query-plan
  covers_topics:
  - data.btree-index
  - data.composite-partial-index
  - data.selectivity
  - data.explain-analyze
  - data.scan-join-plan
  - data.performance-baseline
  uses_capabilities:
  - data.sql-query
  - data.relational-schema
  - data.index-plan
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：在可重复样例数据上为 status+created_at 查询建立候选复合/部分索引，保存建前后 EXPLAIN ANALYZE
  covers_topic_groups:
  - data-index
  - data-query-plan
  covers_topics:
  - data.btree-index
  - data.composite-partial-index
  - data.selectivity
  - data.explain-analyze
  - data.scan-join-plan
  - data.performance-baseline
  uses_capabilities:
  - data.sql-query
  - data.relational-schema
  - data.index-plan
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入低选择性单列索引、列顺序不匹配和函数导致索引失效，比较计划与缓冲读后修复，并把异常定位到第一处可信证据
  covers_topic_groups:
  - data-index
  - data-query-plan
  covers_topics:
  - data.btree-index
  - data.composite-partial-index
  - data.selectivity
  - data.explain-analyze
  - data.scan-join-plan
  - data.performance-baseline
  uses_capabilities:
  - data.sql-query
  - data.relational-schema
  - data.index-plan
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 索引、查询计划、EXPLAIN 与性能证据

> 本章状态为 `drafting`。稳定核心是“结果正确性不变，以可重复数据、计划和资源读数证明优化”；PostgreSQL **18** 的索引与 `EXPLAIN` 语义于 **2026-07-17** 按官方文档核对。本机没有 PostgreSQL server/`psql`，配套资产使用固定数据分布和离线 oracle 检查实验合同。离线 PASS 不证明 PostgreSQL 实际选择了某个计划，也不证明真实延迟改善。

## 1. 索引不是“加速按钮”，而是一项有成本的访问路径

一张表可以想成一本按写入位置摆放的工单档案。没有合适索引时，数据库可能逐页查看；索引则额外维护“键值 → 行位置”的有序结构，让规划器有机会少读数据。这里有三个必须同时记住的事实：

1. 索引不改变查询应返回的关系结果；建前建后结果不同，先查正确性错误。
2. 索引只提供候选访问路径，规划器可以拒绝它。
3. 索引会占空间，并增加 `INSERT`、`UPDATE`、`DELETE`、VACUUM 和缓存压力。

因此本章不以“出现 `Index Scan`”为成功，也不以“索引越多越好”为策略。目标是回答：

```text
固定哪条业务查询？
数据规模和分布是什么？
查询选择了多少行？
候选索引如何匹配谓词与排序？
建前后结果是否完全一致？
估算行数、实际行数、节点、缓冲读发生了什么变化？
写入与维护成本是否值得？
```

### 完成标准

学习者应能：

- 解释 B-tree 对等值、范围与排序查询的适用边界；
- 从查询形状推导复合索引列顺序，而不是背“选择性最高放最左”；
- 说明部分索引的谓词为什么必须能由查询条件推出；
- 计算一个谓词的样例选择性，并知道统计信息只是近似；
- 区分 `EXPLAIN` 的估算与 `EXPLAIN ANALYZE` 的真实执行；
- 自底向上阅读扫描、排序、限制和连接节点；
- 比较 estimated rows 与 actual rows，而不只盯耗时；
- 固定 SQL、参数、数据、统计、配置和测量轮次；
- 注入并诊断低选择性索引、错误列顺序和表达式不匹配；
- 拒绝无收益索引，并记录删除与回滚办法。

本章不展开 GIN/GiST/BRIN 调优、索引膨胀治理、生产压测平台、分区、慢查询采集或参数全局调优。

## 2. 固定 FactoryCare 查询合同

FactoryCare 运维调度页需要取最近的未完成工单：

```sql
SELECT work_order_id, status, created_at, device_id, priority
FROM factorycare.work_order
WHERE status = 'OPEN'
  AND created_at >= TIMESTAMPTZ '2026-06-01 00:00:00+08'
  AND created_at <  TIMESTAMPTZ '2026-07-01 00:00:00+08'
ORDER BY created_at DESC, work_order_id DESC
LIMIT 50;
```

这条查询的合同包含：

- 等值条件 `status = 'OPEN'`；
- 时间半开区间，避免月底精度漏洞；
- `created_at DESC, work_order_id DESC` 的确定性排序；
- `LIMIT 50`；
- 返回列集合固定；
- 时间参数和状态参数固定。

如果优化前用六月、优化后改成七月，比较无效。如果优化前没稳定的第二排序键，两个同时间工单的顺序可能变化，也无法证明分页一致。

示例表：

```sql
CREATE TABLE factorycare.work_order (
  work_order_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  device_id bigint NOT NULL,
  assigned_to bigint,
  status text NOT NULL CHECK (
    status IN ('OPEN', 'IN_PROGRESS', 'DONE', 'CANCELLED')
  ),
  priority smallint NOT NULL CHECK (priority BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL,
  summary text NOT NULL
);
```

不要为了展示索引只插入十行。小表往往一个数据页就读完，顺序扫描完全合理。实验数据应固定规模与分布，例如 100,000 行：

| status | 行数 | 比例 | 含义 |
| --- | ---: | ---: | --- |
| DONE | 85,000 | 85% | 历史完成工单 |
| OPEN | 8,000 | 8% | 等待调度 |
| IN_PROGRESS | 5,000 | 5% | 正在维修 |
| CANCELLED | 2,000 | 2% | 已取消 |

这个分布不是生产事实，而是可重放的教学夹具。必须把规模、比例、时间范围、生成算法和 PostgreSQL 版本一起保存。

## 3. B-tree：默认索引的核心语义

PostgreSQL 的 `CREATE INDEX` 默认创建 B-tree。官方文档明确列出它适合可排序类型的 `<`、`<=`、`=`、`>=`、`>`，也能处理相应的 `BETWEEN`、`IN`、`IS NULL`、`IS NOT NULL`，并可能提供有序输出。

```sql
CREATE INDEX work_order_created_at_idx
ON factorycare.work_order (created_at);
```

它可能帮助时间范围查询，但不代表对固定调度查询就是最佳选择：数据库还要筛 `status`，并处理同一时间的 `work_order_id` 排序。另一方面，如果时间范围覆盖表中大部分行，走索引再访问大量堆页可能比顺序扫描更贵。

### 3.1 选择性

选择性可先粗略理解为：

```text
选择性 = 符合条件的行数 / 总行数
```

在固定夹具中，`status = 'DONE'` 的选择性为 0.85，`status = 'OPEN'` 为 0.08。低比例通常更可能从索引获益，但这不是阈值定律。行宽、物理相关性、缓存、返回列、排序、LIMIT、随机页成本和数据页数量都会参与成本估算。

规划器不会每次完整计数，而是使用 `ANALYZE` 写入的近似统计。`pg_stats` 中常见信息包括空值比例、不同值估计、最常见值及频率、直方图。若估算 50 行而实际 20,000 行，首先检查统计、参数与列相关性，而不是立即强制某个扫描节点。

```sql
ANALYZE factorycare.work_order;

SELECT attname, null_frac, n_distinct, most_common_vals, most_common_freqs
FROM pg_stats
WHERE schemaname = 'factorycare'
  AND tablename = 'work_order';
```

### 3.2 为什么 `status` 单列索引可能无收益

```sql
CREATE INDEX work_order_status_idx
ON factorycare.work_order (status);
```

状态只有四种。查占 85% 的 `DONE` 时，索引需要返回绝大多数行，通常没有减少足够工作。即便查 `OPEN`，它也不能直接满足时间排序与时间范围。是否保留必须由真实工作负载证明，不能因为 DDL 成功就算完成。

## 4. 复合 B-tree：列顺序由查询形状决定

固定查询更直接的候选是：

```sql
CREATE INDEX work_order_status_created_id_idx
ON factorycare.work_order (status, created_at DESC, work_order_id DESC);
```

推导过程是：

1. `status` 是前导等值条件；
2. `created_at` 是范围条件，同时是第一排序键；
3. `work_order_id` 是第二排序键，保证相同时间下稳定；
4. 扫描方向与索引排序可帮助前 50 行尽早返回。

PostgreSQL 18 对多列 B-tree 的基本规则是：前导列的等值约束，加上第一个没有等值约束列的范围约束，稳定地限制需要扫描的索引区间。右侧列条件可以在索引中检查，但不一定缩短扫描区间。

### 4.1 不能把“最有选择性的列放最左”当口诀

若把索引写成 `(created_at, status)`，时间范围先形成一段扫描区间；`status` 常只能在区间内继续过滤。对“状态等值 + 时间范围”的主查询，`(status, created_at)`通常更贴形状。反过来，如果主工作负载多数只按时间查，不带状态，那么另一种顺序或独立时间索引可能更合理。

### 4.2 PostgreSQL 18 的 skip scan 不是合同保证

PostgreSQL 18 文档描述了多列 B-tree 的 skip scan：当缺失前导列条件且前导列不同值很少时，规划器可能对每个前导值生成重复搜索。它是成本驱动的选择，不等于 `(status, created_at)` 对只查 `created_at` 永远高效。不同分布、统计或规模可能让规划器改用顺序扫描。

### 4.3 INCLUDE 不是免费的

若调度页只返回少量列，可以评估：

```sql
CREATE INDEX work_order_status_created_cover_idx
ON factorycare.work_order (status, created_at DESC, work_order_id DESC)
INCLUDE (device_id, priority);
```

`INCLUDE` 列不是搜索键，却能让索引包含返回值，为 Index Only Scan 创造条件。但索引变宽、写放大增加，而且 MVCC 可见性仍可能迫使访问堆页。看到 Index Only Scan 也必须查看 Heap Fetches 与缓冲读。

## 5. 部分索引：只索引业务关注的子集

调度页只关心未完成工单，可建立：

```sql
CREATE INDEX work_order_active_created_id_idx
ON factorycare.work_order (created_at DESC, work_order_id DESC)
INCLUDE (status, device_id, priority)
WHERE status IN ('OPEN', 'IN_PROGRESS');
```

它不保存 `DONE` 和 `CANCELLED`，可能更小，相关写入维护也更少。但部分索引能被使用的关键不是“人觉得意思一样”，而是规划时查询条件必须能推出索引谓词。

固定查询 `status = 'OPEN'` 能推出 `status IN ('OPEN','IN_PROGRESS')`。下面的查询不能：

```sql
SELECT ...
FROM factorycare.work_order
WHERE created_at >= $1;
```

它可能返回完成工单，所以不能只读活动工单索引。

部分索引还有两个常见陷阱：

- 谓词与查询写法需要让规划器在规划时识别蕴含；PostgreSQL 不是通用定理证明器。
- 参数化条件如 `status = $1` 的通用计划未必能证明任意 `$1` 都满足固定谓词。

因此要保存真实 prepared statement 形状和绑定方式，不能只在 psql 中用字面量证明一次。

## 6. `EXPLAIN` 究竟输出什么

`EXPLAIN` 显示规划器选择的计划，但默认不执行语句：

```sql
EXPLAIN (FORMAT TEXT)
SELECT ...;
```

一个节点常见字段：

```text
cost=startup..total rows=estimated width=bytes
```

- `startup cost`：产出第一行前的估算成本；
- `total cost`：消费完该节点所有行的估算成本；
- `rows`：每次执行该节点预计输出行数；
- `width`：预计每行平均字节数。

cost 是规划器内部比较单位，不是毫秒。两个不同机器上的 cost 不能当延迟，cost 降低也不是用户体验已经改善的证明。

### 6.1 `EXPLAIN ANALYZE` 会真实执行

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT ...;
```

这会得到 `actual time`、actual `rows`、`loops`、Planning Time、Execution Time 与缓冲信息。对写语句也会产生真实副作用；要分析 DML 而不保留修改，应明确包在事务中回滚：

```sql
BEGIN;
EXPLAIN (ANALYZE, BUFFERS)
UPDATE factorycare.work_order
SET priority = priority + 1
WHERE work_order_id = 42;
ROLLBACK;
```

不要在生产上对未知重查询随手执行 `ANALYZE` 选项。它不是“更详细的静态解释”，而是一次真实运行。

### 6.2 BUFFERS 比单次时间更稳定，但仍要解释上下文

PostgreSQL 18 中 BUFFERS 可报告 shared/local/temp block 的 hit、read、dirtied、written。`shared hit` 表示需要的块已在缓存，从而避免了物理读；它不等于零成本。父节点的缓冲数包含子节点，不能把每层数字简单相加。

冷缓存、暖缓存、并发噪声、I/O、CPU 频率和计时开销都会影响时间。教学实验至少同时保存：实际行数、loops、扫描节点、排序节点、Rows Removed、heap blocks/heap fetches、shared hit/read 和最终结果指纹。

## 7. 自底向上读计划树

计划是树，不是一行结论。缩进更深的是子节点；数据从子节点流向父节点。

### 7.1 常见扫描节点

- `Seq Scan`：逐页扫描表。小表、返回比例高、缺合适索引时可能是最佳方案。
- `Index Scan`：按索引定位，再访问表取得行或其他列。
- `Index Only Scan`：所需列可由索引提供，但仍受可见性图影响；检查 Heap Fetches。
- `Bitmap Index Scan`：收集符合条件的行位置位图。
- `Bitmap Heap Scan`：按页访问位图指定的堆块，可能重新检查条件。

`Seq Scan` 不是失败标签，`Index Scan` 也不是胜利标签。若查 85% 行，顺序扫描可能以更少随机访问完成。

### 7.2 过滤、排序与限制

- `Index Cond` 表示用于缩小索引访问范围的条件；
- `Filter` 表示行取出后才检查的条件；
- `Rows Removed by Filter` 揭示做了多少无效工作；
- `Sort` 要看排序键、算法、内存或磁盘；
- `Limit` 可能让上游节点提前停止，actual rows 应结合 loops 和提前终止理解。

错误列顺序常表现为：时间条件是 `Index Cond`，状态只是 `Filter`，读取的候选行远大于最终 50 行。表达式不匹配可能让两个条件都落在 Filter。

### 7.3 连接节点

即使本章主查询是一张表，也要认识连接计划：

- `Nested Loop`：外侧每行驱动内侧查找；外侧很小且内侧有合适索引时很强。
- `Hash Join`：一侧建哈希表，另一侧探测，常见于较大等值连接。
- `Merge Join`：两侧按连接键有序后归并。

节点名不能脱离行数解释。估算外侧 10 行、实际 100,000 行时，规划器可能错误选择重复内侧访问；第一处可信证据是估算与实际开始大幅分叉的位置。

## 8. 一套可审计的建前/建后基线

性能实验应像测试，而不是演示。推荐记录：

```text
1. 固定 PostgreSQL 大版本、配置与硬件说明
2. 重建确定性样例数据，记录总行数和状态分布
3. ANALYZE
4. 固定 SQL 文本、参数、返回列和排序
5. 保存结果行数与稳定指纹
6. 保存建前 EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
7. 创建一个候选索引并再次 ANALYZE
8. 用同一参数、同一轮次策略重跑
9. 比较计划、估算/实际、buffers 和结果指纹
10. 记录索引大小、写入代价、保留/拒绝与回滚 DDL
```

结果指纹可以对稳定排序后的主键列表做摘要。仅比较 `count(*)` 不够：两个错误结果可能恰好行数相同。

```sql
SELECT count(*) AS row_count,
       md5(string_agg(work_order_id::text, ',' ORDER BY created_at DESC, work_order_id DESC)) AS result_fingerprint
FROM (
  -- 原查询，不含最终展示列之外的随机值
) AS q;
```

### 8.1 为什么要多轮

第一轮可能包含磁盘读取，后续轮次可能主要命中缓存。不能只挑最快的一次。记录冷/暖状态，采用固定预热方案，报告多轮分布而非单个漂亮数字。教学资产没有真实计时，所以只验证证据字段完整，不虚构毫秒改进。

### 8.2 回滚计划

候选索引无收益时：

```sql
DROP INDEX factorycare.work_order_status_created_id_idx;
```

生产环境创建/删除索引还涉及阻塞、`CONCURRENTLY` 的事务限制、失败索引和部署策略，本章不执行。这里必须先记录索引名称、依赖查询、观察窗口和删除条件。

## 9. 三类故障注入与诊断

### 故障 A：低选择性单列索引

注入：只建 `(status)`，然后用 `status='DONE'` 查询 85% 数据。

错误结论：“没有 Index Scan，所以 PostgreSQL 忽略了我的优化。”

诊断证据：

1. 总行数与符合行数；
2. 选择性 0.85；
3. `Seq Scan` 的 actual rows 与 buffers；
4. 索引大小和写维护成本；
5. 结论为拒绝无收益索引，而不是强制索引。

### 故障 B：复合列顺序不匹配

注入：为主查询创建 `(created_at, status)`。

症状可能是扫描大量时间范围条目后再按 status 过滤，或仍需额外排序。修复候选为 `(status, created_at DESC, work_order_id DESC)`，但必须用相同夹具重测；不能仅凭口诀宣布修复。

### 故障 C：函数包住列

注入：

```sql
WHERE date(created_at) = DATE '2026-06-15'
  AND status = 'OPEN'
```

普通 `created_at` B-tree 不一定能把 `date(created_at)` 当同一个搜索键。优先把查询改写为可索引的半开时间范围：

```sql
WHERE created_at >= TIMESTAMPTZ '2026-06-15 00:00:00+08'
  AND created_at <  TIMESTAMPTZ '2026-06-16 00:00:00+08'
```

如果业务确实大量按某个不可改表达式查询，可以评估表达式索引，但时区、函数不变性、写成本与查询表达式一致性都要纳入合同。

## 10. 诊断顺序：定位第一处可信偏差

面对“索引失效”，按以下顺序，避免随机加索引：

1. **结果合同**：SQL、参数、时区、排序、LIMIT 是否相同？
2. **样例规模**：是否只有几十行或一个数据页？
3. **数据分布**：谓词实际命中多少行？是否高度倾斜？
4. **统计新鲜度**：是否执行 `ANALYZE`？estimated/actual 从哪里开始分叉？
5. **谓词可用性**：操作符、类型转换、函数、collation 是否匹配索引？
6. **复合顺序**：等值、范围、排序如何对应前导键？
7. **部分谓词**：查询能否在规划时推出谓词？是否用了通用参数计划？
8. **节点工作量**：Index Cond、Filter、Rows Removed、loops、buffers 如何？
9. **环境差异**：缓存、配置、并发、硬件是否一致？
10. **成本决策**：顺序扫描是否本来就更便宜？

不要用 `SET enable_seqscan = off` 当修复。它可以帮助实验“若强制另一计划会怎样”，却会扭曲正常成本选择，不能作为生产证据。

## 11. 索引验收决策表

| 问题 | 保留候选索引的证据 | 拒绝或继续调查 |
| --- | --- | --- |
| 结果正确吗 | 主键序列与指纹一致 | 任一结果差异先修 SQL |
| 规模可复现吗 | 行数、分布、生成器固定 | 玩具表或分布未知 |
| 计划解释得通吗 | 条件落到预期 Index Cond，行数估算合理 | 只说出现 Index Scan |
| 资源减少吗 | relevant buffers/扫描候选显著减少 | 只比较一次毫秒 |
| 排序受益吗 | 无多余 Sort 或提前满足 LIMIT | 仍全量排序且无解释 |
| 写入成本可接受吗 | 索引大小与写负载有预算 | 忽略维护和空间 |
| 工作负载稳定吗 | 参数范围和频率有记录 | 只为一次查询定制 |
| 可回滚吗 | 命名、删除、观察条件明确 | 无法知道谁依赖索引 |

索引价值是“在已知工作负载中收益大于总成本”，不是“数据库愿意创建”。

## 12. 配套资产与独立构建

本章提供四类入口：

- `examples/encyclopedia/ch.data.indexes-explain/`：固定分布、查询形状、候选索引与建前/建后证据合同；
- `labs/encyclopedia/ch.data.indexes-explain/`：低选择性、错列顺序、函数条件三项故障注入；
- `exercises/encyclopedia/ch.data.indexes-explain/`：故意失败的索引决策 starter；
- `solutions-private/encyclopedia/ch.data.indexes-explain/`：通过相同 oracle 的私有参考解。

离线 oracle 检查：结果指纹不变、规模/分布字段齐全、计划节点和 buffers 证据存在、无收益索引有拒绝结论。它不生成假的 PostgreSQL 计划。

独立构建报告至少回答：

```text
query-id:
sql-and-bindings:
dataset-size-and-distribution:
baseline-result-fingerprint:
baseline-plan-evidence:
candidate-index-and-rationale:
after-result-fingerprint:
after-plan-evidence:
write-and-space-cost:
decision-keep-or-reject:
rollback:
```

## 13. 120 秒讲回检查

不看笔记解释：

1. 为什么索引存在不代表规划器必须使用？
2. 为什么 `(status, created_at)` 适合固定查询，而不是普遍优于 `(created_at, status)`？
3. `EXPLAIN` 与 `EXPLAIN ANALYZE` 最大的安全差异是什么？
4. estimated rows 与 actual rows 大幅不同说明先查什么？
5. 为什么 `Seq Scan` 可能是正确计划？
6. 怎样证明优化没有改坏结果？
7. 为什么一次耗时不是性能证据？

能讲清责任、边界、一个失败反例、诊断第一证据和回滚，才达到 explain outcome。

## 14. 官方与主来源

- [PostgreSQL 18 Index Types](https://www.postgresql.org/docs/18/indexes-types.html)：B-tree 等索引类型与可用操作符；
- [PostgreSQL 18 Multicolumn Indexes](https://www.postgresql.org/docs/18/indexes-multicolumn.html)：前导列规则与 skip scan；
- [PostgreSQL 18 Partial Indexes](https://www.postgresql.org/docs/18/indexes-partial.html)：部分谓词、蕴含与参数化边界；
- [PostgreSQL 18 Using EXPLAIN](https://www.postgresql.org/docs/18/using-explain.html) 与 [EXPLAIN command](https://www.postgresql.org/docs/18/sql-explain.html)：计划节点、ANALYZE、BUFFERS 与安全注意；
- [PostgreSQL 18 Planner Statistics](https://www.postgresql.org/docs/18/planner-stats.html)：选择性估计和 `pg_stats`。

稳定核心是测量合同、结果不变、选择性与证据推理；版本相关面是 PostgreSQL 18 的具体计划字段、skip scan、成本模型和 planner 行为。真实 PostgreSQL 18 执行仍未验证。
