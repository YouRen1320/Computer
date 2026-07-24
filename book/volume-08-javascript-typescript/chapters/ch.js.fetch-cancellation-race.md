---
schema_version: 2
edition: 2026.2-draft
id: ch.js.fetch-cancellation-race
title: Fetch、AbortController、超时、重试与竞态
responsibility: 用 Fetch 和 AbortController 建立请求、响应、超时、有限重试和“最新请求胜出”合同，区分取消 UI 更新与真正取消网络工作。
volume: '08'
order: 13
level: L2
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.js.fetch-cancellation-race.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.js.testing-debugging
- ch.js.event-loop
- ch.web.origin-cookie-cache
version_surfaces:
- browser
- browser-devtools
- node-24-lts
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
  text: 在 120 秒内解释“Fetch、AbortController、超时、重试与竞态”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - js-fetch-http-boundary
  - js-cancel-retry-race
  covers_topics:
  - js.fetch-request-response
  - js.fetch-http-error-check
  - js.response-body-once
  - js.request-timeout-policy
  - js.abort-controller-signal
  - js.abort-error
  - js.retry-backoff-boundary
  - js.latest-request-wins
  - js.stale-response-guard
  uses_capabilities:
  - web.javascript-async-runtime
  - web.javascript-testing-debugging
  - web.browser-origin-state
  - foundation.http-message
  - web.javascript-network-race
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现可取消且防陈旧响应的工单查询函数并用可控延迟验证竞态；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - js-fetch-http-boundary
  - js-cancel-retry-race
  covers_topics:
  - js.fetch-request-response
  - js.fetch-http-error-check
  - js.response-body-once
  - js.request-timeout-policy
  - js.abort-controller-signal
  - js.abort-error
  - js.retry-backoff-boundary
  - js.latest-request-wins
  - js.stale-response-guard
  uses_capabilities:
  - web.javascript-async-runtime
  - web.javascript-testing-debugging
  - web.browser-origin-state
  - foundation.http-message
  - web.javascript-network-race
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: vitest-fake-server-request-race-matrix-injected-delay
- id: diagnose
  kind: fault-diagnosis
  text: 面对“只清 loading 未校验请求身份、无限重试或把 404 当成功响应”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - js-fetch-http-boundary
  - js-cancel-retry-race
  covers_topics:
  - js.fetch-request-response
  - js.fetch-http-error-check
  - js.response-body-once
  - js.request-timeout-policy
  - js.abort-controller-signal
  - js.abort-error
  - js.retry-backoff-boundary
  - js.latest-request-wins
  - js.stale-response-guard
  uses_capabilities:
  - web.javascript-async-runtime
  - web.javascript-testing-debugging
  - web.browser-origin-state
  - foundation.http-message
  - web.javascript-network-race
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Fetch、AbortController、超时、重试与竞态

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《异常、调试、测试预言与 Vitest》](ch.js.testing-debugging.md)：请求竞态和错误路径必须用可信预言、替身与故障注入证明，而非目测。
- [《事件循环、任务、Promise 与 async/await》](ch.js.event-loop.md)：响应、取消和 timeout handler 的先后由任务与 Promise 调度决定。
- [《Origin、同源、Cookie、缓存与 CORS 浏览器模型》](../../volume-07-web-platform/chapters/ch.web.origin-cookie-cache.md)：凭据、跨源和缓存行为属于浏览器边界，不能误诊为异步逻辑。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。2026-07-17 已核对 WHATWG Fetch/DOM、Node 24 与 Vitest 官方资料。配套资产使用可控的内存传输和 Node 断言验证稳定异步合同，不访问真实网络；课程项目验收仍应使用 Vitest、故障服务器和目标浏览器。Node 22 本地绿灯不能冒充 Node 24/浏览器行为完全一致。

网络代码最危险的错觉是“最后写的代码会最后返回”。请求完成顺序由网络、缓存、服务端和事件循环共同决定。用户先选 A 再选 B，A 可能更晚返回；如果每个回调都无条件写状态，页面会显示已经过时的 A。取消、超时和请求身份就是用来控制这些不确定性的合同。

## 1. 完成定义与边界

你要实现一个工单查询器并确定性证明：

- 2xx 成功才能进入业务解析；
- 404/500 等 HTTP 响应不会当成成功数据；
- 响应体只读取一次，解析错误与 HTTP 错误可区分；
- 超时会真正 abort 关联工作并释放 timer；
- 用户切换查询会取消旧请求；
- 即使传输无法及时取消，旧响应也不能提交状态；
- 重试仅针对明确可重试且副作用安全的情况；
- 退避有上限、抖动策略可注入测试，不形成重试风暴；
- loading/error 只能由当前请求修改；
- 测试能控制每个响应的完成顺序，而非依赖真实睡眠。

本章不解决 CORS、Cookie、安全授权、服务端幂等或数据库性能；这些问题需要在对应边界修复，不能靠“多重试几次”。

配套入口：

- [最新请求胜出示例](../../../examples/encyclopedia/ch.js.fetch-cancellation-race/README.md)
- [陈旧提交、无限重试和 HTTP 误判实验](../../../labs/encyclopedia/ch.js.fetch-cancellation-race/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.js.fetch-cancellation-race/README.md)

## 2. Fetch 的两层失败

`fetch()` 返回 Promise。请求无法形成普通响应（网络错误、取消等）时 Promise 会拒绝；服务端返回 404/500 时通常仍会兑现为 `Response`，因此必须检查状态：

```js
async function readJson(url, { signal, fetchImpl = fetch } = {}) {
  const response = await fetchImpl(url, { signal })

  if (!response.ok) {
    throw new HttpError(response.status, await readProblemSafely(response))
  }

  return response.json()
}
```

`response.ok` 对应 200—299。是否接受 204、206 或重定向后的结果仍由接口合同决定。不要只写 `catch` 然后把所有错误显示“网络异常”；否则 401、403、404、429、500、解析错误和用户取消都失去恢复语义。

### 2.1 错误分类

| 类别 | 首个可信证据 | 常见 UI/策略 |
|---|---|---|
| 取消 | signal/reason、异常类型 | 静默结束旧操作或显示用户取消 |
| 连接/网络 | fetch 拒绝、DevTools | 可重试提示/离线状态 |
| HTTP | status + 受控 Problem | 按 401/403/404/409/429/5xx 处理 |
| 解析 | Content-Type、原始受控响应 | 合同/服务异常，记录 requestId |
| 运行时 | stack + 操作上下文 | 缺陷监控，不伪装网络失败 |

日志不要复制 token、完整 URL query、响应正文或用户输入。记录 route template、status、errorCode、buildId 和无业务语义 requestId。

## 3. Response body 是一次性流

`response.json()`、`text()` 等消费 body。一般不能先 `json()`，失败后再对同一 Response 调 `text()`；`bodyUsed` 会反映消费状态。需要错误正文时先根据 Content-Type 和大小限制选择一次读取，再解析：

```js
async function readProblemSafely(response) {
  const contentType = response.headers.get('content-type') ?? ''
  const text = await response.text()
  if (!contentType.includes('application/problem+json')) return { title: 'HTTP error' }
  try {
    return JSON.parse(text)
  } catch {
    return { title: 'Invalid problem response' }
  }
}
```

真实实现还要限制可记录内容、处理空 body 和超大 body。`clone()` 可以产生另一视图，但流会 tee、增加内存/背压复杂度，不应作为随意重复读取的默认方案。

## 4. AbortController：控制器、信号与原因

```js
const controller = new AbortController()
fetch('/api/v1/reports/mine', { signal: controller.signal })
controller.abort(new DOMException('superseded', 'AbortError'))
```

- `AbortController` 拥有 `signal`；
- 消费者接收 signal，不能只接 controller 的布尔副本；
- `abort(reason)` 向所有监听该 signal 的工作发出一次取消；
- `signal.aborted` 和 `signal.reason` 表示状态；
- `throwIfAborted()` 可在自定义异步步骤进入前失败；
- 一个已 aborted 的 signal 不能“复位”后重用。

取消是协作协议。Fetch 会响应 signal，但自定义解析、sleep、循环、数据库适配器只有显式接收/检查 signal 才会停止。UI 不再提交结果与底层工作已停止是两件事。

### 4.1 三种不同动作

1. **忽略旧结果**：只在提交状态前校验身份；底层仍运行；
2. **请求取消**：调用 controller.abort，让支持 signal 的步骤尽快停止；
3. **释放资源**：清 timer、监听器、流 reader 和控制器引用。

健壮实现通常同时做 1 和 2，并在 `finally` 做 3。只做 abort 仍需陈旧响应防线，因为某个传输替身/非 Fetch 步骤可能忽略 signal。

## 5. 超时是调用方政策

HTTP/Fetch 不替你选择业务超时。查询工单列表可能允许 8 秒，输入联想可能只允许 1 秒，上传不能套同一短超时。超时意味着“调用方不再愿意等待”，不证明服务端没有执行副作用。

```js
function withTimeout(timeoutMs, parentSignal) {
  const controller = new AbortController()
  const timer = setTimeout(
    () => controller.abort(new DOMException('timeout', 'TimeoutError')),
    timeoutMs
  )

  const forwardAbort = () => controller.abort(parentSignal.reason)
  parentSignal?.addEventListener('abort', forwardAbort, { once: true })

  return {
    signal: controller.signal,
    dispose() {
      clearTimeout(timer)
      parentSignal?.removeEventListener('abort', forwardAbort)
    }
  }
}
```

现代环境也可能提供 `AbortSignal.timeout()` 和 `AbortSignal.any()`；使用前按目标基线确认，测试 signal.reason 的分类。手写组合器必须清理 parent listener/timer，并处理 parent 已经 aborted 的情况。

### 5.1 timeout 与 Promise.race

只用 `Promise.race([fetchPromise, timeoutPromise])` 让调用方先得到超时，但不会自动停止 fetch。请求继续占连接、消耗服务端并可能晚到产生副作用。race 必须与 AbortSignal 或明确底层取消结合。

## 6. 最新请求胜出：身份先于结果

状态拥有当前请求 token：

```js
function createLatestLoader(fetchWorkOrders) {
  let current = null

  return async function load(filter) {
    current?.controller.abort(new DOMException('superseded', 'AbortError'))

    const operation = {
      id: Symbol('work-order-query'),
      controller: new AbortController()
    }
    current = operation

    try {
      if (current === operation) state.loading = true
      const items = await fetchWorkOrders(filter, { signal: operation.controller.signal })
      if (current !== operation) return
      state.items = items
      state.error = null
    } catch (error) {
      if (current !== operation) return
      if (!operation.controller.signal.aborted) state.error = normalize(error)
    } finally {
      if (current === operation) state.loading = false
    }
  }
}
```

重点不是变量名，而是不变量：只有仍为 current 的 operation 能写 `items/error/loading`。`controller === currentController` 比比较布尔值可靠，因为对象引用代表操作身份。

### 6.1 典型竞态

时间线：

```text
t0 load(A): loading=true
t1 load(B): abort A, loading=true
t2 A finally: 如果无身份检查 → loading=false（错误）
t3 B response: items=B
```

如果 `finally` 无条件清 loading，B 仍在运行时 UI 已显示“不加载”。同理，A 的 catch 可能覆盖 B 的 error，A 的 response 可能覆盖 B 的 items。三个提交点都要校验身份。

### 6.2 过滤器相同怎么办

可以去重相同请求、复用缓存或始终重发，这是产品/缓存策略。无论如何都要定义并发调用者是否共享取消：一个组件取消不应意外取消其他仍需要的共享请求。简单学习实现先每个 loader 独占 operation。

## 7. 组件卸载与请求生命周期

页面卸载时：

- abort 当前请求；
- 停止 timer/retry sleep；
- 移除监听器；
- 阻止任何晚响应提交 UI；
- 不把用户取消显示为系统错误。

Vue 可在 watcher cleanup/onUnmounted 调用 abort；React/其他框架使用对应 cleanup。`mounted` 布尔只阻止更新，不能取消网络，也不能防止重复调用。业务层应接收 signal，UI 层负责把生命周期取消传入。

## 8. 重试：先问副作用安全

重试是再次发送请求，不是魔法恢复。读取通常更容易重试；创建/修改必须有服务端幂等合同。FactoryCare 创建报修使用稳定 `Idempotency-Key`，超时重试保持同一键和正文；换键可能重复创建。

### 8.1 可重试矩阵

| 结果 | 默认策略 | 原因 |
|---|---|---|
| 用户取消/被新请求替代 | 不重试 | 意图已过期 |
| timeout/连接中断 | 有界重试或用户操作 | 结果可能未知，写操作需幂等 |
| 400/422 | 不自动重试 | 同输入仍失败，需要修改 |
| 401 | 至多一次受控会话恢复 | 无限刷新会环路 |
| 403/404 | 不自动重试 | 权限/资源语义不是瞬时网络 |
| 409 | 按业务合同 | 并发/幂等冲突需理解原因 |
| 429 | 遵守服务端提示并限速 | 立即重试会加重压力 |
| 502/503/504 | 有界退避 | 常为瞬时，但仍需预算 |

具体 Problem/errorCode 可以覆盖通用状态策略。不能只写 `status >= 500`，因为服务端可能明确返回不可重试错误。

## 9. 指数退避、抖动与预算

概念式：

```text
delay = min(cap, base × 2^attempt)
jittered = random(0, delay)   // full jitter 示例
```

抖动减少大量客户端同时重试。测试中注入 `sleep` 和 `random`，不要真实等待。停止条件至少包括：最大尝试次数、总时长/截止时间、parent signal、不可重试错误和业务上下文失效。

```js
async function retry(operation, policy, { signal, sleep }) {
  let lastError
  for (let attempt = 0; attempt < policy.maxAttempts; attempt += 1) {
    signal?.throwIfAborted()
    try {
      return await operation({ attempt, signal })
    } catch (error) {
      lastError = error
      if (!policy.shouldRetry(error) || attempt + 1 >= policy.maxAttempts) throw error
      await sleep(policy.delay(attempt), { signal })
    }
  }
  throw lastError
}
```

无限 `while(true)` + catch + 立即 fetch 是重试风暴。重试层也不能吞掉最后错误或重置 request identity。

## 10. 测试异步竞态：控制完成，不控制运气

不要用真实 `setTimeout(100)` 猜 A/B 顺序。使用 deferred Promise：

```js
function deferred() {
  let resolve
  let reject
  const promise = new Promise((res, rej) => { resolve = res; reject = rej })
  return { promise, resolve, reject }
}
```

测试步骤：调用 load(A) → 调用 load(B) → 先 resolve B → 断言 items=B/loading=false → 再 resolve A（即使 fake transport 忽略 abort）→ 断言 items 仍为 B。这个 oracle 同时证明取消与陈旧提交防线不是同一件事。

### 10.1 必测矩阵

1. 2xx + 合法 JSON；
2. 404 Problem；
3. 500 可重试直到成功；
4. 解析失败；
5. timeout abort；
6. parent/user abort；
7. B 先于 A；
8. A abort 后仍晚到；
9. retry 上限；
10. 429/Retry-After 策略；
11. 当前请求 finally 清 loading，旧请求不能清；
12. cleanup 后无 timer/listener。

Vitest fake timers 可控制 timeout/退避，但需要在 `afterEach` 恢复真实 timer；deferred Promise 的微任务仍要显式 await。不要把所有全局都 mock 掉，否则测试只证明 mock 配置。

## 11. Fetch 替身要保留真实语义

一个过度简化的 mock 若对 404 直接 reject，会掩盖“Fetch 对 HTTP 错误仍返回 Response”的真实边界。好的 fake transport 明确提供：status/ok、headers、body 一次消费、signal abort、延迟控制和调用记录。

不需要重新实现整个浏览器。单元层验证你自己的政策；集成层使用 Mock Service Worker/测试服务器；浏览器层用 DevTools/自动化验证 CORS、Cookie、缓存和真实取消表现。

## 12. 常见错误与首个可信证据

### 12.1 把 404 当成功

症状：页面把 Problem JSON 当成工单对象，随后报 `items.map is not a function`。

首证据是 Network 的 HTTP status/响应合同，不是后面的 TypeError。修复在 fetch 边界检查 status 和运行时 schema，重跑 404 测试。

### 12.2 只在 finally 清 loading

症状：快速切换时 loading 闪烁，旧错误覆盖新结果。

用可控 A/B 时间线观察每次状态写入的 operationId。修复所有提交点身份检查，而不是延长 debounce。

### 12.3 无限重试

症状：服务异常时请求量升高、浏览器持续耗电。

检查 attempt、总截止时间、间隔和停止原因。修复为有界政策、抖动、取消与最终错误；故障服务器持续 503 时断言调用次数精确等于上限。

### 12.4 只 Promise.race 不 abort

症状：UI 已超时，但 Network 中请求继续，服务端仍完成写操作。

首证据是 signal/Network/服务端 requestId。修复把 timeout signal 传到 Fetch 和下游，写操作仍依赖幂等而非取消保证。

### 12.5 错误吞掉

`catch { return [] }` 让真实空列表与加载失败不可区分。UI 应保留 error 与 last good data 的关系；只有明确产品降级才能返回 fallback，并记录原错误类别。

## 13. 安全、缓存与凭据边界

- URL query 可能进入历史/日志，不放 token 或敏感筛选；
- `credentials`、SameSite、CORS 属于浏览器安全合同；
- abort 不能撤回已发送给服务端的数据；
- 重试带凭据仍需 CSRF/授权保护；
- 缓存可能让响应很快，但不能跳过身份/陈旧检查；
- 401 刷新队列要防止多个请求同时刷新和重放风暴；
- 取消原因/错误消息进入监控前脱敏。

## 14. 配套资产与证据限制

示例实现一个可注入 transport 的 latest loader，内存 deferred 允许 B 先完成、A 晚到。实验识别三个策略故障：404 未检查、无限重试、旧 finally/response 无身份保护。公开练习故意保留缺口并稳定红灯；私有答案只证明离线 oracle 有解。

配套脚本使用本机 Node，不发网络请求，不能证明：浏览器连接真的终止、CORS/Cookie/缓存正确、服务端停止计算、Node24/Vitest/真实 timer 相同、FactoryCare 写操作幂等或 UI 无障碍正确。真实 G4 证据必须来自目标 Vitest 版本、受控故障服务器和浏览器 request-race matrix。

## 15. 120 秒讲解模板

1. Fetch 的网络失败会 reject，但 404/500 通常仍是 Response，必须检查 `ok/status`；
2. body 是一次性流，错误正文也要有受控读取策略；
3. AbortController 通过 signal 协作取消，不能复位；
4. UI 忽略旧结果、真正 abort 底层工作、释放 timer/listener 是三件事；
5. 最新请求胜出依赖 operation identity，items/error/loading 每次提交都校验 current；
6. 超时是调用方放弃等待，不证明服务端没有副作用；
7. 重试必须有可重试分类、幂等、上限、退避、抖动和取消；
8. 测试用 deferred 控制完成顺序，而不是 sleep；
9. 越界反例：CORS/数据库慢不能靠前端多重试解决。

## 16. 自测题

1. 为什么 404 不一定进入 fetch 的 catch？
2. `response.ok` 表达什么范围，是否足以替代业务合同？
3. 为什么 body 通常只能读取一次？
4. abort signal 与 controller 各负责什么？
5. 忽略旧结果与取消网络有什么不同？
6. 为什么 `Promise.race` 超时可能仍消耗服务端？
7. A/B 请求中旧 finally 怎样错误清掉新 loading？
8. 为什么 object identity 比比较 `aborted` 布尔更能代表当前请求？
9. 写请求超时后何时可以重试？
10. 同一幂等键为什么必须保持同一请求指纹？
11. full jitter 解决什么群体行为？
12. deferred Promise 比真实 sleep 稳定在哪里？
13. 过度简化的 mock 怎样掩盖 HTTP 错误语义？
14. 取消为什么不能撤回服务端已经提交的事务？
15. 本章哪些结论必须在真实浏览器/服务端重新验证？

## 17. 官方资料

- [WHATWG Fetch Standard](https://fetch.spec.whatwg.org/)
- [WHATWG DOM Standard：AbortController/AbortSignal](https://dom.spec.whatwg.org/)
- [Node.js 24 Globals](https://nodejs.org/download/release/latest-v24.x/docs/api/globals.html)
- [Vitest Timers](https://vitest.dev/guide/mocking/timers)
- [Vitest `vi` API](https://vitest.dev/api/vi)

平台支持面和异常细节会变化，实际项目以目标浏览器/Node/Vitest 基线重新验证；本章稳定核心是响应分层、一次性 body、取消传播、请求身份、有界重试和确定性竞态测试。
