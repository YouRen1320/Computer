---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.boot-autoconfiguration
title: Spring Boot、Starter、自动配置与应用启动
responsibility: 教授 Boot 如何根据类路径和条件装配应用，不把自动配置当作不可检查的魔法
volume: '05'
order: 5
level: L2
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.boot-autoconfiguration.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.spring.configuration-profiles
- ch.java-engineering.maven-reproducible-builds
version_surfaces:
- spring-boot-4.1
- spring-framework-7
- jdk-25
- maven-3
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释Spring Boot、Starter、自动配置与应用启动的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - spring-boot-startup
  - spring-autoconfiguration
  covers_topics:
  - spring.boot-application
  - spring.starter-dependency
  - spring.application-startup
  - spring.auto-configuration-condition
  - spring.condition-report
  - spring.override-boundary
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.build-testing
  - foundation.toolchain-env-build
  - backend.spring-di-config
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 用构造器DI组装Bean图，通过Profile/环境配置选择实现，再创建Boot条件Bean并用condition report解释Starter与自动配置
  covers_topic_groups:
  - spring-boot-startup
  - spring-autoconfiguration
  covers_topics:
  - spring.boot-application
  - spring.starter-dependency
  - spring.application-startup
  - spring.auto-configuration-condition
  - spring.condition-report
  - spring.override-boundary
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.build-testing
  - foundation.toolchain-env-build
  - backend.spring-di-config
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入循环DI、Profile选错、Starter缺失、条件不匹配和用户Bean冲突，沿Bean/配置/自动配置报告逐项恢复
  covers_topic_groups:
  - spring-boot-startup
  - spring-autoconfiguration
  covers_topics:
  - spring.boot-application
  - spring.starter-dependency
  - spring.application-startup
  - spring.auto-configuration-condition
  - spring.condition-report
  - spring.override-boundary
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.build-testing
  - foundation.toolchain-env-build
  - backend.spring-di-config
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# Spring Boot、Starter、自动配置与应用启动

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《配置属性、Profile、环境覆盖与敏感配置》](ch.spring.configuration-profiles.md)：独立完成Boot 启动与 Starter、自动配置前，必须先具备「配置属性、Profile、环境覆盖与敏感配置」已经验证的知识与失败边界
- [《Maven 生命周期、依赖范围、插件与可重复构建》](../../volume-03-java-engineering/chapters/ch.java-engineering.maven-reproducible-builds.md)：独立完成Boot 启动与 Starter、自动配置前，必须先具备「Maven 生命周期、依赖范围、插件与可重复构建」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 drafting。正文与工件是教材证据，不会自动更新 `PROGRESS.md`，也不表示学习者已经完成 Week 09/10。

Spring Framework 提供容器、依赖注入和 Web 等能力；Spring Boot 在其上统一依赖组合、应用启动、外部配置、条件装配和运维惯例。Boot 的价值不是“省掉理解”，而是把常见装配规则编码为可检查、可替换、可测试的配置。

本章工件固定 Spring Boot 4.1.0、其 BOM 管理的 Spring Framework 7.0.8、JDK 25 与 Maven 3.9.16。官方资料复核日期为 2026-07-17；概念可迁移，具体条件与依赖组合必须随 Boot patch 重新验证。

## 1. 本章完成证据

完成者应能从一个依赖声明追到实际 jar，从 `SpringApplication.run` 追到可用 `ApplicationContext`，并用条件评估报告说明某个 Bean 为什么存在或缺失。还要能预测 Profile、配置键、类路径与用户自定义 Bean 的组合结果。

配套工件：

- [Boot 条件装配观察台](../../../examples/encyclopedia/ch.spring.boot-autoconfiguration/README.md)
- [Starter、Profile、条件与覆盖实验](../../../labs/encyclopedia/ch.spring.boot-autoconfiguration/README.md)
- [自动配置 back-off 练习](../../../exercises/encyclopedia/ch.spring.boot-autoconfiguration/README.md)

## 2. Boot 解决什么问题

纯 Spring 可以手工声明每个基础设施 Bean，但多个应用会重复选择版本、导入配置、读取属性、判断可选库、编写启动入口。重复代码容易产生不同默认值和不兼容依赖。

Boot 把常见组合变为“约定加条件”：当类路径、配置、应用类型和用户 Bean 满足条件时，注册合理默认；条件不满足就不注册。它缩短装配工作，但业务边界、数据模型和安全规则仍由应用负责。

## 3. Boot 与 Framework 的边界

Framework 是核心机制：`BeanFactory`、`ApplicationContext`、`@Configuration`、依赖注入和生命周期。Boot 使用这些机制，增加 `SpringApplication`、Starter、自动配置、条件注解、FailureAnalyzer 等应用层体验。

因此“Boot 创建了另一种容器”是错误模型。运行中的 Bean 仍由 Spring 容器管理；Boot 只是决定哪些配置候选应加入，并为常见部署方式准备环境。

## 4. Starter 是依赖入口

Starter 通常是一个很薄的 Maven 依赖入口，聚合某项能力的典型依赖。例如 Web starter 会带入 MVC、Servlet 容器及相关基础组件；它不是一个替代全部依赖知识的黑盒。

看到 starter 时要运行依赖树，回答三件事：它直接声明什么、传递带入什么、BOM 最终解析了哪个版本。缺少 starter 往往首先表现为类不存在或自动配置条件未命中。

## 5. Starter 不等于自动配置代码

“依赖集合”和“装配逻辑”是不同角色。Starter 主要表达一组推荐依赖，自动配置类则在运行时评估条件并定义 Bean。两者常一起发布，却不能混为一谈。

一个库也可以只提供 autoconfigure 模块，由应用自行选择底层依赖；或者提供独立 starter，把常用组合汇总。诊断时先判断问题属于 Maven 类路径还是容器条件。

## 6. BOM 与版本组合

Boot parent 或 dependency management 为受管依赖提供兼容版本。本章接受 Boot 4.1.0 管理的 Framework 7.0.8，不单独覆盖 Framework patch，避免创造未测试组合。

BOM 不会自动添加依赖，只在项目确实声明该坐标时提供版本。Starter 负责“需要哪些依赖”，BOM 负责“这些依赖采用什么版本”；插件版本与 JDK 编译目标还要分别确认。

## 7. SpringApplication 启动入口

典型入口把主配置类交给 `SpringApplication.run`：

```java
@SpringBootApplication
public class FactoryCareApplication {
    public static void main(String[] args) {
        SpringApplication.run(FactoryCareApplication.class, args);
    }
}
```

`run` 不只是调用构造器。它准备 Environment、选择应用类型、创建合适的 context、加载 Bean 定义、刷新容器，并在成功后返回可关闭的 `ConfigurableApplicationContext`。

## 8. SpringBootApplication 的三层含义

`@SpringBootApplication` 组合了 Boot 配置类、自动配置启用和组件扫描。初学者应把三件事分开思考：应用显式配置在哪里、哪些自动配置候选被评估、哪些用户组件被扫描。

组合注解便于入口书写，不代表整个工程只能有一个配置类。官方建议主配置只放一个 `@SpringBootApplication` 或 `@EnableAutoConfiguration`，其余配置通过包扫描或明确导入组织。

## 9. 主类包位置是扫描边界

组件扫描默认从主类所在包向下。若主类放在过深子包，同级的 service 可能根本没有成为 Bean；若放在默认包，扫描范围可能过大且难以预测。

FactoryCare 可把主类放在 `academy.factorycare` 根包，业务模块位于其子包。外部库的自动配置不依赖此扫描，它通过专用 imports 元数据发现。

## 10. 启动不是一个瞬间

可用心智模型是：读取启动参数与环境，推断非 Web/Servlet/Reactive 应用类型，创建 context，加载用户配置和自动配置候选，评估条件，注册 Bean 定义，实例化非延迟 singleton，执行生命周期回调，最后通知 runner 与监听器。

这不是承诺所有内部事件的绝对实现顺序，而是诊断层次。错误发生在“依赖解析”与“Bean 初始化”时，证据和修复方向不同。

## 11. main 参数与外部配置

命令行参数会进入 Boot Environment，并可能覆盖较低优先级来源。`--factorycare.audit.enabled=true` 不是随便传给某个 Bean 的字符串，而是形成属性源，再由条件或绑定器读取。

不要把未经允许的任意启动参数直接变成业务行为。配置键需要类型、默认、校验、所有者和审计；上一章的配置边界在这里继续生效。

## 12. 启动失败应尽早暴露

构造器依赖缺失、重复 Bean、循环依赖、配置绑定失败或端口占用都可能阻止 context 刷新。失败不是“应用部分可用”，而是启动契约未成立。

Boot 的 `FailureAnalyzer` 会为部分常见异常生成 Description 与 Action。先读最具体的分析，再沿 cause chain 找第一处可信证据；不要只复制最后一屏堆栈。

## 13. eager 与 lazy 的取舍

默认急切创建 singleton 能在部署阶段发现装配错误。全局延迟初始化可能缩短启动时间，却把错误推迟到第一次请求，并使容量评估更困难。

因此 lazy 不是修复慢启动的第一反应。先测量耗时 Bean、外部连接和类路径，再针对问题优化；关键依赖仍应在就绪前验证。

## 14. 什么是自动配置

自动配置是普通配置类加上一组条件。Boot 根据已有类、Bean、属性、资源和应用类型判断是否导入配置、注册 Bean。它不会推断业务意图，也不会读取你的心思。

核心不变量是“默认有前提”。条件真时提供默认，条件假时留下证据；用户声明替代实现时，设计良好的默认应 back off。

## 15. 候选如何被发现

Boot 4.1 的自定义自动配置类使用 `@AutoConfiguration`，并在 jar 的 `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` 中逐行列出类名。

这与应用的组件扫描分开。自动配置类不应依靠被扫描到，也不应通过广泛组件扫描搜集内部 Bean；应使用明确的 `@Bean` 或 `@Import`，让候选集合可审计。

## 16. 条件是布尔证据

每个条件回答一个有限问题，例如“类是否存在”“配置是否启用”“用户是否已经提供该类型”。多个条件通常是与关系，任何必要条件失败都应使对应配置退出。

条件不是隐藏业务规则的地方。工单是否允许关闭属于领域策略，而不是 `@ConditionalOnProperty`；否则同一部署内无法按工单状态正确变化。

## 17. ConditionalOnClass

`@ConditionalOnClass` 让自动配置只在目标库位于类路径时生效。Boot 通过注解元数据检查类级条件，可避免直接加载缺失类型。

若缺失类出现在 `@Bean` 方法签名，JVM 可能在方法条件评估前就加载类型。官方建议把这类条件隔离到单独配置类，避免“条件看似能保护，实际先 NoClassDefFoundError”。

## 18. 类路径是构建结果

条件报告说某个类不存在时，不要立刻改注解。先用 Maven dependency tree 确认依赖是否声明、scope 是否正确、是否被 exclusion 移除、最终 jar 是否真的包含它。

IDE 能 import 一个类也不保证生产 runtime classpath 有它。`test` scope 依赖可能让测试绿、打包后却缺失；离线工件显式检查依赖组合。

## 19. ConditionalOnMissingBean

`@ConditionalOnMissingBean` 是 back-off 的常见实现：当容器里尚无目标类型，自动配置注册默认；用户先声明同类型 Bean，默认退出。

它不是“任意同名 Bean 都覆盖”。条件可按类型、名称或注解判断，自动配置作者应选择稳定契约；应用作者则应确认自己的 Bean 真正匹配该条件。

## 20. 用户覆盖边界

好的覆盖有明确原因，例如生产环境需要 `DatabaseAuditSink`，默认只提供 `ConsoleAuditSink`。应用通过一个类型契约声明替代，自动配置退出，最终仍只有一个可注入候选。

不要开启全局 Bean definition overriding 来压住同名冲突。那会让注册顺序决定赢家，掩盖架构错误；优先使用类型化 back-off、`@Primary` 的有限选择或明确排除。

## 21. Bean 方法返回类型影响条件

条件评估只能利用已注册定义暴露的类型信息。若 `@Bean` 返回过宽接口，某些针对具体类型的条件可能无法在正确时点判断。

官方建议自动配置的 Bean 方法尽量返回具体类型。对外消费仍可依赖接口，但配置元数据需要足够具体，才能稳定 back off。

## 22. ConditionalOnProperty

属性条件按 Environment 键判断是否启用配置。默认语义通常是键存在且值不为 `false`；精确行为由 `havingValue` 与 `matchIfMissing` 决定。

不要只凭键名猜默认。`matchIfMissing=true` 意味着缺键也启用，适合安全默认明确的功能；审计、鉴权等关键能力若默认选择错误，风险会被放大。

## 23. ConditionalOnBooleanProperty

Boot 提供专门的布尔属性条件，使“真才启用”的意图更明确。它仍然依赖属性来源与绑定规则，不等于业务服务每次调用时动态读取开关。

配置通常在 context 构建时决定 Bean 图。若运行期间要动态切换，需要独立的配置刷新和一致性设计，不能假定修改环境变量会自动重建 Bean。

## 24. 默认值必须可解释

条件的默认与配置对象的默认要一致。若属性文档说默认关闭，而条件 `matchIfMissing=true`，应用行为与运维认知会分裂。

工件让缺键、true、false 三种输入各有断言，并把最终 Bean 数量作为 oracle。这样升级 Boot 或改注解时，默认漂移会立即出现。

## 25. Profile 与属性条件不是同一工具

Profile 适合选择一组部署环境配置，例如 local 模拟器与生产客户端。属性条件适合一个明确可配置能力，例如是否创建审计 sink。两者都在启动时塑造 Bean 图，但表达的维度不同。

不要制造 `dev-and-eu-and-premium` 这类组合爆炸。环境差异用 Profile，独立技术能力用类型化属性，业务套餐与权限用领域数据和策略。

## 26. 其他常用条件

Boot 还提供 Bean、缺失类、资源、Servlet/Reactive Web 应用和部署方式等条件。它们用于保护基础设施装配，例如只有 Servlet Web 应用才创建 MVC 组件。

条件越多，组合越多。每增加一个条件都要有至少真/假证据，并说明谁负责满足它；否则“偶尔不生效”会变成长期故障。

## 27. 谨慎使用表达式条件

复杂 SpEL 条件难以搜索、类型检查和复用。表达式若引用 Bean，还可能使 Bean 过早初始化，错过配置属性绑定等后处理。

优先使用专用条件注解和小型自定义 Condition。条件只判断装配事实，不执行网络请求、不修改外部状态，也不承担业务计算。

## 28. 自动配置顺序不等于 Bean 创建顺序

`before`、`after` 与自动配置顺序决定 Bean 定义被处理的先后，主要影响条件看到什么。Bean 真正实例化的先后仍由依赖关系和生命周期规则决定。

用顺序注解修复构造器循环依赖无效。若 A 需要 B、B 又需要 A，应重画职责和依赖方向，而不是调整自动配置排序。

## 29. 最小自定义自动配置

FactoryCare 审计默认配置可以写成：

```java
@AutoConfiguration
@ConditionalOnBooleanProperty(prefix = "factorycare.audit", name = "enabled")
public class AuditAutoConfiguration {
    @Bean
    @ConditionalOnMissingBean
    ConsoleAuditSink auditSink() {
        return new ConsoleAuditSink();
    }
}
```

这只表达“属性为真且用户没有实现时给默认”。真正工件还通过 imports 文件登记，并测试缺键、false、true 和用户覆盖。

## 30. 自动配置与配置属性

可配置 starter 应使用自己拥有的命名空间，例如 `factorycare.audit`，并绑定成类型安全对象。不要占用 `spring`、`server`、`management` 等 Boot 命名空间。

条件只决定是否注册，配置对象负责地址、超时等参数的类型和校验。把所有参数塞进条件注解会丢失文档、复用与验证能力。

## 31. imports 文件是发布合同

类写对但没有登记 imports，应用永远不会把它当自动配置候选；登记错误类名则会在启动阶段失败。这个资源必须进入最终 jar，而不只是留在源码目录。

测试可以只导入配置类验证 Bean，却漏掉发布元数据。实验额外读取 imports 资源，确保真实发现路径存在。

## 32. 自定义 Starter 的模块边界

规模较大时可把 API/autoconfigure 与 starter 分开：前者含装配逻辑和可选底层依赖，后者聚合常用依赖。简单场景可合并，但角色仍要在文档中分清。

第三方 starter 名称应使用自己的命名空间，不要伪装成官方 `spring-boot-*`。发布者还要维护兼容矩阵、配置元数据和升级测试。

## 33. 可选依赖与 back-off

autoconfigure 模块若把所有底层库强制带入，`ConditionalOnClass` 将永远为真，应用无法通过依赖选择关闭能力。官方建议底层库在合适场景设为 optional，由 starter 表达典型组合。

optional 不是“运行时随便缺”。自动配置必须在库缺失时安全退出，应用若显式使用该 API 则应在编译或启动时清楚失败。

## 34. 配置元数据与 IDE

高质量 starter 应生成配置元数据，让 IDE 展示键名、类型和说明。元数据不是运行时校验的替代；它帮助作者在编码阶段发现拼写与文档问题。

记录类属性时应说明单位和边界，例如 `Duration` 而非裸 `long`。默认值只定义一次，并由测试验证文档、绑定与条件一致。

## 35. 自动配置不要组件扫描

自动配置若扫描宽泛包，会把库内部类和应用类意外注册，难以解释 Bean 来源。官方建议自动配置自身位于专用包，并通过具体 `@Import` 或 `@Bean` 选择组件。

应用组件扫描服务于用户代码，imports 服务于库候选。保持两条发现路径分离，能减少“换了主类包名后 starter 失效”一类故障。

## 36. ConditionEvaluationReport

条件评估报告记录哪些自动配置候选匹配、哪些未匹配及原因。它是对当次 context 的事实快照，不是静态文档。

报告可从 context 的 BeanFactory 获取，也可在调试日志中输出。实验直接读取报告并断言目标配置的 positive/negative match，避免人工翻阅易变日志文本。

## 37. debug 的正确用途

运行应用时启用 `--debug`，Boot 会为一组核心 logger 输出条件报告。它适合回答“为什么没有这个 Bean”，不等于打开所有包的最高日志级别。

调试输出可能很长。先搜索目标自动配置类，再读未匹配条件；不要从海量正向匹配中猜测，也不要把含环境值的完整日志直接上传。

## 38. 如何读条件报告

先确认候选是否出现；未出现通常是 imports 或依赖问题。出现后区分 positive、negative、unconditional 与 exclusions，再读取具体条件消息。

“did not find required class”指向类路径；“did not find property”指向配置来源；“found beans of type”可能说明默认已 back off。证据类型决定下一条命令。

## 39. ApplicationContextRunner

Boot 的 `ApplicationContextRunner` 可为每个测试构建小 context，注入属性、用户配置和自动配置，并在回调中断言 Bean 数量与失败。

它比启动完整服务器更快、更聚焦，也能在 context 启动失败时检查 failure。它证明装配切片，不证明真实端口、Servlet 链或生产依赖全部正确。

## 40. 模拟类路径缺失

自动配置测试可使用过滤 ClassLoader 隐藏目标类，验证 `@ConditionalOnClass` 真正 back off。只删除 Maven 依赖再观察编译失败，不是同一种运行时条件测试。

测试类自身不要直接引用要隐藏的类型，否则测试加载会先失败。把类条件隔离在自动配置中，恰好也是生产设计要求。

## 41. 测试用户自定义覆盖

先运行只有自动配置的 context，断言一个默认 Bean；再加入用户配置，断言默认具体类为零、用户实现为一、接口候选总数仍为一。

仅断言“用户 Bean 存在”不够，因为默认可能同时存在并在注入时产生歧义。Bean 数量和身份必须一起成为 oracle。

## 42. 测试 Profile 选择

Profile 实验分别启动默认与 `dev` context，断言适配器实现唯一且可预测。不要在同一 context 内修改 active profiles 后期待现有 Bean 自动替换。

若两个 Profile 表达式都匹配并产生同类型 Bean，构造器注入可能失败。修复应让条件互斥或明确选择，而不是依赖扫描顺序。

## 43. 测试条件真、假和缺省

布尔配置至少覆盖缺键、false、true。若设计为缺省关闭，前两者不应创建 Bean，true 恰好创建一个；若设计为默认开启，测试应显式说明不同 oracle。

这三个用例比一个快乐路径更能防止升级漂移。条件注解参数改变时，失败会直接指出默认语义被改动。

## 44. 依赖与生命周期仍受容器管理

自动配置产生的 Bean 与用户 Bean 遵守同一依赖填充和销毁规则。基础设施若持有线程池、连接或文件，应让容器拥有并在 context 关闭时释放。

不要在 Condition 中手工 new 资源并遗失引用；Condition 只判断，`@Bean` 创建受管对象，销毁通过 `AutoCloseable`、destroyMethod 或生命周期回调验证。

## 45. 故障：循环依赖

若 `AuditClient` 构造器需要 `AuditFormatter`，formatter 又需要 client，Boot 启动会失败。打开允许循环引用只是隐藏职责问题，还可能得到半初始化对象。

诊断时画出构造器边，找出可成为纯策略或事件边界的一侧。自动配置不能用加载顺序消除真实对象图环。

## 46. 故障：Starter 或类缺失

症状可能是编译时 package 不存在，也可能是自动配置 negative match。前者先看依赖声明，后者确认 runtime classpath 和 `@ConditionalOnClass` 消息。

不要随意复制多个 starter 直到应用能启动。每个新增 starter 都会扩大类路径和候选集合，应说明它提供的能力与移除验证。

## 47. 故障：Profile 选错

先读取实际 active profiles 与属性来源，确认命令行、环境和配置文件优先级。不要只看 IDE 运行配置截图，因为部署命令可能覆盖它。

Profile 造成的 Bean 缺失应在小 context 中复现。修复后分别重跑默认和目标 Profile，防止只修一侧。

## 48. 故障：条件不匹配

按候选发现、类路径、属性、Bean、应用类型顺序排查。每步只改变一个输入，并比较条件报告；一次同时改依赖和配置会失去因果证据。

若消息说键存在但值不匹配，检查字符串规范、`havingValue` 和高优先级覆盖。不要把实际值写进日志时泄露秘密。

## 49. 故障：用户 Bean 冲突

两个实现同时存在时，先问自动配置是否应 back off、用户是否意外扫描了重复配置、接口是否需要真正多实现集合。`@Primary` 只解决单值注入选择，不删除错误 Bean。

全局允许名称覆盖回滚困难，也让升级后的注册顺序改变行为。本章默认不启用，以显式失败保护装配合同。

## 50. FactoryCare 审计案例

FactoryCare 希望开发环境可选控制台审计，生产由应用提供持久化审计实现。starter 定义 `AuditSink` 契约和安全的无外部资源默认，应用通过 `factorycare.audit.enabled` 启用。

自动配置只管技术适配器是否存在，不决定“哪些工单动作必须审计”；后者是业务与安全规则，必须在用例层明确执行。

## 51. 可重放 oracle

实验固定断言：imports 能找到候选；缺键与 false 无审计 Bean；true 有且仅有默认 Bean；用户 Bean 存在时默认退出；`dev` 与默认 Profile 各只有一个适配器；context 关闭触发资源销毁。

失败消息使用稳定哨兵，而不匹配本地化日志全文。每次 verifier 从 clean 开始、离线执行并输出测试数与版本。

## 52. 独立构建任务

从空目录创建一个小型 autoconfigure 工程：定义接口与默认实现，写 `@AutoConfiguration`、类/属性/缺 Bean 条件和 imports 文件，再用 runner 覆盖条件真、假、用户覆盖。

提交前口述：starter 与 autoconfigure 各负责什么，为什么用户 Bean 能 back off，以及报告中哪条证据证明条件结果。

## 53. 修改任务

把“缺键关闭”改为“缺键开启”，但必须同步更新属性说明、条件参数和三组测试。然后增加 `dev` Profile 的内存实现，保持生产实现选择不变。

禁止通过删除失败断言完成修改。先预测哪几个测试应红，再实现、重跑并记录行为变化和回滚方式。

## 54. 诊断顺序

固定顺序是：复现启动方式与版本；检查 Maven 依赖树；确认 imports 候选；读取 active profiles 和关键非秘密属性；在条件报告定位目标类；检查用户 Bean 类型与数量；最后读 cause chain 和生命周期失败。

此顺序从外部事实进入内部对象图，能避免在错误层反复改代码。修复后重跑原失败组合和相邻反例。

## 55. 120 秒复述提纲

先说 Boot 在 Framework 上提供启动和约定；再区分 starter、BOM 与自动配置；接着说明候选通过 imports 发现，条件按类路径、属性和 Bean 决定，用户实现使默认 back off；最后举一个报告定位缺失类或错误 Profile 的反例。

能背注解名但说不出条件输入、Bean 数量和失败证据，不算掌握。

## 56. 有意不做与兼容边界

本章不实现生产 starter 发布、多模块仓库、AOT/native image、完整 Web 服务、数据库或 Actuator。也不为旧式自动配置登记机制保留双轨兼容；教学目标采用 Boot 4.1 当前 imports 模型。

若真实项目从旧 Boot 迁移，应另做依赖矩阵、弃用检查和回滚计划，不能把本章小工件当迁移证明。

## 57. 一手资料

- [Spring Boot 4.1：Auto-configuration](https://docs.spring.io/spring-boot/reference/using/auto-configuration.html)
- [Spring Boot 4.1：Creating Your Own Auto-configuration](https://docs.spring.io/spring-boot/reference/features/developing-auto-configuration.html)
- [Spring Boot 4.1：SpringApplication](https://docs.spring.io/spring-boot/reference/features/spring-application.html)
- [Spring Boot 4.1 API：AutoConfiguration](https://docs.spring.io/spring-boot/4.1/api/java/org/springframework/boot/autoconfigure/AutoConfiguration.html)
- [Spring Boot 4.1 System Requirements](https://docs.spring.io/spring-boot/system-requirements.html)
- [Spring Boot 4.1 Managed Dependency Coordinates](https://docs.spring.io/spring-boot/appendix/dependency-versions/coordinates.html)
