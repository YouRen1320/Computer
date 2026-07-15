# 第 32 周：Dart 语法、类型、空安全、控制流、函数与集合

## 定位

本周把 Dart 从“跟着 Flutter 写过”还原成一门独立语言。先在命令行纯 Dart 工程里理解类型、空安全、控制流、函数和集合，再进入对象/异步与 Flutter。这样遇到 Widget 问题时能区分语言错误、异步错误和框架生命周期错误。

时间预算：15—18 小时。使用当前 Flutter stable 自带的 Dart stable；不写 Flutter UI。

## 前置

- uni-app G5 前半段主链路完成；
- `dart --version`、`dart create`、`dart run`、`dart test` 可用；
- 有 Java/JS/TS 基础，可做类比但不假设 Dart 等同任何一种；
- 能阅读 `pubspec.yaml` 和分析器输出。

## 目标

- 理解 Dart 程序入口、编译/运行模式和 package 基础；
- 使用变量、内置类型、运算符、字符串和类型推断；
- 掌握 sound null safety、nullable/non-nullable、promotion 与 `late` 边界；
- 使用 if/switch/for/while 和 pattern 基础表达规则；
- 设计函数、命名/可选参数、返回值、closure 和 typedef；
- 使用 List/Set/Map、spread、collection if/for 和不可变视图；
- 使用 analyzer、formatter、test 和 debugger；
- 用纯 Dart 实现并测试 FactoryCare 工单规则。

## 完整概念清单

### 程序与变量

- `main(List<String> args)`、library/package/file；
- JIT（开发）与 AOT（发布）的高层区别；
- `var`、显式类型、`final`、`const`、`dynamic`、`Object?`；
- `final` 运行时一次赋值，`const` 编译期常量；对象内部可变性另算；
- `dynamic` 关闭静态检查，默认用具体类型或 `Object?`；
- int/double/num/bool/String/Symbol/Record 基础；
- 字符串插值、多行字符串、raw string 和 Unicode rune/grapheme 概念；
- 运算符、整数除法 `~/`、级联 `..`/`?..` 和条件访问。

### 空安全

- `T` 与 `T?`；非空类型不能存 null；
- `?.`、`??`、`??=`、`!` 的含义；
- flow analysis/type promotion；
- 字段 promotion 的限制与局部变量提取；
- `late` 延迟初始化，不是“到处绕过 null”的工具；
- `late` 未初始化会在运行时失败；
- `required` 命名参数；
- 与 TS 的 `strictNullChecks` 比较：Dart sound null safety 与运行/编译模式边界。

### 控制流与模式

- if/else、条件表达式、switch statement/expression；
- for、for-in、while、do-while、break/continue；
- switch 穷尽性、enum/sealed 类型在 Week 33 深入；
- pattern matching、destructuring、if-case/switch pattern 基础；
- guard clause 和早返回；
- iterable lazy 操作与 collection 在本周只用基础，复杂异步留后；
- 避免把复杂 UI 状态塞进嵌套条件。

### 函数

- 返回类型、参数类型、箭头函数；
- required positional、optional positional、named、required named；
- 默认值必须是编译期常量；
- 函数是一等值、closure 和 lexical scope；
- `typedef` 命名函数签名；
- tear-off 与立即调用的区别；
- 参数对象/命名参数改善调用可读性，但不掩盖职责过多；
- 不依赖返回类型重载，Dart 不支持 Java 式方法重载。

### 集合与迭代

- List/Set/Map 的字面量、泛型类型和常用操作；
- 固定/可增长列表高层差异；
- `add/addAll/remove/where/map/fold` 的输入输出；
- iterable 是惰性序列视图，必要时 `toList`；
- spread `...`/null-aware spread、collection if/for；
- `List.unmodifiable` 是不可修改视图/副本语义需查 API，深层对象仍可能可变；
- 相等性与 hash 在 Week 33；
- 空集合优于返回 null。

### 工具与测试

- `dart format`、`dart analyze`、`dart test`；
- package dependency/dev_dependency 和 lockfile；
- test 的 group/test/expect；
- 编译/分析错误、测试失败和运行时异常；
- 断点、变量、调用栈；
- lint 是规则，不等于功能正确。

## 时间与任务

| 任务 | 时间 | 产出 |
| --- | ---: | --- |
| 程序/类型/运算 | 2h | CLI 输入与计算测试 |
| 空安全 | 3h | promotion、nullable、late 故障实验 |
| 控制流/模式 | 2—3h | 状态/优先级决策和穷尽分支 |
| 函数/closure | 2h | 命名参数、typedef 和小规则拆分 |
| 集合 | 2—3h | 筛选、分组、统计和不可变边界 |
| FactoryCare/复盘 | 3—4h | 纯 Dart 规则包、独立修改和口述 |

## FactoryCare 增量

- 纯 Dart 定义工单输入 record/简单数据结构和状态字符串/enum 基础；
- 实现优先级计算、未关闭工单筛选和按技师统计；
- 使用命名参数使业务调用可读；
- 对 nullable 技师、空列表、未知状态和负值写测试；
- 对比 Java/TS：空安全、final/const、参数形式、集合和运行时类型；
- 不引用 Flutter package。

## 无 AI 任务（120 分钟）

实现 `summarizeWorkOrders`：输入工单列表与可选技师筛选，输出总数、活跃数、最高优先级和按状态计数。要求不修改输入、处理空列表/未分配/非法优先级，`dart analyze` 和测试通过；再独立增加“只统计 enabled 设备”的规则。

## 验收

- 能写并解释 `main`、变量、输入输出、控制流、函数和集合；
- 能区分 `final`、`const`、`dynamic`、`Object?`；
- 能解释 `T?`、promotion、`!` 和 `late` 的风险；
- `format/analyze/test` 全部通过；
- 能从分析器或测试日志定位一次错误；
- 纯 Dart 包不依赖 Flutter 且可独立修改。

## 非目标

- 不写 Widget 或状态管理；
- 不深入 Future/Stream/isolate，留到 Week 33；
- 不用 `dynamic`/`!` 消除所有类型问题；
- 不复刻一整套 Dart 官方手册。
