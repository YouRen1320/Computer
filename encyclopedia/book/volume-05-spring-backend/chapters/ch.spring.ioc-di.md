---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.ioc-di
title: IoC、构造器注入与依赖反转
responsibility: 教授由容器装配依赖与由接口反转方向，不在本章展开 Bean 作用域、自动配置或 AOP
volume: '05'
order: 2
level: L2
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.ioc-di.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-oop.interfaces-polymorphism
- ch.java.maven-junit-smoke
version_surfaces:
- spring-framework-7
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
  text: 在 120 秒内解释IoC、构造器注入与依赖反转的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - spring-ioc
  - spring-constructor-di
  covers_topics:
  - spring.ioc-container
  - spring.dependency-inversion
  - spring.object-graph
  - spring.constructor-injection
  - spring.dependency-explicitness
  - spring.circular-dependency
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.encapsulation-immutability
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 用 Spring 容器通过构造器组装 WorkOrderService 与两个端口实现，在测试配置中替换通知实现
  covers_topic_groups:
  - spring-ioc
  - spring-constructor-di
  covers_topics:
  - spring.ioc-container
  - spring.dependency-inversion
  - spring.object-graph
  - spring.constructor-injection
  - spring.dependency-explicitness
  - spring.circular-dependency
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.encapsulation-immutability
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入字段注入隐藏依赖、两个同类型 Bean 歧义和循环依赖，读取启动失败图后重构依赖方向
  covers_topic_groups:
  - spring-ioc
  - spring-constructor-di
  covers_topics:
  - spring.ioc-container
  - spring.dependency-inversion
  - spring.object-graph
  - spring.constructor-injection
  - spring.dependency-explicitness
  - spring.circular-dependency
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.encapsulation-immutability
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# IoC、构造器注入与依赖反转

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《接口、抽象类、多态与动态分派》](../../volume-02-java-objects/chapters/ch.java-oop.interfaces-polymorphism.md)：独立完成控制反转、构造器注入前，必须先具备「接口、抽象类、多态与动态分派」已经验证的知识与失败边界
- [《Maven 最小项目、JUnit、断言与失败日志》](../../volume-01-java-language/chapters/ch.java.maven-junit-smoke.md)：独立完成控制反转、构造器注入前，必须先具备「Maven 最小项目、JUnit、断言与失败日志」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文和工件是作者级学习材料，不自动更新 `PROGRESS.md`，也不代表学习者已经掌握 Spring 或通过阶段门。

一个应用服务往往依赖仓储、通知、时钟和外部客户端。最直接的写法是在服务内部 `new` 具体实现，但这让高层业务决定低层技术、隐藏替换点，并使测试不得不启动真实基础设施。依赖注入让对象声明“我需要什么”，组合根或容器负责“给它哪一个实现”；控制反转描述对象创建与装配控制权从业务对象移到外部。

本章先手工装配，再用 Spring Framework 7 的 `AnnotationConfigApplicationContext`、`@Configuration` 和 `@Bean` 重建同一对象图。正确实现只用构造器注入和普通 Java 接口；故障资产稳定展示字段注入隐藏依赖、缺 Bean、同类型歧义和构造器循环。Spring Boot、Bean scope 细节、自动配置、AOP 与组件生命周期留给后续章节。工件固定 Spring Framework **7.0.7** 以使用本机已缓存、可 `mvn -o` 复验的 7.x 基线；概念按 2026-07-17 的当前 Spring 7 官方文档复核。

## 1. 本章完成证据

你需要在 120 秒内区分 IoC、DI 和依赖反转，画出 WorkOrderService 的对象图，并解释为什么构造器依赖适合 `final`。构建证据要证明生产配置使用内存仓储与记录通知，测试配置能替换通知而不改业务类。

故障证据必须包含缺 Bean、两个 NotificationPort、构造器循环和字段注入对象被手工 new 后空指针。每个启动失败都要定位到 cause 链中的具体类型或 bean 名，而不是只说“Spring 起不来”。

配套工件：

- [IoC 与对象图观察台](../../../examples/encyclopedia/ch.spring.ioc-di/README.md)
- [构造器装配与失败图实验](../../../labs/encyclopedia/ch.spring.ioc-di/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.spring.ioc-di/README.md)

## 2. 从普通 Java 对象开始

Spring 管理的对象仍是 Java 对象。`WorkOrderService` 可以没有 Spring 注解、基类或容器接口，只通过构造器接收 `WorkOrderRepository` 与 `NotificationPort`，方法里执行业务编排。

先写成普通 Java 能迫使依赖边界清晰。若移除 Spring 后服务就无法手工构造，通常说明业务类读取了全局容器、环境或静态单例。

## 3. 什么是依赖

对象为了完成职责而调用的协作者就是依赖。字符串参数是一次调用的输入，repository 是跨调用协作者，两者生命周期和替换方式不同。依赖不仅是 Maven JAR，也包括运行时对象关系。

画图时用有向边表示“谁需要谁”：`WorkOrderService → WorkOrderRepository`。边的方向决定编译依赖和测试替换点，不要只列一堆类名。

## 4. 紧耦合的直接创建

若服务构造器内部写 `this.repository = new JdbcWorkOrderRepository(...)`，高层业务知道 JDBC、连接和配置。测试无法换成内存实现，技术升级也会触碰业务类。

直接 new 本身不是罪。值对象、局部集合和无协作者算法可在业务代码创建；问题是高层对象主动选择本应由边界决定的协作者。

## 5. IoC 是控制权转移

传统对象自己创建或查找依赖；IoC 让外部组合根决定创建顺序和连接关系。业务对象只保留使用协作者的控制权，不再控制协作者来自哪个实现。

IoC 是广义思想，框架回调、模板方法也可体现控制反转。本章只聚焦对象创建与装配，不把所有回调都称为 Spring DI。

## 6. DI 是 IoC 的一种形式

依赖注入通过构造器、工厂方法或属性把协作者提供给对象。对象不调用 Service Locator，也不从静态 ApplicationContext 拉取。Spring 容器在创建 bean 时执行这项注入。

“注入”不等于必须加 `@Autowired`。Java 配置的 `@Bean` 方法参数和普通构造器已足够表达依赖。

## 7. 依赖反转原则

依赖反转要求高层策略不依赖低层细节，两者依赖抽象；抽象由高层用例需要塑造，而非让基础设施定义。`WorkOrderRepository` 放在应用边界，数据库适配器实现它。

DI 是装配机制，DIP 是依赖方向设计原则。把具体类注入构造器也叫 DI，但未必实现了业务所需的依赖反转。

## 8. TypeScript/Vue 类比

Vue composable 接收一个 API client 参数，比在函数内部 import 全局单例更容易测试。Java 构造器注入同样把依赖列在入口，只是类型和对象生命周期由 JVM/Spring 表达。

类比有边界：Spring ApplicationContext 会建立 bean definitions、解析类型并管理容器生命周期；普通 composable 参数没有完整容器语义。

## 9. 手工组合根

最小组合根先创建 repository，再 notification，最后 `new WorkOrderService(repository,notification)`。它清楚展示对象图，也是检验 Spring 配置是否只是装配而非隐藏业务的基线。

小应用手工装配完全可行。引入容器的价值在于统一大量对象的注册、解析和生命周期，而不是让三行 new 看起来更高级。

## 10. 对象图

对象图是运行时实例及其引用关系。定义图时要区分接口节点和实际实例：服务字段静态类型是接口，当前边指向 `InMemoryWorkOrderRepository` 实例。

容器解析一个根 bean 时会递归创建所需依赖。图中缺节点、候选过多或形成无法构造的环，都会在创建阶段暴露。

## 11. Spring IoC 容器

Spring 的 `BeanFactory` 提供基础创建与解析能力，`ApplicationContext` 在其上提供常用应用级能力。独立 Java 工件使用 `AnnotationConfigApplicationContext` 读取 Java 配置并刷新对象图。

容器不是业务服务仓库。代码不应在任意方法里调用 `context.getBean` 查依赖；查询只留在启动/测试观察边界。

## 12. 配置元数据

容器需要说明哪些对象由它创建、如何命名、用哪个工厂和依赖谁。这些说明是配置元数据，可来自 Java 配置、注解组件、XML 或程序化注册。

本章只用显式 Java 配置。选择一种方式是为了看清图，不代表其他方式无效；避免同一小项目混合多套来源导致候选难追踪。

## 13. BeanDefinition、名称与实例

BeanDefinition 是创建 bean 的配方，包含类型、工厂、依赖等元数据；bean name 是容器内标识；bean instance 才是业务调用的对象。三者不能互换。

默认 `@Bean` 名通常来自方法名。按类型查找可能得到零个、一个或多个候选；名称存在也不保证类型符合调用者预期。

## 14. 什么应成为 bean

应用服务、仓储适配器、外部客户端、Clock 等跨用例协作者适合由容器装配。它们的实现选择和生命周期属于应用配置。

每张工单、每个设备 ID 和每次请求 command 通常由业务代码创建，不应注册成全局 bean。容器管理一切会把领域对象生命周期搞混。

## 15. `@Configuration`

`@Configuration` 标识类主要提供 bean definitions。`AnnotationConfigApplicationContext(AppConfig.class)` 注册配置，处理 `@Bean` 方法并刷新非懒 singleton。

配置类属于组合根，不写领域判断。生产、测试可各自提供边界实现，但不要复制 WorkOrderService 业务逻辑。

## 16. `@Bean`

`@Bean` 方法实例化、配置并返回容器管理对象。方法返回类型参与类型解析，方法名默认成为 bean name。第三方类或需要显式构造参数的对象尤其适合这种方式。

方法体可以 new 具体实现，因为配置层的职责正是选择实现。业务服务内部则只依赖接口。

## 17. 工厂方法参数表达依赖

`workOrderService(WorkOrderRepository repository, NotificationPort notification)` 明确告诉容器两个必需依赖。Spring 按类型寻找候选，再调用方法。

这比配置方法内部调用 `context.getBean` 更可读，也便于启动错误指出具体参数。参数过多仍是职责过重信号，不应用容器掩盖。

## 18. `proxyBeanMethods=false`

本章配置使用 `@Configuration(proxyBeanMethods=false)`，并通过 `@Bean` 方法参数连接依赖。此 lite 模式不会拦截配置类内部的普通方法调用，也不生成用于跨方法单例语义的 CGLIB 子类。

因此不要在一个 `@Bean` 方法里直接调用另一个 `@Bean` 方法；那只是普通 Java 调用，可能新建额外实例。全部依赖写成参数最清楚。

## 19. 创建与关闭 Context

`AnnotationConfigApplicationContext` 在构造/refresh 时注册并创建默认非懒 singleton。它实现 Closeable，创建者必须 try-with-resources 或 finally close。

关闭 context 才能触发由容器拥有的销毁回调。本章不展开完整生命周期，但工件断言测试结束后 context 已离开所有权作用域。

## 20. 构造器注入

构造器把所有必需依赖列在类型签名中。对象创建成功即达到可用状态，字段可以 `final`，纯单元测试能直接 new 并传入 fake。

Spring 官方一般倡导构造器注入。一个类需要许多构造参数通常意味着职责太多，应先重构，而不是改成隐藏字段。

## 21. 非空不变量

构造器可用 `Objects.requireNonNull` 在第一处可信边界拒绝缺失依赖。容器通常会在解析前发现零候选，但手工调用仍需要类自己的不变量。

不要让 null 依赖存活到第十次业务调用才 NPE。启动失败或构造失败比运行中随机失败更可诊断。

## 22. `final` 字段

`final` 表达协作者引用在构造后不替换，降低半初始化和并发可见性风险。它不保证依赖对象内部不可变或线程安全。

测试替换发生在创建新的 service 实例或新的 context，而不是运行中修改 private 字段。

## 23. 接口作为端口

`WorkOrderRepository` 描述保存/查找工单所需能力，`NotificationPort` 描述通知事件。应用服务依赖这些小接口，内存、日志或未来数据库/消息实现位于外层。

接口不是为了“每个类都有接口”。只有真实替换边界、依赖方向或多实现语义时才有价值。

## 24. 两个端口的对象图

图为 `WorkOrderService → WorkOrderRepository → InMemory...` 和 `WorkOrderService → NotificationPort → Recording...`。服务创建工单，repository 保存，notification 记录业务 ID。

测试配置只替换 notification 为 `SpyNotificationPort`，repository 和 service 规则不复制。这就是构建 outcome 的核心证据。

## 25. 实现替换

替换实现不应要求修改 WorkOrderService。手工测试传入 fake，容器测试注册 TestConfig；调用结果与保存行为保持，只有观察方式改变。

如果替换需要 `if (test)` 分支或反射改字段，说明依赖没有在正确边界显式化。

## 26. 纯单元测试边界

业务规则测试直接 `new WorkOrderService(fakeRepository,spyNotification)`，不启动 Spring。它更快、更精确，也证明类没有容器耦合。

容器测试另行验证 definitions 和解析。不要用 Spring 启动测试替代所有普通 Java 测试。

## 27. 容器装配测试

装配测试创建 context，按类型取得 WorkOrderService，执行固定用例，并检查实际 repository/notification 实例。它验证配置图，不重新测试每条领域分支。

测试必须 close context，并在失败时保留最深 cause。只断言“context 不为 null”没有证明依赖正确。

## 28. 缺 Bean

若定义 WorkOrderService 却没有 NotificationPort，Spring 无法满足工厂参数或构造器，context refresh 失败。外层常是 `UnsatisfiedDependencyException`，cause 中包含 `NoSuchBeanDefinitionException`。

修复不是在 service 内 new 默认实现，而是在组合根注册明确 bean，或确认该依赖是否真的必需。

## 29. 多 Bean 歧义

同时注册 EmailNotification 与 AuditNotification，注入点只要求 NotificationPort，容器无法猜哪一个，通常抛 `NoUniqueBeanDefinitionException` 作为 cause。

先问这两个实现是否应组合、是否属于不同语义接口。只有确实需要选择时再使用明确 bean name、qualifier 或 primary，不能靠声明顺序。

## 30. Qualifier 是显式选择

`@Qualifier` 或命名参数可表达候选选择，但名称变成契约的一部分。它适合确有“sms”和“audit”两类语义，而非随手消除错误。

本章正确路径保持每个端口单候选。歧义故障只用于读懂错误图，不提前建立复杂选择体系。

## 31. 字段注入隐藏依赖

private 字段上的 `@Autowired` 不出现在构造器。手工 `new FieldInjectedService()` 可以成功，但第一次调用才因 null 失败；测试还需容器或反射才能赋值。

修复为构造器参数与 final 字段。输入签名一眼可见，IDE、编译器和普通单元测试都能协助维护。

## 32. Setter 注入的边界

setter 适合真正可选且有安全默认值、或确需运行中重配置的依赖。必需 repository 使用 setter 会产生“构造成功但尚不可用”的窗口。

不要为了解决循环依赖把构造器全部改 setter。那只是让不完整对象提前暴露，依赖方向仍然错误。

## 33. Service Locator 反模式

业务对象保存 ApplicationContext 并在方法里 `getBean(NotificationPort.class)`，表面少了构造参数，实际把所有容器内容变成隐式依赖。测试、重构和错误定位都更差。

容器查询只允许出现在组合根或观察测试。协作者通过构造器进入业务对象。

## 34. 静态单例不是 DI

`NotificationRegistry.getInstance()` 仍由业务代码选择全局实现，测试会共享状态并需要重置。把静态字段换成 Spring singleton 也不自动解决可变状态并发。

DI 关注引用如何提供；scope 与线程安全是另一维度，下一章展开。

## 35. 构造器循环

若 A 构造器需要 B，B 构造器又需要 A，任何一个都无法先完整创建。Spring 检测后抛 `BeanCurrentlyInCreationException` 等 cause，constructor cycle 是不可解析对象图。

不要用 `@Lazy`、setter 或字段注入把环藏起来作为默认修复。先重新划分职责或引入单向协调者/事件边界。

## 36. 循环通常暴露职责问题

WorkOrderService 需要 NotificationService 是合理方向；若 NotificationService 又需要 WorkOrderService 才能发送，说明通知层混入了用例查询或回调控制。

可提取 `WorkOrderViewPort`、传递已准备好的事件数据，或由上层 coordinator 按顺序调用。修复目标是有向无环图，而不是让容器强行启动。

## 37. 延迟初始化不等于修复

lazy bean 可把创建推迟到首次请求，但缺依赖和环仍存在，只是失败更晚。启动快并不是正确性证据。

基础应用默认在 context refresh 时暴露配置错误更安全。本章不启用 lazy 逃避故障。

## 38. cause 链阅读

Spring 启动异常外层描述哪个 bean 创建失败，中层描述哪个参数无法满足，深层给出零候选、多候选或当前创建环。按 cause 逐层记录类型与 bean 名。

不要依赖完整本地化 message 做程序断言。测试可用 `hasCause(Throwable,Class<?>)` 检查确定异常类型，并输出稳定逻辑标签。

## 39. Bean 名与类型证据

context 可查询 bean 名和类型用于诊断，但业务路径不应依赖枚举整个容器。测试断言 `getBeanNamesForType(NotificationPort.class)` 恰好一个，能早期发现歧义。

生成报告时按名字排序，不打印机器路径或对象 identity hash，保证离线输出稳定。

## 40. 配置类也要保持小

配置负责选择实现、构造参数与环境值，不执行创建工单等业务。一个配置类过大时按模块/边界拆分，再用 `@Import` 组合；本章保持一个小图。

不要在 `@Bean` 方法里 catch 所有异常并返回 null。让 context refresh 保留真实失败。

## 41. component scanning 的位置

Spring 能扫描 `@Component` 候选，但包范围、重复扫描和隐式注册会增加来源不透明。本章使用显式 `@Bean`，让初学者能逐边画图。

以后使用 scanning 也要限制根包并理解每个 stereotype。扫描不是“自动发现任何需要的类”。

## 42. BeanDefinition 与业务配置

BeanDefinition 描述对象创建，不等同于业务数据。工单优先级、状态流转不应写进 Spring bean name 或条件注册。

环境差异可选择 adapter，但领域规则仍由代码和输入表达。不要让 Profile 变成业务 if 的替代品。

## 43. FactoryCare 正常路径

固定创建 `WO-17`，repository 保存一次，notification 收到一次 `created:WO-17`，service 返回相同 ID。构造器参数、bean names、候选数量和事件列表都有断言。

同一用例再用手工组合根运行，结果一致。Spring 改变装配方式，不改变业务语义。

## 44. 测试配置替换

TestConfig 注册 `SpyNotificationPort`，暴露其事件列表；WorkOrderService 的定义仍接收 NotificationPort 参数。测试不继承生产配置后覆盖同名 bean，而是建立最小、无歧义图。

这样失败时能看出是业务还是配置。复制整套 production beans 会引入无关依赖。

## 45. 缺 Bean 故障 oracle

MissingConfig 只注册 repository 与 service，refresh 必须失败；cause 链含 NoSuchBeanDefinition。若 service 内偷偷 new notification，测试会意外通过并揭示依赖反转退化。

修复在配置增加 NotificationPort bean，同时保持 service 构造器不变。

## 46. 重复 Bean 故障 oracle

AmbiguousConfig 注册两个 NotificationPort 和一个 service 工厂参数。refresh 必须失败且报告候选数 2。测试不允许用 `getBeansOfType().values().stream().findFirst()` 随机挑选。

修复优先重新定义语义：若两者都要调用，创建 CompositeNotificationPort；若只选一个，配置显式选择。

## 47. 字段注入故障 oracle

故障类只有 `@Autowired NotificationPort notification` 字段和无参构造器。手工 new 后调用抛 NPE，反射还显示构造器参数数为 0，证明依赖未进入类型入口。

正确类构造器参数数为 1 或更多，字段 final，传 null 当场失败。资产不会把字段注入作为“方便的正常示例”。

## 48. 循环故障 oracle

CycleConfig 定义 A(B) 与 B(A)，refresh 失败。测试遍历 cause 链寻找 BeanCurrentlyInCreationException，并记录 `constructor-cycle`，不匹配长 message。

正确图通过 coordinator 或单向 port 消除反向边。测试同时断言正常 config 无该 cause。

## 49. Maven 离线证据

每个资产显式固定 Spring Context 7.0.7、JUnit Jupiter 6.1.1、compiler 3.15.0 与 Surefire 3.5.5，release 为 25。verify 首先检查 Maven/JDK，再用 `mvn -o`。

离线通过证明依赖已缓存且 POM 自足，不证明未来 patch 兼容。版本升级要先更新登记基线、运行相同故障矩阵并保留回滚。

## 50. 预测练习

运行前预测：没有 NotificationPort 时 context 何时失败？两个实现会按声明顺序选吗？字段注入对象手工 new 后字段是什么？构造器 A↔B 能先创建谁？测试替换需不需要改 service？

把答案写成异常类型、候选数或布尔，再运行工件。错题改成对象图规则。

## 51. 独立构建任务

从空项目写两个端口、两个适配器、WorkOrderService 与 AppConfig。先手工装配，再用 context 装配；所有必需依赖必须在构造器，配置方法用参数连接。

补纯单元测试、生产装配测试、TestConfig 替换测试，以及缺失/歧义/循环失败测试。输出稳定 bean 名和事件，不输出对象地址。

## 52. 修改任务

新增 `Clock` 端口并在 service 构造器加入，生产配置用固定教学 Clock，测试用另一个固定值。预测哪些配置会因缺 bean 失败，再逐个修复。

再把两个通知实现改成 composite，让两者都收到事件；不能用 `@Primary` 隐藏“都要调用”的业务要求。

## 53. 诊断顺序

先读最外层 bean 名和工厂参数，再沿 cause 找 NoSuch、NoUnique、CurrentlyInCreation 或业务构造异常。然后画当前图与期望图，标零节点、多节点和环。

一次只修一条边并复跑正常路径。不要开启允许覆盖、lazy 或字段注入来消音。

## 54. 120 秒复述提纲

说明 IoC 与 DI 的关系、DIP 与 DI 的区别、ApplicationContext 如何从 definitions 构造对象图、构造器注入为什么保证显式与可测试。再解释哪些对象不应成为 bean。

最后讲一个歧义或循环失败：第一处可信 cause 是什么，如何通过改变接口语义/图方向修复。

## 55. 验收清单

- 手工组合根与 Spring 组合根业务结果一致。
- WorkOrderService 只依赖端口接口，构造器字段 final/non-null。
- Java 配置用 `@Bean` 参数连接，无业务逻辑。
- 测试配置替换实现不改 service。
- 缺 Bean 与重复 Bean 在启动期明确失败。
- 构造器循环被检测并通过重构图消除。
- 正确代码无字段注入、Service Locator 或静态容器。
- 四类资产在 JDK 25/Maven offline 下可重放。

## 56. 有意不做

本章不展开 singleton/prototype/request scope、完整 bean 生命周期、组件扫描策略、Profile、配置属性、Spring Boot 自动配置、AOP、事务、Web、数据库或消息队列。它们需要独立责任与故障矩阵。

没有为字段注入、循环依赖或 bean 覆盖保留兼容路径。旧项目迁移应先加构造器、建立组合根测试，再逐类移除隐藏依赖；回滚是恢复上一份可启动配置，而不是允许不完整对象。

## 57. 一手资料

- [Spring Framework IoC Container](https://docs.spring.io/spring-framework/reference/core/beans.html)
- [Dependency Injection](https://docs.spring.io/spring-framework/reference/core/beans/dependencies/factory-collaborators.html)
- [Container Overview](https://docs.spring.io/spring-framework/reference/core/beans/basics.html)
- [Java-based Container Configuration](https://docs.spring.io/spring-framework/reference/core/beans/java.html)
- [`@Bean` 与 `@Configuration` 基础](https://docs.spring.io/spring-framework/reference/core/beans/java/basic-concepts.html)
- [AnnotationConfigApplicationContext](https://docs.spring.io/spring-framework/reference/core/beans/java/instantiating-container.html)
