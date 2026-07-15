# 第 1 周：Java 程序结构、控制台 I/O、类型、运算、方法与 JUnit

## 定位

本周建立 Java 的最小可执行心智模型：源码怎样组织和运行、数据怎样进入/输出、值与类型怎样约束运算、方法怎样定义边界、JUnit 怎样证明行为。控制流、字符串深入和数组集中在 Week 02；这样不会一次塞入过多概念。

时间预算：15—18 小时，Week 01 目标窗口为 2026-07-15—07-26。先复用 `practice/week-00-java-smoke`，不创建 Spring 工程。

## 前置

- Week 00 环境已能使用 JDK 25、Maven 和 IntelliJ；
- 会运行 `mvn test`，能从日志找到阶段、文件、行号和 expected/actual；
- 完成 30—45 分钟有计时 G0 桥接后正式开始；
- 有 TS/JS 基础，但不把 Java 简化为“带类型的 JS”。

## 目标

- 理解源文件、package、import、class、经典 `main` 和 JVM 启动链；
- 使用 `System.out`、`System.err`、命令行参数和 `Scanner` 完成最小 I/O；
- 区分外部 I/O 与方法参数/返回值；
- 使用基本类型、引用类型、变量、作用域、字面量和类型转换；
- 理解算术、比较、逻辑、赋值运算和求值顺序；
- 定义和调用方法，理解参数按值传递、返回值、重载与可见性基础；
- 使用 JUnit 编写正常、边界和异常测试；
- 区分编译错误、运行时异常、断言失败和构建成功的证据含义。

## 完整概念清单

### 程序结构与运行

- `.java` 源文件、public class 与文件名；
- package 对应命名空间/目录，import 只影响名称解析；
- class、method、block、statement、expression；
- 经典入口 `public static void main(String[] args)`；Java 25 简化源文件只了解，不作为项目默认；
- `javac` 生成字节码、`java` 启动 JVM 的高层流程；
- classpath、target/classes 和 IDE 运行配置的直觉；
- compiler、runtime、test runner、Maven 是不同层。

### 控制台与方法 I/O

- `System.out.println/print/printf` 和 `System.err`；
- stdout/stderr 与方法 return 不同；
- `args` 是字符串数组，本周只读取一个/两个位置，数组系统知识留 Week 02；
- `Scanner(System.in)` 的 `nextLine`、基本数值解析与关闭边界；
- 不关闭共享的 `System.in` 造成后续不可用的高层风险；
- CLI 输入永远是外部不可信数据，转换失败要有明确结果；
- 业务方法尽量不直接读取控制台，I/O 适配与规则分离。

### 值、变量与类型

- `byte/short/int/long/float/double/char/boolean`；
- 基本类型与引用类型的第一层区别；
- 变量声明、初始化、重新赋值和局部变量必须初始化；
- scope 和 shadowing 基础；
- 整数/浮点/字符/布尔/String 字面量及后缀；
- `long`/`float` 字面量后缀，整数除法，浮点误差；
- widening/narrowing conversion、cast 和数据丢失；
- 溢出不会自动抛异常，使用边界测试；
- `String` 只学习声明/输出/输入，内容比较与方法在 Week 02；
- `null` 只理解引用可能无对象，完整边界在 Week 02。

### 运算符

- `+ - * / %`、一元正负、增减只读懂不追谜题；
- assignment 与 compound assignment；
- comparison 与 boolean；
- `&&/||/!` 的短路只做最小实验，复杂条件在 Week 02；
- 优先级不确定时加括号；
- 字符串 `+` 拼接和从左到右结果；
- 金额不用 float/double 作为最终领域方案，本周先以“分”的整数实验。

### 方法

- 修饰符、`static`、返回类型、方法名、参数列表、方法体；
- declaration/signature/call/argument/parameter；
- `void` 与有返回值方法；
- `return` 结束当前方法；
- 参数按值传递：基本值复制，引用值也被复制；
- 方法重载由名称+参数列表区分，不能只改返回类型；
- public/private/package-private 第一层访问边界；
- 小方法按一个意图命名，避免让 I/O 和计算混在一起。

### JUnit 与反馈分类

- production code 在 `src/main/java`，test code 在 `src/test/java`；
- 同 package 的 package-private 访问；
- `@Test`、AAA、`assertEquals/assertTrue/assertThrows`；
- 先写业务例子/边界，再写断言；
- compile 失败时不会进入 test；testCompile 与生产 compile 不同；
- test runner 执行测试，Failures 与 Errors/编译错误不同；
- `BUILD SUCCESS` 必须结合 Tests run/Failures/Errors 判断；
- 测试也可能写错，expected 应来自业务契约而非实现复制。

## 课次与时间

| 课次 | 时间 | 内容与产出 |
| --- | ---: | --- |
| 0 | 0.5—0.75h | G0：读方法签名、制造类型编译错误、恢复并复验 |
| 1 | 1.5—2h | package/class/main、编译运行、stdout/stderr |
| 2 | 2h | 变量、类型、字面量、转换、整数除法和溢出 |
| 3 | 2h | args/Scanner、输入转换、I/O 与业务方法分离 |
| 4 | 2—2.5h | 方法、参数/返回、作用域、按值传递、重载 |
| 5 | 2—2.5h | JUnit AAA、正常/边界/异常、四类反馈 |
| 6 | 3—4h | CLI 金额计算器、测试和一次真实故障 |
| 7 | 1—1.5h | 关闭 AI 修改一条规则并完成复盘 |

## FactoryCare 前置增量

完成 `OrderAmountCalculator` 的可测试 CLI 包装：

- 业务方法接收 `unitPriceCents`、`quantity`，返回总分；
- CLI 从参数或控制台读取两个整数，输出金额或明确错误；
- 业务方法不直接依赖 `Scanner/System.out`；
- 覆盖单价/数量正常值、0、非法负数和可能溢出的契约；
- 先决定溢出行为，再选择 `long`/精确运算方法；
- 制造参数类型错误、缺分号、错误断言和运行时解析错误各一次，记录区别。

Week 02 前不实现复杂优先级决策，不使用数组循环做主任务。

## AI 协作边界

AI 可以解释完整代码、生成测试候选和提供故障；学习者必须逐词读懂方法签名、先预测错误类别、亲自运行、依据日志恢复，并独立修改规则。禁止一次生成最终 FactoryCare 模块。

## 无 AI 任务（90—120 分钟）

实现 `ServiceFeeCalculator`：输入基础金额（分）和服务费率（整数百分点或基点，由你先定义），返回总金额。提供 CLI、正常/0/边界/非法/溢出测试，并在 README 说明单位、舍入和错误契约。

## 交付物与验收

- 源码与测试从命令行构建，Tests run/Failures/Errors 可解释；
- 能写出经典 main 和最小 Scanner 输入；
- 能逐词解释两个方法签名和一次调用；
- 能判断常见数值类型、整数除法、转换和溢出风险；
- 能解释 Java 参数按值传递；
- 能在 15 分钟内新增一条金额边界测试并修改实现；
- 能根据日志恢复编译、测试或运行时错误各至少一种；
- 60—120 秒复述“输入 → 转换 → 方法 → 返回 → 输出 → 测试”的链路。

## 非目标

- 不系统学习 if/switch/for/while、数组和字符串 API（Week 02）；
- 不学习类实例/构造器（Week 03）、继承/接口（Week 04）；
- 不学习 Spring、数据库或框架；
- 不考 Maven 低频命令背诵；
- 不因已有 JUnit 工程就跳过 Java I/O 与类型基础。

## 官方资料

- Java Language Basics、`System`、`Scanner`、primitive types、methods 和 JUnit User Guide；
- 进入本周时以 JDK 25 和项目 JUnit BOM 的官方文档为准。
