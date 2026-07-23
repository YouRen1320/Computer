---
schema_version: 2
edition: 2026.2-draft
id: ch.python.testing-logging-debug
title: pytest、fixture、Mock、日志与调试证据
responsibility: 用 pytest、fixture、参数化和受控替身建立可信单元测试，并用结构化日志、调试器和 traceback 定位失败，不提前教授 asyncio 测试。
volume: '12'
order: 13
level: L2+
status: drafting
path: book/volume-12-python-data/chapters/ch.python.testing-logging-debug.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.exceptions-context
version_surfaces:
- python-3.14
- pytest
- uv
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“pytest、fixture、Mock、日志与调试证据”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - python-pytest
  - python-logging-debugging
  covers_topics:
  - python.pytest-test
  - python.pytest-fixture
  - python.pytest-parametrize
  - python.mock-fake-boundary
  - python.test-isolation
  - python.structured-logging
  - python.log-level-context
  - python.debugger
  - python.traceback-evidence
  - python.failure-stage
  uses_capabilities:
  - python.language
  - python.io-errors
  - foundation.verification-debug-test
  - python.testing-debugging
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“pytest、fixture、Mock、日志与调试证据”构建可运行程序与测试：为工单服务建立参数化 pytest、Fake repository、日志捕获和一次红绿故障记录；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - python-pytest
  - python-logging-debugging
  covers_topics:
  - python.pytest-test
  - python.pytest-fixture
  - python.pytest-parametrize
  - python.mock-fake-boundary
  - python.test-isolation
  - python.structured-logging
  - python.log-level-context
  - python.debugger
  - python.traceback-evidence
  - python.failure-stage
  uses_capabilities:
  - python.language
  - python.io-errors
  - foundation.verification-debug-test
  - python.testing-debugging
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: pytest-unit-log-capture-debugger-injected-fault
- id: diagnose
  kind: fault-diagnosis
  text: 面对“fixture 共享状态、过度 Mock、错误预言或 catch 后只记日志继续成功”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - python-pytest
  - python-logging-debugging
  covers_topics:
  - python.pytest-test
  - python.pytest-fixture
  - python.pytest-parametrize
  - python.mock-fake-boundary
  - python.test-isolation
  - python.structured-logging
  - python.log-level-context
  - python.debugger
  - python.traceback-evidence
  - python.failure-stage
  uses_capabilities:
  - python.language
  - python.io-errors
  - foundation.verification-debug-test
  - python.testing-debugging
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# pytest、fixture、Mock、日志与调试证据

> 测试不是“运行代码看看有没有报错”，日志也不是“多 print”。可信反馈链先写行为合同和独立 oracle，再用隔离 fixture 驱动成功、边界、失败；故障发生时从 pytest 报告、traceback、结构化日志和调试器逐层取证。本章只覆盖同步代码，异步测试留到下一章。

## 1. 一个测试必须能证伪实现

业务函数：

```python
def calculate_total(unit_price_cents: int, quantity: int) -> int:
    return unit_price_cents * quantity
```

pytest：

```python
def test_calculates_total_for_multiple_items() -> None:
    result = calculate_total(1999, 3)
    assert result == 5997
```

测试有 Arrange（输入）、Act（调用）、Assert（独立预期）。如果把实现同一表达式复制到 expected：

```python
expected = 1999 * 3
```

简单算术尚可读，但复杂业务会复制同一个 bug。优先从需求表写常量/小型 oracle。

### 1.1 先让测试红一次

将实现临时改为加法，确认测试在预期断言失败，再恢复乘法并变绿。这是 mutation sanity：证明测试真的保护目标。若改坏仍绿，测试可能未收集、断言错误或路径没执行。

## 2. pytest 的发现与运行

典型命名：

```text
tests/test_amount.py
test_*.py
def test_...():
```

命令：

```bash
uv run pytest
uv run pytest -q
uv run pytest tests/test_amount.py::test_calculates_total_for_multiple_items
uv run pytest -x
```

项目通过 pyproject 配置 testpaths、markers、strict 选项等并锁定 pytest 版本。不要依赖机器全局 pytest；`uv run` 确保项目环境。

### 2.1 收集 0 个测试不是成功证据

pytest 退出码/摘要要看：`collected N items`、passed/failed/error/skipped。CI 应对 0 测试或意外全 skip 失败/告警。只看 shell 绿色不够。

### 2.2 Failure 与 Error

- failed 常是断言不满足；
- error 常是 fixture setup/collection/import 出错；
- 两者都导致门禁失败，但定位阶段不同。

读取 pytest 最短摘要、具体 assertion diff、traceback 的第一处项目行。

## 3. 断言写可观察合同

pytest 重写普通 assert，展示表达式值：

```python
assert result.status == "CLOSED"
assert [order.id for order in result] == [1, 2]
```

失败消息可补业务上下文：

```python
assert result == 5997, "total must be in cents"
```

不要一条 assert 比较十个无关属性；失败后难定位。也不要测试私有实现步骤，如“内部调用三次 helper”，除非调用次数就是外部合同（例如只发送一次消息）。

### 3.1 浮点与异常

浮点用 `pytest.approx`；异常：

```python
with pytest.raises(ValueError, match="quantity"):
    calculate_total(1999, 0)
```

只写 `raises(Exception)` 过宽，错误 NameError 也能让测试绿。检查具体类型、消息/属性和 cause（需要时）。

## 4. 参数化：同一规则的边界表

```python
@pytest.mark.parametrize(
    ("priority", "expected"),
    [
        pytest.param(0, "INVALID", id="below-min"),
        pytest.param(1, "LOW", id="min"),
        pytest.param(4, "URGENT", id="urgent-boundary"),
        pytest.param(5, "URGENT", id="max"),
        pytest.param(6, "INVALID", id="above-max"),
    ],
)
def test_classifies_priority(priority: int, expected: str) -> None:
    assert classify(priority) == expected
```

每组是独立 case，ID 让失败可读。参数化适合同一行为规则，不要把完全不同流程塞一函数。

### 4.1 参数值不会自动复制

pytest 官方文档提醒参数值按原对象传入。如果用可变 list 并在测试中修改，后续 case 可受污染。使用不可变输入、factory 或 fixture 每次创建。

### 4.2 边界来自合同

阈值 4 至少测 3/4/5，范围 1..5 测 0/1/5/6。参数越多不是越好；每个有理由和可读 ID。

## 5. fixture：依赖与清理

```python
@pytest.fixture
def repository() -> MemoryRepository:
    return MemoryRepository()


def test_saves_order(repository: MemoryRepository) -> None:
    repository.save(WorkOrder(1, "ASSIGNED"))
    assert repository.get(1) == WorkOrder(1, "ASSIGNED")
```

fixture 按名称注入。默认 function scope 每个测试新实例，有利隔离。

### 5.1 yield fixture

```python
@pytest.fixture
def store(tmp_path: Path):
    path = tmp_path / "orders.json"
    repository = JsonRepository(path)
    yield repository
    assert repository.open_handles == 0
```

yield 前 setup，后 teardown；即使测试失败也清理。若 setup 在 yield 前一半失败，只有已成功注册/进入的清理会执行，复杂资源用 context manager/ExitStack。

### 5.2 scope

function/class/module/package/session。扩大 scope 可提速，但共享可变状态和顺序依赖风险增加。数据库容器可 session 级基础设施 + 每测试事务/独立 schema，不能直接共享业务数据。

### 5.3 autouse

自动 fixture 隐藏依赖，适合全局安全清理/阻止真实网络等少量策略；业务 fixture 显式注入更清楚。

## 6. 测试隔离

一个测试无论单独、全量、随机顺序、重复运行都应一致。隔离维度：

- 全局/类可变状态；
- 文件和当前目录；
- 环境变量；
- 时间/随机数；
- 网络/数据库；
- 日志 handler；
- 缓存/singleton；
- 端口/线程/进程。

### 6.1 tmp_path

pytest 提供每测试临时 Path，避免写真实目录。测试失败可根据配置保留证据，但不能依赖上次文件。

### 6.2 monkeypatch

临时修改属性、环境、字典、cwd/sys.path，测试结束自动恢复：

```python
def test_reads_mode(monkeypatch):
    monkeypatch.setenv("APP_MODE", "test")
    assert load_mode() == "test"
```

patch 使用处的名称，而非定义处的原始对象。更好设计是显式注入 config/clock，减少 patch。

### 6.3 时间与随机

注入 `clock: Callable[[], datetime]`、Random 实例/seed，而不是 sleep 或依赖今天日期。冻结时间库也要锁版本并理解边界。

## 7. Fake、Stub、Spy、Mock

术语常混用，关键是替身承担什么：

- Stub：返回预设结果；
- Fake：可运行简化实现，如内存 Repository；
- Spy：记录调用供断言；
- Mock：预设交互期望，常由框架生成。

### 7.1 优先 fake 验证行为

应用服务依赖 Repository Protocol，可传 MemoryRepository，断言最终状态。比 mock “get 被调用一次、save 被调用一次且顺序固定”更不易耦合重构。

### 7.2 何时 spy/mock 合理

外部副作用边界：发送消息必须恰一次、未授权不得调用网关、幂等重放不重复支付。对 interaction 本身有业务意义时断言。

### 7.3 autospec/spec

使用 unittest.mock 时用 spec/autospec 限制不存在成员和签名。无 spec 的 MagicMock 可能接受错误方法，让测试假绿。

### 7.4 不 mock 数据对象

dataclass/value object 直接构造。mock `order.status` 容易得到另一个 Mock，比较和 truthiness 产生假象。

## 8. 测试金字塔与边界

- T1 单元：纯规则、应用服务 + fake，快；
- T2 组件：文件/数据库适配器、FastAPI 测试 client；
- T3 集成/合同：真实 DB/Java API mock server/协议；
- T4 端到端：部署环境、故障注入。

不能靠 500 个 mock 单测证明 SQL、JSON、HTTP 和授权正确；也不能全靠慢 E2E。每层有独立 oracle。

## 9. 结构化日志

```python
import logging

logger = logging.getLogger(__name__)

logger.info(
    "work_order_closed",
    extra={
        "event": "work_order_closed",
        "order_id": order.id,
        "correlation_id": correlation_id,
    },
)
```

标准 logging 生成 LogRecord；真正 JSON 格式可由 handler/formatter 提供。事件名与字段稳定，避免只拼长字符串。

### 9.1 library 不配置 root

库模块获取 `getLogger(__name__)`，应用入口配置 handler/level/format。库不要调用 basicConfig 或添加重复 handler。

### 9.2 日志级别

- DEBUG：开发诊断，生产通常关闭；
- INFO：重要正常生命周期/业务事件；
- WARNING：可恢复异常/退化需关注；
- ERROR：当前操作失败；
- CRITICAL：系统级严重不可用。

不要把每次函数进入都 INFO；噪声降低信噪比并增加成本。

### 9.3 correlation 与 context

跨 Java/Python 请求传播 correlation/trace ID；记录工单 ID（若合规）、操作、结果、耗时、错误码。不记录 token、密码、完整 cookie、原始提示/文件内容、向量、PII。

字段名称/类型是日志合同，进入 schema/版本管理。

## 10. 异常日志

在 except 内：

```python
try:
    repository.load()
except RepositoryError:
    logger.exception("repository_load_failed", extra={"event": "repository_load_failed"})
    raise
```

`logger.exception` 附当前 traceback。不要底层、应用层、API 层每层都记录同一异常；选择首次拥有足够上下文且决定处理的边界。

### 10.1 日志不是恢复

```python
except Exception:
    logger.exception("failed")
return []
```

仍是吞错。应重新抛/翻译/返回明确 Result，保持失败状态。

### 10.2 日志注入

用户输入含换行/控制字符可能伪造文本日志。结构化编码器与字段清洗，不能字符串拼接。敏感值 allowlist，不是 denylist 后再补。

## 11. pytest 的日志捕获

`caplog`：

```python
def test_logs_safe_error(caplog):
    with caplog.at_level(logging.ERROR):
        service.run(correlation_id="corr-1")

    assert any(record.event == "operation_failed" for record in caplog.records)
    assert "secret" not in caplog.text
```

测试级别、事件、关联 ID、无敏感字段。不要精确匹配带时间/行号的完整格式，除非 formatter 本身合同。

## 12. traceback 与失败阶段

失败链：

```text
collection/import -> fixture setup -> test call -> assertion -> fixture teardown
```

pytest 报告标阶段。teardown error 与 test failure 可同时存在，都要修。

读法：

1. 失败 case ID；
2. 异常/断言 diff；
3. 最靠近断言的 actual/expected；
4. 第一处项目实现帧；
5. cause/context；
6. captured stdout/stderr/log。

不要从第三方栈顶直接改库；先检查传入数据。

## 13. pdb 与 breakpoint

```python
breakpoint()
```

进入当前调试器（受 PYTHONBREAKPOINT 配置）。pdb 基本命令：

- `where` 看栈；
- `up/down` 切帧；
- `list` 源码；
- `p expr` 值；
- `pp` 漂亮打印；
- `next` 当前帧下一行；
- `step` 进入调用；
- `continue` 继续；
- `break`/`condition` 断点。

pytest：

```bash
uv run pytest --pdb -x
uv run pytest --trace
```

Python 3.14 的 pdb 增加 attach PID、异步 set_trace 等能力，但使用前评估生产安全/审计；不在生产随意 attach 或执行表达式。

### 13.1 post-mortem

失败后检查当时栈比复现中乱加 print 更有效。固定 fixture 先保证可重现，再调试。

### 13.2 debugger 会改变时序

断点影响超时、线程/异步竞态，不能用“断点下正常”证明并发正确。保存无调试器日志和受控调度测试。

## 14. 常见测试假绿

### 14.1 没断言

调用不报错就 pass，错误返回也绿。加入独立 oracle。

### 14.2 断言 actual 等于自身

`assert result == result` 永远真（NaN 等特殊除外），没有价值。

### 14.3 只 mock 实现

mock 返回 expected，服务原样返回，测试证明 mock 配置而非业务。加入真实 domain/fake。

### 14.4 捕获 Exception

测试期待“会失败”却 NameError 也满足。限定类型、消息/属性和失败阶段。

### 14.5 共享 fixture

session 级内存 repo 上一个测试留数据，单独/全量结果不同。function scope 或每次 reset，有顺序随机验证。

### 14.6 改 expected 迎合 bug

实现从 5997 变 2002，不能把 expected 改 2002 只为绿。回到需求表；若需求改变，提交决策和所有影响。

## 15. 调试协议

1. 用完整命令复现一次；
2. 保存 pytest 版本、Python、case ID、seed/输入；
3. 分类 collection/setup/call/assert/teardown；
4. 找首个可信证据；
5. 用单 case 加速，但最终全量；
6. 必要时 breakpoint/post-mortem；
7. 做最小修复；
8. 原失败 case 绿；
9. 相邻边界/全量/随机顺序；
10. 删除临时调试、检查日志脱敏。

## 16. FactoryCare 测试设计

服务：关闭工单。输入 order_id/actor，Repository fake，Authorization port，Event publisher spy。

参数矩阵：

- ASSIGNED -> CLOSED，save/event 一次；
- IN_PROGRESS -> CLOSED；
- CLOSED 重放幂等，不重复 event；
- missing -> WorkOrderNotFound；
- unauthorized -> 不 save、不 publish；
- repo unavailable -> 保留 cause，ERROR 日志含 correlation，不含 payload；
- event publish fail -> 状态/事务策略明确。

日志 caplog；tmp_path 文件适配器；故意把状态改错确认断言红。

## 17. 公开练习的预期红

学习仓库 public exercise 初始失败是课程合同。验证脚本应输出明确 `EXPECTED RED` 和目标缺口。私有解绿。全仓校验要把这种预期红与基础设施错误区分，不能看到非零就删测试或改 oracle。

### 17.1 把“红”分成三类

第一类是**预期红**：练习故意留下一个明确缺口，失败的测试名称、断言差异和退出码都与题目一致。它证明练习确实能抓住目标错误。第二类是**意外红**：下载失败、解释器版本不匹配、路径错误或 pytest 根本没有收集到目标文件。这类失败不能算学习证据，必须先修复环境。第三类是**错误的绿**：验证脚本吞掉 pytest 的非零退出码，或者测试没有断言、没有收集到用例。它最危险，因为表面成功却没有验证任何行为。

因此验证脚本至少要检查三件事：pytest 真的启动了；目标测试确实被收集并执行；失败发生在约定的断言而非导入或环境阶段。公开练习的脚本可以在确认目标失败后打印 `EXPECTED RED`，但最终仍返回非零；私有解和示例则必须返回零。这样，自动化既能理解课程合同，人也能从日志区分“该红的红”和“坏掉的红”。

### 17.2 证据包应保存什么

一次可复核的测试记录不是一张绿色截图。最小证据包包含：执行命令、Python 与 pytest 版本、工作目录、被测提交或文件摘要、收集数、通过/失败/跳过数、首个可信项目位置、修复说明和修复后的完整重跑。如果故障依赖随机数、时间或输入，还要保存 seed、时区与脱敏后的输入样本。

日志只是证据的一部分。INFO 日志能说明哪一个业务事件被处理；DEBUG 可辅助解释内部路径；WARNING/ERROR 能暴露降级与失败。但“日志里看起来正常”不能替代断言，因为日志语句本身也可能写错。反过来，测试通过也不代表日志安全：还要显式断言 token、身份证号、完整请求体等敏感信息没有出现。

### 17.3 从一次失败走到可信结论

假设 `close_order` 的测试显示期望 `CLOSED`、实际 `IN_PROGRESS`。先确认失败在测试调用阶段，而不是 fixture 创建阶段；再看 traceback 第一处业务代码，确定状态转换没有执行还是保存了错误对象。修复后先重跑原用例，再运行同状态边界、权限失败、重复关闭和仓储异常用例，最后全量执行。若只把断言改成 `IN_PROGRESS`，测试会绿，却破坏了需求；若只让单个用例绿而未跑全量，其他状态可能已经回归。

这套流程的核心不是追求“全绿”这个颜色，而是建立一条可反驳、可重放的推理链：需求给出 oracle，测试构造受控输入，失败信息指向阶段，修复改变最小行为，回归验证排除邻近破坏。面试或工作中真正有价值的能力，就是能把这条链讲清楚并交给别人复现。

## 18. 自测与参考答案

1. **BUILD/进程成功等于功能正确吗？** 不等，需测试及 oracle。
2. **0 tests 能算通过？** 不能作为功能证据，应检查收集数。
3. **参数化值会复制吗？** 默认按原对象传，修改可污染后续。
4. **fixture 默认 scope？** function，每测试新实例。
5. **Fake 与 Mock？** Fake 是简化可运行实现；Mock 常预设交互。
6. **何时断言调用次数？** 副作用次数本身是业务合同。
7. **logger.exception 后 return []？** 仍可能吞错，不是恢复。
8. **先读 traceback 哪？** case/异常/diff，再第一处可信项目帧和 cause。
9. **断点能证明并发吗？** 不能，断点改变时序。
10. **越界反例？** 本章不教 asyncio Task 测试或真实生产故障演练。

## 19. 章节验收清单

- [ ] 能写 Arrange/Act/Assert 且 oracle 独立。
- [ ] 能确认 pytest 收集数、failed/error/skip 和退出码。
- [ ] 能用参数化覆盖边界并提供 case ID。
- [ ] 能设计 function-scope/yield fixture 与可靠清理。
- [ ] 能用 tmp_path/monkeypatch/注入隔离环境、时间、随机。
- [ ] 能选择 Fake/Stub/Spy/Mock，避免过度交互断言。
- [ ] 能配置模块 logger 与结构化安全字段。
- [ ] 能用 caplog 断言事件且排除敏感值。
- [ ] 能按阶段读 pytest/traceback 并用 pdb 定位。
- [ ] 能执行故障注入红->修复绿->全量回归。

## 20. 官方资料与更新检查

- pytest 文档：<https://docs.pytest.org/en/stable/>
- Fixtures：<https://docs.pytest.org/en/stable/how-to/fixtures.html>
- Parametrize：<https://docs.pytest.org/en/stable/how-to/parametrize.html>
- Logging：<https://docs.python.org/3.14/library/logging.html>
- pdb：<https://docs.python.org/3.14/library/pdb.html>
- traceback：<https://docs.python.org/3.14/library/traceback.html>

资料核对日期：2026-07-24。pytest/uv/pdb 功能会更新；独立 oracle、隔离、替身边界、结构化脱敏和失败阶段证据是稳定核心。
