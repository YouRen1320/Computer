---
schema_version: 2
edition: 2026.2-draft
id: ch.dart.types-null-safety
title: 变量、类型、运算符与空安全
responsibility: 建立 Dart 值、变量、静态类型、类型推断、运算和 sound null safety 模型，不提前使用集合、类或异步。
volume: '11'
order: 2
level: L1
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.dart.types-null-safety.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.dart.toolchain
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
  text: 在 120 秒内解释“变量、类型、运算符与空安全”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - dart-values-types
  - dart-null-operators
  covers_topics:
  - dart.var-final-const
  - dart.builtin-types
  - dart.type-inference
  - dart.runtime-type
  - dart.nullable-nonnullable
  - dart.null-aware-operator
  - dart.late-boundary
  - dart.type-cast-test
  - dart.operator-precedence
  uses_capabilities:
  - foundation.shell-command-stream
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“变量、类型、运算符与空安全”构建可运行程序与测试：建立覆盖推断、显式类型、nullable、late 与类型检查的正负样例矩阵；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - dart-values-types
  - dart-null-operators
  covers_topics:
  - dart.var-final-const
  - dart.builtin-types
  - dart.type-inference
  - dart.runtime-type
  - dart.nullable-nonnullable
  - dart.null-aware-operator
  - dart.late-boundary
  - dart.type-cast-test
  - dart.operator-precedence
  uses_capabilities:
  - foundation.shell-command-stream
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: analyzer-fixture-value-table-runtime-contrast
- id: diagnose
  kind: fault-diagnosis
  text: 面对“滥用 !、late 未初始化或错误类型转换造成的编译/运行失败”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - dart-values-types
  - dart-null-operators
  covers_topics:
  - dart.var-final-const
  - dart.builtin-types
  - dart.type-inference
  - dart.runtime-type
  - dart.nullable-nonnullable
  - dart.null-aware-operator
  - dart.late-boundary
  - dart.type-cast-test
  - dart.operator-precedence
  uses_capabilities:
  - foundation.shell-command-stream
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 变量、类型、运算符与空安全

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Dart SDK、CLI、pubspec 与包工具》](ch.dart.toolchain.md)：类型实验必须在已锁定 SDK、分析器和可运行入口中得到可复现诊断。
<!-- END GENERATED LEARNING PREREQUISITES -->

程序要处理值：数量是 `3`，单价分是 `1999`，状态是 `'IN_PROGRESS'`，设备是否在线是 `true`，处理人可能尚未分配。变量给这些值命名，类型限定值可以怎样使用，运算符把值组合成新值，空安全则要求我们明确回答“这里能否没有值”。

本章只建立这一层模型。集合、用户自定义类、异步和 Flutter 都暂不进入；否则初学者会把“值是什么”“值是否存在”“对象怎样建模”“异步何时完成”混成一个问题。示例全部是同步的纯 Dart 标量实验，并用 analyzer 与运行结果区分静态错误和运行时错误。

## 1. 值、变量、表达式与语句

### 1.1 值是计算结果

字面量可以直接写出值：

```dart
1999
3.5
'WO-1001'
true
null
```

表达式会求值得到另一个值：

```dart
1999 * 3
'WO-' + '1001'
priority >= 4
assigneeName ?? 'UNASSIGNED'
```

声明和赋值等结构组成语句：

```dart
final totalCents = 1999 * 3;
```

右侧表达式先求值得到 `5997`，左侧声明一个变量并把该值关联给它。分号结束语句。把表达式、变量和值分开，才能解释“变量类型不变但变量保存的值改变”或“表达式返回 nullable 值”。

### 1.2 Dart 变量保存引用

Dart 官方文档用“变量保存引用”描述变量。每个值都是对象，但本章暂不展开类层次。对标量入门，可以先理解为：变量是一个有名称、有静态类型的槽位，槽位当前引用某个值。类型决定编译器允许哪些操作，修饰符决定这个槽位能否再次指向别的值。

变量名不是值本身，类型也不是运行时值。下面三个概念要分开：

```text
变量名 quantity ──静态类型 int──> 当前值 3 ──运行时类型 int
```

静态类型来自声明与推断，用于 analyzer；运行时类型是实际对象的类型，可通过 `runtimeType` 观察，但不应成为主要业务分支依据。

## 2. `var`、显式类型、`final` 与 `const`

### 2.1 `var` 是类型推断，不是“随便变类型”

```dart
var quantity = 3;
quantity = 4;       // 合法：仍然是 int
// quantity = '4';  // 静态错误：String 不能赋给 int
```

编译器从初始值推断 `quantity` 为 `int`。变量可以重新赋值，但新值必须符合静态类型。它不像 JavaScript 的 `let` 那样可从 number 改成 string，也不等于 Dart 的 `dynamic`。

局部变量在类型清楚时常用 `var`，减少重复：

```dart
var status = 'CREATED'; // 推断为 String
```

公共 API、函数返回和边界模型通常显式写类型更利于读者理解合同，具体风格由 Effective Dart 与项目规则决定。

### 2.2 显式类型把合同写在左侧

```dart
int quantity = 3;
String status = 'CREATED';
bool enabled = true;
double temperature = 36.5;
```

显式类型不会让值“更安全一倍”，它只是把本可推断的信息写出来。当声明的抽象类型比初始值更宽、变量没有立即初始化，或 API 合同需要清晰时，显式类型很重要。

### 2.3 `final`：只能赋值一次，值可在运行时得到

```dart
final unitPriceCents = 1999;
final normalizedStatus = input.trim().toUpperCase();
```

`final` 变量只能完成一次赋值。初始值可以依赖运行时输入，因此不要求编译期已知。对于不需要重新指向别的值的局部变量，优先 `final` 能减少意外修改。

“final 引用不能重赋值”与“它引用的对象一定不可变”不是同一回事。集合与自定义对象是否可变要看其自身 API，后续章节再学。当前只记住：`final` 限制变量槽位的再次赋值。

### 2.4 `const`：编译期常量

```dart
const centsPerYuan = 100;
const maxPriority = 5;
const defaultRetryDelaySeconds = 3;
```

`const` 的值必须能在编译期确定。常量声明本身也是 final；它比“只赋一次”多一层要求。下面不能是 const：

```dart
final currentLabel = readRuntimeInput();
// const currentLabel = readRuntimeInput(); // 编译期无法求值
```

不要为了“性能”把所有值改成 const。先判断它是否是跨运行都不变的定义性常量，再判断是否适合放在当前作用域。

### 2.5 选择表

| 需求 | 建议声明 | 理由 |
| --- | --- | --- |
| 局部值会重新赋同类型值 | `var` 或显式类型 | 允许重赋，类型仍受检查 |
| 局部值只在运行时确定一次 | `final` | 防止再次赋值 |
| 值在编译期确定且是常量 | `const` | 编译期常量合同 |
| 需要比初始值更宽的静态合同 | 显式类型 | 推断可能过窄 |
| 想绕过静态检查 | 不要默认用 `dynamic` | 先用精确类型、`Object` 或 `Object?` |

## 3. 本章需要的内置类型

Dart 对数字、字符串、布尔和 null 等有语言级支持。集合、record、Function 等也是内置类型的重要部分，但留到各自章节。

### 3.1 `int`、`double` 与 `num`

```dart
int quantity = 3;
double temperature = 36.5;
num measurement = 3;
measurement = 3.5;
```

`int` 表示整数，`double` 表示双精度浮点数，二者都是 `num` 的子类型。`num` 可保存两类数字，但会失去部分只属于 `int` 或 `double` 的特定操作，不能因为“更通用”就到处使用。

算术注意：

```dart
final exactDivision = 10 / 3;   // double，约 3.333...
final integerDivision = 10 ~/ 3; // int，结果 3
final remainder = 10 % 3;       // 1
```

金额不要用 `double` 表示分币总额。FactoryCare 工单费用示例用整数“分”，避免二进制浮点对十进制金额的舍入问题。真正的财务舍入、溢出和大数策略需单独设计，不能仅凭本章小整数实验推出生产安全。

### 3.2 数字平台边界

官方文档说明，原生平台的 `int` 与 Web 编译目标存在表示范围差异；Web 中精确整数通常受 JavaScript 安全整数范围约束。一个 macOS VM 上的超大整数实验不能证明 Web 行为相同。涉及设备计数和分币通常远低于边界，但 ID 若超过安全范围应作为字符串或由合同明确表示。

### 3.3 `String`

```dart
final orderId = 'WO-1001';
final status = "IN_PROGRESS";
final label = '$orderId:$status';
final detail = 'priority=${2 + 3}';
```

`$name` 插入标识符，`${expression}` 插入表达式。字符串的 `length` 基于 UTF-16 code units，不等于用户看到的字素数量；中文、emoji 等显示长度问题要用字符处理能力，不能拿 `length` 直接限制“可见字符数”。

解析外部输入可能失败：

```dart
final quantity = int.parse('3');
final maybeQuantity = int.tryParse('three'); // null
```

`parse` 对无效文本抛异常，`tryParse` 返回 nullable。选择取决于边界合同：无效输入是程序错误还是可恢复用户输入。

### 3.4 `bool`

```dart
bool enabled = true;
bool urgent = priority >= 4;
```

Dart 的 `if` 条件必须是 `bool`，不会把空字符串、0、对象自动转真/假。来自 JavaScript 的开发者尤其要改掉“truthy/falsy”直觉：

```dart
// if (1) {}        // 错：int 不是 bool
// if ('ready') {}  // 错：String 不是 bool
```

`bool?` 也不能直接作为条件，因为它还可能是 `null`。必须明确比较或提供默认值，例如 `if (enabled ?? false)`。

### 3.5 `Object`、`Object?` 与 `dynamic`

`Object` 能引用所有非 null Dart 对象，`Object?` 也允许 null。它们保留静态检查：调用某操作前要做类型测试。`dynamic` 会让许多成员检查推迟到运行时，错误可能远离输入点：

```dart
Object raw = '4';
if (raw is String) {
  print(raw.length); // 已提升为 String
}

dynamic unchecked = '4';
// unchecked.nonExistingMethod(); // 分析可能放过，运行时失败
```

处理未知输入时默认从 `Object?` 开始，验证后再进入精确类型；不要用 `dynamic` 假装已经解析。

## 4. 静态类型、推断与 `runtimeType`

### 4.1 静态类型决定可调用能力

```dart
num value = 3;
```

实际对象运行时是 `int`，但变量静态类型是 `num`。编译器只允许 `num` 合同保证的成员，除非通过控制流证明更窄类型。静态类型是代码审查和 analyzer 的主要依据。

### 4.2 推断发生后不会随赋值漂移

```dart
var code = 200; // int
code = 201;
// code = '201'; // 静态错误
```

如果确实要容纳多个类型，应声明真实的上层合同或使用后续的 sealed/联合建模思路，而不是先 `dynamic` 再到处猜。

### 4.3 `runtimeType` 是观察工具，不是领域设计

```dart
print(value.runtimeType);
```

它适合教学、日志和诊断，但生产业务不应靠字符串比较 `runtimeType.toString()`。编译器、平台和混淆可能影响表示；类型分支应使用 `is`，数据边界应解析成明确模型。

### 4.4 一张正样例值表

| 声明 | 静态类型 | 当前值 | 可否重赋 | 是否可为 null |
| --- | --- | --- | --- | --- |
| `var quantity = 3` | `int` | `3` | 可以，仍须 int | 否 |
| `final status = 'CREATED'` | `String` | 字符串 | 否 | 否 |
| `const maxPriority = 5` | `int` | `5` | 否 | 否 |
| `String? assignee` | `String?` | 默认/当前可为 null | 取决于修饰符 | 是 |
| `Object raw = 4` | `Object` | 运行时 int | 取决于修饰符 | 否 |

每行都应能用 analyzer 和运行输出验证，而不是只凭解释。

## 5. sound null safety 的核心模型

### 5.1 非空类型默认不包含 `null`

```dart
String status = 'CREATED';
// status = null; // 静态错误
```

`String` 的合同是不允许 null。要表示“尚未分配”，必须写：

```dart
String? assigneeName;
```

问号不是注释，而是类型的一部分。`String` 与 `String?` 是不同的静态类型；后者的值集合多出 null。

### 5.2 为什么叫 sound

在 sound null safety 下，如果一个表达式静态类型为非 nullable `String`，编译器可以假设它不是 null；潜在空引用尽量在分析期暴露。前提是代码和依赖都遵守对应语言模式。现代 Dart 3 只支持 null-safe 代码，但 `!`、`late`、错误 cast 和外部边界仍能把风险推迟到运行时。

### 5.3 必须先初始化再读取

```dart
String status;
status = 'CREATED';
print(status);
```

局部变量可以先声明后赋值，只要控制流分析能证明每条到达读取点的路径都已赋值。若某个分支可能未赋值，分析器拒绝读取：

```dart
String label;
if (urgent) {
  label = 'URGENT';
}
// print(label); // urgent 为 false 时未赋值
```

解决方法是覆盖所有路径、给初始值或重新建模，不是盲目加 `late`。

## 6. 控制流提升：验证后使用更窄类型

```dart
Object? rawPriority = 4;

if (rawPriority is int) {
  print(rawPriority + 1);
}
```

在 `if` 块中，分析器根据 `is int` 把局部变量提升为 `int`。同样，排除 null 后 nullable 可提升：

```dart
String? assigneeName = readName();
if (assigneeName != null) {
  print(assigneeName.toUpperCase());
}
```

提升依赖编译器能证明值在期间没有被未知代码改变。复杂字段、可重写 getter、闭包修改等会影响提升，不能把局部变量实验机械推广到所有成员。遇到“为什么未提升”，阅读 analyzer 诊断并把不稳定读取保存为局部 final，或重构边界，而不是马上用 `!`。

### 6.1 提前返回也能提升

```dart
String normalize(String? input) {
  if (input == null) return 'UNKNOWN';
  return input.trim().toUpperCase();
}
```

第二个 return 可达时，`input == null` 路径已经返回，因此剩余路径上 `input` 是 `String`。这是控制流分析，而非变量被永久改成另一类型。

## 7. 空感知运算符表达业务缺省

### 7.1 `?.`：接收者非空时才访问

```dart
final normalized = assigneeName?.trim().toUpperCase();
```

若 `assigneeName` 为 null，整条空感知链得到 null；否则执行后续成员。结果仍可能为空，因此类型通常是 `String?`。

### 7.2 `??`：左侧为空才使用右侧

```dart
final label = assigneeName?.trim().toUpperCase() ?? 'UNASSIGNED';
```

左侧非空时保留结果，左侧为空时使用明确默认值。右侧会按需求值，适合把“未分配”映射为领域标签。不要把所有未知都变为空字符串；空字符串和无值可能是不同业务状态。

### 7.3 `??=`：仅在当前为空时赋值

```dart
String? cachedLabel;
cachedLabel ??= 'UNASSIGNED';
```

它是赋值操作，只有左侧为 null 时写入。若状态是否已加载具有独立含义，用 nullable 兼任缓存标志可能不够，后续应建模明确状态。

### 7.4 条件访问不等于异常处理

`?.` 只处理接收者为 null，不吞掉 `trim()` 或 getter 内可能抛出的其他异常。也不能把网络失败、权限失败都表示为 null。空值的业务含义必须在边界明确。

## 8. `!`：把证明责任从编译器转给程序员

```dart
final upper = assigneeName!.toUpperCase();
```

后缀 `!` 表示“我保证这里非空”。它不会检查数据来源，也不会提供默认值；若运行时为 null，会抛错。它相当于一个运行时检查点，丢失了部分静态安全。

合理使用场景非常窄：外部框架合同确实保证非空但分析器无法表达，且你在紧邻位置有可审计证据。即便如此，也应写明保证来自哪里并覆盖失败测试。以下情况不该用：

- 为了消除红线而加；
- API 响应字段可能缺失；
- 页面生命周期“通常”已经初始化；
- 某个 if 在很远处检查过，但值可能变化；
- AI 推断“调用顺序一定如此”。

优先方案是显式检查、提前返回、`?.`/`??`、构造时建立不变量，或把状态分成明确类型。

## 9. `late`：延迟初始化但保留非空类型

### 9.1 基本语义

```dart
late String startupToken;

void initialize() {
  startupToken = 'ready';
}
```

`late` 告诉分析器：变量稍后初始化，读取时由运行时检查是否已赋值。静态类型仍是非 nullable `String`，但“读取前已初始化”的证明被推迟。

### 9.2 赋值前读取会怎样

```dart
late String status;

void main() {
  print(status);
}
```

这段代码可能通过静态分析，却在运行时抛 `LateInitializationError`。因此 `dart analyze` 绿色不等于 late 生命周期正确；必须运行覆盖读取顺序。

### 9.3 `late final`

```dart
late final String token;
token = 'first';
// token = 'second'; // 第二次赋值在相应场景失败
```

它适合“稍后才知道，但只允许设置一次”。不要用它隐藏本应由构造器或函数参数提供的必需值。Flutter 生命周期中常见 `late`，但是否安全取决于 init/dispose 和读取顺序，留到对应章节验证。

### 9.4 `late` 与 nullable 不是替代关系

- “业务上允许没有处理人”应是 `String?`；
- “业务上必有值，只是初始化时点较晚”才可能是 `late String`；
- “可能未加载、加载失败、已加载空值”通常需要更丰富状态，而不是一个 nullable。

选错会让合法缺失变异常，或让生命周期缺陷变成沉默的 null。

## 10. 类型测试、否定测试与转换

### 10.1 `is` 与 `is!`

```dart
Object raw = 4;
if (raw is int) {
  print(raw + 1);
}

if (raw is! String) {
  print('not a string');
}
```

`is` 是运行时类型测试，并帮助静态提升。它适用于接收 `Object?` 的边界分流。大量 `is` 链可能说明模型不清，后续可用 sealed 类型和模式改善。

### 10.2 `as` 是受检查转换，不是数据解析

```dart
Object raw = 4;
final priority = raw as int;
```

若实际值不是 int，运行时转换失败。`'4' as int` 不会解析字符串；要用 `int.parse` 或 `tryParse`。HTTP JSON 的未知值也不能只靠 `as Map...` 获得真实校验；运行时 Schema/手工解析属于边界设计。

### 10.3 先测再用通常比盲转更清楚

```dart
int? parsePriority(Object? raw) {
  if (raw is int) return raw;
  if (raw is String) return int.tryParse(raw);
  return null;
}
```

这里返回 `int?` 表示输入可能无法解析。是否允许字符串数字是 API 合同决策；不能由 AI 为“方便”自动宽松处理。

## 11. 运算符与优先级

### 11.1 常用分组

| 类别 | 示例 | 结果 |
| --- | --- | --- |
| 算术 | `+ - * / ~/ %` | 数值 |
| 比较 | `< <= > >=` | bool |
| 相等 | `== !=` | bool |
| 逻辑 | `! && ||` | bool |
| 类型 | `is is! as` | 测试或转换 |
| 空值 | `??` | 左值或缺省值 |
| 条件 | `condition ? a : b` | 分支表达式值 |
| 赋值 | `= += -= ??=` | 写入变量 |

完整关系以 Dart 语言规范和官方运算符表为准。不要从 JavaScript、Java 或 Python 猜优先级，因为相似符号可能有不同限制。

### 11.2 乘除先于加减

```dart
final a = 2 + 3 * 4;   // 14
final b = (2 + 3) * 4; // 20
```

即使你记得优先级，复杂业务条件也应加括号表达意图。格式化器不会替你判断需求。

### 11.3 `&&` 先于 `||`，并且短路

```dart
final canDispatch = enabled && priority >= 4 || isAdministrator;
```

实际分组相当于：

```dart
final canDispatch = (enabled && priority >= 4) || isAdministrator;
```

若业务要求管理员也必须 enabled，就要写：

```dart
final canDispatch = enabled && (priority >= 4 || isAdministrator);
```

`&&` 左侧为 false 时不求右侧，`||` 左侧为 true 时不求右侧。短路可以保护 nullable 访问：

```dart
if (name != null && name.isNotEmpty) {
  print(name);
}
```

但不要让右侧藏有必须执行的副作用，否则重构条件会改变行为。

### 11.4 `==` 不做 JavaScript 式隐式类型转换

字符串 `'4'` 不会因与整数 4 比较而自动变成数字。边界输入应显式解析。Dart 的 `==` 可以由对象类型定义相等语义，后续类章节再学；标量实验不能推出所有对象都按身份比较。

### 11.5 赋值与比较符号

`=` 是赋值，`==` 是相等比较：

```dart
status = 'CLOSED';
final isClosed = status == 'CLOSED';
```

Dart 的 if 要求 bool，因此很多把赋值误写进条件的错误能被分析器阻止。但仍应阅读诊断，不要仅凭“红线”猜修复。

## 12. 三类失败要按阶段区分

### 12.1 非空变量接收 null：静态分析失败

```dart
void main() {
  String status = null;
  print(status);
}
```

分析器在赋值位置报告不兼容。此时还没进入业务运行，错误类型是编译/静态类型错误，不是 `Failures: 1` 这样的测试断言失败。

### 12.2 late 未初始化：运行时失败

```dart
late String status;
void main() => print(status);
```

声明允许延迟，因此 analyzer 可能通过；第一次读取触发运行时检查并失败。首个可信位置是运行堆栈指向的读取处，同时回看 `late` 声明与初始化合同。

### 12.3 错误 cast：运行时类型失败

```dart
Object rawPriority = '4';
final priority = rawPriority as int;
```

分析器只知道 Object 可能是 int，所以允许受检查转换；运行值实际是 String 时失败。修复可能是 `int.tryParse`、修改输入合同或拒绝输入，不能把 cast 改成 `dynamic` 掩盖。

### 12.4 `!` 在某输入下失败

```dart
String? assignee;
print(assignee!.length);
```

`!` 明确承担运行风险，analyzer 绿色是预期，不是工具漏报。诊断要问“保证来自哪里、哪个输入违反保证”，而不是关闭 null safety。

## 13. FactoryCare 的值与空值合同

工单领域可以先用标量表达：

```dart
final String orderId = 'WO-1001';
final int unitPriceCents = 1999;
final int quantity = 3;
final bool enabled = true;
String? assigneeId;
```

其中 `assigneeId == null` 可以表示“尚未分配”，前提是 API、数据库和 UI 都同意这个含义。不要同时用 null、空字符串、0、`'UNKNOWN'` 表示同一状态。显示层可用 `?? '未分配'`，但保存层仍要保留真实合同。

外部 JSON 中字段缺失、显式 null、错误类型是三种不同输入。Dart 静态声明不能自动验证 JSON；后续网络与模型章节要在边界解析。这里的 `Object?`、`is`、`tryParse` 是理解基础，不是完整 Schema 方案。

金额计算还要考虑乘法溢出、币种、退款、折扣和舍入。`1999 * 3 == 5997` 的绿色断言只证明这个小输入，不证明生产财务规则。

## 14. 正负矩阵与学习资产

本章资产把“会写语法”升级为“能预测失败阶段”：

- `examples/encyclopedia/ch.dart.types-null-safety/`：合法值表，覆盖推断、显式值、nullable、空感知、提升、cast 和优先级；
- `labs/encyclopedia/ch.dart.types-null-safety/`：一个绿色入口和三个临时负样例；
- `exercises/encyclopedia/ch.dart.types-null-safety/`：公开代码故意对 null 使用 `!`，运行预期红；
- `solutions-private/encyclopedia/ch.dart.types-null-safety/`：使用 `?.` 与 `??` 的私有答案。

练习时先填表：

| 样例 | analyzer | run | 首个可信位置 |
| --- | --- | --- | --- |
| null 赋给 String | 失败 | 不应继续 | 赋值表达式 |
| late 赋值前读取 | 通过 | 失败 | 第一次读取与 late 声明 |
| String `as int` | 通过 | 失败 | cast 表达式 |
| nullable 使用 `?. ??` | 通过 | 通过 | 输出断言 |

实际运行后比较预测。若预测错误，记录的是“我混淆了静态与运行阶段”，不是只抄错误文本。

## 15. AI 协作边界

AI 可以帮助生成值表、补充边界输入、解释 analyzer 诊断、比较 `!` 与显式检查的差异。它也可把一段动态代码改成精确类型草案。

学习者必须自己：

- 指出每个变量的静态类型、可空性和可否重赋；
- 在运行前预测是分析失败还是运行失败；
- 解释默认值的业务含义；
- 删除一个 `!` 并用边界测试证明行为；
- 审查 AI 是否用 `dynamic`、`as`、`!` 把不确定性藏起来；
- 说明本机绿色未覆盖哪些平台和 SDK。

不要把真实设备 ID、用户姓名或私有 API 响应直接交给模型。可用合成的 `WO-1001`、`UNASSIGNED` 夹具。AI 写出的类型声明不是运行时数据证据。

## 16. 复习、练习与讲回

### 16.1 快速判断

1. `var x = 1; x = '1';` 为什么失败？
2. `final` 与 `const` 的“只赋一次”和“编译期可知”有何区别？
3. `String` 与 `String?` 的值集合差什么？
4. 为什么 `bool?` 不能直接放进 if？
5. `?.`、`??`、`!` 分别把风险放在哪里？
6. `late` 为什么可能 analyzer 绿、run 红？
7. `as` 为什么不能把字符串数字解析为 int？
8. `Object?` 与 `dynamic` 对静态检查有什么区别？
9. `runtimeType` 为什么不宜用字符串比较做领域分支？
10. `enabled && (urgent || admin)` 去掉括号是否一定保持业务含义？

### 16.2 独立小任务

写一个纯 Dart 入口，包含：

- 一个 `var`、一个运行时 `final`、一个 `const`；
- `int`、`double`、`String`、`bool`；
- 一个 `String?`，分别输入 null 与非空；
- `?.` 和 `??` 的确定输出；
- `Object?` 经 `is` 提升；
- 一个故意失败的 late 或 cast 夹具；
- 格式、分析、运行三段退出证据。

不得用 `dynamic`、无解释的 `!`、集合、类或 async。完成后用 120 秒讲清“静态证明与运行时检查”的分界。

## 17. 稳定核心、版本表面与官方资料

资料核对日期：**2026-07-24**。官方站点当日默认反映 Dart **3.12.2**。本章主要概念——变量推断、`final`/`const`、内置标量、sound null safety、空感知运算、`late`、`is`/`as` 和运算优先级——属于稳定核心。诸如数字分隔符最低语言版本、未来参数修饰符变化等属于版本表面，不作为本章示例依赖。

官方一手资料：

- [Variables](https://dart.dev/language/variables)：变量、推断、final、const 与 null safety；
- [Built-in types](https://dart.dev/language/built-in-types)：数字、字符串、布尔及平台说明；
- [Operators](https://dart.dev/language/operators)：运算符表、类型测试和优先级；
- [Understanding null safety](https://dart.dev/null-safety/understanding-null-safety)：sound 模型、flow analysis、`!` 与 `late`；
- [The Dart type system](https://dart.dev/language/type-system)：静态类型与 soundness；
- [Language versioning](https://dart.dev/language/versioning)：包语言版本如何确定。

**已实际验证**：macOS arm64、Dart 3.9.2 下，本章四类资产的格式、静态分析、绿色值表、null 静态失败、late 运行失败、cast 运行失败和公开练习预期红。**未验证**：Dart 3.12.2 二进制复跑、Dart Web 的大整数边界、AOT/JIT 差异、Flutter Widget 生命周期中的 `late`、外部 JSON Schema、跨 isolate 可见性、生产金额溢出与舍入。这些边界由后续章节或目标平台测试承担。
