---
schema_version: 2
edition: 2026.2-draft
id: ch.java.values-variables-types
title: 值、变量、基本类型、String、作用域与基本输出
responsibility: 教授值在局部作用域中的类型与命名，并用固定输出观察结果，不涉及运算转换或对象身份
volume: '01'
order: 3
level: L1
status: drafting
path: book/volume-01-java-language/chapters/ch.java.values-variables-types.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java.program-structure
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
  text: 在 120 秒内解释值、变量、基本类型、String、作用域与基本输出的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-values-types
  - java-variables-scope
  covers_topics:
  - java.primitive-types
  - java.string-value
  - java.default-vs-local-initialization
  - java.variable-declaration
  - java.assignment
  - java.local-scope-output
  uses_capabilities:
  - java.platform-entry
  - java.values-types-string
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 编写打印设备名称、数量、启用状态和局部作用域变量的程序，显式选择 primitive、String 与初始化时机
  covers_topic_groups:
  - java-values-types
  - java-variables-scope
  covers_topics:
  - java.primitive-types
  - java.string-value
  - java.default-vs-local-initialization
  - java.variable-declaration
  - java.assignment
  - java.local-scope-output
  uses_capabilities:
  - java.platform-entry
  - java.values-types-string
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入局部变量未初始化、作用域外访问和错误类型赋值，读取编译位置后做最小修复
  covers_topic_groups:
  - java-values-types
  - java-variables-scope
  covers_topics:
  - java.primitive-types
  - java.string-value
  - java.default-vs-local-initialization
  - java.variable-declaration
  - java.assignment
  - java.local-scope-output
  uses_capabilities:
  - java.platform-entry
  - java.values-types-string
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 值、变量、基本类型、String、作用域与基本输出

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《注释、标识符、字面量、语句、代码块、class、main 与 package》](ch.java.program-structure.md)：独立完成值与类型、变量与作用域前，必须先具备「注释、标识符、字面量、语句、代码块、class、main 与 package」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。正文和工件已经可以用于试读与技术复核，但尚未通过独立评审，不能据此把学习进度标记为完成。

假设 FactoryCare 收到一条设备记录：设备名称是“空压机-01”，当前有 3 张未关闭工单，设备处于启用状态。程序怎样保存这三个值？为什么数量不能写成任意文本？为什么一个在代码块中声明的名字，出了代码块就找不到了？怎样把程序实际保存的内容打印出来，而不是只凭眼睛猜？

本章回答这些问题。我们只处理**局部作用域里的值和名字**，并用控制台输出观察结果。数值运算、自动类型转换、溢出、对象身份、`null`、类字段设计和完整面向对象模型都在后续章节展开。

## 1. 学完后你要能交付什么

不是“看懂示例”，而是完成三类可观察证据：

1. **解释**：在 120 秒内说清值、类型、变量、初始化、赋值和作用域的关系；能说出 `String` 不是基本类型，以及一个局部变量会编译失败的反例。
2. **构建**：独立写一个控制台程序，保存并输出设备名称、工单数量、启用状态和一个只在局部代码块内可见的值。
3. **诊断**：让局部变量未初始化、越过作用域或收到错误类型的值，找到 `javac` 报告的文件、行及插入符位置（某些构建包装日志还会给出数字列）和原因，再做最小修复。

对应工件：

- [可运行正例](../../../examples/encyclopedia/ch.java.values-variables-types/README.md)
- [可验收实验](../../../labs/encyclopedia/ch.java.values-variables-types/README.md)
- [公开练习（不含答案）](../../../exercises/encyclopedia/ch.java.values-variables-types/README.md)

## 2. 前置知识与补救入口

硬前置是[上一章：Java 程序结构](ch.java.program-structure.md)。开始本章前，你至少需要认得：

- `.java` 源文件、`class` 和 `main`；
- 一条语句通常以分号结束；
- `{}` 形成代码块；
- 字面量是源码里直接写出的值，例如 `3`、`true` 和 `"空压机-01"`；
- 能运行 `javac --release 25 ...` 和 `java ...`，并知道前者编译、后者启动 JVM 进程。

如果这五项中有任何一项说不清，先回到前一章复现最小程序。不要靠记住本章的命令绕过前置，因为本章的故障实验需要你判断失败发生在编译阶段还是运行阶段。

### 开始前的三次预测

先不要运行代码，把预测写在纸上或练习记录里：

```java
int ticketCount = 3;
ticketCount = 4;
System.out.println(ticketCount);
```

1. 最后一行输出 `3`、`4`，还是两个都输出？
2. 如果删掉 `= 3`，直接打印 `ticketCount`，是输出 `0`，还是编译失败？
3. 如果把 `4` 改成 `"四"`，失败发生在编译期还是运行期？

本章后面的模型会让你自己核对，不在这里直接给出练习答案。

## 3. 先建立一个不会误导你的直觉模型

初学时可以把一条局部变量声明想成“创建一个带类型限制的名字卡”：

```java
int openTicketCount = 3;
```

- `int`：类型限制，说明这个名字在当前声明下保存 `int` 值；
- `openTicketCount`：变量名，程序用它找到当前值；
- `3`：一个整数字面量；
- `=`：把右边得到的值交给左边变量；
- `;`：结束这条声明语句。

这个模型比“变量就是一个盒子”更安全，因为它提醒你：**变量有名字、类型、当前值和可见范围**。但它仍是教学简化，不是 JVM 内存布局图。

### 简化内存模型的边界

本章允许你这样想：

- 基本类型变量保存一个基本值；
- `String` 变量让程序使用一段文本；
- 执行新的赋值后，变量的当前值发生变化；
- 离开局部作用域后，变量名不再可用。

本章不允许你据此断言：

- 某个值“一定在栈上”或某个对象“一定在堆上”；
- `String` 变量直接装着全部字符；
- 两个文本相同的变量一定指向同一个对象；
- 离开作用域就会立刻回收内存。

这些结论涉及优化、引用、对象身份、字符串池和垃圾回收。此刻用它们解释一行局部变量代码，只会把尚未验证的实现细节混进语言规则。

## 4. 值、类型和变量不是同一件事

### 4.1 值：程序正在处理的具体内容

`3`、`true`、`'A'` 和 `"空压机-01"` 都可以表示值。值可以来自源码中的字面量，也可以来自输入、方法返回结果或后续计算。本章只使用固定字面量，避免把输入校验和运算规则提前混进来。

### 4.2 类型：可保存值的集合和规则

Java 是静态类型语言。编译器在编译时就知道每个变量和表达式的类型。类型会限制变量可以接受哪些值，也会影响哪些操作有意义。

```java
int openTicketCount = 3;       // 合法：3 是可赋给 int 的整数值
boolean enabled = true;        // 合法：true 是 boolean 值
String deviceName = "空压机-01"; // 合法：双引号得到 String 文本
```

把 `"三"` 交给 `int` 并不会“智能解析”。编译器看到的是文本类型与整数类型不兼容。如何把用户输入转换成数字属于后续输入校验与类型转换章节。

### 4.3 变量：有名字、类型、当前值和作用域的程序实体

变量不是值本身。下面两个变量可以同时保存相同的基本值，但它们仍是两个名字：

```java
int openTicketCount = 3;
int pendingInspectionCount = 3;
```

改动一个变量，不等于改动另一个变量：

```java
openTicketCount = 4;
```

这里的 `=` 是赋值，不是数学等号。它表示先取得右侧的值，再让左侧变量保存该值。表达式求值顺序和复合运算符属于下一章，本章只使用一个字面量作为右侧。

## 5. 声明、初始化和赋值

这三个术语经常被混在一起，但诊断编译错误时必须分清。

### 5.1 声明

声明把变量的类型和名字介绍给编译器：

```java
int openTicketCount;
```

这条语句声明了局部变量，但没有给它初始值。声明存在不代表它已经可以读取。

### 5.2 初始化

变量在声明时第一次得到值，称为初始化：

```java
int openTicketCount = 3;
```

在一条语句里同时完成声明和初始化，通常最容易阅读，也减少“声明了却忘记赋值”的机会。

### 5.3 先声明，后赋值

局部变量也可以在声明后、读取前得到值：

```java
int openTicketCount;
openTicketCount = 3;
System.out.println(openTicketCount);
```

这段代码合法，是因为编译器能证明执行到 `println` 之前，赋值语句必定已经执行。本章只使用直线路径。出现 `if`、循环和异常路径后，“每条可能路径都已经赋值”会变得更重要。

### 5.4 再次赋值

非 `final` 局部变量可以再次赋值：

```java
String statusText = "待确认";
statusText = "运行中";
System.out.println(statusText);
```

第二条语句改变的是变量 `statusText` 当前关联的文本值。它没有把原有 `String` 内容原地改写。`final` 和不可变性的完整区别在后续章节教授，本章只记住：**变量可以重新赋值，不等于文本对象本身可变**。

## 6. Java 的 8 种基本类型

Java 语言预定义了 8 种基本类型（primitive type）。它们不是类类型。

| 类型 | 本章心智用途 | 值域或表示要点 | 值域内示例值 | FactoryCare 示例 |
| --- | --- | --- | --- | --- |
| `byte` | 很小的有符号整数 | -128 到 127 | `4` | 小范围风险级别演示；真实业务更常用 enum |
| `short` | 较小的有符号整数 | -32768 到 32767 | `180` | 维护周期天数演示；通常也可直接用 `int` |
| `int` | 默认的常用整数 | 32 位有符号整数 | `3` | 未关闭工单数量 |
| `long` | 范围更大的整数 | 64 位有符号整数 | `100000001L` | 数字型设备 ID 演示 |
| `float` | 32 位二进制浮点数 | 字面量常用 `F` 后缀 | `58.5F` | 湿度演示；不要用于精确金额 |
| `double` | 默认的常用浮点数 | 64 位二进制浮点数 | `36.5` | 温度演示；仍不是精确十进制金额 |
| `char` | 一个 UTF-16 代码单元 | 0 到 65535，无符号 | `'A'` | 单个区域代码演示 |
| `boolean` | 逻辑状态 | 只有 `true` 和 `false` | `true` | 设备是否启用 |

需要特别守住四个边界：

1. `byte`、`short`、`int`、`long` 的取值范围不同，但怎么自动提升或强制转换属于下一章。
2. `float` 和 `double` 使用二进制浮点表示，不能因为示例显示 `36.5` 就把它们当作任意精度小数。金额建模稍后使用整数分或 `BigDecimal`。
3. `char` 是一个 UTF-16 代码单元，不等于“任意一个人眼看到的 Unicode 字符”。有些字符需要两个 `char`。本章只用 ASCII 区域码 `'A'`。
4. Java 的 `boolean` 不是数字。不能用 `0` 代替 `false`，也不能用 `1` 代替 `true`。

表格中的“值域内示例值”只说明数值落在相应范围，不是在声明这些源码字面量本身就具有 `byte` 或 `short` 类型。为了不在本章偷讲赋值转换，可运行示例中的风险级别和维护周期都使用 `int`；`byte`、`short` 与整数常量之间的赋值规则留到下一章。

### 6.1 为什么示例里有 `L` 和 `F`

源码中的整数字面量默认按 `int` 规则处理；需要明确写出 `long` 字面量时常加大写 `L`。带小数点的浮点字面量默认是 `double`；明确写 `float` 时常加 `F`：

```java
long deviceId = 100000001L;
float humidityPercent = 58.5F;
double temperatureCelsius = 36.5;
```

优先使用大写 `L`，因为小写 `l` 很像数字 `1`。本章只识别这些字面量写法，不讨论转换表达式。

### 6.2 “范围更小就更省”不是业务选型原则

初学者容易把每个小数字都写成 `byte` 或 `short`。实际业务代码中，普通计数优先考虑语义清晰和生态兼容，常用 `int`；只有协议、文件格式、内存密集数据或明确边界才需要特别小的类型。类型选择先表达业务约束，再做有证据的性能优化。

## 7. `String`：本章把它当作不可变文本值使用

`String` 不是第 9 种基本类型。它是 `java.lang.String` 类所表示的引用类型。Java 对字符串字面量提供了特殊语法，所以它看起来和基本类型很接近：

```java
String deviceName = "空压机-01";
```

本章只使用下面三条稳定规则：

- 双引号包围的是字符串字面量，得到 `String` 文本；
- `String` 创建后内容不可变；
- 变量可以再次赋值，让程序随后使用另一段文本。

```java
String statusText = "待确认";
statusText = "运行中";
```

这不表示把“待确认”三个字改造成了“运行中”。这里只能得出变量被重新赋值。至于引用保存什么、字符串池如何工作、`==` 与 `equals`、对象身份和 `null`，全部留给 Java OOP 卷，避免用不完整的引用模型制造错误直觉。

## 8. 局部变量必须在读取前明确赋值

下面的 `openTicketCount` 是 `main` 代码块中的局部变量：

```java
int openTicketCount;
System.out.println(openTicketCount); // 编译错误
```

Java 不会把这个局部 `int` 默认为 `0`。编译器执行“明确赋值”（definite assignment）分析：在每次读取局部变量前，它必须能证明所有可能到达该位置的路径都已经给变量赋值。

最小修复是让赋值发生在读取之前：

```java
int openTicketCount = 0;
System.out.println(openTicketCount);
```

不要看到错误就随手填 `0`。如果 `0` 不是合法业务含义，更好的做法是先取得可信数据，再读取变量。这里用 `0` 只是展示语法闭环。

### 8.1 字段默认值只是边界提示

类变量、实例变量和数组元素在创建时会得到语言规定的默认值；例如数字为零、`boolean` 为 `false`、引用类型为 `null`。这与局部变量不同。

[边界示例 `FieldDefaultBoundary`](../../../examples/encyclopedia/ch.java.values-variables-types/src/main/java/com/factorycare/learning/FieldDefaultBoundary.java)可以复制运行，但本章不要求你创建或设计字段。示例中的 `static` 类字段外壳和打印出的 `null` 都是 **copy-run-only 固定支架**：不要在本章练习中自行改造它们；`static` 会在“类成员与共享状态”章节教授，`null` 与对象身份会在 OOP 卷教授。你现在只需要能回答：

- `main` 代码块里的局部变量不能靠默认值读取；
- 字段有默认值，不代表业务上应该依赖含义不明的默认状态；
- 字段、对象初始化与构造器会在 OOP 章节完整学习。

## 9. 作用域：名字在哪一段源码里有效

作用域（scope）是一个声明引入的名字可以被引用的源码区域。对代码块里声明的普通局部变量，本章使用一个足够准确的规则：从声明位置开始，到直接包围它的代码块结束。

```java
public class ScopeExample {
    public static void main(String[] args) {
        String deviceName = "空压机-01";

        {
            String displaySection = "设备摘要";
            System.out.println(displaySection);
            System.out.println(deviceName);
        }

        System.out.println(deviceName);
        // System.out.println(displaySection); // 已超出 displaySection 的作用域
    }
}
```

内层代码块可以读取在外层已经声明且仍在作用域内的 `deviceName`。但外层后续代码不能读取只存在于内层块的 `displaySection`。

### 9.1 非重叠作用域可以重用名字

两个局部变量的作用域完全不重叠时，可以使用同一个名字：

```java
{
    String displaySection = "设备摘要";
    System.out.println(displaySection);
}

{
    String displaySection = "检查结果";
    System.out.println(displaySection);
}
```

第一段代码块结束后，第一个 `displaySection` 名字已经不在作用域内。第二段声明不会产生歧义。即便语法允许，也要考虑重用是否让读者误以为两个值有持续关系。

### 9.2 Java 不允许局部变量在重叠作用域中同名重声明

这段代码会编译失败：

```java
int openTicketCount = 3;
{
    int openTicketCount = 4; // 编译错误：外层局部变量仍在作用域内
}
```

不要把它误称为“内层变量成功遮蔽外层局部变量”。Java 对局部变量有意禁止这种重叠重声明。字段被局部变量遮蔽是另一条规则，本章只提示存在，不提前教授字段访问和 `this`。

## 10. 用基本输出观察程序状态

`System.out` 是标准输出流。初学阶段可把它理解为程序向终端写内容的现成出口。它的实际类型是 `PrintStream`。

### 10.1 `print`：输出后不主动换行

```java
System.out.print("设备名称：");
System.out.print(deviceName);
```

两次输出会连续出现在当前行。是否换行不能靠“终端看起来自动折行”判断；窗口太窄造成的视觉折行不是程序写入的行分隔符。

### 10.2 `println`：输出后写入平台行分隔符

```java
System.out.println("设备名称：");
System.out.println(deviceName);
```

`println` 在内容之后结束当前行。无参数的 `println()` 只结束一行。

### 10.3 `printf`：按固定格式输出多个值

```java
System.out.printf("设备=%s, 工单数=%d, 启用=%b%n",
        deviceName, openTicketCount, enabled);
```

本章只使用四个格式符：

| 格式符 | 本章用途 |
| --- | --- |
| `%s` | 文本表示 |
| `%d` | 十进制整数 |
| `%b` | 布尔值 |
| `%n` | 平台行分隔符 |

格式字符串与参数类型或数量不匹配，可能在运行时抛出格式化异常。完整格式语法、区域设置和数值精度不在本章范围。业务程序中应把格式模板写成固定代码，把不可信数据作为参数传入；不要把用户输入直接当格式模板。

### 10.4 输出不是验证的替代品

打印适合学习和定位，但“终端出现一行”只能证明这条路径被观察到。它不能自动证明所有输入、边界和失败路径都正确。后续 JUnit 章节会把预期写成可重复断言。本章的实验用固定输出和退出码做 T0 级验证。

## 11. 运行完整正例

正例项目位于 [`examples/encyclopedia/ch.java.values-variables-types`](../../../examples/encyclopedia/ch.java.values-variables-types/README.md)。它使用 JDK 25 和最小 Maven 编译配置，不引入第三方依赖。

从仓库根目录运行：

```bash
cd examples/encyclopedia/ch.java.values-variables-types
mvn clean package
java -cp target/classes com.factorycare.learning.DeviceSnapshot
```

运行前先打开 [`DeviceSnapshot.java`](../../../examples/encyclopedia/ch.java.values-variables-types/src/main/java/com/factorycare/learning/DeviceSnapshot.java)，逐行写下预测：

- 每个变量的类型和值；
- `statusText` 第二次赋值后打印哪段文本；
- 两个独立代码块能否分别声明 `displaySection`；
- 哪些输出会留在同一行，哪些会结束当前行。

再把实际输出与 [`expected-output.txt`](../../../examples/encyclopedia/ch.java.values-variables-types/expected-output.txt)逐行比较。只看 `BUILD SUCCESS` 不够：构建成功证明源码通过了编译，不证明输出符合预期。

## 12. 四类编译失败及日志定位

实验目录提供四个隔离的失败文件。它们必须分开编译，因为一次编译多个错误文件会让日志互相干扰。

| 文件 | 注入故障 | 最先可信证据 |
| --- | --- | --- |
| `UninitializedLocal.java` | 读取尚未赋值的局部变量 | `javac` 的变量可能尚未初始化位置 |
| `OutOfScope.java` | 在代码块外读取内层局部变量 | `cannot find symbol` / 找不到符号的位置 |
| `WrongTypeAssignment.java` | 把 `String` 文本交给 `int` | 不兼容类型位置 |
| `OverlappingLocalName.java` | 在重叠作用域重声明同名局部变量 | 变量已在方法中定义的位置 |

以第一个文件为例：

```bash
cd labs/encyclopedia/ch.java.values-variables-types
javac --release 25 diagnostics/UninitializedLocal.java
```

阅读日志按以下顺序，不要先搜索最后一行：

1. 命令是否真的调用了目标 `javac`；
2. 失败阶段是否为编译，而不是 JVM 运行；
3. 第一个错误指向哪个文件、哪一行，插入符落在哪段源码；
4. 编译器无法确认的名字或类型是什么；
5. 最小修复是否只改变导致错误的规则；
6. 修复后重新编译并运行，是否出现新的证据。

实验的 `verify.sh` 会确认 JDK 25 的 `java`、`javac` 与 Maven 运行时一致，正例输出完全匹配，并逐个核对四个诊断文件的预期错误类别和源码文件名。脚本能拒绝“碰巧以另一种原因失败”，但不会替你解释语言规则或设计最小修复。

## 13. 与 JavaScript / TypeScript 的对照

你已经熟悉 JavaScript、TypeScript 和 Vue，可以利用已有经验，但不能把两套规则直接等同。

| 主题 | Java | JavaScript / TypeScript | 容易踩的坑 |
| --- | --- | --- | --- |
| 运行时类型 | Java 语言在编译期检查静态类型，类型仍影响 JVM 执行 | TypeScript 类型通常在编译后擦除，运行的是 JavaScript | 以为 TS 的类型标注与 Java 类型有相同运行时存在形式 |
| 常用数字 | `byte/short/int/long/float/double` 各有规则 | JS 常用 `number`，另有 `bigint` | 把所有 Java 数字都当成同一种 `number` |
| 未初始化局部变量 | 读取前必须明确赋值，否则编译失败 | `let value;` 在 JS 中读取会得到 `undefined`；TS 规则依配置和控制流而异 | 以为 Java 局部 `int` 会自动得到 `0` |
| 块级名字 | 局部变量有块作用域；不能在重叠作用域重声明同名局部变量 | `let` / `const` 允许内层块遮蔽外层同名变量 | 把 JS 合法的内层 `let count` 原样搬到 Java |
| 文本 | `String` 是引用类型且不可变 | JS 原始 `string` 也是不可变文本值，但类型模型不同 | 因为都“不可变”就推断对象身份规则也相同 |
| 基本输出 | `System.out.print/println/printf` | `console.log` 等控制台 API | 把学习输出当成生产日志或测试断言 |

对照的目的不是评判谁更好，而是定位迁移规则。每当你想说“这和 JS 一样”，再补一句：**语法相似，但编译器、运行时类型和作用域细节是否真的相同？**

## 14. FactoryCare 中的真实落点

本章的最小变量可以映射到真实业务字段，但这只是语言练习，不是最终领域模型：

```java
long deviceId = 100000001L;
String deviceName = "A区-空压机-01";
int openTicketCount = 3;
boolean enabled = true;
char zoneCode = 'A';
```

- `deviceId`：数字型标识示例。真实系统可能选择数据库自增 `long`、UUID 或业务编码，需由数据模型决定。
- `deviceName`：供人识别的文本，不应拿来替代稳定 ID。
- `openTicketCount`：一个快照计数，真实值通常来自查询，不能让前端随意提交后当作事实。
- `enabled`：布尔值只适合真正的二选一语义。若设备有“待启用、启用、停用、报废”等多个状态，应使用受控状态而不是堆叠多个布尔值。
- `zoneCode`：仅用于演示单个 ASCII 代码单元。真实区域编码通常是 `String` 或专门值类型。

后续项目代码会把这些值放进方法、对象、数据库字段和 API DTO。本章只负责让你在进入那些层次前，能准确读写局部值并识别类型错误。

## 15. 安全、隐私与可靠性边界

控制台输出很方便，也很容易泄漏数据。即使是学习项目，也遵守以下规则：

- 不打印 Token、密码、Cookie、私钥、数据库连接串和完整环境变量；
- 不使用真实手机号、身份证号、家庭住址、精确设备位置或真实客户名称做示例；
- 设备名称、故障描述和操作人也可能属于内部敏感信息，公开日志前要脱敏；
- 固定 `printf` 格式模板，不把外部文本直接当格式模板；
- 看到输出不等于数据来源可信，输入校验和服务端授权以后分别处理；
- `System.out` 适合本章观察，不是生产可观测方案。生产日志需要级别、结构化字段、关联 ID、访问控制和保留策略。

本章没有 Web 或移动 UI，因此键盘、焦点、屏幕阅读器和视觉对比度不适用。终端输出仍应避免只靠颜色表达状态；示例使用明确文字和字段名。

## 16. 实验：从预测到独立构建

进入[实验目录](../../../labs/encyclopedia/ch.java.values-variables-types/README.md)，严格按顺序完成：

1. **预测**：不运行代码，写出目标输出和四个失败文件各自的失败阶段。
2. **构建**：只看验收契约，在 starter 中填写设备名称、数量、启用状态和内层局部变量。
3. **观察**：运行公开验证脚本，区分 Maven 构建结果、Java 输出比较和预期编译失败。
4. **破坏**：亲自复现局部变量未初始化、越界访问和错误类型赋值中的至少三项。
5. **诊断**：每次只保留一个故障，记录文件、行列、错误类别、原因和最小修复。
6. **变更**：把设备名称和工单数量替换为新的固定值，先更新预期，再改代码；不要整段重新生成。
7. **关闭 AI**：从空白文件独立写出最小版本，并做 120 秒复述。

公开目录只有任务、失败样例、验收脚本和预期输出，不包含实现答案。隔离答案只供教师批改与仓库自测，不能在独立练习前打开。

## 17. 公开练习与复述

[公开练习册](../../../exercises/encyclopedia/ch.java.values-variables-types/README.md)包含五组任务：概念回忆、输出预测、独立构建、故障诊断和需求变更。请把回答写到自己的学习记录，不修改练习册。

完成后，不看本章，用 60—120 秒回答：

1. 值、类型、变量分别是什么？
2. 声明、初始化和赋值有什么不同？
3. 为什么局部 `int` 不能假定为 `0`？字段默认值为什么不能反推局部变量规则？
4. Java 的 8 种基本类型是什么？`String` 为什么不在其中？
5. 一个代码块内的局部变量何时进入和离开作用域？
6. 为什么 Java 的内层块不能重声明仍在作用域中的外层局部变量？
7. `print`、`println`、`printf` 的最小区别是什么？
8. 看到 `BUILD SUCCESS` 后为什么还要核对程序输出？

如果复述中使用了“应该、好像、差不多”，立刻回到对应失败样例，用一次编译或运行证据替换猜测。

## 18. 间隔复习计划

| 时间 | 不看笔记完成的动作 | 通过证据 |
| --- | --- | --- |
| 学完后 10 分钟 | 写出 8 种基本类型并给出一个 `String` 声明 | 无遗漏，明确 `String` 不是 primitive |
| 第 1 天 | 预测三个局部变量片段是编译失败还是有输出 | 运行后逐项解释差异 |
| 第 3 天 | 从空白文件输出设备名称、数量和启用状态 | `javac` 与 `java` 成功，输出符合先写的预期 |
| 第 7 天 | 注入作用域外访问并依据首条错误修复 | 保存失败和修复后的命令证据 |
| 第 14 天 | 做 120 秒复述并完成一次需求变更 | 不依赖全文，不整段重新生成代码 |

复习不是再读一遍。先回忆、预测和动手，再用本章核对。

## 19. 速查表

### 19.1 最小语法

```java
// 声明并初始化
int openTicketCount = 3;

// 先声明，读取前赋值
boolean enabled;
enabled = true;

// 再次赋值
String statusText = "待确认";
statusText = "运行中";

// 基本输出
System.out.print("设备：");
System.out.println(statusText);
System.out.printf("工单数=%d, 启用=%b%n", openTicketCount, enabled);
```

### 19.2 看到错误时先判断

| 现象 | 先判断 | 本章常见原因 |
| --- | --- | --- |
| `cannot find symbol` / 找不到符号 | 名字在当前位置是否存在且可见 | 拼写错误或超出作用域 |
| `might not have been initialized` / 可能尚未初始化 | 读取前是否每条路径都赋值 | 只声明未赋值 |
| `incompatible types` / 不兼容类型 | 右侧值能否交给左侧类型 | 把文本交给整数等 |
| `already defined` / 已定义 | 同名局部变量作用域是否重叠 | 内层重声明外层局部变量 |
| `IllegalFormat...` | 这是运行时而非编译错误 | `printf` 格式符和参数不匹配 |

### 19.3 本章边界

- 会：局部变量、8 种基本类型、文本 `String`、明确赋值、块作用域、基本输出。
- 暂不会：运算与转换、溢出、输入解析、对象身份、`null`、`final` 完整规则、字段设计、生产日志。

## 20. 术语表

| 术语 | 本章定义 |
| --- | --- |
| value / 值 | 程序处理的具体内容 |
| type / 类型 | 对值集合和可用规则的约束 |
| variable / 变量 | 具有名字、类型、当前值和作用域的程序实体 |
| declaration / 声明 | 把变量的类型和名字引入程序 |
| initialization / 初始化 | 变量第一次获得值 |
| assignment / 赋值 | 把右侧得到的值交给左侧变量 |
| primitive type / 基本类型 | Java 预定义的 8 种非引用类型 |
| reference type / 引用类型 | 类、接口、数组等类型；本章只把 `String` 作为文本使用 |
| scope / 作用域 | 一个声明引入的名字可以被引用的源码区域 |
| definite assignment / 明确赋值 | 编译器证明局部变量在读取前必定已经赋值 |
| standard output / 标准输出 | `System.out` 所代表的默认输出目的地 |

## 21. 版本与官方来源

本章目标版本为 **JDK 25（`25.x LTS`）**，稳定语义以 Java Language Specification 为准，API 行为以 Java SE 25 文档为准。以下资料于 **2026-07-16** 复核：

- [JLS 25 第 4 章：Types, Values, and Variables](https://docs.oracle.com/javase/specs/jls/se25/html/jls-4.html)：静态类型、基本类型、变量种类与默认值边界。
- [JLS 25 §6.3：Scope of a Declaration](https://docs.oracle.com/javase/specs/jls/se25/html/jls-6.html#jls-6.3)：局部变量作用域。
- [JLS 25 §6.4：Shadowing and Obscuring](https://docs.oracle.com/javase/specs/jls/se25/html/jls-6.html#jls-6.4)：重叠作用域中的局部同名声明限制。
- [JLS 25 第 14 章：Blocks, Statements, and Patterns](https://docs.oracle.com/javase/specs/jls/se25/html/jls-14.html#jls-14.4)：局部变量声明语句与初始化。
- [JLS 25 第 16 章：Definite Assignment](https://docs.oracle.com/javase/specs/jls/se25/html/jls-16.html)：局部变量读取前的明确赋值规则。
- [Java SE 25 `String`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/String.html)：`String` 表示文本、不可变及 UTF-16 边界。
- [Java SE 25 `System`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/System.html)：标准输出 `System.out`。
- [Java SE 25 `PrintStream`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/PrintStream.html)：`print`、`println`、`printf` 的 API 行为。

Java 25 还提供了新的 `java.lang.IO` 简化入口，但本课程主线继续使用行业代码中普遍可见的 `System.out`，并让同一示例在更宽的 Java 版本范围内保持可读。这里是教学路线选择，不是说 `IO` 不可用。

---

下一章会在这些值和类型之上学习运算符、表达式、数值转换与溢出。进入下一章前，最低门槛不是背完类型范围，而是能独立构建、预测、制造并修复本章三类核心失败。
