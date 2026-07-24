---
schema_version: 2
edition: 2026.2-draft
id: ch.web.media-assets
title: 图片、响应式资源、音视频与资源边界
responsibility: 为图片、音视频和下载资源选择正确的语义元素、格式与替代内容，只处理资源声明和交付边界，不做 CSS 响应式布局。
volume: '07'
order: 5
level: L1
status: drafting
path: book/volume-07-web-platform/chapters/ch.web.media-assets.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.web.semantic-html
version_surfaces:
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
  text: 在 120 秒内解释“图片、响应式资源、音视频与资源边界”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - web-responsive-images
  - web-media-resource-boundary
  covers_topics:
  - html.img-alt
  - html.picture-source
  - html.srcset-sizes
  - web.image-format-selection
  - html.audio-video-controls
  - html.media-track
  - web.asset-url
  - web.asset-loading-failure
  uses_capabilities:
  - foundation.http-message
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“图片、响应式资源、音视频与资源边界”构建可运行程序与测试：制作包含响应式图片、字幕视频和失败回退的媒体样例页；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - web-responsive-images
  - web-media-resource-boundary
  covers_topics:
  - html.img-alt
  - html.picture-source
  - html.srcset-sizes
  - web.image-format-selection
  - html.audio-video-controls
  - html.media-track
  - web.asset-url
  - web.asset-loading-failure
  uses_capabilities:
  - foundation.http-message
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: browser-inspection-network-observation-fallback-check
- id: diagnose
  kind: fault-diagnosis
  text: 面对“错误 srcset、缺失替代文本或资源 MIME 不匹配造成的媒体失败”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - web-responsive-images
  - web-media-resource-boundary
  covers_topics:
  - html.img-alt
  - html.picture-source
  - html.srcset-sizes
  - web.image-format-selection
  - html.audio-video-controls
  - html.media-track
  - web.asset-url
  - web.asset-loading-failure
  uses_capabilities:
  - foundation.http-message
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 图片、响应式资源、音视频与资源边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《语义 HTML、文档结构与元数据》](ch.web.semantic-html.md)：媒体元素的替代内容、figure 关系和文档语义依赖已验证的 HTML 结构。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套工件使用静态 HTML、SVG、WebVTT、资源清单和浏览器观察矩阵建立离线证据；离线绿灯只证明声明与预言一致，不下载或解码真实照片/视频，也不证明目标浏览器会选择某个候选。易变事实已于 **2026-07-17** 对照 WHATWG HTML Living Standard、W3C WAI Images/Audio and Video 与 WebVTT 一手资料核验。

网页媒体不是“把文件路径塞进标签”。一张图先要回答它在当前上下文中表达什么，再决定 `alt`、`figure`、候选集合和格式；浏览器会把 `srcset`、`sizes`、视口、像素密度、格式支持和自身策略组合，选出实际 URL；服务器又必须用正确状态、MIME、缓存与授权交付。视频还要有用户可操作 controls、字幕/文字稿和可达的失败回退。

本章只建立**声明—选择—请求—解码—替代/回退**证据链。它不教 CSS 如何把卡片改成两栏或在断点重排；`sizes` 会描述后续 CSS 产生的图片槽位，但布局规则本身留给 CSS 章节。它也不实现上传控件、对象存储、转码服务或播放器脚本。

## 1. 完成定义、边界与证据入口

完成本章，应能：

1. 根据图片在当前页面中的目的，写出信息性、装饰性、功能性或复杂图片的替代方案；
2. 解释 `src`、`srcset`、width/density descriptor、`sizes`、`picture/source/type/media` 各自输入什么，浏览器而非作者最终选择哪个候选；
3. 为照片、透明图、图标/示意图选择格式并写清质量、体积、支持、缩放和安全权衡；
4. 用 `audio`/`video` 原生 controls、多个 source、poster、track 与可见文字稿建立最低可用媒体页；
5. 从页面 URL 算出相对资源 URL，在 Network 中检查最终 URL、状态、Content-Type、传输/缓存与 `currentSrc`；
6. 说明元素内 fallback、资源加载错误、字幕失败和可见下载/文字稿链接并不是同一种回退；
7. 用固定视口、DPR、格式支持和资源状态矩阵先预测、再观察候选/替代/失败结果；
8. 注入错误 `srcset`、缺失 `alt`、MIME 不匹配，指出首个可信证据，修复后重跑原矩阵。

配套入口：

- [响应式图片、字幕视频与失败回退示例](../../../examples/encyclopedia/ch.web.media-assets/README.md)
- [资源声明与交付故障实验](../../../labs/encyclopedia/ch.web.media-assets/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.web.media-assets/README.md)

canonical oracle 要求不同视口和资源可用性下，浏览器选择的候选、替代文本和失败回退与预先记录矩阵一致。教材 oracle 不运行浏览器；正式 G4 证据必须补充目标浏览器版本、视口、DPR、缓存条件、Network、`currentSrc`、字幕/回退任务与服务端响应头。

## 2. 先画媒体加载管线

```text
HTML 元素与属性
  → URL 解析 / 候选集合解析
  → 浏览器结合环境选择资源
  → HTTP 请求、缓存或策略阻断
  → MIME/格式识别、下载与解码
  → 渲染媒体或进入错误状态
  → 替代文本、字幕、文字稿、下载/故障回退承担不同任务
```

诊断时不要把所有失败叫“图片挂了”。

- DOM 没有 `img`：作者标记/解析阶段；
- `srcset` 无效导致候选被忽略：候选解析阶段；
- `currentSrc` 不是预期：选择预言或环境条件错误；
- Network 404：URL/部署阶段；
- 200 却 Content-Type 是 `text/html`：服务器路由/MIME 阶段；
- 状态与 MIME 正常却无法显示：格式/内容/解码阶段；
- 图能显示但无等价文本：内容与无障碍阶段；
- 字幕文件 200 但没有字幕：track 声明、CORS、WebVTT 语法/时序或用户设置阶段。

“页面上出现像素”只是其中一条路径成功，不能证明替代内容、候选效率、字幕或授权正确。

## 3. `img` 与 `alt`：替代的是目的，不是像素清单

### 3.1 信息性图片

若图片传递页面没有重复表达的信息，`alt` 应简洁提供同等目的。FactoryCare 故障照片若用于说明“泵体接口处有油迹”，合适文本可写：

```html
<!-- Responsibility: 展示能帮助理解故障的静态教学照片。 -->
<!-- Data source: synthetic-pump-leak 教学资源，不含真实工厂或人员信息。 -->
<!-- Mapping: alt 传达诊断所需的可见事实；编号和拍摄时间由相邻文字提供。 -->
<!-- Side effects: 浏览器可能按资源 URL发起 GET；元素本身不修改工单。 -->
<img src="./assets/pump-leak-960.jpg"
     width="960" height="640"
     alt="冷却泵进水接口下方有一条深色油迹">
```

不要写“图片”“故障照片”或文件名；读者已能从元素语境知道这是图片。也不要把未能从像素确认的诊断结论写进 alt，例如把油迹直接断言为“密封圈破裂”。替代文本表达图在这页的功能，而不是逐像素口述。

### 3.2 装饰性图片

纯装饰、信息已由相邻文字完整提供且图片不承担链接/按钮功能时，使用空 `alt=""`，让常见辅助技术忽略重复内容。**空 alt 与缺失 alt 不同**：空值是作者明确选择装饰角色；缺失值会进入规范的错误/回退处理，也使文件名等被读出的风险增加。

判断装饰性要看上下文。同一扳手图标放在标题旁只是装饰，可空 alt；若它单独表示“维修中”状态，就传递信息，不能空。CSS 背景图通常不会形成内容替代，因此承载业务信息的图不能只放背景。

### 3.3 功能性图片

图片在链接或按钮中承担操作时，替代文本描述**动作/目的**，不是画面：

```html
<!-- Responsibility: 链接到工单附件原图；图片是唯一可见链接内容。 -->
<!-- Data source: 教学缩略图与保留域名 URL；生产下载必须经附件授权。 -->
<!-- Mapping: alt 描述“查看原图”动作，不重复文件像素。 -->
<!-- Side effects: 激活链接会导航到资源 URL，但不会改变业务状态。 -->
<a href="./assets/pump-leak-original.jpg">
  <img src="./assets/pump-leak-thumb.jpg" alt="查看故障照片原图">
</a>
```

若链接同时有可见“查看原图”文字，图片通常可空 alt，避免名称重复。准确可访问名称的计算留给下一章，但本章要避免媒体重复制造噪声。

### 3.4 复杂图片

流程图、趋势图和现场总图可能需要超过一句 alt。做法通常是：alt 简短识别图的目的，页面附近提供结构化长说明、数据表或链接；不要把几百字塞进 alt。`figure`/`figcaption` 可以为图组提供可见标题，却不自动替代 `img alt`。一张趋势图的图注“图 1：过去 24 小时振动”与等价数据表承担不同角色。

### 3.5 文本图片与敏感内容

能用真实文本就不用图片承载文字；真实文本可缩放、选择、翻译并适应高对比/主题。若截图不可避免，alt/长说明仍要给任务所需文字。故障照片可能包含人员面孔、铭牌、地理位置与 EXIF；发布前做隐私、授权、元数据与保留策略审查。替代文本同样会被索引/日志/读屏器读取，不能泄露原图被权限保护的信息。

## 4. 固有尺寸、URL 与基础加载

`src` 是资源地址。相对 URL 按文档 base URL 解析，不按开发者本机目录猜测。页面从 `/app/work-orders/42` 打开时，`assets/a.jpg`、`./assets/a.jpg` 和 `/assets/a.jpg` 可能落到不同路径；构建器的 base path、CDN 前缀和 hash 文件名还会改变部署 URL。

`width`/`height` 属性给出图的固有尺寸线索，浏览器可在文件下载前保留纵横比空间，减少布局跳动。它们不是 CSS 响应式规则，也不意味着浏览器一定按该像素显示；实际布局由 CSS 和容器决定。错误的比例会造成失真或布局不稳，需与资源元数据核对。

`loading="lazy"`、`decoding`、`fetchpriority` 等是提示或策略输入，不是性能保证。首屏关键图是否 lazy、优先级是否合理，需要用真实性能与网络证据；本章不机械给所有图片加同一属性。

Network 最小检查表：

- Request URL 是否是部署后最终 URL；
- status 是 200/304/206/404/403 还是被策略阻断；
- response `Content-Type` 是否与实际格式匹配；
- transferred/cache 线索与响应缓存头是否一致；
- initiator 是否对应目标 `img/source/video/track`；
- response body 是否其实是 SPA HTML fallback 或登录页；
- DOM `currentSrc`、`naturalWidth`/`naturalHeight` 与预言是否相符。

## 5. `srcset`：描述候选，不是命令浏览器

### 5.1 像素密度 descriptor

当资源固有尺寸不同但显示槽位相同，可写：

```html
<!-- Mapping: 两个候选内容相同，仅像素密度不同；浏览器根据环境选择。 -->
<img src="./assets/pump-480.jpg"
     srcset="./assets/pump-480.jpg 1x, ./assets/pump-960.jpg 2x"
     width="480" height="320"
     alt="冷却泵进水接口下方有一条深色油迹">
```

`1x/2x` 是 density descriptor，不是“宽屏/窄屏”。高 DPR 只是选择输入之一，浏览器还可考虑缓存、网络、实现策略。不要声称 2x 设备必然请求 2x；用 `currentSrc` 和 Network 观察。

### 5.2 width descriptor 与 `sizes`

当候选按固有宽度列出，写 `480w`、`960w` 等；数值必须与文件固有宽度诚实对应。`sizes` 告诉浏览器，在匹配条件下**图片在布局里预计占多宽的槽位**，浏览器据此结合 DPR 选候选：

```html
<!-- Responsibility: 声明同一故障照片的宽度候选，不定义页面布局。 -->
<!-- Data source: 三个候选由同一许可原图生成，裁剪和色彩语义一致。 -->
<!-- Mapping: sizes 必须与后续 CSS 槽位契约同步；它不是资源文件宽度列表。 -->
<!-- Side effects: 浏览器可选择并请求一个候选；选择不由作者逐视口强制。 -->
<img src="./assets/pump-960.jpg"
     srcset="./assets/pump-480.jpg 480w,
             ./assets/pump-960.jpg 960w,
             ./assets/pump-1440.jpg 1440w"
     sizes="(max-width: 40rem) 100vw, 40rem"
     width="960" height="640"
     alt="冷却泵进水接口下方有一条深色油迹">
```

`sizes` 列表按规则寻找适用源大小；它不是 CSS，不会把元素真的改成 `40rem`。若 CSS 后来把槽位改为 50vw 而 sizes 仍写 100vw，页面可能显示正常却下载过大资源。这里记录契约，真正的布局/断点在 CSS 章节完成。

同一个 `srcset` 不要混用 width 与 density descriptors；重复/无效 descriptor 可能让候选或整个属性无效。URL 中的逗号、空白、查询字符串也要按语法处理，不手写脆弱分割器。课程 oracle只检查固定子集，真实解析以浏览器为准。

### 5.3 为什么不能硬编码“视口→文件”

候选选择可近似理解为：从 `sizes` 得到 source size，乘以设备像素密度得到需要的资源密度，再由浏览器选合适候选。但用户缩放、DPR、缓存、节省数据、实现启发式和环境变化都会影响。验收矩阵写“预期候选/允许候选集合”，同时记录实际 `currentSrc`，不要把实现策略假装成业务不变量。

## 6. `picture`：格式切换与 art direction

`picture` 为内部 `img` 提供多个 source sets。它本身不显示内容，必须以 `img` 作为最后的承载/回退元素，alt 也写在 `img`：

```html
<!-- Responsibility: 为同一现场照片提供格式候选；不改变图片表达的事实。 -->
<!-- Data source: AVIF/WebP/JPEG 均来自同一许可原图和同一裁剪。 -->
<!-- Mapping: source type 用于格式选择，最终语义与 alt 由 img 承担。 -->
<!-- Side effects: 浏览器根据格式支持和候选算法请求一个 URL。 -->
<picture>
  <source type="image/avif"
          srcset="./assets/pump-480.avif 480w, ./assets/pump-960.avif 960w"
          sizes="(max-width: 40rem) 100vw, 40rem">
  <source type="image/webp"
          srcset="./assets/pump-480.webp 480w, ./assets/pump-960.webp 960w"
          sizes="(max-width: 40rem) 100vw, 40rem">
  <img src="./assets/pump-960.jpg"
       srcset="./assets/pump-480.jpg 480w, ./assets/pump-960.jpg 960w"
       sizes="(max-width: 40rem) 100vw, 40rem"
       width="960" height="640"
       alt="冷却泵进水接口下方有一条深色油迹">
</picture>
```

source 顺序重要：浏览器取首个满足 media/type 等条件的适用 source，再从其集合选候选。`type` 应是真实 MIME；声明 AVIF 却返回 JPEG 会把错误推到交付/解码层。

`media` 可做 art direction：窄屏选择紧裁图、宽屏选择环境全景。它不是为了同一照片的分辨率切换——那用 srcset。不同裁剪必须保持语义等价，alt 描述在所有候选中都成立；若窄图裁掉关键裂纹，就不是合格候选。不要在 HTML 中复制 CSS 的每个断点，只有内容构图确实变化才用 art direction。

## 7. 图片格式选择：先看内容和证据

常见起点而非绝对规则：

| 内容 | 候选格式 | 优势 | 风险/验证 |
|---|---|---|---|
| 照片 | AVIF/WebP/JPEG | 有损压缩、现代格式可显著减小 | 编解码支持、编码成本、细节/色偏、fallback |
| 透明截图/像素图 | PNG/WebP/AVIF | 无损或透明 | PNG 可能大，现代格式工具链需验证 |
| 图标/线稿/简单示意 | SVG | 可缩放、文本化 | 外部内容、安全清洗、字体/滤镜兼容 |
| 动画 | animated WebP/AVIF/GIF 或 video | video 常更高效且可控 | 动画暂停、无障碍、兼容、poster/文字替代 |

“AVIF 永远最好”“SVG 永远最小”都不成立。用同一源、相同视觉质量目标，在目标浏览器测文件大小、解码、清晰度和支持；保留许可/原始资产与生成参数。不要把生产工单附件重新编码成网站静态资产而丢失证据完整性；展示缩略图与原始附件是两种对象。

SVG 可内联或作为 `img` 加载，脚本/外链/foreignObject 等安全面不同。用户上传 SVG 不能因为扩展名是图片就直接信任。FactoryCare 附件服务必须验证内容、隔离/扫描、授权下载；前端格式选择不替代这些边界。

## 8. `audio`、`video` 与原生 controls

### 8.1 可操作的最低基线

```html
<!-- Responsibility: 播放固定教学检修片段并提供字幕与可见文字稿入口。 -->
<!-- Data source: synthetic-inspection-demo 媒体清单；不引用真实人员或厂区。 -->
<!-- Mapping: source/type 对应编码表示，track 对应同版本 zh-CN 字幕。 -->
<!-- Side effects: 播放会请求媒体/字幕并产生本机播放状态，不修改 FactoryCare 工单。 -->
<video controls preload="metadata" width="960" height="540"
       poster="./assets/inspection-poster.svg">
  <source src="./assets/inspection-demo.webm" type="video/webm">
  <source src="./assets/inspection-demo.mp4" type="video/mp4">
  <track kind="captions" src="./assets/inspection.zh-CN.vtt"
         srclang="zh-CN" label="简体中文字幕" default>
  <p>此浏览器不支持 video 元素。请阅读下方文字稿。</p>
</video>
<p><a href="./inspection-transcript.html">阅读检修视频文字稿</a></p>
```

`controls` 让浏览器提供播放、暂停、进度、音量等原生界面，是无脚本基线。实际键盘/读屏器可用性仍需目标组合测试。不要无理由隐藏 controls 造自定义播放器；那会立刻承担键盘、名称、状态、时间、字幕菜单与全屏等大量行为。

`preload` 是提示，不保证浏览器完全照做。`autoplay` 常受策略阻止，且突发声音/运动会伤害用户体验；不要把自动播放当主要内容可达路径。`poster` 是播放前画面，不替代视频的字幕/描述/文字稿。

### 8.2 多个 media source

在 audio/video 中，`source src` 给替代媒体资源，`type` 帮浏览器在下载前判断支持。容器名不足以完整描述 codec，复杂场景可包含 codecs 参数，但必须由真实编码管线生成和验证，不能照抄。source 顺序、服务器 MIME 和实际字节三者要一致。

图片 `picture source` 用 `srcset`，媒体 source 用 `src`；两者资源选择算法不同。把 picture 写法复制到 video 是常见错误。

### 8.3 字幕、描述与文字稿

`track` 常见 kind：

- `captions`：同语言对白和重要非语言声音，服务听不见音频的用户；
- `subtitles`：翻译/转写对白，通常假设能听见其他声音；
- `descriptions`：视频视觉内容的音频描述文本轨；
- `chapters`：章节导航；
- `metadata`：脚本数据，不展示给用户。

字幕文件可用 WebVTT：带 `WEBVTT` 头、时间 cue 与文本。字幕必须与对应媒体版本同步，包含说话者区分与关键声音，而不是自动转写后不校对。`srclang`/label 要准确，`default` 只表作者偏好，用户设置和浏览器仍可决定显示。

文字稿是可搜索、可复制的完整文本，可包含视觉说明；它不能永远替代同步 captions，反之字幕也未必等于完整文字稿。直播、预录、只有音频/只有视频的 WCAG 要求不同，产品需按内容类型制定政策。

### 8.4 fallback 的真实边界

`video` 内普通文本主要面向不支持该元素的 user agent；现代浏览器支持 video 但所有 source 404/解码失败时，不能假设内部段落一定作为可见错误回退。把文字稿/下载链接放在元素外，或在后续 JS 章节监听错误并显示经过测试的状态。即使脚本回退存在，真实错误、焦点和读屏器通知还要验证。

## 9. 资源 URL、HTTP 与下载边界

媒体请求复用 `foundation.http-message`：URL、method、status、headers、body。图片通常 GET；视频可能发 range request 并得到 206，是否发生取决于浏览器/服务器/资源。不要看到 206 就断言“视频成功”，仍要检查 Content-Range、MIME、解码和播放。

关键响应头/行为：

- `Content-Type` 与真实表示相符；
- 缓存策略符合资源是否内容寻址/是否私有；
- 字节范围、Content-Length、压缩和 CDN 转换不破坏媒体；
- 跨源资源需要的 CORS/CSP/referrer 策略按实际使用场景配置；
- 私有附件不因静态 URL、对象键或 CDN 缓存变公开；
- 下载响应的文件名/Content-Disposition 与类型安全处理明确。

`<a download>` 是客户端提示，不是访问控制，也可能受跨源/响应行为影响。服务器必须授权当前主体、限制内容嗅探/危险内联类型，并使用安全文件名。给用户显示文件扩展名不能证明实际 MIME。

### 9.1 FactoryCare 静态资产与附件是两类资源

前端 logo、教学 poster、构建产物可部署为公开/内容寻址静态资产；报修照片和工单附件属于业务对象。FactoryCare 当前合同中附件最终归属 `REPORT` 或 `WORK_ORDER`，状态包括 `PENDING_UPLOAD`、`SCANNING`、`AVAILABLE`、`QUARANTINED`、`REJECTED`；只有经当前主体与父资源范围授权、状态允许的对象才能展示/下载。

上传意图接受 purpose、fileName、size、mime、sha256，返回短期受约束上传指令；完成上传还要校验元数据/哈希并可能等待扫描。前端 `<img src>` 或 `<a href>` 不承担这些服务端规则。对象存储键、可猜 URL、alt 中的文件名都不能作为授权。

若使用短期签名 URL，要考虑过期、刷新、缓存与错误 UX。证据应记录应用授权接口与最终对象请求，不能把完整签名 URL、Cookie 或真实文件放进课程仓库。

## 10. 失败分类与首个可信证据

### 10.1 错误 `srcset`

故障例：候选写 `480w` 却实际文件宽 960，或混用 `480w, image@2x 2x`。视觉上可能仍有 fallback src，于是“图片显示”掩盖错误。诊断：先看 DOM 属性原值/控制台，再看 `currentSrc` 与 Network；首证据是候选语法/声明不满足约定或选择与矩阵首次分歧，不是最终像素看起来模糊。

修复：从构建清单生成真实宽度与 hash，使用一种 descriptor，width descriptor 时同步 sizes。用同一视口/DPR/缓存矩阵重跑，记录允许候选。残余风险：浏览器启发式、未来 CSS 槽位变化。

### 10.2 缺失替代文本

故障：信息图片没有 alt。Network 200、像素正常都不反驳。首证据是 DOM `img` 缺失 alt 与内容分类清单冲突。修复前先判断图目的；信息图写等价文本，装饰图明确 `alt=""`，功能图描述动作。重跑静态检查和目标读屏任务。残余风险：文字虽存在但不准确、泄密或与其他候选不等价。

### 10.3 MIME 不匹配

故障：`inspection-demo.mp4` 请求 200，但返回 `text/html` 登录页/SPA fallback，或 source 声明 `video/mp4` 实际是别的字节。首证据是 Network response URL/status/Content-Type/body 与 manifest 不一致；播放器错误只是后续结果。

修复服务器路由、MIME 与真实编码，不通过随意改扩展名/`type` 属性掩盖。重跑同一 URL、清缓存条件和播放/字幕任务。残余风险：codec 支持、range、CORS、CDN 缓存的旧错误表示。

### 10.4 失败日志模板

```text
fixture: media-page-v1@sha256:...
environment: browser/version, viewport, DPR, cache state, format support
prediction: picture source=webp; img currentSrc=pump-960.webp; alt=...
first_divergence: GET /assets/pump-960.webp → 200 text/html
stage: HTTP representation / MIME
excluded: source selection selected the predicted URL; DOM alt present
repair: static route returns image/webp bytes for the same URL
rerun: same matrix row and cache condition; decode/display succeeds
residual_risk: other browsers, data-saver and CDN edge cache unverified
```

## 11. 观察矩阵：先预测再打开 DevTools

至少记录：

| case | viewport | DPR | format support | resource state | 预期/允许候选 | alt/字幕/回退预言 |
|---|---:|---:|---|---|---|---|
| narrow-1x | 360 | 1 | AVIF/WebP | all 200 | 480w modern | 信息 alt；中文字幕可选 |
| narrow-2x | 360 | 2 | WebP | all 200 | 960w WebP | 同一 alt |
| wide-1x | 1280 | 1 | JPEG only | all 200 | 960w JPEG fallback | 同一 alt |
| image-404 | 800 | 1 | WebP | selected 404 | selected URL fails | alt 仍表达目的 |
| video-mime | 960 | 1 | MP4 | 200 text/html | MP4 selected then error | 外部文字稿仍可达 |
| captions-404 | 960 | 1 | MP4 | video 200, VTT 404 | video may play | 字幕失败，文字稿可达；不得称通过 |

浏览器可能不按简化计算选择唯一文件，所以矩阵把“允许集合”与“实际 currentSrc”分开。对失败行检查可见/可听任务，不只检查控制台。重复时明确缓存开关，否则第二次请求可能来自缓存而改变 Network。

## 12. 常见误解与更正

| 误解 | 为什么错 | 更可靠规则 |
|---|---|---|
| alt 就是图的标题 | 它提供不可见图时的等价目的 | 按信息/装饰/功能/复杂上下文写 |
| 空 alt 等于没写 | 空值是明确装饰选择 | 缺失 alt 是作者错误风险 |
| figcaption 可以替代 alt | 图注与替代内容职责不同 | 需要时两者各自准确 |
| 2x 设备必下 2x | 浏览器掌握最终选择 | 记录 currentSrc/Network，不硬编码 |
| sizes 会改变布局 | 它只给候选选择提供槽位预言 | CSS 决定实际布局 |
| picture 是 img 的可见外壳 | picture 本身不显示 | 最后仍需 img 与 alt |
| AVIF 永远最小最好 | 内容、质量、支持/解码不同 | 对同源目标质量实测 |
| video 内文本会在任何 404 时显示 | 支持元素但资源失败不保证该回退 | 提供元素外文字稿/下载与实测错误 UX |
| track=字幕就已无障碍 | 字幕质量、同步、默认/用户选择仍需验 | 人工校对并做任务测试 |
| download 属性保护附件 | 只是浏览器提示 | 服务端授权、状态、MIME 与安全文件名 |

## 13. 独立实验：从空目录复现

目标：制作响应式图片、字幕视频与失败回退样例，保存固定矩阵，再注入三类故障。

### 13.1 工件要求

- 完整语义 HTML，四类意图注释；不写 CSS 布局；
- `picture` 至少两个格式 source，末尾 img 有 src/srcset/sizes/width/height/准确 alt；
- 一张明确装饰图使用 `alt=""`，并在清单解释为什么；
- video 有 controls、poster、至少两个 source、captions track 与元素外文字稿链接；
- WebVTT 有合法头、时间 cue、说话者/关键声音；
- manifest 记录每个 URL、实际 MIME、宽高/格式/角色和许可来源；
- observation matrix 覆盖窄/宽、DPR、格式 fallback、404/MIME/caption failure；
- 不提交真实 FactoryCare 附件、签名 URL、token 或未经许可媒体。

### 13.2 执行

复制 lab 到空目录，运行唯一 `verify.sh`，确认离线契约绿灯。随后启动获批本地 HTTP server，在目标浏览器逐行设置环境并记录 `currentSrc`、Network、图像 alt、video controls、字幕和文字稿路径。依次注入：srcset descriptor 错误、删除信息图 alt、让视频 URL 返回 text/html。每次保存红灯、首证据、修复和同矩阵重跑。

离线 oracle 不读图片像素、codec 或浏览器选择；如果真实媒体文件未配置，应明确“静态声明通过、播放未验证”，不能伪造播放截图。

## 14. 120 秒讲解模板

> 媒体页先按目的选择 img/video 等原生元素和替代内容。信息图 alt 传达等价事实，装饰图显式空 alt，功能图描述动作，复杂图另有长说明。srcset 给候选，sizes 给预计槽位，picture 用 source 做格式或构图选择，浏览器结合视口、DPR、支持和策略决定 currentSrc；CSS 才决定真实布局。video/audio 用原生 controls、真实 MIME source、同步 captions 和可见文字稿。证据从 DOM 声明到 currentSrc/Network、状态/MIME、解码、字幕/回退任务逐层保存。错误 srcset、缺 alt 或 MIME 不匹配时，我指出第一个偏离矩阵的层级，再用同一环境重跑。它不实现 CSS 响应布局、上传服务、转码或附件授权。

## 15. 官方来源与版本边界

本章于 **2026-07-17** 核验：

- [WHATWG HTML Living Standard：Embedded content](https://html.spec.whatwg.org/multipage/embedded-content.html)：picture/source/img、srcset/sizes、audio/video/track 与资源选择规则；Living Standard 会持续更新。
- [W3C WAI Images Tutorial](https://www.w3.org/WAI/tutorials/images/)：按图片目的选择替代文本的入口。
- [W3C WAI Making Audio and Video Media Accessible](https://www.w3.org/WAI/media/av/)：captions、transcript、audio description 与媒体策划边界。
- [W3C WebVTT 1](https://www.w3.org/TR/webvtt1/)：WebVTT cue 与文本轨格式。
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)：非文本内容、音视频替代与可操作相关成功准则。

已确认：元素职责、候选语法模型、alt/track 与失败证据边界已对照一手资料；离线工件可重复。未确认：目标 Chrome/Firefox/Safari 的候选启发式、真实图片/codec 解码、range/CDN/CORS、字幕 UI、读屏器媒体控件、FactoryCare 附件授权与签名 URL。提交 G4 证据必须补目标环境，不能把本章绿灯当媒体兼容认证。

## 16. 交付检查表

- [ ] 每张图按上下文归类，alt/空 alt/长说明有理由且不泄密。
- [ ] width/height 与固有比例、src/srcset descriptor 与 manifest 一致。
- [ ] width descriptor 配套 sizes，且 sizes 明确只是 CSS 槽位契约。
- [ ] picture source 顺序、type/media 与末尾 img fallback/alt 正确。
- [ ] 格式选择有质量、大小、支持、许可和安全证据，不靠口号。
- [ ] video/audio 保留原生 controls，有多 source、captions 与可见文字稿。
- [ ] URL、status、Content-Type、currentSrc、缓存/失败回退逐层记录。
- [ ] 私有附件与静态资产边界明确；对象 URL/下载属性不充当授权。
- [ ] 三类故障有首个可信证据、修复、同矩阵重跑和残余风险。
- [ ] 我没有声称离线 oracle 运行了浏览器、解码媒体或完成 CSS 布局。

达到这些条件，才算能建立媒体资源证据链，而不是只会写 `<img src>`。
