---
schema_version: 2
edition: 2026.2-draft
id: ch.java.methods
title: 方法、参数传递、返回值、重载与递归边界
responsibility: 教授用方法封装可复用行为和参数契约，不提前使用对象字段、泛型或异常作为主要抽象
volume: '01'
order: 8
level: L1
status: drafting
path: book/volume-01-java-language/chapters/ch.java.methods.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java.arrays-command-args
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
  text: 在 120 秒内解释方法、参数传递、返回值、重载与递归边界的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-method-contract
  - java-method-variants
  covers_topics:
  - java.method-declaration-call
  - java.parameter-return
  - java.pass-by-value
  - java.method-overload
  - java.call-stack
  - java.recursion-base-case
  uses_capabilities:
  - java.control-flow
  - java.arrays
  - java.values-types-string
  - java.methods
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：把工单金额和优先级规则拆成有参数、返回值与重载的方法，并为递归倒计时写明确 base case
  covers_topic_groups:
  - java-method-contract
  - java-method-variants
  covers_topics:
  - java.method-declaration-call
  - java.parameter-return
  - java.pass-by-value
  - java.method-overload
  - java.call-stack
  - java.recursion-base-case
  uses_capabilities:
  - java.control-flow
  - java.arrays
  - java.values-types-string
  - java.methods
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入参数顺序传错、分支漏 return、重载歧义和递归无基线，使用编译/调用栈证据修复
  covers_topic_groups:
  - java-method-contract
  - java-method-variants
  covers_topics:
  - java.method-declaration-call
  - java.parameter-return
  - java.pass-by-value
  - java.method-overload
  - java.call-stack
  - java.recursion-base-case
  uses_capabilities:
  - java.control-flow
  - java.arrays
  - java.values-types-string
  - java.methods
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 方法、参数传递、返回值、重载与递归边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《数组、二维数组、查找与命令行参数》](ch.java.arrays-command-args.md)：独立完成方法契约、重载与递归前，必须先具备「数组、二维数组、查找与命令行参数」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。正文和工件可以试读、运行与修改，但通过验证脚本不等于学习者已经完成本章，也不会自动更新学习进度。

到目前为止，许多计算都挤在 `main` 里。同一套“单价乘数量”“判断优先级”“查找数组最大值”如果复制三遍，需求变化时就可能只改两处。**方法**给一段行为一个名字，声明它需要什么输入、产生什么结果，让调用者通过稳定契约使用它，而不必每次展开内部步骤。

方法并不自动让代码更好。参数顺序模糊、返回含义不清、隐藏修改数组、重载难以选择、递归没有终止基线，都可能把错误藏在更深调用链中。本章的目标是学会“小而可验证的方法”：一项职责、明确参数、明确返回、可预测副作用，并能从编译日志或调用栈定位失败。

本章使用同一 class 内的 `static` 方法，避免提前引入对象实例和字段。不教授泛型、高阶函数、复杂递归算法、异常抽象或框架注解；递归只用于观察调用栈与 base case。版本基线为 **JDK 25**，官方规范复核日期为 **2026-07-16**。

## 1. 学完后必须留下什么证据

1. **解释证据**：在 120 秒内说清方法声明、签名、形参与实参、返回类型、作用域、按值传递、重载、调用栈与递归基线；举一个编译失败或运行失败反例。
2. **构建证据**：把 FactoryCare 金额、优先级和工单标签拆成固定输入输出的小方法；演示基本类型与数组引用值的传递差异；为 0、1、多层倒计时提供断言。
3. **诊断证据**：注入参数顺序颠倒、分支漏 return、重载歧义和递归不靠近基线，根据错误阶段、源码位置、实际输出或重复栈帧做最小修复并复跑。

配套入口：

- [方法契约观察台](../../../examples/encyclopedia/ch.java.methods/README.md)
- [参数、重载、作用域与递归边界实验](../../../labs/encyclopedia/ch.java.methods/README.md)
- [公开独立练习：FactoryCare 工单方法拆分](../../../exercises/encyclopedia/ch.java.methods/README.md)

公开练习先独立完成。私有解析只用于首次尝试后的核对，不得进入公开出版物或学习证据。

## 2. 直觉模型：有标签的输入—处理—输出机器

把方法想成一台小机器：调用者把实参放到输入槽；方法为每个形参建立本次调用的局部变量；方法体按顺序执行；遇到 `return` 把结果交回调用点并结束本次调用。

```text
调用点 calculateTotalCents(1999, 3)
             |        |
             v        v
        unitPrice=1999 quantity=3
             \        /
              1999 * 3
                  |
                  v
              返回 5997
```

机器边界由契约描述：两个参数单位都是分；数量不能被误当单价；返回值仍是分；相同输入在当前规则下得到相同结果；方法不偷偷修改与职责无关的状态。实现可以变化，调用者依赖的契约不能无声变化。

## 3. 一个最小方法声明

```java
static int calculateTotalCents(int unitPriceCents, int quantity) {
    return unitPriceCents * quantity;
}
```

从左到右拆解：

- `static`：本章把方法放在 class 上，可从同一 class 的 main 直接调用；对象与静态设计边界以后再学。
- `int`：返回类型，承诺正常完成时产生一个 int。
- `calculateTotalCents`：方法名，描述行为与单位。
- `(int unitPriceCents, int quantity)`：参数列表，声明每个输入的类型、名称和顺序。
- `{ ... }`：方法体，本次调用执行的语句。
- `return`：结束本次方法调用，并把表达式结果交回调用点。

调用：

```java
int result = calculateTotalCents(1999, 3);
System.out.println(result); // 5997
```

先分别求值两个实参，再把它们按位置赋给新建立的形参变量，执行方法体，返回 5997，最后赋给 result。调用者看到方法名与契约，不需要重复乘法细节。

## 4. 方法声明、方法调用与执行不是同一时刻

声明只告诉编译器这个方法存在及其实现。只有执行到调用表达式，方法体才运行：

```java
static int doubleValue(int value) {
    System.out.println("inside=" + value);
    return value * 2;
}

public static void main(String[] args) {
    System.out.println("before");
    int result = doubleValue(4);
    System.out.println("after=" + result);
}
```

输出顺序是 before、inside=4、after=8。JVM 不会因为方法写在 main 上方就先执行它；源码位置不是执行顺序。调用点把控制权转入方法，return 后回到调用点后面的语句。

## 5. 方法签名与“完整声明”的区别

在 Java 重载规则中，方法签名由**方法名和形参类型序列**组成。例如：

```text
formatTicket(int)
formatTicket(int, String)
```

返回类型、形参名字、`public/private/static` 不属于用于区分重载的签名。以下两项不能同时存在：

```java
static int find(int id) { return id; }
static String find(int ticketId) { return "T-" + ticketId; }
```

它们的方法名和形参类型序列都为 `find(int)`，仅返回类型和形参名不同，编译器无法只根据接收位置稳定区分。

日常沟通有时把“完整声明”也简称签名。面试或日志分析时要说明语境：JLS 的签名定义不包含返回类型。

## 6. 形参与实参：声明位置与调用位置

```java
static int calculateTotalCents(int unitPriceCents, int quantity) { ... }
int total = calculateTotalCents(1999, 3);
```

声明中的 `unitPriceCents`、`quantity` 是 parameters（形参）；调用中的 `1999`、`3` 是 arguments（实参）。每次调用都会建立一组新的形参局部变量。

Java 按**位置**匹配，不按形参名字匹配。若两个参数类型相同，颠倒顺序可能仍能编译：

```java
calculateTotalCents(3, 1999); // 编译成功，业务含义颠倒
```

乘法恰好交换不改变结果，但其他方法会暴露错误：

```java
static int remaining(int capacity, int used) {
    return capacity - used;
}
```

`remaining(10, 3)` 为 7，`remaining(3, 10)` 为 -7。参数名带单位、方法保持少量参数、调用前核对契约和边界测试，比依赖编译器更可靠。

## 7. 返回值与 `void`

有结果的方法声明具体返回类型：

```java
static boolean isUrgent(int priority) {
    return priority >= 4;
}
```

不向调用者产生值的方法使用 `void`：

```java
static void printSummary(int count) {
    System.out.println("count=" + count);
}
```

`void` 不是一种可以赋给变量的值。`int x = printSummary(3);` 会编译失败。void 方法可以写 `return;` 提前结束，但不能 `return 3;`。

优先把可计算结果作为返回值，把打印保留给程序边界。返回值容易组合和断言；一个同时计算、打印、修改数组的方法会让测试与复用变困难。本章示例的 main 负责展示，辅助方法主要返回结果。

## 8. 所有正常路径都必须满足返回契约

```java
static String label(int priority) {
    if (priority >= 4) {
        return "URGENT";
    }
    return "NORMAL";
}
```

若删除最后一个 return，priority<4 的路径走到方法体末尾而没有 String，编译器报告 `missing return statement`。这是 compile 阶段错误，不会出现测试运行结果。

另一个可靠结构是先用完整 if/else 给局部变量赋值，再统一 return；选择哪一种取决于可读性。关键是每条能正常完成的方法路径都产生与声明类型兼容的结果。

无限循环、显式抛出和编译器可证明不可达的细节不作为本章技巧。不要用奇怪控制流绕过清楚返回契约。

## 9. `return` 会立即结束当前方法

```java
static String classify(int priority) {
    if (priority < 1 || priority > 5) {
        return "INVALID";
    }
    if (priority >= 4) {
        return "URGENT";
    }
    return "NORMAL";
}
```

priority=0 命中第一个 return，后续判断不执行；priority=5 跳过第一分支，在第二分支返回；priority=2 到达最后 return。这里 guard clause 把非法边界提前结束，减少嵌套。

return 只结束当前方法，不会自动结束整个 JVM。若 main 调用 classify，classify 返回后 main 继续执行。只有 main 自己 return 到末尾且没有其他非守护工作时，主路径才结束。

## 10. 局部变量与作用域

形参和方法体中声明的变量属于本次调用：

```java
static int addFee(int baseCents) {
    int feeCents = 100;
    int totalCents = baseCents + feeCents;
    return totalCents;
}
```

main 不能直接访问 `feeCents`；另一次调用也有自己的 feeCents 与 totalCents。代码块还能形成更小作用域：

```java
if (baseCents > 0) {
    int checked = baseCents;
    System.out.println(checked);
}
// checked 在这里不可见
```

作用域是编译期名称可见范围，不等同于“这个值何时占用内存”的完整运行时模型。初学阶段用它回答：某行能否按名字访问变量；是否遮蔽了另一个变量；数据应通过参数或返回值跨过方法边界，而不是期待局部变量自动共享。

### 10.1 避免无意义遮蔽

```java
static int normalize(int value) {
    if (value < 0) {
        int value = 0; // 编译失败：同一方法范围内重复声明形参名
    }
    return value;
}
```

不要为了“局部化”重用已经有明确含义的名字。若需要结果变量，可用 `normalized`。对象字段与局部变量的遮蔽会在 OOP 章节专门学习。

## 11. Java 参数传递永远是按值传递

调用时，实参表达式先求值，其结果被复制到形参变量。对 int 来说复制的是整数：

```java
static void increase(int value) {
    value++;
}

int priority = 3;
increase(priority);
System.out.println(priority); // 仍是 3
```

调用开始时，priority 的值 3 被复制给新的形参 value。方法只把 value 改成 4，调用者变量 priority 不变。形参不是调用者变量的另一个名字。

这条规则适用于所有参数。差异来自“被复制的值是什么”：基本类型变量里是数值或布尔值；数组变量里是数组引用值。

## 12. 数组参数：复制引用值，不复制整个数组

```java
static void markFirstUrgent(int[] priorities) {
    priorities[0] = 5;
}

int[] batch = {2, 3};
markFirstUrgent(batch);
System.out.println(batch[0]); // 5
```

调用时复制的是“指向该数组的引用值”。形参 priorities 与调用者 batch 是两个变量，却暂时指向同一个数组；通过形参写元素，会修改共享数组。

这仍然是按值传递，不是“数组按引用传递”。用重新赋值可以证明：

```java
static void replaceLocally(int[] priorities) {
    priorities = new int[]{9, 9};
}

int[] batch = {2, 3};
replaceLocally(batch);
System.out.println(batch[0]); // 仍是 2
```

方法只改变自己的形参，让它指向新数组；调用者 batch 保存的引用值未被改写。区分“修改共同数组的元素”和“给形参变量换引用”是 Java 面试与真实故障中的核心。

### 12.1 明确副作用

若方法修改数组，应在方法名、文档和测试中明确：

```java
static void clampPrioritiesInPlace(int[] priorities) { ... }
```

`InPlace` 提醒调用者输入会变化。纯读取的方法不应偷偷改元素。当前不引入不可变集合，只要求副作用可见、范围最小、断言覆盖调用前后。

## 13. 调用实参的求值顺序

Java 从左到右求值每个实参，再进入目标方法：

```java
static int echo(String name, int value) {
    System.out.println(name + "=" + value);
    return value;
}

int result = remaining(echo("capacity", 10), echo("used", 3));
```

先打印 capacity=10，再 used=3，最后调用 remaining 得到 7。业务代码不应依赖带大量副作用的实参来“炫技”；把步骤拆开更易诊断。理解顺序用于读现有代码和日志，而不是鼓励一行塞多个修改。

## 14. 方法重载：同名、不同形参类型序列

```java
static String formatTicket(int id) {
    return "T-" + id;
}

static String formatTicket(int id, String status) {
    return "T-" + id + ":" + status;
}
```

调用 `formatTicket(7)` 选择第一个；`formatTicket(7, "ASSIGNED")` 选择第二个。重载适合同一概念、不同但清楚的输入形式。若两个方法职责不同，仅为了少取一个名字而重载会降低可读性。

编译器根据方法名、实参数量、类型与允许的转换选择最具体的适用方法。选择发生在编译期，不是运行时读形参名字。

### 14.1 返回类型不能单独构成重载

```java
static int parse(String text) { ... }
static long parse(String text) { ... } // 不合法：签名相同
```

即使调用者左边写 long，Java 也不允许只靠期望返回类型区分这两个声明。

### 14.2 数值转换可能让重载含糊

```java
static String route(int first, long second) { return "A"; }
static String route(long first, int second) { return "B"; }

route(1, 1); // 两边各有一个完全匹配和一个扩大转换，调用含糊
```

编译器报告 ambiguous method call。修复不是随便强转一个参数让红线消失，而是检查 API 是否应该有这组重载；常见更清楚的做法是使用不同方法名或明确业务类型。当前不引入自定义值对象。

### 14.3 避免 `null` 重载陷阱

多个引用类型重载接收 null 时可能没有唯一最具体目标。本章不深入引用类型层次；初学代码不要设计只靠相近引用类型区分的重载。用明确方法名通常更易维护。

## 15. 小方法的职责边界

一个可测试小方法通常能用一句“根据 X 计算 Y”描述。例如：

- `calculateTotalCents(unitPriceCents, quantity)`：只计算金额；
- `classifyPriority(priority)`：只返回分类；
- `formatTicket(id, status)`：只构造标签；
- `findMax(priorities)`：只按约定查找最大值。

不要把读取 args、解析、计算、打印、写文件和退出进程混进一个“万能方法”。也不要机械地把每一行抽成方法。抽取价值来自形成稳定契约、消除有意义的重复或隔离复杂规则，而不是追求方法数量。

审查四问：方法名能否说清结果；参数是否都是完成职责所需；返回值是否表达业务结果；副作用是否最小且公开。

## 16. 确定性与可测试性

若方法只依赖参数且不读时间、随机数、环境变量或可变全局状态，相同输入通常得到相同结果：

```java
assert calculateTotalCents(1999, 3) == 5997;
assert calculateTotalCents(1999, 0) == 0;
```

这类方法容易用输入—输出表验证。确定性不等于业务一定正确；如果公式写成加法，相同输入仍会稳定得到错误结果。oracle 必须来自需求和手算，而不是从当前实现复制。

本章不建立完整纯函数理论，只培养习惯：计算方法优先返回结果；外部输入输出放在边界；隐藏状态越少，故障证据越直接。

## 17. 调用栈：每次调用都有自己的执行帧

当 main 调用 calculate，当前执行位置和局部变量需要暂时保存；calculate 完成后回到 main。可以画成：

```text
栈顶  calculateTotalCents: unitPrice=1999, quantity=3
      main: result 尚未赋值，等待调用返回
栈底
```

return 后 calculate 的帧弹出，5997 回到 main。若 calculate 又调用 helper，就会再压入一帧。异常栈从最近失败调用向外列出帧，重复方法名常提示重复调用或递归。

这里的“栈”是理解控制流的模型，不要求计算字节数、JIT 内联或操作数栈。性能调优属于后续内容。

## 18. 递归：方法直接或间接调用自己

最小倒计时步数：

```java
static int countdownSteps(int remaining) {
    if (remaining <= 0) {
        return 0;
    }
    return 1 + countdownSteps(remaining - 1);
}
```

递归必须回答两问：

1. **base case（基线条件）**：什么输入直接返回，不再递归？这里是 remaining<=0。
2. **progress（进展）**：递归调用是否严格靠近基线？这里每次减 1。

`countdownSteps(3)` 的调用链：3 等待 `1 + steps(2)`；2 等待 `1 + steps(1)`；1 等待 `1 + steps(0)`；0 返回 0；随后依次返回 1、2、3。每层有独立 remaining。

### 18.1 0、1、多层边界

| 输入 | 调用层次 | 返回 |
| ---: | --- | ---: |
| 0 | 直接命中基线 | 0 |
| 1 | 1 -> 0 | 1 |
| 4 | 4 -> 3 -> 2 -> 1 -> 0 | 4 |
| -1 | 因 `<=0` 命中基线 | 0 |

若基线只写 `remaining == 0`，负数会继续减小，永远不等于 0。基线必须与允许输入契约一致。

### 18.2 没有基线或方向错误

```java
static int broken(int remaining) {
    return 1 + broken(remaining + 1);
}
```

每次调用增加一层栈帧，最终可能抛出 `StackOverflowError`。它是 Error，不是本章要用 catch 恢复的业务异常。配套探针在独立 JVM、固定小栈中运行并要求非零退出；不要在主程序中故意触发。

本章只用递归理解调用栈、base case 和进展，不教授树遍历、回溯、动态规划、尾调用优化或递归性能技巧。多数简单倒计时用循环更直接。

## 19. 四类故障的阶段与证据

### 19.1 参数顺序传错：逻辑失败

同类型参数颠倒仍可编译、运行并退出 0。第一可信证据是固定 oracle 与实际值不同。修复前先核对调用点参数单位和位置，不要改方法内部公式来迎合错误调用。

### 19.2 分支漏 return：编译失败

错误发生在 `compiler:compile` 或 javac 阶段，日志指向方法并包含 `missing return statement`。测试根本没有启动，不能报告 `Failures: 1`。

### 19.3 重载歧义：编译失败

日志包含可选方法和 `reference ... is ambiguous`。这是 API 形状问题或调用类型不清，不是随机选择其中一个。

### 19.4 递归无基线：运行失败

编译成功，进程运行后 stderr 出现 `StackOverflowError`，栈帧重复同一源码行。修复基线和进展，再用 0、1、多层复跑；只增大线程栈不是逻辑修复。

## 20. 日志与可观察性

方法边界日志应记录业务事件和安全摘要：

```text
event=calculate-total unit=cent quantity=3 result=5997
event=priority-classified input=5 result=URGENT
event=countdown-call remaining=2
```

不要默认打印令牌、完整命令行参数、个人数据或大型数组。递归逐层日志在大输入下会爆炸，本章只对 0..4 小输入观察；生产代码使用汇总、采样或追踪工具，后续专章处理。

调试参数传递时分别打印调用前、方法内和调用后，变量名带角色：`caller.before`、`callee.parameter`、`caller.after`。这能直观看到基本类型形参变化不会回写，而数组元素修改可见。

## 21. 测试方法契约的输入矩阵

金额方法：

| 输入 | 预期 | 目的 |
| --- | ---: | --- |
| 1999, 0 | 0 | 数量零边界 |
| 1999, 1 | 1999 | 单项 |
| 1999, 3 | 5997 | 多项 |

优先级方法检查 0、1、3、4、5、6，覆盖非法、普通和紧急边界。数组副作用检查调用前后元素与调用者引用。递归检查 -1、0、1、4，证明基线和进展。

仅测试“正常值 3”不能证明边界。若 oracle 直接调用同一个待测方法计算期望，就会和实现一起错；期望值应来自手算或独立规则表。

## 22. Java `assert` 与后续 JUnit

实验使用：

```java
assert calculateTotalCents(1999, 3) == 5997;
```

必须通过 `java -ea` 启用。它适合本章零依赖可重放断言，但不是生产输入校验，也没有完整测试报告。后续 Maven/JUnit 章节会建立 `src/test/java`、测试发现和断言报告；当前先理解一个断言必须比较独立预期和实际返回值。

固定 verifier 还核对输出行数、三个编译预期失败和一个独立 JVM 运行预期失败。预期失败必须非零，并含稳定错误片段；否则脚本应失败，而不是把任何 stderr 当成功。

## 23. FactoryCare 方法拆分示例

```java
static int calculateTotalCents(int unitPriceCents, int quantity) {
    return unitPriceCents * quantity;
}

static String classifyPriority(int priority) {
    if (priority < 1 || priority > 5) {
        return "INVALID";
    }
    return priority >= 4 ? "URGENT" : "NORMAL";
}

static String ticketLabel(int id) {
    return "T-" + id;
}

static String ticketLabel(int id, String status) {
    return "T-" + id + ":" + status;
}
```

main 负责提供固定输入并打印。四个方法分别承担金额、分类、简单标签、带状态标签。当前金额使用 int 和小值，只为练习契约；真实金额溢出、负数、货币、BigDecimal 和数据库约束不在本章。

## 24. 实验闭环

进入[参数、重载、作用域与递归边界实验](../../../labs/encyclopedia/ch.java.methods/README.md)。

### 24.1 预测

写下：金额 1999×0/1/3；优先级 0/1/4/5/6；基本类型参数调用前后；数组元素修改与形参重新赋值的差异；两个重载各被哪个调用选择；countdown 0/1/4 的返回与调用链。

### 24.2 运行

```bash
cd labs/encyclopedia/ch.java.methods
./verify.sh
```

有效证据至少包含精确正常输出、`assertions=18 passed`、漏 return/作用域/重载歧义三个编译预期失败、无基线递归一个运行预期失败和 `LAB PASS`。

### 24.3 修改

任选一项：金额增加固定服务费参数；优先级 3 改为 HIGH；标签重载增加区域文本；倒计时从每次减 1 改为减 2并重新定义基线。先写新输入表，防止只改实现不改契约。

### 24.4 故障—修复—复跑

交换 `remaining(capacity, used)` 实参，记录错误但可运行的结果；删除一个 return 看编译日志；加入含糊重载看候选项；把递归 `-1` 改为 `+1` 观察重复栈帧。恢复后完整复跑。

## 25. 公开练习与无 AI 训练

进入[FactoryCare 工单方法拆分](../../../exercises/encyclopedia/ch.java.methods/README.md)，关闭 AI，限时 35 分钟。起始代码可编译，但金额参数顺序、数组副作用和倒计时进展有三个 TODO。公开 verifier 能区分固定起始状态与正确状态。

提交：

- 修复前输入—输出预测和实际；
- 三个方法各自一句契约；
- 0、1、多项金额断言；
- 基本类型与数组参数调用前后日志；
- 递归 0、1、4 调用链；
- 一次漏 return 编译日志的阶段与首个源码位置；
- 120 秒无稿复述。

第一次尝试前禁止读取私有解析。卡住时先把调用点、形参表和返回路径画出来，不让 AI 直接改完整文件。

## 26. 需求变化：先改契约再改实现

原规则 `classifyPriority(3) -> NORMAL`，新需求要求 3 为 HIGH。变更步骤：列受影响输入 2、3、4；写新 oracle；定位唯一规则方法；做最小分支修改；复跑全部边界。若只修改某个调用点，其他调用者仍使用旧规则。

若金额方法新增折扣，不要悄悄把第二参数从 quantity 改成 discount。参数角色变化属于契约变化，应新增清楚参数、更新全部调用和测试。大量同类型参数会增加位置风险；对象建模将在后续章节解决，此处先控制方法规模并使用带单位名字。

重载需求变化也要审查旧调用是否变得含糊。新增一个“看似方便”的重载可能让原本可编译的调用失去唯一最具体目标。

## 27. 安全与可靠性边界

方法名和参数类型不验证数值业务范围。`calculateTotalCents(-1, -2)` 仍能运行，int 乘法还可能溢出。调用者与被调用者必须约定谁负责校验；后续输入、异常和领域对象章节会建立更完整边界。

递归深度若来自不可信输入，可能耗尽线程栈，形成拒绝服务风险。当前倒计时只接受固定小值，生产代码不能把用户提供的百万深度直接递归。数组参数还可能让调用者数据被意外修改；副作用必须文档化并测试。

日志不要打印认证信息。方法返回错误文本也不应泄露内部路径和栈信息给终端用户；本章故障 stderr 仅用于本地教学。

## 28. 常见误解与纠正

### 28.1 “形参名会参与调用匹配”

错误。Java 按位置和类型匹配，调用点通常不携带形参名。两个 int 颠倒仍可能编译。

### 28.2 “改形参就是改调用者变量”

错误。形参得到实参值的副本。基本类型重新赋值不会回写调用者。

### 28.3 “数组是按引用传递”

不准确。传递的仍是值，只是该值是数组引用；双方引用同一数组，所以元素修改可见，形参重新指向新数组不会替换调用者变量。

### 28.4 “返回类型不同就能重载”

错误。重载签名不含返回类型。必须改变形参类型序列或使用不同名字。

### 28.5 “递归只要有 if 就会停”

错误。需要存在覆盖输入的 base case，且每次调用严格靠近它。方向错误仍会栈溢出。

### 28.6 “方法越短越好”

错误。短只是表象；职责、契约、命名、副作用和测试边界更重要。把一行包装成十个无意义方法会增加跳转成本。

## 29. AI 协作审查清单

1. 方法的一句话职责是什么？
2. 每个参数的业务角色、单位、合法范围和顺序是什么？
3. 返回值的单位和空/失败含义是什么？
4. 所有正常路径都 return 了吗？
5. 方法是否修改数组或其他外部可见状态？
6. 基本类型和引用值传递是否被误述？
7. 重载是否表达同一概念，是否可能含糊？
8. 返回类型是否被错误地当作重载区分？
9. 局部变量是否越过作用域或发生误导性遮蔽？
10. 递归 base case 覆盖 0、1、负数吗？每层是否靠近？
11. 固定 oracle 是否独立于实现？
12. 日志、数组副作用和递归深度有什么安全风险？
13. AI 是否提前引入对象、泛型、框架、复杂异常或高阶递归？

## 30. 120 秒复述模板

> 方法把一段行为放在有名字的契约边界中。声明包括修饰符、返回类型、方法名、形参列表和方法体；调用时实参从左到右求值，其值按位置复制到本次调用的新形参变量。Java 永远按值传递：int 形参修改不影响调用者；数组参数复制的是引用值，所以元素修改双方可见，但给形参换一个新数组不替换调用者变量。非 void 方法的每条正常完成路径都要返回兼容值，return 立即结束当前方法。方法签名用于重载时包含方法名和形参类型序列，不包含返回类型或形参名；多个转换同样合适时会编译歧义。每次调用形成自己的局部变量和调用栈帧。递归必须有 base case，并且每次调用靠近它；否则可能 StackOverflowError。测试要覆盖 0、1、多项、边界、编译预期失败与运行预期失败，不能只看方法能调用。

反例：递归 remaining 每次加 1，而基线要求 remaining<=0；从 1 开始永远远离基线，最终栈溢出。

## 31. 自测题

1. 一个方法声明的五个主要组成部分是什么？
2. 声明写在 main 前面是否意味着先执行？
3. JLS 中方法签名包含返回类型和形参名吗？
4. 形参与实参分别出现在哪里？
5. 两个 int 参数颠倒为什么可能编译成功？
6. void 与返回 null 是否相同？
7. 非 void 分支漏 return 属于哪个失败阶段？
8. return 后当前方法与调用者分别发生什么？
9. 方法局部变量能否由 main 直接访问？为什么？
10. `increase(int x)` 内 x++ 为什么不改调用者？
11. 数组元素通过形参修改为什么调用者可见？
12. 给数组形参赋一个新数组为什么不替换调用者变量？
13. 哪些变化能形成合法重载？
14. 为什么仅返回类型不同不能重载？
15. `route(int,long)` 与 `route(long,int)` 调用 `(1,1)` 为何含糊？
16. 调用栈中每一帧保存哪些本章关心的事实？
17. 递归终止需要哪两个条件？
18. 为什么增大线程栈不是无基线递归的正确修复？
19. 相同输入稳定得到相同结果是否足以证明业务正确？
20. 方法修改数组时应留下哪些契约与测试证据？

## 32. 间隔复习

| 时间 | 任务 | 通过证据 |
| --- | --- | --- |
| 当天 | 观察台、实验、公开练习 | 18 断言、4 类预期失败、独立修复 |
| 第 1 天 | 不看书写两个返回值方法 | 声明、调用、返回路径正确 |
| 第 3 天 | 画基本类型/数组参数图 | 能准确说“引用值按值复制” |
| 第 7 天 | 注入漏 return、歧义、无基线 | 按阶段和首个源码位置诊断 |
| 第 14 天 | 修改一项业务规则 | 先改 oracle，所有调用一致 |
| 第 30 天 | 审查 AI 生成服务方法 | 找出副作用、参数与错误契约 |

## 33. 速查表

### 33.1 声明与调用

```text
有返回值       static int name(int value) { return ...; }
无返回值       static void name(int value) { ... }
调用           int result = name(argument);
形参           声明中的 int value
实参           调用中的 argument
按值传递       把实参求值结果复制给新形参变量
局部作用域     形参/局部变量只在声明范围可见
重载签名       方法名 + 形参类型序列
递归基线       直接返回、不再调用自己的输入条件
递归进展       每次调用严格靠近基线
```

### 33.2 现象到首查位置

| 现象 | 首查 |
| --- | --- |
| 结果符号相反 | 同类型参数顺序和单位 |
| `missing return statement` | 是否有正常路径走到方法末尾 |
| `cannot find symbol` | 名称是否越过局部作用域 |
| `reference ... is ambiguous` | 重载候选与实参转换 |
| 调用后 int 不变 | 是否误以为形参会回写 |
| 调用后数组元素变化 | 方法是否通过共享引用修改元素 |
| 给形参 new 后调用者不变 | 只改变了形参变量的引用值 |
| 栈帧反复同一行 | 递归基线或进展方向 |
| 脚本绿但规则错 | oracle 是否独立且覆盖边界 |

## 34. 术语表

| 术语 | 本章定义 |
| --- | --- |
| method | 有名字、参数、返回契约和方法体的行为单元 |
| declaration | 定义方法名称、输入、输出和实现 |
| invocation | 调用方法并转移控制流 |
| parameter | 方法声明中的输入局部变量，也称形参 |
| argument | 调用位置提供并求值的表达式，也称实参 |
| return type | 正常完成时承诺返回的值类型；void 表示不产生值 |
| signature | 用于重载识别的方法名与形参类型序列 |
| pass-by-value | 把实参求值结果复制给形参变量 |
| side effect | 返回值之外可被外部观察的修改或输出 |
| scope | 名称在源码中可被引用的范围 |
| overload | 同一 class 中同名但签名不同的方法 |
| ambiguous invocation | 编译器无法选出唯一最具体目标的调用 |
| call stack | 保存嵌套方法调用位置与局部状态的运行时结构 |
| recursion | 方法直接或间接调用自身 |
| base case | 递归中直接返回、不再递归的输入条件 |
| stack overflow | 调用层次耗尽线程栈时的运行失败 |
| oracle | 独立定义的预期返回、输出、编译失败或运行失败 |

## 35. 本章明确不教什么

本章不教授实例方法、构造器、对象字段、继承、多态、接口、访问控制设计、泛型方法、lambda、高阶函数、方法引用、反射、框架注解、依赖注入或 API 分层；这些需要对象与框架章节。

递归仅限基线、进展、调用栈和安全故障，不教授树/图递归、回溯、分治、动态规划、尾递归优化或性能证明。也不系统教授异常、输入解析、JUnit、BigDecimal 或并发。所有示例使用固定小输入和同一 class 的 static 方法。

## 36. JDK 25 官方来源

以下官方资料复核日期为 **2026-07-16**：

- [Java Language Specification 25, §8.4 Method Declarations](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.4)：方法声明、签名、返回类型、形参与重载约束。
- [JLS 25, §8.4.1 Formal Parameters](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.4.1)：形参声明与作用域。
- [JLS 25, §8.4.5 Method Result](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html#jls-8.4.5)：void 与返回值方法的结果契约。
- [JLS 25, §14.17 The `return` Statement](https://docs.oracle.com/javase/specs/jls/se25/html/jls-14.html#jls-14.17)：return 的控制转移和值要求。
- [JLS 25, §15.12 Method Invocation Expressions](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.12)：目标方法搜索、适用性、最具体方法与运行时调用。
- [JLS 25, §15.12.4.2 Evaluate Arguments](https://docs.oracle.com/javase/specs/jls/se25/html/jls-15.html#jls-15.12.4.2)：实参从左到右求值，以及每个形参初始化为对应实参值。
- [JLS 25, §6.3 Scope of a Declaration](https://docs.oracle.com/javase/specs/jls/se25/html/jls-6.html#jls-6.3)：形参和局部变量的作用域。
- [Java Virtual Machine Specification 25, §2.5.2 Java Virtual Machine Stacks](https://docs.oracle.com/javase/specs/jvms/se25/html/jvms-2.html#jvms-2.5.2)：每个线程的 JVM 栈、帧与 `StackOverflowError` 边界。

规范解释语言如何匹配、传递和返回；实验说明你的方法是否符合 FactoryCare 规则。若 AI 说“数组按引用传递”“返回类型能区分重载”或“递归有 if 就能终止”，应以 JDK 25 规范和固定故障实验纠正。
