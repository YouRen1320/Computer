---
schema_version: 2
edition: 2026.2-draft
id: ch.uniapp.toolchain-pages
title: uni-app 工具链、页面、路由与项目结构
responsibility: 从空目录建立可编译到小程序的 uni-app 项目，解释页面清单、路由、入口和构建产物，不在本章教授组件差异或条件编译。
volume: '10'
order: 2
level: L2
status: drafting
path: book/volume-10-uniapp-miniprogram/chapters/ch.uniapp.toolchain-pages.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.miniapp.runtime
- ch.vue.vite-sfc
version_surfaces:
- uni-app-cli-vue3
- uni-app-mp-weixin-compiler
- wechat-miniprogram-base-library
- wechat-developer-tools
- vue-3
- vite
- node-24-lts
- pnpm
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“uni-app 工具链、页面、路由与项目结构”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - uniapp-toolchain-project
  - uniapp-pages-routing
  covers_topics:
  - uniapp.project-entry
  - uniapp.manifest-config
  - uniapp.pages-config
  - uniapp.build-target
  - uniapp.page-component
  - uniapp.navigation-api
  - uniapp.route-parameter
  - uniapp.page-stack
  uses_capabilities:
  - mobile.miniprogram-runtime
  - foundation.toolchain-env-build
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 从空目录建立含列表和详情路由的 uni-app 小程序并保存构建与导航证据；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - uniapp-toolchain-project
  - uniapp-pages-routing
  covers_topics:
  - uniapp.project-entry
  - uniapp.manifest-config
  - uniapp.pages-config
  - uniapp.build-target
  - uniapp.page-component
  - uniapp.navigation-api
  - uniapp.route-parameter
  - uniapp.page-stack
  uses_capabilities:
  - mobile.miniprogram-runtime
  - foundation.toolchain-env-build
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: target-build-emulator-smoke-route-matrix
- id: diagnose
  kind: fault-diagnosis
  text: 面对“pages 配置、入口路径或目标平台设置错误造成的编译和白屏”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - uniapp-toolchain-project
  - uniapp-pages-routing
  covers_topics:
  - uniapp.project-entry
  - uniapp.manifest-config
  - uniapp.pages-config
  - uniapp.build-target
  - uniapp.page-component
  - uniapp.navigation-api
  - uniapp.route-parameter
  - uniapp.page-stack
  uses_capabilities:
  - mobile.miniprogram-runtime
  - foundation.toolchain-env-build
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# uni-app 工具链、页面、路由与项目结构

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《小程序运行模型、配置、生命周期与宿主边界》](ch.miniapp.runtime.md)：uni-app 产物仍运行在小程序宿主中，配置和页面生命周期必须与宿主模型对照。
- [《Vite、Vue 应用、SFC 与项目结构》](../../volume-09-vue-nuxt/chapters/ch.vue.vite-sfc.md)：uni-app 页面使用 Vue SFC 和前端构建链，需先能定位入口、依赖和编译错误。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套资产使用 Node.js 离线检查项目清单、Vue SFC 文件、目标脚本、模拟构建产物和页面栈矩阵；当前没有安装或执行 DCloud 编译器、微信开发者工具，也没有真机运行。因此，离线绿灯不等于 `pnpm build:mp-weixin`、开发者工具导入、页面渲染或目标基础库兼容已经通过。

uni-app 的价值不是把平台差异变没，而是让开发者用一套 Vue 风格源码和统一 API 生成不同目标的工件。源码由工具链处理，生成的微信小程序仍受上一章的微信宿主、配置、页面栈和生命周期约束。能写一个 `.vue` 文件只是起点；就业项目更需要你解释入口在哪里、哪些配置控制页面、构建目标是什么、产物去了哪里，以及白屏到底发生在哪一层。

## 1. 完成定义、配套入口与本章边界

完成本章后，你应能：

1. 从空目录识别并建立 Vue 3 + Vite 形态的 uni-app 项目；
2. 解释 `package.json`、lockfile、`src/main.ts`、`App.vue`、`manifest.json`、`pages.json` 和页面 SFC 的职责；
3. 区分源码、依赖、开发构建、生产构建和微信目标产物；
4. 用 `pages.json` 解释页面注册、首页、窗口配置与 tabBar，而不是套用 Web Router；
5. 根据 `navigateTo/redirectTo/navigateBack/switchTab/reLaunch` 预测页面栈；
6. 将路由 query 当不可信字符串，完成编码、解析、校验和服务端授权边界；
7. 按“环境—依赖—配置—编译—产物—宿主—页面业务”定位首个可信错误；
8. 保存开发与生产构建、直接进入、参数导航、返回和失败输入的证据矩阵。

配套入口：

- [列表—详情项目结构与路由矩阵示例](../../../examples/encyclopedia/ch.uniapp.toolchain-pages/README.md)
- [pages、入口与目标设置故障实验](../../../labs/encyclopedia/ch.uniapp.toolchain-pages/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.uniapp.toolchain-pages/README.md)

本章不系统教授 uni-app 组件差异、条件编译、网络认证、设备权限、分包、离线队列和发布审核；它们都有后续专章。这里也不把 HBuilderX 与 CLI 争论成唯一正确方案，而是建立可复现的项目合同。

## 2. 先建立“源码到目标宿主”的管线

把一次微信小程序构建画成：

```text
开发者源码
  ├─ Vue SFC / TypeScript
  ├─ pages.json / manifest.json
  └─ 静态资源
        ↓ Node + pnpm 解析依赖
   Vite 与 DCloud 编译插件
        ↓ 选择 mp-weixin 目标
   微信小程序目标产物
        ↓ 导入开发者工具
   微信基础库与客户端宿主
        ↓
   页面栈、生命周期、组件和平台 API
```

每个箭头都可能失败，而且证据不同。Node 找错版本是环境问题；lockfile 漂移是依赖问题；`pages.json` 路径错是配置问题；编译器不支持某语法是编译问题；产物不存在是构建问题；开发者工具基础库不同是宿主问题；接口返回 403 是业务/授权问题。把所有失败统称“uni-app 有 bug”无法调试。

### 2.1 三个不能混淆的版本集合

- **开发工具链**：Node、pnpm、Vite、DCloud 编译依赖和项目模板；
- **目标平台**：微信开发者工具、调试基础库、客户端和设备系统；
- **应用合同**：源码、lockfile、构建命令、`pages.json`、`manifest.json`、后端 API。

本路线在 2026.2 edition 使用 Node 24 LTS 与 pnpm 11 基线，但 uni-app 官方 CLI 页面展示的兼容说明可能滞后或只列部分 Node 大版本。因此不能仅凭“Node 24 是 LTS”推断当前 DCloud 编译器一定兼容；必须用锁定项目执行安装和两个目标构建。版本注册表把 uni-app 标为 provisional，正是为了保留这个证据边界。

## 3. 从空目录开始：模板不是不可解释的魔法

官方 CLI 文档目前仍提供 Vue 3/Vite 模板，例如：

```bash
npx degit dcloudio/uni-preset-vue#vite-ts factorycare-reporter
cd factorycare-reporter
pnpm install
pnpm dev:mp-weixin
pnpm build:mp-weixin
```

这组命令是理解入口，不是长期可复现方案。`npx` 和远程分支会随时间变化；正式项目应把模板结果纳入自己的 Git，审查 `package.json`，通过 `packageManager`、Node 版本文件和 lockfile 固定实际版本，然后在 CI 使用冻结安装。

```json
{
  "name": "factorycare-reporter",
  "private": true,
  "type": "module",
  "packageManager": "pnpm@11.0.0",
  "scripts": {
    "dev:mp-weixin": "uni -p mp-weixin",
    "build:mp-weixin": "uni build -p mp-weixin",
    "typecheck": "vue-tsc --noEmit"
  }
}
```

上面的 pnpm patch 只是教材示意，不是 2026-07-17 的“最新版本”声明。真实项目由 lockfile 固定经过验证的 patch。不要在 CI 每次使用 `@latest`，也不要只提交 `package.json` 而忽略 `pnpm-lock.yaml`。

### 3.1 安装前先观察

```bash
type -a node pnpm
node --version
pnpm --version
pnpm config get registry
```

这些输出告诉你实际执行了谁。`packageManager` 不会自动修复一个优先级更高的错误 `PATH`；IDE 内置终端也可能没有重新加载 shell。安装失败先看命令路径、代理/registry、证书和 lockfile，不要立即删除全部缓存。

### 3.2 冻结安装与依赖漂移

日常开发可用 `pnpm install` 更新 lockfile；CI 和复现实验应使用：

```bash
pnpm install --frozen-lockfile
```

如果它失败，说明声明与锁定结果不一致或环境不支持，不应静默改成非冻结安装再宣称可复现。依赖升级应单独提交，包含构建、类型检查和目标平台烟雾证据，便于回滚。

## 4. Vue 3/Vite CLI 项目的核心目录

典型目录：

```text
factorycare-reporter/
├── package.json
├── pnpm-lock.yaml
├── vite.config.ts
├── tsconfig.json
└── src/
    ├── main.ts
    ├── App.vue
    ├── manifest.json
    ├── pages.json
    ├── pages/
    │   ├── index/index.vue
    │   ├── work-orders/list.vue
    │   └── work-orders/detail.vue
    ├── components/
    ├── services/
    └── static/
```

不同模板或版本可能有额外配置，关键是能沿入口解释，而不是背目录。

### 4.1 `main.ts`：应用创建入口

```ts
import { createSSRApp } from 'vue'
import App from './App.vue'

export function createApp() {
  // 入口职责：创建当前目标的根应用；页面注册来自 pages.json，而非这里手写数组。
  const app = createSSRApp(App)
  return { app }
}
```

不要在入口中直接读取页面 query、发工单请求或塞入大量业务单例。入口负责创建和安装应用级依赖；页面和领域逻辑应有可测试所有者。具体模板若生成不同签名，以锁定版本的模板和官方说明为准。

### 4.2 `App.vue`：应用级生命周期和全局样式入口

`App.vue` 表达应用级生命周期与全局样式，不是一个像 Web 根组件那样始终可见的普通页面。页面 UI 放在 `pages` 中。把列表 `<view>` 直接写进 `App.vue` 后期待它成为首页，是典型宿主模型错误。

```vue
<script setup lang="ts">
import { onLaunch, onShow, onHide } from '@dcloudio/uni-app'

// 应用副作用只记录脱敏轨迹；页面数据请求由具体页面负责。
onLaunch(() => console.info('app:onLaunch'))
onShow(() => console.info('app:onShow'))
onHide(() => console.info('app:onHide'))
</script>

<style>
page {
  background: #f7f8fa;
}
</style>
```

### 4.3 `manifest.json`：应用和平台元信息

它承载应用名称、版本、AppID、平台构建设置等。它不同于 `pages.json`：前者回答“应用/目标怎样构建与识别”，后者回答“有哪些页面、窗口和页面路由”。AppID 不是服务端密钥，但也不能随意把生产、测试配置混用。环境切换要有明确配置来源和构建证据。

### 4.4 `pages.json`：页面清单和页面级宿主配置

官方文档将 `pages.json` 定义为页面路由、窗口、原生导航栏和 tabBar 的全局配置。未注册页面不会成为目标页面；`pages` 第一项通常为默认首页，支持平台的 `entryPagePath` 可改变入口语义。

```json
{
  "pages": [
    {
      "path": "pages/index/index",
      "style": { "navigationBarTitleText": "FactoryCare" }
    },
    {
      "path": "pages/work-orders/list",
      "style": { "navigationBarTitleText": "工单" }
    },
    {
      "path": "pages/work-orders/detail",
      "style": { "navigationBarTitleText": "工单详情" }
    }
  ],
  "globalStyle": {
    "navigationBarTextStyle": "black",
    "navigationBarBackgroundColor": "#ffffff"
  }
}
```

路径通常不带 `.vue` 后缀。文件在磁盘存在但未注册，会在编译/路由阶段出现问题；配置存在但文件缺失，同样失败。验证器应双向检查“每条配置有文件、每个预期页面已配置”。

## 5. 开发构建、生产构建和目标产物

开发命令通常监听源码并生成调试产物，便于开发者工具热更新；生产命令做面向发布的构建。两者使用相同目标 `mp-weixin`，但优化、source map、环境变量和输出可能不同。

```bash
pnpm dev:mp-weixin
pnpm build:mp-weixin
```

官方 CLI 文档给出的平台占位命令是 `npm run dev:%PLATFORM%` 与 `npm run build:%PLATFORM%`，微信目标名为 `mp-weixin`。使用 pnpm 时仍调用项目脚本。输出路径随模板/编译器版本可能是 `dist/dev/mp-weixin` 和 `dist/build/mp-weixin`；不要只背路径，要从命令日志和实际目录确认。

### 5.1 什么才算构建证据

至少记录：

```text
node/pnpm 实际路径与版本
package.json + pnpm-lock.yaml 摘要
执行命令与退出码
目标平台 mp-weixin
输出目录和关键 app.json / 页面工件
开发/生产构建是否分别运行
开发者工具导入路径和基础库
真机机型、客户端版本与烟雾结果（若执行）
```

“终端出现绿色文字”不是充分证据。构建退出码为 0 也只证明编译步骤成功，不证明页面路由、后端、权限和真机渲染正确。

## 6. 页面 SFC：文件是页面，因为清单注册了它

页面是 Vue SFC，但它同时接受小程序/uni-app 页面生命周期。一个最小列表页：

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'

const filter = ref('CREATED')

onLoad((query) => {
  // 数据来源：路由 query；它是不可信字符串，只映射允许的筛选值。
  const candidate = String(query?.status ?? 'CREATED')
  filter.value = ['CREATED', 'CLOSED'].includes(candidate) ? candidate : 'CREATED'
})

function openDetail(id: string) {
  // 路由副作用：编码参数，目标页仍需格式校验与服务端授权。
  uni.navigateTo({
    url: `/pages/work-orders/detail?id=${encodeURIComponent(id)}`
  })
}
</script>

<template>
  <view class="page">
    <text>当前筛选：{{ filter }}</text>
    <button type="button" @click="openDetail('WO-1001')">打开示例工单</button>
  </view>
</template>
```

本章不展开组件差异，但必须记住：`view/text/button` 等是跨端组件合同，不是任意 HTML 标签；Vue 模板能编译不等于所有 Web DOM/CSS/API 都可用。

## 7. 路由不是 Vue Router

uni-app 页面路由由框架统一管理并映射目标宿主。通常不直接安装 Vue Router 来管理小程序页面。核心动作：

| 意图 | API | 页面栈模型 | 约束 |
|---|---|---|---|
| 保留当前页打开普通页 | `uni.navigateTo` | push | 目标为已注册非 tabBar 页面 |
| 替换当前页 | `uni.redirectTo` | pop + push | 常用于不允许回退到当前页 |
| 返回 | `uni.navigateBack` | pop N | 深度必须合法 |
| 切换 tab | `uni.switchTab` | 按 tab 规则切换 | 目标必须是 tabBar 页面 |
| 重建入口 | `uni.reLaunch` | 清栈后打开目标 | 可打开应用内目标页 |

`navigateTo` 成功只表示路由被接受，不表示详情数据加载完成。目标必须在 `pages.json` 注册。不要用 `navigateTo` 打开 tabBar 页，也不要把 `switchTab` 用于普通详情页。

### 7.1 路由参数是字符串输入

```ts
import { onLoad } from '@dcloudio/uni-app'

onLoad((query) => {
  const raw = String(query?.id ?? '').trim()
  if (!/^WO-[0-9]{4,20}$/.test(raw)) {
    // 错误边界：停止业务请求，并向用户展示可恢复状态。
    return
  }
  // 即使格式合法，服务端仍按会话、租户和权限重新授权。
})
```

URL 编码防止参数分隔符破坏结构，但不等于安全校验。`decodeURIComponent` 也可能面对非法编码并抛错。复杂对象不要塞进 query；传稳定 ID，再从可信数据源获取。把 `role=ADMIN` 放在 query 中只能当输入，不能变成权限。

### 7.2 页面栈矩阵

假设 `I` 首页、`L` 列表、`D` 详情：

```text
直接启动首页              [I]
I navigateTo L            [I,L]
L navigateTo D            [I,L,D]
D navigateBack            [I,L]
L redirectTo D            [I,D]
D reLaunch I              [I]
```

验收不只测试按钮点击，还要测试直接进入详情（分享/扫码/调试启动模式）、空参数、非法编码、连续点击和返回。直接进入时不能假定列表页先创建了内存数据。

## 8. 首页、直接进入和页面所有权

`pages` 第一项是常见默认首页，但扫码、分享、平台入口或 `entryPagePath` 可能直接打开其他页面。页面必须能从自己的输入和持久数据恢复，不应依赖“用户一定先经过首页把对象塞到全局”。

FactoryCare 详情页应收到 `id`，显示加载状态，向服务端读取，并处理 400/401/403/404/409/5xx。若无权访问，清晰展示错误并允许返回；不能因全局 store 没有列表对象就白屏。

页面所有权可这样分：

- `pages.json` 拥有页面注册和宿主窗口配置；
- 页面拥有路由参数解析、当前加载/错误/展示状态；
- service 拥有 HTTP 合同和取消/错误映射；
- store 只拥有明确需要跨页共享的客户端状态；
- Spring 服务端拥有授权、工单状态与幂等不变量。

## 9. 白屏诊断：按管线寻找第一证据

### 9.1 环境阶段

症状：命令不存在、执行错 Node、native 模块不兼容。证据：`type -a`、版本输出、进程命令、安装日志。修复环境后重新安装锁定依赖，不要只重启 IDE。

### 9.2 依赖阶段

症状：冻结安装失败、peer 版本冲突、包未解析。证据：pnpm 首个错误、lockfile diff、registry/代理。不要看到一百行级联错误就只读最后一行。

### 9.3 配置阶段

症状：JSON 解析失败、页面路径不存在、首页或 tabBar 错。证据：`pages.json` 位置与文件树。先验证语法和路径大小写。

### 9.4 编译阶段

症状：SFC/TS 语法错误、导入不存在、目标插件失败。证据：第一个文件:行:列、插件阶段、目标名。修改最早错误后重跑同一命令。

### 9.5 产物阶段

症状：命令成功但导入了旧目录或错误目标。证据：实际输出目录、mtime/摘要、产物 `app.json`、开发者工具项目路径。删除产物不是默认修复；先证明它陈旧。

### 9.6 宿主和页面阶段

症状：目标启动但路由失败或生命周期抛错。证据：开发者工具/真机日志、页面栈、route fail、源码映射。网络 403 不要归为编译失败。

## 10. 三个代表性故障

**错误一：`pages.json` 写 `pages/work-order/detail`，文件为 `pages/work-orders/detail.vue`。** 预计在配置/编译或路由解析阶段失败。第一证据是路径矩阵，不是 CSS。

**错误二：执行 `pnpm build:h5`，却把 H5 目录导入微信开发者工具。** 构建本身可能成功，但目标合同错。第一证据是命令目标和产物格式。

**错误三：列表页能点开详情，分享直接进入详情却白屏。** 说明详情依赖列表页内存或未处理空/非法 query。第一证据是直接进入的生命周期输入和错误堆栈。

修复都要重跑原始失败路径。仅证明“从首页点击现在可以”不能关闭“直接进入白屏”的问题。

## 11. FactoryCare 最小两页切片

第一切片只做工单列表与详情导航：

1. `pages.json` 注册首页、列表、详情；
2. 首页 `navigateTo` 列表；
3. 列表用稳定工单 ID 打开详情；
4. 详情验证 ID，再调用受控 service；
5. 返回后列表保留筛选或按明确策略刷新；
6. 直接进入详情也能给出加载、无权、未找到和错误状态；
7. 开发/生产构建输出目标工件；
8. 微信开发者工具和目标真机分别保存证据。

这不是完整报修端。网络认证、离线幂等、扫码、上传、隐私与发布留在后续章。先建立能解释、能构建、能导航、能失败的薄切片，比一次让 AI 生成整个应用更容易诊断。

## 12. 测试与证据矩阵

| 场景 | 预期 | 自动化/工具证据 | 仍需人工/真机 |
|---|---|---|---|
| pages 注册与文件一致 | 所有路径双向存在 | 静态配置检查 | 开发者工具导入 |
| dev/build 目标 | 均生成 mp-weixin 工件 | 命令退出码和产物检查 | 真机调试包 |
| 首页打开列表 | 栈 `[I,L]` | 路由模型/组件测试 | 实际交互与视觉 |
| 列表打开详情 | ID 编码，栈 `[I,L,D]` | 参数/路由断言 | 宿主返回行为 |
| 直接进入详情 | 不依赖列表内存 | 启动输入测试 | 分享/扫码真机 |
| 非法 ID | 不发业务请求，显示可恢复错误 | 单元断言 | 辅助技术提示 |
| 403/404/5xx | 状态明确，不白屏 | service/UI 测试 | 弱网与客户端差异 |

本章离线资产只覆盖前置的静态配置、模拟构建和路由模型。完整验收必须在依赖可安装环境运行真实 DCloud 构建，并在微信开发者工具与真机复测。

## 13. 安全、性能、无障碍与维护边界

**安全**：manifest、前端环境变量和产物都不能保存服务端密钥。query 不可信，服务端重新鉴权；错误日志脱敏；source map 的发布策略单独评估。

**性能**：开发构建热更新快不代表生产首屏快。记录产物体积、首屏依赖和真机启动；不要在 `main.ts` 同步导入所有业务页面。分包在后续章处理。

**无障碍**：路由后标题、焦点/朗读、加载与错误提示需要目标平台辅助功能验证。模拟页面栈不能证明这些要求。

**维护**：升级模板或编译器时单独看依赖和生成工件 diff；保存旧 lockfile 和可回滚提交；不把生成目录作为手工源码修改。若必须临时修生成产物，应回溯到源码/编译配置，否则下次构建会覆盖。

## 14. 从零动手路径

### 14.1 预测

项目只有 `src/pages/detail.vue`，但 `pages.json` 没有该路径。预测：生产构建、开发者工具路由和后端请求中，哪一步最早可能失败？写出第一证据。

### 14.2 构建

从锁定模板建立项目，创建列表和详情，登记 `pages.json`，运行冻结安装、开发与生产微信目标构建。保存版本、命令、退出码、产物目录和页面矩阵。

### 14.3 故障注入

分别注入：路径大小写错误；把目标改成 H5；详情读取不存在的全局列表对象。每次先写预言，再运行，修复后重跑同一失败场景。

### 14.4 需求变更

新增“从二维码直接打开详情”。不能要求首页先执行；参数必须校验，服务端必须授权。更新页面矩阵与证据，而不是只改按钮。

### 14.5 关闭 AI 复述

限时 120 秒解释：`manifest.json` 与 `pages.json` 差别、`main.ts` 与 `App.vue` 边界、dev/build 与目标产物、五种路由的栈变化，以及为什么离线静态绿灯不是真机验收。

## 15. 快速参考

```text
观察环境： type -a node pnpm && node -v && pnpm -v
冻结安装： pnpm install --frozen-lockfile
开发目标： pnpm dev:mp-weixin
生产目标： pnpm build:mp-weixin
页面注册： src/pages.json -> pages[].path
普通入栈： uni.navigateTo
替换当前： uni.redirectTo
返回出栈： uni.navigateBack
切换 tab： uni.switchTab
清栈重启： uni.reLaunch
```

| 症状 | 先看 | 不要先做 |
|---|---|---|
| 命令找不到 | PATH、版本、package script | 全局安装随机 CLI |
| 冻结安装失败 | lockfile 首错 | 删除 lockfile 后继续 |
| 页面未生成 | pages 路径与目标日志 | 改后端接口 |
| 开发者工具白屏 | 产物路径、宿主日志、source map | 只改 CSS |
| 直接进入失败 | query 与页面独立初始化 | 强制先跳首页 |
| 路由 API fail | 注册、tab 类型、栈和 fail 回调 | 吞掉错误 |

## 16. 复习安排与自检

24 小时后从记忆画源码到微信宿主管线；一周后从空目录重建两页项目并手算路由矩阵；一个月后执行一次依赖升级演练，比较 lockfile、构建产物和回滚。

自检：

1. 为什么 Vue SFC 文件存在仍可能不是可路由页面？
2. 为什么 `build:mp-weixin` 成功不能证明详情接口正常？
3. `App.vue` 为什么不是首页页面？
4. `navigateTo` 与 `redirectTo` 对返回行为有何不同？
5. Node 24 LTS 为什么不自动证明当前 uni-app 编译器兼容？
6. 分享直接进入详情时，哪些全局前置假设会暴露？

## 17. 版本、来源与复核边界

本章于 **2026-07-17** 复核 DCloud 官方 CLI、工程、页面、`pages.json` 与路由文档。官方 CLI 仍给出 Vue 3/Vite 模板和 `dev/build:%PLATFORM%` 形式，微信目标为 `mp-weixin`；页面文档仍要求在 `pages.json` 注册，路由 API 仍区分普通页、tabBar 页、入栈、替换、返回与清栈。文档、模板分支、依赖兼容和输出目录会变化，真实项目必须锁定版本并重跑。

- [uni-app CLI 创建与运行](https://uniapp.dcloud.net.cn/quickstart-cli.html)
- [uni-app 工程简介](https://uniapp.dcloud.net.cn/frame)
- [uni-app 页面](https://uniapp.dcloud.net.cn/tutorial/page.html)
- [pages.json 页面路由配置](https://uniapp.dcloud.net.cn/collocation/pages.html)
- [页面和路由 API](https://uniapp.dcloud.net.cn/api/router.html)
- [微信小程序页面路由](https://developers.weixin.qq.com/miniprogram/dev/framework/app-service/route.html)

稳定原理是依赖锁定、源码/产物分离、页面先注册、路由改变页面栈、参数不可信、宿主证据高于模拟器。易变部分包括模板命令、Node 兼容范围、DCloud 编译器、输出目录、微信基础库和平台审核；使用前重新查官方资料并在目标工具/真机验证。
