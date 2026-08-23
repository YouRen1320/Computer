---
schema_version: 2
edition: 2026.2-draft
id: ch.data.window-functions
title: 窗口、分区、排序与分析函数
responsibility: 教授在保留明细行时计算分区分析结果，不用窗口函数替代正确连接和分组
volume: '04'
order: 8
level: L1
status: drafting
path: book/volume-04-data-postgresql/chapters/ch.data.window-functions.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.data.joins
- ch.data.subqueries-cte
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
  text: 在 120 秒内解释窗口、分区、排序与分析函数的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - sql-window-frame
  - sql-window-analysis
  covers_topics:
  - sql.window-partition-order
  - sql.window-frame
  - sql.window-vs-group
  - sql.row-number-rank
  - sql.lag-lead
  - sql.running-aggregate
  uses_capabilities:
  - data.sql-query
  - data.sql-aggregate-join
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 在保留每张工单明细的同时计算技师内 row_number、前后工单间隔和累计完成数
  covers_topic_groups:
  - sql-window-frame
  - sql-window-analysis
  covers_topics:
  - sql.window-partition-order
  - sql.window-frame
  - sql.window-vs-group
  - sql.row-number-rank
  - sql.lag-lead
  - sql.running-aggregate
  uses_capabilities:
  - data.sql-query
  - data.sql-aggregate-join
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入缺 PARTITION、窗口 ORDER 不确定和默认 frame 造成累计突跳，使用并列时间数据修复，并把异常定位到第一处可信证据
  covers_topic_groups:
  - sql-window-frame
  - sql-window-analysis
  covers_topics:
  - sql.window-partition-order
  - sql.window-frame
  - sql.window-vs-group
  - sql.row-number-rank
  - sql.lag-lead
  - sql.running-aggregate
  uses_capabilities:
  - data.sql-query
  - data.sql-aggregate-join
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 窗口、分区、排序与分析函数

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《INNER/OUTER JOIN、关系基数与重复行》](ch.data.joins.md)：独立完成窗口定义、分析函数前，必须先具备「INNER/OUTER JOIN、关系基数与重复行」已经验证的知识与失败边界
- [《子查询、CTE 与集合拆解》](ch.data.subqueries-cte.md)：独立完成窗口定义、分析函数前，必须先具备「子查询、CTE 与集合拆解」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。语义按 PostgreSQL **18.4** 官方文档于 **2026-07-17** 复核。本机没有 PostgreSQL server 或 `psql`；配套资产用固定 CSV、静态 SQL 契约和 Ruby 2.6 兼容 oracle。离线 PASS 能证明手算行集和故障预言，**不能证明 PostgreSQL 已解析查询、执行时间达标或采用某个计划**。

## 1. 既保留明细，又回答“在组内哪里”

普通聚合回答“每组一行”：每位技师共有多少张工单。窗口分析回答“每张明细旁边再附上组内信息”：这张工单是该技师的第几张、距离前一张多久、下一张是什么、截至当前完成了几张。

本章固定任务是：

> 每张工单仍占一行；在技师自己的时间序列中编号，计算前后间隔，并给出累计完成数。

查询的数据流可以先记成：

```text
FROM / JOIN / WHERE 形成可信明细行集
  → PARTITION BY 把行分给各技师
  → 窗口 ORDER BY 定义组内先后
  → frame 定义“当前计算看哪些行”
  → 窗口函数给每张明细附加分析列
  → 最终 ORDER BY 决定展示顺序
```

窗口函数不是修复错误 JOIN 的工具。若连接已经把一张工单复制三次，窗口看到的就是三行，并会诚实地给三行编号。

### 完成标准

你应能：

- 解释窗口为何保留明细行，而 GROUP BY 会折叠行；
- 分开说明 `PARTITION BY`、窗口 `ORDER BY` 与 frame 的职责；
- 用稳定的唯一 tiebreaker 处理并列时间；
- 区分 `row_number`、`rank` 与 `dense_rank`；
- 用 `lag`、`lead` 读取相邻工单并计算时间间隔；
- 用显式 `ROWS` frame 写逐行累计；
- 预测默认 `RANGE` frame 在 peers 上为何“提前跳”；
- 证明输出行数等于可信明细行数、每个分区编号从 1 开始；
- 按第一处可信证据诊断缺分区、不稳定排序与错误 frame。

本章不教授复杂统计分布、百分位优化、超大分区内存调优、并行计划或业务时区建模。

## 2. 固定 FactoryCare 工单

本章所有例子使用六张工单：

| 工单 | 技师 | 创建时间 UTC | 状态 |
| --- | --- | --- | --- |
| W-01 | T-01 | 2026-07-01 09:00 | CREATED |
| W-02 | T-01 | 2026-07-01 09:00 | CLOSED |
| W-03 | T-01 | 2026-07-01 10:00 | CLOSED |
| W-04 | T-02 | 2026-07-01 08:00 | CLOSED |
| W-05 | T-02 | 2026-07-01 09:30 | CREATED |
| W-06 | T-02 | 2026-07-01 09:30 | CLOSED |

两个技师各三行。W-01/W-02 时间并列，W-05/W-06 也并列，这是故意设计的故障放大器。业务规定同一时间按 `work_order_id` 升序，因此完整顺序为：

```text
T-01: W-01 → W-02 → W-03
T-02: W-04 → W-05 → W-06
```

先手算累计完成数：

```text
T-01: W-01=0, W-02=1, W-03=2
T-02: W-04=1, W-05=1, W-06=2
```

如果查询输出不是六行、某技师第一行不是序号 1、W-01 已累计为 1，先不要怪 `SUM`；逐层检查输入行、分区、排序和 frame。

## 3. GROUP BY 与窗口不是两种写法，而是两种结果形状

每位技师一行：

```sql
SELECT
  w.technician_id,
  COUNT(*) AS work_order_count
FROM factorycare.work_order AS w
GROUP BY w.technician_id
ORDER BY w.technician_id;
```

六行折叠为两行。原来的工单 ID、单张状态和创建时间不再天然存在；若把它们放进 SELECT，就必须聚合或加入 GROUP BY。

每张工单保留，同时附组内总数：

```sql
SELECT
  w.work_order_id,
  w.technician_id,
  COUNT(*) OVER (PARTITION BY w.technician_id) AS technician_order_count
FROM factorycare.work_order AS w
ORDER BY w.technician_id, w.work_order_id;
```

输出仍是六行，T-01 的三行都附 3，T-02 的三行也都附 3。[PostgreSQL 18 窗口教程](https://www.postgresql.org/docs/18/tutorial-window.html)明确区分：普通聚合把一组行合成单行，窗口函数让每行保持自己的身份。

选择规则很简单：

- 业务答案本来就是“一组一行”，先用 GROUP BY；
- 业务答案要求“每张明细旁边的组内指标”，用窗口；
- 同一查询可以先 GROUP BY 得到阶段行集，再对阶段结果做窗口，但必须说清窗口看到的是哪一层粒度。

## 4. 窗口表达式的三个边界

基本形态：

```sql
window_function(arguments) OVER (
  PARTITION BY ...
  ORDER BY ...
  ROWS BETWEEN ... AND ...
)
```

### PARTITION BY：谁和谁一起计算

`PARTITION BY technician_id` 把六行分成 T-01 与 T-02 两个独立分区。函数在每个分区重新开始。省略它不是“自动按业务键分组”，而是把全部输入行当成一个分区。

### 窗口 ORDER BY：分区内部的逻辑顺序

`ORDER BY created_at, work_order_id` 决定哪一行叫前一行、后一行、第一行，并参与 frame 边界。它不保证最终结果显示顺序。

### frame：当前这一行计算时能看见哪些行

frame 是分区的一个滑动子集。对逐行累计，通常希望“分区开头到当前物理行”：

```sql
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
```

`PARTITION BY` 决定池子，窗口 `ORDER BY` 排池子，frame 决定当前函数从池子里取多少。三者不能互相代替。

## 5. PARTITION 缺失：编号不会重置

正确编号：

```sql
ROW_NUMBER() OVER (
  PARTITION BY w.technician_id
  ORDER BY w.created_at, w.work_order_id
) AS technician_sequence
```

T-01 得 1、2、3；T-02 也得 1、2、3。

故障：

```sql
ROW_NUMBER() OVER (
  ORDER BY w.created_at, w.work_order_id
)
```

现在所有工单只有一个全局序列：W-04 是 1，W-01 是 2，W-02 是 3，W-05 是 4，W-06 是 5，W-03 是 6。若最终展示再按技师排序，看上去 T-01 的第一行从 2 开始；第一处可信证据是“每个技师的最小序号是否为 1”，不是页面上某个偶然位置。

有时全局序列确实是业务需求。关键是主动声明粒度：是“全站第几张”，还是“该技师第几张”。

## 6. 窗口排序必须把并列变成稳定全序

仅写：

```sql
ORDER BY w.created_at
```

W-01 与 W-02 的先后没有被业务规则确定。数据库可以在允许的计划中返回任一顺序；表当前物理排列、某次执行碰巧稳定或最终输出看起来一致，都不是合同。

修复：

```sql
ORDER BY w.created_at, w.work_order_id
```

`work_order_id` 在夹具中唯一，于是分区内每两行都能比较出确定先后。生产查询应使用真正稳定且唯一的键，例如 `(created_at, work_order_id)`；不要用可能重复的标题或状态充当 tiebreaker。

窗口排序与最终排序是两个不同位置：

```sql
SELECT ...,
       ROW_NUMBER() OVER (
         PARTITION BY technician_id
         ORDER BY created_at, work_order_id
       ) AS technician_sequence
FROM ...
ORDER BY technician_id, created_at, work_order_id;
```

内层排序定义计算语义，末尾排序定义展示合同。只写窗口排序，不承诺输出按该顺序呈现；只写最终排序，也不能修正已经算错的 `row_number` 或 `lag`。

## 7. row_number、rank 与 dense_rank

[PostgreSQL 18 窗口函数表](https://www.postgresql.org/docs/18/functions-window.html)给出三种常见编号：

- `row_number()`：分区当前行从 1 开始的编号，每行不同；
- `rank()`：同一 peer group 同名次，下一名会留下间隔；
- `dense_rank()`：同一 peer group 同名次，下一名不留间隔。

若窗口只按 `created_at` 排序，T-01 的时间组是 09:00、09:00、10:00：

| 工单 | rank | dense_rank |
| --- | ---: | ---: |
| W-01/W-02 | 1 | 1 |
| W-03 | 3 | 2 |

`row_number` 仍会给并列两行 1 与 2，但哪张拿哪个值没有被该窗口排序确定。加入 `work_order_id` 后每行不再是 peer，三种函数在固定样例上都成为 1、2、3；这并不意味着三者语义相同。

选择问题：

- “第几条记录”通常用 row_number，并给唯一全序；
- “成绩并列名次且后面跳号”用 rank；
- “有几档不同值”常用 dense_rank；
- 不要因为输出样例恰好无并列就把它们互换。

## 8. lag 与 lead：相邻不是自连接的唯一解

取前后工单：

```sql
LAG(w.work_order_id) OVER (
  PARTITION BY w.technician_id
  ORDER BY w.created_at, w.work_order_id
) AS previous_work_order_id,
LEAD(w.work_order_id) OVER (
  PARTITION BY w.technician_id
  ORDER BY w.created_at, w.work_order_id
) AS next_work_order_id
```

`lag(value)` 默认回看一行，分区第一行没有前一行，结果为 NULL；`lead(value)` 默认向后一行，分区末行没有后一行，结果为 NULL。可提供 offset 和 default，但默认值必须符合业务，不能用 0 掩盖“没有相邻行”。

计算间隔：

```sql
w.created_at
  - LAG(w.created_at) OVER (
      PARTITION BY w.technician_id
      ORDER BY w.created_at, w.work_order_id
    ) AS since_previous,
LEAD(w.created_at) OVER (
  PARTITION BY w.technician_id
  ORDER BY w.created_at, w.work_order_id
) - w.created_at AS until_next
```

固定预言：

```text
T-01: W-01 previous=NULL, W-02 since_previous=0, W-03 since_previous=1h
T-02: W-04 previous=NULL, W-05 since_previous=1h30m, W-06 since_previous=0
```

零间隔不是错误，它证明两个不同工单共享时间戳且由 ID 打破并列。若先后业务应由另一个字段决定，应修改排序合同，而不是过滤掉零间隔。

## 9. 累计聚合：聚合函数加 OVER

把 CLOSED 映射为 1，其他状态映射为 0：

```sql
CASE WHEN w.status = 'CLOSED' THEN 1 ELSE 0 END
```

逐行累计：

```sql
SUM(CASE WHEN w.status = 'CLOSED' THEN 1 ELSE 0 END) OVER (
  PARTITION BY w.technician_id
  ORDER BY w.created_at, w.work_order_id
  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
) AS completed_so_far
```

这里 `SUM` 没有把明细折叠，因为它带 `OVER`。每一当前行都有自己的 frame，得到自己的累计值。

也可写计数：

```sql
COUNT(*) FILTER (WHERE w.status = 'CLOSED') OVER (...)
```

两种都能表达固定任务；选择团队更容易读懂的形式。不要用 `COUNT(status)` 统计完成状态，因为它数的是所有非 NULL 状态，不只 CLOSED。

## 10. 默认 frame 为什么在并列处“提前跳”

最危险的省略不是语法错误，而是查询成功却语义不合预期：

```sql
SUM(CASE WHEN status = 'CLOSED' THEN 1 ELSE 0 END) OVER (
  PARTITION BY technician_id
  ORDER BY created_at
)
```

有窗口 ORDER BY 而未写 frame 时，PostgreSQL 默认是从分区开头到当前行的最后一个 peer；等价理解为 `RANGE UNBOUNDED PRECEDING` 到当前 peer group。[窗口表达式语法](https://www.postgresql.org/docs/18/sql-expressions.html#SYNTAX-WINDOW-FUNCTIONS)说明默认 frame 会包含与当前行在窗口排序上相等的 peers。

T-01 的 W-01 CREATED 与 W-02 CLOSED 同在 09:00。对 W-01 而言，默认 frame 已经包含 W-02，因此 W-01 的累计完成数会显示 1；业务手算的逐条序列却要求 0。T-02 的 W-05 也会提前看见同时间的 W-06，使累计从 1 跳到 2。

这不是 SUM 算错，而是 frame 与业务问题不同。

正确逐行累计同时需要：

1. `ORDER BY created_at, work_order_id` 把行排成稳定全序；
2. `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` 明确按物理排序位置逐行扩展。

只加 `ROWS` 而仍只按 `created_at`，并列内部先后仍未确定；只加 ID 而省略 frame，在唯一排序键下样例可能碰巧等同逐行，却没有显式表达 frame 意图。稳定排序和明确 frame 各解决一个问题。

## 11. ROWS、RANGE 与 GROUPS 的心智模型

PostgreSQL 18 支持三类 frame 模式：

- `ROWS` 按排序后的物理行位置移动；当前行就是当前那一行；
- `RANGE` 按窗口排序值范围或 peer 边界移动；当前行边界会扩到当前 peer group；
- `GROUPS` 按 peer group 的数量移动。

例子不是“谁更高级”，而是问题单位不同：

- “截至当前工单这一次录入”是逐行问题，选 ROWS；
- “截至当前时间点，包含同时间全部事件”是 peer/time-value 问题，RANGE 可能正合适；
- “当前价格档及前两个不同价格档”是 peer group 问题，GROUPS 更贴近语义。

边界词：

- `UNBOUNDED PRECEDING`：分区最前；
- `CURRENT ROW`：含义随 ROWS/RANGE/GROUPS 改变；
- `UNBOUNDED FOLLOWING`：分区最后；
- `n PRECEDING/FOLLOWING`：向前或后移动，单位取决于模式。

若要在每行附分区最终总数，最简单是省略窗口 ORDER BY：

```sql
COUNT(*) OVER (PARTITION BY technician_id)
```

或显式写全分区 frame。若保留 ORDER BY 却沿用默认 frame，得到的通常是运行值，不是最终总数。

## 12. 完整 FactoryCare 查询

```sql
SELECT
  w.work_order_id,
  w.technician_id,
  w.created_at,
  w.status,
  ROW_NUMBER() OVER (
    PARTITION BY w.technician_id
    ORDER BY w.created_at, w.work_order_id
  ) AS technician_sequence,
  LAG(w.work_order_id) OVER (
    PARTITION BY w.technician_id
    ORDER BY w.created_at, w.work_order_id
  ) AS previous_work_order_id,
  LEAD(w.work_order_id) OVER (
    PARTITION BY w.technician_id
    ORDER BY w.created_at, w.work_order_id
  ) AS next_work_order_id,
  w.created_at - LAG(w.created_at) OVER (
    PARTITION BY w.technician_id
    ORDER BY w.created_at, w.work_order_id
  ) AS since_previous,
  LEAD(w.created_at) OVER (
    PARTITION BY w.technician_id
    ORDER BY w.created_at, w.work_order_id
  ) - w.created_at AS until_next,
  SUM(CASE WHEN w.status = 'CLOSED' THEN 1 ELSE 0 END) OVER (
    PARTITION BY w.technician_id
    ORDER BY w.created_at, w.work_order_id
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS completed_so_far
FROM factorycare.work_order AS w
ORDER BY w.technician_id, w.created_at, w.work_order_id;
```

该查询有三个可审查合同：

- 粒度合同：FROM 只有六张工单，每张输出一次；
- 顺序合同：每位技师按时间、工单 ID 唯一排序；
- frame 合同：累计只看到当前物理行及之前行。

不要只看 SQL “像不像”。对固定数据逐行算出预言。

## 13. 六行逐项手算

| 技师 | 工单 | seq | previous | next | since previous | until next | done so far |
| --- | --- | ---: | --- | --- | --- | --- | ---: |
| T-01 | W-01 | 1 | NULL | W-02 | NULL | 0 | 0 |
| T-01 | W-02 | 2 | W-01 | W-03 | 0 | 1h | 1 |
| T-01 | W-03 | 3 | W-02 | NULL | 1h | NULL | 2 |
| T-02 | W-04 | 1 | NULL | W-05 | NULL | 1h30m | 1 |
| T-02 | W-05 | 2 | W-04 | W-06 | 1h30m | 0 | 1 |
| T-02 | W-06 | 3 | W-05 | NULL | 0 | NULL | 2 |

四个不变量：

1. 输出行数 6 等于输入明细行数 6；
2. T-01 与 T-02 都从 seq=1 开始且连续到 3；
3. 每个 previous/next 与同一分区稳定顺序相邻；
4. `completed_so_far` 每次只增加 0 或 1，最终都等于各技师 CLOSED 总数 2。

如果连接技师表只是为了显示姓名，应先证明 `technician_id` 在技师表唯一。否则一对多重复会破坏第一个不变量。

## 14. 用命名 WINDOW 去除重复定义

多列共享同一分区和排序时，可以命名：

```sql
SELECT
  w.work_order_id,
  ROW_NUMBER() OVER ordered AS technician_sequence,
  LAG(w.work_order_id) OVER ordered AS previous_work_order_id,
  LEAD(w.work_order_id) OVER ordered AS next_work_order_id,
  SUM(CASE WHEN w.status = 'CLOSED' THEN 1 ELSE 0 END) OVER running AS completed_so_far
FROM factorycare.work_order AS w
WINDOW
  ordered AS (
    PARTITION BY w.technician_id
    ORDER BY w.created_at, w.work_order_id
  ),
  running AS (
    ordered ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  )
ORDER BY w.technician_id, w.created_at, w.work_order_id;
```

命名减少复制粘贴漂移：不会某一列漏掉 `work_order_id`。但名字必须描述语义，`w1`、`w2` 只把复杂度藏起来。

注意继承边界：基窗口不能已经带 frame，再由派生窗口冲突覆盖。真实语法仍应在目标 PostgreSQL 版本执行验证；离线资产只检查本章固定文本合同。

## 15. 为什么不能在 WHERE 直接筛窗口结果

窗口函数只允许出现在 SELECT 列表和查询层的 ORDER BY；它在 WHERE、GROUP BY、HAVING 之后求值。因此下面不是合法阶段：

```sql
SELECT ...
FROM factorycare.work_order
WHERE ROW_NUMBER() OVER (...) <= 2;
```

先在内层计算，再由外层筛选：

```sql
WITH ranked AS (
  SELECT
    w.*,
    ROW_NUMBER() OVER (
      PARTITION BY w.technician_id
      ORDER BY w.created_at, w.work_order_id
    ) AS technician_sequence
  FROM factorycare.work_order AS w
)
SELECT *
FROM ranked
WHERE technician_sequence <= 2
ORDER BY technician_id, technician_sequence;
```

这也是子查询/CTE 前置章节的直接应用。先计算窗口的查询层与后续筛选层各有清晰职责。

同理，通常不能把一个窗口调用直接嵌套到另一个窗口调用参数里；需要新查询层保存第一阶段结果，再做下一阶段窗口。

## 16. 窗口看到 WHERE 之后的行

假设先筛 `WHERE status = 'CLOSED'`，再计算 `lag`：前一行含义变成“前一张已完成工单”，而不是“前一张工单”。这是合法但不同的问题。

两个需求要分开：

```text
需求 A：所有工单序列中，这张 CLOSED 前一张是什么？
  → 先对全部工单做 lag，再在外层筛 CLOSED

需求 B：CLOSED 子序列中，上一张 CLOSED 是什么？
  → 内层 WHERE 先筛 CLOSED，再做 lag
```

如果结果不符合直觉，先记录窗口输入行数和 ID 列表。窗口不会看见已被 WHERE 删除的行，也不会自动回到原表找邻居。

## 17. NULL、排序方向与边界行

真实数据可能有 NULL `technician_id` 或 NULL 时间。需要业务决定：

- NULL 技师是否全部属于一个“未分配”分区；
- NULL 时间排最前还是最后；
- 是否应该先拒绝缺失时间；
- 降序“上一行”是否代表时间上更晚。

PostgreSQL 可显式写 `NULLS FIRST`/`NULLS LAST`。不要依赖默认值表达业务。

`lag`/`lead` 是相对于窗口排序方向：改成 `ORDER BY created_at DESC` 后，`lag` 指向展示中更靠前、时间上更晚的记录。函数名不是自然时间方向。

固定样例时间与技师均非 NULL，因此离线 oracle 不声称覆盖这些生产策略。

## 18. 窗口不修复 JOIN 基数

故障结构：

```sql
FROM factorycare.work_order AS w
JOIN factorycare.work_order_tag AS wt
  ON wt.work_order_id = w.work_order_id
```

一张工单有三个标签就出现三行。随后：

```sql
ROW_NUMBER() OVER (PARTITION BY technician_id ORDER BY created_at, work_order_id)
```

会给三份 W-01 分别编号。用 `DISTINCT` 包住窗口结果也常无效，因为序号本身让复制行互不相同。

正确流程：

1. 先确定目标粒度是“一张工单一行”；
2. 检查每个 JOIN 的基数与唯一约束；
3. 必要时先把标签聚合到一张工单一行，或用 EXISTS 表达存在性；
4. 核对窗口输入 ID 是否唯一；
5. 最后才计算窗口。

窗口之前的可信基线应至少记录输入行数、`COUNT(DISTINCT work_order_id)` 和重复 ID 样例。

## 19. 三类故障的最短诊断路径

### 故障一：缺 PARTITION

症状：第二位技师的第一张不是 1，累计也继承前一位技师。

第一证据：按 `technician_id` 汇总 `MIN(seq), MAX(seq), COUNT(*)`。每组最小值应为 1，最大值应等于组内行数。

修复：在所有相关窗口定义中加入相同业务分区键。检查不要只修 row_number，却漏修 lag 或 SUM。

### 故障二：窗口 ORDER BY 不确定

症状：并列时间工单的 seq、previous 或累计偶尔互换，或不同环境结果不同。

第一证据：对窗口排序列做重复检测。本章 `GROUP BY technician_id, created_at HAVING COUNT(*) > 1` 会暴露两个并列组。

修复：补稳定、唯一、业务认可的 tiebreaker，并同步到所有共享该序列的窗口。

### 故障三：默认 frame 累计突跳

症状：W-01 尚为 CREATED，累计却已经是 1；W-05 也提前包含 W-06。

第一证据：并列组第一行的默认累计与显式 ROWS 累计对照。不要只看分区最终总数，因为两者最终都可能是 2。

修复：确定需求是逐行还是 peer/time-value；逐行则用唯一排序加显式 `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`。

## 20. 诊断时逐层保存证据

建议建立四层可重放表格：

| 层 | 要记录的证据 | 固定预言 |
| --- | --- | --- |
| 输入粒度 | 行数、工单 ID 唯一数 | 6、6 |
| 分区 | 每技师行数 | T-01=3、T-02=3 |
| 排序 | 并列组与 tiebreaker 后序列 | W-01<W-02；W-05<W-06 |
| frame/函数 | seq、邻居、累计 | 手算六行表 |

定位原则是“第一处偏离”。输入已经八行，就先修 JOIN；输入六行但分区起点错误，就修 PARTITION；序号稳定但累计提前跳，才检查 frame。

一个最终页面截图不是充分证据。可重放证据应包括固定输入、查询文本、预期输出与退出状态；配套 lab 就按这个结构组织。

## 21. 性能边界：语义正确之后再看计划

窗口通常需要按分区键和排序键组织数据，大分区可能产生排序、磁盘临时文件或较高内存压力。但“加索引一定消除排序”“命名 WINDOW 会让查询更快”都不是语义保证。

合理顺序：

1. 固定输入和业务顺序；
2. 证明行数、分区、tiebreaker、frame 正确；
3. 在目标 PostgreSQL 18、真实数据量与配置上执行 `EXPLAIN (ANALYZE, BUFFERS)`；
4. 再评估索引、预聚合、分区规模或查询拆分；
5. 修改后重跑结果等价性断言。

不同窗口若分区/排序不同，可能需要多次排序。共享文本不一定共享全部执行工作；实际计划才是证据。本章资产没有 server，因此不对性能作已验证声明。

## 22. 常见失败写法速查

| 写法 | 为什么失败或危险 | 修复方向 |
| --- | --- | --- |
| `OVER (ORDER BY created_at)` | 全局单分区且时间并列 | 加业务 PARTITION 与唯一 tiebreaker |
| `row_number ... ORDER BY created_at` | peers 内编号不确定 | 加稳定唯一键 |
| 累计只写 ORDER BY | 默认 peer-aware frame 可能突跳 | 明确业务并写 ROWS/RANGE/GROUPS |
| 只写窗口 ORDER BY | 不保证最终展示顺序 | 另写最终 ORDER BY |
| WHERE 中直接用 row_number | 查询阶段不允许 | 子查询/CTE 后外层筛 |
| JOIN 复制后再做窗口 | 窗口基于错误粒度 | 先修基数并断言唯一 |
| `COUNT(status)` 当 CLOSED 数 | 数所有非 NULL 状态 | CASE/SUM 或 FILTER |
| 用 `DISTINCT` 清窗口重复 | 窗口列使行不同 | 在窗口前修输入关系 |
| 改成 DESC 却不重审 lag | 相邻方向含义反转 | 明确时间方向并重算预言 |
| 把 NULL lag 改 0 | 混淆“无前一行”与零间隔 | 保留 NULL 或用明确业务默认 |

## 23. 配套四类资产

- `examples/encyclopedia/ch.data.window-functions/`：正确完整查询和六行预言；
- `labs/encyclopedia/ch.data.window-functions/`：缺 PARTITION、不稳定 ORDER、默认 frame 三类故障；
- `exercises/encyclopedia/ch.data.window-functions/`：故意失败的红色 starter；
- `solutions-private/encyclopedia/ch.data.window-functions/`：通过相同契约的私有参考解。

资产 oracle 独立从 CSV 计算序列、相邻行和累计值，并静态核对 SQL 关键片段。它不是 SQL 解析器。学习证据应明确写“离线固定夹具验证通过；PostgreSQL 实机未验证”，不能把两者混为一谈。

## 24. 120 秒复述模板

> 窗口函数在不折叠明细行的前提下计算组内分析值。PARTITION BY 决定独立分区，窗口 ORDER BY 决定组内先后，frame 决定当前计算可见的行。row_number 给每行编号，rank/dense_rank 表达并列名次，lag/lead 读取排序后的相邻行，聚合函数加 OVER 可做运行累计。反例是只按 created_at 排序并省略 frame：并列时间没有稳定先后，PostgreSQL 默认 frame 还会包含当前 peers，导致第一条 CREATED 工单提前看到同时间 CLOSED。逐行累计应使用稳定唯一 tiebreaker 与显式 ROWS frame。窗口只处理它收到的行，不能修复错误 JOIN；筛窗口结果要加外层查询。

复述后必须能回答：

1. GROUP BY 与窗口输出行数为什么不同？
2. 最终 ORDER BY 为什么不能修复窗口 ORDER BY？
3. T-01 的 W-01 默认累计为什么可能是 1？
4. `ROWS` 已写但没有 tiebreaker，为什么仍不稳定？
5. 如何证明每个技师编号都从 1 开始？
6. lag 第一行的 NULL 与零间隔有何不同？
7. JOIN 重复时第一处可信证据在哪里？

## 25. 官方依据与版本边界

本章只把 PostgreSQL 18 官方文档作为技术语义主依据：

- [PostgreSQL 18 Tutorial: Window Functions](https://www.postgresql.org/docs/18/tutorial-window.html)：窗口保留行身份、PARTITION/ORDER、默认 frame 与查询阶段；
- [PostgreSQL 18 Window Functions](https://www.postgresql.org/docs/18/functions-window.html)：row_number/rank/dense_rank、lag/lead、聚合窗口与默认 frame 提示；
- [PostgreSQL 18 Window Function Calls](https://www.postgresql.org/docs/18/sql-expressions.html#SYNTAX-WINDOW-FUNCTIONS)：OVER、frame 模式、边界与 peer 语义。

稳定核心是关系结果粒度、分区、确定性排序、frame 和相邻/累计推理。版本相关面包括 PostgreSQL 18 的具体语法、NULL 排序默认、计划选择与运行资源。升级时先重跑目标数据库语法和结果测试，再做计划对比。
