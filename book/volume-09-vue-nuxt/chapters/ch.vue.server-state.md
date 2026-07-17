---
schema_version: 2
edition: 2026.2-draft
id: ch.vue.server-state
title: 服务端状态、加载、错误、取消与竞态
responsibility: 在 Vue 中建模 idle/loading/success/error 状态、请求身份、取消和重取，避免陈旧响应覆盖且不把服务器缓存数据当普通 Pinia 客户端状态。
volume: '09'
order: 10
level: L2+
status: drafting
path: book/volume-09-vue-nuxt/chapters/ch.vue.server-state.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.vue.pinia-state
version_surfaces:
- vue-3
- pinia
- vitest
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
  text: 在 120 秒内解释“服务端状态、加载、错误、取消与竞态”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - vue-server-state-machine
  - vue-request-race-cleanup
  covers_topics:
  - vue.async-state-union
  - vue.loading-error-success
  - vue.retry-refresh
  - vue.server-cache-boundary
  - vue.request-identity
  - vue.abort-on-invalidate
  - vue.latest-response-guard
  - vue.unmount-request-cleanup
  - js.latest-request-wins
  uses_capabilities:
  - web.vue-reactivity-lifecycle
  - web.vue-client-state
  - web.javascript-network-race
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现可取消的工单查询 Composable 和状态视图并用受控 Promise 验证竞态；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - vue-server-state-machine
  - vue-request-race-cleanup
  covers_topics:
  - vue.async-state-union
  - vue.loading-error-success
  - vue.retry-refresh
  - vue.server-cache-boundary
  - vue.request-identity
  - vue.abort-on-invalidate
  - vue.latest-response-guard
  - vue.unmount-request-cleanup
  - js.latest-request-wins
  uses_capabilities:
  - web.vue-reactivity-lifecycle
  - web.vue-client-state
  - web.javascript-network-race
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: vitest-controlled-promise-state-transition-assertions-race-injection
- id: diagnose
  kind: fault-diagnosis
  text: 面对“finally 无条件清 loading、旧请求覆盖新结果或卸载后继续更新状态”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - vue-server-state-machine
  - vue-request-race-cleanup
  covers_topics:
  - vue.async-state-union
  - vue.loading-error-success
  - vue.retry-refresh
  - vue.server-cache-boundary
  - vue.request-identity
  - vue.abort-on-invalidate
  - vue.latest-response-guard
  - vue.unmount-request-cleanup
  - js.latest-request-wins
  uses_capabilities:
  - web.vue-reactivity-lifecycle
  - web.vue-client-state
  - web.javascript-network-race
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 服务端状态、加载、错误、取消与竞态

> 本章状态为 **drafting**。正文与离线工件可用于学习和作者自检，但不能证明学习者完成了无 AI 独立实现，也不能证明真实网络、浏览器 Fetch、Vue 调度、后端缓存或生产故障已验证。官方 Vue、Fetch 与相关资料复核日为 **2026-07-17**；配套工件用 Node 受控 Promise 消除网络不确定性，不修改 `PROGRESS.md`。

服务器返回的工单不是“另一个 ref”。它有远端权威、请求参数、加载过程、HTTP 与解析失败、取消、缓存新鲜度、重新验证和乱序完成。若把 `data`、`loading`、`error` 三个互不约束的布尔/可空变量散在组件里，页面可以同时声称“成功且错误”“旧请求已结束所以不加载”，甚至把上一筛选结果覆盖到当前筛选。

本章建立两层合同：第一层用 discriminated union 表达 idle/loading/success/error 的互斥状态；第二层为每次请求分配身份，并在每次写状态前同时检查“仍是最新请求、未失效、组件仍存活”。`AbortController` 用来释放旧工作，但 latest-response guard 才是最后提交门。二者必须同时存在。

本章不实现通用缓存库、离线同步、乐观更新、分页归并、SSE、后端幂等或全局错误中心。反例：两个用户并发修改同一工单导致版本冲突，需要后端版本号、条件请求或领域并发控制，不能靠“最新前端 Promise 获胜”解决。

## 1. 完成标准与证据入口

canonical oracle 是：**成功、空、HTTP/解析错误、取消、重试和乱序响应下的状态转换确定；任何旧响应都不能改变最新请求状态。** 完成本章应能：

1. 区分服务器事实、客户端界面状态与纯派生状态，说明为何服务器记录不应被当作普通长期 Pinia 字段；
2. 用 TypeScript union 表达 idle/loading/success/error，排除互相矛盾组合；
3. 为每次请求保存单调 request identity、输入快照和 `AbortController`；
4. 在 success、HTTP error、parse error、catch 与 finally 的每个写点检查当前身份；
5. 在输入失效时 abort，在组件卸载时 dispose，并说明 abort 不保证服务器停止处理；
6. 区分“旧请求不能提交”与“新请求 loading 何时结束”，避免旧 finally 无条件清新 loading；
7. 定义 retry 与 refresh：重试哪个输入、是否保留旧数据、错误计数与按钮何时可用；
8. 用受控 Promise 精确决定完成顺序，不用随机 timeout 伪造竞态测试；
9. 注入陈旧覆盖、loading 腐蚀与卸载后更新，保存首个可信差异并重跑同一矩阵。

配套入口：

- [服务端状态受控 Promise 示例](../../../examples/encyclopedia/ch.vue.server-state/README.md)
- [竞态、finally 与卸载故障实验](../../../labs/encyclopedia/ch.vue.server-state/README.md)
- [公开稳定红灯练习](../../../exercises/encyclopedia/ch.vue.server-state/README.md)

离线绿灯只证明纯状态控制器和固定输入。正式 G4 还需保存 Vue/Vite/Vitest/浏览器版本、真实 `fetch` 请求、Network 面板、请求/响应头、HTTP 状态、组件挂载/卸载轨迹、watch cleanup、DOM 状态、真实取消现象以及后端是否继续处理的服务器日志。

## 2. 先分所有权：服务器状态不是客户端偏好

上一章用 Pinia 管理跨组件客户端状态，例如筛选条件、紧凑布局和当前工作区选择。这些状态的权威在浏览器，action 可以直接决定新值。服务器工单的权威则在 API：浏览器持有的是某次查询在某时刻的快照。它需要额外元数据：query key、请求身份、更新时间、错误、stale/refreshing、取消与重试策略。

| 数据 | 权威 | 生命周期 | 写入入口 | 典型所有者 |
|---|---|---|---|---|
| 状态筛选 `IN_PROGRESS` | 客户端 | 当前会话/URL | 用户操作 | Router/Pinia |
| 表格紧凑模式 | 客户端 | 当前成员偏好 | store action | Pinia |
| 第 2 页工单 | 服务端 | query 与缓存策略 | 请求结果提交 | server-state composable/cache |
| `isEmpty` | 已有 success data | 随 data 派生 | 无 | computed |
| 当前 request id | 请求控制器 | 一次加载到失效 | load | composable 私有字段 |
| 搜索输入草稿 | 当前表单 | 输入到提交 | input | 本地 ref |

“不放普通 Pinia”不是禁止 Pinia 出现。认证或全局缓存实现可以把请求元数据装进 store，但仍必须保留 query identity、新鲜度、取消和失败合同。危险的是只写 `orders = response`，让调用者无法回答这份数据来自哪个参数、是否陈旧、谁能覆盖。

## 3. 用 union 排除不可能状态

三个独立字段容易产生 2³ 种组合：

```ts
const data = ref<WorkOrder[] | null>(null)
const loading = ref(false)
const error = ref<Error | null>(null)
```

其中 `loading=true + error!=null + data!=null` 到底表示重取、失败还是编程错误并不明确。更可靠的是明确状态机：

```ts
type Query = Readonly<{ status: string; page: number }>

type AsyncState<T> =
  | { tag: 'idle' }
  | { tag: 'loading'; requestId: number; query: Query; previous?: T }
  | { tag: 'success'; requestId: number; query: Query; data: T; receivedAt: number }
  | { tag: 'error'; requestId: number; query: Query; error: QueryError; previous?: T }

type QueryError =
  | { kind: 'http'; status: number; message: string }
  | { kind: 'parse'; message: string }
  | { kind: 'network'; message: string }
```

模板可以穷尽分支；TypeScript 能在 `switch(state.tag)` 中收窄。空列表不是网络失败，它通常是 `success` 且 `data.length === 0`，界面由此派生 empty view。取消也不一定是 error：旧请求因新输入失效时，不应覆盖当前 loading；用户显式取消当前请求时，可按产品合同回 idle 或保留前一 success，但必须写进状态矩阵。

是否在 loading/refresh error 中保留 previous data 是产品决策。首次加载通常没有 previous；后台 refresh 可以保留旧数据并显示“更新中”；参数完全改变时保留旧列表可能误导，应按 query 区分。不要一边保留旧数据一边把它标成新 query 的结果。

## 4. 请求适配器先区分失败阶段

Fetch 的 Promise 在收到 HTTP 404/500 时通常会正常 fulfilled；应用必须检查 `response.ok`/status。随后 JSON 解析也可能失败，结构验证还可能发现字段不符合合同。把所有异常压成“加载失败”会丢失首个可信证据。

```ts
// Responsibility: 把 HTTP、JSON 与领域结构边界转换为可分类的查询结果。
// Data source: /api/work-orders 响应；query 已在调用前归一化。
// Mapping: 非 2xx→http，JSON 失败/结构错→parse，合法数组→WorkOrder[]。
// Side effects: 发出一个可取消 Fetch；不会直接写 Vue/Pinia 状态。
async function requestWorkOrders(query: Query, signal: AbortSignal): Promise<WorkOrder[]> {
  const response = await fetch(buildUrl(query), { signal, credentials: 'same-origin' })
  if (!response.ok) {
    throw { kind: 'http', status: response.status, message: `HTTP ${response.status}` } satisfies QueryError
  }

  let unknownBody: unknown
  try {
    unknownBody = await response.json()
  } catch {
    throw { kind: 'parse', message: '响应不是合法 JSON' } satisfies QueryError
  }

  if (!isWorkOrderArray(unknownBody)) {
    throw { kind: 'parse', message: '响应结构不符合 WorkOrder[]' } satisfies QueryError
  }
  return unknownBody
}
```

Network error、CORS、DNS 与 abort 的具体异常形态属于浏览器版本和 Fetch 实现表面。适配器应保留 `signal.aborted`/abort reason 作为判断依据，不只比较一段可能变化的错误消息。真实服务器响应结构仍需契约测试，Node 夹具只模拟分类。

## 5. Request identity：提交权而非显示编号

竞态示例：用户先查 `ASSIGNED`（请求 41，慢），马上查 `IN_PROGRESS`（请求 42，快）。42 成功后，41 晚到。若两个 `.then()` 都能写 `data`，页面显示旧筛选结果。解决方法是给 load 调用单调编号，并把编号捕获在该请求闭包内：

```text
load(A) → id=41 → state=loading(41,A)
load(B) → abort(41), id=42 → state=loading(42,B)
resolve(B) → current=42 → commit success(42,B)
resolve(A) → current=42 → discard（即使传输忽略 abort）
```

核心谓词：

```ts
const mayCommit = () => alive && requestId === currentRequestId && !controller.signal.aborted
```

每个状态写点都调用它。只在 success 检查不够：旧 catch 可能写 error，旧 finally 可能清 loading。身份不是安全令牌，也不是服务端幂等 key；它只决定当前 composable 内哪个异步分支拥有提交权。

单调数字足以处理单实例。若多个独立查询并行，应按 query key 各自维护 identity；若列表和详情共享缓存，需更成熟的 query cache。不要用一个全局 `latestRequestId` 让无关请求互相取消。

## 6. Abort 与 latest guard 各解决一半问题

[Fetch Standard](https://fetch.spec.whatwg.org/) 定义 signal 参与 fetch abort；Vue 官方 watcher 文档也展示在 cleanup 中 `controller.abort()` 取消陈旧请求。Abort 的价值是尽早停止客户端不再需要的工作、避免继续读取 body，并表达失效原因。

但 abort 不是提交门，原因包括：传输适配器可能忽略 signal；Promise 可能已在完成队列；解析/后处理可能继续；服务器可能已收到并执行请求。尤其是写操作，前端 abort 绝不能被当作“服务端事务回滚”。latest guard 仍需阻止陈旧回调写当前状态。

Vue 3.5+ 提供 `onWatcherCleanup()`，官方要求在同步 watch/watchEffect 回调执行期间注册，不能在 `await` 后调用；watch 回调第三参数 `onCleanup` 绑定 watcher，可用于更广兼容写法。无论选哪一种，controller 必须在发请求前创建并立即注册 cleanup。

```ts
// Responsibility: 当规范化查询变化时启动最新请求，并让旧请求立即失效。
// Data source: status/page getter 的响应式值。
// Mapping: 每次 watch 运行映射为一个 load；下一次运行 cleanup 当前 controller。
// Side effects: 创建并取消 Fetch；stop/unmount 后不再允许提交。
watch(querySource, (query, _old, onCleanup) => {
  const handle = queryController.load(query)
  onCleanup(() => handle.abort('watch-invalidated'))
}, { immediate: true })

onUnmounted(() => queryController.dispose('component-unmounted'))
```

Composable 应在同步 `setup()` 中调用，使 watcher/lifecycle 能绑定当前组件实例。Vue 官方说明 composable 可以拥有副作用，但必须清理；SSR 中 DOM 特有副作用要放到浏览器挂载后。数据请求是否在 SSR、路由 loader 或客户端执行是更大的渲染决策，本章不擅自混合。

## 7. `finally` 如何腐蚀 loading

常见故障：

```ts
loading.value = true
try {
  data.value = await request(query)
} finally {
  loading.value = false
}
```

请求 A 开始后请求 B 开始，A 被取消并先进入 finally，于是把 B 的 loading 清掉。按钮可点击、spinner 消失，而 B 仍在运行。修复有两种主流方式：

1. 用 union，让 B 的 state 是 `loading(requestId=B)`；A finally 在 identity 不匹配时完全不写；
2. 若保留独立 loading，也必须 `if (requestId === currentRequestId) loading.value = false`。

第一种更容易排除矛盾。注意 success/error 分支已经把 state 改离 loading 后，finally 通常根本不必再写。把“清理资源”与“清 UI 状态”分开：controller 引用可以按 identity 释放，UI 则由确定的状态转换负责。

## 8. 一个可审计的 Composable

```ts
import { computed, onUnmounted, readonly, ref } from 'vue'

// Responsibility: 拥有单个工单查询的异步状态、身份、取消、重试和卸载清理。
// Data source: 调用者传入的规范化 Query 与注入 requestWorkOrders 适配器。
// Mapping: load→loading；最新成功→success；最新非 abort 失败→error；旧结果丢弃。
// Side effects: 创建 AbortController 并调用网络适配器；dispose 后永久禁止提交。
export function useWorkOrderQuery(requestWorkOrders: RequestWorkOrders) {
  const state = ref<AsyncState<WorkOrder[]>>({ tag: 'idle' })
  let currentId = 0
  let currentController: AbortController | null = null
  let lastQuery: Query | null = null
  let alive = true

  async function load(query: Query) {
    const requestId = ++currentId
    currentController?.abort('superseded')
    const controller = new AbortController()
    currentController = controller
    lastQuery = Object.freeze({ ...query })
    const previous = state.value.tag === 'success' ? state.value.data : undefined
    state.value = { tag: 'loading', requestId, query: lastQuery, previous }

    const mayCommit = () => alive && currentId === requestId && !controller.signal.aborted
    try {
      const data = await requestWorkOrders(lastQuery, controller.signal)
      if (mayCommit()) {
        state.value = { tag: 'success', requestId, query: lastQuery, data, receivedAt: Date.now() }
      }
    } catch (cause) {
      if (mayCommit()) {
        state.value = { tag: 'error', requestId, query: lastQuery, error: normalizeQueryError(cause), previous }
      }
    } finally {
      if (currentId === requestId && currentController === controller) currentController = null
    }
  }

  function retry() {
    if (lastQuery) return load(lastQuery)
    return Promise.resolve()
  }

  function cancel() {
    currentController?.abort('user-cancelled')
    currentId += 1
    currentController = null
    state.value = { tag: 'idle' }
  }

  function dispose() {
    alive = false
    currentId += 1
    currentController?.abort('component-unmounted')
    currentController = null
  }

  onUnmounted(dispose)
  return {
    state: readonly(state),
    isEmpty: computed(() => state.value.tag === 'success' && state.value.data.length === 0),
    load,
    retry,
    cancel,
  }
}
```

这是教学骨架，不是通用缓存库。`retry()` 复用最后规范化输入；重复调用会产生新 identity。取消后递增 identity，确保忽略 signal 的适配器也不能提交。dispose 不必在卸载后把 Vue 状态改 idle，因为界面已经销毁；关键是禁止后续写。

## 9. 状态视图：不要用真假值猜阶段

```vue
<script setup lang="ts">
import { toRef, watch } from 'vue'
import { useWorkOrderQuery } from './useWorkOrderQuery'

const props = defineProps<{ status: string; page: number }>()

// Responsibility: 将路由/父级查询输入连接到工单服务端状态视图。
// Data source: status/page Props 与注入的 API adapter。
// Mapping: 规范化 Query 触发 load，模板按 state.tag 穷尽渲染。
// Side effects: watch 会发可取消请求；Composable 在失效/卸载时清理。
const query = useWorkOrderQuery(requestWorkOrders)
watch(
  [toRef(props, 'status'), toRef(props, 'page')],
  ([status, page]) => query.load({ status, page }),
  { immediate: true },
)
</script>

<template>
  <p v-if="query.state.tag === 'idle'">尚未查询</p>
  <p v-else-if="query.state.tag === 'loading'" aria-live="polite">正在加载…</p>
  <section v-else-if="query.state.tag === 'error'" role="alert">
    <p>{{ query.state.error.message }}</p>
    <button type="button" @click="query.retry">重试</button>
  </section>
  <p v-else-if="query.isEmpty">没有符合条件的工单</p>
  <WorkOrderList v-else :orders="query.state.data" />
</template>
```

不能写 `v-if="data"` 代表 success：空数组为 truthy，而合法响应也可能是空；`null` 可能同时代表 idle/loading/error。模板依赖 discriminant 后，设计和测试可以直接对应状态矩阵。

## 10. Retry、refresh 与缓存边界

Retry 是对失败操作的新尝试，不是恢复旧 Promise。它应复制经过验证的 query，生成新 request id，重新进入 loading，并按策略限制次数/退避。GET 查询通常可安全重试，但真实接口语义仍由 HTTP 方法和后端合同决定；提交/支付等写操作不能盲目自动重试。

Refresh 表示已有 success 后重新验证。可以保留 `previous`，显示“内容可读、正在更新”；若 refresh 失败，可决定显示错误横幅并保留旧数据，或进入 error。无论选哪一种，都要在 union 和测试矩阵中明确，不能由模板随意组合 loading/data/error。

当多个页面需要 query-key 去重、stale time、后台 refetch、缓存回收、失焦重取、mutation invalidation 时，优先评估成熟 server-state/query library，而不是继续扩大全局 Pinia store。引入库是架构决策，需要版本、SSR、缓存与测试策略；本章先掌握底层不变量，资产不绑定具体库。

## 11. 用受控 Promise 测竞态

随机 `setTimeout(Math.random())` 会制造抖动，不会制造可复现实验。受控 transport 应保存每个请求的 resolve/reject，并让测试指定顺序：

```ts
// Responsibility: 让测试精确控制每个请求何时成功、失败或忽略 abort 后晚到。
// Data source: 测试传入的 query/requestId；不访问网络。
// Mapping: 每次 request 建一个可外部 settle 的槽位，并记录 signal。
// Side effects: 只创建 Promise 与 abort 监听；每个测试结束必须清空 pending。
function createControlledTransport() { /* deferred slots */ }
```

矩阵至少包含：

| 场景 | 完成顺序 | 期望最终状态 |
|---|---|---|
| success | A resolve 合法列表 | success(A,data) |
| empty | A resolve `[]` | success(A,[])，isEmpty=true |
| HTTP error | A reject `{kind:http,500}` | error(A,http) |
| parse error | A reject `{kind:parse}` | error(A,parse) |
| retry | A reject，retry B resolve | success(B)，B id>A |
| race | A start，B start，B resolve，A resolve | success(B)，A 无写入 |
| old finally | A start，B start，A reject，B pending | 仍 loading(B) |
| unmount | A start，dispose，A resolve | 无 post-dispose commit |
| cancel current | A start，cancel，A resolve | idle/合同指定状态 |

若 transport 遵守 abort，旧请求会 reject；还应增加一个故意忽略 abort 的槽位，证明 identity guard 独立成立。否则测试只证明 transport 取消，没有证明状态层抵御陈旧提交。

## 12. 故障诊断：首个可信证据

### 12.1 旧请求覆盖新结果

保存 query、requestId、start/abort/resolve/commit 轨迹。若 trace 显示 `resolve(41)` 后执行 `commit(41)`，而 current=42，首因是缺少提交身份检查；不要先改 spinner。修复所有 success/error 写点，再重跑 B→A 的相同 settle 顺序。

### 12.2 `finally` 无条件清 loading

固定 A start→B start→A reject→观察。若 B pending 时界面不再 loading，首个可信差异就是 A finally 的写入。让 loading 归属于 state/request id，或在 finally 验证 identity。不得通过延长 B timeout 隐藏。

### 12.3 卸载后继续更新

记录 component unmount/dispose、abort 与后续 settle。Vue 可能已停止 watcher，但手工创建的 Promise callback 仍可能运行；若 trace 有 post-dispose commit，检查 alive/identity guard 与 controller 所有权。修复后让 transport 忽略 abort 再 resolve，确保仍不提交。

### 12.4 错把 HTTP error 当 success

若 500 body 可解析而状态进入 success，首因位于 adapter 没检查 status，不在组件 v-if。用固定 response fixture 区分 HTTP、JSON parse 与 schema parse，然后重跑同一 error matrix。

### 12.5 服务器缓存与 Pinia 混淆

若切换 query 后仍显示旧数据且没有 query key，先画所有权表：筛选是客户端状态，工单列表是某 query 的服务器快照。修复不是“退出时清整个 Pinia”，而是给 server-state 层明确 key/identity/staleness；若需求已超出单 composable，评估专用缓存层。

## 13. 证据分层与真实运行边界

配套资产已验证的只包括：Node 环境中的状态 union 等价模型；成功、空、HTTP/解析错误；retry 生成新 identity；旧请求不能覆盖；旧 finally 不清新 loading；cancel/dispose 后忽略晚到；源码含职责、数据源、映射、副作用注释；公开夹具稳定失败。

未验证：真实 Vue `ref/computed/watch/onUnmounted` 调度；真实浏览器 AbortController 与 Fetch 异常；CORS、Cookie、代理、HTTP cache；真实后端是否停止请求；服务端日志和事务；Pinia/查询库集成；SSR/hydration；DOM/无障碍；弱网、离线和浏览器兼容。报告不得把离线 Promise 绿灯写成“网络竞态已在生产浏览器验证”。

## 14. 规范索引与版本表面

- [Vue Composables](https://vuejs.org/guide/reusability/composables.html)：Composable 定义、返回 refs、副作用与卸载清理。核验于 2026-07-17。
- [Vue Watchers](https://vuejs.org/guide/essentials/watchers.html)：watch/watchEffect、cleanup、`onWatcherCleanup` 3.5+ 同步注册约束。核验于 2026-07-17。
- [Pinia：组件外使用 Store](https://pinia.vuejs.org/core-concepts/outside-component-usage.html)：SPA 中 `app.use(pinia)` 后使用、Router guard 调用时序。核验于 2026-07-17。
- [WHATWG Fetch Standard](https://fetch.spec.whatwg.org/)：fetch、network error 与 abort 算法边界。核验于 2026-07-17。

本章 `stable_core: false`：Vue/Pinia/Vitest/Vite/TypeScript API 与工具输出会变化。稳定不变量是单一服务器事实所有权、互斥异步状态、每次请求身份、失效取消、提交前新鲜度检查和受控竞态测试。具体 cleanup API、测试工具和错误对象属于版本表面。

## 15. 最终检查表

- [ ] 服务器数据没有被当作无 query/时间/错误语义的普通 Pinia 字段。
- [ ] idle/loading/success/error 是可穷尽 union，空结果属于 success。
- [ ] 每次 load 有唯一身份、输入快照和 controller。
- [ ] success、error、finally 每个写点都受当前身份约束。
- [ ] 新输入与卸载都会 abort，且另有 latest guard。
- [ ] 我能解释 abort 不保证服务器撤销写操作。
- [ ] retry/refresh 的输入、previous data 和错误策略写进矩阵。
- [ ] 竞态测试由受控 Promise 决定顺序，不依赖随机 timeout。
- [ ] 测试含忽略 abort 的旧响应和 post-dispose 晚到。
- [ ] 首次失败、首因、修复和同一矩阵重跑可追溯。
- [ ] 真实网络、浏览器、Vue 与后端未验证项原样报告。
