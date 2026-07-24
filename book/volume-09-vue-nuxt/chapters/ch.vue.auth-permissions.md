---
schema_version: 2
edition: 2026.2-draft
id: ch.vue.auth-permissions
title: 登录态、路由保护、权限 UI 与安全边界
responsibility: 在前端同步认证状态、受保护导航和权限提示，明确隐藏按钮与路由守卫不是服务端授权，所有敏感操作仍由后端默认拒绝。
volume: '09'
order: 11
level: L2+
status: drafting
path: book/volume-09-vue-nuxt/chapters/ch.vue.auth-permissions.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.vue.router-navigation
- ch.vue.server-state
- ch.security.authorization-rbac-abac
version_surfaces:
- vue-3
- pinia
- vite
- vitest
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“登录态、路由保护、权限 UI 与安全边界”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - vue-auth-session-ui
  - vue-permission-ui-boundary
  covers_topics:
  - vue.auth-bootstrap
  - vue.session-expiry
  - vue.auth-route-guard
  - vue.return-url-validation
  - vue.permission-directive
  - vue.capability-driven-ui
  - vue.forbidden-state
  - vue.client-server-authorization-boundary
  uses_capabilities:
  - web.vue-router-navigation
  - web.vue-client-state
  - web.javascript-network-race
  - security.authentication
  - security.authorization-policy
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“登录态、路由保护、权限 UI 与安全边界”构建可运行程序与测试：实现认证 bootstrap、受保护路由和权限 UI，并用 401/403 夹具验证安全边界；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - vue-auth-session-ui
  - vue-permission-ui-boundary
  covers_topics:
  - vue.auth-bootstrap
  - vue.session-expiry
  - vue.auth-route-guard
  - vue.return-url-validation
  - vue.permission-directive
  - vue.capability-driven-ui
  - vue.forbidden-state
  - vue.client-server-authorization-boundary
  uses_capabilities:
  - web.vue-router-navigation
  - web.vue-client-state
  - web.javascript-network-race
  - security.authentication
  - security.authorization-policy
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: component-test-router-integration-forbidden-api-fixture
- id: diagnose
  kind: fault-diagnosis
  text: 面对“开放重定向、客户端放行越权操作或刷新时短暂泄露敏感界面”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - vue-auth-session-ui
  - vue-permission-ui-boundary
  covers_topics:
  - vue.auth-bootstrap
  - vue.session-expiry
  - vue.auth-route-guard
  - vue.return-url-validation
  - vue.permission-directive
  - vue.capability-driven-ui
  - vue.forbidden-state
  - vue.client-server-authorization-boundary
  uses_capabilities:
  - web.vue-router-navigation
  - web.vue-client-state
  - web.javascript-network-race
  - security.authentication
  - security.authorization-policy
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 登录态、路由保护、权限 UI 与安全边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Router、导航、布局与页面边界》](ch.vue.router-navigation.md)：受保护页面和返回路径建立在可预测的导航与失败模型上。
- [《服务端状态、加载、错误、取消与竞态》](ch.vue.server-state.md)：认证 bootstrap、过期和 401/403 都是具有加载、错误和竞态的服务端状态。
- [《URL/方法授权、RBAC、ABAC 与默认拒绝》](../../volume-06-enterprise-architecture/chapters/ch.security.authorization-rbac-abac.md)：权限 UI 只能反映已定义的 RBAC/ABAC 策略，服务端仍是授权权威。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文和离线策略夹具可验证前端状态/导航合同，但不能证明真实 Cookie/Token、TLS、浏览器、身份提供方、后端 Session、RBAC/ABAC、多租户数据权限或审计已经安全。Vue Router、Pinia、HTTP 与 OWASP 官方资料复核日为 **2026-07-17**；配套工件不访问网络、不修改 `PROGRESS.md`。

认证回答“当前请求代表谁”，授权回答“这个主体能否对这个资源执行这个动作”。Vue 前端需要把会话 bootstrap、路由体验、权限提示和 401/403 反馈同步起来，但浏览器里的任何状态都可被用户观察和修改。隐藏按钮只能减少误操作，路由守卫只能阻止正常导航，Pinia 中的角色字符串不能让 API 可信。

本章建立四个互不冒充的合同：

```text
Auth bootstrap  → 前端是否知道当前会话
Route guard     → 正常导航应该进入页面、登录页还是 forbidden
Capability UI   → 应显示/禁用哪些操作及原因
Server policy   → 每个 API 请求是否真正被允许（唯一安全权威）
```

任何敏感操作都必须在最后一层默认拒绝并逐请求授权。反例：维修人员只能修改自己租户、自己被派工单的某些字段，这需要后端按主体、租户、资源归属、状态和动作执行 RBAC/ABAC/data-scope 策略；前端过滤列表或隐藏按钮无法解决。

本章不实现密码学、OAuth/OIDC 登录协议、MFA、Cookie 属性、CSRF、防重放、服务端 Session/JWT 验证、RBAC 表结构或多租户 SQL。它消费前置安全章节定义的认证/授权结果，只负责 Vue 端同步和证据边界。

## 1. 完成标准与证据入口

canonical oracle 是：**未登录、已登录、过期、无权限和有权限矩阵中的 URL、UI、401/403 处理与服务端结果一致，直接调用受限 API 仍被拒绝。** 完成本章应能：

1. 用 unknown/bootstrapping/authenticated/anonymous 表达会话，不在 bootstrap 前猜登录；
2. 让 bootstrap 具备单飞、请求身份和失效边界，旧 `/me` 结果不能复活已退出会话；
3. 在 Pinia 安装后由异步 Router guard 等待 bootstrap，并避免登录页重定向循环；
4. 校验 return URL，仅允许已知站内目的地，不把 query 直接交给 `location.href`；
5. 用服务端下发 capability 映射 UI，而不是在每个组件硬编码角色判断；
6. 说明 permission directive/component 只控制呈现，不授予调用 API 的权利；
7. 区分 401（缺有效认证凭据）和 403（服务器理解但拒绝），分别处理过期与 forbidden；
8. 用直接调用 fixture 证明：即使强行显示按钮、跳过守卫、手写请求，服务端仍拒绝；
9. 注入开放重定向、客户端授权或敏感 UI flash，找到首个可信证据并重跑同一矩阵。

配套入口：

- [认证、路由、能力 UI 与服务端拒绝示例](../../../examples/encyclopedia/ch.vue.auth-permissions/README.md)
- [开放重定向、敏感闪现与越权实验](../../../labs/encyclopedia/ch.vue.auth-permissions/README.md)
- [公开稳定红灯练习](../../../exercises/encyclopedia/ch.vue.auth-permissions/README.md)

离线绿灯运行纯策略和假服务端。正式 G4 还需真实 Vue component test、Router memory/web history、浏览器刷新、Cookie/Token 传输、Network 401/403、后端策略/数据范围、直接 API 调用、跨租户 ID、审计日志、页面无敏感闪现截图以及安全测试。

## 2. 认证状态机：`unknown` 不是 `anonymous`

页面刷新时，浏览器可能带有有效会话 Cookie，但 JavaScript 尚未请求 `/api/session`；也可能没有会话；还可能请求超时。初始状态应是 unknown，而不是乐观 authenticated 或直接 anonymous：

```ts
type AuthState =
  | { tag: 'unknown' }
  | { tag: 'bootstrapping'; requestId: number }
  | { tag: 'authenticated'; subject: SessionSubject; capabilities: ReadonlySet<Capability> }
  | { tag: 'anonymous'; reason: 'missing' | 'expired' | 'signed-out' }
  | { tag: 'bootstrap-error'; message: string }
```

如果默认 `authenticated=true`，刷新时会先渲染工资、设备密钥或删除按钮，再在 `/me` 401 后隐藏，形成 sensitive UI flash。若默认 anonymous 并立刻 redirect，持有效会话的用户会先跳登录再跳回来，可能产生循环。unknown/bootstrapping 期间应渲染不含敏感数据的 app shell/skeleton，并让 protected navigation pending。

Bootstrap 本身就是上一章的服务端状态：它需要 request identity、abort、single-flight 和 session generation。退出登录必须递增 generation，使任何旧 bootstrap Promise 即使晚到也不能恢复 authenticated。多个守卫同时触发时应共享同一个 in-flight Promise，而不是并发请求 `/me`。

```text
unknown → bootstrap start(g=7,id=1) → bootstrapping
  ├─ 200 valid subject/capabilities + still current → authenticated
  ├─ 401 + still current → anonymous(missing/expired)
  ├─ network error + still current → bootstrap-error（不要伪装成未登录）
  └─ signOut changes generation → old response discarded
```

网络错误与 401 不同：网络中断不证明会话无效。产品可以显示重试/离线提示，不能把所有失败都清会话并无限跳登录。

## 3. 会话 Store：共享客户端镜像，不是授权权威

Pinia 适合让 header、Router 和页面共享认证镜像，但它只保存服务器会话的当前客户端认知。`subject`/capabilities 来自受信服务端响应；DevTools 修改 store 只能改变本地 UI，不应改变 API 结果。

Pinia 官方提醒组件外调用 store 要在 `app.use(pinia)` 后执行。在 SPA 中，最安全的组织是先创建/安装 Pinia，再创建或注册会在执行时调用 store 的 guard；不要在模块顶层过早 `useSessionStore()`。SSR 还需按请求隔离 Pinia，不能使用跨用户单例，本章不实现 SSR。

```ts
// Responsibility: 保存前端对当前会话的可观察镜像与 bootstrap single-flight。
// Data source: /api/session 返回的 subject/capabilities；服务端是权威。
// Mapping: 200→authenticated；401→anonymous；网络失败→bootstrap-error；旧 generation 丢弃。
// Side effects: 调用会话 API、abort；signOut 清前端镜像并触发服务端注销适配器。
export const useSessionStore = defineStore('session', () => {
  const state = ref<AuthState>({ tag: 'unknown' })
  let generation = 0
  let inFlight: Promise<void> | null = null

  function bootstrap(): Promise<void> {
    if (state.value.tag === 'authenticated' || state.value.tag === 'anonymous') return Promise.resolve()
    if (inFlight) return inFlight
    const ownGeneration = generation
    inFlight = loadSession().then((result) => {
      if (generation !== ownGeneration) return
      state.value = mapSessionResult(result)
    }).finally(() => {
      if (generation === ownGeneration) inFlight = null
    })
    return inFlight
  }

  function expire() {
    generation += 1
    inFlight = null
    state.value = { tag: 'anonymous', reason: 'expired' }
  }

  const can = (capability: Capability) =>
    state.value.tag === 'authenticated' && state.value.capabilities.has(capability)

  return { state: readonly(state), bootstrap, expire, can }
})
```

凭据究竟使用 HttpOnly Cookie、内存 access token 或 OIDC 流程属于安全架构决策。前端章节不推荐把敏感 token 随便放 localStorage，也不以“Vue 能读到 token”作为正确性。Cookie 方案还涉及 SameSite/Secure/HttpOnly 和 CSRF；Bearer token 涉及获取、刷新、泄露与撤销。必须遵循认证系统合同和威胁模型。

## 4. Route guard：导航体验，而非门锁

Vue Router 官方说明全局 `beforeEach` 可异步，导航在 guards resolve 前 pending；guard 可返回 `false` 取消，或返回 Route Location 发起重定向。受保护路由可用 meta 声明认证与 capability 要求：

```ts
declare module 'vue-router' {
  interface RouteMeta {
    public?: boolean
    capability?: Capability
  }
}

// Responsibility: 把路由 meta 与当前会话镜像映射到 allow/sign-in/forbidden 导航结果。
// Data source: normalized target route 和 Pinia session store；不读取 DOM 按钮状态。
// Mapping: public→allow；unknown→await bootstrap；anonymous→sign-in；缺 capability→forbidden。
// Side effects: 可能启动一次 bootstrap 并返回重定向；不授权或调用敏感 API。
router.beforeEach(async (to) => {
  if (to.meta.public) return true
  const session = useSessionStore()
  await session.bootstrap()

  if (session.state.tag !== 'authenticated') {
    return { name: 'sign-in', query: { returnTo: safeReturnPath(to.fullPath) }, replace: true }
  }
  if (to.meta.capability && !session.can(to.meta.capability)) {
    return { name: 'forbidden', query: { from: to.fullPath }, replace: true }
  }
  return true
})
```

Public route 必须先放行，否则 `/sign-in` 也被要求登录会无限重定向。Guard 在每次导航重新读取 session，不应捕获过时布尔值。即使 guard 放行，页面的数据请求仍可能因会话刚过期得到 401，或因资源级策略得到 403；页面必须处理真实响应。

攻击者可以在地址栏直接输入 URL、在 DevTools 删除 guard、导入模块调用 API，或绕过整个前端。因此 guard 的证据是 URL/组件树/导航体验，不是后端授权证据。

## 5. Return URL：只接收站内、已知且合法目的地

登录后返回原目标能改善体验，也会引入开放重定向。危险写法：

```ts
window.location.href = String(route.query.returnTo)
```

攻击者构造 `/sign-in?returnTo=https://evil.example/phish`，登录后把用户送到钓鱼站。OWASP 建议避免直接使用用户输入；必须使用时按 allow-list 验证。

前端可采用两类合同：

1. **Named-route allow-list**：query 只存内部业务 key，例如 `work-order-detail` 加经过类型校验的 params，再用 Router 生成 URL；最容易审计。
2. **Internal-path validator**：只允许以单个 `/` 开始的同源路径，拒绝 `//host`、反斜线、控制字符、绝对 scheme、登录页自循环和不允许区域，再交给 `router.replace()` 而不是 `location.href`。

```ts
// Responsibility: 将不可信 returnTo 缩减为允许的站内 Router 路径。
// Data source: 登录页 query；攻击者可完全控制。
// Mapping: 有效单斜线站内路径→自身；绝对/协议相对/反斜线/登录循环→安全首页。
// Side effects: 纯函数，不导航；调用者只能把返回值交给 router.replace。
export function safeReturnPath(raw: unknown): string {
  if (typeof raw !== 'string' || !raw.startsWith('/') || raw.startsWith('//')) return '/work-orders'
  if (raw.includes('\\') || /[\u0000-\u001f\u007f]/u.test(raw)) return '/work-orders'
  const url = new URL(raw, 'https://factorycare.invalid')
  if (url.origin !== 'https://factorycare.invalid' || url.pathname === '/sign-in') return '/work-orders'
  return `${url.pathname}${url.search}${url.hash}`
}
```

生产实现还应结合路由表、base path 与允许租户上下文。单纯 `startsWith('/')` 不足以拒绝 `//evil.example`。服务端 OAuth redirect URI 验证是另一层，不能由这个 Vue helper 替代。

## 6. Capability-driven UI：表达动作，不硬编码角色

组件里到处写 `user.role === 'ADMIN'` 会把后端策略复制到前端：角色组合、租户、资源归属或工单状态变化时，UI 与服务端漂移。前端更适合消费可展示的 capability，例如：

```ts
type Capability =
  | 'work-order.read'
  | 'work-order.assign'
  | 'work-order.close'
  | 'work-order.delete'
```

Capability 仍只是服务器决策的摘要，适合决定是否展示操作和解释 forbidden。资源级条件可能无法用全局 capability 表达：用户有 `work-order.close` 也不代表能关闭任意租户或已取消工单。按钮点击后的 API 必须再次携带资源身份，由服务端执行完整策略。

UI 有三种常见呈现：

- 隐藏：动作对用户完全不相关，减少噪声；
- 禁用并解释：用户可能通过流程获得权限，需要告知原因；
- 可见、点击后由 API 判定：资源状态高度动态，但应避免诱导；收到 403 要稳定显示 forbidden。

选择是产品/无障碍决策，不能改变安全要求。

## 7. Permission directive 的有限责任

自定义 `v-can` 可以统一隐藏/禁用逻辑，但不要让 directive 发请求或实现后端策略：

```ts
// Responsibility: 根据当前 capability 镜像控制一个元素的呈现，减少重复模板判断。
// Data source: binding.value capability 与注入 session.can；均只用于客户端体验。
// Mapping: can=true→保留；false→按统一策略隐藏或禁用并写说明。
// Side effects: 修改 DOM 呈现；不授予权限、不替代 API、卸载时不得留下旧节点状态。
export const vCan: Directive<HTMLElement, Capability> = {
  mounted(element, binding) {
    applyPermissionPresentation(element, binding.value)
  },
  updated(element, binding) {
    applyPermissionPresentation(element, binding.value)
  },
}
```

Directive 的风险是可测试性和响应式更新：若只在 mounted 判断，bootstrap 完成或会话切换后可能保留旧 UI；直接 `remove()` 也可能难以恢复。组件/`v-if="session.can(...)"` 往往更透明。无论用哪一种，测试都要改变 capability 并验证更新，而不是只测初次挂载。

最重要的注释应写在组件附近：“这里隐藏按钮只控制体验；服务端仍逐请求授权。”这不是免责声明，而是防止后续维护者把客户端判断升级成安全假设。

## 8. 401 与 403：不要合并成“没权限”

[RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html) 定义 401 表示请求缺少目标资源所需的有效认证凭据；403 表示服务器理解请求但拒绝履行。前端常见处理：

- **401**：当前会话可能过期/无效。让 session generation 失效、清敏感服务器缓存、保存经过校验的 return path，并导航到 sign-in。避免每个并发请求各弹一次、各 redirect 一次，可由单一 coordinator 去重。
- **403**：主体通常仍已认证，但缺该动作/资源权限。保留会话，显示 forbidden/权限变化提示，刷新 capability 或当前资源；不要无条件登出。

这不是说所有后端都必须公开资源存在性。安全策略可能对某些未授权资源返回 404；前端以项目 API 合同为准。不能仅凭状态码猜业务细节，更不能把 403 当 token 刷新信号无限重试。

会话在页面打开后可能失效，权限也可能被管理员撤销。Guard 只在导航时检查镜像；最终 API 401/403 永远需要处理。已有页面的敏感数据应按会话边界清除，但审计日志和服务端副作用不能由清 Pinia 撤销。

## 9. 服务端授权：默认拒绝、逐请求验证

[OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html) 建议 deny by default，并对每个请求验证权限。FactoryCare 的删除接口至少需要：已认证 subject、当前 tenant、动作 capability、目标工单 tenant/状态/归属和可能的审计要求。前端只知道其中一部分。

```text
按钮隐藏                  体验证据
Router guard forbidden    导航证据
Pinia capability=false    客户端镜像证据
POST /orders/WO-9/delete  服务端授权证据 ← 必须独立测试
```

负向测试必须直接调用 API fixture，而不是通过 UI 点击：

| 主体 | UI | 直接 API | 期望 |
|---|---|---|---|
| anonymous | 删除按钮隐藏 | 手写 DELETE | 401 |
| authenticated，无 delete | 隐藏/禁用 | 手写 DELETE | 403 |
| 有全局 capability，跨租户 | 可能误显示 | 手写 DELETE | 403/项目合同 |
| 有权且资源状态允许 | 显示 | DELETE | 2xx |
| 权限刚撤销、UI 仍旧 | 暂时显示 | DELETE | 403，UI 随后同步 |

如果测试只断言按钮不存在，它没有测试授权。反过来，服务端 403 通过也不代表 UI 体验良好；两层都要测，但证据名称不能混淆。

## 10. Bootstrap、导航与页面渲染顺序

一个避免敏感闪现的启动序列：

```text
create app
  → create/install Pinia
  → create Router and register guards
  → initial navigation enters protected guard
  → session unknown: await single bootstrap
      → authenticated + capability: allow target
      → authenticated but missing capability: forbidden
      → anonymous: sign-in(returnTo=safe internal path)
      → network error: recoverable bootstrap error page
  → only then mount/render sensitive route content
```

也可先 mount 一个不含敏感内容的 root shell，由 RouterView 在 guard resolve 后出现。关键 oracle 不是“页面闪得很快看不见”，而是 bootstrap pending 期间敏感 selector 根本不存在。用 fake timers 或人为慢 `/me` 测试，截图/DOM 观察真实浏览器。

多个 API 同时 401 时，session expiry handler 要幂等：第一次使 generation 失效并导航；后续只复用同一过程。登录成功后只能导航到校验过的 return path，并重新 bootstrap/刷新权限，不把旧 anonymous 请求的晚到结果覆盖新会话。

## 11. 可复现认证/权限矩阵

| 场景 | bootstrap | guard URL | 敏感 UI | API fixture | 前端处理 |
|---|---|---|---|---|---|
| unknown pending | 未完成 | pending/shell | 不渲染 | 未调用 | 等待，不猜 |
| anonymous | 401/missing | sign-in + safe return | 隐藏 | 直接调用 401 | 保持 anonymous |
| authenticated + capability | 200 | 原目标 | 显示 | 2xx | success |
| authenticated no capability | 200 | forbidden/页面内提示 | 隐藏/禁用 | 直接调用 403 | 保持登录 |
| session expired | 业务 API 401 | sign-in | 清敏感数据 | 401 | generation 失效 |
| capability revoked | 初始 UI 可能旧 | 当前页 | 可短暂旧 | 403 | forbidden + refresh |
| malicious return URL | 不相关 | safe default | 不相关 | 不相关 | 拒绝外域 |
| guard bypass | 强行直达 | 页面可被加载 | 可强行显示 | 401/403 | 服务端仍拒绝 |

测试必须同时断言 URL、auth tag、UI capability、401/403 分类和服务端结果。只断言某个 `v-if` 或只断言 router redirect 都不足以满足 canonical oracle。

## 12. 故障诊断：首个可信证据

### 12.1 开放重定向

输入 `https://evil.example`、`//evil.example`、反斜线、控制字符、`/sign-in` 自循环和合法站内路径。若结果直接进入 `location.href`，首因是 return URL 未按站内 allow-list 归一化。修复纯 validator 与 Router 导航，再重跑相同恶意表。

### 12.2 客户端放行越权操作

强行把 `session.capabilities` 改成包含 delete、直接调用 API fixture。若服务器根据客户端布尔值返回成功，首因在服务端授权边界，而不是 directive。修复 fixture/后端逐请求策略，确保无 capability/跨租户默认 403；UI 修复作为独立体验工作。

### 12.3 刷新时敏感界面闪现

让 bootstrap Promise 暂停，检查 DOM。若 protected component 在 session unknown 时已 mount，首因是初始 authenticated 假设或 guard/mount 顺序。引入 unknown shell 并让 guard await bootstrap；用同一受控 Promise 证明 settle 前无敏感 selector。

### 12.4 403 导致登出循环

记录 API status、session generation 和 navigation trace。若 403 被统一 interceptor 当 401，清会话并跳登录，首因是错误分类。保留 authenticated，转 forbidden；只有项目合同认定的 401/过期信号才失效会话。

### 12.5 旧 bootstrap 复活退出会话

固定 bootstrap start→signOut→old bootstrap resolve。若状态又 authenticated，首因是缺 generation/request identity。退出递增 generation、abort，并在 commit 前检查；重跑同一顺序。

## 13. 证据分层与未验证边界

配套离线资产验证：unknown 不渲染敏感内容；bootstrap 映射 anonymous/authenticated；站内 return path 与恶意外域矩阵；route decision 的 sign-in/forbidden/allow；capability UI；401 清会话、403 保留会话；假服务端按自己的 subject/resource policy 拒绝直接调用；公开夹具稳定暴露 open redirect、敏感 flash 和 client-only authorization。

未验证：真实 Vue/Pinia/Router 生命周期与 DOM；真实 Cookie/Token、CORS/CSRF、TLS；身份提供方；密码/MFA；后端 Session/JWT 校验；生产 RBAC/ABAC/data scope；跨租户数据库查询；审计；真实 Network 401/403；浏览器刷新 flash；XSS 对前端状态的影响；渗透测试。离线 fixture 的“SERVER_DENY”不是生产 RBAC 证据。

## 14. 规范索引与版本表面

- [Vue Router Navigation Guards](https://router.vuejs.org/guide/advanced/navigation-guards.html)：全局 guard、异步 pending、取消与 Route Location 重定向。核验于 2026-07-17。
- [Pinia：组件外使用 Store](https://pinia.vuejs.org/core-concepts/outside-component-usage.html)：`app.use(pinia)` 时序与 guard 中使用 store。核验于 2026-07-17。
- [RFC 9110 HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html)：401 与 403 语义。核验于 2026-07-17。
- [OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)：最小权限、默认拒绝、逐请求验证。核验于 2026-07-17。
- [OWASP Unvalidated Redirects and Forwards Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Unvalidated_Redirects_and_Forwards_Cheat_Sheet.html)：避免不可信目标、allow-list 验证。核验于 2026-07-17。

本章 `stable_core: false`：Vue Router/Pinia/Vitest/Vite 与认证集成会变化。稳定不变量是 unknown bootstrap、站内 return URL、能力 UI 仅作体验、401/403 分类、服务端默认拒绝与逐请求授权。具体 API、凭据方案和测试工具属于版本/安全架构表面。

## 15. 最终检查表

- [ ] 初始状态是 unknown/bootstrapping，不乐观显示敏感 UI。
- [ ] bootstrap 单飞且有 generation/request identity；退出后旧结果不能复活。
- [ ] Pinia 在 guard 使用前已安装，public route 不进入认证循环。
- [ ] return URL 只允许已知站内目的地，拒绝绝对/协议相对/反斜线。
- [ ] UI 消费 capability，不复制角色与资源级策略。
- [ ] directive/component 注释明确“只控制体验，不授权”。
- [ ] 401 与 403 分开；403 不无条件登出，401 流程幂等。
- [ ] 每个敏感 API 由服务端默认拒绝并逐请求验证。
- [ ] 测试包含绕过 guard、强显按钮、直接 API 和跨租户负例。
- [ ] bootstrap pending 时 DOM 无敏感 selector，有受控证据。
- [ ] 首次失败、首因、修复与同一矩阵重跑可追溯。
- [ ] 真实网络、浏览器、Cookie、后端 RBAC 与安全测试未验证项明确报告。
