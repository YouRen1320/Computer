# Vue：模板、表单与响应式

## 1. Vue 把状态映射成界面

普通 DOM 编程常是：查询元素、判断状态、手动改文字/class。Vue 的基本思路：

```text
响应式状态 + 模板 → 当前界面
状态变化 → Vue 重新计算受影响部分 → 更新 DOM
```

```vue
<script setup lang="ts">
import { ref } from 'vue'

const count = ref(0)
</script>

<template>
  <button @click="count++">{{ count }}</button>
</template>
```

代码主要描述“状态是什么”和“界面应如何呈现”，Vue 管理具体 DOM 更新。

## 2. Vite 是开发和构建工具，Vue 是 UI 框架

Vite 提供：

- 开发服务器和模块加载；
- 热更新；
- TypeScript、CSS 等转换入口；
- 生产构建和资源优化。

Vue 提供组件、模板、响应式和渲染。`npm run dev` 成功说明开发工具启动，不代表 Vue 业务行为正确。

项目通过 `package.json` 和 lockfile 固定依赖，团队使用相同脚本进行 dev/build/test/typecheck。

## 3. SFC 把一个组件的相关内容放在同一文件

Single-File Component（单文件组件，SFC）：

```vue
<script setup lang="ts">
// 状态和行为
</script>

<template>
  <!-- 结构 -->
</template>

<style scoped>
/* 当前组件样式 */
</style>
```

同文件不等于混乱：三块仍各有职责。组件应围绕一项 UI 责任，而不是因“页面都在一起”变成数千行文件。

`<script setup>` 是常用 Composition API 语法，顶层导入、变量和函数可直接在模板使用。

## 4. 模板不是字符串拼接，而是受约束的表达式环境

文本插值：

```vue
<p>{{ order.title }}</p>
```

Vue 会把普通插值作为文本转义，避免标题被当 HTML。模板表达式可读取状态和调用简单函数，但不适合塞复杂业务流程或修改副作用。

```vue
<!-- 不清楚：每次渲染执行复杂筛选和排序 -->
<li v-for="item in expensiveTransform(items)">...</li>
```

复杂派生结果放 computed，事件副作用放函数。

## 5. v-bind 把 JavaScript 值绑定到属性或 prop

```vue
<button :disabled="submitting">提交</button>
<img :src="imageUrl" :alt="imageAlt">
```

`:` 是 `v-bind:` 简写。布尔属性按值正确添加/移除，不要拼接 `disabled="false"`。

动态 class：

```vue
<article :class="{ 'is-critical': order.priority === 5 }">
```

动态 style 适合少量运行值，主要视觉规则仍放 CSS。

## 6. v-on 把事件交给函数

```vue
<button @click="closeOrder">关闭</button>
<form @submit.prevent="submitOrder">...</form>
```

`@` 是 `v-on:` 简写。`.prevent` 调用 preventDefault，`.stop` 阻止传播，`.once` 只监听一次。修饰符应表达明确浏览器行为，不要用 `.stop` 掩盖结构问题。

复杂逻辑用命名函数，模板中保持可读：

```ts
function closeOrder() {
  // 检查并触发用例
}
```

## 7. v-if 真正创建和销毁分支

```vue
<p v-if="status === 'loading'">加载中</p>
<OrderList v-else-if="status === 'success'" :orders="orders" />
<ErrorPanel v-else />
```

条件变化时，分支内组件会挂载/卸载，内部状态和副作用随生命周期变化。适合不常切换或分支内容昂贵但初始不需要的情况。

同一组 `v-if / v-else-if / v-else` 必须相邻。

## 8. v-show 只切换显示状态

```vue
<aside v-show="filtersOpen">...</aside>
```

元素一直存在，只通过 CSS display 显示/隐藏。适合频繁切换且初始创建成本可接受的内容。

```text
v-if：创建/销毁成本，隐藏时不存在
v-show：初始都创建，切换成本低
```

若隐藏内容含仍运行的计时器或网络，v-show 不会停止它们。

## 9. v-for 根据集合渲染重复内容

```vue
<OrderRow
  v-for="order in orders"
  :key="order.id"
  :order="order"
/>
```

`key` 告诉 Vue 每项的稳定身份，用于在增删、排序时复用正确组件和 DOM。

不要在可重排/编辑列表中用索引作为 key；否则行位置变化时，输入状态和组件实例可能跟错数据。使用唯一、稳定、不会随显示变化的业务 ID。

## 10. 不要把 v-if 和 v-for 堆在同一元素上

过滤集合应先 computed：

```ts
const visibleOrders = computed(() =>
  orders.value.filter(order => order.visible),
)
```

```vue
<OrderRow v-for="order in visibleOrders" :key="order.id" />
```

这样规则有名字，只计算依赖变化，模板也不依赖指令优先级细节。

## 11. ref 把一个值接入响应式系统

```ts
const count = ref(0)
const selectedOrder = ref<WorkOrder | null>(null)
```

在 script 中通过 `.value` 读写：

```ts
count.value += 1
```

模板中顶层 ref 通常自动解包，可写 `{{ count }}`。ref 能保存原始值和对象，是官方建议的主要状态声明方式。

## 12. reactive 返回对象的响应式 Proxy

```ts
const form = reactive({
  title: '',
  affectedUsers: 0,
})

form.title = '电机过热'
```

它只接受对象类值，并通过 Proxy 跟踪属性。返回的 proxy 与原对象不是同一引用，应持续使用 proxy。

替换整个 reactive 变量或把原始属性直接解构出来，可能断开响应性：

```ts
const { title } = form // title 是普通当前值，不再跟踪 form.title
```

需要解构可用 `toRefs`，或直接保留 `form.title`。

## 13. 响应式依赖通过“读取时跟踪、写入时触发”建立

组件渲染或 computed 执行时读取 ref/reactive 属性，Vue 记录依赖；以后这些属性变化，相关计算才重新执行。

```text
渲染读取 order.status
  → 记录组件依赖 status
修改 order.status
  → 通知依赖它的组件更新
```

Vue 不是每次扫描所有变量，也不会追踪普通局部变量。只有经过响应式 API 的访问能建立关系。

## 14. 深层响应性和浅层响应性有成本取舍

ref 中的对象和 reactive 默认深度响应，嵌套属性修改也可触发。

对于大型不可变数据、外部类实例或自己管理状态的库，可使用 `shallowRef` / `shallowReactive`，只跟踪顶层替换。

先用默认响应性。只有性能测量或集成边界明确时选择 shallow，并用整体替换触发更新。

## 15. computed 表示由其他状态推导的值

```ts
const criticalCount = computed(() =>
  orders.value.filter(order => order.priority === 5).length,
)
```

computed getter 应保持纯：不发网络、不修改其他 ref、不写 localStorage。它根据依赖缓存，依赖不变时重复读取不重算。

如果一个值能从已有状态计算，就不必再存一个副本并用 watch 同步，否则会出现两个真相。

## 16. 可写 computed 用于明确的双向转换

```ts
const fullName = computed({
  get: () => `${first.value} ${last.value}`,
  set: value => {
    ;[first.value, last.value] = value.split(' ', 2)
  },
})
```

只有读写映射都清楚时使用。若 setter 执行复杂业务副作用，使用命名动作更容易理解。

## 17. 状态更新后 DOM 不会在同一行立即完成

Vue 会批量缓冲更新，避免同一轮多次写状态导致重复渲染：

```ts
count.value += 1
await nextTick()
// 此时本轮 DOM 更新已完成
```

大多数代码不需要 nextTick。只有必须在更新后的 DOM 上测量、聚焦或与第三方库同步时使用。

nextTick 不是“等网络”或通用延时函数。

## 18. v-model 是 value/checked 与事件的组合语法

```vue
<input v-model="form.title">
<input v-model="form.machineStopped" type="checkbox">
```

不同控件映射不同 property 和事件。它不会进行完整业务验证，只保持状态和控件同步。

数据状态应拥有初始值，避免 DOM 是一份真相、JavaScript 又是一份真相。

## 19. v-model 修饰符改变输入转换时机

```vue
<input v-model.trim="form.title">
<input v-model.number="form.affectedUsers" type="number">
<input v-model.lazy="form.code">
```

- `.trim` 去首尾空白；
- `.number` 尝试转数字，但仍需检查 NaN、整数和范围；
- `.lazy` 通常从 input 时机改到 change。

不要把转换修饰符当后端校验。空输入、区域数字格式和精度仍需合同。

## 20. checkbox 既可表示 boolean，也可表示数组成员

```vue
<input v-model="accepted" type="checkbox">
```

多个同类选项：

```vue
<label v-for="tag in availableTags" :key="tag">
  <input v-model="selectedTags" type="checkbox" :value="tag">
  {{ tag }}
</label>
```

Vue 会在数组中加入/移除 value。对象 value 按引用比较，通常使用稳定字符串 ID 更容易持久化。

## 21. radio 和 select 绑定的是值，不只是显示文字

```vue
<select v-model="form.priority">
  <option disabled value="">请选择</option>
  <option :value="5">严重</option>
</select>
```

`value="5"` 是字符串，`:value="5"` 是 number。前后端合同若需要 number，要保持类型一致。

动态选项的 label 可变化，提交值应使用稳定 ID，而不是中文显示文本。

## 22. 表单状态最好用判别清楚的模型

```ts
type SubmitState =
  | { status: 'idle' }
  | { status: 'submitting' }
  | { status: 'success'; id: string }
  | { status: 'error'; errors: FieldErrors }
```

比 `loading/error/success` 三个互相矛盾 boolean 更清楚。表单草稿、服务端结果和原始对象也不要共用一个引用随意修改。

编辑场景可建立 draft，提交时转成 API input；取消时丢弃 draft，不污染列表中的原对象。

## 23. 校验分为控件体验和可信服务端边界

前端可：

- required、长度、格式即时提示；
- 跨字段规则；
- 提交前整理错误；
- 映射服务端 field errors。

后端必须重新校验。权限、租户、唯一约束和当前状态只能由服务端可信数据决定。

前端错误结构应使用稳定字段路径和代码，不从自然语言文案推断字段。

## 24. 提交函数要防重复并保留失败状态

```ts
async function submit() {
  if (submitState.value.status === 'submitting') return
  submitState.value = { status: 'submitting' }

  try {
    const created = await api.create(toRequest(form))
    submitState.value = { status: 'success', id: created.id }
  } catch (error) {
    submitState.value = toSubmitError(error)
  }
}
```

UI 禁用按钮改善体验，但服务端写接口仍需幂等或唯一约束。请求超时后不能假定服务端没执行。

## 25. v-html 是明确的 XSS 边界

```vue
<div v-html="trustedSanitizedHtml" />
```

普通插值会转义；`v-html` 直接插入 HTML。不可信内容必须经成熟 sanitizer，且不要把 sanitizer 后 HTML 再拼进脚本、URL 等不同上下文。

组件模板本身也不应来自不可信用户输入。CSP 可增加一层防御，但不替代安全绑定。

## 26. Template Ref 用于确实需要 DOM/组件实例的地方

```vue
<input ref="titleInput">
```

```ts
const titleInput = useTemplateRef<HTMLInputElement>('titleInput')
```

可用于聚焦、尺寸测量、第三方库集成。普通显示和状态更新仍应数据驱动，不要回到 `querySelector` 后手动改 Vue 管理的 DOM。

Template ref 只在挂载后有元素，卸载时会回到 null。

## 27. 派生数据、事件和 watch 各有边界

```text
computed：从状态算另一个值，无副作用
事件函数：用户动作引发明确副作用
watch：某个响应式值变化后与外部系统同步
```

若“状态 A 变化所以把状态 B 设为 A*2”，通常 B 应是 computed。若用户点击提交，直接在 handler 调 API，不必先改一个 ref 再 watch 它。

## 28. 组件渲染要保持确定性

模板/computed 中不要直接：

- 调网络；
- 修改响应式状态；
- 读取随机数并作为关键 DOM；
- 每次读取当前时间制造不同输出；
- 依赖可变全局单例而无响应式桥接。

渲染可能执行多次。副作用放到事件、watch 或生命周期，并提供清理。

## 29. 这篇的整体地图

```text
SFC + script setup 定义组件
  → ref/reactive 保存响应式状态
  → template 用绑定、事件和条件描述 DOM
  → computed 保存唯一派生关系
  → v-model 同步表单控件与草稿
  → 提交函数处理加载、成功、字段错误
  → Vue 批量更新 DOM，必要时 nextTick 后操作元素
```

必须掌握：模板插值默认转义；key 是列表项身份；ref 在脚本用 `.value`；reactive 解构可能失去响应性；computed 应纯；v-model 不等于验证；`v-html` 是安全边界。

渲染函数、自定义指令和响应式底层调试 API 属于“需要时查询”。
