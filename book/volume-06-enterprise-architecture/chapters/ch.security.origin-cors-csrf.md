---
schema_version: 2
edition: 2026.2-draft
id: ch.security.origin-cors-csrf
title: Origin、SameSite、CORS 与 CSRF
responsibility: 教授浏览器来源边界和跨站请求风险，不把 CORS 当作服务端授权或数据隔离
volume: '06'
order: 4
level: L2
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.security.origin-cors-csrf.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.security.cookie-session-model
- ch.security.threat-model-trust-boundaries
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
  text: 在 120 秒内解释Origin、SameSite、CORS 与 CSRF的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - security-origin-cors
  - security-csrf
  covers_topics:
  - security.origin-site
  - security.same-origin-policy
  - security.cors-preflight
  - security.samesite-cookie
  - security.csrf-attack
  - security.csrf-token-origin-check
  uses_capabilities:
  - foundation.http-message
  - foundation.verification-debug-test
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为凭据型工单 API 配置精确 CORS 来源与 CSRF Token，验证同源、允许跨源、恶意跨源和预检矩阵
  covers_topic_groups:
  - security-origin-cors
  - security-csrf
  covers_topics:
  - security.origin-site
  - security.same-origin-policy
  - security.cors-preflight
  - security.samesite-cookie
  - security.csrf-attack
  - security.csrf-token-origin-check
  uses_capabilities:
  - foundation.http-message
  - foundation.verification-debug-test
  evidence_kind: system-artifact-and-negative-tests
  verification_mode: system-security-resilience-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入 Access-Control-Allow-Origin=* 搭配凭据、关闭 CSRF 和只检查 Referer，使用跨站表单/预检修复
  covers_topic_groups:
  - security-origin-cors
  - security-csrf
  covers_topics:
  - security.origin-site
  - security.same-origin-policy
  - security.cors-preflight
  - security.samesite-cookie
  - security.csrf-attack
  - security.csrf-token-origin-check
  uses_capabilities:
  - foundation.http-message
  - foundation.verification-debug-test
  evidence_kind: fault-injection-fix-rerun
  verification_mode: fault-injection-rerun
---
# Origin、SameSite、CORS 与 CSRF

> 本章状态为 `drafting`。配套资产只计算合成 HTTP 请求/响应和内存副作用，不监听端口、不发网络请求、不打开浏览器、不接触真实 Cookie/Token。模型通过只说明明示的浏览器边界不变量成立，不代表真实部署已防御所有跨站攻击。

浏览器安全里最容易混淆的三句话是：“跨域被浏览器拦了，所以接口安全”“开 CORS 就能调通，也就授权了”“Cookie 有 SameSite，所以不用 CSRF Token”。三句都把不同层混在一起。

同源策略限制页面脚本如何读取/操作另一个 origin；CORS 是服务器让浏览器放宽特定跨源读取的协议；CSRF 是攻击者利用浏览器自动携带认证 Cookie，让用户在可信站点执行非本人意愿的动作。CORS 不替代认证、授权或租户隔离，CSRF 也不会因为攻击者读不到响应就消失。

## 1. 完成定义与证据入口

完成本章应能：

1. 从 URL 计算 origin，并解释 origin 与 site/SameSite 的不同；
2. 区分同源策略对 cross-origin read、write、embed 的不同限制；
3. 写出 simple CORS、preflight 和 credentialed CORS 的请求/响应头矩阵；
4. 说明 `Access-Control-Allow-Origin` 是浏览器响应暴露许可，不是服务器身份/权限；
5. 对浏览器 Session 的所有状态变更要求 CSRF Token，并保持 GET/HEAD 等安全方法无业务副作用；
6. 比较 synchronizer token、带签名双重提交、SameSite、Origin/Referer 和 Fetch Metadata 的职责；
7. 注入 `* + credentials`、关闭 CSRF、仅检查 Referer、GET 修改状态，得到稳定失败并重跑；
8. 为 FactoryCare 验证同源、允许跨源、未知 origin、无凭据预检、跨站表单、缺/错 Token 与 bearer 客户端矩阵。

配套入口：

- [CORS 与 CSRF 请求矩阵示例](../../../examples/encyclopedia/ch.security.origin-cors-csrf/README.md)
- [跨站故障注入实验](../../../labs/encyclopedia/ch.security.origin-cors-csrf/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.security.origin-cors-csrf/README.md)

本章不要求手写浏览器。资产模拟规范相关输入，用断言验证服务端策略；真实行为仍需目标浏览器、反向代理和 Spring filter-chain 集成测试。

## 2. URL、Origin 与 Site

一个普通网络 URL 可分为 scheme、host、port、path、query、fragment。对 Web origin，核心是 `(scheme, host, port)` 元组；path 不参与：

| URL A | URL B | same-origin? | 原因 |
| --- | --- | --- | --- |
| `https://app.example.test/a` | `https://app.example.test/b` | 是 | path 不同不影响 |
| `https://app.example.test` | `http://app.example.test` | 否 | scheme 不同 |
| `https://app.example.test` | `https://app.example.test:8443` | 否 | 有效 port 不同 |
| `https://app.example.test` | `https://api.example.test` | 否 | host 不同 |

`Origin` 序列化不含 path。某些 `data:`、sandbox iframe、文件或隐私上下文使用 opaque origin，HTTP 头里可能表示为 `Origin: null`；`null` 不是可信“无来源”，通常应拒绝，只有经过威胁建模的封闭场景才精确允许。

**Site** 用于 Cookie SameSite 等判断，通常基于 scheme 与 registrable domain（public suffix 之上的可注册域）。`https://app.example.test` 与 `https://api.example.test` 可以是 same-site 但仍 cross-origin。结果是：Session Cookie 可能因 SameSite 被发送，而前端脚本读取响应仍需要 CORS。一个失陷兄弟子域也可能处于 same-site，说明 SameSite 不是严格租户或 origin 隔离。

不要用字符串后缀自己计算公共后缀或 site；浏览器使用标准算法和 Public Suffix List。服务端 CORS allowlist 应保存完整 canonical origin，而不是保存“根域”后让所有子域自动通过。

## 3. 同源策略限制什么

同源策略 SOP 是浏览器保护文档与脚本的基础机制。它并不是“所有跨源请求都禁止”：

- cross-origin **writes** 往往可以发生，如链接、重定向、HTML form 提交；
- cross-origin **embeds** 常被允许，如图片、脚本、iframe，具体资源受其他策略约束；
- cross-origin **reads** 通常被限制，尤其 fetch/XHR 读取响应；
- Window/Location 等少量 cross-origin 操作有受限能力；
- Web Storage/IndexedDB 通常按 origin 隔离，Cookie 使用 Domain/Path/Site 自己的规则。

CSRF 正是利用“写可以发生、Cookie 自动附带、读被阻止也无妨”。恶意页提交“关闭工单”表单，只要服务器执行动作，攻击已经成功，不需要读取响应。看到浏览器控制台 CORS error 不证明服务器没有产生副作用。

同源策略是用户代理策略。`curl`、移动 App、服务器脚本和攻击者自写客户端不受浏览器 SOP/CORS 限制，所以服务端必须始终认证、授权、校验租户与业务状态。

## 4. `Origin` 请求头

浏览器在 CORS 请求和许多状态写请求中生成 `Origin: <scheme>://<host>:<port>`。它是 forbidden request header，网页脚本通常不能任意伪造；服务端可用它判断浏览器请求源。但非浏览器客户端可以任意发头，所以 Origin 检查是 CSRF/CORS 边界，不是身份认证。

服务端还必须知道 **target origin**。直接使用 Host 在简单部署中可行，反向代理可能改写；可信代理可传受控 forwarded host/proto，但应用不能信任任意客户端的 `X-Forwarded-*`。更稳妥的是部署配置中声明 canonical external origin，或只接受已由可信代理清洗的头。

比较要解析并 canonicalize scheme/host/有效 port 后做完整相等，不用 `contains("example.com")`、`endsWith` 或无边界正则；`https://example.com.attacker.test` 和用户信息/端口变体都可能绕过幼稚比较。

## 5. CORS 是浏览器读取协议

CORS（Cross-Origin Resource Sharing）由 WHATWG Fetch 定义。浏览器脚本发 cross-origin fetch 时带 `Origin`；服务器在响应中返回 `Access-Control-*`，浏览器据此决定是否把响应暴露给调用脚本。

关键结论：

- 没有 CORS 许可，服务器仍可能收到并执行请求，只是脚本读不到响应；
- 有 CORS 许可，只代表这个 origin 的浏览器脚本可读取，服务端仍要认证和资源授权；
- CORS 不保护非浏览器客户端；
- CORS 错误由浏览器呈现，JavaScript 通常只能看到网络级失败，详细原因在开发工具；
- same-origin fetch 不需要 CORS 响应头。

把 `Access-Control-Allow-Origin: *` 当“修复跨域”的快捷键，会扩大所有网页脚本读取公开响应的范围；若接口含隐私或认证状态，必须从实际 UI origin 精确允许。

## 6. Simple CORS 请求与响应

符合 safelisted method/header/content-type 限制的请求可直接发送，不先 preflight。典型跨源表单 `POST application/x-www-form-urlencoded` 就可能是 simple request。这是 CSRF 不能依赖 preflight 的关键原因。

对允许的无凭据 origin，服务器可返回：

```http
Access-Control-Allow-Origin: https://app.factorycare.example.test
Vary: Origin
```

若资源确实公开且不带凭据，可使用 `Access-Control-Allow-Origin: *`。动态按 allowlist 回显具体 origin 时必须只回显验证成功值，并设置 `Vary: Origin`，防止缓存把 A origin 的许可响应给 B。

`Access-Control-Expose-Headers` 决定脚本还能读哪些非 safelisted 响应头；不要暴露 `Set-Cookie`、内部 trace/调试或秘密。Fetch 会把 `Set-Cookie` 作为 forbidden response header 过滤，前端脚本不能直接读取它。

## 7. Preflight 请求

非 simple 的 cross-origin 请求，例如 `PATCH`、`DELETE`、`application/json` 配合自定义 `X-CSRF-Token`，浏览器通常先发送无业务副作用的 OPTIONS：

```http
OPTIONS /api/v1/work-orders/WO-1/close HTTP/1.1
Origin: https://app.factorycare.example.test
Access-Control-Request-Method: POST
Access-Control-Request-Headers: content-type, x-csrf-token
```

允许时响应可为：

```http
HTTP/1.1 204 No Content
Access-Control-Allow-Origin: https://app.factorycare.example.test
Access-Control-Allow-Methods: POST
Access-Control-Allow-Headers: Content-Type, X-CSRF-Token
Access-Control-Allow-Credentials: true
Access-Control-Max-Age: 600
Vary: Origin
```

Preflight 按 URL、origin、method、header 集合判断，不是“这个域永久获准所有接口”。`Access-Control-Max-Age` 控制专用 preflight cache，过长会延长错误配置；浏览器还可能设内部上限。

Fetch 规范要求 preflight 不带凭据。若安全链先要求 Session Cookie，合法预检会被 401。Spring 官方因此要求 CORS 在 Spring Security 前处理；预检允许只表示浏览器可发送实际请求，实际请求再认证、CSRF 与授权。

## 8. Credentialed CORS

跨源 `fetch` 默认不发送凭据；前端需显式 `credentials: "include"`，服务器同时返回 `Access-Control-Allow-Credentials: true` 和**具体** `Access-Control-Allow-Origin`。正常 Cookie 的 SameSite/第三方 Cookie/隐私政策仍会独立决定是否发送。

带凭据时不能用 `Access-Control-Allow-Origin: *`。Fetch 对 Allow-Methods/Headers/Expose-Headers 的 wildcard 也有凭据限制，配置应列具体值。即使响应头配置正确，用户代理第三方 Cookie 策略仍可能阻止 Cookie；CORS 许可不是 Cookie 发送保证。

允许 credentialed CORS 意味着被允许 origin 上的任意脚本——包括 XSS 或供应链脚本——可能代表用户读取 API。因此 allowlist 是安全配置，变更要评审、测试、审计；不要允许任意客户自报 origin。

## 9. 精确 allowlist 与响应策略

可把策略建模为：

```text
allowedOrigins = {
  https://app.factorycare.example.test,
  https://portal.factorycare.example.test
}
allowedMethods = {GET, POST, PUT, PATCH, DELETE}
allowedHeaders = {Content-Type, X-CSRF-Token, Idempotency-Key}
allowCredentials = true
```

对未知 origin，响应中不出现 CORS 授权头；预检可稳定拒绝。不要回显任意 `Origin`，不要允许 `null`，不要匹配 `*.example.test` 除非所有子域完全受控且框架模式语义经过测试。开发 localhost origin 与生产 allowlist 分开配置，生产启动保护防止 `*` 泄漏。

CORS 是每路由的最小许可。公开匿名二维码解析与认证管理 API 的读取范围可能不同；全局超集会让低风险需求扩大高风险接口暴露。仍然不能用 origin 作为 tenant 或 role。

## 10. CSRF 的攻击条件

典型 CSRF 需要：

1. 受害者在目标站有有效的 ambient credential，通常是自动发送的 Session Cookie；
2. 目标有可预测的状态变更请求；
3. 攻击者能诱导浏览器发请求；
4. 服务端只凭 Cookie 就执行，没有不可由攻击站获得/自动发送的证明。

攻击页可以放隐藏 form：

```html
<form method="post" action="https://api.factorycare.example.test/api/v1/work-orders/WO-1/close">
  <input name="reason" value="synthetic">
</form>
```

浏览器可能携带 Cookie；即使 SOP/CORS 阻止攻击页读响应，工单仍可能关闭。攻击者甚至不必知道成功，只要副作用发生。

Bearer Token 若只由应用代码从受保护存储取出并显式放 Authorization，第三方站点通常不能让浏览器自动附加，因此传统 Cookie CSRF 条件不同。但 Token 存储、XSS、CORS 和移动回调有其他威胁；不能统一关闭一个同时服务 Cookie 浏览器的后端 CSRF。

## 11. 安全 HTTP 方法必须没有业务副作用

RFC 9110 把 GET、HEAD、OPTIONS、TRACE 定义为 safe：客户端没有请求、也不期望业务状态改变。访问日志或指标是附带效果，不等于用户请求“关闭工单”。应用必须让 GET 只读，不能使用：

```text
GET /work-orders/WO-1/close
GET /logout
GET /members/M-1/disable
```

SameSite=Lax 可在部分跨站顶层安全导航发送 Cookie；爬虫、预取、链接预览也会访问 GET。若 GET 有副作用，SameSite 与 CSRF Token 的“仅保护 unsafe method”假设都会崩溃。

测试除响应外还比较数据库/内存前后快照：GET 200 不代表无副作用；应断言状态写计数为零。

## 12. Synchronizer Token Pattern

服务端 Session 应用的主流方案是同步 Token：服务端为 Session 保存不可预测随机 Token；把 Token 通过可信同源页面、受控响应头或专用端点交给合法前端；状态写请求除了 Session Cookie，还在隐藏字段或自定义头提交 Token；服务器常量时间比较并拒绝缺失/错误值。

安全性质：

- Token 绑定当前 Session/主体，不是全站固定常量；
- 足够随机且不进入 URL、Referer、日志或分析；
- 攻击站不能读取合法页面取得 Token；
- Token 放在不会被浏览器自动跨站附加的位置；
- 认证成功、登出和高风险轮换时清除/刷新；
- 缺失、过期、错 Session 或比较失败统一 403 且无副作用。

把 Token 也只放 Cookie，然后服务器仅检查“Cookie 存在”，没有增加独立证明，因为浏览器会自动发送。合法 SPA 常把 Token 从专用 `/csrf-token` 响应取得，放 `X-CSRF-Token`；该响应不能对恶意 origin 暴露。

## 13. Token 传输与 SPA

多页表单可把 Token 放 hidden input；SPA 用自定义 header 更清晰。header 会使许多跨源请求 preflight，这提供额外门槛，但核心仍是服务器比较 Session 期望值。攻击者若利用同源 XSS，能读取/发 Token，CSRF 防线不解决 XSS。

不要把 Token 放 GET query，因为会进历史、日志和 Referer。响应正文/头需 `Cache-Control: no-store`，前端只在内存或受控生命周期保存。多个标签页、Session 到期、认证/登出后 Token 清除会产生 403；客户端应获取新 Token，而不是关闭校验。

当前 Spring Security 默认可把期望 Token 存 HttpSession，并对 Token 做 deferred loading/BREACH 相关处理；SPA 集成在认证和登出后需刷新。默认会演进，必须按 BOM 管理版本和官方示例验证。

## 14. 双重提交 Cookie：朴素版与带签名版

无服务端 Session 的系统有时使用 double-submit：浏览器保存一个 CSRF Cookie，前端把同值复制到 header，服务器比较。**朴素相等比较**会在攻击者能为父域/兄弟子域注入 Cookie 时被绕过；它也未必绑定当前认证 Session。

OWASP 当前建议新代码使用 **signed double-submit**：Token 包含随机值和对 Session/用户唯一绑定值的 HMAC；服务器用数据库外密钥验证签名、绑定与 header/cookie 对应，常量时间比较。不要把长期稳定用户 ID 单独当 Token，也不要使用无签名 hash。

即便带签名，也需 host-only/`__Host-` Cookie、密钥轮换、过期、XSS 防护和 origin 检查。FactoryCare 已采用服务端 Web Session，默认更自然的是 synchronizer token；本章讲双重提交是为了辨认边界，不建议无理由替换项目设计。

## 15. SameSite 是纵深，不是唯一 CSRF 控制

`SameSite=Strict` 最强限制跨站 Cookie，但可能影响 OIDC/外部跳转 UX；`Lax` 允许部分顶层安全导航，因此 GET 必须无副作用；`None` 允许跨站且必须 Secure，需要更强 Token/origin 控制。浏览器兼容、嵌入 WebView、same-site sibling 和新设置 Cookie 的兼容窗口都可能产生剩余风险。

OWASP 只在很窄条件下认为 SameSite 可单独提供合理防护：所有同站子域受控、无安全方法副作用、严格属性、origin/referer 纵深，并接受旧浏览器风险。FactoryCare 不应依赖这些理想条件，ADR 已明确状态写启用 CSRF。

## 16. Origin 与 Referer 校验

对浏览器状态写请求，若有 `Origin`，把 source origin 与配置的 target origin 完整比较；不匹配拒绝。若 Origin 合法缺失，可按明确策略解析 `Referer` 的 origin 作为 fallback，而不是对原字符串做前缀比较。两者都缺失时，OWASP 建议默认阻止，或先监控兼容性再进入阻止模式。

“只检查 Referer”容易受隐私策略造成缺失，也常被幼稚字符串匹配绕过；诊断题会让恶意 Origin 与看似可信 Referer 冲突，正确策略优先拒绝 Origin mismatch。非浏览器可伪造两者，所以仍需认证授权。

代理后的 target origin 要用安全配置或可信代理头。若客户端可直接控制 `X-Forwarded-Host`，Origin 比较会失去意义。

## 17. Fetch Metadata 与用户交互

现代浏览器可发送 `Sec-Fetch-Site`、`Sec-Fetch-Mode`、`Sec-Fetch-Dest` 等 Fetch Metadata。服务器可把 `cross-site` 的危险导航/请求先拒绝，作为纵深与观测；需评估不支持浏览器、webhook、移动客户端和同站跨源场景，采用 allow/deny 与 rollout 策略。

高风险操作还可要求用户交互、重新输入当前因素、MFA step-up 或二次确认。它们降低后台无感请求，但不能替代基础 Token；简单“确认按钮”若攻击页能触发或 clickjacking，仍不够。

## 18. 登录、登出与客户端 CSRF

登录也可能遭 CSRF：攻击者让受害者登录到攻击者账号，受害者随后把私密信息写进错误账号。登录入口在建立 Session 前也应使用 login CSRF 防护、Origin/SameSite/state 等适合流程的控制。OIDC `state`/`nonce` 有专门协议职责，后续 OIDC 章节处理。

登出是状态变化。FactoryCare 契约使用 POST logout，并要求 browserSession + csrfHeader；跨站 GET logout 会造成会话干扰，甚至配合其他攻击。登出成功后服务端撤 Session、清 Cookie 和 CSRF Token。

客户端代码也可能形成 client-side CSRF：从不可信 URL/hash 读取 endpoint 或 method，再由合法脚本带 Token/Cookie 发请求。统一自动加 Token 不会修复“目标由攻击者控制”；前端仍需固定 API 路由、校验参数和避免任意 URL。

## 19. CORS、CSRF、认证、授权的执行顺序

可把浏览器请求处理拆成：

1. 可信代理规范化外部 scheme/host；
2. CORS 处理 preflight 和响应暴露；
3. 解析认证 Cookie/Session 或 mobile bearer；
4. 对 browser Session 的 unsafe method 验证 CSRF Token 与来源；
5. 重建当前账号、membership、role、data scope；
6. 校验输入、领域状态与幂等；
7. 执行业务并审计；
8. 加精确 CORS/缓存/安全响应头。

顺序不是让 preflight 获得业务权限；预检不执行业务。实际请求必须通过后续所有门。CORS allowlist 中的 origin 也可能被攻陷，所以不能跳过授权。

## 20. FactoryCare 的合同投影

FactoryCare Web 用 `FACTORYCARE_SESSION`，状态写还要求 `X-CSRF-Token`；mobileBearer 不发送浏览器 CSRF credential。公共契约有 `/api/v1/auth/csrf-token`，用于已认证浏览器 Session 取得/刷新 Token。全局 security 表达：

```text
(browserSession AND csrfHeader) OR mobileBearer
```

安全 GET 只要求 browserSession 或 mobileBearer，不要求 CSRF header，但必须无副作用。Logout 是 POST，缺/错 Token 返回 403；登录成功、登出成功和 Session 轮换后 Token 生命周期要与 Session 对齐。

若 Web UI 和 API same-origin，通常无需 CORS；若部署为精确 cross-origin，允许的 UI origin、methods、headers、credentials 和 `Vary: Origin` 必须显式。当前设计没有授权任意公网 origin，本章不写入契约或站点配置。

## 21. 合成请求矩阵

| 场景 | 浏览器输入 | CORS | CSRF/业务预期 |
| --- | --- | --- | --- |
| same-origin GET | Session Cookie | 无需 CORS 头 | 200，写计数 0 |
| 允许 cross-origin preflight | OPTIONS，无 Cookie，声明 POST + headers | 204 + 精确 ACAO/ACAC/method/header | 不认证、不执行业务 |
| 允许 cross-origin POST | exact Origin + Cookie + 正确 Token | 精确 ACAO + credentials | 业务授权后成功 |
| 未知 origin fetch | evil Origin | 无 ACAO | 即使浏览器阻读，服务端仍不得产生副作用 |
| 跨站 simple form | Cookie 可能自动带，无 Token | 可能没有 preflight | 403，写计数 0 |
| 缺/错 Token | allowed Origin + Cookie | CORS 可允许读 403 | 403，写计数 0 |
| mobile bearer | Authorization 显式带 | 按客户端部署决定 | 不因 Cookie CSRF 规则误拒，但照常授权 |
| `* + credentials` | Cookie/include | 浏览器不允许暴露 | 配置验证直接失败 |

断言同时检查 HTTP 状态、响应头与副作用计数。只看“浏览器报 CORS error”会漏掉服务器已经写入；只看 403 会漏掉错误的 ACAO 泄露。

## 22. 故障注入与定位

**`* + credentials`**：第一处证据是配置不变量冲突，不必真的发请求。修复为精确 allowlist、具体 origin、`Vary: Origin`。

**关闭 CSRF**：跨站 simple form 不触发 preflight，Cookie 自动带，写计数从 0 变 1。修复 synchronizer token，并重跑同一个 form。

**只检查 Referer**：请求带恶意 Origin、可信样式 Referer 时被接受。修复为 Origin 优先完整比较，Referer 仅在 Origin 缺失的受控 fallback。

**GET 修改状态**：链接/预取触发写。修复 API 方法与领域命令边界，GET 返回表示且写计数 0。

**预检要求 Session**：OPTIONS 没 Cookie 被 401，合法 UI 无法发送实际请求。修复 filter 顺序，让 CORS policy 先处理，不让预检进入业务。

定位顺序：请求 method/origin/credentials mode → 是否 simple/preflight → CORS policy 输出 → Session 是否 ambient → CSRF expected/actual → 当前授权 → 副作用。不要从前端一句 “Failed to fetch” 反推所有层。

## 23. Spring Security 集成边界

截至 2026-07-17，当前 Spring Security 文档说明：Servlet CSRF 默认可把期望 Token 存在 HttpSession；`CookieCsrfTokenRepository` 可支持 JS，但让 Token Cookie 脚本可读需理解 HttpOnly 取舍；默认 deferred token 与 BREACH 处理会影响 SPA 获取/刷新流程；认证和登出会清旧 Token。

Spring CORS 文档明确 CORS 应在 Security 前处理，因为 preflight 不带 `JSESSIONID`。提供 `CorsConfigurationSource`/Spring MVC 配置可集成，但“配置存在”不是证据。需要 MockMvc/真实 HTTP/浏览器系统测试验证 exact origin、无凭据 OPTIONS、状态写 Token 和错误响应头。

不要全局 `.csrf().disable()` 解决 403。仅当端点不依赖浏览器自动凭据且威胁模型明确时才评估忽略范围；同一个应用含 Web Session 时，按 matcher 划分并测试。Spring 默认与 SPA 示例会变化，版本由 Boot 4.1 BOM 管理，实施时重新复核。

## 24. 120 秒讲解模板

> Origin 是 scheme/host/port；site 用于 SameSite，兄弟子域可 same-site 但 cross-origin。同源策略主要阻止恶意页读取跨源响应，却允许很多跨源写和嵌入。CORS 是服务器用响应头授权浏览器脚本读取，preflight 是无 Cookie 的 OPTIONS；它不是认证或授权。CSRF 利用浏览器自动带 Session Cookie 触发状态变化，所以 unsafe 请求要有绑定 Session、攻击站拿不到且不会自动发送的 Token，再配 exact Origin、SameSite 和 Fetch Metadata。Credentialed CORS 必须具体 origin，不能 `*`；GET 必须无业务副作用。失败反例是跨站 form POST 无预检，服务器关闭 CSRF 后完成关单，浏览器虽报 CORS error，业务已经被改写。

若讲解只会说“跨域要配 CORS”，却说不出 origin/site、simple request、无凭据 preflight、`* + credentials`、Token 和副作用断言，尚未达到目标。

## 25. 自检清单

- 是否能从 URL 精确计算 scheme/host/effective port origin？
- 是否区分 same-origin、same-site、cross-origin、cross-site 与 opaque/null origin？
- 是否承认 SOP 常允许 cross-origin write/embed，而不是所有请求都拦？
- CORS allowlist 是否完整 origin 精确匹配，拒绝任意回显、`null` 和宽泛子域？
- 动态 ACAO 是否配 `Vary: Origin`？
- credentialed CORS 是否具体 origin + ACAC，完全没有 wildcard？
- preflight 是否无 Cookie 成功经过 CORS，又不执行认证业务？
- 未知 origin 是否无授权响应头且无副作用？
- GET/HEAD 是否无业务写，测试是否比较前后状态？
- browser Session 的 POST/PUT/PATCH/DELETE 是否要求 Session 绑定 Token？
- Token 是否不在 URL/日志、认证/登出后刷新、错值统一 403？
- 是否优先检查 Origin，Referer 只做受控 fallback，target origin 来自可信配置？
- 是否把 SameSite、Fetch Metadata、重新认证当纵深，而不是替代 Token？
- 是否知道朴素 double-submit 可被 Cookie 注入绕过，带签名方案需 Session 绑定？
- CORS、CSRF 通过后是否仍执行当前 membership、role、tenant/data scope 授权？

## 26. 资料层级、时效与适用范围

- [WHATWG Fetch Living Standard](https://fetch.spec.whatwg.org/)：CORS、credentials mode、preflight 与响应头处理的现行浏览器算法规范；Living Standard 会持续更新。
- [WHATWG HTML Standard — Origin](https://html.spec.whatwg.org/multipage/browsers.html#origin)：origin、same origin/site 等浏览器模型。URL/opaque origin 细节应以当前标准算法为准。
- [RFC 9110 HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html#name-safe-methods)：已发布的 safe method 语义；它规定请求语义，不直接实现 CSRF。
- [RFC 6265](https://www.rfc-editor.org/rfc/rfc6265.html) 与 [6265bis 状态](https://datatracker.ietf.org/doc/draft-ietf-httpbis-rfc6265bis/)：Cookie 基线与 SameSite 的演进。截至复核日 bis-22 在 RFC Editor 队列，尚未成为已发布 RFC。
- [MDN Same-origin policy](https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Same-origin_policy)、[CORS guide](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS)、[Set-Cookie](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie)：权威浏览器实践、例子与兼容性说明，不替代 WHATWG/IETF normative algorithm。
- [OWASP CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)：synchronizer token、signed double-submit、Origin/Referer、SameSite 和 Fetch Metadata 的工程建议。
- [Spring Security CSRF](https://docs.spring.io/spring-security/reference/servlet/exploits/csrf.html) 与 [CORS](https://docs.spring.io/spring-security/reference/servlet/integrations/cors.html)：当前 Servlet 实现与 filter 顺序；只对采用的框架版本适用。
- [FactoryCare ADR-0003](../../../factorycare-design/adrs/0003-oidc-and-client-sessions.md)：本项目 Web Session + CSRF 与移动 bearer 的权威边界。

规范、Living Standard、浏览器兼容文档和框架默认不是同一层级。实现时记录目标浏览器、Spring BOM、代理拓扑与复核日期；本章概念稳定，不把配置片段登记为版本面。

## 27. 有意不覆盖

本章不修改 CORS/CSRF 生产配置，不实现 Spring filter chain、OIDC `state/nonce`、OAuth、Cookie Session repository、CSP/frame-ancestors、XSS、CORP/COEP/CORB 或浏览器自动化；不开放任何真实 origin；不把 CORS 当租户数据隔离。后续实现必须在现有公共契约和 ADR 下另行验证。
