---
schema_version: 2
edition: 2026.2-draft
id: ch.vue.vite-sfc
title: Vite、Vue 应用、SFC 与项目结构
responsibility: 从空目录建立可运行的 Vue 3 + TypeScript + Vite 应用，解释入口、SFC 三段和构建边界，不提前教授指令、响应式或状态库。
volume: '09'
order: 1
level: L1-L2
status: drafting
path: book/volume-09-vue-nuxt/chapters/ch.vue.vite-sfc.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.ts.foundations
- ch.css.cascade
version_surfaces:
- vue-3
- vite
- typescript
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
  text: 在 120 秒内解释“Vite、Vue 应用、SFC 与项目结构”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - vue-vite-entry
  - vue-sfc-structure
  covers_topics:
  - vue.create-app-mount
  - vue.application-entry
  - vite.dev-build-preview
  - vue.project-directory
  - vue.sfc-template-script-style
  - vue.script-setup
  - vue.scoped-style-boundary
  - vue.component-file
  uses_capabilities:
  - foundation.toolchain-env-build
  - web.javascript-language
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 从空目录创建含一个 TypeScript SFC 的 Vue 应用并证明 dev/build/preview 三条链路；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - vue-vite-entry
  - vue-sfc-structure
  covers_topics:
  - vue.create-app-mount
  - vue.application-entry
  - vite.dev-build-preview
  - vue.project-directory
  - vue.sfc-template-script-style
  - vue.script-setup
  - vue.scoped-style-boundary
  - vue.component-file
  uses_capabilities:
  - foundation.toolchain-env-build
  - web.javascript-language
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: pnpm-build-browser-smoke-source-map-navigation
- id: diagnose
  kind: fault-diagnosis
  text: 面对“挂载选择器、ESM 导入或 SFC 区块语法错误导致的启动/构建失败”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - vue-vite-entry
  - vue-sfc-structure
  covers_topics:
  - vue.create-app-mount
  - vue.application-entry
  - vite.dev-build-preview
  - vue.project-directory
  - vue.sfc-template-script-style
  - vue.script-setup
  - vue.scoped-style-boundary
  - vue.component-file
  uses_capabilities:
  - foundation.toolchain-env-build
  - web.javascript-language
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Vite、Vue 应用、SFC 与项目结构

> 本章状态为 **drafting**。正文和配套工件可以用于学习与作者自检，但不能证明学习者已经完成独立构建、故障诊断或限时复述，也不会自动修改 `PROGRESS.md`。

打开一个 Vue 页面，看见的是按钮、标题和卡片；真正让它出现的却是一条从 HTML 入口、ES 模块、Vue 应用实例、根组件到浏览器 DOM 的链。Vite 在开发时提供模块服务器和热更新，在构建时把源码转成可部署工件；Vue 把组件描述变成可更新的界面；单文件组件把一个组件的模板、脚本和样式放进同一个 `.vue` 文件。三者职责相邻，却不是同一个东西。

本章只建立这条最小链路。你会从空目录手写一个 Vue 3 + TypeScript + Vite 应用，读懂 `<template>`、`<script setup lang="ts">`、`<style scoped>` 三段，证明 `dev`、`build`、`preview` 的差别，并真实注入入口与 SFC 故障。模板指令、响应式状态、状态库、路由和组件通信都留给后续章节；这里出现的页面内容保持静态，避免把“应用能启动”和“应用会交互”混成一个问题。

官方资料复核日为 **2026-07-17**。复核时 Vue 3 仍是官方当前主版本；Vue 官方新项目工具是 `create-vue`，其默认构建路线基于 Vite；Vite 官方支持页列出的当前常规补丁线是 `8.1`，同时为 `8.0` 和 `7.3` 回移重要修复。版本会变化，因此正文不把某个补丁号当作永久知识；配套工件的精确版本只是为了可复现。Vite 8 官方要求 Node.js `20.19+` 或 `22.12+`，课程规范的 Node 24 LTS 满足该下限。

## 1. 完成标准：不是“页面亮了”

本章必须留下三类证据：

1. **解释证据**：在 120 秒内画出 `index.html → src/main.ts → App.vue → mount container`，说清 Vite、Vue、SFC 各自职责，并举出一个不由本章解决的反例，例如“跨页面路由权限”应交给路由和认证章节。
2. **构建证据**：从空目录创建 TypeScript SFC 应用，保存 Node/pnpm 版本、依赖锁文件、源码、三条命令、HTTP/页面观察与 `dist/` 清单；第三人能按记录复放。
3. **诊断证据**：分别面对挂载选择器错误、ESM 导入错误或 SFC 区块语法错误，先保存红色结果和第一条可信证据，再做最小修复并重跑原命令；最后写出尚未由该验证覆盖的风险。

配套入口：

- [最小入口观察例](../../../examples/encyclopedia/ch.vue.vite-sfc/README.md)
- [FactoryCare 空目录构建实验](../../../labs/encyclopedia/ch.vue.vite-sfc/README.md)
- [公开红灯练习](../../../exercises/encyclopedia/ch.vue.vite-sfc/README.md)

公开练习故意保留一个可观察故障，必须先得到确定性红灯。私有解析只用于独立尝试后的校准；删掉断言、直接打印 `PASS`、改变预期选择器或只展示截图，都不是修复证据。

## 2. 从浏览器页面反推启动链

先建立一个足够精确、又不依赖内部实现细节的模型：

```text
浏览器请求 /
  └─ Vite 返回并处理 index.html
       └─ <script type="module" src="/src/main.ts">
            └─ ESM 导入 vue 与 ./App.vue
                 └─ createApp(App) 创建应用实例
                      └─ mount('#app') 找到宿主元素
                           └─ 根组件渲染结果进入宿主 DOM
```

每一箭头都是可失败边界。`index.html` 没有模块脚本时，浏览器根本不会请求 `main.ts`；导入路径拼错时，模块图无法继续；`App.vue` 解析失败时，Vue 插件无法把 SFC 转成 JavaScript；选择器找不到元素时，构建可能成功，但运行时无法挂载。这也是为什么“`pnpm build` 成功”等不等于“用户能看到页面”。

反过来，浏览器出现一行静态 HTML 也不证明 Vue 已挂载：它可能只是写在 `index.html` 里。可靠观察至少要让根组件输出一个独特标记，并确认该标记不是入口 HTML 的预填内容。

## 3. 五个最小文件分别负责什么

一个手写的最小项目通常包含：

```text
factorycare-vue-entry/
├── index.html
├── package.json
├── pnpm-lock.yaml
├── tsconfig.json
├── vite.config.ts
└── src/
    ├── main.ts
    └── App.vue
```

这不是唯一合法目录，但每个文件都应有清楚责任：

| 文件 | 责任 | 常见误判 |
| --- | --- | --- |
| `index.html` | Vite 项目的 HTML 源入口与挂载容器 | 误以为它只是构建后复制的模板 |
| `src/main.ts` | 浏览器应用组合根：导入根组件、创建并挂载应用 | 把所有业务逻辑都塞在这里 |
| `src/App.vue` | 当前应用的根组件 | 把它误称为“整个 Vue 运行时” |
| `vite.config.ts` | 构建工具配置并启用 Vue SFC 插件 | 在里面写运行时业务状态 |
| `package.json` | 脚本、模块类型和直接依赖声明 | 把全局安装当作项目依赖 |
| `pnpm-lock.yaml` | 锁定完整解析结果，提高复放一致性 | 手工随意改锁文件或完全不提交 |
| `tsconfig.json` | TypeScript 检查边界与目标 | 以为 Vite 转译就等于完整类型检查 |

大项目会再有 `components/`、`views/`、`features/`、`assets/` 和测试目录，但不要为一个静态根组件预造十层文件夹。目录表达稳定责任，而不是表达“看起来像企业项目”。当 FactoryCare 后续形成工单调度切片时，可以按业务特性拆分；本章只保证入口边界清楚。

## 4. `index.html` 是源码入口

Vite 官方明确把项目根目录的 `index.html` 当作源码和模块图的一部分。最小内容如下：

~~~html
<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>FactoryCare 入口观察</title>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>
~~~

`type="module"` 告诉浏览器按 ES 模块规则加载入口。模块有自己的作用域，静态 `import` 会形成可分析依赖图，且加载时机与传统脚本不同。`/src/main.ts` 开头的 `/` 在 Vite 开发根下解析；若部署到子路径，还需要在构建配置和部署环境里验证 `base`，不能靠把斜杠删来碰运气。

`<div id="app"></div>` 是宿主容器，不是 Vue 组件本身。容器 ID 与 `mount('#app')` 是一份跨文件契约，任一侧改名都要同步。不要在容器内预放“加载成功”文案来掩盖未挂载；若要无 JavaScript 降级信息，应明确写在 `<noscript>`，并单独测试。

## 5. `main.ts` 是应用组合根

最小入口只有三件事：

~~~ts
import { createApp } from 'vue'
import App from './App.vue'

// 应用入口只负责把根组件挂到 index.html 的稳定宿主，不承载工单业务状态。
createApp(App).mount('#app')
~~~

第一行导入 Vue 公共 API；第二行导入根组件；第三行创建应用实例并挂载。Vue 官方 `app.mount()` 接收真实 DOM 元素或 CSS 选择器；选择器只使用第一个匹配元素，而且同一应用实例只能挂载一次。创建应用和挂载是两个动作，所以以后可以在两者之间安装路由、状态库或全局错误处理，但本章不提前引入它们。

入口应当“薄”。如果 `main.ts` 里出现几十个工单过滤规则、直接发请求和大量 DOM 查询，故障会同时跨越应用装配与业务逻辑。理想边界是：入口失败时先检查依赖导入、插件、根组件和挂载；业务失败时去相应特性模块找证据。

## 6. ESM 导入为什么会失败

两类导入看起来相似，解析来源不同：

- `import { createApp } from 'vue'` 是裸模块说明符，由包管理器安装结果和 Vite 解析；
- `import App from './App.vue'` 是相对说明符，从当前文件位置解析。

常见故障包括：把 `./App.vue` 写成 `./app.vue`，在大小写不敏感机器上侥幸通过、到 Linux CI 才失败；忘记相对路径前缀；文件实际在别的目录；导入一个未安装包；把 CommonJS 的 `require` 心智模型硬套到浏览器 ESM。第一证据通常是终端的模块解析错误或浏览器网络/控制台中的失败 URL，而不是最后一行级联报错。

调试时先读**完整说明符**和**发起导入的文件**，再执行 `pwd`、列目录并核对大小写。不要一看到 “Failed to resolve import” 就删缓存或重装全部依赖；路径拼写错误不会被重装修好。

## 7. `.vue` 文件不是浏览器原生格式

浏览器不认识 `.vue` 的三个顶层区块。`@vitejs/plugin-vue` 在 Vite 变换链中调用 Vue SFC 编译能力，把模板编译成渲染函数，把脚本变成组件模块，把样式提取或注入。最小配置：

~~~ts
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Vue 插件把 .vue 文件纳入 Vite 模块图和编译链。
export default defineConfig({
  plugins: [vue()],
})
~~~

若忘记插件，`main.ts` 的普通 TypeScript 仍可能被 Vite 处理，但 `.vue` 导入没有正确变换器。错误阶段在构建工具，不在 Vue 组件运行时。相反，插件配置正确而挂载容器缺失时，编译和打包能通过，失败发生在浏览器运行阶段。能说出这一区别，才算真正理解构建边界。

## 8. SFC 的三段结构

一个典型单文件组件：

~~~vue
<script setup lang="ts">
const productName: string = 'FactoryCare'
</script>

<template>
  <main class="shell">
    <h1>FactoryCare Vue 入口</h1>
    <p>根组件：{{ productName }}</p>
  </main>
</template>

<style scoped>
.shell {
  max-width: 48rem;
  margin-inline: auto;
  padding: 2rem;
}
</style>
~~~

官方 SFC 规范允许一个 `<template>`、一个普通 `<script>`、一个 `<script setup>`，以及多个 `<style>`；实际项目通常保持最简单组合。三段不是按文本顺序“逐行执行”：工具链分别解析它们，再组合成组件模块。把 `template` 写进 `script`、漏闭合标签或在顶层放任意 HTML，都可能在 SFC 解析阶段失败。

这里用到了静态插值只为证明脚本名称能进入模板；插值语法及安全边界在下一章系统教授。现在只需知道：模板负责声明界面结构，脚本提供组件逻辑与名称，样式负责呈现；一个文件共同定义一个组件，而不是定义三个互不相关文件。

## 9. `<script setup lang="ts">` 到底是什么

`lang="ts"` 告诉工具链按 TypeScript 语法处理脚本。`setup` 不是浏览器属性，而是 SFC 的编译期语法糖。顶层声明可直接被同一组件模板使用，不需要手写 `export default { setup() { return ... } }`。官方把它作为 SFC 配合 Composition API 时的推荐语法。

“编译期语法糖”不等于“代码只在构建时执行”。`<script setup>` 的内容会成为组件 `setup()` 的内容；每创建一个组件实例都会执行相应运行时代码。编译期处理的是语法形状与绑定，而运行期仍会执行表达式、创建值并渲染组件。本章只使用常量，不讨论响应式依赖追踪。

TypeScript 的类型也不会自动留在浏览器里。Vite 可以快速转译 TypeScript，但官方文档明确建议需要类型保障时另跑 `tsc --noEmit`；对 `.vue` 模板与 SFC，Vue 官方工具链推荐 `vue-tsc`。所以成熟的 `build` 脚本常把类型检查和 Vite 构建组合起来。仅看到 JavaScript 工件不代表类型检查已经发生。

## 10. `<template>` 的编译边界

SFC 模板在构建步骤中预编译为 JavaScript 渲染函数。默认工具链因此可以使用 Vue 的 runtime-only 构建，浏览器不必携带模板编译器。这带来三个重要结论：

1. 模板语法错通常在开发变换或生产构建阶段被指出；
2. 浏览器最终执行的是编译结果，不是原样解释 `.vue` 文件；
3. 源码定位依赖开发服务器映射和 source map，不能只盯着打包后的压缩行号。

不要把预编译误解成“页面已经完全变成静态 HTML”。普通客户端 Vue 应用仍在浏览器创建和更新 DOM；只是模板到渲染函数的转换提前完成。SSR、SSG 与水合是另一组边界，留到 Nuxt 章节。

## 11. `<style scoped>` 是选择器改写，不是 Shadow DOM

`scoped` 让编译器给当前组件模板元素和 CSS 选择器附加匹配属性，使样式通常只命中该组件。可以把它理解为类似：

```css
.shell[data-v-abc123] { padding: 2rem; }
```

实际属性值由工具生成，不应写死。`scoped` 没有创建 Shadow DOM，也没有取消 CSS 层叠、继承和优先级。继承属性仍可从父元素进入；父组件为布局需要时也可能影响子组件根元素；全局样式仍可能参与竞争。调试颜色或间距时，要在浏览器 computed styles 中看最终获胜声明，而不是说“有 scoped 就绝不会串样式”。

性能上，类选择器通常比在 scoped 环境里大量使用裸元素选择器更清晰；但本章不做没有测量的微优化。先用低特异性类名和稳定组件边界，遇到真实冲突再观察。

## 12. `dev`、`build`、`preview` 是三种不同证据

典型脚本：

~~~json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  }
}
~~~

三者不可互相代替：

| 命令 | 面向对象 | 主要证据 | 不能证明 |
| --- | --- | --- | --- |
| `pnpm dev` | 开发者 | 开发服务器、按需模块变换、HMR、开发诊断 | 生产工件能部署 |
| `pnpm build` | 构建流水线 | 完整模块图可构建、生成 `dist/`、资源引用被处理 | 用户浏览器运行正常、部署路径正确 |
| `pnpm preview` | 本地验收者 | 本地以静态服务器预览刚构建的 `dist/` | 它适合作为生产服务器 |

Vite 官方特别说明 `vite preview` 只用于本地预览生产构建，不是生产服务器。真实部署还涉及缓存头、TLS、压缩、回退路由、CDN、监控与权限。把 `preview` 进程放上生产是一个不应由本章最小方案解决的反例。

## 13. 开发链与生产链为什么可能漂移

开发服务器按需处理当前访问到的模块，并提供 HMR；构建会遍历生产入口图、优化与输出资源。某个懒路径未被手工打开、某个环境变量只在生产模式使用、文件名大小写差异只在 Linux 出现，都可能造成“开发能跑，构建失败”。反方向也存在：构建成功，却因浏览器宿主元素或运行时数据问题白屏。

最低验证矩阵应包括：

- 冷启动开发服务器并请求根页面；
- 观察根组件独特文本确实由运行时渲染；
- 从干净输出执行生产构建并检查工件；
- 用 `preview` 服务刚生成的同一 `dist/`；
- 在浏览器控制台和网络面板确认无关键错误；
- 至少注入一个构建期错误和一个运行期挂载错误。

“热更新曾经成功”不是冷启动证据。旧进程和旧缓存可能掩盖缺失文件，所以验收前应停止服务、清理可再生输出，再按记录重启。

## 14. 可复现不等于“在我电脑上能跑”

从空目录复现至少记录：

```text
日期与时区
操作系统/架构（只记录必要信息）
node --version
pnpm --version
pnpm install 使用的锁文件状态
pnpm dev / build / preview 的完整命令
服务地址与端口
输入源码的提交或哈希
退出码、关键日志和工件清单
```

不要记录 token、私有 registry 密码或完整用户目录。版本记录用于解释差异，不是把机器所有信息贴进报告。若课程规范要求 Node 24 LTS，而当前终端是别的兼容版本，应如实写“本次只在 X 验证”，不能把规范目标冒充实测环境。

锁文件是解析证据，不是绝对可复现保证。包注册表、原生二进制、操作系统、环境变量和外部服务仍可能改变结果。高风险发布还需要受控构建镜像和依赖来源策略，本章只建立本地可复放基线。

## 15. 第一类故障：挂载选择器不匹配

故障输入：

```html
<div id="factorycare"></div>
```

```ts
createApp(App).mount('#app')
```

可能出现的现象是构建成功、HTTP 200，但组件内容没有出现，控制台报告找不到挂载目标。诊断顺序：

1. 确认浏览器请求的是刚启动的服务，而不是旧端口；
2. 打开 Elements，检查实际宿主 ID；
3. 打开 Console，找 Vue 第一条挂载警告；
4. 在 `main.ts` 核对选择器；
5. 只统一这份契约，重跑同一浏览器 smoke；
6. 再确认独特根组件文本出现。

第一可信证据是“选择器与实际 DOM 不同”，不是随后出现的空截图。改成任意都能匹配的 `body` 会扩大挂载范围并可能覆盖不相关节点，不是好修复。

## 16. 第二类故障：ESM 说明符与文件事实不一致

若写成 `import App from './app.vue'` 而文件是 `App.vue`，开发终端或构建日志会指出无法解析。保存错误中的 importer、说明符和位置，再用文件系统事实验证。修复后必须重跑原先失败的命令；只运行另一个更宽松工具不构成闭环。

残余风险包括：本地文件系统大小写不敏感，修复只改变了引用却没有真正改变 Git 记录中的大小写。可靠迁移要检查 `git diff --name-status`，必要时通过明确的中间名完成大小写重命名；但本章不替学习者执行 Git 破坏性操作。

## 17. 第三类故障：SFC 区块语法破坏

典型输入：漏掉 `</template>`、把两个普通 `<script>` 放入同一 SFC、在 `<script setup>` 中写不合法 TypeScript、标签嵌套不闭合。错误可能同时包含插件前缀、生成代码和堆栈。定位原则：

1. 找最早指出源 `.vue` 文件与行列的诊断；
2. 区分 SFC descriptor 解析、模板编译、脚本转译和 CSS 处理阶段；
3. 查看出错行上下文以及前一个未闭合结构；
4. 做最小语法修复；
5. 重跑相同 `pnpm build`；
6. 若错误变了，保留新证据继续，而不是宣称已完成。

解析器常在“终于无法继续”的位置报错，真正遗漏可能在上一段。不要仅凭最后一行号删除合法代码。格式化器和编辑器能辅助，但最终证据是编译器通过且页面 smoke 恢复。

## 18. Source map 与第一条业务帧

开发模式通常能把错误映射回 `.vue` 或 `.ts` 源位置。生产 source map 是否生成由配置决定，并涉及源码泄露与错误平台上传策略；Vite 构建默认不输出公开 source map。调试时记录：运行模式、浏览器 URL、错误消息、第一条指向自有源码的栈帧、相关网络请求和对应源码片段。

不要把 `node_modules` 内最后抛错处自动当成根因。框架只能在消费你的非法输入时报告错误，最可信的起点往往是第一条自有入口或组件位置。同时也不要无证据跳过依赖帧；若复现表明特定插件版本有问题，应保存最小复现和锁版本，再查官方 issue。

## 19. TypeScript、Vite 转译与类型检查

Vite 的首要目标是快速提供与构建模块，TypeScript 转译会移除类型。下面代码即使类型不一致，也可能被转成 JavaScript 后进入进一步构建：

~~~ts
const workOrderCount: number = 'three'
~~~

因此工程脚本可以显式写：

```json
{
  "scripts": {
    "typecheck": "vue-tsc --noEmit",
    "build": "pnpm typecheck && vite build"
  }
}
```

本章工件为减少依赖，只验证其声明的边界；真实 FactoryCare 管理端应把 SFC 类型检查纳入 CI。性能优化不能以删除类型检查为默认方案，可以并行或缓存，但发布门仍需一个确定性类型结果。

## 20. 安全边界从入口就开始

最小入口也有安全责任：

- 不把密钥、数据库密码、长期 token 写进 `main.ts`、`.vue` 或 `VITE_*` 环境变量；发往浏览器的内容都应视为可被用户读取；
- 不通过字符串拼接把不可信内容变成模块路径或脚本标签；
- 依赖必须来自受控来源并保留锁文件，安装日志中的脚本风险要可审查；
- 不把 `dist/` 构建成功等同于通过 XSS、CSP、越权或供应链检查；
- source map 是否公开要基于调试与源码暴露权衡；
- 开发服务器不应无意暴露到不可信网络。

FactoryCare 的租户身份与权限由服务端认证上下文和业务规则决定，Vue 入口绝不能以“隐藏一个按钮”代替授权。客户端构建变量也不是秘密保险箱。

## 21. 无障碍与入口失败体验

一个可启动页面应从语义 HTML 开始：设置正确语言、保留 viewport、根组件使用 `main` 和唯一清晰 `h1`，交互控件以后使用原生 `button`。焦点可见、键盘路径、动态提示和列表语义在后续章节继续深化。

入口白屏对屏幕阅读器和视觉用户都同样糟糕。可以在生产应用建立错误边界、监控和可访问的失败提示，但不要在 `index.html` 填一段永不移除的假成功内容。本章 smoke 至少验证文档标题、语言、根主区域和独特标题；颜色、动画或 hover 不能成为“已挂载”的唯一证据。

## 22. 性能：先认清开发数据与生产数据

Vite 开发启动快不代表生产首屏一定快；生产 bundle 小也不代表交互顺畅。开发 HMR、生产构建、网络传输、Vue 挂载和浏览器渲染是不同阶段。当前章节的合理性能证据只有：命令耗时、构建输出大小与测试环境说明。不要虚构生产 QPS，也不要用一次本机热缓存结果做容量承诺。

项目变大后可分析模块图、代码分割、资源缓存和组件渲染；本章不提前引入动态导入和懒加载。先保持入口薄、依赖明确、生产工件可预览。优化前记录基线，优化后用同一条件重测。

## 23. FactoryCare 最小纵切：只证明“壳能到达”

本章的 FactoryCare 页面只显示产品名、章节目的和一个静态工单壳标记。它不请求真实 `/api/v1/work-orders`，不伪造登录，不实现状态机。这样边界更诚实：

- Vue 管理端未来服务调度员、资产管理员、知识管理员与主管；
- 工单真实字段和状态来自公共 API 合同，而不是入口文件随意发明；
- 租户隔离和权限必须由后端强制，客户端只呈现已授权结果；
- 当前工件只证明 Vue 根组件、SFC 和三条 Vite 链路。

若为了“看起来完整”在静态 SFC 里写一个任意修改 `status` 的按钮，会违反 FactoryCare 明确禁止通用状态修改接口的契约。正确做法是在后续章节通过具体命令端点与授权 UI 建模。

## 24. 从空目录的独立构建路线

不要复制配套成品。开一个新目录，按下列检查点自行构建：

1. 写 `package.json`，声明 ESM、`dev/build/preview` 脚本和精确依赖策略；
2. 写含语言、标题、挂载容器和模块脚本的 `index.html`；
3. 写 `vite.config.ts` 并启用 Vue 插件；
4. 写 `src/main.ts`，只创建与挂载根应用；
5. 写一个含三段的 TypeScript SFC，并给每段清晰责任；
6. 安装后保存锁文件与环境版本；
7. 冷启动开发服务，保存 HTTP 与浏览器证据；
8. 停止开发服务，执行生产构建，保存退出码和工件清单；
9. 预览该构建，确认运行时根标记；
10. 注入一个 SFC 解析错误和一个选择器错误，分别形成红—修—绿证据。

完成条件不是目录与示例相同，而是你能解释每个文件为何存在、删掉它会在哪个阶段失败。

## 25. 故障证据模板

```text
场景：mount selector mismatch
环境：Node __ / pnpm __ / OS __
复现命令：pnpm dev --host 127.0.0.1 --port ____ --strictPort
预期：根组件标题出现
实际：HTTP 200，但根组件标记缺失
第一可信证据：Console 指出 mount target selector returned null
源码事实：index.html id=factorycare；main.ts selector=#app
最小修复：统一为 #app
原验证重跑：同命令、同 URL，标题出现且关键控制台错误为 0
残余风险：未覆盖生产部署子路径与旧浏览器矩阵
```

这个模板迫使你区分“现象”“证据”“解释”。`页面白了` 是现象；控制台错误和 DOM 事实是证据；选择器契约不一致是可检验解释。修复后若换了端口、数据或命令，要说明为什么仍可比较。

## 26. 常见错误心智模型

- **“Vite 就是 Vue。”** Vite 是通用 Web 构建工具，Vue 通过官方插件接入；Vite 也支持其他框架与纯前端项目。
- **“`.vue` 会被浏览器直接运行。”** 它先经过 SFC 编译与模块变换。
- **“`scoped` 等于 Shadow DOM。”** 它主要是编译器选择器改写，标准层叠仍然存在。
- **“build 通过就说明页面正常。”** 挂载选择器和许多运行时问题仍可失败。
- **“preview 是生产服务器。”** 官方明确否定；它只本地预览构建。
- **“Vite 处理 TS 就一定完成类型检查。”** 转译和类型检查是不同门。
- **“入口越聪明越方便。”** 入口应该稳定而薄，业务变化应在清楚模块内。
- **“最新就是写 `latest`。”** 可复现工件需要锁定解析结果，升级要单独验证。

## 27. 120 秒复述脚本

可以按“职责—链路—边界—证据—反例”组织：

> Vite 负责开发模块服务器和生产构建，Vue 负责创建应用与渲染组件，SFC 用 template、script、style 描述一个组件。浏览器从 Vite 作为源码处理的 index.html 加载 main.ts；main.ts 以 ESM 导入 Vue 和 App.vue，createApp 创建实例，再把它挂到与 HTML 一致的宿主选择器。Vue 插件在构建期预编译 SFC，scoped 样式仍遵循 CSS 层叠。dev、build、preview 分别证明开发链、生产工件和本地预览，任何一条都不能单独证明上线正确。我的证据是锁版本、三条命令、工件清单、浏览器根标记，以及入口/SFC 故障的红—修—绿记录。生产认证、路由和服务端授权不应由这个最小入口方案解决。

不要逐字背诵。听者追问 `mount` 选择器错了为什么 build 还能成功时，你应能用“构建期与浏览器运行期边界”回答。

## 28. 自测题

1. 为什么 `index.html` 在 Vite 中不只是一个最终复制模板？
2. `createApp(App)` 与 `.mount('#app')` 分别建立什么？
3. 裸模块导入和相对导入各由什么事实决定？
4. 为什么浏览器不能原生运行 `.vue`？
5. `<script setup>` 是编译期语法糖，为什么其中代码仍可能每实例执行？
6. `scoped` 为什么不能消除继承和层叠？
7. `dev` 成功、`build` 失败时应优先保存什么证据？
8. `build` 成功、页面空白时为什么先看挂载与控制台？
9. 为什么 `vite preview` 不能部署为生产服务器？
10. Vite 的 TS 转译与 `vue-tsc --noEmit` 有何不同？
11. 哪些环境信息有助复现，哪些秘密不应记录？
12. FactoryCare 的授权为何不能由 Vue 隐藏按钮实现？

若只能回答定义，回到实验做故障注入；若能预测阶段、指出第一证据并设计原验证重跑，才达到 L1-L2 的诊断目标。

## 29. 本章边界与后续路线

本章完成了应用入口、SFC 三段、项目最小结构和 Vite 三条链。明确不包含：模板指令系统、表单双向绑定、响应式原理、watch/lifecycle 副作用、Props/事件/Slot 合同、Router、Pinia、服务端状态、权限守卫、组件测试以及 Nuxt SSR/水合。

下一章会在已可运行的 SFC 中教授插值、属性绑定、事件、条件与列表，并用 FactoryCare 工单列表验证空态、筛选、节点身份和 key 警告。到那时如果页面不启动，先用本章链路收窄入口故障；如果入口正常而 DOM 与状态不一致，再进入模板层诊断。

## 30. 官方一手资料

以下页面均于 **2026-07-17** 复核：

- [Vue Tooling：官方 `create-vue`、Vite、SFC 编译与类型检查](https://vuejs.org/guide/scaling-up/tooling)
- [Vue Application API：`createApp` 与 `app.mount`](https://vuejs.org/api/application.html)
- [Vue SFC Syntax Specification](https://vuejs.org/api/sfc-spec.html)
- [Vue `<script setup>` API](https://vuejs.org/api/sfc-script-setup.html)
- [Vue SFC CSS Features](https://vuejs.org/api/sfc-css-features.html)
- [Vue Release Policy](https://vuejs.org/about/releases)
- [Vite Getting Started：入口、脚本与 Node 下限](https://vite.dev/guide/)
- [Vite Build Guide](https://vite.dev/guide/build)
- [Vite CLI：build 与 preview 边界](https://vite.dev/guide/cli)
- [Vite Releases：当前支持线与发布策略](https://vite.dev/releases)

版本页和脚手架输出会变化。升级时重新阅读迁移文档、更新锁文件并复跑 dev/build/preview 与故障矩阵，不要把本章复核日当成永久保证。
