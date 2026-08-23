# Dart：类型、空安全、控制流与集合

## 1. Dart 是静态类型语言，也能大量使用类型推断

```dart
var title = 'Motor failure'; // 推断 String
int quantity = 3;
final total = quantity * 1999;
```

变量类型在编译/分析时被检查。`var` 不是 dynamic：初始化后类型已推断，不能随意改成无关类型。

局部变量用推断保持简洁；公共函数、复杂结构和业务边界显式类型更清楚。

## 2. Dart 工具链从 SDK 和 pubspec 开始

常用命令概念：

```text
dart --version
dart create
dart run
dart analyze
dart format
dart test
dart pub get
```

`pubspec.yaml` 声明包名、SDK 约束、依赖和资源；`pubspec.lock` 记录应用解析后的具体依赖。库包与应用对 lockfile 的提交惯例可能不同，按官方和项目规则执行。

工具版本、SDK 约束和 lockfile 共同影响可重复性。

## 3. final 和 const 约束不同时间点

```dart
final now = DateTime.now(); // 运行时赋值一次
const maxRetries = 3;       // 编译时常量
```

`final` 变量只能赋值一次，但对象内容可能可变：

```dart
final items = <String>[];
items.add('WO-42'); // 可以
```

`const` 值必须由常量表达式构造，并可用于创建不可变常量对象。不要为追求 const 把运行时数据硬编码。

## 4. late 表示“稍后初始化”，也带运行时责任

```dart
late final WorkOrderRepository repository;
```

适合生命周期保证稍后赋值、昂贵惰性初始化等。若读取前没有赋值，会在运行时失败；`late` 不是关闭空安全的通用逃生口。

能通过构造器立即注入时优先构造器，初始化顺序更明确。

## 5. dynamic 会关闭相关静态检查

```dart
dynamic value = loadSomething();
value.unknownMethod(); // 分析器不阻止，运行时可能失败
```

若只知道“某个对象”，使用 `Object?`，之后通过模式/类型检查收窄。外部 JSON 常先是 `Object?` 或 `Map<String, Object?>`，不要让 dynamic 从边界扩散到领域层。

## 6. 数字有 int 和 double

```dart
int count = 3;
double temperature = 42.5;
num value = count; // num 是共同上层类型
```

整数除法：

```dart
5 / 2  // 2.5，/ 返回 double
5 ~/ 2 // 2，截断除法
5 % 2  // 1
```

int 的精确范围依运行平台不同：原生与编译到 Web 的边界不完全相同。跨端大型整数/金额要定义合同并按目标验证。

## 7. String 不可变，插值用于清楚拼接

```dart
final label = 'total=$total';
final detail = 'order=${order.id}, status=${order.status}';
```

多次循环拼接可用 `StringBuffer`，避免不断创建中间字符串。

字符串比较按内容 `==`；业务规范化要明确 trim、大小写和 Locale/Unicode 语义，不能假定所有文本都是 ASCII。

## 8. Sound Null Safety 默认不允许 null

```dart
String title = '故障'; // 不能为 null
String? note;          // 可以为 String 或 null
```

非空类型必须在使用前被初始化。分析器根据控制流防止可能 null 的成员访问。

```dart
if (note != null) {
  print(note.length); // 已提升为 String
}
```

空安全把很多潜在运行错误变成编辑/构建阶段错误。

## 9. `?.`、`??` 和 `??=` 分别处理空值

```dart
final length = note?.length;       // null 或长度
final display = note ?? '无备注';  // null 时默认
note ??= '待补充';                 // 仅 null 时赋值
```

它们不验证字符串是否为空白，也不判断业务合法。`null`、`''` 和 `'   '` 仍是三种状态。

## 10. `!` 是运行时非空断言

```dart
print(note!.length);
```

它告诉分析器“这里一定不为空”，实际为 null 会运行时抛错。`!` 不做转换或验证。

优先通过 if、switch pattern、构造器不变量或局部变量让分析器自然提升；只有外部生命周期确实保证但分析器看不到时局部使用。

## 11. required 参数不等于值一定非 null

```dart
void create({required String title}) { ... }
void update({required String? note}) { ... }
```

`required` 表示调用时必须提供命名参数；类型是否允许 null 由 `?` 决定。第二个例子必须传参数，但可以显式传 null。

这很适合区分“字段没传”和“明确清空”。

## 12. 类型提升依赖稳定可证明的值

局部 final/变量检查后通常可提升：

```dart
if (value is String) {
  print(value.length);
}
```

可变 getter 可能每次返回不同值，分析器不一定提升。先保存局部：

```dart
final current = object.maybeValue;
if (current != null) print(current.length);
```

## 13. 运算符与相等要看类型合同

```dart
2 == 2.0 // 数字相等语义需理解
identical(a, b) // 是否同一对象引用的底层身份判断
```

类可重写 `operator ==` 与 `hashCode` 表达值相等。放入 Set/Map key 后，相等与 hashCode 必须一致且相关字段不要随意改变。

`&&`、`||` 短路执行，右侧可能不运行；不要把关键副作用藏在复杂布尔表达式里。

## 14. if/else 适合范围和组合规则

```dart
int calculatePriority(int users, bool stopped) {
  if (users < 0) {
    throw ArgumentError.value(users, 'users');
  }
  if (stopped) return 5;
  if (users >= 100) return 4;
  return 2;
}
```

规则从具体/高优先级到兜底，防止宽条件遮蔽。复杂条件拆成命名方法或布尔值。

## 15. switch 可以是语句，也可以产生值

```dart
final label = switch (status) {
  WorkOrderStatus.open => '待处理',
  WorkOrderStatus.inProgress => '处理中',
  WorkOrderStatus.closed => '已关闭',
};
```

Switch expression 适合有限输入映射，分析器可检查穷尽性。传统 switch statement 用于多步流程，并有 Dart 当前版本相应语义。

状态有限时用 enum/sealed 类型，不用任意 String + default 吞掉新状态。

## 16. for、for-in、while 表达不同循环意图

```dart
for (var i = 0; i < items.length; i++) { ... } // 需要索引
for (final item in items) { ... }               // 只需元素
while (queue.isNotEmpty) { ... }                // 次数未知
```

`break` 结束循环，`continue` 跳过当前轮，`return` 结束函数。批量统计仍需处理剩余数据时，不因找到首个匹配就 break。

## 17. 函数是一等值

```dart
int calculate(int price, int quantity) => price * quantity;

final int Function(int, int) operation = calculate;
```

函数可赋值、传参、返回。回调类型可用 typedef 命名：

```dart
typedef PriorityRule = int Function(WorkOrder order);
```

函数合同应明确空值、异常和副作用。

## 18. Dart 同时支持位置参数和命名参数

```dart
void create(
  String title, {
  required int affectedUsers,
  bool machineStopped = false,
}) {}
```

调用：

```dart
create('电机过热', affectedUsers: 3, machineStopped: true);
```

命名参数适合多个同类型、可选或含义重要的值。可选位置参数用 `[]`，默认值必须是编译时常量。

## 19. 箭头语法只适合一个表达式

```dart
String label(Status status) => status.name;
```

箭头后是表达式并隐式返回。包含多步校验、局部变量和日志时用块函数，不为少几行牺牲清楚错误路径。

## 20. List 是有顺序、可索引集合

```dart
final orders = <WorkOrder>[];
orders.add(order);
final first = orders[0];
```

越界会运行时抛 RangeError。空集合先检查；`firstOrNull` 等能力是否来自当前 SDK/扩展需查询。

```dart
final fixed = List<int>.filled(3, 0);
```

固定长度与可增长 List 行为不同。

## 21. Iterable 操作默认可能是惰性的

```dart
final critical = orders.where((order) => order.priority == 5);
```

`where` 返回 Iterable，通常遍历时才计算。如果源集合后来变化，再遍历可能看到新结果。需要当前快照：

```dart
final criticalList = critical.toList(growable: false);
```

`map` 也是转换；`fold` 累积；`any/every` 判断；`firstWhere` 找元素但无匹配处理需明确。

## 22. Set 保存唯一元素

```dart
final ids = <String>{'WO-1', 'WO-2'};
ids.add('WO-1'); // 大小不增加
```

成员唯一依赖 `==` 和 `hashCode`。可变对象若修改参与 hash 的字段，会破坏查找。

Set 适合成员判断和去重；需要保留业务顺序时确认具体实现/构建方式，不要依赖未声明顺序。

## 23. Map 保存 key 到 value

```dart
final byId = <String, WorkOrder>{
  'WO-42': order,
};

final found = byId['WO-99']; // WorkOrder?，可能不存在
```

索引返回 nullable，因为 key 可能缺失。若 value 本身也允许 null，`map[key] == null` 无法区分缺 key 和存 null，可用 `containsKey`。

动态 JSON Map 不应直接 cast 成领域对象；逐字段解析验证。

## 24. Collection if/for 在字面量中按条件生成元素

```dart
final actions = <String>[
  'view',
  if (canAssign) 'assign',
  for (final tag in tags) 'tag:$tag',
];
```

它适合声明式构建 Widget/配置列表。复杂副作用和多步分支仍放普通代码。

当前 Dart 还支持 null-aware collection elements 等新语法，目标 SDK 约束不足时不可使用，需按项目语言版本复核。

## 25. Spread 把集合展开到新集合

```dart
final all = <String>[...base, ...extra];
final maybe = <String>[...?optionalItems];
```

展开是浅层：元素对象仍共享。`...?` 在源集合为 null 时不添加。

不可变更新可创建新 List，但嵌套对象是否可变仍取决于模型设计。

## 26. Record 是固定形状、异构、不可变的数据组合

```dart
(String, int) parse() => ('WO-42', 5);
({String id, int priority}) summary() => (id: 'WO-42', priority: 5);
```

Record 适合小型局部组合和多返回值，有结构相等性。它没有自定义行为和独立名义身份；稳定业务类型、验证规则和长期 API 更适合 class。

```dart
final (:id, :priority) = summary();
```

通过 pattern 解构。

## 27. Pattern 同时做匹配和解构

```dart
switch (value) {
  case {'id': String id, 'priority': int priority}:
    print('$id $priority');
  default:
    throw const FormatException('invalid payload');
}
```

模式可检查常量、类型、List/Map/Record/Object 形状并绑定变量。它有助于解析结构，但仍要验证范围、未知字段和业务关系。

不要用强制 cast pattern 把不可信数据异常散到深处；边界统一返回清楚解析错误。

## 28. if-case 适合一个局部形状检查

```dart
if (json case {'name': String name, 'age': int age}) {
  // name、age 可用
}
```

多种封闭状态用 switch 更清楚；只有成功/否则的单个形状可用 if-case。

Guard `when` 可补业务条件，但不要在 pattern 中塞大量副作用。

## 29. Enum 表达有限命名状态

```dart
enum WorkOrderStatus { open, assigned, inProgress, closed }
```

Enhanced enum 可包含字段和方法，但状态转换不变量不应只靠 enum label。服务端字符串解析要穷尽映射，未知值明确失败或兼容处理。

不要直接把 enum index 持久化，顺序变化会改变含义；使用稳定字符串/代码。

## 30. 级联 `..` 连续操作同一对象

```dart
final buffer = StringBuffer()
  ..write('WO-42')
  ..write(':')
  ..write('OPEN');
```

Cascade 返回原接收者，适合构建/配置。不要把它误认为每个方法都返回 this，也不要因链短而隐藏复杂可变过程。

## 31. 外部 JSON 的边界

```dart
final Object? raw = jsonDecode(text);
```

随后检查 map/list/字段类型并构建领域对象。`Map<String, dynamic>.from(...)` 和 `as` 可能在不匹配时抛错，但错误位置/信息未必符合业务合同。

解析层负责格式，领域构造负责不变量。不要让 UI 到处访问 `json['field'] as String`。

## 32. 这篇的整体地图

```text
Dart SDK + pubspec 建立可重复项目
  → 静态类型和推断描述值
  → Sound Null Safety 默认排除 null
  → 条件、switch pattern 和循环组织流程
  → 函数用命名/位置参数表达合同
  → List / Set / Map / Record 保存不同关系
  → Pattern 在边界匹配和解构数据
```

必须掌握：var 不是 dynamic；final 不代表对象不可变；`!` 是可能失败的运行时断言；`/` 与 `~/` 不同；Map 索引返回 nullable；Iterable 操作可能惰性；Record 适合小型结构而非所有领域对象；JSON 必须运行时解析。

操作符重载、生成器和高级 pattern 组合属于“需要时查询”。
