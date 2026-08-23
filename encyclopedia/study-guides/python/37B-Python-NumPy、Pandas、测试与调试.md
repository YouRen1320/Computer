# Python：NumPy、Pandas、测试与调试

## 1. NumPy 适合处理规则形状的同类数值

Python 列表可以混合多种对象，NumPy 的 `ndarray` 通常保存同一种数据类型，并以规则的多维形状组织数据。

```python
import numpy as np

durations = np.array([30, 45, 60], dtype=np.int64)
```

这种约束让批量数值运算更紧凑、更快，也意味着形状和 `dtype` 都是计算合同的一部分。

## 2. `ndim`、`shape`、`size` 和 `dtype` 是首要观察值

```python
matrix = np.array([[30, 45], [60, 90]], dtype=np.int64)

matrix.ndim   # 2
matrix.shape  # (2, 2)
matrix.size   # 4
matrix.dtype  # int64
```

看到数组先问：每个轴代表什么、每个元素单位是什么、数据类型是否足够。只看打印出的数字很容易漏掉转置和精度错误。

## 3. 一维、二维列向量和标量形状不同

```text
标量：shape = ()
一维向量：shape = (n,)
二维列：shape = (n, 1)
二维行：shape = (1, n)
```

它们包含的元素数可能相同，但广播和矩阵运算的结果不同。机器学习代码中应给轴加业务解释，如 `(batch, features)`，不要只记数字。

## 4. `dtype` 决定表示范围和运算方式

```python
amounts = np.array([1_999, 2_999], dtype=np.int64)
temperatures = np.array([20.5, 21.0], dtype=np.float64)
```

固定宽度整数可能溢出，浮点数可能有舍入误差。`astype` 会尝试转换，但“能转换”不表示符合业务规则。

货币仍应选择清晰的整数单位或经过设计的精确表示，不能因为用了数组就忽略数值边界。

## 5. 索引和切片可能返回共享数据的视图

```python
values = np.array([10, 20, 30, 40])
part = values[1:3]
part[0] = 999
```

基础切片通常是 view（视图），修改 `part` 可能同时修改 `values`。高级索引通常产生 copy（副本），但不要靠感觉猜。

如果所有权要求独立数据，显式调用 `.copy()`，并在测试中检查原数组是否保持不变。

## 6. 布尔 mask 用于逐元素筛选

```python
priorities = np.array([2, 5, 3, 5])
critical = priorities[priorities == 5]
```

数组条件需要逐元素运算符。组合多个条件时使用 `&`、`|` 并给每个比较加括号：

```python
selected = priorities[(priorities >= 3) & (priorities <= 5)]
```

Python 的 `and` / `or` 不是数组逐元素逻辑。

## 7. `reshape` 改变观察形状，不改变元素总数

```python
values = np.arange(6)
matrix = values.reshape(2, 3)
```

新形状各维度乘积必须等于元素总数。`-1` 可以让 NumPy 推断一个维度，但仍应明确每个轴的业务含义。

`flatten()` 通常复制，`ravel()` 尽量返回视图；是否共享会影响修改和内存。

## 8. `axis` 表示聚合掉哪个维度

假设矩阵形状是 `(technicians, days)`：

```python
daily_totals = hours.sum(axis=0)       # 去掉 technicians 轴
technician_totals = hours.sum(axis=1)  # 去掉 days 轴
```

不要死记“0 是列、1 是行”。更可靠的方法是写出输入 shape、轴标签和预期输出 shape。

## 9. 广播让兼容形状自动扩展

```python
hours = np.array([[1, 2, 3], [4, 5, 6]])
rates = np.array([100, 200, 300])
costs = hours * rates
```

NumPy 从末尾维度向前比较：维度相等，或其中一个为 1，才兼容。广播通常不需要真的复制小数组。

能广播不代表业务正确。错误的 `(batch, 1)` 与 `(batch,)` 可能得到意外的 `(batch, batch)`，所以结果 shape 也必须检查。

## 10. 向量化是把批量意图交给数组运算

```python
totals = unit_prices * quantities
```

这比 Python 中逐元素循环更容易利用底层优化。`np.vectorize` 主要提供调用方便，通常不是把普通 Python 函数变成真正高性能内核。

向量化也可能生成大型临时数组。性能问题要同时测时间、内存和数据规模。

## 11. NaN、无穷和缺失需要显式处理

浮点 `NaN` 不等于自身，因此不能用 `value == np.nan` 判断。使用 `np.isnan`、`np.isfinite` 等函数。

```python
valid_mask = np.isfinite(durations)
clean = durations[valid_mask]
```

忽略 NaN 的聚合函数可能方便，但必须先确认“跳过缺失”符合业务，不要让缺测设备悄悄从 SLA 统计中消失。

## 12. 数值 warning 也可能意味着结果不可信

除零、无效运算和溢出有时只产生 warning 和 `inf`/`nan`，程序仍继续。关键计算可用 `np.errstate` 明确策略，并对结果做有限性、范围和 shape 检查。

“函数返回了数组”不代表计算成功。

## 13. Pandas 用 Series 和 DataFrame 表达带标签的数据

`Series` 类似一列带索引的数据，`DataFrame` 类似多列共享行索引的表格。

```python
import pandas as pd

orders = pd.DataFrame({
    "order_id": ["WO-1", "WO-2"],
    "priority": [5, 2],
})
```

Pandas 会按标签自动对齐，这很强大，也会在标签不一致时产生意外缺失值。

## 14. Index 是对齐规则，不只是左侧行号

两个 Series 相加时，Pandas 默认按 index 标签对齐，而不是单纯按位置相加。

业务主键是否放进 Index 要有统一选择。很多数据管线保留普通列更直观，只有确实需要标签对齐或时间索引时才使用特殊 Index。

## 15. 读入数据后先做 Schema 观察

至少检查：

```python
orders.columns
orders.shape
orders.dtypes
orders.head()
orders.isna().sum()
orders["order_id"].is_unique
```

这不是为了“看看差不多”，而是尽早发现列缺失、类型推断错误、重复键和意外空值。

## 16. Pandas 的 `dtype` 决定列如何运算

数字列被读成字符串后，排序、求和和比较都会改变含义。使用 `pd.to_numeric(..., errors="coerce")` 时，失败值会变成缺失；必须保留失败掩码或错误报告，不能直接把它们丢掉。

可空整数、布尔和字符串类型能保留语义。具体默认 dtype 会随 Pandas 版本变化，项目应固定版本并显式检查。

## 17. 缺失值与空字符串不是一回事

```text
缺失：本来应该有值，但没有提供
空字符串：提供了一个长度为零的文本
空白字符串：提供了只含空格的文本
```

清洗前先决定业务含义。不能因为三者显示都“空”就统一填成零。使用 `isna()` / `notna()` 判断 Pandas 缺失值。

## 18. `loc` 按标签，`iloc` 按位置

```python
critical = orders.loc[orders["priority"] == 5, ["order_id", "priority"]]
first_row = orders.iloc[0]
```

选择和赋值尽量在一次 `.loc[...]` 中完成，避免链式赋值。链式操作可能作用于临时对象，代码看似执行却没有改到预期数据。

Pandas 的 Copy-on-Write 行为会继续演进，最可靠的规则仍是明确函数返回新表还是原地修改。

## 19. 向量化字符串和日期操作优先于逐行循环

```python
orders["category"] = orders["category"].str.strip().str.lower()
orders["created_at"] = pd.to_datetime(
    orders["created_at"], utc=True, errors="coerce"
)
```

逐行 `iterrows()` 往往更慢，也容易丢失 dtype 语义。复杂业务规则可以先抽成明确函数，但不要假设 `.apply()` 自动等于高性能向量化。

## 20. 去重前要区分重复行和重复业务键

完全相同的两行可能是文件重复；相同 `order_id` 但其他字段不同，可能是版本、冲突或数据损坏。

直接 `drop_duplicates()` 会隐藏问题。先定义唯一键、保留规则和审计记录，再决定删除、合并还是拒绝。

## 21. `groupby` 是拆分、计算、合并

```python
summary = (
    orders.groupby("technician_id", dropna=False)
    .agg(order_count=("order_id", "size"), total_hours=("hours", "sum"))
    .reset_index()
)
```

`size` 统计行数，`count` 忽略对应列的缺失值。二者不同可能直接改变报表。

分组后的排序、缺失键和 categorical 行为都应显式决定，保证输出可重复。

## 22. `merge` 前先声明连接基数

```python
result = orders.merge(
    technicians,
    on="technician_id",
    how="left",
    validate="many_to_one",
    indicator=True,
)
```

`many_to_one` 表示许多工单只能匹配一个技师。若右表键重复，立即失败，比静默把行数放大更安全。

连接前后应检查行数、唯一键、未匹配比例和关键金额总和。

## 23. Pandas 空键连接行为可能与 SQL 不同

某些 Pandas merge 会让两侧空键互相匹配，而 SQL 中 NULL 通常不相等。这可能制造虚假配对。

连接前要决定空键是拒绝、单独隔离，还是允许特殊处理。不要依赖数据库经验猜 DataFrame 行为。

## 24. 一条可靠清洗管线保留每一步证据

```text
原始文件只读保存
  → 记录输入哈希、来源、时间
  → 统一列名和类型
  → 标记转换失败
  → 校验唯一键与范围
  → 连接参考表并检查基数
  → 产生干净数据和错误数据
  → 输出统计摘要与版本信息
```

不要只有最终 CSV。没有失败行和处理统计，就很难解释数字为什么变化。

## 25. 测试的作用是让错误实现被发现

一个测试应建立输入、执行行为、检查可观察结果。它必须有能力在实现被故意改错时失败。

```python
def test_total_cents():
    assert calculate_total_cents(1999, 3) == 5997
```

只运行代码、打印结果或断言值等于自身，不是可靠测试。

## 26. pytest 会收集符合规则的测试

常见规则是文件名 `test_*.py`、函数名 `test_*`。测试输出中“0 collected”表示没有运行任何测试，不应被当作通过。

Failure 通常表示断言不成立；Error 常表示准备、导入、fixture 或执行过程中出现未处理异常。先看第一处自己代码的堆栈位置。

## 27. 参数化适合表达同一规则的边界表

```python
import pytest

@pytest.mark.parametrize(
    ("unit_price", "quantity", "expected"),
    [(1999, 3, 5997), (1999, 0, 0)],
)
def test_total(unit_price, quantity, expected):
    assert calculate_total_cents(unit_price, quantity) == expected
```

参数只是减少重复写法，真正价值来自边界选择。正常值、零、最小值、最大值和非法值应来自函数合同。

## 28. fixture 提供测试依赖并负责清理

```python
@pytest.fixture
def repository():
    repo = InMemoryOrderRepository()
    yield repo
    repo.close()
```

fixture 的 scope 决定共享范围。共享越大，速度可能更快，但测试间污染风险也更高。默认函数级隔离通常最容易理解。

只有普遍且无歧义的环境准备才使用 `autouse`，否则依赖会变得隐藏。

## 29. `tmp_path` 为文件测试提供隔离目录

```python
def test_snapshot_round_trip(tmp_path):
    target = tmp_path / "snapshot.json"
    save_snapshot(target, {"version": 1})
    assert load_snapshot(target)["version"] == 1
```

测试不应写固定真实目录，也不应依赖开发者机器上恰好存在的文件。临时目录让并行运行和清理更可靠。

## 30. Fake、Stub、Spy 和 Mock 解决的问题不同

- Fake：简化但可工作的实现，如内存仓库。
- Stub：给出预先安排的返回值。
- Spy：记录发生过的调用。
- Mock：预先声明并验证交互。

优先测试业务结果和状态变化。只有“是否调用某个外部端口”本身是合同，才重点验证交互。不要把每个内部方法调用都锁死。

## 31. patch 的目标是“被测试代码实际查找的名称”

如果模块写了 `from clock import now`，测试应 patch 该模块里的 `now` 名称，而不是盲目 patch 原始 `clock.now`。

更长期可维护的做法是显式注入时钟、仓库和客户端。patch 适合控制难以注入的系统边界，不应成为隐藏设计问题的常规手段。

## 32. 日志提供上下文，异常决定控制流

```python
logger.info(
    "order assigned",
    extra={"order_id": order.id, "technician_id": technician_id},
)
```

日志级别应表示影响：DEBUG 细节、INFO 正常里程碑、WARNING 可恢复异常、ERROR 当前操作失败。不要记录密码、Token、完整 PII 或用户上传正文。

记录异常时保留堆栈；记录一次通常在能够补充上下文或决定处理结果的边界，避免每层重复打同一错误。

## 33. pytest 可以捕获并检查日志

`caplog` 可设置日志级别并检查记录字段。测试应验证真正的可观察合同，如失败包含关联 ID 且不泄露 secret，而不是绑定完整易变文案。

日志断言是补充，不能替代返回值、状态和外部效果断言。

## 34. 调试先缩小失败阶段，再看变量

建议顺序：

```text
1. 保存原始命令、退出码和完整堆栈
2. 找到首个属于本项目的失败位置
3. 建立最小稳定复现
4. 检查输入类型、shape、dtype、索引和单位
5. 只改变一个假设
6. 修复后运行相关测试和完整测试
```

不要一遇到失败就同时改依赖、数据和代码，否则无法知道什么真正解决了问题。

## 35. 断点调试会暂停程序，也可能改变时序

`breakpoint()` 或 IDE 断点能观察局部变量和调用栈。它适合普通同步逻辑，但在并发、超时和竞态问题中，暂停本身可能让问题消失。

这类问题还需要结构化日志、时间线、任务 ID 和可重复的同步控制。

## 36. NumPy 测试要同时检查数值、形状和类型

```python
np.testing.assert_allclose(actual, expected, rtol=1e-6, atol=1e-9)
assert actual.shape == expected.shape
assert actual.dtype == expected.dtype
```

浮点结果使用明确容差，不要随意四舍五入后比较。若函数承诺不修改输入，还要保存输入副本并检查不变性。

## 37. Pandas 测试应检查表结构和关键不变量

`pandas.testing.assert_frame_equal` 能比较列、索引、dtype 和值。大型表无需把全部内容写死，但必须检查：

- 列集合与顺序；
- 主键唯一；
- 行数变化符合预期；
- 未匹配和失败记录数量；
- 关键金额/数量总和；
- 输出排序确定。

## 38. 数据测试不能只复制实现逻辑

如果生产代码和测试都用同一段复杂 groupby 计算 expected，二者可能一起犯错。预期值应来自小型手算样本、独立公式或已审查的基准数据。

生产数据抽样可以补充，但必须脱敏并固定，不能让测试依赖实时数据库。

## 39. 性能问题先量数据规模与瓶颈

NumPy/Pandas 不是无限内存方案。先记录行数、列数、dtype、峰值内存和耗时，再决定：

- 优化向量化表达；
- 减少中间副本；
- 分块读取；
- 下推 SQL；
- 使用专用列式引擎或分布式处理。

不要仅因为循环存在就重写，也不要仅因为代码短就认为高效。

## 40. 这一阶段应形成的整体地图

```text
NumPy：同质数组 + shape + dtype + axis + 广播
Pandas：带标签表格 + dtype + 缺失 + groupby + merge
pytest：输入 + 行为 + 可观察断言 + 隔离清理
调试：阶段证据 + 最小复现 + 单一假设
```

必须掌握：广播前后检查 shape；固定宽度数值会溢出；Pandas 按标签对齐；缺失不等于空字符串；merge 前声明基数；测试必须能证伪；fixture 负责依赖与清理；Mock 不应锁死内部实现；数据管线要保留失败数据和处理统计。

NumPy、Pandas 和 pytest 的默认行为会随版本变化，项目应锁定版本；涉及 dtype、Copy-on-Write、merge 和警告策略时，以锁定版本的官方文档为准。
