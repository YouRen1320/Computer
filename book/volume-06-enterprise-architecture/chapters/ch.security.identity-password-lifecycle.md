---
schema_version: 2
edition: 2026.2-draft
id: ch.security.identity-password-lifecycle
title: 身份、密码哈希、凭据生命周期与恢复边界
responsibility: 教授身份与凭据从创建到撤销恢复的安全生命周期，不在本章实现 Cookie Session 或 OAuth
volume: '06'
order: 2
level: L2
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.security.identity-password-lifecycle.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-oop.business-value-types
- ch.foundations.api-contract-basics
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
  text: 在 120 秒内解释身份、密码哈希、凭据生命周期与恢复边界的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - security-identity-password
  - security-credential-lifecycle
  covers_topics:
  - security.identity-account
  - security.password-hash-salt
  - security.password-policy
  - security.credential-issuance-rotation
  - security.account-recovery
  - security.credential-revocation
  uses_capabilities:
  - foundation.http-message
  - foundation.verification-debug-test
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 设计账号注册、密码哈希验证、失败限速、重置一次性凭据、会话撤销和管理员恢复的状态/数据合同，并生成记录输入、操作与结果的验证报告
  covers_topic_groups:
  - security-identity-password
  - security-credential-lifecycle
  covers_topics:
  - security.identity-account
  - security.password-hash-salt
  - security.password-policy
  - security.credential-issuance-rotation
  - security.account-recovery
  - security.credential-revocation
  uses_capabilities:
  - foundation.http-message
  - foundation.verification-debug-test
  evidence_kind: runnable-code-and-unit-tests
  verification_mode: language-unit-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入明文/可逆密码、重置 Token 可重放和改密后旧凭据仍有效，使用哈希/状态测试修复
  covers_topic_groups:
  - security-identity-password
  - security-credential-lifecycle
  covers_topics:
  - security.identity-account
  - security.password-hash-salt
  - security.password-policy
  - security.credential-issuance-rotation
  - security.account-recovery
  - security.credential-revocation
  uses_capabilities:
  - foundation.http-message
  - foundation.verification-debug-test
  evidence_kind: failing-test-fix-rerun
  verification_mode: failing-test-rerun
---
# 身份、密码哈希、凭据生命周期与恢复边界

> 本章状态为 `drafting`。配套代码是纯离线、虚构数据上的生命周期模型，不是 FactoryCare 生产登录组件。仓库源代码中的训练口令、Token 与 pepper 都显式标记为 synthetic；验证输出不会打印它们，也不得替换成真实秘密。

安全认证不是“有一张 users 表再比较字符串”。身份、账号、认证器、凭据和会话有不同生命周期；注册、验证、登录、改密、重置、MFA 变更、冻结、撤销和管理员恢复都是高风险状态迁移。只保护登录入口，却允许重置 Token 重放或客服绕过 MFA，攻击者会选择更弱的恢复路径。

本章建立从创建到撤销的合同：哪些状态可迁移、哪些秘密可存、哪些公开响应必须一致、哪些旧凭据必须失效、哪些事件必须审计。Cookie Session 和 OAuth/OIDC 协议实现留给后续章节；这里仅规定它们需要消费的撤销信号和边界。官方资料复核日期为 **2026-07-17**。

## 1. FactoryCare 的生产边界先说清

FactoryCare 的[身份 ADR](../../../factorycare-design/adrs/0003-oidc-and-client-sessions.md)已经接受以下生产基线：外部 OIDC 身份提供者负责密码恢复、MFA 和 Token 签发；Java 以稳定的 issuer + subject 映射本地 `user_account`，再读取当前成员关系、角色和数据范围。生产环境不能接受仓库静态密码，也不应在业务服务里自建密码恢复和 MFA。

因此，本章的本地密码代码是**教学模型**：它让学习者看见盐、pepper、工作因子、一次性 Token、枚举保护和撤销不变量。它不能被复制为生产身份提供者。若项目未来要改变“外部 IdP”决策，那是架构、安全运营、迁移和合规共同参与的重大变更，需要新 ADR、威胁模型和专门评审。

## 2. 完成定义与证据入口

完成本章应能：

1. 区分现实主体、数字身份、账号、登录标识、principal、认证器、凭据、因素和会话；
2. 设计注册、验证、激活、暂停、恢复、撤销和删除的显式状态机；
3. 解释密码为何使用慢速、自适应、单向方案，并正确区分 hash、salt、pepper 和工作因子；
4. 按当前 NIST/OWASP 基线制定长度、blocklist、粘贴/密码管理器、轮换与限速策略；
5. 让重置/验证凭据随机、足够长、存储安全、短期、一次性并绑定账号与目的；
6. 设计临时限速/锁定而不制造永久账号拒绝服务，公开响应不泄露账号是否存在；
7. 对密码/MFA 变更、管理员恢复和撤销产生不含秘密的审计事件；
8. 注入明文/可逆存储、盐复用、Token 重放和改密后旧凭据仍有效，修复并重跑原测试。

配套入口：

- [密码存储边界示例](../../../examples/encyclopedia/ch.security.identity-password-lifecycle/README.md)
- [凭据生命周期与恢复实验](../../../labs/encyclopedia/ch.security.identity-password-lifecycle/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.security.identity-password-lifecycle/README.md)

离线通过仅证明教学状态机的明示不变量，不证明真实 IdP、邮件、MFA、会话存储、密钥管理或组织恢复流程已经安全。

## 3. 先把身份词汇拆开

| 概念 | 含义 | 不等于 |
| --- | --- | --- |
| 现实主体 subject | 人、组织、设备或服务本身 | 一行数据库记录 |
| 数字身份 digital identity | 某数字服务上下文中主体的表示 | 必然对应法定实名 |
| 身份校验 identity proofing | 建立现实主体与数字身份之间的可信绑定 | 登录时验证密码 |
| 账号 account | 服务内保存状态、标识和关联的记录 | 密码或 session |
| 登录标识 identifier | 邮箱、用户名等用于查找账号的值 | 认证证据；常常可公开 |
| principal | 当前安全上下文中代表主体的对象 | 永久账号事实 |
| 认证器 authenticator | 主体持有/控制、用于证明身份的东西 | 账号本身 |
| 凭据 credential | 系统签发或绑定、支持认证/授权的材料或记录 | 任何用户字段 |
| 因素 factor | 知识、持有、生物特征等独立类别 | 两个密码不构成两因素 |
| 会话 session | 一次认证后维持连续交互的临时状态 | 永久身份；也不是本章实现范围 |

同一个人可有多个账号，一个服务账号可能不对应自然人；邮箱验证只证明当时能控制邮箱，不自动证明法定身份。登录标识可变，而内部账号 ID 应稳定。把邮箱直接当主键，会让改邮箱、合并账号、隐私删除和审计关联变得困难。

认证 AuthN 回答“当前声明由谁控制”；授权 AuthZ 回答“当前主体能对这个对象做什么”。认证成功不是全局通行证。FactoryCare 即使接受外部 IdP 的有效声明，也必须重新检查本地账号状态、当前租户成员关系、角色和数据范围。

## 4. 账号与凭据要有独立状态机

可从以下账号状态开始：

```text
INVITED/PENDING_VERIFICATION --verify--> ACTIVE
ACTIVE --risk/admin action--> SUSPENDED
ACTIVE --recovery request--> ACTIVE + RECOVERY_PENDING 子状态/凭据
SUSPENDED --approved recovery--> ACTIVE
ACTIVE|SUSPENDED --deprovision--> DISABLED
DISABLED --retention workflow--> DELETED/ANONYMIZED
```

恢复请求不应立刻锁定或修改账号；攻击者只要知道邮箱就能发请求，若请求本身改变状态，会制造拒绝服务。重置 Token 是独立的短期凭据，其状态可以是 ISSUED、CONSUMED、EXPIRED、REVOKED。账号仍 ACTIVE，不代表所有凭据有效；凭据版本、认证器状态和会话状态需要单独判断。

状态迁移合同包含：前置状态、操作者、所需证明、输入、原子写入、发出的撤销/通知事件、审计和幂等语义。不能只在 UI 隐藏按钮；后端必须拒绝非法迁移。删除/停用账号时应撤销认证器与会话，停止新通知，并按保留政策处理审计和业务记录。

建议为密码/MFA 等认证器记录：`credential_id`、`account_id`、类型、状态、创建/最后使用/撤销时间、算法与参数版本、凭据版本、失败计数或风险状态。不要在同一个 `password` 字段里混合明文、旧哈希、新哈希和重置 Token。

## 5. 注册、邀请与验证

注册流程至少分开：收集标识 → 规范化与唯一性判断 → 创建待验证账号或邀请 → 通过独立信道发送验证凭据 → 验证一次性凭据 → 激活。公开接口必须决定是否允许自助注册、由管理员邀请，或只由企业 IdP 预配；不同产品边界不能混成一个默认。

邮箱/手机号的规范化要谨慎。大小写、Unicode、别名和供应商规则很复杂，不要擅自改写为另一个地址。系统可以保存原始展示值和经过明确规则的查找键；唯一性约束应在数据库内原子执行，不能只“先查再插”。冲突响应还需考虑账号枚举。

验证 Token 应：

- 由加密安全随机源生成并有足够搜索空间；
- 只向目标信道返回原值一次，服务端存摘要或受保护形式；
- 绑定账号、目的、签发时间和过期时间；
- 使用后原子标记 consumed，重复请求得到稳定失败；
- 新发 Token 撤销或明确管理旧 Token；
- 不在日志、分析参数、Referrer 或错误页面泄露；
- 限制请求和猜测速率。

验证邮箱控制权不是实名身份校验。若业务需要更高身份保证，应建立独立 proofing 流程和证据，不可把“点过邮件链接”写成 KYC 完成。

## 6. 密码是“记忆秘密”，不是身份本身

密码可能被用户选择、记录或由密码管理器生成。服务器验证密码，只证明当前请求者掌握该秘密；密码可共享、钓鱼、复用、泄露或被恶意软件读取。密码不是抗钓鱼认证器，也不能证明现实身份。

传输密码必须通过经认证的受保护通道；客户端散列后再发送不会把它变安全，因为那个散列值本身会变成可重放的等价密码。服务器还要防日志、APM、异常和请求转储捕获正文。密码字段只在最短边界存在，使用 `char[]` 等可擦除容器能减少不可控副本，但 JVM 中仍不能承诺瞬间从所有内存副本消失。

禁止：明文存储；可逆加密后当密码库；无盐 SHA-256/MD5 等快速摘要；固定全局盐；把 pepper 和数据库放在同一备份；在日志输出候选密码或完整 hash。快速 SHA-256 可用于高熵随机 Token 的服务端查找摘要，但不适合低熵、人选密码，因为攻击者可以高速猜测。

## 7. 当前密码策略基线

NIST SP 800-63B-4 于 2025-08-26 发布，适用范围是美国联邦数字身份技术要求；其他项目只有在组织采纳时才具有规范性。本章把它与 OWASP 当前建议作为工程基线，不把它误写成全球法律。

对于由服务器集中验证的密码，当前 NIST 基线包括：

- 单因素密码最少 **15 个字符**；仅作为多因素流程一部分时最少 **8 个字符**；
- 最大长度应至少允许 **64 个字符**；不静默截断，验证完整密码；
- 不强制大写/小写/数字/符号组合规则；
- 创建或修改时把完整候选值与常见、预期或已泄露值 blocklist 比较；
- 不做任意周期轮换；有泄露证据时强制更换；
- 允许密码管理器、自动填充和粘贴；
- 不使用安全问题/知识问答作为密码选择或恢复依据；
- 失败尝试必须限速。

长度按 Unicode code point 还是 UTF-16 code unit 计算必须明确；NIST 要求接受 Unicode 时每个 code point 算一个字符，并建议哈希前使用 NFC 稳定化。系统若支持 Unicode，应让前后端、迁移工具和 IdP 保持一致，不能一端规范化、另一端不规范化。

blocklist 是拒绝最可能被猜中的完整候选密码，不是把词典中任何子串都禁掉。过度庞大或模糊的规则会逼用户做可预测变体。密码强度条可以提供建议，但不要把不可验证的“熵位数”承诺给用户。

## 8. Hash、salt、工作因子与 pepper

密码存储方案的目标不是让 hash “无法破解”，而是让数据库泄露后的每次离线猜测足够昂贵，并支持未来升级。

**Hash/密码派生函数**是单向、自适应且故意昂贵的验证过程。输入候选密码、salt 和成本参数，输出 verifier。登录时重新计算并用常量时间比较，不解密原密码。

**Salt**是每个密码记录独有的随机非秘密值。它阻止相同密码产生相同记录，也让预计算表不能跨所有账号复用。salt 与 verifier 一起存数据库是正常设计。NIST 要求 salt 至少 32 bits 并尽量避免碰撞；现代工程通常使用更长随机 salt，本章离线资产使用 128 bits。

**工作因子**控制 CPU、内存或并行成本。应在目标硬件上测量，在可接受登录延迟与拒绝服务容量内尽量提高，并随硬件演进升级。参数属于记录格式的一部分；登录成功时可检测旧参数并 rehash，批量迁移要考虑用户尚未登录和容量冲击。

**Pepper**是可选的额外服务器秘密，所有或一批记录共享，但必须与密码数据库分离，最好由 HSM/secret manager 控制。可在派生前后做受审查的 keyed operation。pepper 不能替代独有 salt，也不能修复快速 hash；pepper 泄露或轮换通常要求用户重新设置或在验证时迁移，因此必须设计 `pepper_id`、访问审计和恢复方案。

当前 OWASP Password Storage Cheat Sheet 的最低建议为：优先 Argon2id（至少 19 MiB、2 次迭代、并行度 1）；不可用时 scrypt（N=2^17、r=8、p=1）；遗留 bcrypt 成本至少 10 且注意 72-byte 输入限制；需要 FIPS-140 场景时 PBKDF2-HMAC-SHA-256 至少 600,000 次。参数会变化，必须以采用时官方页面和环境基准为准。

本章纯 JDK 25 资产为了离线、无第三方依赖地展示机制，采用 PBKDF2-HMAC-SHA-256 600,000 次、128-bit salt，并在派生结果上做 HMAC-SHA-256 pepper。它体现 OWASP 的 FIPS-oriented PBKDF2 下限，**不表示 FactoryCare 需要 FIPS，也不表示所有生产系统都应优先 PBKDF2**。真实 IdP 应使用其受支持、经评审的现代方案和参数。

## 9. 记录格式与算法迁移

一个密码记录至少要能表达：算法 ID、参数/成本、salt、verifier、pepper 版本、创建时间和凭据版本。不要靠代码当前默认值猜旧记录。Spring Security 的 `DelegatingPasswordEncoder` 使用 `{id}encodedPassword` 形式选择 encoder，目的之一就是支持当前编码和历史验证；官方文档也明确 `NoOpPasswordEncoder` 不安全。

迁移策略常见为“验证时升级”：旧记录用其旧参数验证成功后，用当前方案和新 salt 重新编码，再原子替换。需要考虑并发登录、数据库写失败、pepper 不可用和回滚。新默认上线前先验证旧 ID 都有 reader；否则用户会被集体锁出。

算法名称不是秘密。隐藏 `{argon2}` 或参数不能提供安全性；真正需要保护的是密码、pepper 和其他密钥。存储格式公开反而让审计与迁移更可靠。

## 10. 验证、公开响应与枚举保护

登录内部需要区分“账号不存在、账号暂停、密码错误、认证器已撤销”等原因以便审计和运营；公开响应通常应保持相同语义、状态码和近似处理路径，避免攻击者枚举账号。只把正文改成“用户名或密码错误”还不够：HTTP 状态、重定向 URL、响应长度、缓存行为和明显时间差都可能泄露。

不存在账号时不能简单立即返回，而存在账号时运行昂贵 hash；可使用固定的 dummy verifier 执行同类成本，再返回统一结果。这里的目标是减少可利用差异，不可能在通用 JVM/网络上证明每次纳秒相等。测试可断言公开合同一致，时序则需在受控环境统计测量。

哈希比较使用经过评审的库或常量时间函数，如 Java 的 `MessageDigest.isEqual`；不要自行逐字节遇到首个不同就返回。即使比较安全，账号查找、状态判断和外部调用仍可能造成侧信道。

注册与忘记密码同样要防枚举。可返回“如果该标识符合条件，我们会发送后续指引”，并让不存在账号也走受控的异步/等价路径。内部审计仍要记录真实结果，但日志访问受限且不返回客户端。

## 11. 失败限速、临时锁定与自动化攻击

在线攻击包括：对一个账号尝试大量密码的 brute force；把泄露的用户名/密码对试到本站的 credential stuffing；用一个常见密码试大量账号的 password spraying。只按 IP 限制会被分布式来源绕过，也会误伤共享出口；只按账号永久锁定则允许攻击者锁死任意已知账号。

应组合：

- 账号/认证器维度连续失败计数和递增等待；
- 来源、设备、网络和全局速率信号；
- 成功后按策略重置或衰减计数；
- 对异常模式的指标、审计和告警；
- 风险升高时 step-up 或 bot challenge；
- 用户可用的替代认证器和安全恢复；
- 对高权限账号更强、但不泄露存在性的保护。

NIST SP 800-63B-4 对特定认证器要求不超过 100 次连续失败的上限，并允许组织采用更低上限和递增等待等措施。**100 不是推荐所有网站都放行 100 次**，也不是单一防线；实际阈值需基于认证器类型、风险、误伤和恢复能力设计。

“锁定”最好是可解释的临时状态或认证器禁用，不要用一个没有来源和过期时间的布尔值。限速存储自身也可能被竞争、绕过或耗尽，应测试并发原子性、节点共享、时钟和故障时的安全默认。

## 12. MFA：多个独立因素与更弱的恢复问题

MFA 要求不同因素类别，例如“知道的密码”加“持有的硬件/密钥”。密码加 PIN 仍是两个知识秘密，不构成 MFA。常见认证器包括 WebAuthn/FIDO2/passkey、安全密钥、认证器应用的一次性码、推送和短信；其抗钓鱼、设备绑定、可恢复性与运营风险不同。高风险场景应优先抗钓鱼认证器，不能只在 UI 显示“MFA 已开启”。

生命周期比登录更难：注册新因素、替换手机、丢失设备、恢复码、同步凭据、撤销旧因素和管理员重置都可能成为账号接管路径。更改 MFA 因素应要求已有因素重新认证，而不是仅凭活跃 session；把它视为高风险动作，结合新设备/位置等信号，并通过带外渠道通知用户。

恢复码本身是认证器：随机生成、只显示一次、服务端安全存储、每个码一次性、可撤销并记录使用。不能把安全问题当“第二因素”。客服人工恢复要使用与账号价值匹配的独立证据、双人审批或冷却期，且不能让客服看到密码或直接指定永久凭据。

FactoryCare 生产 MFA 由外部 IdP 负责；Java 业务端仍需处理“IdP 账号被停用、本地成员被删除、高权限操作要求更高保证”等边界，但不能偷偷另建一套本地 MFA 真相。

## 13. 修改密码与凭据轮换

主动修改密码与忘记密码是不同流程。已登录修改通常要求重新认证当前密码或合适因素，验证新密码策略，写入新 hash/salt，递增凭据版本，撤销或提示撤销其他会话，并通知用户。仅凭一个长期活跃 session 改密码，session 被劫持时会帮助攻击者永久接管。

“轮换”应由风险事件驱动：泄露证据、认证器丢失、算法/参数迁移、权限或人员变化。任意按 30/60/90 天强制更换会促使可预测变体，当前 NIST/OWASP 不建议无证据周期轮换。服务凭据可能有不同自动轮换策略，但它们不是人类密码，需单独建模。

改密后“旧凭据失效”至少包含：旧密码无法验证；未使用 reset/verification Token 按策略撤销；旧 session/refresh 能力通过版本或撤销事件失效；缓存不得继续接受旧状态。若某些可信设备继续保留，必须是显式产品决策并写入威胁模型，不可因实现方便沉默保留。

密码变更与会话撤销跨多个存储，可能无法单事务完成。可用凭据版本和可靠事件传播：每次认证/敏感操作比较当前版本，outbox 发布撤销事件，下游幂等消费。具体 Cookie/Token 实现属于后续章节，本章只定义必须观察的失效合同。

## 14. 忘记密码与一次性重置 Token

安全流程分为请求与消费：

1. 客户端提交登录标识；
2. 服务对存在/不存在账号返回一致公开响应，执行限速；
3. 对符合条件账号生成加密安全、足够长的随机 Token；
4. 原值仅经独立信道发送，服务端存摘要、账号、目的、过期和状态；
5. 用户提交 Token 与新密码；
6. 服务原子验证 purpose、account、expiry、未使用和摘要，标记 consumed；
7. 写新 verifier、递增版本、撤销旧凭据/会话并审计；
8. 通过带外渠道通知，不在响应中自动泄露登录状态。

Token 应短期且一次性。使用后再次提交必须失败；两个并发消费只能一个成功。新发 Token 是否撤销旧 Token 要明确，通常保留多个有效 Token 会扩大攻击面。Token URL 由固定/允许列表域构建，使用 HTTPS，避免信任 Host header；重置页设置合适 Referrer Policy，防止 Token 通过 referrer 泄露。

随机 Token 的原值具有高熵，可把 SHA-256 摘要作为数据库查找键；这与对低熵密码使用快速 hash 完全不同。仍要保护摘要存储、限制猜测、比较安全并避免日志原值。JWT 不是自动更安全的重置 Token：撤销、一次性消费和泄露问题仍需服务端状态或等价机制。

不要在请求重置时立即锁账号；不要在消费后自动登录，OWASP 建议让用户走正常认证，并提供/执行会话失效策略。不要通过安全问题恢复，因为答案通常低熵、可研究或可共享。

## 15. 撤销：让“曾经有效”变成“现在无效”

撤销事件包括密码泄露、设备丢失、离职、租户成员删除、管理员停用、MFA 因素替换、reset Token 使用和服务凭据轮换。系统必须定义撤销对象、传播时限、缓存行为和故障默认。

可组合的机制：凭据状态；账号状态；`credential_version`；认证器 `revoked_at`；会话版本；短有效期；撤销集合；事件广播。没有一种机制适合所有凭据。短有效期减少窗口，却不能替代紧急撤销；缓存提高可用性，却可能延长旧权限。应明确最大传播延迟并测试依赖故障。

删除本地租户成员后，即使外部 IdP 仍认为用户已认证，FactoryCare 也必须拒绝下一次受保护业务请求。外部身份真实性与本地业务授权是两份独立事实。

## 16. 管理员与客服恢复是最高风险路径之一

管理员恢复不能是“在数据库改一列”或“客服发一个临时通用密码”。应定义：可发起角色、强认证/step-up、证据类型、双人审批条件、冷却期、受影响认证器、一次性临时凭据、用户通知、会话撤销和完整审计。

管理员不能读取现有密码，因为系统根本不应能恢复明文。若需要临时访问，应签发短期、一次性、范围有限的恢复凭据，让用户首次使用后建立自己的认证器。管理员也不应能静默替换 MFA 并关闭通知。

break-glass 账号需要独立保管、用途限制、每次使用告警、事后复核和定期演练。它解决可用性风险，同时增加高价值凭据风险，必须在威胁模型中明确。

## 17. 审计：记录行为，不记录秘密

身份生命周期至少审计：注册/邀请、验证成功与失败、认证成功与失败、限速/锁定、密码修改、重置申请与消费、MFA 注册/替换/撤销、管理员恢复、账号暂停/启用/删除、凭据和会话撤销。

结构化事件可包含：事件类型、时间、actor（未知时也明确）、目标账号内部 ID、操作、结果、原因码、认证保证级别、相关 ID、来源分类和管理员审批引用。公开标识如邮箱也应按隐私策略最小化或 pseudonymize。

绝不直接记录：密码、候选密码、完整 verifier、salt+verifier 整条记录、pepper、reset/verification Token、MFA seed、恢复码、Cookie、access/refresh Token。即使操作失败也不能把请求正文打到 DEBUG。审计存储自身需要访问控制、完整性、保留和告警；“有日志”不等于可追责。

枚举保护只限制公开响应，不要求内部审计丢失真实原因。两者通过访问边界分开：客户端看到统一结果，受控审计记录 `ACCOUNT_NOT_FOUND` 或 `BAD_CREDENTIAL` 等内部原因。

## 18. 故障注入与可信证据

本章要求主动注入四类失败：

| 故障 | 第一处可信证据 | 修复后断言 |
| --- | --- | --- |
| 明文/可逆密码 | 持久化 schema/值出现可恢复秘密 | 只存算法、参数、salt、verifier、pepper ID |
| 固定/复用 salt | 相同密码记录 salt 相同或 verifier 相同 | 独立 salt；相同密码记录不同，均可验证 |
| reset Token 重放 | 同一 Token 第二次仍成功 | 原子 consumed；第二次稳定失败 |
| 改密后旧凭据有效 | 旧密码、旧 session/version 仍被接受 | 版本递增，旧密码与旧会话均失败 |

还应测试：过期 Token、错误 purpose、另一个账号的 Token、并发消费、未知账号公开响应、临时限速过期、管理员恢复无审批、MFA 更换未重新认证、审计中出现秘密。

定位从最早的持久化和状态证据开始，不从最终“登录失败”猜根因。记录输入分类、操作、预期、实际、第一处偏差、修复和重跑结果；敏感输入只用 synthetic 标签或不可逆指纹，绝不粘贴真实值。

## 19. Java 离线资产的安全边界

示例使用 JDK 25 `PBEKeySpec`、`SecretKeyFactory`、`Mac` 和 `MessageDigest.isEqual`。`PBEKeySpec` 以 `char[]` 接收密码并支持 `clearPassword()`；代码还清零派生字节。这样的清理减少生命周期，不是 JVM 内存清除证明。

示例通过可注入的 salt/token source 生成确定测试。生产实现必须使用 `SecureRandom` 或身份平台认可的 CSPRNG；固定序列只存在测试类，命名为 `TestOnly...`，README 明确禁止复制。pepper 由 synthetic 内存 vault 提供且不进入记录或输出；真实系统需外部密钥管理、权限、轮换和不可用策略。

资产不访问网络、不发送邮件、不打开浏览器、不读取环境变量、不发现本机账号。它们只打印布尔不变量和事件计数，不打印训练口令、Token、pepper、salt 或 verifier。验证脚本会检查输出不存在 synthetic 原值。

## 20. 120 秒讲解模板

> 身份是服务上下文中对主体的表示，账号保存状态，认证器/凭据证明控制权，会话只是认证后的临时连续性。密码必须用现代慢速自适应单向方案，每条记录有独立随机 salt 和参数；pepper 是数据库外的可选额外秘密，不能代替 salt。注册、验证、限速、改密、MFA 变更、重置和撤销都要成为显式状态迁移。重置 Token 应随机、短期、一次性、服务端安全存储，公开响应防枚举；轮换/恢复后旧密码、Token 和相关会话失效并审计。失败反例是加密保存密码、固定盐、可重放 reset Token，或客服用更弱流程绕过 MFA。FactoryCare 生产把密码/MFA/Token 签发委托外部 IdP，本章代码只用于离线教学。

若只能说“密码要加盐”，却说不出盐为什么可公开、pepper 放哪里、Token 如何一次性、旧会话怎样失效和恢复怎样防枚举，尚未达到目标。

## 21. 自检清单

- 现实主体、数字身份、账号、标识、principal、认证器和会话是否分开？
- 账号与每类凭据是否有显式状态、版本、时间和撤销原因？
- 注册/验证是否原子处理唯一性，验证 Token 是否目的绑定且一次性？
- 单因素 15、MFA 8、至少支持 64、无组合规则、blocklist、允许粘贴是否按适用基线评估？
- 是否拒绝明文、可逆密码、快速无盐 hash 和固定盐？
- 记录是否包含算法/参数/独立 salt/pepper ID，而 pepper 值在数据库外？
- 登录、注册和重置的正文、状态、URL 与明显时间路径是否减少枚举差异？
- 限速是否兼顾账号、来源、全局与锁定拒绝服务？
- MFA 更换和管理员恢复是否比普通登录更弱？
- reset Token 是否随机、足够长、存储安全、短期、一次性、目的/账号绑定？
- 改密、恢复、停用和成员删除后，旧凭据/会话是否在声明时限内失效？
- 审计是否记录 actor/action/object/result，却排除所有秘密？
- FactoryCare 是否继续由外部 IdP 管理密码、MFA 和 Token 签发？

## 22. 官方资料、时效与适用范围

- [NIST SP 800-63B-4: Authentication and Authenticator Management](https://pages.nist.gov/800-63-4/sp800-63b.html)：2025-08-26 发布，提供密码长度、blocklist、限速、salted hash、额外 keyed operation、认证器事件与撤销要求；规范适用范围是美国联邦数字身份系统，其他组织需明确采纳。
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)：当前算法选择、最低参数、salt 与 pepper 工程建议。参数是时效面，采用前必须复核并在目标硬件测量。
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)：密码策略、统一错误、重新认证、限速与自动化攻击防护。
- [OWASP Forgot Password Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html)：一致响应、独立信道、随机/安全存储/一次性/过期 Token 与重置后处理。
- [OWASP Multifactor Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Multifactor_Authentication_Cheat_Sheet.html)：因素选择、MFA 丢失、重置和更换边界。
- [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html)：认证事件与不得记录的密码、Token、密钥。
- [Spring Security Password Storage](https://docs.spring.io/spring-security/reference/features/authentication/password-storage.html)：`PasswordEncoder`、`DelegatingPasswordEncoder`、可升级格式和当前框架建议。本仓库版本注册表把 Spring Security 交由 Spring Boot 4.1 管理；本章不把示例绑定为生产配置。
- [Java SE 25 `PBEKeySpec`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/javax/crypto/spec/PBEKeySpec.html)：离线 Java 资产所用 API 语义；Java 标准算法名只说明实现可用性，不等于算法适合所有安全目标。

密码参数、框架默认和认证指南会变化。每次采用或迁移前应记录复核日期、适用组织、目标环境基准与回滚方案。

## 23. 有意不覆盖

本章不实现 Cookie Session、OAuth/OIDC、JWT、Spring Security 过滤链、WebAuthn/TOTP 协议或外部 IdP 配置；不发送真实邮件/短信；不创建外部账号；不处理生产秘密；不声称通过离线资产即可达到任何 AAL、FIPS 或合规认证。后续章节会消费这里定义的账号状态、凭据版本、撤销和审计合同。
