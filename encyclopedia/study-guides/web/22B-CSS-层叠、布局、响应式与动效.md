# CSS：层叠、布局、响应式与动效

## 1. CSS 是一组会互相竞争的样式规则

```css
.work-order-card {
  padding: 1rem;
  border: 1px solid #d0d5dd;
}
```

选择器决定匹配哪些元素，声明决定属性和值。一个元素常同时被多条规则匹配，浏览器需要按来源、层、重要性、选择器优先级和出现顺序决定最终值，这套过程叫**层叠（cascade）**。

## 2. 选择器应表达稳定结构，不依赖偶然位置

常见选择器：

```css
button { }                    /* 类型 */
.button { }                   /* 类 */
#submit { }                   /* id */
[aria-invalid="true"] { }     /* 属性 */
.card > .title { }            /* 直接子元素 */
.list .item { }               /* 后代 */
.button:hover { }             /* 伪类 */
.field::before { }            /* 伪元素 */
```

样式通常优先用可复用 class。深层结构选择器如 `.page main div:nth-child(3)` 很脆弱，DOM 稍改就失效。

## 3. 层叠先看规则来源和重要性

简化理解：

1. 不同来源和 `!important` 级别；
2. cascade layer 顺序；
3. specificity（选择器优先级）；
4. 同优先级时后出现者胜出。

不要只用“谁写在后面谁赢”解释全部 CSS，也不要遇到覆盖问题就加 `!important`。先在 DevTools 的 Computed/Styles 面板看哪条规则被划掉以及原因。

## 4. 选择器优先级不是十进制分数游戏

大致比较类别：

```text
内联样式
  > ID 选择器
  > class / 属性 / 伪类
  > 元素 / 伪元素
```

类别从高到低逐级比较，不是简单把数字拼起来。`!important` 又在另一层级处理。

保持选择器短、组件规则一致，比背“分数”更能避免覆盖战争。

## 5. Cascade Layers 可以明确不同样式来源顺序

```css
@layer reset, base, components, utilities;

@layer components {
  .button { /* ... */ }
}
```

层可以让 reset、第三方库、组件和工具类按预定顺序竞争，减少靠高优先级压制。层内仍有正常的 specificity 和源码顺序。

是否使用要看项目规模；小项目先保持规则简单，不必为术语创建复杂体系。

## 6. 继承把部分属性从父元素传给子元素

字体、文字颜色等常继承；margin、border、width 通常不继承。

```css
body {
  color: #1d2939;
  font-family: system-ui, sans-serif;
}
```

子元素若没有自己的 `color`，会继承。可用 `inherit`、`initial`、`unset`、`revert` 等关键字精确控制，但先在 DevTools 确认属性究竟来自继承还是匹配规则。

## 7. 每个元素都可以看成一个盒子

盒模型从内到外：

```text
content → padding → border → margin
```

默认 `box-sizing: content-box` 下，声明 width 只算 content。项目常使用：

```css
*, *::before, *::after {
  box-sizing: border-box;
}
```

这样 width 通常包含 padding 和 border，更容易估算组件总尺寸。

## 8. Margin、padding 和 gap 用途不同

- padding：组件内容到自身边界的内部空间；
- margin：元素与外界的外部空间；
- gap：Flex/Grid 容器中相邻项目间距。

组件内部布局优先由容器 `gap` 控制，能避免首尾项特殊清零。垂直 margin 在普通流中可能发生合并，出现“为什么间距不像相加”的现象。

## 9. display 决定元素参与哪种布局

常见值：

- `block`：占据普通流中的块级区域；
- `inline`：随文字行排列，宽高行为受限；
- `inline-block`：在行中，但可设置盒尺寸；
- `flex`：一维布局容器；
- `grid`：二维布局容器；
- `none`：不生成布局盒，通常也不进入无障碍树。

HTML 的默认 display 与语义不同。把 `button` 设为 `display:block` 不会让它失去按钮语义。

## 10. 普通文档流应该是布局起点

块元素从上到下，行内内容在行内排布。很多页面无需定位就能完成。

过早使用 `position:absolute` 会让元素脱离普通流，父容器可能不知道其高度，文本变长或屏幕变窄时容易重叠。

先让内容在普通流中可读，再用 Flex/Grid 组织关系，最后才为真正叠加的局部元素使用定位。

## 11. position 有不同参照和滚动行为

- `static`：默认普通流；
- `relative`：保留原位置，并可成为绝对定位参照；
- `absolute`：相对最近定位祖先定位并脱离普通流；
- `fixed`：通常相对视口固定；
- `sticky`：在滚动容器内跨过阈值后粘住。

`sticky` 不生效常因滚动祖先、容器高度、overflow 或缺少 `top` 等阈值，不是简单提高 z-index。

## 12. z-index 只在层叠上下文中比较

某些属性会创建新的 stacking context（层叠上下文），例如定位加 z-index、transform、opacity 等。子元素再大的 z-index 也无法跳出父上下文压过另一个外部上下文。

```text
上下文 A z=1
  └── 子元素 z=9999
上下文 B z=2

B 整体仍可能在 A 上方
```

排查遮挡时看上下文树，不要不断把数值加到百万。

## 13. Flexbox 解决一条主轴上的排列

```css
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: .75rem;
}
```

Flex 有主轴和交叉轴。`flex-direction` 决定主轴；`justify-content` 沿主轴分配；`align-items` 沿交叉轴对齐。

它适合工具栏、按钮组、导航和单行/单列卡片。需要同时控制明确行列时用 Grid 更自然。

## 14. flex-basis、grow 和 shrink 共同决定尺寸

```css
.main { flex: 1 1 30rem; }
.side { flex: 0 1 18rem; }
```

简写可理解为：

- grow：有剩余空间时是否增长；
- shrink：空间不足时是否收缩；
- basis：分配前的基础尺寸。

Flex 子项常有隐含最小内容宽度，长文本使它不愿收缩。给应收缩的子项设置 `min-width: 0` 是常见修复，但要确认内容溢出策略。

## 15. flex-wrap 让项目换行，但不保证二维对齐

```css
.chips {
  display: flex;
  flex-wrap: wrap;
  gap: .5rem;
}
```

每一行独立分配空间，所以跨行列不一定整齐。若卡片需要严格列线对齐，Grid 通常更合适。

不要为了让换行好看固定每项像素宽度，优先使用可伸缩 basis 和容器范围。

## 16. Grid 同时控制行和列

```css
.dashboard {
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  gap: 1rem;
}

.main { grid-column: span 8; }
.aside { grid-column: span 4; }
```

Grid 适合仪表盘、表单行、卡片矩阵和页面大区域。`fr` 分配剩余空间，`minmax(0, 1fr)` 可避免长内容把轨道撑破。

## 17. auto-fit 和 minmax 可减少机械断点

```css
.cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(18rem, 100%), 1fr));
  gap: 1rem;
}
```

容器能放几列就放几列，每列不小于合理宽度。内容驱动布局往往比为每种设备写一个固定断点更稳。

断点仍有用途，但应在布局真正失效的位置增加，而不是按流行设备型号列表堆叠。

## 18. 响应式设计让内容适应可用空间

三个基础：

- 流式尺寸：百分比、fr、min/max/clamp；
- 弹性媒体：`max-width: 100%` 等；
- 媒体或容器查询：在边界处改变布局。

```css
.page {
  width: min(100% - 2rem, 72rem);
  margin-inline: auto;
}
```

这表示窄屏留 1rem 边距，宽屏最大 72rem，而不是整页固定 1200px。

## 19. 常用单位有不同参照

- `px`：CSS 像素，适合边框和精细最小值；
- `%`：相对包含块或属性定义；
- `rem`：相对根字体，适合全局尺度；
- `em`：相对当前元素字体，适合组件局部比例；
- `vw/vh` 及动态视口单位：相对视口；
- `ch`：大致相对“0”字符宽度，适合限制文本行长；
- `fr`：Grid 剩余空间份额。

没有“全项目只能用 rem”的规则。选能表达设计关系的单位。

## 20. clamp 可以表达有上下限的流式值

```css
h1 {
  font-size: clamp(1.75rem, 1.2rem + 2vw, 3rem);
}
```

它表示最小 1.75rem，中间随视口变化，最大 3rem。适合字号、间距和容器尺寸，但中间公式要在真实宽度下检查，不能只因语法漂亮就使用。

## 21. 排版不只是字体大小

可读性还受：

- 行高；
- 行长；
- 字重和对比；
- 中文与英文 fallback；
- 数字对齐；
- 字体加载；
- 用户缩放。

正文行长通常应有限制，不能在超宽屏从左拉到右。不要用固定高度截断用户放大后的文字。

Web Font 要定义合理 fallback，并控制文件子集、预加载和显示策略，避免长时间空白或严重布局跳动。

## 22. 媒体查询按用户/设备条件改变样式

```css
@media (min-width: 48rem) {
  .layout { grid-template-columns: 2fr 1fr; }
}
```

移动优先通常先写窄屏基本样式，再在空间足够时增强。也可以查询：

- `prefers-reduced-motion`；
- `prefers-color-scheme`；
- `forced-colors`；
- hover/pointer 能力；
- 对比偏好（支持情况需查询）。

不要用屏幕宽度推断用户是否有鼠标或触摸屏。

## 23. 容器查询按组件可用空间适配

组件可能在主栏很宽、侧栏很窄，仅看视口宽度无法判断。容器查询让组件根据父容器尺寸调整：

```css
.panel { container-type: inline-size; }

@container (min-width: 30rem) {
  .card { grid-template-columns: 8rem 1fr; }
}
```

适合复用组件。它不取代所有媒体查询：页面级导航、用户偏好仍常由 media query 控制。

## 24. CSS 自定义属性保存可继承的设计值

```css
:root {
  --color-surface: #fff;
  --color-text: #182230;
  --space-3: .75rem;
}

.card {
  color: var(--color-text);
  background: var(--color-surface);
  padding: var(--space-3);
}
```

Custom Property 在运行时参与层叠和继承，适合主题与组件 token。它不是 Sass 变量的简单同义词。

变量名优先表达用途如 `--color-danger-text`，而不是把每个颜色都叫 `--red-500` 后到处猜语义。

## 25. 主题必须同时保持对比和原生控件一致

可以通过属性或用户偏好切换：

```css
[data-theme="dark"] {
  --color-surface: #101828;
  --color-text: #f2f4f7;
  color-scheme: dark;
}
```

主题不仅换背景，要检查文本、边框、焦点、错误、图表、图片、阴影和 disabled 状态。`color-scheme` 可提示浏览器用匹配的原生控件和滚动条。

用户明确选择通常应覆盖系统自动偏好，并稳定保存。

## 26. transition 用于两个状态间平滑变化

```css
.button {
  transition: background-color 150ms ease, transform 150ms ease;
}

.button:hover {
  transform: translateY(-1px);
}
```

不要写 `transition: all`，它可能把尺寸和布局属性也动画化，难以预测。明确列出属性和时长。

动效应帮助用户理解状态变化，不是为了每个点击都增加等待。

## 27. transform 和 opacity 通常更容易合成

改变 width、height、top、left 可能触发布局和绘制；`transform`、`opacity` 经常能由合成阶段处理，动画更平滑。

但“通常”不是保证。大量大图层、模糊滤镜和过度 `will-change` 会消耗显存。用 Performance/Layers 工具验证，不要机械把所有元素提升为图层。

## 28. keyframes 描述多阶段动画

```css
@keyframes pulse-status {
  0%, 100% { opacity: 1; }
  50% { opacity: .55; }
}
```

动画要有停止条件，不能让非必要内容无限闪烁。快速闪烁还可能引发健康风险。加载指示应同时提供可访问文本或状态，不依赖动画本身传达结果。

## 29. 尊重减少动效偏好

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    scroll-behavior: auto;
  }

  .decorative-animation {
    animation: none;
    transition: none;
  }
}
```

不是所有动效都必须完全删除；保留理解操作所必需的状态变化，减少大幅位移、视差和持续装饰。应用也可提供独立设置。

## 30. Overflow 是内容超出盒子后的策略

```css
.table-wrapper { overflow-x: auto; }
```

`overflow:hidden` 会直接裁掉内容、焦点轮廓或弹层，不应作为通用“修好布局”。先找到哪个子项的最小尺寸、长单词或固定宽度撑破容器。

文本截断要确保完整内容仍可通过合理方式获取，不能只加省略号后永久丢失。

## 31. CSS 调试先看计算值和盒模型

顺序：

1. 元素是否被预期选择器匹配；
2. 哪条声明胜出，为什么；
3. 属性是继承还是初始值；
4. Computed width/height 和 box model 是多少；
5. 当前 formatting context 是 block、flex 还是 grid；
6. overflow、min/max-size 是否限制；
7. stacking context 是否造成遮挡；
8. 在真实内容、缩放和窄屏下复现。

不要先随机加 position、z-index 和 `!important`。

## 32. 这篇的整体地图

```text
选择器匹配元素
  → 层叠、优先级、继承决定计算值
  → 盒模型和普通流形成基础布局
  → Flex 管一条轴，Grid 管行列
  → 流式尺寸 + 查询适配容器和视口
  → 自定义属性建立主题
  → transition / transform 表达状态变化
  → DevTools 验证布局、绘制和合成
```

必须掌握：层叠不只是源码顺序；盒模型要理解 border-box；Flex 和 Grid 按关系选择；响应式以内容和可用空间为准；`z-index` 受层叠上下文限制；动效要尊重减少动效偏好。

复杂选择器函数、CSS Houdini、所有排版细节和浏览器前缀属于“需要时查询”。
