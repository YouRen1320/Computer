---
schema_version: 2
edition: 2026.2-draft
id: ch.python.functions-scope
title: 函数、参数、返回值与作用域
responsibility: 用函数、位置/关键字参数、默认值、返回和 LEGB 作用域封装单一规则，不引入装饰器、生成器或类。
volume: '12'
order: 4
level: L1
status: drafting
path: book/volume-12-python-data/chapters/ch.python.functions-scope.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.control-flow
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
  text: 在 120 秒内解释“函数、参数、返回值与作用域”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - python-function-contract
  - python-scope
  covers_topics:
  - python.def-call
  - python.positional-keyword-parameter
  - python.default-variadic-parameter
  - python.return
  - python.callable-value
  - python.legb-scope
  - python.local-global-nonlocal
  - python.mutable-default-risk
  - python.pure-function-boundary
  uses_capabilities: []
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“函数、参数、返回值与作用域”构建可运行程序与测试：把工单统计脚本拆为具有明确参数、返回和无共享默认状态的函数；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - python-function-contract
  - python-scope
  covers_topics:
  - python.def-call
  - python.positional-keyword-parameter
  - python.default-variadic-parameter
  - python.return
  - python.callable-value
  - python.legb-scope
  - python.local-global-nonlocal
  - python.mutable-default-risk
  - python.pure-function-boundary
  uses_capabilities: []
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: input-output-table-scope-trace-assert-script
- id: diagnose
  kind: fault-diagnosis
  text: 面对“遗漏 return、关键字参数漂移或可变默认值跨调用污染”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - python-function-contract
  - python-scope
  covers_topics:
  - python.def-call
  - python.positional-keyword-parameter
  - python.default-variadic-parameter
  - python.return
  - python.callable-value
  - python.legb-scope
  - python.local-global-nonlocal
  - python.mutable-default-risk
  - python.pure-function-boundary
  uses_capabilities: []
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 函数、参数、返回值与作用域

> 函数把一段流程变成有名字、可调用、可验证的规则。初学者最容易把函数理解成“少复制几行代码的工具”，但工程中的核心价值其实是建立边界：调用者提供哪些输入，函数保证什么结果，哪些名称只在内部存在，哪些副作用会影响外部。本章只讨论函数本身，不提前引入类、装饰器或生成器。

## 1. 为什么需要函数

假设脚本要计算两个工单的材料总价：

```python
first_total = 1999 * 3
if first_total < 0:
    first_total = 0

second_total = 2500 * 2
if second_total < 0:
    second_total = 0
```

这段代码能运行，却把同一规则复制了两次。未来增加“数量不能为负数”时，开发者可能只修改其中一处。函数让规则只有一个维护点：

```python
def calculate_total(unit_price_cents, quantity):
    if unit_price_cents < 0 or quantity < 0:
        raise ValueError("价格和数量不能为负数")
    return unit_price_cents * quantity


first_total = calculate_total(1999, 3)
second_total = calculate_total(2500, 2)
```

此时应把函数看成一个小合同：两个输入必须满足非负约束；成功时返回整数金额；失败时抛出明确异常。函数名、参数名、返回与失败行为共同构成合同。仅仅“把代码包进 `def`”并不自动产生好边界。

### 1.1 适合提取函数的信号

- 同一规则出现两次以上；
- 一段代码可以用一句业务语言命名；
- 需要针对某个规则单独测试边界；
- 主流程被实现细节淹没；
- 某段计算希望不依赖输入输出、网络或全局变量；
- 修改一个要求时，很难判断要改哪些位置。

不要为了“每三行一个函数”机械拆分。函数应表达完整的小职责，而不是把阅读者迫使在许多无意义名称之间跳转。

## 2. `def` 定义函数，圆括号调用函数

```python
def priority_label(priority):
    if priority >= 4:
        return "URGENT"
    return "NORMAL"


label = priority_label(5)
print(label)
```

解释器执行到 `def` 时会创建函数对象，再把名称 `priority_label` 绑定到它。定义函数并不会立即执行函数体。执行 `priority_label(5)` 才发生调用：实参 `5` 绑定到形参 `priority`，函数体在新的局部作用域中执行，`return` 把结果交回调用点。

可以用一个调用帧表预测：

| 时刻 | 调用者中的名称 | 本次调用局部名称 | 下一步 |
| --- | --- | --- | --- |
| 定义后 | `priority_label -> 函数对象` | 尚不存在 | 继续顶层代码 |
| 调用开始 | 同上 | `priority -> 5` | 判断 `5 >= 4` |
| return | 等待结果 | 即将结束 | 返回 `"URGENT"` |
| 赋值后 | `label -> "URGENT"` | 调用帧已释放 | 执行 print |

函数每调用一次，通常会建立一次新的局部执行环境。因此递交不同实参不会自动互相污染。污染往往来自外部可变状态或可变默认值，后文会专门处理。

### 2.1 函数名也有命名规则

Python 函数通常使用小写下划线风格：`calculate_total`、`count_active_orders`。动词开头更容易说明行为。`handle_data`、`process`、`do_it` 过于宽泛；如果无法给函数起清楚的名字，往往说明职责还没有想清楚。

### 2.2 文档字符串说明合同

函数体第一条字符串可以成为文档字符串：

```python
def calculate_total(unit_price_cents, quantity):
    """返回非负单价与数量相乘得到的分币金额。"""
    if unit_price_cents < 0 or quantity < 0:
        raise ValueError("价格和数量不能为负数")
    return unit_price_cents * quantity
```

注释不应逐字翻译代码。好的文档字符串补充单位、允许范围、返回含义和特殊失败。函数名中的 `cents` 和文档中的“分币”可以防止调用者误传“元”。

## 3. 形参与实参不是同一个概念

定义中出现的是参数（也叫形参）：

```python
def assign_order(order_id, technician_id):
    return f"{order_id}->{technician_id}"
```

调用时传入的是实参：

```python
assignment = assign_order("WO-001", 42)
```

`order_id`、`technician_id` 描述函数期待的槽位；`"WO-001"`、`42` 是这次调用交给槽位的对象。区分二者后，错误消息中的“missing required positional argument”和“unexpected keyword argument”会更容易理解。

### 3.1 位置实参

```python
assign_order("WO-001", 42)
```

按定义顺序绑定：第一个值给 `order_id`，第二个值给 `technician_id`。位置方式短，但两个同类型值很容易传反。例如 `move_order(source_id, target_id)` 若只看到两个数字，调用点含义不够直观。

### 3.2 关键字实参

```python
assign_order(order_id="WO-001", technician_id=42)
```

关键字直接写出目标参数名，可读性更高，也能改变不同关键字之间的书写顺序：

```python
assign_order(technician_id=42, order_id="WO-001")
```

一旦开始传关键字，后面不能再跟普通位置实参。下面是语法错误：

```python
# assign_order(order_id="WO-001", 42)
```

同一个参数也不能同时通过位置和关键字传两次：

```python
# assign_order("WO-001", order_id="WO-002", technician_id=42)
```

错误发生在函数体执行之前，因为解释器无法建立唯一参数绑定。

## 4. 默认参数表示“省略时使用什么”

```python
def format_order(order_id, prefix="工单"):
    return f"{prefix}:{order_id}"


print(format_order("WO-001"))
print(format_order("WO-001", "紧急工单"))
print(format_order("WO-001", prefix="紧急工单"))
```

`prefix` 有默认值，调用者可以省略。必填参数通常放在有默认值的参数之前。默认值适合真正稳定、语义明确的默认行为；若省略代表多个不同业务状态，就应显式传入或重新设计合同。

### 4.1 默认值在定义时求值

关键规则：默认值表达式不是每次调用时重新计算，而是在执行函数定义时计算一次。不可变默认值通常安全：

```python
def retry_limit(limit=3):
    return limit
```

但可变对象会被所有省略该参数的调用共享：

```python
def append_event_bad(event, events=[]):
    events.append(event)
    return events


print(append_event_bad("created"))
print(append_event_bad("assigned"))
```

第二次结果包含第一次的事件，不是因为局部变量“泄漏”，而是两个调用都使用定义时创建的同一个列表对象。

正确的常见写法是用 `None` 表示“调用时创建”：

```python
def append_event(event, events=None):
    if events is None:
        events = []
    events.append(event)
    return events
```

现在省略 `events` 的每次调用都会创建新列表；显式传入列表时，函数仍会修改那个传入对象。是否允许修改调用者的列表必须写进合同，不能靠读者猜。

### 4.2 “默认参数可选”不等于“值可以是 None”

`prefix="工单"` 表示调用时可省略；它并不自动表示 `prefix=None` 合法。省略参数和传入 `None` 是两种不同输入。后续类型章节会用联合类型表达允许的值，但运行时规则仍需分支或验证实现。

## 5. 用 `/` 和 `*`约束调用方式

Python 可以显式区分三类参数：仅位置、位置或关键字、仅关键字。

```python
def calculate_fee(quantity, /, unit_price_cents, *, discount_cents=0):
    return quantity * unit_price_cents - discount_cents
```

- `/` 之前的 `quantity` 只能按位置传；
- `unit_price_cents` 可按位置或关键字传；
- `*` 之后的 `discount_cents` 只能按关键字传。

有效调用：

```python
calculate_fee(3, 1999, discount_cents=100)
calculate_fee(3, unit_price_cents=1999, discount_cents=100)
```

无效调用包括 `calculate_fee(quantity=3, unit_price_cents=1999)` 和把折扣作为第三个普通位置实参。仅关键字参数特别适合布尔开关、单位相近的数字和未来可能扩展的选项，因为调用点会显示意图：

```python
def list_orders(status, *, include_disabled=False):
    ...
```

`list_orders("OPEN", True)` 很难读；`include_disabled=True` 明确得多。不要为了炫技给每个函数都加 `/` 和 `*`，应依据 API 可读性与兼容性选择。

## 6. 可变数量参数：`*args` 与 `**kwargs`

当参数数量确实可变时，可以收集额外实参：

```python
def total_costs(*costs):
    total = 0
    for cost in costs:
        total += cost
    return total


print(total_costs(100, 200, 300))
```

`costs` 在函数内部是 tuple。名字 `args` 只是惯例，不是关键字；业务代码优先使用有意义的复数名。关键字实参可收集为 dict：

```python
def build_summary(**fields):
    return fields


summary = build_summary(status="IN_PROGRESS", priority=4)
```

`**kwargs` 很灵活，也会隐藏合同。如果函数实际只允许三个固定字段，应显式声明三个参数，让拼写错误尽早失败。可变参数适合转发接口、日志辅助函数等开放集合，不应成为逃避设计的通用办法。

调用时，`*` 和 `**` 还能拆开已有集合：

```python
parts = (3, 1999)
options = {"discount_cents": 100}
amount = calculate_fee(*parts, **options)
```

拆包前要确保元素顺序和键名符合目标函数合同。来自网络的 dict 不能未经校验就直接 `**payload`，否则多余键、缺失键或恶意字段都会跨越边界。

## 7. `return` 决定调用表达式的值

### 7.1 显式返回

```python
def is_urgent(priority):
    return priority >= 4
```

`return` 会立即结束本次函数调用，后续语句不再执行。可以用提前返回减少嵌套：

```python
def normalize_priority(priority):
    if priority < 1 or priority > 5:
        return None
    return priority
```

调用者必须处理 `None`：

```python
normalized = normalize_priority(8)
if normalized is None:
    print("非法优先级")
else:
    print(normalized)
```

### 7.2 没写 return 就返回 None

```python
def print_order(order_id):
    print(order_id)


result = print_order("WO-001")
print(result)  # None
```

函数打印了内容，不等于返回了字符串。遗漏 `return` 是常见错误：终端看见输出便误以为调用者拿到了结果。测试应断言返回值，而不是只目测标准输出。

裸 `return` 也返回 `None`：

```python
def stop_if_closed(status):
    if status == "CLOSED":
        return
    print("继续处理")
```

### 7.3 返回多个值实际是 tuple

```python
def count_orders(statuses):
    total = len(statuses)
    active = 0
    for status in statuses:
        if status != "CLOSED":
            active += 1
    return total, active


total, active = count_orders(["CREATED", "CLOSED"])
```

`return total, active` 构造 tuple，调用点再解包。两个返回项尚可清楚；很多同类型值挤在 tuple 中很容易传错。后续学到 dataclass 后，可用有字段名的结果对象表达复杂结果。

## 8. Python 传递的是对象引用的绑定

“按值传递”或“按引用传递”这两个口号单独使用都容易误导。更准确的模型是：调用时，形参名称绑定到实参所引用的对象。

### 8.1 重新绑定不影响调用者名称

```python
def replace_status(status):
    status = "CLOSED"
    return status


original = "CREATED"
new_status = replace_status(original)
print(original)    # CREATED
print(new_status)  # CLOSED
```

函数内把局部名称 `status` 重新绑定到另一个字符串，不会让调用者名称 `original` 改绑。

### 8.2 修改共享可变对象会被外部观察

```python
def add_tag(tags):
    tags.append("urgent")


order_tags = ["device"]
add_tag(order_tags)
print(order_tags)  # ['device', 'urgent']
```

形参 `tags` 与外部 `order_tags` 起初引用同一个列表。`append` 修改对象本身，所以外部能看到变化。若函数合同承诺不修改输入，可以复制后处理：

```python
def with_urgent_tag(tags):
    result = list(tags)
    result.append("urgent")
    return result
```

这只是浅复制；若内部还嵌套可变对象，内层引用仍可能共享。集合章节会系统解释身份、浅复制和嵌套结构。

## 9. 函数本身也是值

定义函数会产生可调用对象，因此可以赋给另一个名称：

```python
def urgent(priority):
    return priority >= 4


predicate = urgent
print(predicate(5))
print(callable(predicate))
```

`urgent` 表示函数对象，`urgent(5)` 表示调用结果。漏写括号会把函数对象传下去：

```python
result = urgent       # 不是 bool
checked = urgent(5)   # 才是 bool
```

函数也可以作为参数传入：

```python
def count_matching(values, predicate):
    count = 0
    for value in values:
        if predicate(value):
            count += 1
    return count


urgent_count = count_matching([1, 4, 5], urgent)
```

这里不用提前学习 lambda。关键是理解 `predicate` 的合同：它必须可调用，接收一个值，并返回适合条件判断的结果。静态类型章节会让这个合同更可见。

## 10. LEGB：名称从哪里查找

函数体看到一个名称时，Python 按作用域规则解析。教学中常用 LEGB 记忆：

1. Local：当前函数局部；
2. Enclosing：外层函数的局部；
3. Global：当前模块全局；
4. Builtins：内置名称，如 `len`、`print`。

```python
label = "GLOBAL"


def outer():
    label = "ENCLOSING"

    def inner():
        label = "LOCAL"
        return label

    return inner()


print(outer())  # LOCAL
```

当前局部找到名称后就不会继续向外查找。删除 `inner` 里的绑定，返回外层的 `ENCLOSING`；再删除外层绑定，返回模块的 `GLOBAL`。

### 10.1 内置名称也能被遮蔽

```python
list = [1, 2, 3]
# list("abc") 现在会失败，因为 list 名称绑定到一个列表对象
```

不要把变量命名为 `list`、`dict`、`str`、`id`、`input` 等常用内置名称。遮蔽不是语法错误，但会制造难诊断的运行时错误。

### 10.2 赋值让名称成为局部

```python
count = 10


def broken_increment():
    count = count + 1
    return count
```

该函数会出现 `UnboundLocalError`。因为函数体对 `count` 有赋值，编译阶段便把它判为局部名称；右侧读取发生在局部赋值之前。不是“Python 没看到全局 count”，而是局部绑定规则优先。

更好的设计通常是显式输入输出：

```python
def increment(count):
    return count + 1


count = increment(count)
```

数据流清楚、可测试，也避免共享状态。

## 11. `global` 与 `nonlocal`

### 11.1 global 修改模块名称绑定

```python
completed_count = 0


def mark_completed():
    global completed_count
    completed_count += 1
```

`global` 声明函数中的赋值针对模块级名称。它能工作，但让函数结果依赖调用历史，测试之间也容易互相影响。在业务计算中优先传入状态并返回新值。模块级常量可读取，但不要把它当隐式可写数据库。

### 11.2 nonlocal 修改外层函数名称绑定

```python
def make_counter():
    count = 0

    def increment():
        nonlocal count
        count += 1
        return count

    return increment


counter = make_counter()
print(counter())  # 1
print(counter())  # 2
```

`nonlocal` 指向最近的外层函数绑定，不会指向模块全局。这个例子用于理解 Enclosing 作用域，不表示所有计数都该用闭包。带隐藏历史的函数更难复现；如果状态是重要业务事实，应由 Java 领域逻辑和持久化负责，而不是藏在 Python 进程的闭包中。

## 12. 纯函数与副作用边界

纯函数可用一个实用定义理解：相同输入得到相同返回，并且不修改外部可观察状态。

```python
def calculate_sla_minutes(priority):
    if priority >= 4:
        return 30
    return 120
```

它容易测试：给出输入表，断言返回。下面的函数包含副作用：

```python
def announce_sla(priority):
    minutes = calculate_sla_minutes(priority)
    print(f"SLA={minutes}")
```

副作用不是错误。读取文件、写日志、调用网络、更新数据库都必然影响外部。好的设计是把计算与副作用分开，让核心规则保持可预测，让边缘函数负责 I/O。这样测试计算不需要伪造网络，测试 I/O 时也能明确观察点。

### 12.1 FactoryCare 的权限边界

在 FactoryCare 中，Python 可以计算可重建的派生数据，例如根据已有工单生成风险分数或候选摘要；它不能把核心工单状态直接改为 `CLOSED`，也不能成为公开 API 的事实所有者。Java 负责权限、状态转换和核心业务事实。这个边界不是靠函数名保证，而要靠进程、API、凭据、数据库权限和测试共同实施。

一个合适的 Python 函数可能是：

```python
def derive_priority_hint(priority, overdue_minutes):
    score = priority * 10 + max(overdue_minutes, 0)
    if score >= 70:
        return "REVIEW_SOON"
    return "NORMAL_REVIEW"
```

返回值只是建议，不是状态迁移命令。调用者还需验证输入并由 Java 决定是否以及如何使用建议。

## 13. 函数合同要包含什么

写函数前至少回答：

- 名称表达哪一个职责？
- 每个参数的含义、单位与允许范围是什么？
- 位置还是关键字调用更清楚？
- 省略参数与显式传 None 是否不同？
- 成功返回什么？有没有可能隐式返回 None？
- 非法输入是返回哨兵、抛异常还是忽略？
- 是否修改传入的可变对象？
- 是否读取或修改全局状态？
- 是否打印、写文件、访问网络或数据库？
- 哪些边界样例能够证明合同？

例如“统计活跃工单”不能只写 `count(orders)`。应明确“活跃”的状态集合、缺失字段如何处理、是否保持输入不变、返回是否永远非负。业务定义必须来自 Java 事实模型或经确认的合同，而不是 Python 自己发明另一套状态。

## 14. 测试输入、边界与重复调用

函数测试至少覆盖：

```text
成功：1999, 3 -> 5997
边界：1999, 0 -> 0
失败：-1, 3 -> ValueError
重复：省略可变参数调用两次，结果不共享
调用方式：关键字参数按合同绑定
副作用：输入列表身份与内容是否保持
```

使用标准库断言即可建立最小 oracle：

```python
assert calculate_total(1999, 3) == 5997
assert calculate_total(unit_price_cents=1999, quantity=0) == 0
```

失败分支不能只写“应该报错”然后目测。应捕获指定异常，并在没有异常时主动失败：

```python
try:
    calculate_total(-1, 3)
except ValueError as error:
    assert "不能为负数" in str(error)
else:
    raise AssertionError("负数输入必须失败")
```

测试错误类型过宽也会掩盖问题。若写 `except Exception`，名称拼写错误等意外故障也可能被误当成预期失败。

## 15. 三类高频故障如何诊断

### 15.1 遗漏 return

现象：打印看起来正确，但断言显示 `expected 5997, got None`。第一可信位置通常是断言失败与被测函数的返回路径。检查每条分支是否显式返回，而不是给测试改成期待 None。

```python
def bad_total(price, quantity):
    total = price * quantity
    print(total)
```

修复后同时断言返回与不必要输出，防止只补 `return` 却保留污染调用者的打印。

### 15.2 关键字参数漂移

现象：重命名参数后，旧调用出现 `unexpected keyword argument`。这表明参数名是关键字调用者可见的 API。先定位函数签名与调用点，决定是否统一迁移；不要用无限制 `**kwargs` 吞掉拼写错误。

### 15.3 可变默认值污染

现象：单独运行测试通过，连续运行或顺序改变后失败。打印 `id(events)` 或连续调用结果可以证明多个调用共享对象。修复为 None 哨兵后必须重复调用，验证返回列表对象身份不同。

## 16. 阅读调用栈与错误阶段

函数相关错误可分三阶段：

1. 解析/编译：缩进、冒号、参数顺序等语法错误，函数不会运行；
2. 参数绑定：缺少必填参数、重复参数、意外关键字，函数体尚未开始；
3. 函数执行：名称未定义、类型运算错误、断言或主动异常，调用栈会指向执行行。

诊断时从 traceback 最后一个属于自己代码的帧开始，读文件、行号、异常类型和消息，再向上看调用来源。不要只盯最后的“失败”两个字，也不要一看到 `TypeError` 就假设是业务类型；参数绑定错误同样使用 `TypeError`。

## 17. 从 TypeScript/Vue 迁移过来的对照

- Python `def` 与 JS/TS 函数都创建可调用值，但 Python 依靠缩进界定函数体；
- Python 关键字实参是语言级参数绑定，不等同于 JS 传对象；
- Python 没写 return 与 JS 一样会得到空值，但 Python 是 `None`，JS 是 `undefined`；
- Python 默认值在定义时求值，可变对象共享风险比 JS 常见的调用时默认表达式更需要警惕；
- Python LEGB 与 JavaScript 词法作用域相似，但 `global`、`nonlocal` 和局部赋值判定有自己的规则；
- Python 类型标注默认不由运行时强制，不能把 TypeScript 编译检查经验直接等同于输入校验。

对照用于建立桥梁，不表示两种语言语义完全相同。最终判断应以 Python 代码实验和官方语言参考为准。

## 18. 一套可重复的学习实验

1. 预测 `calculate_total(1999, 3)` 的参数绑定和返回；
2. 删掉 `return`，先预测断言结果，再运行；
3. 使用位置和关键字两种方式调用同一函数；
4. 给一个参数改名，观察旧关键字调用在哪个阶段失败；
5. 连续调用可变默认值负例两次，记录对象身份；
6. 改为 None 哨兵，验证两次返回对象不同；
7. 写一个读取全局计数的函数，再改成显式输入输出；
8. 用 120 秒讲清形参/实参、return/print、LEGB 和可变默认值；
9. 把一个 FactoryCare 派生计算写成纯函数，明确它不能修改核心状态。

运行一次成功样例不能证明掌握。必须保存预测、失败证据、修复 diff 和同一验证器的重跑结果。

## 19. 章末检查

你应能独立回答：

- `def` 执行和函数调用分别发生什么？
- 为什么打印 5997 不代表返回了 5997？
- 位置、关键字、仅位置和仅关键字参数如何区分？
- 默认列表为何跨调用共享？
- `*args` 与 `**kwargs` 在函数内部各是什么集合？
- 形参重新绑定与修改传入列表为何影响不同？
- LEGB 每个字母代表哪一层？
- `UnboundLocalError` 为什么可能在读取全局同名变量时出现？
- `global` 和 `nonlocal` 修改哪一层绑定？
- 纯函数与含副作用函数应如何组合？
- Python 派生计算为什么不能成为 FactoryCare 工单事实所有者？

若只能背语法却无法预测对象身份、返回值或故障阶段，应回到资产中的重复调用实验，而不是继续向后赶进度。

## 20. 本章边界与资料核验

本章稳定结论依据 Python 3.14 官方教程的函数定义、默认参数、关键字参数与特殊参数章节，以及语言参考中的函数定义和执行模型。2026-07-24 核对入口：

- [Python 3.14 控制流工具：定义函数与参数](https://docs.python.org/3.14/tutorial/controlflow.html)
- [Python 3.14 复合语句：函数定义](https://docs.python.org/3.14/reference/compound_stmts.html#function-definitions)
- [Python 3.14 执行模型：名称与绑定](https://docs.python.org/3.14/reference/executionmodel.html)

已在本机 CPython 3.14.3 用标准库脚本验证：位置/关键字绑定、默认值共享、None 哨兵、return、LEGB 基本轨迹和输入不变断言。未验证且不在本章承诺的内容包括第三方框架依赖注入、装饰器重写签名、生成器挂起帧、跨进程共享状态以及 Java 服务真实 API 联调。
