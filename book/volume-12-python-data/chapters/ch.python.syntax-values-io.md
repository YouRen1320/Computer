---
schema_version: 2
edition: 2026.2-draft
id: ch.python.syntax-values-io
title: 语句、变量、对象、表达式与基础输入输出
responsibility: 教会读者按缩进读取 Python 语句，用名称绑定、基础对象、表达式、print/input 和类型观察验证程序，不提前使用条件或函数。
volume: '12'
order: 2
level: L1
status: drafting
path: book/volume-12-python-data/chapters/ch.python.syntax-values-io.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.runtime-uv
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
  text: 在 120 秒内解释“语句、变量、对象、表达式与基础输入输出”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - python-syntax-bindings
  - python-values-basic-io
  covers_topics:
  - python.indentation-suite
  - python.statement-expression
  - python.name-binding
  - python.comment-docstring-intro
  - python.int-float-bool-str-none
  - python.operator-expression
  - python.print
  - python.input
  - python.type-inspection
  uses_capabilities:
  - foundation.toolchain-env-build
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 编写只含绑定、表达式和输入输出的维修金额脚本并逐行预测状态；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - python-syntax-bindings
  - python-values-basic-io
  covers_topics:
  - python.indentation-suite
  - python.statement-expression
  - python.name-binding
  - python.comment-docstring-intro
  - python.int-float-bool-str-none
  - python.operator-expression
  - python.print
  - python.input
  - python.type-inspection
  uses_capabilities:
  - foundation.toolchain-env-build
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: prediction-stdin-stdout-fixture-exit-code
- id: diagnose
  kind: fault-diagnosis
  text: 面对“缩进、名称拼写、字符串/数字转换或 EOF 导致的解析与运行错误”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - python-syntax-bindings
  - python-values-basic-io
  covers_topics:
  - python.indentation-suite
  - python.statement-expression
  - python.name-binding
  - python.comment-docstring-intro
  - python.int-float-bool-str-none
  - python.operator-expression
  - python.print
  - python.input
  - python.type-inspection
  uses_capabilities:
  - foundation.toolchain-env-build
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 语句、变量、对象、表达式与基础输入输出

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Python 运行时、uv、虚拟环境与依赖》](ch.python.runtime-uv.md)：语法与 IO 实验必须在可复现解释器和模块入口中运行。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章把 Python 程序缩小到最基本的执行模型：解释器按顺序读取语句，表达式产生值，名称绑定到对象，`input` 从标准输入读取文本，`print` 把可观察结果写到标准输出。暂不使用 `if`、循环、函数或集合，让每一步都能手工预测。

## 1. 第一个程序不是魔法

建立 `main.py`：

```python
print("FactoryCare")
print("Python 环境已运行")
```

执行：

```bash
uv run python main.py
```

解释器从上到下执行两条表达式语句。`print` 是内置可调用对象；圆括号内是实参；字符串字面量产生 `str` 对象。标准输出应是：

```text
FactoryCare
Python 环境已运行
```

命令退出码 0 表示进程正常结束，不表示所有业务结果一定正确。后续要用预期输出和测试判定行为。

### 1.1 交互式 REPL 与脚本

直接运行 `python` 进入 REPL，适合短表达式实验；`.py` 脚本适合保存、复现和版本控制。REPL 的历史名称会留在当前进程，不应成为脚本依赖。

```text
>>> 1999 * 3
5997
```

脚本中的表达式结果默认不会自动显示，必须 `print` 或由调试器观察。不要因为 REPL 自动回显就误以为生产脚本也会输出。

## 2. 词法、语句和表达式

### 2.1 表达式产生值

```python
1999 * 3
"WO-" + "001"
```

这两段都是表达式，分别产生整数和字符串。单独放在脚本中通常计算后丢弃（模块顶层首个字符串还有文档字符串特殊语义）。

### 2.2 语句执行动作

```python
unit_price_cents = 1999
print(unit_price_cents)
```

赋值是语句，把名称绑定到表达式结果；`print(...)` 在语法分类上是表达式语句，求值时产生输出副作用。

### 2.3 一行一条更清楚

Python 可用分号把简单语句写一行，但教材和项目默认一行一条：

```python
price = 1999
quantity = 3
total = price * quantity
```

清晰的差异、堆栈行号和断点比省两行更有价值。

## 3. 缩进是语法，不是装饰

Python 用缩进表达代码 suite（块），而 Java/JavaScript 常用大括号。虽然本章不正式教条件与函数，先认识结构：

```python
if True:
    print("块内")
print("块外")
```

冒号开启 suite，下一层通常使用 4 个空格。混用 tab 和空格、层级不一致，会产生 `IndentationError`/`TabError`，发生在解析阶段，业务代码尚未运行。

错误示例：

```python
if True:
print("没有缩进")
```

日志通常指出文件、行号并显示期待缩进。首个可信位置是解析器报告的附近，但真正结构错误有时在上一行缺冒号或括号未闭合；要查看上下文。

### 3.1 括号内换行

圆/方/花括号内部可以自然换行：

```python
message = (
    "设备：一号循环泵；"
    "状态：处理中"
)
```

相邻字符串字面量会在编译时拼接。项目使用格式化工具统一风格，不用反斜杠到处续行。

## 4. 名称绑定，不是“盒子里存值”

```python
unit_price_cents = 1999
quantity = 3
total_cents = unit_price_cents * quantity
```

更准确的模型：表达式产生对象，赋值让名称指向对象。名称不是带固定类型的内存盒子。

```python
value = 1999
value = "1999"
```

运行时允许同一名称后来绑定不同类型对象，但这会降低可读性和静态检查能力。工程代码让一个名称保持稳定语义。

### 4.1 赋值顺序

右侧先求值，再绑定左侧：

```python
count = 1
count = count + 1
```

第二行右侧的 `count` 先读取旧整数 1，产生新整数 2，再把名称 `count` 绑定到 2。它不是数学等式。

### 4.2 多目标赋值

```python
unit_price_cents, quantity = 1999, 3
```

右侧先形成两个值并完成解包，再分别绑定。交换：

```python
left, right = right, left
```

不需要临时变量，因为右侧先整体求值。完整解包在集合章深化。

### 4.3 常量只是约定

```python
TAX_RATE = 0.06
```

全大写表达“不应重新绑定”的团队约定，Python 运行时并不禁止修改。真正配置来源、不可变模型和类型工具后续再讲。

### 4.4 合法命名与关键字

名称可含字母、数字、下划线，但不能数字开头，也不能使用 `class`、`if` 等关键字。工程使用 `snake_case`：

```python
work_order_code = "WO-001"
```

不要用 `list`、`str`、`type`、`input` 等内置名作为变量，否则后续调用会被遮蔽：

```python
str = "处理中"  # 不推荐：遮蔽内置 str
```

## 5. 基础对象类型

### 5.1 int

Python `int` 表示整数，精度通常不固定为 32/64 位，只受内存限制。金额推荐先用最小货币单位整数：

```python
unit_price_cents = 1999
quantity = 3
total_cents = unit_price_cents * quantity
```

结果 5997，避免二进制浮点表示货币的小数误差。跨 API/数据库仍要约定范围，不能因为 Python int 大就忽略 Java long/数据库列上限。

### 5.2 float

```python
temperature = 78.5
```

CPython float 通常是 IEEE 754 双精度二进制浮点，某些十进制小数不能精确表示：

```python
print(0.1 + 0.2)
```

常见输出接近 `0.30000000000000004`。测量值可以接受带容差比较；货币/精确十进制后续用整数或 Decimal。

### 5.3 bool

```python
enabled = True
archived = False
```

首字母大写。`bool` 在 Python 中是 `int` 的子类，`True + True` 会得到 2，但业务代码不要利用这种历史关系代替明确计数。

### 5.4 str

```python
code = "WO-001"
description = '轴承温度偏高'
```

单双引号都可，项目统一格式。字符串是 Unicode 文本；长度、索引和编码边界以后再讲。字符串不可变，拼接产生新对象。

### 5.5 None

```python
assignee_id = None
```

`None` 表示“没有值”的单例，不是空字符串、0、False 或字符串 `"None"`。比较身份通常写 `is None`/`is not None`：

```python
print(assignee_id is None)
```

本章只观察，不用条件分支。

## 6. type、id 与对象观察

```python
value = 1999
print(type(value))
print(type(value).__name__)
```

`type` 返回运行时类型。学习时可用，产品逻辑不要到处用 `type(...) == ...` 替代多态/验证。

`id(obj)` 返回对象在当前进程生命周期内的身份标识，不保证是可持久化内存地址：

```python
a = 1999
b = a
print(id(a), id(b))
```

两名称指向同一对象时 id 相同。不要依赖小整数/字符串驻留现象；相等性与身份是不同合同，后续比较章深化。

### 6.1 `==` 与 `is`

- `==` 比较值语义；
- `is` 比较是否同一对象；
- 对 None 使用 `is None`；
- 不用 `is` 比较普通数字/字符串值。

```python
print("WO" == "WO")
```

## 7. 运算符与表达式

### 7.1 算术

```python
print(7 + 2)   # 9
print(7 - 2)   # 5
print(7 * 2)   # 14
print(7 / 2)   # 3.5，真除法
print(7 // 2)  # 3，向下整除
print(7 % 2)   # 1，模
print(2 ** 3)  # 8，幂
```

负数的 `//` 是向负无穷取整，不是向零截断：`-7 // 2 == -4`。涉及分页/分桶要写边界测试。

除数 0 在运行时抛 `ZeroDivisionError`。解析成功不代表执行成功。

### 7.2 字符串运算

```python
code = "WO-" + "001"
separator = "-" * 20
```

字符串不能直接加整数：`"数量：" + 3` 会 `TypeError`。显式转换或 f-string：

```python
quantity = 3
print("数量：" + str(quantity))
print(f"数量：{quantity}")
```

### 7.3 比较

```python
print(5 > 4)
print(5 >= 5)
print(5 == 5)
print(5 != 4)
```

产生 bool。Python 支持链式比较 `0 <= quantity <= 100`，含义是 quantity 同时满足两边且只求值一次；条件章再使用。

### 7.4 布尔运算

`and`、`or`、`not` 有短路和返回操作数的语义，不总返回 bool：

```python
print("" or "默认")
```

输出 `默认`。本章只观察，条件章会解释 truthiness 与短路副作用。

### 7.5 优先级与括号

```python
total = unit_price_cents * quantity + shipping_cents
```

乘法先于加法。复杂表达式用括号表达业务意图，不靠读者背完整优先级：

```python
total = (unit_price_cents * quantity) + shipping_cents
```

## 8. 整数、浮点与转换

```python
print(int("1999"))
print(float("78.5"))
print(str(5997))
print(bool(0))
```

转换是运行操作，不是类型注解。`int("19.99")` 会 `ValueError`；应先理解输入格式，不能盲目套两次转换。

`int(3.9)` 向零截断为 3，不是四舍五入。业务舍入需明确规则。

### 8.1 不要捕获错误再静默变 0

用户输入非法金额时，静默设 0 可能生成错误订单。后续异常/验证章会让错误成为显式状态；当前实验可让进程失败并观察堆栈。

## 9. print 的合同

```python
print("工单", "WO-001", "金额", 5997)
print("A", "B", sep=" | ", end="\n")
```

`print` 默认用空格分隔实参、末尾换行。`sep`/`end` 是命名参数。它把对象转换为面向人的文本，不是稳定 API 序列化。

### 9.1 stdout 与 stderr

普通输出到 stdout，错误诊断通常到 stderr：

```python
import sys

print("result", file=sys.stdout)
print("diagnostic", file=sys.stderr)
```

`import` 本章只为展示，不深入模块。脚本管道和测试可分别捕获两个流。不要把调试日志混进机器读取的 stdout，否则下游解析失败。

### 9.2 repr 与 str

```python
text = "a\nb"
print(text)
print(repr(text))
```

`str` 倾向人类可读，`repr` 倾向无歧义调试表示。日志中 `repr` 能看出换行和空格，但敏感数据仍需脱敏。

### 9.3 f-string

```python
code = "WO-001"
total_cents = 5997
print(f"工单 {code}，金额 {total_cents} 分")
```

花括号内表达式求值。不要把不可信文本当成可执行表达式；f-string 模板来自源代码。Python 3.14 还有 t-string 等新表面，但本章基础输出使用稳定 f-string，不提前混入模板处理框架。

## 10. input 总是返回字符串

```python
quantity_text = input("请输入数量：")
print(type(quantity_text).__name__)
```

无论用户输入 `3`，返回都是 str（不含行末换行）。需要整数时显式转换：

```python
quantity = int(input("请输入数量："))
```

提示文字写到 stdout 且默认不换行；自动测试中通常将 stdin 重定向并比较完整 stdout。

### 10.1 EOF

若 input 需要一行但输入流已结束，会抛 `EOFError`。在终端可能由快捷键触发，在管道/测试中常因 fixture 行数不足。

这不是“变量为空”，而是没有更多输入。保存堆栈和 stdin fixture，检查第几次 input。

### 10.2 空行与空格

用户直接回车得到 `""`；输入空格得到含空格字符串。`.strip()` 可去除首尾空白：

```python
code = input("工单号：").strip()
```

是否 strip 是字段合同：密码可能不应随意去空格，描述可能保留格式。不能全局机械处理。

## 11. 注释与文档字符串

```python
# 金额统一使用分，避免二进制浮点表示货币。
unit_price_cents = 1999
```

注释解释原因、边界或风险，不重复语法。坏注释：`# quantity 加一`；好注释说明为什么必须包含某边界。

模块、类、函数体开头的字符串可成为 docstring：

```python
"""FactoryCare 金额输入练习。"""
```

不是所有三引号字符串都是注释；放在普通位置会创建再丢弃字符串对象。正式 docstring 在函数/类章展开。

## 12. 逐行预测：名称—对象表

程序：

```python
unit_price_text = input("单价（分）：")
quantity_text = input("数量：")
unit_price_cents = int(unit_price_text)
quantity = int(quantity_text)
total_cents = unit_price_cents * quantity
print(f"总金额：{total_cents} 分")
```

stdin：

```text
1999
3
```

预测表：

| 行后 | 名称 | 类型 | 值 |
| --- | --- | --- | --- |
| 1 | unit_price_text | str | `"1999"` |
| 2 | quantity_text | str | `"3"` |
| 3 | unit_price_cents | int | `1999` |
| 4 | quantity | int | `3` |
| 5 | total_cents | int | `5997` |

stdout 包含提示与结果，具体是否同一行受 input prompt 和 fixture 回显环境影响。自动 subprocess 不会像交互终端回显 stdin，所以 oracle 要基于实际运行方式。

## 13. 错误发生在哪个阶段

### 13.1 SyntaxError / IndentationError

解析阶段，任何业务语句都未开始。例：缺右括号、非法缩进。看文件、行、插入符与上一行上下文。

### 13.2 NameError

运行到读取未绑定名称：

```python
total = unit_price * qunatity
```

拼写错 `quantity`。首个可信证据是 NameError 名称和堆栈行。IDE 波浪线可能提前发现，但运行日志才是本次进程证据。

### 13.3 TypeError

对象类型不支持操作：

```python
print("金额：" + 5997)
```

修复是明确转换/格式化，不是把所有值都变字符串；内部计算仍保留正确类型。

### 13.4 ValueError

类型接受转换操作，但具体内容非法：`int("三")`。记录安全的字段名和错误类别，不在日志泄露原始敏感输入。

### 13.5 EOFError

输入流提前结束。修复 fixture/协议或显式处理 EOF；不能用默认 0 掩盖。

### 13.6 ZeroDivisionError

解析和此前语句成功，执行除法时失败。条件章会在执行前验证除数。

## 14. 常见误区

### 14.1 “Python 变量有类型”

更准确：对象有运行时类型，名称可重新绑定。类型注解以后给名称/接口增加静态合同，但运行机制仍是对象与绑定。

### 14.2 “input 会自动识别数字”

错误，input 返回 str。必须显式解析并处理非法格式。

### 14.3 “print 通过说明功能正确”

错误。它只是一份观察；需要预先写 expected output 和边界/失败 fixture。

### 14.4 “退出码 0 说明金额算法一定正确”

错误。程序可以稳定输出错误结果仍正常退出。断言/oracle 才比较业务期望。

### 14.5 “注释越多越好”

错误。注释应解释意图、单位和反直觉边界；过期注释比没有更危险。

### 14.6 “float 可以直接表示货币”

不可靠。使用分为单位的 int 或后续 Decimal，并明确舍入。

## 15. FactoryCare 实验：维修金额脚本

限制：只使用名称绑定、表达式、`input`、转换和 `print`，不使用 if/循环/函数。

需求：

1. 读单价（分）；
2. 读数量；
3. 读固定服务费（分）；
4. 计算 `单价 × 数量 + 服务费`；
5. 输出工单号、各输入运行时类型和总金额；
6. 用 stdin fixture 验证。

样例 stdin：

```text
WO-001
1999
3
500
```

预期总金额：6497 分。

准备三组：成功、非法数量 `three`、缺最后一行（EOF）。先预测失败类型和行，再运行：

```bash
uv run python amount.py < fixtures/success.stdin > actual.stdout 2> actual.stderr
echo $?
```

失败用例非零是预期证据。不要为了“全绿”吞掉异常；后续学会验证后再提供用户友好错误。

## 16. 调试协议

1. 写出命令、stdin、预期 stdout/stderr/退出码；
2. 判断解析还是运行；
3. 找首个异常类型、文件和行；
4. 查看该行所有名称的值和类型；
5. 做最小修复；
6. 重跑原失败 fixture；
7. 再跑成功与其他边界。

临时 print 调试后清理，或使用 `repr` 展示空白：

```python
print(repr(quantity_text), type(quantity_text).__name__)
```

不要打印 token、密码和个人信息。

## 17. 自测与参考答案

1. **表达式与语句区别？** 表达式产生值；语句执行绑定/控制等动作，表达式也可作为语句求值。
2. **缩进错误在哪阶段？** 解析阶段，业务语句尚未执行。
3. **名称是否固定类型？** 不固定；对象有类型，名称绑定对象，但工程应保持语义稳定。
4. **`7 / 2` 与 `7 // 2`？** 3.5 与 3；`//` 向下整除。
5. **input 返回什么？** 始终 str；EOF 时抛 EOFError。
6. **None 等于空字符串吗？** 不等，None 表示缺值单例。
7. **何时用 `is`？** 比较对象身份，最常见 `is None`；普通值用 `==`。
8. **为何金额用分的 int？** 避免二进制 float 十进制误差并明确单位。
9. **NameError 首先看什么？** 未绑定名称、文件/行和拼写/执行顺序。
10. **本章越界反例？** 用 if 循环处理无限输入或把逻辑封成函数；留给后续章。

## 18. 章节验收清单

- [ ] 能用脚本和 REPL，并解释回显差异。
- [ ] 能区分表达式、赋值语句和表达式语句。
- [ ] 能按缩进读代码块，定位 Syntax/IndentationError。
- [ ] 能用名称绑定模型逐行画对象/类型/值表。
- [ ] 能解释 int、float、bool、str、None 的边界。
- [ ] 能正确使用算术、比较、字符串和括号。
- [ ] 能用 print 的 sep/end、repr 和 f-string 观察结果。
- [ ] 能证明 input 返回 str，区分空行和 EOF。
- [ ] 能区分 NameError、TypeError、ValueError、EOFError。
- [ ] 能用固定 stdin/stdout/exit code 验证金额脚本。

### 18.1 源码编码与终端显示边界

Python 3 源文件默认按 UTF-8 处理，所以中文字符串通常可直接书写；这不保证所有终端、重定向文件和外部系统都采用同一编码。出现乱码时先分别记录源文件编码、`sys.stdout.encoding`、终端 locale 与目标文件解码方式，不要盲目重复 encode/decode。文本在进程内是 Unicode `str`，只有跨文件、网络或进程边界时才需要在字符与 bytes 之间按明确编码转换。当前金额练习只使用文本 stdin/stdout；二进制、文件编码和 JSON 序列化在后续文件章系统学习。测试 fixture 固定为 UTF-8，并在 CI 设置/记录 locale，避免本机中文正常却在另一环境失败。

## 19. 官方资料与更新检查

- Python tutorial：<https://docs.python.org/3.14/tutorial/index.html>
- Lexical analysis / indentation：<https://docs.python.org/3.14/reference/lexical_analysis.html>
- Expressions：<https://docs.python.org/3.14/reference/expressions.html>
- Simple statements：<https://docs.python.org/3.14/reference/simple_stmts.html>
- Built-in types：<https://docs.python.org/3.14/library/stdtypes.html>
- `print` / `input` / `type`：<https://docs.python.org/3.14/library/functions.html>

资料核对日期：2026-07-24。Python 3.14 的新增语法不改变本章核心：按阶段读取、名称绑定对象、input 显式解析、输出与退出码结合 oracle 才形成证据。
