---
schema_version: 2
edition: 2026.2-draft
id: ch.web.browser-render-devtools
title: 浏览器请求、解析、渲染与 DevTools 观察
responsibility: 建立从导航请求到 DOM/CSSOM、布局、绘制和合成的可观察浏览器管线，只做测量与解释，不在本章优化 JavaScript 性能。
volume: '07'
order: 1
level: L1
status: drafting
path: book/volume-07-web-platform/chapters/ch.web.browser-render-devtools.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.foundations.http-curl
version_surfaces:
- browser
- browser-devtools
- html-living-standard
- css
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“浏览器请求、解析、渲染与 DevTools 观察”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - web-browser-pipeline
  - web-devtools-observation
  covers_topics:
  - web.navigation-request
  - web.html-parsing-dom
  - web.cssom-render-tree
  - web.layout-paint-composite
  - web.devtools-network-panel
  - web.devtools-elements-panel
  - web.devtools-performance-baseline
  uses_capabilities:
  - foundation.http-message
  - web.browser-rendering
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“浏览器请求、解析、渲染与 DevTools 观察”构建可运行程序与测试：制作一个最小页面并保存请求、解析和渲染阶段的 DevTools 证据；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - web-browser-pipeline
  - web-devtools-observation
  covers_topics:
  - web.navigation-request
  - web.html-parsing-dom
  - web.cssom-render-tree
  - web.layout-paint-composite
  - web.devtools-network-panel
  - web.devtools-elements-panel
  - web.devtools-performance-baseline
  uses_capabilities:
  - foundation.http-message
  - web.browser-rendering
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: prediction-devtools-observation-command-exit
- id: diagnose
  kind: fault-diagnosis
  text: 面对“错误资源路径或阻塞资源导致的加载与渲染异常”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - web-browser-pipeline
  - web-devtools-observation
  covers_topics:
  - web.navigation-request
  - web.html-parsing-dom
  - web.cssom-render-tree
  - web.layout-paint-composite
  - web.devtools-network-panel
  - web.devtools-elements-panel
  - web.devtools-performance-baseline
  uses_capabilities:
  - foundation.http-message
  - web.browser-rendering
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 浏览器请求、解析、渲染与 DevTools 观察

> 本章状态为 `drafting`。配套资产用静态 HTML/CSS、合成 HAR/DOM/时间线和离线预言训练证据阅读，不自动启动图形浏览器，也不伪造真实 DevTools 截图。离线绿灯证明输入、阶段和诊断规则一致；真实 Chrome/Firefox/Safari 的网络瀑布、DOM、截图与 Performance 录制仍需人工操作和环境记录。

在地址栏输入 URL 并按回车后，屏幕不会凭空出现页面。浏览器要解析地址、取得主文档、读取响应、解析 HTML、发现依赖资源、构造 DOM 与样式数据、计算几何位置、生成绘制指令、栅格化并合成像素。它还可能重定向、复用缓存、并行下载、边收边解析、暂停解析等待资源或脚本，再因字体、图片、视口和后续变化重新做部分工作。

本章建立的是一张**可观察的因果地图**，不是要求记住某个浏览器内部类名。看到“页面没样式”时，先问 CSS 请求是否成功，再问 CSS 是否被解析和应用；看到“元素存在但看不见”时，先分清 DOM、computed style、layout box 和最终 paint；看到“加载慢”时，不凭感觉指责服务器或 JavaScript，而是保存请求瀑布、DOM 与时间线，指出首个与预言不一致的证据。

## 1. 完成定义与证据入口

完成本章，应能：

1. 从一次导航请求解释主文档与 CSS、图片等子资源如何进入页面；
2. 区分 HTML 源文本、token、DOM、CSS 规则、computed style、用于渲染的结构和最终像素；
3. 解释 style、layout、paint、raster、composite 各回答什么问题，以及为什么并非每次更新都重走全部阶段；
4. 在 Network 面板核对 URL、method、status、headers、body、initiator、timing 与 transfer/cache 线索；
5. 在 Elements 面板区分“当前 DOM”和“最初响应源码”，核对 computed style 与 box；
6. 保存一次带浏览器版本、视口、缓存条件、输入动作和截图的 Performance baseline；
7. 注入错误资源路径或阻塞资源，先预测，再指出首个可信证据，修复并重跑同一预言；
8. 说明 HAR、截图、DOM 快照和时间线各自能证明什么、不能证明什么，并在分享前清除秘密与个人数据。

配套入口：

- [最小页面与合成证据示例](../../../examples/encyclopedia/ch.web.browser-render-devtools/README.md)
- [错误资源路径与阻塞资源实验](../../../labs/encyclopedia/ch.web.browser-render-devtools/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.web.browser-render-devtools/README.md)

canonical 验收要求同一测试页面的请求瀑布、DOM 结构和渲染阶段能由保存的 HAR、截图与时间线重复核对。只说“我在 DevTools 看过”不算；只有截图但没有 URL、输入、版本和原始工件也不算。

## 2. 先建立不容易误导的管线模型

教学上可把首次页面显示写成：

```text
用户导航
  → 主文档请求/响应
  → HTML 字节解码与解析
  → DOM，并发现 CSS/图片等子资源
  → CSS 解析与样式计算
  → layout：尺寸与位置
  → paint：画什么、按什么顺序
  → raster：绘制指令变成像素块
  → composite/draw：组合后提交屏幕
```

这张图只表达依赖关系，不表示浏览器必须等上一步“全部结束”才开始下一步。HTML 常被流式解析；解析器看到 `<link rel="stylesheet">` 或 `<img>` 就可能发请求；preload scanner 可能提前发现资源；已取得的一部分 DOM/CSS 足以触发早期渲染；后来的字体、图片尺寸和 DOM 变化又可能使样式、布局或绘制失效。合成线程也可能在不重做 layout/paint 的情况下处理某些滚动与视觉效果。

不要把规范算法、概念模型和具体 Chromium 实现混成一件事：

- WHATWG HTML 定义导航、文档和 HTML parser 的互操作语义；
- CSSOM 等规范定义样式表/规则的可观察对象模型；
- “render tree”是很有用的教学简写，但浏览器内部可能用 fragment tree、property tree、display list、layer 等更细结构；
- Chromium 的 RenderingNG 阶段说明 Chrome 实现，不是所有浏览器必须采用相同进程、线程和数据结构；
- DevTools 展示的是经过工具解释的记录，UI、分类、颜色和字段会随版本改变。

## 3. 导航：从 URL 到主文档

### 3.1 导航与普通子资源请求

地址栏输入 `http://127.0.0.1:4173/index.html` 并回车，是顶层 frame 的导航。浏览器解析 URL，决定 scheme、host、port、path 等，随后在可适用的缓存、Service Worker、网络和安全策略中取得资源。最终若收到 HTML 响应，会为新文档建立环境并解析内容。页面内的 CSS、图片、字体、脚本请求是由主文档或后续代码发起的子资源请求，不等同于新的顶层导航。

本章测试页用本地 HTTP server，而不是双击 `file://...`。`file:` 的 origin、权限、路径和跨资源行为有浏览器差异，也没有普通 HTTP 状态码/响应头，无法训练前置章已经学过的 HTTP 报文。启动服务后应记录：命令、工作目录、端口、页面 URL、浏览器版本、是否有代理/扩展、缓存条件、视口与重现动作。

### 3.2 Network 中主文档的预言

在刷新前先预测最少请求集合：

```text
GET /index.html  → 200, Content-Type: text/html
GET /styles.css  → 200, Content-Type: text/css
GET /status.svg  → 200, Content-Type: image/svg+xml
```

实际记录多出 favicon、浏览器扩展或开发服务器连接不一定是应用 bug；要按 initiator、domain 和资源类型区分。少了 `styles.css` 可能是 HTML 没有引用、解析没走到、缓存/工具过滤隐藏，或请求被策略阻断。状态 200 也不保证内容正确：CSS URL 返回 HTML 错误页，仍可能导致 MIME/解析问题。

Network 面板的第一证据通常包括：

- **Name/URL**：请求的精确资源，不只看显示名；
- **Method/Status**：是否真的发出，服务器如何响应，是否经历 redirect；
- **Type/Content-Type**：工具推断的资源类型和服务器声明是否吻合；
- **Initiator**：哪段 HTML、CSS 或代码触发；
- **Headers/Payload/Response**：发送和收到的事实；
- **Timing**：排队、连接、等待响应、内容下载等阶段的记录；
- **Size/Transferred**：网络传输、压缩或缓存线索，不能脱离列定义猜测；
- **Waterfall**：请求在同一时间轴上的先后、重叠和阻塞线索。

瀑布中的一条长条不等于“服务器一定慢”。它可能主要在排队、DNS/连接、等待首字节、下载，或只是视图缩放造成误读。先点开 Timing，再结合响应头、服务端证据和重复样本。Network 也不是所有性能问题的唯一入口；本章只建立证据基线，不做 JavaScript 性能优化。

### 3.3 Redirect、错误状态和下载成功不是同义词

3xx 可能产生新的导航/请求；4xx/5xx 也可能带可渲染 HTML；浏览器拿到 body 并显示错误页，不表示目标业务成功。相反，主文档 200 但 CSS 404 时，页面可能仍显示无样式内容。诊断必须按每个资源和阶段判断，不能用“页面能打开/打不开”压平所有状态。

## 4. HTML 解析与 DOM

### 4.1 从字节到节点

HTTP body 是字节序列。浏览器结合响应与文档编码规则解释字符，再由 HTML tokenizer/tree builder 按 HTML 解析算法生成 DOM tree。DOM 是当前文档的对象树，包含 Document、Element、Text、Comment 等节点；HTML 源码只是输入文本。

示例源码：

```html
<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8">
    <title>FactoryCare 工单观察页</title>
    <link rel="stylesheet" href="./styles.css">
  </head>
  <body>
    <main>
      <h1>工单 WO-1001</h1>
      <p class="status">状态：处理中</p>
      <img src="./status.svg" alt="处理中状态示意">
    </main>
  </body>
</html>
```

解析器读到元素开始/结束标记和文本，按当前 insertion mode 建节点、调整栈并进行 HTML 定义的错误恢复。HTML 不是 XML：某些遗漏结束标记会按规则补全，错误嵌套可能被重排。于是 View Source、Network Response 和 Elements 中的当前 DOM 可能不同。不能因为 Elements 树“看起来正确”就断言源 HTML 合法；也不能在 Elements 临时改节点后声称源码已修复。

### 4.2 流式解析、资源发现与暂停

浏览器不必等整个 HTML 下载完成才解析。前半段已到达时就能创建节点和发现子资源。经典脚本在某些条件下会暂停 parser，样式表会影响后续脚本和首次渲染时机；`defer`、`async`、模块脚本等细节留到 JavaScript 章节。本章只要求观察：Network 的 initiator/瀑布是否与 HTML 引用相符，Performance 里解析与样式/布局何时发生。

“DOM 已构造”也不是单一永久时刻。解析期间树逐步增长，脚本可修改，浏览器/扩展可注入；之后交互还会变化。保存证据时说明是在初次 load 后、某次动作前还是动作后。

### 4.3 DOMContentLoaded 与 load 的边界

`DOMContentLoaded` 与文档解析及相关脚本时机有关，`load` 等待的资源集合更广；两者都不是“用户看到完整页面”的可靠同义词，也不是业务数据准备完成的保证。现代页面可在事件后继续请求、渲染字体/图片或更新 DOM。用事件作为标记时，必须写清它回答的具体问题，不把一个时间戳冒充整体用户体验。

## 5. CSSOM、样式计算与用于渲染的结构

### 5.1 CSS 文本也要解析

浏览器取得 `styles.css` 后解析规则，形成可由 CSSOM API 观察的样式表/规则对象。无效声明可能被忽略，而不是让整页报错；规则是否胜出还取决于 selector 匹配、origin、importance、层叠、specificity、source order 和继承。这些规则在后续 `ch.css.cascade` 系统学习，本章只需知道：**成功下载 CSS 不等于目标声明成为 computed style。**

```css
main {
  max-width: 42rem;
  margin: 2rem auto;
  padding: 1rem;
}

.status {
  color: #075985;
  font-weight: 700;
}
```

Elements 的 Styles 区可查看匹配规则与被覆盖声明，Computed 区查看浏览器最终计算值。看到 `color` 不对时，应先看目标元素是否匹配 `.status`、声明是否被覆盖、属性是否继承，再考虑 paint。不要在 Styles 临时修改后忘记把变更写回文件并重载验证。

### 5.2 “DOM + CSSOM = render tree”只是入门图

常见教材说 DOM 与 CSSOM 合成 render tree。这有助于理解“存在于 DOM 的节点未必产生可见盒/像素”：head 元素不显示，`display: none` 的元素不生成普通布局盒，伪元素虽不一定是普通 DOM 节点却可绘制。真实引擎会维护 computed styles、layout/fragment tree、property trees、display lists 和 composited layers 等。学习时保留问题而不是死背一个结构名：

1. 哪些节点参与样式计算？
2. 哪些节点/伪元素产生 layout boxes/fragments？
3. 每个 fragment 的尺寸和位置是什么？
4. 哪些视觉内容需要 paint/raster？
5. 哪些内容可独立 composite？

## 6. Layout、Paint、Raster 与 Composite

### 6.1 Layout：在哪里、多大

layout 根据 computed style、包含块、格式化上下文、视口、字体度量、内容和资源固有尺寸计算几何信息。它回答元素/片段的宽高和位置，不负责决定最终每个像素颜色。窗口变宽、字体加载、图片固有尺寸到达、文本变化或影响几何的 CSS 变化，都可能让部分布局失效并重算。

Elements 的 box model 可观察 content/padding/border/margin；`getBoundingClientRect()` 等 API 可观察几何，但读取 API 本身不解释原因。若页面“跳动”，要保存图片尺寸声明、字体时机、前后截图和 layout 事件，不能只凭肉眼说“CSS 抖了”。

### 6.2 Paint：画什么、按什么顺序

paint 把背景、边框、文字、阴影、图片等视觉操作组织为绘制记录/显示列表，并处理 stacking/clip/effect 等。paint 不是立即把每个 DOM 节点变成独立 GPU layer。一个元素在 DOM 和 layout 中存在，却可能被裁剪、透明、遮挡或不在视口；这些都需要结合 computed style、geometry 和 paint/composite 证据判断。

### 6.3 Raster：绘制描述变像素块

raster 把绘制指令和解码后的资源转成可显示的像素/tiles，常会使用 GPU 与并行工作，但具体线程、缓存和 tile 策略是实现细节。图片请求完成也不等于已解码并出现在下一帧；大图的网络、解码、内存和绘制是不同成本。

### 6.4 Composite/Draw：组合并提交一帧

浏览器可把部分内容分层，以便独立滚动、变换、透明度动画或隔离更新，再由 compositor 组合为 frame 并绘制到屏幕。层不是越多越好，每个 DOM 元素也不对应一个 layer。某些视觉变化可跳过 layout 和 paint，只更新合成属性；另一些变化必须重做样式、几何和绘制。

Chromium RenderingNG 把其当前实现细分为 animate、style、layout、pre-paint、paint、commit、layerize、raster、activate、aggregate、draw 等阶段。对零基础读者，先掌握 style/layout/paint/composite 的职责；阅读 Chrome trace 时再映射更细事件，不能把 Chrome 内部阶段当跨浏览器规范。

## 7. DevTools 三个面板如何组成证据链

### 7.1 Network：资源事实

稳定的首次加载记录步骤：

1. 记录浏览器名称与完整版本、OS、视口、页面 URL；
2. 使用干净 profile/访客窗口，或至少记录扩展、代理和 Service Worker；
3. 先打开 DevTools 与 Network，确认录制已开启；
4. 明确 Preserve log、Disable cache、throttling 的状态；
5. 清空旧记录，执行约定 reload；
6. 等待约定的稳定条件，不随意多点页面；
7. 保存 HAR，并另存一份脱敏后的共享副本；
8. 记录预期请求集合与实际差异。

Chrome 的 Disable cache 通常只在 DevTools 打开期间对该上下文生效；不同 reload 菜单、浏览器和版本行为可能不同，所以证据中写操作而非只写“清缓存”。HAR 可能包含 Cookie、Authorization、query、form data、内部域名和响应业务数据。原始 HAR 默认视为敏感工件，不提交公开仓；本章离线 HAR 使用合成值且验证禁止秘密字段。

### 7.2 Elements：当前 DOM 与样式事实

Elements 中看到的是当前 live DOM，不是数据库、React/Vue virtual DOM，也不保证与响应源码逐字相同。保存节点证据时记录稳定 selector/语义路径、关键属性、文本摘要、computed style 和 box。不要依赖工具生成的超长 `nth-child` selector；页面稍变就失效。

Elements 临时编辑很适合验证假设：“若把 `display:none` 关掉是否出现？”但编辑只存在于当前页面状态，reload 后通常消失。正确闭环是：临时实验支持/否定假设 → 回源码修改 → 用相同 URL/动作重载 → 重新保存 Network/DOM/截图证据。

### 7.3 Performance：阶段与时间线事实

Performance recording 把一段时间里的主线程任务、网络、截图、样式、layout、paint/composite 等事件放到时间线上。基线记录必须短而可重复：从 reload 前开始，到页面稳定后结束；保存 trace/JSON、截图与环境。先看 Overview 与截图定位阶段，再放大 Main/Timings/Network/Frames 等轨道；事件名称和颜色只作当前版本线索。

总时长变化不自动等于某阶段退化。录制开销、CPU/网络 throttling、后台程序、扩展、缓存、窗口大小和机器温度都会影响。至少固定输入并重复观察；本章只要求会读一次基线和故障差异，不设脱离环境的毫秒性能门。

### 7.4 三种证据的连接

以 CSS 404 为例：

- Network 证明浏览器请求了 `/assets/styles.css`，响应 404，initiator 是 HTML link；
- Elements 证明 DOM 的 `<main>`/`.status` 存在，但目标 stylesheet/rule 未产生 computed style；
- Screenshot 证明页面有内容但无预期样式；
- Performance/trace 证明导航、解析和 layout/paint 仍发生，但不是目标视觉输入；
- server log/curl 可独立证明路径映射，不由 DevTools 替代。

这条链比“CSS 没生效”强，因为它指出首个偏差发生在资源取得阶段，而非随意修改 selector。

## 8. 最小页面的逐步观察

### 第一步：写预测清单

在启动 server 前写下：主文档、CSS、SVG 三个请求；DOM 中一个 `main`、一个 `h1`、一个 `.status` 和一个带 `alt` 的 `img`；预期 `.status` computed color；首次渲染至少经历 style/layout/paint 记录。预测是后续判断差异的预言，不能在看到结果后改写。

### 第二步：从空目录启动

使用本机现有 Python 标准库即可：

```bash
python3 -m http.server 4173 --directory ./public
```

命令是否可用取决于本机 Python；若课程资产验证只需离线 oracle，不因此安装 Python。浏览器访问 `http://127.0.0.1:4173/index.html`。不要使用生产端口，不绑定 `0.0.0.0` 暴露到局域网，除非明确需要并了解防火墙。

### 第三步：录 Network

打开 Network、清空、启用所需缓存条件、reload。按预测检查三项；点开 CSS 的 Headers、Response、Initiator、Timing。若浏览器额外请求 favicon，记录为非关键差异，不偷偷删记录。

### 第四步：核 DOM 与样式

在 Elements 找到 `.status`，核对 DOM 层级、匹配规则、computed color 和 box。用 View Source/Network Response 对照输入，理解 browser error recovery 或 DOM 变化。临时编辑颜色只用于假设，随后 reload 撤销。

### 第五步：录 Performance

固定 viewport/cache/throttling，从 reload 开始录制数秒后停止。保存 trace 与截图序列，找到 HTML parsing、style/layout、paint/composite 的当前工具证据。不要为了找到漂亮数字重复挑选一次“最好结果”。

### 第六步：关联并写结论

结论至少含：输入与环境、预测、实际请求、DOM/样式、时间线、首个差异、是否修复、同一验证重跑、仍未确认。`200 + DOM 存在 + screenshot 正确` 仍不证明无障碍、安全、跨浏览器或生产性能。

## 9. 两类故障注入与诊断

### 9.1 错误资源路径

把 HTML 的 `href="./styles.css"` 改为 `href="./assets/styles.css"`，但不移动文件。预测：主文档 200，CSS 404，DOM 仍有内容，computed style 缺目标规则，截图呈现无样式版本。

按证据顺序：

1. Network 是否出现 CSS 请求？若没有，先查 link 语法/解析/过滤；
2. URL 是否与文件路径预言一致？
3. status、Content-Type、Response 是什么？
4. initiator 是否指向目标 link？
5. Elements 中 DOM 是否存在，目标规则/stylesheet 是否缺失？
6. 修正路径，reload 后用同一清空/缓存条件重录；
7. 断言 CSS 200、规则出现、截图恢复。

不要先在 Elements 手写颜色，因为那绕过了失败阶段；也不要因为服务器终端没报错就断言资源成功。

### 9.2 阻塞或迟到资源

实验可用受控 server 为 CSS 延迟固定时间，或在 DevTools 本地 throttling 下观察。预测：HTML 可以开始下载/解析，CSS 请求长时间 pending，首次目标样式/渲染时机后移。保存瀑布与 Performance，而不是用肉眼秒表。

首个可信证据可能是 CSS Timing 中的等待、瀑布与截图之间的对应；但不能只凭一条长 CSS 就声称服务器根因。要用 curl/server trace 区分请求排队、服务端等待和下载。修复可以是更正故障夹具或移除人为延迟；本章不开展 bundling、critical CSS 或 JavaScript 优化方案。

### 9.3 诊断矩阵

| 现象 | 先看 | 可能阶段 | 不应先做 |
|---|---|---|---|
| 页面完全空白 | 主文档 status/body、Console、DOM | 导航/响应/解析 | 盲改 CSS |
| 有文字但无样式 | CSS request/status/type、Styles | 资源取得/CSS 解析/层叠 | 先改布局尺寸 |
| 元素 DOM 中存在但不可见 | computed style、box、clip/opacity | style/layout/paint | 重启后端 |
| 图片破损 | image URL/status/type/response | 子资源/解码 | 改 `z-index` |
| 页面第一次显示晚 | Network timing、截图、Performance | 网络/阻塞资源/渲染 | 只看总 load 时间 |
| View Source 与 Elements 不同 | Response、parser recovery、DOM 变更 | 解析/运行时修改 | 宣称浏览器随机改源码 |
| DevTools 改好，reload 又坏 | 源文件与本地 override | 只改了 live DOM/style | 把截图当修复提交 |

## 10. FactoryCare 场景：工单详情首屏

FactoryCare Vue 管理端最终会复杂得多，但首个 Web 平台实验不用 Vue。做一页静态“工单 WO-1001”：标题、状态、设备摘要、负责人和状态图。它只用 HTML/CSS/SVG，目标是观察浏览器输入与渲染管线，而非提前实现登录、API 或组件状态。

预期证据：

- `/work-order.html`、`/work-order.css`、`/status.svg` 请求都可从 HAR 找到；
- DOM 中 `main`、`h1`、状态文本和有 `alt` 的 `img` 可由保存快照核对；
- `.work-order-status` 的 computed style 来自指定 stylesheet；
- timeline 包含对应导航、解析和渲染阶段，截图能与请求时刻对应；
- 故障版 CSS 路径 404 时，首个差异是网络资源而非 FactoryCare 后端；
- 修复后用同样的 URL、viewport、cache 和 reload 重跑。

页面中使用合成工单号/设备名，不放真实客户、Cookie、Token 或内网域名。后续接真实 API 时，Network/HAR 的隐私风险更高；FactoryCare 设计要求日志与工件不得泄漏 session/token/个人数据。

“页面能画出来”也不证明语义 HTML、键盘、屏幕阅读器、响应式、业务授权或数据正确。这些在卷 07 后续章节和后端安全契约分别验证。本章只建立请求、解析和渲染的可观察基线。

## 11. 安全、隐私与证据诚实

### 11.1 HAR 与截图默认敏感

HAR 可含 request/response headers、Cookie、query、form payload、响应正文、内部地址和时间信息。截图会含姓名、设备、工单、聊天和浏览器书签。共享前使用合成环境重录，或按字段清单脱敏；脱敏后重新验证 JSON/HAR 可读且关键证据未被破坏。不要把真实生产 HAR 放进公开 issue。

### 11.2 DevTools 可修改不等于拥有权限

用户能在自己的浏览器隐藏按钮、改 DOM 或重放请求。服务端不能相信 UI 隐藏或 DOM 文本；FactoryCare 权限必须在 Java 服务端按当前 actor/tenant/data scope 重建并拒绝越权。Elements 的本地修改既不会授权，也不是持久业务事实。

### 11.3 工具截图不是绝对真相

DevTools 可能漏掉打开前的请求、因过滤器隐藏记录、因 Preserve log 混入旧页面、因扩展/代理添加流量。Performance 录制也有开销和版本差异。证据要有环境、时间范围、原始工件、预言与独立 HTTP/服务端核对。无法复现的漂亮截图只能是线索。

## 12. 边界：本章明确不解决什么

- 不优化长任务、事件循环、layout thrashing 或 JavaScript bundle；这些属于后续 JavaScript 性能章节；
- 不系统教授 CSS 层叠、盒模型、Flex/Grid、动画；这里只识别渲染阶段；
- 不实现 Vue、组件、响应式状态或 hydration；
- 不深入 Cookie、同源、CORS 与浏览器缓存规则；下一章专门建立模型；
- 不把 Chrome RenderingNG 内部结构要求为 Firefox/WebKit 相同实现；
- 不把一次本机 trace 当成生产用户性能、Core Web Vitals 或跨设备结论；
- 不以视觉截图替代语义、无障碍、安全和业务验收。

一个不应由本章方案解决的反例：页面点击后因 JavaScript 在主线程计算五秒而卡住。Performance 可以帮助观察长任务，但如何改算法、切分任务、使用 Worker 或减少 layout thrashing 不属于本章；此处只保存基线并把问题路由到 `ch.js.browser-performance`。

## 13. 独立构建任务

从空目录完成，不复制配套成品：

1. 写一个含 HTML、外部 CSS 和一张本地 SVG 的 FactoryCare 静态页；
2. 写预测表：请求 URL/status/type、DOM selector、computed style、渲染阶段；
3. 用本地 HTTP server 打开，记录命令、端口、浏览器/OS/viewport/cache；
4. 保存一份已脱敏 HAR、一份 DOM 结构摘要、至少两张加载截图和一份 Performance trace；
5. 注入一个错误 CSS 路径，定位第一证据；
6. 修复并用相同操作重跑，保留红/绿结果；
7. 再用受控延迟或 throttling 观察阻塞资源，说明测量限制；
8. 写残余风险：未验证的浏览器、设备、网络、无障碍与生产后端。

关闭 AI 后，随机更改资源目录或 CSS selector，不看答案在 15 分钟内恢复，并用 Network→Elements→Performance 的顺序口述证据。能修好但无法解释第一差异，不能算独立诊断完成。

## 14. 两分钟复述模板

> 导航先取得主 HTML；浏览器可以边下载边按 HTML parsing rules 构造 DOM，并发现 CSS、图片等子资源。CSS 被解析并参与样式计算，随后 layout 决定几何，paint 生成绘制描述，raster 转成像素，composite 把可显示内容组合成帧。真实管线会并发、增量和跳过阶段，所以不能把它当严格瀑布。Network 证明请求/响应与 initiator，Elements 证明当前 DOM、匹配规则和 computed style，Performance 证明所录时间窗内的阶段。错误 CSS 路径时先看 Network 的 URL/status，而不是盲改 selector；修复后按同一环境重录。HAR/截图可能泄密，Chrome 的事件名与线程是版本实现细节。本章只观察和解释，不优化 JavaScript 性能。

## 15. 速查与间隔复习

| 问题 | 首要证据 | 常见误判 |
|---|---|---|
| 浏览器是否请求资源 | Network URL/initiator/status | DOM 有引用就等于请求成功 |
| 服务器返回了什么 | Headers/Response/curl | Preview 看起来正常就等于 MIME/状态正确 |
| 当前页面有哪些节点 | Elements live DOM | 把它当原始 HTML |
| CSS 是否最终应用 | matched rules + Computed | CSS 200 就必然生效 |
| 元素是否有几何盒 | box/layout evidence | DOM 存在就一定可见 |
| 为什么某时刻出现像素 | screenshot + trace events | `load` 等于视觉完成 |
| 修复是否持久 | 源文件修改 + reload 重跑 | DevTools 临时编辑截图 |

复习节奏：当天画一次管线；第 2 天不看书解释 CSS 404 的证据顺序；第 7 天重做故障；第 21 天用另一个浏览器比较界面与稳定概念。复习记录“我先猜错了什么”，不要只保存成功截图。

## 16. 自检题

1. HTML Response 和 Elements DOM 为什么可能不同？
2. CSS 请求 200 但样式不生效，至少列出四个检查点。
3. layout、paint、composite 分别回答什么？
4. 为什么不是每次视觉变化都重走全部管线？
5. Network 瀑布长条为何不能直接证明后端慢？
6. 一张页面截图能证明哪些事实，不能证明哪些？
7. 为什么 `file://` 不适合作为本章 HTTP 证据？
8. 如何让错误资源路径的红灯和修复绿灯可比较？
9. HAR 为什么应默认视为敏感？
10. 哪类问题应移交 JavaScript 性能章节，而不是在本章解决？

## 17. 官方主来源与版本边界

下列来源于 **2026-07-17** 核验。HTML/CSS 的规范语义相对稳定；Living Standard、浏览器实现与 DevTools UI 持续变化，复现实验时必须记录实际浏览器完整版本。

- [WHATWG HTML：Browsing the web](https://html.spec.whatwg.org/multipage/browsing-the-web.html)：导航与 Document 生命周期的规范入口；
- [WHATWG HTML：Parsing HTML documents](https://html.spec.whatwg.org/multipage/parsing.html)：`text/html` 解析为 DOM tree 的 tokenizer/tree builder 与错误恢复规则；
- [WHATWG HTML：Documents](https://html.spec.whatwg.org/multipage/dom.html)：HTML Document 的结构与可观察模型；
- [CSSWG：CSS Object Model (CSSOM)](https://drafts.csswg.org/cssom/)：样式表、规则和 CSS 对象模型；
- [Chromium RenderingNG architecture](https://developer.chrome.com/docs/chromium/renderingng-architecture)：Chromium 当前 style/layout/paint/layerize/raster/draw 等实现阶段；它不是跨浏览器强制架构；
- [Chrome DevTools Network panel](https://developer.chrome.com/docs/devtools/network/overview)：请求记录、Headers/Response/Initiator/Timing、HAR 与加载条件；
- [Chrome DevTools DOM/Elements](https://developer.chrome.com/docs/devtools/dom/)：查看和临时改变 live DOM；
- [Chrome DevTools Performance](https://developer.chrome.com/docs/devtools/performance)：录制、截图、主线程与渲染事件；官方页面提示示例 UI 基于特定 Chrome 版本，其他版本可能不同。

记住：**先写预言，再在正确面板找第一差异；把网络、结构和时间线连成证据，不把实现细节、截图或感觉冒充因果。**
