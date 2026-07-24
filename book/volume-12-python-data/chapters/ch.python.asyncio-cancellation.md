---
schema_version: 2
edition: 2026.2-draft
id: ch.python.asyncio-cancellation
title: asyncio、Task、超时、取消与结构化并发边界
responsibility: 解释 coroutine、event loop、Task、TaskGroup、超时和取消传播，保证子任务有所有者且取消后执行清理，不把线程阻塞代码直接放入事件循环。
volume: '12'
order: 14
level: L2+
status: drafting
path: book/volume-12-python-data/chapters/ch.python.asyncio-cancellation.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.exceptions-context
version_surfaces:
- python-3.14
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“asyncio、Task、超时、取消与结构化并发边界”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - python-asyncio-task
  - python-asyncio-cancel
  covers_topics:
  - python.coroutine-await
  - python.event-loop
  - python.task
  - python.task-group
  - python.async-error-propagation
  - python.async-timeout
  - python.cancelled-error
  - python.cancellation-cleanup
  - python.structured-concurrency
  - python.blocking-call-boundary
  uses_capabilities:
  - python.language
  - python.io-errors
  - python.asyncio-cancellation
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现并发加载工单详情的 TaskGroup，并用事件控制超时、失败和取消顺序；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - python-asyncio-task
  - python-asyncio-cancel
  covers_topics:
  - python.coroutine-await
  - python.event-loop
  - python.task
  - python.task-group
  - python.async-error-propagation
  - python.async-timeout
  - python.cancelled-error
  - python.cancellation-cleanup
  - python.structured-concurrency
  - python.blocking-call-boundary
  uses_capabilities:
  - python.language
  - python.io-errors
  - python.asyncio-cancellation
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: controlled-event-timeout-fixture-task-leak-check
- id: diagnose
  kind: fault-diagnosis
  text: 面对“吞 CancelledError、创建无所有者 Task 或阻塞事件循环”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - python-asyncio-task
  - python-asyncio-cancel
  covers_topics:
  - python.coroutine-await
  - python.event-loop
  - python.task
  - python.task-group
  - python.async-error-propagation
  - python.async-timeout
  - python.cancelled-error
  - python.cancellation-cleanup
  - python.structured-concurrency
  - python.blocking-call-boundary
  uses_capabilities:
  - python.language
  - python.io-errors
  - python.asyncio-cancellation
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# asyncio、Task、超时、取消与结构化并发边界

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《异常、上下文管理器与资源清理》](ch.python.exceptions-context.md)：Task 失败、取消传播和 finally 清理依赖异常与资源模型。
<!-- END GENERATED LEARNING PREREQUISITES -->

> `async def` 不会让代码自动并行，`create_task()` 也不是“扔到后台就不管”。asyncio 是一套协作式并发模型：协程在明确的等待点交还控制权，事件循环安排可运行任务，任务失败和取消必须沿所有权传播。本章从零建立 coroutine、event loop、Task、TaskGroup、timeout 和 cleanup 的心智模型，并把“结束后无悬空任务”作为可验证合同。

## 1. 先判断任务是否真的适合 asyncio

并发的目标不是让每行代码更快，而是在一个工作等待 I/O 时让另一个工作前进。HTTP 请求、数据库驱动、消息队列和异步文件/Socket API经常包含等待，适合事件循环；纯 Python 大量计算会持续占用执行线程，直接放入事件循环反而让所有请求停顿。

假设 Python AI 辅助服务需要向三个只读端点加载工单摘要、设备派生特征和知识索引状态。顺序等待总耗时接近三次延迟之和；若三项彼此独立且客户端支持异步 I/O，可以并发等待，耗时接近最慢一项。但如果第二项依赖第一项返回的设备 ID，就不能为了“并发”提前发错请求。

asyncio 主要提供**并发**，不是自动的多核 CPU **并行**。一个事件循环线程在任意时刻通常只执行一个 Task 的 Python 代码；Task 遇到能暂停的 `await` 才让出。CPU 密集推理应使用支持异步调用的外部服务、合适的线程/进程/原生库边界，并测量 GIL、库是否释放 GIL与序列化成本。

## 2. 普通函数、协程函数和协程对象

普通 `def f()` 调用后立即执行函数体并返回值。`async def fetch()` 定义**协程函数**；调用 `fetch()` 并不会完整执行请求，而是创建一个**协程对象**。协程对象必须被 `await`、交给 Task，或由其他 asyncio API负责，否则可能出现“coroutine was never awaited”警告，工作实际没有完成。

```python
async def fetch_order(order_id: str) -> dict[str, object]:
    ...

coro = fetch_order("WO-42")   # 只是协程对象
result = await coro            # 在 async 函数内部等待它
```

`await` 只能写在异步上下文中。程序最外层常用 `asyncio.run(main())` 创建事件循环、运行主协程并完成收尾。Web 框架通常已经拥有事件循环，处理函数里不能再随意调用 `asyncio.run()` 嵌套新循环；应 `await` 当前框架认可的异步接口。

类型标注也要读准确：调用 `async def load() -> WorkOrder` 得到的调用结果是 coroutine/awaitable，真正 `await load()` 后得到 `WorkOrder`。IDE 显示返回标注不等于调用时已经有值。

## 3. 事件循环与协作式调度

事件循环维护可运行回调、计时器和 I/O完成通知。一个 Task 执行到 `await` 某个尚未完成的 Future时暂停；事件循环转而运行其他就绪 Task。等 Future 完成，原 Task再次进入就绪队列。调度顺序不应成为业务正确性的隐藏前提。

```text
Task A: 运行 -> await socket -------> 就绪 -> 继续
Task B:          运行 -> await timer ---------> 继续
event loop: 选择当前就绪工作并轮流推进
```

`await` 一个已经完成的对象可能几乎不让出；在巨大纯 Python 循环中偶尔写普通函数也不会自动公平。需要 I/O等待的代码调用真正异步 API；需要长计算的代码移出事件循环。用 `await asyncio.sleep(0)` 人工让出只能是有证据的特殊策略，不能掩盖错误架构。

事件循环是响应性的共享资源。一个同步 `time.sleep(2)`、阻塞 HTTP 客户端、同步数据库驱动或长 CPU循环会让同循环中的超时、心跳和其他请求都无法按时执行。诊断时要看 loop lag 和 Task 堆栈，不只看单个函数耗时。

## 4. Coroutine、Future 与 Task 的关系

协程描述可暂停的计算；Future 表示稍后得到一个值或异常的低层占位；Task 把协程安排到事件循环并保存其状态、结果、异常和取消请求。日常应用代码主要编写协程，通过 `TaskGroup.create_task()` 或 `asyncio.create_task()` 创建 Task，通常不手工实例化 Task/Future。

直接 `await load_a(); await load_b()` 是顺序。先创建两个 Task 再等待，才能让两个协程交错推进：

```python
task_a = asyncio.create_task(load_a(), name="load-a")
task_b = asyncio.create_task(load_b(), name="load-b")
result_a = await task_a
result_b = await task_b
```

但这段代码仍有所有权缺口：创建 A 后创建 B 失败怎么办；等待 A 时 B先失败怎么办；父任务被取消时谁收尾？结构化并发用 TaskGroup 把创建、等待、失败和退出放在一个词法作用域中，通常更安全。

## 5. 每个 Task 必须有所有者

Python 3.14 官方文档提醒：事件循环只保存 Task 的弱引用，使用 `create_task()` 时要保存引用；可靠“fire-and-forget”需要放入集合，并在完成时移除。更重要的是，业务工作几乎都不应真正无人关心。所有者决定：何时开始、何时等待、父请求结束时如何取消、失败交给谁、日志如何关联。

短生命周期的相关任务优先放 TaskGroup。确需跨请求后台任务时，交给应用级 supervisor：保存强引用；设容量与关闭流程；消费异常；提供健康指标；服务停止时取消并等待。不要在 FastAPI 路由中 `asyncio.create_task(write_business_fact())` 后立即返回 202，却没有队列持久化、幂等和失败处理。

Task 名称应包含动作与脱敏关联 ID，便于调试，但不能含 token、用户正文或完整提示词。完成回调必须调用 `task.result()` 或通过统一 supervisor 收集异常，否则会出现“Task exception was never retrieved”。

## 6. TaskGroup 的结构化并发合同

`asyncio.TaskGroup` 是异步上下文管理器。在 `async with` 块内通过 `tg.create_task()` 创建相关任务；退出块时会等待所有成员。若某个成员以 `CancelledError` 之外的异常失败，TaskGroup 会取消剩余成员；收尾后把非取消异常组成 `ExceptionGroup` 或 `BaseExceptionGroup` 抛出。父代码不会在孩子未结束时悄悄离开作用域。

```python
async def load_bundle(order_id: str) -> tuple[dict, dict]:
    async with asyncio.TaskGroup() as tg:
        order_task = tg.create_task(load_order(order_id), name="order")
        feature_task = tg.create_task(load_features(order_id), name="features")
    return order_task.result(), feature_task.result()
```

结果只能在 TaskGroup 正常退出后安全读取。若任一任务失败，函数不会执行 return，而是得到异常组。使用 `except* DomainReadError as group:` 可以按类型处理组内异常；不要 `except Exception: return []` 吞掉所有成员失败。

TaskGroup 的“兄弟失败互相取消”适合共同完成一个操作的子任务。若任务彼此独立、允许部分成功，仍可在每个子协程内部把预期业务失败转成值，再由 TaskGroup完整等待；但必须明确哪些异常可转成结果、哪些应终止整组。

## 7. `gather()` 与 TaskGroup 不可机械互换

`asyncio.gather()` 仍然有价值，例如按输入顺序收集一批 awaitable 的结果，或明确使用 `return_exceptions=True` 把异常当值审查。但默认 gather 的失败与兄弟任务处理保证和 TaskGroup不同；官方文档推荐 TaskGroup 为相关嵌套子任务提供更强的安全保证。

`return_exceptions=True` 很容易把 `Exception` 对象混进正常列表，后续代码把它序列化或当记录使用。采用时应立即分区并做穷尽映射：成功值、允许的缺失、重试失败和程序错误。不能为了“尽量返回”让认证失败、协议错误和取消悄悄变成空数据。

选择依据是语义：共同成功/失败的工作用 TaskGroup；明确允许部分结果的批处理可以 TaskGroup + 结果封装，或经过审查的 gather。关键不是函数名，而是所有权、失败传播、取消和退出时无悬空任务。

## 8. 异常如何跨异步边界传播

协程中的异常在 await 时重新抛给等待者。若 Task先失败但无人等待/读取，事件循环可能稍后报告未检索异常。TaskGroup会在退出时集中抛出组异常。调试时最先可信的是异常类型、任务名、原始 traceback与当前关联 ID，不是最终一行“500 Internal Server Error”。

业务可预期失败应有稳定异常或结果类型，例如 `OrderNotFound`、`UpstreamTimeout`、`PayloadRejected`；基础设施适配器把客户端库异常映射后再出边界。不要让任意 `aiohttp`/数据库异常直接成为公开 API文案，也不要在每层重复记录同一栈造成噪声。

异常组需要按成员诊断。`except* UpstreamTimeout` 只处理匹配成员，未处理成员继续传播。日志记录每个成员的稳定 code和阶段，但对外错误合同通常汇总为稳定结构，不泄露完整组栈。

## 9. 取消是请求，不是立即杀死

调用 `task.cancel()` 会安排在 Task 下一次可处理机会抛出 `asyncio.CancelledError`。它不是强制终止线程，也不能回滚已经完成的外部副作用。如果协程正在执行没有 await 的阻塞代码，取消要等它回到事件循环才生效。

`CancelledError` 在现代 Python中直接继承 `BaseException`，普通 `except Exception` 通常不会截获它，这是为了让取消更容易传播。若显式 catch 取消，只用于记录或清理，完成后通常必须 `raise`。Python官方文档明确警告：TaskGroup和 `asyncio.timeout()` 内部依赖取消，吞掉 `CancelledError` 可能让结构化并发失效。

取消不等于业务失败。客户端断开、服务关闭、父超时都可能触发取消；监控应区分。已经向 Java 服务发出的写请求可能仍被处理，因此必须依赖幂等键和服务端事务，而不是相信 Python协程取消了网络等待就撤销事实。

## 10. `finally` 是取消清理的核心

需要释放的资源放入异步上下文管理器或 `try/finally`：取消发生时也要关闭连接、归还 semaphore、取消订阅和记录收尾。清理代码本身也可能 await；必须明确它是否可取消、是否有独立短超时，以及失败如何记录。

```python
async def consume(client: AsyncClient) -> None:
    stream = await client.open_stream()
    try:
        async for item in stream:
            await handle(item)
    except asyncio.CancelledError:
        record_cancelled()
        raise
    finally:
        await stream.aclose()
```

若 `aclose()` 卡住，整个关闭流程也卡住。可以给清理设置有限预算并记录未完成资源，但不要无界 shield。资源类型应提供幂等 close，重复清理不会产生第二次写操作。

测试要数清理次数：成功、子任务失败、超时和父取消各执行一次；结束后检查 `asyncio.all_tasks()` 中除当前测试任务外没有本场景遗留任务。只断言返回值不能证明资源安全。

## 11. 超时是一个作用域合同

没有超时的外部 I/O可能永久占住请求和连接池。超时要按层分配：整个 API请求预算、一次上游调用预算、连接/读取预算和清理预算。下层预算应小于上层，留出映射和响应时间；不能每层各给 30 秒导致总时长失控。

Python 3.14 的 `asyncio.timeout(delay)` 是异步上下文管理器。超时到达时会取消当前 Task，并在上下文外把内部取消转换为可捕获的 `TimeoutError`。因此 `TimeoutError` 通常在 `async with` 外处理：

```python
try:
    async with asyncio.timeout(0.8):
        return await load_bundle(order_id)
except TimeoutError as exc:
    raise UpstreamDeadlineExceeded(order_id) from exc
```

`asyncio.wait_for()` 也能给一个 awaitable设超时，但会取消被等待对象并等待其取消完成，实际总时间可能超过数字本身。选哪种要看需要保护单个 awaitable还是一段结构化作用域，且要测试真实客户端的取消行为。

## 12. 超时与外部副作用

当 Python等待 Java API超时，无法断言 Java 没有收到或处理请求。读取操作可以重试但仍需限流；写操作必须带服务端认可的幂等键，重试使用相同键，并查询最终状态。取消/超时只改变调用者的等待，不自动产生分布式事务。

FactoryCare中 Python服务原则上不拥有工单状态写入。即使未来通过 Java公开命令触发动作，也必须走 Java权限、状态机、幂等和审计；Python的 timeout不能通过直接写数据库“补偿”。

记录 deadline和 attempt，但避免记录秘密正文。上游返回晚到结果时，连接库可能丢弃；若后台任务仍运行，必须由所有者接管，不能让请求 handler退出后留一半业务逻辑。

## 13. `shield()` 不是取消万能药

`asyncio.shield(aw)` 可以在调用者被取消时避免把该取消直接传给被保护的 awaitable，但调用者自己的 await 仍会抛 `CancelledError`；被保护 Task若从其他来源取消仍会取消。官方也提醒保存 Task强引用。

滥用 shield会让服务关闭后仍有大量任务运行。只对必须完成且有独立所有者、可观测、有限时长的收尾使用，例如把已经写入本地持久队列的短 flush交给应用 supervisor。网络写业务事实不能只靠 shield保证可靠；进程被杀时它仍会消失，应使用事务、outbox或队列。

若用 shield，需要在父取消后仍等待/观察被保护 Task，处理其结果与异常，并给它截止时间。写出“为什么不能取消”的业务理由，而不是因为测试偶发失败就包一层。

## 14. 阻塞调用边界

同步 `time.sleep()`、`requests.get()`、普通文件大读写、某些数据库/模型 SDK和 CPU计算会阻塞事件循环。开发模式可开启 asyncio debug和 slow callback 日志；生产可以测 loop lag。首证据是其他无关协程也延迟、Task堆栈停在同步函数。

短小、线程安全、主要等待 I/O的同步函数可用 `asyncio.to_thread()` 移到线程：

```python
result = await asyncio.to_thread(sync_client.fetch, order_id)
```

这不会让函数自动可取消：取消等待者通常不能杀死已经运行的线程函数。还要限制线程并发、设置底层客户端超时并处理关闭。CPU密集任务是否适合线程取决于实现是否释放 GIL；纯 Python计算常需进程、原生库或外部 worker。

最佳方案通常是使用真正异步、支持超时和连接池的客户端，而不是把所有同步库包进无界 `to_thread`。

## 15. 并发需要容量和背压

对一万个工单逐个 `create_task()` 会瞬间创建一万个 Task、请求和响应对象。即使每个都是异步，也会耗尽连接池、上游配额和内存。并发上限应来自连接池、上游限额、延迟和资源测量。

`asyncio.Semaphore` 可以限制进入临界异步区的任务数，但要用 `async with` 或 finally确保取消时归还。更大工作流可用有界 `asyncio.Queue` 和固定 worker；生产者遇到满队列等待，形成背压。队列关闭要有 sentinel或显式生命周期，不能无限 `queue.join()`。

限流不是授权或幂等。每个请求仍要验证租户与输入；批任务仍要保存每项结果。取消父批次时，worker、队列中未开始项和已发出的外部请求各有什么语义必须写清。

## 16. 服务关闭与父取消

应用关闭时，停止接收新工作；通知 supervisor取消；给在途任务一个有限优雅期；等待 TaskGroup；超时后记录仍未完成项；关闭连接池和监控；最后退出。顺序反了会在任务仍使用时先关客户端，产生噪声失败。

Unix signal、容器终止和 Web框架 lifespan API的具体接法在生产化章节处理，本章关注内部合同。请求 handler被取消时，只清理它拥有的子任务；应用级持久 worker不应被某个请求随意取消。

关闭测试要控制事件：启动两个子任务，确认进入；触发 stop；允许一个清理完成，另一个超出预算；断言错误、清理次数和遗留任务报告确定。不要真实 sleep数秒制造慢测试。

## 17. 异步上下文管理器与资源所有权

支持 `async with` 的客户端、会话、锁和 TaskGroup把获取/释放绑定到词法作用域。一般应让 lifespan拥有长连接池，让请求只借用；不要每个字段校验创建客户端，也不要把请求局部 session藏进全局。

自己实现异步上下文管理器时，`__aenter__` 部分失败也要清理已获得资源；`__aexit__` 不应无意吞掉异常。异常参数告诉退出原因，返回 truthy会抑制异常，除非合同明确，否则返回 False/None让其传播。

Async generator作为 context manager时也要保证 finally执行。调用者中途 break或取消时，资源必须关闭。用受控 Fake统计 open/close，覆盖进入失败和退出失败。

## 18. 可观察性与上下文传播

为 Task命名，并记录 start、success、failure、cancelled、timeout、cleanup。使用 monotonic clock测耗时，不用本地墙钟相减。`contextvars` 能随 Task传播请求关联上下文，但新线程、进程和手工回调的传播规则要验证；不要依赖隐式 context保存业务权限。

指标可包含在途 Task、队列深度、取消数、超时数、loop lag、上游延迟和清理失败。标签必须低基数，不能把 orderId当指标标签；具体关联 ID放受控日志/trace。取消是正常控制流时不要按崩溃报警，但突然激增可能意味着客户端断开或超时配置错误。

异常组的日志要避免重复：边界统一记录一次，子层补充稳定阶段。敏感 AI输入、工单正文和 token不进入 Task名称或 traceback附加字段。

## 19. 用 Event 控制异步测试，不用碰运气 sleep

可靠异步测试用 `asyncio.Event`、Queue或 Future明确控制“已开始”“允许完成”“触发失败”。例如先启动 TaskGroup；等待所有 Fake调用发出 started；让 B失败；断言 A收到取消并清理；最后检查无悬空 Task。测试不会依赖机器快慢。

超时测试可以使用很短但确定的 context和受控永不完成 Event，也可注入 clock/scheduler。若用 pytest异步插件，锁定插件版本和事件循环作用域；本章资产使用标准库 `asyncio.run()`，避免额外插件。

Task leak检查要排除当前测试 Task和框架合法后台任务，并在同一 loop中执行。只在进程退出后看“没有警告”不够，因为事件循环关闭可能强制取消遗留工作。

## 20. 五类场景的验证矩阵

| 场景 | 期望结果 | 取消/清理 | 首证据 |
| --- | --- | --- | --- |
| 全部成功 | 按 ID得到全部派生详情 | 每项 close一次 | Task结果和 trace |
| 一个子任务失败 | TaskGroup抛异常组 | 兄弟取消并清理 | 异常成员、cancel trace |
| 整体超时 | 外层得到稳定 deadline错误 | 所有孩子结束 | timeout与最终 all_tasks |
| 父任务取消 | `CancelledError` 传播 | finally各一次 | 父/子取消计数 |
| 允许部分完成 | 成功/失败显式结果列表 | 无遗留 | 穷尽结果类型 |

完成条件不是只看函数返回，而是结果、异常组成员、清理次数和遗留 Task都确定。测试故意注入吞取消、无所有者 Task和阻塞调用时，应在最接近职责边界处失败。

## 21. 三个典型故障的诊断

### 21.1 吞掉 `CancelledError`

表现为 timeout到了却不返回、TaskGroup无法退出或服务关停卡住。首证据是协程 catch CancelledError后继续循环、`task.cancelling()`与 trace。修复在 finally清理后 re-raise；不要随意 `uncancel()`。重跑父取消和超时场景，并确认清理一次、无遗留。

### 21.2 创建无所有者 Task

表现为请求返回后后台仍写日志，异常从未检索，或任务被垃圾回收。首证据是 `create_task` 返回值未保存、应用关闭时任务不在 supervisor。修复为 TaskGroup或显式应用 supervisor，保存强引用、消费异常并关闭等待。若工作必须可靠，迁移到持久队列而非内存 Task。

### 21.3 阻塞事件循环

表现为所有请求、超时和心跳一起延迟。首证据是 loop lag、slow callback与堆栈停在 `time.sleep`/同步 I/O/CPU循环。修复换异步客户端、`to_thread`（有界、底层超时）或进程/worker。重跑并发探针，证明无关 tick仍按预算推进。

## 22. FactoryCare 的权威边界

Java服务拥有工单、设备、状态机、租户、权限和审计等业务事实。Python服务用于 AI推理、检索和可重建派生数据，通过 Java公开 API读取必要最小数据；它不能直接连接 Java业务库更新工单，也不能把并发结果当最终事实。

TaskGroup可并发加载多个**只读**派生输入，结果仍需携带来源版本和关联 ID。任一关键来源失败时是整体失败还是部分降级由用例合同决定。AI结果提交回 Java时走受控建议/命令 API，由 Java重新授权、验证状态与幂等。

取消 Python请求不会撤销 Java已接受的命令；超时重试必须复用幂等键。后台批量重建索引应由持久任务系统拥有，而不是 Web请求创建匿名 Task。

## 23. 与 JavaScript/Flutter 的类比

Python coroutine类似 JS Promise背后的异步计算，但调用 `async def`只产生 coroutine，需要 await/Task；JS Promise通常创建时就开始执行。TaskGroup类似结构化管理一组子任务，不等于 `Promise.all`所有细节。`CancelledError`是协作式取消，而 JS `AbortController`也只有底层读取 signal才真正中止。

Flutter/Dart `Future`没有通用取消；Python Task提供 cancel请求，但仍不能杀死阻塞线程或回滚外部副作用。共同规律是：UI/请求生命周期保护结果所有权，不自动取消底层；真正取消必须贯穿生产者；幂等和事务处理已发出的写操作。

## 24. AI 协作边界

AI可以生成 TaskGroup骨架、按场景表补测试、审查 `create_task`所有权、查找吞取消和同步阻塞调用、解释 ExceptionGroup traceback。它也可以建议 timeout层级，但数值必须来自真实 SLO和测量。

开发者必须决定任务关系、部分成功语义、deadline预算、外部副作用、重试幂等、线程安全、应用关闭所有权和监控脱敏。AI看到 `async def`不能断言无阻塞，也不能凭源码宣称没有 Task leak。

禁止为“解决超时”吞 `CancelledError`、到处 shield、把同步库无界塞进线程、创建匿名后台业务写、把异常组改成空列表，或伪造并发性能证据。

## 25. 本章动手路线

### 25.1 Example：TaskGroup 成功路径

运行 `examples/encyclopedia/ch.python.asyncio-cancellation/verify.sh`。它使用 Python标准库和受控 Event并发加载三项合成工单详情，验证结果顺序、清理次数与无遗留 Task。

### 25.2 Lab：失败、超时、父取消

运行 `labs/encyclopedia/ch.python.asyncio-cancellation/verify.sh`。Lab依次制造子任务异常、整体 timeout与父取消，检查异常组、兄弟取消、finally清理和最终 Task集合。它不访问真实 Java API。

### 25.3 Exercise：稳定预期红

运行 `exercises/encyclopedia/ch.python.asyncio-cancellation/verify.sh`。初始代码故意吞取消、丢弃 create_task引用并调用 `time.sleep`；静态与运行合同应稳定非零。任务是建立 TaskGroup所有权、重新抛取消并移除 loop阻塞，不能删除检查。

### 25.4 120 秒讲回

解释 coroutine函数与对象、event loop何时切换、Task为何需所有者、TaskGroup失败如何传播、取消为什么不是杀死、finally做什么、timeout如何转换异常、shield风险、to_thread不能解决什么，以及 Python为何不能写 Java业务事实。

## 26. 已验证、未验证与明确不做

本章资产在本机 CPython 3.14.x标准库上验证 coroutine、TaskGroup、Event、timeout、父取消、清理次数和 leak检查。它们只使用合成数据和短受控任务，不发网络、不访问数据库，不创建生产后台任务。

本章**没有验证**FastAPI/uvicorn事件循环、aiohttp/httpx、异步数据库、真实 Java端点、线程池耗尽、进程池、容器 signal、生产 loop lag、持久队列或 AI模型 SDK。标准库样例绿不能证明第三方客户端真正支持取消，也不能证明生产性能。

本章明确不实现业务写入、分布式事务、生产 worker、通用消息队列、CPU推理部署和框架 lifespan；不修改 FactoryCare业务事实，也不修改学习进度。

## 27. 官方资料与版本边界

以下资料于 2026-07-24 核对；Python官方 3.14文档当时显示 3.14.6。课程版本面仍写 `python-3.14`，项目通过 uv和锁文件固定实际 patch：

- [Python 3.14：Coroutines and Tasks](https://docs.python.org/3.14/library/asyncio-task.html)
- [Python 3.14：Developing with asyncio](https://docs.python.org/3.14/library/asyncio-dev.html)
- [Python 3.14：Asyncio synchronization primitives](https://docs.python.org/3.14/library/asyncio-sync.html)
- [Python 3.14：Queues](https://docs.python.org/3.14/library/asyncio-queue.html)
- [Python 3.14：Exceptions](https://docs.python.org/3.14/library/asyncio-exceptions.html)
- [Python 3.14：Exception groups](https://docs.python.org/3.14/library/exceptions.html#exception-groups)

协作式等待、所有权、取消传播、finally清理和阻塞边界属于稳定核心，因此本章 `stable_core: true`。`TaskGroup.create_task`参数、eager start、取消计数细节和第三方框架集成仍会变化，实施时以锁定 Python 3.14 patch文档和测试为准。
