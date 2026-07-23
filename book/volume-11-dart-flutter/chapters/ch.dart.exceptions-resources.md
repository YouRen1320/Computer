---
schema_version: 2
edition: 2026.2-draft
id: ch.dart.exceptions-resources
title: 异常、资源所有权与错误建模
responsibility: 区分可预期业务失败与异常，定义抛出/转换/捕获边界并用 finally 释放资源，不吞错、不在本章引入 Future。
volume: '11'
order: 6
level: L2
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.dart.exceptions-resources.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.dart.oop-generics
version_surfaces:
- dart-stable
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“异常、资源所有权与错误建模”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - dart-error-contract
  - dart-resource-owner
  covers_topics:
  - dart.throw-catch
  - dart.custom-exception
  - dart.stack-trace
  - dart.error-translation
  - dart.try-finally
  - dart.resource-owner
  - dart.cleanup-order
  - dart.result-error-model
  uses_capabilities:
  - mobile.dart-language
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“异常、资源所有权与错误建模”构建可运行程序与测试：为工单解析和临时资源定义错误模型、转换边界与确定清理；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - dart-error-contract
  - dart-resource-owner
  covers_topics:
  - dart.throw-catch
  - dart.custom-exception
  - dart.stack-trace
  - dart.error-translation
  - dart.try-finally
  - dart.resource-owner
  - dart.cleanup-order
  - dart.result-error-model
  uses_capabilities:
  - mobile.dart-language
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: failure-matrix-stack-trace-check-cleanup-counter
- id: diagnose
  kind: fault-diagnosis
  text: 面对“catch 后静默、丢失 stack trace 或 finally 重复覆盖原异常”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - dart-error-contract
  - dart-resource-owner
  covers_topics:
  - dart.throw-catch
  - dart.custom-exception
  - dart.stack-trace
  - dart.error-translation
  - dart.try-finally
  - dart.resource-owner
  - dart.cleanup-order
  - dart.result-error-model
  uses_capabilities:
  - mobile.dart-language
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
generated_by: scripts/generate-curriculum.rb
generated_spec_digest: c92fc82a7a9de3c825b1cfad822361e0bec4f256621ab255385dc149d2384da1
---
# 异常、资源所有权与错误建模

> 失败不可避免，混乱可以避免。本章把失败分成可预期业务结果与异常路径，规定在哪里抛出、捕获、转换和记录，并把“谁打开资源，谁保证关闭”写成可测试合同。全部示例保持同步；Future、异步 close 与取消放到后续章节。

## 1. 先画失败地图，不要先写 catch

同一句“保存工单失败”可能对应完全不同的原因：工单状态不允许保存，是可预期业务拒绝；输入 JSON 缺字段，是边界格式失败；磁盘不可写，是基础设施异常；程序对 null 错误使用 `!`，是编程缺陷。若全部 catch 后返回 false，调用者无法决定重试、提示、修正输入还是报警。

设计失败合同先回答：调用者能否合理处理；失败是否属于正常业务分支；异常应在哪一层转换；哪些诊断信息可以安全记录；资源在任何路径下由谁释放。

本章采用如下经验规则：可预期且调用者必须分支处理的业务结果，优先显式 result 类型；解析、I/O 或不能在本层恢复的意外失败可以抛异常；编程错误不要被通用 catch 冒充业务失败。规则不是语言强制，而是让合同可读、可测。

## 2. throw、Exception 与 Error

Dart 的异常都是 unchecked：函数签名不要求声明 throws，调用者也不被编译器强制 catch。语言允许抛出任何非 null 对象，但生产代码通常抛实现 `Exception` 或 `Error` 的类型。

```dart
int parsePriority(String raw) {
  final value = int.tryParse(raw);
  if (value == null) {
    throw FormatException('priority is not an integer');
  }
  if (value < 1 || value > 5) {
    throw RangeError.range(value, 1, 5, 'priority');
  }
  return value;
}
```

Exception 一般表示程序可能想处理的运行失败；Error 常表示编程错误或违反 API 合同，例如 StateError、ArgumentError。这个区分是约定，不会自动决定是否捕获。最重要的是类型、消息、边界和测试一致。

`throw` 是表达式，因此可出现在箭头函数或 `??` 右侧，但不要为了短而牺牲可诊断性：

```dart
String requireId(String? id) =>
    id?.trim().isNotEmpty == true ? id!.trim() : throw ArgumentError('id');
```

复杂验证应展开成分支，让失败字段与安全上下文清楚。

## 3. 自定义异常要携带稳定、非敏感上下文

自定义异常适合让上层按类型捕获与转换：

```dart
final class TicketParseException implements Exception {
  final String field;
  final String reason;

  const TicketParseException(this.field, this.reason);

  @override
  String toString() => 'TicketParseException(field: $field, reason: $reason)';
}
```

不要把完整 token、身份证、工单描述或原始响应塞进异常字符串。异常可跨日志、崩溃上报和 UI 边界传播，消息应面向开发诊断且经过脱敏；用户提示另建稳定错误码与本地化文案。

自定义类型不应只是把所有异常换个名字。只有当调用者需要区别处理，或转换边界需要稳定领域语义时才有价值。保留底层异常和 stack trace 的方式也要设计，不能包装后丢掉根因。

## 4. on、catch 与匹配顺序

`on SomeType` 按类型选择，`catch (error)` 取得对象，`catch (error, stackTrace)` 同时取得堆栈。多个子句按从上到下的第一个匹配执行，因此具体类型应在宽类型之前。

```dart
void importTicket(String raw) {
  try {
    parsePriority(raw);
  } on FormatException catch (error, stackTrace) {
    print('format=${error.message}');
    print('origin=${stackTrace.toString().split('\n').first}');
  } on RangeError catch (error) {
    print('range=${error.message}');
  }
}
```

不指定类型的 `catch` 可以捕获任意抛出对象，风险是把本不该恢复的编程错误也吞掉。应用最外层可以做统一记录和崩溃边界，但业务函数应捕获自己能转换或恢复的具体失败。

catch 的三个正当目的：恢复并得到明确结果；添加本层上下文后继续传播；把基础设施异常转换成稳定边界错误。仅仅打印然后继续返回默认成功，不属于处理。

## 5. rethrow 与 stack trace

堆栈是从失败点到捕获点的调用路径，是定位首个可信代码位置的重要证据。在 catch 中只记录部分信息后仍让上层处理，应使用 `rethrow`：

```dart
void parseWithAudit(String raw) {
  try {
    parsePriority(raw);
  } catch (error, stackTrace) {
    print('parse failed: ${error.runtimeType}');
    print(stackTrace.toString().split('\n').first);
    rethrow;
  }
}
```

`rethrow` 只能位于 catch 语境，继续传播当前异常并保留原失败上下文。写 `throw error` 是一次新的 throw，堆栈表现可能改变，使日志更像从转换层开始。需要转换为新异常时，应在结构化日志或包装类型中保留原类型、原 stack trace 与安全 correlation id；不要把整个敏感原文拼接到消息。

测试 stack trace 不应断言完整字符串，因为文件路径、行号和编译模式会变。可验证它非空并包含被调用函数名或已知边界标记，同时把精确格式列为未验证。

## 6. finally：无论成功还是失败都执行

`finally` 用于确定性清理。无论 try 正常完成、catch 处理、return 或异常向外传播，finally 都会执行；若没有匹配的 catch，原异常在 finally 执行后继续传播。

```dart
abstract interface class SyncResource {
  String read();
  void close();
}

String readOnce(SyncResource resource) {
  try {
    return resource.read();
  } finally {
    resource.close();
  }
}
```

这里函数获得一个已经打开的 resource，并明确接管关闭责任。如果调用者仍拥有资源，就不应在此擅自关闭。所有权必须写在函数名、参数类型或文档中。

finally 不是“不会失败的区域”。close 也可能抛异常。若 try 已有原异常而 finally 又抛新异常，后者可能遮蔽原始失败。清理策略要决定哪一个向外传播、另一个如何安全记录；不能无意识让最后一个异常覆盖根因。

## 7. 资源所有权：谁获得，谁释放

资源包括文件句柄、socket、订阅、数据库连接、锁、临时目录、原生 handle。内存对象通常由 GC 管理，但 GC 不能及时替你完成协议层的 close、unlock 或 unsubscribe。

同步资源常见合同：创建函数若返回已打开资源，则调用者成为 owner；高阶函数若在内部打开并关闭，则 callback 只是借用；对象持有资源时必须提供明确 dispose/close 生命周期；多次 close 是否允许必须定义。

```dart
T usingResource<T>(SyncResource resource, T Function(SyncResource) body) {
  try {
    return body(resource);
  } finally {
    resource.close();
  }
}
```

这类似 Java try-with-resources 的意图，但 Dart 这里由普通函数和 finally 实现。callback 不应把 resource 保存到外部，在函数返回后继续使用；否则形成悬空借用。本章没有静态借用检查，只能靠 API 设计、测试与代码审查。

## 8. 清理一次与幂等 close

“资源只释放一次”是本章 oracle。把 close 同时写在 try 成功分支、catch 和 finally，会重复关闭：

```dart
// 错误示意
try {
  resource.read();
  resource.close();
} catch (_) {
  resource.close();
} finally {
  resource.close();
}
```

正确做法通常只在 finally 一个位置清理。资源自身可以把 close 设计为幂等，但调用者仍不该依赖多次关闭掩盖所有权混乱。测试替身用 `closeCount` 记录调用次数，并分别覆盖成功、读取失败与业务失败。

```dart
final class RecordingResource implements SyncResource {
  final String value;
  final bool failRead;
  int closeCount = 0;

  RecordingResource(this.value, {this.failRead = false});

  @override
  String read() {
    if (failRead) throw StateError('read failed');
    return value;
  }

  @override
  void close() => closeCount++;
}
```

幂等的意思是重复调用不会进一步改变可观察结果，不等于重复调用一定正确。若 close 第二次静默，测试仍应验证 owner 正常路径只调用一次。

## 9. 多资源获取与反向释放

资源通常按 A→B→C 获取，应按 C→B→A 释放，因为后获取资源可能依赖先获取资源。更棘手的是 B 获取失败：C 尚不存在，只能释放 A。

```dart
final first = openFirst();
try {
  final second = openSecond();
  try {
    useBoth(first, second);
  } finally {
    second.close();
  }
} finally {
  first.close();
}
```

嵌套看似啰嗦，却准确表达每次成功获取后的 owner。把两个 `open` 都放在同一 try 之前会导致第二个失败时第一个没有进入 finally。可以封装辅助器，但封装必须保留部分获取失败与反向清理语义。

清理顺序测试使用事件列表，如 `['open-a','open-b','close-b','close-a']`；不要只断言最终都 closed，因为顺序也可能属于协议合同。

## 10. 可预期业务失败用 result 建模

“工单已关闭，不能再次分配”不是系统意外，它是调用者应展示的业务结果。用 sealed 泛型结果表达：

```dart
sealed class Result<T extends Object, E extends Object> {
  const Result();
}

final class Ok<T extends Object, E extends Object> extends Result<T, E> {
  final T value;
  const Ok(this.value);
}

final class Err<T extends Object, E extends Object> extends Result<T, E> {
  final E error;
  const Err(this.error);
}

enum AssignmentFailure { alreadyClosed, noPermission, technicianUnavailable }
```

调用者用穷尽 switch 处理 Ok/Err；Result 的 E 只放调用者能采取行动的失败。OutOfMemory、程序 bug 或未知 I/O 不应全部转换为 `Err(unknown)` 后继续假装正常。

错误类型可包含稳定 code、可展示 message key 和安全 metadata。不要把 Exception 直接传到 UI，也不要只返回字符串，字符串难以穷尽、容易拼写漂移且混合开发信息与用户文案。

## 11. 异常与 result 的转换边界

边界层可把具体解析异常转换成领域失败，但只捕获自己理解的类型：

```dart
enum ParseFailure { invalidJsonShape, invalidPriority }

Result<int, ParseFailure> parsePriorityResult(String raw) {
  try {
    return Ok<int, ParseFailure>(parsePriority(raw));
  } on FormatException {
    return const Err<int, ParseFailure>(ParseFailure.invalidJsonShape);
  } on RangeError {
    return const Err<int, ParseFailure>(ParseFailure.invalidPriority);
  }
}
```

若在这里写 `catch (_) => Err(invalidJsonShape)`，内存错误、空指针式 bug、代码类型错误也会被错误归类。转换应有映射表和测试：底层 A→领域 X，底层 B→领域 Y，未知继续抛出。

反向转换也需谨慎。基础设施 adapter 可能把 HTTP 404 转为 `Missing`，但 401、500、超时含义不同。不要在底层把所有错误转为“未找到”，否则业务层会做出错误决策。

## 12. 解析工单的同步边界

为了不引入 JSON 包细节，本例接收已经解码的 Object?，再检查结构与值域：

```dart
final class ParsedTicket {
  final String id;
  final int priority;
  const ParsedTicket(this.id, this.priority);
}

ParsedTicket parseTicket(Object? input) {
  if (input case {
    'id': final String id,
    'priority': final int priority,
  }) {
    if (!RegExp(r'^WO-[0-9]+$').hasMatch(id)) {
      throw const TicketParseException('id', 'invalid format');
    }
    if (priority < 1 || priority > 5) {
      throw const TicketParseException('priority', 'outside 1..5');
    }
    return ParsedTicket(id, priority);
  }
  throw const TicketParseException('payload', 'required fields missing');
}
```

Map pattern 匹配结构，显式条件检查业务值域。错误不包含原始 payload。上层可以把 TicketParseException 转为导入失败记录，同时保留 correlation id；不能把非法工单放入系统后靠下游补救。

## 13. FactoryCare：解析、资源与结果组合

构建一个同步导入函数：资源读取失败向外传播；解析失败转为可预期结果；无论哪条路径都只关闭一次。

```dart
enum ImportFailure { invalidTicket }

Result<ParsedTicket, ImportFailure> importFrom(SyncResource resource) {
  try {
    final raw = resource.read();
    try {
      final input = <String, Object?>{
        'id': raw.split(',').first,
        'priority': int.parse(raw.split(',').last),
      };
      return Ok<ParsedTicket, ImportFailure>(parseTicket(input));
    } on FormatException {
      return const Err<ParsedTicket, ImportFailure>(ImportFailure.invalidTicket);
    } on TicketParseException {
      return const Err<ParsedTicket, ImportFailure>(ImportFailure.invalidTicket);
    }
  } finally {
    resource.close();
  }
}
```

这段代码的合同仍需讨论：`split` 得到多于两个字段怎么办；read 的 StateError 是否应传播；close 抛错如何处理；失败是否记录 stack trace。教材不把示例当万能模板，而是用失败矩阵逼迫设计选择。

## 14. 失败矩阵与测试 oracle

至少建立以下矩阵：有效文本→Ok、closeCount=1；非法数字→Err invalidTicket、closeCount=1；ID 非法→Err、closeCount=1；read 抛 StateError→同一异常向外传播、堆栈非空、closeCount=1；close 本身失败→按书面策略传播或聚合；read 与 close 同时失败→不能无说明覆盖根因。

“成功、边界和失败输入均保存”意味着每个场景有固定输入、命令、期望类型、期望资源计数和实际结果。只看程序最后 exit 0 不能证明失败分支执行过；测试应计数或输出各 case 名称。

stack trace oracle 只检查非空与包含核心函数标记。cleanup oracle 检查次数与顺序。类型 oracle 检查 Ok/Err 或具体 exception，不用消息全文充当类型。

## 15. finally 覆盖原异常的危险

如果 try 中抛 `ReadFailure`，finally 的 `close` 又抛 `CloseFailure`，调用者可能只看到 close 失败。更糟的是 finally 中 return，可能使原异常和原返回路径消失。原则是 finally 只做必要清理，避免 return、break 或无策略地抛出新异常。

同步场景可捕获 cleanup failure 并根据策略处理：若主操作成功，close failure 通常应向外报告；若已有主失败，可以记录 close failure 为次要证据，并 rethrow 主失败。Dart 没有自动 suppressed exceptions 机制等同 Java try-with-resources，需要项目定义聚合错误或日志策略。

不要写一个通用 helper 后宣称覆盖所有资源。不同资源对 close 失败、重试和幂等性的协议不同；文件、锁、事务和订阅的语义不能一刀切。

## 16. 不吞错，也不重复记录

吞错示例：

```dart
try {
  dangerousOperation();
} catch (error) {
  print(error);
}
// 继续返回“成功”
```

改进不只是加 `rethrow`，而是先决定这一层是否 owner：能恢复就返回明确降级结果；能转换就映射具体类型；只能添加上下文就记录一次并 rethrow；完全不能处理就不 catch。

同一异常在 repository、service、UI 连续记录会产生三条重复告警。通常最靠近边界的一层添加技术上下文，最外层统一落日志；中间层只转换合同。日志包含 error type、operation、correlation id 与安全状态，不包含 secret。

## 17. 常见误区与首个可信证据

误区一：`catch (_) {}` 静默。表现为测试没有异常却返回空或默认值；首个可信证据是失败矩阵预期异常/Err 与实际默认值的差异。修复后还要验证未知异常继续传播。

误区二：`throw error` 替代 rethrow。表现为堆栈起点变化；首个证据是 stack trace 检查与 lint，而不是用户截图。修复为 rethrow，再验证原函数标记存在。

误区三：在成功、catch、finally 都 close。首个证据是 cleanup counter 大于 1。修复为唯一 owner 和唯一 finally。

误区四：finally 抛错覆盖原异常。首个证据是双失败 fixture 最终类型不符合约定。修复需要明确主/次失败策略，并记录残余风险。

误区五：所有失败都 result。表现为编程 bug 被包装成业务 error，监控沉默。首个证据是注入未知 StateError 后竟返回 `Err(invalidInput)`。修复为窄捕获。

## 18. 与 Java、TypeScript 的对照

Dart 异常像 Java 的运行时异常，但没有 checked exception 声明；资源释放没有语法等价的 try-with-resources，本章用 try/finally 与 owner API 明确；Java suppressed exception 的行为也不能直接假设存在。

TypeScript/JavaScript 同样用 throw/catch/finally，但 Dart 可用具体类型的 `on`，有静态 Result 泛型和 sealed 穷尽分支。无论语言如何，核心都是失败分类、堆栈保存、边界转换与资源所有权。

不要把前端 `finally { loading=false }` 的经验机械套到资源关闭。UI 标记通常可重复赋值，而文件句柄、事务或锁有协议语义；close 失败也可能需要处理。

## 19. AI 协作边界

AI 可以生成异常类型、result 样板、失败矩阵和 recording fake，但人必须决定：哪些失败可预期；哪些未知异常继续传播；谁是资源 owner；多资源释放顺序；close 失败策略；日志脱敏；stack trace 是否保存；是否会重复记录。

审查 AI 代码时搜索：空 catch；宽 `catch (e)` 后返回成功；`throw e`；finally 中 return；同一资源多个 close；获取多个资源后才进入 try；异常消息拼完整 payload；把 Error 统一映射为业务失败；测试只覆盖 happy path；声称 GC 会自动关闭资源。

任何“已处理所有异常”的说法都可疑。正确声明应列出捕获类型、转换表、未知路径、清理计数和未验证平台。

## 20. 练习、复习与验收

基础练习：实现 TicketParseException；分别用 on、catch(error, stack) 和 rethrow；写 RecordingResource 并验证 read 成功/失败都 close 一次；用 sealed Result 表达一个业务拒绝。

综合练习：实现 `importFrom`，要求有效、非法数字、非法 ID、read 失败四种场景均有断言；资源恰好关闭一次；未知 StateError 不转为 invalidTicket；stack trace 保留核心函数标记。

故障练习：先写空 catch，观察失败矩阵假成功；修复为窄转换。再把 close 写入 catch 与 finally，观察 closeCount=2；修复唯一 owner。最后让 read 和 close 同时抛错，记录实际传播类型，再按项目策略修复并说明哪个次要失败只进入日志。

120 秒复述必须包含：unchecked 的含义；Exception/Error 约定；on/catch 顺序；rethrow 与 stack trace；finally 保证与遮蔽风险；owner 规则；反向释放；result 与 exception 的边界；一个不应该捕获或不应该转 result 的反例。

间隔复习：当天画失败矩阵；第二天手写 usingResource；第七天诊断双失败；第三十天在真实 repository/Flutter 生命周期中指出同步与异步 cleanup 的差别。

## 21. 本章验证范围与未验证项

example 验证异常分类、rethrow 堆栈和 close 计数；lab 验证解析结果、读取失败、双资源反向清理；公开 exercise 保留吞错/泄漏缺陷并预期失败；私有 solution 用同一 oracle 通过。资产使用内存同步 fake，不打开真实文件、socket、数据库、锁或 Flutter subscription。

本章没有验证异步 `IOSink.close()`、Future error、Zone、isolate error port、Flutter dispose、平台 channel 或取消竞争。官方 `dart:io` 中许多 close 返回 Future，必须在后续异步章节按协议 await；不能把本章同步 helper 复制过去后宣称安全。

本机可能用 Dart 3.9.2 运行兼容语法；语义依据 2026-07-24 的 Dart 3.12.2 stable 文档核对，未在所有 AOT/Web/移动平台验证堆栈格式。

## 22. 官方资料

- [Dart Error handling](https://dart.dev/language/error-handling)
- [Dart Exception API](https://api.dart.dev/dart-core/Exception-class.html)
- [Dart Error API](https://api.dart.dev/dart-core/Error-class.html)
- [Dart StackTrace API](https://api.dart.dev/dart-core/StackTrace-class.html)
- [dart:io File](https://api.dart.dev/dart-io/File-class.html)
- [IOSink.close](https://api.dart.dev/dart-io/IOSink/close.html)
- [Dart SDK Archive](https://dart.dev/get-dart/archive)

资料核对日期：2026-07-24。稳定核心与版本相关 API 已分开；实际升级、使用真实 I/O 或引入 Future 前需重新核对目标 SDK 文档。
