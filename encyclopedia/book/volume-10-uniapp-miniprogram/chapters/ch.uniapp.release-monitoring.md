---
schema_version: 2
edition: 2026.2-draft
id: ch.uniapp.release-monitoring
title: 构建、版本、灰度、发布与监控
responsibility: 建立可追溯版本、环境构建、体验版验证、灰度发布、回退和客户端错误监控，不在本章设计通用 CI/CD 平台。
volume: '10'
order: 11
level: L3
status: drafting
path: book/volume-10-uniapp-miniprogram/chapters/ch.uniapp.release-monitoring.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.uniapp.packages-performance
- ch.uniapp.privacy-review
version_surfaces:
- uni-app-cli-vue3
- uni-app-mp-weixin-compiler
- wechat-miniprogram-base-library
- wechat-developer-tools
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“构建、版本、灰度、发布与监控”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - miniapp-release-promotion
  - miniapp-client-monitoring
  covers_topics:
  - miniapp.version-metadata
  - miniapp.preview-trial-release
  - miniapp.gray-release
  - miniapp.release-rollback
  - miniapp.error-monitoring
  - miniapp.release-correlation
  - miniapp.user-feedback-loop
  - miniapp.monitoring-privacy
  uses_capabilities:
  - mobile.uniapp-platform
  - web.javascript-testing-debugging
  - mobile.uniapp-device-permissions
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 生成一份可追溯体验版、灰度清单、监控事件和回退演练记录；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - miniapp-release-promotion
  - miniapp-client-monitoring
  covers_topics:
  - miniapp.version-metadata
  - miniapp.preview-trial-release
  - miniapp.gray-release
  - miniapp.release-rollback
  - miniapp.error-monitoring
  - miniapp.release-correlation
  - miniapp.user-feedback-loop
  - miniapp.monitoring-privacy
  uses_capabilities:
  - mobile.uniapp-platform
  - web.javascript-testing-debugging
  - mobile.uniapp-device-permissions
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: release-checklist-trial-build-smoke-rollback-drill
- id: diagnose
  kind: fault-diagnosis
  text: 面对“环境串包、版本不可追溯、灰度无停止条件或监控泄露敏感信息”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - miniapp-release-promotion
  - miniapp-client-monitoring
  covers_topics:
  - miniapp.version-metadata
  - miniapp.preview-trial-release
  - miniapp.gray-release
  - miniapp.release-rollback
  - miniapp.error-monitoring
  - miniapp.release-correlation
  - miniapp.user-feedback-loop
  - miniapp.monitoring-privacy
  uses_capabilities:
  - mobile.uniapp-platform
  - web.javascript-testing-debugging
  - mobile.uniapp-device-permissions
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 构建、版本、灰度、发布与监控

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《分包、启动性能、缓存与资源预算》](ch.uniapp.packages-performance.md)：目标包体和启动预算是发布前的硬质量条件。
- [《隐私、安全、平台声明与审核证据》](ch.uniapp.privacy-review.md)：监控字段、上传和平台审核必须符合已审查隐私合同。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。平台入口、审核规则、灰度能力和监控产品会变化；2026-07-17 已核对 DCloud 官方发布、版本和错误统计资料，真正发布前仍必须复核 uni-app 与微信小程序当期官方文档。配套程序只验证发布证据模型，不上传代码、不操作平台账号，也不证明已经产生真实体验版或线上灰度。

开发机上“能运行”与用户正在使用“可追溯、可观察、可回退的版本”之间，隔着一条完整发布链。缺少其中任一环，故障发生后都可能只剩猜测：线上究竟是哪次提交？用了哪个环境？错误是否从新版本开始？回退的是代码还是配置？日志里有没有泄露用户数据？本章把这些问题变成可检查的合同。

## 1. 本章边界与完成定义

本章负责两组能力：

1. **版本与发布**：版本元数据、预览/体验/发布的逐级提升、受控灰度和回退；
2. **客户端监控**：错误事件、版本关联、用户反馈闭环和隐私保护。

学完后应能交付一份发布候选证据包，其中至少包含：

- 唯一提交标识、干净工作树声明和依赖锁定摘要；
- 目标环境、目标平台、构建命令和不可变产物摘要；
- 人工可读版本、内部构建标识、配置版本和 API 合同版本；
- 体验版验证矩阵、执行人、时间、设备/基础库范围与结果；
- 灰度范围、观察窗口、成功指标、停止条件和决策人；
- 回退目标、触发条件、步骤、数据兼容性判断和演练结果；
- 可关联版本且经过脱敏的错误/性能事件；
- 用户反馈到缺陷、修复、验证和关闭的追踪记录。

本章不设计通用 CI/CD 平台，不教授 Git 基础，不替代平台审核，不承诺微信当前一定提供某种灰度入口，也不把“上传成功”当成“业务正确”。

配套入口：

- [发布证据模型示例](../../../examples/encyclopedia/ch.uniapp.release-monitoring/README.md)
- [串包、失去版本来源、无停止条件和敏感日志实验](../../../labs/encyclopedia/ch.uniapp.release-monitoring/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.uniapp.release-monitoring/README.md)

## 2. 先建立发布链，而不是先点“上传”

一条可审计发布链可以表示为：

```text
需求/缺陷
  → 已评审提交 commit
  → 锁定依赖与构建工具
  → 明确环境和非秘密配置摘要
  → 生成不可变构建产物 artifact
  → 记录 artifact digest
  → 预览/体验验证
  → 审核与发布决策
  → 灰度观察
  → 全量或回退
  → 版本相关监控与用户反馈
```

每个箭头都要有证据。聊天消息“我打的包”“应该是正式环境”“已经测过”不是证据，因为无法独立复现或排除误解。证据可以是结构化 manifest、命令输出、平台记录、测试报告和审批记录；证据必须指向同一个候选版本。

三个常见反例：

- 开发者从未提交的本地工作树构建，随后只记了 Git 分支名；同一分支已经变化，无法恢复产物来源。
- 体验版测试通过后又重新构建并上传正式版；第二次构建可能使用了不同依赖、环境变量或生成时间，测试并未覆盖正式产物。
- 前端代码回退了，但服务端已删除旧字段；客户端启动成功不代表关键流程可恢复。

## 3. 版本不是一个字符串

“1.2.3”只回答了用户可见版本的一部分。至少区分以下身份：

| 身份 | 回答的问题 | 示例形式 | 必须唯一吗 |
|---|---|---|---|
| 产品版本 | 用户看到哪个功能版本 | `2.4.0` | 同一发布系列可共享 |
| 构建标识 | 这是第几次候选构建 | 单调编号或时间+序号 | 是 |
| commit | 来自哪份源代码 | 完整 Git SHA | 是 |
| artifact digest | 当前字节是否就是已测产物 | SHA-256 | 是 |
| 配置版本 | 使用哪套非秘密配置 | 配置清单摘要 | 应可追溯 |
| API 合同版本 | 客户端期望何种字段/语义 | schema digest | 应可追溯 |
| 平台版本记录 | 平台接收了哪个上传版本 | 平台记录 ID | 是 |

构建清单建议保存：

```json
{
  "productVersion": "2.4.0",
  "buildId": "20260717.3",
  "commit": "<full-git-sha>",
  "target": "mp-weixin",
  "environment": "production",
  "configDigest": "sha256:<digest>",
  "contractDigest": "sha256:<digest>",
  "artifactDigest": "sha256:<digest>",
  "builtAt": "2026-07-17T09:30:00Z"
}
```

不要把 token、私钥、上传密钥或完整环境变量写入 manifest。配置摘要证明“选择了哪套配置”，而不是复制秘密。需要复现时，由受控密钥系统在授权环境中重新注入秘密。

## 4. 可复现构建与环境隔离

环境串包是指候选版本混入错误 API 地址、错误 AppID、调试开关、测试租户或开发依赖。防止串包依赖显式输入和失败即停止：

1. 构建命令必须明确目标平台和环境；
2. 依赖使用 lockfile，安装阶段不静默升级；
3. 生产构建拒绝 localhost、测试域名和调试凭据；
4. 环境配置使用 allowlist，而不是把整个 shell 环境注入客户端；
5. 生成产物后扫描已知禁用字符串；
6. 同一产物从体验提升到发布，避免重新构建；
7. 保存工具版本、命令、退出码和产物摘要。

DCloud 官方快速上手资料说明，CLI 项目可使用面向平台的 `dev` 与 `build` 命令，开发和发布产物目录/行为不同；微信小程序产物还需进入相应开发者工具或平台流程。这里的稳定结论是“开发构建与发布构建不同，且平台仍有独立提升流程”，具体命令、目录和入口以当前项目脚手架与官方文档为准。

### 4.1 为什么同一 commit 仍可能生成不同结果

- lockfile 未提交或安装器忽略 lockfile；
- Node、编译器、插件版本不同；
- 环境变量或生成文件不同；
- 构建读取当前时间、随机数、网络资源；
- 原生/平台工具自动迁移配置；
- 工作树有未提交文件；
- 构建后人工编辑产物。

因此“commit 相同”是必要条件，不是充分条件。digest、工具链和输入摘要补齐剩余身份。

### 4.2 干净工作树与例外

正式候选默认要求干净工作树。若必须用未提交补丁做诊断体验版，应明确标记 `diagnostic-only`，保存补丁摘要，且禁止提升为正式发布。不要把例外悄悄变成常态。

## 5. 预览、体验、审核与发布是不同证据层

各平台术语可能不同，但可以用四个逻辑层理解：

1. **本地/预览**：开发者验证基本启动、路由和接口；证据范围最窄；
2. **体验候选**：受控测试人员在接近真实宿主与配置上执行场景；
3. **审核候选**：材料、隐私声明、功能和版本被冻结并提交平台；
4. **用户发布**：版本真正对目标用户可用，并进入监控和回退责任期。

上一层成功不自动证明下一层。模拟器通过不能证明真机权限；体验者能访问不能证明普通用户权限；审核通过不能证明 FactoryCare 服务端健康；平台显示发布不能证明用户已加载新版本。

### 5.1 体验版验证矩阵

至少覆盖：

| 维度 | 代表场景 |
|---|---|
| 启动 | 冷启动、热启动、旧缓存、升级后首次启动 |
| 账号 | 未登录、正常用户、过期会话、无权租户 |
| 网络 | 正常、超时、断网、恢复、重复响应 |
| 权限 | 允许、拒绝、撤回、平台不支持 |
| 业务 | 扫码、手输、上传、提交、查进度 |
| 数据 | 空值、边界长度、旧合同、新增可选字段 |
| 设备 | 至少一个目标真机范围；记录型号和宿主版本 |
| 可观测 | 错误能关联 buildId，敏感值不进入事件 |

矩阵要写“期待什么”和“实际证据在哪里”，不能只打勾。失败时保留首个可信证据：构建日志、平台控制台、客户端事件、网络响应或服务端 requestId。

## 6. 灰度发布是一个受控实验

灰度不是“先给一小部分人看看”。合格灰度在开始前就定义：

- **候选版本**：唯一 artifact/buildId；
- **范围**：谁被包含、谁明确排除，分组是否稳定；
- **基线**：旧版本在同时间窗的错误率、成功率与延迟；
- **核心指标**：报修提交成功率、重复工单率、崩溃/脚本错误、上传失败率；
- **护栏指标**：隐私事件、鉴权失败、数据错误、投诉；
- **观察窗口**：至少能覆盖关键业务使用；
- **成功条件**：何时可扩大；
- **停止条件**：何时冻结扩大并调查；
- **回退条件**：何时立即恢复旧版本；
- **决策人**：谁有权扩大、暂停、回退；
- **记录**：每次决策基于哪些查询和事件。

“错误明显变多就回退”不可执行。应写成可评估条件，例如：候选组提交失败率连续两个评估窗超过基线与绝对阈值，或出现任何跨租户/敏感数据事件时立即停止。示例阈值只是团队练习值，真实阈值要由业务量、基线和风险共同决定。

### 6.1 样本小怎么办

小样本不适合假装统计显著。可以增加观察时间、优先检查高严重度事件、用确定性场景验证补充，并明确“不足以支持扩大”的结论。没有足够证据时保持当前范围，比凭感觉全量更可靠。

### 6.2 分组污染

用户在多个设备登录、缓存版本、平台版本分发延迟都会让“候选组”与“实际运行版本”不同。监控事件必须上报真实 buildId；分析按真实版本分组，而不是只按计划名单。

## 7. 回退必须在发布前设计

回退回答四个问题：回到什么、谁执行、何时触发、数据是否兼容。

### 7.1 回退对象

可能需要分别处理：

- 客户端代码版本；
- 远程功能开关；
- 非秘密配置；
- 服务端接口/实现；
- 数据迁移；
- 缓存与队列消息；
- 隐私声明或平台材料。

只写“重新发布旧包”通常不够。平台传播可能有延迟，用户可能继续运行候选版本，因此服务端必须在兼容窗口内同时接受旧/新客户端合同，或有明确强制升级与降级方案。

### 7.2 向后兼容数据

危险变更包括：删除旧客户端仍发送/读取的字段、改变状态语义、把可选字段变必填、让新版本写入旧版本无法理解的数据。发布前用兼容矩阵回答：旧客户端+新服务端、新客户端+旧服务端、新旧数据各会怎样。

### 7.3 回退演练

演练至少记录：

1. 从一个已知候选版本开始；
2. 注入满足回退条件的故障；
3. 由指定决策人确认；
4. 执行功能开关或版本回退；
5. 验证关键链路恢复；
6. 验证重复工单、队列和附件没有被二次破坏；
7. 记录恢复时间、残余用户和后续补救。

演练的“成功”不是脚本退出 0，而是既定 oracle 恢复，同时没有新增更严重风险。

## 8. 客户端错误监控：从问题到证据

监控事件至少需要：

```json
{
  "eventName": "report_submit_failed",
  "severity": "error",
  "buildId": "20260717.3",
  "productVersion": "2.4.0",
  "platform": "mp-weixin",
  "routeTemplate": "/pages/report/create",
  "operation": "create_report",
  "errorCode": "NETWORK_TIMEOUT",
  "requestId": "opaque-correlation-id",
  "occurredAt": "2026-07-17T10:02:03Z"
}
```

这些字段让人回答“哪个版本、哪个动作、哪类失败、能否关联服务端”。不要上传请求体、token、坐标、手机号、设备编号原值、照片路径或用户描述。`requestId` 应是无业务语义的关联标识，且服务端同样记录。

### 8.1 错误分类

- **代码错误**：未捕获异常、Promise 拒绝、组件生命周期错误；
- **网络错误**：DNS/连接、超时、HTTP/业务错误、响应解析；
- **合同错误**：字段缺失、枚举未知、类型漂移；
- **平台错误**：权限、宿主 API、版本兼容、资源限制；
- **业务错误**：非法状态、无权、幂等冲突、服务不可用；
- **体验问题**：按钮无反馈、长时间加载、用户主动反馈。

分类要保留原始因果但避免高基数字段。错误消息可以先映射成受控 `errorCode`，详细栈只在受控通道中保存并受保留策略约束。

### 8.2 Source map 与版本关联

压缩后的栈若没有匹配 source map，很难指向源代码。source map 必须与 artifact/buildId 一一对应，受控保存，不能把包含源代码和路径的信息公开。DCloud 的错误统计资料也强调按应用、平台、版本匹配 source map；具体上传入口和存储方式可能变化，采用任何产品前都需复核权限与数据流。

错误栈解析成功不等于根因已确认。首个可信证据还可能是请求响应、状态转换审计、上传服务日志或用户操作轨迹。

## 9. 监控隐私：可观察不等于全量采集

监控同样受数据最小化、目的限制、访问控制、保留和删除约束。实践规则：

- 事件 schema 使用字段 allowlist；未知字段拒绝而非透传；
- URL 只保留路由模板，不保留 query；
- 错误对象序列化前映射，不直接 `JSON.stringify(state)`；
- 用户描述只记录长度/是否存在，不记录正文；
- 坐标、附件、本地缓存和 token 永不进入普通事件；
- 用户/租户需要聚合时使用受控不可逆或轮换标识，并评估是否仍可识别；
- 采样不能成为忽略高严重度安全事件的借口；
- 监控 SDK 新增字段要重新进入隐私数据流审查；
- 访问日志平台的人、用途和导出要审计；
- 到期事件应删除或聚合，不无限保留。

脱敏失败是发布阻断项，而不是发布后再清理的“小问题”。数据一旦离开设备就可能进入多个副本。

## 10. 用户反馈闭环

监控看见系统认为重要的事件，用户反馈能暴露未被建模的问题。反馈入口应收集最小信息：问题类别、发生时间、当前 buildId、可选复现说明和明确选择的附件；不要默认附上全部日志或页面状态。

闭环状态示例：

```text
收到反馈 → 去重/分类 → 关联版本与监控 → 可复现/不可复现
       → 缺陷或说明 → 修复候选 → 原场景复测 → 发布 → 回访/关闭
```

“已回复用户”不等于问题解决；“无法复现”也不等于用户错误。记录已经检查的版本、设备、网络和证据缺口，为下一次出现保留可合并线索。

## 11. 发布清单：门禁而不是装饰

### 11.1 构建前

- [ ] 候选 commit 已确认且工作树状态有记录；
- [ ] lockfile、工具版本和目标平台已锁定；
- [ ] 生产环境/API/AppID 使用受控映射；
- [ ] 没有秘密进入代码、manifest、日志或产物；
- [ ] 合同、数据库和旧客户端兼容性已检查；
- [ ] 隐私声明与实际 API/SDK/字段一致；
- [ ] 包体、启动和关键性能预算通过。

### 11.2 构建后

- [ ] manifest 与 artifact digest 已生成；
- [ ] 禁用域名、调试开关和秘密扫描通过；
- [ ] 体验矩阵覆盖成功、边界和失败路径；
- [ ] 真机/宿主版本范围有记录；
- [ ] 监控事件能关联 buildId 且脱敏；
- [ ] 灰度成功/停止/回退条件已批准；
- [ ] 回退目标存在且已完成演练；
- [ ] 发布责任人与观察窗口明确。

清单项不能由一个人用“都没问题”批量确认。高风险项目需要责任分离：构建者、验证者和发布决策人至少在证据上可区分。

## 12. 诊断四类典型失败

### 12.1 环境串包

症状：体验版连接测试 API，或正式用户看见调试数据。

证据顺序：事件中的 buildId/environment → artifact manifest → 产物禁用字符串扫描 → 构建命令与配置摘要 → 源代码。先确认实际运行的字节，不要先改代码。

修复：让生产构建对测试域名失败即停止，重新生成候选，重跑原体验矩阵。残余风险是已分发错误版本仍可能被缓存，需要监控真实版本分布。

### 12.2 版本不可追溯

症状：平台上有版本，但仓库找不到唯一 commit 或 digest。

修复不是给旧产物“猜一个 SHA”。应阻止提升、重新从干净且可识别的输入构建，再完成体验验证。旧产物只能标记来源未知并隔离。

### 12.3 灰度无停止条件

症状：指标恶化但团队争论是否继续。

修复：暂停扩大，补写基线、评估窗、绝对/相对阈值和决策人；用候选与基线数据重放决策。不能事后选择最有利指标来证明原决定正确。

### 12.4 监控泄露敏感信息

症状：事件含完整 URL、token、坐标或描述。

立即停止相关采集/扩大，限制访问、启动事件响应和删除/轮换流程；代码改为 schema allowlist，加入负向 fixture，重跑事件扫描。是否需要通知、报告或进一步处置由有权人员依据适用规则决定。

## 13. 配套实验怎么使用

示例目录提供一个纯 Node 发布清单验证器。它读取候选 manifest、灰度计划与监控事件，验证：

- commit、artifactDigest、configDigest、buildId 不为空；
- 环境与目标平台在 allowlist；
- 灰度计划有成功、停止、回退条件和决策人；
- 监控事件 buildId 与候选一致；
- 事件不存在 token、坐标、正文等禁止字段。

实验目录包含四个故障 fixture。你应先预测每个 fixture 在哪个阶段失败，再执行验证器，记录首个失败字段，修复 fixture 后重跑同一命令。公开练习故意缺少停止条件，应保持红色；私有答案用于课程维护者验证，不是无 AI 考核答案。

这些脚本没有生成 uni-app 产物，没有调用微信开发者工具，没有真实上传或灰度。真实验收还需要目标项目、账号、真机、平台记录和 FactoryCare 服务端证据。

## 14. 120 秒讲解模板

可以按以下顺序回答：

1. 本章把源代码、构建输入、不可变产物、平台版本和运行事件连成证据链；
2. commit 只标识源代码，artifact digest 和配置/工具摘要补齐实际字节身份；
3. 预览、体验、审核、发布是不同证据层，不能相互替代；
4. 灰度必须预先定义范围、基线、成功、停止、回退和决策人；
5. 回退要同时考虑客户端、服务端、配置和数据兼容；
6. 监控事件用 buildId/requestId 关联，但通过 allowlist 避免敏感原值；
7. 越界反例：本章不设计公司通用 CI/CD 平台，也不能凭本地脚本宣称平台发布成功。

## 15. 自测与进一步推导

1. 为什么“Git SHA 相同”仍不足以证明两个产物相同？
2. 体验版验证后重新构建正式版，会破坏哪条证据？
3. 一个可执行灰度计划至少需要哪些停止与回退信息？
4. 为什么按计划名单统计灰度组可能失真？
5. 旧客户端+新服务端为什么是回退设计的一部分？
6. source map 为什么必须与具体 artifact/buildId 匹配？
7. requestId 有什么价值，为什么仍不能放业务敏感含义？
8. 日志字段 allowlist 比事后正则脱敏更可靠在哪里？
9. 平台显示“上传成功”还缺少哪些业务证据？
10. 如果无法证明旧产物来源，为什么不能补写一个猜测版本号继续发布？

进一步推导：一旦发布身份和事件合同稳定，Web、Flutter、服务端也可以使用同一组 `releaseId/buildId/requestId/contractDigest` 关联事故。这是跨端可观测合同，不代表所有客户端必须使用同一构建工具。

## 16. 发布事故证据包与复盘

如果灰度或正式发布出现事故，先保护用户和证据，再讨论责任。一个最小事故时间线应使用统一时区，记录：候选何时构建、谁在何时批准、平台何时可见、首个异常何时出现、哪个监控规则何时触发、谁决定暂停/回退、旧版本何时恢复、积压离线命令何时处理完成。时间线中的每个结论都链接原始证据，不用回忆填空。

事故证据包可分为五层：

1. **身份层**：commit、artifact digest、buildId、配置和合同摘要；
2. **决策层**：灰度计划、审批、扩大/停止/回退决定；
3. **运行层**：脱敏客户端事件、服务端 requestId、状态转换和依赖健康；
4. **影响层**：受影响版本、场景、时间窗、数量估计方法和不确定性；
5. **恢复层**：执行步骤、验证 oracle、剩余旧缓存/离线队列和补救记录。

不要为了复盘复制整个生产数据库或完整日志到个人电脑。查询和导出仍需最小权限、字段脱敏、受控保存与到期删除。截图如果缺少查询、时间范围和版本条件，只能作为线索；可复现查询或结构化导出才更适合独立核验。

### 16.1 先缓解还是先定位

出现跨租户、隐私泄露、持续重复创建工单或关键流程大面积失败时，优先停止扩大、关闭有害功能或回退；不应为了获得“完美根因”继续扩大影响。低风险且可控的问题可以保留小范围观察，但必须由预定义决策人依据护栏决定。

缓解后仍要保留诊断条件：标记受影响 buildId、冻结相关 manifest/source map、保存允许范围内的事件查询和服务端关联 ID。不能通过清空所有日志来“恢复”，也不能让调试开关把敏感原值上传线上。

### 16.2 复盘不是寻找一个犯错的人

高质量复盘区分触发条件、放大因素和缺失防线。例如错误 API 地址是触发条件；生产构建未拒绝测试域名是缺失门禁；体验版与正式版重新构建是证据断裂；监控没有 buildId 是发现延迟。只写“开发粗心”无法形成可验证改进。

改进行动应带所有者、期限和验证方式，例如“生产构建发现非 allowlist API 时退出非零，并在配套 fixture 中稳定失败”，而不是“以后注意环境”。行动完成后重跑原事故场景或等价演练，记录它确实阻断了同类故障。

### 16.3 发布状态机

为了避免聊天口令代替流程，可以把候选建模为：

```text
DRAFT → BUILT → TRIAL_VERIFIED → APPROVED → GRAY_RUNNING
      → PAUSED / ROLLED_BACK / FULL_RELEASED → OBSERVATION_CLOSED
```

每条边都要求证据和角色。`BUILT` 不能直接跳到 `FULL_RELEASED`；`GRAY_RUNNING` 触发停止条件后不能继续扩大；`ROLLED_BACK` 只有在恢复 oracle 通过、残余影响有记录后才能关闭观察。状态机不需要复杂平台即可执行，一张受版本控制的发布记录也能承载，但人工记录同样必须防止事后无痕改写。

### 16.4 时钟、采样和“没有错误”

不同客户端、平台和服务端的时钟可能偏移，事件上传也可能延迟。分析时间线时同时保留事件发生时间与服务端接收时间，并允许合理乱序。“监控没有错误”可能是没有用户、事件被采样、网络无法上传、SDK 未初始化、版本字段错误或查询条件错误，不能直接推导系统健康。

发布前应注入一个不含敏感数据的合成事件，确认它能以正确 buildId 到达预期查询；同时验证采集失败不会阻塞核心报修流程。监控是辅助证据，不应成为新的单点故障。

## 17. 官方资料与版本说明

- [uni-app 快速上手：运行与发布](https://uniapp.dcloud.net.cn/quickstart)
- [uni 版本说明](https://uniapp.dcloud.net.cn/tutorial/version.html)
- [uni-app 发行到微信小程序](https://uniapp.dcloud.net.cn/tutorial/build/publish-mp-weixin-cli.html)
- [uni 统计与 source map](https://uniapp.dcloud.net.cn/uni-stat-v2)

官方资料用于确认当前入口和产品行为；本章的稳定核心是发布证据、不可变身份、灰度停止条件、回退兼容与隐私最小化。任何平台按钮、账号权限、审核材料和灰度能力都应在实际发布日重新核对。
