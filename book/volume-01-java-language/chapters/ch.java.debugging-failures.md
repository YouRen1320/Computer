---
schema_version: 2
edition: 2026.2-draft
id: ch.java.debugging-failures
title: 编译错误、运行异常、断言失败、逻辑错误与断点调试
responsibility: 训练按失败阶段定位首个可信证据，并使用断点与调用栈复核，不引入 JVM 性能诊断
volume: '01'
order: 11
level: L1
status: drafting
path: book/volume-01-java-language/chapters/ch.java.debugging-failures.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java.maven-junit-smoke
- ch.foundations.editor-project-navigation
version_surfaces:
- jdk-25
- junit-6
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释编译错误、运行异常、断言失败、逻辑错误与断点调试的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-failure-stages
  - java-debugger
  covers_topics:
  - java.compile-error
  - java.runtime-exception
  - java.assertion-logic-failure
  - debug.breakpoint-step
  - debug.stack-frame-variable
  - debug.reproduce-fix-rerun
  uses_capabilities:
  - java.build-testing
  - java.methods
  - java.control-flow
  - foundation.verification-debug-test
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为同一小程序制造编译、运行异常、断言和纯逻辑四类故障，保存断点、变量和调用栈定位记录
  covers_topic_groups:
  - java-failure-stages
  - java-debugger
  covers_topics:
  - java.compile-error
  - java.runtime-exception
  - java.assertion-logic-failure
  - debug.breakpoint-step
  - debug.stack-frame-variable
  - debug.reproduce-fix-rerun
  uses_capabilities:
  - java.build-testing
  - java.methods
  - java.control-flow
  - foundation.verification-debug-test
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 面对未知故障先判断阶段，再从第一条项目代码位置步入并修复，禁止从末尾 BUILD FAILURE 猜原因，并把异常定位到第一处可信证据
  covers_topic_groups:
  - java-failure-stages
  - java-debugger
  covers_topics:
  - java.compile-error
  - java.runtime-exception
  - java.assertion-logic-failure
  - debug.breakpoint-step
  - debug.stack-frame-variable
  - debug.reproduce-fix-rerun
  uses_capabilities:
  - java.build-testing
  - java.methods
  - java.control-flow
  - foundation.verification-debug-test
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# 编译错误、运行异常、断言失败、逻辑错误与断点调试

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Maven 最小项目、JUnit、断言与失败日志》](ch.java.maven-junit-smoke.md)：独立完成Java 失败阶段、断点与调用栈前，必须先具备「Maven 最小项目、JUnit、断言与失败日志」已经验证的知识与失败边界
- [《编辑器、IDE、项目导航与源码定位》](../../volume-00-computer-foundations/chapters/ch.foundations.editor-project-navigation.md)：独立完成Java 失败阶段、断点与调用栈前，必须先具备「编辑器、IDE、项目导航与源码定位」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套故障是受控教学样例；验证脚本确认故障按预期出现，不代表学习者已经亲自诊断，也不会修改学习进度。

调试不是“看见红字就让 AI 重写”，也不是在所有行打印变量。它是一套缩小不确定性的过程：先稳定复现，判断失败阶段，找到第一处可信的项目证据，提出一个可以证伪的假设，用断点或最小实验复核，只修改一个原因，再让原失败输入和完整测试集由红变绿。

本章整合已经见过的 Java 编译、Maven `compile`/`testCompile`/`surefire:test` 与 JUnit 日志，再加入 IDE 断点、step、stack frame 和变量观察。它不重复教授整本 Java 语法，也不进入 JVM 性能分析、线程 dump、远程调试、生产 profiling 或复杂异常设计。运行基线为 **JDK 25 + JUnit 6.1.1**，官方资料复核日期为 **2026-07-16**。

## 1. 学完后必须留下什么证据

1. **解释证据**：在 120 秒内区分编译错误、测试编译错误、运行异常、断言失败和未被测试捕获的逻辑错误；说明第一处可信位置为何比最后的 BUILD FAILURE 更有用。
2. **构建证据**：对同一维修费用方法分别注入四类故障，保存命令、固定输入、日志阶段、断点变量与调用栈；绿色基线 Tests run=4。
3. **诊断证据**：面对未知故障先预测阶段，再最小复现、单点修复、重跑原用例与完整测试；不通过修改 expected 迎合错误实现。

配套入口：

- [失败分类与最小复现](../../../examples/encyclopedia/ch.java.debugging-failures/README.md)
- [四类故障与断点实验](../../../labs/encyclopedia/ch.java.debugging-failures/README.md)
- [独立练习：SLA 余量诊断](../../../exercises/encyclopedia/ch.java.debugging-failures/README.md)

## 2. 直觉模型：先找“列车停在哪一站”

把构建与运行看成有顺序的路线：

```text
main 源码 --compile--> main class
测试源码 --testCompile--> test class
两类 class --surefire:test--> 测试方法
测试方法 --调用--> 业务方法 --返回/异常--> 断言
```

如果 compile 站已经停下，就不该分析 JUnit 断言；如果 testCompile 停下，业务 class 可能正常，问题在测试源码结构；如果测试已经运行，再区分是运行异常、断言不等还是断言根本没覆盖错误结果。

“先分阶段”不会直接给出根因，却能排除大量无关可能。它比从末尾 `BUILD FAILURE` 开始猜更快，因为 BUILD FAILURE 只是整趟构建的最终状态。

## 3. 调试前先建立绿色基线

故意注入故障前，先运行未修改版本并记录：命令、工具版本、Tests run、Failures、Errors、Skipped。若基线本来就是红的，注入后的差异无法归因。配套项目的基线是四条维修费用测试全部通过。

绿色基线也不能证明需求完整，但能提供对照。调试时只改变一个变量：替换一个运算符、一个 expected 或一行语法，然后运行同一命令。若同时改 JDK、依赖、源码和测试，结果变化无法说明哪个修改有效。

保存基线不必截整屏。文本日志、命令和精确计数更易搜索、比较和脱敏。IDE 运行也要记录运行的是单条方法、整个类还是整个项目；“绿色三角形”没有说明范围。

## 4. 第一类：编译错误

编译错误表示 javac 无法把源码转换成合法 class。常见原因包括缺分号、括号不匹配、类型不兼容、找不到符号和 package/文件结构问题。Maven main 源码编译错误停在 `compiler:compile`。

例如 return 语句缺分号，日志给出：项目文件、行列与 `';' expected`。可信顺序是阶段、项目文件位置、具体消息。最后的 Maven Help 链接只是通用说明。

编译错误发生时没有业务执行，更没有 JUnit Tests run。不能把它写成 `Errors: 1`，因为 Surefire 的 Errors 字段尚不存在。修复语法后必须重跑；“IDE 红线消失”只是静态提示变化，不等于命令行构建已恢复。

有时 javac 会从一个括号错误派生十几条消息。先修第一条、重新编译，再看剩余，而不是逐条机械处理。越靠后的错误可能只是解析器失去结构后的连锁反应。

## 5. 第二类：测试编译错误

业务源码 compile 成功后，Maven 编译 `src/test/java`。测试 package 错、import 缺失、调用不存在方法或访问权限不足，会停在 `compiler:testCompile`。此时 `target/classes` 可能已有业务 class，但 `target/test-classes` 不完整，Surefire 不运行。

日志里的 `cannot find symbol` 要继续读 symbol 和 location。若 symbol 是变量 `OrderAmountCalculator`，位置是测试类，先核对测试 package、import、类名和业务类可见性；不要因为名字出现在测试里就修改乘法实现。

main 与 test 分开编译解释了为什么“业务代码没红”仍构建失败。诊断表述应明确：最后成功的是 compile，失败是 testCompile，没有 Tests run。修复后重跑同一 Maven 命令，观察是否推进到 Surefire。

## 6. 第三类：运行异常

源码和测试都编译后，测试调用业务方法。若运行时执行非法操作，例如整数除以零，会产生异常并中断当前调用。Surefire 通常把未由测试预期处理的异常计入 Errors，而不是 Failures。

运行异常日志包含异常类型、消息和 stack trace。调用栈从当前失败点展示一层层调用关系。先找第一条属于自己项目包和源码的 frame，例如 `RepairCost.java:6`；JUnit、反射与 Surefire 的框架 frame 说明运行通道，却通常不是业务修改位置。

异常类型是事实，根因解释仍是推断。`ArithmeticException: / by zero` 证明执行了整数除零；为什么 divisor 为 0，需要看当前 frame 的参数和表达式。不要只在上层 catch 后返回 0 来“消红”，否则可能把真实错误变成错误业务值。

本章不系统讲异常捕获与传播。当前目标是能识别运行异常、读取项目栈帧和用断点复核变量。

## 7. 第四类：断言失败

测试方法正常调用业务代码并得到 actual，但 `assertEquals` 发现它与 expected 不同，JUnit 报 AssertionFailedError，Surefire 计入 Failures。日志常明确：

```text
expected: <12501> but was: <12500>
Tests run: 4, Failures: 1, Errors: 0, Skipped: 0
```

这证明两值不等，不自动证明哪一边错。若业务规则和手算是 120 分钟×6000 分/小时÷60+500=12500，那么 12501 的 expected 错；若规则近期增加 1 分固定费，实现可能错。调试必须找到独立 oracle。

第一处测试栈帧通常指向 assertEquals 行。它是矛盾显现位置，不一定是业务根因。下一步比较输入、expected 来源、actual 和业务方法。禁止为了绿色直接把 expected 改成 actual。

## 8. 第五类：逻辑错误

逻辑错误指程序能够编译和运行，却违反业务规则。若测试覆盖该输入，它最终表现为断言 Failure；若没有相应测试，构建可能全绿，用户仍得到错误结果。因此“逻辑错误”和“断言失败”不处于同一层：前者是产品行为问题，后者是测试观察到不一致的机制。

例如余量应为 target-elapsed，却写成 target+elapsed。输入 60、15 得到 75，没有异常。若只有 0、0 用例，错误运算恰好也返回 0，测试会漏掉。加入 60、15 的独立 oracle 才让逻辑错误可见。

定位逻辑错误要手算或读取明确规则，再观察中间变量和分支。测试全绿时也可用新最小用例暴露；但新测试必须来自需求，不是为了展示“我能让它红”。

## 9. Failure、Error 与“错误”日常用语

中文日常会把任何失败都叫错误，但日志字段有特定含义：

| 情况 | 是否编译 | 是否运行测试 | Surefire 常见计数 |
| --- | --- | --- | --- |
| main 缺分号 | 否 | 否 | 无 Tests run |
| test 找不到类 | main 是、test 否 | 否 | 无 Tests run |
| 业务除零 | 是 | 是 | Errors 增加 |
| expected/actual 不等 | 是 | 是 | Failures 增加 |
| 未覆盖逻辑 bug | 是 | 是 | 可能仍 0/0 |

看到 Maven `[ERROR]` 前缀不能直接推断 Surefire `Errors: 1`。Maven 会用 ERROR 级别打印编译失败、测试 Failure 和最终汇总。应以阶段与测试计数字段分类。

## 10. 第一处可信证据

“第一处可信”不是永远指日志物理第一行，而是最早能直接连接到当前项目和具体矛盾的证据。它通常是：javac 的项目文件行列、异常 stack trace 中第一条项目 frame、JUnit 的 expected/actual 与测试行。

以下信息更弱：末尾 BUILD FAILURE、通用 Help 链接、框架内部反射 frame、AI 根据一张截断截图的猜测。弱证据不是完全无用，但不能覆盖更具体事实。

日志阅读模板：最后成功阶段是什么；失败阶段是什么；是否实际运行测试；第一处项目位置在哪里；expected/actual 或异常变量是什么；当前证据能证明什么、不能证明什么。这个模板能防止从错误层修改代码。

## 11. 稳定复现：同一输入、同一命令、同一范围

无法重复的故障很难验证修复。记录最小命令、输入、版本和运行范围。若问题只在 IDE 出现，确认 IDE JDK、Maven JDK、工作目录和运行配置；若只在命令行出现，确认 IDE 是否只跑单条测试。

“刚才偶尔坏了”不是复现步骤。把输入从真实大数据缩成虚构的小值，删除与失败无关的 UI、数据库和网络依赖，直到仍能触发同一现象。最小复现不是重写一个看似类似的新程序，而是保留根因所需最少条件。

配套实验每次从绿色 project 复制到临时 work，再只替换一个故障文件。这样四类日志互不污染，也不会把 fault fixture 覆盖到基线源码。

## 12. 提出可证伪假设

好的假设能预测下一次观察：“如果是 package 不一致，main compile 应成功，testCompile 会 cannot find symbol，Tests run 不会出现。”“如果是除零，断点命中时 divisor 应为 0，栈顶项目 frame 在除法行。”

“代码有问题”“可能是缓存”“Maven 坏了”不可证伪，范围太大。一次只验证一个假设。证据反驳后就放弃，不要为了维护原猜测不断增加无关修改。

AI 建议也只是候选假设。要求它指出依据的日志行、预测的下一步结果和最小改动；本地执行后再接受。模型说“应该可以”不是验证证据。

## 13. 断点是什么

断点告诉调试器：程序执行到某个可停位置时暂停，让你检查当前状态。它不会改变业务规则，也不自动修复。最有价值的断点通常放在已知失败路径的第一条业务语句、条件判断或产生错误值的表达式附近。

不要在每行设置断点。先从日志或失败测试缩小范围，再选一个点。运行对应的单条测试能减少噪声；确认根因和修复后，仍要运行完整测试集。

断点未命中也是证据：可能运行了不同测试、输入没有经过该分支、设置在不可执行行、class 与源码不一致，或运行配置不是调试模式。先核对运行范围，不要不断复制断点。

## 14. Step Over、Step Into、Step Out 与 Continue

- **Step Over**：执行当前行；若该行调用方法，不逐行进入被调方法，在当前 frame 的下一可停位置暂停。
- **Step Into**：进入当前调用的方法，适合怀疑被调方法内部。
- **Step Out**：运行到当前方法返回调用者，适合已确认本层无问题。
- **Continue/Resume**：继续到下一个断点或程序结束。

“下一步”不是总用 Step Into。进入 JDK、JUnit 或 getter 的大量内部代码会失去方向。先看当前行是否就是待验证边界。调试 RepairCost 时，在 calculate 内通常 Step Over 足够观察表达式结果；从测试调用点怀疑业务实现时才 Step Into。

每次操作前先预测：执行后哪个变量变化、下一 frame 在哪里、是否会返回或抛异常。没有预测的单步只是观看动画。

## 15. stack frame、调用栈与变量

每次方法调用都有一个 stack frame，包含当前执行位置、形参和局部变量等调试视图。调用栈按调用关系排列：测试方法调用业务方法，业务方法可能再调用辅助方法。当前 frame 决定变量窗口显示哪一组局部状态。

切换 frame 不会让程序倒退，只是查看不同调用层当时保存的状态。若在 RepairCost frame 看 `laborMinutes=120`，切回测试 frame 会看到 expected 和输入准备变量。把 frame 与源码行对应起来，才能避免把上层变量当成本层变量。

变量窗口显示的是当前暂停时刻。表达式尚未执行时，不应期待返回值已经存在。调试整数计算时记录输入、中间乘积、除数和最终结果；不要因为 IDE 能任意 Evaluate Expression 就运行有副作用的方法。

## 16. 条件分支的断点验证

若异常只在 `laborMinutes==0` 出现，在条件行断点，用 0 与 120 两个输入分别运行。预测 0 命中错误分支、120 跳过。观察实际分支比阅读代码猜路径更可靠。

条件断点可以只在值满足条件时暂停，但初学阶段先用普通断点理解执行链。复杂条件表达式可能被求值多次或有副作用，生产调试应谨慎。本章样例使用纯整数条件，没有外部状态。

“断点命中预期分支”属于人工证据，shell verifier 无法替代。实验 README 明确要求记录 frame、参数和 step；不要把自动绿测冒充 IDE 操作已完成。

## 17. 最小修复

根因明确后，只改足以恢复契约的一处。缺分号就补分号；package 错就恢复 package；错误 expected 经手算确认后改 expected；加法逻辑错就改成减法。不要顺便改名、格式化全项目、升级 JUnit 或抽取新架构。

小 diff 更容易归因和回滚。若最小修复仍失败，说明假设不完整；保留新证据再迭代。一次大重构后变绿，无法证明原根因，也可能引入未覆盖行为。

安全故障不一定适合只做最小补丁，但仍应先明确问题、影响、迁移与验证。本章的教学 fixture 都是局部语言错误，不代表真实事故处理流程。

## 18. 红—绿—完整复跑

诊断证据至少包含三步：

1. **红**：固定输入确实触发预期失败，不是凭想象修 bug。
2. **绿**：最小修改后，原失败输入通过。
3. **回归**：完整测试集通过，未破坏其他已知行为。

只跑绿不证明修复针对原故障；只跑单条绿不证明回归。反过来，故意失败 fixture 的验证脚本返回 0 也可能表示“成功观察到预期失败”，因此要读脚本输出语义，不能只看 shell 状态。

测试通过后再看 diff，确认没有把测试删除、跳过或改成迎合结果。`Skipped: 0` 与 Tests run 数量是防止假绿的基础证据。

## 19. 编译器、测试与调试器如何协作

编译器最擅长发现结构与类型不成立；JUnit 断言擅长把业务样例 expected 与 actual 比较；调试器擅长在某次执行中观察路径和变量。它们互补，不应互相替代。

能用编译器直接定位的缺分号，不必先开断点；能由失败断言明确 expected/actual 的问题，先手算再决定是否调试；只有路径或中间状态不清时才单步。打印日志也有用，但临时打印可能改变输出契约或污染测试，应在使用后清理。

调试器里看到一次变量正确，不代表所有输入正确。最终仍由可重复测试固定结论。测试失败日志则是入口，不一定展示所有中间状态，必要时用断点补充。

## 20. 常见无效调试方式

### 20.1 从末尾开始猜

只看到 BUILD FAILURE 就重装 Maven。应先看失败阶段和项目位置；多数教学故障与安装无关。

### 20.2 一次修改多处

同时改实现和 expected，结果绿了也不知道谁错。保持单变量实验。

### 20.3 删除失败测试

Tests run 从 4 变 3 可能让构建绿，却减少证据。固定计数并检查 Skipped。

### 20.4 追框架内部栈帧

在反射和 Surefire 代码里单步很久，却跳过第一条项目 frame。先回到自己的 package。

### 20.5 把缓存当万能解释

缓存确实可能影响 class，但必须用 `mvn clean test` 证伪。不能在没有证据时清理整个开发环境或删除本地仓库。

### 20.6 把 AI 结论当运行结果

AI 能读日志和提出假设，不能替代本机版本、断点变量、测试计数和重跑证据。

## 21. FactoryCare 场景：维修费用

规则：人工费按分钟折算，`laborMinutes * ratePerHourCents / 60`，再加零件费。输入 120、6000、500 应为 12500；0、6000、500 应为 500。这个小方法足以制造四类故障而不引入数据库、HTTP 或 Spring。

编译 fixture 删除分号；运行 fixture 让零工时走除零；断言 fixture 把 12500 错写 12501；逻辑 fixture 把乘法改成加法。每个 fixture 只改变一个因素，验证脚本从干净基线复制后运行。

真实金额计算还涉及溢出、舍入、币种与权限，本章没有覆盖。示例只用于调试流程，不能直接作为生产计费实现。

## 22. 安全与隐私

最小复现应使用虚构数据。异常栈、请求参数、环境变量和绝对路径可能暴露用户名、token、客户设备信息。提交日志前脱敏，不把 settings.xml、密钥或完整生产输入上传给外部 AI。

不要在生产系统随意打开远程调试端口，也不要让程序为调试长期打印敏感变量。本章只在本地教学 Maven 项目使用 IDE 调试器。生产诊断需要认证、网络隔离、审计与变更流程，留到运维安全章节。

故意无限循环、栈溢出或资源耗尽可能影响机器。配套实验选择有限失败，不运行不可控破坏。注入故障后每次都从临时副本执行，避免污染基线。

## 23. 一份可复用诊断记录

建议模板：

```text
命令/范围：mvn --offline clean test，完整模块
预期：Tests run=4，全部为 0
实际：Tests run=4，Failures=1，Errors=0
失败阶段：surefire:test
第一处项目证据：RepairCostTest.java 的断言行
事实：expected 12500，actual 12600
假设：分钟折算公式错误
复核：断点参数 120/6000/500，中间表达式偏差 100
最小修复：恢复乘法再除以 60
重跑：原测试通过；完整 4/0/0/0
未验证：大数溢出、舍入、生产数据
```

把事实与推断分开，未来复盘才能发现思维错误。记录“已验证”和“未验证”也防止把一个样例扩张为全局结论。

## 24. 预测题

不运行先回答：

1. main 缺分号，最后阶段和 Tests run 是什么？
2. main 编译成功，测试 package 错，最后阶段是什么？
3. 测试抛 ArithmeticException，Failures/Errors 如何变化？
4. expected 12501、actual 12500，谁一定错？
5. 加法 bug 只用 0、0 测试，为何可能全绿？
6. 断点未命中，最先核对哪三个运行范围事实？

第四题答案不能仅凭日志决定哪边错；日志只证明不相等，需要独立规则。第五题训练“通过不等于没有逻辑 bug”。

## 25. 构建与实验顺序

1. 运行绿色 example，确认 4/0/0/0。
2. 阅读 lab 四个 fault fixture，逐个预测阶段与计数。
3. 运行 lab verifier，检查保存日志，而非只看最终 PASS。
4. 在绿色项目用 IDE 调试一条测试，记录 frame 与变量。
5. 独立做 SLA exercise，先看到 45/75 的红，再最小修复。
6. 运行私有解答只用于首次尝试后的核对。

自动验证覆盖命令与日志；断点证据必须人工完成。不要把脚本能 grep 到 `RepairCost.java` 误称为已经观察过 IDE 变量窗口。

## 26. 无 AI 训练

关闭 AI，限时 60—75 分钟：

1. 从四段陌生日志判断 compile、testCompile、Failure、Error。
2. 对 SLA 余量 starter 手算 expected，运行并写诊断。
3. 在业务方法断点，记录两个参数、当前 frame 和调用者 frame。
4. 只改一个运算符，重跑原测试和完整测试。
5. 不看笔记进行 120 秒复述。

验收时可随机改变输入为 target=90、elapsed=30。你应先算 60，再定位测试与实现完成修改，而不是让 AI 重生成项目。

## 27. 120 秒复述模板

“我先稳定复现并确认绿色基线，再按流水线判断失败阶段。main 编译失败停在 compile，测试源码错误停在 testCompile，都没有 Tests run；测试运行中未处理异常通常计为 Errors，expected 与 actual 不等计为 Failures。逻辑错误可以编译运行，只有独立 oracle 覆盖它时才会变成可见断言失败。我从第一条项目文件位置或项目栈帧开始，不从末尾 BUILD FAILURE 猜。必要时在疑似分支设置断点，观察当前 stack frame、参数和局部变量，Step Into/Over 前先预测。根因明确后做最小修改，先让原失败输入变绿，再跑完整测试并检查数量和 skipped。”

## 28. 复习与速查

### 复习节奏

- 当天：完成四类日志分类和一次断点记录。
- 48 小时后：只看截取日志写阶段、事实、假设与下一步。
- 一周后：从 SLA starter 独立走完红—绿—回归。

### 速查表

| 证据 | 说明 | 下一步 |
| --- | --- | --- |
| compiler:compile + 文件行列 | main 编译失败 | 修第一条源码错误并重编 |
| compiler:testCompile + cannot find symbol | 测试编译失败 | 查 package/import/可见性 |
| Errors>0 + 异常栈 | 测试运行异常 | 找第一条项目 frame 与变量 |
| Failures>0 + expected/actual | 断言不等 | 回到契约判断哪边错 |
| Tests run 少于预期 | 测试没被发现/被删/被跳过 | 查名称、注解、范围、Skipped |
| 全绿但用户结果错 | 覆盖或 oracle 缺口 | 加来自需求的最小失败用例 |
| 断点不命中 | 路径或配置不一致 | 查测试范围、输入、JDK、class |

## 29. 术语表

- **compile error**：源码无法编译成 class 的错误。
- **testCompile**：Maven 编译测试源码的阶段动作。
- **runtime exception**：class 已运行后在执行路径中出现的异常。
- **assertion failure**：actual 与 expected 不符合断言。
- **logic error**：程序可运行但违反业务规则的行为缺陷。
- **breakpoint**：让调试器在特定执行位置暂停的标记。
- **step over/into/out**：在当前层执行、进入调用、返回调用者的单步动作。
- **stack frame**：一次方法调用的执行位置与局部状态视图。
- **call stack**：当前线程的方法调用层次。
- **minimal reproduction**：保留触发问题所需最少条件的可重复样例。
- **regression**：修改后破坏此前已知行为。
- **first credible location**：最早直接连接项目代码和具体矛盾的位置。

## 30. 官方资料与边界

- [Java SE 25 Troubleshooting Guide](https://docs.oracle.com/en/java/javase/25/troubleshoot/)，复核于 2026-07-16；本章只采用基础问题定位思想，不进入 JVM 性能工具。
- [Java SE 25 `ArithmeticException` API](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/ArithmeticException.html)，复核于 2026-07-16。
- [JUnit 6.1.1 User Guide：Assertions 与运行测试](https://docs.junit.org/6.1.1/user-guide/)，复核于 2026-07-16。
- [Maven Surefire Plugin 3.5.5：Using JUnit Platform](https://maven.apache.org/surefire/maven-surefire-plugin/examples/junit-platform.html)，复核于 2026-07-16。
- [IntelliJ IDEA Debug code 官方帮助](https://www.jetbrains.com/help/idea/debugging-code.html)，复核于 2026-07-16；具体按钮布局会随 IDE 版本变化，断点、step、frame 与变量概念是稳定核心。
- [Java SE 25 文档](https://docs.oracle.com/en/java/javase/25/)，复核于 2026-07-16。

本章验证的是本地、单线程、小型 Maven/JUnit 项目的故障分类与调试闭环。未验证远程调试、并发时序故障、内存泄漏、性能 profiling、生产 dump、日志平台、完整异常架构或 Spring 调试。
