---
schema_version: 2
edition: 2026.2-draft
id: ch.uniapp.privacy-review
title: 隐私、安全、平台声明与审核证据
responsibility: 把权限使用、最小数据、告知同意、日志脱敏和平台隐私声明映射到可审查证据，区分合规材料与真实运行时保护。
volume: '10'
order: 10
level: L3
status: drafting
path: book/volume-10-uniapp-miniprogram/chapters/ch.uniapp.privacy-review.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.uniapp.device-capabilities
- ch.uniapp.testing-debugging
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
  text: 在 120 秒内解释“隐私、安全、平台声明与审核证据”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - uniapp-privacy-data
  - miniapp-review-evidence
  covers_topics:
  - mobile.data-minimization
  - mobile.purpose-limitation
  - mobile.consent-record
  - mobile.sensitive-log-redaction
  - miniapp.privacy-declaration
  - miniapp.permission-purpose
  - miniapp.review-checklist
  - miniapp.review-rejection-trace
  uses_capabilities:
  - mobile.uniapp-device-permissions
  - web.javascript-testing-debugging
  - security.web-threat
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“隐私、安全、平台声明与审核证据”构建可运行程序与测试：制作报修端数据流、权限用途、隐私声明和真机审核证据包；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - uniapp-privacy-data
  - miniapp-review-evidence
  covers_topics:
  - mobile.data-minimization
  - mobile.purpose-limitation
  - mobile.consent-record
  - mobile.sensitive-log-redaction
  - miniapp.privacy-declaration
  - miniapp.permission-purpose
  - miniapp.review-checklist
  - miniapp.review-rejection-trace
  uses_capabilities:
  - mobile.uniapp-device-permissions
  - web.javascript-testing-debugging
  - security.web-threat
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: data-flow-audit-permission-review-matrix-negative-device-test
- id: diagnose
  kind: fault-diagnosis
  text: 面对“声明与代码不一致、日志泄露位置或拒绝权限后无降级”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - uniapp-privacy-data
  - miniapp-review-evidence
  covers_topics:
  - mobile.data-minimization
  - mobile.purpose-limitation
  - mobile.consent-record
  - mobile.sensitive-log-redaction
  - miniapp.privacy-declaration
  - miniapp.permission-purpose
  - miniapp.review-checklist
  - miniapp.review-rejection-trace
  uses_capabilities:
  - mobile.uniapp-device-permissions
  - web.javascript-testing-debugging
  - security.web-threat
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 隐私、安全、平台声明与审核证据

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《上传、扫码、定位、权限与失败路径》](ch.uniapp.device-capabilities.md)：隐私声明必须与实际扫码、相机、位置和上传权限路径逐项一致。
- [《单元/组件测试、Mock、真机和网络调试》](ch.uniapp.testing-debugging.md)：审核材料需要可复现真机路径、日志和失败截图，而非文字声明。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`，属于工程教材而非法律意见。适用义务取决于组织、业务、数据、用户、地区和最新法规/平台规则，应由有权决策的法务、隐私与安全人员确认。配套资产只检查声明—代码—证据的一致性和日志脱敏，不访问微信公众平台、不提交审核，也不证明实际合规。

“隐私指引已填写”不等于应用安全；“系统弹窗点了允许”也不等于可以无限使用数据。真实保护来自目的和最小化、明确数据流、受控权限时机、服务端授权、传输/存储保护、日志脱敏、保留/删除和可验证拒绝路径。平台材料是这些事实的一种声明，应与运行时一致，而不是为了审核临时写文案。

## 1. 完成定义、入口与非目标

完成本章后，你应能：

1. 画出报修端从采集到删除的数据流；
2. 为每项数据写明目的、来源、接收方、保留与删除；
3. 区分普通信息、可能敏感的信息、凭据和不应采集的数据；
4. 把页面告知、业务选择、系统权限和平台隐私流程分层；
5. 让代码实际使用的权限/API 与平台声明逐项对应；
6. 验证拒绝/撤回后核心非敏感流程仍可使用；
7. 证明日志、崩溃和分析事件不泄露位置、token、附件与原文；
8. 制作可重现的审核前证据和驳回追踪。

配套入口：

- [数据流与声明一致性示例](../../../examples/encyclopedia/ch.uniapp.privacy-review/README.md)
- [声明漂移、日志泄露和缺失降级实验](../../../labs/encyclopedia/ch.uniapp.privacy-review/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.uniapp.privacy-review/README.md)

本章不生成最终法律文本，不决定处理的法律基础，不替代个人信息保护影响评估/安全评估，不为审核通过作保证，也不教绕过平台隐私检查。

## 2. 从法律原则到工程问题

中国《个人信息保护法》第六条要求处理具有明确、合理目的、与目的直接相关并采取影响最小方式，收集限于最小范围；第七条要求公开透明。第二十八至三十条对敏感个人信息规定更严格条件，并涉及特定目的、充分必要、严格保护、单独同意和额外告知等要求。具体适用由专业人员判断。

工程转译：

- “未来可能有用”不是明确目的；
- 获取位置不等于必须获取高精度持续轨迹；
- 用于到场导航不能顺便用于员工画像；
- 权限允许后仍应只在用户发起相关动作时采集；
- 数据离开客户端前仍需服务端授权和最小字段；
- 保留期到达要真正删除/匿名化，而非仅隐藏 UI；
- 第三方 SDK 也是数据流的一部分。

## 3. 数据清单：没有清单就无法声明

为每个字段建立处理记录：

| 数据 | 来源 | 目的 | 必要性 | 发送/接收方 | 保留 | 删除/撤回 | 证据 |
|---|---|---|---|---|---|---|---|
| 设备编号 | 扫码/手输 | 关联报修设备 | 核心 | FactoryCare API | 随工单政策 | 工单规则 | schema、请求 fixture |
| 问题描述 | 用户输入 | 描述故障 | 核心 | FactoryCare API | 随工单政策 | 工单规则 | 表单与 API |
| 照片 | 用户主动选择 | 展示故障 | 可选 | 上传服务/对象存储 | 明确期限 | 删除附件流程 | 权限/上传证据 |
| 单次位置 | 用户主动选择 | 协助到场 | 可选 | FactoryCare API | 更短期限 | 撤回/删除路径 | 拒绝与降级测试 |
| token | 身份系统 | 认证 | 核心 | 受控 API | 短期 | 登出/失效 | 安全存储/日志扫描 |
| 诊断日志 | 应用生成 | 故障排查 | 最小化 | 日志平台 | 短期 | 自动清理 | 字段 allowlist |

表格内容必须由真实实现/政策确认，不能把“随工单政策”留作上线答案。每次新增 SDK/API/字段，先更新数据流与决定，再写代码；否则声明永远落后。

## 4. 数据流图要包含失败路径

```text
用户输入/设备能力
  ↓（本地校验、可选权限）
页面状态/临时文件
  ↓ HTTPS + 认证 + 最小字段
API 网关/后端
  ├─ 数据库（工单字段、访问控制、保留）
  ├─ 对象存储（附件、受控访问、清理）
  ├─ 日志/监控（脱敏字段）
  └─ 明确第三方处理者（若有）
```

失败也有流：上传 413 的错误体是否带文件名？崩溃报告是否包含完整页面 state？请求重试是否把 token 写入 URL？离线草稿是否含位置？删除工单是否同步清理附件、缓存、搜索和备份政策？

## 5. 数据最小化是字段和精度级别

最小化不只是少调用 API：

- 扫码只保存验证后的设备编号，不保存原始二维码/图片；
- 定位若只需到场参考，可考虑较低精度/一次性，而非持续轨迹；
- 上传只收故障所需媒体，限制数量/大小/类型；
- 日志记录 path template 和错误码，不记录完整 URL/query/body；
- 分析事件记录功能结果，不记录问题描述/设备号/坐标；
- crash state 用字段 allowlist，不序列化整个 store；
- 客户端不收集服务端已有且当前目的不需要的资料。

“先收集再脱敏”仍发生了收集。最佳方案常是源头不产生。

## 6. 目的限制与用途变化

数据为“处理报修”收集，后来想用于员工效率画像、营销或模型训练，是新目的/新风险，不能由原按钮授权自动覆盖。先做新的合法性/必要性评估、告知与相应授权流程，并提供退出/权利路径。

代码层可用 `purpose` 元数据和服务端访问边界帮助审计，但字符串标签不能单独保证限制。数据仓库权限、导出、分析任务、第三方共享也要受控。

## 7. 四种不同“同意/允许”

1. **页面解释/业务选择**：用户知道为什么附加位置并主动选择；
2. **平台隐私流程**：小程序平台对相关隐私接口的声明/授权机制；
3. **系统/宿主权限**：OS 或小程序 scope 允许 API；
4. **组织处理依据与记录**：由适用法律和业务决定的合法基础/记录。

一层不能替代另一层。系统 permission granted 只说明 API 可调用；平台隐私指引通过不证明服务端最小化；勾选业务按钮不绕过系统权限。处理敏感信息时的具体告知/单独同意等要求必须由专业人员按实际情境确认。

### 7.1 同意记录不要过度

若处理以同意为依据，记录应能证明版本、范围、动作和时间，同时自身最小化。不要保存屏幕录制、完整设备指纹来“证明同意”。撤回后按规则停止未来处理，并说明无法逆转的合法已完成事项；系统权限撤回与业务撤回都要测试。

## 8. 平台隐私声明与代码清单

建立机器可比较表：

| 能力/API | 数据类型 | 代码位置 | 用户动作 | 页面用途 | 平台声明 | 拒绝降级 | 真机证据 |
|---|---|---|---|---|---|---|---|
| scan | 扫码内容 | ScanAdapter | 点击扫码 | 填设备号 | 当前配置项 | 手输 | 首次/取消 |
| choose media | 用户选择文件 | MediaAdapter | 点击附件 | 故障照片 | 当前配置项 | 文本报修 | 选择/取消 |
| location | 单次坐标 | LocationAdapter | 勾选并点击 | 到场参考 | 当前配置项 | 不附位置 | 拒绝/设置 |
| upload | 文件/元数据 | UploadAdapter | 提交 | 保存附件 | 域名/声明 | 去掉附件 | 失败/重试 |

具体微信隐私 API、接口分类和后台字段会变化，应以当前微信开放文档/公众平台为准。本教材不硬编码一份永久清单。扫描代码只是线索：动态插件、条件编译和服务端数据仍需人工核对；反过来，声明了但代码未用也要删除多余声明。

## 9. 拒绝权限后核心流程仍可用

若定位与照片是可选，拒绝后仍能手工输入设备、写描述并提交。扫码拒绝有手输；相册拒绝有纯文本；位置拒绝有不附位置。不能把所有权限串成页面准入门槛。

负向真机用例：首次拒绝、曾经拒绝、设置中撤回、调用中取消、能力不存在、隐私流程未完成。断言核心流程、文案和恢复，不只断言“没有崩溃”。

如果某数据确属核心必要（需充分评估），界面应清楚说明无法提供哪些具体服务，而不是无限弹窗或诱导允许。

## 10. 日志脱敏：默认 allowlist

不要“先记录一切，再用正则替换 token”。采用允许字段：

```ts
type SafeEvent = {
  event: string
  target: string
  appVersion: string
  operationId: string
  pathTemplate?: string
  status?: number
  errorCode?: string
  durationBucket?: string
}
```

明确禁止：Authorization/cookie/refresh token、完整 URL/query、请求/响应 body、问题描述、扫码原文、精确坐标、临时路径、照片名/字节、手机号/姓名、未经评估的设备唯一标识。

对 error 对象先映射稳定 code，不直接 `JSON.stringify(error, state, request)`。生产 console 也可能被平台/SDK/远程调试收集，不是安全角落。

### 10.1 自动扫描与诱饵

测试使用 sentinel token、坐标、描述、文件路径，触发成功/失败/崩溃后扫描所有日志输出，断言不出现。正则只是补充；结构化 allowlist 更可靠。第三方 SDK 的日志/网络也要检查。

## 11. 安全保护不等于隐私文案

- HTTPS/TLS 与域名配置保护传输但不决定最小化；
- 认证证明主体但不等于资源授权；
- 客户端隐藏按钮不能阻止越权 API；
- 普通 storage 不是凭据/敏感队列安全存储；
- 文件服务重新验证内容、类型、大小与权限；
- 服务端按 tenant/membership 授权每个工单和附件；
- 秘钥不进入小程序包；
- 第三方 SDK/云服务纳入供应链和数据流评估。

审核截图无法证明这些运行保护，必须有测试、配置和服务端证据。

## 12. 保留、删除和权利路径

对每类信息定义期限或确定方法、触发清理的事件、存储副本和责任服务。删除可能涉及主库、附件、缓存、搜索索引、日志与备份周期；客户端登出清理本地主体数据，但不冒充服务端已删除。

用户查询、更正、删除、撤回等适用权利流程由组织提供。工程需有可认证入口、审计、防止删除他人数据和状态反馈。不要用“联系客服”三个字掩盖不可执行流程。

## 13. 第三方与 SDK

列出 SDK 名称/版本、提供方、功能、收集字段、触发时机、网络域、存储、配置开关、合同/政策和替代方案。用包清单、运行网络抓取和代码路径交叉验证。

SDK 即使初始化后“暂时不用”，也可能访问设备/网络。非必要 SDK 不进入包；可延迟到用户使用相关功能且满足前置条件后初始化。升级需重新 diff 权限/API/域名与隐私文档。

## 14. 审核证据包

```text
review-evidence/
├── release.json            # commit、构建、目标、版本
├── data-inventory.yml      # 数据、目的、保留、接收方
├── permission-matrix.yml   # API、声明、触发、降级
├── code-scan.txt           # 相关 API/SDK 线索
├── network-inventory.yml   # 受控域与目的
├── device-cases/           # 首次、允许、拒绝、撤回、取消
├── log-redaction.txt       # sentinel 扫描结果
├── screenshots-index.md    # 脱敏截图说明
└── residual-risks.md       # 未验证与责任人
```

证据与同一 release commit/版本绑定。截图要说明操作/预期/设备，不放真实个人信息。审核通过后代码变更仍可能造成漂移，所以发布流水线持续检查。

## 15. 驳回追踪

收到平台驳回不要只复制一句话。记录：审核版本、规则/消息原文、提交与发生时间、可重现页面/步骤、平台检测到的 API/数据、当前声明、代码位置、根因、修复 commit、重提版本、结果、残余风险。

分类：声明缺项、声明多余/不一致、权限时机、拒绝无降级、页面文案、域名/第三方、实际功能问题。若无法复现，先用相同提交/配置/目标/账号重建，不用随机改隐私弹窗。

## 16. 三个注入故障

### 16.1 声明与代码不一致

代码扫描和真机 trace 出现 location，permission matrix/平台声明没有。第一证据是 API—声明 diff。修复可能是删除不必要调用或补齐经评估的目的/声明/流程；不是只给清单加一行。

### 16.2 日志泄露位置

sentinel 坐标在 error 日志中出现。第一证据是结构化事件 payload 与调用栈。修复用 allowlist/稳定错误码，并扫描成功、拒绝、超时、崩溃路径。

### 16.3 拒绝后核心阻塞

用户拒绝可选位置后提交按钮永久禁用。第一证据是负向设备用例与组件状态。修复把 location 从核心校验中移除，提供“不附位置继续”，重跑首次/曾拒绝/撤回。

## 17. 发布前检查

1. 数据清单与服务端/第三方真实流一致；
2. 每项数据有明确目的、必要性、保留与删除；
3. 代码 API 与平台声明双向一致；
4. 权限仅在用户相关动作后请求；
5. 可选权限拒绝有核心降级；
6. 日志 sentinel 全路径扫描绿；
7. storage/离线队列不含未评估敏感数据；
8. 服务端认证、授权、文件和租户测试绿；
9. 真机首次/拒绝/撤回/取消证据齐；
10. 法务/隐私/安全及平台配置按组织流程确认；
11. 未验证事项、责任人和上线阻断明确；
12. 证据绑定实际 release build。

## 18. 从零做一次数据流审计

### 18.1 先从用户动作枚举入口

不要只搜索 `getLocation`。列出启动、登录、扫码、手输、选择照片、定位、提交、查看、分享、重试、退出、删除等动作。对每个动作记录读取了什么、写到哪里、发往哪个域、哪些 SDK 收到、失败时记录什么。再补充无用户动作的入口：应用初始化、定时器、推送、后台恢复、崩溃和分析。

### 18.2 静态线索与运行证据交叉

静态线索：API 调用、权限配置、manifest/pages、依赖/SDK、环境域名、日志函数、storage key、网络客户端、服务端 DTO。运行证据：目标产物、网络 trace、storage 快照、设备权限路径、服务端 access/audit log、第三方控制台。任何一边单独都可能漏：条件编译让静态搜索出现未发布代码；动态 SDK 让搜索看不到运行网络。

### 18.3 找所有者确认

每条数据流有业务目的 owner、技术系统 owner、保留/删除 owner 和审核决定来源。教材不能替他们填答案。若“保留多久”“是否共享第三方”“拒绝能否使用”无人确认，应作为上线阻断或显式风险，不以默认值掩盖。

### 18.4 形成双向可追踪关系

```text
数据项 → 目的 → UI 告知/选择 → 权限/API → 客户端字段
      → 网络域/服务端字段 → 存储/第三方 → 保留/删除 → 测试/证据
```

也从代码反查：每个权限/API/SDK/日志字段能否回到数据项和目的？找不到就是未声明/无目的漂移；声明项找不到实际代码则可能过度声明或遗留材料。

## 19. 权限矩阵要覆盖生命周期

| 阶段 | 允许 | 拒绝 | 撤回 | 能力不存在 |
|---|---|---|---|---|
| 首次进入页面 | 不主动采集 | 不弹窗 | 重新查询状态 | 展示替代入口 |
| 用户点击能力 | 调用一次 | 显示用途与降级 | 进入恢复流程 | 直接 fallback |
| 调用中 | 只处理本次结果 | 不产生空“成功”数据 | 丢弃旧结果 | 不调用宿主 |
| 页面恢复 | 按需显示当前状态 | 不自动重问 | 重查后更新 UI | 保持 fallback |
| 提交 | 只发用户选择数据 | 核心流程可继续（若可选） | 不读取旧缓存 | 不发送该字段 |
| 登出/换账号 | 清主体缓存 | 同样清理 | 同样清理 | 同样清理 |

每格都应有预期与证据，避免只测首次允许。平台隐私流程、系统权限和页面选择也要组合：隐私指引未完成但系统曾允许；系统允许但业务未选择附加位置；用户撤回后 storage 仍有旧位置。这些组合暴露最多漂移。

### 19.1 拒绝不是“异常用户”

隐私保护的质量可由拒绝路径判断。按钮仍可键盘操作、文案不羞辱/诱导、核心字段保持、替代入口可发现、不会反复弹窗、不会暗中调用其他 API 获取同类数据。把拒绝测试放入发布回归，而不是审核前临时手点。

## 20. 日志和遥测的工程门禁

集中提供 `safeEvent(name, fields)`，字段 schema 拒绝未知 key；网络层只接受 method/pathTemplate/status/duration/trace；设备层只接受 capability/outcome，不接受 raw result。构建/测试扫描以下 sentinel：

```text
TOKEN_SENTINEL_7e...
DESCRIPTION_SENTINEL_private
31.123456,118.654321
wxfile://SENTINEL_PATH
DEV-SENSITIVE-RAW-CODE
```

分别触发成功、校验失败、HTTP 错误、超时、取消、权限拒绝、异常捕获和 crash breadcrumb。扫描 stdout、结构化 sink、网络遥测请求与本地日志文件。绿灯只说明这些夹具未泄露，仍需审查字段组合能否间接识别。

### 20.1 哈希不是自动匿名

用户 id/设备号哈希若稳定、可跨事件关联，仍可能是个人信息/去标识化数据，不应因为“看不懂”就不纳入清单。使用按目的限定的短期关联 id，控制密钥/盐与访问，必要时聚合后删除明细。具体法律分类由专业人员确认。

## 21. 删除与撤回的验证旅程

建立测试账号和唯一标记数据：创建含可识别 fixture 的工单/附件/可选位置；验证查询；执行适用删除/撤回；检查主 API 不可见/已按规则处理；检查附件访问、客户端缓存、搜索/索引、日志留存策略和下游任务；记录备份/法定保留的政策结果。不要在生产随意使用真实个人数据做测试。

撤回同意通常影响未来基于该同意的处理，不等于技术上瞬间抹除所有合法留存；具体行为按组织确认的处理规则实现并清楚反馈。工程测试只验证已批准的合同，不能自己编法律结论。

## 22. 事故与泄露响应准备

隐私不是只在审核时处理。系统要能回答：哪些版本/用户/字段/时间受影响；数据去了哪些系统/第三方；如何止血（关闭功能/撤销 token/阻断域）；如何保全必要证据而不扩大泄露；如何修复、删除和按流程通知；怎样防复发。

日志最小化会减少事故影响，但仍要有 release、配置和数据流版本。远程功能开关若用于关闭敏感能力，必须受认证授权、审计和安全默认保护；断网/配置失败时不能默认扩大采集。

### 22.1 审核通过后的持续漂移检测

每次依赖/SDK/API/域名/字段变化触发数据流 diff；CI 扫描新增隐私 API/权限/网络域；发布清单要求 owner 确认声明和降级；定期运行负向真机和日志 sentinel。平台规则更新也进入依赖/版本表面，而不是等下一次驳回才发现。

## 23. 角色与交接

- 产品：目的、必要性、核心/可选体验；
- 工程：真实代码/数据流、保护、测试和证据；
- 安全：威胁、访问、凭据、日志、第三方；
- 隐私/法务：适用规则、处理依据、告知/同意、权利/保留；
- 运维：日志/监控/事件响应/删除任务；
- 发布负责人：平台声明、审核材料与 release 绑定。

任何角色都不能凭一张表替代其他层。决策记录写日期、适用版本、owner 和复审条件。未决项明确阻断/风险接受人。

交接时附“确认/未确认”两列：代码扫描、离线日志夹具可以由工程确认；微信后台配置、真实设备、第三方合同和组织保留决定若尚未执行只能标未确认。材料里不要用“应当已经配置”“预计不会收集”等模糊措辞冒充事实。证据文件本身也可能包含个人信息，应使用测试数据、最小访问权限和明确清理期限。

上线后若产品增加字段、改变用途、接入 SDK 或把可选能力改成必填，要重新走数据流与决定流程；“以前审核通过”不是永久豁免。相反，删除功能时也要删除多余权限、声明、SDK、网络域和旧数据处理任务，降低攻击面与维护成本。

## 24. AI/Vibe coding 验收

AI 可以找 API、生成数据流草案和日志扫描器，但可能使用旧平台规则、把系统权限当法律同意、虚构保留期或漏掉第三方。要求每个事实有代码/配置/官方规则/组织决定来源；不确定标待确认。绝不让模型自行决定“此数据不敏感”或生成最终法律承诺后直接上线。

检查 AI 代码是否整 store 打日志、把位置放分析事件、页面加载即请求权限、拒绝后阻塞、将 secret 编进 env、只改文案不改数据流。验证器和真机负例比模型解释更可信。

## 25. 120 秒复述模板

隐私工程从真实数据流开始：每项数据写明来源、目的、必要性、接收方、保留、删除和证据；遵循目的限制与最小化。页面业务选择、平台隐私流程、系统权限和组织处理依据是不同层，不能互相替代。代码使用的 API/SDK 与平台声明双向一致；可选权限拒绝后核心流程仍可用。日志使用字段 allowlist，不含 token、完整 URL、描述、坐标和附件。审核材料绑定 release，并以首次、拒绝、撤回、取消的真机证据和服务端保护支撑；审核通过不等于实际合规/安全。

越界反例：“为了通过审核，把相机、定位和通讯录全部写进声明；页面打开就请求，拒绝后不能报修；调试时把完整请求和坐标上传日志。”声明既不最小也与目的不符，运行时还泄露数据。

## 26. 事实来源与未验证范围

法律原则与平台资料于 2026-07-24 对照下列官方一手页面。平台流程和接口会变化，上线前必须重新核对微信开放文档和公众平台实际配置。本章避免把任何法律基础、同意形式或保留期替项目作最终决定。

直接来源：

- 中国网信网转引中国人大网，[《中华人民共和国个人信息保护法》](https://www.cac.gov.cn/2021-08/20/c_1631050028355286.htm)：目的明确、影响最小、最小范围、公开透明与敏感个人信息等法律文本。
- 国家互联网信息办公室，[个人信息保护政策法规问答（2026 年 1 月）](https://www.cac.gov.cn/2026-01/09/c_1769688003183197.htm)：个人信息、敏感个人信息与保护责任的官方解释材料。
- 微信开放文档，[用户隐私保护指引填写说明](https://developers.weixin.qq.com/miniprogram/dev/framework/user-privacy/)：小程序平台声明表面；后台实际配置仍须按发布候选核验。
- 微信开放文档，[`wx.getPrivacySetting`](https://developers.weixin.qq.com/miniprogram/dev/api/open-api/privacy/wx.getPrivacySetting.html) 与 [`wx.requirePrivacyAuthorize`](https://developers.weixin.qq.com/miniprogram/dev/api/open-api/privacy/wx.requirePrivacyAuthorize.html)：隐私授权状态与触发接口表面。
- DCloud，[`uni.authorize`](https://uniapp.dcloud.net.cn/api/other/authorize.html)：uni-app 对小程序授权 scope 与失败/恢复关系的文档表面。

当前未验证：FactoryCare 实际主体/隐私政策、处理法律基础、微信后台声明、隐私接口、第三方 SDK、服务端/对象存储/日志数据流、删除/备份、跨境、未成年人、影响评估、真实设备与审核。任何绿灯都不是法律结论。

这些缺口在正式发布前必须由对应责任人逐项确认、补证或明确阻断，不能由教材示例推断为已完成。
