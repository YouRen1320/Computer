---
schema_version: 2
edition: 2026.2-draft
id: ch.java.program-structure
title: 注释、标识符、字面量、语句、代码块、class、main 与 package
responsibility: 教授最小 Java 程序的词法和结构规则，不提前要求跨包访问控制或对象实例化
volume: '01'
order: 2
level: L1
status: drafting
path: book/volume-01-java-language/chapters/ch.java.program-structure.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java.platform-toolchain
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
  text: 在 120 秒内解释注释、标识符、字面量、语句、代码块、class、main 与 package的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-lexical-structure
  - java-program-structure
  covers_topics:
  - java.comment-identifier
  - java.literal
  - java.statement-block
  - java.class-declaration
  - java.main-signature
  - java.package-declaration
  uses_capabilities:
  - java.platform-entry
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：独立写出含 package、class、main、注释、字面量、语句和嵌套代码块的最小程序并逐层标注结构
  covers_topic_groups:
  - java-lexical-structure
  - java-program-structure
  covers_topics:
  - java.comment-identifier
  - java.literal
  - java.statement-block
  - java.class-declaration
  - java.main-signature
  - java.package-declaration
  uses_capabilities:
  - java.platform-entry
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入非法标识符、缺分号、括号错位和 package/路径不一致，分别定位词法、语法与结构错误
  covers_topic_groups:
  - java-lexical-structure
  - java-program-structure
  covers_topics:
  - java.comment-identifier
  - java.literal
  - java.statement-block
  - java.class-declaration
  - java.main-signature
  - java.package-declaration
  uses_capabilities:
  - java.platform-entry
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# 注释、标识符、字面量、语句、代码块、class、main 与 package

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《JDK、JVM、源码、class 文件、编译与运行》](ch.java.platform-toolchain.md)：独立完成词法与语句、程序结构前，必须先具备「JDK、JVM、源码、class 文件、编译与运行」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

本章第一次把一份 Java 源文件当成“有语法层级的程序”阅读。目标不是背诵一串关键字，而是能从任意最小程序中找到每一层边界，能自己写出同样的骨架，也能根据 `javac` 的第一条可信错误定位结构故障。

本章版本基线为 **JDK 25**，官方资料复核日期为 **2026-07-16**。注释、标识符、字面量、语句、代码块、普通编译单元、class 和 package 的核心规则属于稳定语言规则。JDK 25 也支持更简化的源文件形式；本路线仍从显式 package、class 和传统 main 开始，因为真实 Java 项目、测试和后续 Spring 代码都需要你看懂这些边界。

## 为什么先学结构

一段代码“看起来像英语”不代表编译器把它看成一句话。编译器先把字符切成 token，再按 Java 语法判断 token 能否组成声明、语句和代码块。一个分号、一对花括号或一个 package 名放错位置，就可能让编译在程序开始运行前终止。

结构知识会直接影响后续工作：

- 阅读 AI 生成代码时，你要先区分文件地址、package、class 和方法边界，才能知道改动应放在哪里；
- 遇到几十行编译日志时，你要先找到第一个文件、行号和插入符，而不是从最后一行猜；
- 新增 FactoryCare 类时，package 与完整类名会决定编译输出位置和启动名称；
- 写单元测试、Spring 控制器或 Flutter/Java 平台代码时，花括号层级错误仍然是最常见的低级故障之一。

完成本章后，你应当能产生三类可观察证据：

1. **解释证据**：在 120 秒内说清本章八个结构的职责，并给出至少一个编译失败反例；
2. **构建证据**：从空文件写出含 package、class、main、注释、字面量、语句和嵌套块的程序，编译并按完整类名运行；
3. **诊断证据**：让非法标识符、缺分号、括号错位、package/路径不一致分别失败，指出失败阶段和第一条可信位置，修复后重跑。

### 前置自检与补救

本章假定你已经完成[Java 平台组成、编译运行链](./ch.java.platform-toolchain.md)，至少能回答：

- `.java` 是源码，`.class` 是 `javac` 的主要编译产物；
- `javac` 负责编译，`java` 负责启动 JVM 并装入类；
- 命令退出码 `0` 表示该次命令成功，非 `0` 表示该次命令失败；
- `javac -version` 与 `java -version` 都应指向 JDK 25 系列。

如果其中任何一项说不清，先运行前置章的正例，再回来。本章不会重新讲环境变量、classpath 搜索算法或 Maven 生命周期。

### 本章明确不讲

- 不讲 `public`、package-private 等跨包访问控制规则；传统 main 中的 `public` 先作为固定入口契约使用；
- 不讲 `new`、构造器和对象实例化；
- 不讲变量类型、运算符、分支、循环、方法设计或异常；
- 不把 package 当成安全边界，也不进入 Java 模块系统；
- 不要求使用 JDK 25 的简化源文件或实例 main 形式。

边界不是遗漏。先把一份普通源文件的结构学稳，后续每个概念才有明确的放置位置。

## 直觉模型：地址、容器、入口、动作

先用四层模型理解最小 Java 程序：

```text
package：类所在的逻辑地址
└── class：声明代码所属的类容器
    └── main：java 启动器进入程序的传统入口
        └── statement：进入后按顺序执行的动作
```

花括号 `{ ... }` 像成对的边界标记：class 有自己的块，main 有自己的块，main 内还可以出现嵌套块。缩进只是人类用来显示层级的排版，真正决定边界的是花括号。

编译器的视角可以再细一层：

```text
Unicode 字符
  → 空白、注释、token
  → package/class/method 等声明与语句
  → 通过语法检查后生成 class 文件
```

token 可以是标识符、关键字、字面量、分隔符或运算符。空白和普通注释主要用于分隔与说明，它们不作为运行时动作执行。

这个模型刻意简化了编译器内部阶段，但足以回答本章问题：**字符是否能组成合法 token，token 是否位于合法结构，结构是否闭合，启动器能否找到约定入口。**

## 先预测，再看完整正例

真实源码保存在[`examples/encyclopedia/ch.java.program-structure`](../../../examples/encyclopedia/ch.java.program-structure/)；正文中的代码与该文件一致，而不是无法验证的孤立片段。

第一次阅读时不要立即运行。先预测：

1. 程序会输出几行？
2. 哪一对花括号属于 class，哪一对属于 main，哪一对只是嵌套块？
3. 哪些行以分号结束，哪些行不以分号结束？
4. 编译产物会位于输出目录下的什么路径？

```java
package com.factorycare.learning;

/*
 * This class keeps every structure used by the chapter in one small file.
 * The comments are intentionally in English so the source is portable across
 * terminals; the chapter explains each line in Chinese.
 */
public class ProgramStructureDemo {
    public static void main(String[] args) {
        // A string literal is passed to a method invocation statement.
        System.out.println("FactoryCare structure ready.");

        {
            // This extra pair of braces is a nested block.
            System.out.println("Nested block reached.");
        }
    }
}
```

预定输出是：

```text
FactoryCare structure ready.
Nested block reached.
```

现在只把 `System.out.println(...)` 当成“把括号中的文本写到标准输出”的固定动作。`System`、`out`、方法调用和 String 类型会在后续章节拆解；本章只识别整条语句、其中的字符串字面量和末尾分号。

## 从左到右拆解最小程序

### 1. package 声明：为类给出完整地址

```java
package com.factorycare.learning;
```

逐个 token 看：

| 源码片段 | 类别 | 本章含义 |
|---|---|---|
| `package` | 保留关键字 | 开始一个 package 声明 |
| `com` | 标识符 | package 名第一段 |
| `.` | 分隔符 | 分隔 package 名的层级 |
| `factorycare` | 标识符 | package 名第二段 |
| `.` | 分隔符 | 再分隔一层 |
| `learning` | 标识符 | package 名第三段 |
| `;` | 分隔符 | 结束 package 声明 |

`com.factorycare.learning` 是 package 的完整名称。本章可以把它理解为逻辑地址，不要把点号理解成文件路径分隔符。源文件中使用点号，macOS/Linux 文件系统常用斜杠，所以推荐目录是：

```text
src/com/factorycare/learning/ProgramStructureDemo.java
```

当命令使用 `javac -d out ...` 时，编译器会按 package 层级组织 class 输出：

```text
out/com/factorycare/learning/ProgramStructureDemo.class
```

在普通编译单元中，package 声明位于 import 和顶层 class 声明之前。它前面可以有空白或注释，但不能先写一条输出语句再声明 package。没有 package 声明的文件属于未命名 package；真实多文件项目不把它作为主线做法。

需要特别纠正一个常见误解：**“目录与 package 不一致”不是在所有 javac 调用形式下都必然立刻报错的独立语法规则。**如果你直接把任意路径的单个源文件交给 `javac`，编译器可能接受文件并按声明 package 输出 class。可是当编译器或构建工具通过 source path 按完整类名寻找源码时，路径指向的文件若声明了另一个 package，就会在编译阶段暴露不一致。本章实验同时观察这两种真实结果，避免背一条过度简化的假规则。

### 2. class 声明：建立类的代码容器

```java
public class ProgramStructureDemo {
    // class body
}
```

本章正式关注的是三个部分：

- `class` 是关键字，表示开始声明一个类；
- `ProgramStructureDemo` 是类的标识符，也是这个类的简单名称；
- 从第一个 `{` 到与它配对的 `}` 是 class body，即类体。

`public` 暂时作为固定修饰符使用，不在这里展开跨包访问规则。在 `javac` 这种基于文件的工具链中，一个 `public` 顶层类通常放在与类名一致的 `.java` 文件中，因此示例文件名为 `ProgramStructureDemo.java`。类名与文件名大小写也要一致。

类声明后的左花括号不是装饰；它开始 class 块。文件末尾最后一个右花括号结束这个块。若少一个右花括号，编译器直到文件末尾仍在等待结构闭合，错误位置可能显示在最后一行，而真正原因发生在更早的左花括号。

### 3. main：传统启动入口

```java
public static void main(String[] args) {
    // statements
}
```

对本路线的普通 class 文件启动方式，先完整记住这个入口形状，再理解每个位置：

| 片段 | 先掌握的含义 | 本章边界 |
|---|---|---|
| `public` | 启动器可使用的传统入口契约组成部分 | 访问控制细节后讲 |
| `static` | 启动器不先创建该类对象就可进入 | 不讲实例与静态成员设计 |
| `void` | 这个入口不向调用者返回一个 Java 值 | 不讲返回语句 |
| `main` | 启动器寻找的入口名称 | 大小写不可随意改 |
| `(` `)` | 包住参数声明 | 分隔符必须配对 |
| `String[]` | 入口接收字符串数组 | String 与数组后讲 |
| `args` | 参数的标识符 | 名字可改，但要合法 |
| `{` `}` | main 的方法体代码块 | 其中语句按顺序执行 |

为什么说 `args` 可以改，而 `main` 不应改？`args` 只是当前源码给这个参数起的标识符；启动器匹配的是入口方法的约定名称与形状。以下改名仍保持传统入口：

```java
public static void main(String[] commandLineArguments) {
    System.out.println("same entry shape");
}
```

下面这个文件则可以通过 Java 语法编译，却不具有本章约定的传统启动入口：

```java
class WrongEntryName {
    public static void start(String[] args) {
        System.out.println("compiled but not launchable as main");
    }
}
```

这是关键的阶段区分：`javac` 只证明源码能否编译；随后 `java ... WrongEntryName` 才会因找不到合适 main 而启动失败。不能把所有故障都叫“编译错误”。

JDK 25 的语言规范还定义了 compact compilation unit 等简化形式，但本章不让两种入口风格混在一起。先掌握显式 class 和传统 main，才能阅读绝大多数已有 Java 工程；简化形式需要时再单独比较。

### 4. 字符串字面量与输出语句

```java
System.out.println("FactoryCare structure ready.");
```

双引号包住的：

```text
"FactoryCare structure ready."
```

是字符串字面量。字面量是在源码中直接写出的固定值表示法。双引号属于源码语法，不是输出内容，所以终端显示时没有双引号。

整行是一个方法调用表达式语句。对本章而言，只需记住：

- `System.out.println(...)` 是固定输出动作；
- `(` 与 `)` 必须配对；
- 字符串的起止双引号必须配对；
- 语句末尾的 `;` 必须存在；
- 运行到这里时才产生一行输出。

不要形成“每行 Java 代码都要分号”的错误口诀。package 声明和这条表达式语句需要分号；class、main 和代码块以花括号界定，不在右花括号后机械添加分号。注释也不以分号结束。

### 5. 嵌套代码块

```java
{
    System.out.println("Nested block reached.");
}
```

代码块是花括号包住的一组块语句。本例中的块位于 main 块内部，因此叫嵌套块。执行进入 main 后，语句按从上到下的顺序运行：先输出第一行，再进入嵌套块输出第二行。

只写空块也符合语法：

```java
{
}
```

它没有可观察输出。空块能编译不代表它有业务价值；这里只用于证明“代码块”和“产生动作的语句”不是同一概念。

缩进四个空格是项目排版约定，不是决定层级的语法。以下代码虽然很难读，但花括号仍决定结构：

```java
class PoorlyFormatted {
public static void main(String[] args) {
System.out.println("legal but hard to review");
}
}
```

编译器接受不等于团队应接受。可读缩进能让人更快发现括号错位，也能降低 AI 修改错误层级的风险。

## 词法层：注释、标识符、关键字与字面量

### 注释不是运行时动作

Java 常见注释形式：

```java
// 行尾注释：到本行结束

/*
 * 跨行注释：从斜杠星号到星号斜杠
 */

/**
 * 文档注释：工具可以把它处理为 API 文档输入
 */
```

语言词法规则把 `// ...` 和 `/* ... */` 视为注释。`/** ... */` 在词法上也是传统块注释，`javadoc` 工具会进一步把合适位置的这种注释解释为文档注释。

三个边界必须知道：

1. 块注释不能嵌套。`/* outer /* inner */ still code */` 会在第一个 `*/` 处结束，后面的字符可能变成非法源码；
2. 字符串里的 `//` 只是字符串内容，不会开始注释，例如 `"https://example.com"`；
3. 普通注释不会输出，也不能用来保存 Token、密码、真实用户数据。源码和 class/构建产物都可能被提交、分发或反编译。

“删除注释不改变程序行为”是适合本章普通注释的模型，但不要把它扩大成“编译出的 class 文件字节必然完全相同”。编译器调试信息等细节可能反映源文件行号变化。本章验证的是结构路径和运行输出，不断言二进制逐字节相同。

### 标识符是程序员给结构起的名字

以下都是标识符：

```text
ProgramStructureDemo
main
args
com
factorycare
learning
```

JLS 25 的精确定义允许标识符使用 Java 字母开头，后续使用 Java 字母或 Java 数字；Java 字母的范围不只 ASCII。对零基础工程实践，可以先用下面的安全子集：

- 首字符用英文字母；
- 后续可用英文字母和数字；
- 不用空格、连字符或点号作为单个标识符的一部分；
- 不用关键字、`true`、`false`、`null` 作名字；
- 大小写敏感，`RepairConsole` 与 `repairConsole` 不是同一标识符。

合法性与命名风格要区分：

| 名称 | 语法判断 | 工程判断 |
|---|---|---|
| `RepairConsole` | 合法 | 适合作为 class 名 |
| `repairConsole` | 合法 | 常用于非 class 名，本章暂不展开 |
| `x1` | 合法 | 含义太弱，真实业务中应更明确 |
| `2RepairConsole` | 非法 | 首字符不能是数字 |
| `repair-console` | 不是单个合法标识符 | `-` 会被看成运算符 |
| `class` | 非法作普通标识符 | 是保留关键字 |
| `维修台` | 规范允许 Unicode 标识符 | 团队、工具与跨语言协作中通常优先英文；这是工程判断而非语法禁止 |

规范因历史原因允许 `$` 和多字符中出现 `_`，但 `$` 主要留给生成代码或兼容场景；单独一个 `_` 在当前 Java 中是关键字，不能当普通名字。初学时不需要靠这些边界设计名称。

### 关键字不是可自由命名的单词

`package`、`class`、`public`、`static` 和 `void` 在示例中都是关键字。关键字由语言保留，在特定语法位置表达固定作用。

`true`、`false` 和 `null` 看起来同样特殊，但 JLS 将前两个归为布尔字面量、后一个归为 null 字面量，而不是保留关键字。这个分类在本章只需会辨认，不需要提前学习 null 或布尔运算。

### 字面量是源码中的固定值写法

本章运行示例只正式使用字符串字面量，但阅读代码时会遇到这些类别：

| 源码 | 类别 | 本章只需识别 |
|---|---|---|
| `42` | 整数字面量 | 直接写出的整数 |
| `3.14` | 浮点字面量 | 直接写出的小数形式 |
| `'A'` | 字符字面量 | 单引号包围的字符 |
| `"ready"` | 字符串字面量 | 双引号包围的文本 |
| `true` | 布尔字面量 | 固定真假值之一 |
| `null` | null 字面量 | 只识别分类，语义后讲 |

同一个可见字符放在不同引号中不是同一种源码结构。`'A'` 与 `"A"` 不能机械互换。缺少结束双引号时，后续字符可能都被误读，编译器通常在当前行给出未闭合字符串等错误。

## 语句、声明和代码块不是同一个层次

初学者常把“每一行”都叫语句。更精确的分类是：

```java
package com.factorycare.learning;                 // package 声明
public class ProgramStructureDemo {               // class 声明 + class 块开始
    public static void main(String[] args) {       // 方法声明 + main 块开始
        System.out.println("ready");               // 表达式语句
        {                                          // 嵌套块开始
            System.out.println("nested");          // 表达式语句
        }                                          // 嵌套块结束
    }                                              // main 块结束
}                                                  // class 块结束
```

这里真正按运行顺序执行的本章语句是两条 `println`。package 和 class 声明描述程序结构；main 声明提供入口；代码块组织其中允许出现的内容。

按“行”判断很危险，因为 Java 允许一条简单语句跨多行：

```java
System.out.println(
    "still one statement"
);
```

也允许多条简单语句写在同一行，尽管可读性很差：

```java
System.out.println("A"); System.out.println("B");
```

所以分号和语法结构比屏幕上的换行更可靠。

## 编译与运行：每一步都有可观察结果

### 目录结构

示例采用：

```text
examples/encyclopedia/ch.java.program-structure/
├── expected-output.txt
├── verify.sh
└── src/
    └── com/factorycare/learning/
        └── ProgramStructureDemo.java
```

`src` 是源码根目录，package 层级位于它下面。验证脚本把 class 写入系统临时目录，结束时清理，不把编译产物混入源码目录。

### 手工编译

从仓库根目录执行：

```bash
WORK_DIR=$(mktemp -d)

javac --release 25 -encoding UTF-8 \
  -d "$WORK_DIR/classes" \
  examples/encyclopedia/ch.java.program-structure/src/com/factorycare/learning/ProgramStructureDemo.java
```

参数在本章的可观察含义：

- `--release 25`：按 Java 25 的受支持语言/API 目标编译；如果 `javac` 太旧，命令应失败而不是静默降级；
- `-encoding UTF-8`：明确源码字符编码；
- `-d "$WORK_DIR/classes"`：把 class 文件写入独立输出根目录；
- 最后一个参数：待编译源文件路径。

编译成功时 `javac` 常常没有普通输出，退出码为 `0`。不要把“终端没显示字”误判为没执行。检查：

```bash
echo "$?"
find "$WORK_DIR/classes" -type f
```

应找到：

```text
.../classes/com/factorycare/learning/ProgramStructureDemo.class
```

### 按完整类名运行

```bash
java -cp "$WORK_DIR/classes" com.factorycare.learning.ProgramStructureDemo
```

`-cp` 指向 class 输出根目录，不是直接指向 `.class` 文件。启动参数使用类的完整名称：

```text
package 名 + 点号 + class 简单名
= com.factorycare.learning.ProgramStructureDemo
```

启动器装入对应 class 并调用传统 main，输出两行后退出码为 `0`。完成后：

```bash
rm -rf "$WORK_DIR"
```

### 一键可重复验证

教材提供的验证命令是：

```bash
bash examples/encyclopedia/ch.java.program-structure/verify.sh
```

脚本不是替代理解的魔法按钮。运行前先预测，运行后再核对它验证了什么：

1. 源码能以 JDK 25 目标编译；
2. class 出现在 package 对应的输出路径；
3. 完整类名可以启动；
4. 实际输出与保存的预言逐字节相同；
5. 临时编译目录被清理。

它没有证明 FactoryCare 的业务逻辑正确，也没有证明你已经能从空文件独立写出程序。

## 边界实验：什么改变行为，什么只改变阅读

### 空白通常分隔 token，但不是任意可删

以下两种排版 token 结构相同：

```java
class Spaced {
    public static void main(String[] args) {
        System.out.println("ready");
    }
}
```

```java
class Spaced{public static void main(String[] args){System.out.println("ready");}}
```

第二种难读，但可编译。若把 `static void` 的空格删成 `staticvoid`，编译器会把它视为一个标识符，而不是两个关键字；程序结构随之失效。由此得到更准确的规则：空白经常不执行，但它可能负责分隔相邻 token。

### 注释也可以分隔 token

```java
static/* explanation */void main(String[] args) {
}
```

词法上注释可以分隔 `static` 与 `void`，但这种写法妨碍阅读，不应作为团队风格。能编译与值得维护仍是两套判断。

### main 参数名不是入口名称

把 `args` 改成 `input`，重新编译后仍可按同一完整类名启动。把 `main` 改成 `start`，源码可能编译成功，但传统启动命令失败。这组对照帮助你区分：

- 语法允许的普通标识符；
- `java` 启动器约定查找的入口名称；
- 编译阶段与启动阶段。

### package 改名会改变完整类名

把：

```java
package com.factorycare.learning;
```

改为：

```java
package com.factorycare.sandbox;
```

再用 `-d` 编译，class 应位于 `com/factorycare/sandbox` 下。继续执行旧名称 `com.factorycare.learning.ProgramStructureDemo` 会找不到主类；新名称才与声明匹配。package 不是只影响源码排版的注释。

## 四类编译故障：先看阶段，再看第一条证据

本章的故障工件保存在[`labs/encyclopedia/ch.java.program-structure`](../../../labs/encyclopedia/ch.java.program-structure/)。执行：

```bash
bash labs/encyclopedia/ch.java.program-structure/verify-failures.sh
```

脚本要求四个用例都以非 `0` 退出，并且日志都包含 `.java:行号`。它把编译器消息语言固定为英文，方便教材和机器验证稳定；你不需要背英文句子，只需掌握位置和原因。

### 故障一：非法标识符

```java
class 2RepairConsole {
}
```

`2RepairConsole` 不能作为一个 class 标识符，因为安全子集规则要求首字符不是数字。JDK 25 的真实首条日志形状是：

```text
.../IllegalIdentifier.java:3: error: <identifier> expected
class 2RepairConsole {
     ^
```

阅读顺序：

1. 文件是 `IllegalIdentifier.java`；
2. 第一条错误在第 3 行；
3. 插入符指向编译器无法继续组成 class 名的位置；
4. `<identifier> expected` 表示该语法位置需要标识符。

不要先处理日志最后的 `1 error`，它只是汇总。

### 故障二：缺少分号

```java
System.out.println("The semicolon is missing")
```

真实日志形状：

```text
.../MissingSemicolon.java:5: error: ';' expected
        System.out.println("The semicolon is missing")
                                                      ^
```

插入符显示编译器到哪里才确认语句没有正常结束。修复是在右括号后添加一个分号，而不是在整份文件所有行尾盲目加分号。

### 故障三：花括号没有闭合

若 class 的左花括号没有对应右花括号，编译器可能到文件末尾才发现：

```text
.../BracketMismatch.java:8: error: reached end of file while parsing
    }
     ^
```

“错误报告在最后一行”不等于“最后一行一定写错”。从报告位置向上按层级配对：嵌套块、main 块、class 块分别有几个左/右花括号。IDE 的括号高亮和格式化能辅助，但最终要能自己数清层级。

### 故障四：package 与按路径期待的类型不一致

故障目录中，`Launcher.java` 期待同一 package 下的 `PackageMismatch`，source path 也在对应路径找到 `PackageMismatch.java`，但后者声明：

```java
package com.factorycare.wrong;
```

于是 javac 报告类似：

```text
.../Launcher.java:5: error: cannot access PackageMismatch
        PackageMismatch.show();
        ^
  bad source file: .../PackageMismatch.java
    file does not contain class com.factorycare.learning.PackageMismatch
```

最先显示的位置是发出依赖请求的 `Launcher.java:5`，随后诊断补充了真正可疑的源文件及期待的完整类名。修复原则不是移动到任意能编译的位置，而是让源码路径、声明 package 和调用方期待的完整名称一致。

这个故障使用了一个固定调用外壳。你不需要在本章解释方法调用、静态设计或访问控制，只需要保持外壳不变，观察编译器如何按完整类名找声明。

### 不属于这四类的启动故障

下面三种情况都可能发生在编译成功之后：

- 使用错误完整类名，启动器找不到主类；
- class 存在但没有传统 main，启动器找不到入口；
- `-cp` 指向 package 子目录而不是 class 输出根目录，类装入失败。

因此诊断表要先写“失败阶段”：

| 证据位置 | 更可能的阶段 | 首要检查 |
|---|---|---|
| `javac` 命令非 0，日志含 `.java:行号` | 编译 | 第一条错误、源码插入符、结构边界 |
| `javac` 为 0，`java` 报找不到主类 | 启动/类路径 | 完整类名、package、class 输出根目录 |
| main 开始输出后才失败 | 运行 | 最先出现的异常类型与源码位置，后续章节详讲 |

### 五步日志阅读法

以后无论日志多长，都先走同一条路径：

1. **确认命令**：失败的是 `javac` 还是 `java`；
2. **确认阶段**：编译失败时不会有本次新程序的正常运行输出；
3. **找第一条错误**：先看第一个 `.java:行号`，再看下一行源码与插入符；不要从汇总或帮助链接开始；
4. **对照插入符与上文结构**：插入符是编译器停止理解的位置，根因可能在更早字符；
5. **一次修一个原因并重跑原命令**：绿色结果必须来自同一验证，不用另写一个更宽松命令绕开。

## 与 JavaScript/TypeScript 的对照

你已有前端经验时，可以借熟悉概念建立桥梁，但不能用 JS 规则替代 Java 规则。

| 主题 | Java | JavaScript/TypeScript | 易错迁移 |
|---|---|---|---|
| 文件入口 | 本章显式 class + 传统 main，由 `java` 启动器查找 | 浏览器脚本、Node 入口或框架入口由运行环境/配置决定 | 以为 Java 源文件从第一条顶层输出自动开始执行 |
| package | 是编译单元声明的逻辑包名，参与完整类名 | ES module 通常由文件路径与 import/export 解析 | 把 package 当成等同于目录字符串或 npm package |
| class | 本章是顶层声明和 main 的容器 | JS class 是运行时语言构造，模块不要求包在 class 中 | 把 Java class 花括号当成可省略的模块包装 |
| 分号 | 某些 Java 声明/语句明确要求 | JS 存在自动分号插入，TS 继承其语法行为 | 忘记 Java 输出语句末尾分号 |
| 标识符 | Unicode 规则、关键字限制、大小写敏感 | 也有标识符与关键字，但集合和上下文不同 | 假定某个 TS 可用名字在 Java 一定可用 |
| 字符串 | 本章使用双引号字符串；单引号表示字符 | JS/TS 单引号和双引号都可表示字符串 | 把 `'ready'` 当成 Java String |
| 代码块 | 花括号决定 class/main/嵌套块边界 | 花括号也常见，但顶层结构和作用域规则不同 | 只看缩进，不数 Java 花括号 |
| 失败阶段 | `javac` 编译与 `java` 启动可分开观察 | TS 转译、打包、浏览器/Node 运行也分阶段 | 把所有红字笼统叫运行错误 |

最重要的共通能力是：看到 AI 生成代码先识别结构层级，再确定错误发生在哪个工具阶段。不同语言的具体规则必须回到对应编译器/运行时验证。

## FactoryCare 中的落点

本章不创建 Spring Boot 项目，只建立未来代码最外层的阅读能力。以“维修受理控制台”作最小占位程序：

```java
package com.factorycare.learning;

class RepairIntakeConsole {
    public static void main(String[] args) {
        System.out.println("FactoryCare repair intake ready");
    }
}
```

你现在能确认：

- `com.factorycare.learning.RepairIntakeConsole` 是完整类名；
- `out` 是 class 输出根目录时，class 路径应包含 `com/factorycare/learning`；
- `RepairIntakeConsole` 是类标识符，输出文本是字符串字面量；
- package 声明和输出语句需要分号；
- class 块包住 main 块，main 块包住输出语句；
- Token、数据库密码或真实工单数据不应写进注释和字面量。

你还不能据此声称会设计 FactoryCare 领域包、跨包 API、对象模型或权限边界。package 能组织名称，不会自动提供业务授权或数据隔离；这些属于后续章节。

## 可靠性与安全边界

这一章没有网络、数据库或用户界面，因此并发、取消、超时和无障碍不是适用主题。但仍有四条工程底线：

1. **源码不放秘密**：注释和字面量都可能进入版本历史、构建产物或日志；示例只用虚构文本；
2. **命令固定版本目标**：保留 `--release 25` 和明确编码，避免“我机器能跑”掩盖工具链漂移；
3. **编译输出与源码分开**：使用 `-d` 写入临时/构建目录，不把 `.class` 混入 `src`；
4. **验证原始预言**：故障修复后重跑原命令并对照原定输出，不用修改期望值来迎合错误实现。

如果 AI 建议“删掉 package 最快”“去掉 `--release` 就能编译”或“把错误文件移出编译范围”，先问它是否修复了契约，还是只绕过了证据。

## 练习阶梯：预测到独立构建

公开题目位于[`exercises/encyclopedia/ch.java.program-structure`](../../../exercises/encyclopedia/ch.java.program-structure/)。它们不附公开答案；答案隔离是为了让预测、故障定位和关闭 AI 训练仍能形成有效证据。

### 第一步：预测

不运行代码，给出输出、分号位置、三层右花括号归属，并判断 `commandLineArguments` 的 token 类别。预测必须写下来，运行后才有可比较对象。

### 第二步：模仿

不复制正例，从空文件写一个新类。模仿的是结构约束，不是背同一段文本。至少改 class 名、字面量和注释内容。

### 第三步：小需求修改

分别修改 main 参数名、空白排版和一个字符串字面量。每次只改一种因素，预测 class 完整名称和输出是否变化，再重新编译。

### 第四步：制造故障

逐个制造非法标识符、缺分号、缺花括号和 package 名漂移。必须记录失败阶段、退出码、第一条错误与修复后的同命令结果。

### 第五步：关闭 AI 独立构建

限时 20 分钟，从空目录创建 `RepairIntake.java`，使用 JDK 25 命令编译、运行，并主动制造/修复一次括号故障。文件存在不算完成；源码、命令输出、预测和 120 秒复述共同构成证据。

## 实验验收

完整实验说明位于[`labs/encyclopedia/ch.java.program-structure`](../../../labs/encyclopedia/ch.java.program-structure/)。核心验收句是：

> 合法程序可编译运行；四类结构错误均在 compile 阶段失败；修复后不改变原定输出。

为了让这句话可判定，实验要求：

- 正例验证退出码为 `0`，输出逐字节匹配保存的预言；
- 四个故障用例都是 `javac` 非 `0`，总数严格为 `4/4`；
- 每个失败日志都有源文件与行号；
- 学习者自己的程序从空文件写出；
- 修复后仍运行原命令，实际输出没有漂移；
- 120 秒复述能区分词法错误、结构编译错误和启动入口错误。

脚本成功只证明工件符合预言，不自动修改学习进度，也不能替代本人独立操作。

## 120 秒复述模板

关闭本章，按下面顺序口述，不照抄原句：

1. package 给类什么名称，为什么运行命令使用完整类名；
2. class 和 main 的花括号分别包住什么；
3. 注释、标识符、关键字、字面量各举一个例子；
4. 语句与屏幕上的“行”为什么不是同一概念；
5. 传统 main 中哪些部分先作为固定契约，哪个参数名可以改；
6. 非法标识符、缺分号、缺花括号、package/路径不一致分别如何观察；
7. 为什么 `javac` 成功仍不等于 `java` 一定能找到入口；
8. 你会如何从第一条日志修复并重跑原验证。

能背出 `public static void main` 但无法解释层级和失败阶段，不算达到本章目标。

## 间隔复习计划

| 时间 | 不看正文完成的检索动作 | 通过信号 |
|---|---|---|
| 学完当天 | 从空文件写 package、class、main 和一条输出语句 | 编译/运行均为 0，能标出每层括号 |
| 第 1 天 | 口述 token 五类，并给出注释/标识符/字面量例子 | 不把注释叫语句，不把 `true` 叫关键字 |
| 第 3 天 | 制造缺分号和缺花括号，先预测第一条日志 | 能从 `.java:行号` 和插入符解释根因 |
| 第 7 天 | 改 package 后解释 class 输出路径与完整类名变化 | 不把点号、斜杠和 classpath 根混为一谈 |
| 第 14 天 | 关闭 AI 完成独立题与 120 秒复述 | 不参考答案也能恢复绿色结果 |

如果某次失败，只补练对应窄项。例如只混淆 package 与路径，就重做 package 实验，不必把整章从头抄一遍。

## 速查表

| 结构 | 最小形状 | 是否运行时动作 | 常见错误 | 首要证据 |
|---|---|---:|---|---|
| package 声明 | `package a.b;` | 否 | 名称/期待路径漂移、位置错误 | 完整类名、class 路径、javac/sourcepath 日志 |
| class 声明 | `class Name {}` | 否 | 非法名称、花括号缺失 | class 名附近或文件末尾编译错误 |
| 传统 main | `public static void main(String[] args) {}` | 是入口 | 改错名称/形状 | 编译可能成功，启动器报告入口缺失 |
| 行尾注释 | `// text` | 否 | 误以为会输出 | 实际输出没有注释内容 |
| 块注释 | `/* text */` | 否 | 试图嵌套、忘记结束 | 后续 token/解析错误 |
| 标识符 | `RepairConsole` | 否 | 数字开头、使用关键字 | `<identifier> expected` 等编译位置 |
| 字符串字面量 | `"ready"` | 作为语句的一部分参与执行 | 引号不配对、误用单引号 | 当前行词法/编译错误 |
| 表达式语句 | `System.out.println("ready");` | 是 | 缺分号 | `';' expected` 附近 |
| 代码块 | `{ ... }` | 组织其中内容 | 括号错位 | 文件末尾或多余右括号处 |

### 最小命令

```bash
javac --release 25 -encoding UTF-8 -d out \
  src/com/factorycare/learning/Program.java

java -cp out com.factorycare.learning.Program
```

### 错误定位顺序

```text
失败命令 → 阶段 → 第一条 .java:行号 → 插入符 → 上文结构 → 单因修复 → 原命令重跑
```

## 术语表

| 术语 | 本章定义 |
|---|---|
| 源文件 | 通常以 `.java` 结尾、交给 Java 编译器读取的文本文件 |
| 编译单元 | 编译器处理的一份 Java 源输入；本章使用含 package 和 class 的普通编译单元 |
| token | 编译器词法处理得到的标识符、关键字、字面量、分隔符或运算符 |
| 注释 | 给人或文档工具阅读、普通运行流程不执行的源码说明 |
| 标识符 | 为 class、参数等程序元素提供名称的 token |
| 关键字 | Java 语言在特定语法中保留的字符序列 |
| 字面量 | 在源码中直接写出的固定值表示法 |
| 声明 | 引入 package、class、main 等程序结构的源码构造 |
| 语句 | 执行时产生动作或控制效果的语法单位；不等同于屏幕上的一行 |
| 代码块 | 一对花括号包围的块语句序列 |
| class body | class 声明花括号内的内容 |
| main | 本路线传统 class 启动方式的程序入口方法名 |
| package | 组织类名称的逻辑命名空间；参与完整类名 |
| 简单类名 | 不含 package 前缀的 class 名，如 `ProgramStructureDemo` |
| 完整类名 | package 名与简单类名组合，如 `com.factorycare.learning.ProgramStructureDemo` |
| class 输出根 | `java -cp` 指向的根目录，其下按 package 层级放置 class 文件 |
| 编译错误 | `javac` 在生成可用 class 前报告的词法、语法、类型或结构等问题 |
| 启动错误 | class 编译后，`java` 在查找/装入类或入口时发生的问题 |

## 来源、版本与适用范围

以下均为 Oracle/OpenJDK 的一手规范或 JDK 工具文档，复核日期为 **2026-07-16**：

1. [Java Language Specification, Java SE 25, Chapter 3: Lexical Structure](https://docs.oracle.com/javase/specs/jls/se25/html/jls-3.html) — 支持 token、空白、注释、标识符、关键字和字面量的分类与边界；
2. [Java Language Specification, Java SE 25, Chapter 7: Packages and Modules](https://docs.oracle.com/javase/specs/jls/se25/html/jls-7.html) — 支持普通编译单元、package 声明、完整名称和基于文件系统的源码组织限制；
3. [Java Language Specification, Java SE 25, Chapter 8: Classes](https://docs.oracle.com/javase/specs/jls/se25/html/jls-8.html) — 支持 class 声明、class body 与成员声明的结构；
4. [Java Language Specification, Java SE 25, Chapter 14: Blocks, Statements, and Patterns](https://docs.oracle.com/javase/specs/jls/se25/html/jls-14.html) — 支持代码块、语句和顺序执行的定义；
5. [JDK 25 `javac` Command](https://docs.oracle.com/en/java/javase/25/docs/specs/man/javac.html) — 支持源码到 class、`--release`、`-encoding`、`-d`、classpath/sourcepath 与输出目录说明；
6. [JDK 25 `java` Command](https://docs.oracle.com/en/java/javase/25/docs/specs/man/java.html) — 支持按主类启动 JVM、完整类名参数和传统 `public static void main(String[] args)` 入口说明；
7. [JDK 25 `javadoc` Command](https://docs.oracle.com/en/java/javase/25/docs/specs/man/javadoc.html) — 支持文档注释由 javadoc 工具进一步处理的说明。

本章的命名风格建议、英文标识符偏好和四空格缩进属于工程判断，不是 JLS 强制语法。示例仅在 macOS arm64、Temurin JDK `25.0.3` 上执行验证；语言规则适用于符合 Java SE 25 的实现，但 Windows 路径分隔、shell 命令写法和不同厂商诊断文本未在本章本地执行。

下一步只做一个动作：关闭正文，先完成公开练习第 1 题的书面预测，再运行任何代码。
