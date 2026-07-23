---
schema_version: 2
edition: 2026.2-draft
id: ch.dart.oop-generics
title: 类、泛型、mixin、extension 与对象边界
responsibility: 用类、构造器、封装、接口/组合、泛型、mixin 和 extension 建立对象边界，整合前置类型与集合能力但不教授异步。
volume: '11'
order: 5
level: L2
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.dart.oop-generics.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.dart.collections-patterns
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
  text: 在 120 秒内解释“类、泛型、mixin、extension 与对象边界”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - dart-object-model
  - dart-generics-language-synthesis
  covers_topics:
  - dart.class-constructor
  - dart.encapsulation
  - dart.abstract-interface
  - dart.inheritance-composition
  - dart.mixin-extension
  - dart.generic-type
  - dart.generic-bound
  - dart.nullable-nonnullable
  - dart.list
  - dart.map
  - dart.record
  uses_capabilities:
  - foundation.toolchain-env-build
  - mobile.dart-language
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“类、泛型、mixin、extension 与对象边界”构建可运行程序与测试：用不可变值对象、repository 接口和泛型结果类型建模维修工单；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - dart-object-model
  - dart-generics-language-synthesis
  covers_topics:
  - dart.class-constructor
  - dart.encapsulation
  - dart.abstract-interface
  - dart.inheritance-composition
  - dart.mixin-extension
  - dart.generic-type
  - dart.generic-bound
  - dart.nullable-nonnullable
  - dart.list
  - dart.map
  - dart.record
  uses_capabilities:
  - foundation.toolchain-env-build
  - mobile.dart-language
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: analyzer-fixture-object-contract-test-substitution-case
- id: diagnose
  kind: fault-diagnosis
  text: 面对“可空字段破坏不变量、共享静态状态或错误继承导致的对象污染”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - dart-object-model
  - dart-generics-language-synthesis
  covers_topics:
  - dart.class-constructor
  - dart.encapsulation
  - dart.abstract-interface
  - dart.inheritance-composition
  - dart.mixin-extension
  - dart.generic-type
  - dart.generic-bound
  - dart.nullable-nonnullable
  - dart.list
  - dart.map
  - dart.record
  uses_capabilities:
  - foundation.toolchain-env-build
  - mobile.dart-language
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
generated_by: scripts/generate-curriculum.rb
generated_spec_digest: ddc1dbee56784204468cd1e5706a1880eb4bb24f1335717c8b8ad2868b967dcd
---
# 类、泛型、mixin、extension 与对象边界

> 本章把前面学到的类型、可空性、函数、集合和 record 组织成清晰对象边界。目标不是背完所有面向对象术语，而是让非法状态难以产生、实现可以替换、实例互不污染，并让泛型合同在 analyzer 与运行时证据中都可解释。本章只写同步代码，不引入 Future。

## 1. 对象不是“把变量塞进 class”

类定义一类对象能够保存什么状态、允许执行什么行为以及创建时必须满足什么条件。对象是类在运行时的实例。字段承载状态，方法表达由对象负责的行为，构造器建立初始合法状态。

```dart
class WorkOrder {
  final String id;
  final String title;
  final int priority;

  WorkOrder({
    required this.id,
    required this.title,
    required this.priority,
  });
}

final first = WorkOrder(id: 'WO-101', title: '空压机异响', priority: 5);
final second = WorkOrder(id: 'WO-102', title: '照明故障', priority: 2);
```

`first` 与 `second` 是两个对象，各自持有实例字段。类不应该成为全局变量的包装。如果把当前工单放进 `static WorkOrder? current`，所有实例和页面会共享同一份状态，测试之间也会互相污染。静态成员属于类本身，适合纯常量、无实例状态的工具行为或受控缓存；它不是“省略 new”的默认方案。

一个好的对象边界回答三件事：谁负责验证输入；哪些字段创建后不可改变；状态改变必须经过哪些方法。若调用者能任意写 `priority = -100`，类虽然存在，却没有保护任何业务不变量。

## 2. 构造器与初始化顺序

普通生成式构造器创建新实例。`this.id` 是初始化形式参数，把同名参数直接赋给字段。命名参数配合 `required` 让调用点可读，也让遗漏参数在静态分析阶段暴露。

```dart
class DeviceId {
  final String value;

  DeviceId(String raw) : value = raw.trim() {
    if (!value.startsWith('DEV-')) {
      throw FormatException('device id must start with DEV-');
    }
  }
}
```

初始化列表在构造器体之前执行，适合设置 final 字段和计算派生值。其右侧不能读取 `this`。`assert` 可用于开发期内部假设，但生产构建可能不执行断言，因此不能把用户输入或关键业务不变量只放在 assert 中。需要始终执行的校验应使用显式条件并产生稳定失败。

命名构造器表达不同的合法创建路径：

```dart
class Priority {
  final int value;

  Priority._(this.value);

  factory Priority.normal(int value) {
    if (value < 1 || value > 3) {
      throw RangeError.range(value, 1, 3, 'value');
    }
    return Priority._(value);
  }

  factory Priority.urgent(int value) {
    if (value < 4 || value > 5) {
      throw RangeError.range(value, 4, 5, 'value');
    }
    return Priority._(value);
  }
}
```

factory 构造器不保证每次创建当前类的新实例；它可以先做复杂校验、返回缓存或返回子类型，但不能返回 null，也不能用 `this` 访问尚不存在的实例。若只是简单字段赋值，用生成式构造器更直接。

## 3. const、final 与不可变值对象

所有实例字段均为 final，且构造表达式可在编译期求值时，可以声明 const 构造器：

```dart
class Coordinates {
  final double latitude;
  final double longitude;

  const Coordinates(this.latitude, this.longitude);
}

const a = Coordinates(31.23, 121.47);
const b = Coordinates(31.23, 121.47);
print(identical(a, b)); // 常量规范化场景可为 true
```

const 表示编译期常量上下文，final 表示变量只能赋值一次。两者都不自动深度冻结字段引用的可变集合：

```dart
class TicketBatch {
  final List<String> ids;
  TicketBatch(List<String> source) : ids = List.unmodifiable(source);
}
```

这里复制并返回不可修改视图，阻止调用者直接修改批次。若元素是可变对象，仍要明确深层所有权。值对象应小、不可变、在构造时合法，并实现与业务身份一致的相等语义；本章资产用字段断言验证，不依赖第三方代码生成包。

## 4. 封装与 library-private

Dart 没有 Java 式 `private` 关键字。以下划线开头的名字在 library 级私有，不只是 class 私有。同一 library 中的其他声明可以访问，另一个 library 不能直接访问。

```dart
class MeterReading {
  int _value;

  MeterReading(int initial) : _value = initial {
    if (initial < 0) throw ArgumentError.value(initial, 'initial');
  }

  int get value => _value;

  void increaseBy(int delta) {
    if (delta <= 0) throw ArgumentError.value(delta, 'delta');
    _value += delta;
  }
}
```

getter 不是为了给每个字段机械生成读取函数，而是为了只暴露必要信息或派生值。setter 很容易让不变量分散；涉及校验或状态机时，优先使用有业务名称的方法，例如 `assignTo`、`increaseBy`。方法调用点应说明意图，不能让对象退化成可随意修改的数据袋。

封装的边界也包括集合。返回 `_items` 会把内部列表交给外界；返回 `List.unmodifiable(_items)` 或不可变快照才能保护所有权。每次创建快照有成本，是否缓存需要真实性能证据。

## 5. 隐式接口与 abstract interface class

Dart 每个类都隐式定义一个接口。`implements` 表示只采用成员合同，不继承实现；实现类必须实现接口要求的全部实例成员。对 repository 这类替换边界，明确写 `abstract interface class` 能表达“外部可以实现，但不应继承我的实现”。class modifiers 除 abstract 外要求 Dart 3.0 以上。

```dart
abstract interface class WorkOrderRepository {
  WorkOrder? findById(String id);
  void save(WorkOrder order);
}

final class MemoryWorkOrderRepository implements WorkOrderRepository {
  final Map<String, WorkOrder> _byId = {};

  @override
  WorkOrder? findById(String id) => _byId[id];

  @override
  void save(WorkOrder order) {
    _byId[order.id] = order;
  }
}
```

测试替身可以实现同一接口；用例只依赖 `WorkOrderRepository`，不依赖 Map 或数据库细节。替换实现后仍应保持：找不到返回 null；保存后可按相同 ID 读取；传入对象不会被偷偷修改。类型能证明成员存在，不能证明语义一致，所以要做 substitution case 测试。

不要为每个类都创建 `IWorkOrder` 接口。只有存在真实替换边界、跨层合同或需要隔离外部系统时，接口才提供价值。一个只有单实现且不会跨边界的内部计算器，直接用类或函数更清楚。

## 6. extends 与继承合同

`extends` 创建子类并继承父类实现。Dart 是单继承，一个类只有一个直接父类，但可以组合多个 mixin。子类可以 override 方法、getter、setter；`@override` 让意图和 analyzer 检查更清晰。

```dart
abstract class NotificationChannel {
  String format(String message) => '[FactoryCare] $message';
  void send(String message);
}

final class ConsoleChannel extends NotificationChannel {
  @override
  void send(String message) {
    print(format(message));
  }
}
```

继承要求“子类是父类，并能在所有父类使用位置保持合同”。如果 `EmergencyWorkOrder` 为复用字段而继承 `WorkOrder`，但它改变 priority 规则、保存方式和生命周期，调用者可能被破坏。不要把“代码长得像”当 is-a。

父类构造器不会自动全部继承。子类需通过 `super(...)` 或 super parameters 把必需参数传给父类。override 不应收窄可接受输入或改变错误语义，否则静态签名相容也可能违反替换原则。

## 7. 组合通常比继承更适合业务能力

组合表示对象“拥有并委托给”另一个对象：

```dart
abstract interface class PriorityPolicy {
  bool isUrgent(int priority);
}

final class DefaultPriorityPolicy implements PriorityPolicy {
  @override
  bool isUrgent(int priority) => priority >= 4;
}

final class WorkOrderService {
  final WorkOrderRepository repository;
  final PriorityPolicy priorityPolicy;

  WorkOrderService(this.repository, this.priorityPolicy);

  bool isUrgent(String id) {
    final order = repository.findById(id);
    return order != null && priorityPolicy.isUrgent(order.priority);
  }
}
```

策略对象可独立替换，服务不需要成为 repository 或 policy 的子类。组合让依赖在构造器中可见，避免深继承层级把状态与副作用藏在父类。默认选择组合，不等于禁止继承；模板算法、框架协议或稳定真正 is-a 层级仍可用继承。

诊断错误继承时检查：子类是否能替代父类；override 是否保留前置/后置条件；父类可变字段是否被多子类共享理解；测试失败是否来自动态分派而非调用者；改为接口+委托后合同是否更清楚。

## 8. mixin：横向复用一组成员

mixin 用于在多个类层级复用成员实现，通过 `with` 应用。它不是多继承，也不适合隐藏复杂依赖。mixin 不能声明生成式构造器；需要宿主能力时，可以声明抽象成员或使用 `on` 约束。

```dart
mixin AuditStamp {
  String get actorId;

  String auditLine(String action) => '$actorId:$action';
}

final class AssignmentCommand with AuditStamp {
  @override
  final String actorId;
  final String workOrderId;

  AssignmentCommand(this.actorId, this.workOrderId);
}
```

这里 mixin 只提供无副作用格式能力，并明确依赖 `actorId`。如果 mixin 内维护可变静态列表、打开资源或依赖全局 service locator，使用者很难看出所有权。此时更适合注入独立 collaborator。

Dart 3.0 后，普通 class 默认不能随意作为 mixin；需要 `mixin` 或 `mixin class` 明确声明。`mixin class` 同时可构造和混入，但同时受到两类限制。教程基线优先使用简单 `mixin`，只有确实需要双重用途才选择 `mixin class`。

## 9. extension method：静态扩展，不改变原类型

extension 给现有类型增加便捷成员，无需修改原库或创建子类。调用根据接收者静态类型解析；它不是运行时 monkey patch，也不会改变类的真实成员。

```dart
extension WorkOrderIdText on String {
  bool get isWorkOrderId => RegExp(r'^WO-[0-9]+$').hasMatch(this);
}

final id = 'WO-101';
print(id.isWorkOrderId); // true
```

若变量是 `dynamic`，extension 不参与静态解析，调用可能在运行时得到 `NoSuchMethodError`。发生两个同名 extension 冲突时，可以通过 import 控制或显式 extension invocation 解决。extension 应保持轻量、无隐藏副作用；核心业务校验若只藏在一个 String extension 中，调用者很容易绕过，值对象构造器更适合建立强不变量。

extension 适合表现层格式化、不可变小工具和针对泛型集合的可读操作：

```dart
extension NonEmptyList<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
```

## 10. 泛型：让同一合同保留具体类型

`List<E>`、`Map<K, V>` 已经是泛型。自己定义泛型类时，类型参数在使用处被具体类型替换：

```dart
sealed class LoadResult<T extends Object> {
  const LoadResult();
}

final class Loaded<T extends Object> extends LoadResult<T> {
  final T value;
  const Loaded(this.value);
}

final class Missing<T extends Object> extends LoadResult<T> {
  final String key;
  const Missing(this.key);
}
```

`LoadResult<WorkOrder>` 表示成功时一定携带 WorkOrder，而不是 dynamic。`T extends Object` 排除可空类型参数；如果 null 是合法值，应显式把合同设计为允许 `Object?`，不能为了通过编译随意去掉边界。

Dart 泛型是 reified，类型信息在运行时保留，例如 `names is List<String>` 可以成立；这与 Java 常见的类型擦除不同。但 reified 不等于外部数据自动安全，`List<dynamic>` 中的元素仍需边界校验。

## 11. 泛型函数、推断与 bounds

泛型函数把输入与输出类型关联：

```dart
T? findFirst<T>(Iterable<T> values, bool Function(T) predicate) {
  for (final value in values) {
    if (predicate(value)) return value;
  }
  return null;
}
```

调用 `findFirst<int>(...)` 可以显式指定，也可由参数推断。若推断得到 dynamic 或过宽 Object?，不要用 `as` 强压结果，应先检查集合声明、空 literal 和 callback 签名。

bound 限制允许的类型，并让实现能够调用该上界的成员：

```dart
abstract interface class Identified {
  String get id;
}

Map<String, T> indexById<T extends Identified>(Iterable<T> values) {
  return <String, T>{for (final value in values) value.id: value};
}
```

传入不实现 Identified 的类型会在 analyzer 阶段失败。bound 是编译时合同，不会检查两个对象是否错误使用相同 ID；重复键的覆盖规则仍需业务测试。

## 12. 可空类型进入对象模型

字段写 `String?` 表示 null 是对象合法状态的一部分。不要把所有“以后可能有值”的字段都声明可空；先问对象处在哪个生命周期。一个“已分配工单”若 assigneeId 可空，就允许了名称与状态矛盾的对象。

可选方案包括：构造器拒绝非法组合；把状态分成 sealed 子类型；使用明确方法完成状态转换；将未加载 UI 状态放在 view model，而不是污染领域对象。

```dart
final class AssignedOrder {
  final String id;
  final int assigneeId;

  AssignedOrder({required this.id, required this.assigneeId}) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id');
    if (assigneeId <= 0) {
      throw ArgumentError.value(assigneeId, 'assigneeId');
    }
  }
}
```

`late` 不是逃避初始化的万能钥匙。读取尚未赋值的 late 字段会在运行时失败，并把本可在构造时暴露的错误推迟。依赖应尽量通过构造器一次提供。

## 13. FactoryCare 完整同步模型

下面组合不可变对象、接口、泛型结果与内存实现：

```dart
abstract interface class Entity {
  String get id;
}

final class WorkOrder implements Entity {
  @override
  final String id;
  final String title;
  final int priority;

  WorkOrder({required this.id, required String title, required this.priority})
      : title = title.trim() {
    if (!RegExp(r'^WO-[0-9]+$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id');
    }
    if (this.title.isEmpty) throw ArgumentError.value(title, 'title');
    if (priority < 1 || priority > 5) {
      throw RangeError.range(priority, 1, 5, 'priority');
    }
  }
}

abstract interface class Repository<T extends Entity> {
  T? findById(String id);
  void save(T value);
}

final class MemoryRepository<T extends Entity> implements Repository<T> {
  final Map<String, T> _values = {};

  @override
  T? findById(String id) => _values[id];

  @override
  void save(T value) => _values[value.id] = value;
}

LoadResult<T> load<T extends Entity>(Repository<T> repository, String id) {
  final value = repository.findById(id);
  return value == null ? Missing<T>(id) : Loaded<T>(value);
}
```

测试要创建两个 repository 实例，向第一个保存数据后断言第二个仍为空，以捕获误用 static Map。再创建一个遵守相同接口的 fake 实现，验证 `load` 的成功与缺失语义保持一致。

## 14. 对象相等、identity 与集合

默认对象相等通常基于 identity。两个字段完全相同的新 WorkOrder 不一定 `==`。若对象作为 Set 成员或 Map key，需要定义与业务一致的 `==` 与 `hashCode`，两者必须一起维护；可变字段不应参与 hash，否则加入 Set 后再修改会破坏查找。

```dart
final class TechnicianId {
  final int value;
  const TechnicianId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TechnicianId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
```

值相等与实体身份不同。工单实体可能只按 id 表示同一身份，即使标题变化；坐标值对象则所有字段共同决定相等。需要团队明确，不要让 AI 根据字段自动生成后直接接受。

## 15. 三类失败与诊断

可空字段破坏不变量：对象构造成功，但状态组合不合法。首个可信证据通常是构造器合同测试或状态转换测试；若只是随后 UI 出现 null error，证据已经离根因太远。修复应把校验前移，不是到处添加 `!`。

共享静态状态：单独测试通过，整套测试受顺序影响；创建两个实例却读到同一数据。首个可信证据是实例隔离断言。修复为实例字段和显式依赖；若确实需要全局缓存，要定义生命周期、清理与并发边界。

错误继承：子类 override 改变合同。首个可信证据是对接口/父类型运行的 substitution case，而不是只测试具体子类。修复可能是恢复合同，也可能是改用组合并定义两个不同接口。

错误泛型边界：传入不满足上界的类型时 analyzer 直接失败；若使用 raw/dynamic 绕过，则错误推迟到运行时。先看失败阶段，再决定是声明错误还是数据错误。不要用 `as T` 消除警告。

## 16. 版本面与 class modifiers

稳定核心包括类、构造器、封装、extends、implements、泛型与 extension。Dart 3.0 引入/规范了 `base`、`interface`、`final`、`sealed` 等 modifiers，并收紧普通 class 作为 mixin 的行为。`interface class` 允许外部实现但禁止外部继承实现；`base class` 允许继承但禁止外部 implements；`final class` 禁止外部子类型；`sealed class` 的直接子类型限制在同一 library，并支持穷尽分析。

截至 2026-07-24 的 stable 文档基线为 Dart 3.12.2。官方 constructors 页面同时预告 Dart 3.13 的 concise constructors 与 primary constructors；它们不是本章资产基线，也不应由 AI 自动改写进目标 3.12 代码。版本升级前应检查 package language version、analyzer 与 Flutter bundled Dart。

## 17. AI 协作边界

可以让 AI 生成数据类、repository skeleton、mock 与泛型样板，但人必须决定：实体和值对象区别；构造不变量；可空状态含义；类是否真的需要 interface；继承是否满足替换；mixin 是否隐藏状态；extension 是否只提供便捷语法；泛型 bound 是否表达真实能力；集合所有权和相等语义。

审查清单：是否出现公共可变字段；构造器是否允许空 ID、非法 priority；是否用 assert 代替生产校验；是否用 late 推迟必需依赖；是否把 repository 存储声明 static；是否为每个类制造无意义接口；是否以继承复用几行代码；是否用 dynamic/as T 掩盖泛型问题；是否同时实现 == 与 hashCode；是否将可变字段放进 hashCode。

AI 说“符合 SOLID”不是证据。证据包括 analyzer、非法构造测试、两个实例隔离测试、接口替换测试和同一失败修复后的重跑记录。

## 18. 练习、复习与验收

基础练习：写 `DeviceId` 值对象，拒绝空字符串；写 `Repository<T extends Entity>`；写一个内存实现并保存两个 WorkOrder；写 String extension 只负责格式化展示。

综合练习：构建不可变 WorkOrder、PriorityPolicy、repository 接口和 `LoadResult<T>`。要求非法 ID/priority 无法成为对象；两个内存仓库实例隔离；missing 与 loaded 分支可穷尽处理；替换 fake repository 后用例合同不变。

故障练习：把 `_values` 改成 static，运行实例隔离测试并记录失败；恢复实例字段后重跑。再把 `assigneeId` 设为可空却让“已分配”对象接受 null，写红测、前移不变量并转绿。最后尝试把不实现 Entity 的类型传入 MemoryRepository，说明这是 analyzer 阶段而不是测试 assertion。

120 秒复述必须包含：对象边界与构造器不变量；Dart 下划线的 library 私有；implements 与 extends；组合优先的条件；mixin 与 extension 的静态边界；泛型和 bound；static 污染反例；一个不应创建 class 或 interface 的反例。

复习节奏：当天手写构造器；第二天从零写 repository；第七天解释 substitution test；第三十天在 Flutter 数据层指出 entity、DTO、view state 和 repository 的职责差异。

## 19. 本章验证范围与未验证项

example 验证不可变对象、泛型 repository、mixin/extension 与实例隔离；lab 验证非法构造、接口替换和泛型结果；公开 exercise 保留静态共享状态缺陷并预期失败；私有 solution 使用相同判据通过。资产只运行同步 Dart VM/analyzer，不包含 code generation、第三方相等库、数据库、依赖注入框架、Flutter Widget、跨 isolate 或异步 repository。

本机可能使用 Dart 3.9.2 执行兼容语法；未在 Dart 3.12.2 SDK、Flutter AOT、Web 或 iOS/Android 真机上重复运行，因此只能声称稳定语义核对与本地机械验证，不能声称所有目标平台已验证。

## 20. 官方资料

- [Dart Classes](https://dart.dev/language/classes)
- [Dart Constructors](https://dart.dev/language/constructors)
- [Dart Extend a class](https://dart.dev/language/extend)
- [Dart Class modifiers](https://dart.dev/language/class-modifiers)
- [Dart Mixins](https://dart.dev/language/mixins)
- [Dart Extension methods](https://dart.dev/language/extension-methods)
- [Dart Generics](https://dart.dev/language/generics)

资料核对日期：2026-07-24。稳定基线以官方 Dart 3.12.2 文档为准；Dart 3.13 及后续语法只记录版本边界，不纳入本章验证。
