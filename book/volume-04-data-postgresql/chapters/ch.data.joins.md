---
schema_version: 2
edition: 2026.2-draft
id: ch.data.joins
title: INNER/OUTER JOIN、关系基数与重复行
responsibility: 教授按键组合多表并预测基数，不在本章用子查询或窗口函数隐藏连接错误
volume: '04'
order: 6
level: L1
status: drafting
path: book/volume-04-data-postgresql/chapters/ch.data.joins.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.data.aggregates
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
  text: 在 120 秒内解释INNER/OUTER JOIN、关系基数与重复行的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - sql-join-types
  - sql-join-cardinality
  covers_topics:
  - sql.inner-join
  - sql.left-right-full-join
  - sql.join-condition
  - sql.one-many-join
  - sql.join-duplicate-row
  - sql.missing-match-null
  uses_capabilities:
  - data.sql-query
  - data.relational-schema
  - data.sql-aggregate-join
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：连接设备、工单和技师，预测1:N基数并用 GROUP BY/HAVING 统计每技师工单数，同时保留有/无匹配行验证
  covers_topic_groups:
  - sql-join-types
  - sql-join-cardinality
  covers_topics:
  - sql.inner-join
  - sql.left-right-full-join
  - sql.join-condition
  - sql.one-many-join
  - sql.join-duplicate-row
  - sql.missing-match-null
  uses_capabilities:
  - data.sql-query
  - data.relational-schema
  - data.sql-aggregate-join
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入漏ON笛卡尔积、LEFT JOIN条件放WHERE变INNER和连接后直接COUNT导致重复计数，逐项修复
  covers_topic_groups:
  - sql-join-types
  - sql-join-cardinality
  covers_topics:
  - sql.inner-join
  - sql.left-right-full-join
  - sql.join-condition
  - sql.one-many-join
  - sql.join-duplicate-row
  - sql.missing-match-null
  uses_capabilities:
  - data.sql-query
  - data.relational-schema
  - data.sql-aggregate-join
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# INNER/OUTER JOIN、关系基数与重复行

> 本章状态为 `drafting`。语义按 PostgreSQL **18.4** 官方文档于 **2026-07-17** 复核。当前机器没有 PostgreSQL server 或 `psql`，配套资产只用固定 CSV 和 Ruby 2.6 兼容 oracle。它能证明样例键匹配、行数与 NULL 扩展预言，**不能证明真实 PostgreSQL 已解析 SQL、执行外连接或选择某个连接算法**。

## 1. JOIN 解决什么问题

关系模型把不同事实放在不同表：

- `device` 一行是一台设备；
- `work_order` 一行是一张工单；
- `technician` 一行是一位技师。

JOIN 在查询时按关系键组合这些事实。它不是“把表永久合并”，也不是“自动找相似文本”，而是建立一个新的表形结果：

```text
左侧行 × 右侧候选行
  → ON/USING 判断是否匹配
  → INNER 只保留匹配对
  → OUTER 还为指定一侧的未匹配行补 NULL
  → SELECT 投影结果列
```

一条连接结果的一行通常表示“一对满足条件的源行”，或“一条被外连接保留、另一侧为空的源行”。必须先说出这个行语义，才可能预测行数。

[PostgreSQL 18 table expressions](https://www.postgresql.org/docs/18/queries-table-expressions.html#QUERIES-JOIN)定义了 INNER、LEFT、RIGHT、FULL 及 ON/USING：一对行只有在连接条件为 true 时才匹配。

### 完成标准

你应能：

- 画出 device 1→N work_order、technician 1→N work_order 的方向；
- 在运行前枚举每个左侧键的匹配数并预测输出基数；
- 区分 INNER、LEFT、RIGHT、FULL 保留哪一侧；
- 解释未匹配侧为何出现 NULL；
- 用 ON 明确键与外连接匹配条件；
- 说明 USING 的列合并与 NATURAL JOIN 的 schema 漂移风险；
- 识别逗号 FROM/CROSS JOIN 产生的笛卡尔积；
- 解释 LEFT JOIN 后右表条件放 WHERE 为何会丢掉未匹配行；
- 区分合法 1:N 行倍增与真正重复/错误连接；
- 在 LEFT JOIN 分组时使用 `COUNT(right.id)` 得到零匹配；
- 不用 DISTINCT 掩盖基数错误。

本章不使用子查询、CTE、窗口函数、写操作或执行计划调优。连接算法、索引和性能留到后续章节。

## 2. FactoryCare 三个关系

### device

| device_id | category |
| --- | --- |
| D-01 | pump |
| D-02 | compressor |
| D-03 | sensor |
| D-04 | valve |

### work_order

| work_order_id | device_id | technician_id | status |
| --- | --- | --- | --- |
| W-01 | D-01 | T-01 | OPEN |
| W-02 | D-01 | T-02 | CLOSED |
| W-03 | D-02 | T-01 | OPEN |
| W-04 | D-04 | NULL | OPEN |

### technician

| technician_id | display_name |
| --- | --- |
| T-01 | Mei |
| T-02 | Arun |
| T-03 | Lin |

关键边界：

- D-01 有两张工单，所以连接后 D-01 会出现两行；
- D-03 没有工单；
- W-04 有设备但尚未分配技师，technician_id 为 NULL；
- T-03 没有工单。

这些不是脏数据。它们分别表达 1:N、可选关系和零匹配，是外连接必须覆盖的正常业务状态。

## 3. 连接条件是关系合同

最明确形式：

```sql
FROM factorycare.device AS d
JOIN factorycare.work_order AS w
  ON w.device_id = d.device_id
```

ON 是布尔表达式。只有结果为 TRUE 的行对匹配；FALSE 或 UNKNOWN 都不匹配。若任一键为 NULL，普通等值条件得到 UNKNOWN，因此不会互相匹配。

连接条件应来自数据模型：

- work_order.device_id → device.device_id；
- work_order.technician_id → technician.technician_id。

不要因为两个列都叫 `id` 就连接，也不要用 category、display_name 等非键字段“看起来相同”来猜关系。

### ON 与业务筛选

ON 可以同时包含键和“哪些右侧行算匹配”的规则：

```sql
LEFT JOIN factorycare.work_order AS w
  ON w.device_id = d.device_id
 AND w.status = 'OPEN'
```

这样每台设备仍由 LEFT 保留，只是关闭工单不算右侧匹配。

## 4. INNER JOIN：只保留匹配对

```sql
SELECT
  d.device_id,
  w.work_order_id
FROM factorycare.device AS d
INNER JOIN factorycare.work_order AS w
  ON w.device_id = d.device_id
ORDER BY d.device_id, w.work_order_id;
```

结果四行：

```text
D-01 W-01
D-01 W-02
D-02 W-03
D-04 W-04
```

D-03 消失，因为没有匹配工单。INNER 可省略，但教学和长期查询中显式写出有助于读者识别保留规则。

官方定义是：对左侧每行，为右侧每个满足条件的行产生一行。因此一个左键有两个匹配，就产生两行，不是“数据库重复了一行”。

## 5. LEFT JOIN：保留每个左侧行

```sql
SELECT
  d.device_id,
  w.work_order_id
FROM factorycare.device AS d
LEFT JOIN factorycare.work_order AS w
  ON w.device_id = d.device_id
ORDER BY d.device_id, w.work_order_id;
```

结果五行：

```text
D-01 W-01
D-01 W-02
D-02 W-03
D-03 NULL
D-04 W-04
```

LEFT 先产生匹配对，再为没有任何匹配的左行补一行，右侧列全部为 NULL。因此输出至少每个左行一行，但若有多个匹配可更多。

[PostgreSQL 18 JOIN 文档](https://www.postgresql.org/docs/18/queries-table-expressions.html#QUERIES-JOIN)明确说明 LEFT JOIN 为未匹配左行补右侧 NULL。

### NULL 是“无匹配”，不一定是源列本来 NULL

D-03 结果中的 w.work_order_id=NULL 是外连接生成的 NULL，表示不存在匹配工单。W-04 连接技师后的 t.technician_id=NULL 则可能同时反映源外键未分配。只看一个 NULL 显示无法知道来源，需结合保留侧和键列解释。

## 6. RIGHT JOIN：保留每个右侧行

`A RIGHT JOIN B` 与 `B LEFT JOIN A` 在保留方向上对称：

```sql
FROM factorycare.work_order AS w
RIGHT JOIN factorycare.device AS d
  ON w.device_id = d.device_id
```

仍保留所有 device，包括 D-03。RIGHT 在复杂查询中容易让阅读方向来回翻转；团队常通过交换表顺序改写为 LEFT。RIGHT 不是错误，但应以“哪一侧是必须保留的业务主体”选择可读方向。

## 7. FULL JOIN：两侧未匹配都保留

```sql
FROM factorycare.technician AS t
FULL JOIN factorycare.work_order AS w
  ON w.technician_id = t.technician_id
```

匹配部分：

- T-01 ↔ W-01、W-03；
- T-02 ↔ W-02。

未匹配：

- T-03 无工单，保留为 work_order 列 NULL；
- W-04 technician_id=NULL，无法与任何技师等值匹配，保留为 technician 列 NULL。

FULL 适合对账：“左边独有、右边独有、两边匹配”都要看。应用主路径若只需要一个主体，LEFT 通常更直观。

## 8. USING 与输出列

若两边连接列同名，可以：

```sql
device AS d
JOIN work_order AS w USING (device_id)
```

USING(device_id) 等价于对应等值条件，并在输出中合并这对同名连接列，而 JOIN ON 默认保留左右两列。投影 `*` 时差别尤其明显。

USING 适合键名确实相同且语义一致。若需要比较不同列名、附加状态条件或同时观察左右键，使用 ON 更清晰。

## 9. 为什么避免 NATURAL JOIN

NATURAL JOIN 自动把两表所有同名列放进连接条件。今天只有 device_id 同名时看似方便；明天两表都新增 `status`，连接条件会静默变成 device_id+status，结果可能骤减。

这种行为让 schema 变化改变查询语义却不改 SQL 文本。生产查询应显式 ON/USING，让代码审阅能看到合同。NATURAL 适合了解语法，不作为本章答案。

## 10. 基数预测：先列每个键的匹配数

对 device LEFT JOIN work_order：

| device | 右侧匹配数 | LEFT 输出行数 |
| --- | ---: | ---: |
| D-01 | 2 | 2 |
| D-02 | 1 | 1 |
| D-03 | 0 | 1（NULL 扩展） |
| D-04 | 1 | 1 |
| 合计 | 4 个真实匹配 | 5 |

通用公式：

```text
INNER 输出 = Σ 每个左行的匹配数
LEFT 输出  = Σ max(1, 每个左行的匹配数)
```

实际基数由数据和条件共同决定。关系约束提供上界：

- 右侧键唯一时，一个左行最多匹配一行；
- 右侧外键不唯一时，一个左行可匹配多行；
- 两侧连接列都不唯一时，某个键值会产生 m×n 行。

## 11. 1:1、1:N 与 N:M

### 1:1

若每个设备最多一条扩展资料，device_id 在右表唯一，一个设备最多匹配一行。LEFT 输出行数等于左表行数。

### 1:N

一台设备多张工单。父行按子行数量重复，这是正确的关系展开。D-01 两行分别对应 W-01、W-02。

### N:M

例如一张工单可有多个标签，一个标签可属于多张工单，通常由关联关系表示。JOIN 两段 1:N 后会产生每个关系实例一行。本章不新增这种表，但必须知道多段连接的倍增会叠加。

在运行前写出最小/最大或固定样例准确行数，是发现漏条件最快的方法。

## 12. 业务重复与错误重复

看到同一个 device_id 多次，不应立即 SELECT DISTINCT。

先比较结果每一行的完整业务键：

```text
D-01 + W-01
D-01 + W-02
```

两行代表不同工单，不是重复。

真正异常可能来自：

- 漏掉 tenant_id 等复合键条件；
- 连接到非唯一名称；
- 多接一张 1:N 表造成乘法；
- 源数据违反唯一性；
- 输出投影丢掉能区分行的子键，让不同事实看起来相同。

DISTINCT 只删除投影后相同行，可能把错误藏起来，还可能丢掉真实多个事实。先修复行语义和连接键。

## 13. 完整三表明细

```sql
SELECT
  d.device_id AS device_id,
  d.category AS category,
  w.work_order_id AS work_order_id,
  w.status AS work_order_status,
  t.technician_id AS technician_id,
  t.display_name AS technician_name
FROM factorycare.device AS d
LEFT JOIN factorycare.work_order AS w
  ON w.device_id = d.device_id
LEFT JOIN factorycare.technician AS t
  ON t.technician_id = w.technician_id
ORDER BY d.device_id, w.work_order_id;
```

五行预言：

```text
D-01 | pump       | W-01 | OPEN   | T-01 | Mei
D-01 | pump       | W-02 | CLOSED | T-02 | Arun
D-02 | compressor | W-03 | OPEN   | T-01 | Mei
D-03 | sensor     | NULL | NULL   | NULL | NULL
D-04 | valve      | W-04 | OPEN   | NULL | NULL
```

第一处 LEFT 保留无工单设备；第二处 LEFT 保留未分配技师工单。若第二处改 INNER，W-04 和其设备明细会从组合结果消失。

## 14. ON 与 WHERE：外连接最常见陷阱

需求：“列出所有设备及其 OPEN 工单，没有 OPEN 工单的设备也保留。”

正确：

```sql
FROM factorycare.device AS d
LEFT JOIN factorycare.work_order AS w
  ON w.device_id = d.device_id
 AND w.status = 'OPEN'
```

结果每台设备至少一行；D-03 右侧 NULL。

危险改写：

```sql
FROM factorycare.device AS d
LEFT JOIN factorycare.work_order AS w
  ON w.device_id = d.device_id
WHERE w.status = 'OPEN'
```

LEFT 先为 D-03 生成 w.status=NULL，随后 WHERE 的比较为 UNKNOWN，D-03 被删除。对该条件而言结果表现得像 INNER。

不是所有右表条件都必须放 ON。若需求本来就是“只看确实有 OPEN 工单的设备”，WHERE 可以正确。位置取决于是否保留无匹配主体。

## 15. 漏 ON 与笛卡尔积

故障写法：

```sql
FROM factorycare.device AS d,
     factorycare.work_order AS w
```

没有关系条件时，每台设备与每张工单组合：4×4=16 行，而正确 INNER 键匹配只有 4 行。

显式 `CROSS JOIN` 也产生笛卡尔积，但能表达有意的“所有组合”。逗号语法容易漏条件，主线查询优先显式 JOIN ... ON。

诊断：

1. 先比较预测 4 与实际 16；
2. 检查 FROM 中每个关系如何连接；
3. 写出键方向和 ON；
4. 再逐键枚举匹配数；
5. 不用 DISTINCT 把 16 行压回“看起来差不多”。

## 16. JOIN 后 COUNT 的两个陷阱

### LEFT JOIN 的 NULL 扩展行

每技师工单数：

```sql
SELECT
  t.technician_id,
  t.display_name,
  COUNT(w.work_order_id) AS work_order_count
FROM factorycare.technician AS t
LEFT JOIN factorycare.work_order AS w
  ON w.technician_id = t.technician_id
GROUP BY t.technician_id, t.display_name
ORDER BY t.technician_id;
```

结果 T-01=2、T-02=1、T-03=0。

若写 COUNT(*)，T-03 也得到 1，因为 LEFT 为它生成了一条 NULL 扩展结果行。要数右侧匹配，应数右侧非 NULL 主键。

### 多段 1:N 的乘法

device LEFT JOIN work_order 已让 D-01 出现两行。此时 `COUNT(*)` 是连接结果行数 5，不是设备数 4。若再连接每工单多个附件，工单也会重复。

选择：

- 数连接行：COUNT(*)；
- 数有匹配工单：COUNT(w.work_order_id)；
- 数不同设备：COUNT(DISTINCT d.device_id)；
- 数不同工单：COUNT(DISTINCT w.work_order_id)。

每个都可能正确，别名必须说明量词。

## 17. GROUP BY/HAVING 的技师统计

先保留有/无匹配：

```sql
SELECT
  t.technician_id,
  t.display_name,
  COUNT(w.work_order_id) AS work_order_count
FROM factorycare.technician AS t
LEFT JOIN factorycare.work_order AS w
  ON w.technician_id = t.technician_id
GROUP BY t.technician_id, t.display_name
ORDER BY t.technician_id;
```

再查询至少两张工单的组：

```sql
SELECT
  t.technician_id,
  t.display_name,
  COUNT(w.work_order_id) AS work_order_count
FROM factorycare.technician AS t
LEFT JOIN factorycare.work_order AS w
  ON w.technician_id = t.technician_id
GROUP BY t.technician_id, t.display_name
HAVING COUNT(w.work_order_id) >= 2
ORDER BY t.technician_id;
```

只有 T-01 通过。第一条证明 T-03=0 被保留；第二条证明 HAVING 阈值。

## 18. RIGHT/FULL 的对账边界

RIGHT 可以用交换顺序的 LEFT 表达，FULL 不能简单由一次 LEFT 代替。FULL 结果必须区分：

- 两边键均非 NULL：匹配；
- 左键非 NULL、右键 NULL：只在左；
- 左键 NULL、右侧标识非 NULL：只在右。

连接键本身允许 NULL 时，使用辅助非空主键判断来源更可靠。不要把外连接产生的 NULL 与业务列原有 NULL 混为一类。

## 19. USING/NATURAL 与 schema 演进

USING 会合并输出连接列，可能改变 `SELECT *` 的列数和顺序；NATURAL 会随新增同名列改变匹配条件。稳定接口应显式投影并选择 ON/USING。

这也是为什么本章所有证据都写：

```sql
d.device_id AS device_id,
w.work_order_id AS work_order_id
```

而不依赖星号列布局。

## 20. 三个故障的第一处可信证据

### 漏 ON

预测正确匹配 4 行，观察到 16 行；4×4 直接指向笛卡尔积。

### LEFT 条件放 WHERE

预测四台设备都保留，D-03 消失；检查 NULL 扩展行经过 WHERE 后的三值逻辑。

### 直接 COUNT

预测 T-03 工单数 0，COUNT(*) 却为 1；检查被计数的是连接行还是右表主键。预测设备数 4、连接行 5，也能暴露 1:N 倍增。

每次修复后重新列举固定行，不只看查询“没有报错”。

## 21. 四类离线资产

```sh
./examples/encyclopedia/ch.data.joins/verify.sh
./labs/encyclopedia/ch.data.joins/verify.sh
./exercises/encyclopedia/ch.data.joins/verify.sh
./solutions-private/encyclopedia/ch.data.joins/verify.sh
```

- `examples`：INNER、LEFT 三表、技师计数与 FULL 未匹配预言；
- `labs`：笛卡尔积 16、ON/WHERE 3 对 4、COUNT(*) 的错误 1；
- `exercises`：包含逗号连接、WHERE 右表条件和 COUNT(*) 的红色 starter；
- `solutions-private`：显式 ON、正确外连接条件与 COUNT(right.id) 答案。

oracle 独立按 CSV 键构造结果，不是 SQL 引擎。它验证固定基数和脚本契约，不验证 PostgreSQL planner、约束或类型。

## 22. 120 秒复述

1. JOIN 按条件产生源行配对；
2. INNER 只保留匹配，LEFT/RIGHT 保留指定侧，FULL 保留两侧；
3. 未匹配侧列由 outer join 补 NULL；
4. ON 只有 TRUE 才匹配，NULL 等值不匹配；
5. 一个父行匹配 N 个子行就产生 N 行，不一定是错误重复；
6. 预测基数要逐键列匹配数；
7. 条件放 ON 决定哪些右行算匹配，放 WHERE 会在连接后过滤；
8. 漏 ON 的 4×4 是 16 行笛卡尔积；
9. LEFT 分组数右侧匹配要 COUNT(right.id)，不用 COUNT(*)；
10. DISTINCT 不能修复错误键或掩盖真实多个工单；
11. USING 合并同名键列，NATURAL 会随 schema 漂移；
12. 失败反例是 D-03 在 LEFT 后因 WHERE w.status='OPEN' 被错误删除。

## 23. 官方依据与未验证边界

- [PostgreSQL 18 Joined Tables](https://www.postgresql.org/docs/18/queries-table-expressions.html#QUERIES-JOIN)
- [PostgreSQL 18 Joins Tutorial](https://www.postgresql.org/docs/18/tutorial-join.html)
- [PostgreSQL 18 GROUP BY/HAVING](https://www.postgresql.org/docs/18/queries-table-expressions.html#QUERIES-GROUP)
- [PostgreSQL 18 Aggregate Functions](https://www.postgresql.org/docs/18/functions-aggregate.html)
- [PostgreSQL 18 SELECT](https://www.postgresql.org/docs/18/sql-select.html)

稳定核心是键匹配、保留侧、NULL 扩展与基数乘法。版本敏感面包括错误文本、列类型解析、优化器的 nested loop/hash/merge 等物理算法和计划成本。真实 PostgreSQL 18.4、约束、索引与 EXPLAIN 尚未验证。
