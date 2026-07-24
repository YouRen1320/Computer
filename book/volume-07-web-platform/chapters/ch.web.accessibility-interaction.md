---
schema_version: 2
edition: 2026.2-draft
id: ch.web.accessibility-interaction
title: 无障碍、键盘、焦点与屏幕阅读器
responsibility: 用原生语义、键盘顺序、焦点管理和必要的 ARIA 建立可操作界面，明确 ARIA 不能修复错误 HTML 或业务流程。
volume: '07'
order: 6
level: L1-L2
status: drafting
path: book/volume-07-web-platform/chapters/ch.web.accessibility-interaction.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.web.forms-validation
version_surfaces:
- html-living-standard
- browser
- browser-devtools
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“无障碍、键盘、焦点与屏幕阅读器”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - web-keyboard-focus
  - web-accessible-name-state
  covers_topics:
  - a11y.keyboard-navigation
  - a11y.focus-order
  - a11y.focus-visible
  - a11y.focus-restoration
  - a11y.accessible-name
  - a11y.screen-reader-announcement
  - a11y.aria-state
  - a11y.native-before-aria
  - html.label-control
  uses_capabilities:
  - web.html-semantic-form
  - web.accessibility
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 将一份工单表单改造成键盘和屏幕阅读器可完成的交互并保存审计证据；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - web-keyboard-focus
  - web-accessible-name-state
  covers_topics:
  - a11y.keyboard-navigation
  - a11y.focus-order
  - a11y.focus-visible
  - a11y.focus-restoration
  - a11y.accessible-name
  - a11y.screen-reader-announcement
  - a11y.aria-state
  - a11y.native-before-aria
  - html.label-control
  uses_capabilities:
  - web.html-semantic-form
  - web.accessibility
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: keyboard-walkthrough-accessibility-tree-inspection-screen-reader-check
- id: diagnose
  kind: fault-diagnosis
  text: 面对“焦点陷阱、无名称控件或错误 ARIA 状态造成的不可操作路径”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - web-keyboard-focus
  - web-accessible-name-state
  covers_topics:
  - a11y.keyboard-navigation
  - a11y.focus-order
  - a11y.focus-visible
  - a11y.focus-restoration
  - a11y.accessible-name
  - a11y.screen-reader-announcement
  - a11y.aria-state
  - a11y.native-before-aria
  - html.label-control
  uses_capabilities:
  - web.html-semantic-form
  - web.accessibility
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 无障碍、键盘、焦点与屏幕阅读器

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《表单控件、提交语义与原生校验》](ch.web.forms-validation.md)：键盘、名称和错误提示验证需要已有可提交、可校验的原生控件。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套工件用语义 HTML、少量有意图注释的 JavaScript、键盘步骤、预期可访问树和读屏播报清单建立离线 oracle；离线绿灯不会真的按键、移动系统焦点或启动读屏器。易变事实已于 **2026-07-17** 对照 WHATWG HTML focus、WCAG 2.2、WAI-ARIA APG 与 Accessible Name and Description Computation 一手资料核验。

无障碍不是“给盲人加 aria-label”，也不是发布前跑一次扫描器。用户可能永久、临时或情境性地无法使用鼠标、看清低对比内容、听到声音、理解复杂提示或保持精确动作；同一个人也会在强光、受伤、噪声、放大、语音控制或慢网络中使用系统。工程目标是让关键任务在不同输入和感知方式下**可理解、可操作、可恢复、可验证**。

本章以 FactoryCare 报修表单为任务：只用键盘填写并提交；控件有稳定名称；错误能定位、可感知并恢复；状态变化的 DOM、ARIA 和实际行为一致。它不承诺一次实验覆盖全部 WCAG，也不修复模糊业务流程、无权限的操作或服务端丢失错误。ARIA 只向可访问性 API 补充语义/状态，通常不会自动添加键盘行为、焦点管理、校验或业务规则。

## 1. 完成定义、边界与证据入口

完成本章，应能：

1. 优先用 `button`、`a`、label/input、fieldset/legend、heading、dialog 等原生元素获得语义与基础行为；
2. 从 DOM 顺序预测 Tab/Shift+Tab 路径，区分 Tab 在组件间移动与方向键在复合组件内部移动；
3. 解释 `tabindex="0"`、`-1` 与正值的差异，保持可见焦点且不制造焦点陷阱；
4. 在打开/关闭临时界面、提交错误、删除当前元素等变化后把焦点放到合乎任务预期的位置，并恢复到有效触发点；
5. 在 Accessibility 面板核对 role、accessible name、description、state/value，而不是只看 DOM 属性；
6. 用 label、可见按钮文字、`aria-labelledby`/`aria-describedby` 等适当来源建立名称/说明，避免覆盖或重复；
7. 只在原生 HTML 表达不了的状态上使用 ARIA，并让 `aria-expanded`、`aria-invalid`、`aria-live` 等与真实 UI 同步；
8. 用键盘 walkthrough、可访问树检查与真实读屏器任务三类证据验证一份表单；
9. 注入焦点陷阱、无名称控件、错误 ARIA 状态，定位首证据，修复后重跑同一任务。

配套入口：

- [可键盘完成的报修表单与审计矩阵](../../../examples/encyclopedia/ch.web.accessibility-interaction/README.md)
- [焦点、名称与状态故障实验](../../../labs/encyclopedia/ch.web.accessibility-interaction/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.web.accessibility-interaction/README.md)

canonical 验收判据是：仅用键盘即可完成任务，焦点顺序、可访问名称和动态错误提示与逐项检查表一致。离线 oracle 只检查结构、脚本意图和预期矩阵；只有在记录 OS、浏览器、读屏器、输入动作和实际播报后，才能声称该环境任务通过。

## 2. 三棵树与一条任务路径

前置章已经区分源码与 DOM。无障碍再增加一层：浏览器把 DOM、CSS 可见性、原生语义、ARIA、名称与状态映射到平台 accessibility API，辅助技术读取的是经过处理的**可访问性树**，不是把所有 DOM 节点逐字朗读。

```text
HTML/DOM + CSS 可见性 + 原生语义 + 必要 ARIA
                         ↓ 浏览器映射
accessibility tree: role / name / description / state / value / relationships
                         ↓ 辅助技术与输入方式
用户完成“找到描述 → 填写 → 发现错误 → 修正 → 确认结果”的任务
```

三种证据回答不同问题：

- DOM/静态检查：label 的 for/id、按钮元素、ARIA 引用是否存在；
- Accessibility 面板：指定浏览器实际暴露的 role/name/state/关系；
- 读屏器/键盘任务：用户是否能按真实输入模型理解并完成。

扫描器找到“无名称按钮”很有用，却不会证明焦点恢复合理；Accessibility 面板显示 `expanded=true` 也不证明面板真的可见；读屏器能听到错误也不证明键盘用户能到达对应控件。按风险组合证据。

## 3. 原生优先：语义和行为一起获得

### 3.1 button、link 与 div 的职责

提交、展开、删除等动作使用 `button`；导航到另一 URL 使用带 `href` 的 `a`。原生 button 默认可聚焦，能被键盘激活，并向 accessibility API 暴露 button role 与状态语义。`div role="button"` 只改变暴露角色，不自动添加焦点、Enter/Space 行为、disabled、表单关联或高对比适配。

```html
<!-- Responsibility: 展开或收起故障填写说明，不提交表单。 -->
<!-- Data source: 展开状态来自同一按钮控制的本地 details-panel。 -->
<!-- Mapping: aria-expanded 镜像 hidden 的反状态，aria-controls 指向受控区域。 -->
<!-- Side effects: 激活按钮只切换本地说明可见性和 ARIA 状态。 -->
<button type="button" aria-expanded="false" aria-controls="details-panel">
  显示填写说明
</button>
<section id="details-panel" hidden>
  <h2>填写说明</h2>
  <p>描述至少包含设备现象与发生位置。</p>
</section>
```

这里 ARIA 仍需脚本同步；若只是普通展开内容，可优先评估原生 `details/summary`，再在目标浏览器/读屏器验证。选择原生不等于无需测试，但减少作者必须重建的行为。

### 3.2 表单原生语义

延续前章：可见 `label for=id` 给控件名称，fieldset/legend 给一组控件上下文，`required` 与 type 提供原生约束，按钮文字给动作名称。不要因为要“做无障碍”就再加与可见 label 重复或冲突的 `aria-label`。优先修正确 HTML。

### 3.3 ARIA 的两条底线

1. ARIA 会影响辅助技术理解，错误 ARIA 可能比没有更糟；
2. role/state/property 不创造实际 UI 行为，作者要实现并同步键盘、焦点、可见状态和业务结果。

例如元素写 `aria-disabled="true"` 不会自动阻止点击或表单提交；`aria-expanded="true"` 不会打开面板；`role="alert"` 不会修复被服务器吞掉的错误。若业务允许提交无权限操作，ARIA 无法补救。

## 4. 键盘输入模型

### 4.1 先用原生 Tab 顺序

浏览器的 sequential focus navigation 以可聚焦元素、DOM 顺序、`tabindex` 等规则决定路径。常见页面中：Tab 向前移动，Shift+Tab 向后；Enter 激活 link/button 或提交条件下的表单；Space 激活 button/checkbox 等，但具体原生控件行为由平台决定。测试不能只按 Tab，还要执行组件对应按键。

一份报修表单的预期路径可写：

```text
skip link → assetId → category → priority → description
→ observedDate → evidenceFiles → submit → footer link
```

预期必须来自任务与 DOM，而不是 DevTools 看到的 tabIndex 数字排序猜测。浏览器地址栏、扩展和操作系统“全键盘访问”设置会影响体验，证据要记录环境。

### 4.2 `tabindex` 三种常用含义

- 无 `tabindex`：原生交互元素按默认规则进入顺序；
- `tabindex="0"`：把本来不可顺序聚焦的元素放入自然 DOM 顺序，常用于确需自定义交互的根；
- `tabindex="-1"`：不进入普通 Tab 顺序，但可由脚本在错误摘要、标题或恢复点上调用 `focus()`；
- 正整数：强行建立优先顺序，极易与 DOM/视觉/维护脱节，主流实践避免。

不要给每个段落/标题加 `tabindex="0"` 让读屏器“能读”。读屏器浏览模式本来能遍历语义内容；把所有内容塞入 Tab 顺序会让键盘任务冗长。

### 4.3 复合组件内的方向键

Tab 通常在组件之间移动；radio group、tabs、menu、grid 等复合组件常用方向键在内部移动，并只保留一个 tab stop（roving tabindex 或 `aria-activedescendant`）。实现这些模式必须遵循相应 ARIA APG pattern 并真实测试。普通 HTML select/radio 已提供平台行为，不要为了统一外观重写。

本章表单不创建自定义 combobox/menu，避免把教学范围扩成组件库。能用 `<select>` 就不先造 div listbox。

### 4.4 不制造焦点陷阱

焦点陷阱是用户能 Tab 进入却无法离开，或按键被循环拦截、焦点落在隐藏/不可见元素。普通页面不应困住焦点。模态 dialog 在打开期间会**有意约束**焦点，但必须有可达关闭动作、Escape 策略、正确初始焦点与关闭后的恢复；这不是随意给 keydown 加循环。

检测：从页面第一项开始只用键盘完成全任务，逐步记录 `document.activeElement`/可见焦点；反向 Shift+Tab 也走一遍。若第三次 Tab 又回到同一两项且没有模态语境，首证据是实际焦点序列重复，不是“鼠标还能点出去”。

## 5. 焦点可见与 DOM/视觉顺序

键盘用户必须知道当前焦点。浏览器默认 outline 是最低基线；不要用 `outline: none` 去掉而不提供至少同等清晰的替代。焦点指示要在正常/高对比/强制色/缩放下可辨，并符合 WCAG 2.2 的 Focus Visible/Appearance 等适用要求。CSS 设计在相关章节实现，本章资产保留 user-agent 指示，不伪造视觉验收。

视觉重新排序可能让屏幕上的顺序与 DOM/Tab 顺序不同。CSS flex/grid `order` 不应替代正确 DOM 阅读顺序。页面的逻辑顺序应同时支持线性阅读、键盘和小屏；若设计稿必须跳跃，先修信息架构，而不是用正 tabindex 拼图。

焦点被遮挡同样失败：sticky header、cookie banner 或 modal overlay 可能盖住 active element。键盘矩阵要记录“可见且未被完全遮挡”，不能只记录 activeElement id。

## 6. 焦点管理：只在任务需要时移动

### 6.1 原则

脚本移动焦点是强烈副作用。合理场景包括：打开模态，把焦点移入；关闭模态，恢复触发按钮；异步提交失败，把焦点移到新出现的错误摘要或首错误（需选定一致策略）；路由切换后把焦点移到新视图主标题/容器；删除当前聚焦项后移到邻近有效控件。

不要在输入每个字符、hover、自动刷新或普通状态更新时抢焦点。焦点移动前问：用户刚执行了什么、下一步最合理是什么、读屏器会听到什么、原焦点节点是否仍存在。

### 6.2 错误摘要

服务器返回多个 fieldErrors 后，只给每个输入加红框不够。常见模式是：显示顶部错误摘要，提供到字段的链接/文字；在用户触发的提交响应后把焦点移到摘要（`tabindex="-1"`）或第一个错误；字段用 `aria-invalid="true"` 和描述关系连接具体错误。选择一种策略并在目标读屏器验证，避免 live region + focus + alert 三重重复播报。

### 6.3 恢复焦点

关闭临时界面时保留 opener 的引用，并在它仍连接、可见、可操作时恢复；若 opener 被删除，选择任务上相邻的稳定替代（例如列表标题或下一项），不能把焦点默默丢到 body。恢复点是业务/交互设计，不是 `history.back()` 自动保证。

## 7. 可访问名称、描述与状态

### 7.1 role、name、description、state/value

辅助技术通常需要知道“这是什么（role）”“叫什么（name）”“有什么额外说明（description）”“当前状态/值是什么”。Accessible Name and Description Computation 是按角色和多个来源计算的规范算法，不应背一个过度简化的全局优先级表；在浏览器 Accessibility 面板检查**实际计算结果和来源链**。

常见可靠来源：

- button/link 的可见文本；
- input/select/textarea 的关联 label；
- fieldset 的 legend 提供组上下文；
- img 的 alt；
- `aria-labelledby` 引用已有可见文本；
- `aria-label` 在适用角色提供字符串名称；
- `aria-describedby` 连接帮助或错误说明，而不替代名称。

`placeholder` 不是稳定 label。`title` 不应作为主要名称策略。`aria-label` 可能覆盖可见文本形成名称不一致，影响语音输入；优先让可见文字本身成为名称。

### 7.2 label 与说明

```html
<!-- Responsibility: 收集故障描述并让帮助、错误与控件建立可追踪关系。 -->
<!-- Data source: 帮助文字来自固定表单合同；错误来自受控 Problem.fieldErrors 映射。 -->
<!-- Mapping: label 提供名称，description-help/error 提供描述，aria-invalid 镜像当前错误。 -->
<!-- Side effects: 聚焦控件可能让辅助技术读出名称与描述；静态标记不提交数据。 -->
<label for="description">故障描述（必填）</label>
<p id="description-help">写出设备现象和发生位置，10–5000 字符。</p>
<textarea id="description" name="description" required
          aria-describedby="description-help description-error"></textarea>
<p id="description-error" hidden>请至少输入 10 个字符。</p>
```

初始没有错误时不应写 `aria-invalid="true"`；错误出现时添加，修正/重新验证后移除或设 false。隐藏错误是否仍被描述取决于树与属性处理；脚本显示它再更新关系/状态，最终以可访问树与读屏器实测。

### 7.3 名称不是旁边有文字

图标按钮旁边视觉上有 tooltip/文本，不证明名字进入可访问树。检查目标节点 computed name 及来源。修复首选可见按钮文字；只有设计确实无可见文字且图标目的明确时，才考虑适用的 `aria-label`，同时验证语音输入名称和本地化。

## 8. ARIA 状态必须与真实行为同源

常见状态/属性：

- `aria-expanded`：控制区域当前展开/收起；
- `aria-controls`：指向受控元素，但不会建立行为；
- `aria-pressed`：toggle button 的按下状态；
- `aria-selected`：适用 composite 中的选中项；
- `aria-checked`：适用 checkbox/switch 等；
- `aria-invalid`：值被识别为无效；
- `aria-busy`：区域正在更新；
- `aria-live`：区域变化的播报优先级。

状态必须从与可见 UI/行为相同的状态源更新。面板 `hidden=false` 时按钮 `aria-expanded` 仍 false，就是明确契约漂移。不要用 ARIA 报告“理想状态”。

`aria-hidden="true"` 会让子树从辅助技术隐藏；其中不能留下可聚焦/可操作元素，否则键盘可到达但读屏器不知道是什么。视觉隐藏、DOM hidden、inert、CSS display 与 ARIA hidden 的行为不同，不能互换猜测。

## 9. 动态状态与屏幕阅读器播报

### 9.1 live region 是更新通知，不是日志广播

`aria-live="polite"` 适合不紧急的异步状态，通常等当前播报后通知；`assertive`/alert 只给必须立即打断的高优先事件。频繁进度、每个按键、已聚焦控件的重复信息都会制造噪声。

live region 通常应先存在于 DOM，再更新其文本；创建一个已填满的 region 是否被播报在不同组合中可能变化。不要把隐藏/显示、插入、清空、重复相同字符串的行为当跨读屏器保证。矩阵记录实际播报。

### 9.2 server fieldErrors 映射

FactoryCare `Problem` 具有 `fieldErrors`，每项包含 `field`、`code`、`message`。前端使用显式 allowlist 将合同字段映射到固定 DOM id；不要把服务端 field 直接拼成 CSS selector 或 innerHTML。message 用 `textContent` 渲染，防止注入；未知字段进入全局错误，不静默丢弃。

下面是教学级片段，展示职责/数据/映射/副作用，而不是完整框架实现：

```js
// Responsibility: 将一次受控提交的 Problem.fieldErrors 映射到摘要和字段状态。
// Data source: 只接收已解析并通过结构边界检查的 Problem；未知字段进入全局项。
// Mapping: API field 通过固定 allowlist 映射 DOM id，message 只用 textContent 输出。
// Side effects: 更新错误 DOM/ARIA，并在用户触发的失败提交后把焦点移到摘要。
const fieldToId = Object.freeze({
  assetId: "asset-id",
  category: "category",
  priority: "priority",
  description: "description"
});

function showProblem(problem) {
  const summary = document.querySelector("#error-summary");
  const list = summary.querySelector("ul");
  list.replaceChildren();

  for (const error of problem.fieldErrors ?? []) {
    const id = fieldToId[error.field];
    const control = id ? document.getElementById(id) : null;
    if (control) control.setAttribute("aria-invalid", "true");

    const item = document.createElement("li");
    item.textContent = error.message;
    list.append(item);
  }

  summary.hidden = false;
  summary.focus();
}
```

真实实现还要清除旧错误、维护字段错误 id/`aria-describedby`、处理 global Problem、请求竞态、取消与成功状态。何时 focus summary、是否另用 live status，要在目标读屏器避免重复播报后决定。

### 9.3 状态消息与结果

“正在提交”“已创建工单 WO-…”“会话过期”优先级不同。成功结果若发生导航，新页面标题/h1 和 focus 可能比 live message 更可靠；身份过期需要可操作的重新登录路径；服务器无响应不能永远 `aria-busy=true`。ARIA 不修复后端无 traceId、错误字段漂移或创建结果不确定。

## 10. 从空白表单到可完成任务

最低语义结构：skip link（在聚焦时可见）、header/main/h1、form、fieldset/legend、每个控件 label、帮助/错误说明、原生 submit button、错误摘要、结果状态。不要为了 landmark 数量添加无意义 role。

任务脚本：

1. 从浏览器内容区起点按 Tab，skip link 可见并能跳主内容；
2. 按顺序到每个控件，焦点可见且未遮挡；
3. 读屏器能听到名称、必填/类型/帮助；
4. 留空 description 提交，原生错误或项目选定错误策略可感知；
5. 模拟服务器返回两个 fieldErrors，摘要出现、焦点去预期位置、字段状态同步；
6. 激活摘要中的字段路径或继续 Tab，能到达具体错误；
7. 修正后旧 `aria-invalid`/错误关系清除；
8. 再提交成功，结果可感知且焦点/导航有落点；
9. Shift+Tab 反向走，任何点都可离开；
10. 不用鼠标完成文件选择之外的流程（系统文件选择器也需键盘实测）。

表单提交真正创建数据时仍依赖上一章的服务端校验、授权与幂等。禁用按钮或 aria-busy 改善体验，却不提供后端 exactly-once 保证。

## 11. 三类故障诊断

### 11.1 焦点陷阱

故障：某脚本拦截 Tab，让焦点在 description/submit 两项循环；或 overlay 已隐藏但内部按钮仍可聚焦。首证据是键盘日志/`activeElement` 序列与预期首次重复/进入隐藏节点。鼠标能点出不是修复。

修复：普通页面删除无理由 keydown trap/正 tabindex，让 DOM 自然排序；若是真 modal，按规范 pattern 实现进入、循环、Escape、关闭和 opener 恢复，并测试反向顺序。重跑相同动作清单。残余风险：OS 全键盘设置、嵌入 iframe、第三方 widget。

### 11.2 无名称控件

故障：图标按钮只有 SVG，没有可见文字或适用名称。首证据是 Accessibility 面板 role=button、name 为空，而非 DOM 有 `title` 猜测。修复优先添加可见“删除附件”等文字；若场景确需仅图标，使用适用名称并验证本地化/语音控制。重跑 tree 与读屏任务。残余风险：多个“删除附件”仍不可区分，需要包含文件上下文。

### 11.3 错误 ARIA 状态

故障：说明面板已打开，但 button `aria-expanded=false`；或错误已清除仍 `aria-invalid=true`。首证据是可见/DOM 行为状态与 Accessibility state 首次不同。修复让同一状态更新 DOM 可见性、ARIA 和按钮文字；不要另建两份布尔。重跑开/关/错误/修复全过程。残余风险：异步竞态或框架 hydration 覆盖。

### 11.4 屏幕阅读器沉默

若 DOM 有错误却没有播报，按层检查：消息是否实际插入/可见；控件 description/error relationship 是否存在；live region 是否先存在、是否被 aria-hidden；focus 是否落到摘要；Accessibility tree 是否暴露；最后才是具体读屏器设置/兼容。不要盲加多个 `role=alert`。

### 11.5 失败日志模板

```text
fixture: accessible-report-form-v1@sha256:...
environment: macOS/version, Safari/version, VoiceOver/version/settings
task/action: submit with empty description, then server returns two fieldErrors
prediction: focus=#error-summary; name/description announced; invalid fields=true
first_divergence: activeElement remains #submit and no summary node in accessibility tree
stage: dynamic DOM/focus management
repair: render summary, then focus existing tabindex=-1 node after user-triggered response
rerun: identical keyboard sequence and Problem fixture; expected focus/announcement observed
residual_risk: NVDA/Firefox and mobile screen readers unverified
```

## 12. 审计矩阵：工具与结论不越权

| 检查 | 输入 | 预期 | 证据 | 不能单独证明 |
|---|---|---|---|---|
| 静态 HTML | page/source hash | 原生元素、label/ref 完整 | oracle/validator | 实际名称/键盘行为 |
| Tab 顺序 | 固定起点与动作 | 与 DOM/清单一致，无 trap | 键盘日志+视频 | 读屏器理解 |
| focus visible | 各控件/缩放/主题 | 清晰且未遮挡 | 截图/人工记录 | 所有视觉障碍场景 |
| accessibility tree | 指定浏览器 | role/name/state/关系匹配 | 面板导出/截图 | 真实读屏播报 |
| screen reader | 固定版本/设置 | 能完成错误—修正—成功任务 | 按键+播报记录 | 其他组合/完整 WCAG |
| 自动扫描 | 固定工具/规则 | 零约定严重问题 | 报告 | 无逻辑/焦点/认知问题 |

至少测试一个桌面浏览器+读屏器组合；产品支持矩阵若含 Windows/移动端，应增加 NVDA/JAWS/TalkBack/VoiceOver 等对应环境。不要写“用 VoiceOver 测了所以屏幕阅读器兼容”。

读屏器有浏览/虚拟光标与表单/焦点模式，按键可能被辅助技术截获。记录模式、verbosity、语言和是否启用快速导航。浏览器 DevTools Accessibility 面板不是读屏器模拟器。

## 13. FactoryCare 表单错误与业务边界

FactoryCare `Problem` 要求 type、title、status、code、message、traceId，可有 `fieldErrors[{field,code,message}]`。前端无障碍层可以：

- 把已知 field 映射到固定控件/错误 id；
- 显示全局 title/message/traceId（按隐私设计）；
- 在用户提交后设置焦点/状态与可感知反馈；
- 保留输入，让用户修正而不重填。

它不能：

- 把 403 伪装成字段错误；
- 在服务器没有结果时宣布“创建成功”；
- 用 aria-disabled 替代 permission check；
- 用客户端校验阻止恶意请求；
- 因字段名漂移就猜测映射到另一个业务字段；
- 把未知服务端 HTML message 用 innerHTML 插入。

错误分类影响任务恢复：400 fieldErrors 回字段；401 提供登录恢复并保存安全草稿策略；403 解释无权限而不是让用户继续改值；409 并发/幂等冲突提供刷新/重试决策；依赖失败保留手工流程。ARIA 只负责可感知状态，不能替业务恢复设计。

## 14. 常见误解与更正

| 误解 | 为什么错 | 更可靠规则 |
|---|---|---|
| 加 aria-label 就无障碍 | 只影响适用名称，还可能覆盖可见文字 | 原生+任务证据，ARIA 最少使用 |
| role=button 等于 button | 不自动添加键盘/表单/disabled 行为 | 使用原生 button |
| 所有内容都 tabindex=0 | 让 Tab 路径冗长 | 语义内容供浏览模式，Tab 给交互项 |
| 正 tabindex 能修复顺序 | 与 DOM/视觉脱节、难维护 | 修 DOM/信息架构 |
| 去掉 outline 更美观 | 用户失去位置 | 保留/设计清晰焦点并实测 |
| aria-hidden 可视觉隐藏 | 它主要影响辅助技术树 | 使用适当 hidden/inert/CSS 并同步焦点 |
| aria-disabled 会阻止操作 | 只声明状态 | 实现行为并服务端授权 |
| Accessibility 面板绿就读屏通过 | 它不执行任务/播报 | 用真实读屏器记录 |
| 自动扫描零错误即 WCAG 合规 | 扫描只覆盖可自动判断子集 | 结合人工与用户任务 |
| 焦点 trap 永远错误 | modal 有意约束焦点 | 仅在正确模式实现进入/关闭/恢复 |
| live=assertive 最可靠 | 会打断并制造噪声 | 选最低必要优先级并测试 |

## 15. 独立实验：从空目录复现

目标：将上一章原生工单表单改造成键盘与屏幕阅读器可完成的交互，保存静态、键盘、tree、reader 四层证据；注入三类故障。

### 15.1 工件要求

- 原生 header/main/h1/form/fieldset/legend/label/control/button；
- DOM 顺序与任务一致，无正 tabindex；默认焦点指示未被移除；
- help/error 使用稳定 id 与描述关系；错误时 aria-invalid 同步；
- 错误摘要可脚本聚焦但不进入正常 Tab 顺序；
- 所有仅图标动作有可区分名称，优先可见文字；
- 展开状态、hidden、按钮文字与 aria-expanded 同源；
- JS 四类意图注释完整，用 textContent 和 allowlist 映射 fieldErrors；
- audit matrix 明确哪些是预言、哪些真实观察；
- 不读 private solution，不把自动结果写成真实读屏器结果。

### 15.2 执行与故障

运行 lab 唯一 `verify.sh` 得到离线基线。随后在获批浏览器/读屏器中从清空状态执行固定按键序列，记录实际 focus、role/name/state、播报和完成结果。

1. 注入 Tab 循环/隐藏可聚焦项，保存第一个重复 activeElement；
2. 删除附件按钮名称，保存 Accessibility name 为空；
3. 让面板可见但 aria-expanded=false，保存状态分歧；
4. 每次只修一个变量，用相同动作与 Problem fixture 重跑；
5. 反向 Shift+Tab、错误修正、关闭/恢复都要覆盖；
6. 报告未测浏览器/读屏器组合与业务恢复路径。

## 16. 120 秒讲解模板

> 无障碍交互从正确原生 HTML 开始：button、link、label/control 和 fieldset 自带语义与基础键盘行为，ARIA 只补原生表达不了的名称、关系和状态，不自动创造行为。Tab 顺序尽量跟 DOM，避免正 tabindex，焦点必须可见；只有 modal、错误摘要或路由等任务变化才谨慎移动焦点，并在关闭/删除后恢复。浏览器从 DOM/原生/ARIA 计算 accessibility tree 的 role、name、description、state/value，DevTools 能检查映射，但最终要用真实键盘和读屏器完成任务。动态 fieldErrors 用固定 allowlist 映射，aria-invalid/expanded/live 与可见状态同源。遇到 trap、空 name 或错误 ARIA，我找第一条 focus/tree/行为分歧，修复后重跑同一动作。ARIA 不能修复服务端授权、模糊流程或错误业务结果。

## 17. 官方来源与版本边界

本章于 **2026-07-17** 核验：

- [WHATWG HTML Living Standard：Interaction / Focus](https://html.spec.whatwg.org/multipage/interaction.html#focus)：focus、sequential focus navigation 与 tabindex 的规范入口。
- [WAI-ARIA APG：Read Me First](https://www.w3.org/WAI/ARIA/apg/practices/read-me-first/)：原生 HTML 优先、ARIA 不自动提供行为及模式测试边界。
- [WAI-ARIA APG：Developing a Keyboard Interface](https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/)：Tab、复合组件、焦点可见/可预测与键盘约定。
- [Accessible Name and Description Computation 1.2](https://www.w3.org/TR/accname-1.2/)：name/description 计算算法。
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)：键盘、无焦点陷阱、焦点可见/未遮挡/外观、名称角色值、状态消息等成功准则。
- [W3C WAI Forms Tutorials](https://www.w3.org/WAI/tutorials/forms/)：label、说明、校验与通知的任务级入口。

已确认：原生优先、键盘/焦点模型、名称/状态和证据边界已对照一手资料；离线工件可重复。未确认：目标 OS/browser Accessibility 映射、VoiceOver/NVDA/JAWS/TalkBack 实际播报、强制色/高对比/放大、系统文件选择器、FactoryCare 网络与 fieldErrors 集成。APG 示例不是生产兼容保证，WCAG conformance 也不能由单章或单工具声明。

## 18. 交付检查表

- [ ] 关键任务使用原生交互元素，ARIA 没有替代可用 HTML。
- [ ] Tab/Shift+Tab/Enter/Space/方向键的期望按组件类型明确。
- [ ] 无正 tabindex、无普通页面 trap，焦点始终可见且未遮挡。
- [ ] 打开、关闭、错误、删除、成功后的焦点落点与恢复已验证。
- [ ] 每个控件/按钮在 Accessibility 面板有正确且可区分的 name。
- [ ] help/error 是 description，不覆盖 label；aria-invalid 随验证清除/设置。
- [ ] expanded/hidden/live/busy 等 ARIA 与真实 UI/行为同源。
- [ ] 动态 Problem 使用 allowlist、textContent、全局错误和未知字段降级。
- [ ] 键盘日志、tree 截图、读屏器按键/播报和环境版本完整。
- [ ] 三类故障都有首证据、修复、同任务重跑与残余风险。
- [ ] 我没有把静态 oracle/扫描器结果称作 WCAG 或屏幕阅读器认证。

达到这些条件，才形成 `web.accessibility` 能力的入门证据，而不是“加过 ARIA”。
