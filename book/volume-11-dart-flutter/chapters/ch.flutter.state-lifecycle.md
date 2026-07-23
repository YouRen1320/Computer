---
schema_version: 2
edition: 2026.2-draft
id: ch.flutter.state-lifecycle
title: 状态、生命周期、mounted、Key 与异步更新
responsibility: 管理 State 生命周期、本地状态、mounted、Key 和异步回调所有权，保证销毁后不更新 UI，并明确 mounted 不能取消请求。
volume: '11'
order: 13
level: L2+
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.flutter.state-lifecycle.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.flutter.layout-accessibility
- ch.dart.future-cancellation
version_surfaces:
- flutter-stable
- dart-stable
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“状态、生命周期、mounted、Key 与异步更新”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - flutter-state-lifecycle
  - flutter-key-identity-layout
  covers_topics:
  - flutter.state-init-dispose
  - flutter.set-state-contract
  - flutter.mounted
  - flutter.did-update-dependencies
  - flutter.async-ui-owner
  - flutter.key-identity
  - flutter.local-global-key
  - flutter.list-state-reuse
  - flutter.box-constraints
  - dart.cancellation-token
  uses_capabilities:
  - mobile.dart-future-cancellation
  - mobile.flutter-tooling-widget
  - web.accessibility
  - mobile.flutter-layout-lifecycle
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现可异步加载且可重排的工单列表，记录生命周期、Key 身份和取消证据；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - flutter-state-lifecycle
  - flutter-key-identity-layout
  covers_topics:
  - flutter.state-init-dispose
  - flutter.set-state-contract
  - flutter.mounted
  - flutter.did-update-dependencies
  - flutter.async-ui-owner
  - flutter.key-identity
  - flutter.local-global-key
  - flutter.list-state-reuse
  - flutter.box-constraints
  - dart.cancellation-token
  uses_capabilities:
  - mobile.dart-future-cancellation
  - mobile.flutter-tooling-widget
  - web.accessibility
  - mobile.flutter-layout-lifecycle
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: lifecycle-trace-controlled-future-key-reorder-test
- id: diagnose
  kind: fault-diagnosis
  text: 面对“销毁后 setState、只检查 mounted 未取消工作或错误 Key 导致状态串项”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - flutter-state-lifecycle
  - flutter-key-identity-layout
  covers_topics:
  - flutter.state-init-dispose
  - flutter.set-state-contract
  - flutter.mounted
  - flutter.did-update-dependencies
  - flutter.async-ui-owner
  - flutter.key-identity
  - flutter.local-global-key
  - flutter.list-state-reuse
  - flutter.box-constraints
  - dart.cancellation-token
  uses_capabilities:
  - mobile.dart-future-cancellation
  - mobile.flutter-tooling-widget
  - web.accessibility
  - mobile.flutter-layout-lifecycle
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 状态、生命周期、mounted、Key 与异步更新

> 本章解决三个经常混在一起的问题：State 何时存在、什么变化应该触发重建、异步工作在页面离开后由谁负责。最重要的结论先写在前面：`mounted` 只是“这个 State 当前是否还挂在树中”的布尔信号；它能阻止销毁后更新 UI，但不能阻止重复请求，也不能取消正在进行的网络、计时器、订阅或计算。

## 1. 状态到底是什么

状态是随时间变化、并会影响可观察行为的数据。按所有权先分：

- 短生命周期 UI 状态：展开/收起、当前输入、选中 tab，通常属于页面或小组件；
- 页面工作状态：加载、成功、空、错误、提交中，通常由页面状态持有者管理；
- 跨页面客户端状态：登录会话、主题、离线队列，需要更高层所有者；
- 服务端事实：工单状态、设备档案、权限，Java API 是权威，Flutter 只持有缓存/快照。

不要因为 `setState` 容易，就把所有东西塞进一个页面。也不要因为状态管理库强大，就把单个展开按钮变成全局状态。选择离使用者最近、又能覆盖所有需要共享者的最小所有者。

### 1.1 派生值不是独立事实

```dart
final activeCount = orders.where((order) => order.isActive).length;
```

若 `activeCount` 能从 `orders` 可靠计算，就不要再维护一个可独立修改的字段，否则会出现列表 3 项但计数 2 的非法组合。只有计算昂贵且有明确缓存失效策略时才缓存派生值。

## 2. StatefulWidget 与 State 的生命周期

一个简化序列：

```text
createState
  -> State 关联 BuildContext，mounted = true
  -> initState（一次）
  -> didChangeDependencies（首次 initState 后，依赖变化时也可能再次调用）
  -> build（可多次）
  -> didUpdateWidget（相同位置/type/key 接收新配置）
  -> build
  -> deactivate（暂时离开树，某些情况可重新插入）
  -> dispose（最终释放，mounted = false，不能再 setState）
```

这是学习模型，实际 framework 还有 reassemble 等调试钩子。不要把生命周期当“每个方法只执行固定一次”的背诵题；要理解触发条件和资源所有权。

### 2.1 createState

`StatefulWidget.createState` 为树中的一个实例创建 State。不要返回共享全局 State。框架会把它与 Element 绑定。

```dart
class WorkOrderPage extends StatefulWidget {
  const WorkOrderPage({super.key, required this.orderId});

  final int orderId;

  @override
  State<WorkOrderPage> createState() => _WorkOrderPageState();
}
```

### 2.2 initState

State 首次插入树后调用一次。适合初始化由该 State 拥有且不依赖 Inherited 查找的资源、订阅对象、触发初次加载。

```dart
@override
void initState() {
  super.initState();
  controller = TextEditingController();
  load(widget.orderId);
}
```

按约定 `super.initState()` 先调用。不能在这里假定所有依赖式 `context` 查找都适合；依赖 InheritedWidget 的初始化通常在 `didChangeDependencies`。

### 2.3 didChangeDependencies

首次 initState 后调用，并在当前 State 依赖的 Inherited 值变化时再次调用，例如 Locale、Theme 或自定义 scope。它可能多次执行，所以其中的副作用要去重。

```dart
Locale? loadedLocale;

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final locale = Localizations.localeOf(context);
  if (locale != loadedLocale) {
    loadedLocale = locale;
    // 只在真正变化时更新依赖 locale 的资源。
  }
}
```

不要每次无条件发请求。

### 2.4 didUpdateWidget

父节点在相同 Element 身份位置传入同类型、同 key 的新 Widget 配置时，State 被保留，`widget` 指向新配置，然后调用 `didUpdateWidget(oldWidget)`。

```dart
@override
void didUpdateWidget(covariant WorkOrderPage oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.orderId != widget.orderId) {
    load(widget.orderId);
  }
}
```

如果订阅对象由参数决定，要先取消旧订阅再监听新对象。只在 initState 订阅会导致页面复用后仍接收旧工单事件。

### 2.5 deactivate 与 dispose

`deactivate` 表示 Element 从树移除，GlobalKey 移动等情况下可能重新插入。不要在这里做不可逆最终销毁。`dispose` 表示 State 生命周期结束：取消订阅/计时器/可取消任务、释放 controller/focus/animation 等由本 State 创建并拥有的资源，然后调用 `super.dispose()`。

```dart
@override
void dispose() {
  requestOperation?.cancel();
  subscription?.cancel();
  timer?.cancel();
  controller.dispose();
  focusNode.dispose();
  super.dispose();
}
```

“谁创建谁释放”是默认所有权线索。若 controller 从父传入，本 State 通常不应 dispose；合同必须明确。

## 3. setState 的真实合同

`setState` 接收一个同步回调，在其中完成状态变更，然后 framework 标记对应 Element 需要重建。

```dart
setState(() {
  expanded = !expanded;
});
```

它不是“立即重新绘制整个 App”，也不是“让异步数据展示的唯一方式”。其他状态机制同样通过可监听/依赖更新触发树重建。

### 3.1 回调必须同步

不要写：

```dart
setState(() async {
  items = await repository.load();
});
```

framework 需要同步知道状态修改完成。正确模式是先 await，再在仍允许更新时同步 setState：

```dart
final result = await repository.load();
if (!mounted) return;
setState(() {
  items = result;
});
```

但这仍只解决“销毁后不更新”，没有取消请求，也没有解决旧响应覆盖新响应。

### 3.2 只包真正状态修改

不要把网络、解析和耗时计算放进 setState 回调。先完成工作，再同步赋值。这样重建原因清楚，异常边界也明确。

### 3.3 setState 后字段何时可见

回调里的字段立即在 Dart 对象上变化，但界面重建安排在 framework 后续帧。测试中需要 `pump` 推进。不能在调用后马上截图并假设新帧已提交。

### 3.4 无变化也 setState

无意义 setState 会触发额外重建；更严重的是它往往说明状态边界不清。比较新旧值，事件只在真正变化时更新。但不要过早为每次 build 紧张，先用性能证据定位。

## 4. mounted 是什么，不是什么

`State.mounted` 在 State 与 Element 关联后为 true，dispose 后为 false。`BuildContext` 也有 mounted 语义用于跨异步间隔检查。

正确结论：

- `mounted == true`：当前仍挂在树中，可以在合适时机 setState；
- `mounted == false`：不能 setState；
- mounted 不代表页面当前肉眼可见，可能被另一条 route 覆盖；
- mounted 不阻止方法被重复调用；
- mounted 不取消网络/数据库/计时器/stream/isolate；
- mounted 不解决多个并发请求的先后覆盖。

### 4.1 为什么只检查 mounted 仍浪费工作

```dart
Future<void> load() async {
  final result = await repository.loadOrders();
  if (!mounted) return;
  setState(() => items = result);
}
```

页面销毁后，`loadOrders` 仍可能占用网络、连接、服务端资源和电量，只是结果被丢弃。若底层支持取消，应在 dispose 传播取消；若协议不支持，至少忽略结果并记录限制。

### 4.2 mounted 也不解决旧响应覆盖

用户先查 A，随后快速查 B。B 先返回并展示，A 后返回时页面仍 mounted，于是 A 覆盖 B。两次回调都合法，但结果过时。

需要请求身份或 latest-wins 协议：

```dart
int generation = 0;

Future<void> load(String status) async {
  final myGeneration = ++generation;
  final result = await repository.load(status: status);
  if (!mounted || myGeneration != generation) return;
  setState(() => items = result);
}
```

更好的是结合底层取消：新请求先 cancel 旧 operation；generation 仍作为不支持强取消或竞态窗口的保护。语义要明确是 latest-wins、first-wins、queue 还是 merge。

## 5. 一套完整异步 UI 状态

用一个不可变联合语义比四个任意布尔组合更安全。即使本章先用字段，也要定义状态机：

```text
idle -> loading -> success(data)
                -> empty
                -> failure(error)
任意新查询 -> loading（是否保留旧数据需明确）
dispose -> cancelled/ignore，禁止 UI 更新
```

简化代码：

```dart
Future<void> load() async {
  final operation = repository.loadOrders();
  currentOperation?.cancel();
  currentOperation = operation;

  setState(() {
    loading = true;
    error = null;
  });

  try {
    final result = await operation.value;
    if (!mounted || currentOperation != operation) return;
    setState(() {
      items = result;
    });
  } on CancelledException {
    // 预期控制流，不展示为业务错误。
  } catch (error, stackTrace) {
    if (!mounted || currentOperation != operation) return;
    setState(() {
      this.error = mapSafeError(error);
    });
    logFailure(error, stackTrace);
  } finally {
    if (mounted && currentOperation == operation) {
      setState(() {
        loading = false;
      });
    }
  }
}
```

代码中的 `CancelableOperation`/取消类型取决于选用库或自建协议，普通 Dart `Future` 本身没有通用强制取消。关键是身份比较用对象引用：`currentOperation == operation` 只有当前操作未被替换时才成立；这与比较两个布尔值无关。

### 5.1 finally 为什么也要检查身份

A 请求启动，随后 B 替换它。A 后完成并进入 finally；如果无条件 `loading=false`，会在 B 仍进行时隐藏 loading。只有当前 operation 才有权结束当前 loading。

### 5.2 错误与取消分开

用户离开页面或发起新筛选导致的取消是预期控制流，通常不应弹“网络失败”。超时、HTTP 错误、解析错误才进入对应可见状态。日志也应区分，以免监控被预期取消淹没。

## 6. 订阅、Timer、Controller 与资源所有权

异步不仅是 Future。

### 6.1 StreamSubscription

```dart
late StreamSubscription<WorkOrderEvent> subscription;

@override
void initState() {
  super.initState();
  subscription = repository.events(widget.orderId).listen(onEvent);
}

@override
void dispose() {
  subscription.cancel();
  super.dispose();
}
```

参数变更时在 didUpdateWidget 取消旧订阅并重建。只做 mounted 检查而不取消，会让 source 继续工作并保留回调引用。

### 6.2 Timer

周期 timer 必须 cancel。回调首先应有语义：页面离开后是否还需要？若需要，它就不应由页面 State 所有，而应移动到更长生命周期服务。

### 6.3 TextEditingController / FocusNode / AnimationController

由 State 创建就 dispose。`AnimationController` 需要 ticker provider；页面不可见时的动画策略还受 TickerMode 等影响。不能仅因为 mounted 为 true 就让所有后台动画继续。

### 6.4 App 生命周期不等于 Widget 生命周期

App 进入后台，页面 State 可能仍 mounted；route 被覆盖，State 也可能仍 mounted。需要暂停相机、定位、动画或刷新时，要监听应用/route 可见性协议，而不是把 mounted 当“用户正在看”。

## 7. Key 与 State 身份复习并深入

State 是否复用取决于 Element 协调。相同父级位置上 runtimeType + key 匹配时，旧 State 通常保留。

### 7.1 列表重排

```dart
ListView(
  children: orders.map((order) {
    return ExpandableOrderCard(
      key: ValueKey(order.id),
      order: order,
    );
  }).toList(),
)
```

无 key 时同类型节点按位置复用。A 展开后排序，A 的 State 可能出现在 B 位置。稳定 `ValueKey(order.id)` 让框架按业务身份匹配。

### 7.2 key 的层级

Key 只在同一父 Element 的直接 children 中比较。如果 key 被包在无 key 的相同外层：

```dart
Padding(
  child: ExpandableOrderCard(key: ValueKey(order.id), order: order),
)
```

重排时首先协调的是兄弟 Padding，内层 key 可能无法解决外层位置身份。应把 key 放到实际参与兄弟重排的最外层节点，例如 `Padding(key: ValueKey(order.id), ...)` 或使用带 key 的合适组件。

### 7.3 LocalKey 与 GlobalKey

`ValueKey` 等 LocalKey 在同一父级唯一。GlobalKey 在整个应用范围唯一，可跨父级移动并访问当前 State/Context，但会增加耦合和重挂载成本。

表单常用 `GlobalKey<FormState>` 是合理场景；不要用 GlobalKey 获取每个子组件状态并命令式操控。优先数据流和回调。

### 7.4 Key 不是数据库主键的自动替身

选择稳定且在兄弟范围唯一的身份。索引不是稳定业务身份；可编辑草稿如果尚无服务端 ID，需要客户端临时 ID。重复 key 会产生断言或协调错误。

## 8. didUpdateWidget 与参数驱动任务

一个页面 route 可能保留同一 State，只把 `orderId` 从 1 换到 2。任务所有权必须随参数更新：

```dart
@override
void didUpdateWidget(covariant WorkOrderDetails oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.orderId != widget.orderId) {
    currentOperation?.cancel();
    load(widget.orderId);
  }
}
```

还要清理旧展示策略：是立即清空、显示旧数据加刷新标识，还是缓存每个 ID？这是产品状态合同，不能让旧数据短暂冒充新 ID。

若任务依赖 `Locale`/认证 scope，还需在 didChangeDependencies 做有条件更新。多个触发源可能连续调用 load，统一交给一个 latest-wins 状态持有者更安全。

## 9. 可访问状态更新

加载与错误不仅是视觉 spinner/红字：

- loading 要有可理解语义，避免读屏不断重复；
- 失败提示包含下一步，并能聚焦/朗读；
- 内容更新后焦点不要无故跳回顶部；
- 排序重排不能让键盘/读屏焦点跟错工单；
- 禁用按钮要表达 disabled，不只是变灰；
- 自动刷新不应打断用户正在读/填的内容。

Key 身份、状态所有权和无障碍不是分开的：错误 key 会让文本框、焦点和语义节点都跟错项。

## 10. Widget 测试：用受控 Future 证明时序

真实网络太不确定。测试注入一个可手动完成的 repository：

```dart
final first = Completer<List<WorkOrder>>();
final second = Completer<List<WorkOrder>>();
final repository = FakeRepository([first.future, second.future]);

await tester.pumpWidget(buildPage(repository));
// 触发第二次加载。
await tester.tap(find.text('刷新'));
await tester.pump();

second.complete([orderB]);
await tester.pump();
expect(find.text(orderB.code), findsOneWidget);

first.complete([orderA]);
await tester.pump();
expect(find.text(orderB.code), findsOneWidget); // 旧响应不能覆盖。
```

再测试销毁：启动未完成请求，`pumpWidget(SizedBox.shrink())` 卸载页面，完成请求，断言无 “setState called after dispose” 异常，并验证取消 token 被调用。

注意：只断言没有异常仍不足以证明取消；Fake 要记录 `cancelled == true`。

## 11. 生命周期轨迹

学习时可给每个 State 分配 instance ID 并记录：

```text
state#7 init order=101
state#7 build order=101 expanded=false
state#7 setState expand
state#7 build order=101 expanded=true
state#7 didUpdateWidget 101 -> 102
state#7 cancel request#3
state#7 start request#4 order=102
state#7 dispose cancel request#4
```

轨迹能回答：同一 State 是否复用、参数是否更新、任务是否取消、销毁后是否有回调。日志不得包含敏感数据，实例 ID 只用于调试。

## 12. 常见误区逐条纠正

### 12.1 “mounted 在页面展示时执行”

错误。mounted 不是生命周期方法，没有“执行”。它是布尔属性，表示 State 是否关联 Element。被其他 route 覆盖时仍可能 true。

### 12.2 “mounted 能防止请求重复”

错误。只要页面仍在树中，多次点击会发多次请求。需要按钮去重、debounce/throttle、single-flight 或显式并发策略。

### 12.3 “mounted 能取消请求”

错误。检查 mounted 只丢弃结果。取消需要底层库支持、取消 token/operation、关闭订阅或将工作移交给正确所有者。

### 12.4 “请求结束必须 setState 才能拿到数据”

错误。Dart 字段赋值不需要 setState；只有需要让这棵 UI 重新根据新状态 build 时才通知 framework。状态库可能用 notify/listenable/provider 等方式。

### 12.5 “dispose 后请求会让 App 栈过载并必然崩溃”

不精确。未取消工作会浪费资源、产生竞态或回调已销毁 UI；严重时可能造成问题，但不是每个 Future 都导致“栈过载”。要用具体资源和证据描述。

### 12.6 “两个 controller 变量值都是 false，所以相等”

概念混乱。controller 通常是对象引用，不是布尔。`currentController == controller` 比较当前操作身份；替换后旧引用与新引用不同。不要用打印对象内部某个布尔状态替代身份判断。

## 13. 故障案例

### 13.1 setState after dispose

复现：页面启动 Future，立刻导航离开，Future 完成后无条件 setState。

首个证据：framework 异常指向回调和 State，生命周期轨迹显示 dispose 先于完成。

修复：dispose 取消工作；回调同时检查所有权/mounted 作为防线。重跑销毁时序并断言 cancel。

### 13.2 loading 被旧请求提前关闭

复现：A、B 并发，A 的 finally 无条件 `loading=false`。

首个证据：operation ID 日志显示 B 当前仍 pending，A 修改了共享 loading。

修复：只有 `currentOperation == operation` 才提交 result/error/finally 状态。

### 13.3 状态随索引而非工单移动

复现：无 key 的 Stateful 卡片排序。

首个证据：State instance ID 留在位置，而 order ID 变化。

修复：在实际兄弟层使用稳定 `ValueKey(order.id)`；测试重排和焦点。

### 13.4 参数变更仍展示旧数据

复现：同一 State 的 widget.orderId 更新，但只在 initState 加载。

首个证据：didUpdateWidget 发生却没有取消/加载轨迹。

修复：比较 old/new 参数，更新任务和 UI 状态；测试快速切换。

## 14. FactoryCare 实验：可取消、可重排工单列表

要求：

1. 页面加载 active 工单，显示 loading/success/empty/error；
2. 状态筛选快速切换采用 latest-wins；
3. repository 接受取消信号或返回可取消 operation；
4. dispose 传播取消；
5. 卡片用稳定工单 ID key；
6. 排序后展开状态与焦点跟随工单；
7. Fake repository 可控制完成顺序；
8. 测试覆盖销毁后完成、B 先于 A、取消、重排。

证据表：

| 场景 | 预测 | oracle |
| --- | --- | --- |
| 正常完成 | success(B) | 只展示当前筛选 |
| A 后于 B | 忽略 A | B 不被覆盖 |
| 页面销毁 | cancel + no UI update | cancel 计数 1，无 framework 异常 |
| 排序 | State 跟随 order ID | 展开/焦点不串项 |
| 请求失败 | failure + retry | 安全错误文案，无敏感日志 |

真实 HTTP 是否能强取消取决于客户端库和请求阶段；即使取消本地等待，服务端可能已经处理。教材必须说明这个残余风险。

## 15. 自测与参考答案

1. **mounted 初始是什么？** State 与 Element 关联后为 true，dispose 后为 false；不是 undefined。
2. **mounted 能做什么？** 防止在已卸载 State 上更新 UI。
3. **mounted 不能做什么？** 不去重、不取消任务、不保证可见、不解决旧响应竞态。
4. **为何 finally 也比较 operation 身份？** 防止旧请求关闭新请求的 loading。
5. **普通 Future 能通用强制取消吗？** 不能；需要底层协议/库支持或忽略结果。
6. **didUpdateWidget 何时重要？** State 复用但构造参数变化时更新订阅/任务。
7. **谁 dispose controller？** 默认由创建并拥有它的一方；传入资源合同另定。
8. **key 应放在哪？** 同一父级实际参与重排的兄弟节点上。
9. **StatefulWidget 本身可变吗？** 仍不可变，可变数据在 State。
10. **本章越界反例？** 在此选择 Riverpod/Bloc 品牌或实现完整离线缓存架构。

## 16. 章节验收清单

- [ ] 能画出 initState、didChangeDependencies、build、didUpdateWidget、deactivate、dispose 的触发关系。
- [ ] 能说明 setState 是同步状态修改 + 标记重建，不是网络/异步容器。
- [ ] 能准确复述 mounted 能做与不能做的事。
- [ ] 能实现 latest-wins，并在 result/error/finally 都检查操作身份。
- [ ] 能取消/释放 State 拥有的 subscription、timer、controller、focus 与可取消任务。
- [ ] 能在参数变化时更新任务/订阅。
- [ ] 能为重排列表选择稳定 key，并证明状态与焦点不串项。
- [ ] 能用受控 Future 测试旧响应、销毁和取消。
- [ ] 能区分忽略结果、本地取消和服务端停止的证据边界。

## 17. 官方资料与更新检查

- State lifecycle：<https://api.flutter.dev/flutter/widgets/State-class.html>
- State.mounted：<https://api.flutter.dev/flutter/widgets/State/mounted.html>
- BuildContext.mounted：<https://api.flutter.dev/flutter/widgets/BuildContext/mounted.html>
- `setState`：<https://api.flutter.dev/flutter/widgets/State/setState.html>
- Keys：<https://api.flutter.dev/flutter/foundation/Key-class.html>
- Flutter testing：<https://docs.flutter.dev/testing/overview>

资料核对日期：2026-07-24。Flutter API 与状态库会变化；资源所有权、生命周期对称、显式并发语义、mounted 只保护 UI 更新、key 表达稳定身份是长期核心。
