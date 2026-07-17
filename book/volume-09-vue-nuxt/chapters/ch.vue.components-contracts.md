---
schema_version: 2
edition: 2026.2-draft
id: ch.vue.components-contracts
title: Props、事件、Slot 与组件 v-model
responsibility: 用 Props、emit、Slot 和组件 v-model 建立单向数据流与可组合 UI 合同，禁止子组件直接修改父级所有状态。
volume: '09'
order: 6
level: L2
status: drafting
path: book/volume-09-vue-nuxt/chapters/ch.vue.components-contracts.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.vue.effects-lifecycle
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
  text: 在 120 秒内解释“Props、事件、Slot 与组件 v-model”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - vue-props-emits-model
  - vue-slots-composition
  covers_topics:
  - vue.props-contract
  - vue.emit-contract
  - vue.one-way-data-flow
  - vue.component-v-model
  - vue.default-named-slot
  - vue.scoped-slot
  - vue.slot-fallback
  - vue.component-boundary
  uses_capabilities:
  - web.vue-template
  - web.vue-reactivity-lifecycle
  - web.vue-components-contracts
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“Props、事件、Slot 与组件 v-model”构建可运行程序与测试：拆分筛选栏、工单卡片和状态编辑器组件并保存数据流合同；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - vue-props-emits-model
  - vue-slots-composition
  covers_topics:
  - vue.props-contract
  - vue.emit-contract
  - vue.one-way-data-flow
  - vue.component-v-model
  - vue.default-named-slot
  - vue.scoped-slot
  - vue.slot-fallback
  - vue.component-boundary
  uses_capabilities:
  - web.vue-template
  - web.vue-reactivity-lifecycle
  - web.vue-components-contracts
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: parent-child-state-matrix-event-payload-check-slot-render-check
- id: diagnose
  kind: fault-diagnosis
  text: 面对“直接修改 Prop、事件名/payload 漂移或 Slot 作用域误用”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - vue-props-emits-model
  - vue-slots-composition
  covers_topics:
  - vue.props-contract
  - vue.emit-contract
  - vue.one-way-data-flow
  - vue.component-v-model
  - vue.default-named-slot
  - vue.scoped-slot
  - vue.slot-fallback
  - vue.component-boundary
  uses_capabilities:
  - web.vue-template
  - web.vue-reactivity-lifecycle
  - web.vue-components-contracts
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Props、事件、Slot 与组件 v-model

> 本章状态为 **drafting**。正文和工件可用于学习与作者自检，但不能证明学习者已完成无 AI 独立构建、故障诊断或限时复述，也不会自动更新 `PROGRESS.md`。

一个单文件工单页面可以工作，却很难让不同人安全修改。把它切成组件也不自动变好：若卡片直接改父数组、筛选栏发出含糊字符串、状态编辑器自带一份默认值、Slot 依赖不存在的子作用域，数据流会比单文件更难追踪。组件边界的价值不是文件变短，而是公开合同变得有限、可命名、可测试。

本章把 FactoryCare 页面拆成三个责任：筛选栏表达一个受控筛选值，工单卡片接收只读展示数据并发出选择意图，状态编辑器通过组件 `v-model` 请求父级更新。卡片的标题/元数据/操作区使用默认、命名和 scoped slots 组合视觉，而父组件仍是工单集合与选择状态的唯一所有者。

本章不引入 provide/inject、Composable、Pinia、Router、异步组件、fallthrough attributes 深入规则或真实 API。组件内部若有资源，沿用上一章生命周期所有权；本章重点是 Props、emit、Slot、组件 v-model 和边界测试。官方资料复核日为 **2026-07-17**。

## 1. 完成标准：每次交互都能沿合同回溯

需要保存一张父子状态矩阵：

| 场景 | 父状态 | 子 Prop | 子发出的事件/payload | 组件 v-model | Slot 输出 |
|---|---|---|---|---|---|
| 初始 | filter=ALL，未选择 | 卡片收到固定 order | 无 | editor 收到当前 status | fallback 或父提供内容 |
| 筛选 | 父收到 update 后改 filter | 列表重算并下传 | `update:modelValue`/精确枚举 | 同步回新 filter | 可见卡片随父状态变 |
| 选择 | selectedId 由父更新 | 卡片 order 不变 | `select({ orderId })` | 不适用 | 父级选择提示更新 |
| 改状态 | 父数组目标项更新 | 下一 render 下传新 status | `update:modelValue(next)` | 子不保留第二份真相 | scoped action 显示新状态 |
| 负例 | 父状态被隐式改/不改 | Prop 与所有权分叉 | 错名/错 payload | 父子不同步 | slot 变量不存在 |

三项 outcome：

- 120 秒解释 Props 下行、事件上行、Slot 渲染作用域与组件 v-model 展开，并举出不应由组件合同解决的反例，例如服务器权限。
- 独立拆分筛选栏、工单卡片和状态编辑器，保存父状态、Prop、emit payload、v-model 与 Slot 的可复现矩阵。
- 注入直接修改 Prop、事件名/payload 漂移或 Slot 作用域错误，先找第一可信证据，再修复并重跑同一 oracle。

配套工件：

- [组件合同观察例](../../../examples/encyclopedia/ch.vue.components-contracts/README.md)
- [FactoryCare 父子数据流实验](../../../labs/encyclopedia/ch.vue.components-contracts/README.md)
- [公开 Prop mutation 红灯练习](../../../exercises/encyclopedia/ch.vue.components-contracts/README.md)

公开练习初始红灯是诊断起点。私有解析不会进入公开目录；改检查器接受隐式 mutation、把父状态断言删除或复制私有实现都不构成学习证据。

## 2. 组件合同的四个方向

先用方向判断工具：

```text
父状态 ──Props──▶ 子组件
父处理器 ◀─emit(event, payload)── 子组件
父模板 ──slot function──▶ 子 outlet（子可提供 slot props）
父状态 ◀─update:modelValue── component v-model（Props + emit 的约定组合）
```

Props 传数据，不授予所有权；emit 报告事实或请求动作，不直接执行父级 mutation；Slot 传渲染片段，不是隐式读取子内部变量；组件 v-model 是受控值合同，不是子组件偷偷共享父 ref。一个边界若需要十几个布尔 Props 和十几个细粒度事件，可能责任仍然过多；但不能为了“整洁”把它们装进一个任意对象后直接双向修改。

组件公开 API 应能脱离实现描述：输入字段、允许值、默认/必填、事件名、payload 形状、Slot 名/props/fallback、可访问语义与不变量。内部 ref 名、CSS DOM 层级和工具函数不是公开合同，除非调用者确实依赖。

## 3. Props：父级向下提供只读输入

在 `<script setup lang="ts">` 中可使用类型声明：

```ts
type WorkOrderCardModel = {
  id: string
  title: string
  status: 'CREATED' | 'IN_PROGRESS' | 'COMPLETED'
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'
}

const props = defineProps<{
  order: Readonly<WorkOrderCardModel>
  selected?: boolean
}>()
```

TypeScript 为项目调用方和编辑器提供静态检查，Vue 编译器会尽力生成相应运行时声明；外部 JSON、模板的 JS 调用或关闭类型检查仍需运行时/服务端边界。对象语法可以声明 `type`、`required`、`default` 与 validator，开发构建违反时 Vue 会在控制台警告。Prop validator 不能代替 API schema 或授权。

Prop 名在脚本通常用 camelCase，在模板标签上推荐 kebab-case：`selected-order-id`。布尔 Prop 有接近原生布尔属性的转换规则；若允许 String 与 Boolean，类型顺序还会影响空属性转换。业务组件应避免过度模糊的联合类型，让调用者不用猜 `disabled="false"` 是字符串还是否定。

### 3.1 默认值与对象工厂

可选数组/对象的运行时 default 应由工厂返回，避免实例共享可变引用。类型式声明可用 reactive props destructure 默认值或 `withDefaults`，具体取决于工具链。默认值是合同，不是隐藏业务决定：状态编辑器不应自行默认为 `CREATED`，若父级没提供值就产生另一个真相。

## 4. 单向数据流：父更新向下流，子不能反向写

Vue Props 是单向下行绑定：父状态更新，子收到新值；子不应给 prop binding 赋值。这样同一事实有一个所有者：

```ts
// 错误：子试图夺取父级 status 所有权
props.status = 'COMPLETED'

// 正确方向：子发出明确请求，父决定是否更新
emit('request-status-change', {
  orderId: props.orderId,
  nextStatus: 'COMPLETED',
})
```

父可以拒绝、校验、调用 API、处理乐观锁或回滚。子只表达用户意图。事件名用业务语义还是通用 update，取决于边界：简单输入适合 `update:modelValue`；有权限/确认/异步失败的工单状态迁移更适合 `request-status-change`，不能把一次 UI 选择伪装成服务端已成功状态。

### 4.1 对象/数组 Prop 的嵌套 mutation 陷阱

Vue 无法以合理成本阻止子修改对象/数组 Prop 的嵌套属性，因为父子共享引用：

```ts
// 语法能运行，却让父状态在没有事件的情况下改变
props.order.status = 'COMPLETED'
```

这类故障可能没有 Prop binding 警告，反而更危险。测试必须冻结输入或比较父状态与事件轨迹：若父状态改变而事件列表为空，第一可信证据已出现。主流做法是子 emit payload，父按 ID 创建更新；除非父子被明确设计为紧耦合且合同写明共享 mutation，本章禁止嵌套改写。

`Readonly<T>` 只提供类型层提醒；运行时可用冻结测试 fixture 捕获 mutation，但生产中深冻结有成本且不是安全边界。真正修复仍是所有权设计。

## 5. “基于 Prop 的本地状态”先问是不是派生

两个常见需求：

1. **只需变换显示**：用 computed 从 prop 派生，不复制。
2. **只把 prop 当初始值，之后成为独立草稿**：明确创建本地 ref，并说明父后续更新不会覆盖；保存/取消通过事件回交。

```ts
const normalizedTitle = computed(() => props.order.title.trim())

// 只有明确的编辑草稿合同才这样做
const draftTitle = ref(props.order.title)
```

第二种不是自动同步。若父因服务器刷新更新 title，draft 是否重置、保留或显示冲突需要产品规则；用 watch 双向同步很容易覆盖用户编辑。状态编辑器的当前已提交 status 不属于独立草稿，本章使用 component v-model 受控合同。

## 6. emit：把事件名和 payload 当公共 API

使用 `defineEmits` 声明所有组件事件，并给 payload 精确类型：

```ts
const emit = defineEmits<{
  select: [payload: { orderId: string }]
  'request-status-change': [payload: {
    orderId: string
    nextStatus: WorkOrderStatus
  }]
}>()
```

声明能形成文档与类型反馈，也让 Vue 区分组件 listener 与 fallthrough listener。对象语法还能在开发时验证 payload 并返回 boolean。事件 validator 只发警告，不能净化不可信输入；父处理器仍应按业务合同处理。

事件名与 payload 一旦被父依赖，就是 API。`statusChanged`、`status-change`、`update:status` 不是自动等价；`{ id, status }` 与 `{ orderId, nextStatus }` 也不是。重构时必须同时更新声明、发射、监听和测试，不能只让 TypeScript 的某处 `any` 静默通过。

### 6.1 报告事实还是请求命令

- 输入组件：`update:modelValue(nextValue)` 表示受控值建议更新。
- 选择组件：`select({ orderId })` 表示用户选择事实。
- 业务动作：`request-status-change({ orderId, nextStatus })` 表示请求，不宣称后端已完成。
- 成功事件：只有真正拥有异步操作且已获得权威成功时才发 `saved`；本章子组件不拥有 API。

避免 `change('x')` 这种上下文不足 payload，也避免把整个可变 order 对象发回让父猜哪些字段变了。最小充分 payload 更容易日志、测试和版本化。

### 6.2 组件事件不冒泡

Vue 组件自定义事件不像原生 DOM 事件，不会穿过祖先冒泡；只能由直接父级监听。祖父需要该信息时，应由中间组件明确重新发出或提升状态所有权。不要靠在顶层写 `@select` 期待捕获任意深度子事件；那会产生静默无响应。

## 7. component v-model：Prop + `update:` 事件的约定

Vue 3.4+ 推荐 `defineModel()`：

```vue
<script setup lang="ts">
type StatusFilter = 'ALL' | 'CREATED' | 'IN_PROGRESS' | 'COMPLETED'

// Data source: this ref is a compiler-backed view of the parent's controlled value.
const filter = defineModel<StatusFilter>({ required: true })
</script>

<template>
  <select v-model="filter" aria-label="工单状态筛选">
    <!-- options -->
  </select>
</template>
```

父级：

```vue
<WorkOrderFilterBar v-model="filter" />
```

编译器把它展开为 `modelValue` Prop 与 `update:modelValue` 事件；父模板则展开成传值和接收事件后赋值。理解展开后，调试路径很明确：子原生控件是否得到正确 value → 子是否 emit 正确事件名/payload → 父 listener 是否更新来源 → 新 Prop 是否下传。

在不使用 `defineModel` 或兼容旧版本时可显式写：

```ts
const props = defineProps<{ modelValue: StatusFilter }>()
const emit = defineEmits<{
  'update:modelValue': [value: StatusFilter]
}>()
```

两者合同相同，不要同时保留两套独立本地状态。

### 7.1 默认值失同步警告

若子 `defineModel({ default: 1 })` 而父没有提供值，父 ref 可能仍是 undefined、子却是 1，初始就失同步。受控输入优先要求父显式初始化并让 model required。本章筛选父初始化为 ALL，编辑器父提供当前 status，不让子发明业务默认。

### 7.2 参数、多个 model 与修饰符

`v-model:status` 对应 `status` Prop/`update:status` 事件，`defineModel('status')` 支持它；一个组件可以有多个 named models。能力存在不代表应把每个 Prop 都变成 v-model。若 first/last name 是两个独立受控值可合理；若整个 WorkOrder 通过多个 v-model 可任意写，边界可能已失去所有权。

组件修饰符可通过 `defineModel` 返回的 modifiers 与 get/set 处理，但转换必须成为公开合同。工单状态枚举无需自定义修饰符，本章不为了展示语法而增加。

## 8. Slot：父提供渲染函数，子决定 outlet

Slot 让组件封装结构与语义，同时允许父替换局部内容：

```vue
<article>
  <header>
    <slot name="title" :order="order">
      <h3>{{ order.title }}</h3>
    </slot>
  </header>
  <div>
    <slot :order="order">暂无补充信息</slot>
  </div>
  <footer>
    <slot name="actions" :order-id="order.id" :status="order.status" />
  </footer>
</article>
```

无父内容时，`<slot>` 标签内部 fallback 渲染；父提供内容时替换。命名 Slot 适合 title/default/actions 等稳定区域，名称也是公共 API。把布局每个 div 都暴露为 slot 会让内部结构无法演进。

## 9. Slot 渲染作用域：定义在哪里，就能读哪里的变量

父模板写的 Slot 内容属于父作用域，不能直接读取子内部变量：

```vue
<WorkOrderCard>
  <!-- 这里不能凭空读取子组件内部的 localOrder -->
  {{ localOrder.title }}
</WorkOrderCard>
```

这与 JavaScript 词法作用域一致。若子要把数据交给 slot，通过 slot props：

```vue
<WorkOrderCard :order="order">
  <template #title="{ order: cardOrder }">
    <h3>{{ cardOrder.title }}</h3>
  </template>
</WorkOrderCard>
```

可以把 scoped slot 视为子调用父提供的函数：`slot({ order })`。父决定如何渲染，子决定传哪些只读上下文。Slot props 不授予父对“子私有状态”的任意写入权；不要传整个内部 reactive store 让父 mutation。

混合命名 slot 与默认 scoped slot 时，默认 slot 应使用显式 `<template #default="...">`，避免 slot props 作用域含糊。某个 slot 的 props 不会自动在另一个命名 slot 中存在。slot scope error 的第一证据通常是编译错误/undefined 或某区域空白，需对照 outlet 提供的 props 名。

## 10. Slot、Prop 与事件各自解决什么

常见误用：

- 为改变一段展示 HTML，传十个样式 Props：应考虑 slot。
- 用 slot 放一个按钮，却让父读子内部 ref：应通过 scoped slot props/callback 或组件事件。
- 用 event 传纯展示内容：应是 Prop/slot。
- 让 slot 内容直接改子/父对象：应发明确事件并由所有者处理。
- 传一个 `renderEverything` slot 导致组件只剩空壳：边界可能没有责任。

选择顺序：稳定数据输入用 Props；子发生的离散事实/请求用 emit；受控单值输入用 component v-model；可替换渲染区域用 slot；子给父渲染函数上下文用 scoped slot props。

## 11. FactoryCare 三组件拆分

### 11.1 `WorkOrderFilterBar`

责任：展示状态筛选原生 select，读取受控 modelValue，发 `update:modelValue`。它不请求网络、不保存另一份 filter、不决定列表结果。可访问名称明确，全部选项显示文本而非只靠颜色。

### 11.2 `WorkOrderCard`

责任：接收一个只读 `order` 和 `selected`，渲染 article 与选择按钮，发 `select({ orderId })`。提供 title、default/metadata、actions slot 与 fallback；不修改 `order.status`，不调用 API。

### 11.3 `WorkOrderStatusEditor`

责任：读取受控 status，通过 `update:modelValue(nextStatus)` 返回合法枚举。若真实状态转换需要权限/确认/乐观锁，可改为更明确的 request event，由父协调；示例只证明组件 model 合同，不宣称服务端迁移成功。

### 11.4 `WorkOrderBoard` 父级

责任：拥有 orders/filter/selectedId，计算 visibleOrders，监听所有子事件并更新来源；在 scoped slot 中组合 priority 和 status editor。它是矩阵的观察点：每次父更新后 Props 再下传，而不是子直接碰父数组。

## 12. 类型合同与运行时合同要同时诚实

TypeScript 能捕获：Prop 名/类型、emit 名/payload、slot props（结合 Vue tooling）、model 枚举。它不能证明：外部 API JSON 合法、用户有权变更、事件真正被监听、slot 实际提供、DOM 可访问、对象没有在 any 中 mutation。

运行时 Vue 开发警告能捕获部分 Prop 类型/只读 binding 问题和 event validator，但生产构建可能不保留相同诊断；嵌套对象 mutation 也不一定警告。测试必须观察行为，不只断言 console 没警告。

边界类型应使用 FactoryCare 稳定字段的最小视图，不把后端完整 DTO 原样塞进每个组件。卡片需要 id/title/status/priority；若不需要 tenantId、内部审计字段，就不应暴露。减少输入面也减少误用和快照噪声。

## 13. 可访问组件合同不能交给调用者猜

可组合不等于语义任意：

- FilterBar 自己提供 label/aria-label 与原生 select；不能要求每个父都记得补名称。
- Card 保留 article/heading/按钮基本结构，slot 只替换内容区域；选择状态用 `aria-pressed`/文字而非颜色单一表示。
- StatusEditor 有可访问 label，若一个页面多实例，label/id 必须唯一或使用包装 label。
- actions slot 中的控件仍需键盘可达；父不能塞不可点击 div 冒充按钮。
- 空列表由父展示可恢复说明和清除筛选动作；不能只渲染 0 张卡片。
- disabled/loading 要有语义属性与状态文本，事件处理器还需防御，不能只改变灰色。

UI/UX 检索选择了 Accessible & Ethical 风格作为工件约束：清晰焦点、原生控件、高对比、错误/空态恢复和 44px 交互目标。本章没有建立视觉设计系统或 CSS token；真实对比度、触控尺寸、窄屏、读屏和 reduced motion 仍是人工未验证项。

## 14. 父子状态矩阵怎样自动化

测试层级从窄到宽：

1. **FilterBar**：给 modelValue=ALL，select 显示 ALL；用户选 OPEN，只 emit 一次 `update:modelValue` 且 payload 精确为 OPEN；Prop 在父更新前仍是 ALL。
2. **StatusEditor**：同样验证受控值与 update 事件，不把内部 DOM 值当父状态已改变。
3. **Card Props**：固定 order 渲染标题/状态，selected 控制 aria-pressed；不修改输入对象。
4. **Card event**：点击只发 `select({ orderId })`，不发送整个 order，不依赖冒泡。
5. **fallback slot**：未提供 title/metadata 时显示默认内容。
6. **named scoped slot**：父模板从 `{ order }` 得到正确 ID/priority，actions 从 `{ orderId, status }` 得到当前值。
7. **Board 集成**：筛选事件更新父 filter 后可见卡片变化；选择事件更新 selectedId；status update 更新目标项并作为新 Prop 下传。
8. **负例**：嵌套 Prop mutation 使父对象在无事件时改变，oracle 必须红；事件错名使父保持旧值；slot prop 错名产生缺失内容/编译诊断。

测试不要只检查子内部 ref，也不要通过 `setData` 绕过公开 API。使用真实 DOM select/click，从 `emitted()` 与父 DOM 同时观察。Vite build 证明所有 SFC/Slot 模板可编译，但不证明单向数据流。

## 15. 三类注入故障与第一可信证据

### 15.1 直接/嵌套修改 Prop

故障组件执行 `props.order.status = next`，没有 emit。第一证据：冻结 fixture 抛出 mutation，或父 order 变化而事件轨迹为空。修复为 emit `{ orderId, nextStatus }` 或受控 update，父决定写入。不要在子里先 mutation 再补 emit，那仍有两个路径。

### 15.2 事件名/payload 漂移

父监听 `update:modelValue`，子发 `status-change`；或父期待 `{ orderId }`，子发字符串。第一证据是原生 select 已变、子 `emitted()` 出现错误合同，而父状态保持旧值。修复声明、发射、监听和测试，使一个名称/形状贯穿。

### 15.3 Slot 作用域误用

父在 actions slot 使用 `order`，但 outlet 只提供 `orderId/status`；或把默认 slot 的 prop 用在 footer。第一证据是模板编译/类型错误或 slot 输出 undefined，不是卡片业务数据丢失。修复 outlet props 或父解构名；不能让父直接 import 子私有变量。

每个报告保存：调用模板、父初始状态、子 props、emitted 列表、slot DOM、第一偏离、修复、原命令重跑和残余风险。

## 16. 版本边界：Vue 3.5 与旧语法

本章锁定 Vue 3.5.35。`defineModel` 从 Vue 3.4 起推荐；3.5 的 reactive props destructure 会让同一 `<script setup>` 中解构变量保持编译器追踪，而 3.4 及更早行为不同。为减少隐式版本差异，核心卡片代码可保留 `const props = defineProps...`，model 用 `defineModel` 并在正文展示展开。

如果项目必须支持 3.3 或更早，应明确选择显式 `modelValue`/`update:modelValue` 语法并调整工具链，不要同时混用宏后声称兼容。当前任务没有兼容要求，因此不加入旧版本分支。具体补丁与编译器必须匹配，锁文件是复现证据。

## 17. 实验路线

### 阶段 A：逐个组件合同

运行示例验证器，记录环境。分别挂载 FilterBar、Card、StatusEditor，手写预期 Prop 与 event，输入后比较 DOM、`emitted()` 和未更新的父状态。验证 fallback/named/scoped slots。

### 阶段 B：父级集成

挂载 Board，依次筛选、选择、改状态。每一步记录父来源、子 Prop、事件 payload 和 DOM。确认父处理事件后才出现新 Prop。

### 阶段 C：故障注入

实验提供 MutatingStatusEditor 与 WrongEventEditor。先运行并保存“无事件父状态已改”和“子有错名事件但父不变”的第一证据；一次只诊断一种，不把两个修复混在一起。

### 阶段 D：Slot 范围

提供 title fallback，再由父覆盖；为 metadata/actions 传明确 slot props。故意解构错名，保存类型/DOM 失败，再修复并重跑 slot-render oracle。

### 阶段 E：边界清单

明确未验证：真实 API 状态迁移、权限/乐观锁、跨浏览器/读屏、CSS 响应式、SSR/hydration、跨层事件架构。组件测试绿不能提升为端到端成功。

## 18. 120 秒复述模板

> Props 是父向子的只读输入，父更新后新值下传；对象 Prop 的嵌套属性技术上仍可能被子改，所以要用事件和测试保护父所有权。emit 是直接子向父的离散合同，事件不冒泡，名称和最小 payload 都要声明/测试。组件 v-model 是 modelValue Prop 与 update:modelValue 事件的约定，defineModel 只是编译宏；受控值由父初始化，子默认值可能导致失同步。Slot 是父作用域定义、子 outlet 调用的渲染函数；普通 slot 只能读父作用域，scoped slot 通过 props 获得子提供的只读上下文，命名和 fallback 都属于 API。FactoryCare 父拥有 orders/filter/selected，筛选栏、卡片和编辑器只接收 Prop/发事件。证据是父子状态矩阵、emitted payload、slot DOM 和 mutation 负例。反例：组件只读和事件验证不能替代服务器授权与状态机。

若不能解释“嵌套 Prop 为什么可能无警告地改父”“组件 v-model 为什么父更新前 Prop 仍旧”“slot 内容为什么看不到子局部变量”，需要回到实验。

## 19. 自检题

1. 文件变小为什么不等于组件边界合理？
2. Prop 类型、运行时 validator 与 API 校验各能证明什么？
3. 为什么 `props.order.status = ...` 比直接给 prop binding 赋值更隐蔽？
4. 哪种场景适合本地草稿，怎样处理父后续更新？
5. 组件事件为什么不能由祖父依赖冒泡捕获？
6. `select({ orderId })` 为什么比发整个 order 更稳定？
7. `defineModel` 展开成哪一个 Prop 和哪一个事件？
8. 子 model default 为什么会与未初始化父 ref 分叉？
9. 普通、命名、scoped slot 与 fallback 各自解决什么？
10. 某个 slot 的 props 为什么不能在另一个 slot 中直接使用？
11. 如何用一个测试证明“父处理事件后才更新”？
12. 哪些业务状态迁移不应包装成通用 component v-model？

答案应引用工件的父状态、props、emitted 与 slot DOM，不只复述“一向下、事件向上”。

## 20. 有意不做与下一章

本章不使用 provide/inject 解决普通父子通信，也不创建事件总线或模块级全局 ref。下一章会在 Props/emit 已经不足以表达跨层依赖时，提取有清理合同的 Composable，并用 typed InjectionKey/readonly injection 控制边界。若当前三个组件已经可用显式合同，不应提前引入注入。

本章不实现服务器状态迁移。真实 FactoryCare 状态更新需要授权、合法转换、版本/并发与审计；UI 事件只表达请求。没有 API 证据时，不能把下拉选择后的本地文字称为“工单已成功更新”。

### 官方资料

- [Vue：Props](https://vuejs.org/guide/components/props.html)
- [Vue：Component Events](https://vuejs.org/guide/components/events.html)
- [Vue：Slots](https://vuejs.org/guide/components/slots.html)
- [Vue：Component v-model](https://vuejs.org/guide/components/v-model.html)
- [Vue：TypeScript with Composition API](https://vuejs.org/guide/typescript/composition-api.html)
- [Vue：Accessibility](https://vuejs.org/guide/best-practices/accessibility.html)

### 本地规范依据

- `curriculum/chapters/volume-09.yml` 中本章责任、主题、G4 验收、oracle 与 outcomes
- FactoryCare 工单 ID/status/priority 仅作固定组件输入；服务端状态机与 API 不在本章实现

官方资料说明 Vue 公开合同；本地工件验证锁定版本中的 SFC、事件与 DOM。两者不能证明生产权限、真实浏览器、跨版本宏行为、视觉对比或辅助技术体验。
