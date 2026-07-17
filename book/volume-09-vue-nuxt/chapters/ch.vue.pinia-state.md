---
schema_version: 2
edition: 2026.2-draft
id: ch.vue.pinia-state
title: Pinia 与客户端状态所有权
responsibility: 用 Pinia 管理真正跨组件的客户端状态，明确本地状态、派生状态和服务端状态的所有权，不把所有 ref 都搬进 store。
volume: '09'
order: 9
level: L2
status: drafting
path: book/volume-09-vue-nuxt/chapters/ch.vue.pinia-state.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.vue.components-contracts
version_surfaces:
- vue-3
- pinia
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
  text: 在 120 秒内解释“Pinia 与客户端状态所有权”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - vue-pinia-store
  - vue-state-ownership
  covers_topics:
  - pinia.define-store
  - pinia.state-getter-action
  - pinia.store-to-refs
  - pinia.store-instance
  - vue.local-vs-global-state
  - vue.derived-state-owner
  - vue.server-state-boundary
  - vue.store-reset-dispose
  uses_capabilities:
  - web.vue-components-contracts
  - web.vue-reactivity-lifecycle
  - web.vue-client-state
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“Pinia 与客户端状态所有权”构建可运行程序与测试：为筛选条件与会话偏好建立 Pinia store，并保留表单草稿为本地状态；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - vue-pinia-store
  - vue-state-ownership
  covers_topics:
  - pinia.define-store
  - pinia.state-getter-action
  - pinia.store-to-refs
  - pinia.store-instance
  - vue.local-vs-global-state
  - vue.derived-state-owner
  - vue.server-state-boundary
  - vue.store-reset-dispose
  uses_capabilities:
  - web.vue-components-contracts
  - web.vue-reactivity-lifecycle
  - web.vue-client-state
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: state-owner-table-multi-component-sync-store-reset-check
- id: diagnose
  kind: fault-diagnosis
  text: 面对“双源状态、解构丢响应性或 store 未重置导致的跨会话污染”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - vue-pinia-store
  - vue-state-ownership
  covers_topics:
  - pinia.define-store
  - pinia.state-getter-action
  - pinia.store-to-refs
  - pinia.store-instance
  - vue.local-vs-global-state
  - vue.derived-state-owner
  - vue.server-state-boundary
  - vue.store-reset-dispose
  uses_capabilities:
  - web.vue-components-contracts
  - web.vue-reactivity-lifecycle
  - web.vue-client-state
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# Pinia 与客户端状态所有权

> 本章解决的不是“怎样把所有变量放进 Pinia”，而是“谁应当拥有一份状态”。只有在多个组件或页面确实需要共同读取、修改并遵守同一套生命周期规则时，Pinia 才是合适的所有者。

## 1. 先从问题开始：共享不等于全局

一个 Vue 组件通常同时接触四类数据：表单输入、界面偏好、跨页面会话信息和从服务器读取的业务记录。它们看起来都是变量，却不应放在同一个地方。

以 FactoryCare 调度端为例：

- “派单备注输入框当前写了什么”只属于当前表单，离开表单就可以销毁；
- “工单列表选择了哪个状态筛选、采用表格还是卡片布局”需要被筛选条、列表和分页组件共同读取；
- “当前登录成员的租户、角色和数据范围”会影响许多页面，并且必须在退出登录时清空；
- “服务器返回的第 3 页工单及其更新时间”来自远端事实，具有加载、错误、缓存和重新验证语义；
- “当前筛选条件下有几个激活项”可以由现有数据计算，不应维护第二份可写副本。

如果把上述内容全部塞进一个 `useAppStore`，短期会觉得“任何地方都能拿到”，长期却会出现五个问题：状态由谁修改不明确、组件之间形成隐藏依赖、退出后残留上一位用户的数据、远端缓存与界面偏好混在一起、派生值和原值发生不一致。Pinia 只负责提供可靠的客户端共享状态机制，不能替代状态边界设计。

本章使用一条贯穿始终的判断：

> 一份状态应有一个权威所有者；其他位置要么通过合同读取，要么发出修改意图，要么从权威状态派生。

## 2. 状态所有权表

写 store 之前，先建立状态所有权表。表不是文档负担，而是避免“双源状态”的最便宜证据。

| 状态 | 权威来源 | 生命周期 | 写入者 | 推荐位置 |
| --- | --- | --- | --- | --- |
| 报修描述草稿 | 当前表单 | 组件挂载到提交/离开 | 表单组件 | 本地 `ref` |
| 列表状态筛选 | 当前浏览器会话 | 跨筛选条、列表和分页 | store action | Pinia |
| 紧凑布局偏好 | 当前成员或设备 | 跨页面，可选持久化 | store action | Pinia，持久化为适配器 |
| 当前成员身份摘要 | 登录会话 | 登录到退出/失效 | 身份流程 | 独立会话 store |
| 工单详情 | Java API | 由服务器版本决定 | 请求/缓存层 | 服务端状态层 |
| 激活筛选数量 | 已有筛选集合 | 随依赖自动变化 | 无独立写入者 | getter/computed |
| 弹窗是否展开 | 当前弹窗 | 打开到关闭 | 弹窗组件 | 本地 `ref` |

判断时依次问：

1. 页面刷新或组件卸载后，它还需要存在吗？
2. 是否有两个以上彼此独立的消费者？
3. 它是不是从已有状态确定计算出来的？
4. 权威事实在浏览器还是服务器？
5. 登录成员、租户或工作空间切换时是否必须重置？
6. 谁被允许修改，修改是否需要统一校验和副作用？

“多个组件会用到”只是候选条件，不是充分条件。父组件和两个直接子组件共享的数据，通常先提升到父组件，通过 props 和事件维持显式合同；跨远距离分支、跨路由页面或需要统一会话生命周期时，再考虑 Pinia。

## 3. Pinia 的两个层次：定义与实例

Pinia 的核心入口是 `defineStore()`。它创建的是一个 `useXxxStore` 函数，而不是立即创建全局对象。真正的 store 实例与当前 Pinia 实例关联：

```ts
import { createPinia, defineStore } from 'pinia'

export const useWorkOrderViewStore = defineStore('work-order-view', {
  state: () => ({
    statuses: [] as string[],
    compact: false,
  }),
})

const pinia = createPinia()
const viewStore = useWorkOrderViewStore(pinia)
```

这里有三个不同概念：

- `'work-order-view'` 是 store 的稳定且唯一标识；
- `useWorkOrderViewStore` 是定义产生的取用函数；
- `viewStore` 是某个 Pinia 容器中的具体实例。

同一 Pinia 实例内重复调用 `useWorkOrderViewStore()`，拿到的是同一个逻辑 store，因此两个组件能够同步。两个不同 Pinia 实例则拥有隔离状态，这对单元测试、多个应用根节点和 SSR 请求隔离都很重要。不要把“模块只加载一次”误认为 Pinia 的全部隔离机制。

Vue 应用通常在入口安装一次：

```ts
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'

const app = createApp(App)
app.use(createPinia())
app.mount('#app')
```

组件 `setup` 内调用 store 时会取得应用提供的 Pinia。组件外调用则必须确保 Pinia 已经安装或显式传入，不能依赖偶然的导入顺序。

## 4. Option Store：state、getter 与 action

Option Store 的结构适合第一次学习：`state` 类似组件数据，`getters` 类似计算属性，`actions` 类似方法。

```ts
import { defineStore } from 'pinia'

type StatusFilter = 'ASSIGNED' | 'ACCEPTED' | 'IN_PROGRESS'

export const useWorkOrderViewStore = defineStore('work-order-view', {
  state: () => ({
    statuses: [] as StatusFilter[],
    compact: false,
    assigneeId: null as number | null,
  }),
  getters: {
    activeFilterCount: (state) =>
      state.statuses.length + Number(state.assigneeId !== null),
    hasFilters(): boolean {
      return this.activeFilterCount > 0
    },
  },
  actions: {
    setStatuses(statuses: StatusFilter[]) {
      this.statuses = [...new Set(statuses)]
    },
    setAssignee(assigneeId: number | null) {
      this.assigneeId = assigneeId
    },
    toggleCompact() {
      this.compact = !this.compact
    },
    resetForSessionBoundary() {
      this.$reset()
    },
  },
})
```

### 4.1 state 是可写事实

`state` 必须由函数返回初始对象，使每个 Pinia 容器能得到自己的初始状态。所有会在运行中新增的顶层字段都应预先声明，这有利于类型推导、序列化、DevTools 和重置。

不要把可以确定计算的值放进 state：

```ts
// 不推荐：activeFilterCount 可能忘记同步
state: () => ({ statuses: [], assigneeId: null, activeFilterCount: 0 })
```

一旦 `statuses` 修改而 `activeFilterCount` 未修改，系统就出现两个互相矛盾的事实。派生值应由 getter 表达。

### 4.2 getter 是派生视图

getter 应尽量保持纯计算：同样的 state 产生同样的结果，不发请求、不写 localStorage、不修改其他 store。它的职责是回答问题，而不是发起流程。

需要参数时，可以让 getter 返回函数，但这类调用结果不具备普通 getter 相同的缓存特征。列表过滤规模较大时，应先测量，再决定是否建立索引或将工作移到服务端，不能仅凭“getter 看起来慢”就复制一份状态。

### 4.3 action 是修改意图和流程边界

action 不只是把赋值包装一层。它适合承载命名明确的用户意图、输入归一化、多个字段的原子修改以及必要副作用。例如 `setStatuses()` 去重，比让每个组件直接拼数组更可靠。

Pinia 允许 action 异步执行，但“可以请求接口”不代表“所有服务端状态都应永久放进 store”。请求结果是否需要缓存、何时过期、切换参数时如何取消、失败后如何重试，属于服务端状态策略。本章只把 action 当作流程入口，下一章会单独处理服务端状态。

## 5. Setup Store：组合式表达，不是另一种所有权规则

Setup Store 使用 `ref`、`computed` 和普通函数：

```ts
import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

export const useWorkOrderViewStore = defineStore('work-order-view', () => {
  const statuses = ref<string[]>([])
  const compact = ref(false)
  const assigneeId = ref<number | null>(null)

  const activeFilterCount = computed(
    () => statuses.value.length + Number(assigneeId.value !== null),
  )

  function setStatuses(next: string[]) {
    statuses.value = [...new Set(next)]
  }

  function resetForSessionBoundary() {
    statuses.value = []
    compact.value = false
    assigneeId.value = null
  }

  return {
    statuses,
    compact,
    assigneeId,
    activeFilterCount,
    setStatuses,
    resetForSessionBoundary,
  }
})
```

Setup Store 适合复用组合式逻辑和精确控制依赖，但要注意：需要被 Pinia 识别为状态的属性必须返回。隐藏一个可写 ref，既可能破坏 SSR/DevTools/插件能力，也会让状态合同不完整。

Option 和 Setup 不是“初级与高级”的关系。团队应选择一种主要风格并保持一致；真正重要的是 state、派生值、修改入口和生命周期是否清楚。

## 6. `storeToRefs()`：为什么直接解构会失去响应性

store 对象是响应式代理。下面的普通解构读取的是当时的值：

```ts
const store = useWorkOrderViewStore()
const { compact, activeFilterCount } = store // 不要这样提取响应式字段
```

之后 store 更新，局部变量不一定继续跟踪。正确方式是：

```ts
import { storeToRefs } from 'pinia'

const store = useWorkOrderViewStore()
const { compact, activeFilterCount } = storeToRefs(store)
const { toggleCompact } = store
```

`storeToRefs()`把 state、getter 和插件添加的响应式属性转成 refs，同时忽略 action 和非响应式属性。因此响应式数据用 `storeToRefs()`，方法直接从 store 取得。模板会自动解包 ref；脚本中读写仍需 `.value`。

另一个可接受方案是不解构：模板直接写 `store.compact`。这往往最清楚，尤其当组件只使用少量字段时。

## 7. 保留本地表单草稿

下面的筛选表单故意同时使用本地草稿和共享 store：

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { storeToRefs } from 'pinia'
import { useWorkOrderViewStore } from '@/stores/work-order-view'

const viewStore = useWorkOrderViewStore()
const { statuses } = storeToRefs(viewStore)

// 草稿只服务当前表单；用户确认前不污染跨组件共享筛选。
const draftStatuses = ref([...statuses.value])

function applyFilters() {
  viewStore.setStatuses(draftStatuses.value)
}

function cancelEditing() {
  draftStatuses.value = [...statuses.value]
}
</script>
```

这里并非“双源状态”，因为二者语义不同：`draftStatuses` 是尚未提交的编辑草稿，store 中的 `statuses` 是已经生效的筛选。只要定义清楚提交和取消边界，就有两个合法所有者。

真正的双源问题是让组件复制 store 值后持续双向同步，并把两边都当作“当前生效筛选”。此时任何遗漏、异步时序或 watcher 环路都会造成不一致。若不需要提交/取消语义，直接绑定唯一 store 状态即可；若需要草稿，就显式命名为 draft，并定义进入、提交、取消、离开四个时刻。

## 8. 多组件同步的证据

Pinia 的价值不是“无需 props”，而是多个远距离消费者观察同一个 store 实例。验证应覆盖行为链，而不是只断言某个字段存在：

1. 创建新的 Pinia 实例，避免测试相互污染；
2. 组件 A 调用 `setStatuses(['ASSIGNED'])`；
3. 组件 B 观察到相同筛选；
4. getter 变为 `1`；
5. 再设置 assignee，getter 变为 `2`；
6. 执行会话重置，两个组件都回到初始值；
7. 新建第二个 Pinia，确认它没有继承第一个实例的数据。

只在一个组件里点击按钮并看到数字变化，无法证明实例隔离和重置边界。只测试 store 方法，也无法证明组件错误解构后的响应性。测试应根据风险选择层级：纯 store 测 state/getter/action，组件测试测 `storeToRefs` 与渲染，端到端测试测路由和登录边界。

## 9. 服务端状态不是普通全局变量

工单列表来自 Java 服务。它至少包含：查询参数、加载状态、错误、数据、分页、服务端版本或更新时间、缓存失效和并发请求处理。把 `items` 放进 Pinia 不会自动解决这些问题。

建议区分：

- Pinia 保存客户端决定的筛选、布局和会话偏好；
- 请求层或专门的服务端状态工具保存远端响应及其缓存元数据；
- URL 保存需要分享、刷新和前进后退的查询条件；
- Java 数据库仍是工单事实的最终权威来源。

同一个筛选条件也可能有多个合适所有者。若用户复制链接后必须还原筛选，URL 应是权威来源，Pinia 只能作为派生镜像或根本不保存；若只是当前会话偏好且不希望暴露在 URL，Pinia 更合适。不要同时让 URL watcher 写 store、store watcher 写 URL，却没有防环路和初始化顺序。

Pinia store 中可以调用 repository，但要写明边界：store 是协调者，repository 才负责 HTTP；错误对象要归一化；旧请求不能覆盖新筛选结果；退出时要清理敏感缓存。下一章将专门练习这些内容。

## 10. 重置、释放与会话边界

### 10.1 `$reset()` 不等于完整退出登录

Option Store 提供 `$reset()`，它会用 `state()`的初始结果替换当前 state。Setup Store 需要自行实现重置 action。重置设计必须列出所有会话相关 store，不能只清空 token：

```ts
function clearSessionState() {
  useIdentityStore().$reset()
  useWorkOrderViewStore().$reset()
  usePermissionStore().$reset()
}
```

持久化插件、localStorage、IndexedDB、请求缓存和广播通道可能还保存数据，因此完整退出流程需要由会话编排器统一调用各适配器。不要假设 `$reset()`会自动清理浏览器所有副本。

### 10.2 `$dispose()` 与 `disposePinia()`

store 的 `$dispose()`会停止其作用域并从 Pinia 的 store 注册表移除，但不会自动清除 Pinia state 中的现有值；重新取用时仍可能看到保留状态，除非同时清理相应 state。`disposePinia()`用于释放整个 Pinia 实例，适合测试或一个应用实例的完整生命周期。具体清理语义属于版本表面，升级时应以当前官方 API 和测试为证据。

业务代码通常优先提供语义化的 `resetForSessionBoundary()`，而不是让每个组件自行决定 `$dispose()`。只有确实创建和销毁独立 store 实例的基础设施代码，才需要直接管理整个 Pinia 的释放。

### 10.3 订阅也有生命周期

`$subscribe()`、`$onAction()`、watcher、定时器和跨标签页监听器都可能产生副作用。组件内注册时应绑定组件作用域，组件外注册则保存取消函数并在会话或应用结束时执行。Pinia 不是内存泄漏的防护罩。

## 11. 持久化是适配器，不是默认能力

“刷新后仍存在”与“跨组件共享”是两件事。Pinia解决后者；前者需要持久化策略。

只有满足明确产品需求时才持久化，并逐项确定：

- 保存哪些字段，是否包含隐私或租户敏感信息；
- key 是否带用户、租户和 schema 版本；
- 数据迁移和无法解析时如何回退；
- 登录切换、租户切换和退出时如何删除；
- 多标签页冲突采用最后写入、版本比较还是禁止同步；
- 服务端权限变化后，旧本地偏好是否仍合法。

FactoryCare 可以保存“紧凑布局”和“每页条数”，但不应无审查地持久化完整成员权限、工单详情或报修人的联系方式。token 的存储方案属于身份与安全设计，不能因为 Pinia 插件方便就顺手写入 localStorage。

把持久化封装成适配器，并让 store action 只表达业务意图。测试时用内存适配器，浏览器实现再处理 Storage 异常、配额和跨标签页事件。

## 12. SSR 与实例隔离

在纯 SPA 中，一个应用一个 Pinia 很常见；在 SSR 中，模块顶层单例可能让一个请求的数据泄漏到另一个请求。正确方向是每个 SSR 请求创建独立应用和 Pinia，将序列化后的初始状态安全地传给客户端再水合。

本章不会把 Nuxt 细节提前塞进来，只保留三个不可违反的原则：

1. 不把包含用户数据的可写响应式单例放在模块顶层供所有请求共享；
2. 服务端为每个请求建立隔离上下文；
3. 序列化到 HTML 的状态必须防止注入，并只包含客户端确实需要的数据。

Nuxt 集成、水合错位和服务端/客户端执行边界会在本卷最后一章单独展开。

## 13. 三类典型故障的诊断

### 13.1 双源状态

**现象**：筛选条显示 `ASSIGNED`，列表请求却仍使用 `IN_PROGRESS`。

**首个可信证据**：记录 URL、组件草稿、Pinia state 和最终请求参数，找出第一个发生分叉的位置。不要先猜后端缓存。

**常见原因**：组件复制 store 值后把副本也当权威；URL 与 store 双向 watcher 初始化顺序不确定；派生值被存入 state。

**修复**：建立所有权表，只保留一个已生效事实；草稿显式提交；派生值改 getter；URL 同步指定单向权威和初始化阶段。

### 13.2 解构丢响应性

**现象**：DevTools 中 store 已更新，模板局部字段不变。

**首个可信证据**：检查组件是否 `const { value } = store`，再用最小测试对比 `store.value`、普通解构和 `storeToRefs(store)`。

**修复**：响应式 state/getter 通过 `storeToRefs()`提取，action 直接解构；或始终通过 store 对象访问。

### 13.3 跨会话污染

**现象**：成员 B 登录后看到成员 A 的筛选、租户选择或缓存摘要。

**首个可信证据**：执行 A 登录→修改→退出→B 登录的确定序列，检查 Pinia、持久化存储、请求缓存和 URL 各层残留。

**修复**：定义单一会话结束编排器；为持久化 key 加作用域与版本；清理各相关 store 和缓存；添加跨会话回归测试。不能只在组件 `onUnmounted` 中重置，因为退出可能并不卸载所有布局组件。

## 14. 可复现实验

本章配套四类资产：

- `examples/encyclopedia/ch.vue.pinia-state/`：真实 Pinia 实例演示 state、getter、action、`storeToRefs()`和实例隔离；
- `labs/encyclopedia/ch.vue.pinia-state/`：状态所有权矩阵与三类故障注入；
- `exercises/encyclopedia/ch.vue.pinia-state/`：公开红灯起点，故意保留双源状态和缺失重置；
- `solutions-private/encyclopedia/ch.vue.pinia-state/`：私有参考修复，用同一判据验收。

建议按以下顺序执行：

```bash
cd examples/encyclopedia/ch.vue.pinia-state && ./verify.sh
cd ../../../labs/encyclopedia/ch.vue.pinia-state && ./verify.sh
cd ../../../exercises/encyclopedia/ch.vue.pinia-state && ./verify.sh
```

公开练习应先失败。你的任务不是修改验证器，而是修复 `src/state-model.mjs`，使所有状态具有唯一所有者、跨消费者同步，并在会话切换后无残留。修复后保存失败日志、修改说明和重跑结果。

### Lab 完成判据

1. 所有权表明确区分本地、跨组件、派生和服务端状态；
2. 两个消费者从同一 Pinia 实例观察同步更新；
3. 第二个 Pinia 实例与第一个隔离；
4. `storeToRefs()`提取值在 action 后更新；
5. 会话 reset 后状态恢复初始值；
6. 三个故障标记都能指向首个可信证据；
7. 示例和 lab 绿灯，公开练习在修复前按指定标记红灯。

## 15. 使用 AI 写 store 时的验收清单

AI 很容易生成一个“大而全”的 store，因为这减少了文件数量，却不等于架构合理。让 AI 实现之前先提供状态所有权表，并要求它回答：

- 为什么该状态必须跨组件共享？
- 为什么它不是 URL、组件本地状态或服务端缓存？
- 哪些是可写事实，哪些是 getter？
- 哪些 action 是修改意图，哪些副作用应交给 repository？
- 登录、退出、租户切换和测试结束时如何重置？
- 是否使用 `storeToRefs()`保持响应性？
- 新 Pinia 实例是否隔离？
- 哪条测试证明没有跨会话污染？

AI 生成代码后，不要只看类型检查。至少运行多实例、同步、重置和故障注入。若代码通过测试但所有权仍说不清，说明验证器覆盖不足，而不是设计已经正确。

## 16. 口述检查与独立构建

### 120 秒口述题

请不用背 API，解释：Pinia 的职责是什么；什么状态不该进入 store；state、getter、action 分别承担什么；为什么直接解构可能失去响应性；为什么退出登录必须有统一 reset；服务端状态为什么需要另一套生命周期证据。

一个合格反例是：“当前弹窗中的一次性备注草稿只有该组件使用，没有跨组件或跨路由需求，因此放在本地 `ref` 更清楚。”

### 独立构建题

从空目录实现一个工单视图偏好 store：

1. 支持状态集合、负责人筛选和紧凑布局；
2. 用 getter 计算激活筛选数量；
3. 让两个消费者同步观察修改；
4. 表单草稿保持本地，确认后才提交；
5. 会话重置后没有残留；
6. 新 Pinia 实例不继承旧实例；
7. 保存命令、环境、输入、失败、修复和输出。

不要复制私有答案。若使用 AI，只允许它解释错误或审查你已经写出的差异；你必须能逐行说明所有权和验证证据。

## 17. 版本表面与边界

本章在 2026-07-17 对照 Vue 与 Pinia 官方文档编写。稳定核心是单一状态所有者、派生状态不复制、显式修改入口、会话重置与实例隔离；版本表面包括 Pinia API 细节、DevTools 界面、SSR/Nuxt 集成和插件行为。升级时应先重跑配套验证，再核对官方迁移说明。

配套资产使用确定版本以保证复现，但它们证明的是 Pinia 客户端状态模型，不证明真实浏览器持久化、Nuxt SSR、后端权限、跨标签页同步或生产性能。那些能力需要各自章节和更高层验证。

## 18. 官方资料

- [Vue：状态管理](https://vuejs.org/guide/scaling-up/state-management.html)
- [Pinia：Getting Started](https://pinia.vuejs.org/getting-started.html)
- [Pinia：Defining a Store](https://pinia.vuejs.org/core-concepts/)
- [Pinia：State](https://pinia.vuejs.org/core-concepts/state.html)
- [Pinia：Getters](https://pinia.vuejs.org/core-concepts/getters.html)
- [Pinia：Actions](https://pinia.vuejs.org/core-concepts/actions.html)
- [Pinia：storeToRefs](https://pinia.vuejs.org/api/pinia/functions/storeToRefs.html)
- [Pinia：API](https://pinia.vuejs.org/api/pinia/)
- [Pinia：SSR](https://pinia.vuejs.org/ssr/)

## 19. 本章结论

Pinia 最重要的能力不是让变量“到处可用”，而是给真正共享的客户端状态一个可命名、可观察、可测试、可重置的唯一所有者。先划分本地状态、共享状态、派生状态和服务端状态，再选择 store；用 state 表达可写事实、getter 表达派生视图、action 表达修改意图；用 `storeToRefs()`维持提取后的响应性；用新 Pinia 实例、跨组件同步和会话 reset 证明边界。做到这些，Pinia 才是在减少复杂度，而不是把复杂度藏进全局对象。
