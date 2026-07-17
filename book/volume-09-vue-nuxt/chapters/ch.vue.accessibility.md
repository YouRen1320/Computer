---
schema_version: 2
edition: 2026.2-draft
id: ch.vue.accessibility
title: Vue 组件无障碍、焦点恢复与动态提示
responsibility: 把原生无障碍原则落实到条件渲染、弹层、路由切换和异步提示，保证组件更新后键盘与屏幕阅读器仍获得正确上下文。
volume: '09'
order: 13
level: L2
status: drafting
path: book/volume-09-vue-nuxt/chapters/ch.vue.accessibility.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.vue.components-contracts
- ch.web.accessibility-interaction
version_surfaces:
- vue-3
- browser
- browser-devtools
- vitest
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“Vue 组件无障碍、焦点恢复与动态提示”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - vue-dynamic-a11y
  - vue-focus-navigation
  covers_topics:
  - vue.live-region
  - vue.validation-announcement
  - vue.dynamic-name-state
  - vue.conditional-content-a11y
  - vue.focus-after-render
  - vue.modal-focus-trap
  - vue.route-focus-restoration
  - vue.escape-close
  - a11y.focus-restoration
  uses_capabilities:
  - web.vue-components-contracts
  - web.accessibility
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现一个可访问工单弹层和路由切换焦点恢复，并保存键盘与屏幕阅读器证据；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - vue-dynamic-a11y
  - vue-focus-navigation
  covers_topics:
  - vue.live-region
  - vue.validation-announcement
  - vue.dynamic-name-state
  - vue.conditional-content-a11y
  - vue.focus-after-render
  - vue.modal-focus-trap
  - vue.route-focus-restoration
  - vue.escape-close
  - a11y.focus-restoration
  uses_capabilities:
  - web.vue-components-contracts
  - web.accessibility
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: keyboard-component-check-accessibility-tree-screen-reader-announcement
- id: diagnose
  kind: fault-diagnosis
  text: 面对“nextTick 时机、teleport 或条件渲染导致的焦点丢失和静默错误”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - vue-dynamic-a11y
  - vue-focus-navigation
  covers_topics:
  - vue.live-region
  - vue.validation-announcement
  - vue.dynamic-name-state
  - vue.conditional-content-a11y
  - vue.focus-after-render
  - vue.modal-focus-trap
  - vue.route-focus-restoration
  - vue.escape-close
  - a11y.focus-restoration
  uses_capabilities:
  - web.vue-components-contracts
  - web.accessibility
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Vue 组件无障碍、焦点恢复与动态提示

> 本章状态为 **drafting**。正文、happy-dom 测试、静态语义检查和 Vite 构建可用于学习与作者自检，但不能替代真实浏览器可访问性树、键盘人工漫游、系统屏幕阅读器播报、缩放或视觉对比度验证。官方 Vue 与 W3C/WAI 资料复核日为 **2026-07-17**。本轮没有启动真实浏览器、VoiceOver/NVDA/JAWS，也没有做人工视觉检查，因此所有浏览器、AT 与人工视觉结论明确为 **UNVERIFIED**，且不修改 `PROGRESS.md`。

Vue 不会自动破坏无障碍，也不会自动补齐它。真正的风险来自动态更新：`v-if` 移走了当前焦点；Teleport 把弹层搬到 `body` 后，查询和所有权仍按原组件假设；路由内容替换，却没有告诉键盘与屏幕阅读器“上下文已变”；保存成功只改变绿色图标，错误只出现在视觉卡片；Escape 被父层快捷键吞掉；弹层关闭后焦点落到 `body`。

本章把原生原则落实为组件合同：**语义与可访问名称在渲染前设计；条件内容提交后再移动焦点；模态弹层包含键盘焦点并支持 Escape；关闭时恢复调用位置；动态错误与完成状态通过可见文本和适当 live region 提供上下文；路由切换把焦点送到新页面标题。** 反例：色盲用户是否能在最终品牌配色下辨认所有状态，不能只靠 Vue 单元测试解决，必须有颜色/非颜色设计、真实渲染测量与人工核验。

## 1. 完成标准、证据入口与非目标

canonical oracle 是：**打开/关闭弹层、校验错误、异步完成和路由切换后，焦点目标、键盘路径与动态提示逐项符合检查表。** 完成本章应能：

1. 优先使用原生 heading、label、button、input，再为没有原生语义的复合模式添加准确 ARIA；
2. 让 dialog 具有可访问名称、modal 状态、说明与明确控制名称；
3. 在打开前保存调用控件，在 `v-if`/Teleport 提交后的 `nextTick` 聚焦合适目标；
4. 让 Tab/Shift+Tab 在可用弹层控件间环绕，让 Escape 在不破坏保存事务时关闭；
5. 关闭后等待 DOM 更新，再把焦点恢复到仍存在且可聚焦的调用控件；
6. 将字段错误同时表现为可见文本、字段关联和及时通知；
7. 将异步成功写入稳定存在的 polite status region，而不是临时加一段可能不播报的节点；
8. 条件内容、动态名称、busy/disabled/expanded 状态对视觉与辅助技术使用同一事实源；
9. 路由切换后将焦点移到可编程聚焦的页面标题，同时保留正常浏览器历史与键盘顺序；
10. 注入错误 nextTick 时机、Teleport 查询域、静默错误和键盘陷阱，保存首证据、修复与重跑；
11. 区分 DOM 合同测试、浏览器可访问性树、键盘人工验证和屏幕阅读器播报证据。

配套入口：

- [可访问工单弹层与路由焦点示例](../../../examples/encyclopedia/ch.vue.accessibility/README.md)
- [焦点、Teleport、静默提示与键盘陷阱实验](../../../labs/encyclopedia/ch.vue.accessibility/README.md)
- [公开红灯：修复动态弹层上下文](../../../exercises/encyclopedia/ch.vue.accessibility/README.md)
- [私有参考解答](../../../solutions-private/encyclopedia/ch.vue.accessibility/README.md)

本章不替代完整 WCAG 审计，不实现通用 dialog 库，不覆盖所有移动屏幕阅读器手势，不决定品牌色、不证明生产页面所有第三方组件、iframe 或浏览器扩展兼容。若产品已有成熟且审计过的组件库，应优先复用其 dialog/focus primitives，再验证本产品组合，而不是每个页面重写焦点陷阱。

## 2. 四层模型：语义、操作、更新与证据

动态无障碍问题可以用四层检查：

| 层 | 核心问题 | Vue 中的典型风险 | 首要证据 |
|---|---|---|---|
| 语义 | 这是什么、叫什么、状态怎样 | div 模拟按钮、标题无引用、名称动态错位 | DOM/Accessibility Tree |
| 操作 | 键盘能否到达、执行、退出 | Tab 逃出 modal、Escape 无效、焦点顺序乱 | 人工键盘轨迹 |
| 更新 | 内容变化后上下文是否保留 | v-if 删除焦点、路由换页沉默、错误无通知 | activeElement + AT 播报 |
| 证据 | 什么已被哪种环境证明 | happy-dom 绿却宣称 NVDA 通过 | 环境、命令、版本、记录 |

四层不能互相替代。DOM 有 `role="status"` 只证明意图与结构，不证明特定浏览器/屏幕阅读器组合按期望播报；人工听到一次播报也不证明键盘环绕、错误关联和路由焦点都正确。每个结论注明证据层，才能避免“自动测试全绿所以无障碍完成”。

Vue 的组件合同决定谁拥有语义与副作用。弹层组件应拥有 dialog 容器、初始聚焦、Tab 环绕、Escape、关闭事件和动态提示；调用方拥有 `open` 状态与触发按钮。焦点恢复需要双方合同：弹层捕获打开时 active element，父层响应 close 改变 prop，弹层观察关闭提交后归还焦点。

## 3. 原生 HTML 优先，ARIA 补充模式

`button` 天生可聚焦、支持 Enter/Space、提供角色与禁用语义；`<div @click>` 需要重新实现所有这些。显式 `<label for>` 给 input 名称和更大点击目标；placeholder 不是标签，输入后会消失，也常不足以形成可靠名称。页面结构使用一个清楚的 `<main>`、层级合理的 heading 与 landmarks，让用户能快速导航。

ARIA 的第一规则是：能用原生就不要重造。对真正的模态弹层，原生 `<dialog>` 与 ARIA dialog 都有实现选择；无论选哪种，都要验证目标浏览器行为。若使用 `role="dialog" aria-modal="true"`，必须真的限制背景交互与焦点，不能只声明 modal。错误 ARIA 会把不符合行为的界面包装成可信谎言。

可访问名称应来自稳定可见文本：

```vue
<section
  role="dialog"
  aria-modal="true"
  aria-labelledby="work-order-dialog-title"
  aria-describedby="work-order-dialog-help"
>
  <h2 id="work-order-dialog-title">新建工单</h2>
  <p id="work-order-dialog-help">所有字段均为必填。</p>
  <label for="work-order-title">工单标题</label>
  <input id="work-order-title">
</section>
```

不要同时塞入互相冲突的 `aria-label` 与 `aria-labelledby`，也不要引用条件渲染后不存在的 ID。多个组件实例必须生成唯一 ID，否则第二个 dialog 可能借到第一个标题。示例为单实例教学使用固定 ID；可复用库应使用 `useId()` 或父层提供稳定唯一前缀，并在 SSR/hydration 中验证一致性。

## 4. 条件渲染改变的不只是可见性

`v-if` 删除并重建节点，当前 `document.activeElement` 若在子树内，浏览器会把焦点移到别处，常见是 `body`。`v-show` 保留节点但隐藏；隐藏元素不应继续被键盘访问。选择依据生命周期与语义，而不是为了“测试好写”。弹层通常需要明确打开/关闭生命周期，`v-if` 合理，但必须设计焦点进入与归还。

条件状态还会改变可访问名称、描述和 live region。错误段落 `v-if="error"` 出现时，字段要通过 `aria-describedby` 或 `aria-errormessage`（需验证支持面）关联；错误清除时引用也要清除。加载按钮若文本从“保存”变成“正在保存”，视觉与 accessible name 同步，但需考虑名称变化是否造成用户迷失；可以保留动词并用 status region 另行通知进度。

使用 `:aria-invalid="Boolean(error)"` 时，Vue 会序列化值；检查最终 DOM 是 `true/false` 还是属性缺失，并与产品合同一致。不要用 CSS class `is-error` 作为唯一状态。颜色、图标、边框必须配合文本与语义，使信息不依赖单一感官。

## 5. `nextTick`：焦点副作用必须发生在提交之后

设置 `open.value = true` 并不意味着 input 已经在 DOM。Vue 会批处理更新；同步调用 `field.value?.focus()` 时 ref 可能仍是 `null`，或指向上一次实例。正确顺序是捕获调用位置 → 改变 open → 等 DOM 提交 → 聚焦。

在弹层内部观察 prop：

```ts
import { nextTick, ref, shallowRef, watch } from 'vue'

const field = ref<HTMLInputElement | null>(null)
const returnTarget = shallowRef<HTMLElement | null>(null)

// Responsibility: preserve keyboard context across one conditional dialog lifecycle.
watch(() => props.open, async (isOpen, wasOpen) => {
  if (isOpen) {
    // Important side effect: capture the invoker before Teleport content receives focus.
    returnTarget.value = document.activeElement instanceof HTMLElement
      ? document.activeElement
      : null
    await nextTick()
    field.value?.focus()
  } else if (wasOpen) {
    await nextTick()
    returnTarget.value?.focus()
  }
}, { immediate: true })
```

初始焦点不是永远第一个 input。WAI-ARIA dialog pattern 建议根据内容与任务选择：短表单可聚焦首字段；危险确认可聚焦最安全操作；长结构内容可给标题 `tabindex="-1"` 并聚焦标题，使开头可感知。不要默认聚焦 destructive button，也不要让焦点落在滚动后看不到的区域。

焦点调用是副作用，应只发生在明确状态转换，不要在每次 render/update 都抢焦点。用户正在阅读或输入时被 watch 反复拉回，会形成可用性故障。若 `open` 已 true，只更新错误或内容，不应重新执行打开聚焦。

## 6. Teleport 改变物理 DOM，不改变逻辑责任

Teleport 把弹层内容渲染到 `body`，解决祖先 stacking/overflow 问题；事件与组件关系仍属于原组件。但工具查询域会变：Vue Test Utils 的 wrapper DOM 可能只看到 teleport 占位，真实 dialog 在 `document.body`。若测试写 `wrapper.get('[role="dialog"]')`，可能错误失败；若 shallow stub Teleport，又可能错误通过。

测试策略是 mount 时 `attachTo: document.body`，然后从 `document.body` 查询被 teleport 的公共节点，并在每 case 后清理 DOM。焦点陷阱内部不应依赖全局 `document.querySelectorAll('button')`，否则背景按钮会混入；使用 panel ref 在 dialog 内查询焦点候选。

Teleport 也不自动使背景 inert。`aria-modal="true"` 是辅助技术声明，不能物理阻止背景 click/Tab。成熟 dialog primitive 通常处理 inert/aria-hidden、scroll lock、嵌套 modal、portal stack 与恢复目标。教学示例只实现单层 focus cycle；生产需要选定策略并在真实浏览器验证背景不可交互，尤其是 Safari、移动端和嵌套弹层。

## 7. 模态焦点环绕：Tab、Shift+Tab 与动态可用项

最小算法：在弹层内取得当前可聚焦且未 disabled 的控件；若 Tab 位于最后一个，preventDefault 并聚焦第一个；若 Shift+Tab 位于第一个，聚焦最后一个；中间位置交给浏览器自然顺序。示例用显式 data marker 定义教学范围：

```ts
function onKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') {
    event.preventDefault()
    requestClose()
    return
  }
  if (event.key !== 'Tab' || !panel.value) return

  // Mapping: marked enabled controls in DOM order become the modal focus ring.
  const controls = [...panel.value.querySelectorAll<HTMLElement>(
    '[data-dialog-focus]:not([disabled])',
  )]
  const first = controls[0]
  const last = controls.at(-1)
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault()
    last?.focus()
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault()
    first?.focus()
  }
}
```

生产级 focusability 比 selector 复杂：hidden、inert、负 tabindex、details、radio group、shadow DOM、contenteditable、动态 disabled 都会影响顺序。若自研算法，必须覆盖矩阵；更稳妥是使用成熟 primitive。即便使用库，仍要在产品内容中验证，因为条件按钮、嵌套 popover 和异步 disabled 会改变环。

没有焦点项时应提供可聚焦的 dialog 容器/标题与明确关闭动作。只有一个焦点项时 Tab 应保持在它上面。保存期间若所有按钮 disabled，用户可能无处可去；通常保留可感知状态，并决定是否允许取消。任何策略都应写入合同和测试，而不是让偶然 DOM 决定。

## 8. Escape 关闭与焦点恢复是一个事务

WAI-ARIA dialog pattern 期望 Escape 关闭 dialog。组件应在最靠近 modal 所有权的边界处理，并避免父页面全局快捷键先执行。使用 `event.preventDefault()` 后 emit `close`，父层改 `open=false`；弹层观察关闭，在 next tick 归还焦点。

若保存中不能关闭，不能静默吞掉 Escape。产品需决定：允许取消请求、提示“保存中，请稍候”，或保持 Escape 禁用但让状态可感知。示例在 `saving` 时不 emit close，按钮也 disabled；真实产品应补充状态说明与可取消策略测试。

恢复目标优先是打开弹层的控件。若它因路由、权限或列表刷新已被删除，fallback 应是逻辑相邻目标：新建按钮所在 heading、列表中下一行或页面主标题。直接 `returnTarget?.focus()` 在 disconnected 节点上不会产生有用上下文，生产实现应检查 `isConnected` 和可聚焦性，再执行 fallback。

“关闭后 dialog 不存在”不等于“焦点已恢复”。DOM 测试必须断言 `document.activeElement === trigger`；人工键盘验证必须观察焦点环/后续 Tab 顺序；屏幕阅读器验证应确认用户回到调用上下文而非页面开头。

## 9. 动态名称与状态保持同一个事实源

按钮文字、`aria-expanded`、`aria-pressed`、`aria-busy`、disabled 和提示文本必须由同一 state 派生。例如保存中：按钮可显示“正在保存”，容器设 `aria-busy="true"`（如语义合适），status region 写“正在保存工单”；完成后清 busy 并写完成文本。不要视觉文本说“已保存”，accessible name 仍是“保存”。

可访问名称不要塞入频繁变化的完整状态，使用户每次导航听到冗长信息。名称回答“控件是什么”，状态回答“现在怎样”。例如关闭按钮名称“关闭新建工单弹层”比孤立“×”可靠；保存结果属于 status region，而非把按钮名称永久改成一整句。

条件内容出现/消失时，应考虑用户当前焦点是否仍在文档、名称引用是否还存在、阅读顺序是否合理。`v-if` 删除一项列表后，可把焦点放到下一项、上一项或列表标题；规则由任务连续性决定，并保存为测试用例。

## 10. 校验错误：可见、关联、及时但不喧闹

提交空标题时，至少需要：

1. 可见具体文本“请输入工单标题”，不能只画红框；
2. 字段通过 label 有名称；
3. `aria-invalid="true"` 表示当前无效；
4. 字段通过 `aria-describedby="work-order-title-error"` 关联错误；
5. 错误区域用适当通知策略，例如提交后 `role="alert"`；
6. 焦点移动到第一个无效字段，或提供错误摘要与跳转链接；
7. 修复后错误与 invalid 状态清除。

`role="alert"` 相当于强烈、assertive 的即时消息，不应在每次键入时轰炸。逐字符校验可以延迟到 blur 或提交，按风险选择 polite/alert。多个错误同时出现时，逐个 alert 可能造成混乱；更好的策略是错误摘要加字段关联，并在人工 AT 中验证播报顺序。

```vue
<label for="work-order-title">工单标题</label>
<input
  id="work-order-title"
  :aria-invalid="Boolean(error)"
  :aria-describedby="error ? 'work-order-title-error' : undefined"
>
<p v-if="error" id="work-order-title-error" role="alert">{{ error }}</p>
```

自动测试可断言最终属性、文本和 focus；不能断言“屏幕阅读器一定说了某句话”。实际播报受 DOM 插入时机、region 是否预先存在、浏览器/AT 组合和 verbosity 设置影响，必须真实监听并记录。

## 11. Live region：先存在，再更新文本

异步保存完成后，视觉用户看到 toast；屏幕阅读器用户也需要不移动焦点的状态通知。`role="status"` 通常具有 polite live 语义，适合非紧急完成；`role="alert"` 适合需要立即注意的错误。不要所有消息都 assertive。

可靠模式是让空 status region 随组件稳定存在，完成后只改变它的文本：

```vue
<p class="status" role="status" aria-live="polite">{{ statusMessage }}</p>
```

```ts
async function submit() {
  statusMessage.value = ''
  try {
    // Data source: the injected gateway is the only asynchronous persistence boundary.
    await props.gateway.save({ title: title.value.trim() })
    statusMessage.value = `已保存工单：${title.value.trim()}`
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '保存失败，请重试'
  }
}
```

若 region 与消息同时通过 `v-if` 插入，一些组合可能来不及建立观察，造成静默。重复完全相同文本时，AT 也可能不再播报；产品可先清空后在受控更新中重设，但不要制造双重消息。toast 自动消失时间、暂停与关闭也要符合可操作性要求，本章示例不实现 toast 系统。

动态提示必须有可见文本，不能为 AT 创建一套与屏幕不同的事实。视觉与无障碍副本分叉会产生维护风险。若使用 visually-hidden，应确认信息对视觉用户是否也必要，而不是默认隐藏。

## 12. 路由切换后的焦点恢复

SPA 路由不会像整页导航一样由浏览器自动重置阅读上下文。链接激活后页面内容变化，但焦点可能留在导航链接，屏幕阅读器未必知道主内容标题改变。常见策略是在 route key 变化且新视图提交后，聚焦页面 `<h1 tabindex="-1">`，并保持标题可见。

```ts
const headingElement = ref<HTMLHeadingElement | null>(null)

// Responsibility: announce one route-context transition through a visible page heading.
watch(() => props.pageKey, async () => {
  await nextTick()
  // Important side effect: focus only after the conditional route subtree commits.
  headingElement.value?.focus()
})
```

不要在首次加载无条件抢走地址栏/用户选择的焦点；区分 initial mount 与实际 route transition。浏览器 back/forward 可能需要恢复上次滚动和控件位置，而不是总回 h1；复杂应用应定义 forward navigation、history navigation、modal route 各自规则。

页面还应提供可见于 focus 的 skip link，让键盘用户绕过重复导航。skip link 目标可聚焦或是 `<main id>`，需在目标浏览器验证。路由标题同时更新 `document.title`，帮助所有用户理解历史项；本章示例聚焦 h1，未实现真实 Router 和 document title，因此这些生产集成仍未验证。

## 13. 视觉与运动：语义绿灯之外的必要检查

配套 UI/UX 检索把本章实现约束收敛为：44px 左右可点击目标、明显 `:focus-visible`、信息不只靠颜色、文本/背景达到目标对比度、错误可恢复、skip link、`prefers-reduced-motion`。示例包含可见焦点轮廓、最小控件高度、错误文本与 reduced-motion 媒体查询，但没有真实渲染测量。

CSS 源码出现 `outline: 3px solid` 不证明焦点环未被覆盖或与所有背景有足够对比；十六进制颜色看似深浅分明也不证明 WCAG 比率。人工视觉与浏览器工具需在默认、hover、focus、disabled、error、forced-colors、高对比度、200%/400% 缩放、窄屏和 reduced-motion 下检查。

动画不能阻止用户操作或在关闭 modal 后延迟 focus 恢复。若存在 transition 离场，DOM 何时删除、何时恢复焦点需要明确；不要用固定 timeout 猜动画结束，使用 transition 生命周期或组件库合同，并为 reduced motion 分支测试。

## 14. 自动组件测试能证明什么

happy-dom/Vitest 可以稳定证明：

- dialog 节点具有 role、aria-modal、标题/说明引用；
- 打开更新后 `document.activeElement` 是预期字段；
- Escape event 导致 close emit；
- 边界 Tab/Shift+Tab handler 把 activeElement 移到环另一端；
- 错误文本、role、字段引用与 invalid 属性存在；
- Promise 完成后 status region 文本更新；
- close prop 提交后调用控件重新获得 activeElement；
- route key 改变后 h1 获得 focus；
- 生产构建可成功完成。

它不能证明：

- 浏览器原生 tab 顺序、inert、scroll lock 与 focus visible 实际表现；
- Accessibility Tree 中名称/描述计算完全符合目标浏览器；
- VoiceOver、NVDA、JAWS、TalkBack 何时以及如何播报；
- 颜色对比、缩放重排、触控目标实际像素、动画舒适度；
- 用户在复杂内容中是否理解上下文。

测试注释和 verifier 输出必须保持这条边界。本章示例输出 `at-screen-reader=UNVERIFIED manual-visual=UNVERIFIED`；实验也输出 `browser-at=UNVERIFIED`。将这些字符串删掉不会增加证据，只会降低诚实度。

## 15. 浏览器、可访问性树与屏幕阅读器矩阵

正式 G4 至少选定项目支持矩阵，而不是抽象写“已测屏幕阅读器”：

| 场景 | 键盘/浏览器 | 可访问性树 | 屏幕阅读器要听到/确认 |
|---|---|---|---|
| 打开弹层 | Tab + Enter | dialog name/modal | 标题、说明、首字段上下文 |
| Tab 环绕 | Tab/Shift+Tab | 背景不可达 | 不离开 modal |
| Escape | Escape | dialog 删除 | 回到“新建工单”调用控件 |
| 空提交 | Enter/点击保存 | invalid + error relation | 具体错误，焦点在字段 |
| 保存成功 | 异步完成 | status region text | 非打断式完成消息 |
| 保存失败 | reject | alert + field relation | 错误与恢复入口 |
| 路由切换 | 激活导航 | 新 h1/name | 新页面标题与上下文 |

记录浏览器精确版本、OS、AT 名称/版本、verbosity 设置、输入序列、实际焦点序列和实际播报摘要。不要长篇逐字转载第三方内容；记录自己观察到的产品输出即可。若某组合未执行，标记 N/A 或 UNVERIFIED，不从另一个组合推断。

人工键盘轨迹示例：`触发按钮 → 标题字段 → 保存 → 取消 → 标题字段（Shift+Tab）`，Escape 后 `activeElement=触发按钮`。同时检查页面背景不能 click/scroll/Tab（按产品合同），焦点环始终可见，且 disabled/busy 不造成零焦点项。

## 16. 四类故障的首证据与修复

### 16.1 `nextTick` 时机错误

坏代码在 `open=true` 的同步 watch 中调用 `field.value?.focus()`。首证据是 input 尚未存在、`field.value === null` 或 activeElement 仍是 trigger/body。修复是捕获 return target 后 `await nextTick()`，再聚焦；重跑打开、关闭和快速重开，确认没有旧 ref。

### 16.2 Teleport 查询/所有权错误

坏测试从 wrapper 根查询 dialog，报找不到；坏实现从全 document 收集按钮，把背景导航加入 focus cycle。首证据分别是 teleport 占位与 `document.body` 中实际 dialog、以及 focusable 列表含背景控件。修复测试查询 body，修复实现从 panel ref 限定；不应为了让测试绿而禁用 Teleport。

### 16.3 条件渲染造成静默错误

坏实现仅 `<p v-if="error">保存失败</p>`，无 role、字段引用或稳定 live region。DOM 视觉文本可能存在，但 AT 无上下文。首证据是 Accessibility Tree/DOM 缺少关联，真实 AT 未播报。修复为 label、invalid、describedby、适当 alert/status，并在目标 AT 重跑；happy-dom 只能证明结构。

### 16.4 键盘陷阱或焦点逃逸

坏实现对所有 key `preventDefault`，Escape 无效；或者完全不处理 Tab，焦点进入背景。首证据是实际按键序列与 activeElement。修复只拦截边界 Tab 与 Escape，保留中间自然顺序和可用关闭动作。若用库，检查 nested overlay 与动态 disabled，而不是再叠一层自定义 handler。

实验的 `faults/` 保存四个独立坏工件，健康 suite 不导入它们；静态检查确认每种缺陷没有被“意外修好”。一次只注入一个，预测首证据，保存修复差异，运行同一 verifier。屏幕阅读器故障仍需真实 AT 补证。

## 17. 实验步骤：实现、注入、重跑

1. 进入 [实验目录](../../../labs/encyclopedia/ch.vue.accessibility/README.md)，记录 OS、Node、pnpm 与依赖版本；
2. 运行 `bash verify.sh`，保存 10 个 DOM/focus case、Vite build 与 fault catalog 结果；
3. 画出触发按钮、Teleported dialog、字段、保存/取消与 route h1 的逻辑/物理位置；
4. 对每个状态写 expected activeElement、可见文本、role/name/description；
5. 注入 `ImmediateFocus.vue` 的同步聚焦，观察提交前后 ref 与 activeElement；
6. 注入 Teleport scoped query，比较 wrapper 和 `document.body`；
7. 注入 silent error，列出视觉可见但语义缺失的字段；
8. 注入 keyboard trap，用 Escape、Tab、Shift+Tab 记录路径；
9. 恢复健康实现，原命令重跑并保存 before/fix/after；
10. 在真实目标浏览器人工走键盘矩阵，查看 Accessibility Tree；
11. 用项目支持的 AT 监听打开、错误、成功、关闭、路由五个事件；
12. 若第 10/11 步没有执行，报告必须保留 `UNVERIFIED`。

实验中的 10 个 case 是机械 oracle 的子集，不是“屏幕阅读器证据”。canonical 验收要求保存键盘与屏幕阅读器证据；本轮作者只交付可执行起点，因此正式 G4 尚未完成。

## 18. 公开练习与独立完成纪律

公开起始 `WorkOrderDialog.vue` 有 Teleport 和视觉内容，但没有 dialog role/name、显式 label、nextTick、Escape/Tab、return target、alert/status/live。它同步 focus 一个尚未提交的 ref，所以 verifier 返回固定非零码和缺失列表。

独立完成时只修改公开组件：先建立语义，再写 watch 时序和 keyboard handler，最后添加错误/状态反馈。不要把要求 token 塞进注释、删除 checker 或照抄私有目录。静态 checker 通过后，仍要在真实 Vue 测试与浏览器运行；练习本身不安装依赖，也不声称 AT 通过。

若 AI 提供建议，保存建议与人工取舍，之后从空白组件无 AI 重做。能解释为什么 return target 在打开前捕获、为什么打开/关闭都要 nextTick、为什么 alert 与 status 不同、为什么 Teleport 查询从 body 开始，才满足 teach-back，而非只记 API。

## 19. G4 证据包模板

建议在 `evidence/gates/g4/ch.vue.accessibility/` 保存：

```text
README.md                 # 范围、支持矩阵、结论、UNVERIFIED 项
environment.txt          # OS/浏览器/AT/Node/Vue/Vitest 版本
component-command.txt    # 命令、工作目录、退出码
component-results.txt    # 语义、focus、keyboard event、live text
build-results.txt        # Vite 生产构建
keyboard-paths.md        # 人工 Tab/Shift+Tab/Escape 实际序列
accessibility-tree/      # dialog/name/state/relations 截图或导出摘要
screen-reader-notes.md   # 组合、设置、输入、实际播报摘要
visual-checks.md         # focus、contrast、zoom、forced colors、motion
fault-nexttick.txt       # 首证据→修复→同命令重跑
fault-teleport.txt
fault-silence.txt
fault-keyboard.txt
residual-risks.md        # 未覆盖浏览器、AT、嵌套 overlay 等
```

自动与人工结果分开。不要在 component-results 写“屏幕阅读器通过”；不要在 screen-reader-notes 只贴源码。每项应有可复现操作与实际观察。若无法安装/操作 AT，说明原因、保留缺口，并由有环境的复核者补证。

## 20. 120 秒 teach-back 与判定表

合格解释应覆盖：Vue 条件渲染需要在 nextTick 后 focus；Teleport 改物理 DOM 与查询域但不改组件所有权；modal 需 role/name、Tab 环绕、Escape 和 focus restoration；错误使用可见文本+字段关联+适当 alert，完成使用稳定 polite status；路由变化聚焦新 h1；DOM 测试不证明 AT。反例是最终配色/真实播报不能由 happy-dom 推断。

| 维度 | 不通过 | 基本通过 | 扎实通过 |
|---|---|---|---|
| 语义 | div + click | dialog/label 存在 | name/description/state 引用稳定且树中验证 |
| 焦点 | 打开/关闭落 body | nextTick 初始聚焦 | 进入、环绕、Escape、恢复、fallback 矩阵 |
| 动态提示 | 只颜色/图标 | alert/status 文本 | 错误关联、live 时机、真实 AT 观察 |
| 路由 | 内容换了焦点不动 | 新 h1 可聚焦 | 区分首次/前进/历史与 title/scroll |
| 诊断 | 随意加 timeout | 找到 nextTick/Teleport | 首证据→单一修复→同矩阵重跑 |
| 证据边界 | happy-dom 声称 AT 绿 | 标记未验证 | DOM、树、键盘、AT、视觉分别记录 |

## 21. 版本面与官方资料

本章工件固定 Vue `3.5.35`、Vue Test Utils `2.4.11`、Vitest `4.0.18`、happy-dom `17.6.3`、Vite `7.3.1`、TypeScript `5.9.3`。`browser` 与 `browser-devtools` 是必须补证的版本面，不是锁文件依赖；执行时记录实际浏览器和 Accessibility Tree 工具版本。

官方资料（复核于 2026-07-17）：

- [Vue Accessibility Best Practices](https://vuejs.org/guide/best-practices/accessibility.html)：skip link、结构、label 与交互基础；
- [Vue `nextTick`](https://vuejs.org/api/general.html#nexttick)：等待下一次 DOM 更新 flush；
- [Vue Teleport](https://vuejs.org/guide/built-ins/teleport.html)：逻辑组件与物理 DOM 位置；
- [WAI-ARIA APG Modal Dialog Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/)：modal role、焦点进入/包含、Escape 与恢复；
- [WCAG 2.2 Focus Order](https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html)：可操作焦点顺序与意义；
- [WCAG 2.2 Status Messages](https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html)：不移动焦点的状态通知。

最终证据边界再次确认：本地机械结果覆盖 9 个示例 case、10 个实验 case、两次 Vite 构建、语义/焦点源码检查、四类 fault、公开预期红灯和私有绿灯；**未运行真实浏览器可访问性树、人工键盘/视觉检查或任何屏幕阅读器**。因此 outcome 中要求的键盘与屏幕阅读器证据仍需在 G4 环境补齐，本章不能自行宣告完成。
