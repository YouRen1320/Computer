---
schema_version: 2
edition: 2026.2-draft
id: ch.dart.control-functions
title: 条件、循环、函数、参数与返回值
responsibility: 用分支、模式化 switch、有界循环和函数合同表达同步规则，不在本章引入集合高阶操作或类。
volume: '11'
order: 3
level: L1
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.dart.control-functions.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.dart.types-null-safety
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
  text: 在 120 秒内解释“条件、循环、函数、参数与返回值”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - dart-control-flow
  - dart-function-contract
  covers_topics:
  - dart.if-switch
  - dart.for-while
  - dart.break-continue
  - dart.switch-exhaustiveness
  - dart.function-declaration
  - dart.positional-named-parameter
  - dart.default-required-parameter
  - dart.return-value
  - dart.arrow-function
  uses_capabilities: []
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现含边界分支、循环统计和命名参数的维修优先级函数集；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - dart-control-flow
  - dart-function-contract
  covers_topics:
  - dart.if-switch
  - dart.for-while
  - dart.break-continue
  - dart.switch-exhaustiveness
  - dart.function-declaration
  - dart.positional-named-parameter
  - dart.default-required-parameter
  - dart.return-value
  - dart.arrow-function
  uses_capabilities: []
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: input-output-table-analyzer-fixture-boundary-cases
- id: diagnose
  kind: fault-diagnosis
  text: 面对“非穷尽 switch、可空条件或命名参数误用导致的规则缺口”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - dart-control-flow
  - dart-function-contract
  covers_topics:
  - dart.if-switch
  - dart.for-while
  - dart.break-continue
  - dart.switch-exhaustiveness
  - dart.function-declaration
  - dart.positional-named-parameter
  - dart.default-required-parameter
  - dart.return-value
  - dart.arrow-function
  uses_capabilities: []
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 条件、循环、函数、参数与返回值

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《变量、类型、运算符与空安全》](ch.dart.types-null-safety.md)：条件表达式、参数可空性、默认值和返回类型都依赖已验证的类型与空安全。
<!-- END GENERATED LEARNING PREREQUISITES -->

变量和类型回答“当前有哪些值”；控制流回答“程序下一步执行哪一段”；函数把一段规则变成有名称、有输入、有输出的合同。FactoryCare 中“优先级 4 以上进入紧急派单”“最多重试 3 次”“没有处理人时排队”等规则都要靠这三者表达。

本章只写同步、标量、可终止的规则。不用 List/Map 的高阶操作，不设计类，不引入 Future、Stream 或 Flutter。这样可以先看清每条路径是否覆盖、每次循环是否推进、每个调用者是否遵守参数合同。集合、对象和异步会在后续章节把这些基础组合起来。

## 1. 控制流不是“让代码跑起来”，而是覆盖所有允许路径

把输入域画出来：工单优先级允许 1—5，处理人可用性为 true/false，重试次数不能为负。一个规则至少包含：

```text
输入域 → 有效性守卫 → 业务分支 → 输出
```

只用一个样例 `priority=5` 跑通，不能证明 `0、1、3、4、5、6` 都正确。分支与循环的测试应按等价类和边界建立输入输出表。

## 2. `if`、`else if` 与 `else`

### 2.1 条件必须是 bool

```dart
if (priority >= 4) {
  print('urgent');
}
```

括号内必须求值为 `bool`。Dart 不把 0、空字符串、对象或 null 自动转为真假：

```dart
// if (1) {}          // int 不是 bool
// if ('assigned') {} // String 不是 bool
```

如果变量是 `bool?`，还要决定 null 的业务语义：

```dart
bool? assigneeAvailable;

if (assigneeAvailable ?? false) {
  print('dispatch');
}
```

这里把未知映射为 false 是明确决策，并非 Dart 自动行为。若“未知”应导致错误或独立状态，就不能用默认 false。

### 2.2 多分支按顺序匹配

```dart
String priorityLabel(int priority) {
  if (priority < 1 || priority > 5) {
    return 'INVALID';
  } else if (priority >= 4) {
    return 'URGENT';
  } else if (priority == 3) {
    return 'MEDIUM';
  } else {
    return 'LOW';
  }
}
```

从上到下遇到第一个 true 分支后跳过其余分支。顺序会影响结果：若先写 `priority >= 1`，则 4 和 5 已被更宽条件捕获，永远到不了紧急分支。

### 2.3 守卫子句减少嵌套

```dart
String dispatch(int priority, bool enabled) {
  if (!enabled) return 'DISABLED';
  if (priority < 1 || priority > 5) return 'INVALID';
  if (priority >= 4) return 'URGENT';
  return 'NORMAL';
}
```

先返回无效/特殊情况，让主路径平直。守卫不是越多越好；重复条件或散落返回会难以审计。目标是每个返回都对应可说明的业务类别。

### 2.4 条件表达式用于求值

```dart
final label = priority >= 4 ? 'URGENT' : 'NORMAL';
```

`condition ? a : b` 是表达式，会产生值。适合两条简单分支；多层嵌套三元表达式可读性差，应改成函数或 switch。箭头函数中不能直接写 if 语句，但可以返回条件表达式。

## 3. switch statement 与 switch expression

### 3.1 switch statement 执行动作

```dart
switch (priority) {
  case 1:
  case 2:
    print('LOW');
  case 3:
    print('MEDIUM');
  case 4:
  case 5:
    print('URGENT');
  default:
    print('INVALID');
}
```

现代 Dart switch 不应套用 C/JavaScript 的隐式 fallthrough 心智模型。每个非空 case 有自己的主体；共享行为可以使用逻辑或模式，或按官方允许方式组织空 case。为避免版本与样式歧义，本章函数优先使用 switch expression。

### 3.2 switch expression 返回值

```dart
String priorityBand(int priority) => switch (priority) {
  1 || 2 => 'LOW',
  3 => 'MEDIUM',
  4 || 5 => 'URGENT',
  _ => 'INVALID',
};
```

左边是模式，`=>` 右边是表达式，分支用逗号分隔。`_` 是兜底模式。Switch expression 从 Dart 3.0 起可用，本章基线已高于 3.0。

### 3.3 模式与 guard

switch 可以按值和模式匹配，并可在 case 后使用 `when` 继续约束：

```dart
String scoreBand(int score) => switch (score) {
  final value when value < 0 => 'INVALID',
  final value when value >= 90 => 'A',
  _ => 'OTHER',
};
```

guard 只有模式先匹配后才判断。复杂 guard 若重复业务计算，应先提取命名变量或函数。模式解构的系统用法在集合与模式章节讲解。

### 3.4 穷尽性是编译器帮你检查遗漏

对有限可枚举类型，switch expression 必须覆盖所有可能值：

```dart
String assignedLabel(bool? assigned) => switch (assigned) {
  true => 'ASSIGNED',
  false => 'UNASSIGNED',
  null => 'UNKNOWN',
};
```

若漏掉 null，analyzer 会报告非穷尽 switch。也可以用 `_` 覆盖剩余值，但兜底会隐藏未来新增情况。对 `bool?` 显式列出三种值更能说明合同；对任意 int，通常需要范围守卫或 `_`。

后续 enum、sealed class 更能发挥穷尽检查：新增一个状态后，遗漏的 switch 会在编译期暴露。此处不提前定义类，只掌握“输入域有限时不要随意 default 吞掉变化”。

## 4. 循环的三个问题：起点、继续条件、推进

任何循环都要回答：

1. 初始状态是什么？
2. 什么条件下继续？
3. 每轮怎样向终止靠近？

缺一个就可能零次误执行、越界或无限循环。

## 5. `for`：次数或索引边界明确

### 5.1 经典 for

```dart
var urgentCount = 0;

for (var index = 0; index < totalWindows; index++) {
  if (index >= firstUrgentAt) {
    urgentCount++;
  }
}
```

三个区域分别是初始化 `index = 0`、继续条件 `index < totalWindows`、每轮更新 `index++`。若 totalWindows 为 0，循环体执行零次。这是正确边界，不需要特殊 if。

### 5.2 `<` 与 `<=` 的 off-by-one

当要访问编号 `0..total-1` 时用 `< total`；用 `<= total` 会多执行一次。若业务编号是 1..5，也可以：

```dart
for (var priority = 1; priority <= 5; priority++) {
  print(priority);
}
```

不要死记某个符号，要先写允许区间。测试零次、一次、多次和最后边界。

### 5.3 进度不变量

若条件是 `index < total`，更新必须使 index 最终不再满足条件。误写 `index--` 或在某分支跳过更新会无限循环。经典 for 的更新区统一执行，通常比手写多个分支增量更安全。

### 5.4 for-in 留到集合章节展开

Dart 支持对 Iterable 使用 `for (final item in items)`，但本章不教授 List/Map/Set。此处只知道它也是循环；选择集合与迭代协议在下一章建立后再用。

## 6. `while`：次数未知，但继续条件清楚

```dart
int consumeRetryBudget(int requested, {int hardLimit = 3}) {
  var attempts = 0;
  while (attempts < requested && attempts < hardLimit) {
    attempts++;
  }
  return attempts;
}
```

while 先判断条件，所以 requested 为 0 时执行零次。每轮 `attempts++` 同时推进两个条件。生产重试还涉及延迟、异常分类、取消、幂等和异步，本章这个同步计数函数只演示边界，绝不代表真实网络重试实现。

### 6.1 无限循环必须有外部终止合同

```dart
while (true) {
  if (shutdownRequested) break;
  processOneStep();
}
```

这种循环依赖 break 条件。学习例子不能只说“最终会关闭”；应可控注入 shutdown，设置最大步数或使用测试夹具。UI 主线程中忙等会冻结界面，异步事件循环另章讲解。

## 7. `do-while`：至少执行一次

```dart
var runs = 0;
do {
  runs++;
} while (runs < requested);
```

条件在循环体后判断，因此即使 requested 为 0，runs 也成为 1。它适合“先执行再判断是否继续”的合同。若业务允许零次，误用 do-while 就是逻辑错误，analyzer 通常无法知道。

对同一需求分别写 while 和 do-while，先预测输入 0、1、3 的输出，是理解差异的最小实验。

## 8. `break` 与 `continue`

### 8.1 `break` 终止当前循环

```dart
var attempts = 0;
while (attempts < requested) {
  if (attempts == hardLimit) break;
  attempts++;
}
```

它跳到循环之后。break 太多会让终止条件分散，难以证明循环有界；能把上限写入 while 条件时通常更清楚。

### 8.2 `continue` 跳过本轮剩余部分

```dart
for (var index = 0; index < totalWindows; index++) {
  if (index < firstUrgentAt) continue;
  urgentCount++;
}
```

continue 不会退出循环，只进入下一轮。经典 for 仍会执行更新表达式；手写 while 若在 `continue` 前没推进变量，可能无限循环：

```dart
var i = 0;
while (i < 3) {
  if (i == 1) continue; // 错：i 永远是 1
  i++;
}
```

修复不是随意移动一行，而是确保每条继续路径都推进状态。

### 8.3 标签是高级控制工具

Dart 支持给循环加 label，并用 `break label` 或 `continue label` 控制外层循环。嵌套搜索可能使用，但容易增加理解成本。本章只要求知道语法存在；优先提取函数、返回结果或重构循环。若使用标签，要测试命中/未命中和外层推进。

## 9. 函数声明是一份可执行合同

```dart
String priorityBand(int priority) {
  if (priority >= 4) return 'URGENT';
  return 'NORMAL';
}
```

从左到右：

- `String`：返回类型；
- `priorityBand`：函数名；
- `(int priority)`：一个必填位置参数；
- `{ ... }`：函数体；
- `return`：结束本次调用并交回 String 值。

调用：

```dart
final label = priorityBand(4);
```

调用者必须提供一个可赋给 int 的实参，返回值静态类型为 String。函数名应描述结果或动作，不要写 `handleData`、`doThing` 让合同只能靠读实现猜。

### 9.1 `main()` 是应用入口

```dart
void main() {
  print('hello');
}
```

顶层 main 是 Dart 应用入口，可选接收 `List<String>` 命令行参数；集合在下一章学习，本章入口不处理参数。`void` 表示调用者不使用返回值。

### 9.2 返回类型不要省略公共合同

Dart 能推断某些返回类型，但公开函数显式写返回类型便于审查：

```dart
int totalCents(int unitPriceCents, int quantity) {
  return unitPriceCents * quantity;
}
```

若所有路径没有返回 int，analyzer 会定位缺口。不要把返回类型改成 dynamic 来绕过。

### 9.3 一个函数一个职责

`classifyPriority` 只分类，`countAttempts` 只计数。若函数同时请求网络、改全局状态、格式化 UI、吞异常，就难以用输入输出表验证。纯函数不是所有代码的唯一形式，但学习业务规则时优先纯函数可降低噪声。

## 10. 位置参数、命名参数与可选参数

### 10.1 必填位置参数

```dart
int totalCents(int unitPriceCents, int quantity) {
  return unitPriceCents * quantity;
}

totalCents(1999, 3);
```

位置决定含义。两个相同类型参数容易写反；若名字能显著提高可读性，可以改用命名参数。

### 10.2 命名参数用花括号声明

```dart
String dispatchDecision({
  required int priority,
  required bool assigneeAvailable,
}) {
  // ...
}
```

调用必须写名字：

```dart
dispatchDecision(priority: 4, assigneeAvailable: true);
```

命名参数默认是可选的；要让调用者必须提供，用 `required`。注意 `required` 与 nullable 是两个维度：`required String? note` 表示调用者必须显式传参数，但值可以是 null。

### 10.3 默认值必须是编译期常量

```dart
int boundedAttempts(int requested, {int hardLimit = 3}) {
  // ...
}
```

调用者省略 `hardLimit` 时使用 3。默认值是 API 合同的一部分，改变它可能改变所有省略参数的调用者。发布库时要视为兼容性变更审查。

### 10.4 可选命名参数的 null 问题

若既不 required 又没有非 null 默认值，则它未传时是 null，因此类型应允许 null：

```dart
String label({String? note}) => note ?? 'NONE';
```

不要写非 nullable 参数却既无 required 也无默认值；analyzer 会要求建立合法初始化合同。

### 10.5 可选位置参数

方括号表示可选位置参数：

```dart
String message(String id, [String suffix = '']) {
  return '$id$suffix';
}
```

它适合含义非常明确、顺序稳定的参数。Flutter API 大量使用命名参数提高可读性。一个函数不能同时拥有可选位置参数和命名参数组；必填位置参数可以位于命名参数之前。

### 10.6 常见调用错误

```dart
String schedule({required int priority}) => '$priority';

// schedule(4);          // 错：传了位置参数
schedule(priority: 4);   // 对
```

分析器会报告额外位置参数和缺少 required 参数。首个可信位置是调用表达式，修复应遵守函数声明，而不是删除 required。

## 11. 返回值、提前返回与所有路径

### 11.1 `return` 立即结束调用

```dart
String validatePriority(int priority) {
  if (priority < 1 || priority > 5) return 'INVALID';
  return 'VALID';
}
```

命中第一个 return 后，后续语句不执行。无法到达代码可能被 analyzer 提示；不要保留“以防万一”的死代码。

### 11.2 非 nullable 返回必须覆盖路径

```dart
String label(bool urgent) {
  if (urgent) return 'URGENT';
  return 'NORMAL';
}
```

若去掉第二个 return，则 false 路径没有 String 结果。修复可以补齐路径或重新定义返回类型，但不能仅为过编译改成 `String?`，除非业务确实允许没有标签。

### 11.3 `void` 不等于“函数没结果影响”

void 函数可能打印、写文件、修改状态，因此仍有可观察副作用。规则计算优先返回值，让调用者决定展示或存储：

```dart
String priorityBand(int priority) => /* value */;

void main() {
  print(priorityBand(4));
}
```

这样规则能用确定输入输出验证。

## 12. 箭头函数

```dart
bool isUrgent(int priority) => priority >= 4;
```

`=> expression` 等价于 `{ return expression; }`，只能放一个表达式，不能直接放 if、for 或多条语句：

```dart
String label(int priority) => priority >= 4 ? 'URGENT' : 'NORMAL';
```

简短、无副作用的转换适合箭头。为了追求一行把复杂 switch、嵌套条件和日志塞进去会降低可读性，应恢复块函数。

函数在 Dart 中也是对象，可传递和保存；闭包、高阶集合操作会在后续结合集合学习，本章不要求使用。

## 13. 用输入输出表审查维修优先级

先写合同：有效优先级 1—5，1/2 为 LOW，3 为 MEDIUM，4/5 为 URGENT，其他为 INVALID。

| 输入 | 期望 | 类别 |
| ---: | --- | --- |
| 0 | INVALID | 下边界外 |
| 1 | LOW | 最低有效 |
| 2 | LOW | 同类代表 |
| 3 | MEDIUM | 中间分支 |
| 4 | URGENT | 紧急下边界 |
| 5 | URGENT | 最高有效 |
| 6 | INVALID | 上边界外 |

实现：

```dart
String priorityBand(int priority) {
  if (priority < 1 || priority > 5) return 'INVALID';

  return switch (priority) {
    1 || 2 => 'LOW',
    3 => 'MEDIUM',
    4 || 5 => 'URGENT',
    _ => 'INVALID',
  };
}
```

前置守卫已经排除其他整数，末尾 `_` 在当前编译器上仍满足任意 int 的穷尽要求。它看似重复，但表达“若未来守卫和映射脱节，仍有安全输出”。另一种方案是把优先级建模为 enum/值对象，让 switch 真正对有限类型穷尽；那属于 OOP 章节。

## 14. 循环输入表：零次、一次、多次和上限

```dart
int boundedAttempts(int requested, {int limit = 3}) {
  var attempts = 0;
  for (var index = 0; index < requested; index++) {
    if (index >= limit) break;
    attempts++;
  }
  return attempts;
}
```

| requested | limit | 期望 |
| ---: | ---: | ---: |
| 0 | 3 | 0 |
| 1 | 3 | 1 |
| 3 | 3 | 3 |
| 9 | 3 | 3 |

还缺负数和负 limit 的合同。可以选择拒绝、归零或抛异常，但必须由需求决定并增加测试。当前教学资产只用非负输入，因此不能宣称处理了全部整数。

## 15. 三类典型诊断

### 15.1 非穷尽 switch

```dart
String assignedLabel(bool? assigned) => switch (assigned) {
  true => 'YES',
  false => 'NO',
};
```

`bool?` 还有 null，switch expression 不完整。失败阶段是 analyze/compile，首个可信位置是 switch。修复要么显式增加 `null`，要么先把 nullable 转成明确非空合同。不要用 `!` 假设输入永不为空。

### 15.2 nullable 条件

```dart
bool? enabled;
// if (enabled) {} // 分析失败
```

修复前先定语义：`enabled == true`、`enabled ?? false`、null 时返回 UNKNOWN，或让调用者提供非 nullable。不同写法行为不同。

### 15.3 命名参数误用

声明 `{required int priority}` 却调用 `schedule(4)`，分析器会同时看到额外位置参数和缺少命名参数。修复调用为 `schedule(priority: 4)`。若大量调用都觉得名称多余，可以评审 API 设计，但不能在排错时偷偷改变合同。

### 15.4 规则缺口导致运行断言失败

```dart
if (priority >= 5) return 'URGENT';
```

这段能分析、能运行，却把 4 错分。边界断言 `priorityBand(4) == 'URGENT'` 才会红。错误类型是业务/测试失败，不是编译错误。先修复实现，再重跑 0—6 全表，防止修一个点破坏别的分支。

### 15.5 无限循环

while 中某条 continue 路径未推进变量，通常不会被 analyzer 自动证明为无限。表现为进程不结束或 CPU 占用。测试应加超时/步数上限，诊断每条路径的推进变量。不要让 AI 只在循环外增加 sleep；那没有修复终止性。

## 16. FactoryCare 规则怎样保持纯净

移动端接到工单后可能根据优先级和处理人可用性展示行动：

```dart
String dispatchDecision({
  required int priority,
  required bool assigneeAvailable,
  int retryLimit = 3,
}) {
  if (priority < 1 || priority > 5) return 'REJECT_INVALID_PRIORITY';
  if (!assigneeAvailable) return 'QUEUE_RETRY_$retryLimit';

  return switch (priority) {
    1 || 2 => 'NORMAL_QUEUE',
    3 => 'EXPEDITED_QUEUE',
    4 || 5 => 'URGENT_DISPATCH',
    _ => 'REJECT_INVALID_PRIORITY',
  };
}
```

此函数不请求网络、不改 UI，只把已验证标量映射成决策字符串，便于值表测试。生产设计会把字符串换成 enum/sealed 类型，把重试交给异步策略，把权限与状态机交给领域合同。当前函数是语法与分支实验，不是完整调度引擎。

如果服务端拥有最终派单权，客户端只能展示建议和提交请求，不能自行改变工单状态。控制流写得再完整也不改变权限边界。

## 17. 学习资产与红绿循环

- `examples/encyclopedia/ch.dart.control-functions/`：8 个同步断言覆盖 if、switch、三类循环、break/continue、命名参数、默认值和箭头函数；
- `labs/encyclopedia/ch.dart.control-functions/`：7 个绿色案例，外加非穷尽 switch、nullable 条件、命名参数误用三个 analyzer 负夹具；
- `exercises/encyclopedia/ch.dart.control-functions/`：公开实现故意把优先级 4 漏出紧急分支，运行稳定预期红；
- `solutions-private/encyclopedia/ch.dart.control-functions/`：用显式 switch 覆盖 0—6 边界。

正确顺序：

1. 不运行，先写每个夹具的失败阶段；
2. 执行公开 verify，确认红色与预测一致；
3. 只改规则，不删断言；
4. 重跑全部边界而非只跑 priority=4；
5. 对照私有答案，解释差异；
6. 120 秒讲回分支穷尽、循环终止和参数合同。

## 18. AI 协作边界

AI 可以根据已确认的输入域生成边界表、指出可能的 off-by-one、建议函数命名、解释 analyzer 诊断、生成负夹具。它也能机械转换 if 链与 switch 草案。

学习者必须自己决定并验证：

- 哪些输入有效，边界是包含还是排除；
- null、无效优先级、负次数的业务含义；
- 所有 switch 分支是否覆盖；
- 循环每条路径是否向终止推进；
- 参数为什么用位置或命名，默认值改变有什么影响；
- AI 是否删除失败断言、加 `_` 吞掉新状态、用无限循环或把错误改成 nullable；
- 本地绿色是否只覆盖同步标量模型。

面对 AI 生成代码，至少独立修改一个要求，例如“紧急下界由 4 改成 3”，并同步调整输入输出表。若只能重新生成整段而不能定位分支，就还没有掌握。

## 19. 复习与独立任务

### 19.1 口头题

1. 为什么 `if (1)` 在 Dart 不是合法条件？
2. else-if 顺序怎样制造不可达分支？
3. switch expression 与 statement 的主要输出形态有什么不同？
4. `bool?` 的 switch 为什么要考虑 null？
5. for 的初始化、条件和更新分别是什么？
6. while 与 do-while 对输入 0 有何差异？
7. continue 为什么可能让 while 无限循环？
8. `required String? note` 表达哪两个独立维度？
9. 默认参数值为何是 API 合同？
10. 箭头函数为什么不能直接装 if statement？
11. analyzer 绿为何不能发现 priority=4 的规则缺口？
12. 举一个本章不负责的问题，例如 HTTP 重试取消或 Flutter 生命周期。

### 19.2 独立构建

实现三个函数：

1. `priorityBand(int priority)`：覆盖有效/无效边界；
2. `boundedAttempts(int requested, {int limit = 3})`：覆盖 0、1、多次和上限；
3. `dispatchDecision({required int priority, required bool assigneeAvailable})`：覆盖所有组合。

要求：不使用集合、类、async、无界循环或 `dynamic`；先写输入输出表；制造一个非穷尽 switch 编译失败；修复后重跑格式、分析、运行；保存首个可信位置和退出码。

## 20. 稳定核心、版本表面和官方资料

资料核对日期：**2026-07-24**。dart.dev 当日默认反映 Dart **3.12.2**。`if`、for/while/do-while、break/continue、函数声明、位置/命名参数、默认值、return 和箭头函数是稳定核心；switch expression 与现代模式需要 Dart 3.0+，本章包约束 3.9+ 已满足。Dart 3.13 文档预告的普通参数修饰符变化不属于当前 3.12.2 基线，本章没有依赖。

官方一手资料：

- [Branches](https://dart.dev/language/branches)：if、switch statement/expression、guard 与穷尽检查；
- [Loops](https://dart.dev/language/loops)：for、while、do-while、break、continue 和 label；
- [Functions](https://dart.dev/language/functions)：声明、参数、默认值、返回、main 与箭头语法；
- [Patterns](https://dart.dev/language/patterns)：模式类别、匹配和解构；
- [Operators](https://dart.dev/language/operators)：条件表达式、逻辑和赋值运算；
- [Analyzer diagnostics](https://dart.dev/tools/diagnostics)：静态诊断索引。

**已实际验证**：macOS arm64、Dart 3.9.2 下，本章四类资产完成格式、分析、绿色输入输出表；三个静态负夹具预期失败；公开优先级边界练习运行预期红；私有答案绿色。**未验证**：Dart 3.12.2 二进制复跑、Web/AOT 性能、集合 for-in 与高阶操作、类/enum/sealed 的跨文件穷尽、真实网络重试/取消、Flutter UI 主线程、状态机授权和服务器并发。它们由后续章节承担，不能从本章同步函数推断。
