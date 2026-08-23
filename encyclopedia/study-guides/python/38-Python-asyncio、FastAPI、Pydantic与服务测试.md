# Python：asyncio、FastAPI、Pydantic 与服务测试

## 1. 异步编程主要解决等待期间的并发

网络、数据库和消息队列经常需要等待外部结果。同步程序在等待时占住当前执行路径；异步程序可以暂时让出控制权，让同一线程处理其他已就绪任务。

它适合大量 I/O 等待，不会自动加速重 CPU 计算。CPU 密集任务需要进程、原生库、任务队列或其他并行方案。

## 2. `async def` 定义协程函数

```python
async def fetch_order(order_id: str) -> dict[str, object]:
    ...
```

调用它会得到 coroutine（协程对象），并不会立刻执行完整函数。必须由事件循环 `await` 它，或把它安排成 Task。

```python
order = await fetch_order("WO-1")
```

`await` 只能出现在异步函数等允许的上下文中。

## 3. 事件循环进行协作式调度

事件循环维护哪些任务正在等 I/O、哪些已经就绪。任务运行到 `await` 一个尚未完成的异步操作时，主动交还控制权。

如果异步函数里执行长时间 CPU 循环或同步阻塞 I/O 而不让出，整个事件循环都可能卡住。因此“写了 async”不等于不会阻塞。

## 4. Coroutine、Future 和 Task 处在不同层次

- Coroutine：异步函数调用产生的可等待计算。
- Future：代表未来会得到结果或异常的低层对象。
- Task：事件循环中被安排执行的 coroutine，并保存结果、异常和取消状态。

通常应用代码直接 `await` coroutine，或在需要并发时由结构化并发工具创建 Task，不必手工操作 Future。

## 5. 并发不等于并行

并发表示多个任务的生命周期重叠；并行表示同一时刻真的在多个 CPU 核心执行。

asyncio 通常在一个线程的事件循环中并发推进 I/O 任务。理解这点能避免把大型图片处理、模型训练等 CPU 工作直接放进请求事件循环。

## 6. 每个后台 Task 都需要所有者

```python
task = asyncio.create_task(send_notification())
```

创建后丢掉引用容易导致异常无人处理、服务关闭时无法等待或取消。每个 Task 都应归属于请求作用域、TaskGroup 或明确的应用生命周期管理器。

“发后不管”仍然需要队列、持久化、重试、监控和关闭协议，而不是简单 `create_task`。

## 7. `TaskGroup` 把一组子任务放进同一生命周期

```python
async with asyncio.TaskGroup() as group:
    order_task = group.create_task(fetch_order("WO-1"))
    user_task = group.create_task(fetch_user("U-1"))
```

离开作用域前会等待子任务。如果某个任务失败，组会取消其余任务并集中传播异常。这种父子关系叫结构化并发。

它适合“一组任务共同完成一个上层操作”的场景。

## 8. `gather` 与 `TaskGroup` 不是机械替换关系

`gather` 适合收集一组 awaitable 的有序结果，也可选择把异常当作结果返回。`TaskGroup` 更强调失败时取消同组任务和明确生命周期。

选择时先写清：一个失败后其他任务是否还有价值、是否要保留部分结果、异常如何聚合、父操作取消时怎么处理。

## 9. 取消是一项协作请求

对 Task 调用 `cancel()` 后，通常会在下一个可取消等待点抛出 `CancelledError`。任务需要在 `finally` 中释放资源，再继续传播取消。

```python
try:
    await client.send(request)
finally:
    await session.close()
```

不要宽泛捕获后吞掉取消，否则上层以为任务已停止，底层仍继续占资源或产生副作用。

## 10. 超时限制的是等待作用域

```python
async with asyncio.timeout(2.0):
    result = await fetch_order("WO-1")
```

超时不保证外部系统撤回已经开始的写操作。客户端没收到响应时，服务端可能已经创建工单。

因此写操作仍需幂等键、结果查询和明确的不确定状态，不能把超时简单解释为“什么都没发生”。

## 11. 阻塞库不能直接塞进事件循环

若第三方客户端只有同步 API，直接调用会阻塞同一事件循环上的所有请求。可选方案：

- 使用真正异步客户端；
- 把短时阻塞调用放到受控线程池；
- 把 CPU/长任务放到进程或队列；
- 限制并发和排队长度。

线程转移不是无限容量，底层连接池和服务端仍有上限。

## 12. 并发必须有容量限制和背压

收到一万个请求就创建一万个下游 Task，会把数据库、文件描述符和内存压垮。可用 semaphore、连接池、队列和速率限制明确容量。

背压表示下游处理不过来时，上游减速、排队有限或明确拒绝，而不是无限堆积。

## 13. FastAPI 把 HTTP 请求映射到路径操作函数

```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/work-orders/{order_id}")
async def get_order(order_id: str):
    return {"orderId": order_id}
```

HTTP 方法、路径和函数共同定义入口。路径参数、查询参数、Header 和 Body 是不同数据来源，应在签名中清晰表达。

## 14. `APIRouter` 按业务能力组织路由

```python
router = APIRouter(prefix="/work-orders", tags=["work-orders"])
```

一个模块可以集中工单查询、创建和状态转换。应用入口负责组合 router、中间件和生命周期，不应包含所有业务逻辑。

路由组织按业务功能通常比按 HTTP 动词分文件更容易维护。

## 15. 路径、查询和 Body 参数有不同语义

```text
GET /work-orders/WO-1?includeHistory=true
    路径参数：order_id = WO-1
    查询参数：includeHistory = true

POST /work-orders
    Body：创建工单所需的结构化数据
```

路径标识资源，查询参数调整筛选或展示，Body 承载复杂命令。敏感凭据不要放 URL，因为 URL 更容易进入日志和历史记录。

## 16. Pydantic 把不可信输入变成有合同的模型

```python
from pydantic import BaseModel, Field

class CreateWorkOrderRequest(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    affected_users: int = Field(ge=0)
```

普通类型标注只供静态工具使用；Pydantic 会在运行时解析和校验输入，并在失败时提供结构化错误位置。

它负责边界数据合同，不应承担数据库查询或复杂业务编排。

## 17. 必填、可空和有默认值是三件事

```python
class PatchRequest(BaseModel):
    title: str                 # 必须提供，不能为 null
    note: str | None           # 必须提供，可以为 null
    assignee: str | None = None  # 可以省略，默认 None
```

更新接口还常需区分“未提供字段”和“明确提供 null”。序列化时可根据字段集合决定只更新真正给出的字段。

## 18. 类型正确不代表业务有效

字符串可能是空白，整数可能超范围，开始时间可能晚于结束时间。单字段约束用 Field 或字段 validator，跨字段不变量用模型 validator。

校验器应确定、快速、无外部副作用。需要查数据库的唯一性、权限和当前状态属于应用/领域服务。

## 19. 宽松转换要有意识地选择

Pydantic 可能把某些字符串转换成数字或布尔，方便常见 API 输入，也可能接受本应拒绝的模糊值。

安全或金额边界可使用严格类型/严格模式。最重要的是测试实际允许与拒绝的输入，不要只根据注解猜运行时行为。

## 20. 额外字段策略决定 Schema 漂移是否被看见

若默认忽略未知字段，上游拼错字段时请求可能仍成功，但值完全没生效。边界模型可根据兼容策略选择禁止、允许或保留额外字段。

命令类 API 常倾向拒绝未知字段；读取第三方事件时可能需要兼容前向扩展。选择必须明确并有版本策略。

## 21. `ValidationError` 是结构化失败，不只是文字

错误通常包含位置、类型和上下文。API 层应把它映射成稳定错误信封，同时保留 request ID 便于排障。

不要把内部堆栈和敏感输入原样返回客户端。客户端需要的是可定位字段和安全说明。

## 22. 序列化不是简单读取 `__dict__`

现代 Pydantic 使用 `model_dump()` / `model_dump_json()` 等 API 按配置处理 alias、排除字段和嵌套模型。

```python
payload = model.model_dump(by_alias=True, exclude_none=True)
```

输入名、Python 属性名和输出 JSON 名可能不同。alias 策略应统一，避免有的接口输出 snake_case、有的输出 camelCase。

## 23. 请求模型、领域命令和响应模型应分开

```text
HTTP JSON
  → Pydantic Request
  → Application Command
  → Domain Entity/Value Object
  → Response DTO
  → HTTP JSON
```

请求模型适应外部协议，领域对象保护业务规则，响应模型控制公开字段。共用一个万能模型虽省映射，却会把数据库、业务和 API 演化绑在一起。

## 24. 响应模型控制公开合同

FastAPI 的响应模型可校验和过滤返回数据，减少内部字段意外泄露。它不是装饰：若实现返回结构和文档不一致，应尽早暴露。

密码哈希、内部备注、租户隔离字段等不能只靠“调用者应该不看”，而应根本不进入公开响应模型。

## 25. 依赖注入用于声明路由需要什么

```python
def get_order_service() -> OrderService:
    ...

@router.get("/{order_id}")
async def get_order(
    order_id: str,
    service: OrderService = Depends(get_order_service),
):
    ...
```

依赖可提供数据库会话、当前用户和服务对象。它让入口合同显式，也便于测试替换。

不要把所有全局状态塞进一个万能依赖对象。

## 26. `yield` 依赖表达请求资源生命周期

```python
async def get_session():
    session = create_session()
    try:
        yield session
    finally:
        await session.close()
```

`yield` 前准备资源，之后清理。资源关闭时点可能受依赖作用域和响应类型影响，流式响应尤其要按当前 FastAPI 文档核对。

## 27. `def` 和 `async def` 要根据下游调用选择

FastAPI 会以不同方式执行同步和异步路径函数/依赖。简单原则：

- 下游库要求 `await`，使用 `async def`；
- 下游只有同步阻塞 API，不能假装用 `async def` 就变异步；
- CPU 密集任务不应占用请求 worker；
- 混用时要测连接池、线程池和取消行为。

## 28. HTTP 状态码表达结果类别

```text
200：成功读取或普通成功
201：成功创建
204：成功但无响应正文
400/422：请求格式或语义不满足入口合同
401：缺少或无效认证
403：身份有效但无权操作
404：资源不存在，或按安全策略隐藏存在性
409：当前状态或版本冲突
```

具体选择应在整个 API 中一致，并写入 OpenAPI 和合同测试。

## 29. 预期错误和未预期错误应分开

不存在、冲突、无权限等可预期结果应映射为稳定 API 错误。程序缺陷、依赖崩溃等未预期异常应记录关联上下文并返回通用 5xx，不泄露内部细节。

业务层不应直接抛 FastAPI 的 `HTTPException`，否则领域规则会绑定传输协议。由 API 适配层统一翻译更清楚。

## 30. 认证、当前主体和授权是三个步骤

```text
读取凭据
  → 验证凭据，建立 current principal
  → 检查 principal 是否能对该资源执行该动作
```

“登录了”不表示能看所有工单。多租户系统每次资源查询都要带租户边界，不能先查全局记录再在内存中补检查。

## 31. FastAPI Security 工具能描述凭据入口

安全依赖可以读取 Bearer token、API key 等，并把方案投影进 OpenAPI。它们不会自动完成安全设计：签名/会话验证、撤销、权限、租户隔离和审计仍需实现。

只在文档写 security 而运行时不校验，或只手工读 Header 却不让 OpenAPI知道，都会造成合同不一致。

## 32. OpenAPI 是机器可读的接口投影

FastAPI 可根据路由和模型生成 OpenAPI，供文档、客户端生成和合同检查使用。

它描述路径、方法、参数、Schema、响应和安全方案，但不自动证明实现正确，也不能完整表达所有业务规则。

稳定、唯一的 `operationId` 有助于生成客户端和版本比较。

## 33. 接口变化要按兼容性分类

常见破坏性变化包括：删除路径、删除响应字段、把可选字段改为必填、缩窄允许值、改变字段类型、增加客户端无法处理的认证要求。

新增可选字段通常较兼容，但严格客户端也可能拒绝。因此 OpenAPI diff 需要规范化后分类，再由人判断业务影响。

## 34. `TestClient` 适合同步风格的 HTTP 测试

```python
from fastapi.testclient import TestClient

client = TestClient(app)

def test_get_order():
    response = client.get("/work-orders/WO-1")
    assert response.status_code == 200
    assert response.json()["orderId"] == "WO-1"
```

它测试路由、校验、依赖和响应映射。若测试本身需要 await 异步数据库等，应使用异步 HTTP 客户端和明确的异步测试后端。

## 35. 测试可覆盖依赖，但必须在结束后恢复

```python
app.dependency_overrides[get_order_service] = lambda: fake_service
try:
    ...
finally:
    app.dependency_overrides.clear()
```

遗留覆盖会污染其他测试并造成顺序依赖。fixture 很适合负责建立和清理覆盖。

安全测试不要把认证依赖直接替换成“永远管理员”后只测成功路径，否则真正安全代码根本没运行。

## 36. API 测试至少覆盖四类合同

- 正常路径：状态码、响应 Schema、关键字段。
- 输入失败：缺字段、错误类型、边界、额外字段。
- 业务失败：不存在、冲突、状态不允许。
- 安全失败：无凭据、无效凭据、跨租户、权限不足。

还要验证未预期异常不会泄露堆栈或秘密。

## 37. 异步测试使用事件或明确同步点

用固定 sleep 等后台任务完成，会让测试在快慢机器上不稳定。更可靠的是 Event、队列、Fake 端口或可观察状态：

```text
测试启动操作
  → 等待“已进入下游”的 Event
  → 触发取消/失败/返回
  → 等待任务结束
  → 检查清理和最终状态
```

这样能稳定复现取消、超时和竞态。

## 38. 服务关闭也属于正确性

应用收到停止信号后应：停止接收新工作、给进行中请求有限完成时间、取消并等待受管后台任务、关闭连接池、刷新必要缓冲，再退出。

关闭无限等待会阻塞部署；直接杀死可能丢失工作。每类资源都需要时间预算和失败处理。

## 39. 可观测性要跨越异步边界

请求进入时建立 request/trace ID，并把租户、用户、路由和关键下游阶段以脱敏字段记录。异步 Task 也要继承或显式传递上下文。

重点指标包括延迟、错误类别、取消、超时、连接池等待、事件循环阻塞和下游重试。日志数量多不等于可诊断。

## 40. 这一阶段应形成的整体地图

```text
HTTP 请求
  → FastAPI 路由与依赖
  → Pydantic 运行时校验
  → 应用服务与领域规则
  → async I/O / 数据库 / 外部 API
  → 响应模型与 OpenAPI

生命周期：Task 所有权 → 超时/取消 → finally 清理 → 服务关闭
验证：正常 + 输入失败 + 业务冲突 + 安全负例 + Schema
```

必须掌握：async 主要解决 I/O 等待；Task 必须有所有者；取消是协作请求；超时不撤回外部副作用；Pydantic 负责运行时边界而非全部业务；请求、领域和响应模型应分开；认证不等于授权；OpenAPI 是合同投影；测试依赖覆盖必须清理。

FastAPI、Pydantic、AnyIO 和 Python asyncio 的细节会更新，实施时应以锁定版本的官方文档核对，尤其是严格模式、序列化、依赖清理时点和异步测试配置。
