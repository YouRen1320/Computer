---
schema_version: 2
edition: 2026.2-draft
id: ch.data.numpy
title: NumPy 数组、形状、广播与向量化
responsibility: 用 ndarray、dtype、shape、轴、切片、广播和向量化处理数值数据，识别 view/copy 与数值稳定边界，不在本章做表格业务清洗。
volume: '12'
order: 18
level: L2
status: drafting
path: book/volume-12-python-data/chapters/ch.data.numpy.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.collections
version_surfaces:
- python-3.14
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
  text: 在 120 秒内解释“NumPy 数组、形状、广播与向量化”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - numpy-array-shape
  - numpy-broadcast-vector
  covers_topics:
  - numpy.ndarray
  - numpy.dtype
  - numpy.shape-axis
  - numpy.index-slice-mask
  - numpy.view-copy
  - numpy.broadcasting
  - numpy.vectorization
  - numpy.reduction
  - numpy.nan
  - numpy.numeric-stability
  uses_capabilities:
  - python.language
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 将工单时长列表转换为 ndarray，完成分组轴统计和广播归一化；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - numpy-array-shape
  - numpy-broadcast-vector
  covers_topics:
  - numpy.ndarray
  - numpy.dtype
  - numpy.shape-axis
  - numpy.index-slice-mask
  - numpy.view-copy
  - numpy.broadcasting
  - numpy.vectorization
  - numpy.reduction
  - numpy.nan
  - numpy.numeric-stability
  uses_capabilities:
  - python.language
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: shape-table-numpy-assertions-view-copy-fixture
- id: diagnose
  kind: fault-diagnosis
  text: 面对“轴选错、静默广播、整数溢出或 view 修改原数组”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - numpy-array-shape
  - numpy-broadcast-vector
  covers_topics:
  - numpy.ndarray
  - numpy.dtype
  - numpy.shape-axis
  - numpy.index-slice-mask
  - numpy.view-copy
  - numpy.broadcasting
  - numpy.vectorization
  - numpy.reduction
  - numpy.nan
  - numpy.numeric-stability
  uses_capabilities:
  - python.language
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# NumPy 数组、形状、广播与向量化

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《list、tuple、dict、set 与推导式》](ch.python.collections.md)：ndarray 与 Python list/嵌套集合的行为、引用和迭代边界必须先能比较。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。截至 2026-07-24，NumPy 官方当前稳定线是 2.5.0，支持 Python 3.12—3.14；本仓库配套资产实际在本机 Python 3.14.3、NumPy 2.4.4 上运行，未安装 pytest。资产使用 `numpy.testing` 与普通断言验证稳定核心，不能冒充 NumPy 2.5.0、pytest、其他 CPU/BLAS、自由线程构建或 GPU 的实测证据。

Python list 是通用对象容器，可以同时放整数、字符串和字典；NumPy `ndarray` 为同质、固定形状的多维数据提供紧凑内存与批量运算。优势来自更明确的限制：元素共享 dtype，形状是规则矩形，许多运算由编译实现一次处理整块数据。限制也带来新风险：固定宽度整数会溢出，切片可能共享底层内存，广播会在 shape 兼容时静默扩大计算，浮点数不满足精确十进制直觉。

本章建立“值—dtype—shape—axis—存储共享”的心智模型。你会把工单时长的嵌套列表转换成二维数组，沿正确轴聚合，利用广播标准化，处理 NaN，并用独立手算与 NumPy 断言交叉验证。这里不做 CSV 表格清洗、不按列名连接设备表；那些属于下一章 pandas。

## 1. 完成定义、配套入口与边界

完成本章后，你应能：

1. 解释 `ndarray` 与 Python list 的所有权、类型和形状差异；
2. 读取 `ndim`、`shape`、`size`、`dtype`，为每个轴写出业务含义；
3. 显式选择整数/浮点宽度，预测转换、类型提升和溢出风险；
4. 使用整数索引、slice、布尔 mask 与高级索引，并判断返回 view 还是 copy；
5. 用 reshape、transpose、`newaxis` 改变观察方式，同时追踪内存共享；
6. 手算 reduction 的 axis 与输出 shape，必要时使用 `keepdims`；
7. 从末尾维度应用广播规则，识别“能广播但业务含义错误”的静默 bug；
8. 用 ufunc 和向量化表达元素级计算，同时评估临时数组、内存与可读性；
9. 区分 NaN、缺测、无穷和零，选择普通或 NaN-aware 聚合；
10. 使用 `np.testing`、`allclose`、shape 表和独立预言验证结果。

配套入口：

- [工单时长矩阵与广播标准化示例](../../../examples/encyclopedia/ch.data.numpy/README.md)
- [axis、广播、溢出与 view 故障实验](../../../labs/encyclopedia/ch.data.numpy/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.data.numpy/README.md)

FactoryCare 中 NumPy 只处理从 Java API 或脱敏夹具得到的可重建派生数值。它可以计算时长分布、模型特征和评估指标，不能直接修改 Java 持有的工单状态、授权或审计事实。

## 2. `ndarray`：同质 N 维数组

标准导入约定：

```python
import numpy as np
```

创建一维数组：

```python
durations = np.array([15, 32, 18, 47], dtype=np.int64)
```

它不是“更好看的 list”。数组通常有一个连续或按 stride 解释的数据缓冲区，加上 dtype、shape、strides 等元数据。固定 dtype 使元素宽度和运算规则可预测，也让底层循环能避免逐个 Python 对象调度。

### 2.1 list 与数组的运算含义不同

```python
python_values = [1, 2, 3]
array_values = np.array([1, 2, 3])

assert python_values * 2 == [1, 2, 3, 1, 2, 3]
np.testing.assert_array_equal(array_values * 2, [2, 4, 6])
```

list 乘整数是重复容器，数组乘标量是逐元素乘法。把 list 代码机械换成 array，必须重新确认运算语义。

### 2.2 同质与规则形状

二维数组来自规则嵌套序列：

```python
matrix = np.array(
    [
        [15.0, 30.0, 45.0],
        [12.0, 24.0, 36.0],
    ],
    dtype=np.float64,
)
```

行长不同的 jagged 输入不能成为普通规则数值矩阵。不要用 `dtype=object` 掩盖脏形状；object 数组保存 Python 对象，通常失去数值数组的性能、类型和广播保证。应在边界验证每行长度，或选择适合变长序列的数据结构。

## 3. 四个必看属性：ndim、shape、size、dtype

```python
assert matrix.ndim == 2
assert matrix.shape == (2, 3)
assert matrix.size == 6
assert matrix.dtype == np.dtype("float64")
```

- `ndim`：轴的数量；
- `shape`：每个轴的长度；
- `size`：总元素数，等于 shape 各项乘积；
- `dtype`：每个元素的解释方式。

### 3.1 shape 必须附业务标签

`(2, 3)` 本身不知道“行是技师、列是星期”。在代码旁记录：

```text
durations shape = (technician, day)
axis 0 = technician
axis 1 = day
```

对更高维数据更重要：`(batch, time, feature)` 与 `(time, batch, feature)` 数字可能一样，结果语义完全不同。函数入口应断言 ndim、固定维度和可接受空轴，而不是等到广播后才发现。

### 3.2 0-D、1-D 与 `(n, 1)` 不相同

```python
scalar_array = np.array(5)           # shape ()
vector = np.array([5, 6, 7])         # shape (3,)
column = vector[:, np.newaxis]        # shape (3, 1)
row = vector[np.newaxis, :]           # shape (1, 3)
```

一维数组没有行/列方向；`vector.T` 仍是 shape `(3,)`。需要列向量时显式添加轴。很多意外外积都来自把 `(n,)` 当 `(n,1)`。

## 4. 创建数组与初始化

常用入口：

```python
np.zeros((2, 3), dtype=np.float64)
np.ones((2, 3), dtype=np.int64)
np.full((2, 3), fill_value=-1, dtype=np.int64)
np.arange(0, 10, 2, dtype=np.int64)
np.linspace(0.0, 1.0, num=5)
```

`np.empty` 只分配，不初始化为业务默认值，内容取决于已有内存；只有确保立刻覆盖每个元素时才用。展示中的随机数也必须使用显式 generator 和固定 seed 才可复现：

```python
rng = np.random.default_rng(20260724)
sample = rng.normal(size=4)
```

固定 seed 让测试可重复，不使伪随机变成安全随机，也不保证不同 NumPy 算法版本永远逐位相同。模型评估应记录实际版本、bit generator 和输入。

## 5. dtype 是计算合同

Python int 可按需要扩展精度，NumPy 整数通常是固定宽度：`int8`、`int32`、`int64` 等。选择 dtype 同时选择值域、内存与溢出行为。

```python
small = np.array([120], dtype=np.int8)
```

`int8` 只能表达 -128..127。任何超出范围的输入、转换或运算都需要验证。设备累计分钟、金额分和 ID 不应为了节省少量内存盲选窄整数。

### 5.1 不要依赖平台宽度别名

对文件、接口与可复现实验，优先写 `np.int64`、`np.float64` 等明确宽度。`np.intp` 面向索引，宽度随平台。跨语言交换还需考虑字节序和 schema。

### 5.2 类型推断与提升

```python
np.array([1, 2, 3]).dtype
np.array([1, 2.5, 3]).dtype
```

混入浮点通常使数组提升为浮点。标量与数组运算也遵循 NumPy 类型提升规则；NumPy 2.x 对部分规则有过变化，不能只凭 Python 类型直觉。关键函数先断言 dtype 或显式转换，并用边界值测试。

### 5.3 `astype` 是转换，不是校验

```python
raw = np.array([1.0, 2.0, 3.0])
converted = raw.astype(np.int64)
```

小数转整数会丢小数部分。NumPy 2.4 增加的 `casting="same_value"` 可在值不能无损保持时失败，但它是版本表面；若项目锁定旧版本，应先手动验证或升级后再使用。转换后必须检查范围、有限性与业务整数语义。

### 5.4 整数溢出与 reduction

窄整数逐元素运算可能回绕或发出警告。部分聚合会使用更宽累加 dtype，但不要假设所有平台/函数一致：

```python
total = np.sum(values, dtype=np.int64)
```

为累计量显式指定安全 dtype，并用接近最大值的夹具验证。金额仍不应使用 float；NumPy 也不替代十进制业务合同。

## 6. 索引、切片与 mask

二维索引使用一个方括号、每轴一个索引：

```python
matrix[0, 1]
matrix[:, 1]
matrix[0:2, 1:3]
```

整数索引通常移除对应轴；slice 保留轴。先预测输出 shape 再运行：`matrix[:, 1]` 是 `(2,)`，`matrix[:, 1:2]` 是 `(2,1)`。

### 6.1 基础切片通常返回 view

```python
source = np.array([10, 20, 30, 40])
window = source[1:3]
window[0] = 999
assert source[1] == 999
```

这与 Python list 切片的 copy 行为不同。view 是新的数组对象，但与 source 共享数据缓冲。性能好，却可能意外修改原数组。

需要独立快照时显式：

```python
safe_window = source[1:3].copy()
```

不能只看 `child.base is parent` 判断所有共享链，因为 base 可能指向更早对象；诊断可结合 `np.shares_memory`、`np.may_share_memory` 和 `flags.owndata`，最终用修改夹具确认合同。

### 6.2 高级索引通常返回 copy

整数数组索引和布尔索引属于高级索引，通常产生 copy：

```python
selected = source[np.array([0, 2])]
mask_selected = source[source > 25]
```

但赋值 `source[mask] = value` 会写回 source，因为左值语义不同。不要试图背零散例子；区分“取出结果再改”和“直接索引赋值”。

### 6.3 布尔条件需要逐元素运算符

```python
mask = (durations >= 15) & (durations < 45)
```

使用 `&`、`|`、`~`，每个比较加括号。Python 的 `and/or` 需要整体真值，多元素数组会报“truth value is ambiguous”。这个报错保护你避免随意把数组压成一个布尔值。需要全真或任一真时明确 `np.all`/`np.any` 和 axis。

### 6.4 赋值会按 dtype 转换

给 int 数组赋浮点可能截断或失败，给固定宽度字符串数组赋长文本可能截断。修改前检查 dtype；不要把 silent cast 当清洗逻辑。

## 7. shape 变换与内存布局

```python
values = np.arange(12, dtype=np.float64)
grid = values.reshape(3, 4)
transposed = grid.T
```

reshape 要求元素总数相同。它在可能时返回 view，必要时可能 copy；transpose 通常通过 strides 改变观察方式，不搬数据。不要把“通常”写成所有输入保证，尤其非连续数组。

### 7.1 `-1` 推断维度

```python
values.reshape(3, -1)
```

只能有一个 `-1`。推断方便，但业务代码仍应断言结果 shape，否则输入批次变化可能产生看似合法的错误结构。

### 7.2 flatten 与 ravel

`flatten()` 返回 copy；`ravel()` 尽量返回 view。若输出将被修改或长期保存，明确 copy；若只读性能路径，可使用 ravel 并在接口文档说明共享风险。

### 7.3 `newaxis` 与 expand_dims

```python
per_day_mean = np.array([10.0, 20.0, 30.0])
row = per_day_mean[np.newaxis, :]      # (1, 3)
column = per_day_mean[:, np.newaxis]   # (3, 1)
```

添加哪个轴决定广播方向。变量名写业务维度比写 `x2` 更有价值。

## 8. axis：被折叠的维度

对 shape `(technician, day)` 的时长矩阵：

```python
durations = np.array(
    [
        [10.0, 20.0, 30.0],
        [15.0, 25.0, 35.0],
    ]
)
```

`durations.mean(axis=0)` 折叠 technician 轴，结果为每个 day 的均值，shape `(3,)`；`axis=1` 折叠 day，结果为每位 technician 的均值，shape `(2,)`。记忆“axis=0 按列算”在高维会失效；更准确的问题是“删除哪个轴，剩下哪些轴”。

### 8.1 先写 shape 表

| 表达式 | 被折叠轴 | 输出 shape | 业务含义 |
| --- | --- | --- | --- |
| `mean(axis=0)` | technician | `(day,)` | 每日跨技师均值 |
| `mean(axis=1)` | day | `(technician,)` | 每位技师跨日均值 |
| `mean()` | 全部 | `()` | 全局均值 |
| `mean(axis=1, keepdims=True)` | day | `(technician,1)` | 可广播的技师均值 |

`keepdims=True` 保留长度为 1 的轴，常用于后续广播，减少手动 newaxis 错位。

### 8.2 多轴 reduction

高维可用 `axis=(1,2)` 同时折叠多个轴。轴编号要与 shape contract 一起维护；重排轴后旧编号可能仍运行却语义错误。复杂管线可定义轴常量或使用更高层带标签结构。

## 9. 广播规则

NumPy 从 shape 的末尾开始逐维比较。两个维度兼容，当且仅当它们相等，或其中一个是 1；缺失前导维度按 1 理解。结果维度取较大值。

```text
(2, 3)
   (3,)
→(2, 3)
```

每列的基准值 `(3,)` 可以从每行减去：

```python
centered = durations - durations.mean(axis=0)
```

### 9.1 不兼容形状应早失败

`(2,3)` 与 `(2,)` 从尾维比较 3 和 2，不兼容，抛 `ValueError`。可在关键代码先用 `np.broadcast_shapes` 检查预期结果 shape，并将它写入测试。

### 9.2 能广播也可能是 bug

```python
column = np.array([[1.0], [2.0]])  # (2,1)
row = np.array([10.0, 20.0])       # (2,)
result = column + row              # (2,2)
```

如果开发者想逐对相加得到 `(2,)`，这次广播静默生成外积式矩阵。shape 兼容只证明数组代数可执行，不证明业务维度匹配。对每个输入给轴命名、断言精确 ndim/shape，避免“只要不报错就正确”。

### 9.3 广播不是总会复制

广播通常通过 stride/迭代规则复用较小数据，不真的铺满，但后续结果和复合表达式可能创建巨大临时数组。`(100000,1)` 与 `(1,100000)` 会得到一百亿元素结果，即使两个输入很小。执行前计算输出 shape 与字节数。

## 10. 向量化与 ufunc

向量化表示把逐元素/按块规则交给数组操作，而不是手写 Python 循环：

```python
normalized = (durations - mean) / scale
```

NumPy universal function（ufunc）如 `np.add`、`np.sqrt` 通常在编译循环中运行，并支持广播、dtype 与 `where`。它们不是“数学自动正确”：shape、单位、缺失和零除仍由你负责。

### 10.1 `np.vectorize` 不是性能魔法

`np.vectorize` 主要提供广播式调用便利，通常仍是 Python 循环。性能需要基准证明；优先寻找真正 ufunc、批量代数或分块算法。

### 10.2 临时数组与内存

表达式 `(x - mean) / std` 可能建立中间数组。数据大时可分块、使用 `out=`、原地操作或专门库，但原地修改会增加别名风险。先保证正确与清晰，再用真实数据、峰值内存和 wall-clock 基准优化。

### 10.3 原地操作改变 dtype 约束

```python
values = np.array([1, 2, 3], dtype=np.int64)
# values /= 2 可能因 float 结果无法按规则写回 int 而失败
```

非原地 `values / 2` 可产生 float 数组。选择原地只为性能时，必须验证 casting 与调用方是否共享内存。

## 11. NaN、缺测与无穷

IEEE 浮点 NaN 表示“非数”，常被用作浮点缺失哨兵，但它不是通用缺失语义：

```python
value = np.nan
assert value != value
assert np.isnan(value)
```

不要用 `value == np.nan`。整数数组不能直接表达 NaN；可使用独立 mask、浮点转换或更高层 nullable 类型。

### 11.1 普通聚合与 NaN-aware 聚合

```python
values = np.array([10.0, np.nan, 30.0])
assert np.isnan(np.mean(values))
assert np.nanmean(values) == 20.0
```

选择 `nanmean` 意味着“忽略缺测”，不是技术默认。如果 NaN 代表传感器故障，忽略会掩盖质量问题；应同时输出有效计数和缺失比例。全 NaN slice 会产生 NaN 并可能警告，需单独处理。

### 11.2 无穷与有限性

除零、指数溢出等可产生 `inf`。用 `np.isfinite` 检查模型输入/输出：

```python
if not np.all(np.isfinite(features)):
    raise ValueError("features must be finite")
```

但如果 NaN 是明确缺测合同，就先用 mask 处理再检查剩余值。

## 12. 数值稳定性

浮点数是有限二进制近似：

```python
0.1 + 0.2 != 0.3
```

数组结果通常用容差比较：

```python
np.testing.assert_allclose(actual, expected, rtol=1e-7, atol=1e-9)
```

容差必须来自量纲与风险，不是为了让失败变绿随意放大。`atol` 对接近零的值尤其重要。

### 12.1 标准化的零方差

若某列所有值相同，标准差为零，直接除会产生 NaN/inf：

```python
mean = np.nanmean(values, axis=0, keepdims=True)
std = np.nanstd(values, axis=0, keepdims=True)
safe_std = np.where(std == 0, 1.0, std)
normalized = (values - mean) / safe_std
```

把零方差列设为 0 是否合理取决于特征合同。还要保留 zero-variance mask，避免下游误以为正常分布。

### 12.2 大数相减与累计误差

接近的大浮点数相减会损失有效位；长序列求和顺序影响误差。NumPy 某些函数会采用更好算法，但精度依 dtype、轴和实现。对关键统计，用 float64、稳定算法、缩放或更高精度参考交叉验证；业务金额仍用整数/十进制。

### 12.3 warning 不是成功

NumPy 数值异常可能以 warning 加 NaN/inf 返回。测试可用 `np.errstate(divide="raise", invalid="raise", over="raise")` 将关注的场景升级为异常：

```python
with np.errstate(divide="raise", invalid="raise"):
    result = numerator / denominator
```

不要全局忽略 warning。明确哪些异常允许、如何标记，保存输入与结果有限性证据。

## 13. FactoryCare 时长矩阵示例

输入语义：行是技师，列是日期，值是已关闭工单处理分钟，NaN 表示该日没有可用观测：

```python
durations = np.array(
    [
        [30.0, 45.0, np.nan],
        [20.0, 40.0, 60.0],
        [25.0, 35.0, 55.0],
    ],
    dtype=np.float64,
)
assert durations.shape == (3, 3)
```

按日期统计：

```python
day_mean = np.nanmean(durations, axis=0, keepdims=True)  # (1,3)
day_std = np.nanstd(durations, axis=0, keepdims=True)    # (1,3)
count = np.sum(~np.isnan(durations), axis=0)             # (3,)
```

广播标准化：

```python
safe_std = np.where(day_std == 0, 1.0, day_std)
zscore = (durations - day_mean) / safe_std
```

NaN 保留，避免把缺测伪装成 0 分钟。结果属于派生分析，可删除重算；原始工单关闭时间由 Java/数据库权威提供。数据导出应携带时间范围、租户过滤、时区与查询版本。

## 14. 测试：shape、值与共享都要断言

```python
np.testing.assert_array_equal(actual_shape, expected_shape)
np.testing.assert_allclose(actual_values, expected_values, equal_nan=True)
```

更完整矩阵：

| 风险 | 正例 | 反例 | 证据 |
| --- | --- | --- | --- |
| axis | 手算每列均值 | 交换轴 | 输出 shape 与逐项值 |
| 广播 | `(m,n)-(1,n)` | `(m,1)-(m,)` 意外 `(m,m)` | `broadcast_shapes` 与业务断言 |
| dtype | float64 时长 | int8 大值溢出 | dtype、范围、结果 |
| NaN | 部分缺测 | 全列缺测 | 有效计数、warning、结果 |
| view | 只读观察 | 修改 slice 污染 source | `shares_memory` 与源数组 |
| copy | 独立快照 | 忘记 `.copy()` | 修改后原值不变 |

本机没有 pytest，所以资产的绿灯不是 pytest 测试发现/fixture 证据。进入正式项目后用锁定 pytest 运行同一预言，并保存 `numpy.__version__`、Python、平台和 BLAS 信息。

## 15. 诊断阶梯

### 15.1 结果 shape 错

先打印/断言每个中间值的 shape 和轴标签，不要先改 reshape。写出广播对齐表，从末尾逐维检查。若期望逐对运算，确认都是 `(n,)` 或都是 `(n,1)`，不要混合。

### 15.2 数值突然负数或回绕

检查 dtype、最小/最大值与转换位置。窄整数溢出不是业务负数。修复为合适宽度并在操作前验证范围，重新用 Python int 手算参考。

### 15.3 修改子数组后原数组变了

判断是 basic slice/view 还是 advanced index/copy，调用 `np.shares_memory`，再决定应保留共享还是 `.copy()`。不要到处 copy 作为默认补丁；大数组会增加内存，接口应明确所有权。

### 15.4 全部变 NaN

检查输入 NaN/inf、零方差、除零、无效函数域和 axis。开启局部 `errstate(...="raise")` 找首个数值异常。不要在最后 `nan_to_num` 抹掉根因；只有业务定义替代值时才转换并保留质量标记。

## 16. 性能边界

NumPy 适合 CPU 上大批同质数值。小列表、复杂 Python 对象、频繁逐元素业务分支未必更快。性能判断包含：

- 数据转换成本；
- 临时数组峰值内存；
- 连续性与 cache locality；
- BLAS/线程配置；
- 算法复杂度；
- 数值精度；
- 并发与自由线程构建差异。

不要用一次 REPL 计时宣称生产性能。固定数据、预热、重复测量、记录版本和硬件，先与正确的纯 Python/手算预言比较。

## 17. 常见误区与修正规则

**“ndarray 就是支持多维的 list。”** 它有同质 dtype、固定形状和共享缓冲。规则：每个入口检查 shape/dtype。

**“axis=0 就是按行。”** 这种口号不适用于高维。规则：axis 是被折叠的维度，写输出 shape。

**“切片得到独立数组。”** basic slicing 通常是 view。规则：先定义所有权，需要快照显式 copy。

**“广播成功说明维度正确。”** 只说明 shape 可兼容。规则：轴标签和精确 shape 仍要验证。

**“向量化必然省内存且更快。”** 可能创建巨大临时数组。规则：测 wall time 与峰值内存。

**“NaN 等于缺失且可以直接比较。”** NaN 不等于自身，缺失含义依业务。规则：用 isnan 与质量 mask。

**“astype 会安全校验。”** 转换可能截断/溢出。规则：先验证范围和无损性。

**“allclose 默认容差总适合。”** 容差必须匹配量纲与风险。规则：显式 rtol/atol 并解释。

## 18. 独立构建任务

实现 `normalize_durations(values)`：

1. 输入转换为 float64 ndarray；
2. 要求 shape 为 `(technician, day)` 且两个轴均非空；
3. 拒绝 inf，允许 NaN 表示缺测；
4. 沿 technician 轴计算每日均值、标准差和有效计数；
5. 使用 keepdims 保留 `(1,day)`；
6. 零方差列标准化为 0，并返回 mask；
7. 原输入数组不得被修改；
8. 保存正常、部分 NaN、全 NaN 列、零方差、错误 ndim、空轴、inf 七组证据；
9. 故意用 axis=1 运行一次，记录 shape 与手算不一致，再修复；
10. 故意修改 slice，证明 view 污染，再使用 copy 修复；
11. 写清结果是可重建派生指标，不回写核心工单事实。

## 19. 自检问题

1. ndarray 的数据缓冲和元数据分别包含什么？
2. `(3,)`、`(1,3)`、`(3,1)` 广播结果有什么差异？
3. 为什么二维 `axis=0` 均值输出长度等于列数？
4. basic slice 与布尔索引的 copy/view 行为通常有何区别？
5. `source[mask] = 0` 与 `selected = source[mask]; selected[:] = 0` 是否相同？
6. fixed-width int 为什么可能回绕，如何建立证据？
7. `nanmean` 做了什么业务假设？
8. `keepdims=True` 如何降低广播错位风险？
9. `np.vectorize` 为什么不等于编译向量化？
10. 为什么 `allclose` 的 atol 不能随便取大？
11. 原地运算与共享 view 组合会有什么风险？
12. NumPy 计算结果为什么不能直接成为 Java 工单权威状态？

## 20. 官方资料与版本说明

以下官方资料在 2026-07-24 核对：

- [NumPy 2.5.0 Release Notes](https://numpy.org/doc/stable/release/2.5.0-notes.html)：当前稳定特性、Python 3.12—3.14 支持与版本变化；
- [Absolute basics for beginners](https://numpy.org/doc/stable/user/absolute_beginners.html)：ndarray、shape、axis、创建与索引；
- [Data types](https://numpy.org/doc/stable/user/basics.types.html)：dtype、宽度、转换与溢出；
- [Indexing on ndarrays](https://numpy.org/doc/stable/user/basics.indexing.html)：基础/高级索引与 mask；
- [Copies and views](https://numpy.org/doc/stable/user/basics.copies.html)：缓冲共享、view、copy 与 reshape；
- [Broadcasting](https://numpy.org/doc/stable/user/basics.broadcasting.html)：兼容规则、效率与不适用场景；
- [Statistics reference](https://numpy.org/doc/stable/reference/routines.statistics.html) 与 [Testing support](https://numpy.org/doc/stable/reference/routines.testing.html)：reduction 与数组断言。

ndarray、shape、axis、广播末维规则和 view/copy 是稳定核心；具体 dtype promotion、casting 参数、排序、自由线程与 patch 修复属于版本表面。正式项目通过 uv lockfile 固定 NumPy，并在升级后重跑 shape 表、边界 dtype、NaN 和共享内存夹具。

## 21. 本章小结

NumPy 的力量来自明确限制：同质 dtype、规则 shape 和批量数组语义。正确使用它必须同时跟踪五件事：值、dtype、shape、axis 和数据所有权。广播与 view 能减少复制，也会制造静默 shape 扩张和别名修改；固定宽度与浮点带来溢出和近似；NaN-aware 函数蕴含业务假设。

最可复用的规则是：**每个数组都写轴含义，每个 reduction 先算输出 shape，每个广播先对齐末维，每个切片先决定所有权，每个数值结果用手算与 NumPy 断言交叉验证。**
