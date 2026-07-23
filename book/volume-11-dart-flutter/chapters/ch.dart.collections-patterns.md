---
schema_version: 2
edition: 2026.2-draft
id: ch.dart.collections-patterns
title: List、Map、Set、record、模式与解构
responsibility: 选择 List/Map/Set/record 表达顺序、映射、唯一性与多值结果，并用模式匹配安全解构，不引入类继承。
volume: '11'
order: 4
level: L1-L2
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.dart.collections-patterns.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.dart.control-functions
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
  text: 在 120 秒内解释“List、Map、Set、record、模式与解构”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - dart-collections
  - dart-record-pattern
  covers_topics:
  - dart.list
  - dart.map
  - dart.set
  - dart.collection-literal-spread
  - dart.collection-transform
  - dart.record
  - dart.destructuring-pattern
  - dart.collection-pattern
  - dart.guard-pattern
  - dart.pattern-exhaustiveness
  uses_capabilities: []
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现按技师分组、去重并返回 record 汇总的工单转换函数；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - dart-collections
  - dart-record-pattern
  covers_topics:
  - dart.list
  - dart.map
  - dart.set
  - dart.collection-literal-spread
  - dart.collection-transform
  - dart.record
  - dart.destructuring-pattern
  - dart.collection-pattern
  - dart.guard-pattern
  - dart.pattern-exhaustiveness
  uses_capabilities: []
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: collection-case-table-pattern-match-fixture-equality-check
- id: diagnose
  kind: fault-diagnosis
  text: 面对“集合类型选错、模式遗漏或浅复制后仍共享可变列表”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - dart-collections
  - dart-record-pattern
  covers_topics:
  - dart.list
  - dart.map
  - dart.set
  - dart.collection-literal-spread
  - dart.collection-transform
  - dart.record
  - dart.destructuring-pattern
  - dart.collection-pattern
  - dart.guard-pattern
  - dart.pattern-exhaustiveness
  uses_capabilities: []
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
generated_by: scripts/generate-curriculum.rb
generated_spec_digest: c6ff180935ce499c46eb6e156369370e2e16147be0893d313f446e0a0940cc39
---
# List、Map、Set、record、模式与解构

> 本章只解决“怎样用集合和数据形状表达问题”。List 表达有顺序的多个值，Map 表达键到值的关联，Set 表达唯一性，record 表达固定形状的多值结果，pattern 负责检查并拆开形状。类、继承与异步留给后续章节。

## 1. 先从业务问题选择数据结构

零基础学习者常把所有数据都放进 `List`，因为列表最直观；真正的工程判断却是先问“不变量是什么”。工单时间线要求保持顺序并允许同类事件重复，因此适合 List。通过工单编号定位工单，关注的是键到值的关联，因此适合 Map。统计参与过工单的技师，关注成员是否出现过，适合 Set。一个函数同时返回总数、紧急数和负责人集合，字段固定且只承载数据，可以先用 record。

```dart
final timeline = <String>['CREATED', 'ASSIGNED', 'IN_PROGRESS'];
final titleById = <String, String>{'WO-101': '空压机异响'};
final technicianIds = <int>{7, 7, 9};
final summary = (total: 3, urgent: 1);

print(timeline[0]);              // CREATED
print(titleById['WO-101']);      // String?，这里得到具体值
print(technicianIds.length);     // 2，重复的 7 没有增加成员
print(summary.urgent);           // 1
```

选择口诀不是“List 快、Set 快、Map 快”，而是：顺序与重复用 List；按键定位用 Map；唯一成员用 Set；固定、异构、少量字段的临时结果用 record。复杂业务实体、需要长期演化的公开 API 或拥有行为与不变量的数据，通常应由类承担，不能为了少写一个类而滥用 record。

这四种结构都不自动验证外部 JSON。`Map<String, Object?>` 只是一个宽泛的容器，不代表字段存在、类型正确或业务状态合法。模式能帮助匹配形状，但边界验证仍需明确失败策略。

## 2. List：有序、可重复、按下标访问

List 的第一个下标是 0，最后一个有效下标是 `length - 1`。空列表没有下标 0；直接读取会抛出范围错误。写代码前先分清“空是合法结果”还是“空代表违反合同”。

```dart
final statuses = <String>[];
statuses.add('CREATED');
statuses.addAll(['ASSIGNED', 'IN_PROGRESS']);
statuses[1] = 'ACCEPTED';

for (final status in statuses) {
  print(status);
}
```

`final statuses` 表示变量以后不能指向另一个 List，不代表 List 内容不可变。`statuses.add(...)` 仍然合法。若要暴露只读视图，可以返回 `List.unmodifiable(source)`；若只是 `final copied = source`，两个变量仍引用同一个对象。

```dart
final source = <String>['WO-1'];
final alias = source;
final shallowCopy = [...source];

source.add('WO-2');
print(alias);       // [WO-1, WO-2]，共享同一列表
print(shallowCopy); // [WO-1]，外层列表已复制
```

展开运算符只做浅复制。若元素本身是可变 List、Map 或对象，外层复制后内层仍共享：

```dart
final grouped = <List<String>>[
  ['WO-1'],
];
final copy = [...grouped];
grouped.first.add('WO-2');
print(copy.first); // [WO-1, WO-2]
```

因此“复制过了”必须说清复制层级。需要深复制时，要按数据合同逐层创建新值，或者把内部值设计为不可变对象。JSON 编解码有时看似实现深复制，却会丢失类型、成本更高，也不是通用复制方案。

## 3. List 的转换：不要混淆 Iterable 与 List

`where`、`map` 等转换通常返回惰性 `Iterable`。它们描述如何遍历，而不是立即得到新 List。需要固定快照时调用 `toList()`；希望随后能观察源集合变化时才保留惰性序列，并在接口中明确。

```dart
final priorities = <int>[5, 2, 4];
final urgentView = priorities.where((value) => value >= 4);
final urgentSnapshot = urgentView.toList(growable: false);

priorities.add(5);
print(urgentView.length);     // 3，遍历时重新读取源列表
print(urgentSnapshot.length); // 2，之前保存的快照
```

常见转换包括 `where` 过滤、`map` 映射、`expand` 展平、`fold` 累积、`any` 判断至少一个、`every` 判断全部、`firstWhere` 查找第一个。不要为“一次查询”连续遍历巨量数据而不知成本；也不要先 `where(...).toList()` 再 `map(...)`，如果中间快照没有业务意义，可以在最后再物化。

`firstWhere` 没找到会失败。与其靠异常猜测，不如给出 `orElse` 或写显式循环，让“没有”成为合同的一部分：

```dart
String? firstUrgent(List<(String, int)> orders) {
  for (final (id, priority) in orders) {
    if (priority >= 4) return id;
  }
  return null;
}
```

## 4. Map：键到值的合同

Map 的键应稳定地表示身份或查询条件。读取不存在的键返回 `null`，因此 `map[key]` 的静态类型通常是 `V?`。若 Map 的值本身也允许 null，`map[key] == null` 无法区分“键不存在”和“键存在但值为 null”，需要 `containsKey`。

```dart
final assigneeByOrder = <String, int?>{
  'WO-101': 7,
  'WO-102': null,
};

print(assigneeByOrder['WO-999']);              // null
print(assigneeByOrder['WO-102']);              // null
print(assigneeByOrder.containsKey('WO-102'));  // true
```

用 `putIfAbsent` 可以集中创建分组列表：

```dart
Map<int, List<String>> groupByTechnician(
  List<({String id, int? technicianId})> orders,
) {
  final result = <int, List<String>>{};
  for (final order in orders) {
    final technicianId = order.technicianId;
    if (technicianId == null) continue;
    result.putIfAbsent(technicianId, () => <String>[]).add(order.id);
  }
  return result;
}
```

这里先把可空值提升为局部非空变量，再用它作为 Map 键。分组 Map 返回后仍包含可变 List；若调用者不应修改，应在边界复制并冻结每组。只冻结外层 Map 不能冻结内层 List。

Map literal 中重复键会以后面的值覆盖前面的值。解析配置时，这可能掩盖输入错误；聚合业务数据时，覆盖可能正是“最后值获胜”的规则。无论哪种，都要写成显式合同与测试，不能让语法偶然决定业务。

## 5. Set：唯一性与集合关系

Set 保证按 `==` 与 `hashCode` 判断的成员唯一。字符串、整数等内建值通常符合直觉；自定义类若没有值相等语义，两个字段相同的实例仍可能被视为不同成员，这属于下一章的对象相等问题。

```dart
final seen = <String>{};
for (final id in ['WO-1', 'WO-1', 'WO-2']) {
  seen.add(id);
}
print(seen.length); // 2
```

Set 适合去重、包含判断、交集 `intersection`、并集 `union` 和差集 `difference`。若最终结果还要求确定展示顺序，应在边界排序后转 List，而不是依赖当前实现的迭代顺序来表达业务排序。

```dart
final required = <String>{'camera', 'location'};
final granted = <String>{'camera'};
final missing = required.difference(granted).toList()..sort();
print(missing); // [location]
```

不要用 Set 统计出现次数，因为加入第二次不会保留计数。计数应使用 `Map<T, int>`。反过来，若只需要知道“是否出现过”，Map 的布尔值会制造多余状态。

## 6. 集合字面量、spread、if 与 for

Dart 可以在集合字面量里使用 `...` 展开、`...?` 可空展开以及 collection-if、collection-for。它们适合声明式拼装，避免先建空集合再写多次 `add`。

```dart
List<String> visibleActions({
  required bool canAssign,
  required List<String>? extra,
}) {
  return <String>[
    'view',
    if (canAssign) 'assign',
    ...?extra,
  ];
}

final labels = <String>[
  for (final id in ['WO-1', 'WO-2']) '工单 $id',
];
```

集合控制流应保持短小。若其中同时发生权限判断、网络转换和日志副作用，就抽成命名函数。字面量表达“结果由哪些元素组成”，函数表达“怎样执行复杂流程”。

注意集合字面量也会进行类型推断。空的 `{}` 默认是 Map，而空 Set 应写成 `<String>{}`。这是常见的编译或运行误解：

```dart
final emptyMap = {};       // Map<dynamic, dynamic>
final emptySet = <String>{};
```

工程中优先写出元素类型，尤其在边界、公开 API 和空集合处。`dynamic` 会让错误推迟到运行时，AI 生成代码也常在这里用宽类型掩盖合同缺口。

## 7. record：固定形状的匿名不可变聚合

record 从 Dart 3.0 起可用。它是匿名、固定大小、字段类型可不同的聚合值；字段没有 setter。位置字段通过 `$1`、`$2` 访问，命名字段通过名字访问。record 是结构类型：字段类型与形状决定类型，不靠声明名称建立身份。

```dart
typedef OrderSummary = ({int total, int urgent, Set<int> technicians});

OrderSummary summarize(List<({int priority, int? assigneeId})> orders) {
  var urgent = 0;
  final technicians = <int>{};
  for (final order in orders) {
    if (order.priority >= 4) urgent++;
    final id = order.assigneeId;
    if (id != null) technicians.add(id);
  }
  return (
    total: orders.length,
    urgent: urgent,
    technicians: Set.unmodifiable(technicians),
  );
}
```

record 自身不可变不等于字段指向的对象不可变。如果 record 字段放了可变 List，仍能修改那个 List。上例用 `Set.unmodifiable` 明确输出边界。

位置字段名称不参与类型形状；命名字段名称参与。两个位置 record 即使局部注释叫 point 与 color，只要字段类型序列相同，就可能是同一结构类型。需要防止“两个含义相同形状被误传”时，应该创建类或 extension type，而不是靠 typedef 获得新名义类型。

record 很适合私有函数多返回值、短生命周期查询结果和穷尽模式的载荷；不适合拥有大量方法、需要构造校验、公开多年演化或要序列化为稳定契约的核心实体。

## 8. pattern：匹配形状并解构值

pattern 从 Dart 3.0 起可用。它先判断值是否符合形状，匹配后把内部部分绑定到局部变量。可出现在局部变量声明、赋值、for-in、`if-case` 和 switch 中。

```dart
final result = (total: 8, urgent: 3);
final (:total, :urgent) = result;
print('$total / $urgent');

for (final MapEntry(:key, value: count) in <String, int>{
  'CLOSED': 3,
  'IN_PROGRESS': 2,
}.entries) {
  print('$key=$count');
}
```

变量声明模式是不可反驳位置：右侧必须保证形状匹配，否则运行时会失败或静态分析拒绝。面对未知输入，应使用 `if-case` 或 switch 这样的可反驳位置：

```dart
String readTicketId(Object? input) {
  if (input case {'id': final String id} when id.startsWith('WO-')) {
    return id;
  }
  throw const FormatException('invalid work-order id');
}
```

Map pattern 只要求声明的键匹配，会忽略额外键；缺失被匹配的键会导致该模式不匹配。在直接解构的不可反驳上下文使用 Map pattern 时，缺键可能产生 `StateError`。不要以为模式自动实现完整 schema 校验，也不要忽视值域规则，例如 priority 必须在 1—5。

## 9. list、map、record 与对象 pattern

List pattern 可表达前缀、固定长度以及 rest：

```dart
String describePath(List<String> segments) => switch (segments) {
  ['work-orders', final id] => 'detail:$id',
  ['work-orders', ...final rest] when rest.isNotEmpty => 'nested:${rest.length}',
  [] => 'home',
  _ => 'unknown',
};
```

固定 `[a, b]` 只匹配恰好两个元素。`[first, ...rest]` 才允许更多元素。不要为了“看起来优雅”把复杂解析压成一条巨大 pattern；匹配结构和后续业务校验可以分层完成。

Map pattern 常用于 JSON 第一层分派；record pattern 用于多返回值；对象 pattern 调用 getter 解构类实例。对象 pattern 并不读取私有字段，而是依赖可见 getter。它适合局部控制流，不应让 UI 层借此绕过领域对象提供的行为。

```dart
String summarizePayload(Object? payload) => switch (payload) {
  {'status': final String status, 'count': final int count} when count >= 0
      => '$status:$count',
  {'status': final String _} => 'invalid-count',
  _ => 'invalid-shape',
};
```

## 10. guard 与穷尽性

`when` guard 在 pattern 已匹配后再检查任意布尔条件。guard 为 false 时会继续尝试后续 case，而在 case 体内写 `if` 为 false 通常不会自动尝试下一 case。这是诊断分支遗漏的关键差异。

```dart
String priorityLabel((String, int) order) => switch (order) {
  (final id, >= 4) when id.startsWith('WO-') => 'urgent',
  (final id, >= 1 && <= 3) when id.startsWith('WO-') => 'normal',
  (_, < 1 || > 5) => 'invalid-priority',
  _ => 'invalid-id',
};
```

编译器能对 `bool`、enum、sealed 类型及一些已知联合做穷尽检查；对任意 String 或 Map，通常不能推断所有业务值，所以需要 `_` fallback 或在前面把宽输入转换成封闭类型。`_ => 'unknown'` 能让程序编译，但也可能吞掉新增状态；稳定领域状态应优先 enum/sealed，再让非穷尽 switch 在开发时暴露变更。

穷尽性解决“所有类型形状已覆盖”，不证明每个分支业务正确。仍需输入输出表、边界值和故障注入。

## 11. FactoryCare：分组、去重与 record 汇总

下面把本章概念组合为一个纯函数。输入使用 record，输出同时保留分组和摘要。函数不修改输入，也不引入类继承：

```dart
typedef Ticket = ({String id, int priority, int? technicianId});
typedef TicketReport = ({
  Map<int, List<String>> idsByTechnician,
  Set<String> uniqueIds,
  int urgentCount,
});

TicketReport buildTicketReport(List<Ticket> tickets) {
  final grouped = <int, List<String>>{};
  final uniqueIds = <String>{};
  var urgentCount = 0;

  for (final (:id, :priority, :technicianId) in tickets) {
    uniqueIds.add(id);
    if (priority >= 4) urgentCount++;
    if (technicianId case final int ownerId) {
      grouped.putIfAbsent(ownerId, () => <String>[]).add(id);
    }
  }

  final frozenGroups = <int, List<String>>{
    for (final MapEntry(:key, :value) in grouped.entries)
      key: List.unmodifiable(value),
  };

  return (
    idsByTechnician: Map.unmodifiable(frozenGroups),
    uniqueIds: Set.unmodifiable(uniqueIds),
    urgentCount: urgentCount,
  );
}
```

应验证的表格至少包含：空输入；一个未分配工单；重复 ID；同一技师多单；多个技师；priority 1、4、5 边界。重复 ID 到底只算一次还是仍计为两次紧急工单不是语言能决定的，必须在业务合同中明确。本例只对 `uniqueIds` 去重，`urgentCount` 按输入行统计。

## 12. 三类典型失败与首个可信证据

第一类是集合合同选错：用 Set 保存时间线，重复事件或顺序语义丢失。首个可信证据应是包含重复与顺序的断言，不是肉眼看一组恰好有序的输出。

第二类是模式缺口：switch 没处理新形状。若被匹配类型封闭，analyzer 的非穷尽诊断是首个证据；若输入是宽 Map，则失败样例和 fallback 计数更可信。日志要保存输入形状与分支名称，不能记录敏感原文。

第三类是浅复制误判：外层复制后内层仍共享。最小复现是修改源内层列表，然后断言输出不变。若失败位置在测试断言，说明程序可编译但对象边界不满足；不要把它误报为 analyzer 错误。

诊断顺序固定为：确认失败阶段；读取第一条指向自己代码的错误；缩小输入；判断是结构选择、可空边界、模式覆盖还是共享引用；只改一个规则；重跑原测试与相邻边界；记录仍未验证的排序、规模或外部输入风险。

## 13. 复杂度与性能边界

List 按下标读取通常是常数级，按值搜索通常随元素数增长；Map/Set 的平均查找常为常数级，但依赖哈希与实现，不应承诺最坏情况。排序通常比单次线性遍历更贵。实际性能还受分配、GC、元素相等实现与目标平台影响。

先依据数据合同选结构，再用真实规模测量。把 20 条工单换成 Set 不会带来用户可见收益，却可能破坏顺序。处理几十万条数据时，连续 `where().map().toList()` 产生的迭代和分配才值得基准测试。浏览器、Dart VM、AOT 移动端结果可能不同，本章资产没有做性能基准。

## 14. AI 协作边界

可以让 AI 生成分组循环、case 表或测试骨架，但必须由人回答：输入是否允许重复；顺序是否属于合同；缺键与 null 是否不同；返回集合能否修改；record 是否会成为长期公开 API；fallback 是容错还是掩盖新状态。

审查 AI 集合代码时逐项检查：是否出现裸 `List`/`Map`；空 `{}` 是否被误当 Set；是否不必要使用 `dynamic`；`map[key]!` 是否有证据；复制是否只复制外层；惰性 Iterable 是否逃逸；Map 重复键覆盖是否符合规则；Set 是否意外丢失计数；switch 是否用 `_` 掩盖封闭类型的新分支。

AI 输出“已验证”不算证据。可接受证据是本地 analyzer、可重放命令、包含空/重复/缺失/边界形状的断言与故障修复记录。

## 15. 练习、复习与验收

基础练习：把五个状态放入 List，读取首尾并安全处理空 List；用 Map 统计状态次数；用 Set 得到参与技师；返回 `(total, closed)` record 并解构。

综合练习：独立实现 `buildTicketReport` 的另一版本，要求输入不被修改，输出组不可修改，重复 ID 规则写在函数注释与测试中。测试至少覆盖空、重复、缺失负责人、priority 4 边界和两个技师。

故障练习：先故意返回共享的分组 List，运行失败测试；说明“编译成功不等于对象边界正确”；修复为逐层冻结，再重跑同一命令。然后把 switch 新增一种输入形状，观察 analyzer 或 fallback 测试在哪一阶段给证据。

120 秒复述应包含：四种结构各表达什么；`final List` 与不可变 List 的差别；浅复制的含义；Map 缺键语义；record 的结构类型与浅不可变；pattern 的匹配、解构、guard 和穷尽边界；一个不该用 record 或 pattern 解决的反例。

间隔复习建议：当天不看笔记画选择表；第二天手写分组函数；第七天从失败日志判断是 analyzer、运行时 shape 还是断言失败；第三十天在 Flutter 数据层中指出集合所有权边界。

## 16. 本章验证范围与未验证项

配套 example 验证集合转换、record 解构与边界表；lab 验证 FactoryCare 分组、去重、浅复制隔离；公开 exercise 保留一个错误集合合同并预期失败；私有 solution 用同一判据通过。它们是纯 Dart 同步程序，不代表 Flutter Widget、真实 JSON、网络、数据库、巨量数据性能或跨 isolate 可发送性已验证。

本机运行环境可能仍是 Dart 3.9.2；教材行为依据 2026-07-24 核对的 Dart 3.12.2 stable 官方文档。List/Map/Set 是长期稳定核心；record、patterns 与 class modifiers 要求 Dart 3.0 及以上。Dart 3.13 文档中出现的 concise/primary constructor 不属于本章 stable 可运行基线。

## 17. 官方资料

- [Dart Collections](https://dart.dev/language/collections)
- [Dart Records](https://dart.dev/language/records)
- [Dart Patterns](https://dart.dev/language/patterns)
- [Pattern types](https://dart.dev/language/pattern-types)
- [Dart Generics](https://dart.dev/language/generics)
- [Dart SDK Archive](https://dart.dev/get-dart/archive)

资料核对日期：2026-07-24。官方站点当日声明默认文档对应 Dart 3.12.2；版本号属于会变化的信息，学习或升级前应重新核对 archive 与本机 `dart --version`。
