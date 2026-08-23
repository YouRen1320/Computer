---
schema_version: 2
edition: 2026.2-draft
id: ch.data.ddl-constraints
title: CREATE/ALTER、主外键、唯一、检查与非空约束
responsibility: 教授由数据库强制执行结构和行级不变量，不在本章完成规范化推导或迁移发布策略
volume: '04'
order: 10
level: L1
status: drafting
path: book/volume-04-data-postgresql/chapters/ch.data.ddl-constraints.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.data.postgresql-psql
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
  text: 在 120 秒内解释CREATE/ALTER、主外键、唯一、检查与非空约束的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - sql-ddl
  - sql-constraints
  covers_topics:
  - sql.create-table
  - sql.alter-drop
  - sql.schema-object
  - sql.prebuilt-schema
  - sql.primary-foreign-key
  - sql.unique-check-not-null
  - sql.constraint-failure
  uses_capabilities:
  - data.relational-schema
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：从预建 schema 重建 device/work_order 表，加入主外键、唯一、CHECK 与 NOT NULL，并写合法/非法插入矩阵，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - sql-ddl
  - sql-constraints
  covers_topics:
  - sql.create-table
  - sql.alter-drop
  - sql.schema-object
  - sql.prebuilt-schema
  - sql.primary-foreign-key
  - sql.unique-check-not-null
  - sql.constraint-failure
  uses_capabilities:
  - data.relational-schema
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入外键方向错误、允许非法状态和 ALTER 破坏存量数据，读约束名后安全修复
  covers_topic_groups:
  - sql-ddl
  - sql-constraints
  covers_topics:
  - sql.create-table
  - sql.alter-drop
  - sql.schema-object
  - sql.prebuilt-schema
  - sql.primary-foreign-key
  - sql.unique-check-not-null
  - sql.constraint-failure
  uses_capabilities:
  - data.relational-schema
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# CREATE/ALTER、主外键、唯一、检查与非空约束

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《PostgreSQL 服务、连接、psql 与脚本执行》](ch.data.postgresql-psql.md)：独立完成结构定义、约束前，必须先具备「PostgreSQL 服务、连接、psql 与脚本执行」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。语义按 PostgreSQL **18.4** 官方文档于 **2026-07-17** 核对。本机没有 PostgreSQL server 或 `psql`；资产用静态 DDL 合同、固定合法/非法行和 Ruby 2.6 兼容约束 oracle。离线 PASS 能证明模型预言和红绿答案，**不能证明 PostgreSQL 已解析 DDL、取得真实锁或执行实际约束检查**。

## 1. DDL 把“应当”变成数据库必须执行的不变量

DDL（Data Definition Language）定义数据库对象：schema、table、column、constraint 等。应用校验可以给用户友好提示，但只有数据库约束能对所有写入入口统一执行最后防线。

本章固定任务：已存在 `factorycare` schema，从中重建 `device` 与 `work_order` 表，使数据库拒绝：

- 重复主键；
- 重复设备序列号；
- 工单引用不存在设备；
- 非法设备/工单状态；
- 必填列为 NULL。

结构关系：

```text
factorycare schema
├── device
│   ├── primary key: device_id
│   ├── unique: serial_number
│   ├── check: status, version
│   └── not null: 关键列
└── work_order
    ├── primary key: work_order_id
    ├── foreign key: device_id → device.device_id
    ├── check: status
    └── not null: device_id, summary, status
```

### 完成标准

你应能：

- 区分 schema、表、列、默认值和约束；
- 在预建 schema 中用限定名创建对象；
- 解释主键、唯一、外键、CHECK、NOT NULL 各保护什么；
- 正确判断引用表、被引用表和外键方向；
- 预测 CHECK 遇 NULL、UNIQUE 遇 NULL 的 PostgreSQL 语义；
- 用名字定位约束失败，而不是只看模糊错误；
- 在事务内重建表并证明失败不留下半成品结构；
- 用合法/孤儿/重复/非法状态/空必填矩阵重放验证；
- 识别 ALTER 在存量数据上验证失败，并选择先清理或 NOT VALID/VALIDATE 流程。

本章不做规范化推导、生产迁移发布、在线零停机方案、分区表或复杂索引设计。

## 2. schema 是命名空间，不是另一台数据库

一个 PostgreSQL database 内可以有多个 schema。对象完整名是：

```text
schema_name.object_name
factorycare.device
factorycare.work_order
```

先确认预建 schema：

```sql
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name = 'factorycare';
```

预期一行。零行时停止并报告前置条件缺失，不静默在 `public` 创建同名表。

未限定名称由 `search_path` 找第一个匹配对象。学习与迁移脚本使用 `factorycare.device`，使目标明确；应用如何配置安全 search_path 属于部署主题。

`CREATE TABLE IF NOT EXISTS` 只避免同名对象错误，不保证已有表与期望定义一致。不能把它当 schema drift 检测器。

## 3. 数据类型、默认值与约束各有职责

```text
data type  规定值的基本表示范围，如 text、integer、timestamptz
default    INSERT 省略列时产生候选值
constraint 判断候选行或关系是否允许进入表
```

例如 `version integer DEFAULT 1 NOT NULL CHECK (version > 0)`：

- integer 拒绝不能转换成整数的值；
-省略 version 时默认 1；
- 显式 NULL 被 NOT NULL 拒绝；
- 0、-1 被 CHECK 拒绝。

DEFAULT 不是约束。把默认状态设为 ACTIVE 不会阻止显式写 BROKEN；必须另有 CHECK。

## 4. 完整 device 表

```sql
CREATE TABLE factorycare.device (
  device_id text,
  serial_number text
    CONSTRAINT device_serial_number_not_null NOT NULL,
  display_name text
    CONSTRAINT device_display_name_not_null NOT NULL,
  status text
    CONSTRAINT device_status_not_null NOT NULL,
  version integer
    DEFAULT 1
    CONSTRAINT device_version_not_null NOT NULL,
  created_at timestamptz
    DEFAULT CURRENT_TIMESTAMP
    CONSTRAINT device_created_at_not_null NOT NULL,

  CONSTRAINT device_pkey
    PRIMARY KEY (device_id),
  CONSTRAINT device_serial_number_key
    UNIQUE (serial_number),
  CONSTRAINT device_status_check
    CHECK (status IN ('ACTIVE', 'MAINTENANCE', 'RETIRED')),
  CONSTRAINT device_version_check
    CHECK (version > 0)
);
```

列定义之间、表约束之间用逗号分隔；最后一项后不加逗号。为约束命名能让错误直接指出 `device_status_check`，也便于 ALTER/DROP 精确引用。

## 5. 完整 work_order 表

```sql
CREATE TABLE factorycare.work_order (
  work_order_id text,
  device_id text
    CONSTRAINT work_order_device_id_not_null NOT NULL,
  summary text
    CONSTRAINT work_order_summary_not_null NOT NULL,
  status text
    CONSTRAINT work_order_status_not_null NOT NULL,
  created_at timestamptz
    DEFAULT CURRENT_TIMESTAMP
    CONSTRAINT work_order_created_at_not_null NOT NULL,

  CONSTRAINT work_order_pkey
    PRIMARY KEY (work_order_id),
  CONSTRAINT work_order_status_check
    CHECK (status IN ('CREATED', 'IN_PROGRESS', 'CLOSED', 'CANCELLED')),
  CONSTRAINT work_order_device_fk
    FOREIGN KEY (device_id)
    REFERENCES factorycare.device (device_id)
    ON DELETE RESTRICT
);
```

先创建被引用的 device，再创建引用它的 work_order。删除结构时顺序反过来：先 work_order，再 device。`CASCADE` 会自动移除依赖对象，练习中不用它掩盖依赖关系。

## 6. PRIMARY KEY：一行的正式身份

主键要求列组合唯一且非 NULL。表最多一个 PRIMARY KEY，但可有多个 UNIQUE。PostgreSQL 会为主键自动建立唯一 B-tree index，并把主键列标为 NOT NULL。

```sql
CONSTRAINT device_pkey PRIMARY KEY (device_id)
```

复合主键：

```sql
PRIMARY KEY (tenant_id, device_id)
```

表示组合唯一，不表示每列单独唯一。本章固定表使用单列业务演示 ID，不讨论代理键与自然键选型。

没有主键的表仍可创建；“PostgreSQL 允许”不代表关系模型完整。应用更新、外键引用和诊断都需要稳定行身份。

## 7. UNIQUE：候选键，不等于主键

序列号不是本章主键，但业务要求不可重复：

```sql
CONSTRAINT device_serial_number_key UNIQUE (serial_number)
```

UNIQUE 自动建立唯一 B-tree index。多个列时，只约束组合：

```sql
UNIQUE (tenant_id, serial_number)
```

PostgreSQL 默认把两个 NULL 视为不相等，所以 UNIQUE 默认可允许多行 NULL。若业务要求序列号必填，应同时 NOT NULL；不能靠 UNIQUE 推断非空。

PostgreSQL 18 支持 `UNIQUE NULLS NOT DISTINCT (...)`，可让 NULL 在唯一比较中视作相等。它是版本相关选择；固定 schema 用明确 NOT NULL，语义更直接。

## 8. NOT NULL：必填值不能缺失

```sql
display_name text
  CONSTRAINT device_display_name_not_null NOT NULL
```

NOT NULL 只回答“有没有值”，不回答空字符串是否允许、文本长度或业务格式。`''` 不是 NULL；若空字符串也非法，需要额外 CHECK，例如 `CHECK (btrim(display_name) <> '')`。

命名 NOT NULL 便于报告。PostgreSQL 18 支持显式约束名；传统 `column text NOT NULL` 也正确，但系统选择名称。

大多数业务必填列应明确 NOT NULL，避免每个查询重复猜 NULL 含义。

## 9. CHECK：当前行的布尔不变量

```sql
CONSTRAINT device_status_check
  CHECK (status IN ('ACTIVE', 'MAINTENANCE', 'RETIRED'))
```

CHECK 表达式为 TRUE 时通过；为 FALSE 时拒绝；**为 NULL 时也视为满足**。因此：

```sql
status text CHECK (status IN (...))
```

仍可能允许 status=NULL。固定 schema 同时声明 NOT NULL。

表级 CHECK 可比较同一行多个列：

```sql
CHECK (closed_at IS NULL OR closed_at >= created_at)
```

PostgreSQL 不支持用 CHECK 稳定引用其他行或其他表的数据；跨表存在性用 FOREIGN KEY，跨行唯一用 UNIQUE。包含可变函数的 CHECK 也会破坏数据库对表达式不变性的假设。

## 10. FOREIGN KEY：引用方向必须从子行指向父键

```sql
CONSTRAINT work_order_device_fk
  FOREIGN KEY (device_id)
  REFERENCES factorycare.device (device_id)
```

词汇：

```text
work_order 是 referencing table（引用表/子表）
device 是 referenced table（被引用表/父表）
work_order.device_id 是外键列
device.device_id 是被引用唯一键
```

它保证每个非 NULL work_order.device_id 都能在 device 找到。由于本章还加 NOT NULL，工单不能用 NULL 绕过引用。

故障方向：

```sql
ALTER TABLE factorycare.device
ADD FOREIGN KEY (device_id)
REFERENCES factorycare.work_order (device_id);
```

这要求“每台设备先对应某张工单”，把生命周期颠倒，并且 work_order.device_id 不是唯一候选键时无法成为有效目标。

## 11. 被引用列与索引边界

外键目标必须是主键、唯一约束或合适的非部分唯一索引，保证一个引用值对应明确父键。列数量与类型必须相容。

被引用键已有唯一索引。PostgreSQL 不会因为声明外键就自动为引用列 `work_order.device_id` 创建索引；父行删除/键更新要检查子表，生产规模通常应评估为引用列建索引。

“外键自动有两边索引”是常见误解。索引策略需根据查询和写入计划单独验证，本章不宣称离线模型的性能。

## 12. ON DELETE 动作是业务所有权声明

固定模型使用：

```sql
ON DELETE RESTRICT
```

仍有工单时不允许删除设备，因为设备与历史工单是独立重要对象。

常见动作：

- `NO ACTION`：默认；约束检查可在可延迟约束中推迟；
- `RESTRICT`：更严格，不能延迟该删除检查；
- `CASCADE`：父行删除时自动删引用行；
- `SET NULL`：外键列设 NULL，仍必须满足 NOT NULL 等其他约束；
- `SET DEFAULT`：设默认值，该值仍必须引用有效父行。

CASCADE 适合真正的组成部分，不是“省得写 DELETE”。对 FactoryCare 历史工单默认不级联删除。

## 13. 合法/非法插入矩阵

先插合法父行与子行：

```sql
INSERT INTO factorycare.device (
  device_id, serial_number, display_name, status
)
VALUES ('D-01', 'SN-001', 'East Pump', 'ACTIVE');

INSERT INTO factorycare.work_order (
  work_order_id, device_id, summary, status
)
VALUES ('W-01', 'D-01', 'Inspect vibration', 'CREATED');
```

预言矩阵：

| case | 输入 | 预期约束 | 结果 |
| --- | --- | --- | --- |
| valid-device | D-01/SN-001/ACTIVE | 全部 | 接受 |
| valid-order | W-01→D-01/CREATED | 全部 | 接受 |
| orphan | W-99→D-99 | work_order_device_fk | 拒绝 |
| duplicate | D-02/SN-001 | device_serial_number_key | 拒绝 |
| bad-device-status | BROKEN | device_status_check | 拒绝 |
| bad-order-status | UNKNOWN | work_order_status_check | 拒绝 |
| null-required | summary=NULL | work_order_summary_not_null | 拒绝 |

负例失败是预期证据，不能因为终端出现 error 就把整个 lab 判失败。应核对约束名、SQLSTATE 类别和失败后行数未增加。

## 14. CREATE/DROP 的依赖顺序

仅在隔离学习数据库重建：

```sql
BEGIN;

DROP TABLE IF EXISTS factorycare.work_order;
DROP TABLE IF EXISTS factorycare.device;

CREATE TABLE factorycare.device (...);
CREATE TABLE factorycare.work_order (...);

COMMIT;
```

先 drop 子表，避免外键依赖阻止父表删除；先 create 父表，保证外键目标存在。

DROP TABLE 会删除数据与结构，是破坏性操作。生产迁移不能照抄本章重建脚本；需要备份、兼容窗口、迁移工具和回滚计划，明确列为非目标。

## 15. 事务避免半成品结构

错误脚本：先 DROP 旧表，CREATE device 成功，CREATE work_order 因外键错误失败。如果每条命令自动提交，就可能留下只有 device 的半成品。

把相关 DDL 放入事务：

```sql
BEGIN;
DROP TABLE ...;
CREATE TABLE ...;
CREATE TABLE ...; -- 假设这里失败
ROLLBACK;
```

PostgreSQL 常规 CREATE/ALTER/DROP 的目录修改参与事务。ROLLBACK 恢复事务前状态。真实脚本还应让 psql/迁移工具遇错停止，不能错误后继续 COMMIT。

离线 oracle 只模拟“全部结构成功才替换”合同，没有在真实 server 验证事务 DDL。

## 16. ALTER TABLE：改变已有对象

增加普通列：

```sql
ALTER TABLE factorycare.device
ADD COLUMN location_code text;
```

增加约束：

```sql
ALTER TABLE factorycare.device
ADD CONSTRAINT device_location_code_check
CHECK (location_code IS NULL OR btrim(location_code) <> '');
```

设非空：

```sql
ALTER TABLE factorycare.device
ALTER COLUMN location_code SET NOT NULL;
```

最后一步只有在所有存量行非 NULL 时成功，通常需要扫描验证。正确流程是先添加允许 NULL 的列、回填、查询剩余 NULL、再 SET NOT NULL。生产锁和发布阶段不在本章。

## 17. ALTER 遇存量非法数据

假设旧表已有：

```text
D-legacy | status=BROKEN
```

直接：

```sql
ALTER TABLE factorycare.device
ADD CONSTRAINT device_status_check
CHECK (status IN ('ACTIVE', 'MAINTENANCE', 'RETIRED'));
```

PostgreSQL 扫描存量行，发现 BROKEN，整条 ALTER 失败；不会留下一个“半加成功”的有效约束。错误不是约束太严格，而是数据与目标不变量冲突。

安全路径 A：先查并修复所有非法状态，再加并立即验证约束。

安全路径 B（需要阶段化时）：

```sql
ALTER TABLE factorycare.device
ADD CONSTRAINT device_status_check
CHECK (status IN ('ACTIVE', 'MAINTENANCE', 'RETIRED'))
NOT VALID;

-- 修复存量 BROKEN

ALTER TABLE factorycare.device
VALIDATE CONSTRAINT device_status_check;
```

NOT VALID 跳过存量扫描，但仍约束后续 INSERT/UPDATE；验证前数据库不能假设全部旧行合规。PostgreSQL 18 的 NOT VALID 适用于外键、CHECK 和 NOT NULL，不适用于把 UNIQUE/PRIMARY KEY 直接跳过验证。

## 18. 读取约束名定位失败

约束错误通常包含约束名。诊断报告应写：

```text
case=orphan-work-order
expected-constraint=work_order_device_fk
actual-constraint=work_order_device_fk
input-key=device_id:D-99
row-count-before=1
row-count-after=1
verdict=EXPECTED_REJECTION
```

若预期 status check，却实际先触发 NOT NULL，说明负例同时破坏多个合同，无法隔离根因。每个负例一次只破坏一个不变量。

约束检查顺序不由定义书写顺序保证；不要依赖“第一个写的约束先报”。

## 19. 故障一：外键方向反了

症状可能是外键目标不唯一、建表失败，或设备插入必须依赖尚不存在工单。

第一处证据：读 `FOREIGN KEY (child_column) REFERENCES parent(unique_key)`，用自然语言复述：“每张工单必须引用已存在设备”。若语句说成“每台设备必须引用某张工单”，方向错误。

修复后重放：先插 D-01 成功，再插 W-01→D-01 成功，W-99→D-99 被 `work_order_device_fk` 拒绝。

## 20. 故障二：允许非法状态

只有 `status text NOT NULL` 时，BROKEN 非 NULL，因此会被接受。应用下拉框不是数据库保证，导入脚本或其他服务仍可写入。

修复：命名 CHECK 加 NOT NULL，并以合法 ACTIVE、边界 RETIRED、非法 BROKEN、NULL 四例验证。CHECK 单独会让 NULL 通过，这是必须观察的失败机制。

## 21. 故障三：ALTER 破坏存量数据假设

症状：开发空表上 ALTER 成功，部署到含 BROKEN 或 NULL 的表失败。

第一处证据不是重试 ALTER，而是查询违反目标谓词的存量行：

```sql
SELECT device_id, status
FROM factorycare.device
WHERE status IS NULL
   OR status NOT IN ('ACTIVE', 'MAINTENANCE', 'RETIRED');
```

选择必须显式：修复/映射旧值后立即加约束，或 NOT VALID 阶段化再 VALIDATE。不要删除约束以“让发布过”。

## 22. DROP/ALTER 的破坏与回滚边界

```sql
ALTER TABLE factorycare.device
DROP COLUMN serial_number;
```

可能连带破坏唯一约束和应用合同。默认 RESTRICT 会在有依赖时拒绝；CASCADE 会扩大删除范围。执行前列出依赖、影响、迁移与回滚。

`ALTER COLUMN TYPE` 可能需要 USING 转换、重写表或失败；`SET DEFAULT` 只影响后续写入，不自动改存量行。这些语义边界要与数据迁移分开。

本章只在离线文本中说明，不实施任何真实破坏性 DDL。

## 23. 约束与应用校验如何协作

应用校验负责：

- 尽早、友好提示；
- 展示字段级错误；
- 执行业务权限和跨流程规则。

数据库约束负责：

- 所有客户端一致执行；
- 在竞争写入中维护唯一和引用完整性；
- 防止批量导入、脚本绕过应用校验。

应用必须捕获约束失败，按约束名/SQLSTATE 映射业务错误；不能把数据库错误原文直接泄露给最终用户，也不能只靠前端校验。

## 24. 完整验证报告

```text
schema=factorycare (prebuilt, confirmed)
tables=device,work_order
create-order=device→work_order
constraints=device_pkey,device_serial_number_key,
            device_status_check,work_order_pkey,
            work_order_status_check,work_order_device_fk,
            named NOT NULL constraints

valid-device=ACCEPT
valid-work-order=ACCEPT
orphan=REJECT work_order_device_fk
duplicate-serial=REJECT device_serial_number_key
invalid-device-status=REJECT device_status_check
invalid-order-status=REJECT work_order_status_check
null-summary=REJECT work_order_summary_not_null
failed-rebuild=ROLLBACK old-structure-preserved
```

“脚本跑完”不是报告。每条非法输入必须有预期约束和失败后状态断言。

## 25. 常见误解速查

| 误解 | 事实 |
| --- | --- |
| DEFAULT 会修正 NULL | 显式 NULL 不等于省略/DEFAULT |
| CHECK(status IN ...) 会拒绝 NULL | CHECK 为 NULL 时通过；还需 NOT NULL |
| UNIQUE 自动非空 | 默认可有多个 NULL；配 NOT NULL |
| PRIMARY KEY 只是 UNIQUE 别名 | 它还强制非空，并是表的正式主键 |
| 外键建在父表 | 外键通常在引用父行的子表 |
| 外键自动索引两边 | 被引用键唯一索引已有；引用列不自动建 |
| IF NOT EXISTS 验证结构一致 | 它只处理同名对象存在 |
| CASCADE 更省事 | 它扩大破坏范围，必须符合所有权语义 |
| ALTER 加约束只影响新行 | 默认验证存量；NOT VALID 才跳过 |
| 应用校验足够 | 其他客户端可绕过，竞争写入也需数据库保证 |

## 26. 四类离线资产

```sh
./examples/encyclopedia/ch.data.ddl-constraints/verify.sh
./labs/encyclopedia/ch.data.ddl-constraints/verify.sh
./exercises/encyclopedia/ch.data.ddl-constraints/verify.sh
./solutions-private/encyclopedia/ch.data.ddl-constraints/verify.sh
```

- examples：正确两表 DDL 与合法/非法矩阵；
- labs：外键方向、缺状态 CHECK、存量 ALTER 三类注入；
- exercises：故意漏约束并反向外键的红色 starter；
- solutions-private：通过同一约束合同的参考定义。

oracle 静态检查 schema.sql，并在内存中独立执行约束模型。它不替代 PostgreSQL 18 实机。

## 27. 120 秒复述

> DDL 定义 schema、表、列和由数据库执行的不变量。PRIMARY KEY 唯一且非空，是一行正式身份；UNIQUE 保护候选键，但默认允许多个 NULL，所以必填业务键还需 NOT NULL。CHECK 只检查当前行，结果为 NULL 时也通过，因此状态列同时要 NOT NULL。FOREIGN KEY 写在引用表 work_order，指向被引用表 device 的主键，保证非 NULL 外键有父行；删除动作表达所有权。预建 factorycare schema 要先确认并用限定名。重建时父表先建、子表后建，删除顺序相反，并放在事务内防止半成品。ALTER 加约束默认验证存量；有坏数据就先清理，或 NOT VALID 后修复并 VALIDATE。失败诊断读约束名并确认行数未变化。

还应能回答：

1. CHECK 为什么不能代替 NOT NULL？
2. UNIQUE 与 PRIMARY KEY 的 NULL/数量边界是什么？
3. 外键为何不能指向普通非唯一列？
4. 为什么 work_order.device_id 的索引不会自动创建？
5. NOT VALID 对旧行和新写入分别意味着什么？
6. 为什么错误重建要用 ROLLBACK，而不是继续补建？

## 28. 官方主来源与版本边界

- [PostgreSQL 18 Constraints](https://www.postgresql.org/docs/18/ddl-constraints.html)：CHECK、NOT NULL、UNIQUE、PRIMARY KEY、FOREIGN KEY 与删除动作；
- [PostgreSQL 18 CREATE TABLE](https://www.postgresql.org/docs/18/sql-createtable.html)：列/表约束和对象创建语法；
- [PostgreSQL 18 ALTER TABLE](https://www.postgresql.org/docs/18/sql-altertable.html)：存量验证、NOT VALID、VALIDATE、SET NOT NULL 与 DROP；
- [PostgreSQL 18 Schemas](https://www.postgresql.org/docs/18/ddl-schemas.html)：限定名与 search_path；
- [PostgreSQL 18 Transactions](https://www.postgresql.org/docs/18/tutorial-transactions.html)。

稳定核心是键、引用方向、行级不变量、命名错误证据与事务回滚。版本相关面是 PostgreSQL 18 的命名 NOT NULL、NULLS NOT DISTINCT、NOT VALID/VALIDATE、锁级别和 DDL 语法。真实 PostgreSQL 18.4 尚未验证。
