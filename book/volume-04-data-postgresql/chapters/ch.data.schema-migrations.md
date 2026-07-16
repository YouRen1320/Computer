---
schema_version: 2
edition: 2026.2-draft
id: ch.data.schema-migrations
title: Flyway、版本迁移、向前修复与数据演进
responsibility: 教授可排序、可审计的 schema 演进和安全发布，不把回滚脚本当作有数据时的默认恢复方案
volume: '04'
order: 15
level: L2
status: drafting
path: book/volume-04-data-postgresql/chapters/ch.data.schema-migrations.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.data.transactions-locking
- ch.foundations.dependencies-build-packages
version_surfaces:
- postgresql-18
- flyway
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释Flyway、版本迁移、向前修复与数据演进的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - data-migration-versioning
  - data-migration-safety
  covers_topics:
  - migration.versioned-repeatable
  - migration.checksum-history
  - migration.baseline
  - migration.expand-contract
  - migration.forward-fix
  - migration.data-backfill
  uses_capabilities:
  - data.relational-schema
  - data.transactions-locks
  - foundation.toolchain-env-build
  - data.schema-migration
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 编写 V1 建表、V2 expand 新列、数据回填和 V3 contract 的 Flyway 序列，在空库与旧库各执行一次，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - data-migration-versioning
  - data-migration-safety
  covers_topics:
  - migration.versioned-repeatable
  - migration.checksum-history
  - migration.baseline
  - migration.expand-contract
  - migration.forward-fix
  - migration.data-backfill
  uses_capabilities:
  - data.relational-schema
  - data.transactions-locks
  - foundation.toolchain-env-build
  - data.schema-migration
  evidence_kind: integration-artifact-and-tests
  verification_mode: framework-or-container-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入已应用脚本 checksum 被改、非空列一步上线和中途回填失败，使用 history/forward-fix 恢复
  covers_topic_groups:
  - data-migration-versioning
  - data-migration-safety
  covers_topics:
  - migration.versioned-repeatable
  - migration.checksum-history
  - migration.baseline
  - migration.expand-contract
  - migration.forward-fix
  - migration.data-backfill
  uses_capabilities:
  - data.relational-schema
  - data.transactions-locks
  - foundation.toolchain-env-build
  - data.schema-migration
  evidence_kind: integration-failure-fix-rerun
  verification_mode: integration-fault-rerun
---
# Flyway、版本迁移、向前修复与数据演进

> 本章状态为 `drafting`。稳定核心是“数据库变更有顺序、有历史、有验证、可由旧状态安全演进”；Flyway 当前官方语义与 PostgreSQL **18** DDL 于 **2026-07-17** 核对。本机未安装/运行真实 Flyway 与 PostgreSQL，资产用文件、checksum 清单和状态机验证迁移合同。离线 PASS 不证明真实锁、事务性 DDL、Flyway history 或容器升级测试已执行。

## 1. Schema 不是一份静态 SQL，而是一条状态演进链

开发初期常把当前表结构导出成 `schema.sql`。它能描述“现在像什么”，却不能独自回答：

- 已有生产库怎样从昨天演进到今天？
- 哪段 SQL 已执行，何时执行，由谁执行，是否成功？
- 两个开发者同时提交变更时顺序怎样确定？
- 应用旧版本和新版本短暂并存时，数据库是否兼容？
- 10 万已有行怎样填新列，不阻塞或破坏业务？
- 失败后是恢复未成功脚本、写新迁移，还是恢复备份？
- 空库从零执行与旧库逐步升级，最终 schema 和数据是否一致？

数据库迁移把每次演进作为受版本控制的部署输入。Flyway 负责发现、排序、执行并在 `flyway_schema_history` 中记录；SQL 的业务正确性、安全锁影响和数据回填仍由团队负责。

### 完成标准

学习者应能：

- 区分 versioned、repeatable 和 baseline；
- 解释文件名、版本、描述、checksum 与 history 的职责；
- 知道已在永久下游环境成功应用的 versioned 文件不应改写；
- 为 FactoryCare 编写 V1、V2 expand、回填、V3 contract 序列；
- 解释 expand/backfill/dual-read-write/validate/contract 的发布次序；
- 在空库与 V1 旧库两条路径验证最终状态一致；
- 重跑 migrate 时证明没有重复副作用；
- 注入 checksum 改写、一步加非空列和中途回填失败；
- 从 history/validate/数据库状态定位第一处失败；
- 用 forward-fix 恢复已发布系统，而不是默认运行破坏性 down 脚本；
- 写出影响、迁移、观测与恢复计划。

本章不搭建完整 CI/CD、不讨论所有 Flyway 商业功能、不执行生产 `clean`、不实现多租户分片迁移，也不把 ORM 自动建表当迁移系统。

## 2. Flyway 的三个核心输入

### 2.1 Versioned migration：有版本，只成功应用一次

典型文件：

```text
V1__create_work_order.sql
V2__expand_priority_code.sql
V2_1__backfill_priority_code.sql
V3__contract_priority.sql
```

默认命名可读成：

```text
V + 唯一版本 + __ + 描述 + .sql
```

Flyway 按版本的数值顺序应用 pending versioned migrations。每个版本唯一；成功记录后不会在普通 `migrate` 中再次执行。history 保存版本、描述、类型、脚本、checksum、执行时间、成功状态等审计信息。

版本不是发布日期文本比较。`V10` 会按数值排在 `V2` 后；点号或下划线可表达分段版本，但团队应固定一种简单规则，避免人为误读。

### 2.2 Repeatable migration：无版本，checksum 变化时重跑

```text
R__work_order_reporting_view.sql
```

适用于可重复定义的视图、函数或参考数据。pending versioned migrations 执行后，repeatable 按描述排序执行。它应能多次运行，常用 `CREATE OR REPLACE`。

错误用法是把一次性、不可逆的数据变换塞进 repeatable：每次改注释导致 checksum 变化，都可能再次修改数据。历史数据演进应使用 versioned migration，并为重跑设计明确幂等边界。

### 2.3 Baseline：承认已有库的起点

团队在已有生产库上首次引入 Flyway 时，不能假装这个库是空库并重放所有建表语句。`baseline` 命令建立 history 起点，表示“此库在某版本之前的状态已由外部事实确认”。版本低于或等于约定起点的迁移不会重新执行。

baseline 不是：

- 自动验证现有库真的等于预期；
- 对任意非空库跳过错误的安全开关；
- 空库项目的必需步骤；
- baseline migration 文件 `B...` 的同义词。

采用已有库前要先做 schema/data 指纹、约束与版本证据。`baselineOnMigrate` 省一步命令，也扩大“连错库后自动承认”的风险，默认应谨慎。

## 3. Schema history 与 checksum 是防改写证据

`flyway_schema_history` 是迁移审计账本。常见状态包括 Pending、Success、Failed、Baseline、Below Baseline、Missing、Out of Order、Outdated、Superseded。团队日常关注：

```text
flyway info
flyway validate
flyway migrate
```

`validate` 比较本地可解析迁移和数据库 history：文件名、类型、版本、checksum 不一致会失败。SQL migration 的 checksum 在执行时保存，用来发现应用后被编辑。

### 3.1 已应用脚本为什么不可改

假设生产已成功执行 `V2__expand_priority_code.sql`，开发者后来“顺手修正”其中 SQL。新环境从修改后的 V2 得到状态 B，旧生产库保留原 V2 得到状态 A；两条历史不再可重现。checksum mismatch 正是在暴露这个分叉。

正确流程：

1. 恢复已应用 V2 的原始字节；
2. 新建更高版本 `V2_2__fix_priority_constraint.sql`；
3. 让所有环境按同一前进路径应用；
4. 验证空库重放与旧库升级一致。

### 3.2 `repair` 不是“让红灯消失”

Flyway `repair` 可以删除失败记录或重新对齐 checksum/history。它是高权限审计操作，不会替你证明数据库对象与数据正确。若仅为绕过未经解释的 checksum mismatch 执行 repair，就把关键告警改成绿色而没有恢复可重现性。

仅在已确认文件、数据库实际状态、变更原因和环境范围后，才把 repair 作为受审计处置；默认优先恢复原文件或 forward-fix。

## 4. 固定 FactoryCare 演进目标

V1 工单只保存数值优先级：

```sql
CREATE SCHEMA IF NOT EXISTS factorycare;

CREATE TABLE factorycare.work_order (
  work_order_id bigint PRIMARY KEY,
  summary text NOT NULL,
  priority smallint NOT NULL CHECK (priority BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp()
);
```

新需求要求 API 与报表使用稳定代码 `P1` 到 `P5`，并最终删除旧 `priority`。目标不是一步改类型，而是让旧应用和新应用在发布窗口内都能工作。

最终目标：

```sql
CREATE TABLE factorycare.work_order (
  work_order_id bigint PRIMARY KEY,
  summary text NOT NULL,
  priority_code text NOT NULL CHECK (
    priority_code IN ('P1', 'P2', 'P3', 'P4', 'P5')
  ),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp()
);
```

## 5. Expand—backfill—contract 的安全序列

### 5.1 V2 expand：先加可兼容的新结构

```sql
ALTER TABLE factorycare.work_order
  ADD COLUMN priority_code text;

ALTER TABLE factorycare.work_order
  ADD CONSTRAINT work_order_priority_code_check
  CHECK (priority_code IS NULL OR priority_code IN ('P1','P2','P3','P4','P5'))
  NOT VALID;
```

新列先允许 NULL，使仍只写旧 `priority` 的旧应用不会立刻失败。PostgreSQL 18 的 `NOT VALID` 可跳过对既有行的初次全表验证，同时约束新插入/更新；之后再显式 `VALIDATE CONSTRAINT`。

但 `ADD COLUMN`/`ALTER TABLE` 仍可能需要强锁。安全发布不能只看 SQL 短：要评估表大小、锁等待、statement/lock timeout、长事务、发布窗口和回滚条件。

### 5.2 应用兼容窗口：双读/双写是暂态协议

expand 后发布兼容应用：

```text
写：同时写 priority 与 priority_code
读：优先 priority_code，NULL 时由 priority 映射
```

这不是永久冗余，而是迁移桥。必须记录：谁负责一致性、监控不一致数量、何时停止旧写法、回滚应用版本时哪列仍可用。

### 5.3 V2.1 数据回填：可观察、可恢复

```sql
UPDATE factorycare.work_order
SET priority_code = 'P' || priority::text
WHERE priority_code IS NULL;
```

教学小表可一次更新；生产大表通常按稳定主键分批，控制每批行数、事务时长和锁/WAL。每批应满足：

- 条件只选尚未完成行；
- 相同输入重复执行不会改变已正确结果；
- 记录扫描、更新、剩余、失败范围；
- 失败后能从未完成主键区间继续；
- 并发新写由双写协议覆盖。

验收查询：

```sql
SELECT count(*) AS remaining_nulls
FROM factorycare.work_order
WHERE priority_code IS NULL;

SELECT count(*) AS mismatches
FROM factorycare.work_order
WHERE priority_code <> 'P' || priority::text;
```

两者都必须为 0，不能只以“UPDATE 无报错”为成功。

### 5.4 V2.2 验证约束

```sql
ALTER TABLE factorycare.work_order
  VALIDATE CONSTRAINT work_order_priority_code_check;
```

validation 扫描既有行；PostgreSQL 官方文档给出相应锁语义。应在观测下执行，不要把 `NOT VALID` 永久留着并误以为数据库已经证明所有历史行满足规则。

### 5.5 V3 contract：确认旧消费者退场后删除旧面

前置证据：

```text
所有实例已运行新版本
旧应用无法再写 priority-only
remaining_nulls = 0
mismatches = 0
新列约束 valid
回滚应用仍能使用新列，或已明确不可回滚
```

然后：

```sql
ALTER TABLE factorycare.work_order
  ALTER COLUMN priority_code SET NOT NULL;

ALTER TABLE factorycare.work_order
  DROP COLUMN priority;
```

contract 是破坏兼容的步骤，必须晚于应用迁移和观测窗口。若蓝绿环境中仍有旧实例，提前 DROP 会造成旧 SQL 立即失败。

## 6. V1、V2、V3 文件职责

推荐目录：

```text
db/migration/
├── V1__create_work_order.sql
├── V2__expand_priority_code.sql
├── V2_1__backfill_priority_code.sql
├── V2_2__validate_priority_code.sql
├── V3__contract_priority.sql
└── R__work_order_reporting_view.sql
```

一个 migration 尽量表达一个可审计意图。过大脚本让失败位置和锁影响难以判断；过碎脚本又增加部署协调。分界依据是事务/发布边界、可独立验证的状态和失败恢复方式，而非固定行数。

不要把敏感凭据、环境判断或手工临时 SQL 写进迁移。同一文件应在所有目标环境产生相同逻辑结果，环境差异通过受控配置和前置条件处理。

## 7. 空库路径与升级库路径必须汇合

### 路径 A：空库

```text
empty
→ V1
→ V2
→ V2.1
→ V2.2
→ V3
→ repeatable view
```

### 路径 B：已有 V1 库

```text
V1 + 真实旧数据
→ V2
→ 兼容应用
→ V2.1 backfill
→ V2.2 validate
→ V3
→ repeatable view
```

最终比较至少包括：

- schema 中列、类型、default、not-null、check、index；
- history 的成功版本集合与 checksum；
- 旧数据正确映射；
- remaining nulls/mismatches 为 0；
- 报表视图定义相同；
- 第二次 `migrate` 没有 pending versioned migration 和重复数据变化。

仅比较“最新版本号都是 3”不够。两个库可能同版本但对象或数据不同。

## 8. 迁移事务、锁与 PostgreSQL 边界

PostgreSQL 支持许多 DDL 在事务中回滚，Flyway 会按数据库能力和配置管理迁移事务。但不能推导“所有 DDL 都原子”。例如 `CREATE INDEX CONCURRENTLY` 不能在普通事务块中运行，需要显式拆分和对应配置/部署策略。

每个脚本回答：

```text
是否可在事务中执行？
取得什么锁？等待多久？
失败时 PostgreSQL 回滚了什么？
Flyway history 会记录什么状态？
脚本可否安全重试？
是否有不能与同一事务混合的命令？
```

不要在不了解数据库事务边界时把多个危险 DDL 塞进一个脚本，然后以“Flyway 会处理”为理由跳过测试。

## 9. Forward-fix 为什么优先于数据回滚脚本

schema 改动后，应用可能已经写入只符合新结构的数据。此时简单执行 down：DROP 新列或恢复旧类型，可能丢失数据、阻塞表、与已部署代码冲突。默认恢复目标应是“让系统从当前真实状态向可用状态前进”。

例：V2.1 回填把 P3 错映射成 P2，且 V2.1 已成功提交。不要编辑 V2.1，也不要先删列；新增：

```text
V2_2__correct_p3_priority_mapping.sql
```

它只修正可证明受影响的行，记录预期数量，执行前后断言，并保持新旧应用兼容。

### 9.1 何时使用备份恢复

备份/PITR 是严重事故恢复手段，不是每次 schema 变更的廉价 undo。恢复会影响迁移后产生的合法业务数据、RPO/RTO、其他表和外部系统。发布计划必须写明：

- forward-fix 条件与负责人；
- 停止流量条件；
- 恢复点和允许的数据损失；
- 对账和重放策略；
- 谁授权破坏性恢复。

## 10. 三类必做故障注入

### 故障 A：改写已应用 checksum

操作：V1 成功后在文件中改一个空格或 SQL，再运行 validate。

期望：validation 失败，指出版本/脚本 checksum mismatch；history 不被静默改成成功。修复是恢复原 V1；若逻辑要变，新增 V4 forward-fix。不要先 repair 掩盖。

### 故障 B：非空列一步上线

错误脚本：

```sql
ALTER TABLE factorycare.work_order
ADD COLUMN priority_code text NOT NULL;
```

已有行没有值会失败；即使指定 default 能通过，旧应用、新应用、表锁和回填语义也未必安全。修复为 expand nullable、兼容写、回填验证、最后 contract。

### 故障 C：中途回填失败

注入：主键 50001 处遇到非法旧值 9，CASE 映射失败或约束拒绝。

要求保存：已尝试范围、事务是否整体回滚、剩余 NULL 数、history 状态、错误行。修复数据规则后使用新 migration 或修复尚未成功的 pending/failed 脚本，依据实际事务状态决定；禁止手工把 history 改成 Success。

## 11. 诊断顺序：从历史到账面真实状态

1. **连接目标**：数据库、schema、用户是否正确？
2. **info/history**：最新成功、pending、failed、baseline 是什么？
3. **validate**：版本、文件名、类型、checksum 是否一致？
4. **数据库事务状态**：失败 SQL 是否已整体回滚？
5. **对象状态**：列/约束/index 到了哪一步？
6. **数据状态**：null、mismatch、非法值、批次进度？
7. **应用兼容**：当前运行实例读写哪些列？
8. **锁与阻塞**：失败是 SQL 错误还是无法取得锁？
9. **修复路径**：恢复原脚本、修复未成功迁移、还是新增 forward-fix？
10. **重放证明**：空库与升级库是否再次汇合？

第一处可信证据通常是 history/validate 与实际对象之间的分叉，而不是日志最后一行“migrate failed”。

## 12. 发布门与验证报告

发布前：

- migration 文件已入版本控制且版本唯一；
- checksum 清单固定；
- 空库和 V1 旧库集成路径通过；
- expand 与 contract 分属兼容窗口；
- 回填行数、批次、超时、观测明确；
- SQL 锁/事务边界已核对；
- contract 前旧应用已退场；
- forward-fix、停止条件和备份恢复边界明确。

报告格式：

```text
flyway-version/database-version:
input-path: empty-or-v1-upgrade
resolved-migrations/checksums:
history-before:
operations:
history-after:
schema-fingerprint:
data-counts/nulls/mismatches:
second-migrate-result:
injected-failure:
first-trusted-evidence:
forward-fix-result:
unverified-production-lock-impact:
```

## 13. 配套资产

- `examples/encyclopedia/ch.data.schema-migrations/`：V1/V2/V2.1/V2.2/V3 与 repeatable 文件清单、两路径预期；
- `labs/encyclopedia/ch.data.schema-migrations/`：checksum、一步非空和回填失败故障；
- `exercises/encyclopedia/ch.data.schema-migrations/`：故意改写历史且一步 contract 的红灯 starter；
- `solutions-private/encyclopedia/ch.data.schema-migrations/`：不可变历史、expand/backfill/contract、forward-fix 私有解。

离线 oracle 验证文件顺序、checksum 不变、两路径最终指纹一致、第二次 migrate 无变化、失败不标 Success。真实 T3 验收仍需 Flyway 与 PostgreSQL 容器。

## 14. 120 秒讲回

不看笔记解释：

1. versioned 与 repeatable 何时执行？
2. checksum mismatch 在保护什么？
3. baseline 为什么不是“非空库自动跳过错误”？
4. 为什么新非空列要 expand/backfill/contract？
5. 已成功 V2 有错时为什么新增 V3/V4 而不是编辑 V2？
6. 空库与升级库要比较哪些事实？
7. 为什么 down 脚本不是有数据生产库的默认恢复？

## 15. 官方来源

- [Flyway Versioned migrations](https://documentation.red-gate.com/flyway/flyway-concepts/migrations/versioned-migrations)；
- [Flyway Repeatable migrations](https://documentation.red-gate.com/flyway/flyway-concepts/migrations/repeatable-migrations)；
- [Flyway schema history table](https://documentation.red-gate.com/flyway/flyway-concepts/migrations/flyway-schema-history-table) 与 [Validate](https://documentation.red-gate.com/flyway/reference/commands/validate)；
- [Flyway Baselines](https://documentation.red-gate.com/flyway/flyway-concepts/baselines)；
- [PostgreSQL 18 ALTER TABLE](https://www.postgresql.org/docs/18/sql-altertable.html)：锁、NOT VALID、VALIDATE 与 SET NOT NULL；
- [PostgreSQL 18 CREATE INDEX](https://www.postgresql.org/docs/18/sql-createindex.html)：并发建索引的事务边界。

稳定核心是不可变历史、可重放顺序、兼容演进和 forward-fix；版本相关面是 Flyway 命令/状态与 PostgreSQL 18 DDL 锁语义。真实集成仍未验证。
