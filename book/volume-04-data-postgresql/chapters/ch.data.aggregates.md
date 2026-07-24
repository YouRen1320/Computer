---
schema_version: 2
edition: 2026.2-draft
id: ch.data.aggregates
title: 聚合、GROUP BY 与 HAVING
responsibility: 教授将多行归约为分组结果及组后过滤，不提前引入多表连接或窗口保留明细
volume: '04'
order: 5
level: L1
status: drafting
path: book/volume-04-data-postgresql/chapters/ch.data.aggregates.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.data.select-rowsets
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
  text: 在 120 秒内解释聚合、GROUP BY 与 HAVING的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - sql-aggregate
  - sql-group-having
  covers_topics:
  - sql.count-sum-average
  - sql.aggregate-null
  - sql.distinct-aggregate
  - sql.group-by
  - sql.having
  - sql.grouping-error
  uses_capabilities:
  - data.sql-query
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：统计 enabled 设备每类别数量与平均维修时长，用 WHERE 过滤行、GROUP BY 分组、HAVING 过滤组
  covers_topic_groups:
  - sql-aggregate
  - sql-group-having
  covers_topics:
  - sql.count-sum-average
  - sql.aggregate-null
  - sql.distinct-aggregate
  - sql.group-by
  - sql.having
  - sql.grouping-error
  uses_capabilities:
  - data.sql-query
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入未分组列、把 HAVING 写 WHERE 和 COUNT(column) 忽略 NULL 的差异，构造样例证明后修复，并把异常定位到第一处可信证据
  covers_topic_groups:
  - sql-aggregate
  - sql-group-having
  covers_topics:
  - sql.count-sum-average
  - sql.aggregate-null
  - sql.distinct-aggregate
  - sql.group-by
  - sql.having
  - sql.grouping-error
  uses_capabilities:
  - data.sql-query
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 聚合、GROUP BY 与 HAVING

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《SELECT、投影、过滤、NULL、排序与分页》](ch.data.select-rowsets.md)：独立完成聚合计算、分组与组过滤前，必须先具备「SELECT、投影、过滤、NULL、排序与分页」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。语义按 PostgreSQL **18.4** 官方文档于 **2026-07-17** 复核。当前机器没有可用 PostgreSQL server 或 `psql`；配套资产使用固定 CSV、静态 SQL 契约和 Ruby 2.6 兼容 oracle。离线 PASS 能证明样例分组、NULL 与阈值预言一致，**不能证明真实 PostgreSQL 已解析查询、选择相同类型或执行相同计划**。

## 1. 从“每行一个结果”到“每组一个结果”

前两章的 SELECT 和标量表达式都以明细行为中心。聚合改变了结果的一行代表什么：

```text
明细输入行
  → WHERE 先排除不参与统计的行
  → GROUP BY 按键把剩余行装进组
  → 聚合函数把每组的多个输入值归约为一个值
  → HAVING 排除不满足条件的组
  → SELECT 交付每组一行
  → ORDER BY 排列分组结果
```

例如，原来一行表示“一次设备维修观察”，聚合后的一行可以表示“一个设备类别的统计摘要”。这是信息压缩：摘要保留数量、总和、平均值等，但不再保留每条明细。

[PostgreSQL 18 聚合函数文档](https://www.postgresql.org/docs/18/functions-aggregate.html)把聚合定义为“从一组输入值计算一个结果”。窗口函数虽然也能计算聚合，却可以保留明细行；它属于后续章节，本章不能用窗口函数绕过分组心智模型。

### 完成标准

你应能：

- 先说清输入一行和输出一行分别代表什么；
- 区分 `COUNT(*)`、`COUNT(column)` 与 `COUNT(DISTINCT column)`；
- 解释 `SUM/AVG/MIN/MAX` 通常忽略 NULL，以及空输入的结果；
- 手算分组键，包括 NULL 分组键；
- 说明 select list 中非聚合表达式为何必须被分组；
- 区分 WHERE 的“组前行过滤”和 HAVING 的“组后过滤”；
- 构造阈值上下各一个组，证明 HAVING 不是装饰；
- 识别 DISTINCT 聚合与 SELECT DISTINCT 的不同作用域；
- 用总行数等于各组行数之和检查分组是否闭合；
- 不用 COALESCE 或 DISTINCT 掩盖未定义的业务规则。

本章只使用一个预建关系，不教授多表连接、子查询、CTE、窗口函数、ROLLUP/CUBE、索引或写操作。

## 2. FactoryCare 固定关系与行语义

练习关系名为 `factorycare.device_maintenance_sample`。它是教学用只读样例，一行表示：

> 一台设备的一次维修时长观察。

列：

| 列 | 含义 |
| --- | --- |
| `event_id` | 观察行唯一标识 |
| `device_id` | 设备标识；同一设备可以出现多次 |
| `category` | 设备类别；故障夹具允许 NULL |
| `enabled` | 该观察对应设备是否启用 |
| `duration_minutes` | 可用维修时长；NULL 表示未获得有效时长 |
| `technician_id` | 技师标识；可用于 distinct 输入演示 |

同一 D-01 有两次 pump 观察。因此：

- `COUNT(*)` 是观察行数；
- `COUNT(DISTINCT device_id)` 才是不同设备数；
- 二者都正确，但回答的是不同问题。

统计开始前必须写出量词。不要把列别名 `device_count` 随意贴在 `COUNT(*)` 上，否则结果能运行却口径错误。

## 3. 聚合函数的输入集合

常见形式：

```sql
COUNT(*)
COUNT(expression)
SUM(expression)
AVG(expression)
MIN(expression)
MAX(expression)
```

无 GROUP BY 时，所有通过 FROM/WHERE 的行形成一个隐式组。下面通常返回一行：

```sql
SELECT
  COUNT(*) AS row_count,
  AVG(s.duration_minutes) AS avg_duration_minutes
FROM factorycare.device_maintenance_sample AS s
WHERE s.enabled IS TRUE;
```

有 GROUP BY 时，每个不同分组键组合形成一个组：

```sql
SELECT
  s.category,
  COUNT(*) AS event_count
FROM factorycare.device_maintenance_sample AS s
WHERE s.enabled IS TRUE
GROUP BY s.category;
```

分组不保证输出顺序；需要稳定报告仍要 ORDER BY。

## 4. COUNT 的三个口径

### COUNT(*)

`COUNT(*)` 统计输入行，不看某一列是否 NULL：

```sql
COUNT(*) AS enabled_event_count
```

若一个组有三行，即使所有 duration 都是 NULL，结果仍为 3。

### COUNT(column)

`COUNT(duration_minutes)` 只统计该表达式非 NULL 的输入行：

```sql
COUNT(s.duration_minutes) AS duration_sample_count
```

sensor 组有两行但两个时长都是 NULL：

```text
COUNT(*)                 = 2
COUNT(duration_minutes)  = 0
```

这不是 PostgreSQL 丢行，而是两个计数口径不同。[官方聚合表](https://www.postgresql.org/docs/18/functions-aggregate.html)明确区分“输入行数”与“表达式非 NULL 的输入行数”。

### COUNT(DISTINCT column)

`COUNT(DISTINCT device_id)` 先对该聚合的非 NULL 输入去重，再计数：

```sql
COUNT(DISTINCT s.device_id) AS enabled_device_count
```

pump 组三条观察来自 D-01、D-01、D-02，所以 event_count=3，device_count=2。

这与：

```sql
SELECT DISTINCT category, device_id ...
```

不是同一层操作。前者只影响一个 aggregate 的输入；后者在整个 select list 计算后去掉重复结果行。

## 5. SUM、AVG、MIN、MAX 与 NULL

PostgreSQL 的常规 `SUM`、`AVG`、`MIN`、`MAX` 对非 NULL 输入计算：

```text
输入 duration: 30, 60, NULL
SUM             = 90
AVG             = 45
COUNT(duration) = 2
```

AVG 的分母不是 COUNT(*)，而是参与平均的非 NULL 值数。可以用以下不变量复核：

```text
AVG(duration) = SUM(duration) / COUNT(duration)
```

仅当 COUNT(duration)>0 且使用相容精度时成立。

若一组全部为 NULL，`AVG` 与 `SUM` 返回 NULL，不是 0；`MIN/MAX` 也为 NULL。零表示已知数值，NULL 表示没有可计算输入，二者不能无授权互换。

除 `count` 外，官方文档说明大多数常规聚合在没有输入行时返回 NULL。`COALESCE(SUM(...), 0)` 只有在产品合同明确“无输入视为零”时才正确。

### 输出类型也是合同

`SUM(integer)`、`SUM(bigint)`、`AVG(integer)` 的返回类型不必与输入完全相同；PostgreSQL 会为部分类型选择更宽或更精确的结果。不要根据示例显示猜 Java/JDBC 目标类型。真实集成测试应查看实际列类型。

## 6. 空输入与“空组”不是同一句话

无 GROUP BY：

```sql
SELECT COUNT(*), AVG(s.duration_minutes)
FROM factorycare.device_maintenance_sample AS s
WHERE s.category = 'does-not-exist';
```

概念上有一个隐式总组，输入为空；结果通常仍有一行：count=0、avg=NULL。

有 GROUP BY：

```sql
SELECT s.category, COUNT(*)
FROM factorycare.device_maintenance_sample AS s
WHERE s.category = 'does-not-exist'
GROUP BY s.category;
```

没有任何分组键出现，因此返回零行。初学者常把“一行 count=0”和“零结果行”混为一谈，客户端处理方式也可能不同。

## 7. GROUP BY：相同键组成一个组

`GROUP BY s.category` 把所有相同 category 的输入行放进同一组。分组键可以是多个表达式；只有全部键值相同才同组。

NULL 分组键也形成可观察的组。固定夹具有两行 category=NULL，它们被归到同一个 NULL 组。这里的分组语义不能用普通 `NULL = NULL` 的 WHERE 比较直觉替代。

稳定展示可写：

```sql
ORDER BY s.category ASC NULLS LAST
```

这样 NULL 组的位置明确。

### 分组改变列可见性

分组后，一个结果行代表一整个组。因此 select list 中每项必须回答：

- 它是分组键，所以组内只有一个键值；或
- 它被聚合成一个值。

合法：

```sql
SELECT s.category, COUNT(*)
FROM factorycare.device_maintenance_sample AS s
GROUP BY s.category;
```

错误：

```sql
SELECT s.category, s.device_id, COUNT(*)
FROM factorycare.device_maintenance_sample AS s
GROUP BY s.category;
```

一个 category 组可能有多个 device_id，数据库无法替你选择哪个。第一处可信证据是组内 D-01 与 D-02 同时存在，而不是背错误文本。

[PostgreSQL 18 GROUP BY 文档](https://www.postgresql.org/docs/18/queries-table-expressions.html#QUERIES-GROUP)说明，一般情况下未分组列只能出现在 aggregate 内。PostgreSQL 能在部分主键函数依赖场景推导列，但零基础查询应先写清每列归属，不能把优化规则当省略依据。

## 8. WHERE 在分组前过滤行

`WHERE s.enabled IS TRUE` 先去掉 disabled 行，剩余行才进入分组：

```sql
FROM factorycare.device_maintenance_sample AS s
WHERE s.enabled IS TRUE
GROUP BY s.category
```

它回答“哪些明细行参与统计”。如果禁用设备不应计入任何类别，就必须在这里排除。

WHERE 不能直接引用当前查询层的聚合结果：

```sql
-- 错误：WHERE 阶段尚未形成组计数
WHERE COUNT(DISTINCT s.device_id) >= 2
```

不能因为 SQL 文本中 WHERE 写在 GROUP BY 前后看起来都像条件，就把两个阶段互换。

## 9. HAVING 在聚合后过滤组

HAVING 回答“哪些统计组值得输出”：

```sql
GROUP BY s.category
HAVING COUNT(DISTINCT s.device_id) >= 2
```

固定样例中：

- pump：2 台不同设备，通过；
- compressor：2 台，通过；
- sensor：2 台，通过，即使平均时长为 NULL；
- NULL category：2 台，通过；
- valve：1 台，不通过。

阈值样例必须同时有通过和不通过组，否则测试只能证明查询能运行，不能证明边界方向写对。

HAVING 可以引用分组表达式，也可以引用聚合。虽然不涉及 aggregate 的条件有时也能写 HAVING，行级条件优先放 WHERE，让阶段和意图清晰。

## 10. 完整查询

```sql
SELECT
  s.category AS category,
  COUNT(*) AS enabled_event_count,
  COUNT(DISTINCT s.device_id) AS enabled_device_count,
  COUNT(s.duration_minutes) AS duration_sample_count,
  SUM(s.duration_minutes) AS total_duration_minutes,
  ROUND(AVG(s.duration_minutes), 2) AS avg_duration_minutes
FROM factorycare.device_maintenance_sample AS s
WHERE s.enabled IS TRUE
GROUP BY s.category
HAVING COUNT(DISTINCT s.device_id) >= 2
ORDER BY s.category ASC NULLS LAST;
```

逐阶段手算：

1. 从 12 行固定样例中保留 10 行 enabled；
2. 按 category 分成 compressor、pump、sensor、valve、NULL 五组；
3. 分别计算行数、不同设备数、非 NULL 时长数、总时长、平均时长；
4. HAVING 排除只有 1 台设备的 valve；
5. 按 category 排序并把 NULL 组放末尾。

完整分组（HAVING 前）的 event_count 之和必须等于 10。HAVING 后输出组的 event_count 之和为 9，因为 valve 那一组被有意排除。两种总和都正确，必须说明比较的阶段。

## 11. DISTINCT 聚合的边界

`COUNT(DISTINCT device_id)` 忽略 NULL device_id 并对非 NULL 值去重。若要对多列组合去重，PostgreSQL 聚合语法和行表达式需要明确书写；本章不扩展。

不要用 distinct 修复重复明细：

```sql
COUNT(DISTINCT duration_minutes)
```

这统计“不同的时长数”，不是维修次数。两个事件都恰好 30 分钟仍是两个事件。先定义量词，再决定 distinct 的输入。

PostgreSQL 还支持 aggregate 内部 `FILTER (WHERE ...)`，只把满足条件的行喂给该聚合；官方[聚合表达式语法](https://www.postgresql.org/docs/18/sql-expressions.html#SYNTAX-AGGREGATES)对此有定义。它适合一行同时展示多个条件计数，但本章主任务使用 WHERE/HAVING 建立阶段心智模型，不要求 FILTER。

## 12. 常见错误一：未分组列

故障：

```sql
SELECT s.category, s.device_id, COUNT(*)
...
GROUP BY s.category;
```

诊断顺序：

1. 说出输出一行代表 category 组；
2. 枚举 pump 组 device_id：D-01、D-01、D-02；
3. 证明 device_id 没有唯一组值；
4. 决定需求：按 category 统计就移除明细 id；按 category+device 统计就把 id 加进 GROUP BY；要设备数则用 COUNT(DISTINCT id)；
5. 重跑固定预言。

不能用 MIN(device_id) 随便挑一个值来消除错误，除非“最小 id”本身就是业务需求。

## 13. 常见错误二：把 HAVING 写进 WHERE

故障：

```sql
WHERE s.enabled IS TRUE
  AND COUNT(DISTINCT s.device_id) >= 2
```

第一处可信证据是逻辑阶段：WHERE 处理明细行时，类别组还不存在。修复：

```sql
WHERE s.enabled IS TRUE
GROUP BY s.category
HAVING COUNT(DISTINCT s.device_id) >= 2
```

不要把错误解释成“PostgreSQL 语法比较挑剔”；它保护了尚未定义的量词。

## 14. 常见错误三：COUNT(column) 被误称为总行数

sensor 两行的 duration 都为 NULL：

```text
COUNT(*)                2
COUNT(duration_minutes) 0
AVG(duration_minutes)   NULL
```

如果报告写 `COUNT(duration_minutes) AS event_count`，结果 0 会谎称没有事件。修复是选择正确表达式并给别名写清口径：

```sql
COUNT(*) AS enabled_event_count,
COUNT(duration_minutes) AS duration_sample_count
```

两列并排是很好的诊断证据。

## 15. 其他边界

### AVG(COALESCE(..., 0))

把未知时长填 0 会改变平均值。pump 的 30、60、NULL 原本平均 45；填零后平均 30。只有“缺失就是零分钟”有业务依据时才可这样做。

### HAVING 对 NULL aggregate

`HAVING AVG(duration_minutes) >= 60` 对全 NULL 的 sensor 组得到 UNKNOWN，因此组被排除。若产品要保留“无样本”组，需要显式写规则，不能把 UNKNOWN 当 false 后忘记它存在。

### ORDER BY aggregate alias

PostgreSQL 允许在 ORDER BY 使用输出别名，如 `ORDER BY enabled_device_count DESC`。为确定并列顺序，应再补稳定键。

### 聚合不是免费

全表 `COUNT(*)` 仍需按可见行语义处理，并不保证读取一个恒定元数据数字。性能结论必须来自后续真实数据和 EXPLAIN，不从小 CSV 外推。

## 16. 验证不变量

固定实验检查：

```text
enabled 总行数 = 所有 HAVING 前分组的 COUNT(*) 之和 = 10
非 NULL duration 总数 = 各组 COUNT(duration) 之和 = 6
pump SUM = 90，COUNT(duration)=2，AVG=45
sensor COUNT(*)=2，COUNT(duration)=0，SUM/AVG=NULL
空过滤无 GROUP BY → count=0、avg=NULL 的一行
空过滤有 GROUP BY → 0 行
HAVING >=2 → 四组通过，valve 一组失败
```

这些不变量比只比对一张输出表更能定位错误发生在哪个阶段。

## 17. 四类离线资产

```sh
./examples/encyclopedia/ch.data.aggregates/verify.sh
./labs/encyclopedia/ch.data.aggregates/verify.sh
./exercises/encyclopedia/ch.data.aggregates/verify.sh
./solutions-private/encyclopedia/ch.data.aggregates/verify.sh
```

- `examples`：正确查询与手算摘要；
- `labs`：空输入、NULL、闭合总数、HAVING 阈值及三种故障；
- `exercises`：故意包含未分组列、WHERE aggregate 和错误 count 口径，oracle 应拒绝；
- `solutions-private`：完整答案与固定通过输出。

oracle 不解析 SQL。它检查本任务关键结构，并独立对 CSV 分组。starter wrapper 在“按预期红灯”时退出 0，表示教学夹具正常，不表示 starter 答案正确。

## 18. 120 秒复述

1. 聚合把多行归约成一个组结果，GROUP BY 决定组；
2. WHERE 在组前筛行，HAVING 在组后筛组；
3. COUNT(*) 数行，COUNT(column) 数非 NULL，COUNT(DISTINCT column) 数不同非 NULL 值；
4. AVG/SUM 忽略 NULL，全 NULL 或空输入通常得到 NULL；
5. 无 GROUP BY 的 aggregate 有一个隐式总组；
6. 分组结果只能选择分组键或 aggregate；
7. NULL 分组键可形成一组；
8. HAVING 测试要有阈值上下两侧；
9. DISTINCT aggregate 只改变该函数输入，不等于 SELECT DISTINCT；
10. 失败反例是把 device_id 与 category 分组统计一起直接选择，因为一个 category 内没有唯一 device_id。

### 交付统计前的口径声明模板

一张可维护的统计表不应只交付 SQL，还应在标题或接口文档中回答：

```text
统计对象：设备、观察事件，还是非 NULL 时长样本？
输入范围：只含 enabled 行，截止时刻和时区是什么？
分组维度：category 为 NULL 时单独成组、排除，还是映射标签？
去重键：event_id、device_id，还是不去重？
NULL 规则：缺时长是否排除平均；无样本是否显示 NULL？
组后门槛：至少两台设备，门槛前后各有哪些固定样例？
排序规则：并列时用哪个稳定键？
```

例如“每类别设备数”必须明确写成“enabled 行内不同 device_id 数”，而不是让读者从 `COUNT(*)` 猜测。若两个报表使用同一个别名却有不同输入范围或 NULL 规则，即使 SQL 各自正确，它们也不能被当作同一指标比较。先冻结口径，再让 oracle 验证；修改口径时同步更新样例和预言。

## 19. 官方依据与未验证边界

- [PostgreSQL 18 Aggregate Functions](https://www.postgresql.org/docs/18/functions-aggregate.html)
- [PostgreSQL 18 GROUP BY 与 HAVING](https://www.postgresql.org/docs/18/queries-table-expressions.html#QUERIES-GROUP)
- [PostgreSQL 18 Aggregate Expressions](https://www.postgresql.org/docs/18/sql-expressions.html#SYNTAX-AGGREGATES)
- [PostgreSQL 18 SELECT](https://www.postgresql.org/docs/18/sql-select.html)

稳定核心是组、量词、NULL 输入和组前/组后过滤。版本敏感面包括返回类型、错误文本、计划、并行聚合和性能。真实 PostgreSQL 18.4 的语法、类型、NULL 展示和执行计划尚未验证；离线 oracle 只覆盖固定教学数据。
