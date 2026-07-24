---
schema_version: 2
edition: 2026.2-draft
id: ch.dart.testing-lints
title: Dart test、断言、Mock、lint 与包质量
responsibility: 用 dart test、可信断言、可控替身和静态分析验证同步/异常合同，组合 format/analyze/test 门禁，不在本章测试 Flutter Widget。
volume: '11'
order: 9
level: L2
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.dart.testing-lints.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.dart.exceptions-resources
version_surfaces:
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
  text: 在 120 秒内解释“Dart test、断言、Mock、lint 与包质量”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - dart-unit-testing
  - dart-package-quality
  covers_topics:
  - dart.test-group-case
  - dart.expect-matcher
  - dart.throws-async
  - dart.mock-fake-boundary
  - dart.test-isolation
  - dart.lint-rule
  - dart.format-check
  - dart.analyze-gate
  - dart.test-gate
  - dart.quality-command-order
  uses_capabilities:
  - mobile.dart-language
  - foundation.verification-debug-test
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为工单领域对象和错误转换编写 Dart 单元测试及一键质量门禁；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - dart-unit-testing
  - dart-package-quality
  covers_topics:
  - dart.test-group-case
  - dart.expect-matcher
  - dart.throws-async
  - dart.mock-fake-boundary
  - dart.test-isolation
  - dart.lint-rule
  - dart.format-check
  - dart.analyze-gate
  - dart.test-gate
  - dart.quality-command-order
  uses_capabilities:
  - mobile.dart-language
  - foundation.verification-debug-test
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: dart-test-lint-gate-injected-fault
- id: diagnose
  kind: fault-diagnosis
  text: 面对“错误 matcher、过度 Mock、共享夹具或忽略 analyzer 警告导致假通过”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - dart-unit-testing
  - dart-package-quality
  covers_topics:
  - dart.test-group-case
  - dart.expect-matcher
  - dart.throws-async
  - dart.mock-fake-boundary
  - dart.test-isolation
  - dart.lint-rule
  - dart.format-check
  - dart.analyze-gate
  - dart.test-gate
  - dart.quality-command-order
  uses_capabilities:
  - mobile.dart-language
  - foundation.verification-debug-test
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Dart test、断言、Mock、lint 与包质量

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《异常、资源所有权与错误建模》](ch.dart.exceptions-resources.md)：异常断言和清理验证需要稳定失败契约。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。截至 2026-07-24，Dart 官方文档基线为 3.12.2，`package:test` 当前为 1.31.2，Dart 团队发布的 `lints` 当前为 6.1.0。配套资产为兼容本机 Dart 3.9.2 固定 `test` 1.31.0 与 `lints` 6.1.0；当前包版本和实际验证版本是两条证据。依赖绿灯不证明 Dart 3.12.2、浏览器或 Flutter Widget 已运行。

测试的价值不是“文件名以 `_test.dart` 结尾”，而是给风险建立会失败的判据。format 统一文本形状，analyzer 检查静态合同和 lint，test 执行行为 oracle；三者互补，任何一个 `BUILD SUCCESS` 都不能单独证明功能正确。AI 可以快速生成测试，但也很容易生成只验证 Mock、遗漏 await 或永远不会变红的假证据。

## 1. 完成定义与非目标

完成本章后，你应能：

1. 建立最小 Dart package，区分 `lib/`、`test/` 与 dev dependency；
2. 用 `group/test/expect` 写正常、边界和失败用例；
3. 选择具有诊断力的 matcher，而不是只断言“抛了某种东西”；
4. 正确等待异步成功与异步错误，避免测试提前结束；
5. 在 Stub、Fake、Mock、真实对象间按风险选择；
6. 让每个用例拥有独立 fixture，并稳定控制时间、随机和 I/O；
7. 配置 `analysis_options.yaml` 与官方 `lints` 集合；
8. 组合只检查格式的 format、`dart analyze` 和 `dart test` 门禁；
9. 注入故障，证明测试能红，再修复并重跑；
10. 报告 SDK、依赖、平台、命令和未验证项。

配套入口：

- [Dart 单元测试与质量门禁示例](../../../examples/encyclopedia/ch.dart.testing-lints/README.md)
- [测试隔离、Fake 与故障实验](../../../labs/encyclopedia/ch.dart.testing-lints/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.dart.testing-lints/README.md)

非目标：不测试 Flutter Widget、不追求虚假 100% 覆盖率、不把每个类都 Mock、不依赖真实生产服务、不忽略 analyzer 警告、不使用只在本机顺序下偶然通过的共享状态。

## 2. Dart package 的测试边界

一个最小可测试包：

```text
factorycare_rules/
├── pubspec.yaml
├── analysis_options.yaml
├── lib/
│   └── work_order.dart
└── test/
    └── work_order_test.dart
```

`lib/` 是包对外可引用的生产代码；`test/` 是测试源。`pubspec.yaml` 中 `test` 与 `lints` 通常是 `dev_dependencies`，因为使用者运行库不需要携带测试 runner。官方 `dart test` 会在当前 package 的 `test` 目录寻找依赖 `package:test` 的测试；指定文件、名称或 tag 可缩小范围。Flutter 代码应使用 `flutter test`，不在本章混用。

```yaml
environment:
  sdk: '>=3.9.0 <4.0.0'
dev_dependencies:
  lints: 6.1.0
  test: 1.31.0
```

精确固定版本便于教材复现，但真实项目可按团队更新策略使用兼容约束和 lockfile。升级依赖时要运行 format/analyze/test，并检查变更说明；“pub get 成功”只证明解析成功。

## 3. 一个测试的四个组成

```dart
test('priority 4 is urgent', () {
  // Arrange：准备最小输入。
  final order = WorkOrder(id: 'WO-1', priority: 4);

  // Act：调用一个可观察行为。
  final result = order.isUrgent;

  // Assert：比较业务合同。
  expect(result, isTrue);
});
```

测试名说明条件与结果；Arrange 不隐藏大量魔法；Act 尽量单一；Assert 检查可观察合同。若失败输出只显示“Expected true, Actual false”且不知道哪个输入，就需要 matcher description 或测试命名补充。

`group` 只是组织与共享生命周期钩子，不是让用例互相依赖：

```dart
group('WorkOrder priority', () {
  test('1 is normal', () { /* ... */ });
  test('4 is urgent boundary', () { /* ... */ });
  test('5 is urgent maximum', () { /* ... */ });
});
```

先按行为和风险分组，不按类的每个私有方法机械分组。重构内部结构而业务合同不变时，理想测试仍通过。

## 4. 正常、边界、失败不是三份重复代码

对优先级 1..5：

- 正常：3 不是紧急；
- 下边界：1 合法；
- 决策边界：4 开始紧急；
- 上边界：5 合法；
- 失败：0、6、非整数或缺失；
- 合同：错误类型携带原始值。

测试矩阵来自输入空间与规则，不是为了增加数量。等价类选一个代表，边界单独验证。若 parser 接受 `Map<String,Object?>`，还要覆盖字段缺失、错误类型和多余字段策略。每个断言应能映射到需求或故障。

## 5. Matcher 要提供诊断，不只提供布尔值

常用 matcher：`equals`、`isTrue/isFalse`、`isNull/isNotNull`、`contains`、`hasLength`、`isA<T>`、`throwsA`。领域错误可使用 `having`：

```dart
expect(
  () => parsePriority(9),
  throwsA(
    isA<InvalidPriority>()
      .having((error) => error.value, 'value', 9),
  ),
);
```

只写 `throwsA(anything)` 会让 FormatException、Null 错误甚至测试自身 bug 都通过。只比较 `error.toString()` 又对文案过度耦合。优先断言稳定类型、领域字段和必要 cause；用户文案另有展示层测试。

集合若顺序属于合同，用 `equals([a,b])`；若只关心集合内容，使用适合无序语义的 matcher。不要为了让用例绿而把预期排序，除非生产合同也保证/不保证顺序。

## 6. 同步抛错与异步失败

同步函数的断言传“函数”，不能先调用：

```dart
expect(() => parseWorkOrder(input), throwsA(isA<FormatException>()));
```

异步函数返回 Future：

```dart
await expectLater(
  repository.load('missing'),
  throwsA(isA<NotFound>()),
);
```

或：

```dart
expect(repository.load('missing'), throwsA(isA<NotFound>()));
```

即使框架支持返回 matcher Future，也推荐显式 `await expectLater`，让所有权易读。若测试 callback 是 `async`，test runner 会等待其返回 Future；忘记 await 某个内部 Future，测试 callback 可能提前完成，晚到错误成为未捕获异步错误或跨用例污染。

### 6.1 假绿示例

```dart
test('fails for invalid priority', () {
  expectLater(normalizePriority(9), throwsA(isA<InvalidPriority>()));
  // 没有 return/await；测试可能在 matcher 完成前结束。
});
```

修复：把 callback 改 `() async` 并 `await expectLater(...)`，或返回 matcher Future。再故意让实现返回 1，确认测试稳定红，才证明 oracle 工作。

## 7. setUp/tearDown 与测试隔离

官方 `package:test` 文档说明 `setUp` 在每个测试前运行，`tearDown` 在测试后运行，即使测试失败也有机会清理。使用 `late` 变量重建 fixture：

```dart
late FakeTicketPort port;
late RepairService service;

setUp(() {
  port = FakeTicketPort();
  service = RepairService(port);
});

tearDown(() async {
  await port.close();
});
```

共享只读常量可以顶层保存；可变 List、缓存、数据库、时钟和全局 singleton 必须每用例重置。测试随机顺序仍应一致。`test` runner 支持 `--test-randomize-ordering-seed`，保存 seed 可复现顺序依赖。

清理失败不能吞掉。若 tearDown 抛错，用例应失败并指出资源未释放。不要在 tearDown 中把全局状态“尽量改回去”却忽略返回 Future。

## 8. Stub、Fake、Mock 与真实对象

术语在团队里可能略有差异，本章使用：

- Stub：按输入返回预设值，不强调交互验证；
- Fake：有简化但可工作的实现，如内存 repository；
- Mock：可配置响应并验证调用次数/参数；
- Spy：包装真实行为并记录交互；
- Dummy：只为填参数，从不使用。

优先最简单的替身。纯领域值对象直接创建；小接口常用手写 Fake，比代码生成 Mock 更易读。只有“是否调用 exactly once、参数是否携带幂等键”本身是合同，才验证交互。

### 8.1 过度 Mock 的症状

一个 service 测试 Mock repository、clock、logger、mapper、validator、DTO factory，并断言七次内部调用顺序。任何重构都会红，但用户行为可能没变。更好的做法是注入一个业务端口和可控 clock，断言返回/状态/领域事件；logger 调用除非是审计合同，不应成为核心 oracle。

Mock 只能证明代码与 Mock 一致。若 Mock 永远返回理想 JSON，它不能证明真实服务字段、错误状态或超时。来自真实合同的脱敏 fixture 和集成测试补足这层。

## 9. 时间、随机、文件和网络要可控

易抖动测试通常依赖：`DateTime.now()`、随机数、真实 Timer、临时文件路径、网络和执行顺序。将不确定源注入：

```dart
abstract interface class Clock {
  DateTime now();
}

final class FixedClock implements Clock {
  FixedClock(this.value);
  final DateTime value;
  @override
  DateTime now() => value;
}
```

随机源也用接口或 seed；文件使用测试临时目录并在 tearDown 删除；HTTP 使用端口和脚本化 fake，真实协议另做集成测试。不要用 `Future.delayed(100ms)` 等待状态，优先 Completer、fake clock 或可观察条件。

## 10. format 是可执行的文本合同

`dart format .` 会改写源文件；CI 只检查不修改时使用官方命令：

```bash
dart format --output=none --set-exit-if-changed .
```

官方文档说明：会发生格式变化时退出码 1，不变化时退出码 0。格式门禁不证明类型或行为，但减少无意义 diff 和风格争论。开发者本地可先 `dart format .` 修复，再提交；CI 不应偷偷改文件后仍绿。

版本升级可能改变 formatter 输出，因此 SDK 版本属于证据。若本地和 CI Dart 不同，格式可能来回变化。记录 `dart --version`，在项目/流水线固定 SDK。

## 11. analyzer 与 lint 的职责

`dart analyze` 做静态分析：类型错误、不可达问题、API 使用和启用的 lint。`analysis_options.yaml` 可引入官方推荐集：

```yaml
include: package:lints/recommended.yaml

linter:
  rules:
    discarded_futures: true
```

官方 `lints` 包提供 core 与 recommended；recommended 包含 core，并增加潜在问题与一致风格。新 Dart 项目默认启用 recommended。Flutter 项目使用在其上扩展的 `flutter_lints`，但本章不进入 Flutter。

lint 不是永恒真理。升级 `lints` 可能增加或移除规则，属于版本表面；团队需评估、集中变更并记录理由。不要在每行加 `// ignore`；若必须抑制，使用最窄范围并说明业务原因和复查条件。

### 11.1 warning 不能靠日志颜色治理

CI 命令可使用适合项目的 fatal 选项，让 warning/info 影响退出码。配套资产采用 `dart analyze --fatal-infos`。具体 flag 以目标 SDK `dart analyze --help` 为准。门禁必须看退出码，不用 grep “No issues”。

## 12. `dart test` 的发现与选择

官方 `dart test` 默认递归查找 `test/` 下符合 `*_test.dart` 的文件；也可指定文件或目录。按名称与 tag 筛选：

```bash
dart test test/work_order_test.dart
dart test --name 'invalid priority'
dart test --tags fast
dart test --exclude-tags integration
```

筛选适合本地定位，不应让 CI 永远只跑一个绿用例。tag 的定义要写入 `dart_test.yaml` 并说明用途。慢测试、外部服务测试和平台测试可以分层，但不能静默 skip 关键失败。

测试套件可并发运行，不要依赖文件执行顺序或共享端口。固定 seed 的随机顺序能暴露状态泄漏；修复后还要在默认并发配置重跑。

## 13. 质量命令顺序

推荐快速失败顺序：

```bash
set -euo pipefail
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test --reporter expanded
```

依赖解析必须先完成，format 最快，analyze 通常比全测试快，行为测试最后。大型仓库可按变更范围并行，但最终合并门禁要覆盖完整 package。shell 使用 `set -e`，任何门失败立即非零；最后打印 PASS 之前必须确认前面的退出码。

门禁输出应含 SDK、lockfile、目标平台、命令和测试统计。不要因为最后一行 `PASS` 就忽略中间命令通过管道被吞掉的退出码；shell pipeline 需要 `pipefail`。

## 14. 测试失败日志怎么读

按层定位：

1. `pub get`：版本约束、网络、源与 lockfile；
2. format：文件会被改写，先运行 formatter 看 diff；
3. analyze：文件行列、diagnostic code、启用规则；
4. test compile/load：import、类型、fixture 初始化；
5. assertion：测试名、expected/actual、matcher、首个业务栈帧；
6. async uncaught：哪个 Future 未被等待，是否跨用例晚到；
7. teardown：资源关闭、临时目录、全局恢复；
8. timeout：是真死锁、无进展，还是业务整体时限。

先看第一条导致门禁失败的诊断，不从末尾复制整个堆栈猜。测试 runner 的超时不一定是严格墙钟总时限；当前 package:test 文档说明默认更偏向无活动超时，具体行为按当前版本核对。

## 15. 故障注入：证明测试不是装饰

每个关键规则至少做一次 mutation：

- 把 `priority >= 4` 改成 `> 4`，边界 4 测试必须红；
- 把 InvalidPriority 改为返回默认 1，异常 matcher 必须红；
- 删除 `await`，analyzer 或异步测试必须红；
- 让 Fake 在用例间共享 Set，随机顺序测试必须暴露；
- 忽略 analyzer info，fatal 门禁必须阻断；
- 删除 cancel，清理计数测试必须红。

修复后重跑原命令，并保存红→修复→绿的最小日志。覆盖率只能说明哪些行执行过，不能证明断言有诊断力；mutation/故障注入更直接。

## 16. FactoryCare 测试分层

| 规则/风险 | 首选证据 | 不足以证明 |
|---|---|---|
| 优先级 1..5 | 纯函数单测 + 边界 | API schema 已部署 |
| 工单状态转换 | 领域对象/状态机单测 | 数据库并发锁正确 |
| repository 错误翻译 | 脚本化 Fake + 真实 fixture | 真实 TLS/超时 |
| 创建幂等键 | service 交互合同 | 服务端确实幂等 |
| 取消清理 | Completer + 计数器 | 真 HTTP 已停止 |
| JSON schema | parser 测试 | 所有线上数据兼容 |
| Widget 显示 | 后续 flutter_test | 真机辅助功能 |

领域测试不依赖 Flutter，运行快且诊断准。Widget、集成和真机证据在后续章节补充；不要把它们塞进本章让基础测试变慢。

### 16.1 示例：错误转换

transport 返回 404 时，repository 应抛 `WorkOrderNotFound(id)`；401 应为 unauthenticated；格式错应为 contract violation 并保留 cause。分别测试，不写一个宽泛 `throwsException`。日志/审计如属于合同，可通过专用 Fake 记录结构化事件，不断言完整文案。

## 17. 四类典型假通过

### 17.1 错误 matcher

预期领域异常却使用 `throwsA(anything)`；Null 错误也绿。首个证据是把实现改成无关异常测试仍绿。修复 matcher 类型和字段，注入错误再次确认。

### 17.2 过度 Mock

Mock 既返回由测试编写的 DTO，又验证测试自己规定的调用；生产 parser 从未执行。首个证据是破坏 parser 后测试仍绿。修复让测试穿过真实领域/映射代码，只替换外部端口。

### 17.3 共享 fixture

用例 A 创建 `WO-1`，用例 B 假设它存在；单独跑 B 失败。首个证据是 `dart test --name B` 或随机顺序 seed。修复每用例重建状态，测试数据由 Arrange 明示。

### 17.4 忽略 analyzer

流水线先 `dart analyze || true`，最后 test 绿。首个证据是 analyzer 非零被 shell 吞掉。修复 `set -euo pipefail` 和 fatal 策略；不要用最后的 echo 伪造成功。

## 18. Mock 的设计边界

接口应围绕业务能力，而非第三方 SDK 的每个方法：

```dart
abstract interface class TicketPort {
  Future<void> save(WorkOrder order, {required String idempotencyKey});
}
```

手写 Fake 保存 calls 和数据，能表达重复冲突。若使用 Mockito 等生成工具，版本、build_runner 和生成文件策略属于额外版本表面；本章无需引入。选 Mock 框架不能替代端口设计。

交互断言只验证外部可观察责任。例如幂等键必须传给后端，可断言；mapper 内部先 trim 再 uppercase 的调用顺序通常不应断言，只看最终规范值。Mock 数量过多常说明类职责或依赖边界需要重审。

## 19. 性能、并发与资源

单元测试数量 n，若每个 O(1)，总时间近似 O(n)；若每个重建大 fixture O(m)，总 O(nm)。把共享 fixture 设为全局虽快，却破坏隔离。可共享不可变解析结果或用轻量工厂，但不共享可变状态。

test runner 并发执行 suite，真实端口/临时文件名必须隔离。为每用例启动进程/数据库成本高，应在集成层按安全作用域复用，并仍通过事务/namespace 隔离。单元层保持毫秒级有助于频繁运行，但不能用速度为理由删掉失败路径。

资源所有权：测试创建的 server、client、subscription、temp directory 和 fake timer 由该测试/fixture teardown 关闭；全局替换必须恢复。门禁脚本创建 `.dart_tool`，教材验证器退出时清理以保持工作区；真实项目通常保留缓存提高速度。

## 20. lint 配置治理

推荐从 `package:lints/recommended.yaml` 开始，再只添加能防真实问题的规则。启用规则前：扫描现有诊断、分类自动修复/语义修复、分批提交、CI 设 fatal，记录例外。升级时不要一次混入业务重构。

规则示例：`discarded_futures` 能提醒同步函数丢弃 Future，但并非所有 fire-and-forget 都错误；若入口必须丢弃，应使用团队认可的显式 helper 或带理由的窄 ignore，并确保错误被观察。`avoid_catches_without_on_clauses` 鼓励更精确捕获，但跨边界顶层保护仍可能需要 catch all 并记录/rethrow。规则服务风险，不是追求全规则启用。

官方 linter 页面标记 stable/experimental/deprecated/removed；复制“所有规则”会引入互相冲突或不适合项目的约束。至少 core，通常 recommended，再基于项目调整。

## 21. AI/Vibe coding 的测试验收

接受 AI 生成测试前回答：

1. 每个用例对应什么失败风险？
2. 破坏实现时它真的会红吗？
3. matcher 是否验证类型和关键字段？
4. 异步 matcher 是否被 await/return？
5. Fixture 是否每用例独立？
6. Mock 是否复制了实现细节或理想化真实服务？
7. 时间、随机、网络是否可控？
8. teardown 是否等待所有清理？
9. format/analyze/test 的非零退出码会中止吗？
10. 哪些平台、SDK、Widget、真机从未运行？

AI 可以起草输入矩阵、Fake 和 matcher，但人必须选择 oracle、制造故障并解释日志。大量绿测试若无法在错误实现上红，比没有测试更危险，因为它制造错误信心。

## 22. 诊断实战流程

当 `dart test` 失败：先只运行失败文件，再按 name 运行单用例；读 expected/actual 和首个项目栈帧；确认失败来自生产代码还是 fixture；保存失败 seed；修复最小责任；重跑单用例、文件、完整门禁。不要立即把 matcher 改成 actual，也不要加 retry 掩盖抖动。

当 analyze 失败：读 diagnostic code 与行列；查官方规则说明；决定修代码还是规则不适用；若 ignore，写原因。自动 `dart fix` 前先看 dry-run/变更，运行测试并审查 diff。

当 format 失败：本地执行 formatter，确认只有预期文本变化；检查本机与 CI SDK。格式失败没有必要更改业务逻辑。

## 23. 120 秒复述与复习

复述模板：Dart 单元测试在 package 的 test 目录由 `dart test` 和 package:test 运行。测试名表达条件与结果，用 Arrange—Act—Assert，正常、边界、失败来自输入合同。同步异常把函数传给 `throwsA`，异步失败必须 await `expectLater`；matcher 应检查稳定类型和领域字段。每个用例重建可变 fixture，时间/随机/I/O 注入。能用真实小对象或 Fake 就不使用过度 Mock。质量门禁依次做只检查的 format、fatal analyze 和 test，并让任一步非零终止。最关键证据是故意破坏实现后测试会红，修复后完整门禁再绿；只声明实际运行的平台和版本。

越界反例：“AI 生成了 200 个 Mock 测试且覆盖率 100%，所以 Dart 3.12、Flutter Widget、真机网络和后端幂等全部验证完成。”它把行覆盖、Mock 合同和未执行平台混成结论。

复习题：

1. 为什么 `throwsA(anything)` 诊断力弱？
2. 同步抛错和 Future 失败的 matcher 写法有什么不同？
3. 忘记 await 为什么会假绿或污染下一用例？
4. Fake 与 Mock 的选择依据是什么？
5. format/analyze/test 各能证明什么、不能证明什么？
6. 为什么要随机化测试顺序？
7. lint ignore 应记录哪些理由？
8. 如何证明一个新测试真的有效？

## 24. 速查表

| 现象 | 首个可信证据 | 修复 |
|---|---|---|
| 测试太快且晚到报错 | 未 await 的 Future | async + await expectLater |
| 无关异常也绿 | 宽 matcher | 类型 + having 字段 |
| 单跑失败、全跑通过 | 共享 fixture/顺序依赖 | 每用例重建 + 固定 seed |
| Mock 绿、真实 parser 坏 | 测试绕过生产映射 | 只替换外部端口 |
| analyze 红但流水线绿 | `|| true`/管道退出码 | `set -euo pipefail` |
| format 来回变化 | SDK 不一致 | 固定并记录 SDK |
| teardown 后仍占资源 | 未 await cancel/close | 等待清理并断言计数 |
| 覆盖率高但 bug 存在 | 缺失败 oracle | mutation/边界测试 |

## 25. 官方资料与版本边界

资料于 2026-07-24 核对：

- [Dart testing](https://dart.dev/tools/testing)：unit/component/end-to-end 分层及 `package:test`、Mockito 等入口。
- [`dart test`](https://dart.dev/tools/dart-test)：默认 test 目录、按路径/name/tag 运行；Flutter 代码使用 `flutter test`。
- [`package:test` 1.31.2](https://pub.dev/packages/test)：`test/group/expect`、setUp/tearDown、异步测试、随机顺序、平台与配置。发布者为 dart.dev。
- [`dart format`](https://dart.dev/tools/dart-format)：`--output=none --set-exit-if-changed` 的非修改式 CI 检查及退出码。
- [Linter rules](https://dart.dev/tools/linter-rules)：规则状态、core/recommended 与 analyzer 使用。
- [`lints` 6.1.0](https://pub.dev/packages/lints)：Dart 团队官方 core/recommended 集合及 `analysis_options.yaml` 引入方式。
- [Dart command-line tool](https://dart.dev/tools/dart-tool)：create、format、analyze、test 等命令职责。
- [Dart SDK overview](https://dart.dev/tools/sdk)：当前文档基线 Dart 3.12.2 与 latest stable 支持政策。

稳定核心：测试隔离、可信 matcher、同步/异步错误区分、替身边界、故障注入、format/analyze/test 分层。版本表面：`package:test`/`lints` 版本、runner flags、默认并发/timeout、规则集合、formatter 输出与浏览器平台支持。

## 26. 已验证与未验证

已验证：example/lab/private 使用 Dart 3.9.2、`test` 1.31.0、`lints` 6.1.0 依次通过 pub get、format check、fatal analyze 和 dart test；公开 exercise 因错误实现稳定测试红；实验覆盖成功、边界、typed error、异步 matcher、每用例 Fake 隔离、调用记录与随机 seed。正文另对照 Dart 3.12.2 官方资料与当前 `test` 1.31.2 元数据。

未验证：Dart 3.12.2 二进制、Chrome/Node 测试平台、Flutter `flutter_test`/Widget、Mockito/build_runner、覆盖率工具、真实 HTTP/数据库、CI 容器、Windows/Linux、并发大套件性能、最新 patch 自动升级。门禁只验证配套纯 Dart package，不能外推为 FactoryCare 全应用质量。
