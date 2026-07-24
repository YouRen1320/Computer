---
schema_version: 2
edition: 2026.2-draft
id: ch.vue.effects-lifecycle
title: watch、effect、生命周期与副作用清理
responsibility: 在组件生命周期中安排 watch/watchEffect 和外部副作用，使用清理函数保证旧计时器、订阅和异步任务不再更新当前界面。
volume: '09'
order: 5
level: L2
status: drafting
path: book/volume-09-vue-nuxt/chapters/ch.vue.effects-lifecycle.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.vue.reactivity
- ch.vue.forms-vmodel
- ch.js.fetch-cancellation-race
version_surfaces:
- vue-3
- vite
- typescript
- browser
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“watch、effect、生命周期与副作用清理”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - vue-watch-effects
  - vue-component-lifecycle
  covers_topics:
  - vue.watch
  - vue.watch-effect
  - vue.watch-source
  - vue.flush-timing
  - vue.effect-cleanup
  - vue.on-mounted
  - vue.on-updated
  - vue.on-unmounted
  - vue.side-effect-owner
  - js.abort-controller-signal
  uses_capabilities:
  - web.vue-template
  - web.javascript-async-runtime
  - web.javascript-network-race
  - web.vue-reactivity-lifecycle
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现可切换筛选条件的副作用组件并记录 watch 触发、清理和卸载轨迹；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - vue-watch-effects
  - vue-component-lifecycle
  covers_topics:
  - vue.watch
  - vue.watch-effect
  - vue.watch-source
  - vue.flush-timing
  - vue.effect-cleanup
  - vue.on-mounted
  - vue.on-updated
  - vue.on-unmounted
  - vue.side-effect-owner
  - js.abort-controller-signal
  uses_capabilities:
  - web.vue-template
  - web.javascript-async-runtime
  - web.javascript-network-race
  - web.vue-reactivity-lifecycle
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: lifecycle-trace-cleanup-counter-stale-callback-injection
- id: diagnose
  kind: fault-diagnosis
  text: 面对“遗漏 cleanup、错误 watch 源或 flush 时机造成的重复订阅和陈旧更新”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - vue-watch-effects
  - vue-component-lifecycle
  covers_topics:
  - vue.watch
  - vue.watch-effect
  - vue.watch-source
  - vue.flush-timing
  - vue.effect-cleanup
  - vue.on-mounted
  - vue.on-updated
  - vue.on-unmounted
  - vue.side-effect-owner
  - js.abort-controller-signal
  uses_capabilities:
  - web.vue-template
  - web.javascript-async-runtime
  - web.javascript-network-race
  - web.vue-reactivity-lifecycle
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# watch、effect、生命周期与副作用清理

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《ref、reactive、computed 与响应式边界》](ch.vue.reactivity.md)：watch 源和 effect 依赖来自 ref/reactive/computed，必须先能区分源状态和派生状态。
- [《表单、v-model、修饰符与校验边界》](ch.vue.forms-vmodel.md)：生命周期副作用最终更新模板和表单状态，需有已验证的 Vue 模板合同。
- [《Fetch、AbortController、超时、重试与竞态》](../../volume-08-javascript-typescript/chapters/ch.js.fetch-cancellation-race.md)：生命周期 cleanup 独立使用 AbortController 取消请求，必须先掌握请求取消、竞态和陈旧响应防护。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文和配套工件可用于学习与作者自检，但不能证明学习者已经完成无 AI 独立构建、故障诊断或限时复述，也不会自动修改 `PROGRESS.md`。

上一章把来源状态与纯派生状态分开；本章只处理剩下的一类工作：状态变化后必须触碰组件外部世界的动作。FactoryCare 工单筛选改变后可能要发请求，挂载后可能订阅更新流，组件离开时必须取消计时器、事件监听和连接。它们共同的危险是：旧工作比新工作晚完成，或者组件已经不存在，回调仍写入当前界面。

`watch`、`watchEffect` 与生命周期钩子不是“让代码自动运行”的三种随意写法。每一个副作用都要回答：谁拥有资源、什么输入触发、何时开始、何时失效、怎样清理、结果提交前如何证明仍然新鲜、卸载后如何证明归零。本章贯穿的 oracle 是挂载、更新、依赖变化、清理与卸载的事件轨迹，而不是“最后列表看起来对”。

本章不教授组件 Props/emit/Slot、Composable、依赖注入、状态库或真实网络协议细节。配套工件以受控计时器模拟可取消请求，避免外网和服务器不确定性；`AbortController` 合同沿用 JavaScript 请求竞态前置章。官方资料复核日为 **2026-07-17**。

## 1. 完成标准：轨迹、计数和最终 DOM 同时成立

完成本章需要三类证据：

1. **触发轨迹**：记录 watch/effect 创建、输入值、开始编号、清理、完成/取消、DOM 更新与卸载的先后顺序。
2. **资源计数**：每个时点活动计时器、订阅、请求控制器有多少；依赖切换后旧资源归零，卸载后总数归零。
3. **最终结果**：只有最新筛选对应的结果进入状态与 DOM；旧回调即使被人为晚到，也不能覆盖新结果。

三项 outcome 的具体要求：

- 120 秒说明 watch/watchEffect 的来源差异、flush 时机、生命周期资源所有权和 cleanup，并给出不应由本章解决的反例，例如服务器授权不能靠卸载清理保证。
- 独立实现可切换筛选条件的副作用组件，对挂载、首次请求、快速切换、更新、卸载保存可复现轨迹。
- 注入遗漏 cleanup、错误 watch 源或错误 flush，先指出第一可信证据，再修复并用原输入重跑，说明真实网络/浏览器未覆盖风险。

配套工件：

- [副作用清理观察例](../../../examples/encyclopedia/ch.vue.effects-lifecycle/README.md)
- [FactoryCare 生命周期轨迹实验](../../../labs/encyclopedia/ch.vue.effects-lifecycle/README.md)
- [公开 cleanup 红灯练习](../../../exercises/encyclopedia/ch.vue.effects-lifecycle/README.md)

公开练习初始验证预期非零退出；私有解析只用于作者校验。删除陈旧回调用例、改短延迟让新请求总是后到或吞掉断言，都不构成修复。

## 2. 先分清纯派生与副作用

如果一个值能完全由响应式来源同步计算，它应优先是 `computed`：

```ts
const visibleOrders = computed(() =>
  orders.value.filter(order => filter.value === 'ALL' || order.status === filter.value),
)
```

不要用 watch 把 `visibleOrders` 复制到另一个 ref。那只会制造双源状态。副作用是无法仅靠返回值表达的外部动作，例如：

- 发送/取消请求；
- 启动/清除计时器；
- 添加/移除 DOM 或全局事件监听；
- 订阅/取消订阅服务器连接；
- 写存储、日志或遥测；
- 调用命令式第三方控件 API。

一个实用判断是：“删除这段代码后，来源与派生值是否仍然在内存里正确，只是外部世界没被同步？”若是，它多半是副作用。把副作用藏在 computed getter 里会让“有没有人读取”决定请求是否发送，也使缓存和重跑产生不可预测行为。

## 3. `watch`：显式声明被观察的来源

Composition API 的 `watch(source, callback, options)` 把依赖声明与回调内读取分离。合法 source 可以是 ref（包括 computed ref）、reactive 对象、getter，或这些来源组成的数组：

```ts
watch(filter, (next, previous, onCleanup) => {
  // 只在 filter 实际变化时执行；默认不是立即执行。
})

watch(
  () => query.status,
  (nextStatus) => { /* explicit effect */ },
)

watch([status, () => paging.page], ([nextStatus, nextPage]) => {
  // 两个明确输入组成一个请求键。
})
```

传 `query.status` 本身是错误来源：调用 `watch` 时它已经被求值为普通字符串。正确写法是 getter `() => query.status`。第一可信证据通常是来源改变但回调计数保持 0，而不是先怀疑网络。

`watch` 默认惰性：创建时不调用回调，来源改变后才调用。需要首屏加载时可用 `{ immediate: true }`，使同一回调承担首次和后续加载。`once: true` 是 Vue 3.4+ 的单次变化能力，但它不适合持续筛选。选项要表达业务时序，不能为了“少跑几次”随手加入。

### 3.1 深度观察不是默认保险

watch getter 默认比较返回值身份；对象内部变化不一定触发。直接 watch 一个 reactive 对象会隐式深度遍历，显式 `{ deep: true }` 也会遍历嵌套属性；Vue 3.5+ 还允许数字深度。深度 watch 在大型结构上可能昂贵，而且嵌套变更时 new/old 往往指向同一对象，不能当历史快照。

工单查询通常应观察稳定请求键，例如 `[status, page, pageSize]`，而不是深度观察整份页面状态。这样触发原因、日志和测试都更明确。需要前后快照时应显式复制必要字段，而不是假设 oldValue 自动深拷贝。

## 4. `watchEffect`：同步执行阶段自动收集依赖

`watchEffect` 立即执行 effect，并自动追踪它在同步执行期间读取的响应式值：

```ts
watchEffect((onCleanup) => {
  const current = filter.value
  const timer = window.setInterval(() => poll(current), 5000)
  onCleanup(() => window.clearInterval(timer))
})
```

它适合副作用与多个依赖天然写在一起、依赖列表不会因此变得隐晦的场景。`watch` 更适合需要 old/new、只在真实变化时运行、明确控制首次执行或精确审计请求键的场景。两者都能 cleanup，不是“简单用 effect，复杂用 watch”的大小关系。

异步 `watchEffect` 有关键边界：只自动追踪第一次 `await` 之前同步读取的响应式属性。若在 await 后才读 `filter.value`，变化可能不触发重跑。可靠做法是在同步段捕获请求键，然后开始异步工作：

```ts
watchEffect((onCleanup) => {
  const requestKey = filter.value
  const controller = new AbortController()
  onCleanup(() => controller.abort())

  void loadOrders(requestKey, controller.signal)
})
```

若依赖是否被追踪必须靠读者扫描异步函数才能判断，显式 `watch(filter, ...)` 通常更可审计。

## 5. cleanup 的两个触发点：失效与停止

watcher cleanup 不只在组件卸载时运行。更重要的时点是：来源再次变化、旧运行即将失效时。一个完整序列应类似：

```text
watch start run=1 filter=ALL
filter changes to CREATED
cleanup run=1 reason=invalidate
watch start run=2 filter=CREATED
run=2 resolves and commits CREATED
component unmounts
cleanup run=2 reason=stop
unmounted
```

如果只在 `onUnmounted` 取消“当前请求”，快速筛选时 run=1 与 run=2 会同时活动；run=1 晚到仍可能覆盖 run=2。cleanup 必须注册到每一次 watcher 运行，使旧运行在下一次开始前失效。

Composition API 有两种注册方式：

```ts
watch(filter, (next, _previous, onCleanup) => {
  const controller = new AbortController()
  onCleanup(() => controller.abort())
  void loadOrders(next, controller.signal)
})
```

以及 Vue 3.5+ 的 `onWatcherCleanup()`。后者必须在 watch/watchEffect 的同步执行阶段调用，不能跨过 await；回调参数 `onCleanup` 绑定到 watcher 实例，不受同一同步限制。为了让资源一创建就有清理，本章仍要求在首个 await 之前注册。

cleanup 应幂等：重复调用不会制造新错误；只释放本次运行拥有的资源，不误杀下一次运行。日志要带 run ID，不能只写“aborted”，否则无法证明取消了谁。

## 6. `AbortController`：取消传递与提交防线

每次异步运行创建自己的 controller，并把 `signal` 传到支持取消的 API：

```ts
watch(filter, async (next, _previous, onCleanup) => {
  const runId = ++latestRunId
  const controller = new AbortController()
  onCleanup(() => controller.abort())

  try {
    const result = await repository.list({ status: next, signal: controller.signal })
    if (controller.signal.aborted || runId !== latestRunId) return
    orders.value = result
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') return
    visibleError.value = '加载失败，请重试'
  }
}, { immediate: true })
```

取消是资源层防线，run ID/当前键检查是提交层防线。某些库或服务器在收到 abort 前已经完成，或者根本不支持 signal；仅调用 `abort()` 不等于永远不会有回调。提交前确认当前运行仍然拥有结果，能覆盖更多竞态。

AbortError 是预期控制流，不应显示成“加载失败”；真正网络/解析/权限错误需要可恢复提示。`finally` 中修改 `loading` 也要检查所有权：旧请求的 finally 若把新请求的 loading 设为 false，会让按钮过早恢复。可用活动 run ID 或活动计数维护准确状态。

本地实验用可取消计时器模拟 repository：signal abort 时 clearTimeout 并拒绝 AbortError。它能稳定控制完成顺序，却不能证明真实 fetch、代理、服务端取消或连接复用行为。

## 7. flush 时机：默认回调看到的是更新前的自身 DOM

状态写入可能同时触发组件渲染和 watcher。Vue 会批处理用户 watcher，避免同步 push 多次就回调同样多次。默认 watcher 回调在父组件更新之后、拥有者组件 DOM 更新之前运行；若此时读自己的 DOM，通常看到旧内容。

三个主要时机：

| 配置 | 相对时机 | 适用 | 风险 |
|---|---|---|---|
| 默认 `pre` | owner DOM 更新前 | 发请求、日志、与 DOM 无关的同步 | 误读旧 DOM |
| `flush: 'post'` | owner DOM 更新后 | 必须读取更新后的尺寸/文字 | 若本可声明式完成，则可能过度命令式 |
| `flush: 'sync'` | 响应式写入时同步 | 极少数简单布尔联动 | 无批处理，数组大量写入会高频触发 |

需要某一次状态写入后的 DOM，`await nextTick()` 往往比全局 `onUpdated` 更精确。需要持续在 DOM 更新后响应某来源，可用 post watcher/`watchPostEffect`。`sync` 不是“最快更好”，它会绕过批处理；配套测试只比较 pre 读到旧标签、post 读到新标签，不把毫秒时间作为合同。

## 8. `onMounted`：DOM/客户端资源的开始边界

Composition API 生命周期钩子必须在 setup 的同步调用栈中注册，Vue 才能关联当前组件实例：

```ts
const element = ref<HTMLElement | null>(null)

onMounted(() => {
  // 此时同步子组件已挂载，本组件 DOM 已创建。
  element.value?.focus()
})
```

不要在 `setTimeout` 或 await 后才调用 `onMounted()`；那时活动实例上下文可能已经消失。可以从 setup 同步调用的外部函数里注册，这正是后续 composable 能工作的基础，但本章不抽取 composable。

`onMounted` 不在服务端渲染期间调用。需要 DOM、window、ResizeObserver 的代码放到这里能避免服务器执行，但仍需考虑 hydration 和组件是否真正插入文档；根容器本身不在文档时，mounted 不会神奇修复它。

如果副作用只依赖响应式筛选并应立即加载，`watch(..., { immediate: true })` 往往比在 mounted 手动调用一次、watch 再调用一次更统一。`onMounted` 留给需要 DOM 或客户端存在性的资源。

## 9. `onUpdated`：观察更新，不要在里面制造更新循环

`onUpdated` 在组件因响应式变化完成 DOM 更新后调用。多个状态写入可能被批成一个渲染，因此不能把“每次业务操作”与“每次 updated”一一对应。父组件 updated 在子组件 updated 之后。

官方明确警告不要在 updated 中修改组件状态，否则很容易形成无限更新循环。日志探针也要谨慎：若 trace 本身是响应式数组，在 `onUpdated` 中 `trace.value.push()` 会触发下一次更新。配套工件用非响应式轨迹数组记录 hook，并通过测试暴露读取，避免观察器改变被观察对象。

业务若需要某字段变化后发请求，应 watch 该字段；若需要一次特定写入后的 DOM，用 nextTick；若需要第三方控件每次 DOM 更新后同步，才考虑 updated，并证明不会回写触发源。

## 10. `onUnmounted`：组件拥有资源的最终清点

组件卸载后，它的同步子组件已卸载，setup 中关联的 render effect、computed 和同步创建的 watchers 已停止。`onUnmounted` 用来清理手工创建的计时器、DOM listener、连接和其他外部资源：

```ts
let intervalId: number | undefined

onMounted(() => {
  intervalId = window.setInterval(refreshHeartbeat, 30_000)
})

onUnmounted(() => {
  if (intervalId !== undefined) window.clearInterval(intervalId)
})
```

同步在 setup 中创建的 watchers 会随组件自动停止，但 watcher 每次运行创建的资源仍要通过 onCleanup 取消；手工 DOM listener/第三方连接仍需 onUnmounted。两种清理层次不能互相替代。

异步回调里才创建 watcher 是危险例外：它不会自动绑定拥有者，必须保存 stop handle 并手动停止。通常更好的是同步创建 watcher，在数据未就绪时提前 return。这样组件卸载的所有权保持可证明。

## 11. 副作用所有权表

设计前写一张表：

| 资源 | 创建者 | 启动 | 失效清理 | 最终清理 | 提交防线 |
|---|---|---|---|---|---|
| 筛选请求 | FilterPanel watcher run | immediate/筛选改变 | onCleanup abort | watcher stop 会触发 cleanup | run ID + signal |
| 轮询 interval | FilterPanel | mounted | 不适用或配置改变时重建 | unmounted clearInterval | 组件 mounted 标志 |
| window resize listener | 拥有 DOM 的组件 | mounted | handler 变化时先移除 | unmounted removeEventListener | 无陈旧闭包 |
| WebSocket subscription | 页面组件/后续 composable | mounted/认证就绪 | topic 变化 unsubscribe | unmounted close/unsubscribe | subscription token |
| DOM 测量 | post watcher | 目标来源改变 | watcher 自动失效 | watcher stop | 读取当前 element |

“谁创建谁清理”比“找一个全局地方统一清理”更可维护。若资源跨多个组件共享，所有权已变成架构决策，应在后续 composable/DI/状态管理章明确引用计数或应用级生命周期，而不是让子组件随便 close 全局连接。

## 12. 生命周期与 UI 反馈是同一合同的两面

副作用时序必须在界面上可理解：

- 加载期间显示文字状态并适当设置 `aria-live="polite"`/`role="status"`，不能只旋转一个无名称图标。
- 需要防重复的按钮使用真实 `disabled`，同时保持为何不可操作的可见反馈；服务端幂等仍是独立边界。
- 错误用 `role="alert"` 或合适 live region，并提供“重试”操作，而不是永久红字。
- 空结果展示“当前筛选无工单”及清除筛选动作，不呈现空白区域。
- 快速筛选时不要让旧结果短暂闪回；cleanup 与提交防线既是正确性也是体验质量。
- 键盘可达、焦点环可见、按钮有文本名称；切换加载状态不能把焦点无故移走。

UI/UX 检索为本章工件选择了高对比、原生控件、状态文字、可恢复错误和明确 disabled 语义。自动测试只覆盖 DOM 文本、role/disabled 和结果顺序；真实焦点、读屏播报、触控尺寸、响应式布局仍需设备/人工验证。

## 13. 一条可审计的筛选请求实现

推荐把每次运行的局部资源都放进回调作用域：

```ts
let runSequence = 0
let latestRun = 0

watch(filter, async (next, _previous, onCleanup) => {
  const run = ++runSequence
  latestRun = run
  const controller = new AbortController()
  trace.push(`start:${run}:${next}`)

  onCleanup(() => {
    trace.push(`cleanup:${run}`)
    controller.abort()
  })

  loading.value = true
  error.value = null
  try {
    const result = await listOrders(next, controller.signal)
    if (run !== latestRun || controller.signal.aborted) return
    orders.value = result
    trace.push(`commit:${run}:${next}`)
  } catch (cause) {
    if (cause instanceof DOMException && cause.name === 'AbortError') {
      trace.push(`abort:${run}`)
      return
    }
    if (run === latestRun) error.value = '加载失败，请重试'
  } finally {
    if (run === latestRun) loading.value = false
  }
}, { immediate: true })
```

注意 cleanup 注册发生在异步开始前，结果和 loading 都检查 latestRun。trace 是非响应式测试轨迹，不能反过来驱动产品 UI。真实实现还应区分认证、权限、超时和离线错误，但不要在本章虚构 API 响应格式。

## 14. 标准状态转换 oracle

实验应先写预期：

| 步骤 | 操作 | 活动运行 | 必须新增的轨迹 | DOM |
|---|---|---|---|---|
| 0 | setup + immediate | run1/ALL | start1 | loading，暂无结果 |
| 1 | mount | run1 | mounted | loading |
| 2 | 改 CREATED | run2/CREATED | cleanup1 → start2 | 仍 loading |
| 3 | run2 完成 | 无活动网络 | commit2 → updated | 仅 CREATED 结果 |
| 4 | 人为让 run1 到期 | 无 | 不得 commit1 | 仍是 CREATED |
| 5 | 改 RESOLVED 后立即卸载 | run3 后归零 | start3 → cleanup3 → unmounted | 组件移除 |
| 6 | 推进全部计时器 | 0 | 不得新增 commit | 无卸载后写入 |

真实 Vue 可能因批处理产生不同数量的 updated，故 oracle 不应硬编码每一次内部 render；应断言关键偏序：清理在下一 start/旧 commit 之前，最新 commit 在对应 DOM 前后可解释，unmounted 后无业务 commit。对 hook 次数的断言要基于固定、单一状态写入。

## 15. 三类故障与第一可信证据

### 15.1 遗漏 cleanup

故障：快速从 ALL 切 CREATED，CREATED 先完成，ALL 后完成并覆盖。第一证据不是最终文字，而是 `start1, start2, commit2, commit1` 中缺少 cleanup1/abort1。修复后用相同延迟重跑，要求 commit1 不出现、活动计数归零。

### 15.2 错误 watch source

故障：`watch(query.status, ...)` 传入普通字符串。第一证据是 query.status 改变而 watcher run count 不变。修复为 getter后回调出现；不要改成 deep watch 整个 query 以掩盖来源错误。

### 15.3 flush 错位

故障：默认 watcher 里读取 label DOM，日志一直比状态落后一步。第一证据是同一回调中状态为 CREATED、DOM 仍为 ALL；修复为 post watcher 或针对该写入 `await nextTick()`。不要加任意 `setTimeout`，那只制造时间猜测。

### 15.4 卸载后更新

故障：timer/request 在 unmount 后 resolve 并写 ref。第一证据是 `unmounted` 之后仍出现 commit 或 activeResources>0。修复应释放实际资源并加提交防线，而不只是忽略 Vue 的警告。

诊断记录统一包含：环境与输入、预期轨迹、实际轨迹、第一偏离、资源所有者、修复、原命令重跑、残余风险。

## 16. 测试策略：控制时间，不等待运气

副作用测试应使用 fake timers、可控 Promise 或内存 repository，避免真实网络：

1. 创建组件后断言 immediate watch 的 start 和 loading 状态。
2. 快速切换来源，断言旧 cleanup 在新 run 提交前出现。
3. 分别推进新、旧延迟，断言只有最新结果提交。
4. 记录活动计时器/控制器数量，在切换与卸载后归零。
5. 比较默认 pre 与 post watcher 读到的 DOM 版本。
6. 触发一次同步批量写入，确认默认 watcher 批处理；不要把内部调度细节当永久合同。
7. 卸载后推进所有 timer/microtask，断言轨迹、状态和 DOM 没有新业务更新。
8. 构建 SFC，证明模板和生命周期 API 能由锁定工具链处理；构建通过不等于竞态通过。

每个 async 断言都要显式刷新微任务和 Vue `nextTick`。不能用“睡 100ms”换取偶然顺序。测试日志保留 run/filter，避免只比较计数而看不出取消了错误运行。

## 17. 实验路线

### 阶段 A：建立无竞态基线

运行示例验证器，记录 Node、pnpm、Vue、Vite、TypeScript、Vitest 与 Happy DOM 版本。只让 ALL 完成，保存 start/commit、loading/结果和 mounted/updated 轨迹。

### 阶段 B：快速切换

在 ALL 未完成时切 CREATED，让 CREATED 更快完成。先预测 cleanup/start/commit 顺序，再推进计时器。若旧结果进入 DOM，停止并记录第一偏离，不要先改延迟。

### 阶段 C：故障注入

实验目录提供遗漏 cleanup 的组件。用完全相同延迟证明 `commit:CREATED` 后又出现 `commit:ALL`。修复版注册 onCleanup 并检查 run 所有权；重跑同一 oracle。

### 阶段 D：卸载和 flush

开始一个未完成运行后卸载，推进全部计时器，确认无 commit。再观察 pre watcher 读旧 DOM、post watcher 读新 DOM。分别记录来源值与 DOM 文本。

### 阶段 E：边界说明

列出未验证：真实 fetch/服务端是否响应取消、移动浏览器、SSR/hydration、真实 WebSocket、后台标签页计时器节流、读屏加载播报。没有这些证据就只声称受控环境 cleanup 正确。

## 18. 120 秒复述模板

> computed 用于纯派生，watch/watchEffect 用于触碰外部世界。watch 显式声明 ref/getter/数组等来源，默认惰性；watchEffect 立即执行并只在同步阶段自动追踪，异步时 await 后的读取不成为依赖。每次运行创建自己的资源，并在首个 await 前用 onCleanup 或 Vue 3.5 的 onWatcherCleanup 注册失效清理；来源变化时旧运行先清理，卸载停止时再清理。AbortController 取消资源，run ID 防止不支持取消的旧结果提交。默认 watcher 在 owner DOM 更新前，post 在更新后，sync 无批处理需谨慎。生命周期钩子在 setup 同步注册；mounted 开始 DOM/客户端资源，updated 不写响应式状态，unmounted 清理计时器、监听和连接。证据是 start-cleanup-commit-unmount 轨迹、活动资源计数和最终 DOM；反例是服务端授权和幂等不能由 cleanup 解决。

若不能说明为什么只在 onUnmounted abort 不够、为什么旧 finally 会错误关闭新 loading、为什么 post watcher 不等于 nextTick 的所有场景，就还未掌握所有权。

## 19. 自检题

1. 哪类值应 computed 而不是 watch + ref？
2. 为什么 `watch(query.status, ...)` 不是有效属性来源？
3. watch 与 watchEffect 在首次执行、依赖声明和 oldValue 上有何差异？
4. async watchEffect 的哪些读取会被追踪？
5. cleanup 在来源失效和组件卸载时分别解决什么？
6. `onWatcherCleanup` 为什么必须同步注册？回调 `onCleanup` 有何差异？
7. abort 后为什么还建议 run ID/当前键检查？
8. 默认/pre、post、sync watcher 读 DOM 和批处理有何差别？
9. 为什么在 onUpdated 中 push 响应式 trace 可能形成循环？
10. 同步 setup watcher 和 setTimeout 中创建的 watcher，卸载所有权有何差异？
11. 如何证明卸载后没有陈旧更新，而不是“页面已经看不到”？
12. 哪些真实网络风险不在本地计时器实验覆盖范围？

答案应引用自己的轨迹和失败输出，不能只背 API 名称。

## 20. 有意不做与下一章

本章不把副作用抽成 composable，不使用 provide/inject，不引入状态库，也不设计组件公开合同。下一章会先建立 Props、emit、Slot 与组件 v-model 的单向数据流；再后一章才把具有明确输入、输出和清理所有权的逻辑提取为 composable。

本章也不声称 abort 等于服务器事务回滚。请求可能已到达服务端；写操作仍要使用 API 的幂等、并发控制和服务端状态机。前端清理的职责是停止无用工作、防止陈旧 UI 提交与释放客户端资源。

### 官方资料

- [Vue：Watchers](https://vuejs.org/guide/essentials/watchers.html)
- [Vue：Lifecycle Hooks](https://vuejs.org/guide/essentials/lifecycle.html)
- [Vue：Composition API Lifecycle Hooks](https://vuejs.org/api/composition-api-lifecycle.html)
- [Vue：Reactivity API Core](https://vuejs.org/api/reactivity-core.html)
- [MDN：AbortController](https://developer.mozilla.org/en-US/docs/Web/API/AbortController)

### 本地规范依据

- `curriculum/chapters/volume-09.yml` 中本章责任、主题、G4 验收、oracle 与 outcome
- FactoryCare 查询筛选只作为确定输入；真实端点、认证与服务端响应格式不在本章虚构

官方资料说明框架和平台合同；本地工件只验证锁定版本、受控计时器与内存 DOM。两者都不能单独证明生产无泄漏、真实网络取消、SSR 或辅助技术体验。
