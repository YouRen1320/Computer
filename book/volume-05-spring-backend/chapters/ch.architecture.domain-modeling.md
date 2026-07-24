---
schema_version: 2
edition: 2026.2-draft
id: ch.architecture.domain-modeling
title: 实体、值对象、聚合、不变量与边界
responsibility: 教授由领域对象维护业务不变量和一致性边界，不在本章绑定数据库表、Controller 或分布式事件
volume: '05'
order: 10
level: L2
status: drafting
path: book/volume-05-spring-backend/chapters/ch.architecture.domain-modeling.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-oop.interfaces-polymorphism
- ch.java-oop.business-value-types
version_surfaces: []
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释实体、值对象、聚合、不变量与边界的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - domain-entity-value
  - domain-aggregate-invariant
  covers_topics:
  - domain.entity-identity
  - domain.value-object
  - domain.lifecycle
  - domain.aggregate-boundary
  - domain.invariant
  - domain.command-state-transition
  uses_capabilities:
  - java.encapsulation-immutability
  - java.inheritance-polymorphism
  - architecture.domain-invariants
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：建模 WorkOrder 聚合、WorkOrderId 值对象和 assign/start/close 行为，让非法状态转换在聚合边界失败，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - domain-entity-value
  - domain-aggregate-invariant
  covers_topics:
  - domain.entity-identity
  - domain.value-object
  - domain.lifecycle
  - domain.aggregate-boundary
  - domain.invariant
  - domain.command-state-transition
  uses_capabilities:
  - java.encapsulation-immutability
  - java.inheritance-polymorphism
  - architecture.domain-invariants
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入 public setter 绕过规则、用 DTO 充当实体和跨聚合直接修改，利用不变量测试重构，并把异常定位到第一处可信证据
  covers_topic_groups:
  - domain-entity-value
  - domain-aggregate-invariant
  covers_topics:
  - domain.entity-identity
  - domain.value-object
  - domain.lifecycle
  - domain.aggregate-boundary
  - domain.invariant
  - domain.command-state-transition
  uses_capabilities:
  - java.encapsulation-immutability
  - java.inheritance-polymorphism
  - architecture.domain-invariants
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 实体、值对象、聚合、不变量与边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《接口、抽象类、多态与动态分派》](../../volume-02-java-objects/chapters/ch.java-oop.interfaces-polymorphism.md)：独立完成实体与值对象、聚合与不变量前，必须先具备「接口、抽象类、多态与动态分派」已经验证的知识与失败边界
- [《正则、BigDecimal、日期时间、UUID 与业务值》](../../volume-02-java-objects/chapters/ch.java-oop.business-value-types.md)：独立完成实体与值对象、聚合与不变量前，必须先具备「正则、BigDecimal、日期时间、UUID 与业务值」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 drafting。正文与工件提供教材证据，不自动更新 `PROGRESS.md`，也不代表学习者已经通过 G3。

领域模型不是数据库表的 Java 复印件，而是把业务词汇、身份、状态和规则变成可执行对象。FactoryCare 的 WorkOrder 聚合必须保证：创建后立即合法，只能通过有含义的命令演进，非法转换失败且不改变任何状态。

本章概念没有 Spring 版本面；配套工件使用 JDK 25、Maven 3.9.16 与 JUnit 6.1.1，只运行纯 Java。Eric Evans DDD Reference 与 JDK 25 官方文档于 2026-07-17 复核。

## 1. 本章完成证据

完成者要能区分 entity 与 value object，解释 aggregate root 为什么控制一致性边界，并实现 WorkOrderId、AssetCode、WorkOrder 聚合及 assign/start/close 等意图方法。

证据必须包含：值对象相等与非法构造、聚合合法创建、完整主路径、非法命令前后快照不变、没有 public status setter，以及 starter 红灯修复后的原测试重放。

配套工件：

- [WorkOrder 领域对象观察台](../../../examples/encyclopedia/ch.architecture.domain-modeling/README.md)
- [聚合不变量矩阵实验](../../../labs/encyclopedia/ch.architecture.domain-modeling/README.md)
- [移除通用状态 setter 练习](../../../exercises/encyclopedia/ch.architecture.domain-modeling/README.md)

## 2. 什么是领域

领域是软件要解决的现实业务范围。在 FactoryCare 中，设备报修、分诊、派单、接单、处理、验证和关闭都属于业务语言。

HTTP、JSON、SQL 和 Spring 是实现环境，不是领域本身。它们可以更换，而“工单未派单不能接单”仍然是同一条业务规则。

## 3. 什么是模型

模型是对领域的有目的简化。它只保留当前问题需要表达的概念、关系和约束，不追求复制现实世界所有细节。

好模型能让代码中的名称和行为直接回答业务问题。`workOrder.start()` 比 `setStatus(4)` 更接近人类讨论，也更容易放置前置规则。

## 4. 领域模型是可执行知识

类图或词汇表只是表达形式；真正有价值的是代码能拒绝不允许的状态。规则若只写在文档而所有字段仍可任意修改，运行时模型并没有保护它。

本章用构造器、值对象和意图方法把知识变成可重放断言。测试不是模型的替代物，而是对其公开承诺的证据。

## 5. DTO、表行与领域对象不同

DTO 描述跨边界数据形状；表行描述持久化结构；领域对象描述身份、生命周期和行为。三者可能共享字段名，但职责和演进方向不同。

把 CreateWorkOrderRequest 直接当 WorkOrder，会允许客户端提交 status、version 等内部事实；把 ORM entity 直接暴露，又会把持久化细节冻结成 API。

## 6. Entity 由身份区分

Entity 即实体：即使属性随时间改变，业务仍把它视为同一个事物。工单从 CREATED 变到 CLOSED，仍是相同 WorkOrder。

实体相等首先取决于领域身份，不取决于当前 description、status 或 assignee。必须由模型明确“同一个”是什么意思。

## 7. 身份不等于内存地址

两个从不同请求或持久化会话加载的 WorkOrder 实例，只要 WorkOrderId 相同，就代表同一领域实体。Java `==` 只能比较对象引用，不能表达该规则。

因此实体的 equals/hashCode 策略需要谨慎。未分配稳定身份的临时实体与 ORM 代理问题属于持久化设计，本章使用创建时即存在的不可变 WorkOrderId。

## 8. WorkOrderId 是值对象

WorkOrderId 包装 UUID，表达“这个值只能用作工单身份”。它阻止把 AssetId、TenantId 或任意 String 误传给工单方法。

包装不是为了多一层代码，而是为类型、验证、解析和显示建立单一入口。相同 UUID 的两个 WorkOrderId 按值相等。

## 9. Value Object 由属性区分

Value Object 没有独立生命周期身份。只要组成值相等，业务就把两个实例视为可替换。

AssetCode、Money、DateRange、Priority 都可能是值对象。它们应表达值的含义与相关操作，而不是成为只有 getter 的命名包装。

## 10. 值对象优先不可变

不可变意味着构造完成后观察到的值不再改变。操作返回新值，调用者无需追踪谁可能偷偷修改共享实例。

Eric Evans 的 DDD Reference 建议把 value object 视为 immutable，并让操作无副作用。这样 equality、缓存和组合推理更可靠。

## 11. record 适合但不保证深不可变

Java record 自动提供 final 组件字段、访问器以及基于全部组件的 equals/hashCode，适合小型值对象。

但 record 只是 shallowly immutable。组件若是可变 List，外部仍可能修改内容；需要防御性复制并返回不可变视图。

## 12. record 构造器承担不变量

紧凑构造器可拒绝 null、空白或格式错误，并做受控 normalization。官方 Record 文档明确列出参数校验、防御性复制和组件规范化是显式构造器的主要理由。

若所有调用点都先 trim 而值对象本身不验证，迟早会出现一个漏网入口。合法性应在值被创建时建立。

## 13. normalization 必须是业务决定

AssetCode 若定义为忽略首尾空白并统一大写，则 `" pump-7 "` 与 `"PUMP-7"` 可规范成相等值。该规则必须由业务确认并测试。

人名、密码、自然语言或外部大小写敏感标识不能照搬这种规范化。不要把技术便利误当领域等价关系。

## 14. equality 与 hashCode 必须一致

值对象只要 equals 为 true，hashCode 也必须相同，否则 HashSet/HashMap 会表现异常。record 的默认实现基于组件，前提是组件本身 equality 正确。

若构造时 normalization，默认 record equality 通常足够；若手写忽略大小写 equals，则必须同步设计 hashCode，复杂度明显增加。

## 15. BigDecimal 的相等陷阱

`new BigDecimal("2.0")` 与 `new BigDecimal("2.00")` compareTo 为 0，但 equals 为 false，因为 scale 不同。直接把原始 BigDecimal 放入 Money record 会让业务相等受到表示差异影响。

Money 可在构造时固定 currency 和 scale，或显式定义数值等价。选择必须与舍入规则一起测试，不能只“使用 BigDecimal 就安全”。

## 16. Value object 不是 Java value-based class 同义词

DDD value object 是领域建模分类；JDK value-based class 是 Java API 的身份使用约束。两者思想相近，却不是同一个规范术语。

例如 LocalDate 很适合嵌入领域值对象，但业务仍需决定日期代表计划日、当地工作日还是绝对时间边界。

## 17. 生命周期属于实体

Entity 从创建、变化到结束具有连续性。WorkOrderId 保持不变，status、team 和 version 随合法命令演进。

生命周期不是 CRUD 四个按钮。业务关心的是 triage、assign、accept、start、resolve、verify、close 等有含义的转换。

## 18. 不变量是什么

不变量是在对象所有可观察合法状态中都必须成立的条件。它不是“通常如此”，也不是只在保存数据库前检查一次。

示例：WorkOrder 必须有 id 和 asset；ASSIGNED 及后续主路径必须已有 team；每次合法转换 version 单调增加；非法命令不能留下半更新状态。

## 19. 创建后必须立即合法

不要先 `new WorkOrder()` 产生空壳，再依靠若干 setter 逐步填满。任何中间调用、异常或提前发布都可能暴露非法对象。

简单聚合可用静态 factory `create(id, assetCode)` 一次建立 CREATED 状态；复杂组装才考虑专用 factory，但最终仍要完整通过不变量。

## 20. 构造合法不等于永远合法

即使构造器严格，public setter 仍能在随后破坏规则。封装必须覆盖整个生命周期，而不是只保护第一刻。

字段 private 只是语言手段；真正目标是让所有改变都经过能表达业务意图和检查的入口。

## 21. Aggregate 是一致性边界

Aggregate 是一组作为单元处理的 entity 与 value object。选一个 entity 作为 aggregate root，外部只持有 root 或其他聚合的 id。

边界内规则同步保持一致；边界外协调通过应用服务、事务或事件。聚合不是“把所有相关对象塞进一棵巨大对象图”。

## 22. Aggregate root 的职责

Root 接收命令、检查前置条件、协调内部成员并保证操作结束后整体合法。外部不能拿到内部可变集合后直接修改。

WorkOrder 是本章 root。Assignment 可以是内部实体或值，但改变派单必须经过 `workOrder.assign(teamId)`，而不是 `workOrder.assignment().setTeam(...)`。

## 23. 边界来自不变量而非表关系

两张表有外键不代表必须属于同一聚合；没有物理外键也不代表没有业务关系。边界应围绕必须在同一业务操作中保持一致的规则。

把所有引用对象都纳入 WorkOrder 会导致加载巨大、锁范围过宽和高冲突。只存 TeamId 引用可让 team 成为独立聚合。

## 24. 外部只引用 root

DDD Reference 建议外部只持有 aggregate root 的引用，避免绕过 root 修改内部成员。临时读取内部值可以，但不能获得长期可变句柄。

Java 中可通过不可变快照、复制集合和窄查询方法实现。返回内部 `ArrayList` 即使字段 private 也等于暴露写入口。

## 25. 命令方法替代通用 setter

`assign(teamId)`、`start()`、`close()` 同时表达意图和合法前置；`setStatus(status)` 只表达存储动作，允许任意跳转。

命令名来自 ubiquitous language。调用者不必知道目标数值或内部字段组合，模型也有地方统一更新 version 和其他相关事实。

## 26. Query 与 command 分开理解

Query 观察状态，不产生可观察改变；command 尝试改变状态，可能成功或以领域失败拒绝。方法返回值并不能单独决定分类，关键是副作用。

`status()` 是 query；`start()` 是 command。不要让 getter 返回可变对象后由调用者完成隐藏 command。

## 27. 状态转换是有向边

合法转换应被视为图上的边，而非“目标状态属于 enum 就合法”。从 CREATED 直接 CLOSED 虽然两者都是有效枚举值，仍不是合法业务路径。

模型要检查 current + command + context。下一阶段会覆盖全部状态机、权限和 SLA；本章先证明聚合能保护主路径。

## 28. FactoryCare 唯一 12 状态

规范状态固定为 `CREATED`、`TRIAGED`、`ASSIGNED`、`ACCEPTED`、`IN_PROGRESS`、`PENDING_PARTS`、`PENDING_APPROVAL`、`RESOLVED`、`VERIFIED`、`CLOSED`、`REOPENED`、`CANCELLED`。

本章不新增 `STARTED`、`DONE` 或 `REASSIGNED`。示例 enum 保留精确集合，但可执行行为聚焦主路径，避免提前实现 Week 18 的完整状态机。

## 29. 主路径

FactoryCare 主路径是 `CREATED → TRIAGED → ASSIGNED → ACCEPTED → IN_PROGRESS → RESOLVED → VERIFIED → CLOSED`。

每条边用独立命令表达。测试重放完整路径并逐步检查 status/version，使缺边或错序在第一处断言暴露。

## 30. assign 的不变量

assign 只能从 TRIAGED 发生，且 TeamId 必须已是合法值。方法先验证 current 和参数，再同时设置 team 与 ASSIGNED。

若先把 team 写入字段，再发现状态不对抛异常，对象会处于“CREATED 但已有 assignment”的半更新状态。检查必须在变更之前完成。

## 31. start 的不变量

主路径 start 只能从 ACCEPTED 进入 IN_PROGRESS。完整状态机中 REOPENED 也能回 IN_PROGRESS，但应由明确语义和测试扩展，而不是通配所有非 CLOSED 状态。

过宽条件如 `status != CLOSED` 会允许 CREATED、TRIAGED 或 CANCELLED 开工，是典型的负向黑名单缺陷。

## 32. close 的不变量

close 只能从 VERIFIED 进入 CLOSED。RESOLVED 仍需验证，IN_PROGRESS 更不能跳过解决和验证。

该规则属于 WorkOrder 生命周期，不应只放在 Controller 按钮显隐。其他客户端、批任务或测试仍可能调用用例，聚合必须是最终保护线。

## 33. 先校验后变更

简单命令采用两阶段顺序：验证所有前置与参数；确定没有失败后再更新全部字段；最后可运行内部 invariant assertion。

这让非法命令天然保持快照不变。若操作跨外部 I/O，领域对象本身不能提供事务原子性，应由应用/持久化层协调，本章不伪造该保证。

## 34. 非法转换不改变状态

“抛异常”不是完整 oracle。测试还要比较失败前后的 status、team、version 和其他受影响字段。

一个方法可能既抛异常又已经改了部分字段；只写 `assertThrows` 会让此类破坏悄悄通过。

## 35. 领域失败要有业务语言

`InvalidTransition` 应携带 current、command 或 target 等安全领域上下文，帮助上层映射为 409 和记录诊断。

它不携带 HttpStatus、ProblemDetail 或 SQL。纯 Java 模型因此能在 MVC、命令行、批任务和消息消费中复用。

## 36. version 的语义边界

聚合 version 可表示成功变更序列，并为后续乐观锁提供 expected/actual 比较。每次成功命令增加一次，拒绝命令不增加。

数据库如何做 compare-and-swap、事务失败如何恢复内存实例属于持久化章节。本章只验证对象内的单线程语义。

## 37. Entity equality 的选择

WorkOrder 若创建时已有稳定 WorkOrderId，可让 equals/hashCode 只使用 id，并保持 id final。不要把 mutable status 放入 hashCode 后再把实体放入 HashSet。

有些团队选择实体不覆盖 equals，或由 ORM 约束策略。没有一种实现脱离生命周期都正确；本章明确采用“稳定 id 身份”并用测试固定。

## 38. Value object equality 的选择

AssetCode 经 trim/大写规范化后，可直接使用 record 默认 equals。两个不同原始表示构造出的规范值相等。

测试必须覆盖 equal、not equal、hashCode 和非法输入。只展示 record 源码而不验证业务 normalization，不能证明 value semantics。

## 39. null 边界

领域模型不应让 null 偷偷代表多个含义。必填值在构造时拒绝；可选事实用 Optional 返回查询或专用状态表达，具体取决于模型。

不要把 Optional 作为所有字段类型的装饰。关键是“缺失”是否是业务合法状态，以及哪个生命周期阶段允许它。

## 40. 字符串也应有边界

直接使用 String 会让 AssetCode、TeamId、description 互相误传。高价值标识和有明确规则的文本适合值对象。

不是每个字符串都必须包装。判断维度包括独立含义、验证、规范化、复用和误用风险，避免无意义类型爆炸。

## 41. Primitive obsession

当规则散落为 `String id`、`int status`、`BigDecimal amount` 时，调用签名不能表达单位和约束，错误组合只能在运行深处发现。

值对象把规则前移到构造边界。其成本是类型与映射增多，因此应优先用于身份、金额、代码、时间范围等高风险概念。

## 42. Anemic model 的诊断

如果 WorkOrder 只有 getter/setter，而 Controller 或 service 写满 `if status`，规则会在多个入口复制并漂移。这是贫血模型的常见信号。

但并非所有逻辑都应塞进实体。跨聚合查询、外部服务和流程编排仍适合应用/领域服务；判断依据是规则所需数据与一致性边界。

## 43. Domain service 的适用边界

一个行为若属于领域语言，却不自然归属于某个 entity/value object，可以使用 domain service。例如需要多个独立聚合只读信息的策略计算。

Domain service 不是“放不下的代码垃圾桶”。它不能通过 public setter 绕过各聚合 root，也不应依赖 Controller DTO。

## 44. Application service 的职责

Application service 负责加载聚合、授权、调用领域命令、保存、提交事务和发布后续动作。它编排用例，但不重新实现状态规则。

本章不创建 repository 或事务；示例直接在内存中构造聚合，以便把测试证据集中在领域行为。

## 45. 跨聚合修改

一个 WorkOrder 不应拿到 Team 的内部成员并直接改 Team 状态。它保存 TeamId，应用层分别协调聚合，并接受跨边界不一定即时一致。

若一条强不变量真的要求两者原子一致，应重新审视边界，而不是随意打开内部字段。

## 46. DTO 充当实体为何失败

DTO record 的所有组件通常由调用者一次提供，适合边界数据；实体则需要稳定身份、受控生命周期和行为。把 status 放进 UpdateWorkOrderDto 会自然形成通用覆盖入口。

正确流程是 DTO → command/value objects → aggregate method。响应再由 aggregate snapshot 映射为独立 DTO。

## 47. ORM 注解不是领域含义

`@Entity` 是持久化框架术语，与 DDD entity 概念有重叠但不等同。一个 DDD entity 可以不使用 ORM；一张 ORM entity 也可能只是数据映射对象。

本章不绑定表、lazy loading、无参构造器或代理限制。后续持久化适配必须尊重已有领域不变量，而不是反向削弱模型。

## 48. 序列化绕过构造器

某些反序列化/ORM 技术可能绕过普通构造路径或直接写字段。如果技术框架能制造非法实例，仍需在 reconstitution 边界校验并用集成测试证明。

纯 Java 单元测试只证明公开 API。它不能自动证明每个框架都遵守封装，这属于明确的未验证边界。

## 49. 聚合不要过大

把所有附件、日志、审计、用户和设备对象都装进 WorkOrder，会增加加载、锁竞争和变更耦合。聚合边界应尽可能小但足以保护强不变量。

只因为 UI 一页同时展示多种数据，不代表它们必须是一个聚合；查询模型可以组合跨聚合投影。

## 50. 聚合也不要过小

若一条必须同步成立的规则被拆到两个无法原子协调的对象，任何一方都可能观察到非法状态。为了“每类一个 repository”机械拆分同样危险。

从业务不变量、并发冲突与事务边界共同判断，而不是按数据库表数或代码行数判断。

## 51. 不变量的三层证据

构造测试证明初始合法；行为测试证明合法命令得到预期状态；拒绝测试证明非法命令抛出且快照不变。

反射测试可辅助证明没有 public setStatus，但它不是全部保证。字段暴露、可变集合、反序列化仍需各自检查。

## 52. 状态图与表驱动测试

完整状态机适合把合法边列成数据，遍历 12×12 的其余非法组合做性质测试。本章只实现主路径，不能声称已满足 FC-WO-001/002 的完整验收。

后续扩展时应从唯一 PROJECT_SPEC 状态图生成或对照 oracle，禁止在代码里发明第二套边集合。

## 53. 测试命名表达业务

`verifiedWorkOrderCanClose` 比 `testSetter3` 更能说明规则。失败输出应包含 expected/current/command，帮助定位第一处偏差。

测试按业务场景组织，而不是逐 getter 覆盖。覆盖率数字不能替代关键不变量矩阵。

## 54. 快照 oracle

一个 Snapshot 可包含 status、teamId、version。非法命令前保存 before，执行 assertThrows，再断言 before 等于 after。

快照应只暴露公开可观察事实，不返回内部可变引用。它既便于测试，也可作为应用层映射输入，但不是网络 DTO。

## 55. Public setter 故障注入

starter 提供 `setStatus(CLOSED)`，调用者可从 CREATED 跳过七条主路径边。合法方法本身即使正确，模型仍不安全。

红灯通过反射检查公开方法集合，哨兵为 `EXPECTED_NO_PUBLIC_STATUS_SETTER`。修复是删除通用 setter，保留意图命令，而非给 setter 再加一个庞大 switch。

## 56. 非法变化的第一处可信证据

若 close 失败后 version 已增加，先检查 mutation 是否发生在 guard 之前；若 CREATED 能 assign，检查 allowed current；若相同 AssetCode 不相等，检查 normalization 与 record 组件。

从第一个失败断言回到负责该不变量的方法。不要先改测试 expected 来迎合实际状态。

## 57. 失败原子性的限制

对象内“先检查后修改”可保证同步方法抛出前不发生部分变更。它不能保证数据库保存、审计与 outbox 的原子提交。

真实 FactoryCare 要由事务把状态、version、transition、核心审计和 outbox 一起提交；这是后续章节，不应在纯 Java 示例中声称已验证。

## 58. 并发的限制

两个线程或两个请求同时操作各自加载的 WorkOrder，单对象 guard 无法判断谁更新较新。需要 expected version 与持久化 compare-and-swap。

本章的 version 只建立概念接口。测试没有多线程、数据库锁或重试，因此不提供并发正确性证据。

## 59. 事件的限制

FactoryCare 规范已有六个核心事件，但本章责任明确不实现分布式事件。聚合状态正确不等于消息已可靠发布。

后续可以记录 domain event intent，并由事务 outbox 发布；当前示例不新增事件名、不模拟 exactly-once，也不改变 Java/Python权威边界。

## 60. 120 秒口述模板

先说 entity 由身份与生命周期区分，value object 由值区分且优先不可变；再说 aggregate root 是同步不变量边界。

然后以 WorkOrder 解释 create、assign、start、close 如何 guard；最后给 public setStatus 反例，并说明非法命令快照不变如何证明修复。

## 61. 练习步骤

先不运行代码，预测 CREATED 调 close、TRIAGED 调 assign、ACCEPTED 调 start 的结果和 version。再运行 lab，对照第一处差异。

随后打开 starter，指出通用 setter 绕过哪条边；修复后重放同一测试。最后用自己的话解释为何 DTO 与聚合不能共用同一个类。

## 62. 自检问题

为什么两个属性相同但 id 不同的 WorkOrder 不是同一实体？为什么 record 不自动深不可变？为什么 `assertThrows` 后还要比较快照？为什么外键关系不能直接决定聚合边界？

若回答只剩“DDD 最佳实践”，还没有形成可执行理解；必须回到具体不变量和失败样例。

## 63. 本章边界

本章不绑定数据库表、ORM、Controller、Bean Validation、授权、事务、分布式事件或完整 12 状态实现。也不创建 repository 和 Spring Bean。

这些是有意非目标。当前证据只说明纯 Java 领域对象的构造、相等、封装和主路径转换规则。

## 64. 官方与主来源

- [Eric Evans：DDD Reference](https://www.domainlanguage.com/ddd/reference/)
- [Eric Evans：DDD Reference PDF](https://www.domainlanguage.com/wp-content/uploads/2016/05/DDD_Reference_2015-03.pdf)
- [Java SE 25：Record](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Record.html)
- [Java SE 25：BigDecimal](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/math/BigDecimal.html)
- [Java SE 25：Value-based Classes](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/doc-files/ValueBased.html)
