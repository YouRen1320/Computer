---
schema_version: 2
edition: 2026.2-draft
id: ch.java-oop.final-immutability
title: final、常量与不可变对象
responsibility: 教授引用不可重新赋值与对象不可变性的区别，不提前使用集合防御性复制
volume: '02'
order: 6
level: L1
status: drafting
path: book/volume-02-java-objects/chapters/ch.java-oop.final-immutability.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-oop.encapsulation-packages
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
  text: 在 120 秒内解释final、常量与不可变对象的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-final
  - java-immutability
  covers_topics:
  - java.final-variable-field
  - java.compile-time-constant
  - java.final-reference
  - java.immutable-object
  - java.defensive-value-boundary
  - java.thread-safety-benefit
  uses_capabilities:
  - java.references-objects
  - java.encapsulation-immutability
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：以private字段/包边界维护Money不变量，字段final、构造校验、操作返回新对象，并演示final引用与对象可变性区别，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - java-final
  - java-immutability
  covers_topics:
  - java.final-variable-field
  - java.compile-time-constant
  - java.final-reference
  - java.immutable-object
  - java.defensive-value-boundary
  - java.thread-safety-benefit
  uses_capabilities:
  - java.references-objects
  - java.encapsulation-immutability
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入public字段绕过不变量、getter泄露可变内部值和误认为final集合不可变，封装后验证旧对象未变化，并把异常定位到第一处可信证据
  covers_topic_groups:
  - java-final
  - java-immutability
  covers_topics:
  - java.final-variable-field
  - java.compile-time-constant
  - java.final-reference
  - java.immutable-object
  - java.defensive-value-boundary
  - java.thread-safety-benefit
  uses_capabilities:
  - java.references-objects
  - java.encapsulation-immutability
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# final、常量与不可变对象

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《封装、访问控制与包边界》](ch.java-oop.encapsulation-packages.md)：独立完成final 与常量、不可变对象前，必须先具备「封装、访问控制与包边界」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文和验证工件提供学习环境，不代表学习者已经完成无 AI 构建、诊断或复述，也不会自动改动 **PROGRESS.md**。

`final` 是 Java 初学阶段最容易被一句“不能改”误导的关键字。它约束的是某个**变量槽位只能完成一次赋值**：基本类型变量不能再换数值，引用变量不能再指向另一个对象；但引用当前指向的对象仍可能发生内部变化。真正的**不可变对象**要求对象构造完成后，从任何公开可达路径都不能观察到其逻辑状态变化，这需要封装、构造校验、字段设计和防御性复制共同保证，单独加 final 不够。

本章以 FactoryCare 的金额值 `Money` 和维护时间槽数组为例，逐层区分 final 局部变量、final 字段、类级常量、final 引用和不可变对象；只用数组演示防御性复制，不提前进入集合 API。`record` 只作为后续可选语法定位，不在本章教授其完整契约。线程安全只解释不可变值为何减少共享写入，不提前讲线程、锁或 Java 内存模型。基线为 **JDK 25**，一手资料复核日期为 **2026-07-16**。

## 1. 本章完成证据

1. **解释证据**：120 秒内说明 final 约束变量而非自动冻结对象；区分常量与普通 `static final` 引用；给出一个 final 数组仍可改元素的反例。
2. **构建证据**：实现跨包可调用的不可变 `Money`；字段 private final，构造器拒绝非法金额和币种，相加返回新对象，原对象不变；再用数组输入输出复制证明边界无别名泄漏。
3. **诊断证据**：复现 final 变量重新赋值的编译错误、可变字段让旧金额被修改的运行失败、数组 getter 泄漏内部状态的运行失败；根据第一处可信证据修复并复跑。

配套工件：

- [final 与不可变性观察台](../../../examples/encyclopedia/ch.java-oop.final-immutability/README.md)
- [FactoryCare Money 实验](../../../labs/encyclopedia/ch.java-oop.final-immutability/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-oop.final-immutability/README.md)

私有答案不得进入公开教材与练习目录。验证器里的预期编译/运行失败必须真实发生；删除失败源码、吞掉异常或只打印 `PASS` 都不构成证据。

## 2. 从变量槽位开始理解 final

把变量想成带标签的槽位。普通变量允许先放一个值，再换另一个值；final 变量完成赋值后，槽位与该值的绑定不能改变：

~~~java
final int maxRetry = 3;
maxRetry = 4; // 编译失败
~~~

对于基本类型，槽位里就是语言值，因此看起来像“数值不能改”。对于引用类型，槽位里是对象引用；不能改变的是引用绑定，不是对象内部所有字段：

~~~java
final int[] windows = {8, 10};
windows[0] = 9;          // 可以：仍是同一个数组对象
windows = new int[]{9};  // 编译失败：引用槽位试图指向新数组
~~~

这两行是本章核心分界。若只能背“final 就不能改”，你会错误地把 final 数组、可变 DTO 或集合当成不可变值。

## 3. final 局部变量

局部变量可在声明时赋值：

~~~java
final String workOrderId = "WO-1001";
~~~

也可先声明，在控制流能够证明恰好完成一次赋值的位置赋值：

~~~java
final String priority;
if (urgent) {
    priority = "URGENT";
} else {
    priority = "NORMAL";
}
~~~

编译器执行明确赋值分析：每条正常到达后续使用点的路径都必须完成赋值，并且不能再次赋值。不是按运行时碰巧走哪条路径判断，而是对控制流做静态检查。若某个分支漏赋值，后续读取会编译失败；若两个可能执行的语句都赋值，也会失败。

final 局部变量适合表达“确定后不再变化”的中间结果，减少后续误改。不要给每一行机械加 final 来制造仪式感；团队风格可以不同，关键是能解释这次约束保护了什么。

## 4. 有效 final 的定位

有些局部变量没有写 `final`，但初始化后从未重新赋值，语言在部分场景会把它视为“有效 final”。例如以后学习 lambda 捕获时会遇到。此处只认识名称：

~~~java
String site = "NC";
// 后面没有 site = ...，它可能满足 effectively final。
~~~

有效 final 不等于变量声明带有 final，也不等于引用对象不可变。本章不借 lambda 展开规则，避免用尚未学习的语法解释基础概念。

## 5. final 字段与构造完成

实例 final 字段每个对象各有一份，必须在字段初始化器或每条构造器正常完成路径中完成赋值：

~~~java
public final class Money {
    private final long cents;
    private final String currency;

    public Money(long cents, String currency) {
        this.cents = cents;
        this.currency = currency;
    }
}
~~~

构造器返回后不能再给这些字段赋新值。若某个构造分支忘记给 `currency` 赋值，编译器会阻止；若在普通方法里再写 `this.cents = ...`，也会编译失败。这给对象状态建立了一层结构性约束。

但 final 字段仍可能指向可变对象。若 `private final int[] slots` 直接保存调用者传来的数组，调用者可以通过原引用修改数组，Money 外壳上的 final 并不能阻止。

## 6. 空白 final 与默认值误解

未在声明处初始化的 final 字段常称“空白 final”。普通字段有默认值，不代表 final 字段可以依赖默认值后永远不赋。构造器必须完成明确赋值：

~~~java
final class DeviceCode {
    private final String value;

    DeviceCode(String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("value must have text");
        }
        this.value = value;
    }
}
~~~

先校验参数，再写 final 字段。不要先写入非法值再期待 setter 修正，因为不可变对象不应有修正入口；构造失败就不产生可用对象。

## 7. final 参数能保护什么

方法参数也可以声明 final：

~~~java
static String normalize(final String raw) {
    return raw.trim().toUpperCase();
}
~~~

这只禁止在方法体里让参数变量重新指向另一个对象，并不改变调用者对象，也不会让参数对象变不可变。团队可把它作为防误赋值风格，但业务边界仍需靠类型和复制。不要看到 `final int[] source` 就误以为方法不能执行 `source[0] = 0`。

## 8. static final 与常量变量

常见类级固定值：

~~~java
private static final String DEFAULT_CURRENCY = "CNY";
private static final long MAX_CENTS = 100_000_000L;
~~~

`static` 表示类级归属，`final` 表示字段只赋值一次。JLS 中更严格的“常量变量”还要求变量是基本类型或 String、带 final，并用常量表达式初始化。它的值可能在调用方编译时内联。

因此下面虽是 `static final`，却不应称为不可变常量对象：

~~~java
static final int[] DEFAULT_WINDOWS = {8, 10};
~~~

数组元素仍可修改，若字段公开，任何调用者都能改变所有人观察的“默认值”。正确选择可能是每次返回新数组、只暴露查询方法，或使用真正不可变表示；集合方案留到集合章节。

## 9. 编译期常量的版本边界

公开编译期常量可能被另一个已编译类内联。若库把 `MAX_RETRY` 从三改成四，只替换库的 class 文件、却不重新编译调用方，旧调用方可能仍使用三。因此：

- public 常量是 API 决策，不只是少写一个数字；
- 会变化的部署配置不应作为编译期常量；
- 数据库地址、租户开关或超时配置不能靠改常量热更新；
- 验证版本变化时要明确哪些模块被重新编译。

本章不进入二进制兼容性全套规则，只要能解释“源码看见新值不证明旧 class 已使用新值”。

## 10. 不可变对象的可观察契约

一个对象在构造完成后，如果调用者不能通过其公开可达路径观察到逻辑状态变化，才可称为不可变。常见设计条件：

1. 状态字段 private，避免外部直接写；
2. 字段在构造期间完成校验；
3. 字段通常 final，防止类内后续重新赋值；
4. 不提供修改状态的 setter 或命令；
5. “变化”操作返回新对象；
6. 对可变输入做防御性复制；
7. 对可变输出不泄露内部引用；
8. 字段引用的对象本身不可变，或边界通过复制隔离。

“所有字段 final”是常用组成，不是充分条件；“没有 setter”也不充分，因为 getter 可能返回可变内部数组，或类内方法直接修改数组元素。

## 11. 不可变 Money：构造时守住不变量

~~~java
package com.factorycare.money.domain;

public final class Money {
    private final long cents;
    private final String currency;

    public Money(long cents, String currency) {
        if (cents < 0) {
            throw new IllegalArgumentException("cents must not be negative");
        }
        if (currency == null || currency.isBlank()) {
            throw new IllegalArgumentException("currency must have text");
        }
        this.cents = cents;
        this.currency = currency;
    }
}
~~~

字段 private，包外只能走公开行为；final 在构造后禁止重新赋值；构造器拒绝负金额和空币种。`String` 本身是不可变值，因此保存经过验证的字符串引用不会让调用者从外部改其字符。

这里把 Money 类声明为 final，用于表达暂不允许通过子类改变契约；完整的 final 类、继承和多态取舍在后续继承章处理。本章验收重点仍是字段、引用与对象状态。

## 12. 变化返回新对象

~~~java
public Money plus(Money other) {
    if (!currency.equals(other.currency)) {
        throw new IllegalArgumentException("currency mismatch");
    }
    return new Money(Math.addExact(cents, other.cents), currency);
}
~~~

`plus` 不写 `this.cents`，而是返回新 Money。给定五千分与七百五十分，结果是五千七百五十分；两个输入仍保持原值。调用者必须接住返回值：

~~~java
Money total = base.plus(fee);
~~~

只写 `base.plus(fee);` 会丢弃新对象，并不会让 base 自动变化。前端开发者可暂时类比字符串的 `toUpperCase()` 返回新字符串，而不是原地改字符串。

`Math.addExact` 让 long 溢出以异常显式暴露，而不是静默绕回负数。异常契约将在后续专章深化，本章只要求看到第一处业务可信证据。

## 13. 查询方法不会自动破坏不可变性

返回基本类型或不可变字符串通常安全：

~~~java
public long cents() {
    return cents;
}

public String currency() {
    return currency;
}
~~~

调用者得到 long 的值副本，得到 String 引用也不能修改 String 对象。问题出现在返回可变对象的内部引用。不能机械地认为“有 getter 就可变”或“没有 setter 就不可变”；必须检查返回类型及其可达对象图。

## 14. 防御性复制：输入边界

假设维护计划保存两个小时槽：

~~~java
public final class MaintenanceWindow {
    private final int[] hours;

    public MaintenanceWindow(int[] hours) {
        if (hours == null || hours.length == 0) {
            throw new IllegalArgumentException("hours must not be empty");
        }
        this.hours = hours.clone();
    }
}
~~~

若直接写 `this.hours = hours`，调用者仍持有同一数组。构造后执行 `source[0] = 23`，对象内部也随之变化。`clone()` 在这里创建新的 int 数组，切断输入别名。

复制不是校验替代品。仍需验证每个小时是否在零到二十三范围，是否允许重复、顺序是否有意义。复制解决“谁能修改同一个对象”，校验解决“哪些值合法”。

## 15. 防御性复制：输出边界

即使构造时复制，getter 若直接返回内部数组仍会泄漏：

~~~java
public int[] hours() {
    return hours; // 错误：调用者得到内部数组
}
~~~

应返回副本：

~~~java
public int[] hours() {
    return hours.clone();
}
~~~

输入复制保护对象不受调用者原数组后续变化影响；输出复制保护对象不受 getter 返回值变化影响。缺任意一边都会留下入口。实验应分别修改原输入和查询结果，之后再次读取内部值，证明两条路径都被隔离。

本章只用原始类型数组。`List.copyOf`、不可修改视图与集合元素深层可变性留到集合章节，避免在尚未学习 List 时堆 API 名称。

## 16. 浅不可变与深不可变

若对象字段本身不能重新赋值，但字段引用的子对象可以变化，通常只能说外层引用稳定，不能轻率宣称整个对象图深度不可变。

~~~java
final class Holder {
    private final MutableDevice device;
}
~~~

`device` 引用不能换，但 `MutableDevice` 的状态仍可能通过别处引用改变。**浅不可变**强调外层直接字段绑定不变；**深不可变**要求从对象可达的整个状态图都不发生可观察变化，或所有可变部分被复制隔离且不泄露。

对 `int[]`，`clone()` 足以复制所有元素，因为元素是基本类型值。对 `Device[]`，数组复制只复制每个 Device 引用；两个数组仍指向同一批可变 Device。这就是浅复制。深复制需要明确定义每个元素如何复制，不是多写一个 `clone()` 就完成。

## 17. final 引用的经典反例

~~~java
final MutableCounter counter = new MutableCounter();
counter.increment(); // 合法，对象内部改变
~~~

变量 `counter` 不能改指向另一个计数器，但当前计数器可以增长。把它放进 `private static final` 只会形成“永不换引用的全局可变对象”，并不会变安全。上一章的共享状态风险与本章的 final 区别在这里相遇。

解释时用完整句子：“引用绑定不可重新赋值；被引用对象是否可变由该对象的公开行为和可达内部状态决定。”这比说“final 对象”准确，因为 final 修饰变量、字段、参数、方法或类，不是给任意运行时对象贴冻结标签。

## 18. String 为什么适合作为不可变字段

Java API 将 String 描述为不可变字符序列。诸如 `trim`、`substring`、`toUpperCase` 返回 String 结果，不让调用者原地改字符。因此不可变 Money 保存 `private final String currency` 时，在完成 null/空白和格式校验后，不必复制 String。

这不表示所有标准库类型都不可变。使用陌生类型前查看官方 API：它是否有修改方法，是否返回内部可变视图，文档是否承诺不可变。不要根据类名、final 字段数量或 IDE 图标猜。

## 19. record 只做定位

`record` 能用紧凑语法声明一组组件，并自动提供若干成员；record 类隐式 final。但“record”不保证组件引用的对象深度不可变：若组件是数组，访问器仍涉及可变数组引用。构造校验、复制和领域不变量依然需要设计。

本章不要把 Money 改成 record 来跳过基本训练。后续 `enum、record、sealed` 章节会完整讨论规范构造器、访问器、相等契约和适用边界。现在先用普通类看清每个字段和每条复制路径。

## 20. 不可变性带来的收益与成本

收益：

- 状态不会在远处悄悄改变，推理范围更小；
- 值可安全复用，测试不需要为每个操作重置对象；
- 失败前后的输入值稳定，日志与重放更可信；
- 在未来并发共享中减少写入冲突，但这不是本章的并发证明；
- API 倾向显式返回新结果，副作用更可见。

成本：

- 每次变化可能创建新对象；
- 大型可变数据的复制有时间和空间成本；
- 深层对象图的不可变设计更复杂；
- 某些实体确实有生命周期状态，不应被强行伪装成值；
- 需要调用者正确接住返回的新对象。

不可变不是所有类的唯一答案。Money、设备编码、坐标、时间点适合值语义；工单实体会经历状态迁移，可能由受控可变行为表达。选择取决于领域身份和变化含义。

## 21. 线程安全收益只做边界定位

不可变对象构造后没有状态写入，多个调用者读取同一逻辑值时少了一类竞争问题。因此教材规范把“线程安全收益”列为本章主题之一。但不能据此宣称：

- 任意含 final 字段的对象都线程安全；
- 不可变对象所在的整个服务都线程安全；
- 外部可变依赖、缓存或集合自动安全；
- final 等于锁或原子性工具。

JLS 对 final 字段在线程间可见性有专门语义，正确构造和对象发布也很重要。完整模型留到并发与 JMM 章节。本章只掌握设计直觉：消除后续写入能显著缩小并发推理范围。

## 22. FactoryCare 场景：金额、时间槽与实体状态

FactoryCare 维修报价中的 `Money` 应保持金额和币种不变量。加价返回新 Money，原报价值可留作审计对照。币种不同应拒绝相加；负金额和 long 溢出不能静默进入对象。

维护时间槽若由 `int[]` 表示，构造和查询都要复制，避免 UI 或导入器保留数组引用后篡改计划。实际系统以后可能换集合或专门值类型，本章先证明边界原理。

工单 `WorkOrder` 则有 CREATED、ASSIGNED、IN_PROGRESS 等生命周期状态。它不因“不可变很好”就必须每次状态变化复制整个聚合；可以继续由封装行为维护受控状态。区分值对象与有身份实体，是比全字段 final 更重要的领域判断。

## 23. 正例、边界例和失败例

| 类别 | 输入或操作 | 预期 |
| --- | --- | --- |
| 正例 | `Money(5000,"CNY") + Money(750,"CNY")` | 新值 5750，输入保持 5000/750 |
| 正例 | 修改构造后原 int 数组 | 对象查询不变 |
| 正例 | 修改 getter 返回数组 | 后续查询不变 |
| 边界 | 金额为零 | 按当前契约合法 |
| 边界 | 金额为负 | 构造时拒绝 |
| 边界 | 币种不同 | 相加时拒绝 |
| 边界 | long 溢出 | `Math.addExact` 抛异常 |
| 失败 | final 局部变量重新赋值 | javac 编译失败 |
| 失败 | plus 原地修改 public cents | 原对象变化，断言失败 |
| 失败 | getter 返回内部数组 | 外部修改穿透边界 |

每个失败都要标注阶段。编译失败没有 `Tests run`；运行断言失败说明源码已编译；异常的第一处业务栈帧比 shell 最后的非零状态更接近原因。

## 24. 编译日志：cannot assign a value to final variable

~~~java
final int maxRetry = 3;
maxRetry = 4;
~~~

`javac` 会在第二次赋值位置报告不能给 final 变量赋值。另一个常见错误是构造器某条正常路径没有初始化 blank final 字段，诊断会指向字段或构造器完成位置。

读日志时记录：命令是 compile 还是 testCompile；文件、行、列；变量名；第一条诊断。不要把最后的 `BUILD FAILURE` 当原因。验证器使用 `-XDrawDiagnostics` 取得更稳定的诊断键，并同时要求非零退出码；只 grep 到某段文字但编译命令返回零，不能算预期失败。

## 25. 运行日志：旧对象被改变

错误实现：

~~~java
public Money plus(Money other) {
    cents += other.cents;
    return this;
}
~~~

若字段不是 final 且可写，代码能编译。测试应同时断言结果和两个输入：

~~~text
IMMUTABILITY_BROKEN expectedOriginal=5000 actualOriginal=5750
~~~

第一处可信证据是旧对象值变化，而不是“assertions failed”汇总。修复为创建并返回新 Money，再断言 `result != base`、结果值正确、base 与 fee 都保持原值。若只断言结果 5750，错误实现也会通过。

## 26. 表示泄漏日志：输入和输出要分开测

输入泄漏测试：构造对象后修改传入数组，再查询。输出泄漏测试：拿到 getter 结果并修改，再次查询。它们诊断不同边界，不能用一个测试代替两个。

~~~text
INPUT_ALIAS_BROKEN expected=8 actual=23
OUTPUT_ALIAS_BROKEN expected=10 actual=0
~~~

修复后还要断言两次 `hours()` 返回不同数组身份、内容相同。只比较数组引用是否不同也不够，因为实现可能每次返回错误的新数组；只比较内容也不够，因为同一内部引用暂时内容正确。身份与内容共同形成证据。

## 27. 测试策略：不可变契约必须观察旧值

至少包含：

- 合法构造后查询金额与币种；
- 负金额、null 币种、空白币种被拒绝；
- 同币种相加结果正确；
- 不同币种拒绝；
- 溢出拒绝；
- 新结果与两个输入身份区分；
- 相加后两个输入值不变；
- 输入数组修改不影响对象；
- 输出数组修改不影响对象；
- final 重赋值稳定编译失败；
- 错误 public 可变字段稳定破坏不变量。

测试不要读取 private 字段来证明不可变，要通过公开行为观察。否则测试会绑定实现，未来字段表示改变时产生虚假阻力。

## 28. 安全与数据完整性

不可变性改善进程内数据完整性，但不是授权系统。private final 金额仍可能被未授权 API 返回；构造器校验也不能代替请求身份、租户边界、数据库约束和审计。防御性复制阻止调用者修改内部数组，不阻止调用者读取合法返回值后传播。

金额使用 long 分单位可避免二进制浮点的常见精度问题，但真实支付还需要币种小数位、舍入、上限、幂等和数据库事务。不要把本章 Money 当完整财务库。异常消息不得包含令牌、完整支付凭证或不必要的个人信息。

公开 `static final` 可变数组尤其危险：任何调用者都可能改变全局默认规则。敏感默认值也不应硬编码为常量。配置与密钥管理在部署安全章节处理。

## 29. TypeScript 与 Vue 对照

| Java | TS/Vue 相近直觉 | 关键差异 |
| --- | --- | --- |
| final 局部变量 | `const binding` | 两者都不自动深冻对象，但语言类型与运行时不同 |
| final 引用数组 | `const arr = []` 后仍可 push/改元素 | Java 数组与 JS Array API 不同 |
| 不可变对象 | readonly 数据加无修改入口 | TS readonly 多为静态类型约束，运行时对象仍可能被别处改 |
| 防御性复制 | 展开/复制后再保存或返回 | 浅复制对嵌套可变引用同样有限 |
| 返回新 Money | reducer/计算返回新状态 | Vue 响应式追踪机制不是 Java final 语义 |
| String 不可变 | JS 字符串也不可原地改 | API 与编码模型仍不同 |

前端经验能帮助理解“const 绑定不等于 Object.freeze”，但不要把 TS 的 `readonly` 当 Java 的运行时安全机制。两边都要审查嵌套引用、边界复制和真实调用者。

## 30. AI 生成代码审查清单

1. AI 是否把“字段 final”直接宣称成“对象不可变”？
2. 构造器是否在赋字段前验证 null、范围和组合规则？
3. 是否仍有 public 字段、setter 或返回内部可变引用的 getter？
4. 操作是返回新值，还是悄悄改 `this`？
5. 测试是否断言旧对象保持不变？
6. 数组输入和输出是否分别复制与测试？
7. 浅复制中元素是否仍是共享可变对象？
8. `static final` 是否暴露数组或其他可变对象？
9. long 相加是否考虑溢出？
10. record 是否被误当成自动深不可变？
11. 为了让测试通过是否删掉非法输入断言？
12. 代码注释是否过度承诺线程安全或金融正确性？

让 AI 给出“不变量表、所有修改入口、所有可变引用路径、失败 oracle”，比要求“写一个 immutable class”更可审计。

## 31. 预测—构建—破坏—需求变更

### 31.1 预测

运行前回答：final int 能否第二次赋值；final int[] 能否改元素；构造器直接保存输入数组后修改原数组会怎样；plus 返回新对象但调用者丢弃结果会怎样；record 的数组组件是否自动深不可变；不同币种相加在哪个阶段失败。

### 31.2 构建

从空包结构实现 `com.factorycare.money.domain.Money` 和另一个包中的调用端。只公开必要构造器、查询与 plus。再实现一个复制 int 数组的维护窗口。写固定断言和可重放输出。

### 31.3 故意破坏

一次只做一项：去掉 cents 的 final 并让 plus 修改 this；把 cents 改 public；直接保存输入数组；直接返回内部数组；让 final 局部变量重新赋值；将 `Math.addExact` 换为普通加法并触发溢出。记录编译/运行阶段与第一处可信证据。

### 31.4 需求变更

新增“Money 可减去折扣但结果不能为负”。先写结果和原值不变断言，再实现 `minus` 返回新对象。第二个变更是时间槽必须严格递增；在构造复制前后都不要修改调用者数组，使用索引检查并保留输入不变测试。

## 32. 无 AI 独立训练

限时 75 分钟：

1. 从空目录创建两个 package；
2. 写 private final 的 Money 和构造校验；
3. 写 plus，返回新对象；
4. 写至少十二个断言，必须观察原值；
5. 写 int 数组值对象，完成输入/输出复制；
6. 制造一次 final 重赋值编译失败；
7. 制造一次 plus 原地修改运行失败；
8. 制造输入和输出别名泄漏并分别修复；
9. 增加 minus 需求，不重新生成整个项目；
10. 120 秒复述 final 引用和不可变对象区别。

允许查看 JDK API 和 `javac` 帮助，不允许由 AI 直接给最终类。验收材料包含源码、命令、非零失败退出码、断言计数、修改前后日志与复述提纲。

## 33. 高频误区

1. **“final 对象不能变。”** final 修饰引用变量时只禁止改指向。
2. **“所有字段 final 就一定深不可变。”** 字段可能指向可变对象。
3. **“没有 setter 就不可变。”** getter 可能泄露内部数组。
4. **“只在构造时复制即可。”** 输出边界也要防御性复制。
5. **“数组 clone 是深复制。”** 对对象数组只复制引用层。
6. **“static final 都是编译期常量。”** 类型与初始化表达式还有限制。
7. **“公开常量改值后旧调用方自动更新。”** 值可能已内联。
8. **“返回新对象会自动更新原变量。”** 调用者必须接住返回值。
9. **“record 自动深不可变。”** 可变组件仍需边界设计。
10. **“不可变对象让整个系统线程安全。”** 外部共享状态仍可能有竞争。
11. **“private final 等于授权和加密。”** 它只是语言与状态设计的一部分。
12. **“所有实体都应不可变。”** 有身份、生命周期实体可能需要受控变化。
13. **“测试结果值正确就够。”** 还要断言输入旧值保持不变。
14. **“复制能替代校验。”** 复制解决别名，校验解决合法值。

## 34. 复述、复习与检索

### 34.1 120 秒复述模板

“final 约束变量槽位只能完成一次赋值。基本类型槽位不能换值；引用槽位不能换对象，但对象内部仍可能变化。不可变对象要求构造后无公开可达的状态变化，所以还需要 private 状态、构造校验、无修改入口、变化返回新值，以及对可变输入输出做复制。我的 Money 的 plus 返回新对象并断言原值不变；我的数组实验分别阻断了输入和输出别名。线程安全只是减少写入的收益，不是 final 自动证明。”

### 34.2 间隔复习

- 当天：画“变量槽位—引用—对象”三层图；
- 第 2 天：重建 final 数组反例与编译失败；
- 第 7 天：从空目录实现 Money 并覆盖旧值断言；
- 第 14 天：写对象数组浅复制反例，只解释不引入集合；
- 第 30 天：审查 FactoryCare 一个值类型和一个实体，说明为何选择不同变化模型。

## 35. 一页速查

| 问题 | 最小结论 |
| --- | --- |
| final 基本类型变量 | 完成赋值后不能换值 |
| final 引用变量 | 不能改指向，对象可能仍可变 |
| final 实例字段 | 每个对象构造时完成一次赋值 |
| blank final | 每条正常构造路径都要明确赋值 |
| `static final` | 类级且字段只赋值一次，不自动深不可变 |
| 常量变量 | final 的基本类型/String，并以常量表达式初始化 |
| 不可变对象 | 构造后无可观察逻辑状态变化 |
| private + final | 常用必要组成，但单独不充分 |
| 变化操作 | 返回新对象，旧对象保持原值 |
| 数组输入 | 验证并复制后保存 |
| 数组输出 | 返回副本，不泄露内部引用 |
| 对象数组 clone | 通常只是浅复制引用 |
| String 字段 | String 本身不可变，校验后可安全保存引用 |
| record | 语法简化，不自动深不可变 |
| 不可变与线程 | 减少共享写入，不等于整个系统线程安全 |
| 结果测试 | 同时断言结果、新身份和所有输入旧值 |

## 36. 术语表

- **final 变量**：只能完成一次赋值的变量。
- **final 字段**：在字段初始化或构造路径中完成赋值后不可重新赋值的字段。
- **blank final**：声明处没有初始化、稍后必须明确赋值的 final 变量或字段。
- **有效 final**：未声明 final 但初始化后从未重新赋值的局部变量。
- **final 引用**：不能改指向其他对象的引用变量。
- **常量变量**：满足 JLS 特定类型、final 与常量表达式条件的变量。
- **不可变对象**：构造完成后逻辑状态无法通过公开路径改变的对象。
- **值对象**：主要由值和不变量定义、通常没有独立身份生命周期的对象。
- **防御性复制**：在可变数据跨边界时复制，切断共享别名。
- **输入别名**：调用者和对象同时保留同一可变输入引用。
- **表示泄漏**：内部可变对象引用经公开行为暴露给调用者。
- **浅复制**：复制外层容器，但内部对象引用仍共享。
- **深复制**：按明确定义复制整个需要隔离的可变对象图。
- **浅不可变**：外层绑定稳定，但可达子对象仍可能变化。
- **深不可变**：整个公开可达状态图都不发生可观察变化。
- **新值操作**：不改变接收者、而返回另一个值对象的操作。

## 37. 本章边界与官方来源

本章要求准确解释 final 变量、字段和引用；区分 `static final` 与常量变量；用普通类实现不可变 Money；通过原值断言与数组输入/输出复制证明边界；认识浅/深不可变、record 与线程安全收益的范围。集合复制、完整 record 契约、继承限制和 JMM 留到后续章节。

以下一手资料已于 **2026-07-16** 按 Java SE 25 / JDK 25 复核：

- [JLS 25 §4.12.4 final Variables](https://docs.oracle.com/javase/specs/jls/se25/html/jls-4.html#jls-4.12.4)：final 与常量变量定义。
- [JLS 25 §8.3.1.2 final Fields](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.3.1.2)：final 字段与赋值约束。
- [JLS 25 Chapter 16 Definite Assignment](https://docs.oracle.com/javase/specs/jls/se25/html/jls-16.html)：明确赋值分析。
- [JLS 25 §15.26 Assignment Operators](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.26)：赋值表达式和 final 左值限制。
- [JLS 25 §17.5 final Field Semantics](https://docs.oracle.com/javase/specs/jls/se25/html/jls-17.html#jls-17.5)：final 字段在线程模型中的专门语义，供后续衔接。
- [String API, Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/String.html)：String 的不可变字符序列契约。
- [Arrays API, Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Arrays.html)：数组复制与操作 API 定位。
- [javac 25 Tool Guide](https://docs.oracle.com/en/java/javase/25/docs/specs/man/javac.html)：编译选项与诊断。

稳定核心是“final 约束变量绑定；不可变性是对象边界契约；对可变数据同时守住输入和输出，并用旧值断言证明没有隐蔽变化”。工具诊断文本会随补丁变化，语义边界不随之变化。
