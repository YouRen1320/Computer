---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.maven-reproducible-builds
title: Maven 生命周期、依赖范围、插件与可重复构建
responsibility: 深化 Maven 项目模型与可重复构建证据，不在本章教授框架 Starter 或发布流水线
volume: '03'
order: 1
level: L2
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.maven-reproducible-builds.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java.maven-junit-smoke
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
  text: 在 120 秒内解释Maven 生命周期、依赖范围、插件与可重复构建的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - maven-project-model
  - maven-reproducibility
  covers_topics:
  - maven.pom-coordinates
  - maven.scope-transitive
  - maven.dependency-tree
  - maven.lifecycle-plugin
  - maven.wrapper-toolchain
  - maven.reproducible-build
  uses_capabilities:
  - java.build-testing
  - foundation.toolchain-env-build
  - foundation.verification-debug-test
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 配置一个多依赖 Maven 工程的 scope、插件版本、Wrapper 与 JDK toolchain，保存 dependency:tree 和两次 clean package 摘要
  covers_topic_groups:
  - maven-project-model
  - maven-reproducibility
  covers_topics:
  - maven.pom-coordinates
  - maven.scope-transitive
  - maven.dependency-tree
  - maven.lifecycle-plugin
  - maven.wrapper-toolchain
  - maven.reproducible-build
  uses_capabilities:
  - java.build-testing
  - foundation.toolchain-env-build
  - foundation.verification-debug-test
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入插件版本漂移、test 依赖进入运行时和 IDE/Maven JDK 不一致，按 lifecycle 与 toolchain 证据修复，并把异常定位到第一处可信证据
  covers_topic_groups:
  - maven-project-model
  - maven-reproducibility
  covers_topics:
  - maven.pom-coordinates
  - maven.scope-transitive
  - maven.dependency-tree
  - maven.lifecycle-plugin
  - maven.wrapper-toolchain
  - maven.reproducible-build
  uses_capabilities:
  - java.build-testing
  - foundation.toolchain-env-build
  - foundation.verification-debug-test
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# Maven 生命周期、依赖范围、插件与可重复构建

> 本章状态为 `drafting`。正文、命令和配套工程可用于学习与试运行，但文件存在或验证器通过都不能自动证明学习者已经掌握，也不会自动修改 `PROGRESS.md`。

在最小 Maven 烟雾项目里，你已经见过 `pom.xml`、`src/main/java`、`src/test/java` 和 `mvn test`。当时的目标只是打通“业务代码—测试代码—JUnit—Surefire”这条最短链路。本章把视角从“一条命令能跑”提升到“任何人能解释这次构建到底使用了什么、为什么得到这个产物、换一台受控环境能否得到同样结果”。

Maven 不是 Java 编译器，也不是测试框架。它读取项目模型，计算继承、属性、依赖和插件配置，构造不同阶段所需的类路径，再按生命周期把插件目标组织起来。`javac` 负责把 Java 源码编译成字节码，JUnit 提供测试编程模型与测试引擎，Surefire 插件在 Maven 的 `test` 阶段发现并运行测试。把这些角色混成一个“mvn 会做所有事”的黑盒，是后续依赖冲突、构建漂移和供应链问题的根源。

本章只深化通用 Maven 工程能力，不引入 Spring、Spring Boot Starter、CI/CD 发布流水线、多模块聚合工程或私服运维。版本基线是 **JDK 25 LTS、Apache Maven 3.9.16、JUnit 6.1.1、Maven Surefire 3.5.5**；官方资料复核日期为 **2026-07-16**。版本号是当前教材的可执行表面，坐标、依赖图、生命周期、插件绑定与可重复构建边界则是稳定核心。

## 1. 学完后必须留下什么证据

1. **解释证据**：在 120 秒内说明 POM、坐标、仓库、依赖图、scope、生命周期、phase、plugin goal、Wrapper、toolchain 和可重复构建各自解决什么问题；举出一个“源码没变但产物变了”的反例。
2. **构建证据**：让 FactoryCare 的最小模块在 JDK 25 与 Maven 3.9.16 下执行 `clean test` 和 `clean package`；保存测试数、依赖树、effective POM 摘要、产物哈希与工具版本。
3. **边界证据**：证明 JUnit 是 `test` scope，只进入测试编译和测试运行类路径，不应被业务代码直接导入，也不应作为运行时业务依赖被打进普通 JAR。
4. **诊断证据**：分别观察错误 scope、遗漏插件版本、离线缓存缺失、IDE 与 Maven JDK 不同、固定时间戳缺失等故障，把结论落到第一处可信日志，而不是只看最后一行 `BUILD FAILURE`。
5. **重放证据**：在清理 `target` 后连续构建两次，比较指定产物的 SHA-256；说明“本机两次相同”只证明局部一致，为什么仍不等于第三方独立可复现。

配套工件：

- [可重复构建示例](../../../examples/encyclopedia/ch.java-engineering.maven-reproducible-builds/README.md)
- [FactoryCare 构建取证实验](../../../labs/encyclopedia/ch.java-engineering.maven-reproducible-builds/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.maven-reproducible-builds/README.md)

私有解析只用于完成独立预测、改动和诊断以后核对。公开 starter 不引用私有目录，私有答案也不能进入公开出版物。

## 2. 先建立执行模型：从命令到进程与文件

在终端输入 `mvn test` 时，至少发生以下链路：shell 按 `PATH` 找到 `mvn`；Maven 启动脚本选择 Java 运行时；Maven JVM 读取全局、用户和项目配置；模型构建器合并 Super POM、父 POM、当前 POM、属性与激活的 profile；依赖解析器读取本地仓库，必要时访问配置的远程仓库；生命周期执行器把到 `test` 为止的阶段展开为插件目标；Compiler 插件调用编译器；Surefire 启动测试 JVM 并通过 JUnit Platform 发现测试；每个插件把输出写入 `target` 或其他配置位置。

因此“我的 Java 是 25”至少有四种含义：终端中 `java -version` 是 25；`javac -version` 是 25；运行 Maven 的 JVM 是 25；Compiler 插件的 `release` 目标是 25。这四项可以不同。IDE 还可能用第五套 Project SDK 或 Maven Runner JDK。诊断时必须分别观察，不能由一个命令推断全部。

构建的主要输入也不只有源码。POM、父 POM、settings、激活 profile、环境变量、JDK、Maven、插件与依赖字节、资源文件、默认编码、时区、用户名、绝对路径、文件时间戳都可能影响结果。可重复构建的第一步不是“多跑一次”，而是列清输入边界。

## 3. POM 是项目模型，不是命令清单

POM 是 Project Object Model。最小坐标由 `groupId`、`artifactId`、`version` 组成，常与 `packaging` 一起描述“这个项目产生什么构件”。坐标不是随意标签，而是仓库中定位构件的地址。`com.factorycare:work-order-core:1.0.0` 表示组织域、构件名和版本；默认 `packaging` 为 `jar`。

```xml
<groupId>com.factorycare</groupId>
<artifactId>work-order-core</artifactId>
<version>1.0.0-SNAPSHOT</version>
```

`SNAPSHOT` 表示仍会变化的开发版本，不是“比较新的正式版”。正式发布版本应是不可变构件；同一坐标若被覆盖，缓存和审计都会失去可信基线。学习工程可以使用 snapshot，但依赖和插件本身应锁定明确版本，避免版本范围与 `LATEST` 一类漂移入口。

POM 中的 `<properties>` 是模型值，不等于 shell 环境变量。`${project.version}`、`${maven.compiler.release}` 等表达式由 Maven 插值；`$JAVA_HOME` 由 shell 展开。两者的解析时机和来源不同。把环境变量直接注入产物会使构建依赖机器状态，因此只有明确的部署参数才应从环境进入，编译参数应尽量显式且可审计。

Maven 的实际模型还包含 Super POM 默认值、父 POM 继承、profile 与插件默认绑定。你眼前的 `pom.xml` 只是输入之一。`mvn help:effective-pom` 展示合并后的有效模型；带 `-Dverbose` 时还能标注配置来源。它适合回答“这个版本到底从哪里继承”“为什么某个插件被执行”，但输出可能含本机路径或仓库信息，提交前要脱敏。

## 4. 依赖声明构造的是图，不是一张下载清单

直接依赖可以再依赖其他构件，形成传递依赖图。Maven 会遍历 POM 元数据并选择最终版本。出现同一构件的多个版本时，Maven 3 的常见调解规则是“最近定义优先”；同深度时声明顺序也可能影响结果。这个规则能让构建继续，却不代表自动选中了最安全或最兼容的版本。

`mvn dependency:tree` 是观察最终图的第一工具。重点不是把整棵树背下来，而是回答：某个构件由谁引入、最终选了哪个版本、scope 是什么、哪个候选被省略。直接使用某个库的 API 时，应显式声明该直接依赖，不要侥幸借用另一库顺带带来的传递依赖；上游一旦移除传递边，代码就会突然失去类。

`dependencyManagement` 负责集中提供版本和默认配置，不会因为写在那里就自动把库加入类路径。真正使用仍需要 `<dependencies>` 声明。BOM 是 `type=pom`、`scope=import` 的依赖管理载体，适合对齐同一组件族版本。JUnit 官方建议在没有框架代管版本时使用 `org.junit:junit-bom` 对齐 Platform、Jupiter 和 Vintage；本章使用 6.1.1。

排除 `exclusion` 应针对确实不需要或存在风险的传递边，并配套测试。盲目排除到“依赖树看起来干净”可能在运行时制造 `ClassNotFoundException` 或 `NoSuchMethodError`。每个排除都应回答：哪条路径引入、为什么不需要、由谁提供替代、哪个测试覆盖了运行边界。

## 5. scope 决定在哪些类路径可见

常用 scope 可以先用三个问题理解：主代码编译时能否看见？应用运行时能否看见？测试编译和运行时能否看见？

| scope | 主代码编译 | 运行 | 测试 | 典型用途 |
| --- | --- | --- | --- | --- |
| `compile` | 是 | 是 | 是 | 业务代码直接使用的普通库 |
| `provided` | 是 | 否，由容器或运行环境提供 | 是 | 容器 API 等明确外部提供项 |
| `runtime` | 否 | 是 | 是 | 只在运行期需要的实现 |
| `test` | 否 | 否 | 是 | JUnit、测试辅助库 |

`system` 绑定本机绝对文件，破坏可移植性，官方也不推荐；`import` 只用于 `dependencyManagement` 中导入 BOM，不是普通运行 scope。初学阶段不要靠 `systemPath` 修复“依赖下载不到”，那只是把仓库问题藏进个人电脑。

JUnit 必须是 `test` scope。若把它改为默认 `compile`，主代码可能错误导入 `Assertions` 而仍能编译，依赖也可能传播给下游；这会让测试工具污染业务契约。普通 JAR 默认不会把依赖 JAR 打包进自己，但 scope 仍决定编译和传递边界，未来若使用打包插件制作 fat JAR，错误 scope 更可能直接进入发布物。

scope 不是安全沙箱。`test` scope 只约束 Maven 类路径，不能保证测试不会访问网络、文件或密钥。测试隔离需要额外的进程、容器、权限和替身设计。

## 6. 生命周期、阶段与插件目标

Maven 内建 `clean`、`default`、`site` 三套生命周期。最常用的 default 生命周期包含 `validate`、`compile`、`test`、`package`、`verify`、`install`、`deploy` 等阶段。调用较后的阶段会顺序执行同一生命周期中之前的阶段；`mvn package` 已包含编译和测试，不需要写成 `mvn compile test package`。

`clean` 属于另一套生命周期。`mvn clean test` 是依次请求 `clean` 生命周期的阶段和 default 生命周期的 `test` 阶段。`clean` 删除旧输出，能揭露“只因 target 中残留 class 才成功”的问题；但每次都 clean 会放弃增量构建速度，所以日常快速反馈与发布取证可以采用不同命令，不能把“更慢”误认为“更正确”。

phase 是生命周期位置，goal 是插件提供的具体操作。例如日志中的 `compiler:compile`、`surefire:test`、`jar:jar` 是插件目标。packaging 会提供默认绑定，POM 也可把额外 goal 绑定到 phase。执行顺序来自生命周期、packaging、插件声明和 execution 配置的共同结果。

直接运行 `mvn dependency:tree` 是按前缀调用 Dependency 插件的 goal；运行 `mvn test` 是请求 phase。二者语义不同。为减少前缀解析和版本漂移，自动化证据中可以写完整坐标与固定版本；日常交互可使用短前缀，但要从日志确认实际版本。

`verify` 比 `test` 更靠后，适合承载对已打包结果的质量检查；`install` 会把构件写入本地仓库；`deploy` 会写远端仓库。不要为了“更完整”在本地随意执行 `deploy`，它是有外部副作用的发布动作。

## 7. 插件也属于构建依赖，必须锁版本

依赖决定程序编译或运行时使用的库，插件决定构建过程中执行的代码。插件同样来自仓库、同样可能有漏洞和行为变化。只锁业务依赖、不锁插件版本，仍然无法重放构建。

本章示例显式锁定 Compiler、Surefire、JAR、Dependency、Help 与 Enforcer 等实际使用插件的版本。不是每个 POM 都必须复制一份超长插件清单；团队可以通过受控父 POM 或 `pluginManagement` 集中管理，但最终 effective POM 必须得到明确版本。

`pluginManagement` 与 `dependencyManagement` 类似，提供插件默认配置，不一定触发插件执行。`plugins` 中声明或生命周期默认绑定才会执行相应插件。排查“配置写了却没生效”时，先区分管理与使用，再查看 effective POM 和实际日志。

构建插件是在开发机或 CI 中运行的第三方代码。审查来源、固定版本、缩小仓库、验证校验和、定期扫描构建依赖，都属于供应链安全，而不是部署以后才考虑的问题。

## 8. Wrapper 固定 Maven，不会自动固定一切

Maven Wrapper 把 `mvnw`、`mvnw.cmd` 和 `.mvn/wrapper/maven-wrapper.properties` 放入项目，使成员通过 `./mvnw` 选择同一 Maven 分发版本。第一次使用可能下载 Maven 分发，之后使用本地缓存。Wrapper 解决“大家用了不同 Maven”这一层，但不自动固定 JDK、插件、依赖、settings、镜像或操作系统。

Wrapper 属性可配置分发 URL 与 `distributionSha256Sum`。校验和能防止下载内容被替换，是供应链边界的一部分。企业环境还应使用受控仓库管理器、HTTPS、最小凭据与来源审计。不要把仓库用户名、密码或 token 写入 POM、Wrapper 文件或 Git。

离线实验使用 `--offline`，含义是禁止 Maven 从远端补取；所需插件和依赖必须已经在本地仓库。离线成功证明缓存足够支撑本次构建，不证明一台全新机器能成功。离线失败也不等于 POM 必然错误，第一处可信证据可能是“某坐标未缓存”。

Wrapper 自己若尚未缓存分发，在离线状态也可能无法启动。因此本章配套验证器直接检查已安装的 Maven 3.9.16，并始终给实际 Maven 构建加 `--offline`；教材不在验证过程中下载 Wrapper 或依赖。真实项目初始化 Wrapper 时应在受控联网步骤完成，再把版本与校验和提交。

## 9. JDK toolchain、release 与运行 Maven 的 JVM

运行 Maven 的 Java 与编译目标 Java不是同一个开关。`mvn -v` 报告 Maven JVM；Compiler 插件的 `<release>25</release>` 指定 Java 编译目标；Toolchains 插件可以让插件选择满足条件的 JDK。IDE 还有自己的 SDK 和 Runner 配置。

在当前学习项目中，最简单且最清楚的规则是三者统一为 JDK 25：终端/Maven JVM、Compiler release、IDE 项目 SDK。统一不是 Java 的语法要求，而是减少学习阶段的环境变量。生产项目可能用较新 JDK 运行 Maven、用 toolchain 编译较旧目标；此时必须把差异写成显式契约并在 CI 验证。

只设置 `maven.compiler.source` 与 `target` 不等于完整限制到旧平台 API；`release` 同时约束语言级别、字节码目标和对应平台 API，更适合现代 JDK。即便 `release` 相同，不同 JDK 大版本、插件版本或操作系统仍可能产生不同字节，因此复现边界必须包括工具版本。

## 10. 什么叫“可重复构建”

严格定义是：给定相同源代码、构建环境和构建指令，独立构建能生成逐字节相同的指定产物。这里有三个容易被省略的词：**独立**、**逐字节**、**指定产物**。

本机连续两次 `clean package` 得到同一哈希，是有价值的局部证据，但两次共享用户名、路径、操作系统、本地仓库和时区，并不独立。第三方在另一台干净环境重建并比对，证据更强。测试都通过只证明测试断言满足，不证明 JAR 字节相同；JAR 字节相同也不证明业务行为正确。这些证据回答不同问题。

ZIP/JAR 条目时间戳是常见漂移来源。Maven 推荐通过 `project.build.outputTimestamp` 为支持该机制的插件提供固定时间。还要避免版本范围、未固定插件、构建时写入当前时间、随机数、用户名、绝对路径、未排序文件、平台默认编码与换行差异。

```xml
<properties>
  <project.build.outputTimestamp>2026-07-16T00:00:00Z</project.build.outputTimestamp>
  <maven.compiler.release>25</maven.compiler.release>
</properties>
```

这段配置不是魔法。某个插件若不支持可重复输出，固定属性也可能无效；生成代码读取当前时钟，产物仍会漂移。正确做法是比较产物、定位不同字节由哪个插件或资源产生，再升级、配置或替换那一步。

## 11. 冷构建、热构建与离线构建不要混称

“冷构建”在团队里常有不同含义：删除 `target`，清空本地依赖缓存，使用全新容器，或没有任何操作系统页缓存。必须说明清理了什么。本章的“干净构建”仅指执行 `clean` 删除项目输出；“离线构建”指 Maven `--offline`；不声称清空 `~/.m2`，也不声称操作系统级网络隔离。

热构建可能复用 `target` 或增量状态，反馈更快。若热构建通过、`clean test` 失败，优先怀疑生成步骤、遗漏源文件、错误目录或残留 class。若在线成功、离线失败，优先查看缺失的插件/依赖坐标和仓库配置。若终端成功、IDE 失败，先对比 JDK、Maven Runner、工作目录、profile 和参数。

不要为了证明“离线”就删除全局 `.m2`。这会影响其他项目且恢复需要联网。安全实验应使用独立临时本地仓库，或只观察已有缓存并清楚声明限制。

## 12. 可重放的诊断顺序

面对 `BUILD FAILURE`，建议从前向后定位，而不是只复制最后的 Help 链接：

1. 记录命令、工作目录、退出码，不要马上改代码；
2. 查看 `mvn -v`，确认 Maven 与运行 JVM；
3. 找第一个 `[ERROR]` 所属 goal，例如 `compiler:compile`、`compiler:testCompile`、`surefire:test`；
4. 识别失败阶段：模型解析、依赖解析、主代码编译、测试代码编译、测试执行、打包、验证；
5. 提取第一个具体文件、行列、坐标或断言 expected/actual；
6. 用 `dependency:tree`、effective POM 或插件描述补充模型证据；
7. 只改一个变量，重跑同一条失败命令；
8. 最后再运行更大的 `clean verify`，确认没有只修一条路径。

缺分号通常停在 `compiler:compile`，不会出现 Tests run；测试源找不到业务类通常停在 `testCompile`；断言不一致进入 `surefire:test` 并报告 Failures；测试中未捕获异常通常报告 Errors。`BUILD SUCCESS` 也要结合测试数，若 `Tests run: 0`，它只说明没有失败测试，不证明预期测试被发现。

## 13. 三类典型故障

### 13.1 scope 泄漏

现象：`src/main/java` 导入 JUnit API 仍能编译。检查 POM 后发现 JUnit 没有 `test` scope。修复不是在业务代码继续使用断言，而是恢复边界、把测试逻辑移到测试源集，重新运行 `dependency:tree -Dscope=compile` 与测试。

### 13.2 插件漂移

现象：同一源码在另一台机器产生不同 JAR，日志显示 JAR 插件或 Compiler 插件版本不同。先比较 effective POM 与日志中的插件坐标，再在项目或受控父 POM 锁版本；同时固定输出时间戳并重建比较。只把 JAR 改名并不能解决字节差异。

### 13.3 JDK 不一致

现象：`java -version` 是 25，`mvn -v` 却显示 21，或 IDE 运行时仍使用另一 JDK。原因可能是 Maven 启动脚本优先读取 `JAVA_HOME`，而 shell 查找 `java` 仍由 `PATH` 决定。临时设置 `JAVA_HOME` 不会自动改写当前 shell 的 `PATH`。分别检查 `type -a java mvn`、`echo "$JAVA_HOME"`、`java -version`、`mvn -v` 和 IDE Runner。

## 14. FactoryCare：把构建当作可审计生产过程

FactoryCare 的 `work-order-core` 不需要 Spring 也能建立工程合同：主代码只负责工单费用计算；测试验证零数量、正常数量和非法数量；JUnit 是 test scope；Compiler 目标为 JDK 25；Surefire 与 JAR 插件锁版本；输出时间戳固定；普通 JAR 不含测试 class；验证器离线执行两次干净 package 并比较哈希。

这套合同保护的不只是“能不能构建”。它让代码评审者知道业务依赖和测试依赖边界，让故障处理者知道在哪个 phase 失败，让安全审查者知道哪些构建代码会执行，让后来者能重放同一结果。

当未来加入 Spring、数据库驱动、JSON 库和测试容器后，依赖图会增大，但本章方法不变：直接依赖显式声明，版本来源可追踪，scope 与运行边界一致，插件固定，构建证据可重放。不要等依赖上百个才第一次查看树。

## 15. 安全与供应链边界

依赖下载意味着信任远端仓库、DNS/TLS、仓库管理器、构件发布者和本地缓存。最低实践包括：只使用必要仓库；优先通过组织仓库管理器代理；锁定正式版本，避免动态范围和 snapshot 进入发布基线；不把凭据写入项目；审查 Wrapper 分发地址与 SHA-256；定期扫描依赖和插件；保留构建日志与物料证据。

`pom.xml` 来自不可信项目时，不要直接运行任意 goal。插件能在构建机上执行代码、读文件、发网络请求。先阅读 POM、父 POM、`.mvn` 扩展与 Wrapper 脚本，再在隔离环境运行。`--offline` 可以阻止 Maven 正常依赖解析联网，但不是操作系统网络沙箱，也不能证明插件内部绝不自行联网。

日志与 effective settings 可能暴露用户名、路径、镜像地址或凭据占位。提交证据前脱敏，但不要删除影响诊断的插件版本、坐标、phase、测试数和退出码。

## 16. 预测—构建—破坏—修复

在运行配套验证器前先写预测：`test` scope 是否出现在 compile 树；删除固定输出时间戳后两次 JAR 哈希是否一定不同；把业务源码改为导入 JUnit 后失败在哪个阶段；切换 Maven JVM 到 21、保留 release 25 时会出现什么；空本地仓库配合 `--offline` 会在何处失败。

然后按最小变量实验。一次只改 scope、插件版本或 JDK，不同时改三处。保存失败命令、退出码和第一处可信证据，修复后先重跑同一命令，再跑完整验证器。这比“AI 一次重写 POM，看到绿色就结束”更能形成工程能力。

AI 可以解释 effective POM、比较依赖树或提出故障假设，但你必须核对它是否偷偷去掉了 `--offline`、升级了版本、添加了仓库、跳过了测试或删除了失败用例。任何“验证通过”都要能指向真实命令和输出。

## 17. 无 AI 训练

关闭 AI，限时 45 分钟：

1. 画出 `./mvnw --offline clean verify` 从 shell 到 JDK、Maven 模型、依赖仓库、Compiler、Surefire、JUnit 与 JAR 的执行图；
2. 给定一段 Maven 日志，标出 phase、plugin goal、主编译、测试编译和测试运行的边界；
3. 把 JUnit scope 错误改为 compile，预测业务代码和依赖树变化，再恢复为 test；
4. 制造一个断言失败，说明它为什么是 Failure 而不是 compile error；
5. 连续构建两次并比较哈希，写出该证据能证明与不能证明的内容；
6. 不看笔记，用 120 秒复述坐标、图、scope、生命周期、插件、Wrapper、toolchain、可重复构建。

评分不看背出多少 XML 标签，而看你是否能从日志定位模型边界、改一个要求并重放证据。

## 18. 复习与速查

### 一句话规则

- POM 描述项目模型，生命周期组织阶段，插件执行具体目标。
- 坐标定位构件，依赖声明形成图，scope 决定类路径边界。
- `dependencyManagement` 管版本，不自动添加依赖。
- `pluginManagement` 管插件默认值，不自动等于执行。
- 调用后置 phase 会执行同生命周期中之前的 phase。
- JUnit 属于 test scope；Surefire 是运行测试的 Maven 插件。
- Wrapper 固定 Maven 版本，不自动固定 JDK 与所有输入。
- `release` 约束编译目标，`mvn -v` 才报告 Maven JVM。
- 本机两次相同是局部证据，不等于第三方独立可复现。
- `--offline` 是 Maven 解析模式，不是操作系统网络沙箱。
- `BUILD SUCCESS` 必须结合测试数、产物和所执行的 goal 解读。

### 故障速查

| 现象 | 第一检查点 | 常见原因 |
| --- | --- | --- |
| 没有 Tests run | `surefire:test` 是否执行、命名是否匹配 | 测试未被发现、引擎缺失 |
| 主代码找不到测试库 | dependency scope | JUnit 正确地是 test scope，业务边界写错 |
| 离线失败 | 第一个缺失坐标 | 插件或依赖未缓存 |
| IDE 与终端不同 | IDE Runner JDK、profile、工作目录 | 两套模型输入不同 |
| 两次 JAR 哈希不同 | ZIP 条目时间、插件版本、生成资源 | 不稳定输入进入产物 |
| `NoSuchMethodError` | runtime 依赖树 | 版本调解或错误排除 |
| 老 class 干扰 | `clean` 后重跑 | target 残留或增量状态 |

## 19. 术语表

- **POM**：Maven 项目对象模型及其 XML 表示。
- **坐标**：通常由 groupId、artifactId、version 定位构件。
- **构件**：JAR、POM 等可被仓库保存和解析的产物。
- **本地仓库**：Maven 在本机缓存和安装构件的位置，不是源码工作区。
- **传递依赖**：由直接依赖继续引入的依赖。
- **依赖调解**：同一构件出现多个版本时选择最终版本的过程。
- **scope**：依赖在哪些编译、运行和测试类路径可见的规则。
- **生命周期**：有序的构建阶段集合。
- **phase**：生命周期中的位置，如 test、package、verify。
- **plugin goal**：插件提供的具体操作，如 `surefire:test`。
- **effective POM**：继承、profile 与默认值合并后的实际模型。
- **Wrapper**：随项目提交、用于选择固定 Maven 分发的启动文件。
- **toolchain**：为构建插件选择满足约束的 JDK 等工具。
- **可重复构建**：相同受控输入能独立得到逐字节相同指定产物。
- **哈希**：对文件字节计算的固定摘要；相同哈希是字节一致证据。

## 20. 官方资料与版本说明

以下资料均于 **2026-07-16** 复核：

- [Apache Maven 3.9.16 发布说明](https://maven.apache.org/docs/3.9.16/release-notes.html)
- [Maven 构建生命周期](https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html)
- [Maven 依赖机制与 scope](https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html)
- [Maven 可重复构建指南](https://maven.apache.org/guides/mini/guide-reproducible-builds.html)
- [Maven Wrapper](https://maven.apache.org/tools/wrapper/index.html)
- [Help Plugin：effective-pom](https://maven.apache.org/plugins/maven-help-plugin/effective-pom-mojo.html)
- [JUnit 6.1.1 Maven 构建支持](https://docs.junit.org/6.1.1/running-tests/build-support)
- [JDK 25 文档](https://docs.oracle.com/en/java/javase/25/)

稳定核心是项目模型、依赖图、scope、生命周期与可重复性定义；具体插件补丁版本属于可变表面。升级时先读发布说明，在隔离分支重跑依赖树、测试和双构建哈希，不因“最新版”三个字直接替换。

## 21. 完成检查

你应能独立回答：为什么 Maven 不是编译器；为什么 JUnit 通过 test scope 仍能测试主代码；为什么 `mvn package` 会运行测试；为什么 `dependencyManagement` 中出现坐标不代表已加入依赖；为什么 Wrapper 与 `release` 不能互相替代；为什么两次 `BUILD SUCCESS` 不足以证明可重复构建；为什么离线成功也不代表一台全新机器能构建。

最后完成一次变更：把 FactoryCare 费用规则增加“非法负数量抛异常”，先预测哪个测试失败，再修改业务代码或测试合同，运行 `--offline clean test`，比较两次 package 哈希，并用自己的话解释每条证据回答了什么问题。只有能解释、修改、制造失败并恢复，才算从“会运行命令”走向“能维护构建”。
