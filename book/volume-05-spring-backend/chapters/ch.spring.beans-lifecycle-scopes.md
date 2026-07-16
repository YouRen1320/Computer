---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.beans-lifecycle-scopes
title: Bean 注册、生命周期、作用域与销毁
responsibility: 教授容器管理对象的创建、作用域和销毁边界，不提前引入配置属性或 Web 请求路由
volume: '05'
order: 3
level: L2
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.beans-lifecycle-scopes.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.spring.ioc-di
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
  text: 在 120 秒内解释Bean 注册、生命周期、作用域与销毁的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - spring-bean-registration
  - spring-bean-lifecycle
  covers_topics:
  - spring.bean-definition
  - spring.component-configuration-bean
  - spring.bean-ambiguity
  - spring.bean-lifecycle
  - spring.singleton-prototype-scope
  - spring.destroy-callback
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.encapsulation-immutability
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：注册 singleton 与 prototype Bean，记录构造、初始化、获取和销毁顺序，并验证同/不同实例身份，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - spring-bean-registration
  - spring-bean-lifecycle
  covers_topics:
  - spring.bean-definition
  - spring.component-configuration-bean
  - spring.bean-ambiguity
  - spring.bean-lifecycle
  - spring.singleton-prototype-scope
  - spring.destroy-callback
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.encapsulation-immutability
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入 prototype 被 singleton 捕获和销毁回调未执行，利用实例 ID/生命周期日志修复作用域选择
  covers_topic_groups:
  - spring-bean-registration
  - spring-bean-lifecycle
  covers_topics:
  - spring.bean-definition
  - spring.component-configuration-bean
  - spring.bean-ambiguity
  - spring.bean-lifecycle
  - spring.singleton-prototype-scope
  - spring.destroy-callback
  uses_capabilities:
  - java.inheritance-polymorphism
  - java.encapsulation-immutability
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# Bean 注册、生命周期、作用域与销毁

> 本章状态为 drafting。正文与工件是作者级教材证据，不自动更新 PROGRESS.md，也不表示学习者已经通过 Week 09。

上一章解决“谁依赖谁、由谁装配”，本章继续回答“容器什么时候创建这个对象、同一份定义会产生几个实例、何时初始化、谁负责销毁”。Bean 不是带注解的神秘对象，而是由 Spring 容器依据 BeanDefinition 创建、装配和管理的普通 Java 对象。作用域决定实例可见范围，生命周期决定回调时机，两者都不替业务对象自动提供线程安全。

工件固定 JDK 25、Maven 3.9.16 与 Spring Framework 7.0.8。7.0.8 是 Spring Boot 4.1.0 官方依赖管理表中的 Framework 版本；本章不启动 Boot、不监听端口。官方资料复核日期为 2026-07-17。

## 1. 本章完成证据

完成证据包含三部分。第一，能在 120 秒内画出从 BeanDefinition 到可用 bean 再到容器关闭的时间线。第二，能预测 singleton、prototype、request、session 连续获取时的实例身份。第三，能解释 prototype 注入 singleton 为什么只解析一次，以及 prototype 的销毁为何不由容器自动完成。

配套工件：

- [Bean 生命周期观察台](../../../examples/encyclopedia/ch.spring.beans-lifecycle-scopes/README.md)
- [作用域、Web scope 与线程安全实验](../../../labs/encyclopedia/ch.spring.beans-lifecycle-scopes/README.md)
- [prototype 获取练习](../../../exercises/encyclopedia/ch.spring.beans-lifecycle-scopes/README.md)

## 2. 普通对象与 Bean

Java 对象由 new、反射、工厂或反序列化等方式产生。只有当某个对象由当前 Spring BeanFactory/ApplicationContext 的定义和扩展点接管时，才称为这个容器中的 bean。容器外手工 new 出相同类型，不会自动得到依赖注入、后处理或销毁回调。

因此“这个类是不是 bean”不是类文件的永久属性。同一个 WorkOrderClient 可以在一个 context 中受管，在另一个测试中手工创建。诊断时要问对象来自哪里，而不是只找类上有没有注解。

## 3. BeanDefinition 是配方

BeanDefinition 描述类型、工厂方法、构造参数、属性值、作用域、是否延迟创建、初始化方法和销毁方法等元数据。它像配方，不等于实例。singleton 配方通常产生一个缓存实例，prototype 配方可以按每次请求产生新实例。

容器先注册定义，再根据刷新和获取动作创建对象。定义存在不等于构造器已经执行。测试可以在 refresh 前检查定义，在 getBean 后检查实例日志，把“注册”和“实例化”分开。

## 4. 名称、类型与实例身份

Bean 名用于定位定义，类型用于候选解析，Java 引用的恒等性用于判断是否同一实例。三个概念不能混用：两个名字可以指向同一实例，一个类型可以有多个定义，同一 prototype 定义也会不断产生不同身份。

测试身份时用 assertSame 或 assertNotSame，不要只比较 equals。两个对象可能值相等但不是同一个生命周期实例；反之，可变 singleton 虽是同一引用，内部状态却可能被并发修改。

## 5. Java 配置注册

本章使用 Configuration 与 Bean 方法明确注册配方。配置类是组合根：方法创建对象，参数表达依赖，Bean 上的 scope、initMethod 和 destroyMethod 描述管理规则。业务判断不应塞进配置类。

使用 proxyBeanMethods=false 时，Bean 方法之间不要直接互调来取得别的 bean，而要把依赖写成参数。直接方法调用只是普通 Java 调用，可能绕过容器的作用域和缓存语义。

## 6. 组件扫描注册

Component、Service、Repository 等 stereotype 可成为扫描候选，扫描器再把候选转换为 BeanDefinition。扫描减少显式清单，却会让定义来源分散到包结构、条件和导入路径中。

初学阶段先用显式 Bean 看清配方和图，再理解扫描。生产项目使用扫描也应限制根包，并能通过 context 或测试说明某个 bean 是怎样注册的，不能用“Spring 找到的”代替证据。

## 7. 同类型歧义仍然存在

注册两个同类型 bean 后，按类型注入没有足够信息时会失败。作用域不会替你选择候选；一个 singleton 和一个 prototype 同类型也仍是两个候选。应通过端口语义拆分、Primary 或 Qualifier 显式表达选择。

不要依赖声明顺序、类路径顺序或集合的第一个元素。稳定测试应检查候选名称和根因类型，避免把本地碰巧启动当成确定合同。

## 8. 注册时机与创建时机

ApplicationContext refresh 会完成定义处理、注册后处理器并创建默认的非延迟 singleton。prototype 通常到第一次显式获取或被其他 bean 解析时才创建。Lazy singleton 也把创建推迟到首次需要。

延迟创建改变错误出现时间，却不修复错误。缺依赖若被 lazy 隐藏，可能从启动失败变成首个业务请求失败。除非启动成本或按需能力确有需要，不要用 lazy 给错误消音。

## 9. 默认 eager singleton

非 lazy singleton 通常在 context refresh 期间创建，所以构造、注入、初始化失败会阻止 context 成功就绪。这是有价值的 fail-fast：部署尚未接收流量时就能暴露错误对象图。

“启动通过”只证明已创建的 eager 图可以装配，不证明所有 lazy/prototype 路径可用。需要使用的按需分支仍要有专门测试。

## 10. 生命周期全图

一个典型 bean 依次经历：实例化、依赖填充、Aware 回调、初始化前 BeanPostProcessor、初始化回调、初始化后 BeanPostProcessor、对外可用；容器有序关闭时再执行销毁回调。

不同扩展点会插入更多步骤，代理也可能让外部拿到的引用不是原始对象。学习时先抓住不变量：依赖在初始化前应就绪，初始化完成后才发布，销毁只发生在容器确实拥有并追踪的实例上。

## 11. 第一步：实例化

容器选择构造器或工厂方法并创建原始实例。构造器注入的必需依赖会在调用构造器前先解析；Bean 工厂方法的参数也由容器解析。若构造器本身抛异常，后续初始化和销毁路径不会完整发生。

构造器应建立对象不变量，不应启动无法回滚的后台线程或执行远程迁移。重资源启动可放在明确初始化边界，并在失败时释放已经获得的局部资源。

## 12. 第二步：依赖填充

对象实例化后，容器可处理属性值、Autowired 字段或方法等填充动作。工件故意用一个 Autowired setter 记录 dependency-filled，让时间线可见；这不是推荐把必需依赖从构造器移走。

业务类仍优先构造器注入。setter 观察样例只为证明“实例已存在但属性尚未填充”的阶段，不能据此建立可半初始化的生产服务。

## 13. Aware 回调

BeanNameAware、BeanFactoryAware、ApplicationContextAware 等接口让对象获得容器基础设施信息。它们发生在属性填充之后、一般初始化回调之前。普通领域服务不应依赖这些接口。

Aware 是基础设施扩展点，不是隐藏 Service Locator 的许可证。若业务方法随处 context.getBean，依赖图、测试和失败时间都会变得不透明。

## 14. BeanPostProcessor 的位置

BeanPostProcessor 可以在初始化前后观察或替换 bean。Autowired、生命周期注解和许多代理能力本身就由容器后处理器参与实现。自定义处理器必须保持范围清楚，避免对所有对象做意外副作用。

工件的 TracePostProcessor 只匹配 observedBean，并记录 before-init 与 after-init。它不修改对象，因此测试能把处理器位置与业务行为分开。

## 15. 初始化前处理

postProcessBeforeInitialization 在依赖填充、Aware 之后执行，在常规初始化回调之前。返回值可能成为后续链处理的对象；返回 null 会终止当前后处理链的后续调用，属于高级且危险的行为。

若在此处做校验，错误应包含稳定 bean 名和配置键。不要打印完整对象，因为对象可能含凭据或大状态。

## 16. PostConstruct

现代 Spring 应用常用 jakarta.annotation.PostConstruct 表达初始化回调，降低对 Spring 接口的耦合。方法应快速、可重放地验证或准备本地状态，不应假定所有外部服务永远可用。

同一 bean 同时使用多种初始化机制时，官方顺序为 PostConstruct、InitializingBean.afterPropertiesSet、最后是自定义 init 方法。通常选择一种即可；工件组合多个机制只是为了观察顺序。

## 17. InitializingBean

InitializingBean.afterPropertiesSet 在所有必要属性设置后调用。它能直接表达容器回调，但让类依赖 Spring API，因此官方更偏向 PostConstruct 或自定义方法。

实验中使用它是为了得到稳定事件 after-properties-set。生产设计应先判断初始化是否真的需要容器回调，很多不可变对象在构造完成时已可用。

## 18. 自定义 init 方法

Bean 的 initMethod 可指向普通 Java 方法，类无需实现 Spring 接口。方法名属于配置元数据，重命名时必须同时更新配置并让启动测试捕获漂移。

当三种初始化机制并存且名称不同，自定义 init 最后执行。若同一个方法被多个机制重复指向，Spring 会避免重复调用；不要依赖这种去重制造晦涩配置。

## 19. 初始化后处理

postProcessAfterInitialization 在初始化回调完成后执行，常用于返回代理。调用者从 context 取得的可能是代理引用，而不是构造器产生的原始引用。

因此不要在初始化方法里假定通过 this 调用就经过最终代理。事务、缓存和安全等代理主题留给后章，本章只建立“后处理器可能替换引用”的边界。

## 20. 对外可用状态

当 refresh 成功返回，默认 eager singleton 已完成初始化。业务代码此时才能把它当成就绪依赖。若 bean 自己又异步启动后台任务，“context 就绪”和“外部资源就绪”可能不同，必须另建健康状态。

测试应在 ready 后执行固定业务动作，并保留初始化日志。只断言 bean 不为 null 无法证明依赖和初始化顺序正确。

## 21. 容器关闭与所有权

ApplicationContext.close 表示创建者归还整个容器的所有权。被容器追踪且支持销毁的 singleton 会收到回调。try-with-resources 能让测试和命令行程序即使断言失败也关闭 context。

若应用进程被强制 kill、崩溃或断电，正常回调没有保证。销毁逻辑应尽力释放本地资源，但不能把唯一业务数据提交寄托在 PreDestroy 上。

## 22. 销毁回调顺序

多种销毁机制并存且方法名不同，官方顺序为 PreDestroy、DisposableBean.destroy、最后是自定义 destroy 方法。正常代码通常只选择一种清晰机制。

销毁必须幂等或至少能处理部分初始化状态。若第一个清理动作抛错，其他资源仍需要独立 finally 或聚合处理，不能留下线程和文件句柄。

## 23. 初始化失败的清理

构造到初始化之间可能已获得资源后再失败。因为 bean 未完整创建，不能盲目假设常规 destroy 一定补救所有中间状态。初始化方法内部应使用局部 try/finally 回滚自身已取得的资源。

确定性故障测试可以让 customInit 抛出固定标签，再检查 context refresh 失败、ready 事件未出现。不要用随机网络超时作为学习 oracle。

## 24. singleton 作用域

singleton 是默认 scope。同一容器、同一 bean 定义的获取会返回同一受管实例。它是 per-container、per-bean，而不是 GoF 意义上每个 ClassLoader 全局唯一。

两个独立 ApplicationContext 各自拥有自己的 singleton。同一个类注册为两个不同 bean 名，也会有两个 singleton 实例。说“这个类全局只有一个对象”是不准确的。

## 25. singleton 与缓存

容器在 singleton 缓存中保存创建完成的实例，后续 getBean 和依赖解析复用它。缓存行为属于容器，不需要业务类写 static getInstance。

把 Spring singleton 与静态全局单例混为一谈，会破坏测试隔离和容器所有权。不要再叠加静态 INSTANCE 字段。

## 26. singleton 不等于线程安全

Web 应用通常让多个线程同时调用同一 singleton。Spring 只保证作用域身份，不会自动给字段加锁、复制对象或把 ArrayList 变成并发集合。

无状态服务最容易安全共享。若 singleton 持有可变计数、当前用户或临时 StringBuilder，必须用正确并发设计或把状态移到更合适边界。

## 27. 确定性丢失更新

实验的 UnsafeCounter 让两个线程先读到同一个旧值，再同时写回旧值加一，最终计数固定为 1 而不是 2。这不是概率压测，而是用 barrier 强制展示竞态。

修复可以是 AtomicInteger、锁、数据库原子更新或彻底移除共享可变状态。选择取决于一致性边界，不能简单把 scope 改成 prototype 就宣布线程安全。

## 28. prototype 作用域

prototype 每次向容器请求该定义时创建一个新实例。请求包括显式 getBean，也包括另一个 bean 创建时解析依赖。它适合需要独立可变状态且由调用方拥有的短生命对象。

prototype 不是“每个方法调用自动一个”。若调用方只获取一次并保存字段，之后方法仍重复使用同一个对象。

## 29. prototype 的初始化与销毁

容器会实例化、填充并初始化 prototype，但交给调用方后不再完整追踪。因此配置的销毁回调不会在 context 关闭时自动针对每个 prototype 执行。

若 prototype 持有文件、连接或线程，调用方必须明确 close/release，或设计专门后处理器追踪。更简单的选择通常是不要让短生命 bean 自己拥有重资源。

## 30. 所有权随实例交付转移

prototype 类似受容器增强的 new：容器负责创建前半程，调用者接管使用和清理后半程。API 应让所有权可见，例如返回 AutoCloseable 并使用 try-with-resources。

没有明确所有者的 prototype 会泄漏。仅仅给类写 destroy 方法并不能让容器记住所有已交付实例。

## 31. prototype 注入 singleton 的陷阱

singleton 只创建一次，构造参数也只解析一次。若直接把 prototype 注入 singleton，容器在 singleton 创建时生成一个 prototype，此后 singleton 永远保存那一个引用。

故障表现为两次 issueTicket 得到相同实例 ID。prototype 定义本身没有失效，是获取时机与期望不一致。

## 32. 按需获取 ObjectProvider

当 singleton 每次业务动作确实需要新 prototype，可注入 ObjectProvider<PrototypeType>，在方法内调用 getObject。这样每次请求都回到容器解析该 prototype 定义。

ObjectProvider 会让业务类知道 Spring 工厂抽象，应限制在组合/工厂边界。另一种做法是注入普通 Java Supplier 或自定义领域工厂，让核心业务保持框架无关。

## 33. scoped proxy

较短 scope 注入较长 scope 时，Spring 可注入代理。singleton 保存的是稳定代理，代理在每次调用时定位当前 request/session/prototype 目标。

代理要求调用发生时相应 scope 已激活。离开 HTTP request 再调用 request-scoped 代理会失败；代理不是把 request 对象复制到后台线程。

## 34. request scope

request scope 为每个 HTTP request 保存一个实例。同一请求内多次解析得到同一目标，不同请求得到不同目标。请求完成后，目标随 request scope 结束并可触发已登记清理。

它不是 thread scope。异步 dispatch 可能换线程，同一请求仍有自己的请求属性；线程池也会让一个线程先后处理很多请求。

## 35. session scope

session scope 为每个 HTTP session 保存一个实例。同一 session 的多个请求共享目标，不同 session 隔离。session 可能持续很久、跨线程且占用服务器内存。

不要把大对象、数据库实体图或秘密缓存塞进 session。集群部署还需考虑序列化、复制、过期和失效，但这些不在本章工件中。

## 36. Web scope 的上下文要求

request、session、application 和 websocket scope 依赖 Web-aware ApplicationContext 与当前请求状态。DispatcherServlet 通常暴露所需状态；Servlet 之外可能需要 RequestContextListener 或 RequestContextFilter。

本章测试显式注册 Spring 的 RequestScope/SessionScope，并用 MockHttpServletRequest 绑定 RequestContextHolder。它验证 scope 实现，不冒充真实容器集成。

## 37. 未激活 scope 的失败

普通 AnnotationConfigApplicationContext 没注册 request scope 时，包含 request 定义可能到首次获取才报 unknown scope。即使注册了 scope，没有绑定 RequestAttributes 也会报告当前线程找不到请求。

稳定测试应区分“scope 未注册”和“当前 request 未暴露”。不要 catch 后创建全局 fallback，这会把请求隔离退化为共享状态。

## 38. request 销毁边界

ServletRequestAttributes.requestCompleted 会执行请求级销毁回调。真实容器由请求基础设施负责触发，业务代码不应随意提前完成请求。

测试必须在 finally 中 reset RequestContextHolder，避免线程复用污染下一个用例。这与生产 Filter 清理 ThreadLocal 的原则相同。

## 39. session 失效边界

session bean 会随相应 session 生命周期结束。显式 logout 或过期可能触发失效，不能假定只在应用关闭时销毁。清理应容忍 session 已部分不可用。

不要用 session scope 代替数据库事实。服务器重启、过期或用户清理 Cookie 都可能结束会话，而工单状态必须持久化。

## 40. scope mismatch 的设计检查

每条依赖边都要问：长生命对象是否直接保存短生命对象？singleton 保存 request 用户数据会串请求；session 保存 request response 会越界；prototype 持有 singleton 通常安全，但仍要审查共享对象线程安全。

若需要跨 scope，优先传递不可变值或显式工厂，不要把整个容器对象生命周期向外延伸。

## 41. 自定义 scope

Spring Scope 接口允许定义缓存、删除、销毁回调和上下文 ID。SimpleThreadScope 是示例但默认不注册，也不自动清理线程池状态。

自定义 scope 是高级基础设施。必须写清创建、获取、结束、异常和并发规则，否则一个自创注解只会隐藏全局 Map。

## 42. 资源型 bean

连接池、调度器、客户端和监控导出器常是 singleton 资源 bean：初始化一次、并发共享、容器关闭时 close。它们内部必须声明线程安全合同。

不要把每次数据库连接本身做 singleton。通常 singleton 是线程安全的 DataSource/池，连接由每次操作借出并归还。

## 43. 关闭 context 的测试纪律

每个创建 context 的测试都使用 try-with-resources，故障 refresh 也在 finally/close 中收尾。否则后台线程或静态缓存可能让后续测试假通过或进程不退出。

verify 从 clean 状态运行，重复两次输出必须相同。生命周期证据用固定事件名，不输出对象地址、随机 UUID 或纳秒时间。

## 44. 生命周期日志设计

日志至少包含 bean 名、阶段和稳定序号，例如 observed:constructed、observed:dependency-filled、observed:before-init。实例身份在测试内用递增 ID，不写 identityHashCode。

敏感字段不应进入 toString 或生命周期日志。下一章会系统讨论配置秘密；本章先遵守最小披露。

## 45. 正常生命周期 oracle

refresh 后事件顺序必须是 constructed、dependency-filled、before-init、after-properties-set、custom-init、after-init。取 bean 后加入 used；close 后追加 destroy、custom-destroy。

此 oracle 针对工件选择的回调组合，不声称覆盖全部 Spring 内部步骤。它证明依赖先于初始化，销毁发生在有序关闭。

## 46. scope 身份 oracle

同一 context 连续两次获取 singleton 必须 assertSame；两次获取 prototype 必须 assertNotSame。两个 context 的 singleton 必须不同，证明 per-container 边界。

request 在同一绑定请求内相同、换请求不同；session 在两个共享 MockHttpSession 的请求间相同，换 session 不同。

## 47. prototype 捕获故障 oracle

BrokenTicketIssuer 构造时直接接收 prototype。连续两次 issue 返回同一 ticket ID，测试以 EXPECTED_FRESH_PROTOTYPE 标记失败。修复后通过 ObjectProvider 在每次调用取新实例。

不要把 prototype 改 singleton 或在 issuer 内手写 new 来让断言碰巧变化；那会绕过定义和初始化证据。

## 48. prototype 销毁缺失 oracle

取得两个 PrototypeResource 后关闭 context，destroyed 计数仍为 0，这是规范行为而非 Spring 漏调。调用方显式 release 两次后计数才为 2。

该测试提醒所有权，不鼓励给每个 DTO 加 close。只有真实持有资源的短生命对象才需要清理合同。

## 49. request scope oracle

绑定 request-A 后两次获取 RequestProbe 身份相同；完成并清理后绑定 request-B，得到不同实例。请求级状态互不出现。

测试不监听端口，也不验证 DispatcherServlet 映射。真实 Web 项目仍需集成测试 RequestContext 暴露和异常清理。

## 50. session scope oracle

两个 MockHttpServletRequest 共享同一个 MockHttpSession 时，SessionProbe 身份相同。第三个请求使用新 session 时身份不同。

这只证明 scope 键，不证明 Cookie 安全、分布式 session、并发写冲突或过期策略。

## 51. singleton 线程故障 oracle

两个线程进入同一 UnsafeCounter，barrier 强制都读到 0，再分别写 1，最终值固定为 1。验证器输出 singleton-race，而不是依赖偶发重现。

修复为 AtomicInteger 后原测试应期待 2；若改成 synchronized，还要移除会在锁内互相等待的 barrier 设计，避免制造测试死锁。

## 52. 独立构建任务

从空 Maven 工程注册 LifecycleLog、ObservedBean、singleton Probe、prototype Resource。写后处理器记录阶段，关闭 context 后生成固定验证报告。

再增加 request/session scope 测试，但只用 Spring 官方 scope 与 mock request。先预测每次获取身份，再运行断言。

## 53. 修改任务

把 singleton TicketIssuer 直接注入 prototype 改为注入 ObjectProvider 或普通工厂。保持 Ticket 类型与事件格式不变，证明每次调用获得新 ID。

再把一个无状态 singleton 改成有共享计数器，写确定性并发测试，选择原子更新或移除状态修复。

## 54. 诊断顺序

先记录 bean 名、定义 scope、实际获取时机和调用方生命周期。再判断问题是候选歧义、scope 未注册、scope 未激活、短 scope 被捕获，还是销毁所有权错误。

画出定义与实例两张图。定义图只有配方，实例图标出 context/request/session 和创建次数；很多 scope 错误在第二张图才显现。

## 55. 120 秒复述提纲

先解释 BeanDefinition 是配方，按顺序说实例化、填充、后处理、初始化、就绪和销毁。再比较 singleton、prototype、request、session 的身份边界。

最后给一个反例：prototype 直接注入 singleton 只解析一次，或者 singleton 可变字段发生丢失更新。说出证据和修复，而不是只背注解。

## 56. 有意不做与兼容边界

本章不讲配置属性、Profile、Web 路由、事务/AOP、完整 Boot 自动配置、自定义 scope 实现、分布式 session 或生产容器调优。request/session 只验证身份边界。

没有为静态 Service Locator、把 request 存入 singleton、prototype 自动销毁假设或旧 XML 配置保留兼容层。旧项目迁移应先加生命周期测试，再逐个显式化所有权；回滚是恢复上一份可启动配置。

## 57. 一手资料

- [Spring Framework Bean 概览](https://docs.spring.io/spring-framework/reference/core/beans.html)
- [Spring Framework Bean scopes](https://docs.spring.io/spring-framework/reference/core/beans/factory-scopes.html)
- [Spring Framework lifecycle callbacks](https://docs.spring.io/spring-framework/reference/core/beans/factory-nature.html)
- [Spring Framework container extension points](https://docs.spring.io/spring-framework/reference/core/beans/factory-extension.html)
- [Spring Framework Java 配置](https://docs.spring.io/spring-framework/reference/core/beans/java.html)
- [Spring Boot 4.1 管理依赖坐标](https://docs.spring.io/spring-boot/appendix/dependency-versions/coordinates.html)
