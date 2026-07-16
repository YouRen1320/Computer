---
schema_version: 2
edition: 2026.2-draft
id: ch.distributed.redis-cache-rate-limit
title: Redis 缓存、TTL、失效、配额与限流
responsibility: 教授 Redis 辅助加速和限流的失效边界，不让缓存成为业务事实唯一权威或分布式事务替代品
volume: '06'
order: 15
level: L2+
status: drafting
path: book/volume-06-enterprise-architecture/chapters/ch.distributed.redis-cache-rate-limit.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.architecture.idempotency-concurrency
version_surfaces:
- redis
- docker
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释Redis 缓存、TTL、失效、配额与限流的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - redis-cache
  - redis-rate-limit
  covers_topics:
  - redis.key-value-ttl
  - redis.cache-aside
  - redis.invalidation-stampede
  - redis.atomic-counter
  - redis.rate-limit-window
  - redis.fail-open-closed
  uses_capabilities:
  - architecture.idempotency-consistency
  - foundation.network-transport
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现租户化 cache-aside 设备查询和原子固定/滑动窗口限流，配置 TTL、空值、失效和 Redis 故障策略
  covers_topic_groups:
  - redis-cache
  - redis-rate-limit
  covers_topics:
  - redis.key-value-ttl
  - redis.cache-aside
  - redis.invalidation-stampede
  - redis.atomic-counter
  - redis.rate-limit-window
  - redis.fail-open-closed
  uses_capabilities:
  - architecture.idempotency-consistency
  - foundation.network-transport
  evidence_kind: system-artifact-and-negative-tests
  verification_mode: system-security-resilience-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入缓存键漏租户、更新后不失效、热点同时过期和 INCR/EXPIRE 非原子，负载测试后修复
  covers_topic_groups:
  - redis-cache
  - redis-rate-limit
  covers_topics:
  - redis.key-value-ttl
  - redis.cache-aside
  - redis.invalidation-stampede
  - redis.atomic-counter
  - redis.rate-limit-window
  - redis.fail-open-closed
  uses_capabilities:
  - architecture.idempotency-consistency
  - foundation.network-transport
  evidence_kind: fault-injection-fix-rerun
  verification_mode: fault-injection-rerun
---
# Redis 缓存、TTL、失效、配额与限流

> 本章状态为 `drafting`。配套资产使用 JDK 25 的离线确定性模型合成 Redis 语义，能够证明键作用域、cache-aside 顺序、TTL、失效、热点折叠、固定/滑动窗口和 fail 策略的协议预言；它不启动 Redis、Docker、Spring Boot 或真实网络，不能替代 Redis 8.x 与 Testcontainers 的 T4 集成证据。

设备详情被访问一万次，不等于 PostgreSQL 应执行一万次相同查询；同一个集成方在一秒内提交一万次知识检索，也不等于下游必须照单全收。Redis 可以把重复读取变成快速命中，也可以让多个应用实例共享配额状态。然而它位于网络另一端，会超时、丢键、被驱逐、重启、复制滞后，也会被错误键名污染。正确的目标不是“永远命中”或“绝不超额”，而是让 Redis 帮助系统加速和自我保护，同时让每一种失效都落在预先声明的安全边界内。

## 1. 完成定义、证据入口与非目标

完成本章后，应能独立做到：

1. 解释键、值、TTL、命中、未命中、过期、驱逐和缓存穿透的差异；
2. 以数据库为事实源实现 cache-aside，保证命中与未命中的业务结果合同一致；
3. 设计包含可信租户、资源类型、资源 ID、数据范围与投影版本的缓存键；
4. 为正常值、空值、错误和敏感投影分别定义是否缓存与 TTL；
5. 在写入成功后失效，并说明删除失败、并发回填和权限撤销的处理方式；
6. 使用抖动、请求合并、逻辑过期或预热缓解热点同时过期，而不拿分布式锁代替数据库事务；
7. 解释固定窗口、滑动窗口、令牌桶在公平性、内存和实现成本上的取舍；
8. 让计数、过期和裁决成为一个原子动作，并对并发边界写出负向断言；
9. 按调用风险选择 fail-open、fail-closed 或降级配额，且不让 Redis 故障复制持久业务副作用；
10. 通过命中率、源站负载、拒绝率、Redis 错误率和热点键等证据诊断，而不是凭“感觉更快”验收。

配套入口：

- [租户化缓存与限流示例](../../../examples/encyclopedia/ch.distributed.redis-cache-rate-limit/README.md)
- [缓存与限流故障注入实验](../../../labs/encyclopedia/ch.distributed.redis-cache-rate-limit/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.distributed.redis-cache-rate-limit/README.md)

本章明确不做三件事：不把 Redis 当工单、设备、成员或权限的唯一事实源；不把 Redis 锁当 PostgreSQL 唯一约束、version 条件更新或本地事务的替代品；不承诺跨进程、跨区域或故障切换期间的绝对公平与 Exactly Once。那些承诺需要不同的数据模型、协调协议和实测证据。

## 2. 从零建立心智模型：Redis 是远程、易失、共享的状态机

Redis 接收命令并操作键空间。一个字符串键可以对应字符串、哈希、集合、有序集合等值。应用通过 TCP 连接发送命令并接收响应，所以每次读写都受网络延迟、连接池、超时、重试和服务端负载影响。即使正常延迟很低，它仍不是 Java 方法调用；把十个细碎命令串在一次请求中会产生十次网络往返或流水线复杂度。

“内存数据库”也不等于数据永不落盘，更不等于数据必丢。Redis 可配置持久化和复制，但 FactoryCare 对缓存与限流采取更强的设计约束：这些数据必须可从权威事实或时间推移中重建。因此即使 Redis 整体清空，最坏结果也应是暂时变慢、配额进入预定降级，而不是设备凭空消失、权限恢复、工单重复关闭或审计丢失。

共享是它的价值，也是风险。两个应用实例能看到同一计数器，所以负载均衡不能轻易绕过全局配额；两个租户若使用同一个 `device:42` 键，也会看到同一缓存值。因此所有身份维度都必须在写键之前由可信上下文确定，不能先读 body 中的 tenantId 再拼键。

## 3. TTL、过期与驱逐不是同一个概念

TTL 是应用为键设置的剩余生存时间。时间到达后，键在语义上应视为不存在。Redis 会在访问过期键时被动删除，也会周期性主动抽样清理，所以“物理内存中的字节何时被回收”与“GET 还能否返回它”不是同一个问题。Redis 官方 `EXPIRE` 文档还说明，过期时间按绝对时间保存，系统时钟大幅跳变会影响结果。TTL 因而是陈旧上界和资源回收工具，不是毫秒级业务定时器。

驱逐是内存达到 `maxmemory` 后由策略删除键。一个尚有 20 分钟 TTL 的设备投影也可能先被驱逐；一次未命中不能说明它从未缓存，也不能说明数据库中不存在。应用必须把任意时刻的 miss 当正常路径。若代码只有“命中时正确”，它还不是缓存实现。

删除、覆盖和重启也会让键消失。由此得到最重要的不变量：

```text
存在缓存值  => 它只是某个时刻权威事实的派生投影
不存在缓存值 => 去权威源查询或按安全策略拒绝，不能猜测业务事实
```

TTL 的选择必须从业务陈旧预算反推。公开、低风险、更新少的设备展示字段可以较长；成员权限、知识发布状态等安全敏感结果不能仅靠 TTL 等待撤销生效。TTL 也不是越短越新：大量键在相同时间同时过期会形成回源尖峰，反而降低可用性。

## 4. Cache-aside：应用显式管理命中、未命中和回填

cache-aside 的读取流程是：先读缓存；命中则解析并返回；未命中则读数据库，把允许缓存的投影写入 Redis，再返回同一个业务 DTO。Redis 官方将它描述为以 TTL 限制陈旧、按需缓存实际读取数据的模式。关键在“数据库是事实源”，而不是先用 Redis 建事实、稍后希望同步成功。

```text
GET /devices/{id}
  -> 从认证上下文得到 tenant 与 actor
  -> 当前请求执行授权
  -> GET cache key
     -> hit: 校验投影版本并返回
     -> miss: 查询 PostgreSQL
              -> 不存在: 按空值策略处理
              -> 存在: 映射同一 DTO，SET + TTL，返回
```

命中与未命中必须保持协议一致：相同字段、相同缺失语义、相同租户隔离、相同授权要求。缓存里若保存旧版 DTO，而数据库路径返回新版 DTO，调用方会因“是否命中”得到不同合同。键或值中加入 `projectionVersion`，部署新映射时换版本，比扫描删除全部旧键更可控。

回填失败通常不应让低风险查询失败：数据库结果已经得到，可以返回结果并记录 cache write error。但反序列化失败不是普通 miss 的同义词；它可能表示版本错配或数据污染。安全做法是记录受控指标、删除坏键、回源重建，不能吞掉异常后返回半个对象。

## 5. FactoryCare 设备键：身份、范围与版本缺一不可

一个可审查的设备详情键可以是：

```text
fc:{tenantId}:device-detail:{deviceId}:scope:{scopeHash}:pv:3
```

花括号这里只是结构说明，不要求使用 Redis Cluster hash tag。`tenantId` 来自已认证的 TenantContext；资源类型避免设备 42 与工单 42 碰撞；`scopeHash` 表示会改变字段可见性的受控数据范围，而不是把完整权限列表或秘密写入键；`pv:3` 表示投影合同版本。每个片段都要限制字符集和长度，避免分隔符注入、巨键和不可观测的高基数。

若同一租户下所有成员都能看到完全相同的非敏感设备摘要，可以不加 actor，但仍须在每次读取前检查当前成员有效和资源访问权。若投影字段随角色变化，就必须把受控 scope version 纳入键，或者只缓存不含敏感字段的公共部分。把完整授权结果缓存五分钟并跳过重新授权，会使“成员被禁用后仍能读”成为必然窗口。

FactoryCare 验收 `FC-CACHE-001` 要求两个租户使用相同本地 deviceId 仍得到各自数据。最小负向测试不是只比较键字符串，而是先向 tenant A/B 数据源放入不同名称，再交错 miss、hit，断言 A 永不出现 B 的名称。只测不同 ID 无法证明隔离维度正确。

## 6. 空值、错误与敏感值的缓存策略

不存在的设备也可能成为热点：爬虫或错误集成反复查询随机 ID，所有请求都回源，称为缓存穿透。可缓存一个短 TTL 的受控“未找到”哨兵，但它必须绑定 tenant、资源和投影版本，并与真正 `null`、解析失败、无权限区分。否则 tenant A 的 404 会遮住 tenant B 的合法设备，或一次数据库超时会被缓存成“永不存在”。

负缓存 TTL 通常比正常值短，因为设备可能随后创建。是否负缓存要结合入口：对高熵且已授权的内部 ID 可短暂缓存；对权限不足请求不能缓存成共享 404 后绕过后续授权；对数据库 500、连接超时、事务冲突绝不能当 404 缓存。错误分类先于缓存策略。

敏感投影应优先不缓存或只缓存非敏感组成部分。若确需缓存，必须有即时撤销路径、当前授权复核、短陈旧预算和故障时安全拒绝。FactoryCare 的知识撤销、成员禁用和权限收回不能被旧缓存绕过。`FC-CACHE-002` 的预言是权限改变后立即拒绝，而不是“等 TTL 到期基本会好”。

## 7. 写入与失效：先提交事实，再删除派生值

cache-aside 常见写路径是更新数据库成功后删除缓存。若先删缓存再提交数据库，会出现：删除后另一个请求 miss，读到尚未更新的旧数据库值并回填；随后事务提交，新值存在数据库而旧值重新进入缓存。若写数据库后删缓存，删除失败仍可能短暂读旧值，所以必须有重试/补偿、TTL 上界和可观测告警。

更精确地说，删除应发生在业务事务成功之后。Spring 的事务完成回调或 outbox 驱动失效都可表达“仅提交后触发”，但二者各有窗口。提交后同步 `DEL` 简单，进程在提交与删除之间崩溃会遗漏；用 outbox 记录失效意图可恢复，却允许重复且需要 relay。无论哪种，缓存失效都不能加入核心数据库事务并假装成为跨 Redis 的原子提交。

“写数据库后更新缓存”看似少一次 miss，但并发写容易让较旧事务最后覆盖较新缓存。删除通常更保守：下次读从事实源重建。若业务要求更小窗口，可以在值中携带数据库 version，回填/更新时拒绝版本倒退，但这仍需故障测试，不能只凭时间顺序。

双删是一种缓解特定竞态的技巧，不是普适证明。第一次删、延迟、第二次删的时间依赖请求延迟和事务长度；选错延迟仍会遗漏，而且进程崩溃会跳过第二次。优先明确权威源、提交后失效、版本化投影、TTL 和可靠补偿，再用故障注入判断是否真的需要双删。

## 8. 热点过期、击穿、穿透和雪崩

四个词经常混用，诊断时必须分开：

| 现象 | 核心原因 | 证据 | 常用缓解 |
| --- | --- | --- | --- |
| 穿透 | 查询事实中不存在的键 | 404 回源量高 | 短负缓存、入口约束、布隆过滤器需可解释更新 |
| 击穿/惊群 | 单个热点过期后并发回源 | 某键 miss 突增、同键数据库查询并发高 | 单航班请求合并、短租约、逻辑过期 |
| 雪崩 | 大批键同刻过期或 Redis 故障 | 全局 miss 与源站负载同时跃升 | TTL 抖动、分批预热、容量与降级 |
| 污染 | 错键/错版本/错租户写入 | 命中率正常但结果错误 | 键合同、版本、隔离负测、删除重建 |

TTL 抖动是在基础 TTL 上加入受控随机区间，让键不在同一秒到期。随机范围要可配置并在测试中固定 seed，否则验证不稳定。抖动只平滑群体过期，不能解决单个超级热点。

单航班让同一进程/同一键只有一个加载者，其余请求等待或使用受控旧值。跨实例可用 Redis 短租约，但获取不到租约不代表可以永久等待；加载者崩溃后必须到期，等待者要有超时。租约只协调回填，不保护业务更新。设备 `version`、数据库唯一约束和事务仍是事实裁判。

逻辑过期把 `freshUntil` 放在值中，物理 TTL 更长。过期后一个请求刷新，其他请求可在业务允许时返回短暂旧值。它适合公开、低风险投影，不适合已撤销权限或安全状态。是否可 stale 必须是字段/用例级决策，不能以“可用性”为由全局开启。

## 9. 限流首先是策略，不是一个计数器

限流回答四个问题：限制谁、限制什么、在多长时间内、超过后怎样。FactoryCare 可按 tenant + actor + operation 限制 AI 建议生成，按 tenant 限制文件解析并发，按 IP + QR 入口限制枚举尝试。若只按 IP，公司 NAT 后的合法用户会互相伤害；若只按 tenant，一个被盗账号可能耗尽全租户；多层限额通常比单一维度更稳健。

返回 429 时应给稳定错误码，并在协议允许时提供 `Retry-After` 或重试时间提示。拒绝本身也要低成本；限流器先执行十次数据库查询再拒绝已经失去保护作用。与此同时，认证和授权不能因限流而泄漏资源是否存在：错误顺序和响应差异要纳入威胁模型。

配额不是业务幂等。一个请求先通过限流，因网络超时携带同一 Idempotency-Key 重试，可能再次消耗令牌；业务层仍须保证持久副作用只有一次。反过来，即使幂等能阻止重复创建，攻击者使用不同 key 仍可耗尽 CPU，所以仍需限流。

## 10. 固定窗口：简单、便宜，但边界会突发

固定窗口把时间分桶，例如每分钟一个键：

```text
fc:rl:{tenant}:{actor}:device-read:minute:202607171530
```

在当前桶原子增加，计数不超过 limit 则允许，并给桶设置略长于窗口的 TTL。它的优点是 O(1) 状态、易解释、易观测。缺点是边界突发：用户可在 15:30:59 用完 100 次，15:31:00 又用 100 次，两秒内通过 200 次。若下游不能承受这种峰值，就不应只因实现简单而选固定窗口。

桶时间应由统一策略计算。应用实例时钟漂移会把同一请求分到不同窗口；Redis 服务端时间也不是业务绝对真理。限流容许小误差时可接受，但应监控 NTP/时钟，并在证据中明确边界。键 TTL 要覆盖当前窗口加清理余量，不能每次请求都无意延长成“距离最后一次请求 N 秒”，那已变成另一种窗口语义。

## 11. INCR 与 EXPIRE 的原子性陷阱

`INCR` 单条命令是原子的，但“如果第一次则 EXPIRE”由两条网络命令组成时不是一个原子动作：客户端在 INCR 后崩溃、超时或连接断开，键会没有 TTL，计数可能永久增长，后续请求永久被拒绝。Redis 官方 `INCR` 文档明确展示该竞态并建议把条件增加与过期放入 Lua 脚本。

正确实现可以使用短小的 Lua/Redis Function，把读、增加、首次设置 TTL、比较阈值和返回剩余量合成一次服务端裁决。Redis 保证脚本原子执行，但脚本执行期间会阻塞其他活动，所以必须保持有界、快速，不扫描大键、不访问网络。原子只覆盖脚本触及的 Redis 状态，不使“通过限流 + PostgreSQL 写工单”成为跨系统事务。

Redis 8 的一些部署可能提供更直接的计数/过期命令，但课程合同锁定的是语义，不应偷偷假设所有兼容服务或客户端都支持新命令。版本面登记为 Redis 8.x；实际采用原生命令、Lua 还是 Function，要在运行环境和集成测试中确认，并提供回滚路径。

## 12. 滑动窗口：更平滑，也更昂贵

精确滑动日志可用有序集合保存最近窗口内的请求成员：先删除窗口外分数，统计剩余，若未超限则加入本次唯一成员并设置 TTL。整个“清理—计数—加入—裁决”必须原子。成员不能只用毫秒时间戳；同一毫秒多个请求会覆盖，应用应加入稳定 request token 或序号。

精确日志的内存随窗口内请求数增长，清理和计数也有成本。滑动计数器可用当前/上一固定桶加权估算，以较小状态换取近似误差。令牌桶按时间补充令牌，允许受控突发并限制长期速率。选择算法要从下游容量和用户公平性出发：如果 API 只需粗略防滥用，固定窗口通常足够；如果外部供应商严格按连续 60 秒计费，滑动窗口更合适；如果需要“平均每秒 10、偶尔突发 20”，令牌桶更自然。

不要同时实现三个算法却没有选择合同。独立构建任务可以实现固定和滑动以比较，但生产 endpoint 必须声明采用哪一个、key 维度、limit、window、误差、故障策略与响应头，否则运维无法解释拒绝。

## 13. Fail-open、fail-closed 与有界降级

Redis 超时后没有万能答案。fail-open 表示限流器不可用时允许请求，保护核心可用性但失去过载/滥用防护；fail-closed 表示拒绝请求，保护昂贵或敏感下游但可能扩大 Redis 故障；有界降级可用每实例小额度、并发舱壁或静态紧急配额，在两者之间保留有限能力。

FactoryCare 应按操作分级：读取低敏设备摘要可回 PostgreSQL 并受连接池/超时保护；AI 推理、批量导出、文件解析等昂贵能力可 fail-closed 或采用很小的本地应急桶；关闭工单等核心命令不能因为 Redis 丢失幂等短状态而重复写，必须依赖数据库幂等记录、version 和事务。敏感查询在无法重新授权时应安全失败，而不是返回旧缓存。

故障策略必须在调用前决定并测试，不要在 catch 块里临时“为了可用先放行”。至少记录 `policyId`、操作、租户匿名标识、timeout/error 分类和最终 `ALLOW/DENY/DEGRADED`，但避免把 token、缓存 payload 或个人数据打进日志。

## 14. 网络、超时、重试与连接池

Redis 客户端有连接建立、命令执行和总请求预算。超时过长会占满线程/连接池；超时过短会在正常抖动时制造错误。一次 HTTP 请求不应无界等待 Redis，再无界等待数据库。预算要从端到端 SLO 反推，给缓存很小份额，miss 后仍留足事实源时间。

读取命令超时后重试通常只增加负载；写命令超时更棘手，因为客户端不知道服务器是否执行。对于缓存 SET/DEL，重复通常可接受但仍须值/version 设计；对限流 INCR，盲重试会重复扣配额。给限流裁决稳定 request token 并去重会增加状态和成本，许多系统接受小幅过计数，但必须声明。任何时候都不能把 Redis 的“不确定”推导成业务命令“肯定没执行”。

连接池耗尽常被误判成 Redis 慢。诊断要区分 DNS/建连、池等待、服务端 command latency、脚本 BUSY、网络丢包、客户端序列化和数据库回源。只看总 HTTP P95 不能定位。Redis 官方脚本文档提醒长脚本会阻塞服务器，这也是为何限流脚本应只做固定数量的简单操作。

## 15. 缓存安全与数据最小化

缓存不是授权层。请求到来先从可信认证建立 tenant/actor，再执行当前授权，最后才可读取对应投影。若为了性能先读共享键并把对象返回，再“异步检查权限”，数据已经泄露。缓存命中也必须经过数据范围判断。

键名、指标标签和日志会被运维系统收集，避免放邮箱、手机号、完整 token 或自然语言描述。值只存用例所需字段，设置上限，防止大对象占满内存。反序列化使用受控 schema/类型，不接受任意类名。Redis 本身还需要网络隔离、认证、最小命令权限、加密和秘密轮换，但这些基础设施控制不能修复应用漏 tenant 的键。

缓存投毒可能来自错误映射、越权写接口或不安全反序列化。修复不仅是删除当前坏键，还要关闭写入路径、增加 projectionVersion、隔离测试和追踪来源。`FLUSHALL` 是高影响操作，不应作为日常修复或自动测试命令指向共享环境。

## 16. FactoryCare 端到端案例：租户化设备详情

假设 `GET /api/devices/{deviceId}` 返回序列号脱敏值、型号、站点和状态摘要。流程如下：

1. 资源服务器验证 token，建立可信 TenantContext；
2. 授权服务确认当前成员有效并有设备读取数据范围；
3. 计算 `tenant + device + scopeVersion + projectionVersion` 键；
4. 读取 Redis，命中则校验 envelope 版本并映射 DTO；
5. miss 时以 tenant 条件查询 PostgreSQL，绝不只按 deviceId；
6. 不存在时写很短的受控负缓存，权限不足不共享负缓存；
7. 存在时回填带 TTL 与抖动的最小投影；
8. 返回值不暴露 `cacheHit` 业务差异，可在内部 trace 记录；
9. 更新设备的数据库事务提交后删除所有受影响投影键；
10. 删除失败进入可重试失效记录并告警，TTL 提供最后上界。

验收要交错执行 A miss、B miss、A hit、B hit、A 更新、A read、B read，并注入 Redis unavailable。必须观察 A 更新后读到新值，B 始终不受影响，Redis 故障时低风险查询回源，权限撤销后即使旧值仍在也拒绝。只测单租户 happy path 不满足系统/安全级证据。

## 17. FactoryCare 端到端案例：入口配额

对知识建议生成定义：tenant 每分钟 100、actor 每分钟 10、并发每 tenant 3。请求必须同时通过各层，任一拒绝都不调用昂贵供应商。固定窗口键绑定 tenant/actor/operation/window；并发额度用有界租约并在 finally 释放，租约到期处理进程崩溃。生成命令仍携带数据库幂等键，以避免客户端重试产生两个持久任务。

对 QR 查询防枚举，IP 只是信号之一，还可按未认证 token 前缀、设备/租户边界和失败比例控制。响应不能通过 404 与 429 精细差异帮助攻击者确认有效资源。阈值应配置化、审计变更并有灰度/回滚，不在代码中散落魔法数字。

负载证据应包含阈值内全部允许、阈值外稳定拒绝、窗口滚动后恢复、不同租户不共享计数、多个应用实例共享限制、并发边界不多放行。离线资产只证明判定模型；真实证据仍需 Redis 容器、多实例客户端和网络故障注入。

## 18. 故障注入矩阵

| 注入 | 错误症状 | 能证明的预言 | 修复方向 |
| --- | --- | --- | --- |
| 缓存键去掉 tenant | 相同 deviceId 串值 | A 永不返回 B payload | 可信租户进入键与源查询 |
| 更新后不失效 | 数据库已新、命中仍旧 | 提交后首次读必须新 | 提交后删、补偿、版本 |
| 所有 TTL 完全相同 | 到点回源并发尖峰 | 峰值加载次数受界 | 抖动、single-flight、预热 |
| `INCR` 后跳过 `EXPIRE` | 无 TTL 计数永久存在 | 所有窗口键有到期 | Lua/Function 原子合并 |
| check 与 add 分开 | 并发多放行 | threshold+1 必须拒绝 | 原子读改写与并发测试 |
| Redis timeout 一律放行 | 昂贵端点失去防护 | 故障行为匹配 policy | 端点分级 fail 策略 |
| Redis timeout 一律拒绝 | 核心查询全站故障 | 低风险读可受控回源 | 舱壁、超时、回源 |
| 命中跳过授权 | 撤销后仍泄露 | 当前授权优先于缓存 | 每次授权、敏感值最小化 |

实验必须先运行安全基线，再逐项启用一个 fault，输出与预期故障标记比较，修复后重跑同一个预言。若故障模式没有让验证失败，说明测试没有覆盖风险，而不是实现“更稳健”。

## 19. 诊断剧本：从现象到证据

**命中率骤降。** 先按 operation、tenant 匿名维度和 projectionVersion 分解；查看部署是否换键版本、TTL 是否集中、Redis 是否驱逐、序列化是否失败，再看数据库 QPS。直接把 TTL 翻十倍可能把权限陈旧窗口也翻十倍。

**数据库在整点被打满。** 对齐 miss 时间分布和 TTL 设置时间，检查批量预热是否给相同到期、热点 single-flight 是否只在单实例。修复后用可控时钟和并发屏障重现整点，比较每键加载次数与全局峰值。

**某租户看到另一个租户设备名。** 这是安全事件，不是普通缓存 bug。立即停用受影响读取/清理隔离键，保留脱敏证据，核对键构造、数据库 WHERE tenant、scope 传播与写入来源。不能仅 FLUSH 后宣布修复；同样输入必须用隔离负测证明不再复现。

**限流后永久 429。** 查键 TTL 是否为 -1、客户端是否在 INCR 与 EXPIRE 之间失败、窗口键是否稳定、时钟是否异常。若缺 TTL，修复原子脚本并清理受控前缀；不要全库扫描/删除不相关键。

**阈值 10 却并发允许 12。** 查算法是否先 GET 再 INCR、多个实例是否使用本地计数、滑动成员是否因同毫秒覆盖、comparison 是 `>` 还是 `>=`。用同时释放的并发屏障统计赢家集合，不断言具体哪个线程获准。

**Redis 故障导致重复关闭工单。** 根因不在“缓存不够持久”，而在核心命令错误依赖 Redis 幂等状态。恢复数据库 `idempotency_record`、唯一约束、version 和同事务副作用；Redis 只能是短期加速，`FC-CACHE-003` 必须证明 Redis unavailable 时持久副作用仍只有一次。

## 20. 观测、容量和运维合同

缓存至少观察 hit、miss、negative hit、load latency、load error、write/delete error、deserialize error、eviction、memory、key size 分布和热点。命中率要与源站负载、正确性一起看：99.9% 命中可能只是长期返回旧权限；低命中也可能因为一次性扫描，本就不适合缓存。

限流至少观察 allowed、denied、degraded、policy error、decision latency、按 policy 的 Redis 错误和下游负载。标签不能直接用任意 tenantId/actorId 造成指标基数爆炸，可使用分层聚合和受控抽样。告警要区分“拒绝率升高是攻击/流量增长”与“Redis 错误导致 fail-closed”。

容量估算包含键和值字节、数据结构开销、TTL 分布、复制/持久化、峰值请求和脚本时间。限流滑动日志的最坏成员数由主体数乘窗口内请求数决定；没有上界就没有容量模型。缓存预热也要限速，避免恢复时应用自己成为攻击源。

运维手册应定义 Redis 重启/清空后的行为、关键前缀、逐租户失效方式、脚本/Function 版本、超时与熔断参数、fail policy owner、回滚开关和证据保留。Docker 镜像使用明确版本或 digest；版本登记中的 Docker 仍为 provisional，进入真实容器实验时必须记录 Engine/Compose、镜像和客户端实际版本。

## 21. 独立构建任务与验收

独立实现一个设备查询和一个限流组件。设备查询必须具备可信租户键、projectionVersion、正常/负值 TTL、抖动、提交后失效、single-flight 和 Redis 故障回源/安全拒绝。限流必须至少实现原子固定窗口与滑动窗口，明确主体、operation、阈值、窗口、返回值和 endpoint 级 fail policy。

最低正向断言：miss 与 hit 返回相同 DTO；A/B 相同本地 ID 不串；更新提交后下一次读为新 version；固定窗口前 N 次允许、N+1 拒绝；滑动窗口旧请求离开后恢复；Redis 正常时所有实例共享裁决。

最低负向断言：漏 tenant 会稳定暴露 cross-tenant；跳过失效会返回 stale；相同 TTL 会放大并发加载；非原子 INCR/EXPIRE 产生无 TTL 键；分离 check/add 会多放行；Redis 故障时行为严格等于配置的 fail-open/closed/degraded；故障不能复制数据库副作用。

T4 证据需要真实 Redis 8.x 容器、真实客户端序列化/超时、至少两个应用实例或连接、可控并发和故障注入。记录 Docker 镜像、Redis/客户端版本、seed、并发数、阈值、命令、退出码和完整断言。内存 Map、mock RedisTemplate 或只打印日志都不能证明网络/原子/TTL 边界。

## 22. 120 秒口述模板

可以这样组织而不是背定义：Redis 在 FactoryCare 只保存可重建投影和时间受限配额，不是业务事实源。cache-aside 先按可信 tenant/scope/version 读缓存，miss 回 PostgreSQL并回填，写事务提交后失效；TTL 限制陈旧但不保证准时业务动作，抖动和 single-flight 缓解热点过期。限流按主体、操作和窗口做原子裁决，固定窗口便宜但边界突发，滑动窗口更公平但成本更高。Redis 故障必须按 endpoint 预定 fail-open、fail-closed 或有界降级，核心命令仍靠数据库幂等与事务。反例是缓存键漏 tenant，命中率看起来很好却跨租户泄露；另一个反例是 INCR 后客户端崩溃没 EXPIRE，用户永久被拒绝。

口述证据要在 120 秒内包含职责、适用边界、六个主题和至少一个可失败反例。只说“Redis 很快、设置过期时间、QPS 超了就拒绝”没有说明权威源、原子性和故障策略，不能通过。

## 23. 版本边界与权威来源

本章版本登记采用 Redis Open Source `8.x`（已核验）与兼容 Compose v2 的当前稳定 Docker Engine（provisional）。语义优先依赖稳定命令合同，不默认所有 Redis 兼容服务、客户端、集群拓扑或托管版本具有相同扩展。真实实验必须记录 patch、镜像 digest、拓扑、持久化/驱逐配置和客户端版本。

- [Redis 官方：cache-aside](https://redis.io/docs/latest/develop/use-cases/cache-aside/)
- [Redis 官方：EXPIRE、精度与过期处理](https://redis.io/docs/latest/commands/expire/)
- [Redis 官方：INCR 与限流竞态](https://redis.io/docs/latest/commands/incr/)
- [Redis 官方：Redis rate limiter](https://redis.io/docs/latest/develop/use-cases/rate-limiter/)
- [Redis 官方：Lua 脚本原子执行与阻塞边界](https://redis.io/docs/latest/develop/programmability/eval-intro/)
- [FactoryCare Redis cache-aside ADR](../../../factorycare-design/adrs/0008-redis-cache-aside.md)
- [FactoryCare 威胁模型](../../../factorycare-design/security/threat-model.md)
- [FactoryCare 验收目录](../../../factorycare-design/testing/acceptance-catalog.md)

## 24. 复盘清单

- 我能否在不看稿时区分过期、驱逐、失效、穿透、击穿和雪崩？
- 每个缓存键是否含可信 tenant、资源、数据范围与投影版本？
- 命中是否仍执行当前授权，敏感撤销是否立即生效？
- 正常值、空值、异常和解析失败是否有不同策略？
- 写事务提交后如何失效，删除失败怎样恢复，陈旧上界是多少？
- 热点过期时每个实例/整个集群最多有多少加载者？
- 固定/滑动窗口为什么符合该 endpoint 的公平性与容量？
- 增加、过期和裁决是否真正原子，长脚本是否有界？
- Redis timeout 时每个 endpoint 明确允许、拒绝还是降级？
- Redis 完全丢失时，核心业务事实和幂等副作用是否仍正确？
- 我保存的是可重放断言、版本和退出码，还是只有一张“看起来成功”的截图？

能逐项给出实现位置、失败注入和重跑证据，才算掌握本章。缓存的成功不是“所有请求都命中”，而是命中能加速、未命中能正确、失效有上界、故障可解释；限流的成功不是“从不超额”，而是裁决原子、策略匹配风险、降级不会破坏更高优先级的业务不变量。
