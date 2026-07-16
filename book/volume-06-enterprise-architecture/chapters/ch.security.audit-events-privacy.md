---
schema_version: 2
edition: 2026.2-draft
id: ch.security.audit-events-privacy
title: 审计事件、敏感字段、追踪责任与隐私最小化
responsibility: 教授记录可归责安全事件同时最小化敏感数据，不把普通调试日志当作不可抵赖审计账本
volume: '06'
order: 12
level: L2+
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.security.audit-events-privacy.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.security.multitenancy-data-isolation
- ch.java-engineering.logging-jvm-diagnostics
version_surfaces:
- observability
- spring-security
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释审计事件、敏感字段、追踪责任与隐私最小化的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - security-audit-event
  - security-privacy
  covers_topics:
  - security.audit-event-schema
  - security.actor-action-target
  - security.audit-integrity-retention
  - security.data-minimization
  - security.pii-redaction
  - security.trace-responsibility
  uses_capabilities:
  - security.authorization-policy
  - security.multitenancy-isolation
  - java.exceptions-resources
  - foundation.verification-debug-test
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：为登录、越权拒绝、状态变更和管理员操作定义 append-only 审计事件，含 actor/action/target/tenant/time/trace 且脱敏，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - security-audit-event
  - security-privacy
  covers_topics:
  - security.audit-event-schema
  - security.actor-action-target
  - security.audit-integrity-retention
  - security.data-minimization
  - security.pii-redaction
  - security.trace-responsibility
  uses_capabilities:
  - security.authorization-policy
  - security.multitenancy-isolation
  - java.exceptions-resources
  - foundation.verification-debug-test
  evidence_kind: system-artifact-and-negative-tests
  verification_mode: system-security-resilience-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入记录密码/Token、缺 tenant/actor 和业务事务失败仍声称成功事件，核对事实与审计后修复
  covers_topic_groups:
  - security-audit-event
  - security-privacy
  covers_topics:
  - security.audit-event-schema
  - security.actor-action-target
  - security.audit-integrity-retention
  - security.data-minimization
  - security.pii-redaction
  - security.trace-responsibility
  uses_capabilities:
  - security.authorization-policy
  - security.multitenancy-isolation
  - java.exceptions-resources
  - foundation.verification-debug-test
  evidence_kind: fault-injection-fix-rerun
  verification_mode: fault-injection-rerun
---
# 审计事件、敏感字段、追踪责任与隐私最小化

> 本章状态为 `drafting`。配套资产只在内存中构造合成事件并检查字段允许列表、结果语义、租户查询和追加写，不启动日志后端、OpenTelemetry、Spring、数据库、对象存储或导出任务。局部绿灯不能证明存储防篡改、事务原子性、保留/删除、访问控制或法律合规。

审计的目标不是“把能看到的都记下来”，而是在事故调查、权限治理和业务争议时，用最少必要数据回答：哪个可信主体，在什么租户和时间，尝试或完成了什么动作，作用于哪个目标，结果是什么，能通过哪个 trace 关联技术证据。记录过少无法归责；记录密码、Token、完整联系人和业务正文又把日志系统变成新的泄密数据库。

FactoryCare 将核心审计与普通调试日志分开。工单状态变化、角色授予/撤销等受保护业务动作在业务事务内经 `AuditAppendPort` 追加最小事件；审计写失败时业务整体回滚。outbox 消费者可以补充派生证据，却不能是核心审计的唯一来源。查询和导出继续按当前 tenant/data scope 授权并脱敏。

## 1. 完成定义与证据入口

完成本章，应能：

1. 区分调试日志、审计事件、业务历史、分布式 trace、指标与 outbox 事件的用途和可靠性；
2. 为登录、越权拒绝、状态变更、管理员操作定义稳定 event schema；
3. 让每条事件包含 actor/action/target/tenant/time/result/trace 等可归责字段，而不记录秘密或完整 PII；
4. 区分 ATTEMPTED、DENIED、SUCCEEDED、FAILED，避免事务回滚后仍声称成功；
5. 解释 append-only、最小写权限、同事务追加、完整性校验、备份和受控查询如何共同保护审计；
6. 为不同数据类别定义目的、访问者、保留期与删除/脱敏策略，不用“永久保留以防万一”；
7. 用 traceId 关联证据但不把 traceId 当 actor、权限、业务 ID 或秘密容器；
8. 注入密码/Token、缺 tenant/actor、伪成功、跨租户查询，得到稳定红灯并修复。

配套入口：

- [审计事件示例](../../../examples/encyclopedia/ch.security.audit-events-privacy/README.md)
- [审计与隐私故障实验](../../../labs/encyclopedia/ch.security.audit-events-privacy/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.security.audit-events-privacy/README.md)

## 2. 六种“记录”不是一张表

### 2.1 调试/应用日志

调试日志帮助定位代码路径和运行错误，可按级别采样、滚动、聚合，内容和格式可能随版本变化。它通常不是强事务事实，日志后端失败不应总让业务回滚。开发时的 `logger.debug(dto)` 也不能因为方便就进入生产。

### 2.2 安全/业务审计事件

审计事件是稳定、结构化、受访问控制的归责记录。事件类型与 schema 要版本化，关键字段不能随日志文案改变。核心状态变化和管理员动作的成功审计必须与业务事实一致；拒绝/失败审计则明确表示尝试，没有伪造业务成功。

### 2.3 业务历史

`work_order_transition`、assignment、approval 等是领域事实，决定当前业务状态如何演变。审计可以引用和摘要这些事实，但不能替代它们；也不能删除业务历史后指望从审计字符串重建聚合。

### 2.4 Trace 与 Span

trace 描述一次请求跨组件的执行路径、时延和错误，可被采样，生命周期通常不同。traceId 是关联键，不是身份或授权证据。攻击者可提交伪造 trace header，入口应验证格式并按信任边界决定继续或重启。

### 2.5 指标

指标回答“多少、多久、是否异常”，例如授权拒绝率、审计写失败数。高基数 actor/object 不应无边界塞进 metric label。指标无法提供每次动作的完整归责。

### 2.6 Outbox/集成事件

outbox 可靠地表达需要跨进程传播的业务事件，消费者可能重复或延迟。审计不应只等待消费者生成，否则队列停摆时核心动作已完成却没有即时证据。FactoryCare 同事务写业务、核心审计和 outbox；异步只补派生证据。

## 3. 审计事件的稳定 schema

一个可用的最小事件可包含：

- `eventId`：内部不可变唯一标识，不使用可猜顺序号暴露规模；
- `schemaVersion` 与 `eventType`：让消费者知道字段语义；
- `occurredAt`：业务动作发生的 UTC 时间；必要时另有 observedAt；
- `tenantId`：当前可信 tenant，GLOBAL 平台事件需显式 scope，不能空值猜含义；
- `actorType/actorId`：HUMAN、SERVICE、SYSTEM 等受控类型和内部引用；
- `onBehalfOf`：服务代用户执行时分开记录，不能把服务伪装成人；
- `action`：稳定动作代码，如 `WORK_ORDER_CLOSE`、`ROLE_ASSIGN`；
- `targetType/targetId`：受影响对象的类型与内部 ID；
- `result`：ATTEMPTED、DENIED、SUCCEEDED、FAILED 等稳定语义；
- `reasonCode`：机器可分析的受控原因，不放异常全文；
- `beforeSummary/afterSummary`：允许字段的最小变化摘要或摘要哈希；
- `traceId`/`requestId`：关联技术证据；
- `source`：产生事件的模块/入口；
- `policyVersion`/`aggregateVersion`：需要时说明按哪个规则/事实版本判断。

不是每类事件都填满所有字段，但必需字段按 event type 明确，不能任意 Map。登录失败可能没有内部 actorId，此时记录 actorType=UNRESOLVED、受控身份提示摘要和当前 tenant 是否已知，绝不能把密码或完整 subject 填进去。

## 4. actor、action、target 的归责边界

Actor 必须来自已验证 SecurityContext/内部服务身份，而不是请求体的 `actorId`。管理员替另一个成员执行、系统定时任务、AI 建议由人采纳，需要区分发起人、执行服务与最终人类决定人。否则“service-account 做了”掩盖真实责任，“用户做了”又把自动行为错误归给人。

Action 使用稳定业务语义，不用 `POST /api/v1/...` 或 Java 方法名作为唯一动作。HTTP 路由会重构，同一业务动作也可能由消息或管理工具触发。可以同时记录入口，但主 action 对齐 permission/command catalog。

Target 记录类型和 ID，而不是把完整对象 JSON 放进 before/after。对于批量操作，记录范围条件、批准理由、结果计数和导出 manifest ID；不要在一条事件嵌入十万联系人。目标不存在或对 actor 隐藏时，只记录请求提供的安全摘要，不能为了审计先越权读取对象。

tenant 是归责的硬边界。审计查询必须按当前 tenant/data scope；平台事件显式 scope。缺 tenant 不能自动归入“系统全局”，否则既不可追责又可能跨租户暴露。

## 5. 四类必须可重放的事件

### 5.1 登录与认证

记录登录成功、失败类别、登出、成员禁用导致拒绝、Provider 错误等。成功事件关联内部 actor/membership 与 tenant；失败不记录原始用户名、密码、authorization code、Token 或完整 OIDC subject。IP/user-agent 是否记录取决于风险目的、法律基础与保留策略，并要归一化、最小化。

### 5.2 越权拒绝

记录已认证主体尝试的 action、目标引用、tenant、策略 reason、trace 和结果 DENIED。不要把目标 tenant、名称或敏感摘要写给当前 actor 的事件可见面。拒绝高峰可形成指标，但单条事件仍需受控访问，避免攻击者用审计查询反向枚举资源。

### 5.3 状态变更

关闭、重开、审批、派单/转派等成功动作在业务事务中追加。事件引用业务 transition/assignment/approval，记录允许字段的 before/after 状态、aggregate version 和 reason。若事务回滚，不存在 SUCCEEDED 事件；可由外层单独记录 FAILED attempt，但必须与成功表分开语义。

### 5.4 管理员/高风险操作

角色授予/撤销、成员禁用、知识发布/撤回、审计导出等需要 actor、target、明确理由、高风险确认、前后摘要与当前权限。tenant_admin 不等于全平台，审计导出本身也要产生审计并使用短时下载。

## 6. 成功、失败与事务真相

最危险的顺序是：业务开始前先写 `WORK_ORDER_CLOSED/SUCCEEDED` 日志，然后事务因为乐观锁或审计失败回滚。调查者会看到不存在的成功。正确做法按事件类型选择：

1. 核心成功审计作为业务事务的一部分，在状态/历史/outbox 都成功时提交；
2. 业务验证失败可追加 DENIED/FAILED 尝试，但不能写成功 after 状态；
3. 基础设施异常若事务整体不可用，可用独立受限安全通道记录“尝试失败”，并明确没有业务提交；
4. `afterCommit` 监听可做通知/派生日志，不可成为核心审计唯一来源。

FactoryCare `FC-AUD-001` 注入 AuditAppendPort 写失败，要求 work order、transition、approval/assignment、core audit 和 outbox 全部回滚。`FC-AUD-002` 暂停异步消费者后，核心命令成功仍要立即查到同事务审计；恢复消费只增加派生证据且不重复。

授权拒绝与业务冲突也不同。403 的 DENIED 表示无权；409 的 FAILED/CONFLICT 表示有权主体遇到状态/version 规则。稳定 result+reasonCode 比自然语言 message 更可靠。

## 7. Append-only 到底保证什么

Append-only 意味着普通业务身份只能追加，不能 UPDATE/DELETE 已有事件。查询和导出使用独立只读权限；保留清理使用受控治理流程，而不是应用普通写接口。数据库约束确保 eventId 唯一、必需字段非空、result/action 类型有效、tenant/scope 组合合法。

仅禁止 UPDATE 不等于不可抵赖。DBA、存储管理员或攻击者可能拥有更高权限；时钟、身份映射和应用本身也可能被攻陷。完整性需要最小数据库角色、变更审计、备份、访问监控、受控迁移与恢复演练。哈希链/签名可提供篡改检测纵深，但密钥保护、canonical serialization、重锚、删除与分区会增加复杂度；没有这些运行证据时不能声称“不可篡改”。

审计存储故障的业务策略按动作风险确定。FactoryCare 核心受保护状态/权限动作采用 fail closed、同事务回滚；大量低价值诊断日志不能让全系统停摆。将两者分开，才能既保持核心证据又控制可用性。

## 8. 数据最小化不是“全部打码”

最小化从目的开始：调查登录攻击需要什么？证明角色授予需要什么？关联一次关闭操作需要什么？只收集与目的相关、足够、可解释的数据。先做字段允许列表，再决定 mask/hash/encrypt，而不是把完整 DTO 序列化后用正则找敏感词。

典型禁止直接记录：

- 密码、一次性验证码、恢复 Token；
- Access/ID/Refresh Token、authorization code、client secret、Session/Cookie；
- 数据库连接串、私钥、对象存储签名 URL；
- 完整联系人、身份证件、健康/脆弱人群信息；
- 完整 Prompt、附件、知识正文或异常请求 body；
- 客户端可控的换行/控制字符未经编码的值。

可记录内部稳定 ID、受控 event/action/reason code、必要状态前后值、字段名集合、计数、大小、摘要哈希和脱敏显示。哈希并不自动匿名：邮箱、手机号等低熵值可被字典猜测；若需关联，使用受控 HMAC/tokenization，并管理密钥、轮换和用途。

mask 应保留最少诊断价值，如联系方式只显示末尾少量字符；不同角色/导出有不同投影。加密保护静态数据但获授权查询仍可解密，不替代最小收集与访问控制。

## 9. PII、敏感信息与法律边界

什么是个人信息、保留多久、是否需要同意/通知，取决于司法辖区、劳动关系、客户合同和实际用途。本章不是法律意见，也不因采用某技术就声称 GDPR、网安法、数据安全法或行业监管合规。上线前需由组织确认数据分类、处理依据、权利请求、跨境、保留与删除规则。

可复用的工程原则是 purpose limitation、data minimisation、storage limitation：明确目的，只收必要字段，只保留必要时间。GDPR Article 5 是这些原则的一个正式来源，但 FactoryCare 练习引用原则不等于其适用性或合规结论。

隐私删除与审计保留可能冲突。解决方法不是“审计永不删”，而是按事件类别定义法定/合同目的、保留期限、主体标识去标识策略、legal hold 与删除证明。业务原文删除后，缓存、索引、导出、对象存储和备份也要按制度失效或到期。

## 10. Redaction 的正确位置

最好让敏感值从未进入记录对象。定义 AuditEvent DTO 只接收允许字段，而不是接收任意 Map/Throwable/Request 后过滤。集中 sanitizer 是纵深防御，用于意外字段、CRLF/log injection、长度与字符集；它不能保证识别所有语义秘密。

不要调用对象自动 `toString()` 记录整个认证对象、请求/响应、JPA entity 或 Provider payload。异常堆栈可能包含 URL/query/header/SQL 参数；生产错误记录异常类型、受控 message code 与 trace，原始异常只进入访问受限且仍脱敏的诊断通道。

Redaction 失败应如何处理要明确。核心审计若发现禁止字段，宁可拒绝该事件并使受保护业务回滚，也不能存秘密；普通日志 exporter 可丢弃并增加 redaction_failure 指标。不能把未脱敏事件作为 fallback 写本地文件。

## 11. Trace 关联与责任

OpenTelemetry Log Data Model 可携带 Timestamp、ObservedTimestamp、TraceId、SpanId、Severity、Body、Resource、Attributes 与 EventName。TraceId/SpanId 让日志与 trace 关联，但字段可选且不证明某条审计存在。若 SpanId 存在，规范建议也有 TraceId。

W3C Trace Context 要求 traceparent/tracestate 不包含 PII 或敏感信息；traceId 应随机且格式受限。外部客户端可以提交 header，因此入口要验证格式、限制长度，跨信任边界可按策略重启 trace。不要把 userId、tenantId、工单号编码进 traceId/tracestate。

追踪责任链可以是：audit event 的 traceId → API span → domain command span → SQL/outbox span → consumer span。但 actor/tenant/action 来自审计字段和可信上下文，不从 trace 推断。采样可能丢 span，核心审计仍保留；反之完整 trace 也不替代 append-only 成功事件。

## 12. Spring Security 能提供什么

Spring Security 会产生认证成功/失败、授权拒绝等事件和异常，应用可监听并转换为受控安全审计。框架事件包含的 Authentication、request、exception 可能很丰富，不应整个序列化；只提取允许字段。认证失败时账号是否存在也不能通过审计 API 泄露。

授权事件能说明框架执行点的结果，却不知道 FactoryCare 的业务状态变化和事务是否提交。`@EventListener` 或异步 listener 不能自动满足核心审计原子性。业务模块在 Application Service 事务中调用 `AuditAppendPort`；Spring 安全事件用于登录/拒绝和补充证据。

Spring 默认日志、Actuator、HTTP access log 与异常 handler 会随版本/配置变化。必须测试成功与异常路径，扫描 Authorization、Cookie、Token、签名 URL 和完整 PII。把应用 logger 级别调低不能修复审计 schema。

## 13. 多租户审计查询与导出

审计本身是敏感租户数据。FactoryCare `/api/v1/audit-logs` 只返回当前 actor data scope 内的 masked append-only entries，按时间窗口分页，并可按 objectType/objectId 查询。即使 event 表有 tenantId，也还要执行 `AUDIT_READ` 与 organization scope。

导出风险更高：`AUDIT_EXPORT` 需要明确 reason、高风险确认、时间范围、字段投影、数量上限、当前权限；异步 job 绑定 tenant/actor。完成后返回短时私有下载，撤权或过期后拒绝。下载 manifest 记录行数、字段版本、生成时间和摘要，不在应用日志打印导出内容。

跨租户平台调查走独立受控通道，不在普通 API 传 `tenantId=null`。查询 SQL、缓存键、export job、对象 key 与 audit-of-audit 都带 tenant。`FC-AUD-003` 验证非审计人、越组织或旧权限链接拒绝。

## 14. 保留、删除与分层存储

每个 event type 建立数据目录：目的、字段、分类、生产者、消费者、访问角色、热/冷存储、保留期、删除方式、legal hold、备份到期。登录拒绝可能短于核心权限变更；导出对象短于导出 job 元数据；调试日志通常短于审计。

append-only 与按策略到期删除并不矛盾：普通应用不能任意改写，受治理的分区销毁/去标识流程按批准策略执行并记录证明。删除要同步搜索索引、缓存、导出与对象存储；备份按独立保留周期自然到期，不承诺即时擦除无法做到的介质。

容量不是无限的。自由文本、完整 before/after、异常 body 会使成本和泄露面同时膨胀。结构化小事件、字段长度限制、批量摘要和冷热分层更可持续。审计量异常也是检测信号，不能静默丢弃核心事件。

## 15. 故障注入与第一处可信证据

### 15.1 记录密码或 Token

异常路径把 request DTO/Authorization header 序列化。第一处可信证据是事件构造器输入与最终 sink 前扫描。修复字段允许列表、专用 DTO 和 sanitizer；立即撤销泄露凭据、限制/清理存储并调查访问，不是只改未来日志。

### 15.2 缺 tenant

平台把空 tenant 当 GLOBAL，导致普通事件跨租户可见。第一处证据是 schema constraint 与 context 来源。修复 tenant 必填或显式 scope，GLOBAL 仅受控事件类型；回填不能靠 actor 名猜 tenant。

### 15.3 缺 actor

后台任务写 `actor=null`，无法区分系统、服务与代用户。第一处证据是任务 envelope/on-behalf context。修复 actorType、serviceId 与可选 onBehalfOf，并在任务入口重建，而不是使用线程名。

### 15.4 事务失败却声称成功

业务 rollback 后仍有 SUCCEEDED event。第一处证据是 audit commit 与业务 commit 的事务边界及 event result。修复核心成功审计同事务；失败尝试另写 FAILED，不携带不存在的 after 状态。重跑 AuditAppendPort 故障与乐观锁冲突。

### 15.5 只靠消息消费者生成核心审计

暂停消费者后业务成功但审计为空。第一处证据是 outbox 与 core audit 行数。修复业务事务直接追加，消费者仅补来源分类；恢复消费后不得重复核心事件。

### 15.6 before/after 保存完整对象

角色变更事件把完整 membership、联系人、Token claim 写入 JSON。第一处证据是 schema 字段和 serialized size。修复只保留变化字段名、旧/新受控代码、版本与摘要；敏感投影不进入审计。

### 15.7 traceId 被当身份

攻击者复用别人 trace header 后查询到其事件，或事件 actor 从 trace baggage 读取。第一处证据是授权/查询参数来源。修复 trace 只关联，actor/tenant 从 SecurityContext；查询仍要求权限和范围。

### 15.8 跨租户审计导出

A 导出任务使用 objectId 筛选却没 tenant，文件含 B。第一处证据是 export SQL、job context 与 manifest count。修复 tenant/scope 条件、短时对象授权并用 A/B 同 ID fixture 重跑。

## 16. 可重放验证矩阵

| 场景 | 预期事件 | 隐私/完整性预言 |
| --- | --- | --- |
| 登录成功 | LOGIN SUCCEEDED | actor/tenant/time/trace；无凭据 |
| 登录失败 | LOGIN DENIED/FAILED | 稳定 reason；无账号枚举、密码、Token |
| 跨租户读取 | AUTHORIZATION DENIED | 当前 actor/tenant + 请求目标摘要；无 B 摘要 |
| 合法关闭工单 | WORK_ORDER_CLOSE SUCCEEDED | 与状态/transition/outbox 同事务 |
| 乐观锁冲突 | WORK_ORDER_CLOSE FAILED/CONFLICT | 无成功 after，无业务变化 |
| 审计端口写失败 | 无业务成功 | 业务/历史/audit/outbox 全回滚 |
| 角色授予 | ROLE_ASSIGN SUCCEEDED | actor/target/前后角色代码/reason |
| 非管理员自提权 | ROLE_ASSIGN DENIED | 无 membership_role 变化 |
| 消费者暂停 | 核心审计仍在 | 恢复只补派生证据 |
| audit 查询 A | 仅 A/scope 内 masked 行 | B 数量/摘要为零 |
| audit 导出 | reason + job + 短时下载 | 当前权限、字段白名单、manifest |
| secret scanner | 成功/异常日志与审计 | Token/Cookie/签名 URL/完整 PII 零命中 |

局部 Java 模型可证明 schema 和 redaction；真实 T4 必须用数据库事务故障、Spring Security 事件、OpenTelemetry/日志后端、双租户查询和私有对象存储。报告记录合成输入、操作、结果、业务行数和审计行数，不放真实秘密。

## 17. 标准、OWASP、框架与隐私边界

| 层 | 本章采用的结论 | 不能误读为 |
| --- | --- | --- |
| OWASP Logging Cheat Sheet | 记录 who/what/when/where/result；排除/脱敏 Session、Token、密码、密钥和敏感 PII；防日志注入 | 记录越多越安全，或普通日志等于审计账本 |
| OpenTelemetry Logs | 统一 LogRecord 字段、EventName、TraceId/SpanId 关联 | exporter 自动最小化字段或保证审计不丢 |
| W3C Trace Context | trace header 格式、随机 ID、隐私/安全注意；不含 PII | traceId 是可信 actor/tenant 或不可伪造 |
| Spring Security | 可观察认证/授权事件并扩展 handler/listener | 自动知道业务事务成功、字段保留和审计 schema |
| 隐私原则 | purpose/data minimisation/storage limitation；按适用规则治理 | 引用 GDPR/NIST 即证明 FactoryCare 合规 |
| FactoryCare 合同 | 核心审计同事务追加；异步非唯一来源；tenant-scope 查询与脱敏导出 | 已达到法律不可抵赖或防 DBA 篡改 |

稳定核心是用途分离、actor/action/target、结果真相、append-only、最小化和范围查询。版本敏感面是 OpenTelemetry 稳定状态/语义约定与 Spring 事件 API；2026-07-17 已核对，真实实现需锁定 SDK/Collector/后端组合并做端到端扫描。

## 18. 独立构建任务

定义四类事件：LOGIN、AUTHORIZATION_DENIED、WORK_ORDER_STATE_CHANGED、ADMIN_ROLE_CHANGED。每类写 required/allowed/forbidden 字段、成功/失败时机、保留类别与查询权限。实现 append-only 内存端口和 tenant-scoped 查询，再生成验证报告。

依次注入：敏感 details；缺 tenant；缺 actor；业务提交失败但 event SUCCEEDED；覆盖已有事件；跨租户 query。每项先产生命名红灯，定位构造、事务或查询的第一处证据，再修复并重跑。公开 exercise 首先以 `SECRET_FIELD_ACCEPTED` 失败，private solution 使用同一场景全绿。

## 19. 120 秒讲述模板

1. 调试日志、trace、业务历史、outbox 与审计目的不同，不能互相冒充；
2. 审计以 actor/action/target/tenant/time/result/trace 回答责任链，schema 稳定且 append-only；
3. 核心成功事件必须与业务事务一致，回滚不能留下伪成功；异步消费者不是唯一来源；
4. 字段从允许列表开始，密码、Token、Cookie、签名 URL、完整 PII/正文不进入；
5. traceId 只关联，查询/导出仍按当前 tenant、permission、scope 并脱敏；
6. 反例：先写 `CLOSE SUCCEEDED` 且附完整请求，事务随后失败，于是既泄密又伪造事实。

## 20. 资料与边界

- [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html)（安全日志建议，2026-07-17 核对）
- [OpenTelemetry Logs Data Model](https://opentelemetry.io/docs/specs/otel/logs/data-model/)（可观测数据模型，2026-07-17 核对）
- [W3C Trace Context](https://www.w3.org/TR/trace-context/)（追踪格式与隐私边界，2026-07-17 核对）
- [NIST Privacy Framework](https://www.nist.gov/privacy-framework/privacy-framework)（隐私风险治理参考，2026-07-17 核对）
- [GDPR Article 5 official text](https://eur-lex.europa.eu/eli/reg/2016/679/oj)（最小化/存储限制原则来源；不构成适用性或合规意见）
- [FactoryCare threat model](../../../factorycare-design/security/threat-model.md)（`TM-15/16` 与隐私原则）
- [FactoryCare acceptance catalog](../../../factorycare-design/testing/acceptance-catalog.md)（`FC-AUD-001—003`、`FC-OBS-001—002`）

本章不选择 SIEM、日志供应商、WORM/签名设施、法定保留期、跨境机制或具体合规认证，也不实现数据库/对象存储和审计导出。离线资产通过不等于不可抵赖、合规或 G3 完成；只有同事务故障、双租户查询、秘密扫描、访问控制、保留/恢复证据齐全，才能声称生产边界已验证。
