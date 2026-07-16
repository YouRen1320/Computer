---
schema_version: 2
edition: 2026.2-draft
id: ch.spring.aop-proxy-model
title: 切点、通知、代理边界与自调用陷阱
responsibility: 教授 Spring AOP 代理如何拦截边界调用，不把代理等同于对象本身或用 AOP 隐藏业务规则
volume: '05'
order: 14
level: L2
status: drafting
path: book/volume-05-spring-backend/chapters/ch.spring.aop-proxy-model.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.spring.beans-lifecycle-scopes
- ch.java-engineering.reflection-classloading-proxies
version_surfaces:
- spring-framework-7
- spring-boot-4.1
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
  text: 在 120 秒内解释切点、通知、代理边界与自调用陷阱的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - spring-aop-model
  - spring-aop-boundary
  covers_topics:
  - spring.aop-pointcut-advice
  - spring.cross-cutting-concern
  - spring.proxy-type
  - spring.self-invocation
  - spring.final-private-method-boundary
  - spring.proxy-debugging
  uses_capabilities:
  - java.inheritance-polymorphism
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：为标注方法添加计时 Advice，比较代理对象与目标对象，并演示外部调用被拦截、self-invocation 不被拦截
  covers_topic_groups:
  - spring-aop-model
  - spring-aop-boundary
  covers_topics:
  - spring.aop-pointcut-advice
  - spring.cross-cutting-concern
  - spring.proxy-type
  - spring.self-invocation
  - spring.final-private-method-boundary
  - spring.proxy-debugging
  uses_capabilities:
  - java.inheritance-polymorphism
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入 private/final 方法切点失效、同类自调用绕代理和异常被 Advice 吞，依据代理类型/日志修复
  covers_topic_groups:
  - spring-aop-model
  - spring-aop-boundary
  covers_topics:
  - spring.aop-pointcut-advice
  - spring.cross-cutting-concern
  - spring.proxy-type
  - spring.self-invocation
  - spring.final-private-method-boundary
  - spring.proxy-debugging
  uses_capabilities:
  - java.inheritance-polymorphism
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# 切点、通知、代理边界与自调用陷阱

> 本章状态为 drafting。教材和工件是学习证据，不自动更新 `PROGRESS.md`，也不代表生产切点或开销已经验证。

Spring AOP 的核心不是“注解会自动执行”，而是容器把目标对象包在代理后，调用者先调用代理，代理匹配切点并执行 Advice，再委托目标。只要调用没有经过代理——例如目标对象内部 `this.inner()`——Advice 就没有机会介入。

本章基线为 Spring Framework 7.0.8、Spring Boot 4.1.0、JDK 25 与 Maven 3.9.16。官方资料复核日期为 2026-07-17。

## 1. 本章完成证据

完成者要为标注方法添加计时 Advice，证明匹配调用恰好记录一次、不匹配不记录、返回值和异常语义不变；还要识别 JDK/CGLIB 代理，复现 self-invocation 以及 private/final 边界。

配套工件：

- [Spring AOP 代理观察台](../../../examples/encyclopedia/ch.spring.aop-proxy-model/README.md)
- [切点、代理类型与自调用实验](../../../labs/encyclopedia/ch.spring.aop-proxy-model/README.md)
- [修复吞异常 Advice 练习](../../../exercises/encyclopedia/ch.spring.aop-proxy-model/README.md)

## 2. 为什么需要横切关注点

计时、追踪、事务、缓存与授权检查常跨越许多服务边界。把相同 try/finally 复制到每个方法会产生样板和不一致。

AOP 允许把“在哪里应用”和“额外做什么”独立表达，但它不应隐藏工单状态机或派单授权这样的核心业务规则。

## 3. AOP 的最小词汇

Join point 是可被增强的位置；Spring AOP 的 join point 是方法执行。Pointcut 选择哪些方法；Advice 定义匹配后执行的动作；Aspect 把切点和通知组织在一起。

Advisor 是 Spring API 中 pointcut+advice 的组合；proxy 是调用者实际持有的包装对象；target 是最终执行业务方法的对象。

## 4. Join point

在 Spring AOP 中，代理可拦截方法调用边界，不直接拦截任意字段赋值、构造器内部指令或所有 JVM 指令。需要更广连接点时属于 AspectJ weaving 等不同模型。

先确认技术模型能看见目标事件，再设计切点，不能从注解名字倒推能力。

## 5. Pointcut

Pointcut 是谓词：给定方法与目标类，是否匹配。可按 execution 表达式、注解、类型或组合选择。

切点过宽会记录框架内部/高频 getter；过窄会静默漏掉重命名或接口调用。它是可测试的生产配置。

## 6. Advice

Advice 在匹配点之前、正常返回后、异常后、finally 或环绕执行。它必须明确是否允许改变返回、异常和调用次数。

计时通常需要在调用前取时钟、finally 记录，但仍必须原样传播目标结果或异常。

## 7. Aspect

Aspect 是横切模块，可用 `@Aspect` 声明并作为 Spring Bean 注册，也可直接使用 ProxyFactory/Advisor API。只有对象被容器识别并启用自动代理，注解声明才生效。

`@Aspect` 本身不是 component stereotype；还要通过 `@Component`、`@Bean` 或其他注册方式进入容器。

## 8. Before Advice

Before 在目标前运行，适合轻量校验或记录开始。它不能修改返回值，也不会忘记调用 proceed；若抛异常会阻止后续链。

只需“进入时做一次”时，使用最小能力比 Around 更不容易破坏语义。

## 9. After Returning

AfterReturning 仅在正常返回后运行，可观察返回值并记录成功。它不处理异常路径。

不要在这里伪造另一个业务返回；若必须转换返回已是在改变方法契约，应慎重设计显式 adapter。

## 10. After Throwing

AfterThrowing 在目标抛异常时运行，适合分类指标和脱敏日志。它不是自动恢复机制。

除非契约明确，Advice 应保留原异常类型、实例/cause 和传播路径，避免上层误判成功。

## 11. After Finally

After 类似 finally，无论成功或失败都执行。资源/计时收尾适合这里，但它拿不到可任意改变的 proceed 控制。

若收尾本身抛异常，可能覆盖原业务异常；记录器应有明确降级策略。

## 12. Around Advice

Around 最强：它决定何时、是否、调用几次 `proceed()`，也能替换返回或异常。因此最容易写出“目标根本没执行”或“异常被吞”的错误。

Framework 官方建议使用能完成需求的最小 Advice 类型；需要完整计时时再使用 Around 并测试语义透明。

## 13. proceed 必须被理解

调用 `proceed()` 才继续进入下一个 interceptor 或目标。零次表示短路，多次表示重复执行；重试 Advice 只有对适合重试且幂等的操作才安全。

派单命令绝不能因通用计时 Advice 误调用两次而产生重复 assignment/outbox。

## 14. 返回值透明

透明计时器保存 `Object result = proceed()` 并原样 return。返回 null、record、集合或异步句柄都不能被默认替换。

测试用不可等价的对象 identity，能发现 Advice 创建“看似相同”的新对象而破坏契约。

## 15. 异常透明

计时器通常在 finally 记录并让 Throwable 自然抛出。`catch (Exception) { return null; }` 会把失败伪装成功，并影响事务回滚。

测试应断言抛出的就是同一个异常实例或至少同类型/cause，而不只断言“有异常”。

## 16. 代理与目标不是同一对象

target 包含业务实现；proxy 持有/引用 target 与 interceptor 链。客户端调用 proxy，代理匹配后委托 target。

`proxy == target` 通常为 false。把 target 裸引用交给另一组件，会绕过计时、事务或缓存。

## 17. 代理调用链

典型顺序是 client→proxy→advisor1→advisor2→target，返回时逆序退出。每个 Around 的 finally 都在栈展开时执行。

日志可记录 enter/exit 顺序验证链，但不要依赖未声明的 Bean 发现顺序。

## 18. Spring Bean 才能被自动代理

`new AssignWorkOrderService(...)` 创建的普通对象不经过容器 auto-proxy creator，即使方法有 `@Transactional` 或自定义标注也不会自动增强。

单元测试若要验证业务可直接 new；要验证 AOP 必须显式 ProxyFactory 或启动受控 Spring context。

## 19. JDK 动态代理

目标实现接口时，Spring Core 的默认建议模型可使用 JDK 动态代理；代理实现接口，不是目标具体类的子类。调用者应按接口类型注入。

强转为实现类可能失败，未暴露在代理接口上的方法不能通过该 JDK proxy 调用。

## 20. CGLIB 类代理

目标没有接口或配置要求 target-class 时，Spring 使用运行时生成子类代理。它可暴露具体类公共/受保护可覆盖方法。

它仍受 Java 继承规则限制：不能重写 final/private/不可见方法，也不能继承 final class。

## 21. Boot 与 Framework 默认要区分

Framework 文档以接口代理为核心默认，但 Spring Boot 可能根据配置启用类代理。不要背一句“Spring 永远是 JDK”或“Boot 永远 CGLIB”。

运行时用 `AopUtils.isJdkDynamicProxy`、`isCglibProxy` 和实际 Bean class 验证当前应用。

## 22. Framework 7 的 @Proxyable

Framework 7 增加 `@Proxyable`，可在单个 component 或 `@Bean` 上选择 INTERFACES/TARGET_CLASS，并覆盖全局默认；也能限定暴露接口。

这是 7.x 版本表面，不应写进与 Framework 6 兼容的公共库而不说明基线。

## 23. 强制类代理的影响

`proxyTargetClass=true` 会把相关 auto-proxy creator 合并到更强设置，可能同时影响事务、AOP、async 等代理处理器。Framework 7 统一了更多全局默认参与行为。

修改它不是一个 Bean 的无害局部开关；需要回归注入类型、final 边界和所有相关代理。

## 24. final class 边界

CGLIB 通过继承生成子类，final class 不允许继承，因此不能创建这种类代理。若它实现接口，可考虑 JDK proxy 拦截接口方法。

不要为让 AOP 生效盲目移除领域类型的 final；优先把横切边界放到合适的应用服务接口。

## 25. final method 边界

CGLIB 无法 override final method，所以通过类代理调用该方法不执行 Advice。方法注解存在不等于代理能拦截。

JDK proxy 拦截接口调用，限制不同；诊断必须先确认代理类型，不能把两种规则混为一谈。

## 26. private method 边界

private method 不参与子类 override，也不在外部代理接口上，因此 Spring AOP 无法直接 advise。给 private helper 加 `@Transactional`/自定义计时标注通常没有期望效果。

如果它真是一个独立横切边界，把行为提取为另一个 Bean 的 public 方法；否则在外层入口计时。

## 27. package-private 可见性

父类中位于不同包的 package-private 方法对子类等同不可见，也不能被类代理重写。protected/public 可覆盖性更明确。

方法可见性是 Java 语言事实，AOP 不会绕过 JVM 访问规则。

## 28. Self-invocation

外部调用 proxy.outer() 会进入 Advice；target.outer() 内的 `this.inner()` 直接在 target 上分派，不回到 proxy，所以 inner 的切点不执行。

显式 `this.inner()` 与省略 this 的 `inner()` 结果相同。自调用是最常见“注解失效”原因之一。

## 29. 为什么外部 inner 又能拦截

同一个 inner 方法由客户端通过 proxy.inner() 调用时会匹配 Advice。由 outer 内部直接调用时不会。差异不在注解或方法，而在引用路径。

测试应同时调用这两条路径，才能形成可复现证据。

## 30. 避免 self-invocation

官方首选是重构，使边界调用发生在协作对象之间：OuterService 注入 TimedStep，调用另一个 Bean 的 public 方法。

这让依赖和事务边界更清晰，也不让业务类知道代理存在。

## 31. self injection

注入自身代理再通过 self.inner() 可以经过代理，但引入循环/生命周期和阅读成本。若使用必须明确原因与测试。

它通常不是第一选择，尤其不能用来掩盖一个本应拆分的巨型 Service。

## 32. AopContext.currentProxy

暴露代理后可从 AopContext 获取当前 proxy，但官方强烈不鼓励：代码与 Spring AOP 耦合，并要求 exposeProxy 配置和代理调用上下文。

教材不把它作为默认修复；优先重构协作边界。

## 33. AspectJ weaving 的区别

编译期/加载期 AspectJ 修改字节码，不依赖同样的代理跳转，因此没有同一 self-invocation 问题。但它是另一套构建、调试和运行模型。

不要为修一个边界误用 weaving；先确认成本和真实需求。

## 34. 注解切点

自定义 `@TimedOperation` 可标记明确的应用边界。注解要有 RUNTIME retention 和 METHOD/TYPE target，才能由运行时 pointcut 读取。

注解存在只是候选；Bean 是否被代理、方法是否可拦截、调用是否经过代理仍要同时成立。

## 35. execution 切点

`execution(* ..application..*Service.*(..))` 按包/类型/方法匹配，适合统一服务边界，但重命名和过宽匹配要测试。

不要用字符串切点隐藏业务授权；它适合通用计时/追踪，不适合定义“谁能派单”。

## 36. 组合切点

可以组合包范围与注解，要求既属于 application 又明确标注。这样减少意外代理 framework/internal 方法。

切点应有匹配和不匹配测试，正例数量不等于没有误匹配。

## 37. 方法注解解析差异

JDK proxy 的 Method 可能来自接口，而注解写在实现方法；简单 `method.getAnnotation` 可能看不到。Spring 的 pointcut/annotation utilities 会结合 target class 解析具体方法。

自写 interceptor 诊断时打印 method、targetClass 与 mostSpecificMethod，不要只看接口反射。

## 38. 多个 Advisor 的顺序

事务、计时、重试、授权可同时包围同一方法。谁在外层决定计时是否包含事务开始、重试次数是否每次计量以及异常先被谁翻译。

使用 `Ordered`/`@Order` 显式声明有意义的顺序，并用事件序列测试；相同 order 不应依赖偶然扫描顺序。

## 39. 计时器的时钟

生产可用单调时钟计算 elapsed，避免 wall clock 调整造成负值。测试注入确定性 `LongSupplier`，不用 sleep 形成脆弱断言。

记录方法标识、结果分类与 duration，避免记录敏感参数。

## 40. 同步方法的计时边界

同步返回时，Around elapsed 包含目标执行直到返回/抛出。若返回 Future/Publisher，它通常只测“创建异步句柄”而非异步完成。

异步计时要在 completion signal 上观察，不能把同步 Advice 数字当端到端时延。

## 41. 指标基数

method/status 是有限标签；workOrderId、tenantId、异常 message 可能产生高基数，不应直接成为 metric tag。

个体关联放脱敏 trace/log，聚合指标保持有界。

## 42. Advice 自身失败

计时记录器失败时是否影响业务必须明确。多数可观察性 Advice 应安全降级而不覆盖业务结果/异常，但合规审计不是普通可选日志。

FactoryCare 核心审计通过事务端口实现，不能靠“最好努力”的 AOP 日志替代。

## 43. 事务也是代理 Advice

声明式事务使用 Spring AOP 拦截外部调用，创建/加入事务、调用目标、按返回/异常提交或回滚。因此 self-invocation 与 private/final 边界同样重要。

看到 `@Transactional` 先问 Bean、proxy、method、call path、rollback rule 五件事。

## 44. 缓存也是代理边界

`@Cacheable` 等也依赖代理。内部调用可能绕缓存，key/condition 也不会执行。不能用缓存注解替代 Repository 正确性。

FactoryCare 权限敏感读在返回前仍需授权，旧缓存不能扩大可见范围。

## 45. Async 代理边界

`@Async` 外部代理调用可把执行提交到 executor；同类 self-invocation 仍在当前线程直接执行。线程切换也会影响 transaction/security context。

不要用 Async 注解隐藏必须同事务完成的核心写入。

## 46. AOP 不适合业务状态机

“TRIAGED 才能 ASSIGNED”“技师属于 team”“expectedVersion 命中”必须在领域/应用代码显式表达。切点字符串无法成为可导航业务模型。

AOP 适合横切技术政策，不适合让业务行为只在运行时隐形出现。

## 47. FactoryCare 计时案例

给应用用例接口标注 TimedOperation，记录 `AssignWorkOrder` 的整体同步耗时和 success/conflict/failure 分类。Advice 不读取或修改工单状态。

它原样返回 AssignResult，原样抛 VersionConflict；核心审计仍由应用服务显式调用 AuditAppendPort。

## 48. FactoryCare 反例

一个 `@Around("assign methods")` 自动把任何工单设为 ASSIGNED，会绕过授权、聚合、事务和版本条件。切点改名还可能让规则消失。

横切代码永远不应承担唯一业务事实写入。

## 49. 诊断第一步：拿到实际 Bean

确认调用者注入的是 Spring context 中的 Bean，而不是 new 出来的 target。打印脱敏的 bean class，并用 `AopUtils.isAopProxy` 判断。

不要通过调用 `getClass()==Service.class` 作为正常性断言；代理类型本来就可能不同。

## 50. 诊断第二步：识别代理类型

`AopUtils.isJdkDynamicProxy(bean)` 与 `isCglibProxy(bean)` 区分两类，再检查接口暴露、final/private 与注入类型。

JDK proxy 的类名形态、CGLIB 生成名可作线索，但公共工具判断更稳定。

## 51. 诊断第三步：检查 Advisor

若对象实现 `Advised`，测试/诊断环境可查看 advisors 和 pointcut，确认目标 Advice 是否进链。生产不要随意暴露或修改链。

Advice 在链中但计数为零，继续检查方法匹配与调用路径；根本不在链则查 Bean 注册/auto proxy 配置。

## 52. 诊断第四步：匹配与调用路径

用 pointcut 的 `matches(method,targetClass)` 验证方法，再画 client→proxy→target→this 的路径。外部 inner 成功、outer 内 inner 失败几乎直接指向 self-invocation。

注解 retention 错、写在未被解析的位置或方法不可覆盖，是其他常见原因。

## 53. 典型故障：final/private 不生效

注解可从反射看到，但 class proxy 无法 override。修复不是扩大切点，而是把边界移动到可代理的 public 方法/协作 Bean，或按接口代理。

实验同时保留“注解存在”和“Advice 未执行”断言，证明失败层在代理可达性。

## 54. 典型故障：Advice 吞异常

Around catch RuntimeException 后返回 fallback，调用者以为成功，事务也可能提交。这是横切代码改变业务语义。

starter 练习以 `EXPECTED_EXCEPTION_PROPAGATION` 唯一红灯定位；答案在 finally 记录并让异常继续传播。

## 55. 典型故障：漏 proceed

Around 只记录日志后 return null，目标副作用和结果完全没有发生。编译仍成功，只有行为测试能发现。

透明 Advice 测试同时检查 target invocation count=1、返回 identity 与异常 identity。

## 56. 测试矩阵

匹配 public 外部调用记录一次；不匹配方法记录零次；返回值完全一致；异常完全传播；self-invocation 内层不增加次数；外部调用同一内层会增加。

另测 JDK/CGLIB 类型、CGLIB final 不拦截、private 不可作为外部 join point，以及多个 Advisor 的声明顺序。

## 57. 工件边界

配套资产直接使用 Spring Framework 7 的 ProxyFactory、pointcut、advisor 与 AopUtils，不靠自制假代理。确定性时钟避免 sleep。

它不启动完整 Boot Web 应用、不测 AspectJ weaving、异步 Publisher、Micrometer exporter 或生产代理开销。

## 58. 120 秒口述模板

先定义 pointcut 选方法、advice 做横切、proxy 包 target；再说 JDK proxy 面向接口、CGLIB 面向可继承类。解释外部调用经 proxy，`this.inner()` 直接 target 所以绕过。

最后给 final/private 或吞异常反例，并说优先拆协作 Bean、用 AopUtils/Advisor/调用路径诊断，而不是盲目改切点。

## 59. 本章边界

本章不教授 AspectJ 编译/加载期 weaving、不设计生产 tracing/metric 系统、不实现安全授权、不用 AOP 隐藏领域规则，也不做性能结论。

工件只证明 Spring AOP 代理语义、透明计时和典型失效边界。

## 60. 官方主来源

- [Spring Framework 7.0.8：AOP Concepts](https://docs.spring.io/spring-framework/reference/core/aop/introduction-defn.html)
- [Spring Framework 7.0.8：Proxying Mechanisms](https://docs.spring.io/spring-framework/reference/core/aop/proxying.html)
- [Spring Framework 7.0.8：Advice API](https://docs.spring.io/spring-framework/reference/core/aop-api/advice.html)
- [Spring Framework 7.0.8：Declaring an Aspect](https://docs.spring.io/spring-framework/reference/core/aop/ataspectj/at-aspectj.html)
- [Spring Framework 7.0.8：Pointcut API](https://docs.spring.io/spring-framework/reference/core/aop-api/pointcuts.html)
- [Spring Framework 7.0.8：AopUtils API](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/aop/support/AopUtils.html)
- [Spring Framework 7：Using @Transactional](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/annotations.html)
