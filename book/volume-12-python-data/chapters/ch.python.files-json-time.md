---
schema_version: 2
edition: 2026.2-draft
id: ch.python.files-json-time
title: Path、编码、文件、JSON 与时间数据
responsibility: 用 pathlib 和显式编码读写文本/JSON，执行原子写入并规范化时区感知时间，不在本章定义异常转换策略。
volume: '12'
order: 8
level: L2
status: drafting
path: book/volume-12-python-data/chapters/ch.python.files-json-time.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.python.modules-packages
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
  text: 在 120 秒内解释“Path、编码、文件、JSON 与时间数据”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - python-files-json
  - python-time-data
  covers_topics:
  - python.pathlib-path
  - python.text-encoding
  - python.file-read-write
  - python.json-parse-serialize
  - python.atomic-file-write
  - python.datetime-aware
  - python.timezone-utc
  - python.iso8601
  - python.time-comparison
  - python.file-path-boundary
  uses_capabilities:
  - python.language
  - foundation.files-path-encoding
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现版本化工单 JSON 文件存储和 UTC 时间往返，并保存损坏输入负例；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - python-files-json
  - python-time-data
  covers_topics:
  - python.pathlib-path
  - python.text-encoding
  - python.file-read-write
  - python.json-parse-serialize
  - python.atomic-file-write
  - python.datetime-aware
  - python.timezone-utc
  - python.iso8601
  - python.time-comparison
  - python.file-path-boundary
  uses_capabilities:
  - python.language
  - foundation.files-path-encoding
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: temp-directory-roundtrip-fixture-timezone-case-table
- id: diagnose
  kind: fault-diagnosis
  text: 面对“依赖 cwd、默认编码、半写文件或 naive/aware 时间混用”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - python-files-json
  - python-time-data
  covers_topics:
  - python.pathlib-path
  - python.text-encoding
  - python.file-read-write
  - python.json-parse-serialize
  - python.atomic-file-write
  - python.datetime-aware
  - python.timezone-utc
  - python.iso8601
  - python.time-comparison
  - python.file-path-boundary
  uses_capabilities:
  - python.language
  - foundation.files-path-encoding
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Path、编码、文件、JSON 与时间数据

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《模块、包、导入与项目布局》](ch.python.modules-packages.md)：文件适配器和数据模块需放入稳定项目布局并从模块入口运行。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套资产使用 Python 3.14 标准库和系统临时目录验证 UTF-8、损坏字节、JSON 往返、原子替换与时区比较；没有验证网络文件系统、Windows 全部文件共享模式、数据库事务或多进程锁。`os.replace` 的绿灯只覆盖当前本地文件系统，不能外推为所有存储介质的崩溃一致性证明。

路径、文本、JSON 和时间看似都是“调用标准库就行”，实际上是业务系统最常见的数据边界。`"data/orders.json"` 的含义会随当前工作目录变化；屏幕上的“南京”是 Unicode 字符串，磁盘上却是按某种编码排列的字节；一次进程崩溃可能留下半个 JSON；不带时区的 `2026-07-24 09:00` 无法说明世界上的同一时刻。若这些边界没有显式合同，程序会在开发机上假绿，到容器、跨时区或异常关机时失败。

本章建立一条完整管线：可信根目录约束路径，显式 UTF-8 在字节与文本间转换，结构校验把 JSON 变成应用数据，临时文件加原子替换避免暴露半写结果，时区感知 `datetime` 统一为 UTC 再比较。异常转换与 Web 错误响应留给后续章节；这里先保留标准库给出的首个可信异常。

## 1. 完成定义、资产入口与边界

完成本章后，你应能：

1. 区分路径文本、`PurePath` 和会访问文件系统的 `Path`；
2. 解释相对路径相对于谁解析，并使数据位置不依赖调用者的当前目录；
3. 把用户提供的文件名视为不可信输入，防止 `..`、绝对路径和符号链接逃逸可信根；
4. 区分 `str` 与 `bytes`，在边界显式指定 UTF-8 与严格错误策略；
5. 使用上下文管理器可靠关闭文件，解释读、写、追加、独占创建的差异；
6. 明确 JSON 与 Python 类型映射、非标准数字、重复键、大小限制和版本字段；
7. 使用同目录临时文件、刷新与 `os.replace` 构造原子替换，并说明它没有解决哪些问题；
8. 区分 naive 与 aware 时间，规范化 UTC，安全解析 ISO 8601，并测试跨时区相等；
9. 用临时目录构造成功、缺失、损坏、半写保护和时区错误的证据矩阵。

配套入口：

- [版本化 JSON 与 UTC 往返示例](../../../examples/encyclopedia/ch.python.files-json-time/README.md)
- [路径、编码、半写与时间故障实验](../../../labs/encyclopedia/ch.python.files-json-time/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.python.files-json-time/README.md)

本章不建立通用异常层，不把 `JSONDecodeError` 统一改成 HTTP 状态码，也不讨论数据库事务。文件只适合教学、小工具、配置或受控单机数据；FactoryCare 核心业务事实仍由 Java 与数据库拥有，Python 文件只能保存可重建派生物或本地训练夹具。

## 2. 路径首先是一个含义，不只是字符串

字符串可以表示路径，却不懂平台分隔符、父目录和文件名。`pathlib` 提供对象化路径：纯路径只做词法运算，具体 `Path` 还能访问当前平台文件系统。

```python
from pathlib import Path, PurePosixPath

logical = PurePosixPath("exports") / "2026" / "orders.json"
actual = Path.home() / ".factorycare" / "derived" / "orders.json"
```

`/` 在这里调用路径拼接，不是磁盘根。`Path` 会根据运行平台产生 `PosixPath` 或 `WindowsPath` 语义。把路径对象传给现代标准库通常可直接使用；需要展示或进入 JSON 时才转成字符串。

### 2.1 相对路径依赖当前工作目录

```python
Path("data/orders.json")
```

这不是“相对于当前源码文件”，而是相对于进程当前工作目录。IDE、测试、CLI、容器和定时任务可能从不同目录启动。同一代码因此读到不同文件，甚至创建一份新的空数据。

更稳定的策略有三种：

1. 由入口接收配置后的绝对数据根，再注入存储对象；
2. 应用资源使用标准资源 API，而不是靠 `__file__` 猜安装布局；
3. 测试使用框架提供的临时目录，显式传入。

```python
class JsonStore:
    def __init__(self, root: Path) -> None:
        self._root = root.resolve(strict=True)
```

不要在领域函数深处调用 `Path.cwd()` 决定业务存储位置。当前目录属于启动上下文，不属于工单规则。

### 2.2 `resolve`、存在性与错误证据

`Path.resolve()` 消除 `..` 并解析符号链接；`strict=True` 要求路径存在，失败会给出文件系统异常。Python 3.14 中，一些 `Path.exists()`、`is_file()` 等查询对操作系统错误统一返回 `False`，若你需要区分“不存在”和“无权限”等具体原因，应调用 `stat()` 或真正打开并保留异常，而不能把所有 `False` 当不存在。

“先 exists 再 open”还存在检查与使用之间被替换的竞态。通常直接执行所需操作并处理失败更可靠：

```python
text = path.read_text(encoding="utf-8", errors="strict")
```

## 3. 文件路径是安全边界

如果接口接收 `filename`，以下输入都需要警惕：

```text
../../secrets.env
/etc/passwd
..%2F..%2Fprivate
reports/current  （可能是指向根外的符号链接）
```

只做字符串 `startswith` 不安全：`/safe/root-old` 也以 `/safe/root` 开头；不同分隔符和规范化形式还会绕过判断。一个最小路径约束函数：

```python
from pathlib import Path

def child_path(root: Path, user_name: str) -> Path:
    if not user_name or Path(user_name).is_absolute():
        raise ValueError("filename must be a non-empty relative path")
    trusted_root = root.resolve(strict=True)
    candidate = (trusted_root / user_name).resolve(strict=False)
    if not candidate.is_relative_to(trusted_root):
        raise ValueError("path escapes storage root")
    return candidate
```

这能阻挡常见词法逃逸，但不是对抗恶意本地进程的完整沙箱：检查后符号链接仍可能变化，权限、文件描述符相对操作和操作系统特性也影响安全。高风险写入应让操作系统权限限制进程可见范围，并使用更强的目录文件描述符方案或受控存储服务。

业务 ID 与文件名最好分离。若工单 ID 只允许固定字符，可以先做白名单校验，再由程序生成文件名，避免用户直接控制目录结构。

## 4. `str`、`bytes` 与编码

Python `str` 表示 Unicode 文本，`bytes` 表示 0 到 255 的字节序列。编码把文本变成字节，解码把字节变成文本：

```python
text = "南京·设备 A-17"
payload = text.encode("utf-8", errors="strict")
restored = payload.decode("utf-8", errors="strict")
assert restored == text
```

磁盘并不存“Python 字符串”。若写文件不显式编码，默认值受平台、区域设置和 Python 模式影响。今天本机默认 UTF-8 不代表合同明确；代码审查也无法知道设计意图。

```python
path.write_text(text, encoding="utf-8", errors="strict")
loaded = path.read_text(encoding="utf-8", errors="strict")
```

### 4.1 错误策略不能随便吞

`errors="strict"` 在无效字节处抛 `UnicodeDecodeError`，保留数据损坏证据。`ignore` 会静默丢字节，`replace` 会插入替代字符；它们可能适合面向人类的最佳努力预览，却不适合业务事实、签名输入或需要无损往返的数据。

若未知外部文件的编码，不能靠反复尝试直到“看起来能读”就宣布正确。编码探测是概率判断，需要来源元数据、协议约定或人工确认。FactoryCare 内部 JSON 统一 UTF-8，外部导入则在适配层记录来源编码与失败证据。

### 4.2 换行和 Unicode 等价

不同平台换行可能是 `\n` 或 `\r\n`；文本模式会做一定转换。哈希、签名或字节级比较应在明确规范化后对 bytes 操作。肉眼相同的 Unicode 也可能有不同码点组合；是否做 NFC 等规范化取决于业务合同，不能由文件 API 擅自决定。

## 5. 文件打开模式与资源生命周期

```python
from pathlib import Path

with Path("notes.txt").open("r", encoding="utf-8") as stream:
    content = stream.read()
```

`with` 在正常与异常路径都关闭文件。依赖垃圾回收最终关闭会耗尽文件描述符，也让刷新时机不可控。

常见模式：

- `r`：读取，文件不存在则失败；
- `w`：写入，存在则先截断，不存在则创建；
- `a`：追加，不等于结构化记录事务；
- `x`：独占创建，已存在则失败；
- `b`：二进制，读写 bytes；
- `+`：同时读写，游标与刷新规则更复杂。

对 JSON 配置，直接 `w` 最危险：文件在序列化完成前可能已被截断，进程崩溃会留下空或半文件。先在内存完成序列化，再写临时文件并替换目标更可靠。

### 5.1 `flush`、`fsync` 与关闭

`stream.flush()` 把 Python 用户态缓冲交给操作系统；`os.fsync(stream.fileno())` 请求操作系统把文件数据同步到底层存储。二者都不神奇：硬件缓存、文件系统和网络挂载仍可能有不同保证。需要崩溃一致性时应记录目标平台证据，必要时同步父目录元数据。教材示例展示稳健基线，不宣称达到数据库级事务。

## 6. JSON 是交换格式，不是 Python 对象快照

JSON 支持对象、数组、字符串、数字、布尔和 null。默认映射大致为：

| JSON | Python |
| --- | --- |
| object | `dict` |
| array | `list` |
| string | `str` |
| integer/number | `int`/`float` |
| true/false | `True`/`False` |
| null | `None` |

`datetime`、`Path`、任意类实例和 set 不能被默认序列化。不要使用 `default=str` 一把梭：它会把不同类型变成无法可靠恢复的字符串，错误对象也可能静默进入数据。应显式建立 wire model：

```python
def order_to_json(order: WorkOrderSnapshot) -> dict[str, object]:
    return {
        "id": order.id,
        "createdAt": order.created_at.astimezone(UTC).isoformat(),
        "tags": sorted(order.tags),
    }
```

读回时同样逐字段检查类型与约束。`json.loads` 只证明语法是 JSON，不证明它是合法工单。

### 6.1 `dump` 与 `dumps`

`dumps` 返回字符串，`dump` 写入文本流。JSON 编码器产生 `str`，不是 bytes。连续对同一文件多次调用 `dump` 不会自动加入记录边界，结果通常是无效 JSON：

```text
{"id": 1}{"id": 2}
```

若需要多条流式记录，应选择明确格式，例如 JSON Lines，并为每行大小、换行、失败恢复与版本制定合同；不能把普通 JSON 数组和 JSONL 混用。

### 6.2 中文、稳定输出与严格数字

```python
encoded = json.dumps(
    payload,
    ensure_ascii=False,
    allow_nan=False,
    sort_keys=True,
    separators=(",", ":"),
)
```

`ensure_ascii=False` 保留可读 Unicode，最终文件仍需按 UTF-8 编码。`allow_nan=False` 拒绝 JSON 标准不允许的 NaN 与 Infinity。`sort_keys` 可使测试 diff 稳定，但对象成员顺序不应成为业务语义。

Python 默认解码会接受某些扩展，包括非有限数字；也会对重复键保留最后一个值。若不可信输入需要严格拒绝，应使用 `parse_constant` 和 `object_pairs_hook` 检查。官方文档还提醒不可信 JSON 可能消耗大量 CPU 与内存，因此解析前应在协议层限制字节大小，深度等进一步限制可由专门解析器或入口策略实现。

### 6.3 数字精度

金额不要用二进制 float。FactoryCare 金额可用整数分，或在确需小数时用 `Decimal` 并制定字符串/数字 wire 合同。`json.loads(..., parse_float=Decimal)` 能保留十进制语义，但序列化时仍需显式转换，且上下游必须一致。

## 7. 版本化数据与验证

文件格式一旦保存就会成为接口。至少包含版本：

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-07-24T03:00:00+00:00",
  "orders": []
}
```

读取顺序应是：限制大小与解码、解析 JSON、检查根类型、检查版本、逐字段校验、再转换应用对象。未知未来版本应明确失败，不能假装按旧格式读。旧版本迁移要用纯函数和夹具验证，迁移前保留原始输入证据。

```python
def require_mapping(value: object) -> dict[str, object]:
    if not isinstance(value, dict):
        raise ValueError("document root must be an object")
    return value
```

注意 `bool` 是 `int` 的子类；校验整数时若布尔不合法，需要排除 `isinstance(value, bool)`。JSON Schema、Pydantic 等更系统的运行时验证在后续章节学习，本章先手写最小边界以理解责任。

## 8. 原子文件替换

目标是：读者要么看到完整旧版本，要么看到完整新版本，不看到写到一半的目标。标准步骤：

1. 在目标同一目录创建唯一临时文件；
2. 完整写入 UTF-8 文本；
3. flush 并在需要时 fsync 临时文件；
4. 用 `os.replace(temp, target)` 替换；
5. 异常时清理临时文件，保留旧目标；
6. 对高持久性需求评估同步父目录。

```python
from pathlib import Path
import os
import tempfile

def atomic_write_text(target: Path, text: str) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary_name: str | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            newline="\n",
            dir=target.parent,
            prefix=f".{target.name}.",
            suffix=".tmp",
            delete=False,
        ) as stream:
            temporary_name = stream.name
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_name, target)
        temporary_name = None
    finally:
        if temporary_name is not None:
            Path(temporary_name).unlink(missing_ok=True)
```

### 8.1 为什么必须同目录

跨文件系统移动可能退化为复制加删除，不再具备同样原子保证。同目录通常确保临时文件和目标处于同一挂载点。`Path.replace` 可表达替换，但同样必须理解底层平台语义。

### 8.2 原子替换没有解决什么

- 两个写者同时更新时的丢失更新；
- 读取—修改—写入跨进程事务；
- 多个文件必须一起提交；
- 文件权限、所有者和扩展属性继承；
- 磁盘满、配额、只读挂载；
- 网络文件系统与特殊文件系统保证；
- 恶意符号链接竞态；
- 备份、审计与并发锁。

因此核心工单数据应进入支持事务与并发控制的数据库。原子文件适合单文件派生快照，不等于“小型数据库已完成”。

## 9. 时间：表示时刻还是墙上时间

`datetime` 有 naive 和 aware 两类。naive 对象没有足够时区信息；aware 对象的 `tzinfo` 能确定相对 UTC 的偏移。

```python
from datetime import UTC, datetime

now = datetime.now(UTC)
assert now.tzinfo is not None
```

后端事件时刻、创建时间、更新时间通常应使用 aware UTC。营业时间“每天 09:00”、生日、纯日期则可能是本地民用概念，不能粗暴都转成 UTC 后丢掉原时区规则。

### 9.1 不要使用无时区的 `datetime.now()` 记录事件

```python
bad = datetime.now()       # naive，本地含义隐式
good = datetime.now(UTC)   # aware，时刻明确
```

`datetime.utcnow()` 返回 naive 值，现代代码更适合 `datetime.now(UTC)`。系统边界接到 naive 值时，不应擅自假设它是 UTC；应根据协议拒绝或由明确来源时区解释。

### 9.2 UTC 存储与本地展示

常见原则：事件时刻以 UTC 传输和存储，展示时根据用户/站点时区转换。本地时区使用 IANA 名称，例如 `Asia/Shanghai`，而不是只存固定 `+08:00`；有些地区有夏令时与历史规则，固定偏移不足以表达未来日程。

```python
from zoneinfo import ZoneInfo

shanghai = now.astimezone(ZoneInfo("Asia/Shanghai"))
```

时区数据库在不同系统的来源和版本可能不同；涉及法规变更的未来排程要记录版本与重算策略。

## 10. ISO 8601 往返

```python
from datetime import UTC, datetime

def format_instant(value: datetime) -> str:
    if value.tzinfo is None or value.utcoffset() is None:
        raise ValueError("timestamp must be timezone-aware")
    return value.astimezone(UTC).isoformat(timespec="microseconds")

def parse_instant(raw: str) -> datetime:
    parsed = datetime.fromisoformat(raw)
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ValueError("timestamp must include an offset")
    return parsed.astimezone(UTC)
```

Python 3.14 的 `fromisoformat` 支持其文档列出的 ISO 8601 形式，但不是任意日期字符串解析器。协议应固定自己接受的子集，例如必须包含偏移、是否接受 `Z`、小数秒精度。宽松解析后再输出规范格式是一种常见策略，但必须测试。

### 10.1 比较前先确认语义

两个 aware datetime 即使偏移不同，只要代表同一时刻，比较可以相等：

```python
left = datetime.fromisoformat("2026-07-24T10:00:00+08:00")
right = datetime.fromisoformat("2026-07-24T02:00:00+00:00")
assert left == right
```

naive 与 aware 做顺序比较会报错，这是好事：它暴露合同缺失。不要通过删除 `tzinfo` 消灭错误，那会丢失时刻含义。

### 10.2 DST、歧义时间与 `fold`

夏令时回拨时，同一墙上时间可能出现两次；跳转时某些本地时间不存在。`datetime` 的 `fold` 帮助区分重复区间，但构造业务排程仍需明确规则。事件日志优先记录 UTC 时刻和来源时区；仅存本地文本无法还原。

### 10.3 时间来源与可测试性

业务函数内部直接 `datetime.now(UTC)` 会让测试结果随时钟变化。把 `now` 作为参数或注入时钟函数：

```python
from collections.abc import Callable

def build_snapshot(now: Callable[[], datetime]) -> dict[str, str]:
    return {"generatedAt": format_instant(now())}
```

测试传固定 aware datetime；生产传真实时钟。这里的时间仍不是防篡改安全时钟，分布式顺序还需版本、序列或数据库并发机制。

## 11. 版本化工单快照示例

组合上述边界：

```python
from datetime import UTC, datetime
import json

def encode_snapshot(orders: list[dict[str, object]], generated_at: datetime) -> str:
    document = {
        "schemaVersion": 1,
        "generatedAt": format_instant(generated_at),
        "orders": orders,
    }
    return json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        indent=2,
    ) + "\n"
```

顺序很重要：先验证并序列化到内存，成功后再触碰目标文件；写入临时文件；替换；重新读取做独立往返测试。若数据可能非常大，不能无限在内存累积，需要数据库或流式格式与新的一致性设计。

读取端：

```python
def decode_snapshot(text: str) -> dict[str, object]:
    value = json.loads(text, parse_constant=lambda token: (_ for _ in ()).throw(
        ValueError(f"non-finite number: {token}")
    ))
    if not isinstance(value, dict):
        raise ValueError("snapshot root must be an object")
    if value.get("schemaVersion") != 1:
        raise ValueError("unsupported schemaVersion")
    generated_at = value.get("generatedAt")
    if not isinstance(generated_at, str):
        raise ValueError("generatedAt must be a string")
    parse_instant(generated_at)
    if not isinstance(value.get("orders"), list):
        raise ValueError("orders must be an array")
    return value
```

示例 lambda 只是展示严格常量边界，生产代码可使用命名函数提高可读性。下一章的 dataclass 可表达内存对象，但文件 wire model 仍需显式转换，不能直接 `asdict` 后认为版本合同完成。

## 12. 故障矩阵与首个可信证据

| 故障 | 阶段 | 常见首证据 | 正确方向 |
| --- | --- | --- | --- |
| 从不同目录读不到文件 | 路径解析 | `FileNotFoundError` 与实际绝对路径 | 注入可信根，不依赖 cwd |
| 文件含非法 UTF-8 | 解码 | `UnicodeDecodeError` 的字节位置 | 确认来源编码或拒绝，不静默忽略 |
| JSON 缺逗号 | 解析 | `JSONDecodeError` 行列 | 保留原始输入，修生产者或拒绝 |
| 根是数组但合同要对象 | 结构验证 | 自定义根类型断言 | 语法通过后仍做结构校验 |
| 写一半进程失败 | 持久化 | 目标变空/截断 | 同目录临时文件加替换 |
| naive 与 aware 比较 | 时间语义 | `TypeError` | 在边界要求偏移并规范化 UTC |
| 两写者互相覆盖 | 并发 | 内容完整但版本丢失 | 数据库/锁/版本条件，不靠原子替换 |

调试时先打印经脱敏后的目标绝对路径、字节长度、schemaVersion 和时区是否存在，不要把完整敏感数据写进日志。异常行列是证据，用户输入全文可能是隐私。

## 13. 测试策略

使用临时目录，测试不触碰真实用户文件：

1. 中文、emoji、换行的 UTF-8 往返；
2. 空订单数组与单条订单；
3. 缺失文件；
4. 非法 UTF-8 bytes；
5. 截断 JSON 与根类型错误；
6. 未知 schemaVersion；
7. NaN/Infinity 拒绝；
8. 写入函数中途失败时旧文件保持原样；
9. 同一时刻的 `+08:00` 与 `+00:00` 比较相等；
10. naive 时间被拒绝；
11. `../` 与绝对路径逃逸被拒绝；
12. 临时文件在成功和失败后都不残留。

只断言“文件存在”不够。要断言内容、编码、结构、时间语义、旧文件保护和清理结果。

## 14. FactoryCare 权限与数据所有权

Java 拥有工单状态、授权、审计与公共 API。Python 可以写：模型评估夹具、可重建索引快照、脱敏实验数据、本地缓存；不能把 `orders.json` 当核心数据库并绕过 Java 更新 `CLOSED`。

安全清单：

- 存储根由部署配置注入，并限制操作系统权限；
- 文件名由服务端 ID 生成，不直接接受任意路径；
- 单文件和 JSON 输入设置大小上限；
- 日志记录哈希、大小、版本和错误位置，不记录令牌与完整隐私内容；
- 敏感文件使用专门密钥系统，不提交仓库；
- 派生文件可删除重建，并注明来源时间与算法版本；
- 写入失败不破坏上一个可用版本；
- 多写者场景迁移到事务存储。

## 15. 常见误区与修正规则

**“Path 会自动找到源码旁文件。”** 不会。规则：数据根显式注入，包资源用资源 API。

**“本机默认 UTF-8，所以不用写 encoding。”** 环境事实不是代码合同。规则：边界显式 `encoding="utf-8"`。

**“errors=ignore 能兼容脏数据。”** 它会静默丢失。规则：业务数据严格失败，最佳努力预览单独标记。

**“JSON 能保存任意 Python 对象。”** 只支持有限数据模型。规则：显式 wire model 与反向验证。

**“json.loads 成功说明工单合法。”** 它只证明语法可解析。规则：继续验证根、版本和字段。

**“写临时文件就原子。”** 最终替换、同文件系统和清理都重要。规则：按完整协议实现并注入失败。

**“原子写等于并发安全。”** 它只防半文件。规则：丢失更新需要版本或事务。

**“去掉 tzinfo 就能比较。”** 这是丢失信息。规则：来源必须给时区，统一 UTC 比较。

**“所有时间都存 UTC 就结束。”** 日程还需要原始地区规则。规则：区分事件时刻与墙上时间。

## 16. 独立构建任务

实现 `DerivedSnapshotStore`：

1. 构造函数接收已存在的可信根目录；
2. 只接受符合 `^[A-Za-z0-9_-]+$` 的快照 ID；
3. 使用 UTF-8 和严格错误策略；
4. 文档包含 `schemaVersion=1`、aware UTC `generatedAt` 与 `orders`；
5. 序列化拒绝 NaN；
6. 同目录临时文件加 `os.replace`；
7. 解析时限制输入大小并检查根类型；
8. 拒绝 naive 时间和未知版本；
9. 在临时目录保存成功、空数组、非法 UTF-8、损坏 JSON、路径逃逸、模拟写失败六类证据；
10. 写明它为何不能作为 FactoryCare 核心工单数据库。

## 17. 自检问题

1. 相对路径相对于源码文件还是进程 cwd？
2. `Path.exists()` 返回 `False` 为什么不总能证明文件不存在？
3. `str` 和 `bytes` 各自表达什么，编码发生在哪个方向？
4. 为什么 `errors="ignore"` 不适合业务 JSON？
5. 连续调用两次 `json.dump` 为什么不是两条合法 JSON 记录？
6. 默认 JSON 对 NaN 和重复键的行为有什么互操作风险？
7. 原子替换为什么应使用同目录临时文件？
8. `flush`、`fsync`、`replace` 分别解决哪一层问题？
9. aware `+08:00` 与 aware UTC 如何判断同一时刻？
10. naive 时间为何不能由库函数随意假设成 UTC？
11. `is_relative_to` 检查仍不能抵御哪个本地竞态？
12. 为什么版本化文件仍需要字段验证？

## 18. 官方资料与版本说明

以下资料在 2026-07-24 按 Python 3.14 文档核对：

- [pathlib — Object-oriented filesystem paths](https://docs.python.org/3.14/library/pathlib.html)：纯路径、具体路径、查询、读写与替换；
- [Reading and Writing Files](https://docs.python.org/3.14/tutorial/inputoutput.html#reading-and-writing-files)：文本模式、编码与上下文管理器；
- [json — JSON encoder and decoder](https://docs.python.org/3.14/library/json.html)：类型映射、严格参数、异常与互操作限制；
- [datetime — Basic date and time types](https://docs.python.org/3.14/library/datetime.html)：aware/naive、UTC、比较与 ISO 格式；
- [zoneinfo — IANA time zone support](https://docs.python.org/3.14/library/zoneinfo.html)：地区时区与 DST；
- [tempfile](https://docs.python.org/3.14/library/tempfile.html) 与 [os.replace](https://docs.python.org/3.14/library/os.html#os.replace)：临时文件和替换语义。

Python 3.14 对部分 `Path` 查询错误处理以及新增移动/复制 API 有版本变化；本章原子写只使用已有稳定接口，并明确当前平台证据。升级 Python patch 或更换文件系统后，应重跑损坏字节、半写保护、替换和时区表，而不是只看单元测试数量。

## 19. 本章小结

路径决定“访问哪里”，编码决定“字节怎样成为文本”，JSON 决定“文本怎样成为交换结构”，原子替换决定“读者是否看见半成品”，时区决定“时间是否代表同一时刻”。每一步都是边界，都需要显式输入、失败证据和可复现测试。

最可复用的规则是：**路径基于可信根，文本显式 UTF-8，JSON 解析后继续验证，写入先完成再替换，事件时间必须 aware 并统一 UTC；原子文件不是事务数据库。**
