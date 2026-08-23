---
schema_version: 2
edition: 2026.2-draft
id: ch.security.untrusted-input-xss-ssrf
title: 不可信输入、输出编码、XSS 与 SSRF
responsibility: 教授数据从不可信源到危险汇的防护边界，不用输入校验替代上下文输出编码或出站控制
volume: '06'
order: 5
level: L2
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.security.untrusted-input-xss-ssrf.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.security.origin-cors-csrf
- ch.spring.problem-details-errors
version_surfaces: []
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释不可信输入、输出编码、XSS 与 SSRF的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - security-xss-output
  - security-ssrf-egress
  covers_topics:
  - security.untrusted-data-flow
  - security.context-output-encoding
  - security.xss
  - security.ssrf
  - security.url-allowlist
  - security.egress-timeout-dns-rebinding
  uses_capabilities:
  - foundation.http-message
  - backend.spring-mvc-contract
  - security.web-threat
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 从DFD资产/信任边界导出CSRF、XSS、SSRF滥用用例，为跨站写入、HTML输出和服务器取URL配置Token/编码/出站allowlist
  covers_topic_groups:
  - security-xss-output
  - security-ssrf-egress
  covers_topics:
  - security.untrusted-data-flow
  - security.context-output-encoding
  - security.xss
  - security.ssrf
  - security.url-allowlist
  - security.egress-timeout-dns-rebinding
  uses_capabilities:
  - foundation.http-message
  - backend.spring-mvc-contract
  - security.web-threat
  evidence_kind: system-artifact-and-negative-tests
  verification_mode: system-security-resilience-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入缺CSRF Token、script/onerror、127.0.0.1和DNS重绑定，判断威胁路径与危险sink并在正确边界阻断
  covers_topic_groups:
  - security-xss-output
  - security-ssrf-egress
  covers_topics:
  - security.untrusted-data-flow
  - security.context-output-encoding
  - security.xss
  - security.ssrf
  - security.url-allowlist
  - security.egress-timeout-dns-rebinding
  uses_capabilities:
  - foundation.http-message
  - backend.spring-mvc-contract
  - security.web-threat
  evidence_kind: fault-injection-fix-rerun
  verification_mode: fault-injection-rerun
---
# 不可信输入、输出编码、XSS 与 SSRF

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Origin、SameSite、CORS 与 CSRF》](ch.security.origin-cors-csrf.md)：独立完成不可信输入与 XSS、SSRF 与出站控制前，必须先具备「Origin、SameSite、CORS 与 CSRF」已经验证的知识与失败边界
- [《异常映射、Problem Details 与稳定错误契约》](../../volume-05-spring-backend/chapters/ch.spring.problem-details-errors.md)：独立完成不可信输入与 XSS、SSRF 与出站控制前，必须先具备「异常映射、Problem Details 与稳定错误契约」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套程序只处理合成字符串、`.example.test` URL、预先给定的地址分类和内存状态；它们不解析真实 DNS、不建立 Socket、不发 HTTP 请求，也不包含真实 Cookie、Token、客户数据或内网地址清单。通过这些程序只能证明决策不变量，不代表浏览器、代理、DNS、云平台或生产出站策略已经通过安全测试。

安全缺陷经常不是“少写一条正则”，而是数据跨越信任边界后进入了错误的解释器。工单描述进入浏览器 HTML 解析器，可能从文字变成标签或脚本；用户给出的 URL 进入服务器 HTTP 客户端，可能从普通字段变成对内网的网络能力。防护要从数据流回答三个问题：数据来自哪里，经过哪些转换，最后进入什么危险 sink；控制必须放在最接近该 sink、能够理解其语义的位置。

## 1. 完成定义与证据入口

完成本章应能交付以下可复验结果：

1. 画出 source → transform → sink 数据流，并把每个跨边界值标为不可信；
2. 区分输入校验、规范化、上下文输出编码、HTML 清洗、认证授权和浏览器附加防线；
3. 对 HTML 文本、属性、URL、JavaScript、CSS 上下文选择不同策略，指出禁止动态插值的危险上下文；
4. 解释反射型、存储型与 DOM 型 XSS 的数据路径，而不是只背攻击字符串；
5. 为服务器取 URL 建立固定业务目标、精确 scheme/host/port allowlist、地址分类、逐跳重定向校验、超时和出站网络控制；
6. 重放缺 CSRF Token、`script`/`onerror`、loopback、非允许 scheme、跳转到私网和 DNS 重绑定，观察稳定拒绝且无副作用；
7. 把每项控制回指 FactoryCare 威胁模型中的资产、攻击者、信任边界和验证证据。

配套入口：

- [不可信数据与危险 sink 示例](../../../examples/encyclopedia/ch.security.untrusted-input-xss-ssrf/README.md)
- [XSS、CSRF 与 SSRF 故障实验](../../../labs/encyclopedia/ch.security.untrusted-input-xss-ssrf/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.security.untrusted-input-xss-ssrf/README.md)

公开练习故意保留红灯；私有解答用于教师核对。资产通过不等于真实富文本清洗器、Vue 页面、Spring MVC、HTTP client 或基础设施 egress 已配置正确。

## 2. 先建立数据流语言

**Source** 是数据首次进入当前信任范围的位置，例如查询参数、JSON body、Header、Cookie、上传文件名、数据库旧记录、消息事件、第三方响应、AI 输出、管理员配置或环境变量。来自数据库不等于可信：数据库里可能保存了昨天由攻击者提交的工单描述，所以存储型 XSS 会在以后由另一名用户触发。

**Transform** 是解析、校验、规范化、拼接、模板渲染、反序列化、清洗和编码。转换不一定提高信任。把字符串存进数据库、包进 DTO、转成 JSON，或者把 URL 做一次小写化，都不会自动使它安全。

**Sink** 是把值交给另一个解释器或产生能力的位置。`textContent` 是把值当文本的相对安全 sink；`innerHTML`、`v-html`、事件处理属性、动态脚本是浏览器危险 sink。服务器端 `HttpClient.send`、图片抓取器、Webhook 测试器、PDF 转换器、Git 导入器都是网络 sink。SQL、shell、模板表达式也有各自 sink，但本章只聚焦 XSS 与 SSRF。

信任是针对用途的。一个经过长度校验的工单标题适合存储，不代表适合直接拼进 HTML；一个语法合法的 HTTPS URL 适合显示，不代表服务器有权访问；一个被允许访问的主机返回的内容也仍是不可信响应。

## 3. 六种控制不能互相冒充

| 控制 | 回答的问题 | 典型位置 | 不能替代 |
| --- | --- | --- | --- |
| 输入校验 | 值是否符合业务格式与范围 | API 边界/领域命令 | 输出编码、授权、出站隔离 |
| 规范化 | 多种表示是否先变成唯一可比较形式 | URL/Unicode/标识解析后 | 业务 allowlist |
| 输出编码 | 在当前解释器上下文里怎样保持为数据 | 最接近渲染 sink | 富文本清洗、其他上下文编码 |
| HTML 清洗 | 允许一小部分标记时删掉危险结构 | 富文本入库或展示的专用边界 | 普通文本编码、CSP |
| 认证/授权/CSRF | 谁可以触发动作，是否为本人意愿 | 服务端请求与业务层 | XSS、SSRF |
| 出站策略 | 服务器可连接到哪里、用什么方法和预算 | 专用客户端与网络层 | URL 语法校验 |

输入校验值得做：例如标题 1—200 字、状态属于枚举、URL 字段不允许控制字符。但“禁止出现 `<script>`”会漏掉事件属性、SVG、解析差异、编码变体和 DOM sink，也会误伤正常文本。正确关系是校验减少无效输入，输出编码在 sink 保持数据语义，CSP 等控制限制失守后的影响。

## 4. XSS 到底发生了什么

Cross-Site Scripting 的核心不是字符串中出现 `script`，而是攻击者控制的数据被浏览器当成可执行内容，最终在受信站点的 origin 权限下运行。脚本可能读取页面可见数据、代表用户发请求、篡改界面、诱导操作或窃取脚本可见的令牌。`HttpOnly` 能减少 Cookie 被脚本读取，却不能阻止脚本以用户浏览器身份发同源请求，因此它不是 XSS 修复。

常见类型按数据路径区分：

- **反射型 XSS**：请求参数立即进入响应 HTML，例如搜索词被原样拼到结果页；
- **存储型 XSS**：恶意值先存储，后来进入其他人的页面，例如工单描述、知识标题或附件文件名；
- **DOM 型 XSS**：服务端响应本身可能固定，前端 JavaScript 从 URL fragment、`postMessage` 或 API 数据读取值，再送入 `innerHTML` 等 sink。

三类可以重叠。诊断时记录 source、持久化点、浏览器解析上下文、实际 sink 和执行证据，比用攻击字符串给漏洞命名更可靠。

## 5. 浏览器不是只有一个“HTML 上下文”

浏览器依次使用 HTML、属性、URL、CSS 和 JavaScript 等解析器。同一个字符在不同解析器中意义不同，所以不存在“统一 escape 一次，到处安全”。关键原则是：先确定最终 sink 的上下文，再使用该上下文的编码或安全 API；如果上下文本身危险，就禁止插值。

### 5.1 HTML 文本节点

在 `<p>这里</p>` 之间显示普通文字时，`&`、`<`、`>` 等必须变成 HTML character references，避免产生标签。模板或框架默认的文本插值通常会完成这件事；DOM 更新优先使用 `textContent`。编码应发生在输出边界，数据库可保存原始业务文本，避免多次读写造成双重编码。

例如原文 `设备 <A&B>` 的目标是页面显示同样的文字，而不是显示编码字面量或创建标签。若入库时就编码，API、移动端、导出和再次编辑都会混入展示格式；若前后端各编码一次，用户会看到 `&lt;`。因此应保存语义值，在每个输出通道按上下文处理。

### 5.2 HTML 属性

属性值要放在引号内，并只允许固定、安全的属性名。普通 `title`、`aria-label`、`data-*` 的值可以做属性上下文编码；属性名本身不能由不可信数据决定。`onerror`、`onclick` 等事件处理属性是执行上下文，不接受不可信值；把字符编码后塞进去也不构成可靠设计。

布尔属性、类名和枚举样式应映射为程序内部固定值。例如优先级只能映射到 `priority-low|medium|high`，而不是把用户输入拼到 `class`。Vue 中优先使用属性绑定和枚举映射，不用字符串生成整个标签。

### 5.3 JavaScript 上下文

最安全的做法是不把不可信值直接插进 `<script>`、事件处理器或可执行表达式。服务端返回 `application/json`，前端解析为对象，再用安全 DOM API 写入文本。即使使用 JSON serializer，也要理解 HTML 解析器与 JavaScript 解析器的嵌套关系；把 JSON 字符串直接嵌入 script block 仍可能遇到结束标签和转义边界。

禁止把数据交给 `eval`、字符串形式的 `setTimeout`、`Function` 构造器或动态脚本 URL。安全代码与数据应通过结构化接口分离，而不是期望“多加一个反斜线”解决所有解析器组合。

### 5.4 URL 与 CSS 上下文

URL 参数需要 URL component 编码，随后如果放进 HTML 属性，还要由模板/DOM API安全设置该属性。编码只防止跳出语法，不决定 scheme 是否可信；`javascript:`、某些 `data:` URL 或外部重定向仍需协议和目标策略。链接、图片和下载分别定义允许 scheme 与来源，不共享一个“看起来像 URL”的正则。

CSS 也有自己的语法。最好把颜色、尺寸、状态样式映射到固定 token，不把用户值拼进 selector、`url()` 或整段 style。允许的 CSS property value 需要专用校验与 API；普通 HTML entity 编码不是 CSS 策略。

### 5.5 危险上下文

标签名、属性名、HTML 注释、script 源码、style 规则、事件处理器和可执行 URL 等上下文不应接收动态不可信值。遇到业务需求时先重构数据模型：例如把“用户可配置脚本”改为有限动作枚举，把“自定义 HTML”改为 Markdown 子集或经维护的 sanitizer allowlist。

## 6. 安全 sink 与危险 sink

相对安全 sink 包括 `textContent`、创建文本节点、框架默认文本插值、固定安全属性名的属性绑定。危险 sink 包括 `innerHTML`、`outerHTML`、`document.write`、Vue 的 `v-html`、动态事件处理器、`eval` 和未经策略验证的 `href/src`。

“安全 sink”仍有前提。给 `textContent` 设置数据不会执行 HTML，但若之后代码读取它再交给 `innerHTML`，安全性质在第二次转换处丢失。固定属性名 `href` 仍要检查 URL scheme。审查必须沿数据流看到最终 sink，不能只看到中途调用过一次 escape。

Vue 官方安全指南把模板视为代码：不能使用不可信内容作为组件模板。双大括号文本插值和常规属性绑定提供框架级转义，但 `v-html` 是明确的逃生口；它只应接收经过可信 sanitizer 的、业务确实需要的 HTML。框架行为属于当前实现约定，不替代浏览器标准和项目测试。

## 7. 富文本为什么需要清洗而非编码

如果知识作者确实需要段落、列表和强调，全部 HTML 编码会把标签显示成文字，破坏功能；此时需要专门 HTML sanitizer，把输入解析成 DOM，按允许的元素、属性和协议重建安全结果。正则替换标签不是 HTML parser，无法可靠处理嵌套、错误恢复、命名空间和编码变体。

清洗器配置应是最小 allowlist，例如只允许段落、列表、强调和受控链接；移除脚本、事件属性、style、iframe、表单以及未知 URL scheme。清洗后不要再用字符串拼接修改结构，否则会重新引入危险内容。库和规则要固定版本、持续升级，并用历史绕过样本做回归。

FactoryCare 的普通工单标题、备注、AI 摘要默认都是文本，不需要富文本。若知识正文未来允许富文本，应由独立发布流程清洗、版本化并记录 sanitizer 版本；客户端仍只在专用组件中渲染，不能把“已清洗”扩散成所有字段可信。

## 8. CSP、Trusted Types 与安全响应头的定位

Content Security Policy 可以限制脚本来源、禁止不安全内联脚本并产生违规报告；Trusted Types 可在支持的浏览器中约束若干 DOM XSS sink。它们是纵深防御：能降低编码或 sink 失守的影响，却不能让 `innerHTML` 拼接变成正确做法。宽泛的 `script-src * 'unsafe-inline'` 几乎失去关键价值，nonce/hash 生命周期和第三方脚本也需要设计。

`HttpOnly`、`Secure`、`SameSite`、`X-Content-Type-Options: nosniff` 与正确 `Content-Type` 同样是附加边界。Spring Security 可帮助写出若干响应头，但不会替业务选择输出上下文、清洗富文本或修复 Vue 的危险 sink。WAF 也只能拦截部分已知模式，不能作为 XSS 根因修复。

## 9. JSON API 与 XSS 的边界

JSON 响应中的字符串不会仅因包含 `<` 就自动执行。真正的风险通常在客户端把解析后的字段送入危险 DOM sink，或服务端用错误 Content-Type 让浏览器进行不同解释。API 应返回结构化 JSON 和明确 `application/json`；前端把业务文本写入文本节点，不把整个 JSON 片段拼成 HTML。

不要在后端为了“防 XSS”删除所有尖括号。移动端可能需要显示原文，知识搜索可能需要保留符号，且这仍防不住其他上下文。后端负责业务校验、存储原始语义和为服务端模板选择正确编码；前端负责其最终 DOM sink。责任可以跨团队，但不能无人拥有。

## 10. SSRF：把字符串变成服务器网络能力

Server-Side Request Forgery 发生在攻击者影响服务器要访问的目标或请求参数，从而借用服务器的网络位置、凭据或信任关系。浏览器无法直连的 loopback、集群服务、云元数据、管理端口和内部 DNS，可能对应用服务器可达。攻击者不一定读到响应；只要能触发状态变化、端口探测、计时差异或把数据转发到外部，就可能是 blind SSRF。

典型 sink 包括“从 URL 导入知识”“测试 Webhook”“抓取设备图片”“生成网页预览/PDF”“解析远程头像”“AI 通用 HTTP 工具”。危险来自请求能力，不只来自 `http://` 字符串。支持 `file:`、`jar:`、`ftp:` 或自定义协议的库会扩大攻击面；代理自动读取环境凭据、客户端自动跟随重定向也会绕过最初检查。

## 11. 第一优先：不要接受任意 URL

最可靠的设计是把自由 URL 改成业务标识。客户端提交 `manualId`，服务器从已配置的数据源读取；选择 `connectorId` 与相对资源路径，而不是提供完整 scheme/host；Webhook 由管理员通过受控流程登记并验证，普通业务请求只引用已批准目标。

FactoryCare 威胁模型 TM-13 明确禁止 AI 获得通用 HTTP/SQL 工具。Python 只能调用 Java 暴露的固定只读工具，参数是资源 ID 与分页上限；模型输出 URL 不能直接进入网络客户端。这种能力削减比不断扩充 URL 黑名单更可维护。

只有业务确实需要访问外部目标时，才建立专用 egress client。每个用例有独立 allowlist、方法、Header、凭据、响应大小和超时，不共享一个“万能 fetch(URL)”服务。

## 12. URL 解析、规范化与精确 allowlist

URL 必须由标准 parser 解析一次，拒绝解析错误、缺 host、userinfo、fragment 和非允许 scheme。比较的是解析、规范化后的 scheme、ASCII host 与有效 port；不要用 `startsWith`、`contains` 或无边界 `endsWith`。字符串 `https://manuals.example.test.attacker.example`、`https://manuals.example.test@attacker.example` 都能骗过幼稚检查。

allowlist 优先列出完整三元组，例如 `https://manuals.factorycare.example.test:443`。若允许子域，要明确 DNS 管理权和边界，不能简单允许任意 `*.example.test`。路径也按业务限制为固定前缀和字符集；禁止把 `..`、编码斜杠或 query 再解释成另一个目标。

WHATWG URL 定义浏览器 URL 解析算法，但 Java HTTP client、反向代理与上游服务可能采用不同 parser。生产应在实际技术栈中用同一个解析结果完成校验和请求，避免“校验一个字符串、客户端重新解析另一个字符串”。教学资产只建模规则，不声称复现全部 parser 差异。

## 13. IP 地址与 DNS 边界

域名 allowlist 不是终点。服务器解析 host 后，应检查全部 A 与 AAAA 结果，不允许 loopback、link-local、private、unique-local、multicast、unspecified、文档保留地址和环境定义的内部网段。只检查字符串 `127.0.0.1` 会漏掉 IPv6 loopback、整数/混合表示、内部 DNS 名和不同地址族。

需要理解两次检查之间的竞态。攻击域名可第一次解析到允许地址，通过校验后第二次解析到内网，这就是 DNS rebinding 类风险。应用层应尽量把已验证地址绑定到实际连接，并保持原 host 用于 HTTP Host/TLS SNI 与证书校验；但不同客户端的连接池、代理和 TLS 能力不同，不能随意手写。更强边界是在网络层只允许专用 egress proxy 或批准目标，明确阻断元数据和内部网段。

DNS 本身也要受控：使用组织解析器、监控 allowlist 域名的记录、对解析失败安全拒绝。不能为了“防重绑定”永久缓存地址而破坏轮换；应该让连接时证据与验证时证据一致，并用集成测试证明。

## 14. 重定向必须逐跳重新授权

如果客户端自动跟随 `302/307/308`，初始允许 URL 可以跳到 loopback 或私网。安全默认是关闭自动重定向；业务需要时手动读取 `Location`，解析相对地址，按同一 scheme/host/port/DNS/IP 规则逐跳验证，限制跳数，并阻止协议降级。每一跳都是新的网络决策，不能继承第一跳的信任。

重定向还可能改变方法或带出 Header。专用客户端不向不同 origin 转发 Authorization、Cookie、内部 trace 或签名 Header。即使目标仍允许，也要确认方法语义；服务器取文档通常只允许 GET/HEAD，绝不让输入决定 PUT、DELETE 或任意 body。

## 15. 预算、响应与失败策略

允许访问不代表无限访问。配置连接、TLS、响应头、首字节和总时限；限制响应字节、解压后大小、内容类型、重定向次数和并发；流式读取并在超过上限时终止。压缩炸弹、永不结束的响应和慢速连接属于 SSRF 之外的资源耗尽，但共享同一个 sink。

响应仍是不可信数据。不要把远端 HTML 直接回显给浏览器，不要自动执行脚本或宏，不要从响应复制 Set-Cookie。解析器同样要有深度与实体限制。错误响应只返回稳定 Problem code 和 traceId，不回显内部 IP、完整目标、代理凭据或堆栈；安全日志记录规则 ID、目标类别、拒绝阶段和脱敏 host hash，而不是签名 query。

## 16. FactoryCare 数据流落点

### 16.1 工单与报修文本

报修人提交描述 → Spring MVC JSON DTO → 业务长度校验 → PostgreSQL 原始文本 → Vue/Flutter 展示。服务端不能把 DTO 合法视为 HTML 安全；Vue 使用文本插值，Flutter 使用 Text widget。导出 CSV、通知和 PDF 各有自己的编码规则。测试注入 `script` 与 `onerror` 形态，断言页面 DOM 中只有文本、没有事件属性或新标签。

### 16.2 知识与 AI 输出

知识正文与 AI 答案都视为不可信数据。普通答案按文本/结构化引用展示；若支持 Markdown，使用固定 parser 与禁止原始 HTML 的配置，再对结果清洗。文档中的链接经过客户端 URL 策略，服务器不会因为模型返回 URL 就抓取。提示注入与 XSS 可以组合，因此模型输出不能升级为 HTML 或网络命令。

### 16.3 附件元数据

原始文件名只作展示元数据，存储对象键随机生成；Content-Disposition 由库安全构造。文件名进入 HTML、Header、日志与对象存储时分别处理，不能复用 HTML escape。附件下载保持私有与短时授权，不因文件名“清洗过”就允许内联执行。

### 16.4 服务器取 URL

当前 FactoryCare 设计没有面向普通用户的通用 URL 抓取接口，也不应为 AI 增加。未来若接设备厂商手册，只接受管理员批准的 connector 和文档 ID，由独立 egress client 访问精确来源；网络策略、凭据、超时和审计按 connector 隔离。这个未来扩展是设计约束，不是已实现功能。

## 17. CSRF、XSS 与 SSRF 不可互相替代

CSRF 利用浏览器自动携带认证状态发用户未意愿的请求；XSS 让不可信内容在可信 origin 中执行；SSRF 借服务器访问网络目标。三者可以串联：跨站表单写入恶意工单描述，管理端危险 sink 执行，脚本再触发服务器 URL 导入。但每个边界仍需自己的控制。

CSRF Token 不会编码 HTML；SameSite 不会阻止服务器访问 loopback；CORS 不会授权出站目标；CSP 不会验证 URL DNS。完整 DFD 应分别标注浏览器请求意图、输出解释器和服务器 egress。

## 18. 诊断：从第一处可信偏差开始

| 故障 | 首个可信证据 | 根因位置 | 正确修复 |
| --- | --- | --- | --- |
| 缺 Token 的跨站 POST 写入成功 | 写计数从 0 变 1 | CSRF 请求边界 | 恢复 Token/Origin 并断言无副作用 |
| 工单文字产生新 `<img>` 节点 | DOM 结构而非响应字符串 | HTML sink | 文本插值/上下文编码，禁止 `v-html` |
| `onerror` 被保留 | 元素出现事件属性 | 属性/清洗策略 | 固定属性名，富文本 sanitizer allowlist |
| `http://127.0.0.1` 被接受 | 连接前决策为 allow | scheme/IP 策略 | HTTPS 精确目标与地址分类 |
| 允许站点跳到私网 | 第二跳未重新评估 | redirect client | 关闭自动跳转或逐跳验证 |
| 验证 DNS 公网、连接 DNS 内网 | 两次解析结果不同仍连接 | TOCTOU/egress | 绑定已验证连接并加网络层阻断 |

不要先观察浏览器弹窗或等待真实内网响应。离线断言可把“会不会执行/连接”转为结构证据：输出是否仍含活动标签，属性名是否在安全集合，决策是否在连接前拒绝，重定向每跳是否重新调用策略，解析绑定是否一致。

## 19. 可重放测试矩阵

XSS 至少覆盖：普通中文和符号；`&<>"'`；标签与事件属性形态；已存储后由另一用户读取；DOM URL fragment；安全文本 sink；危险 HTML sink 被禁止；允许富文本的 sanitizer 正负元素/属性/协议；CSP 只作附加证据。

SSRF 至少覆盖：精确允许 HTTPS；非允许 host/port/scheme；userinfo；loopback、link-local、IPv4 private、IPv6 loopback/unique-local；多个 DNS 地址中混入一个禁区；重定向到禁区；超跳数；第一次与连接时解析变化；连接/读取/总超时；超大与错误类型响应。测试使用 fake resolver 与 fake transport，不访问公网或真实内网。

真实实现还需要浏览器 E2E、Spring MVC 集成、实际 HTTP client 行为、DNS/代理/容器网络和部署防火墙测试。单元测试只能验证纯决策函数，不能替代这些边界。

## 20. 常见错误及失败原因

- **入库前统一 HTML escape**：污染领域数据、引发双重编码，且无法覆盖 JS/URL/CSS 上下文；
- **删除 `<script>` 即安全**：漏掉事件属性、SVG、DOM sink 和解析变体；
- **所有地方都用 `innerHTML`，因为内容来自 API**：API/数据库都可能保存不可信数据；
- **允许 `v-html` 后只靠 CSP**：CSP 是易配置错误的纵深控制，不是 sink 修复；
- **URL 包含公司域名就放行**：userinfo、攻击者后缀和解析差异会绕过；
- **只禁 `127.0.0.1`**：漏 IPv6、私网、link-local、内部 DNS 与编码形式；
- **第一跳合法就自动重定向**：后续 Location 可越过边界；
- **应用校验足以替代防火墙**：parser、DNS、代理和竞态仍可能失守；
- **记录完整拒绝 URL 便于排错**：query 可能含签名、凭据和个人数据；
- **安全扫描器无告警等于安全**：扫描器不能证明业务 connector、网络可达性和最终 DOM sink。

## 21. 120 秒口述模板

“不可信不是指数据一定恶意，而是当前边界没有资格假设它安全。我先画 source、transform、sink。XSS 的 sink 是浏览器解释器：普通文本在最终 HTML 文本位置做上下文编码并使用 textContent/框架文本插值；属性、URL、JS、CSS 使用各自规则，危险上下文禁止插值；业务需要富文本时用维护中的 sanitizer，CSP 只是纵深。SSRF 的 sink 是服务器网络客户端：优先不用任意 URL，而用 connector/资源 ID；必须请求时解析规范化、精确 allowlist、检查全部 DNS/IP、逐跳验证重定向、绑定连接证据，并用超时/大小/方法限制和网络 egress 阻断。输入校验、CSRF、CORS、CSP 都不能替代这两个 sink 的控制。反例是允许域名的 URL 自动跳到私网，第一跳检查通过仍然失败。”

## 22. 资料层级、时效与适用范围

截至 2026-07-17，本章按以下层级使用资料：

- [WHATWG HTML Living Standard](https://html.spec.whatwg.org/) 与 [WHATWG URL Living Standard](https://url.spec.whatwg.org/)：浏览器 HTML/DOM 与 URL 解析的现行规范算法。Living Standard 会更新；它们不替项目决定允许哪些内容或网络目标。
- [RFC 1918](https://www.rfc-editor.org/rfc/rfc1918.html)、[RFC 4193](https://www.rfc-editor.org/rfc/rfc4193.html) 与 [RFC 4291](https://www.rfc-editor.org/rfc/rfc4291.html)：IPv4 private、IPv6 unique-local 与 IPv6 地址语义的已发布标准资料；生产还必须覆盖 link-local、loopback、云元数据和部署自定义网段。
- [W3C Content Security Policy Level 3](https://www.w3.org/TR/CSP3/)：CSP 机制规范；本章只把它当纵深防御，不把它写成输出编码替代品。
- [OWASP Cross Site Scripting Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)、[DOM based XSS Prevention](https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html) 与 [SSRF Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html)：上下文编码、safe sink、清洗、allowlist、DNS pinning 和纵深控制的权威工程建议，不是浏览器或 HTTP 协议标准。
- [Vue Security Guide](https://vuejs.org/guide/best-practices/security.html)：Vue 当前模板转义与危险逃生口的框架行为。它只对采用的 Vue 版本和写法适用，必须由组件/E2E 测试确认。
- [Spring Security Security HTTP Response Headers](https://docs.spring.io/spring-security/reference/servlet/exploits/headers.html)：Spring 提供安全响应头集成的当前框架文档；Spring MVC 校验和 Spring Security 响应头都不会自动修复业务输出 sink 或 SSRF client。

规范告诉我们解析器和协议怎样工作；OWASP 给出工程防护建议；框架文档说明当前默认和逃生口；FactoryCare 威胁模型决定资产、允许能力与验收。四层不能互相替代。
