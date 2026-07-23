---
schema_version: 2
edition: 2026.2-draft
id: ch.python.classes-dataclass
title: 类、对象模型、dataclass 与 enum
responsibility: 用类、构造、封装、dataclass 和 enum 表达具有不变量的数据对象，理解方法解析和组合边界，不提前教授 Protocol 或泛型。
volume: '12'
order: 9
level: L2
status: drafting
path: book/volume-12-python-data/chapters/ch.python.classes-dataclass.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.typing-foundations
version_surfaces:
- python-3.14
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“类、对象模型、dataclass 与 enum”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - python-class-model
  - python-dataclass-enum
  covers_topics:
  - python.class-instance
  - python.init-constructor
  - python.instance-class-attribute
  - python.method-binding
  - python.composition-inheritance
  - python.dataclass
  - python.dataclass-frozen
  - python.field-default-factory
  - python.enum
  - python.object-invariant
  uses_capabilities:
  - python.language
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“类、对象模型、dataclass 与 enum”构建可运行程序与测试：用 frozen dataclass、enum 和服务类建模工单状态与不变量；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - python-class-model
  - python-dataclass-enum
  covers_topics:
  - python.class-instance
  - python.init-constructor
  - python.instance-class-attribute
  - python.method-binding
  - python.composition-inheritance
  - python.dataclass
  - python.dataclass-frozen
  - python.field-default-factory
  - python.enum
  - python.object-invariant
  uses_capabilities:
  - python.language
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: object-contract-cases-type-checker-identity-equality-check
- id: diagnose
  kind: fault-diagnosis
  text: 面对“共享类属性、可变默认字段或 dataclass 相等语义误用”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - python-class-model
  - python-dataclass-enum
  covers_topics:
  - python.class-instance
  - python.init-constructor
  - python.instance-class-attribute
  - python.method-binding
  - python.composition-inheritance
  - python.dataclass
  - python.dataclass-frozen
  - python.field-default-factory
  - python.enum
  - python.object-invariant
  uses_capabilities:
  - python.language
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 类、对象模型、dataclass 与 enum

> 本章状态为 `drafting`。配套资产在当前 Python 3.14 解释器验证对象身份、方法绑定、非法构造、frozen 行为、`default_factory` 隔离和 enum 解析；没有运行第三方静态类型检查器，也没有把模型持久化或映射到 Java API。运行时通过不代表跨服务契约已经验证。

函数适合表达“输入经过计算得到输出”；对象适合表达“一组数据、行为与长期不变量共同拥有一个身份或值”。Python 中类也是对象，实例属性可以动态出现，方法取出时会发生绑定，继承遵循方法解析顺序。灵活性让原型开发很快，也让共享类属性、半合法实例和错误相等语义更容易潜入生产。

本章不以“把所有函数塞进 class”作为面向对象。我们从对象的身份、类型和值开始，理解类语句、实例创建、`__init__`、属性查找与方法绑定；再用普通类表达有行为的服务，用 dataclass 消除值对象样板，用 enum 约束有限状态。Protocol 和泛型在下一章，文件序列化在上一章，Web 模型映射在后续章节。

## 1. 完成定义、资产入口与边界

学完后，你应能：

1. 解释每个 Python 对象都有身份、类型和值，以及 `is` 与 `==` 的区别；
2. 说明类对象与实例对象的关系，知道 `__init__` 初始化已有实例而非通常意义上分配对象；
3. 区分实例属性与类属性，预测属性查找和赋值会发生什么；
4. 解释 `obj.method()` 为什么自动传入实例，避免手工重复传 `self`；
5. 用下划线约定、只读 property 和行为方法保护不变量，而不假装 Python 有绝对私有；
6. 比较组合与继承，识别错误 is-a 关系和脆弱多继承；
7. 解释 dataclass 自动生成哪些方法，以及 `eq`、`frozen`、`slots`、`kw_only` 的边界；
8. 使用 `field(default_factory=...)` 隔离可变默认值，并证明两个实例不共享对象；
9. 选择 enum 表达封闭状态集合，安全解析外部字符串；
10. 根据业务含义决定实体与值对象的相等语义，不被 dataclass 默认值替你做架构决定。

配套入口：

- [工单值对象、enum 与服务组合示例](../../../examples/encyclopedia/ch.python.classes-dataclass/README.md)
- [共享状态、浅 frozen 与相等语义实验](../../../labs/encyclopedia/ch.python.classes-dataclass/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.python.classes-dataclass/README.md)

本章不教授 Protocol、TypeVar 或泛型容器，不引入 ORM，也不让 Python 复制 Java 的核心工单状态机。示例只建模 AI 侧草稿/快照，Java 仍是业务事实所有者。

## 2. 对象有身份、类型和值

Python 语言参考把对象视为数据的抽象。每个对象有：

- **identity**：创建后不变，用 `is` 比较，`id()` 返回身份相关整数；
- **type**：决定支持哪些操作，用 `type()` 观察；
- **value**：对象承载的内容，可变对象的值可变化。

```python
left = ["WO-1"]
right = ["WO-1"]
alias = left

assert left == right
assert left is not right
assert alias is left
```

`==` 调用相等协议，通常比较值；`is` 比较是否同一个对象。判断 `None` 应使用 `is None`，因为 `None` 是单例语义，而且自定义类可以重载 `==`。

不要根据小整数或短字符串在当前解释器中偶然 `is` 相同来推断值相等。驻留属于实现优化，不是业务合同。

### 2.1 可变与不可变

list、dict、set 通常可变；int、str、tuple 通常不可变。不可变容器不等于深不可变：tuple 中可以包含 list，list 仍能改变。对象模型设计要问“可达对象图是否会变化”，而不只看最外层类型。

```python
container = (["draft"],)
container[0].append("reviewed")
```

tuple 本身没有换元素，内部 list 却变了。这是理解 frozen dataclass 的前置。

## 3. 类语句创建类对象

```python
class Priority:
    minimum = 1
    maximum = 5

    def __init__(self, value: int) -> None:
        if not self.minimum <= value <= self.maximum:
            raise ValueError("priority out of range")
        self._value = value

    @property
    def value(self) -> int:
        return self._value
```

执行 `class` 语句会执行类体，建立命名空间，再创建类对象并把它绑定到名字 `Priority`。因此类也是运行时对象：可传参、可查询属性、可实例化。类体不应做昂贵 I/O；它与模块顶层一样在导入时执行。

调用 `Priority(3)` 大致经历创建实例与初始化实例。通常 `__new__` 负责创建，`__init__` 接收已创建实例并设置初始状态。初学代码很少需要重写 `__new__`，但要准确说：`__init__` 不是返回新对象的工厂，必须返回 `None`。

### 3.1 `self` 不是关键字，却是强约定

实例方法第一个参数按约定叫 `self`。类中定义：

```python
def describe(self) -> str:
    return f"P{self._value}"
```

调用：

```python
priority.describe()
```

从实例取函数时，描述符协议生成绑定方法，把实例绑定为第一个参数。因此它近似：

```python
Priority.describe(priority)
```

若写 `priority.describe(priority)` 就多传一次。把方法从类上取出与从实例上取出，结果不同：前者通常是函数，后者是绑定方法，可用 `__self__` 观察绑定对象。

## 4. 实例属性与类属性

类属性属于类对象并可被实例查找到。实例属性通常放在实例自己的 `__dict__`，赋值时会遮蔽同名类属性：

```python
class Ticket:
    category = "GENERAL"

first = Ticket()
second = Ticket()
first.category = "ELECTRICAL"

assert first.category == "ELECTRICAL"
assert second.category == "GENERAL"
assert Ticket.category == "GENERAL"
```

查找 `first.category` 时先看实例，再沿类与基类的方法解析顺序寻找。给实例赋值通常不会改类属性；给 `Ticket.category` 赋值会影响所有尚未遮蔽它的实例。

### 4.1 共享可变类属性陷阱

```python
class BadQueue:
    items: list[str] = []

    def add(self, item: str) -> None:
        self.items.append(item)
```

两个实例都通过类找到同一个 list。`self.items.append` 改的是共享列表，没有触发实例赋值。

修复：

```python
class Queue:
    def __init__(self) -> None:
        self.items: list[str] = []
```

每次初始化都创建新 list。类属性适合真正共享且通常不可变的常量；可变实例状态在构造时建立。

### 4.2 属性查找不是简单字典二选一

property、方法等描述符会参与查找；多继承还会沿 MRO。调试时可观察 `vars(instance)`、`vars(type(instance))` 和 `type(instance).__mro__`，但不要在业务逻辑中依赖随意篡改 `__dict__`。公开行为比内部存储更稳定。

## 5. 封装与不变量

Python 常用单下划线表达非公开实现：`_status`。双下划线会触发名称改写，用于减少子类意外冲突，不是安全权限。任何能运行进程内代码的调用者通常仍能访问内部属性。

真正的封装目标是：让对象始终处于合法状态，并让修改通过命名行为发生。

```python
class WorkOrderDraft:
    def __init__(self, title: str) -> None:
        normalized = " ".join(title.split())
        if not normalized:
            raise ValueError("title must not be blank")
        self._title = normalized

    @property
    def title(self) -> str:
        return self._title
```

若 title 创建后不该随意变化，不提供 setter。若允许改名，提供 `rename(new_title)`，在一个地方执行校验、审计提示或派生更新。直接公开字段并不一定错；简单数据载体可以公开。关键是依据不变量与演化需求选择，而不是模仿 Java getter/setter。

### 5.1 构造时拒绝非法状态

“先创建空对象，稍后补字段”会让所有方法都必须处理半初始化。更可靠的是构造成功即合法：

```python
if not order_id.startswith("WO-"):
    raise ValueError("invalid work-order id")
```

对象不能单独验证的跨实体规则放在服务或仓储边界，例如“处理人必须属于同租户”需要外部事实。不要为了让对象“聪明”而在 `__init__` 里访问数据库。

## 6. 实例方法、类方法与静态方法

实例方法需要对象状态。类方法接收类 `cls`，适合尊重继承的替代构造器。静态方法不自动接收实例或类，只是放在类命名空间里的函数。

```python
class WorkOrderId:
    def __init__(self, value: str) -> None:
        if not value.startswith("WO-"):
            raise ValueError("invalid id")
        self.value = value

    @classmethod
    def from_number(cls, number: int) -> "WorkOrderId":
        if number <= 0:
            raise ValueError("number must be positive")
        return cls(f"WO-{number}")
```

不必把所有工具函数标成 `@staticmethod`。若函数不依赖类概念，模块级函数更直观。类方法的价值不是“看起来 OOP”，而是它确实构造该类或子类。

## 7. 组合优先与继承边界

继承表达“子类是父类的一种，并遵守其合同”。组合表达“对象拥有或使用另一个对象”。

```python
class PriorityPolicy:
    def score(self, severity: int, safety_risk: bool) -> int:
        return min(5, severity + (1 if safety_risk else 0))


class SuggestionService:
    def __init__(self, policy: PriorityPolicy) -> None:
        self._policy = policy

    def suggest(self, severity: int, safety_risk: bool) -> int:
        return self._policy.score(severity, safety_risk)
```

服务“使用”策略，组合清楚且易测试。若写 `SuggestionService(PriorityPolicy)`，语义变成服务是一种策略，通常不成立。

### 7.1 继承何时合理

稳定框架扩展点、真正可替换的特化对象和异常层次可能适合继承。子类必须保持基类可观察合同，不能让调用者因换成子类就破坏前置/后置条件。

### 7.2 MRO 与 `super`

Python 用方法解析顺序决定多继承查找。`super()` 不是简单“调用我的直接父类”，而是沿当前 MRO 的下一个实现协作。多继承中各类构造签名与 `super()` 使用必须兼容，否则某一层可能被跳过或重复执行。

本路线默认用单继承或组合。mixin 应职责窄、无隐蔽状态，并有 MRO 测试。不要用多继承拼装核心工单领域。

## 8. dataclass 解决什么

值对象经常需要字段、初始化、展示和相等比较。手写会重复：

```python
from dataclasses import dataclass

@dataclass
class Point:
    x: int
    y: int
```

`@dataclass` 检查类中带类型标注的字段，并按参数生成 `__init__`、`__repr__`、`__eq__` 等。类型标注本身不会自动做运行时类型校验：`Point("x", "y")` 可能仍能构造，除非静态检查或运行时边界拦截。

默认大致为 `init=True, repr=True, eq=True, order=False, unsafe_hash=False, frozen=False`，另有 `kw_only`、`slots` 等选项。不要背签名代替选择：每一个生成行为都必须与对象语义一致。

### 8.1 字段顺序成为接口

生成的 `__init__` 与比较按声明顺序。公开值对象建议 `kw_only=True`，避免调用方依赖位置：

```python
@dataclass(frozen=True, slots=True, kw_only=True)
class Suggestion:
    order_id: str
    summary: str
```

调用 `Suggestion(order_id="WO-1", summary="...")` 自解释，新增默认字段也更安全。

### 8.2 `__post_init__` 维护不变量

```python
@dataclass(frozen=True, slots=True, kw_only=True)
class Suggestion:
    order_id: str
    summary: str

    def __post_init__(self) -> None:
        if not self.order_id.startswith("WO-"):
            raise ValueError("invalid order id")
        if not self.summary.strip():
            raise ValueError("summary must not be blank")
```

`__post_init__` 在生成的初始化后调用。若需要规范化 frozen 字段，可以谨慎使用 `object.__setattr__`：

```python
object.__setattr__(self, "summary", " ".join(self.summary.split()))
```

这应只发生在初始化不变量阶段。到处绕过 frozen 会使承诺失去意义。

## 9. 默认值与 `default_factory`

函数默认参数的可变对象会被复用，字段也有类似风险。dataclass 会拒绝一部分明显的不可哈希可变默认值，但正确表达仍是工厂：

```python
from dataclasses import dataclass, field

@dataclass
class ReviewQueue:
    items: list[str] = field(default_factory=list)
```

每次构造都调用 `list`，得到不同对象：

```python
first = ReviewQueue()
second = ReviewQueue()
first.items.append("WO-1")
assert second.items == []
assert first.items is not second.items
```

错误写法的本质不是语法，而是默认对象在类定义时创建一次。若默认值依赖当前时间，也应使用工厂：`field(default_factory=lambda: datetime.now(UTC))`；直接 `created_at=datetime.now(UTC)` 会让所有实例共享类定义时刻。

`default_factory` 必须是零参数可调用对象。不要写 `default_factory=list()`，那是立即调用后的 list，不是工厂。

## 10. frozen 是浅层防赋值

`@dataclass(frozen=True)` 生成阻止字段重新赋值/删除的行为：

```python
@dataclass(frozen=True)
class Snapshot:
    order_id: str
```

`snapshot.order_id = "WO-2"` 会抛 `FrozenInstanceError`。但若字段指向 list：

```python
@dataclass(frozen=True)
class ShallowFrozen:
    tags: list[str] = field(default_factory=list)

value = ShallowFrozen()
value.tags.append("urgent")  # 允许，list 本身仍可变
```

因此不可变值对象优先使用 tuple、frozenset 或其他不可变子对象。frozen 也不是安全沙箱；反射和底层方法可绕过。它的价值是把意外赋值变成早期错误，并帮助表达值语义。

### 10.1 `slots=True`

slots 可减少每实例存储并限制随意新增属性，常能及早发现拼写错误。它会改变类创建、继承、弱引用、序列化和反射的一些行为。不要仅为“性能最佳实践”全局开启；先在大量稳定值对象上测量与验证工具兼容。

## 11. 相等、哈希与实体语义

dataclass 默认 `eq=True`，比较同一具体类的所有 `compare=True` 字段。对坐标、金额、派生建议等值对象通常合理；对有生命周期身份的实体可能错误。

```python
@dataclass
class Technician:
    id: str
    display_name: str
```

默认相等会让同 ID 但 display_name 不同的对象不相等，也让不同业务来源但字段碰巧相同的对象相等。你必须先定义实体语义：是否仅 ID 决定相等、是否对象身份决定、是否根本避免在跨层实体上使用自动 `eq`。

可选择 `@dataclass(eq=False)` 并显式实现，或把 ID 建成值对象、在服务中按 ID 比较。不要为了测试方便就接受默认。

### 11.1 `is` 与 `==` 的测试

```python
@dataclass(frozen=True)
class WorkOrderId:
    value: str

first = WorkOrderId("WO-1")
second = WorkOrderId("WO-1")
assert first == second
assert first is not second
```

这是值对象：不同实例可值相等。实体对象则可能拥有同 ID 的不同时间快照，是否相等需要合同。

### 11.2 哈希

dict 键与 set 元素要求哈希稳定。可变对象若参与哈希，放入 set 后再改变会破坏查找。dataclass 根据 `eq` 与 `frozen` 谨慎决定是否生成 `__hash__`；`unsafe_hash=True` 的名字已提示风险。不要为了“让它能放 set”盲目开启，先让参与哈希的状态真正不可变。

## 12. `ClassVar` 与初始化专用值

若一个标注名称是类级常量，不应成为 dataclass 字段，可用 `ClassVar`：

```python
from typing import ClassVar

@dataclass(frozen=True)
class Priority:
    MINIMUM: ClassVar[int] = 1
    MAXIMUM: ClassVar[int] = 5
    value: int
```

它不会进入生成的初始化和字段列表。若值只用于初始化但不应保存，可了解 `InitVar`；使用过多通常说明构造过程需要工厂或服务。保持对象公开状态可解释比炫技更重要。

## 13. enum 表达有限集合

状态不是任意字符串：

```python
from enum import StrEnum

class SuggestionStatus(StrEnum):
    DRAFT = "DRAFT"
    REVIEWED = "REVIEWED"
    REJECTED = "REJECTED"
```

成员有稳定名字和值，可迭代，可按值构造：

```python
status = SuggestionStatus("DRAFT")
assert status is SuggestionStatus.DRAFT
```

未知值会抛 `ValueError`，这是边界证据。外部输入仍应捕获并在适配层转换为合适错误；本章不定义统一异常映射。

### 13.1 为什么不用魔法整数

`1`、`2` 缺少语义，调试日志难读，重排会破坏持久化。若协议已规定数字值，可以使用 `IntEnum`，但仍需冻结映射。字符串 enum 更适合可读 API，但也不能随意改值。

### 13.2 alias 与唯一性

enum 允许多个名字共享同一值形成别名。业务状态通常希望值唯一，可用 `@unique` 在类创建时检查。别名适合兼容迁移时也要显式记录，不能意外重复。

### 13.3 Python enum 不拥有 Java 状态机

FactoryCare 的十二个工单状态由 Java 定义并执行业务迁移。Python 若镜像字符串用于只读建议，必须把未知状态视为版本不兼容，而不是自己新增迁移或写回核心事实。Python 侧示例使用 `SuggestionStatus`，避免伪造工单权威。

## 14. 数据对象、服务对象与适配器

一个清晰拆分：

- dataclass 值对象：承载已验证的小型数据和局部不变量；
- enum：承载有限集合；
- 普通服务类：组合策略和执行用例；
- 适配器：把外部 dict/JSON/API 映射为对象，再映射出去。

```python
@dataclass(frozen=True, slots=True, kw_only=True)
class PrioritySuggestion:
    order_id: str
    level: int
    status: SuggestionStatus = SuggestionStatus.DRAFT

    def __post_init__(self) -> None:
        if not self.order_id.startswith("WO-"):
            raise ValueError("invalid order id")
        if not 1 <= self.level <= 5:
            raise ValueError("level must be between 1 and 5")
```

服务：

```python
class SuggestionService:
    def __init__(self, policy: PriorityPolicy) -> None:
        self._policy = policy

    def suggest(self, order_id: str, severity: int) -> PrioritySuggestion:
        return PrioritySuggestion(
            order_id=order_id,
            level=self._policy.score(severity),
        )
```

对象不联网、不读数据库。服务也不直接篡改 Java 工单，只产生明确的建议值。

## 15. 从外部 dict 到对象必须验证

类型标注和 dataclass 不会自动验证运行时输入：

```python
payload: object = {"orderId": "WO-1", "level": "high"}
```

不能直接 `PrioritySuggestion(**payload)`：键名、类型、未知字段与权限都不匹配。适配器应逐字段检查或使用后续 Pydantic 模型。领域对象的 `__post_init__` 是最后防线，不替代边界 schema。

反向序列化也不应盲目 `asdict`。`asdict` 会递归深拷贝 dataclass、容器等，但 enum、日期与字段命名仍需 wire 合同；内部新增字段可能意外泄露。显式 mapper 更安全：

```python
def to_response(value: PrioritySuggestion) -> dict[str, object]:
    return {
        "orderId": value.order_id,
        "level": value.level,
        "status": value.status.value,
    }
```

## 16. 继承 dataclass 的注意点

dataclass 字段会沿继承顺序组合，默认字段与非默认字段顺序可能冲突；生成方法和自定义方法也相互影响。frozen 与非 frozen 继承有约束。核心值对象优先扁平、小而明确；需要共享行为时考虑模块函数或组合。

不要建立“BaseEntity 包含 id、created_at、updated_at、所有验证”的万能基类。它会把持久化字段渗入所有领域对象，并让不同生命周期被迫一致。少量重复往往比错误抽象便宜。

## 17. 故障诊断矩阵

| 故障 | 现象 | 首个可信证据 | 修复方向 |
| --- | --- | --- | --- |
| 共享类 list | 改 first，second 也变化 | `first.items is second.items` 为真 | 在 `__init__` 或 default_factory 创建 |
| 可变默认参数 | 新实例带上旧数据 | 构造前后对象 identity | 零参数工厂 |
| frozen 内部 list | 字段不能赋值但 append 成功 | 嵌套对象 identity/value | 使用 tuple/frozenset/不可变子对象 |
| 默认 dataclass eq 不符实体 | display name 改后同 ID 不等 | `__dataclass_fields__` 与比较结果 | 先定义实体相等合同 |
| 方法多传 self | positional argument 数量错误 | traceback 指向绑定方法调用 | 用 `obj.method(args)` |
| 类属性被实例遮蔽 | 只一个实例看到新值 | `vars(instance)` 出现同名字段 | 明确类/实例所有权 |
| enum 未知值 | 构造 ValueError | 输入值与 enum 列表 | 边界拒绝或显式版本迁移 |
| 错误继承 | 子类不能替代基类 | 行为合同测试失败 | 改组合或重定义抽象 |

修复后必须新建两个实例重跑 identity 与值断言，只看单个实例无法证明共享状态消失。

## 18. 测试对象合同

至少覆盖：

1. 合法最小值和最大值构造；
2. 空白、越界和错误 enum 值拒绝；
3. 规范化后的字段值；
4. frozen 字段重新赋值失败；
5. 嵌套状态确实不可变，或明确测试其可变边界；
6. 两个默认容器不是同一对象；
7. 值相同实例 `==` 为真但 `is` 为假；
8. 实体相等按约定工作；
9. 绑定方法自动接收 self；
10. 服务组合的策略替身被调用，且领域对象不执行 I/O；
11. enum 成功与未知输入；
12. mapper 不泄露内部字段。

若启用静态类型检查，还要保存正负夹具；但本章离线资产没有安装第三方检查器，因此不把运行结果伪装成静态证据。

## 19. 常见误区与修正规则

**“面向对象就是所有函数放进类。”** 模块函数也有清楚所有权。规则：只有数据、行为与不变量需要共同演化时建对象。

**“self 是特殊变量，Python 自动创建。”** 它只是约定参数名，绑定机制自动传实例。规则：理解 `Class.method(instance, ...)` 等价模型。

**“下划线保证私有。”** 只是协作约定。规则：安全权限在进程与 API 边界。

**“类属性相当于 Java 实例字段声明。”** 类属性由实例共享查找。规则：可变实例状态在初始化中创建。

**“dataclass 会验证类型。”** 默认不会。规则：静态工具加运行时边界验证。

**“frozen 就深不可变。”** 只阻止字段赋值。规则：字段也用不可变值。

**“默认 eq 总是方便。”** 它可能错误定义实体。规则：先写相等语义，再选生成参数。

**“继承能减少重复，所以优先。”** 错误 is-a 会制造耦合。规则：默认组合，继承需要可替换合同。

**“enum 值就是显示文案。”** 协议值与本地化文案职责不同。规则：稳定值单独映射展示。

## 20. 独立构建任务

实现 Python AI 侧 `PrioritySuggestion`，不得复制 Java 工单写权限：

1. 定义 `SuggestionStatus(StrEnum)`：DRAFT、REVIEWED、REJECTED；
2. 定义 frozen、slots、kw_only dataclass；
3. 字段含 `order_id`、`level`、`reasons` 的不可变 tuple、状态；
4. `__post_init__` 校验 ID、1..5、非空理由，并规范化理由空白；
5. 定义普通 `SuggestionService`，通过构造参数组合评分策略；
6. 定义一个使用 `default_factory=list` 的训练用审查队列，并证明实例隔离；
7. 保存非法 ID、越界 level、未知 enum、frozen 赋值、两个默认容器和相等/身份证据；
8. 故意建立共享类列表，先让测试红，再修复；
9. 写出为何 suggestion 是值对象而 Java work order 是业务实体；
10. 不读文件、不联网、不更新工单状态。

## 21. 自检问题

1. `is` 与 `==` 各比较什么？
2. `__init__` 为什么不是普通意义上的对象分配函数？
3. `obj.method()` 的实例参数从哪里来？
4. `self.items.append` 为什么可能修改类属性中的共享 list？
5. property 解决什么，为什么不是安全权限？
6. 什么条件下继承比组合更合适？
7. dataclass 根据什么识别字段，会不会自动检查运行时类型？
8. 为什么 `default_factory=list` 必须传函数而不是 `list()`？
9. frozen dataclass 中 list 为什么仍能 append？
10. 默认 dataclass `eq` 为什么可能不适合实体？
11. enum 未知输入应该静默创建新成员吗？
12. `asdict` 为什么不是稳定 API 序列化合同？

## 22. 官方资料与版本说明

以下链接在 2026-07-24 按 Python 3.14 文档核对：

- [Python 3.14 Data model](https://docs.python.org/3.14/reference/datamodel.html)：对象身份、类型、值、类与特殊方法；
- [Python Tutorial: Classes](https://docs.python.org/3.14/tutorial/classes.html)：作用域、实例、类属性、继承与方法；
- [dataclasses — Data Classes](https://docs.python.org/3.14/library/dataclasses.html)：生成方法、field、frozen、slots、ClassVar 与 InitVar；
- [enum — Support for enumerations](https://docs.python.org/3.14/library/enum.html)：Enum、StrEnum、唯一性与成员行为；
- [Enum HOWTO](https://docs.python.org/3.14/howto/enum.html)：比较、别名、限制与使用模式。

Python 3.14 为 dataclass `field` 增加了 `doc` 等版本表面，但本章核心不依赖该新参数。对象模型、绑定、实例/类属性、default_factory 和 enum 是稳定核心；升级时仍需重跑 identity、equality、frozen 与默认值隔离测试。

## 23. 本章小结

类不是代码收纳箱，而是创建对象和定义行为合同的运行时对象。实例属性承载每个实例的状态，类属性承载真正共享的状态；绑定方法让实例自动成为第一个参数；封装通过行为维护不变量。dataclass 能生成样板，却不能替你决定运行时验证、深不可变、实体相等或序列化合同。enum 约束有限集合，却不能夺取 Java 的业务状态权威。

最可复用的规则是：**先定义身份、值和不变量，再选择普通类或 dataclass；可变默认值每实例创建，frozen 按浅层理解，实体相等必须显式决策，组合优先于错误继承。**
