---
schema_version: 2
edition: 2026.2-draft
id: ch.uniapp.offline-idempotency
title: 离线队列、重试、冲突与幂等重放
responsibility: 为离线报修定义持久队列、幂等键、有限重试和冲突决策，保证重放不重复创建且失败可观察，不把缓存等同离线同步。
volume: '10'
order: 9
level: L3
status: drafting
path: book/volume-10-uniapp-miniprogram/chapters/ch.uniapp.offline-idempotency.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.uniapp.platform-conditional
- ch.uniapp.packages-performance
- ch.architecture.idempotency-concurrency
version_surfaces:
- uni-app
- wechat-miniprogram
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“离线队列、重试、冲突与幂等重放”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - mobile-offline-queue
  - mobile-idempotency-conflict
  covers_topics:
  - mobile.offline-command
  - mobile.durable-queue
  - mobile.replay-order
  - mobile.retry-backoff
  - mobile.queue-observability
  - mobile.idempotency-key
  - mobile.duplicate-response
  - mobile.conflict-detection
  - mobile.conflict-resolution
  - mobile.poison-command
  uses_capabilities:
  - mobile.uniapp-platform
  - architecture.idempotency-consistency
  - mobile.uniapp-offline-idempotency
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现可持久化报修命令队列并用断网、重启和重复响应验证幂等重放；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - mobile-offline-queue
  - mobile-idempotency-conflict
  covers_topics:
  - mobile.offline-command
  - mobile.durable-queue
  - mobile.replay-order
  - mobile.retry-backoff
  - mobile.queue-observability
  - mobile.idempotency-key
  - mobile.duplicate-response
  - mobile.conflict-detection
  - mobile.conflict-resolution
  - mobile.poison-command
  uses_capabilities:
  - mobile.uniapp-platform
  - architecture.idempotency-consistency
  - mobile.uniapp-offline-idempotency
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: offline-online-simulation-duplicate-replay-test-conflict-fixture
- id: diagnose
  kind: fault-diagnosis
  text: 面对“随机幂等键重建、无限重试或队头毒消息阻塞全队列”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - mobile-offline-queue
  - mobile-idempotency-conflict
  covers_topics:
  - mobile.offline-command
  - mobile.durable-queue
  - mobile.replay-order
  - mobile.retry-backoff
  - mobile.queue-observability
  - mobile.idempotency-key
  - mobile.duplicate-response
  - mobile.conflict-detection
  - mobile.conflict-resolution
  - mobile.poison-command
  uses_capabilities:
  - mobile.uniapp-platform
  - architecture.idempotency-consistency
  - mobile.uniapp-offline-idempotency
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 离线队列、重试、冲突与幂等重放

> 本章状态为 `drafting`。配套资产在内存/JSON 快照中模拟断网、进程重启、重复响应、401、409 和毒消息；没有依赖真实 uni-app storage、后台任务、微信网络监听或 FactoryCare 服务端幂等表。离线绿灯证明状态机模型，不证明目标宿主能在后台可靠执行。

缓存保存“以后可以重新读取的值”；离线队列保存“以后必须尝试执行、且不能重复产生业务效果的命令”。两者不是一回事。把 POST payload 随手塞进 storage 并在联网时循环发送，会造成重复工单、重试风暴、跨用户泄露、旧合同崩溃和队头阻塞。本章从服务端幂等合同出发，设计客户端持久命令与可观察重放。

## 1. 完成定义、入口与非目标

完成本章后，你应能：

1. 区分读取缓存、草稿和可重放业务命令；
2. 为命令建立稳定 id、幂等键、schema、用户/环境绑定与状态；
3. 解释为什么重试必须复用原幂等键；
4. 用持久化写入顺序应对进程突然终止；
5. 为暂时失败设计有限退避、抖动与停止条件；
6. 区分 401、409、重复响应、校验失败与未知超时；
7. 隔离毒消息，避免一条永久失败阻塞全部队列；
8. 让用户/运维看见等待、失败、冲突和人工处置。

配套入口：

- [持久队列与幂等重放示例](../../../examples/encyclopedia/ch.uniapp.offline-idempotency/README.md)
- [随机键、无限重试和毒消息实验](../../../labs/encyclopedia/ch.uniapp.offline-idempotency/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.uniapp.offline-idempotency/README.md)

本章不承诺 exactly-once 网络传输，不在客户端解决服务端跨资源事务，不允许后台无限唤醒，也不默认启用离线创建。若业务/平台无法满足幂等与安全存储，诚实的“仅保存草稿，联网后用户确认提交”更安全。

## 2. 先理解“至少一次尝试、至多一次业务效果”

网络在服务端完成写入后、响应到客户端前断开：客户端不知道成功还是失败。若不重试，用户可能丢工单；若重新生成新请求，可能重复创建。客户端无法仅凭超时判断。

```text
客户端 ── POST(key=K) ──→ 服务端创建 WO-1
客户端 ←── 响应在途中丢失 ── 服务端
客户端 ── POST(key=K) ──→ 服务端返回同一结果 WO-1
```

传输可以发生多次，服务端使用同一个幂等键和请求指纹，将相同命令映射为同一业务结果。这是“重复投递可接受、业务效果不重复”。如果客户端重试时生成 K2，服务端无法知道是同一意图。

### 2.1 幂等需要双方合同

客户端负责：首次创建命令时生成键并持久化；每次重放复用；payload 变化时不能冒充同一请求；处理重复响应。服务端负责：原子记录键/主体/请求指纹/状态/结果；并发相同键只执行一次；相同键不同 payload 拒绝；保留期覆盖客户端最大重试窗口；授权和租户隔离。

没有服务端支持，客户端“只点一次按钮”不等于幂等。

## 3. 离线命令的结构

```ts
type OfflineCommand = {
  commandId: string
  schemaVersion: 1
  type: 'CREATE_WORK_ORDER'
  idempotencyKey: string
  environment: 'test' | 'production'
  subjectHash: string
  tenantId: string
  createdAt: string
  payload: CreateWorkOrderInput
  payloadHash: string
  state: 'pending' | 'in-flight' | 'waiting-retry' | 'blocked-auth' | 'conflict' | 'dead-letter'
  attemptCount: number
  nextAttemptAt: string | null
  lastErrorCode: string | null
}
```

`commandId` 标识本地记录，`idempotencyKey` 标识服务端业务意图；二者可以不同，但都在命令首次产生时固定。`payloadHash` 帮助发现“同一键 payload 被编辑”。subject/tenant/environment 防止切账号或切环境后把旧命令发到错误上下文。

不要持久化 access token；重放时从当前认证状态取得有效凭据，并验证当前主体与命令归属一致。日志只输出 commandId、键的不可逆摘要、状态和稳定错误码，不输出 payload、token、精确位置或附件路径。

## 4. 写入顺序与进程崩溃

用户点击“离线保存报修”时：

1. 校验输入并建立不可变 payload；
2. 生成 commandId/idempotencyKey/hash；
3. 把完整 `pending` 命令持久化；
4. 确认写入成功；
5. 才向用户显示“已保存，等待同步”；
6. 若在线，可触发调度器。

不能先显示成功、后异步写 storage；进程可能在两者之间退出。写入失败必须可见，并保留用户输入让其复制/重试。

执行前将状态持久化为 `in-flight`。若进程此时崩溃，重启恢复时把超时的 `in-flight` 视为“不确定，需要用同一键查询/重放”，不能生成新键。状态写入和读取本身也可能失败，需要 schema 与损坏恢复。

## 5. 调度器不是 `while(true)`

触发来源可以是：应用启动/恢复、网络从离线变在线、用户主动“立即同步”、有限定时器。平台可能暂停后台执行，所以不能承诺离开应用后立刻同步。

```text
trigger
  ↓ 单实例锁
读取到期 pending/waiting-retry
  ↓ 认证与归属检查
按策略选择命令
  ↓ 标记 in-flight 并持久化
发送（复用幂等键）
  ↓ 分类结果并持久化
安排下一次有限触发 / 停止
```

同一时刻只允许一个调度器拥有队列，或使用明确租约；否则应用恢复与网络事件可能并发重放同一命令。即便发生并发，服务端幂等仍是最后防线。

## 6. 重放顺序

全局严格 FIFO 简单但危险：第一条永久失败会阻塞所有命令。完全并发又可能破坏同一实体的因果关系。常见策略是“按依赖/聚合键保持顺序，不相关命令有限并发”。

创建工单通常彼此独立，但附件命令可能依赖工单/草稿 id。最简单的首版可以把创建请求和已上传附件引用作为一个命令，避免跨命令依赖；或者显式记录 `dependsOnCommandIds` 并验证无环。

每条命令独立进入 dead-letter，调度器继续处理不依赖它的其他命令。若后续命令依赖失败命令，则标记 `blocked-dependency`，不能偷偷跳过关系。

## 7. 结果分类与动作

| 结果 | 队列动作 | 是否自动重试 |
|---|---|---|
| 2xx 首次成功 | 保存结果并移除/归档 | 否 |
| 相同键重复结果 | 当作完成，核对 payloadHash/结果 | 否 |
| 传输超时/断网 | `waiting-retry` | 有限 |
| 5xx/429 | 按服务端提示和预算退避 | 有限 |
| 401 | `blocked-auth`，刷新/重新登录 | 不在无凭据时循环 |
| 403 | `dead-letter` 或人工处置 | 通常否 |
| 400/422 校验 | `dead-letter`，允许用户复制修正为新命令 | 否 |
| 409 业务冲突 | `conflict`，展示差异/策略 | 否 |
| 同键不同 payload | 严重合同错误 | 否 |

HTTP 分类仍需结合服务端问题类型。不能仅凭 409 一律重试，也不能把 401 当网络失败。

## 8. 退避、抖动和重试预算

指数退避示意：

```text
delay = min(cap, base × 2^attempt) + jitter
```

抖动避免大量设备同时联网后齐刷刷请求。真实算法需可测试随机源。还要有：最大尝试次数、最大命令年龄、下一次时间、每次会话上限、服务端 `Retry-After`（适用时）和用户主动重试规则。

“最多 5 次”不是唯一答案；按错误类型和业务时效决定。超过预算进入 dead-letter，不再自动唤醒，但用户可以看到并处置。重试计数/时间必须持久化，重启不能清零，否则仍是无限重试。

## 9. 401：暂停队列，不是给每条命令刷新 token

多个命令同时 401 时，若每条都刷新会形成风暴。队列进入认证阻塞：由单一认证协调器刷新/重新登录；成功后确认 subject/tenant 未变化再继续；失败则保持 `blocked-auth` 并提示用户。

用户 A 退出、用户 B 登录后，A 的命令不能由 B 发出。可按主体分区保留并提示，或按产品政策清理/导出；绝不能仅换 token 重放。

## 10. 409 冲突不是“再试一次”

冲突表示客户端基于旧版本操作，或业务状态已变化。服务端应返回稳定类型、当前版本/允许动作和关联资源（按授权）。客户端进入 `conflict`：

- 创建命令若返回“同一幂等键已完成”，应恢复原结果，不是冲突；
- 设备已停用，用户可能选择取消离线命令或改选设备；
- 工单字段变更需要显示本地意图与服务端当前值；
- 自动合并只用于证明安全的字段；
- 用户修正后生成**新命令/新幂等键**，原命令归档为 superseded。

不要修改原 payload 后继续用旧键。

## 11. 毒消息与 dead-letter

毒消息是每次执行都永久失败的命令，例如旧 schema、非法设备、丢失附件。若它永远排在队头并立即重试，会阻塞队列与耗电。

进入 dead-letter 的条件和信息：commandId、类型、创建/最后尝试时间、attemptCount、稳定错误码、可恢复动作、原 payload 的受控本地引用。UI 提供“查看原因、复制/修正为新草稿、删除”。删除敏感命令应符合产品/保留政策，并留下不含 payload 的审计事件。

dead-letter 不等于吞错；队列概览必须显示数量，遥测按错误码聚合，运维能发现版本升级造成大面积毒消息。

## 12. 队列可观察性

建议指标：

- pending/in-flight/waiting/conflict/dead-letter 数量；
- 最老 pending 年龄；
- attempt 分布；
- 同步成功/重复恢复/冲突/永久失败率；
- 401 阻塞时长；
- 从离线创建到服务端确认的延迟；
- 版本/目标/错误码分布。

日志事件包含 `QUEUE_ENQUEUED/REPLAY_STARTED/REPLAY_DEFERRED/REPLAY_COMPLETED/CONFLICT/DEAD_LETTER`。严禁 payload、位置、附件原文、token。idempotencyKey 仅摘要，且要评估摘要是否仍可关联个人。

## 13. 持久化和 schema 升级

队列 envelope 自己有 schema，命令 payload 也可能有 schema。升级时先用旧 fixture 测迁移；无法安全迁移的命令进入人工处置，不能丢弃或盲发。

写入最好采用“读当前→构造完整新快照→原子/替换写”语义；具体 storage 是否原子由平台决定。多次写中途失败可能导致损坏，需校验 checksum/shape 和备份策略。队列有容量预算；达到上限应阻止新增并提示，而不是淘汰未完成命令像普通缓存。

敏感离线 payload 的本地保护需要安全评估；普通 `uni.setStorage` 不是安全 vault。若无法保护包含位置/描述/附件的命令，缩小 payload、仅存草稿或禁用离线提交。

## 14. 断网、重启与重复重放测试

最小矩阵：

1. 离线入队，重启后命令仍在且键相同；
2. 在线发送成功，响应丢失，重启后同键重放只产生一个工单；
3. 同一键并发两次，服务端只执行一次且返回同结果；
4. 同键不同 payload 被拒绝；
5. 401 暂停队列，认证恢复后继续；
6. 409 进入 conflict，不自动重试；
7. 5xx 按持久退避，重启不重置 attempt；
8. 毒消息进入 dead-letter，后续独立命令继续；
9. 切换用户/环境不重放旧命令；
10. storage 损坏/满时不显示假成功。

服务端测试要断言数据库/幂等记录，而不仅客户端最终 UI。

## 15. 三个典型故障

### 15.1 每次重放生成随机幂等键

第一证据是同一 commandId 的请求日志出现多个 key 摘要，服务端产生多条工单。修复：键成为持久命令不可变字段，在 enqueue 时唯一生成；重放只读取。用响应丢失夹具重跑。

### 15.2 无限重试

第一证据是 attemptCount 重启后归零、nextAttemptAt 不存在或同错误无停止条件。修复持久预算/退避/dead-letter，测试长时间与多次重启。

### 15.3 队头毒消息

第一证据是最老命令反复失败，后续独立命令从未被选择。修复调度器按状态/依赖选择，并隔离永久失败。若后续确实依赖它，显示 blocked-dependency。

## 16. FactoryCare 首版决策

离线创建会显著增加客户端、服务端和运维复杂度。建议分阶段：

1. 首版：离线只保存版本化本地草稿；联网后用户确认并在线提交；
2. 服务端幂等表、重复响应、冲突问题类型和可观察性先完成；
3. 再启用单一 `CREATE_WORK_ORDER` 持久命令，不含复杂附件依赖；
4. 真实目标验证断网/重启/账号切换；
5. 达到门禁后才扩展其他命令。

这是长维护性优先：不为了“离线功能”在没有服务端合同的情况下伪造队列。

## 17. 状态转移必须显式

一条命令的合法转移可以写成表，而不是散落 if：

| 当前状态 | 事件 | 下一状态 | 持久化信息 |
|---|---|---|---|
| 新建 | `ENQUEUE` | `pending` | 完整命令、固定键、attempt=0 |
| `pending` | `START` | `in-flight` | lease/startedAt |
| `in-flight` | `SUCCESS` | `completed` | workOrderId、结果摘要 |
| `in-flight` | `DUPLICATE_SUCCESS` | `completed` | 恢复的同一结果 |
| `in-flight` | `TEMPORARY_FAILURE` | `waiting-retry` | attempt+1、nextAttemptAt、code |
| `in-flight` | `UNAUTHENTICATED` | `blocked-auth` | code，不增加紧密循环 |
| `in-flight` | `CONFLICT` | `conflict` | 服务端版本/允许动作摘要 |
| `in-flight` | `PERMANENT_FAILURE` | `dead-letter` | code、人工恢复动作 |
| `waiting-retry` | `DUE` | `in-flight` | 新 lease，键不变 |
| `blocked-auth` | `AUTH_RESTORED` | `pending` | 先核对 subject/tenant |
| `conflict` | `SUPERSEDE` | `superseded` | 新命令 id 引用 |

任何未列转移都应失败并留下诊断。例如 `completed → in-flight` 不合法；`dead-letter → pending` 若要支持，必须通过显式“用户重试”动作，重新校验 payload 和归属，通常生成新命令。

### 17.1 纯 reducer 与副作用解释器

把 `transition(command, event)` 写成纯函数，返回 `{next, effects}`。effects 可能是 `PERSIST`、`SEND`、`SCHEDULE`、`NOTIFY_USER`，由外层解释器执行。这样单元测试可以覆盖所有状态，不需要真的断网。外层再测试“先持久化还是先发送”的顺序。

若 persist 失败，不得执行 send；若 send 完成但保存结果失败，恢复时仍用同键重放并从服务端取原结果。这体现服务端幂等是最终防线。

## 18. 服务端幂等记录的最小语义

概念表（不是固定数据库设计）：

```text
tenant_id + subject_id + idempotency_key   唯一
request_fingerprint
operation_type
state: processing/completed/failed-replayable
response_status
response_reference / response_body_snapshot
created_at / expires_at
```

接收请求时在事务边界内尝试占有键。若首次出现，校验 fingerprint 后执行业务并保存结果；若 processing，返回受控“仍在处理”或等待策略；若 completed，返回同一业务引用；若键相同但 fingerprint 不同，返回明确合同错误。不要先查“键不存在”再无锁插入，那会在并发下双执行。

结果快照必须权衡隐私和变化：保存完整响应可能包含敏感数据；只存 workOrderId 可在授权后重新读取。过期时间不能短于客户端可能重放的最长窗口，否则旧命令在记录清理后会再次生效。删除幂等记录要与业务保留、队列最大年龄一起设计。

### 18.1 客户端怎样识别重复成功

服务端可以通过状态码/问题类型/响应字段表明 `replayed=true`，但客户端核心判据是得到与原命令对应的权威资源。重复成功不是错误，不应再次创建本地临时工单。核对 command id/键摘要、业务 id、租户和 payload fingerprint；若服务端结果与本地意图不一致，进入合同错误而不是覆盖。

## 19. 调度伪代码与锁

```ts
async function drainQueue(trigger: Trigger): Promise<void> {
  const lease = await queue.tryAcquireLease('replay', clock.now())
  if (!lease) return
  try {
    while (lease.valid(clock.now())) {
      const command = await queue.nextDue(clock.now())
      if (!command) return
      const context = await auth.currentContext()
      if (!belongsTo(command, context)) {
        await queue.blockForIdentity(command.commandId)
        continue
      }
      await queue.markInFlight(command.commandId, lease.id)
      const outcome = await sender.send(command, context)
      await queue.applyOutcome(command.commandId, outcome)
    }
  } finally {
    await queue.releaseLease(lease.id)
  }
}
```

这是职责示意。真实实现要处理 lease 续期、storage 错误、页面终止和并发触发。`nextDue` 只返回到期、非阻塞命令；每轮有最大数量/时间，防止应用恢复时长时间占用主线程或网络。

### 19.1 公平性

如果一条命令不断临时失败，`nextDue` 根据 nextAttemptAt 会让其他到期命令执行。对租户/聚合可轮转，避免某一组占满。并发度从 1 开始，测量后再有限提高；小程序网络、服务端限流和电量都不是无限资源。

## 20. 用户界面不是“正在同步”一个布尔值

队列概览可以显示：等待同步 N、需要登录 N、冲突 N、失败待处理 N；每条显示创建时间、非敏感摘要、当前状态和动作。

- pending/waiting：允许取消本地命令（确认后）；
- blocked-auth：登录后继续，不能让用户 B 代发；
- conflict：查看服务端变化，选择放弃或以新命令修正；
- dead-letter：说明不可自动恢复，允许复制为新草稿/删除；
- completed：显示权威工单 id，不继续留在待同步。

不要用“已提交”描述仅入队；准确文案是“已保存在本机，联网后同步”。应用卸载可能丢失本地队列，需在产品承诺中说明。关键报修若不能容忍，应要求联网确认或提供其他渠道。

### 20.1 手动重试也受预算

用户点击“重试”可以提前 nextAttemptAt，但不能绕过身份、冲突或永久校验，也不能生成新键。按钮防连点，显示最近错误。服务器 429/维护窗口时尊重恢复时间。

## 21. 威胁与滥用边界

本地队列内容不可信：设备可被篡改、storage 可损坏。服务端每次重放都重新认证、授权、验证 schema/业务规则和附件，不因带幂等键就信任。幂等键不是认证凭据，也不应允许仅凭键读取他人结果。

攻击者可制造大量离线命令消耗存储/请求；客户端设容量，服务端限流/配额并按主体审计。键需足够不可预测以减少碰撞，但安全仍来自授权。不要把连续本地 command id 当全局秘密。

包含个人信息的 payload 要最小化、设置本地保留期和删除路径；日志与 crash report 不包含 payload。设备丢失/共享设备的风险需纳入产品决策。若平台没有满足要求的保护，不启用敏感离线队列。

## 22. 证据包模板

```text
scenario: response-lost-after-server-commit
commandId: local-7
idempotencyKeyHash: sha256:...
payloadHash: sha256:...
timeline:
  - offline enqueue persisted
  - online replay attempt=1
  - server commit workOrderId=WO-9
  - client response dropped
  - process restarted
  - replay attempt=2 same key
  - server returned WO-9 replayed
assertions:
  businessRows: 1
  finalQueueState: completed
  automaticAttempts: 2
```

证据包保存输入类别、时间线、命令/键摘要、服务端业务行数和最终队列状态。真实用户文本、位置、token 不入包。每个关键场景都能在假服务器和集成环境重复；真机再补生命周期/持久化证据。

## 23. AI/Vibe coding 验收

检查 AI 生成方案：幂等键是否在 enqueue 时持久化；重放是否复用；是否有 payloadHash；attempt/nextAttempt 是否持久；401 是否单飞；409 是否停止；是否有限重试/dead-letter；毒消息会否阻塞；切用户/环境怎样隔离；日志是否泄露；服务端是否原子处理重复。

若模型声称“使用 UUID 所以不会重复”，这是错误：每次重试新 UUID 正是重复来源。若它用 `setInterval` 永久扫描，也要补生命周期、单实例、退避、后台限制和停止条件。

## 24. 120 秒复述模板

离线命令不同于缓存：它代表必须以后执行的业务意图。首次入队时生成并持久化 commandId、幂等键、payloadHash、用户/租户/环境和状态；每次重放复用原键。网络只能做到重复尝试，服务端原子幂等保证至多一次业务效果。错误按超时/5xx/401/校验/409/重复结果分类，只有暂时错误有限退避；重试预算持久化。409 进入人工冲突，毒消息进入 dead-letter，不能阻塞独立命令。队列必须可观察，切账号不能重放旧主体命令。

越界反例：“联网事件触发后遍历 storage 里的 POST，每次生成 UUID，失败立即无限重试，第一条成功前不处理下一条。”它会重复创建、重试风暴和队列死锁。

## 25. 事实与未验证范围

本章稳定核心来自分布式系统幂等、至少一次投递、退避、冲突和 durable queue 原理；目标平台仅影响持久化、网络/生命周期触发和后台能力。实施时仍需核对 uni-app/微信当前 storage、网络状态和任务限制。

当前未验证：真实 storage 原子性/配额/加密、微信进程恢复、后台执行、网络事件、服务端幂等表与事务、附件依赖、真实 401/409/429、跨版本迁移和 FactoryCare 数据。配套模型不支持发布。
