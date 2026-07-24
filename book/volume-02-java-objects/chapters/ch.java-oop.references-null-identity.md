---
schema_version: 2
edition: 2026.2-draft
id: ch.java-oop.references-null-identity
title: 引用、对象身份、null 与内存心智模型
responsibility: 区分值、引用、对象身份与空引用，明确 String 的身份/内容相等与 null/空/空白文本边界，不把示意图等同于 JVM 真实物理布局
volume: '02'
order: 1
level: L1
status: drafting
path: book/volume-02-java-objects/chapters/ch.java-oop.references-null-identity.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java.methods
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
  text: 在 120 秒内解释引用、对象身份、String 的 ==/内容相等、null/空字符串/空白字符串与内存心智模型的边界，并给出一个会失败的反例
  covers_topic_groups:
  - java-reference-model
  - java-null-model
  covers_topics:
  - java.reference-value
  - java.object-identity
  - java.aliasing
  - java.string-identity-content-equality
  - java.null-reference
  - java.null-vs-empty-string
  - java.null-dereference
  - java.stack-heap-mental-model
  uses_capabilities:
  - java.values-types-string
  - java.methods
  - java.references-objects
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：用两个引用指向同一设备对象、另一个等值对象和 null，对比 String 的身份与内容相等，区分 null、空与空白文本，画出赋值前后别名与身份变化，打印验证并生成一页引用与文本边界验证报告
  covers_topic_groups:
  - java-reference-model
  - java-null-model
  covers_topics:
  - java.reference-value
  - java.object-identity
  - java.aliasing
  - java.string-identity-content-equality
  - java.null-reference
  - java.null-vs-empty-string
  - java.null-dereference
  - java.stack-heap-mental-model
  uses_capabilities:
  - java.values-types-string
  - java.methods
  - java.references-objects
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入把 String 的 == 当内容相等、把 null 当空字符串和未判 null 解引用的故障，区分身份、内容、缺失与空白语义后最小修复
  covers_topic_groups:
  - java-reference-model
  - java-null-model
  covers_topics:
  - java.reference-value
  - java.object-identity
  - java.aliasing
  - java.string-identity-content-equality
  - java.null-reference
  - java.null-vs-empty-string
  - java.null-dereference
  - java.stack-heap-mental-model
  uses_capabilities:
  - java.values-types-string
  - java.methods
  - java.references-objects
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 引用、对象身份、null 与内存心智模型

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《方法、参数传递、返回值、重载与递归边界》](../../volume-01-java-language/chapters/ch.java.methods.md)：独立完成引用与对象、null 与内存边界前，必须先具备「方法、参数传递、返回值、重载与递归边界」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。正文与工件可以试读和运行，但不能自动证明学习者已经掌握，更不能自动修改 `PROGRESS.md`。

看到 `Device current = ...` 时，初学者很容易把变量、对象和值混成一件事：以为变量就是对象，以为赋值会复制整个对象，以为两个字段相同的对象就是“同一个”，或者以为 `null` 是空字符串。后续的类、集合、Spring Bean、数据库实体和 Flutter 状态管理都会建立在这些概念上；这里若含糊，错误会在更复杂的代码里放大。

本章建立一个够用且可验证的最小模型：**引用类型变量保存的是引用值；引用值可以指向某个对象，也可以是 `null`；多个引用可以指向同一对象；对象的身份与对象当前保存的状态不是一回事。** 我们会画“变量到对象”的箭头，但明确它只是语义图，不是 HotSpot 的物理内存地图。

本章不完整讲 `equals`/`hashCode` 契约，不讲垃圾收集算法，不讨论压缩对象指针、逃逸分析或对象头，也不要求推断地址。那些内容分别属于对象契约与 JVM 工程章节。版本基线为 **JDK 25**，官方规范复核日期为 **2026-07-16**。

## 1. 学完后必须留下什么证据

“我看懂箭头图了”不是证据。完整学习至少留下三类结果：

1. **解释**：在 120 秒内用自己的话区分变量、引用值、对象、身份、状态、别名与 `null`；说出一张箭头图不能证明什么。
2. **构建**：创建一个设备对象、指向它的两个引用、另一个字段相同但身份不同的对象和一个空引用；先画图，再打印可复现结果。
3. **诊断**：故意把引用 `==` 当作字段等值判断，再故意对 `null` 解引用；根据输出、异常类型和源码行定位并修复。

配套工件：

- [引用与身份观察台](../../../examples/encyclopedia/ch.java-oop.references-null-identity/README.md)
- [FactoryCare 设备引用地图实验](../../../labs/encyclopedia/ch.java-oop.references-null-identity/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-oop.references-null-identity/README.md)

公开练习只给任务和带故障的 starter。私有解析不属于公开教材，不应在第一次作答前搜索或复制。

## 2. 前置自检：变量与方法调用

开始前应能解释：声明给变量规定静态类型；赋值把右侧求得的值存入左侧变量；调用方法时，实参表达式先求值，再把求得的值传入形参；方法返回时可以把一个值带回调用点。

```java
int source = 7;
int copy = source;
copy = 9;
System.out.println(source); // 7
```

这里两个变量各自保存一个 `int` 值。修改 `copy` 不会回头修改 `source`。引用赋值也会复制“变量里的值”，但复制的是引用值；如果两个引用值都指向同一个可变对象，经其中一个引用改变对象状态，另一个引用会观察到变化。**Java 始终按值传递**，引用场景看似特殊，只因被复制的值本身是一条“到对象的引用”。

若你还不能区分变量、赋值、形参和返回值，先回到方法章节。本章不会重新教授方法声明和控制流。

## 3. 两类值：基本值与引用值

Java 语言规范把值的大方向分为基本类型值和引用类型值。`int`、`long`、`double`、`boolean` 等变量保存基本值；类类型、接口类型和数组类型的变量保存引用值。一个引用值可以指向对象，特殊的空引用 `null` 则不指向任何对象。

```java
int priority = 5;          // 基本类型变量，保存整数值 5
String label = "PUMP-01"; // 引用类型变量，保存一个引用值
int[] readings = {3, 4};   // 数组也是对象，变量保存数组引用
```

不要把“引用”简单说成“内存地址”。Java 源代码允许你判断两个引用是否指向同一对象、访问字段或调用方法，却没有承诺把真实地址暴露给你。JVM 可以移动对象、优化表示或使用实现相关的句柄；业务判断不应依赖地址猜测。

一个实用说法是：

- 变量是有名字的存储位置；
- 变量当前保存一个值；
- 引用类型变量保存的值，要么关联到某个对象，要么是 `null`；
- 对象有身份，通常也有可观察状态；
- 变量不是对象，箭头也不是对象的一部分。

## 4. 对象身份与对象状态是两条轴

**身份**回答“是不是同一个对象”；**状态**回答“这个对象当前保存了什么”。两个对象可以状态相同但身份不同，同一对象也可以在不同时刻拥有不同状态。

设设备 A 与设备 B 都有 `code=PUMP-01`、`status=IDLE`。它们可能是两次创建得到的不同对象，因此身份不同；A 状态改为 `RUNNING` 后，A 的身份仍是 A，只是状态变了。反过来，两个变量同时指向 A 时，它们名字不同，却代表同一对象身份。

用表格比一句“对象相等”更清楚：

| 问题 | 关注点 | 本章验证方式 |
| --- | --- | --- |
| `primary` 与 `alias` 是否指向同一个对象 | 身份 | 引用 `==` |
| 两个设备的 `code/status` 是否一样 | 选定字段状态 | 逐项比较固定字段 |
| 修改 `alias` 后 `primary` 看见什么 | 共享对象状态 | 修改后读取 |
| 变量是否没有对象 | 空引用 | `reference == null` |

完整业务等值以后会用 `equals`，还要与 `hashCode` 协作。本章只用逐字段比较建立“状态相同不等于身份相同”的边界，不把完整对象契约提前塞进来。

## 5. 赋值与别名：一步一步执行

观察下面的抽象过程。`Device` 盒子的声明暂时视为配套代码，下一章再拆语法。

```java
Device primary = new Device();
primary.status = "IDLE";
Device alias = primary;
alias.status = "RUNNING";
System.out.println(primary.status);
```

按表达式求值顺序解释：

1. `new Device()` 创建一个新对象，并产生指向该对象的引用值；
2. 引用值存入 `primary`；
3. 经 `primary` 找到对象，把对象字段改为 `IDLE`；
4. 读取 `primary` 中的引用值，把这个值复制进 `alias`；
5. 此时没有复制对象，只新增一个别名；
6. 经 `alias` 找到同一个对象，把字段改为 `RUNNING`；
7. 经 `primary` 再找到同一个对象，因此打印 `RUNNING`。

用语义图表示：

```text
primary ─┐
         ├──> Device A { status = "RUNNING" }
alias   ─┘
```

**别名**是多个引用能到达同一可变对象的现象。它既有价值也有风险：多个方法可以协作修改一个工单，也可能让某处看似局部的修改影响远处观察者。遇到“谁改了我的数据”，先查别名与写入点，而不是先怀疑 JVM 随机变化。

### 5.1 重新赋值不等于修改对象

```java
Device a = new Device();
Device b = a;
b = new Device();
```

第二行后 `a` 与 `b` 是别名；第三行把一个新的引用值存进变量 `b`，不会改变 `a`，也不会把旧对象变成新对象。执行后有两个对象：`a` 指向旧对象，`b` 指向新对象。把“变量改指向”与“对象字段改变”分开，是排查状态问题的第一步。

### 5.2 传参仍是复制引用值

```java
static void markRunning(Device input) {
    input.status = "RUNNING";
}
```

调用 `markRunning(primary)` 时，`primary` 保存的引用值被复制到形参 `input`。方法内两者暂时指向同一对象，所以字段修改可见。如果方法内仅写 `input = new Device()`，只是让局部形参改指向，调用者变量 `primary` 不会自动改指向。这个区别能解释大量“方法里明明赋值了，外面为什么没变”的问题。

## 6. 引用上的 `==`：只回答身份问题

当两侧是可比较的引用时，`==` 判断它们是否都为 `null`，或是否指向同一个对象。它不承诺比较对象内部所有字段。

```java
String left = new String("PUMP-01");
String right = new String("PUMP-01");

System.out.println(left == right); // false：两个对象
```

文本内容相同不代表引用身份相同。若在登录用户名、设备编码或工单状态上使用引用 `==`，程序可能在某些输入“碰巧通过”，在另一些构造路径失败。尤其不要用字符串池的偶然行为证明业务规则。

本章可以说 `left.equals(right)` 比较字符串内容，因为 `String` 已定义该行为；但不要由此推导“所有对象的 `equals` 都自动逐字段比较”。不同类可以定义不同等值语义，完整约束留到对象契约章节。

`left.equals(right)` 还有一个接收者边界：`left` 为 `null` 时无法调用实例方法。两边都允许为空时，可以使用 `java.util.Objects.equals(left, right)`；与固定常量比较时也常写 `"RUNNING".equals(status)`。这些写法只解决技术上的空接收者，不会自动替你决定“两个缺失值是否业务相等”。`equalsIgnoreCase` 也只能在契约明确不区分大小写时使用，不要为了让一个测试通过就改变业务语义。

判断问题时先命名问题：

- 要确认两个变量是不是同一个可变对象：考虑引用 `==`；
- 要确认两个字符串内容相同：调用字符串内容比较；
- 要确认两个领域对象是否业务等值：先定义业务字段与契约，不能猜；
- 要判空：使用 `reference == null` 或 `reference != null`。

## 7. `null`：没有对象，不是空对象

`null` 是特殊的空引用。它可以赋给引用类型变量，表示该变量当前没有指向任何对象。它不是字符串 `"null"`，不是空字符串 `""`，不是数字 0，也不是一个字段全为空的 `Device` 对象。

| 表达形式 | 含义 | 能否调用实例方法 |
| --- | --- | --- |
| `null` | 没有对象 | 不能 |
| `""` | 存在一个长度为 0 的字符串对象 | 可以 |
| `"null"` | 存在一个内容为四个字符的字符串对象 | 可以 |
| 新建但字段为空的设备 | 存在一个设备对象，只是状态可能不完整 | 技术上可以，业务上未必合法 |

空值必须有业务语义。FactoryCare 中 `assignee == null` 可能表示“尚未分配技术员”，而空字符串可能表示“调用方提交了无效 ID”。把两者合并会让查询、审计和接口契约含糊。

```java
static String route(Device device) {
    if (device == null) {
        return "REJECT_MISSING_DEVICE";
    }
    return "ACCEPT:" + device.code;
}
```

这里判空不是为了让红线消失，而是把“没有设备”映射成明确结果。另一种业务可能要求立即拒绝输入或抛出异常；异常契约在后续章节学习。本章先要求空路径显式、可预测、可测试。

## 8. 空引用解引用与 `NullPointerException`

**解引用**是通过引用访问对象成员，例如读字段、写字段或调用实例方法。引用为 `null` 时没有对象可供访问，因此运行时抛出 `NullPointerException`。

```java
StringBuilder note = null;
note.append("inspection");
```

这段通常能编译，因为变量静态类型支持 `append`；失败发生在运行时，实际引用值是 `null`。诊断时区分三个层面：

1. 编译器是否接受类型和语法；
2. 运行到哪一行需要对象；
3. 该行哪个接收者引用是 `null`，它从哪里来。

不要只看到 `NullPointerException` 就在所有地方加 `if (x != null)`。无目的判空可能把数据错误悄悄吞掉。先确认契约：该值允许缺失吗？允许时走什么分支？不允许时应在哪个边界拒绝？

### 8.1 安全的成员访问顺序

```java
if (device != null && "RUNNING".equals(device.status)) {
    System.out.println("dispatch-monitoring");
}
```

`&&` 短路意味着左侧为假时不求值右侧，因此不会访问空引用。但若“缺少设备”本身需要记录错误，仅仅跳过代码还不够，应写清 `else` 或 guard 分支。

字符串常量放在左侧调用 `equals` 可以避免变量为 `null` 时解引用变量；它只解决这一处技术失败，不替代业务空值设计。

## 9. 堆与栈：只保留不误导的简化

教学中常画“局部变量在栈、对象在堆”。这张图有助于区分变量与对象，但不能当作 JVM 实现承诺。JVM 规范和优化实现允许使用寄存器、标量替换、逃逸分析等手段；你从源代码层面通常不该推断对象物理地址。

本章允许使用的简化模型只有：

- 一次方法调用有自己的局部变量环境；
- 局部引用变量保存引用值；
- 对象拥有独立身份与状态；
- 多个局部变量可通过引用到达同一对象；
- 方法结束意味着局部变量不再可用，不等于对象在那一瞬间必然被回收；
- 没有任何可达引用的对象何时回收，由垃圾收集器决定，本章不推断时间。

禁止由图推出：引用大小永远是多少、对象一定放在某个固定地址、`System.identityHashCode` 就是地址、`null` 占一个对象、局部变量一离开作用域内存立刻释放。图的职责是帮助推理可达关系，不是替代 JVM 诊断工具。

## 10. FactoryCare：用引用关系解释真实状态

设维修页面、通知服务和审计代码都拿到同一个内存中工单对象的引用。页面把状态从 `ASSIGNED` 改为 `IN_PROGRESS` 后，其他持有别名的代码可能立即观察到新状态。这并不等于数据库已提交，也不等于其他进程已看到；它只说明当前 JVM 内这些引用到达同一对象。

再设从数据库查询两次得到两个字段相同的 `WorkOrder` 对象。即使 ID、状态和负责人相同，它们也可能是两个 Java 对象身份。用引用 `==` 判断“是否同一业务工单”就会错。业务等值通常由稳定标识与契约决定，后续对象契约和持久化章节再展开。

空引用也要带语义：

- `technician == null`：尚未分配；
- `device == null`：请求无法关联设备，通常应拒绝；
- `closedBy == null`：工单尚未关闭；
- 空字符串 ID：输入存在但无效，不等于未提供对象。

安全问题同样依赖边界。不能因为拿到了一个对象引用就认为当前用户有权修改它；引用可达性不是授权。权限检查、租户隔离和审计属于后续安全章节，但现在要记住：对象存在、引用非空、业务合法、用户有权，是四个不同命题。

## 11. TypeScript 与 Vue 对照：相似处与断裂处

JavaScript/TypeScript 的对象赋值也常表现为共享对象：

```ts
const primary = { status: 'IDLE' }
const alias = primary
alias.status = 'RUNNING'
console.log(primary.status)
```

这能帮助理解别名，但不要把运行模型完全照搬。TypeScript 的类型主要在编译阶段擦除，Java 的引用类型参与编译检查并运行在 JVM 上；Java 字段和方法受类声明约束；Java 的 `null`、未初始化局部变量、字段默认值与 TypeScript 的 `null`/`undefined` 规则不同。

Vue 的 `ref()` 还多包了一层响应式容器：`statusRef.value` 中的 `.value` 是 Vue API，不是 Java 引用语法。Vue 响应式追踪负责通知视图重新计算，Java 普通对象字段变化不会自动刷新页面。可以借“多个组件观察同一响应式对象”理解别名风险，但不能说 Java 引用就是 Vue ref。

跨语言迁移时保留抽象问题：这里复制的是基本值、对象引用，还是框架容器？修改发生在变量、对象字段，还是响应式包装层？谁能观察？什么机制触发更新？

## 12. 调试：从第一条可信证据回溯

### 12.1 状态串扰

症状：修改 `alias.status` 后 `primary.status` 也变化。先打印或断点检查 `primary == alias`；若为真，这是别名的预期结果，不是复制失败。再回到需求判断：应该共享同一对象，还是应该创建独立对象并复制所需状态？不要随便“深拷贝一切”，复制策略必须由业务身份决定。

### 12.2 内容相同却判断失败

症状：两个设备编码看起来一样，`left == right` 却为假。检查代码问的是身份还是内容。若要内容，使用该类型定义的内容比较；若要领域对象等值，明确字段契约。本章实验用固定字段逐项比对，不先发明通用反射比较器。

### 12.3 空引用异常

读取异常的顺序：异常类型；第一处属于自己源码的堆栈行；该行的接收者；接收者的赋值来源；契约是否允许空。修复后重跑原输入，再增加非空输入，避免为了修空路径破坏正常路径。

### 12.4 图与输出矛盾

若图说两个引用指向同一对象，但 `a == b` 为假，图或创建步骤有误。检查是否出现第二次 `new`，是否在方法里重新赋值，是否把字段等值误当身份。图应随着每次赋值更新，而不是运行后凭印象补画。

## 13. 测试与稳定 oracle

引用实验需要稳定断言，而不是肉眼看一串对象打印：

- 身份断言：别名应满足 `a == b`，独立创建应满足 `a != b`；
- String 断言：独立创建的同内容文本可以身份不同但 `equals` 为真；
- 状态断言：经别名写入后从另一引用读取指定字段；
- 隔离断言：独立对象的字段保持原值；
- 空路径断言：`null` 得到明确业务结果；
- 文本空值断言：`null`、`""` 和只含空白的文本使用不同 oracle；
- 失败断言：故障进程非零退出并出现 `NullPointerException` 或自定义故障标记。

不要断言默认 `toString()` 的完整输出、对象哈希码、进程相关地址文本或堆布局，因为它们不是本章契约。固定输入、固定字段、固定行数和固定退出状态才便于重放。

配套脚本使用 Java 自带 `assert` 与 shell 比对，不引入测试依赖。运行断言程序时必须加 `-ea`；未启用断言却看到退出 0，不能声称断言通过。

### 13.1 四格轨迹表：比“我觉得”更可靠

遇到多次赋值时，用四列逐行记录“执行语句、变量中的引用、可达对象、对象状态”。例如先创建 A，再让 `alias` 保存与 `primary` 相同的引用，随后经别名写状态，最后把别名改为 `null`。轨迹应显示：写状态改变的是 A；把 `alias` 置空只改变一个变量；`primary` 仍到达 A，A 的状态仍是新值。

这种表能拆开三种容易混淆的动作：创建新对象会增加一个身份；引用赋值会改变变量保存的值；字段赋值会改变已存在对象的状态。调试时先判断当前语句属于哪一种，再预测影响范围。若一行同时包含方法调用与赋值，先求右侧表达式，再记录左侧变量变化。

对方法传参也可使用相同轨迹：调用前记录调用者变量，进入方法时增加形参变量并复制引用值，方法内写字段时更新共同对象，方法内重绑形参时只更新形参，返回后删除形参那一行。这样无需背“引用传递”之类容易误导的口号，也能正确推导行为。

### 13.2 从输入边界设计 null 测试

一个可空入口至少准备三类输入：明确非空且合法；明确为 `null`；存在对象但字段处于边界状态。只测前两类会把“对象存在”误当“对象有效”。例如设备引用非空，但 `code` 为空字符串，它不会触发空引用异常，却仍可能违反业务契约。

为每类输入写不同 oracle：合法对象返回固定路由；`null` 返回缺失设备；字段非法的对象由后续验证规则拒绝。不要让三种输入都返回空字符串，否则调用者无法区分原因。错误信息也不要输出敏感字段或完整凭据；测试只需固定设备代号与状态。

### 13.3 别名风险的最小变更评审

当 AI 建议“直接把对象传进去修改”时，先回答五问：调用者是否仍持有引用；方法是否会写字段；同一对象是否还被缓存、列表或 UI 状态引用；调用失败时是否可能只写了一半；测试是否证明未受影响对象保持不变。回答不清时，不应仅因代码更短就接受原地修改。

这不意味着所有对象都要复制。共享状态可以是正确设计，例如多个协作方法共同处理一张内存工单。关键是共享必须是契约的一部分，并由身份断言、状态后置条件和失败路径共同证明，而不是偶然别名。

### 13.4 输出一张可复核的验证报告

报告不要只贴终端截图。先写固定输入和预期关系，再写命令、进程退出状态、关键输出和你的解释。身份关系用 A/B 对象标签；状态变化写明由哪个引用发起、从哪个引用再次读取；空路径写明它代表缺失而不是空文本。故障部分保留异常类型与第一处自有源码行，不需要复制整份 JVM 堆栈。

报告最后做事实分级：运行已经证明的事实，例如别名身份为真；根据模型作出的解释，例如引用赋值复制了引用值；尚未验证的推断，例如对象物理位置或回收时间。把三者混成一句“Java 就是这样存内存”会制造过度结论。

若结果与预测不同，不要修改预测伪装一次成功。保留第一次预测，新增“实际—差异—根因—最小修复—复跑”五项。学习价值恰恰来自可追踪的模型修订；最终绿色输出不能替代这个过程。

### 13.5 代码评审时的六条定位问句

看到引用相关变更时逐项问：这里创建了几个对象；哪些变量互为别名；哪一行改变变量指向；哪一行改变对象状态；哪个入口允许 `null`；哪条测试分别证明身份、状态与空路径。六问都有可指向的源码或输出，才算理解了 AI 生成代码。若回答依赖“看起来应该”，就继续缩小示例和加断言。

## 14. 完整练习路径

### 14.1 Recall：先写你的当前模型

不查资料回答：`Device b = a` 会创建几个对象？`b = null` 会不会把 `a` 指向的对象删除？两个字段相同的对象用 `==` 一定是什么结果？`null` 与空字符串分别表示什么？保留原答案，运行后用不同颜色修订。

### 14.2 Predict：逐行预测

对示例写六行预期输出。必须解释每次 `new`、每次引用赋值、一次字段写入和一次空分支。不能只写最终答案。

### 14.3 Build：设备引用地图

完成实验并生成一页验证记录：固定输入、赋值前图、赋值后图、实际命令、退出状态、五行输出、十个断言结果。图中对象使用 A/B 标签，不写虚构内存地址。

### 14.4 Break and diagnose：两个故障

先把字段等值要求写成引用 `==`，保存 `IDENTITY_MISTAKE`；再把安全空分支改成直接读字段，保存异常栈中第一处自有源码行。分别写“一句话根因”和“最小修复”，不得只写“代码有 bug”。

### 14.5 Change：需求变化

新增 `backup` 引用：先让它与独立对象 `peer` 成为别名，再把 `peer` 重新赋值为 `primary`。每一步更新图并预测 `backup == peer`、`peer == primary`。该练习证明重新赋值只影响目标变量，旧对象只要仍可由 `backup` 到达就没有消失。

### 14.6 No-AI：独立复现

关闭 AI 与答案，限时 25 分钟，从空文件写一个最小引用实验：两个别名、一个独立对象、一个 `null`、一次共享写入、六条断言。允许查 `javac` 帮助和本章速查，不允许复制配套源码。完成后才与私有解析比较。

### 14.7 Teach back：120 秒复述

必须覆盖：变量与对象不是同一物；Java 复制引用值而非自动复制对象；别名如何产生；身份与状态如何独立；`==` 在引用上的含义；`null` 为什么不能解引用；堆/栈图的能力边界。最后给一个把 `==` 当业务等值而失败的 FactoryCare 反例。

## 15. 常见误区与纠正句

1. **“引用变量就是对象。”** 纠正：变量保存引用值，对象是该引用可能指向的实体。
2. **“对象赋值会复制对象。”** 纠正：普通引用赋值复制引用值，是否复制对象必须显式设计。
3. **“两个变量名不同就是两个对象。”** 纠正：不同变量可以成为同一对象的别名。
4. **“字段一样就是身份一样。”** 纠正：状态相同与对象身份是两条轴。
5. **“引用 `==` 比较内容。”** 纠正：引用 `==` 回答是否同一对象或是否都为空。
6. **“null 是一个空对象。”** 纠正：`null` 不指向对象，无法访问实例成员。
7. **“判空越多越安全。”** 纠正：判空必须对应明确契约，否则可能掩盖非法数据。
8. **“局部变量离开方法，对象立刻回收。”** 纠正：局部引用失效不等于对象立即回收，还要看其他可达引用与 GC 决策。
9. **“哈希码就是地址。”** 纠正：哈希码是方法结果，不是 Java 语言承诺的物理地址。
10. **“非空就有权限。”** 纠正：引用存在与授权完全不同，安全边界另行验证。

## 16. 复习计划、速查与术语

### 16.1 间隔复习

- 当天：画三张图，分别表示别名、独立对象、空引用；
- 第 2 天：不看书解释重新赋值与字段修改的区别；
- 第 7 天：重做公开练习并注入两类故障；
- 第 14 天：结合类与实例章节解释 `this` 为什么也是指向当前对象的引用；
- 第 30 天：在集合或 Spring 代码中找一个别名风险，说明测试策略。

### 16.2 一页速查

| 语句/问题 | 最小结论 |
| --- | --- |
| `B = A`（引用类型） | 复制 A 当前的引用值，不自动复制对象 |
| `A == B` | 同一对象身份，或两者都为 null |
| `A != B` | 不是同一引用结果；不自动证明字段不同 |
| `A == null` | A 当前没有指向对象 |
| `A.field` 且 A 为 null | 运行时 `NullPointerException` |
| 经别名写字段 | 所有到达同一对象的引用都可观察新状态 |
| 重新给一个别名赋值 | 改变量指向，不直接改旧对象 |
| 堆/栈箭头图 | 语义推理工具，不是物理布局证明 |

### 16.3 术语表

- **引用值**：引用类型表达式产生、变量可保存的值，可能指向对象或为 `null`。
- **对象**：类实例或数组，具有身份，通常具有状态和行为。
- **对象身份**：某对象作为“这一个对象”的连续性，与字段是否相同分开。
- **状态**：对象当前字段或数组元素所保存的可观察数据。
- **别名**：多个引用到达同一对象。
- **空引用**：`null`，不指向任何对象。
- **解引用**：经引用访问实例字段、数组元素或实例方法。
- **可达**：从当前活动引用沿关系能够找到某对象的抽象性质。
- **oracle**：判定实际行为是否符合预期的稳定依据。

## 17. 本章边界与官方来源

本章只建立引用、身份、别名、null 和不误导的内存心智模型。下一章才系统解释类、实例、字段、实例方法和 `new`；再下一章处理构造器与有效状态。完整 `equals/hashCode`、垃圾收集和 JVM 内存诊断分别留到后续章节。

以下官方资料已于 **2026-07-16** 按 JDK 25 / Java SE 25 复核：

- [Java Language Specification 25, Chapter 4: Types, Values, and Variables](https://docs.oracle.com/javase/specs/jls/se25/html/jls-4.html)：引用类型、引用值、对象、变量初始值与多个引用共享对象状态。
- [JLS 25 §15.21.3 Reference Equality Operators](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.21.3)：引用 `==`/`!=` 的身份与 null 语义。
- [JLS 25 §15.11 Field Access Expressions](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.11)：字段访问与空接收者失败边界。
- [Java SE 25 `Object` API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Object.html)：所有类层次的根与对象基础方法；完整对象契约在后章展开。
- [Java SE 25 `String` API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/String.html)：内容相等、空与空白检查的 API 契约。
- [Java SE 25 `Objects.equals`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Objects.html#equals(java.lang.Object,java.lang.Object))：双方均可为 null 时的空安全等值比较。

稳定核心不是某个补丁版本的技巧：变量保存值、引用可能形成别名、对象身份独立于状态、空引用不能解引用，这些原则是后续 Java 工程的基础。版本相关命令仍以本仓库 JDK 25 基线运行结果为准。
