---
schema_version: 2
edition: 2026.2-draft
id: ch.fastapi.web-foundations
title: FastAPI 路由、依赖、请求响应与错误
responsibility: 用 FastAPI 建立路由、参数/Body、依赖、状态码和错误合同，理解 sync/async 处理边界，不在本章接入完整认证。
volume: '12'
order: 16
level: L2+
status: drafting
path: book/volume-12-python-data/chapters/ch.fastapi.web-foundations.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.pydantic-validation
- ch.foundations.http-curl
version_surfaces:
- python-3.14
- fastapi
- pydantic-2
- pytest
- openapi
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“FastAPI 路由、依赖、请求响应与错误”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - fastapi-routing-dependency
  - fastapi-response-error
  covers_topics:
  - fastapi.app-router
  - fastapi.path-query-body
  - fastapi.dependency-injection
  - fastapi.sync-async-handler
  - fastapi.response-model
  - fastapi.status-code
  - fastapi.http-exception
  - fastapi.exception-handler
  - fastapi.request-validation-error
  uses_capabilities:
  - python.language
  - python.io-errors
  - foundation.http-message
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现工单 CRUD API 切片、依赖替换和统一错误响应；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - fastapi-routing-dependency
  - fastapi-response-error
  covers_topics:
  - fastapi.app-router
  - fastapi.path-query-body
  - fastapi.dependency-injection
  - fastapi.sync-async-handler
  - fastapi.response-model
  - fastapi.status-code
  - fastapi.http-exception
  - fastapi.exception-handler
  - fastapi.request-validation-error
  uses_capabilities:
  - python.language
  - python.io-errors
  - foundation.http-message
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: test-client-curl-contract-dependency-override
- id: diagnose
  kind: fault-diagnosis
  text: 面对“路由优先级、响应模型或异常转换错误造成的状态码/数据泄露”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - fastapi-routing-dependency
  - fastapi-response-error
  covers_topics:
  - fastapi.app-router
  - fastapi.path-query-body
  - fastapi.dependency-injection
  - fastapi.sync-async-handler
  - fastapi.response-model
  - fastapi.status-code
  - fastapi.http-exception
  - fastapi.exception-handler
  - fastapi.request-validation-error
  uses_capabilities:
  - python.language
  - python.io-errors
  - foundation.http-message
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# FastAPI 路由、依赖、请求响应与错误

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Pydantic 模型、校验、序列化与错误》](ch.python.pydantic-validation.md)：请求/响应模型和运行时校验是 FastAPI 合同基础。
- [《HTTP 报文、方法、状态码、Header、Body 与 curl》](../../volume-00-computer-foundations/chapters/ch.foundations.http-curl.md)：路由、状态码、Header 和 Body 必须能从 HTTP 层独立验证。
<!-- END GENERATED LEARNING PREREQUISITES -->

> FastAPI 把 HTTP 请求映射到 Python 函数，并借助类型标注、Pydantic 和 OpenAPI 描述输入输出。框架可以自动解析与校验形状，却不会替你定义业务权限、状态机或事实所有权。本章用教学型工单 CRUD 切片学习 Web 合同；在真实 FactoryCare 中，公开客户端仍只调用 Java，Python 只承载内部 AI/可重建派生能力。

## 1. 从 HTTP 报文到路径操作函数

浏览器或客户端发送：

```http
GET /training/work-orders/WO-001?include_history=false HTTP/1.1
Host: example.test
Accept: application/json
```

Web 应用要做的事可以拆成：

1. 服务器接收 HTTP 并转换成 ASGI scope 与事件；
2. Starlette/FastAPI 按方法和路径寻找路由；
3. FastAPI 从路径、查询、Header、Cookie 或 Body 提取值；
4. Pydantic 校验需要建模的数据；
5. 依赖图先求值；
6. 路径操作函数执行应用逻辑；
7. 返回值按响应模型过滤、序列化；
8. 状态码、Header 与 JSON Body 组成响应。

FastAPI 不是 HTTP 服务器本身。开发时常由 Uvicorn 等 ASGI 服务器承载它。测试中的 `TestClient` 或 HTTPX `ASGITransport` 可在进程内调用 ASGI 应用，因此“请求经过了应用协议层”不等于“真实网卡、TLS、反向代理和公网都已验证”。

## 2. 创建应用与第一条路由

```python
from fastapi import FastAPI

app = FastAPI(title="Training Work Order API")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
```

`app` 是 ASGI 应用对象。`@app.get("/health")` 在导入模块时注册一条 GET 路由；被装饰函数不会在导入时执行，而会在匹配请求到来时由框架调用。

路径操作由“HTTP 方法 + 路径模板”共同确定：

```python
@app.get("/training/work-orders")
def list_orders(): ...


@app.post("/training/work-orders", status_code=201)
def create_order(): ...
```

GET 与 POST 即使路径相同也是不同操作。方法语义不是装饰：GET 应用于读取且应保持安全语义；POST 常用于创建或触发非幂等动作；PUT 通常表达完整替换；PATCH 表达部分更新；DELETE 表达删除。实际 API 要结合资源合同与幂等要求，不能只凭 CRUD 名称机械套用。

### 2.1 路由顺序与重叠

```python
@app.get("/users/me")
def current_user(): ...


@app.get("/users/{user_id}")
def user_by_id(user_id: str): ...
```

具体路径应在宽泛动态路径之前注册。否则 `/users/me` 可能先被 `{user_id}` 捕获。更好的防护是减少含义重叠、给路径参数设置明确类型/格式，并用路由矩阵测试具体值、动态值和不存在路径。

同一方法和完全相同路径重复注册也是合同错误。不要指望“后一个覆盖前一个”作为稳定设计；启动审查或测试应检查 OpenAPI 中 operation 与路由集合是否唯一。

## 3. APIRouter 组织相关操作

应用变大后，用 `APIRouter` 分组：

```python
from fastapi import APIRouter, FastAPI

router = APIRouter(prefix="/training/work-orders", tags=["training-work-orders"])


@router.get("")
def list_orders():
    return []


app = FastAPI()
app.include_router(router)
```

router 可统一 prefix、tag、依赖与响应说明，但它不是业务模块边界本身。目录拆分也不会自动阻止跨模块写数据。FactoryCare 的核心业务模块仍在 Java 模块化单体中；Python router 只能暴露经确认的内部 AI 边界。

避免在模块导入时访问数据库、读取远程配置或发网络请求。导入应主要定义对象和注册路由；资源生命周期在显式 lifespan/依赖中管理，便于测试和失败恢复。

## 4. 路径参数

```python
@router.get("/{order_id}")
def get_order(order_id: str):
    return {"id": order_id}
```

路径模板中的 `{order_id}` 与函数参数名一致，FastAPI 从 URL 注入字符串。若标为 int：

```python
@app.get("/devices/{device_id}")
def get_device(device_id: int):
    return {"device_id": device_id}
```

请求 `/devices/abc` 会在进入函数前产生请求校验错误。路径参数始终存在；不存在“省略路径参数”的情况。路径值已校验为 int 也不代表资源存在或当前主体有权读取，那是应用层查询和授权。

可以用 `Path` 声明范围与文档：

```python
from typing import Annotated
from fastapi import Path

DeviceId = Annotated[int, Path(gt=0, description="正整数设备 ID")]
```

范围规则属于输入合同；如果业务身份不是自然数或会迁移为 UUID，不要为了方便写错类型。

## 5. 查询参数

没有出现在路径模板中的简单函数参数通常来自 query：

```python
@router.get("")
def list_orders(
    status: str | None = None,
    offset: int = 0,
    limit: int = 20,
):
    return {"status": status, "offset": offset, "limit": limit}
```

对应 `/training/work-orders?status=ASSIGNED&offset=0&limit=20`。查询字符串本质是文本，FastAPI 按类型转换；转换成功不等于业务合法。`status=UNKNOWN` 仍是 str，需要 Enum/集合或业务合同拒绝。分页还要限制 `limit` 上界，避免一次请求读取无界数据。

用 `Query` 声明约束：

```python
from fastapi import Query

Limit = Annotated[int, Query(ge=1, le=100)]
```

布尔查询的文本转换规则由框架版本决定。若客户端合同要求精确 `true|false`，应写测试，不要只在浏览器中试一次。

## 6. 请求 Body 与 Pydantic 模型

复杂模型参数默认从 JSON Body 解析：

```python
from pydantic import BaseModel, ConfigDict, Field


class TrainingOrderCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)

    title: str = Field(min_length=1, max_length=120)
    priority: int = Field(ge=1, le=5)
```

```python
@router.post("", status_code=201)
def create_order(command: TrainingOrderCreate):
    return {"id": "WO-TRAINING-001", **command.model_dump()}
```

模型完成 JSON 解析后的字段校验。`strict=True` 减少意外宽松转换，`extra="forbid"` 阻止客户端偷偷多传字段。具体规则应在 Pydantic 章节先验证。

Body 模型不应复用数据库实体或完整响应模型。创建命令不允许客户端提交 `id`、`created_at`、`tenant_id` 或内部风险分数；响应也不应泄露内部备注和凭据。输入与输出模型承担不同合同。

### 6.1 参数来源要能一眼看出

FastAPI 根据路径模板、简单类型、Pydantic 模型以及 `Path/Query/Header/Body` 元数据推断来源。复杂接口应显式使用 `Annotated`：

```python
from fastapi import Body, Header

TraceId = Annotated[str | None, Header(alias="X-Trace-Id")]
CommandBody = Annotated[TrainingOrderCreate, Body()]
```

显式来源让代码审查和 OpenAPI 更清楚。不要让同名值同时从多个位置出现却没有优先级合同。

## 7. 响应模型不是装饰

```python
class TrainingOrderResponse(BaseModel):
    id: str
    title: str
    priority: int


@router.post("", response_model=TrainingOrderResponse, status_code=201)
def create_order(command: TrainingOrderCreate):
    return {
        "id": "WO-TRAINING-001",
        "title": command.title,
        "priority": command.priority,
        "internal_secret": "must-not-leak",
    }
```

FastAPI 会按 response model 处理输出，未声明的 `internal_secret` 不应出现在 JSON。这是纵深防御，但不能依赖它掩盖随意返回实体的坏设计。响应模型不匹配通常表示服务端 bug，不应伪装成客户端 422。

两种常见声明：

```python
@app.get("/items/{item_id}")
def read_item(item_id: str) -> ItemResponse: ...
```

或 `response_model=ItemResponse`。返回类型同时供静态工具使用；response_model 能在返回原始 dict 等场景明确运行时合同。团队选一种一致策略并测试实际 OpenAPI/响应。

### 7.1 序列化与过滤的证据

至少断言：

- 状态码；
- `content-type`；
- JSON 精确字段集合；
- 字段类型和关键值；
- 内部字段不存在；
- OpenAPI 指向正确 schema。

只断言 `response.status_code == 200` 无法发现数据泄露。

## 8. 状态码表达结果类别

```python
from fastapi import status

@router.post("", status_code=status.HTTP_201_CREATED)
def create_order(...): ...
```

常见合同：

- 200：读取或普通成功；
- 201：资源创建成功，通常还应考虑 Location；
- 204：成功且无 Body；
- 400：请求语义或通用格式错误（按团队错误策略）；
- 401：未认证，通常伴随 `WWW-Authenticate`；
- 403：已识别但无权限；
- 404：资源不存在，或为防枚举而统一隐藏；
- 409：版本/唯一性/状态冲突；
- 422：FastAPI 默认请求校验错误；
- 500：未预期服务端故障。

状态码不是“差不多即可”。客户端重试、UI 提示、监控和安全行为会依赖它。错误码策略必须写进测试矩阵。

204 响应不要返回 JSON Body；201 与 200 不应随实现重构漂移。错误处理器也不能把所有异常都转换成 200 + `{success:false}`，这会破坏 HTTP 和可观测性。

## 9. 依赖注入：声明函数需要什么

```python
from typing import Annotated
from fastapi import Depends, Header, HTTPException


def require_internal_client(
    x_internal_client: Annotated[str | None, Header()] = None,
) -> str:
    if x_internal_client is None:
        raise HTTPException(status_code=401, detail="missing internal client")
    return x_internal_client


InternalClient = Annotated[str, Depends(require_internal_client)]


@router.get("/{order_id}")
def get_order(order_id: str, client: InternalClient):
    return {"id": order_id, "requested_by": client}
```

`Depends(require_internal_client)` 接收函数对象，不是提前调用它。每次请求由 FastAPI解析依赖参数、调用依赖，再把结果注入路径操作。

依赖适合：

- 提取并验证公共 Header；
- 获取请求作用域资源；
- 建立数据库 session 生命周期；
- 当前主体和授权判断；
- feature flag、租户上下文和观测上下文。

依赖不应藏入难以察觉的大量业务副作用。路径操作读起来应能看出关键授权和写入。把所有行为塞进一个 `common_dependency` 会让失败来源和测试变模糊。

### 9.1 子依赖与请求内缓存

依赖可以依赖其他依赖。FastAPI 通常对同一请求内重复依赖结果进行缓存，避免相同依赖被多次求值；可按 API 控制 `use_cache`。这个缓存不是跨请求缓存，也不能替代数据库/Redis 缓存。依赖若返回可变对象，多个消费方可能在同一请求共享它，所有权必须清楚。

### 9.2 yield 资源依赖

资源依赖可以 `yield`：yield 前获取，yield 后清理。FastAPI 近年对 yield 依赖退出时机增加过版本行为，属于必须按选定 patch 核对的表面。本章资产不使用它假装验证数据库连接；后续接入真实资源时应测试正常、异常、流式响应和取消路径。

## 10. 测试中覆盖依赖

应用提供：

```python
app.dependency_overrides[require_internal_client] = lambda: "test-client"
```

此后请求会使用替代依赖。测试结束必须清理：

```python
try:
    ...
finally:
    app.dependency_overrides.clear()
```

更好的是 fixture 负责安装与清理。覆盖键必须是原依赖函数对象；覆盖错误对象时不会生效。覆盖能隔离外部服务，却也可能绕过想测试的解析与安全逻辑，因此应同时有“不覆盖的失败测试”和“覆盖后的应用逻辑测试”。

依赖覆盖是进程内全局可变状态。并行测试若共享同一个 app，可能互相污染。用应用工厂创建隔离实例，或严格管理 fixture 作用域。

## 11. sync 与 async 路径操作

FastAPI 同时支持：

```python
@app.get("/sync")
def sync_handler(): ...


@app.get("/async")
async def async_handler(): ...
```

选择原则不是“async 更快”：

- 调用提供可等待异步 API 的库时，用 async def 并 await；
- 调用阻塞库且没有异步接口时，普通 def 让框架按其线程池策略执行；
- CPU 密集计算不会因加 async 自动并行，应移出请求关键路径或使用合适进程/任务架构；
- async def 中直接运行阻塞 I/O 会阻塞事件循环，拖慢同一 worker 的其他请求；
- 忘记 await 会得到 coroutine 对象或逻辑未执行。

```python
import asyncio

@app.get("/derived")
async def derived():
    result = await async_client.fetch()
    return result
```

取消、超时与资源清理仍要显式设计。客户端断开不保证所有下游工作自动停止；不要把 `async` 当自动取消开关。

## 12. 预期错误使用 HTTPException

```python
from fastapi import HTTPException


@router.get("/{order_id}")
def get_order(order_id: str):
    order = repository.find(order_id)
    if order is None:
        raise HTTPException(status_code=404, detail="work order not found")
    return order
```

`HTTPException` 要 raise，不是 return。raise 会中断当前请求路径并交给异常处理。它适合靠近 HTTP 边界的预期错误；核心计算函数不必依赖 FastAPI 类型，可以抛领域/应用异常，由适配层转换。

不要把数据库原始错误、SQL、文件路径、token、堆栈或完整请求 Body 放进 detail。对外错误应稳定、最小；内部日志用 trace ID 关联详细原因并脱敏。

## 13. 自定义异常与统一错误信封

```python
class SnapshotUnavailable(Exception):
    pass


@app.exception_handler(SnapshotUnavailable)
async def snapshot_unavailable_handler(request, exc):
    return JSONResponse(
        status_code=503,
        content={
            "code": "SNAPSHOT_UNAVAILABLE",
            "message": "derived snapshot temporarily unavailable",
        },
    )
```

错误信封可包含稳定 code、对用户安全的 message、trace ID 和字段错误；不要包含内部 exception repr。处理器顺序与异常类型要测试。一个捕获所有 `Exception` 的处理器若返回具体异常消息，会造成数据泄露；若吞掉取消异常或记录错误状态，也会破坏运行时语义。

### 13.1 预期错误与未预期错误

- 预期业务/应用错误：映射确定 4xx/409/503；
- 请求解析错误：稳定 422 或团队明确的 400；
- 服务端编程错误：记录内部证据，对外统一 500；
- 取消与超时：保留任务语义并按边界转换，不能一概吞掉。

统一信封不等于统一状态码。

## 14. RequestValidationError

路径、查询或 Body 不符合声明时，FastAPI 会产生 `RequestValidationError`，默认响应通常是 422 与 detail 列表。可以覆盖：

```python
from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


@app.exception_handler(RequestValidationError)
async def request_validation_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={
            "code": "REQUEST_INVALID",
            "errors": [
                {"location": list(error["loc"]), "type": error["type"]}
                for error in exc.errors()
            ],
        },
    )
```

不要把 `exc.body` 原样回传或无脱敏记录。Body 可能含密码、token、个人信息或大负载。错误快照应稳定但不绑死本地化消息全文；位置和错误类型往往更适合作为结构 oracle。

请求校验错误是客户端输入问题；响应模型校验失败是服务端输出 bug。二者不能映射成同一个“请修改请求”。

## 15. CRUD 教学切片与真实架构边界

本章实验实现内存版：

```text
POST   /training/work-orders
GET    /training/work-orders
GET    /training/work-orders/{id}
PATCH  /training/work-orders/{id}
DELETE /training/work-orders/{id}
```

它用于学习路由、状态码、Body、响应过滤、依赖替换和错误矩阵。它不是 FactoryCare 生产 API，不能接 core schema，也不能被客户端当第二后端。

真实边界：

```text
Vue / uni-app / Flutter
        |
        v
Java /api/v1  —— 认证、授权、工单状态机、核心事实
        |
        v  固定且重新授权的内部调用
Python /internal/v1 —— AI 计算、可重建派生数据、只读工具
```

Python 若返回优先级建议，字段应叫 hint/suggestion，并由 Java 决定是否展示或采纳。不能让 Python 的 `PATCH /work-orders/{id}` 在生产中直接写 `status=CLOSED`。

## 16. HTTP 合同测试矩阵

至少保存：

| 场景 | 预期状态 | 关键 oracle |
| --- | ---: | --- |
| 合法创建 | 201 | 精确响应字段、Location/ID 规则 |
| 缺失 title | 422 | REQUEST_INVALID、字段位置 |
| priority 越界 | 422 | 不进入 repository |
| 额外 internal 字段 | 422 | extra forbidden |
| 已知 ID | 200 | response model 过滤内部字段 |
| 不存在 ID | 404 | 安全错误信封 |
| 依赖失败 | 401/503 | 路径操作未执行 |
| repository 冲突 | 409 | 稳定错误 code |
| 未预期异常 | 500 | 无堆栈/路径/secret 泄露 |
| 路由 `/special` | 200 | 未被 `/{id}` 抢占 |

TestClient 在同步测试中很方便：

```python
from fastapi.testclient import TestClient

client = TestClient(app)
response = client.get("/health")
assert response.status_code == 200
assert response.json() == {"status": "ok"}
```

它验证应用内 HTTP/ASGI 合同，但没有验证真实代理、TLS、DNS、网络超时或部署配置。

## 17. 诊断三类高频漂移

### 17.1 路由优先级错误

现象：请求 `/training/work-orders/special` 进入 `/{order_id}`。第一可信证据是测试响应与匹配 endpoint，而不是数据库。检查注册顺序和路径设计，修复后同时重跑 special、普通 ID 与 404。

### 17.2 响应模型漂移

现象：内部字段泄露，或合法返回触发 500。比较响应模型、实现返回和 OpenAPI schema。不能通过删除 response_model 来“修复”，那只是移除防线。确定公共字段后修模型或映射器。

### 17.3 异常转换泄露

现象：500 Body 包含 exception 文本、文件路径或 secret。先保留内部日志证据，再改安全处理器；测试只断言对外无敏感片段，不把真实 secret 写进 fixture。错误处理器自身也可能失败，需有最小回退。

## 18. 从 Spring Boot 对照理解

- `@app.get` / `APIRouter` 类似 Spring `@GetMapping` / Controller 路由，但运行模型与注解机制不同；
- Pydantic Body 类似 DTO + Bean Validation 的部分职责，不等同领域实体；
- `Depends` 可承担 Spring 参数解析/Bean 注入/拦截逻辑的部分角色，但依赖图按请求解析，不能照搬单例 Bean 心智模型；
- `HTTPException` 类似在 Web 边界抛出带状态的异常；统一 handler 类似 `@ControllerAdvice`；
- response_model 是运行时输出过滤/Schema 来源之一，Java record 返回类型并不会自动提供完全相同过滤行为；
- async def 建立在 Python/ASGI 事件循环上，不等于 Java 虚拟线程。

对照只用于迁移已有知识，最终以实际 FastAPI patch、Starlette 与 Pydantic 组合验证。

## 19. 学习与验收顺序

1. 画出请求从方法/路径到依赖、函数、响应模型的流水线；
2. 写一条具体路由和一条动态路由，制造顺序故障；
3. 分别验证 path、query、Body 的合法与非法输入；
4. 添加严格输入模型和独立响应模型，注入内部字段验证过滤；
5. 添加依赖并测试原依赖失败；
6. 覆盖依赖测试应用逻辑，再清理覆盖；
7. 添加 HTTPException、自定义异常和 RequestValidationError 信封；
8. 注入未预期异常，证明响应无堆栈与 secret；
9. 说明 sync/async 选择及一个阻塞事件循环反例；
10. 口述为什么教学 CRUD 不能部署成 FactoryCare 第二业务后端。

AI 可以生成路由样板，但学习者必须能指出参数来源、校验位置、授权位置、输出过滤和失败 oracle，并独立修改一条合同后修复测试。

## 20. 章末检查

你应能回答：

- FastAPI、Starlette、ASGI 服务器分别承担什么？
- 方法和路径如何共同确定操作？
- path/query/body 如何推断与显式声明？
- Pydantic 形状校验为何不是授权？
- response_model 如何降低输出泄露风险？
- Depends 接收函数还是调用结果？
- 依赖覆盖为何必须清理？
- sync def 与 async def 应按什么选择？
- HTTPException 为什么要 raise？
- RequestValidationError 与响应模型失败属于哪一方错误？
- 如何证明 500 没有泄露内部信息？
- 为什么 Python 教学 CRUD 不能成为 FactoryCare 的 `/api/v1`？

## 21. 版本、官方资料与未验证范围

2026-07-24 核对 FastAPI 官方发布说明，当前稳定补丁为 0.139.2（2026-07-16）。本章资产实际解析并运行组合：FastAPI 0.139.2、Pydantic 2.13.4、Starlette 1.3.1、HTTPX 0.28.1、pytest 9.1.1、AnyIO 4.14.2、CPython 3.14.3。版本升级必须重新运行合同矩阵。

- [FastAPI Release Notes](https://fastapi.tiangolo.com/release-notes/)
- [FastAPI Path、Query 与 Request Body 教程](https://fastapi.tiangolo.com/tutorial/body/)
- [FastAPI Dependencies](https://fastapi.tiangolo.com/tutorial/dependencies/)
- [FastAPI Response Model](https://fastapi.tiangolo.com/tutorial/response-model/)
- [FastAPI Handling Errors](https://fastapi.tiangolo.com/tutorial/handling-errors/)
- [FastAPI Testing](https://fastapi.tiangolo.com/tutorial/testing/)

已验证范围：进程内 TestClient 的路由、path/query/body、Pydantic 请求校验、依赖覆盖、状态码、响应过滤与安全错误信封。未验证范围：真实 Uvicorn worker、curl 到监听端口、TLS/反向代理、数据库、外部认证、网络超时、负载与并发、部署健康检查、Java 内部调用。不得从本章绿色测试推断线上可用。
