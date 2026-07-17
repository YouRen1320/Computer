---
schema_version: 2
edition: 2026.2-draft
id: ch.uniapp.packages-performance
title: 分包、启动性能、缓存与资源预算
responsibility: 用分包、懒加载、资源压缩和版本化缓存控制小程序启动与包体预算，以真实设备指标验证，不引入离线业务队列。
volume: '10'
order: 8
level: L2+
status: drafting
path: book/volume-10-uniapp-miniprogram/chapters/ch.uniapp.packages-performance.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
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
  text: 在 120 秒内解释“分包、启动性能、缓存与资源预算”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - uniapp-package-loading
  - uniapp-startup-cache-budget
  covers_topics:
  - miniapp.main-subpackage
  - miniapp.subpackage-preload
  - uniapp.lazy-component
  - miniapp.package-size-limit
  - miniapp.startup-metric
  - uniapp.asset-budget
  - uniapp.cache-version
  - uniapp.cache-eviction
  - uniapp.performance-baseline
  uses_capabilities:
  - mobile.miniprogram-runtime
  - web.javascript-testing-debugging
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“分包、启动性能、缓存与资源预算”构建可运行程序与测试：对超预算报修端实施分包与缓存版本化并保存冷启动和包体前后对比；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - uniapp-package-loading
  - uniapp-startup-cache-budget
  covers_topics:
  - miniapp.main-subpackage
  - miniapp.subpackage-preload
  - uniapp.lazy-component
  - miniapp.package-size-limit
  - miniapp.startup-metric
  - uniapp.asset-budget
  - uniapp.cache-version
  - uniapp.cache-eviction
  - uniapp.performance-baseline
  uses_capabilities:
  - mobile.miniprogram-runtime
  - web.javascript-testing-debugging
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: package-report-cold-start-measurement-regression-suite
- id: diagnose
  kind: fault-diagnosis
  text: 面对“循环分包依赖、陈旧缓存或预加载过度导致的启动回退”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - uniapp-package-loading
  - uniapp-startup-cache-budget
  covers_topics:
  - miniapp.main-subpackage
  - miniapp.subpackage-preload
  - uniapp.lazy-component
  - miniapp.package-size-limit
  - miniapp.startup-metric
  - uniapp.asset-budget
  - uniapp.cache-version
  - uniapp.cache-eviction
  - uniapp.performance-baseline
  uses_capabilities:
  - mobile.miniprogram-runtime
  - web.javascript-testing-debugging
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 分包、启动性能、缓存与资源预算

> 本章状态为 `drafting`。配套资产分析人工 package report、缓存 envelope 与冷启动样本；它没有执行真实 uni-app/微信构建、上传代码、清理真机缓存或测量设备启动。教材使用项目自定义预算，不把会变化的平台硬限制写成永久事实。真实限制、分包规则和测量 API 必须按目标版本官方文档复核。

性能优化不是“把代码变短”，而是让用户关键路径在明确预算内完成，同时保持正确性。小程序启动涉及主包下载/校验/加载、运行时初始化、首屏脚本和渲染、缓存读取与必要网络。把页面移到分包可能减少主包，却增加首次进入该页面的延迟；预加载可能改善下一页，却消耗弱网流量；缓存可能减少请求，也可能让旧 schema 令应用崩溃。本章用可测预算约束这些取舍。

## 1. 完成定义、入口与非目标

完成本章后，你应能：

1. 解释主包、分包、独立/普通加载边界和页面路径关系；
2. 从构建报告找出主包中不应存在的页面、依赖与资源；
3. 用用户旅程而非目录美观设计分包；
4. 谨慎配置预加载，计算额外流量和启动竞争；
5. 区分组件懒加载、代码分割、分包与网络数据延迟；
6. 为主包、分包、图片/字体和关键脚本建立预算；
7. 为缓存设计 schema version、环境/用户绑定、TTL 和淘汰；
8. 保存可比较的冷启动/暖启动样本与回归判据。

配套入口：

- [分包、缓存与预算分析示例](../../../examples/encyclopedia/ch.uniapp.packages-performance/README.md)
- [循环依赖、陈旧缓存和过度预载实验](../../../labs/encyclopedia/ch.uniapp.packages-performance/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.uniapp.packages-performance/README.md)

本章不实现离线业务命令队列，不给所有项目规定同一毫秒数，不用开发者工具单次测量冒充真实设备分布，也不为减包删除可访问性、错误处理或安全校验。

## 2. 先定义“启动完成”

不同团队说“启动 1 秒”可能指完全不同事件：宿主打开、首个脚本执行、页面创建、骨架可见、关键文本可见、用户能操作、首个真实数据出现。没有共同终点，优化前后无法比较。

FactoryCare 报修端建议至少记录：

- `appLaunch`：应用启动入口；
- `pageCreated`：首页实例建立；
- `shellVisible`：导航和骨架出现；
- `interactive`：关键输入/扫码按钮可操作；
- `essentialDataReady`：设备/草稿必要数据可用；
- `firstUserAction`：真实用户第一次动作（仅分析，不作为单次实验终点）。

```text
T_shell = shellVisible - appLaunch
T_interactive = interactive - appLaunch
T_data = essentialDataReady - appLaunch
```

每个时间点的实现必须稳定、无敏感数据，并记录构建版本、目标、设备/OS、基础库、网络与冷/暖状态。只看平均值会掩盖长尾，至少报告样本数、中位数和高分位；小样本时诚实列出原始值，不假装统计显著。

## 3. 冷启动、暖启动和页面进入

- **冷启动**：进程/运行时和包资源处于约定的冷初态；具体清理方式要记录；
- **暖启动**：应用/资源已有缓存或进程恢复；
- **页面首次进入**：应用已启动，但目标分包/页面尚未加载；
- **页面再次进入**：代码和数据可能已缓存。

这些指标不能混在一个数组中。优化主包可能改善冷启动，却让报修分包首次进入变慢；缓存可能改善 `T_data`，但不影响主包下载。报告要按旅程分层。

## 4. 主包与分包的思维模型

主包应包含启动所必需的页面、公共运行时和真正跨旅程复用的最小依赖。分包包含非启动关键、按旅程聚合的页面与专用资源。uni-app 的 `pages.json` 支持 `subPackages`（具体字段/大小写与目标版本以官方文档为准），其中分包页面路径相对该 `root`。

示意：

```json
{
  "pages": [
    { "path": "pages/home/index" },
    { "path": "pages/login/index" }
  ],
  "subPackages": [
    {
      "root": "packages/reporter",
      "pages": [
        { "path": "create/index" },
        { "path": "scan/index" }
      ]
    },
    {
      "root": "packages/history",
      "pages": [
        { "path": "list/index" },
        { "path": "detail/index" }
      ]
    }
  ]
}
```

这是教学示意，不是可直接发布配置。真实路由、tabBar、目标限制、独立分包和构建输出必须验证。

### 4.1 按旅程切，不按文件后缀切

“所有 components 一个包、所有 utils 一个包”通常不能形成用户可理解的加载边界。更好的问题：首次打开必须有什么？用户选择“新建报修”后需要什么？历史查询是否可以延后？图表/地图是否只在详情中使用？

### 4.2 公共依赖会把东西拉回主包

如果主入口导入一个聚合 `index.ts`，而它又导出地图、图表、上传 SDK，打包器可能把这些依赖纳入启动图。即使页面在分包，静态 import 依赖仍可能进入公共 chunk。必须查看实际 package report，而不是看源码目录猜大小。

避免“barrel 泄漏”：入口只导出启动所需符号；分包专用服务由分包内部导入；重型依赖按目标能力与旅程加载；同时保持端口合同，避免直接跨分包引用页面实现。

## 5. 循环分包依赖

不健康结构：

```text
main → reporter → history → reporter
```

或 reporter 页面导入 history 页面组件，而 history 又导入 reporter store。结果可能是公共代码提升、初始化顺序错误、包体重复或目标构建失败。用依赖图检测环：节点是主包/分包，边表示静态依赖；图必须满足项目允许的方向。

推荐：领域纯类型/小工具放明确公共核心；各分包依赖核心，不彼此导入页面；需要跨旅程导航时用路由和稳定参数，不 import 另一个页面组件。

## 6. 预加载：优化下一步，不能猜用户下一步

官方 `pages.json` 文档说明 `preloadRule` 可在进入某页面后预下载指定分包，并可按网络条件配置（各目标行为有差异）。预加载会占用网络、CPU、存储和并发资源。首页同时预载所有分包，可能让当前首屏数据与代码竞争，弱网尤其明显。

选择预载前回答：

1. 从当前页面进入目标分包的真实概率是多少？
2. 不预载时首次进入代价是多少？
3. 包有多大，用户网络/流量环境怎样？
4. 是否会与首屏 API、图片竞争？
5. 能否在 `interactive` 后或明确用户意图后触发？
6. 低概率旅程是否应该完全不预载？

建立预算：例如首页关键资源完成前禁止预载；Wi-Fi 下预载上限；弱网下禁用非必要预载；每条规则有命中率和收益证据。具体实现受平台配置约束，不能随意用 Web 预加载方式替代。

## 7. 懒加载与分包不是同义词

- **分包**：平台级代码/页面交付边界；
- **代码分割/动态加载**：构建器模块边界；
- **组件懒加载**：组件何时解析/实例化；
- **图片懒加载**：资源何时请求/解码；
- **数据延迟加载**：业务请求何时发起。

页面位于分包不代表其中所有图片都合适；组件懒加载也不保证重型依赖没进主包。每个机制要查看对应证据：package report、chunk/module 清单、网络瀑布、组件渲染时间和 API trace。

首屏关键组件不应为了“懒加载分数”延后，导致布局跳动或不可交互；非关键地图、历史图表和帮助资源可以等到用户进入相关旅程。

## 8. 资源预算

预算是项目门禁，不等于平台硬上限。示例预算文件：

```json
{
  "mainPackageBytes": 1500000,
  "subpackageBytes": 1200000,
  "singleImageBytes": 180000,
  "totalCriticalImagesBytes": 350000,
  "startupScriptBytes": 650000,
  "preloadBytesBeforeInteractive": 0
}
```

这些数字仅为离线练习。项目应从当前基线、目标平台限制、设备数据和发布风险制定，并留安全余量。CI 对构建报告比较预算，超出时列出增量最大的模块/资源，而不是只报“包太大”。

### 8.1 图片

按显示尺寸提供合适像素，不把 4000px 原图放进 300px 卡片；选择目标支持的格式；压缩时验证文字/故障细节仍可读；重复图标优先统一资产系统；非关键图可延迟。不要把用户上传附件打进静态包。

### 8.2 字体与图标

自带整套字体可能非常重，还会延迟文本。优先系统字体或必要子集，并考虑中文字符覆盖与授权。图标字体可能包含大量未用 glyph；SVG/组件方案也需核对目标支持与安全。不能为了减包让关键状态只剩颜色或不可访问图标。

### 8.3 JavaScript 与依赖

检查大库是否仅用一个函数；是否重复引入不同版本；是否因错误 import 拉入全部 locale；source map 是否错误进入发布包；开发工具依赖是否被打包；平台专用包是否进入非目标。删除前运行行为回归。

## 9. 缓存 envelope：值之外还要有语义

普通 storage 里不能只放裸数组：

```ts
type CacheEnvelope<T> = {
  schemaVersion: number
  cacheKey: string
  environment: 'test' | 'production'
  subjectHash: string
  createdAt: string
  expiresAt: string
  payload: T
}
```

读取顺序：安全解析 → 形状 → schemaVersion → 环境 → 当前用户 → key → TTL → payload schema。任何一步失败都清理/忽略并回源。缓存损坏不应让应用无法启动。

### 9.1 版本升级

三种策略：

- 直接失效：最安全，适合可重新获取的小缓存；
- 显式迁移：保留价值高的草稿，必须有旧版本 fixture；
- 双读单写：迁移期读取旧/新，统一写新，但要设删除期限。

不要用 `try/catch` 后继续把旧对象当新类型；TypeScript 类型不会验证 storage 运行时数据。

### 9.2 淘汰与配额

缓存有总预算和每类上限。可按过期优先、最近使用或业务优先级淘汰；关键草稿和可重取列表不能同等处理。写入失败必须产生确定结果，不能假装已保存。页面要能在空缓存下正确启动。

本章缓存只用于只读数据/草稿读取优化，不引入离线“稍后自动提交”的业务队列。命令重放、幂等和冲突将在下一章处理。

## 10. 陈旧缓存的典型故障

API 把 `technicianName` 改为嵌套对象，缓存还是 v1；页面直接读取新字段崩溃。首个证据是 cache envelope/version 与运行时 schema 错误，而不是网络面板，因为请求可能根本没发。

修复步骤：

1. 用旧 fixture 稳定重现；
2. 确定失效还是迁移；
3. 增加 schema version 和 decoder；
4. 清缓存、旧缓存升级、损坏缓存分别测试；
5. 在目标端验证 storage 配额/序列化行为；
6. 保留回源失败时的明确 UI。

## 11. 性能基线与实验设计

优化前先固定：构建 commit/配置、目标与版本、设备/OS、网络、账号数据规模、冷/暖初态、测量起止点、采样次数。一次改一个主要变量；同一设备交替测基线和候选，减少环境漂移。

示例报告：

| 指标 | 基线 | 候选 | 预算 | 结论 |
|---|---:|---:|---:|---|
| 主包字节 | 1,720,000 | 1,410,000 | 1,500,000 | 达标 |
| 报修分包字节 | 820,000 | 1,030,000 | 1,200,000 | 达标但增加 |
| 冷启动 interactive P50 | 1,480 ms | 1,230 ms | 1,300 ms | 达标 |
| 报修首次进入 P50 | 520 ms | 690 ms | 750 ms | 回退可接受 |
| 弱网首屏失败 | 0/10 | 0/10 | 0 | 行为保持 |

这些数字是格式示意，不是项目事实。包体改善不能掩盖关键页面回退；报告要解释取舍。

## 12. 冷启动测量常见错误

- 把第一次样本（含工具连接/编译）与后续样本混合；
- 只在开发者工具测，不记录设备；
- 每次缓存初态不同；
- 用 `Date.now` 的两个随意日志点代表可交互；
- 优化版数据更少或账号不同；
- 只报最佳值；
- 同时改分包、API、UI 和缓存，无法归因；
- 日志本身进行大量同步序列化，干扰指标。

测量代码轻量、稳定、在 release-like 构建中运行；分析事件异步批量且不含敏感信息。正式验收优先平台支持的性能工具与真机 trace。

## 13. 三种注入故障

### 13.1 循环分包依赖

package graph 中 reporter→history、history→reporter。验证器应在构建报告阶段报环；修复为共同小合同放核心，页面互不 import。重跑 package report 和所有路由回归。

### 13.2 陈旧缓存

fixture 的 schemaVersion 低于当前且 payload 缺字段，错误实现仍返回 ok。验证器应报 `STALE_CACHE_ACCEPTED`；修复为失效/迁移，再测试空、损坏、跨环境、跨用户和过期。

### 13.3 过度预加载

配置在 `interactive` 前预载两个低概率大分包，候选冷启动 P50/P95 回退。第一证据是网络/包加载时间线与规则，不是主包大小。修复规则和网络条件后，以相同样本重测。

## 14. CI 低成本门禁与真机门禁

每次提交可运行：

- 生成目标 package report；
- 检查主/分包及单资源预算；
- 检查分包依赖环和禁止跨包页面 import；
- 检查缓存 decoder fixture；
- 运行关键行为回归；
- 保存与基线的字节增量。

发布候选再运行：

- 目标真机冷/暖启动样本；
- 首次进入关键分包；
- 弱网与空缓存；
- 缓存升级/损坏；
- 预载命中与未命中旅程；
- 内存/崩溃及真实网络错误。

CI 包体绿不能推出启动绿；真机性能绿也不能推出功能正确，因此两层都要保留。

## 15. AI/Vibe coding 的性能纪律

AI 常会建议“全部懒加载”“开启所有预加载”“缓存所有接口”或引用旧包上限。接受前要求：

1. 当前 package report 证明瓶颈在哪里？
2. 关键旅程和预算是什么？
3. 方案会把成本转移到哪个页面/网络？
4. 缓存 envelope 如何版本化和绑定用户/环境？
5. 空/损坏/过期缓存怎样恢复？
6. 预载命中率和弱网成本是什么？
7. 优化前后使用同一设备、数据与初态吗？
8. 功能回归和真实设备结果在哪里？

AI 可以生成报告解析器、预算门禁和候选拆分，但不能凭代码长度宣布性能提升。只有构建报告和真实设备基线能支持结论。

## 16. 120 秒复述模板

主包放启动必需内容，分包按用户旅程承载延后页面和专用资源；实际归属看构建报告，不看源码目录。预加载会争用网络，只对高概率下一步、在合适网络和时机使用。懒组件、代码分割、分包、图片和数据延迟是不同机制。包体和启动都要设项目预算，并记录目标、版本、设备、网络、冷暖初态和明确终点。缓存必须有 schema、环境、用户、TTL 和淘汰，损坏时可回源；本章不实现离线命令队列。优化必须保留行为回归并用真机前后样本证明。

越界反例：“把所有页面分包并在首页全部预载，再把所有 API 响应永久缓存；开发者工具显示主包变小，所以启动一定更快。”它忽略首次页面代价、网络竞争、陈旧缓存和真机证据。

## 17. 速查表

| 问题 | 证据 | 修复方向 |
|---|---|---|
| 主包超预算 | package report 模块/资源增量 | 旅程分包、移除泄漏 import |
| 分包互相拉取 | package dependency graph | 稳定核心合同、单向依赖 |
| 首屏变慢 | 冷启动时间线 | 推迟预载/非关键初始化 |
| 分包首次进入慢 | 页面首次进入样本 | 谨慎预载/减小专用资源 |
| 缓存升级崩溃 | envelope/version/schema | 失效或显式迁移 |
| storage 满 | 写入结果与使用统计 | 总预算、优先级淘汰 |
| 工具快、真机慢 | 同构建真机样本 | 分设备/网络定位 |
| 优化无法归因 | 多变量同时变化 | 固定基线、单变量实验 |

## 18. 从零执行一次优化，不凭感觉改目录

下面是一轮可回滚流程。

### 18.1 建立基线

锁定 commit、依赖锁文件和目标构建参数；生成 package report；在选定设备上分别测冷启动、暖启动、首次进入报修、再次进入报修；运行功能回归。把原始数据放在不可覆盖的基线目录，而不是复制到聊天窗口后删除。

### 18.2 找最大可行动项

按字节排序主包模块/资源，追溯“为什么进入主包”。可能是首页确实使用、公共聚合导出、全局注册、静态资源引用或打包器配置。只有确认原因才选手段。一个 300 KB 库若首屏必须使用，移动文件夹不会消失；一个 50 KB 帮助图若从不首屏出现，可能是简单收益。

### 18.3 提出带预测的改动

例如：

> 把 history 页面和图表依赖移入 history 分包，预测主包减少约 240 KB；首页行为不变；历史首次进入增加不超过 150 ms；不在首页预载。

预测让结果可判定。若主包没减，检查依赖提升；若首次进入回退超预算，考虑在用户点击历史入口前的明确意图时预热，或继续减小图表资源。

### 18.4 同条件重测

重新生成报告、运行相同功能回归、用相同设备/网络/初态测量。报告字节变化和每个关键指标，不只挑有利数字。保留原始样本和异常值说明。

### 18.5 设门禁与回滚点

如果候选不达预算或破坏功能，回滚单一实验。若达标，把新 package report 当基线，并在 CI 加相同预算。不要在实验分支混入 UI 重构、API 改名和缓存协议变化，否则回滚困难。

## 19. CPU、内存与渲染不能被包体代表

小包仍可能启动慢：入口执行大量同步循环、解析巨大 JSON、一次创建长列表、重复 watch、副作用加载多个 storage、首屏图片解码或日志序列化都消耗主线程。包体是交付成本，不是执行成本。

观察：

- 长任务/脚本执行时间；
- 页面节点和列表渲染数量；
- 重复请求/重复解码；
- 首屏图片尺寸与解码；
- 内存增长和页面返回后是否释放；
- 不必要的全局响应式大对象；
- 频繁 storage 同步读写。

修复依然以用户旅程为准：列表分页/虚拟化（目标支持前提）、把非关键解析移出首帧、避免全量深响应、压缩图片、清理监听和任务。不能为了跑分移除错误提示或权限检查。

### 19.1 骨架屏不能伪造交互完成

骨架更早可见只改善 `T_shell`，若按钮仍不能用、必要数据很晚到，`T_interactive/T_data` 没改善。报告应分别记录。骨架要避免布局跳动并有可访问的加载语义；不能用无穷动画掩盖请求失败。

### 19.2 并行也有成本

启动时并行所有请求看似更快，却会竞争连接、CPU 和服务端资源；某些请求依赖认证/配置，错误并行导致重复 401。先建立依赖图：必须串行的保持明确，互不依赖且关键的受控并发，非关键的延后。用瀑布和 trace 验证，而不是把 Promise 全改成 `Promise.all`。

## 20. 缓存与发布版本的协作

应用升级时，旧 storage 仍可能存在。发布计划应列出当前 reader 支持哪些 schema、何时删除旧 reader、失败是否回源、草稿是否需要迁移。若回滚到旧应用，新版本写入的数据是否会令旧 reader 崩溃？这是双向兼容问题。

选择：

- 可重取缓存：新版本直接使用新 key，旧 key 异步清理；回滚互不干扰；
- 用户草稿：采用 envelope 和可测试迁移，必要时保留最近两个 reader；
- 敏感凭据：不在普通缓存迁移，本章不设计安全 vault；
- 大资源：依赖平台缓存策略但保持应用可在缺失时恢复。

所有兼容保留都要有删除条件，不能让 v1/v2/v3 分支永久存在。迁移失败记录稳定代码并保护用户内容，日志不包含完整草稿。

### 20.1 缓存命中不是唯一目标

高命中率可能来自过长 TTL，用户看到旧工单。为每类数据定义允许陈旧时间和刷新策略：权限/认证实时性高；静态分类表可较长；工单状态需要刷新；草稿由用户主导。展示缓存时可后台 revalidate，但必须防旧响应和跨用户/环境污染。

## 21. 性能结论的写法

合格结论：

> 在 commit A→B、微信目标、设备 X、基础库 Y、受控 Wi-Fi、各 20 个冷启动样本下，主包从 N 降到 M；interactive 中位数从 P 到 Q，高分位从 R 到 S；报修首次进入回退 T，但仍低于预算 U；功能、空缓存、缓存升级和弱网用例通过。尚未验证低端 Android 与蜂窝网络。

不合格结论：“包小了 20%，性能提升明显。”它缺少目标、样本、终点、行为回归和残余风险。

若结果无改善，也有价值：记录假设未成立与原因，撤销改动，避免未来重复同一无效实验。

性能验收还要区分“确认”和“推断”：package report 确认字节归属；同条件真机样本确认该样本集的指标；由一台高端设备推断全部用户都更快则不成立。报告中把未覆盖设备、网络、缓存初态和平台版本单列，后续补证时才能知道缺口，而不是重新猜测。

## 22. 事实来源与未验证范围

本章易变事实于 2026-07-17 对照 DCloud 官方 `pages.json` 页面路由/`subPackages`/`preloadRule`、条件编译和编译器资料，并以微信小程序目标为主要发布表面。官方文档说明分包页面相对 root、预载包与网络配置等合同；平台硬限制与优化能力会调整，项目实施时必须对照微信当前官方文档和实际构建报告。

当前未验证：DCloud/微信真实 package report、平台包大小硬限制、独立分包、真实预载调度、release 构建、设备冷启动、storage 配额、图片/字体解码、弱网和 FactoryCare 资源。配套预算数字全是教学夹具。
