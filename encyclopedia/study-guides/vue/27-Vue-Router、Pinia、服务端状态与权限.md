# Vue：Router、Pinia、服务端状态与权限

## 1. 路由把 URL 映射到页面状态

```text
/work-orders            → 工单列表
/work-orders/WO-42      → 工单详情
/work-orders/WO-42/edit → 编辑页
```

URL 不只是显示地址，它是可复制、刷新、前进后退和收藏的应用状态。筛选、分页、选中资源等适合放 URL 的信息应有稳定格式。

Vue Router 监听导航并渲染匹配组件，不需要每次整页刷新。

## 2. Router 配置声明路径、名称和组件

```ts
const routes = [
  {
    path: '/work-orders',
    name: 'work-order-list',
    component: () => import('./pages/WorkOrderListPage.vue'),
  },
  {
    path: '/work-orders/:id',
    name: 'work-order-detail',
    component: () => import('./pages/WorkOrderDetailPage.vue'),
  },
]
```

命名路由让调用者按语义导航，避免到处拼路径字符串。动态 import 可按页面拆包。

路径参数仍是外部字符串，必须验证格式和权限，不能因为路由匹配就当作可信 WorkOrderId。

## 3. RouterLink 保留链接语义

```vue
<RouterLink :to="{ name: 'work-order-detail', params: { id: order.id } }">
  {{ order.title }}
</RouterLink>
```

它生成可访问链接，支持新窗口、复制地址和浏览历史。不要把普通页面导航做成 div click + `router.push`。

按钮触发完成动作后程序导航才用 `router.push` / `replace`。`replace` 不新增历史记录，适合登录回跳等不希望用户返回中间页的场景。

## 4. Route Params 和 Query 有不同语义

```text
/work-orders/:id      → 标识主要资源
?status=OPEN&page=2   → 筛选、排序、分页等可选视图状态
```

读取：

```ts
const route = useRoute()
const id = computed(() => String(route.params.id))
```

route 是响应式对象。复用同一页面组件从一个 id 导航到另一个 id 时，组件不一定重新挂载，应 watch 具体参数或让数据层使用响应 key。

## 5. 嵌套路由表达页面布局层级

```text
WorkOrderLayout
  ├── OverviewPage
  ├── HistoryPage
  └── AttachmentsPage
```

父组件放侧栏、标题和子级 `RouterView`。路径层次和组件层次不必完全复制数据库结构，但应与用户导航心智一致。

过深嵌套会让数据加载和权限难追踪；共享外观也可用 layout component，不必全部变嵌套路由。

## 6. 路由元数据保存页面级声明

```ts
{
  path: '/admin/users',
  component: UserAdminPage,
  meta: {
    requiresAuth: true,
    requiredPermission: 'USER_MANAGE',
    title: '用户管理',
  },
}
```

meta 适合导航守卫、标题和布局等声明。它运行在前端，用户可修改打包代码或绕过页面，不能成为服务端授权。

类型化 RouteMeta 可减少拼错字段，但仍是 UI 合同。

## 7. 导航守卫决定重定向、取消或继续

```ts
router.beforeEach(async to => {
  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
})
```

当前官方 Router 推荐通过返回值表达结果；旧式 `next` 回调更容易多次调用或漏调用。守卫可异步，在完成前导航处于 pending。

全局、单路由和组件内守卫各有范围。只放真正导航级规则，不把所有页面数据请求堆进一个巨型 beforeEach。

## 8. 登录回跳地址必须限制为本应用安全路径

如果 `redirect` query 可是任意 URL：

```text
/login?redirect=https://evil.example
```

登录后直接跳过去会造成开放重定向。应只允许已知内部路径/命名路由，拒绝协议、外部主机和危险格式。

身份平台 redirect URI 还有更严格的 OAuth 注册边界，不能与普通页面 return path 混为一谈。

## 9. 守卫要避免重定向循环

登录页自身不能再次要求登录；无权限页也不能被同一规则不断送回。

```text
访问 /admin
  → 未登录 → /login
/login 若也 requiresAuth
  → 再回 /login → 循环
```

每个返回分支要保证目标状态不同。身份初始化失败、Token 刷新失败和后端离线应有独立页面/错误，不要全部重定向登录。

## 10. 页面焦点和滚动属于导航体验

Vue Router 可配置 scroll behavior，恢复前进后退位置或新页面回顶部。导航后还应：

- 更新 document title；
- 把焦点移到主标题/内容入口；
- 用 live region 必要时提示页面变化；
- 保留符合预期的列表筛选与滚动。

SPA 改 DOM 不会像传统页面加载一样自动向屏幕阅读器声明新页面。

## 11. Pinia 管理跨组件共享的客户端状态

适合 Store 的状态：

- 当前认证用户的 UI 表示；
- 全局偏好和主题；
- 多页面共享的编辑草稿；
- 当前租户选择（必须由服务端再次验证）；
- 复杂客户端工作流。

不必进入 Store：

- 单个输入框是否展开；
- 只属于一个组件的临时状态；
- 能从 props 计算的值；
- 所有服务端列表数据不加区别地永久保存。

## 12. Store 有 state、getters 和 actions

Setup Store 示例：

```ts
export const useAuthStore = defineStore('auth', () => {
  const user = ref<AuthUser | null>(null)
  const isAuthenticated = computed(() => user.value !== null)

  async function loadCurrentUser() {
    user.value = await authApi.me()
  }

  function clear() {
    user.value = null
  }

  return { user, isAuthenticated, loadCurrentUser, clear }
})
```

- state/ref：事实状态；
- getter/computed：派生值；
- action/function：有名称的修改与副作用。

## 13. Store 状态所有权要有一个入口

技术上 Pinia state 可直接修改，但关键业务状态通过 action 更容易：

- 集中不变量；
- 管理 loading/error；
- 记录副作用；
- 做并发和取消；
- 测试行为。

不要让十个组件各自写 `auth.user = ...`。简单 UI 状态可直接改，边界按风险决定。

## 14. 解构 Store 时保留响应性

直接解构 reactive store 属性可能丢响应性：

```ts
const store = useAuthStore()
const { user } = storeToRefs(store)
const { loadCurrentUser } = store
```

state/getters 使用 `storeToRefs`；actions 是普通绑定，可直接解构。也可以始终用 `store.user` 保持清楚来源。

## 15. Store 不是后端数据库的永久镜像

服务器状态有：

- 缓存时间和新鲜度；
- loading/error；
- 分页与筛选 key；
- 后台重新获取；
- 乐观更新与回滚；
- 多组件去重；
- 取消和竞态。

把每个 API 结果塞 Pinia 数组会自行重造一套不完整的数据获取库。小应用可手工管理，但要明确缓存合同；复杂场景可使用适合 Vue 的服务端状态库。

## 16. 客户端状态和服务端状态的区别

```text
客户端状态：侧栏开关、未提交草稿、主题
服务端状态：工单列表、当前状态、权限、设备数据
```

服务端状态由服务器拥有，前端保存的是有时效的副本。用户 A 修改工单后，用户 B 的页面不一定立即知道，需要失效、刷新、SSE 或其他同步机制。

这一区分决定谁是事实来源和错误如何恢复。

## 17. 服务端数据用 Query Key 表达身份

```text
['work-orders', { tenantId, status, page }]
['work-order', workOrderId]
```

同一 key 代表同一份缓存语义。筛选条件变化应产生不同 key；缺租户维度可能把 A 的缓存展示给 B。

Key 只能包含可稳定序列化的查询身份，不要每次创建无法比较的大对象或包含 Token。

## 18. 加载状态不只有一个 boolean

需要区分：

- 初次无数据加载；
- 已有数据后台刷新；
- 用户提交 mutation；
- 某一行局部更新；
- 重试等待；
- 离线状态。

已有列表刷新时不必整页变空白 spinner；可保留旧数据并标记正在更新。状态模型应对应用户能采取的动作。

## 19. 错误要能恢复

```text
初次加载失败 → 错误页 + 重试
后台刷新失败 → 保留旧数据 + 非阻塞提示
提交校验失败 → 字段错误
409 冲突 → 展示最新版本并让用户重新决定
401 → 重新认证
403 → 无权限状态
```

不要在组件 `catch` 后只 console.log。也不要每个子组件同时弹十个 Toast；错误显示应由拥有该操作上下文的层决定。

## 20. 请求竞态要明确“谁拥有最新结果”

路由从 WO-1 快速变 WO-2，旧请求可能后返回。可：

- 使用 AbortSignal 取消；
- query key 让不同结果分开；
- 使用 request sequence；
- 组件卸载后不提交旧结果。

取消只是减少工作，最终状态写入仍要验证请求是否属于当前 key。

## 21. Mutation 成功后更新或失效相关缓存

关闭工单后：

- 详情状态变化；
- OPEN 列表应移除；
- CLOSED 列表可能新增；
- 统计数字变化。

可以：

- 直接按响应精确更新少量缓存；
- 使相关 query 失效并重新获取；
- 两者组合。

服务端响应应返回已提交后的规范对象/version，前端不要只凭请求草稿猜最终值。

## 22. 乐观更新先改 UI，失败时回滚

```text
保存旧缓存
  → 立即显示新状态
  → 发请求
  ├── 成功：用服务端结果确认
  └── 失败：恢复旧缓存并提示
```

适合成功率高、可安全回滚、反馈需要即时的操作。删除、支付、复杂状态转换和跨列表更新可能不适合。

并发 mutation 让回滚更复杂，必须按 mutation ID/version 防止旧失败覆盖后来成功。

## 23. 认证初始化是一个明确状态机

```ts
type AuthState =
  | { status: 'unknown' }
  | { status: 'authenticated'; user: AuthUser }
  | { status: 'anonymous' }
  | { status: 'error'; error: SafeError }
```

应用启动时不是立刻“未登录”，而是可能还没查询 Session。若守卫把 unknown 当 anonymous，会闪烁登录页或产生循环。

先初始化身份，再决定受保护导航；初始化网络失败也不等同密码失效。

## 24. 浏览器认证状态按后端模式保存

Session/BFF 模式：浏览器保存 HttpOnly Session Cookie，前端通过 `/me` 取得用户表示，JavaScript 不读取凭据。

Token SPA 模式：需要处理 PKCE、短期 Token、刷新和 XSS 风险。把长期 Refresh Token 放 localStorage 是高风险选择。

前端 Store 中的 user/permissions 是 UI 副本，不是权威授权。刷新页面后能恢复它，也不能让服务端因此相信。

## 25. 路由保护用于体验，不用于服务器安全

```text
路由守卫：不让正常用户进入看不懂的页面
权限 UI：隐藏/禁用不可用操作并解释原因
服务器授权：真正拒绝未授权请求
```

攻击者可直接调用 API。每个写操作、对象和租户边界必须在服务端校验。

权限从服务端可信身份取得，不能让 URL query 或 localStorage 自报 role。

## 26. 权限 UI 应表达能力而不是散落角色判断

```ts
const canAssign = computed(() =>
  auth.hasPermission('WORK_ORDER_ASSIGN') &&
  order.value?.status === 'OPEN',
)
```

角色可映射权限，但组件最好依赖 `can('WORK_ORDER_ASSIGN')` 这类稳定能力，再结合资源状态。

隐藏和禁用有不同体验：完全不适用可隐藏；用户需要理解为何不可做时可禁用并说明。无论哪种，服务端仍执行相同规则。

## 27. 403 后要刷新权限或资源，而不是只弹 Toast

可能原因：

- 权限刚被撤销；
- 工单已被他人修改；
- 用户切换租户；
- Session 身份变化；
- 前端旧缓存错误。

前端应根据错误码失效相关 user/resource，显示稳定无权限或冲突界面。不要自动无限重试 403。

## 28. 多租户切换必须清理租户化缓存

若允许一个用户切换租户：

1. 由服务端确认可用租户；
2. 切换请求建立新的可信上下文；
3. 清除/隔离旧租户的 query cache、Store、草稿和页面；
4. 重新加载用户权限；
5. 导航到安全默认页；
6. 服务端每次仍按身份校验 tenant。

仅改 Pinia `tenantId` 会造成严重数据混用。

## 29. 持久化 Store 只保存必要、可失效的客户端数据

localStorage 不受 HttpOnly 保护，页面脚本和 XSS 可读取。不要保存密码、Session ID、Refresh Token 或完整敏感工单。

主题、非敏感筛选和草稿可考虑持久化，但要有：

- schema version；
- 过期和迁移；
- 用户/租户命名空间；
- 登出清理；
- 解析失败回退。

存储事件还可能让多个标签页同步，需要防止循环更新。

## 30. Router 与 Store 的依赖方向要避免循环

常见循环：router guard import auth store，auth store 又 import router 做跳转。可让：

- Store 只管理认证行为和状态；
- 页面/守卫根据结果导航；
- API 层把 401 转为事件/错误；
- 应用组合根注入依赖。

在 action 深处任意 `router.push` 会隐藏流程，除非导航本身就是该应用用例的明确责任。

## 31. 组件测试验证用户可见合同

Vue Test Utils + Vitest 常见结构：

```text
挂载组件
  → 用 props/store/router 提供输入
  → 通过可访问角色/文本找到控件
  → 触发用户动作
  → 等待 DOM/Promise 更新
  → 断言 emit、显示结果或 API 合同
```

不要断言组件内部 ref 名称和每个实现细节，否则重构就全坏。关键权限组件必须有允许和拒绝场景。

## 32. Mock 应替换边界，不要复制内部实现

可 Mock：HTTP API、时间、随机数、外部 SDK。少量集成测试使用真实 Router/Pinia 往往比手写假对象更可靠。

如果 Mock 返回永远成功的完美数据，测试不会发现 loading/error/竞态。提供最小、显式、类型正确的成功和失败场景。

## 33. 异步断言要等待真正的更新原因

Vue DOM 更新可能需要 `nextTick`，Promise/HTTP stub 可能需等待其完成。应等待用户可观察结果或明确 Promise，不靠固定 sleep。

```text
触发点击
  → 等待按钮显示“已保存”或 API Promise 完成
  → 断言
```

无条件 `setTimeout(100)` 会慢且不稳定。

## 34. 端到端测试留给关键跨层流程

适合：

- 登录和回跳；
- 权限/租户拒绝；
- 创建到详情导航；
- 409 冲突恢复；
- 刷新后状态恢复。

端到端数量少但覆盖真实浏览器、Router、API 和后端。纯显示映射不必全放 E2E；使用分层测试保持速度和定位能力。

## 35. 这篇的整体地图

```text
URL → Vue Router → 页面和布局
  → 守卫改善登录/权限导航体验

客户端共享状态 → Pinia
服务端事实副本 → query key + loading/error/cache/invalidation
  → mutation 后确认、失效或回滚

认证 Store 表示身份状态
  → 权限 UI 按能力呈现
  → 服务端始终执行真正授权与租户隔离
```

必须掌握：URL 是可分享状态；路由参数是不可信字符串；Pinia 不应无差别镜像后端；客户端与服务端状态所有权不同；路由保护不是安全授权；租户切换必须隔离缓存；异步测试等待事实而非固定时间。

高级 Router matcher、Pinia 插件和具体 server-state 库 API 属于“需要时查询”。
