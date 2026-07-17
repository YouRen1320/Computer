---
schema_version: 2
edition: 2026.2-draft
id: ch.css.cascade
title: CSS 语法、选择器、层叠、优先级与继承
responsibility: 建立声明、选择器、来源、层叠层、优先级和继承的可计算规则，不在本章教授具体布局算法。
volume: '07'
order: 7
level: L1
status: drafting
path: book/volume-07-web-platform/chapters/ch.css.cascade.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.web.semantic-html
version_surfaces:
- css
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
  text: 在 120 秒内解释“CSS 语法、选择器、层叠、优先级与继承”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - css-syntax-selectors
  - css-cascade-inheritance
  covers_topics:
  - css.rule-declaration
  - css.selector-basic
  - css.selector-combinator
  - css.pseudo-class-element
  - css.cascade-origin-layer
  - css.specificity
  - css.source-order
  - css.inheritance-initial-unset
  uses_capabilities: []
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为同一语义页面编写冲突样式矩阵并逐项证明最终计算值；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - css-syntax-selectors
  - css-cascade-inheritance
  covers_topics:
  - css.rule-declaration
  - css.selector-basic
  - css.selector-combinator
  - css.pseudo-class-element
  - css.cascade-origin-layer
  - css.specificity
  - css.source-order
  - css.inheritance-initial-unset
  uses_capabilities: []
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: specificity-calculation-computed-style-inspection-visual-diff
- id: diagnose
  kind: fault-diagnosis
  text: 面对“优先级、继承或源码顺序误判造成的样式覆盖失败”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - css-syntax-selectors
  - css-cascade-inheritance
  covers_topics:
  - css.rule-declaration
  - css.selector-basic
  - css.selector-combinator
  - css.pseudo-class-element
  - css.cascade-origin-layer
  - css.specificity
  - css.source-order
  - css.inheritance-initial-unset
  uses_capabilities: []
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# CSS 语法、选择器、层叠、优先级与继承

> 本章状态为 `drafting`。配套工件用固定 HTML、CSS、冲突矩阵和离线 oracle 证明一个可审计的层叠子集；离线绿灯不等于真实浏览器的 `computed style` 或视觉差异已经验证。易变事实已于 **2026-07-17** 对照 W3C CSS Syntax Level 3、Selectors Level 4 与 CSS Cascading and Inheritance Level 5/6 一手规范核验。

CSS 最容易被误解成“后写覆盖先写”或“选择器分数大的赢”。这两句话只描述了完整决策树的末端片段。浏览器先解析声明、判断规则是否相关、匹配元素，再比较来源与重要性、层叠上下文/层、优先级和源码顺序；没有胜出声明时，才通过继承或初始值补齐指定值。若不先确定失败阶段，继续加类名、ID 或 `!important` 只会把局部故障变成长期维护问题。

本章建立一条可以手算、可以在 DevTools 逐项核对的证据链。它不教授盒模型尺寸、定位、Flexbox 或 Grid；“元素为什么匹配并得到某个属性值”属于本章，“这个值如何参与几何布局”属于后续章节。

## 1. 完成定义、边界与证据入口

完成本章，应能：

1. 把样式表分解为规则、选择器、声明、属性和值，并预测局部语法错误的恢复边界；
2. 使用类型、类、ID、属性、通配、组合器、伪类和伪元素描述目标，而不把 DOM 偶然层级写成脆弱契约；
3. 对同一元素、同一属性收集候选声明，按相关性、来源/重要性、层、优先级和源码顺序得出胜者；
4. 用三元组 `(A,B,C)` 手算常见选择器优先级，并正确处理 `:is()`、`:not()`、`:has()` 与 `:where()`；
5. 区分声明值、层叠值、指定值、计算值、使用值和实际值，不把 DevTools 显示文本当成全部内部阶段；
6. 区分继承属性与非继承属性，解释 `initial`、`inherit`、`unset`、`revert`、`revert-layer`；
7. 在 DevTools 的 Styles/Computed 中定位落选声明、继承来源和规则文件位置；
8. 注入优先级、继承或源码顺序误判，指出首个可信证据，修复后重跑同一矩阵。

配套入口：

- [层叠冲突矩阵示例](../../../examples/encyclopedia/ch.css.cascade/README.md)
- [层叠误判故障实验](../../../labs/encyclopedia/ch.css.cascade/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.css.cascade/README.md)

canonical oracle 是：**给定冲突规则时，手算结果与浏览器 computed style 一致，移除规则后差异可预测。** 配套 oracle 只验证固定数据模型、选择器权重和预期结果，没有启动浏览器；正式 G4 证据必须记录浏览器及版本、页面 URL、目标元素、伪状态、Styles/Computed 截图或导出、规则删除前后结果，并解释环境差异。

## 2. 从文本到最终值：先画全管线

```text
CSS 字节与编码
  → token 与规则/声明解析
  → 属性和值语法校验
  → 条件是否成立、选择器是否匹配
  → 为“元素 × 属性”收集声明值
  → cascade 选出层叠值
  → defaulting 得到指定值
  → 解析依赖得到计算值
  → 布局得到使用值
  → 设备约束得到实际值
```

这条管线给出诊断顺序：

- 规则根本没出现在 Styles：先查文件是否加载、语法块是否被吞掉、条件规则是否成立；
- 规则存在但选择器不匹配：查 DOM、属性、状态和组合器；
- 声明匹配却被划掉：查层叠排序，不先改布局；
- Computed 值正确但画面不对：进入盒模型、格式化、绘制或资源问题；
- 值来自父元素：查属性是否继承，以及父元素的**计算值**；
- `getComputedStyle()` 返回像素值：它在历史上可能暴露 resolved/used value，不能据此断言规范内部所有阶段相同。

“页面看起来对”不是足够证据。它可能只是另一个规则偶然补偿，也可能只在当前 DOM、视口或用户样式下成立。

## 3. 规则、声明与错误恢复

### 3.1 基本结构

普通样式规则由选择器前导和声明块组成：

```css
/* Responsibility: 给故障卡片标题设置可辨识的文本强调。 */
/* Data source: .fault-card 与 data-severity 来自语义 HTML 契约。 */
/* Mapping: high 严重度映射为强调色；不承载业务状态本身。 */
/* Side effects: 只改变呈现，不修改 DOM、工单或服务端数据。 */
.fault-card[data-severity="high"] > .fault-card__title {
  color: #9f1239;
  font-weight: 700;
}
```

`.fault-card[...] > ...` 是选择器；`color: #9f1239` 是声明；`color` 是属性，`#9f1239` 是值。分号分隔声明，最后一个声明虽常可省略分号，但统一保留能降低追加时的错误。`@media`、`@supports`、`@layer` 等是 at-rule，其块内容按各自语法解释，不能把所有花括号都当成声明列表。

CSS 解析器被设计为向前兼容：旧浏览器遇到新属性或无效声明通常忽略局部构造，继续处理后续内容。它不是“整个文件一处报错就停止”，也不是“任何拼写都会自动纠正”。例如：

```css
.notice {
  color: navy;
  colr: red;          /* 未知属性：该声明无效。 */
  padding: 8qu;       /* 对 padding 无效的单位：该声明无效。 */
  background: white;  /* 后续合法声明仍可生效。 */
}
```

缺失右花括号、字符串或函数括号时，恢复范围可能跨越比预想更大的区域。可靠证据是浏览器 CSSOM/Styles 是否保留规则和声明、控制台/编辑器解析诊断，而不是肉眼猜测。构建工具是否把未知语法报成错误，是工具策略，不改变浏览器规范的基本恢复模型。

### 3.2 无效的不同时间点

至少区分三类：

1. **语法/属性语法无效**：解析或按属性 grammar 校验时被忽略；
2. **条件不相关**：合法规则位于不匹配的媒体/支持条件中，本次不进入候选；
3. **计算值阶段无效**：某些依赖（最典型是自定义属性替换）到计算阶段才暴露无效，回退行为不能用“上一条声明自然接管”一概而论。

本章不展开自定义属性，但要保留这条边界：看到声明存在，不代表它一定产生预期计算值；看到后一条无效，也不总能假设前一条再次成为层叠胜者。

### 3.3 简写与长写

简写会按定义展开并设置其所有长写子属性，未显式提供的部分通常回到相应初始值：

```css
.panel {
  background-image: url("texture.svg");
  background: white; /* 同时把 background-image 重置为 none。 */
}
```

因此“background-color 没被写过”并不证明它没被覆盖；DevTools 展开简写后才看得到真实候选。给简写加 `!important` 等价于给其所有长写加重要标记。排查时应比较实际长写属性，而不是只按源码文本名字搜索。

## 4. 选择器：匹配契约，而不是造分数

### 4.1 基本选择器与复合选择器

- 类型选择器 `button` 匹配该元素类型；
- 类选择器 `.action` 匹配 class token，而非任意子串；
- ID 选择器 `#save` 匹配 ID；页面仍应保持 ID 唯一；
- 属性选择器 `[disabled]` 查存在性，`[data-state="open"]` 查值；不同操作符还有词、前缀、后缀等语义；
- 通配选择器 `*` 不增加优先级；
- `button.action[aria-pressed="true"]` 是多个简单选择器组成的复合选择器，要求同一元素同时满足。

选择器是 DOM 契约。若业务状态仅存在 JavaScript 内存而没有反映到 DOM 属性，CSS 无法凭空匹配；若把文字“高风险”当作状态来源，CSS 也不能用普通选择器可靠读出文本。应由语义 HTML/组件把呈现所需状态暴露为稳定 class、data/ARIA 属性，再由 CSS 映射。

避免以 `#app > div:nth-child(2) > div...` 绑定偶然结构。它会在插入说明元素后失效，也把组件职责扩散到页面骨架。更可维护的契约常是低优先级组件类加有限状态属性。

### 4.2 组合器

组合器描述元素之间的关系：

| 写法 | 关系 | 典型误判 |
| --- | --- | --- |
| `.card .title` | 任意深度后代 | 会命中嵌套子组件的同名 title |
| `.card > .title` | 直接子元素 | DOM 多一层包装就不再匹配 |
| `.label + .help` | 紧邻后续兄弟 | 中间插入元素会断开 |
| `.label ~ .help` | 同父级、其后的兄弟 | 不会命中前方或不同父级元素 |

空格也是语法。`.card.active` 表示同一元素同时有两个 class；`.card .active` 表示 `.card` 内某个后代，两者不能互换。组合器本身不增加 `(A,B,C)` 计数，但其两侧简单选择器会增加。

选择器匹配是逻辑结果；“浏览器一定从右向左实现”不是作者可依赖的规范契约。性能优化应以目标浏览器剖析和真实页面规模为证据，优先先解决过度匹配与维护风险。

### 4.3 伪类与伪元素

伪类选择元素在某个状态或结构关系下的实例，如 `:hover`、`:focus-visible`、`:checked`、`:disabled`、`:first-child`、`:nth-child()`。它们计入 B 类。状态常受输入设备、焦点来源、历史和浏览器策略影响；测试 `:focus-visible` 必须记录键盘/指针路径，不能只在静态 DOM 上声称通过。

伪元素选择元素未直接作为普通 DOM 元素表示的部分或生成框，如 `::before`、`::after`、`::first-line`。伪元素计入 C 类。用 `::before { content: "危险" }` 生成关键业务信息很脆弱：它不改变源数据和 DOM 文本，可访问性/复制/翻译/打印行为也需单独验证。伪元素适合装饰和已有语义的视觉补充，不是语义 HTML 的替代品。

`:nth-child()` 按兄弟序列计算，不按“视觉上的第几个卡片”猜测。隐藏、不同类型兄弟和 `of <selector>` 参数都会影响结果；动态列表若用位置表达业务状态，重排后会产生错误映射。

## 5. 层叠：固定顺序的比较器

对某个**元素 × 属性**，推荐用下面的工作算法：

1. 收集语法合法、属性适用的声明；
2. 过滤不相关条件和不匹配选择器；
3. 比较来源与重要性（也包括过渡/动画的规范位置）；
4. 在同一来源/重要性范围内比较封装上下文与 cascade layer；
5. 比较 style attribute 与选择器优先级；
6. 若使用 `@scope`，规范还会比较 scope proximity；本章工件不覆盖它；
7. 最后比较出现顺序。

不要跳到第 5 步。高优先级 author normal 规则不能击败更高层叠等级的 user `!important`；后写的低层普通规则也不能击败未分层普通规则。

### 5.1 来源与重要性

常见来源是 user-agent、user、author。对普通声明，作者规则通常在用户规则和 UA 默认之上；对 important 声明，来源顺序反转，以保护用户的重要覆盖。过渡值、重要声明和动画值在完整表中还有特定位置。因此 `!important` 不是“优先级加一万”，而是先进入不同的层叠等级，再在该等级内继续比较层与优先级。

用户样式可能用于大字体、高对比或其他可访问需求。作者不应用成片 `!important` 与之对抗。浏览器 UA 样式解释了为何没有作者 CSS 时标题仍粗、列表仍有标记；`initial` 取属性规范初始值，不等于“恢复浏览器对这个 HTML 元素的默认样式”。

### 5.2 cascade layers

层把来源内部的规则组织成明确顺序：

```css
@layer reset, base, components, utilities;

@layer components {
  .button { color: navy; }
}

@layer utilities {
  .text-danger { color: firebrick; }
}
```

对同一来源的**普通**声明，后面的层胜过前面的层；未分层的普通样式位于所有层之上。对 **important** 声明，层顺序反转，早期层的重要声明更强，这使底层保护性约束不被后层轻易击穿。层顺序在首次声明时建立，不会因为随后把同名层块写到文件末尾就重新排序。

层解决的是架构顺序，不改变选择器优先级数值。先比较层，只有同层候选才需要比较 specificity。把第三方 CSS 放入低优先级层，往往比给覆盖规则堆 ID 更清晰；但若一部分第三方规则未分层，它仍可能压过所有分层普通规则，必须从 Styles 证据确认。

匿名层、嵌套层、`@import ... layer()` 有更完整的排序规则。初学实验固定命名顶层层，不把简化 oracle 冒充完整 CSS 实现。

## 6. specificity：三元组逐位比较

Selectors Level 4 的核心计数是：

- A：ID 选择器数量；
- B：类、属性、伪类数量；
- C：类型选择器、伪元素数量；
- 通配和组合器不计数。

按 A、B、C 从左到右逐位比较，不做十进制换算；再多 class 也不会“进位”成一个 ID。例子：

| 选择器 | `(A,B,C)` | 说明 |
| --- | --- | --- |
| `*` | `(0,0,0)` | 通配不计 |
| `button` | `(0,0,1)` | 一个类型 |
| `.button:hover` | `(0,2,0)` | class 与伪类 |
| `[data-state="open"] .icon` | `(0,2,0)` | 属性与 class |
| `#dialog .button` | `(1,1,0)` | ID 先决定胜负 |
| `button::before` | `(0,0,2)` | 类型与伪元素 |

style attribute 参与作者来源中的特殊优先比较，通常高于普通 style rule；不要把它硬塞进三元组写成 `(1,0,0,0)` 后再误当 Selectors 规范算法。`!important` 也不属于 specificity。

函数伪类是高频陷阱：

- `:is()`、`:not()`、`:has()` 本身不额外加一个伪类权重，其 specificity 由参数中最具体的复杂选择器替换；
- `:where()` 及其参数的 specificity 固定为 `(0,0,0)`，适合写可轻易覆盖的边界；
- `:nth-child(An+B of S)` 包含伪类本身的 B，再加参数 S 中最具体选择器；
- 对选择器列表，应针对实际匹配元素计算相应分支，不能只看最短文字。

```css
:where(.inspection-panel, #legacy-panel) .title { color: navy; }
/* (0,1,0)：:where(...) 为零，只剩 .title。 */

:is(.inspection-panel, #legacy-panel) .title { color: maroon; }
/* 对匹配目标按最具体参数，得到 (1,1,0)。 */
```

工程上，低 specificity 不是目的本身；目标是权重可预测、覆盖边界明确。若为覆盖组件必须复制长选择器或引入 ID，先查它是否放错 layer、状态契约是否缺失、DOM 是否过度耦合。

## 7. 源码顺序：最后的决胜条件

只有此前所有条件相等，出现更后的声明才胜出：

```css
.status { color: navy; }
.status { color: firebrick; } /* 同来源、同层、同权重，后者胜。 */
```

“出现顺序”不总等于你正在看的文件行号。`@import`、构建产物拼接、重复加载、CSS-in-JS 注入、同名层分散声明、style attribute 都会改变实际顺序。可信证据是浏览器加载后的 Styles/CSSOM 与 Network initiator，而非源码仓库单文件的直觉。

选择器列表中的每个复杂选择器独立匹配与计权；同一规则若多个分支命中，规范会采用适用的 specificity。简写展开后，各长写按该声明的位置参与。动画和过渡也不是“源码末尾”，需先归到正确层叠等级。

删除规则实验很有效：先记录当前胜者和所有落选者，禁用胜者，预测下一候选，再观察。若结果不是预测值，说明候选清单不完整、条件/伪状态变化，或默认/继承路径被误判。

## 8. 继承与默认：没有声明不等于没有值

每个属性在每个元素上最终都要有指定值。若没有层叠值：继承属性取父元素计算值，非继承属性取规范初始值。`color`、许多字体属性通常继承；`border`、`margin`、`background` 通常不继承。必须查属性定义，不能凭“看起来像会继承”猜。

继承是从父元素传递**计算值**，不是从祖先中寻找“最近一条匹配当前子元素的规则”。子元素上的直接声明无论选择器权重多低，通常也会作为子元素自己的层叠值，压过从父元素来的继承值；父规则的高 specificity 不会跨元素与子规则竞争。

```css
#app { color: navy; }       /* 父元素高权重，但这里只决定父元素。 */
.label { color: firebrick; } /* 子元素自己的声明胜过继承。 */
```

CSS-wide keywords：

- `initial`：使用属性规范定义的初始值，不是 UA 对某个标签的默认规则；
- `inherit`：显式使用父元素的计算值，即使该属性通常不继承；
- `unset`：若属性自然继承则等同 `inherit`，否则等同 `initial`；
- `revert`：回滚当前来源在层叠中的贡献，让更低来源/上下文继续决定；
- `revert-layer`：回滚当前 layer 的贡献，让当前来源内较低层或更低来源继续决定。

`all` 简写可给多数属性应用这些 CSS-wide keyword，但不重置 `direction`、`unicode-bidi`，也不重置自定义属性。`all: initial` 会连 UA 常见的元素 display 表现一起绕过，不能当“安全 CSS reset”。

根元素没有普通父元素，其继承处理有专门规则。伪元素也有自己的属性值处理。课程矩阵固定普通元素父子关系，遇到根、shadow tree、伪元素或自定义属性时必须回到对应规范与浏览器证据。

## 9. DevTools：从首个可信证据诊断

建议固定以下过程，而不是边试边加权重：

1. 在 Elements 选中准确 DOM 节点，记录稳定 selector/path 与当前状态；
2. 在 Styles 搜目标**长写属性**，确认规则是否匹配、是否被划掉、来自哪个文件/行/层；
3. 展开 shorthand，查看 inherited sections 与伪元素规则；
4. 在 Computed 搜属性，展开来源，记录浏览器实际暴露的 resolved value；
5. 写下候选表：值、来源、important、layer、specificity、order；
6. 手算胜者；禁用一条规则前先预测下一胜者；
7. 禁用/删除规则并观察差异；恢复后用最小修复重跑；
8. 若值正确而渲染仍错，停止修改层叠，移交后续布局/绘制诊断。

一个可复核候选表：

| candidate | relevant | origin/importance | layer | specificity | order | result |
| --- | --- | --- | --- | --- | --- | --- |
| `.button` navy | yes | author normal | components | `(0,1,0)` | 1 | 落选：层较早 |
| `.text-danger` firebrick | yes | author normal | utilities | `(0,1,0)` | 2 | 胜出 |
| `#app .button` green | yes | author normal | base | `(1,1,0)` | 3 | 落选：先比较层 |

DevTools 的“划掉”只说明该声明未成为当前目标属性的有效胜者，原因可能是被覆盖、无效、属性不适用等；悬停/提示和 Computed 来源比颜色直觉更可信。不同浏览器 UI 文案会变化，报告要写浏览器版本，不把面板位置当稳定 API。

## 10. 三类注入故障

### 10.1 优先级误判

症状：认为十个 class 会“超过”一个 ID，或把 `!important` 当 specificity。首个证据是完整候选的来源/层/important 与 `(A,B,C)`，不是继续拼接 class。

修复优先级：先纠正 layer/来源架构，再给组件暴露明确状态契约，最后才考虑局部增加权重。删除不必要 ID、用 `:where()` 降低边界权重，通常比新一轮 `!important` 更可维护。

### 10.2 继承误判

症状：父元素 `#app { color: ... }` 看似很强，却没有覆盖子元素 `.label`。首个证据是两条声明属于不同元素：子元素自己的层叠值先成立，继承只在没有相应层叠值时补位。

修复可选择删除子声明、把状态直接映射给子元素、或明确 `color: inherit`；不要给父规则加更多 ID。

### 10.3 源码顺序误判

症状：仓库里“后写”的文件却落选。首个证据是浏览器实际加载/注入顺序和 layer 顺序。检查重复 bundle、条件加载、动态 style 标签与 `@import`，再修复入口顺序或层声明。仅移动源码文件但构建产物顺序不变，不构成修复。

每次故障记录至少包含：注入差异、预期错误、实际首个证据、候选表、根因、最小修复、原命令重跑、残余风险。只保存最终截图会丢失诊断能力证据。

## 11. 独立构建任务

从空目录构建一个语义明确的“设备告警卡片”页面，不复制示例：

1. HTML 包含普通卡片、紧急状态卡片、嵌套卡片和一个禁用操作；
2. CSS 明确声明 `reset/base/components/utilities` 层顺序；
3. 至少覆盖基本选择器、四种组合器中的三种、状态伪类、结构伪类与一个装饰伪元素；
4. 为 `color` 与一个非继承属性分别构造来源/层/权重/顺序冲突；
5. 手写不少于六行矩阵，给出 `(A,B,C)`、胜者和禁用胜者后的下一值；
6. 在目标浏览器逐行记录 Styles/Computed，保存版本和页面条件；
7. 注入一次 selector overreach，让嵌套卡片误中，再缩小选择器边界；
8. 注入一次层叠误判，指出首个证据，修复后重跑同一检查。

通过条件不是“颜色差不多”，而是关键断言、预期输出与目标浏览器观察一致；任何未做的真实浏览器步骤必须标为 unverified。

## 12. 120 秒讲回模板

可以按下面顺序讲：

> CSS 先解析规则和声明，再判断条件与选择器是否匹配。对同一元素的同一属性，层叠先比较来源与 important，再比较 layer，然后才是 specificity，完全相等才看源码顺序。specificity 是 ID、class/属性/伪类、类型/伪元素三元组逐位比较，`!important` 不在其中。没有层叠值时，继承属性取父元素计算值，其他属性取初始值，也可用 `initial`、`inherit`、`unset`、`revert`、`revert-layer` 显式控制。证据来自 Styles 候选和 Computed 结果，禁用胜者前应能预测下一值。本章不解决盒模型或 Flex/Grid；若 computed value 正确而几何错误，应进入布局章节。

反例：按钮宽度在窄屏溢出，即使已确认 `width` 与 `padding` 的 computed value 正确，也不能再靠提高选择器权重解释；那是盒模型/布局边界。

## 13. 常见失败清单

- 只记“ID 大于 class”，不先比较 origin/layer；
- 把 `!important` 当成 specificity 数字；
- 把 inline style、动画或过渡当普通源码规则；
- 认为后写一定胜，不核对打包/注入与层顺序；
- 用长后代链修 selector overreach，反而绑定更多 DOM 偶然结构；
- 把 `:where()` 与 `:is()` 权重当成相同；
- 把伪元素生成文字当作语义数据；
- 认为父元素选择器权重能与子元素自己的声明直接竞争；
- 把 `initial` 当成“标签默认样式”，把 `unset` 当成固定清空；
- 只看 Styles，不看 Computed；或只看 Computed，不保存落选候选；
- 用离线字符串 oracle 声称浏览器计算值和视觉差分已验证；
- computed value 已正确仍不断加选择器，而不转交布局/绘制诊断。

## 14. 验收清单与证据边界

### explain

- 120 秒内说清语法、匹配、层叠、默认/继承和值阶段；
- 正确解释来源/important、layer、specificity、order 的顺序；
- 给出一个布局问题作为本章反例。

### build

- 从空目录复现语义 HTML、CSS、冲突矩阵和验证命令；
- 八个 canonical topics 均有对应代码或解释证据；
- 手算与目标浏览器 computed style 逐项一致；
- 禁用胜者后，下一候选和值与预测一致；
- 不复制私有答案，保存输入、工件、环境和结果。

### diagnose

- 对优先级、继承或顺序故障指出首个可信证据；
- 修复 selector overreach 或 cascade misdiagnosis，而非用 `!important` 掩盖；
- 重跑原验证，说明 shadow DOM、`@scope`、动画/过渡、自定义属性或浏览器差异等残余风险。

本章配套验证器确认文件契约、固定 specificity 计算、层/来源排序、继承预言和故障记录。它**没有**验证真实 CSS parser、选择器匹配引擎、用户样式、动画/过渡、shadow tree、`@scope`、浏览器 computed style 或像素视觉差分。这些是真实 G4 证据的刻意非目标，而不是已经通过的项目。

## 15. 一手资料与核验记录

- [W3C CSS Syntax Module Level 3](https://www.w3.org/TR/css-syntax-3/)：规则/声明结构、tokenization、解析与错误恢复；核验于 2026-07-17。
- [W3C Selectors Level 4](https://www.w3.org/TR/selectors-4/)：基本/关系选择器、伪类、伪元素与 specificity；核验于 2026-07-17。
- [W3C CSS Cascading and Inheritance Level 5](https://www.w3.org/TR/css-cascade-5/)：值阶段、来源、important、layers、继承与 CSS-wide keywords；核验于 2026-07-17。
- [W3C CSS Cascading and Inheritance Level 6](https://www.w3.org/TR/css-cascade-6/)：后续层叠与 scope proximity 演进；该文档明确仍是基于 Level 5 的差异草案，本章不把 Level 6 草案当稳定实现保证；核验于 2026-07-17。

版本敏感提示：`:has()`、嵌套选择器、`@scope`、层面板 UI 和 DevTools 解释文本会随浏览器变化。写生产兼容性结论前，应以目标浏览器版本、其官方兼容数据或 Web Platform Tests 复核；本章只把跨版本稳定的核心算法设为 stable core。
