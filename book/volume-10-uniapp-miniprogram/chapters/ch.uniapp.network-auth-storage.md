---
schema_version: 2
edition: 2026.2-draft
id: ch.uniapp.network-auth-storage
title: 网络、认证、存储与多环境配置
responsibility: 用 uni.request、受控凭据存储和环境配置访问后端，区分 HTTP、宿主白名单、认证过期与本地存储失败，不实现离线重放。
volume: '10'
order: 4
level: L2+
status: drafting
path: book/volume-10-uniapp-miniprogram/chapters/ch.uniapp.network-auth-storage.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.uniapp.toolchain-pages
- ch.security.session-authentication
version_surfaces:
- uni-app
- wechat-miniprogram
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“网络、认证、存储与多环境配置”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - uniapp-network-environment
  - uniapp-auth-storage
  covers_topics:
  - uniapp.request
  - uniapp.request-domain-whitelist
  - uniapp.environment-config
  - uniapp.http-error-mapping
  - uniapp.auth-session-state
  - uniapp.secure-storage-boundary
  - uniapp.credential-expiry
  - uniapp.storage-versioning
  uses_capabilities:
  - mobile.miniprogram-runtime
  - foundation.http-message
  - security.authentication
  - security.web-threat
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现带环境切换、认证过期处理和版本化存储的工单 API 客户端；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - uniapp-network-environment
  - uniapp-auth-storage
  covers_topics:
  - uniapp.request
  - uniapp.request-domain-whitelist
  - uniapp.environment-config
  - uniapp.http-error-mapping
  - uniapp.auth-session-state
  - uniapp.secure-storage-boundary
  - uniapp.credential-expiry
  - uniapp.storage-versioning
  uses_capabilities:
  - mobile.miniprogram-runtime
  - foundation.http-message
  - security.authentication
  - security.web-threat
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: mock-server-environment-matrix-expired-credential-fixture
- id: diagnose
  kind: fault-diagnosis
  text: 面对“域名白名单、环境串线、明文凭据日志或损坏存储导致的网络/安全故障”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - uniapp-network-environment
  - uniapp-auth-storage
  covers_topics:
  - uniapp.request
  - uniapp.request-domain-whitelist
  - uniapp.environment-config
  - uniapp.http-error-mapping
  - uniapp.auth-session-state
  - uniapp.secure-storage-boundary
  - uniapp.credential-expiry
  - uniapp.storage-versioning
  uses_capabilities:
  - mobile.miniprogram-runtime
  - foundation.http-message
  - security.authentication
  - security.web-threat
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 网络、认证、存储与多环境配置

> 本章状态为 `drafting`。配套资产使用纯 TypeScript/JavaScript 风格状态模型与 Node.js 假服务器验证环境矩阵、HTTP 映射、过期凭据、日志脱敏和损坏存储；它没有访问真实微信请求域名、OIDC Provider、平台安全存储或 FactoryCare 服务。因此，绿灯不能证明 TLS、域名白名单、PKCE 回调、真实 token 轮换和真机存储安全已经通过。

移动端“请求失败”至少可能来自六层：构建时选错环境、微信域名白名单拒绝、DNS/TLS/超时等传输错误、服务器 HTTP 错误、认证过期，以及本地缓存损坏。若把它们都映射成“网络异常”，用户无法恢复，开发者也会在错误层排查。本章建立一个小而明确的 API 客户端：只允许预注册环境，区分传输与 HTTP，凭据有状态和期限，存储有版本与损坏策略，日志永不出现敏感值。

## 1. 完成定义、配套入口与非目标

完成本章后，你应能：

1. 解释 `uni.request` 的配置、回调、`statusCode` 与 `RequestTask` 边界；
2. 区分平台域名白名单、DNS/TLS/超时、HTTP 4xx/5xx 和 JSON 合同错误；
3. 用显式环境键选择固定 API origin，拒绝运行时任意 URL；
4. 区分 Web Cookie 会话和小程序/移动 bearer，不复制浏览器 CSRF 逻辑；
5. 建模匿名、有效、刷新中、过期、撤销与损坏凭据状态；
6. 解释普通 `uni.setStorage` 为什么不是密码保险箱；
7. 为本地数据加 schema version、所有者/环境绑定、过期与损坏清理；
8. 用成功、超时、HTTP 错误、过期凭据和损坏存储矩阵验证客户端。

配套入口：

- [环境、请求、认证和存储状态示例](../../../examples/encyclopedia/ch.uniapp.network-auth-storage/README.md)
- [白名单、串线、泄密和损坏存储实验](../../../labs/encyclopedia/ch.uniapp.network-auth-storage/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.uniapp.network-auth-storage/README.md)

本章不实现完整 OIDC Provider 桥接、不设计自建用户名密码、不实现离线命令重放、不讨论上传/扫码权限。FactoryCare 的离线报修首期只保存草稿，创建工单要求在线获得服务端幂等结果。

## 2. 先画请求管线

```text
页面意图
  ↓ 领域输入校验
API Client
  ↓ 选择受控环境 + 附加有效凭据 + 生成 trace/idempotency 元数据
uni.request
  ↓ 微信宿主域名规则 / 网络 / TLS
Spring /api/v1
  ↓ 认证、租户、授权、业务规则
HTTP 响应
  ↓ 状态码 + Content-Type + 运行时 schema
确定的 UI 状态
```

每层都有自己的第一证据。环境串线看最终 base URL；白名单看宿主 fail 日志与平台配置；超时看 request fail/计时；401 看 HTTP 响应；403 看服务端授权审计；JSON 错看 schema 错误。页面只接收统一结果，不解析五种平台错误字符串。

## 3. `uni.request`：回调成功不等于业务成功

官方文档说明 `uni.request` 发起请求，小程序平台使用前需要配置域名白名单；配置包含 URL、method、header、data、timeout 等，响应包含 `statusCode`，返回值可提供 `abort` 等 RequestTask 能力。

```ts
type RequestResult = {
  statusCode: number
  data: unknown
  header: Record<string, string>
}

function requestWorkOrder(id: string, token: string) {
  return new Promise<RequestResult>((resolve, reject) => {
    const task = uni.request({
      url: `${API_BASE}/api/v1/work-orders/${encodeURIComponent(id)}`,
      method: 'GET',
      timeout: 10_000,
      header: {
        Accept: 'application/json',
        Authorization: `Bearer ${token}`
      },
      success: (response) => resolve(response as RequestResult),
      fail: (error) => reject(error)
    })
    // 副作用所有权：调用者保存 task，并在页面卸载或新请求替代时主动 abort。
    currentTask = task
  })
}
```

这里的 success 通常意味着宿主完成了 HTTP 交换，不表示 `statusCode` 是 2xx，更不表示响应满足业务 schema。必须显式分类状态码。fail 更接近域名、DNS、TLS、超时、取消和连接等传输/宿主失败；具体错误字符串具有平台差异，不应成为跨端领域枚举。

### 3.1 取消的证据边界

`RequestTask.abort()` 能请求宿主终止客户端任务，但不能证明服务器没有收到或处理请求。对创建工单等写操作，取消 UI 等待不能替代幂等键。页面卸载后还要防旧回调更新新页面状态；下一章/后续竞态内容再系统处理。

## 4. 域名白名单是平台门，不是服务端授权

微信小程序对请求域名有平台配置要求。常见失败：开发者工具勾选“不校验合法域名”后本地可用，真机/体验版失败；测试域名未配置；使用 IP、HTTP、非标准证书或跳转到未允许域名；上传/下载与普通 request 使用不同配置类别。

正确证据链：

1. 记录实际最终 URL（必须脱敏 query）；
2. 对照微信公众平台当前合法域名配置；
3. 确认 HTTPS 证书链、域名与有效期；
4. 在目标基础库/真机复现 fail；
5. 用 `curl`/服务端日志独立判断服务器可达与响应；
6. 修复平台配置后重跑同一真机场景。

白名单只决定客户端能否请求某域，不决定当前用户能否看工单。攻击者可绕过客户端直接调用 API，所以 Spring 必须认证、恢复 tenant/membership 并授权每个资源。

## 5. 多环境配置：允许列表，不是可编辑 URL

环境至少包括本地开发、集成/测试、生产。每个构建只选择一个显式环境键：

```ts
type Environment = 'development' | 'test' | 'production'

const endpoints: Record<Environment, string> = {
  development: 'https://dev-api.example.invalid',
  test: 'https://test-api.example.invalid',
  production: 'https://api.example.invalid'
}

export function apiBase(environment: Environment): string {
  const value = endpoints[environment]
  if (!value) throw new Error('UNSUPPORTED_ENVIRONMENT')
  return value
}
```

`.invalid` 是教材保留域，不是真实 FactoryCare 地址。不要允许用户或本地 storage 覆盖任意 base URL，否则生产 token 可能被发送到攻击者域。内部调试若需要 endpoint override，必须只在明确非生产构建、显示警告、限制 allowlist，并保证发布构建移除。

### 5.1 构建环境与运行平台不同

`development/production` 描述构建模式，H5/微信/Android 描述目标平台，devtools/iOS/Android 描述运行宿主。它们是不同维度。不能用 `process.env.NODE_ENV === 'production'` 推断正在微信真机，也不能用 `getSystemInfo` 选择生产服务器。

### 5.2 环境变量不是秘密

编译进客户端的 `import.meta.env` 或 define 值会出现在产物。只能放公开 base URL、功能标识和版本号；OIDC client secret、数据库密码、签名私钥永远不能进客户端。前缀是否暴露由构建工具合同决定，但“没有前缀”也不是安全存储策略。

## 6. HTTP 与问题映射

建议将平台结果归一为封闭联合：

```ts
type ApiResult<T> =
  | { kind: 'ok'; value: T; traceId?: string }
  | { kind: 'unauthenticated' }
  | { kind: 'forbidden' }
  | { kind: 'not-found' }
  | { kind: 'conflict'; code?: string }
  | { kind: 'rate-limited'; retryAfterSeconds?: number }
  | { kind: 'server-error'; traceId?: string }
  | { kind: 'transport-error'; reason: 'timeout' | 'offline' | 'cancelled' | 'other' }
  | { kind: 'contract-error' }
```

映射示例：

| 证据 | 结果 | UI/动作 |
|---|---|---|
| 2xx + schema 通过 | ok | 展示数据 |
| 2xx + schema 失败 | contract-error | 阻止错误数据进入页面，记录脱敏 trace |
| 401 | unauthenticated | 进入受控刷新/重新登录 |
| 403 | forbidden | 显示无权，不循环刷新 token |
| 404 | not-found | 资源不存在/已隐藏 |
| 409 | conflict | 提示刷新/按业务合同解决 |
| 429 | rate-limited | 遵守受控重试提示 |
| 5xx | server-error | 可恢复错误与 traceId |
| request fail | transport-error | 按超时/离线/取消区分 |

401 与 403 不能互换：401 是当前认证凭据不足或无效，403 是已识别主体仍无权。刷新 token 不会修复租户权限。404 有时用于避免泄露资源存在，具体由服务端合同决定。

## 7. 响应仍是不可信输入

TypeScript 泛型不会验证 JSON：

```ts
// 错误：只是在编译期相信 unknown 是 WorkOrder。
const response = await request<WorkOrder>(options)
```

客户端应使用运行时 schema 或显式解析，验证 ID、状态枚举、可空字段和时间字符串。解析失败映射为 `contract-error`，不要把字段 `undefined` 传遍组件后才白屏。错误日志只保留 schema 路径、traceId 和客户端版本，不保留完整敏感 payload。

## 8. FactoryCare 的认证分端合同

ADR-0003 规定：Web 在 Java 端建立 HttpOnly/Secure/SameSite 会话并为状态写使用 CSRF；Flutter 与具备安全能力的小程序使用 Authorization Code + PKCE 和短时 bearer，refresh token 只放平台安全存储，具体小程序 Provider 桥接在实现周确认。OpenAPI 用 `mobileBearer` 表示移动客户端，格式为 opaque 或 OIDC access token。

这意味着不能把 Web Cookie/CSRF 代码原样复制到 uni-app，也不能自制用户名密码/JWT。小程序认证需要：

1. 外部 Provider/平台桥接的当前官方流程；
2. state/nonce/PKCE 等协议参数按 OIDC/OAuth 合同验证；
3. access token 短时、只发允许 audience；
4. refresh token 只有在目标平台有明确安全存储与清理能力时才持久化；
5. Java 每次恢复当前 membership/角色/数据范围；
6. 用户禁用、退出或撤销后，旧凭据请求失败并清理敏感缓存。

具体 Provider 尚未选择，本章不能补造登录 URL、scope、token 生命周期或刷新策略。

## 9. 认证状态机与单次恢复

```text
UNKNOWN -> ANONYMOUS
UNKNOWN -> AUTHENTICATED
AUTHENTICATED -> REFRESHING -> AUTHENTICATED
AUTHENTICATED -> REFRESHING -> EXPIRED
AUTHENTICATED -> REVOKED
任意状态 -> STORAGE_CORRUPT -> ANONYMOUS + 清理
```

页面不能用 `Boolean(token)` 代表已认证；token 可能过期、issuer/audience 错、成员已禁用。客户端状态只表示“本地目前持有候选凭据”，最终认证与授权由服务器结果决定。

多个请求同时收到 401 时，不应各自并发刷新十次。可用 single-flight 协调一次刷新，等待者复用结果；刷新失败统一进入 EXPIRED。每个原请求最多自动重放一次，并只对符合合同的请求；写请求必须有幂等键。完整实现和 Provider 细节留在认证集成任务。

## 10. 本地存储不是安全保险箱

官方 `uni.setStorage/getStorage` 提供异步缓存，Sync 变体提供同步读写；数据需为可序列化类型，写入可覆盖同 key，Sync 调用可能抛错。它解决持久化便利，不自动提供加密、防调试、防越狱/Root、防备份泄露或跨用户隔离。

因此分级：

- 可存：非敏感 UI 偏好、带版本的表单草稿、公开目录缓存；
- 谨慎存：最小用户展示信息，必须绑定 subject/tenant、过期和退出清理；
- 不应放普通 storage：密码、client secret、长期 bearer、refresh token、完整敏感工单；
- refresh token：只有目标平台明确的安全存储方案、威胁模型和清理证据满足 ADR 才允许。

“Base64 后再存”不是加密；硬编码 AES key 在同一客户端也不能提供可靠秘密边界。

## 11. 版本化存储信封

```ts
type StoredDraftV1 = {
  schemaVersion: 1
  environment: 'development' | 'test' | 'production'
  subjectHash: string
  savedAt: string
  expiresAt: string
  payload: {
    deviceId: string
    description: string
  }
}
```

读取顺序：捕获存储异常；检查对象形状；检查 schemaVersion；检查环境；检查当前用户绑定；检查过期；验证 payload；失败即隔离/删除并回到安全默认。不能把 test 草稿带到 production，也不能让用户 B 自动上传用户 A 的未确认草稿。

迁移应显式：V1→V2 的纯函数，成功后写新 key/新版本，验证后再删旧值。无法安全迁移时提示用户重新输入，而不是用 `as NewType` 强行解释旧 JSON。

### 11.1 同步与异步 API

启动路径少量小配置可用 Sync，但要捕获异常并避免大对象阻塞。大量草稿/缓存优先异步。任何写入都可能因配额、序列化、平台和存储损坏失败；UI 不能在写入前就显示“已保存”。

## 12. 日志脱敏是一项可测试合同

禁止日志字段：Authorization、Cookie、token、code、PKCE verifier、完整 subject、手机号、签名 URL、完整私密描述。允许字段：traceId、环境键、HTTP status、错误类别、客户端版本、脱敏资源类型。

```ts
function safeRequestLog(input: {
  environment: string
  method: string
  pathTemplate: string
  status?: number
  traceId?: string
}) {
  // 日志允许列表：只接受结构化非敏感字段，而不是事后正则擦除整个对象。
  console.info('api-request', input)
}
```

不要 `console.log(options)`，因为 header 中可能有 bearer；不要把完整 URL 打印出来，query 可能有 code/token/个人信息。自动测试应扫描输出不含已知哨兵 token。

## 13. FactoryCare API 客户端分层

```text
env.ts             受控环境 -> API base
credential.ts      认证状态与安全存储适配
transport.ts       uni.request / timeout / abort / 脱敏日志
problem.ts         HTTP + Problem Details -> ApiResult
schema.ts          unknown -> 运行时 DTO
workOrders.ts      领域端点、幂等键与命令/查询合同
```

页面调用 `getWorkOrder(id)`，不自行拼 Authorization。transport 不知道工单状态机。credential 不决定租户权限。这样可以在 Node/Vitest 用 fake transport 测大部分逻辑，再用目标真机验证宿主白名单和请求行为。

### 13.1 一个受控请求算法

1. 验证领域输入；
2. 读取显式 environment；
3. 获取未过期候选 access token；
4. 构造固定 origin + 路径，header 使用允许列表；
5. 启动 request 并保存 task；
6. fail 映射传输错误；success 再检查 status；
7. 2xx 做运行时 schema；401 进入一次受控恢复；
8. 返回封闭 `ApiResult`；
9. 只写脱敏日志；
10. 页面卸载取消等待，但服务端写入依赖幂等。

## 14. 诊断四类代表故障

### 14.1 域名白名单

表现：开发工具放宽校验可用，真机 fail。第一证据是最终 origin、宿主 fail 与公众平台配置。不要修改 Spring CORS 来修白名单；它们是不同门。

### 14.2 环境串线

表现：测试账号请求生产、生产 token 发往测试。第一证据是构建环境、受控 endpoint 和服务端 audience/issuer。立即停止发送、轮换可能泄露凭据，修复 allowlist 与 CI 构建矩阵。

### 14.3 明文凭据日志

表现：调试平台能搜索到 bearer。先撤销/轮换，再修日志允许列表和自动扫描；删除本地日志不能证明外部平台副本消失。

### 14.4 损坏存储

表现：启动 JSON/字段错误、用户切换后出现旧草稿。第一证据是 key、schemaVersion、环境/subject 绑定和解析错误；隔离/清理，回到匿名/空草稿，不能继续带错数据请求。

## 15. 测试矩阵

| 输入 | 预期结果 | 必查证据 |
|---|---|---|
| development/test/production | 只选对应 allowlisted origin | 构建模式与最终 origin |
| 2xx 合法 JSON | ok | schema 与 traceId |
| 2xx 非法 JSON | contract-error | 字段路径，不记录 payload |
| timeout/offline | transport-error | 宿主 fail/计时 |
| 401 + 刷新成功 | 最多一次重放 | single-flight 计数 |
| 401 + 刷新失败 | expired | 凭据清理与登录提示 |
| 403 | forbidden | 不刷新 token |
| 409 | conflict | 业务冲突，不伪装网络错 |
| 损坏/旧版 storage | 安全默认 + 隔离/迁移 | 版本/绑定/过期 |
| 哨兵 token | 日志中零出现 | 输出扫描 |

Mock 服务器能验证 HTTP 分类，但不能验证微信域名白名单；真机能验证宿主，但不能单独证明日志平台没有泄密。证据要组合。

## 16. 安全、性能、隐私与可用性边界

**安全**：客户端始终不可信；服务端验 issuer/audience/expiry、恢复 membership/tenant/data scope；敏感凭据短时、最小 scope、可撤销。环境切换 fail closed。

**隐私**：只缓存必要草稿；退出/禁用/用户切换清理敏感数据；诊断导出前脱敏。不要把“方便客服”作为上传完整日志的理由。

**性能**：缓存可减少请求，但本章不实现离线同步。小缓存也要过期和版本。同步 storage 不放大对象；请求超时可配置但不能无限。不要无条件重试 4xx。

**可用性**：错误必须可恢复且可区分。离线提示保存草稿；401 引导登录；403 说明无权；冲突提示刷新；服务端错误展示 traceId。不能把所有错误变成 toast“请求失败”。

## 17. 从零练习路径

### 17.1 预测

`uni.request` 进入 success，`statusCode=401`。这是成功、网络错误还是认证错误？写出状态转换。再预测开发者工具关闭域名校验而真机失败时首证据。

### 17.2 构建

实现 environment allowlist、fake transport、ApiResult、认证状态与 V1 存储信封。用矩阵覆盖 2xx/401/403/409/5xx/timeout/损坏存储和日志哨兵。

### 17.3 故障注入

依次把 production endpoint 指向 test；打印完整 request options；把损坏 JSON 强转类型；并发三个 401 触发三次刷新。预测、运行、找首错、修复并重跑同一矩阵。

### 17.4 需求变更

新增用户切换。旧用户未提交草稿不得自动上传到新用户；设计 subjectHash/tenant/environment 绑定、提示和清理测试。

### 17.5 关闭 AI 复述

120 秒解释请求六层、白名单与授权区别、success 与 2xx 区别、Bearer 状态机、普通 storage 边界、版本化信封和日志允许列表。

## 18. 快速参考与复习

```text
宿主请求：uni.request -> RequestTask
传输失败：fail（域名/DNS/TLS/超时/取消等）
HTTP 失败：success 后检查 statusCode
环境：显式 key -> 固定 allowlist，客户端变量不是秘密
认证：短时 bearer；401 恢复，403 不刷新
存储：普通 storage 非安全保险箱；版本/环境/用户/过期绑定
日志：字段允许列表，token/code/cookie/payload 禁止
```

24 小时后手画 401 流程；一周后重写环境+HTTP 矩阵；一个月后模拟 token 撤销、用户切换和存储迁移。

自检：

1. 为什么 `uni.request.success` 不等于业务成功？
2. 微信域名白名单与 Spring CORS/授权各负责什么？
3. 为什么生产 endpoint 不能由 storage 任意覆盖？
4. 为什么普通 `setStorage` 不能保存 refresh token 就宣称安全？
5. 401 与 403 的恢复动作有何不同？
6. 页面 abort 为什么不能证明写请求没有到服务端？

## 19. 版本、来源与复核边界

本章于 **2026-07-17** 复核 uni-app 官方 request、storage、环境变量和 Vite 配置文档。官方 request 仍明确小程序网络 API 需配置域名白名单，并暴露 `statusCode`、timeout 与 RequestTask；storage 仍区分异步/同步接口且只承诺可序列化缓存，不承诺密码学安全；环境变量仍会进入客户端构建。

- [uni.request](https://uniapp.dcloud.net.cn/api/request/request.html)
- [数据缓存 Storage](https://uniapp.dcloud.net.cn/api/storage/storage.html)
- [环境变量](https://uniapp.dcloud.net.cn/tutorial/env.html)
- [Vite 配置](https://uniapp.dcloud.net.cn/collocation/vite-config.html)
- [ADR-0003：OIDC 与分客户端会话](../../../factorycare-design/adrs/0003-oidc-and-client-sessions.md)
- [FactoryCare 公共 API 安全方案](../../../factorycare-design/contracts/public-api.yaml)

稳定原理是环境 allowlist、传输/HTTP/合同分层、凭据有状态和期限、普通缓存不等于安全存储、日志最小化。易变部分是 uni.request 平台参数、微信域名政策、Provider 桥接、安全存储能力与 token 生命周期；实施时必须复核官方文档和目标威胁模型。
