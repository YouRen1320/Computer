---
schema_version: 2
edition: 2026.2-draft
id: ch.css.box-position
title: 盒模型、display、定位与层叠上下文
responsibility: 解释元素尺寸、正常流、display、定位包含块和层叠上下文，不在本章使用 Flexbox 或 Grid 解决整体布局。
volume: '07'
order: 8
level: L1
status: drafting
path: book/volume-07-web-platform/chapters/ch.css.box-position.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.css.cascade
version_surfaces:
- css
- browser
- browser-devtools
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“盒模型、display、定位与层叠上下文”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - css-box-formatting
  - css-position-stacking
  covers_topics:
  - css.content-padding-border-margin
  - css.box-sizing
  - css.display-formatting
  - css.margin-collapse
  - css.containing-block
  - css.position-schemes
  - css.z-index
  - css.stacking-context
  - css.overflow-clipping
  uses_capabilities:
  - web.browser-rendering
  - web.css-foundations
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“盒模型、display、定位与层叠上下文”构建可运行程序与测试：构造正常流、绝对定位和多个层叠上下文的可视化实验；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - css-box-formatting
  - css-position-stacking
  covers_topics:
  - css.content-padding-border-margin
  - css.box-sizing
  - css.display-formatting
  - css.margin-collapse
  - css.containing-block
  - css.position-schemes
  - css.z-index
  - css.stacking-context
  - css.overflow-clipping
  uses_capabilities:
  - web.browser-rendering
  - web.css-foundations
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: box-model-calculation-layout-inspection-visual-diff
- id: diagnose
  kind: fault-diagnosis
  text: 面对“box-sizing、包含块或层叠上下文误判导致的溢出和遮挡”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - css-box-formatting
  - css-position-stacking
  covers_topics:
  - css.content-padding-border-margin
  - css.box-sizing
  - css.display-formatting
  - css.margin-collapse
  - css.containing-block
  - css.position-schemes
  - css.z-index
  - css.stacking-context
  - css.overflow-clipping
  uses_capabilities:
  - web.browser-rendering
  - web.css-foundations
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 盒模型、display、定位与层叠上下文

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《CSS 语法、选择器、层叠、优先级与继承》](ch.css.cascade.md)：盒模型和定位的最终值来自层叠后的 computed style，必须先能定位覆盖来源。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套工件通过固定几何矩阵、HTML/CSS 夹具和离线 oracle 验证手算公式、包含块/层叠树预言与故障记录；离线绿灯不代表真实 DevTools 盒模型、截图或像素差分已经完成。易变事实已于 **2026-07-17** 对照 W3C CSS Box Model Level 4、CSS Display Level 3、CSS Positioned Layout Level 3、CSS Overflow Level 3、CSS Basic UI Level 4、CSS 2.2 与 CSSOM View 一手规范核验。

当一个元素“多出 24px”、绝对定位跑到页面角落、`z-index: 999999` 仍被遮住时，继续调数字通常只会偶然修好当前截图。真正可复现的答案来自三张图：这个元素生成什么盒、尺寸从哪条边算；它参加哪个格式化上下文、以谁为包含块；它属于哪个层叠上下文、在哪个上下文内部绘制。

本章只建立正常流、盒模型、display、定位、溢出与层叠上下文的推理模型。它明确不使用 Flexbox 或 Grid 解决整体布局；后续章节会分别教授它们的轴、轨道和对齐算法。这里若提到 flex/grid，只用于标记“该情形不发生 margin collapse”或 `z-index` 的边界，不展开其布局方案。

## 1. 完成定义、边界与证据入口

完成本章，应能：

1. 标出 content、padding、border、margin 四层边并手算 content-box/border-box 的外部尺寸；
2. 解释 `display` 的外部参与角色与内部格式化模型，区分 `block`、`inline`、`flow-root`、`none`、`contents` 的盒生成影响；
3. 判断普通块的相邻垂直 margin 是否折叠，并写出阻断折叠的最小、语义明确条件；
4. 为 static/relative/sticky/absolute/fixed 元素确定包含块与是否保留正常流空间；
5. 区分“z-index 数字”与“层叠上下文边界”，画出上下文树并预测遮挡顺序；
6. 区分 `overflow: visible/hidden/clip/auto/scroll` 的裁剪、滚动容器和格式化影响；
7. 用 Computed、盒模型面板、`getBoundingClientRect()`、滚动尺寸和截图交叉验证手算；
8. 注入 box-sizing、包含块或 stacking context 误判，指出首个可信证据，修复并重跑原验证。

配套入口：

- [盒尺寸、包含块与层叠树示例](../../../examples/encyclopedia/ch.css.box-position/README.md)
- [溢出与遮挡故障实验](../../../labs/encyclopedia/ch.css.box-position/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.css.box-position/README.md)

canonical oracle 是：**给定尺寸与定位规则时，手算外部尺寸、包含块和遮挡顺序与 DevTools 盒模型及截图一致。** 教材 oracle 没有启动浏览器，只验证固定输入的数学和结构预言。正式 G4 证据必须补齐浏览器/版本、视口与缩放、字体加载状态、滚动位置、DPR、目标节点、Computed 与盒模型读数、几何 API 输出、基准/修复截图和差异说明。

## 2. 先画渲染推理管线

```text
DOM + 层叠后的 computed styles
  → display 决定是否/如何生成盒
  → formatting context 安排正常流盒
  → 尺寸算法求 content/padding/border/margin
  → containing block 解析百分比与 inset
  → position 调整或移出正常流
  → overflow 建立裁剪/滚动边界
  → stacking context tree 与 painting order
  → 变换、栅格化和设备像素得到截图
```

诊断时按阶段停靠：

- Computed 值不是预期：先回到上一章的 cascade；
- Computed 正确但外部尺寸错误：查 box-sizing、auto/百分比、min/max 与四边；
- 尺寸正确但位置参照错：查 position scheme 与 containing block；
- 几何正确但看不见：查 overflow、clip、opacity、visibility 和绘制；
- 只在两个局部组之间遮挡错误：画 stacking context tree，不先加 z-index；
- 截图不同但几何 API 相同：查字体、抗锯齿、颜色、变换或环境，不把它归咎于盒模型。

## 3. 四层盒：每个数字属于哪条边

每个 CSS box 有 content area，以及可选的 padding、border、margin area。由内向外：

```text
margin edge
┌──────────────────────────────┐
│ margin                       │
│  border edge                 │
│  ┌────────────────────────┐  │
│  │ border                 │  │
│  │  padding edge          │  │
│  │  ┌──────────────────┐  │  │
│  │  │ padding          │  │  │
│  │  │  content edge    │  │  │
│  │  │  ┌────────────┐  │  │  │
│  │  │  │ content    │  │  │  │
│  │  │  └────────────┘  │  │  │
│  │  └──────────────────┘  │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

- content 放文字、后代盒或替换元素内容；
- padding 是内容与边框之间的透明间距，元素背景通常会绘制到它；
- border 有宽度、样式、颜色并参与 border box；
- margin 位于边框外，透明，可为负，也可能为 `auto` 或发生折叠。

不要把 margin 当元素可点击背景的一部分，也不要用 margin 模拟组件内部留白。点击区域与背景通常覆盖 border box；真实命中仍需浏览器事件/盒证据。

### 3.1 content-box 手算

```css
/* Responsibility: 构造固定 content-box 尺寸用于手算。 */
/* Data source: 教学常量，不来自响应式容器。 */
/* Mapping: width 是 content width，padding/border/margin 分别加到外部尺寸。 */
/* Side effects: 只影响本地盒几何，不修改数据。 */
.meter {
  box-sizing: content-box;
  width: 240px;
  padding-inline: 16px;
  border-inline: 2px solid;
  margin-inline: 8px;
}
```

在水平书写模式且所有值已解析为固定 px 时：

```text
content width = 240
padding box width = 240 + 16 + 16 = 272
border box width = 272 + 2 + 2 = 276
margin box / outer width = 276 + 8 + 8 = 292
```

这是受控案例公式，不是所有盒的通用布局算法。`width:auto`、百分比、min/max、替换元素、inline non-replaced box、固有尺寸、滚动条、书写模式和可用空间都会改变求值。先从 Computed 取各长写使用/解析值，再决定公式。

### 3.2 border-box 手算

`box-sizing: border-box` 让指定 `width`/`height` 包含 content、padding 和 border，但仍不含 margin：

```text
declared border-box width = 240
content width = 240 - 16 - 16 - 2 - 2 = 204
outer width = 240 + 8 + 8 = 256
```

如果 padding+border 大于指定尺寸，内容尺寸不能被压成负数，最终 border box 可能超过声明尺寸。`border-box` 不是“永不溢出”；内容最小尺寸、长单词、固定子元素、百分比、滚动条和负 margin 仍能制造溢出。

工程中常用全局：

```css
*, *::before, *::after { box-sizing: border-box; }
```

这是明确的项目约定，不是浏览器对所有元素的规范初始值；部分表单控件的 UA 行为和项目 reset 还需用 Computed 核对。不要仅看到规则文本就假设伪元素或 shadow 内部都受它控制。

### 3.3 高度更危险

块的 `height:auto` 常由内容决定；百分比高度需要相应 containing block 尺寸满足定义条件，否则可能按 `auto` 处理。固定高度加 padding/border、内容换行、字体替换和最小内容约束很容易溢出。优先让内容决定块尺寸；确需固定视窗/面板时，明确 overflow 与可达性策略。

## 4. `display`：外部角色、内部模型与盒生成

现代 `display` 模型可以理解为外部 display type 与内部 display type：外部角色说明 principal box 如何参加父格式化上下文，内部模型说明其子内容如何布局。常用单关键字是历史预组合映射；例如普通 `block` 通常表现为 block flow，`inline` 为 inline flow。

### 4.1 block 与 inline

block-level box 在正常流的块方向依次放置，通常参与 block formatting context；inline-level box 与文字一起组成 line box。非替换 inline 元素的 `width`/`height` 与垂直 margin 表现不能按普通 block 公式照搬；它可跨行产生多个 fragment，`getClientRects()` 可能返回多个矩形。

`inline-block` 让元素外部以 inline-level 参与行布局，内部建立独立格式化行为；行内基线和空白仍会影响视觉间隙。不要把它误称为“没有换行的 block”后忽略 line box。

### 4.2 flow-root 与 block formatting context

`display: flow-root` 生成 block-level box，并为内容建立新的 block formatting context（BFC）。常见效果包括隔离内部/外部某些 margin collapse、包含浮动影响等。它比用 `overflow: hidden` 偶然创建 BFC 更能表达“建立独立流根”的意图，也不会顺带裁剪内容。

BFC 不是新 stacking context。建立格式化上下文解决布局参与边界，不自动改变跨上下文 z-order。要分别画 formatting context 与 stacking context 两张图。

### 4.3 none、contents、visibility、opacity 不等价

- `display: none`：元素及后代不生成用于布局的盒，通常也不会作为可访问对象暴露；它不占正常流空间；
- `display: contents`：元素自身通常不生成 principal box，子元素像被提升参与外部格式化；元素语义、特殊元素处理和辅助技术实现有兼容性风险，不能只为省 wrapper 盲用；
- `visibility: hidden`：盒仍占布局空间但不可见/不可交互的细节需按属性规范与后代值检查；
- `opacity: 0`：盒仍布局、通常仍可命中/聚焦，并会建立 stacking context；“看不见”不等于“移除”。

状态切换需同时明确视觉、布局、键盘焦点、可访问树和事件命中结果。本章只负责盒与绘制边界，交互可访问性必须回到相应章节做真实任务验证。

## 5. 正常流与 margin collapse

正常流是没有浮动、绝对定位等移出行为时，盒按其格式化上下文排列的基线。先让文档顺序和正常流表达阅读顺序，再用定位做局部覆盖；把整页都绝对定位会让内容增长、缩放和翻译变得脆弱。

### 5.1 哪些 margin 会折叠

在普通 block formatting context 中，某些相邻 block-level box 的**块方向 margin**会折叠为一个 margin：相邻兄弟的上下 margin；父与第一个/最后一个 in-flow block child 的相应 margin；没有 border、padding、内容、height/min-height 等分隔的空 block 自身上下 margin。水平 margin 不折叠。

两个正 margin 折叠时不是相加，通常取较大值；有负 margin 时按规范组合最大正值和最小负值；全为负时结果为最负者。课程固定正值示例：上项 `margin-bottom: 24px`，下项 `margin-top: 16px`，间距预期 24px，不是 40px。

### 5.2 什么会阻断

border、padding、inline content、clearance、明确的 height/min-height 条件、建立新的格式化上下文等会影响 adjoining 条件。绝对定位元素和浮动元素的 margin 不与正常流块折叠；flex/grid 项目的 margin 也不折叠，但算法留到后章。

不要为“让 16+24=40”随手加透明 border 或 `overflow:hidden`，它们会带来绘制/裁剪副作用。先决定想要的是父内部 padding、兄弟统一 gap 契约，还是独立 `flow-root`，再选最能表达职责的修复。

DevTools 显示每个元素声明的 margin，不一定直接显示折叠后的最终间距。需要用相邻 border-box 的 `getBoundingClientRect()` 之差或 overlay 验证，并记录是否存在空块、父边框/内边距与 BFC。

## 6. containing block：先找坐标参照

包含块不是“DOM 父元素”的同义词。它用于解析许多尺寸、百分比和 positioned inset；不同 positioning scheme 的查找规则不同。

### 6.1 static、relative、sticky

static、relative、sticky box 的 containing block 由其 formatting context 定义，常见 block 子元素以最近 block container 的 content box 为基础，但 inline、表格、书写模式等有更具体规则。不要把这个常见近似写成所有元素定律。

### 6.2 absolute

absolute box 的 containing block 由最近一个建立 absolute positioning containing block 的祖先盒建立。最常见触发是祖先 `position` 非 `static`：

```css
.card { position: relative; }
.card__badge { position: absolute; inset-block-start: 8px; inset-inline-end: 8px; }
```

这里 `relative` 可不移动 `.card`，但建立 badge 的定位参照。对于普通非 inline 祖先，绝对定位包含块通常由其 padding edge 形成；inline 祖先和分片有专门规则。transform、perspective、filter、contain、will-change、content-visibility 等其他规范特性也可能建立 containing block，必须看目标属性定义和浏览器 Computed，而不是只搜索 `position: relative`。

若找不到合格祖先，absolute 会相对 initial containing block；它“跑到页面角落”通常是 containing block 证据，不是 `top` 数字太小。

### 6.3 fixed

fixed positioning 的 containing block 查找与 absolute 类似，但寻找建立 fixed positioning containing block 的祖先；若不存在，在连续媒体通常相对 layout viewport。带 transform 等特性的祖先可能让 fixed 不再固定于视口。移动端 visual viewport、软键盘与缩放又会影响观察，测试必须记录设备与视口条件。

`offsetParent` 可提供有用线索，却不是 containing block 的规范同义 API：它有自己的返回算法，可能为 `null`，table/zoom 等也会影响。首选把 CSS 规则推导与实际几何读数交叉验证。

## 7. 五种 position scheme

### 7.1 static

`position: static` 是普通基线，inset 属性不对它产生定位效果。若 `top: 10px` 没反应，先看 position，而不是增大 top。

### 7.2 relative

relative box 先在正常流获得位置，再按 inset 做视觉偏移；其原始空间仍被保留，其他正常流元素不会自动填入。它也会为 positioned 后代建立 containing block。用 relative 把大段内容挪走会留下“幽灵空位”，应判断是否真正需要布局算法。

当同一轴的两侧 inset 都非 auto 时有方向/书写模式约束，不要认为 `left` 与 `right` 永远共同拉伸 relative box。使用逻辑属性 `inset-inline-*` 可更好适配书写方向，但仍需明确设计意图。

### 7.3 absolute

absolute box 脱离正常流，通常不为后续兄弟保留空间；它相对 containing block 由 inset、margin、尺寸和静态位置共同求解。`inset-inline: 0; width: auto` 与固定 width 的约束不同，过约束时还受方向影响。

absolute 适合徽标、局部覆盖层、与明确容器绑定的装饰，不适合承载会推开后文的主内容。父高度若只含 absolute children，可能像“塌陷”，因为这些孩子不参与正常流高度贡献。

### 7.4 fixed

fixed 是绝对定位的一类，通常相对 viewport，不保留正常流空间，并建立 stacking context。固定工具条要为正文预留空间，考虑缩放、软键盘、安全区与小视口；不能只在桌面截图验证。

### 7.5 sticky

sticky 在正常流中保留空间，依据最近 scrollport 与 inset 在滚动过程中受约束；至少一个相关轴 inset 非 `auto` 才有可见粘滞阈值。祖先的 overflow 可能建立意外 scroll container，父高度不足或裁剪也会让 sticky “失效”。

诊断 sticky：记录滚动的是哪个元素、其 scrollport、sticky 的 containing block、相关 inset、祖先 overflow 和实际滚动位置。只看 `position: sticky` 一行不足以证明行为。

## 8. z-index 与 stacking context：树，而不是全球数字轴

`z-index` 为 positioned boxes 提供 stack level/是否建立局部上下文等作用；其他布局模型还有各自适用规则。关键事实是：stacking context 是原子绘制单元。一个子上下文内部的 `z-index: 9999` 不能逃出父上下文，去压过父上下文外更高层的兄弟。

```text
root stacking context
├─ panel A (z-index: 1, creates context)
│  └─ tooltip (z-index: 9999)  ← 仍封装在 A
└─ panel B (z-index: 2, creates context) ← 整体可盖住 A 的 tooltip
```

### 8.1 常见建立条件

常见触发包括：根元素；positioned 且 `z-index` 非 auto；fixed/sticky；`opacity < 1`；非 none transform/filter/perspective；特定 blend/isolation；某些 contain；预示会建立上下文的 `will-change`。完整列表分布在多个 CSS 模块并会演进，不能把博客清单当永恒规范。对目标元素应在 Computed 中逐项核对触发属性。

`will-change` 不是修 z-index 的开关；它是性能提示，可能提前建立包含块或 stacking context，改变行为并消耗资源。没有测量证据不要长期滥用。

### 8.2 绘制顺序不是只排序 z-index

一个上下文内部还有背景/边框、负 stack level 子上下文、in-flow block/inline 内容、positioned auto/0、正 stack level 子上下文等规定顺序；相同层级最终又与树序有关。初学图可以简化为负→普通流→auto/0→正，但正式边界要回到 CSS 2.2 Appendix E 与相关模块。

`z-index: auto` 与 `z-index: 0` 不总等价：后者在适用条件下明确 stack level 0 并可能建立上下文，前者常让后代参与当前上下文；fixed/sticky 即使 auto 也有当前 Positioned Layout 规范定义。把 auto 机械替换为 0 可能改变封装。

### 8.3 可靠诊断

1. 找被遮挡元素与遮挡元素；
2. 分别沿祖先向上列出每个 stacking context trigger；
3. 找两条路径的最近共同上下文；
4. 比较共同上下文中的**直接子上下文/绘制项**，不是比较深层叶子数字；
5. 暂时禁用可疑 trigger，先预测树如何变化，再观察；
6. 修复上下文所有权（移动 overlay 容器、移除无意 trigger、建立明确层级），而非继续加大数字。

## 9. overflow：可见、裁剪与滚动是三件事

`overflow-x`/`overflow-y` 取 `visible | hidden | clip | scroll | auto`。两轴值会发生 computed-value 相互影响：若一轴不是 `visible/clip`，另一轴的 `visible` 可能计算为 `auto`，`clip` 可能计算为 `hidden`。所以只读一条源码并不足够，要看两轴 Computed。

- `visible`：通常不裁剪，也不建立 scroll container；溢出内容可绘制到盒外，但仍可能被更外层裁剪；
- `hidden`：裁剪到 padding box，用户没有直接滚动 UI，但规范上仍是 scroll container，可被脚本/焦点等程序性滚动；
- `clip`：裁剪到 overflow clip edge，禁止各种滚动，不是 scroll container，且自身不建立新的 formatting context；需要独立格式化时可配 `display: flow-root`；
- `scroll`：裁剪并可滚动，UA 通常持续提供滚动机制；
- `auto`：存在可滚动溢出时提供滚动机制，否则视觉上接近 visible/hidden 的具体表现按规范。

overflow 会影响 sticky 所参照的最近 scrollport，也会裁掉 absolute/box-shadow/focus indicator。为清浮动使用 `overflow:hidden` 可能意外裁剪焦点环和弹层；为去滚动条使用 `clip` 又会禁止程序性滚动。选择值前必须写清裁剪、用户滚动、脚本滚动、BFC 与可访问焦点五个维度。

检查 `scrollWidth/clientWidth`、`scrollHeight/clientHeight` 可发现滚动溢出，但这些 API 有整数舍入、伪元素、滚动条与根元素特例。几何数据要与截图和目标节点一起保存。

## 10. 几何与 DevTools 证据

建议固定一张记录表：

| evidence | 回答什么 | 不能单独证明什么 |
| --- | --- | --- |
| Computed | 层叠后属性的 resolved 表示 | 最终像素位置的全部约束 |
| Box Model panel | 当前节点 content/padding/border/margin 读数 | margin collapse 的完整关系 |
| `getBoundingClientRect()` | 相对 viewport 的 border-box 包围矩形，含滚动/变换影响 | 未变换原始盒、margin box |
| `getClientRects()` | 多 fragment 的矩形集合 | 绘制像素完全一致 |
| `clientWidth/scrollWidth` | padding box/滚动内容的实现读数线索 | CSS containing block 身份 |
| Stacking/3D view（若浏览器提供） | 上下文与合成线索 | 跨版本稳定 API |
| screenshot + diff | 最终可见结果 | 根因本身 |

`getBoundingClientRect()` 的坐标相对 viewport，页面滚动后会改变；它通常给 border box 的包围矩形，transform 后可能是轴对齐包围框。要与手算比较，应固定滚动位置、缩放、DPR、字体，并说明是否有 transform。

一个最小浏览器记录脚本可在控制台执行，但输出必须保存到证据目录：

```js
// Responsibility: 采集单个教学目标的计算样式与视口几何证据。
// Data source: 当前文档中由操作者明确选定的 .target 元素。
// Mapping: computed style 对应声明结果，rect 对应变换后的视口 border-box 包围矩形。
// Side effects: 只读取 DOM/CSSOM 并向控制台输出，不修改页面或业务数据。
const target = document.querySelector('.target');
const style = getComputedStyle(target);
console.table({
  boxSizing: style.boxSizing,
  width: style.width,
  paddingInline: `${style.paddingLeft} / ${style.paddingRight}`,
  borderInline: `${style.borderLeftWidth} / ${style.borderRightWidth}`,
  position: style.position,
  zIndex: style.zIndex,
  overflow: `${style.overflowX} / ${style.overflowY}`,
  rect: JSON.stringify(target.getBoundingClientRect().toJSON())
});
```

若浏览器没有 `DOMRect.toJSON()` 或序列化不同，记录版本并改为逐字段读取；这属于运行环境适配，不改变几何概念。

## 11. 三类注入故障

### 11.1 box-sizing 导致溢出

输入：容器内容宽 300px，子盒 `width: 300px; padding: 16px; border: 2px`，却按 border-box 预期。若实际是 content-box，border box 为 336px，已超出 300px（尚未计 margin）。首个证据是 Computed `box-sizing` 与 Box Model 四边，不是截图右侧被截一小段。

修复可选：明确 `box-sizing: border-box`；或保持 content-box 并把 content width 改为 264px；或让 width auto 由可用空间求解。选择应依据组件尺寸契约，不是哪个数字恰好消除当前截图。

### 11.2 containing block 误判

输入：badge absolute，预期相对 card，却相对页面。首个证据是沿祖先检查 establishing trigger，并比较 badge/card 的 rect；`offsetParent` 只作辅助。修复通常是给真正拥有 overlay 的容器 `position: relative`，而不是持续改 `top/right`。

也要检查 transform/contain 是否让 fixed/absolute 改变参照。移除 trigger 可能影响性能和其他后代，需列影响与回滚。

### 11.3 stacking context 误判

输入：panel A `z-index:1`，内部 tooltip `9999`；panel B `z-index:2`。tooltip 仍在 B 下。首个证据是上下文树中 A 与 B 的比较，叶子 9999 从未与 B 直接竞争。

修复可以把全局 overlay 挂到共同 overlay root，或移除 A 的无意上下文 trigger，或重新定义顶层层级 token。移动 DOM 可能影响语义、焦点、事件和 containing block，不能只看遮挡截图。

故障日志至少记录：注入差异、错误预言、首个可信证据、手算/上下文树、根因、最小修复、相同命令/任务重跑、残余风险与回滚点。

## 12. 独立构建任务

从空目录构建“设备检查面板”可视实验，不复制示例：

1. 一个正常流说明区，至少两个相邻 block 用于 margin collapse 对照；
2. content-box 与 border-box 各一盒，给定固定 padding/border/margin，手算 content/border/outer 尺寸；
3. 一个 positioned card 与 absolute badge，明确并标注 containing block；
4. 一个 sticky 标题和可滚动容器，记录 scrollport 与 inset；
5. 两个兄弟 stacking contexts，其中低层父上下文包含高 z-index 子 tooltip；
6. `hidden` 与 `clip` 两个 overflow 对照，分别检查程序性滚动边界；
7. 保存几何矩阵、上下文树、浏览器环境、DevTools/控制台输出和基准截图；
8. 分别注入 box-sizing、containing block、stacking context 三类故障中的至少两类，修复后重跑原检查。

尺寸验收允许说明亚像素/字体/滚动条容差，但固定 px 夹具的公式本身必须精确。视觉差分必须解释环境和容差，不能用“截图看起来相同”替代。

## 13. 120 秒讲回模板

> 元素先由 display 决定生成什么盒以及如何参加正常流。普通盒由 content、padding、border、margin 四层构成；content-box 的 width 只含内容，border-box 的 width 含 padding 与 border，margin 都在外面。相邻正常流块的垂直 margin 在满足 adjoining 条件时可能折叠。position 决定元素是否保留流空间以及 inset 相对哪个 containing block；absolute/fixed 通常脱离正常流，relative/sticky 保留空间。z-index 只在所属 stacking context 内比较，子元素再大也不能逃过父上下文。overflow 还会决定裁剪、滚动容器与 sticky scrollport。证据是 Computed、盒模型、几何 API、上下文树和截图交叉验证。本章不使用 Flexbox/Grid 解决整体布局；多轴排列应进入后续布局章节。

反例：需要让十组卡片在不同视口自动形成二维轨道，这不应靠 absolute 坐标或 inline-block 间隙拼接，应进入 Grid/响应式布局章节。

## 14. 常见失败清单

- 把声明 width 当成 outer width，不看 box-sizing；
- 认为 border-box 自动消除所有内容溢出；
- 对 non-replaced inline 套普通 block 宽高公式；
- 把两个垂直 margin 相加，不检查 collapse；
- 为阻止折叠随手用 overflow hidden，意外裁剪焦点环；
- 把 DOM parent 当 containing block；
- 用 `offsetParent` 代替 CSS 规则推导；
- absolute 子元素撑不起父高度，却误判为 margin 问题；
- sticky 没设 inset，或忽略祖先 scroll container；
- 把 z-index 当全页面数字，忽略父 stacking context；
- 认为 BFC 与 stacking context 是同一结构；
- 把 `z-index:auto` 与 0 无条件等价；
- 把 overflow hidden 与 clip 都说成“隐藏并不能滚”；
- 用 opacity 0 代替 display none，却遗漏焦点/命中；
- 只保存截图，不保存 Computed、rect、滚动位置和浏览器版本；
- 用离线 JSON oracle 声称 DevTools 与视觉差分已通过。

## 15. 验收清单与证据边界

### explain

- 120 秒内说清盒四边、display/正常流、包含块、position、overflow 与 stacking context；
- 能画出一个上下文树并解释高 z-index 子元素为何仍被遮挡；
- 给出 Flex/Grid 才适合解决的整体布局反例。

### build

- 从空目录复现 HTML、CSS、几何矩阵、上下文树、命令和结果；
- 九个 canonical topics 都有手算或可观察证据；
- 外部尺寸、包含块、遮挡顺序与目标浏览器 DevTools/截图一致；
- 保存 fixed px 公式与实际读数，任何容差有理由；
- 不复制私有答案。

### diagnose

- 对 box-sizing、containing block 或 stacking context 故障指出首个可信证据；
- 修复后重跑原几何/截图任务，而非更换验收标准；
- 说明 transform、字体、scrollbar、移动视口、辅助技术、浏览器实现等残余风险与回滚。

配套验证器只确认固定数值的盒公式、CSS/HTML 意图契约、包含块/层叠树预言和故障记录。它**没有**执行浏览器布局、margin collapse、sticky/fixed 滚动、程序性 scrolling、点击/焦点、DevTools 读取、截图或视觉差分；这些均是正式 G4 的真实未验证项。

## 16. 一手资料与核验记录

- [W3C CSS Box Model Module Level 4](https://www.w3.org/TR/css-box-4/)：content/padding/border/margin areas 与边；核验于 2026-07-17。
- [W3C CSS Basic User Interface Level 4 — box-sizing](https://www.w3.org/TR/css-ui-4/#box-sizing)：content-box/border-box 尺寸解释；核验于 2026-07-17。
- [W3C CSS Display Module Level 3](https://www.w3.org/TR/css-display-3/)：外部/内部 display type、盒生成、flow-root/none/contents；核验于 2026-07-17。
- [W3C CSS Positioned Layout Module Level 3](https://www.w3.org/TR/css-position-3/)：position schemes、absolute/fixed containing block、inset、sticky、z-index 与上下文；核验于 2026-07-17。
- [W3C CSS Overflow Module Level 3](https://www.w3.org/TR/css-overflow-3/)：scrollable overflow、scrollport、visible/hidden/clip/scroll/auto；核验于 2026-07-17。
- [W3C CSS 2.2 Visual Formatting Model](https://www.w3.org/TR/CSS22/visuren.html) 与 [Box Model](https://www.w3.org/TR/CSS22/box.html)：正常流、block formatting 与 margin collapse 基线；核验于 2026-07-17。
- [W3C CSS 2.2 Appendix E: Elaborate Description of Stacking Contexts](https://www.w3.org/TR/CSS22/zindex.html)：详细 painting order；核验于 2026-07-17。
- [W3C CSSOM View Module](https://www.w3.org/TR/cssom-view-1/)：`getBoundingClientRect()`、client/scroll/offset 几何 API；核验于 2026-07-17。

版本敏感提示：建立 containing block/stacking context 的触发列表、移动端视口行为、`display: contents` 与辅助技术、DevTools 布局/层叠面板 UI 会变化。生产判断必须基于目标浏览器版本和真实任务复核；固定盒公式、正常流/包含块/上下文的核心模型才是本章 stable core。
