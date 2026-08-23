---
schema_version: 2
edition: 2026.2-draft
id: ch.security.authorization-rbac-abac
title: URL/方法授权、RBAC、ABAC 与默认拒绝
responsibility: 教授对已认证主体执行显式资源访问策略，不在本章实现租户数据过滤或审计存储
volume: '06'
order: 10
level: L2+
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.security.authorization-rbac-abac.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.security.jwt-resource-server
- ch.spring.transactions
version_surfaces:
- spring-security
- spring-boot-4.1
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释URL/方法授权、RBAC、ABAC 与默认拒绝的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - security-authorization-enforcement
  - security-rbac-abac
  covers_topics:
  - security.url-method-authorization
  - security.object-authorization
  - security.authorization-default-deny-policy
  - security.rbac
  - security.abac
  - security.policy-conflict
  uses_capabilities:
  - security.authentication
  - security.web-threat
  - backend.spring-mvc-contract
  - security.authorization-policy
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：为工单读取/分派/关闭定义 RBAC+ABAC 策略，在 URL、方法和对象层默认拒绝，并验证 owner/technician/admin 矩阵
  covers_topic_groups:
  - security-authorization-enforcement
  - security-rbac-abac
  covers_topics:
  - security.url-method-authorization
  - security.object-authorization
  - security.authorization-default-deny-policy
  - security.rbac
  - security.abac
  - security.policy-conflict
  uses_capabilities:
  - security.authentication
  - security.web-threat
  - backend.spring-mvc-contract
  - security.authorization-policy
  evidence_kind: system-artifact-and-negative-tests
  verification_mode: system-security-resilience-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入仅隐藏按钮、URL 保护但方法未保护和对象 IDOR，使用另一用户 ID 发请求后补齐执行点，并把异常定位到第一处可信证据
  covers_topic_groups:
  - security-authorization-enforcement
  - security-rbac-abac
  covers_topics:
  - security.url-method-authorization
  - security.object-authorization
  - security.authorization-default-deny-policy
  - security.rbac
  - security.abac
  - security.policy-conflict
  uses_capabilities:
  - security.authentication
  - security.web-threat
  - backend.spring-mvc-contract
  - security.authorization-policy
  evidence_kind: fault-injection-fix-rerun
  verification_mode: fault-injection-rerun
---
# URL/方法授权、RBAC、ABAC 与默认拒绝

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《JWT 验证、Bearer Token 与 Resource Server》](ch.security.jwt-resource-server.md)：独立完成授权执行点、RBAC 与 ABAC前，必须先具备「JWT 验证、Bearer Token 与 Resource Server」已经验证的知识与失败边界
- [《@Transactional、传播、回滚、隔离与提交后行为》](../../volume-05-spring-backend/chapters/ch.spring.transactions.md)：独立完成授权执行点、RBAC 与 ABAC前，必须先具备「@Transactional、传播、回滚、隔离与提交后行为」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套资产以固定的合成主体、工单和策略矩阵模拟授权，不启动 Spring、数据库或 HTTP 服务，也不包含真实租户、用户和 Token。局部验证通过只能证明策略函数、执行点与故障预言，不能证明 AOP 代理、事务、数据库查询、多租户过滤或生产配置已正确。

认证解决“请求主体是谁”，授权解决“这个主体此刻能否对这个具体对象执行这个动作”。一个合法 Token、已登录 Session、管理员样式按钮或难猜 UUID 都不构成授权。授权结论至少要同时考虑主体、动作、对象、关系、数据范围、业务状态与环境，并且必须在服务端每条可达路径执行。

FactoryCare 的权限模型不是“有 `ADMIN` 就全放行”。平台发布七个固定、只读的全局角色 catalog，租户只给 membership 绑定角色；角色映射到 permission，permission 还要与 `SELF/TEAM/ORGANIZATION/TENANT` 数据范围、对象所有权、当前 assignment、组织归属和工单状态组合。未知角色、未列动作、他人对象以及没有明确命中允许规则的情况一律拒绝。

## 1. 完成定义与证据入口

完成本章，应能独立做到：

1. 区分认证与授权、角色与权限、功能权限与对象权限、RBAC 与 ABAC、403 与隐藏资源时的 404；
2. 把一个自然语言规则拆成 subject、action、resource、environment 四类输入及明确 Allow/Deny 结果；
3. 在 URL/HTTP 请求层做粗粒度入口保护，在 Service 方法层保护跨入口调用，在对象层校验 ownership/assignment/data scope；
4. 采用默认拒绝：未知角色、未知 action、未匹配路径、缺失属性、冲突策略和策略异常都不能意外放行；
5. 为工单 read/assign/close 建立 owner、technician、dispatcher/admin 等正反矩阵，并解释每个 allow 的业务依据；
6. 证明隐藏按钮、改变 URL、猜测对象 ID、绕过 Controller 直调 Service 都不能绕过服务端策略；
7. 识别 Spring request matcher、方法安全代理、自调用、非 Spring 对象和事务时序的真实边界；
8. 注入 UI-only、URL-only、IDOR、allow-by-default 和策略冲突，定位第一处可信证据并修复重跑。

配套入口：

- [授权策略示例](../../../examples/encyclopedia/ch.security.authorization-rbac-abac/README.md)
- [RBAC/ABAC 故障实验](../../../labs/encyclopedia/ch.security.authorization-rbac-abac/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.security.authorization-rbac-abac/README.md)

## 2. 授权判断的最小模型

可以把授权写成纯函数：

```text
Decision = Policy(Subject, Action, Resource, Environment)
```

Subject 是已认证且重建过的当前业务主体，包括 membership ID、tenant、角色、permissions、data scope、team/organization 和启用状态。Action 是稳定业务动作，例如 `WORK_ORDER_READ`、`WORK_ORDER_ASSIGN`、`WORK_ORDER_CLOSE`，不是随意的 Controller 方法名。Resource 是目标工单及其 tenant、组织、owner、assignment、状态等可信属性。Environment 是当前时间、请求通道、风险确认、事务版本等辅助条件。

Policy 的输出不应只是模糊 boolean。生产设计常需要 `ALLOW` 或带稳定 reason/category 的 `DENY`，并明确哪些输入缺失。对外错误可最小化，对内测试必须知道是 role、permission、scope、relation、state 还是 unknown-action 导致拒绝。缺属性不能当作 `false` 后被另一个宽松 OR 覆盖，也不能因为策略服务超时而 fail-open。

授权不是一次登录时永久计算的属性。成员可能被禁用、角色被撤销、工单被转派、状态已关闭、组织范围发生变化。FactoryCare 每次请求重建当前 membership，再对当前对象做判断；长寿命 Token 中的旧 role 不能覆盖数据库事实。

## 3. RBAC：用角色管理权限集合

Role-Based Access Control 把用户与大量 permissions 之间增加角色层。membership 被授予一个或多个角色，角色通过受控 catalog 包含 permissions。它减少逐用户授权的管理成本，也支持职责分离与最小权限。角色不是身份称号；只有映射到具体动作，才能回答请求。

FactoryCare 固定七角色：`tenant_admin`、`asset_admin`、`dispatcher`、`knowledge_admin`、`technician`、`reporter`、`supervisor_auditor`。它们是 `scope=GLOBAL` 的平台只读 catalog；租户不能创建、改名、删除或修改 role-permission，只能在同租户 `membership_role` 关系中绑定/撤销。这样权限含义可版本化和集中测试。

角色过少会产生“超级管理员”滥权，角色过多会角色爆炸。若为“南区夜班一组技师只能看自己工单”创建一个超长角色，实际上把对象/环境属性硬编码进角色名。更合理的是 RBAC 决定候选功能权限，ABAC/关系判断限定对象范围。

角色继承也不是自动最佳实践。层级可减少重复，却可能让高层角色无意获得未来新增权限。FactoryCare 更适合稳定 permission code 与显式矩阵；若使用 Spring RoleHierarchy，必须把展开结果纳入契约测试，不能只看名字猜包含关系。

## 4. ABAC：让属性进入决策

NIST 把 ABAC 描述为：根据主体、对象、操作以及有时环境的属性，结合策略规则决定允许的操作。它适合表达“技师可读取分派给自己的工单”“报修人可读取自己创建的报修关联工单”“调度员只能在被分配组织范围内派单”等关系。

常见属性：

- Subject：tenantId、membershipId、role、permission、organizationId、teamId、dataScope、status；
- Resource：tenantId、reporterMembershipId、assignedTeamId、assignedTechnicianId、organizationId、status、sensitivity；
- Action：read、assign、close 等稳定 permission code；
- Environment：请求时间、渠道、高风险二次确认、业务版本、紧急模式。

ABAC 的优势是表达力，代价是输入质量、策略可解释性和测试组合数。属性来源必须有权威：请求传入的 `tenantId`、`role`、`owner=true` 都不可信；客户端只能给资源标识和业务命令，服务端从认证上下文与数据库加载属性。所谓“前端已经算过 dataScope”没有安全价值。

关系型访问控制（ReBAC）常被视为 ABAC 的一种应用：主体与对象之间存在 owner、assignee、reviewer、member-of-team 等关系。FactoryCare 的 reporter ownership 与 technician assignment 都属于此类。不能用对象 ID 是否难猜替代关系检查。

## 5. RBAC + ABAC 的组合方式

一个稳健的 allow 通常是“功能权限 AND 对象条件 AND 状态条件”，例如：

```text
ALLOW assign(workOrder)
WHEN subject has WORK_ORDER_ASSIGN
 AND subject tenant == workOrder tenant
 AND subject data scope contains workOrder organization
 AND target team belongs to the same allowed organization
 AND workOrder is not terminal
 AND expectedVersion matches
```

这里 `WORK_ORDER_ASSIGN` 来自 dispatcher 角色是 RBAC，tenant/organization/team/status/version 是 ABAC。若只检查角色，dispatcher 可能跨组织或跨租户派单；若只检查 owner 关系，又无法表达谁有派单功能。

组合表达式必须保持可读。不要把几十个 SpEL 条件复制到注解里。可以让注解只表达稳定 permission，再委托一个命名良好的 `AuthorizationManager`/policy service 加载对象和判断属性。策略输入和结果可单测，HTTP 与方法层只负责调用同一权威规则。

## 6. 默认拒绝是闭世界策略

默认拒绝意味着只有可解释、显式列出的规则产生 Allow，其余都是 Deny。它覆盖的不只是匿名用户，还包括：新增 URL 没写 matcher、枚举新增 action、未知 role code、对象不存在、必要属性为空、策略解析异常、依赖不可用、规则冲突或没有规则命中。

“所有 `/api/**` 需要登录”不是默认拒绝的业务授权，只是认证门。一个 authenticated 主体仍可能调用不属于自己的资源。请求层应在列出公开端点后对其余请求显式拒绝/要求认证；业务方法层同样需要明确授权，不靠“当前没有别的调用者”。

OWASP 建议显式配置 deny by default，而不是信赖框架某个版本的隐含默认。原因是路由、matcher 与框架默认会变化。测试应扫描/枚举关键操作，证明新 action 没加入矩阵时先红灯，而不是自动落入宽泛 `authenticated()`。

未知角色不能当普通用户后被宽规则允许，未知 action 不能映射为 read，缺失 owner 不能当自己，策略异常不能 catch 后 return true。这些都是 fail-open。

## 7. 三层执行点各自解决什么

### 7.1 URL/请求层：减少入口攻击面

Spring Security `authorizeHttpRequests` 可按 HTTP method、path 或自定义 RequestMatcher 做入口规则。例如明确公开健康检查/登录回调，要求 `/api/**` 已认证，并对管理路由要求某 permission。它在进入 Controller 前拒绝明显不合格请求，统一 401/403 与安全响应。

URL 层看得到 path、method、headers 和 Authentication，但通常没有完整领域对象。可以判定“只有拥有 `WORK_ORDER_ASSIGN` 才能调用派单路由”，却不能只凭 `/work-orders/{id}` 中的字符串判断对象属于哪个 tenant/team。把所有 ABAC 查询塞进 matcher 会让过滤链与事务边界混乱。

matcher 顺序与覆盖很重要：宽规则先命中可能遮蔽窄规则；HTTP method 未限定可能让 read 权限覆盖 write；路径规范化、Servlet path、forward/error/async dispatch 都需按目标版本测试。不要用字符串 `startsWith("/admin")` 自制安全路由器。

### 7.2 方法层：保护跨入口业务能力

同一 Service 可能被 HTTP Controller、消息消费者、定时任务、管理脚本或另一个模块调用。只保护 URL 会让非 HTTP 路径绕过。Spring 方法安全通过 `@EnableMethodSecurity` 启用，`@PreAuthorize` 等由 AOP advisor 在 Spring-managed bean 代理上执行；Boot Starter Security 本身不会自动开启方法授权。

方法层适合保护业务能力和参数，例如要求 permission 并委托 policy 检查 `workOrderId`。拒绝时通常抛 `AccessDeniedException`；HTTP 链可转为 403，非 HTTP 调用者要显式处理。安全注解不是魔法：`new` 出来的对象、未被代理的类、错误代理边界和某些自调用路径可能绕过拦截，必须用集成测试证明。

为了不依赖“只有 Controller 会调”，在模块对外的 Application Service 边界执行授权。内部纯领域函数可以接受已经过验证的命令，但不能把 public 方法随意暴露给未授权调用者。

### 7.3 对象层：防 IDOR/BOLA

拥有 read permission 不等于拥有所有工单。对象层从可信仓库加载目标，检查 tenant、data scope、owner/assignment 与状态。攻击者把 URL 中 ID 换成另一个合法 UUID，若服务端只 `findById` 返回，就是典型 IDOR/Broken Object Level Authorization。

可采用“按当前 scope 查询”让不可见对象根本不返回，或加载后调用 policy；两者都需保证跨租户为零且不泄漏摘要。前者减少误用风险，后者有时更易区分不存在与无权。FactoryCare 的多租户数据过滤由下一章详细实现；本章只规定对象授权必须存在，不能把 tenantId 从请求当过滤权威。

对象读取与写入之间还要防 TOCTOU：授权时是 assignee，提交时已转派。高风险命令应在同一事务中基于当前记录、当前成员和 expectedVersion 判定并变更，或让更新语句携带约束，确保状态变化不会越过策略。

## 8. FactoryCare 工单策略样例

### 8.1 读取 `WORK_ORDER_READ`

权限矩阵允许 tenant admin、asset admin、dispatcher、supervisor/auditor 读取，但仍受 tenant/assigned organization 范围；technician 是 conditional，只能在分派的 organization/team 或自身工单关系内；reporter 是 conditional，只能看与自己报修关联的工单。knowledge admin 也只是 conditional，不代表浏览全租户工单。

因此规则不是 `hasAnyRole("ADMIN","TECHNICIAN","REPORTER")`。它应先要求 `WORK_ORDER_READ`，再检查对象在 subject data scope 或 owner/assignment 关系中。owner 是对象关系，不是固定角色名。

### 8.2 分派 `WORK_ORDER_ASSIGN`

FactoryCare 主要由 dispatcher 执行，supervisor/auditor 为 conditional；普通 tenant admin 并不因“admin”字样自动拥有所有工单动作。还要检查目标工单与 team 同租户、team 属于授权组织、目标技师 membership 合法、工单非终态、expectedVersion 当前。

公开练习为便于教学使用 `ADMIN/DISPATCHER` 候选，但正文以 permission matrix 为权威。角色只提供 permission；对象策略仍决定可操作范围。未知 role 或未列 action 必须 403。

### 8.3 关闭 `WORK_ORDER_CLOSE`

dispatcher 可在 assigned organization 范围内关闭，supervisor/auditor 允许，其他角色拒绝；同时只有满足状态机条件的工单可关闭。授权通过但状态不合法属于业务冲突，通常是 409，而不是把所有失败都伪装成 403。检查顺序要避免向无权者泄露状态：先证明主体可见/可操作，再给有权主体业务冲突细节。

### 8.4 角色绑定

`ROLE_ASSIGN` 只有 tenant admin，在当前 tenant 内绑定固定 role catalog，并要求高风险确认。禁止非管理员自我提权、给他租户 membership 赋权、绑定未知 role、修改全局 catalog。角色授予/撤销与核心审计同事务属于 FactoryCare 合同，但审计存储实现不在本章。

## 9. 策略冲突如何处理

冲突可能来自多个角色、一条 allow 与一条 deny、全局规则与对象规则、旧策略与新策略并存。必须选择并记录组合算法，不能依赖集合遍历顺序。安全默认通常是：任何硬性 deny（禁用主体、跨租户、未知 action、对象越界、职责分离冲突）优先；只有所有必要条件满足才 allow。

并不是所有业务都需要“deny overrides”语言引擎，但每个组合都要确定。例如 technician 同时也是 dispatcher：可以拥有派单 permission，却不能给自己审批自己请求；职责分离的 explicit deny 应覆盖角色带来的 allow。普通“某角色没有这个 permission”则只是没有贡献 allow，不一定要写成全局 deny，否则多角色组合无法工作。

可以把决策拆成：

1. 硬边界：主体启用、同 tenant、action 已知、对象类型正确；
2. 功能候选：permission 是否存在；
3. 对象范围：scope/owner/assignment 是否满足；
4. 状态与职责分离：当前状态、非请求人、非自提权等；
5. 没有明确 Allow 就 Deny。

策略版本变化要重跑完整矩阵。不要让旧缓存继续持有已撤销权限；缓存 key 至少考虑 membership/role 版本，敏感操作可直接读取权威。缓存失效策略属于后续分布式章节，本章只规定陈旧 allow 不可接受。

## 10. 401、403、404 与 409 的边界

未提供或无效认证通常是 401；主体已认证但不满足权限/对象范围通常是 403；为了防对象枚举，读取不可见资源可统一表现为 404；有权主体违反状态、版本或业务不变量通常是 409。具体以公共 API Problem 合同为准。

状态码不是安全控制本身。必须同时断言业务方法未执行、数据库无副作用、响应不含目标摘要。把越权请求改成 404 却已经先查出并记录敏感对象，仍然越界。相反，内部测试需要稳定 reason 来定位，但不能把“他租户对象存在”泄漏给客户端。

认证与授权异常处理要分开。Spring 的 AuthenticationEntryPoint 处理未认证，AccessDeniedHandler 处理已认证拒绝；方法在非 HTTP 场景抛出的拒绝要由调用适配器映射。一个全局 catch `Exception -> 200 {success:false}` 会破坏 HTTP 语义和测试预言。

## 11. Spring Security 行为与易错边界

Spring Security 当前 Authorization API 以 `AuthorizationManager` 为核心，可用于请求与方法等执行点。Request 规则通过 `authorizeHttpRequests` 组合；方法安全通过 `@EnableMethodSecurity` 发布 `@PreAuthorize`、`@PostAuthorize` 等 advisor。多个不同方法安全注解会依序执行，通常相当于必要条件共同满足。

框架能读取 Authentication/authorities、调用表达式或自定义 manager、发布授权事件并在拒绝时抛异常。它不知道 FactoryCare 的固定角色 catalog、工单 owner、team assignment、data scope、状态机或职责分离，应用必须提供 policy 与可信属性来源。

方法安全建立在 Spring AOP 上，因此要检查：目标是否为 Spring bean；调用是否经过代理；注解是否放在真正对外方法；代理与事务 advisor 顺序是否符合设计；测试是否从真实入口调用。`@PreAuthorize` 写在 private 方法上或手工 `new Service()`，不会因为源码上有注解就获得保护。

`@PostAuthorize` 在对象返回后判断可能已执行查询或副作用，不适合保护写命令；对于集合过滤，`@PostFilter` 也可能先加载过多越界数据并带来性能问题。更稳健的是查询层按可信 scope 限制，再以对象 policy 做防御。多租户查询由下一章实现。

复杂 SpEL 会把业务政策散落在字符串中，难以复用、重构和解释。优先使用稳定 authority + 命名策略 bean，例如 `@PreAuthorize("hasAuthority('WORK_ORDER_READ') and @workOrderPolicy.canRead(authentication, #id)")`，并让 policy 自身有参数化矩阵测试。示例只是形态，实际还要避免重复查询与 TOCTOU。

## 12. 事务与授权的相互作用

写命令通常需要先确认主体与对象，再在事务中修改。若授权查询在事务外，目标可能在检查与更新之间被转派；若为了授权加载完整对象后又在另一个事务用旧快照更新，会产生竞态。可在 Application Service 事务里加载当前行、执行 policy、检查 expectedVersion，然后原子写入。

但是事务不等于授权。`@Transactional` 只提供数据库一致性边界，不会检查当前用户。授权失败要抛能触发回滚的异常；若 catch 后继续写审计/状态，必须明确哪些拒绝证据允许单独提交，不能留下半个业务变更。

代理顺序同样要测试，而不是凭注解排列推断。方法授权在事务开始前还是事务内，取决于 advisor 配置。关键预言是：policy 读取的属性与最终写入使用一致的可信快照，失败时业务表无变化。

## 13. 常见失败与诊断路径

### 13.1 只隐藏前端按钮

症状：普通用户在 UI 看不到“关闭”，但直接 POST 对应 API 成功。第一处可信证据是服务端请求 trace 中没有授权决策，或方法调用计数已增加。修复服务端 request/method/object policy；UI 隐藏只改善体验，不能算控制。

### 13.2 只保护 URL

HTTP 请求被拒绝，但测试或消息消费者直接调用 `workOrderService.close` 成功。第一处证据是调用路径是否经过 SecurityFilterChain 和方法代理。修复为对模块 Application Service 启用方法/策略保护，同时保留 URL 粗筛。不要把所有内部 helper 都加注解来制造混乱。

### 13.3 对象 IDOR

用户能读自己的工单，把 ID 换成同租户另一 reporter 的工单仍返回。第一处证据是仓库只 `findById`，policy 只查 `WORK_ORDER_READ` 而没查 owner/scope。修复查询范围或对象策略，并用两个真实主体与两个对象重跑。

### 13.4 allow by default

新增 `WORK_ORDER_EXPORT` action 后测试未配置规则却返回允许。第一处证据是 switch/default、未知枚举解析或空策略集合的返回值。修复为 closed-world：所有显式 action 有规则，unknown 永远 Deny；加入枚举覆盖测试。

### 13.5 角色与 permission 混淆

代码到处 `hasRole('ADMIN')`，但 FactoryCare 的 tenant_admin 被误授派单/知识发布/审计导出。第一处证据是角色到 permission 展开结果与 `permission-matrix.csv` 不一致。修复以稳定 permission code 保护动作，让固定 catalog 集中映射并进行哈希/矩阵验证。

### 13.6 策略冲突依赖顺序

同一主体既 technician 又 dispatcher，一次运行 Allow，一次 Deny。第一处证据是 HashSet/数据库无序遍历中“最后规则覆盖”。修复为明确组合算法和硬性 deny 优先级，排序仅用于报告，不用于决定语义。

### 13.7 可信属性来自请求

客户端提交 `tenantId=B`、`owner=true`、`role=admin` 后越权。第一处证据是策略输入映射直接使用 DTO 安全字段。修复为从 SecurityContext 和数据库加载；请求中的资源 ID 只是查找键，tenant、角色与关系由服务端建立。

## 14. 工单 read/assign/close 参数化矩阵

| 主体与关系 | READ | ASSIGN | CLOSE | 原因 |
| --- | --- | --- | --- | --- |
| reporter，自己的报修关联工单 | Allow | Deny | Deny | owner 关系只授读取/合同列出的动作 |
| reporter，他人的工单 | Deny | Deny | Deny | 对象关系不满足 |
| technician，分派给自己 | Allow | Deny | Deny | assignment 满足读取/执行，不授派单关闭 |
| technician，同 team 但分派给别人 | 依 data scope/矩阵 | Deny | Deny | 不能只看角色猜全队权限 |
| dispatcher，授权组织内 | Allow | Allow | 条件 Allow | permission + organization scope + 状态 |
| dispatcher，授权组织外 | Deny | Deny | Deny | ABAC scope 拒绝 |
| supervisor/auditor，授权范围 | Allow | 条件 Allow | Allow | 仍受对象范围与职责分离 |
| tenant_admin | 按矩阵 Allow | 不因 admin 自动 Allow | 不因 admin 自动 Allow | 固定 permission catalog 是权威 |
| 未知角色 | Deny | Deny | Deny | 默认拒绝 |
| 任意角色、未知 action | Deny | Deny | Deny | 闭世界 action catalog |

表中的“条件”必须继续展开成可执行属性；不能把单元格里的文字当实现。配套资产使用缩小的 owner/technician/dispatcher/admin 教学模型，正文与真实项目仍以完整 permission matrix 为准。

## 15. 验证层次与预言

### 15.1 纯策略单元测试

用合成 Subject/Resource 枚举 role、permission、action、ownership、assignment、scope、state，断言 Decision 与 reason。它速度快，能覆盖冲突和 unknown，但不能证明 Spring 执行点存在。

### 15.2 方法安全集成测试

从 Spring bean 代理调用 Application Service，证明合法调用进入方法、非法调用在业务副作用前抛拒绝；再构造绕过 Controller 的直接 Service 调用，验证仍被拦截。手工 new 只用于展示失败，不能作为绿灯路径。

### 15.3 API 安全测试

通过真实 FilterChain 请求 URL，覆盖匿名 401、无权 403、隐藏对象 404/合同响应、合法 2xx。改变 HTTP method、URL 变体、对象 ID 与主体，断言响应与数据库无副作用。`FC-RBAC-002` 专门证明 UI 隐藏不等于授权。

### 15.4 数据库/事务测试

使用两个 tenant、多个 organization/team 和真实外键 fixture，证明跨范围读取为零、越权写入原子拒绝。角色授予/撤销与业务审计的同事务证据属于后续实现；本章离线资产不启动数据库，也不冒充 T4 完整证据。

最低负测集合：未知 role；未知 action；缺 permission；他人 owner；他 team/organization；跨 tenant；终态工单；UI-only；URL-only；Service 直调；策略异常；双角色冲突。每项记录第一处拒绝规则、业务调用计数和副作用计数。

## 16. 标准、OWASP 与框架行为分层

| 来源层 | 本章采用的结论 | 不能误读为 |
| --- | --- | --- |
| NIST RBAC/ABAC 模型 | RBAC 用角色组织权限；ABAC 根据 subject/object/action/environment 属性执行策略 | 某个固定角色表是通用标准，或 ABAC 引擎自动知道业务属性 |
| OWASP Authorization Cheat Sheet | 最小权限、默认拒绝、每请求验证、对象级检查、正确执行点、自动化负测 | 隐藏 ID、UI 按钮或框架默认足以授权 |
| Spring Security | request authorization、`AuthorizationManager`、`@EnableMethodSecurity`、AOP 方法拦截与拒绝事件 | Boot 自动开启方法安全，或源码有注解就一定经过代理 |
| FactoryCare 合同 | 固定七角色 catalog、permission matrix、membership role、data scope、owner/assignment 关系 | tenant_admin 万能，或 Provider role claim 是业务权威 |

稳定核心是显式 Allow、默认拒绝、多执行点和对象级判断。版本敏感面是 Spring Security 7.x 的 DSL、matcher、AOP advisor 与异常映射；本章按 Boot 4.1 管理版本在 2026-07-17 核对，真实项目必须用集成测试固定行为。

## 17. 独立构建与诊断任务

先写一份机器可读或表格策略：至少包含 `READ/ASSIGN/CLOSE`，主体至少包含 owner/reporter、technician、dispatcher/admin、unknown，资源属性至少包含 owner、assigned technician、organization scope 和状态。每个 Allow 写出理由；未列组合自动 Deny。

再建立三个执行点：请求路由粗筛、Application Service 方法保护、对象 policy。运行合法矩阵后依次注入：只隐藏按钮；移除方法保护；对象 policy 只检查 permission；unknown 默认 Allow；冲突最后规则覆盖。每个故障必须先产生命名红灯，再修复并重跑原矩阵。

验证报告记录合成主体、action、对象属性、命中规则、Decision、HTTP/方法结果与副作用计数。不能只写“返回 403”，还要证明方法未执行、状态/version 未变化。配套 exercise 首先以 `UNKNOWN_ROLE_ALLOWED` 红灯；private solution 以相同输入全绿。

## 18. 120 秒讲述模板

1. 认证确认主体，授权判断这个主体对这个对象能做什么；
2. RBAC 用角色汇总 permission，ABAC 用主体/对象/动作/环境属性收窄；
3. FactoryCare 的 allow 是 permission AND data scope/owner/assignment AND state，不是角色名；
4. URL 层做入口粗筛，方法层防跨入口直调，对象层防 IDOR，三者共用权威策略；
5. 未匹配、未知、缺属性、冲突和异常全部默认拒绝；
6. 反例：UI 隐藏关闭按钮，但攻击者直接调用 Service/URL 并替换工单 ID，因没有对象检查而成功。

若不能解释“为什么 `hasRole('TECHNICIAN')` 不能证明能读任意工单”，或“方法安全为什么可能被手工 new/代理边界绕过”，应回到故障实验，而不是继续堆注解。

## 19. 资料与版本核对

- [NIST SP 800-162：ABAC Definition and Considerations](https://csrc.nist.gov/pubs/sp/800/162/upd2/final)（模型定义，2026-07-17 核对）
- [OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)（实施建议，2026-07-17 核对）
- [Spring Security Authorization](https://docs.spring.io/spring-security/reference/servlet/authorization/)（框架行为，2026-07-17 核对）
- [Spring Security Method Security](https://docs.spring.io/spring-security/reference/servlet/authorization/method-security.html)（AOP 与方法执行点，2026-07-17 核对）
- [FactoryCare permission matrix](../../../factorycare-design/security/permission-matrix.csv)（项目权限权威）
- [FactoryCare acceptance catalog](../../../factorycare-design/testing/acceptance-catalog.md)（`FC-RBAC-001—006` 设计预言）

## 20. 本章边界

本章不实现 tenant 条件注入、跨租户数据库查询、缓存失效、审计表与保留策略，也不选择外部策略引擎、ACL 产品或企业 IAM 治理平台。多租户数据隔离与审计存储分别由后续章节负责。这里引用 tenant/data scope 只是定义授权输入和必须拒绝的边界。

本章完成不等于生产授权已验收。只有目标 Spring 应用中的 FilterChain、方法代理、对象查询、事务、两个真实 fixture tenant、完整 permission matrix 和负向副作用证据都通过，才能把 G3 相关授权证据标为已验证。
