---
schema_version: 2
edition: 2026.2-draft
id: ch.python.pydantic-validation
title: Pydantic 模型、校验、序列化与错误
responsibility: 用 Pydantic 模型在不可信输入边界执行类型转换、字段/模型校验、序列化和稳定错误映射，区分 Python 类型标注与运行时验证。
volume: '12'
order: 15
level: L2+
status: drafting
path: book/volume-12-python-data/chapters/ch.python.pydantic-validation.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.exceptions-context
version_surfaces:
- python-3.14
- pydantic-2
- pytest
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“Pydantic 模型、校验、序列化与错误”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - pydantic-model-validation
  - pydantic-serialization-schema
  covers_topics:
  - pydantic.base-model
  - pydantic.field-validator
  - pydantic.model-validator
  - pydantic.strict-coercion
  - pydantic.validation-error
  - pydantic.model-dump
  - pydantic.alias
  - pydantic.extra-field-policy
  - pydantic.json-schema
  - pydantic.model-versioning
  uses_capabilities:
  - python.language
  - python.io-errors
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为工单创建/响应定义 Pydantic 模型、跨字段规则和版本化错误快照；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - pydantic-model-validation
  - pydantic-serialization-schema
  covers_topics:
  - pydantic.base-model
  - pydantic.field-validator
  - pydantic.model-validator
  - pydantic.strict-coercion
  - pydantic.validation-error
  - pydantic.model-dump
  - pydantic.alias
  - pydantic.extra-field-policy
  - pydantic.json-schema
  - pydantic.model-versioning
  uses_capabilities:
  - python.language
  - python.io-errors
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: valid-invalid-payloads-roundtrip-schema-error-snapshot
- id: diagnose
  kind: fault-diagnosis
  text: 面对“意外宽松转换、额外字段静默或序列化 alias 漂移”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - pydantic-model-validation
  - pydantic-serialization-schema
  covers_topics:
  - pydantic.base-model
  - pydantic.field-validator
  - pydantic.model-validator
  - pydantic.strict-coercion
  - pydantic.validation-error
  - pydantic.model-dump
  - pydantic.alias
  - pydantic.extra-field-policy
  - pydantic.json-schema
  - pydantic.model-versioning
  uses_capabilities:
  - python.language
  - python.io-errors
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Pydantic 模型、校验、序列化与错误

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《异常、上下文管理器与资源清理》](ch.python.exceptions-context.md)：ValidationError 需要在稳定异常映射边界中转化。
<!-- END GENERATED LEARNING PREREQUISITES -->

> Python 类型标注主要帮助人、编辑器和静态检查器理解代码；它不会自动阻止运行时收到错误数据。Pydantic 的职责，是在 JSON、消息、配置和外部服务响应等不可信边界，把输入解析成满足声明的 Python 对象，或者产生结构化的 `ValidationError`。它不是数据库、权限系统，也不是 FactoryCare 业务真相的所有者。

## 1. 为什么仅写类型标注还不够

下面的函数声明希望 `priority` 是整数，但 Python 运行时不会仅因标注就拒绝字符串：

```python
def raise_priority(priority: int) -> int:
    return priority + 1
```

调用者仍能传入 `"4"`。错误可能直到执行加法时才暴露，而且报错位置已经离输入边界很远。来自 HTTP JSON 的对象还可能缺字段、多字段、字段嵌套错误或组合关系非法。若业务代码到处写 `payload.get(...)` 和临时转换，错误语义会分散，静态类型也失去价值。

Pydantic 模型把边界合同集中表达：字段叫什么、是什么类型、是否必填、允许什么范围、额外字段怎么处理、跨字段关系是什么、输出怎样序列化。验证成功后，内部代码拿到的是模型实例；验证失败时，边界层把错误映射为稳定协议。关键语义是：Pydantic 保证的是**验证后的输出对象**满足模型规则，并不保证原始输入本来就是那个 Python 类型，因为宽松模式可能执行转换。

## 2. `BaseModel`：把字典变成有合同的对象

Pydantic 2 的典型模型继承 `BaseModel`：

```python
from pydantic import BaseModel, ConfigDict, Field

class WorkOrderCreate(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")

    title: str = Field(min_length=1, max_length=120)
    priority: int = Field(ge=1, le=5)
    device_id: int = Field(gt=0)
```

`model_validate(payload)` 接收 Python 对象并进行验证；`model_validate_json(raw)` 直接处理 JSON 字符串或字节。成功后可用 `order.title` 访问字段，而不是让整个系统继续传递无约束字典。失败会抛出 `ValidationError`，不会返回“半合法模型”。

模型适合放在系统边界和清晰的层间合同处，不应把每个局部变量都包装成模型。大量极小模型会增加认知与运行成本；完全不用边界模型又会让不可信输入渗透到内部。判断标准不是“能不能用 Pydantic”，而是“这里是否存在需要被明确验证、记录和版本化的合同”。

## 3. 必填、可空和默认值不是一回事

初学者常把 `str | None` 理解为“可不传”，其实它主要表示值可以是字符串或 `None`。字段是否必填，还取决于有没有默认值：

```python
class PatchRequest(BaseModel):
    reason: str | None              # 必须出现，但值可为 None
    note: str | None = None         # 可以省略，省略后为 None
    enabled: bool = True            # 可以省略，使用默认 True
```

更新接口还要区分“字段没提交”和“明确提交 null”。`model_fields_set` 能显示输入中实际提供了哪些字段；序列化时 `exclude_unset=True` 可只输出已提交字段。若直接把缺失和 `None` 混为一谈，补丁请求可能意外清空数据库字段。

默认值也需要审慎。默认列表应通过 `Field(default_factory=list)` 表达意图；依赖当前时间、随机数或请求上下文的默认值尤其要测试。不要假设每个默认值都会像普通输入一样被校验；需要时显式配置默认值验证，并用对应版本的测试确认。

## 4. 约束字段：类型正确不代表语义有效

整数 `priority` 仍可能是 `99`，字符串 `title` 仍可能为空。`Field` 可以声明长度、数值范围、模式、别名和说明：

```python
class WorkOrderCreate(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")

    title: str = Field(min_length=1, max_length=120)
    priority: int = Field(ge=1, le=5)
    tags: list[str] = Field(default_factory=list, max_length=20)
```

这些是边界规则，不等于完整业务规则。比如“只有值班主管能把优先级设为 5”需要身份、权限和当前业务状态，不能仅靠模型字段完成。Pydantic 适合验证形状、局部值和不依赖外部 I/O 的组合不变量；授权、库存、工单状态机等仍由 Java 业务服务负责。

字段约束应该可解释。若用一个复杂正则表达式隐藏所有规则，错误会难以定位，也容易与前端、Java 合同漂移。优先给规则命名，配合法输入、边界输入和失败输入测试。

## 5. 宽松转换与严格模式

Pydantic 默认倾向于实用的解析。例如某些场景中字符串数字可以转换为整数。这对读取环境变量或兼容旧数据很方便，但在 API 合同、标识符和金额字段中可能掩盖调用方错误：前端发了 `"5"`，测试仍然通过，直到另一个实现严格拒绝它。

`ConfigDict(strict=True)` 可以为模型启用严格模式，也可在字段或单次验证调用上选择严格策略。严格并不等于“任何来源的行为完全相同”：JSON 本身没有日期、元组等 Python 类型，某些类型在 JSON 路径下仍有特定解析语义。因此，合同测试必须使用生产中真实的入口：HTTP 收 JSON，就测试 JSON；内部 Python 调用，就测试 Python 对象。

严格性是合同决策，而不是越严格越高级。配置文件可明确允许字符串转布尔值；公开 API 的工单 ID 则通常应拒绝浮点数和布尔值。把允许的转换写入测试和文档，避免依赖记忆中的默认规则。

## 6. 字段验证器：处理单字段规则

`@field_validator` 用于一个或多个字段的定制校验。常见模式是 `before` 与 `after`：`before` 看见原始输入，必须面对任意类型；`after` 在基础类型验证之后运行，拿到更可信的值。

```python
from pydantic import field_validator

class WorkOrderCreate(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")
    title: str

    @field_validator("title", mode="after")
    @classmethod
    def title_must_have_visible_text(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("title must contain visible text")
        return normalized
```

验证器返回的值会成为模型字段值；忘记 `return` 会把值变成 `None` 或引发后续错误。`before` 验证器若直接修改传入的可变对象，联合类型的其他验证分支可能看到被污染的数据。更稳妥的是生成新值，并保持验证器确定、快速、无外部副作用。

不要在验证器里查询数据库、调用 Java 服务或发送消息。模型可能在重试、文档生成、测试、队列消费和嵌套验证中多次构造，副作用次数不稳定。需要 I/O 的业务校验放入应用服务，并给它独立的超时、重试和错误模型。

## 7. 模型验证器：表达跨字段不变量

当规则需要同时观察多个字段时，使用 `@model_validator`。例如，紧急工单必须给出升级原因：

```python
from typing import Self
from pydantic import model_validator

class WorkOrderCreate(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")
    priority: int = Field(ge=1, le=5)
    escalation_reason: str | None = None

    @model_validator(mode="after")
    def urgent_order_requires_reason(self) -> Self:
        if self.priority == 5 and not self.escalation_reason:
            raise ValueError("priority 5 requires escalation_reason")
        return self
```

`after` 模式检查已经构造的模型并返回自身。`before` 模式面对原始输入，适合做模型级预处理，但必须处理输入可能不是字典的情况。`wrap` 模式能包围标准验证流程，能力更强也更难推理，只有在确实需要截获整个流程时使用。

跨字段验证仍不是跨聚合业务事务。比如“设备必须启用且未被其他未完成工单占用”依赖实时数据库状态，必须在 Java 事务边界处理；Python 模型只能检查 `device_id` 的形状和本请求内字段关系。

## 8. 嵌套模型、集合与联合类型

真实请求常包含嵌套对象。把地址、附件或预测结果定义为子模型，可以让错误位置精确到 `attachments.1.url`。列表元素会逐个验证，但模型验证不是数据库批量导入的性能免费午餐；大型负载需测量时间与内存，并设置请求体和集合长度上限。

联合类型表达“多种合法形状”时，优先使用稳定的判别字段，例如 `kind: Literal["text"]` 与 `kind: Literal["image"]`。没有判别字段的复杂联合可能依次尝试多个分支，产生冗长错误，也可能因宽松转换选择出乎意料的分支。协议一旦公开，判别值就是需要版本化的合同。

集合类型也包含语义选择：`list` 保留顺序与重复，`set` 去重但改变序列化和顺序。不要为了方便校验而静默改变调用方数据。若业务要求标签去重，应明确它是规范化规则，并验证输出顺序是否需要稳定。

## 9. 额外字段策略：默认忽略可能隐藏漂移

Pydantic 模型默认会忽略未知字段。对于读取不断增加字段的外部响应，这可能有兼容价值；对于本系统的创建/更新请求，它可能把拼写错误静默吞掉：调用方发送 `prioritty`，服务忽略它并使用默认优先级，表面成功而语义错误。

`ConfigDict(extra="forbid")` 会把未知字段变成验证错误，适合受控 API 输入、任务消息和安全敏感配置。`extra="allow"` 会保留未知字段；`extra="ignore"` 会丢弃。三种策略都不是全局答案，必须根据边界选择并测试。

FactoryCare 建议：自己控制的写入合同默认 `forbid`；读取第三方或渐进演进的响应可经过适配层选择 `ignore`，但要有未知字段指标或契约监控。不要在同一个模型里同时承担“宽容读取”和“严格写入”，否则最宽松的需求会削弱所有边界。

## 10. `ValidationError`：机器可定位，人可理解

验证失败时，`ValidationError.errors()` 返回结构化错误列表。每项通常包含 `type`、`loc`、`msg`、`input` 和可选上下文。`loc` 给出字段路径，`type` 是比自然语言消息更适合程序判断的错误代码。

不要把整个异常对象原样返回客户端或写入日志。`input` 可能包含密码、Token、个人信息或大段文本；`msg` 也可能随 Pydantic 版本或本地化策略变化。边界层应建立自己的稳定错误格式，例如：

```python
def public_errors(exc: ValidationError) -> list[dict[str, object]]:
    return [
        {
            "path": [str(part) for part in item["loc"]],
            "code": item["type"],
        }
        for item in exc.errors(include_input=False)
    ]
```

对外协议可再把 Pydantic 代码映射为 FactoryCare 自有代码，如 `INVALID_TYPE`、`MISSING_FIELD`、`UNKNOWN_FIELD`。测试快照应该比较稳定字段和排序规则，不宜锁死所有英文提示，否则小版本升级会制造噪声。

## 11. 失败阶段决定首个可信证据

诊断必须先分阶段：

1. JSON 解析失败：输入还不是合法 JSON，首证据是 JSON 解码位置；Pydantic 字段规则尚未运行。
2. 模型验证失败：出现 `ValidationError`，首证据是首个有意义的 `loc` 与 `type`。
3. 业务校验失败：模型已合法，但 Java 服务拒绝状态、权限或事务条件；首证据来自业务服务的稳定错误合同。
4. 序列化或响应合同失败：内部值存在，但输出 alias、类型或字段集合不符；首证据是响应模型/合同测试差异。
5. 持久化失败：验证通过不代表数据库提交成功，首证据应来自事务/约束，而不是修改 Pydantic 规则掩盖问题。

看到 HTTP 422 或测试失败时不要立刻“放宽模型”。先保留最小失败输入，打印安全化错误路径，确认模型版本、入口函数、严格模式和额外字段策略，然后修复根因并重跑同一个失败用例。

## 12. `model_validate`、构造器与 JSON 入口

`Model.model_validate(obj)` 明确表达“验证一个 Python 对象”；`Model.model_validate_json(raw)` 在 JSON 入口完成解析与验证；`Model(**data)` 也常见，但在通用边界代码里前两者更清楚。

`model_construct()` 绕过正常验证，直接构造模型。它只适合已经由同一合同验证过、性能确有证据且调用路径严格受控的内部数据。绝不能用它来“解决验证报错”，也不能把来自缓存、消息或数据库的数据想当然地视为可信。绕过之后，类型标注不会保护运行时，验证器和默认处理也可能不执行。

性能优化前要基准测试。Pydantic 2 对简单模型的正常验证已经很快，`model_construct()` 并不保证对所有模型更快。用可维护性和正确性换取未经测量的微小优化，是典型越界。

## 13. 序列化：`model_dump` 不是简单的 `__dict__`

`model_dump()` 按 Pydantic 规则把模型转换为字典。`mode="python"` 可以保留日期、UUID 等 Python 对象；`mode="json"` 产生可 JSON 序列化的值。`model_dump_json()` 直接产生 JSON 字符串。输出时还可选择 `include`、`exclude`、`exclude_none`、`exclude_unset` 和 `by_alias`。

这些选项会改变合同，不能在控制器里随手组合。例如创建响应若使用 `exclude_none=True`，客户端会分不清“字段存在且为空”和“字段不存在”；补丁命令若忘记 `exclude_unset=True`，默认值可能被误当成用户更新。

序列化也不是脱敏器。若模型含内部诊断、提示词、密钥或个人信息，应设计专用响应模型，只选择允许公开的字段。不要先构造一个包含所有内容的模型，再寄希望于每个调用点都记得 `exclude={...}`。

## 14. alias：输入名、Python 名和输出名

外部协议可能使用 `workOrderId`，Python 代码偏好 `work_order_id`。alias 建立两者映射，但要区分验证入口和序列化出口：`validation_alias` 影响接受什么名字，`serialization_alias` 影响按 alias 输出什么名字；通用 `alias` 可同时影响两侧。输出是否使用 alias 还取决于 `model_dump(by_alias=True)` 等调用。

```python
class WorkOrderView(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")

    work_order_id: int = Field(
        validation_alias="workOrderId",
        serialization_alias="workOrderId",
        gt=0,
    )
```

alias 漂移很隐蔽：模型能成功接收 `workOrderId`，但默认 `model_dump()` 输出 `work_order_id`；单元测试只检查属性值就发现不了。合同测试必须验证真实输出键集合，并对 `by_alias=True` 做明确选择。不要把 alias 生成器升级当作无风险重构，它可能一次改变所有外部字段名。

## 15. 输入模型、领域命令与响应模型应分离

“一个模型到处用”看起来省代码，却把不同信任边界耦合起来：创建请求没有 `id`，数据库实体有内部审计字段，响应需要公开计算结果，消息模型还需要版本号。复用一个超大模型会导致大量 Optional、意外输入字段和数据泄露。

更清晰的流程是：

```text
不可信 JSON
  -> Python 边界输入模型
  -> 显式映射为只读 AI/派生数据请求
  -> 调用 Java 权威 API
  -> Python 派生结果模型
  -> 专用响应模型
  -> JSON
```

映射代码不是浪费，它是可审查的信任转换点。字段增删时，编译器、类型检查器和测试能提醒维护者决定是否传播。Pydantic 模型可以负责 Python AI 服务的输入与派生输出，但工单状态、设备可用性、价格、权限和最终写入仍由 Java 后端裁决。

## 16. JSON Schema：合同投影，不是系统真相

`model_json_schema()` 可以生成 JSON Schema，用于文档、客户端生成和契约检查。字段类型、必填集合、约束、说明和嵌套定义会反映到 Schema 中。但不是每个 Python 验证器都能被完整表达，外部状态规则更不可能自动出现。

因此 Schema 是模型的一个投影，而不是“有了 Schema 就验证完毕”。若 `model_validator` 规定优先级 5 必须有升级原因，生成的 Schema 未必能完整表达这条条件。文档应补充语义，测试要直接执行验证器。

Schema 快照适合检测字段、required、alias 和主要约束漂移；不宜无选择地比较整份巨大 JSON，因为 `$defs` 顺序、标题或实现细节可能随版本变化。保存经过规范化的关键片段，升级时人工审查有意义差异。

## 17. 模型版本化：变化要按兼容性分类

合同变化至少分三类：

- 新增带默认值的响应字段通常对宽容客户端较兼容，但严格客户端仍可能失败。
- 新增必填请求字段、收紧范围、改变字段类型或重命名 alias 通常是破坏性变化。
- 放宽输入可能向后兼容，却可能改变安全和业务语义，也需要审查。

任务消息和长期存储数据应含显式 `schema_version` 或事件类型版本。消费者先选择对应版本模型，再执行迁移，不应让一个充满条件分支的模型猜输入年代。迁移必须是纯函数、可重放、有旧样本测试，并保留无法迁移时的隔离证据。

Pydantic 2 的小版本也可能调整错误文本、Schema 细节或弃用接口。本章按 2026-07-24 可验证的稳定版 Pydantic 2.13.4 编写；项目应在依赖文件中锁定可复现范围，升级时运行输入、错误映射、alias 输出与 Schema 回归。2.14.0a1 等预发布版本不能当作稳定基线。

## 18. 错误映射要稳定，也要保留排障关联

对客户端返回稳定的 `code`、`path` 和可操作说明；对内部日志记录请求关联 ID、模型版本、错误类型计数和安全化路径。两者目的不同：公开错误不能泄露原始输入，内部证据又必须足以定位。

错误数组的顺序可能受字段和验证流程影响。若协议声称顺序稳定，就显式按路径和代码排序；否则客户端不应依赖顺序。相同字段多条错误是否全部返回，也是合同决策。

不要捕获宽泛 `Exception` 后统一返回“参数错误”。数据库断连、程序错误和 Pydantic 验证失败应处于不同失败类别。只在明确边界捕获 `ValidationError`，映射后保留异常链或结构化内部日志；未知异常继续由通用错误机制处理。

## 19. 用 pytest 建立成功、边界和失败证据

一个合格验证套件至少覆盖：

1. 最小合法输入产生确定模型。
2. 每个数值/长度约束的上下边界。
3. 缺失必填字段。
4. 错误运行时类型，特别是严格模式与宽松模式差异。
5. 未知字段策略。
6. 每条跨字段冲突。
7. 输入 alias 与输出 alias。
8. `model_dump(mode="json", by_alias=True)` 的键和值。
9. 序列化后按预期模型重新验证的往返。
10. 安全化错误快照不含原始敏感输入。

`pytest.mark.parametrize` 适合把多个失败负载和期望错误代码放在同一测试矩阵中。使用 `pytest.raises(ValidationError) as caught` 捕获异常，再比较 `errors(include_input=False)` 的规范化结果。不要只写“抛异常就算通过”，否则错误可能来自错误字段或验证器自身的 bug。

## 20. 三类典型故障如何诊断

### 20.1 意外宽松转换

现象：发送 `{"priority": "5"}` 居然成功。先确认真实入口是 `model_validate` 还是 `model_validate_json`，再查看模型/字段严格配置。首个可信证据是测试中输入运行时类型与验证后字段类型的对比。修复为明确严格策略后，重跑同一个字符串用例以及合法整数用例。残余风险是其他字段仍可能允许转换，因此需要矩阵而不是只测一个字段。

### 20.2 额外字段被静默忽略

现象：`prioritty` 拼错仍返回成功。首证据是验证后的 `model_dump()` 中字段消失，而输入含未知键；根因通常是默认 `extra="ignore"`。写入合同改为 `extra="forbid"`，测试错误路径与类型。残余风险是嵌套子模型有自己的配置，父模型严格不代表每个子模型自动严格。

### 20.3 序列化 alias 漂移

现象：输入接受 `workOrderId`，响应却输出 `work_order_id`。首证据是真实序列化结果的键集合，而不是模型属性。确认字段 alias 配置和 `by_alias` 参数，修复后做 JSON 层合同测试。残余风险包括嵌套模型、alias 生成器和框架响应层再次序列化。

## 21. 不要用验证器承担业务服务职责

错误示例是验证 `device_id` 时同步请求 Java 后端确认设备存在。它会让模型构造依赖网络，无法在离线测试、文档生成或批处理稳定运行；网络重试还可能让一次验证执行多次。更糟的是，验证通过到真正写入之间状态可能变化，仍不能保证事务正确。

正确分层：Pydantic 先验证 `device_id` 为正整数；应用服务再带超时和追踪调用 Java；Java 在事务中验证设备、权限和工单状态并写入。Python 只保存可重建的 AI 标签、向量索引或解释性结果，权威事实从 Java API读取。即使 Pydantic 模型显示 `status="CLOSED"` 合法，也不代表 Python 获得了关闭工单的权限。

## 22. 日志、隐私和安全边界

验证错误往往携带原始 `input`。在开发机打印完整异常很方便，在生产环境却可能泄露手机号、位置、附件内容、访问令牌或提示词。日志策略应默认不记录原值，只记录模型版本、字段路径、错误代码、数据尺寸和关联 ID；确需采样时必须经过脱敏和访问控制。

模型输出也可能造成过度共享。使用专用公开响应模型，避免将内部字段先放入模型再排除。对 secret 类型也不能只依赖其字符串展示被掩码；序列化与自定义编码器仍需测试。

Pydantic 验证不能替代请求体大小限制、递归深度保护、上传扫描、认证授权和速率限制。一个结构合法的超大嵌套负载仍可能消耗大量 CPU/内存。边界安全是多层合同。

## 23. 性能与批量处理

先测量，再优化。记录模型复杂度、负载大小、验证次数和延迟分位数，区分 JSON 解码、Pydantic 验证、业务 I/O 与序列化耗时。不要因看到一次慢请求就绕过验证，网络或数据库往往才是瓶颈。

批量输入应限制条数，并决定“全部成功或全部失败”还是“逐项错误”。逐项模式需要稳定索引路径和最大错误数，防止万条坏数据产生巨大响应。若数据已在受信任内部边界验证过，可传递模型对象而不是反复从字典重建，但必须保持所有权和版本清晰。

对热点路径考虑 `TypeAdapter` 等官方能力前，先确认问题不是模型被重复无意义构造。任何优化都要保留合法、边界、失败、alias 和错误脱敏测试。

## 24. AI 协作时的使用协议

可以让 AI 生成初稿模型和测试矩阵，但必须给出：真实 JSON 样例、字段所有者、严格/宽松决定、额外字段策略、输入与输出 alias、跨字段规则、公开错误格式和版本边界。然后要求 AI 解释每个转换，而不是只返回可运行代码。

审查 AI 代码时重点找：一个模型跨输入/数据库/响应复用；默认忽略额外字段；把 `Optional` 误当可省略；验证器忘记返回；验证器内做 I/O；`model_construct()` 绕过；错误响应泄露 `input`；只测 happy path；默认 `model_dump()` 导致 alias 漂移。

AI 可以加速键入，不能决定业务真相。所有由 AI 推导的 FactoryCare 标签、摘要和评分必须标为派生、可重建、可追踪；Java 服务仍是工单状态、设备、用户、权限和事务的唯一权威来源。

## 25. 本章可执行路线

- `examples/encyclopedia/ch.python.pydantic-validation/verify.sh`：最小严格模型、字段/模型校验、alias、序列化与 Schema 烟雾验证。
- `labs/encyclopedia/ch.python.pydantic-validation/verify.sh`：成功、缺失、额外、错误类型、跨字段冲突、错误快照和往返的完整实验。
- `exercises/encyclopedia/ch.python.pydantic-validation/verify.sh`：故意保留宽松转换、额外字段忽略和 alias 漂移，稳定返回非零，训练定位首证据。
- `solutions-private/encyclopedia/ch.python.pydantic-validation/verify.sh`：教师参考修复，严格合同和回归全部通过。

公开练习失败是设计结果，不是仓库损坏。学习者应先保存原失败输出，指出失败阶段与首证据，修改自己的工作副本，再重跑原命令。私有答案只用于核对，不替代诊断表达。

## 26. 120 秒口述模板

“Python 类型标注不自动执行运行时校验；Pydantic `BaseModel` 在不可信边界把输入验证/解析为满足合同的对象，失败产生结构化 `ValidationError`。我会明确严格转换和额外字段策略，用字段验证器处理单字段纯规则、模型验证器处理本请求内跨字段规则，不在验证器做 I/O。输入、内部命令和响应使用不同模型；输出用显式 alias 和 `model_dump` 选项，错误只公开稳定路径与代码。JSON Schema 是合同投影，不覆盖所有业务语义。越界反例是让 Python Pydantic 验证器查询数据库并决定工单能否关闭；该事实应由 Java 事务服务裁决。证据包括合法/边界/失败矩阵、错误快照、alias 输出和 Schema 关键片段。”

## 27. 完成判据与自测

完成本章不等于读完。你应能独立回答并演示：

- 为什么 `priority: int` 不等于运行时一定是整数？
- `str | None` 与 `str | None = None` 的缺失语义有何区别？
- 什么情况下选严格模式，为什么必须按真实 JSON/Python 入口测试？
- `field_validator` 与 `model_validator` 各自负责什么，为什么不做 I/O？
- 默认额外字段策略有什么风险？
- 如何从 `ValidationError` 生成不泄密的稳定错误？
- `model_dump()`、JSON 模式和 `by_alias=True` 如何改变输出合同？
- 为什么 Schema、Pydantic 和 Python AI 服务都不能成为工单业务真相？
- 如何对一次宽松转换、未知字段或 alias 漂移指出失败阶段、首证据、修复和残余风险？

验收证据是：示例、实验和私有参考脚本退出码为 0；公开故障练习稳定非零；实验覆盖合法、缺失、额外、错误类型和跨字段冲突；序列化往返及 Schema 关键片段有断言；错误快照不含原始敏感输入。

## 28. 已验证与未验证边界

本章随附脚本在本机 CPython 3.14.3 上，以隔离依赖方式运行 Pydantic 2.13.4 与 pytest 9.1.1，验证模型、错误、序列化、alias、Schema 和故障注入。脚本首跑可能从 Python 包索引下载并缓存指定版本，因此网络和包索引可用性属于环境前提。

未验证：真实 FastAPI 请求生命周期、Java FactoryCare 服务、数据库事务、消息队列、生产日志平台、OpenAPI 客户端生成器以及大规模性能。这些必须在相应集成阶段补真实合同与观测证据，不能由本章单元实验推断。

## 29. 官方资料与版本边界

- Pydantic Models：<https://docs.pydantic.dev/latest/concepts/models/>
- Pydantic Validators：<https://docs.pydantic.dev/latest/concepts/validators/>
- Pydantic Strict Mode：<https://docs.pydantic.dev/latest/concepts/strict_mode/>
- Pydantic Serialization：<https://docs.pydantic.dev/latest/concepts/serialization/>
- Pydantic Configuration：<https://docs.pydantic.dev/latest/api/config/>
- Pydantic Validation Errors：<https://docs.pydantic.dev/latest/errors/errors/>
- pytest 官方文档：<https://docs.pytest.org/en/stable/>
- Python 3.14 typing：<https://docs.python.org/3.14/library/typing.html>

版本说明：截至 2026-07-24，本章把 Pydantic 2.13.4 与 pytest 9.1.1 作为可复现实验基线，Python 文档目标为 3.14 系列；预发布版不进入稳定基线。未来升级必须重跑错误结构、严格转换、extra、alias、Schema 和序列化回归，并阅读对应官方迁移说明。
