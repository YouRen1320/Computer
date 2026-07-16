---
schema_version: 2
edition: 2026.2-draft
id: ch.security.multitenancy-data-isolation
title: 租户上下文、数据权限与跨租户隔离测试
responsibility: 教授从请求到持久化的租户约束和越权负测，不把前端隐藏或单字段过滤当作隔离
volume: '06'
order: 11
level: L2+
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.security.multitenancy-data-isolation.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.security.authorization-rbac-abac
version_surfaces:
- spring-security
- spring-boot-4.1
- mybatis
- postgresql-18
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
  text: 在 120 秒内解释租户上下文、数据权限与跨租户隔离测试的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - security-tenant-context
  - security-tenant-data
  covers_topics:
  - security.tenant-identity-context
  - security.tenant-propagation
  - security.tenant-trust-boundary
  - security.tenant-query-constraint
  - security.cross-tenant-negative-test
  - security.tenant-cache-boundary
  uses_capabilities:
  - security.authorization-policy
  - security.authentication
  - security.web-threat
  - backend.spring-persistence-tx
  - data.persistence-access
  - security.multitenancy-isolation
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：从认证主体建立不可由请求体覆盖的 tenant context，让 Repository 所有读写带租户条件并写跨租户集成测试
  covers_topic_groups:
  - security-tenant-context
  - security-tenant-data
  covers_topics:
  - security.tenant-identity-context
  - security.tenant-propagation
  - security.tenant-trust-boundary
  - security.tenant-query-constraint
  - security.cross-tenant-negative-test
  - security.tenant-cache-boundary
  uses_capabilities:
  - security.authorization-policy
  - security.authentication
  - security.web-threat
  - backend.spring-persistence-tx
  - data.persistence-access
  - security.multitenancy-isolation
  evidence_kind: system-artifact-and-negative-tests
  verification_mode: system-security-resilience-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入列表查询漏 tenant、缓存键漏 tenant 和后台任务未传播 context，使用同 ID 不同租户数据证明泄露后修复
  covers_topic_groups:
  - security-tenant-context
  - security-tenant-data
  covers_topics:
  - security.tenant-identity-context
  - security.tenant-propagation
  - security.tenant-trust-boundary
  - security.tenant-query-constraint
  - security.cross-tenant-negative-test
  - security.tenant-cache-boundary
  uses_capabilities:
  - security.authorization-policy
  - security.authentication
  - security.web-threat
  - backend.spring-persistence-tx
  - data.persistence-access
  - security.multitenancy-isolation
  evidence_kind: fault-injection-fix-rerun
  verification_mode: fault-injection-rerun
---
# 租户上下文、数据权限与跨租户隔离测试

> 本章状态为 `drafting`。配套资产只用内存中的合成租户、记录、缓存和任务模型验证不变量，不启动 Spring、MyBatis、PostgreSQL、Redis、消息队列或 Testcontainers。局部验证通过只能证明策略预言；不能证明真实 SQL、连接池、事务、RLS、缓存客户端或异步执行器已隔离。

多租户系统让一套应用服务多个相互隔离的客户组织。最大的危险不是页面把租户名显示错，而是租户 A 的主体读到、修改或推断出租户 B 的任何数据。隔离必须贯穿“认证主体 → tenant context → 授权 → Repository → SQL/约束 → 缓存 → 事件/任务 → 对象存储/AI”，任何一跳把 tenant 当可选字段都会形成横向越权。

FactoryCare 采用共享 schema、每行业务数据显式非空 `tenant_id`。这是成本和当前规模下的架构决定，不是声称达到物理隔离或监管认证。可信 tenant 来自服务端认证 membership；请求头、路径、query、请求体和 AI 工具参数里的 tenant 都不可信。普通业务不存在“管理员自动看全部租户”。

## 1. 完成定义与证据入口

完成本章，应能：

1. 区分 tenant、organization、team、data scope 与 GLOBAL catalog，不能把它们都叫“租户”；
2. 比较独立数据库、独立 schema、共享 schema 三种模型及其隔离/运维代价；
3. 从已验证身份与当前 membership 创建不可被 DTO 覆盖的 TenantContext；
4. 让所有 Repository 读、写、join、exists、count、聚合、分页与批量操作显式携带 tenant；
5. 用非空 tenant、复合唯一键/外键和受控 SQL 增加持久化防线；
6. 让缓存键、幂等键、事件、异步任务、对象键与 AI 检索都带可信 tenant/范围；
7. 解释 PostgreSQL RLS 的 default deny、`USING/WITH CHECK` 与 owner/BYPASSRLS/连接池边界，且不把 RLS 当唯一防线；
8. 使用两个租户和同局部 ID fixture 注入漏过滤、缓存污染和任务漏上下文，得到稳定红灯并修复。

配套入口：

- [租户隔离示例](../../../examples/encyclopedia/ch.security.multitenancy-data-isolation/README.md)
- [跨租户故障实验](../../../labs/encyclopedia/ch.security.multitenancy-data-isolation/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.security.multitenancy-data-isolation/README.md)

## 2. 先澄清五个容易混淆的范围

Tenant 是合同、数据所有权和隔离的客户边界。FactoryCare 示例中的“青岚设备服务”和“江右工业运维”是两个 tenant。即使它们都有名为 `ORG-01`、编号 `WO-0001` 的对象，也不能互相读取。

Organization 是 tenant 内的组织树节点；team 是 organization 内的工作组。它们用于数据范围与派单，不是新的 tenant。`TEAM` scope 必须有同 tenant、同 organization、已启用 team；仅比较 teamId 不足以防跨组织关联。

Data scope 是当前 membership 可见数据的范围：`SELF`、`TEAM`、`ORGANIZATION`、`TENANT`。`TENANT` scope 表示当前这个 tenant 内的全部授权数据，不表示全平台。它仍与 tenant context 求交。

GLOBAL catalog 是平台发布、跨租户定义的只读元数据，例如七个固定 role、permission 和 role-permission。每行显式 `scope=GLOBAL`，不是 `tenant_id=NULL` 的普通业务行。租户管理员只能绑定角色，不能改 GLOBAL catalog。

Platform operator/受控运维通道是例外能力，不是普通角色。跨租户排障或导出必须使用单独身份、显式理由、最小字段、短期授权与审计。不要在普通 Repository 中加入 `tenantId=null means all` 为未来省事。

## 3. 三种数据部署模型

### 3.1 每租户独立数据库

每个 tenant 有独立数据库/凭据，隔离和定制能力强，故障域与备份恢复可独立。代价是建租户、迁移、连接池、监控、跨租户运营报表和版本漂移复杂。它也不是自动安全：连接路由错了仍可能把 A 请求送到 B 库。

### 3.2 每租户独立 schema

同一数据库实例中按 schema 分离，介于物理库与共享表之间。迁移要覆盖所有 schema，search_path 与连接复用必须严格重置，schema 名不能来自未经验证请求。租户数增长后运维成本仍明显。

### 3.3 共享 schema、行携带 tenant

所有 tenant 共用表，每条租户业务行包含 `tenant_id`。它最利于统一迁移、连接池和学习项目，但任何漏 WHERE、join、cache key 或任务 context 都可能 P0 泄露。隔离依靠系统性约束，不靠开发者“记得加一个条件”。

FactoryCare 选择第三种。若将来客户要求物理隔离，迁移需按 tenant 导出、校验行数/哈希/对象 manifest、冻结写入、切换路由并保留可回放回滚；本章不假装当前已经具备此能力。

## 4. TenantContext 的信任来源

### 4.1 从认证主体建立

请求通过 Session/OIDC Access Token 验证后，Java 用稳定外部身份映射当前 `user_account` 与启用 membership。membership 决定 `tenantId`、organization/team、roles 和 dataScope。构造的 TenantContext 是服务端安全上下文的一部分，不是普通 DTO。

如果一个用户在多个 tenant 有 membership，必须先通过受控的租户选择/会话切换流程选择当前 membership，并重新签发/建立上下文。不能让每个 API 任意提交 tenantId 后从所有 membership 中挑一个。切换要轮换/更新本地会话语义并留下审计。

### 4.2 客户端 tenant 字段只能是待校验输入

有些创建命令为了契约清晰可能出现 parent resource ID，却不应接收权威 tenant。即使 DTO 有 tenantId，也必须忽略或与 context 比较后拒绝错配，不能用它覆盖 context。HTTP Header `X-Tenant-Id` 同理；除非专门的受控网关协议已认证并签名，它只是攻击者输入。

路径 `/tenants/{tenantId}/...` 可用于可读 URL，但服务端仍以 current membership 检查路径 tenant 是否等于上下文。隐藏选择器或前端 Pinia state 不形成信任边界。

### 4.3 生命周期与清理

TenantContext 应在请求/消息处理开始时创建，在结束时清理。不能把可变全局变量或静态字段保存当前 tenant；并发请求会相互覆盖。ThreadLocal 只与特定线程关联，而异步、虚拟线程、reactive、线程池切换会失去或泄露值。优先把不可变 Context 显式传到 Application Service/Repository；若框架上下文桥接存在，仍需执行器与异常路径测试。

## 5. 从 HTTP 到 Repository 的传播

可靠传播不是“每层都从请求头再读一次”，而是入口认证一次建立可信上下文，后续层只接收服务端对象。Controller 不把 tenant 作为任意业务参数；Application Service 同时执行 permission/data scope；Repository 方法签名要求 TenantId 或 TenantScope。

例如：

```text
listVisibleWorkOrders(TenantScope scope, WorkOrderFilter filter)
assignWorkOrder(TenantContext actor, WorkOrderId id, AssignmentCommand command)
findByTenantAndId(TenantId tenant, WorkOrderId id)
```

避免暴露业务端口 `findById(id)` 再让调用者决定是否补过滤。若 ORM/Mapper 仍生成这种方法，架构测试应禁止它进入租户业务端口。调用方无法省略参数，比代码评审提醒更可靠。

tenant context 不等于完成授权。tenant 相同后仍要检查 organization/team/SELF、owner/assignment、permission 与状态。隔离先把候选集合限制在 tenant 内，授权再收窄；二者都必须满足。

## 6. 表结构与约束是第二道防线

所有租户业务表将 `tenant_id` 定义为 NOT NULL，并与业务唯一键组合。例如工单号唯一通常是 `(tenant_id, number)`，而不是全平台 number 唯一或只在应用先查。相同编号可在两个 tenant 正常存在，数据库仍防止同 tenant 重复。

跨表引用尽量使用复合约束，如 assignment 的 `(tenant_id, work_order_id)` 引用 work_order 的同组键，避免 A tenant 的行引用 B tenant 的工单。单列 UUID 全局唯一虽降低碰撞，却不能证明归属一致；恶意或代码错误仍能写错关联。

INSERT 的 tenant 由 context 写入，不从客户端实体复制。UPDATE/DELETE 的 WHERE 同时包含 tenant 与 id，并断言影响行数；`UPDATE work_order SET ... WHERE id=?` 即使之前查过一次也保留竞态/绕过窗口。跨 tenant ID 应更新零行并映射为拒绝/不可见，而不是先泄露“它属于 B”。

数据库约束不是完整授权。NOT NULL、FK、unique 能防结构不一致，却不知道当前 actor 是否有权限；应用 policy 仍在事务中执行。反过来，只靠应用 if 也不能阻止漏写 SQL 或维护脚本产生坏关联。

## 7. MyBatis 中最危险的“可选 tenant”

MyBatis 只执行映射 SQL，不自动理解多租户。`#{tenantId}` 是安全参数绑定，但 SQL 中必须真的存在正确条件。特别危险的写法是：

```xml
<if test="tenantId != null">
  AND tenant_id = #{tenantId}
</if>
```

tenant 一旦因传播错误为 null，查询就变成全表。安全字段应是必需参数；缺失在调用/参数验证处失败，而不是动态省略。动态 `<where>` 能整理 AND，不会替你决定安全谓词。

每类 SQL 都要检查：

- 单条读取：`WHERE tenant_id=? AND id=?`；
- 列表/分页：tenant 条件在 count 与 page query 都存在；
- join：每个租户业务表的关联 tenant 一致，不能只过滤主表；
- exists/唯一检查：只在当前 tenant；
- update/delete：tenant 在写谓词且验证影响行数；
- batch/foreach：每条元素归属当前 tenant，不能混合；
- aggregate/report：分组和源行都限定 tenant/data scope；
- 子查询/CTE/union：每个数据来源保持边界，不能外层过滤后内层泄露侧信道。

不要用 SQL 字符串拦截器盲目给所有表拼 `tenant_id` 作为唯一方案。它可能破坏 alias、子查询、GLOBAL catalog、迁移或管理通道。若采用插件，必须有表分类、显式 escape hatch、启动校验和真实 SQL 测试；Repository API 与数据库约束仍保留。

## 8. 读取、写入和“不可区分不存在”

租户 A 请求 B 的 object ID 时，可以返回 403 或按合同表现为 404；关键是不返回 B 的名称、状态、tenant、时间、ETag 或差异化错误。FactoryCare `FC-TEN-001` 要求读取为零，不返回摘要；`FC-TEN-002` 要求写入原子拒绝，所有相关表无变化。

先执行 `SELECT * WHERE id=?` 再在 Java 比 tenant，会把 B 数据带入应用内存、日志或追踪；更安全的是仓库按 tenant 查询，得不到即不可见。对于需要记录越权安全证据的场景，也应记录请求 object ID 与当前 tenant 的脱敏摘要，而不是读取/记录目标 tenant 的内容。

写命令需要在事务内读取当前 tenant 行、检查授权/状态/version，再更新同 tenant 行、历史、审计和 outbox。失败时业务副作用为零。不要在 Controller 先 `existsById`、Service 后无 tenant 更新。

## 9. organization、team 与 data scope

tenant 条件只是最大边界。`ORGANIZATION` scope 只能看到同 tenant 的指定组织子树；`TEAM` scope 还必须匹配有效 team；`SELF` 通常基于 owner/reporter/assignee 关系。scope 从当前 membership 重建，不能相信请求传来的 organizationId/teamId。

派单/转派要同时检查工单、目标 team、可选 technician 都属于同 tenant 和合法 organization。只比较 teamId 或 technicianId 可能跨边。membership `data_scope=TEAM` 但 teamId 为空、禁用、他组织或他 tenant 必须在写入时拒绝，而不是查询时猜默认范围。

GLOBAL catalog 不走普通 data scope，但必须是显式只读平台资源。`scope=TENANT` 的 catalog 行必须非空 tenant；绝不让 NULL 同时表示“全局”和“忘了写 tenant”。

## 10. 缓存边界

缓存能绕过正确数据库查询。键若只有 `work-order:{id}`，A 先热缓存、B 使用同局部 ID/可猜 ID 查询，可能直接收到 A 投影。安全键至少包含 schema version、tenant、资源类型、ID 与必要 scope/version，例如：

```text
fc:v2:tenant:TENANT-A:work-order:WO-LOCAL-1:version:7
```

但把 tenant 写进 key 仍不等于授权。读取敏感详情前应重验当前 membership/permission；成员禁用或 scope 撤销不能等待缓存 TTL。缓存 value 也应最小化，不把完整 PII/Token 放进去。

列表缓存还要包含 organization/team/filter/page/sort/permission projection；否则同 tenant 不同 scope 也会串数据。失效消息与防击穿锁同样需要 tenant。Redis 不可用时回源数据库或安全失败，不能绕过 policy。

## 11. 异步任务、事件与消息

HTTP 线程结束后，ThreadLocal tenant 不会自动成为后台任务事实。任务/事件 envelope 必须显式包含 tenantId、actor/reference、事件类型、版本、trace/correlation 与资源 ID，并在消费者入口验证 schema、tenant 和当前权限需要。消费者用消息 tenant 构建受限上下文，不接受 payload 中任意“isAdmin”。

定时任务若逐租户运行，应先列出受控 tenant 集合，再为每个 tenant 创建独立 context；单个 tenant 失败不能让下一轮复用旧 context。线程池 `finally` 清理不足以证明正确，因为任务可能根本没设置；显式参数更可测试。

outbox 与业务行在同事务保存 tenant。消费、幂等记录、重试、死信和派生读模型继续保留 tenant。重放工具不能以“运维”名义调用无作用域 Repository。

## 12. 对象存储、搜索与 AI 也属于隔离

私有对象不能仅凭 object key 下载；Java 先根据 attachment/knowledge 的 tenant 与父资源授权，再发短时 URL。对象 key 最好包含不可猜的内部前缀，但 key 难猜只是纵深防御。manifest、扫描状态和删除任务都带 tenant。

AI 的 chunk、embedding、source version、eval run 与 tool call 继续携带 tenant。检索必须先按当前 tenant、发布状态、ACL 过滤，再排序；不能先跨租户 top-k 后删结果，因为排名、计数和错误也可能泄露。Python 无权直接读取 `core`，只通过 Java 受控只读工具获得已授权摘要。

日志与 trace 记录 tenant 的内部稳定引用可帮助诊断，但不得把客户名称、联系人或业务正文塞进传播 header。审计细节由下一章讲述。

## 13. PostgreSQL RLS：纵深防御而非单点神话

PostgreSQL 18 的 Row-Level Security 在表启用 RLS 后，让普通行访问必须满足 policy；若没有适用 policy，默认拒绝。`USING` 控制可见/可更新的旧行，`WITH CHECK` 控制新行/更新后行。策略可按命令和数据库角色设置，多条 permissive/restrictive policy 的组合语义要明确。

关键边界：superuser 与 `BYPASSRLS` 角色总能绕过；表 owner 通常也绕过，除非 `FORCE ROW LEVEL SECURITY`；`TRUNCATE` 与某些完整性检查不由普通行 policy 覆盖；唯一/FK 错误可能形成存在性侧信道。生产应用不能用 owner/superuser 连接后声称 RLS 保护。

共享连接池尤其危险。若用 `SET app.tenant_id`/`current_setting`，必须在事务边界设置并保证释放前复位；异常、自动提交、嵌套事务、后台连接和迁移连接都要测试。更稳妥的做法通常是事务本地设置、专用非 owner 角色和 fail-closed policy，但具体实现要通过目标驱动验证。

FactoryCare ADR 只把 RLS 定为后续纵深实验。应用 TenantContext、Repository tenant 参数、复合约束和双租户测试是主防线；RLS 不能掩盖无作用域 API。

## 14. Spring Security 与上下文传播

Spring Security 的 Authentication/SecurityContext 提供认证主体起点，应用从当前 membership 构建业务 TenantContext。框架不会自动把 `tenant_id` 加入 MyBatis SQL，也不知道 organization/team/data scope。把 tenant 放在 JWT claim 后直接用仍有陈旧 membership 与伪造 issuer 风险。

SecurityContext 在不同执行模型中的传播策略版本敏感。异步执行器、调度任务、消息监听、虚拟线程或 reactive context 不能凭 ThreadLocal 直觉。即使使用 DelegatingSecurityContext 工具，也要决定传播的是哪个主体、何时重验权限，并防止线程池复用旧上下文。

异常处理必须清理上下文；但最理想是 Repository 不从隐式 ThreadLocal 猜 tenant，而从方法参数获得。测试可在没有 Web 请求的 Service/任务入口证明 tenant 仍必填。

## 15. 双租户 T4 测试设计

单元测试可证明过滤函数，却不能证明真实 Mapper、SQL、约束和连接池。最低集成 fixture 包含 tenant A/B，各自拥有相同本地业务编号、相似组织/team、不同 owner，另有 GLOBAL catalog。使用 PostgreSQL 18 容器与实际 migrations、MyBatis mapper 运行。

必须覆盖：

| 场景 | 操作 | 预期预言 |
| --- | --- | --- |
| A 读取 A 同 ID | list/get | 只返回 A |
| A 读取 B object ID | get | 403/404，零摘要 |
| A 更新/删除 B ID | write | 影响 0 行，所有业务表不变 |
| A 创建引用 B parent | insert | 应用拒绝或复合 FK 失败 |
| A/B 同业务编号 | insert | 各自成功；同 tenant 重复失败 |
| 列表/count 分页 | query | items 与 total 都仅当前 tenant |
| join/aggregate | query | 无 B 字段、计数或分组 |
| 缓存 A 后查 B | cache | B 不命中 A value |
| 禁用 A membership | cached read | TTL 内立即拒绝 |
| 后台任务缺 tenant | execute | fail closed，不执行查询 |
| 任务 A 后任务 B | pool reuse | 无 context 串线 |
| RLS context 缺失/错误 | SQL | 默认零行/拒绝，不回全表 |

每个拒绝还要断言日志不含 B 摘要、审计使用当前 A tenant/actor，并记录 SQL/行数等第一处证据。测试失败立即阻断，因为跨租户是 P0，不允许标 flaky 后重跑到绿。

## 16. 故障注入与诊断

### 16.1 列表漏 tenant

详情查询安全，列表却返回 A+B。第一处可信证据是实际 BoundSql/数据库结果，不是 Controller DTO。检查列表 SQL、count SQL、join/CTE 和动态条件。修复为必需 tenant 参数并重跑双租户同编号 fixture。

### 16.2 写操作只按 ID

A 用 B ID 更新成功。第一处证据是 UPDATE WHERE 与影响行数。修复 `WHERE tenant_id=? AND id=? AND version=?`、复合关联约束和事务前后快照；不要只在前端隐藏 ID。

### 16.3 请求字段覆盖 context

A body 提交 `tenantId=B` 后创建 B 行。第一处证据是 DTO→Entity 映射和 INSERT 参数来源。修复为 tenant 只取 TenantContext，若契约仍含字段则错配拒绝；添加 forged header/body/path 三类负测。

### 16.4 缓存键漏 tenant/scope

A 热缓存后 B 得 A 投影。第一处证据是 cache key 与 value provenance。修复键包含 tenant/scope/version并在命中后重验当前授权；清除受污染缓存并重跑 A→B、B→A 顺序。

### 16.5 后台任务没传播

任务缺 context 时调用无 tenant `findAll`，或线程复用 A 后把 A tenant 带进 B。第一处证据是任务 envelope 与 Repository 参数；修复显式 TenantId、入口校验、不可省略 API，而非仅加 finally remove。

### 16.6 join 只过滤主表

work_order 属于 A，但错误 assignment/attachment 关联 B，join 返回 B 字段。第一处证据是 join ON 条件和数据约束。修复关联 tenant 相等与复合 FK，加入故意坏引用 migration fixture/约束测试。

### 16.7 `tenant_id=NULL` 当 GLOBAL

业务行漏 tenant 后被全体读取。第一处证据是 scope/tenant check constraint。修复显式 `GLOBAL|TENANT`，GLOBAL 走只读 catalog，TENANT 必须非空；不保留 NULL 通配兼容语义。

### 16.8 RLS 连接身份绕过

测试账号安全，生产 owner 连接看到全表。第一处证据是 `current_user`、role 属性、table owner、RLS/FORCE 状态和 session setting，不是 policy 文件存在。修复专用非 owner 连接与部署检查，并保留应用过滤。

## 17. 标准、OWASP 与框架行为分层

| 层 | 本章采用的结论 | 不能误读为 |
| --- | --- | --- |
| NIST/ABAC 授权模型 | tenant、scope、关系是策略属性；每次对象访问都判定 | tenant claim 本身自动可信 |
| OWASP Multi-Tenant/Authorization/IDOR | tenant 从可信上下文建立；数据访问层执行；每次对象访问检查；多账号负测 | UUID 难猜或 UI 隐藏可以隔离 |
| PostgreSQL 18 | RLS `USING/WITH CHECK`、无 policy 默认拒绝；owner/BYPASSRLS 等明确绕过 | 启用 RLS 就无需应用 tenant 条件 |
| MyBatis 3.5.x | Mapper 显式生成 SQL、参数绑定、动态 SQL | 框架会自动补 tenant，或可选 `<if>` 安全 |
| Spring Security/Boot 4.1 | 提供认证主体与安全上下文机制 | 自动传播业务 tenant 到 SQL/缓存/任务 |
| FactoryCare ADR | 共享 schema、非空 tenant、复合约束、RLS 纵深、双租户验证 | 已实现物理隔离或监管合规 |

稳定核心是信任来源、必需 tenant、每层传播、默认拒绝与双租户负测。版本敏感面是 Spring 上下文传播、MyBatis Starter 4.x 组合、PostgreSQL 18 RLS/驱动/连接池和 Testcontainers 镜像；2026-07-17 已核对官方资料，真实实现仍锁定 patch 与镜像。

## 18. 独立构建任务

交付一个 TenantContext、一个只能按 tenant 调用的 Repository 端口，以及双租户验证报告。报告至少覆盖 list/get/update/cache/background 三条链，A/B 具有同局部 ID。先预测每个故障应在哪层红灯，再注入列表漏 tenant、缓存键漏 tenant、任务缺 context，记录实际第一处证据，修复后重跑原断言。

公开 exercise 刻意让 `tenantMatches` 返回 true，首先产生 `FORGED_TENANT_ACCEPTED`；private solution 以相同输入全绿。离线资产不使用 SQL，真实 T4 仍必须用 migrations、MyBatis 与 PostgreSQL 容器完成。

## 19. 120 秒讲述模板

1. FactoryCare tenant 是客户隔离边界，organization/team/dataScope 只能在 tenant 内收窄；
2. 可信 tenant 来自已认证的当前 membership，不能被 header/path/body 覆盖；
3. Repository 每个读写、join、count、bulk 都把 tenant 作为必需条件，数据库用非空与复合约束纵深；
4. 缓存、任务、事件、对象与 AI 同样带 tenant，不能只保护 HTTP；
5. RLS 可纵深，但 owner/BYPASSRLS/连接池配置会绕过，不能是唯一防线；
6. 反例：列表 SQL 漏 tenant，A 用同 ID fixture 读到 B，即使详情页和 UI 都正确仍是 P0。

## 20. 资料与边界

- [OWASP Multi-Tenant Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Multi_Tenant_Security_Cheat_Sheet.html)（实施建议，2026-07-17 核对）
- [OWASP IDOR Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Insecure_Direct_Object_Reference_Prevention_Cheat_Sheet.html)（对象负测，2026-07-17 核对）
- [PostgreSQL 18 Row Security Policies](https://www.postgresql.org/docs/18/ddl-rowsecurity.html)（数据库行为，2026-07-17 核对）
- [MyBatis 3 Dynamic SQL](https://mybatis.org/mybatis-3/dynamic-sql.html)（框架行为，2026-07-17 核对）
- [FactoryCare ADR-0002](../../../factorycare-design/adrs/0002-pooled-multitenancy.md)（项目设计基线）
- [FactoryCare threat model](../../../factorycare-design/security/threat-model.md)（`TM-01/11/23/24`）

本章不实现物理数据库拆分、schema 路由、跨租户平台运维、RLS 上线、Redis、AI 数据库或审计存储；只定义它们必须延续的 tenant 不变量。通过离线资产不代表 G3 完成；只有双租户真实数据库、缓存和异步链证据齐全，才能声称隔离已验证。
