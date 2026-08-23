# OAuth、JWT 与 OIDC：令牌、授权和第三方登录

## 1. 先把三个名字分开

这三个词经常一起出现，但不是同一种东西：

| 名称 | 它主要解决什么 |
| --- | --- |
| JWT | 用一种可签名的格式携带声明 |
| OAuth 2.0 | 让客户端获得有限权限去访问资源 |
| OpenID Connect（OIDC） | 在 OAuth 2.0 之上增加“用户是谁”的登录身份层 |

JWT 是一种 Token 格式；OAuth 是授权协议；OIDC 是身份协议。OAuth Token 不一定是 JWT，JWT 也不一定用于 OAuth。

## 2. 先认识 OAuth 中的四种角色

以“FactoryCare 网页通过统一身份平台读取工单 API”为例：

- **资源所有者（resource owner）**：通常是用户；
- **客户端（client）**：FactoryCare 网页或后端；
- **授权服务器（authorization server）**：负责登录、同意和发 Token；
- **资源服务器（resource server）**：持有工单 API，验证 Access Token。

```text
用户
  │ 使用
  ▼
FactoryCare 客户端 ──请求授权──▶ 授权服务器
  │                                  │
  └────带 Access Token 调用──────────┘
                  ▼
              工单 API
```

“登录服务器”和“API 服务器”可以由同一产品提供，也可以是不同服务，但职责仍要分清。

## 3. OAuth 的核心是委托有限权限

过去一种危险做法是：第三方应用直接索要用户在另一个系统的账号密码。OAuth 改为：

1. 用户在可信授权服务器上认证；
2. 用户或策略同意客户端获得有限范围；
3. 客户端得到有范围、受众和时限的 Access Token；
4. 客户端用它访问资源服务器，不得到用户原始密码。

这叫**委托授权**。Token 应只对指定资源、范围和时段有效，而不是一把永久万能钥匙。

## 4. Authorization Code 流程不把 Access Token 暴露在浏览器跳转中

当前常见交互式流程是 Authorization Code：

```text
1. 客户端把浏览器重定向到授权服务器
2. 用户登录并授权
3. 授权服务器把短期、一次性的 code 返回客户端回调地址
4. 客户端在 Token 端点用 code 换取 Token
5. 客户端带 Access Token 调 API
```

浏览器重定向中传回的是 authorization code，而不是把长期使用的 Access Token 直接放进 URL。code 应短期、一次性，并绑定客户端、回调地址和当前流程。

## 5. PKCE 防止截获授权码后直接兑换

公开客户端（浏览器单页应用、桌面或移动应用）无法可靠保守固定 client secret。PKCE 给每次登录生成新的随机秘密：

```text
客户端生成 code_verifier
  → 计算 code_challenge
  → 授权请求发送 challenge
  → 换 Token 时发送 verifier
  → 授权服务器验证二者匹配
```

攻击者即使截获 authorization code，没有原客户端保存的 `code_verifier` 也无法兑换。当前 OAuth 安全最佳实践要求公开客户端使用 PKCE，新系统不应把静态 secret 当作保护移动 App 或前端代码的秘密。

## 6. state 绑定发起请求和回调

客户端开始授权时生成不可预测的 `state`，回调时验证它是否与本次会话中保存的值一致。

它主要用来防止攻击者把自己发起的授权结果塞给受害者客户端，并帮助绑定流程上下文。不能只检查“回调里有 code”就接受。

```text
开始：保存 state=A，并把 A 发给授权服务器
回调：必须收到同一个 A；缺失或不匹配就拒绝
```

`state` 不应装入可被攻击者任意修改的敏感业务数据。若需要携带返回地址，应签名、服务端保存或严格验证允许范围。

## 7. redirect URI 必须精确约束

授权服务器会把 code 送到注册的回调地址。如果允许宽泛通配，攻击者可能构造一个自己控制的子路径或域名来接收 code。

因此要：

- 预先注册回调地址；
- 尽量精确匹配；
- 使用 HTTPS，开发环境例外也要明确；
- 不把任意请求参数直接拼成 redirect URI；
- 回调落地后尽快移除 URL 中的一次性信息。

安全流程中，“跳回哪里”也是凭据交付边界。

## 8. Access Token 是给资源服务器看的访问凭据

客户端调用 API 时常用：

```http
Authorization: Bearer eyJ...
```

Bearer 的意思接近“持有者即可使用”。它通常不要求请求者再证明自己拥有另一把密钥，所以 Token 泄露后可被重放。

应避免：

- 放在 URL query 中，被浏览历史、代理和日志复制；
- 写进应用日志和错误信息；
- 通过不受信渠道发送；
- 给过长有效期和过大 scope；
- 在多个不相关 API 间共用同一 audience。

HTTPS、短有效期、最小 scope、安全存储和泄露后的撤销/轮换共同降低风险。

## 9. JWT 由三段 Base64URL 文本组成

常见紧凑 JWT 形如：

```text
header.payload.signature
```

- header：算法、密钥标识等；
- payload：claims，也就是声明；
- signature：对前两段的签名验证材料。

Base64URL 只是编码，不是加密。任何拿到普通签名 JWT 的人通常都能解码 header 和 payload，所以其中不应放密码、隐私详情或内部秘密。

## 10. 签名证明内容未被篡改，不代表内容一定可接受

验证 JWT 不能只做 Base64 解码，也不能只验证“签名数学上正确”。资源服务器还应验证业务上下文：

| Claim | 要回答的问题 |
| --- | --- |
| `iss` | 是可信的哪个签发者发的？ |
| `aud` | 是否明确发给当前 API？ |
| `exp` | 是否已经过期？ |
| `nbf` | 是否还没到可使用时间？ |
| `sub` | 代表哪个主体？ |
| `jti` | 是否需要用唯一标识处理撤销或重放？ |

如果 API A 接受了只发给 API B 的 Token，即使签名有效，授权边界仍然错了。

## 11. 算法和密钥由服务器策略决定

JWT header 中可能声明算法和 `kid`，但服务器不能因此盲目接受任意算法。应配置允许算法、可信 issuer 和密钥来源。

非对称签名常见结构：

```text
授权服务器：用私钥签名
资源服务器：用公钥验证
```

资源服务器可以从可信 JWKS 地址取得轮换中的公钥，并按 `kid` 选择，但仍要验证来源、缓存和轮换失败策略。不要让不可信 Token 自己指定任意网络密钥地址。

## 12. JWT 并不自动“无状态”或更安全

JWT 可让资源服务器在本地验证多数声明，减少每次查 Session 的需要。但真实系统仍可能需要状态：

- 密钥和 JWKS 缓存；
- 用户冻结与权限变更；
- Token 撤销；
- Refresh Token 轮换；
- 登录设备管理；
- 风险控制和审计。

JWT 的代价是已签发 Token 在到期前不容易即时收回。可以使用短期 Access Token、撤销列表、Token introspection 或版本号等方式，但每种都会重新引入存储、延迟和一致性取舍。

## 13. Resource Server 负责严格验证 Access Token

Spring Security Resource Server 的职责可以概括为：

```text
读取 Authorization: Bearer
  → 解析 Token
  → 验签或 introspection
  → 检查 issuer / audience / 时间等
  → 把 claims 映射成 Authentication 和 authorities
  → 进入授权规则
```

项目不应自己写一个“拆三段再解 JSON”的 Filter 冒充验证。框架可以完成标准密码学和错误链，项目主要负责可信 issuer、audience、claim 映射和业务权限边界。

## 14. Scope 表示被委托的能力范围

例如：

```text
workorders.read
workorders.assign
devices.read
```

scope 应表达对资源的有限能力，不应直接等同系统全部角色。资源服务器需要把 scope 转换为适合本系统的 authority，再结合租户、资源归属和状态做授权。

```text
有 workorders.assign scope
  ≠ 可以分派所有租户的工单
```

Token 的粗粒度能力和本地对象级授权通常要一起使用。

## 15. Refresh Token 用来获取新的 Access Token

Access Token 适合较短有效期。为了不让用户频繁登录，客户端可能得到 Refresh Token，用它向授权服务器换新 Access Token。

Refresh Token 通常：

- 只发给适合的客户端；
- 不发送给资源 API；
- 有更高存储保护要求；
- 应支持轮换、撤销和异常重用检测；
- scope 不应在刷新时悄悄扩大。

Refresh Token 一旦泄露，攻击者可以持续换新访问凭据，所以“Access Token 很短”不能补救不安全的 Refresh Token 存储。

## 16. OIDC 在 OAuth 上增加身份信息

OAuth 本身回答“客户端被允许访问什么”，并不标准化“这个登录用户是谁”。OIDC 增加：

- `openid` scope；
- ID Token；
- UserInfo 等身份能力；
- 登录流程中的 `nonce` 等校验。

```text
OAuth Access Token → 给资源服务器授权访问
OIDC ID Token      → 给客户端说明本次认证身份
```

两种 Token 的接收者和用途不同。

## 17. ID Token 不是拿来随便调用业务 API 的

ID Token 的 audience 通常是客户端，内容说明用户在身份提供方完成了什么认证。资源 API 应接收为自己签发、audience 正确的 Access Token。

如果把 ID Token 当 Access Token：

- audience 可能不属于 API；
- scope/权限语义可能不存在；
- 生命周期和撤销方式不同；
- 资源服务器会把“身份说明”错误当成“访问授权”。

即使两者恰好都是 JWT，也不能因此互换。

## 18. nonce 防止客户端接受被重放的登录结果

OIDC 客户端为登录请求生成 `nonce`，授权服务器把它放进 ID Token，客户端验证一致。

```text
本次登录保存 nonce=N
  → 请求携带 N
  → ID Token 必须包含同一个 N
```

`state` 主要绑定授权请求和回调、防止流程被替换；`nonce` 主要把 ID Token 绑定到本次认证请求。二者有相关性但职责不同，不应互相省略。

## 19. 客户端类型决定什么秘密能被保护

- **保密客户端（confidential client）**：运行在可保护凭据的服务器环境，可以安全保存客户端认证材料；
- **公开客户端（public client）**：代码运行在用户设备或浏览器，不能把固定 secret 当秘密。

把 `client_secret` 编译进 JavaScript、APK 或桌面程序，不会让它成为真正秘密，用户和攻击者都能提取。公开客户端依赖 PKCE、精确回调等机制，而不是假装能够保守共享 secret。

## 20. 浏览器中的 Token 存放是架构取舍

单页应用把 Token 放在可被 JavaScript 读取的位置，会扩大 XSS 后的 Token 窃取风险；把认证放进 Cookie，又要认真处理 CSRF。

常见方案之一是 BFF（Backend for Frontend）：

```text
浏览器 ←安全 Session Cookie→ BFF ←Token→ API / 授权服务器
```

浏览器不直接持有长期 Token，BFF 负责 OAuth 客户端行为。代价是增加后端状态、部署和 CSRF 防护。没有一种存储位置自动消除全部风险，应按 XSS、CSRF、跨域、移动端和运维边界选择。

## 21. 新系统应避开已知风险较高的旧流程

当前 OAuth 安全最佳实践不建议新系统采用把 Access Token 直接放在授权响应 URL 中的 Implicit Flow，也不应使用要求客户端收集用户密码的 Resource Owner Password Credentials 流程。

推荐思路是：

- 交互登录使用 Authorization Code；
- 公开客户端使用 PKCE；
- 精确限制 redirect URI；
- 使用 `state`，OIDC 登录还验证 `nonce`；
- Token 只发送给预期接收者；
- 对 Refresh Token 做轮换或等效保护。

具体协议要求以实施时最新的 OAuth/OIDC 官方规范和身份平台文档为准。

## 22. Session 与 Token 不是简单的新旧之争

| 维度 | 服务端 Session | 自包含 Access Token |
| --- | --- | --- |
| 状态主要位置 | 服务端 | Token 携带部分声明 |
| 即时撤销 | 相对直接 | 通常需要额外设计 |
| 浏览器携带 | 常用 Cookie 自动携带 | 常用 Authorization header |
| 扩展到多个 API | 需要共享/集中 Session 或网关 | 本地验签较方便 |
| 权限陈旧 | Session 可重新加载 | 到期前可能保留旧声明 |
| 主要风险 | Session 劫持、CSRF | Token 泄露、错误受众、重放 |

内部单体管理后台使用 Session 可能更简单；多个独立 API 接受统一身份平台 Token 可能更合适。应从信任边界、撤销需求和客户端类型出发，不因“微服务”三个字自动选 JWT。

## 23. 排查 Token 失败要按验证链看

收到 401 时依次确认：

1. header 是否真的使用 Bearer scheme；
2. Token 是否被截断、放错位置或已过期；
3. issuer 是否与配置完全一致；
4. 签名算法和对应公钥是否允许；
5. `kid` 是否能在可信 JWKS 中找到；
6. audience 是否属于当前 API；
7. 时钟是否合理，是否误判 `exp` / `nbf`；
8. Token 验证成功后 claims 是否正确映射为权限。

不要在在线网站粘贴真实生产 Token 做调试，也不要通过关闭验签来“确认 payload 没问题”。

## 24. 验证授权流程要覆盖攻击路径

至少要证明：

- 错签名 Token 被拒绝；
- 错 issuer 和错 audience 被拒绝；
- 过期和尚未生效 Token 被拒绝；
- 缺少所需 scope 被拒绝；
- 授权回调缺少或错误 `state` 被拒绝；
- OIDC ID Token 的 `nonce` 不匹配被拒绝；
- authorization code 不能重复使用；
- 同一 redirect URI 不能被攻击者替换；
- ID Token 不能冒充 API Access Token；
- Refresh Token 异常重用有明确处理。

能解码一个成功 Token，只证明文本可读，不证明安全链正确。

## 25. 这篇的整体地图

```text
OAuth：客户端取得有限访问授权
  ├── Authorization Code：先拿一次性 code
  ├── PKCE：code 还要匹配本次客户端秘密
  ├── state：绑定发起流程和回调
  └── Access / Refresh Token：短期访问与续期

OIDC：在 OAuth 流程上增加登录身份
  ├── ID Token：给客户端说明认证身份
  └── nonce：绑定本次认证请求

JWT：某些 Token 使用的签名声明格式
  └── 验证签名 + iss + aud + exp + nbf + 业务权限
```

必须掌握：JWT 不是加密；签名有效不等于 Token 可用于当前 API；ID Token 和 Access Token 不能互换；Bearer Token 泄露后可重放；Authorization Code + PKCE、精确回调、state/nonce 是一整套边界。

JWK 字段、具体授权服务器配置键和所有扩展 grant 属于“需要时查询”，不必死记。
