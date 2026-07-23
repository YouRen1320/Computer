---
schema_version: 2
edition: 2026.2-draft
id: ch.python.iterators-decorators
title: 迭代器、生成器、惰性计算与装饰器
responsibility: 解释 iterable/iterator/generator 的惰性与一次性消费，并用保持元数据的装饰器包装函数合同，不把装饰器作为隐藏依赖容器。
volume: '12'
order: 12
level: L2+
status: drafting
path: book/volume-12-python-data/chapters/ch.python.iterators-decorators.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.exceptions-context
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
  text: 在 120 秒内解释“迭代器、生成器、惰性计算与装饰器”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - python-iterator-generator
  - python-decorator-contract
  covers_topics:
  - python.iterable-iterator
  - python.iter-next
  - python.generator-yield
  - python.lazy-evaluation
  - python.generator-cleanup
  - python.function-decorator
  - python.decorator-factory
  - python.wraps-metadata
  - python.decorator-order
  - python.wrapper-exception-boundary
  uses_capabilities:
  - python.language
  - python.io-errors
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现惰性工单读取生成器和记录耗时但保留合同的装饰器；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - python-iterator-generator
  - python-decorator-contract
  covers_topics:
  - python.iterable-iterator
  - python.iter-next
  - python.generator-yield
  - python.lazy-evaluation
  - python.generator-cleanup
  - python.function-decorator
  - python.decorator-factory
  - python.wraps-metadata
  - python.decorator-order
  - python.wrapper-exception-boundary
  uses_capabilities:
  - python.language
  - python.io-errors
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: consumption-trace-metadata-check-failure-fixture
- id: diagnose
  kind: fault-diagnosis
  text: 面对“重复消费生成器、装饰顺序误判或 wrapper 吞异常/丢元数据”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - python-iterator-generator
  - python-decorator-contract
  covers_topics:
  - python.iterable-iterator
  - python.iter-next
  - python.generator-yield
  - python.lazy-evaluation
  - python.generator-cleanup
  - python.function-decorator
  - python.decorator-factory
  - python.wraps-metadata
  - python.decorator-order
  - python.wrapper-exception-boundary
  uses_capabilities:
  - python.language
  - python.io-errors
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 迭代器、生成器、惰性计算与装饰器

> for 循环背后是迭代协议；生成器把“产生下一项”的状态暂停在 `yield`，因此可以惰性处理大数据，也带来一次性消费、关闭和资源所有权问题。装饰器则在定义时用一个可调用对象替换另一个。本章把两种“看似魔法”的语法还原为普通协议与调用顺序。

## 1. Iterable 与 Iterator

可迭代对象（Iterable）能产生 iterator；迭代器（Iterator）能用 `next()` 逐项返回值，耗尽时抛 StopIteration。

```python
items = ["ASSIGNED", "IN_PROGRESS"]
iterator = iter(items)
print(next(iterator))
print(next(iterator))
```

第三次 `next` 抛 StopIteration。for 会自动处理：

```python
iterator = iter(items)
while True:
    try:
        status = next(iterator)
    except StopIteration:
        break
    print(status)
```

真实 for 在 C/解释器层实现，但语义近似。

### 1.1 可迭代对象可多次迭代吗

list 每次 `iter(list)` 通常得到新 iterator，因此可重复遍历。iterator 自己 `iter(iterator) is iterator`，状态会前进，通常一次性。

```python
values = [1, 2]
first = iter(values)
second = iter(values)
assert first is not second
assert iter(first) is first
```

是否可重放是接口合同，不能见到 Iterable 注解就假设无限重放；某些自定义 iterable 仍可能连接一次性源。

## 2. 自定义迭代器

```python
class Countdown:
    def __init__(self, start: int) -> None:
        self.current = start

    def __iter__(self) -> "Countdown":
        return self

    def __next__(self) -> int:
        if self.current <= 0:
            raise StopIteration
        value = self.current
        self.current -= 1
        return value
```

调用 `list(Countdown(3))` 得 [3,2,1]。迭代器保存当前状态，耗尽后应持续 StopIteration，不应重新开始。

多数业务不需手写 class iterator，生成器更简洁；理解协议有助于诊断重复消费。

### 2.1 StopIteration 不应作为普通业务错误泄漏

迭代器协议使用它表示结束。生成器体直接抛 StopIteration 会按 PEP 479 语义转成 RuntimeError，避免无意提前结束；生成器正常结束用 return 或自然走到尾。

## 3. 生成器函数

函数体含 yield 时，调用不会立即执行函数体，而是返回 generator：

```python
def active_statuses(statuses: list[str]):
    print("generator started")
    for status in statuses:
        if status in {"ASSIGNED", "IN_PROGRESS"}:
            yield status


result = active_statuses(["ASSIGNED", "CLOSED"])
print("created")
print(next(result))
```

输出先 created，再 generator started。惰性意味着定义/创建与执行时间分开。

### 3.1 yield 暂停局部状态

每次 yield 返回一个值并暂停当前帧；下次 next 从后面继续，局部变量保留。耗尽后 generator 关闭。

### 3.2 generator expression

```python
active = (
    order
    for order in orders
    if order.status in ACTIVE_STATUSES
)
```

圆括号表达式惰性；方括号 list comprehension 立即物化。需要多次遍历/长度/随机访问时 list 更合适；只流水一次且数据大时 generator 可省内存。

## 4. 惰性计算的成本与优势

优势：

- 按需读取大文件；
- 只消费前 N 项时避免后续工作；
- 流水组合 filter/map；
- 降低峰值内存。

代价：

- 错误延迟到消费时；
- 源资源生命周期跨越消费期；
- 只能一次消费；
- 调试时 `repr` 看不到所有值；
- 多次遍历要重新建立源；
- 计数/排序常需要完全消费。

### 4.1 `list(generator)` 是终结操作

它完全消费并物化，之后 generator 空。调试时 `print(list(gen))` 会把数据吃掉，后续业务得到空。

若需要查看又继续：先明确物化一次保存 list；对无限/巨大生成器不能这么做。

### 4.2 `in`/`any`/`all` 的短路

它们可能只消费到确定结果的位置。剩余 generator 状态从中间继续，不是重新开始。把同一 generator 先 `any` 后 list，后者只有剩余项。

## 5. 工单文件惰性读取

```python
import json
from collections.abc import Iterator
from pathlib import Path


def iter_orders(path: Path) -> Iterator[dict[str, object]]:
    with path.open("r", encoding="utf-8") as stream:
        for line_number, line in enumerate(stream, start=1):
            if line.strip() == "":
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError as error:
                raise CorruptOrderLine(line_number) from error
```

文件保持打开直到 generator 耗尽、关闭或被回收。调用者若只取一项就停止，应显式 close 或使用上下文化接口。

### 5.1 资源范围方案

方案 A：生成器内部 with，要求消费者完全消费或 close；文档清楚。

方案 B：外层 context manager 打开资源并 yield iterator，with 退出强制清理：

```python
with open_order_stream(path) as orders:
    for order in orders:
        ...
```

方案 C：小文件一次性读 list，简单且资源范围短。不要为了惰性而延长资源。

## 6. close、GeneratorExit 与 finally

`generator.close()` 在暂停位置抛 GeneratorExit，让 finally 执行：

```python
def traced():
    try:
        yield 1
        yield 2
    finally:
        print("cleanup")


gen = traced()
next(gen)
gen.close()
```

cleanup 执行。生成器不应捕获 GeneratorExit 后继续 yield，否则 RuntimeError。

### 6.1 不依赖 GC 及时清理

CPython 引用计数有时很快回收，但其他实现/循环引用/生命周期不保证。资源型 generator 要由所有者完全消费或显式 close/context。

### 6.2 `yield from`

```python
def all_orders(paths):
    for path in paths:
        yield from iter_orders(path)
```

它委托迭代并传播 send/throw/close 等协议，远不只是 for 简写。基础使用时理解值和异常沿链传播。

## 7. send/throw 的边界

generator 还支持 `send` 把值送回 yield 表达式、`throw` 注入异常。它能实现协程样式状态机，但 async/await 已是异步主路径。普通数据 pipeline 不应滥用 send，使双向控制难测试。

本章验收只要求 next/for/close/finally/yield from。

## 8. 生成器类型注解

常见只 yield：

```python
from collections.abc import Iterator


def iter_ids() -> Iterator[int]:
    yield 1
```

更完整 `Generator[YieldType, SendType, ReturnType]`。异步生成器对应 AsyncIterator，asyncio 章处理。

输入若只需遍历写 `Iterable[T]`；若必须一次性 `next` 写 `Iterator[T]`；若需要多次/长度/索引，用 Collection/Sequence 等更强合同。

## 9. 装饰器是什么

```python
@trace
def close_order(order_id: int) -> str:
    ...
```

等价于定义函数后：

```python
close_order = trace(close_order)
```

装饰发生在模块执行/函数定义阶段，返回对象替换原名称。调用时实际进入 wrapper。

### 9.1 最小装饰器

```python
def trace(function):
    def wrapper(*args, **kwargs):
        print(f"start {function.__name__}")
        result = function(*args, **kwargs)
        print(f"end {function.__name__}")
        return result
    return wrapper
```

它有问题：元数据变成 wrapper，异常时没有 end，类型签名退化。

## 10. `functools.wraps`

```python
from functools import wraps


def trace(function):
    @wraps(function)
    def wrapper(*args, **kwargs):
        return function(*args, **kwargs)
    return wrapper
```

wraps 更新 `__name__`、`__doc__`、`__module__`、`__annotations__`，设置 `__wrapped__`，帮助 inspect/框架/测试找到原函数。它不自动让静态检查器保留精确签名；现代注解可用 ParamSpec/TypeVar。

```python
from collections.abc import Callable
from typing import ParamSpec, TypeVar

P = ParamSpec("P")
R = TypeVar("R")


def trace(function: Callable[P, R]) -> Callable[P, R]:
    @wraps(function)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
        return function(*args, **kwargs)
    return wrapper
```

## 11. 正确记录成功、异常和耗时

```python
from time import perf_counter


def timed(function):
    @wraps(function)
    def wrapper(*args, **kwargs):
        started = perf_counter()
        outcome = "error"
        try:
            result = function(*args, **kwargs)
            outcome = "success"
            return result
        finally:
            elapsed = perf_counter() - started
            record_metric(function.__qualname__, outcome, elapsed)
    return wrapper
```

finally 记录两种结果，但不能 return/吞异常。日志/指标不得记录 args 中敏感数据。`perf_counter` 适合持续时长，不用 wall clock。

### 11.1 同步装饰器不能直接测异步完成

包装 async function 的普通 wrapper 只测创建 coroutine，不测 await 完成。需要 async wrapper 并 await。测试/async 章展开；装饰器必须区分可调用类型。

## 12. 带参数的装饰器工厂

```python
def retry(*, attempts: int):
    if attempts < 1:
        raise ValueError("attempts must be >= 1")

    def decorate(function):
        @wraps(function)
        def wrapper(*args, **kwargs):
            ...
        return wrapper

    return decorate


@retry(attempts=3)
def load(): ...
```

三层：工厂接配置 -> decorator 接函数 -> wrapper 接调用参数。配置在定义时验证。

重试不是通用示例：只对临时且幂等操作、有限预算、退避抖动；不要装饰所有异常，也不要重试业务拒绝。

## 13. 多层装饰顺序

```python
@outer
@inner
def work(): ...
```

定义等价：`work = outer(inner(work))`。调用顺序通常 outer-before -> inner-before -> function -> inner-after -> outer-after。

用轨迹证明：

```text
outer enter
inner enter
body
inner exit
outer exit
```

认证、事务、重试、缓存的顺序会改变语义。例如缓存放认证外可能泄露用户结果；事务与重试嵌套决定每次重试是否新事务。不能只凭视觉上下顺序猜。

## 14. wrapper 异常边界

错误：

```python
try:
    return function(*args, **kwargs)
except Exception:
    return None
```

吞掉业务/程序异常并改变返回类型。装饰器默认应让异常传播；若做转换/重试，精确捕获、保留 cause、文档化并测试。

cleanup/after 日志放 finally，但 finally 自己失败会覆盖原异常。观测代码应尽量不抛；失败时降级且不得泄露。

## 15. 装饰器与描述符/方法

普通函数装饰后作为类属性仍需保持描述符绑定。返回普通 function 的 wrapper 通常正常；返回自定义可调用对象可能丢失 `self` 绑定，需实现 `__get__` 或使用合适工具。

classmethod/staticmethod/property 与自定义装饰器顺序影响传入对象。不要随意叠加，写实例/类调用测试。

## 16. 不把装饰器当隐藏依赖容器

`@inject_everything` 从全局容器取 repository/logger/config，看似函数参数简洁，却隐藏测试输入和依赖方向。装饰器适合横切且合同明确的观测、授权标记、框架注册；核心业务依赖仍显式参数/构造注入。

FastAPI 的 decorator/register 行为属于框架表面，理解定义时执行和元数据保留很重要，但不要自造大量魔法。

## 17. 常见故障

### 17.1 生成器被消费两次

```python
orders = iter_orders(path)
count = sum(1 for _ in orders)
for order in orders:
    process(order)  # 空
```

首证据：消费轨迹/next 次数，第二次已经 exhausted。修复一次循环同时计数处理、重新创建生成器，或可控物化 list。

### 17.2 调试 list 吃掉数据

`print(list(orders))` 是一次完整消费。修复不要在正式路径这么调；用 tee 也会缓存且有内存/时序风险，不是免费复制。

### 17.3 提前 break 未关文件 generator

资源仍开。使用 context 化迭代或 try/finally 显式 close。测试 close counter。

### 17.4 装饰器丢元数据

框架路由/文档看到名称 wrapper、签名 `*args`。首证据 `__name__`、signature、`__wrapped__`。修复 `@wraps` + ParamSpec，重跑框架/inspect 测试。

### 17.5 装饰顺序误判

调用轨迹与期待不同。把 `outer(inner(f))` 展开，测试 success/error 顺序，调整并解释安全影响。

### 17.6 wrapper 吞异常

原函数 RuntimeError 变 None，调用者后续 TypeError。修复让原异常传播或精确转换 from；测试 traceback/cause。

## 18. 测试策略

生成器：

- 创建时源未读取；
- first next 只读一项；
- 完全消费次数；
- 第二次消费空；
- close 执行 finally 一次；
- 中间解析错误保留行号/cause；
- 提前 break 的所有者清理。

装饰器：

- 返回值不变；
- 参数/kwargs 转发；
- 异常类型/traceback 不吞；
- `__name__`/doc/annotations/`__wrapped__`；
- inspect.signature；
- 多层 enter/exit 顺序；
- 观测失败不覆盖主失败。

## 19. FactoryCare 实验

实现 JSON Lines 工单生成器：每行惰性解析，只产出 active，错误翻译含 line number，提前停止可关闭资源。再实现 `@timed(operation="read-active-orders")`：用 perf_counter，保留元数据，成功/异常均记录 outcome，不记录 payload，不吞异常。

实验序列：

1. 创建 generator，断言 open/read=0；
2. next，断言只读到首个符合项；
3. close，断言 cleanup=1；
4. 新 generator 全消费；
5. 再消费同一对象为空；
6. 损坏第三行，断言 cause；
7. 检查 decorated signature/name；
8. 叠两层记录轨迹。

离线文件证据不代表生产超大文件性能；profile/内存测量另做。

## 20. 自测与参考答案

1. **Iterable 与 Iterator？** Iterable 产 iterator；Iterator 有状态 next 并耗尽。
2. **list 可多次遍历吗？** 通常可以，每次新 iterator；generator 通常一次。
3. **调用生成器函数会执行函数体吗？** 不立即，首次迭代开始。
4. **list(gen) 后？** gen 已完全消费。
5. **close 做什么？** 注入 GeneratorExit，让 finally 清理。
6. **为何不依赖 GC 关资源？** 回收时机/实现不保证。
7. **decorator 语法等价？** `f = decorator(f)`。
8. **wraps 保留什么？** 名称、文档、注解、wrapped 等元数据；静态签名还需 ParamSpec。
9. **两层顺序？** 定义 outer(inner(f))，调用外进内出。
10. **越界反例？** 装饰器偷偷从全局拿 Repository；核心依赖应显式。

## 21. 章节验收清单

- [ ] 能手写 iter/next/StopIteration 展开 for。
- [ ] 能区分可重放 Iterable 与一次性 Iterator。
- [ ] 能解释 yield 暂停与惰性错误时机。
- [ ] 能选择 generator/list 并说明内存/重放权衡。
- [ ] 能让资源型 generator 在完全/提前结束时清理。
- [ ] 能解释 decorator 定义时替换与调用 wrapper。
- [ ] 能使用 wraps、ParamSpec、TypeVar 保留合同。
- [ ] 能展开多层装饰顺序并验证异常路径。
- [ ] 能避免 wrapper 吞错、泄密和隐藏核心依赖。
- [ ] 能运行消费轨迹、cleanup、metadata 和 failure fixture。

### 21.1 惰性 pipeline 的所有者必须唯一

当一个服务返回 Iterator 时，要说明谁负责启动消费、谁可提前停止、谁关闭底层资源、能否跨线程/任务传递。不要把绑定数据库 cursor 的 generator 从 repository 一路返回到 HTTP 框架后再希望 GC 收尾；请求取消、序列化异常和客户端断连都会改变消费终点。更安全的边界可能是在 repository 内完全物化有限页，或返回同时实现 context manager 的流对象。选择依据是数据规模、延迟、连接预算和取消需求，不是“生成器更省内存”一句话。

多个惰性步骤串联时，最下游第一次 next 才会触发上游。故障日志应记录 pipeline 阶段与输入位置，避免只看到最终消费行。对无限流，任何 `list`、`sorted`、`sum` 都可能永不返回；必须有 `islice`、哨兵、取消或外部上界。性能测试同时测首项延迟、总吞吐、峰值内存与资源占用，不能只比较完成时间。

### 21.2 装饰器配置属于导入时副作用

装饰器工厂在模块导入、函数定义时执行。若工厂此时访问网络、数据库或读取易变秘密，单纯 import 就可能失败，测试收集/CLI 帮助也被阻塞。定义阶段只做纯配置验证和包装；昂贵依赖在明确应用装配或调用期提供。框架注册类装饰器确实会在导入时登记路由，但应保持确定、幂等，并测试模块重复导入/开发 reload 的行为。热重载下重复注册、全局列表增长和旧 wrapper 保留都是实际风险。

## 22. 官方资料与更新检查

- Iterator types：<https://docs.python.org/3.14/library/stdtypes.html#iterator-types>
- Generator expressions：<https://docs.python.org/3.14/reference/expressions.html#generator-expressions>
- `yield`：<https://docs.python.org/3.14/reference/expressions.html#yield-expressions>
- `functools.wraps`：<https://docs.python.org/3.14/library/functools.html#functools.wraps>
- `typing.ParamSpec`：<https://docs.python.org/3.14/library/typing.html#typing.ParamSpec>

资料核对日期：2026-07-24。生成器和装饰器 API 会扩展；一次性消费、显式资源所有权、定义/调用顺序、元数据与异常透明是稳定核心。
