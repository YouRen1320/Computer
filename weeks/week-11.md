# 第 11 周：索引、EXPLAIN、事务隔离与锁

## 定位

本周从“SQL 能返回结果”升级为“知道它为什么快或慢、并发时是否正确”。重点是用 PostgreSQL 18 的执行计划和双会话实验建立证据，不靠索引口诀或背隔离级别定义。

时间预算：15—18 小时。所有优化先定义查询与数据规模，再测量；所有并发规则先保证正确，再讨论吞吐。

## 前置

- FactoryCare schema、约束、种子数据和业务查询通过验收。
- 能用 `psql` 开两个独立会话并明确当前事务状态。
- 理解主键/唯一约束通常会建立索引，但外键列不会自动都获得合适查询索引。
- 测试数据可重复生成，不使用真实生产数据。

## 目标

- 理解索引加速读取但增加写入、空间和维护成本。
- 根据查询谓词、排序和数据分布设计复合/部分/表达式/覆盖索引。
- 阅读 `EXPLAIN (ANALYZE, BUFFERS)` 的关键节点与估算偏差。
- 理解 ACID、MVCC、事务边界和 PostgreSQL 隔离级别的实际行为。
- 使用行锁和一致锁顺序处理竞争，识别阻塞与死锁。
- 比较乐观版本控制和悲观锁的适用场景。
- 为 FactoryCare 形成查询优化证据和工单抢单并发方案。

## 完整概念清单

### 索引基础

- 索引是辅助数据结构，不是“越多越好”。
- B-tree 默认适合等值、范围和排序；Hash、GIN、GiST、SP-GiST、BRIN 只了解主要场景。
- 主键、唯一约束与唯一索引的关系。
- 单列、复合、多列顺序和查询前缀的实际影响。
- selectivity、cardinality、数据倾斜和小表顺序扫描。
- 部分索引只覆盖满足 predicate 的行，查询条件需可匹配。
- 表达式索引用于稳定表达式，例如规范化查询；会增加维护成本。
- `INCLUDE` 覆盖列与 index-only scan 的条件。
- 排序、LIMIT 与索引方向；稳定排序仍需唯一键。
- 外键列是否需要索引由删除/更新和查询模式决定。
- 重复/冗余索引增加写放大和维护成本。

### 统计与维护

- planner 使用统计信息估算行数和成本。
- `ANALYZE` 更新统计；autovacuum 同时承担 vacuum/analyze 相关工作。
- MVCC dead tuples、VACUUM 高层作用；不是每慢一次都手工 FULL。
- 统计估算偏差可能导致错误 plan，先检查数据分布与统计。

### EXPLAIN

- `EXPLAIN` 只估算；`EXPLAIN ANALYZE` 会实际执行。
- 对 UPDATE/DELETE 的 ANALYZE 必须在可回滚环境中谨慎使用。
- cost、estimated rows、actual time、actual rows、loops。
- Seq Scan、Index Scan、Index Only Scan、Bitmap Scan。
- Nested Loop、Hash Join、Merge Join 的适用直觉。
- Sort、Aggregate、HashAggregate、Limit。
- `BUFFERS` 帮助区分缓存页访问，不等于直接磁盘耗时。
- 估算与实际行数差距、过滤掉的行和重复 loops。
- 本机小数据快不代表生产大数据快，使用可控规模生成器。

### 事务与 ACID

- 原子性、一致性、隔离性、持久性分别解决什么问题。
- autocommit、`BEGIN/COMMIT/ROLLBACK`、savepoint。
- 事务边界应围绕一个业务不变量，不围绕每条 SQL。
- 长事务持锁、保留旧版本并增加故障恢复成本。
- 外部 HTTP/邮件调用通常不应长期占着数据库事务。

### MVCC 与隔离级别

- PostgreSQL 使用 MVCC 让读写在很多场景下少互相阻塞。
- snapshot 是事务/语句看到的数据版本视图，不是复制整张表。
- Read Uncommitted 在 PostgreSQL 中按 Read Committed 行为处理。
- Read Committed 是默认级别，每条语句获得新的 snapshot。
- Repeatable Read 在 PostgreSQL 中提供稳定事务 snapshot，但仍需理解 serialization anomaly 风险。
- Serializable 使用可序列化隔离并可能主动回滚事务；应用必须能安全重试。
- 脏读、不可重复读、幻读、更新丢失和写偏差用实验理解，不死背跨数据库统一结论。

### 锁与竞争

- 表级锁和行级锁的高层用途与冲突。
- `SELECT ... FOR UPDATE/NO KEY UPDATE/SHARE/KEY SHARE` 的边界。
- `NOWAIT` 立即失败、`SKIP LOCKED` 适合队列式抢占但会跳过数据。
- 锁等待、lock timeout、statement timeout。
- 死锁形成条件、PostgreSQL 检测和回滚其中一个事务。
- 一致加锁顺序和短事务减少死锁。
- advisory lock 了解存在，不作为工单锁的默认选择。

### 乐观与悲观并发控制

- 乐观锁使用 version/条件更新，冲突时返回 0 行并由应用重试或提示。
- 悲观锁先取得数据库行锁，适合冲突概率高、临界区短的操作。
- 原子条件 UPDATE 常比“先查再改”更安全简单。
- 无论何种锁，业务幂等和事务边界仍需设计。
- 不将 JVM `synchronized` 当作多实例数据库并发控制。

## 任务分配

| 模块 | 时间 | 任务 |
| --- | ---: | --- |
| 索引设计 | 3h | B-tree、复合、部分、表达式、INCLUDE 和成本实验 |
| EXPLAIN | 3h | 生成规模数据、读取节点、估算/实际和 BUFFERS |
| 事务/MVCC | 2.5h | ACID、快照和隔离级别双会话实验 |
| 锁与死锁 | 2.5h | 行锁、NOWAIT、SKIP LOCKED、超时和死锁恢复 |
| FactoryCare | 3—4h | 查询优化报告与工单抢单方案 |
| 无 AI 训练 | 2h | 慢查询/阻塞定位 |
| 求职动作 | 1h | SQL 性能和事务口述 |

## FactoryCare项目增量

### 查询优化

选择至少三条真实查询：

- 组织内按状态和创建时间分页工单。
- 设备的未关闭工单查询。
- 超期候选或最近重复故障统计。

为每条记录：业务目标、测试数据规模、原始 SQL、原始计划、候选索引、优化后计划、写入/空间代价和是否保留索引。不能只贴“用了 Index Scan”的截图。

### 并发实验

设计“维修人员领取待处理工单”：

- 双会话模拟同时领取同一工单。
- 比较先查后改、条件 UPDATE、`FOR UPDATE` 和 version 乐观更新。
- 明确冲突返回、重试、超时和用户提示。
- 制造两个工单反向加锁死锁，观察数据库错误并采用稳定顺序修复。

本周先用 SQL 证明方案，第 12 周再通过 MyBatis/Spring 事务实现。

## AI协作边界

可以让 AI：

- 解释计划节点和提出索引候选。
- 生成具有倾斜、低选择性和重复值的测试数据方案。
- 帮助枚举并发现象，但必须用双会话复现。
- 审查事务是否包含不必要外部调用和过宽锁范围。

必须由你完成：

- 提供真实 SQL、表结构、行数、计划和统计信息，不能只说“查询慢”。
- 用前后计划与数据证明索引是否有效。
- 独立执行两会话隔离、阻塞和死锁实验。
- 决定冲突是重试、失败还是跳过，并解释业务后果。

## 无AI训练

本周从求职/复盘时段预留45—60分钟完成并记录：区间合并/冲突题；说明排序依据和边界相交语义。

关闭 AI，限时 120 分钟：

1. 获取一条分页查询的 EXPLAIN ANALYZE BUFFERS。
2. 判断瓶颈假设，创建一个候选复合或部分索引，再次测量。
3. 在两个 psql 会话复现一次阻塞，使用系统视图/日志找到阻塞方。
4. 实现版本号条件更新并验证只有一个领取者成功。
5. 口述 Read Committed 与 Repeatable Read 在 PostgreSQL 中的可见性差异。

## 求职动作

- 准备索引原理、复合索引、最左/查询前缀、EXPLAIN、ACID、MVCC、隔离级别、行锁、死锁、乐观锁的回答。
- 避免把 MySQL 口诀原封不动套 PostgreSQL；明确当前回答的数据库。
- 将一份优化前后证据整理为 3 分钟项目故事：问题、假设、验证、取舍。
- 定向投递至少 6 个岗位，记录 SQL/事务面试反馈。

## 交付物

- 三条以上查询的 EXPLAIN 优化报告。
- 索引清单：服务的查询、维护成本、保留/删除理由。
- 隔离级别、阻塞、死锁和领取竞争 SQL 实验。
- 乐观/悲观方案对比与业务冲突策略。
- 无 AI 慢查询和锁排查记录。

## 验收标准

- 能根据查询和数据分布设计索引，不用“有 WHERE 就建索引”判断。
- 能读取主要扫描、连接、排序、聚合节点和估算/实际差异。
- 至少一个优化有前后计划证据，同时说明写入/空间代价。
- 能解释 PostgreSQL 四种隔离名称的实际支持差异和 Serializable 重试需要。
- 能复现并定位阻塞/死锁，说明锁顺序和短事务的修复。
- 同一工单并发领取最多一个成功，冲突结果明确。
- 无 AI 完成一次查询和一次锁问题排查。

## 明确不做

- 不深入 PostgreSQL planner、B-tree page、WAL、buffer manager 或 MVCC 源码。
- 不做分区、分库分表、读写分离、复制、连接池调优或 DBA 级参数调优。
- 不为所有外键/字段机械加索引，不保留未服务查询的实验索引。
- 不用禁用 Seq Scan 强迫索引，也不根据毫秒级小样本下结论。
- 不在本周接 MyBatis 或 Spring `@Transactional`。

## 官方资料

- [PostgreSQL 18 Indexes](https://www.postgresql.org/docs/18/indexes.html)
- [Using EXPLAIN](https://www.postgresql.org/docs/18/using-explain.html)
- [Planner Statistics](https://www.postgresql.org/docs/18/planner-stats.html)
- [Transaction Isolation](https://www.postgresql.org/docs/18/transaction-iso.html)
- [Explicit Locking](https://www.postgresql.org/docs/18/explicit-locking.html)
- [Concurrency Control](https://www.postgresql.org/docs/18/mvcc.html)
- [Monitoring Database Activity](https://www.postgresql.org/docs/18/monitoring-stats.html)
