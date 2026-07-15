# FactoryCare架构决策记录（ADR）

ADR记录已经进入设计基线、会显著影响后续施工的决定。它们说明为什么选、放弃了什么、如何迁移与回滚；“Accepted”只表示设计已确认，不表示代码已实现。

| ADR | 决定 | 对应阶段 |
| --- | --- | --- |
| [0001](./0001-modular-monolith.md) | Java采用模块化单体 | Week 16、18、21 |
| [0002](./0002-pooled-multitenancy.md) | PostgreSQL共享schema、行级tenant键和复合约束 | Week 13、14 |
| [0003](./0003-oidc-and-client-sessions.md) | 外部OIDC；Web安全会话，移动端PKCE bearer | Week 16—17、24、26、30、34 |
| [0004](./0004-transactional-outbox.md) | 事务outbox与至少一次消费 | Week 20—21 |
| [0005](./0005-java-python-boundary.md) | Java拥有业务事实，Python为有界AI服务 | Week 21、38、40—44 |
| [0006](./0006-private-object-storage.md) | 私有对象存储与短时授权 | Week 20—21、27、30—31、35、41、44 |
| [0007](./0007-rag-safety-and-evaluation.md) | 发布门、混合检索、引用、拒答和固定评估 | Week 39—43、46 |
| [0008](./0008-redis-cache-aside.md) | Redis仅做租户隔离的cache-aside、限流与可丢失技术状态 | Week 19、46 |
| [0009](./0009-mobile-offline-command-sync.md) | Flutter显式离线命令队列、服务端幂等/version与人工冲突 | Week 33—35、44 |

## 状态与变更

- `Proposed`：仍需选择；`Accepted`：当前设计基线；`Superseded`：被新ADR替代；`Rejected`：明确不采用；
- 不能重写旧ADR来掩盖变化。重大变化新增ADR，并在旧文件顶部链接替代者；
- 每项决定实现前复核当前官方版本；真实约束变化时记录证据，再决定是否迁移；
- 回滚是回到安全可运行状态，不等于假装没有数据/契约迁移。

## ADR最小内容

上下文与目标、至少两个可行选项、实现/迁移成本、风险、回滚难度、长期维护、最终决定、后果、迁移、回滚、验证、明确非目标。
