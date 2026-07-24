---
schema_version: 2
edition: 2026.2-draft
id: ch.vue.composables-di
title: Composable、依赖注入与模块边界
responsibility: 把可复用状态和副作用封装为具有所有权/清理合同的 Composable，并在确有跨层依赖时使用 provide/inject，不创建隐式全局单例。
volume: '09'
order: 7
level: L2+
status: drafting
path: book/volume-09-vue-nuxt/chapters/ch.vue.composables-di.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.vue.components-contracts
version_surfaces:
- vue-3
- vite
- typescript
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“Composable、依赖注入与模块边界”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - vue-composable-contract
  - vue-provide-inject
  covers_topics:
  - vue.composable-naming
  - vue.composable-input-output
  - vue.composable-effect-cleanup
  - vue.composable-instance-scope
  - vue.provide-inject
  - vue.injection-key
  - vue.readonly-injection
  - vue.dependency-boundary
  uses_capabilities:
  - web.vue-reactivity-lifecycle
  - web.vue-components-contracts
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“Composable、依赖注入与模块边界”构建可运行程序与测试：提取一个可注入 repository 的工单查询 Composable 并证明多实例隔离；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - vue-composable-contract
  - vue-provide-inject
  covers_topics:
  - vue.composable-naming
  - vue.composable-input-output
  - vue.composable-effect-cleanup
  - vue.composable-instance-scope
  - vue.provide-inject
  - vue.injection-key
  - vue.readonly-injection
  - vue.dependency-boundary
  uses_capabilities:
  - web.vue-reactivity-lifecycle
  - web.vue-components-contracts
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: multi-instance-check-cleanup-trace-dependency-substitution
- id: diagnose
  kind: fault-diagnosis
  text: 面对“模块级共享 ref、遗漏清理或字符串注入键冲突导致的状态串扰”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - vue-composable-contract
  - vue-provide-inject
  covers_topics:
  - vue.composable-naming
  - vue.composable-input-output
  - vue.composable-effect-cleanup
  - vue.composable-instance-scope
  - vue.provide-inject
  - vue.injection-key
  - vue.readonly-injection
  - vue.dependency-boundary
  uses_capabilities:
  - web.vue-reactivity-lifecycle
  - web.vue-components-contracts
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Composable、依赖注入与模块边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Props、事件、Slot 与组件 v-model》](ch.vue.components-contracts.md)：需要先区分显式 Props/emit 合同与跨层注入的适用范围。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文与工件可供学习和作者自检，但不能证明学习者已经完成无 AI 独立构建、限时复述或故障诊断，也不会自动更新 `PROGRESS.md`。

组件变短不等于逻辑已经有边界。把请求、筛选状态和事件监听从组件复制进 `helpers.ts`，若调用者仍共享模块级 `ref`、不知道谁终止请求、直接依赖一个具体 HTTP 客户端，那只是移动了代码。Composable 的价值是给一组有状态逻辑命名，并把输入、输出、所有权、生命周期和失败语义变成可观察合同。

FactoryCare 的工单查询会同时出现在工作台、设备详情侧栏和派工页。三个界面可以复用查询规则，却不应默认共享当前筛选、加载状态和错误。每个组件调用 `useWorkOrderQuery()` 都应获得自己的状态；一次筛选变化要使该实例旧请求失效；组件卸载时其在途请求归零。repository 是跨越页面层级的基础设施依赖，组合根可用 `provide` 安装，深层消费者用 typed `InjectionKey` 获取；测试可以替换 fake，而不修改消费者合同。

本章只讨论 Composable 合同、provide/inject 和依赖边界。不引入 Pinia、Router、Nuxt plugin、真实 HTTP、缓存去重、服务端授权或跨标签页同步。真正需要全局共享的客户端状态留给状态管理章节；服务器状态一致性、鉴权和审计仍由服务端负责。官方资料复核日为 **2026-07-17**。

## 1. 完成标准：三个 oracle，而不是“抽出来了”

本章的核心验收句是：**两个组件实例的 Composable 状态互不污染，卸载时副作用归零，替换注入实现后消费者合同不变。** 它被拆成三种证据：

| oracle | 输入 | 必须观察的结果 | 不能替代它的弱证据 |
|---|---|---|---|
| multi-instance-check | 同一页面挂载两个查询面板，只改变左侧状态 | 左侧变更，右侧仍保持原值；两者 ref 身份不同 | “页面上目前只有一个实例” |
| cleanup-trace | 请求未完成时改筛选，再卸载组件 | 旧请求收到 abort；卸载后 repository 活跃调用为 0 | 只断言 loading 变成 false |
| dependency-substitution | 用 repository A、B 分别挂载同一消费者 | Props、命令、DOM 选择器和返回形状不变；调用都经过端口 | 在测试里 mock 整个组件 |

需要完成三个 outcome：

- 在 120 秒内说明 Composable 与普通纯函数、组件、store 的区别，解释 per-call state、清理和 DI 的边界，并举出不应靠客户端注入解决的反例，如服务端权限。
- 从空目录独立构建可注入 repository 的工单查询 Composable，保存版本、命令、测试、构建和三种 oracle 结果。
- 注入模块级共享 ref、遗漏清理或字符串 key 冲突，先指出第一可信证据，再修复并重跑原 oracle，记录残余风险。

配套工件：

- [Composable 合同观察例](../../../examples/encyclopedia/ch.vue.composables-di/README.md)
- [FactoryCare Composable / DI 故障实验](../../../labs/encyclopedia/ch.vue.composables-di/README.md)
- [公开 Composable 所有权红灯练习](../../../exercises/encyclopedia/ch.vue.composables-di/README.md)

公开练习初始红灯是课程设计，不是仓库损坏。修改检查器、删除清理断言、把状态污染隐藏到另一个模块或复制私有目录，都不能构成通过证据。

## 2. 什么是 Composable，什么不是

Vue 官方把 Composable 定义为利用 Composition API 封装和复用**有状态逻辑**的函数。按约定使用 camelCase 且以 `use` 开头，例如 `useWorkOrderQuery`。名字不仅为了风格统一：调用点一眼能判断它可能创建 reactive effect、注册生命周期或返回 refs，因此需要问“谁拥有它”。

以下三个函数责任不同：

```ts
function formatStatus(status: WorkOrderStatus): string // 纯变换，无 reactive owner
function useWorkOrderQuery(repository: WorkOrderRepository) // 有状态逻辑
function WorkOrderQueryPanel() // 视觉、交互和可访问组件边界
```

纯函数接收值并立即返回值，不需要 Vue 活跃实例。Composable 可以创建 ref、computed、watch 和生命周期副作用。组件负责 DOM、Props、emit、Slot 与交互语义。不要为每个三行纯函数加 `use`，也不要让 Composable 返回大段渲染结构；来源越清晰，调用者越容易追踪。

Composable 不是 Vue 版“万能 service locator”。把所有 API、toast、router、用户、配置都藏在一次 `useEverything()` 里，会使依赖不可见、测试需要搭完整应用、模块无法独立替换。它也不是自动单例：官方文档明确说明，每个组件实例调用 Composable 会获得自己的状态副本；若要共享状态，应有意选择状态管理，而不是意外把 ref 放到模块顶层。

## 3. 输入合同：让依赖和响应性可读

Composable 的输入可以是普通值、ref 或 getter。若输入只在调用时读取一次，应明确写成值；若调用后要跟踪变化，应接收 `MaybeRefOrGetter<T>`，在 watcher 内用 `toValue()` 归一化，确保依赖读取发生在响应式追踪上下文中。不要“顺便支持一切”而不写语义：调用者必须知道传入普通字符串后不会自动变化，传入 getter 时会触发重新查询。

```ts
type QueryInput = MaybeRefOrGetter<WorkOrderStatus>

export function useWorkOrderQuery(
  repository: WorkOrderRepository,
  input: QueryInput,
) {
  watchEffect((onCleanup) => {
    const status = toValue(input)
    // status 的 ref/getter 依赖在 effect 内被追踪
  })
}
```

本章工件选择另一种可控合同：初始状态是普通值，随后由返回的 `setStatus` 命令修改内部状态。这让状态所有权和写入口更明显，也便于用 readonly 输出阻止消费者直接改写。两种设计都可以，关键是不要一边返回可写 ref，一边宣称只有 composable 能维持不变量。

repository 作为第一个参数比在函数内部硬编码 `fetch` 更容易测试。组件若跨越多层布局获取 repository，可以在调用 Composable 前 inject；纯逻辑本身仍可显式接收端口：

```ts
const repository = requireWorkOrderRepository()
const query = useWorkOrderQuery(repository, 'CREATED')
```

这种“边界处 inject、核心处显式参数”的组合使依赖来源可见。直接在 Composable 里 inject 也能工作，但它把有效调用上下文限制在带 provider 的组件树；若选择它，要在名字、错误和测试夹具中写清约束。

## 4. 输出合同：普通对象中的 refs 与命令

官方推荐 Composable 返回一个普通、非 reactive 对象，其中包含多个 refs。这样解构后响应性仍然保留：

```ts
const { status, orders, loading, error, setStatus, reload } =
  useWorkOrderQuery(repository)
```

若直接返回 `reactive({ ... })`，调用者解构普通属性可能失去响应连接。若调用者偏好 `query.status` 风格，可以不解构，或在外部用 `reactive(useX())` 进行 ref 解包；不要让 API 的响应行为依赖调用者猜测。

输出应最小化：

- `status`、`orders`、`loading`、`error` 是可观察状态；
- `setStatus` 和 `reload` 是显式写命令；
- AbortController、watch stop handle、generation id 和原始 repository 不属于消费者合同；
- 不返回“为了测试方便”的内部可写 ref，测试应观察公开结果与资源 trace。

对由 Composable 拥有的状态使用 `readonly()`：

```ts
return {
  status: readonly(status),
  orders: readonly(orders),
  loading: readonly(loading),
  error: readonly(error),
  setStatus,
  reload,
}
```

`readonly` 是运行时开发提示和 API 约束，不是安全边界；恶意脚本、外部 JSON 和服务端请求仍需各自校验。它的主要作用是让合法调用路径只有命令，状态转换规则可以集中测试。

## 5. 实例作用域：ref 放在哪里决定所有权

最危险且最隐蔽的错误，是把“整理到文件顶部”误当普通重构：

```ts
// 错误：模块加载一次，全应用调用者共享同一个 ref
const status = ref<WorkOrderStatus>('CREATED')

export function useWorkOrderQuery() {
  return { status }
}
```

两个面板会返回同一 ref 身份。左侧把状态改成 `RESOLVED`，右侧立即变化，即使产品从未定义共享筛选。这就是 `implicit-global-state`：它可能在单实例测试里全绿，只有同时挂载两个消费者才暴露。

正确的 per-call state 在函数体内创建：

```ts
export function useWorkOrderQuery(repository: WorkOrderRepository) {
  const status = ref<WorkOrderStatus>('CREATED')
  const orders = shallowRef<readonly WorkOrderSummary[]>([])
  // 每次调用拥有新的 refs 和新的 watcher
}
```

`shallowRef` 适合这里的不可变结果数组：替换整个列表会触发更新，内部工单视为只读快照。若业务需要逐项可变对象，应先明确谁拥有 mutation，不能只靠换一个响应式 API 掩盖所有权。

“模块级状态一定错误”也不是绝对规则。若产品明确要求所有页面共享一个会话状态，可以有意创建单例 store；但必须命名、记录初始化/重置、测试隔离和 SSR 请求隔离。未经声明的模块 ref 才是本章禁止的隐式全局。

## 6. 副作用合同：每次启动都要能指出终止路径

查询不是赋值，而是有时长的副作用。筛选从 `CREATED` 变为 `IN_PROGRESS` 时，旧请求若继续完成，可能晚到并覆盖新结果；组件卸载后继续占用网络、timer 或 listener，则产生资源泄漏。设计时为每个 effect 写资源账本：

| 启动 | 资源所有者 | 无效化条件 | cleanup | 可观察证据 |
|---|---|---|---|---|
| repository.search | 当前 watcher run | status/revision 改变、scope stop | `controller.abort()` | signal.aborted、active=0 |
| window listener | 调用该 composable 的组件 | unmount | removeEventListener | add/remove 对称 |
| interval | 当前 scope | stop/unmount | clearInterval | timer 数归零 |

watch 回调提供 `onCleanup`，清理在下一轮执行前或 watcher 停止时运行：

```ts
const stop = watch([status, revision], async ([next], _, onCleanup) => {
  const controller = new AbortController()
  onCleanup(() => controller.abort())
  const result = await repository.search(next, controller.signal)
  orders.value = result
}, { immediate: true })

onScopeDispose(stop)
```

同步创建的 watcher 本来会绑定当前组件/effect scope，scope 停止时自动处理；显式保存 stop 并登记 `onScopeDispose` 是为了让资源所有权在教学代码中可见。真正关键的是每轮请求的 `onCleanup`。如果 watcher 在异步回调之后才创建，它可能无法自动绑定原组件，需要手动停止；因此 Composable 通常必须在 `<script setup>` 或 `setup()` 中同步调用。

### 6.1 abort 不是 error UI

用户改筛选触发 abort 是正常控制流，不应显示“查询失败”。catch 需要区分 `AbortError` 与真实错误。与此同时，不能用 `catch {}` 吞掉所有异常；网络、解析和仓储错误应映射到 `error` 输出。finally 也要防旧请求关闭新请求的 loading。

### 6.2 generation 防迟到写入

并非所有 repository 都可靠响应 AbortSignal。为防旧 promise 晚到，可给每轮递增 `generation`，只有当前代写入状态：

```ts
const mine = ++generation
const result = await repository.search(next, signal)
if (mine === generation) orders.value = result
```

AbortController 负责释放可取消资源，generation 负责结果顺序；二者职责不同。只加 generation 会让旧请求继续耗资源，只加 abort 又依赖底层实现正确响应信号。

## 7. provide/inject 解决什么问题

Props/emit 是显式组件合同，默认优先使用。当一个稳定依赖必须穿过多层布局，而中间组件既不读取也不改变它时，层层声明 props 会制造无意义耦合，provide/inject 可以让祖先向任意后代提供依赖。常见候选是 repository 端口、表单上下文、主题或组件库内部协作。

不该因为“少写几行”就注入所有业务数据。判断顺序：

1. 直接父子或只有一两层：Props/emit 最清楚；
2. 多个不相关页面真正共享可变客户端状态：使用明确 store；
3. 跨越深层 UI 且属于同一子树的稳定依赖：考虑 provide/inject；
4. 纯函数依赖：优先参数；
5. 服务端权限、租户隔离或数据授权：必须在服务端执行，客户端 DI 不可信。

provider 有层级规则：同一个 key 被多个祖先提供时，inject 选择最近的祖先。这能支持局部覆盖，例如测试/预览子树替换 repository，也意味着错误的同名字符串可能静默遮蔽外层值。依赖替换应是有意的组合根行为，而不是组件树任意节点偷偷重新 provide。

## 8. InjectionKey：用身份与类型保护端口

字符串 key 在小 demo 可用，在大应用易碰撞：两个团队都写 `'service'`，最近 provider 的值可能形状完全不同。使用 `Symbol` 保证身份唯一；TypeScript 的 `InjectionKey<T>` 把 provider 与 injector 的值类型关联：

```ts
export const workOrderRepositoryKey: InjectionKey<WorkOrderRepository> =
  Symbol('factorycare.work-order-repository')
```

Symbol 的 description 只用于调试，不参与相等判断。即使两个 Symbol 都描述为 `factorycare.service`，它们仍不相等；这正是实验中 repository key 与 audit sink key 的证据。

集中导出 key，而不是 provider 与 consumer 各自 `Symbol()`。后者虽然描述相同，却永远匹配不到。可以封装安装/必需读取函数：

```ts
export function provideWorkOrderRepository(repository: WorkOrderRepository) {
  provide(workOrderRepositoryKey, repository)
}

export function requireWorkOrderRepository() {
  const repository = inject(workOrderRepositoryKey)
  if (!repository) throw new Error('WorkOrderRepository provider is required')
  return repository
}
```

缺省值必须是产品决定。基础设施 repository 缺失通常应尽早报错；静默创建真实 HTTP client 会让测试意外访问网络。真正可选的依赖可以给 default；创建昂贵默认值时按官方 API 使用 factory 参数，避免 provider 已存在仍执行副作用。

## 9. readonly 注入与 mutation 共置

若 provider 提供 reactive state，官方建议 mutation 尽量留在 provider，并提供修改函数；必要时用 `readonly()` 包裹注入值。消费者得到观察能力和命令，而不是任意写能力：

```ts
const currentSiteId = ref('SITE-NC-01')

provide(siteContextKey, {
  currentSiteId: readonly(currentSiteId),
  selectSite(next: string) { currentSiteId.value = next },
})
```

这样可以集中校验站点是否存在、记录审计和取消旧查询。若直接 provide 可写 ref，任意后代都能绕过规则。注意 readonly 仍不是授权：用户可以篡改浏览器内存，后端必须按会话、租户和资源重新校验。

repository 本身通常不是 reactive state，而是不可变端口对象。无需为了“响应式”把它包进 `reactive()`；若运行时要切换实现，必须明确切换时已存在消费者如何更新、旧资源如何释放。大多数应用在 composition root 固定一次实现，简单且可预测。

## 10. 模块边界：依赖方向指向端口

建议把工单查询拆成四层：

```text
WorkOrderQueryPanel.vue
  ├─ requireWorkOrderRepository()  ← UI 组合边界
  └─ useWorkOrderQuery(port)        ← 状态/副作用所有者
          ↓
  WorkOrderRepository interface     ← 稳定端口
          ↑
  HttpRepository / FakeRepository   ← 可替换实现
```

消费者不 import `axiosInstance`、环境变量或 fake。HTTP 实现负责 URL、序列化、状态码和 AbortSignal 传递；Composable 负责当前筛选、加载/error 与迟到结果；组件负责可访问 label、按钮和渲染。端口方法返回领域需要的最小只读数据，不能把 HTTP response、headers 和客户端异常类型泄漏到所有 UI。

依赖倒置不是“接口越多越好”。若一个函数只有一次纯计算，直接参数即可。对 repository 建端口的理由是它跨越 I/O 边界、需要替换、存在取消语义且影响多处消费者。接口应由消费者需要塑形，而不是把后端 SDK 全部方法复制一遍。

## 11. 多实例、清理和替换的测试设计

### 11.1 多实例矩阵

同时挂载两个真实消费者，而不是分别创建后比较快照：

1. 两个面板初始 `CREATED`；
2. 左侧 select 改为 `RESOLVED`；
3. 左侧 DOM 为 `RESOLVED`，右侧仍为 `CREATED`；
4. repository trace 出现左侧新查询，右侧没有隐式状态变化；
5. ref 身份不同。

若测试只挂一个组件，模块级 singleton 会被漏掉。若只比较 DOM，而两个面板恰好渲染相同值，也可能假绿；因此需要身份、状态和调用 trace 的联合证据。

### 11.2 受控 repository

fake 应保存每次 status、signal、resolve handle 和活跃计数。它不是在复制生产实现，而是在提供可控时序：旧请求保持 pending，改变筛选后断言 signal.aborted，再卸载并断言 active=0。即时 `Promise.resolve` fake 无法稳定证明清理，因为请求在断言前已经结束。

### 11.3 依赖替换

分别用返回一条记录和空列表的两个 repository 挂载同一组件。断言两者都按同一 status 调用、组件 Props/标题/选择器一致、返回对象 keys 一致。不要在组件里写 `if (import.meta.env.MODE === 'test')`，那会污染消费者合同。

### 11.4 readonly 与负例

可以用 `isReadonly` 断言公开 refs。不要依赖生产构建是否打印 warning 作为唯一 oracle；更稳的证据是 API 类型/结构、命令后的合法变化以及没有直接写入口。缺 provider 测试应在消费者边界快速失败，错误指出缺哪个端口。

## 12. 三类故障如何找到第一可信证据

### 12.1 模块级共享 ref

症状：改左侧筛选，右侧也改变。第一可信证据不是“Vue 响应式有 bug”，而是两次调用返回的 `status` 是同一对象，且声明位于函数外。修复：把可变 refs 移入函数；重跑同时挂载矩阵。残余风险：若其他模块仍缓存返回对象，仍可能形成有意或无意共享，需要搜索组合根。

### 12.2 遗漏清理

症状：卸载后请求/订阅仍活跃，或旧结果覆盖新状态。第一可信证据是 scope stop 后 active count 仍为 1，或者旧 signal 未 aborted；loading 文字消失不是资源证据。修复：在 effect 创建点登记对称 cleanup、向 repository 传 signal、必要时加 generation。重跑同一时序。残余风险：真实 HTTP adapter 可能忽略 signal，必须在集成层再验证。

### 12.3 字符串注入 key 冲突

症状：consumer 收到错误形状，或局部 provider 让外层依赖静默失效。第一可信证据是两个逻辑端口的 key 严格相等，且最近 provider 解析到错误值。修复：共享模块导出两个 `InjectionKey<T>` Symbol；重跑 provider 替换。残余风险：如果 provider 与 consumer 各自创建 Symbol，会从“碰撞”变成“永远不匹配”，仍需集中 key。

诊断报告使用固定格式：

```text
场景：两个面板同时挂载，左侧改 RESOLVED
期望：left=RESOLVED，right=CREATED
实际：两者均 RESOLVED
第一可信证据：left.status === right.status 为 true
根因：status ref 声明在模块作用域
修复：ref 移入 useWorkOrderQuery 函数体
重跑：同一 multi-instance-check 通过
残余风险：未在真实浏览器验证网络 adapter 的 AbortSignal
```

## 13. SSR、浏览器与服务端边界

官方提醒：Composable 中的 DOM 副作用应放在 `onMounted`，并在卸载时移除，以免 SSR 环境访问 `window`。本章查询逻辑使用 AbortController，但配套测试运行在 happy-dom，不能证明 Nuxt SSR 请求隔离、hydration 或所有目标浏览器的卸载行为。

模块级 singleton 在 SSR 更危险：若服务器进程复用模块，不同请求可能共享用户状态。正确方向是每个请求创建应用/注入上下文，避免用户相关可变状态落在进程级模块顶层。本章不实现 Nuxt plugin 或 server rendering，只把它列为后续必须验证的风险。

DI 也不能替代安全。客户端 provider 可以替换、删除和篡改；repository 接口可以被恶意脚本直接调用。服务器仍必须认证调用者、校验租户/资源权限、限制字段并写审计。前端 readonly 只保护协作代码的意图。

## 14. 独立实验步骤与证据包

在空目录重建时保存：

1. `node --version`、`pnpm --version` 与精确依赖版本；
2. `WorkOrderRepository`、typed key、Composable 和两个消费者；
3. 受控 repository 的 requests/trace/active count；
4. 初始绿灯：隔离、cleanup、substitution；
5. 逐个注入三类 fault，每次只改变一个变量；
6. 失败输出、第一证据、修复 diff、同一命令重跑；
7. `vite build` 输出；
8. 未验证项和残余风险。

配套命令：

```bash
cd examples/encyclopedia/ch.vue.composables-di && ./verify.sh
cd labs/encyclopedia/ch.vue.composables-di && ./verify.sh
cd exercises/encyclopedia/ch.vue.composables-di && ./verify.sh   # 初始应红
```

示例与实验的 verifier 会离线安装锁定依赖、执行 Vitest、构建 Vite，并在退出时清理 `node_modules` 和输出目录。公开练习是静态小 oracle，刻意不安装依赖；私有目录只供作者确认同一判据存在可行绿灯。

## 15. 120 秒复述模板

可以按“职责—边界—证据—反例”组织：

> Composable 是用 Composition API 封装有状态逻辑的 `useX` 函数。每次调用默认拥有自己的 refs；返回普通对象中的 readonly refs 和显式命令。它创建的 watcher、请求、listener 必须有同一所有者的 cleanup，异步查询同时用 AbortSignal 和代次防资源泄漏与迟到覆盖。provide/inject 用于跨越无关中间层的稳定依赖，直接父子仍优先 Props/emit；大型应用用共享 typed Symbol InjectionKey 防字符串碰撞，并把 mutation 留在 provider。证据是两个实例不串扰、卸载活跃资源为零、替换 repository 后消费者合同不变。它不解决服务器授权，客户端 provider 可被篡改。

若超时，优先保留三种 oracle 和反例；若只背 API 名而无法说明资源所有者、清理时机与替换证据，不算完成。

## 16. 自检问题

1. 为什么把 ref 移到单独文件顶部可能从局部状态变成隐式全局？
2. 普通对象包含 refs 为什么比直接返回 reactive 对象更适合解构？
3. `onCleanup`、`onScopeDispose` 与 `onUnmounted` 分别对应哪种所有权？
4. AbortController 与 generation 各防什么问题？为什么不能互相完全替代？
5. 哪些依赖适合 Props，哪些适合 provide/inject，哪些应进入 store？
6. 两个描述相同的 Symbol 为什么不冲突？provider 和 consumer 各建一个 Symbol 又为什么失败？
7. 为什么 readonly 注入不是服务端授权？
8. 如何构造一个不会瞬间完成、能证明 cleanup 的 fake repository？
9. 如何证明替换实现后消费者合同不变，而不只证明代码能编译？
10. 若真实 HTTP adapter 不响应 signal，本章哪项风险仍未关闭？

## 17. 有意非目标与兼容性说明

本章没有实现 Pinia 全局状态、查询缓存/去重、Nuxt 注入、SSR、真实 HTTP adapter、重试退避、离线恢复、服务端权限或端到端浏览器测试。没有为了兼容旧字符串 key 保留双 key 查找；长期可维护性优先，迁移时应由组合根一次切换到 typed Symbol。没有提供 Vue 2 mixin 兼容层；官方仍保留 mixin 主要为迁移/熟悉，而 Vue 3 新逻辑采用 Composable。

示例固定 Vue `3.5.35`、Vite `7.3.1`、TypeScript `5.9.3`、Vitest `4.0.18` 和 pnpm `10.18.0`，这是可复现教学基线，不代表所有更新版本已经验证。happy-dom 中的成功不等于真实 Chromium/WebKit、网络栈、页面刷新或 SSR 成功。

## 18. 官方资料

- [Vue：Composables](https://vuejs.org/guide/reusability/composables.html)
- [Vue：Provide / Inject](https://vuejs.org/guide/components/provide-inject.html)
- [Vue：TypeScript 与 Composition API（InjectionKey）](https://vuejs.org/guide/typescript/composition-api.html#typing-provide-inject)
- [Vue API：Composition API Dependency Injection](https://vuejs.org/api/composition-api-dependency-injection.html)
- [Vue API：Reactivity Core](https://vuejs.org/api/reactivity-core.html)
- [Vue API：Reactivity Utilities](https://vuejs.org/api/reactivity-utilities.html)
