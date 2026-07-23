---
schema_version: 2
edition: 2026.2-draft
id: ch.dart.future-cancellation
title: Future、async/await、超时与取消协议
responsibility: 解释 Future 完成/失败、async/await 恢复、超时和协作式取消，明确丢弃结果不等于取消底层工作，不教授 Stream。
volume: '11'
order: 7
level: L2
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.dart.future-cancellation.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.dart.exceptions-resources
version_surfaces:
- dart-stable
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
generated_by: scripts/generate-curriculum.rb
generated_spec_digest: fe050cbe3c6e55408cf99b8269d9ad95de71ed453fa4e51b03d854eb0ab61461
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“Future、async/await、超时与取消协议”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - dart-future-async
  - dart-timeout-cancellation
  covers_topics:
  - dart.future-state
  - dart.async-await
  - dart.future-error-propagation
  - dart.future-composition
  - dart.timeout
  - dart.cancellation-token
  - dart.cooperative-cancellation
  - dart.stale-result-guard
  uses_capabilities:
  - mobile.dart-language
  - mobile.dart-future-cancellation
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现可超时和协作取消的工单加载函数并用 Completer 控制完成顺序；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - dart-future-async
  - dart-timeout-cancellation
  covers_topics:
  - dart.future-state
  - dart.async-await
  - dart.future-error-propagation
  - dart.future-composition
  - dart.timeout
  - dart.cancellation-token
  - dart.cooperative-cancellation
  - dart.stale-result-guard
  uses_capabilities:
  - mobile.dart-language
  - mobile.dart-future-cancellation
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: controlled-completer-timeout-fixture-cancellation-counter
- id: diagnose
  kind: fault-diagnosis
  text: 面对“忘记 await、仅忽略结果未取消工作或超时后仍写状态”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - dart-future-async
  - dart-timeout-cancellation
  covers_topics:
  - dart.future-state
  - dart.async-await
  - dart.future-error-propagation
  - dart.future-composition
  - dart.timeout
  - dart.cancellation-token
  - dart.cooperative-cancellation
  - dart.stale-result-guard
  uses_capabilities:
  - mobile.dart-language
  - mobile.dart-future-cancellation
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Future、async/await、超时与取消协议

> 本章状态为 `drafting`。稳定概念按 Dart 语言与 `dart:async` 合同讲解；版本资料于 2026-07-24 对照 Dart 官方文档 3.12.2。本章配套程序实际在本机 Dart 3.9.2 stable、macOS arm64 上运行，因此“3.9.2 绿灯”与“3.12.2 资料核对”是两条证据，不能合并成未执行的版本兼容结论。本章只处理一次性异步结果，不教授 Stream。

很多异步 bug 并不是不会写 `await`，而是不清楚谁拥有工作、谁拥有结果、截止时间后底层任务是否仍在运行，以及页面或业务状态是否还允许接收该结果。Future 只是“将来完成一次”的结果容器；它不是线程、请求、取消句柄，也不是生命周期管理器。掌握这一边界，才能审查 AI 生成的网络代码，而不是看到 `async` 就默认安全。

## 1. 完成定义、学习入口与非目标

完成本章后，你应能：

1. 画出 Future 从未完成到以值或错误完成的单次状态迁移；
2. 解释 `async` 如何改变函数合同，以及 `await` 在哪里暂停当前函数；
3. 用 `try/catch/finally` 保留异步错误和清理责任；
4. 区分顺序等待、并发启动和汇总等待的成本与失败语义；
5. 准确说明 `Future.timeout` 只停止等待返回值，不取消源 Future；
6. 设计由调用方发出、由执行方检查的协作式取消协议；
7. 用 operation id 或 generation 阻止陈旧结果覆盖新状态；
8. 用 `Completer` 控制完成顺序，稳定复现成功、失败、超时、取消和竞态；
9. 指出资源所有者、取消所有者、状态提交者和日志关联标识；
10. 对 AI 生成的异步代码给出“已验证/未验证”边界。

配套入口：

- [可控 Future、取消与陈旧结果示例](../../../examples/encyclopedia/ch.dart.future-cancellation/README.md)
- [工单加载乱序与超时实验](../../../labs/encyclopedia/ch.dart.future-cancellation/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.dart.future-cancellation/README.md)

非目标：本章不讲多事件 Stream，不把 Future 描述成操作系统线程，不承诺任意第三方 API 可取消，不用固定延时替代可控测试，也不把“没有更新 UI”误写成“请求已经停止”。

## 2. 先建立一次性结果模型

同步函数调用时，调用者通常在当前调用栈中得到值或异常：

```dart
WorkOrder parse(Map<String, Object?> json) {
  // 成功返回 WorkOrder，失败同步抛出异常。
}
```

异步函数不能立即给出最终 `WorkOrder`，于是返回 `Future<WorkOrder>`：

```text
调用 load()
   │
   ├─立即得到 Future<WorkOrder>（uncompleted）
   │
   └─稍后只能完成一次
       ├─value: WorkOrder
       └─error: Object + StackTrace
```

官方文档使用 `uncompleted` 与 `completed`。完成以后不能回到未完成，也不能再换一个值。`Future<void>` 仍然有完成合同，只是成功时没有业务值；它仍可能以错误完成。`Future<T>` 的类型参数描述成功值，不描述失败类型，所以调用者必须通过文档、测试和领域异常约定知道可能失败。

Future 不等于后台任务。数据库查询、HTTP transport、Timer、文件读取或 Isolate 工作才是“源工作”；Future 只是观察其最终完成的接口。把变量设为 `null`、不再 `await` 或从页面离开，都不会自动向源工作发送停止信号。

## 3. `async` 改变的是函数合同

标记 `async` 的函数总是返回 Future。即使源码里写 `return order`，调用者看到的仍是 `Future<WorkOrder>`：

```dart
Future<WorkOrder> load(String id) async {
  final json = await gateway.fetch(id);
  return WorkOrder.fromJson(json);
}
```

执行分两段理解：进入函数后同步运行，直到遇到第一个尚未完成的 `await`；此时函数把控制权交回事件循环，返回尚未完成的 Future。被等待的 Future 完成后，后续语句被安排继续执行。`await` 不是阻塞整个 isolate；它暂停的是当前 async 函数的剩余部分。若你在 `await` 前做一段昂贵 CPU 循环，事件循环仍会卡住。

### 3.1 `await` 会展开值，也会重新抛出错误

```dart
try {
  final order = await gateway.fetch(id);
  return order;
} on TimeoutException catch (error, stack) {
  logger.warn('load timeout', error, stack);
  rethrow;
}
```

成功时 `await` 表达式产生 `T`；失败时它在等待位置抛出错误，所以普通 `try/catch` 能捕获。`rethrow` 保留原错误与堆栈；`throw error` 可能让诊断起点变差。若边界需要把 transport 异常翻译为领域错误，应该保留 cause、stack、operation id，而不是只抛一个“加载失败”。

### 3.2 避免无意的 `async void`

事件回调有时要求 `void Function()`，开发者会写：

```dart
void onPressed() async {
  await service.create();
}
```

调用者无法等待这个回调的完成，也不容易把错误纳入自己的合同。除框架明确要求的事件入口外，业务函数应返回 `Future<void>`，入口负责 `await`、记录或显式标注 fire-and-forget。静态分析规则 `discarded_futures` 能发现一部分被丢弃的 Future，但不能替代所有权设计。

## 4. `await` 的顺序就是依赖关系

以下代码严格顺序执行：

```dart
final order = await loadOrder(id);
final device = await loadDevice(order.deviceId);
```

第二步依赖第一步的 `deviceId`，顺序合理。若两个读取互不依赖，先后等待会增加总耗时：

```dart
final orderFuture = loadOrder(id);
final timelineFuture = loadTimeline(id);
final order = await orderFuture;
final timeline = await timelineFuture;
```

重点不是把两个 `await` 写在一行，而是先启动两个工作，再分别观察结果。也可使用 `Future.wait` 汇总多个同类 Future。必须决定一个失败时其他工作怎么办、成功资源如何清理、是否需要收集部分成功。当前官方 `dart:async` 文档还展示 Iterable/record 的 `.wait` 与 `ParallelWaitError`；这是版本表面，旧 SDK 或团队基线未确认前不能直接假设可用。

### 4.1 并发启动不是无限并发

若对一万个附件同时发请求，时间可能缩短，但连接、内存、服务端限流和重试风暴会失控。复杂度仍约为 O(n) 个任务，空间可能从 O(1) 顺序等待变成 O(n) 个在途 Future。工程上通常设置并发上限、批次和截止时间，而不是无界 `Future.wait`。

## 5. 错误传播与“忘记 await”

下面的 `catch` 捕获不到稍后发生的异步错误：

```dart
try {
  repository.save(order); // 返回 Future<void>，但没有 await 或 return。
} catch (error) {
  // 只包住同步调用阶段。
}
```

正确做法通常是：

```dart
try {
  await repository.save(order);
} catch (error, stack) {
  // 现在 save Future 的错误在这里被观察。
}
```

或者直接 `return repository.save(order);`，把完成责任交给上层。Future 若以错误完成而没有及时注册错误处理器，错误会进入当前 Zone 的未捕获错误路径。测试里常表现为用例已经看似结束，稍后才出现异步异常；生产中可能只留下全局 crash 日志。

不要为了“消除红字”写空 `catch`。捕获意味着你已经决定恢复、翻译、补偿或记录；若做不到，就让错误继续传播。`finally` 适合释放由当前范围拥有的资源，但清理失败可能覆盖原失败，因此要定义日志与错误优先级。

## 6. `Completer`：主要用于适配与测试控制

`Completer<T>` 允许代码显式完成一个 Future：

```dart
final completer = Completer<WorkOrder>();
final future = completer.future;

completer.complete(order);          // 成功一次
completer.completeError(error, st); // 或失败一次
```

普通 `async` 函数通常不需要手写 Completer；滥用会制造重复完成、遗漏错误和永不完成。它适合把回调式 API 适配成 Future，或在测试中控制 A/B 请求的完成顺序。测试竞态时不要写 `Future.delayed(100ms)` 猜时序；创建两个 Completer，先触发 A、再触发 B、先完成 B、最后完成 A，才是确定性证据。

Completer 的所有者负责保证每条路径最终完成且只完成一次。取消路径、超时路径、回调异常都必须纳入状态图。必要时检查 `isCompleted` 只能避免重复完成，不自动证明业务协议正确。

## 7. 超时的精确语义

官方 `Future.timeout` 合同是：创建一个新的 timeout Future；源 Future 在期限内完成，新 Future 跟随其值或错误；否则执行 `onTimeout`，或以 `TimeoutException` 完成。最关键的一句是：源 Future 可以在之后正常完成，只是它的晚到结果不再用于 timeout Future。

```dart
final visible = await source.timeout(
  const Duration(seconds: 3),
  onTimeout: () => cachedOrder,
);
```

三秒后拿到缓存不代表 `source` 停止。若 source 是 HTTP GET，它可能继续消耗连接；若是写请求，服务器甚至可能已经创建工单。超时是等待预算，不是回滚，也不是取消。

### 7.1 截止时间、单步超时和总预算

复杂流程可能经历 DNS、连接、认证刷新、业务请求与解析。每步都给 3 秒可能累计远超用户预算。更可靠的做法是计算绝对 deadline，每次操作使用剩余时间：

```dart
Duration remaining(DateTime deadline, DateTime now) {
  final value = deadline.difference(now);
  return value.isNegative ? Duration.zero : value;
}
```

测试时注入 Clock，不能依赖真实墙钟。deadline 到达后，还要执行取消协议和陈旧结果保护；单独 `.timeout` 只解决调用者何时停止等待。

## 8. Dart 没有自动附着在每个 Future 上的通用取消

Future API 本身没有 `cancel()`。这不是缺陷，而是源工作差异太大：Timer 可取消，某些 HTTP 客户端可关闭请求，文件系统操作可能不能中断，远程写入即使断开连接也可能继续。取消必须由具体 API 或你的协议定义。

协作式取消包含四个角色：

```text
调用者/生命周期所有者 ──发出 cancel(reason)──> token/signal
                                             │
执行者 <──检查信号、停止可停止资源、结束 Future──┘
状态提交者 ──检查 operation id──> 接受或丢弃结果
观测系统 <──记录 request/operation/cancel reason/cleanup result
```

调用方不能只创建 token 后从不传递；执行方不能只在函数开始检查一次；底层适配器要把信号映射到 `Timer.cancel`、客户端关闭或其他真实能力。无法停止的部分必须明确“仅放弃结果”，并继续保护状态和记录晚到完成。

## 9. 一个最小取消信号

以下示例展示合同而非通用库：

```dart
final class CancellationToken {
  bool _cancelled = false;
  Object? _reason;
  final List<void Function(Object?)> _listeners = [];

  bool get isCancelled => _cancelled;

  void throwIfCancelled() {
    if (_cancelled) throw CancelledOperation(_reason);
  }

  void onCancel(void Function(Object?) listener) {
    if (_cancelled) {
      listener(_reason);
    } else {
      _listeners.add(listener);
    }
  }

  void cancel([Object? reason]) {
    if (_cancelled) return; // 幂等
    _cancelled = true;
    _reason = reason;
    for (final listener in List.of(_listeners)) listener(reason);
    _listeners.clear();
  }
}
```

生产实现还要考虑监听器注销、重入、同步还是异步通知、清理错误、线程/Isolate 边界，以及 token 能否被复用。默认应一次操作一个 token。取消是预期控制流还是异常也需团队统一；无论选择哪种，都不能把它记录为未知系统故障。

### 9.1 执行方的检查点

```dart
Future<WorkOrder> loadOrder(String id, CancellationToken token) async {
  token.throwIfCancelled();
  final response = await transport.get('/work-orders/$id', token: token);
  token.throwIfCancelled();
  final order = decode(response);
  token.throwIfCancelled();
  return order;
}
```

检查点放在昂贵工作前后和状态提交前。CPU 循环若长期不让出执行权，即使 token 已取消也无法及时观察；应分块检查，或把合适工作移到 Isolate。检查过密也有成本，要根据取消延迟目标设计。

## 10. 放弃结果与停止工作是两道门

现实中底层工作可能不能取消，或取消只能“尽力而为”。因此必须同时有：

- 工作门：有能力时通知源工作停止，等待其清理；
- 提交门：无论源工作是否停止，旧结果都不得写入当前状态。

只做工作门不够：取消与完成可能同时发生。只做提交门也不够：资源仍可能泄漏、服务端仍承受无意义请求。两者承担不同风险。

## 11. operation id / generation 防陈旧结果

用户先查设备 A，立刻切到 B。B 快速返回，A 晚到。若两个回调都直接赋值，页面会倒退到 A。用单调 generation：

```dart
final class WorkOrderController {
  int _generation = 0;
  WorkOrder? current;

  Future<void> load(String id) async {
    final mine = ++_generation;
    final result = await repository.load(id);
    if (mine != _generation) return;
    current = result;
  }

  void invalidate() => _generation++;
}
```

这能阻止旧结果提交，却不会停止 repository。完整方案为每代创建取消信号，开始新操作时取消旧信号，并在 `await` 后检查 generation。页面销毁时使 generation 失效、触发取消，再阻止 UI 提交。

operation id 还应进入日志。若只看到“WO-A 返回 200”，却不知道它属于第几次加载，就无法证明是旧请求覆盖。

## 12. 生命周期与资源所有权

谁创建资源，谁负责关闭，除非合同明确转移。典型关系：

| 资源/状态 | 建议所有者 | 结束动作 | 必须等待吗 |
|---|---|---|---|
| 页面级加载 token | 页面状态对象 | 页面销毁/新查询时 cancel | 视清理 Future 而定 |
| Timer | 创建它的操作 | `cancel()` | 同步取消，但回调竞态仍需保护 |
| HTTP client | 应用或 repository | 按作用域 close | 通常要按 API 合同 |
| 临时文件 | 当前 use case | finally 删除/关闭 | 是，记录清理失败 |
| operation generation | 状态提交者 | 新操作/销毁时递增 | 不涉及 I/O |
| Completer | 适配器 | 每条路径完成一次 | 是，不能悬空 |

不要在 repository 每次调用都关闭应用共享 client；也不要让页面持有它无法理解的 Socket。取消协议沿调用链传递，但资源释放仍由资源所有者执行。

## 13. FactoryCare：工单详情加载合同

需求：输入工单 id，3 秒内优先显示远程结果；页面离开或 id 改变时停止可停止工作；超时显示可重试状态；任何旧结果不得覆盖新工单。

可以分层：

```text
WorkOrderPageState
  owns generation + CancellationToken
  ↓
LoadWorkOrderUseCase
  owns total deadline + error translation
  ↓
WorkOrderRepository
  owns cache/remote selection
  ↓
HttpTransport adapter
  maps cancellation to concrete client capability
```

返回值不要只用 `null` 表示所有失败。可定义 `LoadOutcome`：fresh、cached、notFound、unauthorized、deadlineExceeded、cancelled。异常保留给违反合同或无法恢复的故障，或使用统一的领域异常层。选择何种错误模型不是语法题，但必须可测试且不吞掉 cause。

### 13.1 写请求额外需要幂等

创建工单超时后，客户端不知道服务器是否成功。直接重试可能重复创建。取消连接也不能回滚远端提交。应使用幂等键、查询确认或业务状态机；UI 提交门只防本地重复展示，不能证明服务端没有副作用。

## 14. 确定性测试矩阵

| 场景 | 控制手段 | 预期判据 |
|---|---|---|
| 成功 | Completer 完成值 | Future 得到规范对象，提交一次 |
| 解析失败 | completeError | 错误类型/cause/stack 符合合同 |
| 超时 | 注入 deadline/短 fixture | 调用方得到 deadline 结果 |
| 超时后源完成 | 超时后再 complete | 源确实运行完，但不提交 |
| 主动取消 | signal 完成 | 底层 stop 计数恰为 1 |
| 重复取消 | cancel 两次 | 清理仍只执行一次 |
| A/B 乱序 | 两个 Completer | B 提交，A 被 generation 拒绝 |
| 页面销毁 | invalidate + cancel | 无 UI 更新、无未处理错误 |

计数器比“没有看到输出”更可信。测试要断言：开始次数、取消次数、清理次数、提交次数和最终状态。真实 transport 的取消能力需要集成测试，纯 Dart fake 只能证明调用协议。

## 15. 三类故障注入与首个可信证据

### 15.1 忘记 `await`

注入：从 `await repository.save()` 删除 `await`。现象可能是函数先成功返回，稍后全局报告异常。首个可信证据是 analyzer 的 `discarded_futures`（若已启用）或测试结束后的未捕获异步错误，而不是 UI 的“偶尔失败”。修复后让调用链返回/等待 Future，并重跑错误用例。

### 15.2 仅忽略结果，没有取消工作

注入：销毁页面时只把 `mounted=false`，不调用 token/transport stop。UI 可能没被更新，但取消计数为 0，底层完成日志仍出现。首个可信证据是 operation trace 和资源计数。修复是调用具体取消能力，并保留提交门；若源不可取消，报告“结果被丢弃、源工作仍完成”。

### 15.3 超时后仍写状态

注入：timeout Future 返回缓存，但源 Future 的 `.then` 仍直接赋值。首个可信证据是相同 operation id 在 deadline 后出现第二次 commit。修复把所有提交集中到检查 generation 的单一函数，并测试晚到值与晚到错误。

## 16. 诊断顺序

遇到异步问题时按证据链，不先加更长 sleep：

1. 记录 operation id、输入摘要、开始时间和当前 generation；
2. 确认函数是同步抛错还是 Future 以错误完成；
3. 查调用者是否 `await`/`return` 了 Future；
4. 查 deadline 是哪一层设置，超时后源工作是否仍存在；
5. 查 cancel 是否发出、执行方是否观察、真实资源是否停止；
6. 查所有状态写入是否经过 current-operation 判定；
7. 查 finally/cleanup 是否执行一次，是否覆盖原错误；
8. 用 Completer 固定顺序重现，再修最小责任层；
9. 重跑原红测试和相邻成功/取消场景；
10. 写明仍未验证的真实网络与生命周期条件。

## 17. 复杂度、延迟与资源预算

创建一个 Future 和继续回调有时间/空间开销，但一般业务瓶颈在 I/O 与在途数量。顺序 n 次请求总延迟近似各次之和；全并发延迟接近最慢者，但空间、连接和服务负载为 O(n)。generation 检查时间 O(1)、状态 O(1)；为每个操作保存完整历史则空间 O(n)。取消监听器数量为 m 时，广播取消通知 O(m)，应在操作结束清理引用。

超时值不是越小越好。过短会制造无意义取消/重试，过长损害体验与资源。依据业务 SLA、移动网络分位数和服务端预算设置，并区分连接、单请求和总流程 deadline。观测 p50/p95/p99，不能只用本机平均值。

## 18. AI/Vibe coding 审查边界

可以让 AI 生成 CancellationToken、repository 适配器和测试矩阵，但接受前逐项回答：

1. 这个 Future 对应什么源工作？
2. 谁可以取消，谁必须执行清理？
3. `.timeout` 后源工作会怎样？
4. 新操作如何使旧 operation 失效？
5. 写请求超时是否有幂等保证？
6. 每个 Future 错误在哪里被观察？
7. `finally` 会不会覆盖原错误？
8. 测试是否用可控完成顺序，而非固定 sleep？
9. 计数器能否证明取消和清理确实发生？
10. 哪些真实 transport/设备/版本从未运行？

AI 常生成“调用 timeout 所以已经取消”“mounted 防止重复请求”“catch 后返回 null”这类貌似可用的代码。审查者必须以 API 合同和失败测试为准，而不是以代码流畅程度为准。

## 19. 复习与 120 秒复述

复述模板：Future 表示一次将来完成的结果，状态从未完成走向值或错误，完成一次后不可改变。`async` 函数返回 Future，`await` 暂停当前函数并在等待位置传播错误，不会阻塞整个 isolate。顺序还是并发由工作何时启动决定。`Future.timeout` 创建超时结果，但源 Future 可在之后完成，所以取消必须由具体 API 或协作 token 定义。完整方案同时停止可停止工作，并用 generation 阻止任何旧结果提交。测试用 Completer 控制乱序，用计数器证明取消和清理，只把实际运行过的版本和 transport 声明为已验证。

越界反例：“页面离开后我不再读取 Future，所以 HTTP 请求已取消，服务器也一定没有创建工单。”它把丢弃观察、停止本地 transport 和回滚远程副作用混成一件事。

自测问题：

1. `Future<void>` 能否以错误完成？
2. 为什么 `try { save(); }` 可能捕获不到错误？
3. 两个 `await` 怎样判断是顺序还是并发？
4. timeout Future 和 source Future 各自会怎样完成？
5. token 已取消后新注册监听器该怎么处理？
6. generation 能解决资源泄漏吗？为什么？
7. 创建工单超时后为何仍需要幂等键？
8. 如何不用真实时间稳定复现 A/B 乱序？

## 20. 速查表

| 误解/现象 | 正确模型 | 首个证据 |
|---|---|---|
| `async` 就是新线程 | 当前 isolate 运行，await 只暂停当前函数 | CPU 重任务仍卡事件循环 |
| 丢掉 Future 等于取消 | 只是不观察；源工作可能继续 | 源完成/资源计数 |
| timeout 会终止源 Future | 只让新的 timeout Future 提前完成 | 官方 API 合同与晚到 fixture |
| mounted 能取消请求 | 只能用于阻止某些 UI 提交 | transport stop 计数为 0 |
| generation 已足够 | 防旧提交，不负责停资源 | 请求仍完成/连接仍占用 |
| catch 能抓所有异步错 | 必须 await/return 对应 Future | 未捕获 Zone 错误 |
| 并发越多越快 | 在途资源和服务端限制会反噬 | 连接数、p95、限流 |
| 取消就回滚远程写入 | 网络断开不等于业务回滚 | 幂等键与服务端审计 |

## 21. 官方资料与版本边界

以下资料于 2026-07-24 核对：

- [Asynchronous programming: futures, async, await](https://dart.dev/libraries/async/async-await)：Future 的未完成/以值或错误完成状态与 async/await 入门。
- [dart:async](https://dart.dev/libraries/dart-async)：Future 组合、错误处理与等待多个任务。
- [Futures and error handling](https://dart.dev/libraries/async/futures-error-handling)：`then`、`catchError`、`whenComplete` 的传播边界；新代码优先 async/await + try/catch。
- [`Future.timeout` API](https://api.dart.dev/dart-async/Future/timeout.html)：源 Future 超时后仍可能正常完成，是本章取消边界的核心依据。
- [Dart SDK overview](https://dart.dev/tools/sdk)：官方当前文档基线为 Dart 3.12.2，且仅支持最新 stable 的支持政策。
- [Dart SDK archive](https://dart.dev/get-dart/archive)：stable/beta/dev/main 的定位和下载档案。

稳定核心：一次性完成、async 返回 Future、await 的值/错误传播、timeout 不自动取消源、取消需具体协议、陈旧结果需显式提交门。版本表面：`.wait` 扩展、诊断规则集合、具体 SDK/Flutter 内置 Dart 版本和第三方取消 API。

## 22. 已验证与未验证

已验证：配套 example/lab/private 在本机 Dart 3.9.2 VM 运行；公开练习稳定预期红；覆盖值/错误完成、timeout 后源继续、取消幂等计数和 generation 乱序保护；正文与 Dart 3.12.2 官方 API 文档核对。

未验证：Dart 3.12.2 二进制实际运行、Flutter Widget 生命周期、真实 HTTP 客户端取消、Socket/DNS/TLS、Android/iOS 后台切换、服务端幂等、Zone 顶层错误采集、极端竞态和性能基准。进入 Flutter/网络章节时必须以目标 SDK、目标设备和实际 transport 重跑，不能把本章纯 Dart fixture 当成真机证据。
