---
schema_version: 2
edition: 2026.2-draft
id: ch.data.pandas
title: Pandas 表格、缺失值、连接与数据清洗
responsibility: 用 Series/DataFrame、索引、缺失值、groupby、merge 和类型转换清洗表格数据，整合 Python 与 NumPy 能力，防止静默行数膨胀。
volume: '12'
order: 19
level: L2+
status: drafting
path: book/volume-12-python-data/chapters/ch.data.pandas.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.files-json-time
- ch.data.numpy
version_surfaces:
- python-3.14
- pandas
- numpy
- pytest
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“Pandas 表格、缺失值、连接与数据清洗”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - pandas-frame-clean
  - pandas-aggregate-merge
  covers_topics:
  - pandas.series-dataframe
  - pandas.index-column
  - pandas.missing-value
  - pandas.dtype-conversion
  - pandas.vectorized-cleaning
  - pandas.groupby-aggregate
  - pandas.merge-join
  - pandas.merge-cardinality
  - pandas.duplicate-row
  - numpy.shape-axis
  uses_capabilities:
  - python.language
  - foundation.files-path-encoding
  - data.numpy-pandas
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 清洗设备与工单脏数据、验证连接基数并生成按类别/技师汇总表；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - pandas-frame-clean
  - pandas-aggregate-merge
  covers_topics:
  - pandas.series-dataframe
  - pandas.index-column
  - pandas.missing-value
  - pandas.dtype-conversion
  - pandas.vectorized-cleaning
  - pandas.groupby-aggregate
  - pandas.merge-join
  - pandas.merge-cardinality
  - pandas.duplicate-row
  - numpy.shape-axis
  uses_capabilities:
  - python.language
  - foundation.files-path-encoding
  - data.numpy-pandas
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: row-count-invariant-pandas-assertions-dirty-data-fixture
- id: diagnose
  kind: fault-diagnosis
  text: 面对“隐式 dtype、链式赋值、缺失值误判或多对多 merge 行爆炸”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - pandas-frame-clean
  - pandas-aggregate-merge
  covers_topics:
  - pandas.series-dataframe
  - pandas.index-column
  - pandas.missing-value
  - pandas.dtype-conversion
  - pandas.vectorized-cleaning
  - pandas.groupby-aggregate
  - pandas.merge-join
  - pandas.merge-cardinality
  - pandas.duplicate-row
  - numpy.shape-axis
  uses_capabilities:
  - python.language
  - foundation.files-path-encoding
  - data.numpy-pandas
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Pandas 表格、缺失值、连接与数据清洗

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Path、编码、文件、JSON 与时间数据》](ch.python.files-json-time.md)：表格摄取需要正确处理路径、编码、JSON/CSV 时间数据。
- [《NumPy 数组、形状、广播与向量化》](ch.data.numpy.md)：Pandas 的 dtype、shape、向量化和缺失值与 NumPy 数组模型相连。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。截至 2026-07-24，pandas 官方当前稳定线为 3.0.4；本仓库资产实际在 Python 3.14.3、pandas 3.0.2、NumPy 2.4.4 上运行，未安装 pytest。正文说明 pandas 3.0 默认字符串 dtype 与 Copy-on-Write 语义，资产只证明本机内存 DataFrame 合同，没有验证 3.0.4 patch、PyArrow 后端、数据库、Excel 引擎、分布式执行或真实生产数据。

表格数据很少天然干净。设备编号可能有前后空格，关闭时长可能是字符串，空值可能写成空串、`NULL` 或真正缺失，设备维表可能重复主键。pandas 让开发者用 Series、DataFrame、向量化清洗、groupby 和 merge 快速处理这些问题，也会让错误在没有异常时悄悄扩大：字符串列推断漂移、链式赋值没有生效、`count` 忽略缺失、多对多 merge 把五行变成几十行。

本章把 DataFrame 当“带标签、每列有 dtype 的二维数据结构”，不把它当电子表格魔法。每次清洗都要有输入 schema、行数与键唯一性预言；每次连接都要声明基数；每次聚合都要说明分组键缺失和计数规则。FactoryCare 中结果只作为可重建派生报表或模型输入，不能反向成为 Java 工单事实。

## 1. 完成定义、资产入口与边界

完成本章后，你应能：

1. 区分 Series、DataFrame、Index 与普通二维 NumPy 数组；
2. 理解 index 是标签，不等于始终连续的行号，并正确选择 `loc`/`iloc`；
3. 在摄取后立即检查列集合、行数、dtype、缺失、唯一键与时间时区；
4. 正确使用 pandas nullable dtype、`string`、`Int64`、`boolean` 和 timezone-aware datetime；
5. 用 `isna` 识别缺失，区分 `pd.NA`、NaN、NaT、空串和业务上的“未知”；
6. 使用向量化字符串/数值/时间转换，保留失败掩码，不静默吞掉脏值；
7. 在 pandas 3.0 Copy-on-Write 下使用单步 `loc` 或 `assign`，避免链式赋值；
8. 用 groupby + named aggregation 生成可解释汇总，区分 `size` 与 `count`；
9. 用 merge 的 `validate`、`indicator`、键唯一性与行数不变量防止静默膨胀；
10. 用 `pandas.testing` 和独立手算验证排序、dtype、缺失和结果值。

配套入口：

- [设备/工单清洗、基数验证与汇总示例](../../../examples/encyclopedia/ch.data.pandas/README.md)
- [dtype、缺失、链式赋值与 merge 爆炸实验](../../../labs/encyclopedia/ch.data.pandas/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.data.pandas/README.md)

本章不把 pandas 当事务存储，不处理超出单机内存的数据湖，也不把 DataFrame 直接写回核心 schema。Java 仍拥有授权、状态迁移和业务事实；Python 只读取授权后的快照，生成可删除重算的报表与特征。

## 2. Series、DataFrame 与 Index

```python
import pandas as pd

durations = pd.Series([30, 45, 20], name="duration_min")
orders = pd.DataFrame(
    {
        "order_id": ["WO-1", "WO-2", "WO-3"],
        "technician_id": ["T-1", "T-1", "T-2"],
        "duration_min": [30, 45, 20],
    }
)
```

Series 是一维带标签数组；DataFrame 是共享行索引、各列可有不同 dtype 的二维表。`orders.shape == (3,3)`，第一个数是行数，第二个是列数。它与二维 ndarray 最大差异之一是列可异质并有标签对齐。

### 2.1 index 不是普通列

默认 RangeIndex 看起来像 0、1、2，但筛选后可能变成 0、2：

```python
filtered = orders[orders["duration_min"] < 40]
assert filtered.index.tolist() == [0, 2]
```

`filtered.loc[2]` 按标签取，`filtered.iloc[1]` 按位置取，二者恰好指向同一行只是此例。不要假设 index 永远连续；需要整洁输出可 `reset_index(drop=True)`，但不能因此丢掉有业务含义的索引。

### 2.2 是否把业务键设成 index

`set_index("order_id")` 可让标签选择更自然，但不会自动证明唯一。业务连接常把键保留为普通列，更容易检查、序列化和 merge。若设 index，立即验证 `index.is_unique`，并明确 reset/merge 后如何恢复。index 是数据模型决策，不是美化输出。

### 2.3 标签自动对齐

两个 Series 运算按 index 对齐，不按当前位置：

```python
left = pd.Series([10, 20], index=["A", "B"])
right = pd.Series([1, 2], index=["B", "A"])
result = left + right
assert result.loc["A"] == 12
```

自动对齐很强，也可能生成意外缺失。需要纯位置计算时先验证相同 index 或转 ndarray，并明确失去标签的后果。

## 3. 构造与摄取：先建立 schema 观察

真实输入可来自 CSV、JSON、Parquet、SQL。无论入口，第一步不是立即 groupby，而是保存数据画像：

```python
def profile(frame: pd.DataFrame) -> dict[str, object]:
    return {
        "shape": frame.shape,
        "columns": frame.columns.tolist(),
        "dtypes": frame.dtypes.astype(str).to_dict(),
        "missing": frame.isna().sum().to_dict(),
        "duplicate_rows": int(frame.duplicated().sum()),
    }
```

日志应避免输出完整个人数据，只保存行数、字段、dtype、缺失率、哈希或脱敏样本。CSV 是无 schema 文本，推断可能因某个脏值把整列变字符串；正式管线应声明 dtype、encoding、日期解析和大小限制，并对失败行建立隔离策略。

### 3.1 列集合合同

```python
required = {"order_id", "technician_id", "duration_min", "closed_at"}
missing = required - set(frame.columns)
if missing:
    raise ValueError(f"missing columns: {sorted(missing)}")
```

同时决定未知列是允许、告警还是拒绝。仅检查必需列不防止上游拼错后同时保留旧列；版本化 schema 更可靠。

### 3.2 读取路径与编码

```python
frame = pd.read_csv(path, encoding="utf-8")
```

路径必须来自可信根，编码显式。`read_csv` 的 dtype、na_values、keep_default_na、parse_dates 等会改变结果，必须锁定并测试。不要只在 REPL 让 pandas 猜测，然后把猜测当长期合同。

## 4. dtype：列的运行语义

查看：

```python
frame.dtypes
frame.info()
```

常见 dtype：数值、布尔、字符串、datetime、timedelta、category，以及回退的 object。`object` 可能混装任意 Python 对象，是“需要进一步调查”的信号，不等于字符串。

### 4.1 pandas 3.0 默认字符串变化

pandas 3.0 默认使用专用 string dtype；若安装 PyArrow，内部后端可能不同，否则回退到 NumPy object-backed 实现。代码应依赖公开字符串语义，不依赖底层数组类。升级 2.x → 3.x 时，字符串缺失值和推断可能影响测试与序列化，必须保存实际 `pandas.__version__` 和 dtype。

显式转换：

```python
frame["order_id"] = frame["order_id"].astype("string")
```

ID 应保持字符串，不能转整数后丢前导零。

### 4.2 nullable 整数与布尔

传统 NumPy int 不能表达 NaN，带缺失整数过去常被提升为 float。pandas 扩展 dtype `Int64` 可保存整数与 `pd.NA`：

```python
frame["duration_min"] = pd.to_numeric(
    frame["duration_min"], errors="coerce"
).astype("Int64")
```

注意大小写：`Int64` 是 nullable 扩展 dtype，`int64` 是 NumPy 整数。`boolean` 同理支持三值。选择前要定义缺失能否存在；核心必填字段不应因可空 dtype 就默许缺失。

### 4.3 `to_numeric` 与失败掩码

`errors="coerce"` 把解析失败变缺失，便于批量清洗，也容易吞掉错误。正确模式：先记录原始非空值，再比较转换后的 NA：

```python
raw = frame["duration_raw"].astype("string").str.strip()
converted = pd.to_numeric(raw, errors="coerce")
invalid = raw.notna() & raw.ne("") & converted.isna()
if invalid.any():
    bad_rows = frame.loc[invalid, ["order_id", "duration_raw"]]
```

生产日志只记录安全标识与计数，原始脏值进入受控隔离区。

### 4.4 时间 dtype

```python
closed_at = pd.to_datetime(frame["closed_at"], errors="coerce", utc=True)
```

`utc=True` 将可解析带偏移时刻规范为 UTC。无偏移文本是否允许必须由协议决定；不能默认当 UTC。解析失败同样保留 invalid mask。pandas 3.0 时区实现默认转向标准库 zoneinfo 等版本表面，业务仍需存储事件时刻与原始地区规则的区别。

## 5. 缺失值不是空字符串

pandas 可能用 `pd.NA`、`np.nan`、`NaT` 表达不同 dtype 的缺失。统一检测：

```python
frame.isna()
frame["technician_id"].isna()
```

不要写 `value == np.nan`；NaN 不等于自身。`pd.NA` 参与比较可能产生 `<NA>`，转 bool 可能歧义。用 `isna/notna` 表达意图。

### 5.1 空串、空白与缺失

`""`、`"   "` 默认可能是普通字符串。业务清洗可先 strip，再把空串映射缺失：

```python
cleaned = frame["technician_id"].astype("string").str.strip()
cleaned = cleaned.mask(cleaned.eq(""), pd.NA)
```

但设备备注允许空串、工单处理人不允许缺失，规则按字段定义。全表 `replace("", pd.NA)` 可能错误改变合法字段。

### 5.2 drop、fill 与业务含义

`dropna` 删除行，`fillna` 填充。两者都不是无害清理：删除会改变样本和汇总，填 0 会把未知时长伪装成零分钟。每次操作记录：目标列、前后行数、缺失数、替代值含义和下游影响。

### 5.3 `size` 与 `count`

groupby 中 `size` 统计行数，包括目标列缺失；`count` 按列统计非缺失值：

```python
groups = frame.groupby("technician_id", dropna=False)
rows = groups.size()
valid_durations = groups["duration_min"].count()
```

工单数通常用 size；有效时长样本数用 count。混用会造成 KPI 偏差。

## 6. 选择与赋值：`loc`、`iloc` 和 Copy-on-Write

按标签：

```python
frame.loc[frame["status"].eq("CLOSED"), ["order_id", "duration_min"]]
```

按位置：

```python
frame.iloc[:10, :3]
```

### 6.1 链式赋值为什么危险

```python
# 错误模式
frame[frame["duration_min"] < 0]["duration_min"] = pd.NA
```

这是先选子对象再赋值。历史版本中可能产生 SettingWithCopyWarning 或难以预测；pandas 3.0 Copy-on-Write 是默认且唯一语义，链式赋值不会更新原 DataFrame，并会发出警告。正确写成单步：

```python
mask = frame["duration_min"].lt(0)
frame.loc[mask, "duration_min"] = pd.NA
```

或用函数式 `assign` 返回新表。不要通过关闭 warning 修复逻辑。

### 6.2 Copy-on-Write 不等于深复制一切

CoW 延迟复制，让派生对象修改不影响原对象，提升一致性；底层可能共享只读数据直到写入。它不保证 Python object 列中嵌套可变对象的深隔离，也不替代并发事务。避免 DataFrame 单元格存 list/dict。

### 6.3 明确返回新表还是原地修改

清洗函数推荐接收 DataFrame 后先选择必要列并构造结果，返回新对象；文档说明不修改调用者输入。测试保存输入深度足够的快照并用 `assert_frame_equal` 比较。`inplace=True` 不必然更省内存，pandas 3 CoW 下更应优先清晰数据流。

## 7. 向量化清洗

字符串：

```python
clean_id = (
    frame["device_id"]
    .astype("string")
    .str.strip()
    .str.upper()
)
```

数值：

```python
duration = pd.to_numeric(frame["duration_raw"], errors="coerce")
duration = duration.mask(duration.lt(0), pd.NA).astype("Float64")
```

条件列：

```python
frame = frame.assign(
    is_long=frame["duration_min"].ge(60).fillna(False)
)
```

### 7.1 避免逐行 `iterrows`

逐行 Python 循环慢且容易丢 dtype。优先列运算、map、merge、groupby。若规则极复杂，先确认能否拆成向量化条件；若必须 Python 函数，明确性能和类型边界。`apply` 也不是自动向量化，常仍逐行执行。

### 7.2 `query` 与动态输入

`query` 可读性好，但不要拼接不可信字符串形成表达式注入。列选择和过滤条件优先显式 Series 表达式；动态规则需要受控 DSL 或白名单。

## 8. 重复：重复行与重复键不同

```python
frame.duplicated()
frame.duplicated(subset=["order_id"], keep=False)
```

完全重复行可能来自重复导出；业务键重复可能表示不同版本、合法一对多或上游错误。不能无条件 `drop_duplicates()`：保留 first/last 依赖当前排序，可能随机丢事实。

清理前定义：

- 唯一键是什么；
- 重复是否允许；
- 若只保留最新，按哪个 aware 时间和 tie-breaker；
- 删除多少行；
- 被删除行是否归档/审计。

维表 `device_id` 预期唯一时：

```python
duplicate = devices["device_id"].duplicated(keep=False)
if duplicate.any():
    raise ValueError("device dimension has duplicate keys")
```

失败优于 merge 后静默膨胀。

## 9. groupby：split—apply—combine

按 technician 汇总：

```python
summary = (
    closed_orders
    .groupby("technician_id", dropna=False, as_index=False)
    .agg(
        ticket_count=("order_id", "size"),
        valid_duration_count=("duration_min", "count"),
        mean_duration_min=("duration_min", "mean"),
        max_duration_min=("duration_min", "max"),
    )
)
```

named aggregation 让输出列名与函数明确。默认 groupby 对缺失键的处理可能丢弃缺失组；显式 `dropna=False` 可保留“未分配”组，再由业务决定是否报错。

### 9.1 聚合、变换、过滤

- `agg`：每组变成一个或少量汇总；
- `transform`：返回与原行对齐的结果，例如组内标准化；
- `filter`：按组条件保留/删除整组；
- `apply`：灵活但慢、schema 更难预测，能用专门操作就不用。

先写预期输出 grain：一行是“每技师”还是“每技师每天”。grain 不清楚，连接和指标都会重复。

### 9.2 categorical 分组版本表面

category dtype 的未观察类别是否出现在结果受 `observed` 参数与版本默认影响。正式代码显式传值，并为零样本类别写测试。pandas 升级时检查 FutureWarning，不靠默认。

### 9.3 排序与确定性

groupby/merge 输出顺序不是业务合同时，测试前按稳定键排序并 reset index。不要只因为当前结果顺序“看起来对”就依赖它。需要排名时显式排序规则和 tie-breaker。

## 10. merge：连接前先声明基数

```python
enriched = orders.merge(
    devices,
    how="left",
    on="device_id",
    validate="many_to_one",
    indicator=True,
)
```

`validate` 可选语义包括 one-to-one、one-to-many、many-to-one、many-to-many。对“多张工单属于一个设备”，左表 order 多，右表 device 唯一，因此 many_to_one。若维表重复，立即报错。

### 10.1 连接类型

- inner：只保留双方匹配；
- left：保留所有左行；
- right：保留所有右行；
- outer：保留双方并集；
- cross：笛卡尔积，行数相乘。

选择由业务问题决定。生成“所有工单及设备类别”常用 left，并检查 `_merge` 中 left_only；inner 会静默删除未知设备工单。

### 10.2 行数膨胀的数学

某键左侧出现 m 次、右侧出现 n 次，inner merge 对该键产生 m×n 行。若两侧都重复，就是多对多爆炸：

```text
orders: device A 有 3 行
devices: device A 有 2 行
结果: A 有 6 行
```

总行数增长不是 pandas bug。修复要回到 grain 和唯一键：维表去重规则是否可靠、历史版本是否应按有效期连接、还是业务确实需要多对多桥接。不要 merge 后随手 drop_duplicates，这会隐藏错误组合。

### 10.3 空键连接与 SQL 不同

pandas merge 文档警告：双方连接键均为空的行可能互相匹配，这与常见 SQL NULL 不匹配行为不同。连接前应根据合同拒绝/隔离缺失键，不能指望数据库直觉。

### 10.4 同名列与 suffix

除连接键外同名列会得到 suffix。显式选择/重命名列，比事后猜 `_x/_y` 所有者可靠：

```python
devices_for_join = devices[["device_id", "category"]]
```

若两侧字段表达不同时间版本，应采用语义名，例如 `order_recorded_category` 与 `current_device_category`。

### 10.5 indicator 与覆盖率

`indicator=True` 生成 `_merge`：left_only、right_only、both。保存计数作为数据质量证据：

```python
coverage = enriched["_merge"].value_counts(dropna=False)
```

验证后再删除辅助列。成功连接不能只看没有异常，还要看覆盖率和前后行数。

## 11. 连接不变量模板

在 merge 前后记录：

```python
left_rows = len(orders)
assert devices["device_id"].is_unique

result = orders.merge(
    devices,
    how="left",
    on="device_id",
    validate="many_to_one",
    indicator=True,
)

assert len(result) == left_rows
assert result["order_id"].is_unique == orders["order_id"].is_unique
```

对于合法 one-to-many，行数本来会增长，预言应换成每个左键的预期匹配数，而不是强制相等。先定义 cardinality，再写断言。

## 12. FactoryCare 脏数据管线

设备维表示例：

```python
devices = pd.DataFrame(
    {
        "device_id": [" d-1 ", "D-2", "D-3"],
        "category": ["pump", "motor", pd.NA],
    }
)
```

工单快照：

```python
orders = pd.DataFrame(
    {
        "order_id": ["WO-1", "WO-2", "WO-3", "WO-4"],
        "device_id": ["D-1", "D-2", "D-2", "D-9"],
        "technician_id": ["T-1", " T-1 ", pd.NA, "T-2"],
        "duration_raw": ["30", "bad", "45", " 60 "],
        "status": ["CLOSED", "CLOSED", "CREATED", "CLOSED"],
    }
)
```

步骤：

1. 复制/选择需要列，记录输入 shape；
2. 清洗 ID 的 string、strip、upper，空串转 NA；
3. 数值转换并保存 invalid mask；
4. 验证 order_id 唯一、device_id 维表唯一；
5. 仅筛选 CLOSED，但保留脏数值质量报告；
6. many_to_one left merge，检查 `_merge`；
7. groupby category/technician，明确 dropna；
8. 对输出排序、重建连续索引、固定 dtype；
9. 输出汇总及数据质量元数据；
10. 标注生成时间、来源时间窗和 Java 查询版本。

不要直接回写清洗后的 status 或 assignee。若发现 Java 数据质量问题，生成诊断报告和可审计修复建议，由权威服务执行。

## 13. 时间、时区与周期汇总

```python
closed_at = pd.to_datetime(raw, errors="coerce", utc=True)
```

确认原始非空但解析后缺失的行。按本地日汇总前，将 UTC 转站点时区：

```python
local = closed_at.dt.tz_convert("Asia/Shanghai")
business_date = local.dt.date
```

不要先去掉时区再转换。夏令时地区还要测试歧义/不存在时间。`dt.date` 产生 Python object，后续性能/序列化要注意；可按 normalized timestamp 或 Period 建模，具体取决于输出合同。

## 14. 输出与可复现性

输出前固定：

- 列顺序和名称；
- dtype 与时区；
- 排序键与 tie-breaker；
- 缺失表示；
- 浮点精度/舍入；
- schema 版本；
- 行 grain；
- 来源快照 ID；
- 生成代码/依赖版本。

CSV 会丢 dtype 和时区细节，适合交换但需 companion schema。Parquet 保留更多类型，却受引擎版本影响；本章不验证 PyArrow。JSON 输出遵循上一章显式版本和时间合同。

## 15. pandas.testing 与独立预言

```python
from pandas.testing import assert_frame_equal, assert_series_equal
```

比较前按业务键排序、reset index，再明确是否检查 dtype、列顺序和浮点容差。不要把 `check_dtype=False` 作为默认，否则 `Int64` 退化 float 可能被掩盖。

测试矩阵：

| 风险 | 输入 | 预言 |
| --- | --- | --- |
| 缺失 | pd.NA、NaN、空串、空白 | 每列缺失/非法计数 |
| dtype | 整数文本、bad、前导零 ID | 转换值与失败掩码 |
| 重复 | 完全重复、键重复 | 删除/拒绝策略与行数 |
| merge | 1:1、N:1、1:N、N:M | validate、行数、覆盖率 |
| groupby | 缺失组、缺失值 | size/count 和 dropna 结果 |
| 时间 | UTC、+08:00、坏值 | 规范时刻与失败数 |
| CoW | 派生表修改 | 原表不变；链式赋值失败证据 |

本机资产没有 pytest，因此未验证 pytest fixture、参数化和 warning 捕获；只使用 pandas 官方测试函数与普通 Python 断言。正式项目补充锁定 pytest 后，应把 warning 当测试证据，而不是关闭。

## 16. 故障诊断阶梯

### 16.1 指标数量少了

检查过滤条件、inner merge 是否丢行、groupby 是否默认丢缺失键、count 是否忽略缺失。比较每步行数和 `_merge` 计数，不要只看最终总数。

### 16.2 merge 后数量暴增

分别计算两侧 `value_counts`、唯一性与每键乘积。使用正确 `validate` 让错误在连接点失败。若确需多对多，先设计桥表 grain 和预期上限。

### 16.3 修改没有生效

搜索链式索引，改为单步 `.loc[mask, column] = value` 或 `assign`。在 pandas 3 CoW 下不应依赖临时对象回写原表。开启/保留 ChainedAssignmentError 警告。

### 16.4 列突然是 object/string

查看摄取参数与首个不能解析值，保留原始列和 invalid mask。不要直接 `astype(float)` 后只处理最后异常；批量 `to_numeric` 加质量表更可控。

### 16.5 缺失比较结果异常

用 isna/notna；不要 `== pd.NA` 或把 `pd.NA` 直接转 bool。明确三值逻辑在过滤时如何处理，必要时 `fillna(False)` 并说明含义。

## 17. 性能与规模边界

pandas 主要面向内存表格分析。性能原则：

- 摄取时只读必要列并声明 dtype；
- 使用向量化列操作而非逐行 Python；
- 避免 object 列和嵌套对象；
- category 只在重复有限集合且语义稳定时使用；
- 避免无界 cross/many-to-many join；
- 观察内存、行数和临时对象；
- 大数据考虑数据库聚合、分块或专门引擎，但保持同一 schema/预言。

不要把“能在笔记本跑完”当生产容量证明。记录峰值内存、输入分布、版本、硬件和耗时。分块读取会改变全局去重、排序和 groupby 设计，需要可合并算法。

## 18. 安全与隐私

DataFrame 容易在 notebook、异常、日志中打印整表。生产规则：

- 只读取授权租户与必要列；
- 样例数据脱敏且不可逆；
- 日志只记录计数、schema、哈希与安全 ID；
- 导出路径受可信根约束；
- CSV/Excel 供人下载时防公式注入；
- 报表按最小权限发布；
- 临时文件有生命周期与权限；
- 派生表带来源和过期时间；
- 删除可重建数据不影响核心事实。

pandas 无法替你执行 Java 授权。先由权威服务限制数据，再进入 Python。

## 19. 常见误区与修正规则

**“DataFrame 就是带列名的二维数组。”** 它有异质 dtype 和标签对齐。规则：同时检查 shape、index、columns、dtypes。

**“index 就是行号。”** 筛选后标签可不连续。规则：标签用 loc，位置用 iloc。

**“object 就代表字符串。”** 可混装任意对象。规则：显式 string/nullable dtype。

**“coerce 后没有异常就是清洗成功。”** 脏值被变 NA。规则：保留 invalid mask 和计数。

**“缺失都填 0。”** 未知不等于零。规则：字段级业务策略。

**“链式赋值有 warning 但通常能用。”** pandas 3 CoW 下不会更新原表。规则：单步 loc/assign。

**“merge 不报错就正确。”** 多对多可静默膨胀。规则：每次声明 validate 与行数预言。

**“drop_duplicates 能修重复。”** 它可能随排序随机丢事实。规则：先定义唯一键和保留规则。

**“count 就是组内行数。”** count 忽略目标列缺失。规则：工单行数用 size，样本数用 count。

## 20. 独立构建任务

实现 `build_closed_order_summary(orders, devices)`：

1. 不修改调用者 DataFrame；
2. 检查必需列与输入 shape；
3. order/device/technician ID 转 string、strip、upper；
4. 空 ID 转 NA，order_id 必填且唯一；
5. duration 用 to_numeric，保存非法掩码，负数拒绝；
6. closed_at 解析 aware UTC，保存失败掩码；
7. devices 的 device_id 必须唯一；
8. CLOSED 工单 left merge 设备，validate many_to_one，indicator 覆盖率；
9. 输出按 category、technician 的 ticket_count、valid_duration_count、mean_duration；
10. 明确保留/拒绝缺失分组；
11. 保存空输入、脏数值、重复设备键、未知设备、缺失技师、多对多注入、跨时区七组证据；
12. 输出质量报告与可重建标记，不回写 Java。

## 21. 自检问题

1. Series 运算为何可能按标签而非位置对齐？
2. `.loc[2]` 与 `.iloc[2]` 各自是什么意思？
3. pandas 3.0 字符串 dtype 有什么版本变化？
4. `Int64` 与 `int64` 的缺失语义有什么区别？
5. `errors="coerce"` 后如何找真正脏值？
6. `pd.NA` 为什么不能直接当 bool？
7. groupby size 与 count 何时不同？
8. Copy-on-Write 下链式赋值为什么不更新原表？
9. many_to_one 的左右表 grain 分别是什么？
10. 两侧每键出现 m/n 次时 merge 产生几行？
11. pandas 空键连接与 SQL NULL 有什么重要差异？
12. 为什么清洗后的 DataFrame 不能直接覆盖 Java 工单状态？

## 22. 官方资料与版本说明

以下官方资料在 2026-07-24 核对：

- [pandas release notes](https://pandas.pydata.org/docs/whatsnew/index.html)：当前 3.0.4 patch 与版本修复；
- [pandas 3.0.0 release notes](https://pandas.pydata.org/docs/whatsnew/v3.0.0.html)：默认 string dtype、Copy-on-Write 与迁移变化；
- [Intro to data structures](https://pandas.pydata.org/docs/user_guide/dsintro.html)：Series、DataFrame、Index 与对齐；
- [Working with missing data](https://pandas.pydata.org/docs/user_guide/missing_data.html)：NA、NaN、NaT 与 nullable dtype；
- [Copy-on-Write](https://pandas.pydata.org/docs/user_guide/copy_on_write.html)：pandas 3.0 唯一复制语义和链式赋值；
- [Group by](https://pandas.pydata.org/docs/user_guide/groupby.html)：split-apply-combine、agg/transform/filter；
- [Merge, join, concatenate](https://pandas.pydata.org/docs/user_guide/merging.html) 与 [pandas.merge API](https://pandas.pydata.org/docs/reference/api/pandas.merge.html)：基数验证、indicator、空键与 CoW；
- [pandas testing](https://pandas.pydata.org/docs/reference/testing.html)：Series/DataFrame 官方断言。

Series/DataFrame、标签对齐、缺失检测、groupby 和连接基数属于稳定核心；默认 string dtype、CoW、category 参数默认、时区后端和 copy 参数属于 pandas 3.x 版本表面。正式项目通过 uv 锁定 pandas/NumPy/pytest，升级后必须重跑 dtype、warning、缺失、行数和 merge 基数夹具。

## 23. 本章小结

pandas 把标签、列 dtype 和表格操作组合起来，适合将脏快照变成可解释派生数据。它的最大风险不是语法报错，而是静默语义变化：标签自动对齐、coerce 产生 NA、count 忽略缺失、链式赋值失效、多对多连接膨胀。可靠管线必须在每一步保存 shape、dtype、缺失、唯一性、基数与覆盖率证据。

最可复用的规则是：**摄取后立刻画像，类型转换保留失败掩码，赋值使用单步 loc/assign，groupby 先定义 grain，merge 必须声明 cardinality，所有输出都带行数与数据质量报告。**
