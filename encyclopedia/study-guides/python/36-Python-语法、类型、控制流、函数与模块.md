# Python：语法、类型、控制流、函数与模块

## 1. Python 程序本质上是在依次执行语句

Python 解释器读取源码后，会先检查语法，再执行能够到达的语句。最简单的程序只有一条语句：

```python
print("FactoryCare ready")
```

交互式解释器适合快速观察一个表达式，`.py` 文件适合保存可重复运行的程序。真正项目应以模块方式运行，并固定解释器和依赖环境。

## 2. 缩进是程序结构的一部分

Java 用大括号表示代码块，Python 主要用缩进：

```python
if machine_stopped:
    print("critical")
    notify_manager()

print("finished")
```

前两条缩进语句属于 `if`，最后一条不属于。建议统一使用四个空格，不混用 Tab 和空格。

## 3. 表达式产生值，语句执行动作

`2 * 3`、`name.upper()`、`priority == 5` 都是表达式，会产生一个值。赋值、`if`、`for`、`return` 和 `import` 是语句，负责改变程序流程或名称绑定。

理解这一区别有助于读代码：先找表达式会得到什么，再看语句如何使用这个值。

## 4. Python 变量更准确地说是“名称绑定”

```python
first_label = "ready"
second_label = first_label
second_label = "done"
```

名称 `first_label` 和 `second_label` 起初指向同一个字符串对象；最后一行只是让 `second_label` 改为指向另一个对象，因此 `first_label` 仍是 `"ready"`。

这与“把一个盒子里的内容复制进另一个盒子”并不完全相同，遇到可变对象时差别尤其明显。

## 5. 对象有类型，名称本身不锁死类型

```python
value = 3
value = "three"
```

两行都能运行，因为 Python 在运行时检查对象类型。`3` 是 `int`，`"three"` 是 `str`，名称 `value` 可以先后绑定不同类型的对象。

这叫动态类型。它不等于“没有类型”，而是类型检查主要发生在运行时。

## 6. 常见基础类型各有明确用途

- `int`：任意精度整数，适合数量和以分为单位的金额。
- `float`：二进制浮点数，适合允许近似的测量值，不适合直接表示精确货币。
- `bool`：`True` 或 `False`。
- `str`：Unicode 文本。
- `None`：明确表示“没有值”或“尚未得到结果”。

`None`、空字符串、数字 `0` 是三种不同的业务状态，不要随意混用。

## 7. `==` 比较值，`is` 比较是否为同一个对象

```python
left = [1, 2]
right = [1, 2]

print(left == right)  # True
print(left is right)  # False
```

通常用 `==` 比较内容。`is` 最常见且可靠的用途是判断单例：

```python
if result is None:
    ...
```

不要用 `is` 比较普通数字或字符串的值；解释器内部复用对象的细节不是业务合同。

## 8. 输入得到的永远是字符串

```python
raw_quantity = input("quantity: ")
quantity = int(raw_quantity)
```

`input()` 不会猜测用户想输入数字。`int()` 转换失败会抛出 `ValueError`，这属于运行阶段失败。空行是 `""`，输入结束则可能抛出 `EOFError`。

因此边界处理顺序通常是：读取文本、清理空白、检查是否缺失、转换、检查业务范围。

## 9. 正常输出和诊断输出应分开

```python
import sys

print("totalCents=5997")
print("invalid quantity", file=sys.stderr)
```

正常结果写到 stdout，错误和诊断写到 stderr。命令行工具还能通过退出码告诉调用者成功或失败。文字看起来正确并不等于退出状态正确，两者都是接口的一部分。

## 10. f-string 用来把值放进清晰的文本模板

```python
order_id = "WO-1001"
priority = 5
message = f"order={order_id} priority={priority}"
```

f-string 适合用户输出和短小调试信息。生产日志更适合使用结构化字段，让日志系统能按 `order_id`、`tenant_id` 等字段查询。

## 11. 类型转换可能失败，也可能丢信息

```python
int("1999")      # 1999
float("2.5")     # 2.5
int(2.9)          # 2，直接截去小数部分
str(1999)         # "1999"
```

转换不是校验的替代品。`int(2.9)` 能执行，但如果业务要求拒绝小数，这就是错误做法。应先写清输入合同，再决定允许哪些转换。

## 12. 条件判断使用布尔值和 truthiness

以下值在条件中通常被当作假：`False`、`None`、数值零、空字符串和空集合。其他大多数对象为真。

```python
if not order_ids:
    print("no orders")
```

但 truthiness 不能代替业务判断。`if not quantity` 同时把 `0` 和 `None` 当成假，如果两者含义不同，就应该显式比较。

## 13. `and` 和 `or` 会短路，而且返回操作数

```python
if order is not None and order.priority == 5:
    ...

display_name = entered_name or "anonymous"
```

短路表示前半部分已经决定结果时，后半部分不会执行。这能保护对 `None` 的属性访问。

`and`、`or` 返回的不一定是 `bool`，而可能是某个原始操作数。业务代码若需要严格布尔值，可用 `bool(value)` 或明确比较。

## 14. `if / elif / else` 表示互斥选择

```python
if affected_users < 0:
    raise ValueError("affected_users must not be negative")
elif machine_stopped:
    priority = 5
elif affected_users >= 100:
    priority = 4
else:
    priority = 2
```

条件从上到下判断，只执行第一个命中的分支。更具体的非法情况通常先挡住，然后再处理正常业务规则。

多个互不排斥的动作可以使用多个独立 `if`，不要为了少写一个关键字而错误地改成 `elif`。

## 15. `match` 适合按数据形状或有限情况分派

```python
match status:
    case "CREATED":
        label = "待处理"
    case "ASSIGNED":
        label = "已分派"
    case _:
        label = "未知状态"
```

它叫结构化模式匹配。只处理两三个普通范围条件时，`if` 往往更直观；当输入有明确形状、多个字段需要一起匹配时，`match` 更有价值。

## 16. `for` 遍历可迭代对象，不要求手动维护下标

```python
total = 0
for amount in amounts:
    total += amount
```

每轮把下一个元素绑定到 `amount`。需要下标时使用 `enumerate`：

```python
for index, order_id in enumerate(order_ids):
    print(index, order_id)
```

这比自己维护 `i += 1` 更不容易出现边界错误。

## 17. `range` 使用左闭右开区间

`range(0, 3)` 产生 `0、1、2`，不包含 `3`。这种规则与字符串切片一致，便于表示长度为 `end - start` 的区间。

如果目的是遍历集合元素，直接 `for item in items`；如果还要下标，用 `enumerate`。不要习惯性写 `range(len(items))`。

## 18. `while` 适合重复次数事先未知的流程

```python
while True:
    line = input().strip()
    if line == "quit":
        break
    process(line)
```

它常用于读取到哨兵、重试到成功或状态机循环。循环必须有明确的状态变化和退出条件，否则可能永不结束。

## 19. `break`、`continue` 和 `return` 退出的范围不同

- `continue`：结束本轮，进入下一轮。
- `break`：结束当前循环。
- `return`：结束整个函数，并把结果交给调用者。

如果循环除了“找到一个结果”还要继续做总数、总和等统计，找到后就不能 `break`。可以只在首次命中时保存位置，然后继续扫描剩余数据。

## 20. Python 的四种常用集合解决不同问题

- `list`：有顺序、可修改、允许重复。
- `tuple`：有顺序，整体不能原地修改，适合固定结构。
- `dict`：从唯一键查找值。
- `set`：保存唯一成员，适合去重和集合关系。

选择集合先看业务语义，不要一律使用列表。

## 21. 可变对象会让“共享引用”变得可见

```python
first = ["WO-1"]
second = first
second.append("WO-2")

print(first)  # ["WO-1", "WO-2"]
```

两个名称指向同一个列表，修改对象会被两边看到。`second = first.copy()` 可得到浅复制，但嵌套对象仍可能共享。是否复制应由所有权和修改合同决定。

## 22. 推导式适合简单地构造新集合

```python
critical_ids = [order.id for order in orders if order.priority == 5]
```

它表达“遍历、筛选、转换、收集”。如果包含多层条件、异常处理或副作用，普通循环通常更清楚。不要为了短而把一整段业务流程压进一行。

## 23. 函数把一段规则变成可命名、可复用的合同

```python
def calculate_total_cents(unit_price_cents: int, quantity: int) -> int:
    return unit_price_cents * quantity
```

函数合同至少包括：输入含义、允许范围、返回含义、可能失败方式和副作用。好名字应描述业务结果，而不是实现步骤。

## 24. 形参是定义中的名称，实参是调用时给出的值

```python
calculate_total_cents(1999, 3)
calculate_total_cents(unit_price_cents=1999, quantity=3)
```

第一行传位置实参，第二行传关键字实参。关键字能提高可读性，但参数名一旦被外部广泛使用，也成为需要谨慎修改的接口。

## 25. 默认参数在函数定义时创建一次

下面是典型陷阱：

```python
def add_event(event, events=[]):
    events.append(event)
    return events
```

多次调用会共享同一个列表。可靠写法是：

```python
def add_event(event, events=None):
    if events is None:
        events = []
    events.append(event)
    return events
```

不可变默认值通常安全，可变默认值要特别小心。

## 26. `return` 决定调用表达式的值

函数没有显式 `return` 时返回 `None`。返回多个值实际上是返回一个 tuple：

```python
def summarize(amounts):
    return len(amounts), sum(amounts)

count, total = summarize([100, 200])
```

如果调用者需要稳定的多个命名字段，数据类或明确对象通常比越来越长的 tuple 更容易维护。

## 27. Python 传递的是对象引用的绑定

函数内重新绑定形参，不会改变调用者的名称；函数内修改共享可变对象，会被调用者观察到。

```python
def rename(label):
    label = "done"

def append_order(order_ids):
    order_ids.append("WO-2")
```

因此函数是否修改传入对象必须在合同中明确。纯计算函数通常返回新值，副作用函数则应让名字能看出来。

## 28. 作用域决定名称从哪里寻找

Python 常用 LEGB 顺序查找名称：当前函数局部作用域、外层函数作用域、模块全局作用域、内置名称。

函数内对一个名称赋值，通常会让它成为局部名称。`global` 和 `nonlocal` 能改变绑定位置，但会增加隐藏状态；业务代码更适合显式传参和返回结果。

## 29. 类型标注帮助工具理解合同，但不会自动校验运行时输入

```python
def find_order(order_id: str) -> dict[str, object] | None:
    ...
```

标注能被 IDE 和静态类型检查器使用，也能帮助读者理解。直接调用 `find_order(123)` 时，解释器通常不会因为标注而自动拒绝。

外部 JSON、命令行和数据库数据仍需运行时校验。

## 30. `Any` 与 `object` 的含义不同

`Any` 基本告诉类型检查器“这里不要检查”，并会把不确定性传播出去。`object` 表示值确实未知，但使用前仍必须缩窄类型。

在系统边界，优先接收 `object` 或经过 Schema 校验的模型；仅在无法描述的第三方边界局部使用 `Any`。

## 31. 模块是一个独立命名空间

一个 `.py` 文件通常对应一个模块。导入模块时，Python 会查找模块、首次执行其顶层代码、缓存模块对象，再把名称绑定到当前作用域。

```python
from factorycare.pricing import calculate_total_cents
```

导入会执行顶层代码，因此模块顶层不要建立数据库连接、发网络请求或读取不可控配置。

## 32. 包把相关模块组织成清晰的名字空间

推荐的小型项目结构：

```text
factorycare/
  pyproject.toml
  src/
    factorycare/
      __init__.py
      domain/
      application/
      adapters/
  tests/
```

`src` 布局能减少“只因为当前目录刚好在搜索路径里所以能导入”的假成功。包名、导入名和发布到包仓库的发行名不一定完全相同。

## 33. 用 `python -m` 按模块身份运行入口

```bash
python -m factorycare.cli
```

这让 Python 按包结构解析导入。直接执行包内某个文件可能改变 `sys.path` 和模块身份，从而出现 IDE 能跑、终端不能跑或相对导入失败。

```python
if __name__ == "__main__":
    main()
```

main guard 表示只有作为入口运行时才执行 `main()`，被导入时不执行。

## 34. 虚拟环境隔离项目依赖

不同项目可能需要不同版本的库。虚拟环境给项目一套独立解释器入口和依赖目录，不必把所有包装进系统 Python。

使用 uv 时，常见职责是：

```text
pyproject.toml：项目声明和直接依赖
uv.lock：解析后的精确依赖图
.venv：可删除并重建的本地环境
```

锁文件应提交仓库，`.venv` 不提交。不要通过复制虚拟环境实现部署。

## 35. `uv add`、`uv lock`、`uv sync` 和 `uv run` 各管一件事

- `uv add`：修改依赖声明并更新解析结果。
- `uv lock`：根据声明生成或更新锁。
- `uv sync`：让环境与锁文件一致。
- `uv run`：在项目环境中运行命令。

如果 `python` 和 `uv run python` 表现不同，先比较解释器路径与导入来源，而不是立即重装所有东西。

## 36. 错误要先按发生阶段分类

```text
解析/导入前：SyntaxError、IndentationError
名称解析：NameError、ModuleNotFoundError
运行操作：TypeError、ValueError、ZeroDivisionError
业务结果：程序成功退出，但数字或状态错误
```

异常堆栈从底部附近找自己代码的第一处位置，再向上理解调用路径。退出码 0 只证明进程正常结束，不能证明业务结果正确。

## 37. 这一阶段应形成的整体地图

```text
源码语句
  → 名称绑定到对象
  → 表达式产生值
  → 条件和循环控制路径
  → 函数封装规则
  → 类型标注描述静态合同
  → 模块和包组织依赖
  → 虚拟环境与锁文件固定运行条件
```

必须掌握：输入先是字符串；可变对象可能被共享修改；`if` 顺序就是规则优先级；函数要写清输入、输出和失败；标注不等于运行时校验；导入会执行顶层代码；解释器、环境和锁文件共同决定程序实际运行条件。

具体 Python、uv 和类型检查器版本属于“需要时查询”，以项目声明和当前官方文档为准。
