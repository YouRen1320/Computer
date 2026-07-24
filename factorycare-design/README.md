# FactoryCare施工前设计资产

这里存放写业务代码前必须固定的逻辑设计、契约和验收证据。它是[项目规格](../PROJECT_SPEC.md)的可执行化补充，不是已经完成的系统，也不是可直接部署的生产模板。

## 权威顺序

发生冲突时按以下顺序处理，禁止悄悄保留两套定义：

1. [PROJECT_SPEC.md](../PROJECT_SPEC.md)：产品范围、角色、模块和唯一工单状态机；
2. 本目录中的契约与矩阵：字段、API、事件、安全和测试细节；
3. [逐周计划](../weeks/README.md)：实现顺序和学习深度；
4. 未来代码：必须服从已确认契约，变更时先写影响、迁移和回滚。

## 目录

| 目录/文件 | 内容 | 使用时机 |
| --- | --- | --- |
| [architecture.md](./architecture.md) | 系统上下文、模块依赖、数据与调用方向 | Week 09、18、21、29、34、44 |
| [data/data-model.md](./data/data-model.md) | 聚合、ER关系、状态与一致性规则 | Week 03—04、13、18 |
| [data/data-dictionary.csv](./data/data-dictionary.csv) | 表级所有权、租户键、关键字段和敏感性 | Week 13、14、18、30 |
| [contracts/public-api.yaml](./contracts/public-api.yaml) | Web/App/小程序只可调用的Java公共API草案 | Week 10、20、26、30、34、44 |
| [contracts/ai-internal-api.yaml](./contracts/ai-internal-api.yaml) | Java↔Python内部API和只读工具回调 | Week 38、40—44 |
| [events](./events/README.md) | 六个唯一版本化事件JSON Schema | Week 18、20—21、29—30、44 |
| [security/threat-model.md](./security/threat-model.md) | STRIDE式威胁、边界和验证计划 | Week 16—17、24、29、31、35、42、46 |
| [security/permission-matrix.csv](./security/permission-matrix.csv) | 角色、权限、数据范围和高风险确认 | Week 17、20 |
| [testing/test-strategy.md](./testing/test-strategy.md) | 测试层、风险映射、故障与质量门 | Week 11、18、22、29、35、43、46 |
| [testing/acceptance-catalog.md](./testing/acceptance-catalog.md) | 主链路与失败链路的稳定验收编号 | 全程 |
| [../curriculum/factorycare-stage-gates.yml](../curriculum/factorycare-stage-gates.yml) | 93 个验收编号到八个项目阶段的唯一 primary 门禁映射、负向场景与学习者证据路径 | 每次生成路线和阶段验收时 |
| [seed/seed-data-plan.md](./seed/seed-data-plan.md) | 无隐私、可重置、可重复的演示数据 | Week 13、44 |
| [adrs](./adrs/README.md) | 关键架构决策及备选方案 | 对应阶段 |
| [scripts/validate-design.rb](./scripts/validate-design.rb) | 只读验证YAML、JSON、CSV和唯一事件目录 | 修改设计资产后 |

## 唯一命名

- Java模块：`identity`、`organization`、`asset`、`workorder`、`knowledge`、`engagement`、`reporting`、`audit`、`ai-integration`；
- 组织边界：`organization` 下可建`team`；membership的`team_id`可空，但`data_scope=TEAM`必须有同租户/同organization的`teamId`；
- 固定角色catalog：`tenant_admin`、`asset_admin`、`dispatcher`、`knowledge_admin`、`technician`、`reporter`、`supervisor_auditor`；平台发布、租户只绑定；
- 12个工单状态：`CREATED`、`TRIAGED`、`ASSIGNED`、`ACCEPTED`、`IN_PROGRESS`、`PENDING_PARTS`、`PENDING_APPROVAL`、`RESOLVED`、`VERIFIED`、`CLOSED`、`REOPENED`、`CANCELLED`；
- 核心事件：`WorkOrderCreated.v1`、`WorkOrderAssigned.v1`、`WorkOrderResolved.v1`、`WorkOrderClosed.v1`、`KnowledgeDocumentPublished.v1`、`KnowledgeDocumentRevoked.v1`；
- 核心历史表：`work_order_transition`；
- 可靠事件表：`outbox_event`，与`idempotency_record`一样归`shared-infrastructure`技术能力，它不是第十个业务模块；
- 成员角色关系：`membership_role`；
- 公共API前缀：`/api/v1`；
- 内部API前缀：`/internal/v1`。

任何新增状态、事件、角色绑定表或API前缀都属于契约变更，必须先更新规格、影响、迁移、部署顺序和回滚。

## 跨文档不变量

- 工单状态、权限变更和高风险审批的核心审计，由发起模块在同一PostgreSQL事务经`audit` 的仅追加端口写入；事件消费只补派生/异步审计；
- 审批决定命令只有`APPROVE|REQUEST_CHANGES`，持久状态只有`PENDING|APPROVED|CHANGES_REQUESTED`；两个决定都让工单从`PENDING_APPROVAL`回`IN_PROGRESS`；
- `attachment`最终只属于`REPORT|WORK_ORDER`；上传`purpose`只有`REPORT_CREATION|REPORT_SUPPLEMENT|WORK_ORDER`，只有REPORT_CREATION可暂无owner且绑定后必须转REPORT；知识文件由`knowledge_version`直接定义对象键、哈希、大小和MIME；
- 转派只结束旧assignment并创建新assignment，更新team/技师、增加work-order version和核心审计；不改status、不生成transition或扩展状态集合；
- 只有chunk/embedding/索引具象等明确派生物可重建；`model_call/tool_call/eval_run/eval_result/checkpoint`等当时运行证据不能被标成可精确重建；
- catalog每行显式使用`scope=GLOBAL|TENANT`；GLOBAL只读项只由平台发布流程管理，TENANT项必须有非空`tenant_id`。

## 契约能力与证据落点

OpenAPI定义路由和DTO，验收目录定义可观察行为，seed计划定义可重现资源图；三者不相互复制字段。

验收目录只定义稳定 `FC-*` 行为身份；阶段归属由独立的 [FactoryCare 门禁注册表](../curriculum/factorycare-stage-gates.yml) 定义。全部 93 个编号必须各有且只有一个 primary 阶段。生成后的项目路线会嵌入完整门禁投影供学习使用，但它是派生物，不能反向成为权威来源；任何阶段证据都必须由学习者在对应阶段真实产生，课程仓库不得预填通过结果。

| 契约能力 | 验收组 | seed落点 |
| --- | --- | --- |
| 会话、组织、team、membership、固定role catalog/绑定 | `FC-AUTH-*`、`FC-ORG-*`、`FC-TEAM-*`、`FC-MEM-*`、`FC-RBAC-*` | 正常/禁用身份，双组织team，TEAM scope正反例，固定七角色 |
| equipment model、location、asset、二维码 | `FC-ASSET-*`、`FC-QR-*` | 双租户同名型号/位置/资产，当前/撤销码 |
| 报修、补充、验证、反馈 | `FC-REPORT-*`、`FC-WO-006—007` | 两个报修人、追加补充、已验证/可反馈工单 |
| 工单命令、assignment/转派、待审批、SSE、SLA/质量报表 | `FC-WO-*`、`FC-SLA-*`、`FC-REP-*` | 12状态合法链、team派单/转派不变状态、审批两决定、cursor序列、可手算分子/分母 |
| 通用附件与知识对象生命周期 | `FC-FILE-*`、`FC-KNOW-*` | `REPORT|WORK_ORDER` attachment与独立`knowledge_version`对象manifest |
| 分诊、流式回答、报告草稿、评估、只读工具 | `FC-AI-*` | 固定引用/拒答/注入case；调用和评估证据现场产生，不seed伪造 |

### Team API语义基线

- `listTeams/getTeam`只返回当前成员租户/数据范围内的team，列表可按`organizationId/status`白名单过滤；
- `createTeam`需`organizationId/code/name`，且父organization必须与当前tenant一致；`tenant+organization+code`唯一；
- `updateTeam`只更新name/status等允许字段并要求version；禁用已被TEAM scope或有效assignment引用的team前必须先处理引用，不级联改成员/工单；
- membership设`dataScope=TEAM`时`teamId`必填，team必须启用且与membership同tenant/organization；所有失败使用OpenAPI Problem契约，不返回跨租户摘要。

## 当前状态

本目录所有文件均为“设计候选基线”。只有在对应周完成实现、测试和阶段门后，才能把某一能力标记为已实现。外部身份提供方、对象存储、模型供应商和消息Provider均未选定生产服务。

## 快速验证

```bash
ruby factorycare-design/scripts/validate-design.rb
```

验证器只证明文件可解析、目录与关键名称一致；它不能证明API行为、安全性、数据库迁移或运行时兼容。
