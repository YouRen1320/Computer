---
schema_version: 2
edition: 2026.2-draft
id: ch.vue.performance
title: 渲染分析、懒加载、错误恢复与性能预算
responsibility: 用 Vue DevTools、浏览器 trace 和预算定位不必要渲染、过大 chunk 与恢复失败，实施可测优化且不牺牲正确性或无障碍。
volume: '09'
order: 14
level: L2+
status: drafting
path: book/volume-09-vue-nuxt/chapters/ch.vue.performance.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.vue.component-testing
version_surfaces:
- vue-3
- vite
- browser
- browser-devtools
- vitest
- playwright
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“渲染分析、懒加载、错误恢复与性能预算”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - vue-render-bundle-performance
  - vue-error-recovery
  covers_topics:
  - vue.render-tracking
  - vue.component-lazy-loading
  - vue.async-component
  - vue.chunk-budget
  - vue.list-virtualization-boundary
  - vue.error-captured
  - vue.error-boundary-pattern
  - vue.performance-budget
  - vue.optimization-regression
  uses_capabilities:
  - web.vue-reactivity-lifecycle
  - web.javascript-network-race
  - web.component-e2e-testing
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为一个过度渲染和首包过大的工单页建立预算、修复并保存前后证据；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - vue-render-bundle-performance
  - vue-error-recovery
  covers_topics:
  - vue.render-tracking
  - vue.component-lazy-loading
  - vue.async-component
  - vue.chunk-budget
  - vue.list-virtualization-boundary
  - vue.error-captured
  - vue.error-boundary-pattern
  - vue.performance-budget
  - vue.optimization-regression
  uses_capabilities:
  - web.vue-reactivity-lifecycle
  - web.javascript-network-race
  - web.component-e2e-testing
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: bundle-analysis-browser-trace-regression-suite
- id: diagnose
  kind: fault-diagnosis
  text: 面对“深层 watch、错误懒加载边界或无恢复 async component 导致的卡顿和白屏”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - vue-render-bundle-performance
  - vue-error-recovery
  covers_topics:
  - vue.render-tracking
  - vue.component-lazy-loading
  - vue.async-component
  - vue.chunk-budget
  - vue.list-virtualization-boundary
  - vue.error-captured
  - vue.error-boundary-pattern
  - vue.performance-budget
  - vue.optimization-regression
  uses_capabilities:
  - web.vue-reactivity-lifecycle
  - web.javascript-network-race
  - web.component-e2e-testing
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 渲染分析、懒加载、错误恢复与性能预算

> 本章不是“背诵若干优化技巧”。你要先用同一场景留下基线，再根据 trace、组件更新和构建产物找到主因，实施最小修复，最后用原场景证明预算达标且功能、错误恢复和无障碍没有回退。

## 1. 性能优化首先是证据问题

FactoryCare 调度页同时展示工单筛选、统计卡片、长列表和按需打开的证据面板。用户报告“页面卡”时，至少可能对应四类完全不同的问题：

- 初次访问下载和解析的 JavaScript 太多，内容很晚才可交互；
- 输入筛选时父组件变化导致大量行组件重复更新；
- 一次深层 watcher 遍历了庞大对象，阻塞主线程；
- 动态 chunk 加载失败后没有错误界面和重试，用户只看到白屏。

如果没有测量就加入 `v-memo`、改成异步组件或引入虚拟列表，可能让代码复杂度上升，却没有改善真正瓶颈。性能优化的闭环应当是：

```text
固定场景 -> 保存基线 -> 找到首个可信瓶颈 -> 提出预算 -> 最小修复
        -> 重跑同一场景 -> 功能/无障碍回归 -> 保存前后证据
```

“我感觉更快”不能作为完成证据。“Lighthouse 分数更高”也不自动证明列表交互变快，因为测量场景、网络、CPU、缓存和页面状态可能不同。

## 2. 把性能拆成三个预算面

本章用三个互补的预算面，避免用单一数字概括所有性能。

### 2.1 加载预算

关注初始 HTML、CSS、入口 JavaScript、动态 chunk、字体和图片的传输与执行。一个可执行预算必须写出：

- 哪个路由和构建模式；
- gzip/Brotli 传输大小还是原始产物大小；
- 冷缓存还是热缓存；
- 网络和 CPU 限速；
- 哪些 chunk 属于初始路径；
- 超出多少阻止合并。

例如：“生产构建中 `/dispatch` 首次导航所需入口 JS 原始总量不超过 180 KiB，证据面板必须是动态 chunk，失败时显示可重试界面。”这仍不是普适行业阈值，只是本项目在当前设备和场景下的初始预算。

### 2.2 更新预算

关注已经加载后的交互：一次筛选输入触发多少组件更新、多少 layout、最长任务多长、交互到下一次绘制需要多久。预算必须绑定固定数据量和动作，例如：“200 条工单中切换一个 active id，只允许旧行和新行更新；过滤输入的第 95 百分位处理时间低于项目预算。”

### 2.3 恢复预算

性能不仅是成功路径。动态 chunk 404、发布后旧 HTML 引用已删除 chunk、弱网超时或组件渲染抛错时，用户多久能看到明确错误？是否能重试？失败是否保留原页面导航和焦点？恢复预算可以写成：“加载超过 3 秒显示状态；失败显示错误摘要和重试按钮；重试不会重复提交业务操作；错误上报不包含隐私字段。”

## 3. 建立可比较基线

优化前先固定实验：

1. 使用生产构建，而不是只测 Vite 开发模式；
2. 记录 commit、Node、pnpm、Vue、Vite 和浏览器版本；
3. 固定数据夹具、路由、视口、缓存、网络和 CPU 条件；
4. 预热次数与正式采样次数分开；
5. 对同一用户动作建立脚本或逐步记录；
6. 保存构建清单、trace、组件 profiler、测试结果和无障碍检查；
7. 一次只改一个主要变量，再重跑原验证。

浏览器 trace 用于回答主线程在做什么，Vue DevTools profiler 用于回答哪些组件为什么更新，构建产物用于回答下载了什么。三者不能互相替代。组件更新很多不一定是主线程主因；chunk 很大也不一定影响已缓存的当前交互。

Vue 官方建议在本地分析时开启 `app.config.performance`，让 Vue 特定标记出现在浏览器 Performance 时间线中。该开关用于分析，不应因此在生产永久输出多余测量；DevTools 界面和标记名称属于版本表面。

## 4. 渲染追踪：谁读取了依赖，谁被写入触发

Vue 提供开发期调试钩子 `onRenderTracked()` 与 `onRenderTriggered()`：

```ts
import { onRenderTracked, onRenderTriggered } from 'vue'

onRenderTracked((event) => {
  console.debug('render-track', event.type, event.key)
})

onRenderTriggered((event) => {
  console.debug('render-trigger', event.type, event.key)
})
```

它们适合在开发环境缩小依赖范围，不能作为生产监控 API；官方明确这些钩子仅在开发模式调用，SSR 中也不会调用。分析时重点记录：哪个组件、哪次用户动作、哪个 target/key、触发类型以及随后更新次数。不要把完整业务对象打印到共享日志。

最常见的过度更新并非 Vue “重新渲染整个页面”，而是父组件给每个子项传递了不稳定 props：

```vue
<!-- activeId 改变时，每个子项都收到变化的 active-id。 -->
<WorkOrderRow
  v-for="order in orders"
  :key="order.id"
  :order="order"
  :active-id="activeId"
/>
```

改为父级计算稳定布尔值：

```vue
<WorkOrderRow
  v-for="order in orders"
  :key="order.id"
  :order="order"
  :active="order.id === activeId"
/>
```

当 active id 从 A 变成 B，多数行的 `active` 仍是 `false`，理论上只有 A/B 两行的相关 prop 改变。是否真的减少更新仍要由 profiler 和组件测试证明。

## 5. 深层 watcher：方便但可能放大工作量

`watch(largeObject, callback, { deep: true })`会让 Vue 追踪深层属性。对象越大、变化越频繁，遍历和依赖数量越可能成为成本。常见反模式是为了“任何筛选变化就请求”而深看整个页面模型，其中还包含列表结果、选中项和展示元数据。

优先选择精确来源：

```ts
watch(
  () => [filters.status, filters.assigneeId, filters.keyword],
  ([status, assigneeId, keyword]) => reload({ status, assigneeId, keyword }),
)
```

这不是说深层 watcher 永远错误。小型配置对象、低频变化且语义确实是“任何嵌套字段变化”时可以使用。决定依据应是数据规模、变更频率、trace 与业务语义，而不是代码行数。

watcher 触发请求时还要处理取消和竞态：新筛选开始后，旧响应不能覆盖新结果。性能章不会重新发明网络章节的方案，只要求优化不得破坏已有 AbortController、请求序号或服务端状态缓存合同。

## 6. computed、对象身份与无意更新

computed 能缓存派生结果，但若每次求值都返回新对象，即使语义未变，下游仍可能观察到不同身份。Vue 3.4+ 对 computed 值相等时减少 effect 触发，但对象相等仍依赖身份，手工稳定旧值属于高级优化，容易出错。

先用更简单的方式：

- 让 computed 返回原始值或稳定引用；
- 不在模板中每次创建大对象和内联数组作为 prop；
- 不复制完整工单对象只为添加一个 `selected` 字段；
- 保持列表 `key` 稳定，不能用会变化的索引冒充业务身份；
- 大型不可变数据可评估 `shallowRef`，但必须遵守替换根引用的更新方式。

`v-once`适合真正不会再变化的子树，`v-memo`只应在已测得的性能关键大子树/列表使用。官方把 `v-memo`定位为少见的微优化；把它撒满模板会让正确性推理和调试变困难。

## 7. 大列表与虚拟化边界

即使框架更新高效，几千个 DOM 节点仍会增加创建、样式、布局、内存和无障碍树成本。虚拟列表只渲染视口附近项目，是常见解决方向，但不是“加一个组件就完成”。

采用前必须定义边界：

- 行高固定还是动态，测量误差如何修正；
- 键盘向下移动到未渲染项时如何滚动并恢复焦点；
- 屏幕阅读器如何理解总数、位置与当前项；
- 浏览器查找、打印、复制多行和锚点链接是否仍符合需求；
- 行展开、图片加载和状态变化是否影响高度；
- 选择状态是否由业务 ID 保存，而非 DOM 是否存在；
- 自动化测试如何控制滚动与可见区。

数据量较小或分页已经满足任务时，虚拟化的维护成本可能高于收益。先降低不必要组件更新、减少每行抽象层、分页或服务端过滤，再用真实规模测量是否仍需要虚拟化。

## 8. 懒加载与动态 import

懒加载的目标是把当前路径不需要的代码移出初始依赖图。ES 动态 import 返回 Promise，Vite 会把可静态分析的动态导入作为代码分割点：

```ts
const EvidencePanel = defineAsyncComponent(() =>
  import('./EvidencePanel.vue'),
)
```

组件只有渲染时才调用 loader。适合按需打开的复杂图表、证据预览、低频管理页面；不适合首屏核心标题、登录表单或每次都会立刻显示的小组件。分割过细会增加请求、调度、依赖共享和发布一致性复杂度。

路由组件应使用 Vue Router 的路由懒加载约定，不要因为 API 相似就把所有路由记录包进 `defineAsyncComponent()`。组件级异步与路由级动态 import 的生命周期不同。

Vite 对动态表达式可分析范围有限。`import(variable)`可能把意外的大量文件纳入映射，也可能无法按预期构建。构建清单与 chunk 图才是证据，源码中出现 `import()`不是完成标准。

## 9. 异步组件必须拥有失败界面

只写 loader 会把加载失败变成难以理解的空白区域。`defineAsyncComponent()`支持 loading、error、delay、timeout 和 `onError`：

```ts
const EvidencePanel = defineAsyncComponent({
  loader: () => import('./EvidencePanel.vue'),
  loadingComponent: EvidencePanelLoading,
  errorComponent: EvidencePanelError,
  delay: 200,
  timeout: 5_000,
  onError(error, retry, fail, attempts) {
    if (isTransientChunkFailure(error) && attempts <= 2) retry()
    else fail()
  },
})
```

重试必须有限、可观察且不会重复业务写操作。动态组件 loader 只加载代码，不应顺便提交工单。错误组件要说明发生了什么、提供可操作的重试或返回入口，并把焦点移到合理位置；不能只显示旋转图标。

部署后旧页面引用已被删除的 chunk 是真实风险。Vite 会发出 `vite:preloadError`事件供应用处理预加载错误，但“监听后直接无限刷新”会制造刷新循环和数据丢失。应记录发布版本、限制一次恢复、保护未提交草稿，并在服务端保留合理的静态资产缓存/版本策略。

## 10. 错误边界模式

Vue 的 `onErrorCaptured()`能捕获后代组件在渲染、事件、生命周期、setup、watcher、指令和 transition 等来源抛出的错误。可以用它把局部区域切换到恢复界面：

```ts
const failure = shallowRef<unknown>(null)

onErrorCaptured((error) => {
  failure.value = error
  return false
})
```

错误界面不能再次渲染原故障内容，否则可能形成循环。返回 `false`会阻止错误继续向上传播，因此只有当本层真正处理并完成必要上报时才这样做；否则让应用级 `errorHandler`继续统一观测。

Vue 没有要求一个名为 ErrorBoundary 的内置组件，但可以建立团队模式：默认 slot 渲染业务内容，fallback slot 接收安全错误摘要与 retry/reset 操作，内部 `onErrorCaptured`记录故障。边界应围绕可独立恢复的区域，而不是每个按钮一个，也不是整个应用只有一个白屏替换器。

错误对象、组件 props 和服务器响应可能含敏感信息。日志中保存错误类别、版本、路由模板、相关 request id 和安全上下文，不保存报修人联系方式、token 或完整附件路径。

## 11. Chunk 预算与构建分析

构建日志中的压缩大小只是起点。完整分析至少区分：

- 初始 entry 与动态 entry；
- 当前路由必须加载的共享依赖；
- 未使用但因副作用无法 tree-shake 的代码；
- 重复依赖版本；
- source map 是否被错误计入发布；
- CSS、字体、Wasm 和图片等非 JS 资源；
- 原始、gzip、Brotli 与解析执行成本。

预算脚本应读取机器可解析的 manifest 或统计工件，而不是用脆弱正则截取彩色终端输出。预算失败必须列出资产名、实际值、阈值和基线差异。

不要为了让单 chunk 变小而强行 `manualChunks`，却让首屏仍下载相同总量，甚至增加依赖瀑布。人工分包是版本敏感策略，应建立路由级加载图和缓存命中证据。

## 12. 优化不能破坏正确性和无障碍

性能修改经常改变渲染时机、DOM 数量、焦点和错误路径。每次修复后至少重跑：

- 组件合同：props、emit、slot 与状态更新仍正确；
- 网络合同：取消、旧响应抑制和错误显示仍正确；
- 键盘：可聚焦顺序、弹窗关闭后焦点恢复、虚拟行导航；
- 语义：标题、列表/表格关系、状态消息和错误摘要；
- E2E 主任务：筛选、打开工单、加载证据、失败后重试；
- 视觉：loading 与 error 不造成不可接受布局跳动；
- 性能：使用原数据和原动作重跑同一 trace。

为了减少 DOM 而移除表头、把按钮换成不可聚焦 div、让 loading 覆盖整页，均不是可接受优化。虚拟列表、懒加载和延迟水合尤其需要真实浏览器与辅助技术人工检查。

## 13. 三个故障的首个可信证据

### 13.1 深层 watch 导致输入卡顿

**症状**：每输入一个字符都出现长任务。

**证据顺序**：固定 500 条夹具；录制输入 trace；在长任务调用栈和 Vue profiler 中定位 watcher；用 render debug 钩子确认依赖；移除深层遍历或缩小来源；重跑同一输入脚本。

**不要先做**：直接加 1 秒 debounce。它可能掩盖遍历成本并让交互延迟更差。

### 13.2 懒加载边界错误导致 chunk 仍进首包

**症状**：源码用了动态 import，但入口预算未下降。

**证据顺序**：查看生产 manifest 和模块图；确认是否有另一个静态 import；确认 barrel 文件副作用；记录修复前后 entry 依赖图，而不是只看文件名多了一个 hash。

### 13.3 异步组件失败后白屏

**症状**：阻断动态 chunk 后区域为空，控制台出现加载错误。

**证据顺序**：保存失败 URL/status 与组件状态；检查 loader 是否 reject；检查 errorComponent、timeout、有限 retry；检查全局 preload error 处理；验证错误摘要、焦点和重试；恢复网络后重跑。

## 14. 配套实验与判据

配套资产分为：

- `examples/encyclopedia/ch.vue.performance/`：生产构建、动态 chunk、预算清单和错误恢复模型；
- `labs/encyclopedia/ch.vue.performance/`：固定场景的前后预算、渲染次数与三类故障诊断；
- `exercises/encyclopedia/ch.vue.performance/`：故意超预算且无恢复字段的公开红灯；
- `solutions-private/encyclopedia/ch.vue.performance/`：保持相同 oracle 的参考修复。

机械验证只能证明确定性构建模型、预算脚本和故障标记；它不会伪造 Chrome trace、Vue DevTools profiler、Playwright 浏览器运行或屏幕阅读器证据。学习者的完整 Lab 还必须在真实生产构建上补齐这些工件。

Lab 判据：

1. 固定同一条工单交互路径与数据夹具；
2. 建立 entry chunk、动态 chunk、行更新次数和恢复时间预算；
3. 修复后至少一个主指标下降到预算；
4. 动态组件具备 loading、error、timeout 和有限重试；
5. 深层 watch、错误分割与无恢复边界三个故障可定位；
6. 组件、E2E 和无障碍检查不回退；
7. 保存版本、命令、原始输出和残余风险。

## 15. AI 辅助优化的边界

AI 可以列候选原因、生成预算脚本和解释 trace，但不能仅凭代码截图判断瓶颈。给 AI 的输入应包括：固定场景、构建 manifest、相关 profiler 片段、trace 事件摘要、预算和回归测试。要求它区分“证据支持”“推测”和“需要追加实验”。

拒绝以下改法：

- 未测量就把所有组件改成异步；
- 为降低 chunk 数字删除错误恢复或无障碍代码；
- 通过放宽预算、减少数据夹具或跳过 E2E 获得绿灯；
- 遇到 chunk 错误无限刷新；
- 用随机计时结果宣称稳定提升；
- 把浏览器长任务全部归因于 Vue。

你必须能解释每项修改改变了哪条依赖边、哪个构建入口或哪个恢复状态，并用原验证证明。

## 16. 120 秒口述与独立构建

口述时说明：加载与更新性能有什么区别；为什么先固定场景；render tracking 与浏览器 trace 各回答什么；稳定 props 如何减少子组件更新；何时需要虚拟列表；动态 import 为什么不等于预算下降；异步组件失败如何恢复；`onErrorCaptured`的传播边界；为什么性能优化必须重跑功能与无障碍。

不应由本章解决的反例：“数据库查询本身耗时 4 秒，服务端 trace 已证明索引缺失。”前端可以展示 loading 和取消，但不能用 `v-memo`修复数据库执行计划。

独立构建要求你从空目录创建一个过度渲染、首包过大且错误边界缺失的工单页，先保留失败证据，再实施稳定 props、精确 watcher、动态 chunk 和恢复组件，最后用同一预算、组件/E2E 与无障碍检查证明无回退。

## 17. 版本表面与未验证边界

本章在 2026-07-17 对照 Vue 和 Vite 官方资料。稳定原则是先测量、预算绑定场景、最小修复、同场景重跑和不牺牲正确性；版本表面包括 DevTools UI、Vite chunk 策略、构建 manifest、浏览器 trace 字段、Vue 调试钩子和异步组件选项。

配套验证运行于本机 Node/pnpm 的确定环境，不代表真实用户设备。真实浏览器 CPU/网络、Chrome Performance/Layers、Vue DevTools、Playwright E2E、键盘与屏幕阅读器结果必须由后续人工或浏览器流水线补证。

## 18. 性能证据记录模板

为了让另一个人能够复现实验，每次性能修改都建立一张记录卡，而不是只上传一张 DevTools 截图：

```text
场景：/dispatch，200 条固定工单，点击 WO-101 后再点击 WO-102
环境：commit、production build、浏览器/操作系统、视口、CPU/网络限速
冷启动：清空哪些缓存；预热次数；正式采样次数
基线：入口资产、动态资产、更新组件、最长任务、交互指标
预算：每项阈值、阈值来源、允许波动范围
修改：只描述本轮改变的依赖边、分割点或恢复状态
复测：使用完全相同输入，保存原始 trace 与汇总
回归：组件、E2E、键盘、焦点、语义、错误恢复
残余风险：未测设备、未测浏览器、虚拟列表或缓存假设
```

一次采样容易受后台进程、热缓存、浏览器扩展和 JIT 影响。至少运行多次并保留原始值，报告中位数、分位数或范围；不要挑最快的一次。对本地确定性构建大小，可用单次精确工件；对时延类数据，则要说明样本量和离群处理规则。

比较前后版本时还要确认数据完全相同。若优化版只渲染 20 条而基线渲染 200 条，除非需求本身变成分页/虚拟化，否则不能直接宣称算法更快。若关闭无障碍检查、错误上报或权限校验换取数字下降，也属于行为回退。

性能预算应进入版本控制，并在变化时接受代码评审。合理变更预算的原因包括新增经批准的核心能力、目标设备变化或测量方法修正；不能因为当前提交超标就临时把阈值调高。预算更新要与功能修改分开列出影响、迁移和回滚方式。

构建预算脚本的失败输出至少包含：资产或路由、实际值、阈值、与基线差异、生成工件位置。浏览器流水线失败则保存 trace、截图、console、Network 和测试录像的索引。没有原始工件，后续无法判断是产品回退、环境抖动还是测量脚本变化。

最后把“已验证”和“未验证”分开书写。例如：已在 Chrome 指定版本、Mac arm64、200 条夹具证明行更新由 200 降到 2；未在低端 Android、Firefox、屏幕阅读器和 5000 条动态高度列表验证。诚实边界比一个没有上下文的绿色分数更有价值。

## 19. 官方资料

- [Vue：Performance](https://vuejs.org/guide/best-practices/performance)
- [Vue：Async Components](https://vuejs.org/guide/components/async)
- [Vue：Composition API Lifecycle Hooks](https://vuejs.org/api/composition-api-lifecycle)
- [Vue：Built-in Directives](https://vuejs.org/api/built-in-directives)
- [Vite：Building for Production](https://vite.dev/guide/build)
- [Vite：Features 与 Dynamic Import](https://vite.dev/guide/features.html)

## 20. 本章结论

Vue 性能优化是一条证据链：固定真实任务，分别建立加载、更新和恢复预算；用浏览器 trace、Vue profiler、render tracking 与构建清单找到首个可信瓶颈；再选择稳定 props、精确 watcher、列表虚拟化、动态 import 或错误边界中的最小方案。异步和分包必须处理 loading、error、timeout 与有限重试，任何提升都必须通过原功能、E2E 和无障碍回归。没有这条闭环，优化只是更复杂的猜测。
