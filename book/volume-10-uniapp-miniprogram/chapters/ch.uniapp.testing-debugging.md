---
schema_version: 2
edition: 2026.2-draft
id: ch.uniapp.testing-debugging
title: 单元/组件测试、Mock、真机和网络调试
responsibility: 在 uni-app 中选择纯函数、组件、宿主 Mock、真机和网络调试证据，明确模拟器通过不能代替目标真机验证。
volume: '10'
order: 7
level: L2+
status: drafting
path: book/volume-10-uniapp-miniprogram/chapters/ch.uniapp.testing-debugging.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.uniapp.template-components
- ch.uniapp.network-auth-storage
version_surfaces:
- uni-app-cli-vue3
- uni-app-mp-weixin-compiler
- wechat-miniprogram-base-library
- wechat-developer-tools
- vitest
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“单元/组件测试、Mock、真机和网络调试”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - uniapp-automated-testing
  - uniapp-device-debugging
  covers_topics:
  - uniapp.unit-test
  - uniapp.component-test
  - uniapp.platform-api-mock
  - uniapp.async-test
  - uniapp.device-log
  - uniapp.network-panel
  - uniapp.source-map
  - uniapp.emulator-device-gap
  - uniapp.repro-bundle
  uses_capabilities:
  - web.javascript-testing-debugging
  - web.vue-template
  - mobile.miniprogram-runtime
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“单元/组件测试、Mock、真机和网络调试”构建可运行程序与测试：为报修表单和网络客户端建立单元/组件测试并制作一个真机最小复现包；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - uniapp-automated-testing
  - uniapp-device-debugging
  covers_topics:
  - uniapp.unit-test
  - uniapp.component-test
  - uniapp.platform-api-mock
  - uniapp.async-test
  - uniapp.device-log
  - uniapp.network-panel
  - uniapp.source-map
  - uniapp.emulator-device-gap
  - uniapp.repro-bundle
  uses_capabilities:
  - web.javascript-testing-debugging
  - web.vue-template
  - mobile.miniprogram-runtime
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: unit-component-test-platform-mock-device-repro
- id: diagnose
  kind: fault-diagnosis
  text: 面对“Mock 与宿主行为不一致、源码映射缺失或只在模拟器通过”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - uniapp-automated-testing
  - uniapp-device-debugging
  covers_topics:
  - uniapp.unit-test
  - uniapp.component-test
  - uniapp.platform-api-mock
  - uniapp.async-test
  - uniapp.device-log
  - uniapp.network-panel
  - uniapp.source-map
  - uniapp.emulator-device-gap
  - uniapp.repro-bundle
  uses_capabilities:
  - web.javascript-testing-debugging
  - web.vue-template
  - mobile.miniprogram-runtime
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 单元/组件测试、Mock、真机和网络调试

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《uni-app 模板、组件、表单与 Vue 差异》](ch.uniapp.template-components.md)：组件测试需要明确模板、事件、表单和组件合同。
- [《网络、认证、存储与多环境配置》](ch.uniapp.network-auth-storage.md)：网络、认证和存储错误是宿主调试的核心负例。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套资产用 Node.js 验证测试分层、异步时序、宿主 Mock 合同和最小复现清单；没有安装 DCloud 测试插件、Vitest、微信开发者工具，也没有连接真机。离线绿灯不能证明真实页面渲染、基础库行为、网络面板、source map 或设备权限已经通过。

测试的目的不是“让 BUILD SUCCESS 出现”，而是对具体风险提供能失败的判据。uni-app 同一份源码会经过编译器、Vue 运行时、平台运行时、设备和网络，因此没有一种测试能证明全部层。纯函数测试快而稳定，却看不到宿主差异；开发者工具能看到目标产物，却仍可能与真机不同；真机截图有现实性，却可能无法复现和自动回归。本章建立分层证据链。

## 1. 完成定义、入口与非目标

完成本章后，你应能：

1. 为一个风险选择纯函数、组件、宿主 Mock、目标自动化或真机测试；
2. 用 Arrange—Act—Assert 写出独立、确定的单元测试；
3. 让组件测试验证用户可见行为，而不是 Vue 内部实现；
4. 设计与真实宿主合同一致的 Mock，并保存合同差异；
5. 控制 Promise、定时器、取消和旧响应等异步场景；
6. 从目标、版本、source map、网络请求和服务端日志中定位失败层；
7. 制作他人能重复运行的最小真机复现包；
8. 清楚写出“自动化通过但尚未验证什么”。

配套入口：

- [分层测试与复现包示例](../../../examples/encyclopedia/ch.uniapp.testing-debugging/README.md)
- [Mock 漂移、source map 与模拟器偏差实验](../../../labs/encyclopedia/ch.uniapp.testing-debugging/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.uniapp.testing-debugging/README.md)

本章不把某个测试框架版本硬编码成永久标准，不用测试替代类型检查/代码审查，不伪造真机记录，也不要求所有逻辑都做端到端测试。

## 2. 测试金字塔要按风险解释

```text
                少量真实设备关键旅程
             目标平台自动化 / 网络集成
          Vue 组件行为 / 平台适配器合同
       大量纯函数、状态机、schema 与映射测试
```

越靠下，运行快、定位准、环境少；越靠上，现实性高、运行慢、失败原因多。不是“上层更高级”，而是不同证据。工单金额计算应优先纯函数；表单禁用与错误提示适合组件测试；`uni.request` 状态映射适合假 transport；微信权限弹窗和真机域名规则必须到目标平台；完整扫码报修需要少量真机关键旅程。

每条用例先写风险句：

> 当用户快速切换设备时，旧请求晚到可能覆盖新设备；测试应控制两次 Promise 完成顺序，并断言页面只显示最新结果。

这比“测试 loadData 方法”明确得多。

## 3. 纯函数测试：最快的错误定位层

把格式化、校验、状态转移、错误映射和缓存解码从组件中抽出：

```ts
export function validateRepairDraft(input: RepairDraft): ValidationResult {
  const errors: Record<string, string> = {}
  if (!/^DEV-[A-Z0-9]{6,20}$/.test(input.deviceCode)) errors.deviceCode = '设备编号格式不正确'
  if (input.description.trim().length < 10) errors.description = '问题描述至少 10 个字符'
  return { valid: Object.keys(errors).length === 0, errors }
}
```

测试遵循 AAA：

```ts
it('rejects a short repair description', () => {
  // Arrange：输入直接表达边界。
  const draft = { deviceCode: 'DEV-A1B2C3', description: '异响' }
  // Act：只调用一个可观察行为。
  const result = validateRepairDraft(draft)
  // Assert：断言合同，不断言内部循环。
  expect(result.errors.description).toBe('问题描述至少 10 个字符')
})
```

至少覆盖正常、边界、失败。不要让多个用例共享可变全局对象；不要依赖当前日期、随机数或真实网络，除非通过参数注入时钟/随机源/transport。

## 4. 组件测试：按用户看见和操作的内容断言

组件测试重点：初始状态、输入、事件、禁用、错误、成功/空态与恢复。避免断言 `wrapper.vm.internalFlag` 等实现细节；重构 Composition API 后用户体验没变，测试不应全部破裂。

报修表单的行为清单：

- 缺少设备编号时提交按钮不可提交或显示对应错误；
- 用户输入合法描述后发出规范化 payload；
- 提交中防重复点击；
- 服务端 409 显示冲突与刷新动作；
- 扫码取消保留已填内容；
- 定位拒绝仍允许不附位置提交；
- 页面卸载后旧 Promise 不更新 UI。

跨端组件尽量使用 `view/text/button/input` 等合同，测试通过语义文本、角色/属性、事件与 emit 观察。如果测试必须知道编译后的微信节点名，说明它更接近目标端测试，不应伪装成普通 Vue 单元测试。

## 5. 宿主 Mock：模拟合同，不是模拟愿望

最差的 Mock 永远返回成功：

```ts
globalThis.uni = {
  request: ({ success }) => success({ data: {}, statusCode: 200 })
}
```

它遗漏 fail、非 2xx、返回任务、abort、回调时序、响应字符串和平台差异，容易让错误代码绿灯。更好的方法是注入最小端口：

```ts
type RequestTransport = (request: RequestInput) => {
  response: Promise<HostResponse>
  abort(): void
}
```

测试假 transport 可以脚本化：立即 200、延迟 401、传输超时、先后两次响应、取消后仍模拟服务端完成。真实 uni 适配器另有合同测试，确认它把宿主回调转换成此端口。

### 5.1 Mock 现实差距

Mock 与宿主不一致的信号：

- Mock 返回 JSON 对象，真实上传返回字符串；
- Mock 的 `statusCode` 总是数字，某目标工具暴露其他形态；
- Mock 的 fail 只表示网络，真实宿主把用户取消也放入 fail；
- Mock 的 abort 保证 Promise 永不完成，真实服务端可能已处理；
- Mock 忽略域名白名单、基础库和权限。

每发现一次真实差异，应先更新适配器合同测试和最小 fixture，再修业务代码。不要直接给 Mock 加“特殊 if”只为让当前测试绿。

## 6. 异步测试：控制时间与完成顺序

异步测试最常见假绿是没有 `await`：测试函数提前结束，断言从未执行。所有 Promise 必须返回/等待；期望拒绝要用框架提供的 async 断言；定时器需要 fake timer 或注入 scheduler。

### 6.1 可控 Promise

```ts
function deferred<T>() {
  let resolve!: (value: T) => void
  let reject!: (reason: unknown) => void
  const promise = new Promise<T>((res, rej) => { resolve = res; reject = rej })
  return { promise, resolve, reject }
}
```

先触发 A，再触发 B，先完成 B，最后完成 A。断言 B 仍在页面。不要用 `setTimeout(100)` “等网络完成”，它会让用例慢且不稳定。

### 6.2 刷新队列

Vue 状态变更、Promise microtask 和 DOM 更新不是同一时刻。组件测试需要按照框架约定等待事件和下一次渲染，而不是连续读取旧 DOM。等待目标条件比固定 sleep 更可靠，例如等待“提交中”消失且结果文本出现，并设置合理总超时。

### 6.3 取消测试的真实语义

断言调用过 `abort`，并断言旧 operation id 的结果不会覆盖 UI。不要断言“服务器一定未处理”，那不是客户端能证明的。对写请求还要通过幂等和查询确认测试服务端语义。

## 7. 目标平台自动化处在哪一层

uni-app 官方自动化测试文档说明，相关工具能控制应用、跳转页面、查询元素、触发事件与截图，并列出 H5、微信小程序及部分 App 环境支持；`program` 等对象由自动化环境注入。具体依赖、Jest 版本、平台配置和真机 remote 能力属于易变表面，必须按当前官方文档配置，不能把旧教程命令永久复制。

目标自动化适合验证：

- 构建产物能被目标宿主加载；
- 页面路由与组件在目标树中存在；
- 平台事件代理能触发业务；
- 关键文本/状态/截图与预期一致；
- 小程序网络请求在工具环境出现。

它仍不能自动证明所有真实权限、摄像头质量、ROM、弱网、系统设置和审核环境。官方自动化本身可能运行在开发者工具或模拟器；报告必须写清运行载体。

## 8. 开发者工具与真机差距

常见差距包括：

- 工具可关闭合法域名校验，真机不能据此推断；
- CPU、内存、存储和网络条件不同；
- 权限初态、系统设置和硬件不存在/被模拟；
- 基础库、宿主版本和预发布配置不同；
- 文件临时路径、相机、扫码和定位行为不同；
- 工具 console 与真机远程日志内容/时序不同；
- release 优化、分包和资源加载可能不同。

因此“模拟器通过”是一个层级的证据，不是结论。若 bug 只在真机出现，先保存环境和最小动作，再缩小：同产物换设备、同设备换网络、同网络换基础库/版本、禁用单一能力。一次只改变一个变量。

## 9. 网络调试的证据关联

一个请求至少记录以下脱敏字段：

```text
operationId / traceId
target + appVersion + runtime/baseLibrary
environment
method + pathTemplate（不是完整敏感 URL）
start/end/duration
transport outcome
HTTP status（若存在）
domain error kind
```

客户端网络面板证明“宿主尝试了什么”；服务端 access log 证明“服务器收到了什么”；业务审计证明“授权和状态变更发生了什么”。没有共同 trace/idempotency 标识时，很容易把另一次请求的日志当证据。

诊断顺序：最终 URL/环境 → 宿主 fail → DNS/TLS/白名单 → HTTP 状态 → Content-Type/schema → 认证/授权 → 业务错误。不要把所有失败都归入“后端挂了”。

## 10. source map：把产物位置映回源码

跨端构建会转译 SFC、TypeScript 和平台代码，设备堆栈可能指向 bundle。source map 用映射关系帮助定位原始文件/行列，但它也有边界：

- 构建必须生成与当前产物匹配的 map；
- 上传/符号化服务必须使用同一构建 id；
- source map 可能暴露源码，应受控保存和访问；
- 映射后的行只是起点，仍要结合输入与状态；
- 如果产物被二次压缩或 map 丢失，行号会误导。

复现包记录 `commit + lockfile + build command + artifact checksum + source-map checksum`。只保存一张“报错 1.js:1”截图通常无法复盘。

## 11. 真机最小复现包

一个可交接复现包至少含：

```text
repro/
├── README.md              # 现象、期望、最小步骤
├── environment.json       # 目标、版本、设备、OS、网络
├── fixture.json           # 脱敏输入
├── build.txt              # 命令、commit、lock 摘要
├── logs/                  # 脱敏客户端/服务端关联日志
├── screenshots/           # 必要截图或录屏索引
└── result.md              # 重现次数、对照实验、首个证据
```

README 要让未参与排查的人在合理时间内复现：从什么初态开始、点什么、看到什么、预期什么、发生频率、是否只在特定网络/设备。移除 token、手机号、精确位置、真实附件和完整用户数据。

### 11.1 “最小”不等于随手删除

逐步移除与故障无关的页面、依赖和请求；每次仍重现才继续。若删到故障消失，刚删除的因素就是线索。保留健康对照，例如同设备 H5 正常、小程序异常；或同产物设备 A 失败、设备 B 正常。

## 12. 三种注入故障

### 12.1 Mock 与宿主行为不一致

让 Mock 把上传响应设为对象，而真实 fixture 是 JSON 字符串。业务代码若直接读 `.attachmentId`，单测绿、目标失败。首个证据是适配器输入形状对比。修复应在适配器安全解析和 schema 校验，并让合同测试包含真实脱敏 fixture。

### 12.2 source map 缺失/错配

模拟 crash artifact id 与 map artifact id 不同。验证器应拒绝“已经定位到源码”的结论。修复发布流水线，让两者以不可变 build id 关联，再对原堆栈符号化。

### 12.3 只在模拟器通过

自动化报告只有 `mp-weixin-devtools`，支持声明却写“微信真机通过”。验证器必须报告 `DEVICE_EVIDENCE_MISSING`。修复是执行最小真机矩阵并保存环境/结果，不是把报告文案改成绿色。

## 13. AI/Vibe coding 的测试纪律

让 AI 写测试时，先提供风险和合同，不要只说“提高覆盖率”。接受前检查：

1. 用例能在故障实现上变红吗？
2. 是否只断言自己刚写的 Mock？
3. 是否遗漏 await、取消和乱序？
4. 是否断言实现细节而非用户行为？
5. fixture 是否来自真实合同并已脱敏？
6. 是否把开发者工具叫作真机？
7. 是否声称未执行的平台已通过？
8. 失败日志能否指出目标、阶段和第一证据？

AI 可以生成矩阵、假对象和复现脚本，但不能凭文字补出真机证据。未执行就是未验证。

## 14. FactoryCare 测试分层

| 风险 | 首选测试 | 追加证据 |
|---|---|---|
| 设备编号格式 | 纯函数 | 服务端 schema |
| 权限状态转移 | 纯 reducer + Mock | 真机首次/拒绝/设置恢复 |
| 表单错误和防重复 | 组件 | H5/微信目标自动化 |
| HTTP 错误映射 | 假 transport | 集成服务日志 |
| 旧响应覆盖 | 可控 Promise | 弱网目标端 |
| 上传字符串响应 | 适配器合同 fixture | 真机上传域名/TLS |
| 扫码取消 | 适配器 + 组件 | 真实相机/返回 |
| 创建工单幂等 | 服务集成 | 客户端超时重试旅程 |

每个发布门禁注明证据层级。单元 100% 通过不能替代 G5 的目标设备关键旅程；真机一次成功也不能替代可重复回归。

## 15. 120 秒复述模板

uni-app 测试按风险分层：纯函数验证校验和状态机，组件测试验证用户可见行为，平台适配器用脚本化 Mock 验证成功/失败/取消和时序，目标自动化验证编译产物与宿主交互，真机验证权限、硬件、网络和性能差异。Mock 必须来自真实合同，不能永远成功。异步用可控 Promise 和 operation id 验证乱序/取消。调试先写目标、版本和环境，再关联客户端网络、服务端日志与 source map。模拟器通过不能推出真机通过；设备故障要交付脱敏的最小复现包。

越界反例：“我在开发者工具里跑了一个总是 200 的 Mock，所以微信真机网络、权限和上传已经全部通过。”它混淆三个证据层，也没有失败判据。

## 16. 速查表

| 现象 | 首个可信证据 | 不足证据 |
|---|---|---|
| 单测偶发 | 未等待 Promise/共享状态/时间源 | 多跑几次后变绿 |
| Mock 绿、目标红 | 真实宿主 fixture 与适配器输入 | 猜基础库 bug |
| 旧数据覆盖 | 两次 operation id 与完成顺序 | 固定 sleep |
| 真机请求失败 | 最终 URL、宿主 fail、TLS/白名单 | 工具关闭校验后成功 |
| bundle:1 崩溃 | 同 build id 的 artifact/map | 其他版本 source map |
| 只有模拟器证据 | 测试载体元数据 | 报告标题写“微信通过” |
| 无法交接 bug | 最小复现包 | 聊天记录和一张截图 |

## 17. 从零组织一套可维护测试

初学时不要先把所有页面挂到昂贵的目标自动化。按依赖方向建立目录：

```text
src/
├── domain/
│   ├── repair-validation.ts
│   └── repair-validation.test.ts
├── platform/
│   ├── request-port.ts
│   ├── uni-request-adapter.ts
│   └── uni-request-adapter.contract.test.ts
├── components/
│   ├── RepairForm.vue
│   └── RepairForm.component.test.ts
└── pages/reporter/
    ├── create.vue
    └── create.target.test.js
test-fixtures/
├── http/
├── permissions/
└── uploads/
```

第一轮先让纯函数测试跑通；第二轮让组件使用假端口；第三轮给真实 uni 适配器加合同 fixture；第四轮只为关键旅程写目标自动化；发布候选补真机矩阵。这样失败时可以从最低层快速定位，也避免同一规则在四处重复断言。

### 17.1 测试命名写明条件和结果

推荐命名：`when quantity is zero, total remains zero`、`given an expired credential, maps 401 to unauthenticated`。中文也可以，关键是包含情境和可观察结果。避免 `test1`、`works`、`should handle error`。失败输出应让未打开源码的人知道哪个合同破裂。

每个用例保持独立：在 `beforeEach` 重建状态，不依赖前一个用例先登录；fixture 不被用例原地修改；时间/随机数由依赖注入；测试后恢复全局替换。测试顺序打乱仍应一致。

### 17.2 fixture 的来源与治理

fixture 可以来自：手写最小边界、API schema 生成、真实失败脱敏快照。每个真实快照记录来源日期、目标/版本和脱敏规则；禁止 token、手机号、精确位置、用户描述原文、真实文件路径。schema 改变时 fixture 和合同测试一起变化，不能让“旧 Mock”继续定义不存在的后端。

不要保存巨大完整响应来断言一个字段。裁剪为最小仍能重现的输入，既容易审查，也减少敏感数据和无关漂移。

## 18. 一套可重复的调试协议

遇到失败时按固定顺序，避免 AI 或开发者一次修改多个猜测。

### 18.1 固定现象

写一句可证伪描述：

> 在 build `abc123`、微信基础库 X、设备 Y、生产-like 测试环境中，首次拒绝定位后返回页面，再点“提交”，页面无限显示 loading；10 次复现 10 次。H5 同输入不复现。

它比“定位有问题”包含更多定位变量。接着记录期望、实际、最小步骤和最后一次正常版本。

### 18.2 判断失败阶段

```text
源码/类型检查
  ↓
目标编译与产物
  ↓
宿主加载与页面生命周期
  ↓
用户事件与设备适配器
  ↓
网络传输 / HTTP / schema
  ↓
认证授权 / 业务状态
  ↓
UI 映射与旧结果保护
```

找最早偏离预期的位置。例如按钮事件根本没产生，就不要先查数据库；请求未离开宿主，就不要先改 Spring；服务端 200 且 schema 正确，UI 仍旧，才检查异步状态和组件映射。

### 18.3 收集最小证据

每层只收必要字段，使用同一 trace/operation id 串联。对照健康运行：相同输入在哪里第一次不同？如果源映射缺失，先恢复 build artifact 关联；如果环境不一致，先统一环境再比较。

### 18.4 提出单一假设

写成：“若旧 operation id 未被过滤，则让第二次请求先完成、第一次后完成会复现旧值覆盖。”然后用可控 Promise 验证。假设不成立就撤回实验修改，不把无效防御代码留在项目。

### 18.5 最小修复与原验证

修复后依次运行：最小红灯用例、相邻层测试、原目标复现、相关回归。保存修复前后相同命令。最后写残余风险，例如只在一台 Android 真机测过、iOS 尚未覆盖。

## 19. 如何阅读测试失败而不是只看红色

先定位失败类型：

- **编译失败**：测试根本未执行，先看首个语法/类型/模块错误；
- **setup 失败**：环境、依赖、端口或 fixture 无法建立；
- **assertion failure**：测试已运行，比较 expected 与 actual 及调用栈；
- **timeout**：可能没有 await、事件未发生、Mock 未 resolve、目标工具卡住；
- **unhandled rejection**：异步错误没有被测试/业务接住；
- **进程退出/崩溃**：查看目标日志、内存与原生/运行时堆栈；
- **flaky**：记录随机种子、顺序、时钟、并发和共享资源。

expected 是规格，不一定永远正确；actual 是本次观察，也不代表业务应改成它。先回到需求与合同判断谁错。不能为了绿灯把 `expected: 5997` 改成错误实现的 `2002`。

### 19.1 超时的逐层排查

确认测试是否进入目标步骤；Mock 是否注册在调用前；Promise 是否被 resolve/reject；fake timer 是否推进；Vue 更新是否等待；网络是否被意外真实调用；目标工具页面是否切到正确路径；总超时是否合理。不要直接把 5 秒改成 60 秒掩盖死等待。

### 19.2 日志不是断言

console 出现“success”不等于测试验证了结果。自动化应读取可观察状态并断言；日志用于诊断。当日志本身成为合同（如审计事件），也要结构化验证字段和脱敏，而不是肉眼浏览。

## 20. 事实来源与未验证范围

本章易变事实于 2026-07-24 对照 DCloud 官方 uni-app(x) 自动化测试快速开始、测试 API、CLI 项目与 HBuilderX CLI 页面。官方资料描述了 `program`/页面/元素控制、测试文件和多个目标配置；依赖版本和支持矩阵会变化，应以目标项目当前官方文档为准。Vitest 仅作为纯函数/普通 Vue 层的可选工具表面，不把它冒充 DCloud 目标自动化。

直接来源：

- DCloud，[uni-app(x) 自动化测试快速开始](https://uniapp.dcloud.net.cn/worktile/auto/quick-start.html)：测试能力、平台矩阵、工程结构与用例约定。
- DCloud，[Uni 测试框架 API](https://uniapp.dcloud.net.cn/worktile/auto/api.html)：`program`、页面、元素、截图与 Mock 表面。
- DCloud，[CLI 项目运行自动化测试](https://uniapp.dcloud.net.cn/worktile/auto/uniapp-cli-project.html)：CLI 工程依赖、配置与运行入口。
- DCloud，[使用 HBuilderX CLI 运行自动化测试](https://uniapp.dcloud.net.cn/worktile/auto/hbuilderx-cli-uniapp-test.html)：命令行目标与插件依赖边界。

当前未验证：真实 Vitest/Vue Test Utils、DCloud 自动化插件、微信开发者工具 CLI、remote 真机、网络面板、source map 符号化、H5 浏览器、相机/定位/上传和 FactoryCare 服务。配套资产只验证证据模型。
