---
schema_version: 2
edition: 2026.2-draft
id: ch.web.semantic-html
title: 语义 HTML、文档结构与元数据
responsibility: 用原生元素表达页面结构、内容层级和机器可读元数据，不在本章引入表单交互、CSS 布局或 ARIA 补丁。
volume: '07'
order: 3
level: L1
status: drafting
path: book/volume-07-web-platform/chapters/ch.web.semantic-html.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.web.browser-render-devtools
version_surfaces:
- html-living-standard
- chrome-stable
- chrome-devtools
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“语义 HTML、文档结构与元数据”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - web-semantic-document
  - web-document-metadata
  covers_topics:
  - html.document-outline
  - html.landmark-elements
  - html.heading-hierarchy
  - html.text-semantics
  - html.document-language
  - html.meta-viewport
  - html.title-description
  - html.link-metadata
  uses_capabilities:
  - foundation.http-message
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 编写一页不依赖 CSS 的语义化工单详情并验证文档大纲与元数据；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - web-semantic-document
  - web-document-metadata
  covers_topics:
  - html.document-outline
  - html.landmark-elements
  - html.heading-hierarchy
  - html.text-semantics
  - html.document-language
  - html.meta-viewport
  - html.title-description
  - html.link-metadata
  uses_capabilities:
  - foundation.http-message
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: markup-validation-dom-inspection-manual-outline
- id: diagnose
  kind: fault-diagnosis
  text: 面对“滥用 div、标题跳级或缺失语言声明造成的结构语义丢失”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - web-semantic-document
  - web-document-metadata
  covers_topics:
  - html.document-outline
  - html.landmark-elements
  - html.heading-hierarchy
  - html.text-semantics
  - html.document-language
  - html.meta-viewport
  - html.title-description
  - html.link-metadata
  uses_capabilities:
  - foundation.http-message
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 语义 HTML、文档结构与元数据

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《浏览器请求、解析、渲染与 DevTools 观察》](ch.web.browser-render-devtools.md)：语义元素最终形成 DOM 与可访问树，先理解解析和检查工具才能验证结构而不是只看视觉效果。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套工件用静态 HTML、固定结构清单和 Ruby 标准库离线检查器训练“源码—DOM 预言—人工大纲”证据链；离线绿灯不是 WHATWG/W3C 在线校验、浏览器可访问树或读屏器实测。易变事实已于 **2026-07-17** 对照 WHATWG HTML Living Standard 与 W3C WAI/WCAG 一手资料核验，具体浏览器版本仍须在提交证据时记录。

一个页面即使只有 `div` 和 `span`，也可能被 CSS 画得很像产品界面；但去掉 CSS、让搜索引擎或辅助技术读取、让另一名开发者维护时，结构就可能消失。语义 HTML 的目标不是“少写 div”或“看起来更高级”，而是选择能表达内容含义的原生元素，使源码、浏览器 DOM、可访问性映射和机器处理者拥有共同线索。

本章只处理文档结构、标题、文本语义和 `head` 元数据。表单控件与提交留给下一章，CSS 布局留给 CSS 卷内章节，动态交互留给 JavaScript 章节，必要 ARIA 的判断留给无障碍交互章。错误的原生元素不能靠添加 `role` 粉饰；如果一个普通元素本来就能换成正确的 HTML 元素，先修 HTML。

## 1. 完成定义、边界与证据入口

完成本章，应能独立做到：

1. 用 `header`、`nav`、`main`、`article`、`section`、`aside`、`footer` 表达一页工单详情的区域关系，并说明每个元素为何适用；
2. 用显式的 `h1`–`h6` 等级写出可朗读的大纲，不按字体大小选标题，也不依赖历史上的自动大纲设想；
3. 为段落、列表、术语、强调、时间、引用、代码、图注和联系信息选择对应文本元素；
4. 在 `html` 与 `head` 中设置可核对的语言、字符编码、标题、描述、视口和链接元数据；
5. 分开保存源码检查、浏览器 DOM 检查、标题/区域清单和真实辅助技术观察，不让一种证据替另一种结论；
6. 注入 `div` 汤、标题跳级、缺失 `lang` 三类故障，找到首个可信证据，修复后重跑同一验证；
7. 说出一个本章不解决的反例，例如“让两栏在窄屏变成一栏”属于 CSS 布局，而不是语义标记。

配套入口：

- [语义化工单详情示例](../../../examples/encyclopedia/ch.web.semantic-html/README.md)
- [结构语义故障实验](../../../labs/encyclopedia/ch.web.semantic-html/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.web.semantic-html/README.md)

canonical 验收要求是：从空目录重建一页不依赖 CSS 的语义化工单详情，HTML 结构检查无错误，DOM 检查与人工大纲逐项对应预期的区域、标题和元数据。教材离线 oracle 只检查约定子集；正式证据还应保存在线/本地 conformance checker 结果、浏览器版本与 DOM/可访问树截图。

## 2. “语义”到底是什么

HTML 元素有定义的含义、内容模型和处理规则。`p` 表示段落，`nav` 表示主要导航区段，`time` 可以携带机器可读时间，`button` 天生是可激活控件。浏览器可能为它们提供默认样式，但样式不是含义本身：把 `h2` 调成 12px，它仍是二级标题；把 `div` 调成 32px 粗体，它仍不是标题。

选择元素时依次问：

1. 这段内容在文档中扮演什么角色？
2. HTML 是否已有能直接表达该角色的元素？
3. 该元素的内容模型允许这里的子内容吗？
4. 它会给标题层级、区域导航、表单行为或机器可读数据带来什么规则？
5. 去掉 CSS 后，阅读顺序和关系是否仍合理？

语义不等于“每一块都必须换成专用元素”。当内容没有额外语义，只是为了分组或将来挂接样式/脚本时，`div` 是正确的通用流容器，`span` 是正确的行内容器。反过来，为了“显得语义化”把每个卡片都包成 `section`，却不给它主题和标题，仍然制造噪声。

三个层面必须区分：

- **作者源码**：你写下的标签、属性和文本；conformance checker 主要在这里发现结构错误。
- **DOM**：HTML parser 完成错误恢复后的当前节点树；它可能与错误源码字面结构不同，也可能被脚本/扩展修改。
- **可访问性树/平台映射**：浏览器从 DOM、原生语义、名称和状态映射给辅助技术的结果；它不是 DOM 的逐节点复制。

源码合法是必要的质量基础，却不自动证明内容易懂、标题恰当或读屏流程可用。反过来，一次读屏器似乎能读完，也不能证明 HTML 没有结构错误。证据要按问题选择。

## 3. 文档外壳：DOCTYPE、语言与 head

### 3.1 最小但完整的外壳

下面是本章工单页的外壳。注释不是装饰，它们记录页面职责、数据来源、字段映射和副作用边界，避免示例被误当成生产接口：

```html
<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>工单 WO-2026-0717｜FactoryCare 教学页</title>
    <meta name="description" content="用于学习语义 HTML 的静态工单详情。">
    <link rel="canonical" href="https://docs.factorycare.example/work-orders/WO-2026-0717">
  </head>
  <body>
    <!-- Responsibility: 只表达一份静态工单详情的文档结构，不实现表单、样式或业务动作。 -->
    <!-- Data source: 示例字段来自固定教学夹具，不来自真实租户、用户或生产数据库。 -->
    <!-- Mapping: number/status/priority/createdAt 对应 FactoryCare WorkOrderSummary 的同名概念。 -->
    <!-- Side effects: 本页无脚本、无网络写入，也不会提交或修改工单。 -->
    <main>
      <h1>工单 WO-2026-0717</h1>
      <p>状态：已分派</p>
    </main>
  </body>
</html>
```

`<!doctype html>` 让浏览器以标准模式处理现代 HTML；它不是结束标签，也不是 XML DTD 下载指令。`meta charset="utf-8"` 应尽早放在 `head`，让字节按预期字符编码解释。真实 HTTP 响应中的 `Content-Type`/charset 与文档声明不应冲突；这是上一章 `foundation.http-message` 与浏览器解析证据的连接点。

### 3.2 文档语言 `lang`

根元素 `lang="zh-CN"` 声明页面主要自然语言。它帮助读屏器选择发音规则，也可被翻译、拼写检查和 CSS 语言选择使用。值应是有效的 BCP 47 语言标签；不要写展示用名称如 `Chinese`。若短语语言发生变化，可以在最小范围覆盖：

```html
<!-- Responsibility: 标明术语实际语言，避免把字体或视觉样式误当语言声明。 -->
<p>浏览器根据 <span lang="en">document language</span> 提供语言线索。</p>
```

`lang` 说明内容语言，不说明用户国籍、时区或界面偏好。服务器内容协商、数据库 locale、日期格式化和国际化资源加载不由一个属性解决。缺失 `lang` 的首个可信证据是 DOM 根节点没有有效声明，而不是“页面中文看起来正常”。

### 3.3 `title` 与 description

`title` 是文档元数据，常用于浏览器标签、历史记录、书签和辅助技术的页面识别。每个页面应有简洁、可区分、能在脱离上下文时识别的标题。“详情”或所有页面都叫“FactoryCare”不足以区分；“工单 WO-2026-0717｜FactoryCare”同时给出对象和站点上下文。

`meta name="description"` 给出页面摘要，某些消费者可能使用，但搜索结果是否展示、如何排序不由作者保证。语义元数据提供可机器读取的候选，不是 SEO 排名承诺。描述应反映页面实际内容，不能塞无关关键词或泄露敏感工单信息。

### 3.4 viewport 元数据

常见移动页面声明：

```html
<!-- Responsibility: 让布局视口跟随设备宽度；实际响应式布局由 CSS 章节负责。 -->
<meta name="viewport" content="width=device-width, initial-scale=1">
```

这不是“自动响应式”。它影响视口解释，使后续 CSS media query 和布局更符合设备宽度。不要用禁止缩放的设置掩盖布局问题；用户缩放能力关系到可访问性。本章验证字符串和 DOM 属性存在，不验证具体设备渲染。

### 3.5 `link` 元数据

`link` 在文档与外部资源/相关表示之间建立带 `rel` 的关系。`rel="canonical"` 可声明作者偏好的规范 URL；`rel="icon"` 可声明图标；`rel="stylesheet"` 会加载样式表，但样式加载不是本章目标。关系值的语义必须对应真实关系，不能靠随意发明 `rel` 值让消费者理解。

canonical URL 不会自动重定向用户，也不替代服务端 URL 规范化、权限或缓存策略。私有工单页尤其不能为了示例把真实标识、租户或 token 写入公开 canonical。教学资产使用保留域名和虚构编号。

## 4. 页面区域：选元素而不是选外观

### 4.1 `header` 与 `footer` 是上下文相关的

页面级 `header` 通常包含站点/页面引介、标识和导航；`article` 内的 `header` 可包含该工单标题和摘要。`footer` 同样可以属于页面或最近的 sectioning 内容，包含作者、更新时间、相关链接等。它们不是“永远等于顶部/底部”的坐标，也不因标签名自动固定在屏幕。

`header`/`footer` 是否暴露为 landmark 与其上下文和浏览器映射有关。不要统计标签数就断言可访问树必有同样数量的 banner/contentinfo。应在锁定浏览器中查看 Accessibility 面板，并用真实读屏器导航区域。

### 4.2 `nav` 只包主要导航

`nav` 表示指向其他页面或当前页面部分的导航区段。主导航、面包屑或长文目录通常适用；页脚中两三个法律链接未必需要额外 `nav`。多个导航区域应有可区分的可访问名称，但本章不靠随意添加 ARIA 解决命名，优先让标题和上下文清晰，把更完整的命名策略留给无障碍章。

导航内部用列表常能表达“一组链接”，例如：

```html
<!-- Responsibility: 提供当前文档主要区域的跳转清单，不承载工单业务动作。 -->
<nav>
  <h2>本页目录</h2>
  <ul>
    <li><a href="#summary">摘要</a></li>
    <li><a href="#timeline">流转记录</a></li>
  </ul>
</nav>
```

不是每个含链接的容器都是导航；“查看设备 A-17”作为正文相关链接，放在段落里即可。

### 4.3 `main` 是页面主内容

`main` 表示文档主体中独有、直接相关的主要内容，不包括跨页面重复的站点导航、版权信息等。普通页面通常只有一个当前可见的主内容。模板预渲染、对话框或多视图可能让 DOM 暂时出现多个 `main`，但必须遵守规范的隐藏/上下文要求并经过真实浏览器验证；入门项目保持一个清晰 `main` 最可靠。

“数据库里的主要字段”与 HTML `main` 不是一个概念。`main` 划分页面内容区域，不告诉 API 哪些字段必填，也不决定数据权限。

### 4.4 `article`、`section` 与 `div`

判断方法：

- `article`：内容整体可独立分发、复用或理解，例如一篇文章、论坛帖、评论，或本页中完整的一份工单详情；
- `section`：文档/应用中有主题的一节，通常应该有标题，例如“故障摘要”“流转记录”；
- `div`：没有更合适语义，只为通用分组、样式或脚本挂点。

把页面每块都写成 `article` 不会增加价值。工单详情作为完整对象可用一个 `article`，其中按主题分 `section`；状态徽标旁的若干视觉包装若无独立含义，未来用 `div` 完全合理。`section` 不是“带间距的盒子”，CSS 才负责间距。

### 4.5 `aside` 与补充内容

`aside` 表示与周围内容间接相关、可相对独立的补充内容，如同设备的安全提示、相关维修手册。若移除后主叙事仍完整，通常适合。核心故障描述不能为了做侧栏而放进 `aside`；视觉位置不是语义。

## 5. 标题层级与人工大纲

### 5.1 标题是层级，不是字号

`h1`–`h6` 的数字表达标题级别。对于一页工单详情，可把页面/文章主标题设为 `h1`，一层主题用 `h2`，主题内子项用 `h3`：

```text
h1 工单 WO-2026-0717
  h2 故障摘要
  h2 设备与位置
  h2 流转记录
    h3 已创建
    h3 已分派
  h2 联系信息
```

这份纯文本清单就是可审阅的“预期大纲”。它不是某个浏览器保证提供给用户的标准可视面板，也不是完整可访问树。先写预期，再检查源码/DOM 的标题序列，最后用辅助技术实际导航。

不要从 `h1` 直接跳到 `h3` 只因为想要更小字体；也不要把普通加粗段落当标题。若标题下没有独立内容，只是视觉标签，它可能不是标题。若组件被嵌入不同页面，应该由架构明确层级契约，而不是依赖旧的“section 会自动重排 h1”想象。现代实践使用显式、连续且符合内容关系的等级。

### 5.2 一个还是多个 `h1`

HTML 允许的细节与历史讨论容易让初学者误解为“每个 section 都写 h1，浏览器会自动算层级”。实际辅助技术和浏览器并不提供一个可依赖的自动重排结果。项目采用清晰规则：每个页面一个描述主主题的 `h1`，直接子主题 `h2`，更深层递增。这不是说任何多个 `h1` 都语法无效，而是选择跨工具更容易预测、维护和审核的作者约定。

### 5.3 标题与区域不是同一清单

标题大纲回答“内容有哪些主题与从属关系”；landmark/区域清单回答“用户能跳到哪些页面功能区”。一个 `section` 有标题，不代表在所有环境中自动成为具名 landmark；一个 `main` 即使内部标题缺失，仍可能映射主区域，但内容层级依然不完整。证据表应分两列记录。

建议保存：

| 证据 | 预期 | 实际 | 能证明 | 不能证明 |
|---|---|---|---|---|
| 标题序列 | `h1,h2,h2,h2,h3,h3,h2` | DOM 检查结果 | 显式等级顺序 | 标题文字是否易懂 |
| 原生区域 | `header,nav,main,article,section*,footer` | DOM 元素 | 使用了约定元素 | 实际平台映射完全一致 |
| Accessibility 面板 | 主区域/导航等 | 指定浏览器截图 | 该浏览器版本的映射 | 所有读屏器体验 |
| 读屏器任务 | 能按标题找到流转记录 | 操作记录 | 该环境任务可完成 | 全面 WCAG 合规 |

## 6. 文本语义：句子内部也有结构

### 6.1 段落、换行与分隔

`p` 表示段落。不要用连续 `<br>` 制造段落间距；`br` 适用于诗行、地址行等换行本身有意义的内容。主题改变需要标题/section 时，不要用 `<hr>` 和粗体假装层级。`hr` 表示段落级主题转换，仍不是布局线工具。

### 6.2 列表与术语

- `ul`：顺序不重要的项目，如故障标签；
- `ol`：顺序/排名有意义的步骤，如事件时间线；
- `dl`：名称—值/术语—描述组合，如工单编号、状态、优先级；
- `li`、`dt`、`dd` 保留项目关系，不用一串 `p` 模拟。

例如工单概要：

```html
<!-- Mapping: 展示字段是固定 WorkOrderSummary 教学投影；缺失值应由上游显式标注。 -->
<dl>
  <dt>状态</dt>
  <dd>已分派</dd>
  <dt>优先级</dt>
  <dd>高</dd>
  <dt>创建时间</dt>
  <dd><time datetime="2026-07-17T09:30:00+08:00">2026 年 7 月 17 日 09:30</time></dd>
</dl>
```

`time` 的可见文本服务读者，`datetime` 给机器稳定值。时区不可省略后又假装是全球绝对时间；FactoryCare 领域值若为带时区 instant，应在映射处写明展示转换规则。

### 6.3 `em`、`strong`、`b`、`i`

`em` 表示语气强调，嵌套可加强；`strong` 表示重要、严重或紧急。它们不是“斜体/粗体快捷键”。`b` 可表示不带额外重要性的关键词等，`i` 可表示另一语态、技术术语等；若只是视觉样式，留给 CSS。把所有字段名包 `strong` 会把重要性语义稀释。

### 6.4 引用、代码与预格式文本

短行内引用用 `q`，块级引用用 `blockquote`，来源可在相邻内容或适当属性/链接中表达；不要把任意缩进文字都当引用。`code` 标记代码/标识符，`pre` 保留空白格式，二者常组合但含义不同。错误日志是预格式文本，字段名可能只是 `code`。

### 6.5 `figure`、`figcaption` 与 `address`

`figure` 包裹可独立引用的图、表、代码清单等，`figcaption` 提供其标题。它不意味着右浮动，也不替代媒体的替代文本。`address` 只用于当前文章或页面的联系信息，不是任意邮政地址、设备位置或所有键值块。工单“设备位置：三号车间”通常是普通数据，不该放进 `address`；报修人联系方法才可能适用，但还要遵守隐私最小化。

## 7. 一页语义化 FactoryCare 工单详情

FactoryCare 的真实 `WorkOrderDetail`/summary 合同包含工单 id/number、assetId、status、priority、version、createdAt、可选 SLA 到期时间、分派团队/技术员及 transition 记录。下面只做固定、脱敏的阅读投影，不请求 API，也不暗示 HTML 名称就是后端 JSON 合同：

```html
<!-- Responsibility: 呈现一份可独立阅读的教学工单详情；不提供状态变更控件。 -->
<!-- Data source: synthetic-work-order.json 固定夹具；禁止替换为真实租户或联系人数据。 -->
<!-- Mapping: summary 字段映射到 dl；transitions 按 occurredAt 排序后映射到 ol/article。 -->
<!-- Side effects: 静态文档只读；链接仅做页内导航，不调用 FactoryCare API。 -->
<header>
  <p>FactoryCare 教学文档</p>
  <nav>
    <h2>本页目录</h2>
    <ul>
      <li><a href="#summary">故障摘要</a></li>
      <li><a href="#transitions">流转记录</a></li>
    </ul>
  </nav>
</header>
<main>
  <article>
    <header>
      <h1>工单 WO-2026-0717</h1>
      <p><strong>高优先级：</strong>冷却泵出现持续异响。</p>
    </header>
    <section id="summary">
      <h2>故障摘要</h2>
      <dl>
        <dt>状态</dt><dd>已分派</dd>
        <dt>设备</dt><dd>A-17 冷却泵</dd>
        <dt>创建</dt><dd><time datetime="2026-07-17T09:30:00+08:00">09:30</time></dd>
      </dl>
    </section>
    <section id="transitions">
      <h2>流转记录</h2>
      <ol>
        <li><article><h3>已创建</h3><p>系统接受报修请求。</p></article></li>
        <li><article><h3>已分派</h3><p>分派至机修一组。</p></article></li>
      </ol>
    </section>
    <footer><p>夹具版本：2026.2；内容不含真实个人信息。</p></footer>
  </article>
</main>
<footer><p><small>FactoryCare 学习项目</small></p></footer>
```

此例故意没有 CSS。无样式并不代表生产页面不需要 CSS，而是验收先证明结构不依赖视觉摆放。transition 的 `article` 是否必要取决于它能否独立理解/复用；若每项只有短句，`li` 内直接用标题/段落也可。要把这一选择写进评审说明，而不是机械套模板。

## 8. 验证：四层证据，不让绿灯越权

### 8.1 源码 conformance

使用 WHATWG/W3C 兼容的 HTML checker 检查元素嵌套、属性和值等作者错误。记录工具名称/版本或 URL、运行日期、输入文件哈希和完整结果。在线上传前先确认夹具无秘密；私有页面可使用本地 validator 或经过批准的环境。

教材 `oracle.rb` 只用正则和固定契约检查 DOCTYPE、`lang`、head 元数据、区域元素、标题顺序及意图注释。它不是完整 HTML parser，更不是官方 conformance checker。离线结果应写成“课程契约通过”，不能写成“HTML 标准完全合规”。

### 8.2 DOM 检查

用浏览器 Elements/Console 检查解析后的节点树：标签是否被 parser 修复/搬移，根语言与 meta 属性是否如预期，标题序列是否相同。保存浏览器全版本、URL/文件 hash、视口和检查命令。DOM 正确仍不能单独证明区域映射或读屏体验。

### 8.3 手工标题与区域清单

在打开页面前写预期：

```text
landmarks/regions: header → nav → main → article.sections → footer
headings: h1 工单；h2 故障摘要；h2 流转记录；h3 已创建；h3 已分派
metadata: lang=zh-CN；title 非空且唯一；viewport；description；canonical
```

再从当前 DOM 提取实际序列逐项比较。这样可避免“看到页面像对的”后再修改预期。注意这里的 `landmarks/regions` 是作者结构预言，真实 landmark 名称和数量仍以可访问性树/辅助技术观测为准。

### 8.4 可访问性映射与任务验证

在目标浏览器 Accessibility 面板观察 role/name 层次，用至少一种目标读屏器按标题与 landmark 导航到“流转记录”。记录 OS、浏览器、读屏器版本、语言、操作键和结果。一次成功不能推出 WCAG 全部满足；颜色、键盘交互、焦点、动态通知等在后续章节另验。

## 9. 诊断三类结构语义丢失

### 9.1 滥用 `div`

症状：视觉上有页头、导航、主体和小节，DOM 却只有嵌套 `div`，标题也是 class 加粗文本。

诊断顺序：

1. 保存源码 hash，确认问题不是 DevTools 临时修改；
2. 查看 DOM 元素名与标题序列；
3. 对照预期结构，首个可信差异通常是缺少原生 `main`/`nav` 或没有 `h1`，不是 CSS class 名不好看；
4. 按内容职责替换元素，保持可见文字与数据不变；
5. 重跑同一源码 oracle、DOM 清单和读屏任务。

残余风险：换标签可能改变浏览器默认样式或既有 CSS selector，生产迁移需另做视觉回归；本章不为了兼容错误 selector 而保留 div 汤。

### 9.2 标题跳级

症状：`h1` 后直接出现 `h3`，只因设计稿希望小字号。首证据是 DOM 标题等级序列与预期不一致。修复应根据内容关系改成 `h2`，然后由 CSS 控制视觉；不能把上一个空 `h2` 塞进去“补级”。若组件上下文不明确，应先定义宿主传入的层级契约，不能硬编码猜测。

### 9.3 缺失语言声明

症状：根 `html` 没有 `lang` 或值无效。首证据是 DOM `document.documentElement.lang` 为空/错误；中文肉眼可读不是反证。补上页面主语言，并对真实外语片段覆盖，再重跑结构检查与目标读屏器发音任务。残余风险包括混合语言专名、用户生成内容和运行时 locale 切换，这些需要内容/i18n 策略。

### 9.4 失败日志模板

```text
fixture: semantic-work-order@sha256:...
environment: offline-oracle / browser+version / screen-reader+version
prediction: h1,h2,h2,h3,h3；lang=zh-CN；main=1
first_observed_divergence: heading[2]=h3, expected h2
excluded_causes: CSS appearance；HTTP body hash mismatch；DevTools temporary edit
repair: h3 → h2 according to content hierarchy
rerun: same command, same fixture, new source hash, all structural assertions pass
residual_risk: real accessibility-tree and screen-reader matrix not yet verified
```

“修完刷新看起来正常”缺少输入、首证据、排除过程和同一验证重跑，不构成 diagnose outcome。

## 10. 常见误解与更正

| 误解 | 为什么错 | 更可靠的规则 |
|---|---|---|
| 语义化就是不用 `div` | 通用容器有合法用途 | 有原生含义时用原生元素，无额外含义时用 `div`/`span` |
| `section` 会自动制造正确大纲 | 工具不会替作者可靠重排标题 | 显式、连续地写 `h1`–`h6` |
| `header` 永远是 banner | 映射依赖上下文 | 区分页面级与 section 内 header，并实测可访问树 |
| 每组链接都用 `nav` | 会制造冗余导航区域 | 只包主要导航块 |
| `main` 等于业务最重要字段 | 它定义页面主体区域 | API 字段重要性由业务合同定义 |
| validator 绿就无障碍 | 它主要发现标记错误 | 继续做可访问树、键盘和读屏任务 |
| meta description 保证搜索摘要 | 消费者决定是否使用 | 写准确摘要，不作展示/排名保证 |
| `role` 能修复任意 div | 行为、内容模型和平台支持可能仍缺失 | 能用正确原生元素时先修 HTML |

## 11. 独立实验：从空目录复现

目标：编写一页不依赖 CSS 的语义化工单详情，验证元数据、显式标题和原生结构；随后依次注入三类故障。

### 11.1 输入与约束

- 只使用虚构 FactoryCare 工单数据；不复制 `solutions-private`；
- 页面必须包含 `html[lang]`、UTF-8、viewport、唯一且有区分度的 title、description 与 canonical；
- 一个可见 `main`，一个页面主 `h1`；按主题使用 `h2`，子主题才用 `h3`；
- 至少包含 header、主要 nav、main、article、两个 section 和 footer；
- 至少展示 `dl`、`time[datetime]`、`strong` 与有序/无序列表中的两种；
- 不写 CSS、表单、脚本、ARIA；HTML 注释说明职责、数据源、映射和副作用；
- 先保存 `expected.json`，再写 HTML，防止看结果改预言。

### 11.2 命令与证据

复制配套 lab 到空目录，阅读 README，运行其中唯一 `verify.sh`。该命令只做离线课程契约检查。真实验收另执行获批的 HTML checker，并在浏览器中保存：Response/源码 hash、Elements DOM、标题清单、Accessibility 区域、读屏任务记录。

注入顺序：

1. 把 `main/nav/section` 改为 `div`，预测第一个失败断言；
2. 把某个 `h2` 改成 `h3`，保持文字不变；
3. 删除 `html lang`；
4. 每次只改一个变量，保存红灯，修复后用原命令重跑；
5. 报告残余风险，不声称离线正则检查覆盖完整标准。

## 12. 120 秒讲解模板

> 语义 HTML 用原生元素表达内容角色，而不是决定视觉。页面外壳用 `lang`、title、description、viewport 和 link metadata 给浏览器及机器消费者上下文；body 用 header/nav/main/article/section/footer 表达区域，用显式 h1–h6 表达标题从属，用 p/list/dl/time 等表达文本关系。证据分源码 conformance、解析后 DOM、人工标题/区域预言和真实可访问性任务，任一绿灯都不能替代其他层。遇到 div 汤、标题跳级或缺 lang，我先比较固定源码与预期清单，指出第一个结构差异，修复后重跑相同检查。它不解决 CSS 两栏布局、表单提交、JavaScript 交互或完整 WCAG 合规。

若不能在 120 秒内同时讲清职责、边界、证据与反例，说明仍在背标签清单，没有形成诊断模型。

## 13. 规范核验与版本边界

本章易变事实于 **2026-07-17** 核验：

- [WHATWG HTML Living Standard：Sections](https://html.spec.whatwg.org/multipage/sections.html)：`article`、`section`、`nav`、标题、`header`/`footer` 等定义；Living Standard 会持续更新。
- [WHATWG HTML Living Standard：Document metadata](https://html.spec.whatwg.org/multipage/semantics.html)：`title`、`meta`、`link` 与文档级语义。
- [W3C WAI Page Structure Tutorial](https://www.w3.org/WAI/tutorials/page-structure/)：页面区域、逻辑标题与结构对辅助技术导航的作用。
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)：信息与关系、页面标题、标题与标签等成功准则的规范入口。

确认项：元素职责、显式标题等级、语言与元数据的标准语义已对照一手资料；配套离线 oracle 的输入/预期可重复。未确认项：具体 Chrome/Firefox/Safari 版本的可访问性映射、在线 HTML checker 输出、VoiceOver/NVDA/JAWS 导航体验、FactoryCare 生产模板与真实数据映射。提交 G4 证据时必须补齐目标环境，不能把教材日期当产品认证日期。

## 14. 交付检查表

- [ ] 我能说明 `article`、`section`、`div` 的选择依据，而非按外观选择。
- [ ] 页面有有效主语言、UTF-8、viewport、区分度足够的 title、准确 description 和真实 link relation。
- [ ] 去掉 CSS 后，阅读顺序、标题层级和内容关系仍成立。
- [ ] 标题等级显式连续，不依赖自动 outline，也没有空标题补级。
- [ ] 页面级与局部 `header/footer` 的上下文已解释，主要导航和主内容可识别。
- [ ] 文本使用段落、列表、描述列表、time、强调等适当语义。
- [ ] HTML 注释写明职责、固定数据来源、字段映射和无副作用边界。
- [ ] 我保存了预期清单、源码 hash、离线结果与真实浏览器待验项。
- [ ] 三类故障都有首个可信证据、修复、同一命令重跑和残余风险。
- [ ] 我没有声称 validator 绿灯等于无障碍，也没有用 ARIA 掩盖错误 HTML。

达到这些条件，才具备进入“表单控件、提交语义与原生校验”的结构基础。
