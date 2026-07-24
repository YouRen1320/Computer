---
schema_version: 2
edition: 2026.2-draft
id: ch.vue.reactivity
title: ref、reactive、computed 与响应式边界
responsibility: 解释 ref/reactive 的依赖追踪、computed 缓存和解包边界，用派生状态替代重复可变状态，不在本章发起副作用。
volume: '09'
order: 4
level: L2
status: drafting
path: book/volume-09-vue-nuxt/chapters/ch.vue.reactivity.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.vue.vite-sfc
version_surfaces:
- vue-3
- vite
- typescript
- chrome-stable
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“ref、reactive、computed 与响应式边界”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - vue-reactive-sources
  - vue-computed-derived
  covers_topics:
  - vue.ref
  - vue.reactive
  - vue.ref-unwrapping
  - vue.destructuring-reactivity-loss
  - vue.computed
  - vue.computed-cache
  - vue.derived-vs-source-state
  - vue.readonly-reactive-boundary
  uses_capabilities:
  - web.javascript-language
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现工单列表的源状态与 computed 统计，并记录求值缓存和引用身份证据；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - vue-reactive-sources
  - vue-computed-derived
  covers_topics:
  - vue.ref
  - vue.reactive
  - vue.ref-unwrapping
  - vue.destructuring-reactivity-loss
  - vue.computed
  - vue.computed-cache
  - vue.derived-vs-source-state
  - vue.readonly-reactive-boundary
  uses_capabilities:
  - web.javascript-language
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: state-transition-table-render-count-observation-identity-check
- id: diagnose
  kind: fault-diagnosis
  text: 面对“解构 reactive、写入 computed 或复制派生状态导致的更新丢失与双源状态”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - vue-reactive-sources
  - vue-computed-derived
  covers_topics:
  - vue.ref
  - vue.reactive
  - vue.ref-unwrapping
  - vue.destructuring-reactivity-loss
  - vue.computed
  - vue.computed-cache
  - vue.derived-vs-source-state
  - vue.readonly-reactive-boundary
  uses_capabilities:
  - web.javascript-language
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# ref、reactive、computed 与响应式边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Vite、Vue 应用、SFC 与项目结构》](ch.vue.vite-sfc.md)：响应式 API 需要在可运行组件和 DevTools 中观察依赖更新。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文和验证工件可以用于学习与作者自检，但不代表学习者已经完成无 AI 独立构建、故障诊断或限时复述，也不会自动修改 `PROGRESS.md`。

一个 FactoryCare 页面可能保存工单数组、当前筛选条件和选中工单 ID，同时显示“开放工单数”“高优先级数”和筛选后的列表。最危险的做法不是少写一个 API，而是把每个显示结果都复制成另一份可变状态：数组改了却忘记改计数，筛选改了却忘记改列表，两个“真相”从此漂移。

Vue 响应式系统让代码声明“哪些值是来源、哪些值由来源计算”。`ref` 为一个值提供可追踪容器，`reactive` 为对象返回可追踪代理，`computed` 描述可缓存的派生值，`readonly` 限制某些调用者的写权限。它们不是数据库同步、网络请求调度或业务授权系统。本章刻意不使用 `watch`、生命周期、计时器、存储或 fetch；副作用由下一章讨论。

官方资料复核日为 **2026-07-17**。本文以 Vue 3 Composition API 为范围，使用稳定公开 API；配套工件锁定精确版本只为复现，不宣称补丁版本永久最新。

## 1. 完成标准：状态转换、求值次数与引用身份三类证据

完成本章不能只说“Vue 会自动更新”。需要留下三个相互独立的观察面：

1. **状态转换表**：给定初始 orders/filter，执行一次明确变更后，来源状态与 DOM 派生结果分别是什么。
2. **求值次数**：同一依赖版本连续读取 computed 时是否复用缓存；依赖改变后何时重新求值；未读取时是否保持惰性。
3. **引用身份**：原对象与 reactive 代理是否相同，`toRef` 前后是否保持到属性的活连接，解构出的原始值为什么不再更新。

三项 outcome 的证据要求是：

- 120 秒内解释 `ref`、`reactive`、解包、解构失联、computed 缓存、派生状态和只读边界，并举出一个不应由响应式方案解决的反例，例如服务端租户授权。
- 独立实现工单来源状态与 computed 统计，保存命令、输入、状态转换、求值计数、DOM 和身份断言。
- 注入解构 reactive、写入 computed 或复制派生状态故障，先定位第一可信证据，再修复并重跑同一 oracle，说明残余风险。

配套工件：

- [响应式缓存与身份观察例](../../../examples/encyclopedia/ch.vue.reactivity/README.md)
- [FactoryCare 工单统计实验](../../../labs/encyclopedia/ch.vue.reactivity/README.md)
- [公开重复派生状态红灯练习](../../../exercises/encyclopedia/ch.vue.reactivity/README.md)

公开练习的初始验证预期为红灯；私有解析只用于作者校验，不应复制给学习者。有效证据是同一输入、同一断言先失败后通过，而不是删掉失败断言。

## 2. 最小心智模型：读取建立依赖，写入使依赖失效

Vue 在一个响应式消费者（例如组件渲染或 computed getter）执行时，记录它读取了哪些响应式属性；这些属性被写入时，Vue使相关消费者失效并在合适时机重新运行。可把核心关系简化为：

```text
执行消费者
  └─ 读取响应式属性 → track(target, key, consumer)

写入响应式属性
  └─ trigger(target, key) → 使相关 computed 失效 / 安排组件更新
```

这是解释工具，不是公开实现承诺。Vue 3 对 reactive 对象使用 Proxy，对 ref 使用带 getter/setter 的容器；真正实现还处理集合、嵌套 effect、调度与许多优化。学习者需要抓住两点：只有在受追踪上下文中发生的响应式读取才成为依赖；改变未被读取的属性不会凭空让无关 computed 重算。

“响应式”也不等于“同步 DOM”。JavaScript 来源变更后，来源本身立即可读；组件 DOM 更新通常被批量安排到后续刷新。若测试刚写状态就读 DOM，应 `await nextTick()`。这个调度边界不能用 `setTimeout(100)` 猜测，否则机器快慢会改变证据。

## 3. `ref`：一个明确的可追踪槽位

Composition API 中，Vue 官方推荐用 `ref()` 声明响应式状态。它返回一个对象，JavaScript 中通过 `.value` 读取或写入：

```ts
import { ref } from 'vue'

const selectedOrderId = ref<string | null>(null)

selectedOrderId.value = '11111111-1111-4111-8111-111111111111'
console.log(selectedOrderId.value)
```

`.value` 不是多余语法，而是 Vue 能拦截读写、保持一个稳定容器身份的边界。把 `selectedOrderId.value` 传给只需要当前字符串的纯函数，会得到快照；把 ref 本身交给理解 ref 的代码，才保留后续连接。API 设计应明确究竟接收“此刻的值”还是“可持续更新的槽位”。

`ref` 可以持有基本类型、对象和数组。对象写入普通 ref 时通常会被深层转换为响应式对象；这对常见 UI 状态方便，但不意味着所有第三方类实例都适合深度代理。大型不可变数据、外部状态系统或需要保留原始身份的值可能需要 `shallowRef`/`markRaw`，但它们不在本章核心工件范围，不能在未测量前当作性能偏方。

### 3.1 模板解包与 JavaScript `.value`

模板为顶层 ref 提供便利解包：

```vue
<script setup lang="ts">
import { ref } from 'vue'
const openCount = ref(2)
</script>

<template>
  <p>开放：{{ openCount }}</p>
</template>
```

模板写 `openCount`，脚本仍写 `openCount.value`。不要把模板便利推广成“ref 到处都不需要 `.value`”。嵌套表达式、数组/集合中的 ref 有额外解包边界，见后文。类型检查和小型身份实验比凭记忆猜规则可靠。

## 4. `reactive`：对象的代理视图，不是原对象贴标签

`reactive()` 接收对象并返回 Proxy：

```ts
import { reactive } from 'vue'

const filter = reactive({
  status: 'ALL' as 'ALL' | 'CREATED' | 'CLOSED',
  query: '',
})

filter.status = 'CREATED'
```

读写属性不需要 `.value`，但关键身份事实是：代理通常不严格等于原对象。

```ts
const raw = { status: 'ALL' }
const proxy = reactive(raw)

console.log(proxy === raw) // false
console.log(reactive(raw) === proxy) // 同一个原对象再次转换通常得到同一代理
console.log(reactive(proxy) === proxy) // 已有代理保持代理身份
```

因此不要在一处保存 raw、另一处保存 proxy，再用引用相等作为同一工单的业务身份。FactoryCare 工单应使用稳定 `order.id` 作为身份；对象引用只说明内存对象关系。也不要直接继续修改 raw 并期待所有消费者按代理写入语义得到通知，应用代码应一致地使用代理。

`reactive` 只接受对象类型，不能直接把字符串、数字作为根值。它的代理身份也使“整体替换”容易断开原变量：

```ts
let filter = reactive({ status: 'ALL' })
filter = reactive({ status: 'CREATED' }) // 旧消费者仍可能连接旧代理
```

需要整体替换的单个值或数组常适合 `ref`；需要稳定对象身份并逐属性修改时适合 `reactive`。这不是绝对风格规则，关键是来源所有权与替换语义保持一致。

## 5. 深层响应与嵌套 ref 解包边界

常规 reactive 转换是深层的：访问嵌套对象会得到相应代理，嵌套写入能触发读取该路径的消费者。深层不代表“任何地方任意解构都保持连接”，也不代表遍历大型结构没有成本。

当 ref 是 reactive 对象的属性时，Vue 通常会自动解包，并把对该属性的赋值写回 ref：

```ts
const selectedId = ref('WO-1')
const state = reactive({ selectedId })

console.log(state.selectedId) // 'WO-1'，不是 ref 对象
state.selectedId = 'WO-2'
console.log(selectedId.value) // 'WO-2'
```

但是 reactive 数组或原生集合中的 ref 不做相同解包：

```ts
const cells = reactive([ref('WO-1')])
console.log(cells[0].value)
```

需要 `.value`。边界存在是为了避免集合元素和对象属性语义含混。团队代码若把 ref 深藏于多层结构，阅读成本会迅速上升；优先使用清晰、浅显的来源形状，而不是依赖所有人记住每种自动解包例外。

## 6. 解构为什么会失去属性连接

最经典的故障如下：

```ts
const filter = reactive({ status: 'ALL' })
const { status } = filter

filter.status = 'CREATED'
console.log(status) // 仍是 'ALL'
```

解构时发生了一次 `filter.status` 读取，得到普通字符串并赋给局部常量。之后读取 `status` 不再经过代理属性的 getter，所以 Vue 无从追踪这条连接。这不是 Proxy “失效”，也不是异步延迟，而是 JavaScript 值复制语义。

若需要保持属性连接，使用 `toRef` 或 `toRefs`：

```ts
import { toRef, toRefs } from 'vue'

const status = toRef(filter, 'status')
const { query } = toRefs(filter)

filter.status = 'CREATED'
console.log(status.value) // 'CREATED'
```

`toRef` 返回与源属性互相连接的 ref；它不是值副本。若只需把当前值传入纯函数，普通解构/读取完全合理。问题不在“禁止解构”，而在代码是否错误地把快照当成持续响应来源。

函数参数也有相同风险：`useSomething(filter.status)` 只传当前字符串，`useSomething(() => filter.status)` 或 `toRef(filter, 'status')` 才能让接收方在需要时读取最新值。具体选 getter 还是 ref 取决于 API 合同，不应仅为“看起来响应式”包一层。

## 7. `computed`：声明派生关系，而不是保存第二份真相

开放工单数完全由 orders 决定：

```ts
const orders = ref<WorkOrder[]>(initialOrders)

const openCount = computed(() =>
  orders.value.filter(order => order.status !== 'RESOLVED').length,
)
```

这里没有 `openCount.value++`。添加、删除或替换工单后，下次读取 `openCount.value` 会基于当前来源计算。代码审查时可问：如果所有来源状态已知，这个值是否能被完全重建？若能，它通常应是派生值，而不是独立可变来源。

派生状态可以返回数字、布尔、数组或对象：

```ts
const visibleOrders = computed(() => {
  const selected = filter.status
  return orders.value.filter(order =>
    selected === 'ALL' ? true : order.status === selected,
  )
})
```

computed getter 应保持纯：相同来源版本得到相同派生结果，不在里面发请求、写 localStorage、修改其他 ref、统计分析事件或改变 DOM。getter 可能被惰性执行、缓存、重复评估或因开发工具观察而读取；副作用放进去会让行为依赖“有没有人读它”。

## 8. computed 的惰性与缓存要用计数证明

computed 会跟踪 getter 读取的响应式依赖，并缓存结果。只要依赖未改变，多次读取同一 computed 返回缓存而不重新执行 getter；依赖改变时缓存失效，但通常直到下一次读取才重新求值。

可用纯观察计数建立证据：

```ts
let evaluations = 0

const openCount = computed(() => {
  evaluations += 1
  return orders.value.filter(order => order.status !== 'RESOLVED').length
})

console.log(evaluations)      // 0：尚未读取
console.log(openCount.value)  // 第一次结果，evaluations = 1
console.log(openCount.value)  // 缓存结果，仍为 1
orders.value.push(newOrder)   // 使依赖失效，未必立即执行 getter
console.log(evaluations)      // 仍为 1
console.log(openCount.value)  // 新结果，evaluations = 2
```

这个 `evaluations` 是测试探针，不应成为产品业务状态。若 getter 依赖 `Date.now()` 但没有响应式依赖，缓存不会随时间自动失效；若确实需要时间驱动更新，应由明确计时副作用更新一个响应式时钟来源，并由后续生命周期章节负责清理。

“computed 比方法快”过于粗糙。缓存只在重复读取且依赖不变时有价值，getter 本身仍应高效。是否优化大型过滤需要真实数据规模、渲染次数和性能分析；不能为了减少一次简单 `length` 读取而复制状态。

## 9. 只读 computed 与可写 computed 的边界

只传 getter 创建的 computed 是只读派生：

```ts
const openCount = computed(() => /* derive */)
// openCount.value = 99  // 类型/运行时都应拒绝这种所有权
```

看到“不能赋值”不是障碍，而是设计反馈：开放数没有独立写入语义。要改变它，必须改变某个工单状态或集合。直接把显示值设成 99 会让来源和派生矛盾。

Vue 支持带 `get`/`set` 的可写 computed，适合可逆投影，例如姓与名组合；setter 应把写入明确分解回来源。它不适合掩盖命令：“把 openCount 设成 3”究竟应该关闭哪几张工单没有唯一答案。FactoryCare 统计应保持只读。若需求是批量关闭工单，应设计一个有权限、确认、审计和失败处理的命令流程，而不是 computed setter。

本章诊断可故意尝试写只读 computed，记录 Vue 警告/类型错误与来源未变，再移除写入并改为合法来源操作。不要为了让测试不报错而给统计增加一个无业务语义的 setter。

## 10. 重复派生状态：最安静也最常见的双源故障

错误实现常这样开始：

```ts
const orders = ref(initialOrders)
const openCount = ref(
  orders.value.filter(order => order.status !== 'RESOLVED').length,
)

function addOrder(order: WorkOrder) {
  orders.value.push(order)
  // 忘记 openCount.value += 1
}
```

初始化时两者一致，happy path 截图完全正常。只要出现另一个修改入口——批量替换、状态转换、删除、服务端刷新——就可能忘记同步。给每个入口补赋值只扩大维护成本；根因是两个来源表达同一事实。

修复方向是删除可写计数，让 `computed` 从 orders 推导。验证器应先断言：初始 openCount=1；push 一个开放工单后 orders.length 与 openCount 同步；把某项改成 RESOLVED 后 openCount 下降；替换整个数组后仍正确。只有覆盖多种变化路径，才能证明没有隐藏同步入口。

并非所有看似派生的值都应 computed。用户尚未提交的表单草稿、分页游标、服务端返回的聚合统计可能有独立来源和一致性合同。若后端只返回 `totalCount` 而不返回全量记录，前端无法从当前页精确重建总数，就不能伪装成本地 computed。要先确认信息是否完备。

## 11. `readonly`：表达写入所有权，不是安全边界

`readonly()` 返回只读代理。消费者可以读取并继续获得响应式更新，但尝试写入会在开发环境警告并失败：

```ts
const source = reactive({ status: 'CREATED' })
const view = readonly(source)

source.status = 'RESOLVED' // 所有者合法更新
console.log(view.status)    // 'RESOLVED'

// view.status = 'CREATED'     // 消费者不应写
```

它适合让一个状态拥有者暴露查询视图，减少误写。TypeScript 的 `Readonly` 与运行时 `readonly()` 可以互补：前者提供静态反馈，后者在运行时代理拦截写入。只读通常是深层的；浅层边界另有 API，但需明确理由。

`readonly` 不是安全机制。攻击者能绕过前端代码，服务端仍须验证每个变更命令的认证、授权、租户与状态转换。它也不保证对象永远不变——原始所有者更新 source 后，readonly view 会反映新值。更准确的描述是“当前调用者没有写权限”，而不是“不可变快照”。

## 12. FactoryCare 来源与派生的推荐划分

以工单统计板为例：

| 值 | 建议形态 | 理由 |
|---|---|---|
| `orders` | `ref<WorkOrder[]>` | 页面拥有可整体替换的集合来源 |
| `filter.status`、`filter.query` | `reactive` 对象 | 一组稳定身份、逐属性更新的筛选来源 |
| `selectedOrderId` | `ref<string|null>` | 单个可替换来源 |
| `visibleOrders` | `computed` | 完全由 orders + filter 派生 |
| `openCount`、`criticalCount` | `computed` | 完全由 orders 派生，不能独立写 |
| `hasSelection` | `computed` | 由 selected ID 和当前集合派生 |
| API 加载状态/错误 | 后续副作用章节的来源 | 与请求生命周期有关，本章不实现 |

一个简洁模型可以返回只读统计和受控命令：

```ts
function createWorkOrderStats(initialOrders: WorkOrder[]) {
  const orders = ref([...initialOrders])
  const filter = reactive({ status: 'ALL' as StatusFilter })
  const visibleOrders = computed(() => filterOrders(orders.value, filter.status))
  const openCount = computed(() => countOpen(orders.value))

  function replaceOrders(next: WorkOrder[]) {
    orders.value = [...next]
  }

  function setStatusFilter(next: StatusFilter) {
    filter.status = next
  }

  return { orders: readonly(orders), filter: readonly(filter), visibleOrders, openCount,
    replaceOrders, setStatusFilter }
}
```

命令函数只是同步来源更新，不是本章所说的外部副作用。复制输入数组避免调用者随后直接 push 同一数组导致所有权含糊；是否需要更深不可变策略取决于项目规范和测量。

## 13. 状态转换表：每一步只改变一个来源

实验应预先写 oracle，例如：

| 步骤 | 操作 | orders 来源 | filter 来源 | computed 求值次数 | DOM 派生结果 |
|---|---|---|---|---:|---|
| 0 | 创建但未读统计 | 3 项 | ALL | 0 | 尚未挂载 |
| 1 | 首次读取 openCount | 3 项 | ALL | 1 | 开放 2 |
| 2 | 再读 openCount | 不变 | ALL | 1 | 开放 2 |
| 3 | push 一张开放单，不读 | 4 项 | ALL | 1 | 旧 DOM 等待刷新 |
| 4 | 读取/渲染 | 4 项 | ALL | 2 | 开放 3 |
| 5 | filter=RESOLVED | 4 项 | RESOLVED | openCount 不应因无关筛选重算 | 列表只显示完成项 |

实际 computed 可拆成多个 getter，分别记录 `openEvaluations` 与 `visibleEvaluations`，这样能证明依赖精度：只读取 orders 的开放计数不应因为 filter 改变而失效；读取 orders 与 filter 的可见列表应失效。若把整个 `filter` 序列化到 openCount getter 中，即使结果不用它也会建立多余依赖。

DOM 证据需等待 `nextTick()`，然后读取可访问文本或 `data-testid`。不要把 computed 求值次数和组件 render 次数混为一个数：一个渲染可能读多个 computed，一个 computed 也可能被其他消费者读取。分别命名和记录。

## 14. 三类故障的定位顺序

### 14.1 解构 reactive 后不更新

重现：`const { status } = filter`，修改 `filter.status`，显示仍用局部 `status`。第一可信证据是同一时刻 `filter.status === 'CREATED'` 而 `status === 'ALL'`；这已经证明分叉发生在解构，不必先怀疑渲染队列。修复为直接读 `filter.status` 或 `toRef(filter, 'status')`，再重跑初始和修改步骤。

### 14.2 写只读 computed

重现：尝试 `openCount.value = 9`。第一证据是类型诊断或运行时只读警告，同时 orders 未变。根因是把派生查询误当命令。修复不是增加 setter，而是调用有明确业务语义的来源更新；若根本不应更改统计，则删除写入。

### 14.3 复制派生状态

重现：`openCount` 用 ref 初始化，push 后忘记同步。第一证据是来源数组包含新增开放单而计数仍旧；DOM只是这个分叉的下游表现。修复为 computed 并删除所有手工同步入口。重跑 push、状态修改、删除和整体替换，确认没有残留双源。

诊断报告格式保持统一：输入与环境 → 预期转换表 → 实际 → 第一处偏离 → 根因 → 修复范围 → 原验证重跑 → 残余风险。不要用刷新页面、强制重新挂载或在断言前手工重算掩盖根因。

## 15. 调试工具与可靠证据层级

从便宜、确定的证据开始：

1. 直接记录来源值、派生值和 `typeof`，确认问题是否已在 JavaScript 层出现。
2. 用 `isRef`、`isReactive`、`isReadonly`、`toRaw` 做受控身份观察；`toRaw` 只用于临时诊断，不应作为绕过代理写入的常规通道。
3. 为 computed getter 增加测试期求值计数，记录首次读、重复读、依赖写、再次读。
4. 对组件等待 `nextTick()` 后观察 DOM，区分来源立即更新与渲染调度。
5. 使用 Vue DevTools 查看组件状态与更新；截图应配可复现步骤和版本，不单独作为 oracle。
6. 只有当功能正确但成本异常时，才做浏览器性能录制和 Vue 性能标记。

Vue 提供 `onTrack`/`onTrigger` 等开发调试钩子，可帮助确认依赖为何建立或触发，但它们用于开发诊断且受环境限制，不应把日志内容当跨版本产品合同。本章核心工件用公开可观察结果与计数，减少对内部事件格式的耦合。

## 16. 性能边界：先移除重复来源，再谈微优化

响应式性能问题可能来自巨大深层对象、高频无意义写入、每次渲染创建昂贵派生结果或组件边界不当。主流处理顺序是先测量，再缩小依赖/数据规模，然后考虑浅层 API、虚拟化、稳定 props 或架构调整。不要因为听说 Proxy 有成本就把所有状态改为普通对象并手工刷新。

computed 缓存不是免费数据库索引。若 `visibleOrders` 每次返回新数组，依赖改变后仍需完整过滤；一万项列表的主要成本可能是 DOM 渲染而非 getter。分页、服务端查询或列表虚拟化是另一层方案。本章只验证小型确定数据的语义，不据此宣称生产性能达标。

对象身份也影响更新优化。若每次无关事件都替换 orders 为全新但内容相同的数组，会使依赖失效；反过来，直接绕过响应式代理修改 raw 又可能没有更新。数据所有权、不可变策略与 API 响应归一化应由项目级架构决定，并用性能录制/测试证明。

## 17. 自动化验证策略

示例和实验应覆盖：

1. ref 在脚本中通过 `.value` 读写，类型与结果正确。
2. reactive 返回代理，raw/proxy 引用不同，重复转换身份稳定。
3. reactive 对象属性中的 ref 解包，数组中的 ref 仍需 `.value`。
4. computed 第一次读取求值、第二次复用；依赖写后惰性失效，再读才增加次数。
5. filter 变更只使真正读取 filter 的 computed 失效。
6. reactive 属性普通解构稳定复现旧快照，`toRef` 保持连接。
7. readonly view 随 source 更新，但消费者写入不改变 source。
8. 复制的开放计数出现漂移，computed 修复后 push/状态变更/替换都一致。
9. 组件挂载后来源变化，等待 `nextTick()`，DOM 统计和列表与转换表一致。
10. 工具链构建通过，测试与构建结果分开报告。

测试不要断言 Vue 内部 effect ID 或 Proxy 私有字段。求值计数必须来自 getter 自身，身份断言使用 `===` 与公开 utilities。捕获 readonly 警告时只匹配稳定意图，避免绑定完整措辞。Node 内存 DOM 能证明本章的派生文本，但不能证明视觉布局、真实浏览器调度细节或 DevTools 行为。

## 18. 实验路线

### 阶段 A：纯响应式观察

运行示例，记录环境。创建 orders ref 与 filter reactive，先不读 computed，记录计数 0；连续读两次，记录结果相同且计数 1；push 后先读计数再读值，证明失效惰性；记录 raw/proxy、对象属性解包和数组 ref 边界。

### 阶段 B：组件与 DOM

挂载 FactoryCare 统计组件。记录初始“总数/开放/严重”与列表；通过模型的同步命令添加或改变工单；等待 `nextTick()` 后保存 DOM。筛选只改变 visible 结果，不应改 openCount。不要引入 fetch 来提供数据，固定输入更适合本章 oracle。

### 阶段 C：故障注入

实验目录提供重复派生状态或解构快照故障。执行固定变化，保存来源与派生第一次分叉。一次只注入一种故障；若同时解构又复制计数，无法确定哪个是第一原因。

### 阶段 D：修复与回归

改用 computed 或 toRef，运行完全相同的转换表。回归不同修改路径，保存退出码和求值计数。最后明确：未连接真实 API、未测试大数据性能、未测试浏览器 DevTools、没有副作用清理证据。

## 19. 120 秒复述模板

可以这样组织：

> `ref` 是带 `.value` 的可追踪槽位，适合基本值和可整体替换来源；模板对顶层 ref 有便利解包。`reactive` 返回对象 Proxy，代理与 raw 身份不同，对象属性中的 ref 通常解包，但数组/集合元素仍需 `.value`。把 reactive 的基本属性解构出来只得到快照，后续读取不再经过代理；需要活连接时用 `toRef`。`computed` 是纯派生查询，惰性执行并按响应式依赖缓存，依赖未变的重复读取不重算，依赖写入后下次读取才重算。能从来源完全重建的统计不要复制成另一个 ref；只读边界表达写入所有权但不是安全授权。证据是状态转换表、getter 求值次数、raw/proxy/toRef 身份和 nextTick 后 DOM。反例：响应式只读不能代替服务端租户授权，也不负责网络取消。

如果无法解释“为什么解构字符串不再更新”“为什么 filter 改变不一定让 openCount 重算”“为什么 readonly view 仍会随 source 改变”，需要返回实验逐步观察。

## 20. 自检题

1. `.value` 为 ref 提供了什么可拦截边界？模板为什么能省略而脚本不能普遍省略？
2. `reactive(raw) === raw` 是否成立？业务身份为什么不应依赖 raw/proxy 引用？
3. 对象属性和数组元素中的 ref 解包有何差别？
4. `const { status } = reactiveState` 后，哪一次读取经过代理？
5. `toRef` 与把属性值传给 `ref()` 有何本质区别？
6. computed 在创建时、首次读取、重复读取、依赖写入、再次读取五个时点分别会发生什么？
7. 为什么 computed getter 内发送请求是危险的？
8. 哪些情况下服务端 totalCount 不应被前端 computed 重建？
9. readonly 为什么是所有权边界而不是安全边界？
10. DOM 未立即更新时，怎样区分调度边界与来源失联？

回答应引用自己的计数、身份断言和转换表。若只能背“ref 用基本类型、reactive 用对象”，仍不足以处理替换、解构和所有权问题。

## 21. 有意不做的事与下一章

本章不调用 API、不 watch 筛选、不写 localStorage、不启动定时器、不订阅 WebSocket，也不讨论卸载清理。这样才能让来源—派生—DOM 的因果链保持确定。下一章会在已经理解响应式来源后，引入 `watch`、`watchEffect`、生命周期和副作用清理；届时网络、计时器和订阅必须有明确所有者与取消证据。

本章也不做状态管理库选型。Pinia 等库仍建立在来源、派生和动作边界之上；在组件内还无法辨别双源状态时，换库只会把故障移到更远的位置。

### 官方资料

- [Vue：Reactivity Fundamentals](https://vuejs.org/guide/essentials/reactivity-fundamentals.html)
- [Vue：Computed Properties](https://vuejs.org/guide/essentials/computed.html)
- [Vue：Reactivity in Depth](https://vuejs.org/guide/extras/reactivity-in-depth.html)
- [Vue：Reactivity API: Core](https://vuejs.org/api/reactivity-core.html)
- [Vue：Reactivity API: Utilities](https://vuejs.org/api/reactivity-utilities.html)
- [Vue：Performance Best Practices](https://vuejs.org/guide/best-practices/performance.html)

### 本地规范依据

- `curriculum/chapters/volume-09.yml` 中本章责任、主题、G4 验收、oracle 和三项 outcome
- FactoryCare 工单域的稳定 ID、状态与优先级字段，仅作为固定输入，不在本章执行服务端操作

官方资料说明框架合同，配套工件验证受控版本和固定输入中的现象。它们不共同推出生产性能、跨版本内部实现、服务器授权或真实浏览器端到端行为；未测试的结论必须继续标注未验证。
