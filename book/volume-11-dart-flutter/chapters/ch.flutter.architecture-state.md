---
schema_version: 2
edition: 2026.2-draft
id: ch.flutter.architecture-state
title: 状态管理、模块边界与依赖方向
responsibility: 按 presentation/application/domain/data 划分依赖方向，为本地、共享与服务端状态选择所有者和可替换接口，不绑定单一状态管理品牌。
volume: '11'
order: 15
level: L2+
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.flutter.architecture-state.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.flutter.navigation-forms
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
  text: 在 120 秒内解释“状态管理、模块边界与依赖方向”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - flutter-layer-boundary
  - flutter-state-ownership
  covers_topics:
  - flutter.presentation-domain-data
  - flutter.dependency-inversion
  - flutter.repository-boundary
  - flutter.feature-module
  - flutter.local-shared-server-state
  - flutter.state-holder
  - flutter.immutable-ui-state
  - flutter.action-event
  - flutter.error-state-model
  uses_capabilities:
  - mobile.flutter-layout-lifecycle
  - mobile.dart-language
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“状态管理、模块边界与依赖方向”构建可运行程序与测试：把单文件工单应用拆成四层模块并用 Fake repository 验证依赖方向；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - flutter-layer-boundary
  - flutter-state-ownership
  covers_topics:
  - flutter.presentation-domain-data
  - flutter.dependency-inversion
  - flutter.repository-boundary
  - flutter.feature-module
  - flutter.local-shared-server-state
  - flutter.state-holder
  - flutter.immutable-ui-state
  - flutter.action-event
  - flutter.error-state-model
  uses_capabilities:
  - mobile.flutter-layout-lifecycle
  - mobile.dart-language
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: dependency-rule-test-state-transition-test-fake-repository
- id: diagnose
  kind: fault-diagnosis
  text: 面对“UI 直接访问存储、全局可变状态或双向层依赖导致的耦合”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - flutter-layer-boundary
  - flutter-state-ownership
  covers_topics:
  - flutter.presentation-domain-data
  - flutter.dependency-inversion
  - flutter.repository-boundary
  - flutter.feature-module
  - flutter.local-shared-server-state
  - flutter.state-holder
  - flutter.immutable-ui-state
  - flutter.action-event
  - flutter.error-state-model
  uses_capabilities:
  - mobile.flutter-layout-lifecycle
  - mobile.dart-language
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
generated_by: scripts/generate-curriculum.rb
generated_spec_digest: 5a42bf59bd52a6ea2b2a45f2f1d49f51664b52ddfaab49dce1df3dbb3ce78942
---
# 状态管理、模块边界与依赖方向

> 架构不是“选 Riverpod、Bloc、Provider 还是别的包”，也不是把文件夹命名为 `clean_architecture`。架构真正回答的是：每段代码负责什么，谁可以依赖谁，状态由谁拥有，外部系统如何被替换，以及失败时第一份可信证据在哪里。本章以 FactoryCare 工单列表为贯穿案例，先建立不绑定品牌的合同，再讨论 Flutter 如何把状态呈现为 Widget。

## 1. 从单文件应用看到问题，而不是先画漂亮目录

零基础项目往往从一个 `StatefulWidget` 开始：`initState` 请求接口，JSON 在页面中解析，列表存在 `_items`，点击按钮直接写本地数据库，`setState` 同时控制 loading、error 和数据。几十行时它能运行，这并不等于边界正确。

需求增长后，同一文件会承担六种职责：绘制界面、接收用户动作、安排异步流程、执行工单规则、选择远程或本地数据源、把外部异常翻译成用户提示。于是出现连锁问题：Widget 测试必须启动大量依赖；离线存储更换会改 UI；两个页面各自保存一份当前用户；加载失败后旧列表被清空；AI 修改一个按钮时顺手改变重试规则。

拆层的目标不是追求文件数量，而是让变化被边界吸收。例如“把 REST 服务替换成 Fake”只应影响 data 装配；“关闭中的工单不能重新指派”应在纯 Dart 规则里验证；“错误态显示重试按钮”属于 presentation。能够说出变化会停在哪一层，才说明架构产生了价值。

本章采用四个名称：

- **presentation（表现层）**：Widget、页面与面向 UI 的状态持有者；负责显示状态、转交动作和少量布局/导航逻辑。
- **application（应用层）**：编排一个用户用例，例如“加载工单”“重新指派”；定义步骤、并发策略和结果，不绘制 Widget。
- **domain（领域层）**：业务概念与不变量，例如工单状态、优先级、允许的转换；尽量只依赖 Dart。
- **data（数据层）**：Repository 实现、HTTP/数据库/平台 Service、DTO 与映射；吸收外部格式和基础设施失败。

这四层是本课程为 FactoryCare 选择的学习模型，不是 Flutter 编译器要求的唯一目录。判断正确与否要看职责和依赖，而不是文件夹拼写。

## 2. Flutter 官方指南与本课程四层如何对应

截至 2026-07-24，Flutter 官方架构指南页面处于 Flutter 3.44 文档家族。官方强调“关注点分离”，先把应用分成两个宽层：UI layer 与 Data layer；UI 中有 View 和 ViewModel，Data 中有 Repository 和 Service。复杂逻辑需要时可以加入可选 Domain layer/use-case。官方也明确说明这些是应按项目调整的指南，而不是不可违背的框架规则。

本课程并未与官方冲突，而是把宽层继续拆开：

| 官方常见称呼 | 本课程位置 | 主要对象 | 说明 |
| --- | --- | --- | --- |
| View | presentation | Screen、Widget | 读取 UI state，发出用户 action |
| ViewModel | presentation 为主 | state holder | 把用例结果映射为 UI state；不直接操作存储 |
| use-case/interactor | application | `LoadOrders`、`AssignOrder` | 编排一次业务意图；简单功能可不建空壳类 |
| domain model/rule | domain | `WorkOrder`、状态转换规则 | 表达业务语义与不变量 |
| Repository | domain 端口 + data 实现 | `WorkOrderRepository` | 对内暴露领域合同，对外协调数据源 |
| Service | data | API、数据库、平台插件适配器 | 包装外部 I/O，返回原始响应或 DTO |

官方指南的示例常让 ViewModel 直接调用 Repository，并把 domain/use-case 视为按复杂度添加。本课程在 FactoryCare 中显式写 application，是因为工单操作逐步涉及权限、幂等、离线、审计和多数据源；它不是要求每个 getter 都创建 use-case。只有当应用编排能独立表达、复用或测试时，才值得形成对象或函数。

稳定概念是关注点分离、单一事实源、单向数据流、不可变快照、依赖注入与可替换边界。可能随版本和团队变化的是 `ChangeNotifier`、命令辅助类、路由包、代码生成器和具体状态库。因此本章 `stable_core: false`：原则相对稳定，Flutter API 与官方推荐细节仍需在实际实施时复核。

## 3. 层、模块、功能与包不是同义词

**层（layer）**按技术职责划分依赖方向；**功能（feature）**按用户能力划分，例如工单、设备、会话；**模块（module）**是拥有明确公开接口、内部实现和依赖规则的一组代码；**package** 是 Dart 工具链的发布/依赖单位。一个文件夹可以叫 module，但若任何代码都能导入其内部文件，它实际上没有边界。

小型应用可以全局按层组织：

```text
lib/
  presentation/
  application/
  domain/
  data/
```

功能增多后更推荐 feature-first，再在功能内按职责拆分：

```text
lib/
  features/
    work_orders/
      presentation/
      application/
      domain/
      data/
    devices/
      presentation/
      application/
      domain/
      data/
  shared/
    session/
    diagnostics/
  app/
    composition_root.dart
```

feature-first 的优势是修改“工单”时相关文件相邻、删除功能时边界清晰、团队可按业务切分。风险是把所有复用代码过早搬进 `shared`，最后 `shared` 变成谁都依赖的杂物间。进入 shared 的条件应是语义真的跨功能且拥有明确维护者，而不是“第二次出现就抽象”。

跨 feature 依赖也要通过公开合同。设备页面若需要“未结工单数”，不要导入工单 data 内部的 SQLite DAO；应调用 application 层公开查询，或订阅由明确所有者发布的只读领域状态。循环引用通常说明某个共同概念归属不清，不能靠合并两个文件掩盖。

## 4. 依赖方向：源代码箭头与运行时调用要分开

“依赖”首先指编译期认识：A 文件 `import` B、构造器参数使用 B 类型、A 继承或实现 B，都是 A 指向 B。运行时调用箭头可以相反，这正是依赖反转容易令人困惑的地方。

课程规则是外层可以认识内层抽象，内层不能认识 Flutter、HTTP、SQLite 或具体实现：

```text
presentation ---> application ---> domain
       |                 ^             ^
       |                 |             |
       +------------ composition       |
data implementation -------------------+
```

更精确地说：presentation 调用 application；application 使用 domain 中的实体与端口；data 实现内层声明的端口；应用入口（composition root）负责创建具体对象并注入。domain 不 import data。data 可以 import domain 来实现接口和构造领域对象。不同团队也可能把 Repository 抽象放 application；只要抽象由需要它的内层拥有、依赖箭头向内、规则一致即可。

例如领域侧声明：

```dart
abstract interface class WorkOrderRepository {
  Future<List<WorkOrder>> findOpen();
  Future<WorkOrder> save(WorkOrder order);
}
```

data 侧实现：

```dart
final class HttpWorkOrderRepository implements WorkOrderRepository {
  final WorkOrderApi _api;
  HttpWorkOrderRepository(this._api);

  @override
  Future<List<WorkOrder>> findOpen() async {
    final response = await _api.fetchOpen();
    return response.items.map(WorkOrderMapper.fromDto).toList(growable: false);
  }
}
```

运行时是用例调用 `WorkOrderRepository`，最终进入 `HttpWorkOrderRepository`；编译期内层只认识自己的接口。若将 HTTP 实现替换为 Fake，application 与 presentation 不改，这就是可替换性的证据。

## 5. 依赖注入不是一定要装容器

依赖注入的最小形式就是构造器参数：对象不在内部偷偷 `new` 自己的依赖，而由外部传入。容器、Provider 或 service locator 只是组装工具，不是原则本身。

```dart
final class LoadOpenOrders {
  final WorkOrderRepository _repository;
  const LoadOpenOrders(this._repository);

  Future<List<WorkOrder>> call() => _repository.findOpen();
}
```

应用启动处是 composition root：在那里创建 `HttpClient`、API service、Repository、用例与 state holder，并把它们交给 Widget 树。这是外层唯一应该集中知道具体实现的地方。若每个页面都通过全局单例查找对象，测试必须清理全局状态，生命周期也难以判断；若每次 build 都创建 Repository，又会丢失共享缓存。

注入范围要匹配所有者生命周期：应用会话共享的 Repository 通常在会话或应用作用域创建；页面专用 state holder 在 route 作用域创建并释放；一次操作的临时值留在方法栈。范围错误比“没用某个 DI 包”更危险。

## 6. Domain：业务语义与不变量的家

领域层不是 DTO 仓库。它描述业务，而不是复刻接口字段。FactoryCare 的 `WorkOrder` 可以拥有 `id`、`status`、`priority`、`assigneeId` 和版本号，并通过构造或转换方法维护规则：已关闭工单不能再次指派；进入处理中必须有处理人；版本不能倒退。

```dart
enum WorkOrderStatus { assigned, inProgress, closed, cancelled }

final class WorkOrder {
  final String id;
  final WorkOrderStatus status;
  final String? assigneeId;
  final int revision;

  const WorkOrder._(this.id, this.status, this.assigneeId, this.revision);

  WorkOrder start() {
    if (status != WorkOrderStatus.assigned || assigneeId == null) {
      throw StateError('only an assigned order with assignee can start');
    }
    return WorkOrder._(id, WorkOrderStatus.inProgress, assigneeId, revision + 1);
  }
}
```

例子使用抛异常只是教学选择；生产合同也可返回 sealed result。重点是不让 Widget、API mapper 和数据库各自复制一份状态转换。Domain 不应 import `package:flutter/...`；这样规则能用 `dart test` 快速验证，也能在后台 isolate 或命令行工具中复用。

并非所有校验都是领域规则。TextField 是否为空的即时提示属于 presentation；接口字符串能否解析成枚举属于 data 边界；当前用户是否有执行权限可能需要 application 结合会话与服务端权威决定。把每种校验都塞进实体只会形成另一种巨型对象。

## 7. Application：编排一次用户意图

Application 处理“做什么步骤”，不处理“按钮是什么颜色”。以“开始维修”为例：读取当前用户、加载工单、执行领域转换、保存、把冲突翻译为应用结果、记录必要诊断信息。它可能协调多个端口，但不应知道 REST URL 或 Widget Context。

```dart
sealed class StartOrderResult { const StartOrderResult(); }
final class StartSucceeded extends StartOrderResult {
  final WorkOrder order;
  const StartSucceeded(this.order);
}
final class StartConflict extends StartOrderResult { const StartConflict(); }
final class StartDenied extends StartOrderResult { const StartDenied(); }

final class StartWorkOrder {
  final WorkOrderRepository _orders;
  final SessionReader _session;
  const StartWorkOrder(this._orders, this._session);

  Future<StartOrderResult> call(String id) async {
    final actor = _session.currentUser;
    if (!actor.canRepair) return const StartDenied();
    final current = await _orders.getById(id);
    try {
      return StartSucceeded(await _orders.save(current.start()));
    } on RevisionConflict {
      return const StartConflict();
    }
  }
}
```

不要为了“形式完整”给每个 repository 方法包一层只转发的 use-case。官方指南也把 domain/use-case 视为条件性选择。判断依据是：是否存在编排、是否跨 Repository、是否需要复用、是否需要单独策略或测试。简单只读页让 state holder 直接依赖 Repository 也可以，但同一 feature 要有明确一致的约定。

## 8. Repository 与 Service 的边界

Repository 对应用说领域语言，是某类应用数据的单一事实源；Service 对外部系统说协议语言，是 HTTP endpoint、数据库、文件或平台插件的薄适配器。官方指南将缓存、刷新、重试、错误处理等数据策略放在 Repository，将 Service 描述为包装外部 I/O、尽量无状态的对象。

```text
UI/Application -> WorkOrderRepository -> WorkOrderApiService
                                  \----> WorkOrderCacheService
```

API Service 可返回 `WorkOrderDto`、状态码和协议错误，不应决定“列表展示旧数据还是全屏错误”。Repository 选择远程与缓存、DTO 映射、维护数据流并输出领域对象。application 决定某个用例遇到冲突如何继续。presentation 决定对应结果显示 banner、空页还是对话框。

Repository 不应互相依赖。若 `WorkOrderRepository` 需要 `DeviceRepository` 才能组合页面数据，应由 application/use-case 或 state holder 组合；否则 Repository 图会形成隐形业务层和循环。例外必须写 ADR，说明所有权为何仍唯一。

“Repository 是单一事实源”不等于“服务端不是权威”。移动端 Repository 可以是应用内观察数据的唯一入口，而服务端仍是跨设备业务事实的最终权威。Repository 负责明确当前值是缓存、乐观值还是服务端确认值，不能把来源抹掉。

## 9. 状态到底是什么：值、事实、草稿与派生结果

状态是影响未来输出、且在某段时间内需要保存的信息。并非方法里的每个变量都是应用状态。可以用三个问题识别所有者：谁创建它？谁能修改它？需要活多久？

| 状态 | 例子 | 推荐所有者 | 生命周期 |
| --- | --- | --- | --- |
| 本地/临时 UI 状态 | 当前 Tab、展开项、输入焦点 | 页面或局部 Widget | Widget/Route |
| 页面工作流状态 | loading、列表、错误、筛选条件 | 页面 state holder/ViewModel | Route/feature |
| 共享会话状态 | 当前用户、租户、权限快照 | Session Repository/会话作用域 | 登录会话 |
| 服务端状态的本地视图 | 工单列表、revision、同步时间 | Repository | 应用/会话，并可持久化 |
| 持久草稿 | 未提交报修内容 | Draft Repository | 跨页面甚至跨重启 |
| 派生状态 | `visibleOrders`、`activeCount` | 从权威状态计算 | 不单独写入，除非有缓存合同 |

“共享”不是把变量放成 `static`。共享意味着多个消费者观察同一个有所有者、有更新入口、有生命周期的源。全局可变 List 允许任何地方绕过规则修改，测试顺序相关，登出后也可能残留。

服务端状态不能由两个页面各自宣称拥有。两个 state holder 可以各有展示快照，但它们应从同一 Repository 数据流获得，并由 Repository 负责刷新/合并。页面草稿可以暂时偏离服务端实体，因为草稿有不同语义；提交成功后再由结果更新事实源。

## 10. 单一事实源不等于只有一个对象

Single Source of Truth（SSOT）指一项事实有一个权威更新入口，不是整个应用只有一个巨型 Store。当前登录用户由 Session Repository 拥有；工单事实由 WorkOrder Repository 拥有；编辑页未保存文本由 Editor state holder 拥有。各自一个所有者，组合时读取它们。

典型反例是在 UI state 同时保存 `orders` 与 `activeCount`，更新列表时忘记更新计数。若计数能由列表过滤得到，应使用 getter：

```dart
int get activeCount => orders.where((o) => o.isActive).length;
```

若计算昂贵，可以缓存，但缓存必须明确失效条件，并测试列表变化后缓存更新。派生值不是“绝对不能存”，而是多存一份就多一份一致性合同。

另一个反例是 Repository 有 `_orders`，ViewModel 又长期维护另一份可编辑 `_orders`。解决前先区分：ViewModel 的是否仅是不可变展示快照？是否包含本地筛选？编辑是否是草稿？只要语义不同可以共存，但命名和同步边界必须写清。

## 11. 不可变 UI State：每次发布完整快照

Flutter 是声明式 UI：给定当前状态，build 描述应显示的 Widget。不可变 UI state 让每次变化生成一个新快照，旧快照不会被其他代码悄悄修改，日志也能比较 before/after。

一种设计是 sealed 状态：

```dart
sealed class OrdersUiState { const OrdersUiState(); }
final class OrdersInitial extends OrdersUiState { const OrdersInitial(); }
final class OrdersLoading extends OrdersUiState { const OrdersLoading(); }
final class OrdersContent extends OrdersUiState {
  final List<WorkOrder> orders;
  final bool refreshing;
  const OrdersContent(List<WorkOrder> orders, {this.refreshing = false})
      : orders = List.unmodifiable(orders);
}
final class OrdersEmpty extends OrdersUiState { const OrdersEmpty(); }
final class OrdersFailure extends OrdersUiState {
  final UiFailure failure;
  final List<WorkOrder> staleOrders;
  const OrdersFailure(this.failure, {this.staleOrders = const []});
}
```

另一种是单一 data class，含 `phase`、data、error。两者都可用，关键是不允许非法组合。例如 `isLoading=true`、`error!=null`、`items` 又被清空究竟显示什么？sealed 状态限制组合更强；data class 复制和局部更新更方便。选型应由状态复杂度决定，而不是追热门写法。

`final List` 只保证字段引用不能重绑，不保证 List 内容不可变，因此发布前应复制并用 `List.unmodifiable` 或真正不可变集合。UI state 也不要持有 `BuildContext`、controller、HTTP response 或数据库 cursor；这些对象有不同生命周期，不是可比较的展示快照。

## 12. Action、Event、Command 与单向数据流

术语会因团队而异，本章给出可执行定义：

- **Action**：用户或系统发给 state holder 的意图，如 `RefreshPressed`、`FilterChanged`。
- **Command/use-case 调用**：application 执行的业务操作，可以产生结果。
- **State**：持久可观察的 UI 快照，Widget 由它渲染。
- **Effect/Event**：只消费一次的外部效果，如导航、SnackBar；若需要恢复或重放，就不能只当瞬时事件。

数据流如下：

```text
用户动作 -> View -> state holder -> application/repository
                           |                 |
                           +<--- result -----+
                           |
                           +-- 新 UI state --> View rebuild
```

Widget 不应该先修改 Repository 内部 List 再通知 state holder。所有写操作从 action 的唯一入口进入，state holder 负责防重复、标记 loading、调用用例、根据结果生成新状态。这使状态转换可写成表格和单元测试。

一次性 effect 容易丢失或重复：旋转屏幕、重新订阅、热重载可能再次收到。导航如果是业务工作流的一部分，可让 View 对“保存成功”结果只处理一次，并在 state holder 中用明确消费协议；关键消息若用户稍后仍需看到，应成为持久状态而非 SnackBar event。

## 13. State holder 不等于某个状态管理品牌

State holder 是角色：拥有 UI state、接收 action、调用用例并发布新状态。它可以用 Flutter SDK 的 `ChangeNotifier`/`ValueNotifier`，也可以用 Stream、某个状态库或团队封装。官方当前将 `ChangeNotifier`/`Listenable` 推荐标为条件性，并承认状态管理有多种选项。

本章先写不依赖 Flutter 的核心：

```dart
final class OrdersController {
  final LoadOpenOrders _load;
  OrdersUiState _state = const OrdersInitial();
  OrdersUiState get state => _state;

  Future<void> refresh() async {
    if (_state is OrdersLoading) return;
    _state = const OrdersLoading();
    try {
      final orders = await _load();
      _state = orders.isEmpty ? const OrdersEmpty() : OrdersContent(orders);
    } on RepositoryUnavailable {
      _state = const OrdersFailure(UiFailure.retryable());
    }
  }
}
```

接入 Flutter 时再让适配器通知 Widget，或让 controller 实现选定库的协议。这样更换观察机制不应改变领域规则、Repository 合同和状态转换测试。若 controller 直接继承某个库的基类也不一定错误，但业务核心与包 API 的耦合成本要清楚。

状态库解决的是传播、订阅、作用域和工具体验，不能自动决定状态所有权，也不能阻止循环依赖。把所有变量放进同一个全局 store 仍然是所有权模糊。

## 14. Loading、Empty、Error、Stale 需要独立语义

错误状态不是一个随手保存的 String。至少要回答：用户能否重试？旧数据还能否展示？是否需要登录？是否发生版本冲突？诊断系统用什么代码追踪？

```dart
enum UiFailureKind { offline, unauthorized, conflict, invalidData, unknown }

final class UiFailure {
  final UiFailureKind kind;
  final String userMessage;
  final String diagnosticCode;
  final bool retryable;
  const UiFailure(this.kind, this.userMessage, this.diagnosticCode, this.retryable);
}
```

不要把原始异常、堆栈、URL 或 token 放进用户消息。data 将协议/存储异常映射为有语义的 Repository failure；application 转为用例结果；presentation 选择安全文案并把脱敏诊断码交给日志。

首次加载和后台刷新也不同：首次无数据可显示全屏 loading；已有列表刷新时通常保留旧内容并显示小型进度。刷新失败后可以是 `stale content + banner`，不应为了一个临时网络错误把可用数据清空。Empty 代表请求成功且结果确实为空，不是失败的替代。

状态转换矩阵是很好的 oracle：

| 当前状态 | Action/结果 | 下一个状态 | 不允许的副作用 |
| --- | --- | --- | --- |
| Initial | Refresh | Loading | 不显示伪造空列表 |
| Loading | success(non-empty) | Content | 不保留旧 error |
| Loading | success(empty) | Empty | 不写成 Failure |
| Content | Refresh | Content(refreshing) | 不清空 items |
| Content(refreshing) | retryable failure | Failure(stale items) | 不丢旧数据 |
| 任意 | unauthorized | Failure(auth) | 不无限自动重试 |

## 15. 异步竞争的所有者也必须明确

架构拆层后仍可能有竞态：用户连续切筛选条件，旧请求晚于新请求返回；页面销毁后请求完成；两个 action 同时保存。`mounted` 只能保护 Widget 不在卸载后更新，不能取消 Future，也不能决定哪个响应更新 Repository。

state holder/application 应拥有并发策略：忽略重复、最后一次获胜、顺序排队、可取消、或按版本冲突失败。策略必须与业务一致。搜索筛选通常 last-write-wins，可用 generation/request id 丢弃过期结果；提交工单不能简单丢弃，通常需要禁用重复提交与服务端幂等。

当 state holder dispose 时，它应停止发布 UI state，并请求支持取消的客户端终止操作；但 Repository 级刷新若服务多个页面，不能由其中一个页面随意取消。谁启动、谁观察、谁共享，决定取消所有权。

本章资产只用同步/可控 Future 验证状态转换，不声称证明真实 HTTP 取消；网络取消和离线队列在下一章处理。

## 16. Fake Repository：替换边界，而不是复制实现

Fake 是可工作的轻量实现，使用内存与可控失败来满足同一接口；Mock 通常验证调用和预设返回。状态转换测试优先使用 Fake，因为它表达行为，减少测试与内部调用次数耦合。

```dart
final class FakeWorkOrderRepository implements WorkOrderRepository {
  List<WorkOrder> values;
  Object? nextFailure;
  FakeWorkOrderRepository(this.values);

  @override
  Future<List<WorkOrder>> findOpen() async {
    final failure = nextFailure;
    nextFailure = null;
    if (failure != null) throw failure;
    return List.unmodifiable(values.where((o) => o.isOpen));
  }
}
```

同一组 controller 测试分别注入成功 Fake、空 Fake 与失败 Fake，应得到 Content、Empty 与 Failure。UI state 转换不应知道 Fake 名称。若替换 Repository 后必须修改 Widget 或状态类，说明抽象泄漏了 HTTP DTO、数据库 row 或具体包类型。

Fake 不能证明真实实现正确。还需要 Repository contract test：对 Fake 与真实实现（或受控集成环境）运行共同的语义用例，例如排序、找不到、冲突和错误映射。Fake 也不要比生产合同更宽松，否则测试会给出假绿。

## 17. 依赖规则测试：让边界变成机器可见证据

代码审查可发现 `presentation` 直接 import `data`，但项目变大后最好自动检查。最简单的脚本读取 `lib/features/**.dart` 的 import，按目录映射 layer，并拒绝规则外箭头。例如：domain 不能依赖 application/presentation/data/Flutter；application 不能依赖 presentation/data/Flutter；presentation 不直接依赖 data；data 不依赖 presentation。

测试要输出：来源文件、来源层、非法目标和规则。首个可信证据是具体 import，而不是后续运行时“数据不对”。静态检查有边界：字符串解析器不等同 Dart analyzer，可能无法识别导出链、package 重命名或生成代码；成熟项目可用 analyzer 插件、lint 或 package 边界加强。

本章 lab 会建立临时四层纯 Dart 文件并检查 import 图，同时运行 Fake Repository 状态转换。它证明教学合同在该样例中成立，不证明整个 FactoryCare 代码库已经符合规则。

依赖规则只看箭头，不证明职责正确。把数据库调用代码复制进 domain 而不 import data，静态图可能仍绿。因此还要结合代码审查、单元测试和术语检查。

## 18. 三类典型故障与首个可信证据

### 18.1 UI 直接访问存储

表现：Widget import SQLite/HTTP client，测试需要真实插件，缓存字段进入 UI。失败阶段通常先在静态 dependency-rule test；首证据是 `presentation/...dart -> data/...dart` 的非法 import。修复是让 UI 依赖 state holder/application 接口，由 data 实现内层端口。残余风险：仅移动文件但 DTO 仍泄漏。

### 18.2 全局可变状态

表现：测试单独通过、一起失败；登出后上个用户数据残留；任何页面可修改 List。首证据可以是测试顺序相关、两个独立实例共享值，或静态扫描发现 mutable global/static。修复是确定唯一所有者和作用域，通过只读快照/方法更新，并在会话结束释放。残余风险：第三方单例或缓存仍有隐式状态。

### 18.3 双向层依赖

表现：application import presentation 的 dialog 类型，presentation 又 import application；无法独立测试，改 UI 迫使业务层重编译。首证据是 import cycle 或架构检查的双向边。修复时把双方需要的合同移到拥有它的内层，外层做映射；不要建 `common.dart` 让双方都依赖大杂烩。残余风险：事件总线虽消除显式 import，却可能形成更难追踪的运行时环。

诊断顺序应是：找到失败阶段；读第一条明确指出本项目文件的错误；画依赖/所有权；做最小修复；重跑原测试；再跑相邻回归。不要只凭最终 `BUILD FAILED` 或用户截图猜测。

## 19. FactoryCare 从单文件拆成四层

以“查看未关闭工单并刷新”为例，目标目录可以是：

```text
features/work_orders/
  domain/
    work_order.dart
    work_order_repository.dart
  application/
    load_open_orders.dart
  data/
    work_order_api_service.dart
    work_order_dto.dart
    http_work_order_repository.dart
  presentation/
    orders_ui_state.dart
    orders_controller.dart
    orders_screen.dart
```

逐步迁移比一次大爆炸安全：

1. 先写当前行为的状态转换测试，保存成功/空/失败证据。
2. 提取纯 Dart `WorkOrder` 与规则，不改变 UI。
3. 声明 Repository 端口，用适配器包住现有数据访问。
4. 提取 `LoadOpenOrders` 与 controller，把 Widget 中异步编排迁出。
5. Widget 只读取 UI state、转发 Refresh action。
6. 注入 Fake，跑同一状态转换测试；再加静态依赖规则。
7. 删除旧直连路径，而不是永久维护两套事实源。

这是一项架构/目录变更，真实项目实施前应比较一次迁移、按 feature 渐进迁移和保留旧结构三种方案，明确影响、回滚与完成标准。本教材展示目标态和安全顺序，不授权自动重构现有 FactoryCare 项目。

完成标准不是“目录都创建了”，而是：静态依赖只指向允许方向；本地、共享与服务端状态各有唯一所有者；替换 Repository 后 UI 状态转换测试不变；旧直连入口已移除；失败与残余风险有证据。

## 20. 测试金字塔与证据矩阵

| 风险 | 最小有效测试 | Oracle | 本章资产是否覆盖 |
| --- | --- | --- | --- |
| 领域状态转换错误 | 纯 Dart 单元测试 | 非法转换拒绝、合法转换新快照 | 覆盖样例核心 |
| Repository 不可替换 | Fake substitution test | 同一用例不改调用者 | 覆盖 |
| UI state 非法组合 | state transition test | 转移矩阵 | 覆盖 |
| 层依赖反向 | dependency rule | 具体非法 import 为红 | lab 样例覆盖 |
| Widget 未按 state 渲染 | Flutter widget test | finders/黄金图/交互 | **未覆盖** |
| DI 生命周期错误 | Widget/integration test | 页面释放与会话重建 | **未覆盖** |
| 真实 HTTP/缓存映射错误 | contract/integration test | 真实协议与故障 | **未覆盖** |

公共 exercise 故意保留“presentation 直接依赖 data”的错误，`verify.sh` 必须稳定返回非零；它是练习起点，不是仓库坏了。私有 solution 修正同一规则并返回绿。不能通过删除断言、改 expected 或吞掉退出码制造假绿。

每份证据至少保存输入、工件、命令、退出码和关键输出。只有 `dart analyze` 绿不能证明行为；只有行为输出绿也不能证明依赖方向。本章因此组合静态规则与运行时状态测试。

## 21. 与 Vue/TypeScript 的类比及边界

如果你熟悉 Vue，可以把 Widget/View 类比为 Vue SFC 的模板与轻量交互，把 state holder 类比为 feature composable/store，把 Repository 类比为面向业务的数据访问门面，把 Service 类比为 axios client/local storage adapter。但不要机械一一对应：Flutter Widget 生命周期、Dart 类型和移动端进程恢复不同。

Pinia store 也不天然是 Repository。若 store 直接拼 URL、解析 DTO、做领域转换、控制弹窗，它仍混合职责。反过来，Flutter 使用 Provider/Riverpod/Bloc 也不代表拥有清晰 architecture；包只提供依赖作用域和状态传播能力。

TS 的 `readonly` 与 Dart 的 `final` 都不自动深度冻结集合。Vue computed 与本章派生状态类似：能从权威值稳定计算的内容优先派生。Vue 组件卸载后的异步问题也与 Flutter 相似：生命周期保护 UI 更新，不自动取消底层请求。

## 22. AI 协作边界

可以让 AI：依据已经确认的依赖矩阵生成重复目录；把 DTO mapper、Fake 和测试骨架补齐；扫描 import 并列出疑似越界；根据状态转换表生成测试组合；解释失败日志的第一条本项目证据。

必须由开发者决定并验证：每项状态的唯一所有者；Repository 合同是否表达业务而非基础设施；application 是否确有编排价值；失败是可重试、冲突还是权限问题；DI 生命周期；真实实现与 Fake 是否遵守同一合同；迁移何时删除旧入口。

禁止把以下说法直接当完成证据：“用了 Clean Architecture”“AI 建了四个文件夹”“换成某状态库就不会乱”“单元测试通过所以 Widget 生命周期正确”。还要警惕 AI 为了消除编译错误把接口移到 `common`、加入全局 service locator、暴露 `dynamic` 或让 presentation import data。

推荐审查提示词包含合同而非风格：“列出每个 import 箭头和状态所有者；找出 presentation 直连 data、Repository 互相依赖、可变集合泄漏、重复事实源；不要修改代码，先给首个可信证据与最小修复范围。”

## 23. 本章动手路线

### 23.1 Example：替换 Repository

运行 `examples/encyclopedia/ch.flutter.architecture-state/verify.sh`。它创建 domain 端口、两个 data 实现、application 用例和不可变 UI state；同一 controller 在两个 Fake/Memory 实现上产生相同状态。预测：若 controller 构造器改成具体 `MemoryWorkOrderRepository`，哪个层首先被锁死？

### 23.2 Lab：依赖图 + 状态转换

运行 `labs/encyclopedia/ch.flutter.architecture-state/verify.sh`。脚本生成临时 feature 文件，验证允许的 import 图，再覆盖 success、empty、failure 和 stale refresh 转移。然后人为让 presentation import data，确认规则先红；修复后重跑原命令。

### 23.3 Exercise：稳定预期红

运行 `exercises/encyclopedia/ch.flutter.architecture-state/verify.sh`。初始实现故意让 presentation 直接依赖 data，脚本输出 `ARCHITECTURE_DEPENDENCY_EXERCISE` 并非零退出。你的任务是通过引入内层端口与注入修复，不能删检查器。参考解仅用于完成尝试后的对照。

### 23.4 120 秒讲回模板

不看正文回答：四层各自职责；编译期依赖与运行时调用为何不同；一个本地、共享、服务端状态的所有者；Repository 与 Service 区别；替换 Fake 后什么测试必须不变；一个越界反例和首证据。说不清时回到对应章节，不用从头重读。

## 24. 已验证、未验证与明确不做

本章随附验证器只依赖本机 Dart，验证的是纯 Dart 的端口替换、不可变快照、状态转换与教学样例 import 规则。脚本运行时会使用临时目录并清理，不写入真实应用。

它们**没有验证** Flutter Widget rebuild、`BuildContext`、`ChangeNotifier`、第三方状态库、真实路由、真实 HTTP/SQLite/平台插件、热重启、进程恢复、Android/iOS 生命周期和整库依赖图。完成真实项目时仍需 `flutter test` 的 Widget 测试、集成测试、真实 Repository contract test 以及项目级架构规则。

本章明确不选择全局状态管理品牌，不把 domain 强制用于每个简单功能，不建设网络/离线实现，不重构现有 FactoryCare 仓库，也不修改学习进度。目录结构是推荐目标而非兼容承诺；若旧项目迁移，应单独确认方案、影响和回滚。

## 25. 官方资料与版本边界

以下页面于 2026-07-24 核对；官方文档当时显示 Flutter 3.44 文档家族。项目实际使用其他 stable patch 时，应重新核对 API 与推荐等级：

- [Flutter：Guide to app architecture](https://docs.flutter.dev/app-architecture/guide)
- [Flutter：Architecture recommendations and resources](https://docs.flutter.dev/app-architecture/recommendations)
- [Flutter：Common architecture concepts](https://docs.flutter.dev/app-architecture/concepts)
- [Flutter：Architecture case study](https://docs.flutter.dev/app-architecture/case-study)
- [Flutter：State management fundamentals](https://docs.flutter.dev/data-and-backend/state-mgmt)
- [Dart：Libraries and imports](https://dart.dev/language/libraries)
- [Dart：Class modifiers](https://dart.dev/language/class-modifiers)
- [Dart：Testing](https://dart.dev/tools/testing)

阅读官方示例时要区分两类证据：官方明确强烈推荐 UI/Data 分离、Repository、View/ViewModel、单向数据流、不可变模型与依赖注入；Domain/use-case、`ChangeNotifier`、独立 API/domain model 等带条件或项目规模判断。本课程的四层映射是针对 FactoryCare 的架构决定，不能冒充 Flutter 唯一官方目录。
