---
schema_version: 2
edition: 2026.2-draft
id: ch.data.transactions-locking
title: ACID、隔离级别、锁、死锁与重试边界
responsibility: 教授多语句原子性和并发异常边界，不提前绑定 Spring 代理或消息一致性实现
volume: '04'
order: 14
level: L2
status: drafting
path: book/volume-04-data-postgresql/chapters/ch.data.transactions-locking.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.data.dml
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
  text: 在 120 秒内解释ACID、隔离级别、锁、死锁与重试边界的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - data-transaction-isolation
  - data-lock-deadlock
  covers_topics:
  - data.acid
  - data.isolation-anomaly
  - data.commit-rollback
  - data.row-table-lock
  - data.deadlock
  - data.retry-boundary
  uses_capabilities:
  - data.sql-query
  - data.relational-schema
  - data.transactions-locks
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：用两个 psql 会话复现提交/回滚、不可重复读或锁等待，并记录隔离级别、锁顺序和重试边界，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - data-transaction-isolation
  - data-lock-deadlock
  covers_topics:
  - data.acid
  - data.isolation-anomaly
  - data.commit-rollback
  - data.row-table-lock
  - data.deadlock
  - data.retry-boundary
  uses_capabilities:
  - data.sql-query
  - data.relational-schema
  - data.transactions-locks
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入相反锁顺序制造死锁和读后写丢更新，依据 PostgreSQL 错误/锁视图修正事务协议
  covers_topic_groups:
  - data-transaction-isolation
  - data-lock-deadlock
  covers_topics:
  - data.acid
  - data.isolation-anomaly
  - data.commit-rollback
  - data.row-table-lock
  - data.deadlock
  - data.retry-boundary
  uses_capabilities:
  - data.sql-query
  - data.relational-schema
  - data.transactions-locks
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# ACID、隔离级别、锁、死锁与重试边界

> 本章状态为 `drafting`。事务、锁顺序和整事务重试是稳定核心；PostgreSQL **18** 的隔离、行锁、死锁与 SQLSTATE 于 **2026-07-17** 按官方文档核对。本机没有 PostgreSQL server/`psql`，资产使用确定性调度模型验证状态、回滚、等待图和去重边界。离线 PASS 不证明真实 MVCC、锁等待或死锁检测已经发生。

## 1. 事务是在声明“一组操作只能整体成立”

FactoryCare 把工单 `W-42` 从 `OPEN` 指派给技师 `T-07` 时，至少有两个数据库事实：

1. 工单的状态和负责人改变；
2. 一条不可缺失的状态历史被记录。

若第一条成功、第二条失败，当前状态与历史不一致；若第二条成功、第一条失败，历史声称发生了实际未发生的指派。事务把它们放进一个原子边界：

```sql
BEGIN;

UPDATE factorycare.work_order
SET status = 'IN_PROGRESS',
    assigned_to = 7,
    version = version + 1
WHERE work_order_id = 42
  AND status = 'OPEN';

INSERT INTO factorycare.work_order_history (
  command_id, work_order_id, from_status, to_status, assigned_to
) VALUES (
  '01947b2a-7b20-7cc3-98f2-9f4d4a71e801',
  42, 'OPEN', 'IN_PROGRESS', 7
);

COMMIT;
```

只有“包在 BEGIN/COMMIT 中”还不够。还必须验证 UPDATE 恰好影响一行、约束成立、并发协议明确、失败后 ROLLBACK、可重试错误从事务开头重做，并避免重复副作用。

### 完成标准

学习者应能：

- 用业务事实解释 ACID，而不是只背四个英文单词；
- 证明两个语句一起提交或一起回滚；
- 区分 PostgreSQL autocommit 与显式事务块；
- 解释 Read Committed 的语句快照和不可重复读；
- 解释 PostgreSQL Repeatable Read 的稳定快照、无幻读与仍可能的序列化异常；
- 说明 Serializable 为什么仍要求处理 `40001`；
- 区分普通读、行级锁、表级锁与锁等待；
- 用两会话顺序稳定复现等待和死锁；
- 从 `pg_stat_activity`、`pg_locks`、blocking PID 与 SQLSTATE 形成证据链；
- 修复读后写丢更新；
- 对 `40001` 和 `40P01` 回滚并重试整个事务；
- 证明重试后数据库副作用只有一份。

本章不绑定 Spring `@Transactional`、代理、自调用、分布式事务、消息投递一致性或具体连接池 API；这些要在后续章节建立在本章边界之上。

## 2. 固定 FactoryCare 表与不变量

```sql
CREATE TABLE factorycare.work_order (
  work_order_id bigint PRIMARY KEY,
  status text NOT NULL CHECK (
    status IN ('OPEN', 'IN_PROGRESS', 'DONE', 'CANCELLED')
  ),
  assigned_to bigint,
  version bigint NOT NULL DEFAULT 0,
  CHECK (
    (status = 'OPEN' AND assigned_to IS NULL)
    OR (status <> 'OPEN' AND assigned_to IS NOT NULL)
  )
);

CREATE TABLE factorycare.work_order_history (
  history_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  command_id uuid NOT NULL UNIQUE,
  work_order_id bigint NOT NULL
    REFERENCES factorycare.work_order (work_order_id),
  from_status text NOT NULL,
  to_status text NOT NULL,
  assigned_to bigint NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (from_status <> to_status)
);
```

固定初始状态：

```sql
INSERT INTO factorycare.work_order (
  work_order_id, status, assigned_to, version
) VALUES
  (42, 'OPEN', NULL, 0),
  (43, 'OPEN', NULL, 0);
```

本章只把 history 当数据库内审计事实，不讨论向外部消息系统发布。`command_id UNIQUE` 用于证明同一业务命令不会产生两份历史，但它不能自动让邮件、HTTP 调用或 MQ 发送回滚。

## 3. BEGIN、COMMIT、ROLLBACK 与 autocommit

在 PostgreSQL 中，没有显式 `BEGIN` 的普通命令通常表现为每条语句各自一个事务，即常说的 autocommit。于是下面不是一个原子单元：

```sql
UPDATE ...;  -- 成功后已经提交
INSERT ...;  -- 失败不能撤销上一条已提交 UPDATE
```

显式事务块：

```sql
BEGIN;
-- 多条语句
COMMIT;      -- 使整个事务结果可见并持久化
```

主动放弃：

```sql
BEGIN;
-- 多条语句
ROLLBACK;    -- 撤销当前事务内的数据库修改
```

发生错误后，事务通常进入 aborted 状态。不能抓住错误后在同一个事务里继续剩余业务语句并提交；先回滚事务，修正或按策略从头重试。

### 3.1 可证明的回滚故障

给 history 注入相同 `command_id`，触发唯一约束失败：

```sql
BEGIN;

UPDATE factorycare.work_order
SET status = 'IN_PROGRESS', assigned_to = 7, version = version + 1
WHERE work_order_id = 42 AND status = 'OPEN';

INSERT INTO factorycare.work_order_history (...)
VALUES ('已存在的-command-id', ...); -- unique_violation

ROLLBACK;
```

验证不能只看报错。回滚后必须断言：

```text
work_order(42) = OPEN, assigned_to NULL, version 0
该 command_id 的历史总数没有增加
```

### 3.2 SAVEPOINT 的边界

`SAVEPOINT` 可回滚事务中的局部工作，但不能把原本必须共同成立的业务事实拆成可接受的半成功。若工单更新与 history 都是命令不变量，history 失败后只回滚 INSERT、保留 UPDATE 是错误设计。

## 4. 用业务事实解释 ACID

### 4.1 Atomicity：原子性

一个事务的数据库修改整体提交或整体回滚。它不是“每条语句不被打断”，也不覆盖事务外的 HTTP 请求、文件写入或邮件。

FactoryCare 例：工单指派与 history 两者都存在，或两者都不存在。

### 4.2 Consistency：一致性

事务把数据库从一个满足已声明不变量的状态带到另一个满足不变量的状态。约束能执行一部分规则：主外键、唯一、非空、检查。数据库不知道全部业务语义；应用仍需检查 UPDATE 行数、状态迁移和授权。

“C”不是“副本最终一致”，也不是数据库自动理解业务。

### 4.3 Isolation：隔离性

并发事务的中间状态不能任意相互干扰；具体保证由隔离级别、语句形状和显式锁协议共同决定。隔离不是“所有事务串行运行”，也不是“选择最高级别就无需处理失败”。

### 4.4 Durability：持久性

成功 COMMIT 后，数据库承诺结果在其持久化配置与故障模型下保存。应用不能把“客户端没收到响应”简单等同于未提交；连接断开时可能出现事务结果未知，需用业务命令标识查询或对账。

### 4.5 序列号反例

PostgreSQL 官方文档特别提示：sequence 的变化会立即对其他事务可见，事务回滚也不会把序列计数倒回。这不破坏表行的事务原子性，但说明“回滚后所有观察值都恢复原样”是错误理解。主键出现间隙不是事务失败证据。

## 5. MVCC 与“我看见哪一版”

PostgreSQL 使用多版本并发控制。粗略模型是：更新通常产生新行版本，事务按快照规则决定可见版本；读者和写者不必总是互相阻塞。

这不表示“没有锁”。UPDATE 仍会取得行级锁，DDL/DML 会取得表级锁，事务还可能等待另一个事务 ID。MVCC 解决可见性，锁解决冲突访问，两者一起构成并发行为。

不要用墙上时间描述快照：“我在 10:01 开始事务，所以永远看 10:01”。准确边界取决于隔离级别和第一条相关语句。

## 6. PostgreSQL 18 的隔离级别

| 请求级别 | PostgreSQL 行为摘要 | 仍需处理 |
| --- | --- | --- |
| READ UNCOMMITTED | 实际按 Read Committed 处理 | 不可重复读、幻读、序列化异常 |
| READ COMMITTED | 默认；每条语句开始取得新快照 | 同一事务两次 SELECT 可不同 |
| REPEATABLE READ | 第一个非事务控制语句建立稳定快照 | 序列化异常、更新冲突重试 |
| SERIALIZABLE | 检测会破坏串行等价的读写依赖 | `40001`，整事务重试 |

### 6.1 Read Committed：语句级快照

会话 A：

```sql
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT status FROM factorycare.work_order WHERE work_order_id = 42;
-- OPEN
```

会话 B：

```sql
BEGIN;
UPDATE factorycare.work_order
SET status = 'IN_PROGRESS', assigned_to = 7
WHERE work_order_id = 42;
COMMIT;
```

会话 A 再读：

```sql
SELECT status FROM factorycare.work_order WHERE work_order_id = 42;
-- IN_PROGRESS
COMMIT;
```

这是不可重复读，不是脏读。A 第一次没看见 B 未提交的数据；第二次看见了 B 已提交的数据，因为第二条 SELECT 取得新快照。

### 6.2 Repeatable Read：稳定快照但不是所有规则自动安全

在 PostgreSQL 的 Repeatable Read 中，同一事务后续查询不看见并发事务在其快照后提交的变化；PostgreSQL 实现还不允许 SQL 标准表中该级别可容许的幻读。这是 PostgreSQL 具体语义，不能不加说明地推广到所有数据库。

但它仍可能出现无法等价到某个串行顺序的异常，更新过时版本时也可能被迫中止。因此业务规则若依赖“先读多个行，再根据总和写另一行”，要用 Serializable 或正确显式锁协议，并处理失败。

### 6.3 Serializable：成功事务等价串行，不等于永不失败

Serializable 监测读写依赖。如果一组并发事务不能安全对应某种逐个执行顺序，PostgreSQL 会中止其中一个并返回 `serialization_failure`，SQLSTATE `40001`。

正确应用合同是：

```text
成功 COMMIT 的结果满足串行语义
+
应用准备好回滚并重试 40001
```

把 `40001` 当普通 500 错误丢给用户，会丢失 Serializable 的可用性边界。

## 7. 丢失更新：读后写的经典陷阱

假设 A、B 都读取 `version=0` 和 `priority=2`，各自在内存把 priority 加一，然后依次写回 3：

```text
A reads 2
B reads 2
A writes 3
B writes 3
最终 3，而期望 4
```

### 7.1 修复一：单条原子 UPDATE

```sql
UPDATE factorycare.work_order
SET priority = priority + 1,
    version = version + 1
WHERE work_order_id = 42
RETURNING priority, version;
```

数据库基于当前行版本执行，避免把旧内存值直接覆盖。适合能表达为单条相对更新的规则。

### 7.2 修复二：乐观版本检查

```sql
UPDATE factorycare.work_order
SET priority = 3,
    version = version + 1
WHERE work_order_id = 42
  AND version = 0
RETURNING version;
```

第二个竞争者影响 0 行。0 行不是“成功但没变化”，而是并发冲突证据；应用要重新读取、合并或拒绝。

### 7.3 修复三：悲观行锁

```sql
BEGIN;

SELECT status, assigned_to, version
FROM factorycare.work_order
WHERE work_order_id = 42
FOR UPDATE;

-- 根据锁住的当前行验证并更新
UPDATE ...;
INSERT INTO work_order_history ...;

COMMIT;
```

`FOR UPDATE` 锁住所取行，其他试图更新、删除或取得冲突行锁的事务等待到本事务结束。普通 MVCC SELECT 通常仍能读到其快照可见版本。行锁必须尽量晚取得、尽快提交，不能在持锁时等待人工输入或远程接口。

## 8. 行锁与表锁不要混为一谈

### 8.1 表级锁

普通 `SELECT` 取得 `ACCESS SHARE`；`INSERT/UPDATE/DELETE` 通常取得 `ROW EXCLUSIVE`；许多 DDL 需要更强锁，`ACCESS EXCLUSIVE` 与所有表锁模式冲突。名字中的 ROW 不表示它是行锁，`ROW EXCLUSIVE` 仍是表级锁模式。

所有表级锁通常持有到事务结束。长事务会把看似短小的 DDL 或维护操作拖成等待链。

### 8.2 行级锁

PostgreSQL 提供 `FOR UPDATE`、`FOR NO KEY UPDATE`、`FOR SHARE`、`FOR KEY SHARE`。它们冲突矩阵不同：

- `FOR UPDATE` 最强，阻止其他事务更新、删除或取得冲突行锁；
- `FOR NO KEY UPDATE` 较弱，普通不改键 UPDATE 常取得它；
- `FOR SHARE` 允许共享读取锁，但阻止更新/删除；
- `FOR KEY SHARE` 重点保护键不被删除或改动。

不要为“保险”全部使用 `FOR UPDATE`。选最弱但足够表达不变量的模式，有助于并发。

### 8.3 等待不是死锁

A 锁住 W-42，B 更新 W-42，B 等待；A 提交后 B 继续，这是正常锁等待。只有等待关系形成环，所有参与者都无法自行前进，才是死锁。

## 9. 用两个会话受控复现锁等待

会话 A：

```sql
BEGIN;
SELECT work_order_id
FROM factorycare.work_order
WHERE work_order_id = 42
FOR UPDATE;
-- 暂不提交
```

会话 B：

```sql
BEGIN;
UPDATE factorycare.work_order
SET version = version + 1
WHERE work_order_id = 42;
-- 此处等待
```

第三个观察会话使用系统视图，不要只凭“终端没返回”判断：

```sql
SELECT a.pid,
       a.state,
       a.wait_event_type,
       a.wait_event,
       pg_blocking_pids(a.pid) AS blocking_pids,
       a.query
FROM pg_stat_activity AS a
WHERE a.datname = current_database()
  AND a.pid <> pg_backend_pid();
```

进一步看 `pg_locks`：

```sql
SELECT pid, locktype, relation::regclass, mode, granted, waitstart
FROM pg_locks
WHERE database = (SELECT oid FROM pg_database WHERE datname = current_database())
ORDER BY granted, pid, locktype;
```

`granted=false` 表示正在等待，但行级冲突常还表现为等待另一个 transactionid，不能只筛 `locktype='tuple'` 后宣称没有锁。

结束实验：A `COMMIT`，B 得到锁并完成，然后 B `ROLLBACK`，恢复夹具。保存会话顺序、PID、阻塞 PID、等待事件和最终状态。

## 10. 受控死锁：相反锁顺序形成环

初始有 W-42、W-43。

会话 A：

```sql
BEGIN;
UPDATE factorycare.work_order SET version = version + 1
WHERE work_order_id = 42;
```

会话 B：

```sql
BEGIN;
UPDATE factorycare.work_order SET version = version + 1
WHERE work_order_id = 43;
```

A 再请求 W-43，会等待 B；B 再请求 W-42，形成环：

```text
A holds W-42 → waits W-43
B holds W-43 → waits W-42
```

PostgreSQL 检测后中止一个事务，错误 `deadlock_detected`，SQLSTATE `40P01`。另一方可以继续，但被中止方在错误前做过的本事务修改都会回滚。

### 10.1 首选预防：全局一致锁顺序

需要锁多张工单时，双方都按 `work_order_id` 升序：

```sql
SELECT work_order_id
FROM factorycare.work_order
WHERE work_order_id IN (42, 43)
ORDER BY work_order_id
FOR UPDATE;
```

一致顺序显著减少死锁，但复杂系统仍应处理 `40P01`。外键、触发器或其他表访问也可能引入未显式看到的锁。

## 11. 重试边界：失败语句不是可独立续跑的检查点

对 `40001 serialization_failure` 与 `40P01 deadlock_detected`，安全默认是：

1. 捕获 SQLSTATE，不匹配本地化文本；
2. ROLLBACK 当前事务；
3. 丢弃旧快照、旧实体和旧计算；
4. 从 BEGIN 前重新读取并重跑完整业务函数；
5. 使用有上限的重试次数与退避/抖动；
6. 超限后返回可诊断失败，保留 SQLSTATE、attempt、command_id；
7. 验证最终数据库副作用只出现一次。

错误做法：

```text
事务中第 3 条 UPDATE 收到 40P01
→ 只重新执行第 3 条
→ 接着 COMMIT
```

该事务已失败，前序读也可能过时。重试整个事务才能重新建立一致输入。

### 11.1 哪些错误不能盲目重试

- `23505 unique_violation` 可能表示重复命令，也可能是真正业务冲突；先按约束语义判断。
- 语法错误、权限错误、CHECK 失败不会因随机等待自动消失。
- 连接中断可能使提交结果未知；不能直接再做一次非幂等命令。
- `lock_timeout`/statement timeout 反映等待预算，但不等于死锁；重试策略要独立定义。

### 11.2 重试与外部副作用

数据库事务无法回滚已经发送的邮件、HTTP 请求或文件写入。若把外部调用放在可能重试的闭包中，第一次调用成功而数据库事务回滚，第二次会再次调用。

本章只规定边界：可重试事务函数内部只做可回滚数据库操作，或使用可证明的幂等命令标识；跨消息一致性的具体实现留给后续章节。

## 12. 用 command_id 证明“最终一次”

固定命令 `C-100`/UUID。第一次尝试被死锁选为牺牲者，整个事务回滚，因此没有 history。第二次从头执行：

```sql
INSERT INTO factorycare.work_order_history(command_id, ...)
VALUES (:command_id, ...);
```

唯一约束保证数据库中最多一条同 command_id 历史。验收：

```text
work_order.version 只增加一次
最终状态与负责人正确
history where command_id = C-100 的 count = 1
attempts = 2 可记录，但不是两份业务副作用
```

如果第一次 COMMIT 成功但客户端没收到响应，第二次 INSERT 触发唯一约束。应用应按 command_id 查询已完成结果，而不是把它当未知错误反复写。

## 13. 故障诊断矩阵

| 现象 | 第一证据 | 常见误诊 | 正确方向 |
| --- | --- | --- | --- |
| 同事务两次读不同 | 隔离级别、两次语句快照 | “读到了脏数据” | 识别 Read Committed 不可重复读 |
| UPDATE 长时间无返回 | wait_event、blocking PID、pg_locks | “数据库死了” | 找持锁事务与其边界 |
| 40P01 | SQLSTATE、两会话锁顺序 | 只重跑失败 UPDATE | 回滚，统一顺序，整事务重试 |
| 40001 | SQLSTATE、隔离级别、尝试号 | 降级隔离以消除错误 | 保持规则，整事务重试 |
| 最终值少加一次 | 两个读取值、UPDATE 行数/version | “事务已经保证不会丢” | 原子 UPDATE、版本检查或行锁 |
| 重试产生两条 history | command_id 计数 | 只减少重试次数 | 唯一命令标识与完整边界 |
| 回滚后 identity 有间隙 | 行状态与 sequence 分开观察 | “ROLLBACK 失效” | 接受 sequence 非事务回退 |

## 14. 一套可重放的两会话报告

实验报告必须把操作顺序写成时间线，不能只贴最终截图：

```text
server-version:
schema-reset-command:
initial-state:
session-a-isolation:
session-b-isolation:
step-01 A SQL/result:
step-02 B SQL/result:
step-03 observer blocking evidence:
injected-error SQLSTATE:
rollback evidence:
retry attempt:
final work_order state:
final history count by command_id:
```

为了可重复：

- 每轮先重置 W-42/W-43；
- 明确哪个会话先执行到哪一行；
- 不依赖人工“差不多同时按回车”；
- 设置合理的会话级等待预算，结束后恢复；
- 记录 SQLSTATE 而非只截错误文本；
- 失败后显式 ROLLBACK；
- 最后断言状态和副作用数量。

## 15. 三类关键反例

### 反例 A：多语句无显式事务

UPDATE autocommit 成功，history INSERT 失败。最终状态改变但没有历史。修复是同一数据库事务、检查 UPDATE 行数、失败整体回滚。

### 反例 B：读后写丢更新

两个会话读取同一旧值，各自覆盖写回。修复优先选择单条相对 UPDATE；若业务必须先读，使用 version 条件或 `FOR UPDATE`，并验证冲突分支。

### 反例 C：相反锁顺序与错误重试

A 先 W-42 后 W-43，B 先 W-43 后 W-42，出现 `40P01`。若只重跑最后一条或在事务闭包中重复外部调用，会产生不一致。修复是统一锁顺序、回滚并整事务重试、限制尝试次数、用 command_id 证明一次副作用。

## 16. 配套资产与独立构建

本章提供：

- `examples/encyclopedia/ch.data.transactions-locking/`：提交与回滚的确定性状态模型；
- `labs/encyclopedia/ch.data.transactions-locking/`：两会话不可重复读、等待、死锁与重试时间线；
- `exercises/encyclopedia/ch.data.transactions-locking/`：故意只重跑失败语句且锁顺序相反的红灯 starter；
- `solutions-private/encyclopedia/ch.data.transactions-locking/`：统一顺序、整事务重试、单一副作用的私有解。

离线 oracle 能证明模型中的原子状态、等待图环、回滚和 command_id 去重；不能证明 PostgreSQL 18 真实锁管理器执行。真实实验仍需两路 psql 与观察会话。

独立构建必须留下三组断言：

1. 成功：工单与 history 一起提交；
2. 失败：注入 INSERT 失败后两者一起回滚；
3. 并发：死锁一方失败，统一顺序整事务重试后，最终状态正确且副作用一份。

## 17. 120 秒讲回检查

不看笔记回答：

1. ACID 四项分别约束什么，哪些不覆盖外部 HTTP？
2. Read Committed 为什么能在同一事务两次读到不同提交值？
3. PostgreSQL Repeatable Read 与 Serializable 的剩余失败边界是什么？
4. 锁等待与死锁怎样从等待图区分？
5. 为什么死锁后必须重试整个事务？
6. 丢失更新有哪三类修复，各自适合什么形状？
7. 怎样证明两次 attempt 只有一次业务副作用？

能说出责任、边界、SQLSTATE、第一诊断证据与一个失败反例，才达到 explain outcome。

## 18. 官方与主来源

- [PostgreSQL 18 Transaction Isolation](https://www.postgresql.org/docs/18/transaction-iso.html)：隔离级别、异常与整事务重试边界；
- [PostgreSQL 18 SET TRANSACTION](https://www.postgresql.org/docs/18/sql-set-transaction.html)：Read Committed、Repeatable Read、Serializable 与事务属性；
- [PostgreSQL 18 Explicit Locking](https://www.postgresql.org/docs/18/explicit-locking.html)：表锁、行锁、死锁与统一锁顺序；
- [PostgreSQL 18 Viewing Locks](https://www.postgresql.org/docs/18/monitoring-locks.html) 与 [`pg_locks`](https://www.postgresql.org/docs/18/view-pg-locks.html)：锁观察证据；
- [PostgreSQL 18 Error Codes](https://www.postgresql.org/docs/18/errcodes-appendix.html)：`40001` 与 `40P01`；
- [PostgreSQL 18 ROLLBACK](https://www.postgresql.org/docs/18/sql-rollback.html)：事务回滚命令。

稳定核心是原子边界、快照推理、统一锁顺序、SQLSTATE 分类和整事务重试；版本相关面是 PostgreSQL 18 的具体隔离保证、行锁冲突、系统视图与错误码。真实 PostgreSQL 18 会话实验仍未验证。
