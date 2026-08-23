---
schema_version: 2
edition: 2026.2-draft
id: ch.java.expressions-conversions
title: 运算符、表达式、类型转换、溢出与整数分金额
responsibility: 教授表达式求值和数值边界，使用最小货币例子但不引入 BigDecimal 或业务对象
volume: '01'
order: 4
level: L1
status: drafting
path: book/volume-01-java-language/chapters/ch.java.expressions-conversions.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java.values-variables-types
version_surfaces:
- jdk-25
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释运算符、表达式、类型转换、溢出与整数分金额的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-expressions
  - java-conversions
  covers_topics:
  - java.arithmetic-operator
  - java.precedence
  - java.comparison-boolean-expression
  - java.numeric-promotion-cast
  - java.integer-overflow
  - java.integer-money
  uses_capabilities:
  - java.values-types-string
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现单价分×数量的金额计算器，展示优先级、整型提升、显式转换和接近 int 上限的输入，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - java-expressions
  - java-conversions
  covers_topics:
  - java.arithmetic-operator
  - java.precedence
  - java.comparison-boolean-expression
  - java.numeric-promotion-cast
  - java.integer-overflow
  - java.integer-money
  uses_capabilities:
  - java.values-types-string
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入整数除法截断、窄化转换丢值和乘法溢出，先预测错误结果再选择 long/校验修复，并把异常定位到第一处可信证据
  covers_topic_groups:
  - java-expressions
  - java-conversions
  covers_topics:
  - java.arithmetic-operator
  - java.precedence
  - java.comparison-boolean-expression
  - java.numeric-promotion-cast
  - java.integer-overflow
  - java.integer-money
  uses_capabilities:
  - java.values-types-string
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 运算符、表达式、类型转换、溢出与整数分金额

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《值、变量、基本类型、String、作用域与基本输出》](ch.java.values-variables-types.md)：独立完成运算与表达式、转换与数值边界前，必须先具备「值、变量、基本类型、String、作用域与基本输出」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。正文、正例、实验和公开练习已经可以用于试读与技术复核，但尚未通过独立评审，不能据此把学习进度标记为完成。

你已经会声明变量，也知道 `int quantity = 3;` 中的类型、变量和值分别是什么。现在要回答下一层问题：程序怎样把单价和数量算成总额？为什么 `5 / 2` 得到的不是 `2.5`？为什么把一个 `int` 结果放进 `long` 变量仍可能已经溢出？为什么 `false && dangerousExpression` 可以安全跳过右侧，而看起来相似的 `false & dangerousExpression` 却可能抛异常？

这些并不是面试用的冷知识。AI 能快速写出一条表达式，却不会替你决定金额是否允许截断、类型范围是否覆盖生产数据、失败应该静默回绕还是立即阻止。你需要能预测表达式的**类型、求值顺序、结果和失败方式**，才能审核 AI 生成的业务代码。

本章只处理局部变量和最小金额表达式，不引入 `BigDecimal`、业务对象、方法设计、数据库或完整订单模型。版本基线为 **JDK 25**，官方资料复核日期为 **2026-07-16**。

## 1. 学完后你要能交付什么

学习完成不是“把正文看完”，而是留下三类可复查证据：

1. **解释证据**：在 120 秒内说清运算符、操作数、表达式、结果类型、数值提升、显式窄化、溢出和整数分金额；至少给出一个会编译失败或运行失败的反例。
2. **构建证据**：独立写出“单价分 × 数量 + 固定费用”的计算和整数分摊，覆盖普通值、零、`int` 上限附近以及超过 `int` 正数范围的结果；输出输入、操作和实际结果。
3. **诊断证据**：分别注入整数除法截断、窄化转换编译失败、窄化后丢值、普通乘法静默溢出和除零异常；先预测，再运行，找到第一处可信证据，修复并复跑。

本章配套工件：

- [表达式观察台：可运行正例与预期失败](../../../examples/encyclopedia/ch.java.expressions-conversions/README.md)
- [整数分金额与溢出边界实验](../../../labs/encyclopedia/ch.java.expressions-conversions/README.md)
- [公开独立练习：维修材料费与分摊守恒](../../../exercises/encyclopedia/ch.java.expressions-conversions/README.md)

公开练习不含答案。先完成第一次独立尝试并保存输出，再由老师模式核对；不要让 AI 直接把答案写进公开目录。

## 2. 前置知识与补救入口

硬前置是[上一章：值、变量、基本类型、String、作用域与基本输出](ch.java.values-variables-types.md)。开始前，你至少要能：

- 读出 `int unitPriceCents = 1_999;` 的类型、变量名和值；
- 分清声明、初始化和再次赋值；
- 知道 `int`、`long`、`double`、`boolean` 和 `String` 不是同一类型；
- 把代码放入 `class` 与 `main`，用 `javac --release 25` 编译并用 `java` 运行；
- 看懂标准输出、标准错误和非零退出码是不同证据。

如果你还会把局部变量当成“自动有默认值的盒子”，或分不清编译失败与运行异常，先回上一章做补救。表达式诊断要求你知道程序是否已经成功进入 JVM 运行阶段。

### 2.1 开始前先写预测

不要运行，先把每项的“值、类型、是否失败”写下来：

```java
int a = 2 + 3 * 4;
int b = (2 + 3) * 4;
double c = 5 / 2;
long d = 1_073_741_824 * 2;
boolean e = false && (10 / 0 > 1);
System.out.println("sum=" + 1 + 2);
```

这些语句都能通过语法和类型检查。关键不是编译器是否“看见了 0”，而是运行时会不会真正求值除法：`false && ...` 会跳过右侧。配套正例把零保存到变量中，并分别用 `&&` 与 `&`，让你在相同输入下直接比较“跳过右侧”和“强制求值右侧”。

现在不要急着查答案。等读完第 12 节，再把预测与实际输出逐项对照。

## 3. 一个足够准确的心智模型

先看最小表达式：

```java
unitPriceCents * quantity
```

- `*` 是**运算符**（operator），规定要进行乘法；
- `unitPriceCents` 和 `quantity` 是它的两个**操作数**（operand）；
- 整段是一个**表达式**（expression）；
- 表达式求值后得到一个值，同时这个表达式在编译期有确定的类型；
- 表达式可以成为更大表达式的操作数，也可以作为赋值右侧或输出参数。

```java
long totalCents = (long) unitPriceCents * quantity;
```

阅读这行时，固定问五个问题：

1. 每个名字当前是什么类型和值？
2. 括号和运算符优先级怎样形成子表达式？
3. 每个子表达式在运算前是否发生数值提升或显式转换？
4. 每一步产生什么类型和值，是否可能越界或失败？
5. 最终结果能否赋给左侧类型，业务含义是否允许该结果？

这比只在脑中“算答案”可靠。数学结果正确，不代表 Java 中间步骤没有先溢出；最终类型够大，也不代表运算一开始就在大类型里完成。

### 3.1 表达式有值，也有类型

```java
int quantity = 3;
int unitPriceCents = 1_999;
int total = unitPriceCents * quantity;
boolean expensive = total >= 5_000;
```

- `unitPriceCents * quantity` 的值是 `5997`，类型是 `int`；
- `total >= 5_000` 的值是 `true`，类型是 `boolean`；
- `boolean` 结果不能赋给 `int`，Java 也不会把 `true` 自动当作 `1`。

类型不是只写在变量声明左侧。字面量、变量引用、算术、比较和逻辑表达式都有类型。编译器正是根据这些类型判断运算是否合法。

### 3.2 “计算规则”与“业务规则”必须分开

Java 能算出 `-100 * 3 == -300`，不表示业务允许负数量。Java 能把 5,997 分平均拆成 1,999 分三份，不表示税费、折扣或退款都能随意截断。语言规则回答“机器会怎样求值”；业务规则回答“这个值是否有效、如何舍入、谁承担余数”。审核代码时两层都要检查。

## 4. 本章使用的运算符

### 4.1 算术运算符

| 运算符 | 作用 | 整数示例 | 结果 |
| --- | --- | --- | ---: |
| `+` | 加法；遇到 `String` 时也可连接文本 | `7 + 2` | `9` |
| `-` | 减法 | `7 - 2` | `5` |
| `*` | 乘法 | `7 * 2` | `14` |
| `/` | 除法 | `7 / 2` | `3` |
| `%` | 余数 | `7 % 2` | `1` |
| 一元 `+` | 保持数值符号并进行一元数值提升 | `+7` | `7` |
| 一元 `-` | 取相反数并进行一元数值提升 | `-7` | `-7` |

`/` 不是固定产生小数，结果取决于操作数类型。`%` 不是“百分比”，而是除法余数运算符。

### 4.2 比较与相等运算符

| 运算符 | 含义 | 示例 | 结果类型 |
| --- | --- | --- | --- |
| `<` | 小于 | `quantity < 10` | `boolean` |
| `<=` | 小于等于 | `quantity <= 10` | `boolean` |
| `>` | 大于 | `totalCents > 0` | `boolean` |
| `>=` | 大于等于 | `totalCents >= 5_000` | `boolean` |
| `==` | 相等 | `quantity == 3` | `boolean` |
| `!=` | 不相等 | `quantity != 0` | `boolean` |

本章只用 `==` 比较基本数值和布尔值。对象、`String` 内容比较、引用身份和 `equals` 属于后续对象章节，不能从本章例子推断 `String` 应用 `==` 比内容。

### 4.3 布尔逻辑运算符

```java
boolean validQuantity = quantity >= 0;
boolean canSplit = groups > 0 && totalCents >= 0;
boolean needsReview = totalCents > limitCents || quantity > limitQuantity;
boolean disabled = !enabled;
```

- `&&`：两边都为 `true` 才为 `true`，并且会短路；
- `||`：至少一边为 `true` 就为 `true`，并且会短路；
- `!`：对一个布尔值取反；
- `&`、`|` 也能处理布尔操作数，但会求值两侧，本章不把它们当普通条件组合写法。

Java 不接受 `if (quantity)` 这种 JavaScript 风格的“真值”判断。条件必须是 `boolean` 表达式，例如 `quantity > 0`。

## 5. 优先级、结合性与求值顺序不是一回事

这三个概念最容易被混在一起。

### 5.1 优先级决定怎样分组

```java
int result = 2 + 3 * 4;
```

`*` 的优先级高于 `+`，所以相当于：

```java
int result = 2 + (3 * 4); // 14
```

不是：

```java
int result = (2 + 3) * 4; // 20
```

本章常用运算符从高到低可这样记：

| 层级（高到低） | 本章运算符 | 例子 |
| --- | --- | --- |
| 显式分组 | `(...)` | `(2 + 3) * 4` |
| 一元 | `!`、一元 `+`、一元 `-`、类型转换 | `-(quantity)`、`(long) value` |
| 乘除余 | `*`、`/`、`%` | `price * count / groups` |
| 加减 | `+`、`-` | `subtotal + fee` |
| 大小比较 | `<`、`<=`、`>`、`>=` | `total >= limit` |
| 相等比较 | `==`、`!=` | `remainder == 0` |
| 短路与 | `&&` | `groups > 0 && ...` |
| 短路或 | `||` | `quantity == 0 || ...` |
| 赋值 | `=` | `total = expression` |

表格只覆盖本章使用的运算符，不是 Java 全部运算符表。真实业务表达式一旦需要读者停下来背表，就加括号表达意图；括号不能修复错误的类型和业务规则，但能减少误读。

### 5.2 结合性处理同一优先级的连续运算

`-` 和 `/` 这类二元算术运算符按左结合分组：

```java
int a = 10 - 3 - 2; // (10 - 3) - 2，结果 5
int b = 20 / 5 / 2; // (20 / 5) / 2，结果 2
```

左结合不表示任何场景都可以随意移动括号：`10 - (3 - 2)` 是 `9`，与 `5` 不同；`20 / (5 / 2)` 还会先发生整数除法，结果也不同。

### 5.3 求值顺序决定操作数何时被执行

Java 按从左到右求值运算符的操作数，并遵守括号与优先级形成的分组。优先级更高不等于源码右边一定先于左边执行。若子表达式包含方法调用、异常或状态改变，区别就可观察到。

初学阶段最安全的规则是：

- 用优先级判断表达式结构；
- 用从左到右判断结构内各操作数的求值先后；
- 不依赖难读的副作用表达式；一个语句同时计算又修改多个值时，拆成有名字的中间结果。

本章示例刻意不使用 `i++ + ++i` 这类谜题。它们即使有语言规定的结果，也不代表是可维护业务代码。

## 6. 整数除法与余数

### 6.1 两个整数相除，结果仍是整数

```java
int each = 5 / 2; // 2
```

两个操作数都是整数类型，Java 执行整数除法。无法整除的部分被向零截断，不是四舍五入：

```java
int positive = 7 / 3;  // 2
int negative = -7 / 3; // -2，不是 -3
```

把结果交给 `double` 不会让已经完成的整数除法重新计算：

```java
double tooLate = 5 / 2;   // 先得到 int 2，再扩大为 double 2.0
double decimal = 5.0 / 2; // 一个操作数是 double，结果 2.5
```

这就是常见逻辑故障：源码能编译、进程正常退出，结果却不符合业务预期。此时没有 `ERROR` 日志，第一处可信证据是“输入、运算类型、实际输出与预期不一致”。

### 6.2 `%` 保存不能整除的余数

```java
int totalCents = 1_000;
int groups = 3;
int eachCents = totalCents / groups;         // 333
int remainderCents = totalCents % groups;   // 1
```

对非零整数除数，下面的重组关系成立：

```text
(totalCents / groups) * groups + totalCents % groups == totalCents
```

余数的符号跟被除数一致，且绝对值小于除数的绝对值：

```java
int q = -7 / 3; // -2
int r = -7 % 3; // -1，因为 (-2) * 3 + (-1) == -7
```

金额通常先通过业务校验限制为非负值，所以不应把负数余数规则当成退款分摊方案。退款、冲正和谁承担尾差需要明确领域规则。

### 6.3 整数除零是运行时失败

```java
int divisor = 0;
int result = 10 / divisor;
```

源码可以编译，但运行到除法时抛出 `ArithmeticException: / by zero`，进程若未处理异常会非零退出。相同规则适用于整数 `% 0`。

即使直接写 `10 / 0`，整数除零仍按运行时异常规则处理；不能把“字面量 0 很明显”误记成编译期类型错误。故障实验把零放在变量中，是为了让短路与非短路两个版本复用同一种输入，并清楚观察右侧究竟有没有执行。

浮点除零规则不同：`double` 可能得到正负无穷或 `NaN`，不会因为除数是 `0.0` 自动抛出整数除零异常。不要用这一差异绕过业务输入校验。

### 6.4 一个极端边界

`Integer.MIN_VALUE / -1` 的数学结果比 `int` 最大值大 1。Java 对这个特殊整数除法结果保留 `Integer.MIN_VALUE`，不抛异常。普通 `/` 不是“精确且自动检查范围”的 API；当范围本身就是业务约束时，必须显式校验或使用相应的 exact 方法。

## 7. 短路表达式：右侧可能根本不求值

### 7.1 `&&`：左侧为 false，就跳过右侧

```java
int groups = 0;
boolean valid = groups > 0 && totalCents / groups >= 0;
```

求值过程：

1. 先算 `groups > 0`，得到 `false`；
2. `false && anything` 必然为 `false`；
3. Java 不求值右侧，所以不会执行 `/ groups`，也不会除零。

这可以用于先检查一个条件，再执行依赖该条件才安全的表达式。但可读性更重要：输入校验复杂时，应写成清晰的分支和错误信息，而不是把所有规则塞进一行。

### 7.2 `||`：左侧为 true，就跳过右侧

```java
boolean noWorkNeeded = quantity == 0 || totalCents / quantity <= limitCents;
```

如果 `quantity == 0` 为 `true`，右侧不会求值，因此不会除零。

### 7.3 `&` 与 `|` 不会短路

```java
int divisor = 0;
boolean result = false & (10 / divisor > 1);
```

虽然最终逻辑不可能为 `true`，`&` 仍会求值右侧，于是抛出 `ArithmeticException`。配套观察台把它作为预期运行失败。业务条件通常用 `&&`、`||`；只有确实需要两侧都执行并能解释原因时，才考虑布尔 `&`、`|`。

短路能跳过右侧，不等于它是完整的错误处理。它不会记录非法输入原因，也不会替你设计 API 错误响应。

## 8. `String` 连接与算术的交界

`+` 的操作数中一旦进入字符串连接上下文，后续会从左到右连接文本：

```java
System.out.println("sum=" + 1 + 2);   // sum=12
System.out.println("sum=" + (1 + 2)); // sum=3
```

第一行先得到字符串 `"sum=1"`，再把 `2` 转成文本连接；第二行用括号要求先做整数加法。

输出金额时，先计算并保存有类型的结果，再拼接标签通常更清楚：

```java
long totalCents = (long) unitPriceCents * quantity;
System.out.println("totalCents=" + totalCents);
```

不要通过观察一条拼接输出反推表达式类型。IDE 的参数提示、编译器和显式中间变量比“看起来像数字”可信。

## 9. 数值提升：运算前先确定共同类型

### 9.1 `byte + byte` 也通常得到 `int`

```java
byte left = 40;
byte right = 2;
int sum = left + right; // 42
```

执行常见整数算术前，`byte`、`short` 和 `char` 会提升为 `int`。所以这行不能直接写成：

```java
byte sum = left + right; // 编译失败：int 不能自动窄化为 byte
```

而下面能编译：

```java
byte answer = 40 + 2;
```

因为右侧是编译期常量表达式，值 `42` 落在 `byte` 范围内，赋值上下文允许这类受限常量窄化。不要把这个特例误记成“整数加法结果是 byte”。把变量换进去后，结果类型仍是 `int`。

### 9.2 二元数值提升的常用顺序

对本章的二元数值运算，可以用下面的决策顺序：

1. 任一操作数是 `double`，另一个转换为 `double`；
2. 否则任一是 `float`，另一个转换为 `float`；
3. 否则任一是 `long`，另一个转换为 `long`；
4. 否则两边都按 `int` 运算。

```java
int quantity = 3;
long unitPriceCents = 1_999L;
long total = unitPriceCents * quantity; // quantity 先扩大为 long
```

比较运算也会先把数值操作数提升到可比较的共同类型，然后产生 `boolean`。数值提升不是把变量声明永久改掉；它只影响当前表达式求值。

### 9.3 最终变量类型不能逆转中间运算

这是本章最重要的边界之一：

```java
int unitPriceCents = 1_073_741_824;
int quantity = 2;

long wrong = unitPriceCents * quantity;
long correct = (long) unitPriceCents * quantity;
```

`wrong` 的右侧两个操作数都是 `int`，因此先做 `int` 乘法，得到溢出后的 `-2147483648`，然后才扩大为 `long`。变量 `wrong` 最终保存的是 `-2147483648L`。

`correct` 在乘法前把一个操作数转换成 `long`，二元数值提升让另一侧也以 `long` 参与，结果是 `2147483648L`。

口诀只能作为提醒：**先扩再算有效，算完再接已经太晚。** 真正判断仍要逐个标出子表达式类型。

## 10. 类型转换：扩大不等于永远无损，强转不等于验证

### 10.1 扩大基本类型转换

Java 允许的扩大转换由 JLS 的转换表定义，不能只比较类型名称或位数后自行推断。例如 `int` 可以扩大到 `long`，但同为 16 位的 `short` 与 `char` 之间不存在自动扩大关系；`char` 也不能自动转成 `short`。一个常见的合法例子是：

```java
int count = 3;
long wideCount = count;
```

整数到整数的扩大转换保持精确值。某些整数到浮点的扩大转换虽然不抛异常，却可能丢失精度，例如很大的 `long` 转成 `double`，或部分 `int` 转成 `float`。因此“widening conversion”描述的是语言允许的方向，不等于每一种目标表示都能精确保留原值。

```java
int sourceValue = 16_777_217;
float rounded = sourceValue; // 合法，但 float 不能精确保留这个整数
```

本章金额不使用二进制浮点数，避免把“范围容得下”误当成“每一分都精确”。

### 10.2 窄化基本类型转换需要显式 cast

```java
long measuredCents = 3_000_000_000L;
int displayedCents = (int) measuredCents;
```

`long` 到 `int` 是窄化。强制转换 `(int)` 让代码通过编译，但结果不是 30 亿，而是 `-1294967296`。高位被丢弃，符号也可能改变。

如果不写 cast：

```java
int displayedCents = measuredCents;
```

编译器会报告可能有损转换。这是保护，不是麻烦。修复方式不是机械加 `(int)`，而是先问：

- 目标真的必须是 `int` 吗？
- 业务允许什么范围？
- 越界时应该拒绝、报警还是使用 `long`？
- 若必须转成 `int`，能否使用 `Math.toIntExact` 在越界时显式失败？

### 10.3 cast 的位置改变运算类型

```java
long a = (long) unitPriceCents * quantity; // 先转左侧，再做 long 乘法
long b = (long) (unitPriceCents * quantity); // 先做 int 乘法，再转结果
```

两行括号只差一个位置，溢出语义完全不同。代码评审时看到 cast，必须看它作用于哪个子表达式。

### 10.4 复合赋值隐藏了转换

```java
byte level = 120;
level += 10; // 可编译，效果包含隐式窄化，结果可能回绕
```

`E1 op= E2` 并不总是等价于简单写下 `E1 = E1 op E2`；复合赋值会包含到左侧类型的隐式转换。初学和金额代码中，优先把中间结果放进足够宽的类型，并显式检查范围，不要用 `+=` 掩盖窄化。

## 11. `int` 溢出：程序可能成功结束，但结果已经错误

### 11.1 `int` 的边界

`int` 是 32 位有符号整数，范围是：

```text
-2,147,483,648 到 2,147,483,647
```

普通整数加、减、乘如果超出范围，不会自动变成 `long`，也不会因溢出自动抛异常。结果按固定宽度保留低位，可能从大正数回绕为负数：

```java
int value = 1_073_741_824 * 2;
System.out.println(value); // -2147483648
```

此时：

- 编译成功；
- JVM 进程正常启动；
- 输出语句正常执行；
- 退出码可能仍为 0；
- 但业务结果错误。

所以 `BUILD SUCCESS` 或退出码 0 只能证明执行链没有以异常终止，不能证明数值正确。必须用边界输入和预期结果核对。

### 11.2 三种策略不是互相替代

**策略 A：运算前扩大到 `long`**

```java
long totalCents = (long) unitPriceCents * quantity;
```

适合数学结果可能超过 `int`、但在 `long` 范围内且业务允许的情况。`long` 也有上限，不是无限整数。

**策略 B：使用 exact 运算，让越界立即失败**

```java
int totalCents = Math.multiplyExact(unitPriceCents, quantity);
```

若 `int` 乘法越界，`Math.multiplyExact` 抛出 `ArithmeticException`。适合“结果必须仍在 int 范围，否则就是非法状态”的契约。

这里的 `Math.multiplyExact(...)`，以及实验断言中读取的 `Integer.MIN_VALUE`，都是 **copy-run-only 固定支架**。本章只观察它们对数值边界的可重复行为，不要求你解释方法声明、参数传递、返回值、类字段或 `static` 类成员；这些语法会分别在“方法”和“static、类成员”章节系统教授。

也可以先转 `long` 再用对应的 `long` exact 重载检查 `long` 溢出。选择取决于领域范围，不是追求最宽类型。

**策略 C：在边界处校验输入与结果范围**

输入校验能给用户更明确的错误，例如数量必须非负且不超过业务上限。但只校验单个参数不一定能阻止乘积越界；还要验证组合结果或使用 exact 运算。

常见可靠组合是：边界校验解释业务规则，足够宽的类型保存合法结果，exact 运算保护实现假设。

### 11.3 哪一处是第一可信证据

发生静默溢出时通常没有异常日志。诊断顺序：

1. 记录输入的值与类型；
2. 手算或使用可信工具得到数学结果；
3. 标出乘法实际使用 `int` 还是 `long`；
4. 比较程序输出与数学结果；
5. 查看 cast 是发生在乘法前还是后；
6. 做最小修复并用同一输入复跑。

“输出是负数”是现象；“两个 `int` 在乘法时超出 `int` 最大值”才是定位到规则的解释。

## 12. 为什么本章用整数“分”表示金额

### 12.1 最小模型

若当前业务货币明确使用两位小数，教学示例可以把 19.99 元写成 1,999 分：

```java
int unitPriceCents = 1_999;
int quantity = 3;
long totalCents = (long) unitPriceCents * quantity; // 5,997 分
```

这样乘法和加法都在整数域中完成，不引入 `double` 的二进制小数近似，也能直接观察溢出边界。

### 12.2 整数分不等于完整金额系统

这个模型有明确适用边界：

- 货币的小数位数必须已知，不是所有货币都固定两位；
- 汇率、税率、折扣和按比例分摊可能产生小于一分的中间值；
- 舍入模式、尾差承担方和退款规则必须由业务定义；
- 金额还需要货币代码，不能只保存一个裸数字；
- 跨系统 API 和数据库必须约定单位，避免一端传“元”、另一端按“分”理解；
- `long` 仍需业务上下限和溢出策略。

本章不教授 `BigDecimal`。后续金额建模章节会处理十进制精度、舍入和领域类型。本章只建立“操作单位明确、运算前选对类型、结果可验证”的习惯。

### 12.3 整数分摊要保存余数

```java
long totalCents = 5_997L;
int groups = 4;
long eachCents = totalCents / groups;       // 1,499
long remainderCents = totalCents % groups; // 1
boolean conserved = eachCents * groups + remainderCents == totalCents;
```

`conserved` 验证金额守恒，但没有决定余下 1 分给谁。真实系统还需要确定分配顺序、幂等性、并发与审计记录。本章只证明“每组整数分 + 余数”没有凭空增加或丢失金额。

## 13. 运行表达式观察台

进入正例目录：

```bash
cd examples/encyclopedia/ch.java.expressions-conversions
./verify.sh
```

脚本要求当前 `javac` 为 JDK 25，用 `--release 25` 编译，然后逐行验证正常输出。重点输出包括：

```text
precedence=14
parenthesized=20
integerDivision=2
widenedAfterDivision=2.0
floatingDivision=2.5
narrowed=-1294967296
rawOverflow=-2147483648
widenedBeforeMultiply=2147483648
splitEach=333
splitRemainder=1
stringTrap=12
stringGrouped=3
```

脚本还要求四个故障必须发生：

| 故障 | 阶段 | 预期第一可信证据 |
| --- | --- | --- |
| 整数变量除零 | 运行 | 非零退出，`ArithmeticException: / by zero` |
| `false &` 仍求值危险右侧 | 运行 | 非零退出，栈追踪指向右侧除法 |
| `Math.multiplyExact` 越界 | 运行 | 非零退出，`ArithmeticException: integer overflow` |
| `long` 直接赋给 `int` | 编译 | 源文件位置与 `possible lossy conversion from long to int` |

这些失败是实验成功证据，不要为了让脚本全绿而删除。脚本把预期失败包装为通过条件，目的是确认你真的观察过边界。

### 13.1 日志定位模板

遇到错误时写下：

```text
执行命令：
工具版本：
失败阶段：编译 / 运行 / 结果校验
输入值与类型：
预期结果：
实际结果或异常：
第一个文件:行号（如有）：
触发的语言规则：
最小修复：
复跑证据：
```

不要把 Maven、IDE 或脚本最后一行当作唯一证据。编译错误优先看第一个源码位置；运行异常优先看异常类型、消息和第一处属于自己代码的栈帧；逻辑错误优先看固定输入、实际输出与预期差异。

## 14. 与 JavaScript / TypeScript 的对照

你已有前端经验，可以借用表达式直觉，但要主动切换规则：

| 主题 | Java | JavaScript / TypeScript | 迁移风险 |
| --- | --- | --- | --- |
| 常用数值类型 | 多种固定范围基本数值类型 | JS 常用 `number`，另有 `bigint` | 忘记 `int` 会静默溢出 |
| 整数除法 | 两个整数操作数得到整数商 | `5 / 2` 的 `number` 结果是 `2.5` | 把 Java 的 `5 / 2` 当成小数 |
| 布尔条件 | 条件必须是 `boolean` | JS 有 truthy/falsy；TS 仍运行 JS 规则 | 写出 `if (quantity)` 或把 0 当 false |
| 数值自动转换 | 由静态类型与数值提升规则控制 | JS 可能发生运行时强制转换 | 期待 Java 自动把字符串转数字 |
| 字符串 `+` | 一旦进入字符串连接就从左到右连接 | JS 也有类似陷阱 | 因语法相似而忽略静态结果类型 |
| 越界 | `int`、`long` 固定范围并可回绕 | `number` 使用 IEEE 754 双精度；大整数也有安全范围 | 误以为换成 `long` 就无限精确 |
| 短路 | `&&`、`||` 产生 `boolean` 且短路 | JS 返回某个操作数本身 | 期待 Java 的 `a && b` 返回非布尔对象 |
| 强制转换 | `(int) value` 是语言级数值转换 | TS `as` 主要是类型断言，不进行对应运行时数值转换 | 把 Java cast 当成只告诉编译器“相信我” |

尤其要区分 Java cast 与 TypeScript `as`：Java 的 `(int) longValue` 会真实改变数值表示并可能丢位；TypeScript 的 `value as number` 通常不会在运行时把字符串解析成数字。

## 15. FactoryCare 中的真实落点

本章表达式会出现在后续设备运维系统的很多位置：

- 配件单价分 × 数量得到材料费；
- 工时分钟数 / 60 得到完整小时，同时 `% 60` 保存剩余分钟；
- `statusAllowed && assigneePresent` 组合状态前置条件；
- 当前计数 `>=` 阈值产生告警布尔值；
- 分页总数计算要警惕加法和除法顺序；
- 批量导入统计要警惕 `int` 计数与字节大小溢出。

一个最小费用片段：

```java
int partUnitPriceCents = 1_299;
int partQuantity = 4;
int inspectionFeeCents = 200;

long totalCents = (long) partUnitPriceCents * partQuantity + inspectionFeeCents;
boolean nonNegative = totalCents >= 0;

System.out.println("totalCents=" + totalCents);
System.out.println("nonNegative=" + nonNegative);
```

它只证明语言表达式正确，不是生产服务代码。生产落地还需要：输入来源可信度、单位和货币代码、权限、数据库约束、异常映射、事务、并发、日志脱敏与测试。这些会在后续卷逐层加入。

## 16. 安全、可靠性与 AI 协作边界

### 16.1 不要把不可信表达式当代码执行

用户输入的 `"1000 * 3"` 是文本，不应被拼接成源码、脚本或数据库表达式再执行。业务 API 应接收有类型的字段，例如单价分和数量，服务端再按固定代码计算并校验。

### 16.2 日志记录单位，不记录不必要的敏感内容

诊断金额时记录字段名、单位、范围和请求追踪标识；不要随意打印支付凭据、完整个人信息或密钥。`total=5997` 如果没有单位，几周后就可能被误读为元、分或毫分。

### 16.3 AI 生成代码必须过四道数值检查

让 Codex 或 Claude 写表达式后，至少检查：

1. **单位**：每个操作数是元、分、数量、比例还是分钟？
2. **类型**：中间运算是 `int`、`long`、浮点还是十进制类型？
3. **边界**：零、负值、最大合法值、组合乘积和除零怎样处理？
4. **证据**：有没有固定输入、预期输出、失败注入和复跑记录？

Vibe coding 能减少敲字时间，不能替代你对数据契约和边界的签字责任。最危险的代码往往不是编译失败，而是“每次都能跑、只在大数据时算错”。

## 17. 实验：整数分金额与溢出边界

打开[实验说明](../../../labs/encyclopedia/ch.java.expressions-conversions/README.md)，按顺序完成，不要一上来运行脚本。

### 17.1 第一步：预测

手算并记录：

| 场景 | 单价分 | 数量 | 预期数学结果 | 预期 Java 运算类型 |
| --- | ---: | ---: | ---: | --- |
| 普通 | 1,999 | 3 | 5,997 | 先转换为 `long` |
| 零数量 | 1,999 | 0 | 0 | `long` |
| `int` 安全上界附近 | 1,073,741,823 | 2 | 2,147,483,646 | `long` |
| 超过 `int` 最大值 1 | 1,073,741,824 | 2 | 2,147,483,648 | 必须在乘法前成为 `long` |

再预测普通 `int` 乘法和 `Math.multiplyExact` 对最后一组输入分别怎样表现。

### 17.2 第二步：模仿与逐行解释

阅读 `MoneyLab.java`，用注释或学习记录标出：

- cast 作用于哪一个操作数；
- 为什么整个乘法变成 `long`；
- `/` 与 `%` 的操作数类型；
- 守恒式为什么能发现丢失余数；
- 哪些是语言规则，哪些仍缺业务校验。

### 17.3 第三步：运行并核对

```bash
cd labs/encyclopedia/ch.java.expressions-conversions
./verify.sh
```

有效证据至少包括：

```text
assertions=8 passed
EXPECTED_FAILURE MoneyOverflowProbe status=1 evidence=ArithmeticException
LAB PASS normal=5997 zero=0 boundary=2147483646 widened=2147483648
```

这里使用 Java 自带 `assert` 只是 **copy-run-only 固定验证支架**，脚本显式通过 `-ea` 启用它。你只需要复制运行并读取成功/失败证据，不需要在本章设计新的断言体系或诊断断言失败；这些内容会在“调试与失败”和测试章节系统整理。本章只聚焦表达式规则。

### 17.4 第四步：修改

选择一项，每次修改前先写预测：

1. 把普通数量从 3 改成 4，更新手算值；
2. 把分组数从 4 改成 5，验证商、余数和守恒式；
3. 把 cast 从乘法操作数移到整个乘法外，观察大输入结果；
4. 把 `Math.multiplyExact` 输入改到刚好不溢出的边界，再增加 1。

只改一处，运行，保存差异，再恢复。否则无法确认哪个改动导致哪个结果。

### 17.5 第五步：故障—修复—复跑

至少完成以下闭环：

```text
预测：移除乘法前 cast 后，大输入会先按 int 乘法并回绕为负数。
注入：long total = unitPriceCents * quantity;
观察：数学结果 2147483648，实际结果 -2147483648，进程仍退出 0。
定位：右侧两个操作数都是 int，溢出发生在赋给 long 之前。
修复：long total = (long) unitPriceCents * quantity;
复跑：实际结果 2147483648，其他断言仍通过。
```

这个记录比“AI 修好了”更有价值，因为它能在面试、评审和生产排障中复用。

## 18. 独立练习与验收

进入[公开练习](../../../exercises/encyclopedia/ch.java.expressions-conversions/README.md)。先关闭 AI，限时 25 分钟，只替换起始文件中的四个右侧表达式。

固定输入为单价 2,500 分、数量 3、上门费 1 分、4 个分摊组。你需要独立得到：

```text
totalCents=7501
eachCents=1875
remainderCents=1
conserved=true
```

验收不只看四行相同，还要口头回答：

1. 为什么 cast 放在乘法左操作数上，而不是整个乘法外？
2. 为什么每组金额和余数都用 `long`？
3. `conserved` 证明了什么，没有证明什么？
4. 若 `groups` 为 0，失败发生在哪个阶段？第一可信证据是什么？
5. 若必须保证总额仍是 `int`，应选扩大类型、范围校验还是 `Math.multiplyExact`？为什么？

完成后做两次迁移：把上门费改为 3；再临时使用会让 `int` 乘法溢出的大单价。每次都遵守“预测—运行—解释—恢复”。

## 19. 120 秒复述模板

不要背整章，按因果关系复述：

> 运算符规定对操作数进行什么运算，表达式求值会产生有类型的值。括号和优先级决定分组，同级运算还受结合性影响，而 Java 按从左到右求值操作数。两个整数做除法会向零截断，余数可用 `%` 保存；整数除零会失败。数值运算前会进行提升，byte、short、char 常提升为 int；有 long 操作数时另一侧提升为 long。把 int 运算结果赋给 long 不会逆转已经发生的 int 溢出，所以要在运算前扩大。窄化 cast 可能丢位，强转不是范围校验。普通 int 溢出通常静默回绕；业务可选择 long、范围校验或 Math.multiplyExact。整数分适合本章的两位小数金额最小例子，但真实金额还要货币、舍入和业务规则。

再补一个失败反例和定位证据，例如：

> `long total = 1_073_741_824 * 2;` 右侧仍是 int 乘法，实际先得到 -2147483648，再扩大成 long。它可能正常退出，所以第一可信证据是固定输入下实际输出与数学结果不一致；修复是在乘法前把一个操作数转为 long，并用同一输入复跑。

如果超过 120 秒，先删例子，不删“运算前类型决定中间结果”这条主线。

## 20. 自测题

先独立作答，再运行最小程序验证。

1. `7 + 2 * 3` 与 `(7 + 2) * 3` 分别是多少？
2. `20 / 3`、`20 % 3`、`-20 / 3`、`-20 % 3` 分别是多少？
3. 为什么 `double result = 5 / 2;` 是 `2.0`？写出得到 `2.5` 的两种改法。
4. `byte a = 40; byte b = 2;` 后，`a + b` 的类型是什么？
5. `long result = intA * intB;` 是否保证乘法不发生 `int` 溢出？
6. `(int) 3_000_000_000L` 是验证还是转换？可能发生什么？
7. `false && dangerous()` 与 `false & dangerous()` 是否都会调用右侧？
8. 为什么 `"total=" + 1 + 2` 不是 `"total=3"`？
9. `Math.multiplyExact` 与转换为 `long` 分别表达什么不同契约？
10. 整数分摊中的余数为什么不能直接丢弃？守恒式能验证什么？
11. “编译成功、退出码 0”为什么不能证明金额正确？
12. 整数分模型为什么仍不足以覆盖汇率、税率和多币种？

合格标准不是选中答案，而是每题能给出一个最小表达式或输出证据。

## 21. 间隔复习安排

| 时间 | 任务 | 通过证据 |
| --- | --- | --- |
| 当天 | 跑观察台和实验，完成公开练习 | 正常输出、预期失败、独立输出三类记录齐全 |
| 第 1 天 | 不看书写出优先级、整数除法、提升与溢出主线 | 120 秒复述，能给一个反例 |
| 第 3 天 | 重写金额计算与分摊，不复制旧代码 | 大输入得到 `2147483648`，守恒式为真 |
| 第 7 天 | 注入“cast 太晚”和“错误期望值” | 能区分静默逻辑错误与运行异常 |
| 第 14 天 | 审查一段 AI 生成费用代码 | 标出单位、类型、中间范围、舍入和验证缺口 |
| 第 30 天 | 在后续项目中寻找一个真实表达式 | 留下输入边界、失败策略和测试证据 |

若复习时只能背结论，回到表达式观察台改一个输入；若能预测但总写错代码，重做公开练习；若代码能跑但解释含糊，重点练 120 秒复述。

## 22. 速查表

### 22.1 求值检查清单

```text
操作数的类型和值是什么？
括号和优先级如何分组？
同级运算怎样结合？
各操作数按什么顺序求值？
运算前发生了什么提升或 cast？
每个中间结果的类型与范围是什么？
整数除法是否截断，余数是否保存？
可能除零、窄化或溢出吗？
业务单位和舍入规则是什么？
怎样用固定输入验证？
```

### 22.2 常见现象到原因

| 现象 | 首先检查 |
| --- | --- |
| `5 / 2` 得到 2 | 两个操作数是否都是整数 |
| `double` 变量里是 `2.0` 而非 `2.5` | 除法是否在赋值前已经按整数完成 |
| 大正数乘积变负数 | 乘法时是否仍是 `int` |
| cast 后数值完全不同 | 是否发生有损窄化 |
| `false` 条件仍抛除零 | 是否误用了非短路 `&` |
| 日志显示 `sum=12` | 字符串连接是否早于数值加法进入 |
| `byte + byte` 不能赋给 byte | 二元数值提升后结果是否为 `int` |
| 退出码 0 但金额错误 | 是否只有运行证据，没有结果断言与边界样例 |

### 22.3 三种范围策略

| 需求 | 常用方向 |
| --- | --- |
| 合法结果可超过 `int` | 运算前提升为 `long` |
| 结果必须留在固定类型范围 | `Math.*Exact` 或显式范围检查 |
| 需要向用户解释业务上限 | 在输入边界做领域校验，并保留底层溢出保护 |

## 23. 术语表

| 术语 | 本章定义 |
| --- | --- |
| 运算符 operator | 规定对一个或多个操作数执行何种运算的符号或语法 |
| 操作数 operand | 被运算符读取并参与运算的表达式 |
| 表达式 expression | 求值后产生一个值并具有类型的程序结构 |
| 优先级 precedence | 不加括号时，不同运算符怎样形成分组的规则 |
| 结合性 associativity | 同一优先级运算符连续出现时怎样分组的规则 |
| 求值顺序 evaluation order | 程序实际求取各操作数值的先后顺序 |
| 短路 short-circuit | 根据左操作数即可确定结果时，不求值右操作数 |
| 数值提升 numeric promotion | 运算前把数值操作数转换到当前运算使用的共同类型 |
| 扩大转换 widening conversion | 转向语言允许的更宽表示；不一定对所有整数到浮点转换都精确 |
| 窄化转换 narrowing conversion | 转向较窄表示，可能丢失范围、精度或改变符号 |
| cast | 通过 `(目标类型)` 显式请求转换；不等同于业务校验 |
| 截断 truncation | 整数除法丢弃不能构成整数商的部分并向零取整 |
| 余数 remainder | `%` 计算的除法剩余部分，可用于验证整数分配守恒 |
| 溢出 overflow | 数学结果超出目标数值类型可表示范围 |
| 静默回绕 wraparound | 普通整数运算越界后保留固定宽度结果而不自动抛异常 |
| 整数分 integer cents | 在明确两位小数货币的最小示例中，用最小单位整数保存金额 |
| 第一可信证据 | 最早能直接支持故障判断的编译位置、异常栈帧或输入—输出差异 |

## 24. 本章明确不教什么

为了让每条规则都能被零基础学习者验证，本章有意不展开：

- `BigDecimal`、舍入模式、汇率、税率和多币种领域建模；
- 方法参数、返回值、重载与对象封装；
- `String` 内容相等、引用身份和 `equals`；
- 位运算、移位、三元表达式、模式匹配和完整运算符表；
- 输入解析、异常捕获、HTTP 错误响应和数据库约束；
- JIT、字节码指令和硬件寄存器层面的实现细节。

这些不是遗漏，而是后续章节的责任边界。本章要先保证你能稳定回答：**这条表达式以什么类型、按什么顺序、得到什么结果，在哪里可能失败？**

## 25. 版本与官方来源

本章语言与 API 基线为 JDK 25。核心表达式、数值提升和基本类型规则长期稳定；执行命令和 exact API 仍以本仓库 `jdk-25` 版本面为准。

- [Java Language Specification 25, §4.2.2 Integer Operations](https://docs.oracle.com/javase/specs/jls/se25/html/jls-4.html#jls-4.2.2)：整数范围、整数运算和溢出行为。
- [Java Language Specification 25, §5.1.2 Widening Primitive Conversion](https://docs.oracle.com/javase/specs/jls/se25/html/jls-5.html#jls-5.1.2)：扩大基本类型转换及精度边界。
- [Java Language Specification 25, §5.1.3 Narrowing Primitive Conversion](https://docs.oracle.com/javase/specs/jls/se25/html/jls-5.html#jls-5.1.3)：窄化转换可能丢失范围、精度和高位。
- [Java Language Specification 25, §5.2 Assignment Contexts](https://docs.oracle.com/javase/specs/jls/se25/html/jls-5.html#jls-5.2)：赋值上下文允许哪些转换，以及常量表达式的窄化边界。
- [Java Language Specification 25, §5.6 Numeric Contexts](https://docs.oracle.com/javase/specs/jls/se25/html/jls-5.html#jls-5.6)：一元和二元数值提升。
- [Java Language Specification 25, §15.7 Evaluation Order](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.7)：括号、优先级与从左到右求值。
- [Java Language Specification 25, §15.18.1 String Concatenation Operator `+`](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.18.1)：数字加法与字符串拼接的分界。
- [Java Language Specification 25, §15.26.2 Compound Assignment Operators](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.26.2)：复合赋值包含隐式转换的规则。
- [Java Language Specification 25, §15.17.2 Division Operator](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.17.2)：整数除法向零截断、除零与最小值边界。
- [Java Language Specification 25, §15.17.3 Remainder Operator](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.17.3)：余数的符号、范围和重组关系。
- [Java Language Specification 25, §15.23 Conditional-And Operator](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.23) 与 [§15.24 Conditional-Or Operator](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.24)：`&&`、`||` 的短路求值。
- [Java SE 25 API, `Math.multiplyExact(int, int)`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Math.html#multiplyExact(int,int))：`int` 乘法溢出时抛出 `ArithmeticException` 的契约。

阅读官方规范时不要求一次看懂全部形式化措辞。先用本章正例建立可观察现象，再回官方条款确认边界；遇到博客与实际输出冲突时，以当前 JDK 25 的官方规范、API 契约和可重复实验为准。
