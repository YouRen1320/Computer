---
schema_version: 2
edition: 2026.2-draft
id: ch.data.dml
title: INSERT、UPDATE、DELETE、UPSERT 与 RETURNING
responsibility: 教授可审计的数据写入和影响行数，不在本章处理跨语句事务并发或 schema 变更
volume: '04'
order: 9
level: L1
status: drafting
path: book/volume-04-data-postgresql/chapters/ch.data.dml.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.data.select-rowsets
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
  text: 在 120 秒内解释INSERT、UPDATE、DELETE、UPSERT 与 RETURNING的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - sql-dml-write
  - sql-upsert-returning
  covers_topics:
  - sql.insert
  - sql.update-delete
  - sql.affected-rows
  - sql.on-conflict-upsert
  - sql.returning
  - sql.write-safety-predicate
  uses_capabilities:
  - data.sql-query
  - data.relational-schema
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 编写设备 INSERT、带版本条件 UPDATE、受限 DELETE 和 ON CONFLICT UPSERT，使用 RETURNING 核对影响行，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - sql-dml-write
  - sql-upsert-returning
  covers_topics:
  - sql.insert
  - sql.update-delete
  - sql.affected-rows
  - sql.on-conflict-upsert
  - sql.returning
  - sql.write-safety-predicate
  uses_capabilities:
  - data.sql-query
  - data.relational-schema
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入 UPDATE/DELETE 漏 WHERE、UPSERT 覆盖不可变字段和忽略 affected rows，事务内发现并回滚
  covers_topic_groups:
  - sql-dml-write
  - sql-upsert-returning
  covers_topics:
  - sql.insert
  - sql.update-delete
  - sql.affected-rows
  - sql.on-conflict-upsert
  - sql.returning
  - sql.write-safety-predicate
  uses_capabilities:
  - data.sql-query
  - data.relational-schema
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# INSERT、UPDATE、DELETE、UPSERT 与 RETURNING

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《SELECT、投影、过滤、NULL、排序与分页》](ch.data.select-rowsets.md)：独立完成增改删、冲突与返回前，必须先具备「SELECT、投影、过滤、NULL、排序与分页」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。语义按 PostgreSQL **18.4** 官方文档于 **2026-07-17** 核对。本机没有 PostgreSQL server 或 `psql`；配套资产使用固定 CSV、静态 SQL 合同和 Ruby 2.6 兼容状态机。离线 PASS 能证明固定写入预言、危险语句拦截和红绿答案，**不能证明 PostgreSQL 已解析或执行这些语句，也不能证明锁、触发器或并发行为**。

## 1. DML 的核心不是“语句成功”，而是“恰好改了该改的行”

DML（Data Manipulation Language）改变表中的行：

```text
INSERT  创建新行
UPDATE  修改满足谓词的已有行
DELETE  删除满足谓词的已有行
UPSERT  插入；唯一冲突时执行明确替代动作
RETURNING 把真正写入后的行作为结果集返回
```

一次可靠写入至少有四个合同：

1. 输入合同：业务键、值、预期版本与调用意图；
2. 目标合同：表、列和候选行谓词；
3. 影响合同：预期 affected rows 是 0、1 还是某个批量范围；
4. 结果合同：RETURNING 的键、旧值/新值或删除前值。

本章固定问题：新增设备、用版本条件修改设备、只删除满足保护条件的设备，并按序列号 UPSERT；每次写入都生成可核对报告。

### 完成标准

你应能：

- INSERT 时显式列名，区分提供值、默认值与 NULL；
- UPDATE/DELETE 前用同一 WHERE 做 SELECT 预览；
- 把“预计一行”写成可验证的 affected rows 合同；
- 识别 0 行不是 SQL 错误，却可能是业务冲突；
- 用 `RETURNING` 取得实际插入、更新或删除的行；
- 用版本谓词防止把旧读结果无条件覆盖；
- 用 `ON CONFLICT` 明确冲突键，只更新允许变更的列；
- 在事务内注入漏 WHERE、不可变字段覆盖和忽略行数故障，并 ROLLBACK；
- 把输入、语句摘要、预计/实际影响行和返回键写入验证报告。

本章不设计表结构，不教授隔离级别、死锁、跨语句并发协议、批量迁移或永久审计日志。

## 2. 固定 FactoryCare 表合同与初始行

假设 `factorycare.device` 已由 DDL 章节建立：

```text
device_id      text，主键，不可变
serial_number  text，唯一、非空，不可变
display_name   text，非空，可修改
status         text，ACTIVE/MAINTENANCE/RETIRED
version        integer，正整数，每次受控更新递增
```

初始设备：

| device_id | serial_number | display_name | status | version |
| --- | --- | --- | --- | ---: |
| D-01 | SN-001 | East Pump | ACTIVE | 3 |
| D-02 | SN-002 | South Compressor | ACTIVE | 5 |
| D-03 | SN-003 | West Sensor | RETIRED | 2 |

另有 W-01 引用 D-01。D-03 没有工单，因此可在“已退役且无工单”保护条件下删除。

本章预言：

```text
INSERT D-04                         → 1 行
UPDATE D-01 WHERE version=3         → 1 行，version 3→4
再次用 version=3 更新 D-01          → 0 行
DELETE D-03（退役、无工单）          → 1 行
DELETE D-02（状态 ACTIVE）           → 0 行
UPSERT SN-002                       → 更新 D-02，version 5→6
```

## 3. INSERT：列名是写入接口

```sql
INSERT INTO factorycare.device (
  device_id,
  serial_number,
  display_name,
  status
)
VALUES (
  'D-04',
  'SN-004',
  'North Valve',
  'ACTIVE'
)
RETURNING device_id, serial_number, status, version;
```

`version` 未出现在列清单中，由表默认值产生。PostgreSQL 18 INSERT 文档说明，未列出的列使用声明的默认值；没有默认时是 NULL，随后仍要通过约束。

显式列清单的价值：

- 值与列一一对应，审查者不需背表顺序；
- 新增有默认值的列时，旧语句意图较稳定；
- 可以只授予必要列的 INSERT 权限；
- 防止把 display_name 与 status 位置写反。

不要把用户输入拼进 SQL 字符串。应用应使用驱动参数绑定；本章 SQL 文件使用字面量只是为了离线、可读的固定夹具。

## 4. DEFAULT、NULL 与省略不是同义词

三种写法要分别理解：

```sql
-- 省略 version：使用默认
INSERT INTO ... (device_id, serial_number, display_name, status)
VALUES (...);

-- 显式 DEFAULT：也使用默认
INSERT INTO ... (..., version)
VALUES (..., DEFAULT);

-- 显式 NULL：写 NULL；若 NOT NULL 则失败
INSERT INTO ... (..., version)
VALUES (..., NULL);
```

默认值不是“兜底所有错误”。显式 NULL 通常不会自动改成 DEFAULT。默认表达式产生的值也必须满足约束。

多行 VALUES 是一条 INSERT：

```sql
INSERT INTO factorycare.device (...) VALUES
  (...),
  (...)
RETURNING device_id;
```

每个成功插入的行都有 RETURNING 行。任一行违反约束时，该语句不会留下半批成功结果；事务中的其他语句如何处理由事务边界决定。

## 5. affected rows：命令完成不等于业务成功

PostgreSQL 成功命令带行数标签：

```text
INSERT 0 count
UPDATE count
DELETE count
```

`UPDATE 0` 和 `DELETE 0` 不是 SQL 错误。它们表示没有行实际被该命令更新/删除。业务应明确期待：

- 创建新设备通常期待 1；
- 按 ID 与版本更新通常期待 1；
- 幂等清理可能允许 0 或 1；
- 批量任务应有审批后的范围，而不是“成功就行”。

UPDATE 的 count 包括匹配但新值与旧值相同的行；不能用 count 判断值一定发生变化。触发器还可能抑制部分修改。因此需要 RETURNING 与必要的前后值断言。

## 6. RETURNING：把实际写入行变成结果集

RETURNING 的列清单与 SELECT 输出清单相似：

```sql
UPDATE factorycare.device
SET display_name = 'East Pump / inspected'
WHERE device_id = 'D-01'
RETURNING device_id, display_name, version;
```

只返回真正被写入的行。零影响时结果集为空。它可以取得默认生成值、触发器修改后的值以及删除前行，不需要先写再 SELECT 猜结果。

PostgreSQL 18 还允许明确请求旧、新值：

```sql
RETURNING WITH (OLD AS o, NEW AS n)
  n.device_id,
  o.version AS old_version,
  n.version AS new_version;
```

简单 INSERT 的 OLD 列为 NULL；简单 DELETE 的 NEW 列为 NULL；UPDATE 可同时读前后值。无前缀列默认取 INSERT/UPDATE 的新值、DELETE 的旧值。

RETURNING 不是永久审计表，也不代表事务已 COMMIT。客户端断线、外层回滚或日志丢失都可能使“看到返回行”与“最终持久化”不同。它是写入验证证据的一部分，不是审计系统全部。

## 7. 带版本条件 UPDATE

```sql
UPDATE factorycare.device
SET
  display_name = 'East Pump / inspected',
  version = version + 1
WHERE device_id = 'D-01'
  AND version = 3
RETURNING WITH (OLD AS o, NEW AS n)
  n.device_id,
  o.version AS old_version,
  n.version AS new_version,
  n.display_name;
```

固定输入返回 D-01、3、4、新名称。随后再次提交相同 version=3，当前行已是 4，所以 affected rows=0、RETURNING 空。

这叫条件更新。它能让调用者发现“条件已不成立”，但零行原因仍可能是：

- device_id 不存在；
- version 已变化；
- 其他保护谓词不成立；
- 行被触发器抑制。

不要把 0 自动翻译成“数据库坏了”或“用户无权限”。应用根据合同选择返回 not found、conflict 或进一步查询。本章不展开并发隔离，只训练版本谓词与行数证据。

## 8. UPDATE 的危险边界

```sql
UPDATE factorycare.device
SET status = 'RETIRED';
```

没有 WHERE 时，所有可见目标行都被更新。这在 SQL 上合法。数据库不知道你“本来只想改 D-01”。

安全工作流：

```sql
SELECT device_id, status, version
FROM factorycare.device
WHERE device_id = 'D-01' AND version = 3;

UPDATE ...
WHERE device_id = 'D-01' AND version = 3
RETURNING ...;
```

SELECT 预览必须复制同一谓词，不是大概相似的条件。对预计一行的操作，还应让谓词包含主键或候选键；仅按 `status='ACTIVE'` 可能匹配大量设备。

静态防护可拒绝无 WHERE 的 UPDATE/DELETE，但无法证明 WHERE 足够窄。运行时行数上限、事务内预览和人工审批共同防线更可靠。

## 9. UPDATE ... FROM 的一对多陷阱

PostgreSQL 支持从其他表取更新值：

```sql
UPDATE factorycare.device AS d
SET display_name = s.proposed_name
FROM factorycare.device_name_stage AS s
WHERE s.device_id = d.device_id;
```

若一个目标设备连接到多条 stage 行，只有其中一条被用于更新，但选哪一条不容易预测。官方 UPDATE 文档要求确保每个目标行至多对应一个连接输出。

诊断证据：

```sql
SELECT device_id, COUNT(*)
FROM factorycare.device_name_stage
GROUP BY device_id
HAVING COUNT(*) > 1;
```

先修来源唯一性或明确聚合规则，不用 `DISTINCT` 随机隐藏冲突。

## 10. 受限 DELETE

只删除已退役、且没有工单的指定设备：

```sql
DELETE FROM factorycare.device AS d
WHERE d.device_id = 'D-03'
  AND d.status = 'RETIRED'
  AND NOT EXISTS (
    SELECT 1
    FROM factorycare.work_order AS w
    WHERE w.device_id = d.device_id
  )
RETURNING d.device_id, d.serial_number, d.status;
```

固定数据 affected rows=1。把 ID 换成 ACTIVE 的 D-02，保护条件使结果为 0。

无 WHERE 的 DELETE 会删除表中全部行，表结构仍存在且为空。它是合法语义，不是语法保护。需要清空整表时仍应使用独立审批流程；TRUNCATE 的锁、触发器与事务边界不在本章。

外键也可拒绝被引用设备，但业务保护谓词仍有价值：它表达“只有退役且无工单才允许删除”，而不是等数据库最后报错才发现意图不符。

## 11. DELETE RETURNING 是删除证据

删除后普通 SELECT 已找不到行。RETURNING 能返回被删除行的旧值：

```sql
DELETE ...
RETURNING OLD.device_id, OLD.serial_number, OLD.status;
```

PostgreSQL 18 简单 DELETE 的无前缀列也表示旧值。建议报告至少记录主键、业务键、删除前状态和 affected rows，不默认 `RETURNING *` 暴露不必要敏感列。

删除报告不能代替恢复方案。若事务 COMMIT 后才发现误删，需要备份、审计事件或业务补偿；这些属于后续生产化主题。

## 12. UPSERT 的前提是可强制的冲突键

```sql
INSERT INTO factorycare.device AS d (
  device_id,
  serial_number,
  display_name,
  status
)
VALUES (
  'D-import-99',
  'SN-002',
  'South Compressor / calibrated',
  'ACTIVE'
)
ON CONFLICT (serial_number) DO UPDATE
SET
  display_name = EXCLUDED.display_name,
  status = EXCLUDED.status,
  version = d.version + 1
RETURNING d.device_id, d.serial_number, d.display_name, d.version;
```

`serial_number` 有唯一约束，所以数据库能用它仲裁冲突。SN-002 已属于 D-02，于是更新现有 D-02；输入里的 D-import-99 不应覆盖不可变主键。

关键词：

- `d` 是目标表现有行；
- `EXCLUDED` 是原本准备插入、因冲突被排除的候选行；
- conflict target 指定由哪个唯一索引/约束判断；
- DO UPDATE 只列出允许变更的列。

PostgreSQL 18 保证 ON CONFLICT DO UPDATE 的原子 INSERT 或 UPDATE 结果；这不等于整个业务工作流已解决全部并发问题。

## 13. 不可变字段白名单

故障：

```sql
ON CONFLICT (serial_number) DO UPDATE
SET
  device_id = EXCLUDED.device_id,
  serial_number = EXCLUDED.serial_number,
  display_name = EXCLUDED.display_name;
```

这样可能把 D-02 的主键改成导入临时 ID，破坏引用或身份连续性。即使外键最终拒绝，语句意图也错误。

正确做法不是“除某列外全部覆盖”，而是维护可变字段白名单：

```text
可变：display_name、status、version
不可变：device_id、serial_number
```

若序列号确实可更正，应建立独立、授权更高的业务命令和引用影响分析，不借普通 UPSERT 偷渡。

## 14. DO NOTHING、DO UPDATE WHERE 与返回行

`ON CONFLICT DO NOTHING` 遇冲突时不插入，affected rows=0，RETURNING 无行。它适合“重复输入可安全忽略”的明确合同；不适合把数据不一致静默吞掉。

DO UPDATE 还可附条件：

```sql
ON CONFLICT (serial_number) DO UPDATE
SET display_name = EXCLUDED.display_name
WHERE d.display_name IS DISTINCT FROM EXCLUDED.display_name
RETURNING ...;
```

若冲突行被锁定但 WHERE 为 false，该行不更新，也不出现在 RETURNING。调用者必须把 0 行纳入预言。

一批输入不能让同一现有行在一个确定性 ON CONFLICT DO UPDATE 中被影响两次；候选批次自己在冲突键上重复会触发基数错误。先验证导入批次唯一性。

## 15. RETURNING 的旧/新值与触发器边界

RETURNING 看到由命令实际处理、并经过触发器影响后的行值。对 UPSERT，可同时报告旧、新：

```sql
RETURNING
  OLD.device_id AS old_device_id,
  OLD.display_name AS old_name,
  NEW.device_id AS new_device_id,
  NEW.display_name AS new_name,
  NEW.version;
```

纯 INSERT 的 OLD 通常全 NULL；冲突更新时 OLD 可非 NULL。这是 PostgreSQL 18 当前语法面，跨旧版本或其他数据库不可直接假设支持。

应用若只读取 `RETURNING device_id`，不能声称验证了状态与版本；报告列应覆盖真正的写入不变量。

## 16. 事务内预测、观察与回滚

对高风险练习使用：

```sql
BEGIN;

-- 1. SELECT 同谓词预览
-- 2. 执行 UPDATE/DELETE ... RETURNING
-- 3. 核对 affected rows、返回键和不变量

ROLLBACK;
```

ROLLBACK 让故障实验不持久化。若验证完全符合审批条件，真实流程才会 COMMIT。官方事务教程把事务定义为全有或全无；失败后中间步骤不应影响数据库。

本章用单会话事务作安全沙箱，不讨论另一个会话同时修改时的隔离、锁等待或序列化失败。

## 17. 故障一：UPDATE/DELETE 漏 WHERE

固定初始三台设备。破坏性语句：

```sql
UPDATE factorycare.device SET status = 'RETIRED';
DELETE FROM factorycare.device;
```

预测均影响 3，而不是预计 1。诊断顺序：

1. 静态检查是否存在 WHERE；
2. 在事务内运行 RETURNING device_id；
3. 比较预期上限 1 与实际 3；
4. 立即 ROLLBACK；
5. 修复为主键加保护条件；
6. 重放同一断言，确认只返回 D-01 或 D-03。

“看到三行后手动改回去”不是可靠回滚；你可能漏掉触发器、版本、时间戳或并发变化。

## 18. 故障二：UPSERT 覆盖不可变字段

输入临时 ID D-import-99 与已存在 SN-002 冲突。错误 SET 包含 `device_id=EXCLUDED.device_id`，第一处可信证据不是最终名称，而是 RETURNING 的 old/new device_id 不一致。

安全 oracle 直接拒绝 SQL 中不可变字段出现在 DO UPDATE SET。修复后返回的 device_id 必须仍为 D-02，serial_number 仍为 SN-002，只有白名单字段与 version 改变。

## 19. 故障三：忽略 affected rows

带错误 version=2 更新 D-01：

```sql
UPDATE ...
WHERE device_id='D-01' AND version=2
RETURNING ...;
```

数据库成功完成语句但影响 0 行。若应用仍返回“保存成功”，就是业务层故障。

验证报告必须区分：

```text
sql-execution=success
expected-affected=1
actual-affected=0
business-result=CONFLICT_OR_NOT_FOUND
transaction=ROLLBACK
```

不要仅检查有没有异常。

## 20. 写入验证报告模板

```text
case-id: update-device-versioned
input: device_id=D-01, expected_version=3, display_name=...
operation: UPDATE with id+version predicate
expected-affected: 1
actual-affected: 1
returning: device_id=D-01, old_version=3, new_version=4
invariants: id unchanged; version increments once
transaction: ROLLBACK for lab / COMMIT for approved run
verdict: PASS
```

失败报告同样保留实际数据，不把 0 行改写成 1。敏感输入应脱敏，SQL 参数值按安全日志策略处理。

## 21. 最小安全检查表

在执行 UPDATE/DELETE 前问：

- 目标表是否 schema-qualified？
- WHERE 是否存在且使用主键/候选键？
- 状态、租户、版本等保护条件是否齐全？
- 相同 WHERE 的 SELECT 预计几行？
- 允许的 affected rows 范围是什么？
- RETURNING 能否证明键和关键值？
- 超范围时是否在事务内 ROLLBACK？

在执行 UPSERT 前再问：

- conflict target 是否真有唯一约束/index？
- 输入批次在该键上是否自身唯一？
- DO UPDATE SET 是否只有可变白名单列？
- 插入与更新两条路径各返回什么？
- DO NOTHING/WHERE false 的 0 行是否有业务定义？

## 22. 权限、锁与性能边界

INSERT、UPDATE、DELETE 分别需要相应权限；读取 WHERE、SET、conflict target 或 RETURNING 中的列还可能需要 SELECT 权限。权限失败与 0 affected rows 不同，应保留 SQLSTATE/错误分类。

写入会锁定或等待相关行；大范围 UPDATE/DELETE 可能造成表膨胀、复制延迟和锁争用。官方文档说明 UPDATE/DELETE 没有直接 LIMIT，可用 CTE 分批，但批处理、SKIP LOCKED、VACUUM 与重试属于后续生产主题。

本章只建立语义安全，不用离线小夹具推断真实性能。

## 23. 四类离线资产

```sh
./examples/encyclopedia/ch.data.dml/verify.sh
./labs/encyclopedia/ch.data.dml/verify.sh
./exercises/encyclopedia/ch.data.dml/verify.sh
./solutions-private/encyclopedia/ch.data.dml/verify.sh
```

- examples：正确 INSERT、版本 UPDATE、受限 DELETE、UPSERT 与报告；
- labs：新增/更新/冲突/零影响预言及三类故障；
- exercises：故意漏保护条件并覆盖不可变字段的红色 starter；
- solutions-private：通过同一结构合同的参考答案。

oracle 从 CSV 独立模拟状态变化并静态检查 SQL；它不是 PostgreSQL 解析器。

## 24. 120 秒复述

> INSERT 新建行，UPDATE/DELETE 只处理 WHERE 为真的行；没有 WHERE 会合法地影响全表。可靠写入必须声明预期 affected rows，并用 RETURNING 取得真正写入或删除的行。版本 UPDATE 把 ID 和旧 version 放在 WHERE，成功时递增版本；0 行不是 SQL 错误，但必须转成明确业务结果。UPSERT 依赖唯一冲突键，EXCLUDED 是候选插入行，DO UPDATE 只能更新可变白名单，不能覆盖 device_id、serial_number。危险练习在事务内先预览、写入、核对返回键与行数，不符合预言就 ROLLBACK。RETURNING 是即时结果，不是永久审计或 COMMIT 证明。

你还应能回答：

1. UPDATE count=1 为什么不证明值发生变化？
2. version UPDATE 返回 0 的可能原因有哪些？
3. UPSERT 为什么必须有唯一仲裁键？
4. DO UPDATE WHERE 为 false 时 RETURNING 为什么为空？
5. 预览 SELECT 与 UPDATE 的 WHERE 不一致有什么风险？
6. 为什么 RETURNING * 不是默认审计设计？

## 25. 官方主来源与版本边界

- [PostgreSQL 18 INSERT](https://www.postgresql.org/docs/18/sql-insert.html)：列清单、默认值、ON CONFLICT、affected rows、RETURNING 和 OLD/NEW；
- [PostgreSQL 18 UPDATE](https://www.postgresql.org/docs/18/sql-update.html)：WHERE、FROM 基数、count 与 RETURNING；
- [PostgreSQL 18 DELETE](https://www.postgresql.org/docs/18/sql-delete.html)：无 WHERE 全删、count 与删除值返回；
- [PostgreSQL 18 Returning Data from Modified Rows](https://www.postgresql.org/docs/18/dml-returning.html)；
- [PostgreSQL 18 Transactions](https://www.postgresql.org/docs/18/tutorial-transactions.html)。

稳定核心是目标谓词、影响行数、可变字段白名单、版本条件与回滚证据。版本相关面是 PostgreSQL 18 的 OLD/NEW RETURNING 语法、ON CONFLICT 细节、触发器/权限和命令标签。真实 PostgreSQL 18.4 尚未验证。
