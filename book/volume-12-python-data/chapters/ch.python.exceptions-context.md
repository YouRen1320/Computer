---
schema_version: 2
edition: 2026.2-draft
id: ch.python.exceptions-context
title: 异常、上下文管理器与资源清理
responsibility: 区分业务失败与异常，定义抛出、转换、链式和清理边界，并用 with/contextmanager 保证文件等资源释放，整合 IO 与错误能力。
volume: '12'
order: 11
level: L2
status: drafting
path: book/volume-12-python-data/chapters/ch.python.exceptions-context.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.classes-dataclass
- ch.python.files-json-time
version_surfaces:
- python-3.14
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“异常、上下文管理器与资源清理”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - python-exception-contract
  - python-context-resource
  covers_topics:
  - python.raise-except
  - python.custom-exception
  - python.exception-chaining
  - python.error-translation
  - python.traceback
  - python.with-context-manager
  - python.enter-exit
  - python.contextmanager-decorator
  - python.resource-owner
  - python.file-read-write
  uses_capabilities:
  - python.language
  - foundation.files-path-encoding
  - python.io-errors
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“异常、上下文管理器与资源清理”构建可运行程序与测试：为工单文件存储建立异常翻译和可验证 context manager 资源边界；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - python-exception-contract
  - python-context-resource
  covers_topics:
  - python.raise-except
  - python.custom-exception
  - python.exception-chaining
  - python.error-translation
  - python.traceback
  - python.with-context-manager
  - python.enter-exit
  - python.contextmanager-decorator
  - python.resource-owner
  - python.file-read-write
  uses_capabilities:
  - python.language
  - foundation.files-path-encoding
  - python.io-errors
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: failure-matrix-cleanup-counter-traceback-chain-check
- id: diagnose
  kind: fault-diagnosis
  text: 面对“裸 except、吞掉 cause、return 覆盖异常或 __exit__ 错误抑制”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - python-exception-contract
  - python-context-resource
  covers_topics:
  - python.raise-except
  - python.custom-exception
  - python.exception-chaining
  - python.error-translation
  - python.traceback
  - python.with-context-manager
  - python.enter-exit
  - python.contextmanager-decorator
  - python.resource-owner
  - python.file-read-write
  uses_capabilities:
  - python.language
  - foundation.files-path-encoding
  - python.io-errors
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 异常、上下文管理器与资源清理

> 异常不是“所有非理想结果”的同义词。它是一条非本地控制流：当前语句无法按合同继续时，解释器沿调用栈寻找匹配处理器；无处理器就终止当前任务/进程并输出 traceback。正确设计既不吞掉根因，也不把每个业务分支都变异常，还要保证成功和失败时资源都只释放一次。

## 1. 先区分结果、业务拒绝和异常

FactoryCare 查询工单：

- 找不到 ID：若是正常查询结果，可返回 `None`；
- 用户无权：应用层业务拒绝，映射为明确错误；
- JSON 损坏：存储/数据异常；
- 文件不存在：取决于合同，首次空库可能正常，也可能配置错误；
- 磁盘写失败：基础设施异常；
- 程序变量拼错：缺陷，不应伪装成“用户输入错误”。

同一事件在不同边界含义可能不同。Repository `get` 文档若约定 missing -> None，调用者应分支；配置加载器要求文件必须存在，则 FileNotFoundError 应翻译成配置异常。

### 1.1 异常合同要写四件事

1. 哪些输入可能失败；
2. 暴露哪些异常类型/正常结果；
3. 是否保留原始 cause；
4. 失败后系统/资源状态是否完整。

只写“可能抛异常”无法可靠调用。

## 2. raise 与异常对象

```python
if quantity <= 0:
    raise ValueError("quantity must be positive")
```

`raise` 创建/抛出异常，当前正常路径停止。调用栈展开直到匹配 except 或顶层。

### 2.1 选择合适内置异常

- `ValueError`：类型可接受但值域非法；
- `TypeError`：对象类型/调用合同错误；
- `KeyError`：映射键缺失；
- `LookupError`：查找失败抽象；
- `RuntimeError`：更合适类型不存在时的运行状态错误；
- I/O 有 FileNotFoundError、PermissionError、OSError 等细类。

不要所有失败都 `Exception("error")`，也不要为每行创建无语义自定义类。

### 2.2 `raise` 与 `raise error`

在 except 中裸 `raise` 重新抛当前异常并保留原 traceback：

```python
except OSError:
    logger.exception("read failed")
    raise
```

`raise error` 可能改变 traceback 顶部/重抛位置，诊断通常优先裸 raise。

## 3. try / except / else / finally

```python
try:
    text = path.read_text(encoding="utf-8")
except FileNotFoundError:
    return None
except PermissionError as error:
    raise RepositoryUnavailable("cannot read work orders") from error
else:
    return parse_orders(text)
finally:
    metrics.read_attempt_finished()
```

- try 包可能抛目标异常的最小区域；
- except 处理匹配异常；
- else 仅 try 正常结束后执行；
- finally 无论正常、return、异常（乃至部分控制转移）都执行，用于必须清理。

### 3.1 except 顺序

子类在前，父类在后：

```python
except FileNotFoundError:
    ...
except OSError:
    ...
```

反过来 OSError 先捕获会让细分支不可达。

### 3.2 try 区域不要过大

```python
try:
    text = path.read_text()
    order = transform(text)
    notify(order)
except Exception:
    ...
```

你无法知道处理的是读取、转换还是通知缺陷。缩小 try 并在边界翻译。

### 3.3 多异常一分支

仅当处理策略相同：

```python
except (FileNotFoundError, PermissionError) as error:
    ...
```

不要因懒惰合并语义不同异常。

## 4. 不要裸 except / 宽吞错

```python
try:
    load_orders()
except:
    return []
```

裸 except 捕获 `BaseException` 家族，包括 KeyboardInterrupt/SystemExit 等控制信号；返回空列表把真实损坏伪装成“无工单”。`except Exception` 虽稍窄，仍可能吞编程缺陷。

只有在进程/任务顶层兜底记录并建立隔离时才考虑宽捕获，而且通常要重新抛、失败任务或返回明确失败，不可静默。

### 4.1 记录后继续也可能是吞错

`logger.error(...); return []` 仍改变语义。日志不是错误处理。调用者必须知道结果是否可信。

## 5. 自定义异常层次

```python
class RepositoryError(Exception):
    """Base error for the work-order repository boundary."""


class RepositoryUnavailable(RepositoryError):
    pass


class CorruptRepositoryData(RepositoryError):
    pass
```

调用者可捕获 RepositoryError 统一处理，也可细分重试/告警。名称按调用者能采取的动作设计，不暴露底层库品牌。

### 5.1 异常携带安全上下文

```python
class WorkOrderNotFound(LookupError):
    def __init__(self, order_id: int) -> None:
        super().__init__(f"work order {order_id} not found")
        self.order_id = order_id
```

不要放 token、密码、完整请求体或 PII。异常会进入日志、监控和 API 映射。

### 5.2 业务异常不要泄露 HTTP

领域/应用层不应抛 `HTTPException(404)`；那把 Web 框架渗入核心。应用抛 WorkOrderNotFound，FastAPI 边界映射 404，CLI 可映射退出码。

## 6. 异常链：`raise ... from ...`

```python
try:
    payload = json.loads(text)
except json.JSONDecodeError as error:
    raise CorruptRepositoryData("work-order JSON is invalid") from error
```

外层异常给调用者稳定语义，`__cause__` 保留原 JSON 位置与原因。traceback 展示“direct cause”。

### 6.1 隐式 context

在 except 内抛新异常但不写 from，原异常成为 `__context__`，报告 “During handling...”。工程边界翻译优先显式 `from error`，表明因果是有意的。

### 6.2 `from None`

可抑制界面展示原链：

```python
raise PublicInputError("invalid input") from None
```

仅在原异常对调用者无价值/可能泄露实现时使用；日志边界仍应安全保留内部证据。不要用它让调试更干净而删除根因。

## 7. traceback 是路径证据

读 traceback 从底部异常类型/消息开始，再沿调用帧找第一处属于项目、且违反合同的位置。最后一帧未必根因，例如库在解析你传入的坏数据时失败。

记录：

- 异常类型；
- cause/context 链；
- 第一处项目帧；
- 输入 fixture（脱敏）；
- 失败阶段；
- 资源是否清理。

不要只截最后一行，也不要把完整含秘密堆栈直接发公开渠道。

### 7.1 `logger.exception`

在 except 中记录当前 traceback。多层都记录会重复告警；通常在有足够上下文且决定终止/降级的边界记录一次，底层翻译并抛出。

## 8. finally 的危险：return 覆盖异常

```python
def broken():
    try:
        raise RuntimeError("root cause")
    finally:
        return "ok"
```

finally 的 return 会压掉异常，调用者得到 ok。Python 3.14 编译器/工具可能对这种控制流给警告，但不要依赖提示；项目禁止 finally 中 return/break/continue 覆盖未决异常。

finally 只做必要、尽量不失败的清理。如果清理也失败，会覆盖或链接原异常，需明确策略和测试。

## 9. with 与上下文管理协议

```python
with path.open("r", encoding="utf-8") as stream:
    text = stream.read()
```

概念等价：调用 `__enter__` 获得绑定值，执行块，无论正常还是异常调用 `__exit__(exc_type, exc, traceback)`。

文件由 with 管理，离开块自动 close。比手写 open/try/finally 更不易漏。

### 9.1 `__exit__` 返回值

- 返回 falsy/None：异常继续传播；
- 返回 truthy：异常被抑制。

错误实现无条件 `return True` 会吞掉块内所有异常：

```python
def __exit__(self, exc_type, exc, tb):
    self.close()
    return True  # 危险
```

普通资源管理器应返回 False/None。只有明确的异常抑制器才按类型选择 true，并写合同测试。

### 9.2 `__enter__` 失败

若 enter 尚未成功，Python 不会对这个 manager 调 exit。enter 中已获取多个资源时，应自己回滚已获取部分，或用 ExitStack。

## 10. 自定义 context manager

```python
class Transaction:
    def __init__(self, connection):
        self.connection = connection

    def __enter__(self):
        self.connection.begin()
        return self

    def __exit__(self, exc_type, exc, tb):
        if exc_type is None:
            self.connection.commit()
        else:
            self.connection.rollback()
        return False
```

必须测试 begin/块成功/块失败/commit 失败/rollback 失败，验证次数和异常链。不要假定 rollback 永不失败。

### 10.1 幂等清理

资源 close 最好能安全重复或至少明确第二次行为，但所有者仍应只调用一次。测试用 cleanup counter 发现双释放。

## 11. `contextlib.contextmanager`

生成器形式：

```python
from contextlib import contextmanager


@contextmanager
def opened_text(path: Path):
    stream = path.open("r", encoding="utf-8")
    try:
        yield stream
    finally:
        stream.close()
```

yield 前对应 enter，yield 值绑定给 as，yield 后/finally 对应 exit。函数必须恰好 yield 一次。

异常从 with 块注入 yield 位置。如果 catch 后不重新抛，可能抑制异常；不要无意吞错。

### 11.1 何时 class vs decorator

- 状态/多方法/复杂协议：class 清楚；
- 简单 acquire-yield-release：contextmanager 简洁；
- 都需要测试成功和异常。

## 12. 多资源与 ExitStack

静态多个 manager：

```python
with source.open() as src, target.open("w") as dst:
    ...
```

后进入的先退出（栈顺序）。动态数量使用 `contextlib.ExitStack` 注册回调/进入 managers；若中途失败，已进入资源按逆序清理。

不要自己用列表加多个 bool 模拟复杂清理而不测中途失败。

异步资源对应 `async with`/`AsyncExitStack`，在 asyncio 章展开。

## 13. 文件安全写入

直接覆盖原 JSON，进程在中途失败可能损坏旧文件。更安全模式：

1. 同目录创建临时文件；
2. UTF-8 写完整内容；
3. flush，按耐久要求 fsync；
4. 原子替换目标（平台/文件系统语义需验证）；
5. 异常时删除临时文件且保留原文件。

context manager 保证 stream close，但不自动保证事务/原子。资源清理与数据完整性是两层合同。

### 13.1 清理失败如何处理

若业务写失败且 close/删除临时也失败，保留主失败并把清理失败记录/链接，或使用 ExceptionGroup 等显式聚合策略。不能让一个低价值删除失败完全覆盖导致数据损坏的根因。

## 14. 资源所有权

```python
def read_orders(stream: TextIO) -> list[WorkOrder]:
    ...
```

如果 stream 由调用者传入，函数通常不应 close；它只借用。若函数自己 open，则负责 close。命名/文档说明：

- owned：创建方释放；
- borrowed：调用期间使用，不释放；
- transferred：所有权明确转移。

同样适用于 socket、数据库连接、线程池、临时目录、锁和 HTTP client。

## 15. 错误翻译边界

分层：

```text
OS FileNotFound/Permission/JSONDecode
    ↓ repository adapter 翻译 + chain
RepositoryUnavailable/CorruptRepositoryData
    ↓ application 决策
Retry / alert / business failure
    ↓ FastAPI boundary
安全 HTTP status + error code + correlation id
```

不要让 API 返回本机路径/traceback；也不要在最底层直接决定 HTTP 500/404。

可重试性不能只按异常类粗猜。PermissionError 通常不重试；临时超时可按幂等性/预算重试；数据损坏重试无效。

## 16. ExceptionGroup 入门边界

并发或多资源清理可能同时产生多个异常。Python 3.11+ 有 ExceptionGroup 与 `except*`。本章只知道：不要丢掉并发子失败；asyncio 章在 TaskGroup 场景使用。

普通顺序代码不要为了“先进”随处聚合。大多数接口仍抛一个有链异常。

## 17. 测试失败矩阵

为文件 Repository 建：

| 场景 | 外部结果 | cause | 资源/文件 oracle |
| --- | --- | --- | --- |
| 正常读 | orders | 无 | close=1 |
| missing（允许空） | None/[] | 无 | 无泄漏 |
| permission | RepositoryUnavailable | PermissionError | close/未打开 |
| JSON 损坏 | CorruptRepositoryData | JSONDecodeError | close=1 |
| 写中途失败 | RepositoryError | OSError | 原文件不变，临时清理 |
| 块内异常 | 原异常传播 | 保留 | exit=1 |
| cleanup 失败 | 明确链/聚合 | 两份证据 | 不静默 |

用 fake manager 记录 enter/exit/close 次数；用 tempfile 隔离文件。测试不要破坏真实用户目录。

### 17.1 检查 cause

```python
with pytest.raises(CorruptRepositoryData) as captured:
    repository.load()

assert isinstance(captured.value.__cause__, json.JSONDecodeError)
```

若不使用 pytest，标准库 unittest/try-except 同样可断言。

## 18. 故障案例

### 18.1 裸 except 返回空

症状：损坏 JSON 看起来像无数据。

首证据：故障 fixture 与代码宽捕获；没有 cause/日志。

修复：仅捕获预期 JSONDecodeError，翻译并 from；重跑 missing 与 corrupt，确保语义不同。

### 18.2 `__exit__` 无条件 True

症状：with 内断言失败但测试继续绿。

首证据：exit 返回 truthy；块后语句执行。

修复：返回 False，除非明确只抑制某类型；测试块异常传播。

### 18.3 finally return

症状：底层异常消失，调用者收到成功值。

首证据：finally 控制转移和缺失 traceback。

修复：finally 只清理；return 放 try 成功路径/函数尾。重跑故障。

### 18.4 丢失 cause

症状：只看到 RepositoryError，无法定位 JSON 行列。

修复：`raise ... from error`，断言 `__cause__`。

### 18.5 双 close

症状：自定义资源报 already closed 或计数 2。

原因：with 已释放，finally 又手工释放。明确一个所有者，保留一次。

## 19. FactoryCare 实验

实现 `JsonWorkOrderRepository`：

- Path 由构造传入；
- UTF-8；
- 文件不存在按合同返回空；
- JSON 损坏翻译 CorruptRepositoryData from JSONDecodeError；
- 保存使用临时文件 + replace；
- 自定义 manager/fake 记录 cleanup；
- 不输出原始敏感数据；
- 同一错误在 Repository/FastAPI 映射层分离。

注入：损坏 JSON、permission（可用 fake 避免平台差异）、写中断、exit 返回 true、finally return。每项保存首异常/链/文件 digest/cleanup 次数和修复后重跑。

## 20. 自测与参考答案

1. **找不到一定抛异常吗？** 不一定，由接口合同决定，可返回 None。
2. **为何不裸 except？** 捕获范围过宽并易吞控制信号/缺陷。
3. **else 何时执行？** try 正常结束且没有异常。
4. **finally 何时执行？** 正常、异常和多数控制转移都执行；不应 return 覆盖异常。
5. **裸 raise 与 raise error？** 前者保留当前 traceback 更适合重抛。
6. **`from error`？** 建立明确 cause，保留底层证据。
7. **`__exit__` true？** 抑制 with 块异常，普通资源管理器通常返回 false。
8. **enter 失败会调用 exit 吗？** 该 manager enter 未成功时不会。
9. **谁 close 传入 stream？** 默认调用者拥有，除非合同转移所有权。
10. **with 是否保证原子写？** 不，只保证退出清理；原子替换另设计。

## 21. 章节验收清单

- [ ] 能区分正常缺失、业务拒绝、基础设施异常和程序缺陷。
- [ ] 能选择具体内置/自定义异常并写合同。
- [ ] 能正确使用 try/except/else/finally 和顺序。
- [ ] 能用 `raise ... from ...` 保留 cause。
- [ ] 能读 traceback 找第一处可信项目边界。
- [ ] 能解释 finally return 与宽捕获的危险。
- [ ] 能实现 class/contextmanager 形式的资源管理器。
- [ ] 能说明 `__exit__` 返回值和 enter 失败边界。
- [ ] 能明确 owned/borrowed/transferred 资源。
- [ ] 能用失败矩阵证明清理一次、链保留、原文件不损坏。

### 21.1 清理代码也要有时间与取消边界

关闭网络连接、等待线程池和提交事务本身可能阻塞或失败。不能因为它位于 finally/`__exit__` 就允许无限等待。资源协议应规定关闭是同步还是异步、最大等待、取消后是否仍必须执行 shielded cleanup，以及超时后留下什么状态。普通同步文件 close 通常很快；远程事务、异步 client 与进程池需要在对应框架中验证。若外层任务被取消，仍要尽最大努力恢复不变量，但也不能永久吞掉取消信号。asyncio 章会用 `async with`、TaskGroup 和取消传播继续实践。

测试中给清理 fake 注入“第一次失败、第二次调用”的场景，确认不会无限重试或重复提交。若 cleanup 失败只能记录而不能恢复，要让监控包含资源种类、操作 ID 和安全错误码，并保留主异常因果；不得只输出一行 `cleanup failed`。对数据库/文件的耐久性还要用进程崩溃和磁盘故障测试，单元 cleanup counter 只是 T1 证据。

### 21.2 API 边界的安全错误响应

内部 traceback 供运维诊断，外部响应只给稳定错误码、可操作消息和 correlation ID。不要把 `str(error)` 无审查返回给客户端，因为 PermissionError 可能包含绝对路径，数据库异常可能包含 SQL/字段，第三方错误可能带 URL 凭证。映射表应测试“异常类型 -> HTTP/CLI 状态 -> 公共码”，同时断言响应不含 path、token、stack。未知异常由顶层记录一次并返回通用内部错误，随后仍保持任务失败证据；不能返回 200 加空结果。

## 22. 官方资料与更新检查

- Errors and exceptions：<https://docs.python.org/3.14/tutorial/errors.html>
- Exception hierarchy：<https://docs.python.org/3.14/library/exceptions.html>
- `with` statement：<https://docs.python.org/3.14/reference/compound_stmts.html#the-with-statement>
- `contextlib`：<https://docs.python.org/3.14/library/contextlib.html>
- `traceback`：<https://docs.python.org/3.14/library/traceback.html>

资料核对日期：2026-07-24。异常展示和工具提示会变化；窄捕获、明确翻译、保留因果、所有权对称和失败路径验证是稳定核心。
