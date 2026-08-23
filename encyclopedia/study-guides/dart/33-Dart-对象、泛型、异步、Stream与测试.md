# Dart：对象、泛型、异步、Stream 与测试

## 1. Dart 中几乎所有值都是对象

类可以同时表达数据、构造规则和行为：

```dart
class WorkOrder {
  WorkOrder({required this.id, required this.title});

  final String id;
  final String title;
}
```

字段默认实例成员，方法通过对象调用。领域模型应让非法状态难创建，而不是只当 JSON 字段容器。

## 2. 构造器先建立对象不变量

```dart
class Quantity {
  Quantity(this.value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value');
    }
  }

  final int value;
}
```

初始化列表可在构造体前计算 final 字段：

```dart
WorkOrder(String rawId) : id = rawId.trim() {
  if (id.isEmpty) throw ArgumentError('id is required');
}
```

不要让对象先以空字段创建，再依赖调用者按顺序 setter 修好。

## 3. 命名构造器表达不同创建入口

```dart
class WorkOrderId {
  const WorkOrderId._(this.value);

  factory WorkOrderId.parse(String raw) {
    final value = raw.trim();
    if (!value.startsWith('WO-')) throw const FormatException();
    return WorkOrderId._(value);
  }

  final String value;
}
```

命名构造器比一个含多个 nullable 参数的万能构造器更清楚。Factory 构造器可返回缓存对象或子类型，但调用者仍应把它理解为创建合同。

## 4. const 构造器创建编译时常量对象

字段必须满足不可变要求：

```dart
class Priority {
  const Priority(this.value);
  final int value;
}
```

相同 const 表达式可能被 canonicalize 为同一实例，有利于 Flutter Widget。它不自动实现业务相等或深不可变，字段引用的对象也要满足常量规则。

## 5. Getter 和方法表达不同语义

```dart
bool get isClosed => status == WorkOrderStatus.closed;
void close(Instant now) { ... }
```

Getter 应像读取属性、快速且无显著副作用；可能昂贵、需要参数或有动作含义的用方法。

Setter 容易绕过不变量，领域变化优先命名方法如 `assign()`、`close()`。

## 6. 私有名称以 `_` 开头，范围是库

```dart
class WorkOrder {
  WorkOrder(this._status);
  WorkOrderStatus _status;
}
```

Dart 私有性以 library 为边界，不是 Java 的 class private。多个 part 文件可属于同一库并访问 `_` 成员。

不应依赖下划线保护安全秘密；它是代码封装。

## 7. 继承表达可替换关系

```dart
abstract interface class WorkOrderReader {
  Future<WorkOrder?> findById(String id);
}
```

具体实现：

```dart
class HttpWorkOrderReader implements WorkOrderReader { ... }
```

`extends` 继承实现和类型；`implements` 只承诺接口合同，需要自己实现成员。当前 Dart 的 class modifiers 能更精确限制扩展/实现边界，库设计时按官方文档查询。

## 8. 抽象类可提供部分共同实现

```dart
abstract class Repository<T> {
  Future<T?> findById(String id);

  Never unsupported(String operation) =>
      throw UnsupportedError(operation);
}
```

抽象成员要求子类实现，具体成员可复用。但跨基础设施复用通常组合优于深继承，避免父类知道所有子类需求。

## 9. Mixin 复用横切实现，但不能取代所有权

```dart
mixin SafeLogger {
  void logCode(String code) { ... }
}

class ApiClient with SafeLogger { ... }
```

Mixin 适合独立能力，可能用 `on` 约束可混入类型。若它依赖大量隐式字段、改变生命周期或含共享状态，组合服务更清楚。

## 10. Extension 为已有类型添加静态可见便利方法

```dart
extension WorkOrderStatusLabel on WorkOrderStatus {
  String get label => switch (this) {
    WorkOrderStatus.open => '待处理',
    WorkOrderStatus.closed => '已关闭',
    _ => '处理中',
  };
}
```

不改变原类，也不是运行时猴子补丁。适合格式化和局部便利，不应把依赖数据库/网络的业务行为藏进 extension。

## 11. 相等和 hashCode 必须一致

```dart
@override
bool operator ==(Object other) =>
    other is WorkOrderId && other.value == value;

@override
int get hashCode => value.hashCode;
```

若 `a == b`，两者 hashCode 必须相同。参与相等的字段应不可变，才能安全作为 Map key/Set member。

实体通常按稳定 ID 相等，值对象按所有组成值相等。可使用经过审查的代码生成库减少样板，但要理解语义。

## 12. Generics 保留集合和 API 的类型关系

```dart
class Result<T> {
  const Result.success(this.value) : error = null;
  const Result.failure(this.error) : value = null;

  final T? value;
  final Object? error;
}
```

真正更严谨可用 sealed 成功/失败子类型，避免两个 nullable 字段形成矛盾状态。

泛型用于表达输入输出关系，不要用 `Repository<dynamic>` 逃避边界类型。

## 13. 泛型约束规定最小能力

```dart
abstract interface class Entity {
  String get id;
}

Map<String, T> indexById<T extends Entity>(Iterable<T> items) =>
    {for (final item in items) item.id: item};
```

T 保留具体子类型，同时保证有 id。约束过宽失去帮助，过窄又阻碍合法复用。

Dart 泛型在运行时保留部分类型信息，但不能因此替代 JSON schema 验证。

## 14. 协变/逆变影响函数和泛型赋值

直观原则：能处理所有 Animal 的函数，可以在只会传 Dog 的位置使用；只会处理 Dog 的函数不能安全处理任意 Animal。

复杂 variance 规则需要时查文档。遇到类型错误先从“调用者会提供什么、实现能接受什么、结果承诺什么”推理，不用 dynamic 消音。

## 15. Sealed 类配合穷尽 switch 表达封闭状态

```dart
sealed class LoadState<T> {}

final class Idle<T> extends LoadState<T> {}
final class Loading<T> extends LoadState<T> {}
final class Success<T> extends LoadState<T> {
  Success(this.data);
  final T data;
}
final class Failure<T> extends LoadState<T> {
  Failure(this.error);
  final AppError error;
}
```

Switch 必须处理所有子类型，避免 loading/data/error 多 boolean 矛盾。具体 modifier 约束按当前 Dart 文档复核。

## 16. 异常用于正常返回合同之外的失败

```dart
try {
  final order = await repository.load(id);
} on TimeoutException catch (error, stack) {
  // 转成可重试失败
} on FormatException catch (error) {
  // 数据合同错误
} finally {
  // 必要清理
}
```

Dart 可 throw 任意对象，但项目应抛 Error/Exception 或明确业务失败类型，保留 stack trace 与 cause 上下文。

不要 `catch (_) {}` 静默吞掉；也不要把程序错误全部转换成“网络错误”。

## 17. Error 和 Exception 的惯例不同

一般惯例：

- Error：编程错误、违反内部约定，通常修代码；
- Exception：可预期运行失败，调用者可能处理。

这不是编译器强制层级。业务拒绝也可用 sealed Result 返回，避免把“无权限”“冲突”全部当异常控制流。

## 18. 资源所有权决定谁负责关闭

文件、StreamSubscription、Timer、HTTP client、数据库连接都有生命周期。

```text
谁创建资源
  → 谁明确转交或负责关闭
  → 正常/异常/取消路径都清理
```

使用 try/finally、subscription.cancel、client.close 等。仅依赖垃圾回收不能及时释放文件描述符和系统资源。

## 19. Future 表示未来的一次结果

```dart
Future<WorkOrder> load(String id) async {
  final response = await client.get(id);
  return parseWorkOrder(response);
}
```

Future 最终完成为值或错误。async 函数立即返回 Future，await 暂停当前异步函数，不阻塞整个 isolate 等 I/O。

未 await/return 的 Future 错误可能成为未处理异步错误，调用者也不知道操作何时完成。

## 20. Dart 事件循环处理 Event 和 Microtask

当前 isolate 单线程逐项执行。Future continuation、计时器、I/O 进入调度队列；microtask 通常在下一个 event 前清空。

```text
同步调用栈
  → microtask queue
  → event queue
```

大量 CPU 计算仍会阻塞 Flutter UI。async 只帮助等待，不自动并行。

## 21. 并行等待用 Future.wait

```dart
final results = await Future.wait([
  loadOrders(),
  loadUsers(),
]);
```

输入通常需同类型结果；不同类型可用 records/单独 Future 组合。一个失败时错误行为、其他操作是否仍运行和 cleanup 需理解。

有依赖就串行，无依赖可并行，但请求数量需要上限。

## 22. Timeout 只停止等待，不一定取消底层工作

```dart
await operation.timeout(const Duration(seconds: 5));
```

超时 Future 会以 TimeoutException 完成，但原始网络/计算是否停止取决于 API。写请求可能已到服务端。

Dart Future 本身没有通用强制取消。应设计取消协议：Abort/cancel token、关闭 client/subscription、操作 ID 忽略旧结果，并让服务端写入幂等。

## 23. 取消是协作，不是随时杀掉任意 Future

```text
调用者发 cancel signal
  → 操作在安全检查点观察
  → 停止后续工作/释放资源
  → 返回 cancelled 状态
```

若底层插件不支持取消，只能不再使用结果。UI 仍要用 request generation 防止旧完成覆盖新状态。

## 24. Stream 表示随时间到达多个值

```dart
Stream<int> countdown() async* {
  for (var i = 3; i >= 0; i--) {
    yield i;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}
```

消费：

```dart
await for (final value in countdown()) {
  print(value);
}
```

适合事件、进度、传感器、Socket 和数据库变化，不适合只返回一次结果的 API。

## 25. Single-subscription 和 broadcast Stream

- 单订阅：一条事件序列通常只能有一个监听者，可暂停并缓冲；
- broadcast：多个监听者观察实时事件，晚订阅者通常错过旧事件。

不要因多个页面需要就盲目转 broadcast；要定义是否回放最新值、无监听者时是否继续产生、每个 listener 错误如何处理。

## 26. StreamSubscription 是需要清理的资源

```dart
late final StreamSubscription<Event> subscription;

subscription = events.listen(handleEvent);
await subscription.cancel();
```

可 pause/resume/cancel，具体生产者是否真正停止取决于实现。Flutter State dispose 中要取消，否则旧页面继续更新和保留内存。

`await for` 离开循环时也要理解生成器/流的取消清理。

## 27. Stream 的错误是序列中的事件

Stream 可以发多个数据事件，也可以发错误，最后 done。`listen` 可提供 onError/onDone；转换操作符可能转发或产生错误。

业务上要决定：一个错误是否终止整个流、是否可恢复重连、是否保留最后数据。不要把所有传感器暂时错误当永久页面崩溃。

## 28. 背压是生产速度高于消费能力的问题

Dart Stream API 没有一个跨所有来源自动解决的背压保证。订阅 pause 可能让可暂停生产者停下，也可能只在内存缓冲。

策略：

- 限频/采样/去抖；
- 丢弃中间状态，只保留最新；
- 批处理；
- 有界队列；
- 上游协议反馈；
- 将 CPU 工作移 isolate。

要按事件语义选择，工单状态不能像鼠标坐标一样随意丢。

## 29. Isolate 有独立内存和事件循环

```text
main isolate（Flutter UI）
  ↔ message passing
worker isolate（CPU 密集计算）
```

没有共享可变内存，因此不能直接传任意对象引用或用普通锁共享状态。`Isolate.run` 适合一次计算，长生命周期 worker 使用 port 协议。

启动和传输有成本，小工作不要频繁创建 isolate。Flutter Web 的并发实现边界与原生不同，按当前文档复核。

## 30. I/O async 与 CPU isolate 不是一回事

网络/文件等待通常使用 Future，不需要另开 isolate；巨大 JSON 解析、图片处理和密集算法可能阻塞 UI，才考虑 isolate。

先在 profile 模式测量帧和 CPU，避免把所有 async 函数都移后台。插件和平台 channel 是否能从 worker isolate 调用也有约束。

## 31. Dart test 的最小结构

```dart
void main() {
  group('Quantity', () {
    test('rejects negative values', () {
      expect(() => Quantity(-1), throwsArgumentError);
    });
  });
}
```

测试名写条件与结果。同步抛错传函数给 matcher；Future/Stream 使用适合异步的 expect/later 并 await。

不要用 print 代替断言。

## 32. 异步测试要等待 Future 完成

```dart
test('returns order', () async {
  final order = await repository.load('WO-42');
  expect(order.id, 'WO-42');
});
```

忘记 await 可能测试提前结束。使用可控 completer 驱动成功、失败和乱序，不用真实 sleep 制造脆弱测试。

## 33. Mock 外部端口，不 Mock 领域规则

可替换：网络 client、Clock、存储、设备 API。测试提供内存实现或 mock，返回真实合同的不同路径。

不要 mock 待测对象自己的方法；不要让 mock 永远返回完美数据。接口过大导致 mock 配置复杂，往往说明边界需要缩小。

## 34. Lint、format、analyze 和 test 各有职责

```text
dart format：统一格式
dart analyze：静态类型和 lint
dart test：运行测试行为
```

`analysis_options.yaml` 选择规则。升级 lint 集可能产生迁移，应理解真实语义，不用 ignore 文件全局压制。

绿灯只证明这些命令执行范围，不证明 Flutter 真机和平台插件。

## 35. Package 质量还包括公共 API 和版本

- 最小导出面；
- 文档说明 null、异常和异步合同；
- semver 与 breaking change；
- SDK 约束合理；
- 依赖不过度；
- 示例可运行；
- changelog/license；
- 发布前 analyze/test/dry-run。

内部应用包也应保持模块所有权，不把所有源码从一个 barrel 导出。

## 36. 这篇的整体地图

```text
Class + 构造器建立对象不变量
  → 接口/组合分离外部实现
  → 泛型保持输入输出关系
  → sealed 状态让分支穷尽
  → Future 处理一次异步结果
  → Stream 处理多个时间事件
  → Isolate 通过消息执行 CPU 并行
  → 资源所有权确保取消和清理
  → analyze + test 验证静态与运行合同
```

必须掌握：私有 `_` 是 library 范围；相等与 hashCode 必须一致；Future 超时不等于底层取消；StreamSubscription 要取消；async I/O 不等于 CPU 并行；Isolate 不共享内存；异步测试必须 await。

Class modifiers 全矩阵、Zone、底层 port 协议和自定义 analyzer plugin 属于“需要时查询”。
