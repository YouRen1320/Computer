---
schema_version: 2
edition: 2026.2-draft
id: ch.js.runtime-esm
title: JavaScript 运行时、Node、pnpm 与 ESM
responsibility: 建立浏览器与 Node 运行时、包管理器、package.json 和 ESM 模块解析的最小运行链，不在本章教授语言控制流。
volume: '08'
order: 1
level: L1
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.js.runtime-esm.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.foundations.dependencies-build-packages
version_surfaces:
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
  text: 在 120 秒内解释“JavaScript 运行时、Node、pnpm 与 ESM”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - js-runtime-hosts
  - js-package-esm
  covers_topics:
  - js.ecmascript-host-boundary
  - js.browser-runtime
  - js.node-runtime
  - js.console-output
  - js.package-json
  - js.pnpm-workflow
  - js.esm-import-export
  - js.module-resolution
  uses_capabilities:
  - foundation.toolchain-env-build
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 从空目录创建可重复安装和运行的 ESM 小项目；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - js-runtime-hosts
  - js-package-esm
  covers_topics:
  - js.ecmascript-host-boundary
  - js.browser-runtime
  - js.node-runtime
  - js.console-output
  - js.package-json
  - js.pnpm-workflow
  - js.esm-import-export
  - js.module-resolution
  uses_capabilities:
  - foundation.toolchain-env-build
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: version-evidence-module-run-exit-code
- id: diagnose
  kind: fault-diagnosis
  text: 面对“Node/pnpm 解析到错误版本、包类型错误或模块路径错误”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - js-runtime-hosts
  - js-package-esm
  covers_topics:
  - js.ecmascript-host-boundary
  - js.browser-runtime
  - js.node-runtime
  - js.console-output
  - js.package-json
  - js.pnpm-workflow
  - js.esm-import-export
  - js.module-resolution
  uses_capabilities:
  - foundation.toolchain-env-build
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# JavaScript 运行时、Node、pnpm 与 ESM

把一个以 `.js` 结尾的文件双击、交给浏览器，或者在终端输入 `node app.js`，得到的结果可能完全不同。原因不是“JavaScript 有好几种语法”，而是同一门语言会被不同宿主装进不同的运行环境。语言规定怎样写模块和表达式；浏览器提供网页、DOM 与网络页面生命周期；Node 提供进程、文件系统和命令行入口；pnpm 管理项目依赖与锁文件；`package.json` 声明项目边界；ESM 则把多个源文件连接成一个可执行的模块图。

本章只建立这条最小运行链。你会从空目录得到两个互相导入的 ESM 模块，保存工具路径、版本、标准输出和退出码，并学会沿着证据定位失败。控制流、函数、对象模型与 TypeScript 都留给后续章节。示例里偶尔出现的 `const` 只当作固定外壳使用；下一章才会系统解释它。

## 学完以后，你应当能交出什么

完成本章后，你应当能够独立交出三类证据：

1. 在 120 秒内说明 ECMAScript、宿主、Node、浏览器、pnpm、`package.json` 和 ESM 各自负责什么，并举出一个边界反例；
2. 从空目录创建包含 `package.json`、锁文件和两个模块的项目，用已钉住的工具链安装、运行，记录实际命令、路径、完整版本、stdout、stderr 与退出码；
3. 分别注入工具版本漂移、包类型错误和模块路径错误，指出流水线最早出现的可信证据，修复后重跑完全相同的验证命令，并写出残余风险。

“屏幕上似乎打印对了”不是完整证据。可验收记录至少要回答：哪个 shell 找到了哪个可执行文件？版本是否符合项目约束？项目清单和锁文件是什么？Node 解析了哪个入口？预期输出是什么？进程是以 `0` 还是非零退出？

## 前置地图：语言不等于运行环境

ECMAScript 规范定义 JavaScript 语言的语法与语义，例如模块中的 `import`/`export` 如何形成依赖、绑定何时可用、源码怎样被解析。规范不会替你的程序创建网页按钮，也不会承诺存在 `process` 或本地文件路径。这些能力由宿主提供。

```text
你的源码
   │
   ├── ECMAScript：模块语法、求值规则、语言值与错误规则
   │
   └── 宿主环境
       ├── 浏览器：window、document、页面事件、Web API、开发者工具
       └── Node：process、node:fs、命令行入口、Node 模块解析器

项目层工具
   ├── package.json：包边界、模块类型、脚本、依赖与工具约束
   ├── pnpm-lock.yaml：已解析依赖图及完整性信息
   └── pnpm：依据清单与锁文件组织安装并执行项目脚本
```

可背诵的一句话是：**ECMAScript 规定语言，宿主提供环境，包管理器准备项目输入，Node 或浏览器真正加载并执行模块。**

### 一个必须会给出的边界反例

“用户点击工单按钮后没有发出 HTTP 请求”不应仅用本章的模块方案解决。ESM 可以组织按钮代码，却不能自动证明 DOM 选择、事件绑定、请求权限、后端接口和业务状态机正确。类似地，“生产数据库写入失败”不是换一个 `import` 写法就能修好的问题。先把问题放回负责它的层，才不会用工具链配置掩盖业务故障。

## 浏览器与 Node：同一语言，不同房间

两种环境都能执行 ECMAScript，也都支持 ESM，但入口、可用 API、权限模型和解析上下文不同。

| 观察维度 | 浏览器模块 | Node 模块 |
| --- | --- | --- |
| 常见入口 | HTML 中的 `<script type="module" src="./app.js">` | `node src/main.mjs` 或包脚本 |
| 相对路径基准 | 当前模块 URL | 当前模块的 `file:` URL |
| 页面能力 | `document`、页面事件、Web Storage 等 | 没有通用 DOM；`document` 通常不存在 |
| 系统能力 | 受浏览器沙箱与权限策略限制 | 可使用 `node:fs`、`process` 等 Node API |
| 裸说明符 | 通常需 import map、打包器或浏览器可解析映射 | 可按 Node 包解析规则查找已安装包 |
| 本地开发 | 应通过本地 HTTP 服务，避免 `file:` 来源限制 | 可直接读取本地模块入口 |
| 诊断工具 | Network、Sources、Console | 终端、`--trace-*` 选项、调试器 |

不要用“我的新版 Node 里有 `fetch`，所以 Node 就等于浏览器”推理。Node 确实提供越来越多 Web 兼容全局对象，但它仍不提供网页文档树与浏览器页面生命周期。也不要把浏览器 Console 里的临时代码当成项目模块：控制台执行上下文、页面模块和 Node 文件是三种不同证据环境。

### `globalThis` 是共同名字，不是共同能力清单

`globalThis` 提供跨环境引用全局对象的标准入口，但它不保证全局对象上有哪些宿主属性。浏览器页面常见 `globalThis.document`；普通 Node 进程通常没有。Node 的 `globalThis.process` 可用，浏览器页面则不应依赖它。判断能力时应查目标宿主的官方文档并在目标环境验证，不能只凭属性名相似。

### Console 输出只是观察口，不是业务协议

`console.log(...)` 是宿主提供的调试输出接口。它适合建立最小预言：给定固定输入，stdout 应精确出现哪些行。它不适合作为跨系统的长期数据协议，因为浏览器开发者工具可能延迟展示对象状态，不同宿主的格式化细节也可能不同。测试本章的字符串输出时，用纯文本预期文件逐字比较；不要依赖颜色、对象展开样式或时间戳。

在 Node 中，普通 `console.log` 通常写向标准输出，语法错误和未捕获异常通常写向标准错误并让进程非零退出。三者要分开保存：

```text
stdout：程序承诺的正常可观察结果
stderr：诊断信息，不能混入正常预言
exit=0：本次进程按约定完成
exit!=0：本次进程失败；数字本身不替代错误正文
```

## 先证明当前 shell 会启动谁

同一台机器可能同时装有系统 Node、版本管理器 Node、IDE 内置 Node 和 CI 镜像 Node。`node --version` 只给版本；`command -v node` 才说明当前 shell 先命中了哪个路径。两条都要记录：

```sh
command -v node
node --version
command -v pnpm
pnpm --version
```

本书的目标版本面是 **Node 24.x LTS 与 pnpm 11.x**。教材核验日为 **2026-07-17**：Node 官方发布页当日把 v24（Krypton）列为 LTS；pnpm 11 官方安装页说明其常规安装要求 Node 至少为 22，并给出 Node 22/24/26 的兼容表。这里的 `24.x` 和 `11.x` 是主线约束，不代表任何一个 patch 永远正确；正式证据还必须记录实际完整版本。

一个环境显示 Node 22 或 pnpm 10 时，不要偷偷把它写成“已经验证 Node 24/pnpm 11”。它可以帮助观察稳定的 ESM 语义，却不能充当目标版本证据。正确做法是把结果标为工具链漂移，切换到项目声明的版本，再重跑同一验证。切换方式取决于团队选择的版本管理器或容器，不属于 ECMAScript 本身。

> 版本事实来源与核验日：Node [Previous Releases](https://nodejs.org/en/about/previous-releases)、Node 24 [ECMAScript modules](https://nodejs.org/download/release/latest-v24.x/docs/api/esm.html)、pnpm 11 [Installation](https://pnpm.io/installation)，均于 2026-07-17 核验。Node 26 当日是 Current，不因数字更大就自动替代生产 LTS 基线。

## `package.json`：项目边界中的声明，不是安装结果

`package.json` 是 JSON 文档。JSON 要求双引号，不允许注释，也不允许末尾多余逗号。下面是本章的最小清单：

```json
{
  "name": "factorycare-esm-smoke",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "packageManager": "pnpm@11.9.0",
  "engines": {
    "node": "24.x"
  },
  "scripts": {
    "start": "node src/main.js",
    "verify": "node src/main.js"
  }
}
```

逐项读它：

- `name` 是包名；内部练习也应使用清晰名字，不能靠目录名猜身份。
- `version` 是这个包自己的版本，不是 Node 版本。
- `private: true` 防止把学习项目意外发布到公共仓库；它不等于安全边界。
- `type: "module"` 明确告诉 Node：这个包边界内的 `.js` 按 ESM 解释。
- `packageManager` 记录预计使用的包管理器及精确版本。它提供约束线索，是否自动执行仍取决于工具链配置。
- `engines.node` 描述期望 Node 范围。不同包管理器和配置对不满足约束的处理强度不同，因此不能把声明当成已切换版本的证据。
- `scripts` 给长命令稳定名字；`pnpm run verify` 最终仍会启动进程并产生 stdout、stderr、退出码。

清单声明“想要什么”，锁文件记录“解析到什么”，安装目录体现“本机准备了什么”。三个问题不要混为一个。只有 `package.json` 而没有锁文件，无法证明间接依赖图固定；只有 `node_modules` 而没有清单与锁文件，无法可靠重建；只有锁文件也不证明本机真的安装成功。

Node 官方建议即使当前文件全是 CommonJS，也明确写出 `type`，避免未来 Node 的语法探测或邻近包边界变化使解释方式模糊。`.mjs` 始终明确表示 ESM，`.cjs` 始终明确表示 CommonJS；它们可用于教学和边界文件，但正常项目应形成一致策略，而不是随故障临时改后缀。

## pnpm：根据清单准备依赖图

pnpm 的职责是读取项目元数据、解析依赖、维护锁文件、组织内容寻址存储与项目链接，并在项目环境里执行脚本。它不是 JavaScript 运行时：`pnpm run start` 会找到脚本，再启动 Node；真正解析 ESM 的仍是 Node。

本章的可重复工作流是：

```sh
# 在目标 Node 24.x 环境中先保存路径与版本。
command -v node
node --version
command -v pnpm
pnpm --version

# 第一次明确解析依赖并提交生成的锁文件。
pnpm install

# CI 或验收从已提交锁文件进行冻结安装。
pnpm install --frozen-lockfile

# 运行清单中稳定命名的验证入口。
pnpm run verify
```

即使项目暂时没有第三方依赖，也保留清单、锁文件与冻结安装步骤有教学价值：它证明空依赖图同样被明确记录，并为后续新增依赖提供可重复边界。不要在练习中使用未经审阅的远程安装管道，也不要为了“看起来最新”每次自动取浮动 latest。pnpm 官方文档展示 Corepack、安装脚本、独立程序等多种方案；团队需要选定一种、固定版本并记录来源。本书不替你的机器擅自修改全局工具链。

pnpm 11 的官方文档还指出该主版本自身以纯 ESM 分发；这是版本面事实，不是让业务项目必须导入 pnpm 内部模块的理由。`packageManager`、Corepack 和团队 CI 镜像如何配合属于工具治理决策。若 Corepack 的签名或缓存失败，应按“工具获取阶段”诊断，而不是修改业务 `import` 来掩盖。

## ESM：先导出，再按说明符连接

假设 `src/status-label.js` 负责提供一个 FactoryCare 展示词条：

```js
// 本模块只提供演示用的稳定代码与标签，不充当后端状态机权威。
export const statusCode = "ASSIGNED";
export const statusLabel = "已指派";
```

入口模块消费这些命名导出：

```js
// 入口显式写出文件扩展名，让 Node 与浏览器共享清楚的相对 URL。
import { statusCode, statusLabel } from "./status-label.js";

// 输出是本实验唯一外部副作用，也是逐字比较的最小预言。
console.log(`status=${statusCode}`);
console.log(`label=${statusLabel}`);
```

在本章只需掌握四件事：

1. `export` 把模块的某个绑定公开给其他模块；没有导出的名字不能被命名导入。
2. `import { statusCode }` 中的名字必须与导出名一致；默认导出与命名导出是两种合同，不能凭感觉混用。
3. `./status-label.js` 是相对模块说明符，`./` 表明从当前模块位置出发；Node ESM 的相对导入要求显式文件扩展名。
4. Node 会先构造并链接模块图，再求值入口。依赖解析失败时，入口里的第一条输出也可能完全不执行。

ESM 导入的是绑定，不是把另一个文件的文本粘贴过来。模块通常只求值一次，同一模块被多个依赖引用时也不会简单地重复执行源码。循环依赖、动态导入和顶层等待会改变更复杂图的时序，留到后续章节；本章只用静态、无环、两节点模块图。

### 路径首先是 URL 问题

Node ESM 以 URL 解析模块并缓存。相对说明符应像 URL 一样写出扩展名；目录不能靠 CommonJS 时代的隐式 `index.js` 猜测。Node 原生支持 `file:`、`node:` 和有限场景下的 `data:`；普通 `https:` 模块并不是默认本地 Node 加载方式。浏览器则天然从页面和模块 URL 出发，还受来源、CORS 和服务器 MIME 类型影响。

这带来几个实用规则：

- 从文件 A 导入相邻文件 B，写 `./b.js`，不要只写 `b`，也不要省略扩展名。
- 导入 Node 内置模块时用清楚的 `node:` 前缀，如 `node:fs`；这种说明符不能直接移植到浏览器。
- 浏览器里的裸说明符如 `import "vue"` 需要 import map 或构建工具映射；Node 会在包依赖范围内按自己的规则解析。
- 文件名大小写应完全一致。大小写不敏感的开发机可能暂时放过错误，Linux CI 会暴露它。
- 不要把绝对的个人磁盘路径写入源码；让相对模块图跟随项目目录移动。

`import.meta.url` 能给出当前模块的绝对 URL，可用于需要定位资源的 Node 或浏览器模块，但它不是“当前工作目录”。Node 的 `process.cwd()` 取决于启动位置，`import.meta.url` 取决于模块位置；二者解决不同问题。初学阶段若只导入相邻源码，保持明确相对说明符即可。

## 从空目录建立最小可复现项目

下面是独立构建任务的目标结构。命令中的目录名可以更换，但结构职责不能混淆：

```text
factorycare-esm-smoke/
├── package.json
├── pnpm-lock.yaml
├── src/
│   ├── main.js
│   └── status-label.js
├── expected.stdout
└── evidence/
    ├── toolchain.txt
    ├── stdout.txt
    ├── stderr.txt
    └── exit-code.txt
```

构建顺序如下：

1. 创建空目录，进入后先记录 `pwd`，避免在错误项目操作。
2. 创建明确含 `type: module`、Node 约束和 pnpm 精确版本的 `package.json`。
3. 写被依赖模块和入口模块，所有相对导入带扩展名。
4. 手写 `expected.stdout`，每个换行都属于预言；先预测，后运行。
5. 在目标 Node/pnpm 环境执行首次 `pnpm install`，审阅并保存 `pnpm-lock.yaml`。
6. 清理可再生安装结果后用 `pnpm install --frozen-lockfile` 证明锁文件可用。
7. 执行稳定验证入口，分别保存 stdout、stderr 和退出码。
8. 用字节级比较工具核对预期与实际；比较成功也要保存命令与退出码。

关键不是复制这八步，而是能解释每一步消除哪种不确定性。工具路径排除 PATH 歧义；精确版本排除主版本漂移；冻结安装排除锁文件被悄悄重写；模块输出排除“只安装未执行”；退出码让自动化知道成功还是失败；预言比较排除“看起来差不多”。

### 一个合格的 T0 记录

本章 canonical 验证级别是 T0：证明工具版本、模块运行和退出码。建议记录为纯文本：

```text
cwd=/workspace/factorycare-esm-smoke
node_path=/toolchains/node-24/bin/node
node_version=v24.x.y
pnpm_path=/toolchains/pnpm
pnpm_version=11.x.y
install_command=pnpm install --frozen-lockfile
run_command=pnpm run verify
stdout_sha256=<实际摘要>
stderr_bytes=0
exit_code=0
```

占位符不能作为最终证据；验收时必须替换为实测值。若 stdout 正确而退出码非零，仍是失败。若退出码为零而工具版本错误，也不满足本章的目标版本验收。若锁文件被安装命令修改，说明冻结边界没有成立，应先解释原因。

## 一条可重复使用的故障定位流水线

调试时按阶段收窄，不要从最后一行盲猜：

```text
0. shell 查找工具
   ↓ command -v、完整版本
1. package.json 读取
   ↓ JSON 语法、最近包边界、type/scripts/约束
2. pnpm 解析与安装
   ↓ 锁文件、registry/缓存、完整性、冻结状态
3. Node 解析入口源码
   ↓ 文件格式、ESM/CommonJS 判定、语法位置
4. ESM 链接模块图
   ↓ 说明符、扩展名、导出名、包解析
5. 模块求值
   ↓ 宿主 API、顶层副作用、未捕获异常
6. 观察结果
   ↓ stdout、stderr、exit code 与预言
```

“首个可信证据”是最早能够反驳期望的原始观察，不是聊天窗口里的猜测。例如 `command -v node` 已指向意外目录且 `node --version` 是 v22，那么版本漂移在阶段 0 已成立；不要先删除锁文件。若版本正确，Node 报 `ERR_MODULE_NOT_FOUND` 并标出缺扩展名的 URL，首个可信证据在阶段 4；不要换 pnpm 镜像。

### 故障一：Node 或 pnpm 版本漂移

现象可能是语法支持差异、锁文件格式变化，也可能暂时“运行正常”。只要实际路径或主版本不符合声明，验收仍失败。

```sh
command -v node
node --version
command -v pnpm
pnpm --version
```

修复动作是按团队既定方式选择 Node 24.x 与钉住的 pnpm 11.x，重新打开或刷新 shell，然后重跑上面四条和原验证命令。残余风险包括：IDE 终端与系统终端 PATH 不同、CI 镜像仍旧、精确 patch 尚未一致。不能只截一张成功输出而省略路径。

### 故障二：包类型错误

在没有 `type: "module"` 的 CommonJS 包边界中，让 `.js` 使用静态 `import`，常会得到“不能在模块外使用 import”一类语法错误。先检查报错文件的扩展名，再从文件目录向上找到最近的 `package.json` 并检查 `type`。不要看到 `import` 就全局重命名所有文件。

主线修复是让项目策略一致：本章项目明确使用 `type: "module"` 和 `.js`，或在孤立边界明确使用 `.mjs`。修复后重跑原命令，确认模块确实执行且预言匹配。残余风险是子目录可能另有 `package.json` 改写包边界，第三方工具配置也可能仍按 CommonJS 生成文件。

### 故障三：模块路径或导出合同错误

`ERR_MODULE_NOT_FOUND` 首先检查错误中显示的父模块 URL 与目标 URL；确认 `./`、大小写、扩展名和文件是否存在。若找到文件却提示“does not provide an export named”，说明解析已通过，失败移动到了链接期的导出合同。检查导入名与导出名，不要用默认导入掩盖命名不一致。

修复只改导致证据失败的最小合同，然后重跑完全相同的命令与预言比较。残余风险包括跨平台大小写、构建产物目录改变以及浏览器服务器没有正确 MIME/CORS 响应。

## 浏览器中的同一模块图怎样验证

浏览器实验需要一个 HTML 入口和本地 HTTP 服务：

```html
<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8">
    <title>FactoryCare ESM smoke</title>
  </head>
  <body>
    <script type="module" src="./src/main.js"></script>
  </body>
</html>
```

模块脚本按模块规则执行并天然采用严格模式；它的顶层绑定不会像传统脚本那样简单成为 `window` 属性。浏览器从 URL 获取依赖，所以应检查 Network 面板中的状态码、最终 URL、响应 MIME 类型和 CORS 错误，再看 Console。直接打开 `file://` 可能引入不透明来源或跨源限制，无法代表真实部署；用受控本地服务器更可靠。

同一份纯计算或纯字符串模块可以同时被浏览器和 Node 消费，前提是它不依赖某一宿主 API，且说明符在两端都可解析。包含 `node:fs` 的模块不能直接交给浏览器；读取 `document` 的页面入口也不能直接交给普通 Node。跨宿主设计的关键不是假装差异不存在，而是把宿主适配放在边缘、把可共享模块放在中间。

浏览器模块集成规则的当前一手来源是 WHATWG [HTML Living Standard：JavaScript module system integration](https://html.spec.whatwg.org/multipage/webappapis.html#integration-with-the-javascript-module-system)，本章于 2026-07-17 核验。浏览器实现和开发者工具界面会变化，验收仍要记录实际浏览器版本与网络证据。

## FactoryCare 中为什么先做这条最小链

FactoryCare 的 Vue/Nuxt 前端、Node 工具脚本和测试工具都会经过包清单、依赖锁定与模块解析。若运行链不可信，后续“状态标签错了”可能只是导入了旧文件，“本机能跑 CI 失败”可能只是 Node/pnpm 不一致，“页面空白”也可能在业务逻辑执行前就已经链接失败。

本章示例使用 `ASSIGNED → 已指派` 只是展示模块边界，不定义 FactoryCare 领域状态机。正式状态集合、允许迁移与权限应由项目契约和 Java 后端权威实现维护；前端标签映射必须消费已约定合同，而不能因为演示文件能运行就自创第十三种状态。这是一个重要边界：**模块可运行证明交付通道畅通，不证明业务语义正确。**

适合放在共享 ESM 模块里的内容包括稳定标签、无宿主副作用的格式化数据和前端公共配置。数据库连接、浏览器 DOM 初始化、日志上传等宿主副作用应放在明确入口附近。这样模块图既能被测试，也能在失败时指出是哪一个边缘适配出问题。

## 常见误解与纠正

### “JavaScript 就是浏览器脚本”

语言与宿主不同。Node 能执行 JavaScript 但没有普通网页 DOM；浏览器能运行模块，却不能任意读取本机文件。证据应注明运行宿主。

### “装了 pnpm，就装了 Node”

pnpm 通常依赖 Node 或使用独立分发方式，但包管理器和运行时仍是两个版本面。分别记录路径与版本。

### “`engines` 会自动帮我切换 Node”

它是项目约束元数据，具体是警告还是拒绝取决于工具和配置。只有实测 `node --version` 能证明当前进程版本。

### “有 `package-lock.json` 也可以叫 pnpm 锁定”

不同包管理器有不同锁文件合同。本章 pnpm 主线使用并提交 `pnpm-lock.yaml`，不要混用其他锁文件后声称同一依赖图已冻结。

### “省略 `.js` 更简洁”

Node ESM 相对导入要求完整扩展名，浏览器 URL 也更清楚。依靠打包器补全是另一套解析合同，不能当成原生 Node 证据。

### “退出码为 0，所以模块一定正确”

退出码只证明进程没有按失败路径退出。仍要比较 stdout 预言、确认版本和输入。程序稳定地打印错误业务标签也可能返回 0。

### “删掉锁文件再安装能修复一切”

这会改变输入并掩盖依赖漂移。先保存失败证据，判断失败阶段；只有明确决定重新解析依赖并审阅差异时才更新锁文件。

## 三层练习路线

本仓库为本章提供四类资产：

- `examples/encyclopedia/ch.js.runtime-esm/`：最小两个 ESM 模块与 stdout 预言，可直接观察绿色基线；
- `labs/encyclopedia/ch.js.runtime-esm/`：包含基线和三个可控故障证据，练习按阶段诊断；
- `exercises/encyclopedia/ch.js.runtime-esm/`：公开红灯练习，要求修复清单、路径与导出合同；
- `solutions-private/encyclopedia/ch.js.runtime-esm/`：私有参考答案，用同一预言验证。

每个目录只有一个 `verify.sh` 入口。公开练习保留稳定失败，防止“没有做也全绿”；私有答案必须稳定通过。资产为了在当前学习机上可局部自检，使用 Node 22 以上都支持的稳定 ESM 子集，并不声称替代 Node 24.x、pnpm 11.x 的正式 T0 工具证据。完整 build outcome 仍要求在目标工具链从空目录执行冻结安装并记录结果。

## 120 秒口述模板

你可以用以下结构自测，不要逐字背诵：

> ECMAScript 规定模块语法和求值规则，浏览器与 Node 是提供不同 API 和入口的宿主。`package.json` 声明包边界、`type`、脚本和版本约束；pnpm 根据清单与锁文件准备依赖并启动项目脚本；Node 最终解析 ESM 模块图。我的证据包括实际工具路径与完整版本、冻结安装结果、两个模块的精确 stdout、空 stderr 和退出码 0。若失败，我依次检查 shell 工具、清单、安装、解析、链接、求值和预言。数据库写入失败不是 ESM 应负责解决的反例。

如果你不能在 120 秒内把“谁声明、谁安装、谁解析、谁执行、证据是什么”说清楚，就回到运行链图，用自己的项目路径重讲一次。

## 独立构建与诊断验收单

### Build：从空目录重建

- [ ] 目录起点和 `pwd` 已保存，没有借用旧 `node_modules`。
- [ ] `package.json` 明确写出 `private`、`type`、Node 约束和精确 pnpm 版本。
- [ ] 两个 ESM 模块职责单一，相对导入带扩展名，导出合同一致。
- [ ] `pnpm-lock.yaml` 来自审阅过的首次解析并已纳入证据。
- [ ] 目标环境的 Node 实际为 24.x LTS，pnpm 实际为钉住的 11.x。
- [ ] 冻结安装没有修改锁文件。
- [ ] 运行前写好 stdout 预言；实际输出逐字相同，stderr 为空，退出码为 0。
- [ ] 记录含命令、输入摘要、路径、完整版本、输出与退出码，不只是一张截图。

### Diagnose：注入、修复、原样复跑

- [ ] 工具漂移：PATH 指向错误版本，能用阶段 0 证据证明并恢复。
- [ ] 包类型错误：能根据文件后缀和最近 `package.json` 定位，而不是乱改语法。
- [ ] 路径错误：能根据父模块 URL、说明符、扩展名、大小写与导出名收窄。
- [ ] 每次先保存失败证据，再做单一修复；修复后运行原验证而不是换一个较宽松命令。
- [ ] 说明残余风险：IDE/CI PATH、跨平台大小写、浏览器 CORS/MIME 或工具 patch 差异。

## 参考边界与时效说明

本章稳定核心是语言/宿主边界、清单/锁文件/安装结果三分法、ESM 显式合同和证据驱动的阶段诊断。版本状态、工具安装渠道和浏览器界面属于易变事实。2026-07-17 核验的一手资料如下：

- [ECMAScript 2026：Scripts and Modules](https://tc39.es/ecma262/2026/multipage/ecmascript-language-scripts-and-modules.html)
- [Node.js Previous Releases](https://nodejs.org/en/about/previous-releases)
- [Node.js v24 ESM documentation](https://nodejs.org/download/release/latest-v24.x/docs/api/esm.html)
- [Node.js Packages documentation](https://nodejs.org/api/packages.html)
- [Node.js v24 Globals](https://nodejs.org/download/release/latest-v24.x/docs/api/globals.html)
- [pnpm 11 Installation](https://pnpm.io/installation)
- [pnpm 11 package.json](https://pnpm.io/package_json)
- [WHATWG HTML module integration](https://html.spec.whatwg.org/multipage/webappapis.html#integration-with-the-javascript-module-system)

当日期、主版本或官方维护状态变化时，先更新版本注册表和验证环境，再更新正文；不要把未来状态倒写成今天已经验证的事实。
