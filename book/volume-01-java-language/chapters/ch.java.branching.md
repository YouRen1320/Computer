---
schema_version: 2
edition: 2026.2-draft
id: ch.java.branching
title: 布尔逻辑、if/else 与 switch
responsibility: 教授互斥条件选择和穷尽分支，不在本章教授重复执行或异常流程
volume: '01'
order: 5
level: L1
status: drafting
path: book/volume-01-java-language/chapters/ch.java.branching.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java.expressions-conversions
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
  text: 在 120 秒内解释布尔逻辑、if/else 与 switch的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-boolean-branch
  - java-switch
  covers_topics:
  - java.boolean-logic
  - java.if-else
  - java.guard-clause
  - java.switch-statement-expression
  - java.exhaustive-branch
  - java.fallthrough-boundary
  uses_capabilities:
  - java.values-types-string
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现工单优先级规则：非法值拒绝、多个互斥区间用 if/else、有限状态用穷尽 switch 返回结果
  covers_topic_groups:
  - java-boolean-branch
  - java-switch
  covers_topics:
  - java.boolean-logic
  - java.if-else
  - java.guard-clause
  - java.switch-statement-expression
  - java.exhaustive-branch
  - java.fallthrough-boundary
  uses_capabilities:
  - java.values-types-string
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入遗漏边界、条件顺序遮蔽和 switch 漏分支，使用具体输入定位未覆盖路径并修复
  covers_topic_groups:
  - java-boolean-branch
  - java-switch
  covers_topics:
  - java.boolean-logic
  - java.if-else
  - java.guard-clause
  - java.switch-statement-expression
  - java.exhaustive-branch
  - java.fallthrough-boundary
  uses_capabilities:
  - java.values-types-string
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 布尔逻辑、if/else 与 switch

> 本章状态为 `drafting`。正文、正例、实验和公开练习可用于试读与技术验证，但尚未代表学习者已经完成本章，也不能自动推进 `PROGRESS.md`。

程序如果只能从上到下无条件执行，就不能根据工单优先级决定先后、不能拒绝非法输入，也不能按工单状态选择下一步动作。**分支**让程序在某个时刻根据条件只选择一条路径继续执行。选择的依据是布尔值，选择的结构主要是 `if/else` 与 `switch`。

本章把“条件写对”拆成四个可以检查的问题：输入范围有没有覆盖完整；各条规则是否互斥；规则顺序会不会遮蔽后面的路径；有限选项是否有明确的未知值策略。AI 可以很快生成十几个 `if`，但你必须能用具体边界证明每个输入会走哪条路。

本章只教授选择，不教授重复执行。示例会重复写少量代码，目的是让每个分支完整可见；循环、数组、集合、方法抽取、对象状态与异常处理均在后续章节展开。版本基线为 **JDK 25**，官方语言规范复核日期为 **2026-07-16**。

## 1. 学完后必须留下什么证据

“看懂 if”不是可验证结果。完整学习应留下三类证据：

1. **解释证据**：在 120 秒内说清布尔表达式、互斥、穷尽、分支顺序、guard clause、switch 表达式和 fallthrough；至少给出一个边界错误或编译失败反例。
2. **构建证据**：从固定输入实现 FactoryCare 优先级路由。0 和 6 被拒绝，1..2 为常规，3..4 为高，5 为紧急；有限状态用 switch 选择动作。
3. **诊断证据**：先预测并注入三类故障——把 `< 1` 写成 `< 0`、把大区间放在小区间前、删除 switch 的兜底分支——再根据输出或 `javac` 日志做最小修复和复跑。

配套工件：

- [分支选择观察台](../../../examples/encyclopedia/ch.java.branching/README.md)
- [FactoryCare 工单优先级与状态路由实验](../../../labs/encyclopedia/ch.java.branching/README.md)
- [公开独立练习：工单分级与状态动作](../../../exercises/encyclopedia/ch.java.branching/README.md)

公开练习不含答案。先保存第一次预测和实际输出，再在需要时由老师模式核对；不要让 AI 把私有解析复制到公开目录。

## 2. 前置自检：先会产生布尔值

分支不会替你计算业务事实，它只读取一个结果为 `true` 或 `false` 的表达式。因此开始前应能预测这些表达式：

```java
int priority = 3;

System.out.println(priority >= 1);               // true
System.out.println(priority <= 5);               // true
System.out.println(priority >= 1 && priority <= 5); // true
System.out.println(priority < 1 || priority > 5);   // false
System.out.println(!(priority == 3));             // false
```

逐行解释时不要说“差不多满足”。应说：比较运算先产生两个布尔值，`&&` 要求左右都为真，`||` 只要求至少一侧为真，`!` 把紧随其后的布尔值取反。运算优先级在上一章已经学过；业务代码中仍建议用括号突出区间意图。

若你还不能预测整数比较、`&&`、`||`、`!` 或短路行为，先回到“运算符、表达式、类型转换”章节。这里不会重新讲数值提升和求值顺序。

## 3. 控制流不是“代码有没有写”，而是“这次走了哪条路径”

**控制流**是语句实际执行的先后路径。普通语句按书写顺序执行；条件语句遇到布尔条件后，只执行对应代码块，再从整个条件结构后继续。没有被选中的代码仍存在于源文件中，但本次运行不会执行。

```java
int priority = 5;

System.out.println("before");
if (priority == 5) {
    System.out.println("critical");
}
System.out.println("after");
```

固定输入 5 的路径是 `before → critical → after`。输入 3 的路径是 `before → after`。画路径时，菱形代表条件，分叉边分别标注 true 和 false，汇合后才执行 `after`。这种图不是装饰：遇到“某行为什么没执行”时，它迫使你指出是哪一个条件把路径导向另一边。

每个条件都应至少准备一组使它为真的输入和一组使它为假的输入。只跑“正常输入”无法证明 false 路径正确。

## 4. 布尔逻辑：先把自然语言翻成集合

条件错误通常不是 Java 语法错，而是自然语言边界翻译错。先写集合，再写表达式。

FactoryCare 规定合法优先级为闭区间 1..5：

```text
合法：priority >= 1 并且 priority <= 5
非法：priority < 1 或者 priority > 5
```

对应代码：

```java
boolean valid = priority >= 1 && priority <= 5;
boolean invalid = priority < 1 || priority > 5;
```

这两个表达式互为否定。根据德摩根关系，`!(A && B)` 等价于 `!A || !B`；因此 `!(priority >= 1 && priority <= 5)` 可整理成 `priority < 1 || priority > 5`。零基础阶段不要求背符号定律，但应能用边界表验证：

| `priority` | `>= 1` | `<= 5` | 合法 `&&` | 非法 `<1 || >5` |
| ---: | --- | --- | --- | --- |
| 0 | false | true | false | true |
| 1 | true | true | true | false |
| 3 | true | true | true | false |
| 5 | true | true | true | false |
| 6 | true | false | false | true |

最小值前一个、最小值、区间内部、最大值、最大值后一个，构成最基本的五点边界。把 `<` 写成 `<=`，往往只会让一个边界输入错；没有边界表就很难发现。

### 4.1 短路不仅是性能，也是安全边界

```java
int denominator = 0;
boolean result = denominator != 0 && 10 / denominator > 1;
```

左侧为 false，`&&` 已能确定整个结果为 false，右侧不会求值，因而没有除零。把 `&&` 写成 `&` 会强制求值两侧，运行时失败。条件从左到右安排时，通常先放便宜、必要且能保护右侧的检查。

但是短路不能替代完整校验。上例只说明右侧这次没有执行，不说明 0 是合法业务输入。程序仍需在合适分支明确拒绝非法值。

## 5. 单分支 if：条件为真才做一件事

基本形式：

```java
if (布尔表达式) {
    条件为 true 时执行的语句
}
```

例如只对紧急工单打印提示：

```java
int priority = 5;
if (priority == 5) {
    System.out.println("notify-on-call");
}
```

输入不是 5 时，整个代码块被跳过。这适合“可选附加动作”，不适合“无论如何都必须得到分类结果”。若后续代码依赖变量已经被赋值，只写单分支可能导致编译器报告局部变量未初始化：

```java
int priority = 3;
String route;
if (priority == 5) {
    route = "CRITICAL";
}
System.out.println(route); // 不是每条路径都赋值，编译失败
```

编译器不知道业务上“可能总是 5”；它检查所有可达路径。补一个真正合理的 `else`，或在声明时给出有语义的初始值，才能让赋值路径完整。不要为了消除红线随便写空字符串，那只是掩盖未建模的分支。

### 5.1 花括号是路径边界

Java 允许单条语句省略花括号，但教材和生产代码默认保留：

```java
if (priority == 5)
    System.out.println("critical");
    System.out.println("notify");
```

缩进会让人误以为两行都受条件控制，实际上只有第一行属于 `if`，第二行总会执行。编译器按语法，不按视觉缩进。统一写花括号可以让新增语句时不意外改变路径。

## 6. if/else：在两个互斥结果中二选一

```java
if (priority == 5) {
    route = "CRITICAL";
} else {
    route = "NOT_CRITICAL";
}
```

同一次执行只会进入一侧。条件为 true 时跳过 `else`，条件为 false 时跳过第一块。整个结构结束后，`route` 在两条路径上都有值。

二选一适合明确互补的规则，例如“合法/非法”“启用/停用”。如果 `else` 的含义只能说成“其他所有乱七八糟情况”，要警惕是否把未知输入误归为正常。下面的代码会把 -100 当作常规优先级：

```java
if (priority >= 3) {
    route = "HIGH";
} else {
    route = "ROUTINE";
}
```

问题不是 `else` 语法，而是进入分类前没有先处理合法范围。边界策略应先于正常分类。

## 7. else-if 链：从上到下选择第一条为真的规则

```java
if (priority < 1 || priority > 5) {
    route = "REJECTED";
} else if (priority == 5) {
    route = "CRITICAL";
} else if (priority >= 3) {
    route = "HIGH";
} else {
    route = "ROUTINE";
}
```

执行规则不是“把所有条件都算一遍”，而是从上往下检查，命中第一条后跳过剩余分支。因此顺序本身就是业务含义：

1. 先把 1..5 外的输入隔离；
2. 再处理最特殊的 5；
3. 再处理 3..4；
4. 最后剩下的合法值只能是 1..2。

若先写 `priority >= 3`，输入 5 会提前命中 `HIGH`，后面的 `priority == 5` 永远没有机会执行。这叫**条件遮蔽**。两条条件数学上可能同时为真，但 else-if 只取第一条。

用路径表复核：

| 输入 | 非法 | `==5` | `>=3` | 最终结果 |
| ---: | --- | --- | --- | --- |
| 0 | true | 不再求值 | 不再求值 | REJECTED |
| 1 | false | false | false | ROUTINE |
| 3 | false | false | true | HIGH |
| 4 | false | false | true | HIGH |
| 5 | false | true | 不再求值 | CRITICAL |
| 6 | true | 不再求值 | 不再求值 | REJECTED |

“不再求值”与 false 不同：后续条件根本没有执行。调试时在每个分支打印路径标签，比只看最终变量更容易发现遮蔽。

## 8. 互斥、穷尽与优先顺序

一个可靠分类器应回答：

- **互斥**：同一合法输入在业务定义上是否只属于一个类别？
- **穷尽**：每个允许输入是否都有明确结果？
- **非法策略**：范围外或未知值是拒绝、兜底还是继续？
- **优先顺序**：若条件有重叠，为什么先检查这一条？

else-if 的运行机制保证只执行一个分支，却不能自动保证业务规则互斥。例如 `priority >= 3` 与 `priority >= 5` 重叠，程序只是靠顺序决定结果。更清晰的规则可以写成不重叠区间：

```text
非法：小于 1 或大于 5
常规：1 到 2
高：3 到 4
紧急：等于 5
```

把规则先写成区间，再决定代码从特殊到一般还是从小到大。任何顺序都要能用边界表证明，而不是靠“看起来顺”。

## 9. guard clause：先挡住不满足前置条件的路径

guard clause（守卫子句）把非法、无需继续或无法处理的情况放在前面，满足时立即离开当前处理边界，让后面的主路径少一层缩进。

在已经熟悉的固定 `main` 外壳中，可以这样观察：

```java
int priority = 0;
if (priority < 1 || priority > 5) {
    System.out.println("REJECTED");
    return;
}

System.out.println("continue-routing");
```

这里 `return;` 结束当前 `void main` 的执行，所以非法输入不会到达后面的路由逻辑。本章只把它作为既有 `main` 中的早退出语句使用；方法声明、参数、返回值契约和多个 guard 的组织会在方法章节系统讲解。

守卫子句不是“所有 if 都要 return”。若两个分支都要在后面汇合，普通 `if/else` 更清晰。选择标准是：被挡住的路径是否真的不应继续，而不是为了少写一层花括号。

## 10. 嵌套条件：可表达，但先问能否展平

```java
if (valid) {
    if (priority == 5) {
        route = "CRITICAL";
    } else {
        route = "NON_CRITICAL";
    }
} else {
    route = "REJECTED";
}
```

嵌套表示第二个判断只有在第一个路径里才有意义。两层以内通常能读懂，层数继续增加时，读者必须同时记住多条外层条件。可以先用 guard 处理非法输入，再用扁平 else-if 分类；也可以保留嵌套，但给每层明确业务名称和路径输出。

不要为了追求“无嵌套”复制条件，也不要把所有条件塞进一个超长表达式。目标是让每条路径的前置条件可说、可测、可定位。

## 11. switch 适合“一个值对应有限标签”

else-if 擅长范围和任意布尔条件；`switch` 擅长同一个选择值与若干离散标签匹配。例如 FactoryCare 状态文本来自一组有限值：

```java
String status = "ASSIGNED";
String action;

switch (status) {
    case "CREATED":
        action = "WAIT";
        break;
    case "ASSIGNED":
    case "IN_PROGRESS":
        action = "WORK";
        break;
    case "CLOSED":
        action = "ARCHIVE";
        break;
    default:
        action = "REJECT_UNKNOWN";
}
```

这是传统 switch **语句**。选择器 `status` 只求值一次，然后寻找匹配的 `case` 标签。`ASSIGNED` 后没有语句，它与紧随其后的 `IN_PROGRESS` 共享 `WORK` 动作，这是有意合并标签。每个完成动作的分支都写 `break`，避免继续落入下一标签。

本章只用 `int` 与 `String` 作为选择器，暂不展开枚举、模式匹配和对象类型。不要为了使用 switch，把连续数值区间强行列出几十个 case；`priority >= 3 && priority <= 4` 仍更适合 if。

### 11.1 statement 与 expression 的区别

switch 语句执行动作；switch 表达式直接产生一个值：

```java
String action = switch (status) {
    case "CREATED" -> "WAIT";
    case "ASSIGNED", "IN_PROGRESS" -> "WORK";
    case "CLOSED" -> "ARCHIVE";
    default -> "REJECT_UNKNOWN";
};
```

观察三个语法边界：

1. 箭头右侧给出该标签对应的结果；
2. 多个标签用逗号合并，不需要空 case 穿透；
3. 整个赋值语句最后仍有分号。

表达式形式适合“给一个输入，得到一个分类值”。语句形式适合每个分支执行多条不同动作。若箭头分支需要代码块并产生值，Java 支持 `yield`，但本章不需要为了展示语法制造复杂分支；先掌握一行结果和穷尽性。

## 12. switch 的穷尽性：每个可能输入都必须有去处

switch 表达式必须对所有可能选择值给出结果，否则表达式在某条路径上没有值。对 `String` 这类开放取值，通常用 `default` 明确未知策略：

```java
String action = switch (status) {
    case "CREATED" -> "WAIT";
    case "CLOSED" -> "ARCHIVE";
    default -> "REJECT_UNKNOWN";
};
```

删除 `default` 后，JDK 25 的 `javac` 会在 compile 阶段报告 switch expression 没有覆盖所有可能输入。此时程序根本没有开始运行，所以不会出现 `Tests run` 或业务输出。第一可信证据是源文件位置和“does not cover all possible input values”一类编译消息。

`default` 不等于“把未知值当成功”。`REJECT_UNKNOWN` 是明确拒绝，调用者或后续逻辑仍能区分。若写 `default -> "WORK"`，新拼错的状态也会被悄悄当作可工作状态，穷尽了语法却破坏业务语义。

穷尽还包括需求层面：代码可能有 default 而编译成功，但漏掉一个新的合法状态，导致它落入拒绝分支。编译器只认识类型可能性，不认识你的业务清单；固定状态表和变更测试仍然必要。

## 13. fallthrough：传统冒号 case 会继续向下执行

传统 switch 语句中，匹配标签后会从那里继续执行，直到 `break`、`return`、整个 switch 结束或发生其他控制转移。省略 `break` 的行为叫 fallthrough（贯穿/穿透）：

```java
int stage = 1;
int transitions = 0;

switch (stage) {
    case 1:
        transitions++;
    case 2:
        transitions++;
        break;
    default:
        transitions = -1;
}
```

输入 1 会执行 case 1，再继续执行 case 2，因此结果是 2，不是 1。它通常能编译、退出码也是 0，是典型逻辑错误。实验中的 `FallthroughFailure` 用固定预言机把它转成非零证据，方便定位。

有意 fallthrough 可以合并多个标签，但必须让意图极其明显。现代代码优先使用逗号标签或箭头规则：

```java
case "ASSIGNED", "IN_PROGRESS" -> "WORK";
```

箭头规则不会隐式贯穿到下一条。不要机械地认为“switch 一定要 break”：箭头形式不写 break，冒号形式通常需要。先辨认使用的是哪种标签语法。

## 14. if 还是 switch：按问题形状选择

| 问题 | 更自然的结构 | 原因 |
| --- | --- | --- |
| 数值范围 1..2、3..4、5 | if/else-if | 条件是区间和不等式 |
| 同一个状态文本对应动作 | switch 表达式 | 标签有限、输出一一对应 |
| 先校验再进入主路径 | guard clause | 非法路径应立即停止 |
| 两个互补结果 | if/else | true/false 正好覆盖 |
| 每个分支做多条不同动作 | if 或 switch 语句 | 选择可读性更清晰者 |
| 条件依赖多个不同变量 | if | switch 主要围绕一个选择器 |

不要用“switch 比 if 高级”作为选择依据。二者生成的底层实现也不是本章决策标准；先让业务规则可读、互斥、穷尽、可验证。以后若状态改为 enum，switch 还能获得更强的编译期覆盖帮助，但 enum 属于对象章节。

## 15. FactoryCare 完整最小例：先校验，再分类，再选动作

下面的最小程序只使用已学的变量、表达式和分支：

```java
public class TicketDecision {
    public static void main(String[] args) {
        int priority = 5;
        String status = "ASSIGNED";

        if (priority < 1 || priority > 5) {
            System.out.println("priority=REJECTED");
            return;
        }

        String level;
        if (priority == 5) {
            level = "CRITICAL";
        } else if (priority >= 3) {
            level = "HIGH";
        } else {
            level = "ROUTINE";
        }

        String action = switch (status) {
            case "CREATED" -> "WAIT";
            case "ASSIGNED", "IN_PROGRESS" -> "WORK";
            case "CLOSED" -> "ARCHIVE";
            default -> "REJECT_UNKNOWN";
        };

        System.out.println("level=" + level);
        System.out.println("action=" + action);
    }
}
```

执行前依次回答：

1. guard 条件为 true 还是 false；
2. level 链检查了几次条件，命中哪一条；
3. switch 选择器的值是什么，哪个标签匹配；
4. 最终有几行标准输出；
5. 把 priority 改为 0 后，switch 是否执行。

正确答案不能只写 `CRITICAL/WORK`，还要说明路径：校验为 false，所以没有 return；`==5` 为 true，后续 else-if 不执行；`ASSIGNED` 匹配共享的 WORK 标签。输入 0 时在 guard 打印一行并结束，后面两个决策都不可达。

## 16. 边界设计：最小值、最大值、相邻值和未知值

分支测试应从规则边界推导，而不是随便挑几个“看起来不同”的数。对 1..5 分类，最小集合至少是：

```text
0：下界外
1：下界
2：第一段上界
3：第二段下界
4：第二段上界
5：特殊最大值
6：上界外
```

每一个值都有理由。若只测 1、3、5，`priority < 0` 的错误不会暴露；若只测 0 和 6，又不能证明合法区间分类正确。区间规则变化时，测试输入也要跟着边界移动。

状态 switch 至少测每个合法标签和一个未知标签。大小写、前后空格和空文本是否允许属于后续输入校验契约；本章不要擅自“自动纠正”。固定源码中的状态文本必须精确匹配 case 标签。

## 17. 三类常见故障与第一可信证据

### 17.1 遗漏边界

错误：

```java
if (priority < 0 || priority > 5) {
    route = "REJECTED";
}
```

输入 0 没有被拒绝。程序通常编译成功、退出 0；第一可信证据是 `priority.0` 的实际输出与边界表不同。修复 `< 0` 为 `< 1`，用同一组 0、1、5、6 复跑。

### 17.2 条件顺序遮蔽

错误：

```java
if (priority >= 3) {
    route = "HIGH";
} else if (priority == 5) {
    route = "CRITICAL";
}
```

输入 5 同时满足两个条件，但第一条先命中。第一可信证据是固定输入 5 得到 `HIGH`，而不是“IDE 没报红”。修复方式可以把特殊条件移到前面，也可以重新写成不重叠区间；修复后还要复跑 3 和 4，证明没有破坏原区间。

### 17.3 switch 不穷尽或意外贯穿

switch 表达式漏 `default` 是 compile 错误；传统 switch 漏 `break` 多为运行后的逻辑错误。两者都叫“漏分支”会混淆失败阶段：前者看 `javac` 文件位置，后者看具体输入的路径计数或输出差异。

诊断记录建议固定格式：

```text
预测：输入 5 会被宽条件提前命中，错误输出 HIGH。
注入：把 priority >= 3 放到 priority == 5 前。
命令：javac ... && java ...
实际：退出 0，priority.5=HIGH。
第一可信证据：固定输入 5 的实际分类与规则表不一致。
修复：特殊条件前置。
复跑：0/1/3/4/5/6 全部符合预言。
```

## 18. 日志诊断：打印路径标签，不泄露无关数据

学习程序可在每个分支打印简短标签：

```java
if (priority < 1 || priority > 5) {
    System.out.println("path=invalid");
} else if (priority == 5) {
    System.out.println("path=critical");
} else {
    System.out.println("path=normal");
}
```

标签应稳定、可搜索、能与规则对应。只打印“进来了”缺少语义；把整个用户输入、token 或隐私数据全部输出又会制造安全风险。真实系统以后使用结构化日志，本章先掌握最小原则：记录输入边界所需的脱敏值、命中规则和最终结果，不把日志本身当业务正确证明。

若输出错，按顺序检查：输入实际值、guard 条件、分支顺序、比较符号、最终赋值。不要一上来重写所有条件；一次改一处，保留原输入复跑，才能建立因果关系。

## 19. 实验闭环

进入[工单优先级与状态路由实验](../../../labs/encyclopedia/ch.java.branching/README.md)，按五步执行。

### 19.1 预测

先写出 1、3、5、0、6 与 `ASSIGNED` 的预期，不运行脚本。再预测故意 fallthrough 的 `transitions` 是 1 还是 2。

### 19.2 运行

```bash
cd labs/encyclopedia/ch.java.branching
./verify.sh
```

有效证据应包含六行正常输出、`assertions=9 passed`、一个非零预期失败和最终 `LAB PASS`。只有最后一行而没有前面的案例明细，不足以证明边界都执行过。

### 19.3 修改

任选一项：把 HIGH 下界从 3 改为 4；把最大合法值改为 6；把 `CREATED` 动作改为 `TRIAGE`。修改前列出受影响输入，运行后核对，再恢复。

### 19.4 破坏与修复

把 `priority == 5` 移到 `priority >= 3` 后，或临时移除传统 case 的 break。先预测故障类型是 compile、非零运行还是退出 0 的逻辑错误，再运行固定预言机。恢复后必须复跑完整脚本。

## 20. 公开独立练习与无 AI 训练

进入[公开练习](../../../exercises/encyclopedia/ch.java.branching/README.md)。关闭 AI，限时 25 分钟。公开起始代码故意含三类规则错误，但可以编译和结束；你的任务是从输出和边界表定位，而不是让工具整文件重写。

提交证据包括：

- 修复前对五行输出的预测；
- 修复前实际输出；
- 三类最小修改及理由；
- 修复后精确五行输出；
- 把最大合法值改为 6 时的影响清单；
- 60 秒口述“为什么编译成功不能证明分支正确”。

卡住时只允许查本章速查表和 `javac/java` 输出，不看私有答案。完成第一次尝试后，可以让 AI 充当审查者：要求它指出未覆盖边界和重叠条件，但你必须逐条用输入验证，不能把模型评价当测试结果。

## 21. AI 协作时的审查问题

让 AI 写分支代码前，给它规则表而不是一句模糊需求。拿到代码后逐项问：

1. 合法输入集合是什么，区间端点是否包含？
2. 哪些条件可能同时为真，顺序为什么正确？
3. 每个合法输入是否恰好有一个结果？
4. 未知状态如何处理，是否被误当成功？
5. 哪个条件保护右侧危险表达式，是否真的短路？
6. switch 使用冒号还是箭头，是否存在 fallthrough？
7. 边界变化时需要同步改哪些测试？

一次可靠修改应由“规则差异 → 受影响路径 → 新边界用例 → 代码最小变更 → 复跑证据”组成。只说“请优化 if”会诱导无关重构，也无法验收。

## 22. 120 秒复述模板

按因果关系复述，不背代码：

> 分支读取布尔条件并改变本次执行路径。比较、&&、|| 和 ! 产生或组合布尔值，&& 与 || 会短路。单 if 适合可选动作，if/else 处理互补结果，else-if 从上到下只选择第一条为真的规则，因此区间必须覆盖完整，重叠条件的顺序必须有理由。非法输入可以先由 guard clause 阻断。switch 适合同一个值的有限标签：传统冒号形式可能 fallthrough，通常需要 break；箭头规则不隐式贯穿。switch 表达式必须穷尽，对 String 常用 default 明确拒绝未知值。编译成功只能证明语法和部分路径赋值合法，不能证明边界和业务分类正确，所以要用最小值前后、区间端点和未知值验证。

再补一个反例，例如“把 `>=3` 放在 `==5` 前，输入 5 被遮蔽为 HIGH”，并说明第一可信证据是固定输入输出差异。

## 23. 自测题

1. `priority >= 1 && priority <= 5` 在 0、1、5、6 时分别是什么？
2. 写出上式的否定形式，为什么中间使用 `||`？
3. `false && 10 / 0 > 1` 是否运行失败？换成 `&` 呢？
4. 单 if 与 if/else 的路径数量和赋值完整性有什么区别？
5. 为什么 `priority >= 3` 写在 `priority == 5` 前会遮蔽后者？
6. “else 保证输入合法”这句话为什么错？
7. guard clause 适合什么路径？本章中的 `return;` 做了什么？
8. 连续区间分类为什么通常用 if，而离散状态通常适合 switch？
9. switch 语句和 switch 表达式的主要区别是什么？
10. 冒号 case 忘写 break 可能出现什么现象？箭头 case 呢？
11. String switch 表达式删除 default 为什么在编译阶段失败？
12. 有 default 是否就证明业务状态完整？
13. 测试 1..5 分类时，为什么至少还要测 0 和 6？
14. 退出码 0 但分类错误属于哪类证据问题？
15. 若业务把最大优先级改为 6，你会先改代码还是先列边界？为什么？

每题都应给具体输入或最小代码证据。只背“if 是判断”不能通过。

## 24. 间隔复习

| 时间 | 任务 | 通过证据 |
| --- | --- | --- |
| 当天 | 运行观察台、实验和公开练习 | 正常输出、编译失败、fallthrough 非零证据齐全 |
| 第 1 天 | 不看书画 1..5 分类路径 | 能标 true/false、端点和命中顺序 |
| 第 3 天 | 从空文件重写优先级链和状态 switch | 0/1/3/5/6 与未知状态全符合预言 |
| 第 7 天 | 注入 `<0`、条件遮蔽和漏 break | 能区分 compile、运行失败和逻辑错误 |
| 第 14 天 | 审查一段 AI 生成路由代码 | 列出互斥、穷尽、未知策略和测试缺口 |
| 第 30 天 | 在后续项目找到真实分支 | 写出规则表、边界值和变更影响 |

## 25. 速查表

### 25.1 选择结构

```text
可选附加动作            -> if
互补二选一              -> if/else
有顺序的范围分类        -> if/else-if/else
非法路径先停止          -> guard clause
同一值的有限离散标签    -> switch
需要直接得到分类值      -> switch expression
```

### 25.2 分支检查清单

```text
输入的合法集合是什么？
端点包含还是不包含？
每条条件在哪些输入下为真？
条件是否重叠，顺序是否遮蔽？
合法输入是否全部覆盖？
非法或未知输入如何处理？
短路是否保护了右侧？
传统 switch 是否可能 fallthrough？
每条路径上的局部变量都赋值了吗？
固定边界输入和预期输出是什么？
```

### 25.3 现象到首查位置

| 现象 | 首先检查 |
| --- | --- |
| 0 被当成合法 | 下界比较是否写成 `< 0` 而非 `< 1` |
| 5 被分成 HIGH | 宽条件是否遮蔽特殊条件 |
| 后一个 case 也执行 | 冒号形式是否遗漏 break |
| switch 表达式编译失败 | 是否缺少合法标签或 default |
| 局部变量可能未初始化 | 是否存在未赋值路径 |
| 除零仍发生 | 是否误用 `&`，或保护条件顺序错误 |
| 未知状态被当正常 | default 的业务语义是否过宽 |

## 26. 术语、边界与官方来源

| 术语 | 本章含义 |
| --- | --- |
| 布尔表达式 | 求值结果为 `true` 或 `false` 的表达式 |
| 控制流 | 一次运行中语句实际执行的先后路径 |
| 分支 | 根据条件在若干路径中选择 |
| 互斥 | 同一输入按业务定义不应同时属于多个结果 |
| 穷尽 | 允许的每个输入都有明确路径或结果 |
| 遮蔽 | 前面的宽条件先命中，使后面的特殊条件无机会执行 |
| guard clause | 在主路径前检查前置条件并让不合格路径提前离开 |
| switch statement | 依据标签执行语句的选择结构 |
| switch expression | 依据标签产生一个值的表达式 |
| fallthrough | 冒号 case 完成后继续执行后续 case 内容 |
| 边界值 | 位于区间端点或紧邻端点、最能暴露比较符错误的输入 |

本章有意不展开循环、数组、集合、方法抽取、递归、enum、sealed class、switch 模式匹配、`null` 策略、异常捕获和完整状态机。String 的对象身份与内容相等也在后续引用章节讲解；本章用 switch 标签规避混淆。这些是责任边界，不是遗漏。

JDK 25 官方来源，复核日期 **2026-07-16**：

- [Java Language Specification 25, §14.9 The `if` Statement](https://docs.oracle.com/javase/specs/jls/se25/html/jls-14.html#jls-14.9)：if、if-then-else 与最近 if 匹配规则。
- [Java Language Specification 25, §14.11 The `switch` Statement](https://docs.oracle.com/javase/specs/jls/se25/html/jls-14.html#jls-14.11)：switch 标签、规则、语句组、兼容类型与运行语义。
- [Java Language Specification 25, §15.28 `switch` Expressions](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.28)：switch 表达式的求值、穷尽性与结果产生。
- [Java Language Specification 25, §15.23 Conditional-And](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.23) 与 [§15.24 Conditional-Or](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.24)：`&&`、`||` 的布尔与短路语义。
- [Java Language Specification 25, §14.17 The `return` Statement](https://docs.oracle.com/javase/specs/jls/se25/html/jls-14.html#jls-14.17)：本章 guard 示例中 `return;` 的控制转移边界。

阅读规范时先定位标题和最小示例，再回实验复现。若博客、AI 回答与当前 JDK 25 实际行为冲突，以官方规范、固定输入和可重复命令为准。
