---
schema_version: 2
edition: 2026.2-draft
id: ch.java-oop.constructors-invariants
title: 构造器、初始化顺序与对象不变量
responsibility: 教授对象从创建起即满足不变量，不在本章展开包可见性或继承初始化链
volume: '02'
order: 3
level: L1
status: drafting
path: book/volume-02-java-objects/chapters/ch.java-oop.constructors-invariants.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-oop.classes-objects
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
  text: 在 120 秒内解释构造器、初始化顺序与对象不变量的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-constructor
  - java-invariant
  covers_topics:
  - java.constructor
  - java.field-initializer
  - java.initialization-order
  - java.constructor-validation
  - java.valid-state
  - java.invalid-construction
  uses_capabilities:
  - java.references-objects
  - java.methods
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为 Device 编写构造器，要求非空名称和合法初始状态，并记录字段初始化器、构造器体的执行顺序，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - java-constructor
  - java-invariant
  covers_topics:
  - java.constructor
  - java.field-initializer
  - java.initialization-order
  - java.constructor-validation
  - java.valid-state
  - java.invalid-construction
  uses_capabilities:
  - java.references-objects
  - java.methods
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入构造器忘记赋字段、校验发生在赋值后和重载链递归，依据对象状态或编译错误修复
  covers_topic_groups:
  - java-constructor
  - java-invariant
  covers_topics:
  - java.constructor
  - java.field-initializer
  - java.initialization-order
  - java.constructor-validation
  - java.valid-state
  - java.invalid-construction
  uses_capabilities:
  - java.references-objects
  - java.methods
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 构造器、初始化顺序与对象不变量

> 本章状态为 **drafting**。正文和代码可以试读、修改和运行，但文件存在或验证器通过都不能替学习者自动更新 **PROGRESS.md**。

上一章为了看清类、实例、字段和方法，先创建空对象，再逐个写字段。这种写法适合观察，却留下危险窗口：一台设备可能已经存在，名称仍是 **null**，状态仍是语言默认值；它可以在“半合法”时被传给另一个方法。构造器要解决的核心问题不是少写两行赋值，而是规定对象诞生时必须满足什么。

**构造器**是在创建类实例时执行的特殊声明；**字段初始化器**为字段提供创建阶段的显式初值；**初始化顺序**解释多个创建步骤先后发生；**对象不变量**是一个合法对象在对外可观察期间必须持续成立的条件。FactoryCare 的设备对象可以规定：编码去除首尾空白后不能为空，名称不能为空，初始状态只能来自允许集合。若输入不满足条件，创建应失败，调用方不应拿到半合法对象引用。

本章只建立当前类内部的构造模型。不会展开父类与子类构造链，不讲工厂模式、依赖注入、反射创建或 Spring Bean 生命周期；访问修饰符和包边界在下一章处理。版本基线为 **JDK 25**，一手资料复核日期为 **2026-07-16**。

## 1. 学习结果必须能被验证

完成本章不等于“会写一个同名方法”。你要留下三类证据：

1. **解释**：在 120 秒内说明构造器与普通方法的差别，按顺序描述字段默认值、字段初始化器和构造器体，给出一个无效对象漏出的反例。
2. **构建**：为设备写带参数构造器；规范化并验证编码和名称；用固定日志观察字段初始化器、委托构造器和构造器体；合法输入有确定输出，非法输入不能得到对象。
3. **诊断**：分别复现忘记写入字段、校验顺序错误和递归构造器调用；区分业务断言失败、运行时拒绝与编译失败，再做最小修复。

配套工件：

- [构造与初始化观察台](../../../examples/encyclopedia/ch.java-oop.constructors-invariants/README.md)
- [FactoryCare 合法设备实验](../../../labs/encyclopedia/ch.java-oop.constructors-invariants/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-oop.constructors-invariants/README.md)

私有解析只应在公开练习留下预测、首次失败和修复尝试后使用。自动验证证明的是固定输入下的程序行为，不证明学习者能够独立解释和迁移。

## 2. 前置模型：类声明、字段与 new

你已经知道类声明定义实例字段和行为，**new Device(...)** 创建实例并产生引用。构造器正处在这次创建过程中。先比较过渡写法：

~~~java
Device device = new Device();
device.code = "PUMP-01";
device.name = "北区循环泵";
device.status = "IDLE";
~~~

从第一行结束到最后一行结束之间，变量 **device** 已指向对象，但对象尚未具备完整业务信息。如果第二行之后调用登记方法，日志可能记录一个没有名称或状态的设备。即使当前单线程示例看似不会被别人看到，这种“先造壳再补字段”的 API 也把正确调用顺序交给了每个调用者。

构造器把必需输入放进同一个创建表达式：

~~~java
Device device = new Device("PUMP-01", "北区循环泵");
~~~

表达式只有两类结果：成功得到满足约束的对象引用，或者创建失败而没有可用对象。这个二选一是本章最重要的设计收益。

## 3. 构造器的语法身份

最小带参数构造器如下：

~~~java
class Device {
    String code;
    String name;

    Device(String code, String name) {
        this.code = code;
        this.name = name;
    }
}
~~~

逐项辨认：

- 构造器名称必须与类的简单名称一致；
- 构造器声明没有返回类型，连 **void** 也不能写；
- 圆括号中声明形参，规则与方法形参相同；
- 构造器体在创建阶段执行；
- **this** 指向当前正在初始化的实例；
- **this.code** 是字段，右侧 **code** 是形参。

写成 **void Device(...)** 后，它不再是构造器，而是一个名叫 Device 的普通实例方法。此时如果类中没有其他构造器，编译器可能仍提供无参默认构造器，导致代码“能 new，却没有执行你以为的初始化”。判断构造器不能只看名字，要确认它没有返回类型，并观察创建后的字段。

构造器不是可任意再次调用的重置函数。对象创建完成后不能写 **device.Device(...)**。若对象以后允许改名，应提供表达业务含义的实例行为；若不允许，就不要暴露重置入口。

## 4. 默认构造器不是“永远存在的无参构造器”

若类没有声明任何构造器，编译器会按语言规则隐式提供一个默认构造器。对于最简单的类，这使 **new Device()** 可以编译。只要你声明了任意构造器，编译器就不再额外赠送这个默认构造器。

~~~java
class Device {
    String code;

    Device(String code) {
        this.code = code;
    }
}
~~~

此后 **new Device()** 会编译失败，除非你显式声明无参构造器。常见误解是“加了有参构造器后，无参构造器被覆盖”；更准确的说法是：原先隐式默认构造器的生成条件不再成立。

不要为了消除 IDE 红线就随手补一个无参构造器。如果 **code** 是不变量的一部分，无参创建从设计上就无法提供合法值。应该修改调用方传入必需信息，而不是打开一个非法入口。框架是否要求无参构造器属于后续框架契约，不能反过来污染当前领域规则。

## 5. this：区分当前实例字段与构造参数

构造器常让字段和参数使用相同业务名称：

~~~java
Device(String code) {
    this.code = code;
}
~~~

执行右侧时读取形参 **code**，执行左侧时找到当前实例的字段 **this.code**。若错写成：

~~~java
Device(String code) {
    code = code;
}
~~~

左右两侧都指形参，赋值没有改变字段；构造器正常返回，但对象中的 code 仍为 **null**。这是一种比语法错误更危险的逻辑失败，因为程序能编译、能运行，直到后续断言或业务路径才暴露。

可靠诊断步骤：

1. 在调用点写出输入；
2. 在构造器内标注每个同名标识符是形参还是字段；
3. 创建后立即读取可观察结果；
4. 让测试断言字段符合不变量；
5. 把错误改为最小的 **this.code = code**，不要重写整个类掩盖原因。

## 6. 字段初始化器：声明处的创建初值

字段可以在声明处带初始化表达式：

~~~java
class Device {
    String status = "REGISTERED";
    int repairCount = 0;
    String code;

    Device(String code) {
        this.code = code;
    }
}
~~~

字段初始化器适合表达所有构造入口共享的初值，例如新登记设备状态。**int** 的语言默认值本来就是 0，但显式写 0 可以强调业务含义；是否保留应以可读性为准，而不是误以为不写就“没有值”。

字段初始化器不是输入验证替代品。它看不到尚未赋给字段的构造参数，也不应偷偷依赖调用顺序。必需输入仍应由构造器接收、规范化和验证。

### 6.1 语言默认值与业务默认值

实例字段在显式初始化前会先具有类型默认值：引用为 **null**，整数为 0，布尔为 false。它们是语言层创建过程的一部分，不代表业务认可。设备状态的 null 不是“待登记”，维修次数 0 也不自动证明设备合法。

局部变量不同：局部变量没有同样的可读取默认值保证，读取前必须明确赋值。不要把字段规则套到方法局部变量上。

## 7. 必要的初始化顺序模型

不涉及继承细节时，可以按下面的观察模型理解当前类实例：

1. 求值 **new** 表达式中的实参，并按重载规则选择构造器；
2. 为新对象建立存储，实例字段先处于语言默认值；
3. 若构造器第一步用 **this(...)** 委托当前类另一个构造器，先进入目标构造器；
4. 当前类的字段初始化器和实例初始化块按源码文本顺序执行；
5. 最终承接初始化的构造器体继续执行；
6. 构造成功后，**new** 表达式才向调用点产生可用引用。

真实语言规则还包括父类初始化；本章只承认它存在，不展开继承链。这里的模型用于预测本章配套日志，不是 JVM 内存指令列表。

~~~java
class Trace {
    String first = mark("field:first");
    String second = mark("field:second");

    Trace() {
        mark("constructor:body");
    }

    String mark(String step) {
        System.out.println(step);
        return step;
    }
}
~~~

输出先是两个字段初始化器，再是构造器体。把字段顺序调换，日志顺序也会调换。依赖这种副作用通常会降低可读性；实验用日志是为了看清规则，生产字段初始化器应尽量简单。

## 8. 重载构造器与 this(...) 委托

同一个类可以按参数列表重载构造器：

~~~java
class Device {
    String code;
    String name;
    String status = "REGISTERED";

    Device(String code, String name) {
        this.code = requireText(code, "code");
        this.name = requireText(name, "name");
    }

    Device(String code, String name, String status) {
        this(code, name);
        this.status = requireText(status, "status");
    }
}
~~~

第二个构造器用 **this(code, name)** 委托第一个构造器，避免复制编码和名称校验。构造器内的显式委托必须处于允许的位置；不能先打印或赋字段，再调用 **this(...)**。JDK 25 的语言规则允许在显式构造器调用之前出现受严格限制、不能引用正在构造实例的语句，但零基础代码仍应把委托写成第一条，最容易审查，也与常见代码库兼容。

重载不是越多越好。推荐找到一个维护完整不变量的“主入口”，其他入口只补默认值并委托。若 A 委托 B，B 又委托 A，编译器会报告递归构造器调用，因为不存在真正完成初始化的出口。

### 8.1 不要把 null 当作重载选择技巧

多个引用类型重载可能让 **new Device(null)** 产生歧义，或者选中调用者没有预料的入口。必需业务输入应有清楚类型与名称，不能靠 null 暗示“任选默认值”。遇到可选概念时先写明确需求；更复杂的创建 API 留到后续设计章节。

## 9. 对象不变量：谁拥有、何时成立

不变量不是一条随意的 if，而是“只要对象被视为合法，它就必须满足”的陈述。一个简化设备可以定义：

- code 去除首尾空白后长度大于 0；
- name 去除首尾空白后长度大于 0；
- status 在创建时是 **REGISTERED** 或调用方明确给出的允许状态；
- repairCount 不小于 0。

构造器应先处理不可信输入，再把结果写入字段：

~~~java
Device(String code, String name) {
    String normalizedCode = requireText(code, "code");
    String normalizedName = requireText(name, "name");
    this.code = normalizedCode;
    this.name = normalizedName;
    this.status = "REGISTERED";
}
~~~

这里局部变量让“验证完成”与“发布到字段”分开。若验证失败，调用方得不到对象。即使实现曾短暂写过字段，只要 **this** 没有在构造期间泄漏，外部通常无法观察半成品；为了让代码更易审查，仍优先验证后赋值。

### 9.1 requireText 的最小职责

~~~java
static String requireText(String value, String field) {
    if (value == null) {
        throw new IllegalArgumentException(field + " must not be null");
    }
    String normalized = value.trim();
    if (normalized.isEmpty()) {
        throw new IllegalArgumentException(field + " must not be blank");
    }
    return normalized;
}
~~~

本章把 **IllegalArgumentException** 当作“创建被拒绝”的可观察结果，不展开异常层次、捕获策略或对外错误码；完整失败契约在后续异常章节。重点是：异常之前没有合法对象结果，测试必须验证异常类型与输入边界，而不是只测试快乐路径。

错误消息不能回显密码、令牌或大段敏感输入。设备编码可以按业务安全规则记录，用户提交的自由文本则应谨慎脱敏。验证逻辑也应避免正则灾难或无限循环。

## 10. 校验发生在赋值之后为什么仍可能出错

看似等价的代码：

~~~java
Device(String code) {
    this.code = code;
    if (this.code == null || this.code.isBlank()) {
        throw new IllegalArgumentException("invalid code");
    }
}
~~~

在对象没有泄漏的简单类中，异常仍会阻止调用方得到结果；因此不能声称“只要先赋值就必然泄漏”。真正的问题是边界变得更脆弱：

- 校验前若调用实例方法，方法会观察无效字段；
- 构造器若把 **this** 注册到共享列表、回调或线程，外部可能观察半成品；
- 后续维护者可能在校验前新增日志或副作用；
- 多字段校验失败时，排查哪个字段已被规范化更困难。

所以更稳健的顺序是：对参数做纯校验与规范化，全部成功后再集中写字段；构造期间不要把 **this** 传出对象边界。本章不展开并发安全，但先建立“不发布半成品”的习惯。

## 11. 失败分类：编译、运行和业务断言

构造器故障至少分三类，不能只看最后一句 **BUILD FAILURE**：

| 故障 | 阶段 | 典型证据 | 修复方向 |
| --- | --- | --- | --- |
| 构造器写了返回类型 | 编译 | 调用入口不匹配或无参创建行为异常 | 去掉返回类型，确认真实构造器 |
| this(...) 互相递归 | 编译 | recursive constructor invocation | 保留一个真正完成初始化的入口 |
| 空名称被拒绝 | 运行 | 非零退出与 IllegalArgumentException | 若需求就是拒绝，这是预期失败 |
| 忘记 this 写字段 | 运行后断言 | expected 编码，actual 为 null | 区分字段和形参 |
| 字段初始化顺序猜错 | 输出比对 | trace 行次序不同 | 按源码顺序重画执行过程 |
| 允许非法状态创建 | 业务断言 | 构造成功但不变量不成立 | 在创建边界验证允许值 |

预期失败也必须受到验证：命令非零只是第一层，还要确认错误类别与目标故障一致。拼错类名造成非零退出，不能冒充“空名称被成功拒绝”。

## 12. 测试对象不变量，而不是实现细节

一个固定测试应覆盖：

- 最小合法输入；
- 首尾空白被规范化；
- null；
- 空字符串与全空白；
- 默认状态；
- 显式合法状态；
- 非法状态；
- 两个独立对象不会串状态；
- 初始化日志顺序；
- 构造器重载最终得到相同不变量。

不要断言局部变量名、私有辅助方法调用次数或 JVM 对象地址。测试的契约是“合法对象具有什么可观察性质、非法输入如何失败”。本章实验使用无依赖的 **check** 方法和 shell 固定输出，后续再系统学习 JUnit。

测试方法本身也可能错。先手算预期，再故意修改一个期望值确认验证器会红；恢复后复跑。一个永远绿色的测试没有证明力。

## 13. FactoryCare：设备创建边界

FactoryCare 接收扫码结果时，不要直接把原始字符串散落写入字段。可以先建立最小设备：

~~~java
class Device {
    String code;
    String name;
    String status = "REGISTERED";

    Device(String code, String name) {
        this.code = requireText(code, "code");
        this.name = requireText(name, "name");
    }

    String describe() {
        return code + "|" + name + "|" + status;
    }
}
~~~

创建流程可口述为：

1. 扫码或表单提供原始 code/name；
2. 调用点执行实参表达式；
3. 构造器规范化并验证；
4. 任一必需值无效则创建失败；
5. 全部通过后字段组成合法状态；
6. 调用点得到对象引用，再进行后续登记。

这里没有数据库 ID、租户、权限或持久化。不要把“Java 对象构造成功”误说成“设备已入库”或“当前用户有权登记”。领域创建、本地内存、接口授权和事务提交是不同证据。

## 14. TypeScript、Vue 对照：相似骨架，不同保证

TypeScript 类也有 **constructor** 和 **this**：

~~~typescript
class Device {
  constructor(
    readonly code: string,
    private status = 'REGISTERED',
  ) {
    if (code.trim().length === 0) throw new Error('blank code')
  }
}
~~~

相似处是创建入口集中接收依赖，当前实例由 **this** 表示。差异是 TypeScript 类型在编译后大多被擦除，JavaScript 调用方和外部 JSON 仍能传入不符合静态声明的值；Java 也不能靠静态类型验证空白文本或所有业务状态。两者都需要运行时边界校验。

Vue 组件的 props 像创建输入，但组件实例生命周期不等于 Java 构造器。不要把 **setup**、mounted 或响应式默认值机械映射成字段初始化顺序。可迁移的原则只有：输入边界明确、默认值集中、无效输入不应悄悄形成半合法状态。

## 15. AI 协作：允许生成，必须能审查

可以让 AI 生成构造器样板，但你必须逐项回答：

1. 哪些参数是必需输入，哪些是真正安全的默认值？
2. 每条不变量由哪一行执行？
3. null、空串、全空白分别怎样？
4. 验证发生在字段发布之前还是之后？
5. 有几个构造入口，是否都汇聚到同一套规则？
6. AI 是否擅自加入无参构造器以“兼容框架”？
7. 错误消息是否泄露输入？
8. 测试是否真的能因故障变红？

最有效的 AI 使用方式不是让它一次重写整类，而是让它解释一条执行路径、设计一条边界测试或比较两个小补丁。最终你要能在没有 AI 时修复一个漏赋字段和一个递归委托错误。

## 16. 预测、构建、诊断、变更闭环

### 16.1 先预测

不运行代码，写出：

- 两个字段初始化器与构造器体的打印顺序；
- **new Device("  P-1  ", "泵")** 最终 code；
- **new Device(" ", "泵")** 是编译失败还是运行拒绝；
- 增加有参构造器后 **new Device()** 是否还能编译；
- A 构造器委托 B、B 委托 A 会在哪个阶段失败。

### 16.2 再构建

从空文件定义 Device，不复制完整答案。加入 code、name、status 和 repairCount；实现一个主构造器和一个委托入口；打印对象摘要与初始化轨迹。命令必须使用 **javac --release 25**，并保存命令、退出码和固定输出。

### 16.3 故意破坏

按顺序只注入一个故障：

1. 把 **this.code = code** 改成 **code = code**；
2. 把字段初始化器移动到另一个字段之后；
3. 让两个重载构造器互相委托；
4. 删除空白检查；
5. 在校验前打印或发布 this。

每次记录“预测—实际—首个可信证据—最小修复—复跑”。不要同时改五处，否则无法证明因果。

### 16.4 需求变更

新增规则：状态 **RETIRED** 不能作为新建设备初始状态。先改测试让它红，再改构造验证；说明为什么不能只在调用页面隐藏该选项。之后再要求 code 统一大写，评估规范化发生在构造器还是更早的输入解析边界。

## 17. 无 AI 训练与复述

限时 45—60 分钟，关闭补全和聊天：

1. 从空目录写一个有两个构造入口的 Device；
2. 写至少八个固定断言，覆盖合法、空白、null 与默认状态；
3. 制造 **code = code**，只看失败证据修复；
4. 制造递归委托，指出编译阶段与源位置；
5. 画出一次创建的初始化顺序；
6. 用 120 秒复述“不变量为何比少写 setter 更重要”。

有效复述必须包含一个反例：对象先创建后填字段时，另一个方法可能看到半合法状态；构造失败时调用方得不到对象引用。只背“构造器名和类名相同”不足以通过。

## 18. 高频误区校正

1. **“构造器是返回对象的方法。”** 构造器没有返回类型；new 表达式产生引用。
2. **“构造器写 void 更明确。”** 写 void 会变成普通方法。
3. **“每个类都有无参构造器。”** 只有满足默认构造器生成条件，或显式声明时才有。
4. **“字段默认值就是业务默认值。”** 语言默认值不证明业务合法。
5. **“code = code 已经赋值。”** 它只把形参赋给自己。
6. **“校验写在哪里都一样。”** 副作用和 this 泄漏会让半成品可观察。
7. **“重载就是复制多个构造器体。”** 优先委托到单一不变量入口。
8. **“this(...) 可以放在任意位置。”** 构造器委托受严格位置与引用规则约束。
9. **“异常就是程序 bug。”** 对非法输入的预期拒绝可以是正确契约；必须验证类型和原因。
10. **“构造成功等于保存成功。”** 内存对象与数据库事务是不同阶段。
11. **“AI 生成了 null 检查就安全。”** 还要验证空白、规范化、状态集合与测试有效性。
12. **“初始化日志顺序就是 JVM 物理内存顺序。”** 它只证明语言层可观察行为。

## 19. 复习节奏

- 当天：不看笔记写出构造器语法和五步初始化模型；
- 第 2 天：制造漏字段与空白输入，凭测试定位；
- 第 7 天：从空文件重做实验并加入一个委托构造器；
- 第 14 天：学习封装后说明谁可以破坏不变量；
- 第 30 天：在 Spring 项目代码中找到领域对象创建入口，区分框架绑定与业务构造。

每次复习都应包含一次预测和一次红绿验证，不把重复阅读计为掌握。

## 20. 一页速查

| 问题或代码 | 最小结论 |
| --- | --- |
| **Device(String code)** | 构造器；无返回类型，名称与类一致 |
| **new Device("P-1")** | 求值实参、执行构造过程、成功后产生引用 |
| 类未声明构造器 | 可能生成默认构造器 |
| 已声明任意构造器 | 不再额外生成默认构造器 |
| **this.code = code** | 左侧当前对象字段，右侧形参 |
| **String status = "REGISTERED"** | 字段初始化器 |
| 多个字段初始化器 | 按源码文本顺序执行 |
| **this(...)** | 委托当前类另一构造器，避免复制规则 |
| A 委托 B，B 委托 A | 编译期递归构造器调用 |
| 不变量 | 合法对象对外可观察期间持续成立的条件 |
| 非法输入 | 创建应被拒绝，不能返回半合法对象 |
| 验证后赋字段 | 降低半成品被副作用观察的风险 |

## 21. 术语表

- **构造器**：创建类实例时执行、名称与类一致且没有返回类型的特殊声明。
- **默认构造器**：类未声明任何构造器时，由编译器按规则隐式提供的构造器。
- **无参构造器**：参数列表为空的构造器；它可能是隐式的，也可能显式声明。
- **字段初始化器**：字段声明中的初始化表达式。
- **实例初始化块**：创建实例时按文本顺序执行的块；本章只用于解释顺序，不建议初学业务代码滥用。
- **构造器重载**：同一类中参数列表不同的多个构造器。
- **构造器委托**：用 this(...) 进入当前类另一个构造器。
- **对象不变量**：对象被视为合法时必须持续满足的条件。
- **规范化**：把允许的多种输入形式转换为统一表示，例如 trim 后保存。
- **无效构造**：输入不满足不变量，创建过程失败且不产生可用对象结果。
- **this 泄漏**：对象构造完成前把当前实例引用暴露给外部可观察位置。
- **半合法对象**：技术上存在、却没有满足业务必需条件的对象。

## 22. 本章边界与官方来源

本章到此要求：能声明构造器、解释默认构造器、使用 this 写字段、观察字段初始化顺序、用 this(...) 汇聚重载入口，并以验证保证对象从创建起满足不变量。父类与子类初始化链留给继承章节；访问修饰符与包留给下一章；final 与完整不可变性、异常契约、工厂与框架实例化分别在后续章节展开。

以下一手资料已于 **2026-07-16** 按 Java SE 25 / JDK 25 复核：

- [JLS 25 §8.8 Constructor Declarations](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.8)：构造器声明、重载、默认构造器与显式构造器调用。
- [JLS 25 §8.3.2 Initialization of Fields](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.3.2)：实例字段初始化器与前向引用边界。
- [JLS 25 §12.5 Creation of New Class Instances](https://docs.oracle.com/javase/specs/jls/se25/html/jls-12.html#jls-12.5)：新实例创建和初始化过程。
- [JLS 25 §15.9 Class Instance Creation Expressions](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.9)：new 表达式、实参和构造器选择。
- [Java SE 25 IllegalArgumentException API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/IllegalArgumentException.html)：本章用来观察非法构造拒绝的标准异常类型。

稳定核心是“创建入口集中建立合法状态，并用可重放失败证明非法输入不会产生可用对象”。JDK 补丁可能改变诊断文字或实现细节，不改变这个对象边界。
