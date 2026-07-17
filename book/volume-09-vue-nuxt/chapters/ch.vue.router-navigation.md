---
schema_version: 2
edition: 2026.2-draft
id: ch.vue.router-navigation
title: Router、导航、布局与页面边界
responsibility: 用路由记录、参数、嵌套布局和导航守卫表达页面边界，区分路由可达性与真正的服务端授权。
volume: '09'
order: 8
level: L2
status: drafting
path: book/volume-09-vue-nuxt/chapters/ch.vue.router-navigation.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.vue.components-contracts
version_surfaces:
- vue-3
- vite
- typescript
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“Router、导航、布局与页面边界”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - vue-router-records
  - vue-navigation-flow
  covers_topics:
  - vue.router-record
  - vue.route-param-query
  - vue.nested-route-view
  - vue.route-layout
  - vue.programmatic-navigation
  - vue.navigation-guard
  - vue.navigation-failure
  - vue.route-component-lifecycle
  uses_capabilities:
  - web.vue-components-contracts
  - web.vue-router-navigation
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现工单列表、详情和嵌套布局路由并保存深链接与导航失败证据；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - vue-router-records
  - vue-navigation-flow
  covers_topics:
  - vue.router-record
  - vue.route-param-query
  - vue.nested-route-view
  - vue.route-layout
  - vue.programmatic-navigation
  - vue.navigation-guard
  - vue.navigation-failure
  - vue.route-component-lifecycle
  uses_capabilities:
  - web.vue-components-contracts
  - web.vue-router-navigation
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: route-matrix-navigation-trace-deep-link-smoke
- id: diagnose
  kind: fault-diagnosis
  text: 面对“参数复用未刷新、守卫无限重定向或把客户端守卫误当授权”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - vue-router-records
  - vue-navigation-flow
  covers_topics:
  - vue.router-record
  - vue.route-param-query
  - vue.nested-route-view
  - vue.route-layout
  - vue.programmatic-navigation
  - vue.navigation-guard
  - vue.navigation-failure
  - vue.route-component-lifecycle
  uses_capabilities:
  - web.vue-components-contracts
  - web.vue-router-navigation
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Router、导航、布局与页面边界

> 本章状态为 **drafting**。正文与工件可用于学习和作者自检，但不能证明学习者已经完成无 AI 独立构建、故障诊断或限时复述，也不会自动改变 `PROGRESS.md`。

SPA 里把组件放进菜单并不等于建立页面。页面必须有可复制、可刷新、可前进后退的 URL；URL 要映射到确定的布局和组件树；参数变化要刷新正确数据；取消与重定向要有可判断结果。Vue Router 负责客户端 URL 与组件树的协调，但它不能证明调用者有权读取服务端工单。

FactoryCare 本章建立 `/work-orders` 列表和 `/work-orders/:workOrderId` 详情。二者共享工单中心布局，列表筛选放在 query 中，详情身份放在 param 中。未登录访问详情会被导航守卫送到 sign-in，并保留 return URL；详情有未保存草稿时离开会取消。测试不只断言“看到某段文字”，而是同时记录 URL、`matched` 组件树和 `router.push()` 的成功/失败结果。

本章不引入 Pinia、Nuxt file-based routing、数据 loader、真实 API、服务端 Session/JWT 实现、页面缓存、复杂动画或生产服务器配置。路由守卫是客户端体验边界，不是安全边界。官方 Vue Router 文档与安装页复核日为 **2026-07-17**；配套工件固定 Vue Router `5.1.0`，使用 v4/v5 共同的显式路由记录 API。

## 1. 完成标准：路由矩阵三列必须一致

canonical oracle 是：**直接访问、参数变化、嵌套导航、取消和重定向场景的 URL、组件树和导航结果与路由矩阵一致。** 建议先写矩阵再写配置：

| 场景 | 期望 URL | 期望 matched / DOM | 导航结果 |
|---|---|---|---|
| 直接访问列表 | `/work-orders?status=CREATED` | `WorkOrderLayout > WorkOrderListPage`，筛选为 CREATED | success |
| 直接访问详情（已认证） | `/work-orders/WO-3001` | `WorkOrderLayout > WorkOrderDetailPage`，prop=WO-3001 | success |
| 详情参数变化 | `/work-orders/WO-3002` | 复用详情实例，但加载 ID/次数更新 | success |
| 未保存草稿离开 | URL 仍为旧详情 | 旧组件树保留 | aborted failure |
| 未认证访问详情 | `/sign-in?redirect=...` | SignInPage | redirect 后 success，有限次数 |
| 未知深链 | 原未知 URL | NotFoundPage | success |

三个 outcome：

- 120 秒解释路由记录、param/query、嵌套 outlet、程序化导航、守卫、失败和组件复用的职责，给出服务端授权这个反例。
- 从空目录实现工单列表、详情和嵌套布局，保存直接深链、参数变化、取消、重定向与 catch-all 证据。
- 注入参数复用未刷新、守卫循环和客户端守卫冒充授权，找第一可信证据，修复并重跑相同矩阵。

配套工件：

- [Router 路由矩阵观察例](../../../examples/encyclopedia/ch.vue.router-navigation/README.md)
- [Router 导航故障实验](../../../labs/encyclopedia/ch.vue.router-navigation/README.md)
- [公开参数复用红灯练习](../../../exercises/encyclopedia/ch.vue.router-navigation/README.md)

公开练习初始红灯是预期状态。通过强制给 `<RouterView :key="$route.fullPath">` 销毁所有页面来绕过复用问题、删除 checker 或只改文案，都不算掌握参数生命周期。

## 2. Router 的职责边界

Vue Router 是 Vue 官方客户端路由方案。它观察 history location，匹配路由记录，渲染 `<RouterView>`，让 `<RouterLink>` 与 `router.push()` 更新 history，并在导航管线中运行守卫。它处理的是**可达性与呈现**：某 URL 应显示哪些组件，客户端是否取消或改道。

它不负责：

- 判断数据库中的工单是否属于当前租户；
- 隐藏敏感字段后就认为数据安全；
- 签发/验证服务器凭证；
- 让生产 Web History 服务器自动返回 `index.html`；
- 在刷新时自动还原未持久化的组件 ref；
- 保证真实浏览器 focus、scroll 和 back/forward 都符合产品预期。

守卫内的 `authenticated` 布尔值可以改善 UX，攻击者仍可绕过前端直接请求 API。真正服务端授权必须认证会话、验证租户与资源关系、限制字段并记录审计。把这条边界写进详情页与测试，是为了防“页面进不去，所以接口安全”的错误推理。

## 3. 路由记录是 URL 到组件树的声明合同

最小路由由 `path` 与 `component` 构成；实际项目还会用 `name`、`children`、`props`、`redirect`、`meta`。显式记录让路由矩阵可审查：

```ts
const routes: RouteRecordRaw[] = [
  {
    path: '/work-orders',
    component: WorkOrderLayout,
    children: [
      { path: '', name: 'work-order-list', component: WorkOrderListPage },
      {
        path: ':workOrderId',
        name: 'work-order-detail',
        component: WorkOrderDetailPage,
      },
    ],
  },
]
```

`path` 是外部 URL 合同，改名可能破坏书签、邮件、监控、浏览器历史和外部系统链接；`name` 是代码内稳定引用。页面文件名只是实现细节。不要把后端 Java 类名或数据库表名直接泄漏进 URL；选择用户/业务能理解且能长期维护的资源路径。

记录顺序和匹配语法会影响结果。动态 segment 用冒号；catch-all 使用 `/:pathMatch(.*)*`。不要再用 Vue Router 3 的裸 `*` 语法。未知 URL 应有明确终点，而不是匹配成功但 `<RouterView>` 空白。

## 4. param、query 与普通页面状态怎么选

判断标准是“这个状态是否定义资源身份、是否应进入可分享 URL”：

- `workOrderId` 决定当前资源，放 path param：`/work-orders/:workOrderId`；
- 列表 `status`、页码、排序影响可分享视图，放 query；
- 纯视觉展开、临时 hover 不值得进入 URL，放本地状态；
- 跨页面但不适合公开 URL 的会话状态可能进入 store，但不能替代服务端真相。

params/query 都来自不可信字符串。TypeScript route 类型不能证明 URL 值合法。路由到页面的 `props` 函数应归一化：

```ts
props: route => ({
  status: normalizeStatusQuery(route.query.status),
})
```

`route.query.status` 可能缺失、数组或未知文本。本章仅接受 `CREATED`、`IN_PROGRESS`、`COMPLETED`，否则映射 `ALL`；测试用明确的 `UNKNOWN` 表示非法输入，不把它当成业务状态。真正请求 API 前仍需后端校验。

### 4.1 props 解耦页面与 Router

详情记录将 param 映射成普通 Prop：

```ts
props: route => ({ workOrderId: String(route.params.workOrderId) })
```

页面声明 `defineProps<{ workOrderId: string }>()`，不用在每处读取整个 route。这样组件测试可以直接 setProps，数据依赖更显式。并非任何页面都必须用 props；需要 query/hash/route meta 的协调页面可以使用 `useRoute()`，但应 watch 具体属性，不要 watch 整个 reactive route。

## 5. 嵌套路由表达布局与页面层级

顶层 `App` 有一个 `<RouterView>`；匹配 `/work-orders/...` 时先渲染 `WorkOrderLayout`。布局内部再放 `<RouterView>`，子记录在这里渲染列表或详情。URL segment 与组件层级对应：

```text
App
└─ RouterView → WorkOrderLayout          /work-orders
   ├─ section navigation
   └─ RouterView → WorkOrderListPage     /work-orders
                → WorkOrderDetailPage   /work-orders/:workOrderId
```

子 path `''` 表示父 URL 的默认页面；子 path `'settings'` 拼到父 path 后。以 `/` 开头的子 path 会成为根路径，仍可借用组件嵌套，容易让读者误判 URL 层级，应只在有明确理由时使用。

布局负责共同导航、section 标题、面包屑或 outlet，不应偷偷持有每个页面的数据。若子页面需要同一 repository，可在布局/组合根 provide；若需要全局客户端状态，留给 Pinia。嵌套路由不是把所有页面包进一个巨大组件的理由。

## 6. 声明式与程序化导航

用户可点击的普通导航优先 `<RouterLink>`。它最终渲染可访问的 anchor，支持复制链接、打开新标签、浏览器语义和 active 状态。按钮完成操作后跳转、条件流程或命令式协调可用 `useRouter()` + `router.push()`。

推荐使用命名 location：

```ts
await router.push({
  name: 'work-order-detail',
  params: { workOrderId },
  query: { from: 'list' },
})
```

Router 负责路径构造与参数编码。手写 `` `/work-orders/${id}` `` 容易遗漏编码、base 或路径重构。不要同时传 `path` 与 `params` 并期待 params 生效；按官方说明，使用 `path` 时 params 会被忽略，应使用命名路由或自行在 path 中编码。

`push` 在 history 栈增加记录，用户可 Back 返回；`replace` 替换当前记录，常用于规范化无意义 URL 或登录完成后不希望返回中间页的场景。不能为了“避免重复”到处用 replace，否则用户返回行为会失真。路由 API 返回 Promise，必须根据是否需要等待结果选择 `await`，尤其在关闭菜单、显示成功提示或记录 trace 时。

## 7. 深链接是首要场景，不是附加功能

SPA 常见假绿是：从首页点击能到详情，但直接打开 `/work-orders/WO-3001` 白屏。测试先 `router.push(deepLink)`、等待 `isReady()`，再挂载应用，模拟首个 location。要断言：

1. `currentRoute.name` 正确；
2. `matched` 含布局和详情两条记录；
3. DOM 同时有布局与详情；
4. param/query 归一化到页面输入；
5. 未认证时重定向保留 return URL。

Memory history 能稳定测试 Router 逻辑，却不会验证生产服务器。`createWebHistory()` 下，用户刷新深层 URL 会向服务器请求该 path；服务器必须对非静态资源回退到 SPA `index.html`，否则 Router 还未启动就得到 404。该配置属于部署章节，本章明确标为未验证。

## 8. 当前页状态、键盘与路由后焦点

可达不是只有 URL。主要导航使用语义 `<nav aria-label="主要导航">` 和 RouterLink。RouterLink 会对 active link 添加 class，并在精确 active 时设置 `aria-current="page"`；视觉上也要用颜色之外的下划线/边框，让当前页可辨识。不要把 `<div @click>` 当链接，也不要移除 focus outline 而无替代。

导航多时提供 skip link，允许键盘用户跳到 `<main>`。SPA 路由切换不会像完整页面加载那样自动把屏幕阅读器/键盘焦点带到新内容。本章示例 watch `route.fullPath`，等待 DOM 更新后聚焦带 `tabindex="-1"` 的页面标题。这个副作用要测试，也要注意产品实际焦点策略：弹窗关闭、表单错误与返回列表可能需要不同目标。

UI/UX 验收至少包括：当前页视觉/`aria-current`、可见 focus ring、合理 Tab 顺序、skip link、标题层级和 44px 左右的点击目标。课程内只在 happy-dom 验证 DOM/focus 证据，没有声称完成真实 screen reader 或多浏览器测试。

## 9. 导航守卫：返回值就是控制流

全局 `beforeEach`、路由 `beforeEnter`、组件内守卫用于取消或重定向。现代 API 直接返回：

- `true`/`undefined`：继续；
- `false`：取消，URL/组件树恢复到 from；
- route location：发起重定向；
- throw：进入错误处理。

不要混用旧式 `next()` 与返回值；复杂分支容易调用两次或漏调用。守卫应快速、可预测，避免把所有页面数据加载塞进一个全局守卫。

本章两条策略：

```ts
router.beforeEach((to, from) => {
  if (from.name === 'work-order-detail' && session.hasUnsavedDraft && to.fullPath !== from.fullPath) {
    return false
  }
  if (to.meta.requiresSession && !session.authenticated) {
    return { name: 'sign-in', query: { redirect: to.fullPath } }
  }
  return true
})
```

顺序是合同。草稿取消只在离开详情时触发；认证重定向只对 `requiresSession` 记录触发。Sign-in 本身不带该 meta，因而不会重定向自己。若写成“只要未认证就返回 sign-in”，进入 sign-in 时再次返回同一位置，形成循环或重复导航。

### 9.1 route meta 的合并语义

`route.meta` 是匹配记录 meta 的非递归合并，适合 `requiresSession`、layout hint 等横切元数据。它不是秘密，也不是权限声明的唯一来源；攻击者能改前端包或直接调用 API。服务端必须独立授权。

### 9.2 beforeEnter 与参数变化

官方说明，记录级 `beforeEnter` 通常只在进入记录时触发；从同一动态记录 `/users/2` 到 `/users/3` 的 params/query 变化不会重新触发它。若需要响应参数变化，应 watch 具体 param 或使用 `onBeforeRouteUpdate`，不能假设所有守卫都会重跑。

## 10. 导航失败是 Promise 的业务结果

`await router.push()` 成功（包含重定向完成）通常得到 falsy；取消、重复等情况会得到 Navigation Failure。用 `isNavigationFailure` 和 `NavigationFailureType` 判断，而不是解析错误字符串：

```ts
const failure = await router.push({ name: 'work-order-list' })

if (isNavigationFailure(failure, NavigationFailureType.aborted)) {
  // 保持编辑 UI；不要关闭抽屉或显示“已离开”
}
```

取消不是异常崩溃，而是导航流程的显式结果。UI 若不 await 就立即关闭详情面板，会出现 URL/组件仍在详情、面板却消失的分叉。`afterEach(to, from, failure)` 适合记录 trace/analytics；它不能改变已决定的结果。日志至少保存 from/to、结果类型和必要 correlation，不记录 token 或敏感 query。

重定向与取消不同。未认证详情导航重定向到 sign-in，最终 currentRoute 是 sign-in；原始目的地放在编码 query 中。登录后只能接受应用允许的本地 return URL，避免开放重定向风险；本章只展示保存，不实现完整安全校验。

## 11. 动态参数与组件实例复用

从 `/work-orders/WO-3001` 到 `/work-orders/WO-3002` 匹配同一个详情记录，Vue Router 会复用组件实例以提高效率。`setup()`、`onMounted()` 不会因为 param 改变自动重跑。以下快照会陈旧：

```ts
const route = useRoute()
const firstId = String(route.params.workOrderId)
void loadWorkOrder(firstId)
```

修复可以 watch 特定 param：

```ts
watch(
  () => route.params.workOrderId,
  nextId => void loadWorkOrder(String(nextId)),
  { immediate: true },
)
```

或者用路由 `props` 映射，然后 watch `props.workOrderId`。`immediate` 同时覆盖直接深链接的首轮加载。若新加载有异步请求，还要沿用上一章的取消/generation 规则；本章示例只用同步 ID 证据，真实 API 未验证。

`onBeforeRouteUpdate` 适合参数变化时还需取消导航的场景。不要一律给 RouterView 加 `:key="$route.fullPath"` 强制重建；它会丢本地状态、重复昂贵初始化、掩盖生命周期设计。只有明确需要全量重建时才用 key，并记录影响。

## 12. 路由组件也是组件合同

路由记录决定谁创建页面；页面仍应遵守 Props/emit/Slot 规则。路由 props 把 URL 映射成普通输入，使页面能独立挂载；布局 outlet 是组合点，不应让子页面直接修改父状态。错误/空/加载 UI 仍是页面责任，Router 不替你管理数据请求。

Route object 是 reactive，但官方建议只 watch 预计变化的属性：

```ts
watch(() => route.params.workOrderId, load)
```

watch 整个 route 会对不相关 query/hash 变化重复加载，难以解释。反之，若数据也依赖 `status` query，就把它加入 source tuple并定义顺序/取消。

页面切换时的 effect cleanup 取决于复用：记录变化导致组件卸载，组件 scope cleanup 运行；只有 params 改变且实例复用时，不会卸载，所以 watcher 每轮 cleanup 更关键。路由生命周期和 Composable 生命周期必须共同设计。

## 13. 测试：memory history 的确定性证据

每个测试创建独立 Router，避免 currentRoute/guard 在用例间污染：

```ts
const router = createFactoryCareRouter(
  createMemoryHistory(),
  session,
  trace,
)
await router.push('/work-orders/WO-3001')
await router.isReady()
const wrapper = mount(App, { global: { plugins: [router] } })
```

关键矩阵：

1. 已认证直接详情：URL、name、matched 长度、布局和详情 ID；
2. query：真实状态保留，非法文本 `UNKNOWN` 映射 `ALL`；
3. named params：包含空格/斜线的 ID 正确编码；
4. 参数复用：同一详情 load count 从 1 到 2；
5. 取消：failure=aborted、URL 与 DOM 不变；
6. 重定向：sign-in、redirect query、trace 次数有限；
7. catch-all：未知深链到 NotFound；
8. active link：class 与 `aria-current=page`；
9. focus：切换后 activeElement 是新标题。

不要只对 routes 数组做快照。快照可发现配置变化，却不能证明 guard 返回结果、组件复用或 focus。也不要只点击 RouterLink；程序化导航、直接深链、取消和无效 query 都需要专门输入。

## 14. 三类故障的第一可信证据

### 14.1 参数复用未刷新

症状：URL 已是 WO-4002，页面仍显示 WO-4001。第一可信证据是 `currentRoute.params.workOrderId === 'WO-4002'`，但页面 `loaded-id === 'WO-4001'`，且 setup 只快照一次。根因不是 Router 没导航，而是组件生命周期假设错误。修复 watch param/prop，重跑同一实例导航。残余风险是实际请求的竞态与 abort 尚未集成。

### 14.2 守卫无限重定向

症状：控制台 repeated/infinite redirect，导航不 ready。第一可信证据是守卫以 sign-in 为 `to` 且仍返回 `{ name: 'sign-in' }`。修复：只保护带 meta 的目标或显式排除公共路由，并保证 sign-in 是终止状态。重跑未认证深链，trace 次数应有限。残余风险包括多个守卫组合后的新循环，需要整体矩阵。

### 14.3 客户端守卫误当授权

症状可能并不在 UI：通过直接请求 API，即使路由进不去仍拿到敏感 maintenance report。第一可信证据是无 credential 的服务端调用返回数据。修复必须在服务端认证/授权，而不是加更多前端 if。重跑 API 负例应得到 401/403/404（具体策略另章定义）。本章 lab 的 `faultyServerRead` 故意泄漏，只为证明边界，不是生产实现。

报告模板：

```text
场景：/work-orders/WO-4001 → /work-orders/WO-4002
期望：URL=WO-4002，loaded-id=WO-4002，load-count=2
实际：URL=WO-4002，loaded-id=WO-4001
第一可信证据：Router currentRoute 已更新，页面快照未更新
根因：setup 只读取一次 param，组件被复用
修复：watch props.workOrderId，immediate=true
重跑：同一路由矩阵通过
残余风险：真实 API 旧请求取消未验证
```

## 15. history、返回与恢复语义

`createWebHistory` 产生干净 URL，需要服务器 fallback；`createWebHashHistory` 将路径放在 `#` 后，服务器配置简单但 URL 形态不同；`createMemoryHistory` 不与浏览器地址栏交互，适合测试和 SSR 入口。历史实现是应用组合根决定，不应在页面组件里创建。

Back 行为取决于 `push`/`replace`。从列表点详情应 push，让 Back 回列表；修正无效 query 可 replace，避免历史里留下两份等价状态。列表筛选进 query 后，Back 能恢复 URL，但页面是否恢复滚动、选中项和服务器数据仍需额外策略。不要把“URL 恢复”宣称成“全部状态恢复”。

Vue Router 提供 `scrollBehavior` 和 `savedPosition`，本章不实现真实浏览器滚动，因为 memory history/happy-dom 不能提供可信 layout/scroll 证据。后续应在浏览器 E2E 测试刷新、Back/Forward、滚动、hash anchor 与焦点互不冲突。

## 16. 导航与安全的双重判据

以“查看工单详情”为例：

```text
客户端 Router guard
  └─ 是否让用户进入详情页面？（体验/可达性）

服务端 API authorization
  └─ 当前身份、租户、角色、资源关系是否允许返回该工单？（安全）
```

两者都要有测试。客户端测试未认证时重定向，服务端测试无凭证/跨租户时拒绝。服务端可返回 404 隐藏资源存在性或 403 表达禁止，取决于安全策略；客户端不能自行决定。route meta 也不能作为 API 证据，构建产物对用户可见。

Return URL 同样要验证：只允许站内相对路径或命名目标，拒绝 `https://evil.example`、`//evil.example` 和控制字符。示例仅保存 `to.fullPath`，它来自 Router 内部当前目标；真实登录回跳还要在消费 query 时校验。

## 17. 独立构建步骤与证据包

从空目录完成：

1. 固定 Node、pnpm、Vue、Vue Router、Vite、TypeScript、Vitest 版本；
2. 写路由矩阵，再写 records、layout、pages；
3. 用 named RouterLink/`push` 构造 params/query；
4. 为详情使用 route props，并证明 param 复用刷新；
5. 写认证重定向与草稿取消，保存 navigation trace；
6. 添加 catch-all、active current page、skip link/focus；
7. 逐个注入三类 fault，保存失败、修复、重跑；
8. 构建并列出未验证的浏览器/服务器/SSR 条件。

命令：

```bash
cd examples/encyclopedia/ch.vue.router-navigation && ./verify.sh
cd labs/encyclopedia/ch.vue.router-navigation && ./verify.sh
cd exercises/encyclopedia/ch.vue.router-navigation && ./verify.sh   # 初始应红
```

示例/实验 verifier 以锁文件离线安装，运行 Vitest 与 Vite build，退出时清理 node_modules/dist。公开练习用静态 oracle 聚焦参数响应；私有目录只证明存在一个通过样例，不是学习者完成证据。

## 18. 120 秒复述模板

> 路由记录把 URL 映射到组件树：path param 表示资源身份，query 表示可分享筛选；children 与嵌套 RouterView 表达共享布局。普通点击用 RouterLink，流程跳转用 named router.push，让 Router 处理编码和 history。守卫通过返回 true、false 或 location 继续、取消或重定向，push 的 Promise 用 Navigation Failure 判断。动态 param 变化会复用组件，所以 watch 具体 param/route prop 或用更新守卫，不依赖 mounted 重跑。证据必须同时检查 URL、matched/DOM 和导航结果，包含直接深链、参数变化、取消与重定向。客户端守卫只控制可达性，服务端必须独立授权。

如果只能说“Router 用来切页面”，没有说明 history、组件复用、失败结果与安全反例，不算通过。

## 19. 自检问题

1. 为什么工单 ID 应是 param，而状态筛选通常是 query？
2. 使用 route props 比页面直接读取整个 route 有什么可测试性优势？
3. 子 path 为空与以 `/` 开头分别如何匹配？
4. 为什么 named route 能减少编码和重构错误？
5. push 与 replace 对 Back 行为有什么影响？
6. 守卫返回 false 后应观察 URL、组件树和 Promise 的哪些证据？
7. 为什么 sign-in 路由也被同一认证守卫保护会产生循环？
8. 从同一详情记录的 ID 1 到 ID 2，为什么 mounted 不重跑？
9. 为什么 `<RouterView :key="$route.fullPath">` 不是默认修复？
10. `aria-current`、可见 focus 和标题聚焦分别解决什么问题？
11. memory history 通过后，Web History 生产服务器仍需验证什么？
12. 为什么任何客户端守卫都不能替代 API 授权？

## 20. 有意非目标与兼容性说明

本章没有实现 Nuxt/file-based routing、typed routes generator、data loaders、Pinia、KeepAlive、过渡动画、scrollBehavior、真实登录、API 授权、生产 history fallback、SSR/hydration 或浏览器 E2E。没有保留 Vue Router 3 的 `new VueRouter`、`mode`、裸 `*` catch-all 或 `next()` 风格兼容层；长期维护性优先，旧项目迁移应单独评估影响和回滚。

Vue Router 5 是官方文档中的过渡版本；官方 v4→v5 指南说明未使用 file-based routing 的 v4 项目通常可无代码修改升级。本章因此继续显式 routes，不引入 v5 的文件路由插件。固定 `5.1.0` 只是本次可复现基线，不代表未来 5.x/6 已验证。真实 Chrome/Safari/Firefox、Back/Forward、刷新、scroll、screen reader、服务器 fallback、SSR 和服务端授权全部明确未验证。

## 21. 官方资料

- [Vue Router：Getting Started](https://router.vuejs.org/guide/)
- [Dynamic Route Matching with Params](https://router.vuejs.org/guide/essentials/dynamic-matching.html)
- [Nested Routes](https://router.vuejs.org/guide/essentials/nested-routes.html)
- [Programmatic Navigation](https://router.vuejs.org/guide/essentials/navigation.html)
- [Passing Props to Route Components](https://router.vuejs.org/guide/essentials/passing-props.html)
- [Active Links](https://router.vuejs.org/guide/essentials/active-links.html)
- [Navigation Guards](https://router.vuejs.org/guide/advanced/navigation-guards.html)
- [Vue Router and the Composition API](https://router.vuejs.org/guide/advanced/composition-api.html)
- [Navigation Failures](https://router.vuejs.org/guide/advanced/navigation-failures.html)
- [Route Meta Fields](https://router.vuejs.org/guide/advanced/meta.html)
- [Different History modes](https://router.vuejs.org/guide/essentials/history-mode.html)
- [Migrating to Vue Router 5](https://router.vuejs.org/guide/migration/v4-to-v5)
- [Vue Router Installation](https://router.vuejs.org/installation)
