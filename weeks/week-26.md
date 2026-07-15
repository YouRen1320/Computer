# 第 26 周：Vue 3 SFC、模板、响应式、组件、生命周期与 Composable

> 建议投入：16 小时（可在 15—18 小时内调整）

## 1. 本周定位

HTML/CSS、JavaScript、浏览器机制和 TypeScript 已在 Week 22—25 系统补齐。本周从 Vue 框架核心重新梳理 SFC、模板、响应式、组件通信、生命周期和 Composable，把已有经验升级成 2026 年可面试、可维护、能审查 AI 代码的能力，再在第 27 周搭完整企业后台。

FactoryCare 本周建立 Web 端领域 UI 基础与可复用逻辑，不急于堆路由、状态库和 UI 组件库。

## 2. 前置条件

- 第 21 周后端阶段考核通过，FactoryCare API 契约和权限模型稳定。
- 熟悉 HTML、CSS、JavaScript、TypeScript 和 Vue 3 基本语法。
- Node.js、pnpm 使用当前稳定生产版本；依赖通过 lockfile 固定，不使用 nightly/RC。
- 已从 OpenAPI 或接口文档整理用户、设备、工单和分页响应类型。

## 3. 学习目标

- 用 Week 22—25 的证据定位仍未关闭的 HTML、CSS、JavaScript、TypeScript 和浏览器缺口，不重新把它们压缩成一次两小时审计。
- 能解释 Vue 的依赖追踪、触发更新、批处理与组件渲染时机。
- 能正确选择 `ref`、`reactive`、`computed`、`watch`、`watchEffect` 和浅层响应式工具。
- 能以严格 TypeScript 定义 Props、Emits、双向绑定、模板引用和异步状态。
- 能把状态逻辑提取为职责单一、可测试、会清理副作用的 Composable。
- 能识别失去响应式、重复派生状态、深度监听和未释放监听器等常见缺陷。
- 能在没有 AI 的情况下完成一个类型安全的中等复杂组件切片。

## 4. 完整概念清单

### 4.1 响应式原理与选择

- Proxy、依赖收集、触发更新、Effect 与组件渲染 Effect。
- `ref` 与 `reactive` 的返回值、解包规则和边界；不要用风格偏好替代场景判断。
- 解构 `reactive` 导致响应式断开；`toRef`、`toRefs`、`toValue` 的用途。
- `computed` 表达可派生状态并保持纯净；避免在 getter 中发请求或修改其他状态。
- `watch` 精确观察源，`watchEffect` 自动收集；`flush` 时机、立即执行和清理过期副作用。
- 异步竞态：快速切换工单时取消旧请求或忽略过期响应。
- `shallowRef`、`markRaw`、`readonly`、`effectScope` 的适用边界；不用高级 API 炫技。
- `nextTick` 只等待 DOM 刷新，不解决任意业务竞态。

### 4.2 TypeScript 与组件契约

- `<script setup lang="ts">`、`defineProps`、默认值、`defineEmits`、`defineModel`、`defineExpose`。
- Props 只读、事件上行；避免子组件直接修改父组件对象深层字段。
- 使用字面量联合/判别联合表示状态、权限和异步结果，减少布尔变量组合爆炸。
- `unknown` 优先于 `any`，在 API 边界做运行时验证或明确转换。
- 模板引用、DOM 事件、插槽、Provide/Inject 的类型。
- DTO、ViewModel、FormModel 不强制复用；时间、枚举和可空字段要显式转换。
- `vue-tsc` 执行 SFC 类型检查；Vite 转译不等于类型检查。

### 4.3 组件与 Composable 设计

- 组件负责可视结构和交互契约；Composable 负责可复用的有状态逻辑。
- 命名以 `use` 开头，参数接受值/Ref/Getter 时用 `toValue` 归一化。
- 返回普通对象中的多个 `ref`，避免解构丢失响应式。
- 每个 Composable 写明职责、数据来源、非显然映射和重要副作用。
- 在 `onScopeDispose`/`onUnmounted` 清理定时器、事件监听、AbortController 和订阅。
- 避免“万能 `useWorkOrder`”同时管理列表、详情、表单、权限、SSE 和缓存。
- 表单草稿、服务端 DTO 与展示格式分离；派生数据不重复存入状态。

### 4.4 性能与调试

- Vue Devtools 检查组件、响应式状态和更新原因。
- 稳定 Key、列表渲染、条件渲染、组件拆分和大对象响应式成本。
- 先测量再使用 `v-memo`、浅层响应式或虚拟列表。
- 错误边界、加载/空/失败/成功状态不能只用一个 `loading` 布尔值表达。

## 5. 任务分配

| 任务 | 时间 | 结果 |
| --- | ---: | --- |
| Web基础审计 + 响应式实验 | 3h | 基线清单、薄弱项和关键响应式实验 |
| Vue + TS 组件契约练习 | 3h | 类型安全组件组 |
| Composable 设计与测试 | 3h | 两个职责单一的 Composable |
| FactoryCare UI 垂直切片 | 4h | 工单详情/状态时间线模块 |
| 无 AI 训练 | 2h | 独立组件实现 |
| 求职采样与简历复健 | 1.5h | Vue 技能证据矩阵 |

总计 16.5 小时。若有 18 小时，增加响应式性能剖析；不要提前引入多个状态管理库。

开始Vue任务前，限时完成一次Web基础审计：语义HTML/表单、CSS层叠与布局、JS闭包/原型/事件循环、DOM事件、Fetch/Abort、Cookie/CORS/CSRF、TypeScript收窄与`unknown`。通过项不复习；失败项进入本周补弱清单，并在FactoryCare组件中验证。

## 6. FactoryCare 项目增量

- 建立 `factorycare-web` 的 Vue 3 + TypeScript 基础，启用严格类型检查和统一格式/检查脚本；完整 Vite 工程化留到第 27 周深化。
- 从 API 契约定义 `WorkOrderSummary`、`WorkOrderDetail`、`WorkOrderStatus`、`PermissionCode` 等前端边界类型。
- 实现工单详情展示、状态时间线和 SLA 剩余时间组件，使用判别联合表达加载/失败/成功。
- 编写 `useSlaCountdown`：输入目标时间与暂停状态，正确清理定时器，并允许注入当前时间便于测试。
- 编写 `useAsyncTask` 或等价小型 Composable：处理取消、过期响应和错误归一化；不替代第 27 周服务端状态缓存。
- 状态映射、权限码和 SLA 颜色规则写成有意图的注释，避免 UI 中散落魔法字符串。
- 使用 Mock Repository 驱动本周切片，后端联调在第 27 周进行。
- 至少编写 6 条单元测试：时间暂停/到期、卸载清理、过期响应、错误状态、事件契约和类型边界。

## 7. AI 协作边界

AI 可以：

- 根据你的响应式解释生成反例或小型实验。
- 审查 Props/Emits/Composable API，寻找职责过多和副作用泄漏。
- 生成测试场景清单和类型收窄建议。
- 帮助把 Options API 片段解释成 Composition API，但不能只做机械翻译。

AI 不可以：

- 一次生成整页并用 `any`、深度 `watch` 或大量布尔变量掩盖设计问题。
- 擅自创建全局 Store、全局事件总线或万能请求 Composable。
- 根据后端字段名直接决定最终 UI 契约。
- 在无 AI 训练中提供实现或排错提示。

所有 AI 修改必须通过 `vue-tsc`、测试和浏览器交互验证；能运行但不能解释的响应式代码不算掌握。

## 8. 无 AI 训练

关闭 AI 120 分钟，实现“工单筛选条件”组件与`useDebouncedFilter`：

- 支持状态、关键字、仅看超时三类条件，Props/Emits 全部严格类型化。
- 关键字 300ms 防抖，组件卸载时取消定时器。
- 不重复保存可派生条件，不使用 `any` 和深度监听整个对象。
- 补重置、连续输入、卸载清理和事件载荷测试。
- 结束后口述 `computed/watch/watchEffect` 在实现中的选择。

## 9. 求职动作（恢复求职后启用）

- 采样 8 个南昌 Vue3/Java 全栈/大屏或信息化岗位，统计 TypeScript、Composition API、Pinia、Vite、Element Plus、ECharts、uni-app 要求。
- 把两年前端经验拆成证据：复杂表单、状态管理、性能、组件复用、接口联调、线上排错分别有哪些真实案例。
- 准备 5 个 Vue 面试答案：响应式解构、computed vs watch、Composable 清理、Props 单向数据流、`vue-tsc` 的必要性。
- 更新 Vue 版简历，至少完成 5 次本地或江西周边定向投递，不因学习 Java 暂停前端求职。

## 10. 本周交付物

- Vue 响应式陷阱实验和口述笔记。
- 严格类型的组件、两个 Composable 及不少于 6 条测试。
- FactoryCare 工单详情、状态时间线和 SLA 展示切片。
- 无 AI 筛选组件实现记录。
- Vue 技能证据矩阵与更新后的简历条目。

## 11. 验收标准

- 不看资料解释 `ref/reactive/computed/watch/watchEffect` 的选择和常见断链原因。
- `vue-tsc` 无错误，项目业务代码不使用未解释的 `any`。
- Composable 有单一职责、明确数据源和副作用清理，卸载后没有残留定时器/请求。
- 工单详情能完整显示加载、空、错误、成功和 SLA 到期状态。
- 测试关注公开行为，不依赖私有实现细节。
- 无 AI 在120分钟内完成组件并通过测试，能够逐段解释响应式依赖。
- 简历只陈述真实 Vue 经验和本周可验证增量，不把复健项目写成商业年限。

## 12. 明确不做

- 不重新观看整套 HTML/CSS/JavaScript 入门课，不做 Todo List；只对基线失败项定向补强。
- 不引入 Vuex、多个 UI 库或复杂微前端。
- 不把所有状态塞进 Pinia；Pinia 与服务端状态在第 27 周明确边界。
- 不使用深度监听和 `any` 作为默认解法。
- 不为了“高级”使用 Render Function、TSX、复杂自定义响应式或编译器插件。

## 13. 官方资料

- [Vue 响应式基础](https://vuejs.org/guide/essentials/reactivity-fundamentals.html)
- [Vue Reactivity in Depth](https://vuejs.org/guide/extras/reactivity-in-depth.html)
- [Vue Watchers](https://vuejs.org/guide/essentials/watchers.html)
- [Vue Composables](https://vuejs.org/guide/reusability/composables.html)
- [Vue + TypeScript](https://vuejs.org/guide/typescript/overview.html)
- [TypeScript with Composition API](https://vuejs.org/guide/typescript/composition-api.html)
- [Vue 性能最佳实践](https://vuejs.org/guide/best-practices/performance.html)
