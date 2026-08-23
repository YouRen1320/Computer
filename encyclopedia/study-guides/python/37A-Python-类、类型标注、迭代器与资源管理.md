# Python：类、类型标注、迭代器与资源管理

## 1. 类用来定义一类对象共同的数据和行为

```python
class WorkOrder:
    def __init__(self, order_id: str, priority: int) -> None:
        self.order_id = order_id
        self.priority = priority

    def is_critical(self) -> bool:
        return self.priority == 5
```

`WorkOrder` 是类，`WorkOrder("WO-1", 5)` 创建实例。实例把彼此相关的数据和规则放在一个有名字的边界内。

不是每组数据都必须写成类；当数据需要维护不变量、拥有行为或代表明确业务概念时，类最有价值。

## 2. `self` 表示当前实例

调用 `order.is_critical()` 时，Python 会把 `order` 作为第一个参数传给方法。`self` 不是关键字，但几乎所有 Python 代码都遵循这个名字约定。

实例属性通常在 `__init__` 中通过 `self.name = value` 建立，让对象一创建就处于完整状态。

## 3. 实例属性与类属性不要混淆

```python
class WorkOrder:
    category = "maintenance"       # 类属性，实例默认共享

    def __init__(self, tags: list[str]) -> None:
        self.tags = list(tags)      # 实例属性，每个实例一份
```

类体中定义的可变列表会被所有实例共享，通常是错误来源。每个实例自己的可变状态应在构造器中创建。

## 4. 封装的核心是保护对象始终有效

Python 没有 Java 那样严格的 `private` 访问控制，但可通过清晰 API 和命名约定保护边界：

```python
class WorkOrder:
    def __init__(self, priority: int) -> None:
        if priority not in range(1, 6):
            raise ValueError("priority must be between 1 and 5")
        self._priority = priority
```

前导下划线表示“这是内部实现，请通过公开方法使用”。真正目标不是藏字段，而是让非法状态难以出现。

## 5. 属性可以把读取方式和内部表示分开

```python
class WorkOrder:
    @property
    def critical(self) -> bool:
        return self._priority == 5
```

调用者使用 `order.critical`，对象仍能在内部计算结果。不要给每个字段机械地写 getter/setter；只有需要维护规则或稳定接口时才使用属性。

## 6. 三种方法的归属不同

- 实例方法接收 `self`，处理某个实例。
- 类方法用 `@classmethod` 接收 `cls`，常用于替代构造器。
- 静态方法用 `@staticmethod`，只是放在类命名空间中的普通函数。

如果函数既不需要实例也不属于这个概念，模块级函数往往更清楚，不必硬塞进类。

## 7. 组合通常比继承更灵活

```python
class AssignmentService:
    def __init__(self, repository: "OrderRepository") -> None:
        self.repository = repository
```

这里服务“拥有并使用”仓库，属于组合。继承适合真正的“是一种”关系，并且子类能遵守父类全部合同。

为了复用几行代码就继承，容易让无关概念绑定在一起。优先提取协作者或普通函数。

## 8. `super()` 按方法解析顺序继续寻找实现

Python 支持多继承，方法查找遵循 MRO（Method Resolution Order，方法解析顺序）。`super()` 不是简单等于“调用直接父类”，而是沿当前 MRO 的下一个实现继续。

多继承需要参与类都遵守协作式调用约定。业务模型一般保持简单继承层次，复杂能力用组合表达。

## 9. `dataclass` 适合字段为主的数据对象

```python
from dataclasses import dataclass

@dataclass(frozen=True, slots=True)
class WorkOrderSummary:
    order_id: str
    priority: int
```

`dataclass` 根据字段生成构造器、显示文本和相等比较等样板。它没有自动完成业务校验，也不代表对象只是“无脑数据袋”。

## 10. 可变默认字段要用 `default_factory`

```python
from dataclasses import dataclass, field

@dataclass
class WorkOrderDraft:
    tags: list[str] = field(default_factory=list)
```

工厂会为每个实例创建新列表，避免实例间共享。`field(default_factory=...)` 同样适用于字典、集合和需要动态计算的默认值。

## 11. `__post_init__` 可以维护构造后的不变量

```python
@dataclass(frozen=True)
class Priority:
    value: int

    def __post_init__(self) -> None:
        if not 1 <= self.value <= 5:
            raise ValueError("priority must be between 1 and 5")
```

所有创建路径都经过这一规则。若输入需要大量解析和错误收集，先在边界模型中校验，再构造领域对象会更清楚。

## 12. `frozen=True` 是浅层禁止重新赋值

冻结数据类不能把字段重新绑定，但字段内部若是可变列表，列表内容仍可能改变。因此不可变设计应同时选择不可变字段类型，例如 tuple 或自定义不可变值对象。

`slots=True` 可限制任意新增属性并减少部分内存开销，但是否使用应由模型规模与兼容需求决定。

## 13. 相等、身份和哈希要符合业务语义

数据类默认按字段比较相等。领域实体往往以稳定 ID 表示身份，值对象则按全部组成值相等。

可哈希对象才能作为字典键或集合成员。对象参与哈希后，如果影响相等性的字段还能改变，集合可能无法再正确找到它。因此可哈希值通常应不可变。

## 14. `enum` 表示有限且有名字的取值集合

```python
from enum import Enum

class WorkOrderStatus(str, Enum):
    CREATED = "CREATED"
    ASSIGNED = "ASSIGNED"
    CLOSED = "CLOSED"
```

它比散落的字符串更集中，也能减少拼写错误。但 enum 只描述合法标签，不会自动限制状态转换。`CREATED → CLOSED` 是否允许仍由领域规则决定。

## 15. 类型标注是一份给人和工具看的静态合同

```python
def assign(order_id: str, technician_id: int) -> bool:
    ...
```

类型检查器在运行前分析调用是否一致，IDE 可据此补全和重构。Python 运行时通常不会自动按这些标注验证参数。

因此需要同时区分：静态类型检查、运行时 Schema 校验、业务规则校验。

## 16. 联合类型表示多个明确候选

```python
def find_order(order_id: str) -> WorkOrder | None:
    ...
```

返回值可能是 `WorkOrder` 或 `None`。调用者必须先判断，类型检查器才能把后续类型缩窄为 `WorkOrder`。

`T | None` 只表示允许没有值；它不表示允许空字符串、零或任意缺失字段。

## 17. 容器标注应写出元素类型

```python
order_ids: list[str]
orders_by_id: dict[str, WorkOrder]
coordinate: tuple[float, float]
events: tuple[DomainEvent, ...]
```

`tuple[float, float]` 表示固定两个元素，`tuple[DomainEvent, ...]` 表示任意数量同类型元素。只写裸 `list` 会丢掉最重要的元素合同。

## 18. 类型别名给复杂形状起业务名字

```python
type TenantId = str
type OrderIndex = dict[TenantId, dict[str, WorkOrder]]
```

别名提升可读性，但通常不会在运行时创建新的严格类型，也不会校验外部数据。如果两个字符串不能混用，需要值对象或更强的新类型方案。

## 19. 泛型保留输入和输出之间的类型关系

```python
from typing import TypeVar

T = TypeVar("T")

def first(items: list[T]) -> T:
    return items[0]
```

传入 `list[str]` 时返回 `str`，传入 `list[WorkOrder]` 时返回 `WorkOrder`。如果写成 `object` 或 `Any`，这种关系就丢失了。

项目若支持较早 Python，可使用 `TypeVar` 的兼容写法；具体语法应服从项目声明的最低 Python 版本。

## 20. `Callable` 描述可以被调用的对象

```python
from collections.abc import Callable

Notifier = Callable[[str, int], None]
```

它适合简单回调。若协作者有多个方法、属性或逐步演进的合同，使用 `Protocol` 会更清楚。

## 21. `Protocol` 描述“只要有这些能力就可以”

```python
from typing import Protocol

class OrderRepository(Protocol):
    def find_by_id(self, order_id: str) -> WorkOrder | None: ...
    def save(self, order: WorkOrder) -> None: ...
```

实现类不必显式继承该 Protocol；只要静态可见的结构兼容即可。这叫结构类型，也可以理解为经过类型检查器描述的 duck typing。

## 22. 端口应由使用者真正需要的能力定义

如果分派用例只需要 `find_by_id` 和 `save`，就不应依赖一个包含二十个方法的万能仓库。小接口更容易提供内存 Fake，也能减少基础设施细节向业务层泄漏。

`@runtime_checkable` 只能做有限的成员存在检查，不能替代完整签名检查和输入校验。

## 23. `Any` 应被限制在很小的边界

第三方库缺标注时可能暂时出现 `Any`。可靠做法是立刻在适配器内验证和转换，再向系统内部返回明确类型。

如果让 `Any` 穿过多层，类型检查器会对错误属性和错误调用保持沉默，形成假安全感。

## 24. 可迭代对象和迭代器不是同一个概念

可迭代对象能通过 `iter(value)` 取得迭代器；迭代器通过 `next()` 每次给出一个值，耗尽时抛出 `StopIteration`。

列表通常可以反复遍历。迭代器通常是一次性游标，消费后不会自动回到开头。

```python
iterator = iter(["WO-1", "WO-2"])
print(next(iterator))
print(next(iterator))
```

## 25. 生成器用 `yield` 保存暂停位置

```python
def critical_orders(orders):
    for order in orders:
        if order.priority == 5:
            yield order
```

调用函数得到生成器对象，不会立即把所有结果放进内存。每次请求下一个值时，函数从上次 `yield` 后继续。

这叫惰性计算：只在需要时计算，也意味着错误可能到迭代时才出现。

## 26. 惰性序列只能消费一次时要明确所有者

```python
stream = critical_orders(orders)
print(list(stream))
print(list(stream))  # 通常已经为空
```

调试时调用 `list(stream)` 也会把数据吃完。若多个消费者都需要完整数据，就在明确边界物化一次并共享不可变结果，或让每个消费者获得自己的新迭代器。

## 27. 生成器持有资源时必须管理生命周期

```python
def read_lines(path):
    with path.open(encoding="utf-8") as file:
        for line in file:
            yield line
```

生成器暂停时文件仍可能打开。如果调用者提前停止，资源何时关闭取决于生成器所有权。更明确的方案是让调用者持有 `with`，或返回不跨越资源边界的已解析批次。

不要依赖垃圾回收“迟早会关”。

## 28. 装饰器在定义时包装函数

```python
from functools import wraps

def logged(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        print(f"start {func.__name__}")
        return func(*args, **kwargs)
    return wrapper
```

`@logged` 相当于把原函数替换为 `logged(original)` 的结果。`wraps` 保留名称、文档和部分类型工具所需的元数据。

装饰器适合统一的横切行为，如计时和遥测；不适合隐藏复杂业务依赖。

## 29. 同步装饰器不能正确观察异步完成

调用 `async def` 得到的是协程对象，真正工作在 `await` 时发生。若同步 wrapper 只记录函数调用前后，它记录的只是“创建协程”的时间。

异步函数需要 `async def wrapper` 并 `await func(...)`，还要保留异常与取消语义。装饰器应分别处理同步和异步合同。

## 30. 异常表示正常返回合同无法完成

```python
def parse_priority(raw: str) -> int:
    try:
        value = int(raw)
    except ValueError as error:
        raise ValueError("priority must be an integer") from error
    if not 1 <= value <= 5:
        raise ValueError("priority must be between 1 and 5")
    return value
```

异常不是所有失败的唯一表达。可预期业务拒绝有时适合明确结果类型；编程错误、损坏数据和无法继续的外部失败通常适合异常。

## 31. `try` 区域越小，捕获含义越准确

```python
try:
    quantity = int(raw_quantity)
except ValueError:
    ...
else:
    total = calculate_total(quantity)
finally:
    release_resource()
```

- `except` 处理匹配异常。
- `else` 只在没有异常时执行。
- `finally` 无论成功、失败还是提前返回都执行，适合清理。

不要用裸 `except:` 或宽泛捕获后返回假成功，这会隐藏真正故障。

## 32. 异常链保留底层原因

```python
try:
    payload = json.loads(text)
except json.JSONDecodeError as error:
    raise SnapshotFormatError("snapshot is invalid") from error
```

上层获得符合业务边界的异常，堆栈仍保留原始原因。日志可记录关联 ID 和安全上下文，但不要把 Token、PII 或完整敏感正文放入异常消息。

## 33. `with` 把资源获得和释放绑定在一起

```python
from pathlib import Path

path = Path("orders.json")
with path.open(encoding="utf-8") as file:
    text = file.read()
```

离开代码块时会执行资源清理，即使中途抛异常。文件、锁、数据库事务和临时目录都常用上下文管理器。

谁创建资源，谁通常负责关闭；若所有权转移，接口必须明确。

## 34. 上下文管理器可以用类或 `contextlib` 编写

类实现 `__enter__` / `__exit__`，适合有状态且协议较复杂的资源。`@contextmanager` 适合简单的获取—使用—释放结构：

```python
from contextlib import contextmanager

@contextmanager
def transaction(connection):
    try:
        yield connection
        connection.commit()
    except Exception:
        connection.rollback()
        raise
```

`__exit__` 返回真会吞掉异常，除非这是明确合同，否则不要这样做。

## 35. `ExitStack` 管理数量动态的多个资源

当运行时才知道要打开几个文件或注册多少清理回调时，`ExitStack` 能按相反顺序统一释放。它比手写许多嵌套 `with` 或分散的 `try/finally` 更容易保证失败路径完整。

## 36. 文件路径不只是字符串

`pathlib.Path` 提供路径拼接、检查和读写方法。相对路径依赖当前工作目录，同一程序从 IDE、终端和服务启动器运行时可能不同。

配置中要明确路径相对谁解析。处理用户给出的路径时，应防止越过允许根目录和符号链接绕过，这是安全边界。

## 37. 文本、字节和编码是三个相关概念

`str` 是 Unicode 文本，`bytes` 是原始字节。读写文本文件应显式给出编码：

```python
text = path.read_text(encoding="utf-8")
path.write_text(text, encoding="utf-8")
```

解码错误说明字节与预期编码不一致。用忽略错误的方式继续可能静默破坏数据，除非业务明确允许，否则应失败并保留证据。

## 38. JSON 是交换格式，不是 Python 对象快照

JSON 只有对象、数组、字符串、数字、布尔和 null 等有限类型。`datetime`、enum、自定义类和精确 Decimal 需要明确转换合同。

外部 JSON 先做运行时结构校验，再构造领域对象。字段缺失、额外字段和版本变化都要有策略。

## 39. 时间数据先区分“时刻”和“墙上时间”

事件发生时刻适合保存带时区的 UTC 时间，再按用户时区显示。预约“当地每天 9 点”属于墙上时间规则，还涉及夏令时和地区时区。

不要混用无时区 `datetime` 和有时区 `datetime`。业务测试可注入时钟，避免代码到处直接读取当前时间。

## 40. 这一阶段应形成的整体地图

```text
类/数据类保护业务不变量
  → enum 表示有限标签
  → 类型标注和 Protocol 描述静态合同
  → 泛型保留类型关系
  → 迭代器/生成器控制数据何时产生
  → 异常说明无法正常返回
  → with 明确资源所有权和释放
  → Path/编码/JSON/时间处理系统边界
```

必须掌握：类属性和实例属性不同；`dataclass` 不会自动校验业务；标注不等于运行时校验；Protocol 是按能力描述边界；生成器可能一次性且持有资源；异常不能宽泛吞掉；资源必须有明确所有者；外部文件和 JSON 永远是不可信输入。

新式泛型语法、类型检查器行为和标准库细节会随支持版本变化，实际项目以 `requires-python`、锁文件和当前官方文档为准。
