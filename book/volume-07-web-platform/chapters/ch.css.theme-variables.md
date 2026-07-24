---
schema_version: 2
edition: 2026.2-draft
id: ch.css.theme-variables
title: 颜色、主题与 CSS 自定义属性
responsibility: 用设计 token、自定义属性、颜色对比和系统偏好表达主题，不在本章建立完整组件库。
volume: '07'
order: 12
level: L1-L2
status: drafting
path: book/volume-07-web-platform/chapters/ch.css.theme-variables.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.css.cascade
version_surfaces:
- css
- chrome-stable
- chrome-devtools
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“颜色、主题与 CSS 自定义属性”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - css-custom-properties
  - css-color-theme
  covers_topics:
  - css.custom-property
  - css.var-fallback
  - css.property-inheritance
  - css.design-token-scope
  - css.color-space
  - css.contrast-ratio
  - css.prefers-color-scheme
  - css.theme-override
  uses_capabilities: []
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“颜色、主题与 CSS 自定义属性”构建可运行程序与测试：为语义页面建立可回退的亮暗主题 token 并记录对比度证据；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - css-custom-properties
  - css-color-theme
  covers_topics:
  - css.custom-property
  - css.var-fallback
  - css.property-inheritance
  - css.design-token-scope
  - css.color-space
  - css.contrast-ratio
  - css.prefers-color-scheme
  - css.theme-override
  uses_capabilities: []
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: computed-token-check-contrast-check-theme-matrix
- id: diagnose
  kind: fault-diagnosis
  text: 面对“变量作用域、回退或对比度配置错误导致的不可读主题”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - css-custom-properties
  - css-color-theme
  covers_topics:
  - css.custom-property
  - css.var-fallback
  - css.property-inheritance
  - css.design-token-scope
  - css.color-space
  - css.contrast-ratio
  - css.prefers-color-scheme
  - css.theme-override
  uses_capabilities: []
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 颜色、主题与 CSS 自定义属性

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《CSS 语法、选择器、层叠、优先级与继承》](ch.css.cascade.md)：自定义属性的继承、覆盖和回退完全依赖层叠计算，必须先能解释最终值来源。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套工件以静态源码合同、主题矩阵和不透明 sRGB 对比度计算建立离线证据；绿灯不等于真实浏览器 computed style、Windows 强制颜色、宽色域、背景图、屏幕阅读器或人工视觉已验证。易变事实已于 **2026-07-17** 对照 W3C CSS Custom Properties Level 1、CSS Color 4、CSS Color Adjustment 1、Media Queries 5 与 WCAG 2.2 一手规范核验。

主题不是“把页面背景换成黑色”，自定义属性也不是脱离层叠的全局常量。本章建立一条可以解释、测量和故障定位的链：原始颜色经过语义 token 命名，在确定的作用域中由层叠和继承选出 computed value，再由 `var()` 替换到普通属性；作者亮暗主题、显式用户覆盖与强制颜色分别改变这条链的不同环节；最终必须以具体前景/背景/状态色对验证对比度。

本章不建立完整组件库，不处理主题偏好的 JavaScript 持久化、服务端首屏同步、跨 iframe 协议、品牌插画重着色或设计工具流水线。反例：用户刷新后仍要保持账号级主题，涉及存储、启动时序与服务端渲染，不能只靠本章的 CSS 方案解决。

## 1. 完成定义、边界与证据入口

完成本章，应能独立做到：

1. 解释自定义属性与普通属性一样参加层叠，默认继承，其初始值是 guaranteed-invalid value；
2. 预测根作用域、组件作用域、状态作用域和后代继承后的 token 值，并从 computed style 找到获胜声明；
3. 正确使用 `var(--name, fallback)` 与嵌套回退，知道“变量存在但替换后类型无效”不会退回第二参数；
4. 区分 palette primitive、semantic token 与 component token，不让组件直接依赖某个品牌色编号；
5. 建立亮色默认、系统暗色偏好、显式亮/暗覆盖的清晰优先级，并说明 CSS 本身不负责持久化；
6. 说明 `color-scheme` 让浏览器控制的表单、滚动条和画布适配，但不会替作者生成完整配色；
7. 为普通文本、大号文本、控件边界、焦点和图形分别记录色对与阈值，不把 token 表当成合规证明；
8. 说明 sRGB、HSL、Lab/LCH、OKLab/OKLCH 等颜色空间的用途边界，并给旧实现准备可接受的级联回退；
9. 在 `forced-colors: active` 下优先允许 UA 与系统色接管，仅在确有证据时局部使用 `forced-color-adjust`；
10. 注入作用域泄漏、回退误解或低对比度故障，沿“声明—层叠—替换—普通属性—used value”找到首个可信证据。

配套入口：

- [主题矩阵与对比度示例](../../../examples/encyclopedia/ch.css.theme-variables/README.md)
- [作用域、回退与低对比度故障实验](../../../labs/encyclopedia/ch.css.theme-variables/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.css.theme-variables/README.md)

canonical oracle 是：**亮色、暗色、缺失 token 与局部覆盖场景中的计算值和对比度均符合预设表格。** 离线 oracle 只验证夹具中写明的静态映射和不透明十六进制 sRGB 色对。正式 G4 证据还要保存浏览器与操作系统版本、视口与缩放、系统主题和强制颜色设置、关键节点的 computed/used value、表单与焦点截图、对比度工具输入、键盘路径以及屏幕阅读器观察。

## 2. 从声明到屏幕：主题推理管线

```text
CSS origins / layers / specificity / source order
  → 每个元素上选出 custom property 的 cascaded value
  → 继承得到该元素的 custom property computed value
  → 在同一元素上解析 var() 依赖与循环
  → 替换到 color、background、border 等普通属性
  → 普通属性语法检查与 computed value
  → color-scheme / forced-colors / UA 调整影响 used value
  → 实际背景叠加、字体渲染、焦点和交互状态
  → 对比度与人工/辅助技术验证
```

这条顺序是诊断地图。若 DevTools 中 `--color-text` 的获胜声明就错了，先查作用域、选择器和层叠；若变量值正确而 `color` 被划掉，查替换后的语法；若 computed color 正确但强制颜色下屏幕不同，查 used value 与 UA 调整；若静态正文通过而 hover/focus 失败，查漏测的交互状态，不要修改无关 token。

“变量在 `:root` 定义”只是一个常见策略，不是语言规则。变量取自**使用该 `var()` 的元素自身**所拥有的 custom property computed value。这个值可能直接声明在元素上，也可能从最近祖先继承，还可能由媒体查询、层、重要性、特殊性与源码顺序共同选出。

## 3. 自定义属性不是预处理器变量

[CSS Custom Properties Level 1](https://www.w3.org/TR/css-variables-1/) 规定 `--*` 适用于所有元素和伪元素，默认继承，初始值是 guaranteed-invalid value。它们保留 token stream，直到被 `var()` 替换进一个有具体语法的普通属性。由此得到四个实用结论。

第一，名称区分大小写。`--color-text` 与 `--Color-Text` 是两个属性，团队应约定 ASCII 小写和稳定前缀，避免肉眼近似字符。第二，`all` 不会重置 custom properties；把 `all: unset` 当“清空组件变量”的方法会留下继承 token。第三，custom property 的值可以在声明时看起来“什么都能写”，真正的类型错误可能到替换进 `color`、`width` 等属性后才暴露。第四，循环以元素为单位求解；循环中的 custom properties 在 computed-value time 失效。

```css
/* Responsibility: 为页面建立可继承的语义颜色输入。 */
/* Data source: 经评审的亮色基线，不来自组件内部硬编码。 */
/* Mapping: canvas/text/surface/accent 表达用途，不表达具体组件。 */
/* Side effects: 根作用域声明会继承到后代，局部覆盖会继续向其后代传播。 */
:root {
  --color-canvas: #ffffff;
  --color-text: #172033;
  --color-surface: #f4f7fb;
  --color-accent: #0b5cad;
  --color-on-accent: #ffffff;
}

body {
  color: var(--color-text);
  background: var(--color-canvas);
}
```

注意“继承变量”和“继承最终属性”不同。父元素可以只声明 `--color-text`，后代的 `color: var(--color-text)` 在后代自身解析；父元素也可以声明 `color`，让后代直接继承普通 `color`。前者保留了组件在自身作用域覆盖 token 的机会，后者继承的是已计算的普通属性。

### 3.1 局部覆盖的传播边界

组件覆写 semantic token 时，覆写会传给所有后代，除非更近的规则再覆盖。这个能力适合“危险区内的强调色都变红”，也容易造成 scope leak：把 `--color-text` 写在过高的 `.page` 上，会让本不相关的帮助栏一起变色。

```css
/* Responsibility: 只在危险操作区重新解释 accent 语义。 */
/* Data source: 危险状态色对，经独立对比度检查。 */
/* Mapping: accent 供按钮和链接读取；正文 token 保持根值。 */
/* Side effects: 覆盖会继承到 danger-zone 的全部后代，不影响兄弟节点。 */
.danger-zone {
  --color-accent: #b42318;
  --color-on-accent: #ffffff;
}
```

作用域设计应先回答“谁有权改这个语义”。全站语义 token 放根或主题边界；组件私有 token 放组件根；单一状态 token 放状态选择器。不要在某个深层图标上覆盖一个全局名称，再期待外层按钮读取到它——继承只从祖先到后代，不会向上或横向传播。

## 4. `var()` 回退：缺失保护，不是类型校验

`var(--name, fallback)` 的第二参数只在引用的 custom property 是 guaranteed-invalid（通常是缺失、显式 `initial` 或因循环失效）时参与替换。逗号之后直到函数结尾都属于 fallback，因此 `var(--shadow, 0 1px 2px rgb(0 0 0 / .2), 0 0 1px black)` 的回退本身可以含逗号。

```css
/* Responsibility: 组件优先读取私有表面 token，并提供两级安全回退。 */
/* Data source: component → theme → system color 的明确降级链。 */
/* Mapping: 缺失 component token 时读取全局 surface，再缺失则交给 Canvas。 */
/* Side effects: 只影响该组件背景；不会创建或持久化任何 token。 */
.panel {
  background: var(--panel-surface, var(--color-surface, Canvas));
}
```

最常见的误解是：

```css
:root { --space: red; }
.card { padding: var(--space, 1rem); }
```

`--space` 已存在，不会采用 `1rem`。替换后得到 `padding: red`，该普通属性在 computed-value time 无效，并按该属性的失效规则处理。浏览器发现得太晚，层叠中较早的 `padding` 声明也可能已被丢弃。回退因此不是 runtime 类型系统；应通过命名、代码审查、静态检查与受控测试保证 token 类型。

另一个陷阱是循环，即便循环只出现在 fallback 依赖边中也会进入依赖图。`--a: var(--b); --b: var(--a)` 会让两者失效。跨元素继承可能打破表面上的文本循环，因为每个元素以自己的 computed custom properties 建图；调试时必须看具体元素，不能只全文搜索名称。

高级项目可研究 `@property` 注册类型、初始值与 `inherits` 行为，但它是额外版本表面，且不能替代 token 架构。本章稳定核心先掌握未注册 custom properties 的标准行为；是否引入注册、如何做兼容回退，应另立决策与真实目标浏览器测试。

## 5. Token 架构：从原始颜色到语义用途

设计 token 的价值不是把所有字面量换成变量，而是建立受控决策层。一个可维护的三层模型是：

```text
palette primitive       semantic token          component token
--blue-700: #0b5cad  →  --color-accent       → --button-bg
--white: #fff         →  --color-on-accent    → --button-fg
```

primitive 描述颜色本身，semantic token 描述用途，component token 表达组件的可配置接口。简单页面不必机械建立三层；如果组件直接读取 `--blue-700`，暗色主题可能仍能工作，但语义改变必须全局搜索实现细节。若每个局部像素都创建 token，依赖图又会膨胀。判断标准是：这个值是否需要跨主题改变、是否由多个消费者共享、是否构成对外配置合同。

命名应以角色为中心：`--color-text-muted` 比 `--gray-500` 更能说明用途；`--color-danger-surface` 与 `--color-danger-text` 明确成对；`--focus-ring-color` 提醒它需要独立非文本对比度验证。不要假设同一个 accent 能同时作为链接文字、按钮背景、图标和焦点环——这些位置的相邻背景和阈值不同。

Token 清单至少记录：名称、语义、允许作用域、亮/暗值、消费者、前景或背景角色、需验证的状态、弃用策略。这里只建立颜色主题合同，不扩展为完整间距、字体、圆角和组件库治理。

## 6. 亮色、系统暗色与显式覆盖

主题来源至少有三种：作者默认、操作系统/浏览器偏好、站点显式选择。它们必须有可读的优先级。一个常用合同是：无显式选择时跟随系统；存在 `data-theme="light|dark"` 时，显式选择覆盖媒体查询。要实现这个合同，可让显式规则位于媒体规则之后，并保持同等或更高的层叠优先级。

```css
/* Responsibility: 声明页面可支持的 UA 亮暗界面，并提供亮色基线。 */
/* Data source: 主题矩阵中的亮色 token。 */
/* Mapping: 根 token 供语义消费者继承；color-scheme 只声明 UA 支持范围。 */
/* Side effects: 浏览器控制的表单、滚动条与 canvas 可能随 used scheme 改变。 */
:root {
  color-scheme: light dark;
  --color-canvas: #ffffff;
  --color-text: #172033;
  --color-surface: #f4f7fb;
  --color-accent: #0b5cad;
  --color-on-accent: #ffffff;
}

/* Responsibility: 无显式覆盖时响应用户暗色偏好。 */
/* Data source: prefers-color-scheme 媒体特征和暗色矩阵。 */
/* Mapping: 同一语义名映射到暗色值，不修改组件选择器。 */
/* Side effects: 偏好变化可触发重算；不保存站点选择。 */
@media (prefers-color-scheme: dark) {
  :root {
    --color-canvas: #0f172a;
    --color-text: #f8fafc;
    --color-surface: #1e293b;
    --color-accent: #60a5fa;
    --color-on-accent: #0f172a;
  }
}

/* Responsibility: 让用户的站点内显式选择覆盖系统偏好。 */
/* Data source: 文档根上的 data-theme；属性如何持久化不属于本章。 */
/* Mapping: light/dark 均完整覆盖关键语义色，避免混合主题。 */
/* Side effects: 属性改变会重算后代样式；CSS 不写存储或账号数据。 */
:root[data-theme="light"] {
  color-scheme: light;
  --color-canvas: #ffffff;
  --color-text: #172033;
  --color-surface: #f4f7fb;
  --color-accent: #0b5cad;
  --color-on-accent: #ffffff;
}

:root[data-theme="dark"] {
  color-scheme: dark;
  --color-canvas: #0f172a;
  --color-text: #f8fafc;
  --color-surface: #1e293b;
  --color-accent: #60a5fa;
  --color-on-accent: #0f172a;
}
```

`prefers-color-scheme` 报告用户偏好，不等于授权作者忽略显式选择；`color-scheme: light dark` 表示元素支持哪些 scheme，让 UA 选择表单、滚动条、默认画布等浏览器控制外观，它不是具体 palette，也不会重写作者所有颜色。只改 `color-scheme` 而不提供匹配的前景背景，可能产生不协调甚至不可读组合。

若产品需要“系统/亮/暗”三态，`system` 可表示移除显式 `data-theme`，让媒体查询生效；但点击、存储、首屏防闪烁属于 JavaScript/服务端集成。CSS 章节只定义输入属性和层叠合同，不能宣称完成持久化体验。

## 7. 颜色空间与渐进增强边界

[CSS Color 4](https://www.w3.org/TR/css-color-4/) 扩展了现代颜色语法和颜色空间。工程上应按任务选空间：

- 十六进制、`rgb()` 适合明确 sRGB 值与当前离线对比度 oracle；
- `hsl()` 便于按 hue/saturation/lightness 表达，但数值等距不保证感知等距，也不保证对比度；
- Lab/LCH 与 OKLab/OKLCH 更适合感知方向的亮度、色度和色相调整，但仍需 gamut mapping 与最终色对测量；
- `color(display-p3 ...)` 等宽色域值需要真实设备、浏览器和回退验证，不能由 sRGB 截图替代；
- alpha、混合模式、滤镜、背景图和半透明叠加会改变最终颜色，不能直接拿 token 字面量计算即下结论。

渐进增强可先写稳定的 sRGB 回退，再写现代值：

```css
/* Responsibility: 为支持现代颜色空间的实现增强 accent，同时保留 sRGB 基线。 */
/* Data source: 已测量的 sRGB 回退与待真实设备复核的 OKLCH 候选。 */
/* Mapping: 后声明仅在实现能解析时覆盖同一语义 token。 */
/* Side effects: gamut mapping 与显示设备可能改变实际呈现，必须另存证据。 */
:root {
  --color-accent: #0b5cad;
  --color-accent: oklch(48% 0.14 251);
}
```

这不是说第二个值在所有环境“更准确”。它把不支持语法时的解析回退和支持后实际 gamut/对比度验证分开。真实产品还应针对目标浏览器矩阵和设备色域运行截图/测色，本章不虚构这些结果。

## 8. 对比度是色对与状态的证据

[WCAG 2.2 1.4.3](https://www.w3.org/TR/WCAG22/#contrast-minimum) 的 AA 基线要求普通文本至少 `4.5:1`，大号文本至少 `3:1`；[1.4.11](https://www.w3.org/TR/WCAG22/#non-text-contrast) 要求识别控件及状态、理解必要图形所需的视觉信息与相邻颜色至少 `3:1`。阈值不能通过四舍五入“凑过”。颜色也不能作为表达信息、动作或状态的唯一视觉手段。

不透明 sRGB 色对的计算步骤是：

1. 将 8-bit `R/G/B` 除以 255 得到 sRGB 分量；
2. 对每个分量做线性化；
3. 计算相对亮度 `L = 0.2126R + 0.7152G + 0.0722B`；
4. 令较亮为 `L1`、较暗为 `L2`，比值为 `(L1 + 0.05) / (L2 + 0.05)`；
5. 用未四舍五入值与相应阈值比较，显示值仅供阅读。

但“所有 token 两两对比”没有业务意义。证据表应列实际用途，例如：

| 场景 | 前景 token | 背景 token | 阈值 | 需覆盖状态 |
|---|---|---|---:|---|
| 正文 | `--color-text` | `--color-canvas` | 4.5 | light/dark/override |
| 次级正文 | `--color-text-muted` | canvas/surface | 4.5 | 默认、disabled 例外需说明 |
| 主按钮文字 | `--color-on-accent` | `--color-accent` | 4.5 | default/hover/pressed |
| 控件边界 | border | 相邻 canvas | 3.0 | default/focus/error |
| 焦点指示 | focus ring | 两侧相邻色 | 依适用准则 | keyboard focus |

离线工具能重算固定十六进制色对，却不知道浏览器最终选了哪个 token，也看不到 alpha 后的底色、渐变最差位置、背景图、字体抗锯齿、强制颜色 used value 或焦点是否被遮住。因此“contrast-check PASS”是有限证据，不能写成“页面已通过 WCAG”。

## 9. 强制颜色不是第三套品牌主题

[CSS Color Adjustment 1](https://www.w3.org/TR/css-color-adjust-1/) 规定，在 forced colors mode 中，UA 可将受影响颜色的 used value 强制到用户调色板；`forced-colors` 媒体查询允许页面适配，系统颜色如 `Canvas`、`CanvasText`、`ButtonFace`、`ButtonText`、`Highlight`、`LinkText` 提供用户调色板语义。

推荐策略是先允许默认 `forced-color-adjust: auto`，避免依赖背景色块作为唯一边界，并为必要状态提供文本、边框、形状或原生语义。透明边框在普通主题不可见，但强制颜色下可由 UA 显示；`currentColor` 能让图标随文本色。不要在整个页面写 `forced-color-adjust: none` 锁死品牌颜色。

```css
/* Responsibility: 在强制颜色中使用系统语义色保留按钮、链接与边界。 */
/* Data source: forced-colors 媒体特征及 UA 提供的系统调色板。 */
/* Mapping: canvas/text/accent 映射到系统用途，不模拟品牌亮暗主题。 */
/* Side effects: used color 由用户代理和用户设置决定；静态 hex oracle 无法证明结果。 */
@media (forced-colors: active) {
  :root {
    --color-canvas: Canvas;
    --color-text: CanvasText;
    --color-surface: Canvas;
    --color-accent: LinkText;
    --color-on-accent: Canvas;
  }

  .button {
    border: 2px solid ButtonText;
  }

  .button:focus-visible {
    outline: 3px solid Highlight;
    outline-offset: 3px;
  }
}
```

`forced-color-adjust: none` 只有在作者自己完整支持用户颜色与对比需求、且 UA 默认调整确实破坏必要内容时才局部使用。该属性继承，误放根节点影响很大。插画、图表等复杂 SVG 可能需要专门策略，但这要求真实强制颜色测试和替代信息，不在本章把一条 CSS 声明包装成通用修复。

强制颜色可能同时影响 `prefers-color-scheme` 的匹配，但仍应把两个模式的责任分开：亮暗偏好选择作者支持的 scheme，forced colors 则让用户的受限调色板控制 used colors。验收必须在真实支持环境中打开该模式，检查文本、链接、表单、焦点、选中、错误和 disabled 状态。

## 10. 可复现主题矩阵

一个可审计矩阵至少包含四条路径：

```text
light baseline
  root semantic tokens → component default → expected text/background/ratio

dark preference
  @media dark tokens → component default → expected text/background/ratio

explicit override
  system preference + data-theme → explicit rule wins → complete expected token set

missing/local override
  missing component token → nested fallback；danger-zone local accent → only descendants
```

每个案例应保存：输入（属性、媒体偏好、作用域）、期望 token、期望最终普通属性、色对阈值、离线输出、真实浏览器证据状态。不要把“dark=true”写成一个没有具体环境的截图名称，也不要只测首页静态正文。

配套示例的 `theme-matrix.json` 明确把 `real_browser_computed_recorded`、`real_forced_colors_recorded`、`real_screen_reader_recorded` 与 `real_visual_review_recorded` 保持为 `false`。这是诚实边界，不是缺陷掩盖：当前工件只承诺离线可重现；正式评审应把这些字段换成具体证据路径，而不是直接改成 `true`。

## 11. 故障诊断：找首个可信差异

### 11.1 作用域错误

症状：危险区之外的链接也变红。先选中错误元素，在 Computed/Styles 中展开 `--color-accent`，记录获胜声明和继承来源。若来源是过高祖先，首个可信差异在 token scope，不在按钮 `background`。把覆盖移到最小共同组件根，再验证兄弟、后代与嵌套组件。

### 11.2 回退错误

症状：声明写了 fallback，属性仍恢复初始值。检查 custom property 是否其实存在但值与消费属性类型不匹配。用最小复现记录替换前 token 与替换后目标值；修复 token 类型或消费合同，而不是继续堆第三层 fallback。

### 11.3 对比度错误

症状：暗色主按钮文字难读。先确认实际 state、前景和背景 used colors，避免拿默认态 token 代替 hover/pressed。重算未取整比值，确定阈值类别；优先调整语义色对，再复测所有消费者，防止只修按钮却破坏链接。

### 11.4 覆盖顺序错误

症状：用户选择 light，但系统暗色仍获胜。比较两个规则的 origin、layer、important、specificity 与 source order；显式主题必须在合同规定的优先级获胜。不要用不断加 ID 或 `!important` 隐藏架构问题。

### 11.5 强制颜色错误

症状：焦点环或图标消失。开启真实 forced colors，检查背景图是否被抑制、颜色是否被 UA 替换、边框/outline 是否存在、状态是否只靠颜色。优先使用系统色和结构性指示；若考虑 opt-out，要记录为什么 UA 调整不适用，以及 opt-out 后怎样满足用户需求。

修复后的“重跑同一验证”意味着输入、命令、阈值和 oracle 不变，只替换故障实现；否则不能证明修复对应原失败。

## 12. 实验与考核协议

独立构建建议按以下顺序完成：

1. 从空目录创建语义 HTML，不复制示例成品；
2. 列出页面实际色对与状态，再定义 semantic tokens；
3. 写亮色基线、暗色偏好、显式 light/dark 覆盖，规定优先级；
4. 为组件设置一个局部覆盖和一个嵌套 fallback；
5. 为固定 sRGB 色对保存对比度输入、精确计算与阈值；
6. 注入 scope、fallback 或 contrast 故障，保存首次失败输出；
7. 只修首因，重跑同一命令并保存绿色输出；
8. 在真实浏览器补 computed style、主题切换、forced colors、键盘焦点与视觉证据；
9. 写残余风险：透明度、宽色域、图像、用户样式和辅助技术中哪些尚未覆盖。

120 秒讲解可以采用“职责—机制—证据—反例”结构：本章用 custom properties 和 semantic tokens 表达主题；层叠/继承决定变量，`var()` 在消费元素替换，媒体偏好与显式属性按合同覆盖；固定矩阵和色对计算提供离线证据，浏览器与强制颜色需要实测；账号级偏好持久化不是 CSS 主题章能独立解决的问题。

## 13. 证据分层与未验证声明

已由配套离线工具验证的内容：源码包含四类意图注释；关键 token、媒体查询、显式覆盖、局部覆盖、嵌套 fallback 与 forced-colors 合同存在；固定主题矩阵结构正确；不透明十六进制 sRGB 色对按同一算法达到矩阵阈值；公开故障夹具稳定失败。

尚未由本章工件验证的内容：真实浏览器的 computed/used values；目标浏览器对现代颜色语法的解析与 gamut mapping；真实 Windows/浏览器 forced colors；表单控件、滚动条和 canvas 的实际 `color-scheme` 呈现；透明叠加、渐变和背景图最差对比度；字体渲染与显示器；键盘焦点完整路径；屏幕阅读器；人工视觉评审。任何交付报告都必须把这两组分开。

## 14. 规范索引与版本说明

- [CSS Custom Properties for Cascading Variables Module Level 1](https://www.w3.org/TR/css-variables-1/)：custom property 的适用范围、默认继承、guaranteed-invalid value、循环、`var()` 与 invalid-at-computed-value-time。核验于 2026-07-17。
- [CSS Color Module Level 4](https://www.w3.org/TR/css-color-4/)：颜色语法、颜色空间与转换边界。核验于 2026-07-17。
- [CSS Color Adjustment Module Level 1](https://www.w3.org/TR/css-color-adjust-1/)：`color-scheme`、forced colors、系统色与 `forced-color-adjust`。核验于 2026-07-17。
- [Media Queries Level 5](https://www.w3.org/TR/mediaqueries-5/)：`prefers-color-scheme` 与 `forced-colors` 媒体特征。核验于 2026-07-17。
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)：1.4.1、1.4.3、1.4.11 及对比度定义。核验于 2026-07-17。

规范的最新编辑草案、浏览器实现和系统设置都会变化。稳定核心是层叠、继承、回退语义、语义作用域与“实际色对必须测量”；现代颜色空间的具体支持、UA 调色结果和工具输出属于版本表面，发布前应重新核验。

## 15. 最终检查表

- [ ] 我能从具体元素解释 custom property 的获胜声明和继承来源。
- [ ] 我知道 fallback 只处理 missing/invalid variable，不验证消费属性类型。
- [ ] 亮色、暗色和显式覆盖都完整定义关键 semantic tokens。
- [ ] 显式选择与系统偏好的优先级有源码和矩阵证据。
- [ ] 组件覆盖位于最小合理作用域，并验证兄弟不受影响。
- [ ] 每个正文、按钮、边界、焦点和状态都有实际前景/背景色对。
- [ ] 对比度使用未取整值判定，且不把离线 hex 计算扩张为整页合规。
- [ ] `color-scheme` 与作者 palette 的职责没有混淆。
- [ ] forced colors 默认允许 UA 接管，并用真实环境补证据。
- [ ] 现代颜色语法有可接受回退和目标环境验证计划。
- [ ] 首次失败、最小修复、同一验证重跑与残余风险均可追溯。
- [ ] 未把主题持久化、完整组件库或跨文档协议塞进本章。
