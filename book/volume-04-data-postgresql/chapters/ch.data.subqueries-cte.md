---
schema_version: 2
edition: 2026.2-draft
id: ch.data.subqueries-cte
title: 子查询、CTE 与集合拆解
responsibility: 教授把复杂行集拆为可解释中间关系，不把 CTE 当作自动性能优化或递归万能工具
volume: '04'
order: 7
level: L1
status: drafting
path: book/volume-04-data-postgresql/chapters/ch.data.subqueries-cte.md
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
  text: 在 120 秒内解释子查询、CTE 与集合拆解的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - sql-subquery
  - sql-cte
  covers_topics:
  - sql.scalar-row-table-subquery
  - sql.exists
  - sql.correlated-subquery
  - sql.cte
  - sql.query-decomposition
  - sql.cte-materialization-boundary
  uses_capabilities:
  - data.sql-query
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 用 EXISTS 找有未完成工单的设备，并把类别聚合与筛选拆成命名 CTE，输出等价查询对照
  covers_topic_groups:
  - sql-subquery
  - sql-cte
  covers_topics:
  - sql.scalar-row-table-subquery
  - sql.exists
  - sql.correlated-subquery
  - sql.cte
  - sql.query-decomposition
  - sql.cte-materialization-boundary
  uses_capabilities:
  - data.sql-query
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入 NOT IN 遇 NULL、相关子查询引用错层和 CTE 中间集错误，检查每个行集后修复
  covers_topic_groups:
  - sql-subquery
  - sql-cte
  covers_topics:
  - sql.scalar-row-table-subquery
  - sql.exists
  - sql.correlated-subquery
  - sql.cte
  - sql.query-decomposition
  - sql.cte-materialization-boundary
  uses_capabilities:
  - data.sql-query
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 子查询、CTE 与集合拆解

> 本章状态为 `drafting`。语义按 PostgreSQL **18.4** 官方文档于 **2026-07-17** 复核。本机没有 PostgreSQL server 或 `psql`；资产用固定 CSV、静态 SQL 契约和 Ruby 2.6 兼容 oracle。离线 PASS 能证明固定集合与错误注入预言，**不能证明 PostgreSQL 已解析查询、折叠 CTE 或采用某个执行计划**。

## 1. 为什么需要再包一层查询

一个 SELECT 产生一个行集，这个行集又可以成为另一层查询的输入或条件：

```text
基础关系
  → 内层查询产生中间集合/单值/存在性
  → 外层查询消费它
  → CTE 给中间集合命名
  → 最终结果与每个阶段预言核对
```

子查询不是“高级 SQL 的括号技巧”，而是建立查询层级。CTE 也不是临时表的别名；它只在一条语句内给辅助查询命名。

本章的核心问题：

> 找出有未完成工单的设备，再按类别计数，只输出至少两台的类别；同时证明拆分前后集合一致。

### 完成标准

你应能：

- 区分标量、单行、表形子查询的形状合同；
- 用 EXISTS 表达“至少存在一行”，不因多匹配复制外层行；
- 识别相关子查询如何引用外层别名；
- 解释 IN/NOT IN 的 NULL 三值边界；
- 使用 NOT EXISTS 安全表达“没有匹配”；
- 将筛选、聚合、组后筛选拆成可单独运行的 CTE；
- 证明扁平查询和 CTE 查询结果集合一致；
- 说明 CTE 默认不保证物化或性能提升；
- 区分 MATERIALIZED/NOT MATERIALIZED 的优化边界；
- 不把递归 CTE 当所有层级问题的默认答案。

本章不教授 DML CTE、递归实现、执行计划调优或窗口分析。

## 2. 固定 FactoryCare 数据

设备：

```text
D-01 pump
D-02 pump
D-03 compressor
D-04 sensor
D-05 compressor
```

工单：

```text
W-01 D-01 OPEN
W-02 D-01 DONE
W-03 D-02 IN_PROGRESS
W-04 D-03 DONE
W-05 D-03 DONE
W-06 D-05 OPEN
```

未完成状态固定为 `OPEN` 或 `IN_PROGRESS`。因此正确设备集合是 D-01、D-02、D-05；类别计数为 pump=2、compressor=1；门槛至少两台后只剩 pump。

另有独立排除夹具包含 D-02 和 NULL，专门证明 NOT IN 的 NULL 边界。它不是生产外键表。

## 3. 子查询形状：先问几列几行

### 标量子查询

标量子查询必须返回一列、至多一行：

```sql
SELECT
  d.device_id,
  (
    SELECT COUNT(*)
    FROM factorycare.work_order AS w
    WHERE w.device_id = d.device_id
  ) AS work_order_count
FROM factorycare.device AS d;
```

COUNT 无 GROUP BY 时产生一行，所以每台设备得到一个数，包括 D-04 的 0。

[PostgreSQL 18 scalar subquery](https://www.postgresql.org/docs/18/sql-expressions.html#SQL-SYNTAX-SCALAR-SUBQUERIES)规定：零行时标量结果为 NULL；超过一行或超过一列是错误。

危险写法：

```sql
(SELECT w.work_order_id
 FROM factorycare.work_order AS w
 WHERE w.device_id = d.device_id)
```

D-01 有两行，会报多行错误。`LIMIT 1` 只有在“任意一行”或确定排序后的“第一行”确实符合需求时才是修复；不能用它隐藏形状错误。

### 表形子查询

放在 FROM 中的子查询产生关系，必须有查询层可引用的别名：

```sql
SELECT x.category, x.device_count
FROM (
  SELECT d.category, COUNT(*) AS device_count
  FROM factorycare.device AS d
  GROUP BY d.category
) AS x;
```

### 单行比较

行构造与单行子查询必须列数一致，且右侧不能超过一行。零行比较结果为 NULL。零基础主线先用标量、EXISTS 和命名 CTE。

## 4. EXISTS：只关心有没有行

```sql
SELECT
  d.device_id,
  d.category
FROM factorycare.device AS d
WHERE EXISTS (
  SELECT 1
  FROM factorycare.work_order AS w
  WHERE w.device_id = d.device_id
    AND w.status IN ('OPEN', 'IN_PROGRESS')
)
ORDER BY d.device_id;
```

对每个外层设备，内层查询寻找至少一张未完成工单：

- 有一行即可为 TRUE；
- 零行是 FALSE；
- 有两行仍只是 TRUE，不复制外层设备。

[PostgreSQL 18 subquery expressions](https://www.postgresql.org/docs/18/functions-subquery.html)说明 EXISTS 只依据是否返回至少一行，select list 通常不重要，所以习惯写 `SELECT 1`。

不要依赖 EXISTS 子查询完整执行或其中副作用；系统通常只需找到第一行。

## 5. 相关子查询：外层值进入内层

内层：

```sql
w.device_id = d.device_id
```

右侧 `d.device_id` 来自外层查询。对当前外层行，它在一次内层求值中像常量。这样的查询称为相关子查询。

相关不等于必然逐行慢。优化器可等价改写；性能必须看真实计划。语义上，先用“每个 d 对应哪些 w”理解。

### 别名遮蔽错误

故障：

```sql
WHERE w.device_id = w.device_id
  AND w.status IN ('OPEN', 'IN_PROGRESS')
```

条件只比较内层列自身。只要数据库存在任意未完成且 device_id 非 NULL 的工单，所有外层设备的 EXISTS 都可能为 TRUE。固定样例错误返回五台，而正确为三台。

修复必须明确一侧来自内层 w、一侧来自外层 d。避免内外层复用同一个别名。

## 6. IN 的集合成员语义

```sql
d.device_id IN (
  SELECT w.device_id
  FROM factorycare.work_order AS w
  WHERE w.status IN ('OPEN', 'IN_PROGRESS')
)
```

子查询必须返回一列。只要有一个相等值，IN 为 TRUE；空子集时为 FALSE。重复值不会让外层行重复。

若左值为 NULL，或没有相等值但右集合含 NULL，结果可能是 UNKNOWN。WHERE 只保留 TRUE。

EXISTS 与 IN 常可表达相同业务，但不是在所有 NULL、类型和相关条件下机械替换。选择能最直接表达量词的形式。

## 7. NOT IN 遇 NULL

排除集合：

```text
D-02
NULL
```

查询：

```sql
WHERE d.device_id NOT IN (
  SELECT e.device_id
  FROM factorycare.device_exclusion AS e
)
```

对 D-01：

```text
D-01 <> D-02 = TRUE
D-01 <> NULL = UNKNOWN
TRUE AND UNKNOWN = UNKNOWN
```

所以不是 TRUE，WHERE 丢弃。D-02 明确匹配，NOT IN 为 FALSE。结果可能一行都没有。

官方文档明确：若没有相等值但右侧至少一个 NULL，NOT IN 结果是 NULL，不是 TRUE。

### NULL-safe 的不存在表达

```sql
WHERE NOT EXISTS (
  SELECT 1
  FROM factorycare.device_exclusion AS e
  WHERE e.device_id = d.device_id
)
```

NULL 排除行不会与非 NULL device_id 等值匹配，故正确保留 D-01、D-03、D-04、D-05，仅排除 D-02。

如果业务把 NULL 视为特殊匹配，必须另外定义；NOT EXISTS 也不会替你决定业务 NULL 规则。

## 8. 空子集与多匹配

| 构造 | 子查询零行 | 子查询多行 |
| --- | --- | --- |
| 标量子查询 | NULL | 错误 |
| EXISTS | FALSE | TRUE |
| NOT EXISTS | TRUE | FALSE |
| IN | FALSE | 可正常比较 |
| NOT IN | TRUE（若确实空） | 逐项比较，NULL 可变 UNKNOWN |
| FROM 子查询 | 空关系 | 多行关系 |

诊断前先写这张形状表，能避免把错误归因于“数据库偶尔不稳定”。

## 9. CTE：给辅助查询命名

基本形式：

```sql
WITH unfinished_devices AS (
  SELECT ...
),
category_counts AS (
  SELECT ...
  FROM unfinished_devices
)
SELECT ...
FROM category_counts;
```

CTE 名在这条语句中像关系名。后一个 CTE 可引用前一个；最终查询引用需要的中间关系。语句结束后名称消失，不是 view、临时表或缓存。

好名称描述行语义：

- `unfinished_devices`：一行一台有未完成工单的设备；
- `category_counts`：一行一个类别及设备数。

避免 `tmp1`、`data2`，否则拆分并未增加可解释性。

## 10. 完整 CTE 查询

```sql
WITH unfinished_devices AS (
  SELECT
    d.device_id,
    d.category
  FROM factorycare.device AS d
  WHERE EXISTS (
    SELECT 1
    FROM factorycare.work_order AS w
    WHERE w.device_id = d.device_id
      AND w.status IN ('OPEN', 'IN_PROGRESS')
  )
),
category_counts AS (
  SELECT
    u.category,
    COUNT(*) AS device_count
  FROM unfinished_devices AS u
  GROUP BY u.category
)
SELECT
  c.category,
  c.device_count
FROM category_counts AS c
WHERE c.device_count >= 2
ORDER BY c.category;
```

每层合同：

```text
unfinished_devices = D-01 pump, D-02 pump, D-05 compressor
category_counts    = pump 2, compressor 1
final              = pump 2
```

## 11. 扁平等价查询

```sql
SELECT
  d.category,
  COUNT(*) AS device_count
FROM factorycare.device AS d
WHERE EXISTS (
  SELECT 1
  FROM factorycare.work_order AS w
  WHERE w.device_id = d.device_id
    AND w.status IN ('OPEN', 'IN_PROGRESS')
)
GROUP BY d.category
HAVING COUNT(*) >= 2
ORDER BY d.category;
```

固定输入上，两者都输出 pump=2。等价验证要比较：

- 列集合与类型意图；
- 行集合；
- NULL 规则；
- 确定排序（若交付顺序属于合同）。

CTE 版本不是因为“更高级”，而是中间集合需要独立命名和诊断。

## 12. 每个 CTE 可单独运行

调试第一层：

```sql
WITH unfinished_devices AS (...)
SELECT *
FROM unfinished_devices
ORDER BY device_id;
```

调试第二层：

```sql
WITH unfinished_devices AS (...),
category_counts AS (...)
SELECT *
FROM category_counts
ORDER BY category;
```

先证明最早错误层，再看最终结果。若 unfinished_devices 已经多出 D-03，后续 COUNT 正确也无法补救。

## 13. CTE 中间集故障

注入：

```sql
WHERE w.status = 'DONE'
```

错误中间集变成 D-01、D-03，最终类别完全不同。若只看最终“某类别计数”，容易误以为 GROUP BY 错；单独运行第一 CTE 立即看到状态规则反了。

诊断报告应记录：

```text
层名
输入关系
行语义
预计行数/键
实际固定结果
第一处差异
修复后重跑
```

## 14. CTE 与物化边界

CTE 不自动等于“先算好并存进临时表”。PostgreSQL 18 对非递归、无副作用的 SELECT：

- 父查询只引用一次时，默认可能折叠进父查询共同优化；
- 引用多次时，默认通常物化；
- `MATERIALIZED` 可强制分开计算；
- `NOT MATERIALIZED` 可允许合并，但可能重复计算。

[PostgreSQL 18 WITH 文档](https://www.postgresql.org/docs/18/queries-with.html)明确描述这些规则和代价。

因此不能声称：

- “CTE 一定更快”；
- “CTE 一定只执行一次”；
- “CTE 一定是优化屏障”；
- “NOT MATERIALIZED 总更快”。

这些是计划决策，必须在真实数据上 EXPLAIN。主线先按语义拆分，不为猜测性能扭曲结构。

## 15. MATERIALIZED 的两面

强制物化可能：

- 避免昂贵、稳定表达式重复计算；
- 固定一个中间关系供多处引用；
- 也可能阻止父层谓词下推，使系统处理大量无用行。

NOT MATERIALIZED 可能让每个引用只扫描需要部分，也可能让昂贵计算重复。选择要记录数据规模、引用次数、函数波动性和计划证据。

离线 CSV 无法验证物化或计划，资产只检查我们没有把 CTE 写成性能承诺。

## 16. 递归 CTE 的边界

`WITH RECURSIVE` 可表达层级遍历，由非递归起点、UNION/UNION ALL 和递归项组成。PostgreSQL 内部按工作表迭代求值。

递归查询还需要：

- 明确终止条件；
- 防止环；
- 控制深度和重复；
- 单独定义输出排序，不能依赖求值访问顺序。

本章责任是普通集合拆解，不实现设备树递归。看到“有多个步骤”不意味着需要 RECURSIVE；普通多个 CTE 已足够。

## 17. 相关子查询的性能边界

相关语义可想成“对每个外层行代入一次”，但不能据此断言物理执行 N 次。PostgreSQL 可能转换为半连接或其他计划。

写法选择先看：

- EXISTS 是否最准确表达存在；
- 外层是否需要右表列；
- 多匹配是否应复制外层行；
- NULL 规则；
- 索引与实际 EXPLAIN。

本章不做性能排行榜。

## 18. EXISTS、JOIN 与外层行基数

“设备是否至少有一张未完成工单”只需要布尔答案。EXISTS 的外层粒度天然保持“一台设备一行”：

```sql
SELECT d.device_id
FROM factorycare.device AS d
WHERE EXISTS (
  SELECT 1
  FROM factorycare.work_order AS w
  WHERE w.device_id = d.device_id
    AND w.status IN ('OPEN', 'IN_PROGRESS')
);
```

改成普通 JOIN 后，结果粒度变成“一次设备—工单匹配一行”：

```sql
SELECT d.device_id
FROM factorycare.device AS d
JOIN factorycare.work_order AS w
  ON w.device_id = d.device_id
WHERE w.status IN ('OPEN', 'IN_PROGRESS');
```

固定夹具恰好每台设备至多一张未完成工单，所以两段查询当前都列出三行；这只是数据巧合。只要给 D-01 再加一张 OPEN，JOIN 会输出两次 D-01，EXISTS 仍输出一次。

不能把外层 `DISTINCT` 当默认修复：

- 它可能掩盖本来就重复的设备主数据；
- 一旦 SELECT 增加工单列，两行不再相同；
- 它让读者先制造错误粒度，再猜哪些列可以去重；
- 去重需要额外工作，且不能表达“只关心是否存在”的意图。

如果业务既需要设备一行，又要某张工单的列，先定义“哪一张”：最早、最新、优先级最高，还是聚合后的集合。然后使用稳定排序的子查询、聚合或其他明确模型。不能用 EXISTS 凭空带出未定义的右表列。

行基数核对至少包含：外层设备 ID 是否唯一、内层每设备匹配数、最终设备 ID 是否重复。查询看起来简短不是证据，输入与输出键才是。

## 19. 标量子查询的三条诊断路径

标量位置的合同是“一列、至多一行”。出现故障时按形状分开处理。

### 超过一列

```sql
SELECT (
  SELECT w.work_order_id, w.status
  FROM factorycare.work_order AS w
  WHERE w.device_id = 'D-01'
);
```

标量槽位不能装两个字段。若需要一个复合值，必须显式选择复合类型或 JSON 等设计；零基础主线应把需要的列放在关系层，而不是强塞进标量。

### 超过一行

D-01 有 W-01、W-02 两行，直接选择 `work_order_id` 会失败。先问业务是否本来期待唯一：

- 若数据库合同规定每设备只能一张当前工单，应增加并验证相应唯一约束，并定位脏数据；
- 若本来允许多张，应改成 EXISTS、IN、聚合或表形子查询；
- 若要最新一张，应写完整 `ORDER BY created_at DESC, work_order_id DESC LIMIT 1`，并把“最新”纳入需求。

裸 `LIMIT 1` 不是通用修复，因为没有排序时哪一行被选中未定义。

### 零行

标量子查询返回 NULL，不是错误。后续表达式会继承 NULL 传播，例如 `NULL + 1` 仍是 NULL。是否 `COALESCE(..., 0)` 由业务决定：工单计数为零可用 COUNT 自然得到 0；“最新完成时间不存在”通常应保留 NULL，不能伪装成某个日期。

诊断记录要写清实际形状：返回列数、每个外层键对应行数、零行含义。只抄错误文本无法证明修复满足业务。

## 20. 相关层级、名称解析与可读性合同

每个 SELECT 都建立自己的名称作用域。内层可以读取自己的 FROM 项，也可以向外读取可见别名。名称解析会优先找到最近层级，因此复用模糊名字容易把“相关”悄悄改成“自比较”。

建议在相关查询中遵守：

```text
外层设备固定别名 d
内层工单固定别名 w
共享键两侧都写限定名
相关谓词必须肉眼出现 w... = d...
```

错误不仅有 `w.device_id = w.device_id`，还有引用业务上不对应的外层列：

```sql
WHERE w.assigned_team_id = d.category
```

它语法可能成立、类型也可能可比较，却不是设备关联键。静态检查能发现常见错层，但只有关系模型、键约束和固定结果断言能发现“列存在但业务键错误”。

审查相关子查询时逐句读成自然语言：

> 对当前设备 d，寻找工单 w，使 w 的 device_id 等于当前 d 的 device_id，且 w 状态属于未完成集合。

如果一句话里说不出哪一列来自当前外层行，相关条件很可能没有建立。

## 21. 三值逻辑的完整预测表

对非 NULL 左值 `x`，先根据右侧集合写预测：

| 右侧情况 | `x IN (subquery)` | `x NOT IN (subquery)` |
| --- | --- | --- |
| 空集合 | FALSE | TRUE |
| 至少一个值等于 x | TRUE | FALSE |
| 无相等值且全部非 NULL | FALSE | TRUE |
| 无相等值但含 NULL | UNKNOWN | UNKNOWN |

WHERE 只保留 TRUE，所以 UNKNOWN 在筛选效果上也被丢弃，但它不等于 FALSE。这个差异会在 `NOT`、布尔组合、CHECK 约束或直接 SELECT 出表达式时显现。

若左值本身是 NULL，普通等值比较不会成为 TRUE；IN/NOT IN 通常也得到 UNKNOWN，除非右侧为空时由空集合规则决定。不要把 NULL 当普通哨兵值。

EXISTS 不比较投影值，只看是否有行，所以子查询行里的 NULL 不会把 EXISTS 变成 UNKNOWN。NOT EXISTS 同样只是否定行存在性。这就是 nullable 排除集合通常优先写相关 NOT EXISTS 的原因：

```sql
WHERE NOT EXISTS (
  SELECT 1
  FROM factorycare.device_exclusion AS e
  WHERE e.device_id = d.device_id
)
```

如果源表合同保证 `e.device_id NOT NULL`，NOT IN 可以有清晰语义；仍应把该约束作为证据，而不是凭当前样例没有 NULL 推断。若在子查询里临时加 `WHERE e.device_id IS NOT NULL`，要说明这是业务认可的 NULL 忽略规则。

## 22. 给每个 CTE 写“行集合同”

把长 SQL分段只增加了名字，不一定增加理解。每个 CTE 在编码前写五项合同：

| 项目 | unfinished_devices | category_counts |
| --- | --- | --- |
| 一行代表 | 一台有未完成工单的设备 | 一个设备类别 |
| 候选键 | device_id | category |
| 输入 | device 与 work_order 存在关系 | unfinished_devices |
| NULL 规则 | device_id 非 NULL；状态只认两值 | category 的 NULL 是否单独成组需声明 |
| 固定预言 | D-01、D-02、D-05 | pump=2、compressor=1 |

再检查列最小化：第一层只输出后层确实需要的 `device_id, category`。随手 `SELECT *` 会把来源列变化传播到后层，增加同名列冲突，也让读者难以看出这一层的接口。

CTE 次序应反映数据依赖：筛出目标设备，按类别聚合，最后按聚合结果筛选。不要把最终阈值提前进第一层，因为那时还没有类别计数；也不要把未完成状态推迟到聚合后，否则计数粒度已经错。

命名 CTE 的可测试性来自可替换最终 SELECT：同一个 WITH 前缀后接 `SELECT * FROM unfinished_devices`。它不是独立持久对象，测试仍必须随原语句重放。

## 23. “拆分前后等价”到底比较什么

SQL 默认处理多重集合；相同值的两行可以同时存在。因此等价不能只比较截图里“看起来有 pump”。至少比较：

1. 列的业务含义、顺序和预期类型；
2. 每个完整结果行及其出现次数；
3. NULL 是否在相同位置；
4. 若顺序属于交付合同，最终 ORDER BY 是否一致；
5. 空输入、单匹配、多匹配和 nullable 数据的边界结果。

本章扁平版把 `COUNT(*) >= 2` 写在 HAVING，因为它筛分组；CTE 版先把计数命名成 `device_count`，外层 WHERE 再筛普通列。两个位置不同但阶段语义等价。

等价依赖前置合同：device_id 在 device 中唯一，EXISTS 不复制设备，category_counts 一类别一行。如果设备表有重复 ID，两种写法可能仍给相同错误答案；“彼此相等”不能证明“共同正确”。所以还必须对照独立手算预言 pump=2。

比较时不要用无 ORDER BY 的文本顺序做证据。关系结果没有天然展示顺序；本章两版都显式按 category 排序，才能稳定 diff。

## 24. 从症状到第一处可信证据

建议按以下层级调查，不跳层：

```text
0. 固定输入：5 台设备、6 张工单、排除集 D-02 + NULL
1. 相关存在集：D-01,D-02,D-05
2. 第一 CTE：同一三台及类别
3. 第二 CTE：compressor:1,pump:2
4. 最终阈值：pump:2
```

最终空结果可能来自 NOT IN + NULL、状态集合写错、相关条件错、阈值过高或数据为空。只盯最后一层无法区分。

每次故障注入都保存：破坏的最小 SQL 片段、运行所用固定数据、修改前预测、实际输出/错误、第一处偏离层、修复片段、修复后同一断言。不要只保存最终 PASS，因为它无法证明你观察过失败机制。

若第一层正确而第二层错误，调查 GROUP BY 输入列和重复行；若第一层已经错误，不要先调聚合。这个“最早偏离”原则比猜执行顺序更可靠。

## 25. 三个故障注入

### NOT IN + NULL

现象：预计排除 D-02，却得到空结果。第一证据是子查询含 NULL；修复为 NOT EXISTS 或在有充分合同下排除 NULL。

### 引用错层

现象：所有五台设备都被标为有未完成工单。第一证据是 `w.device_id=w.device_id` 没有外层 d；修复相关键。

### CTE 中间集错误

现象：最终类别不对。先运行 unfinished_devices，发现 DONE/unfinished 状态反了；修复最早错误层，再验证聚合。

## 26. 四类离线资产

```sh
./examples/encyclopedia/ch.data.subqueries-cte/verify.sh
./labs/encyclopedia/ch.data.subqueries-cte/verify.sh
./exercises/encyclopedia/ch.data.subqueries-cte/verify.sh
./solutions-private/encyclopedia/ch.data.subqueries-cte/verify.sh
```

- examples：EXISTS、标量计数、扁平/CTE 等价；
- labs：NULL/空/多匹配、错层和错误中间集；
- exercises：故意引用错层和筛错状态的红色 starter；
- solutions-private：正确 EXISTS 与两层 CTE。

oracle 不解析 SQL；它独立对固定 CSV 计算集合，并检查任务关键结构。

## 27. 120 秒复述

1. 子查询有形状合同：标量一列至多一行；
2. EXISTS 只看是否至少一行，多匹配不复制外行；
3. 相关子查询显式引用外层别名；
4. IN 空集为 false，NOT IN 遇右侧 NULL 可能 unknown；
5. 不存在匹配通常用 NOT EXISTS 表意更稳；
6. CTE 是一条语句内的命名辅助查询；
7. 每个 CTE 应有清楚行语义并可单独运行；
8. 扁平和拆分查询要比较集合等价；
9. CTE 不自动物化或提速；
10. MATERIALIZED/NOT MATERIALIZED 需要计划证据；
11. RECURSIVE 需要终止与环控制，不是普通步骤拆解；
12. 失败反例是 w.device_id=w.device_id 让相关条件失去外层关联。

## 28. 官方依据与未验证边界

- [PostgreSQL 18 Subquery Expressions](https://www.postgresql.org/docs/18/functions-subquery.html)
- [PostgreSQL 18 Scalar Subqueries](https://www.postgresql.org/docs/18/sql-expressions.html#SQL-SYNTAX-SCALAR-SUBQUERIES)
- [PostgreSQL 18 WITH Queries](https://www.postgresql.org/docs/18/queries-with.html)
- [PostgreSQL 18 SELECT](https://www.postgresql.org/docs/18/sql-select.html)

稳定核心是查询形状、存在量词、相关层级、NULL 与命名行集。版本敏感面是 CTE 折叠/物化规则、执行计划、类型和错误文本。真实 PostgreSQL 18.4 尚未验证。
