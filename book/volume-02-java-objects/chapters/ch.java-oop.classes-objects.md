---
schema_version: 2
edition: 2026.2-draft
id: ch.java-oop.classes-objects
title: 类、实例、字段与实例方法
responsibility: 教授用类定义对象状态和行为，不在本章处理构造不变量、继承或访问控制策略
volume: '02'
order: 2
level: L1
status: drafting
path: book/volume-02-java-objects/chapters/ch.java-oop.classes-objects.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-oop.references-null-identity
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
  text: 在 120 秒内解释类、实例、字段与实例方法的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-class-instance
  - java-instance-behavior
  covers_topics:
  - java.class-instance
  - java.field
  - java.new-object
  - java.scanner-construction
  - java.instance-method
  - java.this-reference
  - java.object-state-change
  uses_capabilities:
  - java.references-objects
  - java.methods
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 定义 Device 类的字段与实例方法，创建两个独立实例并通过方法改变各自状态，同时解释 Scanner 创建外壳
  covers_topic_groups:
  - java-class-instance
  - java-instance-behavior
  covers_topics:
  - java.class-instance
  - java.field
  - java.new-object
  - java.scanner-construction
  - java.instance-method
  - java.this-reference
  - java.object-state-change
  uses_capabilities:
  - java.references-objects
  - java.methods
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入把字段写成局部变量或误用 this 导致状态不变，检查实例输出和对象身份后修复
  covers_topic_groups:
  - java-class-instance
  - java-instance-behavior
  covers_topics:
  - java.class-instance
  - java.field
  - java.new-object
  - java.scanner-construction
  - java.instance-method
  - java.this-reference
  - java.object-state-change
  uses_capabilities:
  - java.references-objects
  - java.methods
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 类、实例、字段与实例方法

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《引用、对象身份、null 与内存心智模型》](ch.java-oop.references-null-identity.md)：独立完成类与实例、实例行为前，必须先具备「引用、对象身份、null 与内存心智模型」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。正文和配套代码可以试读、运行与修改，但不能自动证明学习完成，也不会自动更新 `PROGRESS.md`。

上一章已经建立引用模型：变量保存引用值，对象有身份和状态，多个引用可以成为别名，`null` 不指向对象。现在要回答下一组问题：对象的状态由谁定义？为什么每个设备都有 `code` 与 `status`？为什么 `pump.activate()` 只改变泵实例，而不改变传感器？

**类**描述一类对象可以拥有的字段和实例方法；**实例**是运行时具体创建的对象；**字段**保存每个实例的状态；**实例方法**描述针对某个接收者执行的行为；`new` 表达式创建新实例并产生引用；`this` 在实例方法中表示本次调用的当前对象。

本章刻意允许先 `new Device()`、再逐个赋字段，用最透明的方式观察对象状态。它不教授构造器验证、不保证对象一出生就满足业务不变量、不制定完整访问控制策略，也不讲继承。下一章会修复“先创建空壳、再慢慢填字段”的缺点。版本基线为 **JDK 25**，官方资料复核日期为 **2026-07-16**。

## 1. 学完后必须留下什么证据

1. **解释证据**：在 120 秒内说清类与实例、字段与局部变量、实例方法与普通静态方法、接收者与 `this` 的关系；给出一个局部变量遮蔽字段的失败反例。
2. **构建证据**：定义最小 `Device` 类，创建两个独立实例，分别设置字段并调用方法；证明修改一个实例不会串到另一个实例；解释 `new Scanner(...)` 外壳中的类型、变量、`new` 与实参。
3. **诊断证据**：让 `rename(String code)` 错误地只修改形参，让 `startRepair()` 错误地只修改局部变量；根据实例输出定位字段没有变化，再做最小修复并复跑。

配套工件：

- [类与实例观察台](../../../examples/encyclopedia/ch.java-oop.classes-objects/README.md)
- [FactoryCare 两个设备实例实验](../../../labs/encyclopedia/ch.java-oop.classes-objects/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-oop.classes-objects/README.md)

私有解析只用于完成独立尝试后的核对。不要把答案目录复制进公开教材，也不要用 AI 重写整个类来绕过定位训练。

## 2. 前置自检：引用、方法与作用域

开始前，给定 `Device a = ...; Device b = a;`，你应能判断 `a` 与 `b` 是两个变量，但可能指向同一对象；给定两次创建表达式，应知道通常得到两个对象身份。你还应理解方法的形参、返回值和局部变量只在相应作用域中可用。

本章在此基础上新增“对象内部有哪些状态与行为”。如果你把 `a = b` 理解成自动复制对象，或把 `null` 当作空设备，请先回到上一章。类的语法不会自动纠正错误的引用心智模型。

## 3. 类不是对象，而是对象结构与行为的声明

最小类声明如下：

```java
class Device {
    String code;
    String status;
}
```

这段源码声明一个名为 `Device` 的类类型，并说明它的实例可以有 `code` 与 `status` 两个字段。仅仅加载或阅读这段声明，不等于已经存在某一台具体设备。就像表格列定义不等于已经有某一行数据，Vue 组件定义不等于页面上已经挂载某一个组件实例。

类承担两个初始职责：

- 定义每个实例可保存哪些状态；
- 定义可以对某个实例执行哪些行为。

类不应被说成“一个对象的模板副本”后就停止思考。它还是编译期类型：编译器据此检查字段名、方法名、参数和返回类型。`device.unknown` 若没有对应成员，通常在编译阶段就失败。

### 3.1 一份类声明，多个实例

```java
Device pump = new Device();
Device sensor = new Device();
```

两次 `new Device()` 创建两个不同实例；`pump` 与 `sensor` 分别保存指向它们的引用。两个实例都拥有 `code/status` 这组字段，但字段存储彼此独立。

```text
pump   ───> Device A { code=?, status=? }
sensor ───> Device B { code=?, status=? }
```

类声明只有一份，不代表字段值只存一份。后续会学习 `static` 类状态；本章所有示例都使用实例字段，避免混淆共享类状态与独立实例状态。

## 4. `new`：创建实例并返回引用

类实例创建表达式的最小外壳是：

```java
new Device()
```

它创建一个 `Device` 实例、执行相应初始化过程，并产生指向新实例的引用值。完整语句：

```java
Device pump = new Device();
```

可拆为四个角色：

| 片段 | 角色 |
| --- | --- |
| 左侧 `Device` | 变量的静态类型 |
| `pump` | 引用变量名 |
| 右侧 `new Device()` | 创建实例并求得引用值的表达式 |
| `=` | 把右侧引用值保存到左侧变量 |

每次求值 `new Device()` 都是新的创建事件。不要用变量名推断实例数量，要数实际执行了几次创建表达式。循环中的一处 `new` 可能执行很多次；分支中未走到的 `new` 本次不会执行。

### 4.1 为什么目前 `new Device()` 不带参数

本章的 `Device` 没有显式声明构造器，编译器会在满足规则时提供默认构造器，因此可以写空括号。这里仅把它当作过渡外壳。下一章会解释构造器、参数、初始化顺序与对象不变量，并把“创建后字段暂时无效”的窗口关闭。现在不要自行推导所有构造器规则。

### 4.2 创建与声明不是同一件事

```java
Device first;
Device second = null;
Device third = new Device();
```

第一行声明局部变量但尚未赋值，读取它会触发编译期的“可能未初始化”；第二行变量有值，但值是 `null`，解引用会在运行时失败；第三行才创建实例并保存引用。三者红线和失败阶段不同，调试时不能都叫“对象没初始化”。

## 5. 字段：属于实例的持久状态

字段声明在类体中、方法体外：

```java
class Device {
    String code;
    String status;
    int repairCount;
}
```

每个 `Device` 实例都有各自的三份字段状态。访问实例字段需要一个非空接收者引用：

```java
pump.code = "PUMP-01";
pump.status = "IDLE";
sensor.code = "SENSOR-07";
sensor.status = "IDLE";
```

点号左侧告诉程序“访问哪个实例”。右侧字段名告诉程序“访问这个实例的哪个状态位置”。`pump.status` 与 `sensor.status` 名字相似，却是两个不同对象里的状态。

### 5.1 字段与局部变量不同

局部变量声明在方法或代码块中，服务于一次调用的计算；字段属于对象状态，可跨多次方法调用观察。两者的初始化规则也不同：新对象的实例字段会获得语言定义的默认值，例如引用字段为 `null`、`int` 字段为 0、`boolean` 字段为 `false`；局部变量必须在读取前明确赋值。

默认值是技术事实，不一定是业务合法值。`code == null`、`repairCount == 0` 可能只是刚创建空壳后的暂态，不代表对象满足 FactoryCare 规则。下一章用构造器与不变量建立合法起点；本章只观察这个问题，不提前解决。

### 5.2 直接公开字段只是教学过渡

示例从 `main` 直接写字段，是为了让状态位置清晰可见。真实工程通常通过封装控制写入、校验和可见性，但访问控制与封装策略在后续章节系统学习。现在应知道直接写字段会让任何可访问代码都能绕过业务规则，因此不要把教材的过渡写法直接扩散到生产领域模型。

## 6. 实例方法：行为绑定到接收者

在类中声明不带 `static` 的方法，就是实例方法：

```java
class Device {
    String status;

    void activate() {
        this.status = "ACTIVE";
    }
}
```

调用：

```java
pump.activate();
```

点号左侧 `pump` 是接收者表达式。运行时先求得 `pump` 的引用，确认它不是 `null`，再以该对象作为当前对象执行方法体。方法中的 `this` 指向本次调用的当前实例，因此这一调用修改泵对象；`sensor.activate()` 则以传感器对象为当前实例。

### 6.1 调用过程逐步展开

```java
Device pump = new Device();
pump.status = "IDLE";
pump.activate();
System.out.println(pump.status);
```

过程：创建实例并保存引用；经引用写字段；求值接收者 `pump`；进入实例方法，`this` 表示泵实例；写入 `this.status`；方法返回；再次经 `pump` 读取同一字段，打印 `ACTIVE`。没有神秘“类自动全局变更”，只有对具体接收者状态的操作。

### 6.2 实例方法可以读取并返回状态

```java
String describe() {
    return this.code + ":" + this.status;
}
```

`pump.describe()` 与 `sensor.describe()` 执行同一份方法代码，却读取不同接收者的字段。这是“同一类型、不同实例状态”的直接证据。

### 6.3 行为应该表达对象职责

比起在外部散落 `device.status = ...`，`device.activate()` 更能表达意图，也为后续校验、审计和不变量提供集中入口。但不要把所有工具逻辑都塞进对象：是否属于实例方法，要问“该行为是否主要依赖并维护这个对象的职责”。发送短信、访问数据库、读取系统时间往往涉及外部服务边界，后续架构章节再讨论。

## 7. `this`：当前实例的引用

`this` 不是“当前类”，也不是固定全局对象。每次实例方法调用都有一个接收者，方法体中的 `this` 表示该接收者。

```java
void rename(String code) {
    this.code = code;
}
```

左侧 `this.code` 是当前实例字段；右侧 `code` 是这次调用传入的形参。`pump.rename("PUMP-02")` 时 `this` 指向泵，`sensor.rename("TEMP-08")` 时 `this` 指向传感器。

在字段名没有被局部名称遮蔽时，可以省略 `this.`：

```java
void activate() {
    status = "ACTIVE";
}
```

但在同名形参存在时，`this` 能清楚消除歧义。教材在状态写入处倾向保留它，帮助零基础学习者确认写入目标。

### 7.1 经典遮蔽故障

```java
void rename(String code) {
    code = code;
}
```

两侧都解析为形参，语句只是把形参当前值赋回形参，对对象字段没有影响。它可以编译、运行并正常返回，因此仅看 `BUILD SUCCESS` 发现不了。必须调用后读取实例字段，或用断言比较期望值。

正确意图：

```java
void rename(String code) {
    this.code = code;
}
```

若还要去空白，可以先计算，再明确写回：

```java
void rename(String code) {
    String normalized = code.trim();
    this.code = normalized;
}
```

不要只把局部变量 `normalized` 算出来却忘记赋给字段。

## 8. 对象状态变化：按接收者隔离观察

```java
Device pump = new Device();
pump.status = "IDLE";
Device sensor = new Device();
sensor.status = "IDLE";

pump.activate();
```

执行后泵是 `ACTIVE`，传感器仍为 `IDLE`。类的方法代码共享，实例字段不共享。若两个变量其实是别名：

```java
Device sensor = pump;
pump.activate();
```

此时经 `sensor` 也会看到 `ACTIVE`，原因是两个引用到达同一实例，不是字段“串了”。诊断状态串扰时，先检查对象身份，再检查方法写入位置。

### 8.1 状态转移至少要验证前后值

调用方法退出 0 只证明没有未处理失败。要证明行为正确，至少读取后置状态：

```java
pump.activate();
assert "ACTIVE".equals(pump.status);
assert "IDLE".equals(sensor.status);
```

第二条隔离断言同样重要：它证明影响范围只在接收者，而不是全局状态。以后加入集合或并发后，这种“正向结果 + 未受影响对象”测试仍然有价值。

## 9. `Scanner` 创建外壳：读懂，不扩大主题

控制台章节出现过：

```java
Scanner scanner = new Scanner(System.in);
```

现在可以从对象角度拆开：左侧类型是 `Scanner`，变量名是 `scanner`；右侧 `new Scanner(System.in)` 创建一个扫描器对象；括号内 `System.in` 是传给创建过程的输入源；最终引用存入 `scanner`。随后 `scanner.next()` 是在该实例上调用方法。

为了固定测试输入，配套示例使用：

```java
Scanner scanner = new Scanner("VALVE-09 RUNNING");
```

它从字符串读取 token，避免交互输入导致验证不稳定。这里仅解释创建外壳与实例调用，不展开 `Scanner` 的全部解析、区域设置、异常和资源生命周期。示例结束时显式 `close()`；何时应关闭标准输入、如何用 `try-with-resources`，属于资源生命周期章节。

不要把 `Scanner` 当语言关键字。它是 `java.util` 包中的普通类，需要 import；它有多个创建入口，具体可用参数由其 API 定义。`new Device()` 与 `new Scanner(...)` 语法骨架类似，但领域职责完全不同。

## 10. 类的职责边界：状态与行为要相互支持

一个类不应该只是任意字段的袋子，也不应成为“什么都做”的万能对象。零基础阶段先用三问判断最小职责：

1. 这些字段是否共同描述同一种实体或值？
2. 这个方法是否主要读取或维护该实例的状态？
3. 修改规则时，是否有一个清晰位置能验证影响？

FactoryCare 的 `Device` 可以有设备编码、状态、维修次数，并提供开始维修、完成维修或描述状态的行为。它不应该自行打开数据库连接、读取登录用户、发短信、渲染 Vue 页面。那些职责属于仓储、权限、通知或界面层。

本章也不要求把所有数据都做成类。一次计算中的临时计数仍适合局部变量；跨边界传输的数据可能用后续的 record/DTO；枚举状态在后续章节学习。类是建模工具，不是把每个变量包进对象的仪式。

## 11. FactoryCare 小模型：两个设备为什么不串状态

```java
Device pump = new Device();
pump.code = "PUMP-01";
pump.status = "IDLE";

Device sensor = new Device();
sensor.code = "SENSOR-07";
sensor.status = "IDLE";

pump.activate();
```

预期：泵变成 `ACTIVE`，传感器保持 `IDLE`。证据链：两次 `new`；引用 `pump != sensor`；方法调用接收者为 `pump`；方法写 `this.status`；调用后分别读取两个实例。

若结果都变了，排查顺序：是否误写成类共享的 `static` 字段（该主题后讲）；是否让两个变量成为别名；方法是否修改了外部共享对象；输出是否读错实例。若都没变，排查方法是否只改了同名局部变量或形参。

领域安全同样需要边界。`device.activate()` 能执行，不代表当前用户有权激活设备，也不代表数据库更新成功。实例方法只处理内存对象职责；身份认证、授权、事务和持久化是另外的契约。不要用“方法在对象里”代替安全设计。

## 12. TypeScript 与 Vue 对照：可迁移的直觉与限制

TypeScript 中也可以写类：

```ts
class Device {
  code = ''
  status = 'IDLE'

  activate() {
    this.status = 'ACTIVE'
  }
}
```

类、实例、字段、方法、`new` 与 `this` 的直觉相似：两次 `new Device()` 得到两个对象，方法中的 `this` 取决于调用接收者。但 Java 的字段和方法声明有明确静态类型，类文件由 JVM 执行；TypeScript 编译后是 JavaScript，运行时规则仍受 JavaScript 影响。

特别注意 `this` 断裂：Java 实例方法的 `this` 由正常方法调用接收者确定，不能像 JavaScript 那样随意把裸函数传递后改变调用绑定；Java 的方法引用和 lambda 在后续章节另讲。不要把 Vue 组合式函数里的闭包状态叫作 Java 实例字段。

Vue 组件定义可以产生多个组件实例，每个实例通常拥有自己的局部状态，这有助于理解“一份定义，多份实例状态”。但 Vue 响应式系统会追踪依赖并触发视图更新，普通 Java 对象字段修改没有这种自动 UI 效果。可迁移的是职责与实例隔离问题，不是框架机制。

## 13. 调试：编译通过但对象没变

### 13.1 先确认接收者身份

当 `pump` 的修改出现在 `sensor` 上，先检查 `pump == sensor`。若为真，是别名；若为假，再检查是否有共享类字段或其他引用。本章只保留身份检查，不用默认 `toString()` 或哈希码猜对象。

### 13.2 检查写入左侧

状态不变时，找到方法内最终赋值语句。左侧是 `this.status`、`this.code` 这样的字段，还是新声明的 `String status`、`int repairCount` 局部变量？计算出正确右侧却没有写回字段，是常见故障。

### 13.3 查看作用域与遮蔽

IDE 高亮、跳转定义或重命名可以显示标识符解析到哪里。`code = code` 的两处可能都是形参；`String status = ...` 明确创建局部变量。不要仅凭缩进判断作用域。

### 13.4 区分编译错误与行为失败

字段名拼错常在 `compile` 阶段报告 `cannot find symbol`；空接收者在运行时产生 `NullPointerException`；遮蔽赋值能正常编译运行，却被后置断言判失败。日志先看阶段，再看第一处自有源码位置，避免在错误层次修复。

### 13.5 修复后做反向检查

修好 `pump.activate()` 后，不只断言泵为 `ACTIVE`，还断言传感器仍为 `IDLE`。修好 `sensor.rename()` 后，再断言泵编码未变。反向检查证明影响范围，而不仅是目标值碰巧正确。

## 14. 测试策略：实例结果、隔离与预期失败

最小类实验应覆盖：

- 两次 `new` 得到不同身份；
- 初始字段按本章显式赋值设置；
- 每个实例方法产生明确后置状态；
- 未接收调用的实例保持不变；
- 查询方法返回当前接收者的字段组合；
- 遮蔽故障可以稳定复现并由断言抓住。

配套工件使用固定输入、固定输出和 Java `assert`，不新增 JUnit 依赖。运行断言程序必须加 `-ea`。验证脚本同时检查预期失败探针的非零退出状态与固定错误文本，避免“脚本继续运行”被误报成故障通过。

不要只测一个实例：单实例测试无法发现状态是否错误共享。也不要只比较最终字符串：至少保留针对字段、身份和未受影响实例的独立断言，错误发生时才能快速定位。

### 14.1 阅读陌生类的固定顺序

面对 AI 生成或同事提交的类，不要从第一行机械读到最后一行。先读类名和一句职责，再列实例字段及其含义；接着列所有会写字段的实例方法，最后列只读取状态的方法。为每个写方法写一行“前置输入—写入字段—后置状态—未改变字段”。这个顺序能快速判断类是否把数据库、网络、界面等外部职责混进来。

然后在调用点找出实际创建次数和接收者。一个方法写对，并不证明调用者把它用在正确实例上；一个实例状态正确，也不证明另一个实例没有被误改。至少选择一次典型调用画出 `变量 → 实例 → 字段`，把 `this` 替换成具体对象名再复述方法体。

最后才看语法细节和格式。若字段含义、行为后置条件或接收者都说不清，漂亮命名与大量注释不能证明设计正确。AI 代码评审尤其要检查它是否偷偷加入 `static`、是否创建了不必要的新实例、是否只改局部变量，以及是否在方法中承担未经授权的外部副作用。

### 14.2 用行为表防止职责漂移

可以为最小 `Device` 建一张行为表：

| 行为 | 读取 | 写入 | 不应承担 |
| --- | --- | --- | --- |
| `activate` | 当前状态 | 当前实例状态 | 发通知、写数据库 |
| `rename` | 新编码参数 | 当前实例编码 | 查询登录用户 |
| `describe` | 当前实例字段 | 无 | 修改状态、访问网络 |

表格不是永久架构合同，却能帮助零基础学习者判断实例方法为何存在。若 `describe()` 一边返回文本一边把状态改成 `VIEWED`，查询行为产生隐藏写入，调用者很难预测；若 `activate()` 顺便创建另一个设备，则接收者边界变得模糊。后续领域建模会增加规则，但“行为名称、读取集合、写入集合、外部副作用”仍是有效评审维度。

### 14.3 默认值窗口为什么需要后续构造器

本章先创建对象再赋字段，因此短时间内 `code` 为 `null`、`status` 为 `null`、次数为 0。这样便于观察字段，却允许调用者在字段未填完时调用方法。若 `describe()` 依赖非空编码，空壳对象就可能产生错误文本或异常。

不要现在用随处判空把窗口补满，也不要把字段默认设成看似合理的业务值来隐藏问题。先把它记录为本章的已知限制：创建与成为合法业务对象之间存在步骤。下一章会比较构造器参数、字段初始化与验证，让对象从可观察的创建点起满足不变量。这条衔接能解释为什么教材暂时写法不是最终最佳实践。

## 15. 安全与可靠性提醒

对象方法的输入仍是不可信输入。`rename(String code)` 若来自接口或扫描枪，可能为空、过长或恶意构造；本章只演示 `trim` 和字段写入，不声称已经完成验证。构造器不变量、接口校验与权限在后续章节建立。

直接可变字段会扩大写入面：任何持有引用且具备访问权限的代码都可能修改状态。后续封装会缩小入口，审计与事务会记录业务改变。现在学习者至少要能列出：谁持有对象引用、哪个方法写哪个字段、写后谁能观察、哪些状态不应被调用者直接伪造。

`Scanner` 也有资源与阻塞边界。来自标准输入或文件的读取可能等待、失败或留下资源；本章固定字符串输入只是为了教学可重复，不代表生产读取方案。不要把固定实验外推为线上安全实现。

## 16. 完整证据循环

### 16.1 Recall：不查资料先回答

类声明会立即创建几个对象？两次 `new Device()` 创建几份字段状态？`pump.activate()` 中 `this` 是类、变量还是实例引用？`String status = "ACTIVE"` 写在方法内会不会修改字段？保存原答案。

### 16.2 Predict：画两个实例表

在运行示例前，按每条语句更新 `pump` 与 `sensor` 的编码、状态和身份关系。对 `Scanner` 行圈出类型、变量名、创建表达式和实参。预测七行输出，不能只写“两个互不影响”。

### 16.3 Build：FactoryCare 设备类

独立定义 `Device` 的 `code/status/repairCount`，实现 `startRepair`、`rename`、`describe`。创建两个实例，交错调用方法，留下编译命令、运行输出、退出状态与十条断言。类文件名和公开类名保持一致。

### 16.4 Break and diagnose：遮蔽故障

把 `this.code = normalized` 改成 `code = normalized`，观察字段不变；把 `this.repairCount = this.repairCount + 1` 改成新建局部变量，观察计数不变。用 IDE 跳转定义确认每个名称属于字段、形参还是局部变量，写一句根因并最小修复。

### 16.5 Change：新增完成维修行为

增加 `completeRepair()`，只把当前实例状态改为 `READY`，不重置维修次数。先写两个实例交错调用的状态表，再写至少三条断言：目标状态变化、目标次数保留、另一个实例不受影响。

### 16.6 No-AI：从空文件复现

关闭 AI，限时 30 分钟，从空文件写一个包含类、三个字段、三个实例方法和两个实例的程序。允许查看 `javac` 帮助与本章速查，不允许复制源码。至少故意制造一次遮蔽错误，保存失败，再修复。

### 16.7 Teach back：120 秒复述

必须覆盖：类与实例不是同一物；一份类声明为何支持多个独立实例；字段与局部变量的生命周期和职责差异；`new` 产生什么；实例方法接收者如何决定 `this`；为什么 `code = code` 可能什么都没改；`Scanner` 创建外壳如何拆；本章为何不声称对象一创建就合法。

## 17. 常见误区与纠正句

1. **“类就是对象。”** 纠正：类声明类型结构和行为，实例才是运行时对象。
2. **“声明变量就创建对象。”** 纠正：声明只建立变量；执行 `new` 等创建表达式才产生实例。
3. **“同一个类的字段只有一份。”** 纠正：实例字段通常每个实例各一份；类共享状态以后由 `static` 明确表示。
4. **“方法修改类。”** 纠正：实例方法通过接收者修改具体实例状态。
5. **“this 是当前类名。”** 纠正：`this` 是当前实例的引用。
6. **“code = code 会更新字段。”** 纠正：同名形参会遮蔽字段，需要明确 `this.code`。
7. **“局部变量算对了，字段自然会变。”** 纠正：必须把结果明确写回字段。
8. **“两个变量就一定两个实例。”** 纠正：变量可能互为别名，要检查创建与赋值步骤。
9. **“字段默认值就是合法默认业务状态。”** 纠正：语言默认值不等于业务不变量，构造器章节再建立合法性。
10. **“对象方法能运行就有权限执行。”** 纠正：内存行为与授权、事务、持久化是不同契约。
11. **“Scanner 是 Java 语法。”** 纠正：它是标准库类，创建与普通类遵循相同表达式骨架。
12. **“一个大类最方便。”** 纠正：类应有清晰状态与行为职责，外部服务边界不要随意混入。

## 18. 复习计划、速查与术语

### 18.1 间隔复习

- 当天：不看源码画出一类两实例，复述 `new` 与 `this`；
- 第 2 天：从空文件重写最小 `Device`，制造并修复遮蔽；
- 第 7 天：完成变更练习，加入第三个实例验证隔离；
- 第 14 天：学完构造器后，把逐字段初始化改为构造时建立合法对象；
- 第 30 天：在 Spring 或 Vue 项目中找一个“定义与实例”对照，说明相似处和边界。

### 18.2 一页速查

| 代码/问题 | 最小结论 |
| --- | --- |
| `class Device { ... }` | 声明类类型、实例字段与行为，不自动等于某个实例 |
| `Device d;` | 声明引用变量，局部变量读取前必须赋值 |
| `new Device()` | 创建新实例并产生引用值 |
| `d.field` | 经非空接收者访问该实例字段 |
| `d.method()` | 以 d 指向的对象为接收者调用实例方法 |
| `this.field` | 当前实例的字段 |
| `field = parameter` | 无遮蔽时可能写字段；同名时建议 `this.field` 明确目标 |
| 两次 `new` | 两次实际执行通常产生两个对象身份 |
| `new Scanner(source)` | 创建标准库对象，source 是创建输入 |
| 字段默认值 | 语言初始化结果，不自动证明业务合法 |

### 18.3 术语表

- **类**：声明一类实例的结构、成员和行为的类型定义。
- **实例**：运行时创建的具体类对象。
- **字段**：属于类或实例的变量；本章聚焦实例字段。
- **局部变量**：声明在方法或代码块内、用于一次计算的变量。
- **实例方法**：以具体对象为接收者执行的方法。
- **接收者**：点号左侧求得、接收实例方法调用的对象引用。
- **`this`**：实例方法执行期间对当前接收者的引用。
- **遮蔽**：内层同名声明使外层成员不能用简单名称直接指代。
- **状态变化**：字段值随行为发生可观察改变。
- **职责边界**：一个类应该管理什么状态和行为，以及明确不承担什么。

## 19. 本章边界与官方来源

本章到此只要求能定义最小类、创建独立实例、读写字段、调用实例方法、解释 `this` 并诊断遮蔽。构造器参数、初始化顺序和不变量紧接下一章；访问修饰符与包、`static`、不可变性、继承和多态分别在后续章节。不要把当前过渡写法包装成最终领域设计。

以下官方资料已于 **2026-07-16** 按 Java SE 25 / JDK 25 复核：

- [Java Language Specification 25, Chapter 8: Classes](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html)：类声明、字段、方法、构造器与成员的语言规则。
- [JLS 25 §15.9 Class Instance Creation Expressions](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.9)：`new` 类实例创建表达式。
- [JLS 25 §15.11 Field Access Expressions](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.11)：实例字段访问、接收者求值与 null 边界。
- [JLS 25 §15.12 Method Invocation Expressions](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.12)：方法调用表达式与接收者。
- [Java SE 25 `Scanner` API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Scanner.html)：扫描器职责、构造入口和 token 读取行为。

稳定核心是“一份类定义、多份实例状态、方法作用于具体接收者”。JDK 补丁版本可能改变实现与诊断细节，却不改变本章要求你验证的对象职责模型。
