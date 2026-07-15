# 第 33 周：Dart 类、泛型、异常、Future、Stream 与测试

## 定位

本周完成 Flutter 前的 Dart 语言基础：对象模型、接口/mixin/extension、泛型、错误处理、异步 Future/Stream、取消与 isolate 边界。所有机制先在纯 Dart 中验证，再由 Week 34 接入 Flutter 生命周期。

时间预算：15—18 小时。禁止用 Widget `setState` 掩盖尚未理解的 Future/Stream 状态。

## 前置

- 能用 Dart 类型、空安全、控制流、函数和集合；
- 纯 Dart 工单规则的 analyzer/test 通过；
- 能使用 debugger 和读取 async stack trace；
- 明白 Promise/Future 类比只用于入门，具体调度与 API 需按 Dart 证据。

## 目标

- 定义类、字段、构造器、命名/工厂构造器和不可变对象；
- 理解 implicit interface、abstract、extends/implements/mixin/extension；
- 使用 enum/sealed class/pattern 表达有限状态；
- 使用泛型、约束与集合类型安全；
- 设计 Exception/Error 边界并保留 stack trace；
- 理解 event queue/microtask 的高层模型；
- 使用 Future/async/await、并发组合、超时和错误；
- 使用 Stream subscription、暂停/恢复/取消和 broadcast 边界；
- 理解 isolate 解决 CPU 隔离，不共享普通内存；
- 建立纯 Dart 单元、异步和 fake 测试。

## 完整概念清单

### 类与对象

- class、instance field/method、getter/setter、static；
- 默认/生成/命名构造器、initializer list、redirecting constructor；
- `this`、`super`、const constructor 和 canonical instance 高层现象；
- private 名称以 `_` 表示 library 私有，不是 class 私有；
- immutable 注解/lint 与真正不可变设计；
- factory constructor 可缓存/选择实现，但不一定创建新对象；
- record/data object/class 的选择。

### 类型协作

- 每个 class 隐式定义 interface；
- `extends` 继承实现，`implements` 只承诺接口并重新实现；
- abstract class/interface class/base/final/sealed modifier 的高层约束，按当前稳定 Dart 文档验证；
- mixin 复用横切行为的适用条件与状态风险；
- extension method 静态解析，不修改原类型；
- composition/delegation 优先于深继承；
- overriding、covariant 关键字风险和 LSP 直觉。

### enum、sealed 与模式

- enhanced enum 的字段/构造器/方法；
- sealed hierarchy 让同 library 分支可穷尽；
- switch pattern、object/record/list pattern 和 guard；
- 状态、加载结果、领域错误用 sealed union 表达；
- JSON 字符串到 enum/sealed 类型需要显式验证；
- 不用继承层次模拟随配置变化的任意数据。

### 泛型与相等性

- generic class/method、bound `T extends ...`；
- `Object?`、`Never` 与 variance 直觉；
- reified generic 的可见范围，不假设可反射所有嵌套参数；
- `==` 与 `hashCode` 契约；
- 可变对象作为 Set/Map key 的风险；
- value equality 可以手写或使用经选择的工具，但要理解生成结果。

### 异常与资源

- throw 任意对象可行但应抛 Exception 类型；
- `try/on/catch/finally`、rethrow、stack trace；
- 同步异常与 Future error；
- 自定义领域异常、技术异常和用户可见结果；
- `Error` 通常表示编程错误，不当正常控制流；
- close/dispose/cancel 必须由资源拥有者调用；
- finally 收尾不能无条件覆盖更新后的状态。

### Future 与事件循环

- sync stack、event queue、microtask queue 高层顺序；
- Future 状态和 completion；创建 Future 不等于新线程；
- async 到首个 await 前同步执行；
- `await`、then/catchError/whenComplete；
- `Future.wait`、串行与并发、部分失败；
- timeout 结束等待不一定取消底层 I/O；
- Dart Future 默认没有统一取消，需 client/subscription/token 机制；
- unawaited 操作必须有明确所有权与错误处理。

### Stream 与 isolate

- single-subscription 与 broadcast；
- listen/onData/onError/onDone；
- subscription pause/resume/cancel；
- async*、yield、await for；
- Stream transform、backpressure 高层限制；
- 页面销毁时取消订阅；
- isolate 有独立内存，通过消息传递；
- CPU 密集解析可考虑 isolate，普通网络等待不需要 isolate。

### 测试

- group/setup/teardown、matcher、throwsA；
- async test、completion、emitsInOrder、fake async/time；
- fake repository/client 与 mock 的取舍；
- 测取消、超时、乱序、重复和资源关闭；
- 测试通过仍需 analyzer/build；
- Flutter Widget/Integration 测试留到 Week 34—35。

## 时间与任务

| 任务 | 时间 | 产出 |
| --- | ---: | --- |
| 类/构造器/不可变 | 2—3h | 工单值对象与实体 |
| interface/mixin/extension/sealed | 3h | 端口、状态 union 和取舍记录 |
| 泛型/相等 | 2h | Result/Repository 和 key 故障 |
| 异常/Future | 3h | 超时、乱序、错误传播实验 |
| Stream/isolate | 2—3h | 事件流取消和 CPU 对照 |
| FactoryCare/复盘 | 3—4h | 纯 Dart data/domain 包和测试 |

## FactoryCare 增量

- `WorkOrderId` 值对象、`WorkOrder` 实体和 sealed `LoadState`；
- 泛型 `Repository<T, ID>` 仅在确有共同时使用；
- fake repository 模拟成功、延迟、异常和乱序；
- `WorkOrderEvent` Stream 支持订阅取消；
- 测试页面等价 owner 销毁后 subscription 已取消（纯 Dart owner 类）；
- 用 isolate 处理大 JSON 只做对照实验并测量，不默认采用。

## 无 AI 任务（120—150 分钟）

实现 `WorkOrderSyncService` 纯 Dart 版本：从 repository 拉取、映射 sealed 结果、发布进度 Stream、支持超时和显式 dispose；fake client 可控制乱序/失败。测试成功、错误、超时、取消订阅、dispose 后不再发布，并解释哪些工作真正被取消。

## 验收

- 能比较 extends/implements/mixin/extension/composition；
- 能用 sealed 类型和穷尽 switch 表达状态；
- 能解释 Future 不等于线程、timeout 不等于底层取消；
- 能创建并取消 StreamSubscription；
- analyzer、纯 Dart 测试稳定通过；
- 能独立新增一种错误结果并更新所有穷尽分支。

## 非目标

- 不进入 Flutter Widget/BuildContext；
- 不为了架构创建通用 Repository/Result 框架；
- 不深入 isolate 调度器或 Dart VM 源码；
- 不把 `mounted` 当网络取消方案，Week 34 会在 UI 生命周期验证。
