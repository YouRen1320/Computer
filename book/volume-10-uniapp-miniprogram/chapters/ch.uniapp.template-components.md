---
schema_version: 2
edition: 2026.2-draft
id: ch.uniapp.template-components
title: uni-app 模板、组件、表单与 Vue 差异
responsibility: 把 Vue 模板、组件和表单合同迁移到 uni-app 的跨端组件集合，明确宿主事件、样式和 API 差异，不处理设备权限。
volume: '10'
order: 3
level: L2
status: drafting
path: book/volume-10-uniapp-miniprogram/chapters/ch.uniapp.template-components.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.uniapp.toolchain-pages
- ch.vue.components-contracts
version_surfaces:
- uni-app
- wechat-miniprogram
- vue-3
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“uni-app 模板、组件、表单与 Vue 差异”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - uniapp-template-component
  - uniapp-form-style
  covers_topics:
  - uniapp.built-in-component
  - uniapp.template-binding
  - uniapp.event-difference
  - uniapp.component-contract
  - uniapp.form-control
  - uniapp.model-binding
  - uniapp.unit-rpx
  - uniapp.style-scope
  - vue.component-v-model
  uses_capabilities:
  - mobile.miniprogram-runtime
  - web.vue-template
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现跨端报修表单和工单卡片组件并记录 H5/小程序差异矩阵；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - uniapp-template-component
  - uniapp-form-style
  covers_topics:
  - uniapp.built-in-component
  - uniapp.template-binding
  - uniapp.event-difference
  - uniapp.component-contract
  - uniapp.form-control
  - uniapp.model-binding
  - uniapp.unit-rpx
  - uniapp.style-scope
  - vue.component-v-model
  uses_capabilities:
  - mobile.miniprogram-runtime
  - web.vue-template
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: cross-target-render-matrix-form-state-check-host-event-log
- id: diagnose
  kind: fault-diagnosis
  text: 面对“误用 DOM 元素、事件名、rpx 或 v-model 类型导致的目标端差异”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - uniapp-template-component
  - uniapp-form-style
  covers_topics:
  - uniapp.built-in-component
  - uniapp.template-binding
  - uniapp.event-difference
  - uniapp.component-contract
  - uniapp.form-control
  - uniapp.model-binding
  - uniapp.unit-rpx
  - uniapp.style-scope
  - vue.component-v-model
  uses_capabilities:
  - mobile.miniprogram-runtime
  - web.vue-template
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# uni-app 模板、组件、表单与 Vue 差异

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《uni-app 工具链、页面、路由与项目结构》](ch.uniapp.toolchain-pages.md)：组件必须在已能构建、运行和导航的目标项目中验证。
- [《Props、事件、Slot 与组件 v-model》](../../volume-09-vue-nuxt/chapters/ch.vue.components-contracts.md)：uni-app 的模板、表单、事件和 v-model 差异必须建立在已验证的 Vue Props、emit、Slot 与组件 v-model 合同上。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套资产用 Node.js 静态合同检查和纯函数状态机验证模板、事件、表单值及 H5/微信目标差异矩阵；它没有执行真实 DCloud 编译器、浏览器渲染或微信基础库。因此，绿灯不能证明像素、焦点、软键盘、原生组件层级或真机无障碍行为一致。

你已经会 Vue，并不代表把 Web 后台的 `<div><input></div>` 复制到 uni-app 就能跨端。Vue 提供响应式和组件合同，uni-app 编译器把一部分模板、组件、样式和 API 映射到目标平台，最终仍由 H5 浏览器或小程序宿主执行。正确目标不是让所有端内部实现相同，而是为产品需要的文本、事件、表单值与关键样式定义可验证的一致合同，并把不可一致之处写进差异清单。

## 1. 完成定义、配套入口和非目标

完成本章后，你应能：

1. 说明为什么跨端模板优先使用 `view/text/image/button/input` 等内置组件；
2. 区分 Vue 指令语义、uni-app 组件合同与目标宿主实际事件；
3. 从事件对象中读取平台合同字段，而不是默认使用浏览器 `event.target.value`；
4. 用 Props/emit 与 `modelValue`/`update:modelValue` 建立可测试组件边界；
5. 处理 input、textarea、picker、radio、checkbox 和 form 的值类型与边界；
6. 解释 `rpx`、px、百分比、Flex 和安全区分别适合什么，不把设计稿数值当真机证据；
7. 识别 scoped 样式、选择器支持、组件默认样式和原生层差异；
8. 保存 H5/微信目标的渲染、事件、表单与关键样式矩阵。

配套入口：

- [报修表单与工单卡片合同示例](../../../examples/encyclopedia/ch.uniapp.template-components/README.md)
- [DOM、事件、rpx 与 v-model 差异实验](../../../labs/encyclopedia/ch.uniapp.template-components/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.uniapp.template-components/README.md)

本章不处理摄像头、相册、定位等设备权限，不展开条件编译，不选 UI 组件库，也不承诺所有目标像素完全相同。目标是先掌握平台原生组件和最小自定义组件合同。

## 2. 三层模型：Vue 语义、跨端组件、目标宿主

一段代码同时经过三种规则：

```text
Vue 层：ref、computed、v-if、v-for、Props、emit、v-model
    ↓
uni-app 层：view、text、button、input、picker、uni.* API、rpx
    ↓
目标层：H5 DOM/CSS/事件 或 微信组件/WXML/WXSS/基础库事件
```

Vue 层回答状态如何驱动模板、组件如何通信。uni-app 层定义跨端可用组件和 API。目标层决定具体支持、默认样式、事件字段、权限、渲染和性能。遇到差异先问“它属于哪一层”，不要在 Vue 响应式正常时反复改 `ref`，也不要用 H5 DOM 截图证明微信目标。

### 2.1 编译通过不等于跨端语义相同

编译器可以接受一个标签，但目标端可能没有相同属性、默认样式或事件。反过来，某个 H5 浏览器能容忍的写法可能在微信目标直接失败。跨端合同必须由目标矩阵验证：至少构建 H5 和 mp-weixin，分别运行成功、边界和失败输入。

## 3. 内置组件不是换名字的 HTML

常用基础组件：

| 组件 | 职责 | 常见误用 |
|---|---|---|
| `view` | 布局容器 | 期待拥有任意 `div` DOM 方法 |
| `text` | 文本与可选择文本边界 | 用它包复杂块布局 |
| `image` | 跨端图片组件 | 只测 H5 的 object-fit 行为 |
| `scroll-view` | 受控滚动容器 | 与页面滚动事件混为一谈 |
| `button` | 点击、表单与开放能力入口 | 依赖各平台默认颜色完全一致 |
| `input/textarea` | 文本输入 | 假定事件就是 DOM InputEvent |
| `picker` | 选择器 | 直接使用 Web `<select>` |
| `form` | 宿主表单提交/重置合同 | 认为嵌套自定义组件值自动跨端收集 |

组件名相似不代表属性完全相同。官方 button 文档明确平台预置 `type` 颜色可能不同；若产品需要品牌一致，应使用 `type="default"` 加受控 class，并在目标端验证点击态和禁用态。

```vue
<template>
  <view class="card">
    <text class="card__title">工单 {{ workOrder.id }}</text>
    <text class="card__status">{{ statusLabel }}</text>
    <button
      class="card__action"
      type="default"
      :disabled="disabled"
      @click="emit('open', workOrder.id)"
    >
      查看详情
    </button>
  </view>
</template>
```

这段模板只声明合同。文本换行、按钮默认 padding、字体和点击态仍需 H5/微信矩阵观察。

## 4. 模板绑定沿用 Vue，但数据必须适合目标

插值、`:prop`、`@event`、`v-if`、`v-for` 等来自 Vue 模板模型。仍要遵守：

- 模板表达式保持简单，复杂映射放 computed/函数；
- `v-for` 提供稳定且唯一 key，不用数组 index 伪装实体身份；
- `v-if` 创建/销毁，`v-show` 只改变显示，选择要考虑目标端成本；
- 不把未经解析的后端 HTML 当跨端模板注入；
- URL、状态、文本先按业务合同规范化。

```vue
<script setup lang="ts">
import { computed } from 'vue'

type WorkOrderCard = {
  id: string
  title: string
  status: 'ASSIGNED' | 'IN_PROGRESS' | 'CLOSED'
}

const props = defineProps<{ workOrder: WorkOrderCard }>()
const emit = defineEmits<{ open: [id: string] }>()

// 非显然映射：服务端状态码转成用户文本，未知值不能静默冒充完成。
const statusLabel = computed(() => ({
  ASSIGNED: '待处理',
  IN_PROGRESS: '处理中',
  CLOSED: '已关闭'
}[props.workOrder.status]))

const disabled = computed(() => !/^WO-[0-9]+$/.test(props.workOrder.id))
</script>
```

如果后端新增状态而类型/映射未更新，理想做法是运行时 schema 报错或展示“未知状态”，不是默认映射成“已关闭”。

## 5. 事件：看组件合同，不猜 DOM 字段

Web 输入常见 `event.target.value`；小程序/uni-app 组件事件常把值放在 `event.detail.value`。具体字段以组件文档和目标类型为准。不要写一个“万能事件处理器”在所有端逐层猜 `target/detail/currentTarget`，那会吞掉合同漂移。

```vue
<script setup lang="ts">
import { ref } from 'vue'

const description = ref('')

function onDescriptionInput(event: { detail: { value: string } }) {
  // 数据来源：宿主 input 事件；先转为受控字符串，再写入表单状态。
  description.value = String(event.detail.value).slice(0, 500)
}
</script>

<template>
  <textarea
    :value="description"
    maxlength="500"
    placeholder="描述故障现象"
    @input="onDescriptionInput"
  />
</template>
```

若使用 `v-model`，编译器会为支持的控件展开值与更新事件，但类型、修饰符和平台差异仍需验证。调试时打印脱敏的事件键和值类型，不要把完整手机号、token 或故障隐私写日志。

### 5.1 点击与触摸不是同一个抽象

`@click` 通常适合语义按钮；触摸起止、长按、滑动属于更底层交互。不要为了“移动端更快”把所有按钮改成 touchstart，这会破坏禁用、键盘/辅助技术语义与误触边界。先用 button/click，再为确有证据的手势建立单独合同。

## 6. 自定义组件：Props 向下，事件向上

工单卡片不应直接修改父页面列表，也不应读取全局 store 才能展示。最小合同：父传不可变展示数据，子通过语义事件报告用户意图。

```vue
<script setup lang="ts">
type CardValue = { id: string; title: string; statusLabel: string }

defineProps<{ value: CardValue; selected?: boolean }>()
const emit = defineEmits<{
  open: [id: string]
  'update:selected': [value: boolean]
}>()

function toggleSelection(current: boolean) {
  // 组件副作用边界：只发出新值，不直接写父状态或发网络请求。
  emit('update:selected', !current)
}
</script>
```

事件名表达业务意图，如 `open`、`submit`、`retry`，避免 `clickButton1`。Prop 只包含组件真正需要的字段，避免把整份后端响应传给所有组件。

## 7. 组件 `v-model`：值与更新事件必须成对

Vue 3 默认组件 `v-model` 合同是 `modelValue` Prop 与 `update:modelValue` 事件。uni-app 页面仍使用 Vue 组件模型，但具体目标编译与表单行为要验证。

```vue
<script setup lang="ts">
const props = defineProps<{ modelValue: string }>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

function update(event: { detail: { value: string } }) {
  // 值映射：宿主事件 detail.value -> 组件字符串合同。
  emit('update:modelValue', String(event.detail.value))
}
</script>

<template>
  <input :value="props.modelValue" @input="update" />
</template>
```

父组件：

```vue
<FaultDescriptionField v-model="form.description" />
```

常见错误包括 Prop 叫 `value` 却发 `update:modelValue`、发出整个事件对象、数字控件实际返回字符串、子组件直接改 Prop。编译不一定发现这些语义漂移，组件测试必须断言输入事件后发出的值和类型。

## 8. 表单值：UI 类型、领域类型与请求类型分开

输入控件给出的通常是字符串或平台定义的数组/索引。业务需要的优先级整数、设备 ID、布尔同意项不能靠 TypeScript 强制转换就变真。

```ts
type RepairFormUi = {
  deviceId: string
  description: string
  priorityText: string
  acceptedTerms: boolean
}

type RepairCommand = {
  deviceId: string
  description: string
  priority: 1 | 2 | 3 | 4 | 5
}

function toCommand(form: RepairFormUi): RepairCommand | null {
  const priority = Number(form.priorityText)
  if (!/^DEV-[A-Z0-9-]{3,40}$/.test(form.deviceId)) return null
  if (form.description.trim().length < 5) return null
  if (![1, 2, 3, 4, 5].includes(priority)) return null
  if (!form.acceptedTerms) return null
  return {
    deviceId: form.deviceId,
    description: form.description.trim(),
    priority: priority as RepairCommand['priority']
  }
}
```

类型断言只在运行时验证之后收窄，不是绕过校验。服务端仍重新验证长度、设备权限和状态规则。

### 8.1 form submit 与响应式状态

`form` + `button form-type="submit"` 可触发提交事件并收集受支持控件值；响应式 `v-model` 则持续拥有页面状态。两种方式可以组合，但必须选一个权威状态，避免 submit 数据与 reactive 数据不一致。自定义表单组件是否能被宿主 form 收集具有平台限制；官方文档列出的 form-field behaviors 并非所有平台/Vue 组合都一致，必须做差异矩阵。

### 8.2 picker、radio 与 checkbox

picker change 可能返回索引而不是领域值；用索引查受控选项，再得到稳定代码。radio 是单选值，checkbox 常为数组；不要因为值看起来像数字就假定类型是 number。选项更新时，旧索引可能越界，需验证。

## 9. rpx 与布局：适配单位不是像素保证

`rpx` 是小程序/uni-app 常用响应式单位，通常以 750 设计宽度建立比例直觉。`750rpx` 可对应当前视口宽度，但不同设备像素密度、字体、横屏、安全区和平台舍入会影响结果。不要把 `1rpx` 宣称为固定物理像素。

经验边界：

- 页面水平间距、卡片宽度可使用 rpx；
- 极细边框要在目标设备观察舍入；
- 文字不要只按设计稿等比缩小，需考虑可读性和系统字体；
- 布局优先 Flex/Grid 的目标支持范围与百分比，不用绝对坐标堆页面；
- 底部操作区考虑安全区和软键盘；
- H5 与小程序分别截图/量测，不用一端替另一端签字。

```css
.repair-form {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
  padding: 32rpx;
}

.repair-form__submit {
  min-height: 88rpx;
}
```

## 10. scoped 样式与选择器边界

SFC 的 `<style scoped>` 通过编译后的选择器隔离当前组件，但它不是真正 Shadow DOM。子组件内部、平台原生组件、弹层/原生层和第三方组件可能有不同边界。深层覆盖会把你绑定到实现细节，升级易失效。

```vue
<style scoped>
.work-order-card {
  border: 1rpx solid #d7dce2;
  border-radius: 16rpx;
  padding: 24rpx;
}

.work-order-card__status--urgent {
  color: #b42318;
}
</style>
```

不要使用依赖 DOM 层级的长选择器；采用组件名/BEM 风格 class 和少量设计 token。平台内置组件的默认样式可能不同，关键视觉状态要显式写并在两端测。不能支持的选择器应在构建日志或差异清单明确失败，而不是偷偷降级。

## 11. FactoryCare 报修表单的组件切分

建议最小组件：

- `DeviceSummaryCard`：只展示已选择设备并发 `change-device`；
- `FaultDescriptionField`：拥有输入合同与字符计数；
- `PriorityPicker`：把宿主索引映射为 `1..5`；
- `AttachmentList`：本章只展示元数据，不调用设备能力；
- `RepairSubmitBar`：接收 `disabled/loading`，发 `submit`，不直接发请求。

页面拥有完整 UI 表单、校验错误和提交协调；service 把命令发后端；服务端拥有权限和工单不变量。这样可以在 H5/微信分别验证组件，而不会让每个组件都调用网络和全局状态。

### 11.1 提交状态合同

```text
IDLE -> VALIDATING -> SUBMITTING -> SUCCESS
                    -> FIELD_ERROR
                    -> NETWORK_ERROR
```

按钮 loading 和 disabled 来自状态，不靠直接查 DOM。连续点击在 SUBMITTING 时不会重复发起；服务端仍用幂等键防重复。错误与字段关联，焦点/朗读策略在目标端验证。

## 12. 跨目标差异矩阵

不要只写“已兼容”。建立矩阵：

| 合同 | H5 预言 | mp-weixin 预言 | 证据 |
|---|---|---|---|
| 卡片文本 | ID/标题/状态一致 | 同左 | 两端文本快照 |
| button click | 发一次 `open(id)` | 同左 | 事件日志/组件测试 |
| input value | string，最长 500 | 同左 | 输入边界样例 |
| picker | 索引映射稳定代码 | 同左 | 选项矩阵 |
| form submit | 权威状态一致 | 平台支持差异注明 | submit payload |
| rpx 卡片间距 | 可接受范围 | 可接受范围 | 目标截图与量测 |
| scoped style | 不泄漏同级组件 | 同左 | class/样式检查 |
| 非支持 DOM API | 明确不进入跨端代码 | 构建/运行明确失败 | 负例日志 |

文本与事件可以自动断言，像素和辅助技术通常需要目标环境人工证据。矩阵不是要求完全相同，而是明确相同项、允许差异、失败项和理由。

## 13. 故障诊断：四类首证据

### 13.1 误用 DOM 标签或 API

症状可能是目标编译失败或运行不存在。先看编译器第一文件/行号和目标；确认代码是否用了 `div/select/document` 等 Web 专属合同。改成内置组件/uni API，或明确限定 H5，而不是用 `any` 压掉类型。

### 13.2 事件字段错误

症状是输入 UI 变化但状态为空。记录脱敏事件形状，看官方组件合同和目标日志。若代码读 `target.value` 而实际是 `detail.value`，这是事件映射错误，不是响应式失效。

### 13.3 rpx/默认样式漂移

症状是两端尺寸不同。先区分自定义 class 是否生效、平台默认 button 样式、rpx 舍入与字体，而不是盲调十组数值。用最小组件和量测矩阵定位。

### 13.4 v-model 类型漂移

症状是“3”与 `3` 比较失败、子组件不更新。检查 Prop 名、更新事件名、payload 类型和父状态。运行组件合同测试，修复后重跑边界值。

## 14. 安全、隐私、性能与无障碍

**安全**：模板插值默认文本展示不等于所有富文本都安全。富文本来源必须按组件合同清洗；事件和表单值不可信；权限仍在服务端。不要在组件日志输出 token、手机号和完整故障描述。

**隐私**：字段应最小必要，提示用户用途，错误截图/日志脱敏。设备能力与权限下一章以后再讲，本章组件不能偷偷在 mounted 请求位置或相册。

**性能**：列表 key 稳定，避免把大响应对象传入每张卡片，computed 不做副作用，频繁 input 映射保持轻量。性能必须目标端量测，不能只从代码行数推断。

**无障碍**：文本标签、错误说明、按钮状态、足够点击目标和颜色对比需在 H5 与微信目标检查。自定义 view 模拟按钮容易丢语义；优先 button。表单提交后焦点/朗读恢复具有平台差异，自动静态检查不能证明完成。

## 15. 从零练习路径

### 15.1 预测

一个 input handler 读取 `event.target.value`。预测 H5 与微信目标可能出现什么差异，第一证据在哪里。再解释为什么给 event 标 `any` 不能修复。

### 15.2 构建

实现报修表单、工单卡片与自定义字段组件，分别构建 H5/微信；用成功、空值、超长、非法优先级和重复点击填矩阵。

### 15.3 故障注入

依次注入 DOM `<select>`、错误事件字段、固定 px 绝对定位、错误 `update:value` 事件。一次只改一个变量，记录首错、修复和同一验证重跑。

### 15.4 需求变更

新增“紧急等级必须显示文字和图标，不能只靠红色”。更新组件合同、两端快照与无障碍人工检查，不把判断复制到父子两处。

### 15.5 关闭 AI 复述

120 秒解释三层模型、内置组件、事件 detail、组件 v-model、rpx、scoped，以及模拟绿灯为什么不能证明真机 UI 一致。

## 16. 快速参考与复习

```text
容器/文本：view / text
语义操作：button + @click
输入值：input/textarea + detail.value 或受支持 v-model
组件模型：modelValue + update:modelValue
页面适配：rpx + Flex + 目标量测
样式边界：scoped 是编译隔离，不是 Shadow DOM
验证目标：H5 和 mp-weixin 分别构建/运行/记录
```

24 小时后写出一个不依赖 DOM 的受控 input；一周后从空目录重建卡片+表单并填差异矩阵；一个月后选择一个第三方组件，判断其 Props、事件、样式和目标支持边界。

自检：

1. `view` 为什么不等于能任意调用 DOM 的 `div`？
2. 为什么事件字段要由组件合同决定？
3. 组件 v-model 的两半分别是什么？
4. picker 索引为什么不能直接作为领域值？
5. rpx 为什么不能保证真机物理尺寸？
6. scoped 为什么不能保证所有原生组件内部样式可覆盖？

## 17. 版本、来源与复核边界

本章于 **2026-07-17** 复核 uni-app 官方 Vue 3 基础、组件、form、button 与页面文档。官方仍以 Vue 模板和内置组件为主，input/v-model、form-field、button 默认样式及平台支持均存在明确差异；目标项目必须锁定编译器并建立 H5/微信矩阵。

- [uni-app Vue 3 基础](https://uniapp.dcloud.net.cn/tutorial/vue3-basics.html)
- [uni-app Vue 3 组件](https://uniapp.dcloud.net.cn/tutorial/vue3-components.html)
- [uni-app 组件目录](https://uniapp.dcloud.net.cn/component/)
- [form 组件](https://uniapp.dcloud.net.cn/component/form.html)
- [button 组件](https://uniapp.dcloud.net.cn/component/button.html)
- [uni-app 页面](https://uniapp.dcloud.net.cn/tutorial/page.html)

稳定原理是状态驱动模板、Props/事件单向合同、表单值先解析、跨端组件优先、差异用目标矩阵证实。易变部分是组件属性、事件字段、样式支持、编译器转换、基础库和平台行为；升级后必须重跑 H5/微信目标证据。
