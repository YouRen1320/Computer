---
schema_version: 2
edition: 2026.2-draft
id: ch.css.motion-compositing
title: 过渡、变换、动画、合成与减少动效
responsibility: 用过渡、关键帧与 transform 表达有意义反馈，并依据合成成本和减少动效偏好限制动画，不处理 JavaScript 长任务优化。
volume: '07'
order: 13
level: L2
status: drafting
path: book/volume-07-web-platform/chapters/ch.css.motion-compositing.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.css.box-position
- ch.web.accessibility-interaction
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
  text: 在 120 秒内解释“过渡、变换、动画、合成与减少动效”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - css-motion-primitives
  - css-motion-performance-a11y
  covers_topics:
  - css.transition
  - css.transform
  - css.keyframes-animation
  - css.animation-fill-iteration
  - css.compositor-friendly-property
  - css.layer-promotion-boundary
  - css.prefers-reduced-motion
  - a11y.focus-visible
  uses_capabilities:
  - web.accessibility
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现含进入、状态反馈和减少动效降级的可访问组件动画；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - css-motion-primitives
  - css-motion-performance-a11y
  covers_topics:
  - css.transition
  - css.transform
  - css.keyframes-animation
  - css.animation-fill-iteration
  - css.compositor-friendly-property
  - css.layer-promotion-boundary
  - css.prefers-reduced-motion
  - a11y.focus-visible
  uses_capabilities:
  - web.accessibility
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: motion-state-matrix-reduced-motion-check-performance-timeline-observation
- id: diagnose
  kind: fault-diagnosis
  text: 面对“动画属性触发布局抖动或忽略减少动效导致的性能与可访问性故障”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - css-motion-primitives
  - css-motion-performance-a11y
  covers_topics:
  - css.transition
  - css.transform
  - css.keyframes-animation
  - css.animation-fill-iteration
  - css.compositor-friendly-property
  - css.layer-promotion-boundary
  - css.prefers-reduced-motion
  - a11y.focus-visible
  uses_capabilities:
  - web.accessibility
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 过渡、变换、动画、合成与减少动效

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《盒模型、display、定位与层叠上下文》](ch.css.box-position.md)：transform、定位与层叠上下文相互作用，必须先能判断包含块和遮挡关系。
- [《无障碍、键盘、焦点与屏幕阅读器》](ch.web.accessibility-interaction.md)：动效不能破坏焦点可见性或忽略减少动效偏好，需先掌握交互无障碍基线。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套工件以静态 CSS 合同和普通/减少动效状态矩阵建立离线证据；它没有运行浏览器 Performance/Layers、没有测量 layout/paint/composite 时间，也没有完成键盘、屏幕阅读器或前庭敏感用户测试。易变事实已于 **2026-07-17** 对照 W3C CSS Transitions 2、CSS Transforms 1、CSS Animations 1、CSS Will Change 1、Media Queries 5 与 WCAG 2.2 一手规范核验。

好的动效说明“发生了什么”：进入关系、状态变化、空间来源或操作反馈。坏的动效让用户等装饰结束、让焦点消失，或以“用了 transform”伪装成已证明的性能优化。本章把动效当一份状态合同：语义状态先成立，视觉插值随后跟进；普通模式有限而可中断；`prefers-reduced-motion: reduce` 下保留即时、低运动量的反馈；性能结论必须由真实时间线支持。

本章不处理 JavaScript 长任务、框架调度、Web Animations API 编排、滚动驱动动画、视频制作或完整性能预算。反例：点击后主线程被 800ms JavaScript 阻塞，CSS 改成 `transform` 不能消除长任务，应在脚本和任务调度章节诊断。

## 1. 完成定义、边界与证据入口

完成本章，应能：

1. 区分 transition 对“两个 computed state 之间变化”的插值与 keyframes 对时间序列的声明；
2. 为状态反馈明确写出 property、duration、delay、timing function，避免无边界的 `transition: all`；
3. 解释 transition 被快速反向或目标改变时会重定向、取消，业务正确性不能只依赖 `transitionend`；
4. 使用 `translate/scale/rotate` 与 `transform-origin`，预测 transform 列表顺序、视觉几何、overflow、stacking context 和 containing block 副作用；
5. 使用 `@keyframes`、iteration、direction、fill-mode 与 play-state，并知道 fill 不修改 DOM/业务状态；
6. 优先评估 `transform`/`opacity` 等常见合成候选，同时拒绝“某属性必然 GPU/独立层”的无证据结论；
7. 说明 `will-change` 只是 UA hint，长期大量使用会占资源并可能提前产生渲染副作用；
8. 在 `prefers-reduced-motion: reduce` 中移除非必要位移、缩放、视差和循环，不把 reduce 误解为一律零毫秒或已满足全部 WCAG；
9. 保证 `:focus-visible` 的指示即时、持续、未被 transform/opacity/overlay 遮挡；
10. 用普通/减少动效/快速反向矩阵和真实 Performance 记录区分合同验证、可访问性观察与性能证据。

配套入口：

- [可中断状态与减少动效示例](../../../examples/encyclopedia/ch.css.motion-compositing/README.md)
- [布局抖动、焦点与减少动效故障实验](../../../labs/encyclopedia/ch.css.motion-compositing/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.css.motion-compositing/README.md)

canonical oracle 是：**普通与 prefers-reduced-motion 场景下，状态转换、焦点和合成时间线与声明的动效合同一致。** 离线 oracle 只能检查“声明的合同”；正式 G4 还需保存浏览器/系统/硬件、viewport/缩放、普通与 reduce 设置、交互输入序列、computed styles、动画事件或状态日志、Performance trace、layout/paint/composite 观察、layer 原因、键盘焦点截图与屏幕阅读器结果。

## 2. 状态先于插值

```text
语义输入（点击、focus、open、error）
  → DOM/ARIA/原生控件状态立即成立
  → CSS 选择器得到 before/after computed values
  → transition 或 animation 建立视觉时间模型
  → 每帧采样、layout / paint / composite（具体由实现决定）
  → 结束、取消、反向或被新状态替换
  → 语义状态始终可操作，不等待装饰完成
```

这个顺序定义“可中断”。用户连续开—关—开时，新输入立即改变真实状态；视觉可从当前采样值转向新目标；控件不锁死；焦点、名称、展开状态和可操作性不依赖某个结束事件。如果只有在动画结束后才把 `aria-expanded` 改成 `true`，辅助技术会在整个动画期间得到错误状态。

CSS-only 夹具可以用 `:hover`、`:focus-visible`、`:checked`、`[open]` 或静态 `data-state` 表达状态，但复杂业务仍需脚本维护语义。本章只规定 CSS 消费状态的合同，不用伪造脚本运行证据。

## 3. Transition：状态差异的受控插值

[CSS Transitions Level 2](https://www.w3.org/TR/css-transitions-2/) 描述 transition 如何在属性 computed value 改变时创建动画效果。基础合同包含：

- `transition-property`：只列确实需要插值的属性；
- `transition-duration`：持续时间大于零才有可感知过渡；
- `transition-timing-function`：速度曲线；
- `transition-delay`：是否延后开始；交互反馈通常慎用延迟；
- 多列表按 CSS 列表匹配规则重复或截断，维护时应避免难读的错位列表。

```css
/* Responsibility: 为卡片进入/离开建立有限、可反向的视觉插值。 */
/* Data source: data-state 语义状态；由拥有该状态的逻辑维护。 */
/* Mapping: closed/open 只映射 opacity 与 transform，状态本身不等待过渡。 */
/* Side effects: transform 会创建 stacking context/containing block；合成路径仍需实测。 */
.motion-card {
  opacity: 0;
  transform: translateY(0.75rem);
  transition-property: opacity, transform;
  transition-duration: 180ms;
  transition-timing-function: ease-out;
}

.motion-card[data-state="open"] {
  opacity: 1;
  transform: translateY(0);
}
```

不要默认 `transition: all 200ms`。新增任何可动画属性都可能意外参与，产生尺寸爬动、颜色滞后或焦点边框延迟。显式属性列表也是审计清单：看到 `width`、`height`、`top`、`left` 时，应追问是否有 layout 成本和视觉/布局几何不同的替代方案。

### 3.1 反向、重定向与取消

过渡不是“从头播放且保证结束”的一次性任务。目标值在运行中变化时，浏览器会根据当前状态和 reversing 规则产生新过渡；元素被移除、属性不再过渡或状态改变时，可能产生 `transitioncancel` 而非 `transitionend`。规范列出的典型中断序列会以 cancel 结束。

因此：

- 不用 `transitionend` 作为提交、删除或权限更新的唯一触发器；
- 若脚本监听结束做清理，也要处理 cancel、零时长、节点移除和重复事件；
- 快速点击必须保持幂等，第二次输入不应等待第一段 180ms；
- after state 应完整描述最终视觉，不能只靠上一动画残留；
- reduce 模式可能直接取消/消除过渡，业务仍必须正确。

Level 2 的 `@starting-style` 与离散 transition 能解决某些“首次渲染没有 before style”问题，但它们属于额外版本表面。使用前要对目标浏览器做真实兼容测试并保留无动画可用基线；本章离线夹具不宣称验证它们。

## 4. Transform：视觉坐标改变，不是重新排版

[CSS Transforms Level 1](https://www.w3.org/TR/css-transforms-1/) 规定 transform 改变元素坐标空间。对 CSS box model 元素，它不会改变周围内容的普通流位置，但 transformed bounds 会计入 overflow；非 `none` transform 会创建 stacking context，还会为 absolute/fixed 后代建立 containing block。

这解释了几个常见故障：

- 用 `translateX` 把卡片移走，邻居不会自动填补原布局槽；
- 视觉上移出的内容仍可能扩大滚动区域；
- 给祖先加 transform 后，原本相对 viewport 的 fixed 后代可能改为相对该祖先；
- 新 stacking context 会改变 `z-index` 竞争范围，弹层可能被意外压住；
- hit testing 与焦点仍对应 transformed 元素，不能只看原布局框推断。

Transform 函数顺序重要。`translate() scale()` 与 `scale() translate()` 的矩阵组合和结果一般不同。先画坐标系、写 `transform-origin`，再决定旋转/缩放/平移顺序；不要靠不断调像素得到偶然截图。

```css
/* Responsibility: 在原布局槽内给按钮按压反馈，不用尺寸变化推挤邻居。 */
/* Data source: 原生 :active 状态。 */
/* Mapping: press 映射为小幅 scale，transform-origin 保持中心。 */
/* Side effects: 非 none transform 创建 stacking context；不能据此断言独立合成层。 */
.action-button {
  transform-origin: center;
  transition: transform 90ms ease-out;
}

.action-button:active {
  transform: scale(0.98);
}
```

“transform 不参与普通流重新计算”不等于“transform 永远便宜”。复杂内容可能需要大面积栅格化、纹理上传、滤镜处理或每帧绘制；缩放文本可能模糊；巨大的 offscreen surface 会增加内存。性能只能在目标场景实测。

## 5. Keyframes：明确的时间序列

[CSS Animations Level 1](https://www.w3.org/TR/css-animations-1/) 让 `@keyframes` 定义多个时间点，animation properties 控制名称、时长、曲线、延迟、迭代、方向、fill 和 play state。适合需要超过两个阶段或自动进入反馈的场景，不应替代业务状态机。

```css
/* Responsibility: 为新状态徽标提供一次、短时、非关键的进入提示。 */
/* Data source: .status-badge.is-new 状态类。 */
/* Mapping: 0→65→100% 映射小幅 opacity/translate，不循环表达任务进度。 */
/* Side effects: fill 只影响动画采样值，不修改类、文本或 DOM 状态。 */
@keyframes badge-enter {
  0% { opacity: 0; transform: translateY(0.4rem); }
  65% { opacity: 1; transform: translateY(-0.08rem); }
  100% { opacity: 1; transform: translateY(0); }
}

.status-badge.is-new {
  animation-name: badge-enter;
  animation-duration: 240ms;
  animation-timing-function: ease-out;
  animation-iteration-count: 1;
  animation-fill-mode: both;
}
```

### 5.1 端点、迭代与填充

缺失 `0%` 或 `100%` keyframe 时，动画可使用底层属性值形成端点；这会让同一 keyframes 在不同上下文得到不同轨迹。需要稳定证据时显式写端点。

`animation-iteration-count: infinite` 适合极少数持续状态，但不能用永动旋转作为“任务正在进行”的唯一信息，也不能让自动运动无限抢注意力。状态应有文本/语义，运动应可暂停或在 reduce 下取消。`animation-direction` 改变迭代方向；偶数次 alternate 的最终采样可能与直觉不同，矩阵要写清。

`animation-fill-mode` 定义动画执行期外应用哪些动画值：`backwards` 影响 delay 期，`forwards` 影响结束后，`both` 合并。它不会写回 DOM，不会改变 attribute/class，也不应被当作持久状态。移除 animation 或改变 cascade 后，底层值仍会显现；最终样式应由真实状态规则表达。

`animation-play-state: paused` 会暂停采样，但可访问的暂停控件、状态同步与恢复逻辑可能需要 HTML/JavaScript。本章不因一条 paused 声明就声称满足长期自动运动的控制要求。

## 6. 渲染管线与“合成友好”的证据等级

一个概念化帧管线是：style → layout → paint → composite。某些变化需要前序阶段，某些已栅格化内容可能在合成阶段移动或改变透明度。但浏览器可以优化、合并、回退，具体路径受实现、页面结构、遮挡、滤镜、设备、内存和当时负载影响。

工程上常把 `transform` 与 `opacity` 视为**优先评估的合成候选**，因为它们通常可以在不改变普通流几何的情况下插值。相对地，`width`、`height`、`top`、`left`、`margin` 等经常影响布局或绘制。但这只是风险模型，不是规范承诺：

```text
CSS 源码检查      → 发现 layout-affecting 候选和无限动画
computed styles    → 确认真正参与动画的属性
Performance trace  → 观察动画期间 style/layout/paint/composite 任务
Layers/原因信息    → 观察当次实现如何分层，不把内部策略当 API
重复与压力场景     → 检查慢设备、多个实例、滚动/遮挡与内存边界
```

只要没有 trace，就只能说“源码合同避免已知布局属性并选择常见候选”，不能说“零 layout”“只走 GPU”或“60fps”。帧率也不是唯一指标；输入延迟、主线程占用、paint 范围、内存和稳定性都要看。

### 6.1 Layer promotion 边界

合成层由 UA 决定，不是 CSS 作者拥有的持久对象。`translateZ(0)`、极小 3D transform 或长期 `will-change` 不是可依赖的 layer API。浏览器版本、GPU 和场景变化都可能改变结果。

[CSS Will Change Level 1](https://www.w3.org/TR/css-will-change-1/) 把 `will-change` 定义为对未来变化的渲染提示。浏览器可用不同方式处理，元素过多时甚至可忽略 promotion 以避免耗尽 GPU 内存。提示还可能提前产生相应属性本会产生的 stacking context 等视觉副作用。

实践顺序是：先测量；若确有准备不足导致的抖动，再在变化前短暂添加具体 `will-change: transform`；变化结束后移除；重新测量资源与层叠副作用。不要写：

```css
* { will-change: transform; }
```

它让所有元素长期占据潜在优化资源，却不能保证性能。配套 oracle 会把“全局/长期 will-change”和“强制 layer promotion”视为合同故障。

## 7. 减少动效：保留意义，降低运动

[Media Queries Level 5](https://www.w3.org/TR/mediaqueries-5/) 的 `prefers-reduced-motion` 有 `reduce` 与 `no-preference`。`reduce` 表示用户希望页面减少非必要运动，不等于“用户没有偏好时才能动画到任何程度”，也不等于“把所有 duration 改为 0.01ms 就完成无障碍”。

设计时先给每段动效分类：

- 必要状态：成功、错误、展开结果必须被感知，但信息可由文本、图标、边框或即时颜色表达；
- 空间说明：小幅、短时进入可能有帮助，reduce 下可直接呈现；
- 装饰运动：视差、漂浮、弹跳、长距离缩放应在 reduce 下删除；
- 持续自动运动：默认也要严格限制，超过可访问性条件时提供暂停/停止/隐藏机制；
- 闪烁：减少位移不等于解决闪烁风险，仍需单独满足相关准则。

```css
/* Responsibility: 为请求结果提供一次状态反馈，同时尊重减少动效偏好。 */
/* Data source: .result.is-visible 与用户的 prefers-reduced-motion。 */
/* Mapping: 普通模式用短位移/透明度；reduce 模式立即显示并保留边框与文字。 */
/* Side effects: 媒体切换可取消运行中的动画；业务状态不得依赖结束事件。 */
.result {
  opacity: 0;
  transform: translateY(0.75rem);
  transition: opacity 180ms ease-out, transform 180ms ease-out;
}

.result.is-visible {
  opacity: 1;
  transform: translateY(0);
}

@media (prefers-reduced-motion: reduce) {
  .result,
  .status-badge.is-new {
    animation: none;
    transition: none;
    transform: none;
  }

  .result.is-visible {
    opacity: 1;
  }
}
```

为什么不一刀切 `* { animation-duration: .01ms !important }`？它可能破坏依赖 iteration/event 的第三方代码、留下仍会闪一下的位移、覆盖必要的焦点样式，并掩盖哪些动效真正需要替代。组件级显式降级更可审计。若基线采用“默认无动效，只在 `(prefers-reduced-motion: no-preference)` 中增强”，也很稳健；选择需与项目层叠合同一致。

[WCAG 2.2 2.3.3](https://www.w3.org/TR/WCAG22/#animation-from-interactions) 是 Level AAA，要求可禁用交互触发的 motion animation（必要情形除外）；[2.2.2](https://www.w3.org/TR/WCAG22/#pause-stop-hide) 是 Level A，涉及自动开始、超过五秒并与其他内容并列的移动/闪烁/滚动信息，以及自动更新信息。`prefers-reduced-motion` 是重要输入，但不能自动证明这些成功准则全部满足。

## 8. 焦点必须比动效更可靠

[WCAG 2.2 2.4.7](https://www.w3.org/TR/WCAG22/#focus-visible) 要求键盘可操作界面存在焦点指示可见的操作模式。动效组件的额外风险包括：初始 `opacity:0` 期间控件已经可聚焦；transform 把焦点控件移出视口；overlay 或新 stacking context 遮住 outline；对 `outline-color` 做延迟 transition；把 `outline:none` 当视觉清理；关闭面板后焦点仍留在隐藏内容。

```css
/* Responsibility: 给键盘焦点提供即时、非动画、可辨认的指示。 */
/* Data source: UA 的 :focus-visible 匹配与当前主题 focus token。 */
/* Mapping: 焦点映射为 outline，不放入 transition-property。 */
/* Side effects: outline 不占布局空间；仍须实测是否被 overflow/overlay 遮挡。 */
.motion-card :focus-visible {
  outline: 3px solid var(--focus-ring, currentColor);
  outline-offset: 3px;
}
```

静态源码只能证明规则存在，不能证明实际键盘路径、颜色对比、遮挡和焦点恢复。验收至少用 Tab/Shift+Tab/Enter/Escape 快速操作，普通与 reduce 各走一遍；打开/关闭时记录 active element；检查焦点指示在动画每一阶段都可见；再用屏幕阅读器核对名称、角色、状态和焦点上下文。

## 9. 可中断动效合同

用一张状态表代替“看起来顺滑”：

| 输入 | 语义状态何时更新 | 普通视觉 | reduce 视觉 | 可中断要求 |
|---|---|---|---|---|
| open | 输入被接受时立即 | 180ms opacity/translate 到 open | 立即 open，无位移 | close 可从当前采样值反向 |
| close | 输入被接受时立即 | 同属性返回 closed | 立即 closed | 不等待 transitionend 才可再开 |
| focus | UA 匹配时立即 | outline 立即出现，不参与 transition | 相同 | 运行中始终不被遮挡 |
| status-new | 状态类出现时立即 | keyframes 1 次、240ms | 无动画，文字/样式直接出现 | 移除类不依赖 animationend |
| rapid toggle | 每次输入立即 | 新目标覆盖旧目标，可产生 cancel | 每次立即采样最终态 | 无锁死、无重复业务副作用 |

状态表还应写断言：没有 `transition: all`；没有 width/height/top/left keyframes；没有 infinite 装饰循环；reduce 规则显式覆盖 transition、animation 与 transform；focus-visible 存在且不透明；matrix 将 `layer_promotion_guaranteed` 设为 false；真实 trace 字段在未取证前保持 false。

## 10. 故障诊断：从源码候选到真实时间线

### 10.1 布局动画抖动

症状：抽屉移动时 layout 时间激增。第一步不是直接换 transform，而是 Performance 录制同一输入，定位每帧 Layout/Paint、受影响节点和触发属性。若 `left` 或 `width` 每帧变化是首个可信证据，再设计固定布局槽 + transform 的视觉方案；验证 hit testing、overflow、文本清晰度和最终布局语义，重录同一 trace。

### 10.2 reduce 被忽略

症状：系统已设置减少动效，组件仍弹跳。先在浏览器检查媒体查询是否匹配、规则是否加载、层叠是否被更后声明覆盖；再查 animation shorthand 是否重新写回 name/duration；确保状态信息不用运动独占。修复后切换偏好并重复相同输入。

### 10.3 焦点消失

症状：Tab 到打开中的面板但看不到焦点。记录 `document.activeElement`、computed opacity/transform/outline、stacking/overflow 和 overlay。首因可能是可聚焦时序、父级 opacity、裁剪或 outline 被覆盖；不能只加更大 `z-index`。修复后验证普通/reduce、正向/反向和快速关闭。

### 10.4 transition 结束逻辑丢失

症状：快速反向后控件永久 disabled。保存事件序列，若只有 `transitionend` 解锁而本次收到 `transitioncancel`，首因是业务依赖装饰事件。让业务状态立即且独立更新，并对可选清理同时处理 cancel/零时长；reduce 下无 transition 也必须工作。

### 10.5 layer 假设失效

症状：代码写了 `will-change` 但仍掉帧。检查实际 trace 和 layer 原因，不把声明存在当 promotion 证据；可能是大面积 paint、内存压力、滤镜、主线程长任务或多实例。若首因是 JavaScript long task，明确移交到脚本性能范围，不在 CSS 中继续堆 hack。

所有修复要重跑**同一输入、同一偏好、同一设备/浏览器和同一采集设置**。换设备或缩短案例可以作为补充，不能替代原故障复测。

## 11. 实验与考核协议

独立构建流程：

1. 从空目录写一个原生可操作组件，定义 closed/open/focus/status 状态，不复制成品；
2. 在无动效条件下先保证语义、焦点和最终样式正确；
3. 对普通模式只添加明确的 transform/opacity transition 和一次 keyframes；
4. 写 reduce 分支，移除非必要位移、缩放、循环，同时保留即时状态反馈；
5. 写快速 open/close/open 预期，保证业务不依赖 end event；
6. 注入 width 动画、缺失 reduce、outline none 或无限循环故障，保存首次失败；
7. 修复首因并重跑同一离线 oracle；
8. 在真实浏览器录普通/reduce 的 Performance trace、键盘路径和焦点截图；
9. 记录实际 layout/paint/composite 与 layer 观察，不写“GPU 一定”；
10. 用屏幕阅读器核对状态，并列出未覆盖设备、浏览器与用户测试。

120 秒讲解可用：transition 插值 computed state，keyframes 表达多阶段；transform 改视觉坐标且产生 stacking/containing-block 副作用；transform/opacity 只是常见合成候选，真实路径看 trace；reduce 下去掉非必要运动，焦点和语义即时可见；JavaScript 长任务不是本章责任。

## 12. 证据分层与未验证声明

配套离线绿灯验证：HTML/CSS 四类意图注释；显式 transition 属性；transform/opacity 状态；一次 keyframes 和 fill/iteration；组件级 reduce 覆盖；focus-visible outline；无 layout-affecting 动画、无 `transition: all`、无无限循环、无长期 `will-change`；状态矩阵声明 cancel/rapid toggle 边界；公开故障夹具稳定红灯。

离线绿灯没有验证：浏览器真的把某元素放到合成层；动画期间是否出现 Layout/Paint；帧率、输入延迟、CPU/GPU 或内存；不同硬件/浏览器的栅格化；真实 `transitioncancel`/事件时序；键盘焦点是否被遮挡；屏幕阅读器状态；前庭敏感用户体验；闪烁阈值；自动运动的暂停机制。交付时必须原样报告这些未验证项，除非已有具体证据文件。

## 13. 规范索引与版本说明

- [CSS Transitions Module Level 2](https://www.w3.org/TR/css-transitions-2/)：过渡生成、反向与事件/cancel 模型。核验于 2026-07-17。
- [CSS Transforms Module Level 1](https://www.w3.org/TR/css-transforms-1/)：transform 顺序、普通流、overflow、stacking context 与 containing block。核验于 2026-07-17。
- [CSS Animations Level 1](https://www.w3.org/TR/css-animations-1/)：keyframes、iteration、direction、fill、play state 与事件。核验于 2026-07-17。
- [CSS Will Change Module Level 1](https://www.w3.org/TR/css-will-change-1/)：渲染提示、资源回收与 UA 自主决策边界。核验于 2026-07-17。
- [Media Queries Level 5](https://www.w3.org/TR/mediaqueries-5/)：`prefers-reduced-motion`。核验于 2026-07-17。
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)：2.2.2、2.3.3、2.4.7 及相关定义。核验于 2026-07-17。

浏览器合成策略不是稳定 Web API；规范编辑草案、实现和 DevTools 标签会变化。稳定核心是状态独立、动效可中断、transform 副作用、reduce 与焦点边界、真实测量优先。`@starting-style`、离散过渡、具体 layer promotion 和工具 UI 属版本表面，发布前需对目标矩阵重验。

## 14. 最终检查表

- [ ] 无动效时组件语义、焦点、open/closed 最终状态已正确。
- [ ] transition 明确列属性、时长、曲线和延迟，没有 `all`。
- [ ] 快速反向/取消不会锁控件，业务不只依赖 end event。
- [ ] transform 顺序与 origin 有意图，并检查 overflow、stacking、containing block。
- [ ] keyframes 端点、iteration、direction、fill 和最终状态职责清楚。
- [ ] 无限或自动长期运动有明确必要性与控制；装饰循环已删除。
- [ ] reduce 分支显式移除非必要位移/缩放/循环并保留即时反馈。
- [ ] focus-visible 不参与延迟动画，普通/reduce 全程可见。
- [ ] “compositor friendly”只作为候选；性能结论有真实 trace 才成立。
- [ ] `will-change` 若存在，有测量理由、短生命周期和移除点。
- [ ] 首次失败、首因、最小修复、同一验证重跑与残余风险可追溯。
- [ ] JavaScript 长任务、WAAPI 编排与完整性能工程未越界混入。
