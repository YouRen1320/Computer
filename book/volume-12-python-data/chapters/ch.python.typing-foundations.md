---
schema_version: 2
edition: 2026.2-draft
id: ch.python.typing-foundations
title: 基础类型标注、联合、容器类型与类型检查器
responsibility: 为函数和集合边界添加基础类型标注、联合和 Optional，并用类型检查器定位静态错误，明确标注不是运行时校验。
volume: '12'
order: 6
level: L1-L2
status: drafting
path: book/volume-12-python-data/chapters/ch.python.typing-foundations.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.collections
version_surfaces:
- python-3.14
- uv
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“基础类型标注、联合、容器类型与类型检查器”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - python-type-annotations
  - python-static-checking
  covers_topics:
  - python.type-annotation
  - python.parameter-return-type
  - python.union-optional
  - python.container-type
  - python.type-alias
  - python.static-type-checker
  - python.type-narrowing
  - python.any-unknown-boundary
  - python.type-runtime-gap
  uses_capabilities:
  - python.language
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“基础类型标注、联合、容器类型与类型检查器”构建可运行程序与测试：为工单函数与嵌套集合添加类型标注并保存正负类型检查证据；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - python-type-annotations
  - python-static-checking
  covers_topics:
  - python.type-annotation
  - python.parameter-return-type
  - python.union-optional
  - python.container-type
  - python.type-alias
  - python.static-type-checker
  - python.type-narrowing
  - python.any-unknown-boundary
  - python.type-runtime-gap
  uses_capabilities:
  - python.language
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: type-checker-positive-negative-fixture-runtime-contrast
- id: diagnose
  kind: fault-diagnosis
  text: 面对“把 Any 当安全、忽略 None 或把类型标注误当运行时 Schema”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - python-type-annotations
  - python-static-checking
  covers_topics:
  - python.type-annotation
  - python.parameter-return-type
  - python.union-optional
  - python.container-type
  - python.type-alias
  - python.static-type-checker
  - python.type-narrowing
  - python.any-unknown-boundary
  - python.type-runtime-gap
  uses_capabilities:
  - python.language
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 基础类型标注、联合、容器类型与类型检查器

> Python 是动态语言：对象在运行时带类型，名称可以在不同时刻绑定到不同类型的对象。类型标注为开发工具提供静态合同，但解释器默认不会因为参数标了 `int` 就拒绝字符串。本章同时运行解释器和真实类型检查器，要求你能区分“静态检查通过”“程序成功执行”“不可信输入已校验”三种完全不同的证据。

## 1. 动态类型不等于没有类型

```python
value = 42
print(type(value))

value = "WO-001"
print(type(value))
```

整数对象和字符串对象都有明确运行时类型；变化的是名称 `value` 的绑定。Python 不要求名称终生只有一种类型，这叫动态类型。类型标注在源代码中表达“我们希望这里遵守什么合同”：

```python
order_id: str = "WO-001"
priority: int = 4
```

标注能帮助 IDE、类型检查器和阅读者，但不是 Java 式编译强制，也不是 HTTP 输入校验器。

### 1.1 三层证据必须分开

| 问题 | 工具/证据 | 能证明什么 |
| --- | --- | --- |
| 源代码类型关系是否一致 | mypy 等静态检查器 | 在配置和可见标注范围内未发现类型矛盾 |
| 某个运行路径是否工作 | CPython + 断言/测试 | 给定样例实际执行并满足 oracle |
| 外部输入是否符合业务 Schema | 运行时解析与验证 | 这个具体输入被检查、转换或拒绝 |

任一层通过都不能替代另外两层。类型检查器可能被 `Any` 绕过；测试只覆盖运行过的路径；运行时验证也不能替代内部函数的静态合同。

## 2. 变量标注的语法与边界

```python
technician_id: int = 42
status: str = "ASSIGNED"
enabled: bool = True
```

冒号后是类型表达式，等号后仍是普通运行时表达式。仅标注不赋值：

```python
error_message: str
```

这不会自动创建一个可读取的值。立刻 `print(error_message)` 仍会触发名称错误。标注描述意图，不提供默认值。

下面的代码通常仍能被解释器执行：

```python
priority: int = "high"
print(priority)
```

解释器会打印 `high`；类型检查器应报告 `str` 与 `int` 不兼容。这正是本章必须保留的“运行时对照”。不要用“它能打印”否定静态错误，也不要用“mypy 通过”声称网络输入安全。

### 2.1 类型推断与显式标注

```python
count = 0
```

类型检查器通常可推断 count 是 int，不必给每个局部变量重复标注。应优先标注边界：公共函数参数和返回、空容器、复杂联合、模块级数据合同。过度标注会制造噪声；完全不标注又会让检查器失去信息。

空集合尤其需要上下文：

```python
order_ids: list[str] = []
counts: dict[str, int] = {}
```

否则检查器可能无法知道未来允许放什么，或在非严格配置下退化为过宽类型。

## 3. 函数参数与返回类型

```python
def calculate_total(unit_price_cents: int, quantity: int) -> int:
    return unit_price_cents * quantity
```

- `unit_price_cents: int` 标注第一个参数；
- `quantity: int` 标注第二个参数；
- `-> int` 标注返回；
- 标注不改变函数调用语法。

类型检查器可以发现：

```python
calculate_total("1999", 3)  # 参数类型错误
```

也能检查函数体的返回：

```python
def broken_total(unit_price_cents: int, quantity: int) -> int:
    return f"{unit_price_cents * quantity} cents"  # 返回 str
```

函数只执行副作用、不返回业务值时写 `-> None`：

```python
def print_order(order_id: str) -> None:
    print(order_id)
```

不要省略返回标注后假设检查器会始终严格推断。在渐进类型系统中，无标注函数可能被当作动态区域；严格配置可以要求所有函数声明类型。

### 3.1 默认值必须与允许类型一致

```python
def format_order(order_id: str, prefix: str = "工单") -> str:
    return f"{prefix}:{order_id}"
```

默认值是 str，与参数类型一致。如果默认值是 None，而函数内部允许 None，类型必须表达它：

```python
def format_order(order_id: str, prefix: str | None = None) -> str:
    if prefix is None:
        prefix = "工单"
    return f"{prefix}:{order_id}"
```

“有默认值”与“类型包含 None”不是同一个概念。`limit: int = 10` 可以省略，但显式传 None 不合法；`limit: int | None` 表示值可为 None，不代表参数可以省略，除非还提供默认值。

## 4. 联合类型：值可以属于多个候选类型

Python 3.10+ 推荐使用 `|`：

```python
def normalize_order_id(raw: int | str) -> str:
    if isinstance(raw, int):
        return f"WO-{raw:06d}"
    return raw.strip()
```

`int | str` 表示输入可以是 int 或 str，不表示它同时是二者，也不表示可接收任意对象。联合越大，函数内部需要处理的分支越多；不要用巨大联合掩盖缺少稳定合同。

### 4.1 Optional 的准确含义

`str | None` 与 `typing.Optional[str]` 在类型含义上等价。本路线优先使用更直接的 `str | None`：

```python
def technician_label(technician_id: int | None) -> str:
    if technician_id is None:
        return "未指派"
    return f"技师-{technician_id}"
```

Optional 意味着值可能是 None，不等于“函数参数可省略”。以下参数仍必填：

```python
def label(value: str | None) -> str:
    ...
```

调用 `label()` 会因缺少实参失败；调用 `label(None)` 才是传入允许的空值。

### 4.2 None 是独立对象，不是空字符串或 0

```python
assignee_id: int | None = None
```

应使用 `is None` / `is not None` 收窄。`if assignee_id:` 会同时把 0 当假，混淆“缺失”与合法零值。类型标注不会替你选择正确的业务语义。

## 5. 容器类型写出元素合同

现代 Python 直接给内置容器加方括号：

```python
order_ids: list[str] = ["WO-001", "WO-002"]
coordinate: tuple[int, int] = (10, 20)
statuses: set[str] = {"CREATED", "ASSIGNED"}
counts: dict[str, int] = {"CREATED": 1}
```

含义：

- `list[str]`：元素都是 str 的列表；
- `tuple[int, int]`：恰好两个 int 槽位；
- `tuple[str, ...]`：任意长度、元素都是 str；
- `set[str]`：元素是 str 的集合；
- `dict[str, int]`：键是 str，值是 int。

嵌套结构也能表达：

```python
summary: dict[int, list[str]] = {
    7: ["WO-001", "WO-003"],
}
```

标注越深越难读，是引入类型别名或数据类的信号。它仍不保证运行时收到的 dict 真符合结构。

### 5.1 tuple 的两种形状不能混淆

```python
pair: tuple[str, int] = ("WO-001", 4)
statuses: tuple[str, ...] = ("CREATED", "ASSIGNED")
empty: tuple[()] = ()
```

固定位置 tuple 可让每个槽位类型不同；省略号形式表示同类型任意长度。普通 `tuple` 太宽，类似 `tuple[Any, ...]`，会丢失有用信息。

### 5.2 可变容器与不变性

类型检查器通常不会允许把 `list[int]` 当作 `list[object]`。原因是 list 可变：若允许，接收方可向其中 append 字符串，从而破坏原本的 `list[int]`。初学时记住：可变容器的类型兼容比“int 是 object 的子类”更严格。需要只读遍历合同，后续可学习 `Iterable`、`Sequence` 等抽象类型。

## 6. 类型别名给复杂形状命名

Python 3.12+ 可用 `type` 语句：

```python
type TechnicianId = int
type OrdersByTechnician = dict[TechnicianId, list[str]]


def group_order_ids() -> OrdersByTechnician:
    return {7: ["WO-001"]}
```

别名让签名更易读，但不会创建新的运行时业务类型。`TechnicianId` 与 int 在静态上等价，不能阻止把普通计数当技师 ID。如果要区分同为 int 的不同领域身份，需要后续讨论 `NewType` 或值对象；本章只建立别名基础。

旧代码常见：

```python
from typing import TypeAlias

OrdersByTechnician: TypeAlias = dict[int, list[str]]
```

Python 3.14 官方文档指出 `TypeAlias` 自 3.12 起已被 `type` 语句取代并标为弃用方向；新建 3.14 项目优先 `type`。这属于版本表面，维护旧版本库时需按最低 Python 版本决定。

### 6.1 别名不是 Schema

```python
type WorkOrderPayload = dict[str, object]
```

这只告诉检查器键和值的大范围类型，没有规定必需键、字段精确类型、未知字段策略或运行时错误格式。后续会学习 TypedDict/Pydantic 等更具体工具，但即便如此，Java 仍是 FactoryCare 公开业务合同和事实所有者。

## 7. 静态类型检查器如何工作

CPython 不自带强制项目类型检查命令。本章使用 mypy 2.3.0 作为真实检查器，并通过 uv 临时、固定版本运行：

```bash
uvx --from mypy==2.3.0 mypy --strict src
```

静态意味着它分析源代码，不执行程序。正常流程应分别运行：

```bash
uvx --from mypy==2.3.0 mypy --strict src
python3 -m unittest
```

前者检查可见类型关系，后者执行行为测试。二者退出码都应进入 CI 判据。

### 7.1 为什么固定检查器版本

类型检查器会修复推断、增加规则或改变诊断。若每台机器拉取“latest”，同一代码可能得到不同结果。教材资产固定 2.3.0；项目应在依赖锁文件和 CI 中固定，并在升级时单独审查新诊断。本章 `stable_core: false` 正是提醒：类型思想稳定，工具版本与部分推断属于可变化表面。

### 7.2 渐进类型

Python 类型系统允许逐步采用标注。无标注函数可能处于动态区域：

```python
def legacy(value):
    return value.unknown_method()
```

宽松配置未必报告。`--strict` 会启用一组更严格规则，包括要求函数定义有标注。严格不是魔法：显式 Any、忽略注释、第三方缺失 stub、反射和动态导入仍可形成盲区。

### 7.3 配置应提交到仓库

可在 `pyproject.toml` 中保存：

```toml
[tool.mypy]
python_version = "3.14"
strict = true
show_error_codes = true
warn_unused_ignores = true
```

团队必须运行同一配置。只在个人 IDE 开检查、CI 不检查，会让类型合同逐渐失效。不要全局 `ignore_missing_imports = true` 来追求绿色；应逐个依赖确认 stub、局部豁免和残余风险。

## 8. 类型收窄：先验证候选，再使用专属操作

联合值不能直接使用某一候选专属方法：

```python
def normalize(value: int | str) -> str:
    # return value.strip()  # int 没有 strip
    ...
```

用 `isinstance` 分支收窄：

```python
def normalize(value: int | str) -> str:
    if isinstance(value, int):
        return str(value)
    return value.strip()
```

在 if 分支中，检查器知道 value 是 int；其余路径知道是 str。None 同理：

```python
def uppercase(value: str | None) -> str:
    if value is None:
        return ""
    return value.upper()
```

提前返回能让后续范围更窄。若只写 `if value:`，静态和业务语义都可能不够精确。

### 8.1 assert 可以收窄，但不能代替边界验证

```python
def uppercase(value: str | None) -> str:
    assert value is not None
    return value.upper()
```

检查器可能据此收窄。然而断言可在优化模式下禁用，也不一定提供合适的客户端错误。它适合表达程序内部不变量，不适合验证外部请求。外部输入应明确分支并返回稳定错误。

### 8.2 `reveal_type` 是检查器诊断工具

```python
from typing import reveal_type

def inspect(value: int | str) -> None:
    if isinstance(value, int):
        reveal_type(value)
```

mypy 会报告推断类型。Python 运行时的 `typing.reveal_type` 还会输出运行时类型并返回原对象，但教学中应把它当临时诊断，不提交到业务日志。

## 9. Any：关闭检查传播，不是“未知但安全”

```python
from typing import Any


def unsafe(payload: Any) -> int:
    return payload.missing.deep.value + 1
```

Any 可以赋给几乎任何类型，也允许任意属性和调用。这让动态库集成更容易，同时会把错误推迟到运行时。Any 不是通配安全类型，而是“此处不做静态约束”的逃生口。

### 9.1 用 object 表示真正未知

```python
def normalize_external(value: object) -> str:
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, int):
        return str(value)
    raise TypeError("只接受 str 或 int")
```

所有普通值都可视为 object，但不能在未收窄时随意访问属性。这迫使边界代码验证。Python typing 没有一个与 TypeScript `unknown` 完全同名同语义的内置类型；基础代码中常用 object + narrowing 建立相似安全边界。

### 9.2 Any 如何污染后续

```python
def parse_payload(raw: Any) -> dict[str, int]:
    return raw
```

检查器可能接受返回，因为 Any 可赋给目标类型；运行时 raw 可能是字符串。解决方案不是只给返回写得更精确，而是在边界实际检查每一层。后续 Pydantic 章节会建立 Schema；本章资产用 `isinstance` 对照证明标注本身不校验。

### 9.3 类型忽略是债务

```python
value = external_call()  # type: ignore[no-untyped-call]
```

忽略应包含具体错误码、原因、替代验证和清理条件。裸 `# type: ignore` 会掩盖同一行未来出现的其他问题。开启 `warn_unused_ignores`，让已经不需要的豁免失败。

## 10. 标注在运行时是什么

函数通常可通过 `__annotations__` 观察标注元数据：

```python
def calculate(priority: int) -> str:
    return "URGENT" if priority >= 4 else "NORMAL"


print(calculate.__annotations__)
```

Python 3.14 改进了标注的延迟求值模型，复杂反射应使用官方 `annotationlib` / `typing.get_type_hints` 等规定接口，而不是假设所有标注都在定义时变成普通字典值。本章只要求理解：元数据可供工具读取，但不会自动包裹函数做参数校验。

最直接的反例：

```python
def echo_count(count: int) -> int:
    return count


result = echo_count("three")
print(result, type(result))
```

解释器会把字符串原样返回。mypy 检查调用源时会报告错误；如果值来自 Any 或动态调用，静态检查也可能看不到。

## 11. 输入 Schema 与类型标注的分工

HTTP JSON、消息队列、文件和模型输出都是不可信输入。过程应是：

```text
bytes/text
  -> 语法解析
  -> 结构与字段验证
  -> 业务约束和授权
  -> 内部已类型化对象
```

类型标注主要帮助最后一段内部代码保持合同。它不会检查：

- JSON 是否语法正确；
- 必需字段是否存在；
- `priority=99` 是否超范围；
- `tenant_id` 是否属于当前用户；
- 状态转换是否合法；
- 多传字段是否企图越权。

FactoryCare 客户端只调用 Java。Java 验证授权和状态机；Python 只能收到最小、只读、已授权输入，用于 AI/派生计算。Python 即使使用 Pydantic 验证形状，也不能因此越过 Java 的业务权限边界。

## 12. FactoryCare 的类型化派生函数

```python
type Status = str
type CountsByStatus = dict[Status, int]


def count_statuses(statuses: list[Status]) -> CountsByStatus:
    result: CountsByStatus = {}
    for status in statuses:
        result[status] = result.get(status, 0) + 1
    return result
```

这个函数的类型合同清楚，但 `Status = str` 并不限制 12 个合法状态。若来源不可信，仍需集合成员验证。即使来源可信，Python 也不应创建第 13 个业务状态；稳定词汇来自 Java 合同：

```python
KNOWN_STATUSES: frozenset[str] = frozenset({
    "CREATED", "TRIAGED", "ASSIGNED", "ACCEPTED", "IN_PROGRESS",
    "PENDING_PARTS", "PENDING_APPROVAL", "RESOLVED", "VERIFIED",
    "CLOSED", "REOPENED", "CANCELLED",
})
```

派生函数可以拒绝未知字符串，但不能决定新的状态迁移。类型安全与业务权限是正交维度。

### 12.1 嵌套 dict 的可读性边界

```python
type TechnicianSummary = dict[int, dict[str, list[str] | int]]
```

这种类型虽然能写，却把不同字段值塞入巨大联合，调用处不断收窄。它提示下一步应使用更明确的记录类型；本章先学会识别信号，不提前讲 dataclass、TypedDict 或 Pydantic 的完整方案。

## 13. 正例、负例与运行时对照

一个可靠类型实验应有三份证据：

### 13.1 正例必须通过静态检查

```python
def normalize(value: int | str) -> str:
    if isinstance(value, int):
        return str(value)
    return value.strip()


result: str = normalize(42)
```

运行 `mypy --strict` 应退出 0。

### 13.2 负例必须在预期位置失败

```python
def total(values: list[int]) -> int:
    return sum(values)


result: int = total([1, "2"])
```

检查器应在字符串元素处给出 list-item 等不兼容诊断。验证器不应只检查退出码非零，还应检查文件、行或稳定错误码，防止“工具根本没启动”也被误判为预期红。

### 13.3 同一负例可被解释器执行到不同结果

某些静态负例运行时立即抛错，另一些却能运行：

```python
def identity(value: int) -> int:
    return value


print(identity("not-an-int"))
```

运行成功恰好证明标注不自动验证。资产会把这项输出作为独立 oracle，不能把它修成抛错后又宣称展示了运行时差距。

## 14. 常见诊断如何阅读

### 14.1 忽略 None

```python
def upper_name(name: str | None) -> str:
    return name.upper()
```

静态错误通常说明联合中的 None 没有 `upper`。修复是在业务允许的位置处理 None，而不是 `# type: ignore` 或盲目 `cast`。

### 14.2 返回漂移

签名写 `-> int`，某分支返回 str 或隐式 None。检查所有控制流路径；不要只把签名改成 `int | str | None` 来让错误消失。联合扩大必须反映真实需求，否则是合同降级。

### 14.3 容器元素错

`list[int]` 中放 str。先定位产生错误元素的边界，而不是在最终 sum 前批量 `int(...)`，因为粗暴转换会隐藏非法来源和错误语义。

### 14.4 Any 没有报错

无诊断不表示安全。查看值为何成为 Any：无标注函数、第三方库缺 stub、JSON 解析结果、显式 Any 或 ignore。把边界收紧为 object，验证后返回精确类型。

## 15. 类型检查器也可能给出“假安全感”

下列情况都可能让检查通过但运行失败：

- 用 Any 穿过边界；
- 使用 `cast` 只告诉检查器一个结论，却没在运行时验证；
- `# type: ignore` 压制诊断；
- 第三方 stub 与实际库版本不一致；
- 反射、猴子补丁、动态属性或条件导入；
- 并发与状态逻辑错误；
- 单位、权限、范围等并非静态类型能表达的规则。

`cast(str, value)` 不转换值：

```python
from typing import cast

value: object = 42
name = cast(str, value)
# name.upper() 运行时仍失败
```

cast 是给检查器的声明，风险由开发者承担。外部边界应使用 `isinstance` 或 Schema 验证。

## 16. 类型合同的维护策略

### 16.1 从边界开始

先标注被大量调用的函数、I/O 后的内部模型和共享库 API，再逐步向内。全仓一次性加入 Any 只会制造“覆盖率很高”的假象。

### 16.2 严格模式与局部例外

新模块可默认 strict；遗留模块分阶段收紧。例外应局部、可追踪、有错误码。CI 保存检查器版本和配置，升级时单独处理新规则。

### 16.3 类型错误不应自动改业务合同

AI 常见做法是把返回类型扩大到 `object | None` 以消除红线。正确流程是先确认业务应返回什么，再修实现或合同。工具诊断是证据，不是需求来源。

### 16.4 测试仍然必需

类型检查不会证明金额计算正确、集合顺序正确、异常消息稳定或输入未修改。每个关键函数仍要有成功、边界、失败和副作用测试。

## 17. 与 TypeScript 的关键差异

- 两者都能静态检查联合和容器，但 Python 标注默认不由解释器强制；
- Python `Any` 与 TypeScript any 都会传播不安全；Python `object` 可承担部分 unknown 式边界，但语义并非完全相同；
- Python `str | None` 类似 TS `string | null`，但还要区分缺省实参；
- Python `type Alias = ...` 是类型别名语句，不是 JS 运行时对象工厂；
- mypy/pyright 是独立工具，CPython 执行不要求先通过它们；TypeScript 项目通常由 tsc/构建工具更紧密集成；
- Python 第三方包的 stub、`py.typed` 和运行版本组合会影响检查结果。

不要把 TS 已有直觉直接复制。尤其不能因为 Vue 前端类型已经校验，就信任跨 HTTP 到达 Python 的 JSON；网络边界会丢失静态保证。

## 18. 一套完整的实验顺序

1. 给无标注函数补参数和返回类型；
2. 运行 strict 正例，保存退出码 0；
3. 注入字符串到 `list[int]`，先预测错误位置和错误类别；
4. 运行负例，确认检查器真实启动且在预期 fixture 失败；
5. 写 `str | None`，删掉 None 分支，观察 union-attr；
6. 用 isinstance 或提前返回收窄，不用 ignore；
7. 把动态入口从 Any 改为 object，逐层验证；
8. 运行“标注 int 却传 str”的脚本，证明解释器仍接受绑定；
9. 为 FactoryCare 派生函数写类型与行为测试，并明确 Java 权限边界；
10. 用 120 秒讲清静态、运行时、Schema 三层证据。

每次修复后必须重跑原命令。若只看 IDE 红线消失，没有保存 CLI 版本、配置和退出码，证据不可复现。

## 19. 章末检查

你应能独立回答：

- Python 对象有类型与名称有固定类型有什么区别？
- 变量标注会自动创建值或拒绝错误赋值吗？
- `-> None` 表达什么？
- `str | None` 与“参数有默认值”为什么不同？
- `list[str]`、`tuple[str, ...]`、`dict[str, int]` 如何读？
- 为什么 `list[int]` 通常不能当 `list[object]`？
- Python 3.14 新项目为何优先 `type Alias = ...`？
- mypy 静态检查与 CPython 执行有什么阶段差异？
- `isinstance` 如何收窄联合？
- Any 为什么是逃生口，而 object 更适合不可信边界？
- cast 为什么不做运行时转换？
- 怎样用正例、负例和运行时对照证明三种不同结论？
- 类型标注为什么不能授权 Python 修改 FactoryCare 核心工单？

## 20. 本章边界与资料核验

稳定语言结论依据 Python 3.14 官方 typing 文档、类型标注语法与数据模型；检查器行为依据 mypy 2.3.0 官方文档并用固定版本实际运行。2026-07-24 核对入口：

- [Python 3.14：typing—类型提示支持](https://docs.python.org/3.14/library/typing.html)
- [Python 3.14：标注语法](https://docs.python.org/3.14/reference/simple_stmts.html#annotated-assignment-statements)
- [Python 3.14：数据模型中的标注](https://docs.python.org/3.14/reference/datamodel.html)
- [mypy 2.3.0：入门与静态/动态类型](https://mypy.readthedocs.io/en/stable/getting_started.html)

已验证：本机 CPython 3.14.3 的运行时标注对照，以及通过 uv 获取并固定的 mypy 2.3.0 strict 正例、预期负例、None 收窄和 Any/object 差异。未验证范围：pyright/ty 与 mypy 的诊断一致性、IDE 插件行为、第三方包 stub、annotationlib 高级反射、Pydantic/FastAPI 运行时 Schema、跨服务实际 payload 与 CI 平台缓存。后续若升级检查器，必须重新保存正负 fixture 证据。
