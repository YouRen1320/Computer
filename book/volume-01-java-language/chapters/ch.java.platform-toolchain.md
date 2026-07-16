---
schema_version: 2
edition: 2026.2-draft
id: ch.java.platform-toolchain
title: JDK、JVM、源码、class 文件、编译与运行
responsibility: 建立 Java 源码到 JVM 进程的运行链，不提前解释 main 声明内部语法或对象模型
volume: '01'
order: 1
level: L1
status: drafting
path: book/volume-01-java-language/chapters/ch.java.platform-toolchain.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.foundations.dependencies-build-packages
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
  text: 在 120 秒内解释JDK、JVM、源码、class 文件、编译与运行的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-platform
  - java-run-chain
  covers_topics:
  - java.jdk-jre-jvm
  - java.source-class-bytecode
  - java.classpath
  - java.javac-java-command
  - java.compile-run-phase
  - java.tool-version-evidence
  uses_capabilities:
  - foundation.shell-command-stream
  - foundation.toolchain-env-build
  - java.platform-entry
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 用固定 main 外壳从 .java 编译出 .class 并运行，记录 javac/java 的实际路径、版本、classpath 与进程退出码，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - java-platform
  - java-run-chain
  covers_topics:
  - java.jdk-jre-jvm
  - java.source-class-bytecode
  - java.classpath
  - java.javac-java-command
  - java.compile-run-phase
  - java.tool-version-evidence
  uses_capabilities:
  - foundation.shell-command-stream
  - foundation.toolchain-env-build
  - java.platform-entry
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入 source/target 版本不兼容或 classpath 缺失，判断失败在编译还是 JVM 加载阶段并恢复运行
  covers_topic_groups:
  - java-platform
  - java-run-chain
  covers_topics:
  - java.jdk-jre-jvm
  - java.source-class-bytecode
  - java.classpath
  - java.javac-java-command
  - java.compile-run-phase
  - java.tool-version-evidence
  uses_capabilities:
  - foundation.shell-command-stream
  - foundation.toolchain-env-build
  - java.platform-entry
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# JDK、JVM、源码、class 文件、编译与运行

本章先解决一个很实际的问题：你写下的 `ToolchainSmoke.java` 只是文本，为什么计算机最后能打印一行结果？中间究竟是谁读源码、谁生成文件、谁启动进程？如果命令失败，怎样判断错误发生在“编译前”“编译时”还是“运行时”？

这一条运行链是后续所有 Java 学习的地基。先看懂它，再学变量、分支、类和 Spring，遇到红色日志时才不会只能把整段错误交给 AI 猜。

## 学完以后，你应当能观察到什么

完成本章后，你应当能够在没有 AI 代写命令的情况下：

1. 用自己的话区分 JDK、JVM、源码和 class 文件，并说明它们不是四种“编程语言”；
2. 找出终端实际调用的 `java` 与 `javac`，记录二者版本和 `JAVA_HOME`；
3. 用 `javac` 把固定的 Java 源文件编译到指定目录，再用 `java -cp` 启动它；
4. 用文件变化、命令输出和退出码证明每个阶段确实发生过；
5. 面对“版本不受支持”和“找不到主类”两类故障，先判断失败阶段，再修复并重跑原命令。

这里的“会”不是“看过命令”。验收证据必须包含输入文件、实际命令、输出、退出码和修复后的复跑结果。

## 前置知识与补救入口

本章假定你已经接触过[依赖、包管理、构建生命周期与可重复性](../../volume-00-computer-foundations/chapters/ch.foundations.dependencies-build-packages.md)，并知道：

- 命令是由 shell 查找并启动的程序；
- 标准输出、标准错误和退出码是三类不同证据；
- 同名工具可能安装多份，`PATH` 决定当前 shell 先找到哪一份；
- “构建成功”只证明已执行阶段通过，不自动证明业务结果正确。

若这些概念还不稳，可以先读补救章，再回来。本章会给出全部命令，但不会重新完整教授 shell、环境继承或 Maven 生命周期。

> 本书版本基线是 JDK 25 LTS，不把 preview 特性放入必修路径。你可以使用 Temurin、Oracle JDK 或其他兼容的 OpenJDK 发行版；每次实验都要记录实际发行商和完整 patch 版本。

## 先建立一张不会误导你的地图

把最小 Java 运行链想成一条有检查站的生产线：

```text
人编写的文本                   编译器输出                     JVM 进程
ToolchainSmoke.java --javac--> ToolchainSmoke.class --java--> 加载、校验并执行
       源码                  JVM 可读取的 class 文件          输出/错误/退出码
```

这张图是本章需要牢牢记住的稳定核心。不过它是有意简化的：真实项目还会有很多源码、依赖 JAR、资源文件、模块、注解处理器、构建工具和测试阶段；JVM 运行时也会进行类加载、验证、解释执行和即时编译等工作。本章只先建立“源码→class→JVM 进程”这条最小可观察链。

### 四个名词分别负责什么

| 名词 | 本章精确定义 | 你能直接观察的证据 | 常见误解 |
| --- | --- | --- | --- |
| Java 源码 | 通常以 `.java` 保存、遵守 Java 语言规则的文本；本项目统一使用 UTF-8 | 编辑器内容、文件摘要、修改时间 | “有源码就已经有可运行程序” |
| `javac` | JDK 提供的 Java 编译器，读取类或接口定义并生成字节码/class 文件 | `javac -version`、编译日志、输出目录 | “`javac` 负责启动业务进程” |
| class 文件 | 有严格二进制格式和版本号的 JVM 输入，不是给人日常编辑的源码 | `.class` 文件、`javap -verbose` 的 major version | “class 就是机器 CPU 直接执行的原生代码” |
| JVM | Java 虚拟机规范描述的抽象机器；具体发行版提供实现 | `java -version`、运行进程、加载错误、退出码 | “JVM 等于 JDK 的全部内容” |

### JDK、运行环境与 JVM 的包含关系

对学习者最有用的模型是：

```text
JDK（开发工具包）
├── javac、java、javap、jar、javadoc 等开发/诊断工具
├── Java 标准库和运行时镜像
└── JVM 实现（运行 class 所需的核心执行环境）
```

历史资料常把 **JRE**（Java Runtime Environment）画成可单独下载的盒子。这个词仍可用于表达“运行 Java 应用所需的 JVM、库与配置”这一概念，但现代 JDK 使用模块化运行时镜像，生产部署也可以用 `jlink` 等工具生成定制运行时。不要因此得出“学习 JDK 25 必须再单独安装一个 JRE”的结论。

一句可复述的边界是：**JDK 面向开发与诊断，JVM 负责执行 class；JDK 包含运行所需能力，但 JVM 不是 JDK 的全部。**

## 先证明你到底在调用哪一个 Java

同一台电脑可以同时安装 JDK 21、25、26。编辑器、终端和 Maven 也可能各用一套。先收集证据，再讨论“我的 Java 是多少”。

在 macOS/zsh 中运行：

```zsh
echo "JAVA_HOME=${JAVA_HOME:-<未设置>}"
type -a java javac
command -v java
command -v javac
java -version
javac -version
```

逐行理解：

- `JAVA_HOME` 是一个环境变量，它只是一段路径信息，不会自动改写 `PATH`；
- `type -a` 列出 shell 能找到的全部同名命令；第一项通常是直接输入命令时采用的程序；
- `command -v` 给出当前解析结果；
- `java -version` 证明启动器/JVM 版本，`javac -version` 证明编译器版本；
- 这两条版本最好来自同一 JDK，但“名字看起来一样”不是证据，路径与输出才是。

在当前学习机上，预期主线是 Temurin 25。不要把下面示例里的绝对路径抄到自己的配置：

```text
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home
openjdk version "25.0.3" ...
javac 25.0.3
```

patch 号会随更新改变，所以实验只要求 feature version 为 25，同时把完整输出保存到报告。若编辑器显示 25、终端显示 21，这不是“Java 随机变化”，而是两个进程解析了不同的工具来源。

### 为什么临时改 `JAVA_HOME` 不一定改变 `java -version`

考虑：

```zsh
env JAVA_HOME="$(/usr/libexec/java_home -v 21)" zsh -c '
  echo "$JAVA_HOME"
  command -v java
  java -version
  mvn -v
'
```

子 shell 会继承临时的 `JAVA_HOME`，但若它继承的 `PATH` 第一项仍是 JDK 25 的 `bin`，直接执行 `java` 仍可能是 25。某些 Maven 启动脚本会主动读取 `JAVA_HOME`，于是同一段输出中 `java -version` 与 `mvn -v` 又可能指向不同 JDK。

这说明两个通用规则：

1. 环境变量从父进程传给子进程；子进程的临时修改不会反向改写已经存在的父进程；
2. 工具最终使用哪一个运行时，要看该工具自己的启动规则，不能只看一个环境变量。

完整的环境变量与 Maven 规则在前置章和 Maven 专章展开，本章只要求你形成“同时查路径和版本”的证据习惯。

## 从源码编译到 class：亲手走一遍

本章的可运行示例位于 [`examples/encyclopedia/ch.java.platform-toolchain`](../../../examples/encyclopedia/ch.java.platform-toolchain/README.md)。先不要研究 `main` 每个单词的语法；它是从下一章临时借用的固定入口外壳，本章只复制、编译和运行。

源码：

```java
package com.factorycare.learning;

public class ToolchainSmoke {
    public static void main(String[] args) {
        System.out.println("FactoryCare toolchain OK");
    }
}
```

从示例根目录执行：

```zsh
rm -rf build
mkdir -p build/classes
javac --release 25 \
  -d build/classes \
  src/com/factorycare/learning/ToolchainSmoke.java
echo "compile_exit=$?"
find build/classes -type f -print
```

各参数的职责：

- `--release 25`：要求编译器按 Java SE 25 的语言/API/目标 class 版本进行编译；
- `-d build/classes`：把生成的 class 文件放进明确的输出根目录；
- 最后一个参数是输入源码路径；
- shell 的 `$?` 是上一条命令的退出码，`0` 表示该命令按约定成功，非 `0` 表示失败。

成功后应出现：

```text
build/classes/com/factorycare/learning/ToolchainSmoke.class
compile_exit=0
```

为什么 class 文件还保留 `com/factorycare/learning` 目录？因为这个类型的二进制名称是 `com.factorycare.learning.ToolchainSmoke`。输出根目录与包路径共同让类加载器能找到它。`package` 的完整语义留到下一章，本章只需观察这个映射。

### 用 `javap` 查看而不是修改 class

class 文件是二进制格式。不要用文本编辑器修改它。可以让 JDK 工具读取：

```zsh
javap -classpath build/classes -verbose \
  com.factorycare.learning.ToolchainSmoke \
  | grep 'major version'
```

JDK 25 正常编译出的非 preview class 应显示：

```text
major version: 69
```

`69` 是 class 文件格式的主版本号，不是“Java 有 69 个版本”，也不是源码版本号。Java SE 25 JVM 规范规定了它支持的 class 主版本范围；旧 JVM 遇到更新的、不支持的 class 版本会在加载阶段拒绝它。

## 用 JVM 启动 class

继续在示例根目录运行：

```zsh
java -cp build/classes com.factorycare.learning.ToolchainSmoke
echo "run_exit=$?"
```

预期结果：

```text
FactoryCare toolchain OK
run_exit=0
```

这一条命令里没有 `.java`，也没有 `.class` 后缀：

- `java` 启动 JVM；
- `-cp build/classes` 把 `build/classes` 指定为用户 classpath 的一个根；
- `com.factorycare.learning.ToolchainSmoke` 是要加载的完整类名；
- JVM 从 classpath 根开始，把点号映射为目录，寻找对应 class；
- 找到、校验并初始化入口类后，启动器调用它的入口方法。

classpath 是“去哪些根目录或 JAR 中查 class”的搜索列表，不是某个 class 文件本身。在 macOS/Linux 上多个项用冒号分隔，在 Windows 上通常用分号。显式 `-cp` 会覆盖 `CLASSPATH` 环境变量；本书示例优先显式写 `-cp`，减少隐藏环境导致的不可复现行为。

> `java ToolchainSmoke.java` 的源码文件模式也能直接启动简单程序，但它在背后仍会编译源码，并使用专门的类加载行为。学习本章时先显式执行 `javac` 和 `java -cp`，因为这样编译产物与失败阶段都看得见。

## 一次命令成功，到底证明了什么

正确解释证据很重要：

| 证据 | 能证明 | 不能单独证明 |
| --- | --- | --- |
| `javac` 退出码 0 | 本次给定输入和选项通过编译 | 业务功能符合需求、所有测试通过 |
| class 文件存在 | 指定输出中产生了文件 | 一定来自你刚编辑的源码，除非清理并记录时间/摘要 |
| `java` 打印固定文本且退出 0 | JVM 找到并执行了入口，走到固定输出 | 整个真实应用没有逻辑错误 |
| 自动脚本全部断言通过 | 脚本覆盖的预言成立 | 脚本没有遗漏所有未知场景 |

因此示例脚本会先删除自己的 `build/`，再编译、运行、检查输出和退出码。这个动作消除了“拿旧 class 冒充新构建”的常见干扰。

## 故障实验一：编译器不支持目标版本

先预测，不要立刻运行：

```zsh
javac --release 99 -d build/classes \
  src/com/factorycare/learning/ToolchainSmoke.java
```

问题：它会进入 JVM 加载阶段吗？会出现 `Tests run` 吗？

答案是都不会。`javac` 在处理编译选项时已经发现本机不支持 release 99，返回非 0；没有新的可用 class 需要 JVM 加载，且这条命令根本没有启动测试框架。

典型首个可信证据包含：

```text
error: release version 99 not supported
```

诊断顺序：

1. 看失败命令是 `javac`，所以先归类为编译阶段；
2. 找第一条具体错误，而不是只看最后的“失败”；
3. 核对 `javac -version` 和命令的 `--release`；
4. 改回项目规定的 25；
5. 清理输出后重跑编译和运行，不能只说“应该好了”。

在 Maven 中，类似错误可能被包装为 `maven-compiler-plugin:compile` 失败，但本质仍是编译器没有产出合格 class。

## 故障实验二：classpath 根目录错误

先保持正确 class 文件不变，然后故意运行：

```zsh
mkdir -p build/empty
java -cp build/empty com.factorycare.learning.ToolchainSmoke
echo "run_exit=$?"
```

典型结果是非 0，并在标准错误中出现：

```text
Error: Could not find or load main class com.factorycare.learning.ToolchainSmoke
Caused by: java.lang.ClassNotFoundException: com.factorycare.learning.ToolchainSmoke
```

这里源码没有重新编译，class 文件也可能完好。失败发生在 JVM 启动后的类查找/加载阶段。首要检查不是去改 Java 语法，而是回答：

1. `-cp` 的根目录实际是什么？
2. 从这个根拼出 `com/factorycare/learning/ToolchainSmoke.class` 后，文件是否存在？
3. 完整类名是否包含正确 package？
4. 当前目录是否与命令假设一致？

把 classpath 恢复为 `build/classes` 后，必须再次看到固定文本和退出码 0，修复才闭环。

## 四类阶段不要混在一起

| 阶段 | 典型动作 | 典型失败 | 首个可信位置 |
| --- | --- | --- | --- |
| 命令解析前/启动前 | shell 查找 `javac`/`java` | `command not found`、权限不足 | shell 自己的错误、`type -a` |
| compile | `javac` 读取源码并写 class | 语法错误、不支持 release、缺少依赖类型 | 第一条 compiler error；裸 `javac` 常见 `文件.java:行号:` 加插入符，Maven 包装日志也可能显示 `[行,列]` |
| JVM 加载/启动 | `java -cp ... 完整类名` | classpath 错、class 版本过新、入口不存在 | launcher/JVM 的第一条 cause |
| 程序运行 | 入口已开始执行 | 未捕获异常、错误退出码、逻辑结果错误 | 异常栈首个业务帧或测试 expected/actual |

日志最后一行经常只是汇总，例如 `BUILD FAILURE`。它能告诉你总体失败，却不一定告诉你最早的可修原因。训练自己从“哪个阶段”开始缩小范围，再找该阶段第一条具体证据。

## 与 JavaScript/TypeScript 开发经验对照

如果你熟悉前端，可以暂时这样类比，但要保留边界：

| Java | 前端中的近似物 | 不可直接等同之处 |
| --- | --- | --- |
| `.java` 源码 | `.ts` 源码 | 两种语言的类型系统、模块和运行模型不同 |
| `javac` | TypeScript 编译器/构建器 | Java 常生成 JVM class，TS 常转译为 JS |
| classpath | 模块/包查找路径的一个近似概念 | Node、浏览器、打包器和 JVM 的解析规则不同 |
| JVM | JS 引擎加宿主运行时的粗略组合 | JVM 规范、字节码、类加载与 Web API 模型不同 |
| Maven 构建阶段 | `pnpm` scripts/构建流水线 | 生命周期名称和依赖模型不同 |

类比只用来搭桥。真正诊断时，以当前工具的路径、规范和日志为准。

## FactoryCare 中这条链落在哪里

未来 FactoryCare 后端会由很多 Java 源文件、Spring 依赖和资源组成，Maven 负责组织构建。但底层证据仍沿用本章模型：

```text
src/main/java 下的源码
        ↓ maven-compiler-plugin / javac
target/classes 下的 class 与资源
        ↓ java -jar 或测试启动器
JVM 进程加载应用与依赖
        ↓
HTTP 服务、日志、退出状态
```

真实排障示例：CI 报 `UnsupportedClassVersionError` 时，应先核对“编译 class 的 JDK/target”与“部署 JVM 的版本”，而不是先怀疑数据库；部署报找不到主类时，先检查 JAR 内容、manifest 和启动 classpath，而不是改业务计算。

本章不会让你手写 Spring 项目，但会让你以后看 Spring 的长日志时知道最底层发生了什么。

## 安全与可靠性边界

- 不要在截图、报告或命令中粘贴 Token、密码、私钥和完整生产环境变量；本章只记录工具路径和版本。
- 不要从不明网站下载“破解 JDK”。使用可信发行方，并核对下载来源、签名或摘要。
- `JDK_JAVA_OPTIONS`、`JAVA_TOOL_OPTIONS` 等环境变量可能影响 JVM 行为。出现无法解释的额外参数时应检查它们，但分享报告前要先去除敏感值。
- 清理命令必须限制在示例自己的 `build/`，不要把未经检查的变量拼进 `rm -rf`。
- “本机能运行”不等于“部署机能运行”。可复现报告必须记录操作系统、架构、JDK 发行商、完整版本、输入摘要与命令。

本章没有用户界面，无键盘、焦点或屏幕阅读器交互要求；但所有运行链和图示都提供了等价文字说明，不能只靠颜色区分成功与失败。

## 按层次完成本章实验

公开实验入口是 [`labs/encyclopedia/ch.java.platform-toolchain`](../../../labs/encyclopedia/ch.java.platform-toolchain/README.md)，自动示例入口是 [`examples/encyclopedia/ch.java.platform-toolchain`](../../../examples/encyclopedia/ch.java.platform-toolchain/README.md)。建议按以下顺序：

1. **预测**：在运行前写下每条命令会产生哪个文件、输出和退出码；
2. **模仿**：逐条执行正确的 `javac` 和 `java -cp`，不要整段盲贴；
3. **解释**：给每一段输出标注“工具来源、编译、加载、程序运行”之一；
4. **故障**：分别注入 `--release 99` 和错误 classpath，保存非 0 与第一条具体错误；
5. **修复**：恢复 JDK 25 release/classpath，清理并重跑；
6. **独立**：关闭 AI，从空目录完成实验并写一份验证报告。

实验验收必须同时满足：

- 记录 `java`/`javac` 的实际路径与完整版本；
- 源码修改后产生新的 class，`javap` 显示目标 class 主版本；
- 正常运行输出固定文本且退出码为 0；
- 两个故障均返回非 0，能分别归类到 compile 与 JVM 加载；
- 修复后使用原正常预言复跑通过；
- 报告不含凭据或个人隐私。

## 练习：先做题，再看隔离答案

题目位于 [`exercises/encyclopedia/ch.java.platform-toolchain`](../../../exercises/encyclopedia/ch.java.platform-toolchain/README.md)。这里不提供答案，只说明练习层级：

- 看命令预测输出目录、class 名称和退出码；
- 根据三段日志判断失败阶段；
- 修改输入文件并用时间/摘要证明不是旧 class；
- 将“文本改为 `FactoryCare JDK 25 READY`”作为需求变更，更新预言与验证脚本；
- 关闭 AI，从空目录恢复一条可重复运行链。

隔离答案保存在本地 `solutions-private/encyclopedia/ch.java.platform-toolchain/`，不进入公共站点和搜索索引。独立完成并保存自己的证据以前不要打开。

## 120 秒复述模板

请合上本章，按下面顺序说一遍：

1. JDK 包含哪些开发/运行能力，JVM 单独负责什么；
2. `.java` 与 `.class` 的用途和可观察差别；
3. `javac --release 25 -d ...` 的输入与输出；
4. `java -cp ... 完整类名` 如何从 classpath 根寻找 class；
5. 一个 compile 失败反例与一个 JVM 加载失败反例；
6. 为什么只看 `BUILD SUCCESS` 或最后一行不够。

若无法在 120 秒内讲清，优先重做故障实验，而不是背更多术语。

## 间隔复习点

- **当天**：不看命令，从空目录重建并运行一次；
- **第 2 天**：只看两段故障日志，写下阶段、首证据和修复；
- **第 7 天**：解释 `JAVA_HOME` 与 `PATH` 为什么可能指向不同 JDK；
- **第 21 天**：在 Maven 项目日志中标出 compile、testCompile、test 和 JVM 启动边界。

## 速查表

```zsh
# 工具来源与版本
echo "$JAVA_HOME"
type -a java javac
java -version
javac -version

# 编译
rm -rf build && mkdir -p build/classes
javac --release 25 -d build/classes path/to/ToolchainSmoke.java

# 查看 class 版本
javap -classpath build/classes -verbose fully.qualified.ClassName

# 运行
java -cp build/classes fully.qualified.ClassName

# 每条关键命令后立即观察退出码
echo $?
```

| 现象 | 先查什么 |
| --- | --- |
| `command not found` | `PATH`、拼写、文件是否可执行 |
| `release version ... not supported` | `javac -version` 与 `--release` |
| `Could not find or load main class` | classpath 根、完整类名、class 实际位置 |
| `UnsupportedClassVersionError` | 编译 class 版本与运行 JVM 版本 |
| 改源码但输出没变 | 是否清理/重新编译，运行的是否同一输出目录 |

## 术语表

- **JDK**：Java Development Kit，包含编译、启动、打包、诊断等工具及运行时能力。
- **JVM**：Java Virtual Machine，定义并实现 class 加载与执行环境的核心。
- **源码**：供人编写和审查、遵守 Java 语言规则的文本输入。
- **字节码**：class 文件中供 JVM 指令集使用的代码表示；class 文件还包含常量池、字段、方法和属性等结构。
- **class 文件**：JVM 规范定义的、带版本信息的二进制格式。
- **classpath**：类加载时搜索目录、JAR 或 ZIP 的路径列表。
- **退出码**：进程结束时返回给父进程的整数状态；按常见约定 0 表示成功，非 0 表示失败。
- **发行版**：对 OpenJDK 等实现进行构建、测试和分发的产品，例如 Temurin 或 Oracle JDK。

## 版本与一手来源

- 目标版本面：`jdk-25`，约束为 `25.x LTS`；本章本地验证应记录实际 patch，preview 特性不进入必修。
- 复核日期：2026-07-16。
- Oracle，[JDK 25 Tool Specifications](https://docs.oracle.com/en/java/javase/25/docs/specs/man/index.html)：支持 JDK 工具集合及 `javac`/`java` 的职责。
- Oracle，[Oracle Java SE Support Roadmap](https://www.oracle.com/java/technologies/java-se-support-roadmap.html)：支持 Java 25 的 LTS 发布定位与支持时间表。
- Oracle，[The javac Command](https://docs.oracle.com/en/java/javase/25/docs/specs/man/javac.html)：支持编译器输入输出、`--release`、`-d` 和 classpath 选项。
- Oracle，[The java Command](https://docs.oracle.com/en/java/javase/25/docs/specs/man/java.html)：支持 JVM 启动、主类、源码文件模式、classpath 与退出状态说明。
- Oracle，[Java Virtual Machine Specification, Java SE 25, Chapter 4](https://docs.oracle.com/javase/specs/jvms/se25/html/jvms-4.html)：支持 class 文件结构、版本与 Java SE 25 的主版本 69。
- Oracle，[Installed Directory Structure of JDK 25](https://docs.oracle.com/en/java/javase/25/install/installed-directory-structure-jdk.html)：支持现代 JDK 安装目录与运行时镜像组成。

来源只直接支持相应技术事实；“先按阶段定位再看首个可信证据”是本课程基于可重复调试实践制定的教学方法，不是 Oracle 对所有工程日志的统一规定。
