---
schema_version: 2
edition: 2026.2-draft
id: ch.dart.streams-isolates
title: Stream、背压边界、Isolate 与并发
responsibility: 处理单订阅/广播 Stream、订阅取消、事件速率和 Isolate 消息边界，区分并发事件流与 CPU 隔离，不承诺不存在的通用背压。
volume: '11'
order: 8
level: L2+
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.dart.streams-isolates.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.dart.future-cancellation
version_surfaces:
- dart-stable
route_tags:
- zero-base
- accelerated-48
- reference
generated_by: scripts/generate-curriculum.rb
generated_spec_digest: 8f5eb7471b6795c430ae6bfc80bc296ca1aa29997fe78086a57f3b06739756c1
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“Stream、背压边界、Isolate 与并发”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - dart-stream-lifecycle
  - dart-isolate-message
  covers_topics:
  - dart.stream-subscription
  - dart.single-broadcast-stream
  - dart.stream-transform
  - dart.stream-cancel
  - dart.stream-rate-boundary
  - dart.isolate
  - dart.sendable-message
  - dart.isolate-error-exit
  - dart.cpu-work-offload
  - dart.future-state
  uses_capabilities:
  - mobile.dart-language
  - mobile.dart-future-cancellation
  - mobile.dart-streams-isolates
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现可取消的工单事件流和一个 Isolate CPU 统计任务并记录生命周期；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - dart-stream-lifecycle
  - dart-isolate-message
  covers_topics:
  - dart.stream-subscription
  - dart.single-broadcast-stream
  - dart.stream-transform
  - dart.stream-cancel
  - dart.stream-rate-boundary
  - dart.isolate
  - dart.sendable-message
  - dart.isolate-error-exit
  - dart.cpu-work-offload
  - dart.future-state
  uses_capabilities:
  - mobile.dart-language
  - mobile.dart-future-cancellation
  - mobile.dart-streams-isolates
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: stream-event-trace-subscription-leak-check-isolate-message-test
- id: diagnose
  kind: fault-diagnosis
  text: 面对“广播/单订阅误用、未取消订阅或发送不可传递对象”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - dart-stream-lifecycle
  - dart-isolate-message
  covers_topics:
  - dart.stream-subscription
  - dart.single-broadcast-stream
  - dart.stream-transform
  - dart.stream-cancel
  - dart.stream-rate-boundary
  - dart.isolate
  - dart.sendable-message
  - dart.isolate-error-exit
  - dart.cpu-work-offload
  - dart.future-state
  uses_capabilities:
  - mobile.dart-language
  - mobile.dart-future-cancellation
  - mobile.dart-streams-isolates
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Stream、背压边界、Isolate 与并发

> 本章状态为 `drafting`。稳定语义于 2026-07-24 对照 Dart 3.12.2 官方文档；配套程序实际在本机 Dart 3.9.2 stable 的 Dart Native VM 上运行。Isolate 的绿灯只覆盖 macOS arm64 本机，不代表 Dart Web、Flutter Web、Android、iOS 或长期 worker 已验证。本章不承诺 Dart Stream 具有跨所有生产者的通用背压。

Future 解决“一次完成”，Stream 表示“随时间到来的零个、一个或多个事件”。但 Stream 不是一个装满数据的 List：真正持有运行中关系的是 `StreamSubscription`。Isolate 又是另一层：它有独立内存和事件循环，通过消息通信，可把 CPU 工作放到其他核心。把 Stream、线程、并行、后台任务和广播混为一谈，是跨端应用最常见的并发误区。

## 1. 完成定义与边界

完成本章后，你应能：

1. 区分 Stream 描述、事件源和活动订阅；
2. 选择单订阅或广播，并说明迟到监听者会看到什么；
3. 用 `map/where/asyncMap` 等变换而不吞掉错误与完成；
4. 持有并等待 `StreamSubscription.cancel()` 的清理 Future；
5. 解释 pause 可能向上游传递，也可能只导致缓冲；
6. 为高频事件明确采样、合并、丢弃、排队或限制生产策略；
7. 区分事件循环并发和 Isolate 多核并行；
8. 选择 `Isolate.run` 或长期 `spawn + port`，估算创建与消息成本；
9. 设计可传递消息、结果、错误和退出协议；
10. 用事件轨迹、清理计数和 Isolate 错误测试诊断泄漏。

配套入口：

- [Stream 生命周期与 Isolate 示例](../../../examples/encyclopedia/ch.dart.streams-isolates/README.md)
- [事件速率、取消和 Isolate 故障实验](../../../labs/encyclopedia/ch.dart.streams-isolates/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.dart.streams-isolates/README.md)

非目标：不讲 Flutter Widget 绑定，不用 Stream 替代所有状态，不将广播误称为历史回放，不把 pause 宣称为网络级背压，不在 Dart Web 上承诺 Native Isolate，也不把 worker isolate 当共享内存线程。

## 2. Stream 的三层模型

```text
事件源 source
  产生 data / error / done
          │
Stream<T> 描述如何订阅与变换
          │ listen()
StreamSubscription<T>
  当前监听关系：onData/onError/onDone、pause/resume/cancel
```

`Stream<T>` 本身常是惰性的。官方文档指出，调用 `listen()` 后得到活动订阅；订阅可以暂停、恢复或取消。事件有三类：数据事件携带 T；错误事件携带错误和可能的 StackTrace；完成事件表示不会再有事件。完成不是一个 `null` 数据，取消也不等于源自然完成。

一个订阅应有明确所有者。页面订阅 repository 事件时，页面生命周期通常拥有 subscription；共享应用服务若内部监听平台连接，则服务拥有它。把 `listen()` 返回值丢掉，会失去取消、暂停和清理证据。

## 3. 单订阅 Stream

单订阅流通常表示一个有序过程，例如读取文件、解码一段响应、按序接收某个操作的阶段。一般只允许一次监听；第二次 `listen` 会抛状态错误。它可以保留开始前的事件语义，且上游通常更有机会响应 pause。

```dart
Stream<WorkOrderEvent> loadTimeline(String id) async* {
  yield LoadStarted(id);
  final events = await repository.fetchTimeline(id);
  for (final event in events) {
    yield event;
  }
  yield LoadCompleted(id);
}
```

`async*` 函数返回 Stream。每个 `yield` 发一个数据事件；抛出的异常成为错误事件；函数正常结束发 done。监听方用 `await for` 时，错误会在循环处抛出，退出循环后订阅结束。提前 `break` 时生成器的取消/清理必须被测试。

不要为了“以后也许多人监听”就立即 `.asBroadcastStream()`。它改变订阅语义、暂停与事件丢失边界，并不自动重放旧数据。

## 4. 广播 Stream

广播流允许多个同时监听者，适合应用级连接状态、设备传感器或平台事件总线。监听者只收到其订阅期间的事件；广播通常不会替迟到者保存历史。示例：A 先订阅，收到 `assigned`；B 后订阅，只能从之后的 `in-progress` 开始。若业务要求新页面立即看到最新状态，需要在 Stream 外保存当前快照，或选用明确的 replay/state 抽象。

```dart
final controller = StreamController<WorkOrderEvent>.broadcast(
  onListen: startSource,
  onCancel: stopWhenLastListenerLeaves,
);
```

要理解 `onCancel` 是最后一个监听者离开还是单个监听关系清理，取决于具体 controller 合同。每个监听者拥有自己的 subscription；一个监听者 pause 不能被想当然地扩展为暂停所有人的真实设备源。广播源若持续产生，暂停的订阅可能缓冲，导致内存增长。

### 4.1 单订阅/广播选择表

| 问题 | 单订阅倾向 | 广播倾向 |
|---|---|---|
| 同时几个消费者 | 一个 | 多个 |
| 迟到者需要过去事件 | 由源过程决定 | 通常不会收到 |
| pause 能否传上游 | 通常更可能 | 常只影响该订阅 |
| 用途 | 单次处理管线 | 热事件/共享平台信号 |
| 典型风险 | 第二次监听、未清理 | 丢历史、缓冲、监听泄漏 |

## 5. 变换：保持事件合同

Stream 常用变换：

```dart
final urgentIds = source
    .where((event) => event.priority >= 4)
    .map((event) => event.workOrderId)
    .distinct();
```

`where` 筛选数据事件；`map` 一对一转换；`distinct` 跳过相邻相等数据。错误和 done 仍沿管线传播，除非变换显式处理。若 mapper 抛错，通常生成错误事件，而不是让整个进程同步崩溃。

异步映射需要确认顺序和并发。`asyncMap` 通常按源事件顺序等待每个转换；如果需求是多个并发请求后按完成顺序输出，不能仅凭名字猜，要选择或实现明确合同，并控制最大在途数。对设备更新流逐事件发 HTTP 可能形成排队，应先定义“每个事件都必须处理”还是“只要最新”。

### 5.1 自定义 `StreamTransformer`

当多个地方重复同一事件规则，可以封装 transformer，但它必须定义：数据映射、错误是否翻译、done 时是否 flush、取消怎样向上游传播、pause 是否产生缓存。一个只覆盖正常 `onData` 的 AI 生成 transformer 往往会吞错误或不关闭下游。

## 6. `listen` 与 `await for`

`await for` 适合在 async 函数中顺序消费：

```dart
await for (final event in repository.watch(id)) {
  await persist(event);
}
```

循环每次等待处理完成后再继续读取语义清晰，但源是否减速仍取决于上游 pause 支持。若需要从生命周期外取消，`listen` 返回 subscription 更直接：

```dart
late final StreamSubscription<WorkOrderEvent> subscription;
subscription = repository.watch(id).listen(
  applyEvent,
  onError: reportStreamFailure,
  onDone: markDisconnected,
);
```

回调签名、错误处理和 `cancelOnError` 必须显式决定。没有 `onError` 的错误会进入未处理路径；错误不一定意味着 Stream 自动 done。不要在 `onData` 中启动 Future 后丢弃；异步处理失败可能逃出订阅合同并打乱顺序。

## 7. 订阅取消是异步清理合同

官方 `StreamSubscription.cancel()` 返回 `Future<void>`。调用后订阅不再接收事件；源可能需要异步关闭文件、Socket 或平台监听，清理完成后 Future 才完成。因此：

```dart
await subscription.cancel();
await deleteTemporaryFile();
```

若文件流取消后要删除文件，必须等待取消清理。忽略返回 Future 会出现“偶尔文件仍被占用”。清理本不应失败，但 API 明确允许返回的 Future 以错误完成，所以生产代码要记录。

取消订阅只取消该监听关系。是否停止事件源取决于源和其他监听者；广播流仍有其他订阅时通常继续。取消也不能撤销已经交给 `onData` 的副作用。

## 8. pause/resume 与“背压”边界

`subscription.pause()` 暂停向该监听者交付事件。官方 API 说明：暂停期间收到的事件会被缓冲；非广播流通常会把暂停通知上游，使其有机会停止产生。关键词是“通常”和“有机会”，不是通用保证。

官方创建 Stream 指南进一步警告：`StreamController` 若生产者不尊重 pause，会继续 add，缓冲可能无限增长。广播订阅暂停时，为避免缓冲，若中间事件不重要，官方 API 建议取消并在需要时重新监听。

因此不要简单写“Dart Stream 自带背压”。背压意味着消费方能可靠限制生产方速率，但不同 Stream 源行为不同。网络服务器、传感器广播或外部消息源可能不会因为一个本地订阅 pause 而减速。

### 8.1 高频事件的五种策略

| 策略 | 适用语义 | 代价/风险 |
|---|---|---|
| 全部排队 | 每个审计事件都不可丢 | 内存与延迟可能增长 |
| 限制生产 | 可控制文件/自建源 | 上游必须支持 pause/ack |
| 采样 | 指标预览 | 丢失中间变化 |
| debounce | 用户停止输入后查询 | 延迟，持续输入可能不触发 |
| latest/switch | UI 只关心最新查询 | 旧任务仍需取消/丢弃结果 |
| 批处理 | 聚合上传/统计 | 增加窗口延迟和失败重试复杂度 |

策略必须来自业务语义。设备报警不能随意 debounce；进度动画可以采样；搜索建议通常只关心最新。实现前写清容量、溢出行为和可观测计数。

## 9. StreamController 的资源所有权

手写 controller 时要把启动/暂停/恢复/取消映射到真实资源：

```dart
late StreamController<int> controller;
Timer? timer;

controller = StreamController<int>(
  onListen: () => timer = Timer.periodic(
    const Duration(seconds: 1),
    (_) => controller.add(readValue()),
  ),
  onPause: () => timer?.cancel(),
  onResume: restartTimer,
  onCancel: () {
    timer?.cancel();
    timer = null;
  },
);
```

这只是示意。恢复时要防重复 Timer；关闭 controller 后不能 add；源出错要 `addError(error, stack)`；最后一个监听者离开要释放；同步 controller 可能重入，除非理解约束，不要随意 `sync: true`。控制器自身也要 `close()`，但 close 和订阅 cancel 是不同方向的生命周期动作。

## 10. 事件循环并发不等于多核并行

一个 isolate 有自己的内存和事件循环。Future、Timer、I/O completion 和 Stream 事件让多个操作交错推进，但同一时刻 Dart 代码仍在该 isolate 的执行线程上运行。一个 500ms 的同步 JSON 聚合会阻塞事件循环，导致 UI、Timer 和 Stream 回调延迟；在函数前加 `async` 不会改变。

```text
main isolate event loop
  event A handler ──短执行──┐
  microtasks               │ 交错，不共享两个 Dart 栈同时跑
  event B handler ──短执行──┘

worker isolate event loop  ← 可在其他核心并行执行 CPU 工作
```

并发是多个任务时间上重叠推进；并行是多个核心同时执行。I/O 通常用 async 即可；CPU 密集工作才考虑 Isolate。把每个 HTTP 请求放进 Isolate 通常只有创建和拷贝开销。

## 11. Isolate 的核心模型

官方说明：所有 Dart 代码都在 isolate 内运行；新 isolate 有独立内存和独立事件循环，只能消息通信，没有共享可变状态。它类似 actor，而不是共享内存线程，因此一般不需要 mutex 保护 Dart 对象。但逻辑竞态仍存在，例如两个消息都基于旧版本提交到服务器。

Dart Native 实现 Isolate；Dart Web 有不同的并发边界，Flutter Web 不支持这里描述的多 Isolate 模型。平台判断必须进入设计与测试报告。

### 11.1 `Isolate.run`

一次 CPU 任务优先：

```dart
final summary = await Isolate.run(
  () => aggregateWorkOrders(serializableInput),
);
```

它返回 Future，因为主 isolate 继续运行；callback 的结果或错误通过消息回到调用方。创建 isolate、传输输入和结果都有成本，小任务可能比直接执行更慢。应基于事件循环卡顿和基准证据，不因“可以并行”就使用。

### 11.2 `Isolate.spawn` 与长期 worker

若反复执行昂贵任务，长期 worker 可摊薄启动成本，但你必须自己设计：ready 握手、request id、reply port、错误通道、退出通知、超时、取消、关闭和意外退出后的在途请求处理。端口忘记关闭会让进程或资源残留；请求没有 id 会把响应交错到错误调用者。

## 12. 消息可传递性

不同 isolate 不共享对象引用；消息要满足 sendable 合同。当前官方并发文档说明，通过 `SendPort` 可发送几乎所有 Dart 对象，但包含原生资源的对象、`Socket`、`ReceivePort`、`DynamicLibrary`、多种 FFI/Finalizer/UserTag 类型及标记为不可发送的实例存在例外。具体列表属于版本表面，必须查当前 `SendPort.send` API。

工程上仍建议消息使用小而明确的不可变结构：基本值、List/Map 数据、record 或专用 DTO；不要把巨大的对象图、client、数据库连接或带闭包状态的服务对象发过去。序列化/复制会占时间和内存。`TransferableTypedData` 等优化只在理解平台和所有权转移后使用。

```dart
typedef AggregateRequest = ({String requestId, List<int> priorities});
typedef AggregateReply = ({String requestId, int urgentCount});
```

消息包含协议版本和 request id。消费者先验证 shape，再使用；即使发送端是同仓库，独立 isolate 边界也可能随版本漂移。

## 13. Isolate 的错误和退出

`Isolate.run` 会把 callback 的错误反映到返回 Future，调用方必须 await/catch。低层 spawn 需要设置错误/退出监听，区分：业务失败响应、worker 未捕获错误、worker 正常退出、主端主动 kill、进程终止。只监听业务 reply port 会让 worker 崩溃后 Future 永远悬空。

长期 worker 的最小状态机：

```text
starting -> ready -> accepting -> closing -> closed
                  \-> failed
```

在 ready 前发请求要排队或拒绝；closing 后拒绝新请求；failed 时让所有在途 Completer 以带 cause 的错误完成；close 要等待端口和 worker 退出。若直接 `kill`，finally 是否运行、外部资源是否清理要按具体 API 验证，不能猜。

## 14. 取消 Isolate 工作

Isolate Future 与普通 Future 一样不自带通用取消。一次 `Isolate.run` 没有让业务代码随时拿 token 的魔法；长期 worker 可通过控制端口发送 cancel(requestId)，worker 在分块 CPU 循环中检查。若必须强制 kill，要定义未完成工作、临时资源和响应 Future 如何结束。

```dart
for (var i = 0; i < records.length; i++) {
  if (i % 1000 == 0 && cancelledIds.contains(requestId)) {
    sendCancelled(requestId);
    return;
  }
  aggregate(records[i]);
}
```

检查间隔决定取消延迟与开销。CPU 函数若调用不可中断原生代码，控制消息也无法及时执行。状态提交仍需 generation/request id，kill 不能代替陈旧结果保护。

## 15. FactoryCare：事件流与统计任务

### 15.1 工单详情事件流

页面需要初始快照加实时更新。可以让 repository 返回单订阅的页面流：先读取缓存/远程快照，再桥接共享连接的事件。共享连接本身可能是广播；repository 为每个页面维护过滤订阅和当前版本。

关键合同：

- 事件含 workOrderId、sequence/version、event type 和 trace id；
- 重连后从已知 version 补洞，不能假设广播保留历史；
- 重复事件按 event id 幂等；
- 越序事件缓存、重取或拒绝，策略明确；
- 页面取消后 repository 的页面订阅计数归零；
- 最后一个消费者离开时是否断共享连接由应用策略决定。

### 15.2 CPU 统计

离线导入十万条工单并按状态聚合可能阻塞 UI。先测同步耗时；超过帧预算再把纯 CPU 聚合和可传递输入放到 `Isolate.run`。文件读取本身已是异步 I/O，不应为了“后台”把所有 I/O 放 Isolate。输入解析、传输和结果大小也计入总成本。

## 16. 高频事件容量设计

为一个流写容量合同：

```text
源峰值：每秒 500 事件
消费者持续能力：每秒 200
允许延迟：2 秒
必须保留：CLOSED/安全告警
可合并：同设备进度更新
容量：400
溢出：保留关键事件；同设备普通更新只留最新
指标：received/processed/coalesced/dropped/maxQueue/lag
```

若不写，系统只会在压力下无声堆积。StreamController 缓冲不是容量规划。处理不可丢事件时，可能需要服务端消费确认、持久队列或拉取协议，而非仅靠进程内 Stream。

## 17. 确定性测试矩阵

| 场景 | Fixture | 判据 |
|---|---|---|
| 数据顺序 | controller 依次 add | 轨迹严格一致 |
| 错误 | addError | error 类型/stack 被观察 |
| 完成 | close | onDone 一次、无后续事件 |
| 单订阅误用 | 第二次 listen | 在预期阶段失败 |
| 广播迟到 | B 后订阅 | B 不收到历史 A |
| pause | pause 后 add | 恢复前不交付；缓冲策略记录 |
| cancel | cancel 两次/一次 | 清理计数符合合同 |
| 高频溢出 | 人工推送超过容量 | 丢弃/合并指标准确 |
| Isolate 结果 | 小纯函数 | 内容与同步 oracle 一致 |
| Isolate 错误 | callback 抛错 | 调用方 Future 失败 |
| worker 退出 | 模拟 exit | 所有在途请求确定失败 |

测试结束要检查未关闭 controller、subscription、ReceivePort 和 worker 数量。仅断言收到了期望事件，不能证明没有泄漏。

## 18. 三类故障注入

### 18.1 单订阅与广播误用

把一个冷的单订阅请求流转换为广播，第二个监听者迟到后缺少初始值。首个可信证据是带时间/订阅 id 的事件轨迹，而非“页面偶尔空”。修复不是盲目缓存所有事件，而是选择正确抽象：每订阅重建、显式当前快照，或真正共享热源。

### 18.2 未取消订阅

页面多次进入后事件处理次数成倍增长。首个可信证据是 active subscription 计数和同一 event id 被多个旧 listener 处理。修复由创建者保存 subscription，在生命周期结束 `await cancel()`，并让测试确认清理计数归零。

### 18.3 不可传递对象或错误出口缺失

把 Socket/client/ReceivePort 或复杂服务对象发给 worker，发送阶段失败；或者 worker 崩溃而主端只等 reply。首个可信证据分别是 `SendPort.send`/spawn 错误与 error/exit port 轨迹。修复为最小可传递 DTO，并完整实现业务 reply、error、exit 三条通道。

## 19. 诊断流程

1. 标记 stream id、subscription id、source id、request id；
2. 写出期望的 data/error/done/cancel 顺序；
3. 确认是单订阅、广播还是多订阅构造；
4. 统计监听者、缓存队列、事件延迟和清理次数；
5. 查 pause 是否传到源，还是只在订阅缓冲；
6. 查异步 onData 是否被等待，错误是否逃逸；
7. 对 Isolate 记录 spawn、ready、request、reply/error、exit；
8. 缩小消息为基本结构，验证可传递性和大小；
9. 用同步 oracle 对比 Isolate 结果；
10. 修复后重跑原故障、取消、完成与资源归零检查。

不要靠 `print` 的偶然顺序推断所有事件循环语义；测试保存结构化轨迹并对序列断言。不要用不断增加内存限制掩盖无限缓冲。

## 20. 复杂度与资源预算

对 n 个事件做 `map/where` 通常时间 O(n)，若只流式处理，额外空间可为 O(1)；调用 `toList()` 则 O(n) 空间。distinct 的连续比较可能 O(1) 状态；全局去重 Set 为 O(u) 空间。缓冲 q 个事件占 O(q)，没有容量时 q 可无界。

Isolate 创建有固定启动成本；传输输入/结果成本取决于对象图大小。CPU 任务时间仍是 O(f(n))，只是移出主事件循环，并不让算法免费变快。拆太多小任务会让启动和消息成本主导；长期 worker 减少启动成本，却增加端口、错误和关闭复杂度。通过基准选择，而非固定阈值。

资源清单：StreamController、StreamSubscription、Timer、Socket、ReceivePort、SendPort、worker isolate、在途 Completer、事件缓冲。每项写创建者、关闭者、失败路径和可观察计数。

## 21. AI/Vibe coding 审查清单

让 AI 生成流或 worker 后，逐项追问：

1. 这是单订阅还是广播？迟到者看到什么？
2. 谁持有 subscription，何时 await cancel？
3. error 与 done 各走哪条路径？
4. onData 返回 Future 时是否被正确编排？
5. pause 会阻止生产还是只缓冲？证据是什么？
6. 高频输入的容量和溢出策略是什么？
7. 任务是 I/O 还是 CPU，为什么需要 Isolate？
8. 消息是否可传递、是否过大、是否带 request id？
9. worker 崩溃/退出时在途 Future 怎么完成？
10. Dart Web 与真机哪些未运行？

常见 AI 幻觉包括：“广播会把最后一条自动给新监听者”“pause 就会通知网络服务器停止”“Isolate 共享同一个 singleton”“async 已经把 CPU 工作放后台”。这些都必须用官方合同与失败实验纠正。

## 22. 120 秒复述与复习

复述模板：Stream 表示多事件序列，真正的活动关系是 `StreamSubscription`，它拥有 pause/resume/cancel。单订阅适合一个有序过程，广播允许多个当前监听者但通常不回放历史。pause 可能让非广播上游减速，也可能只缓冲，因此 Dart Stream 没有跨所有来源的通用背压；高频事件必须显式定义容量和丢弃/合并策略。Future/Stream 在一个 isolate 的事件循环上实现并发，CPU 重任务仍会阻塞。Native Isolate 有独立内存和事件循环，只通过可传递消息通信；一次计算优先 `Isolate.run`，长期 worker 才用 spawn/port，并实现 ready、request、reply/error、exit 和 close。测试要断言事件轨迹与资源归零。

越界反例：“把 WebSocket 变成 broadcast 并在页面上 pause，就能让服务器停止发送，且新页面会自动收到所有历史事件。”它同时虚构背压与回放合同。

复习题：

1. Stream 与 subscription 谁代表活动监听？
2. 广播流的迟到监听者为什么可能丢事件？
3. `cancel()` 为什么要 await？
4. pause 在什么情况下只会扩大缓冲？
5. `asyncMap` 应审查哪两个顺序问题？
6. Future 并发和 Isolate 并行有何区别？
7. 为什么 HTTP I/O 通常不需要 Isolate？
8. worker 意外退出后如何让调用方不永远等待？

## 23. 速查表

| 现象/误解 | 首个可信证据 | 修复方向 |
|---|---|---|
| 页面进入越多回调越多 | active subscription/事件 id | 生命周期 await cancel |
| B 监听缺第一条 | 订阅时刻与广播轨迹 | 快照 + 热事件或正确抽象 |
| pause 后内存上涨 | queue length/lag | 源尊重 pause 或限容/取消 |
| 错误消失 | onError/Zone 轨迹 | 明确错误通道 |
| UI 仍卡顿 | 主 isolate CPU profile | 纯 CPU 工作评估 Isolate |
| Isolate 更慢 | spawn/传输/计算分段耗时 | 合并任务或直接执行 |
| worker 请求悬空 | 缺 error/exit 事件 | 完整失败与退出协议 |
| 消息发送失败 | SendPort 错误与消息类型 | 最小可传递 DTO |
| Web 无多 Isolate | 平台目标 | Web 并发采用对应方案 |

## 24. 官方资料与版本边界

资料于 2026-07-24 核对：

- [Asynchronous programming: Streams](https://dart.dev/libraries/async/using-streams)：`listen`、数据/错误/done 与订阅 pause/resume/cancel。
- [Creating streams in Dart](https://dart.dev/libraries/async/creating-streams)：controller 生命周期、尊重 pause，以及不尊重 pause 时缓冲可能增长。
- [`StreamSubscription.pause` API](https://api.dart.dev/dart-async/StreamSubscription/pause.html)：暂停缓冲、非广播通常通知源、广播暂停的风险。
- [`StreamSubscription.cancel` API](https://api.dart.dev/dart-async/StreamSubscription/cancel.html)：取消后停止接收，返回 Future 等待源清理。
- [Concurrency in Dart](https://dart.dev/language/concurrency)：事件循环、独立内存 Isolate、Native 平台边界、`Isolate.run` 与 `spawn` 选择。
- [Isolates](https://dart.dev/language/isolates)：短任务与长期 port 通信、启动和消息成本。
- [`Stream.multi` API](https://api.dart.dev/dart-async/Stream/Stream.multi.html)：每次监听获得独立 controller 的多订阅构造边界。
- [Dart SDK overview](https://dart.dev/tools/sdk)：官方资料基线 Dart 3.12.2 与 latest-stable 支持政策。

稳定核心：data/error/done、订阅所有权、单订阅/广播差异、取消清理 Future、pause 不保证通用背压、Isolate 隔离内存与消息通信。版本表面：可传递对象例外清单、Web 并发实现、具体 SDK 优化、`Stream.multi`/Isolate API 的补丁行为。

## 25. 已验证与未验证

已验证：本机 Dart 3.9.2 Native VM 运行单订阅变换、广播迟到边界、pause 后恢复顺序、取消清理计数、`Isolate.run` 结果与错误；公开练习稳定预期红；正文对照 Dart 3.12.2 官方资料。

未验证：Dart 3.12.2 二进制执行、Dart Web/Flutter Web、长期 `Isolate.spawn` worker、真实 Socket/WebSocket/传感器、Android/iOS 调度与后台限制、TransferableTypedData、大对象传输基准、生产高频流背压、服务端重放和断线补偿。纯内存 StreamController 不能证明真实源会尊重 pause；一次 Isolate 绿灯不能证明性能改善。
