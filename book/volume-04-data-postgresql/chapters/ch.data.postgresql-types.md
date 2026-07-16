---
schema_version: 2
edition: 2026.2-draft
id: ch.data.postgresql-types
title: UUID、JSONB、数组与 PostgreSQL 类型选择
responsibility: 教授 PostgreSQL 扩展类型的适用边界，不用 JSONB 或数组逃避关系建模和约束
volume: '04'
order: 12
level: L1
status: drafting
path: book/volume-04-data-postgresql/chapters/ch.data.postgresql-types.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.data.ddl-constraints
version_surfaces:
- postgresql-18
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释UUID、JSONB、数组与 PostgreSQL 类型选择的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - postgres-identity-json
  - postgres-array-domain
  covers_topics:
  - postgres.uuid-type
  - postgres.jsonb-type
  - postgres.jsonb-boundary
  - postgres.array-type
  - postgres.domain-enum
  - postgres.type-portability
  uses_capabilities:
  - data.relational-schema
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：为设备 ID、可扩展属性、标签集合和状态选择 UUID/JSONB/数组/enum 或关系表并记录决策矩阵，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - postgres-identity-json
  - postgres-array-domain
  covers_topics:
  - postgres.uuid-type
  - postgres.jsonb-type
  - postgres.jsonb-boundary
  - postgres.array-type
  - postgres.domain-enum
  - postgres.type-portability
  uses_capabilities:
  - data.relational-schema
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入把高频关联数据塞 JSONB、无界数组和不可迁移 enum 变更，依据查询/约束需求重新建模
  covers_topic_groups:
  - postgres-identity-json
  - postgres-array-domain
  covers_topics:
  - postgres.uuid-type
  - postgres.jsonb-type
  - postgres.jsonb-boundary
  - postgres.array-type
  - postgres.domain-enum
  - postgres.type-portability
  uses_capabilities:
  - data.relational-schema
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# UUID、JSONB、数组与 PostgreSQL 类型选择

> 本章状态为 `drafting`。PostgreSQL **18** 类型语义于 **2026-07-17** 按官方文档核对。本机没有 PostgreSQL server/`psql`；配套资产以固定值分类、静态 DDL 合同和 Ruby 2.6 兼容 oracle 验证决策边界。离线 PASS **不能证明 PostgreSQL 已解析类型、执行 cast/函数、建立索引或得到某个性能结果**。

## 1. 选类型是在选择数据库能理解和强制的语义

把所有值存成 text 很灵活，却丢失很多数据库能力：格式拒绝、运算、索引操作符、类型安全和清晰接口。反过来，把所有不确定字段塞 JSONB、把多值都塞数组，也会绕过关系约束。

类型选择依次回答：

```text
这个值是什么事实？
必须满足哪些格式/范围/引用？
怎样查询、排序、连接和更新？
集合元素是否有独立身份？
值集合如何演化？
是否需要跨数据库可移植？
```

### 完成标准

你应能：

- 选择 native uuid，而不是把 UUID 当任意 text；
- 区分 SQL NULL 与 JSON `null`；
- 解释 json 与 jsonb 的存储/处理差异；
- 只把可扩展、相对原子的可选属性放 JSONB；
- 区分 NULL 数组、空数组和含 NULL 元素数组；
- 知道声明数组长度不会自动强制长度；
- 判断多值何时用有界数组、何时用关联表；
- 区分 domain、enum、text+CHECK 与参考表的演化边界；
- 为每个决定记录约束、查询、演化和可移植性；
- 从高频 JSON 关联、无界数组和 enum 变更失败重新建模。

本章不做 JSONPath 深入、GIN 性能调优、自定义类型实现或跨数据库迁移执行。

## 2. FactoryCare 决策矩阵

| 业务事实 | 选择 | 主要理由 | 明确不选 |
| --- | --- | --- | --- |
| device_id | uuid | 128 位身份、原生解析/比较、分布式生成 | varchar(36) |
| serial_number | asset_code domain + column NOT NULL/UNIQUE | 重用格式语义 | 裸 text |
| vendor_metadata | nullable jsonb object | 厂商键可扩展、整体属于一台设备 | 把核心 FK 放 JSONB |
| search_aliases | 有界 text[] | 最多 5 个、无独立身份、只随设备整体维护 | 无界业务标签数组 |
| 核心 tags | tag + device_tag 关系表 | 标签可查询、去重、引用、有独立生命周期 | JSONB/数组 |
| device status | text + CHECK（本章选择） | 便于迁移/跨库；固定集合由约束执行 | 快速演化流程直接 enum |

没有“PostgreSQL 类型越专用越好”。矩阵必须说明为什么、约束什么、以后怎么改。

## 3. UUID：值、类型与生成算法是三件事

UUID 是 128 位标识。标准文本形态：

```text
a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11
```

```sql
SELECT 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid;
```

PostgreSQL 输入还接受大写、去连字符等若干形式，输出统一标准小写带连字符形式。无效十六进制或长度在类型输入阶段失败。

`uuid` 类型可保存任意版本 UUID；版本决定生成方式与性质，不由列类型自动选择。

## 4. PostgreSQL 18 的 UUIDv4 与 UUIDv7

PostgreSQL 18 原生提供 UUIDv4、UUIDv7 生成：

```sql
SELECT uuidv4();
SELECT uuidv7();
```

- v4 主要是随机；
- v7 含时间有序成分，常对按生成时间局部写入更友好；
- 两者都仍需 PRIMARY KEY/UNIQUE 执行表内唯一合同；
- “极不可能冲突”不是可以删除唯一约束的理由。

固定 schema：

```sql
device_id uuid DEFAULT uuidv7() PRIMARY KEY
```

若应用生成 UUID，应明确版本、库和重试策略；不要数据库与客户端随机混用而不记录来源。`uuidv7()` 是 PostgreSQL 18 版本面，旧版本部署需重新核对。

## 5. UUID 的 NULL 与文本边界

```text
合法 uuid             → 类型接受
SQL NULL + nullable    → 接受，表示没有值
SQL NULL + PRIMARY KEY → NOT NULL 拒绝
'not-a-uuid'::uuid     → 类型输入错误
```

不要用全零 UUID 代替 NULL，除非它是明确、受约束的业务身份。哨兵值看起来合法，会绕过外键/非空语义。

不要为方便日志把列改成 text；在应用/展示边界 cast 为文本即可，存储仍保留 uuid 类型。

## 6. json 与 jsonb

PostgreSQL 两种 JSON 类型都验证 JSON 语法：

- `json` 保存输入文本原样，保留无意义空白、对象键顺序和重复键文本，处理时需重新解析；
- `jsonb` 保存分解后的二进制表示，不保留空白、对象键顺序或重复键，只保留重复键最后值，处理通常更快并支持索引。

官方文档建议多数应用优先 jsonb，除非确实需要保留原始文本细节。

```sql
'{"firmware":"1.2.3","calibration":{"offset":0.2}}'::jsonb
```

jsonb 不保证输出键顺序。若签名/审计要求原始字节，另存原始文档并定义规范化策略，不能依赖 jsonb 文本复原。

## 7. SQL NULL 与 JSON null 完全不同

```sql
SELECT NULL::jsonb;      -- SQL NULL：整个列值不存在
SELECT 'null'::jsonb;    -- 一个非 SQL-NULL 的 JSON 标量
SELECT '{}'::jsonb;      -- 空 JSON 对象
```

三者业务含义不同。固定 `vendor_metadata` 允许 SQL NULL 或对象，不允许 JSON 数组/标量：

```sql
vendor_metadata jsonb,
CONSTRAINT device_vendor_metadata_object_check
CHECK (
  vendor_metadata IS NULL
  OR jsonb_typeof(vendor_metadata) = 'object'
)
```

`'null'::jsonb` 的 `jsonb_typeof` 是 `null`（文本结果），不是 object，因此被拒绝。

## 8. JSONB 合法语法不等于合法业务结构

以下都是合法 JSONB：

```json
42
null
[]
{"firmware":"1.2.3"}
{"location_id":"L-01","technician_id":"T-01"}
```

类型只能保证 JSON 语法；CHECK 可保证顶层 object，却不能自动保证每个键、格式、引用与版本。

因此要区分：

- 语法合法；
- 形状合法；
- 业务合法；
- 关系完整。

高价值规则应提升为普通列、domain、CHECK、UNIQUE 或 FK。

## 9. JSONB 的合适边界

适合 `vendor_metadata` 的键：

- 厂商特有 firmware 字段；
- 不同设备类别差异大的校准参数；
- 相对低频查询、随设备整体更新的小文档；
- 缺失键有明确默认/兼容解释。

不适合藏入 JSONB：

- location_id、owner_id、technician_id 等核心关联；
- status、serial_number 等高频筛选与强约束字段；
- 需要独立权限、并发更新或生命周期的子实体；
- 每次查询都抽取并 cast 的事实。

官方 JSON 设计建议文档代表业务上难以再合理细分、整体修改的原子 datum；大 JSON 更新仍锁整行。

## 10. JSONB 查询与索引不证明建模正确

```sql
vendor_metadata @> '{"firmware":"1.2.3"}'::jsonb
vendor_metadata ? 'calibration'
```

jsonb 支持 containment、existence，并可用 GIN。能索引不表示应把关系塞进去：

- JSON 内的 technician_id 没有普通 FK；
- 键拼错会变成另一个键；
- 更新路径更复杂；
- 应用需反复抽取/cast；
- 文档整体行锁边界更大。

先选正确模型，再在索引章节测量计划。

## 11. PostgreSQL 数组的基本形态

```sql
ARRAY['pump-east', 'pump-a']::text[]
'{pump-east,pump-a}'::text[]
```

数组元素共享同一元素类型。可用下标、切片、`ANY`、重叠/包含等操作。默认下界通常为 1，但 PostgreSQL 能表示其他下界；不要把所有外部数组都想当然当 JavaScript 的零下标。

声明：

```sql
search_aliases text[]
```

写 `text[5]` 不会强制长度 5。PostgreSQL 18 当前实现忽略声明的数组大小与维度限制，它们只是文档。要限制必须 CHECK。

## 12. NULL 数组、空数组与 NULL 元素

```text
NULL::text[]               整个数组缺失
ARRAY[]::text[]            数组存在，元素数 0
ARRAY['a', NULL]::text[]   数组存在，第二元素缺失
ARRAY['NULL']::text[]      文本 "NULL"，不是 SQL NULL
```

业务必须决定它们是否不同。本章 `search_aliases` 允许 NULL 和空数组，但不允许 NULL 元素。

```sql
CHECK (
  search_aliases IS NULL
  OR (
    cardinality(search_aliases) <= 5
    AND array_position(search_aliases, NULL) IS NULL
  )
)
```

还可决定是否允许重复、空字符串、大小写变体；类型不会替你决定集合语义。

## 13. 有界数组的使用条件

本章只把 `search_aliases` 放数组，因为：

- 最多 5 个，有 CHECK；
- 元素没有独立元数据；
- 不被其他表引用；
- 随 device 整体增删；
- 查询只是辅助匹配，不是核心关系。

如果后来每个 alias 需要语言、来源、审核状态或唯一性，它已经有独立事实，应迁移为子表。

## 14. 数组不是集合或关系表

官方数组文档直接提示：arrays are not sets；大量搜索数组元素可能是建模错误，单独表更易查询并更可扩展。

FactoryCare 核心标签：

```sql
CREATE TABLE factorycare.tag (
  tag_code text PRIMARY KEY,
  display_name text NOT NULL
);

CREATE TABLE factorycare.device_tag (
  device_id uuid REFERENCES factorycare.device(device_id),
  tag_code text REFERENCES factorycare.tag(tag_code),
  PRIMARY KEY (device_id, tag_code)
);
```

这能做 FK、标签重命名/元数据、去重和按标签连接。无界 `tags text[]` 难以保持这些不变量。

## 15. domain：给基础类型加可复用语义

```sql
CREATE DOMAIN factorycare.asset_code AS text
  CONSTRAINT asset_code_format_check
  CHECK (VALUE ~ '^SN-[0-9]{3}$');
```

使用：

```sql
serial_number factorycare.asset_code
  NOT NULL UNIQUE
```

domain 把格式规则和类型名复用到多列。`VALUE` 代表被检查值。CHECK 对 NULL 通常得到 NULL 并通过，所以本章仍在列上写 NOT NULL；不要只靠 domain 推断必填。

domain 是 PostgreSQL schema 对象，会增加跨数据库迁移映射。只有真正跨多列共享稳定语义时才值得使用；单列一次性规则可直接列 CHECK。

## 16. enum：静态、有序、类型安全的值集

```sql
CREATE TYPE factorycare.device_lifecycle AS ENUM (
  'ACTIVE',
  'MAINTENANCE',
  'RETIRED'
);
```

enum 拒绝未列标签；不同 enum 类型不能直接比较；排序按 CREATE TYPE 列出的业务顺序，不按字母。

PostgreSQL 可 ADD VALUE、RENAME VALUE，但已有值不能直接删除，排序也不能在不重建类型时任意改变。因此 enum 适合真正静态、有内在顺序且 PostgreSQL 绑定可接受的集合。

## 17. 为什么固定模型没选 enum 做工作流状态

FactoryCare 状态可能随业务演化，需要部署顺序、历史兼容和跨服务/跨库接口。当前选择：

```sql
status text NOT NULL,
CHECK (status IN ('ACTIVE','MAINTENANCE','RETIRED'))
```

优点：约束可在表迁移中替换，导出到其他数据库较直观。代价：类型安全弱于 enum，不同状态列仍都是 text。

若状态有显示名、终态标志、排序权重、启停时间等元数据，应选择参考表与 FK，而不是不断扩充 enum。

这不是“enum 不好”，而是演化/可移植性维度下的明确决定。

## 18. 完整 FactoryCare 类型模型

```sql
CREATE DOMAIN factorycare.asset_code AS text
  CONSTRAINT asset_code_format_check
  CHECK (VALUE ~ '^SN-[0-9]{3}$');

CREATE TABLE factorycare.device (
  device_id uuid DEFAULT uuidv7(),
  serial_number factorycare.asset_code NOT NULL,
  status text NOT NULL,
  vendor_metadata jsonb,
  search_aliases text[],

  CONSTRAINT device_pkey PRIMARY KEY (device_id),
  CONSTRAINT device_serial_number_key UNIQUE (serial_number),
  CONSTRAINT device_status_check
    CHECK (status IN ('ACTIVE', 'MAINTENANCE', 'RETIRED')),
  CONSTRAINT device_vendor_metadata_object_check
    CHECK (
      vendor_metadata IS NULL
      OR jsonb_typeof(vendor_metadata) = 'object'
    ),
  CONSTRAINT device_search_aliases_check
    CHECK (
      search_aliases IS NULL
      OR (
        cardinality(search_aliases) <= 5
        AND array_position(search_aliases, NULL) IS NULL
      )
    )
);
```

另建 tag/device_tag 关系表承载核心标签。

## 19. 每种类型的合法、NULL、非法矩阵

| 类型/用途 | 合法 | NULL | 非法/拒绝原因 |
| --- | --- | --- | --- |
| uuid PK | 标准 UUID | PK 拒绝 | `not-a-uuid` 类型输入错误 |
| asset_code | SN-001 | 列 NOT NULL 拒绝 | BAD-1 domain CHECK |
| jsonb metadata | object | SQL NULL 接受 | JSON null/array 违反 object CHECK |
| text[] aliases | 0—5 个非 NULL 元素 | 接受 | 6 个或含 NULL 元素违反 CHECK |
| status text+CHECK | ACTIVE | NOT NULL 拒绝 | BROKEN CHECK 拒绝 |
| enum 示例 | 列出的标签 | 由列 NULL 决定 | 未列标签类型输入拒绝 |

验证报告必须区分失败发生在类型输入、domain、列 NOT NULL、CHECK、UNIQUE 还是 FK。

## 20. 显式 cast 与未知字面量

SQL 字符串字面量开始可能是 unknown，PostgreSQL 根据上下文解析：

```sql
'a0ee...'::uuid
'{}'::jsonb
ARRAY['a','b']::text[]
'SN-001'::factorycare.asset_code
```

在测试/迁移中显式 cast 能让预期类型清楚。应用参数应让驱动绑定正确数据库类型，避免所有参数都当 text 后依赖隐式转换。

cast 能转换不表示语义合理：UUID→text 丢失原生类型接口，JSONB→text 再 LIKE 查询绕过结构操作符。

## 21. 失败一：高频关联数据塞 JSONB

坏模型：

```json
{
  "location_id":"L-01",
  "technician_id":"T-01",
  "firmware":"1.2.3"
}
```

location/technician 高频连接、需引用完整性和独立更新。把它们留在 JSONB 导致：

- 普通 FK 无法直接保护路径；
- 拼错键静默并存；
- JOIN 前要抽取/cast；
- 权限与索引更复杂；
- 更新任一路径仍锁整个设备行。

修复：location_id、technician/assignment 建普通列/关系，vendor firmware 留 JSONB。

## 22. 失败二：无界标签数组

坏模型 `tags text[]` 从 2 个长到数百，标签需显示名、停用、全局唯一和被多设备复用。此时数组的“少建一张表”变成约束债务。

第一证据：元素基数分布、按标签查询频率、重复/拼写变体、是否需要 FK/元数据。若任一元素已成为独立实体，迁移 tag/device_tag。

修复后用复合 PK 防同设备重复标签，用 FK 防未知标签。

## 23. 失败三：不可迁移的 enum 变更

需求：删除旧标签、重新排序、不同服务先后部署、未来支持其他数据库。PostgreSQL enum 不能直接删除已有值或任意重排。

诊断不是强行 cast text，而是重新评估：

- 静态集合且顺序有意义：保留 enum，设计迁移；
- 只需有限校验且经常变：text+CHECK；
- 值有元数据/启停：参考表+FK；
- 多数据库：记录每个平台映射与迁移测试。

## 24. 可移植性报告

| 选择 | PostgreSQL 绑定 | 迁移策略 |
| --- | --- | --- |
| uuid | 多数数据库有等价类型但函数不同 | 应用生成或平台函数适配 |
| jsonb | PostgreSQL 操作符/GIN 特有 | 映射目标 JSON 类型与查询 |
| text[] | 数组支持差异大 | 子表或序列化迁移 |
| domain | schema 级自定义类型语法不同 | 展开为基础类型+CHECK |
| enum | DDL/演化语义不同 | text+CHECK/参考表 |
| 关系表 | SQL 核心更可移植 | 保留 PK/FK 语义 |

“可能迁移”不要求放弃全部 PostgreSQL 优势，但必须把绑定列入成本和回滚。

## 25. 决策诊断顺序

1. 写一行/一个值代表什么；
2. 列强制规则：格式、范围、唯一、引用、NULL；
3. 列核心查询、更新粒度、集合基数；
4. 判断内部元素是否独立事实；
5. 比较 native/domain/enum/JSONB/array/关系表；
6. 写合法、SQL NULL、内部 null、非法值；
7. 写演化操作：新增、删除、重命名、拆分；
8. 写可移植性和真实验证计划。

不要先问“哪个类型性能最好”；没有查询和数据分布，性能结论无证据。

## 26. 四类离线资产

```sh
./examples/encyclopedia/ch.data.postgresql-types/verify.sh
./labs/encyclopedia/ch.data.postgresql-types/verify.sh
./exercises/encyclopedia/ch.data.postgresql-types/verify.sh
./solutions-private/encyclopedia/ch.data.postgresql-types/verify.sh
```

- examples：DDL、类型矩阵、决策矩阵；
- labs：高频 JSON 关联、无界数组、enum 演化故障；
- exercises：故意逃避关系建模的红色决策；
- solutions-private：约束明确、可移植性已记录的参考答案。

oracle 验证固定字符串/结构决策，不执行 PostgreSQL cast。

## 27. 120 秒复述

> native uuid 让数据库解析、比较 128 位身份，PostgreSQL 18 可生成 v4/v7，但仍要主键唯一。jsonb 验证 JSON 并支持结构操作，不保留空白、键顺序或重复键；SQL NULL 与 JSON null 不同。JSONB 适合随设备整体维护的小型可扩展厂商属性，不适合核心 FK、状态和高频关系。数组适合小型、有界、无独立身份的同类型值；声明 text[5] 不强制长度，NULL 数组、空数组、NULL 元素不同，数组也不是集合。domain 复用基础类型规则，列仍单独声明 NOT NULL；enum 是静态有序类型，但值不能直接删除/重排。FactoryCare 用 UUID 身份、JSONB 厂商属性、有界 alias 数组、标签关系表、状态 text+CHECK，并记录 PostgreSQL 绑定与迁移策略。

## 28. 官方主来源与版本边界

- [PostgreSQL 18 UUID Type](https://www.postgresql.org/docs/18/datatype-uuid.html) 与 [UUID Functions](https://www.postgresql.org/docs/18/functions-uuid.html)；
- [PostgreSQL 18 JSON Types](https://www.postgresql.org/docs/18/datatype-json.html)；
- [PostgreSQL 18 Arrays](https://www.postgresql.org/docs/18/arrays.html)；
- [PostgreSQL 18 Enumerated Types](https://www.postgresql.org/docs/18/datatype-enum.html)；
- [PostgreSQL 18 CREATE DOMAIN](https://www.postgresql.org/docs/18/sql-createdomain.html)。

稳定核心是按事实、约束、查询、演化选择类型。版本相关面是 uuidv7、JSONB/数组操作符、domain/enum DDL、索引与 cast 解析。真实 PostgreSQL 18 尚未验证。
