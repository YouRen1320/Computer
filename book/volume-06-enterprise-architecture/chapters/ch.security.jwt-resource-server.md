---
schema_version: 2
edition: 2026.2-draft
id: ch.security.jwt-resource-server
title: JWT 验证、Bearer Token 与 Resource Server
responsibility: 教授资源服务器验证自包含 Token 的边界，不把解码等同于验签或把 JWT 当作可撤销 Session
volume: '06'
order: 8
level: L2
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.security.jwt-resource-server.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.security.session-authentication
version_surfaces:
- spring-security
- spring-boot-4.1
- testcontainers
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释JWT 验证、Bearer Token 与 Resource Server的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - security-jwt-validation
  - security-resource-server
  covers_topics:
  - security.jwt-structure
  - security.jwt-signature-claims
  - security.jwt-expiry-audience-issuer
  - security.bearer-token
  - security.resource-server
  - security.token-error-contract
  uses_capabilities:
  - security.authentication
  - security.web-threat
  - foundation.http-message
  - backend.spring-mvc-contract
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 配置 Resource Server 验证签名、iss/aud/exp/nbf 与 Bearer 头，为合法、过期、错签名和错 audience Token 写负测
  covers_topic_groups:
  - security-jwt-validation
  - security-resource-server
  covers_topics:
  - security.jwt-structure
  - security.jwt-signature-claims
  - security.jwt-expiry-audience-issuer
  - security.bearer-token
  - security.resource-server
  - security.token-error-contract
  uses_capabilities:
  - security.authentication
  - security.web-threat
  - foundation.http-message
  - backend.spring-mvc-contract
  evidence_kind: system-artifact-and-negative-tests
  verification_mode: system-security-resilience-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入只 Base64 解码不验签、接受 alg/issuer 错配和 Token 写 query，依据验证链修复，并把异常定位到第一处可信证据
  covers_topic_groups:
  - security-jwt-validation
  - security-resource-server
  covers_topics:
  - security.jwt-structure
  - security.jwt-signature-claims
  - security.jwt-expiry-audience-issuer
  - security.bearer-token
  - security.resource-server
  - security.token-error-contract
  uses_capabilities:
  - security.authentication
  - security.web-threat
  - foundation.http-message
  - backend.spring-mvc-contract
  evidence_kind: fault-injection-fix-rerun
  verification_mode: fault-injection-rerun
---
# JWT 验证、Bearer Token 与 Resource Server

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Spring Security 登录、退出、密码编码与 Session 防护》](ch.security.session-authentication.md)：独立完成JWT 验证、Bearer 与资源服务器前，必须先具备「Spring Security 登录、退出、密码编码与 Session 防护」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套程序不生成真实 JWT、不实现密码学、不下载 JWK、不启动 Authorization Server 或 Resource Server；它只用合成 Token 元数据模拟验证顺序，且不输出完整 Token。通过只能证明策略预言，不能证明密钥、JOSE 库、网络发现、时钟或 Spring Security 集成正确。

JWT 最危险的误解是“能把 payload 解出来，所以 Token 有效”。Base64url 解码只恢复攻击者可写的 JSON；只有在算法和密钥策略确定、签名/密码学操作成功、issuer/audience/时间/类型等 claims 全部验证后，资源服务器才能把 claims 转成认证主体。即使 Token 合法，也不等于当前成员仍启用或拥有任意业务数据范围。

## 1. 完成定义与证据入口

完成本章应能：

1. 解释 compact JWT 的 header、claims、signature 三段，区分编码、签名和加密；
2. 按“提取 Bearer → 限制格式/算法 → 选可信密钥 → 验签 → 验 iss/aud/exp/nbf/type/sub → 映射 authority”顺序验证；
3. 只从 `Authorization: Bearer` 接受 Token，拒绝 query、冲突 Header 和日志回显；
4. 为合法、过期、未生效、错签名、错 issuer、错 audience、错 alg/type Token 写 401 负测；
5. 区分 invalid token 的 401 与已认证但 scope/业务权限不足的 403；
6. 说明 JWT 自包含的缓存/离线优势与即时撤销、密钥轮换、claims 陈旧风险；
7. 在 FactoryCare 中让 mobile bearer 只建立身份起点，再重建当前 membership、租户和 data scope。

配套入口：

- [JWT 验证链示例](../../../examples/encyclopedia/ch.security.jwt-resource-server/README.md)
- [Bearer 与 claims 故障实验](../../../labs/encyclopedia/ch.security.jwt-resource-server/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.security.jwt-resource-server/README.md)

## 2. JWT、JWS、JWE 与 Bearer 是不同概念

JWT 是一组 JSON claims 的紧凑表示规则。常见签名 JWT 实际使用 JWS compact serialization，形如 `base64url(header).base64url(payload).base64url(signature)`。三段并不意味着加密：任何拿到 Token 的人通常都能解码 header 与 payload，所以其中不能放密码、私钥、完整联系人或不应暴露的业务正文。

JWS 提供完整性与来源验证；JWE 提供加密。一个 Token 可以嵌套，但复杂度和误配风险更高。资源服务器不能仅凭“三段字符串”猜它是受支持的 access token；要按明确的 token profile、issuer 和类型处理。

Bearer 是使用模型：谁持有 Token，谁就能以其权限调用，通常没有额外 proof-of-possession。Bearer Token 可以是 JWT，也可以是不透明随机串。JWT 格式与 Bearer 传输协议是两个层次；FactoryCare OpenAPI 的 `mobileBearer` 明确为 `opaque-or-OIDC-access-token`，若 Provider 发 opaque token，应使用 introspection，而不是强行 Base64 解码。

## 3. Header 不是可信配置

JOSE header 常见 `alg`、`kid`、`typ`。它们位于 Token 内，由发送者提供；资源服务器可用它们选择候选验证路径，但不能让它们决定“接受什么”。服务器预先配置允许的 issuer、token type、算法族和密钥来源，再检查 header 是否与配置相符。

`alg: none`、对称/非对称算法混淆、接受未预期算法都可能让攻击者绕过。不能因为 JWK 声称某 alg 就扩大应用允许列表，也不能把 RSA 公钥字节误当 HMAC secret。RFC 8725 要求使用适当算法、验证所有密码学操作，并为不同 JWT 类型使用互斥验证规则。

`kid` 是密钥标识，不是文件路径、SQL 片段或任意 URL。只在该 issuer 的可信 JWK set 中选择，限制长度/字符，找不到就安全失败并按受控刷新策略处理，不能回退到“任意第一把钥匙”。

## 4. Claims 是声明，不是事实

payload 中每个字段都是 claim。签名成功只说明可信 issuer 对这些字节签名，不保证资源服务器理解或接受其语义。常见 registered claims：

- `iss`：谁签发；必须与配置的规范 issuer 精确匹配；
- `sub`：issuer 命名空间内的主体；通常与 issuer 组合作为稳定外部身份键；
- `aud`：Token intended recipient，可为字符串或数组；必须包含本资源服务器 audience；
- `exp`：到此时间后不得接受；
- `nbf`：此前不得接受；
- `iat`：签发时间，可做合理性/最大年龄策略，但不是独立有效性证明；
- `jti`：Token 标识，可辅助审计/撤销，但存在不等于自动防重放。

角色、tenant、email 等自定义 claims 也不能盲信。FactoryCare 以 `iss + sub` 映射内部账号，再从数据库读取当前 membership、角色与 data scope。把客户端长期 access token 内的旧 role 当最终授权，会让禁用和撤权延迟到过期。

## 5. 完整验证链及顺序

### 5.1 从唯一通道提取

默认只接受一个 `Authorization` Header，scheme 必须为 Bearer，语法合法且 Token 非空。拒绝 query `access_token`、Cookie 和多个冲突来源。URI query 容易进入浏览器历史、代理、Referer、访问日志和监控；RFC 6750 虽记录这种方式，但明确不推荐。

提取前限制 Header/Token 长度，防止超大输入消耗 Base64/JSON/密码学资源。错误不回显 Token。

### 5.2 解析但不授权

解析三段、base64url 和 JSON 只是获得待验证数据。限制段数、解码大小、JSON 深度、重复 claim/键处理。任何解析结果都不可写入 SecurityContext、日志身份字段或业务查询，直到后续全部验证通过。

诊断工具可以展示脱敏 header/claims，但 UI 必须大字标明“unverified”。开发者网站解码生产 Token 还会向第三方泄密，不应使用。

### 5.3 固定算法与密钥边界

根据已配置 issuer/token profile 确定允许算法，检查 header alg 在集合内；用受信 JWK set 的 `kid` 选 key，验证 key type/use/strength 与算法匹配。密钥来自 HTTPS 元数据/JWK、配置或受控缓存，不来自 Token 中任意 URL。

### 5.4 验证签名

用成熟 JOSE 库验证签名覆盖的 header.payload。失败立即 401，不继续信任 claims。禁止自己实现 RSA/ECDSA/HMAC、Base64 拼接或 constant-time 比较。

### 5.5 验证 issuer 与 audience

`iss` 精确匹配，包括 scheme、host、path 与尾斜杠规范；不要用 contains/endsWith。`aud` 必须包含 FactoryCare API 预定 audience，不能因为 Token 对另一个服务有效就接受。多个 issuer 使用各自独立的算法、key、audience 和 claim mapping，不能混用。

### 5.6 验证时间

`now < exp` 才有效；`now >= nbf` 才开始有效。使用注入 Clock 和小而明确的 clock skew 处理节点时钟差，skew 不是延长 Token 生命周期的随意窗口。缺失 exp 是否允许由 profile 决定；access token 通常要求短期 exp。

### 5.7 验证类型与主体

明确只接受 access token profile，拒绝 ID Token、logout token 或其他 JWT 被替换使用。检查 `typ`/profile 要结合 issuer 配置，不能仅看字符串。`sub` 非空且能映射当前启用账号；必要时检查 client/azp、scope 等 profile 约束。

### 5.8 最后才映射 Authentication

全部通过后，`JwtAuthenticationConverter` 等组件把 scope 映射为 `SCOPE_...` authority，把 principal 放入 SecurityContext。随后业务层仍校验资源、租户、组织范围与状态。验证成功不是业务授权成功。

## 6. 签名验证解决什么、不解决什么

签名能检测 Token 是否被修改，并在密钥可信时证明来自持钥者。它不隐藏内容、不保证客户端安全存储、不阻止合法 Token 被窃取重放、不保证 claims 仍是最新业务事实，也不自动撤销。

HTTPS 仍是必须：没有 TLS，Bearer 可被窃取；TLS 也不阻止设备恶意软件、日志或崩溃报告泄漏。短寿命、最小 audience/scope、安全存储、撤销策略和服务器当前授权检查共同限制影响。

## 7. 密钥发现、缓存与轮换

资源服务器可通过 issuer metadata 找到 JWK set，并缓存公钥。Provider 轮换 key 时，新 `kid` 触发刷新；旧 key 在已签 Token 生命周期内可能需保留。刷新失败的安全行为要明确：已缓存且仍受信的 key 可在策略内继续验证，未知 kid 不能无界重试或自动信任远端任意 key。

启动是否依赖 Authorization Server 是部署选择。Spring Security/Boot 可用 `issuer-uri` 自动发现，也可显式 `jwk-set-uri` 保持 issuer 验证；当前文档还提供延迟 decoder 以降低启动耦合。每种配置都要测试 Provider 不可用、缓存已有 key、新 kid、错误 issuer 和轮换窗口。

JWK endpoint 是外部依赖与 SSRF 边界：地址来自受控配置，不来自 Token。限制出站、TLS、响应大小和刷新频率。生产不在日志打印 JWK 私钥；资源服务器通常只持公钥。

## 8. JWT 为什么不是可撤销 Session

服务端 Session 每次请求查服务端状态，可立即删除。自包含 JWT 在离线验证通过时不必查询 issuer，所以天然不会知道“刚才 logout/撤销”。把 JWT 放进 Redis 并每次检查 denylist 可以实现撤销，但已经重新引入服务端状态、容量和一致性成本。

常用组合是短 access token + 可撤销 refresh token；高风险系统加入 token version、事件驱动撤销或 introspection。选择取决于撤销时效、可用性与规模。本章不实现 refresh/OAuth 客户端流程。

FactoryCare 即使 JWT 尚未过期，也每次确认内部 membership 启用；这可立即阻止禁用成员，但不能使 Token 在所有其他 audience 自动失效。登出含义由客户端/Authorization Server 协调，不能照搬 Session invalidate。

## 9. Bearer Token 传输与存储

原生/移动端把 access/refresh token 放平台安全存储，不放普通日志、analytics、自定义 URL、剪贴板或明文数据库。Web 端按 ADR 使用 HttpOnly Session Cookie，降低脚本直接读取 bearer 的风险；不要为了“统一”让 Vue 把 access token 放 localStorage。

请求使用 `Authorization: Bearer <token>`。代理、APM 和应用日志对 Authorization 默认脱敏；trace 只记录认证结果、issuer ID、失败阶段和 Token 指纹（若确有需要，用不可逆且带服务器秘密的短指纹），不记录完整 token/header/payload。

不得把 Token 转发给任意下游。只有目标 audience 与委托模型允许时，使用 token exchange/受控客户端凭据；把入站 bearer 原样传播到另一个服务容易造成 confused deputy 与 audience 绕过。

## 10. Resource Server 的框架路径

Spring Security `BearerTokenAuthenticationFilter` 从请求解析 bearer，构造 `BearerTokenAuthenticationToken` 并交给 AuthenticationManager。JWT 场景由 `JwtAuthenticationProvider` 调用 `JwtDecoder` 做 decode、signature 与 validators，再经 `JwtAuthenticationConverter` 映射 authorities；成功对象进入 SecurityContext，失败由 Bearer entry point 返回 challenge。

依赖边界上，resource-server 支持与 JOSE/JWT 支持是不同模块；Boot starter/BOM 管理组合。配置 `issuer-uri` 默认验证 issuer，并结合 decoder 验证签名与时间；audience 必须通过 Boot audiences 属性或自定义 validator 显式声明，不能假定自动等于 API。

自定义 converter 只能在验证完成后转换 claims，不能在 converter 中“补验签”。自定义 decoder/validator 应组合现有实现，避免替换后丢掉默认 timestamp/issuer 验证。

## 11. 401、403 与 RFC 6750 challenge

缺失、格式错误、签名失败、过期、未生效、错 issuer/audience/type 都是认证失败，通常返回 401，并使用 `WWW-Authenticate: Bearer`；可按 RFC 6750 使用 `invalid_token`，但 error_description 不泄漏 key、claims 或内部配置。

Token 合法但缺所需 OAuth scope，可返回 403 与 `insufficient_scope`；Token 合法但 FactoryCare 业务 data scope/租户不足，也属于授权拒绝，按项目 Problem/隐藏策略处理。客户端据此区分“需要重新认证”与“当前身份无权”。

Spring Filter 在 MVC 前失败，`@ControllerAdvice` 不会自动统一所有 bearer 错误。配置 `AuthenticationEntryPoint`/`AccessDeniedHandler` 保留 RFC challenge，同时写 FactoryCare `application/problem+json` 的 type/title/status/code/message/traceId。契约测试同时断言 Header、body、状态和无业务查询。

## 12. FactoryCare 客户端边界

ADR-0003 规定：Web 使用服务端 Session；Flutter 与具备安全能力的小程序使用 Authorization Code + PKCE 的短时 bearer。Public API 的 `mobileBearer` 可为 opaque 或 OIDC access token。资源服务器根据 Provider 实际格式选择 JWT decoder 或 opaque introspection，不能从字符串形状猜测。

对 JWT access token，配置稳定 issuer、FactoryCare API audience、允许算法和 JWK；用 `iss+sub` 映射内部 user_account。随后读取当前 membership、tenant、角色与 data scope，禁止客户端 claim `tenantId` 直接成为查询过滤条件。

`FC-AUTH-002` 要求 issuer/audience/signature/time 四类错误均稳定拒绝且不进入业务查询；`FC-AUTH-003` 要求成员禁用立即生效。日志禁止完整 Token、code 与 subject。OIDC/PKCE 客户端流程属于下一章，本章只做 Resource Server 端。

## 13. Scope 与业务权限不是同一层

OAuth scope 是授权服务器授予客户端/Token 的粗粒度能力，例如 `workorders.read`。Spring 可映射为 `SCOPE_workorders.read`。FactoryCare 还需要角色、组织 data scope、资源所有权、状态机前置和租户隔离。

正确判定是多层 AND：Token profile/claims 有效；具备入口 scope；内部成员当前启用；角色允许动作；data scope 覆盖目标；资源状态允许。任一失败不执行副作用。把所有对象 ID 塞进 JWT 不可维护且会陈旧，把所有业务授权交给 issuer 会耦合领域模型。

## 14. Token 类型混淆

同一 issuer 可能签发 access token、ID Token、logout token、authorization response JWT。它们可能使用同一 key 并含相似 claims。只验签和 issuer，就可能把给客户端证明登录的 ID Token 当 API access token。

RFC 8725 建议显式 typing，并为不同 JWT 类型使用互斥验证规则：不同 `typ`、audience、required claims、key 或 issuer profile。Resource Server 只接受 access token profile；ID Token 的 audience 通常是 client，不是 API。测试用一枚密码学有效但类型错误的 synthetic metadata Token，必须 401。

## 15. 时钟与有效期边界

NumericDate 以秒表示时间点。固定 Clock 测试：`now == exp` 时已过期；`now < nbf` 时尚未生效；允许 skew 时边界按 validator 明确定义。系统时钟同步是基础设施依赖，不能把 10 分钟 skew 当修复。

过长 access token TTL 扩大窃取窗口；过短会增加刷新与离线复杂度。TTL 由威胁、移动网络和撤销 SLO 决定，并由 Authorization Server 签发策略控制。Resource Server 不可擅自改 Token exp，只能接受或拒绝。

不要只验证 exp 而漏 nbf/issuer/audience；也不要用 `iat` 代替 exp。若 profile 要求 exp，缺失就失败。

## 16. 日志、指标和隐私

JWT payload 可含 subject、email、tenant hint、scope 等敏感元数据。签名不等于可公开。禁止在异常、Access log、trace baggage、metrics label、SIEM 原文、测试 snapshot 和客服截图中记录完整 Token。

可观测字段采用 allowlist：auth outcome、reason category（signature/expired/audience/issuer/malformed）、configured issuer alias、route、traceId。不要把任意 `sub` 放高基数指标；安全事件需要主体时映射内部脱敏 ID。失败响应也不告诉攻击者期望 audience 或 key id。

## 17. 可重放验证矩阵

| Token/请求 | 预期 |
| --- | --- |
| 合法签名+iss+aud+时间+type | 建立认证，随后业务授权 |
| Base64 可解码但 signature false | 401，claims 不进入 context |
| `alg=none`/非允许算法 | 401，密钥查找前拒绝 |
| 错 issuer | 401 |
| audience 不含 API | 401 |
| `now == exp` | 401 expired |
| `now < nbf` | 401 not active |
| 合法 ID Token 当 access token | 401 type/profile |
| Token 写 query | 401/400，日志不含值 |
| Header 合法但缺 scope | 403 insufficient scope |
| Token 合法、membership disabled | 401/设计的稳定无效身份，无业务查询 |

测试报告只写 case ID 和结果，不把 synthetic compact token 输出。固定 Clock、fake decoder/key metadata 和 spy business gateway 可证明失败发生在业务层之前。

## 18. 故障注入与第一处可信证据

| 故障 | 第一处可信偏差 | 正确修复 |
| --- | --- | --- |
| 只 Base64 解码 | signature=false 仍生成 Authentication | 使用 JwtDecoder 验证密码学与 claims |
| 信任 header `alg` | `none`/非允许算法进入 key path | 服务器固定 allowlist/profile |
| 不验 issuer | 外部 issuer Token 成功 | exact issuer validator |
| 不验 audience | 给另一 API 的 Token 成功 | required audience validator |
| Token 接受 query | resolver 从 URI 取值 | 只允许 Authorization Header |
| 完整 Token 写日志 | failure log 含 compact value | 字段 allowlist/脱敏指纹 |
| JWT 过期才检查成员禁用 | disabled member Token 仍访问 | 每请求重建内部 membership |

修复顺序与验证链一致。不要先改 Controller authority 来掩盖 decoder 漏洞；claims 未可信前，业务层不应被调用。

## 19. 常见错误

- 在线解码器显示 payload 就认为 Token 有效；
- 在代码里手写 Base64+RSA，而非成熟 JOSE 库；
- 接受 Token 自报的任意 alg/kid/jku；
- 只验签，漏 issuer/audience/exp/nbf/type；
- 把 ID Token 当 access token；
- 从 query 接受 bearer，完整 URL 被日志记录；
- 把 JWT 放 localStorage 作为 Web 默认会话；
- 把 role/tenant claim 当最终业务授权；
- logout 后假设所有自包含 JWT 立即撤销；
- key refresh 失败时接受未知 kid；
- 自定义 validator 覆盖掉默认 timestamp/issuer validator；
- 401/403 都返回 200 或同一个模糊错误；
- Testcontainers/fake IdP 未运行却宣称真实 key rotation 已验证。

## 20. 120 秒口述模板

“JWT compact 常见三段是 header、claims、signature，Base64url 只是编码，payload 可读；Bearer 表示持有者即可使用，JWT 也可能不是 bearer，bearer 也可能 opaque。资源服务器只从 Authorization Header 提取，先按服务器配置限制算法和可信 key，再验签，然后精确验证 iss、aud、exp、nbf、token type 和 sub，全部通过后才映射 scope/Authentication。签名不加密、不防窃取重放、不让业务 claims 自动最新；FactoryCare 仍从 iss+sub 重建当前 membership、租户和 data scope。无效 Token 返回 401+Bearer challenge，合法 Token 缺 scope/权限返回 403。反例是 payload 能解码就建立 context，攻击者可自写 admin claim。”

## 21. 标准、OWASP 建议与框架行为

截至 2026-07-24：

- [RFC 7519 JSON Web Token](https://www.rfc-editor.org/rfc/rfc7519.html) 定义 JWT 与 registered claims；[RFC 7515 JSON Web Signature](https://www.rfc-editor.org/rfc/rfc7515.html) 定义 JWS；[RFC 6750 Bearer Token Usage](https://www.rfc-editor.org/rfc/rfc6750.html) 定义 Authorization Header、challenge 与错误；[RFC 8725 JWT Best Current Practices](https://www.rfc-editor.org/rfc/rfc8725.html) 是更新 RFC 7519 的 BCP，强调算法、issuer/audience、typing 与互斥规则。它们是标准/BCP 层。
- [OWASP REST Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html) 包含 JWT 完整性、标准 claims 与 REST 资源服务器的工程建议，不替代 RFC 或具体 Provider profile。原 Java JWT 专项页面已于本次复核时失效，因此不再保留断链。
- [Spring Security OAuth 2.0 Resource Server](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/index.html)、[JWT](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html) 与 [Bearer Tokens](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/bearer-tokens.html) 描述当前 Filter、JwtDecoder、validators、JWK rotation、authority mapping 和错误响应，属于版本相关框架行为。
- [Testcontainers for Java](https://java.testcontainers.org/) 可用于真实 Provider/依赖集成。版本登记仍为 `provisional`，离线资产不声称完成容器验证。

项目由 Boot 4.1 管理 Spring Security 版本，不单独覆盖。RFC 的验证义务是稳定边界；Spring 配置属性、默认 decoder 初始化和 DSL 可能演进，必须在锁定依赖组合上测试。
