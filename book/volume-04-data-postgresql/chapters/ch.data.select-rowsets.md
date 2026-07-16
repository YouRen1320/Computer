---
schema_version: 2
edition: 2026.2-draft
id: ch.data.select-rowsets
title: SELECT、投影、过滤、NULL、排序与分页
responsibility: 教授从关系中声明式产生确定行集，不在本章引入聚合、连接或写操作
volume: '04'
order: 3
level: L1
status: drafting
path: book/volume-04-data-postgresql/chapters/ch.data.select-rowsets.md
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
  text: 在 120 秒内解释SELECT、投影、过滤、NULL、排序与分页的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - sql-select-filter
  - sql-order-page
  covers_topics:
  - sql.select-projection
  - sql.where-predicate
  - sql.null-three-valued-logic
  - sql.order-by
  - sql.limit-offset
  - sql.deterministic-pagination
  uses_capabilities:
  - data.relational-schema
  - data.sql-query
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 查询启用设备：投影 id/category/created_at，处理 NULL 条件，按时间+id 确定排序并实现稳定分页
  covers_topic_groups:
  - sql-select-filter
  - sql-order-page
  covers_topics:
  - sql.select-projection
  - sql.where-predicate
  - sql.null-three-valued-logic
  - sql.order-by
  - sql.limit-offset
  - sql.deterministic-pagination
  uses_capabilities:
  - data.relational-schema
  - data.sql-query
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入 = NULL、缺括号 AND/OR 和只按非唯一时间分页，使用样例行发现漏行/重复后修复
  covers_topic_groups:
  - sql-select-filter
  - sql-order-page
  covers_topics:
  - sql.select-projection
  - sql.where-predicate
  - sql.null-three-valued-logic
  - sql.order-by
  - sql.limit-offset
  - sql.deterministic-pagination
  uses_capabilities:
  - data.relational-schema
  - data.sql-query
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# SELECT、投影、过滤、NULL、排序与分页

> 本章状态为 `drafting`。语义按 PostgreSQL **18.4** 官方文档于 **2026-07-17** 复核。当前机器没有可用的 `psql` 或 PostgreSQL server，Docker daemon 也未运行；配套资产因此使用固定 CSV、静态 SQL 契约和独立 Ruby oracle。离线 oracle 能证明样例行、三值逻辑预言、分页集合与失败注入可重复，**不能证明 SQL 已被真实 PostgreSQL 解析或执行**。

## 1. 本章解决什么问题

关系模型告诉我们表中每一行代表什么，psql 章节告诉我们怎样把脚本送到明确的会话。本章才开始回答最常见的读取问题：

> 从哪一个关系取数据，保留哪些行，显示哪些列，并按什么确定规则交付其中一段？

一条查询不是“逐行操作数据库的命令清单”，而是对目标结果的声明。最小心智流水线是：

```text
FROM 确定输入关系
  → WHERE 对每个候选行求谓词
  → 只保留结果为 TRUE 的行
  → SELECT 为每个保留行产生输出列
  → DISTINCT（若有）去掉完整输出行的重复项
  → ORDER BY 建立交付次序
  → LIMIT / OFFSET 取得有序结果的一段
  → 客户端收到表形结果集
```

这是理解语义的**概念处理顺序**，不是对 PostgreSQL 物理执行步骤的承诺。优化器可以采用索引、改变内部求值方式或重排等价表达式，只要查询语义不变。[PostgreSQL 18 `SELECT` 文档](https://www.postgresql.org/docs/18/sql-select.html)给出了各子句的规范处理次序；本章用它来解释名称可见性和结果含义，不拿它猜执行计划。

### 完成标准

学完后，你应能：

- 明确说出 `FROM`、`WHERE`、`SELECT`、`DISTINCT`、`ORDER BY`、`LIMIT/OFFSET` 各自改变什么；
- 手算空集、单行、多行和含 `NULL` 行的结果；
- 用 `IS NULL`，不写永远无法得到 `TRUE` 的 `= NULL`；
- 给混合 `AND/OR` 条件加括号，让业务规则不依赖读者背优先级；
- 显式投影 `id/category/created_at` 并给结果列稳定名称；
- 用 `created_at, device_id` 组成全序，在固定数据快照上重复得到同一页；
- 解释 `DISTINCT` 去重的是完整输出行，不能用来掩盖查询建模错误；
- 说明 offset 分页在并发写入下仍可能漂移，并界定本章证据只覆盖固定输入。

本章明确不做聚合、分组、多表连接、子查询、写操作、索引设计、事务隔离和 keyset/cursor 分页实现。后续章节分别承担这些职责。

## 2. 固定样例：先定义一行的意义

本章的输入关系是 `factorycare.device`。一行表示“一台可被 FactoryCare 跟踪的设备”，不是一次维修事件。配套 CSV 使用以下字段：

| 列 | 本章中的意义 |
| --- | --- |
| `device_id` | 设备稳定标识，样例中唯一且非空 |
| `category` | 设备类别 |
| `enabled` | 是否启用 |
| `retired_at` | 退役时刻；`NULL` 表示尚未记录退役时刻 |
| `created_at` | 设备记录建立时刻 |

固定截止时刻为 `2026-07-17 00:00:00+00`。业务问题是：

> 查询已启用，并且尚无退役时刻或退役时刻晚于截止时刻的设备；输出 id、category、created_at；按 created_at 升序，再按 device_id 升序；每页两行。

注意 `retired_at IS NULL` 在这里有明确业务含义：“没有已知退役时刻，所以仍视为候选”。如果领域把 `NULL` 定义成“状态未知，不能展示”，谓词就应不同。SQL 不会替业务决定 `NULL` 的含义。

## 3. SELECT 是投影：决定结果的列

`SELECT` 后面的列表称为 select list。它为每个通过过滤的输入行计算输出表达式，并给客户端形成结果列：

```sql
SELECT
  d.device_id AS id,
  d.category AS category,
  d.created_at AS created_at
FROM factorycare.device AS d;
```

这条查询显式承诺三列，顺序是 `id`、`category`、`created_at`。投影改变的是结果“宽度”和列名，不是输入表定义，也不负责筛行。

`SELECT *` 会展开当前输入关系的全部列，适合临时观察，却不适合作为稳定接口：

- 表新增一列会悄悄改变结果契约；
- 客户端会收到不需要的数据；
- 重名列和敏感列更难审阅；
- 读者无法只看查询就知道需要哪些字段。

因此应用和教材证据优先显式列清单。[PostgreSQL 18 select list 文档](https://www.postgresql.org/docs/18/queries-select-lists.html)说明 `*` 展开和逐结果行表达式语义。

### 输出别名不是改列名

`AS id` 只给本次结果列一个标签，不会把表中的 `device_id` 改名。显式写 `AS` 可让列别名和表达式边界更清楚：

```sql
d.device_id AS id
```

由于概念上 `WHERE` 先于 select list，`WHERE` 一般不能引用同层刚定义的输出别名：

```sql
-- 错误心智模型：WHERE 阶段还没有输出别名 id
SELECT d.device_id AS id
FROM factorycare.device AS d
WHERE id = 'D-01';
```

应引用输入列 `d.device_id`。而 `ORDER BY` 在输出之后处理，PostgreSQL 允许它引用简单输出别名。为了让“按哪个源字段排序”一眼可见，本章仍在排序中使用限定列名。

## 4. FROM 是输入边界

`FROM factorycare.device AS d` 明确了 schema、关系和查询内别名：

- `factorycare` 是 schema；
- `device` 是关系名；
- `d` 是这条查询内的短名称。

一旦给表写了别名，同一查询层应使用该别名限定列：

```sql
FROM factorycare.device AS d
SELECT d.device_id
```

上面的片段只是为了展示名称；完整 SQL 必须按 `SELECT ... FROM ...` 的语法顺序书写。表别名不会创建表，也不会跨查询存在。schema 限定能减少 `search_path` 变化导致的歧义，但权限和搜索路径治理仍属于后续主题。

本章只使用一个 `FROM` 项。多个并列 FROM 项会涉及笛卡尔积和连接语义，留到 joins 章节。

## 5. WHERE 是行过滤：只有 TRUE 能通过

`WHERE` 为每个候选行计算一个布尔谓词。关键规则不是“非假即真”，而是：

| WHERE 结果 | 是否保留该行 |
| --- | --- |
| `TRUE` | 保留 |
| `FALSE` | 丢弃 |
| `NULL` / UNKNOWN | 丢弃 |

[PostgreSQL 18 table expressions 文档](https://www.postgresql.org/docs/18/queries-table-expressions.html)明确说明，只有搜索条件为 true 的行通过；false 或 null 都被丢弃。

本章谓词为：

```sql
WHERE d.enabled IS TRUE
  AND (
    d.retired_at IS NULL
    OR d.retired_at > TIMESTAMPTZ '2026-07-17 00:00:00+00'
  )
```

可先把它翻译成自然语言，再逐行代入：

1. 必须明确启用；
2. 同时满足以下任一条件：
   - 没有退役时刻；
   - 有退役时刻，并且晚于截止时刻。

括号不是装饰。它把第二条的“任一”绑定成一组。

## 6. NULL 与三值逻辑

`NULL` 不是空字符串、零、false 或某个特殊日期。它表示 SQL 值缺失/未知。在普通比较中，只要比较的一侧是 `NULL`，结果通常是 UNKNOWN：

| 表达式 | 结果 |
| --- | --- |
| `5 = 5` | `TRUE` |
| `5 = 6` | `FALSE` |
| `5 = NULL` | `UNKNOWN` |
| `NULL = NULL` | `UNKNOWN` |
| `NULL IS NULL` | `TRUE` |
| `5 IS NULL` | `FALSE` |

因此下面的条件不会找到 `NULL`：

```sql
WHERE d.retired_at = NULL
```

对任意行，它都不能得到 `TRUE`。正确的空值测试是：

```sql
WHERE d.retired_at IS NULL
-- 或
WHERE d.retired_at IS NOT NULL
```

若要做“把两个 NULL 当作相等”的两值比较，可以在合适场景使用 `IS NOT DISTINCT FROM`；反向的 `IS DISTINCT FROM` 也不会返回 UNKNOWN。它们不是把 `NULL` 变成普通值，而是提供明确的 null-aware 比较。[PostgreSQL 18 comparison 文档](https://www.postgresql.org/docs/18/functions-comparison.html)给出了这些谓词。

### AND、OR、NOT 的三值表

`AND` 要求两侧都真；`OR` 只要一侧真；`NOT` 翻转真/假但未知仍未知：

| A | B | A AND B | A OR B |
| --- | --- | --- | --- |
| TRUE | TRUE | TRUE | TRUE |
| TRUE | FALSE | FALSE | TRUE |
| TRUE | UNKNOWN | UNKNOWN | TRUE |
| FALSE | TRUE | FALSE | TRUE |
| FALSE | FALSE | FALSE | FALSE |
| FALSE | UNKNOWN | FALSE | UNKNOWN |
| UNKNOWN | TRUE | UNKNOWN | TRUE |
| UNKNOWN | FALSE | FALSE | UNKNOWN |
| UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN |

| A | NOT A |
| --- | --- |
| TRUE | FALSE |
| FALSE | TRUE |
| UNKNOWN | UNKNOWN |

可从“确定信息能否决定结果”理解：`FALSE AND UNKNOWN` 已确定为 false；`TRUE OR UNKNOWN` 已确定为 true。[PostgreSQL 18 logical operators 文档](https://www.postgresql.org/docs/18/functions-logical.html)给出同样的三值表。

## 7. AND/OR 优先级：语法正确也可能业务错误

PostgreSQL 中 `NOT` 高于 `AND`，`AND` 高于 `OR`。因此：

```sql
WHERE d.enabled IS TRUE
  AND d.retired_at IS NULL
  OR d.retired_at > TIMESTAMPTZ '2026-07-17 00:00:00+00'
```

会被理解成：

```text
(enabled IS TRUE AND retired_at IS NULL)
OR retired_at > cutoff
```

一台已禁用但退役时刻晚于 cutoff 的设备也会通过。这不是 SQL 语法错，而是业务分组错，往往比语法错误更危险。目标应写成：

```text
enabled IS TRUE
AND (retired_at IS NULL OR retired_at > cutoff)
```

即使你记得优先级，也应为混合 `AND/OR` 的业务组合加括号；它既保护语义，也让审阅者无需猜测。[PostgreSQL 18 lexical structure 文档](https://www.postgresql.org/docs/18/sql-syntax-lexical.html)列出运算符优先级。

不要进一步假设左侧谓词必定先执行。优化器可以重组布尔表达式；需要避免错误求值的场景应改写表达式，而不是依赖“短路顺序”。标量函数章节会继续说明 `CASE` 的边界。

## 8. 结果集：表形值不自带顺序

查询交给客户端的是一个结果集：有列定义、有零到多行。它可以为空：

```text
 id | category | created_at
----+----------+------------
(0 rows)
```

空结果不是 SQL 失败；它表示查询成功且没有行满足条件。相反，语法错误、类型错误或连接错误不会产生“正常的空结果”，应从 stderr 和退出状态判断。

结果集不是基础表，也不会因为被 SELECT 就持久化。更重要的是，关系结果在没有 `ORDER BY` 时没有可依赖的交付顺序。今天看起来按主键、插入先后或磁盘位置返回，明天可能因计划、并行、统计信息或版本变化而不同。

[PostgreSQL 18 sorting 文档](https://www.postgresql.org/docs/18/queries-order.html)明确指出，只有显式排序步骤才能保证特定顺序。

## 9. ORDER BY：从集合到有序序列

稳定排序要写出每个排序键、方向和必要的 NULL 位置：

```sql
ORDER BY
  d.created_at ASC,
  d.device_id ASC
```

先比较 `created_at`；只有时间相等时才比较 `device_id`。如果 `device_id` 在候选行中唯一，这两个键就组成全序：任何两行都有确定先后。

`ASC` 是升序，`DESC` 是降序。每个键方向独立：

```sql
ORDER BY d.created_at DESC, d.device_id ASC
```

如果排序列允许 `NULL`，应显式写 `NULLS FIRST` 或 `NULLS LAST`，而不是依赖默认值：

```sql
ORDER BY d.retired_at ASC NULLS LAST, d.device_id ASC
```

PostgreSQL 默认在 `ASC` 时把 NULL 放后面，在 `DESC` 时放前面；显式声明更能表达产品需求。排序中的位置号如 `ORDER BY 1` 虽可用，却会随 select list 重排而改变含义，不适合作为长期维护契约。

### “唯一排序键”与“唯一列”不是同一句话

`created_at` 可以重复，所以只按它排序并非全序。补上唯一的 `device_id` 后，组合键才唯一。不能为了“看起来更稳定”随便补一个非唯一列；必须证明最终组合能区分候选行。

## 10. LIMIT 与 OFFSET：先排序，再切片

`LIMIT 2 OFFSET 0` 表示跳过零行后最多取两行；`LIMIT 2 OFFSET 2` 表示跳过前两行后最多取两行：

```sql
-- 第 1 页
ORDER BY d.created_at ASC, d.device_id ASC
LIMIT 2 OFFSET 0;

-- 第 2 页
ORDER BY d.created_at ASC, d.device_id ASC
LIMIT 2 OFFSET 2;
```

页码从 1 开始、页大小为 `page_size` 时，常见公式是：

```text
offset = (page_number - 1) × page_size
```

这里“OFFSET 从 0 开始”描述跳过的行数，不是说用户界面必须显示第 0 页。

没有确定 `ORDER BY` 的分页没有稳定含义。即使查询文本和数据不变，不同 LIMIT/OFFSET 也可能使用不同计划并返回不同子集。[PostgreSQL 18 LIMIT/OFFSET 文档](https://www.postgresql.org/docs/18/queries-limit.html)特别要求用可预测顺序约束结果。

OFFSET 还存在成本边界：被跳过的行仍需由服务器计算，较大 offset 可能越来越慢。本章只建立语义正确性，不把 offset 分页包装成任意规模下的性能最佳方案。

## 11. 确定分页的两层边界

“按时间 + id”解决的是第一层：

1. **同一固定输入/同一可见数据版本内**，排序键组成全序；
2. 每页是该全序的连续、不重叠切片；
3. 重复运行得到相同顺序。

它不自动解决第二层：

> 用户取第 1 页后，如果有行插入、删除或排序键改变，第 2 页的 OFFSET 是相对于新结果计算的。

因此并发变化仍可能造成跨请求重复或遗漏。产品必须选择一致性策略，例如在同一事务快照读取、接受“实时列表会漂移”，或在后续采用基于最后排序键的 keyset pagination。选择取决于交互和一致性要求；本章实验只声称对固定 CSV 快照成立。

这一区分非常重要：**全序是稳定分页的必要条件，但不是跨变化快照一致性的充分条件。**

## 12. DISTINCT：对完整输出行去重

`SELECT` 默认是 `ALL`，保留全部输出行。`DISTINCT` 会在投影之后删除重复的**完整输出行**：

```sql
SELECT DISTINCT
  d.category AS category
FROM factorycare.device AS d
WHERE d.enabled IS TRUE
ORDER BY category ASC;
```

若三台候选设备的 category 都是 `pump`，结果只出现一个 `pump`。但如果同时投影唯一 `device_id`：

```sql
SELECT DISTINCT d.device_id, d.category
...
```

每个 id 不同，整行仍不同，DISTINCT 不会把它们合并。

正确用途是问题本来就问“有哪些不同类别”。危险用途是发现重复后随手加 DISTINCT，把不理解的数据关系或未来连接错误藏起来。先回答“结果的一行代表什么”，再决定是否去重。

在 PostgreSQL 的 `SELECT DISTINCT` 中，`ORDER BY` 表达式需要出现在 select list。`DISTINCT ON` 是 PostgreSQL 扩展，还有“左侧排序表达式”和首行选择规则；它不属于本章主线，不应在零基础分页练习中代替清晰的业务规则。

## 13. 完整构建：启用设备的两页结果

第一页：

```sql
SELECT
  d.device_id AS id,
  d.category AS category,
  d.created_at AS created_at
FROM factorycare.device AS d
WHERE d.enabled IS TRUE
  AND (
    d.retired_at IS NULL
    OR d.retired_at > TIMESTAMPTZ '2026-07-17 00:00:00+00'
  )
ORDER BY
  d.created_at ASC,
  d.device_id ASC
LIMIT 2 OFFSET 0;
```

第二页只改变 offset：

```sql
SELECT
  d.device_id AS id,
  d.category AS category,
  d.created_at AS created_at
FROM factorycare.device AS d
WHERE d.enabled IS TRUE
  AND (
    d.retired_at IS NULL
    OR d.retired_at > TIMESTAMPTZ '2026-07-17 00:00:00+00'
  )
ORDER BY
  d.created_at ASC,
  d.device_id ASC
LIMIT 2 OFFSET 2;
```

检查时按流水线手算，不要从预期答案倒推：

1. 枚举 CSV 的每一行；
2. 计算 `enabled IS TRUE`；
3. 计算括号内两项；
4. 只有总谓词为 true 才保留；
5. 只写三列并改名为 `id/category/created_at`；
6. 先按时间、同时间再按 id；
7. 从有序列表切出索引 `0..1` 和 `2..3`；
8. 拼接两页，确认无重复、无遗漏，且与完整候选列表一致。

配套 oracle 预期候选顺序为：

```text
D-01, D-02, D-05, D-06
```

前三行共享同一 `created_at`，故样例能真正检验 id tie-breaker，而不是“碰巧没有并列”。

## 14. 三个失败注入与第一处可信证据

### 失败一：`= NULL`

注入：

```sql
d.retired_at = NULL
```

第一处可信证据是逐行真值表：即使 retired_at 实际为 NULL，比较结果仍是 UNKNOWN；WHERE 不保留 UNKNOWN。修复为 `IS NULL`，再重算候选行。

### 失败二：缺少 AND/OR 括号

注入：

```sql
d.enabled IS TRUE
AND d.retired_at IS NULL
OR d.retired_at > cutoff
```

第一处可信证据是 D-07：它已禁用，但有未来 retired_at。按实际优先级，右侧 OR 单独为 true，于是泄漏到结果。修复括号后 D-07 被第一项拦下。

### 失败三：只按非唯一时间分页

注入：

```sql
ORDER BY d.created_at ASC
LIMIT 2 OFFSET ...
```

D-01、D-02、D-05 的时间相同，数据库可用任意相对次序交付这三行。若第一页与第二页是两次独立查询，它们可能采用不同的合法并列顺序，进而让 D-02 重复、D-05 遗漏。第一处可信证据不是“我在本机跑一次没复现”，而是排序规范无法决定三者先后。补 `device_id ASC` 才消除自由度。

## 15. 如何使用四类离线资产

四个入口均不访问网络、不读取环境中的数据库变量、不执行 `psql`：

```sh
./examples/encyclopedia/ch.data.select-rowsets/verify.sh
./labs/encyclopedia/ch.data.select-rowsets/verify.sh
./exercises/encyclopedia/ch.data.select-rowsets/verify.sh
./solutions-private/encyclopedia/ch.data.select-rowsets/verify.sh
```

- `examples`：演示正确查询契约和固定结果；
- `labs`：验证空集/单行/多行、NULL、三种失败注入和两页闭合；
- `exercises`：故意保留红色 starter；wrapper 只有在 oracle 按预期拒绝时才成功；
- `solutions-private`：保存独立答案与固定通过输出，不应提前给学习者。

oracle 不实现 PostgreSQL SQL parser。它先检查 SQL 文件是否包含本任务要求的关键结构，再用 Ruby 对 CSV 独立计算业务预言。这样能发现教材样例自相矛盾，又不会产生“Ruby 接受了，所以 PostgreSQL 必定接受”的错误结论。

## 16. 120 秒复述模板

可以用以下顺序口述，但不要背成空话：

1. `FROM` 确定一个输入关系；
2. `WHERE` 对每行求三值谓词，只有 true 通过；
3. `SELECT` 投影结果列，别名只影响本次结果标签；
4. `NULL` 不能用 `= NULL` 测试，要用 `IS NULL`；
5. 混合 `AND/OR` 用括号表达业务分组；
6. 没有 `ORDER BY` 就没有保证顺序；
7. 分页排序必须形成全序，例如时间后补唯一 id；
8. LIMIT/OFFSET 是有序结果的切片，固定快照内可稳定，但并发变化仍会漂移；
9. DISTINCT 去掉完整输出行的重复项，不修复错误建模；
10. 一个失败反例是只按非唯一时间分页，理论上就允许跨页重复/遗漏。

若你不能用 D-07 解释括号错误，或不能说出 D-01/D-02/D-05 为什么需要 tie-breaker，就还没有达到诊断结果。

## 17. 官方依据与版本边界

本章只采用 PostgreSQL 18 官方主文档：

- [`SELECT` 语法与处理顺序](https://www.postgresql.org/docs/18/sql-select.html)
- [Select lists](https://www.postgresql.org/docs/18/queries-select-lists.html)
- [Table expressions 与 `WHERE`](https://www.postgresql.org/docs/18/queries-table-expressions.html)
- [逻辑运算与三值表](https://www.postgresql.org/docs/18/functions-logical.html)
- [比较与 `IS NULL` / `IS DISTINCT FROM`](https://www.postgresql.org/docs/18/functions-comparison.html)
- [排序规则](https://www.postgresql.org/docs/18/queries-order.html)
- [`LIMIT` 与 `OFFSET`](https://www.postgresql.org/docs/18/queries-limit.html)
- [词法结构与优先级](https://www.postgresql.org/docs/18/sql-syntax-lexical.html)

稳定核心是关系投影、三值过滤、显式排序与分页切片的语义。版本敏感面包括 PostgreSQL 扩展语法、优化器计划、默认 NULL 排序、错误文本和客户端展示。真实 PostgreSQL 18.4 的解析、类型解析、排序执行与 psql 输出尚未在本机验证，不能用本章离线 PASS 替代集成证据。
