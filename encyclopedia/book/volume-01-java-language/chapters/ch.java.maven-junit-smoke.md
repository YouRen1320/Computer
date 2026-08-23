---
schema_version: 2
edition: 2026.2-draft
id: ch.java.maven-junit-smoke
title: Maven 最小项目、JUnit、断言与失败日志
responsibility: 建立 Java 自动化测试最小闭环，不提前教授 Mock、参数化测试或 Spring 上下文
volume: '01'
order: 10
level: L1
status: drafting
path: book/volume-01-java-language/chapters/ch.java.maven-junit-smoke.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java.methods
version_surfaces:
- jdk-25
- maven-3
- junit-6
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释Maven 最小项目、JUnit、断言与失败日志的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-maven-smoke
  - java-junit-smoke
  covers_topics:
  - maven.standard-layout
  - maven.test-lifecycle
  - maven.dependency-scope-test
  - junit.test-case
  - junit.assert-equals
  - junit.failure-report
  uses_capabilities:
  - java.methods
  - foundation.toolchain-env-build
  - foundation.verification-debug-test
  - java.build-testing
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 创建标准 Maven 工程，为 OrderAmountCalculator 写正常和零数量两条 JUnit 测试并从命令行执行 mvn clean test
  covers_topic_groups:
  - java-maven-smoke
  - java-junit-smoke
  covers_topics:
  - maven.standard-layout
  - maven.test-lifecycle
  - maven.dependency-scope-test
  - junit.test-case
  - junit.assert-equals
  - junit.failure-report
  uses_capabilities:
  - java.methods
  - foundation.toolchain-env-build
  - foundation.verification-debug-test
  - java.build-testing
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 分别注入 package 不一致、源码缺分号和错误 expected，区分 compile、testCompile、surefire:test 三个失败阶段，并把异常定位到第一处可信证据
  covers_topic_groups:
  - java-maven-smoke
  - java-junit-smoke
  covers_topics:
  - maven.standard-layout
  - maven.test-lifecycle
  - maven.dependency-scope-test
  - junit.test-case
  - junit.assert-equals
  - junit.failure-report
  uses_capabilities:
  - java.methods
  - foundation.toolchain-env-build
  - foundation.verification-debug-test
  - java.build-testing
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# Maven 最小项目、JUnit、断言与失败日志

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《方法、参数传递、返回值、重载与递归边界》](ch.java.methods.md)：独立完成Maven 最小项目、JUnit 最小闭环前，必须先具备「方法、参数传递、返回值、重载与递归边界」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。自动测试通过证明固定样例符合当前断言，不自动证明学习完成、需求完整或程序绝对正确，也不会修改学习进度。

单个 `.java` 文件可以直接用 `javac` 编译，但真实项目需要稳定回答更多问题：源码和测试放在哪里，使用哪个 JDK 目标，JUnit 从哪里来，谁发现测试方法，执行了几条，失败发生在业务源码编译、测试源码编译，还是测试运行。本章用 **Maven 3.9.16 + JDK 25 + JUnit 6.1.1** 建立最小闭环。

范围严格保持在非 Spring 小项目：标准目录、POM 基本坐标、test scope、生命周期到 `test`、`@Test`、`assertEquals`、Surefire 汇总和三类失败。不教授 Mock、参数化测试、测试替身、覆盖率、集成测试、Spring 上下文或复杂插件配置。官方资料复核日期为 **2026-07-16**。

## 1. 学完后必须留下什么证据

1. **解释证据**：在 120 秒内解释 Maven 标准目录、POM 坐标、依赖 scope、`mvn test` 执行链、JUnit 与 Surefire 的职责，以及 `Failures` 和 `Errors` 的区别。
2. **构建证据**：从空目录建立金额计算器，写正常数量和零数量两条测试；命令行执行 `mvn clean test`，日志明确显示 Tests run=2、Failures=0、Errors=0、Skipped=0。
3. **诊断证据**：分别注入 main 缺分号、测试 package 不一致和错误 expected，判断失败在 compile、testCompile 或 surefire:test，并从第一处项目位置修复后完整复跑。

配套入口：

- [Maven + JUnit 最小闭环](../../../examples/encyclopedia/ch.java.maven-junit-smoke/README.md)
- [生命周期故障分层实验](../../../labs/encyclopedia/ch.java.maven-junit-smoke/README.md)
- [独立练习：设备停机分钟数测试](../../../exercises/encyclopedia/ch.java.maven-junit-smoke/README.md)

## 2. 直觉模型：约定目录上的流水线

Maven 像一条按约定装配的流水线。你把业务源码放在 main 源集、测试源码放在 test 源集，在 POM 中声明项目身份、Java 版本与依赖；Maven 按生命周期阶段依次处理。JUnit 定义怎样标记测试和怎样断言，Surefire 在 Maven 的 test 阶段发现并运行测试。

```text
pom + src/main/java + src/test/java
              |
              v
 resources -> compile -> testResources -> testCompile -> surefire:test
              |                            |                |
           业务源码                      测试源码          测试执行
```

失败在哪一站，决定后面的站是否有机会执行。main 源码缺分号时 compile 已失败，不会出现 Tests run；测试源码引用不到类时 main compile 可能成功，但 testCompile 失败；断言期望错误时两次编译都成功，Surefire 才能报告测试失败。

## 3. Maven 解决什么，不解决什么

Maven 负责读取项目模型、解析依赖、调用编译和测试插件、按生命周期组织任务，并把产物放进 `target`。它不理解 FactoryCare 的金额规则，也不自动知道 1999×3 应为 5997。业务正确性来自你写下的契约与测试 oracle。

`mvn test` 不是“启动 main”。它执行到 test 阶段；main 源码会先编译，测试源码随后编译，测试引擎再运行匹配测试。若项目没有测试，构建仍可能成功。因此 `BUILD SUCCESS` 只代表这次请求的 Maven 生命周期没有报告失败，不能单独证明“确实运行了两条测试”。

Maven 也不会替你选择正确 JDK。`mvn -v` 显示 Maven 进程实际使用的 Java 版本与 home；它可能与终端里另一次 `java -version` 不同。运行本章前应确认 Maven 3.9.16 且 Java version 为 25。

## 4. 标准目录为什么重要

最小结构如下：

```text
project/
├── pom.xml
└── src/
    ├── main/
    │   └── java/com/factorycare/learning/OrderAmountCalculator.java
    └── test/
        └── java/com/factorycare/learning/OrderAmountCalculatorTest.java
```

`src/main/java` 放产品运行需要的源码；`src/test/java` 放验证产品行为的测试源码。package `com.factorycare.learning` 对应目录 `com/factorycare/learning`。Maven 默认识别这些路径，无需为每个项目重复配置。

构建后出现的 `target/classes` 是 main 编译结果，`target/test-classes` 是测试编译结果，`target/surefire-reports` 保存测试报告。它们都可由源码和 POM 重建，通常不提交 Git。删除 target 不会删除源码；`mvn clean` 的核心效果就是清理上次构建输出，避免陈旧 class 影响判断。

如果把测试类误放进 main，它可能把 JUnit 变成生产运行依赖；如果把业务类误放进 test，正式产物不包含它。目录不是美观偏好，而是依赖可见性和产物边界。

## 5. POM 的项目坐标

POM 是 Project Object Model。最小项目常见三项坐标：

```xml
<groupId>com.factorycare.learning</groupId>
<artifactId>week-01-java-smoke</artifactId>
<version>1.0-SNAPSHOT</version>
```

`groupId` 通常表示组织或命名空间；`artifactId` 是当前模块名；`version` 标识这个产物版本。三者共同帮助仓库与依赖系统识别产物。它们不是 Java package 的强制同义词，但保持有意义的一致命名能减少混乱。

`SNAPSHOT` 表示开发中的可变版本语义。本章不发布产物，只认识坐标。不要因为“坐标能随便写”就复制 `org.example` 到所有项目；也不要把客户名、用户名或秘密写入坐标。

`modelVersion` 描述 POM 模型格式，不是项目版本。初学者常把它和 `<version>` 混淆。修改 JDK 目标也不应改 modelVersion，而应配置编译 release 属性。

## 6. 固定 JDK 编译目标

本项目使用：

```xml
<properties>
  <maven.compiler.release>25</maven.compiler.release>
  <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
</properties>
```

`release=25` 让编译器以 Java 25 语言与 API 目标编译。它不负责切换 Maven 自己运行在哪个 JVM；若 Maven 运行在更旧 JDK 上，仍可能无法完成。先看 `mvn -v`，再看 POM，分别确认“运行构建的 JDK”和“目标 release”。

UTF-8 属性使源码资源处理更明确。编码配置不能修复错误字符本身，但能减少不同机器默认编码造成的漂移。固定版本和编码是可重复构建的一部分，不等于只要 POM 相同，所有操作系统环境就完全相同。

## 7. 依赖、BOM 与 test scope

JUnit 不是 JDK 自带语言关键字，而是外部测试库。示例通过 JUnit BOM 固定同一系列组件版本，再声明 Jupiter：

```xml
<dependency>
  <groupId>org.junit.jupiter</groupId>
  <artifactId>junit-jupiter</artifactId>
  <scope>test</scope>
</dependency>
```

`scope=test` 表示它用于测试编译和测试运行，不进入正常 main 编译依赖，也不应成为生产运行 classpath 的常规组成。这样业务代码不能偷偷依赖 `Assertions`，发布产物也保持边界清楚。

BOM 的作用是集中管理兼容版本；本章固定 JUnit 6.1.1。不要把“没写 dependency 版本”误解为版本未固定，版本来自导入的 BOM。也不要把 BOM 当作会自动加入所有库：仍需显式声明 `junit-jupiter`。

依赖首次使用通常需要进入本地仓库。本章验证脚本强制 `--offline`，只允许使用已有缓存，不在验证期间下载。若缓存缺失，离线失败说明环境前置不满足，不应偷偷联网后把结果描述为同一次离线验证。

## 8. Maven 生命周期到 test

执行 `mvn test` 会按顺序到达 test 之前的阶段。日志里常见：

1. resources：处理 main 资源。
2. compiler:compile：编译 `src/main/java` 到 `target/classes`。
3. testResources：处理测试资源。
4. compiler:testCompile：编译 `src/test/java` 到 `target/test-classes`。
5. surefire:test：发现并运行测试。

这是有序链，不是五个互不相关命令。前一阶段失败，后续不会运行。日志出现 `Nothing to compile - all classes are up to date` 表示增量判断认为无需重编，不代表源码不存在；需要排除缓存影响时执行 `mvn clean test`。

`clean` 属于独立 clean 生命周期，`test` 属于 default 生命周期。写 `mvn clean test` 表示先清理，再走到 test。它比每次手动删除 target 更清楚，但日常快速反馈不必机械 clean；诊断陈旧产物或收集验收证据时再 clean。

## 9. JUnit 的最小测试结构

一个测试类可以写成：

```java
class OrderAmountCalculatorTest {
    @Test
    void calculatesTotalForMultipleItems() {
        int result = OrderAmountCalculator.calculateTotalCents(1999, 3);
        assertEquals(5997, result);
    }
}
```

`@Test` 告诉 JUnit 这个方法是测试用例。本章把注解当作固定标记使用，不解释注解元数据机制。方法名描述行为，不以 `test1` 代替含义。测试分三步：准备输入、调用行为、断言结果。

测试类与测试方法不必为了本章写 public。它们位于与业务类相同 package 时，可以访问 package-private 成员；访问规则与 static 是两件事。static 让调用不必先创建对象，访问修饰决定测试是否有权限。

一条 `@Test` 方法通常计为一项 test。类里有两个方法但漏掉一个 `@Test`，Surefire 可能只报告 Tests run=1；所以要看实际数量，不能仅凭文件里“肉眼看到两个方法”。

## 10. `assertEquals(expected, actual)`

断言把事先确定的 expected 和程序运行得到的 actual 比较：

```java
assertEquals(5997, result);
```

第一个参数是期望值 5997，来自 1999×3 的规则与手算；第二个参数是实际结果。顺序写反时相等场景仍通过，但失败日志会把 expected/actual 说反，误导诊断。

断言不是 `if` 的神秘替代品，而是测试框架提供的可报告检查。不相等时，JUnit 记录 AssertionFailedError，Surefire 汇总为 Failure。不要为了让测试绿而把 expected 改成当前错误 actual；先回到业务契约判断哪一边错。

零数量测试是边界用例，不是重复普通用例。它能发现代码错误地加一次单价、拒绝合法 0 或使用错误默认值。两条测试仍远非完整规格，但足以建立最小闭环。

## 11. JUnit 与 Surefire 的职责边界

JUnit Jupiter 提供测试编程模型和执行引擎：`@Test`、Assertions、测试发现与执行语义。Maven Surefire Plugin 把测试运行接到 Maven test 阶段，建立测试 classpath，启动 provider，收集结果并决定构建是否失败。

因此看到：

```text
--- surefire:3.5.5:test (default-test) ---
Running com.factorycare.learning.OrderAmountCalculatorTest
Tests run: 2, Failures: 0, Errors: 0, Skipped: 0
```

可以说 Surefire 在 Maven 中运行了两条 JUnit 测试。不要说“JUnit 就是 Maven 插件”，也不要说“Surefire 定义 assertEquals”。它们协作但职责不同。

测试命名与发现有默认约定。示例用 `*Test`，避免研究更复杂包含规则。如果测试文件名完全不匹配默认模式，可能编译了却未运行，再次说明 Tests run 数量不可省略。

## 12. 四个计数分别表示什么

- **Tests run**：实际执行的测试数量。
- **Failures**：测试执行到了断言，但结果与 expected 不一致等测试失败。
- **Errors**：测试准备或执行中出现未按测试契约处理的运行异常，未得到正常断言结论。
- **Skipped**：被跳过而没有执行验证主体的测试。

目标 `2,0,0,0` 表示两条都实际运行、无失败、无错误、无跳过。仅 `BUILD SUCCESS` 不提供这个细度。`Tests run: 0` 即使成功，也不能作为两条金额规则已经验证的证据。

Failures 与 Errors 都会让构建失败，但诊断方向不同。Failure 首先看 expected、actual 和业务规则；Error 首先看异常类型与第一条项目代码栈帧。后续调试章会更细讲运行异常。

## 13. 第一类故障：main 源码缺分号

业务源码写成：

```java
return unitPriceCents * quantity
```

Maven 在 compiler:compile 报 compilation error，并给出 `OrderAmountCalculator.java:[行,列]`。因为 main class 尚未生成，testCompile 和 Surefire 不会发生，也不会出现 Tests run。

可信证据是最早的编译阶段、项目文件位置和 `';' expected` 一类具体信息。末尾 `Failed to execute goal` 与 `BUILD FAILURE` 只是汇总。修复分号后应重新运行原命令，确认流水线继续推进到 test。

这类错误不能记作 JUnit Errors=1；JUnit 根本没运行。日志中的英文 “error” 与 Surefire 汇总字段 `Errors` 不是同一分类语境。

## 14. 第二类故障：测试 package 不一致

假设 main 源码 package 是 `com.factorycare.learning`，测试错误写成 `com.factorycare.wrong`，又没有导入业务类。main compile 成功，testCompile 处理测试源码时报告 `cannot find symbol`。

此时仍没有 Tests run，因为测试 class 没编译出来。失败阶段比“文件在 src/test”更重要：你应先检查测试 package、import、类名和可见性，而不是修改业务乘法。

修复方式可能是恢复正确 package，或在设计允许时加入正确 import。不要只把目录拖来拖去而不核对源码首行。package 声明、目录和访问边界应保持一致且可解释。

## 15. 第三类故障：错误 expected

把 5997 写成 5998 时，两次编译都成功，Surefire 运行两条测试，其中一条 Failure：

```text
expected: <5998> but was: <5997>
Tests run: 2, Failures: 1, Errors: 0, Skipped: 0
```

第一步不是立即改业务，也不是立即改 expected，而是回到规则手算。若 1999×3 明确为 5997，expected 错；若需求其实包含额外费用，则当前实现和旧测试可能都需调整。日志告诉你不相等，不替你决定需求。

失败位置通常指向测试中的 assertEquals 行。这是第一处直接观察到矛盾的位置；业务根因也可能在被测方法。用 expected 来源、实际值和实现共同判断。

## 16. 如何读一段 Maven 日志

推荐从上到下寻找最后成功阶段与第一条具体失败：

1. 确认项目坐标和实际读取的 POM。
2. 找 `compiler:compile` 是否完成。
3. 找 `compiler:testCompile` 是否完成。
4. 若出现 Surefire，再看测试类、计数和第一条失败。
5. 找第一条属于项目源码的 `文件:[行,列]` 或测试栈帧。
6. 最后再看 BUILD SUCCESS/FAILURE 汇总。

不要从最末尾向上只读一行 Help 链接。它通常解释 Maven goal 失败的一般原因，不包含本次源码的首要事实。也不要被大量下载或插件日志淹没；固定版本、离线模式和小项目能减少噪声。

一份合格诊断应写：“失败在 testCompile；main 2 个源码已编译，测试源码找不到 OrderAmountCalculator；最先可信位置是 OrderAmountCalculatorTest.java 的调用行；未进入 Surefire，因此没有 Tests run。”

## 17. 增量编译、缓存与 `clean test`

连续运行时 Maven 可能报告所有 class 已是最新。这是优化，不是错误。修改 main 源码通常触发 compile，修改测试只触发 testCompile。理解这些日志能避免把 `Nothing to compile` 误认为 Maven 没工作。

当你怀疑旧 class、重命名文件或 package 移动留下残留时，用 `mvn clean test` 删除 target 后重建。它提供更强的“从源码重建”证据，但耗时略多。日常每次按保存都 clean 会降低反馈速度，因此可用 `mvn test` 快速循环，验收时再 clean test。

IDE 的绿色结果与命令行 Maven 都有价值，但不应互相替代。IDE 可能使用不同 JDK、运行配置或单条测试；最终项目证据应包含命令、版本与完整计数。

## 18. 测试能证明到哪里

两条测试通过能证明：在当前代码、依赖、JDK 和固定输入下，两个 actual 与两个 expected 相等，且 Maven 完成 test 阶段。它不能证明所有整数都正确、没有溢出、需求没有遗漏、生产环境配置相同或系统没有安全问题。

测试价值来自覆盖重要规则和失败边界，不是数字越多越好。复制同一输入一百遍仍只验证一个点。当前最小集合选一个普通多数量和一个零数量，用来训练闭环；后续会增加更多测试设计知识。

AI 生成测试时尤其要问 expected 从哪里来。模型可能同时生成错误实现和迎合实现的测试，两边一致就全绿。先由人写契约、手算 oracle，再审查生成代码，才能区分验证与自证。

## 19. FactoryCare 增量

金额计算器是 FactoryCare 的脱敏小切片。业务代码只做“单价分×数量”，测试固定 1999×3=5997 和数量 0=0。它没有数据库、HTTP、Spring、权限或真实订单，不应该被包装成完整后端项目。

这个切片仍训练了以后会复用的结构：生产源码与测试源码分离；构建工具固定版本；依赖只进入所需 scope；测试从需求得出 expected；失败日志按阶段定位；修复后完整复跑。

公开仓库不得包含真实客户数据、token、私有 Maven 仓库密码或 settings.xml。POM 中只使用公开坐标，验证日志若要提交也应检查本机绝对路径和用户信息。

## 20. 安全与供应链边界

依赖是执行到本机的外部代码。不要为了“版本更新”任意使用未知仓库、snapshot 或复制来源不明的插件。固定 JUnit 与 Surefire 版本，优先官方 Maven Central 坐标和官方文档。验证脚本用离线模式，减少执行期间外部状态变化。

离线不等于绝对供应链安全：缓存中的工件仍来自此前下载，且本章没有验证签名或构建来源。它只证明这次运行不需要下载。不要把本机 `~/.m2`、settings.xml 或凭据复制进项目。

测试日志可能包含绝对路径、输入值和异常消息。公开前脱敏。示例没有秘密，并把构建目录加入 gitignore。真正含敏感输入的失败应使用最小的虚构复现数据。

## 21. 预测—构建—诊断

运行实验前填写：

| 变更 | 预测最后阶段 | Tests run | 预测分类 |
| --- | --- | ---: | --- |
| 无变更 | surefire:test 完成 | 2 | 全绿 |
| main 缺分号 | compile | 无 | 编译错误 |
| test package 错 | testCompile | 无 | 测试编译错误 |
| expected=5998 | surefire:test | 2 | Failures=1 |

然后执行实验脚本，逐项比较。若预测错了，写明混淆：把 compile error 当成 Surefire Error，还是认为存在测试文件就会 Tests run。恢复绿色后再执行 `mvn clean test`，不能停在“改完看起来对”。

## 22. 无 AI 训练

关闭 AI，限时 60 分钟：

1. 从空目录写 POM、业务类和两条测试。
2. 运行前手算 expected，并预测 Tests run。
3. 依次注入三类故障，每次只改一个点，记录阶段、分类和第一处可信位置。
4. 不看笔记解释 JUnit、Surefire、Maven 的职责边界。
5. 把数量 3 改为 4，独立更新正确 oracle 并通过完整测试。

允许查官方 POM 语法，不允许让 AI 直接生成诊断结论。目标不是背 XML，而是能导航生成项目、改变一个规则、修复一条测试并解释日志。

## 23. 120 秒复述模板

“Maven 按标准目录和 POM 构建项目。main 源码在 src/main/java，测试在 src/test/java；JUnit 是测试库，@Test 标记用例，assertEquals 比较事先确定的 expected 和运行得到的 actual；Surefire 把 JUnit 运行接到 Maven test 阶段。mvn test 先 compile main，再 testCompile 测试，最后 surefire:test。main 缺分号停在 compile；测试 package 错停在 testCompile；断言错会运行测试并记录 Failure。BUILD SUCCESS 必须结合 Tests run、Failures、Errors、Skipped，文件存在或代码能编译不等于功能正确。修复后要重跑原失败输入和完整测试集。”

## 24. 复习与速查

### 复习节奏

- 当天：画生命周期链，运行 2 条绿测与 3 类故障。
- 48 小时后：从日志片段判断阶段，不运行代码先预测。
- 一周后：从空目录重建 exercise，并口述 scope 与计数。

### 速查表

| 现象 | 阶段 | 先查 |
| --- | --- | --- |
| main 缺分号 | compile | main 文件行列 |
| 测试找不到业务类 | testCompile | package/import/可见性 |
| expected 与 actual 不同 | surefire:test | 业务契约、断言行、实现 |
| BUILD SUCCESS 但无验证 | test 或更早 | Tests run 是否为预期数量 |
| IDE 绿、命令行失败 | 环境/构建 | JDK、Maven、运行范围 |
| 结果疑似旧 class | 增量输出 | `mvn clean test` 重建 |

## 25. 术语表

- **Maven**：基于项目模型、约定与生命周期的构建工具。
- **POM**：描述坐标、属性、依赖和插件的项目模型文件。
- **coordinate**：groupId、artifactId、version 组成的产物身份。
- **scope=test**：依赖只用于测试编译和运行的可见范围。
- **lifecycle phase**：Maven 有顺序的构建阶段。
- **JUnit Jupiter**：JUnit 6 中用于编写和运行 Jupiter 测试的模型与引擎。
- **Surefire**：在 Maven test 阶段运行测试的插件。
- **assertion**：把 actual 与 expected 比较的可报告检查。
- **Failure**：测试运行到断言但结果不符合期望。
- **Error**：测试执行中发生未正常完成的异常类错误。
- **oracle**：独立于当前实现确定的预期结果。

## 26. 官方资料与版本说明

- [Apache Maven 3.9.16 Release Notes](https://maven.apache.org/docs/3.9.16/release-notes.html)，复核于 2026-07-16。
- [Maven Introduction to the Standard Directory Layout](https://maven.apache.org/guides/introduction/introduction-to-the-standard-directory-layout.html)，复核于 2026-07-16。
- [Maven Introduction to the Build Lifecycle](https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html)，复核于 2026-07-16。
- [Maven Dependency Mechanism](https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html)，复核于 2026-07-16。
- [JUnit 6.1.1 User Guide](https://docs.junit.org/6.1.1/user-guide/)，复核于 2026-07-16。
- [Maven Surefire Plugin 3.5.5](https://maven.apache.org/surefire/maven-surefire-plugin/)，复核于 2026-07-16。
- [Java SE 25 文档](https://docs.oracle.com/en/java/javase/25/)，复核于 2026-07-16。

稳定核心是标准目录、依赖范围、生命周期、测试发现、断言与失败分层；补丁版本和插件输出格式可能变化。未在本章验证 Spring 测试、Mock、参数化测试、集成测试、覆盖率、并行测试、Maven Wrapper、发布仓库或多模块构建。
