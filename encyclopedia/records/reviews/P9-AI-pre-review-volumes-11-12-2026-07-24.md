# P9 AI 辅助预审：卷 11 Dart/Flutter 与卷 12 Python/Data

- `actor_class=AI`
- `review_mode=read-only`
- `attestation_class=not-human-attestation`
- `dod_human_gate=OPEN`
- `review_date=2026-07-24`
- `scope=volume-11-dart-flutter,volume-12-python-data`

> 本记录是只读 AI 辅助预审的结果，不是独立真人复核或真人 attestation。除创建本记录这一项经授权的记录写入外，预审过程没有修改教材、示例、练习、实验、私有答案、manifest、attestation、release 或 `PROGRESS`。本记录不能关闭 Definition of Done 中的真人试读、独立人工复核、真实运行时、跨平台、无障碍、出版和来源支持性门槛，也不能把任何章节推进到 `review`、`verified` 或可公开发行状态。

## 1. 范围、方法与结论

范围为卷 11 与卷 12 共 38 章正文，以及各章公开 `examples`、`exercises`、`labs` 和 `solutions-private` 接口。评审依据为 `records/encyclopedia/REVIEW-RUBRIC.md`、章节 outcomes/prerequisites、2026.2 版本目录及 FactoryCare 事实所有权边界。

本次逐章实际阅读，检查零基础教学连续性、概念准确性、稳定核心与版本表面的区分、示例/练习/实验语义一致性、故障证据是否可证伪、安全/无障碍/取消边界、重复或模板注水、跨章矛盾、相对链接和来源入口。没有按“文件存在”宣称通过，也没有把 AI 输出称为独立真人复核。

总体结论：存在 1 个 S0 阻断、3 个 S1、13 个 S2、3 个 S3。按 `REVIEW-RUBRIC.md:59-63`，当前范围不能通过最终 P9 质量门。

## 2. 逐章结论索引

### 2.1 卷 11

| 章节 | AI 预审结果 |
|---|---|
| `ch.dart.toolchain` | clean |
| `ch.dart.types-null-safety` | clean |
| `ch.dart.control-functions` | clean |
| `ch.dart.collections-patterns` | finding F05 |
| `ch.dart.oop-generics` | finding F05 |
| `ch.dart.exceptions-resources` | finding F05 |
| `ch.dart.future-cancellation` | clean |
| `ch.dart.streams-isolates` | finding F08、F09 |
| `ch.dart.testing-lints` | clean |
| `ch.flutter.toolchain-project` | clean |
| `ch.flutter.widget-tree` | finding F06、F07 |
| `ch.flutter.layout-accessibility` | clean；仍有人类门 |
| `ch.flutter.state-lifecycle` | finding F09 |
| `ch.flutter.navigation-forms` | finding F05 |
| `ch.flutter.architecture-state` | finding F05 |
| `ch.flutter.network-storage-offline` | finding F05、F09 |
| `ch.flutter.device-apis` | finding F05；仍有人类门 |
| `ch.flutter.testing-performance` | finding F05；仍有人类门 |
| `ch.flutter.release-monitoring` | finding F05；仍有人类门 |

### 2.2 卷 12

| 章节 | AI 预审结果 |
|---|---|
| `ch.python.runtime-uv` | clean；真实 uv 冷重建仍是人类/运行门 |
| `ch.python.syntax-values-io` | finding F18 |
| `ch.python.control-flow` | clean |
| `ch.python.functions-scope` | clean；是 F10 的前置证据 |
| `ch.python.collections` | finding F10 |
| `ch.python.typing-foundations` | finding F11 |
| `ch.python.modules-packages` | finding F12 |
| `ch.python.files-json-time` | finding F01、F10、F13 |
| `ch.python.classes-dataclass` | finding F01、F14 |
| `ch.python.protocol-generics` | finding F02、F15、F19 |
| `ch.python.exceptions-context` | clean |
| `ch.python.iterators-decorators` | clean |
| `ch.python.testing-logging-debug` | finding F16 |
| `ch.python.asyncio-cancellation` | finding F05 |
| `ch.python.pydantic-validation` | finding F05 |
| `ch.fastapi.web-foundations` | clean |
| `ch.fastapi.security-testing-openapi` | finding F03 |
| `ch.data.numpy` | finding F20 |
| `ch.data.pandas` | finding F04、F17 |

## 3. 有证据的 findings

### F01 — S0：零基础路线在类章之前强制学习者实现类

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.files-json-time.md:8`
- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.files-json-time.md:13-18`
- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.files-json-time.md:156-160`
- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.files-json-time.md:591-603`
- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.classes-dataclass.md:8-18`
- `/Users/youren/Desktop/Study/Computer/records/encyclopedia/REVIEW-RUBRIC.md:59-63`

第 8 章的唯一硬前置是 modules，却直接使用 `class`、`__init__`、`self`，并要求独立实现 `DerivedSnapshotStore`；类的系统教学在第 9 章。该章又属于 `zero-base` 路线，符合 rubric 的必需概念前置阻断。

建议：把类章移到文件章之前并调整前置图；或把文件章的强制实现暂改为模块级函数，存储类留到类章之后。

### F02 — S1：Protocol 示例让 Python 修改 Java 拥有的核心工单事实

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.protocol-generics.md:337-347`
- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.python.protocol-generics/repository.py:35-41`
- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.protocol-generics.md:456-468`

正文和示例中的 `close_order()` 在 Python 创建 `status="CLOSED"` 并写入 Repository；同章随后规定 Java 才是工单事实所有者、Python 不得成为第二主库，合同自相矛盾。

建议：改成 Python 拥有的 `PrioritySuggestion`/草稿建议仓库；或把工单端口设为只读，由 Java 执行状态迁移、授权与持久化。

### F03 — S1：安全练习的公开验收器可让不完整实现通过

证据：

- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.fastapi.security-testing-openapi/README.md:11-17`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.fastapi.security-testing-openapi/scripts/check.py:19-30`
- `/Users/youren/Desktop/Study/Computer/solutions-private/encyclopedia/ch.fastapi.security-testing-openapi/scripts/check.py:19-45`

README 要求无效凭据 401、缺权限 403、合法主体成功、OpenAPI 安全声明和响应字段过滤；公开 checker 只检查匿名 401/header 与 OpenAPI。仅实现“始终拒绝匿名 + Schema 声明”即可绿，授权和响应过滤都未证明。

建议：公开 checker 增加 invalid/denied/allowed 三类 token、403、200、精确响应字段和 `internal_score` 排除断言。

### F04 — S1：pandas Lab 用教材明确禁止的任意去重修复维表

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.data.pandas.md:395-413`
- `/Users/youren/Desktop/Study/Computer/labs/encyclopedia/ch.data.pandas/oracle.py:21-34`

正文明确指出 `drop_duplicates(... keep="first")` 依赖排序、可能随机丢事实；Lab 却正是用该方式把重复 `PUMP/PUMP-OLD` 降为一条，并称为 fixed。

建议：重复键应保持失败；如确需择一，加入明确版本/生效时间和确定性 tie-breaker，并审计被丢记录。

### F05 — S2：11 个公开练习只有固定红验证器，没有可编辑 starter

这些目录均只有 `verify.sh`。错误源码或配置在临时目录/heredoc 中生成，脚本最后固定返回 41，学习者无法在“不删检查器”的前提下让原验证器变绿：

- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.dart.collections-patterns/verify.sh:9-45`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.dart.exceptions-resources/verify.sh:9-61`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.dart.oop-generics/verify.sh:9-53`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.flutter.architecture-state/verify.sh:4-40`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.flutter.device-apis/verify.sh:4-61`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.flutter.navigation-forms/verify.sh:9-56`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.flutter.network-storage-offline/verify.sh:10-72`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.flutter.release-monitoring/verify.sh:3-38`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.flutter.testing-performance/verify.sh:3-42`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.python.asyncio-cancellation/verify.sh:12-84`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.python.pydantic-validation/verify.sh:17-60`

正文又明确要求修复并重跑原检查，例如：

- `/Users/youren/Desktop/Study/Computer/book/volume-11-dart-flutter/chapters/ch.flutter.architecture-state.md:593-595`
- `/Users/youren/Desktop/Study/Computer/book/volume-11-dart-flutter/chapters/ch.flutter.device-apis.md:460-462`
- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.asyncio-cancellation.md:372-374`
- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.pydantic-validation.md:419`

建议：把错误实现移到可编辑源文件；checker 同时支持 starter 的稳定红和完成后的绿，禁止通过修改 expected 或删除断言绕过。

### F06 — S2：Widget 树可执行 oracle 把 MaterialApp 错标为 StatelessElement

证据：

- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.flutter.widget-tree/tree.yml:2-6`
- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.flutter.widget-tree/scripts/check_tree.rb:26-29`

当前官方继承关系是 `MaterialApp -> StatefulWidget`，因此实际应对应 `StatefulElement` 并拥有 State；checker 只验证错误 YAML 的内部自洽。官方依据：<https://api.flutter.dev/flutter/material/MaterialApp-class.html>。

建议：改成 `StatefulElement/state: true`，并让 checker 具备已知框架 Widget 类型 oracle，而不只是检查 YAML 自己声明的 Element。

### F07 — S2：“错误 Context”示例没有确定性展示所声称的失败

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-11-dart-flutter/chapters/ch.flutter.widget-tree.md:366-404`

示例说外层 context 看不到刚创建的 Scaffold，却调用 `ScaffoldMessenger.of(context)`；常见 `MaterialApp` 已在页面路由之上提供 ScaffoldMessenger，因此通常会成功。加 `Builder` 也没有证明访问“刚返回的 Scaffold”。

建议：改用确定性的 `Scaffold.of(context)`/自定义 InheritedWidget fixture，明确上层失败、下层成功；或删除“错误”标签，只作为祖先路径分析反例。

### F08 — S2：Streams/Isolates 练习宣称三类能力，实际只验证两小项

证据：

- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.dart.streams-isolates/README.md:1-3`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.dart.streams-isolates/starter.dart:1-13`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.dart.streams-isolates/oracle.dart:6-23`
- `/Users/youren/Desktop/Study/Computer/solutions-private/encyclopedia/ch.dart.streams-isolates/solution.dart:4-18`

README 要求广播流不回放、`Isolate.run` 聚合并保留错误、取消后释放生产者；starter/oracle 只有计数和同步 cleanup counter。`Isolate.run` 是 oracle 调用而非学习者实现，广播行为和 isolate 错误传播没有测试，私有解也未覆盖。

建议：增加可编辑广播源、晚订阅断言、抛错 isolate worker 和错误类型/stack 保留断言。

### F09 — S2：取消清理语义跨章不连续

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-11-dart-flutter/chapters/ch.dart.streams-isolates.md:230-241`
- `/Users/youren/Desktop/Study/Computer/book/volume-11-dart-flutter/chapters/ch.flutter.state-lifecycle.md:214-232`
- `/Users/youren/Desktop/Study/Computer/book/volume-11-dart-flutter/chapters/ch.flutter.state-lifecycle.md:387-405`
- `/Users/youren/Desktop/Study/Computer/book/volume-11-dart-flutter/chapters/ch.flutter.network-storage-offline.md:166-184`

Dart 章正确说明 `StreamSubscription.cancel()` 返回可失败的 `Future<void>`，依赖清理时必须等待；Flutter 生命周期示例在同步 `dispose()` 中直接丢弃 Future，未解释如何观察取消失败或处理依赖异步清理。网络接口又把取消降为 `void cancel()`。

建议：明确 `dispose()` 同步限制、结果提交立即失效、fire-and-forget 取消必须显式观察错误；需要等待完成的资源放到可 await 的所有者关闭 API。网络接口应区分 `requestCancel()` 与 `Future<void> close/cancel()`。

### F10 — S2：lambda 是隐藏前置，“后续函数主题”实际不存在

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.functions-scope.md:480-494`
- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.collections.md:534-546`
- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.files-json-time.md:501-507`

函数章明确不教 lambda；下一章集合直接使用并称“后续函数主题扩展”，但函数章已经过去，后面没有系统 lambda 教学；文件章又叠加 generator-expression 抛错技巧。

建议：在函数章补最小 lambda 教学和链接；零基础主路线更适合把排序 key 与 `parse_constant` 改为命名函数。

### F11 — S2：类型练习可用明确禁止的逃生口假绿

证据：

- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.python.typing-foundations/README.md:3-5`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.python.typing-foundations/scripts/check.py:13-36`

README 禁止 `Any`、ignore、扩大到 object；checker 唯一成功条件却只是 mypy 返回 0，因此这些方式都能绕过。

建议：AST/受控文本检查禁止 `Any`、目标行 ignore 和不合理 `object`，再加入精确运行时行为断言。

### F12 — S2：循环导入 Lab 没有真正验证无环模块修复

证据：

- `/Users/youren/Desktop/Study/Computer/labs/encyclopedia/ch.python.modules-packages/README.md:1-9`
- `/Users/youren/Desktop/Study/Computer/labs/encyclopedia/ch.python.modules-packages/oracle.py:10-30`

README 称“每个场景都在新 Python 进程执行”；故障案例确实如此，但“修复”只是在同一进程对字符串 `exec`，不存在多个模块或 import 图。

建议：建立真实 repaired 多模块 fixture，将共享常量移入下层模块，再由全新子进程导入并验证。

### F13 — S2：文件可靠性资产的声明强于故障证据

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.files-json-time.md:583`
- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.files-json-time.md:591-603`
- `/Users/youren/Desktop/Study/Computer/labs/encyclopedia/ch.python.files-json-time/oracle.py:54-59`
- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.python.files-json-time/README.md:1-3`
- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.python.files-json-time/verify.py:8-35`

Lab 只是手工创建/删除临时文件，没有调用实际 writer，也没有在写入和 replace 之间注入异常；示例 README 声称验证大小限制，但 verify 没有等于上限或超过上限输入。

建议：给 writer 加受控故障点，证明旧文件、临时文件清理和异常传播；增加 size limit 边界矩阵。

### F14 — S2：类章 outcome 声明 type-checker，但资产明确没运行

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.classes-dataclass.md:45-65`
- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.classes-dataclass.md:98`
- `/Users/youren/Desktop/Study/Computer/examples/encyclopedia/ch.python.classes-dataclass/README.md:1-9`

建议：加入锁定 mypy/pyright 正负 fixture；否则从当前 verification mode 移除 type-checker，登记为后续门。

### F15 — S2：Protocol outcome 的文件实现和静态替换验证均未兑现

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.protocol-generics.md:45-66`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.python.protocol-generics/scripts/check.py:14-18`
- `/Users/youren/Desktop/Study/Computer/labs/encyclopedia/ch.python.protocol-generics/lab.py:35-44`
- `/Users/youren/Desktop/Study/Computer/solutions-private/encyclopedia/ch.python.protocol-generics/README.md:1-3`

所谓 `JsonLikeRepository` 仍是内存 dict；公开练习在运行时调用缺失方法并用 ignore 压掉静态错误；私有答案也把类型检查留给将来。

建议：用临时目录实现真实 JSON repository，并让锁定类型检查器验证正确实现通过、缺成员实现产生预期诊断。

### F16 — S2：Python testing 练习修复后也不可能变绿

证据：

- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.python.testing-logging-debug/verify.sh:13-21`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.python.testing-logging-debug/verify.sh:30-40`

pytest 初始失败时内层返回 1；学习者修复后 pytest 返回 0，内层却无条件进入 `UNEXPECTED RESULT` 并返回 2，因此外层 `EXERCISE_GREEN` 分支不可达。

建议：pytest 为 0 时内层直接退出 0；仅对 starter 的精确 `DID NOT RAISE` 失败形状返回预期红。

### F17 — S2：pandas 公开练习只有负例，永远抛 MergeError 也会通过

证据：

- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.data.pandas/README.md:1-3`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.data.pandas/verify.py:5-15`
- `/Users/youren/Desktop/Study/Computer/solutions-private/encyclopedia/ch.data.pandas/verify.py:5-17`

建议：公开 checker 增加正常 left join、matched/unmatched、精确内容、行数不变和 `_merge` 断言，再保留重复键拒绝。

### F18 — S3：金额练习文字与实际故障不一致

证据：

- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.python.syntax-values-io/README.md:1-3`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.python.syntax-values-io/amount.py:3-5`

README 说“乘法产生重复字符串并让断言失败”，实际代码是 `int + str`，立即 `TypeError`，也没有断言。

建议：同步描述为加法类型错误，或改成真正的字符串乘法错误案例。

### F19 — S3：`runtime_checkable` 的副作用表述未跟上 Python 3.12+

证据：

- `/Users/youren/Desktop/Study/Computer/book/volume-12-python-data/chapters/ch.python.protocol-generics.md:383-394`

正文称运行时 Protocol 检查的属性访问可能有副作用；Python 3.12 起使用 `inspect.getattr_static()`，不会像普通 `getattr` 一样触发 property/`__getattr__`。它仍只检查成员存在、可能较慢，也不验证签名或语义。

建议：改成静态属性查找、与 `hasattr` 结果可能不同；真正调用成员时才可能触发副作用。

### F20 — S3：NumPy 公开 checker 未验证 starter 明示的 shape 合同

证据：

- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.data.numpy/starter.py:4-6`
- `/Users/youren/Desktop/Study/Computer/exercises/encyclopedia/ch.data.numpy/verify.py:5-8`
- `/Users/youren/Desktop/Study/Computer/solutions-private/encyclopedia/ch.data.numpy/verify.py:5-12`

公开 checker 只验证一个合法二维 axis 案例，未检查一维输入或空轴；这些只存在私有验证。

建议：把错误 ndim 与空轴负例放入公开 acceptance，不泄露具体实现。

## 4. 额外静态检查

- 只读解析了 38 章中的 73 个相对链接，未发现断链。
- endpoint README 本批没有相对链接可断。
- 来源以官方/一手文档为主，但“来源是否逐条支持正文”不能由链接存在性证明。
- 本预审没有重新运行会创建缓存、下载依赖或删除 `.dart_tool` 的验证脚本，因此没有输出任何运行通过声明。
- `clean` 只表示本轮 AI 阅读没有形成可证实 finding，不表示章节经过真人复核、真实运行或完成 DoD。

## 5. 仍需真人或真实环境完成的门

以下门保持打开，本记录不能关闭：

- 真正编程零基础读者按当前前置图完成运行、修改、独立实现和诊断；记录卡点、提示和用时。
- 独立真人逐章复核技术正确性、教学连续性、来源支持关系和跨章一致性。
- Flutter 3.44.x / Dart 3.12.x 的真实编译、Widget/Semantics 测试；当前不少 Dart 资产只在较低本机 SDK 表面可运行。
- Android/iOS/Web/macOS 真机、插件、权限、平台通道、相机/定位和后台恢复。
- 键盘、焦点、TextScaler、RTL、TalkBack、VoiceOver、对比度和减少动画。
- 网络取消、离线持久化、进程崩溃恢复、服务端幂等与真实 Java 边界。
- AAB/IPA 签名、商店提交、符号归档、监控关联和回滚演练。
- Python 3.14 + uv 冷缓存锁定重建、固定 mypy/pyright、Linux/Windows 文件系统与编码矩阵。
- NumPy/pandas 大数据、BLAS/PyArrow、硬件和内存行为。
- 外部 IdP/JWT/OIDC、TLS/代理、FastAPI lifespan、多 worker 和真实授权链。
- 来源逐条支持性、版权边界和出版编辑复核。
- HTML/EPUB/PDF 正式构建、导航、代码块、阅读顺序、阅读器和屏幕阅读器人工 QA。

## 6. 记录边界

本文件只保存 AI 预审发现，不能作为：

- 独立真人复核记录；
- 人类 attestation；
- 真实学习者试读证据；
- 运行验证 manifest；
- 版本升级或平台兼容证明；
- release approval；
- 章节状态晋升依据；
- `PROGRESS` 更新依据。

任何 findings 修复后，仍须由不依赖本 AI 结论的真人和真实环境重新验证受影响章节、相邻章节与公共端点。
