---
schema_version: 2
edition: 2026.2-draft
id: ch.python.protocol-generics
title: 泛型、Protocol、Callable 与结构类型
responsibility: 用 TypeVar/泛型、Protocol 和 Callable 表达可替换依赖与输入输出关系，整合 Python 语言、类型和对象能力，不依赖继承注册。
volume: '12'
order: 10
level: L2+
status: drafting
path: book/volume-12-python-data/chapters/ch.python.protocol-generics.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.classes-dataclass
version_surfaces:
- python-3.14
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“泛型、Protocol、Callable 与结构类型”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - python-generics-callable
  - python-protocol-structural
  covers_topics:
  - python.typevar-generic
  - python.generic-bound
  - python.callable-type
  - python.variance-intro
  - python.list
  - python.protocol
  - python.runtime-checkable-boundary
  - python.structural-subtyping
  - python.dependency-port
  - python.dataclass
  uses_capabilities:
  - python.language
  - python.typing-oop
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 定义泛型 Repository Protocol 并以文件/内存实现证明结构替换；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - python-generics-callable
  - python-protocol-structural
  covers_topics:
  - python.typevar-generic
  - python.generic-bound
  - python.callable-type
  - python.variance-intro
  - python.list
  - python.protocol
  - python.runtime-checkable-boundary
  - python.structural-subtyping
  - python.dependency-port
  - python.dataclass
  uses_capabilities:
  - python.language
  - python.typing-oop
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: type-checker-substitution-fixture-runtime-contrast
- id: diagnose
  kind: fault-diagnosis
  text: 面对“Protocol 成员漂移、泛型关系丢失或把静态 Protocol 当运行时验证”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - python-generics-callable
  - python-protocol-structural
  covers_topics:
  - python.typevar-generic
  - python.generic-bound
  - python.callable-type
  - python.variance-intro
  - python.list
  - python.protocol
  - python.runtime-checkable-boundary
  - python.structural-subtyping
  - python.dependency-port
  - python.dataclass
  uses_capabilities:
  - python.language
  - python.typing-oop
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 泛型、Protocol、Callable 与结构类型

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《类、对象模型、dataclass 与 enum》](ch.python.classes-dataclass.md)：结构类型需要能区分类的运行时行为和静态合同。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 类型不是为了让 Python 变成 Java，而是把“什么输入可以替换、输出与输入有什么关系、组件只依赖哪些能力”写成可检查合同。Python 运行时通常不强制注解；静态类型检查器、IDE 和测试共同提供证据。本章以 Repository 端口为主线，不要求实现类继承某个框架基类。

## 1. 为什么 `Any` 会丢掉关系

没有泛型的取首项：

```python
from typing import Any


def first(items: list[Any]) -> Any:
    return items[0]
```

传 `list[WorkOrder]`，返回注解仍是 Any。调用者可以错误地调用不存在的方法，类型检查器无法帮助。

真正合同是：输入元素是什么类型，输出就是什么类型。

Python 3.12+ 类型参数语法：

```python
def first[T] (items: list[T]) -> T:
    return items[0]
```

上例在类型参数 `]` 与参数列表 `(` 之间保留一个合法空格，避免 Markdown 工具把 PEP 695 的函数头误识别为链接；这个空格不改变 Python 语义，复制运行时可以保留。

兼容传统 TypeVar 写法：

```python
from typing import TypeVar

T = TypeVar("T")


def first(items: list[T]) -> T:
    return items[0]
```

本教材会识别两者。项目是否采用新语法取决于最低 Python 版本和工具支持；当前卷锁定 3.14，可使用新语法，但大量生态代码仍是 TypeVar。

### 1.1 泛型不是自动转换

`T` 是类型关系占位符，不会把 JSON dict 变成 WorkOrder，也不会运行验证。运行时输入若错误，仍可能直到操作时才失败。边界验证由 Pydantic/解析器等负责。

### 1.2 空集合与推断

`first([])` 没有元素，运行时抛 IndexError；类型参数也难从空字面量推断。泛型只表达类型，不保证非空。可改 API 返回 `T | None`、接受 NonEmpty 抽象或明确抛异常。

## 2. 泛型容器与函数

```python
def copy_items[T] (items: list[T]) -> list[T]:
    return list(items)
```

它保留输入输出元素关系。`list[T]` 是参数化类型，`list` 是运行时类。

### 2.1 多个类型参数

```python
def map_value[T, R] (value: T, transform: Callable[[T], R]) -> R:
    return transform(value)
```

输入 T，转换器接受 T 返回 R，整个函数返回 R。调用者传 WorkOrder 和 `WorkOrder -> str`，结果推断为 str。

### 2.2 泛型类

新语法：

```python
class Box[T]:
    def __init__(self, value: T) -> None:
        self.value = value

    def get(self) -> T:
        return self.value
```

传统：

```python
from typing import Generic, TypeVar

T = TypeVar("T")


class Box(Generic[T]):
    ...
```

`Box[int]` 与 `Box[str]` 对静态检查不同；运行时擦除/保留细节不能用作业务验证。

## 3. bound 与 constraints

有时类型参数必须具备上界：

```python
from typing import Protocol


class HasId(Protocol):
    id: int


def index_by_id[T: HasId] (items: list[T]) -> dict[int, T]:
    return {item.id: item for item in items}
```

T 受 HasId 上界约束，返回仍保留具体子类型，不只是 HasId。

传统写法：`T = TypeVar("T", bound=HasId)`。

constraints 表示只能从几个离散类型选择，例如 `TypeVar("TextOrBytes", str, bytes)`；它与上界“任意满足父合同的子类型”不同。不要为方便把所有业务类型塞进 constraints 联合。

### 3.1 上界不是运行时 isinstance

静态检查器验证调用关系；Python 运行时不会自动在函数入口拒绝对象。若输入来自外部，需要实际解析和验证。

## 4. Callable 表达函数合同

```python
from collections.abc import Callable


Formatter = Callable[[int, str], str]


def render_order(order_id: int, status: str, formatter: Formatter) -> str:
    return formatter(order_id, status)
```

`Callable[[int, str], str]` 表示两个位置参数与返回类型。它不擅长表达复杂命名参数、重载或属性；复杂可调用对象可用带 `__call__` 的 Protocol。

```python
class OrderFormatter(Protocol):
    def __call__(self, *, order_id: int, status: str) -> str: ...
```

这能表达 keyword-only 参数名。

### 4.1 不要把 Callable 变隐藏依赖袋

传一个明确 clock/logger/mapper 可测试；传 `Callable[..., Any]` 又从闭包偷偷访问数据库，会丢失合同。依赖应命名、最小且可替换。

## 5. nominal 与 structural typing

名义类型要求显式继承/注册：`class FileRepository(BaseRepository)`。结构类型关注对象实际拥有的成员，不要求继承同一个基类。

```python
from typing import Protocol


class WorkOrderRepository(Protocol):
    def get(self, order_id: int) -> WorkOrder | None: ...
    def save(self, order: WorkOrder) -> None: ...
```

任何签名兼容的类都可静态视为该 Protocol：

```python
class MemoryWorkOrderRepository:
    def get(self, order_id: int) -> WorkOrder | None:
        ...

    def save(self, order: WorkOrder) -> None:
        ...
```

无需写 `(WorkOrderRepository)`。这降低适配第三方/旧代码的侵入，也让端口由使用方定义。

### 5.1 duck typing 与 Protocol

传统 duck typing 是“能叫就当鸭子”，主要靠运行测试。Protocol 把所需结构显式写给静态工具，同时保持无需继承。两者精神相近，但证据不同。

## 6. Repository Protocol 设计

泛型端口：

```python
from typing import Protocol, TypeVar

T_co = TypeVar("T_co", covariant=True)
T = TypeVar("T")


class ReadRepository(Protocol[T_co]):
    def get(self, entity_id: int) -> T_co | None: ...


class Repository(Protocol[T]):
    def get(self, entity_id: int) -> T | None: ...
    def save(self, entity: T) -> None: ...
```

只读端口的 T 只出现在输出位置，可协变；读写端口既输入又输出，通常不变。

### 6.1 端口由消费者的需要决定

报表用例只需要 `list_active()`，不要依赖包含 delete/admin/cache 等几十个方法的“万能 Repository”。更小 Protocol：

- 易 fake；
- 实现选择更多；
- 变更影响更小；
- 权限边界更清楚。

### 6.2 方法签名是合同

参数名称/位置、可空性、返回类型、异常语义和副作用都重要。实现把 `get(int)` 改成 `get(str)`，即使方法名相同也不兼容。

静态工具检查形状，不能完全检查“找不到返回 None 而非抛异常”等语义；需要合同测试。

## 7. 内存与文件实现替换

```python
from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class WorkOrder:
    id: int
    status: str


class MemoryRepository:
    def __init__(self) -> None:
        self._items: dict[int, WorkOrder] = {}

    def get(self, entity_id: int) -> WorkOrder | None:
        return self._items.get(entity_id)

    def save(self, entity: WorkOrder) -> None:
        self._items[entity.id] = entity
```

文件实现可读写 JSON，但仍暴露同一业务端口。应用服务：

```python
def close_order(repository: Repository[WorkOrder], order_id: int) -> WorkOrder:
    order = repository.get(order_id)
    if order is None:
        raise LookupError(order_id)
    closed = WorkOrder(id=order.id, status="CLOSED")
    repository.save(closed)
    return closed
```

同一合同测试分别传 Memory/File 实现。File 的持久性、原子写和异常属于文件/异常章；这里验证替换。

## 8. Protocol 属性与可变性

```python
class HasStatus(Protocol):
    @property
    def status(self) -> str: ...
```

只读 property 允许实现用属性/只读描述符。直接写 `status: str` 可能被解释为可读写属性，限制更强。

如果消费者需要修改 `obj.status`，必须在 Protocol 表达 setter，并承担可变语义。优先让领域对象不可变，通过方法/新对象变化。

## 9. variance 入门

设 `UrgentOrder` 是 `WorkOrder` 子类型。

- 生产者只返回 T：`Producer[UrgentOrder]` 可当 `Producer[WorkOrder]`，协变；
- 消费者只接受 T：能处理所有 WorkOrder 的消费者也能处理 UrgentOrder，逆变；
- 可读写容器：通常不变。

为什么 `list[UrgentOrder]` 不能当 `list[WorkOrder]`：若允许，调用者可 append 普通 WorkOrder，破坏原列表元素合同。

只读输入参数可用 `Sequence[WorkOrder]` 获得更灵活协变；需要修改才要求 `list[WorkOrder]`。

### 9.1 不要凭感觉标 covariant

TypeVar 在输入/输出位置决定安全性。错误 variance 会被类型检查器拒绝或导致合同漏洞。先画生产/消费方向，再声明。

## 10. `@runtime_checkable` 的有限边界

默认 Protocol 用于静态检查。加：

```python
from typing import Protocol, runtime_checkable


@runtime_checkable
class Closeable(Protocol):
    def close(self) -> None: ...
```

可执行 `isinstance(value, Closeable)`。但运行时检查主要确认成员存在，不验证完整签名、参数/返回类型和业务语义；属性访问还可能有副作用/性能。

不能把它当外部 JSON schema 或安全验证。`isinstance(repo, WorkOrderRepository)` 通过不代表 `save` 真能保存、事务正确或异常合同一致。

### 10.1 何时用

插件边界需要粗粒度能力检查时可能使用；核心依赖更可靠的是构造时类型、静态检查和合同测试。不要因想“保险”给所有 Protocol runtime_checkable。

## 11. 类型检查器是独立工具

Python 3.14 解释器通常不会因注解不匹配拒绝运行：

```python
def double(value: int) -> int:
    return value * 2


print(double("x"))  # 运行可能输出 xx，静态检查应报参数错误。
```

因此质量门包含：

```text
python 执行/测试
+ 类型检查器（mypy/pyright 等，项目锁定版本和配置）
+ lint/format
```

本章资产可用标准库运行行为验证，但“缺成员在预期类型检查点失败”必须在项目选择的类型检查器上实际跑，不能只看解释器。

### 11.1 reveal_type

类型检查器提供 `reveal_type` 调试推断，通常不是运行时业务代码。确认泛型是否保留具体类型，完成后可移除或放类型测试 fixture。

## 12. 泛型 API 常见错误

### 12.1 输入输出都写 Any

```python
def load(repo: Any, id: Any) -> Any: ...
```

静态检查失效。修复定义最小 Protocol 与具体 ID/返回关系。

### 12.2 返回基类丢具体类型

函数输入 T 却返回 Base，调用者丢失具体能力。若实现确实保留对象，应返回 T；若只保证 Base，合同就应诚实，不要强行泛型。

### 12.3 类型参数彼此独立

```python
def choose[T, R] (first: T, second: R) -> T: ...
```

若业务要求两参数同类型，应都用 T。不同 TypeVar 表示可不同。

### 12.4 容器裸类型

`list` 不说明元素；写 `list[WorkOrder]`。`dict[str, Any]` 仍很宽，稳定结构可 TypedDict/dataclass/Pydantic。

### 12.5 过度抽象

只有一个实现、没有替换需求、端口反而复制实现所有方法时，Protocol 可能增加噪音。抽象应由消费者测试、外部边界或明确演化需要驱动。

## 13. 依赖倒置与 FactoryCare 边界

Python AI 用例不应直接 import 某个 HTTP/文件/数据库实现。应用层定义自己需要的端口：

```python
class EmbeddingStore(Protocol):
    def upsert(self, chunks: list[Chunk]) -> None: ...
    def search(self, query: list[float], limit: int) -> list[Hit]: ...
```

实现层适配供应商。更换库时应用服务/测试不变。

但 Java 仍是工单业务事实所有者。Python 的 `WorkOrderRepository` 若其实调用 Java API，应命名/文档说明只读快照和授权边界，不能变成本地第二主库。

## 14. 合同测试

共享测试套件：

```python
def assert_repository_contract(repo: Repository[WorkOrder]) -> None:
    order = WorkOrder(id=1, status="ASSIGNED")
    assert repo.get(1) is None
    repo.save(order)
    assert repo.get(1) == order
```

分别传内存/文件实现。静态检查证明形状，合同测试证明示例语义。还需失败矩阵：重复 ID、损坏文件、权限、并发等按层测试。

### 14.1 Fake 不是 Mock 所有调用

内存 fake 实现真实端口语义，比对每个内部调用的脆弱 mock 更接近替换原则。必要时 spy 记录副作用，但测试关注外部行为。

## 15. 故障案例

### 15.1 成员漂移

Protocol 改 `get` 为 `find`，实现未改。运行路径可能直到调用才 AttributeError；类型检查应先失败并指向实现赋值/参数。

修复所有实现和调用，运行类型门+合同套件。不要在应用层 `hasattr` 同时兼容两个名字无限期。

### 15.2 泛型关系丢失

Repository.get 返回 Any，错误实体流入关闭工单服务。首个证据是 reveal_type=Any/类型报告未报警。

修复用一致 T 连接 save/get；添加负类型 fixture。

### 15.3 把 runtime Protocol 当输入验证

攻击/错误对象只提供同名 `save`，isinstance 通过，但签名/行为错误。首个证据是 runtime check 仅形状。

修复外部数据用 schema 验证；依赖由可信装配创建，配合静态与合同测试。

### 15.4 variance 错误

把可读写 Repo 标协变，理论上可向 UrgentRepo 保存普通 WorkOrder。类型检查器报告协变 T 用于参数位置。

修复读写不变，或拆 ReadRepository（协变）与 Writer（逆变/不变）。

## 16. 实验

实现：

1. frozen WorkOrder dataclass；
2. `Repository[T]` Protocol：get/save；
3. Memory 实现；
4. JSON File 实现；
5. 一个只依赖 Protocol 的 `change_status` 服务；
6. 同一合同测试跑两实现；
7. `Callable[[WorkOrder], str]` 格式器注入；
8. 一个故意缺 save 的 BrokenRepository 类型 fixture；
9. 记录静态检查失败和运行时对照。

验收表：

| 证据 | 期望 |
| --- | --- |
| 类型检查 | 两实现可替换，Broken 在指定行失败 |
| 合同测试 | get missing/save/get roundtrip 一致 |
| Callable | 输入 WorkOrder 输出 str，异常不吞 |
| runtime check | 明确只做成员存在粗检，不声称签名验证 |
| 文件实现 | 原子/编码/异常边界由对应章节验证 |

## 17. 自测与参考答案

1. **T 的作用？** 保留多处类型之间的关系，不是运行时转换。
2. **bound 与 constraints？** bound 接受上界的任意子类型；constraints 从列出的候选选择。
3. **Protocol 是否要求继承？** 结构子类型不要求，成员签名兼容即可。
4. **Callable 何时不足？** 复杂命名参数/属性时用 `__call__` Protocol。
5. **list 是否协变？** 否，可变 list 通常不变，避免写入破坏。
6. **只读输入为何用 Sequence？** 更宽、可协变且表达不修改。
7. **runtime_checkable 验证签名吗？** 不能完整验证，只是有限成员检查。
8. **注解会自动阻止错误运行吗？** 通常不会，需要类型检查器。
9. **静态通过为何还要合同测试？** 类型不证明存储/异常/副作用语义。
10. **越界反例？** 用 Protocol 直接验证外部 JSON 或认证；应交给运行时 schema/安全边界。

## 18. 章节验收清单

- [ ] 能用 TypeVar 与 Python 3.14 类型参数语法表达输入输出关系。
- [ ] 能选择 bound/constraints，不把它们当运行验证。
- [ ] 能用 Callable 或 `__call__` Protocol 表达回调。
- [ ] 能解释 nominal/structural/duck typing 的证据差异。
- [ ] 能按消费者需求定义最小 Repository Protocol。
- [ ] 能以 Memory/File 实现运行同一合同测试。
- [ ] 能解释协变、逆变、不变以及 list 不变原因。
- [ ] 能说明 runtime_checkable 的限制。
- [ ] 能运行锁定的类型检查器和负类型 fixture。
- [ ] 能保留 Java 业务事实与 Python 派生端口边界。

### 18.1 Union、overload 与泛型的选择

`WorkOrder | Device` 说明一个值可以是两种类型，却没有自动表达“输入 WorkOrder 时输出一定也是 WorkOrder”。这种输入输出关联应使用同一个类型参数。`@overload` 适合少量离散调用形态，例如字符串输入返回字符串、字节输入返回字节；实现仍只有一个，并须覆盖所有 overload。若规则对任意 T 都相同，泛型比列出十几个 overload 更准确。不要用 overload 为运行时不可能区分的返回值许诺精确类型，也不要让实现签名比 overload 集合更窄。

方法返回当前具体子类时可研究 `Self`，例如 fluent builder；但 Repository 的 entity 类型与 repository 自身类型是两个概念，不能都用 Self。选择步骤是：先用自然语言写关系，再问它是“一个值多种可能”（Union）、“若干离散签名”（overload）、“任意类型保持关系”（TypeVar）还是“只需要一组能力”（Protocol）。最后用正/负类型 fixture 证明推断，而不是仅看 IDE 没有红线。

### 18.2 类型合同也需要演化策略

给 Protocol 新增抽象成员会让所有结构实现立即不兼容，是一次合同变更。先搜索所有生产实现、Fake、测试和第三方适配器；若能力并非所有消费者都需要，拆成更小 Protocol，而不是给每个实现塞一个抛 `NotImplementedError` 的空方法。返回从 `T` 改成 `T | None` 会把缺失处理传播给调用者；参数从只读 Sequence 收紧为 list 会减少可替换输入。类型检查报告展示静态影响，运行合同测试展示语义影响，两者都通过后再合并。对外部插件还要给迁移期、版本和失败信息，不能依赖结构类型让破坏“悄悄发生”。

## 19. 官方资料与更新检查

- `typing`：<https://docs.python.org/3.14/library/typing.html>
- Typing specification：<https://typing.python.org/en/latest/spec/>
- Generics：<https://typing.python.org/en/latest/spec/generics.html>
- Protocols：<https://typing.python.org/en/latest/spec/protocol.html>
- `collections.abc`：<https://docs.python.org/3.14/library/collections.abc.html>

资料核对日期：2026-07-24。类型检查器支持细节会变化；最小能力端口、类型关系、替换测试和静态/运行时证据分离是稳定核心。
