# FactoryCare测试策略

> 目标不是追求一个孤立的覆盖率数字，而是用最便宜、最稳定的测试证明关键业务与安全不变量。本文定义施工顺序和证据；当前尚未执行这些测试。

## 1. 质量风险排序

| 优先级 | 风险 | 失败后果 | 主要测试层 |
| --- | --- | --- | --- |
| P0 | 跨租户或跨数据范围访问 | 数据泄露与权限失控 | 授权单元测试、Repository集成、API负向、AI评估 |
| P0 | 非法工单状态或模型直接写业务 | 核心事实不可相信 | 状态机性质测试、命令集成、架构测试 |
| P0 | RAG召回未发布/已撤回/他租户内容 | 敏感知识泄露 | 检索集成、固定安全评估集 |
| P1 | 并发覆盖、重复命令和重复事件 | 派单/工时/通知重复 | 数据库并发、幂等、消费者测试 |
| P1 | 上传与私有下载绕过 | 恶意文件或附件泄露 | 上传负向、对象存储集成、安全扫描 |
| P1 | 离线同步丢失或乱序 | 现场工作记录不一致 | Dart单元、App集成、弱网场景 |
| P1 | API/事件/客户端类型漂移 | 多端运行时失败 | 契约校验、生成客户端编译、兼容测试 |
| P1 | AI编造、无引用或越权工具调用 | 错误维修建议 | 结构校验、评估、红队、降级测试 |
| P2 | 页面回归、可访问性和性能 | 使用效率降低 | 组件、E2E、a11y、性能预算 |

## 2. 测试组合

| 测试层 | 测什么 | 不测什么 | 建议工具/方式 | PR期望 |
| --- | --- | --- | --- | --- |
| 纯单元 | 值对象、状态转换、SLA计算、权限判定、映射、算法 | Spring上下文、真实数据库 | JUnit 5/AssertJ、Vitest、Dart test、pytest | 秒级；每次提交 |
| 性质/参数化 | 所有状态边、角色×范围、边界值、幂等摘要 | 完整UI | JUnit参数化/属性测试或表驱动 | P0规则全覆盖 |
| 模块测试 | 单个Java模块公开API、事务和发布事件 | 浏览器与外部Provider | Spring Modulith ApplicationModuleTest | 关键命令必有 |
| 数据集成 | SQL约束、tenant过滤、乐观锁、迁移、outbox原子性 | mock数据库行为 | Testcontainers PostgreSQL/Redis/MinIO | 合并前关键集运行 |
| 契约测试 | OpenAPI请求/响应、错误码、事件JSON Schema、Java↔Python | 业务正确性全貌 | OpenAPI校验、JSON Schema、生成客户端编译 | 契约变更阻断漂移 |
| 组件测试 | Vue表格/表单/权限态、Flutter状态、uni-app表单 | 整体后端 | Vitest+Testing Library、Flutter widget test | 高交互组件必有 |
| API/E2E | 角色主链路和失败链路 | 所有排列组合 | Playwright或等价浏览器测试；移动端少量集成 | 冒烟集稳定可重跑 |
| AI离线评估 | 召回、引用、拒答、跨租户、注入、结构输出 | 真实用户满意度 | 固定数据集+pytest；记录版本 | 门槛和基线不可退化 |
| 故障/恢复 | Python/Redis/对象存储/消费者异常、恢复与重放 | 无目标随机破坏 | 可控故障注入、备份恢复演练 | 发布候选执行 |
| 非功能 | p95、并发、a11y、秘密、依赖、镜像 | 未定义SLO的虚假承诺 | k6/JMeter等、axe、SCA/SAST | 阶段门执行 |

测试比例是方向而非KPI：业务规则尽量下沉到大量快速测试，少量E2E只证明跨层组装。不要用浏览器脚本重复验证状态机所有边。

## 3. 按模块的最低证据

### identity / organization

- OIDC issuer、audience、过期、缺失claim与当前成员状态；
- `membership_role`授予/撤销的授权与审计；七个GLOBAL固定role catalog可读但租户不可增删改或改role-permission；
- organization/team父子tenant与唯一约束；`membership.team_id`可空，但`data_scope=TEAM`时必须存在、启用且与membership同tenant/organization；
- 七角色、SELF/TEAM/ORGANIZATION/TENANT范围和租户边界的表驱动测试；
- 禁止自我提权、跨租户邀请和禁用后继续访问。
- catalog必须显式`GLOBAL|TENANT`：租户用户不能改GLOBAL，TENANT行不能缺`tenant_id`，空tenant不会被默认解释为GLOBAL。

### asset

- equipment model的租户内code唯一/version，location树的同租户父节点/无环，以及设备引用型号/位置的租户/组织约束；
- 二维码随机性、轮换、旧码失效、速率限制与最小响应；
- 并发更新版本冲突；私有手册关联不能绕过knowledge授权。

### workorder

- `PROJECT_SPEC.md`中每一条合法边成功，每个未列边失败；
- 转换、`work_order_transition`、经`audit` 公开追加端口写入的核心审计与outbox同事务；任一写失败整体回滚；
- 派单并发只有一个赢家；重复键不重复副作用；
- assignment必有team，技师若存在必须属于同tenant/organization/team范围；转派结束旧assignment、创建新assignment、version+1与核心审计，不改status、不写transition；
- 等备件/待审批的SLA暂停恢复；跨时区与边界时间；
- `IN_PROGRESS -> PENDING_APPROVAL -> IN_PROGRESS`覆盖请求人、审批人分离，命令`APPROVE|REQUEST_CHANGES`与持久状态`PENDING|APPROVED|CHANGES_REQUESTED`的精确映射、必填理由、过期version、越范围与自审拒绝；
- 报修人、技师、调度员和主管的所有权/范围负向测试。

### knowledge / attachment

- 草稿、审核、发布、撤回和不可变版本；
- 事件与source version一致；撤回后新检索不可返回；
- `attachment.owner_type`最终只允许`REPORT|WORK_ORDER`；`purpose`只允许`REPORT_CREATION|REPORT_SUPPLEMENT|WORK_ORDER`，后两者创建意图必须有owner；
- `REPORT_CREATION`可暂无owner，但未绑定时不可下载/引用；创建report时校验主体/会话/租户/状态并原子转`owner_type=REPORT`，幂等重试、他主体、过期与重绑全覆盖；
- 知识上传/绑定直接生成带对象键与哈希的`knowledge_version`，不存在knowledge attachment purpose，不产生attachment行；
- 两类对象都覆盖文件大小、数量、MIME、魔数、恶意样本和短时URL，但授权与生命周期按各自父资源测试；
- 作者是否允许自审由策略显式决定并测试，不能意外放行。

### reporting / engagement / audit

- 重复、乱序事件仍生成同一读模型；损坏读模型可重建；
- Provider失败不回滚工单；重试有上限并可人工恢复；
- SLA、首次解决、重复故障、知识命中和AI采纳都以分子/分母和版本化口径验证，重开/驳回/无决定样本不得误计；
- 核心审计追加写与业务同事务，事件消费者停机时核心证据仍存在；异步消费只补派生证据；
- 审计敏感字段遮罩、导出授权和trace关联。

### ai-integration / Python AI

- 请求/响应Schema、超时、熔断、fallback和错误映射；
- service token的audience、scope、过期与回调上下文；
- 两个只读工具的允许列表、参数Schema、页数/字符上限；
- 固定评估集记录dataset、prompt、model、embedding、index版本；
- `model_call/tool_call/eval_run/eval_result`是不可精确重建的证据；备份/保留/权限测试不能用“以后重跑”替代；checkpoint丢失时显式终止并安全重启，不伪造原流程恢复；
- 跨租户与已撤回内容目标是**零召回**，不以平均分抵消安全失败。

### shared-infrastructure / Redis缓存

- 架构测试证明它是技术包而非第十个业务模块；业务只见`OutboxPort`、`IdempotencyPort`等稳定端口；
- PostgreSQL中业务事实、outbox和持久幂等结果的原子性；Redis不可用时不会重复业务副作用；
- 缓存键包含tenant、资源、数据范围与版本；双租户同名/同局部ID不会命中同一值；
- 返回敏感投影前重新授权；成员禁用、权限撤销和知识撤回不能被TTL内旧缓存绕过；
- 测试cache miss/hit与双删竞态的最终一致窗口；禁止用分布式锁代替数据库版本/唯一约束。

### Vue / Nuxt / uni-app / Flutter

- 权限UI只改善体验，API负向测试仍是授权权威；
- 加载、空、错误、无权限、冲突、离线和重试状态；
- 生成客户端能编译，错误码映射一致；
- Flutter离线队列：重复、乱序、部分成功、冲突人工处理、退出清理；
- 离线命令携带`clientCommandId`、幂等键、`expectedVersion`和依赖关系；按工单保序上传，已确认、冲突、永久拒绝和可重试失败分开处理；
- 关键表单键盘可达、标签/对比度、移动触控面积和中文长文本。

## 4. 工单状态机测试设计

唯一合法边集合：

```text
CREATED -> TRIAGED | CANCELLED
TRIAGED -> ASSIGNED | CANCELLED
ASSIGNED -> ACCEPTED
ACCEPTED -> IN_PROGRESS
IN_PROGRESS -> PENDING_PARTS | PENDING_APPROVAL | RESOLVED
PENDING_PARTS -> IN_PROGRESS
PENDING_APPROVAL -> IN_PROGRESS
RESOLVED -> VERIFIED | IN_PROGRESS
VERIFIED -> CLOSED
CLOSED -> REOPENED
REOPENED -> IN_PROGRESS
```

参数化测试从全部12×12组合中减去合法边，逐个证明非法边拒绝且版本、状态、历史、审计、outbox均未改变。每条合法边还要覆盖：正确角色、错误角色、错误租户、过期版本、缺少必填理由/证据和重复幂等键。其中`PENDING_APPROVAL`的进出边必须验证approval记录与核心审计的原子性。

转派是assignment命令，不是状态边；单独断言status与`work_order_transition`行数不变，只有效assignment、work-order version和核心审计变化。

## 5. 契约与兼容策略

- `public-api.yaml`和`ai-internal-api.yaml`是设计时来源；实现阶段由CI生成/校验，不手工维护第二套DTO说明；
- 公共API在`/api/v1`内允许增加可选响应字段；删除/改义/改必填需新版本或迁移窗口；
- 事件消费者先部署为“能忽略新增字段”，生产者后部署；破坏性变化创建`.v2`并双读/有限双写；
- 每个稳定错误码有至少一个契约测试；禁止客户端依赖自然语言`message`；
- 匿名QR与其他公共失败只按Problem契约做参数化测试：验证400/401/403/404/409/429/503对应的稳定`code/message/fieldErrors/traceId`、头与无副作用，不在测试文档发明另一套错误DTO；
- TypeScript与Dart生成客户端在CI编译，Python/Java内部Schema用双方测试样例验证。

## 6. 公共/内部契约能力追踪

以契约中实际`operationId`为源，每组能力必须同时有验收ID和可重现数据；下表不复制DTO字段：

| 契约能力 | 必测行为 | 验收ID | seed/fixture要求 |
| --- | --- | --- | --- |
| 登录、CSRF、登出、当前操作者 | session固定/CSRF、token错误、成员禁用、logout失效 | `FC-AUTH-001—004` | 正常/禁用/无角色成员 |
| 组织/team、成员、固定角色catalog及授予/撤销 | 树约束、TEAM必填匹配teamId、禁用立即生效、catalog只读、禁止自提权、同事务核心审计 | `FC-ORG-001`、`FC-TEAM-001—002`、`FC-MEM-001`、`FC-RBAC-001—006` | 组织/team树、TEAM scope正反例、正常/禁用成员、七角色 |
| equipment model/location/asset与不透明二维码 | 型号唯一/version、location无环、资产范围/冲突、旧码失效、匿名最小字段/统一失败 | `FC-ASSET-001—004`、`FC-QR-001—004`、`FC-API-001` | 双租户同名型号/位置/资产、当前/撤销码 |
| 报修创建/我的报修/详情/补充/验证/反馈 | 幂等、所有权、补充追加、验证不跳状态、反馈唯一性 | `FC-REPORT-001—005`、`FC-WO-006—007` | 两个报修人、supplement、已验证/可反馈工单 |
| 工单查询、状态命令、team派单/转派、work log/check item/part usage | 12状态、全部合法/非法边、转派不变状态、并发、待审批和现场事实幂等 | `FC-WO-001—014`、`FC-SLA-*` | 完整迁移链、team assignment历史、审批命令/状态矩阵、旧version、三类现场事实 |
| 工单SSE | 按权限订阅、序列单调、断线续传、慢消费者/心跳 | `FC-WO-012` | 固定事件序列与旧cursor |
| 通用附件上传/完成/下载 | 三purpose、REPORT_CREATION无owner与原子绑定、父资源权限、对象扫描/短URL，不接受knowledge purpose | `FC-FILE-001—005` | 暂无owner创建附件、`REPORT|WORK_ORDER`最终附件、错MIME/哈希与超限fixture |
| 知识列表/创建/上传/绑定/提审/评审/发布/撤回/下载 | `knowledge_version`对象哈希、审核人分离、发布门、私有短URL，不产生attachment | `FC-KNOW-001—006`、`FC-FILE-004` | 上传意图、待绑定对象、待审/驳回/发布/撤回版本 |
| SLA/质量/AI采纳报表 | 稳定分子分母、范围、重开和无决定边界 | `FC-REP-001—004` | 可手算的按日预期值 |
| 公共AI分诊/流式诊断/评估启动与查询；内部分诊/回答/报告草稿/评估 | Java权限门、Schema/fallback、stream取消、不补事实、版本化不可重建运行证据 | `FC-AI-001—013` | 固定知识/拒答/注入case；运行证据现场产生 |
| Python回调资产摘要/工单历史 | service+原操作者双上下文、每次重新授权、只读/上限 | `FC-AI-007—008` | 过期、错scope、已撤权上下文 |
| 审计列表、导出启动/状态 | 当前数据范围、导出理由、脱敏、短时结果与核心/派生source区分 | `FC-AUD-001—003` | 核心审计链；导出任务在测试现场产生 |

## 7. AI评估门

最终数据集最低80条，按`PROJECT_SPEC.md`分层。开发阶段可以小规模开始，但每次结果必须记录：

```text
dataset_version, case_id, tenant_fixture, source_version,
prompt_version, model_version, embedding_version, index_version,
retrieved_ids, cited_ids, structured_output, latency, token_or_cost,
metric_results, reviewer, failure_category
```

建议发布门在建立基线后锁定数值，施工前不伪造阈值。无论平均指标如何，以下硬失败均阻断：跨租户召回、引用不存在/未发布版本、执行非允许工具、把建议当业务命令、证据不足仍给出确定性高风险步骤。

## 8. 测试数据与环境

- 每个测试生成独立tenant ID，禁止共享“默认租户”掩盖过滤缺失；
- 测试工厂创建最少必要对象，跨租户样本成对出现；
- 数据库集成使用与生产大版本一致的PostgreSQL容器，不用H2替代关键SQL；
- 对象、事件和AI Provider使用协议级fake或容器，mock只用于稳定的内部边界；
- 时间通过Clock注入；随机数可固定seed；测试不依赖执行顺序；
- 演示种子与自动化fixture分离，均不得含真实个人或客户数据。

## 9. CI流水线与质量门

```mermaid
flowchart LR
    A["格式 / 静态检查 / 秘密扫描"] --> B["单元与参数化"]
    B --> C["模块 + PostgreSQL集成"]
    C --> D["OpenAPI / 事件契约 + 客户端编译"]
    D --> E["关键API与跨租户负向"]
    E --> F["小型AI安全评估"]
    F --> G["构建镜像与SBOM"]
    G --> H["预览环境冒烟"]
```

- PR必跑：A—F中受影响部分，但P0授权和契约不能靠路径规则全部跳过；
- 主分支/每日：完整集成、浏览器主链、依赖/镜像扫描、较完整AI评估；
- 发布候选：性能预算、移动弱网、恢复、密钥吊销和人工探索；
- 不稳定测试立即隔离并有工单、负责人和期限，不能无限重跑到变绿；
- 覆盖率作为变化线索：新/改核心业务分支应接近全覆盖，但不得用无断言测试刷数字。

## 10. 可观测性验收

测试环境至少能用`traceId`串联公共API、领域命令、outbox、消费者、Python调用和工具回调。验证：

- 日志没有Authorization、service token、签名URL、完整联系方式或文档正文；
- 指标能区分业务拒绝、权限拒绝、版本冲突、依赖超时与系统错误；
- AI记录版本与引用元数据，但不默认记录完整用户内容；
- 告警测试覆盖事件积压、撤回索引失败、跨租户防线异常和错误率突增。

## 11. 缺陷处理与完成定义

一项功能只有同时满足以下条件才完成：验收编号通过；失败链路有断言；契约已同步；关键日志/指标可观察；安全矩阵对应负向测试存在；相关文档和迁移/回滚已更新。

P0缺陷不得带病发布。P1若确需延期，必须记录影响、临时控制、负责人和截止日期。当前文档没有执行任何测试，也没有确认具体工具版本；进入对应周时依据官方文档锁定patch并记录真实报告。
