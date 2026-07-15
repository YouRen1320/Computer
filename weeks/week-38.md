# 第 38 周：Python async、FastAPI、Pydantic、配置、日志与服务测试

## 定位

Python 语言、OOP、文件、typing、pytest 和 uv 已在 Week 36—37 完成。本周只把这些能力升级为可运行的内部 AI 服务：理解 async 事件循环和阻塞边界，使用 FastAPI/Pydantic 建立契约、配置、日志、认证、超时与测试。模型调用从 Week 40 开始。

时间预算：15—18 小时。服务只提供确定性占位能力，不提前接 LLM/RAG。

## 前置

- Python package、类型检查、pytest、异常链和文件边界通过；
- Java `ai-integration` 端口、内部 API 和 Java/Python权限边界已定义；
- Python 数据库角色不得写 `core` schema；
- 能用 uv 锁依赖并从干净环境运行。

## 目标

- 理解 coroutine、event loop、task、await、取消和 structured concurrency 高层模式；
- 识别阻塞 I/O/CPU 工作对事件循环的影响；
- 使用 timeout、并发限制、线程/进程 offload 和资源生命周期；
- 使用 FastAPI path/query/header/body/dependency/lifespan；
- 使用 Pydantic 做运行时验证、序列化和设置；
- 建立稳定错误码、traceId、健康/就绪和内部认证；
- 结构化日志不泄漏敏感内容；
- 使用 pytest、async client、dependency override 和 fake 测服务；
- 容器化并由 Java 完成一次内部调用烟雾测试。

## 完整概念清单

### async 运行模型

- coroutine function/object、awaitable、Task、Future 高层关系；
- async 函数到首个 await 前的执行；
- event loop 协作调度，并非每个请求新线程；
- `create_task` 的所有权、异常和生命周期；
- gather/TaskGroup（按当前版本官方行为）、部分失败；
- cancellation 是注入异常式协作，清理后应继续传播；
- timeout 结束等待，不保证远端工作撤销；
- semaphore/队列做资源限制；
- 阻塞库使用线程 offload，CPU 大任务考虑进程/外部 worker；
- async 不会让 CPU 代码自动更快。

### FastAPI 请求链

- ASGI、server、application、middleware、route/dependency；
- path/query/header/cookie/body；
- sync/async endpoint 的执行边界；
- dependency injection 用于请求依赖，不替代清晰领域结构；
- lifespan 初始化/关闭 client、pool、model adapter；
- response model/status/header；
- exception handler 和稳定错误 envelope；
- health/liveness/readiness 区别；
- OpenAPI 是契约资产，需要与 Java internal client 验证。

### Pydantic 与配置

- BaseModel、field、validator/model validator；
- strict/coercion 选择、额外字段策略；
- input/output model 分离，敏感字段不回显；
- JSON schema 与业务规则边界；
- Settings、环境变量、secret 和多环境；
- 配置启动时 fail-fast，不使用静默危险默认；
- datetime/UUID/enum/decimal 序列化；
- ORM/数据库映射不是本周重点。

### 日志、身份与可观测基础

- structured log、level、event name、trace/correlation ID；
- middleware 传播 Java 传入 traceId；
- 内部服务身份/短期凭证或共享方案按设计契约，不能信任来源 IP；
- 不记录完整 prompt、文档、token、密码和隐私数据；
- latency/error/request count 基础指标；
- audit 与诊断日志不同；
- 详细 OTel/故障演练在 Week 46。

### 服务测试

- unit test 纯函数/服务；
- ASGI transport/test client 测 route/validation/error；
- dependency override/fake client；
- async test、timeout、cancel、并发上限；
- lifespan 和资源关闭测试；
- contract schema snapshot/Java consumer smoke；
- Testcontainers 可用于 ai schema，但本周骨架可先无数据库；
- 网络测试不依赖真实模型供应商。

## 时间与任务

| 任务 | 时间 | 产出 |
| --- | ---: | --- |
| async/取消/阻塞 | 3h | TaskGroup、timeout、blocking 对照实验 |
| FastAPI 骨架 | 3h | lifespan、route、dependency、错误 |
| Pydantic/配置 | 2—3h | 严格 DTO、settings、敏感字段测试 |
| 日志/身份/trace | 2h | Java→Python trace 和拒绝未认证 |
| 测试/容器 | 3h | unit/API/async/resource tests |
| FactoryCare/复盘 | 2—4h | 确定性分诊占位服务和契约证据 |

## FactoryCare 增量

- `GET /internal/v1/health` 与 readiness；
- `POST /internal/v1/triage-preview` 使用确定性规则返回结构化草稿；
- 请求包含 tenant/user/trace 上下文，Python 不自行决定最终业务权限；
- 未认证、schema 错误、超时、内部错误有稳定 code/traceId；
- Java client 设置 connect/read/overall timeout 和降级；
- Python 账户无法写 core schema 的测试/权限证据；
- fake slow dependency 证明 event loop 阻塞与 offload 差异。

## 无 AI 任务（120—150 分钟）

增加 `POST /internal/v1/checklist-draft`：严格验证设备类别和症状，调用 fake async provider，限制并发，超时返回稳定错误；传播 traceId，日志脱敏。完成 unit/API/timeout/cancel/lifespan 测试并由 Java 或 curl 契约调用。

## 验收

- 能解释 coroutine/task/thread/process 与阻塞边界；
- 能证明取消、超时和资源关闭行为；
- Pydantic 验证不被当业务授权；
- 内部认证、traceId、稳定错误和健康检查可运行；
- 类型、lint、pytest、构建/容器烟雾通过；
- Java 核心在 Python 不可用时明确降级；
- 能独立增加一个 endpoint 而不复制全局 client/config。

## 非目标

- 不调用真实 LLM、embedding 或向量库；
- 不让 Python 写 Java 核心业务；
- 不把所有函数改 async；
- 不建设 Celery/分布式任务平台。
