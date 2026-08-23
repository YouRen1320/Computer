---
schema_version: 2
edition: 2026.2-draft
id: ch.uniapp.factorycare-reporter
title: FactoryCare 报修端集成与验收
responsibility: 把扫码、上传、位置、服务端状态、离线幂等和发布证据集成为 FactoryCare 报修端切片，只验收既定合同，不在本章补教平台基础。
volume: '10'
order: 12
level: L3
status: drafting
path: book/volume-10-uniapp-miniprogram/chapters/ch.uniapp.factorycare-reporter.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.uniapp.offline-idempotency
- ch.uniapp.release-monitoring
- ch.vue.server-state
version_surfaces:
- uni-app-cli-vue3
- uni-app-mp-weixin-compiler
- wechat-miniprogram-base-library
- wechat-developer-tools
- vue-3
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“FactoryCare 报修端集成与验收”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - factorycare-reporter-flow
  - factorycare-reporter-resilience
  covers_topics:
  - factorycare.reporter-identify-device
  - factorycare.reporter-create-order
  - factorycare.reporter-upload-evidence
  - factorycare.reporter-track-status
  - factorycare.reporter-offline-submit
  - factorycare.reporter-duplicate-prevention
  - factorycare.reporter-permission-fallback
  - factorycare.reporter-release-evidence
  uses_capabilities:
  - mobile.uniapp-device-permissions
  - mobile.uniapp-offline-idempotency
  - mobile.uniapp-platform
  - web.javascript-network-race
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“FactoryCare 报修端集成与验收”构建可运行程序与测试：交付可安装的 FactoryCare 报修端切片、端到端脚本、离线重放记录和版本证据；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - factorycare-reporter-flow
  - factorycare-reporter-resilience
  covers_topics:
  - factorycare.reporter-identify-device
  - factorycare.reporter-create-order
  - factorycare.reporter-upload-evidence
  - factorycare.reporter-track-status
  - factorycare.reporter-offline-submit
  - factorycare.reporter-duplicate-prevention
  - factorycare.reporter-permission-fallback
  - factorycare.reporter-release-evidence
  uses_capabilities:
  - mobile.uniapp-device-permissions
  - mobile.uniapp-offline-idempotency
  - mobile.uniapp-platform
  - web.javascript-network-race
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: end-to-end-device-test-offline-replay-test-release-evidence-review
- id: diagnose
  kind: fault-diagnosis
  text: 面对“跨端字段漂移、重复工单、权限失败无降级或发布版本与证据不一致”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - factorycare-reporter-flow
  - factorycare-reporter-resilience
  covers_topics:
  - factorycare.reporter-identify-device
  - factorycare.reporter-create-order
  - factorycare.reporter-upload-evidence
  - factorycare.reporter-track-status
  - factorycare.reporter-offline-submit
  - factorycare.reporter-duplicate-prevention
  - factorycare.reporter-permission-fallback
  - factorycare.reporter-release-evidence
  uses_capabilities:
  - mobile.uniapp-device-permissions
  - mobile.uniapp-offline-idempotency
  - mobile.uniapp-platform
  - web.javascript-network-race
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# FactoryCare 报修端集成与验收

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《离线队列、重试、冲突与幂等重放》](ch.uniapp.offline-idempotency.md)：弱网提交必须能重放且不重复创建工单。
- [《构建、版本、灰度、发布与监控》](ch.uniapp.release-monitoring.md)：验收必须对应可追溯目标版本、监控和回退证据。
- [《服务端状态、加载、错误、取消与竞态》](../../volume-09-vue-nuxt/chapters/ch.vue.server-state.md)：报修状态、加载、错误与竞态复用统一服务端状态合同。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。它是 uni-app 卷的项目集成章：不重新教授 Vue、网络、权限、上传、离线、幂等或发布基础，而是把前置章节能力按 FactoryCare 已冻结合同组合并验收。配套 Node 资产只验证离线业务模型；只有真实 uni-app 目标产物、测试账号、真机/宿主、FactoryCare API、对象存储和发布记录齐全时，才能声称交付“可安装报修端”。

FactoryCare 报修人的主线看起来很短：扫码、填写、上传、提交、查看进度。但任何一步都可能跨越宿主权限、网络、对象存储、Java 事务、状态机和版本发布。集成章的价值不是再写一遍按钮，而是证明这些边界在成功、边界和故障路径下仍遵守同一个合同。

## 1. 完成定义与验收边界

最终切片至少包含：

1. 扫描或手输不透明设备码，匿名解析最小设备身份；
2. 报修人登录后填写类别、描述、优先级和可选联系方式；
3. 可选选择/拍摄附件，走上传意图、对象上传、完成确认和扫描状态；
4. 可选获取一次性位置；拒绝时仍可完成核心报修；
5. 使用稳定 `Idempotency-Key` 创建报修和初始工单；
6. 断网时保存可解释队列，恢复后安全重放；
7. 列出并查看自己的报修，显示服务端返回的真实状态；
8. 上传失败、会话过期、合同漂移和竞态都有明确 UI；
9. 发布候选能关联 commit、buildId、产物、体验矩阵和监控事件；
10. E2E 证据覆盖扫码到提交、权限拒绝、上传失败、离线重放、重复点击、状态刷新和版本回退。

本章不增加第十三个状态，不提供通用 `PATCH status`，不让客户端决定 tenantId，不公开资产运维细节，不让 Python AI 创建工单，不设计支付/客服，也不承诺多平台发布。

配套入口：

- [报修聚合流示例](../../../examples/encyclopedia/ch.uniapp.factorycare-reporter/README.md)
- [字段漂移、重复创建、权限降级和版本证据实验](../../../labs/encyclopedia/ch.uniapp.factorycare-reporter/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.uniapp.factorycare-reporter/README.md)

## 2. 先画跨边界序列

```text
报修人
  → 小程序扫码/手输
  → POST /api/v1/asset-codes:resolve（匿名、码放 body）
  ← assetId + displayName（最小字段）
  → 登录/恢复会话
  → 可选附件上传意图 → 对象存储 → 完成确认/扫描
  → POST /api/v1/reports + Idempotency-Key
  ← reportId + workOrderId + CREATED
  → GET /api/v1/reports/mine 或 /reports/{reportId}
  ← 服务端状态与公开进度
```

序列中的每个响应都可能晚到、失败或重复。页面不是线性脚本，而是一组有身份的异步操作。UI 需要知道当前草稿、当前扫描、当前上传、当前提交意图和当前刷新请求分别是谁。

## 3. 扫码识别设备：码不是资产主键

FactoryCare 公开码是可轮换、可撤销的不透明值。客户端不能从码中解析 tenantId、assetId 或业务属性，也不能把原码放 URL/query 中。既定合同使用：

```http
POST /api/v1/asset-codes:resolve
Content-Type: application/json

{"code":"<opaque-value>"}
```

成功只返回发起报修所需的匿名最小身份，例如 `assetId` 与安全展示文本。不能返回内部状态、位置树、序列号、租户、历史工单或“这个码差一点有效”的提示。

### 3.1 扫码状态机

```text
idle → scanning → resolving → resolved
  ├→ cancelled → idle
  └→ invalid/revoked/rate-limited/network-error → recoverable
```

取消扫码不是错误；无效、撤销和不存在对匿名用户应遵守统一失败合同；限流要显示稍后重试而不是自动无限重放。页面离开或开始新扫描后，旧解析响应不能覆盖新设备，可使用递增 operationId/AbortController 等等价策略进行“只提交最新结果”。

### 3.2 手输降级

扫码权限拒绝、摄像头故障或宿主不支持时，提供手输码入口。手输仍调用同一解析接口，不得绕过校验直接把字符串当 assetId。降级意味着实现同一目的的替代路径，不是降低服务端安全要求。

## 4. 表单合同：客户端友好，服务端权威

`CreateReportRequest` 的既定字段为：

| 字段 | 语义 | 客户端职责 |
|---|---|---|
| `assetId` | 已解析设备身份 | 来自成功解析，不信任手工注入 |
| `category` | 报修类别 | 使用当前合同允许值/长度 |
| `description` | 故障描述 | 提供长度提示和必填反馈 |
| `priority` | `LOW/MEDIUM/HIGH/CRITICAL` | 显示可理解文案，发送稳定值 |
| `contact` | 可选联系信息 | 最小化、明确用途 |
| `attachmentIds` | 最多三个已完成的创建期附件 | 只发送当前草稿所属成功附件 |

OpenAPI 当前定义描述长度 10—5000、类别 1—64、联系方式最大 200、附件最多三个。这里引用的是项目内合同，不是 uni-app 固有限制。客户端校验提高反馈速度，服务端仍必须再次验证；若两端漂移，以发布时冻结的合同和服务端响应为证据，不能在客户端静默截断后假装成功。

### 4.1 表单状态与派生状态

原始状态可以是 `asset`、`category`、`description`、`priority`、`contact`、`attachments`、`locationChoice`；`canSubmit`、字符计数、错误摘要是派生状态，不应多份手工同步。提交期间禁用重复动作，但不能只靠按钮禁用保证幂等。

验证错误需要同时满足：字段旁提示、表单级摘要、焦点移动和屏幕阅读器可理解。网络/服务端问题不应伪装成字段错误。

## 5. 上传证据：先意图，后对象，再绑定

附件不能直接把本地路径塞进创建报修请求。FactoryCare 的通用附件链为：

1. `POST /api/v1/attachments/upload-intents`，目的使用 `REPORT_CREATION`；
2. 服务端授权短时受限上传目标；
3. 客户端上传对象并记录进度；
4. `POST /api/v1/attachments/{attachmentId}/completion`；
5. 服务端核验对象元数据，扫描可能仍在进行；
6. 创建报修时发送可绑定的 `attachmentIds`；
7. Java 在创建报修事务中把附件原子绑定为 `owner_type=REPORT`。

创建前未绑定附件不能下载、引用或供 AI 处理；它仍绑定上传会话/主体并有短时生命周期。知识文件不走这条 attachment 合同。

### 5.1 上传 UI 状态

每个附件独立拥有：

```text
selected → intent-creating → uploading → completing → scanning → ready
        ↘ failed/rejected/expired/cancelled
```

只有 `ready` 且属于当前草稿的 ID 可进入报修请求。删除本地卡片时还要按合同撤销/清理服务端临时对象；页面销毁不能让晚到上传结果重新插入新草稿。

### 5.2 失败恢复

- 上传意图过期：创建新意图，不复用过期 URL；
- 网络中断：按对象存储/服务端支持决定续传或重新上传，不猜测；
- completion 超时：用同一幂等键安全查询/重试；
- 扫描拒绝：显示安全原因类别，移除附件后仍可提交文字；
- 报修创建失败：保留已授权临时附件，按过期时间提示重试，不复制对象；
- 用户换草稿：附件归属不能跨草稿串用。

## 6. 可选位置与权限降级

位置只是协助到场的可选信息，不是创建报修的默认硬门槛。流程应由用户主动触发：说明目的 → 请求一次性能力 → 成功后预览 → 用户选择是否附加。拒绝/撤回/不可用时返回表单并允许继续。

不要在页面 `onLoad` 立即索取位置，不持续采集轨迹，不把坐标写日志，不将权限弹窗结果当永久状态。若后端当前 `CreateReportRequest` 没有位置字段，就不能为了“已经取到”而私自添加；应先按跨端 API 变更流程更新合同、服务端、测试和隐私材料。本章只验收现有合同。

## 7. 创建报修与重复防护

用户点击提交时生成**提交意图**，而不是每次网络重试都生成新命令。该意图包含：

- 稳定的本地 `operationId`；
- 稳定 `Idempotency-Key`；
- 规范化请求指纹；
- 创建时间、尝试次数和最后错误；
- 草稿快照或不可变 payload；
- 状态 `queued/sending/confirmed/needs-attention`。

服务端对同主体、同路由、同键、同指纹重试返回原结果；同键不同正文必须冲突。客户端遇到超时不能推断失败，也不能换键立刻再发。先用原键重试或查询自己的报修，直到获得权威结果。

### 7.1 双击与多入口

按钮 `loading` 只改善交互，无法阻止：快速双击竞态、页面重建、系统重试、多个设备、代理重发。真正 exactly-once 业务结果依赖服务端幂等记录、唯一约束和事务；客户端负责稳定传键和正确解释重放/冲突。

### 7.2 成功后的状态

创建响应同时给出 report/work order 身份和初始 `CREATED`。页面先保存权威响应，再删除本地队列与草稿。顺序反过来会在保存响应失败时失去追踪线索；先跳转再持久化也可能让进度页找不到 ID。

## 8. 离线队列与重放

离线不是“catch 后再请求”。队列要显式建模：

```text
queued → sending → confirmed
   ├→ retry-wait（瞬时错误，可有界退避）
   └→ needs-attention（合同/权限/永久业务错误）
```

应用启动、网络恢复和用户手动重试可能同时触发 drain，因此同一时刻只能有一个队列消费者或使用租约。每条命令保持原键与原 payload；确认后原子保存服务端 ID 并移除队列项。

### 8.1 可重试分类

- 连接失败、超时、部分 5xx：通常可有界重试；
- 401：先刷新/恢复会话，不能无限发送旧凭据；
- 403：需要用户/权限处理，不自动重试；
- 400/合同校验：标记需修改草稿；
- 409 同键不同指纹：停止并诊断本地键复用；
- 429：遵守服务端节流提示，避免惊群；
- 已确认重放：接受原 reportId，不再创建新卡片。

“通常”仍服从具体 Problem 合同。不要只按 HTTP 大类猜测副作用。

### 8.2 本地安全

队列包含描述、联系方式和附件引用，属于受保护数据。限制字段、数量和保留期；登出/换账号时隔离或清理；不把 token 复制进每条命令；调试导出默认脱敏；本地记录不能让另一个报修人重放。

## 9. 查看进度与服务端状态

报修人使用：

- `GET /api/v1/reports/mine` 查看自己的列表；
- `GET /api/v1/reports/{reportId}` 查看授权详情与公开进度。

服务端只返回当前主体可见的数据。客户端不能用前端过滤代替授权，也不能把另一用户的缓存短暂显示后再隐藏。

FactoryCare 有固定 12 状态：`CREATED`、`TRIAGED`、`ASSIGNED`、`ACCEPTED`、`IN_PROGRESS`、`PENDING_PARTS`、`PENDING_APPROVAL`、`RESOLVED`、`VERIFIED`、`CLOSED`、`REOPENED`、`CANCELLED`。报修端可以把多个状态映射成易懂进度文案，但必须保留原始值并对未知值安全降级，不能编造 `PROCESSING` 等第十三状态回传服务端。

### 9.1 状态展示映射

```text
CREATED/TRIAGED/ASSIGNED/ACCEPTED → 已受理/待处理阶段
IN_PROGRESS/PENDING_PARTS/PENDING_APPROVAL → 处理中及明确等待原因
RESOLVED → 待报修人或主管验证
VERIFIED/CLOSED → 已验证/已关闭
REOPENED → 已重开处理
CANCELLED → 已取消
```

这是 UI 映射，不改变领域状态。具体文案应让用户知道下一步和是否需要操作。

配套示例把 `VERIFIED/CLOSED` 映射到名为 `COMPLETED` 的 **UI 展示分组**。`COMPLETED` 不是 `WorkOrderStatus`、不进入 API/数据库，也不能从客户端回写；它只是一条显式的 `VERIFIED|CLOSED → COMPLETED` 展示映射。

### 9.2 请求竞态

用户从列表快速进入 A、返回、再进入 B，A 的晚响应不能覆盖 B。每次加载拥有 reportId 与 operationId；只有响应仍对应当前页面身份才更新状态。`finally` 中也应只关闭自己那次请求的 loading，避免旧请求把新请求的加载指示提前关掉。

轮询/前台刷新要有停止条件：页面不可见、工单终态、网络离线或错误预算达到时停止。若使用 SSE/订阅等机制，也必须处理断线恢复与版本去重；本章不强迫选择某种传输。

## 10. 补充、验证与反馈

完整报修端不仅创建：

- `POST /reports/{reportId}/supplements` 只追加文字/附件，不覆盖原始报修；
- `POST /reports/{reportId}/resolution-verifications` 只允许报修人对自己的 `RESOLVED` 工单按 `VERIFY/REJECT` 提交，拒绝需要原因并带版本；
- `POST /reports/{reportId}/feedback` 只对本人已闭环工单创建一次反馈。

这些写操作都使用独立幂等键。不能复用“创建报修”的键，也不能让客户端直接把工单改成 CLOSED。状态转换、角色、数据范围、版本和审计都由 Java 权威执行。

## 11. 服务端状态在 UI 中的统一模型

每个服务端资源至少区分：

```text
data        最后一次可信数据
loading     当前是否有请求
error       最近一次可展示错误
operationId 当前请求身份
updatedAt   数据证据时间
```

首次加载没有数据时显示骨架；已有数据刷新失败时可保留旧数据并标记可能过期；401 引导重新认证；403 不伪装成 404，除非服务端合同故意统一；未知状态显示“状态已更新，请刷新/升级”并上报安全合同错误。

`loading=false` 不代表请求成功，`data` 非空也不代表它是最新。组件使用派生视图，不在多处复制同一状态。

## 12. 跨端合同漂移

典型漂移：

- 后端把 `priority` 枚举改名，客户端仍发送旧值；
- 新字段变成必填，旧客户端无法创建；
- 状态增加但 UI switch 无 default；
- 上传 purpose 或绑定时机被客户端猜错；
- Problem 响应变形，客户端把永久错误当网络错误；
- `attachmentIds` 上限改变而表单仍允许更多。

防线从靠近源头到运行时：OpenAPI/schema 版本控制 → 生成或校验 TypeScript 类型 → fixture 合同测试 → 服务端兼容测试 → 体验版 E2E → 运行时边界解析与监控。TypeScript 编译通过不能证明网络 JSON 符合类型；外部输入仍需运行时验证。

发布中发现漂移，先确认真实 buildId、contractDigest 和响应，不要立即给客户端加 `as any`。修复后重跑原失败 fixture、旧客户端兼容场景和体验流程。

## 13. 权限失败的产品降级矩阵

| 能力 | 拒绝/不可用 | 核心流程 | 证据 |
|---|---|---|---|
| 扫码 | 提供手输不透明码 | 可继续 | 同一 resolve API 成功 |
| 相机/相册 | 允许无图提交或稍后补充 | 可继续 | 文字报修成功 |
| 位置 | 显示未附加，可手工描述 | 可继续 | 请求中无私自新增字段 |
| 通知 | 页面内查看进度 | 可继续 | mine/detail 可用 |
| 本地存储失败 | 明确提示不能离线保存 | 在线可尝试 | 不谎称已入队 |

真正必需的业务输入若缺失，应解释原因并停止相关动作；“降级”不是吞掉错误。每个拒绝分支必须在真机或受信平台模拟中验证，纯函数 fixture 只能验证决策矩阵。

## 14. 发布证据与监控关联

最终体验证据必须指向一个候选：

```json
{
  "commit": "<full-sha>",
  "buildId": "20260717.3",
  "artifactDigest": "sha256:<digest>",
  "contractDigest": "sha256:<openapi-digest>",
  "target": "mp-weixin",
  "environment": "production"
}
```

报修错误事件包含 buildId、routeTemplate、operation、受控 errorCode 和无业务含义 requestId；不得包含 token、设备码、assetId 原值、联系方式、描述、坐标或附件 URL。通过 requestId 在受控服务端查询连接客户端失败与事务结果。

回退验收不能只看旧页面出现。还要确认：新旧客户端均能调用服务端兼容合同；候选创建的离线命令不会在旧版重复执行；临时附件能清理/绑定；监控显示实际版本分布和关键成功率恢复。

## 15. 端到端验收矩阵

### 15.1 成功主线

1. 扫描合法码，只返回最小设备信息；
2. 登录报修人填写合法表单；
3. 可选上传一张允许附件，完成并通过安全状态；
4. 提交使用唯一且稳定幂等键；
5. API 返回一次 report/workOrder 与 `CREATED`；
6. 列表和详情只显示本人报修；
7. 监控事件/成功指标关联候选 buildId；
8. 数据库、审计、outbox 与附件绑定由后端验收证明一次副作用。

### 15.2 必测边界与失败

| 场景 | 期望 oracle |
|---|---|
| 码无效/撤销 | 统一匿名失败，不泄漏资产/租户 |
| 扫码权限拒绝 | 手输后能完成同一流程 |
| 位置拒绝 | 无位置仍可创建报修 |
| 上传失败/扫描拒绝 | 移除或重试附件，不重复创建报修 |
| 提交超时 | 原键重试返回同一结果 |
| 双击提交 | 一个 report、一个 workOrder、一个创建事件 |
| 同键不同正文 | 稳定 409，不覆盖原结果 |
| 断网提交 | 队列一条，恢复后一次确认 |
| 两个 drain 触发 | 单消费者/租约防止并行副作用 |
| 他人 reportId | 服务端拒绝，UI 不泄露缓存 |
| 快速切换详情 | 旧响应不覆盖当前页面 |
| 未知状态 | 安全 UI + 合同监控，不崩溃/不回写假状态 |
| 版本回退 | 核心流程恢复，离线/附件残余有记录 |

### 15.3 证据分层

- 纯函数：映射、队列分类、敏感字段 allowlist；
- 组件：输入、错误、焦点、重复点击；
- API 合同：请求/响应/schema/Problem；
- 集成：幂等记录、唯一约束、附件绑定、授权；
- E2E：真机宿主+真实测试后端+对象存储；
- 发布：同一 artifact 的体验、灰度、回退和监控。

不能用下层绿灯代替上层证据。配套 Node 脚本只在第一层及部分合同模拟层。

## 16. 四类故障的证据优先诊断

### 16.1 跨端字段漂移

症状：提交 400、字段为空或状态页崩溃。

先看真实 buildId/contractDigest → 网络响应与 Problem → OpenAPI/schema → 客户端运行时解析 → 源代码。修复后重跑原 fixture、旧客户端兼容与体验主线。不要用 `any` 或默认值隐藏未知语义。

### 16.2 重复工单

先取两次请求的主体、路由、幂等键、指纹、requestId 和服务端结果，再查 report/workOrder/outbox 行数。若客户端换键重试，修复提交意图生命周期；若服务端未原子保存结果，修复事务和唯一约束。按钮防抖不是最终修复。

### 16.3 权限失败无降级

检查能力调用时机、拒绝结果和 UI 状态；确认是否仍能手输/无附件/无位置提交。修复后用拒绝 fixture 与目标真机重跑，不能只把错误弹窗改成“已取消”。

### 16.4 版本与证据不一致

体验记录指向 build A，平台实际运行 build B 时，所有功能结论暂时失效。停止提升，确认 artifact digest 和平台版本，重新对实际候选执行验收。不能复制 A 的截图作为 B 的证据。

## 17. 配套资产使用方式

示例把扫码解析、附件就绪、提交意图、服务端幂等和状态映射组合成一个离线模型。实验注入：旧字段名、每次重试新键、相机拒绝后阻断、release buildId 不匹配。公开练习故意同时存在这些缺口：登记 starter 的 `verify.sh` 返回 41 与 `EXPECTED_RED`，正确答案由同一命令返回 0 与 `EXERCISE_GREEN`，部分修改、未知失败或基础设施异常返回 43；私有答案证明存在满足合同的解。

运行前先写预测；失败后看 oracle 输出的首个问题；只修改对应 fixture；用原命令重跑。不要把私有答案通过等同于真实 E2E。

真实项目验收还需：

- 从空环境安装依赖并构建目标平台；
- 开发者工具与至少一台目标真机；
- 隔离测试账号、测试租户、合法/撤销码；
- FactoryCare Java API、PostgreSQL、对象存储/扫描；
- 网络代理或故障注入；
- 平台体验版、真实 buildId 和监控查询；
- 回退演练及数据库副作用证据。

## 18. 120 秒讲解模板

1. 本章只集成既定合同，不重新发明平台/API/状态；
2. 设备码是不透明可轮换值，匿名解析只返回最小身份；
3. 附件经上传意图、对象上传、完成/扫描，再在创建报修事务中绑定 REPORT；
4. 每个提交意图保持同一幂等键与 payload，断网重放不能换键；
5. 报修状态由 Java 的 12 状态机权威返回，UI 映射不创造新状态；
6. 权限拒绝通过手输、无图、无位置等路径保持核心报修；
7. 竞态用 operation identity 防止旧响应覆盖；
8. 验收必须关联真实 artifact/buildId，离线脚本不能冒充真机发布证据；
9. 越界反例：客户端不能直接更新工单状态或自行指定租户。

## 19. 自测题

1. 为什么公开二维码不应直接编码 assetId/tenantId？
2. 为什么码要放请求 body，而不是 URL？
3. `attachmentIds` 在创建报修时需要满足什么状态和归属？
4. 上传 completion 超时后为什么不能直接创建第二份对象？
5. 位置权限被拒绝为什么不应阻断当前合同的核心流程？
6. 双击禁用为什么不能取代服务端幂等？
7. 提交超时后换新键会造成什么风险？
8. 两个离线 drain 同时启动需要什么保护？
9. UI 可以聚合状态文案，为什么不能把聚合值回写服务端？
10. 快速切换 reportId 时，旧请求的 `finally` 有什么竞态？
11. TypeScript 类型为什么不能证明响应 JSON 符合合同？
12. 真实 E2E 比配套 Node oracle 多验证哪些边界？
13. 回退后为什么还要检查候选版本产生的离线命令？
14. 怎样证明同键重试只创建一个 report/workOrder/outbox 事件？

## 20. 权威项目资料

- [FactoryCare 项目说明](../../../PROJECT_SPEC.md)
- [FactoryCare 公开 API 合同](../../../factorycare-design/contracts/public-api.yaml)
- [FactoryCare 数据模型](../../../factorycare-design/data/data-model.md)
- [FactoryCare 验收目录](../../../factorycare-design/testing/acceptance-catalog.md)

平台资料复核日期为 2026-07-24。集成章不能只写“沿用前置章节”，下列官方页面直接支持本章实际使用的平台边界：

- DCloud，[条件编译处理多端差异](https://uniapp.dcloud.net.cn/tutorial/platform.html)：目标专用代码与跨端适配边界。
- DCloud，[`uni.scanCode`](https://uniapp.dcloud.net.cn/api/system/barcode)：扫码结果、取消/失败和平台兼容表面。
- DCloud，[`uni.uploadFile`](https://uniapp.dcloud.net.cn/api/request/network-file)：附件上传、UploadTask、进度与取消表面。
- DCloud，[`uni.getLocation`](https://uniapp.dcloud.net.cn/api/location/location)：可选位置、坐标系、精度和平台配置表面。
- 微信开放文档，[用户隐私保护指引填写说明](https://developers.weixin.qq.com/miniprogram/dev/framework/user-privacy/)：微信小程序隐私声明表面。

本次只完成项目合同与官方文档核对；没有执行真实 uni-app/微信构建、扫码/定位/上传、平台隐私授权、FactoryCare Java API、对象存储、断网重放、真机 E2E 或发布回退。项目字段、12 状态、附件目的和幂等语义以同一发布候选冻结的 FactoryCare 合同为准，平台行为则必须在实际构建/发布日重新验证。
