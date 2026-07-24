---
schema_version: 2
edition: 2026.2-draft
id: ch.security.spring-security-architecture
title: FilterChain、SecurityContext、默认拒绝与异常链
responsibility: 教授 Spring Security 请求链和认证上下文架构，不在本章完成具体登录、JWT 或业务授权策略
volume: '06'
order: 6
level: L2
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.security.spring-security-architecture.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.security.untrusted-input-xss-ssrf
version_surfaces:
- spring-security
- spring-boot-4.1
- spring-framework-7
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释FilterChain、SecurityContext、默认拒绝与异常链的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - spring-security-chain
  - spring-security-defaults
  covers_topics:
  - security.filter-chain
  - security.security-context
  - security.authentication-entry-point
  - security.deny-by-default
  - security.authentication-vs-access-denied
  - security.security-filter-order
  uses_capabilities:
  - backend.spring-di-config
  - security.web-threat
  - foundation.http-message
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 配置两条 SecurityFilterChain，打印匹配顺序和 SecurityContext，在未认证/已认证/无权限请求上观察异常链
  covers_topic_groups:
  - spring-security-chain
  - spring-security-defaults
  covers_topics:
  - security.filter-chain
  - security.security-context
  - security.authentication-entry-point
  - security.deny-by-default
  - security.authentication-vs-access-denied
  - security.security-filter-order
  uses_capabilities:
  - backend.spring-di-config
  - security.web-threat
  - foundation.http-message
  evidence_kind: integration-artifact-and-tests
  verification_mode: framework-or-container-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入宽 matcher 抢先匹配、匿名默认放行和自定义过滤器顺序错误，依据 filter chain debug 修复，并把异常定位到第一处可信证据
  covers_topic_groups:
  - spring-security-chain
  - spring-security-defaults
  covers_topics:
  - security.filter-chain
  - security.security-context
  - security.authentication-entry-point
  - security.deny-by-default
  - security.authentication-vs-access-denied
  - security.security-filter-order
  uses_capabilities:
  - backend.spring-di-config
  - security.web-threat
  - foundation.http-message
  evidence_kind: integration-failure-fix-rerun
  verification_mode: integration-fault-rerun
---
# FilterChain、SecurityContext、默认拒绝与异常链

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《不可信输入、输出编码、XSS 与 SSRF》](ch.security.untrusted-input-xss-ssrf.md)：独立完成过滤链与上下文、默认拒绝与异常前，必须先具备「不可信输入、输出编码、XSS 与 SSRF」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套代码用纯 JDK 模拟匹配、上下文、授权和异常翻译，不启动 Servlet 容器、不下载 Spring 依赖、不实现登录/JWT/OIDC，也不接触真实凭据。模型能证明顺序与状态不变量，不能替代 Spring Boot 4.1 管理版本上的真实 `SecurityFilterChain` 集成测试。

Spring Security 不是 Controller 上的一条注解，也不是“登录成功后放个用户对象”。在 Servlet 应用中，它首先是一组按顺序运行的 Filter：选择一条安全链，加载当前请求的安全上下文，尝试认证，执行 CSRF 等攻击防护，授权请求，把安全异常翻译成 HTTP 响应，最后清理请求线程上的上下文。任何一步错位，都可能让请求绕过、误报 401/403 或把上一请求身份泄到下一请求。

本章只建立架构地图和默认拒绝不变量。具体 Session 登录、JWT Resource Server、OIDC、方法级/业务级授权分别属于后续章节。

## 1. 完成定义与证据入口

完成本章应能：

1. 从 Servlet 容器画到 `DelegatingFilterProxy`、`FilterChainProxy`、首个匹配的 `SecurityFilterChain` 和 Controller；
2. 区分“选择哪条链”的 `securityMatcher` 与“链内怎样授权”的 request matcher；
3. 解释 `SecurityContextHolder → SecurityContext → Authentication` 的层次、来源、使用者和清理时机；
4. 让公开端点只有预定的 method+path 集合，其余请求有兜底链并默认拒绝或要求认证；
5. 区分未认证 401 与已认证但无权限 403，说明 `AuthenticationEntryPoint`、`AccessDeniedHandler` 与 `ExceptionTranslationFilter` 的关系；
6. 为自定义 Filter 指定相对位置，证明它只运行一次、依赖的上下文已经存在、失败由正确处理器接住；
7. 注入宽 matcher 抢先匹配、匿名默认放行、无 catch-all、错误 Filter 顺序和上下文未清理，定位第一处可信偏差。

配套入口：

- [两条安全链与异常翻译示例](../../../examples/encyclopedia/ch.security.spring-security-architecture/README.md)
- [FilterChain 与 SecurityContext 故障实验](../../../labs/encyclopedia/ch.security.spring-security-architecture/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.security.spring-security-architecture/README.md)

资产只使用合成请求元数据。真正完成 canonical build outcome 仍需在项目采用的 Spring Security、Boot 4.1 与 Framework 7 组合上启动容器并运行集成测试。

## 2. Servlet Filter 是请求进入 MVC 前的关卡

Servlet `Filter` 可以在目标 Servlet/Controller 之前检查或包装 request/response，也可以在下游返回后执行清理。它必须调用 `chain.doFilter` 才会继续；直接写响应并返回则短路链。安全认证和授权放在这里的价值是：请求尚未进入业务 Controller 就能统一建立身份和拒绝未授权访问。

容器只认识 Servlet Filter，不认识 Spring bean。`DelegatingFilterProxy` 是桥：容器调用这个 Filter，它再从 Spring `ApplicationContext` 找到目标 bean，通常是名为 `springSecurityFilterChain` 的 `FilterChainProxy`。代理本身不承载所有安全逻辑；真正编排的是 `FilterChainProxy`。

这一层次解释了常见误判：“我定义了一个 Spring Filter bean，所以它一定只在 Spring Security 中运行。”若容器或 Boot 又把它注册成普通 Servlet Filter，它可能在容器链和安全链各执行一次。自定义安全 Filter 应明确由哪一层注册，并用调用次数测试防止重复。

## 3. FilterChainProxy 为什么是中心

`FilterChainProxy` 持有零到多条 `SecurityFilterChain`。每条链由一个请求 matcher 与一组有序安全 Filter 组成。请求到达后，代理按链顺序检查 matcher，**只调用第一条匹配链**；不会把两条链的 Filter 合并，也不会在第一条处理后继续寻找“更具体”的链。

它还提供跨链的重要行为：应用 `HttpFirewall`，在请求完成后清理 `SecurityContext`，并统一 Spring Security 的诊断入口。绕过 `FilterChainProxy` 不只是绕过授权规则，也可能丢失防火墙、上下文清理和安全响应头等处理。

若没有任何 `SecurityFilterChain` 匹配，请求不受 Spring Security 保护。框架不会凭空猜出“应该拒绝”。因此多链配置必须有覆盖所有剩余请求的兜底链，或有清晰证据说明未覆盖路径由另一个可信边界保护。FactoryCare 采用前者。

## 4. `securityMatcher` 与链内 matcher 是两层决策

`HttpSecurity.securityMatcher(...)` 决定这一整个 `SecurityFilterChain` 是否候选。链内 `authorizeHttpRequests().requestMatchers(...)` 决定已进入该链的请求需要 `permitAll`、`authenticated`、authority 或 `denyAll`。两者名称相近，职责不同。

假设高优先级链的 `securityMatcher("/api/**")`，并在链内 `anyRequest().permitAll()`；它会抢先匹配所有 API，后面的受保护 API 链永远没有机会。这不是后链授权表达式的 bug，而是链选择第一步已经偏离。诊断应先记录 matched chain，再看链内 authorization rule。

规则顺序同样重要。链内 matcher 通常按声明顺序判断，第一条匹配规则生效。把 `requestMatchers("/api/**").permitAll()` 写在更具体规则前，后者会被遮蔽。安全配置应从精确例外到一般规则，并显式以 `anyRequest().denyAll()` 或经过评审的 `authenticated()` 收尾。

## 5. FactoryCare 的两条链目标形态

为理解结构，可把设计压缩为两条链：

1. **受控公共入口链**：高优先级，只匹配 OpenAPI 明确 `security: []` 的精确 method+path，例如本地受控身份适配入口 `POST /api/v1/auth/login`；链内只 permit 这个动作，不能扩大为整个 `/api/v1/auth/**`；
2. **应用兜底链**：低优先级匹配所有剩余请求；`/api/v1/**` 先要求已认证，具体角色、租户与 data scope 在业务授权层继续判断；非预定路径 `denyAll`。

真实配置可以因 actuator、静态资源、OIDC callback 或 bearer/session 模式增加链，但每增加一条都会扩大排序和覆盖面的证明成本。本章用两条链建立不变量，不提前选择生产 Provider 或完成登录协议。

公开不等于忽略。对确实公开的 HTTP 端点优先让请求经过安全链后 `permitAll`，这样仍可获得安全响应头、日志边界和统一上下文清理。`WebSecurityCustomizer.ignoring` 会完全绕过 Spring Security，适用面更窄，不能当成公开 API 的默认写法。

## 6. 请求经过安全链的概念时序

一个受保护 API 请求可抽象为：

```text
Servlet container
  -> DelegatingFilterProxy
  -> FilterChainProxy
      -> choose first matching SecurityFilterChain
      -> load/defer SecurityContext
      -> CORS / CSRF and request protections as configured
      -> authentication filter(s)
      -> ExceptionTranslationFilter wraps downstream
      -> AuthorizationFilter
  -> DispatcherServlet / Controller
  -> finally clear SecurityContext
```

这不是所有版本和配置的完整 Filter 列表。认证机制不同会加入不同 Filter；某些 Filter 可延迟加载上下文；授权 Filter 的默认位置会演进。稳定认知是依赖关系：授权读取认证结果，异常翻译要能捕获下游安全异常，请求结束必须清理上下文。实际顺序以目标版本启动日志和测试为证。

## 7. SecurityContext 三层对象

`SecurityContextHolder` 是访问当前上下文的入口；默认策略通常以 `ThreadLocal` 关联当前执行线程。`SecurityContext` 是容器，内部保存 `Authentication`。`Authentication` 表示一次待认证输入，或已认证主体，包含 principal、credentials、authorities 与认证状态。

不要把三者混为“用户”：

- principal 是身份表示，不自动包含 FactoryCare 当前 membership、tenant 与 data scope；
- credentials 是认证材料，认证成功后通常应擦除，不进入日志；
- authorities 是较粗粒度权限声明，资源所有权、租户和组织范围仍由服务端业务层重查；
- `isAuthenticated=true` 说明认证机制接受了主体，不等于对任意业务对象有权。

客户端 JSON 中的 `tenantId`、`role` 或 `userId` 不能创建可信 `Authentication`。FactoryCare 从 OIDC/session/bearer 验证出的身份映射当前启用成员，再建立服务端上下文；业务请求字段只能作为待检查资源 ID。

## 8. 上下文从哪里来，又到哪里去

对 Session 应用，`SecurityContextRepository` 可以在请求开始时从 `HttpSession` 等位置加载上下文，并在认证变化后保存。现代 Spring Security 文档区分 `SecurityContextHolderFilter` 与较旧行为的 `SecurityContextPersistenceFilter`：前者负责加载并要求需要持久化的代码显式保存，二者不应同时存在。具体默认随版本和配置演进，不能从旧教程复制结论。

对无状态 bearer 请求，认证 Filter 每次验证 token 并为当前请求建立上下文，通常不把它保存到 HTTP Session。无论有状态还是无状态，请求完成后线程上的 holder 必须清空。线程池会复用线程；不清理可能让请求 B 看到请求 A 的身份，这是严重越权。

认证失败、授权异常、Controller 抛错和异步分派都要走清理路径。自己写 `try/finally` 模型时要覆盖所有退出；真实应用依赖 `FilterChainProxy` 和框架集成，并用异常路径测试证明。

## 9. ThreadLocal 不会自动跨异步边界

默认 holder 与当前线程关联。把任务提交到另一个 executor、使用 `CompletableFuture`、计划任务或消息消费者时，不能假设上下文自动传播。盲目改成 inheritable/global 策略可能让线程池继承陈旧身份。

若异步任务确实需要调用者身份，使用 Spring Security 提供的受控 context propagation wrapper，明确捕获、最小化并在任务结束清理；更常见的后台任务应携带不可伪造的 actor/tenant 快照或服务身份，并在执行时重新授权。日志 MDC 传播也不是安全上下文传播。

本章资产只在单线程 `ThreadLocal` 模型中断言清理，不声称覆盖 Reactor、虚拟线程或任意 executor。那些都需要目标运行模型的独立测试。

## 10. 认证与授权是两个问题

**Authentication** 回答“请求代表谁，凭据是否有效”。缺失、过期、签名错误或无法映射当前成员属于未认证。**Authorization** 回答“这个已识别主体能否执行该动作并访问该资源”。角色不足、data scope 不覆盖、跨租户或对象状态不允许属于无权限。

HTTP 语义上，受保护资源缺少有效认证通常返回 401；服务器理解身份但拒绝动作通常返回 403。401 响应可包含适用的 `WWW-Authenticate` challenge；浏览器页面也可能由 EntryPoint 重定向登录。FactoryCare API 选择稳定 `application/problem+json`，但仍保留正确状态语义。

不要为了隐藏资源而把所有情况机械改成同一个状态。跨租户资源可能按威胁模型返回不可区分的 404，但这是业务授权的显式策略；入口处未认证仍应有稳定 401。测试要分别证明状态、错误 code 和零业务副作用。

## 11. ExceptionTranslationFilter 不做授权

`ExceptionTranslationFilter` 的责任是把下游的 `AuthenticationException` 与 `AccessDeniedException` 转成可交互的 HTTP 行为，而不是决定谁有权限。它先调用后续 chain；若捕获认证异常，或发现访问拒绝发生在未认证/匿名主体，调用 `AuthenticationEntryPoint`；若已认证主体触发访问拒绝，调用 `AccessDeniedHandler`。

`AuthenticationEntryPoint` 可能返回 JSON 401、Basic challenge 或跳转登录页。`AccessDeniedHandler` 通常产生 403。API 与浏览器页面可以配置不同处理器，但必须与所选链匹配。把两者交换会让客户端误以为刷新凭据可以解决权限不足，或把未登录请求误报为永久禁止。

匿名支持常用一个 anonymous `Authentication` 表示未登录请求，方便统一表达式。它不是业务登录成功。异常翻译会通过 trust resolver 区分匿名与已认证主体；不能只看 `Authentication != null` 就返回 403。

## 12. 为什么 `@ControllerAdvice` 接不住所有安全错误

安全 Filter 在 `DispatcherServlet`/Controller 之前运行。若请求在认证或授权 Filter 中被拒绝，MVC 的异常映射尚未接管，普通 `@ControllerAdvice` 不一定能格式化该异常。因此 FactoryCare 要在 `AuthenticationEntryPoint` 与 `AccessDeniedHandler` 中写出与 OpenAPI `Problem` 一致的 `type/title/status/code/message/traceId`，同时保持 Content-Type。

Controller 或业务层随后抛出的业务授权异常可由 MVC Problem handler 处理。两条路径应共享一个安全的 Problem writer 或相同契约测试，不应复制出两个错误 DTO。错误正文不包含 principal、authority 全集、matcher 细节、堆栈或凭据。

## 13. 默认拒绝不是一句口号

默认拒绝由三层证据构成：

1. 链覆盖：每个请求至少匹配一条预期安全链，未知路径进入 catch-all；
2. 规则覆盖：公开 method+path 逐项列出，其他 API 至少要求认证，未知非 API 明确 `denyAll`；
3. 业务覆盖：已认证用户仍经过角色、租户、data scope 与资源状态检查。

只写 `.anyRequest().authenticated()` 解决不了业务越权；只写方法级授权解决不了没有匹配安全链；只在前端隐藏按钮不构成服务端授权。FactoryCare 威胁模型 TM-02 要求角色与 data scope 同时判定，入口链只能提供可信 actor 起点。

配置变更时做差分测试：增加新 Controller 后，它在未添加规则的情况下应被兜底拒绝或至少要求认证，而不是自动公开。公开端点列表应从 OpenAPI/明确设计产生，不从扫描到的 Controller 名称自动 permit。

## 14. Filter 顺序是依赖图

Filter 的正确位置由“它读什么、写什么、谁处理它的异常”决定：

- CORS 要先处理无 Cookie 的 preflight；
- 加载上下文要发生在读取当前主体之前；
- 认证 Filter 建立 `Authentication`，授权 Filter 才能消费；
- `ExceptionTranslationFilter` 必须包围可能抛安全异常的后续授权；
- CSRF 对浏览器状态变更在业务写入前拒绝；
- 清理必须在所有下游返回或抛错后执行。

Spring Security 提供 `addFilterBefore`、`addFilterAfter`、`addFilterAt`，相对一个已知框架 Filter 定位比猜整数顺序可靠。`addFilterAt` 放在同一槽位不保证多个 Filter 的确定顺序，除非另有明确排序。自定义 Filter 应尽量少，先检查是否已有认证 converter/provider、authorization manager 或 handler 扩展点。

## 15. 自定义 Filter 的安全合同

自定义 Filter 开始前写清：匹配哪些请求；需要上下文是否已加载；是否修改 Authentication；失败抛什么异常；谁翻译；是否允许异步/error dispatch；是否会被容器重复注册；日志允许哪些字段。

`OncePerRequestFilter` 可帮助控制一次请求分派中的调用，但“once”仍受 async/error dispatch 和注册方式影响。不要把一个既是 `@Bean`、又通过 `addFilterBefore` 加入安全链的 Filter 留给 Boot 自动注册而不测试调用次数。

若 Filter 自己 `catch (Exception)` 并返回 200 JSON，它会绕过异常链和状态语义。若在授权 Filter 之后才建立 context，则本请求已经按匿名拒绝。若不调用下游 chain，可能让合法请求静默短路。每种行为都应有正负请求测试。

## 16. 两条链的配置草图与版本边界

下面是结构草图，不是可直接复制的生产配置；具体 DSL 名称以 Boot 4.1 管理的 Spring Security 版本为准：

```java
@Bean
@Order(1)
SecurityFilterChain publicEntry(HttpSecurity http) {
    http.securityMatcher(exactPost("/api/v1/auth/login"))
        .authorizeHttpRequests(a -> a.anyRequest().permitAll());
    return http.build();
}

@Bean
@Order(2)
SecurityFilterChain application(HttpSecurity http) {
    http.securityMatcher(anyRequest())
        .authorizeHttpRequests(a -> a
            .requestMatchers("/api/v1/**").authenticated()
            .anyRequest().denyAll());
    return http.build();
}
```

真正实现还要配置 session/bearer、CSRF、CORS、headers、request cache、entry point 与 access denied handler。字符串 matcher、PathPattern matcher、Servlet path 处理及 DSL 在主版本间会变化；不能以这段伪代码替代编译。版本登记要求 Spring Security 由 Boot 4.1 BOM 管理，不独立覆盖版本，并对所有授权结论运行测试。

## 17. FactoryCare 请求矩阵

| 请求 | 预期链/上下文 | 首层结果 | 后续边界 |
| --- | --- | --- | --- |
| `POST /api/v1/auth/login` 合成合法输入 | 精确公共链 | 进入受控身份适配器 | Session 登录生命周期后续实现 |
| `GET /api/v1/auth/me` 无凭据 | 应用链、空/匿名上下文 | EntryPoint 401 Problem | 不查询业务成员详情 |
| 同请求有效 Session | 应用链、已认证 | 进入 Controller | 重新确认当前 membership |
| 审计导出，已登录但无 authority/scope | 应用链、已认证 | AccessDeniedHandler 403 或业务隐藏策略 | 无导出任务副作用 |
| 未知 `/debug/config` | catch-all | denyAll | 不能因没有 Controller 就当安全 |
| 浏览器状态变更缺 CSRF | 应用链 | CSRF Filter 403 | Controller 与数据库均未执行 |
| bearer 请求有效但成员已禁用 | 应用链、认证映射失败/无效 | 401 或设计的稳定拒绝 | 不信任 token 内旧角色 |

本章只解释链与上下文；“审计导出需要什么 authority”“跨租户返回 403 还是 404”属于业务授权章节。这里的目标是确保那些策略有可信主体可用且无法绕过链。

## 18. 诊断顺序：链、Filter、上下文、异常

安全请求失败时按证据顺序排查：

1. 请求实际 method、规范化 path、Servlet path 与 dispatch type；
2. `FilterChainProxy` 是否被容器调用；
3. 哪条 `SecurityFilterChain` 第一个匹配，哪些后续链被遮蔽；
4. 选中链包含哪些 Filter，顺序是什么；
5. 授权点前 `SecurityContext` 是空、匿名还是已认证，authorities 是什么；
6. 哪个 Filter/AuthorizationManager 抛出什么异常；
7. 哪个 EntryPoint/DeniedHandler 写了最终状态与 Problem；
8. 请求结束后 holder 是否清空、业务副作用是否为零。

不要一看到 403 就在 Controller 加 `permitAll`，也不要一看到 401 就关闭 CSRF。先找到第一处 expected/actual 偏差，修复对应边界，再重跑同一请求矩阵。

## 19. 典型故障与第一处证据

| 注入故障 | 第一处可信偏差 | 结果 | 修复 |
| --- | --- | --- | --- |
| 高优先级公共链 matcher 写成 `/api/**` | matched chain 是 public | 受保护 API 被 permit | method+path 精确 matcher，重跑全矩阵 |
| API 链 `anyRequest().permitAll()` | authorization rule 为 permit | 匿名请求进入业务 | 默认 authenticated/denyAll |
| 无 catch-all 链 | FilterChainProxy 找不到匹配 | 未知路径绕过安全 | 末尾全覆盖链 |
| 自定义认证 Filter 位于 AuthorizationFilter 后 | 授权时 context 为空 | 合法请求误 401 | 定位到认证与异常翻译之间的合适位置 |
| context 未在 finally 清理 | 下一请求开始已有旧 principal | 跨请求身份泄漏 | 依赖 FilterChainProxy 并覆盖异常路径 |
| EntryPoint/DeniedHandler 对调 | 未认证得 403、无权限得 401 | 客户端恢复策略错误 | 按认证状态与异常类型翻译 |
| Filter 容器与安全链双注册 | 单请求调用计数 2 | 重复认证/副作用 | 只保留一个注册边界 |

Spring Security debug 日志可列出请求经过的安全 Filter，但可能包含敏感请求信息，只在受控开发/测试环境短时启用并脱敏保存。生产不以 DEBUG 常开代替结构化安全审计。

## 20. 可重放测试设计

两条链至少覆盖：精确公共 POST 成功；同 path 的 GET 不公开；相似前缀/后缀不公开；所有受保护 API 无凭据 401；有效身份进入；已认证无权限 403；未知路径 deny；第一匹配链名称；每个请求 Filter 调用一次；正常与异常退出 context 都清空。

故障测试应逐项修改一个变量：交换链 order；放宽 matcher；改默认 permit；删除 catch-all；移动自定义 Filter；跳过 clear；交换异常 handler。每个注入必须先红灯、修复后用原请求重跑。只验证“返回不是 200”不够，还要断言准确状态、稳定 Problem code、无 Controller/Repository 副作用和上下文清理。

真实框架集成测试应启动 Boot 应用，使用目标 Spring Security 依赖，由 MockMvc/真实端口测试实际 chain。必要时打印 `FilterChainProxy` 中每条链的 matcher 与 Filter 类名；不要只单测自己复制的模型。本章离线 lab 是进入框架测试前的概念预言。

## 21. 常见错误及失败原因

- **只有一条宽 public matcher**：第一匹配链遮蔽后续保护；
- **把 `securityMatcher` 当链内 authorization matcher**：选链与授权层次混乱；
- **没有末尾 catch-all**：未匹配请求完全绕过 Spring Security；
- **所有静态/公开路径都 `ignoring`**：绕过整条安全链和附加防护；
- **`Authentication != null` 就当已登录**：anonymous token 也可能存在；
- **token 内有 role 就不查 membership**：禁用与数据范围变更无法立即生效；
- **只在 ControllerAdvice 统一 401/403**：Filter 异常发生在 MVC 之前；
- **自定义 Filter 任意放在链尾**：授权读取不到新 context 或异常无人翻译；
- **ThreadLocal 会自然跨线程且自然清除**：线程池复用会造成丢身份或泄身份；
- **Boot 启动成功即安全**：启动只证明 bean 可构建，不证明 matcher/顺序/负向请求；
- **开启 debug 后提交完整日志**：可能泄漏 Header、参数和认证元数据。

## 22. 120 秒口述模板

“Servlet 容器先调用 DelegatingFilterProxy，它委托 Spring bean FilterChainProxy。代理按 order 找第一条匹配的 SecurityFilterChain，只执行该链，所以宽 public matcher 会遮蔽后链；无匹配链则没有 Spring Security 保护。链先加载或建立 SecurityContext，Authentication 表示当前主体和 authorities，授权消费它，请求结束必须清空 ThreadLocal。默认拒绝要同时证明链有 catch-all、链内规则有 deny/authenticated 兜底、业务层仍检查租户与 data scope。ExceptionTranslationFilter 不做授权，它把下游 AuthenticationException/匿名拒绝交给 AuthenticationEntryPoint，通常形成 401；已认证无权限交给 AccessDeniedHandler，通常形成 403。反例是把 `/api/**` 放进高优先级 permitAll 链，后面的受保护链写得再严也不会运行。”

## 23. 标准、OWASP 建议与框架行为边界

截至 2026-07-17：

- [Jakarta Servlet Specification](https://jakarta.ee/specifications/servlet/) 定义 Servlet/Filter 容器合同；[RFC 9110 HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html) 定义 401/403 等 HTTP 语义；[RFC 9457 Problem Details](https://www.rfc-editor.org/rfc/rfc9457.html) 定义 `application/problem+json`。这些是标准层，不规定 FactoryCare 使用哪条 Spring DSL。
- [OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html) 给出最小权限、每请求校验与默认拒绝等工程建议，不是 Spring Filter 顺序规范。
- [Spring Security Servlet Architecture](https://docs.spring.io/spring-security/reference/servlet/architecture.html)、[Authentication Architecture](https://docs.spring.io/spring-security/reference/servlet/authentication/architecture.html)、[Authentication Persistence](https://docs.spring.io/spring-security/reference/servlet/authentication/persistence.html)、[Authorize HttpServletRequests](https://docs.spring.io/spring-security/reference/servlet/authorization/authorize-http-requests.html) 与 [Java Configuration](https://docs.spring.io/spring-security/reference/servlet/configuration/java.html) 描述当前框架的 `FilterChainProxy`、首条链、SecurityContext、异常翻译、matcher 与 DSL 行为。
- [Spring Boot System Requirements](https://docs.spring.io/spring-boot/system-requirements.html) 与 [Spring Framework Overview](https://docs.spring.io/spring-framework/reference/overview.html) 是项目版本组合的官方入口。`versions/registry.yml` 将 Boot 固定为 4.1.x、Framework 交由 Boot 管理为 7.x、Spring Security 交由 Boot 4.1 管理；不在章节中另钉一个 Security patch。

Filter 类、默认启用项、显式保存语义、matcher DSL 和顺序会演进，所以本章把它们标为框架行为，并要求目标版本集成测试。默认拒绝、上下文不跨请求泄漏、未认证与无权限可区分，则是项目必须长期保持的不变量。
