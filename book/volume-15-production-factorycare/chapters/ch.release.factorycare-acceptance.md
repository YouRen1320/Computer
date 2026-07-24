---
schema_version: 2
edition: 2026.2-draft
id: ch.release.factorycare-acceptance
title: FactoryCare 端到端验收与可回滚发布
responsibility: 在路线门禁集中验收 FactoryCare 的 Web、小程序、Flutter、Java 后端、Python/AI 和生产交付，证明安全隔离、故障恢复与可回滚发布。
volume: '15'
order: 16
level: L3
status: drafting
path: book/volume-15-production-factorycare/chapters/ch.release.factorycare-acceptance.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ops.incident-dr
- ch.architecture.system-design
- ch.vue.component-testing
- ch.uniapp.release-monitoring
- ch.flutter.testing-performance
- ch.flutter.device-apis
- ch.agent.mcp-boundaries
version_surfaces:
- ci
- git
- docker
- docker-compose
- nginx
- postgresql-18
- spring-boot-4.1
- vue-3
- uni-app
- wechat-miniprogram
- flutter-stable
- python-3.14
- model-api
- mcp
- observability
- ubuntu-server-26.04
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“FactoryCare 端到端验收与可回滚发布”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - factorycare-business-e2e
  - factorycare-security-data
  - factorycare-ai-contract
  - factorycare-release-recovery
  covers_topics:
  - factorycare.workorder-lifecycle
  - factorycare.web-client
  - factorycare.mini-client
  - factorycare.flutter-client
  - factorycare.authentication-authorization
  - factorycare.tenant-isolation
  - factorycare.transaction-invariant
  - factorycare.audit-trail
  - factorycare.rag-citation
  - factorycare.agent-readonly
  - factorycare.ai-fallback
  - factorycare.eval-regression
  - factorycare.release-manifest
  - factorycare.canary-gate
  - factorycare.rollback-forward-fix
  - factorycare.dr-evidence
  uses_capabilities:
  - ops.recovery-deployment
  - ops.container-proxy-delivery
  - architecture.observability
  - security.multitenancy-isolation
  - web.component-e2e-testing
  - mobile.uniapp-platform
  - mobile.flutter-device-permissions
  - ai.agent-graph-mcp
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 从空白验收环境按发布清单部署 FactoryCare，运行多角色/双租户/三客户端/AI 回归、性能/安全故障、canary 回滚与数据库恢复；独立保存可复现工件与判断结果
  covers_topic_groups:
  - factorycare-business-e2e
  - factorycare-security-data
  - factorycare-ai-contract
  - factorycare-release-recovery
  covers_topics:
  - factorycare.workorder-lifecycle
  - factorycare.web-client
  - factorycare.mini-client
  - factorycare.flutter-client
  - factorycare.authentication-authorization
  - factorycare.tenant-isolation
  - factorycare.transaction-invariant
  - factorycare.audit-trail
  - factorycare.rag-citation
  - factorycare.agent-readonly
  - factorycare.ai-fallback
  - factorycare.eval-regression
  - factorycare.release-manifest
  - factorycare.canary-gate
  - factorycare.rollback-forward-fix
  - factorycare.dr-evidence
  uses_capabilities:
  - ops.recovery-deployment
  - ops.container-proxy-delivery
  - architecture.observability
  - security.multitenancy-isolation
  - web.component-e2e-testing
  - mobile.uniapp-platform
  - mobile.flutter-device-permissions
  - ai.agent-graph-mcp
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: full-system-regression-security-and-failure-injection-release-rollback-drill
- id: diagnose
  kind: fault-diagnosis
  text: 面对“任一客户端绕过后端合同、跨租户数据出现在列表/RAG/cache、AI 不可用阻塞核心工单或发布失败无法回滚”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - factorycare-business-e2e
  - factorycare-security-data
  - factorycare-ai-contract
  - factorycare-release-recovery
  covers_topics:
  - factorycare.workorder-lifecycle
  - factorycare.web-client
  - factorycare.mini-client
  - factorycare.flutter-client
  - factorycare.authentication-authorization
  - factorycare.tenant-isolation
  - factorycare.transaction-invariant
  - factorycare.audit-trail
  - factorycare.rag-citation
  - factorycare.agent-readonly
  - factorycare.ai-fallback
  - factorycare.eval-regression
  - factorycare.release-manifest
  - factorycare.canary-gate
  - factorycare.rollback-forward-fix
  - factorycare.dr-evidence
  uses_capabilities:
  - ops.recovery-deployment
  - ops.container-proxy-delivery
  - architecture.observability
  - security.multitenancy-isolation
  - web.component-e2e-testing
  - mobile.uniapp-platform
  - mobile.flutter-device-permissions
  - ai.agent-graph-mcp
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# FactoryCare 端到端验收与可回滚发布

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《事故响应、灾难恢复、复盘与改进闭环》](ch.ops.incident-dr.md)：总验收必须证明事故响应、恢复和改进闭环，而非只验证快乐路径。
- [《需求、边界、容量、可靠性与系统设计取舍》](ch.architecture.system-design.md)：端到端范围、容量、可靠性与取舍必须有统一系统设计基线。
- [《组件测试、Mock、异步断言与端到端边界》](../../volume-09-vue-nuxt/chapters/ch.vue.component-testing.md)：Web 客户端必须具备组件、集成与浏览器级回归证据。
- [《构建、版本、灰度、发布与监控》](../../volume-10-uniapp-miniprogram/chapters/ch.uniapp.release-monitoring.md)：小程序必须完成平台权限、包体、真机和发布验证。
- [《Widget/集成/Golden 测试、性能与内存分析》](../../volume-11-dart-flutter/chapters/ch.flutter.testing-performance.md)：Flutter 客户端必须具备测试、无障碍和设备路径证据。
- [《相机、扫码、定位、权限与平台通道》](../../volume-11-dart-flutter/chapters/ch.flutter.device-apis.md)：三客户端验收包含扫码、拍照和定位，必须直接复用已验证的 Flutter 权限与平台通道合同。
- [《MCP、Agent 模式/反模式与 Java/Python 职责边界》](../../volume-14-llm-rag-agents/chapters/ch.agent.mcp-boundaries.md)：AI/Agent 只能在已验证 RAG 安全、MCP 和 Java 权威边界内验收。
<!-- END GENERATED LEARNING PREREQUISITES -->

一个系统能在开发者电脑上打开，不等于它已经可以交付。端到端验收要回答的是一组更严格的问题：三个客户端是否遵守同一份后端合同；工单状态是否只能按业务规则迁移；租户甲是否在任何路径都看不到租户乙的数据；AI 不可用时核心维修流程是否仍可运行；发布失败后能否恢复到已知状态；所有结论是否都有可复查的制品、命令、日志和判据。

本章是 FactoryCare 路线的总门禁。它不再逐项教授 Vue、uni-app、Flutter、Spring Boot、PostgreSQL、RAG、Docker 或 Nginx，而是把前面已经学过的能力组合成一条可证伪的交付链。组合并不意味着“启动所有服务然后点一点页面”，而是先冻结验收对象和规则，再以成功、边界、失败和恢复四类证据证明系统行为。

稳定原则不依赖某个框架版本：业务事实只有一个权威来源；身份、租户和授权必须在服务端强制；客户端只是业务合同的不同呈现；AI 只能读取经过授权的投影并给出可丢弃的建议；发布对象由不可变制品身份定义；备份必须经过恢复演练才算证据。Spring Boot 4.1、PostgreSQL 18、Vue 3、uni-app、Flutter stable、Python 3.14、模型 API、MCP、Docker Compose 和 Ubuntu Server 26.04 都是本版课程的版本表面，执行验收前仍要锁定实际版本并保存输出。

## 1. 先定义“通过”，再运行系统

没有事先写下判据的演示很容易自我欺骗。页面出现一行工单，既不能证明数据库事务正确，也不能证明列表没有跨租户泄漏。验收清单的每一项必须包含：前置数据、执行角色、输入动作、可观察结果、禁止结果、首个可信证据、清理动作和失败后的恢复方式。判据应尽量是机器可断言的布尔条件，而不是“看起来没问题”。

总门禁的核心判据是：版本化清单中的所有必需检查通过；Web、小程序和 Flutter 调用同一份版本化 Java API；任何查询、缓存、RAG 检索和 Agent 工具都保持租户隔离；模型或 Python 服务停机不阻塞创建、分派、处理和关闭工单；候选发布异常时能按已演练路径在目标 RTO/RPO 内恢复。只要任一关键项缺证据，结论就是“未验证”，不是“基本通过”。

建议把结论分为四种，而不是只有绿色和红色：`PASS` 表示在声明环境按原判据通过；`FAIL` 表示已观察到违反判据；`BLOCKED` 表示受外部条件阻塞且没有执行；`UNVERIFIED` 表示尚未覆盖或证据不足。`BLOCKED` 与 `UNVERIFIED` 不能伪装成 `PASS`，也不应通过删除用例让总门禁变绿。

## 2. 冻结验收对象与环境身份

开始前创建 release manifest。它至少记录 Git commit、工作区是否干净、Java API/Web/Python 制品 digest、移动端构建号、小程序版本、数据库 schema 版本、配置修订、测试报告、SBOM/来源证明引用以及回滚目标。测试环境和候选环境必须解析到同一组已门禁制品；如果到生产阶段重新构建，就产生了新的候选，先前测试不能自动继承。

环境也要有身份。记录操作系统、CPU 架构、JDK、Maven、Node、pnpm、Python、uv、Flutter、Docker、Compose、数据库和浏览器/设备版本。`java -version`、`mvn -v` 与 IDE Project SDK 可能来自不同路径，必须分别保存。终端环境通过不代表 IDE、容器或 CI 使用相同 JDK。验收报告应说明真正执行每个命令的进程环境，而不是笼统写“本机是 JDK 25”。

从空白环境开始并不意味着每次手工搭机器。更可靠的方式是版本化 Compose、初始化脚本、fixture 和探针，用一条明确入口建立环境。入口必须失败关闭：缺少密钥引用、镜像 digest、迁移版本或必要配置时退出非零。默认连接开发数据库、自动关闭 TLS 校验或用管理员账号兜底，都会把配置错误变成潜在事故。

## 3. 系统边界与不可破坏的不变量

FactoryCare 的权威写入边界在 Java 服务。Java 持有用户与角色、租户、设备、工单、状态机、指派、审计和事务不变量；PostgreSQL 持久化这些事实。Vue、uni-app 和 Flutter 不直接访问数据库，不各自实现一套状态规则。Python 服务不拥有工单最终状态，不自行批准动作，不从模型输出直接执行写库。模型上下文和向量索引是可重建派生数据，不是业务真相。

验收前把关键不变量写成表格。例如：每条业务行拥有不可为空的 `tenant_id`；服务端从认证主体推导租户，不信任客户端传入租户；工单只能沿允许状态边迁移；一次状态迁移和审计记录处于同一事务；重复请求不会创建两次同一业务结果；关闭工单需要满足必填字段和权限；AI 建议缺失、超时或格式错误都不能改变事实；跨租户引用即使猜中 ID 也返回不可利用结果。

不变量需要多层保护。控制器解析输入，应用服务执行权限与状态规则，仓储查询强制租户条件，数据库约束防止明显非法数据，审计记录保存主体和变化。多层不是重复浪费，而是避免任一入口绕过。测试也应覆盖不同入口：HTTP API、后台任务、Agent 工具、导入脚本和运维命令都不能获得特殊旁路。

## 4. 工单生命周期的业务回归

先用最小而完整的生命周期建立基线：租户管理员创建设备和工单，调度员分派技术员，技术员接受并进入处理中，补充维修记录后关闭，审计时间线按顺序出现。每一步同时断言 HTTP 状态、响应 schema、数据库可见事实、版本号或 ETag、审计事件和无关字段不变。只看最终状态会漏掉中间事务和审计错误。

边界矩阵至少包括：不存在设备、禁用设备、空标题、非法优先级、越权分派、跳过中间状态、重复关闭、并发更新、过期版本、重复幂等键和取消后继续处理。测试预先写出期望错误码和问题详情结构。服务端不能把所有错误都变成 500，也不能在返回 4xx 后留下部分写入。

并发验收不能靠顺序点击。准备两个独立会话读取相同版本，然后同时修改，断言只有符合并发策略的结果提交；失败方收到可识别冲突并能刷新重试。若采用乐观锁，就验证版本字段；若使用数据库锁，就验证等待与超时边界。PostgreSQL 默认 `READ COMMITTED` 并不会自动实现所有业务不变量，事务、锁和重试必须由应用合同明确。

## 5. 三个客户端共享一份合同

客户端一致不是要求界面一模一样，而是同一业务动作拥有同一语义。OpenAPI 或等价 schema 是机器可读合同；客户端生成类型或手写适配器都必须受合同测试约束。工单状态、错误码、分页、时间、金额和可空字段不能由各端猜测。时间统一传输格式和时区语义，UI 再按本地化展示。

Web 回归覆盖桌面端列表、筛选、详情、创建/编辑、权限可见性、加载/空/错误状态和刷新后的事实一致。组件测试证明交互与渲染，浏览器级测试证明路由、网络和真实构建组合。测试不能只 mock 一个永远成功的 API；至少有一组候选环境用例经 Nginx 到 Java 服务。

小程序回归还要覆盖平台登录、授权拒绝、网络切换、分包/包体、真机与审核限制。uni-app 编译到 H5 成功不能证明微信小程序运行成功。若当前没有真机、开发者账号或审核环境，就把这些项标为 `UNVERIFIED`，保存待执行步骤；不要用浏览器截图替代平台证据。

Flutter 回归覆盖路由、状态恢复、加载与错误、离线/重试、无障碍和性能基线。扫码、拍照、文件与定位需要权限矩阵：首次询问、拒绝、永久拒绝、系统设置返回和平台差异。模拟器测试不能证明真实摄像头、定位精度和系统权限文案，真机证据必须记录设备、系统、应用 build 和授权状态。

跨客户端合同测试可用同一组案例数据驱动。每端创建的工单都由其他端读取；同一权限角色看到一致动作；同一错误得到语义一致提示；分页游标和排序不漂移。若某端需要平台专属能力，差异应在适配层显式声明，而不是复制一套后端规则。

## 6. 认证、授权与双租户隔离

认证回答“是谁”，授权回答“是否可以执行此动作”，租户隔离回答“允许在哪个数据空间执行”。三者不可互换。一个有效 Token 不能访问任意租户；一个管理员也只能在其被授予的租户范围内管理。客户端隐藏按钮只是体验，服务端必须对每个写入和敏感读取重新授权。

建立租户甲和乙，每个租户至少有管理员、调度员、技术员和只读用户。为设备、工单、附件、评论、审计、缓存、导出、搜索和 AI 文档准备相似但可识别的数据。矩阵测试合法列表、猜 ID 详情、跨租户父子引用、批量接口、分页、排序、统计、附件 URL、WebSocket/推送、缓存命中和错误信息。目标不仅是“不返回完整记录”，还要避免数量、存在性、标题、向量片段和时间线侧漏。

后端查询应从安全上下文绑定 `tenant_id`，而不是把前端参数直接传入仓储。缓存键包含租户和影响结果的主体/角色；异步任务在入队时保存最小授权上下文并在执行时重新校验；日志和 trace 不记录原始 Token、敏感正文和跨租户检索内容。数据库行级安全可作为附加层，但不能代替应用授权设计和连接池上下文清理。

故障注入时，故意移除一个列表查询的租户条件，或把缓存键简化为资源 ID。正确门禁应先在安全测试中失败，并指出具体响应或候选集合，而不是等人工发现。修复后必须重跑完整双租户矩阵，因为单个 happy path 变绿不能证明所有入口恢复隔离。

## 7. 事务、幂等与审计证据

状态更新、关联记录和审计事件若属于一个业务动作，应在同一事务边界提交。注入审计写入失败，断言业务状态也回滚；注入业务约束失败，断言没有孤立审计。审计不是普通可编辑备注，应保存主体、租户、动作、对象、前后版本、时间、请求/追踪标识和结果，敏感字段按策略脱敏。

移动网络和代理重试会重复请求。为创建、支付类外部动作或关键迁移设计幂等键，并定义作用域、有效期、输入摘要和结果复用规则。同一租户、同一键、同一输入返回同一结果；同一键不同输入应冲突；不同租户不能互相命中。只在客户端禁用按钮不能解决超时后的未知结果。

验收还要验证审计可追溯而不可过度采集。日志有助于诊断，但不等于审计；数据库更新时间也不说明谁改变了什么。反过来，审计中保存完整附件、密码、Token 或模型提示又会扩大风险。字段清单和保留期必须明确。

## 8. RAG 的引用、隔离与回归

RAG 只消费 Java 生成或授权的数据投影。摄取记录保存租户、来源对象、版本、可见角色、更新时间和内容摘要；切块保留稳定 source ID 与字符范围；索引可以删除重建。检索前施加租户与权限过滤，不能先跨租户召回再让模型“不要泄漏”。模型永远不接收未授权候选。

回答必须带可机器核验的引用。引用至少指向 source ID、版本和精确片段范围；页面再通过 Java 授权接口解析显示。若证据不足、来源冲突或过期，系统拒答或明确不确定，不能补造业务事实。引用存在不等于引用支持结论，因此评估集要分别计算检索命中、引用有效、答案受支持和拒答正确。

冻结一组包含正常、边界、冲突、过期、提示注入和跨租户诱导的案例。更换嵌入模型、切块策略、重排器、提示或模型版本时重跑。评估报告记录数据集版本、参数、模型身份、随机性和阈值。只展示几个看起来聪明的回答不是回归证据。

停掉向量库、Python 服务或模型 API，核心工单流程仍应成功；AI 区域显示可理解的降级状态并允许稍后重试。若创建工单必须等待模型分类才能提交，就违反“AI 可降级”边界。可选分类可以异步补充建议，但最终业务字段由 Java 规则和授权用户确认。

## 9. Agent 与 MCP 的只读边界

Agent 的计划、工具调用和自然语言都不可信。MCP 或内部工具为每个动作定义严格输入输出 schema、租户/角色要求、超时、预算和审计。用于验收的默认工具集只读，例如查询授权工单、读取设备手册和生成建议。Agent 不直连 PostgreSQL，不持有管理员连接串，不自行调用关闭工单写接口。

如果未来允许写动作，应经过独立批准节点：先产生结构化提案，Java 重新认证授权和校验状态，用户看到精确影响并批准，最终写入返回不可混淆的 receipt。模型文本中的“已完成”不算提交证据。工具超时、重复调用、错误输出、拒绝审批、崩溃恢复和 kill switch 都要测试。

MCP 协议版本、SDK 包版本和服务器实现版本是三个不同身份。当前课程以登记的协议日期和锁定 SDK 执行夹具，但真实 socket、OAuth、远端服务器与生产授权若没有实际连接，必须明确未验证。内存 transport 通过只能证明协议对象和工具合同的一部分。

## 10. 性能、容量和可靠性基线

先从用户旅程定义服务级指标：创建工单成功率与延迟、列表查询延迟、状态迁移冲突率、附件上传、RAG 回答和后台摄取积压。给出负载模型：活跃租户、角色比例、工单量、峰值请求、对象大小、读写比和突发。没有工作负载描述的“1000 QPS”没有意义。

性能测试从功能正确的同一候选制品运行。先基线，再增加并发并观察 p50/p95/p99、错误、饱和资源、数据库连接池、慢查询和队列。客户端性能还包括首屏、包体、长列表、图片内存和卡顿。测量环境与生产不同就注明，不外推没有证据的容量。

注入数据库慢查询、连接池耗尽、模型超时、磁盘不足和下游 5xx。超时、重试、熔断和背压必须有预算；多层盲目重试会放大流量。核心 Java API 的降级不能依赖 AI。健康检查区分存活与就绪，只有准备接流量的实例才进入代理。

## 11. 可观测性与证据关联

日志、指标和 trace 不是三套互不相关的截图。请求从 Nginx 进入 Java，再到 PostgreSQL、Python 或模型代理，应使用可传播的相关标识；异步边界显式传递。日志结构化记录服务、release、环境、租户的不可逆标识、请求、事件和错误类别，不记录秘密或完整敏感文本。

指标用于聚合趋势，trace 用于单次路径，日志用于详细事件，审计用于受控业务追责。告警绑定用户影响和可执行 runbook，而不是 CPU 一高就报警。发布窗口在图表中标注 release ID，事故时间线才能回答错误是否随候选出现。

验收报告保存查询表达式和时间范围，不只保存一张图。截图可能裁掉单位、过滤器和时区；可复现查询能重新核对。若没有真实 collector，本地夹具只能验证字段、脱敏和关联规则，不能声称生产 trace 已打通。

## 12. Canary、前向修复与回滚

候选按不可变 digest 部署到 canary，小比例真实或合成流量进入。晋级门禁比较候选与基线的成功率、延迟、关键业务不变量和资源使用，观察窗口覆盖冷启动与典型任务。没有阈值和窗口的“观察一下”不是门禁。

应用回滚与数据库回滚分开设计。向后兼容的 expand/contract 迁移让旧、新应用在过渡期共同运行；先扩展 schema，再发布双读/双写或兼容代码，回填并验证，最后收缩。破坏性迁移后直接回滚旧应用可能无法读取新 schema。部署清单必须注明可回滚范围、前向修复条件和数据恢复路径。

触发阈值后自动或受控停止晋级，保存候选、基线、流量、指标和时间。回滚到先前 digest 后重跑核心 smoke，并确认数据库、队列和缓存兼容。仅看到旧容器启动不代表恢复完成。若错误写入了业务数据，需要补偿或恢复，不能靠替换镜像撤销。

## 13. 备份、恢复与 RTO/RPO

备份文件存在不等于可恢复。选择 SQL dump、文件系统级备份或 WAL 连续归档取决于规模和目标；本课程基线使用 PostgreSQL 18 官方备份/恢复概念。每个备份记录数据库版本、schema 版本、时间、范围、加密/访问、校验摘要和保留策略。

在隔离环境执行恢复：创建空目标，恢复 schema 和数据，运行完整性查询、租户隔离抽样、关键业务 smoke，并记录耗时。RPO 比较恢复点与故障时刻，RTO 从宣布恢复动作到服务满足判据。没有实际计时，就不能宣称达到目标。

恢复演练还要防止误连生产。目标连接、网络和凭据明确隔离；恢复前打印数据库身份；危险命令要求二次门禁。备份中包含敏感数据，测试环境仍需同等级访问和销毁策略。PostgreSQL 官方文档列出 SQL dump、文件系统备份与连续归档三类路径，实际方案按版本手册执行，而不是复制不明脚本。

## 14. 四个总门禁故障注入

### 14.1 客户端绕过后端合同

故意让某客户端发送不存在的状态或把租户 ID 当可编辑字段。期望 Java API 以稳定问题详情拒绝，数据库和审计不产生非法事实；客户端展示可恢复错误。若数据库出现非法状态，首个可信证据是约束/事务与审计对照，不是 UI 文案。修复服务端合同后，三个客户端和 API 合同测试一起重跑。

### 14.2 跨租户数据进入列表、RAG 或缓存

移除一个仓储过滤或缓存租户维度，用相似 ID 的双租户 fixture 触发。门禁必须在模型调用前发现未授权候选；日志记录拒绝但不泄漏正文。修复后重跑所有读取、统计、导出、附件、缓存和 AI 路径，证明不是只补了一个端点。

### 14.3 AI 不可用阻塞核心工单

让 Python/模型代理超时、返回畸形结构或完全停机。创建、分派、处理、关闭仍应由 Java 正常完成；AI 功能返回明确可重试降级。若事务等待模型并回滚，首个可信证据是 trace 中的依赖路径和超时预算。修复方法是移出核心事务、设置有界超时并提供可丢弃派生任务。

### 14.4 发布失败无法回滚

给候选注入错误配置、失败健康检查或不兼容迁移。门禁阻止扩大流量并执行预定恢复。首个证据是候选指标、部署事件和 schema 兼容检查；不能靠反复重启掩盖。修复后用原清单重演 canary、回滚/前向修复和恢复 smoke。

## 15. 实验实施顺序

第一阶段是准备。选择完整 Git commit，确保工作区状态有记录；构建一次并记录 digest；生成 release manifest；建立两个租户、多角色、设备、工单、附件、RAG 文档和冲突数据。冻结 fixture 版本和期望输出。

第二阶段是静态与单服务门禁。执行格式、编译、单元、组件、API schema、安全规则和依赖检查。任何基础门禁失败就停止，不用昂贵端到端环境掩盖。保存命令、退出码、报告路径和制品身份。

第三阶段是组合环境。按 digest 启动 PostgreSQL、Java、Web/Nginx、可选 Python 服务；执行迁移；验证健康、版本、TLS/代理和数据库身份。先跑核心生命周期，再跑三端合同、双租户、并发、AI、性能和故障矩阵。

第四阶段是发布与恢复。部署 canary，按阈值观察；注入失败；执行回滚或前向修复；在隔离目标恢复数据库并核对 RTO/RPO。最后生成证据索引，逐条链接判据和结果。未执行真机、真实 registry、真实 TLS、真实模型计费或云环境的项目必须保留为明确未验证项。

## 16. 证据包结构

一个可审计证据包可以包含：`manifest/` 保存发布与环境身份；`commands/` 保存带时间和退出码的命令；`reports/` 保存测试、安全、性能和评估结果；`logs/` 保存去敏片段；`screens/` 只作为交互辅助；`faults/` 保存故障注入前后；`recovery/` 保存回滚和数据库恢复；`claims.yml` 把每个结论链接到证据。

证据文件不是越多越好。每个结论要能回答：验证了什么对象、在什么环境、用什么输入、判据是什么、结果是什么、哪些没有验证。一个 `BUILD SUCCESS` 只有在测试数量和失败数清晰时才支持测试结论；一个 HTTP 200 若没有断言 release ID、响应 schema 和业务事实，只能证明某个端点当时返回 200。

证据也有保密边界。不得提交真实 Token、用户数据、私钥、生产数据库转储和未脱敏日志。发现秘密先撤销/轮换，再清理历史和补门禁；只加 `.gitignore` 不能撤回已泄漏内容。公开作品集使用合成数据和经审查片段。

## 17. 本章随附夹具如何使用

`examples/encyclopedia/ch.release.factorycare-acceptance/` 提供纯本地的验收清单校验器，演示怎样检查核心业务、三客户端、租户隔离、AI 降级、不可变制品和恢复证据。它验证的是数据结构与判据，不启动真实 FactoryCare。

`labs/encyclopedia/ch.release.factorycare-acceptance/` 提供带故障注入的合成 release fixture。实验先运行绿色清单，再把缓存隔离、AI fallback 或 rollback 证据改坏，观察首个失败字段，修复后重跑。这个夹具用于学习门禁思维，不能作为真实 Docker、Nginx、PostgreSQL、真机、模型 API 或灾备演练证据。

`exercises/` 故意保留一个只看页面和 HTTP 状态、不验证租户与恢复的错误实现，公开验证应稳定失败；`solutions-private/` 给出参考实现。先预测失败原因，再运行测试，读出 expected/actual 和字段路径，然后独立修复，不要直接复制答案。

## 18. 120 秒复述模板

可以这样复述：FactoryCare 总验收以不可变 release manifest 冻结对象；Java 和 PostgreSQL持有业务事实，三个客户端共享版本化 API，Python/AI 只读授权投影并可降级。测试从核心工单生命周期扩展到多角色双租户、并发事务、三端合同、RAG 引用、只读 Agent、性能与故障注入。候选按 digest canary 发布，失败时按已演练的应用回滚、前向修复或数据库恢复路径处理。所有结论链接到命令、退出码、日志、报告和制品身份，未跑真机或真实生产环境的部分明确标为未验证。

一个越界反例是让 Agent 持有数据库管理员连接并根据自然语言直接关闭工单。它绕过 Java 状态机、授权、事务和审计，即使演示成功也不能通过验收。

## 19. 版本与官方资料

本章版本表面以课程目录为准，执行日要重新核对锁文件和工具输出。数据库事务与恢复参考 [PostgreSQL 18 事务隔离](https://www.postgresql.org/docs/18/transaction-iso.html) 和 [备份与恢复](https://www.postgresql.org/docs/18/backup.html)；Vue 的测试层次参考 [Vue 官方测试指南](https://vuejs.org/guide/scaling-up/testing.html)；Flutter 设备与集成测试以 [Flutter 官方测试文档](https://docs.flutter.dev/testing/overview) 为准。框架文档能说明机制，不能替代本项目实际执行证据。

截至本教材核验日，本章随附资产只在本地合成 fixture 上验证清单、隔离、降级和恢复判据；没有据此声称真实 Docker daemon、registry、Nginx/TLS、PostgreSQL 18、微信真机、Flutter 真机、模型 API、MCP OAuth、观测后端、canary 或生产灾备已经运行。学习者完成真实环境后，应把新的版本、命令、身份和结果放入自己的证据目录，而不是修改教材中的边界说明。
