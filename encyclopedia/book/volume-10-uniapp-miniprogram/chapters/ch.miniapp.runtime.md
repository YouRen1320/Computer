---
schema_version: 2
edition: 2026.2-draft
id: ch.miniapp.runtime
title: 小程序运行模型、配置、生命周期与宿主边界
responsibility: 解释小程序宿主、逻辑/视图层、全局与页面配置以及应用/页面生命周期，区分平台能力与普通浏览器能力，不引入 uni-app。
volume: '10'
order: 1
level: L1-L2
status: drafting
path: book/volume-10-uniapp-miniprogram/chapters/ch.miniapp.runtime.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.js.object-model
- ch.js.event-loop
version_surfaces:
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
  text: 在 120 秒内解释“小程序运行模型、配置、生命周期与宿主边界”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - miniapp-host-runtime
  - miniapp-config-lifecycle
  covers_topics:
  - miniapp.host-runtime
  - miniapp.logic-view-layer
  - miniapp.sandbox-boundary
  - miniapp.platform-api-boundary
  - miniapp.app-page-config
  - miniapp.app-lifecycle
  - miniapp.page-lifecycle
  - miniapp.navigation-stack
  uses_capabilities:
  - foundation.shell-command-stream
  - web.javascript-objects
  - web.javascript-async-runtime
  - mobile.miniprogram-runtime
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 创建原生最小小程序并记录应用与两个页面的配置和生命周期轨迹；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - miniapp-host-runtime
  - miniapp-config-lifecycle
  covers_topics:
  - miniapp.host-runtime
  - miniapp.logic-view-layer
  - miniapp.sandbox-boundary
  - miniapp.platform-api-boundary
  - miniapp.app-page-config
  - miniapp.app-lifecycle
  - miniapp.page-lifecycle
  - miniapp.navigation-stack
  uses_capabilities:
  - foundation.shell-command-stream
  - web.javascript-objects
  - web.javascript-async-runtime
  - mobile.miniprogram-runtime
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: lifecycle-trace-config-inspection-host-log
- id: diagnose
  kind: fault-diagnosis
  text: 面对“配置路径错误、生命周期归属混淆或把浏览器 API 当宿主 API”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - miniapp-host-runtime
  - miniapp-config-lifecycle
  covers_topics:
  - miniapp.host-runtime
  - miniapp.logic-view-layer
  - miniapp.sandbox-boundary
  - miniapp.platform-api-boundary
  - miniapp.app-page-config
  - miniapp.app-lifecycle
  - miniapp.page-lifecycle
  - miniapp.navigation-stack
  uses_capabilities:
  - foundation.shell-command-stream
  - web.javascript-objects
  - web.javascript-async-runtime
  - mobile.miniprogram-runtime
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 小程序运行模型、配置、生命周期与宿主边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《this、原型、class 与对象模型》](../../volume-08-javascript-typescript/chapters/ch.js.object-model.md)：App/Page 注册、对象字面量、方法与 this.setData 依赖已经验证的 JavaScript 对象模型，不能在宿主章节中作为隐藏语法首次出现。
- [《事件循环、任务、Promise 与 async/await》](../../volume-08-javascript-typescript/chapters/ch.js.event-loop.md)：宿主回调、Promise 与生命周期先后关系依赖已经验证的事件循环和异步模型。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套资产使用 Node.js 编写的受控宿主模拟器，验证目录、配置、页面栈和生命周期轨迹；它没有启动微信开发者工具，也没有在微信客户端真机运行。因此，离线验证通过只证明模型与工件内部一致，不能证明基础库兼容、渲染效果、网络域名、权限弹窗或发布审核已经通过。

小程序不是“把网页缩小后放进微信”。它是由微信客户端提供宿主、基础库、组件、路由和平台 API 的应用。开发者提交的是代码包与配置，宿主决定何时装载、怎样创建页面、哪些能力可调用以及生命周期何时触发。先理解这个运行模型，后面学习 uni-app 时才不会把编译框架、浏览器和微信宿主混成一层。

## 1. 本章完成定义、学习入口与非目标

完成本章后，你应当能够：

1. 用“代码包—客户端宿主—基础库—逻辑层—视图层”解释一个页面如何出现；
2. 说明 `app.json`、页面 `.json`、`app.js`、页面 `.js`、WXML 和 WXSS 各自负责什么；
3. 区分应用生命周期、页面生命周期、组件生命周期和一次普通函数调用；
4. 根据导航动作预测页面栈以及 `onLoad/onShow/onReady/onHide/onUnload` 的变化；
5. 解释为什么 `window`、`document` 和浏览器 DOM 不是小程序逻辑层的通用合同；
6. 使用宿主日志、配置检查、页面栈和生命周期轨迹定位首个可信失败证据；
7. 创建一个原生两页小程序骨架，并给成功、边界和失败场景写出可复核预言；
8. 明确模拟器、开发者工具、基础库与真机验证分别能证明什么。

配套入口：

- [原生两页小程序与宿主轨迹示例](../../../examples/encyclopedia/ch.miniapp.runtime/README.md)
- [配置、生命周期与宿主 API 故障实验](../../../labs/encyclopedia/ch.miniapp.runtime/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.miniapp.runtime/README.md)

本章只讲微信小程序原生运行模型，不引入 uni-app、Vue 组件语法、条件编译、设备权限和发布流程。后续框架只是生成或组织宿主能执行的工件，不能改写这里的基本边界。

## 2. 从“谁在运行代码”开始

桌面浏览器加载网页时，浏览器同时提供 HTML/CSS 解析、DOM、Web API 和 JavaScript 宿主。Node.js 运行 JavaScript 时不提供页面 DOM，却提供文件、进程和网络等 Node API。ECMAScript 语言本身没有规定 `document`、`wx.request` 或 `process`；这些名字由不同宿主提供。

微信小程序也有自己的宿主。可以把它分成五层：

1. **微信客户端**：负责进程、窗口、登录环境、原生能力、路由请求和真机差异；
2. **小程序基础库**：提供 `App`、`Page`、组件系统、数据通信和 `wx.*` API 合同；
3. **开发者代码包**：包含配置、逻辑、视图模板、样式和静态资源；
4. **逻辑层**：执行应用/页面 JavaScript，处理状态、事件和平台 API 回调；
5. **视图层**：根据 WXML/WXSS 与数据渲染界面，将用户事件反馈给逻辑层。

这是一张职责图，不保证所有客户端版本都使用相同底层引擎或线程实现。教材应依赖公开合同：逻辑与视图存在通信边界、页面由宿主路由管理、能力来自基础库和客户端。不要把某一代 iOS/Android 的内部实现当成永远稳定的 API。

### 2.1 “基础库版本”不是“微信版本”

开发者工具可选择调试基础库，真机微信客户端也携带其可用基础库。某个 API 文档写有最低基础库版本，只表示低于该版本不能假定存在；它不表示开发者工具模拟成功就等于所有用户真机成功。项目必须记录：开发者工具版本、调试基础库、客户端版本、设备系统和实际失败日志。

### 2.2 冷启动、热启动和前后台

冷启动意味着宿主需要建立新的小程序运行实例并加载代码；热启动通常意味着已有实例从后台重新显示。准确的回收时机由宿主管理，业务代码不应假定“切到后台五分钟一定还活着”。关键草稿要及时保存，认证与服务端状态要能重新获取，初始化必须允许重新执行。

前后台切换主要体现在应用 `onShow/onHide` 和可见页面的 `onShow/onHide`。它不是浏览器标签页 `visibilitychange` 的同义词，也不是页面一定被销毁。隐藏页面可能仍在页面栈中；真正卸载要看路由动作和 `onUnload`。

## 3. 代码包与四类核心文件

最小原生项目可以这样组织：

```text
miniapp/
├── app.js
├── app.json
├── app.wxss
├── sitemap.json
└── pages/
    ├── index/
    │   ├── index.js
    │   ├── index.json
    │   ├── index.wxml
    │   └── index.wxss
    └── detail/
        ├── detail.js
        ├── detail.json
        ├── detail.wxml
        └── detail.wxss
```

`app.js` 调用 `App({...})` 注册全局唯一应用实例；`app.json` 声明页面路径、全局窗口、tabBar、分包等全局配置；`app.wxss` 提供全局样式。每个页面使用同名四件套：`.js` 注册页面逻辑，`.json` 覆盖页面级配置，`.wxml` 描述结构，`.wxss` 描述页面样式。

这里的 JSON 是配置，不是 JavaScript 对象字面量。不能随意写函数、`undefined`、单引号或尾逗号。看到“配置解析失败”时，先检查 JSON 语法和路径，不要先去改生命周期函数。

### 3.1 页面必须先注册

官方全局配置要求 `app.json` 的 `pages` 列出页面路径；路径不写扩展名。新增页面文件但忘记登记、登记路径与目录大小写不同、只改文件名未改配置，都可能让构建或启动找不到页面。若未设置 `entryPagePath`，`pages` 第一项通常作为默认首页。

```json
{
  "pages": [
    "pages/index/index",
    "pages/detail/detail"
  ],
  "window": {
    "navigationBarTitleText": "FactoryCare"
  },
  "sitemapLocation": "sitemap.json"
}
```

预测：把第二项写成 `pages/details/detail`，但磁盘只有 `pages/detail/detail.js`，失败发生在业务请求之前。第一证据应是开发者工具的配置/路径错误和工件树，而不是后端接口日志。

### 3.2 全局配置与页面配置

`app.json` 的 `window` 是全局默认值；页面自己的 `.json` 可为该页面设置标题、下拉刷新等可覆盖项。页面配置不是任意合并所有字段，有些能力只属于全局配置。排查视觉差异时记录“最终生效页面、全局默认、页面覆盖、基础库/平台支持”，不要只截一张图。

```json
{
  "navigationBarTitleText": "工单详情",
  "enablePullDownRefresh": false
}
```

配置是启动合同的一部分。把环境密钥写进配置包并不能保密，客户端可被分析；真正的服务端凭据必须只留在服务端。客户端配置只放允许公开的 AppID、功能开关或环境标识，并由服务端鉴权兜底。

## 4. 逻辑层与视图层：不是共享一个可随意修改的 DOM

WXML 声明视图，页面 `data` 提供可渲染状态，事件从视图回到逻辑层。逻辑层更新数据后，框架把变化传递给视图层。这个边界解释了三个常见现象：

- 在页面逻辑里不能把 `document.querySelector` 当通用能力；
- 大而频繁的数据同步会增加通信和渲染成本；
- “变量已经改了”不等于“视图合同已经更新”。

原生页面示意：

```js
Page({
  data: {
    status: 'LOADING'
  },

  onLoad(options) {
    // 页面职责：把路由参数转换成可验证的工单查询输入。
    const workOrderId = String(options.id ?? '')
    this.setData({ status: workOrderId ? 'READY' : 'INVALID' })
  }
})
```

```xml
<view aria-role="status">{{status}}</view>
```

不要把整份后端响应、token、无关大数组直接塞进 `data`。先把不可信响应解析为页面真正需要的字段；敏感凭据避免写日志；服务端仍必须校验租户、身份和权限。UI 隐藏按钮不是授权。

## 5. 宿主 API 边界

小程序通过 `wx.*` 使用网络、存储、扫码、位置等能力。一个名字存在不等于当前基础库、客户端、平台、权限状态和业务场景都能成功。稳健调用至少要考虑：

1. API 是否在目标基础库存在；
2. 是否需要用户授权或平台声明；
3. success、fail、complete 的职责；
4. 页面隐藏/卸载后结果是否仍会回来；
5. 重复点击、超时、重试和竞态；
6. 服务器是否独立验证身份、幂等键与数据范围。

```js
function loadWorkOrder(id) {
  // 数据源：FactoryCare 后端；响应仍是不可信输入，页面只消费最小字段。
  return new Promise((resolve, reject) => {
    wx.request({
      url: `https://api.example.invalid/work-orders/${encodeURIComponent(id)}`,
      success: resolve,
      fail: reject
    })
  })
}
```

示例域名使用 `.invalid`，故意不可访问，避免误导成真实服务。真实项目还要配置合法请求域名、TLS、登录态和错误结构。本章不讲网络实现，只用它说明“宿主提供能力、异步结果晚于页面生命周期”这一边界。

### 5.1 为什么 `window` 和 `document` 会失败

它们是浏览器宿主 API，不是 ECMAScript 关键字。小程序逻辑层通常没有浏览器 DOM；即使某个渲染环境内部使用 WebView，也不等于开发者拥有普通网页的完整 `window/document` 合同。正确问题不是“如何强行 polyfill DOM”，而是“需求属于数据、组件查询、平台 API，还是本来就应该放在 Web 页面”。

```js
// 错误反例：把浏览器 DOM 当成小程序宿主合同。
document.querySelector('#submit').disabled = true
```

第一可信证据是运行时的未定义引用及其代码位置。不要因页面没显示就先怀疑 CSS，也不要无条件捕获异常后继续执行。

## 6. App 生命周期：全局实例不等于全局垃圾桶

每个小程序用 `App` 注册应用实例。常见回调包括首次启动时的 `onLaunch`、进入前台的 `onShow`、进入后台的 `onHide`、未处理错误的 `onError`、页面不存在等。应用实例可由 `getApp()` 访问，但全局可访问不代表所有状态都应该放在 `globalData`。

```js
App({
  globalData: {
    sessionState: 'UNKNOWN'
  },

  onLaunch(options) {
    // 重要副作用：只记录脱敏启动来源；不可把 token 或完整 query 打到日志。
    console.info('app:onLaunch', { scene: options?.scene ?? 'unknown' })
  },

  onShow() {
    console.info('app:onShow')
  },

  onHide() {
    console.info('app:onHide')
  }
})
```

`onLaunch` 不是“每个页面第一次出现”都会执行，`onShow` 也不等于重新创建应用。把页面查询、计时器、监听器全部注册到全局且从不清理，会让页面之间互相污染。全局适合进程级协调和少量共享状态；页面数据、表单草稿、请求控制应有明确所有者。

## 7. Page 生命周期：创建、可见、就绪、隐藏、卸载

典型页面回调：

- `onLoad(options)`：页面实例加载，一般接收路由参数；一次页面实例通常只调用一次；
- `onShow()`：页面变为可见，返回上一页时可能再次调用；
- `onReady()`：页面首次渲染完成，可进行依赖渲染完成的动作；
- `onHide()`：页面被其他页面覆盖或切到后台，但实例可能仍在栈中；
- `onUnload()`：页面实例从栈中移除，应清理页面拥有的资源。

生命周期是宿主通知，不是由开发者随便调用的业务函数。不要在 `onShow` 中无条件注册监听器而从不注销，因为它可能重复触发；不要把只需一次的参数解析放到每次显示；不要假定 `onHide` 后一定紧接 `onUnload`。

一个清晰页面可以把副作用的所有权写出来：

```js
Page({
  data: { id: '', status: 'IDLE' },
  requestTask: null,

  onLoad(options) {
    // 路由参数是不可信字符串；先规范化，再决定是否发起请求。
    const id = String(options.id ?? '').trim()
    this.setData({ id, status: id ? 'LOADING' : 'INVALID' })
  },

  onUnload() {
    // 页面只清理自己拥有的请求任务；是否支持 abort 取决于具体宿主 API 返回值。
    this.requestTask?.abort?.()
    this.requestTask = null
  }
})
```

`onUnload` 清理能阻止部分后续副作用，但不是所有平台请求都自动取消。还要在回调中检查页面/请求世代，避免旧结果覆盖新状态；后续网络章节会系统处理。

## 8. 页面栈与五种常见路由动作

把页面栈想成从左到右的数组，右端是当前页。假设首页为 `I`，详情页为 `D`，报修 tab 页为 `R`：

| 动作 | 典型 API | 栈变化 | 生命周期重点 |
|---|---|---|---|
| 打开新页 | `wx.navigateTo` | `[I] → [I,D]` | I 隐藏；D 加载、显示、就绪 |
| 返回 | `wx.navigateBack` | `[I,D] → [I]` | D 卸载；I 再显示 |
| 重定向 | `wx.redirectTo` | `[I,D] → [I,R]` | D 卸载；R 新建 |
| 切 tab | `wx.switchTab` | 由宿主按 tab 规则整理 | 目标必须是 tabBar 页面 |
| 重启路由 | `wx.reLaunch` | 关闭现有页后只留目标 | 旧实例卸载，目标新建 |

路由成功回调表示宿主确认执行，不表示目标页面的业务数据已经加载成功。连续快速发起路由还可能受宿主节流或失败；按钮应有明确状态，失败回调要保留证据。

### 8.1 手算轨迹

从冷启动首页开始：

```text
app:onLaunch
app:onShow
index:onLoad
index:onShow
index:onReady
```

首页 `navigateTo(detail)`：

```text
index:onHide
detail:onLoad
detail:onShow
detail:onReady
```

详情 `navigateBack()`：

```text
detail:onUnload
index:onShow
```

具体日志可能夹杂框架/渲染信息，甚至某些内部时序受版本影响。验收应只断言公开合同要求的偏序，例如 `detail:onLoad` 必须先于该实例的 `detail:onReady`，而不是把毫秒级完整日志硬编码成永远不变。

## 9. 配置、构建、启动、运行：先分失败阶段

看到“白屏”不能直接归因为生命周期。按阶段收窄：

1. **配置解析**：JSON 是否合法，`pages` 是否存在，路径是否对应文件；
2. **代码装载/编译**：JS/WXML/WXSS 是否可解析，模块是否存在；
3. **应用注册**：是否正确调用 `App`，启动回调是否抛错；
4. **页面注册/路由**：目标是否登记、是否允许该路由类型、页面是否调用 `Page`；
5. **生命周期业务**：回调内参数、平台 API、异步状态是否正确；
6. **视图更新**：WXML 绑定、`setData`、样式和组件是否符合预期；
7. **真机/平台**：基础库、权限、域名、设备和审核限制是否不同。

首个可信证据通常是最早出现且能定位阶段的错误：配置解析位置、找不到页面路径、未定义 API 的堆栈、路由 fail 回调。后续“页面没显示”只是症状。

### 9.1 三类故障的诊断顺序

**配置路径错误**：先对比 `app.json.pages` 与真实文件树，验证 JSON，再看开发者工具配置错误。不要修改后端。

**生命周期归属混淆**：先画 App 与每个 Page 实例，再标注触发者。若把页面 `onLoad` 写进 `App`，宿主不会把它当页面回调；若在 `onShow` 重复订阅，应从重复日志和监听器计数定位。

**把浏览器 API 当宿主 API**：看 `ReferenceError` 与源码位置，确认运行环境。改用小程序组件/平台 API，或重新判断需求是否应属于 Web。

## 10. FactoryCare 中的落点

FactoryCare 报修端至少有首页/设备扫码结果/报修表单/提交结果等页面。此时必须先明确：

- App 层只协调会话状态、全局错误和前后台，不拥有每张表单；
- 页面 `onLoad` 只解析入口参数，不把未经验证的 scene/query 直接当设备权限；
- 页面 `onShow` 可按策略刷新，但要避免每次返回都重复提交；
- `onUnload` 清理页面计时器、监听和可取消任务；
- 页面栈只负责导航，不是持久化仓库；草稿需有版本和恢复策略；
- 服务端根据登录态、租户和设备权限重新授权，不能信任客户端传入的 `assigneeId`；
- 提交工单使用幂等键，不能靠按钮隐藏避免重复创建。

一个扫码 scene 里出现设备 ID，只能作为候选输入。页面先解析格式，服务端再验证该设备是否属于当前租户和用户范围。把 scene 解码成功写成“已授权”是严重越界。

## 11. 安全、隐私、性能与无障碍边界

**安全**：客户端代码和配置不是秘密。不要内置服务端密钥，不把 token/手机号/完整设备序列号写进普通日志。所有关键授权、状态迁移和价格/权限规则必须在服务端执行。

**隐私**：平台 API 可用不代表可以未经说明调用。位置、相册、摄像头等能力需遵循当前平台声明、最小必要和用户授权；拒绝权限是正常业务分支，不是“让用户重装”。

**性能**：减少首屏不必要代码和大对象数据同步，避免在重复 `onShow` 中创建永久计时器，避免一次 `setData` 发送无关大树。性能结论要有真机数据，开发者工具趋势只能帮助定位。

**无障碍**：原生组件、焦点、文本语义和点击目标需要在真机及目标辅助功能下验证。本章离线模拟器不渲染界面，因此不能声称屏幕阅读器、动态提示或键盘/开关控制已经合格。

## 12. 可复现实验与证据包

一次有效实验至少保存：

```text
输入：app.json、页面文件、导航动作序列、基础库/工具/设备信息
预言：页面栈和关键生命周期偏序
命令：验证器或开发者工具复现步骤
成功：配置、启动、前后台、导航轨迹
边界：空参数、重复显示、返回首页
失败：错误路径、错误生命周期位置、浏览器 API
证据：首个错误、修复 diff、同一验证重跑结果
残余风险：开发者工具与真机、基础库与权限差异
```

只保存最后绿色截图不够，因为别人无法知道输入和失败是怎样被修复的。也不能把模拟器输出冒充微信客户端日志。

## 13. 从零练习路径

### 13.1 预测

不运行代码，回答：当前栈 `[index, detail]`，执行 `navigateBack` 后，哪个页面触发 `onUnload`，哪个页面再次 `onShow`？若回答“两个页面都重新 onLoad”，请回到页面实例与页面栈模型。

### 13.2 构建

建立两页原生骨架：在 `app.json` 注册首页和详情；首页按钮打开详情并携带 `id`；详情记录 `onLoad/onShow/onReady/onHide/onUnload`。保存配置、文件树和轨迹。

### 13.3 故障注入

依次只注入一个故障：把详情路径写错；把 `onLoad` 放进 `App`；在页面逻辑调用 `document.querySelector`。每次先预测失败阶段，再运行，记录首个可信证据，修复后重跑原验证。

### 13.4 需求变更

让详情页返回首页后刷新列表，但不能重复注册监听器、不能重复提交工单。写出状态所有者、触发条件和清理点，然后再改代码。

### 13.5 关闭 AI 复述

限时 120 秒解释：宿主是谁；逻辑/视图层为何是边界；App 与 Page 生命周期有何不同；页面栈怎样变化；模拟器绿灯为何不能证明真机通过。

## 14. 常见误区速查

| 误区 | 正确模型 | 第一证据 |
|---|---|---|
| 小程序就是普通网页 | 微信宿主 + 基础库 + 代码包 | API/运行环境与文件合同 |
| `onShow` 只调用一次 | 页面每次重新可见都可能调用 | 同一实例重复轨迹 |
| `onHide` 等于销毁 | 页面可能仍在栈中 | 页面栈与是否触发 `onUnload` |
| 文件存在就能路由 | 页面必须配置登记且路由类型正确 | `app.json.pages` 与 route fail |
| `document` 是 JS 自带 | 它是浏览器宿主 API | `ReferenceError` 与运行环境 |
| 工具通过就等于真机通过 | 工具和真机证据范围不同 | 版本/设备/权限矩阵 |
| 隐藏按钮就完成授权 | 服务端必须重新鉴权 | 服务端策略测试和审计 |

## 15. 复习点与自检

24 小时后，不看正文画五层运行图和 `[index] → [index,detail] → [index]` 轨迹；一周后从空目录重建两页骨架；一个月后拿一个真实小程序日志，按失败阶段定位首个证据。

自检问题：

1. 为什么页面隐藏后异步回调仍可能回来？
2. 为什么 `onShow` 中注册监听需要幂等或清理？
3. `app.json` 与页面 `.json` 的职责怎样区分？
4. `wx.navigateTo` 成功是否等于详情接口成功？
5. 为什么 scene 中的设备 ID 不能直接视为已授权？
6. 开发者工具、受控模拟器和真机各能证明什么？

## 16. 版本、来源与复核边界

本章于 **2026-07-17** 复核以下官方页面：微信小程序开发指南、注册小程序、页面生命周期、全局配置与页面路由。官方全局配置仍将 `app.json.pages` 定义为页面路径列表，`App` 文档仍说明全局唯一实例，页面路由仍由客户端和基础库控制。基础库、开发者工具和客户端持续演进，项目必须锁定并记录实际验证组合，不能从本章日期推断未来版本。

- [微信小程序开发指南](https://developers.weixin.qq.com/miniprogram/dev/framework/)
- [注册小程序 App](https://developers.weixin.qq.com/miniprogram/dev/framework/app-service/app.html)
- [页面生命周期](https://developers.weixin.qq.com/miniprogram/dev/framework/app-service/page-life-cycle.html)
- [全局配置 app.json](https://developers.weixin.qq.com/miniprogram/dev/reference/configuration/app.html)
- [页面路由](https://developers.weixin.qq.com/miniprogram/dev/framework/app-service/route.html)

稳定原理是宿主边界、配置先于运行、生命周期由宿主驱动、页面栈决定实例可见与销毁。易变部分是基础库最低版本、可用配置项、底层渲染实现、开发者工具行为和平台审核规则；使用前必须重新查官方文档并在目标真机复测。
