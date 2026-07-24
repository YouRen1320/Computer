---
schema_version: 2
edition: 2026.2-draft
id: ch.data.scalar-functions
title: 数值、文本、日期函数与 CASE
responsibility: 教授逐行标量表达式和条件映射，不把标量函数与聚合函数混为一谈
volume: '04'
order: 4
level: L1
status: drafting
path: book/volume-04-data-postgresql/chapters/ch.data.scalar-functions.md
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
  text: 在 120 秒内解释数值、文本、日期函数与 CASE的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - sql-scalar-functions
  - sql-case-conversion
  covers_topics:
  - sql.numeric-function
  - sql.text-function
  - sql.date-time-function
  - sql.case-expression
  - sql.cast
  - sql.coalesce
  uses_capabilities:
  - data.sql-query
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 用文本规范化、日期截断、数值舍入、COALESCE 和 CASE 生成设备展示字段，保留原始列对照，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - sql-scalar-functions
  - sql-case-conversion
  covers_topics:
  - sql.numeric-function
  - sql.text-function
  - sql.date-time-function
  - sql.case-expression
  - sql.cast
  - sql.coalesce
  uses_capabilities:
  - data.sql-query
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入时区边界跨日、NULL 被错误填成业务值和隐式 cast 失败，定位表达式并改为显式规则，并把异常定位到第一处可信证据
  covers_topic_groups:
  - sql-scalar-functions
  - sql-case-conversion
  covers_topics:
  - sql.numeric-function
  - sql.text-function
  - sql.date-time-function
  - sql.case-expression
  - sql.cast
  - sql.coalesce
  uses_capabilities:
  - data.sql-query
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 数值、文本、日期函数与 CASE

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《SELECT、投影、过滤、NULL、排序与分页》](ch.data.select-rowsets.md)：独立完成标量函数、CASE 与转换前，必须先具备「SELECT、投影、过滤、NULL、排序与分页」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。语义按 PostgreSQL **18.4** 官方文档于 **2026-07-17** 复核。当前机器没有可用的 `psql` 或 PostgreSQL server，Docker daemon 也未运行；配套资产使用固定 CSV、静态 SQL 契约与 Ruby 标准库 oracle。它能核对固定输入的逐行结果、NULL/时区/转换失败预言和函数边界，**不能证明真实 PostgreSQL 的函数重载、类型解析、IANA 时区库或表达式索引已经执行**。

## 1. 本章解决什么问题

上一章把输入关系筛成一个结果行集。本章保持“每个输入行仍对应一个输出行”，只在每行内部生成展示字段：

```text
一行原始设备数据
  → 文本规范化
  → 数值舍入
  → NULL 回退
  → CASE 条件映射
  → 时区转换与日期截断
  → 一行带原始值和派生值的结果
```

标量表达式一次产生一个值。把多个标量表达式放进 select list，会增加或替换结果列，却不会自行把多行压成一行：

```text
输入 4 行 + 每行 7 个标量结果 = 输出仍为 4 行
```

这与后续聚合章节的“多行归约成一个分组结果”完全不同。也不要把返回多行的 set-returning function 混进这个心智模型；本章不教授它。

### 完成标准

你应能：

- 解释标量函数按结果行求值，不把 `round`、`lower`、`date_trunc` 当聚合；
- 为数值类型选择明确的舍入/截断规则，并识别整数除法与浮点边界；
- 区分字符长度与字节长度，知道大小写转换受 locale/collation 语境影响；
- 使用 `CASE`、`COALESCE`、`NULLIF` 保留 NULL 的业务含义；
- 使用标准 `CAST(expr AS type)` 或 PostgreSQL `expr::type` 显式转换，并让非法输入可见地失败；
- 先把 `timestamptz` 转到目标地区墙钟时间，再按当地日期截断；
- 区分事务时间、语句时间和真实时钟时间；
- 解释 `IMMUTABLE/STABLE/VOLATILE` 是给优化器的承诺，不是性能标签；
- 解释查询中的函数表达式为何可能需要匹配的表达式索引，以及时区依赖为何限制 immutable；
- 为普通、NULL、跨日边界和转换失败留下固定验证报告。

本章不教授聚合、窗口函数、用户自定义函数实现、正则清洗、DDL 建索引、执行计划调优或完整时区治理。索引只讲“表达式匹配和波动性边界”，实际创建与解释计划留到索引章节。

## 2. 标量表达式的最小语法

select list 的每一项都是值表达式，可以是：

- 列引用：`d.temperature_c`；
- 常量：`NUMERIC '30'`；
- 运算：`d.temperature_c + 1`；
- 函数调用：`round(d.temperature_c, 1)`；
- 条件表达式：`CASE ... END`；
- 类型转换：`CAST(d.last_seen_at AS date)`；
- 上述结构的组合。

例如：

```sql
SELECT
  d.device_id,
  round(d.temperature_c, 1) AS temperature_c_1dp
FROM factorycare.device_reading AS d
ORDER BY d.device_id;
```

如果输入有四行，`round` 对四个输入值分别求值。某行 `temperature_c` 为 NULL 时，内置 `round` 的对应结果也为 NULL；其他行不受影响。

“逐行”是语义模型，不保证 PostgreSQL 机械地从第一行到最后一行依次调用函数。优化器可以折叠常量、重排安全表达式或使用索引。涉及副作用和变化值时，必须看函数 volatility 契约。

## 3. 固定样例与原始值对照

配套数据一行表示“一台设备的展示输入”，主要列为：

| 列 | 类型意图 | 边界样例 |
| --- | --- | --- |
| `device_id` | text | 稳定 id |
| `raw_name` | text | 大小写混合、前后空格 |
| `alias` | text nullable | NULL、空白或真实别名 |
| `temperature_c` | numeric nullable | 正负、半值、NULL、阈值 |
| `last_seen_at` | timestamptz | UTC 瞬间跨上海午夜 |
| `calibration_text` | text | 包含 `not-a-number` 的转换故障夹具 |

结果同时保留原始列和派生列。保留对照很重要：如果只输出规范化结果，就无法区分“原始数据本来如此”和“表达式把它改错”。

本章使用明确产品规则：

- `normalized_name`：去首尾空格后转小写，仅用于搜索/展示演示；
- `display_name`：非空白 alias 优先，否则退回去空格的 raw name；
- `temperature_c_1dp`：按 `numeric` 规则保留一位小数；
- `temperature_band`：NULL→`UNKNOWN`，小于 0→`FREEZING`，大于等于 30→`HOT`，否则 `NORMAL`；
- `local_day_start`：把绝对时刻转换为 `Asia/Shanghai` 墙钟时间后截到当地日；
- `local_date`：同一当地墙钟时间显式 cast 为 `date`。

这些标签是本练习的业务合同，不是 PostgreSQL 内置含义。

## 4. 类型先于函数名

PostgreSQL 支持函数重载：同名函数可以按参数类型选择不同实现。读到：

```sql
round(value)
```

还不能完整判断边界，必须问 `value` 是 `numeric` 还是 `double precision`。同样的字面量、运算符和函数名，可能经过类型解析得到不同结果或错误。

这就是为什么示例用：

```sql
NUMERIC '30'
TIMESTAMPTZ '2026-07-16 16:00:00+00'
CAST(expression AS date)
```

明确类型不是为了堆语法，而是把精度、时区和错误合同暴露给读者。真实表列已有声明类型时不必给每个值重复 cast；但跨边界常量和文本转换应保持清晰。

## 5. 数值函数：舍入不是格式化

[PostgreSQL 18 mathematical functions](https://www.postgresql.org/docs/18/functions-math.html)列出常用数值函数：

| 表达式 | 意义 |
| --- | --- |
| `abs(x)` | 绝对值 |
| `round(x)` | 舍入到整数 |
| `round(numeric, scale)` | 舍入到指定小数位 |
| `trunc(numeric, scale)` | 向零截断到指定小数位 |
| `ceil(x)` / `floor(x)` | 向上/向下取整 |

本章列为 `numeric`：

```sql
round(d.temperature_c, 1) AS temperature_c_1dp
```

对 `numeric`，刚好在半值时向远离零方向取整，所以固定样例 `23.45 → 23.5`、`-2.25 → -2.3`。而 `round(double precision)` 的半值规则依赖平台，常见是“向最近偶数”。不能把某一 overload 的规则套给所有数值类型。

### 三个常见混淆

第一，`round` 改变数值，不只是显示格式。客户端显示几位小数是另一层合同。

第二，`trunc(-2.29, 1)` 是向零截断，不是 `floor`；对负数两者不同。

第三，整数除法会向零截断：

```sql
SELECT 5 / 2;    -- integer 结果为 2
SELECT 5.0 / 2;  -- 类型不同，结果保留小数
```

如果分母为零，正确行为是错误，不应靠“左侧条件先执行”侥幸避开。可重写公式或用明确 CASE 守卫，但还要考虑常量折叠边界。

浮点函数多数基于宿主 C 库，精度和边界行为可能随平台不同。需要精确十进制业务规则时应先选合适数据类型，再谈函数。

## 6. 文本函数：字符、字节和 locale

本章组合：

```sql
lower(btrim(d.raw_name)) AS normalized_name
```

`btrim(text)` 默认去掉两端空格，不删除中间空格。若传第二个字符集合，它移除的是两端由这些字符组成的最长片段，不是把第二参数当完整子串。

`lower(text)` 按数据库 locale 规则转小写。ASCII 样例便于离线复现，但真实多语言名称可能受 locale、collation、Unicode 版本及扩展配置影响。Ruby `downcase` 与 PostgreSQL `lower` 在固定 ASCII 样例上一致，不代表所有 Unicode 输入等价。

[PostgreSQL 18 string functions](https://www.postgresql.org/docs/18/functions-string.html)还区分：

```sql
char_length('josé')   -- 字符数
octet_length('josé')  -- 当前编码下的字节数
```

UTF-8 中字符数和字节数可能不同。产品限制“最多 20 个字符”不能用字节函数代替；协议限制“最多 20 bytes”也不能用字符函数代替。

字符串连接也有 NULL 边界：

- `a || b` 的任一侧为 NULL 时通常得到 NULL；
- `concat(...)` 会忽略 NULL 参数；
- `concat_ws(separator, ...)` 也忽略后续 NULL，但 separator 不应为 NULL。

选择哪种写法取决于“缺字段时整个展示值是否应未知”，不能只看哪个输出更好看。

## 7. NULL 传播不是统一魔法

许多普通内置函数对 NULL 输入返回 NULL，但不能凭函数外观推断所有函数都如此。函数可以声明 `STRICT`（有 NULL 参数时不调用，直接返回 NULL），也可以被设计成主动处理 NULL。

条件表达式尤其不同：

### COALESCE：第一个非 NULL

`COALESCE(a, b, c)` 返回从左到右第一个非 NULL 参数；全部为 NULL 才返回 NULL。参数必须能转换为共同类型。

但空字符串和只含空格的字符串都不是 NULL。因此直接写：

```sql
COALESCE(d.alias, d.raw_name)
```

无法跳过 `'   '`。本章先去空格，再把空字符串变成 NULL：

```sql
COALESCE(
  NULLIF(btrim(d.alias), ''),
  btrim(d.raw_name)
) AS display_name
```

### NULLIF：相等则变 NULL

`NULLIF(value1, value2)` 按 `value1 = value2` 比较；相等返回 NULL，否则返回第一个值。它适合把一个**明确约定的哨兵值**转换为缺失，不适合随手把合法的零、空字符串或 UNKNOWN 标签抹掉。

### 默认值必须有业务授权

`COALESCE(d.temperature_c, 0)` 在语法上有效，却可能把“未测量”伪装成“测得 0°C”。如果随后分档，它会得到 `NORMAL` 或 `FREEZING`，丢掉未知状态。本章保留原始 NULL，并在 CASE 中显式输出 `UNKNOWN`。

[PostgreSQL 18 conditional expressions](https://www.postgresql.org/docs/18/functions-conditional.html)说明 COALESCE 只求值到第一个非 NULL 参数，并给出 NULLIF 的比较/返回类型边界。

## 8. CASE：把条件映射写成可审阅规则

搜索式 CASE 逐个检查 WHEN：

```sql
CASE
  WHEN d.temperature_c IS NULL THEN 'UNKNOWN'
  WHEN d.temperature_c < NUMERIC '0' THEN 'FREEZING'
  WHEN d.temperature_c >= NUMERIC '30' THEN 'HOT'
  ELSE 'NORMAL'
END AS temperature_band
```

顺序是合同的一部分。NULL 分支必须在数值比较之前表达；虽然 NULL 与数值比较得到 UNKNOWN、会继续到后面，但显式首分支让读者看到业务决策。重叠条件要从更具体到更一般，否则后面的分支永远到不了。

所有结果分支必须可转换为共同类型。省略 `ELSE` 时，没有 WHEN 命中的行返回 NULL；这有时正确，有时是遗漏。

简单 CASE 则先计算一个表达式，再与各值比较：

```sql
CASE d.status
  WHEN 'ACTIVE' THEN '运行'
  WHEN 'RETIRED' THEN '退役'
  ELSE '未知'
END
```

它适合离散等值映射；范围判断使用搜索式 CASE。

### CASE 的短路边界

CASE 一般只处理决定结果所需的子表达式，常用于保护可能失败的计算。但它不是任意求值顺序的万能开关。PostgreSQL 规划阶段可能预先计算 immutable 常量表达式，因此未被选中的分支里如果写死 `1/0`，仍可能在执行前报错。[PostgreSQL 18 value expressions](https://www.postgresql.org/docs/18/sql-expressions.html)明确说明布尔表达式可被重组，以及常量子表达式可能提前求值。

更好的做法是移除危险恒等式、清理数据或改写公式，而不是制造依赖偶然求值顺序的查询。

## 9. 显式 CAST：转换成功与失败都要进入合同

PostgreSQL 接受两种主要语法：

```sql
CAST(expression AS type)  -- SQL 标准
expression::type          -- PostgreSQL 历史语法
```

二者在这里表示同样的运行时类型转换。标准形式更便于跨数据库阅读；`::` 在 PostgreSQL 项目中很常见。

[PostgreSQL 18 type casts](https://www.postgresql.org/docs/18/sql-expressions.html#SQL-SYNTAX-TYPE-CASTS)说明：只有定义了合适转换时才会成功；自动转换只用于系统目录标记为可隐式应用的 cast，以避免惊讶。

### 不要期待“失败时自动 NULL”

```sql
CAST('12.5' AS numeric)       -- 有效输入
CAST('not-a-number' AS numeric) -- 应报错
```

非法输入不是缺失值。把它静默变成 NULL 会混淆“没提供”和“提供但格式错误”。正确策略应在数据入口验证，或把 staging text 的坏行显式列入拒绝/修复队列；确认格式后再 cast。若业务确实允许容错，也要保存原值、错误类别和规则版本。

隐式 cast 失败的第一处证据通常是 PostgreSQL 的运算符/函数解析错误，例如把 numeric 与 text 直接相加：

```sql
d.temperature_c + d.calibration_text
```

系统不会为了方便就猜测所有 text 都是 numeric。修复不是“到处加 cast 直到不报错”，而是先确认源类型、目标类型、允许格式和坏值策略，再在受控边界显式转换。

还要注意，显式转换到带长度字符类型可能按 SQL 规则截断超长值；“显式”不等于“永不丢信息”。转换前后都需要验证。

## 10. 日期时间类型：先问它代表瞬间还是墙钟

常用类型的核心区别：

| 类型 | 表示 |
| --- | --- |
| `date` | 日历日期，没有时区 |
| `time without time zone` | 一天中的墙钟时间，没有日期/时区上下文 |
| `timestamp without time zone` | 日期 + 墙钟时间，不代表唯一全球瞬间 |
| `timestamp with time zone` / `timestamptz` | 一个全球瞬间，显示时按时区转换 |
| `interval` | 时间跨度 |

[PostgreSQL 18 date/time types](https://www.postgresql.org/docs/18/datatype-datetime.html)说明，timestamptz 输入会转换为 UTC 内部值，原始时区不会保留；输出时再按当前 `TimeZone` 转换。也就是说，列里保存的是瞬间，不是“用户最初键入了 Asia/Shanghai”这个标签。

`timestamp without time zone` 即使输入文本附带时区，类型语义也没有时区。不能靠列名猜测它其实是 UTC；数据合同必须明确。

## 11. AT TIME ZONE：两个方向不要背反

`AT TIME ZONE` 根据左侧类型有两个常见方向：

1. `timestamp without time zone AT TIME ZONE zone`
   把墙钟时间解释为该地区时间，得到一个 `timestamptz` 瞬间。
2. `timestamptz AT TIME ZONE zone`
   把同一瞬间显示为该地区的 `timestamp without time zone` 墙钟时间。

本章的 `last_seen_at` 是 timestamptz，所以：

```sql
d.last_seen_at AT TIME ZONE 'Asia/Shanghai'
```

得到上海当地墙钟时间。再截日：

```sql
date_trunc(
  'day',
  d.last_seen_at AT TIME ZONE 'Asia/Shanghai'
) AS local_day_start
```

以及显式取当地日期：

```sql
CAST(
  d.last_seen_at AT TIME ZONE 'Asia/Shanghai'
  AS date
) AS local_date
```

顺序不能反。固定边界：

```text
2026-07-16T15:59:59Z → 上海 2026-07-16 23:59:59 → local_date 2026-07-16
2026-07-16T16:00:00Z → 上海 2026-07-17 00:00:00 → local_date 2026-07-17
```

如果先把 UTC 显示值 cast 为 date，再转换时区，第二行会被错误归到 7 月 16 日。[PostgreSQL 18 date/time functions](https://www.postgresql.org/docs/18/functions-datetime.html)给出了 `date_trunc` 和 `AT TIME ZONE` 的类型方向。

离线 oracle 对 2026 年上海样例使用固定 `+08:00`。它没有实现 IANA 时区规则，不能推广到有 DST、历史规则变化或未来政策变化的地区。真实验证必须由 PostgreSQL 使用其时区数据库执行。

## 12. “现在”有三种常见时间边界

PostgreSQL 的当前时间函数不是同一个时钟：

| 表达式 | 语义 |
| --- | --- |
| `CURRENT_TIMESTAMP` / `transaction_timestamp()` / `now()` | 当前事务开始时刻 |
| `statement_timestamp()` | 当前语句开始时刻 |
| `clock_timestamp()` | 函数实际调用时刻，同一语句内可变化 |

`CURRENT_TIMESTAMP` 在事务内保持一致，这是为了让一组操作共享“现在”。若你测量耗时或要求真实墙钟变化，`clock_timestamp()` 才符合语义，但其可变性会影响优化与复现。

不要在延后求值的定义里写类型化字面量 `TIMESTAMP 'now'`。官方文档警告它可能在解析时就固化；应使用调用时求值的 current-time 表达式。

## 13. 函数波动性：给优化器的承诺

每个函数属于一类：

- `IMMUTABLE`：相同参数永远得到相同结果；
- `STABLE`：同一语句中相同参数结果一致，但不同语句可变化；
- `VOLATILE`：同一语句甚至同一行间都可能变化，必须在需要处重新求值。

[PostgreSQL 18 function volatility](https://www.postgresql.org/docs/18/xfunc-volatility.html)把这些分类定义为对优化器的承诺。标得过于保守可能错失优化；标得过强则可能产生错误结果，例如 immutable 调用被预计算并在复用计划中变成陈旧常量。

官方说明 current timestamp 系列符合 stable；`clock_timestamp()` 和 `random()` 的值可在语句内变化，属于 volatile 语义。更关键的边界是配置依赖：

> 如果函数结果依赖 `TimeZone` 之类配置，即使参数相同，不同会话设置也可能得到不同结果，就不能诚实承诺 immutable。

本章不创建自定义函数，但阅读查询时必须知道：函数名背后还有波动性、NULL 调用、权限与快照合同。

## 14. 函数表达式与索引边界

查询：

```sql
WHERE lower(d.raw_name) = 'pump beta'
```

普通 `raw_name` 索引通常不能直接充当 `lower(raw_name)` 结果的索引。PostgreSQL 支持在表达式结果上建索引；只有查询表达式与索引表达式匹配时，优化器才有对应的已存结果可用。

[PostgreSQL 18 indexes on expressions](https://www.postgresql.org/docs/18/indexes-expressional.html)用 `lower(col1)` 展示同一模式，并指出表达式索引会增加插入和非 HOT 更新的计算/维护成本。索引不是免费的函数缓存。

表达式索引还要求其中的函数和操作符是 immutable，因为一个已存索引键必须在行未改变时保持有效。一个依赖 session TimeZone 的“当地日期”表达式不能直接被假装成 immutable。常见选择是：

- 把时区作为受控输入，构造真正不依赖会话配置的表达式；
- 存储明确的 UTC 瞬间，并在查询边界转换；
- 若当地日期本身是业务事实，单独建模并规定更新来源；
- 不建表达式索引，接受计算并用真实计划证据评估。

这些是后续索引设计的决策维度。本章只要求你看到 `lower(...)` 或时间表达式时，不想当然地说“原列有索引，所以一定快”。

## 15. 完整构建查询

```sql
SELECT
  d.device_id AS device_id,
  d.raw_name AS raw_name,
  d.alias AS alias,
  d.temperature_c AS temperature_c,
  d.last_seen_at AS last_seen_at,
  lower(btrim(d.raw_name)) AS normalized_name,
  round(d.temperature_c, 1) AS temperature_c_1dp,
  COALESCE(
    NULLIF(btrim(d.alias), ''),
    btrim(d.raw_name)
  ) AS display_name,
  CASE
    WHEN d.temperature_c IS NULL THEN 'UNKNOWN'
    WHEN d.temperature_c < NUMERIC '0' THEN 'FREEZING'
    WHEN d.temperature_c >= NUMERIC '30' THEN 'HOT'
    ELSE 'NORMAL'
  END AS temperature_band,
  date_trunc(
    'day',
    d.last_seen_at AT TIME ZONE 'Asia/Shanghai'
  ) AS local_day_start,
  CAST(
    d.last_seen_at AT TIME ZONE 'Asia/Shanghai'
    AS date
  ) AS local_date
FROM factorycare.device_reading AS d
ORDER BY d.device_id ASC;
```

它没有 WHERE，所以四个输入行都保留。原始列和派生列并排，使验证报告能回答：

1. 输入是什么；
2. 应用了哪个命名操作；
3. 输出是什么；
4. NULL 是否仍可区分；
5. 换日边界是否归到正确当地日期；
6. 行数是否仍为四。

真正执行时还应让客户端显示数据类型，尤其是 `date_trunc`、`AT TIME ZONE` 和 `CAST` 的结果类型。当前离线报告只验证固定文本预言。

## 16. 三个故障注入

### 故障一：先截 UTC 日期，再谈当地时区

错误表达式：

```sql
CAST(d.last_seen_at AS date)
```

在 session TimeZone 不明确时，它依赖会话显示规则；若按 UTC 先取日期，`2026-07-16T16:00:00Z` 得到 7 月 16 日，而上海已经是 7 月 17 日。第一处可信证据是紧邻午夜的两行输入，而不是普通中午样例。

修复：先 `AT TIME ZONE 'Asia/Shanghai'` 得到当地墙钟，再 cast/date_trunc。

### 故障二：用 0 填补未知温度

错误表达式：

```sql
COALESCE(d.temperature_c, 0)
```

第一处可信证据是 D-03：原始值为 NULL，输出却与真实 0°C 无法区分。修复不是换一个更漂亮的默认值，而是保留原始 NULL，CASE 明确映射为 `UNKNOWN`。只有领域正式规定“缺测等同 0”时才能这样填补。

### 故障三：让 numeric 与 text 隐式相加

错误表达式：

```sql
d.temperature_c + d.calibration_text
```

第一处可信证据是运算符类型不匹配；即使强行写 `CAST(calibration_text AS numeric)`，D-03 的 `not-a-number` 仍应成为可见转换错误。修复流程：

1. 查看两列实际类型；
2. 定义 calibration_text 的合法格式和 NULL 规则；
3. 找到第一条坏输入并记录 id、原值和目标类型；
4. 拒绝或修复坏输入；
5. 只在验证后的边界显式 cast；
6. 重新运行并确认没有静默丢失。

## 17. 四类离线资产与证据解释

入口：

```sh
./examples/encyclopedia/ch.data.scalar-functions/verify.sh
./labs/encyclopedia/ch.data.scalar-functions/verify.sh
./exercises/encyclopedia/ch.data.scalar-functions/verify.sh
./solutions-private/encyclopedia/ch.data.scalar-functions/verify.sh
```

- `examples`：对四行生成含原始值、操作名和派生值的固定报告；
- `labs`：注入时区跨日、NULL→0 和 text/numeric 转换故障，并验证 volatility/index 边界声明；
- `exercises`：红色 starter 故意先截 UTC 日期、错误填 NULL、遗漏原始列；
- `solutions-private`：保存完整查询契约和通过预言。

Ruby 使用 `BigDecimal` 模拟本样例的 numeric 半值规则，使用固定 `+08:00` 模拟 2026 上海边界，只对 ASCII 名称调用 `downcase`。这些限制都刻意缩小了离线声明范围。oracle 不是 PostgreSQL 函数实现，也不声称覆盖 locale、所有 numeric scale、DST、类型重载或查询计划。

## 18. 120 秒复述模板

你应能不看答案完成以下口述：

1. 标量表达式每个输入行产生一个值，本身不归约行数；
2. 函数重载意味着先看参数类型，再谈 round 等边界；
3. numeric 半值与 double precision 可能不同；
4. btrim 去边界空格，lower 受 locale 语境影响，字符数不等于字节数；
5. COALESCE 取首个非 NULL，空白字符串要先通过 NULLIF 显式处理；
6. NULL 不应随手填成业务值，CASE 要把 UNKNOWN 分支写出来；
7. cast 非法输入应报错，不能默认静默 NULL；
8. timestamptz 表示瞬间，先转目标时区墙钟，再截当地日；
9. current timestamp 是事务时间，clock timestamp 是实际调用时间；
10. immutable/stable/volatile 是优化承诺；时区依赖限制 immutable；
11. lower(column) 查询可能需要匹配表达式索引，普通列索引不自动等价；
12. 一个失败反例是 UTC 16:00 已是上海次日，先 cast date 会跨日归错。

如果不能解释 D-03 的 NULL 与真实 0 为什么不同，或不能说清 AT TIME ZONE 两个方向，就尚未达到诊断结果。

## 19. 官方依据与版本边界

本章只采用 PostgreSQL 18 官方主文档：

- [数学函数与数值类型边界](https://www.postgresql.org/docs/18/functions-math.html)
- [字符串函数](https://www.postgresql.org/docs/18/functions-string.html)
- [条件表达式：CASE、COALESCE、NULLIF](https://www.postgresql.org/docs/18/functions-conditional.html)
- [值表达式与类型转换](https://www.postgresql.org/docs/18/sql-expressions.html)
- [日期时间函数、截断、时区与当前时间](https://www.postgresql.org/docs/18/functions-datetime.html)
- [日期时间类型与存储/显示规则](https://www.postgresql.org/docs/18/datatype-datetime.html)
- [函数波动性类别](https://www.postgresql.org/docs/18/xfunc-volatility.html)
- [表达式索引](https://www.postgresql.org/docs/18/indexes-expressional.html)
- [`CREATE INDEX` 的函数限制](https://www.postgresql.org/docs/18/sql-createindex.html)

稳定核心是逐行标量、显式类型/NULL 规则、瞬间与墙钟区分、波动性承诺。版本敏感面包括具体 overload、locale/collation、时区数据库、平台浮点、优化器、系统目录 volatility 标记和错误文本。真实 PostgreSQL 18.4 执行尚未验证；离线 PASS 不能替代 server 上的类型检查、时区结果与 EXPLAIN 证据。
