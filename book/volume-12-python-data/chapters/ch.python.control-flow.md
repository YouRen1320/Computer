---
schema_version: 2
edition: 2026.2-draft
id: ch.python.control-flow
title: 条件、循环与控制转移
responsibility: 用布尔条件、if/elif/else、for/while、range 和 break/continue 表达选择与重复，不使用函数或推导式隐藏控制流程。
volume: '12'
order: 3
level: L1
status: drafting
path: book/volume-12-python-data/chapters/ch.python.control-flow.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.syntax-values-io
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
  text: 在 120 秒内解释“条件、循环与控制转移”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - python-branching
  - python-loops-control
  covers_topics:
  - python.truthiness
  - python.boolean-expression
  - python.if-elif-else
  - python.match-intro
  - python.for-range
  - python.while
  - python.break-continue
  - python.loop-else
  - python.sentinel-loop
  uses_capabilities: []
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现交互式工单优先级分类和有界统计循环；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - python-branching
  - python-loops-control
  covers_topics:
  - python.truthiness
  - python.boolean-expression
  - python.if-elif-else
  - python.match-intro
  - python.for-range
  - python.while
  - python.break-continue
  - python.loop-else
  - python.sentinel-loop
  uses_capabilities: []
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: boundary-table-prediction-stdout-oracle
- id: diagnose
  kind: fault-diagnosis
  text: 面对“truthiness 误用、遗漏 elif、循环边界偏一或哨兵不终止”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - python-branching
  - python-loops-control
  covers_topics:
  - python.truthiness
  - python.boolean-expression
  - python.if-elif-else
  - python.match-intro
  - python.for-range
  - python.while
  - python.break-continue
  - python.loop-else
  - python.sentinel-loop
  uses_capabilities: []
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 条件、循环与控制转移

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《语句、变量、对象、表达式与基础输入输出》](ch.python.syntax-values-io.md)：条件和循环需要已验证的值、名称、表达式及输入转换。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 程序默认从上到下执行。条件让它在互斥路径中选择，循环让一段代码有界重复，`break`/`continue` 改变当前循环的下一步。本章故意不用函数和推导式，要求你逐轮画出名称、条件和累计结果。

## 1. 条件必须先成为可检查的问题

“如果工单紧急就升级”太模糊。先定义输入和边界：

```text
priority 是 1..5 的整数
priority >= 4 => URGENT
2 <= priority < 4 => NORMAL
priority == 1 => LOW
其他值 => INVALID
```

再写代码。若先堆 if 再猜规则，最容易遗漏 0、负数、5 以上和边界 4。

## 2. bool、比较与 truthiness

比较表达式产生 bool：

```python
priority = 4
is_urgent = priority >= 4
print(is_urgent)
```

`True` 与 `False` 是布尔对象。条件语句会对表达式做真值判断；不仅 bool 有真值。

### 2.1 常见 falsy 值

以下通常为假：

- `False`；
- `None`；
- 数值 0 / 0.0；
- 空字符串 `""`；
- 空 list/dict/set/tuple 等。

多数其他对象为真。验证：

```python
print(bool(""))
print(bool("0"))
print(bool(0))
```

结果分别 False、True、False。字符串 `"0"` 非空，因此为真。

### 2.2 truthiness 不能替代业务语义

```python
if assignee_id:
    print("已指派")
```

若合法 ID 可能为 0，这会误判。业务问题是“是否缺失”，应写：

```python
if assignee_id is not None:
    print("已指派")
```

同样，空列表可能表示“成功查询但无结果”，None 可能表示“尚未加载”。用 `if items` 会把不同状态合并。truthiness 是语言机制，是否适合由领域合同决定。

## 3. 布尔运算与短路

### 3.1 and

```python
if enabled and priority >= 4:
    print("启用且紧急")
```

先求左侧；若 falsy，右侧不求值。短路可安全保护后续访问：

```python
if assignee_id is not None and assignee_id > 0:
    print("有效指派")
```

### 3.2 or

左侧 truthy 时右侧不求值：

```python
display_name = input_name or "未命名设备"
```

但如果空字符串是合法名称，默认逻辑就错。不要把 `or` 默认值用于需要区分 0、False、空字符串与 None 的字段。

### 3.3 not

```python
if not enabled:
    print("已停用")
```

对复杂表达式优先写正向业务名称：`is_closed` 比 `not not_open` 清楚。

### 3.4 返回操作数

`and`/`or` 不保证返回 bool：

```python
print("" or "fallback")
print("ready" and 42)
```

分别得到 fallback 和 42。条件会继续按真值解释，但赋值时要知道实际类型。

### 3.5 优先级

一般 `not` 高于 `and`，`and` 高于 `or`。业务表达式加括号：

```python
if enabled and (status == "ASSIGNED" or status == "IN_PROGRESS"):
    print("活跃工单")
```

更常用成员判断：

```python
if enabled and status in {"ASSIGNED", "IN_PROGRESS"}:
    print("活跃工单")
```

集合语法下一章深入，此处先读懂。

## 4. if / elif / else

```python
priority = int(input("优先级（1-5）："))

if priority >= 4 and priority <= 5:
    label = "URGENT"
elif priority >= 2:
    label = "NORMAL"
elif priority == 1:
    label = "LOW"
else:
    label = "INVALID"

print(label)
```

解释器从上到下检查，执行第一个 truthy 分支，然后跳过其余 elif/else。分支顺序是语义。

### 4.1 更具体的非法范围应先挡住

上面代码对 6：第一条件 `>=4 and <=5` 为假，第二 `>=2` 为真，错误归 NORMAL。应先验证完整范围，或让每段边界封闭：

```python
if priority < 1 or priority > 5:
    label = "INVALID"
elif priority >= 4:
    label = "URGENT"
elif priority >= 2:
    label = "NORMAL"
else:
    label = "LOW"
```

边界表：

| 输入 | 结果 |
| ---: | --- |
| 0 | INVALID |
| 1 | LOW |
| 2 | NORMAL |
| 3 | NORMAL |
| 4 | URGENT |
| 5 | URGENT |
| 6 | INVALID |

只测 3 和 5 会漏掉错误。

### 4.2 独立 if 与 elif 链

两个独立 if 都可能执行：

```python
if priority >= 4:
    print("紧急")
if enabled:
    print("启用")
```

elif 链只选一个互斥分类。需要同时产生多个标签时用独立 if；需要唯一分类时用 elif/else。不要为了少写字把非互斥规则塞进链。

### 4.3 嵌套条件

```python
if enabled:
    if priority >= 4:
        print("需立即处理")
```

可改为 `if enabled and priority >= 4`。嵌套适合内层只在外层成立后有意义，或需要不同 else。超过两三层时先提炼规则/函数（下一章）。

### 4.4 条件表达式

```python
label = "启用" if enabled else "停用"
```

适合简单二选一值，不适合多步副作用和复杂嵌套。不要写难读的嵌套三元。

## 5. match 入门

Python 结构化模式匹配可按值/结构选择：

```python
status = input("状态：").strip().upper()

match status:
    case "ASSIGNED":
        message = "已指派"
    case "IN_PROGRESS":
        message = "处理中"
    case "CLOSED" | "CANCELLED":
        message = "已结束"
    case _:
        message = "未知状态"

print(message)
```

`case _` 是兜底。match 不是 JavaScript switch 的简单复制，它支持模式、guard、解构；集合/类章再深化。

### 5.1 捕获模式陷阱

裸名称在 case 中通常表示捕获变量而非比较现有变量：

```python
case expected_status:
    ...
```

这可能匹配所有值并绑定名称，导致后续 case 不可达。常量值用字符串字面量、枚举限定名等。阅读语法错误/静态工具提示。

### 5.2 if 还是 match

- 范围比较（priority >= 4）：if/elif 更自然；
- 对离散状态/结构匹配：match 清楚；
- 简单两分支：if；
- 不要为“新语法”强行改写。

## 6. for：遍历 iterable

```python
for priority in [5, 2, 4]:
    print(priority)
```

for 依次从 iterable 获取元素并绑定循环变量。它不是 C 风格三段 for。这里列表只是输入，下一章系统讲集合。

### 6.1 累计器

```python
urgent_count = 0

for priority in [5, 2, 4]:
    if priority >= 4:
        urgent_count = urgent_count + 1

print(urgent_count)
```

逐轮表：

| priority | 条件 | urgent_count 后 |
| ---: | --- | ---: |
| 5 | true | 1 |
| 2 | false | 1 |
| 4 | true | 2 |

累计器必须在循环前初始化。放循环内会每轮重置。

### 6.2 循环变量在循环后仍存在

Python for 不创建块级作用域。非空循环后 `priority` 保留最后值；空循环时可能根本未绑定。不要依赖这个细节传结果，显式维护 result。

### 6.3 不要边遍历边结构性修改

遍历列表时删除元素可能跳项。先构建新集合或遍历副本，下一章练习。当前章用只读输入。

## 7. range 与边界

```python
for index in range(5):
    print(index)
```

输出 0,1,2,3,4；停止值不包含。常见形式：

```python
range(stop)
range(start, stop)
range(start, stop, step)
```

例：

```python
list(range(2, 6))       # [2, 3, 4, 5]
list(range(6, 1, -2))   # [6, 4, 2]
```

step 不能是 0。方向与 step 符号不匹配会产生空序列，不一定报错。

### 7.1 off-by-one

需求“重试最多 3 次”：

```python
for attempt in range(1, 4):
    print(attempt)
```

输出 1,2,3。`range(1, 3)` 只有 1,2。用边界表而非直觉。

### 7.2 需要索引时 enumerate

```python
for index, status in enumerate(statuses, start=1):
    print(index, status)
```

不要 `range(len(statuses))` 只为取元素；enumerate 更表达意图。若确需并行索引再使用。

## 8. while：条件为真就重复

```python
attempt = 1
while attempt <= 3:
    print(f"第 {attempt} 次")
    attempt += 1
```

设计 while 必须回答：

1. 初始条件是什么；
2. 每轮如何靠近终止；
3. 上界是多少；
4. 异常/EOF 如何退出。

遗漏 `attempt += 1` 会无限循环。开发时用外部 timeout 保护实验，不能把“手动 Ctrl+C”当设计。

### 8.1 不要用 while 重造 for

固定遍历 iterable 用 for，更不易漏更新。while 适合条件/哨兵驱动、次数未知但可终止的流程。

### 8.2 无限循环必须有显式退出

```python
while True:
    command = input("命令（quit 退出）：").strip().lower()
    if command == "quit":
        break
    print(f"收到：{command}")
```

这是哨兵循环；`quit` 不作为业务数据处理。还要考虑 EOF，否则输入结束会抛异常。本章允许观察失败，生产程序后续显式处理。

## 9. break 与 continue

### 9.1 break

立即退出最近一层循环：

```python
found = False
for status in ["ASSIGNED", "IN_PROGRESS", "CLOSED"]:
    if status == "CLOSED":
        found = True
        break
```

嵌套循环中只退出内层。需要退出多层时重构为函数/明确状态，而不是堆标志。

### 9.2 continue

跳过本轮剩余语句，进入下一轮：

```python
active_count = 0
for status in statuses:
    if status in {"CLOSED", "CANCELLED"}:
        continue
    active_count += 1
```

while 中 continue 前尤其要确保更新变量，否则跳过 `attempt += 1` 造成无限循环。

### 9.3 清晰优先

continue 可减少嵌套，合理；但一轮多个 continue/break 会让路径难追踪。用输入输出表覆盖每条控制转移。

## 10. 循环 else

for/while 的 else 在循环自然结束（没有 break）时执行，不是“循环体一次没执行才执行”。

```python
target = "CLOSED"

for status in statuses:
    if status == target:
        print("找到了")
        break
else:
    print("未找到")
```

若找到并 break，else 跳过；遍历完未找到，else 执行。空集合也自然结束，所以执行 else。

这个语法适合搜索/验证，不熟悉的团队也可用 found flag。选择可读性并测试 break/无 break/空输入。

## 11. 哨兵输入循环

FactoryCare 统计多个优先级，输入 `q` 结束：

```python
urgent_count = 0
valid_count = 0

while True:
    raw = input("优先级 1-5（q 结束）：").strip().lower()

    if raw == "q":
        break

    priority = int(raw)
    if priority < 1 or priority > 5:
        print("INVALID")
        continue

    valid_count += 1
    if priority >= 4:
        urgent_count += 1

print(f"有效 {valid_count}，紧急 {urgent_count}")
```

当前 `int(raw)` 对非 q 非数字抛 ValueError；异常章前先作为失败 fixture。不要用 `raw.isdigit()` 就断言所有整数格式正确（负号、Unicode 数字等语义复杂）；后续用显式解析/异常。

### 11.1 哨兵不计入数据

先检查 q，再转换和累计。若先 `valid_count += 1`，结束标志会被错误计数。

### 11.2 空输入

空字符串 int 转换失败。产品决定是提示重试、视为结束还是非法；不能让语言 truthiness 悄悄替你决定。

### 11.3 EOF

测试 fixture 没有 q 且用尽输入会 EOFError。若协议要求 EOF 也结束，需要异常处理（后续）；当前 fixture 必须包含哨兵或预期失败。

## 12. 嵌套循环与复杂度直觉

```python
for technician in technicians:
    for order in orders:
        print(technician, order)
```

若各 N/M 项，循环体执行 N×M。小例子无感，生产数据会慢。下一章用 dict/set 建索引降低查找，但先能数出执行次数。

不要在循环里重复网络/数据库查询形成 N+1；批量接口和数据层负责。当前 Python AI 服务也不应逐工单回调 Java API 数千次。

## 13. 状态机思维

复杂流程不要只看代码行，列状态与事件：

```text
READING --输入q--> DONE
READING --合法1..5--> COUNTED -> READING
READING --越界--> REJECTED -> READING
READING --非数字--> ERROR（当前版本）
```

每条转移对应 fixture。这样能发现“INVALID 后是否 continue”“q 是否计数”“EOF 怎么办”。状态机不是只有框架才用，if/while 已经在实现它。

## 14. 常见故障

### 14.1 边界顺序错误

```python
if priority >= 2:
    label = "NORMAL"
elif priority >= 4:
    label = "URGENT"
```

4 先命中 >=2，URGENT 永不可达。首个证据是边界表 4/5 实际 NORMAL。修复把更具体/更高阈值放前或封闭范围。

### 14.2 把字符串 "0" 当假

`if raw:` 对 "0" 为真。若要数值比较先解析；若要检查缺失明确 `raw == ""`。

### 14.3 range 少一次

`range(1, 3)` 不含 3。列实际序列、对照需求的次数，不要只改 +1 后不测空/负方向。

### 14.4 while 不终止

更新变量只写在某分支，另一分支 continue 永不更新。首个证据是同一输入/状态重复日志；用外部 timeout 终止测试。修复确保每个非 break 路径推进，或用 for。

### 14.5 循环内重置累计器

```python
for priority in priorities:
    urgent_count = 0
```

结果只反映最后一轮。轨迹显示每轮回到 0。初始化放循环前。

### 14.6 `else` 误解

以为循环至少执行一次就不走 else。实际只要没 break，自然结束就走。测试找到、未找到、空输入三类。

## 15. 可测试的边界矩阵

分类器至少：

```text
-1, 0, 1, 2, 3, 4, 5, 6
```

循环至少：

- 空输入（若以固定列表测试）；
- 一项低优先级；
- 一项紧急；
- 多项混合；
- 第一个就是哨兵；
- 多项后哨兵；
- 非数字；
- fixture 无哨兵 EOF；
- timeout 保护下的故障版无限循环。

预期红不是坏事：非法/EOF 故障用例应以明确非零和异常结束。成功用例才要求 0。

## 16. FactoryCare 实验

实现一个不使用函数/推导式的脚本：

1. 循环读 `priority,status`；
2. `q` 结束；
3. priority 只允许 1..5；
4. status 只允许 `ASSIGNED/IN_PROGRESS/CLOSED/CANCELLED`；
5. `priority>=4` 且状态活跃，urgent_active +1；
6. CLOSED/CANCELLED 计 ended；
7. 越界输出 INVALID 并 continue；
8. 最后输出 total/urgent_active/ended。

先写 8 行以上的输入—状态—累计器表，再编码。用 subprocess stdin fixture 验证 stdout 和退出码。为故障版删除一个 continue 或改 range 边界，记录差异再恢复。

### 16.1 证据格式

```text
case: mixed-until-q
stdin: fixture path + digest
expected stdout: ...
actual stdout: ...
expected exit: 0
actual exit: 0
result: pass
```

失败记录第一处差异，而不是只写“逻辑不对”。

## 17. 自测与参考答案

1. **`bool("0")`？** True，因为字符串非空。
2. **为什么 `if assignee_id` 可能错？** 合法 0 会被当假；缺失应 `is None` 判断。
3. **elif 链会执行几个分支？** 最多一个，第一个为真者。
4. **两个独立 if 呢？** 可都执行。
5. **range(1,4)？** 1、2、3，不含 4。
6. **while 必须说明什么？** 初始条件、推进、终止、上界和异常路径。
7. **continue 在 while 的风险？** 跳过推进语句导致无限循环。
8. **循环 else 何时执行？** 循环自然结束且未 break；空循环也执行。
9. **break 退出几层？** 最近一层循环。
10. **本章越界反例？** 用函数、生成器或推导式隐藏循环；后续章节再重构。

## 18. 章节验收清单

- [ ] 能区分 bool 与 truthiness，列出常见 falsy 值。
- [ ] 能判断业务何时不能用模糊 truthiness。
- [ ] 能解释 and/or 短路和返回操作数。
- [ ] 能用 if/elif/else 实现无遗漏边界分类。
- [ ] 能选择 if 范围与 match 离散模式。
- [ ] 能逐轮追踪 for 累计器。
- [ ] 能正确生成 range 边界并使用 enumerate。
- [ ] 能设计有推进和终止证明的 while/哨兵循环。
- [ ] 能使用 break/continue/loop else 并预测路径。
- [ ] 能用空/一/多/非法/哨兵/EOF fixture 验证。

### 18.1 用循环不变量检查累计逻辑

循环不变量是在每轮开始或结束都必须成立的关系。紧急工单统计中，可以写成：`0 <= urgent_count <= valid_count <= 已处理的合法输入数`。在任何一轮出现 urgent_count 大于 valid_count，就说明某条路径重复累计或忘记更新分母。哨兵结束前后，已处理业务数据数量不应变化；非法输入经过 continue 后，合法计数也不应变化。学习时在每轮输出轮次、原始输入、分支和三个计数，与预先写的轨迹表比较；理解后删掉调试输出，保留自动断言。

终止证明也可以写成不变量配合变元：固定次数循环的“剩余轮数”每轮减少且不能小于零；while 重试的 `attempt` 每个非退出路径都增加，最大值有限；哨兵循环本身依赖外部输入，自动测试必须提供哨兵或用超时设置外部上界。仅仅说“用户总会输入 q”不是可靠终止保证，生产交互还需要 EOF、取消或最大输入数量策略。这样的证明比肉眼看循环更容易发现隐藏的 `continue` 路径。

### 18.2 分支覆盖不等于规则正确

测试执行过每一行，只能说明代码路径被触达，不能说明边界期望正确。例如把紧急阈值错写成 `> 4`，用 5 仍能覆盖紧急分支，却漏掉边界 4。因此先由业务表推导用例，再用覆盖率找未执行路径；不能从覆盖率反推需求。对每个比较符至少测试阈值前、阈值、阈值后，对 elif 链再测非法范围和所有分支。出现失败时先修实现或澄清合同，禁止把 expected 改成错误 actual 只为变绿。

## 19. 官方资料与更新检查

- Control flow tutorial：<https://docs.python.org/3.14/tutorial/controlflow.html>
- Truth value testing：<https://docs.python.org/3.14/library/stdtypes.html#truth-value-testing>
- Boolean operations：<https://docs.python.org/3.14/reference/expressions.html#boolean-operations>
- Compound statements：<https://docs.python.org/3.14/reference/compound_stmts.html>
- `range`：<https://docs.python.org/3.14/library/stdtypes.html#range>

资料核对日期：2026-07-24。match 的模式能力会扩展，但分支互斥、短路、半开区间、循环不变量/终止和边界矩阵是稳定核心。
