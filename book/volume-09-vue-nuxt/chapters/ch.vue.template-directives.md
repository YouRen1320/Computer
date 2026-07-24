---
schema_version: 2
edition: 2026.2-draft
id: ch.vue.template-directives
title: 插值、绑定、事件、条件与列表指令
responsibility: 用模板表达文本、属性、事件、条件和列表渲染，解释 key 的身份作用，不在本章引入 v-model、复杂组件通信或副作用。
volume: '09'
order: 2
level: L1-L2
status: drafting
path: book/volume-09-vue-nuxt/chapters/ch.vue.template-directives.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.vue.vite-sfc
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
  text: 在 120 秒内解释“插值、绑定、事件、条件与列表指令”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - vue-template-binding
  - vue-template-control-events
  covers_topics:
  - vue.text-interpolation
  - vue.v-bind
  - vue.class-style-binding
  - vue.template-expression-boundary
  - vue.v-on
  - vue.v-if-show
  - vue.v-for
  - vue.list-key-identity
  - vue.event-modifier
  uses_capabilities:
  - web.javascript-language
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现可筛选和选择的工单列表模板并保存空态、列表和交互 DOM 证据；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - vue-template-binding
  - vue-template-control-events
  covers_topics:
  - vue.text-interpolation
  - vue.v-bind
  - vue.class-style-binding
  - vue.template-expression-boundary
  - vue.v-on
  - vue.v-if-show
  - vue.v-for
  - vue.list-key-identity
  - vue.event-modifier
  uses_capabilities:
  - web.javascript-language
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: render-case-matrix-dom-inspection-console-warning-check
- id: diagnose
  kind: fault-diagnosis
  text: 面对“漏 key、错误条件或事件修饰符导致的节点复用和交互异常”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - vue-template-binding
  - vue-template-control-events
  covers_topics:
  - vue.text-interpolation
  - vue.v-bind
  - vue.class-style-binding
  - vue.template-expression-boundary
  - vue.v-on
  - vue.v-if-show
  - vue.v-for
  - vue.list-key-identity
  - vue.event-modifier
  uses_capabilities:
  - web.javascript-language
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 插值、绑定、事件、条件与列表指令

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Vite、Vue 应用、SFC 与项目结构》](ch.vue.vite-sfc.md)：模板必须位于可运行 SFC 中，编译错误与浏览器结果需要有稳定观察入口。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文和验证工件可以用于学习与作者自检，但不代表学习者已经完成无 AI 独立构建、故障诊断或限时复述，也不会自动修改 `PROGRESS.md`。

上一章让 Vue 根组件成功挂载，本章回答下一个问题：怎样把一组工单数据清楚、安全、可操作地表达为 DOM？模板不是把 JavaScript 字符串拼成 HTML 的便捷写法，而是一种由编译器检查、由 Vue 运行时更新的声明。插值决定文本，`v-bind` 决定属性，`v-on` 连接事件，`v-if`/`v-show` 控制可见结构，`v-for` 展开集合，`key` 告诉更新算法每一项是谁。

本章用 FactoryCare 工单列表贯穿空态、单项、多项、筛选、选择和节点重排。为了让交互可观察，示例使用极少量 `ref` 作为现成状态容器，但不解释依赖追踪、`reactive`、`computed` 或副作用；这些属于后续响应式章节。本章也不引入 `v-model`、复杂组件通信、网络请求、watch 或生命周期。

官方资料复核日为 **2026-07-17**。复核时 Vue 3 是当前主版本，本文只使用稳定的基础模板能力，不依赖实验性编译特性。工件锁定精确包版本是为了复现，不代表补丁号永久最新。

## 1. 完成标准：DOM 矩阵而不是“点起来好像行”

需要留下三类证据：

1. **解释**：120 秒内说清插值、属性绑定、类/样式绑定、事件、条件、列表与 `key` 的职责，给出一个不应由模板解决的反例，例如服务端租户授权不能靠 `v-if`。
2. **构建**：独立实现可筛选、可选择的工单列表；为零项、一项、多项、条件切换和事件输入保存 DOM 文本、属性、列表数量与节点身份矩阵；开发控制台无 key 警告。
3. **诊断**：注入漏 `key`/错误 `key`、反向条件或错误事件修饰符，先保存失败断言和第一可信证据，再修复并重跑同一矩阵，说明未覆盖的浏览器或异步风险。

配套工件：

- [模板指令观察例](../../../examples/encyclopedia/ch.vue.template-directives/README.md)
- [FactoryCare 工单列表实验](../../../labs/encyclopedia/ch.vue.template-directives/README.md)
- [公开 key 身份红灯练习](../../../exercises/encyclopedia/ch.vue.template-directives/README.md)

私有解析不进入公开练习。验证器同时检查源码指令与真实 Vue 渲染更新；把断言改成接受索引 key、删除重排用例或打印假 `PASS` 都不算完成。

## 2. 声明式模板的最小模型

命令式代码会说“找到第 3 个 `<li>`，把文字改成 X，再给它添加 class”；声明式模板说“对当前可见工单中的每一项，渲染一个以工单 ID 为身份的 `<li>`，若被选择则绑定选中类”。当状态改变，Vue 重新求值模板所依赖的表达式并修补 DOM。

可以把一次更新简化为：

```text
组件状态/输入
  ↓ 求值模板表达式
新的虚拟节点描述
  ↓ 与旧描述比较（key 提供身份线索）
最小化修补真实 DOM
```

这是调试模型，不承诺 Vue 内部永远采用某个具体数据结构。重要的是：模板描述目标结果；事件改变状态；运行时负责把旧 DOM 更新到新结果。手工再用 `document.querySelector(...).textContent = ...` 修改同一节点会制造两个事实来源，下次渲染可能覆盖它。

## 3. 数据先有明确形状

FactoryCare 公共合同中的 `WorkOrderSummary` 要求 `id`、`number`、`assetId`、`status`、`priority`、`version`、`createdAt`，可选 `slaDueAt`。本章为界面聚焦保留一个只读最小投影：

~~~ts
type WorkOrderStatus =
  | 'CREATED'
  | 'TRIAGED'
  | 'ASSIGNED'
  | 'ACCEPTED'
  | 'IN_PROGRESS'
  | 'PENDING_PARTS'
  | 'PENDING_APPROVAL'
  | 'RESOLVED'
  | 'VERIFIED'
  | 'CLOSED'
  | 'REOPENED'
  | 'CANCELLED'

type Priority = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'

interface WorkOrderListItem {
  id: string
  number: string
  status: WorkOrderStatus
  priority: Priority
  createdAt: string
}
~~~

不把 `REASSIGNED` 发明成状态；FactoryCare 转派替换 assignment 记录而不创建新工单状态。模板只呈现已经授权、已经验证的对象；它不决定状态迁移合法性，也不信任客户端提供的 tenantId。

## 4. 文本插值 `{{ }}`

双大括号把表达式结果作为文本内容写入：

~~~vue
<h2>待处理工单（{{ visibleOrders.length }}）</h2>
<p>当前筛选：{{ activeStatus }}</p>
~~~

它适合人可读文本，不适合 HTML 属性，也不会把字符串当作可执行 HTML。若 `number` 是 `<img src=x onerror=alert(1)>`，普通插值会转义为文本，这是一条重要的默认安全边界。

插值只在文本位置工作。下面不会动态绑定属性：

```vue
<button aria-label="选择 {{ order.number }}">错误</button>
```

属性应使用 `v-bind`。调试“页面显示旧值”时，先确认表达式实际引用了什么名称、该名称是否在模板作用域、DOM 文本是否更新，再进入响应式内部；不要先删除插值括号。

## 5. 模板表达式的边界

模板允许单个 JavaScript 表达式，例如属性访问、条件运算、方法调用和数组长度：

~~~vue
<span>{{ order.number.toUpperCase() }}</span>
<span>{{ order.priority === 'CRITICAL' ? '紧急' : '常规' }}</span>
~~~

它不是任意语句容器。`if`、`for` 声明、变量声明和多条以分号分隔的流程不应塞进插值。复杂映射若反复出现，应在脚本里命名，让模板表达“是什么”，而不是堆满“怎么算”。

表达式也运行在受限模板上下文，不应期待任意全局变量可用。模板中执行昂贵排序或过滤，会在每次相关渲染时重新工作；小列表教学可以直观展示，真实大列表应把派生规则放到后续 `computed`，并用测量决定优化。

## 6. `v-bind`：把表达式绑定到属性

`v-bind:属性="表达式"` 的缩写是 `:属性="表达式"`：

~~~vue
<button
  type="button"
  :aria-pressed="selectedId === order.id"
  :aria-label="`选择工单 ${order.number}`"
  :disabled="order.status === 'CLOSED'"
>
  选择
</button>
~~~

没有冒号时，值是字面字符串。`:disabled="false"` 会按布尔属性语义移除 `disabled`；写成 `disabled="false"` 仍然存在该布尔属性，按钮会被禁用。调试属性时要在 Elements/属性 API 看最终值，不要仅看源码文本。

动态参数 `:[name]` 存在，但会扩大可读性和安全审查面，本章不需要。工单列表的属性集合稳定，应显式写出来。

## 7. class 绑定：状态不是颜色

对象语法适合按布尔条件添加类：

~~~vue
<li
  class="work-order"
  :class="{
    'work-order--selected': selectedId === order.id,
    'work-order--critical': order.priority === 'CRITICAL',
  }"
>
~~~

静态 `class` 与动态 `:class` 会合并。数组语法也能组合多个类，但不要为了炫技嵌套难读结构。对状态徽标，CSS 颜色只能作为补充，必须保留可读文字，例如“优先级：紧急”，不能只显示红点。选中状态同时使用 `aria-pressed` 或可见文字，确保键盘、屏幕阅读器和无法区分颜色的用户能理解。

从设计系统角度，类名表达组件状态，不把业务枚举直接变成任意 CSS。来自服务器的字符串不能直接当作可信类名拼进选择器；建立显式映射才能控制外观集合。

## 8. style 绑定与单位

可以绑定样式对象：

~~~vue
<div :style="{ inlineSize: completionPercent + '%' }"></div>
~~~

数字值是否自动添加单位取决于 CSS 属性；布局尺寸最好明确单位。动态 style 适合真正连续的值，离散状态优先 class，便于主题、媒体查询和审查。本章列表不需要内联颜色，避免把业务状态与色值硬编码在模板。

不得把不可信字符串直接绑定成任意 `style` 或 URL。Vue 安全文档提醒，样式和 URL 都可能形成安全问题；服务端应校验可接受范围，客户端再用白名单映射。

## 9. `v-on`：把用户事件连接到状态改变

`v-on:click="handler"` 缩写为 `@click="handler"`：

~~~vue
<button type="button" @click="selectOrder(order.id)">
  选择 {{ order.number }}
</button>
~~~

`@click="selectOrder"` 传递方法处理器，Vue 会把原生事件交给它；`@click="selectOrder(order.id)"` 是内联调用，适合传当前项 ID。复杂流程放入有名字的函数，便于测试与错误栈定位。

事件处理器是副作用发生的常见入口，但本章只改变本地选择/筛选值，不发网络请求，不用 watch。真实“派单”“关闭”必须调用具体受权命令并处理并发版本，不能因为按钮被点就直接改列表对象的 `status`。

## 10. 为什么原生 `<button>` 优于可点击 `<div>`

按钮自带键盘激活、焦点语义、禁用行为和辅助技术角色。若用 `<div @click>`，还要补 `role`、`tabindex`、Enter/Space 键盘处理、禁用语义和焦点样式，极易遗漏。模板指令不改变 HTML 语义原则。

本章工件的筛选与选择控件都使用 `button type="button"`，提供可见焦点，目标尺寸至少约 44×44 CSS 像素，`aria-pressed` 表示开关状态。hover 只做增强，不作为唯一反馈。

## 11. 事件修饰符把 DOM 细节留在模板

Vue 支持 `.stop`、`.prevent`、`.self`、`.capture`、`.once`、`.passive` 和键/鼠标相关修饰符。例如卡片可点击选择，而内部链接不应触发卡片：

~~~vue
<li @click="selectOrder(order.id)">
  <button type="button" @click.stop="openDetails(order.id)">查看详情</button>
</li>
~~~

`.stop` 调用停止传播；`.prevent` 阻止默认行为。两者不是同义词。修饰符的顺序会影响生成代码，`@click.prevent.self` 与 `@click.self.prevent` 的范围不同。只有明确需要时使用，并用事件矩阵验证父子处理器计数。

不要滥用 `.prevent` 破坏链接、表单或键盘的原生行为；不要把 `.passive` 与 `.prevent` 组合。浏览器会警告被动监听器不能阻止默认动作。事件异常的第一可信证据通常是处理器计数、默认行为或控制台警告，而不是“用户说点了两次”。

## 12. `v-if`：结构存在或不存在

~~~vue
<p v-if="visibleOrders.length === 0" class="empty-state">
  当前筛选没有工单。
</p>
<ul v-else aria-label="工单列表">
  <!-- items -->
</ul>
~~~

`v-if` 条件为假时，不渲染该分支；切换可能创建/销毁分支。相邻的 `v-else-if`、`v-else` 必须紧跟对应分支。空态应有清楚文本和下一步，而不是只留空白区域。

错误条件常来自变量名写错、真值规则误解、把“原始列表为空”和“筛选结果为空”混用。验收必须分别覆盖：原始零项、原始有项但筛选零项、筛选一项、筛选多项。

## 13. `<template v-if>`：分组而不增加 DOM

需要同时控制多个兄弟节点时，可用不渲染为实际元素的 `<template>`：

~~~vue
<template v-if="selectedOrder">
  <h3>已选工单</h3>
  <p>{{ selectedOrder.number }}</p>
</template>
~~~

不要为绕过 CSS 随意添加无语义 `<div>`，也不要把 `<template>` 当成可设置 `class` 的真实节点。浏览器 Elements 中没有它对应的元素，因此测试应断言分支里的实际节点。

本章不使用 `v-if` 与 `v-for` 在同一元素上。官方文档指出两者同时存在时 `v-if` 优先级更高，且条件可能拿不到 `v-for` 作用域变量。先准备可见集合，再循环，结构更清楚。

## 14. `v-show`：节点保留，只切换显示

`v-show` 始终渲染元素，通常通过 `display` 切换：

~~~vue
<p v-show="selectedId !== null" aria-live="polite">
  已选择一个工单。
</p>
~~~

选择原则：切换很少、分支创建成本较高且初始不一定需要时，常考虑 `v-if`；高频切换、节点应保留时，常考虑 `v-show`。这不是绝对性能公式，真实场景要测量。

安全与无障碍上，“视觉隐藏”不等于授权。敏感数据即使 `display:none` 也已进入客户端 DOM；后端根本不应返回未授权数据。动态提示若需要被辅助技术感知，应合理使用 live region，并避免每次微小变化产生噪声。

## 15. `v-for`：从集合产生节点

~~~vue
<li v-for="order in visibleOrders" :key="order.id">
  <strong>{{ order.number }}</strong>
  <span>{{ order.status }}</span>
</li>
~~~

`order` 只在循环作用域内可用。也可写 `(order, index) in visibleOrders`，但索引主要用于展示序号或诊断，不应自动成为身份。集合可以是数组、对象或数值范围；工单列表使用数组，保持来源顺序清楚。

列表渲染本身不负责分页、虚拟化或服务端过滤。几万条工单一次进入 DOM 会产生性能与可访问性问题；真实管理端应结合 API 分页、搜索、加载/错误状态和必要的虚拟化，本章只用小而确定的数据矩阵学习语义。

## 16. `key` 不是为了消除警告的装饰

`key` 告诉 Vue 同层兄弟节点的稳定身份。没有 key 时，Vue 可采用就地修补策略；有唯一稳定 key 时，它能在插入、删除和重排中复用/移动与同一业务实体对应的节点。工单的 `id` 是身份，显示编号通常也稳定但合同上真正主键是 `id`。

设旧列表：

```text
位置 0: WO-A（DOM 节点 α）
位置 1: WO-B（DOM 节点 β）
```

重排为 B、A。若 key 为 `order.id`，期望 WO-B 仍关联节点 β，只是被移动；WO-A 仍关联 α。若 key 为数组索引，位置 0 的 key 仍是 0，运行时可能把节点 α 的内容改成 WO-B。纯文本表面看似正确，但输入值、焦点、局部 DOM 状态或组件实例状态可能跟错实体，这就是节点复用故障。

## 17. 好 key 的四个条件

一个列表 key 应当：

1. 在同层兄弟中唯一；
2. 对同一实体跨渲染稳定；
3. 是 `string` 或 `number` 等原始值；
4. 来自业务身份，而不是渲染位置或随机数。

不推荐：

- `:key="index"`：插入、删除、排序时位置变了；
- `:key="Math.random()"`：每次渲染都换身份，节点被反复销毁重建；
- `:key="order.status"`：多个工单可同状态，且状态会变化；
- `:key="order"`：对象引用不适合作为通用可序列化身份；
- 重复编号：会产生 duplicate key 警告和不确定复用。

索引 key 只在列表永久静态、永不排序插入删除、项目也没有局部状态时可能不暴露问题；这种脆弱前提不适合作为 FactoryCare 工单默认设计。

## 18. key 应放在哪个节点

直接循环普通元素时 key 放在该元素：

```vue
<li v-for="order in orders" :key="order.id">...</li>
```

循环 `<template>` 产生多个兄弟节点时，key 放在 `<template>`：

```vue
<template v-for="order in orders" :key="order.id">
  <dt>{{ order.number }}</dt>
  <dd>{{ order.status }}</dd>
</template>
```

不要把 key 藏在更深子节点，以为运行时能推断整个循环片段身份。开发控制台的 missing/duplicate key 警告应被当作缺陷处理，而不是用 warn handler 永久过滤。

## 19. 筛选按钮而不是提前使用 `v-model`

本章可以用一组按钮表达筛选：

~~~vue
<button
  v-for="option in statusOptions"
  :key="option.value"
  type="button"
  :aria-pressed="activeStatus === option.value"
  @click="activeStatus = option.value"
>
  {{ option.label }}
</button>
~~~

这样同时练习 `v-for`、`v-bind`、`v-on` 和稳定 key，却不提前讲表单双向绑定。按钮数据也要有稳定 `value`；显示 label 可本地化，不能拿中文显示文本作为后端枚举。

筛选结果的派生在工件中保持最小。正式项目应在响应式章节用 `computed` 表达派生数据，避免每个模板位置重复过滤。此处如果看到 `ref` 或简单 getter，把它当作脚手架，不把“为什么会更新”纳入本章考核。

## 20. 选择状态与失效身份

筛选后，已选择工单可能不在可见集合中。模板需要明确产品语义：保留全局选择、清除选择，或显示“所选项已被筛选隐藏”。本章选择“筛选改变时清除选择”，并由事件处理器显式完成：

~~~ts
function chooseStatus(next: StatusFilter): void {
  // 筛选是用户动作；同步清除选择，避免详情指向不可见工单。
  activeStatus.value = next
  selectedId.value = null
}
~~~

这是重要副作用，因此代码注释说明它。不要用 watch 偷偷清理；watch 与副作用生命周期在后续章节。若产品选择保留，也应测试可见/隐藏状态并给辅助技术清楚提示。

## 21. 空态、单项、多项矩阵

最低渲染矩阵：

| 数据/动作 | 预期 DOM 文本 | 预期属性 | 预期结构 |
| --- | --- | --- | --- |
| 原始零项 | “暂无工单” | 空态可被定位 | 无列表项 |
| 一项 CREATED | 显示编号和中文状态 | 选择按钮 `aria-pressed=false` | 1 个有 key 的项 |
| 三项，筛选 ALL | 三个编号 | 当前筛选按钮 pressed | 3 项 |
| 三项，筛选 CLOSED | 只显示关闭项 | CLOSED 按钮 pressed | 1 项 |
| 筛选无结果 | “当前筛选没有工单” | 可恢复到全部 | 0 项 |
| 选择一项 | 已选提示含编号 | 对应按钮 pressed | 其他项不误选 |
| 重排 B,A | 文本顺序改变 | 身份仍为各自 ID | B 节点对象仍是旧 β |

仅做截图无法证明节点对象身份，也很难证明控制台无警告。配套实验使用 Vue 自定义内存渲染器保存节点引用，再重排输入进行同一对象比较；这是无浏览器 DOM 的确定性 T1 证据，仍需人工浏览器 smoke 覆盖真实焦点与样式。

## 22. 诊断漏 key 与重复 key

漏 key 时，开发模式通常发出列表 key 警告。第一步保存完整警告和组件位置；第二步找到实际 `v-for` 根；第三步确认业务数据是否真的有唯一 ID；第四步绑定 ID；第五步重跑空/单/多/重排矩阵并确认警告为零。

如果 API 数据出现重复 ID，不能在模板里临时拼上索引把警告藏掉。重复主键是数据合同问题，应在适配边界失败并记录证据。客户端伪造 `id-index` 会让同一工单跨刷新身份不稳定，还可能掩盖服务端严重错误。

## 23. 诊断索引 key 的节点复用

索引 key 常不产生 missing-key 警告，所以必须做身份实验：

1. 渲染 `[A, B]`，保存 B 对应实际节点对象引用；
2. 把输入重排为 `[B, A]`；
3. 再按 `data-order-id="B"` 找节点；
4. 用严格对象相等比较新 B 节点与旧引用；
5. 索引 key 下可能失败，ID key 下应相同；
6. 再观察焦点/输入等局部状态是否随实体移动。

第一可信证据不是视觉顺序，而是同一业务 ID 对应的节点对象变了。修复只把 key 改为 `order.id`，然后重跑同一矩阵。残余风险是自定义渲染器不等同于所有浏览器焦点行为，所以还要人工键盘检查。

## 24. 诊断错误条件

假设空态写成：

```vue
<p v-if="visibleOrders.length > 0">暂无工单</p>
```

多项时错误显示空态，零项时什么都没有。不要用 CSS 隐藏矛盾节点。矩阵会同时在零项与多项失败，第一证据是条件表达式与 DOM 数量反向。改为 `=== 0`，并用 `v-else` 保证空态和列表互斥。

还要区分 `orders.length` 和 `visibleOrders.length`：原始列表有数据但当前筛选无结果时，用户仍需要筛选空态。选择错误数据源是 template-state-drift 的典型原因。

## 25. 诊断事件修饰符

父卡片选择、子按钮打开详情时，缺 `.stop` 会让一次点击同时触发两个动作；误加 `.prevent` 可能阻止链接导航；把 `.once` 放在筛选按钮会让它只能使用一次。建立事件计数矩阵：

```text
动作                         selectCount  detailCount  defaultPrevented
点击卡片空白处               1            0            false
点击详情按钮（.stop）         0            1            false
点击需要阻止提交的演示按钮    0            1            true
```

用事件对象和计数器观察，不靠“感觉点了一次”。修复后重跑相同事件、相同节点和相同初始状态。若浏览器原生行为很重要，还应增加真实浏览器 E2E；内存渲染器只能证明处理器绑定和传播模型中的一部分。

## 26. 编译期错误、运行时警告、DOM 错误要分层

- 模板标签或表达式语法非法：SFC/template **编译阶段**失败，先看插件给出的 `.vue` 行列；
- 漏 key 或重复 key：通常是开发**运行时警告**，构建可能通过；
- 条件写反、索引 key、错误修饰符：通常能编译，也未必警告，要靠**行为矩阵**发现；
- 数据字段缺失：可能表现为空文本、TypeScript 诊断或运行时错误，要回到输入合同；
- 未授权数据被渲染：不是模板显示问题，而是安全边界与 API 问题。

先判断失败阶段再选择工具。`pnpm build` 适合发现语法与模块图，Console 适合警告，Elements/属性检查适合最终 DOM，自动化矩阵适合回归，Network 适合数据来源。本章不拿单一工具包打天下。

## 27. 安全：插值安全不代表整个模板安全

Vue 自动转义文本插值和普通属性绑定，这是重要默认保护，但以下仍危险：

- `v-html` 渲染不可信 HTML；
- 把用户可控字符串用作 URL、style 或事件代码；
- 挂载到含服务端用户内容且使用运行时模板编译的节点；
- 把敏感数据先返回客户端，再用 `v-if` 隐藏；
- 用客户端状态决定租户边界或工单状态迁移权限。

本章完全不使用 `v-html`。FactoryCare 工单描述按纯文本显示；若未来必须显示富文本，要采用受信任的清洗策略、内容安全策略和专门组件。任何授权都由服务端按认证上下文、角色与数据范围强制。

## 28. 无障碍：模板语法服务于语义

工单列表应使用 `ul/li` 或在真正表格数据时用语义表格。筛选是一组有清楚名称的按钮；当前状态通过可见样式和 `aria-pressed` 双重表达。每个工单选择按钮名称包含编号，不能十个按钮都只叫“选择”。空态用普通文本和可执行下一步，动态选择提示可用克制的 `aria-live="polite"`。

条件切换时要考虑焦点：若 `v-if` 删除当前聚焦节点，焦点可能回到 body。完整焦点恢复在无障碍章节处理，本章至少避免在点击后立刻删除操作者自身，并在人工 smoke 中全程只用键盘走一遍。`v-show` 保留节点也不自动解决焦点语义；隐藏元素的可聚焦性要实测。

CSS 要提供清晰 `:focus-visible`，文本与背景有足够对比，触控目标约 44×44，不能依靠 hover 或颜色单独传达状态。减少动画用户的偏好在需要动画时必须尊重；本章无需动画。

## 29. 性能：模板里的成本从哪里来

每次相关更新时，复杂模板表达式、列表过滤、未稳定的 key 和大量节点都会产生成本。常见边界：

- 不在每个列表项里重复排序整个数组；
- 不用随机 key 迫使节点全部重建；
- 不为隐藏敏感数据渲染巨大分支；
- 大列表由服务端分页，必要时再评估虚拟化；
- `v-if` 与 `v-show` 的选择基于切换频率和节点成本；
- 测量生产构建，不拿开发模式性能下结论。

小型 FactoryCare 教学列表优先正确身份和清楚 DOM。只有当 profiler 或用户指标指出瓶颈时才引入缓存、虚拟列表或更复杂派生状态；性能优化不能牺牲键盘访问和完整可见名称。

## 30. FactoryCare 业务映射与不变量

列表中可展示合同允许的十二个工单状态和四个优先级。UI 可把枚举映射为中文：

~~~ts
const statusLabels: Record<WorkOrderStatus, string> = {
  CREATED: '已创建',
  TRIAGED: '已分诊',
  ASSIGNED: '已派单',
  ACCEPTED: '已接单',
  IN_PROGRESS: '处理中',
  PENDING_PARTS: '等待备件',
  PENDING_APPROVAL: '等待审批',
  RESOLVED: '已解决',
  VERIFIED: '已验证',
  CLOSED: '已关闭',
  REOPENED: '已重开',
  CANCELLED: '已取消',
}
~~~

这是非显然映射，应注释其数据源是 `public-api.yaml`，而不是临时产品文案。未知枚举应在适配层被显式处理，不能默默显示空白。优先级标签也不能改变 API 值；呈现层使用中文，命令仍按合同发送规范枚举。

模板按钮只筛选/选择，不直接执行“任意改 status”。真正转换需要当前状态、权限、数据版本、理由/附件/检查项、SLA、审计和领域事件等服务端校验。客户端再漂亮也不能替代这些不变量。

## 31. 一个边界清楚的完整骨架

~~~vue
<script setup lang="ts">
import { ref } from 'vue'

type Filter = 'ALL' | 'CREATED'

// 静态工单是本章可复现输入；生产数据以后来自受权 API 适配层。
const orders = [
  { id: 'wo-a', number: 'WO-2026-001', status: 'CREATED' },
  { id: 'wo-b', number: 'WO-2026-002', status: 'CLOSED' },
] as const

const activeFilter = ref<Filter>('ALL')
const selectedId = ref<string | null>(null)

function chooseFilter(next: Filter): void {
  // 筛选切换会使旧选择含义不清，因此此用户动作同步清除选择。
  activeFilter.value = next
  selectedId.value = null
}
</script>

<template>
  <main>
    <h1>FactoryCare 工单</h1>
    <div aria-label="工单筛选">
      <button type="button" :aria-pressed="activeFilter === 'ALL'" @click="chooseFilter('ALL')">
        全部
      </button>
      <button type="button" :aria-pressed="activeFilter === 'CREATED'" @click="chooseFilter('CREATED')">
        未关闭
      </button>
    </div>

    <p v-if="orders.length === 0">暂无工单。</p>
    <ul v-else aria-label="工单列表">
      <li v-for="order in orders" :key="order.id">
        <span>{{ order.number }}</span>
        <button
          type="button"
          :aria-pressed="selectedId === order.id"
          :aria-label="`选择工单 ${order.number}`"
          @click="selectedId = order.id"
        >
          选择
        </button>
      </li>
    </ul>
  </main>
</template>
~~~

这段骨架刻意没有 v-model、请求、子组件通信和 watch。实际工件补上正确筛选结果与状态标签；你应自己实现，而不是复制骨架。

## 32. 独立实验步骤

1. 从上一章可运行 Vite + Vue + TS 项目开始，先确认入口绿灯；
2. 定义三条固定工单，ID、编号、状态与优先级来自合法枚举；
3. 先渲染标题和静态一项，确认插值文本；
4. 用 `v-bind` 添加 `data-order-id`、`aria-pressed` 和状态类；
5. 用原生按钮和 `v-on` 实现选择；
6. 用条件分支实现原始/筛选空态；
7. 用 `v-for` 和 `:key="order.id"` 展开列表；
8. 实现 ALL/CREATED/CLOSED 筛选，不用 v-model；
9. 跑零/一/多/筛选/选择/重排矩阵并捕获警告；
10. 将 key 改成索引得到红灯，保存节点身份证据；
11. 恢复 ID key，重跑原矩阵；
12. 人工用键盘检查焦点、可见名称、空态和 44px 控件。

每一步都用可观察结果推进。若入口已经坏了，先回上一章；若 build 绿而矩阵红，留在模板与状态边界，不要重装 Vite。

## 33. 证据记录模板

```text
场景：重排保持工单节点身份
输入：[wo-a, wo-b]
初始观察：wo-b → nodeRef β
动作：改为 [wo-b, wo-a]
预期：wo-b → 同一个 nodeRef β，顺序位于第一项
实际（故障版 :key=index）：wo-b → nodeRef α，严格相等失败
第一可信证据：identity assertion EXPECTED_STABLE_WORK_ORDER_KEY failed
最小修复：:key="order.id"
原矩阵重跑：零/一/多/筛选/事件/身份/警告全部通过
残余风险：未自动覆盖真实浏览器焦点与屏幕阅读器播报
```

记录中不要只写“key 修好了”。证据要能让第三人用相同输入判定红绿，并知道该测试没有证明什么。

## 34. 常见错误与纠正

- **把 `{{ }}` 写进属性字符串**：改用 `:aria-label="表达式"`。
- **布尔属性写 `disabled="false"`**：它仍存在；改为 `:disabled="false"` 或真实条件。
- **在模板塞多条语句**：提取脚本函数或命名派生值。
- **`v-if` 与 `v-for` 同元素且条件引用循环变量**：先准备集合或套 `<template>`，不要依赖错误作用域。
- **索引/随机数作 key**：改用稳定业务 ID，并做重排身份测试。
- **只消掉 missing-key 警告**：还要验证唯一、稳定和节点复用。
- **`.prevent` 当 `.stop`**：分别验证默认行为与传播计数。
- **可点击 div**：使用原生 button/link。
- **状态只靠颜色**：加可见文字与语义属性。
- **`v-if` 当权限控制**：后端不返回未授权资源并强制授权。
- **大列表都塞浏览器**：API 分页与按需加载，测量后再虚拟化。
- **用 `v-html` 显示工单描述**：默认按文本插值；富文本必须专门清洗。

## 35. 120 秒复述脚本

> Vue 模板声明状态对应的 DOM。双大括号产生已转义文本，`v-bind` 把表达式绑定到属性、class 或 style，`v-on` 把原生事件连接到有名字的状态改变；修饰符表达 stop/prevent 等 DOM 细节。`v-if` 会创建或删除分支，`v-show` 保留节点并切换显示，`v-for` 展开集合。列表的 key 是业务身份，不是消警告装饰；工单应使用稳定唯一的 id，索引 key 在重排时可能让旧节点局部状态跟错实体。我的证据是空/一/多、筛选、选择、事件和重排矩阵，加上控制台 key 警告为零。模板不能解决服务端租户授权、工单状态机或网络副作用。

追问时要能说明为什么索引 key 可能“文字正确但身份错误”，并描述保存节点引用再重排的验证方法。

## 36. 自测题

1. 插值和 `v-bind` 分别放在什么位置？
2. 为什么普通插值显示 `<script>` 时默认不会执行它？
3. `disabled="false"` 为什么仍可能禁用按钮？
4. 静态 class 与对象 class 如何协作？
5. 方法处理器和内联处理器各适合什么？
6. `.stop` 与 `.prevent` 分别改变什么？顺序为何可能重要？
7. `v-if` 与 `v-show` 的 DOM 生命周期有何不同？
8. 为什么不应在同一元素混用 `v-if` 与 `v-for`？
9. key 如何帮助重排？为什么索引不是工单身份？
10. 怎样用对象严格相等证明节点身份保留？
11. 过滤为空与原始列表为空为何需要两个测试？
12. 为什么没有 key 警告仍不能证明 key 正确？
13. 如何让筛选和选择控件可键盘访问且不只靠颜色？
14. `v-if="canClose"` 为什么不是服务端授权？
15. 大列表性能优化前应记录哪些事实？

如果答案只会背语法，回到实验注入错误条件、索引 key 和缺 `.stop`；能预测 DOM、警告与节点身份，才达到诊断要求。

## 37. 本章边界与后续路线

本章已覆盖文本插值、属性/class/style 绑定、模板表达式、事件与修饰符、条件、列表和 key 身份。故意不包含：`v-model`、表单校验、完整响应式原理、computed、watch、生命周期副作用、Props/emit/Slot、异步 API、Router、Pinia、权限守卫和组件测试框架。

下一章将系统教授表单、`v-model`、修饰符与校验边界。之后响应式章节解释为什么值改变会触发更新，组件合同章节再拆分工单项。遇到问题先判断层次：入口失败回上一章；模板能编译但 DOM 不符用本章矩阵；网络竞态或生命周期清理由后续专章处理。

## 38. 官方一手资料

以下资料均于 **2026-07-17** 复核：

- [Vue Template Syntax：插值、属性绑定与表达式](https://vuejs.org/guide/essentials/template-syntax.html)
- [Vue Class and Style Bindings](https://vuejs.org/guide/essentials/class-and-style.html)
- [Vue Event Handling：处理器与修饰符](https://vuejs.org/guide/essentials/event-handling.html)
- [Vue Conditional Rendering：`v-if` 与 `v-show`](https://vuejs.org/guide/essentials/conditional.html)
- [Vue List Rendering：`v-for`、`key` 与数组变化](https://vuejs.org/guide/essentials/list.html)
- [Vue Built-in Directives API](https://vuejs.org/api/built-in-directives.html)
- [Vue Special Attribute `key`](https://vuejs.org/api/built-in-special-attributes.html#key)
- [Vue Security Guide：自动转义与危险边界](https://vuejs.org/guide/best-practices/security.html)
- [Vue Accessibility Guide](https://vuejs.org/guide/best-practices/accessibility.html)

基础指令稳定，但浏览器行为、工具链诊断和 Vue 补丁会变化。升级后重跑相同 DOM/事件/身份矩阵，并重新核对官方迁移与安全说明。
