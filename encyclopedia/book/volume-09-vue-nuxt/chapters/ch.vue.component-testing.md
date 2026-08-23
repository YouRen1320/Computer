---
schema_version: 2
edition: 2026.2-draft
id: ch.vue.component-testing
title: 组件测试、Mock、异步断言与端到端边界
responsibility: 用组件测试验证渲染、事件与异步状态，用少量浏览器端到端测试覆盖关键用户路径，明确 Mock、组件和 E2E 各自证据边界。
volume: '09'
order: 12
level: L2+
status: drafting
path: book/volume-09-vue-nuxt/chapters/ch.vue.component-testing.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.vue.server-state
version_surfaces:
- vue-3
- vitest
- playwright
- vite
- typescript
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“组件测试、Mock、异步断言与端到端边界”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - vue-component-test
  - vue-e2e-boundary
  covers_topics:
  - vue.component-mount
  - vue.component-query-action
  - vue.emitted-event-assertion
  - vue.flush-promises
  - vue.mock-boundary
  - web.e2e-user-path
  - web.role-based-locator
  - web.network-stub-boundary
  - web.flake-control
  - web.test-pyramid
  uses_capabilities:
  - web.javascript-testing-debugging
  - web.vue-components-contracts
  - web.javascript-network-race
  - web.component-e2e-testing
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为工单筛选与详情组件编写组件测试，并用浏览器覆盖登录到打开工单的关键路径；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - vue-component-test
  - vue-e2e-boundary
  covers_topics:
  - vue.component-mount
  - vue.component-query-action
  - vue.emitted-event-assertion
  - vue.flush-promises
  - vue.mock-boundary
  - web.e2e-user-path
  - web.role-based-locator
  - web.network-stub-boundary
  - web.flake-control
  - web.test-pyramid
  uses_capabilities:
  - web.javascript-testing-debugging
  - web.vue-components-contracts
  - web.javascript-network-race
  - web.component-e2e-testing
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: vitest-component-browser-e2e-network-fault-injection
- id: diagnose
  kind: fault-diagnosis
  text: 面对“只断言实现细节、未等待异步、过度 Mock 或脆弱选择器造成的假通过与抖动”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - vue-component-test
  - vue-e2e-boundary
  covers_topics:
  - vue.component-mount
  - vue.component-query-action
  - vue.emitted-event-assertion
  - vue.flush-promises
  - vue.mock-boundary
  - web.e2e-user-path
  - web.role-based-locator
  - web.network-stub-boundary
  - web.flake-control
  - web.test-pyramid
  uses_capabilities:
  - web.javascript-testing-debugging
  - web.vue-components-contracts
  - web.javascript-network-race
  - web.component-e2e-testing
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 组件测试、Mock、异步断言与端到端边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《服务端状态、加载、错误、取消与竞态》](ch.vue.server-state.md)：异步断言需要覆盖加载、错误、取消和竞态，而非只测静态渲染。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 **drafting**。正文、Vitest 工件、Vite 构建和 Playwright 规格可用于学习与作者自检，但不能证明学习者已经无 AI 独立完成，也不能把 happy-dom 或静态规格检查当成真实浏览器结果。官方 Vue、Vue Test Utils、Vitest 与 Playwright 文档复核日为 **2026-07-17**。本轮没有安装或启动 Playwright 浏览器，因此登录到打开工单的真实浏览器路径明确为 **UNVERIFIED**，也不修改 `PROGRESS.md`。

组件测试的价值不是“Vue 文件能 mount”，而是用较低成本证明一个组件向用户和父组件承诺的行为：给定 props 与边界响应，它渲染什么可见状态；用户通过什么可访问控件行动；组件发出什么最小事件；异步完成、失败、重试与乱序时，公共结果是否稳定。E2E 则在真实浏览器中证明少量跨层关键路径，例如登录、加载工单、打开详情。两者不是高低级替代关系，而是回答不同问题。

本章建立一个证据纪律：**先写风险与公共合同，再选择能观察该合同的最低测试层；Mock 只替换真正的外部边界；每个异步断言明确等待谁；关键路径再交给真实浏览器。** 反例：后端是否正确执行工单权限、事务与并发控制，不应由 Vue 组件测试解决；即便前端把 `/api/work-orders` Mock 成 200，也没有证明生产 API 正确。

## 1. 完成标准、范围与四个入口

canonical oracle 是：**组件正常、边界、错误测试与一条真实浏览器关键路径可重复通过；故意改坏事件或竞态防护时，在相应层以明确断言失败，而不是随机超时或假通过。** 完成本章应能做到：

1. 从用户可见 DOM、可访问名称和 emitted event 描述组件公共合同，而不是读取私有 ref、computed 或子组件实例；
2. 区分 Vue DOM 更新与外部 Promise 两套调度，知道何时等待 `trigger`、`setValue`、`nextTick`、`flushPromises`；
3. 对加载、成功、空、错误、重试、事件载荷和陈旧响应至少各有可判定断言；
4. 只 Mock 网络/存储/时钟等边界，保留被测组件、关键子组件和状态转换为真实代码；
5. 用受控 Promise 决定竞态完成顺序，不以随机延迟期待偶然复现；
6. 在 E2E 中从用户入口开始，使用 role、label、text 等面向用户的定位器，并让每个测试隔离状态；
7. 明确网络 stub 证明的是前端消费合同，不是后端实现；至少保留一条适合在集成环境跑真实后端的路径；
8. 注入实现细节断言、漏等待、过度 Mock 与脆弱选择器，保存首个可信失败、修复和同一命令重跑；
9. 分别报告组件绿灯、静态 E2E 规格检查、真实浏览器结果，绝不把前两者合并成“E2E 已通过”。

配套入口：

- [可执行组件测试与待执行浏览器规格](../../../examples/encyclopedia/ch.vue.component-testing/README.md)
- [四类故障注入实验](../../../labs/encyclopedia/ch.vue.component-testing/README.md)
- [公开红灯：把实现细节改成公共合同](../../../exercises/encyclopedia/ch.vue.component-testing/README.md)
- [私有参考解答](../../../solutions-private/encyclopedia/ch.vue.component-testing/README.md)

本章不建立全仓测试框架、不决定 CI 并行拓扑、不测试后端业务正确性、不替代视觉回归、性能追踪、安全渗透或真实辅助技术检查。配套 E2E 文件是可审阅规格；必须在已安装对应浏览器的环境运行 `pnpm exec playwright test`，保存版本、base URL、trace、截图/录像策略与结果，才构成浏览器证据。

## 2. 先写风险矩阵，再决定测试层

“给每个组件写测试”会制造大量低价值断言。先从失败后果与可观察边界出发：

| 风险 | 最低可信层 | 主要输入 | 关键断言 | 该层不能证明 |
|---|---|---|---|---|
| 状态选择发错事件 | 组件 | prop、select action | emitted 名称与载荷 | 父页面最终导航 |
| 加载/错误/空状态错乱 | 组件 | gateway 结果 | role/status/alert/empty DOM | 真实网络可达性 |
| 旧响应覆盖新筛选 | 组件 | 两个受控 Promise | 新结果保持、旧结果不出现 | 浏览器 Fetch 的传输取消 |
| 登录后工单入口断裂 | E2E | 页面与会话 | 用户可见关键路径 | 后端权限规则全部正确 |
| CSS 改动使第 3 个按钮换位 | 不应依赖位置 | 可访问名称 | role/name 定位仍稳定 | 视觉符合设计稿 |
| API 字段变更 | 合同/集成测试 | 真实或契约响应 | schema/映射 | Vue 内部 ref 名称 |

最低可信层不是“越低越好”。若风险是“父组件收到 `{ workOrderId }` 后打开详情”，组件测试可以验证事件，页面级组件测试可以验证组合；若风险是“登录 cookie、路由守卫、浏览器导航和请求共同工作”，就必须是 E2E。反过来，用 E2E 穷举每个错误分支成本高、诊断慢，应把纯视图分支下沉到组件层。

测试金字塔在这里不是固定比例，而是反馈结构：大量快速的纯函数/组件合同，少量组合或集成证据，更少但不可缺的浏览器关键路径。若 UI 风险集中在浏览器布局、焦点或原生 API，形状可以变宽；关键是每条测试都有明确风险，而不是追求数量或覆盖率数字。

## 3. Mount 是建立测试边界，不是完成测试

`mount(Component, options)` 创建真实 Vue 组件实例并渲染 DOM。`shallowMount` 或全量 stub 子组件会缩小边界，但也会删除集成行为。选择时问：“这个子组件的行为是否属于我要证明的合同？” 工单筛选和查询组合中，select 的 `v-model` 事件驱动请求，这是关键路径，应保留真实筛选组件。图标或昂贵且无关的门户可以 stub，但要记录删除了什么证据。

```ts
import { flushPromises, mount } from '@vue/test-utils'
import { expect, it, vi } from 'vitest'
import WorkOrderSearch from './WorkOrderSearch.vue'

it('从加载状态进入可见结果', async () => {
  // Data source: only the gateway boundary is replaced; the Vue state/view pipeline remains real.
  const list = vi.fn().mockResolvedValue([
    { id: 'WO-5001', title: '主轴振动复核', status: 'CREATED' },
  ])
  const wrapper = mount(WorkOrderSearch, { props: { gateway: { list } } })

  expect(wrapper.get('[role="status"]').text()).toBe('正在查询工单')
  await flushPromises()
  expect(wrapper.get('[aria-label="工单结果"]').text()).toContain('WO-5001')
  expect(list).toHaveBeenCalledWith('CREATED', expect.any(AbortSignal))
})
```

这个测试建立三段证据链：初始 DOM 证明 loading；gateway 调用证明输入映射；Promise 排空后的 DOM 证明结果提交。它没有断言 `wrapper.vm.loading`、内部 watcher 数量或某个 ref 名字。重构内部状态机而公共行为不变时，测试应继续通过。

`mount` 选项也属于可复现输入，应保存 global plugins、provide、route、Pinia 实例、时区、locale 与 feature flag。若测试在共享单例 store 上运行，前一个测试可能污染下一个。每个 case 创建新 wrapper、新 gateway、新 store，并在需要时 unmount，才有隔离证据。

## 4. Query、Action、Assertion 以用户语言连接

组件测试最稳定的形状是 query → action → assertion。Query 优先选择可访问语义或稳定业务标识：label 对应的输入、role 对应的 alert/status、可见按钮文本；当 happy-dom 查询能力有限时可用明确的 `data-testid` 表示无语义业务节点，但不能让它代替正确标签。

```ts
it('状态操作映射为新的查询输入', async () => {
  const list = vi.fn().mockResolvedValue([])
  const wrapper = mount(WorkOrderSearch, { props: { gateway: { list } } })
  await flushPromises()

  await wrapper.get('select').setValue('IN_PROGRESS')
  await flushPromises()

  // Mapping: one visible option value becomes the gateway's domain status argument.
  expect(list.mock.calls.map(([status]) => status)).toEqual(['CREATED', 'IN_PROGRESS'])
})
```

Vue Test Utils 的 `trigger` 与 `setValue` 返回 Promise，应 `await`，因为事件处理可能安排 Vue DOM 更新。不要直接执行组件方法来模拟点击；那绕过了模板事件绑定、禁用态、值转换和 bubbling。也不要用 `wrapper.findAll('button')[2]` 表示“打开 WO-5001”，因为增加一个工具按钮就会错点。组件层至少用可见文本/属性缩小目标，浏览器层则用 role 与 accessible name。

断言应说明业务差异。`expect(wrapper.exists()).toBe(true)` 只证明 mount；整页 snapshot 在小文案变化时产生噪声，又可能掩盖错误交互。更可靠的是分别断言 alert 内容、按钮可用性、列表包含哪个工单、不包含哪个旧工单，以及事件载荷的精确形状。

## 5. Emitted event 是父子合同，不是日志

Vue 组件常用事件请求父层变更。测试既要触发真实用户动作，也要验证事件名称、次数和最小载荷：

```ts
it('打开操作只发出稳定身份', async () => {
  const wrapper = mount(WorkOrderSearch, {
    props: { gateway: { list: async () => [{ id: 'WO-5001', title: '复核', status: 'CREATED' }] } },
  })
  await flushPromises()
  await wrapper.get('button').trigger('click')

  expect(wrapper.emitted('select')).toEqual([[{ workOrderId: 'WO-5001' }]])
})
```

只发 ID 而不是整个可变对象，减少父子耦合；测试也因此保护合同。若实现误写 `emit('selected', order)`，这里应立即失败，而不是等 E2E 超时。事件测试不能证明父组件正确消费，所以对关键组合再写父页面测试，或由少量 E2E 覆盖最终用户结果。

不要为了方便调用 `wrapper.vm.selectOrder()`。它只证明私有方法执行后有事件，不证明按钮存在、按钮绑定正确或用户能触达。`defineExpose` 适合确有命令式父组件合同的场景；即使如此，也应分别验证公开命令和可见结果，而不是把所有内部 ref 暴露给测试。

## 6. 两套异步队列：Vue 更新与外部 Promise

异步假阴性和假阳性常来自“不知道在等谁”。至少区分：

1. Vue 响应式写入后，DOM patch 在 next tick 完成；`await wrapper.trigger(...)`、`await wrapper.setValue(...)` 或 `await nextTick()` 用于这条边界；
2. gateway、HTTP client 或其他 Promise 不由 Vue 调度；`await flushPromises()` 让当前可处理的 Promise 回调完成，再观察 Vue 更新；
3. debounce、retry backoff、interval 属于计时器；应使用 fake timers 并明确推进时间；
4. 永不结束或乱序请求不应靠 flush 猜测，应由测试持有 resolve/reject。

一个常见错误是：mount 后 gateway 已 `mockResolvedValue`，马上断言结果。此刻组件可能仍显示 loading。另一个错误是用 `await nextTick()` 等 HTTP Promise；next tick 不承诺外部 Promise 已 resolve。正确写法先观察初始状态，再根据边界选择等待，最后断言。

避免把 `flushPromises` 当万能咒语。若代码持续创建新 Promise 或 interval，盲目 flush 可能掩盖生命周期泄漏。测试名称和注释应说清“等待 gateway fulfillment”，而不是“等一下”。需要验证中间态时，用 deferred Promise：

```ts
function deferred<T>() {
  let resolve!: (value: T) => void
  let reject!: (reason?: unknown) => void
  // Important side effect: the test, not wall-clock timing, decides settlement order.
  const promise = new Promise<T>((ok, fail) => { resolve = ok; reject = fail })
  return { promise, resolve, reject }
}
```

测试持有 `resolve` 后，可以先断言 loading，再 resolve，flush，断言 success；也可以先发 A、切筛选发 B、先 resolve B、后 resolve A，精确验证 latest-response guard。

## 7. 竞态测试必须控制完成顺序

前章的服务器状态合同要求旧请求不能覆盖新结果。组件层既要观察 gateway 调用顺序，也要观察最终 DOM：

```ts
it('旧响应晚到也不能覆盖当前筛选', async () => {
  const pending: Array<{ status: string; resolve: (value: unknown[]) => void }> = []
  const gateway = {
    list: (status: string) => new Promise<unknown[]>((resolve) => pending.push({ status, resolve })),
  }
  const wrapper = mount(WorkOrderSearch, { props: { gateway } })
  await nextTick()
  await wrapper.get('select').setValue('IN_PROGRESS')
  await nextTick()

  pending[1].resolve([{ id: 'WO-NEW', title: '当前', status: 'IN_PROGRESS' }])
  await flushPromises()
  expect(wrapper.get('ul').text()).toContain('WO-NEW')

  pending[0].resolve([{ id: 'WO-OLD', title: '陈旧', status: 'CREATED' }])
  await flushPromises()
  expect(wrapper.get('ul').text()).not.toContain('WO-OLD')
})
```

不要写两个 `setTimeout(Math.random())` 并期待旧请求偶尔晚到。随机测试不保存具体调度，失败时难以重放；固定 sleep 则让 CI 负载改变结果。受控 Promise 把“完成顺序”变成输入，失败差异就是首个可信证据。

还要验证每次调用收到不同 AbortSignal，但不要由此推断服务器已停止。Abort 是资源释放信号；即便旧 Promise 忽略 signal 或响应已经到达，generation/request identity 守卫仍必须阻止提交。故意删掉守卫后，同一测试应稳定红灯，而不是超时。

## 8. Mock 的边界：替换不确定性，不替换要证明的行为

Mock 适合网络、存储、时钟、随机数、遥测发送等外部边界。一个好的 gateway Mock 保留真实组件、真实模板、真实事件和真实状态机，只控制输入/输出与调用记录。过度 Mock 的典型形状包括：

- 把 `WorkOrderSearch` 自身替换成永远显示成功的 stub，然后声称搜索成功；
- 把所有子组件 shallow 掉，使 `v-model` 事件从未真实发生；
- Mock composable 返回与真实 discriminated union 不同的宽松对象；
- Mock router 方法，却从不验证用户最终看到的 route；
- 把网络响应写成已经映射的视图模型，跳过真实字段映射风险。

每次 Mock 都要记录“删除了哪段证据”。若 stub `WorkOrderDetail`，当前测试不再证明详情渲染；若 route fulfill API，E2E 不再证明真实服务与认证，但仍可证明前端从登录输入到详情视图的浏览器路径。Mock 越靠近被测目标，假通过风险越高。

Vitest 的 `vi.fn`、`vi.mock`、`vi.spyOn` 都应在测试间恢复。模块 Mock 有提升与缓存语义，容易让共享状态泄漏；优先通过 props/provide 注入明确接口。只有第三方模块或不可注入边界才使用模块 Mock，并在配置中恢复 mocks、unstub globals。不要 mock 不属于自己的 API 形状；为 gateway 定义 TypeScript interface，使 mock 必须满足生产签名。

## 9. 组件正常、边界与错误矩阵

一个工单查询组件的最小矩阵不是“renders”。建议显式列出：

| Case | 输入/调度 | 首个公共证据 | 最终证据 |
|---|---|---|---|
| 初始加载 | 未完成 Promise | `role=status` | 暂无列表 |
| 成功一条 | resolve `[WO]` | gateway 参数 | 列表与打开按钮 |
| 成功空 | resolve `[]` | success 分支 | 明确 empty 文案，无伪造列表 |
| 网络错误 | reject Error | `role=alert` | 错误文本与重试按钮 |
| 重试成功 | 第一次 reject、第二次 resolve | 两次调用 | alert 消失、结果出现 |
| 事件 | 点击打开 | 按钮可触达 | `select` 精确载荷 |
| 筛选 | setValue | 新 status 参数 | 对应结果 |
| 竞态 | B 先、A 后 | 两请求身份 | DOM 保持 B |
| 卸载 | pending 时 unmount | abort signal | 无卸载后提交/警告 |

DOM 断言必须覆盖“不该出现”的内容。竞态 case 只断言新结果存在还不够，旧结果可能同时残留；应断言旧结果不存在。错误 case 只断言文案还不够，应确认用户有恢复动作。重试后应确认错误消失且调用次数增加。

组件环境不是真实浏览器。happy-dom 可以提供 DOM API 并执行 Vue 更新，但不证明布局、CSS、原生表单细节、焦点算法、网络栈或辅助技术。需要这些证据时升级到浏览器组件测试或 E2E，不要修改断言文案掩盖边界。

## 10. E2E 只覆盖有价值的用户路径

关键路径应从用户可识别的入口开始，并以用户结果结束。FactoryCare 的代表路径是：访问登录页 → 输入工号 → 登录 → 看到工单查询 → 打开 `WO-5001` → 看到详情标题。Playwright 规格示意：

```ts
import { expect, test } from '@playwright/test'

test('登录并打开工单', async ({ page }) => {
  // Data source boundary: fulfill stable frontend scenarios; this does not validate the backend.
  await page.route('**/api/session', route => route.fulfill({ json: { displayName: '值班工程师' } }))
  await page.route('**/api/work-orders?status=CREATED', route => route.fulfill({
    json: [{ id: 'WO-5001', title: '主轴振动复核', status: 'CREATED' }],
  }))

  await page.goto('/')
  await page.getByLabel('工号').fill('E-007')
  await page.getByRole('button', { name: '登录' }).click()
  await expect(page.getByRole('heading', { name: '工单查询' })).toBeVisible()
  await page.getByRole('button', { name: '打开工单 WO-5001' }).click()
  await expect(page.getByRole('heading', { name: '工单详情 WO-5001' })).toBeVisible()
})
```

`getByRole`/`getByLabel` 让定位器与可访问界面同源。它们也不是魔法：按钮 accessible name 若含变化数字，应定义稳定名称；同名多个元素要先缩小到 landmark/list item，而不是立刻 `.nth(2)`。Playwright 会为 click 等 action 执行可见、稳定、可接收事件、可用等 actionability 检查；不要在前面塞 `waitForTimeout(1000)` 抵消自动等待。

本章示例的 verifier 只静态确认规格包含 route、role/label、web-first assertion 且没有固定 sleep/位置选择器。它没有运行上述路径，因此输出 `browser-e2e=UNVERIFIED`。正式证据需要浏览器二进制、服务启动、测试命令、退出码、trace 和失败工件。

## 11. 网络 stub 的合同与真实后端路径

网络 stub 可以稳定制造 200、空、500、慢响应和字段边界，适合前端关键路径。但必须明确：

- stub 证明浏览器页面如何消费该响应；
- stub 不证明 DNS/TLS、代理、cookie policy、CORS、真实认证、后端 schema、权限或数据库；
- 若所有 E2E 都 stub，部署集成可能完全断裂却仍绿灯；
- 若所有 E2E 都依赖共享后端，数据漂移和服务故障会降低反馈质量。

主流做法是分层：PR 上运行隔离的 stubbed path，快速保护前端；在受控集成环境保留少量真实 API smoke path；后端另有契约/集成测试。两套结果分开报告。不要用一个 E2E 同时期待回答前端 UI、后端所有分支和基础设施健康，这会让失败定位从秒级变成猜测。

route handler 应尽量匹配方法、URL 与请求体，避免 `**/*` 吞掉意外请求。响应保持 API 原始合同，让真实 mapper 运行；若直接返回视图模型，会跳过最危险的字段转换。还应断言页面发出的关键请求参数，尤其是筛选、分页与身份上下文，但不要把所有实现请求都写死到一条脆弱 spec。

## 12. 抖动控制与测试隔离

E2E flake 是“同一代码、同一已知输入，结果不稳定”。常见来源与处理：

| 来源 | 脆弱做法 | 可复现做法 |
|---|---|---|
| 固定等待 | `waitForTimeout(1000)` | 等可见结果/响应/URL 的具体条件 |
| 位置定位 | `button.nth(2)` | role + accessible name，必要时先缩小容器 |
| 共享账户数据 | case 间依赖顺序 | 每 case 建立/清理独立状态或 API fixture |
| 登录重复且慢 | UI 登录每个 case | setup 保存隔离 auth state；登录本身保留一条 UI path |
| 随机工单号 | 不保存 seed | 固定 seed/显式 fixture，输出实际输入 |
| 并行污染 | 共享可变记录 | worker 唯一 namespace，幂等清理 |
| 隐藏重试 | 只看最终绿灯 | 报告 first-attempt、retry、trace，先修根因 |

重试可帮助收集证据，不能把 flake 变成通过。若首轮失败、第二轮通过，结果仍应标记不稳定并调查。Playwright test isolation 为每个测试提供新的 BrowserContext；若手动共享 page 或依赖前 case，会主动丢掉隔离优势。

失败时保存“首个可信证据”：第一个断言差异、locator strictness 错误、请求/响应、console error、trace 时间点。不要先增加 timeout；timeout 只是症状终点。若目标根本不存在，等 60 秒不会提供更多事实。

## 13. 四类故障的诊断路径

### 13.1 只断言实现细节

症状：重命名 `loading` ref 或把 watch 改为 composable，功能不变但测试失败；或者按钮绑定删掉，直接调用私有方法的测试仍绿。首证据是断言指向 `wrapper.vm`、私有方法或 snapshot 中无关节点。修复：把测试重写为可见 query → action → DOM/event assertion；重跑原 case，并加入故意断开按钮绑定的 mutation，确认测试会红。

### 13.2 未等待异步

症状：本地偶尔看到结果，CI 仍在 loading；或测试在 assertion 结束后产生 unhandled rejection。首证据是 gateway Promise 已安排但断言发生在 fulfillment/DOM patch 前。修复：画出 action → Vue tick → external Promise → Vue tick，选择 `await trigger/setValue` 与 `flushPromises`；复杂竞态改用 deferred，不用加 sleep。

### 13.3 过度 Mock

症状：组件结构或事件连接已坏，测试仍因 stub 固定 HTML 绿。首证据是被测行为本身被 mock，真实模板/mapper/state machine 从未执行。修复：把 Mock 向外推到 gateway；保留关键子组件；新增能被真实缺陷杀死的断言。若不得不 stub，记录证据缺口并在另一层补齐。

### 13.4 脆弱选择器和 E2E 抖动

症状：增加一个按钮、文案异步变化或 CI 稍慢就失败。首证据是 `.nth()`、复杂 CSS 层级、固定 timeout、共享状态。修复：role/label/name、web-first assertion、独立 fixture 与精确等待。重跑不只一次；保存重复次数、每次结果和 retry 情况，而不是宣称“我这里好了”。

实验目录把四类坏例放在 `faults/`，健康 Vitest suite 不导入它们；静态分类器确认故障确实存在。这样故障教学不会污染绿灯，而每类仍有明确输入与判据。

## 14. 实验步骤：从绿灯到可诊断失败

1. 在 [实验目录](../../../labs/encyclopedia/ch.vue.component-testing/README.md) 记录 `node --version`、`pnpm --version`、操作系统与命令；
2. 执行 `bash verify.sh`，保存 10 个组件 case、构建和静态 E2E 合同结果；
3. 阅读 `tests/work-order-search.test.ts`，把每个 case 标注为正常、边界、错误、事件或竞态；
4. 只复制一个 `faults/` 场景到临时运行入口，预测首个失败，不要同时注入多个故障；
5. 对实现细节 fault，比较 `wrapper.vm` 与公共 DOM 断言能发现的缺陷；
6. 对漏等待 fault，记录断言时 DOM 和 flush 后 DOM，不加 timeout；
7. 对过度 Mock fault，列出被替换掉的真实路径；
8. 对 brittle E2E，逐项替换 `.nth`、固定 sleep 与宽 URL；
9. 恢复健康代码，运行完全相同的 verifier，保存 before/fix/after；
10. 在已准备浏览器的外部环境执行 Playwright 规格；若未执行，必须保留 `UNVERIFIED`，不得根据静态检查补写通过。

实验的浏览器规格目前只是“可运行候选”，不是本轮已验证证据。真正执行时若失败，先检查应用是否确有登录表单、base URL、route handler 匹配和按钮 accessible name；不要因为本地资产的静态 verifier 绿就假设路径正确。

## 15. 公开练习与独立完成规则

公开练习起始测试故意读取 `wrapper.vm`、同步断言 Promise 结果，缺少公共 loading/result 查询、用户 click 与 emitted assertion。运行 verifier 返回固定非零码和缺失证据列表，这个红灯是起点，不是工具故障。

独立完成时只修改公开测试文件：导入 `flushPromises`，先断言 `role=status`，等待 gateway，再查结果列表，点击可见按钮并断言 `select` 的 `{ workOrderId }`。不要读取私有解答，不要通过删除检查器、硬编码输出或把坏 token 放进注释骗过静态规则。正式学习证据还应运行真实 Vitest；本公开练习的 checker 只评价提交结构，章节示例/实验提供执行证据。

若使用 AI 辅助，应保存提示、建议与人工决定，之后从干净起点无 AI 重建同类 case。能解释每个等待对应哪条队列、每个 Mock 删除哪段证据、每个 selector 为什么稳定，才接近 outcome；复制绿灯文件不等于掌握。

## 16. G4 证据包模板

建议在 `evidence/gates/g4/ch.vue.component-testing/` 保存：

```text
README.md                  # 范围、风险矩阵、命令、结论与未验证项
environment.txt           # OS/Node/pnpm/Vue/Vitest/Playwright/浏览器版本
component-command.txt     # 完整命令与退出码
component-results.txt     # 正常/边界/错误/竞态 case
build-results.txt         # Vite 生产构建
e2e-command.txt           # 真实 browser 命令；未执行则写 UNVERIFIED
e2e-results/              # report、trace、截图或失败录像
fault-implementation.txt  # 首个失败→修复→同命令重跑
fault-async.txt
fault-overmock.txt
fault-selector.txt
residual-risks.md         # 后端、浏览器矩阵、视觉/无障碍等剩余风险
```

每份记录包含工作目录、输入 fixture/seed、是否使用 network stub、是否重试。组件测试绿但 E2E 未执行时，总结必须写“组件与构建已验证；E2E 规格已静态检查；真实浏览器未验证”。没有浏览器版本、命令和结果，不能给浏览器证据打勾。

## 17. 120 秒 teach-back 与判定表

合格解释应覆盖：组件测试观察公共 DOM/事件，E2E 观察真实浏览器关键路径；Mock 放在 gateway/网络等边界；Vue tick 与外部 Promise 不同；受控 Promise验证竞态；role/label locator 与 web-first assertion 降低抖动；反例是后端权限/事务不能由前端 Mock 证明。

| 维度 | 不通过 | 基本通过 | 扎实通过 |
|---|---|---|---|
| 公共合同 | `wrapper.vm`/snapshot 为主 | DOM 或事件有断言 | query-action-result 与负向断言完整 |
| 异步 | sleep/偶然绿 | 能用 flush | 能解释每次等待并控制竞态 |
| Mock | 把被测行为 stub 掉 | gateway 可注入 | 逐项记录证据缺口并补层 |
| E2E | 无路径或只点 CSS | 有登录到详情规格 | role/label、隔离、trace、真实浏览器结果 |
| 诊断 | 增加 timeout | 找到失败文件 | 首证据→单一修复→同命令重跑 |
| 边界诚实 | 静态检查称浏览器通过 | 标记未验证 | 组件、规格、浏览器证据分别报告 |

## 18. 版本面与官方资料

本章工件固定 Vue `3.5.35`、Vitest `4.0.18`、Vue Test Utils `2.4.11`、Vite `7.3.1`、TypeScript `5.9.3`；E2E 规格固定 `@playwright/test` `1.60.0`。版本固定只帮助复现，不意味着所有未来版本语义相同，升级时重读 release notes 并重跑组件、构建和浏览器路径。

官方资料（复核于 2026-07-17）：

- [Vue Testing 指南](https://vuejs.org/guide/scaling-up/testing.html)：测试类型、公共行为、组件与 E2E 工具边界；
- [Vue Test Utils 异步行为](https://test-utils.vuejs.org/guide/advanced/async-suspense.html)：Vue 更新、`nextTick` 与 `flushPromises`；
- [Vitest Mock API](https://vitest.dev/api/mock)：mock/spy 的生命周期与恢复；
- [Vitest Module Mocking](https://vitest.dev/guide/mocking/modules.html)：模块替换与缓存边界；
- [Playwright Locators](https://playwright.dev/docs/locators)：role、label 与 locator 策略；
- [Playwright Actionability](https://playwright.dev/docs/actionability)：自动等待与 web-first assertions；
- [Playwright Network](https://playwright.dev/docs/network)：请求观察、修改与 route fulfill；
- [Playwright Best Practices](https://playwright.dev/docs/best-practices)：面向用户测试、隔离与稳定性；
- [Playwright Test Isolation](https://playwright.dev/docs/browser-contexts)：BrowserContext 隔离模型。

最终边界再次确认：本地机械结果已覆盖 8 个示例组件 case、10 个实验 case、两次 Vite 构建、两份 E2E 规格静态合同、公开预期红灯与私有绿灯；**真实 Playwright 浏览器没有启动，登录到打开工单路径未验证**。这项缺口是刻意保留的真实边界，不应由推断填补。
