---
schema_version: 2
edition: 2026.2-draft
id: ch.security.cookie-session-model
title: Cookie、Session、认证状态与固定攻击模型
responsibility: 教授浏览器携带认证状态及 Session 固定风险，不在本章实现 Spring Security 登录流程
volume: '06'
order: 3
level: L2
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.security.cookie-session-model.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.security.identity-password-lifecycle
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
  text: 在 120 秒内解释Cookie、Session、认证状态与固定攻击模型的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - security-cookie
  - security-session
  covers_topics:
  - security.cookie-attributes
  - security.cookie-transport
  - security.cookie-lifetime
  - security.server-session
  - security.session-id-rotation
  - security.session-fixation
  uses_capabilities:
  - foundation.http-message
  - foundation.verification-debug-test
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 用请求时序图描述登录前后 Cookie/Session ID、服务端状态、轮换、过期和退出，并配置 HttpOnly/Secure/SameSite
  covers_topic_groups:
  - security-cookie
  - security-session
  covers_topics:
  - security.cookie-attributes
  - security.cookie-transport
  - security.cookie-lifetime
  - security.server-session
  - security.session-id-rotation
  - security.session-fixation
  uses_capabilities:
  - foundation.http-message
  - foundation.verification-debug-test
  evidence_kind: runnable-artifact-and-oracles
  verification_mode: failing-and-passing-oracle-cases
- id: diagnose
  kind: fault-diagnosis
  text: 注入登录后沿用旧 Session ID、退出不失效和 Cookie 作用域过宽，重放旧标识证明漏洞后修复
  covers_topic_groups:
  - security-cookie
  - security-session
  covers_topics:
  - security.cookie-attributes
  - security.cookie-transport
  - security.cookie-lifetime
  - security.server-session
  - security.session-id-rotation
  - security.session-fixation
  uses_capabilities:
  - foundation.http-message
  - foundation.verification-debug-test
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Cookie、Session、认证状态与固定攻击模型

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《身份、密码哈希、凭据生命周期与恢复边界》](ch.security.identity-password-lifecycle.md)：独立完成Cookie 边界、Session 状态与攻击前，必须先具备「身份、密码哈希、凭据生命周期与恢复边界」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。正文描述浏览器 Cookie 与服务端 Session 的安全合同，配套代码只用固定时钟、合成 ID 和内存存储，不启动服务器、不访问公网、不读取浏览器资料，也不实现 FactoryCare 的生产登录流程。

HTTP 请求彼此独立。浏览器第一次请求与下一次请求没有天然“同一个用户”的含义；应用若要保存语言偏好、购物车或认证状态，就必须建立可关联的状态。Cookie 是浏览器按规则保存并随请求发送的少量 name/value；Session 是服务器把一个不透明标识映射到状态记录的机制。二者经常配合，却不是同一个东西。

本章关心的核心不变量是：客户端只持有不可解释、不可预测的 Session ID；认证与授权状态保存在服务端；身份或权限提升时 ID 轮换；旧 ID、过期 ID、登出 ID 和撤销账号的 ID 都不能继续访问；Cookie 的传输、脚本可见性、站点与作用域属性与实际 HTTPS/域名/路径一致。

## 1. 完成定义与证据入口

完成本章，应能交付以下可复验结果：

1. 从 `Set-Cookie` 响应到后续 `Cookie` 请求画出浏览器和服务器各自保存什么；
2. 解释 host-only、`Domain`、`Path`、`Secure`、`HttpOnly`、`SameSite`、`Max-Age` 和 `Expires` 的语义与一个误用反例；
3. 区分 Cookie 的客户端过期与 Session 的服务端失效；
4. 设计不透明、高熵、由框架或 CSPRNG 生成且只从 Cookie 接受的 Session ID；
5. 画出匿名会话 → 登录 → ID 轮换 → 已认证请求 → 超时/登出/撤销的状态时序；
6. 重放登录前旧 ID、登出旧 ID、过期 ID 和错误路径/主机请求，得到稳定拒绝；
7. 注入“登录沿用旧 ID”“只删 Cookie 不删服务端状态”“Domain 过宽”“跳过超时”并定位第一处可信偏差。

配套入口：

- [Cookie 作用域与 Session 轮换示例](../../../examples/encyclopedia/ch.security.cookie-session-model/README.md)
- [Session 固定与失效实验](../../../labs/encyclopedia/ch.security.cookie-session-model/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.security.cookie-session-model/README.md)

公开练习保留 TODO 与负向预言；私有解析只在完成预测、修复和重跑后核对。资产通过不证明真实 Servlet 容器、反向代理、浏览器或多节点 Session 存储已经配置正确。

## 2. Cookie 与 Session 的职责边界

服务器可在响应中发送：

```http
Set-Cookie: FACTORYCARE_SESSION=<opaque-id>; Path=/; Secure; HttpOnly; SameSite=Lax
```

用户代理保存后，对符合规则的请求发送：

```http
Cookie: FACTORYCARE_SESSION=<opaque-id>
```

请求中的 `Cookie` 只带 name/value，不会把 `Secure`、`HttpOnly`、`SameSite` 等属性再发给服务器。服务器不能从收到的 Cookie 推断它当初以哪些属性设置；属性配置必须由响应测试、浏览器测试和部署配置共同验证。

Session 存储可能是进程内存、数据库、专用缓存或框架提供者。其逻辑模型是：

```text
opaque session ID
  -> account/user ID
  -> authentication time and assurance
  -> current credential/membership version
  -> creation / last-used / absolute-expiry timestamps
  -> server-side status ACTIVE | EXPIRED | REVOKED
```

Cookie 只是携带 ID 的信封。把完整角色、租户或个人信息编码进可读 ID，会扩大泄露和陈旧权限问题。即使客户端 Token 是签名的，服务端仍可能需要撤销和当前成员检查；那属于 Token/授权章节，本章采用服务端状态模型。

## 3. `Set-Cookie` 的结构与解析边界

每个 Cookie 从 name/value 开始，后接分号分隔属性。多个 Cookie 应使用多个 `Set-Cookie` 字段，不应把它们像普通列表头那样合并，因为 `Expires` 日期等语法可能含逗号。浏览器可因策略、容量或语法拒绝 Cookie，服务端不能假定响应一发就一定存下。

Cookie 值不是任意 JSON 容器。字符范围、编码和实现限制会影响解析；若确需结构化值，应使用明确编码和严格大小边界。认证 Cookie 最好只有框架生成的不透明值，业务数据留在服务端。Cookie 数量和大小有用户代理下限/上限与淘汰策略，不应把它当可靠数据库。

同名 Cookie 可能因不同 Domain/Path 同时存在。服务器收到 `Cookie` 头时不一定得到创建属性，解析顺序也不能当安全决策。安全敏感 Cookie 应避免同名多作用域，使用精确名称、host-only 范围和一致删除属性；服务器要拒绝重复/歧义输入或按框架的已验证策略处理。

## 4. host-only 与 `Domain`

不写 `Domain` 时，Cookie 是 **host-only**：只发给设置它的主机，不自动发给子域。这通常是认证 Session 的更小范围。写 `Domain=example.test` 会让它可发送给该域及子域；较早写法中的前导点 `.example.test` 在现代处理里被忽略，不会变成更严格范围。

服务器只能设置当前域或合适父域，不能设置无关域或公共后缀。即便浏览器拒绝明显非法值，应用也不应动态回显不可信 Host/Domain。共享父域意味着任何可控或失陷子域可能影响 Cookie 风险，包括设置广域同名 Cookie 参与固定攻击。

FactoryCare 的浏览器 Session 默认应评估 host-only，也就是省略 `Domain`。若 Web UI 与 API 使用不同 origin，需要在 BFF、反向代理或明确跨源方案之间作架构选择，不能为了“让 Cookie 到处都能用”直接扩到父域。

## 5. `Path` 是发送选择器，不是访问控制

`Path=/api` 表示请求路径匹配 `/api` 及其目录边界时浏览器可发送 Cookie；`/api/v1` 与 `/api/v1/orders` 可匹配，而不相关路径不匹配。默认 Path 来自设置 Cookie 的请求路径规则，安全配置应显式指定。

`Path` 不阻止同源其他页面通过 DOM 等方式间接访问或覆盖 Cookie，也不把同一主机上的应用变成安全隔离域。不能用 `/admin` Cookie 替代管理员授权。若同一主机部署互不信任应用，应使用独立主机/origin、服务端授权与部署隔离。

删除 Cookie 必须匹配原来的名称、Domain/host-only 和 Path；只发同名但不同 Path 的 `Max-Age=0` 可能留下原 Cookie。测试应在真实作用域矩阵中验证，而非只看响应出现 `Set-Cookie`。

## 6. `Secure`：限制传输方案，不等于全能加密

`Secure` 指示用户代理只在 HTTPS 请求中发送 Cookie（浏览器对 localhost 可能有开发例外）。它降低明文 HTTP 传输泄露，却不替代完整站点 HTTPS、证书验证和 HSTS；也不防本机恶意软件、服务端日志、XSS 行为或 Session ID 预测。

登录页用 HTTPS、登录后又允许 HTTP，会在后续请求泄露会话。安全会话必须全程 HTTPS，重定向到 HTTPS 后再建立/轮换 Cookie。生产测试不能因为 localhost 例外而推断真实域已正确设置 `Secure`。

不要把 Session ID 放入 URL query、path、Referer 或页面内容作为“HTTPS 已加密所以没问题”。URL 会进入历史、书签、访问日志、分析系统和外链 Referer。应用只接受约定 Cookie 通道，拒绝 `?sessionId=` 等替代入口，防止固定与泄露。

## 7. `HttpOnly`：阻止脚本读取，不能阻止脚本使用

`HttpOnly` 让 `document.cookie` 等非 HTTP API 无法读取该 Cookie。它显著降低常见 XSS 直接窃取 Session ID 的能力，也证明该 Cookie 应由 HTTP 响应设置。但浏览器仍会在匹配的 `fetch`、XHR、表单和导航请求中自动携带它。

所以 `HttpOnly` 不防 CSRF，也不能让 XSS 无害。已在同源执行的恶意脚本仍可代表用户调用接口、读取页面响应或触发状态变更。需要继续部署输出编码、内容安全策略、CSRF、授权、敏感操作重新认证和短时会话。

Session Cookie 应默认 `HttpOnly`。需要 JavaScript 读取的偏好或 CSRF 双重提交 Cookie 是另一类数据，应使用不同名称、不同威胁模型，不能把认证 Session 为了前端方便改成脚本可读。

## 8. `SameSite` 的三种值

`SameSite` 决定 Cookie 在跨站上下文中的发送范围，使用的是 **site** 概念，不是严格的 scheme/host/port origin。当前浏览器和 6265bis 工作把 scheme 纳入“schemeful same-site”判断；兄弟子域可能 same-site 但 cross-origin。因此 SameSite 不能替代 origin 级 CORS/授权。

| 值 | 概念效果 | 适用权衡 |
| --- | --- | --- |
| `Strict` | 仅 same-site 请求发送 | 最严格，外站跳入可能先呈未登录，需评估登录/支付回跳 UX |
| `Lax` | same-site 发送；部分跨站顶层安全导航可发送 | 常用会话折中，仍要求 GET 无副作用 |
| `None` | same-site 与 cross-site 均可发送 | 必须同时 `Secure`；跨站嵌入/客户端确有需要才采用 |

属性应显式设置。现代浏览器通常把缺省视作 Lax，但“缺省 Lax”存在更宽松的短时间 POST 兼容行为，属于浏览器实践而不是应用可依赖的安全合同。旧浏览器、嵌入 WebView 和企业策略也可能不同。

SameSite 是 CSRF 防御纵深，不能替代随机 Token 与 origin 检查；下一章会建立完整矩阵。Lax 仍允许某些顶层 GET 导航携带 Cookie，所以任何 GET 若执行“删除、审批、退出、转派”等副作用，攻击者可用链接或嵌入触发。

## 9. Cookie 前缀

支持的用户代理会为特定名称前缀强制属性：

- `__Secure-`：必须从安全上下文设置并带 `Secure`；
- `__Host-`：必须 `Secure`、`Path=/` 且不能有 `Domain`，得到 host-only、host-wide 作用域；
- 当前 MDN 还记录 `__Http-` 与 `__Host-Http-`，额外要求 `HttpOnly`，但采用前必须检查目标浏览器支持。

前缀是防御纵深，不是服务器授权。服务器必须匹配完整名称，不能自动剥离。FactoryCare 公共契约当前名字是 `FACTORYCARE_SESSION`；若改为 `__Host-FACTORYCARE_SESSION` 会改变契约、客户端/代理测试与迁移，不能在本章静默修改。理想属性组合仍可先在模型中验证，再由实现决策决定是否版本化改名。

## 10. Cookie 生命周期与服务端生命周期

没有 `Expires`/`Max-Age` 的 Cookie 通常称 Session Cookie，由用户代理会话管理；浏览器的 session restore 可能在重启后恢复它，因此“关浏览器一定退出”不是安全保证。带 `Max-Age` 或 `Expires` 的持久 Cookie 可跨会话保留；两者同时出现时 `Max-Age` 优先。

浏览器可提前淘汰 Cookie，也可能因时钟、隐私政策或第三方 Cookie 限制表现不同。Cookie 到期只说明客户端不再发送；已泄露 ID 仍可能被手工重放。因此服务器必须独立检查状态、idle timeout、absolute timeout、账号/成员状态与凭据版本。

登出正确顺序是：在服务端原子撤销当前 Session，再返回匹配原作用域的清除 Cookie，例如 `Max-Age=0`。只清浏览器而服务端记录仍 ACTIVE，攻击者手里的副本继续有效；只撤服务端而不清 Cookie 虽然安全拒绝，却造成客户端反复发送无效 ID 和体验问题。两边都做，服务端撤销是权威。

## 11. Session ID 的安全性质

Session ID 应：

- 由成熟框架或 CSPRNG 生成，全部位不可预测；
- 有足够搜索空间，OWASP 当前建议自建时至少 128 bits；
- 唯一、不透明，不含 user、tenant、role、邮箱或时间可读信息；
- 只在 Cookie 交换，不接受 URL、正文或自定义替代通道；
- 作为不可信输入校验长度/语法，并只接受服务器已签发 ID；
- 不进入日志、trace、错误页、分析系统或客服截图；需要关联时记录受保护的派生指纹。

长度不是熵。一个 32 字符 ID 若一半固定，只有剩余随机部分贡献猜测难度。UUID 是否适合取决于版本与生成器，不能只凭格式宣称安全。最稳妥做法是让 Servlet/安全框架管理，并在测试中验证不可预测性边界、轮换和严格接受策略，而不是手写随机算法。

## 12. 服务端 Session 状态

一个最小安全 Session 记录可包含：

- ID 的安全存储键或摘要；
- `account_id` 与当前认证级别；
- `created_at`、`authenticated_at`、`last_seen_at`；
- idle 与 absolute expiry；
- `credential_version`、membership/version 或撤销 epoch；
- 状态 `ANONYMOUS | AUTHENTICATED | REVOKED | EXPIRED`；
- 与高风险重新认证相关的时间；
- 不含原始密码、OIDC code、access token 或完整 Session ID 的审计关联。

角色和数据范围可以在 Session 中作为性能缓存，但不能成为永久真相。FactoryCare ADR 要求每次重建当前 membership、角色与 data scope；成员禁用应立即生效。可用版本/撤销 epoch 检测陈旧状态，必要时读取当前授权源。Session 有效只证明认证连续性，不证明对当前工单有权。

## 13. 从匿名到认证：必须跨越权限边界

应用可为匿名访问建立预认证 Session，例如保存 OAuth state、CSRF Token 或界面偏好。攻击者也许能先取得自己的匿名 ID，再诱导受害者使用它。如果登录成功后仍沿用该 ID，受害者的认证状态被绑定到攻击者已知标识，形成 Session fixation。

安全时序：

```text
浏览器                  Java / Session Store
  | GET /login         |
  |------------------->| 创建 PRE-1（匿名）
  |<-- Set-Cookie PRE-1|
  | POST 登录 + PRE-1  |
  |------------------->| 验证身份；生成 AUTH-9；复制允许状态；撤销 PRE-1
  |<-- Set-Cookie AUTH-9（安全属性）
  | GET /me + PRE-1    |
  |------------------->| 401：旧 ID 不存在/已撤销
  | GET /me + AUTH-9   |
  |------------------->| 重建当前成员；允许或按授权拒绝
```

“改 Session 对象里的 `authenticated=true`”不够；ID 必须改变。轮换应在认证成功这一权限提升点原子发生，旧 ID 立即不可用。复制哪些匿名属性要允许列表化，避免把攻击者预置的购物车、redirect、租户或安全上下文迁入认证 Session。

## 14. 权限变化与重新认证也要轮换

Session fixation 防护不只发生在初次登录。管理员升权、step-up/MFA、账号恢复、密码变更和 impersonation 开始/结束都会改变安全级别，应评估轮换 ID、重建状态和撤销并发会话。否则低权限阶段泄露的 ID 可继续承载高权限状态。

轮换实现要处理并发请求：旧页面可能同时发送旧 ID，新 ID 响应可能乱序。服务端安全默认是旧 ID 不再认证；客户端收到 401 后刷新状态，而不是为“平滑”长期双 ID 有效。极短迁移窗口若业务必须使用，也需明确攻击窗口、一次性映射和自动测试。

## 15. Session fixation 与 Session hijacking

**固定攻击 fixation**：攻击者先知道或控制一个 ID，再让受害者用同一 ID 登录。防线是严格只接受服务端签发 ID、登录/升权轮换、拒绝 URL ID、精确 Cookie 作用域和子域治理。

**劫持 hijacking**：攻击者在受害者登录后窃取有效 ID，通过 XSS、网络、日志、浏览器扩展、恶意软件或数据库泄露重放。防线包括 HTTPS + Secure、HttpOnly、短时/撤销、日志脱敏、XSS 防护、异常检测和敏感操作重新认证。

轮换能阻止固定，不会自动防止已窃取的新 ID；HttpOnly 降低脚本读取，不阻止 CSRF 或同源 XSS 发请求；绑定 IP/User-Agent 可能作为风险信号，却会误伤移动网络、代理和隐私设置，不宜作为唯一硬绑定。

## 16. 超时：idle、absolute 与 renewal

**Idle timeout**：一段时间没有受认可活动即失效。什么算活动要明确；背景轮询不应无限续命高风险会话。**Absolute timeout**：无论是否活跃，超过总时长必须重新认证。**Renewal timeout**：周期轮换 ID，缩短已窃取标识窗口，但要处理并发和 UX。

所有超时由服务器按可信时钟执行。前端倒计时只是提示，攻击者可禁用 JavaScript。过期处理必须把服务端状态变为不可用，而不是只返回新的登录页。不同风险角色/操作可采用不同策略，具体分钟数由威胁、用户工作流与运营容量决定，本章不编造 FactoryCare 的生产阈值。

测试使用固定时钟覆盖“恰好到期”：通常 `now >= expiresAt` 即不可用；不要使用真实 sleep。时钟回拨、跨节点时差和存储 TTL 提前/延后都需要集成环境验证。

## 17. 登出、全局撤销与成员禁用

当前会话登出至少：验证 CSRF；撤销服务端记录；清 Cookie；清/轮换 CSRF Token；返回不可缓存响应；后续旧 ID 得到 401。若提供“退出所有设备”，需按账号撤销所有会话或递增撤销版本，并让多节点在声明时限内一致。

密码恢复、凭据轮换、账号停用、租户成员删除和角色高风险变化也应触发撤销合同。FactoryCare 的 `FC-AUTH-003` 与 `FC-MEM-001` 要求成员禁用后已有 Session 立即失效；不能等客户端 Cookie 到期。

浏览器 `Clear-Site-Data` 可辅助清缓存、Cookie 或存储，但影响范围大且有用户代理差异；它不替代服务端撤销。敏感响应应使用合适 `Cache-Control: no-store`，Session ID 和私有页面不进入共享缓存。

## 18. 多节点存储与故障默认

多实例应用需要共享或可路由的 Session 状态。进程内存配合不可靠 sticky session 会让故障切换随机登出；共享存储又引入可用性、TTL、序列化、网络分区和批量泄露风险。Session repository 只保存认证连续性所需最小数据，访问最小权限，传输/静态保护并有容量上限。

存储不可用时不能把请求当匿名高权限或跳过授权。通常受保护请求安全失败；登录/刷新可返回稳定依赖故障。撤销传播比创建更安全敏感：若某节点仍接受已撤 Session，应有版本/事件/集中读取机制和明确最大窗口。

本章不替 FactoryCare 选择 Redis、数据库或 Spring Session。ADR-0008 明确 Web Session Provider 不在其范围；实现时应比较成本、迁移、风险、回滚和长期维护，再决策。

## 19. Cookie 与日志、错误、缓存

禁止记录原始 `Cookie`/`Set-Cookie`、Session ID、OIDC code 和 Token。HTTP access log、代理、APM、异常 dump 和调试工具都可能默认收集头；采用允许列表而非事后黑名单。若需关联 Session 事件，可使用独立审计 ID 或带密钥/加盐的不可逆短指纹，并限制访问和保留。

记录创建、认证轮换、升权轮换、超时、撤销、登出、无效 ID 尝试和并发策略结果；字段包含 event、actor/account 内部 ID、结果、原因、时间和 trace，不含秘密。错误响应统一为未认证/会话过期，不回显“这个 ID 曾属于管理员”等内部状态。

包含 `Set-Cookie` 或私有认证内容的响应设置 `Cache-Control: no-store`。共享缓存 key 若忽略 Cookie/Authorization 可能把用户响应给另一个用户；缓存与认证边界需在部署章节单独验证。

## 20. FactoryCare 的设计投影

FactoryCare [ADR-0003](../../../factorycare-design/adrs/0003-oidc-and-client-sessions.md)决定：Web 完成外部 OIDC Authorization Code 后，由 Java 建立 `HttpOnly; Secure; SameSite` 服务端 Session Cookie；移动端使用 Auth Code + PKCE bearer。两种客户端共享业务授权，但交换机制不同。

公共设计契约当前 Cookie 名为 `FACTORYCARE_SESSION`，本章不修改契约。以下只是属性测试基线，不是已部署响应：

```http
Set-Cookie: FACTORYCARE_SESSION=<opaque>; Path=/; Secure; HttpOnly; SameSite=Lax
Cache-Control: no-store
```

是否使用 Strict、Lax、独立 UI/API host、`__Host-` 前缀、idle/absolute 超时和并发会话上限，需要实现期结合 OIDC 回跳、跨源部署与 UX 决策。无论 SameSite 选择，状态写请求仍按 ADR 启用 CSRF；登录后轮换、登出后旧 ID 拒绝，映射到 `FC-AUTH-004`。

## 21. Spring Security 的实现边界

截至 2026-07-17，当前 Spring Security Servlet 文档说明框架在登录时创建新 Session 或改变 ID，Servlet 3.1+ 默认可使用 `HttpServletRequest#changeSessionId()`；也支持 `newSession`、`migrateSession` 等策略。禁用 fixation 防护的 `none` 会留下风险。

这些是框架集成行为，不是本章要复制的代码。`changeSessionId` 是否保留属性、监听器是否重复处理、并发 Session 和 Session repository 仍要做集成测试。仓库版本由 Spring Boot 4.1 BOM 管理，默认与 DSL 会演进；实现章节必须复核当时文档，不能把本章文字当配置输出。

Spring Security 不独自决定容器生成 Cookie 的全部属性；反向代理、Servlet 容器、Spring Session 和 Boot 配置可能共同影响最终 `Set-Cookie`。验证必须观察真实 HTTP 响应与浏览器行为。

## 22. 可重放测试矩阵

| 场景 | 请求/状态 | 预期 |
| --- | --- | --- |
| 登录轮换 | PRE ID 登录成功 | 新 ID != 旧 ID；PRE 立即 401 |
| 严格接受 | 未签发随机 ID 或 URL query ID | 不创建认证 Session；拒绝 |
| 正常访问 | ACTIVE 新 ID + 当前成员 | 认证后再做业务授权 |
| 登出 | POST + CSRF + 新 ID | 服务端 REVOKED；清 Cookie；重放 401 |
| Idle 到期 | `now >= idleExpiresAt` | 401，状态 EXPIRED |
| Absolute 到期 | 仍活跃但超过 absolute | 401，要求重认证 |
| 成员禁用 | Cookie 未过期 | 当前成员检查拒绝；Session 撤销 |
| HTTP 请求 | Secure Cookie | 浏览器不发送 |
| 子域请求 | host-only Cookie | 不发送 |
| 路径不匹配 | 受限 Path | 不发送；但不把它当授权 |
| 脚本读取 | HttpOnly | 不可读取；同源请求仍可自动携带 |

测试输出不能打印 ID。可比较 hash/布尔差异和记录计数。故障注入后保留同一输入，修复再跑；不要把失败夹具改成“更容易通过”的场景。

## 23. 诊断顺序

出现“退出后仍可访问”时，从第一处事实检查：服务端 Session 状态是否撤销 → 旧 ID 重放是否仍映射 → 清 Cookie 的 name/domain/path 是否匹配 → 代理缓存是否返回旧页面。不要因为浏览器 DevTools 看不到 Cookie 就宣称服务端失效。

出现“登录后 ID 没变”时，抓取脱敏前后指纹 → 确认认证成功事件 → 检查 fixation 策略和自定义登录过滤器 → 查看监听器/代理是否覆盖 `Set-Cookie` → 用旧 ID 单独重放。ID 值本身不进入报告。

出现“Cookie 发到不应主机”时，检查 Domain 是否省略、同名 Cookie 是否多作用域、父域/子域是否可控、代理是否重写。Path 过宽是最小化问题，但 Path 缩小不能替代同源隔离。

出现“Session 不按时过期”时，使用固定时钟对照 created/lastSeen/absolute/idle，检查比较边界、TTL 单位、刷新活动定义和节点时钟。前端计时器成功不构成服务端证据。

## 24. 120 秒讲解模板

> Cookie 是浏览器保存并按 Domain、Path、Secure、SameSite 等规则发送的 name/value；Session 是服务端用不透明 ID 关联认证状态。Session Cookie 应 host-only、Secure、HttpOnly、显式 SameSite，服务端 ID 用框架/CSPRNG 生成且不含业务信息，只从 Cookie 接受。登录或升权必须轮换 ID 并立即撤销旧 ID，防止攻击者预先固定标识；登出和超时由服务端失效，清客户端 Cookie 只是配套。HttpOnly 防脚本读值但不防 CSRF，SameSite 是纵深而不是替代 Token。失败反例是攻击者先拿 PRE ID，受害者登录后服务器继续用同一 ID，攻击者随后重放接管会话。

若讲解只会背 `Secure; HttpOnly`，却说不出 host-only、SameSite 的 site/origin 差别、服务端撤销、旧 ID 重放和固定攻击时序，尚未达到本章目标。

## 25. 自检清单

- 响应 `Set-Cookie` 与请求 `Cookie` 的方向、字段和属性是否分清？
- Session ID 是否不透明、高熵、无 PII/role/tenant，且只从 Cookie 接受？
- 是否省略不必要 `Domain`，明确 Path 又不把 Path 当授权？
- 全会话是否 HTTPS，Cookie 是否 Secure，生产是否未依赖 localhost 例外？
- Session Cookie 是否 HttpOnly，团队是否仍承认 XSS 可代表用户操作？
- SameSite 是否显式，Strict/Lax/None 与 `None; Secure` 是否按场景选择？
- 登录、升权、恢复后是否轮换，旧 ID 是否立即不可复用？
- idle、absolute、renewal 是否由服务器可信时钟执行？
- 登出是否服务端撤销并匹配原作用域清 Cookie？
- 成员禁用/凭据轮换是否在客户端 Cookie 到期前生效？
- 日志、trace、错误、URL、缓存是否都不含 Session ID？
- 多节点 repository 故障是否安全拒绝，撤销传播窗口是否明确？

## 26. 资料层级、时效与适用范围

- [RFC 6265](https://www.rfc-editor.org/rfc/rfc6265.html)：截至复核日仍是已发布的 HTTP Cookie Standards Track RFC，提供 `Set-Cookie`、Domain、Path、Secure、HttpOnly、Expires/Max-Age 等基础规范。
- [draft-ietf-httpbis-rfc6265bis-22](https://datatracker.ietf.org/doc/draft-ietf-httpbis-rfc6265bis/)：截至 2026-07-17 已获 IETF 批准并在 RFC Editor 队列，**仍未成为已发布 RFC**。它覆盖 SameSite 等现代处理；本章把它标为即将取代的规范草案，不把草案号当最终标准。
- [MDN Set-Cookie reference](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie) 与 [Using HTTP cookies](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Cookies)：浏览器属性、前缀、默认 Lax/session restore 与兼容性说明，属于权威实践文档，不高于最终 RFC/WHATWG 算法。
- [OWASP Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)：ID、TLS、固定、轮换、超时、登出、日志等工程建议，不是协议规范。
- [Spring Security Session Management](https://docs.spring.io/spring-security/reference/servlet/authentication/session-management.html)：当前 Servlet 集成与 fixation 策略；仅在使用该框架与对应版本时适用。
- [FactoryCare ADR-0003](../../../factorycare-design/adrs/0003-oidc-and-client-sessions.md)：本项目生产方向的权威架构决定；正文示例不能覆盖它。

浏览器默认、Cookie 草案、Spring 配置会变化。实现前重新核对官方来源、目标浏览器和实际响应，记录验证日期；不要把 MDN 兼容说明、OWASP 建议、IETF 草案和已发布 RFC 混成同一规范等级。

## 27. 有意不覆盖

本章不实现 Spring Security 登录、外部 OIDC code/token、Cookie Session 的具体存储 Provider、JWT、CSRF/CORS 策略、XSS 修复、反向代理/HSTS 部署或并发会话 UI；不选择生产超时数字；不连接真实浏览器、账号或服务。下一章在这里的“浏览器自动携带 Cookie”基础上处理 Origin、CORS 与 CSRF。
