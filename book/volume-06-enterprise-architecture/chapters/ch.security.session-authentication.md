---
schema_version: 2
edition: 2026.2-draft
id: ch.security.session-authentication
title: Spring Security 登录、退出、密码编码与 Session 防护
responsibility: 实现基于 Session 的认证生命周期和负向路径，不在本章混入 JWT 或 OAuth 客户端流程
volume: '06'
order: 7
level: L2
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.security.session-authentication.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.security.spring-security-architecture
- ch.spring.testing-testcontainers
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
  text: 在 120 秒内解释Spring Security 登录、退出、密码编码与 Session 防护的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - security-session-login
  - security-session-defense
  covers_topics:
  - security.spring-login
  - security.password-encoder
  - security.authentication-failure
  - security.logout-invalidation
  - security.session-fixation-protection
  - security.concurrent-session-boundary
  uses_capabilities:
  - security.web-threat
  - backend.spring-di-config
  - backend.spring-mvc-contract
  - security.authentication
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现账号密码哈希、一次性恢复/撤销、Spring Security登录退出、Session ID轮换，并覆盖凭据与Session完整生命周期，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - security-session-login
  - security-session-defense
  covers_topics:
  - security.spring-login
  - security.password-encoder
  - security.authentication-failure
  - security.logout-invalidation
  - security.session-fixation-protection
  - security.concurrent-session-boundary
  uses_capabilities:
  - security.web-threat
  - backend.spring-di-config
  - backend.spring-mvc-contract
  - security.authentication
  evidence_kind: system-artifact-and-negative-tests
  verification_mode: system-security-resilience-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入NoOp密码、恢复Token可重放、改密后旧Session有效、登录固定Session和账号枚举，执行攻击用例后修复
  covers_topic_groups:
  - security-session-login
  - security-session-defense
  covers_topics:
  - security.spring-login
  - security.password-encoder
  - security.authentication-failure
  - security.logout-invalidation
  - security.session-fixation-protection
  - security.concurrent-session-boundary
  uses_capabilities:
  - security.web-threat
  - backend.spring-di-config
  - backend.spring-mvc-contract
  - security.authentication
  evidence_kind: fault-injection-fix-rerun
  verification_mode: fault-injection-rerun
---
# Spring Security 登录、退出、密码编码与 Session 防护

> 本章状态为 `drafting`。配套代码只模拟密码记录元数据、固定时钟、一次性恢复授权和内存 Session，不计算或输出真实密码哈希、不启动 Spring/数据库/邮件服务，也不包含真实账号、Cookie 或恢复 Token。通过只能证明生命周期不变量；真实 `PasswordEncoder`、Servlet 容器、Session store 与 Testcontainers 集成仍需目标版本测试。

认证不是“用户名密码相等就返回成功”。一个完整 Session 认证生命周期从密码输入开始，经过安全存储与比较、统一失败、登录成功后的 Session ID 轮换、SecurityContext 保存、CSRF 保护、超时、并发会话策略、改密/恢复后的全局撤销，最后到服务端登出失效。只修其中一个点，旧凭据或旧 Session 仍可能绕过新规则。

FactoryCare 的生产基线是外部 OIDC；Web 在授权码流程完成后由 Java 建立服务端 Session。`/api/v1/auth/login` 只是受控本地身份适配器或会话入口，生产不能接受仓库里的静态密码。本章仍学习密码编码和本地登录，因为开发适配器、迁移、恢复和框架认证链都必须理解这些边界，但不会把自建账户系统升级成生产身份提供方。

## 1. 完成定义与证据入口

完成本章应能：

1. 画出登录请求 → Authentication Filter → AuthenticationManager/Provider → PasswordEncoder → SecurityContext → Session 的成功与失败路径；
2. 区分密码编码、加密和普通哈希，使用带唯一 salt 的自适应慢哈希并能迁移算法参数；
3. 让不存在账号、错误密码、禁用账号对外返回统一失败，同时保留不含秘密的内部分类；
4. 对恢复 Token 实现不可预测、只存摘要、限定用途、短期、一次性原子消费；
5. 登录成功轮换 Session ID；改密、恢复、成员禁用和登出使旧 Session 服务端失效；
6. 明确并发 Session 是“每主体多少个服务端会话”的策略，不是浏览器 tab 数；
7. 注入 NoOp 密码、恢复重放、旧 Session 有效、固定 ID 和账号枚举，得到稳定红灯并修复重跑。

配套入口：

- [认证生命周期示例](../../../examples/encyclopedia/ch.security.session-authentication/README.md)
- [Session 登录故障实验](../../../labs/encyclopedia/ch.security.session-authentication/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.security.session-authentication/README.md)

## 2. 登录链的职责分工

HTTP 请求到达认证 Filter 后，Filter 从受控位置读取凭据，构造尚未认证的 `Authentication`，交给 `AuthenticationManager`。常见 `ProviderManager` 遍历能处理该类型的 `AuthenticationProvider`；用户名密码 Provider 读取账号记录，并通过 `PasswordEncoder.matches(raw, encoded)` 比较。成功返回已认证对象，失败抛稳定认证异常。

成功处理还要通知 `SessionAuthenticationStrategy`、轮换 Session ID、建立新的 SecurityContext、按当前版本要求保存到 `SecurityContextRepository`，再写 Cookie/CSRF 等响应。失败处理清空临时上下文、调用 failure handler，不能创建已认证 Session。Filter、Provider、Encoder、Session 策略与响应 handler 是独立扩展点，不应全部塞进 Controller。

对 JSON 登录入口，可以使用合适的认证 converter/filter 或受控 Controller 调用 `AuthenticationManager`，但不能绕过成功路径的 Session 策略和 context 保存。自己在 Controller 中 `SecurityContextHolder.setContext` 后直接返回，常见后果是没有 fixation 防护、下一请求未持久化或凭据残留。

## 3. 密码不能解密回来

密码验证只需要回答“输入是否与存储记录匹配”，不需要恢复原文。因此密码应使用专门的单向、自适应、带 salt 的密码哈希。数据库泄露时，攻击者仍可离线猜测；慢且资源可调的算法让每次猜测更昂贵。通用快速哈希 SHA-256、MD5、可逆 AES 和 Base64 都不满足这个目标。

每条密码记录使用独立随机 salt，salt 可与编码结果一起存储，无需保密。算法、版本和参数也必须可识别，便于将来升级。可选 pepper 是独立于数据库、由密钥管理系统保护的额外秘密；引入后必须有轮换和灾难恢复方案，不能把 pepper 常量提交仓库。

验收所谓“强哈希”不是检查字符串以 `$` 开头，而是证明采用的 `PasswordEncoder`、算法参数、随机 salt、迁移策略和资源预算。教学资产只检查记录元数据，真实测试必须调用框架 Encoder 并证明相同密码两次编码不同、两者都能匹配、错误密码失败。

## 4. Spring PasswordEncoder 与版本迁移

Spring Security 的 `DelegatingPasswordEncoder` 使用 `{id}encodedPassword` 格式，根据 id 选择匹配算法，并用当前默认 id 编码新密码。它解决“旧记录仍需验证、新记录要用新算法、登录后可逐步升级”三件事。未知或缺失 id 默认可能抛错，迁移时应显式识别历史格式，而不是退回 NoOp。

`NoOpPasswordEncoder` 只比较原文，是本章必须注入的故障，不是开发环境便捷选项。即使测试账号也用受控 Provider/fixture 生成安全编码，避免配置误入生产。框架的默认 id 与参数会演进；项目把 Encoder bean 和迁移测试写清，不把某个博客的 cost 永久当标准答案。

登录成功后可用 `upgradeEncoding` 判断旧参数是否需要重编码：只有在本次原始密码已经成功验证时才有原文可重新编码。批量离线“升级哈希”不可行，因为单向哈希无法恢复密码。无法透明升级的账号在下次登录或恢复流程迁移。

## 5. 算法与工作因子如何选择

OWASP 当前优先建议 Argon2id，并给出最低参数基线；也给出 scrypt、bcrypt、PBKDF2 等在兼容/FIPS 条件下的建议。项目应依据部署 CPU/内存、并发登录量和拒绝服务风险实测，让单次验证足够昂贵但不拖垮服务。参数是可版本化配置，不是代码里散落的魔法数字。

不能通过截断用户密码来适配算法限制。允许长 passphrase、Unicode 和空格，设置防止资源滥用的合理最大字节数并明确编码。不要强制“大小写+数字+符号”组成规则或周期性无故改密；更有效的是长度、常见/泄露密码阻断、MFA、速率控制和风险触发的轮换。

密码比较使用 Encoder 提供的安全函数。不要自己把两个哈希转字符串后用普通逻辑做复杂分支。数据库、日志、trace、异常、指标 label 和测试快照都不记录 raw password 或完整编码结果。

## 6. 登录输入与传输边界

登录只在 HTTPS 上接收，限制 body 大小和 Content-Type。用户标识可按业务规则规范化，但密码是精确字节序列：不能无提示 trim、大小写转换或 Unicode 归一化，否则用户输入和密码管理器记录不一致。DTO 校验不回显密码，也不把整请求写入 debug 日志。

同一入口拒绝重复或冲突的凭据来源。例如既有 JSON password 又有 Basic header 时不要猜优先级。FactoryCare 的 Session 登录只读取受控 body；Bearer 属于另一条资源服务器链，不混进这里。

TLS 保护传输，不保护数据库存储；强哈希保护数据库泄露后的离线猜测，不保护钓鱼或客户端恶意脚本。每层有独立威胁。

## 7. 统一失败与账号枚举

若不存在账号返回 `ACCOUNT_NOT_FOUND`，错误密码返回 `BAD_PASSWORD`，禁用账号返回 `DISABLED`，攻击者可批量枚举有效身份。公开响应应保持相同 HTTP 状态、稳定 code、字段形状和大致可比的处理路径。对不存在账号仍执行一次 dummy password hash 比较，减少明显时间差；但网络、缓存和数据库噪声意味着“完全恒时”不能轻易宣称。

内部可以分类安全事件，用于运营和排错，但日志只记录脱敏账号标识/哈希、规则 ID、trace 和结果类别，不记录密码。用户登录后可得到更具体的账户状态；匿名攻击者不应得到存在性 oracle。

速率限制按多维度设计：来源、账号标识、设备/租户和全局预算。只锁账号会让攻击者对受害者发起拒绝服务；只限 IP 会误伤代理用户并可被分布式绕过。退避、验证码或 MFA 是风险策略，不能代替正确密码验证。

## 8. 成功登录的原子安全结果

密码匹配只是认证成功路径的一部分。服务端还应确认账号与当前 membership 启用、身份映射唯一、允许使用本入口；清除 `Authentication` 中不再需要的 credentials；执行 Session authentication strategy；建立并保存新 context；写安全 Cookie 与 CSRF Token；记录不含秘密的成功事件。

如果 Session ID 轮换或 context 保存失败，不能返回成功。否则客户端收到 204，却继续使用未轮换或未认证 Session。验证报告应记录前置匿名 ID 与后置认证 ID“是否不同”，不记录完整值。

FactoryCare 生产 OIDC 登录由外部 Provider 验证用户；本地适配器只允许明确 profile 和 synthetic fixture，启动保护确保生产配置无法使用仓库静态密码。无论凭据来自密码还是 OIDC，建立 Web Session 后都共享 fixation、CSRF、超时、登出和成员禁用不变量。

## 9. Session fixation 防护

攻击者若能预先获得或设置一个匿名 Session ID，再诱导受害者用同一 ID 登录，登录后若 ID 不变，攻击者就可能复用已升级的 Session。防线是在认证/权限提升成功时改变标识并使旧标识不可用。

在 Servlet 3.1+ 容器中，Spring Security 默认可用 `changeSessionId`；也支持创建新 Session 或迁移属性的策略。`none` 会关闭防护，不应使用。迁移属性要审查：匿名购物车可能保留，攻击者预置的安全敏感属性不能自动带入。真实默认与事件行为以目标 Spring Security/Servlet 版本测试为准。

断言包括：登录前 ID A；登录后 ID B 且 A≠B；A 再请求受保护资源得到 401；B 可用；日志与报告不打印 A/B。只看到响应 `Set-Cookie` 不够，还要服务端旧记录失效。

## 10. SecurityContext 持久化

Session ID 指向服务端状态，SecurityContext 是其中的认证状态。认证 Filter 成功后，根据当前 Spring Security 持久化模型把 context 保存到 `SecurityContextRepository`。现代配置可能要求显式保存；从旧版本复制“设置 holder 就自动保存”的代码会导致本请求看似成功、下一请求变匿名。

每次请求仍要重建 FactoryCare 当前 membership、角色与 data scope。把多月不变的权限完整冻结在 Session 中，会让成员禁用和权限撤销延迟到 Session 过期。可在 Session 保存稳定主体映射，但授权关键数据需版本/实时校验。

请求结束由安全链清理线程 holder；登出还要清理 repository 和 server Session。只清 ThreadLocal 不会使其他请求持有的 Session ID 失效。

## 11. 登出是服务端撤销操作

安全登出至少包括：验证 state-changing 请求的 CSRF；在服务端使当前 Session 失效；清除 SecurityContext/Repository；清理 remember-me/CSRF 状态；响应清除 Cookie。浏览器删除 Cookie 只是客户端提示，服务端记录仍有效就可被复制值重放。

Spring Security logout 支持用一组 `LogoutHandler` 完成这些动作。默认行为和路径可配置，API 通常使用 `POST /api/v1/auth/logout` 返回 204，而不是依赖页面重定向。`GET` 不应产生登出副作用；启用 CSRF 时 POST 带 Token。

删除 Cookie 时 name、Domain、Path、Secure/SameSite 需要与设置时一致。可选 `Clear-Site-Data` 是浏览器附加清理手段，不代替服务端 invalidation。多节点部署必须让所有节点都观察到撤销，而不是只删当前 JVM map。

## 12. 改密与恢复后的旧 Session

密码改变意味着旧认证证明不再可信。策略可以自动撤销全部 Session，或保留当前经过重新认证的 Session 并撤销其他 Session；选择必须明确并测试。FactoryCare 验收要求改密/恢复后旧凭据与旧 Session 均失效，因此使用 `credentialVersion`/`sessionVersion` 或集中 Session 删除实现。

每个 Session 记录创建时的 credential version。请求时版本与账号当前值不一致即 401。改密事务先保存新安全编码并递增版本，再撤销 Session；如果跨存储，需要可靠顺序和失败策略，不能新密码成功但旧 Session 永久有效。

成员禁用同样立即拒绝，即使 Session 未到期。Session 有效表示“标识和状态尚存在”，不等于业务成员仍启用。

## 13. 密码恢复授权的生命周期

恢复请求的公共响应对存在/不存在账号相同，并采用大致一致流程。若账号存在，生成高熵随机 Token，经侧信道发送；数据库只存 Token 摘要、purpose、account、expiresAt、consumedAt 和创建上下文。Token 不能等于用户 ID、时间戳或可预测 UUID 序列。

提交恢复时，先对输入 Token 求摘要并查询，检查 purpose、未消费、未过期、账号状态，再在一个原子事务中标记已消费并更新密码/credential version。并发提交只有一个成功。过期边界通常定义为 `now < expiresAt`；等于到期时拒绝。

成功后不自动登录，要求用户走正常认证；通知账号发生密码变化；撤销旧恢复授权和 Session。URL query 可能进入浏览器历史、Referer 和日志，因此页面尽快交换/清除 Token，服务端及监控禁止完整值。教学资产只使用不可输出的 synthetic marker。

## 14. 并发 Session 的真实含义

同一浏览器多个 tab 通常共享 Cookie，所以不等于多个 Session。并发控制统计的是同一主体的多个认证 Session，例如两台设备、两个浏览器 profile。策略有两类：达到上限时拒绝新登录，或让旧 Session 过期并接受新登录。哪种更符合现场运维要由产品和风险决定。

Spring Security 提供 maximum sessions 与 SessionRegistry 等组件，但多节点环境要共享权威状态并接收 Session 生命周期事件。单 JVM registry 在节点 B 不知道节点 A 的会话，不能宣称全局上限。浏览器异常关闭也不等于及时 logout，必须依赖 idle/absolute timeout 与存储清理。

账号共享本身不应靠并发限制“解决”。FactoryCare 每个技师/管理员使用独立身份；共享账号破坏审计。高风险角色可以更严格限制，并提供可见的会话列表与撤销操作。

## 15. 超时、锁定与恢复不是一回事

idle timeout 从最后活动计算，absolute timeout 从认证会话建立计算；到期由服务端拒绝。renewal/rotation 可缩短标识长期暴露窗口。超时返回未认证，不泄漏内部原因。高风险操作即使 Session 有效也可要求近期重新认证。

账号 lock 是认证尝试策略，Session invalidation 是已建立会话撤销，密码恢复是证明账号控制权的流程。三者状态机不同。错误登录不应自动使所有合法 Session 注销；恢复请求不应先锁定账号；解锁不能恢复已经撤销的 Session。

使用固定 `Clock` 测试到期边界，禁止 sleep。并发恢复使用事务/唯一约束测试，而不是顺序调用两次后声称无竞态。

## 16. FactoryCare API 合同映射

`POST /api/v1/auth/login` 是唯一无认证的受控本地会话入口，成功 204 并设置 `FACTORYCARE_SESSION` 与初始 `X-CSRF-Token`。`GET /api/v1/auth/me` 需要 Session 或 mobile bearer；`GET /api/v1/auth/csrf-token` 需要现有 browser Session；`POST /api/v1/auth/logout` 需要 Session+CSRF 并服务端失效。

Cookie 名来自现有 OpenAPI，不在本章擅自改为 `__Host-`；部署可评估契约迁移后采用前缀。属性仍要求 HttpOnly、Secure、明确 SameSite 和正确 Path/Domain。错误使用公共 `Problem`：无效/过期/禁用 Session 为 401；已认证但业务范围不足为 403；正文不暴露账号存在性或 session ID。

生产身份由 OIDC Provider 管理，密码恢复通常也由 Provider 承担。若本地开发 adapter 实现密码/恢复，本章全部控制仍适用，但它不是生产 fallback；Provider 故障时不能降级成共享管理员密码。

## 17. 验证报告应该记录什么

每条用例记录 case ID、固定输入类别、操作、HTTP/领域结果、服务端状态变化和是否有副作用。安全值只记录“present/different/revoked”，不记录 raw password、完整 hash、reset token、Cookie 或 CSRF Token。

推荐矩阵：

| 用例 | 预期 |
| --- | --- |
| 正确密码 | 统一成功，ID 轮换，新 Session 可用 |
| 错密码/不存在/禁用 | 相同公开 401 Problem，无认证 Session |
| 相同密码编码两次 | 编码不同，均可 matches |
| NoOp/快速哈希记录 | 配置/迁移测试失败 |
| 恢复 Token 首次 | 更新密码、消费 Token、撤销旧 Session |
| 恢复 Token 重放/到期 | 拒绝且密码不变 |
| 改密后旧 Session | 401 |
| logout 后旧 Cookie | 401，服务端记录已撤销 |
| 并发上限 | 按选定策略只有允许会话有效 |

## 18. 故障注入与第一处可信证据

| 故障 | 第一处可信偏差 | 修复 |
| --- | --- | --- |
| `NoOpPasswordEncoder` | 存储记录为原文/可逆类型 | 使用 DelegatingPasswordEncoder 和迁移测试 |
| reset Token 可重放 | 第二次消费仍成功 | 原子 `consumedAt`/条件更新 |
| 改密后旧 Session 有效 | credential version 不匹配仍 access | 版本校验和集中撤销 |
| 登录后沿用匿名 ID | preAuth 与 auth ID 相同 | 启用 Session fixation strategy |
| 不存在账号返回不同 code | 公开响应/路径出现差异 | 统一 failure handler + dummy compare |
| logout 只清 Cookie | server record 仍 AUTHENTICATED | Session/context/repository 服务端清理 |
| 多节点只清当前 map | 另一节点仍接受 | 共享权威 Session/撤销传播 |

先观察服务端状态与稳定 marker，不打印秘密“证明”漏洞。修复后用原请求和旧标识重跑，确认不是换了测试数据掩盖问题。

## 19. 常见错误

- 把 Base64、AES 或 SHA-256 当密码存储；
- 为方便 fixture 使用 NoOp，结果 profile 误进生产；
- 在日志打印 login DTO、encoded password 或完整 Cookie；
- 不存在用户立即返回，错误密码才做慢哈希，形成时间 oracle；
- 成功认证只设置 holder，不轮换 ID/保存 repository；
- 登出只删除浏览器 Cookie；
- 改密只更新 hash，不撤销旧 Session 与恢复 Token；
- 以 tab 数理解并发 Session；
- 单节点 registry 宣称多节点全局上限；
- 把 Provider 不可用降级为本地共享密码；
- 用 sleep 测超时、用顺序调用冒充并发原子性。

## 20. 120 秒口述模板

“密码用带独立 salt、可调成本的单向 PasswordEncoder 存储，DelegatingPasswordEncoder 用 `{id}` 支持旧格式验证和新格式升级，NoOp/快速哈希都失败。登录 Filter 把凭据交给 AuthenticationManager/Provider，公开失败对不存在账号、错密码、禁用账号统一；成功还必须轮换 Session ID、建立并保存 SecurityContext。恢复 Token 高熵、只存摘要、有 purpose/expiry，原子一次性消费；改密和恢复递增 credential version 并撤销旧 Session。登出是 POST+CSRF，服务端 invalidate Session/context/repository，再清 Cookie。并发会话按主体的服务端 Session 计，不是 tab。反例是改密只换 hash，旧 Session 仍然可用。”

## 21. 标准、OWASP 建议与框架行为

截至 2026-07-17：

- [NIST SP 800-63B Digital Identity Guidelines](https://pages.nist.gov/800-63-4/sp800-63b.html) 是认证器与密码策略的规范性公共指南；[RFC 6265](https://www.rfc-editor.org/rfc/rfc6265.html) 是已发布 Cookie 标准基线。它们不规定 Spring bean/DSL。
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)、[Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)、[Forgot Password](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html) 与 [Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) 是算法、统一失败、恢复与 Session 生命周期的工程建议，不是协议标准。
- [Spring Security Password Storage](https://docs.spring.io/spring-security/reference/features/authentication/password-storage.html)、[Authentication Architecture](https://docs.spring.io/spring-security/reference/servlet/authentication/architecture.html)、[Session Management](https://docs.spring.io/spring-security/reference/servlet/authentication/session-management.html) 与 [Logout](https://docs.spring.io/spring-security/reference/servlet/authentication/logout.html) 描述当前 DelegatingPasswordEncoder、认证成功/失败、fixation、持久化、并发和登出行为，属于版本相关框架文档。
- [Testcontainers for Java](https://java.testcontainers.org/) 是真实数据库/依赖集成工具入口。版本登记把它标为 Boot 4.1 BOM-compatible、`provisional`；本章不把离线模型冒充容器证据。

`versions/registry.yml` 要求 Spring Security 由 Boot 4.1 管理。算法参数、默认 Filter/Session 策略和 DSL 会演进；ID 轮换、旧 Session 不可复用、秘密不落日志和统一失败则是长期不变量。
