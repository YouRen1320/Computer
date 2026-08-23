# PostgreSQL：索引、执行计划、事务与锁

## 1. 数据正确后，还要解决“找得快”和“并发不乱”

表、键和约束先保护数据的结构正确。当数据和并发请求增长后，还有两类问题：

1. 查询是否需要读几百万行，才找到几十行结果；
2. 多个请求同时读写数据时，是否会丢失更新、读到不一致结果或互相等待。

索引和查询计划主要处理第一类问题；事务、MVCC 和锁主要处理第二类问题。它们彼此也会影响：长事务可以阻碍清理，索引维护会增加写入成本，锁等待会让看似快的 SQL 整体变慢。

## 2. 索引用额外结构换取某些查询的快速定位

没有合适索引时，数据库可能逐行检查整张表：

```text
表：[1][2][3][4][5]...[1,000,000]
                    每行检查 status 和 created_at
```

为常用条件建立 B-tree 索引：

```sql
CREATE INDEX idx_work_order_status_created_at
ON work_order (status, created_at DESC);
```

索引保存按键组织的条目和行位置，使数据库可以直接找到目标范围。但它不是一份免费的数据副本：

- 占用磁盘和缓存；
- `INSERT`、`UPDATE`、`DELETE` 时要维护；
- 需要 VACUUM 和统计信息等维护；
- 只对某些查询形状有用；
- 索引过多会让写入、缓存和规划选择更贵。

索引应从真实查询和性能证据出发，不是每个列都创建一个。

## 3. B-tree 适合相等、范围和有序访问

B-tree 是 PostgreSQL 默认索引类型，常适合：

```text
status = 'OPEN'
created_at >= :from
priority BETWEEN 3 AND 5
ORDER BY created_at DESC
```

它还可帮助 `min`、`max` 和前 N 条查询。但是否真正使用索引，取决于数据分布、返回行数、表大小和整体成本。

如果一张小表只有 50 行，顺序读完可能比走索引后再回表更快。计划器选择顺序扫描不代表索引“失效”。

## 4. 选择性说明条件能缩小多少数据

假设 100 万张工单中：

- `tenant_id` 有 1000 个不同值；
- `status` 只有 4 个值，其中 70% 都是 `COMPLETED`；
- `id` 每行唯一。

`id = ?` 选择性很高，结果最多一行。`status = 'COMPLETED'` 选中大部分表，单独通过索引找到数十万个位置再回表，可能比顺序扫描更贵。

所以“在布尔列上建索引一定没用”和“所有 WHERE 列都应有索引”都过于绝对。部分索引可能对少数有价值状态很有用。

## 5. 复合索引的列顺序由查询形状决定

```sql
CREATE INDEX idx_work_order_tenant_status_created
ON work_order (tenant_id, status, created_at DESC);
```

它可能支持：

```sql
WHERE tenant_id = ?
  AND status = ?
ORDER BY created_at DESC
LIMIT 20
```

B-tree 复合索引常先通过左边列定位范围，再利用后续列。因此 `(tenant_id, status)` 与 `(status, tenant_id)` 不是同一个设计。

不要把“最高选择性的列永远放最左”当成不变口诀。需要结合：

- 常用查询的相等条件；
- 范围条件在哪里开始；
- 需要的排序；
- 是否有只按索引后续列查询的独立需求；
- 数据分布和实际计划。

## 6. 部分索引只为一部分行建立条目

大多数工单已完成，业务最常查少量未完成工单时：

```sql
CREATE INDEX idx_work_order_active_created
ON work_order (tenant_id, created_at DESC)
WHERE status IN ('OPEN', 'ASSIGNED', 'IN_PROGRESS');
```

这叫**部分索引（partial index）**。它只保存满足谓词的行，因此体积和写入成本可能更低。

查询条件必须能让计划器确认它只需要该部分行。查询状态是 `COMPLETED` 时，这个索引不包含需要的行，当然不能使用。

## 7. 表达式索引与查询表达式要对应

不区分大小写查设备编码：

```sql
SELECT id
FROM device
WHERE lower(code) = lower(?);
```

普通 `code` B-tree 索引不一定直接支持 `lower(code)` 的结果。可为表达式建索引：

```sql
CREATE INDEX idx_device_lower_code
ON device (lower(code));
```

更根本的问题是：设备编码的大小写是否本来就不应有意义？如果是，可在写入边界统一正规化，用唯一约束保护。索引解决查找成本，不代替数据语义决策。

## 8. INCLUDE 列可以帮助覆盖查询

```sql
CREATE INDEX idx_work_order_device_created
ON work_order (device_id, created_at DESC)
INCLUDE (status, priority);
```

键列用于定位和排序，`INCLUDE` 列作为非键负载保存在索引中。当查询所需列都能从索引获得、且可见性条件允许时，PostgreSQL 可能使用 index-only scan，减少访问表堆。

这不代表 `INCLUDE` 越多越好。宽索引体积更大、写入更贵，且 index-only scan 是否真正发生要用计划验证。

## 9. 不同索引类型服务不同数据和操作

见过即可的概念地图：

- **B-tree**：相等、范围、排序，日常最常用；
- **GIN**：一行中有多个可检索元素，常用于 JSONB、数组和全文检索；
- **GiST**：支持多种可扩展的搜索策略，常见于几何、范围和近邻问题；
- **BRIN**：为物理相邻数据块保存摘要，适合巨大且与物理顺序高度相关的表。

这些不需要在当前背详细内部结构。需要时先根据数据类型和操作符查 PostgreSQL 官方文档，再用真实查询计划验证。

## 10. EXPLAIN 显示计划器选择的执行方案

```sql
EXPLAIN
SELECT id, status, created_at
FROM work_order
WHERE tenant_id = 42
  AND status = 'OPEN'
ORDER BY created_at DESC
LIMIT 20;
```

计划可能包含：

- `Seq Scan`：顺序扫描表；
- `Index Scan`：通过索引定位，再访问表行；
- `Index Only Scan`：尽量从索引返回数据；
- `Bitmap Index Scan` + `Bitmap Heap Scan`：先收集大批行位置，再按数据页访问；
- `Nested Loop`、`Hash Join`、`Merge Join`：不同连接策略；
- `Sort`、`Aggregate`、`HashAggregate`：排序和聚合节点。

“出现 Seq Scan”不是一个独立故障。先看表大小、预计行数、实际返回比例和整体耗时。

## 11. cost 是计划器的相对成本，不是毫秒

一个节点可能显示：

```text
cost=0.43..125.19 rows=20 width=40
```

- 第一个 cost 是产生第一行前的启动成本；
- 第二个 cost 是产生全部预计结果的总成本；
- `rows` 是计划器预计的输出行数；
- `width` 是预计每行宽度。

cost 是根据页访问、CPU 操作等模型计算的相对值，用来在候选计划间比较，不能当作真实毫秒。

预计 `rows` 与实际相差很大时，计划器可能因错误基数选了不合适的 JOIN 或扫描方式。需要查统计信息是否新鲜、列是否相关、条件是否难以估算。

## 12. EXPLAIN ANALYZE 会真正执行语句

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT ...;
```

`ANALYZE` 会运行查询并显示实际行数、循环次数和耗时。`BUFFERS` 显示命中或读取的数据页情况，能区分“CPU 快但读了大量缓存页”和“真的只访问少量数据”。

因为它真正执行，对 `UPDATE`、`DELETE`、`INSERT` 使用时必须谨慎。在非生产环境和明确可回滚事务中分析，也要考虑语句会发送外部效果或与其他 session 交互的可能。

## 13. 性能优化要保留前后证据

一次可评估的索引变更至少记录：

1. 真实 SQL 和参数分布；
2. 可代表的数据量与统计信息；
3. 变更前的 `EXPLAIN (ANALYZE, BUFFERS)`；
4. 候选索引的理由和大小；
5. 变更后的计划、耗时与 buffer 差异；
6. 写入延迟、存储和维护成本。

只记录“从 300ms 降到 20ms”而没有数据、热缓存状态和计划，很难证明改进可复现。第一次运行和重复运行可能因文件系统与数据库缓存不同而差异很大。

## 14. 事务把多步数据操作定义成一个成功单位

创建工单同时写入初始审计事件：

```text
1. INSERT work_order
2. INSERT work_order_event
```

如果第一步成功、第二步失败却仍保留第一步，系统就出现“工单存在但没有必需创建事件”的半成品。事务使二者一起提交或一起回滚：

```sql
BEGIN;

INSERT INTO work_order ...;
INSERT INTO work_order_event ...;

COMMIT;
```

任一步不能成功时：

```sql
ROLLBACK;
```

事务边界应对齐一个必须共同成功的业务不变条件，不是“每条 SQL 自己一个事务”，也不是“整个应用请求中任何事情都包在一个超长事务”。

## 15. ACID 描述事务需要提供的性质

- **Atomicity（原子性）**：事务内变更整体成功或整体不生效；
- **Consistency（一致性）**：事务将数据从一个满足规则的状态带到另一个满足规则的状态；
- **Isolation（隔离性）**：并发事务的中间过程按隔离级别受控；
- **Durability（持久性）**：已成功提交的变更在故障后仍应可恢复。

一致性不是数据库知道所有业务规则。数据库能保护已表达的类型、约束和事务操作，应用仍需要实现状态转换等领域规则。

## 16. PostgreSQL 用 MVCC 管理并发版本可见性

MVCC 是 **Multi-Version Concurrency Control（多版本并发控制）**。更新一行时，PostgreSQL 在概念上创建新行版本，不同事务根据快照和提交状态判断哪个版本可见。

```text
旧版本 v1 ── 仍对某些已开始事务可见
新版本 v2 ── 对满足可见性规则的新事务可见
```

这让普通读操作很多时候不需要阻塞普通写操作，但不表示“有 MVCC 就没有锁”。写同一行、DDL、显式锁定和约束检查仍可产生等待。

旧版本不能无限保留，VACUUM 要清理不再被任何事务需要的版本。长时间不结束的事务会保持旧快照，导致表膨胀、清理受阻和锁持有时间过长。

## 17. 隔离级别是并发可见性和冲突的契约

SQL 标准名称常见为：

- `READ UNCOMMITTED`；
- `READ COMMITTED`；
- `REPEATABLE READ`；
- `SERIALIZABLE`。

PostgreSQL 中 `READ UNCOMMITTED` 的行为与 `READ COMMITTED` 一样，不提供脏读。实际常用的核心区分：

### 17.1 READ COMMITTED

PostgreSQL 默认隔离级别。每条语句通常看到它开始时已提交的数据。同一事务的两次 `SELECT` 之间，另一事务提交的更新可能在第二次可见。

### 17.2 REPEATABLE READ

事务在更稳定的快照上工作，同一事务的重复查询不会随其他已提交变更一起改。PostgreSQL 的实现还会防止某些标准中可能的异常，但仍不等于完全串行执行。

### 17.3 SERIALIZABLE

目标是使成功事务的整体效果等价于某个串行顺序。PostgreSQL 可检测无法安全序列化的事务并中止其中一个。因此使用这个级别的应用必须能重试整个事务。

隔离级别越高不是绝对越好。要结合业务不变条件、冲突概率、重试能力和性能选择。

## 18. 丢失更新的典型过程

两个请求同时增加一个计数：

```text
事务 A 读 count = 10
事务 B 读 count = 10
事务 A 写 count = 11
事务 B 写 count = 11
最终是 11，其中一次增加丢失
```

解法不只有“提高隔离级别”：

### 18.1 用单条原子 SQL 表达变化

```sql
UPDATE device
SET repair_count = repair_count + 1
WHERE id = ?;
```

数据库在更新当前行时计算，不需要应用先把旧值读回。能用一条条件更新表达的业务变化，往往是最简单安全的方式。

### 18.2 乐观锁用版本检测过期更新

```sql
UPDATE work_order
SET status = ?,
    version = version + 1
WHERE id = ?
  AND version = ?;
```

如果影响 0 行，说明 ID 不存在或版本已变。应用可将其解释为并发冲突，重新加载并让用户决定，或在操作安全幂等时重试。

乐观锁的“锁”不是长时间持有一把数据库锁，而是在写入时检测从读取后是否被其他人修改。

### 18.3 悲观锁先锁定要修改的行

```sql
SELECT id, status
FROM work_order
WHERE id = ?
FOR UPDATE;
```

其他事务想修改同一行时需要等待。它适合冲突概率高、操作必须依赖当前状态的短事务。如果锁定后等用户输入、调用远程 API 或做大量计算，会将锁持有时间拉长。

## 19. 行锁等待与锁超时

事务 A 更新一行但未提交，事务 B 尝试修改同一行：

```text
A：UPDATE row 42 ── 持有锁 ── ... ── COMMIT
B：UPDATE row 42 ───── 等待 ────────── 继续
```

这是正常串行化冲突写入的一种方式。但如果 A 长时间不结束，B 的请求线程和数据库连接会一直被占用，最后可以拖垮连接池。

应用需要合理的 statement timeout、lock timeout 和事务超时，但超时只能终止等待，不会解释谁长时间持有锁。诊断时要查阻塞关系、活动事务、SQL 和应用调用链。

## 20. 死锁是事务形成了循环等待

```text
事务 A 持有 row 1，等待 row 2
事务 B 持有 row 2，等待 row 1
```

两者都无法继续。PostgreSQL 会检测死锁，中止其中一个事务，让另一个能继续。

常见预防方法：

- 多个事务按一致顺序访问同类资源；
- 缩短事务，不在锁内做外部网络调用；
- 一次明确选中需要锁定的资源，不在未知顺序里逐个追加；
- 为可恢复错误实现有界、带退避的整事务重试。

死锁不代表数据库损坏，但如果应用把被中止的事务当成普通成功，或重试时重复发送外部效果，会产生业务问题。

## 21. 重试必须以整个事务为边界

当发生 serialization failure 或 deadlock victim 时，当前事务的中间读取和决策已不再可靠。不能只重试最后一条 `UPDATE`：

```text
错误：复用旧读取结果 → 只重试最后 SQL

正确方向：开始新事务
          → 重新读取当前状态
          → 重新执行业务决策和全部写入
```

事务重试还要考虑幂等性。如果事务里已经向外部支付或短信服务发送请求，数据库回滚无法撤回这些外部效果。外部副作用需要幂等键、Outbox 或提交后处理等设计。

## 22. Savepoint 是事务内的回滚位置

```sql
BEGIN;

INSERT INTO work_order ...;
SAVEPOINT after_order;

INSERT INTO optional_note ...;
-- 如果这步失败：
ROLLBACK TO SAVEPOINT after_order;

COMMIT;
```

Savepoint 可以撤销事务中的一部分工作，但整个事务仍是一个最终提交单位。

不要用 savepoint 把本应整体成功的业务规则拆成“有一半成功也算了”。只有那部分本来就允许失败而不破坏整体不变条件时，局部回滚才合理。

## 23. 长事务的成本远不只是占用一个连接

长事务可能：

- 长时间持有行锁或表锁；
- 保持旧快照，让 VACUUM 不能清理旧版本；
- 占用连接池中的连接；
- 增加冲突、死锁和重试概率；
- 在失败时撤销大量工作；
- 让部署、DDL 和运维操作等待。

事务内应只保留必须共同提交的数据库操作和必需计算。不要在事务中等用户点击，也尽量不在其中做无超时的远程调用。

## 24. 诊断并发问题要看“谁等谁”

当请求卡住时，只看当前 SQL 可能发现它本身很简单。真正问题可能是它在等另一个事务释放锁。

诊断需要关联：

```text
受阻 session
  → 当前 SQL / 等待事件 / 等待时间
  → 阻塞它的 session
  → 阻塞者事务开始时间和 SQL
  → 对应的应用请求、trace 和代码边界
```

PostgreSQL 的活动会话和锁视图可以提供数据库侧证据。操作系统级的 CPU/I/O、连接池指标和应用 trace 帮助说明这是慢查询、锁等待，还是连接根本拿不到。

## 25. 两条主线的整体地图

```text
查询性能：
真实查询 + 真实数据分布
  → EXPLAIN ANALYZE + BUFFERS
  → 理解扫描、连接、预计与实际行
  → 设计候选索引或改写查询
  → 前后对比读、耗时、存储和写入成本

并发正确性：
业务不变条件
  → 划定短事务
  → 选择原子 SQL / 乐观版本 / 悲观锁 / 隔离级别
  → 显式处理冲突、超时、死锁和整事务重试
```

最重要的边界：索引是查询和数据分布的设计，不是“列的装饰”；`EXPLAIN ANALYZE` 会真正执行语句；MVCC 不消灭锁；事务失败后要在新事务中重新做决策，外部副作用则需要另外的幂等和一致性设计。
