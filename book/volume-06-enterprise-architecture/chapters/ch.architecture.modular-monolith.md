---
schema_version: 2
edition: 2026.2-draft
id: ch.architecture.modular-monolith
title: 模块化单体、结构测试与拆分信号
responsibility: 教授在单一部署中保持业务模块边界和依赖方向，不因模块命名就声称已成为微服务
volume: '06'
order: 18
level: L2+
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.architecture.modular-monolith.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.distributed.messaging-delivery
version_surfaces:
- spring-boot-4.1
- spring-modulith
- testcontainers
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释模块化单体、结构测试与拆分信号的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - architecture-module-boundary
  - architecture-module-evolution
  covers_topics:
  - architecture.business-module
  - architecture.module-api-internal
  - architecture.dependency-rule
  - architecture.structure-test
  - architecture.modulith-event
  - architecture.service-split-signal
  uses_capabilities:
  - architecture.domain-invariants
  - architecture.events-outbox
  - backend.spring-di-config
  - backend.spring-persistence-tx
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：把 users/devices/workorders 分成公开 API 与 internal 包，用结构测试禁止反向依赖并通过模块事件协作
  covers_topic_groups:
  - architecture-module-boundary
  - architecture-module-evolution
  covers_topics:
  - architecture.business-module
  - architecture.module-api-internal
  - architecture.dependency-rule
  - architecture.structure-test
  - architecture.modulith-event
  - architecture.service-split-signal
  uses_capabilities:
  - architecture.domain-invariants
  - architecture.events-outbox
  - backend.spring-di-config
  - backend.spring-persistence-tx
  evidence_kind: integration-artifact-and-tests
  verification_mode: framework-or-container-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入跨模块直接访问 Repository、循环依赖和共享实体对象，运行结构测试后改为端口/事件
  covers_topic_groups:
  - architecture-module-boundary
  - architecture-module-evolution
  covers_topics:
  - architecture.business-module
  - architecture.module-api-internal
  - architecture.dependency-rule
  - architecture.structure-test
  - architecture.modulith-event
  - architecture.service-split-signal
  uses_capabilities:
  - architecture.domain-invariants
  - architecture.events-outbox
  - backend.spring-di-config
  - backend.spring-persistence-tx
  evidence_kind: integration-failure-fix-rerun
  verification_mode: integration-fault-rerun
---
# 模块化单体、结构测试与拆分信号

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《RabbitMQ、投递语义、重试、死信与幂等消费》](ch.distributed.messaging-delivery.md)：独立完成模块边界、结构验证与拆分前，必须先具备「RabbitMQ、投递语义、重试、死信与幂等消费」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套资产以 JDK 25 离线依赖图和公开/internal 类型模型证明无环、允许依赖、内部包隔离、端口/事件协作及证据化拆分判断；它不启动 Spring Boot、Spring Modulith、PostgreSQL 或 Testcontainers，不能替代 `ApplicationModules.verify()`、`@ApplicationModuleTest`、真实 bean/事务和模块事件集成证据。

单体只描述一个部署单元，并不说明代码是否混乱；模块只描述逻辑边界，也不说明它是否独立部署。模块化单体把多个业务能力组织在一个 Spring Boot 进程和部署物中，用公开 API、internal 包、单向依赖、结构测试与事件保持边界。它保留本地调用、同库事务和简单运维的优势，同时为未来可能的服务拆分准备接缝。目录叫 `modules`、类名带 `Service` 或使用消息事件，都不能把一个部署物自动变成微服务。

## 1. 完成定义、证据入口与非目标

完成本章后，应能：

1. 区分普通分层单体、模块化单体、Maven 多模块与微服务；
2. 依据业务语言、规则和数据所有权划分 vertical business module；
3. 为每个模块定义公开应用端口/事件与 internal 实现；
4. 声明允许依赖并保持有向无环，拒绝“互相注入就能工作”；
5. 禁止跨模块 Repository、internal 包、表实体和可变对象共享；
6. 选择同步端口或事务后事件，并解释一致性与失败边界；
7. 使用 Spring Modulith 结构验证和模块级集成测试固定边界；
8. 让模块可以独立启动/测试其公开用例，外部依赖可由受控端口替身；
9. 用团队、数据、伸缩、发布、合规与故障隔离证据判断拆分，而不是数目录；
10. 给真实拆服务提供迁移、回填、双读核对和回滚路由。

配套入口：

- [模块边界与依赖图示例](../../../examples/encyclopedia/ch.architecture.modular-monolith/README.md)
- [内部访问、循环与共享实体故障实验](../../../labs/encyclopedia/ch.architecture.modular-monolith/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.architecture.modular-monolith/README.md)

本章不实施微服务迁移，不把每个 package 变成独立 JAR，不引入 Kubernetes/服务网格，也不保证 Spring Modulith 自动设计正确领域。FactoryCare 仍是一个 Java 部署物，Python AI 因运行时/依赖/伸缩特征已经是明确的独立进程。

## 2. 四个常被混淆的结构

**普通分层单体**常按 `controller/service/repository/entity` 分顶层包。所有业务的 service 同处一层，依赖很容易横穿；修改工单规则时要在多个技术层寻找。它仍可维护，但技术分层本身没有表达业务所有权。

**模块化单体**先按 `workorder/asset/knowledge` 等业务能力垂直切片，每片内部再有 API、application、domain、infrastructure。模块通过受控端口/事件协作，仍共同编译、启动、部署，通常共享同一 PostgreSQL 实例。

**Maven/Gradle 多模块**是构建边界，可帮助依赖隔离与增量构建，但不是业务模块的必要条件。一个 Maven module 可以混入五个业务领域；一个单 Maven module 也能用 package + Spring Modulith 建立清晰边界。不要把构建术语当部署/领域术语。

**微服务**独立进程、独立部署与运行故障边界，理想上拥有独立数据。调用跨网络，需要契约、认证、超时、重试、可观测和分布式一致性。把同一数据库上的三个 Spring Boot 进程称为微服务只增加网络成本，并没有真正数据自治。

## 3. 为什么当前 FactoryCare 选择模块化单体

项目由一名学习者完成，没有九个独立团队、独立伸缩、法规隔离或不同发布节奏证据。一个 Spring Boot 部署让状态转换、核心审计、outbox 和幂等结果可用同一 PostgreSQL 事务，开发、调试、部署与恢复更可控。

普通分层单体的长期风险是 Repository/实体互相穿透；立即微服务的风险是契约、消息、网关、部署、追踪和数据迁移压垮业务主线。模块化单体在两者之间：现在用结构测试守边界，将来若证据出现，可沿公开端口和版本化事件拆出低一致性耦合模块。

这一选择不是“系统永远小”。它明确承认单进程故障域和共同发布成本，并用观测数据决定何时演进。ADR-0001 是当前基线，不能因为本章学了 RabbitMQ 就悄悄改成微服务。

## 4. 业务模块不是表、页面或技术层

业务模块拥有一组连贯语言、规则、用例和数据写责任。例如 `workorder` 拥有十二状态机、assignment、transition、审批与关闭 guard；`asset` 拥有设备/型号/位置事实；`organization` 拥有租户、组织、team、membership 与数据范围。

一个模块不必等于一张表，也不等于一个 UI 菜单。工单模块可能拥有多表，设备页面可能组合 asset、organization 和 reporting 的公开查询。若按每张表建模块，会产生大量贫血 CRUD 和循环依赖；若按前端页面建模块，同一规则会被复制到多个页面模块。

划分问题可问：谁决定不变量？谁能写这些数据？哪些词在该上下文有特定含义？哪些变化应在同一事务？哪些消费者只需已发生事实？答案比“包有多少类”更可靠。

## 5. FactoryCare 九个业务模块

固定模块为：`identity`、`organization`、`asset`、`workorder`、`knowledge`、`engagement`、`reporting`、`audit`、`ai-integration`。不能新增第十个 `maintenance` 或 `shared` 业务模块来收纳暂时不知道放哪的代码。

`shared-infrastructure` 是 outbox/idempotency 等技术能力，经 `OutboxPort/IdempotencyPort` 提供适配，不定义领域规则，不算第十个业务模块。通用数据库 helper、时间/ID 接口等共享内核必须稳定且极小；一旦承载业务 DTO 或 Repository，就会变成无主领域。

`identity` 不依赖业务模块；`organization` 提供可信范围；`workorder` 可经公开接口引用 asset/organization；`audit` 只公开追加端口；`knowledge`、`engagement`、`reporting` 多在事务后消费事件；`ai-integration` 是 Java/Python 唯一适配层，不拥有工单规则。

## 6. Java 包如何形成模块 API 与 internal

Spring Modulith 默认把应用主包直接下的包识别为应用模块。模块 base package 被视为 API；其子包默认是 internal。例如：

```text
com.factorycare.workorder
  WorkOrderUseCases.java       # 公开应用端口
  WorkOrderSummary.java        # 最小公开 DTO
  WorkOrderClosed.java         # 受治理事件
  internal/
    CloseWorkOrderService.java
    WorkOrder.java
    WorkOrderRepository.java
    persistence/
```

Java 的 `public` 只表示语言可见，并不表示模块 API。internal 中某个 Spring bean 为注入而必须 public，结构测试仍应禁止其他模块引用它。反过来，base package 中每个 public 类型会被视作潜在 API，所以根包要小，避免把实现类顺手放进去。

需要暴露额外子包时，用 named interface 显式声明。不要把整个模块设置为 open 作为永久逃生口；官方文档将 open module 主要定位为旧系统渐进迁移，完整模块化应用中通常意味着结构仍需改进。

## 7. 公开 API 要表达用例，不泄漏存储

公开端口可为 `AssetLookup`、`OrganizationScopePort`、`AuditAppendPort`、`CloseWorkOrderUseCase`。参数/返回使用稳定 ID、值类型、不可变 DTO 或版本化事件。不要暴露 `JpaRepository`、MyBatis mapper、数据库 entity、事务 session 或可变 aggregate。

若 workorder 直接调用 `assetRepository.findById()`，它知道 asset 表/实体和加载策略；asset 改 schema 会迫使 workorder 改，且容易漏 tenant。改为 `AssetReferencePort.requireAccessible(tenant,assetId)`，由 asset 模块拥有查询/授权语义。调用方只依赖所需合同。

API 不是越抽象越好。为一个简单只读查询发明十层 generic port 会隐藏业务。好的端口名称来自用例语言、输入最小、错误明确、所有权唯一，并有消费者契约测试。

## 8. Internal 的价值是允许模块内部自由演进

其他模块若只见公开端口，workorder 可把 MyBatis mapper 换实现、重构 aggregate 或拆 application/domain 包而不波及全仓。internal 不是“秘密代码”，而是变更影响范围承诺。

访问 internal 的常见借口是“同一个进程，直接调更快”。方法调用性能差异通常可忽略，真正代价是依赖方向和数据所有权被破坏。另一个借口是“测试需要”；测试应通过公开 API 或位于模块测试包，不能让生产 API 为白盒测试泄漏实现。

反射、component scan 或 bean name lookup 也可能绕开编译依赖。结构测试能发现静态类型引用，但动态查找还需代码审查/运行测试。不要把依赖注入容器当服务定位器。

## 9. Allowed dependencies 与无环图

模块依赖应是有向图。`workorder -> organization` 表示 workorder 调用 organization 的公开 API；这不授权 organization 反向调用 workorder internal。若双向业务需求出现，应重画所有权：提取稳定协议、由上层 orchestration 协调，或让一方向另一方发布事件。

Spring Modulith `@ApplicationModule(allowedDependencies=...)` 可在 `package-info.java` 或模块元数据类型中声明允许列表；空数组表示不允许依赖其他模块，未显式配置则不会自动限制到某个白名单。named interface 用 `module :: interface` 形式精确引用。实际语法随选定版本核对。

依赖无环不等于设计自动正确：A 可以合法依赖 B 的巨大 API，形成高耦合；所有模块也可依赖一个“common”。结构验证是下限，仍需评估 API 大小、变更频率、事务与数据所有权。

## 10. 循环依赖为何不是简单 bean 问题

`workorder -> engagement -> workorder` 表示两边都需要知道对方内部时机，无法独立理解、测试或拆分。Spring 启动时报循环 bean 只是较早症状；用 `@Lazy`、setter injection 或允许 circular references 会隐藏架构循环，并没有移除业务耦合。

常见修复是 workorder 完成状态变更后发布事实，engagement 异步消费；engagement 不回调改变工单核心状态。若需要同步判断，应把规则归还真正拥有者或建立单向查询端口。不是所有循环都用事件：把必须同事务的 guard 改成最终一致，会破坏不变量。

画模块级边而非类级箭头。若为了修一条边新增 `shared-service` 让双方都依赖，往往只是把循环藏起来。

## 11. 同步端口还是模块事件

同步调用适合调用方必须在当前事务得到答案或维持不变量，例如 workorder 需要确认 asset 与 organization 范围、核心命令必须经 AuditAppendPort 同事务追加审计。失败应阻止提交，调用关系明确单向。

模块事件适合事实提交后多个派生反应：关单后生成知识草稿、更新 reporting、创建通知意图。生产模块不需要知道所有消费者，消费者失败不回滚核心事实。代价是最终一致、重复、版本、重试、积压和可观测。

一个危险规则是“跨模块一律事件化”。权限/状态 guard 若异步，可能先提交非法状态。另一个危险规则是“同进程一律直接调用”，会让低优先级消费者加入核心事务。选择依据是一致性需求，不是工具偏好。

## 12. Spring Modulith 事件与 FactoryCare Outbox 的关系

Spring Modulith 支持模块 application event、transactional listener 和持久 Event Publication Registry。官方文档说明 registry 可在原业务事务记录 listener publication，失败保留以便重提；2.0 还引入 publication lifecycle/staleness。它能帮助模块内可靠事件协作，但具体版本、持久化 starter、序列化与恢复策略都要集成验证。

FactoryCare 已有自己的受治理 `outbox_event`、事件目录与 `OutboxPort`，用于跨模块/跨进程集成事实。不要同时启用两套持久 publication 后让同一消费者执行两次而无人负责。可选择让 Spring Modulith 验证结构/模块测试，事件可靠性仍走项目 outbox；或经过显式 ADR 将特定 listener 纳入 registry，并定义与外部 outbox 的映射。

官方 2.1 文档还明确提醒原生异步 broker externalization 缺少真实 outbox 期望的某些关键特性，并提供其他集成选项。课程不能因为 `@Externalized` 存在就宣称端到端可靠。项目合同优先，框架是实现工具。

## 13. 模块化单体中的事务边界

共享一个 PostgreSQL 使必要的跨模块本地事务可行，但不能把它变成随意跨表写。调用发起模块的应用服务拥有事务，其他模块通过公开端口参与；所有 mapper 使用同一 DataSource/transaction manager，异常向上传播。

FactoryCare 的核心审计是刻意例外：workorder 状态变化与 audit append/outbox 同事务，审计失败整体回滚。这是安全不变量，不代表 workorder 可直接 insert audit 表。端口保留 ownership，数据库事务保留原子性。

reporting/engagement/knowledge 派生不加入关单事务；它们消费已提交事件。若 reporting 故障不能关闭工单，说明它本就不该同步。模块边界与事务边界相关但不完全相同：一个事务可通过端口跨两模块，一个事件可在提交后跨边界。

## 14. 数据所有权：共享数据库不等于共享表

每张业务表有唯一写模块。其他模块通过公开 API、只读投影或事件获取所需事实。数据库用户可能技术上能访问所有 schema，结构/代码/测试仍要禁止跨模块 mapper；更严格时可用 schema/权限加强，但不要先制造复杂部署再无代码边界。

共享 entity 是最隐蔽的耦合。例如 workorder 与 asset 同时持有/修改 `AssetEntity`，谁负责 tenant guard、version 和字段语义不清。公开 `AssetId`、`AssetReference` 或最小摘要；实体只在 asset internal。

复制不是总坏事。reporting 保存由事件构建的读模型，knowledge 草稿保存关单事实快照，各自可最终一致/重建。复制必须标明权威来源与恢复策略，不能双写两边都声称真相。

## 15. 结构测试证明什么

Spring Modulith 的 `ApplicationModules.of(Application.class).verify()` 官方验证至少包括：模块级无环、外部只能访问模块 API、若配置则只允许声明依赖。失败会抛异常；应作为 CI 快速测试，而不是偶尔生成一张图。

结构测试证明静态依赖模型符合规则，不证明业务不变量、数据库 tenant 条件、事务原子、事件消费幂等或运行性能。反过来，所有业务测试绿也不证明没有一条未执行路径引用 internal。二者互补。

负向结构测试要可定位：故意让 `users` 直接引用 `devices.internal.DeviceRepository`，期待错误包含来源模块、目标 internal 类型和违反规则。若测试只断言“抛任意异常”，Spring 配置错误也可能误通过。

## 16. 模块级集成测试

`@ApplicationModuleTest` 默认以 STANDALONE 启动当前模块，还可选择 DIRECT_DEPENDENCIES 或 ALL_DEPENDENCIES。若当前模块必须拉起大量其他模块/beans 才能测试，这是高耦合信号；可以用公开端口替身，但不能 mock 掉本模块自己的核心规则。

模块测试覆盖公开用例、Spring DI、transactional listener 和模块事件；真实 SQL/事务需要 Testcontainers PostgreSQL。外部模块的 port 可用受控 fake/mock，断言输入与失败映射。不要把全应用 `@SpringBootTest` 唯一绿灯称为模块可独立测试。

独立测试不等于独立部署。它证明模块有清晰入口、依赖和环境切片，为未来演进降低风险。

## 17. FactoryCare 依赖方向实例

`workorder` 同步依赖 `organization` 的 scope/team port 与 `asset` 的引用查询，依赖 `audit` 的追加端口和 shared-infrastructure 的 outbox/idempotency port。`organization`/`asset` 不反向依赖 workorder。关单后 knowledge/reporting/engagement 通过版本化事件反应。

`ai-integration` 调 Python 并对返回 schema/超时/fallback 负责；Python 只回调 ai-integration 暴露的受控只读工具，Java 每次重新授权。业务模块不能直接导入 Python client 并绕过边界。

`identity` 提供全局只读 role/permission catalog 与操作者身份，不知道工单/知识规则。`organization` 绑定 membership/role 和数据范围。若把所有授权逻辑塞进 identity，就会产生 identity 依赖每个业务模块的循环。

## 18. 独立构建任务的三模块缩影

canonical 任务使用 `users/devices/workorders` 三个教学模块，目的是用最小图练习 API/internal、允许依赖和事件。它不改 FactoryCare 正式九模块命名；可将 users 映射为身份/组织能力缩影、devices 映射 asset、workorders 映射 workorder。

每个模块根包只放 public port/DTO/event，internal 放 aggregate/repository/service。允许边：workorders -> users API、workorders -> devices API；users/devices 不依赖 workorders。工单创建/关闭后发布模块事实，由一个 reporting test listener 消费，不让 producer 直接注入 listener。

结构测试断言模块集合、允许边、无环、无 internal 访问。模块集成测试单独启动 workorders 加 direct dependencies，替换外部端口并验证事件。随后注入 direct repository、反向 call 和 shared mutable entity，证明原测试稳定失败并用 port/event/DTO 修复。

## 19. 常见反模式与修复

**顶层 `service/repository/entity`。** 业务所有权消失；改为业务模块垂直切片，内部仍可分层。

**`common` 万能包。** 所有模块互相通过 shared DTO/entity；把类型归还 owner，只有稳定 ID/技术值类型进入最小 shared kernel。

**跨模块 Repository。** 调用方绕过规则/tenant；改为 owner 的应用端口或受控查询接口。

**双向 Spring bean 注入。** `@Lazy` 让应用启动但循环仍在；重分配规则或改事务后事件。

**共享可变 entity。** 两模块都能改同一对象；改不可变 DTO/ID，写操作回 owner。

**事件当远程方法返回。** 发布后马上等待消费者结果，既同步又不透明；需要答案就用同步端口，需要派生就接受最终一致。

**“每模块一个 schema 所以是微服务”。** 若同进程/同部署/跨 schema join 和共同发布，仍是模块化单体；诚实描述。

**框架注解代替合同。** 标 `@ApplicationModule` 却没有 verify/negative test；把结构验证放 CI，并审查 API 面。

## 20. 故障注入矩阵

| 注入 | 错误 oracle | 修复 | 原验证 |
| --- | --- | --- | --- |
| workorders 引 devices.internal.Repository | INTERNAL_ACCESS | 公开 DeviceLookup port | verify 无 violation |
| devices 反向依赖 workorders | MODULE_CYCLE | 事件或上层协调 | 图无环 |
| 共享 DeviceEntity | SHARED_MUTABLE_ENTITY | ID/不可变 DTO | owner 唯一 |
| allowedDependencies 漏边 | UNDECLARED_DEPENDENCY | 明确白名单/删边 | 边集合相等 |
| listener 加入核心事务 | DERIVED_FAILURE_ROLLS_BACK_CORE | after-commit/outbox | 核心提交独立 |
| guard 改异步 | INVALID_STATE_COMMITTED | 同步 owner/port | 非法状态拒绝 |
| common 包持有业务 service | HIDDEN_BUSINESS_MODULE | 归属明确 | shared 仅技术类型 |
| 全应用测试替代模块测试 | MODULE_NOT_ISOLATABLE | module slice/port fake | standalone 启动 |

实验先跑安全图，再一次启用一个 fault，输出首个可信 violation。修复后重跑同一规则。若循环注入仍通过，说明测试只看类存在而没有真正遍历依赖图。

## 21. 失败诊断剧本

**`ApplicationModules.verify()` 报 internal access。** 从来源类型到目标类型追一条最短边，确认调用真正需要什么业务能力。不要把目标类搬到根包消音；先设计最小 port/DTO，目标 module 实现。

**报 module cycle。** 输出模块级路径 A -> B -> A，逐边标记同步不变量还是派生反应。将派生边改事件，或把共享规则归入唯一 owner/上层 orchestration。禁止用 `@Lazy` 当架构修复。

**模块测试启动拉起全应用。** 查当前 bean 构造参数是否引用多模块实现、配置是否扫描过宽、bootstrap mode 是否被改为 ALL。只 mock 真正的外部 module port；若依赖数量持续增加，回看边界。

**改 asset entity 导致 workorder 编译失败。** 这是实体泄漏证据。引入 asset-owned API 与稳定 DTO，迁移调用，再把 entity internal；不要复制一份同名 entity 继续双写。

**事件消费者失败回滚关单。** 查 listener phase/同步 application event 和事务传播。派生动作应通过提交后/持久 outbox；核心审计保留同步端口。用故障注入证明 knowledge failure 不影响 CLOSED。

**所有结构测试绿但运行越权。** 结构测试不验证 tenant/授权。检查 owner 公开端口的可信 TenantContext、SQL tenant 条件和安全集成测试，不要扩展结构工具去假装解决数据隔离。

## 22. 什么才是拆服务信号

可信信号包括：稳定独立团队对模块全生命周期负责；数据所有权清晰且需要法规/地域隔离；负载曲线显著不同并可独立伸缩节约成本；发布频率冲突造成持续等待；单进程故障影响不可接受；技术/runtime 明确不同；模块 API/事件已稳定且跨边界调用可观测。

弱信号包括：目录类很多、开发者“喜欢微服务”、简历需要关键词、某个方法很慢、想换数据库、团队暂时有两个人。方法慢先 profile；目录多先治理模块；这些不支付网络与运维成本。

评估要量化：变更耦合率、跨模块调用/事务、部署失败来源、CPU/内存曲线、队列/SLO、团队 owner、数据迁移量、合规要求和回滚可行性。若候选模块仍每次请求同步调用六个模块并共享表，拆出只会成为分布式单体。

FactoryCare 最可能先评估低一致性耦合的 engagement/reporting，而不是核心 workorder/audit 事务。但“最可能”是架构判断，不是已确认迁移；必须等真实证据。

## 23. 拆分迁移与回滚

先稳定公开端口/事件和消费者幂等；建立目标服务独立数据模型；设计历史回填、增量捕获、校验和隐私/权限；在兼容窗口双读或 shadow compare，写路径保持唯一 owner；灰度路由并观察；最后才删除旧实现。

不要长期双写两个数据库且没有一致性协议。优先 outbox 传播和目标幂等，保留 source of truth。回滚要求旧模块仍能接流量、迁出期间数据可回灌/核对、事件版本兼容、DNS/route 切换可逆。删除旧表/API 是最后的破坏动作。

拆出服务后，本地事务变至少一次/补偿，失败和延迟成为正常路径，安全身份必须跨网络传递并重验。迁移计划若没写这些，成本评估不完整。

## 24. 观测与维护

模块层观察公开 API 调用、同步跨模块 latency/error、模块事件 publication/completion、依赖图变化和 module test 时长。不要把每个 Java method 变指标；按受控 module/use-case/eventType 聚合。

架构 fitness function 在 CI 运行，失败输出来源/目标/规则。module diagram/document 可从代码模型生成，但图不是门禁。API 面积、allowed edges、cycle、internal violation 可形成趋势；数值上升是审查信号，不是自动坏设计。

每个模块有 owner、职责、公开入口、拥有数据、发/收事件、同步依赖、事务和非目标说明。新增依赖必须解释为何同步、为何方向正确、是否扩大事务。删除边比隐藏边更有价值。

## 25. 独立验收与 T3 边界

T3 真实证据需要 Spring Boot 4.1 兼容的 Spring Modulith release train，运行 `ApplicationModules.verify()` 和 `@ApplicationModuleTest`，并保留一个负向 fixture 能稳定暴露 internal access/cycle。若模块事务依赖 PostgreSQL，使用 BOM-compatible Testcontainers 验证提交/回滚。

验收：允许依赖图无环；internal 不可跨模块访问；users/devices/workorders 可识别且 API 面最小；workorders 模块可独立测试 direct dependencies；事件 producer 不知道 listener；跨模块 Repository/shared entity fault 被定位并修复；拆分建议有证据表，目录数量不计证据。

离线资产只证明图算法/合同；不证明框架包识别、package-info、named interface、Spring bean slice、transactional event 或实际版本兼容。Spring Modulith/Testcontainers 在版本登记均 provisional，真实运行前记录版本、BOM、JDK、命令、退出码和报告。

## 26. 120 秒口述模板

可以这样讲：模块化单体是一个部署物中的多个业务模块，FactoryCare 按九个业务能力切片，共享 PostgreSQL但每张表有唯一 owner。模块 base package 是公开 API，子包 internal；同步依赖只经端口并保持无环，提交后派生用版本化事件/outbox。Spring Modulith 的 verify 检查无环、internal 访问和允许依赖，模块测试验证单模块 bean/用例，但都不替代业务、事务和安全测试。是否拆服务看独立团队、数据、伸缩、发布、合规和故障隔离证据，不看目录数。反例是 workorder 直接引用 asset Repository：它绕过 tenant/规则并让 asset schema 变化扩散；修复是 asset-owned 公开查询端口。

口述必须覆盖业务模块、API/internal、依赖规则、结构测试、模块事件、拆分信号和反例。只说“按模块建包，以后方便微服务”不能通过。

## 27. 版本边界与权威来源

本章登记 Spring Boot `4.1.x` GA；Spring Modulith 为与 Boot 4.1 兼容的 release train，provisional；Testcontainers 也为 BOM-compatible provisional。截至 2026-07-17 官方 reference 展示 Spring Modulith 2.1.0，但项目必须按官方兼容矩阵与 Boot BOM 确认，不在正文硬编码组合。模块事件 lifecycle/外部化细节可能随版本变化，真实实验以锁定版本文档为准。

- [Spring Modulith 官方总览与兼容入口](https://docs.spring.io/spring-modulith/reference/)
- [Spring Modulith：Fundamentals、API/internal 与 allowed dependencies](https://docs.spring.io/spring-modulith/reference/fundamentals.html)
- [Spring Modulith：Verifying Application Module Structure](https://docs.spring.io/spring-modulith/reference/verification.html)
- [Spring Modulith：Integration Testing Application Modules](https://docs.spring.io/spring-modulith/reference/testing.html)
- [Spring Modulith：Working with Application Events](https://docs.spring.io/spring-modulith/reference/events.html)
- [FactoryCare ADR-0001：Java 模块化单体](../../../factorycare-design/adrs/0001-modular-monolith.md)
- [FactoryCare 逻辑架构与模块依赖](../../../factorycare-design/architecture.md)
- [FactoryCare 项目规范](../../../PROJECT_SPEC.md)
- [FactoryCare 测试策略](../../../factorycare-design/testing/test-strategy.md)

## 28. 复盘清单

- 我能否区分部署、构建、业务模块和技术分层？
- 每个模块的不变量、写数据与公开用例 owner 是否唯一？
- 根包 API 是否最小，internal 是否真的无跨模块引用？
- allowed dependency 是否明确且全图无环？
- 是否存在 common 业务泥团、跨模块 Repository 或共享 entity？
- 同步调用是否因为当前事务需要答案，事件是否只承载已提交事实？
- 核心审计为何同步，reporting/engagement 为何异步？
- Spring Modulith registry 与项目 outbox 是否避免双重投递/责任冲突？
- 结构测试、模块测试、数据库事务测试分别证明什么？
- 拆分建议是否有团队/数据/伸缩/发布/隔离指标？
- 迁移是否有回填、核对、灰度和回滚，不是“大爆炸重写”？
- 我能否注入 internal access/cycle/shared entity 并定位第一条失败边？

全部问题都能指向代码、图、负向测试和项目合同，才算掌握。模块化的价值不是增加目录，而是让业务变化有明确归属、依赖可机械验证、失败边界可解释，并让“保持单体”与“未来拆分”都成为基于证据的可逆决定。
