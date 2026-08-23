---
schema_version: 2
edition: 2026.2-draft
id: ch.css.grid
title: Grid 二维布局
responsibility: 用轨道、网格线、区域和自动放置表达二维布局，区分 Grid 与 Flexbox 的责任边界。
volume: '07'
order: 10
level: L1-L2
status: drafting
path: book/volume-07-web-platform/chapters/ch.css.grid.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.css.box-position
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
  text: 在 120 秒内解释“Grid 二维布局”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - css-grid-tracks-placement
  - css-grid-areas-responsive
  covers_topics:
  - css.grid-container
  - css.grid-track-sizing
  - css.grid-lines
  - css.grid-auto-placement
  - css.grid-template-areas
  - css.grid-gap
  - css.minmax-fr
  - css.subgrid-boundary
  - css.content-padding-border-margin
  uses_capabilities:
  - web.css-foundations
  - web.css-grid-layout
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现工单列表、筛选栏和详情区组成的二维响应式网格；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - css-grid-tracks-placement
  - css-grid-areas-responsive
  covers_topics:
  - css.grid-container
  - css.grid-track-sizing
  - css.grid-lines
  - css.grid-auto-placement
  - css.grid-template-areas
  - css.grid-gap
  - css.minmax-fr
  - css.subgrid-boundary
  - css.content-padding-border-margin
  uses_capabilities:
  - web.css-foundations
  - web.css-grid-layout
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: track-calculation-layout-matrix-visual-diff
- id: diagnose
  kind: fault-diagnosis
  text: 面对“隐式轨道、min-content 或区域命名错误导致的错位和横向滚动”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - css-grid-tracks-placement
  - css-grid-areas-responsive
  covers_topics:
  - css.grid-container
  - css.grid-track-sizing
  - css.grid-lines
  - css.grid-auto-placement
  - css.grid-template-areas
  - css.grid-gap
  - css.minmax-fr
  - css.subgrid-boundary
  - css.content-padding-border-margin
  uses_capabilities:
  - web.css-foundations
  - web.css-grid-layout
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Grid 二维布局

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《盒模型、display、定位与层叠上下文》](ch.css.box-position.md)：Grid 轨道最终分配的是盒模型尺寸，必须先能解释包含块、溢出和定位边界。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套工件以固定 content box、显式/隐式轨道、网格线、区域和自动放置矩阵建立离线证据；离线绿灯不等于真实浏览器的 track sizing、DevTools Grid overlay、截图或视觉差分已验证。易变事实已于 **2026-07-17** 对照 W3C CSS Grid Layout Level 1/2、CSS Box Alignment Level 3 与 CSS Box Sizing Level 3 一手规范核验。

Grid 解决“行与列同时形成约束”的二维布局。工单列表、筛选区和详情区需要共享列线、明确区域与跨行/跨列放置时，Grid 能直接表达结构；Flexbox 多行的每条 line 独立伸缩，无法天然让第二行与第一行共享列轨。反过来，只有一组按钮沿一条轴分配空间时，用 Grid 建很多行列会把简单一维问题过度结构化。

本章不把 Grid 简化为“写三个 `1fr`”。可靠推理要区分显式网格与隐式网格、track 与 line、item 与 area、固定/内在/弹性 sizing functions、明确放置与 auto-placement、内容最小贡献与 free space，并说明 DOM 顺序不应靠视觉 placement 修复。

## 1. 完成定义、边界与证据入口

完成本章，应能：

1. 识别 grid container、直接 grid items，并画出行/列 tracks、lines、cells、areas；
2. 用固定长度、`auto`、min/max-content、`minmax()`、`fr`、`repeat()` 描述轨道，知道它们不是等价百分比；
3. 用正/负 line index、named lines、`span` 放置 item，并避免把 line 数当 track 数；
4. 解释 explicit grid 如何由 template 定义，以及越界/auto-placement 如何生成 implicit tracks；
5. 手工执行受控 auto-placement 矩阵，区分默认 sparse 与 `dense` 回填；
6. 编写矩形、等列数、同名连续的 `grid-template-areas`，诊断命名拼写导致的整项无效；
7. 把 gap 当作轨道间 gutter 并纳入可用空间，保持 container padding/item box 职责；
8. 解释 `1fr` 的 automatic minimum 与 `minmax(0,1fr)` 的收缩边界；
9. 说明 `subgrid` 只在选择的轴采用父轨道，区分它与独立 nested grid；
10. 注入隐式轨道、min-content 或区域命名故障，找到首个可信证据并重跑原矩阵。

配套入口：

- [轨道、区域与自动放置矩阵示例](../../../examples/encyclopedia/ch.css.grid/README.md)
- [隐式轨道、min-content 与区域故障实验](../../../labs/encyclopedia/ch.css.grid/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.css.grid/README.md)

canonical oracle 是：**固定内容与视口矩阵下，轨道尺寸、区域位置和自动放置顺序与截图基线及 DevTools 网格叠层一致。** 离线 oracle 仅计算固定数字/占位矩阵并检查源码契约；正式 G4 证据要补充浏览器/版本、viewport 与 container content box、writing mode/direction、字体/缩放、Computed track list、Grid overlay、item rect、DOM/Tab 序列、截图基线和视觉差分。

## 2. Grid 推理管线

```text
DOM + computed styles
  → 识别 grid container 与直接 grid items
  → template rows/columns/areas 建立 explicit grid
  → 解析 definite line/area placements
  → auto-placement 按 order-modified document order 填空
  → 越界或放不下时生成 implicit tracks
  → track sizing：固定 → intrinsic contributions → flexible fr
  → item 在 grid area 内 sizing/alignment
  → content alignment 分配整个轨道组剩余空间
  → painting、overflow、DOM/视觉/导航与截图验证
```

故障定位因此有顺序：

- area 声明在 Styles 消失：先查 template grammar/矩形性，不先调 fr；
- item 落到新行：先查 placement 和 implicit grid，再查尺寸；
- tracks 总宽超容器：查 min-content/auto minimum、gap 和 item overflow；
- tracks 正确但 item 没填满：查 justify/align-self 与 item intrinsic size；
- 截图顺序不同于 DOM/Tab：查 placement/order/dense，不用 tabindex 修补。

## 3. Container、item 与二维术语

computed `display:grid` 生成外部 block-level grid container，`inline-grid` 生成外部 inline-level container；内部都使用 grid layout。in-flow 直接 children 成为 grid items，孙元素不自动参与祖先 grid。absolute child 有特殊 grid-containing-block 规则，但不参与普通 auto-placement。

```html
<!-- Responsibility: 用语义区块表达筛选、列表和详情，供二维 Grid 放置。 -->
<!-- Data source: 静态教学工单；真实数据加载不属于本章。 -->
<!-- Mapping: DOM 保持 filter→list→detail 的任务顺序，area 只改变二维呈现。 -->
<!-- Side effects: 此夹具仅加载样式，不请求或修改工单。 -->
<main class="work-order-layout">
  <form class="filters">筛选…</form>
  <section class="work-orders">列表…</section>
  <aside class="work-order-detail">详情…</aside>
</main>
```

核心对象：

- grid line：分隔轨道的线；N 个 tracks 有 N+1 条 lines；
- grid track：两条相邻 lines 之间的一行或一列；
- grid cell：一行轨道与一列轨道交叉的最小单位；
- grid area：一个或多个 cells 构成的矩形；item 的 grid area 是其布局 containing block；
- gutter/gap：轨道之间间距，在 sizing 时像固定尺寸的空轨道；
- explicit grid：template rows/columns/areas 定义的部分；
- implicit grid：item 越界或 auto-placement 需要额外 tracks 时生成的部分。

容器 padding 位于网格轨道组外侧；gap 只在 tracks 之间；item margin 属于 item margin box。Grid item margin 不发生普通块 margin collapse。

## 4. 显式轨道：从固定值到 intrinsic functions

```css
/* Responsibility: 建立筛选跨两列、列表/详情共享二维行列的显式网格。 */
/* Data source: 容器 content box 与三段语义 DOM；不依赖设备型号。 */
/* Mapping: sidebar 最小 16rem、内容允许缩到 0；areas 必须矩形且拼写一致。 */
/* Side effects: 只改变视觉区域和尺寸，不改变 DOM、Tab 或数据顺序。 */
.work-order-layout {
  display: grid;
  grid-template-columns: minmax(16rem, 1fr) minmax(0, 2fr);
  grid-template-areas:
    "filters filters"
    "list    detail";
  gap: 1rem;
  padding: 1rem;
}

.filters { grid-area: filters; }
.work-orders { grid-area: list; min-inline-size: 0; }
.work-order-detail { grid-area: detail; min-inline-size: 0; }
```

`grid-template-columns/rows` 是空格分隔的 track list；方括号可给 lines 命名。常用 sizing functions：

- 固定 `<length>`：轨道 base/growth limit 固定；
- 百分比：相对 container content area 的对应 definite dimension；indefinite 时有特殊处理；
- `auto`：作为 minimum/maximum 会受 item 贡献与 alignment 影响，不能等同 `1fr`；
- `min-content`：用最大的相关最小内容贡献建立 minimum；
- `max-content`：容纳不进行非强制换行的最大内容贡献；
- `fit-content(limit)`：在 auto minimum 与 max-content 之间受 limit 限制；
- `minmax(min,max)`：minimum 与 maximum 两个函数形成范围；flex value 不能作为 minimum；
- `<number>fr`：在完成非弹性/内在约束后分享 leftover space；
- `repeat(n,...)`：重复轨道片段；`auto-fill/auto-fit` 有 repeat-to-fill 规则，留到响应式综合章深入。

## 5. `fr` 与 `minmax()`：分享剩余空间，不是百分比

固定受控案例：container content inline size 960px，三列 `240px 1fr 2fr`，两个 gap 各 24px，忽略 intrinsic/min/max 额外增长。

```text
gaps = 48
fixed track = 240
leftover = 960 - 48 - 240 = 672
flex factor sum = 3
1fr = 224
2fr = 448
check = 240 + 224 + 448 + 48 = 960
```

`fr` 对 leftover space 生效，gap 和固定/内在轨道先占空间。`50% 50%` 再加 gap 会超过 100%，而 `1fr 1fr` 会在扣 gap 后分享剩余空间，这是典型差异。

### 5.1 为什么 `1fr` 仍可能溢出

作为 track maximum 的裸 `1fr` 在 `minmax()` 外意味着 `minmax(auto,1fr)`；automatic minimum 常受 item min-content contribution 约束。长不可断 URL、表格或 flex child 可以把轨道撑宽，使整个 grid 横向滚动。

若产品契约明确允许该轨道低于 min-content 收缩，可写 `minmax(0,1fr)`，并在 item 上视需要 `min-inline-size:0`，再为内容定义换行/省略/滚动策略。不能只把 track minimum 设 0 后让信息不可达。

`minmax(16rem,1fr)` 表示 minimum 不低于 16rem；窄于两列 minimum+gap 时仍会溢出，这是规格而非浏览器 bug。真正响应式切换要在后续章节以内容驱动条件改变 template，本章只验证固定矩阵。

### 5.2 轨道算法为什么不能简化成一次除法

完整 track sizing 会初始化 base size/growth limit，解析 intrinsic sizes 和跨轨 item contributions，增加 tracks，最后展开 flexible tracks。item 跨多轨、baseline、percentage/indefinite size、min/max 和 aspect ratio 都会改变结果。离线公式只覆盖“固定轨+gap+fr 且无 intrinsic violation”的明确子集，正式证据以浏览器 overlay/rect 为准。

## 6. Lines、索引、命名与 span

三列显式 grid 有四条 column lines。正索引从 explicit grid start 侧 1 开始，负索引从 explicit grid end 侧 -1 开始：

```css
.filters { grid-column: 1 / -1; }
.detail { grid-column: 2 / span 1; }
```

`1 / -1` 跨显式网格全部列，不保证跨随后生成的所有 implicit columns。item 放到显式边界之外会创建 implicit track；看到 “-1” 不能推断它是当前最终隐式网格最后线。

命名 lines 可减少魔法数字：

```css
.layout {
  grid-template-columns:
    [layout-start list-start] minmax(16rem, 1fr)
    [list-end detail-start] minmax(0, 2fr)
    [detail-end layout-end];
}

.detail { grid-column: detail-start / detail-end; }
```

同名 line 可重复，`name 2` 等语法选择第几个；`span` 表示跨多少 lines/匹配 named lines。简写 `grid-column`/`grid-row` 设置 start/end，`grid-area` 也可用四个 line 值。调试先展开长写，避免把 area name 与四值 shorthand 混淆。

## 7. `grid-template-areas`：可读但语法严格

每个字符串是一行，每行 cell token 数必须相同。同名区域必须形成一个完整矩形；不能 L 形、分裂成两岛。`.` 表示空 cell。任一行拼写、列数或矩形性错误会让整个 property 无效，而不是只丢坏 cell。

```css
grid-template-areas:
  "filters filters"
  "list    detail"
  "list    detail";
```

每个 named area 隐式创建 `name-start`/`name-end` 行列线。item `grid-area: details` 与 template 的 `detail` 不一致时，不会“模糊匹配”；它可能按 line-name/auto placement 规则落到意外位置并扩展隐式网格。首个证据是 container computed `grid-template-areas`、item placement longhands 与 Grid overlay。

Areas 很适合少量稳定页面区域；大量动态卡片更适合 auto-placement。不要为每条工单生成独立 area 名，也不要用 area 改写不合理 DOM 任务顺序。

## 8. Explicit 与 implicit grid

template 定义固定数量显式 tracks。以下行为会产生 implicit tracks：

- item 明确放到显式 line 范围外；
- auto-placement 找不到显式空 cell；
- template areas 定义了但 rows/columns 未显式 sizing 的轨道按 auto track properties sizing。

`grid-auto-rows`/`grid-auto-columns` 设置隐式 tracks 的 sizing pattern；若省略，默认 `auto` 可能被内容撑大。故障常表现为“第三行突然很高”或“出现横向滚动”，根因其实是意外 implicit column，而不是 gap。

DevTools overlay 要同时显示 line numbers、area names 和 explicit/implicit 区别。矩阵记录 expected explicit track count、allowed implicit track count 与 auto-track size；不能只记录最终 item rect。

## 9. Auto-placement：先放 definite，再走游标

没有明确位置的 grid items 由 auto-placement 放入未占 cells。`grid-auto-flow: row` 默认按行前进；`column` 交换主遍历轴。大致顺序是先处理有 definite placements 的 items，再按 order-modified document order 放置其余 items，必要时创建 implicit tracks。

默认 sparse 算法不会回头填所有早期空洞：一个 span 2 item 跳过只剩 1 cell 的洞后，后续 item 也许留空。`dense` 允许回填较早空洞，但可能使视觉顺序与 DOM 顺序分裂。因此 dense 适合顺序无语义的图块，不适合工单优先级/键盘任务列表。

受控 3-column sparse 案例：

```text
A span 2 → row1 col1-2
B span 2 → row2 col1-2（row1 只剩1格，跳过）
C span 1 → row2 col3（游标不回填 row1）
结果：row1 col3 保持洞
```

若 dense，C 可回填 row1 col3。离线 oracle 可模拟这个固定子集，但真实规范还处理 definite row/column、order、negative lines、overlap 和 implicit growth；不要把简化程序当浏览器实现。

与 Flex 相同，`order` 只影响视觉布局/placement 顺序，不修复 source、speech 与 sequential navigation。Grid line/area placement也能改变视觉位置，因此必须验证 DOM/Tab 顺序。

## 10. Gap、padding 与外部尺寸

`row-gap`、`column-gap`、`gap` 创建轨道间 gutters；track sizing 算法把 gutter 当固定尺寸空轨道。两列一个 column gap，三列两个；它不在 container 边缘产生 padding。

container content box 960、padding inline 16 each 时，若元素 border-box width 为 992，轨道可用 content size 才是 960；不能拿 border-box rect 直接分配 tracks。item 的 padding/border 又可能贡献 min-content/outer size。所有矩阵必须注明 container 使用哪条 edge、item 输入是 content contribution 还是 border-box rect。

Grid item 的 percentage size、overflow、auto minimum 和 box-sizing 仍遵循盒/尺寸规范。Grid 不是绕过盒模型的“魔法布局”。

## 11. Alignment：轨道组与 item 分开

Grid 中两轴都可对齐：

- `justify-content`：inline axis 对齐整个 column track group；
- `align-content`：block axis 对齐整个 row track group；
- `justify-items`/`align-items`：设 grid items 在各自 area 内的默认 self-alignment；
- `justify-self`/`align-self`：覆盖单 item；
- `place-content/items/self`：相应成对 shorthand。

若 fr/stretch 已消耗相应自由空间，content distribution 没有空间可移动轨道组。item 默认 normal 对常见非替换元素通常表现为 stretch，但 replaced item/aspect-ratio 等边界不同。auto margins 也会参与。诊断要明确 subject 是轨道组还是 item margin box。

Grid 的 baseline alignment 可跨相关 items 影响 intrinsic contributions，固定截图可能受字体影响。本章矩阵用 start/stretch 简化；生产表单 baseline 必须真实验证。

## 12. `subgrid`：共享父轨道，不是“嵌套 grid”别名

CSS Grid Level 2 的 `subgrid` 可在行或列轴采用父 grid 中该 item 跨越部分的 tracks。subgrid 在该轴不自己定义独立 track sizes；其 children 的 intrinsic contributions 可参与共享父 tracks 的 sizing。另一轴仍可保持独立 grid tracks。

```css
.parent { display: grid; grid-template-columns: 8rem 1fr auto; }
.card { display: grid; grid-template-columns: subgrid; grid-column: 1 / -1; }
```

普通 nested grid 的列尺寸各卡独立，不会自动与父/兄弟共享；subgrid 才表达跨层共享列线。它受父 item span 限制，line names/gap 继承/覆盖有专门规则；不是无界穿透所有祖先。

subgrid 是版本敏感能力。使用前应在目标浏览器验证支持和实际 overlay，并设计不破坏内容可达性的 fallback。课程离线 oracle 只检查“adopts parent tracks in selected axis”概念，不声称真实 subgrid 已运行。Masonry 不是本章内容，也不能用 subgrid 代称。

## 13. Grid 与 Flex 的决策边界

选择不是“哪个更现代”：

| 问题 | 优先模型 | 原因 |
| --- | --- | --- |
| 一组按钮沿单轴分配空间 | Flex | basis/grow/shrink 与单轴对齐直接表达 |
| 卡片内部标题、正文、动作纵向推底 | Flex | 单列内部关系 |
| 页面 filter/list/detail 共享行列 | Grid | 二维 area/track 关系 |
| 多行卡片要求每列跨行对齐 | Grid | 共享 columns；Flex lines 独立 |
| 内容自然换行、最后一行可不同宽 | Flex | 一维 wrap 正合适 |
| 子组件字段与父表单列线对齐 | subgrid（验证支持） | 共享父 tracks |

可以嵌套：页面 Grid 的某个 area 内用 Flex 工具栏，Grid card 内部也可再用一维 Flex。职责按每一层局部问题选择，不要为了统一只用一个模型。

## 14. DevTools 与二维布局矩阵

推荐证据流程：

1. 记录 container content box、writing-mode/direction、template rows/columns/areas、auto-flow/auto tracks、gap；
2. 开启 Grid overlay，显示 line numbers/names、areas、track sizes、implicit lines；
3. 对每 item 记录 DOM index、order、placement longhands、grid area、min/max、rect；
4. 先手算固定/gap/fr 子集，再读 resolved track list/overlay；
5. 注入 long token，比较 `1fr` 与 `minmax(0,1fr)`，同时验证内容策略；
6. 注入 area typo 或越界 line，先预测 implicit tracks，再观察；
7. 分别运行 sparse/dense 夹具，记录 DOM/visual/Tab；
8. 固定 viewport、字体、缩放与 DPR 做基准/修复截图差分。

矩阵至少包含 viewport、container content size、template、gap、content variant、expected tracks、areas/placements、implicit count、auto-placement order、DOM/Tab order、browser observed、screenshot/diff。未运行的后两类字段必须明确 `unverified`。

## 15. 三类注入故障

### 15.1 意外隐式轨道

注入：显式两列，却给 detail `grid-column:3 / 4`，或 auto item 放不下。症状是第三列/横向滚动。首个证据是 overlay 显示 explicit end 外新增 implicit line/track，以及 item placement longhands。修复 placement 或明确 `grid-auto-columns`，重跑固定矩阵。

### 15.2 min-content 撑宽

注入：`240px 1fr` 的内容列包含不可断 token，保持 auto minimum。症状是 grid 超过 content box。首个证据是 item min-content contribution 与 `1fr` 实际 `minmax(auto,1fr)` 边界。若契约允许，改为 `240px minmax(0,1fr)` 并处理 item/content；不能只加 overflow hidden 掩盖。

### 15.3 area name/grammar 错误

注入：template 写 `details`，item 写 `detail`；或同名 area 形成 L 形。首个证据是 container property 无效/Computed 为 none 或 item 没有匹配 named area。修复所有行 token/矩形和 item name，重跑同一 area/rect/截图 oracle。

故障日志保留 injected change、wrong prediction、first trusted evidence、root cause、repair、same verification rerun、residual risk。只保存最终 overlay 不足以证明诊断过程。

## 16. 独立构建任务

从空目录实现工单二维布局：

1. 语义 DOM 顺序为筛选、列表、详情，视觉 placement 不破坏键盘任务顺序；
2. 固定宽矩阵用明确 areas；列表/详情共享两列 tracks；
3. 至少一处 line/span placement，一处 auto-placement 动态卡片区；
4. 明确 explicit tracks、允许的 implicit tracks 和 `grid-auto-rows/columns`；
5. 用固定/gap/fr 受控案例手算 tracks，并测试长 token 的 min-content；
6. container padding、gap、item box 各自职责清楚；
7. 记录 subgrid 的目标用例、支持验证和 fallback，但不伪造运行结果；
8. 注入 implicit track、min-content、area mismatch 三类故障中的至少两类并重跑原矩阵；
9. 保存 Grid overlay、Computed、rect、DOM/Tab、基准/修复截图和视觉差分。

通过条件：固定内容/视口矩阵下，tracks、areas、auto-placement 与目标浏览器截图/overlay 一致；所有未执行真实项明确未验证。

## 17. 120 秒讲回模板

> Grid 是二维布局。container 的直接 in-flow children 是 grid items；template rows/columns/areas 建 explicit grid，越界放置或 auto-placement 会创建 implicit tracks。N 个 tracks 有 N+1 条 lines，正负索引从显式网格两端计。固定和 intrinsic tracks 先占空间，gap 也按固定 gutter 计入，fr 再分享 leftover；裸 1fr 有 auto minimum，长 min-content 可能撑宽，只有在职责允许时才用 minmax(0,1fr) 并处理内容。auto-placement 默认 sparse 不回填早期洞，dense 可能视觉重排，所以要验证 DOM/Tab。areas 必须每行等列、同名矩形。subgrid 只在选定轴采用父轨道，不是普通 nested grid。证据是 track/placement 矩阵、Grid overlay、rect 和截图。本章不该解决单轴按钮组的 grow/shrink，那是 Flexbox 的职责。

反例：只有三个按钮在一行中一个增长、两个保持内容宽，不需要二维共享轨道，应使用 Flexbox。

## 18. 常见失败清单

- 把孙元素当祖先 grid item；
- 把 track 数与 line 数混淆；
- 认为 `1fr` 等于容器某百分比，不扣 gap/固定轨；
- 用 `50% 50%` 加 gap 后惊讶溢出；
- 认为裸 1fr minimum 为 0，忽略 auto/min-content；
- 全部改 `minmax(0,1fr)` 却不验证信息可达；
- `1 / -1` 被当作包含所有 implicit columns；
- area 拼写/L 形错误后继续调 item width；
- 不记录 `grid-auto-rows/columns`，意外轨道被内容撑大；
- 把 sparse 预期写成 dense 回填；
- 用 dense/order/placement 修逻辑 DOM 顺序；
- 混淆 content alignment 与 item self-alignment；
- 把 nested grid 当 subgrid；
- 用 Grid 过度设计单轴组件，或用多行 Flex 冒充共享二维轨道；
- 用离线矩阵声称真实 track sizing、overlay 和视觉 diff 已通过。

## 19. 验收与证据边界

### explain

- 120 秒内讲清 container/item、track/line/area、explicit/implicit、auto-placement、fr/minmax、subgrid；
- 给出一个应由 Flex 解决的一维反例；
- 能解释长内容如何通过 auto minimum 撑宽 1fr。

### build

- 从空目录复现二维工单布局、矩阵、命令与结果；
- 八个 taught topics 与盒模型 used topic 都有证据；
- 固定内容/视口下 tracks、areas、auto-placement 与目标浏览器一致；
- DOM/visual/Tab 顺序保持任务逻辑；
- subgrid 支持/fallback 结论有真实证据或明确未验证。

### diagnose

- implicit track、min-content、area mismatch 能指出首个可信证据；
- 修复后重跑原矩阵/截图，不改变验收标准；
- 说明 intrinsic sizing、字体、writing mode、dense、subgrid 支持和浏览器舍入残余风险。

配套验证器只确认固定 px `fr` 子集、area/placement 文本契约、简化 sparse/dense 模型、故障记录和 disclosure。它**没有**运行浏览器完整 track sizing、intrinsic contributions、subgrid、RTL、Grid overlay、键盘导航或截图视觉差分。

## 20. 一手资料与核验记录

- [W3C CSS Grid Layout Module Level 1](https://www.w3.org/TR/css-grid-1/)：Grid 术语、tracks、lines、areas、implicit grid、auto-placement、track sizing 与 gap；核验于 2026-07-17。
- [W3C CSS Grid Layout Module Level 2](https://www.w3.org/TR/css-grid-2/)：subgrid 轴、父轨道采用与 intrinsic contribution；核验于 2026-07-17。
- [W3C CSS Box Alignment Module Level 3](https://www.w3.org/TR/css-align-3/)：content/items/self alignment、gap 与 baseline；核验于 2026-07-17。
- [W3C CSS Box Sizing Module Level 3](https://www.w3.org/TR/css-sizing-3/)：min/max-content 与 intrinsic size contributions；核验于 2026-07-17。

版本敏感提示：Grid Level 2/subgrid、track serialization、DevTools overlay、intrinsic sizing 修订与浏览器舍入会变化。生产兼容结论必须基于目标浏览器版本、官方测试/WPT 与真实任务；本章 stable core 是二维 tracks/lines/areas、显式/隐式边界和放置/尺寸推理。
