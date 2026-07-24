---
schema_version: 2
edition: 2026.2-draft
id: ch.architecture.idempotency-concurrency
title: 幂等键、乐观并发、重复提交与重放
responsibility: 教授在数据库与应用事务边界抵御重复和并发覆盖，不承诺跨消息系统的恰好一次
volume: '06'
order: 14
level: L2+
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.architecture.idempotency-concurrency.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.architecture.workflow-state-sla
- ch.spring.transactions
- ch.java-engineering.threads-jmm
version_surfaces:
- spring-boot-4.1
- postgresql-18
- mybatis
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
  text: 在 120 秒内解释幂等键、乐观并发、重复提交与重放的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - architecture-idempotency
  - architecture-concurrency
  covers_topics:
  - architecture.idempotency-key
  - architecture.request-deduplication
  - architecture.replay-result
  - architecture.optimistic-lock
  - architecture.lost-update
  - architecture.retry-conflict
  uses_capabilities:
  - architecture.domain-invariants
  - data.transactions-locks
  - backend.spring-persistence-tx
  - java.concurrency-runtime
  - architecture.idempotency-consistency
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现带 Idempotency-Key 和 version 乐观锁的分派 API，保存首次响应并对重复/并发请求返回同结果或明确冲突
  covers_topic_groups:
  - architecture-idempotency
  - architecture-concurrency
  covers_topics:
  - architecture.idempotency-key
  - architecture.request-deduplication
  - architecture.replay-result
  - architecture.optimistic-lock
  - architecture.lost-update
  - architecture.retry-conflict
  uses_capabilities:
  - architecture.domain-invariants
  - data.transactions-locks
  - backend.spring-persistence-tx
  - java.concurrency-runtime
  - architecture.idempotency-consistency
  evidence_kind: system-artifact-and-negative-tests
  verification_mode: system-security-resilience-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入先执行业务后记录 key、相同 key 不同 payload 和忽略 update=0，使用并发屏障复现重复/丢更新后修复
  covers_topic_groups:
  - architecture-idempotency
  - architecture-concurrency
  covers_topics:
  - architecture.idempotency-key
  - architecture.request-deduplication
  - architecture.replay-result
  - architecture.optimistic-lock
  - architecture.lost-update
  - architecture.retry-conflict
  uses_capabilities:
  - architecture.domain-invariants
  - data.transactions-locks
  - backend.spring-persistence-tx
  - java.concurrency-runtime
  - architecture.idempotency-consistency
  evidence_kind: fault-injection-fix-rerun
  verification_mode: fault-injection-rerun
---
# 幂等键、乐观并发、重复提交与重放

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《状态机、状态转换、SLA 与超时语义》](ch.architecture.workflow-state-sla.md)：独立完成幂等与重放、并发控制前，必须先具备「状态机、状态转换、SLA 与超时语义」已经验证的知识与失败边界
- [《@Transactional、传播、回滚、隔离与提交后行为》](../../volume-05-spring-backend/chapters/ch.spring.transactions.md)：独立完成幂等与重放、并发控制前，必须先具备「@Transactional、传播、回滚、隔离与提交后行为」已经验证的知识与失败边界
- [《线程、Java 内存模型、同步与锁》](../../volume-03-java-engineering/chapters/ch.java-engineering.threads-jmm.md)：独立完成幂等与重放、并发控制前，必须先具备「线程、Java 内存模型、同步与锁」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套资产以 JDK 25 内存模型和可控并发屏障验证协议预言，不启动 Spring Boot、MyBatis、PostgreSQL 或 Testcontainers。它能证明“同键同请求重放、异请求冲突、过期版本拒绝”的逻辑，不证明真实唯一约束、隔离级别、事务代理、连接池或跨进程故障窗口已经关闭。

用户双击一次、移动端离线重放一次、网关超时自动重试一次，可能产生三个外观相同的请求。与此同时，两名调度员可能都基于 version 7 派同一张工单。前者是“同一意图被重复交付”，后者是“不同意图竞争同一旧状态”。幂等记录解决重复交付，乐观并发解决过期写入；二者必须同时存在，任何一方都不能代替另一方。

## 1. 完成定义与证据入口

完成本章后，应能：

1. 区分 HTTP 方法幂等、业务命令幂等、请求去重、响应重放与消息消费幂等；
2. 定义 `Idempotency-Key` 的作用域、请求指纹、状态、响应快照和保留期；
3. 让同 key + 同 payload 返回首次结果且不重复副作用；
4. 让同 key + 不同 payload 明确冲突，不能返回旧请求的结果；
5. 在业务副作用前原子声明 key，并让声明、状态写入、审计/outbox 与最终响应记录处于可解释事务边界；
6. 使用 version 条件更新防止丢失更新，把影响行数 0 映射为明确冲突；
7. 解释冲突后何时可安全重试，何时必须刷新并由人重新决定；
8. 使用并发屏障让两个旧版本写同时到达，稳定证明只有一个提交；
9. 说明为什么这些机制不等于跨数据库、消息系统和外部服务的 Exactly Once。

配套入口：

- [幂等/并发示例](../../../examples/encyclopedia/ch.architecture.idempotency-concurrency/README.md)
- [重复与丢更新故障实验](../../../labs/encyclopedia/ch.architecture.idempotency-concurrency/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.architecture.idempotency-concurrency/README.md)

## 2. 先把两个问题分开

### 2.1 重复提交：一个意图送达多次

客户端发送创建报修，服务端已经提交，但响应在网络中丢失。客户端不知道结果，只能重试。若服务端把第二次当新命令，就会创建两张工单。此时请求内容相同、业务意图相同，系统需要识别“这是第一次命令的重放”。

重复不一定来自坏用户。浏览器双击、移动弱网、反向代理重试、客户端超时、任务 redelivery、进程恢复都可能产生。只在按钮点击后禁用 UI 不能形成服务器保证，因为攻击者、另一个客户端或网络组件都可绕过 UI。

### 2.2 并发覆盖：不同意图基于同一旧版本

两个调度员都读到工单 version 7。甲派给 team A，乙派给 team B。若两条 SQL 都是 `UPDATE work_order SET team_id=? WHERE id=?`，后提交者静默覆盖前者，最终没人知道甲的成功响应已经过期。这是 lost update。

两次请求可能使用不同幂等键，所以去重不会阻止它们；它们确实是两个不同意图。系统必须验证“你基于的 version 仍是当前 version”。

### 2.3 组合关系

分派 API 的正确顺序是：先识别是否为已处理的同一请求；若是，重放首次结果。若是新请求，再校验 expectedVersion 并竞争提交。这样同一 key 的网络重试不会因为 version 已经增加而错误返回冲突，而另一个 key 的过期命令仍会被拒绝。

## 3. “幂等”不是所有输出都一模一样

RFC 9110 把 HTTP 方法幂等定义为：多个相同请求的“预期服务器效果”与单次相同。PUT、DELETE 和安全方法按规范具有这种语义，但服务器仍可为每次请求追加日志。POST 默认不幂等，不过应用可以用额外协议让一个具体 POST 命令可安全重试。

业务幂等关注受保护副作用：同一报修意图不能产生第二张工单、第二条 outbox 或第二次扣减。响应重放比“副作用没重复”更强：客户端重试应得到首次保存的 status、业务 ID、版本和稳定 body，而不是从当前可变资源重新拼一份看似成功但内容不同的响应。

去重也不等于把“看起来相似”的请求合并。两次相同描述但由用户明确提交的不同报修，若 key 不同，就是两个意图；按 payload 哈希全局去重会误删合法业务。key 标识客户端声明的同一命令，fingerprint 用来防止 key 被错误复用，不负责猜测相似业务。

## 4. Idempotency-Key 的完整身份

### 4.1 key 不能脱离作用域

数据库唯一键至少应覆盖可信 tenant、actor/客户端主体、规范化路由/操作和 idempotency key，具体范围由 API 合同决定。例如：

```text
(tenant_id, actor_id, operation, idempotency_key)
```

若全平台只对 key 唯一，两个租户偶然使用 `CMD-1` 会互相碰撞。若只按 tenant + key，而同一客户端在“创建报修”和“追加工时”复用 key，也可能重放错误类型的响应。不要把原始完整 URL（含不稳定 query）直接当 operation；使用受控 operation ID 或规范路由。

key 要有长度、字符和数量限制，不能把它当秘密或授权凭据。拿到别人的 key 不应获得别人的结果；查询仍绑定认证主体和租户。日志可以记录短摘要或安全标识，不需要输出完整高熵值。

### 4.2 请求指纹绑定语义

同一作用域/key 第一次请求保存 `request_fingerprint`。后续请求：

- fingerprint 相同：等待首次处理完成或重放已保存结果；
- fingerprint 不同：返回稳定的 idempotency conflict；
- 记录不存在：尝试原子创建处理声明。

fingerprint 必须来自业务语义的规范表示。直接哈希原始 JSON 字节会把字段顺序、空白或等价默认值误判为不同；随意忽略字段又可能把不同意图判为相同。常见做法是先完成 DTO 解析、默认值决定和受控 canonicalization，再对 operation + 关键字段形成摘要。认证得到的 tenant/actor 属于 scope，不信任 body 中自报的 tenant。

敏感字段不可为了排查而把原文存入幂等表。保存最小摘要、算法/规范版本和必要业务引用；算法变更时保留版本，否则旧 key 无法解释。

### 4.3 IETF 文档状态边界

`Idempotency-Key` 曾有 IETF HTTPAPI 工作组草案，描述 key 唯一、不得与不同 payload 复用、资源应公布过期策略等实践。但截至 2026-07-17，Datatracker 显示 revision 07 已于 2026-04-18 过期并归档，它不是已发布 RFC。本章把这些内容作为有用的协议设计参考，不把草案措辞冒充互联网标准。FactoryCare 的 header 与冲突语义由自身 OpenAPI/项目合同负责。

## 5. 幂等记录至少保存什么

一个可解释的 `idempotency_record` 可包含：

| 字段 | 目的 |
| --- | --- |
| tenant/actor/operation/key | 唯一作用域与授权绑定 |
| request fingerprint + algorithm version | 判断同意图或 key 误用 |
| processing state | `IN_PROGRESS / COMPLETED` 等受控状态 |
| owner/lease 或创建事务信息 | 处理并发与崩溃恢复 |
| HTTP status / stable error code | 重放首次协议结果 |
| response body snapshot 或不可变结果引用 | 保持重试响应一致 |
| aggregate ID/version | 关联业务结果与排障 |
| created/completed/expires at | 保留、清理与不确定窗口 |

不要只存 `key -> resourceId` 后每次读取当前资源。资源之后可能被更新，重放就会返回不同 version/status，客户端无法判断首次命令到底得到什么。若响应很大，可以保存稳定结果所需的不可变快照或版本化引用，但必须定义资源删除后的行为。

并非所有失败都应永久保存。确定性业务拒绝（例如 payload 与 key 冲突）可稳定返回；临时基础设施失败、事务未开始或未知提交状态需要专门策略。不能把随机 500 永久缓存，也不能在提交可能成功时删除记录让重试重复副作用。错误分类是协议的一部分。

## 6. 必须先声明，再产生副作用

### 6.1 最危险的顺序

```text
创建工单
写 outbox
最后插入 idempotency_record
```

如果进程在第二步后崩溃，重试看不到 key，会再次创建。即使最后插入有唯一约束，也只能防重复记录，防不了已经发生的两个业务副作用。

另一个危险写法是先 `SELECT key`，没查到后做业务，再 `INSERT key`。两个并发请求可以同时没查到。应用层的“先查”不是互斥，唯一约束/原子 insert 才是争用裁判。

### 6.2 本地数据库事务内的安全骨架

对业务状态、幂等记录、核心审计和 outbox 都在同一 PostgreSQL 数据库的命令，可以在一个 Spring 事务中：

1. 尝试插入 `(scope,key,fingerprint,IN_PROGRESS)`，由唯一约束竞争；
2. 若已存在，读取并比较 fingerprint；
3. 不同 fingerprint 返回冲突；相同且完成则重放；相同且处理中则等待、返回处理中或按受控策略接管；
4. 新声明者校验领域 guard 与 expectedVersion；
5. 条件更新聚合，验证影响行数；
6. 写 transition/assignment/必要审计/outbox；
7. 保存首次响应并标记 COMPLETED；
8. 一起提交。

关键不是固定代码模板，而是“key 声明和副作用必须由同一个原子边界解释”。若 `IN_PROGRESS` 行在同一事务里直到提交才可见，其他事务可能等待唯一索引竞争；若采用独立预声明事务，就会引入 lease、超时接管与业务提交不确定性。两种设计成本不同，必须有崩溃点测试，不能混搭后只测试顺利路径。

Spring `@Transactional` 通过代理建立线程绑定事务；自调用、错误 rollback 规则或把外部调用放入事务都可能破坏预期。默认 unchecked exception 回滚不代表所有 checked exception 都回滚。项目应显式定义业务异常与 rollback 规则，并用真实数据库验证，而不是只看注解存在。

## 7. PostgreSQL 唯一约束与 `ON CONFLICT`

多列 `UNIQUE (tenant_id, actor_id, operation, idempotency_key)` 让数据库在高并发下裁决同作用域 key。PostgreSQL 18 文档说明 unique constraint 会建立唯一 B-tree，且 `INSERT ... ON CONFLICT` 能在唯一/排除约束冲突时选择动作；`ON CONFLICT DO UPDATE` 在没有独立错误时保证原子的 insert 或 update 结果。

但 `DO UPDATE` 不是“自动幂等”。若冲突时直接把 fingerprint、response 或 owner 覆盖成新请求，攻击者便可复用 key 篡改首次记录。冲突分支应读取并比较不变量，只允许受控状态推进。通常不希望 `NULL` 出现在 scope/key 列；PostgreSQL 默认 unique 对多个 NULL 的处理可能允许重复，关键列应 NOT NULL。

隔离级别也不替代唯一约束。Read Committed 下两个“先查后插”仍可竞争；Serializable 会带来可重试 serialization failure，也不免除业务指纹、响应重放和冲突分类。选择隔离级别后必须测试相应错误路径。

## 8. 乐观并发：把读到的版本带回写条件

### 8.1 条件更新

工单读取时返回 version。命令携带 expectedVersion，Repository 执行：

```sql
UPDATE work_order
SET status = #{newStatus},
    version = version + 1,
    updated_at = #{now}
WHERE tenant_id = #{tenantId}
  AND id = #{id}
  AND version = #{expectedVersion};
```

影响 1 行表示当前版本仍匹配且提交了本次写；影响 0 行表示对象不存在、不可见或版本冲突，需要在不泄露边界的前提下映射。MyBatis 的 update 返回受影响行数，调用方必须断言恰好 1。忽略 0 后继续写 transition/outbox，会返回成功但主行没更新，形成自相矛盾历史。

version 必须与聚合的所有受保护变化一起增加，不只 status。FactoryCare 转派虽不改 status，仍替换 assignment，因此 work-order version 加一。否则两个调度员在 assignment 层互相覆盖，而主聚合 version 看不见。

### 8.2 为什么“最后写入获胜”不够

Last-write-wins 适用于明确允许覆盖且没有丢失业务意图的字段，不适合派单、状态、库存、权限。甲收到 200 后乙静默覆盖，使甲的响应成为谎言；审计也难以分辨谁覆盖了谁。乐观锁把覆盖变成可观察冲突，让调用方重新读取和决定。

数据库行锁是另一机制，但不是默认更安全。长事务持锁会降低吞吐并引入死锁；跨用户思考时间不能一直锁行。乐观锁适合冲突相对少、用户可以刷新重试的命令。高争用计数器或不可接受冲突的流程可能需要原子 SQL、悲观锁或队列化，须按证据选择。

### 8.3 HTTP 冲突结果

RFC 9110 的 409 表示请求与目标资源当前状态冲突，且用户可能解决后重提。FactoryCare 合同用稳定错误表示 version、状态、不变量或 key fingerprint 冲突，并携 traceId；不能只返回模糊 500。若 API 使用 ETag/If-Match，也可按条件请求语义选择 412，但项目必须统一合同，不在不同端点随机混用。

冲突响应应提供安全的识别信息，例如稳定 `VERSION_CONFLICT`、当前可见 version 或刷新指引；不能泄露他租户资源存在。

## 9. 响应重放的精确顺序

假设第一次 `Idempotency-Key=K1`、fingerprint F1、expectedVersion 7 成功派单，返回 201、工单 version 8。网络丢包后同一请求重试：

1. 先按 scope + K1 找到幂等记录；
2. 比较 F1 相同；
3. 发现 COMPLETED；
4. 返回首次保存的 201/body/version 8；
5. 不再次检查“当前已经 version 8，所以 expectedVersion 7 过期”。

若把乐观锁放在幂等重放判断之前，同一成功请求的重试会变成 409，破坏协议。若 K1 携带 F2，则必须冲突，不能因为已有成功就把 F1 的结果给 F2。若 K2 携带 expectedVersion 7，则是新意图，应走乐观锁并冲突。

响应中若有短时下载 URL、时间戳或一次性凭据，不适合原样长期重放。应该保存稳定业务结果，重放时经授权重新生成短时传输材料，并在合同中说明哪些字段会刷新。不能因此放弃保存核心 status/ID/version。

## 10. `IN_PROGRESS`、崩溃和不确定结果

同 key 的第二个请求可能在首个请求尚未完成时到达。可选策略包括：短暂等待首个事务、返回 409/202 “处理中”、或由可靠 lease 在确认原 owner 失效后接管。不能让两个处理者都继续副作用。

每个崩溃点都要问：业务是否提交？幂等记录是否可见？响应是否保存？

- 全部同事务回滚：记录和副作用都不存在，可安全重试；
- 业务与记录同事务提交但响应未送达：重试可重放保存结果；
- 业务已提交、结果记录却在另一事务失败：产生最危险的不确定窗口；
- 调用外部服务后本地事务回滚：外部副作用可能存在，不能靠数据库事务撤销。

最后一种需要对外部调用本身提供幂等 key、采用 outbox/状态编排或补偿，不存在一个注解就能实现跨系统原子提交。不要宣称“Exactly Once API”；更准确的说法是“在指定本地事务边界内，对同 scope/key/fingerprint 只产生一次受保护副作用，并对至少一次交付安全重放”。

## 11. 冲突后的重试不是简单循环

### 11.1 安全自动重试

死锁、serialization failure 或临时连接异常在事务完整回滚、命令仍适用于新快照、重试次数有上限且使用同幂等身份时，可能自动重试。每次必须重新开始事务，不能复用已失败 persistence context/connection 状态。

### 11.2 不能盲重试 version conflict

version conflict 表示另一个业务决定已经改变当前事实。客户端应刷新数据，重新展示差异，让用户确认原意图是否仍成立。服务端若捕获 update=0、读最新 version 后自动套用旧命令，会绕过 guard：例如工单已经被取消，旧“派单”不应刷新 version 后强行成功。

可自动合并的字段需要显式 merge 规则和测试；“最后写入”不是 merge。移动离线重放尤其要保存客户端命令 ID、基准 version 和原始意图，冲突进入人工处理，不静默覆盖现场事实。

### 11.3 退避不能修复语义

指数退避和 jitter 能减轻瞬时争用，不能把错误 payload 变成正确、也不能解决 key 误用。重试策略应按错误分类：参数/权限/状态冲突不自动重试；基础设施瞬态错误有限重试；未知提交状态使用原 key 查询/重放，绝不能生成新 key 再发。

## 12. 用并发屏障证明只有一个赢家

顺序调用“先成功、后冲突”不能证明并发安全，因为 bug 可能只在两个请求都完成预读后出现。测试需要：

1. 建立 version 7 的同一工单；
2. 两个线程分别构造不同 key/不同分派意图，都携带 expectedVersion 7；
3. 用 `CountDownLatch`/barrier 等待两者都到达写前位置；
4. 同时释放；
5. 收集结果，不依赖哪个线程获胜；
6. 断言成功数 1、冲突数 1、最终 version 8；
7. 断言只有一个有效 assignment、一个对应 transition/audit/outbox；
8. 失败请求没有残留幂等“成功”记录。

并发测试的 oracle 是集合性质，不应硬编码“线程 A 一定赢”。设置有限 timeout，失败时输出两个请求 ID、key 摘要、expected/current version、update count 和数据库事实，避免测试挂死。

本章内存实验用同步对象模拟原子 compare-and-set；G3 的 T4 证据必须使用与项目兼容的 Testcontainers/PostgreSQL，让两个独立连接/事务真正竞争。mock mapper 返回预设 1/0 只能验证分支，不能验证唯一索引等待、隔离和提交顺序。

## 13. FactoryCare 场景落地

### 13.1 小程序重复报修

创建报修使用 `Idempotency-Key + 请求指纹 + 唯一约束`。同 key 同请求返回首次 report/work-order 结果，不重复绑定 `REPORT_CREATION` 附件、不重复 outbox；同 key 不同请求拒绝。两次真正不同的报修即使文字相同，只要 key 不同就分别创建。

### 13.2 双调度员派单

两人基于同 version 派单，一个条件更新成功，另一个收到 409 并刷新。成功事务同时写 assignment、version、必要 transition/审计/outbox。转派也要求 expectedVersion，结束旧 assignment、创建新 assignment、version +1，但 status/transition 不变。

### 13.3 现场事实与离线重放

work log、check item result 和 part usage 是只追加现场事实。移动端保存客户端 command ID/idempotency key 与基准 version；重放返回原结果。若工单已转派、关闭或版本冲突，进入人工解决，不能把离线旧事实偷偷覆盖当前状态。

### 13.4 Outbox 与消费者

outbox 与业务状态同事务，relay 按至少一次发送。消费者以 eventId 去重，重复投递不重复构建报表/索引；这仍不承诺消息中间件 Exactly Once。消费幂等记录与业务 API key 解决的是不同交付边界，不能共用一个模糊“processed=true”。

### 13.5 模块所有权

`idempotency_record` 和 `outbox_event` 属于 `shared-infrastructure` 技术能力，不是第十个业务模块。`workorder` 只通过 `IdempotencyPort/OutboxPort` 使用，不直接访问别的模块内部 Repository 或表实体。幂等基础设施负责声明/重放协议，领域模块仍负责“哪些副作用构成一次业务命令”。

## 14. 多租户、安全与保留期

key 查询必须先绑定可信 tenant/actor/operation，不能让请求 body 的 tenant 决定 scope。返回已保存响应仍重新检查当前主体是否能访问结果；否则拿到 key 可能绕过已撤销权限。是否对“首次有权、重放时已撤权”返回原业务内容，是安全合同，通常应重新授权且不泄露旧数据。

保留期必须大于客户端/网关可能重试和离线重放的窗口，并按操作公布。过期后同 key 是当作新请求还是拒绝，必须定义；对危险写，盲目删除后当新请求可能重复副作用。可采用业务自然唯一键/命令 ID 延长防线，或在过期后要求新人工确认。

幂等表会保存请求摘要、响应片段和主体标识，需要最小化、访问控制、审计与清理。不能把完整联系方式、认证材料或大 payload 当排障捷径。

## 15. 常见伪方案

### 15.1 前端禁用按钮

改善体验，不防网络重试、并发客户端或直接 API 调用。服务器仍需协议。

### 15.2 内存 Map/本地锁

单进程 demo 可用，滚动重启、多实例和崩溃后失效。它不能替代数据库唯一约束；本章资产明确只把它当逻辑模型。

### 15.3 Redis `SETNX` 就完成

Redis 可作短期协调或缓存，但若唯一业务事实仍在 PostgreSQL，Redis 锁与数据库事务之间存在崩溃窗口。FactoryCare 不把 Redis 当唯一事实源。使用时需定义 TTL、owner token、续租、释放和数据库最终裁决，不能只写一行 SETNX。

### 15.4 payload 哈希直接当 key

会把两个合法相同请求误合并，也无法由客户端在未知响应时稳定查询同一意图。fingerprint 是 key 的绑定证据，不是 key 本身。

### 15.5 捕获唯一冲突后统一返回成功

冲突行可能属于不同 fingerprint、不同 operation 或失败中的旧记录。必须读回并分类；否则把 key 误用伪装成成功。

### 15.6 update=0 仍写历史

这是最直接的丢更新证据。Mapper 返回值必须进入领域结果；0 不是“数据库最终一致”，而是当前命令没有修改目标行。

## 16. 故障诊断手册

### 16.1 重复副作用

先按 tenant、operation、key 摘要、fingerprint、aggregate ID 和 trace 对齐两次请求，检查业务行、幂等行、audit 和 outbox 的提交顺序。若业务 createdAt 早于 key claim，或两者不在同事务，优先修边界；不要先加更长 TTL。重放原请求，断言副作用计数保持 1。

### 16.2 相同 key 不同 payload 返回了旧结果

检查 fingerprint 是否漏字段、canonicalization 是否把两个值归一、冲突分支是否只按 key 查询。修复后保留正例“字段顺序不同但语义相同”和反例“assignee 不同”两组测试。错误必须稳定冲突，不能泄露旧响应正文。

### 16.3 丢失更新

保存两个请求的 expectedVersion、SQL、update count、最终 version 和 assignment 历史。若 SQL 缺 version 或 service 忽略 0，使用屏障稳定复现。修复后断言一个成功、一个 409，不依赖赢家身份；再检查失败事务没有 audit/outbox 残留。

### 16.4 重试制造第二个 key

客户端超时处理若每次生成新 key，服务器无法识别同一意图。key 应在命令创建时生成并随该意图的所有重试持久保存，直到得到确定结果或用户明确发起新命令。日志只记录安全摘要。

### 16.5 `IN_PROGRESS` 永久卡住

确认记录与业务事务模型、owner/lease、last heartbeat、首次处理 trace 和数据库提交事实。不要仅按“超过五分钟”删除；业务可能已提交。恢复流程需要查业务自然引用、outbox/审计并决定重放、完成记录或人工处置。

## 17. 120 秒讲述模板

可以这样回答：

> 幂等处理的是同一业务意图被至少一次交付：key 必须绑定租户、主体、operation 和规范化请求指纹；同 key 同 fingerprint 重放首次保存的 status/body，不重复副作用，同 key 不同 fingerprint 明确冲突。key 的原子声明必须发生在副作用之前，并与本地业务状态、审计/outbox 和结果记录处于可解释事务边界。乐观并发处理不同意图竞争旧状态：更新 SQL 带 expectedVersion 并 version+1，影响 0 行就是冲突，不能盲目刷新后重试。反例是先创建工单再记录 key，同时忽略 update=0；它会在崩溃重试时重复创建，也会让两个调度员静默覆盖。两者只保证声明的本地边界，不等于跨消息和外部服务 Exactly Once。

还应补充：RFC 9110 规定了 HTTP 方法幂等和 409；`Idempotency-Key` 的 IETF 文档截至核对日是已过期草案，不是 RFC。能说出这个边界，才没有把行业惯例误称为标准。

## 18. 练习与 G3 验收

公开练习修复七个 TODO，起始代码稳定命中 `DIFFERENT_PAYLOAD_REPLAYED`。私有答案要证明：fingerprint 精确比较、key scope 完整、首次响应可重放、claim 先于副作用、version 匹配、update count 0 被识别、冲突重试不会强套旧意图。

故障实验逐项注入：副作用先于声明、key scope 缺失、payload 未绑定、响应未保存、version 未进 WHERE、忽略 update=0、盲目重试。并发屏障必须产生稳定 oracle，而不是靠循环“偶尔撞到”。

真正 G3 T4 证据还需要 Spring Boot 4.1、MyBatis Core 3.5.x/Starter 4.x、PostgreSQL 18 当前 minor 与 BOM 兼容 Testcontainers：真实唯一约束、两个连接并发、事务回滚、响应重放、409 契约、audit/outbox 行数全部核对。本章离线资产不冒充这些证据。

## 19. 官方来源、版本与证据边界

官方主来源（核对日期：2026-07-17）：

- [RFC 9110 HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html)：方法幂等语义与 409 Conflict；
- [IETF Idempotency-Key draft 状态](https://datatracker.ietf.org/doc/draft-ietf-httpapi-idempotency-key-header/07/)：revision 07 已过期归档，不能称 RFC；
- [PostgreSQL 18 Constraints](https://www.postgresql.org/docs/18/ddl-constraints.html)：多列唯一约束与 NULL 语义；
- [PostgreSQL 18 INSERT / ON CONFLICT](https://www.postgresql.org/docs/18/sql-insert.html)：唯一冲突裁决与原子 insert/update 语义；
- [PostgreSQL 18 UPDATE](https://www.postgresql.org/docs/18/sql-update.html)：WHERE 条件、RETURNING 与 update count；
- [MyBatis 3.5 `SqlSession`](https://mybatis.org/mybatis-3/apidocs/org/apache/ibatis/session/SqlSession.html)：update 返回受影响行数；
- [Spring Framework 7 声明式事务](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative.html)：代理事务与 rollback 规则；
- [Java SE 25 `CountDownLatch`](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/concurrent/CountDownLatch.html)：并发测试的可控起跑/完成屏障；
- [Testcontainers for Java](https://java.testcontainers.org/)：真实依赖集成测试入口。

版本表以仓库 `versions/registry.yml` 为准：Spring Boot 4.1.x GA；PostgreSQL 18.x 使用当前 minor；MyBatis 是 Core 3.5.x + Spring Boot Starter 4.x，绝不能写成 MyBatis Core 4；Testcontainers 采用 Boot 4.1 BOM 兼容版本并保持 provisional 组合验证。

FactoryCare 权威合同来自 [PROJECT_SPEC](../../../PROJECT_SPEC.md)、[data-model](../../../factorycare-design/data/data-model.md)、[public API](../../../factorycare-design/contracts/public-api.yaml)、[threat model](../../../factorycare-design/security/threat-model.md) 和 [acceptance catalog](../../../factorycare-design/testing/acceptance-catalog.md)。

有意不在本章证明：跨数据库原子性、消息 Exactly Once、外部 provider 幂等、Redis 锁正确性、真实数据库隔离/死锁、Spring 自调用代理边界、连接中断后的未知提交恢复、性能与保留清理。它们必须由后续集成、故障演练和运行证据回答。
