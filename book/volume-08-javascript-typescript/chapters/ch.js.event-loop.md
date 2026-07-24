---
schema_version: 2
edition: 2026.2-draft
id: ch.js.event-loop
title: 事件循环、任务、Promise 与 async/await
responsibility: 建立调用栈、任务、微任务、Promise 状态和 async/await 恢复顺序的运行模型，不在本章发起网络请求或设计重试。
volume: '08'
order: 12
level: L2
status: drafting
path: book/volume-08-javascript-typescript/chapters/ch.js.event-loop.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.js.scope-closures
version_surfaces:
- node-24-lts
- browser
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“事件循环、任务、Promise 与 async/await”的职责、边界与证据，并给出一个不应由本章方案解决的反例
  covers_topic_groups:
  - js-event-loop-queues
  - js-promise-async
  covers_topics:
  - js.call-stack
  - js.task-queue
  - js.microtask-queue
  - js.run-to-completion
  - js.promise-state
  - js.promise-chaining
  - js.async-await
  - js.async-error-propagation
  uses_capabilities:
  - web.javascript-language
  - web.javascript-functions-closures
  - web.javascript-async-runtime
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“事件循环、任务、Promise 与 async/await”构建可运行程序与测试：构造同步、Promise、queueMicrotask 和 timer 的最小顺序实验并画出队列轨迹；不复制成品，保存可复现输入、工件与验证结果
  covers_topic_groups:
  - js-event-loop-queues
  - js-promise-async
  covers_topics:
  - js.call-stack
  - js.task-queue
  - js.microtask-queue
  - js.run-to-completion
  - js.promise-state
  - js.promise-chaining
  - js.async-await
  - js.async-error-propagation
  uses_capabilities:
  - web.javascript-language
  - web.javascript-functions-closures
  - web.javascript-async-runtime
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: queue-trace-prediction-async-assertion-script
- id: diagnose
  kind: fault-diagnosis
  text: 面对“把 Promise 当同步值、遗漏 await 或错误捕获边界造成的顺序与异常丢失”，定位失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - js-event-loop-queues
  - js-promise-async
  covers_topics:
  - js.call-stack
  - js.task-queue
  - js.microtask-queue
  - js.run-to-completion
  - js.promise-state
  - js.promise-chaining
  - js.async-await
  - js.async-error-propagation
  uses_capabilities:
  - web.javascript-language
  - web.javascript-functions-closures
  - web.javascript-async-runtime
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 事件循环、任务、Promise 与 async/await

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《词法作用域、闭包与函数状态》](ch.js.scope-closures.md)：延迟执行会捕获词法环境，必须先能判断闭包状态的生命周期。
<!-- END GENERATED LEARNING PREREQUISITES -->

JavaScript 从上到下读取源码，却不保证所有回调按源码位置连续执行。同步代码先占用当前调用栈；Promise reaction、`queueMicrotask` 与 `await` 的恢复会排入微任务；timer 回调由宿主在未来某次任务机会运行。若只背“Promise 比 setTimeout 快”，稍微改变注册顺序、加入另一个 await 或换到 Node 的 I/O 阶段，就会再次猜错。

本章建立一个可手工追踪的运行模型：区分 ECMAScript 语言的执行上下文、Promise Job 与 async 函数语义，和浏览器/Node 宿主提供的任务与 timer；每个最小实验先写调用栈和队列预测，再运行固定 trace；错误沿同步 throw 或 Promise rejection 传播时，明确由谁 await/return/catch。我们不发网络请求、不设计重试，也不把单线程事件循环等同于整个宿主只有一个线程。

## 完成定义与 canonical 预言

完成本章需要交出：

1. 在 120 秒内解释调用栈、run-to-completion、任务、微任务、Promise 状态、链式传播与 async/await 恢复，并给出不属于本章的反例；
2. 构造包含同步步骤、`Promise.then`、`queueMicrotask`、`await` 和 timer 的最小脚本，运行前画出队列轨迹；
3. 用稳定文本断言证明输出顺序，并单独证明同步错误、await 后拒绝和未处理拒绝的边界；
4. 注入“把 Promise 当同步值”“遗漏 await”“错误 try/catch 边界”，定位首个可信差异，修复后重跑原验证。

canonical T1 预言是：**同步、任务、微任务和 await 的输出顺序与手工队列追踪逐项一致，异常传播路径可重复。** timer 的毫秒耗时、操作系统调度与完整 Node I/O 阶段不作为跨环境固定预言；实验只断言由标准和明确注册顺序支持的先后关系。

## 两层规范：语言负责 Job，宿主负责事件循环

ECMAScript 规范定义执行上下文、Promise 状态、reaction Job、async 函数与 `await` 等语言语义；WHATWG HTML 定义浏览器事件循环、任务源、微任务队列与 microtask checkpoint；Node 以 libuv 阶段、`process.nextTick`、timer、I/O 和 `setImmediate` 形成不同宿主模型。

因此“JavaScript 规范说 setTimeout 什么时候运行”这句话不准确：`setTimeout` 是宿主 API，不是 ECMAScript 核心。可靠解释应说：当前同步执行由语言运行；调用 timer API 后，宿主在阈值满足并轮到相应任务/阶段时调用回调；具体调度需查目标宿主。

一个有用但有限的分层图：

```text
ECMAScript
  执行上下文栈 ── Promise 状态/Reaction Job ── async/await
          │                    │
          └────── 宿主入队钩子 ┘
                           │
Browser: task → microtask checkpoint → rendering opportunity
Node: timers / poll / check / ... + nextTick 与 Promise 微任务处理
```

本章共同实验只使用 Node 与现代浏览器都有的 `Promise`、`queueMicrotask`、`setTimeout` 子集。涉及 `process.nextTick`、`setImmediate` 或渲染时机时单独标注 Node/浏览器，不能把一个宿主的输出复制成另一宿主合同。

## 调用栈与 run-to-completion

函数调用会创建执行上下文并压入调用栈；返回或抛出时退出。当前 JavaScript Job/回调通常运行到完成后，事件循环才会调用另一个已排队回调。这里的“完成”可以是函数返回、抛错，或 async 函数执行到一个需要暂停的 `await` 边界；它不表示整个业务操作已经完成。

```js
// calculateLabel 的数据源全是参数；执行期间没有异步副作用。
function calculateLabel(order) {
  return `${order.id}:${order.status}`;
}

console.log("A");
console.log(calculateLabel({ id: "WO-1", status: "CREATED" }));
console.log("B");
```

在单个调用栈中不会有 timer 回调插入两个 `console.log` 之间。若同步循环运行 500ms，已到期 timer 也要等待栈退出；这就是“0ms timer 不是立即执行”的根本原因之一。

### run-to-completion 不等于线程安全万能保证

一次回调内的同步步骤不会被另一 JavaScript 回调任意插入，但两个回调仍可能基于不同时间的状态做出冲突决策。共享内存 Worker、原子操作、服务端并发和网络响应竞态也有额外模型。本章只追踪单个 agent 的基础调度，不用事件循环替代事务、锁或版本检查。

## 任务与微任务

在浏览器模型中，用户交互、timer 等工作会形成任务；每个事件循环有微任务队列，宿主在定义的 checkpoint 清空可运行微任务。Promise reaction 和 `queueMicrotask` 都会产生微任务类工作。关键不只是“两个队列”，还包括：

1. 当前同步栈先运行到完成；
2. 已入队微任务按入队关系执行；
3. microtask 执行时新排的 microtask 可在同一 checkpoint 继续执行；
4. checkpoint 完成后，宿主才选择后续任务/渲染机会；
5. 任务选择还受任务源和宿主算法影响，不能用一个全局 FIFO 简图解释所有浏览器工作。

最小实验：

```js
// trace 是唯一观察出口；注册顺序本身就是预言输入。
const trace = [];
trace.push("sync:start");

setTimeout(() => trace.push("task:timer"), 0);
Promise.resolve().then(() => trace.push("microtask:promise"));
queueMicrotask(() => trace.push("microtask:queue"));

trace.push("sync:end");
```

在支持这些 API 的目标宿主中，当前脚本的两个同步标记先出现；两个微任务按此处入队顺序出现；timer 至少在当前栈及这个 checkpoint 之后。不要断言 timer 恰好 0ms，也不要把此结论扩大到 `process.nextTick`、`setImmediate` 与 I/O 内部的所有组合。

### 微任务饥饿

微任务可以继续排微任务。如果回调无界递归 `queueMicrotask(loop)`，宿主可能长期无法进入下一个任务，页面输入、timer 和渲染都被推迟：

```js
// 错误示范：每个微任务继续排一个微任务，后续任务可能得不到机会。
function loop() {
  queueMicrotask(loop);
}
```

“异步”不自动等于“让出给所有工作”。长计算应拆分并选择能真正给任务/渲染机会的边界，或移到 Worker；具体性能策略超出本章，但诊断时要区分微任务洪水与同步阻塞。

## timer 是阈值，不是预约时刻

`setTimeout(callback, 0)` 表示满足最小延迟后回调有资格进入宿主调度，不保证马上、精确或优先执行。延迟可能来自当前长任务、微任务 checkpoint、其他任务、后台页面节流、Node I/O 阶段或系统负载。

测试应断言因果顺序：`sync:end` 在 `task:timer` 前，而不是断言 timer 在 1ms 内执行。需要测试业务超时策略时应使用可控时钟；本章只做真实队列顺序，不引入网络 timeout。

## Promise 是未来结果的对象，不是结果本身

ECMAScript 定义 Promise 有 pending、fulfilled、rejected 三种互斥状态；fulfilled/rejected 合称 settled。`resolved` 与 settled 不完全同义：一个 Promise 可以被 resolve 到另一个仍 pending 的 Promise，从而“锁定跟随”但尚未 settled。

```js
// loadCount 的返回值始终是 Promise；调用者不能把它直接当 number。
async function loadCount() {
  return 3;
}

const countPromise = loadCount();
console.log(typeof countPromise); // object，而不是 number
```

Promise constructor 的 executor 在构造时同步调用，但 `.then` 回调不会因此同步插入当前栈：

```js
// executor 的同步副作用和 reaction 的异步执行被故意分别记录。
const trace = [];
const promise = new Promise((resolve) => {
  trace.push("executor");
  resolve("READY");
});

promise.then(() => trace.push("reaction"));
trace.push("after-then");
```

稳定顺序是 `executor`、`after-then`、`reaction`。Promise 已 fulfilled 只意味着注册 reaction 会立即入 Job，不意味着 handler 在 `then()` 调用栈内同步执行。

### 只会 settled 一次

同一个 Promise 首次有效 resolve/reject 后，后续尝试无效。它不是可多次发值的事件流：

```js
// firstSettlementWins 展示单次结果合同，不用于事件订阅。
const promise = new Promise((resolve, reject) => {
  resolve("first");
  reject(new Error("late"));
  resolve("later");
});
```

结果是首次解析方向；若需要多次更新，使用事件、迭代器或其他流抽象，不把 Promise 重复 resolve。

## Promise 链：每个 `then` 都产生派生 Promise

`.then(onFulfilled, onRejected)` 返回新 Promise。handler 的结果决定派生 Promise：

| handler 行为 | 派生 Promise |
| --- | --- |
| 返回普通值 | fulfilled 为该值 |
| 返回 Promise/thenable | 跟随其最终状态 |
| 抛出错误 | rejected 为该错误 |
| 没有 fulfillment handler | 原 fulfilled 值向后传 |
| 没有 rejection handler | 原 rejection 原因向后传 |

```js
// 每一步 return 让数据与错误沿同一链传播；没有隐藏的外部可变结果。
function prepareSummary(loadOrders) {
  return loadOrders()
    .then((orders) => orders.filter((order) => order.status === "CREATED"))
    .then((orders) => ({ count: orders.length }));
}
```

忘记 return 会让下一步收到 `undefined` 或过早完成：

```js
// 错误：内部 Promise 没有返回，外链无法等待其结果或接收其拒绝。
loadOrders().then((orders) => {
  persistAudit(orders);
}).then(() => console.log("audit done?"));
```

若 `persistAudit` 返回 Promise，应 `return persistAudit(orders)`。链式写法与 async/await 都要求显式连接异步所有权；语法不同，传播合同相同。

### `catch` 也是链的一部分

`promise.catch(onRejected)` 类似 `.then(undefined, onRejected)`，返回新的 Promise。catch 若返回普通值，表示恢复为 fulfilled；若不能恢复，应重新抛出或返回 rejected Promise。沉默 catch 会把失败伪装成成功：

```js
// 错误：错误被转换成 undefined fulfillment，调用者失去失败证据。
return loadOrders().catch(() => undefined);
```

恢复策略必须有明确返回类型，例如 `{ ok: false, error }`；否则保留 rejection。

## async 函数：同步开始，Promise 结束

调用 async 函数立即得到 Promise。函数体从开头同步执行，直到返回、抛错或遇到需要暂停的 await；await 后的恢复通过 Promise 机制排队，不在当前调用栈内继续。

```js
// buildTrace 展示 async 函数在首个 await 前同步、之后异步恢复。
async function buildTrace(trace) {
  trace.push("async:before");
  await Promise.resolve("ready");
  trace.push("async:after");
  return "done";
}

const trace = ["sync:start"];
const resultPromise = buildTrace(trace);
trace.push("sync:end");
```

调用返回时，trace 已含 `async:before`，但尚无 `async:after`；恢复微任务执行后才添加。`resultPromise` 最终 fulfilled 为 `"done"`。即使 `await 42` 的操作数不是 Promise，语言也通过 Promise/await 语义安排恢复，不应把 await 后代码视为同一同步段。

### 多个 await 是多个可观察边界

```js
// 每个 await 都可能让其他已排队微任务先运行，因此共享状态需重新判断。
async function processOrder(order, validate, persist) {
  const checked = await validate(order);
  const saved = await persist(checked);
  return saved;
}
```

从 validate 恢复到调用 persist 之间，其他工作可能已改变外部状态。不要把 async 函数从头到尾想成一个事务。FactoryCare 权威状态仍由服务端版本与事务检查，本章只解释前端调度。

## async 错误传播：throw 会成为 rejection

async 函数在返回 Promise 前后的 throw 最终都表现为返回 Promise 的 rejection；调用者必须 await、return 或显式接链。同步 `try/catch` 只捕获当前栈中的 throw，不能捕获未来 Promise rejection：

```js
// 错误：try 块只拿到 Promise；未来 rejection 不会跳回这个已结束的 catch。
try {
  loadWorkOrder();
} catch (error) {
  report(error);
}
```

正确边界之一：

```js
// await 把 rejection 重新表现为当前 async 控制流中的 throw，catch 才能处理。
async function showWorkOrder() {
  try {
    const order = await loadWorkOrder();
    render(order);
  } catch (error) {
    renderFailure(error);
  }
}
```

另一种是返回链：`return loadWorkOrder().catch(...)`。关键是 Promise 不能脱离所有者。顶层事件处理器若启动异步工作，也要定义错误出口；`void run()` 只是表明忽略返回值，不能自动处理 rejection。

### `return promise` 与 `return await promise`

两者最终都让 async 函数的返回 Promise 跟随内部 Promise，但错误捕获位置可能不同：在当前函数的 `try/catch` 中若希望捕获内部拒绝，必须在 try 内 await 它。不要为了风格机械删除所有 `return await`；先看错误边界合同和工具链行为，再优化栈或性能。

## 三类高频失败

### 把 Promise 当同步值：`async-order-misread`

```js
// 错误：summarize 返回 Promise，读取 total 得到 undefined。
const summary = summarizeAsync(orders);
console.log(summary.total);
```

首个可信证据是 `summary instanceof Promise === true`，而不是后续 UI 显示空白。修复由调用边界决定：在 async 所有者内 `await`，或 return/then 连接；不能给 Promise 对象随意添加业务属性。

### 遗漏 await：验证跑在结果之前

```js
// 错误：异步函数尚未完成就读取 trace，测试可能产生假绿或错误顺序。
runPipeline(trace);
expect(trace).toEqual(["start", "done"]);
```

测试本身应 async 并 `await runPipeline(trace)`，或 return 该 Promise。若函数设计为 fire-and-forget，必须有可观察完成信号和错误出口；普通业务操作不默认脱离所有者。

### 错误捕获边界：`unhandled-rejection`

一个 Promise 被拒绝且没有及时 handler，宿主可报告未处理拒绝；Node 当前默认行为与 CLI 选项属于版本表面。测试不要靠全局 unhandled 监听器把错误吞掉后继续绿灯。首个可信证据是产生 rejection 的 Promise 链和缺失 owner，而不是全局警告最后一行。

修复顺序：找到谁启动异步操作；决定其应 await、return 还是显式监控；把 catch 放在能恢复/转换的责任边界；保留 cause/上下文；让验证器对未处理拒绝以非零退出。

## 手工队列追踪方法

面对混合脚本，不要凭直觉排序。逐行维护三列：

| 观察点 | 当前栈动作 | 新入队工作 |
| --- | --- | --- |
| `trace.push("sync:start")` | 立即追加 | 无 |
| 注册 timer | 调用宿主 API | future task/timer |
| `Promise.resolve().then(P)` | 注册 reaction | microtask P |
| `queueMicrotask(Q)` | 调用宿主 API | microtask Q |
| 调用 async 函数 | 运行到 await | 恢复 microtask A |
| `trace.push("sync:end")` | 立即追加 | 无 |

当前栈清空后，按已知入队顺序处理 P、Q、A；微任务执行期间若再入队，追加到队尾；checkpoint 清空后 timer 才有机会。每运行一个回调，重新写它可能添加的队列项，而不是一次性猜最终输出。

### 固定实验的预期 trace

```js
// runQueueTrace 只观察跨宿主共同子集，不混入 nextTick 或 setImmediate。
export async function runQueueTrace() {
  const trace = ["sync:start"];
  setTimeout(() => trace.push("task:timer"), 0);
  Promise.resolve().then(() => trace.push("microtask:promise"));
  queueMicrotask(() => trace.push("microtask:queue"));

  async function resume() {
    trace.push("async:before");
    await null;
    trace.push("async:after");
  }

  const completion = resume();
  trace.push("sync:end");
  await completion;
  await new Promise((resolve) => setTimeout(resolve, 10));
  return trace;
}
```

注册顺序决定预期：`sync:start`、`async:before`、`sync:end`、`microtask:promise`、`microtask:queue`、`async:after`、`task:timer`。最后 10ms timer 只是让演示等待前一个 timer 完成，不把 10ms 当精确性能断言。

## Node 与浏览器：共享语言，不共享全部调度细节

Node 官方模型展示 timers、pending callbacks、poll、check、close callbacks 等阶段；`setImmediate` 在 check 阶段，timer 与 I/O 的相对顺序受上下文影响。Node 20 起相关 libuv timer 行为发生过调整，说明死记某个历史版本输出很危险。

`process.nextTick()` 是 Node 特有队列机制，官方说明它在当前调用栈完成后、事件循环继续到其他阶段前运行。它不等于 WHATWG 的普通 task，也不应在浏览器教材里无标注使用。递归 nextTick 同样可能饿死 I/O。

浏览器还有渲染机会、用户交互任务源、页面生命周期与后台节流。`requestAnimationFrame` 的视觉时机不能用 Node 验证。反过来，Node 的 poll/check 也不能从浏览器 DevTools 推断。

本章资产在 Node v22.14.0 运行，因此只验证共同子集和当前 Node 输出；canonical 的 Node 24 LTS 表面尚未实跑，必须在 Week 24/环境升级后重新验证。

## 可重复的异步验证原则

顺序测试很容易写成偶发测试。遵守以下原则：

1. 只断言规范保证或由显式注册顺序保证的关系；
2. 不用“睡 1ms”猜异步工作完成，等待实际 completion Promise；
3. timer 用于产生任务边界时，断言先后而非精确耗时；
4. 每个异步调用都由 await/return/catch 所有；
5. 错误测试断言 rejection 类型/标记，不依赖完整跨引擎 stack；
6. 进程退出前确认所有实验工作已完成，没有开放 handle；
7. 故障脚本独立进程运行，避免一个未处理拒绝污染其余预言。

Vitest 异步测试也必须 return Promise 或声明 async 并 await。当前资产为减少测试框架调度干扰，主要使用 Node assertion script；这不表示以后不需要 Vitest，而是让本章队列本身成为唯一观察对象。

## FactoryCare 边界

事件循环模型能解释为什么“先发请求”不保证“先返回”，但本章不发请求，也不设计最新请求胜出、AbortController、timeout 或 retry。它更不能决定工单状态迁移：

- await 只暂停当前 async 控制流，不锁住服务端工单；
- Promise fulfillment 只表示该异步合同成功，不表示业务命令获得授权；
- 微任务先于 timer 不构成事务顺序；
- 客户端 trace 不能代替服务端审计事件与版本检查。

这些规则会成为后续 Fetch/cancellation/race 章节的前置模型，但本章保持纯调度实验。

## 独立实验与诊断任务

### 实验 A：最小顺序

复制的不是输出，而是结构：自己写同步、Promise、queueMicrotask、async/await、timer 各一个标记。先画栈和队列，给每个入队动作编号，再运行。若不同，找到第一个与预测不同的标记并说明原因。

### 实验 B：链式返回

写三步 Promise 链：第一步返回值，第二步返回一个 Promise，第三步故意 throw。证明最终 Promise rejected；加入 catch 恢复为明确对象；删除第二步 return，观察下游为何过早运行。

### 实验 C：错误边界

写一个 async 函数在 await 后 throw。分别用同步 try/catch（不 await）、await try/catch、returned `.catch` 运行。不要让第一种产生无法归属的全局污染；给 Promise 附加外层观察 handler，并记录本地 catch 没有执行。

### 故障注入表

| 故障 | 首个可信证据 | 修复 | 残余风险 |
| --- | --- | --- | --- |
| Promise 当值 | 实际类型/身份是 Promise | await 或返回链 | 调用者仍可能漏接 |
| 遗漏 await | 断言发生在 completion 前 | await/return completion | fire-and-forget 需另定义 |
| 同步 catch 捕异步拒绝 | 本地 catch=false、Promise rejected | await 后 catch/返回 catch | 宿主全局策略版本相关 |
| 微任务顺序猜错 | 第一条 trace 差异与注册序号 | 重画入队轨迹 | 加入宿主特有队列需重判 |

### 120 秒口述提纲

先分语言与宿主；解释调用栈和 run-to-completion；说明 task/microtask checkpoint；解释 Promise 三状态与 reaction Job；描述 async 同步开始、await 后恢复；给出 try/catch 捕不到未来 rejection 的原因；最后说出 Node/browser 差异和本章不处理的 Fetch 重试反例。

## 官方一手资料与核验日期

以下页面于 **2026-07-17** 核验：

- [WHATWG HTML：Web application APIs / Event loops](https://html.spec.whatwg.org/multipage/webappapis.html#event-loops)：浏览器事件循环、任务与微任务 checkpoint；页面为 Living Standard；
- [ECMAScript 2026：Promise Objects 与 Promise Jobs](https://tc39.es/ecma262/2026/multipage/control-abstraction-objects.html#sec-promise-objects)：Promise 状态、reaction Job、宿主入队与 rejection tracker；
- [ECMAScript 2026：Async Function Definitions](https://tc39.es/ecma262/2026/multipage/ecmascript-language-functions-and-classes.html#sec-async-function-definitions)：async 函数返回 Promise、Await 运行语义；
- [Node.js：The Node.js Event Loop](https://nodejs.org/learn/asynchronous-work/event-loop-timers-and-nexttick)：Node 阶段、timer/poll/check 与版本变化说明；
- [Node.js：Understanding process.nextTick](https://nodejs.org/learn/asynchronous-work/understanding-processnexttick)：Node 特有 nextTick 时机；
- [Node.js Process API](https://nodejs.org/api/process.html#event-unhandledrejection)：未处理拒绝的宿主观察边界；
- [Vitest Getting Started](https://vitest.dev/guide/)：当前文档要求 Node >=20，异步测试框架版本表面供后续验证参考。

调用栈、Promise 状态与 await 传播是稳定语言核心；Node 阶段细节、未处理拒绝策略、timer 实现与测试框架版本是易变表面。目标 Node 24 和真实浏览器未在本次运行，不能把文档阅读写成运行证明。

## 本章刻意不做

- 不使用 Fetch，不实现 AbortController、超时、重试、退避、竞态或缓存；
- 不把 async 函数当事务，不实现服务端锁、幂等或状态机；
- 不覆盖 Worker、SharedArrayBuffer、Atomics、async iterator 与 Stream；
- 不建立浏览器渲染性能基准，也不承诺 timer 精确时间；
- 不用 Node v22 的输出声称 Node 24 或所有稳定浏览器一致。
