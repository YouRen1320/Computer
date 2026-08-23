---
schema_version: 2
edition: 2026.2-draft
id: ch.web.forms-validation
title: 表单控件、提交语义与原生校验
responsibility: 建立 label、控件、提交编码和原生约束校验的端到端表单契约，不在本章实现 JavaScript 自定义校验或框架双向绑定。
volume: '07'
order: 4
level: L1
status: drafting
path: book/volume-07-web-platform/chapters/ch.web.forms-validation.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.web.semantic-html
- ch.web.origin-cookie-cache
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
  text: 在 120 秒内解释“表单控件、提交语义与原生校验”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - web-form-semantics
  - web-native-validation
  covers_topics:
  - html.form-owner
  - html.label-control
  - html.control-name-value
  - html.form-submit-encoding
  - html.required-constraint
  - html.input-type-semantics
  - html.validity-state
  - html.validation-message
  - html.landmark-elements
  uses_capabilities:
  - web.browser-rendering
  - web.browser-origin-state
  - foundation.http-message
  - web.html-semantic-form
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现含文本、选择、日期和文件控件的原生表单并保存提交负载矩阵；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - web-form-semantics
  - web-native-validation
  covers_topics:
  - html.form-owner
  - html.label-control
  - html.control-name-value
  - html.form-submit-encoding
  - html.required-constraint
  - html.input-type-semantics
  - html.validity-state
  - html.validation-message
  - html.landmark-elements
  uses_capabilities:
  - web.browser-rendering
  - web.browser-origin-state
  - foundation.http-message
  - web.html-semantic-form
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: submission-matrix-native-validity-check-request-inspection
- id: diagnose
  kind: fault-diagnosis
  text: 面对“缺失 label、错误 name 或绕过客户端校验导致的契约不一致”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - web-form-semantics
  - web-native-validation
  covers_topics:
  - html.form-owner
  - html.label-control
  - html.control-name-value
  - html.form-submit-encoding
  - html.required-constraint
  - html.input-type-semantics
  - html.validity-state
  - html.validation-message
  - html.landmark-elements
  uses_capabilities:
  - web.browser-rendering
  - web.browser-origin-state
  - foundation.http-message
  - web.html-semantic-form
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 表单控件、提交语义与原生校验

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《语义 HTML、文档结构与元数据》](ch.web.semantic-html.md)：表单必须嵌入正确的文档结构并复用原生元素语义。
- [《Origin、同源、Cookie、缓存与 CORS 浏览器模型》](ch.web.origin-cookie-cache.md)：提交目标、Origin、Cookie 和浏览器策略会影响表单请求，必须能区分客户端约束与网络边界。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套工件用静态 HTML、固定提交矩阵和 Ruby 标准库离线 oracle 训练 label、name/value、编码与服务端复核边界；离线绿灯不等于真实浏览器约束 UI、网络请求、文件上传或 FactoryCare API 已通过。易变事实已于 **2026-07-17** 对照 WHATWG HTML Living Standard 与 W3C WAI/WCAG 一手资料核验，提交证据时仍须记录目标浏览器版本。

表单是用户意图变成 HTTP 请求的边界。一个输入框不仅有外观：它属于某个 form，有供人理解的 label，有供请求使用的 name，有当前 value，有类型与约束；提交时浏览器构造“成功控件”的条目列表，再按 method、action、enctype 和 submitter 形成导航请求。原生约束校验可以在普通交互提交前阻止明显缺失或格式错误，却无法阻止攻击者绕过浏览器，也无法保证业务规则、权限、幂等或文件安全。

本章只建立原生 HTML 端到端契约，不实现 JavaScript 自定义校验、框架双向绑定、后端接口或生产上传链路。特别要区分：教材表单用 `multipart/form-data` 观察文件控件的浏览器提交语义；FactoryCare 生产报修 API 使用 JSON `CreateReportRequest`，附件先走独立上传意图，再将完成的 `attachmentIds` 绑定到报修。二者是不同合同，不能把教学表单直接称为生产实现。

## 1. 完成定义与证据入口

完成本章，应能：

1. 解释 form owner、label/control、id、name、value、submitter 各自职责，避免把它们混为一个属性；
2. 用文本、选择、日期、文件及按钮控件实现无 JavaScript 也能提交的原生表单；
3. 预测 GET 与 POST、`application/x-www-form-urlencoded` 与 `multipart/form-data` 的请求目标和负载形态；
4. 预测哪些控件会进入提交条目：无 name、disabled、未选中的 checkbox/radio 等不会像普通成功控件那样提交；
5. 用 `required`、合适的 input type、min/max/length/pattern 等原生约束建立第一层反馈，并读取 `ValidityState` 的含义；
6. 说明客户端校验可绕过，服务端必须重新校验类型、范围、业务状态、权限和文件；
7. 保存合法、缺失、格式错误、校验绕过、重复提交的“浏览器状态—实际请求—服务端判定”矩阵；
8. 注入缺失 label、错误 name、绕过客户端校验，指出首个可信差异，修复后重跑同一矩阵。

配套入口：

- [原生报修表单与提交矩阵示例](../../../examples/encyclopedia/ch.web.forms-validation/README.md)
- [表单契约故障实验](../../../labs/encyclopedia/ch.web.forms-validation/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.web.forms-validation/README.md)

canonical 验收要求合法、缺失、格式错误和重复提交输入，在浏览器校验状态与实际请求负载中得到确定、可重复的结果。离线 oracle 只检查教学 HTML 与矩阵契约；真实请求必须在锁定浏览器中用 Network 面板或受控接收端捕获，不能仅凭源码猜测。

## 2. 一条从人到请求的链

先把常被混淆的角色排开：

```text
可见 label ──for/id──> 控件
控件 ──form owner──> form
控件当前状态 ──successful controls 算法──> name/value 条目
form + submitter ──method/action/enctype──> HTTP 导航请求
浏览器约束状态 ──普通交互提交前──> 允许或阻止这次提交
服务器 ──重新认证/授权/校验/幂等──> 接受或 Problem 错误
```

这条链上的任何一环都不能替代其他环：

- `id="priority"` 可供 label/DOM 指向，但请求键通常来自 `name="priority"`；
- 有 `name` 能提交，却不代表用户知道输入目的，仍需 label；
- `required` 能阻止普通空值提交，却不证明服务端安全；
- 服务器返回 201 不代表重复点击一定只创建一次，仍需幂等合同；
- `accept="image/*"` 影响文件选择提示，不是 MIME、扩展名或恶意内容的信任边界。

## 3. `form` 与 form owner

### 3.1 form 是提交合同容器

最小表单：

```html
<!-- Responsibility: 演示浏览器原生 POST 表单合同，不调用 FactoryCare 生产 API。 -->
<!-- Data source: 所有选项和默认值来自固定教学夹具，不读取真实资产或用户资料。 -->
<!-- Mapping: HTML name/value 只映射教学接收端字段；生产 JSON/附件合同见本章第 11 节。 -->
<!-- Side effects: 点击提交会向本地教学接收端发 POST；在没有接收端时只会导航失败。 -->
<form action="/teaching/report-submissions" method="post" enctype="multipart/form-data">
  <label for="asset-id">设备编号</label>
  <input id="asset-id" name="assetId" type="text" required>
  <button type="submit" name="intent" value="create">提交教学请求</button>
</form>
```

`action` 决定提交目标 URL（相对 URL 会相对文档基 URL 解析），`method` 常用 `get` 或 `post`，`enctype` 决定 POST 表单数据编码。若省略或写错默认值，浏览器仍可能按规范默认处理，页面“有请求”不代表合同正确。验收应检查最终 request URL、method、Content-Type 和 payload。

### 3.2 form owner 不总是最近祖先

表单相关元素通常由最近祖先 `form` 拥有；也可以用 `form="report-form"` 显式指向同一文档中具有该 id 的 form。这允许 submit button 在视觉/DOM 上位于 form 外部仍参与提交：

```html
<!-- Responsibility: 演示显式 form owner；按钮仍会触发 report-form 的提交副作用。 -->
<form id="report-form" action="/teaching/reports" method="post">
  <label for="description">故障描述</label>
  <textarea id="description" name="description" required></textarea>
</form>
<button type="submit" form="report-form" name="intent" value="create">提交</button>
```

显式 owner 不是用来修补混乱布局的默认手段。重复 id、指向不存在 form、动态移动节点都可能让归属与预期不同。真实浏览器里检查 `control.form`/Elements，而不是仅看缩进。一个控件不能同时归属两个 form。

禁止嵌套 form。HTML parser 的错误恢复可能让实际 DOM 出乎作者预期，导致按钮提交了另一组控件。结构 checker 与 DOM 检查应先于业务调试。

## 4. label、id、name、value：四个不同问题

### 4.1 label 让人知道“这是什么”

显式关联：

```html
<!-- Responsibility: 让可见文字与唯一控件建立可点击、可被辅助技术解析的关联。 -->
<label for="contact">联系方式（可选）</label>
<input id="contact" name="contact" type="text" autocomplete="tel">
```

`for` 的值必须精确匹配可标注控件的 `id`。点击 label 通常会把交互/焦点转给控件，辅助技术也可利用关联计算名称。隐式关联可把控件嵌在 label 内，但显式关联更容易审计，也适合 label 与控件分离的结构。具体组件风格可统一，但关联必须可证明。

placeholder 不能替代 label：它可能在输入后消失，常只提供示例或提示，且并非稳定名称。`title`、附近视觉文本、CSS 伪元素也不是默认替代。必填提示不能只靠红色星号；要用文字说明，`required` 再提供机器状态。

文件控件、select、textarea 同样需要 label。按钮的可见内容通常就是名称，但图标按钮的名称策略属于后续无障碍章。

### 4.2 id 服务关联，name 服务提交

```html
<label for="priority">优先级</label>
<!-- Mapping: id 供 label/DOM；name 才是教学请求条目键。 -->
<select id="priority" name="priority" required>
  <option value="">请选择</option>
  <option value="LOW">低</option>
  <option value="HIGH">高</option>
  <option value="CRITICAL">紧急</option>
</select>
```

若错误写成 `name="severity"`，label 仍可能正常、原生 required 仍可能通过，屏幕也看不出问题；首个可信差异通常出现在 Network payload：键是 `severity`，而接收合同期待 `priority`。服务端应返回稳定字段错误，不该偷偷把未知键猜成 priority。

若没有 `name`，多数普通表单提交不会为该控件生成条目；有 `id` 并不补救。反过来，多个控件可共享同一 name，形成重复条目，例如多个选中的 checkbox；服务端解析器如何映射为数组/首值/末值必须显式约定，不能假定所有框架相同。

### 4.3 value 是提交时的当前值

文本/textarea 的 value 来自当前输入；select 来自选中的 option value（未写 value 时有规范定义的回退）；checkbox/radio 只有在选中时通常才成为成功控件，value 若省略会有默认值但不宜依赖；文件控件提交文件条目，不允许脚本随意设置本地路径。

不要用显示文字充当稳定协议值。option 可见文本是“紧急”，value 用后端枚举 `CRITICAL`；这就是明确映射。枚举变化是 API 合同变化，需要前后端共同迁移，而不是仅改页面翻译。

## 5. 哪些控件会进入提交负载

浏览器构造 form data set/entry list 时，不是把 form 下所有节点序列化。入门时至少预测这些条件：

- 有适用 `name` 的成功控件才贡献键；
- `disabled` 控件通常不提交；`readonly` 与 disabled 不同，适用控件仍可提交；
- 未勾选 checkbox/radio 不贡献条目；
- select 贡献已选 option；`multiple` 可能贡献同名多条；
- 触发提交的 submitter（如被点击的 submit button）可贡献自己的 name/value，其他 submit button 通常不贡献；
- 文件 input 贡献所选文件条目，编码和接收端必须适配；
- 控件是否由该 form 拥有，比它在视觉上是否“在框里”更关键。

因此“缺失 checkbox=false”不是浏览器自动发了布尔 false，而是根本没有该键。服务端/适配层必须定义 absent 的业务含义，或用额外字段设计明确表达。不要在安全决策里把缺失值默认为授权。

### 5.1 disabled 与 readonly

`disabled` 表示控件不可变、不可聚焦且通常不提交；它不是隐藏可信值的安全办法。攻击者能删属性并自行发请求。`readonly` 只适用于部分文本类控件，通常仍参与提交，也同样不可信。若服务器需要 assetId、tenantId 或 actor，必须从受信上下文/路由与授权重新确定，而不是相信禁用输入框。

### 5.2 submitter 会覆盖部分 form 属性

submit button 可用 `formaction`、`formmethod`、`formenctype`、`formnovalidate` 等影响这次提交。这对“保存草稿/发布”可能有用，也扩大审计面。若项目不需要多目标提交，避免不必要覆盖。Network 证据应记录实际点击了哪个按钮，而不是只截图 form 属性。

## 6. method、action 与编码

### 6.1 GET 表单

GET 适合安全、可书签的查询。表单条目通常进入目标 URL query，页面会导航到新 URL。敏感信息、长文本和文件不应靠 GET 表单传递；URL 会出现在地址栏、历史、日志、Referer 等环境。GET 语义应是安全读取，不用它创建/改变工单。

示例预测：

```text
action=/search, method=get
name=q value=泵
name=status value=CREATED
→ /search?q=%E6%B3%B5&status=CREATED （具体序列化按标准编码）
```

不要手拼 query 再与表单自动 query 混用而不测试；URL 编码不是“把空格换成 +”这一条规则的全部。

### 6.2 POST 与 `application/x-www-form-urlencoded`

没有文件且使用默认 POST 编码时，Content-Type 常为 `application/x-www-form-urlencoded`，条目编码在请求 body。它仍是 HTTP 普通 body，不自动加密；机密性依赖 HTTPS，认证授权依赖服务端。参数重复、字符编码、空值与服务器 parser 行为要用抓到的原始请求确认。

### 6.3 `multipart/form-data`

有文件控件时通常使用 `multipart/form-data`。浏览器生成 boundary，并把每个条目分成 part；作者不应在普通原生提交中手写错误 boundary。它适合教学观察“字段 + 文件”如何成为多 part 请求，但不自动完成病毒扫描、对象存储上传、哈希校验或附件归属。

`text/plain` 表单编码不适合作为生产结构化 API 合同；解析边界和互操作性差。生产 API 是 JSON 时，应由明确的客户端适配层构造 JSON，并经过相应 JavaScript/后端章节验证；本章不实现这层。

### 6.4 HTTP 证据

从上一章复用 `foundation.http-message`：至少保存 method、最终 URL、请求 `Content-Type`、Origin/Cookie 条件、payload/各 part、响应 status/body。只看 Console 的校验气泡，不能证明发出了什么；只看服务端对象，可能已经被框架归一化而丢失重复键等原始事实。Network raw/payload 与接收端原始记录应能互相印证。

## 7. 控件类型语义

### 7.1 文本、email 与 textarea

`input type="text"` 是单行文本。`textarea` 是多行内容，初始值来自元素文本而非 `value` 属性。`type="email"` 提供 email 语义、可能的移动键盘和类型约束，但不会验证邮箱实际存在、允许域或业务唯一性。电话号码、资产编号等有各自业务规则，不能随意选择 email 只为得到红框。

### 7.2 select

select 用于有限候选，option value 应是稳定协议值。占位 option 常用空 value 与提示文字，再配 required；必须在目标浏览器核对空选择的 validity。候选来自 API 时会产生加载、失败、过期和权限问题，属于动态交互；本章使用固定夹具，注释其数据来源。

### 7.3 date

`input type="date"` 的 UI 可能按 locale 呈现，但提交 value 使用标准化日期形式（有值时常见 `YYYY-MM-DD`）。日期不包含时间和时区；“故障发生时间”若需要 instant，单个 date 控件并不足够。浏览器对 UI 与可输入方式可能不同，必须实测，不要从截图推断 payload。

`min`/`max` 可建立范围约束，但服务器仍要结合业务时钟/时区判断，例如不能报告未来日期。动态的“今天”不能硬编码进长期夹具；矩阵应固定基准日期并写明时区。

### 7.4 file

`input type="file"` 让用户选择本地文件。`accept="image/png,image/jpeg"` 是选择提示/过滤线索，不是安全验证；用户代理和客户端都可绕过，文件扩展名与声明 MIME 也可伪造。服务端/上传服务需验证大小、允许类型、内容特征、哈希、恶意内容扫描、对象键、访问权限和所有权绑定。

`multiple` 允许多文件，提交中会出现多个同名文件条目。FactoryCare 的报修附件上限是 3，单文件最大 52,428,800 字节（按当前项目合同）；这些仍必须由上传服务与创建报修事务复核。HTML 文件控件不应显示/保存真实本地路径，也不能把路径当可上传内容。

### 7.5 button 默认行为

在 form 内，`button` 未声明 type 时常按 submit 处理。只想展开帮助或打开对话框的按钮必须写 `type="button"`，否则未来加脚本时可能意外提交。真正提交按钮写 `type="submit"`，重置按钮要谨慎：`reset` 会清除输入，容易让用户丢失工作，也不提供撤销。

## 8. 原生约束校验与 ValidityState

### 8.1 约束来源

常用约束包括：

- `required`：适用控件必须有满足条件的值/选择；
- `type="email"` 等：可能触发类型不匹配；
- `min`/`max`/`step`：数值或日期范围/步进；
- `minlength`/`maxlength`：适用文本长度；
- `pattern`：适用文本值须满足模式；
- 浏览器内建规则：例如某些控件的 parse/value sanitization。

约束是组合的。空的 required email 常先有 `valueMissing`；非空但格式错误可能 `typeMismatch`。不要只保存“invalid=true”，应预测具体 validity flag 与用户可见错误上下文。

### 8.2 ValidityState

约束可通过控件的 `validity` 对象观察，常见成员：

- `valueMissing`
- `typeMismatch`
- `patternMismatch`
- `tooLong` / `tooShort`
- `rangeUnderflow` / `rangeOverflow`
- `stepMismatch`
- `badInput`
- `customError`
- 汇总 `valid`

不同 input type 适用的 flags 不同。`validationMessage` 是用户代理生成/本地化的消息，其文字可能随浏览器和语言变化，不应把完整文案硬编码成跨浏览器 oracle。稳定矩阵优先断言 flag 与是否阻止提交，再在目标环境记录实际消息/截图。

### 8.3 `checkValidity()` 与 `reportValidity()`

概念上，`checkValidity()` 检查并返回有效性，可能触发 `invalid` 事件；`reportValidity()` 还要求用户代理向用户报告问题。本章不写 JavaScript，只要求能在 DevTools 手工观察。生产自定义错误、焦点管理与动态通知需进入无障碍/JS 章节，不能在此用脚本替换原生行为。

### 8.4 何时执行交互校验

普通用户激活 submitter 触发表单提交时，浏览器通常执行交互式约束校验；不通过时阻止提交并报告无效控件。`novalidate`（form）或 `formnovalidate`（submitter）可跳过这一层。程序化调用也有差异：`requestSubmit()` 按 submitter 驱动正常提交流程，而历史 `form.submit()` 不等同于用户激活，可能绕过交互校验与 submit 事件。攻击者还可直接构造 HTTP 请求。

所以服务端策略必须假设客户端约束全部可被删除。矩阵中的“bypass”行不是异常黑客技巧，而是必测输入。

### 8.5 错误消息与说明

可见 label 说明控件目的；格式、范围和必填要求应在用户输入前后以文字提供。浏览器默认 message 可作为基础反馈，但其文案与呈现不可由作者完全控制。服务端错误返回后，页面必须把稳定 field error 映射回相应控件并可被感知；这需要后续交互/无障碍实现。本章只定义合同：字段键稳定、错误原因可操作、不泄露敏感内部信息。

## 9. 提交矩阵：预测、观察、判定

矩阵不能只写“通过/失败”，至少含三层：

| case | 输入 | 预测浏览器 validity | 是否普通提交 | 预期请求条目 | 服务端必须做 |
|---|---|---|---:|---|---|
| valid | 所有必填合法、1 个 PNG | valid | 是 | assetId/priority/description/observedDate/evidenceFiles/intent | 认证授权、字段与文件复核 |
| missing | description 空 | `valueMissing` | 否 | 无请求 | 若绕过仍返回字段错误 |
| format | 日期超 max/模式不符 | range/pattern flag | 否 | 无请求 | 用业务时区重新判断 |
| unnamed | 有 id 无 name | 控件可 valid | 是 | 缺少该键 | 拒绝缺失必填字段 |
| wrong-name | priority 被写成 severity | valid | 是 | `severity=HIGH` | 拒绝未知/缺失合同键 |
| bypass | 移除 required 直接 POST | 浏览器不阻止 | 是 | 可含非法值 | 服务端 400 + stable fieldErrors |
| duplicate | 同请求连点/重放 | 每次均可 valid | 两次 | payload 相同 | 幂等键同请求只产生一结果 |

“重复提交”不是 ValidityState 能解决的问题。按钮暂时 disabled 只能改善体验，网络重试、双设备、恶意重放仍存在。FactoryCare 创建报修支持 `Idempotency-Key`：相同 key + 同请求应复用第一次结果，相同 key + 不同请求应冲突/拒绝。真实状态码与 Problem 字段以锁定 API 合同测试为准。

### 9.1 为什么要捕获实际 payload

源码看见 `name="priority"` 不证明运行时 DOM 没被修改；浏览器 UI 显示“高”不证明提交 value 不是 `HIGH`/空；控件 disabled 状态、所点 submitter 和文件选择都会改变条目。Network 面板或受控 echo endpoint 的原始记录才是请求层证据。接收端回显必须脱敏，不能把文件或 Cookie 上传到公共服务。

### 9.2 稳定与易变断言

稳定断言：是否有 name、expected entry keys、validity flag、是否发生请求、HTTP method/Content-Type。易变断言：浏览器气泡文案、日期选择器外观、文件选择 UI、DevTools 列名。前者适合自动 oracle，后者记录浏览器版本做人工证据。

## 10. 诊断三类契约不一致

### 10.1 缺失 label

症状：输入框视觉旁边有文字，但没有显式/隐式关联。首个可信证据可以是 DOM 中 label `for` 找不到目标 id，或目标控件的可访问名称检查为空；“文字离得很近”不是关联证据。

修复：为控件分配页面内唯一 id，用可见 label 的 `for` 精确匹配；保持 name 不变，避免无意改变请求合同。重跑结构 oracle，再在目标浏览器检查 Accessibility name 并用点击 label/读屏任务验证。残余风险包括重复 id、动态渲染时 id 冲突、复杂说明未关联。

### 10.2 错误 name

症状：label、输入和原生校验都正常，服务器却报告 priority 缺失。诊断顺序：

1. 保存用户输入与所点 submitter；
2. 在 Network 查看实际 payload，确认键是 `severity`；
3. 对照接收合同期望 `priority`，把首个差异定位在“构造 entry list”而非服务器枚举解析；
4. 把 name 改回合同键，保持 id/label/value 映射；
5. 用同一输入与接收端重跑，比较原始 payload。

不要让服务器永久兼容两个键来掩盖前端错误，除非团队明确选择迁移窗口、记录弃用与回滚。长期目标是一份稳定合同。

### 10.3 绕过客户端校验

症状：普通 UI 空描述被阻止，但直接请求或 `novalidate` 提交到达服务器并被接受。这不是“浏览器 bug”，而是服务端信任边界错误。首个可信证据是非法原始请求到达后产生成功状态/持久化副作用。

修复必须在服务端重新验证，并返回稳定 Problem/fieldErrors；HTML required 仍保留作即时反馈。重跑普通合法、普通非法、绕过非法三行，确认合法成功、普通非法无请求、绕过非法被服务端拒绝。若曾写入脏数据，还需单独的数据审计/修复计划，本章不执行。

### 10.4 故障日志模板

```text
fixture: report-form@sha256:...
environment: browser/version + local receiver/version
case: wrong-name
prediction: validity.valid=true；payload contains priority=HIGH
first_observed_divergence: payload contains severity=HIGH, priority absent
stage: construct form data set / author contract
repair: name="severity" → name="priority"
rerun: same input, same submitter, same receiver; expected key observed
residual_risk: accessibility-name and production JSON adapter not verified
```

## 11. FactoryCare 合同映射：教学 multipart 不等于生产 JSON

FactoryCare 当前项目合同中的 `CreateReportRequest` 要求：

- `assetId`：UUID，必填；
- `category`：1–64 字符，必填；
- `description`：10–5000 字符，必填；
- `priority`：`LOW | MEDIUM | HIGH | CRITICAL`，必填；
- `contact`：最多 200 字符，可选；
- `attachmentIds`：最多 3 个已完成、用途为 `REPORT_CREATION` 的上传，可选，并在创建报修事务中安全绑定。

教学表单为了覆盖 canonical 要求，包含文本、select、date 和 file 控件；其中 date 是额外教学字段，不能未经 API 变更就发给生产。生产附件流程是：创建 upload intent（purpose/fileName/size/mime/sha256）→ 上传到受控目标 → 完成/校验 → JSON 创建报修携带 attachmentIds。直接把 `<input type="file">` 的 multipart body POST 到 `/api/v1/reports` 与现有合同不一致。

合适的边界图：

```text
原生 HTML 表单状态
  →（后续 JS 适配层，非本章）读取/转换受控字段
  → 文件逐个走 upload intent + upload + completion
  → 收集完成 attachmentIds
  → JSON CreateReportRequest + Idempotency-Key
  → 服务端认证/授权/字段校验/附件绑定/幂等
```

该适配层需要处理异步、进度、失败恢复、取消、hash、认证过期和错误映射，不能由本章静态 HTML 假装完成。原生 label/type/required 仍可复用，但请求编码合同发生了明确转换。

服务端错误应使用稳定 Problem 与 fieldErrors，让前端能按合同键映射；错误 name 会让映射失败，因此字段命名必须统一。创建请求还要携带幂等键；同 key 不同 payload 应拒绝，防止误把不同报修合并。

## 12. 安全、隐私与可访问性边界

### 12.1 客户端输入永不可信

隐藏、readonly、disabled、required、pattern、min/max、accept 都能被非浏览器客户端绕过。服务端必须：从可信 session/token 重建 actor 与 tenant；检查资产数据范围；验证枚举、长度、关系与状态；对文本做上下文安全输出；对文件做大小/类型/内容/扫描/归属；对副作用使用事务与幂等。

### 12.2 表单与 CSRF/CORS/Cookie

跨源表单提交与脚本读取不是同一件事。CORS 不构成 CSRF 防护；Cookie SameSite 只是纵深措施；服务端写操作仍需项目规定的 CSRF/Origin 策略、认证授权与幂等。Network 中看到请求被浏览器发送但响应不可读时，先按前章拆分 Origin、Cookie、CORS，再判断表单合同。

### 12.3 敏感证据

表单 Network payload 可能含联系人、故障描述、文件名、Cookie/token。提交学习证据前使用虚构数据，遮蔽秘密，保存必要字段而非整份生产 HAR。文件夹内不存真实图片、个人电话号码或预签名 URL。

### 12.4 原生语义不是完整无障碍验收

label、fieldset/legend、原生按钮和错误文字是良好基础，但完整任务还包括键盘顺序、焦点落点、错误关联与通知、缩放、对比度、读屏器组合等。下一无障碍章会实测。本章离线 oracle 不读取可访问树，绝不声称 WCAG 合规。

## 13. 常见误解与更正

| 误解 | 为什么错 | 更可靠的规则 |
|---|---|---|
| placeholder 就是 label | 输入后消失且不是稳定关联 | 使用可见 label 并用 for/id 关联 |
| id 是请求字段名 | 提交键来自 name | 分别验证 id 关联与 payload name |
| required 保证服务端不收空值 | 客户端可绕过 | 浏览器反馈 + 服务端重新校验 |
| disabled 值很安全 | 可删属性/自造请求，且通常不提交 | 从可信上下文重建安全字段 |
| accept 限制了真实文件类型 | 主要是选择提示 | 服务端验证内容、大小、扫描和归属 |
| 表单内 button 默认不会提交 | 默认 type 可能是 submit | 每个 button 显式写 type |
| GET/POST 只差 URL 是否显示 | 语义、目标、缓存/历史与 body 均不同 | 从 HTTP 消息和副作用选择 |
| multipart 就是 FactoryCare 上传方案 | 生产使用独立上传意图与 JSON attachmentIds | 明确适配层和两份合同 |
| 关掉按钮能阻止重复创建 | 重试/并发/恶意客户端仍存在 | 服务端 Idempotency-Key |
| validationMessage 可跨浏览器精确断言 | 文案会本地化/变化 | 自动断言 ValidityState，人工记录文案 |

## 14. 独立实验：从空目录复现

目标：实现含文本、选择、日期、文件控件的原生教学表单，先写提交矩阵，再捕获实际浏览器请求；注入缺 label、错误 name、校验绕过三类故障。

### 14.1 HTML 合同

- 页面沿用上一章语义结构，有一个 `main` 与清晰 `h1`；
- 每个 labelable control 有可见、关联正确的 label；
- `id` 页面内唯一，`name` 精确匹配教学合同；
- 含 `assetId` 文本、`priority` select、`description` textarea、`observedDate` date、`evidenceFiles` file；
- 必填项、类型/长度/范围与帮助文字明确；
- form 使用 POST + multipart 教学接收端，submit button 显式 type/name/value；
- 注释写明职责、固定数据来源、教学到生产映射和提交副作用；
- 不写自定义 JavaScript 校验，不声称直连生产 `/api/v1/reports`。

### 14.2 矩阵合同

至少写 valid、missing-description、invalid-date、wrong-name、bypass-invalid、duplicate-same-key 六行。每行在操作前预测：ValidityState flag、是否发请求、expected entry names、接收端判定、幂等结果。固定日期、文件名/大小/类型和虚构值，避免依赖当天或本机路径。

### 14.3 执行与证据

复制 lab 到空目录，运行其中唯一 `verify.sh`，得到离线课程契约绿灯。然后在获批本地 HTTP 接收端与目标浏览器中：

1. 清除与 case 相关状态，记录浏览器/OS/接收端版本；
2. 按矩阵逐行设置输入，截取 validity 与实际 Network 请求；
3. 缺失/格式错误普通提交应观察“无请求”；另用受控方式构造绕过请求，服务端应拒绝；
4. 相同幂等键同 payload 重放，验证不会产生第二报修；同 key 不同 payload 验证冲突；
5. 每次故障修复后重跑同一行，不临时改预期；
6. 报告真实浏览器 UI、读屏器、生产 API 中哪些尚未验证。

教材 public exercise 故意保持红灯；学习者应自行修复公开 `answer.html`/矩阵，不查看 private solution。红灯表示输入与约定差异可检测，不表示存在网络或生产副作用。

## 15. 120 秒讲解模板

> 原生表单把人与 HTTP 请求连接起来。label 通过 for/id 说明控件目的；控件由祖先 form 或 form 属性确定 owner；name/value 而不是 id 形成提交条目；disabled、未选 checkbox、无 name 等会影响条目；form 与被点击 submitter 的 method、action、enctype 决定请求。required、input type 和其他约束形成 ValidityState，普通交互提交前可阻止明显错误，但可被 novalidate、程序或直接 HTTP 绕过，所以服务端仍要认证、授权、字段/文件校验和幂等。证据是预先写好的 validity—request—server 矩阵与实际 Network payload。它不实现自定义 JS 校验、框架绑定或 FactoryCare 的上传意图/JSON 适配层。

若只说“required 会校验、POST 会提交”，却说不出 name、成功控件、编码、绕过和服务端证据，就还没掌握端到端合同。

## 16. 规范核验与版本边界

本章易变事实于 **2026-07-17** 核验：

- [WHATWG HTML Living Standard：Forms](https://html.spec.whatwg.org/multipage/forms.html)：form、label、控件基础设施、提交与约束校验算法入口。
- [W3C WAI Labeling Controls](https://www.w3.org/WAI/tutorials/forms/labels/)：可见 label、显式 `for`/`id` 关联与控件目的。
- [W3C WAI Validating Input](https://www.w3.org/WAI/tutorials/forms/validation/)：原生 required/type、错误识别以及客户端校验不能替代服务端校验。
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)：信息和关系、标签或说明、错误识别/建议等规范入口。

确认项：form owner、label/control、name/value、提交编码与原生 validity 的规范语义已对照一手资料；离线 HTML/矩阵工件可重复。未确认项：具体浏览器日期/file UI 与 validationMessage、真实 Network multipart 字节、Accessibility name/读屏器体验、本地接收端、FactoryCare upload intent/JSON/Idempotency-Key 集成。生产合同时还须重新核对当前 OpenAPI 与安全策略；本章记录的项目字段是课程输入，不取代生成合同。

## 17. 交付检查表

- [ ] 每个控件的 owner、label、id、name、value 和约束都能逐项解释。
- [ ] 所有按钮显式 type，所点 submitter 和可能覆盖属性已记录。
- [ ] 我能预测无 name、disabled、未选择项、多值和文件对负载的影响。
- [ ] 表单 method/action/enctype 与实际 Network method/URL/Content-Type/payload 对应。
- [ ] valid、missing、format、bypass、wrong-name、duplicate 均先预测后观察。
- [ ] 自动断言基于稳定 validity flags/条目，不锁死浏览器本地化消息。
- [ ] 服务端重新校验、认证授权、文件安全与幂等没有被客户端属性替代。
- [ ] FactoryCare multipart 教学页与生产 JSON + upload-intent 映射明确分开。
- [ ] HTML 注释写明职责、固定数据源、非显然字段映射和提交副作用。
- [ ] 三类故障都有首证据、修复、同矩阵重跑与残余风险。
- [ ] 真实浏览器、可访问性、服务器和生产集成未验证项已明确记录。

达到这些条件，才算建立 `web.html-semantic-form` 能力，而不是只会摆放输入框。
