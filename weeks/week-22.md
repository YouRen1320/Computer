# 第 22 周：HTML、表单、可访问性与 CSS 布局基础

## 定位

虽然已有 Vue 前端经验，本周仍从浏览器原生基础做一次系统重建。框架组件最终会输出 HTML/CSS；语义、可访问性、布局和表单边界不清楚时，Vue 只会把问题藏得更深。熟练项用基线挑战快速通过，薄弱项当场补齐。

时间预算：15—18 小时。先使用原生 HTML/CSS 和少量已掌握的 JS 验证，不引入 Vue 或 UI 组件库。

## 前置

- G3 企业后端通过，FactoryCare 公共 API/错误契约已有稳定草案；
- 能使用浏览器 DevTools 检查 Elements、Styles、Network 和 Accessibility 基础面板；
- 已有前端经验，但接受每项用证据而非年限判定。

## 目标

- 根据内容和交互语义选择 HTML 元素；
- 构建可键盘操作、可读标签、错误可理解的表单；
- 理解 DOM 文档结构、元数据、资源和渐进增强；
- 掌握 CSS cascade、specificity、inheritance、box model 和 normal flow；
- 使用 Flexbox/Grid/定位/响应式完成稳定布局；
- 理解 stacking context、overflow、滚动、尺寸和文本布局常见问题；
- 建立颜色、间距、字体和焦点的最小设计 token；
- 完成不依赖框架的 FactoryCare 报修/筛选页面骨架。

## 完整概念清单

### HTML 文档与语义

- doctype、`html/head/body`、字符集、viewport、title/description；
- block/inline 是默认表现，不是语义分类；
- `header/nav/main/section/article/aside/footer` 与标题层级；
- `button` 与链接的行为差异；不用 `div` 模拟按钮；
- 列表、表格、figure、time、address、details/summary；
- 表格用于二维数据，表头、caption 和 scope；
- 图片 `alt`、装饰图、尺寸与延迟加载；
- 渐进增强和无 JS 时的基础可用性概念。

### 表单

- `form`、action/method、label/for、fieldset/legend；
- input type、name、value、placeholder、autocomplete、inputmode；
- checkbox/radio/select/textarea/button；
- required、min/max、minlength/maxlength、pattern 和原生校验；
- disabled 与 readonly、提交是否包含字段；
- 客户端校验改善体验，服务端仍是权威；
- 错误摘要、字段错误、焦点移动和保留输入；
- 文件上传类型/大小提示不能替代服务端验证。

### 可访问性

- 语义优先于 ARIA；“没有 ARIA 比错误 ARIA 更好”的边界；
- accessible name/description、角色、状态；
- 键盘顺序、可见焦点、skip link、modal 焦点管理概念；
- 颜色对比、不能只靠颜色传达状态；
- `aria-live` 用于必要动态反馈，避免噪音；
- reduced motion、屏幕阅读器高层体验；
- Lighthouse/axe 是辅助工具，不能证明全部可访问。

### CSS 核心

- selector、cascade origin/layer、specificity、source order、inheritance；
- `initial/inherit/unset/revert` 高层概念；
- box model：content/padding/border/margin、`box-sizing`；
- normal flow、block formatting、margin collapse；
- display、visibility、opacity 与是否占位/可交互；
- 长度单位 px/rem/em/%/vw/vh/dvh/ch；
- 自定义属性、fallback 和主题 token；
- 字体栈、line-height、文本换行和溢出。

### 布局与响应式

- Flex 主轴/交叉轴、grow/shrink/basis、min-width 陷阱；
- Grid track、fr、minmax、auto-fit/auto-fill、gap 和区域；
- relative/absolute/fixed/sticky 的包含块；
- z-index 只在同一 stacking context 中比较；
- overflow、滚动容器、sticky 失效原因；
- media/container query、移动优先和内容驱动断点；
- 响应式图片和触控目标；
- CSS reset/normalize 的作用与边界。

## 时间与任务

| 任务 | 时间 | 产出 |
| --- | ---: | --- |
| 无框架语义页面 | 2h | 设备详情与工单时间线 |
| 可访问表单 | 3h | 报修表单、原生校验、错误摘要 |
| CSS 层叠/盒模型实验 | 2h | specificity、尺寸和溢出故障记录 |
| Flex/Grid/响应式 | 3h | 工作台、筛选栏、表格/卡片切换 |
| 可访问性审计 | 2h | 键盘、焦点、名称、对比与修复证据 |
| FactoryCare 骨架/复盘 | 3—5h | 三种宽度截图、DevTools 证据、独立改动 |

## FactoryCare 增量

- 原生 HTML/CSS 实现“创建报修”和“工单筛选结果”两页；
- 表单包含设备、故障类别、描述、紧急程度和附件提示；
- 所有交互可用键盘完成，错误和成功状态有可访问文本；
- 窄屏、平板、桌面三种内容布局合理；
- 不复制最终 Vue 页面，保留为后续组件化的语义基线；
- 记录至少 3 个原先凭经验写但机制解释不清的 CSS/HTML 点。

## 无 AI 任务（120 分钟）

根据一张简单线框图实现可访问的工单筛选+结果页：不使用框架、CSS 库或 AI；支持 360px 和桌面宽度、键盘焦点、表单标签、空/错误提示和表格或卡片语义。使用 DevTools 解释一个层叠和一个布局问题。

## 验收

- 能解释 `button`/`a`、`section`/`div`、表格/列表的语义选择；
- 表单标签、错误、键盘和焦点通过人工检查；
- 能从 cascade/box/containing block/stacking context 定位一个 CSS 问题；
- Flex/Grid 选择有理由，不靠大量绝对定位；
- 页面在三种宽度可用，无明显横向溢出；
- 能说明浏览器原生校验与 Java 服务端校验的边界。

## 非目标

- 不学习 Vue、Tailwind 或 Element Plus；
- 不追求视觉作品集级精修；
- 不背所有 HTML 标签/CSS 属性；
- 不用 Lighthouse 满分冒充人工可访问性验证。
