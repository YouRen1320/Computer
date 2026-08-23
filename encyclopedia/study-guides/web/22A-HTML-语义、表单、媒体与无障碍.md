# HTML：语义、表单、媒体与无障碍

## 1. HTML 说明内容是什么，不只决定它长什么样

HTML 的核心是描述文档结构和内容意义：这是标题、导航、正文、列表、表单还是按钮。CSS 负责呈现，JavaScript 负责交互行为。

```html
<h1>设备报修</h1>
<p>填写故障信息后提交工单。</p>
<button type="button">添加照片</button>
```

若只用一堆 `div` 再靠颜色和位置表达意义，人眼也许看得懂，但浏览器、搜索引擎、键盘和屏幕阅读器缺少可靠结构。

## 2. 一个正常文档有清楚的骨架

```html
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>设备报修 - FactoryCare</title>
</head>
<body>
  <header>...</header>
  <main>...</main>
  <footer>...</footer>
</body>
</html>
```

- `doctype` 让浏览器使用标准模式；
- `lang` 帮助朗读和搜索工具理解语言；
- `charset` 应尽早声明 UTF-8；
- viewport 让移动端按设备宽度布局；
- `title` 是浏览器标签、历史记录和搜索结果的重要名称；
- 一个页面通常只有一个主要 `main` 区域。

## 3. 标题层级表达内容大纲

标题不是“字号快捷键”。`h1` 到 `h6` 表示章节层级：

```html
<h1>工单 WO-42</h1>

<h2>故障信息</h2>
<h3>现场照片</h3>

<h2>处理记录</h2>
```

不要为了字体大小从 `h1` 跳到 `h4`；样式交给 CSS。标题应按内容嵌套，帮助用户快速浏览和辅助技术导航。

## 4. 语义容器说明页面区域职责

常见元素：

- `header`：页面或章节头部；
- `nav`：主要导航集合；
- `main`：当前页面主体；
- `article`：可相对独立分发的内容；
- `section`：有主题、通常带标题的章节；
- `aside`：补充信息；
- `footer`：页面或章节尾部；
- `address`：相关作者或组织的联系信息。

`section` 不是有间距的 `div`。没有明确语义时使用 `div` 完全合理，重点是不要编造含义。

## 5. 列表和表格各自表达一种关系

一组同类项目用列表：

```html
<ul>
  <li>检查电源</li>
  <li>确认报警代码</li>
</ul>
```

有顺序的步骤用 `ol`。键值式描述可用 `dl`、`dt`、`dd`。

表格用于行列关系，不用于页面布局：

```html
<table>
  <caption>本周工单</caption>
  <thead>
    <tr><th scope="col">编号</th><th scope="col">状态</th></tr>
  </thead>
  <tbody>
    <tr><th scope="row">WO-42</th><td>处理中</td></tr>
  </tbody>
</table>
```

`caption` 和 `th scope` 让列、行与数据的关系更清楚。

## 6. 链接和按钮不是靠外观区分

```text
链接 <a>：去另一个地址或页面位置
按钮 <button>：在当前界面触发动作
```

```html
<a href="/work-orders/42">查看工单</a>
<button type="button">关闭弹窗</button>
```

不要用没有 `href` 的 `a` 冒充按钮，也不要给 `div` 加 click 就冒充两者。原生元素自带键盘、焦点和辅助技术语义。

新窗口应谨慎使用，并让用户知道。下载链接也应说明文件类型和大小。

## 7. 图片需要根据用途决定替代文本

内容图片：

```html
<img src="motor-overheat.jpg" alt="电机温度表显示 108 摄氏度">
```

纯装饰图片：

```html
<img src="divider.svg" alt="">
```

`alt` 不是文件名或“图片”二字，而是在看不到图时传达相同用途。复杂图表可用简短 alt 加邻近文字说明或数据表。

若图片旁已有完全相同文字，装饰性 alt 可为空，避免屏幕阅读器重复。

## 8. 响应式图片让浏览器选择合适资源

同一内容有不同分辨率时：

```html
<img
  src="device-800.jpg"
  srcset="device-400.jpg 400w, device-800.jpg 800w, device-1600.jpg 1600w"
  sizes="(max-width: 600px) 100vw, 50vw"
  width="800"
  height="600"
  alt="车间三号泵的铭牌">
```

`srcset` 提供候选，`sizes` 告诉浏览器预计显示宽度。明确 width/height 比例能在图片下载前保留空间，减少页面跳动。

需要根据画面裁切或格式选择时可使用 `picture`。不要只用 CSS 把一张巨大的桌面图缩小给手机。

## 9. 音视频需要控制、字幕和降级内容

```html
<video controls preload="metadata">
  <source src="repair.mp4" type="video/mp4">
  <track kind="captions" src="repair.zh.vtt" srclang="zh" label="中文" default>
  浏览器无法播放此视频。
</video>
```

通常不要自动播放有声音媒体。字幕服务听障用户，也方便静音环境；只含语音的信息可提供文字稿。媒体体积、格式、版权和隐私同样属于资源边界。

## 10. 表单是“命名字段并提交数据”的协议

```html
<form action="/work-orders" method="post">
  <label for="title">故障标题</label>
  <input id="title" name="title" required>
  <button type="submit">提交工单</button>
</form>
```

关键区别：

- `id` 把 label 和控件关联，也用于页面唯一定位；
- `name` 决定提交字段名；
- `value` 是提交值；
- 没有 `name` 的普通控件不会成为原生表单数据；
- `button` 在 form 中默认可能是 submit，非提交按钮应显式 `type="button"`。

## 11. label 要给用户可见的字段名称

Placeholder 不能替代 label：输入后它消失，颜色常较弱，也不稳定地充当可访问名称。

推荐显式关联：

```html
<label for="device-code">设备编号</label>
<input id="device-code" name="deviceCode" autocomplete="off">
```

也可以把 input 包在 label 中。图标按钮若没有可见文字，需要一个可靠的可访问名称，例如 `aria-label`，但优先保留可见文字以减少理解成本。

## 12. 选择正确 input 类型能获得浏览器能力

```html
<input type="email" name="contactEmail">
<input type="tel" name="phone">
<input type="date" name="reportedDate">
<input type="number" name="quantity" min="1" step="1">
```

类型可影响移动键盘、原生校验和辅助语义。不过：

- 电话并非纯数字，不能用 number；
- 金额要明确精度和货币，不应盲目用浮点；
- 日期控件的显示和输入体验由浏览器/系统决定；
- 服务器仍必须校验所有值。

## 13. checkbox、radio 和 select 表达不同选择

- checkbox：多个独立布尔或可多选项；
- 同名 radio：一组选一个；
- select：从一组候选选择，适合选项较稳定且数量合理。

```html
<fieldset>
  <legend>故障影响</legend>
  <label><input type="radio" name="impact" value="stopped"> 停机</label>
  <label><input type="radio" name="impact" value="degraded"> 降级运行</label>
</fieldset>
```

`fieldset` 和 `legend` 给一组控件共同名称。不要用多个 checkbox 表示必须单选的选项，再用 JavaScript 修补。

## 14. 原生校验改善体验，但不是安全边界

常用约束：

```html
<input required minlength="3" maxlength="100" pattern="[A-Z0-9-]+">
```

浏览器可在提交前给提示，但攻击者、脚本和其他客户端可绕过 HTML。服务端要按同一业务合同重新验证，并返回稳定字段错误。

不要让客户端和服务端维护两套互相矛盾的正则。前端约束用于尽早反馈，服务端约束才决定是否接受。

## 15. 错误信息要和字段建立关系

```html
<label for="title">故障标题</label>
<input id="title" aria-describedby="title-help title-error" aria-invalid="true">
<p id="title-help">请用一句话描述主要现象。</p>
<p id="title-error">标题至少需要 3 个字符。</p>
```

错误不能只靠红色边框。提交失败后：

- 页面顶部可有错误摘要；
- 焦点移到摘要或第一个错误字段；
- 每个错误说明如何修复；
- 用户已填的合法内容应保留；
- 动态错误应被辅助技术感知。

## 16. GET 和 POST 表单有不同语义

```text
GET：读取/搜索，参数进入 URL，可收藏、分享、缓存
POST：创建或产生副作用，数据放请求 body
```

搜索表单适合 GET；创建工单适合 POST。密码和敏感数据不应放 URL，因为 URL 会进入历史、日志、Referer 和监控。

HTML form 原生主要支持 GET/POST。更新/删除的其他方法通常由 JavaScript 请求或服务端约定处理。

## 17. 文件上传要同时考虑浏览器和服务器边界

```html
<form method="post" enctype="multipart/form-data">
  <label for="photo">故障照片</label>
  <input id="photo" name="photo" type="file" accept="image/*">
</form>
```

`accept` 只是文件选择提示，不是安全验证。服务器必须检查大小、实际内容类型、文件名、存储路径、权限、恶意内容和解码资源消耗。

用户选择本地文件后，页面不能任意读取其他文件。不要要求前端提交用户本机绝对路径。

## 18. 元数据帮助分享、搜索和显示

常见内容：

```html
<meta name="description" content="FactoryCare 设备报修与维修工单管理">
<link rel="canonical" href="https://example.com/work-orders">
```

还有站点图标、社交分享元数据等。它们不能替代正文结构，也不应把租户、用户或敏感工单信息意外放入公开页面 head。

## 19. 无障碍首先是让不同方式都能完成任务

用户可能：

- 只用键盘；
- 使用屏幕阅读器；
- 放大到 200% 或更高；
- 使用语音控制；
- 有色觉差异；
- 暂时单手操作或处在强光/噪声环境。

无障碍不是少数人的“附加模式”。语义清楚、键盘可用、错误明确和布局可缩放通常也改善普通用户体验。

## 20. 原生 HTML 通常优先于自造 ARIA 控件

一句常用原则：能用原生元素，就不要先用 `div` 再补角色。

```html
<button>保存</button>
```

自造按钮必须重新实现焦点、Enter/Space 键、禁用状态和可访问名称，容易遗漏。

ARIA 用于补充动态关系和原生 HTML 表达不了的组件状态，不能让不可点击的元素自动变得可用，也不会修复错误键盘行为。

## 21. 键盘焦点必须可到达、可看见、顺序合理

交互元素应使用 Tab 顺序访问。不要用正数 `tabindex` 人工拼接复杂顺序；DOM 顺序应与视觉和阅读顺序一致。

焦点样式不能无替代地删除：

```css
:focus-visible {
  outline: 3px solid #1a73e8;
  outline-offset: 2px;
}
```

打开模态框时把焦点移入，关闭后还给触发按钮；页面导航后把焦点放到合理入口。焦点不应掉到已删除元素或被隐藏在弹窗背后。

## 22. Skip link 帮助键盘用户跳过重复导航

```html
<a class="skip-link" href="#main-content">跳到主要内容</a>
<nav>...</nav>
<main id="main-content" tabindex="-1">...</main>
```

它平时可以视觉隐藏，获得焦点时显示。长页面还应有清楚标题和 landmark，让用户不必逐个 Tab 穿过所有导航。

## 23. 颜色不能成为唯一信息通道

错误、成功、优先级不能只用红绿区分。可同时使用：

- 文字标签；
- 图标加文字；
- 形状或线型；
- 足够对比度。

```text
仅红色圆点      → 不足
红色图标 + “严重” → 更清楚
```

正文和控件需要可辨对比，禁用态也不能淡到完全不可读。具体对比阈值需要时按当前 WCAG 标准查询。

## 24. 动态提示需要可感知但不能过度打扰

保存成功、上传失败等动态消息可使用合适 live region：

```html
<p role="status" aria-live="polite">工单已保存</p>
```

紧急错误才使用更打断的 alert。不要让每次键入都朗读整个页面，也不要频繁重建 live region 导致消息丢失。

视觉 Toast 自动消失前要给足阅读时间；重要结果还应在页面中有持久位置。

## 25. 隐藏内容有多种不同效果

```text
display: none / hidden：视觉和辅助技术通常都不可见
visibility: hidden：占位但不可见、通常不可访问
仅视觉隐藏：屏幕阅读器可读，视觉不显示
aria-hidden="true"：从无障碍树隐藏，视觉仍可能显示
```

不要把仍可聚焦的按钮设为 `aria-hidden`，会产生“键盘到了一个读不出来的东西”。隐藏策略必须和交互状态一起管理。

## 26. DOM 顺序比视觉重排更重要

CSS Grid/Flex 可以改变视觉位置，但屏幕阅读和键盘通常仍按 DOM 顺序。若桌面上把“提交”视觉移到最前，而 DOM 在最后，用户体验会割裂。

先写合理阅读顺序，再用布局在不改变含义的前提下适配屏幕。移动端不应仅靠 `order` 把完全不同结构硬拼出来。

## 27. 浏览器怎样把 HTML 变成页面

大致过程：

```text
下载 HTML
  → 解析为 DOM
  → 下载/解析 CSS 成 CSSOM
  → 形成渲染树
  → 布局（尺寸与位置）
  → 绘制
  → 合成到屏幕
```

JavaScript 可能暂停解析、修改 DOM 和触发新布局。DevTools 的 Elements、Accessibility、Network 和 Performance 面板可以观察真实结果，不要只盯源码文件。

## 28. 基础检查应使用真实交互方式

阅读完成后，项目阶段可按风险验证：

- 不用鼠标完成主要流程；
- 观察焦点是否可见且顺序合理；
- 使用浏览器无障碍树检查名称、角色和状态；
- 放大和窄屏时内容不丢失；
- 表单错误能关联字段并保留输入；
- 图片关闭或加载失败仍能理解；
- 至少用一种屏幕阅读器走关键流程。

自动检查能发现部分问题，不能代替真实键盘和辅助技术体验。

## 29. 这篇的整体地图

```text
语义 HTML
  → 文档结构、标题、导航、列表与表格
  → 正确的链接、按钮和媒体
  → form + label + name 形成提交合同
  → 原生校验改善体验，服务端负责最终接受
  → 键盘、焦点、名称、状态和动态提示都可感知
```

必须掌握：HTML 描述含义；链接用于导航、按钮用于动作；label 不能由 placeholder 代替；原生校验不是安全边界；原生元素优先于自造控件；键盘、焦点和错误提示是主要功能的一部分。

复杂 ARIA Widget 模式、媒体编码和全部 WCAG 条款属于“需要时查询”。
