---
schema_version: 2
edition: 2026.2-draft
id: ch.uniapp.platform-conditional
title: 平台 API、条件编译与能力检测
responsibility: 在统一业务合同下用条件编译和运行时能力检测隔离平台差异，提供明确降级路径，不散布无法测试的平台分支。
volume: '10'
order: 5
level: L2
status: drafting
path: book/volume-10-uniapp-miniprogram/chapters/ch.uniapp.platform-conditional.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.uniapp.template-components
version_surfaces:
- uni-app-cli-vue3
- uni-app-mp-weixin-compiler
- wechat-miniprogram-base-library
- wechat-developer-tools
- vue-3
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“平台 API、条件编译与能力检测”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - uniapp-platform-adaptation
  - uniapp-fallback-contract
  covers_topics:
  - uniapp.conditional-compilation
  - uniapp.platform-api
  - uniapp.capability-detection
  - uniapp.adapter-boundary
  - uniapp.platform-fallback
  - uniapp.unsupported-feature
  - uniapp.platform-branch-test
  - uniapp.dead-branch-risk
  - uniapp.component-contract
  uses_capabilities:
  - mobile.miniprogram-runtime
  - web.vue-template
  - mobile.uniapp-platform
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“平台 API、条件编译与能力检测”构建可运行程序与测试：为平台选择、分享和文件能力建立适配器及两个目标的可验证降级；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - uniapp-platform-adaptation
  - uniapp-fallback-contract
  covers_topics:
  - uniapp.conditional-compilation
  - uniapp.platform-api
  - uniapp.capability-detection
  - uniapp.adapter-boundary
  - uniapp.platform-fallback
  - uniapp.unsupported-feature
  - uniapp.platform-branch-test
  - uniapp.dead-branch-risk
  - uniapp.component-contract
  uses_capabilities:
  - mobile.miniprogram-runtime
  - web.vue-template
  - mobile.uniapp-platform
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: multi-target-build-capability-fixture-fallback-assertion
- id: diagnose
  kind: fault-diagnosis
  text: 面对“错误条件宏、只编译未运行或无能力检测导致的目标端崩溃”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - uniapp-platform-adaptation
  - uniapp-fallback-contract
  covers_topics:
  - uniapp.conditional-compilation
  - uniapp.platform-api
  - uniapp.capability-detection
  - uniapp.adapter-boundary
  - uniapp.platform-fallback
  - uniapp.unsupported-feature
  - uniapp.platform-branch-test
  - uniapp.dead-branch-risk
  - uniapp.component-contract
  uses_capabilities:
  - mobile.miniprogram-runtime
  - web.vue-template
  - mobile.uniapp-platform
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 平台 API、条件编译与能力检测

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《uni-app 模板、组件、表单与 Vue 差异》](ch.uniapp.template-components.md)：平台差异最终通过模板/组件适配呈现，需保持既有组件输入输出合同。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套程序用离线“目标编译器 + 能力夹具”模拟 H5 与微信小程序两个目标，能够检查分支选择、适配器合同和降级结果，但没有调用真实 DCloud 编译器、微信开发者工具、浏览器分享 API 或真机文件系统。离线绿灯只能证明教材中的合同模型成立，不能冒充目标平台验收。

uni-app 的价值是让大量业务代码跨端复用，而不是让所有平台变成完全相同。浏览器、小程序和 App 拥有不同宿主、权限、组件与发布规则。面对差异，最危险的写法是在页面里到处判断平台，然后直接调用某个宿主对象。几年后，没有人知道哪些分支会进入产物、哪些设备真正支持、失败时用户能做什么。本章把问题拆成三层：**编译期选择代码、运行期检测能力、领域层保持统一合同**。

## 1. 完成定义、学习入口与非目标

完成本章后，你应能：

1. 用自己的话区分编译期条件与运行期条件；
2. 正确写出 JavaScript、模板、样式与 `pages.json` 的条件编译标记；
3. 解释为什么平台名称不能等同于某项能力一定可用；
4. 把 `uni.*` 或 `wx.*` 调用封装在适配器边界，而不是散落在页面；
5. 为“支持、暂不可用、用户拒绝、调用失败”设计稳定结果；
6. 给不支持的平台提供看得见、能恢复的降级路径；
7. 用至少两个目标的产物清单和运行夹具发现死分支；
8. 从错误宏、编译日志、运行时能力快照和适配器调用记录中找到首个可信证据。

配套入口：

- [双目标适配器示例](../../../examples/encyclopedia/ch.uniapp.platform-conditional/README.md)
- [错误宏、死分支与缺失降级实验](../../../labs/encyclopedia/ch.uniapp.platform-conditional/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.uniapp.platform-conditional/README.md)

本章不讲上传、扫码、定位的完整权限状态机，那是下一章；不证明任何特定版本的宿主兼容性；不要求为了“统一”而隐藏所有平台差异；也不把条件编译当作业务需求分叉的常规工具。

## 2. 先建立三个时间点

“判断平台”发生在不同时间点，后果完全不同。

```text
源代码
  │
  ├─ 编译期：条件编译删除或保留源码片段
  │          ↓
  │       H5 产物 / 微信小程序产物
  │
  └─ 运行期：已经进入产物的代码读取宿主信息或检测能力
             ↓
          当前设备上的一次决策
```

第三个时间点是**业务运行时**：用户点击“分享工单”或“选择附件”以后，能力仍可能因为权限、网络、系统设置或用户取消而失败。于是一个可靠设计至少回答三问：

- 这段语法是否能进入目标产物？
- 进入产物后，当前宿主是否拥有需要的 API/组件/参数？
- 调用后失败，页面怎样给出确定状态和恢复动作？

只回答第一问会产生“编译成功、真机崩溃”；只回答第二问会把目标端根本不能解析的代码塞进产物；只处理成功回调会把拒绝、取消和不可用混成空数据。

## 3. 条件编译究竟做了什么

uni-app 官方文档把条件编译定义为：用特殊注释标记代码，编译时依据平台保留或移除片段。常见形式如下：

```ts
// #ifdef MP-WEIXIN
const buildTarget = 'mp-weixin'
// #endif

// #ifdef H5
const buildTarget = 'h5'
// #endif
```

`#ifdef` 表示定义了条件才保留，`#ifndef` 表示没有定义条件才保留，`#endif` 结束片段。多个条件可以用文档支持的逻辑形式组合。这里的 `MP-WEIXIN`、`H5` 是编译常量，不是运行时字符串变量；删除注释标记、拼错名称或使用错误注释语法都可能让结果与预期不同。

### 3.1 四种文件，四种注释语法

JavaScript/TypeScript 使用行注释：

```ts
// #ifdef MP-WEIXIN
export const hostFamily = 'miniprogram'
// #endif
```

Vue 模板使用 HTML 注释：

```vue
<template>
  <view>
    <!-- #ifdef MP-WEIXIN -->
    <button open-type="share">分享</button>
    <!-- #endif -->
  </view>
</template>
```

样式及其预处理语言应使用块注释：

```css
/* #ifdef H5 */
.toolbar { position: sticky; top: 0; }
/* #endif */
```

`pages.json` 也能按平台保留页面或配置，但它仍然必须满足对应工具的语法处理规则。条件标记之外和处理之后都应形成可解析内容。不能把“IDE 没有标红”当作两个目标都生成了正确配置。

### 3.2 条件编译适合什么

适合：

- 某平台才存在的组件或全局对象，其他目标解析会失败；
- 各目标入口文件、页面声明、静态资源确实不同；
- 某段依赖无法被非目标打包器解析；
- 需要从非目标产物中彻底移除实现与依赖。

不适合：

- 普通业务状态，例如工单是否关闭；
- 可以用一个稳定适配器解决的小差异；
- 仅为了避免写测试；
- 把整个页面复制成 H5 版和微信版，长期各自演化；
- 用 `#ifdef` 隐藏敏感信息——客户端产物不能保存秘密。

条件编译是“选择产物”的工具，不是架构边界本身。如果每个页面都包含十几段宏，依赖方向仍然混乱。

## 4. 平台识别不等于能力检测

知道当前产物是微信小程序，只能缩小可能性，不能证明某个能力此刻可用。能力还受基础库/运行时版本、宿主实现、操作系统、应用声明、用户权限、硬件和当前上下文影响。

```text
平台匹配
  ≠ API 一定存在
  ≠ 参数一定受支持
  ≠ 用户已经授权
  ≠ 调用一定成功
  ≠ 业务操作已经提交
```

例如 H5 通常没有 `uni.scanCode` 的统一支持；微信小程序可能有扫码 API，但用户仍可取消；分享入口可能受页面类型和宿主规则限制；文件能力即使存在，也可能因为临时路径过期而失败。可靠代码要检测它真正依赖的能力，并始终处理调用结果。

### 4.1 能力快照

建立一个小而可注入的能力快照，而不是让组件自己查询十次宿主：

```ts
export type CapabilitySnapshot = {
  target: 'h5' | 'mp-weixin'
  share: boolean
  chooseFile: boolean
  reasonByCapability: Partial<Record<'share' | 'chooseFile', string>>
}
```

快照的来源可以包括编译目标、官方 `canIUse` 能力查询、特性存在性、应用配置和服务端功能开关。具体查询方式是版本表面，必须以目标平台当前文档与真机证据为准。领域组件不需要知道快照怎样取得，只读取稳定字段。

### 4.2 检测必须靠近适配器

错误写法：

```ts
if (platform === 'mp-weixin') {
  // 页面直接依赖宿主对象；测试环境没有 wx，且没有失败合同。
  wx.shareAppMessage({ title: order.title })
}
```

更好的调用面：

```ts
type ShareResult =
  | { kind: 'shared' }
  | { kind: 'unsupported'; recovery: 'copy-link' }
  | { kind: 'cancelled' }
  | { kind: 'failed'; retryable: boolean }

interface SharePort {
  shareWorkOrder(input: { id: string; title: string }): Promise<ShareResult>
}
```

页面只消费 `ShareResult`。微信适配器、Web 适配器和测试假对象分别实现同一接口。这样组件合同稳定，平台细节集中，错误矩阵可以在普通测试里完成。

## 5. 适配器边界：统一意图，不伪造相同能力

“统一合同”不等于所有平台都返回假成功。它统一的是业务意图与结果分类。

```text
WorkOrderDetail.vue
        │ shareWorkOrder(input)
        ▼
      SharePort
       ├─ WeixinShareAdapter → 宿主分享能力
       ├─ WebShareAdapter    → Web Share / 复制链接
       └─ UnsupportedAdapter → 明确不可用 + 恢复建议
```

适配器应拥有：

- 宿主 API 的存在性/兼容性检查；
- 平台错误到领域结果的映射；
- 调用过程的取消或清理；
- 不含敏感数据的诊断字段；
- 可替换的依赖，以便夹具测试。

适配器不应拥有：

- 工单是否允许分享的授权判断；服务端必须做最终授权；
- 页面展示细节；它返回结果，不操作任意组件；
- 任意 fallback URL；链接必须由受控路由生成；
- 把所有 `fail` 都当成用户取消的字符串匹配。

## 6. 降级不是一句 Toast

降级路径应保留用户意图，并说明下一步。以“分享工单”为例：

| 能力状态 | 领域结果 | 页面行为 | 可恢复动作 |
|---|---|---|---|
| 原生分享可用且完成 | `shared` | 显示完成反馈 | 无 |
| 原生分享不存在 | `unsupported` | 展示受控链接 | 复制链接 |
| 用户取消 | `cancelled` | 保留当前页面 | 可再次点击 |
| 临时宿主失败 | `failed/retryable` | 解释失败 | 重试或复制链接 |
| 当前工单不可分享 | 服务端拒绝 | 不生成可用链接 | 联系管理员 |

“当前平台不支持”只是一条诊断，不是完整体验。如果用户原意是把工单交给同事，复制受控链接可能是合理降级；如果能力涉及定位且业务允许可选，则可以不附加位置；如果扫码不可用，可以提供经过校验的手工输入。降级绝不能绕过服务端授权或隐私同意。

### 6.1 不可用、拒绝、取消、失败要分开

- **不可用**：宿主/版本/硬件不提供能力，重试通常无意义；
- **拒绝**：用户或系统策略没有授予权限，可能需要解释或进入设置；
- **取消**：用户主动退出本次操作，不应显示红色系统故障；
- **失败**：超时、内部错误或业务拒绝，需要具体恢复策略。

下一章会把权限状态展开。本章的重点是适配器不能只返回 `boolean`，否则四种情况都会变成 `false`。

## 7. 组合一个可测试的平台注册表

不要在页面加载时到处生成实现。应用组合根根据编译目标注册一次：

```ts
export type PlatformServices = {
  target: 'h5' | 'mp-weixin'
  share: SharePort
  files: FilePickPort
  capabilities: CapabilitySnapshot
}

export function createPlatformServices(
  target: 'h5' | 'mp-weixin',
  host: HostBindings
): PlatformServices {
  if (target === 'mp-weixin') return createWeixinServices(host)
  return createH5Services(host)
}
```

真实项目中，某些工厂或导入可能必须放在条件编译片段中，以免非目标打包器解析平台专用模块。无论怎样，工厂返回的接口保持一致。组件通过 Vue `provide/inject`、显式参数或应用服务容器获得它，不读取全局平台变量。

### 7.1 条件编译与动态导入不是同一件事

动态导入是在运行或打包分析阶段加载模块；条件编译是在生成目标源码时移除片段。若某模块包含非目标无法解析的原生语法，仅靠 `if (false)` 或动态分支未必能阻止打包器解析。反过来，可以被所有目标解析、只需运行时选择的能力，未必值得用宏切开。决定前先问“问题发生在解析/打包阶段，还是当前设备执行阶段”。

## 8. 双目标验证：编译过还不够

至少为 H5 与 `mp-weixin` 保存两类证据。

**产物证据**：

- 构建命令、锁文件和工具版本；
- 目标输出目录；
- 平台专用模块是否只出现在目标产物；
- 两个目标是否都包含稳定适配器合同；
- 构建告警和宏展开后的关键文件。

**运行证据**：

- 当前 target 与能力快照；
- 支持能力时命中哪个适配器；
- 无能力时是否出现预期降级 UI；
- 用户取消/拒绝是否进入正确结果；
- 组件是否没有直接调用宿主对象。

```text
H5 build green ──┐
                  ├─ 不能推出功能已跨端通过
MP build green ──┘

还必须：H5 运行分支 + MP 运行分支 + 不支持/失败夹具
```

本章配套资产用纯 Node 模拟这条证据链：为两个目标选择模块，再对 `share=true/false` 和 `chooseFile=true/false` 注入夹具。真实项目必须替换成真实编译器、目标开发者工具和设备测试。

## 9. 死分支为什么常年不被发现

死分支是“以为存在，实际从未被构建或执行”的平台代码。常见成因：

1. 宏名拼写错误，`#ifdef` 片段被静默移除；
2. CI 只构建 H5，从不构建小程序；
3. 只验证产物生成，不触发目标能力；
4. 开发工具开启绕过选项，真机规则不同；
5. 运行时判断值域过时，例如把 `devtools` 当成真实操作系统；
6. 能力检测只覆盖“存在”，没有覆盖拒绝和失败；
7. 平台专用依赖升级后合同变化，但适配器测试仍是假实现自测。

防止死分支需要矩阵，而不是一次成功截图：

| 目标 | 构建 | 支持夹具 | 无能力夹具 | 失败夹具 | 目标端运行 |
|---|---:|---:|---:|---:|---:|
| H5 | 必须 | 必须 | 必须 | 必须 | 浏览器 |
| mp-weixin | 必须 | 必须 | 必须 | 必须 | 开发工具 + 真机 |

如果某平台暂不在发布范围，应从支持声明和 CI 矩阵中明确移除，而不是保留一个没人运行的绿色图标。

## 10. 故障定位：先判断失败阶段

### 10.1 编译期失败

现象：语法错误、平台模块无法解析、页面未生成、专用组件进入错误目标。首个可信证据通常是目标构建日志和生成产物，而不是页面运行日志。检查：

1. 当前实际构建目标；
2. 条件标记的注释语法、宏名与闭合；
3. 宏处理前后语法是否都有效；
4. 平台专用 import 是否也处在正确边界；
5. 输出目录中是否存在目标文件。

### 10.2 运行时崩溃

现象：`undefined is not a function`、宿主对象不存在、某参数不支持。首个证据是目标设备堆栈与能力快照。检查实际版本、API/参数兼容表、能力检测，以及适配器是否在调用前选择 fallback。

### 10.3 功能静默不可用

现象：按钮可点却没反应，或者只显示统一“失败”。首个证据是意图事件、适配器选择和最终领域结果三段日志。若只有 UI 日志，就无法判断事件没发出、适配器没注册还是宿主回调没映射。

### 10.4 修复后的原验证

修复错误宏后，必须重跑原来的两个目标及能力矩阵。只在当前平台手点一下不能证明非当前分支没有被破坏。报告要保留：失败命令与日志、最小修改、相同命令的新结果、仍未覆盖的真实设备/版本。

## 11. FactoryCare 示例边界

FactoryCare 报修端需要“分享工单摘要”和“选择附件”。领域层声明：

```ts
type PlatformAction<T> =
  | { kind: 'ok'; value: T }
  | { kind: 'cancelled' }
  | { kind: 'unsupported'; fallback: string }
  | { kind: 'denied'; recovery: 'settings' | 'explain' }
  | { kind: 'failed'; code: string; retryable: boolean }
```

这个联合类型让页面必须处理每一种结果。分享适配器只生成经过服务端授权的受控路径；文件适配器只返回临时文件描述，不直接上传；后端仍验证租户、工单权限、文件类型和大小。H5 可以复制链接或使用当前浏览器能力，小程序可以接入宿主能力；二者都不能把授权判断留给按钮是否显示。

## 12. 实验指导：亲手制造三种错

实验不是抄答案，而是建立“阶段—证据—修复—重跑”习惯。

### 12.1 错误条件宏

把 `MP-WEIXIN` 写成未定义宏，预期：微信目标清单缺少专用适配器。第一证据应是目标产物清单，不是猜测运行缓存。修复宏后重建两个目标，确认 H5 没有意外包含微信模块。

### 12.2 只编译、不运行

让两个目标都能生成，但测试只执行 H5。验证器应报告 `mp-weixin` 分支未执行，而不是给整章绿灯。修复方式是将目标与能力夹具做笛卡尔组合，并记录命中的 adapter id。

### 12.3 没有能力检测

令微信目标的 `share=false`，故障实现仍直接调用宿主函数。预期结果是可复现崩溃或缺失 fallback。修复后应得到 `unsupported + copy-link`，组件保持可用。

## 13. 120 秒复述模板

你可以按以下顺序复述：

1. 条件编译在生成目标产物时保留/移除代码，适合解析和产物层差异；
2. 运行时能力检测回答当前宿主/版本/设备是否能做某事；
3. 平台名称不能推出权限和调用结果；
4. 页面依赖稳定端口，平台 API 集中在适配器；
5. 结果至少区分成功、不支持、取消、拒绝和失败；
6. 每个不支持场景都有明确降级；
7. 验证需覆盖两个目标的产物和实际分支，防止死分支；
8. 错误宏看构建/产物，能力缺失看设备堆栈、快照与适配器记录。

越界反例：“因为当前是微信小程序，所以直接在所有页面调用 `wx.*`，失败统一显示网络错误。”它混淆平台与能力、破坏组件合同、没有降级，也无法通过普通测试替换宿主。

## 14. 速查表

| 问题 | 首选机制 | 必留证据 |
|---|---|---|
| 非目标无法解析某组件/模块 | 条件编译 | 两目标产物清单 |
| 当前版本是否支持 API/参数 | 能力检测 | 宿主/版本/查询结果 |
| 用户是否允许能力 | 权限状态机 | 状态迁移与设置快照 |
| 平台实现差异 | 适配器 | 端口合同与实现 id |
| 能力不存在 | 显式 fallback | 降级 UI 断言 |
| 用户取消 | `cancelled` | 不报系统错误、可重试 |
| 目标分支从未执行 | 矩阵测试 | 每目标 branch-hit |
| 修复错误宏 | 原命令双目标重跑 | 红→绿日志与残余风险 |

## 15. 从零建立目录，而不是先写宏

初学者可以按下面顺序落地，避免一上来就在页面里堆条件：

```text
src/platform/
├── contracts.ts          # SharePort、FilePickPort 与领域结果
├── capability.ts         # 能力快照的数据结构和纯判断
├── h5/
│   ├── share.ts          # H5 实现与复制链接降级
│   └── files.ts
├── mp-weixin/
│   ├── share.ts          # 微信实现
│   └── files.ts
└── index.ts              # 组合根，向页面只暴露稳定服务
```

第一步只写 `contracts.ts`，用假实现让组件能够渲染五种结果。第二步写 H5 适配器并完成支持/不支持/失败夹具。第三步写微信适配器。最后才在 `index.ts` 或 import 边界加入必要的条件编译。这样宏依赖已经被压缩到少数位置，组件测试也不需要真实宿主。

如果平台实现非常小，可以在同一文件的两个条件片段中赋值；如果依赖专用组件或包，应分文件并在正确目标才导入。不要为每个平台复制整个 `pages/` 目录，除非页面的信息架构和交互合同确实不同，并且团队明确接受双份维护成本。

### 15.1 一个组件怎样消费合同

```ts
async function onShareClicked(): Promise<void> {
  sharing.value = true
  shareMessage.value = ''
  try {
    const result = await platform.share.shareWorkOrder({
      id: props.workOrder.id,
      title: props.workOrder.title
    })
    // 映射职责：组件只把稳定领域结果映射为界面，不解析宿主 errMsg。
    shareState.value = result.kind
    if (result.kind === 'unsupported') shareMessage.value = '可复制工单链接分享'
    if (result.kind === 'cancelled') shareMessage.value = '已取消，工单内容保持不变'
    if (result.kind === 'failed') shareMessage.value = result.retryable ? '暂时失败，可重试' : '当前无法分享'
  } finally {
    sharing.value = false
  }
}
```

注意 `finally` 只负责收尾，不证明结果成功；同一按钮应在进行中防重复；页面卸载后的旧异步结果还需 operation id 或 active flag 保护。这里展示消费合同的形状，不代表已经解决后续章节的全部竞态。

### 15.2 版本表面要显式记录

平台适配最容易受版本变化影响。每次验收记录：uni-app 编译器来源与版本、CLI/HBuilderX 方式、Vue 版本、目标平台、微信基础库、开发工具、设备/系统，以及真正使用的 API/参数。不要只写“最新版”。CLI 项目的编译器可能跟项目依赖走，HBuilderX 可视化项目可能跟工具安装走；同事机器上的“同一个项目”仍可能使用不同版本面。

遇到兼容问题时，不应先把所有 API 改成旧写法。先确认支持矩阵与目标用户范围，再决定：提高最低版本、保留降级、条件移除新参数，或暂缓功能。决定应写入适配器测试和发布说明。

## 16. AI 生成平台代码时的验收清单

Vibe coding 可以快速生成适配器，但模型很容易混用微信原生、uni-app、浏览器和 App API，或者引用已经变化的兼容结论。接受代码前逐项检查：

1. 这段代码属于哪个构建目标、哪个宿主和哪个版本？
2. API 名、参数、回调与返回任务是否来自当前官方文档？
3. 条件标记使用了正确文件类型的注释吗？宏能被当前工具识别吗？
4. 非目标产物是否真的移除了专用依赖？
5. 页面是否只依赖端口，而非直接读 `wx`、`window` 或 `plus`？
6. 能力检测针对具体能力，还是只判断平台字符串？
7. 不支持、取消、拒绝和失败有没有不同结果？
8. 每个失败结果是否有不会越权的恢复路径？
9. 两个目标是否都构建并执行了分支？
10. 日志是否包含 token、完整 URL query、扫码原文或本地文件路径？

若 AI 说“该 API 全平台支持”，必须回到官方兼容表；若它只给成功回调，要求补齐结果联合与失败夹具；若它生成五个页面级 `#ifdef`，先让它重构成端口和组合根。AI 输出是候选实现，构建产物、目标端运行和失败矩阵才是证据。

### 16.1 提交前的机械门禁

一个实用的低成本门禁可以检查：

- 条件标记成对闭合，宏名来自允许列表；
- `pages/` 和通用组件中禁止直接出现平台全局对象；
- 每个适配器实现导出同一合同；
- CI 至少生成两个声明支持的目标；
- 运行夹具记录每个 target 的实现 id；
- fallback 文案与动作存在；
- 公开支持矩阵与构建矩阵一致。

这些检查不能证明真机行为，却能在正式跨端验收前挡住明显死分支。若产品只发布微信小程序，就不要为了“看起来跨端”伪造 H5 绿灯；支持范围应诚实、可验证。

## 17. 事实来源与证据边界

本章易变事实于 2026-07-24 对照 uni-app 官方“条件编译处理多端差异”“编译器”和 API 总览页面。官方文档说明了特殊注释、支持文件、平台宏、编译期/运行期判断和能力 API 的存在。具体宏、平台值、版本和 API 参数会变化，实施时必须重新读取目标版本官方兼容表。

直接来源：

- DCloud，[条件编译处理多端差异](https://uniapp.dcloud.net.cn/tutorial/platform.html)：条件标记、平台宏、支持文件与编译期/运行期适配边界。
- DCloud，[什么是编译器](https://uniapp.dcloud.net.cn/tutorial/compiler)：编译器、运行时、Vue 版本与 CLI/HBuilderX 工程的版本归属。
- DCloud，[API 概述](https://uniapp.dcloud.net.cn/api/index.html)：uni API、标准 JavaScript、宿主特色 API 与条件编译关系。

当前未验证：DCloud CLI/HBuilderX 的真实双目标构建、微信基础库版本、真机分享、浏览器 Web Share、平台文件选择、开发者工具生成物与 FactoryCare 服务端授权。它们必须进入项目验收证据，不能由本章离线验证器替代。
