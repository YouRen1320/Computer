---
schema_version: 2
edition: 2026.2-draft
id: ch.css.flexbox
title: Flexbox 一维布局
responsibility: 用主轴、交叉轴、伸缩、换行和对齐解决一维组件布局，不把二维页面网格强塞给 Flexbox。
volume: '07'
order: 9
level: L1
status: drafting
path: book/volume-07-web-platform/chapters/ch.css.flexbox.md
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
  text: 在 120 秒内解释“Flexbox 一维布局”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - css-flex-axis-sizing
  - css-flex-alignment
  covers_topics:
  - css.flex-container
  - css.flex-main-cross-axis
  - css.flex-basis-grow-shrink
  - css.flex-wrapping
  - css.justify-content
  - css.align-items-content
  - css.flex-gap
  - css.flex-visual-order
  - css.content-padding-border-margin
  uses_capabilities:
  - web.css-foundations
  - web.css-flex-layout
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现能容纳长文本和窄视口的表单工具栏与卡片行布局；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - css-flex-axis-sizing
  - css-flex-alignment
  covers_topics:
  - css.flex-container
  - css.flex-main-cross-axis
  - css.flex-basis-grow-shrink
  - css.flex-wrapping
  - css.justify-content
  - css.align-items-content
  - css.flex-gap
  - css.flex-visual-order
  - css.content-padding-border-margin
  uses_capabilities:
  - web.css-foundations
  - web.css-flex-layout
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: layout-matrix-computed-style-check-responsive-visual-oracle
- id: diagnose
  kind: fault-diagnosis
  text: 面对“min-size、shrink 或视觉 order 配置导致的溢出和键盘顺序错位”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - css-flex-axis-sizing
  - css-flex-alignment
  covers_topics:
  - css.flex-container
  - css.flex-main-cross-axis
  - css.flex-basis-grow-shrink
  - css.flex-wrapping
  - css.justify-content
  - css.align-items-content
  - css.flex-gap
  - css.flex-visual-order
  - css.content-padding-border-margin
  uses_capabilities:
  - web.css-foundations
  - web.css-flex-layout
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Flexbox 一维布局

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《盒模型、display、定位与层叠上下文》](ch.css.box-position.md)：Flex 项尺寸、溢出和包含块仍遵循盒模型，必须先能解释元素外部尺寸。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套工件以固定容器宽度、item 基准尺寸、flex factors、gap、换行和顺序矩阵建立离线证据；离线绿灯不等于真实浏览器的 Flex 算法、computed style、键盘顺序或视觉差分已验证。易变事实已于 **2026-07-17** 对照 W3C CSS Flexible Box Layout Level 1、CSS Box Alignment Level 3 与 CSS Box Sizing Level 3 一手规范核验。

Flexbox 解决的是“沿一条主轴排列一组项目，并在空间变化时伸缩、换行和对齐”。工具栏、按钮组、水平元数据、纵向卡片内部结构都是典型问题。它可以换成多行，但各行分别分配主轴空间，行与行之间没有共享列轨道；如果任务要求第二行的字段与第一行列线对齐，应该进入 Grid，而不是给每项手写宽度模拟二维网格。

本章的核心不是背 `display:flex`，而是能预测：谁是 flex item、主轴向哪、基准尺寸是多少、可用自由空间是正还是负、grow/shrink 如何分配、自动最小尺寸是否冻结 item、在哪一步换行和对齐，以及视觉顺序是否与 DOM/键盘顺序分裂。

## 1. 完成定义、边界与证据入口

完成本章，应能：

1. 从 computed `display` 找出 flex container 与其直接 in-flow flex items；
2. 结合 `flex-direction`、writing mode 与 direction 标出 main/cross axis 及 start/end；
3. 区分 flex base size、hypothetical main size、post-flexing used main size 与盒模型外部尺寸；
4. 在固定 px 夹具中手算正自由空间的 grow 与负自由空间的 scaled shrink；
5. 解释 `flex-wrap` 如何收集 flex lines，以及多行仍不是共享轨道的二维 Grid；
6. 区分 `justify-content`、`align-items`、`align-self`、`align-content` 与 auto margin；
7. 使用 `gap` 表达项目/行之间间距，同时保留容器 padding 与 item margin 的职责边界；
8. 证明 `order`/reverse 只改变视觉布局，不能修复 DOM、朗读和键盘顺序；
9. 注入 min-size、shrink 或视觉 order 故障，指出首个可信证据并重跑原矩阵。

配套入口：

- [Flex 主轴尺寸与换行矩阵示例](../../../examples/encyclopedia/ch.css.flexbox/README.md)
- [长文本、收缩与顺序故障实验](../../../labs/encyclopedia/ch.css.flexbox/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.css.flexbox/README.md)

canonical oracle 是：**不同内容长度和容器宽度下，主轴尺寸、换行和对齐结果与预先声明的布局矩阵一致。** 配套 oracle 只计算受控数字并检查 HTML/CSS 契约；正式 G4 证据必须补充浏览器与版本、writing mode/direction、视口和容器 content box、字体/缩放、Flex overlay、Computed、DOM/Tab 顺序、截图基线与差分。

## 2. 推理管线：对齐在伸缩之后

```text
DOM + computed styles
  → 识别 flex container 和直接 flex items
  → 决定 main/cross axis、方向与是否 wrap
  → 求每项 flex base / hypothetical main size
  → 按 outer hypothetical size 收集 flex lines
  → 每行解析 grow 或 scaled shrink，并受 min/max 冻结
  → 求每行 cross size
  → justify-content 分配剩余 main-axis 空间
  → align-items/self 对齐 item，align-content 分配多行 cross space
  → order-modified visual layout 与 DOM/导航证据分别检查
```

这解释了几个常见“属性没效果”：

- `justify-content: space-between` 看不到间隔，可能是 grow 已把主轴自由空间用完；
- `align-content` 没效果，可能只有一条 flex line，或 cross size 没有额外空间；
- `flex-shrink: 1` 仍溢出，可能 item 被自动 min-content minimum 冻结；
- `order:-1` 画面正确但 Tab 错位，因为它本来就不改变顺序导航；
- `width` 看似没生效，可能 `flex-basis` 在主轴尺寸计算中先成为基准。

## 3. 容器、item 与匿名内容

元素的 computed `display` 为 `flex` 或 `inline-flex` 时，生成 flex container。两者的差别首先是容器自身在外部 flow 中为 block-level 或 inline-level；内部都运行 flex layout。容器的 in-flow children 成为 flex items。孙元素不是该容器的 item，除非其父本身又建立 flex container。

```html
<!-- Responsibility: 用一维工具栏组织筛选输入和两个动作，不表达二维表格。 -->
<!-- Data source: 固定教学字段；真实筛选状态由后续表单逻辑提供。 -->
<!-- Mapping: DOM 先筛选后提交/清除；CSS 不重新排列可操作项。 -->
<!-- Side effects: 此静态夹具只加载样式；按钮没有提交或写业务状态。 -->
<form class="work-order-toolbar">
  <label class="work-order-toolbar__query">关键字 <input name="q"></label>
  <button type="submit">筛选</button>
  <button type="reset">清除</button>
</form>
```

```css
/* Responsibility: 让工具栏沿 inline 主轴排列，在空间不足时整项换行。 */
/* Data source: HTML 直接子元素和容器 content box；不读取设备型号。 */
/* Mapping: query 可增长/收缩，动作保持内容尺寸，gap 只负责 sibling 间距。 */
/* Side effects: 改变视觉尺寸与换行，不改变 DOM、Tab 或提交顺序。 */
.work-order-toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: end;
  gap: 0.75rem;
  padding: 1rem;
}

.work-order-toolbar__query {
  flex: 1 1 18rem;
  min-inline-size: 12rem;
}
```

直接文本可能被包装为匿名 flex item；只包含可折叠空白的匿名 item 可能不渲染。不要依赖匿名 item 来表达可测组件结构，给有意义内容明确元素。绝对定位的 child 不参与 flex layout，但其静态位置/包含块仍有专门规则，不能把它算入 grow/shrink。

Flex item 的 margin 不发生普通块的 margin collapse。容器 padding 属于内部边界，gap 属于 item/line 之间，item margin 属于单项外部例外；三者都占空间但责任不同。

## 4. 主轴与交叉轴不是水平与垂直的别名

`flex-direction` 决定 main axis：

- `row`：沿当前 writing mode 的 inline axis，从 main-start 到 main-end；
- `row-reverse`：交换 main-start/end；
- `column`：沿 block axis；
- `column-reverse`：交换对应 start/end。

cross axis 总与 main axis 垂直。LTR 水平书写中的 `row` 常从左到右，但 RTL、vertical writing mode 会改变物理映射。优先用 `inline-size`、`block-size`、`margin-inline-start` 等逻辑属性，并在测试矩阵写明 direction/writing-mode；不要把 `row` 注释成永远“横向从左到右”。

reverse 只改变视觉流向，源顺序与顺序导航仍由 DOM 决定。若界面必须“返回→下一步”按视觉从左到右，而 DOM 却相反，用 reverse 掩盖会制造键盘/朗读错位；应先修 DOM 的逻辑顺序，再选普通方向。

## 5. 三个 flex 分量：basis、grow、shrink

`flex` shorthand 对应 `flex-grow flex-shrink flex-basis`。它们不是“比例宽度”三个同义写法：

- `flex-basis` 给出 flexing 之前的主轴基准；`auto` 常从主尺寸属性或内容取得输入；
- `flex-grow` 决定正自由空间如何分配；默认 0；
- `flex-shrink` 决定负自由空间如何按 scaled shrink factor 收回；默认 1。

常用关键字：`flex: initial` 相当于 `0 1 auto`，可缩不主动长；`flex: auto` 相当于 `1 1 auto`；`flex: none` 相当于 `0 0 auto`。单数字 `flex: 1` 的常见展开是 `1 1 0%`，不是简单的 `width: 100%`；百分比 basis 在 indefinite container 中还有求值边界。关键组件建议写能表达意图的 shorthand/三个分量并在 Computed 复核，而不是背缩写猜测。

### 5.1 正自由空间手算

固定案例：容器 content main size 720px；三项 outer flex base（这里 margin/border/padding 均已计入约束）分别 160、240、200；两个 gap 各 16；grow 为 1、2、1。

```text
available for item boxes = 720 - 2×16 = 688
base total = 160 + 240 + 200 = 600
positive free space = 688 - 600 = 88
grow sum = 1 + 2 + 1 = 4
increments = 22, 44, 22
target main sizes = 182, 284, 222
check = 182 + 284 + 222 + 32 = 720
```

这是没有 min/max violation、margin、intrinsic adjustment 等复杂因素的教学子集。真实算法会反复冻结违反 min/max 的 item 并重新分配；不能把一次比例算式当完整浏览器实现。

grow factor 表示分享**自由空间**，不是最终尺寸比例。basis 不同的两项即使都 grow 1，最终尺寸通常不相等。若目标是等分，需明确 basis、min-size、padding/border 与内容贡献；`flex:1` 也可能被长内容的自动最小尺寸阻挡。

### 5.2 负自由空间与 scaled shrink

固定案例：容器 500px；gap 共 20px；两项 base 分别 300、200，shrink factors 分别 1、2。可放 item boxes 的空间为 480，负自由空间为 -20。

```text
scaled shrink A = 1 × 300 = 300
scaled shrink B = 2 × 200 = 400
sum = 700
A removes 20 × 300/700 ≈ 8.571
B removes 20 × 400/700 ≈ 11.429
targets ≈ 291.429, 188.571
check ≈ 291.429 + 188.571 + 20 = 500
```

shrink 要乘 base size，避免大项目与小项目只按相同裸 factor 不成比例缩。实际 used value 可能有亚像素/设备像素舍入，截图不必每项都显示整数；矩阵保存允许误差并用总和校验。

`flex-shrink:0` 表示该项不参与收缩，剩余项目承担更多负空间；若所有项都不能缩、min-size 又大于空间，结果就是溢出，浏览器不会凭空创造空间。

### 5.3 basis 与 width 的优先关系

主轴为 row 时，`width` 是主尺寸属性；但非 `auto` 的 `flex-basis` 通常作为 flex base 输入，post-flexing used width 还会继续变化。主轴为 column 时，对应的是 height/block size。看到 `width:200px` 却实际 240px，不代表 cascade 错；应检查 computed basis/grow/shrink 和 post-flexing rect。

盒模型仍适用。若 basis 表示 content box，padding/border 会形成 outer flex base/outer target 的差异；课程矩阵会明确输入是 inner 还是 outer，不能混算。

## 6. 自动最小尺寸：最常见的 Flex 溢出根因

Flex item 主轴上的 `min-width/min-height:auto` 可能使用 content-based minimum。长不可断 URL、代码、表格或嵌套控件会让 item 拒绝收缩，即使 `flex-shrink:1`。典型修复：

```css
.toolbar__query {
  flex: 1 1 18rem;
  min-inline-size: 0;
}

.toolbar__query input {
  inline-size: 100%;
  min-inline-size: 0;
}
```

`min-inline-size:0` 是明确允许该 item 低于内容最小贡献；它不是所有 flex item 的万能 reset。若内容不能断行且不可裁剪，缩小只会把溢出转移到 item 内。还需按内容职责选择 `overflow-wrap:anywhere`、省略、滚动或换行，并验证完整信息仍可达。

对 scroll container，自动最小尺寸处理不同。不要为了得到 0 最小尺寸随手加 `overflow:hidden`，这会裁剪焦点环/弹层并改变滚动语义。首个证据是目标 item 的 computed `min-inline-size`、overflow、内容 min-content 约束和 Flex overlay，而非“加 0 后看起来好了”。

## 7. 换行：每条 flex line 独立伸缩

`flex-wrap: nowrap` 默认所有 items 在一条 line；`wrap` 允许超过 line 长度时创建 cross-axis 新 line；`wrap-reverse` 反转 cross-start/end 的堆放方向。`flex-flow` 是 direction 与 wrap shorthand。

行收集以 item 的 outer hypothetical main size 为重要输入，然后每行独立解析 flexible lengths。因此同一 `flex:1` 卡片在最后一行只有两项时，可能比上一行三项更宽。这正说明多行 Flex 不是 Grid：没有共享列轨道来保持跨行列宽一致。

换行矩阵至少包含：

- 宽容器、短文字：一行；
- 窄容器、短文字：按 item min/base 换行；
- 宽容器、长不可断 token：检查 auto min-size；
- 窄容器、按钮本地化长文案：动作是否整项换行；
- RTL/缩放 200%：视觉 start/end 和可达内容。

不要仅用 viewport 作为输入；Flex 算法看到的是容器 content box。侧栏、嵌套容器、滚动条与 padding 都会让同一 viewport 下可用主轴不同。

## 8. 主轴对齐：`justify-content`

`justify-content` 在**每条 flex line** 的 main axis 分配 flexible sizing 和 auto margins 之后剩余的自由空间。常见值 `flex-start/start`、`flex-end/end`、`center`、`space-between`、`space-around`、`space-evenly`。

若 items 的 grow 已吸收全部正空间，justify-content 没有剩余空间可分。若出现负自由空间，分布式对齐会使用 fallback，safe/unsafe overflow alignment 还影响溢出处理。不能看到声明存在就声称“均匀分布已经生效”。

main-axis auto margin 会先吸收正自由空间，优先于 `justify-content`：

```css
.toolbar__danger-action { margin-inline-start: auto; }
```

这可把单个动作推向 main-end，但换行后它只在所在 line 吸收空间。若必须跨所有行固定为右列，问题已经接近二维轨道，应考虑 Grid。

## 9. 交叉轴对齐：item 与 lines 分开

`align-items` 设置 flex items 的默认 cross-axis self-alignment，`align-self` 覆盖单项。常见 `stretch`、`flex-start/start`、`flex-end/end`、`center`、`baseline`。对普通非替换 item，auto cross size 在 stretch 条件下可能拉伸；已有明确尺寸/min/max 或 auto margin 会改变结果。

`align-content` 对齐的是**多条 flex lines 作为整体**，只对 multi-line flex container 有效，还需要 cross axis 有可分配空间。单行容器即便写 `flex-wrap:wrap` 但实际只有一行，也不能据此期待 `align-content:center` 移动 items；单行 item 用 align-items/self。

Baseline 对齐依赖内容基线、writing mode、字体与可能的合成基线，不是简单“底边对齐”。表单控件跨浏览器 baseline 可能有差异，必须用目标浏览器截图/rect 验证。

auto cross-axis margin 会吸收空间并优先于 align-self。诊断对齐时依次记录：alignment container、subject 的 margin box、轴、可用空间、auto margin、目标属性与 fallback。

## 10. `gap` 与盒模型间距

`row-gap`、`column-gap`、`gap` 在 Flex 中建立相邻 items/lines 之间的固定最小 gutter；它不在容器首尾自动加外边距。对 row flex，column-gap 通常是同一 line items 的 main-axis 间距，row-gap 是 lines 的 cross-axis 间距；direction/writing mode 仍决定物理方向。

与 margin 相比，gap 不需要“最后一项归零”，不会发生 margin collapse，并把 sibling 间距责任集中在 container。容器边缘留白仍用 padding；单项特殊偏移/auto absorption 才用 margin。

gap 会先占用可用空间，再计算 grow/shrink。三项两个 16px gap 就必须从容器主尺寸减 32，而不是伸缩完成后再“额外画上去”。百分比 gap 在尺寸不确定和 intrinsic sizing 时有专门解析规则，本章数字 oracle 固定 px，不把它泛化。

## 11. 视觉 order 与 DOM/键盘顺序

`order` 默认 0，按 order-modified document order 参与视觉布局；相同 order 保持源相对顺序。`row-reverse/column-reverse` 也能反转视觉 main flow。但规范明确这些能力只改变视觉呈现，不改变 speech 和默认 sequential navigation 的源顺序。

错误案例：DOM 是“提交、取消、帮助”，CSS 用 `order` 显示“帮助、取消、提交”。鼠标看到的第一项不是 Tab 第一项，屏幕放大/读屏用户的线性顺序也可能与视觉分离。修复不是设置正 `tabindex` 人工补序；应把 DOM 写成逻辑/任务顺序，让 CSS 只做不影响理解的装饰性排列。

验收必须同时记录：DOM 序列、视觉序列、连续 Tab 焦点序列和可访问性检查。截图只能证明视觉，不证明键盘或朗读。若 order 用于装饰图片移位，也要验证图文关系与小屏/无 CSS 顺序仍合理。

## 12. DevTools 与布局矩阵

推荐证据过程：

1. 选中 container，记录 content main/cross size、writing-mode、direction、flex-flow、gap；
2. 开启 Flex overlay，记录 line 数量与方向；
3. 对每项记录 outer flex base、computed grow/shrink/basis、min/max、padding/border/margin；
4. 先手算自由空间和目标值，再读取 rect/DevTools；
5. 对长 token 注入/删除 `min-inline-size:0`，预测溢出变化；
6. 按 DOM 顺序 Tab，记录 focus indicator 与视觉顺序；
7. 固定宽度/字体/缩放截图并做差分；
8. 若浏览器显示的“flex base size”面板字段变化，保存版本和原始 computed/rect 数据，不把 UI 文案当 API。

布局矩阵示例列：case、container main size、direction/wrap、gap、items 的 basis/grow/shrink/min、expected lines、expected used main sizes、alignment、DOM/visual/Tab order、browser observed、visual diff。最后两列在未运行浏览器时必须为 `unverified`，不能复制离线预言。

## 13. 三类注入故障

### 13.1 min-size 溢出

注入：给可伸缩查询区放一段不可断设备编码，保留 `min-inline-size:auto`。症状是容器横向滚动，按钮被推出。首个证据是 query item 的 auto min/content-based minimum 大于可分配 target，不是 shrink 属性缺失。

修复：在真正允许收缩的 item 设 `min-inline-size:0`，并为文本制定断行/省略/滚动策略。重跑同样的短/长文本与窄宽矩阵；残余风险包括本地化、200% 缩放、焦点环和完整值可达性。

### 13.2 shrink 误算

注入：把 factors 1/2 直接当作各缩 1/3、2/3，却遗漏乘 base size和 gap；或某项设 shrink 0 仍期待平均缩。首个证据是 negative free space 与 scaled shrink table。修复 factor/basis/min 约束，重跑总和与每项 rect。

### 13.3 视觉/DOM 顺序错位

注入：给“高优先级”按钮 `order:-1`，使它视觉第一但 DOM/Tab 最后。首个证据是 DOM 与连续 Tab 序列，不是截图。修复 DOM 逻辑顺序并移除语义重排；若只有装饰图重排，记录为何不改变任务顺序。

每份故障日志保存 injected change、wrong prediction、first trusted evidence、root cause、minimal repair、same verification rerun、residual risk。只保留修复后 CSS 不能证明诊断能力。

## 14. 独立构建任务

从空目录实现表单工具栏与卡片行：

1. 工具栏有标签化查询输入、状态选择、提交和清除，DOM 顺序与任务顺序一致；
2. 使用一维 Flex，窄容器允许整项换行，长文本不制造不可达横向滚动；
3. 卡片行在宽度矩阵中分别出现 3/2/1 项换行，但不要求跨行共享列轨道；
4. 至少一项 grow、一项 shrink 0、一项 auto margin，并解释自由空间后果；
5. container padding、gap、item margin 职责不混用；
6. 建立不少于六个 case 的布局矩阵并先写预言；
7. 注入 min-size、shrink、order 三类故障中的至少两类，保存首个证据和同一验证重跑；
8. 在真实浏览器记录 Flex overlay、Computed、rect、DOM/Tab 顺序与截图差分。

通过条件：关键断言、预期输出和目标浏览器观察一致；未执行的真实浏览器项必须明确 `unverified`。

## 15. 120 秒讲回模板

> Flexbox 是一维布局：container 的直接 in-flow children 成为 flex items，flex-direction 与 writing mode 决定主轴，交叉轴与它垂直。每条 line 先由 flex-basis 和 outer hypothetical size 收集 items，再对正自由空间按 grow 分配，对负自由空间按 shrink×base 的 scaled factor 收回，并受 min/max，尤其自动 min-content minimum 限制。伸缩之后 justify-content 才分配主轴剩余空间；align-items/self 对 item，align-content 只对多条 lines。gap 占用可用空间但不提供容器边缘 padding。wrap 的每行独立伸缩，不形成共享二维轨道。order 和 reverse 只改视觉，不改 DOM、朗读和 Tab，所以证据必须同时含布局矩阵与键盘顺序。本章不处理需要行列共同对齐的二维页面网格，那应使用 Grid。

反例：工单列表、筛选栏、详情栏需要共享列线和明确二维区域，不能靠多行 Flex 与 item width 拼成页面网格。

## 16. 常见失败清单

- 把所有 direct/descendant children 都当 flex items；
- 把 row 永远解释为左到右；
- 把 grow 当最终宽度比例，不看 basis；
- shrink 只按 factor 分配，不乘 base size；
- 计算自由空间时漏掉 gap、margin、padding/border；
- `flex-shrink:1` 仍溢出时不断增大 shrink，不看 auto min-size；
- 全局给所有 item `min-width:0`，却不处理内容可达性；
- grow 已吃完空间仍期待 justify-content 分布；
- 单行容器用 align-content 对 item 居中；
- 混淆 align-items 与 justify-items（后者在 Flex items 上没有普通 Grid 式作用）；
- 用 item margin 模拟统一 sibling gap；
- 用 order/reverse 修逻辑顺序，再用 tabindex 补丁；
- 把多行 Flex 当共享列轨道；
- 只看 viewport，不记录 container content box；
- 用离线算式声称真实浏览器、键盘和视觉 oracle 已通过。

## 17. 验收与证据边界

### explain

- 120 秒内讲清 container/item、轴、basis/grow/shrink、wrap、alignment、gap、order；
- 给出一个必须使用 Grid 的二维反例；
- 能解释自动最小尺寸为何让 shrink 看似失效。

### build

- 从空目录复现工具栏、卡片行、矩阵、命令与结果；
- 八个 taught topics 与盒模型 used topic 都有证据；
- 不同内容/容器宽度下主轴尺寸、换行、对齐与矩阵一致；
- DOM、visual、Tab order 不因 CSS 重排而分裂；
- 保存真实环境或明确未验证。

### diagnose

- min-size、shrink、order 故障能指出首个可信证据；
- 修复后重跑原 case，不更换判据；
- 说明 intrinsic content、字体、writing mode、浏览器舍入、可访问性等残余风险。

配套验证器只确认固定 px 子集、HTML/CSS 属性契约、布局预言、故障记录与真实证据 disclosure。它**没有**运行浏览器 flex algorithm、intrinsic sizing、字体、本地化、RTL、200% 缩放、Flex overlay、DOM focus navigation 或截图视觉差分。

## 18. 一手资料与核验记录

- [W3C CSS Flexible Box Layout Module Level 1](https://www.w3.org/TR/css-flexbox-1/)：容器/item、轴、换行、自动最小尺寸、伸缩算法、order 与对齐；核验于 2026-07-17。
- [W3C CSS Box Alignment Module Level 3](https://www.w3.org/TR/css-align-3/)：content/self alignment、auto margins、baseline、gap 与 overflow alignment；核验于 2026-07-17。
- [W3C CSS Box Sizing Module Level 3](https://www.w3.org/TR/css-sizing-3/)：min-content/max-content、intrinsic size contribution 与 min/max 边界；核验于 2026-07-17。

版本敏感提示：Flexbox 当前 TR 是 2025-10-14 Candidate Recommendation Draft；intrinsic sizing 修订、DevTools Flex UI、表单控件 baseline 与浏览器舍入会变化。生产结论应以目标浏览器版本和 WPT/真实任务复核；本章 stable core 是轴、line、flexibility、alignment 与顺序边界，而不是某个面板 UI。
