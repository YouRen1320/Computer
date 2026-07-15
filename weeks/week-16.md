# 第 16 周：Spring Security 认证、Session、JWT 与 OIDC

> 建议投入：16 小时（可在 15—18 小时内调整）

## 1. 本周定位

本周把 FactoryCare 从“能调用接口”升级为“能够证明调用者身份”。重点不是背注解或自制一套认证协议，而是理解 Spring Security 的请求链路、浏览器安全边界，以及 Session、JWT、OIDC 各自解决的问题。

FactoryCare 本周采用 **服务端 Session + HttpOnly Cookie** 保护同源 Web 管理端；JWT 资源服务器和 OIDC 登录先做到能解释、能验证示例，不同时维护三套生产认证。移动端认证方式留到 uni-app 阶段根据客户端约束单独决策。

## 2. 前置条件

- FactoryCare 已有 Spring Boot Web、MyBatis、PostgreSQL 和统一错误响应。
- 能使用 MockMvc/Testcontainers 验证接口成功与失败路径。
- 已掌握 HTTP 方法、Cookie、Header、状态码和基本事务边界。
- 开始前确认 Spring Boot 依赖由项目 BOM 统一管理，不手工混搭 Spring Security 小版本。

## 3. 学习目标

- 能画出 `SecurityFilterChain → AuthenticationManager → AuthenticationProvider → SecurityContext` 的认证链路。
- 能区分认证与授权，以及 401 与 403。
- 能比较 Session、JWT Bearer Token、OAuth 2.0 和 OIDC，不再把它们当作同一概念。
- 能实现安全的登录、退出、当前用户接口，并处理 CSRF、CORS、Session 固定攻击和 Cookie 属性。
- 能用自动化测试证明匿名、已登录、错误凭据、过期会话和 CSRF 失败行为。

## 4. 完整概念清单

### 4.1 Spring Security 请求链路

- Servlet Filter、`DelegatingFilterProxy`、`FilterChainProxy` 与 `SecurityFilterChain`。
- `Authentication` 在认证前后的含义，`principal`、`credentials`、`authorities`。
- `SecurityContextHolder` 的请求生命周期与线程边界；为什么不能把用户信息放进全局变量。
- `AuthenticationManager`、`ProviderManager`、`AuthenticationProvider`、`UserDetailsService` 的职责。
- `PasswordEncoder` 与自适应哈希；密码不加密存储、不记录明文日志。
- `ExceptionTranslationFilter`、`AuthenticationEntryPoint`、`AccessDeniedHandler`。

### 4.2 Session 与浏览器安全

- 服务端 Session、Session ID Cookie、登录态续期与退出失效。
- `HttpOnly`、`Secure`、`SameSite`、作用域、有效期和 HTTPS。
- Session fixation 防护、并发会话、超时和服务重启后的会话策略。
- Cookie 认证为什么需要 CSRF 防护；CSRF Token 与 XSS 是不同问题。
- CORS 预检、允许来源白名单、携带凭据；CORS 不是授权机制。
- 同源部署、反向代理和前后端分离开发环境的差异。

### 4.3 JWT、OAuth 2.0 与 OIDC

- JWT 的 Header、Claims、Signature；签名不等于加密。
- `iss`、`sub`、`aud`、`exp`、`nbf`、`jti` 的用途和校验责任。
- 对称密钥与非对称密钥、JWKS、密钥轮换和时钟偏差。
- Access Token 与 Refresh Token；短期令牌、撤销、重放和泄露风险。
- OAuth 2.0 的 Resource Owner、Client、Authorization Server、Resource Server。
- OIDC 在 OAuth 2.0 上增加身份层；ID Token 不能当作任意业务 API 的 Access Token。
- Authorization Code + PKCE 的适用场景；不实现已淘汰的 Password Grant。
- 浏览器本地存储 Token 的 XSS 风险；“用了 JWT”不等于“无状态且更安全”。

### 4.4 测试与可观测性

- 对登录成功、失败、退出、会话过期、匿名访问、CSRF 缺失分别断言。
- 日志只记录用户标识、结果、来源和关联 ID，不记录密码、Cookie 或完整 Token。
- 认证失败统一响应，但不泄露“账号存在/不存在”等可枚举信息。

## 5. 任务分配

| 任务 | 时间 | 结果 |
| --- | ---: | --- |
| 阅读认证架构并手绘请求链路 | 3h | 一张认证链路图和概念卡片 |
| Session、JWT、OIDC 对比实验 | 2.5h | 一份认证选型 ADR |
| FactoryCare 登录与安全配置 | 5h | 可运行的 Session 认证闭环 |
| 安全测试与故障排查 | 2.5h | 成功和错误路径测试 |
| 无 AI 训练 | 2h | 认证排错记录 |
| 南昌岗位采样与简历更新 | 1.5h | 岗位矩阵和项目表述 |

总计 16.5 小时。若只有 15 小时，压缩资料整理；若有 18 小时，增加 JWT Resource Server 最小验证，不扩展为自建授权服务器。

## 6. FactoryCare 项目增量

完成以下最小闭环：

- `POST /api/v1/auth/login`：验证账号密码，建立 Session；失败信息不可用于枚举账号。
- `POST /api/v1/auth/logout`：使当前 Session 失效。
- `GET /api/v1/auth/me`：返回稳定的用户 DTO，不返回密码哈希和内部安全字段。
- 设备、工单接口默认要求认证；健康检查等公开端点显式列入白名单。
- 为状态修改接口启用 CSRF 防护；前端能够取得并回传 Token。
- Cookie 在生产配置启用 `HttpOnly`、`Secure` 和合适的 `SameSite`。
- 使用 Flyway 或当前迁移机制增加用户凭据字段，演示账号密码使用自适应哈希生成。
- 新增 `ADR-013-authentication.md`：说明为何当前 Web 端选择 Session、何时才切换 OIDC/JWT、移动端仍待决策。
- 至少覆盖 8 个安全测试：匿名、成功登录、错误密码、受保护资源、缺失 CSRF、有效 CSRF、退出、会话失效。

## 7. AI 协作边界

AI 可以：

- 根据你画出的认证链路检查遗漏。
- 生成测试场景清单和 MockMvc 测试骨架。
- 对 `SecurityFilterChain` 做逐项解释，寻找过宽的匹配规则。
- 比较 Session 与 JWT 方案，但必须列出威胁模型和运维成本。

AI 不可以替你决定：

- 哪些端点公开、Cookie/CORS 的生产域名和信任边界。
- 密钥、密码、Token 和真实账号的生成或保存方式。
- 关闭 CSRF、允许任意 Origin 或使用明文密码等“为了跑通”的捷径。
- 认证方案最终选型和验收结论。

每次接受 AI 修改后，必须逐行检查路径匹配顺序，并重新运行全部安全测试。

## 8. 无 AI 训练

本周从求职/复盘时段预留45—60分钟完成并记录：贪心基础题；给出选择依据、反例与复杂度。

关闭 AI 120 分钟：给定一个故意损坏的安全配置，定位并修复三个问题——匿名端点误受保护、登录成功仍返回403、POST因CSRF失败。要求：

- 先画过滤器链和请求状态，不靠反复删除配置试错。
- 用日志与单个最小测试缩小范围。
- 最后口述 401、403、CORS、CSRF 的区别，并说明为何不能简单 `csrf.disable()`。

## 9. 求职动作（恢复求职后启用）

- 从南昌当周 Java、Java 全栈和信息化岗位中采样 8 个 JD，统计 Spring Security、JWT、RBAC、单点登录、OAuth2 的出现方式。
- 把“熟悉 JWT”改写成可验证表述：`实现 Session 认证、CSRF 防护及 8 条安全集成测试；能说明 JWT/OIDC 适用边界`。
- 准备 3 分钟回答：公司为什么可能选择 Session，而不是 JWT？
- 对 Vue 岗继续投递，不等待后端路线学完；本周至少完成 5 次高匹配投递或跟进。

## 10. 本周交付物

- 认证链路图和 Session/JWT/OIDC 对比表。
- `ADR-013-authentication.md`。
- FactoryCare 登录、退出、当前用户接口与安全配置。
- 不少于 8 条认证/CSRF 自动化测试。
- 一份无 AI 排错记录和一条可写进简历的项目证据。

## 11. 验收标准

- 不看资料解释完整认证链路，并说清认证与授权的边界。
- 匿名访问受保护接口返回 401，已认证但无权限的场景预留为 403，而不是一律返回 500。
- Cookie 认证的状态修改请求不能绕过 CSRF；CORS 不使用通配符配合凭据。
- 数据库没有明文密码，日志没有密码、Cookie 或完整 Token。
- 8 条以上测试稳定通过，且至少一半覆盖失败路径。
- 能说明 JWT 的签名、过期、撤销和密钥轮换问题，以及 OIDC 与 OAuth 2.0 的区别。
- 本周代码、ADR、测试和岗位矩阵均可由他人复现或审阅。

## 12. 明确不做

- 不自研 OAuth 2.0/OIDC 授权服务器。
- 不同时把 Session、JWT、OIDC 三套方案投入 FactoryCare 生产路径。
- 不使用已淘汰的 Password Grant，不把 ID Token 当业务 Access Token。
- 不为了前后端联调关闭 CSRF、允许所有 Origin 或把 Token 永久放在 `localStorage`。
- 不在本周实现 RBAC、租户数据权限和完整审计；这些属于第 17 周。

## 13. 官方资料

- [Spring Security Servlet 架构](https://docs.spring.io/spring-security/reference/servlet/architecture.html)
- [Spring Security 认证](https://docs.spring.io/spring-security/reference/servlet/authentication/index.html)
- [Spring Security Session 管理](https://docs.spring.io/spring-security/reference/servlet/authentication/session-management.html)
- [Spring Security CSRF](https://docs.spring.io/spring-security/reference/servlet/exploits/csrf.html)
- [OAuth 2.0 Resource Server JWT](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html)
- [OAuth 2.0 Login 与 OIDC](https://docs.spring.io/spring-security/reference/servlet/oauth2/login/index.html)
- [Spring Security 测试支持](https://docs.spring.io/spring-security/reference/servlet/test/index.html)
