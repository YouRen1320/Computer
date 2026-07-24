---
schema_version: 2
edition: 2026.2-draft
id: ch.css.responsive-typography
title: 响应式单位、断点、排版与资源适配
responsibility: 组合流式尺寸、媒体/容器查询、可读排版和响应式资源形成内容驱动适配，不用设备型号堆砌断点。
volume: '07'
order: 11
level: L2
status: drafting
path: book/volume-07-web-platform/chapters/ch.css.responsive-typography.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.web.media-assets
- ch.css.flexbox
- ch.css.grid
version_surfaces:
- css
- html-living-standard
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
  text: 在 120 秒内解释“响应式单位、断点、排版与资源适配”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - css-responsive-layout
  - css-responsive-type-assets
  covers_topics:
  - css.relative-viewport-units
  - css.media-query
  - css.container-query
  - css.content-driven-breakpoint
  - css.flex-container
  - css.grid-container
  - css.typographic-scale
  - css.line-length-height
  - css.fluid-type
  - html.srcset-sizes
  - web.image-format-selection
  uses_capabilities:
  - web.css-flex-layout
  - web.css-grid-layout
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“响应式单位、断点、排版与资源适配”构建可运行程序与测试：把同一工单工作台适配到窄屏、宽屏和放大文本场景并保存矩阵证据；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - css-responsive-layout
  - css-responsive-type-assets
  covers_topics:
  - css.relative-viewport-units
  - css.media-query
  - css.container-query
  - css.content-driven-breakpoint
  - css.flex-container
  - css.grid-container
  - css.typographic-scale
  - css.line-length-height
  - css.fluid-type
  - html.srcset-sizes
  - web.image-format-selection
  uses_capabilities:
  - web.css-flex-layout
  - web.css-grid-layout
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: viewport-matrix-visual-regression-network-resource-check
- id: diagnose
  kind: fault-diagnosis
  text: 面对“硬编码断点、固定字号或错误 sizes 引起的溢出与资源浪费”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - css-responsive-layout
  - css-responsive-type-assets
  covers_topics:
  - css.relative-viewport-units
  - css.media-query
  - css.container-query
  - css.content-driven-breakpoint
  - css.flex-container
  - css.grid-container
  - css.typographic-scale
  - css.line-length-height
  - css.fluid-type
  - html.srcset-sizes
  - web.image-format-selection
  uses_capabilities:
  - web.css-flex-layout
  - web.css-grid-layout
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 响应式单位、断点、排版与资源适配

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《图片、响应式资源、音视频与资源边界》](ch.web.media-assets.md)：响应式页面必须能选择合适的图片候选和替代内容，而不是只缩放布局。
- [《Flexbox 一维布局》](ch.css.flexbox.md)：一维组件在内容变化时的伸缩和换行是响应式组合的基础。
- [《Grid 二维布局》](ch.css.grid.md)：二维区域和轨道适配是页面级断点策略的基础。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。2026-07-17 已核对 CSS Values and Units、Media Queries、CSS Containment 与 HTML Living Standard。配套离线检查器只验证明确声明的源码合同；它不会计算真实布局、浏览器资源选择、字体指标、缩放结果或视觉差分。真正验收必须在目标浏览器、视口、缩放和网络矩阵中完成。

响应式设计不是给“手机、平板、电脑”各复制一份页面，而是让同一语义内容在可用空间、文字偏好、输入方式和资源条件变化时仍可读、可操作。尺寸只是约束之一；长文本、翻译、放大字号、动态数据和嵌入容器往往比设备名称更能暴露问题。

## 1. 本章完成定义与边界

你需要把同一 FactoryCare 工单工作台适配到：

- 窄视口与宽视口；
- 组件位于主区和窄侧栏；
- 浏览器文字放大与较长中文/英文内容；
- 普通与高密度显示；
- 不同图片候选和网络条件；
- 横竖屏、动态浏览器 UI 和键盘出现；
- 鼠标、键盘与触控可操作。

通过标准是：没有非预期横向滚动，内容不被裁切，行长/行高可读，焦点仍可见，触控目标可用，浏览器按 `srcset/sizes` 合理选择资源。不是“截图看着差不多”。

本章不解决后端字段过长策略、业务信息优先级、完整设计系统或浏览器兼容基线制定；也不通过隐藏核心内容制造“适配成功”。

配套入口：

- [内容驱动工作台示例](../../../examples/encyclopedia/ch.css.responsive-typography/README.md)
- [溢出、固定字号与错误资源提示实验](../../../labs/encyclopedia/ch.css.responsive-typography/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.css.responsive-typography/README.md)

## 2. 从约束而不是设备型号开始

先列内容最小需求：工单号不能截断到不可辨认；状态要同时有文字；主操作需要可点击；描述需要可换行；表格在窄容器要转为列表或允许受控滚动；图片区需要保留比例；侧栏变窄时卡片应重排。

然后逐步缩小可用空间，直到布局第一次无法保持这些需求。这个“内容开始失败”的位置才是候选断点。它与某款手机宽度无直接关系，未来设备变化时也更稳定。

反例：

```css
/* 反例：设备名字被伪装成三个数字，内容变化仍会破坏布局。 */
@media (width: 375px) { /* iPhone */ }
@media (width: 768px) { /* tablet */ }
@media (width: 1440px) { /* desktop */ }
```

更好的问题是：“导航和主操作在多少可用 inline-size 下开始互相挤压？”“卡片字段在什么宽度下需要从双列变单列？”

## 3. CSS 长度：数值必须有参照系

### 3.1 绝对与相对

CSS `px` 是参考像素，不等于某个物理像素。它适合边框、图标基准等稳定值，但大量固定宽高会阻止内容增长。

- `%`：通常相对包含块或属性定义的参照；不同属性参照不一定相同；
- `em`：字体相关属性常相对父元素字体，其他属性通常相对当前元素字体；嵌套可能累积；
- `rem`：相对根元素字体，适合全局间距/字号基准；
- `ch`：基于所用字体“0”字形的 advance measure，适合作为近似文本度量，不等同“中文字符数”；
- `lh/rlh`：相对行高，可用于垂直节奏；
- `vw/vh`：相对视口尺寸；移动浏览器动态 UI 会让高度理解更复杂；
- `vi/vb`：相对逻辑 inline/block 轴；书写模式变化时比 width/height 更语义化；
- `svh/lvh/dvh`：分别表达小、大、动态视口概念；使用前按产品兼容基线验证；
- `cqw/cqi/...`：相对查询容器；没有合适查询容器时行为必须按规范和浏览器验证。

### 3.2 不要让单位承担业务语义

`100vw` 容器加页面滚动条、padding 或固定侧栏可能产生横向溢出；普通块级元素的 `width:auto` 往往更符合可用空间。`100vh` 在移动浏览器地址栏变化时可能遮挡底部操作，可根据需求使用 `min-block-size: 100dvh` 并保留安全降级。

`rem` 也不是自动可访问：如果根字体被强制写成较小像素或组件固定高度，用户放大后仍会裁切。单位选择和布局可增长必须一起验证。

## 4. 流式尺寸函数

### 4.1 `min()`、`max()` 与 `clamp()`

```css
.workspace {
  inline-size: min(100% - 2rem, 80rem);
  margin-inline: auto;
}

.title {
  /* 映射：下限保证小屏可读，上限避免宽屏标题无限增大。 */
  font-size: clamp(1.5rem, 1.1rem + 1.5vi, 2.5rem);
}
```

`clamp(min, preferred, max)` 把流式首选值限制在上下界。三个参数需要可比较；它不会自动保证对比度、换行或文字缩放。标题可以流式，正文通常保持稳定可读下限和舒适行高更重要。

### 4.2 `min-inline-size: 0`

Flex/Grid 子项默认最小尺寸可能由内容决定，长 URL、编号或 `white-space: nowrap` 会撑破容器。常见修复：

```css
.work-order-main {
  min-inline-size: 0;
}

.identifier {
  overflow-wrap: anywhere;
}
```

不要先用 `overflow:hidden` 把证据裁掉；先确认内容是否允许换行、滚动或缩略，并提供查看完整值的方式。

## 5. Media Query：查询视口与用户环境

媒体查询针对用户代理/显示环境，而不是组件本身：

```css
.workspace-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
}

@media (width >= 64rem) {
  .workspace-grid {
    grid-template-columns: minmax(0, 2fr) minmax(18rem, 1fr);
  }
}
```

移动优先不是“先做手机产品”，而是基础规则满足最受限布局，再在空间足够时增强。这样未支持查询或条件不满足时仍有可用基线。

### 5.1 常用查询维度

- `width/height/aspect-ratio`：当前视口或页面区域；
- `orientation`：几何关系，不代表设备类别；
- `hover/pointer/any-hover/any-pointer`：输入能力线索，不能假设永远不变；
- `prefers-reduced-motion`：用户希望减少非必要动效；
- `prefers-color-scheme`：亮暗偏好；
- `forced-colors`：受控颜色模式；
- `resolution`：输出分辨率特征，图片资源仍优先让浏览器选择。

不要用 hover 查询隐藏触控用户必须操作的按钮；设备可能同时有触屏与鼠标。核心操作始终可见，hover 只增强反馈。

### 5.2 范围与重叠

断点规则要避免同一宽度意外同时匹配相互冲突的布局。现代范围语法可表达 `(width >= 48rem)`，但兼容基线可能要求 `min-width` 写法。选择一种团队约定并用边界值矩阵验证：断点前 1px、断点、断点后 1px。

## 6. Container Query：组件根据所在容器适配

同一 `WorkOrderCard` 可能出现在主内容、侧栏或弹层。视口很宽但侧栏很窄，媒体查询无法知道组件实际空间。容器查询让后代查询祖先容器：

```css
.card-region {
  container: work-order / inline-size;
}

.work-order-card {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
}

@container work-order (inline-size >= 32rem) {
  .work-order-card {
    grid-template-columns: minmax(0, 1fr) auto;
    align-items: start;
  }
}
```

关键点：

1. size query 需要建立合适 `container-type`/shorthand；
2. 被查询的是祖先，不是元素自身；
3. 查询内样式应用于查询容器的后代，避免自我依赖循环；
4. 命名容器减少嵌套场景选错祖先；
5. `em` 等相对单位在容器查询条件中以查询容器计算值为参照；
6. containment 可能影响尺寸/布局，使用前观察真实 computed style。

Media Query 决定页面级结构与用户偏好；Container Query 决定可复用组件在局部空间中的结构。二者不是互相替代。

## 7. Flex 与 Grid 的响应式组合

### 7.1 Flex：操作组和一维流

```css
.actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
}

.actions > * {
  flex: 1 1 10rem;
}
```

不要用固定 margin 和 `width: 33.333%` 猜每行数量。`flex-basis` 表达舒适基准，wrap 让内容在空间不足时换行。主操作顺序应在 DOM 中正确；不要用 CSS `order` 创造与键盘/读屏顺序不一致的视觉顺序。

### 7.2 Grid：卡片和二维区域

```css
.summary-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 16rem), 1fr));
  gap: 1rem;
}
```

`min(100%, 16rem)` 防止最小轨道比窄容器还宽。`auto-fit/minmax` 可减少人为断点，但不是所有布局都适合自动填充：信息层级固定的工作台仍可能需要明确区域变化。

## 8. 排版是布局的一部分

### 8.1 字号尺度

建立有限语义层级：body、label、title、section heading、display。不要每个组件发明 15/17/19px。示例：

```css
:root {
  --font-body: 1rem;
  --font-label: 0.875rem;
  --font-title: clamp(1.5rem, 1.25rem + 1vi, 2rem);
  --line-body: 1.6;
}
```

UI 辅助文本小于正文时仍需对比和缩放验证。技能参考建议移动正文至少约 16px，这是常用设计基线而非 CSS 规范强制值；最终以用户、语言、字体和可访问性测试为准。

### 8.2 行长与行高

过长行让视线难以回到下一行，过短行导致频繁换行。正文容器可用 `max-inline-size: 65ch` 作为起点，再以实际中英文和字体观察。`ch` 不是精确字符计数；中文需要真实内容验证。

行高用无单位值可以随字体大小继承。按钮、标签、正文需要不同密度，但不能用固定高度裁切两行文字。文字放大到 200%、系统字体替换和翻译增长都要测试。

### 8.3 流式排版的风险

只用 `font-size: 5vw` 会在窄屏过小、宽屏过大；`clamp()` 提供上下限。若 preferred 项完全依赖 viewport，浏览器文字放大可能增幅不足，应让 `rem` 与相对视口项组合，并实际验证缩放。

## 9. 响应式图片：布局提示必须说真话

宽度描述符 `srcset` 配合 `sizes` 时，浏览器根据设备、网络和候选选择资源：

```html
<!-- 数据来源：同一故障照片的不同编码宽度；sizes 必须对应真实 CSS slot。 -->
<img
  src="pump-640.webp"
  srcset="pump-480.webp 480w, pump-960.webp 960w, pump-1440.webp 1440w"
  sizes="(width >= 64rem) 40vw, 100vw"
  width="1440"
  height="960"
  alt="泵体底部渗漏区域"
>
```

`sizes` 是资源选择提示，不会设置 CSS 宽度。若 CSS 实际 slot 在宽屏只有 33vw，却写 `100vw`，浏览器可能下载过大候选；若写太小，图片可能模糊。DevTools Network 中检查实际 `currentSrc`、传输大小、DPR 和 slot，不能只看文件名。

`<picture>` 适合格式协商或艺术裁切；不要用它为每个断点复制相同内容。图片保留 `width/height` 或 `aspect-ratio` 减少布局跳动，alt 描述仍按语义处理。

## 10. 断点矩阵怎么设计

不要只测 375、768、1440。矩阵至少包括：

| 维度 | 样例 |
|---|---|
| 视口 | 320、375、768、1024、1440；加每个断点前/中/后 |
| 容器 | 18rem 侧栏、32rem 卡片区、宽主区 |
| 缩放 | 100%、200%；浏览器/系统实际能力 |
| 内容 | 空、正常、极长编号、长单词、长中文、未知状态 |
| 方向 | 窄竖向、低高度横向 |
| 输入 | 键盘、鼠标、触控能力组合 |
| 资源 | 1x/2x、慢网、图片失败 |
| 偏好 | reduced motion、forced colors、dark/light |

每格记录：无横向滚动、焦点可见、内容完整、操作可达、资源候选合理、截图/DOM/Network 证据位置。截图适合视觉差异，但滚动宽度、computed style 和 `currentSrc` 是更具体的 oracle。

## 11. 避免横向滚动的诊断顺序

出现页面比视口宽时：

1. 在控制台比较根元素 `scrollWidth` 与 `clientWidth`；
2. 找出超出视口的具体元素边界；
3. 查看 computed width/min-width/white-space/transform；
4. 沿包含块追踪 `%`、`vw` 和 padding 参照；
5. 检查 Grid `minmax()`、Flex 自动最小尺寸和不可换行内容；
6. 修复根因后重跑全矩阵。

常见根因：`width:100vw` + padding、固定 600px 子项、长 token、表格、绝对定位、负 margin、transform、图片缺 `max-inline-size:100%`、Grid 使用 `1fr` 但子项最小内容过大。

`body { overflow-x:hidden }` 只会隐藏证据和焦点，不是默认修复。

## 12. 放大文字与裁切诊断

症状：按钮文字消失、卡片覆盖、固定底栏挡住内容。先检查固定 `height/line-height`、绝对定位、`white-space:nowrap` 和 `overflow:hidden`。让块随内容增长，用 `min-block-size` 替代固定高度，允许操作组换行，并给固定区域预留滚动内边距。

视觉上“一行更整齐”不优先于信息完整。必要截断必须提供可发现的完整内容访问方式；纯 `title` 对触控和键盘不可靠。

## 13. 错误 `sizes` 与资源浪费

诊断路径：

1. 确认实际渲染 slot 的 CSS 像素宽度；
2. 记录 DPR 与浏览器选择的 `currentSrc`；
3. 手工按 `sizes` 条件计算浏览器得到的 source size；
4. 对比候选宽度与实际需求；
5. 修正 `sizes` 后清缓存/禁用缓存重跑同一网络矩阵。

浏览器可以基于自身策略选择候选，因此 oracle 应关注候选是否与声明和需求合理，而不是强制每次选定唯一文件。节省字节不能以明显模糊为代价。

## 14. 内容优先并不等于全部堆在首屏

窄屏可以重新排列和渐进披露次要详情，但核心工单身份、状态、下一步与主操作必须可发现。折叠区使用语义按钮、`aria-expanded` 和关联区域；不要只用颜色/图标。长表格可选择卡片化、列优先级、受控横向滚动或详情钻取，依据任务而定。

来自 UI/UX 参考的本章实践：触控目标保持约 44×44 CSS px 起步、交互间距足够、移动正文约 16px 起步、焦点清晰、颜色不独自表达状态、固定栏不遮内容。这些是设计基线，不替代 WCAG 成功准则与产品实测。

## 15. 配套资产与证据限制

示例提供语义工作台 HTML/CSS，离线脚本检查：viewport meta 未禁用缩放、容器使用流式上限、卡片建立 inline-size query、排版有 rem 下限、图片提供 `srcset/sizes/width/height/alt`、没有用 `overflow-x:hidden` 掩盖问题。

实验注入：固定页面宽度、固定按钮高度、错误 `sizes=100vw`。公开练习故意保留这些问题，应稳定红灯；私有答案只证明源码合同可满足。

离线脚本不能证明：

- 浏览器是否支持/如何计算全部特性；
- 真实字体和语言是否换行良好；
- 是否有横向滚动或视觉重叠；
- 浏览器实际选择哪个图片候选；
- 200% 缩放、读屏、键盘和触控体验；
- Lighthouse/性能指标和真实网络成本。

真实验收要在浏览器中保存 viewport、DOM、computed style、Network/currentSrc、截图差分和无障碍检查证据。

## 16. 浏览器验收协议：把“看起来可以”变成可复现证据

先固定浏览器版本、操作系统、页面 commit、测试数据、缩放方式和缓存状态。每个矩阵格执行同一流程：设置视口/容器 → 注入指定内容 → 设置缩放/偏好 → 从页面顶部键盘遍历 → 执行主操作 → 检查滚动范围 → 查看图片 `currentSrc` 与传输字节 → 保存截图和异常。若改变一个变量，其他条件保持不变，才能比较结果。

### 16.1 横向溢出 oracle

记录文档根元素的 `scrollWidth` 与 `clientWidth`。两者相等通常表示没有页面级横向溢出，但不能证明内部滚动区、transform 或视觉覆盖正确。允许横向滚动的表格必须有可发现提示、键盘可进入、焦点不丢失，并只在明确容器内部滚动；不要把整个页面作为表格的滚动条。

还要检查焦点元素：Tab 到每个控件后，元素边界必须位于可视区域，固定头/底栏不得遮挡。单纯的滚动宽度数值不会发现焦点环被 `overflow:hidden` 裁切。

### 16.2 文字放大 oracle

在 200% 缩放下，不应丢失内容/功能或要求同时进行二维滚动（适用标准和例外应在项目无障碍基线中确认）。检查按钮、状态徽标、表头、弹层、固定底栏和错误消息；这些位置最容易使用固定高度。浏览器页面缩放、仅文字缩放、操作系统动态文字并非完全等价，目标产品支持哪一种就明确测哪一种。

长文本 fixture 不只重复字符。应包含无空格长 token、带连字符编号、中文、英文长单词、日期/数字、emoji/组合字形、从右到左文本和本地化后变长按钮。CSS 能换行不表示业务含义仍清楚，需人工阅读。

### 16.3 资源选择 oracle

禁用缓存或使用全新上下文，记录视口宽度、slot 宽度、DPR、`sizes` 计算分支、`currentSrc`、资源固有宽度和传输大小。浏览器的选择算法允许策略差异，不要把某个文件名写成跨浏览器唯一答案；判断候选是否明显过大/过小以及声明是否真实。

同一截图在高 DPR 下需要更多像素，但不意味着必须下载原图。编码格式、质量、裁切和显示尺寸共同决定成本；响应式布局与媒体资产章节要联合验收。

### 16.4 截图差分的边界

截图能发现错位、覆盖、字体变化和视觉回归，但字体渲染、平台抗锯齿、动态时间和动画会产生噪声。冻结数据/时间、关闭非必要动画、使用容差并人工查看差异。截图绿灯不能证明 DOM 顺序、键盘操作、alt、网络候选或读屏输出。

## 17. 特殊布局的响应式决策

### 17.1 数据表格

先确定用户任务：比较多行同一列时，保留表格和列对齐比卡片化更重要；只查看单条详情时，窄屏键值列表更合适。可以设置受控横向滚动、固定首列或按优先级隐藏次要列，但列标题、排序状态和完整数据访问必须保留。不要在 CSS 中根据位置选择器静默删除列而没有产品合同。

### 17.2 固定头部与底部操作

固定区域占据视口却脱离普通流，内容需要相应 `scroll-padding`/padding，并考虑安全区域、虚拟键盘和横屏低高度。操作栏换成两行时高度会变化，固定 `padding-bottom:64px` 可能失效；可避免固定、使用布局变量或在真实环境测量。键盘打开后 `dvh` 和 Visual Viewport 行为需目标浏览器验证。

### 17.3 侧栏与抽屉

宽屏侧栏变窄屏抽屉不仅是 `display:none`。需要触发按钮、焦点进入/恢复、Escape/关闭、背景交互约束、可访问名称和滚动策略。该交互属于组件/无障碍章节；本章只负责何时布局模式需要改变，并保证没有内容被永久隐藏。

### 17.4 打印与高对比模式

打印是另一个媒体环境：隐藏纯交互控件、保留工单身份、展开必要详情并避免颜色背景成为唯一信息。`forced-colors` 下浏览器可能替换颜色，边框、焦点和状态不要依赖精确品牌色。不要用 `forced-color-adjust:none` 大范围阻止用户配色，除非对特定图形有充分理由并验证。

## 18. 120 秒讲解模板

1. 响应式是内容在不同可用空间和用户偏好下仍可读可操作，不是设备型号表；
2. 相对单位必须解释参照系，`rem/%/vi/dvh` 不能机械替换；
3. `min/max/clamp` 提供流式值与上下界；
4. Media Query 查询视口/用户环境，Container Query 查询组件祖先容器；
5. Flex/Grid 负责一维/二维自适配，仍要处理最小内容尺寸；
6. 排版控制字号尺度、行高与行长，并验证文字放大；
7. `srcset/sizes` 是浏览器资源选择合同，sizes 必须匹配真实 CSS slot；
8. 证据包括 scrollWidth、computed style、currentSrc、网络字节和视觉矩阵；
9. 越界反例：后端错误返回无限字符串不应只靠 CSS 隐藏。

## 19. 自测题

1. `px` 为什么不等于物理像素？
2. `%`、`em`、`rem` 各自需要问哪个参照系？
3. 为什么 `100vw` 常比普通块 `auto` 更容易溢出？
4. `svh/lvh/dvh` 分别在表达什么视口概念？
5. `clamp()` 为什么仍需验证浏览器文字缩放？
6. 什么是内容驱动断点？
7. Media Query 与 Container Query 的职责差异是什么？
8. 为什么查询容器通常是组件的祖先？
9. Flex/Grid 子项的自动最小尺寸怎样造成溢出？
10. `ch` 为什么不是精确中文字符数？
11. `sizes` 是否会改变图片 CSS 宽度？
12. 怎样用 DevTools 验证响应式图片是否浪费？
13. 为什么 `overflow-x:hidden` 不是横向溢出的默认修复？
14. 断点为何要测前 1px、断点、后 1px？
15. 200% 文字缩放失败时首查哪些属性？

## 20. 官方资料

- [CSS Values and Units Level 4](https://www.w3.org/TR/css-values-4/)
- [Media Queries Level 5](https://www.w3.org/TR/mediaqueries-5/)
- [CSS Containment Level 3](https://www.w3.org/TR/css-contain-3/)
- [HTML Living Standard：Images](https://html.spec.whatwg.org/multipage/images.html)

其中部分文档仍处于草案阶段。规范定义和浏览器实现基线不是同一件事；课程讲稳定模型，实际项目仍须用目标浏览器与 Web Platform Tests/兼容数据确认。
