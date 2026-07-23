---
schema_version: 2
edition: 2026.2-draft
id: ch.python.collections
title: list、tuple、dict、set 与推导式
responsibility: 选择 list/tuple/dict/set 表达顺序、不可变记录、映射和唯一性，用切片、遍历和可读推导式转换数据，整合 Python 基础语言能力。
volume: '12'
order: 5
level: L1-L2
status: drafting
path: book/volume-12-python-data/chapters/ch.python.collections.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.functions-scope
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
  text: 在 120 秒内解释“list、tuple、dict、set 与推导式”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - python-core-collections
  - python-collection-language-synthesis
  covers_topics:
  - python.list
  - python.tuple
  - python.dict
  - python.set
  - python.hashable-key
  - python.slice
  - python.unpacking
  - python.comprehension
  - python.iteration-protocol-intro
  - python.def-call
  - python.if-elif-else
  uses_capabilities:
  - foundation.toolchain-env-build
  - python.language
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现按技师分组、去重和汇总的工单集合转换且不意外修改输入；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - python-core-collections
  - python-collection-language-synthesis
  covers_topics:
  - python.list
  - python.tuple
  - python.dict
  - python.set
  - python.hashable-key
  - python.slice
  - python.unpacking
  - python.comprehension
  - python.iteration-protocol-intro
  - python.def-call
  - python.if-elif-else
  uses_capabilities:
  - foundation.toolchain-env-build
  - python.language
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: collection-case-table-identity-check-assert-script
- id: diagnose
  kind: fault-diagnosis
  text: 面对“集合类型选错、不可哈希键、浅复制共享或过度复杂推导式”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - python-core-collections
  - python-collection-language-synthesis
  covers_topics:
  - python.list
  - python.tuple
  - python.dict
  - python.set
  - python.hashable-key
  - python.slice
  - python.unpacking
  - python.comprehension
  - python.iteration-protocol-intro
  - python.def-call
  - python.if-elif-else
  uses_capabilities:
  - foundation.toolchain-env-build
  - python.language
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# list、tuple、dict、set 与推导式

> 集合不是“把很多数据装起来”这么简单。选择集合就是选择合同：是否保留顺序、是否允许重复、通过位置还是键查找、是否允许原地修改、元素或键需要满足什么约束。本章从零建立四种核心集合的模型，再用遍历、切片、解包和推导式完成 FactoryCare 派生数据转换。

## 1. 先按问题选择集合

遇到多个值时，先问四个问题：

1. 顺序是否有业务意义？
2. 重复值是否有意义？
3. 是按位置读取，还是按唯一键查找？
4. 创建后是否允许原地修改？

| 类型 | 核心含义 | 顺序 | 重复 | 常见读取 | 是否可变 |
| --- | --- | --- | --- | --- | --- |
| `list` | 有序序列 | 保留 | 允许 | 整数索引/遍历 | 是 |
| `tuple` | 固定序列记录 | 保留 | 允许 | 整数索引/解包 | 否 |
| `dict` | 键到值的映射 | 保留插入顺序 | 键唯一，值可重复 | 键 | 是 |
| `set` | 唯一成员集合 | 不承诺业务顺序 | 自动去重 | 成员测试/集合运算 | 是 |

“保留插入顺序”不等于“已经按字段排序”。`dict` 会记住键插入的先后；`set` 的显示或遍历顺序不能成为业务输出合同。若结果必须按创建时间排列，应显式排序并测试，而不是依赖当前进程碰巧显示的顺序。

## 2. list：可变、有序、允许重复

```python
statuses = ["CREATED", "ASSIGNED", "ASSIGNED"]
print(statuses[0])
print(len(statuses))
```

索引从 0 开始，所以长度为 3 的列表有效索引是 0、1、2。访问 `statuses[3]` 会抛 `IndexError`。负索引从末尾计数：`statuses[-1]` 是最后一个元素，`statuses[-2]` 是倒数第二个。

### 2.1 原地修改

```python
statuses.append("IN_PROGRESS")
statuses[0] = "TRIAGED"
```

`append` 修改现有列表并返回 `None`。常见错误：

```python
statuses = statuses.append("CLOSED")
```

执行后 `statuses` 变为 `None`，因为把 `append` 的返回重新绑定给名称。大多数原地修改集合的方法返回 `None`，这是 Python 用来提醒“动作”和“新值”不同的设计。

常用动作：

```python
items = ["A", "B"]
items.append("C")             # 单个元素
items.extend(["D", "E"])    # 逐个追加可迭代对象中的元素
items.insert(1, "X")         # 在索引 1 前插入
last = items.pop()            # 删除并返回最后一个
items.remove("X")            # 删除第一个相等元素
```

`append(["D", "E"])` 会追加一个嵌套列表；`extend(["D", "E"])` 会追加两个字符串。`remove` 找不到值时抛 `ValueError`；`pop` 对空列表会抛 `IndexError`。选择方法前先写出期望形状。

### 2.2 名称别名与对象身份

```python
original = ["WO-001"]
alias = original
alias.append("WO-002")
print(original)
```

赋值没有复制列表，两个名称引用同一对象。可以用 `alias is original` 验证身份，用 `alias == original` 比较内容。`is` 与 `==` 回答不同问题：前者是否同一个对象，后者内容是否相等。

复制顶层列表：

```python
copy_a = original.copy()
copy_b = original[:]
copy_c = list(original)
```

三种方式都创建新的外层列表。但若元素本身是 dict/list，复制仍共享内层对象：

```python
orders = [{"id": "WO-001", "tags": ["device"]}]
copied = orders.copy()
copied[0]["tags"].append("urgent")
print(orders[0]["tags"])  # 也包含 urgent
```

这叫浅复制。是否需要深复制应根据所有权合同决定；不应看到嵌套结构就无条件深复制，因为成本和对象语义都会改变。更稳妥的做法常是创建明确的新记录和新内层集合。

## 3. 切片：半开区间产生新序列

形式 `sequence[start:stop:step]` 中，start 包含，stop 不包含：

```python
ids = ["WO-001", "WO-002", "WO-003", "WO-004"]
print(ids[1:3])   # WO-002, WO-003
print(ids[:2])    # 前两个
print(ids[2:])    # 从索引 2 到末尾
print(ids[::2])   # 每隔一个
print(ids[::-1])  # 反向副本
```

半开区间的长度容易计算：在步长为 1 且边界有效时，长度是 `stop - start`。切片超出边界通常会截断，不像单个索引那样抛错：

```python
print(ids[0:100])
```

这在分页预览中方便，也可能隐藏边界计算错误。若“必须正好取到 20 条”，还要断言结果长度。

列表切片返回新列表，修改新列表的顶层结构不改变原列表；但它仍是浅复制。切片也可用于字符串和 tuple，因为它们都是序列。

### 3.1 切片赋值

列表支持用切片修改一段：

```python
values = [1, 2, 3, 4]
values[1:3] = [20, 30, 40]
```

结果长度可以变化。这个能力很强，但业务代码中可能降低可读性；若目标是生成派生结果，优先返回新列表而不是在多个位置原地改写。

## 4. tuple：有序且不可原地修改

```python
point = ("WO-001", "IN_PROGRESS")
order_id, status = point
```

tuple 保留顺序，允许重复，但不支持元素赋值或 append。不可变的是 tuple 的槽位：若某个槽位引用列表，列表本身仍可变。

```python
record = ("WO-001", ["device"])
record[1].append("urgent")  # 合法：修改内部列表
```

因此“tuple 就是深度不可变”是错误结论。

### 4.1 单元素 tuple 必须有逗号

```python
not_tuple = ("WO-001")
one_item_tuple = ("WO-001",)
```

真正构造 tuple 的关键是逗号，括号主要用于分组。`type(not_tuple)` 是 str，`type(one_item_tuple)` 才是 tuple。

### 4.2 tuple 适合什么

- 函数返回少量固定位置结果；
- 字典键中的复合身份，例如 `(tenant_id, external_id)`；
- 表示不应改变长度和槽位的短记录；
- 解包赋值与交换。

字段很多、同类型值很多时，位置含义难读。后续的 dataclass 更适合有名称的业务记录。

## 5. 解包让结构与名称对应

```python
order_id, status = ("WO-001", "ASSIGNED")
```

左右元素数量必须匹配，否则抛 `ValueError`。星号目标收集剩余元素为 list：

```python
first, *middle, last = [1, 2, 3, 4, 5]
print(first)   # 1
print(middle)  # [2, 3, 4]
print(last)    # 5
```

循环中可直接解包：

```python
pairs = [("WO-001", "CREATED"), ("WO-002", "CLOSED")]
for order_id, status in pairs:
    print(order_id, status)
```

交换名称无需临时变量：

```python
left, right = right, left
```

右侧先形成值序列，再完成左侧绑定，不是逐行覆盖。

## 6. dict：唯一键到值的映射

```python
order = {
    "id": "WO-001",
    "status": "IN_PROGRESS",
    "priority": 4,
}
```

通过键读取：

```python
print(order["status"])
```

不存在的键使用下标会抛 `KeyError`。如果缺失是合法状态，可使用 `get`：

```python
assignee_id = order.get("assignee_id")
label = order.get("label", "未命名")
```

但 `get` 也有信息压缩风险：键不存在与键存在但值为 None 都可能得到 None。若业务必须区分，应先用 `"assignee_id" in order` 判断。

### 6.1 写入、覆盖和删除

```python
order["assignee_id"] = 42
order["status"] = "RESOLVED"
del order["priority"]
```

同一键再次赋值会覆盖旧值，不会出现两个相同键。字典字面量中重复键也只保留后者，因此配置重复可能静默丢失前值。

`pop` 删除并返回：

```python
removed = order.pop("assignee_id", None)
```

是否允许原地改变传入 dict 必须由函数合同明确。对派生计算，通常创建新 dict 更容易验证输入未变：

```python
def with_hint(order, hint):
    result = dict(order)
    result["priority_hint"] = hint
    return result
```

这仍是浅复制。

### 6.2 遍历字典

```python
for key in order:
    print(key)

for value in order.values():
    print(value)

for key, value in order.items():
    print(key, value)
```

直接遍历 dict 得到键。需要键值对时使用 `items()`，并在循环头解包。不要在遍历同一个字典时改变其大小，这通常会触发 `RuntimeError`。可先遍历 `list(order)` 快照，或构建新字典。

### 6.3 合并与更新

```python
base = {"status": "CREATED", "priority": 2}
patch = {"priority": 4, "assignee_id": 42}
merged = base | patch
```

右侧同名键覆盖左侧，`base` 不变。`base.update(patch)` 则原地修改 base。合并外部 payload 前必须先验证允许字段；不能让客户端通过多传 `status` 绕过 Java 状态机。

## 7. 字典键必须可哈希

字典和 set 依赖哈希表。键必须在作为键期间具有稳定的哈希与相等语义。常见可哈希对象包括 int、str、bytes，以及元素都可哈希的 tuple。list、dict、set 可变，因此不能直接作为 dict 键或 set 元素：

```python
# invalid = {["tenant-a", "WO-001"]: "CREATED"}
valid = {("tenant-a", "WO-001"): "CREATED"}
```

失败会显示 `TypeError: unhashable type: 'list'`。不要通过把对象转成字符串来草率绕过；字符串拼接可能碰撞或丢失结构。复合键应使用明确的不可变 tuple，或重新建模。

“不可变”与“可哈希”高度相关但不是完全同义。tuple 只有在所有元素可哈希时才可哈希：

```python
hash(("tenant-a", "WO-001"))  # 可行
# hash(("tenant-a", ["WO-001"]))  # 内含 list，失败
```

## 8. set：唯一成员和集合关系

```python
statuses = {"CREATED", "ASSIGNED", "ASSIGNED"}
print(len(statuses))  # 2
```

set 自动去重，适合成员测试、去重和集合运算。空 set 必须写 `set()`；`{}` 是空 dict。

```python
active = {"CREATED", "ASSIGNED", "IN_PROGRESS"}
current = "ASSIGNED"
if current in active:
    print("活跃")
```

常用运算：

```python
left = {"A", "B"}
right = {"B", "C"}

print(left | right)  # 并集
print(left & right)  # 交集
print(left - right)  # 差集
print(left ^ right)  # 对称差
print({"A"} <= left)  # 子集
```

set 不应直接用来保存“第一条、第二条”的业务顺序。若既要去重又要保留首次出现顺序，可以用 dict 键：

```python
unique_in_order = list(dict.fromkeys(["B", "A", "B", "C"]))
```

或者显式维护 `seen` set 与 `result` list，这样意图更清楚且便于附加转换。

`frozenset` 是不可变集合，可作为 dict 键或另一个 set 的成员。只有当“无序成员组合”本身就是身份时才使用它；大多数业务记录仍需有字段含义。

## 9. 成员测试的语义取决于集合

```python
"WO-001" in ["WO-001", "WO-002"]
"WO-001" in {"WO-001", "WO-002"}
"status" in {"status": "CREATED"}
```

对 list/tuple，`in` 比较元素；对 set，判断成员；对 dict，默认判断键而不是值。要判断字典值需写 `value in mapping.values()`，但如果频繁反向查找，说明数据结构可能选错。

从复杂度心智模型看，list 成员测试通常线性扫描，dict/set 平均可借助哈希快速定位。但“大 O”不是无条件性能承诺：哈希计算、碰撞、对象大小和内存都会影响实际结果。先选择正确语义，再用真实数据分析热点。

## 10. 迭代协议初识

`for` 能遍历 list、tuple、dict、set，是因为它们可迭代。可以手工观察：

```python
values = ["A", "B"]
iterator = iter(values)
print(next(iterator))
print(next(iterator))
```

再次 `next` 会抛 `StopIteration`，表示耗尽。`for` 会在内部处理结束信号：

```python
iterator = iter(values)
while True:
    try:
        value = next(iterator)
    except StopIteration:
        break
    print(value)
```

这段仅用于建立模型，日常遍历应使用 for。可迭代对象负责产生迭代器；迭代器还记录当前位置，通常是一次性消费。这里不讨论如何用生成器创建迭代器，那是后续章节职责。

### 10.1 遍历时修改集合

对列表边遍历边删除会跳过元素：

```python
values = [1, 2, 2, 3]
for value in values:
    if value == 2:
        values.remove(value)
```

删除会移动后续索引，而迭代器继续前进。更安全的是构建新列表：

```python
kept = [value for value in values if value != 2]
```

若确需原地更新，先明确迭代快照和修改目标，不要依赖偶然结果。

## 11. 推导式：从可迭代输入构建新集合

### 11.1 list 推导式

```python
priorities = [1, 4, 5, 2]
urgent = [priority for priority in priorities if priority >= 4]
```

阅读顺序：遍历 priorities 中每个 priority；只保留满足条件者；把左侧表达式结果放入新列表。它等价于清楚的循环：

```python
urgent = []
for priority in priorities:
    if priority >= 4:
        urgent.append(priority)
```

推导式不是“更高级所以一定更好”。当转换包含多层条件、错误处理、多个副作用或复杂状态时，普通循环更可读、也更便于调试。

### 11.2 set 与 dict 推导式

```python
unique_statuses = {order["status"] for order in orders}
status_by_id = {order["id"]: order["status"] for order in orders}
```

dict 推导式若生成重复键，后出现的值覆盖前值。若重复 ID 应视为数据错误，就必须先检测，而不是让推导式静默决定胜者。

### 11.3 推导式的名称作用域

Python 3 中，推导式的循环变量不会泄漏到外层：

```python
status = "OUTER"
labels = [status.lower() for status in ["A", "B"]]
print(status)  # OUTER
```

但推导式仍可读取外部名称。若表达式依赖会变化的外部可变状态，理解成本会上升；优先显式传参给函数。

### 11.4 不在推导式中堆副作用

```python
# 不推荐：仅为了打印而创建无用列表
unused = [print(order) for order in orders]
```

结果会是一串 None。打印、写文件、发送请求等副作用使用普通循环。推导式的清晰合同是“从输入构建一个新集合”。

## 12. 排序不是集合类型自动提供的业务保证

```python
orders = [
    {"id": "WO-002", "priority": 2},
    {"id": "WO-001", "priority": 5},
]

ordered = sorted(
    orders,
    key=lambda order: (-order["priority"], order["id"]),
)
```

此例只展示现有内置排序接口；lambda 会在后续函数主题扩展。`sorted` 返回新 list，原输入不变；`list.sort()` 原地排序并返回 None。稳定、可复现的排序应提供完整决胜键。只按 priority 排序时，同优先级顺序仍依赖输入顺序；如果跨系统需要一致结果，还要增加 ID 等二级键。

不要对 set 直接声称有顺序。要输出稳定文本时先 `sorted(statuses)`。测试集合语义时可直接比较 set；测试输出语义时比较排序后的 list。

## 13. FactoryCare：按技师分组而不修改输入

输入是 Java 服务授权后提供的工单快照；Python 只计算可重建汇总：

```python
def summarize_by_technician(orders):
    result = {}

    for order in orders:
        technician_id = order.get("technician_id")
        if technician_id is None:
            continue

        if technician_id not in result:
            result[technician_id] = {
                "order_ids": [],
                "statuses": set(),
                "total": 0,
            }

        bucket = result[technician_id]
        bucket["order_ids"].append(order["id"])
        bucket["statuses"].add(order["status"])
        bucket["total"] += 1

    return result
```

结构选择有理由：

- 外层 dict 用 technician_id 快速定位分组；
- order_ids 是 list，因为输出顺序和重复异常都值得观察；
- statuses 是 set，因为只关心唯一状态；
- total 是数值累计；
- 只读取 order，不给输入 dict 新增字段。

若要序列化为 JSON，set 不是 JSON 类型，应在边界转换为排序 list：

```python
def to_serializable(summary):
    result = {}
    for technician_id, bucket in summary.items():
        result[str(technician_id)] = {
            "order_ids": list(bucket["order_ids"]),
            "statuses": sorted(bucket["statuses"]),
            "total": bucket["total"],
        }
    return result
```

Python 不能把汇总反写为核心工单事实。Java 仍拥有工单状态、授权与公开 API；这里的 result 可以随时从源数据重建。

## 14. 输入不变性如何验证

只比较输入前后 `==` 能证明内容相等，但还需根据合同检查身份与嵌套对象：

```python
orders = [{"id": "WO-001", "technician_id": 7, "status": "ASSIGNED"}]
before = [dict(order) for order in orders]

summary = summarize_by_technician(orders)

assert orders == before
assert summary[7]["order_ids"] == ["WO-001"]
assert summary[7]["statuses"] == {"ASSIGNED"}
```

若输入含嵌套列表，`dict(order)` 仍是浅复制。测试可以为关键内层字段另建快照，或构造不可变 fixture。不要为了写测试随意 `deepcopy` 所有对象，然后误以为生产函数所有权已经清楚。

边界表至少包括：空输入、单条未指派、单个技师多条、多个技师、重复状态、缺失必需键和输入嵌套对象。缺失 `id` 是失败还是跳过，必须由合同决定并写入断言。

## 15. 四类典型故障

### 15.1 集合类型选错

用 set 保存工单时间线会丢重复并丢失业务顺序；用 list 模拟按 ID 查找会导致每次线性扫描；用 dict 保存允许重复的事件会发生覆盖。修复前先回到“顺序、重复、查找、可变性”四问，而不是只换语法。

### 15.2 不可哈希键

日志：`TypeError: unhashable type: 'list'`。第一可信位置是把 list 放进 dict 键或 set 的那一行。判断这个键本应是有序复合身份（tuple）还是无序成员组合（frozenset），不能仅为消除错误随便 stringify。

### 15.3 浅复制共享

现象：修改派生结果的内层 tags，原输入也变。用 `is` 比较内层对象身份，画出两个外层 dict 指向同一内层 list。修复可以显式复制内层集合或构建新记录；修复后既断言内容，也断言关键对象不是同一个。

### 15.4 过度复杂推导式

当一行同时包含两层循环、多个条件、条件表达式与多次索引时，即使正确也难预测。把它展开为循环，给中间概念命名，并针对失败分支写断言。代码行数增加不等于质量下降；可验证性比炫技短代码重要。

## 16. 运行时错误与逻辑错误要分开

- `IndexError`：序列索引越界；
- `KeyError`：dict 下标键不存在；
- `TypeError: unhashable type`：哈希集合收到不合格对象；
- `ValueError`：remove 找不到值、解包数量不匹配等；
- `RuntimeError`：遍历 dict/set 时改变大小等；
- 无异常但顺序错、重复丢失、输入被修改：逻辑合同错误。

“没有 traceback”不代表集合转换正确。对结果形状、顺序、唯一性、身份和输入不变性建立 oracle，才能捕获静默逻辑错误。

## 17. 从 JavaScript/TypeScript 对照理解

- Python list 类似 JS Array，但 list 推导式与切片是 Python 独有常用表达；
- Python dict 是通用哈希映射并保留插入顺序，不应简单等同普通 JS object；
- Python set 与 JS Set 都表达唯一成员，但 API 和相等/哈希模型不同；
- Python tuple 是内置运行时对象，TypeScript tuple 主要是静态类型形状；
- Python `in` 对 dict 查键，而 JS `in` 涉及对象属性链，不能直接类比；
- Python 原地集合方法常返回 None，JS 某些方法会返回长度或数组，迁移时尤其要检查。

对照只能帮助入门。对象身份、可哈希规则、切片与迭代行为都应通过 Python 实验确认。

## 18. 独立练习路线

1. 为“时间线、唯一角色集合、ID 查状态、固定坐标”各选一种集合并说明理由；
2. 预测 append 与 extend 后的形状，再运行；
3. 写出 `values[1:4]` 的索引集合，验证 stop 不包含；
4. 建立浅复制负例，用 `is` 证明内层共享；
5. 用 tuple 和 frozenset 分别尝试作为 dict 键，解释差异；
6. 把过度复杂推导式展开为普通循环；
7. 实现按技师分组、状态去重和稳定序列化；
8. 证明函数没有修改输入；
9. 注入 list 作为 dict 键，记录异常类型和首个自己代码位置；
10. 用 120 秒讲清四种集合合同和一个选错类型的反例。

每个实验都先预测结果或失败阶段。只有亲手制造并修复别名、不可哈希键和顺序错误，才能在 AI 生成嵌套转换时完成审查。

## 19. 章末检查

你应能回答：

- list、tuple、dict、set 分别保留什么、禁止什么？
- 为什么 `items = items.append(x)` 会让名称变成 None？
- `is` 与 `==` 的问题有什么不同？
- 浅复制为何不能隔离嵌套列表？
- 切片为何采用左闭右开？越界切片与越界索引有什么不同？
- 单元素 tuple 为什么需要逗号？
- dict 的 `[]`、`get` 与 `in` 如何选择？
- 为什么 list 不能作为 dict 键？
- set 为什么不能承载时间线顺序？
- `iter`、`next` 和 `StopIteration` 如何解释 for？
- 推导式何时清楚，何时应展开？
- 怎样证明 FactoryCare 派生汇总没有修改输入？

## 20. 本章边界与资料核验

本章稳定结论依据 Python 3.14 官方教程的数据结构章节，以及标准类型与数据模型参考。2026-07-24 核对入口：

- [Python 3.14 教程：数据结构](https://docs.python.org/3.14/tutorial/datastructures.html)
- [Python 3.14 标准类型](https://docs.python.org/3.14/library/stdtypes.html)
- [Python 3.14 数据模型](https://docs.python.org/3.14/reference/datamodel.html)

已在本机 CPython 3.14.3 用标准库脚本验证：四类集合基本行为、切片、解包、哈希失败、迭代耗尽、分组转换、稳定序列化和输入不变性。未验证范围包括不同 Python 实现的内部哈希表布局、超大数据性能、并发修改、第三方持久集合、真实 Java API 返回数据与数据库查询计划。本章不把平均复杂度模型当作任何生产延迟承诺。
