# 第 21 周：模块化单体、Spring Modulith 与后端阶段考核

> 建议投入：17 小时（可在 15—18 小时内调整）

## 1. 本周定位

本周收束企业后端阶段的安全、领域、缓存与可靠事件能力，把 FactoryCare 整理为能长期演进的 **Spring Boot 模块化单体**。目标不是追求“干净架构”外观，而是使模块职责、公开 API、依赖方向、事务与事件边界可被自动验证。

Spring Modulith 用于发现、校验、测试和记录模块，不把单体伪装成微服务。周末进行后端阶段考核，验证在不依赖 AI 的情况下能完成带权限、事务和测试的真实小需求。

## 2. 前置条件

- Week 16—20 的安全、租户、领域、缓存和事件核心测试通过，当前主分支可回滚。
- 已有认证/授权、设备、工单、审计、缓存和通知/Outbox 功能。
- 能说明各模块的数据所有权和核心事务，不以 Controller 或数据库表作为唯一分层依据。
- 重构前创建架构快照、测试基线和可回滚提交，不在同一提交混入新业务功能。

## 3. 学习目标

- 能区分技术分层、按业务模块划分和微服务拆分。
- 能为 FactoryCare 定义模块、公开接口、内部实现、所有数据和发布/订阅事件。
- 能识别循环依赖、共享数据库越界、万能 `common` 包和跨模块直接调用内部类。
- 能使用 Spring Modulith 自动验证模块结构、生成文档并进行模块集成测试。
- 能说明模块内事务、跨模块同步调用与事件协作的取舍。
- 能在无 AI 阶段考核中独立完成需求、测试、排错和口述。

## 4. 完整概念清单

### 4.1 模块化单体基础

- 单进程/单部署不等于没有模块；模块由业务能力和变更原因定义。
- 高内聚、低耦合、稳定依赖方向和信息隐藏。
- 模块公开 API、内部包、事件契约和数据所有权。
- 同步调用适合需要立即结果/同事务一致；事件适合降低依赖和次要副作用。
- 模块内可按 application/domain/infrastructure 表达职责，但不机械复制空目录。
- Shared Kernel 只保存真正稳定的小型值类型；`common` 不能成为垃圾场。
- 模块化单体与微服务的实施成本、迁移成本、故障面、回滚和运维差异。

### 4.2 FactoryCare 目标模块

- `identity`：认证主体、用户、角色、权限；不拥有业务工单。
- `organization`：租户、组织、班组与数据范围。
- `asset`：设备、设备编码和设备状态。
- `workorder`：工单聚合、状态机、SLA、历史和业务事件。
- `engagement`：通知意图、Outbox投递适配与发送记录。
- `audit`：跨业务审计写入端口与受限查询。
- `knowledge`：本周完成文档元数据、版本、审核、发布/撤回和版本化事件的最小纵向切片。
- `reporting`：先建立可重建的只读SLA/工单指标边界，Week 27接Vue看板。
- `ai-integration`：先定义Java/Python端口、身份、超时和降级契约，Week 40接入真实Python服务。
- 计划性预防维护是未来扩展，本轮不创建`maintenance`模块。
- 每张业务表只有一个拥有模块；其他模块通过 API、ID 或事件协作。

### 4.3 Spring Modulith

- 基于包结构发现 Application Module；公开 API 与内部实现。
- `ApplicationModules.of(...).verify()` 验证无循环、仅访问公开接口和允许依赖。
- `@ApplicationModule`、命名接口与 allowed dependencies 的适用场景。
- `@ApplicationModuleTest` 的独立模块集成测试模式。
- `Scenario`、`PublishedEvents` 验证模块事件协作。
- 文档生成：模块 Canvas、组件图和依赖图；文档必须反映真实代码。
- Event Publication Registry 与第 20 周 Outbox 的重叠：选择一种主路径，避免双重可靠事件机制。

### 4.4 架构治理与演进

- 架构决策记录 ADR：上下文、选项、决定、后果、迁移和回滚。
- 依赖规则进入自动化测试/CI，而不是只画图。
- 模块边界重构采用小步移动、编译、测试、提交。
- 何时考虑拆服务：独立伸缩、部署、故障隔离、数据/团队所有权有真实证据。
- 不能因为“将来可能”提前承担网络、分布式事务和可观测性成本。

## 5. 任务分配

| 任务 | 时间 | 结果 |
| --- | ---: | --- |
| 当前依赖盘点与目标模块设计 | 2h | 现状/目标依赖图 |
| 小步重构与最小模块契约 | 5.5h | 业务模块、knowledge切片、reporting/AI端口 |
| Modulith 验证、测试与文档 | 3h | 自动化架构证据 |
| 后端阶段无 AI 实操考试 | 3h | 完整需求交付 |
| 口述/故障定位考试与复盘 | 2h | 评分表和补弱清单 |
| 求职与作品集动作 | 2h | 架构讲解和投递版本 |

总计 17.5 小时。若只有 15 小时，减少图表美化；不能删除模块验证、knowledge发布/撤回、阶段考试和回滚基线。

## 6. FactoryCare 项目增量

- 先生成当前包依赖图，标注循环、跨模块内部访问、共享表和万能工具类。
- 按`identity/organization/asset/workorder/knowledge/engagement/reporting/audit/ai-integration`迁移或建立最小边界，保持既有API行为不变；每移动一个模块即运行测试并提交。
- `knowledge`完成文档元数据、对象键/哈希/大小/MIME字段、版本、审核、发布/撤回API，并发布`KnowledgeDocumentPublished.v1`与`KnowledgeDocumentRevoked.v1`；Week 27接入私有对象上传，暂不做解析和向量索引。
- `reporting`提供可重建的SLA/工单只读查询；`ai-integration`只提供端口、假实现、身份/超时/降级契约，不连接真实模型。
- 为每个模块写 `README` 或 Canvas：职责、公开接口、拥有数据、订阅/发布事件、禁止依赖。
- 添加 `ApplicationModules.verify()` 架构测试并纳入 CI。
- 为 `workorder` 编写 `@ApplicationModuleTest`：验证状态变更、审计/事件发布和非法路径。
- 生成模块依赖图，确认无循环；不能靠把所有类改成 `public` 消除错误。
- 比较第 20 周手写 Outbox 与 Spring Modulith Event Publication Registry，选择当前主实现并写 `ADR-018-modular-monolith.md`；另一条只作为迁移备选。
- 保持一个 Spring Boot 部署单元和一个业务数据库；模块化完成后做一次完整回归。

## 7. AI 协作边界

AI 可以：

- 阅读依赖清单后提出 2—3 个模块划分方案并比较取舍。
- 帮助生成 ArchUnit/Modulith 测试骨架和模块文档草稿。
- 逐个小提交审查跨模块依赖和潜在回归。
- 在阶段考试结束后充当面试官追问，而不是考试中直接作答。

AI 不可以：

- 一次性移动整个目录、批量改包名并宣称重构完成。
- 为消除循环依赖创建巨大 `common` 包、全局 Service Locator 或全公开接口。
- 擅自拆微服务、数据库或改变 API/数据契约。
- 参与无 AI 实操考试的分析、编码和排错阶段。

每次 AI 辅助重构都必须先定义文件范围和验收测试，diff 超出范围立即停止审查。

## 8. 无 AI 训练

本周从求职/复盘时段预留45—60分钟完成并记录：从Week 01—17错题中随机复测一道，独立写测试、复杂度和替代方案。

### 8.1 180 分钟阶段实操

需求：增加“主管驳回已解决工单，要求技师返工”。

- 20 分钟：写目标、非目标、权限、状态规则、API 契约与验收标准。
- 100 分钟：实现领域行为、乐观锁、状态历史、审计/事件及数据库变更。
- 40 分钟：补单元/集成测试，包含成功、无权限、跨租户、非法状态和版本冲突。
- 20 分钟：运行全量测试，检查日志和 diff，写回滚说明。

### 8.2 口述与排错

- 10 分钟画出认证、授权、工单事务、Outbox 和通知链路。
- 随机解释一个模块依赖为何允许或禁止。
- 在 30 分钟内从日志定位一个故意制造的事务失效或跨模块依赖问题。
- 评分低于 80/100 时，下周每天先补 30 分钟，不带着关键缺口进入前端阶段。

## 9. 求职动作（恢复求职后启用）

- 采样南昌 Java/Java 全栈/工业软件岗位 10 个，把要求映射到 FactoryCare 证据：Spring Security、SQL、Redis、MQ、模块化、测试、Docker。
- 准备 10 分钟架构讲解：为什么选模块化单体、各模块如何协作、何时才拆微服务。
- 形成两版项目描述：Java 应用版突出权限/事务/可靠性；全栈版同时突出即将开始的 Vue3 管理端。
- 恢复求职后才完成一次模拟系统设计面试和 5 次定向投递，并根据反馈校准 Week 22—25 Web 基础与 Week 26—29 Vue/Nuxt 的练习深度；暂停期间把这段时间用于 G3 错题复测。

## 10. 本周交付物

- 当前/目标模块图、模块 Canvas 和 `ADR-018-modular-monolith.md`。
- 完成业务模块重构的 FactoryCare 后端。
- `ApplicationModules.verify()`、模块集成测试和生成的架构文档。
- 后端阶段考试代码、评分表、排错记录和补弱清单。
- 10 分钟架构讲解提纲与两版项目经历。

## 11. 验收标准

- 模块依赖无循环，模块只能访问其他模块公开 API；规则由自动化测试和 CI 验证。
- 每张核心表和关键业务规则有明确拥有模块，不出现任意模块直接改他人表。
- 全量业务、安全、租户、状态、缓存、Outbox 测试保持通过。
- 能解释手写 Outbox 与 Modulith 事件注册表的取舍，项目只保留一条主可靠交付路径。
- 无 AI 在 180 分钟内完成阶段需求，评分不低于 80/100。
- 能在 10 分钟内讲清模块、事务、数据权限、并发和失败恢复，不背框架宣传词。
- 重构有小步提交和回滚点，没有混入未约定的新功能。

## 12. 明确不做

- 不拆微服务、不引入 Spring Cloud、服务注册中心或分布式事务。
- 不为每个模块创建独立数据库，不复制六套机械分层模板。
- 不把所有通用类放进 `common`，不为了通过验证公开内部实现。
- 不同时运行两套 Outbox/事件可靠交付机制。
- 不在阶段考试中使用 AI，不把未通过考核包装为已掌握。

## 13. 官方资料

- [Spring Modulith Reference](https://docs.spring.io/spring-modulith/reference/)
- [Spring Modulith Fundamentals](https://docs.spring.io/spring-modulith/reference/fundamentals.html)
- [验证应用模块结构](https://docs.spring.io/spring-modulith/reference/verification.html)
- [应用模块集成测试](https://docs.spring.io/spring-modulith/reference/testing.html)
- [使用应用事件](https://docs.spring.io/spring-modulith/reference/events.html)
- [生成应用模块文档](https://docs.spring.io/spring-modulith/reference/documentation.html)
- [Spring Boot Structuring Your Code](https://docs.spring.io/spring-boot/reference/using/structuring-your-code.html)
