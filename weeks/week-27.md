# 第27周：Python 3.14工程化、异步、FastAPI与测试

## 本周定位

从本周开始进入Python AI主线。第一周不接模型，先把Python服务建立为正常的软件系统：依赖可锁定、类型可检查、配置可验证、API可测试、日志可关联、错误可处理。

## 前置条件

- Java核心API、认证和traceId稳定；
- PostgreSQL和对象存储可用；
- 安装Python 3.14与uv，确认PyTorch/关键库兼容；
- 明确Python不写`core` schema。

## 本周目标

- 恢复Python数据模型、类型、异常、上下文管理和包结构；
- 理解协程、事件循环、阻塞IO和线程/进程边界；
- 使用uv、`pyproject.toml`和锁文件建立可复现环境；
- 建立FastAPI内部服务、配置、错误、日志和健康检查；
- 建立pytest和Java-Python契约测试入口。

## 必须理解的概念

- 动态类型与类型提示、`Any`风险、Protocol、Generic、TypedDict；
- dataclass与Pydantic模型的职责；
- iterable/iterator/generator和惰性；
- exception chaining、自定义异常和资源清理；
- context manager、文件/网络资源生命周期；
- module、package、绝对/相对导入和`src`布局；
- virtual environment、lock、应用依赖与开发依赖；
- coroutine、task、event loop、await和cancellation；
- 异步函数调用阻塞库的后果，以及线程池/进程池适用性；
- FastAPI路由、依赖、生命周期、Pydantic校验和OpenAPI；
- 配置/密钥、统一错误、结构化日志、traceId和健康检查；
- pytest fixture、参数化、mock边界、async测试和HTTP测试。

## 时间与任务（15—18小时）

下方120分钟无AI训练计入任务3的异步实验，不在总时长之外重复增加。

### 任务1：环境和包结构（2小时）

- 创建AI服务`pyproject.toml`和`uv.lock`；
- 建立`src/factorycare_ai`与`tests`结构；
- 配置format/lint/typecheck/pytest命令；
- 配置Python版本文件和`.env.example`，不提交密钥；
- 在README记录从空环境启动方式。

### 任务2：语言与类型复健（3小时）

- 用dataclass表达领域无关内部值；
- 用Pydantic表达API输入输出；
- 用Protocol定义模型客户端和检索器接口；
- 写generator处理大文档片段；
- 主动构造`Any`传播、可变默认值和异常吞掉的问题。

### 任务3：异步实验（3小时）

- 并发调用三个假外部服务，比较串行和`TaskGroup`/gather；
- 处理超时、取消、一个任务失败和资源释放；
- 在async路由中故意执行阻塞任务并测量影响；
- 比较直接await、线程池和进程池；
- 写结论，不把async等同于更快。

### 任务4：FastAPI骨架（4小时）

- `/health/live`和`/health/ready`；
- `/internal/v1/triage`先返回确定性假结果；
- Pydantic schema和稳定错误格式；
- service token/tenant/scope/traceId依赖骨架；
- 结构化日志和请求耗时；
- 超时和异常映射；
- Java客户端契约样例。

### 任务5：测试与容器（2—3小时）

- 配置pytest fixture和测试客户端；
- 覆盖schema失败、未认证、scope不足、异常和健康检查；
- 用fake实现隔离外部模型；
- 创建最小容器镜像或开发Dockerfile，非root运行概念；
- CI运行lint/type/test。

### 任务6：求职和复盘（1小时）

- 采样5个Python/AI应用岗位，区分Web后端、数据、算法和AI应用；
- 更新R4简历草稿，但暂不写RAG/Agent已完成；
- 口述Java和Python服务为什么分开、为什么又不拆更多服务。

## FactoryCare项目增量

- 可独立启动的Python AI服务；
- 确定性假分诊接口；
- 内部服务身份、tenant/scope/traceId骨架；
- Java调用Python的契约测试或stub；
- CI和基础容器化。

## AI协作边界

AI可以生成Pydantic样板、测试参数和Dockerfile初稿。必须人工检查：async内部阻塞、依赖版本、异常泄漏、日志敏感信息、认证依赖、`Any`和测试是否真的隔离外部调用。

## 无AI训练（120分钟）

实现一个异步批处理端点：最多并发3个假解析任务，每项有超时，部分失败返回明确结果，客户端取消时释放任务。使用类型提示并写async测试。

## 求职动作

- 整理“Python AI应用”和“算法岗”的JD差异；
- 模拟回答：为什么不用Spring AI完成全部AI功能？Python服务如何避免成为第二业务中心？
- 本周投递仍以Java/Vue全栈为主，AI简历只作为准备。

## 交付物

- [ ] `pyproject.toml`、`uv.lock`和包结构；
- [ ] 类型/异步最小实验；
- [ ] FastAPI健康和假分诊接口；
- [ ] 内部认证与trace骨架；
- [ ] pytest、lint/typecheck和CI结果；
- [ ] 无AI任务和周复盘。

## 验收标准

- 从干净环境可按README启动和测试；
- 能解释coroutine、task、thread和process区别；
- async路由没有明显阻塞调用；
- 外部依赖可替换为fake，测试不消耗模型费用；
- Python账户没有`core` schema写权限；
- 错误和日志不泄漏密钥。

## 本周明确不做

- LangChain/LangGraph；
- RAG和向量库；
- 模型微调；
- Python直连Java业务表；
- 为一个服务拆复杂微服务框架。

## 官方资料

- [Python 3 documentation](https://docs.python.org/3/)
- [Python typing](https://docs.python.org/3/library/typing.html)
- [Python asyncio](https://docs.python.org/3/library/asyncio.html)
- [uv documentation](https://docs.astral.sh/uv/)
- [FastAPI documentation](https://fastapi.tiangolo.com/)
- [pytest documentation](https://docs.pytest.org/)
