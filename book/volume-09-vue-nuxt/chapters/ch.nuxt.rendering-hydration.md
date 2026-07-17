---
schema_version: 2
edition: 2026.2-draft
id: ch.nuxt.rendering-hydration
title: Nuxt SSR、SSG、水合与服务端数据获取
responsibility: 区分 SSR、SSG 与客户端渲染，解释服务端/客户端执行边界、水合一致性和 Nuxt 数据获取，不在本章教授生产部署或完整认证。
volume: '09'
order: 15
level: L2+
status: drafting
path: book/volume-09-vue-nuxt/chapters/ch.nuxt.rendering-hydration.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.vue.components-contracts
version_surfaces:
- nuxt-4
- vue-3
- vite
- node-24-lts
- pnpm
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“Nuxt SSR、SSG、水合与服务端数据获取”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - nuxt-rendering-modes
  - nuxt-hydration-data
  covers_topics:
  - nuxt.ssr-ssg-csr
  - nuxt.server-client-runtime
  - nuxt.route-render-rule
  - nuxt.universal-code-boundary
  - nuxt.hydration
  - nuxt.hydration-mismatch
  - nuxt.use-async-data
  - nuxt.payload-serialization
  - nuxt.server-fetch-boundary
  uses_capabilities:
  - web.vue-components-contracts
  - web.javascript-async-runtime
  - foundation.http-message
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为工单列表实现 SSR 与预渲染对照页面并保存 HTML、payload 和水合证据；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - nuxt-rendering-modes
  - nuxt-hydration-data
  covers_topics:
  - nuxt.ssr-ssg-csr
  - nuxt.server-client-runtime
  - nuxt.route-render-rule
  - nuxt.universal-code-boundary
  - nuxt.hydration
  - nuxt.hydration-mismatch
  - nuxt.use-async-data
  - nuxt.payload-serialization
  - nuxt.server-fetch-boundary
  uses_capabilities:
  - web.vue-components-contracts
  - web.javascript-async-runtime
  - foundation.http-message
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: server-client-snapshot-hydration-console-check-curl-browser-contrast
- id: diagnose
  kind: fault-diagnosis
  text: 面对“服务端使用浏览器 API、随机值或时区差异导致的构建与水合不一致”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - nuxt-rendering-modes
  - nuxt-hydration-data
  covers_topics:
  - nuxt.ssr-ssg-csr
  - nuxt.server-client-runtime
  - nuxt.route-render-rule
  - nuxt.universal-code-boundary
  - nuxt.hydration
  - nuxt.hydration-mismatch
  - nuxt.use-async-data
  - nuxt.payload-serialization
  - nuxt.server-fetch-boundary
  uses_capabilities:
  - web.vue-components-contracts
  - web.javascript-async-runtime
  - foundation.http-message
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# Nuxt SSR、SSG、水合与服务端数据获取

> Nuxt 不只是“带文件路由的 Vue”。同一份组件代码可能先在服务器生成 HTML，再在浏览器水合并接管交互。你必须知道代码在哪个运行时执行、数据如何进入 payload、初始 HTML 与客户端第一次渲染为何必须一致。

## 1. 一次页面访问经历了什么

以 FactoryCare 公开知识页为例。用户直接访问 `/knowledge/pump-overheat` 时，通用渲染流程可以拆成：

1. 浏览器向 Nuxt 服务请求 URL；
2. 服务器创建本次请求的应用上下文；
3. 页面组件在服务器执行，`useAsyncData`获取公开知识数据；
4. Vue 把组件树渲染成 HTML；
5. Nuxt 把可序列化的数据放入 payload；
6. 浏览器先显示 HTML，再下载客户端 JavaScript；
7. Vue 在已有 DOM 上执行第一次客户端渲染并水合事件；
8. 后续导航通常在客户端完成，必要时再请求数据或 payload。

服务器生成 HTML 与浏览器第一次渲染结果必须在结构和关键内容上相容。若服务器输出“处理中”，浏览器第一次却输出一个随机工单号，Vue 不能可靠地把事件绑定到原 DOM，于是出现 hydration mismatch、重建节点、闪烁或交互错误。

水合不是重新请求所有东西的同义词。`useAsyncData`的一个核心职责，是把服务器结果写入 Nuxt payload，使客户端水合时复用，而不是对相同键立即再发一次请求。

## 2. SSR、SSG 与 CSR

### 2.1 SSR：请求到来时渲染

Server-Side Rendering 在每次请求或缓存未命中时，由服务器运行 Vue/Nuxt 代码并返回完整 HTML。它适合内容需要按请求变化、首屏内容重要或需要搜索引擎读取的页面。

优点包括首个 HTML 已有内容、可表达请求上下文、在合适场景改善首屏和索引。成本是必须维护服务器运行时，代码同时面对 Node/边缘与浏览器两种环境，数据请求、错误和缓存策略更复杂。

SSR 不自动等于快速。若服务器依次调用三个慢接口、序列化巨大 payload，再发送大量客户端 JavaScript，总体验仍会很差。

### 2.2 SSG：构建时预渲染

Static Site Generation 在构建阶段执行页面，将结果保存为静态 HTML/payload，由 CDN 或静态服务器直接返回。适合变化不频繁、可枚举路径的公开文档、帮助页和营销内容。

SSG 不是“没有 Vue”。页面仍可下载客户端代码并水合交互。它只是把服务器渲染的时刻从用户请求前移到构建。数据变化后需要重新生成、按需再验证或客户端刷新，具体策略必须显式设计。

### 2.3 CSR：浏览器渲染

Client-Side Rendering 的初始 HTML 通常只有应用外壳，数据和主要内容在浏览器 JavaScript 执行后出现。它适合强交互、登录后且搜索索引不是重点的管理区域，也可以降低服务端渲染约束。

CSR 的代价包括首次内容依赖脚本下载/执行、慢设备或网络下空壳时间更长、爬虫和社交预览能力取决于外部条件。不能因为管理端不需要 SEO，就忽略加载性能和错误状态。

### 2.4 混合渲染

Nuxt 4 支持 route rules，让不同路径采用不同策略。例如公开知识页预渲染，动态详情 SSR，内部工具 CSR：

```ts
export default defineNuxtConfig({
  routeRules: {
    '/knowledge/**': { prerender: true },
    '/public/reports/**': { ssr: true },
    '/admin/**': { ssr: false },
  },
})
```

规则语义、缓存和部署支持属于版本及平台表面。路径重叠时必须测试最终匹配，不要只看配置文件觉得合理。

## 3. 为 FactoryCare 选择渲染方式

选择维度不是“哪个更先进”，而是内容变化、访问身份、首屏、索引、缓存、成本与运行时能力。

| 路由 | 推荐起点 | 理由 | 仍需验证 |
| --- | --- | --- | --- |
| 公开产品介绍 | SSG | 内容稳定、适合 CDN | 发布刷新与预览 |
| 已发布公开知识文章 | SSG/混合缓存 | 可索引、版本明确 | 撤回后的失效策略 |
| 带公开编号的报修进度摘要 | SSR | 请求级数据、首屏重要 | 隐私、缓存键、限流 |
| 租户管理后台 | CSR 或 SSR | 强交互、登录上下文 | 首屏、权限与部署成本 |
| 个性化工单列表 | SSR/CSR 需实验 | 取决于首屏和请求成本 | 数据转发、payload 大小 |

不要把敏感接口响应为了“SEO”塞进 HTML。服务端渲染只改变数据到达页面的路径，不改变授权要求。Java 服务仍要验证租户、角色和数据范围。

## 4. 两个运行时：服务器与浏览器

通用组件可能在服务端和客户端都执行。两边可用 API 不同：

- 服务端有请求头、服务端密钥、文件系统或数据库连接能力，但没有 DOM、`window`和 `localStorage`；
- 浏览器有 DOM、Storage、媒体查询和用户交互，但不能获得私密 runtime config；
- 通用代码只能依赖双方都存在且结果确定的能力。

Nuxt 提供 `import.meta.server`与 `import.meta.client`判断编译/运行侧：

```ts
if (import.meta.client) {
  const theme = localStorage.getItem('theme')
}
```

判断只是边界工具，不代表服务端与客户端可以分别生成完全不同的首屏 DOM。若该值参与模板，服务器必须提供稳定 fallback，客户端应在挂载后再更新，或使用 SSR 友好的 cookie/composable 保持一致。

浏览器专用插件和组件可以使用 `.client`后缀或 `<ClientOnly>`，服务器专用代码放入 `server/`。共享目录中的代码必须严格审查依赖；一个顶层导入若在加载时读取 `window`，即使调用被包在 `if (import.meta.client)`中，也可能已经在服务器构建/执行阶段失败。

## 5. 服务端请求上下文不能成为全局单例

在长期运行的 Node 进程里，模块会被多个请求复用。把当前用户、租户或 token 存进模块顶层变量，可能让请求 B 读到请求 A 的状态：

```ts
// 严重错误：跨请求共享可写身份。
let currentTenantId: string | undefined
```

身份信息必须来自当前请求上下文、cookie/headers 与受控服务端 session，并在向 Java API 转发时建立白名单。不能把所有浏览器请求头原样转发，因为其中可能包含不应发送给内部服务的字段。

每次 SSR 请求都要拥有隔离的 Nuxt/Vue/Pinia 上下文。模块顶层可以保存不可变配置或明确的跨请求缓存，但缓存键必须包含所有影响响应的维度，敏感响应默认不应共享缓存。

## 6. 水合的精确心智模型

水合时 Vue 不从空 DOM 开始，而是把客户端虚拟 DOM 与服务器已有 DOM 对齐，附加事件监听并恢复响应式状态。第一次客户端渲染必须使用与服务器一致的输入。

常见不一致来源：

- 模板中调用 `Math.random()`或直接生成 UUID；
- 服务端和客户端分别调用 `new Date()`，跨过秒/日期边界；
- 不同默认时区或 locale 格式化出不同文本；
- setup 直接读取 `localStorage`、视口宽度或媒体查询；
- 服务端与客户端分别请求一次数据，结果版本不同；
- 条件渲染依赖仅一侧存在的环境变量；
- 无效 HTML 被浏览器解析器修正，DOM 结构不同；
- 列表顺序不稳定或 key 由随机值产生；
- 第三方脚本在 Vue 接管前修改 DOM。

Hydration warning 不是可忽略的开发噪声。它可能导致整棵子树重建、事件绑定错误、布局闪烁和 SEO 内容与用户看到的内容不同。

## 7. 修复不一致，而不是隐藏警告

### 7.1 随机值

如果业务需要随机种子，服务器生成一次并序列化进 payload，客户端复用同一值。不要两侧各调用一次随机函数。仅装饰性内容可延后到 `onMounted`，但要提供尺寸稳定的 fallback。

### 7.2 时间与时区

服务器返回 ISO 时间和明确时区，首屏可显示确定格式；若要按用户本地时区展示，使用客户端挂载后更新或 Nuxt 提供的时间组件，并接受/控制变化。测试要固定 locale、timezone 与系统时间。

### 7.3 浏览器偏好

主题若必须首屏一致，可使用请求可读 cookie；若只存在 localStorage，服务器先输出固定默认主题，客户端挂载后再更新。最糟做法是服务器输出 light，客户端第一次渲染立即读取 dark，造成结构/属性不一致和闪屏。

### 7.4 ClientOnly

地图、富文本编辑器等真正依赖 DOM 的模块可以放在 `<ClientOnly>`中，但要提供语义和尺寸合理的 fallback。ClientOnly 是明确边界，不是把所有警告包起来的创可贴；关键内容若只在客户端出现，会改变首屏和索引能力。

## 8. `useAsyncData`：SSR 友好的数据获取

Nuxt 4 的 `useAsyncData`接收稳定 key、异步 handler 和选项，返回 `data`、`status`、`error`、`refresh/execute`与 `clear`等响应式/操作接口：

```vue
<script setup lang="ts">
const route = useRoute()
const key = computed(() => `public-work-orders:${route.query.page ?? '1'}`)

const { data, status, error, refresh } = await useAsyncData(
  key,
  (_nuxtApp, { signal }) => $fetch('/api/public/work-orders', {
    query: { page: route.query.page ?? 1 },
    signal,
  }),
  {
    watch: [() => route.query.page],
    dedupe: 'cancel',
    timeout: 5_000,
    deep: false,
  },
)
</script>
```

handler 在 SSR 时执行，其结果进入 payload；客户端水合复用同 key 的数据。key 是缓存和共享身份，不能让不同参数误用同一 key。同 key 的多个调用会共享状态，影响结果语义的 handler、deep、transform、pick 等选项必须一致。

handler 应无副作用并返回非 `null/undefined`值，否则客户端可能重复请求。发送审计事件、写数据库或发送通知不应放在可能执行多次的数据 handler 中；需要一次性副作用时使用专门服务端流程或官方 `callOnce`语义，并仍保证后端幂等。

`signal`使 handler 能响应取消。`dedupe: 'cancel'`、clear、timeout 或显式 signal 可以终止当前处理，但底层 repository/$fetch 必须真正传递 signal；仅接收参数却忽略，不能声称已取消。

## 9. `useFetch`、`$fetch` 与重复请求

`$fetch`是请求函数，本身不会自动把服务端结果序列化到 Nuxt payload。若在组件 setup 中直接 `await $fetch`，同一逻辑可能在服务端执行，又在客户端水合时执行，形成双请求。`useFetch`在常见 URL 请求上封装了 `useAsyncData`与 `$fetch`，适合 SSR 友好获取。

选择原则：

- 页面/组件需要 SSR 结果和 payload 复用：`useFetch`或 `useAsyncData`；
- 用户点击后提交、删除、重试等客户端事件：直接 `$fetch`，并自行处理状态/幂等；
- 复杂 repository、多个请求组合或自定义缓存：`useAsyncData`包裹无副作用 handler；
- Nitro server route 内部：根据上下文调用服务或 `$fetch`，不要误用组件 composable。

名字相似不等于职责相同。排查重复请求时先记录执行侧、key、payload 是否命中和调用栈。

## 10. Payload：数据桥梁也是安全边界

Payload 需要序列化到 HTML 或独立文件，再由浏览器读取。它不是任意 JavaScript 对象的透明克隆。函数、DOM 节点、连接、请求对象和许多类实例不应作为页面数据返回；日期、Map、自定义类型等具体支持随 Nuxt 序列化实现变化，必须用当前版本测试。

推荐返回明确 DTO：字符串、数字、布尔、null、数组和普通对象，并使用 ISO 字符串表达时间。利用 `pick`/`transform`只保留客户端所需字段，降低体积和泄露面。

绝不能进入 payload：服务端密钥、内部 bearer token、数据库连接信息、其他租户数据、未授权字段、完整异常堆栈。HTML 源码对用户可见，即使页面没有把字段渲染出来，payload 里仍能读取。

对 FactoryCare 公开进度页，Java API 应先返回专用公开 DTO；Nuxt 不能抓取内部工单实体后仅在模板中隐藏联系人。

## 11. 服务端数据获取与 Java API 边界

Nuxt server 可以作为 BFF，但不应复制 Java 领域规则。其合理职责包括：读取当前请求 cookie、建立安全后端调用、组合适合页面的读取结果、隐藏内部服务地址、处理 SSR 需要的响应状态。

Java 仍负责租户隔离、角色与数据范围、状态机、事务、审计和业务事实。Nuxt 不能因服务端运行而被信任；传来的 ID、cookie 和查询参数仍需验证。

转发请求时明确：

- 允许哪些 header/cookie；
- 超时、取消和 request id；
- 401/403/404 映射；
- 缓存是否按用户/租户隔离；
- 错误对象怎样脱敏；
- SSR 与客户端导航是否走同一公开契约；
- 内部地址与 secret 只来自私密 runtime config。

本章不实现完整认证。生产 cookie 属性、CSRF、token 刷新和 BFF 会话需要安全章节单独设计。

## 12. 三种路由的证据矩阵

不要只打开浏览器“看起来一样”。用 curl、构建工件和浏览器建立矩阵：

| 证据 | SSR | SSG | CSR |
| --- | --- | --- | --- |
| 首次 curl HTML | 含当次数据内容 | 含构建时内容 | 通常是应用外壳 |
| 生成时机 | 请求/缓存未命中 | 构建/再生成 | 浏览器运行时 |
| payload | 当次请求产生 | 随静态产物 | 初始可能无业务数据 |
| 服务端数据请求 | 首次请求时 | 构建时 | 通常无 |
| 浏览器首次业务请求 | payload 命中时不重复 | payload 命中时不重复 | 需要请求 |
| 水合 | 是 | 通常是 | 从空壳挂载，不是同一 SSR 水合路径 |

完整 Lab 应保存：三条 curl 输出、Network 请求计数、服务日志中的执行侧、payload 摘要、hydration console、JavaScript 禁用时的 HTML、客户端导航后 DOM。只有 HTML 截图不能证明请求次数；只有服务器日志不能证明水合后 DOM。

## 13. 三个注入故障

### 13.1 服务端访问浏览器 API

**故障**：setup 顶层读取 `localStorage`。

**预期失败阶段**：SSR 请求或构建，出现 `localStorage/window is not defined`。

**首个可信位置**：首个栈帧指向通用组件的浏览器 API 读取，而不是后续 500 页面。

**修复**：使用 SSR 友好 cookie，或把非关键读取放到 `onMounted`/client-only 边界并提供稳定 fallback。重跑服务端 curl 与浏览器。

### 13.2 随机值导致水合不一致

**故障**：模板直接调用 `Math.random()`。

**预期失败阶段**：服务器 HTML 成功，但客户端 hydration warning；文本不同。

**修复**：服务器生成种子/值并放入 payload，客户端复用；或延后为非首屏客户端装饰。用固定输入稳定复现，不能靠“这次随机碰巧一样”。

### 13.3 时区差异

**故障**：服务器 UTC、浏览器 Asia/Shanghai 分别对同一 Date 使用默认本地格式。

**预期失败阶段**：HTML 与客户端第一次渲染文本不同。

**修复**：首屏使用明确时区/格式或一致 ISO；需要用户本地格式时挂载后更新并提供稳定 fallback。测试固定 `TZ`和 locale。

## 14. 常见错误路线

### “全部包 ClientOnly 就没有警告”

这会把问题变成内容延迟、SEO 缺失和布局跳动。只有真正浏览器专属且不适合 SSR 的区域才使用。

### “设置 `ssr: false`最快”

这只是切换渲染架构，可能规避服务端错误，却改变首屏与索引。必须按路由需求决定，并建立 CSR 加载预算。

### “服务端能访问内部 API，所以无需权限”

错误。Nuxt 服务也在处理用户输入，Java 服务必须继续执行授权。BFF 不能越过领域边界。

### “忽略 hydration warning，生产会自动好”

开发 warning 揭示确定性或结构问题。生产可能减少日志，却不会让根因消失。

### “useAsyncData key 随便写”

相同 key 共享数据，不同参数误用会串结果；不稳定 key 又会丢失复用并重复请求。key 应表达数据身份。

## 15. 配套资产与完成判据

本章配套四类工件：

- `examples/encyclopedia/ch.nuxt.rendering-hydration/`：最小 Nuxt 4 源码合同与 SSR/SSG/CSR 快照模型；
- `labs/encyclopedia/ch.nuxt.rendering-hydration/`：三模式矩阵、payload 复用与三种故障注入；
- `exercises/encyclopedia/ch.nuxt.rendering-hydration/`：故意随机化且泄露服务端字段的公开红灯；
- `solutions-private/encyclopedia/ch.nuxt.rendering-hydration/`：同一 oracle 下的确定性参考修复。

机械验证不会启动 Nuxt/Nitro 或真实浏览器，因此只证明模型和源码合同。完整 Lab 必须额外运行当前 Nuxt 4、生产构建/预渲染、curl 与浏览器 hydration console。

完成判据：

1. SSR、SSG、CSR 首次 HTML 与请求次数符合矩阵；
2. `useAsyncData`稳定 key 的 payload 在水合时复用；
3. 客户端专属 API 不在服务端路径执行；
4. 服务器与客户端首次 DOM 一致；
5. payload 不含 secret、内部 token 或未授权字段；
6. 随机、浏览器 API、时区三个故障可稳定定位；
7. 保存命令、版本、HTML、payload、日志、console 和修复后重跑。

## 16. AI 生成 Nuxt 代码的验收

AI 经常把普通 Vue SPA 代码直接搬进 Nuxt，最典型错误是 setup 顶层使用 `window`，用 `$fetch`造成 SSR/水合双请求，或者把服务端 secret 放进公开 runtime config。

让 AI 输出前先要求它标注每段代码的执行侧：server-only、client-only、universal、build-time。再逐项检查：

- 路由使用 SSR、SSG、CSR 的理由；
- 数据 key 与请求参数是否一一对应；
- handler 是否无副作用、可取消并返回可序列化非空值；
- payload 字段白名单；
- 首次服务器/客户端输入是否确定一致；
- 浏览器专属库是否延迟导入；
- 请求上下文是否被模块单例污染；
- 错误、pending、empty 和无 JavaScript 路径；
- curl、浏览器与日志分别证明什么。

不能接受“Nuxt 会自动处理 SSR”作为解释。自动约定减少样板，不会自动修复不确定数据、安全边界或业务授权。

## 17. 120 秒口述与独立构建

口述时说明：SSR、SSG、CSR 分别在何时生成 HTML；通用代码为什么运行两次；水合的目标是什么；随机值和时区为何造成 mismatch；`useAsyncData`如何通过 key 与 payload 避免重复请求；为什么 payload 是安全边界；Nuxt server 与 Java 业务服务如何分工。

不应由本章解决的反例：“为 FactoryCare 实现完整 OAuth/OIDC 登录、token 轮换和 CSRF 防御。”本章只说明请求上下文和数据转发边界，认证方案必须由身份安全设计完成。

独立构建：创建三个工单路由，分别使用 SSR、预渲染和 CSR；固定同一夹具，保存初始 HTML、请求日志、payload 与水合后 DOM；随后注入浏览器 API、随机值和时区差异，记录失败，再修复并重跑。

## 18. 版本表面与未验证边界

本章在 2026-07-17 对照 Nuxt 4.4.8 官方文档。稳定原则是执行侧明确、每请求隔离、首屏确定、payload 最小且安全、数据 key 稳定；版本表面包括 route rules、payload 序列化、目录约定、`useAsyncData`选项、Nitro 与部署平台行为。

本机当前 Node 22/pnpm 10 的轻量 verifier 不等于 canonical 目标 Node 24 LTS/pnpm 当前面的真实 Nuxt 运行。P6 drafting 阶段不声称完成 Nitro server、真实 curl、浏览器 hydration、部署缓存或认证验证。

## 19. 官方资料

- [Nuxt 4：Rendering Modes](https://nuxt.com/docs/4.x/guide/concepts/rendering)
- [Nuxt 4：Nuxt and Hydration](https://nuxt.com/docs/4.x/guide/best-practices/hydration)
- [Nuxt 4：useAsyncData](https://nuxt.com/docs/4.x/api/composables/use-async-data)
- [Nuxt 4：Directory Structure](https://nuxt.com/docs/4.x/directory-structure/)
- [Nuxt 4：server Directory](https://nuxt.com/docs/4.x/directory-structure/server)
- [Vue：SSR Hydration](https://vuejs.org/guide/scaling-up/ssr.html#hydration-mismatch)

## 20. 本章结论

Nuxt 渲染的核心不是配置名，而是一条跨运行时证据链：SSR 在请求时生成 HTML，SSG 在构建时生成，CSR 在浏览器生成；通用组件必须同时遵守服务器与浏览器边界；服务器 HTML 与客户端第一次渲染必须确定一致；`useAsyncData`用稳定 key、无副作用 handler 和 payload 复用连接两侧；payload 只含授权且可序列化的页面 DTO。用 curl、浏览器、网络日志和 hydration console 对照三种模式，才能证明实现，而不是只看到页面最终长得一样。
