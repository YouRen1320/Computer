# Vue：组件、生命周期与 Composable

## 1. 组件是带明确输入、输出和内部责任的 UI 单元

一个组件通常包含：

- Props：父组件给的输入；
- Emits：子组件报告的事件；
- Slots：父组件提供的内容区域；
- 内部状态：只属于当前实例；
- 生命周期副作用：挂载、更新和卸载时的资源。

组件不是“把每 50 行模板切一个文件”。边界应围绕可命名责任，例如工单行、筛选面板、状态标签、编辑表单。

## 2. Props 是只读输入

```vue
<script setup lang="ts">
const props = defineProps<{
  order: WorkOrderSummary
  selected?: boolean
}>()
</script>
```

父组件：

```vue
<OrderRow :order="order" :selected="selectedId === order.id" />
```

子组件不应直接给 prop 重新赋值。数据所有权在父级，子级通过事件请求变化。

## 3. 对象 Prop 的嵌套内容仍可能被修改

Prop 只读主要防止重新绑定：

```ts
props.order = other // 不允许
```

但 JavaScript 对象引用共享，子组件仍可能写 `props.order.status = ...`。这会绕过父组件的数据流，通常应避免。

若要编辑，创建本地 draft；若要执行状态变化，emit 业务意图，让所有者处理。开发环境警告不能替代架构约束。

## 4. Prop 默认值必须避免跨实例共享可变对象

类型声明配合默认：

```ts
const props = withDefaults(defineProps<{
  filters?: FilterOptions
}>(), {
  filters: () => ({ statuses: [] }),
})
```

对象/数组默认通常通过工厂产生每个实例独立值。默认值不应隐藏昂贵请求或依赖另一个 prop 的复杂业务规则。

运行时校验只能检查部分类型，外部 API 数据应在进入组件前已验证。

## 5. Emits 是子组件向外报告事实或意图

```ts
const emit = defineEmits<{
  assign: [workOrderId: string]
  close: [workOrderId: string, reason: string]
}>()

function requestClose() {
  emit('close', props.order.id, reason.value)
}
```

父组件：

```vue
<OrderRow @close="closeOrder" />
```

事件不会像 DOM 事件那样自动穿过多层组件冒泡。需要跨多层共享的状态应重新判断所有权、provide/inject 或 store，而不是每层盲目转发几十个事件。

## 6. 事件名应表达发生了什么

```text
好：submit、close-requested、selection-change
弱：click、changeData、doThing
```

若组件就是通用按钮，click 合理；业务组件应报告业务含义，而不是泄漏内部哪个 DOM 被点击。

事件 payload 应小而稳定，避免把整个可变内部状态引用抛给外部。

## 7. 单向数据流让变化来源可追踪

```text
父状态 → props → 子组件呈现
子用户动作 → emit → 父处理 → 父状态变化 → 新 props
```

这条环让状态所有者清楚。若多个兄弟都修改同一对象、子组件再写 prop，问题出现时很难找到最后写入者。

单向不等于所有状态都放根组件；状态应放到最接近所有使用者的共同所有者。

## 8. 组件 v-model 是 prop + update 事件合同

概念上：

```vue
<FilterInput v-model="query" />
```

等价于父传 `modelValue`，子发 `update:modelValue`。现代 Vue 也提供 `defineModel` 简化声明，具体版本能力应按官方文档复核。

它适合真正的双向输入值，不应把保存 API、权限检查等副作用藏在 setter 中。

多个 model 应有清楚名称，如 `v-model:start`、`v-model:end`。

## 9. Slot 让父组件提供内容，子组件控制布局

```vue
<!-- Card.vue -->
<article class="card">
  <header><slot name="header" /></header>
  <div><slot /></div>
</article>
```

```vue
<Card>
  <template #header>工单 WO-42</template>
  <p>电机过热</p>
</Card>
```

Slot 内容在父组件作用域求值，可以访问父状态，不能直接访问子内部变量。

## 10. Scoped Slot 让子组件把有限数据交给内容模板

```vue
<slot name="row" :order="order" :selected="selected" />
```

父级：

```vue
<OrderList v-slot:row="{ order }">
  <strong>{{ order.title }}</strong>
</OrderList>
```

它适合无头组件、表格单元格定制等。Slot contract 过大时会让父级依赖子内部结构，应只暴露稳定最小数据。

## 11. Fallthrough Attributes 会落到组件根元素

未声明为 prop/emit 的 class、style、aria-*、监听器等通常会传到单根组件根节点。

这有利于可访问属性和样式组合，但多根组件或包装层可能需要显式控制 `inheritAttrs` 和 `useAttrs`。

组件要明确哪个真实交互元素接收 disabled、aria-label 和 click，不能让属性误落在无意义 div。

## 12. 生命周期描述组件实例从创建到销毁

简化流程：

```text
setup 执行
  → 首次渲染
  → DOM 挂载 onMounted
  → 响应式状态变化
  → DOM 更新 onUpdated
  → 卸载前/后 onBeforeUnmount / onUnmounted
```

每个组件实例有自己的状态和生命周期。条件 v-if 切换可能销毁并创建新实例，key 改变也可能重建。

## 13. setup 阶段适合建立状态和依赖，不适合直接操作 DOM

在 `<script setup>` 顶层：

- 声明 ref/computed；
- 定义事件函数；
- 调用 Composable；
- 建立 watch；
- 读取 props/inject。

此时 DOM 尚未挂载，浏览器专用库也可能在 SSR 环境不存在。DOM 操作放 onMounted 或更明确的指令/组件集成中。

## 14. onMounted 用于需要真实 DOM 或浏览器环境的副作用

```ts
onMounted(() => {
  titleInput.value?.focus()
})
```

还可初始化图表、ResizeObserver、第三方 editor。初始化多少资源，就要有相应卸载清理。

数据请求是否放 mounted 取决于应用架构；SSR/Nuxt 初始数据不应机械放 mounted，否则服务端没有内容且客户端才二次加载。

## 15. onUpdated 不是“任何变化后都做事”的入口

组件任一 DOM 更新后都会触发，若在其中无条件修改响应式状态，可能造成更新循环。

需要对一个具体状态反应时使用 watch；需要等待某次状态对应 DOM 完成时，在动作后 `await nextTick()`；需要观察尺寸时使用 ResizeObserver。

onUpdated 适合少量必须基于每次更新后 DOM 的集成行为。

## 16. onUnmounted 必须释放外部资源

```ts
let timer: number | undefined

onMounted(() => {
  timer = window.setInterval(refresh, 30_000)
})

onUnmounted(() => {
  if (timer !== undefined) clearInterval(timer)
})
```

还包括：

- document/window 监听器；
- Observer；
- WebSocket/SSE；
- 第三方实例；
- 防抖计时器；
- 未完成请求；
- 自建订阅。

未清理会造成重复调用、旧页面更新和内存保留。

## 17. computed 用于派生，watch 用于副作用

```ts
const total = computed(() => price.value * quantity.value)

watch(selectedId, id => {
  analytics.track('selection_changed', { id })
})
```

不要 watch 两个状态来同步第三个可计算状态。Watch 适合 URL、localStorage、网络、焦点等外部副作用。

如果副作用只由某个用户动作触发，直接放事件函数比 watch 一个中间 flag 更清楚。

## 18. watch 明确来源和新旧值

```ts
watch(
  () => props.order.id,
  (newId, oldId) => {
    // 对明确 ID 变化响应
  },
)
```

不能直接 `watch(props.order.id, ...)`，那会把当前普通值传入而不是响应式来源。可以 watch ref、reactive、getter 或数组。

深度 watch 会遍历嵌套结构，可能昂贵且新旧值引用相同；优先观察真正需要的字段。

## 19. watchEffect 自动跟踪同步执行中读取的依赖

```ts
watchEffect(() => {
  document.title = `${unreadCount.value} 条待处理`
})
```

它适合依赖和副作用紧密、逻辑简单的情况。依赖隐式，复杂逻辑更难审查；需要精确触发、新旧值或不立即执行时用 watch。

异步 watchEffect 只会跟踪第一个 await 前同步读取的依赖，避免依赖藏在异步深处。

## 20. Watcher 清理旧的异步工作

```ts
watch(query, async (value, _old, onCleanup) => {
  const controller = new AbortController()
  onCleanup(() => controller.abort())

  results.value = await search(value, controller.signal)
})
```

当 query 再变化时，旧请求取消，减少竞态。仍可用序列号保证只有最新结果拥有状态。

Vue 版本也提供相关清理 API；具体调用限制以当前官方文档为准。

## 21. flush 时机决定 watcher 相对 DOM 更新的位置

默认 watcher 通常在父更新后、当前组件 DOM 更新前执行。需要读取更新后 DOM 时可选择 post flush；必须同步触发的少数场景可用 sync，但会失去批量缓冲。

大多数业务不需改默认。遇到 DOM 时序问题先问是否应该用 nextTick、模板 ref 或 Observer，而不是随意切 flush。

## 22. Composable 把有状态逻辑组合成可复用函数

约定以 `use` 开头：

```ts
export function useWorkOrderSearch(api: WorkOrderApi) {
  const query = ref('')
  const results = ref<WorkOrderSummary[]>([])
  const status = ref<'idle' | 'loading' | 'error'>('idle')

  // watch、取消、清理等
  return { query, results, status }
}
```

Composable 复用的是响应式状态与生命周期逻辑，不是视觉模板。组件负责呈现，Composable 负责一种能力。

## 23. 每次调用 Composable 是否共享状态要明确

函数内创建 ref：每个调用者得到独立状态。

```ts
function useCounter() {
  const count = ref(0)
  return { count }
}
```

模块顶层创建 ref：所有调用者共享单例状态。

```ts
const sharedCount = ref(0)
function useSharedCounter() { return { count: sharedCount } }
```

共享不是自动错误，但 SSR 中模块单例可能跨请求泄露用户数据。全局业务状态更适合明确 Store/每请求实例。

## 24. Composable 输入要保持响应性合同

若调用者传 ref、getter 或普通值，API 应明确。可用 `toValue` 等工具统一读取，但是否 watch 仍要定义。

```ts
function useOrder(source: MaybeRefOrGetter<string>) {
  watchEffect(() => load(toValue(source)))
}
```

不要在函数入口立即解包成普通值后声称会响应变化。

## 25. Composable 返回 ref，调用者解构仍保持联系

```ts
const { query, results } = useWorkOrderSearch(api)
```

因为返回的是 ref，解构不会丢响应性。若返回 reactive 对象再直接解构其原始属性，则可能断开。

可返回只读 ref，配合命名动作修改，防止调用者绕过不变量：

```ts
return { orders: readonly(orders), refresh }
```

## 26. provide/inject 解决深层依赖传递

祖先：

```ts
provide(workOrderApiKey, api)
```

后代：

```ts
const api = inject(workOrderApiKey)
```

它适合主题、表单上下文、服务接口等树范围依赖，避免每层 props 透传。使用 Symbol + `InjectionKey<T>` 可保持类型。

Inject 会隐藏依赖来源，组件关键输入仍优先 props；全局可变业务状态不要全部塞 provide。

## 27. 依赖注入使 Composable 更容易替换外部服务

```text
组件/Composable 依赖 WorkOrderApi 接口
  → 应用入口提供真实 HTTP 实现
  → 组件测试提供内存实现
```

这比在每个 Composable 直接 import 一个全局 axios 单例更清楚地控制 base URL、认证、错误映射和测试。

但不要为纯格式化函数注入十层接口；只对真正外部边界使用。

## 28. Async Component 和 Suspense 是加载边界

```ts
const HeavyReport = defineAsyncComponent(() => import('./HeavyReport.vue'))
```

可按功能拆包，并配置 loading/error/timeout 行为。路由页面通常由 Router/Nuxt 管理懒加载。

`Suspense` 可协调异步依赖，但生态和稳定细节需按当前 Vue 文档查询。不要用异步组件把每个小图标拆成单独网络块。

## 29. Teleport 改变 DOM 落点，不改变组件关系

```vue
<Teleport to="body">
  <ModalDialog />
</Teleport>
```

适合弹窗避免祖先 overflow/z-index 影响。Props、emits、provide/inject 仍按 Vue 组件树工作。

无障碍焦点、背景 inert、关闭恢复和 SSR 落点仍需组件负责，Teleport 不自动完成模态对话框。

## 30. KeepAlive 缓存组件实例而不是普通卸载

路由/动态组件切换时，KeepAlive 可保留实例状态，触发 activated/deactivated 生命周期，而非每次 mounted/unmounted。

适合返回列表保留滚动和筛选，但会增加内存，并让计时器/订阅在 deactivated 时是否暂停成为新问题。不要全局缓存所有页面。

## 31. 组件边界的常见异味

- 子组件直接改 prop；
- 父组件通过 ref 调子组件大量内部方法；
- 一个组件同时负责请求、业务规则、表格、弹窗和路由；
- 每层都转发相同 20 个 props；
- Composable 模块顶层保存用户状态导致 SSR 泄露；
- watch 互相修改形成环；
- unmounted 不清理外部资源；
- Slot 暴露全部内部对象。

重构目标是让所有权和副作用边界更清楚，不追求组件数量最多。

## 32. 这篇的整体地图

```text
父状态 → Props → 子呈现
子动作 → Emits → 所有者修改
父内容 → Slots → 子布局

组件实例：setup → mounted → updated → unmounted
  → watcher 连接响应状态与外部副作用
  → cleanup 取消旧请求、监听和计时器
  → Composable 复用有状态逻辑
  → provide/inject 提供树范围依赖
```

必须掌握：prop 是只读输入但嵌套引用仍可误改；组件事件不自动跨层冒泡；computed 与 watch 职责不同；每个副作用都有清理；Composable 是否共享状态必须明确；SSR 中不能把用户状态放模块单例。

Renderless component、插件 API 和高级 effect scope 属于“需要时查询”。
