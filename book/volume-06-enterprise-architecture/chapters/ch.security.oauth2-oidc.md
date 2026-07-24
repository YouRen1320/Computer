---
schema_version: 2
edition: 2026.2-draft
id: ch.security.oauth2-oidc
title: OAuth 2.0 授权流程、OIDC 登录与客户端边界
responsibility: 区分 OAuth 授权与 OIDC 身份层并实现安全客户端边界，不自建授权服务器或混淆 Access Token 与 ID Token
volume: '06'
order: 9
level: L2+
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.security.oauth2-oidc.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.security.jwt-resource-server
version_surfaces:
- oauth2-security-bcp
- oidc-core
- spring-security
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释OAuth 2.0 授权流程、OIDC 登录与客户端边界的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - security-oauth2
  - security-oidc
  covers_topics:
  - security.oauth2-roles
  - security.authorization-code-pkce
  - security.access-refresh-token
  - security.oidc-id-token
  - security.oidc-discovery
  - security.oauth-client-secret-boundary
  uses_capabilities:
  - security.authentication
  - security.web-threat
  - foundation.http-message
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 画 Authorization Code+PKCE 与 OIDC 登录时序，配置 state/nonce/redirect URI，并区分 ID/Access/Refresh Token 用途
  covers_topic_groups:
  - security-oauth2
  - security-oidc
  covers_topics:
  - security.oauth2-roles
  - security.authorization-code-pkce
  - security.access-refresh-token
  - security.oidc-id-token
  - security.oidc-discovery
  - security.oauth-client-secret-boundary
  uses_capabilities:
  - security.authentication
  - security.web-threat
  - foundation.http-message
  evidence_kind: system-artifact-and-negative-tests
  verification_mode: system-security-resilience-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入缺 state、宽 redirect URI、用 ID Token 调 API 和 Refresh Token 泄露，模拟回调后修复，并把异常定位到第一处可信证据
  covers_topic_groups:
  - security-oauth2
  - security-oidc
  covers_topics:
  - security.oauth2-roles
  - security.authorization-code-pkce
  - security.access-refresh-token
  - security.oidc-id-token
  - security.oidc-discovery
  - security.oauth-client-secret-boundary
  uses_capabilities:
  - security.authentication
  - security.web-threat
  - foundation.http-message
  evidence_kind: fault-injection-fix-rerun
  verification_mode: fault-injection-rerun
---
# OAuth 2.0 授权流程、OIDC 登录与客户端边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《JWT 验证、Bearer Token 与 Resource Server》](ch.security.jwt-resource-server.md)：独立完成OAuth 2.0 授权、OIDC 身份层前，必须先具备「JWT 验证、Bearer Token 与 Resource Server」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套资产只用固定时钟和合成事务元数据模拟授权回调，不连接身份提供方、不签发或解析真实 Token、不保存真实 client secret，也不启动 Authorization Server。局部验证通过只能证明流程不变量与负向预言，不能证明某个 Provider、浏览器、系统回调、TLS、密钥轮换或 Spring Security 集成已经正确。

OAuth 2.0 回答的是“一个客户端如何在限定范围内代表资源所有者访问受保护资源”；OpenID Connect（OIDC）在 OAuth 2.0 上增加可互操作的身份认证层，回答“客户端如何确认这次登录的最终用户是谁”。二者经常出现在同一个重定向流程里，却不是同一件事。把 Access Token 当登录资料、把 ID Token 发给业务 API、让浏览器保存 client secret，都会把协议中的边界拆掉。

FactoryCare 的生产基线不是自研用户名密码、MFA、授权服务器或 JWT 签发器，而是外部 OIDC Provider。Web 端完成授权码流程后由 Java 建立 `HttpOnly; Secure; SameSite` 服务端会话；Flutter 与具备安全存储和系统浏览器能力的客户端使用 Authorization Code + PKCE 和短时 bearer。Java 最终仍以已验证的 `issuer + subject` 映射内部账号，并重建当前 membership、角色与 data scope。

## 1. 完成定义与证据入口

完成本章，应能独立做到以下事情：

1. 指出资源所有者、用户代理、客户端、授权服务器、资源服务器、OIDC Provider 与 Relying Party 的职责，不能把“用户”“App”“API”“登录服务器”混成一个框；
2. 画出 Authorization Code + PKCE 从发起到回调、换 Token、验证 ID Token、建立本地会话的完整时序；
3. 解释 `state`、`nonce`、`code_verifier/code_challenge` 分别绑定什么，为什么三者名字相近却不可随意互换；
4. 精确匹配预注册 redirect URI，拒绝通配域名、任意路径、开放重定向和回调后未经校验的 `returnUrl`；
5. 区分 authorization code、Access Token、ID Token、Refresh Token 的接收者、用途、寿命、存储位置与泄露影响；
6. 说明公开客户端为何不能靠静态 client secret 证明身份，机密客户端的 secret 又为何不能进入前端包、移动安装包或仓库；
7. 用稳定红灯证明：state/nonce 错配、redirect 不精确、PKCE verifier 错误、ID Token 调 API、Refresh Token 暴露都被拒绝；
8. 说明 Spring Security 能完成哪些协议机械工作，哪些业务身份映射、成员禁用与权限判断仍由 FactoryCare 负责。

配套入口：

- [OAuth/OIDC 边界示例](../../../examples/encyclopedia/ch.security.oauth2-oidc/README.md)
- [授权回调故障实验](../../../labs/encyclopedia/ch.security.oauth2-oidc/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.security.oauth2-oidc/README.md)

## 2. 先建立角色地图

### 2.1 OAuth 角色

资源所有者（Resource Owner）通常是最终用户，能够授权客户端访问某些资源。客户端（Client）是希望获得这种委托访问的软件，不等于用户本人。授权服务器（Authorization Server）验证用户、获得授权并签发凭据。资源服务器（Resource Server）托管 API，验证 Access Token 并执行权限。用户代理（User Agent）通常是浏览器，它搬运重定向，却是不可信输入通道。

例如，FactoryCare Flutter App 想读取当前技师可见工单：技师是资源所有者语境中的用户，App 是公开客户端，外部 Provider 是授权服务器/OIDC Provider，FactoryCare Java API 是资源服务器。App 不能因为“是官方安装包”就被当作能保守秘密的服务器，也不能直接替 API 决定技师能看哪些工单。

OAuth 的“授权”是委托访问，不等同于 FactoryCare 内部的 RBAC/ABAC。Provider 可以让客户端获得面向 `factorycare-api` 的 Access Token；Java 仍要判定当前 membership 是否启用、是否拥有 `WORK_ORDER_READ`、是否在目标组织或 team 数据范围内。

### 2.2 OIDC 角色

OIDC 把授权服务器扩展为 OpenID Provider（OP），把希望登录用户的客户端称为 Relying Party（RP）。OP 发出的 ID Token 是关于一次认证事件和用户标识的声明，RP 验证它后建立自己的登录状态。FactoryCare Web 的 Java 端是机密 RP；Flutter 可作为公开原生 RP。FactoryCare 业务 API 不因为收到任意 ID Token 就变成该 Token 的 RP。

`openid` scope 是进入 OIDC 语义的信号。没有它的普通 OAuth 授权响应不能被客户端想当然解释成标准身份登录。即使请求了 `profile` 或 `email`，这些 claims 也只是 Provider 对用户资料的声明，不是 FactoryCare 角色、tenant 或 membership 的权威来源。

### 2.3 公开客户端与机密客户端

机密客户端能在受控服务器环境中保护凭据，例如 Java 服务端保存由秘密管理系统注入的 client secret，或使用私钥客户端认证。公开客户端运行在用户可控制设备中，包括 SPA、原生 App、桌面程序和小程序包；反编译、调试或代理流量的人都能取得打包进去的“secret”。因此公开客户端不能用共享静态 secret 证明“我是唯一合法 App 实例”。

PKCE 不是把公开客户端变成机密客户端。它把某次授权请求和某个客户端实例临时生成的 verifier 绑定，减少截获授权码后被别处兑换的风险。client secret 认证客户端身份，PKCE 保护单次授权码，两者威胁模型不同。

## 3. OAuth 与 OIDC 的职责分界

可以用“接收者和目的”快速判断：Access Token 的接收者是资源服务器，目的是访问 API；ID Token 的接收者是发起登录的客户端/RP，目的是确认认证结果；Refresh Token 的接收者是授权服务器的 token endpoint，目的是在授权仍有效时换取新 Access Token；authorization code 也是只给 token endpoint 的短时一次性中间凭据。

Access Token 可能是 JWT，也可能是不透明字符串。客户端通常不应依赖其内部格式；资源服务器按 issuer、audience、签名/内省和时间策略验证。ID Token 通常是 JWT，但“能验签”仍不意味着能拿它调用 API：它的 audience 是客户端，claims 与防重放规则也面向登录。把 ID Token 放进 `Authorization: Bearer` 是 token substitution，不是节省一次 Token。

OIDC 登录成功也不直接授予 FactoryCare 业务权利。`issuer + sub` 只定位外部身份；Java 查询 `user_account` 与当前 membership，检查启用状态，再读取固定 role/permission catalog 和数据范围。如果 Provider Token 尚未过期而成员已被禁用，`FC-AUTH-003` 要求立即拒绝。

## 4. Authorization Code + PKCE 的逐步时序

下面是安全主线，不使用 Implicit Grant 或 Resource Owner Password Credentials 作为新实现默认值。

### 4.1 发起事务

客户端首先创建一次登录事务，生成不可预测且一次性的 `state`、OIDC `nonce`、PKCE `code_verifier`。`code_verifier` 留在该客户端实例的临时受保护状态中；客户端计算 `BASE64URL(SHA256(code_verifier))` 得到 `code_challenge`，并声明 `code_challenge_method=S256`。同时保存本事务精确 redirect URI、issuer、发起时间和回调后允许的本地目标。

这些值不是长期配置，也不能所有用户共用一个常量。事务状态应有短 TTL、只能消费一次，并绑定发起浏览器会话或设备上下文。日志只能记录合成 transaction ID 与失败类别，不能记录完整 state、nonce、verifier 或 authorization code。

### 4.2 重定向到 authorization endpoint

客户端把用户代理重定向到由可信 issuer 元数据得到的 authorization endpoint，请求包含 `response_type=code`、`client_id`、精确 `redirect_uri`、scopes、state、nonce、code challenge 等。浏览器地址栏里的参数仍是可见的；不能在其中放 client secret、Refresh Token 或业务隐私。

授权服务器验证客户端注册与 redirect URI，认证用户并获得授权。它不应把用户密码交给客户端。成功后把短时 authorization code 和原 state 送回预注册回调；错误回调同样要绑定事务，不能因为是错误路径就跳过校验。

### 4.3 客户端接收回调

客户端先从自己的临时事务存储按安全关联取出预期值，再做比较。没有对应事务、state 缺失/不等、事务已消费或超时，都必须停止，不能先兑换 code 再补校验。若支持多个 issuer，还要防 mix-up：回调必须对应最初选定的 issuer，不能让攻击者把一个 Provider 的 code 送到另一个 Provider 的 token endpoint。

回调处理器不应把任意 `returnUrl` 直接 302。只允许站内相对路径或预先允许目标，避免客户端自身成为开放重定向器。浏览器可见的 code 应尽快兑换并通过干净重定向移出地址栏，但清理 URL 不能代替校验与服务端日志脱敏。

### 4.4 后通道兑换 authorization code

客户端向可信 token endpoint 发送 code、与发起时完全相同的 redirect URI、client ID，以及原始 `code_verifier`。机密客户端还按注册方式执行客户端认证。授权服务器核对 code 未消费、绑定的 client/redirect、PKCE challenge 和其他条件；成功后使 code 失效并返回 Token。

只有掌握原 verifier 的实例才能兑换被截获的 code。若发起请求含 challenge，token endpoint 却允许缺 verifier 或错误 verifier，PKCE 就退化。RFC 9700 还要求防 PKCE downgrade：不能在兑换时看到 verifier 就假定发起阶段必有 challenge。

### 4.5 验证 OIDC 响应并建立本地状态

客户端验证 ID Token 的签名、issuer、audience、时间、nonce；多 audience 情况按 OIDC 规则处理 `azp` 等要求。验证成功后，用 `issuer + sub` 定位外部身份映射。邮箱可变化、可复用、可能未验证，不能只按邮箱静默合并已有账号。

FactoryCare Web 随后创建新的服务端 Session，轮换预认证 Session ID，并让浏览器只持有安全 Cookie。客户端不把 Access/Refresh Token 暴露给 Vue。移动端则把短时 Access Token 与必要 Refresh Token 放进平台安全存储，不进普通偏好、日志、剪贴板或崩溃报告。

## 5. state、nonce 与 PKCE 不可混成一个“随机串”

`state` 由 OAuth 客户端发出并在回调原样比较，传统用途是把授权响应绑定到发起用户代理事务，抵御登录 CSRF，也可间接关联本地返回目标。若 state 携带应用状态，其完整性与机密性需要额外保护；更稳妥的方式是 state 只做不透明索引，真实数据存在服务端。

`nonce` 是 OIDC 认证请求中的一次性值，客户端要求它出现在相应 ID Token 中。客户端在验证过签名等条件后比较 nonce，用来把 ID Token/认证响应绑定到当前事务并降低重放。只在 URL 看见同名 nonce 不算验证，必须检查受验证 ID Token 中的 claim。

PKCE 的 verifier/challenge 把 authorization code 与发起客户端实例绑定。它主要在 token endpoint 发挥作用。RFC 9700 说明，在确认授权服务器正确支持 PKCE的条件下，PKCE也可提供回调 CSRF 防护；OIDC nonce 也有相应保护价值。但工程上不应因“协议允许某种等价保护”就随意删掉框架生成的 state。应按所用流程、Provider 能力和框架文档形成明确测试，不从博客复制删减版参数集合。

诊断时先问每个值在哪生成、存在哪里、在哪个端点比较、是否一次性、绑定哪一个会话。能答出这五项，才说明实现的不是装饰性随机数。

## 6. redirect URI 是凭据投递地址

authorization code 会通过浏览器送到 redirect URI，因此 URI 注册近似“凭据收件地址”。RFC 9700 要求除原生应用 localhost 端口的特例外进行精确字符串匹配。`https://*.example.com/**`、只比 host 后缀、忽略 path、允许任意 query 拼接或信任未经净化的代理头，都会扩大攻击者可接收 code 的位置。

生产 redirect 应使用 HTTPS。原生客户端使用系统浏览器与平台推荐回调机制；不要嵌入可窃取凭据的 WebView。自定义 scheme 可能被其他 App 抢注，通用链接/app link 与 claimed HTTPS redirect 仍需平台关联文件和系统行为测试。localhost loopback 的动态端口是规范化特例，不应外推成所有 redirect 都可通配。

客户端本身也不能提供 `?next=https://evil.example` 的开放重定向。即使 Provider 只回到合法 URI，客户端随后把 code 或登录状态转发到攻击站点仍会破坏边界。反向代理部署还要固定外部基址并清洗 Forwarded 头，不能让外部请求伪造回调 host。

## 7. 三类 Token 的用途与存储

### 7.1 Access Token

Access Token 授权访问特定资源服务器，应该短时、最小 scope、限制 audience。它是 bearer 时，泄露者通常能直接使用。资源服务器验证 Token 后仍执行对象与业务授权；scope 不是 FactoryCare 数据范围的替代品。客户端不把 Access Token 当长期用户档案，也不能假定刷新后内部 claims 永远相同。

Web BFF/服务端会话架构让浏览器不直接持有 Provider Access Token。若 Java 需要代用户调用下游资源，应在服务端受控的 authorized-client 存储里管理，前端只拿不透明会话 Cookie。FactoryCare 当前公共 API 的 Web 入口使用 `FACTORYCARE_SESSION`，移动入口才是 `mobileBearer`。

### 7.2 ID Token

ID Token 是 OP 给 RP 的认证声明。RP 必须验证签名、issuer、audience、过期和本流程要求的 nonce；`sub` 只在 issuer 命名空间内稳定。它可以支持建立本地登录，但不应该发给 FactoryCare API 当 Access Token，也不应被前端当可编辑的业务角色配置。

显示名称、头像、邮箱等资料可能来自 ID Token 或 UserInfo，却要明确更新策略和可信级别。`email_verified` 也不代表该邮箱与 FactoryCare 已有高权限账号可自动合并。身份关联是有审计、可回滚的业务操作。

### 7.3 Refresh Token

Refresh Token 只送授权服务器 token endpoint，用于换新 Access Token，通常寿命和影响都大于 Access Token。是否签发要基于客户端类型与风险。RFC 9700 要求公开客户端使用 sender-constrained refresh token 或 rotation 来发现重放；Refresh Token 还应绑定获批 scope 和资源服务器，并在长期不活动或安全事件后失效。

浏览器 JavaScript 不应持有 FactoryCare Web 的 Refresh Token。移动端只有在确需后台续期且平台安全能力满足时才保存；登出、账号解绑、设备丢失响应、应用数据清理与 rotation 重用检测都要纳入生命周期。把 Refresh Token 放 localStorage、普通 SQLite、URL、日志或崩溃报告均算泄露故障。

## 8. Discovery 是配置发现，不是信任发现

OIDC Discovery 可从可信 issuer 获取 authorization endpoint、token endpoint、jwks URI、支持的 claims/算法等元数据。起点 issuer 必须来自部署配置或受控选择，不来自请求参数、Token claim、邮箱域名拼接或用户提交 URL。否则攻击者可把客户端引到自己的端点，形成 SSRF、凭据外送或 mix-up。

客户端必须核对返回元数据中的 issuer 与配置 issuer 一致，并只用该 issuer 的端点和 keys。缓存和刷新要处理轮换、超时与短暂故障；发现失败应安全失败，不能退化为跳过验签、接受匿名管理员或使用上一次不明来源配置。

元数据宣称支持某算法不等于客户端必须接受全部算法。应用仍要设置预期算法和客户端认证方式。JWK 轮换、缓存 TTL、未知 `kid` 刷新属于 JWT 验证层；本章只强调 discovery 建立端点/issuer 边界，不重复实现 JOSE。

## 9. Spring Security 的协议行为与应用责任

Spring Security 的 `oauth2Login` 使用 Authorization Code Grant，并在 OIDC scope 存在时处理 OIDC 登录语义。Client Registration 描述 client ID、授权类型、redirect 模板、issuer/provider 等；通过 issuer 配置可进行 Provider 元数据发现。框架提供发起授权、保存授权请求、处理回调、调用 token endpoint、验证 OIDC 响应并构造 Authentication 的扩展点。

公开客户端的授权码支持可以启用 PKCE；具体自动条件、端点路径、repository、cookie/session 持久化和客户端认证行为会随版本与配置变化，必须用 Boot 4.1 管理的实际 Spring Security 版本做集成测试。不要因为 DSL 名称相似就假设 state、nonce、PKCE 与 redirect 已按项目威胁模型全部配置。

Spring Boot Starter Security 不替 FactoryCare 选择 Provider、注册 redirect、保护 secret、决定 Web BFF 与移动 bearer 边界，也不自动把外部 claims 映射成当前 membership。应用需要受控的 OIDC user service/认证成功处理：以 issuer+sub 查内部映射，拒绝禁用或无 membership 身份，建立最小内部主体。角色与数据范围来自数据库权威，不从客户端可编辑 claim 直接复制。

授权客户端保存 Access/Refresh Token 时要选择明确的服务端存储与加密策略。默认内存实现适合什么环境、集群如何共享、刷新并发如何处理、登出是否撤销 Provider grant，都需要单独验证。`oauth2Login()` 的成功页面出现不等于 Token 生命周期完工。

Spring Security 不是本章要自建的 Authorization Server。FactoryCare 的长期维护目标是消费外部 OIDC，而不是自己承担密码、MFA、同意页、客户端注册、Token 签发、撤销、密钥发布和安全响应的全部责任。

## 10. FactoryCare 的分客户端设计

### 10.1 Web：OIDC 后建立服务端 Session

浏览器访问受保护页面时，Java 发起 OIDC 授权事务，state/nonce/PKCE 等临时状态留在服务端会话或受控仓库。回调验证并映射成员后轮换 Session ID，设置 `FACTORYCARE_SESSION`。Vue 只通过同源 API 使用 Cookie；状态写请求还要发送 `X-CSRF-Token`。Provider Token 不进入前端状态管理、localStorage 或页面源码。

本地 `/api/v1/auth/login` 只是受控开发 Provider/会话入口，生产不能接受仓库静态密码，更不能在 OIDC 故障时启用万能账户。生产启动保护应拒绝危险适配器配置。

### 10.2 移动端：系统浏览器 + PKCE + 短时 bearer

Flutter 通过系统浏览器发起 Authorization Code + PKCE，回调由平台绑定的 URI 接收。每次授权生成新 verifier/state/nonce；Access Token 放平台安全存储并只发到受信 API origin。Refresh Token 是否保存与如何轮换，在实现周按 Provider 与平台能力验证。设备清理或退出要删除本地凭据并尽力撤销服务端授权。

小程序 Provider 桥接尚未选定，不能把“未来可能支持”写成已验证行为。无系统浏览器、回调或安全存储能力的平台，需要重新建模，不得把 client secret 写进包里补洞。

### 10.3 Java 每次重建业务主体

API 收到有效移动 Access Token，或收到有效 Web Session，都只得到认证起点。Java查询当前 `user_account`、tenant membership、角色绑定与 data scope。`FC-AUTH-001` 验证合法映射；`FC-AUTH-002` 验证签名/issuer/audience/时间错误在业务查询前失败；`FC-AUTH-003` 验证成员禁用后旧 Token 仍未过期也不能访问。

日志只写内部关联 ID、Provider 代号、稳定错误类别和脱敏主体引用。禁止完整 Token、code、cookie、state、nonce、verifier、Refresh Token、client secret 和完整 subject。

## 11. 错误合同与安全失败

发起阶段的配置错误、Provider 不可用、回调事务不匹配、Token endpoint 拒绝、ID Token 验证失败、内部成员不存在是不同诊断类别；对浏览器可返回一致且不泄密的登录失败页面，对 API 返回稳定认证问题。不能把 Provider 的原始错误正文、Token 响应或堆栈直接回显。

回调失败必须不建立 Session、不写已认证 SecurityContext、不创建未经审批的账号映射，并使可疑事务不可再次使用。若 code 已兑换但本地映射失败，也不能为了“避免浪费登录”创建匿名高权限或长期临时账号。

401 表示缺失、无效或过期的认证；已认证但无 FactoryCare 权限是 403；资源为了防枚举可按合同表现为 404。登录回调通常是浏览器导航，不应机械把所有错误都变成 JSON 401，但其底层原因和无副作用预言必须稳定。

## 12. 故障注入与第一处可信证据

### 12.1 缺失或错配 state

症状可能是用户被登录到攻击者账号，或任意回调可进入兑换。第一处可信证据不是最终用户名，而是“发起事务是否存在、回调 state 是否与该事务常量时间比较、是否已消费”。修复为一次性、短期、绑定会话的 state；重放同一回调必须红灯。

### 12.2 redirect URI 过宽

攻击者将回调改为相似子域、不同 path 或开放重定向目标，仍收到 code。第一处证据是注册表与授权请求中的精确 URI 对照。修复 Provider 注册与客户端配置，同时清除开放重定向；只改其中一侧会让合法流程失败或漏洞保留。

### 12.3 PKCE 未校验

错误 verifier 或完全缺 verifier 仍换到 Token，说明 token endpoint 或客户端流程没有绑定 challenge。第一处证据是发起事务保存的 challenge method/challenge 与兑换时 verifier 派生值的对照。客户端自身不能单元证明 Provider 真正强制，必须在集成环境执行负向兑换。

### 12.4 nonce 重放

来自另一登录事务的已签名 ID Token 被当前回调接受。签名验证绿灯不能覆盖事务绑定。第一处证据是当前事务预期 nonce 与已验证 ID Token nonce 的对照，以及事务一次性状态。修复后跨事务替换与同事务重放都应失败。

### 12.5 ID Token 调 API

API 接受 audience 指向客户端的 ID Token，通常意味着资源服务器只做“这是个签名 JWT”检查。第一处证据是 token profile、audience 与预期资源类型。修复为 Access Token 专用验证链和互斥类型规则，不能只给 ID Token 增加一个 scope。

### 12.6 Refresh Token 泄露

日志、前端状态或普通文件出现 Refresh Token。第一处证据是数据流：token endpoint 响应在哪里被解析、对象是否进入日志/序列化、存储接口是什么。修复包括删除泄露路径、轮换/撤销受影响 grant、日志清理与回归扫描，不能只做字符串掩码后继续把对象传给前端。

### 12.7 client secret 进入公开客户端

前端环境变量或移动包能提取 secret。第一处证据是构建产物而不是源 `.gitignore`。修复为把机密客户端操作移到服务端，公开客户端使用 PKCE；已经发布的 secret 必须轮换。给 secret 混淆、拆字符串或远程下发都不改变公开客户端无法保密的事实。

## 13. 可重放测试矩阵

| 场景 | 输入变化 | 预期 | 第一处预言 |
| --- | --- | --- | --- |
| 合法 OIDC 登录 | state/nonce/redirect/PKCE 全匹配 | 建立一次新本地会话 | 事务消费一次、Session ID 轮换 |
| state 缺失或错配 | 回调替换 state | 拒绝 | 不调用业务映射、不建 Session |
| nonce 来自旧事务 | 替换已验证 ID Token nonce | 拒绝 | 当前事务 nonce 比较失败 |
| redirect 相似但不相同 | 改 host/path/query | 拒绝 | 精确注册匹配失败 |
| verifier 错误 | code 正确，verifier 改一位 | token endpoint 拒绝 | 无 Token 返回 |
| code 重放 | 同 code 兑换第二次 | 拒绝 | code 一次性 |
| ID Token 调 API | Bearer 换成 ID Token | 401 | profile/audience 不符 |
| Access Token 当用户资料 | 客户端读取不稳定内部 claim | 不作为身份权威 | issuer+sub 的受控映射 |
| Refresh Token 暴露 | 序列化到前端或日志 | 测试失败并撤销 | 输出扫描命中 |
| 成员已禁用 | Provider Token 仍有效 | 401/合同化拒绝 | 当前 membership 查询失败 |
| Provider 不可用 | discovery/token endpoint 超时 | 安全失败 | 不退化为匿名或本地管理员 |

测试报告要记录合成事务 ID、输入类别、操作、HTTP/策略结果、业务副作用计数与修复后重跑。绝不把真实 Token 或 secret 放进报告。离线模型能证明比较逻辑；Provider 的 PKCE 强制、元数据发现、浏览器重定向和安全存储必须留待真实集成环境。

## 14. 标准、OWASP 与框架行为分层

| 来源层 | 本章采用的结论 | 不能误读为 |
| --- | --- | --- |
| OAuth 2.0 / RFC 9700 | redirect 精确匹配；授权码主线；公开客户端必须 PKCE；S256；保护 Refresh Token；限制 Access Token 权限 | 某个 SDK 默认配置必然满足全部 BCP |
| OIDC Core | `openid` 身份层；ID Token 给 RP；验证 issuer/audience/时间/nonce；issuer+sub 定位主体 | ID Token 可以访问任意 API，或 email 是永久业务主键 |
| OWASP OAuth2 建议 | 新实现使用 Authorization Code + PKCE，避免过时流程，保护 redirect、Token 与客户端边界 | OWASP 替代规范中的协议互操作细节 |
| Spring Security | 提供 OAuth2 Client/OIDC Login、授权请求仓库、回调、Token/ID Token 验证与扩展点 | 自动选择 FactoryCare Provider、成员映射、数据范围与 Token 存储策略 |
| FactoryCare 合同 | 外部 OIDC；Web 服务端 Session；移动 PKCE bearer；Java 重建当前 membership；日志不含秘密 | 本章要实现授权服务器或把角色固定进 Provider claim |

稳定核心是角色、Token 用途、事务绑定和公开/机密客户端边界。版本敏感面是 Spring DSL、默认端点、PKCE 自动启用条件、authorized-client 存储及 Provider 特性。本章版本登记于 2026-07-16/17 核对；进入真实实现仍需按当日 Boot 4.1 BOM 与 Provider 文档重验。

## 15. 独立构建任务

交付一张时序图和一份可执行验证报告。时序图至少包含 Browser/App、FactoryCare Client、OP authorization endpoint、token endpoint、FactoryCare API，并标出 state、nonce、challenge、code、verifier、ID/Access/Refresh Token 的流向。每个秘密标注“产生位置、允许存储、禁止输出、销毁时机”。

验证报告至少包含：合法流程；state 错、nonce 错、redirect 错、verifier 错；ID Token 误作 bearer；Refresh Token 输出；成员禁用。每项写明预期失败点，运行后记录第一处可信证据，再修复并重跑原断言。只看到最终 401 还不够，必须证明没有建立 Session、没有执行业务查询、没有输出秘密。

公开练习刻意保留 TODO 并首先以 state 缺失失败；私有答案满足相同接口并全绿。学习者应先预测哪个比较会失败，再改最小规则，不能直接复制答案后把绿灯当理解。

## 16. 120 秒讲述模板

可以按以下顺序讲，而不是背术语：

1. OAuth 是委托授权，OIDC 是建立在其上的身份层；
2. 授权码只送 token endpoint，Access Token 给资源服务器，ID Token 给客户端，Refresh Token 只用于刷新；
3. state 绑定回调事务，nonce 绑定 OIDC 认证响应，PKCE 绑定 code 与客户端实例；
4. redirect 必须精确注册，公开客户端不能保守静态 secret；
5. Spring 做协议机械工作，FactoryCare 仍用 issuer+sub 查询当前成员和权限；
6. 反例：API 只因 ID Token 验签通过就接受，攻击者完成 token substitution。

若不能说明“ID Token audience 为什么通常不是 API”或“错误 verifier 应在哪一跳失败”，说明仍停留在名词记忆，应回到时序与故障实验。

## 17. 资料与版本核对

- [RFC 9700：OAuth 2.0 Security Best Current Practice](https://www.rfc-editor.org/rfc/rfc9700.html)（标准/BCP，2026-07-17 核对）
- [OpenID Connect Core 1.0 incorporating errata set 2](https://openid.net/specs/openid-connect-core-1_0-errata2.html)（身份层标准，2026-07-17 核对）
- [OWASP OAuth2 Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/OAuth2_Cheat_Sheet.html)（实施建议，2026-07-17 核对）
- [Spring Security OAuth 2.0 Login](https://docs.spring.io/spring-security/reference/servlet/oauth2/login/)（框架行为，2026-07-17 核对）
- [Spring Security Authorization Grant Support](https://docs.spring.io/spring-security/reference/servlet/oauth2/client/authorization-grants.html)（PKCE 与客户端配置，2026-07-17 核对）
- [FactoryCare ADR-0003](../../../factorycare-design/adrs/0003-oidc-and-client-sessions.md)（项目决策基线）

## 18. 本章边界

本章不自建 Authorization Server，不选择具体企业 Provider，不实现 SCIM、SAML、MFA、设备证明、DPoP/mTLS、动态客户端注册或联合登出协议；这些不是“遗漏的几行配置”，而是各自独立的威胁模型和交付。本章也不教授 JWT 密码学细节、Session 全生命周期、RBAC/ABAC 或多租户数据过滤，它们分别由相邻章节负责。

本章完成意味着能解释、建模、负测并诊断安全客户端流程，不意味着真实 Provider 已接通。只有目标环境中的 redirect 注册、PKCE 负测、ID Token 验证、Token 存储、日志扫描、登出/撤销和成员禁用证据齐全，才能声称集成完成。
