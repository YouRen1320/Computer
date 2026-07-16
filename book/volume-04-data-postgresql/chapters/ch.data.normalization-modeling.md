---
schema_version: 2
edition: 2026.2-draft
id: ch.data.normalization-modeling
title: 函数依赖、规范化与关系模式设计
responsibility: 教授把业务事实分解为低冗余关系模式，不把所有查询性能问题归因于反规范化
volume: '04'
order: 11
level: L1
status: drafting
path: book/volume-04-data-postgresql/chapters/ch.data.normalization-modeling.md
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
  text: 在 120 秒内解释函数依赖、规范化与关系模式设计的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - data-functional-dependency
  - data-normalization
  covers_topics:
  - data.functional-dependency
  - data.update-anomaly
  - data.candidate-key
  - data.first-second-third-normal-form
  - data.relation-decomposition
  - data.denormalization-tradeoff
  uses_capabilities:
  - data.relational-schema
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：把含技师、设备、工单重复字段的宽表按函数依赖分解到 3NF，并写出无损连接与键说明
  covers_topic_groups:
  - data-functional-dependency
  - data-normalization
  covers_topics:
  - data.functional-dependency
  - data.update-anomaly
  - data.candidate-key
  - data.first-second-third-normal-form
  - data.relation-decomposition
  - data.denormalization-tradeoff
  uses_capabilities:
  - data.relational-schema
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 从更新异常、插入异常和删除异常反例定位错误依赖，修正分解且不凭空增加实体
  covers_topic_groups:
  - data-functional-dependency
  - data-normalization
  covers_topics:
  - data.functional-dependency
  - data.update-anomaly
  - data.candidate-key
  - data.first-second-third-normal-form
  - data.relation-decomposition
  - data.denormalization-tradeoff
  uses_capabilities:
  - data.relational-schema
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 函数依赖、规范化与关系模式设计

> 本章状态为 `drafting`。关系理论属于稳定核心；PostgreSQL **18** 的键、唯一与外键语义于 **2026-07-17** 按官方文档核对。本机无 PostgreSQL server/`psql`，资产以固定 CSV 和 Ruby 2.6 兼容 oracle 验证依赖、异常、分解和无损重建；PASS **不证明 PostgreSQL 已执行 DDL/JOIN，也不证明真实性能**。

## 1. 规范化是在决定“一行代表一个什么事实”

把所有字段塞进一张宽表，SELECT 可能暂时方便，却会让同一设备名、序列号、技师电话在每张工单重复。重复不是单纯浪费空间；它让一个事实有多个可写副本。

本章固定目标：

> 从含工单、设备、技师重复字段的宽表发现函数依赖，分解为 3NF 的 device、technician、work_order，并证明原事实可无损重建。

规范化不是“表越多越专业”，而是：

```text
识别业务事实
→ 找决定关系（函数依赖）
→ 找最小唯一标识（候选键）
→ 将不同事实放入各自关系
→ 用主外键保持关联
→ 验证无损连接和依赖可执行
```

### 完成标准

你应能：

- 用 `X → Y` 读写函数依赖，并区分业务规则与样例巧合；
- 区分超键、候选键、主键与非键属性；
- 从宽表演示更新、插入、删除三类异常；
- 解释 1NF、2NF、3NF 各排除哪类依赖问题；
- 把固定 FactoryCare 宽表分解为三张关系；
- 为每个非键属性指出它依赖的正确候选键；
- 证明分解无损，而不是只说“JOIN 能跑”；
- 区分无损连接与依赖保持；
- 识别错误依赖和有损分解产生的伪行；
- 只有在测量证据、同步规则和校验机制齐全时讨论反规范化。

本章不做 BCNF/4NF/5NF 证明、规范化自动算法、仓库星型模型或生产迁移发布。

## 2. 固定 FactoryCare 宽表

`work_order_wide`：

| work_order_id | device_id | serial_number | device_name | technician_id | technician_name | technician_phone | summary | order_status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| W-01 | D-01 | SN-001 | East Pump | T-01 | Lin | 18800000001 | Inspect vibration | OPEN |
| W-02 | D-01 | SN-001 | East Pump | T-02 | Chen | 18800000002 | Replace seal | IN_PROGRESS |
| W-03 | D-02 | SN-002 | South Compressor | T-01 | Lin | 18800000001 | Change oil | DONE |

看起来一行是一张工单，但其中混入三类事实：

- 工单事实：summary、order_status、关联的设备/技师；
- 设备事实：serial_number、device_name；
- 技师事实：technician_name、technician_phone。

重复值只是线索。真正的分解依据是业务决定关系。

## 3. 函数依赖：一个属性集决定另一个属性集

写作：

```text
X → Y
```

读作：在该关系的所有合法状态中，只要两行 X 相同，它们的 Y 必须相同。

固定业务规则：

```text
work_order_id → device_id, technician_id, summary, order_status
device_id → serial_number, device_name
serial_number → device_id
technician_id → technician_name, technician_phone
```

`work_order_id → device_name` 也可由传递推得：工单决定 device_id，device_id 决定 device_name。但这不表示 device_name 应存进工单关系。

函数依赖不是因果关系、计算公式或当前三行碰巧一致。三行中所有 `order_status` 都不同，不能推断 `order_status → work_order_id` 是长期业务规则。

## 4. 如何证伪一个错误依赖

有人观察首行后声称：

```text
device_id → technician_id
```

D-01 的 W-01 是 T-01，W-02 是 T-02；同一 device_id 对应两个 technician_id，固定数据立即证伪。

重要边界：

- 反例一对即可证明依赖不成立；
- 没找到反例不能单靠样例证明依赖成立；
- 依赖成立需要业务合同、唯一约束或权威定义；
- 时间变化也要考虑：今天一台设备只有一个技师，不代表历史上永远如此。

诊断时先按决定项 GROUP BY 并找多个不同被决定值：

```sql
SELECT device_id
FROM work_order_wide
GROUP BY device_id
HAVING COUNT(DISTINCT technician_id) > 1;
```

固定结果 D-01，说明不能把 technician_id 移到 device 表。

## 5. 键：唯一还不够，必须最小

超键能唯一标识一行。`{work_order_id}` 是超键，`{work_order_id, summary}` 也是，但后者多了不必要属性。

候选键是最小超键：去掉任何属性就不再能唯一标识。宽表的候选键是 `work_order_id`。选择其中一个候选键作为 PRIMARY KEY，其他候选键通常用 UNIQUE 表达。

分解后：

```text
device:     candidate keys = device_id, serial_number
technician: candidate key  = technician_id
work_order: candidate key  = work_order_id
```

“当前数据没有重复”不等于候选键。姓名可能重复，电话可能换号，summary 更会重复；是否能作为键取决于业务身份合同。

主属性是属于某个候选键的属性；非主属性不属于任何候选键。理解 2NF/3NF 时需要这个区别。

## 6. 更新异常：同一事实有多个副本

把 D-01 名称改为 `East Pump A`，宽表必须同时更新 W-01、W-02。若只改一行：

```text
W-01 D-01 East Pump A
W-02 D-01 East Pump
```

数据库无法回答 D-01 到底叫什么。错误不是 UPDATE 语法，而是 `device_id → device_name` 的事实被复制到每张工单。

分解后 device 只有一行 D-01；名称只改一处，所有连接结果自然看到同一值。

## 7. 插入异常：没有载体就无法记录事实

新技师 T-03 已入职，但尚无工单。宽表的一行以 `work_order_id` 为键；若没有虚构工单，就没有地方记录 T-03 名称和电话。

错误替代：

- 创建 `W-TEMP` 假工单污染业务；
- 允许大量工单列 NULL，使一行不再明确代表工单；
- 把技师存在性绑在首张工单上。

分解后可独立插入 technician(T-03, ...)，不需要凭空增加实体。

## 8. 删除异常：删除一件事，意外丢掉另一件事

W-03 是 D-02 唯一工单。删除 W-03 时，宽表也失去 SN-002、South Compressor 这些设备事实。业务只要求删除工单，却顺带“删除”了设备知识。

分解后删除 work_order W-03，不删除 device D-02。外键删除策略还可阻止错误父行删除。

三类异常共同根因：不同生命周期的事实共用一行存储。

## 9. 第一范式（1NF）：关系的每个属性取一个域值

面向初学者的操作规则：

- 一列有声明的域/类型；
- 一行一组同构属性；
- 不用 `phone1, phone2, phone3` 重复列组；
- 不在一个 text 中用逗号拼多个本应独立关联的值。

“原子”取决于业务操作边界。PostgreSQL 数组和 JSONB 本身是一个合法类型值，但它们不会自动使内部业务事实满足良好关系建模。若需要对每个标签做外键、独立更新和连接，标签应成为关联表行，而不是因为数组“一个单元格”就宣称问题解决。

宽表每个格子当前是单值，可视为满足本章操作性 1NF；它仍有高阶依赖问题。

## 10. 第二范式（2NF）：非键属性依赖完整候选键

2NF 建立在 1NF 上，排除非主属性对候选键真子集的部分依赖。只有复合候选键时才会出现典型部分依赖。

例：

```text
work_order_skill(
  work_order_id,
  skill_code,
  work_order_summary,
  skill_name,
  required_level
)
candidate key = (work_order_id, skill_code)
```

若：

```text
work_order_id → work_order_summary
skill_code → skill_name
(work_order_id, skill_code) → required_level
```

summary 只依赖键的一部分 work_order_id，skill_name 只依赖另一部分 skill_code，违反 2NF。分为 work_order、skill、work_order_skill。

固定宽表候选键只有单列 work_order_id，没有真子集可形成部分依赖，所以它可满足 2NF，却仍不满足 3NF。

## 11. 第三范式（3NF）：非键事实不经另一个非键事实转决定

教学简化：每个非键属性应依赖“键、整个键，且只依赖键”，不要通过另一个非键属性传递依赖。

宽表：

```text
work_order_id → device_id → serial_number, device_name
work_order_id → technician_id → technician_name, technician_phone
```

device_name 和 technician_phone 对工单键是传递依赖，违反 3NF。

形式化 3NF 条件：对每个非平凡函数依赖 `X → A`，至少满足 X 是超键，或 A 是主属性。这个定义处理多候选键边界；零基础诊断先使用传递依赖图。

3NF 不等于“每张表只能三个列”，数字指范式层级。

## 12. 按依赖分解到三张表

```text
device(
  device_id PK,
  serial_number UNIQUE NOT NULL,
  device_name NOT NULL
)

technician(
  technician_id PK,
  technician_name NOT NULL,
  technician_phone NOT NULL
)

work_order(
  work_order_id PK,
  device_id FK → device.device_id,
  technician_id FK → technician.technician_id,
  summary NOT NULL,
  order_status NOT NULL
)
```

每个关系一行语义：一台设备、一位技师、一张工单。没有凭空添加 Location、Team、Skill 等当前输入未表达的实体。

所有非键属性的决定项：

```text
device_id → serial_number, device_name
technician_id → technician_name, technician_phone
work_order_id → device_id, technician_id, summary, order_status
```

## 13. PostgreSQL 18 约束映射

```sql
CREATE TABLE factorycare.device (
  device_id text PRIMARY KEY,
  serial_number text UNIQUE NOT NULL,
  device_name text NOT NULL
);

CREATE TABLE factorycare.technician (
  technician_id text PRIMARY KEY,
  technician_name text NOT NULL,
  technician_phone text NOT NULL
);

CREATE TABLE factorycare.work_order (
  work_order_id text PRIMARY KEY,
  device_id text NOT NULL REFERENCES factorycare.device(device_id),
  technician_id text NOT NULL REFERENCES factorycare.technician(technician_id),
  summary text NOT NULL,
  order_status text NOT NULL
);
```

PRIMARY KEY/UNIQUE 执行候选键，FOREIGN KEY 执行引用存在性，NOT NULL 执行本章必填合同。约束不会自动发现所有函数依赖，例如 device_id→device_name 必须通过表边界和键建模。

## 14. 无损连接：分开后必须能准确拼回

重建查询：

```sql
SELECT
  w.work_order_id,
  w.device_id,
  d.serial_number,
  d.device_name,
  w.technician_id,
  t.technician_name,
  t.technician_phone,
  w.summary,
  w.order_status
FROM factorycare.work_order AS w
JOIN factorycare.device AS d
  ON d.device_id = w.device_id
JOIN factorycare.technician AS t
  ON t.technician_id = w.technician_id
ORDER BY w.work_order_id;
```

固定预言：输入宽表 3 行，重建 3 行，完整列值逐项相同，无缺行、无额外行、无重复。

“能写 JOIN”不够。错误连接键也能返回结果；必须比较完整行多重集合和键基数。

## 15. 二元分解的无损判据直觉

把关系 R 分成 R1、R2 时，共享属性若能函数决定 R1 或 R2 的其余属性，连接通常可无损恢复。

例如分出 device：

```text
R1=device(device_id, serial_number, device_name)
R2=work_order-side(work_order_id, device_id, ...)
intersection={device_id}
device_id → R1 全部属性
```

device_id 是 device 的键，所以每个 work_order.device_id 最多匹配一台设备；不会凭空组合多个设备名。

## 16. 有损分解与伪行

错误分解：

```text
work_order_device(work_order_id, device_id)
device_technician(device_id, technician_id)
```

对 D-01：W-01/T-01、W-02/T-02 原本是两组配对。分开后只保留 W-01/W-02 都属于 D-01，以及 T-01/T-02 都服务过 D-01。再按 device_id JOIN 得四行：

```text
W-01 T-01  原事实
W-01 T-02  伪行
W-02 T-01  伪行
W-02 T-02  原事实
```

丢失的是“哪张工单分给哪位技师”的配对事实。正确 work_order 必须保留 technician_id。

## 17. 无损连接与依赖保持是两项测试

无损：连接分解关系能还原原关系，不多不少。

依赖保持：原有重要函数依赖能在单张分解表的约束中检查，或由分解后依赖推导，不必每次跨表 JOIN 才判断。

固定 3NF 分解同时保持核心依赖：设备依赖在 device，技师依赖在 technician，工单依赖在 work_order。外键保持关联。

某些更高范式分解可能无损但不保持全部依赖，需要权衡；本章不展开算法证明。

## 18. SQL 表不是自动的数学集合

关系理论通常把关系视作元组集合；SQL 查询默认可保留重复行。若分解表漏主键/唯一约束，两个完全相同设备行可让 JOIN 扩张。

所以验证包含：

- 每表候选键唯一；
- 外键列指向唯一父键；
- 重建行数与完整值；
- 不用无根据 DISTINCT 掩盖重复。

`SELECT DISTINCT` 能隐藏最终重复，却不能修复底层多个可写副本。

## 19. 不凭空增加实体

规范化依赖已有业务事实，不是看到名词就建表。固定输入没有 Location 的独立 ID、属性和生命周期，不能凭“East”猜出 location 表；没有 Team 规则，也不能造 team_id。

何时新增实体：

- 有独立身份或候选键；
- 有独立属性/生命周期；
- 被多个事实引用；
- 业务明确需要独立约束与操作。

无法证明时记录为待确认建模问题，不把猜测写进 canonical schema。

## 20. 反规范化不是规范化失败后的默认补丁

反规范化有意复制或缓存可推导数据，以换取经过测量的读取收益。例如在 work_order 保存 `device_name_snapshot` 可能有两种完全不同语义：

- 若表示创建工单当时名称，它是历史快照事实，不一定是冗余；
- 若表示当前设备名缓存，它是冗余副本，必须同步。

任何反规范化决策至少记录：

```text
被复制事实与权威来源
具体慢查询/计划/数据量证据
写入与同步机制
允许陈旧窗口
失败检测与修复任务
回滚为规范化读取的路径
```

没有 EXPLAIN/测量，只说“JOIN 慢”不是证据。PostgreSQL 能高效执行有正确键和索引的连接；真实性能留给索引/EXPLAIN 章节。

## 21. 三类异常的前后对照

| 操作 | 宽表 | 3NF |
| --- | --- | --- |
| 改 D-01 名称 | 改两行，可能不一致 | device 改一行 |
| 新增无工单 T-03 | 无处存或造假工单 | technician 独立插入 |
| 删除 W-03 | 丢失 D-02 唯一设备事实 | 只删 work_order |

验证不仅看最终表数，还要重放这三种业务变化。

## 22. 诊断错误分解的顺序

1. 写每张表“一行代表什么”；
2. 列出业务给定的函数依赖；
3. 对每表找候选键及所有非键属性；
4. 找部分/传递依赖；
5. 用固定数据找错误依赖反例；
6. 分解后检查主外键；
7. 完整重建并比较行多重集合；
8. 重放插入、更新、删除异常；
9. 单列任何反规范化项及证据。

第一处偏离优先：若 `device_id → technician_id` 已被反例推翻，不先调整 JOIN；若依赖正确但重建多两行，检查键和有损分解。

## 23. 常见误解

| 误解 | 修正 |
| --- | --- |
| 表多就是 3NF | 需按依赖、键、无损性证明 |
| 当前值一致就证明 FD | 样例只能证伪，规则需业务依据 |
| 单列主键后一定 3NF | 单列键只让典型部分依赖消失，仍可有传递依赖 |
| 每个名词都建表 | 只有独立事实/身份才建模 |
| JOIN 能返回行就无损 | 必须无伪行、无缺行且完整值相同 |
| DISTINCT 能修复分解 | 它掩盖重复，不恢复丢失依赖 |
| JSON/数组算一个值就总是 1NF 好设计 | 类型原子性不替代业务关系约束 |
| 为性能先反规范化 | 先要计划、测量、同步与回滚证据 |

## 24. 四类离线资产

```sh
./examples/encyclopedia/ch.data.normalization-modeling/verify.sh
./labs/encyclopedia/ch.data.normalization-modeling/verify.sh
./exercises/encyclopedia/ch.data.normalization-modeling/verify.sh
./solutions-private/encyclopedia/ch.data.normalization-modeling/verify.sh
```

- examples：宽表分解、候选键与完整重建；
- labs：三类异常、错误依赖、有损分解与反规范化门槛；
- exercises：把 technician 错放 device 的红色 starter；
- solutions-private：三表 3NF 模型与同一重建预言。

oracle 是固定关系模型，不是 SQL 引擎。

## 25. 120 秒复述

> 函数依赖 X→Y 表示在所有合法状态中，相同 X 必须有相同 Y；样例反例能推翻依赖，样例一致不能独自证明它。候选键是最小超键。宽工单表中 work_order_id 决定工单字段，device_id 决定设备字段，technician_id 决定技师字段，因此设备和技师属性对工单键是传递依赖，产生更新、插入、删除异常。1NF 处理关系属性域和重复组，2NF 排除对复合候选键一部分的依赖，3NF 排除非键传递依赖。分成 device、technician、work_order 后，工单保留两个外键；按键 JOIN 必须逐行还原原宽表。若把工单—技师配对拆丢，会产生伪行。反规范化只在测量收益、权威来源、同步、校验和回滚都明确时采用。

## 26. 主来源与版本边界

- [E. F. Codd, A Relational Model of Data for Large Shared Data Banks](https://doi.org/10.1145/362384.362685)：关系模型原始主来源；
- [PostgreSQL 18 Constraints](https://www.postgresql.org/docs/18/ddl-constraints.html)：主键、唯一、外键与数据库不变量；
- [PostgreSQL 18 CREATE TABLE](https://www.postgresql.org/docs/18/sql-createtable.html)；
- [PostgreSQL 18 Table Basics](https://www.postgresql.org/docs/18/ddl-basics.html)。

稳定核心是函数依赖、候选键、异常、范式、无损与依赖保持。版本相关面是 PostgreSQL 18 的具体 DDL/约束执行和 SQL 多重集合行为。真实 server 与性能未验证。
