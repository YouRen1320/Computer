# Nuxt：渲染、水合、数据获取与部署

## 1. Nuxt 在 Vue 之上提供完整应用运行模型

Vue 负责组件和响应式 UI；Nuxt 进一步提供：

- 文件式路由和布局；
- 服务端渲染、客户端渲染和预渲染；
- 服务端 API/中间件能力；
- SSR 安全的数据获取；
- 自动导入、资源和配置约定；
- 构建到 Node、Serverless、Edge 或静态托管等目标。

学习 Nuxt 的重点不是记目录名，而是知道同一段代码可能在哪个环境、哪个时间执行。

## 2. 一次初始访问可能先在服务器运行 Vue

Universal Rendering（通用/同构渲染）概念流程：

```text
浏览器请求 URL
  → Nuxt 服务器匹配页面
  → 在服务器运行页面 setup 和数据获取
  → 输出已有内容的 HTML + 序列化 payload
  → 浏览器显示 HTML
  → 下载 JavaScript
  → Hydration 绑定交互
```

客户端后续路由跳转通常不再整页刷新，而像 SPA 一样取数据和更新组件。

## 3. CSR、SSR、SSG 和混合渲染解决不同目标

| 模式 | HTML 何时产生 | 适合 |
| --- | --- | --- |
| CSR | 浏览器运行 JS 后 | 内部后台、强交互、SEO 不重要 |
| SSR | 每次或缓存后的服务请求 | 动态公开内容、首屏与 SEO |
| SSG/Prerender | 构建时预先生成 | 更新较少的公开页面 |
| Hybrid | 按路由选择策略 | 同站点混合公开页与后台 |

SSR 增加服务器运行和缓存成本；SSG 内容更新需重新生成或再验证；CSR 首屏可能只有空壳。按页面需求选择，不是 SSR 永远更高级。

## 4. 水合让服务器 HTML 变成可交互 Vue 页面

Hydration（水合）：浏览器端 Vue 使用相同组件和状态，接管服务器已经生成的 DOM，绑定事件和响应式关系。

```text
服务端 HTML：<button>0</button>
客户端第一次期望：<button>0</button>
  → 匹配，绑定 click
```

如果两边第一次渲染结构不同，会出现 hydration mismatch。Vue 可能修复 DOM，但会增加成本并可能造成闪烁、状态丢失或错误交互。

## 5. 水合不匹配来自服务端和客户端初始结果不一致

常见原因：

- 直接渲染 `Date.now()`、随机数；
- 按浏览器窗口宽度在 setup 选择不同 DOM；
- 服务端和客户端使用不同语言/时区；
- 无效 HTML 被浏览器纠正；
- 服务端请求和客户端又请求出不同数据；
- 在模块单例中共享用户状态；
- 第三方库在导入时立即读 window/document。

解决方向是让初始输入一致，而不是把 warning 全部隐藏。

## 6. 浏览器专用行为放在客户端生命周期

```ts
onMounted(() => {
  width.value = window.innerWidth
})
```

初始服务端和客户端可先渲染同一个安全占位，挂载后再增强。仅浏览器组件可使用 `ClientOnly`，并提供合理 fallback，避免首屏大片空白和布局跳动。

动态导入浏览器专用库也应在客户端边界发生。`process.client` 等具体兼容写法随版本变化，优先用当前 Nuxt 推荐 API。

## 7. 文件式路由把 pages 目录映射为 URL

概念：

```text
app/pages/index.vue              → /
app/pages/work-orders/index.vue  → /work-orders
app/pages/work-orders/[id].vue   → /work-orders/:id
```

Nuxt 4 的默认应用目录组织与旧版教程可能不同，应以当前项目和官方升级指南为准。

动态参数仍需验证。文件存在只建立路由，不自动建立权限或数据加载。

## 8. Layout 提供跨页面稳定外壳

```text
default layout：导航、主内容、用户菜单
auth layout：登录/恢复页
```

页面选择 layout，Nuxt 在其中渲染页面内容。共享外壳不应持有所有页面业务数据；导航和身份摘要适合，具体工单状态由页面/模块拥有。

布局切换要管理标题、焦点、滚动和 pending 状态。

## 9. Middleware 在导航边界执行页面规则

Route middleware 可检查认证 UI 状态、租户选择或页面参数并重定向。

```text
进入受保护页面
  → 初始化/读取可信认证表示
  → 未登录则导航登录
  → 无页面能力则导航无权限
```

这仍是前端导航保护。服务器 API 必须独立认证授权；不能因为 middleware 运行过就信任客户端请求。

Server middleware 和 route middleware 运行位置/职责不同，具体 API 需按当前文档查询。

## 10. useFetch 用于 SSR 安全的常见请求

```vue
<script setup lang="ts">
const route = useRoute()

const { data, status, error, refresh } = await useFetch(
  () => `/api/work-orders/${route.params.id}`,
)
</script>
```

服务器首次渲染时取得数据，并把结果放入 Nuxt payload 给客户端，水合时避免同一请求再发一次。

它返回 ref 形式的 data/status/error 和刷新能力。页面仍要呈现 loading、error、not found 和权限状态。

## 11. useAsyncData 包装任意异步数据生产函数

```ts
const { data, status, error } = await useAsyncData(
  () => `work-order:${route.params.id}`,
  () => workOrderRepository.findById(String(route.params.id)),
)
```

适合组合多个请求或非 `$fetch` 数据源。handler 应返回可序列化、确定的结果，避免在其中执行可能重复的副作用。

对提交、删除等用户动作使用 `$fetch` 或服务 action，而不是把 mutation 塞进 useAsyncData 缓存流程。

## 12. $fetch 适合直接网络请求和用户动作

```ts
async function submit(input: CreateWorkOrderInput) {
  return await $fetch('/api/work-orders', {
    method: 'POST',
    body: input,
  })
}
```

在组件 setup 的初始渲染中直接 `$fetch`，服务端和客户端水合可能各调用一次；`useFetch/useAsyncData` 解决初始数据传递和去重。

在点击提交等仅客户端交互中 `$fetch` 很合适，因为不存在同一 setup 两端执行问题。

## 13. Key 定义同一份 AsyncData 的身份

同 key 的数据调用可能共享 data/error/status。Key 应包含查询身份：

```text
work-order:WO-42
work-orders:tenant-A:status=OPEN:page=2
```

不能让两个不同查询误用同 key，也不能让同 key 配置互相冲突。Nuxt 4 对同 key 共享 ref 和清理等行为有明确规则，应以当前官方数据获取文档为准。

租户和用户敏感数据还要防止跨 SSR 请求共享。

## 14. Reactive Key 或参数变化可触发重新获取

```ts
const id = computed(() => String(route.params.id))

const { data } = await useFetch(
  () => `/api/work-orders/${id.value}`,
)
```

URL getter/响应参数变化时，Nuxt 可重新获取。若先把 URL 计算成固定字符串，再只 watch id，可能仍请求旧 URL。

请求变化时要处理竞态和旧数据展示。是否清空旧值、保留 stale 数据或显示 pending 是体验决定。

## 15. await 与 lazy 决定导航等待体验

默认 await 数据获取时，客户端导航可以等数据就绪后进入页面；用户停留在旧页，可配导航进度。

lazy/非阻塞模式让页面先进入，再由页面显示 pending skeleton。两者没有绝对优劣：

- 详情关键内容少且必须完整：可阻塞；
- 仪表盘多个独立区块：可先导航、分区加载；
- 慢数据：避免让导航看起来无响应。

具体 `await` 与 lazy 交互以当前 Nuxt 4 文档为准，不凭旧教程推断。

## 16. server: false 把获取推迟到客户端

浏览器专用或无需首屏/SEO的数据可只在客户端加载。初始 SSR payload 没有它，水合完成前 data 可能仍是 undefined，因此必须有初始状态。

不要为修 hydration 问题把所有请求都改 `server:false`；那只是放弃 SSR，可能造成内容闪烁和额外瀑布。先找到两端输入不一致原因。

## 17. Payload 是从服务器传给客户端的状态边界

服务器获取的数据会序列化进入页面 payload。它最终会到浏览器，所以不能包含：

- 数据库密钥和私密环境变量；
- 仅服务端可见的内部字段；
- 其他租户数据；
- 原始 Token/Session；
- 无需传输的巨大对象。

可以使用 `pick`/`transform` 等减少进入 payload 的字段，但最好从 API/用例源头只返回需要的 DTO。

## 18. 服务器与客户端的序列化能力有边界

AsyncData payload 可由 Nuxt 的序列化机制支持比纯 JSON 更多类型，但 server API 响应常仍按 JSON 语义传输。无论框架能否复原 Date/Map，都应定义跨边界合同。

Class 实例、函数、数据库连接和请求对象不能放响应式 payload。日期建议用明确 ISO 时间字符串/时区语义并在边界解析。

## 19. useState 提供 SSR 安全的共享状态工厂

```ts
const theme = useState<'light' | 'dark'>('theme', () => 'light')
```

与模块顶层 `const user = ref(...)` 不同，Nuxt 能为 SSR 请求管理状态并序列化给客户端。

Key 必须唯一且稳定，初始工厂要可序列化、无副作用。复杂业务状态可使用与 Nuxt SSR 集成正确的 Pinia，每次请求都要隔离实例。

## 20. 模块级单例可能跨用户请求泄露状态

危险：

```ts
const currentUser = ref<User | null>(null)
```

若模块在 Node 服务器进程中只加载一次，多个请求可能共享这个 ref。用户 A 的数据可能被 B 看到。

SSR 用户状态必须按请求创建或使用框架提供的请求隔离状态。普通纯常量、无用户数据的配置可以模块共享。

## 21. 服务端请求需要谨慎转发 Header 和 Cookie

服务端渲染时调用内部 API，浏览器 Cookie 不会自动像客户端 fetch 那样自然存在。Nuxt 提供 request-aware fetch 能转发合适请求 header/cookie，同时会排除不应转发的部分。

不要把所有入站 header 原样转发给任意第三方 URL，可能泄露 Cookie、Authorization 和内部信息。只对可信内部目标、按允许列表转发必要字段。

## 22. Runtime Config 区分服务端秘密和公开配置

概念：

```ts
runtimeConfig: {
  databasePassword: 'server-only',
  public: {
    apiBase: '/api',
  },
}
```

`public` 内容会进入客户端包或 payload，不能放秘密。服务端环境变量在部署时注入，不提交仓库。

变量命名和运行时覆盖规则随 Nuxt/Nitro 有约定，部署前按当前官方文档和平台验证。

## 23. Nitro 提供服务端运行和部署适配

Nuxt 的服务端能力由 Nitro 构建，可包含：

- server routes/API；
- server middleware；
- server plugins；
- storage/caching 抽象；
- 面向不同平台的 deployment presets。

部署到 Node Server、Serverless 或 Edge 时，文件系统、进程生命周期、连接池和冷启动边界不同。不能在本地长进程正常就假定所有平台都正常。

## 24. Server Route 也是完整安全边界

```text
浏览器 → Nuxt server route → Spring API
```

Nuxt 可充当 BFF：持有 OAuth Token、把 HttpOnly Session 给浏览器、聚合后端数据。但 server route 必须：

- 认证当前会话；
- 执行或委托授权；
- 校验输入；
- 限制上游地址，防 SSRF；
- 不向客户端泄露后端 Token；
- 正确映射 Cookie、CSRF 和错误。

“代码在 server 目录”不自动安全。

## 25. Route Rules 可以按路径选择渲染和缓存策略

概念上可配置：

- prerender；
- SSR 开关；
- 缓存/再验证；
- 重定向和 header；
- 边缘运行等平台行为。

公开文档页可预渲染，租户后台不能被公共缓存。缓存 key 必须区分身份和语言等必要维度，敏感页面通常不共享缓存。

具体 routeRules 字段和实验能力会变化，真正配置时查询当前文档。

## 26. Prerender 只生成构建时能发现或指定的路由

动态页面 `/work-orders/[id]` 不会因为有文件就自动生成所有 ID。可通过链接爬取、显式列表或构建钩子提供路由。

敏感工单不应构建为公开静态文件。SSG 适合公开、稳定内容；登录后个性数据应由运行时安全获取。

构建后数据变化还需要重新部署或采用再验证策略。

## 27. SEO 元数据要由页面数据稳定生成

Nuxt 提供 head/SEO composable 管理 title、description、canonical、Open Graph 等。

```text
公开设备知识页 → 可用服务端数据生成明确标题
私有工单页 → noindex，避免把敏感标题写入公开元数据
```

元数据也参与 SSR/hydration，不能在客户端随机变化。结构化数据必须与页面可见事实一致。

## 28. 图片和资源需要与部署策略协同

本地静态资源、public 文件、构建导入、CDN/图片优化模块有不同处理方式。应明确：

- 是否带内容 hash；
- 缓存时长；
- 尺寸和格式候选；
- 跨域和 CSP；
- SSR 时 URL 是否一致；
- 私有附件是否经授权 URL。

不要把私有维修照片放进构建时 public 目录。

## 29. 错误有页面级、服务端级和局部级

- 组件局部 API 失败：保留页面并提供重试；
- 页面资源 404/403：显示对应安全页面；
- 服务端渲染异常：返回正确 HTTP 状态和安全错误页；
- 全局致命错误：Nuxt error boundary/page；
- 导航 chunk 加载失败：可恢复刷新策略。

不要把所有错误变成 200 + “出错了”，搜索、缓存和监控会失去语义。错误页不能泄露堆栈和秘密。

## 30. Hydration 调试要比较两次初始输入

步骤：

1. 查看服务器返回的 HTML；
2. 查看客户端第一次渲染预期；
3. 找时间、随机、浏览器 API、语言、请求结果差异；
4. 检查 HTML 是否合法嵌套；
5. 检查 payload key 和数据是否重复获取；
6. 用最小组件定位；
7. 修复数据来源，而非整个组件包 `ClientOnly`。

浏览器扩展也可能修改 DOM，应在干净环境复现。

## 31. 生产部署需要验证运行适配器

构建成功后还要在接近生产环境验证：

- preset/Node 版本匹配；
- 反向代理正确传 Host、proto 和客户端信息；
- base URL 与资产路径；
- runtime config 注入；
- 健康、就绪与优雅停止；
- Session/Cookie 的 Secure、Domain、SameSite；
- 多实例状态和缓存；
- 服务端日志、trace 与错误；
- 静态资源缓存和回滚。

本地 `npm run dev` 与生产 serverless/容器生命周期差异很大。

## 32. 可访问性在路由和水合后仍要保持

- 客户端导航更新 title 和主内容焦点；
- loading 和错误状态可被感知；
- `ClientOnly` fallback 有意义且不造成焦点跳跃；
- 水合前按钮不应看似可用却长时间无响应；
- 动态页面遵守减少动效；
- 服务端 HTML 本身有合理语义，不依赖 JS 才出现所有内容。

SSR 能提供 HTML，但不自动保证语义和键盘行为。

## 33. 这篇的整体地图

```text
URL 请求
  → Nuxt 按路由选择 SSR / CSR / prerender / hybrid
  → 服务端运行组件与 useFetch/useAsyncData
  → HTML + payload 到浏览器
  → Hydration 用一致状态接管 DOM
  → 后续客户端导航和数据刷新

服务端：Nitro routes + runtime config + deployment preset
客户端：Vue components + Router + hydration
边界：序列化、Cookie/header、缓存、租户和秘密
```

必须掌握：同一组件可能在服务端和客户端执行；水合要求初始输出一致；useFetch/useAsyncData 负责 SSR 数据传递，$fetch 适合直接交互；模块单例不能保存用户状态；public runtime config 不是秘密；预渲染和缓存不能泄露私有数据。

Nitro hooks、各云平台 preset 和实验型 route rules 属于“需要时查询”，应以真正学习/部署当天的 Nuxt 4 官方文档为准。
