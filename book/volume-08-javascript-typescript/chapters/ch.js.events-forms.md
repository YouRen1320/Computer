---
schema_version: 2
edition: 2026.2-draft
id: ch.js.events-forms
title: 事件传播、监听器、表单与默认行为
responsibility: 解释捕获、目标、冒泡、默认行为和事件委托，用监听器增强原生表单且保留提交与无障碍语义。
volume: '08'
order: 11
level: L2
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.js.events-forms.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.js.dom-mutation
- ch.js.object-model
- ch.web.forms-validation
version_surfaces:
- browser
- browser-devtools
- html-living-standard
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“事件传播、监听器、表单与默认行为”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - js-event-flow
  - js-form-events-default
  covers_topics:
  - dom.event-capture-target-bubble
  - dom.event-listener-options
  - dom.event-delegation
  - dom.listener-removal
  - dom.form-submit-event
  - dom.input-change-event
  - dom.prevent-default
  - dom.formdata
  - html.control-name-value
  uses_capabilities:
  - web.javascript-language
  - web.html-semantic-form
  - web.javascript-objects
  - web.javascript-dom
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为动态工单列表实现事件委托和渐进增强表单并记录事件顺序；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - js-event-flow
  - js-form-events-default
  covers_topics:
  - dom.event-capture-target-bubble
  - dom.event-listener-options
  - dom.event-delegation
  - dom.listener-removal
  - dom.form-submit-event
  - dom.input-change-event
  - dom.prevent-default
  - dom.formdata
  - html.control-name-value
  uses_capabilities:
  - web.javascript-language
  - web.html-semantic-form
  - web.javascript-objects
  - web.javascript-dom
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: event-order-trace-form-request-check-dom-assertions
- id: diagnose
  kind: fault-diagnosis
  text: 面对“重复监听、错误 preventDefault 或 target/currentTarget 混淆”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - js-event-flow
  - js-form-events-default
  covers_topics:
  - dom.event-capture-target-bubble
  - dom.event-listener-options
  - dom.event-delegation
  - dom.listener-removal
  - dom.form-submit-event
  - dom.input-change-event
  - dom.prevent-default
  - dom.formdata
  - html.control-name-value
  uses_capabilities:
  - web.javascript-language
  - web.html-semantic-form
  - web.javascript-objects
  - web.javascript-dom
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 事件传播、监听器、表单与默认行为

一次点击不是“按钮直接调用函数”这么简单。事件先沿事件路径到达目标，再按监听器配置调用回调；回调看到的 `target` 与 `currentTarget` 可能不同；传播结束后，浏览器还可能执行链接导航、复选框切换或表单提交等默认行为。若把这些层混在一起，常见结果是动态按钮没有响应、同一动作执行两次、在错误节点读取 `dataset`，或者 JavaScript 一加载就让原本可用的表单失去提交能力。

本章的目标是用一条可追踪证据链理解并实现事件增强：固定 HTML 先提供可访问、可提交的基础能力；JavaScript 在已知根节点绑定可清理的监听器；事件委托从真实目标解析业务动作；只有当增强路径确实接管提交时才取消默认行为；最终用事件顺序表、FormData 条目和 DOM 状态断言证明结果。网络请求、重试、服务端状态权限与 Vue 组件事件留给后续章节。

## 完成定义与 canonical 预言

完成本章必须留下四类证据：

1. 在 120 秒内说明捕获、目标、冒泡、默认行为、监听器身份、委托、`submit`、`input/change` 与 `FormData`，并给出一个不属于本章的反例；
2. 为动态工单列表实现单根监听的事件委托，为原生表单实现可撤销的渐进增强，保存固定事件顺序；
3. 证明页面没有 JavaScript 时仍有正确 `action`、`method`、label、name、原生校验与提交按钮；
4. 分别注入重复监听、无条件 `preventDefault()`、`target/currentTarget` 混淆，指出首个可信差异，修复后重跑同一预言。

canonical T1 预言是：**捕获/冒泡顺序、委托解析出的工单身份、默认提交是否被取消、FormData 条目和最终 DOM 状态，与固定事件追踪表及请求负载逐项一致。** “点一下看起来有反应”不是充分证据，因为两个处理器可能把同一状态切换两次后回到原样；“控制台没有报错”也不能证明默认提交仍然存在。

## 先保留不用 JavaScript 也成立的表单

渐进增强从 HTML 合同开始，而不是从 `preventDefault()` 开始：

```html
<!-- 表单本身负责无脚本提交、标签关联和原生约束；脚本只增强反馈。 -->
<form id="work-order-filter" action="/work-orders" method="get">
  <label for="status">工单状态</label>
  <select id="status" name="status" required>
    <option value="CREATED">待分派</option>
    <option value="ASSIGNED">处理中</option>
  </select>
  <label>
    <input type="checkbox" name="urgent" value="true">
    仅看紧急工单
  </label>
  <button type="submit">筛选</button>
</form>
```

这里每个名字都有职责：`action` 和 `method` 定义无脚本请求；`label` 提供控件名称；`name` 决定控件是否以什么键进入表单条目；`value` 是提交值，不一定等于用户看到的文字；`required` 交给浏览器约束验证；显式 `type="submit"` 避免按钮职责随上下文猜测。若脚本下载失败，用户仍能筛选，这是增强策略的回滚路径。

不要把 `<div>` 加点击监听器冒充按钮。原生 `button` 已有键盘激活、焦点与表单关系；重新实现这些行为既昂贵又容易残缺。事件代码负责业务增强，不负责重建 HTML 语义。

## 事件对象与传播路径

DOM 事件分发会建立一条事件路径。简化成普通文档树，可以这样预测：

```text
Window → Document → main → ul → li → button
                   捕获方向  →
                                  目标
                   ←  冒泡方向
```

捕获监听器沿祖先到目标方向执行；到达目标时，目标上的监听器处于 `AT_TARGET`；允许冒泡的事件再沿祖先反向传播。真实规范还处理 Shadow DOM retargeting、slot、relatedTarget 等，本章实验使用无 Shadow DOM 的已知树，不能把简图当作所有浏览器事件的完整算法。

一个固定追踪器：

```js
// traceListener 把节点、阶段和目标压成稳定字符串，作为事件顺序预言。
function traceListener(label, trace) {
  return (event) => {
    trace.push(`${label}:${event.eventPhase}:${event.target.id}`);
  };
}

document.addEventListener("click", traceListener("document-capture", trace), {
  capture: true,
});
list.addEventListener("click", traceListener("list-bubble", trace));
```

`eventPhase` 常量比“我觉得现在在冒泡”可靠。调试时还可记录 `event.composedPath()`，但不要把 DOM 对象直接序列化进跨环境快照；稳定预言应提取固定 ID、tagName 和阶段数字。

### `target` 与 `currentTarget` 是两个问题

- `event.target`：事件被分发到的原始/重定向后目标，在同一传播过程中通常保持业务起点；
- `event.currentTarget`：当前正在执行哪个对象上的监听器，随监听器调用而变化，回调结束后不应被当作长期上下文保存；
- `event.composedPath()`：当前事件路径，可用于跨 Shadow DOM 边界的高级判断，但本章不深入组件封装。

当监听器绑在 `ul`，用户点击按钮里的图标时，`target` 可能是 `svg` 或 `span`，`currentTarget` 是 `ul`。因此下面两种写法都可能错：

```js
// 错误一：target 未必就是按钮，直接读 dataset 会得到 undefined。
const action = event.target.dataset.action;

// 错误二：currentTarget 是委托根 ul，不是具体工单按钮。
const workOrderId = event.currentTarget.dataset.workOrderId;
```

可靠做法是从元素目标向上找业务按钮，再确认它仍属于委托根：

```js
// resolveAction 把任意后代点击映射为根节点内的一个显式业务动作。
function resolveAction(event, root) {
  if (!(event.target instanceof Element)) return null;
  const button = event.target.closest("button[data-action][data-work-order-id]");
  if (!button || !root.contains(button)) return null;
  return {
    action: button.dataset.action,
    workOrderId: button.dataset.workOrderId,
  };
}
```

`closest()` 表达“最近业务控制”，`root.contains()` 防止错误节点越过职责边界。工单 ID 只用于定位界面动作，不能在客户端授权服务端状态迁移。

## 事件委托：动态节点共享一个稳定入口

若列表项会新增或替换，逐个按钮绑定监听器会带来两个问题：新节点没有监听器，旧节点移除后回调生命周期难追踪。事件委托利用可冒泡事件，在稳定祖先上绑定一次：

```js
// installWorkOrderDelegation 只拥有列表根的 click 监听，并返回明确清理函数。
export function installWorkOrderDelegation(root, onAction) {
  const handleClick = (event) => {
    const command = resolveAction(event, root);
    if (!command) return;
    onAction(command);
  };

  root.addEventListener("click", handleClick);
  return () => root.removeEventListener("click", handleClick);
}
```

委托不是“所有事件都绑 document”。根越大，误匹配与跨功能耦合越多；应选择拥有该动作集合的最小稳定祖先。也要确认事件确实冒泡：`focus` 本身与 `focusin` 的行为不同，`mouseenter` 也不按普通冒泡模型委托。本章示例用 `click`、`input`、`change`、`submit`，并针对每种事件查合同。

### 重复安装为何难发现

规范不会把同一 `type`、同一回调对象、同一 capture 的监听器重复追加；但每次执行 `() => handle()` 都创建新函数对象：

```js
// 错误：每次 mount 都创建新回调，三次安装就会执行三次。
root.addEventListener("click", (event) => handleClick(event));
```

若渲染、路由进入或热更新多次调用安装函数，就会出现重复副作用。验证不能只看最终 class；应让 `onAction` 计数并断言一次点击恰好产生一次命令。清理时也必须持有原回调身份；用一个新的箭头传给 `removeEventListener` 无法移除旧函数。

## 监听器选项与生命周期

`addEventListener(type, callback, options)` 的常用选项分别解决不同问题：

| 选项 | 责任 | 可观察证据 | 常见误用 |
| --- | --- | --- | --- |
| `capture` | 选择捕获阶段监听 | trace 中阶段与顺序 | 以为它改变事件目标 |
| `once` | 首次调用前后自动移除 | 第二次分发不再调用 | 用于需要持续响应的按钮 |
| `passive` | 承诺回调不会取消事件 | `preventDefault` 不应成为合同 | 在必须取消滚动/提交时设 true |
| `signal` | signal abort 时移除监听器 | abort 后计数不增加 | 复用已 aborted signal 安装 |

对一组同生命周期监听器，`AbortController` 能把清理责任集中起来：

```js
// installEnhancement 用一个 signal 管理本功能拥有的列表与表单监听器。
export function installEnhancement(list, form, handlers) {
  const controller = new AbortController();
  list.addEventListener("click", handlers.click, { signal: controller.signal });
  form.addEventListener("submit", handlers.submit, { signal: controller.signal });
  return () => controller.abort();
}
```

不要把 controller 放进跨页面全局并由任意模块 abort；拥有安装动作的层也应拥有清理动作。若运行环境不支持 listener `signal`，可以保留具名回调并逐个移除；这属于显式兼容选择，不是两套逻辑同时无期限维护。

`removeEventListener` 匹配时关键是 type、callback 身份与 capture。`passive`、`once` 的差异不是移除匹配的主要身份，但为了可读与避免误判，安装和移除应复用同一命名配置。

## 传播控制不等于默认行为控制

三组 API 经常被混为一谈：

- `stopPropagation()`：不再把事件传播到路径上的其他对象；不自动取消默认行为；
- `stopImmediatePropagation()`：还阻止当前对象上排在后面的监听器；
- `preventDefault()`：若事件可取消，则设置 canceled/defaultPrevented，阻止关联默认动作；不停止其他监听器执行。

因此“为了阻止表单导航调用 stopPropagation”是错误修复；“为了避免父组件监听调用 preventDefault”同样错误。调试时同时记录 `event.cancelable`、`event.defaultPrevented` 与监听器 trace，才能区分哪一层改变了结果。

```js
// handleSubmit 只在增强路径准备好接管提交时取消浏览器默认提交。
async function handleSubmit(event) {
  if (!enhancementIsReady()) return;
  event.preventDefault();
  await submitEnhancedForm(event.currentTarget);
}
```

若先无条件 `preventDefault()`，随后发现配置缺失就 `return`，页面既没有增强请求，也没有原生提交，形成 `default-action-loss`。更稳妥的策略是先完成同步前置判断，再取消；取消之后的失败必须由增强路径给出可恢复反馈。本章示例以注入的提交端口记录负载，不发真实网络请求。

### `dispatchEvent` 与真实用户动作

脚本创建的 Event 可测试传播和取消标志，但 `isTrusted` 为 false，且模拟器不一定实现浏览器全部激活/导航行为。`dispatchEvent()` 返回值可反映可取消事件是否被取消，却不能证明真实浏览器已经发送或阻止了一次 HTTP 请求。真实提交证据必须在固定浏览器 Network/DevTools 中另行采集。

## 表单应监听 `submit`，而不是猜测所有提交入口

用户可能点击提交按钮、在文本控件按 Enter、由辅助技术激活，或由代码调用 `requestSubmit()`。只监听按钮 `click` 会漏掉合法入口，也把提交规则绑在一个具体按钮上。`submit` 事件派发到 form，HTML 规范定义它可冒泡且可取消，并携带 `submitter`（若有）。

```js
// submit 监听器以 form 为 currentTarget，覆盖点击与隐式提交入口。
form.addEventListener("submit", (event) => {
  const form = event.currentTarget;
  if (!(form instanceof HTMLFormElement)) return;
  if (!form.checkValidity()) return;
  event.preventDefault();
  const formData = new FormData(form, event.submitter ?? undefined);
  onSubmit(formData);
});
```

原生约束验证通常发生在提交算法相关步骤中；测试模拟事件时不要假定模拟器完整复刻交互验证 UI。真实浏览器检查至少要覆盖鼠标点击、键盘提交、无脚本/禁用脚本路径，以及非法值是否阻止提交。

`form.submit()` 与用户式提交入口的语义不同，可能绕过 `submit` 事件和约束验证；需要模拟用户提交时优先理解并使用 `requestSubmit()`。但本章不把某个模拟器的 `requestSubmit` 实现当成跨浏览器证明。

## `input` 与 `change`：选择需要的反馈时机

`input` 常用于值每次由用户编辑后提供即时反馈；`change` 常在值被用户提交/确认、控件失焦或选择改变的相应时点触发，具体时点取决于控件类型。不要写“一律 input 更好”或“一律 change 只在 blur”。

```js
// input 只更新本地字数提示，不提交业务状态，也不改服务端权威数据。
description.addEventListener("input", (event) => {
  const value = event.currentTarget.value;
  counter.textContent = `${value.length}/200`;
});

// change 记录已确认的筛选值，用于界面过滤预览。
status.addEventListener("change", (event) => {
  previewFilter(event.currentTarget.value);
});
```

脚本给 `input.value` 赋值通常不会自动代表用户输入事件；若测试需要事件，必须明确分发并说明这是合成证据。输入法组合、粘贴、自动填充与辅助技术行为需要真实浏览器测试，本章仅建立监听选择原则。

## FormData：从“成功控件”构造有序条目

`new FormData(form)` 不是“把页面上所有 input 变成普通对象”。HTML 构造的是有序 entry list，键来自成功控件的 `name`，值可能是字符串或 File。重要边界包括：

- 没有 `name` 或 name 为空的控件不会按预期提供业务键；
- disabled 控件通常不进入提交条目；只读与禁用不是同义；
- 未选中的 checkbox/radio 不产生对应条目；选中且未显式 value 的 checkbox 有规范默认值；
- 同一 name 可以重复，如多个标签或多选项；
- 提交按钮是否进入条目与实际 submitter 有关；
- FormData 保留 File，不能随意 `JSON.stringify` 后宣称负载等价。

```js
// entriesToTrace 保留重复键与顺序，避免 Object.fromEntries 静默覆盖多值。
function entriesToTrace(formData) {
  return [...formData.entries()].map(([name, value]) => [
    name,
    typeof value === "string" ? value : value.name,
  ]);
}
```

`Object.fromEntries(formData)` 对单值简单表单方便，但重复键只保留最后一个，File 仍是对象。业务负载应显式映射：单值用 `get`，多值用 `getAll`，再做类型/枚举验证。客户端映射是请求形状准备，不代替服务端校验。

```js
// mapFilterPayload 明确 FormData 到只读筛选合同的映射，不创建状态迁移命令。
function mapFilterPayload(formData) {
  const status = formData.get("status");
  if (status !== "CREATED" && status !== "ASSIGNED") {
    throw new TypeError("status must be a supported filter value");
  }
  return {
    status,
    urgent: formData.get("urgent") === "true",
  };
}
```

## 一个可审计的渐进增强安装器

把列表委托、表单提交与清理放在一个有所有权的边界：

```js
// enhanceWorkOrderPage 的数据源是现有 DOM；副作用仅是监听与状态文本更新。
export function enhanceWorkOrderPage({ root, form, onCommand, onSubmit }) {
  const controller = new AbortController();

  root.addEventListener("click", (event) => {
    const command = resolveAction(event, root);
    if (command) onCommand(command);
  }, { signal: controller.signal });

  form.addEventListener("submit", (event) => {
    if (!(event.currentTarget instanceof HTMLFormElement)) return;
    const data = new FormData(event.currentTarget, event.submitter ?? undefined);
    const payload = mapFilterPayload(data);
    event.preventDefault();
    onSubmit(payload);
  }, { signal: controller.signal });

  return { dispose: () => controller.abort() };
}
```

这里 `onCommand`、`onSubmit` 是外部端口，使示例能够计数并检查负载，而不是发真实请求。先构造/验证 payload 再取消默认行为，意味着同步映射失败时可以选择保留原生路径；实际产品还要定义错误反馈与回退策略。若 `onSubmit` 异步拒绝，错误传播属于事件循环与后续请求章节，本章不默默 catch。

## 事件顺序表：先预测再运行

对如下结构：document → list → button，设置 document capture、button target、list bubble 三个监听器，点击按钮前先填表：

| 步骤 | currentTarget | eventPhase | target | defaultPrevented |
| ---: | --- | --- | --- | --- |
| 1 | document | CAPTURING_PHASE | button | false |
| 2 | button | AT_TARGET | button | false |
| 3 | list | BUBBLING_PHASE | button | 取决于此前监听器 |

然后再加入 list 委托、form submit 与清理，至少核对：

1. 动态新增按钮无需单独绑定也只触发一次命令；
2. 点击按钮后 `target` 是按钮/后代，委托解析出的 ID 正确，`currentTarget` 仍是 list；
3. 增强未启用时 submit 没有被取消；增强启用时 cancelable submit 的 `defaultPrevented` 为 true；
4. FormData 按固定顺序得到 `status=ASSIGNED`、选中时 `urgent=true`；
5. dispose 后再次分发不增加命令或提交计数。

把结果写成文本快照比截图更适合机械比较；真实浏览器再用 Event Listener Breakpoints、Elements、Network 与 Accessibility 面板补充宿主证据。

## 三类故障的首个可信证据

### 重复监听：`duplicate-event-handler`

症状可能是一次点击出现两次 toast、两个请求或状态来回切换。首个可信证据不是“用户说好像点了两次”，而是同一合成事件 ID/时间窗口内命令端口计数从 0 变 2，且调用栈指向两个不同回调身份。排查安装入口、生命周期和 cleanup；不要在业务回调里加布尔锁掩盖所有权问题。

### 默认动作丢失：`default-action-loss`

症状是按 Enter 无反应或脚本报错后表单不导航。记录 submit 是否触发、`cancelable/defaultPrevented`、增强前置是否就绪，以及提交端口是否收到负载。若 `defaultPrevented=true` 而端口计数为 0，最早差异通常是过早取消。修复后同时验证增强开启与关闭两条路径。

### 目标混淆：`event-target-confusion`

症状是点击按钮文字可用、点击图标失效，或所有动作都读到 undefined ID。记录 `target.tagName`、`currentTarget.id`、`closest` 结果与 contains guard。修复不是把监听器绑回每个图标，而是把“后代点击 → 根内业务按钮”的映射写成函数并测试。

### 传播被过度阻断

`stopImmediatePropagation` 可能让审计、快捷键或分析监听器消失。只有存在明确冲突合同才停止传播，并在事件追踪表中证明所需监听器仍运行。不要把传播控制作为修复重复安装的捷径。

## FactoryCare 权威边界

浏览器事件只能表达“用户在这个界面发起了什么意图”。它不能证明：

- 当前用户有权接单；
- 工单仍处于允许迁移的状态；
- SLA、版本号或租户边界满足；
- 同一命令没有被服务端重复处理。

客户端应发送明确 ID 与意图，服务端重新授权、校验状态并返回权威结果。事件委托中的 `data-work-order-id` 是定位信息，不是安全凭据。后续 Fetch 与竞态章节再处理网络、取消和过期响应，本章不提前实现。

## 模拟器、真实浏览器与 DevTools 证据

本章资产在本机用 `happy-dom@17.6.3` 执行 DOM 分发、FormData 与属性断言，优点是确定、快速、可从命令行复现。它能证明我们的映射与预言在该模拟器版本成立，不能证明：

- 真实浏览器的默认导航或网络请求；
- 键盘、辅助技术、输入法组合与 autofill 的完整行为；
- Shadow DOM retargeting、布局、焦点可视状态；
- 不同稳定浏览器的兼容结果。

真实验收应固定浏览器版本，清空日志后分别用鼠标、键盘与禁用 JavaScript 场景操作；在 DevTools 观察事件断点、监听器、Network 请求与 DOM；再用屏幕阅读器/键盘检查 label、焦点和错误提示。本次材料没有运行真实浏览器，因此这些结果必须写“未验证”。

## 独立练习与口述

### 练习 A：顺序预测

在三层 DOM 上同时安装 capture/bubble 监听器，加入一个 `once` 监听器和一个可 abort 监听器。运行前写出两次点击各自的完整 trace，再运行并解释每个差异。禁止先看输出再补预测。

### 练习 B：动态列表

从固定数据新增两条工单，按钮内部包含 `<span>`。只在 `ul` 绑定一次监听；分别点击 button 与 span，断言都映射为同一命令；清理后再次点击计数不变。

### 练习 C：渐进增强表单

建立 GET 筛选表单，保留 action/method/name/required。增强关闭时证明 submit 未取消；增强开启时检查固定 FormData 条目和 payload；故意把 `preventDefault` 提到前置判断之前，保存失败证据，再恢复。

### 120 秒口述提纲

依次说明：事件路径与三个阶段；target/currentTarget；为什么委托适合动态列表；回调身份与清理；传播控制和默认行为的差异；为什么监听 submit；FormData 如何选择 name/value；模拟器和真实浏览器证据边界。最后给出一个反例：“请求重试和最新响应胜出”不由本章解决。

## 官方一手资料与核验日期

以下页面于 **2026-07-17** 核验：

- [WHATWG DOM Standard：Events 与 EventTarget](https://dom.spec.whatwg.org/)：事件阶段、target/currentTarget、取消、监听器选项、身份与分发算法；
- [WHATWG HTML：Form control infrastructure / submission](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html)：submit 事件、submitter、控件 name/value、entry list 与 FormDataEvent；页面显示 Living Standard 于 2026-07-16 更新；
- [Chrome DevTools：DOM 与事件检查](https://developer.chrome.com/docs/devtools/dom/)：真实浏览器人工检查入口。

事件传播、回调身份、表单 name/value 等属于稳定核心；浏览器 DevTools 菜单、模拟器覆盖面与兼容细节属于易变表面。版本或宿主行为不确定时，重新查规范与目标浏览器，不用记忆替代证据。

## 本章刻意不做

- 不发 Fetch 请求，不实现超时、取消、重试、竞态或离线队列；
- 不设计 Vue `emit`、组件生命周期、Router 或 Pinia；
- 不重建服务端状态机、RBAC、租户权限或幂等；
- 不覆盖 Shadow DOM 高级事件、拖放、Pointer Events、触摸手势与组合输入全矩阵；
- 不用 happy-dom 绿灯声称真实浏览器、无障碍树或网络默认行为已通过。
