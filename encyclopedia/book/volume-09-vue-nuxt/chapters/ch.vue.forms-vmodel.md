---
schema_version: 2
edition: 2026.2-draft
id: ch.vue.forms-vmodel
title: 表单、v-model、修饰符与校验边界
responsibility: 把原生控件的 value/checked、事件与 Vue 状态通过 v-model 建立可追踪契约，区分显示校验、客户端校验和服务端权威校验。
volume: '09'
order: 3
level: L2
status: drafting
path: book/volume-09-vue-nuxt/chapters/ch.vue.forms-vmodel.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.vue.template-directives
- ch.web.forms-validation
- ch.js.scope-closures
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
  text: 在 120 秒内解释“表单、v-model、修饰符与校验边界”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - vue-vmodel-contract
  - vue-form-validation-boundary
  covers_topics:
  - vue.v-model-text
  - vue.v-model-checkbox-radio
  - vue.v-model-select
  - vue.v-model-modifiers
  - html.control-name-value
  - vue.form-submit
  - vue.field-error-state
  - vue.client-server-validation
  - vue.form-reset
  - vue.template-expression-boundary
  uses_capabilities:
  - web.html-semantic-form
  - web.javascript-language
  - web.javascript-functions-closures
  - web.vue-template
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现工单创建表单并保存状态、DOM、原生校验和提交负载四方对照；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - vue-vmodel-contract
  - vue-form-validation-boundary
  covers_topics:
  - vue.v-model-text
  - vue.v-model-checkbox-radio
  - vue.v-model-select
  - vue.v-model-modifiers
  - html.control-name-value
  - vue.form-submit
  - vue.field-error-state
  - vue.client-server-validation
  - vue.form-reset
  - vue.template-expression-boundary
  uses_capabilities:
  - web.html-semantic-form
  - web.javascript-language
  - web.javascript-functions-closures
  - web.vue-template
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: form-state-matrix-dom-value-check-submission-payload-check
- id: diagnose
  kind: fault-diagnosis
  text: 面对“字符串/数字转换、checkbox 值或重置逻辑错误造成的 UI 与模型漂移”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - vue-vmodel-contract
  - vue-form-validation-boundary
  covers_topics:
  - vue.v-model-text
  - vue.v-model-checkbox-radio
  - vue.v-model-select
  - vue.v-model-modifiers
  - html.control-name-value
  - vue.form-submit
  - vue.field-error-state
  - vue.client-server-validation
  - vue.form-reset
  - vue.template-expression-boundary
  uses_capabilities:
  - web.html-semantic-form
  - web.javascript-language
  - web.javascript-functions-closures
  - web.vue-template
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 表单、v-model、修饰符与校验边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《插值、绑定、事件、条件与列表指令》](ch.vue.template-directives.md)：v-model 是模板绑定与事件更新的受控组合，必须先理解指令和渲染条件。
- [《表单控件、提交语义与原生校验》](../../volume-07-web-platform/chapters/ch.web.forms-validation.md)：Vue 表单增强必须保留 label、控件、提交和原生约束语义。
- [《词法作用域、闭包与函数状态》](../../volume-08-javascript-typescript/chapters/ch.js.scope-closures.md)：模板处理器会捕获组件状态，需能解释函数与词法环境的关系。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文与配套工件可用于学习和作者自检，但不能证明学习者已经完成无 AI 独立构建、故障诊断或限时复述，也不会自动更新 `PROGRESS.md`。

模板章节解决了“状态怎样投影为 DOM”，这一章处理相反方向：用户在原生控件中输入、选择或取消选择时，DOM 的 `value`/`checked` 怎样回到 Vue 状态；提交时，哪些状态才允许进入请求负载；服务器拒绝后，错误又应放到哪里。`v-model` 不是一个神秘的表单对象，也不是校验器。它是针对控件种类约定好的一组属性绑定与事件监听，让一个 JavaScript 状态成为界面的来源。

本章以 FactoryCare 的“报告故障并创建初始工单”表单贯穿全过程。当前 API 合同没有直接创建工单的公开端点：前端向 `POST /api/v1/reports` 发送 `CreateReportRequest`，服务端在同一次幂等操作中创建 Report 与初始 WorkOrder。因此界面可以写“创建工单”，但代码和证据必须忠实记录真正的请求资源、字段与响应语义，不能用界面文案改写后端合同。

本章只讨论原生表单、`v-model`、同步客户端校验、错误显示、负载投影和重置。跨组件表单库、异步唯一性查询、上传流程、网络竞态、`watch`、生命周期与服务端实现均不在范围内。官方资料复核日为 **2026-07-17**；工件锁定具体工具版本是为了复现，并不声称这些补丁版本永久最新。

## 1. 完成标准：四方状态必须能逐项对照

“输入后页面看起来对”不是足够证据。学习者要保存同一场景下的四个观察面：

1. **Vue 状态**：例如 `draft.description` 是去除首尾空白后的字符串，`attachmentIds` 是由复选框值组成的数组，持续时间是数字还是空字符串。
2. **DOM 控件状态**：文本框的 `value`、单选与复选框的 `checked`、下拉框当前选项、错误元素文本与可访问属性。
3. **原生和客户端校验**：`checkValidity()`、字段级错误映射、何时允许提交、错误恢复后是否清除旧提示。
4. **提交负载**：实际投影出的 `CreateReportRequest`，不能混入纯界面字段，也不能漏掉合同必填字段。

完成本章需要留下三类成果：

- 120 秒复述 `v-model` 对各类控件展开成什么、三层校验各自能证明什么，并举出一个反例，例如租户授权不能由浏览器校验解决。
- 独立实现表单，对初始、输入、非法、提交、重置五类场景保存四方矩阵和可复现命令。
- 注入一次字符串/数字转换、checkbox 值或重置故障；先记录失败断言和第一可信证据，再修复并重跑相同验证，最后写出残余风险。

配套工件位于：

- [表单合同观察例](../../../examples/encyclopedia/ch.vue.forms-vmodel/README.md)
- [FactoryCare 四方状态实验](../../../labs/encyclopedia/ch.vue.forms-vmodel/README.md)
- [公开数字转换红灯练习](../../../exercises/encyclopedia/ch.vue.forms-vmodel/README.md)

私有解析不会进入公开练习。公开练习预期失败是起点，不是仓库故障；只有修复源码后同一验证器转绿，才形成有效的红—绿证据。

## 2. 先还原 `v-model`，再使用简写

理解表单问题最可靠的方法，是把简写还原成“读哪个 DOM 属性、听哪个事件、写回哪个状态”。对文本 `<input>` 和 `<textarea>`，近似关系是：

```vue
<input
  :value="draft.description"
  @input="draft.description = ($event.target as HTMLInputElement).value"
>

<!-- 等价目的的声明式简写 -->
<input v-model="draft.description">
```

这里不是两个状态互相猜测，而是 JavaScript 状态向控件提供 `value`，控件的 `input` 事件再更新同一个状态。Vue 官方文档明确把 JavaScript 状态视为来源；模板中静态的 `value`、`checked`、`selected` 初始属性不会覆盖已绑定状态。若服务端模板残留 `value="旧描述"`，而 `draft.description` 初始为空，挂载后应以空状态为准。

不同控件使用不同合同：

| 控件 | 读取/写入的 DOM 面 | 默认监听 | 模型的典型形状 |
|---|---|---|---|
| text、textarea | `value` | `input` | `string` |
| 单个 checkbox | `checked` | `change` | `boolean` 或自定义 true/false 值 |
| checkbox 组 | `checked` + 每项 `value` | `change` | 选中值数组/Set |
| radio 组 | `checked` + 当前项 `value` | `change` | 一个标量值 |
| select | 当前选项的 `value` | `change` | 单值或多值数组 |

所以“所有 `v-model` 都只是 `value` 加 `input`”是错误心智模型。看到 checkbox 不更新时，第一步不是加 `@input`，而是先问模型是布尔值还是集合、模板是否给每一项提供了正确 `value`、浏览器实际改变的是 `checked` 还是 `value`。

### 2.1 模板表达式边界

`v-model` 后面必须是可赋值位置，例如 `draft.description`、`selectedPriority`，不能是 `description.trim()`、`openCount + 1` 或函数调用结果。右边需要能承接事件写回。转换应由修饰符、事件处理函数或提交投影完成，不要把多步业务规则塞进模板表达式。

组件方法可以捕获 `draft` 与 `errors`，这是已学过的词法作用域；模板只负责把事件连接到方法。方法名表达意图，例如 `submitDraft`、`resetDraft`，比模板里连续赋值四个字段更容易测试和诊断。

## 3. 文本输入：字符串、IME 与 `<textarea>`

普通文本字段使用 `v-model` 即可。FactoryCare 描述字段可以用 `.trim` 在写回时移除首尾空白：

```vue
<label for="description">故障描述</label>
<textarea
  id="description"
  v-model.trim="draft.description"
  name="description"
  required
  minlength="10"
  maxlength="5000"
  aria-describedby="description-help description-error"
/>
<p id="description-help">请描述现象、位置和发生时间。</p>
<p v-if="errors.description" id="description-error" role="alert">
  {{ errors.description }}
</p>
```

`<textarea>{{ draft.description }}</textarea>` 不是 Vue 中正确的双向绑定方式；文本节点不会承担后续输入写回，应使用 `v-model`。`.trim` 解决的是边缘空白，不会把连续内部空格、换行或危险内容“净化”。服务端仍需按合同校验长度并在输出位置安全编码。

输入法组合期间，Vue 的文本 `v-model` 不会在每个未完成的拼音/注音组合片段上更新，这能避免把半成品当作最终文字。如果产品确实要观察组合中的每次变化，需要显式处理 `input`/composition 事件并定义业务理由；不能假设默认 `v-model` 提供这种语义。校验提示通常应等组合完成后再更新，避免中文输入时不断报错。

`name` 和 `v-model` 也不是替代关系。`name` 是浏览器原生表单提交、自动填充和辅助技术常用的字段身份；`v-model` 是 Vue 状态合同。即使最终使用 JSON 请求，保留有意义的 `name`、`label` 和原生控件类型仍有价值。

## 4. checkbox：先决定布尔合同还是集合合同

一个“我确认信息准确”的 checkbox 适合布尔模型：

```vue
<label>
  <input v-model="confirmed" name="confirmed" type="checkbox">
  我确认已核对设备与描述
</label>
```

`confirmed` 是提交前的客户端保护，但不属于 `CreateReportRequest`，因此负载投影必须排除它。浏览器中的勾选也不能证明报告真实、用户有权限或设备属于当前租户。

多个附件选择使用数组模型。每个 checkbox 的 `value` 必须是服务端识别的已完成上传 UUID：

```vue
<label v-for="attachment in completedAttachments" :key="attachment.id">
  <input
    v-model="draft.attachmentIds"
    type="checkbox"
    name="attachmentIds"
    :value="attachment.id"
  >
  {{ attachment.name }}
</label>
```

当一项选中，Vue 把它的 `value` 加入数组；取消时移除。若漏写 `:value`，浏览器默认值常成为字符串 `"on"`，页面仍显示“已勾选”，但请求不再是 UUID 数组。第一可信证据是 Vue 状态里的 `attachmentIds` 已出现 `"on"`，而不是等待服务器返回泛化的 400。验证器应同时断言 `checked`、数组内容与最终 payload。

数组内最多三个附件是 FactoryCare 合同约束。客户端可立即提示第 4 项，但服务端必须再次验证数量、UUID、上传用途为 `REPORT_CREATION`、上传已完成以及访问权限。客户端缓存的附件列表可能过期，所以“界面只显示合法项”不能替代权威检查。

## 5. radio 与 select：值的类型来自绑定方式

优先级是互斥枚举，适合一组 radio：

```vue
<fieldset>
  <legend>优先级</legend>
  <label v-for="option in priorityOptions" :key="option.value">
    <input
      v-model="draft.priority"
      type="radio"
      name="priority"
      :value="option.value"
      required
    >
    {{ option.label }}
  </label>
</fieldset>
```

相同 `name` 保留原生互斥语义，`v-model` 让枚举值进入状态，`value` 决定写回什么。若使用静态 `value="HIGH"`，结果是字符串；若用 `:value="someObject"`，模型可能得到对象引用。请求合同只接受 `LOW | MEDIUM | HIGH | CRITICAL`，所以应绑定稳定字符串而不是整个展示对象。

故障类别可用 select。推荐先提供值为空字符串且禁用的提示项：

```vue
<label for="category">故障类别</label>
<select id="category" v-model="draft.category" name="category" required>
  <option disabled value="">请选择类别</option>
  <option v-for="category in categories" :key="category" :value="category">
    {{ category }}
  </option>
</select>
```

模型初始也设为 `''`，这样原生 `required` 能把“尚未选择”识别为非法。Vue 官方表单指南特别提醒：若 select 初值不匹配任何 option，某些 iOS 情况下选择第一项可能不触发 change；空值提示项同时让初始状态和交互更明确。不要把展示标签“机械故障”误当作 API 值，除非合同确实如此；显示文本与提交值是两个维度。

## 6. 三个修饰符，各自只解决一个窄问题

### 6.1 `.lazy`：从 `input` 改为 `change`

`v-model.lazy` 不再随每次 `input` 写回，而在 `change` 时同步。它适合只需在提交/离开字段时更新的窄场景，但会让用户正在看见的 DOM 值与 Vue 状态短暂不同。若实时字符计数、按钮可用性或错误提示依赖该字段，`.lazy` 会改变产品行为，不能当性能开关随手添加。

证据矩阵应分别触发 `input` 与 `change`，否则测试可能误以为绑定坏了。故障定位时先确认事件时间点，再检查转换与业务校验。

### 6.2 `.number`：尽早暴露数字边界，但仍是联合类型

HTML 控件的 `value` 原本是字符串。一个只用于界面观察、不会进入创建报告负载的“症状持续分钟数”可以写：

```vue
<input
  v-model.number="symptomDurationMinutes"
  name="symptomDurationMinutes"
  type="number"
  min="0"
  step="1"
>
```

Vue 使用类似 `parseFloat()` 的转换：可解析输入写为数字，无法解析时保留原字符串，空输入返回 `''`；`type="number"` 也会自动应用数字修饰行为。因此 TypeScript 中不能草率声明它永远是 `number`，应建模为 `number | ''`（若接受无法解析的程序化输入，还需考虑字符串）并在业务边界缩窄。

漏掉 `.number` 的典型故障不是马上崩溃，而是 `"30" + 5` 得到 `"305"`、严格相等失败，或把不属于 API 的字段混进 payload。第一可信证据是输入后对状态做 `typeof` 观察。注意 FactoryCare `CreateReportRequest` 的 `additionalProperties` 为 false，本章的持续时间是教学用 UI 状态，提交投影必须排除它。

### 6.3 `.trim`：清理边缘空白，不改变校验权威

`.trim` 可使只含空格的描述更快暴露为空，也减少偶然首尾空格，但它不会验证 10–5000 长度、不会判断内容质量、不会防止越权或脚本注入。若空白本身具有业务意义（例如精确代码块），就不应使用。修饰符是输入映射，不是完整业务规则。

## 7. 提交：一个入口、显式投影、可观察结果

表单应保留真实 `<form>` 和 submit 按钮，让 Enter 提交、原生约束与辅助技术语义都能工作：

```vue
<form @submit.prevent="submitDraft">
  <!-- controls -->
  <button type="submit">提交报告并创建工单</button>
</form>
```

`.prevent` 调用 `preventDefault()`，避免浏览器导航/表单编码提交；它不会自动校验、不会发送请求，也不会阻止处理器执行。处理器应遵循清晰阶段：清除旧客户端错误 → 读取当前状态 → 同步校验 → 若非法则显示/聚焦 → 投影允许字段 → 交给后续网络层。不要让 click 处理器和 submit 处理器各做一套逻辑，否则鼠标点击与 Enter 键会产生两个合同。

请求投影必须列举字段，而不是扩展整个 UI 状态：

```ts
type CreateReportRequest = {
  assetId: string
  category: string
  description: string
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'
  contact?: string | null
  attachmentIds?: string[]
}

function buildPayload(): CreateReportRequest {
  return {
    assetId: draft.assetId,
    category: draft.category,
    description: draft.description,
    priority: draft.priority,
    contact: draft.contact === '' ? null : draft.contact,
    attachmentIds: [...draft.attachmentIds],
  }
}
```

这样 `confirmed`、`symptomDurationMinutes`、本地错误、提交中标志和租户信息都不会意外泄漏。`attachmentIds` 复制为新数组，保存的请求证据不会因为用户随后取消勾选而被同一个引用静默改写。真实网络层还需要 `Idempotency-Key` 请求头；重试必须复用同一业务操作的 key，不能靠禁用按钮假装解决重复提交。

不要发送 `tenantId` 让客户端自报租户。服务端应从认证上下文确定租户和主体，再检查 `assetId`、附件与权限。即使前端选择器只展示当前租户设备，攻击者仍可直接构造 JSON。

## 8. 三层校验：体验、结构与权威不能混为一谈

把“校验”拆成层次，错误归因会清楚很多。

### 8.1 显示校验

显示校验回答“错误是否贴近字段、是否可理解、是否可被读屏感知、修正后是否恢复”。它包括：稳定的可见 label、帮助文本、`aria-describedby`、字段错误、表单级摘要、焦点顺序、非颜色单一提示、提交中状态。显示正确不证明输入合法。

错误文本应说明如何恢复，例如“描述至少 10 个字符”，而不是“参数非法”。动态紧急错误可使用 `role="alert"`；普通状态更新可用合适的 `aria-live`，避免所有按键都触发打断性播报。错误元素应有稳定 id，控件只在错误存在时设置 `aria-invalid="true"`。焦点环要清晰，触控目标尽量不小于约 44×44 CSS 像素；这些是本章工件的 UI/UX 自检方向，不替代真实辅助技术测试。

### 8.2 原生约束与同步客户端校验

`required`、`minlength`、`maxlength`、`min`、`max`、`pattern` 提供浏览器可理解的基础约束，`checkValidity()` 可形成一条证据。客户端函数可补充跨字段规则，例如必须确认、附件不能超过三项。两者价值是快速反馈和减少无效请求。

但程序化赋值、浏览器差异和测试工具可能绕过某些交互检查。测试既要观察约束属性，也要用实际元素的 `checkValidity()`，还要直接验证客户端函数的错误映射。不要只截一张红色边框图片。

### 8.3 服务端权威校验

FactoryCare 服务端最终验证：主体是否认证、资产是否属于可访问租户、字段是否符合 schema、附件 UUID/用途/状态/数量是否有效、幂等键是否合法、当前资源状态是否允许操作。客户端无法证明这些事实，也不能把服务端拒绝统一翻译为“网络错误”。

如果服务端返回可映射的字段问题，应把允许公开的消息映射到 `errors[field]`；全局冲突、权限或幂等问题放表单级摘要。不要把内部堆栈、SQL、租户存在性细节展示给用户。服务端错误在用户再次编辑相关字段后何时清除，需要明确策略，避免旧错误永远挂着或过早消失。

## 9. FactoryCare 的真实字段合同

本章工件采用以下投影，而不是自创 WorkOrder 请求：

| 字段 | UI 控件 | 客户端模型 | `CreateReportRequest` 约束 |
|---|---|---|---|
| `assetId` | 设备 select | UUID 字符串 | 必填 UUID，服务端再查可见性 |
| `category` | 类别 select | 字符串 | 必填，1–64 字符 |
| `description` | textarea + `.trim` | 字符串 | 必填，10–5000 字符 |
| `priority` | radio 组 | 枚举字符串 | LOW/MEDIUM/HIGH/CRITICAL |
| `contact` | text + `.trim` | 字符串，投影为空时 `null` | 可选/nullable，最多 200 |
| `attachmentIds` | checkbox 组 | UUID 字符串数组 | 可选，最多 3，且必须是完成的报告用途上传 |
| `confirmed` | checkbox | 布尔值 | 纯 UI 客户端门槛，不提交 |
| `symptomDurationMinutes` | number + `.number` | `number | ''` | 教学观察字段，不提交 |

提交成功的服务器语义是创建 Report 与初始 WorkOrder 恰好一次，而不是客户端先后发两个请求。若 UI 先 `POST /reports` 再尝试一个不存在的 `/work-orders`，会制造半成功状态，也背离合同。页面上可以展示服务端返回的资源标识，但不能提前生成一个看似权威的工单编号。

## 10. 重置：原生控件和 Vue 状态必须同向回到基线

表单重置是最容易产生“看着清空、实际仍提交旧值”的位置。只调用 `form.reset()` 会让原生控件回到 HTML 默认值，但 Vue 模型可能仍保留旧状态；下一次渲染又可能把旧状态写回 DOM。只替换部分模型则可能留下 `attachmentIds`、错误或上一次 payload。

可靠做法是定义单一默认值工厂，并让 Vue 状态回到它：

```ts
function createEmptyDraft(): Draft {
  return {
    assetId: '',
    category: '',
    description: '',
    priority: 'MEDIUM',
    contact: '',
    attachmentIds: [],
  }
}

function resetDraft() {
  Object.assign(draft, createEmptyDraft())
  confirmed.value = false
  symptomDurationMinutes.value = ''
  errors.value = {}
  submittedPayload.value = null
}
```

若使用 `reactive` 对象，`Object.assign` 保持代理身份；若使用 `ref`，可整体替换 `.value`。重置后要等待 Vue 完成 DOM 更新再读取，例如测试中 `await nextTick()`。证据至少包括每个控件 value/checked、Vue 状态 JSON、错误区为空和 payload 证据清除。不要用页面刷新代替重置逻辑。

默认值本身也属于产品合同。优先级是否默认为 MEDIUM、是否应强迫用户显式选择，需要产品决定并记录；本章工件选择 MEDIUM 是可复现示例，不宣称适用于所有部署。

## 11. 状态矩阵：用固定观察面阻止“修一处、坏一处”

建议保存如下表格，实际证据填入精确值而不是“正常”：

| 场景 | DOM | Vue 状态 | 原生/客户端错误 | payload |
|---|---|---|---|---|
| 初始 | description=`''`，附件均未选 | 空 draft，priority=MEDIUM | required 不满足，尚未显示客户端错误 | `null` |
| 输入 | DOM 反映用户值 | trim/number/checkbox 映射后值 | 合法字段无错误 | 仍为 `null` |
| 非法提交 | 缺 asset、短描述 | 与 DOM 一致 | 字段提示 + `aria-invalid` | 仍为 `null` |
| 合法提交 | 所有控件值稳定 | 可投影状态完整 | 无客户端错误 | 精确等于允许字段 |
| 重置 | value/checked 回基线 | 全部回默认 | 错误清空 | `null` |

四方不是四份独立可变数据。DOM 是状态的控件投影，错误是校验结果，payload 是允许字段的快照；真正可编辑的来源应尽量只有一份。若为了“方便”再维护 `payloadDraft` 并用 watch 同步，就创造了第五个漂移面，还提前引入了副作用。

## 12. 三类注入故障与第一可信证据

### 12.1 数字仍是字符串

症状：输入 30，界面显示 30，但计算或严格类型断言失败。诊断顺序：记录 `input.value`（必然是字符串）→ 记录 `symptomDurationMinutes` 和 `typeof` → 检查 `v-model.number` → 用同一输入重跑。不要因为 `Number(state)` 能临时通过就忽略模型合同；要决定转换应发生在输入边界还是投影边界。

### 12.2 checkbox 写入错误值

症状：勾选附件后 `checked=true`，请求却含 `"on"` 或整个对象。第一可信证据是数组内容与绑定 `:value` 不一致。修复后重跑选中、取消、两项、多于三项和重置，不只重跑一条 happy path。

### 12.3 原生 reset 造成双轨

症状：点击重置后 DOM 短暂为空，但模型/下一次 payload 仍含旧描述。先在同一时刻输出 DOM value 和模型值，证实分叉发生在 reset 阶段；再统一重置 Vue 来源并等待渲染。不要在测试里手动把 DOM value 改空来“修”产品源码。

所有诊断都按同一格式保存：可复现输入 → 预期 → 实际 → 第一处偏离 → 根因 → 最小范围修复 → 原命令重跑 → 残余风险。服务器未联调、真实 IME、移动 Safari、密码管理器/自动填充和辅助技术行为若未测试，必须明确列为未验证。

## 13. 可访问与可恢复交互清单

表单是高交互密度界面，视觉整洁不能牺牲语义：

- 每个控件有可见、唯一、可点击的 label；一组 radio/checkbox 用 `fieldset` 与 `legend`。
- 帮助文本和错误通过 id 关联，错误不仅靠颜色；键盘焦点环保持可见。
- submit 与 reset 使用正确 `type`，避免普通按钮在 form 内默认提交。
- 非法提交后把焦点移到错误摘要或首个非法字段，但不要每次按键都抢焦点。
- 提交中可禁用重复触发并显示进度，真正的重复保护仍由服务端幂等处理。
- 成功/失败状态使用可感知文本；不要只把按钮从蓝变绿。
- 布局在窄屏保持标签和错误完整，长错误、200 字符 contact、5000 字符描述不会遮挡按钮。

这些规则来自本章 UI/UX 检索对企业表单、错误恢复、键盘与实时反馈的筛选。配套工件只自动验证其中可确定的 DOM 属性；真实焦点顺序、读屏播报、触控尺寸和浏览器自动填充仍需人工/设备测试。

## 14. 自动化验证应断言合同，不应复制实现

好的测试通过用户可见控件输入并读取状态证据，而不是直接调用所有内部方法。建议覆盖：

1. 初始状态与 DOM 的默认值一致。
2. 文本输入和 `.trim` 的结果明确，数字字段写成数字/空字符串。
3. radio/select 写入合同值，checkbox 组按 value 增删数组。
4. 原生 `checkValidity()` 对必填和长度用例产生预期结果。
5. 非法 submit 显示字段错误、设置 `aria-invalid`，payload 仍为空。
6. 合法 submit 只包含 `CreateReportRequest` 字段，数组为快照，不包含 UI-only 状态。
7. reset 后 DOM、模型、错误和 payload 全部回基线。
8. 注入故障先红；修复后用完全相同输入和断言转绿。

不要断言组件内部变量名或 CSS 类层级，除非它们就是合同。对浏览器原生校验的模拟环境要诚实：Happy DOM/jsdom 能覆盖一部分约束与事件，但不能代表每个浏览器的气泡文案、IME 或自动填充。构建成功证明 SFC 可被工具链处理，不证明表单业务正确；两类证据必须分开报告。

## 15. 实验路线

### 阶段 A：建立合法基线

运行示例验证器，记录 Node、pnpm、Vue、Vite、TypeScript、Vitest 版本。依次输入资产、类别、描述、优先级、contact、两个附件、持续分钟数与确认框，保存四方矩阵。确认 payload 的顶层键集合精确，没有 `tenantId`、`confirmed` 或 `symptomDurationMinutes`。

### 阶段 B：注入并定位

实验目录提供一个只调用原生 `form.reset()` 的故障实现。先输入可辨识值并提交，再触发故障重置；在任何修改前记录 DOM 与模型第一次分叉的位置。另可自行选择漏 `.number` 或漏 checkbox `:value`，但一次只注入一种，以免无法判断第一根因。

### 阶段 C：修复并回归

把重置所有权收回 Vue 默认值工厂，清理错误和 payload，运行原验证。再回归非法提交和合法提交，避免“重置变绿但提交变坏”。保存命令、退出码与关键断言摘要。

### 阶段 D：写边界说明

列出未验证项：真实 API/认证、幂等重试、上传完成态、服务端错误格式、实际浏览器与辅助技术。若没有这些证据，只能声称本地状态合同通过，不能声称端到端创建工单已验证。

## 16. 120 秒复述模板

可以按以下顺序组织，不必背原文：

> `v-model` 把 Vue 状态绑定到不同原生控件的 `value` 或 `checked`，并通过 `input` 或 `change` 写回；文本、单 checkbox、checkbox 数组、radio 和 select 的模型形状不同。`.lazy` 改事件时机，`.number` 做尽力数字转换且空值仍可能是字符串，`.trim` 只去边缘空白。表单保留原生语义并从一个 submit 入口同步校验，再显式投影 `CreateReportRequest`。显示校验改善恢复，客户端校验提供快速反馈，服务器才有 schema、授权、租户、附件和幂等的最终权威。重置必须重置 Vue 来源、错误与 payload，而不能只重置 DOM。证据是初始、输入、非法、提交、重置的 DOM/状态/错误/负载四方矩阵。反例：不能用隐藏 option 或前端 required 实现租户授权。

如果无法在 120 秒内说明 checkbox 数组为什么依赖 `value`、`.number` 为什么不保证恒为 number、服务器为什么仍须校验，说明还没有掌握边界。

## 17. 自检题

1. 为什么绑定后的静态 `value` 不是初始数据权威？
2. 单个 checkbox 与 checkbox 组的模型形状有何不同？漏 `value` 的第一证据在哪里？
3. `.lazy` 会改变哪一个事件时点？它为什么可能破坏实时字符计数？
4. `.number` 遇到空输入返回什么？TypeScript 类型该怎样表达？
5. 为什么 `confirmed` 与症状持续时间不能直接展开进请求？
6. 为什么 `@click.prevent` 绑在按钮上不如 form 的 `@submit.prevent` 完整？
7. 原生约束、客户端函数和服务端校验各自能证明什么？
8. `form.reset()` 单独使用时，DOM 和 Vue 状态怎样分叉？
9. 为什么成功创建 Report 后不能再由客户端补发一个虚构的直接建单请求？
10. 若服务端返回权限错误，为什么不应伪装成 description 字段错误？

答案应引用自己的矩阵、测试或 API 合同，而不只复述术语。

## 18. 边界与下一章

本章用了响应式状态作为已有容器，但没有解释依赖追踪、代理身份、计算缓存或解构丢失；下一章专门处理 `ref`、`reactive`、`computed` 与只读边界。本章也没有用 `watch` 自动提交或调用网络，因为那会把控件合同、派生状态和副作用所有权混在一起。后续副作用章节会讨论取消、竞态与清理。

### 官方资料

- [Vue：Form Input Bindings](https://vuejs.org/guide/essentials/forms.html)
- [Vue：Accessibility](https://vuejs.org/guide/best-practices/accessibility.html)
- [MDN：Client-side form validation](https://developer.mozilla.org/en-US/docs/Learn_web_development/Extensions/Forms/Form_validation)
- [MDN：HTMLFormElement.checkValidity()](https://developer.mozilla.org/en-US/docs/Web/API/HTMLFormElement/checkValidity)

### 本地合同依据

- FactoryCare [public-api.yaml](../../../factorycare-design/contracts/public-api.yaml) 中 `POST /api/v1/reports`、`CreateReportRequest` 与幂等头定义
- `curriculum/chapters/volume-09.yml` 中本章责任、主题、G4 验收与三项 outcome

资料能证明 API/框架语义；本地工件验证的是受控环境中的状态合同。两者都不能替代真实部署的鉴权、跨租户隔离、浏览器兼容、读屏与端到端网络验证。
