---
schema_version: 2
edition: 2026.2-draft
id: ch.web.origin-cookie-cache
title: Origin、同源、Cookie、缓存与 CORS 浏览器模型
responsibility: 解释浏览器如何按 Origin 隔离读取、携带 Cookie 并复用缓存，区分浏览器 CORS 执行与服务端授权，不进入登录业务实现。
volume: '07'
order: 2
level: L1
status: drafting
path: book/volume-07-web-platform/chapters/ch.web.origin-cookie-cache.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.web.browser-render-devtools
version_surfaces:
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
  text: 在 120 秒内解释“Origin、同源、Cookie、缓存与 CORS 浏览器模型”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - web-origin-browser-security
  - web-browser-cache-model
  covers_topics:
  - web.origin-tuple
  - web.same-origin-policy
  - web.cors-browser-enforcement
  - web.cookie-attachment
  - web.http-cache-browser
  - web.cache-validation
  - web.navigation-cache-effect
  - web.layout-paint-composite
  uses_capabilities:
  - web.browser-rendering
  - foundation.http-message
  - web.browser-origin-state
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“Origin、同源、Cookie、缓存与 CORS 浏览器模型”构建可运行程序与测试：搭建两个 Origin 的最小请求矩阵并记录 Cookie、CORS 与缓存结果；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - web-origin-browser-security
  - web-browser-cache-model
  covers_topics:
  - web.origin-tuple
  - web.same-origin-policy
  - web.cors-browser-enforcement
  - web.cookie-attachment
  - web.http-cache-browser
  - web.cache-validation
  - web.navigation-cache-effect
  - web.layout-paint-composite
  uses_capabilities:
  - web.browser-rendering
  - foundation.http-message
  - web.browser-origin-state
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: prediction-request-matrix-header-assertions
- id: diagnose
  kind: fault-diagnosis
  text: 面对“错误的 Origin、SameSite 或缓存头引起的请求阻断与陈旧响应”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - web-origin-browser-security
  - web-browser-cache-model
  covers_topics:
  - web.origin-tuple
  - web.same-origin-policy
  - web.cors-browser-enforcement
  - web.cookie-attachment
  - web.http-cache-browser
  - web.cache-validation
  - web.navigation-cache-effect
  - web.layout-paint-composite
  uses_capabilities:
  - web.browser-rendering
  - foundation.http-message
  - web.browser-origin-state
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Origin、同源、Cookie、缓存与 CORS 浏览器模型

> 本章状态为 `drafting`。配套资产用固定 URL、Cookie、CORS 与 HTTP cache 头构造离线请求矩阵，验证决策规则和红绿灯；它不启动真实 HTTPS、图形浏览器、代理/CDN、身份 Provider 或 FactoryCare 登录。浏览器策略会随版本与隐私机制演进，生产 cookie 属性、CORS allowlist 和缓存策略尚须在锁定部署拓扑后做真实浏览器与服务端安全测试。

浏览器收到页面后，不允许任意页面读取任意网站的响应，也不会把所有 Cookie 发给所有 URL，更不会永远从网络重新下载相同资源。它用 Origin 隔离脚本读取，用 Cookie 的 host/domain、path、Secure、SameSite、过期等条件决定附带，用 Fetch credentials mode 决定跨源凭据行为，用 CORS 响应头决定跨源响应能否共享给脚本，再用 HTTP cache 规则判断能否复用或验证旧响应。

这些机制容易被一句“跨域问题”混成一团。一个请求可能已经到达服务器并改变状态，但浏览器因 CORS 不把响应交给脚本；Cookie 可能满足 SameSite，却因 `credentials: "include"` 缺失而未随跨源 fetch 发送；服务器可能返回正确 `Access-Control-Allow-Origin`，但服务端仍应以 401/403 拒绝无权用户；缓存可能返回 304，页面却应复用本地 body 正常显示。诊断必须逐层写出预言。

## 1. 完成定义与证据入口

完成本章，应能：

1. 从 URL 算出普通 HTTP(S) Origin 的 scheme、host、port，并判断一组 URL 是否同源；
2. 区分 same-origin 与 same-site，解释为什么 `localhost:4173` 和 `localhost:4174` 跨 Origin 却通常仍是 same-site；
3. 说明同源策略主要限制跨源读取，不等于禁止一切跨源发送、导航或嵌入；
4. 解释 CORS 由浏览器执行、由服务器响应头声明共享条件，但不提供身份认证、业务授权或 CSRF 完整防护；
5. 逐项判断 Cookie 的 host/domain、path、Secure、HttpOnly、SameSite、Max-Age/Expires 与 Fetch credentials；
6. 区分 fresh reuse、stale revalidation、`ETag`/`If-None-Match`/304，以及 `no-cache`、`no-store`、`private`；
7. 解释 `Vary` 如何参与表示选择，为什么动态回显 Origin 却漏 `Vary: Origin` 会造成缓存串用；
8. 搭建固定同源/跨源矩阵，保存 Origin、Cookie、请求 credentials、CORS/cache 响应头、控制台与 Network 结果；
9. 注入错误 Origin、SameSite 或缓存头，指出首个可信证据，修复并用同一矩阵重跑。

配套入口：

- [Origin/Cookie/CORS/cache 请求矩阵示例](../../../examples/encyclopedia/ch.web.origin-cookie-cache/README.md)
- [三类策略故障实验](../../../labs/encyclopedia/ch.web.origin-cookie-cache/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.web.origin-cookie-cache/README.md)

本章验收是固定矩阵得到确定结果，并可由响应头和浏览器控制台复核。只看前端报错、只用 curl 成功，或只看到 Cookie 存在，都不足以证明浏览器会发送且脚本可读取响应。

## 2. URL、Origin 与 Site：先把三个词拆开

### 2.1 URL 是资源地址

以 `https://api.factorycare.test:8443/api/v1/work-orders?page=1#top` 为例：

```text
scheme   = https
host     = api.factorycare.test
port     = 8443
path     = /api/v1/work-orders
query    = page=1
fragment = top
```

fragment 不随普通 HTTP 请求发给服务器。path/query 会影响目标资源，但不属于 Origin tuple。用户名密码形式、国际域名、IPv6、默认端口和 URL 规范化还有更多规则；本章使用已解析的有效 URL，不手写脆弱字符串切割器。

### 2.2 Origin 通常是 scheme + host + port

对普通 HTTP(S) URL，Origin 可用 `(scheme, host, port)` 理解。默认端口规范化后比较，例如 `https://example.test/` 与显式 `https://example.test:443/` 同源；scheme、host 或有效 port 任一不同就是跨源。

| A | B | 同源？ | 第一差异 |
|---|---|---:|---|
| `https://app.factorycare.test/a` | `https://app.factorycare.test/b` | 是 | 只有 path 不同 |
| `https://app.factorycare.test` | `http://app.factorycare.test` | 否 | scheme |
| `https://app.factorycare.test` | `https://api.factorycare.test` | 否 | host |
| `https://app.factorycare.test:443` | `https://app.factorycare.test:8443` | 否 | port |
| `http://localhost:4173` | `http://localhost:4174` | 否 | port |

`data:`、沙箱 iframe 等可能产生 opaque origin，不能简单还原为 tuple。不要把字符串前缀相同、DNS 指向同一 IP、同一公司、同一证书或同一服务器当“同源”。Origin 是浏览器安全主体，不是组织架构标签。

### 2.3 Site 比 Origin 宽

现代 SameSite 判断使用 schemeful site 等规则，核心直觉是 scheme 与 registrable domain/site，而端口不是 site 边界。`https://app.factorycare.test:8443` 与 `https://api.factorycare.test:9443` 跨 Origin，却可为 same-site；`https://app.factorycare.test` 与 `https://api.vendor.test` 是 cross-site。

这一区分决定实验设计：两个 localhost 端口足以触发 CORS，却不能单独证明 cross-site SameSite Cookie 被阻断。要测试 SameSite，必须额外使用不同 site（并配置 HTTPS/域名）或使用浏览器测试框架明确模拟 site context。教材矩阵同时列 Origin 与 Site 两列，避免把一次结果错误归因。

## 3. 同源策略：限制读取，不是“跨源请求总禁令”

同源策略（Same-Origin Policy, SOP）是一组浏览器隔离规则，目的是防止恶意页面直接读取另一个 Origin 的敏感数据。页面可以执行某些跨源导航、表单提交、图片/样式/script/iframe 嵌入或请求；能否读取内容、访问 DOM、获取详细错误则受不同规则限制。

因此以下说法都不准确：

- “跨域请求根本发不出去”——简单跨源请求可能已到服务器，浏览器只是不向脚本共享响应；
- “看到 CORS 错误说明后端没执行”——状态改变可能已经发生，所以写操作仍需 CSRF 与幂等；
- “图片能显示说明 fetch 能读 body”——嵌入资源与脚本读取权限不是同一能力；
- “两个服务都在 localhost 所以同源”——port 不同即跨 Origin；
- “关闭浏览器安全就修好了”——那只移除了本机执行器，生产用户和安全边界仍失败。

SOP 是客户端纵深防御，不替代服务端授权。攻击者可以直接用 curl、服务端程序或自制客户端访问 API；FactoryCare Java 必须从受信 session/bearer 重建 actor、tenant、role 和 data scope，不能依赖浏览器“帮忙拦住”。

## 4. CORS：服务器声明，浏览器执行的响应共享协议

### 4.1 最小跨源读取

页面 Origin 是 `https://app.factorycare.test`，请求 `https://api.factorycare.test/api/v1/auth/me`。浏览器发送 `Origin: https://app.factorycare.test`。若 API 允许该来源，可响应：

```http
Access-Control-Allow-Origin: https://app.factorycare.test
Vary: Origin
```

浏览器比较请求上下文与响应头，决定是否把响应交给脚本。`Access-Control-Allow-Origin` 不是服务器替用户授权；它只允许某 Origin 的脚本读取。服务器在生成此头之前/同时仍要认证 session、检查成员状态和权限。

如果允许多个指定 Origin，服务端应从严格 allowlist 选择并回显匹配值，同时发送 `Vary: Origin`，让 HTTP cache 不把为 A 生成的响应拿给 B。不能把请求里的任意 Origin 原样回显；那等于向所有来源开放共享。

### 4.2 简单请求与预检

Fetch 规范定义 CORS-safelisted method/header/content type 等条件。满足条件的跨源请求可直接发送，响应仍需 CORS 检查。不满足时，浏览器先发 `OPTIONS` preflight，询问服务器是否允许目标 method/headers；preflight 成功后才发送实际请求。

典型过程：

```text
页面 fetch 跨源 PUT + X-CSRF-Token
  → 浏览器 OPTIONS，带 Origin、Access-Control-Request-Method/Headers
  → 服务器返回允许的 Origin、Methods、Headers
  → 浏览器通过后发送实际 PUT
  → 实际响应也要有适用的 CORS 头
  → 浏览器决定脚本是否可读
```

预检是浏览器对跨源脚本请求的保护，不是认证握手；规范上 CORS-preflight fetch 的 credentials mode 为 same-origin，跨源 preflight 本身不带目标站凭据。服务端应能安全处理 OPTIONS，却不能因此跳过实际请求的认证授权。

### 4.3 带 Cookie 的跨源 fetch

Fetch `credentials` 有 `omit`、`same-origin`、`include`。常见 `fetch()` 默认是 `same-origin`：跨 Origin 时不会按 include 模式处理凭据。要让满足 Cookie 规则的跨源请求携带 Cookie，并接受 `Set-Cookie`，调用方通常需显式：

```js
fetch("https://api.factorycare.test/api/v1/auth/me", {
  credentials: "include"
})
```

服务器还需返回精确 Origin 和：

```http
Access-Control-Allow-Origin: https://app.factorycare.test
Access-Control-Allow-Credentials: true
Vary: Origin
```

带 credentials 时不能用 `Access-Control-Allow-Origin: *` 共享响应。`true` 的拼写/大小写按协议精确处理。即使这些都正确，Cookie 自身的 host/domain、path、Secure、SameSite、expiry 仍可能让它不发送。

### 4.4 CORS 诊断顺序

1. 页面实际 Origin 是什么？不要把完整 URL/path 写进 allowlist；
2. 请求是否出现，是否先有 OPTIONS？
3. OPTIONS 的 Origin、requested method/headers 和响应状态/allow headers 是什么？
4. 实际请求是否到服务器，响应是否含匹配 ACAO/ACAC？
5. fetch credentials mode 是什么？
6. Cookie 是否在 Request Headers，若没有看 blocked reason/Issues/Cookies；
7. 服务端返回 401/403 还是浏览器将响应变成脚本侧 network error？
8. 是否由缓存返回了另一个 Origin 对应的 CORS 头，`Vary: Origin` 是否缺失？

Console 的 “blocked by CORS policy” 是入口线索；Network 的请求/响应头、服务器 access log 和非浏览器负测共同判因。

## 5. Cookie：按目标 URL 与请求上下文附带的状态

### 5.1 Set-Cookie 与 Cookie 是两个方向

服务器响应使用 `Set-Cookie` 建立/更新 Cookie；浏览器在后续匹配请求中使用 `Cookie` 请求头附带。前端不能通过普通 Response Headers API 读取 `Set-Cookie`。Cookie jar 由 user agent 管理，是否接受/发送还受隐私设置、存储分区和版本策略影响。

教学响应：

```http
Set-Cookie: FACTORYCARE_SESSION=opaque-id; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=1800
```

这是**教学夹具，不是 FactoryCare 已批准生产合同**。项目 ADR 只要求 Web 会话 Cookie 具备 `HttpOnly; Secure; SameSite`，尚未决定具体 SameSite 值、Path、Domain 或寿命。

### 5.2 Host-only 与 Domain

不写 `Domain` 时是 host-only Cookie，只发给设置它的 host。写 `Domain=example.test` 后，可匹配该 domain 及子域（仍受 user agent 验证），作用面更大。Cookie 不以 port 为边界：由 `api.factorycare.test:8443` 设置的匹配 Cookie 也可能发往相同 host 的其他端口。

因此 Cookie 与 Origin 不能画等号。将 session Cookie 设为父 domain 会让更多子域接收，增加子域接管/泄漏风险；除非明确需要，host-only 通常更小。不能由前端随意指定另一个无关 domain。

### 5.3 Path 不是安全边界

`Path=/api` 影响浏览器把 Cookie 附带到哪些 path，但同 host 的其他页面/脚本仍可能通过请求、覆盖等方式产生影响。规范明确不应把 Path 视为阻止同源未授权读取/影响的安全边界。真正隔离使用 host、origin、服务端权限与独立凭据设计。

### 5.4 Secure 与 HttpOnly

- `Secure` 要求 Cookie 只在 user agent 认为安全的通道发送；生产应使用 HTTPS。localhost 的例外行为不可写成跨浏览器生产保证。
- `HttpOnly` 让非 HTTP API（如 `document.cookie`）不能读取该 Cookie，可降低某些 XSS 直接窃取 session 的风险；浏览器仍会在匹配 HTTP 请求中发送。

`HttpOnly` 不阻止 CSRF，因为攻击页面不必读取 Cookie，只需诱导浏览器发送请求；`Secure` 也不提供服务端授权或加密浏览器存储。XSS 仍可代表当前用户发起同源操作，所以还需输入输出防护、CSP 等后续措施。

### 5.5 SameSite

- `Strict`：只在 same-site 请求语境附带，保护强但可能打断外站进入后的会话体验；
- `Lax`：same-site 可附带，并对规范定义的安全方法顶层导航有放行；
- `None`：允许 cross-site 语境，但必须同时有 `Secure`。

省略或非法 SameSite 的默认处理和兼容窗口可能由浏览器演进；实验必须显式设置、记录浏览器完整版本，不依赖“我这台 Chrome 默认怎样”。SameSite 依据 site，不依据 Origin，所以同 site 的跨端口/子域 fetch 与真正 cross-site 请求结果不同。

SameSite 是 CSRF 纵深防御，不替代状态写的 CSRF token、Origin/Referer 策略、幂等和服务端授权。FactoryCare Web 的写请求还要求 `X-CSRF-Token`；移动 bearer 客户端使用不同认证方式，不发送浏览器 CSRF credential。

### 5.6 Max-Age、Expires 与 session Cookie

`Max-Age` 用相对秒数，`Expires` 用日期；两者同现时 Max-Age 优先。二者都没有时通常称 session Cookie，但 user agent 的会话恢复可能延长其实际存在，不能把“关窗口必删”当安全合同。登出必须让服务端 session 失效并清理 Cookie；只删除客户端值而服务器 session 仍有效不够。

Cookie 的过期也不等于用户权限到期。FactoryCare 每次请求仍重建当前 membership/role/data scope，成员禁用后现有 session 应立即无权；FC-AUTH-004 还要求登录轮换 session ID、登出后旧 Cookie 不可访问。

## 6. 把 Cookie、credentials、SameSite 与 CORS 放入一张矩阵

假设：

- 页面 A：`https://app.factorycare.test:8443`；
- API B：`https://api.factorycare.test:9443`，与 A cross-origin、same-site；
- 外站 C：`https://api.vendor.test:9443`，与 A cross-origin、cross-site；
- session 是 B 设置的 host-only Cookie。

| 页面→目标 | Origin关系 | Site关系 | fetch mode | SameSite | Cookie候选 | 脚本读响应还需 |
|---|---|---|---|---|---|---|
| A→A | same-origin | same-site | 默认 same-origin | Lax | 可（再看 host/path/expiry） | 不走 CORS |
| A→B | cross-origin | same-site | 默认 same-origin | Lax | 不按 include 发送跨源凭据 | CORS；若要 Cookie 设 include+ACAC |
| A→B | cross-origin | same-site | include | Lax | 可（B host 匹配） | 精确 ACAO、ACAC true、Vary Origin |
| A→C | cross-origin | cross-site | include | Lax | 通常不适用于子资源 fetch | 即使无 Cookie，读取仍需 CORS |
| A→C | cross-origin | cross-site | include | None; Secure | 可在其他条件满足时 | 精确 ACAO、ACAC true、Vary Origin |

“Cookie 候选”不保证浏览器一定发送：用户隐私策略、第三方 Cookie 限制/分区、存储访问规则等版本面仍可能阻止。矩阵的作用是逐层排除，而不是发明一个永不过时的浏览器承诺。

顶层 navigation 与 `fetch` 的 credentials/SameSite 语境也不同。测试要标记 request mode/initiator，不能用地址栏导航成功推断跨源 fetch 会带相同 Cookie。

## 7. 浏览器 HTTP Cache：存储响应、判断能否复用

### 7.1 浏览器 cache 与其他 cache

浏览器 HTTP cache 是用户代理保存先前 HTTP 响应并控制复用的机制。它不同于：

- FactoryCare 服务端 Redis cache-aside（服务端数据读取优化）；
- CDN/shared proxy cache（多个客户端可能共享）；
- Service Worker Cache API（脚本管理、与 HTTP cache 分离）；
- JavaScript 内存状态、Pinia store、IndexedDB/localStorage；
- 数据库查询缓存或操作系统文件缓存。

页面看到旧数据时先确认是哪一层，不要用“清浏览器缓存”掩盖 Redis key/数据库一致性问题，也不要重启 Redis 来修静态 CSS 缓存。

### 7.2 Cache key 与 Vary

RFC 9111 的缓存 key 至少来自 request method 与 target URI；实现还可分区或加入其他材料。`Vary` 指示哪些请求头参与已存响应的选择。例如：

```http
Vary: Accept-Encoding, Origin
```

若服务器按 `Origin` 动态生成 `Access-Control-Allow-Origin`，却未 `Vary: Origin`，共享/浏览器 cache 可能把为 A 生成的响应误用于 C，导致泄露或错误 CORS 阻断。`Vary: *` 基本阻止正常复用，不应作为不知道如何建 key 时的万能修复。

### 7.3 Fresh 与 stale

fresh response 在规则允许时可直接复用，不访问 origin server；stale response 通常需要 revalidate，除非适用允许 stale 的规则。浏览器可能因容量、用户操作、分区或实现策略提前驱逐，`max-age=3600` 是最长 freshness 指令语义，不是“保证保存一小时”。

```http
Cache-Control: public, max-age=3600
```

表示可由 shared cache 存储且 freshness lifetime 为一小时（仍受完整协议/实现约束）。对带内容哈希的静态资源可使用长 freshness；URL 不变却内容会变时，长 max-age 会制造陈旧版本，应使用版本化 URL或合适验证策略。

### 7.4 no-cache、no-store、private

- `no-cache`：可以存储，但复用前必须向 origin 验证；它不是“不缓存”。
- `no-store`：cache 不得存储该请求/响应，适合高敏感或明确不可存储内容；它不是清除所有既有副本、历史、截图或应用内存的隐私魔法。
- `private`：响应可以存入私有 cache，但 shared cache 不得存储；它不是“内容已加密”。
- `public`：明确允许 shared cache（仍需满足其他规则）；对认证/个性化内容应非常谨慎。
- `s-maxage`：针对 shared cache，和浏览器私有 cache 的 max-age 边界不同。

示例策略必须按资源分类，不能给所有响应复制一条 header。个性化 `/api/v1/auth/me`、公共静态 CSS、HTML shell 和公开图片的泄露风险/更新方式不同。FactoryCare 当前合同没有批准具体 HTTP cache headers，本章只提供分析方法。

### 7.5 ETag、If-None-Match 与 304

`ETag` 是服务器给某个 representation 的 opaque validator。缓存保存 body 和：

```http
ETag: "work-order-shell-v3"
Cache-Control: no-cache
```

下次 revalidation 可发送：

```http
If-None-Match: "work-order-shell-v3"
```

若当前 representation 与 validator 匹配，GET/HEAD 可返回 `304 Not Modified`，不带新的完整 representation body；浏览器把更新后的 304 元数据与已存 200 body 组合供页面使用。因此 Network 出现 304 不是“空响应导致空页面”，也不等于资源未使用。

FactoryCare API 的“版本字段或 ETag 语义防覆盖”是写并发前置条件（如 `If-Match`/version conflict）的设计问题；本章的 `If-None-Match`/304 是 GET cache validation。两者都用 entity tag 概念，但目标、状态和失败处理不同，不能自动共用一个实现或测试。

### 7.6 缓存如何影响导航与渲染

首次导航需要传输 HTML/CSS/图片；后续导航可能直接 fresh reuse，或发条件请求收到 304，再把本地 body 输入 parser/style/layout/paint。Network 仍可能显示条目，但 Size/Transferred、status/timing 的含义不同。即使字节来自 cache，浏览器仍可能解析、样式计算、layout 和 paint；“from memory cache”不等于跳过渲染管线。

DevTools 的 Disable cache、Empty cache and hard reload、普通 reload 各会改变实验。记录按钮状态和具体动作；不要比较一次冷缓存与一次热缓存后声称代码性能优化成功。

## 8. 两 Origin 最小实验设计

### 8.1 固定拓扑

为了只训练浏览器模型，定义两个 HTTPS Origin：

```text
App A = https://app.factorycare.test:8443
API B = https://api.factorycare.test:9443
```

二者 cross-origin、same-site。若要验证 cross-site SameSite，再增加 C=`https://api.vendor.test:9443`，不能用另一个 localhost port 冒充。真实运行需本地 DNS/hosts、可信测试证书和明确端口；不要关闭 TLS 校验作为最终证据。离线资产只计算矩阵，不声称完成真实 HTTPS。

### 8.2 端点与头

API B 提供合成端点：

```text
GET /public       无 Cookie，允许 A 读取
GET /session      需要 FACTORYCARE_SESSION，允许 A credentials
PUT /work-orders/WO-DEMO  需要 session + X-CSRF-Token，触发 preflight
GET /asset.css    ETag + no-cache，支持 304
GET /origin-view  按 allowlist 回显 ACAO，并 Vary: Origin
```

所有值为合成数据。响应记录 `Access-Control-Allow-Origin`、`Access-Control-Allow-Credentials`、`Vary`、`Cache-Control`、`ETag`；浏览器记录 Origin、Cookie 是否发送、OPTIONS/实际请求、脚本结果、Console 与 cache transfer status。

### 8.3 先写预测矩阵

| Case | 页面 | 目标 | credentials | Cookie/SameSite | CORS/cache 预言 |
|---|---|---|---|---|---|
| S1 | A | A public | same-origin | 无 | 同源可读 |
| C1 | A | B public | omit | 无 | 精确 ACAO 后可读 |
| C2 | A | B session | same-origin | B 的 Lax | 无跨源凭据，服务端 401 |
| C3 | A | B session | include | B 的 Lax | Cookie 候选；精确 ACAO+ACAC 后可读 |
| P1 | A | B PUT | include | session + CSRF header | OPTIONS 通过后实际请求，仍做授权/CSRF |
| X1 | A | B | include | Cookie 候选 | ACAO `*` + credentials，脚本读取失败 |
| K1 | A | B CSS first | omit | 无 | 200 + ETag，保存表示 |
| K2 | A | B CSS repeat | omit | 无 | If-None-Match，304 后复用旧 body |

执行后不能删除失败行。每行保存预言、Network 请求/响应、Console/脚本结果、服务器是否收到、cache status。用 curl 复核响应头，但注明 curl 不执行 SOP/CORS/SameSite 浏览器规则。

## 9. 三类故障：找第一证据

### 9.1 错误 Origin

配置 allowlist 为 `https://app.factorycare.test:8443/`（错误地带 path slash）或旧端口 8444。页面实际 Origin 不匹配。预期：请求可能到 API，响应无匹配 ACAO，脚本得到 CORS network error；服务端 access log 仍可能显示 200/401。

首证据顺序：页面 Origin → Request `Origin` → Response ACAO → Console → server log。修复严格 allowlist 值并重跑，不能改成反射任意 Origin或 `*` 配 credentials。

### 9.2 错误 SameSite/credentials

从 cross-site C fetch B 的 session endpoint，Cookie 是 `SameSite=Lax`；或 A→B 跨源 fetch 忘写 `credentials: include`。两者都表现为 Request Headers 无 Cookie，但原因不同。

先记录 initiator/top-level site、目标 Cookie attributes、blocked reason、fetch credentials mode，再判断。修复实验可分别：A→B same-site + include；或确有跨站业务时使用 `SameSite=None; Secure`、include、精确 CORS，并完成 CSRF/第三方 Cookie 兼容评估。不能为了让 demo 通过把真实 session 全域、跨站、长期开放。

### 9.3 错误缓存头与陈旧响应

服务器在不变 URL `/app.css` 返回 `Cache-Control: public, max-age=86400`，随后内容改变但 URL 不变。第二次 navigation 仍 fresh reuse，服务端可能根本收不到请求，页面呈现旧 CSS。第一证据是 Network 的 cache 来源/transfer 与 response freshness，不是 DOM parser 随机失败。

修复策略取决于资源：内容哈希 URL + 长 freshness，或短 freshness/`no-cache` + ETag revalidation。修正后用“首次 200→内容更新→再次请求/304或新 URL 200”的同一序列重跑。强制清缓存只能临时恢复本机，不能修用户部署策略。

### 9.4 漏 Vary: Origin

API 为 A 回显 ACAO 并被 cache 保存，随后 C 请求相同 URL。若没有 `Vary: Origin`，缓存可能复用 A 的响应：C 被错误阻断，甚至在更糟配置中共享不应共享的表示。先看 response age/cache status、ACAO 是否属于另一请求，再查 Vary。修复添加 `Vary: Origin` 并隔离既有错误 cache entry；只改 CORS controller 不清理污染条目可能暂时继续失败。

## 10. 症状到证据的速查表

| 症状 | 第一检查 | 可能原因 | 不要误判为 |
|---|---|---|---|
| fetch 抛 TypeError/network error | Network + Console + server log | CORS/网络/TLS | 服务器一定没执行 |
| OPTIONS 403 | preflight request/response | method/header/origin 未允许 | session Cookie 过期（预检通常无目标凭据） |
| 实际请求 200 但脚本读不到 | ACAO/ACAC/credentials | CORS response check | 业务成功可安全重试 |
| Cookie jar 有值但请求不带 | target host/path/secure/site/expiry/credentials | 多层匹配失败 | CORS header 单一问题 |
| document.cookie 看不到 session | HttpOnly | 预期保护 | Cookie 不会随请求发送 |
| 两 localhost 端口需 CORS | Origin port 不同 | cross-origin same-site | cross-site SameSite 已测试 |
| 304 无 body | ETag validation | 复用缓存 body | 空页面响应 |
| 改 CSS 后仍旧 | cache freshness/URL | 长 max-age、不变 URL | CSSOM 必然坏了 |
| A 正常、C 得到 A 的 ACAO | Vary/cache key | 漏 `Vary: Origin` | 浏览器随机缓存 |
| `no-cache` 仍有 cache | 指令语义 | 允许存储但每次验证 | 浏览器违反 no-store |

## 11. FactoryCare 的真实落点与未决项

FactoryCare ADR-0003 规定：Web 完成 OIDC Authorization Code 流程后由 Java 建立 `HttpOnly; Secure; SameSite` session Cookie；状态写请求启用 CSRF。OpenAPI 将 Cookie 名声明为 `FACTORYCARE_SESSION`，另有 `X-CSRF-Token`。这些事实可用于本章建模，但登录流程、Provider、session 存储与 token 验证不在本章实现。

一次管理端请求应按层判断：

1. 部署拓扑决定页面与 API 是否同 Origin/same-site；
2. 浏览器按 Cookie attributes 与 fetch credentials 决定是否附带；
3. 跨源时服务器按 allowlist 输出 CORS，浏览器决定脚本能否读响应；
4. Java 从 session 重建当前 membership/tenant/role/data scope；
5. 写请求验证 CSRF token、业务权限、version/幂等；
6. 响应按敏感性选择 HTTP cache 策略；
7. 前端收到结果后才更新 DOM/触发渲染。

当前项目合同**没有**确定生产 SameSite 具体值、Domain/Path/寿命、部署 Origin、CORS allowlist 或 HTTP cache headers。教材不能擅自决定。上线前至少要矩阵测试：合法/恶意 Origin、credentials 模式、同站/跨站、Cookie blocked reasons、CSRF、成员禁用/登出、个性化响应缓存泄漏、Vary 与 304。

服务端 Redis cache-aside 是另一层：它缓存领域查询结果，需要 tenant-aware key、失效/版本策略。浏览器 HTTP cache 处理 HTTP representation。PROJECT_SPEC 的 ETag/version 防覆盖也不等于 GET 304。出现陈旧工单时按层保存证据，不能一键清空所有缓存再宣布根因已修。

## 12. 安全边界与常见危险修复

- `Access-Control-Allow-Origin: *` 不是“开发环境万能开关”，带 credentials 不可这样共享，公开 API 也要评估数据与滥用；
- 动态反射任意 Origin + ACAC 是把任意攻击站加入可信读取面；
- CORS 不认证用户，服务端仍负责任何客户端的授权；
- SameSite 不是完整 CSRF 方案，HttpOnly 也不是；
- Cookie `Domain` 越宽，子域风险越大；Path 不能做权限隔离；
- 不把 session ID、Set-Cookie、Cookie、CSRF token 写进日志、HAR 公共工件或截图；
- `no-store` 不能召回已泄漏数据；`private` 不能阻止本机用户看到；
- 个性化响应若进入 shared cache 可能跨用户泄漏，应有负面测试；
- 为了本地 demo 关闭浏览器 web security、禁用 TLS 或安装不可信根证书，不能作为修复/生产证据；
- 服务器收到写请求但浏览器看不到响应时，客户端不得无条件重试，应依靠幂等键/查询事实。

## 13. 边界：本章明确不做

- 不实现 OIDC 登录、密码、session repository、logout 或 refresh token；
- 不把 CORS 当服务端授权、租户隔离或 CSRF；
- 不系统教授 XSS、CSP、CSRF token 生成与完整威胁建模；
- 不实现 Service Worker、Cache API、离线 PWA 或 storage partitioning；
- 不决定 FactoryCare 生产域名、SameSite、CORS allowlist 与 cache header；
- 不把浏览器 HTTP cache 与 Redis、CDN、Pinia、数据库缓存混成一个清理按钮；
- 不承诺不同浏览器/隐私模式对第三方 Cookie 的当前策略完全相同；
- 不用本章 ETag 例子替代写并发 `If-Match`/version contract。

一个不应由本章方案解决的反例：某租户管理员通过 curl 成功读取另一租户工单。增加 CORS allowlist 或 SameSite 不会修复，因为 curl 不受浏览器 SOP/CORS；这必须由 Java 服务端租户/权限校验和负向数据库/API 测试修复。

## 14. 独立构建任务

不复制成品，构建两个 Origin 的最小实验：

1. 明确 A/B 的 scheme、host、port 和 site，先写同源/same-site 判断；
2. B 实现 public、session、preflight write、ETag asset 与 origin-vary 五类合成响应；
3. 逐行写 request matrix，固定页面、目标、method/headers、credentials、Cookie attributes 与预期；
4. 用浏览器记录 Network、Console、Cookie blocked reason、响应头与 cache transfer；
5. 用 curl 复核服务器，但注明 curl 不执行浏览器策略；
6. 分别注入错误 allow Origin、错误 SameSite/credentials、错误 max-age/Vary；
7. 每次指出第一偏差，修复后重跑同一矩阵；
8. 将 HAR/截图脱敏，保存浏览器版本、OS、测试证书、缓存/reload 操作；
9. 列出未验证的第三方 Cookie 策略、移动浏览器、代理/CDN 与生产身份系统。

关闭 AI 后随机抽五行，先口算“请求是否发出、Cookie 是否候选、是否预检、服务器是否处理、脚本是否可读、cache 是否复用”，再与浏览器证据对照。只会修改 CORS 配置而不能解释六个问题，不算完成。

## 15. 两分钟复述模板

> Origin 对普通 HTTP(S) 是 scheme、host、port；任一不同就跨源。Site 更宽且不以端口为边界，所以两个 localhost 端口跨源却可同站。SOP 主要限制跨源读取，不保证请求没到服务器。CORS 由服务器响应头声明、浏览器执行，只决定脚本能否共享响应，不做认证授权。Cookie 依次受 host/domain、path、Secure、expiry、SameSite 和 fetch credentials 影响；HttpOnly 只阻止脚本读取，SameSite/HttpOnly 都不替代 CSRF。带 Cookie 的跨源 fetch 要 include、精确 ACAO、ACAC true 和 Vary Origin。HTTP cache 按 freshness 复用，stale 可用 ETag/If-None-Match 验证，304 复用旧 body；no-cache 是每次验证，no-store 才是不存。诊断时按 Origin、请求、Cookie、CORS、服务端授权、cache 顺序找第一证据。

## 16. 自检与间隔复习

1. `https://a.example.test` 与 `https://a.example.test:8443` 为什么跨 Origin？
2. 两个 localhost port 能验证 CORS，为什么不能独自验证 cross-site SameSite？
3. CORS 报错时，服务器是否可能已经完成 POST？如何证明？
4. `credentials: include`、SameSite 与 ACAO/ACAC 各控制哪一步？
5. Cookie 有 HttpOnly 时，`document.cookie` 看不到是否说明请求不发送？
6. Domain 与 Path 为什么不应作为业务权限边界？
7. `no-cache`、`no-store`、`private` 有什么不同？
8. 304 为什么没有新 body，页面仍能得到内容？
9. 动态 ACAO 为什么要 `Vary: Origin`？
10. 浏览器 ETag validation 与 FactoryCare 写并发 ETag 有什么不同？

复习：当天手算 URL 矩阵；第 2 天画 Cookie/CORS 决策树；第 7 天完成三种故障；第 21 天在另一浏览器复跑并记录差异。每次先预测，不把工具显示的 blocked reason 当背诵答案。

## 17. 官方主来源与版本边界

以下资料于 **2026-07-17** 核验：

- [WHATWG HTML：Origins and sites](https://html.spec.whatwg.org/multipage/browsers.html#origins)：Origin/site 定义、tuple 与 opaque origin；
- [WHATWG Fetch Standard](https://fetch.spec.whatwg.org/)：CORS protocol、preflight、credentials mode、ACAO/ACAC 与 `Vary: Origin` 交互；
- [RFC 6265：HTTP State Management Mechanism](https://www.rfc-editor.org/rfc/rfc6265.html)：当前已发布 Cookie 基线；
- [draft-ietf-httpbis-rfc6265bis-22](https://datatracker.ietf.org/doc/draft-ietf-httpbis-rfc6265bis/22/)：SameSite 与现代 Cookie 行为的当前 IETF 主来源。核验日已获 IESG 批准并处于 RFC Editor 流程，但**仍是 Internet-Draft，不冒充正式 RFC**；浏览器兼容策略必须实测；
- [RFC 9110：HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html)：Origin、ETag、条件请求与 304 语义；
- [RFC 9111：HTTP Caching](https://www.rfc-editor.org/rfc/rfc9111.html)：cache key、freshness、validation、Vary、Cache-Control 与敏感信息缓存边界；
- [Chrome DevTools Network panel](https://developer.chrome.com/docs/devtools/network/overview)：请求/响应、Cookie、Timing、cache 与 blocked requests 的当前 Chrome 观察入口。

稳定原则是：**先算 Origin 与 Site，再分别判断请求发送、Cookie 附带、CORS 共享、服务端授权与 cache 复用；任何一层的绿灯都不能替代下一层。**
