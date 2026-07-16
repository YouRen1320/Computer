---
schema_version: 2
edition: 2026.2-draft
id: ch.java-engineering.testing-test-doubles
title: JUnit 参数化、测试设计、测试替身与 Mockito
responsibility: 深化可维护测试和协作边界替身，不用 Mock 证明真实数据库、网络或框架集成行为
volume: '03'
order: 17
level: L2
status: drafting
path: book/volume-03-java-engineering/chapters/ch.java-engineering.testing-test-doubles.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-engineering.maven-reproducible-builds
- ch.java-oop.exceptions-failure-contracts
version_surfaces:
- jdk-25
- maven-3
- junit-6
- mockito
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释JUnit 参数化、测试设计、测试替身与 Mockito的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - java-test-design
  - java-test-doubles
  covers_topics:
  - junit.parameterized-test
  - test.fixture-boundary
  - test.behavior-vs-implementation
  - test.fake-stub-mock
  - mockito.interaction-verification
  - test.mock-boundary
  uses_capabilities:
  - java.build-testing
  - java.inheritance-polymorphism
  - foundation.verification-debug-test
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：为依赖 NotificationSender 的服务写参数化测试、手写 fake 和 Mockito stub/verify，并说明每种替身边界
  covers_topic_groups:
  - java-test-design
  - java-test-doubles
  covers_topics:
  - junit.parameterized-test
  - test.fixture-boundary
  - test.behavior-vs-implementation
  - test.fake-stub-mock
  - mockito.interaction-verification
  - test.mock-boundary
  uses_capabilities:
  - java.build-testing
  - java.inheritance-polymorphism
  - foundation.verification-debug-test
  evidence_kind: integration-artifact-and-tests
  verification_mode: framework-or-container-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入过度 verify 调用顺序、Mock 数据库当集成证明和共享 fixture 污染，重构后保留行为 oracle，并把异常定位到第一处可信证据
  covers_topic_groups:
  - java-test-design
  - java-test-doubles
  covers_topics:
  - junit.parameterized-test
  - test.fixture-boundary
  - test.behavior-vs-implementation
  - test.fake-stub-mock
  - mockito.interaction-verification
  - test.mock-boundary
  uses_capabilities:
  - java.build-testing
  - java.inheritance-polymorphism
  - foundation.verification-debug-test
  evidence_kind: integration-failure-fix-rerun
  verification_mode: integration-fault-rerun
---
# JUnit 参数化、测试设计、测试替身与 Mockito

> 本章状态为 `drafting`。正文与配套工程可用于学习和局部试运行，但“文件存在”“自动化通过”都不能替代独立讲解、现场改动和故障复现，也不会自动修改 `PROGRESS.md`。

测试不是“给方法配几行断言”，而是把一个可观察命题交给机器反复核验。一个可靠测试必须同时回答：被测对象是什么、前置世界如何建立、动作是什么、可观察结果是什么、哪些真实边界被包含、哪些协作者被替换，以及失败时哪条证据最先说明问题。只会调用 `assertEquals`，却无法解释 fixture、oracle、隔离边界和替身语义，仍然无法设计可维护的测试。

本章从零建立这套模型，并把 JUnit 6 参数化测试、手写 fake、stub、spy、mock 与 Mockito 的 `when`／`verify` 放到同一张边界图中。重点不是追求 mock 数量，也不是把每个类都“单元化”；重点是用最小但足够真实的测试组合回答风险问题。Mock 可以证明“某次可观察协作发生了”，不能证明 SQL、事务、序列化、网络协议或框架配置真的正确。

配套工程锁定 **JDK 25、Maven 3.9.16、JUnit 6.1.1 与 Mockito 5.17.0**，并以 Maven 离线模式重放。版本锁是教材的可执行表面；测试组合、fixture 边界、替身分类、行为 oracle 与证据强度是稳定核心。官方资料复核日期为 **2026-07-17**。

## 1. 完成定义：必须能解释、构建和诊断

完成本章时，至少留下五类证据：

1. 在 120 秒内解释测试金字塔只是组合启发式，不是固定比例；能按速度、真实性、隔离程度、故障定位与维护成本选择测试层级。
2. 为一个依赖 `NotificationSender` 的服务写成功、边界、重复请求与协作者失败用例；参数组合有业务理由，而不是为增加数量机械枚举。
3. 分别实现 dummy、stub、fake 与 spy，并说明 Mockito 创建的对象在某个测试里究竟承担 stub 还是 mock 的角色。
4. 注入共享可变 fixture、过度调用顺序验证和“mock 数据库冒充集成证据”三个故障，定位第一处可信失败，再用同一 oracle 重跑。
5. 对真实数据库、文件、HTTP 与框架绑定保留窄集成测试，明确纯替身测试没有覆盖哪些边界。

配套入口：

- [参数化与替身示例](../../../examples/encyclopedia/ch.java-engineering.testing-test-doubles/README.md)
- [FactoryCare 测试边界实验](../../../labs/encyclopedia/ch.java-engineering.testing-test-doubles/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.java-engineering.testing-test-doubles/README.md)

独立练习应先预测失败，再运行 starter，完成后才核对私有解析。公开材料不暴露答案路径。

## 2. 一个测试的最小执行模型

先区分五个角色：

- **SUT（system under test）**：本次真正要判断的对象，可能是函数、类、组件或完整服务。
- **fixture**：让测试开始时世界处于已知状态的全部数据与对象，包括数据库行、时钟、临时目录和替身配置。
- **collaborator**：SUT 为完成工作而调用的对象，例如仓库、通知端口、时钟与 ID 生成器。
- **stimulus**：测试施加的动作，例如调用 `createWorkOrder`、发送 HTTP 请求或提交事务。
- **oracle**：区分正确与错误的可观察规则，例如返回值、持久化状态、抛出的异常类型或一条必要通知。

测试通过只说明“这个 fixture、动作和 oracle 的组合没有发现违例”。它不说明所有输入都正确，不说明未包含的真实边界正确，也不自动说明实现没有并发、性能或安全问题。测试名称和失败信息应把命题写清楚，例如“重复来源键被拒绝且不发送通知”，比 `testCreate2` 更能帮助诊断。

Arrange–Act–Assert 是阅读结构，不是必须机械分成三段的语法。Arrange 建立最小世界，Act 通常只执行一个业务动作，Assert 检查最少但充分的外部结果。若一个测试需要多轮 Act 才表达状态机，也可以按 Given–When–Then 分阶段，但每一步仍要让读者知道哪个状态转换正在被证明。

## 3. 测试层级：金字塔是启发式，不是配额

行业常用“测试金字塔”表达两条经验：测试应有不同粒度；越靠近完整系统，通常越慢、越脆弱、定位越困难，因此数量应更少。它不是 JUnit 规范，也没有适用于所有系统的 70/20/10 法定比例。纯算法库、数据库密集服务、硬件接入系统与前端应用的风险分布不同，合理组合也不同。

可用五个维度判断一条测试放在哪里：

| 维度 | 更窄的测试 | 更宽的测试 |
| --- | --- | --- |
| 反馈速度 | 毫秒级、适合每次保存后运行 | 秒到分钟、适合提交或流水线 |
| 真实性 | 多数协作者在进程内或被替换 | 包含真实框架、协议、存储或部署 |
| 隔离 | 故障定位集中 | 多组件共同参与，定位链更长 |
| 可控制性 | 时间、异常、返回值容易注入 | 外部状态与调度更难控制 |
| 维护成本 | fixture 小，但可能过度绑定实现 | 环境重，业务信心通常更高 |

常见组合可以按“回答什么”命名，而不必争论术语：

- **领域/单元测试**：验证金额、状态转换、校验规则等进程内行为。
- **组件测试**：启动一个组件及其内部真实协作者，只替换外部端口。
- **窄集成测试**：一次验证一个真实边界，例如仓库实现与目标数据库、HTTP 客户端与协议 stub。
- **契约测试**：验证消费者与提供者对请求、响应、错误和兼容性的共同约定；stub 必须由契约反向校验。
- **端到端测试**：从公开入口穿过部署后的关键链路，证明少量高价值旅程。

“测试奖杯”等其他模型强调较多集成测试，本质仍是风险与证据的权衡。团队应记录每层的定义、触发频率、环境所有者和失败归属。名称一致比背诵图形更重要。

## 4. 边界决定测试，不是类数量决定测试

测试设计从风险问题出发：工单优先级 0 或 6 是否被拒绝？同一来源事件是否会重复建单？仓库保存后通知失败，系统如何报告？数据库唯一约束真的存在吗？HTTP 客户端能否处理 409 和超时？每个问题需要不同证据。

纯值对象、不可变集合和确定性领域规则通常适合直接使用真实对象。它们创建便宜、没有外部副作用，替换反而会丢失行为。数据库连接、网络、系统时钟、随机源、文件系统和消息发布器更可能需要边界控制，但“需要控制”不等于“永远 mock”。单元测试可替换它们；边界本身仍需真实集成测试。

一个实用原则是：**在己方可控、快速、确定的代码里尽量使用真实对象；在慢、非确定、昂贵或跨进程的边界建立端口与替身；再用少量真实边界测试校验端口实现。** 这是一种工程判断，不是 Java 语言保证。

如果类很难隔离，先观察设计：构造器是否自己读取当前时间、创建客户端、访问全局单例？业务逻辑是否与 SQL 或序列化混在一起？可测试设计通常把这些副作用放到显式接口后，通过构造器传入。不要为了 mock 任意 private/final/static 细节而不断升级技巧；有时拆分职责比更强的 mock 能力更可靠。

## 5. fixture：每个用例都应从已知世界开始

fixture 包含测试数据、SUT、替身与外部环境。好 fixture 的目标不是“复用最多”，而是让当前命题清楚并保持隔离。默认优先每个测试创建新 fixture；JUnit Jupiter 默认的 per-method 生命周期会为每个测试方法创建新的测试类实例，这有助于隔离实例字段，但 static 字段、单例、文件、数据库和外部服务仍可能共享。

常见 fixture 技法：

- 小对象直接在测试内构造，让关键值一眼可见。
- 多字段对象使用 Test Data Builder，默认值合法，测试只覆盖与命题相关的字段。
- Object Mother 可提供命名场景，例如“已超 SLA 的高优工单”，但不要形成一个隐藏几十个字段的万能工厂。
- `@BeforeEach` 只放所有测试都需要且语义稳定的准备；若读者必须跳到远处才能理解数据，宁可局部重复。
- 文件使用 `@TempDir` 或受控临时目录；测试结束由框架或显式清理负责。
- 数据库测试按事务回滚、truncate、唯一 schema 或一次性容器选择隔离策略，并验证该策略真实生效。

共享可变 fixture 是典型脆弱源。某个测试先写入 fake，另一个测试假设它为空；单独运行都通过，按另一顺序运行失败。修复不是固定 `@Order`，而是移除顺序依赖：每例新建 fake、显式清理或让 fixture 不可变。排序只适合确实在验证有序场景的测试，不是污染遮羞布。

## 6. 参数化测试：压缩重复，不压缩语义

JUnit `@ParameterizedTest` 让同一测试方法对多个参数运行，每次调用在测试树中都是独立节点。它需要至少一个参数源，例如 `@ValueSource`、`@NullSource`、`@CsvSource`、`@EnumSource` 或 `@MethodSource`。JUnit 6 还提供参数化类，但该能力的稳定性级别需以所用版本文档为准；本章只依赖成熟的参数化方法。

适合参数化的场景是“同一业务规则、同一动作、同一 oracle 形状，仅输入与期望变化”，例如优先级 1—3 走普通队列、4—5 走紧急队列；空白设备编号的多个表示都被拒绝。若不同参数触发不同协作、不同异常和完全不同断言，把它们塞进一张巨大 CSV 会让失败难懂，应拆成命名测试。

设计数据集时按边界值与等价类，而不是盲目穷举：

1. 正常代表值；
2. 最小与最大合法值；
3. 紧邻上下界的非法值；
4. null、空、空白是否语义不同；
5. 已知历史缺陷的回归值；
6. 组合约束，例如“紧急且无负责人”。

显示名应包含能定位失败的字段，但不要塞入密钥或完整个人信息。方法源返回领域记录通常比十列 CSV 更易维护。参数化测试仍需独立 fixture；参数列表不能复用同一个可变对象，否则前一次调用可能污染后一次。

## 7. 测试替身的五类角色

Gerard Meszaros 的术语经 Martin Fowler 文章广泛传播。分类按测试中的职责，而不是按创建工具：

| 角色 | 做什么 | 典型使用 |
| --- | --- | --- |
| dummy | 只为满足参数或构造器，不会被真正使用 | 当前分支不触发的通知端口 |
| stub | 为调用提供预设返回或异常 | 固定时钟、固定 ID、仓库查询结果 |
| fake | 有可工作的简化实现，但不适合生产 | 内存仓库、内存队列 |
| spy | 记录发生过的调用，之后由测试查询 | 捕获发送的通知内容 |
| mock | 预先或事后声明期望交互，并由框架验证 | 验证事务成功后发布一次事件 |

同一个 Mockito 对象可以同时被 stub 和 verify：`when(repo.exists(key)).thenReturn(false)` 是 stubbing；`verify(sender).send(...)` 是 interaction verification。把所有 Mockito 对象统称为 mock 会掩盖测试到底依赖状态还是交互。

**fake 不是“更真实的 mock”。** 它需要维护状态与不变量，能支持多个测试；也正因如此可能与生产实现漂移。内存仓库若允许生产数据库拒绝的 null、重复键或事务顺序，基于它的通过结果无法证明真实仓库。应为端口建立契约测试，把同一行为套件同时运行在 fake 与真实实现上；仍要为数据库特有约束保留集成测试。

**spy 不是 Mockito 的 partial spy 专属名词。** 一个手写通知捕获器只要记录调用供断言，就承担 spy 角色。Mockito 的 `spy(realObject)` 是包装真实对象的特定机制，可能调用真实方法并带来副作用；除非确有遗留边界，不应把 partial spy 当成默认设计。

## 8. 状态验证与交互验证

状态验证检查动作后的可观察状态：返回的工单 ID、fake 仓库中的工单、异常类型。交互验证检查协作者之间的消息：通知是否发送一次、失败时是否未发送。两者都合法，但证据强度和耦合点不同。

优先状态验证的原因是它贴近业务结果，对内部重构更稳定。例如服务从“先组装再保存”改成“由仓库返回已保存对象”，只要公开结果不变，行为测试应继续通过。若测试验证每个 getter 调用次数、对象创建顺序和私有辅助调用，重构就会无端破坏测试。

交互验证适合结果只能通过边界动作观察，或动作本身就是合同：向支付网关扣款、发布领域事件、不得发送第二次通知。此时只验证业务上重要的参数与次数。`verifyNoMoreInteractions` 不应在每个测试机械使用；Mockito 官方文档也提醒这种做法会导致过度指定。调用顺序只在顺序具有业务意义时验证，例如“持久化成功之后才发布事件”，而不是把当前实现的所有步骤冻结。

不要让 mock 只验证自己安排的脚本。若测试先 stub `repo.find`，调用 SUT 后只 verify `repo.find`，却没有检查返回、状态或真正副作用，它可能在业务结果错误时仍通过。每条测试应能说出业务 oracle，而非仅有调用清单。

## 9. Mockito 的清晰使用边界

Mockito 降低了创建 stub 与 mock 的样板成本，但不会替你选择边界。常用语义如下：

- `mock(Type.class)` 创建测试对象；未 stub 的方法返回 Mockito 默认值。
- `when(call).thenReturn(value)` 或 `thenThrow` 配置响应。
- `verify(mock)` 默认验证一次；只有业务需要时再写 `times`、`never` 或 `atLeast`。
- `ArgumentCaptor` 用于捕获无法直接返回的业务消息；若只是比较简单参数，直接 verify 更清楚。
- strict stubbing 可发现未使用配置和参数不匹配，但“严格”不等于应验证所有交互。

默认返回值是风险：未配置的布尔值可能是 false，集合或 Optional 的行为随 API/版本定义，测试可能误走另一分支。对关键查询显式 stub，并让失败信息指向业务含义。宽泛的 `any()` 会隐藏错误参数；优先精确值或领域 matcher。matcher 的目标是表达合同，不是让测试勉强通过。

不要 mock 数据载体、String、集合、record 或自己可直接构造的简单领域对象。不要 mock 被测对象本身。不要以深层 stub 复制 `a.getB().getC().call()` 链；这通常暴露对象边界过深。不要用 mock 绕过构造器不变量，然后声称生产对象合法。

Mockito 的 inline mock maker、final/static mocking 和 agent 行为属于版本敏感表面。教材工程只 mock 自有接口，避免将高级机制当作零基础前提。升级 Mockito 时应重跑整个测试集，并核对 JDK 兼容说明。

## 10. 隔离非确定性：时钟、ID、随机与并发

测试隔离不只是“不访问数据库”。当前时间、默认时区、Locale、随机数、线程调度、端口、环境变量与全局缓存都能制造非确定性。

对时间，业务代码依赖 `Clock` 或自有 TimeProvider，测试注入固定 `Instant` 与显式 `ZoneId`。不要断言“现在前后 100 毫秒”；机器负载和断点会破坏窗口。对 ID，注入生成器或只断言格式与唯一性，不把随机 UUID 写死为神秘常量。对随机策略，注入带固定种子的源仍只保证同一实现序列；更好的单元边界往往直接 stub 决策所需值。

对异步流程，不用 `Thread.sleep` 猜任务何时完成。优先返回 `Future`／`CompletionStage` 并有上限地等待，或用 latch、队列、虚拟时钟和可观察状态建立同步点。超时是防止测试永久挂起的保险，不是业务 oracle。并发正确性还需要重复压力、专用工具或系统测试，单次绿色运行不能证明无竞态。

测试应显式设置依赖的编码、Locale 与时区。若测试依赖平台换行或路径分隔，应使用平台 API 或把格式合同写清楚。不要读取开发机真实 HOME、token 或云凭据。离线测试必须在构建层禁止联网，不能只“希望代码不联网”。

## 11. 脆弱测试的主要气味

脆弱测试不是“偶尔失败”这么简单；还包括实现一重构就大面积失败、失败信息无助定位、在本机与 CI 表现不同。常见来源：

1. **过度指定交互**：验证所有调用次数与顺序，冻结实现而非行为。
2. **共享可变 fixture**：static 集合、单例缓存、同一数据库行或固定文件名互相污染。
3. **休眠等待**：依赖机器快慢和调度，既慢又不可靠。
4. **真实当前时间与随机数**：跨午夜、时区或种子导致漂移。
5. **断言无序输出的完整字符串**：HashMap 顺序、并发日志和集合迭代变化就失败。
6. **测试 private 方法**：绑定内部结构，公共行为反而缺少保护。
7. **巨型共享 setup**：每例只需其中一小部分，却都承担初始化与维护成本。
8. **吞掉异常**：catch 后不 fail，导致错误路径假绿。
9. **宽泛异常断言**：只断言 Exception，无法区分合同拒绝与空指针缺陷。
10. **环境依赖**：固定端口、真实用户名、默认编码、外网和本机缓存。
11. **只看覆盖率**：语句被执行不等于结果被正确断言。
12. **先失败就重跑**：flaky 被重试隐藏，证据不再可信。

修复时先保留业务 oracle，再替换不稳定控制方式。比如删除顺序 verify 之前，确保测试仍验证“保存成功后通知恰好一次”；拆共享 fixture 之后，随机化或多顺序重跑以证明隔离；替换 sleep 后，加入明确完成信号和超时故障信息。

## 12. Mock 不能证明真实边界

模拟 `DataSource`、`Connection` 或仓库接口，只能证明业务代码对这个模拟合同作出预期响应。它没有执行 SQL，没有触发目标数据库的类型转换、唯一约束、事务隔离、索引、连接池或迁移。把这样的测试命名为 database integration test 是证据越权。

同理：

- mock HTTP 客户端不验证 URL 编码、TLS、JSON 映射、超时和真实状态码处理；
- mock 文件接口不验证权限、原子移动、字符集与路径语义；
- mock 消息发布器不验证序列化、broker 确认、重投与顺序；
- 直接调用 Controller 方法不验证路由、参数绑定、过滤器与异常映射。

合理组合是：大量快速测试用替身覆盖业务分支；每个适配器有窄集成测试连接真实依赖或协议级测试服务；少量组件/端到端测试证明装配。若真实依赖昂贵，可在受控流水线运行，但不能删除并让 mock 冒名顶替。

## 13. 契约测试防止 fake 漂移

设 `WorkOrderRepository` 定义“按 sourceKey 唯一保存；重复时拒绝；查询不存在返回 empty”。可以编写抽象契约套件，要求提供“创建空仓库”“清理资源”的工厂，然后分别运行在内存 fake 和真实数据库实现上。相同断言能发现 fake 与生产语义分叉。

契约仍有边界。真实数据库的并发唯一冲突、事务隔离、大小写排序和时区行为可能无法由通用接口完全表达，需要实现专属测试。契约套件证明双方满足已写出的共同部分，不证明接口遗漏的性质。

外部服务的 consumer-driven contract 也不是端到端替代品。消费者 stub 应来自双方可验证的契约，而不是手写一个“永远返回理想 JSON”的对象。提供者验证通过后，仍需部署配置和网络路径证据。

## 14. JUnit 生命周期、顺序和并行

JUnit Jupiter 默认每个测试方法新建实例，`@BeforeEach`／`@AfterEach` 围绕每个用例，`@BeforeAll`／`@AfterAll` 围绕测试类。切换 `PER_CLASS` 会共享实例字段并允许非 static 的 beforeAll，但也扩大污染风险。除非有昂贵且只读的 fixture，不要仅为少写 static 就改变生命周期。

测试发现依赖类名、方法注解与构建插件配置。`BUILD SUCCESS` 加 `Tests run: 0` 不是成功证据。检查 Surefire 报告中的测试数，并在升级 JUnit 或 Surefire 后确认 Platform engine 被发现。

测试执行顺序默认不应成为合同。使用 `@TestMethodOrder` 能控制顺序，但它适合教学故障或明确序列场景，不能修复相互依赖的普通测试。并行执行会放大共享状态、端口和文件冲突；启用前先让测试在随机顺序和独立进程下稳定，再为共享资源声明隔离策略。

## 15. 失败诊断：找第一处可信证据

一条测试失败通常分四层：

1. **发现/装配失败**：测试数为零、engine 缺失、extension 初始化失败；
2. **fixture 失败**：beforeEach、容器、迁移或数据准备失败，SUT 尚未执行；
3. **动作错误**：未预期异常、超时或依赖调用失败；
4. **oracle 不满足**：expected/actual、缺少交互或出现多余交互。

先记录完整测试名、参数显示名、异常类型与第一条业务栈帧，再判断生产缺陷、测试缺陷还是环境缺陷。Mockito 的 “Wanted but not invoked” 只说明某期望交互没有观察到；原因可能是业务分支没走、参数不匹配、调用了另一个实例，或期望本身多余。不要看到框架信息就立即添加更多 `verify`。

修复过程保持单变量：重现单个测试；确认它是否单独与整套都失败；检查 fixture；保留原 oracle；修改一个边界；重跑原测试；最后运行全套和故障夹具。若只通过重试，仍未修复。

## 16. FactoryCare 设计实例

FactoryCare 创建工单的核心用例依赖三个端口：仓库检查来源键并保存；ID 生成器产生工单号；通知发送器告知报修人。领域规则要求优先级 1—5，4—5 进入紧急队列，同一来源键不能重复建单。

测试组合可以这样分层：

- 直接领域测试验证优先级边界与路由；
- 服务测试使用手写 fake 仓库、固定 ID stub、Mockito 通知对象；
- 状态断言验证返回工单与 fake 中保存的对象；
- 必要交互断言验证成功时通知一次、重复时不通知；
- 仓库适配器集成测试连接目标数据库验证唯一约束；
- 少量 API 测试验证请求绑定和错误映射。

若服务以后把“保存后通知”改为 outbox，本章的行为测试应围绕可观察合同调整，而不是坚持旧的直接调用顺序。真正需要维持的是“不丢工单、不重复通知、失败可恢复”的业务性质。

## 17. 实验顺序

### 17.1 示例：识别每个替身角色

先阅读示例 README，预测参数化测试调用次数。找出固定 ID 是 stub、内存仓库是 fake、Mockito 通知对象在成功测试里承担 mock。运行验证器后，故意把优先级边界改为 5 以上才紧急，确认哪个参数调用失败，再恢复。

### 17.2 实验：三种脆弱性

实验工程先跑正常套件，再分别运行三个预置故障：错误的调用顺序期望、共享 static fixture 污染、用内存替身声称数据库约束已被验证。每个故障都必须非零退出，验证器记录首个测试类与失败类型。学习者修复时不得删除业务 oracle。

### 17.3 独立练习

starter 提供正确 SUT 与未完成的 fake/spy。先写预测：哪些测试通过、哪条失败、失败属于 fixture 还是 oracle。完成内存保存与调用捕获，确保每例新建 fixture，再运行同一离线命令。最后比较私有解析，记录不同设计选择，不复制完即算掌握。

## 18. 反例矩阵

| 现象 | 越权结论 | 第一处应查证据 | 修复方向 |
| --- | --- | --- | --- |
| mock 仓库测试通过 | SQL 与事务正确 | 是否启动目标数据库 | 增加适配器集成测试 |
| 单独通过、整套失败 | JUnit 随机坏了 | static、文件、端口、数据库行 | 每例新 fixture 或资源隔离 |
| 重构后大量 verify 失败 | 业务一定回归 | 公开状态与业务副作用是否变 | 删除非合同交互 |
| 参数化 20 行 CSV 难读 | 覆盖很全面 | 每行是否同一规则和 oracle | 按行为拆组并命名 |
| sleep 后偶尔失败 | 等久一点即可 | 是否有完成信号 | future/latch/虚拟时钟 |
| Tests run: 0 且构建绿 | 测试全通过 | engine 与发现规则 | 修正依赖/命名并断言测试数 |
| fake 接受非法数据 | 生产也会接受 | 真实约束与契约套件 | 对齐 fake，再跑真实实现 |
| 捕获 Exception 即通过 | 错误路径已覆盖 | 实际异常类型与消息合同 | assertThrows 精确类型 |

## 19. 120 秒口述模板

可以按以下顺序组织，不必逐字背诵：

1. 测试由 SUT、fixture、动作和 oracle 组成，绿色只覆盖已包含边界。
2. 金字塔建议多种粒度与较少高层测试，但比例按风险决定。
3. dummy 只占位，stub 给预设响应，fake 是简化可工作实现，spy 记录调用，mock 验证期望交互。
4. 优先验证可观察行为；只有协作本身属于合同时才 verify，顺序只有业务相关才固定。
5. Mock 数据库没有执行 SQL，因此必须有真实边界测试；fake 还需契约套件防漂移。
6. 反例：static fake 让测试依赖顺序，单独绿、整套红；修复为每例新 fixture，而非加 `@Order`。

## 20. 提交前清单

### 测试设计

- 测试名描述行为和条件，而不是方法编号；
- 每条测试有明确业务 oracle；
- 成功、边界、非法输入与重要失败路径均有代表；
- 参数化数据来自等价类/边界，而非凑数量；
- 高层测试数量少但覆盖关键真实装配。

### fixture 与隔离

- 默认每例创建新对象；
- 不共享可变 static、固定文件、端口和数据库行；
- 时间、时区、Locale、随机和 ID 显式控制；
- 异步等待使用完成信号与上限；
- 外网、个人目录和真实凭据不进入测试。

### 替身

- 能给每个替身准确命名其当前角色；
- 真实值对象不被无意义 mock；
- fake 有契约测试并记录未模拟性质；
- verify 只覆盖业务重要交互；
- 未用 stub、宽泛 matcher 和深层 stub 被清理。

### 证据

- Surefire 报告测试数非零；
- 预置故障确实失败且原因可辨；
- 修复后重跑同一命令与全套；
- 真实数据库/网络/框架未运行时明确写“未验证”；
- 不用覆盖率百分比替代 oracle 质量。

## 21. 版本边界与官方资料

JUnit 参数化测试的参数顺序、参数源与生命周期规则以所锁 JUnit 6 文档为准；Maven Surefire 负责在 `test` 阶段通过 JUnit Platform 发现并执行测试；Mockito 的默认答案、strictness、mock maker 与 JDK 支持会随版本变化。升级任一项都应固定版本、离线预热、检查测试发现数并重跑负向夹具。

资料入口：

- [JUnit 6 User Guide：Parameterized Classes and Tests](https://docs.junit.org/6.0.3/writing-tests/parameterized-classes-and-tests.html)
- [JUnit User Guide：Test Instance Lifecycle](https://docs.junit.org/6.0.3/writing-tests/test-instance-lifecycle.html)
- [Mockito 5 Javadoc](https://javadoc.io/doc/org.mockito/mockito-core/latest/org.mockito/org/mockito/Mockito.html)
- [Maven Surefire：Using JUnit Platform](https://maven.apache.org/surefire/maven-surefire-plugin/examples/junit-platform.html)
- [Martin Fowler：The Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)
- [Martin Fowler：Mocks Aren't Stubs](https://martinfowler.com/articles/mocksArentStubs.html)
- [Martin Fowler：Test Double](https://martinfowler.com/bliki/TestDouble.html)

前三项与 Maven 文档用于校正规范/工具行为；测试金字塔、替身术语与“优先状态验证”等属于行业方法和作者经验，应结合项目证据决策。

## 22. 明确不做

本章不以 mock 证明真实数据库、网络、容器或框架集成；不追求固定覆盖率 KPI；不展开 Testcontainers、Spring 测试切片、契约平台、UI 自动化、变异测试与并发压力工具；不把测试通过自动记为 G1 通过。它只建立可维护测试设计、替身边界、JUnit 参数化与 Mockito 基础交互证据。更宽的工程验收必须在后续对应章节和真实环境完成。
