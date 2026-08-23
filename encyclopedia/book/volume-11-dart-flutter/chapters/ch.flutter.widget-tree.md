---
schema_version: 2
edition: 2026.2-draft
id: ch.flutter.widget-tree
title: MaterialApp、基础 Widget、Widget 树与 BuildContext
responsibility: 用 MaterialApp、Stateless/Stateful Widget、组合和 BuildContext 构建可解释 Widget 树，整合工具链与 Dart 对象能力，不提前教授复杂布局或异步生命周期。
volume: '11'
order: 11
level: L2
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.flutter.widget-tree.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.flutter.toolchain-project
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
  text: 在 120 秒内解释“MaterialApp、基础 Widget、Widget 树与 BuildContext”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - flutter-widget-composition
  - flutter-tree-context-runtime
  covers_topics:
  - flutter.widget-immutable-config
  - flutter.stateless-stateful-intro
  - flutter.widget-composition
  - flutter.material-app-scaffold
  - flutter.widget-element-render-intro
  - flutter.build-context
  - flutter.inherited-lookup
  - flutter.hot-reload-restart
  - dart.class-constructor
  uses_capabilities:
  - mobile.dart-language
  - mobile.flutter-tooling-widget
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现由多个小 Widget 组合的工单详情骨架并画出 Widget/Element/Context 关系；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - flutter-widget-composition
  - flutter-tree-context-runtime
  covers_topics:
  - flutter.widget-immutable-config
  - flutter.stateless-stateful-intro
  - flutter.widget-composition
  - flutter.material-app-scaffold
  - flutter.widget-element-render-intro
  - flutter.build-context
  - flutter.inherited-lookup
  - flutter.hot-reload-restart
  - dart.class-constructor
  uses_capabilities:
  - mobile.dart-language
  - mobile.flutter-tooling-widget
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: widget-tree-inspection-rebuild-counter-device-smoke
- id: diagnose
  kind: fault-diagnosis
  text: 面对“在错误 Context 查找祖先、在 build 中产生副作用或混淆 Widget 与状态身份”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - flutter-widget-composition
  - flutter-tree-context-runtime
  covers_topics:
  - flutter.widget-immutable-config
  - flutter.stateless-stateful-intro
  - flutter.widget-composition
  - flutter.material-app-scaffold
  - flutter.widget-element-render-intro
  - flutter.build-context
  - flutter.inherited-lookup
  - flutter.hot-reload-restart
  - dart.class-constructor
  uses_capabilities:
  - mobile.dart-language
  - mobile.flutter-tooling-widget
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# MaterialApp、基础 Widget、Widget 树与 BuildContext

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Flutter SDK、项目结构、run、hot reload 与 DevTools》](ch.flutter.toolchain-project.md)：Widget 树必须在稳定目标和 DevTools 中构建、重载与检查。
<!-- END GENERATED LEARNING PREREQUISITES -->

> Flutter UI 的基本方法不是“命令式地创建一个按钮后再修改它”，而是根据当前配置和状态描述一棵 Widget 树。框架把新描述与既有运行时元素协调，更新真正参与布局、绘制和交互的对象。本章先把这套身份模型讲清楚，再写工单详情骨架。

## 1. 从入口到第一棵 Widget 树

最小入口通常是：

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const FactoryCareApp());
}

class FactoryCareApp extends StatelessWidget {
  const FactoryCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FactoryCare',
      home: const WorkOrderPage(),
    );
  }
}
```

逐句理解：

- `main` 是 Dart 入口；Flutter 工具启动后最终执行它。
- `runApp` 接收根 Widget，把它挂到框架管理的视图中。
- `FactoryCareApp` 是一个不可变配置对象，不是屏幕像素本身。
- `const` 表示构造参数在编译时可确定时复用常量对象，减少不必要分配；它不是“这个页面永远不更新”。
- `build` 返回当前配置下的子树描述。
- `MaterialApp` 提供 Material 设计应用常用的主题、导航、本地化等上层能力。
- `home` 是默认页面入口；大型应用后续通常采用明确路由配置。

这里已经用到了 Dart 类、继承、构造函数、命名参数、`super.key` 与方法重写。Flutter 没有绕开语言基础，而是大量建立在 Dart 对象模型之上。

## 2. Widget 是不可变配置

Widget 类带有 `@immutable` 语义：它的字段通常是 `final`，构造后不在原对象上修改。页面变化时，框架会再次调用 `build`，产生新的 Widget 配置，然后与现有 Element 树协调。

```dart
class WorkOrderHeader extends StatelessWidget {
  const WorkOrderHeader({
    super.key,
    required this.code,
    required this.statusLabel,
  });

  final String code;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Text('$code · $statusLabel');
  }
}
```

如果工单状态从“待分配”变成“处理中”，上层以新值构造 `WorkOrderHeader`。不要写 `widget.statusLabel = '处理中'`；字段不可变，而且修改旧配置会破坏框架对新旧描述的比较模型。

不可变的好处包括：

- `build` 的输入更明确；
- 同一配置可安全共享或使用 `const`；
- 运行时状态与页面描述分离；
- 框架可以按类型与 key 协调节点身份。

不可变不代表所有对象都深度不可变。例如把可变 `List` 传进 `final` 字段，字段引用不能换，但列表内容仍可能变。对 UI 输入应优先传只读视图或创建防御性副本，避免框架不知道数据已被原地修改。

## 3. 组合优先：页面是一组小职责

Flutter 通过 Widget 组合构建 UI。不要从一开始就在单个 `build` 写数百行嵌套。FactoryCare 工单页可以先按职责拆解：

```text
FactoryCareApp
└─ MaterialApp
   └─ WorkOrderPage
      └─ Scaffold
         ├─ AppBar
         └─ WorkOrderDetails
            ├─ WorkOrderHeader
            ├─ DeviceSummary
            ├─ FaultDescription
            └─ ActionSection
```

拆分依据不是“每三行一个组件”，而是：有清晰名字和职责、有独立输入合同、可单独测试、会被复用、或能隔离重建/副作用边界。

```dart
class WorkOrderPage extends StatelessWidget {
  const WorkOrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    const order = WorkOrderViewData(
      code: 'WO-20260724-001',
      statusLabel: '处理中',
      deviceName: '一号循环泵',
      description: '轴承温度持续偏高',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('工单详情')),
      body: WorkOrderDetails(order: order),
    );
  }
}
```

本章使用静态 view data 练习树，不连接后端。真实项目中 Java API 是工单事实所有者，Flutter 将 API DTO 映射成客户端展示模型；不要让 UI 文案反向成为业务状态编码。

## 4. StatelessWidget 与 StatefulWidget

### 4.1 StatelessWidget

当一个 Widget 的输出只依赖构造参数与从 `BuildContext` 读取的上层依赖时，优先使用 `StatelessWidget`。它并非“永不重建”：父节点更新、Inherited 依赖变化或框架其他条件都可能让它再次 `build`。它只是没有独立的可变 `State` 对象。

```dart
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primaryContainer;
    return ColoredBox(
      color: color,
      child: Text(label),
    );
  }
}
```

这里输出依赖 `label` 和当前 Theme。Theme 改变时，即使 `label` 没变，Inherited 依赖也会触发相应重建。

### 4.2 StatefulWidget

当节点需要保存会随交互或生命周期变化、且其变化需要驱动 UI 的本地状态时，使用 `StatefulWidget`：

```dart
class ExpandableDescription extends StatefulWidget {
  const ExpandableDescription({
    super.key,
    required this.text,
  });

  final String text;

  @override
  State<ExpandableDescription> createState() =>
      _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          widget.text,
          maxLines: expanded ? null : 2,
        ),
        TextButton(
          onPressed: () {
            setState(() {
              expanded = !expanded;
            });
          },
          child: Text(expanded ? '收起' : '展开'),
        ),
      ],
    );
  }
}
```

`StatefulWidget` 本身仍不可变；可变字段放在关联的 `State`。`widget` 属性指向当前配置。`setState` 同步修改状态并告诉框架该 Element 需要重建；它不负责网络请求，也不自动取消任务。

复杂生命周期、异步竞态与请求取消属于后续状态生命周期章。本章只建立 Widget 与 State 分离的第一层模型。

### 4.3 不要把所有变量都放进 State

只有会影响 UI、且需要跨 build 保留的局部可变数据适合 State。以下通常不应成为字段：

- 可从其他状态立即推导的展示值；
- 每次 `build` 都能便宜计算的局部常量；
- 业务全局真相的客户端复制；
- 一次方法调用的临时变量。

状态越多，非法组合越多。`isLoading`、`error`、`items` 三个分散字段可能组合出“加载中且有错误且有旧数据”的语义难题；后续架构章会用显式状态模型约束它。

## 5. Widget、Element 与 RenderObject

理解三者能解释“为什么 Widget 经常创建却状态能保留”。

### 5.1 Widget：描述

Widget 是轻量、不可变的配置，描述“希望这里是什么”。一次重建可以产生大量短生命周期 Widget 对象。不要用对象引用把它想成屏幕上的永久控件。

### 5.2 Element：树中的身份与上下文

Element 是 Widget 在特定树位置的实例化。它持有父子关系，协调旧 Widget 与新 Widget，并把 Widget 连接到 State 或 RenderObject。`BuildContext` 接口实际由 Element 实现，因此 Context 表示的是“当前节点在这棵树里的位置”。

当父节点再次构建，框架比较同一位置的新旧 Widget。简化理解：若 `runtimeType` 与 `key` 匹配，通常更新既有 Element；不匹配则移除旧节点并创建新节点。State 能否保留与这个身份匹配有关。

### 5.3 RenderObject：布局、绘制与命中测试

部分 Widget 最终配置 RenderObject，由它参与约束、尺寸、位置、绘制和命中测试。不是每个 Widget 都对应独立 RenderObject：很多 Widget 只组合或传递信息。

简化关系：

```text
每次 build 产生 Widget 配置
          │ 更新/协调
          ▼
较稳定的 Element 树（Context、State、依赖）
          │ 配置
          ▼
RenderObject 树（布局、绘制、命中）
```

这个图是入门模型，不代表三棵树一一对应。Inspector 能帮助观察实际层级。

## 6. Key 决定同层级身份的补充线索

无 key 时，框架主要按同一父节点下的位置和类型协调。列表重排时，位置变化可能让 State 跟错业务项。Key 告诉框架“这个 Widget 对应哪个稳定身份”。

```dart
for (final order in orders)
  WorkOrderCard(
    key: ValueKey(order.id),
    order: order,
  )
```

`ValueKey(order.id)` 适用于同一父节点下具有稳定唯一业务 ID 的项。常见 key：

- `ValueKey`：按值比较，列表项常用；
- `ObjectKey`：按对象身份/相等性；
- `UniqueKey`：每次都不同，会强制视为新身份，不能用来“优化”；
- `GlobalKey`：可跨位置唯一识别并访问 State/Context，能力强、成本和耦合也高，应谨慎。

Key 只在同一父级的兄弟协调中有意义。给每个节点随便加 key 不会自动提升性能；每次 build 新建 `UniqueKey` 反而会丢 State。

## 7. BuildContext 是位置，不是全局服务容器

`BuildContext` 能从当前 Element 沿祖先查找主题、媒体、本地化、Navigator、ScaffoldMessenger 和自定义 Inherited 数据。它的可见范围由树位置决定。

```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  return Text(
    '工单详情',
    style: theme.textTheme.titleLarge,
  );
}
```

Context 不是一个到处长期保存的全局句柄。节点卸载后，它不再适合更新 UI；跨异步间隔使用前需要检查当前 context 是否仍 mounted，具体在生命周期章学习。

### 7.1 为什么“错误 Context”会找不到祖先

下面代码在创建 `Scaffold` 的同一个 `build` context 上调用 `Scaffold.of`。这个 context 位于
Scaffold 之上，因此确定找不到刚返回的 ScaffoldState：

```dart
Widget build(BuildContext context) {
  return Scaffold(
    body: TextButton(
      onPressed: () {
        Scaffold.of(context).showBottomSheet(
          (_) => const Text('已保存'),
        );
      },
      child: const Text('保存'),
    ),
  );
}
```

这里使用 `Scaffold.of` 而不是 `ScaffoldMessenger.of`，是为了让失败形状确定：MaterialApp 常在
路由之上提供 ScaffoldMessenger，但不会在当前页面的 Scaffold 之上再放一个同页 Scaffold。
要获得新 Scaffold 之下的 context，可以抽出子 Widget 或使用 `Builder`：

```dart
return Scaffold(
  body: Builder(
    builder: (innerContext) {
      return TextButton(
        onPressed: () {
          Scaffold.of(innerContext).showBottomSheet(
            (_) => const Text('已保存'),
          );
        },
        child: const Text('保存'),
      );
    },
  ),
);
```

不要机械背“加 Builder”。先画出调用 `of(context)` 的 Element 与目标 Inherited 祖先位置；若祖先根本不存在，加多少 Builder 都无效。

## 8. Inherited 查找与依赖登记

`Theme.of(context)`、`MediaQuery.of(context)` 等通常通过 InheritedWidget/InheritedModel 一类机制向下提供数据。调用依赖式查找时，当前 Element 会登记依赖；上层相关值变化后，框架通知依赖者重建。

概念示例：

```dart
class WorkshopScope extends InheritedWidget {
  const WorkshopScope({
    super.key,
    required this.siteName,
    required super.child,
  });

  final String siteName;

  static WorkshopScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<WorkshopScope>();
    assert(scope != null, 'WorkshopScope not found above this context');
    return scope!;
  }

  @override
  bool updateShouldNotify(WorkshopScope oldWidget) =>
      siteName != oldWidget.siteName;
}
```

子节点用 `WorkshopScope.of(context).siteName`。当 `siteName` 改变且 `updateShouldNotify` 返回 true，依赖者重建。

真实项目常用 Provider/Riverpod 等更完整方案，但底层“向下提供、按 context 读取、变化通知依赖”模型仍重要。本章不选状态管理库；后续架构状态章再比较。

## 9. build 必须接近纯描述

框架可以在很多时机调用 `build`，调用次数不应成为业务语义。以下行为不要直接放在 build：

- 发起网络请求；
- 写数据库/Storage；
- 发送埋点或消息；
- `setState`；
- 创建每次必须 dispose 的控制器而不管理生命周期；
- 依赖“build 只执行一次”的计数逻辑。

错误示例：

```dart
@override
Widget build(BuildContext context) {
  repository.loadOrder(); // 每次重建都可能重复请求
  return const Text('加载中');
}
```

`build` 应根据已有输入返回 UI 描述。请求何时触发、怎样取消、旧响应如何避免覆盖新响应，在生命周期章处理。读取 Theme 和构造短生命周期 Widget 是正常的。

### 9.1 调试 build 次数

可以临时增加受控计数或使用 DevTools 的 rebuild 观察能力，但不要把 debug 计数当产品逻辑。一次点击引发多个节点重建不一定是错误；判断要看范围、频率、工作量和帧性能。

## 10. MaterialApp 与 Scaffold 的职责

### 10.1 MaterialApp

`MaterialApp` 是 Material 应用外壳，常管理：

- theme/darkTheme/themeMode；
- Navigator 路由入口；
- Locale 与本地化代理；
- 文本方向、MediaQuery 等上层能力；
- 调试标识和 builder。

通常应用只有一个顶层 `MaterialApp`。在每个页面再包一个，可能生成新的 Navigator、Theme 和 ScaffoldMessenger 边界，造成 context 查找与返回行为混乱。测试小部件时可用最小 MaterialApp 作为测试宿主。

### 10.2 Scaffold

`Scaffold` 提供 Material 页面结构槽位，如 appBar、body、floatingActionButton、drawer、bottomNavigationBar。它不是所有布局的万能容器，也不是每个小组件都需要一个 Scaffold。

```dart
return MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    useMaterial3: true,
  ),
  home: Scaffold(
    appBar: AppBar(title: const Text('FactoryCare')),
    body: const WorkOrderDetails(order: sampleOrder),
  ),
);
```

主题应尽量集中表达设计 token，而不是每个 Text/Button 硬编码颜色。详细布局与无障碍在下一章。

## 11. 一个可解释的工单详情骨架

先定义不可变展示数据：

```dart
class WorkOrderViewData {
  const WorkOrderViewData({
    required this.id,
    required this.code,
    required this.statusLabel,
    required this.deviceName,
    required this.description,
  });

  final int id;
  final String code;
  final String statusLabel;
  final String deviceName;
  final String description;
}
```

再组合：

```dart
class WorkOrderDetails extends StatelessWidget {
  const WorkOrderDetails({super.key, required this.order});

  final WorkOrderViewData order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkOrderHeader(
          code: order.code,
          statusLabel: order.statusLabel,
        ),
        DeviceSummary(name: order.deviceName),
        ExpandableDescription(
          key: ValueKey('description-${order.id}'),
          text: order.description,
        ),
      ],
    );
  }
}
```

这段代码使用了 `Column`，但本章不深入约束与溢出。当前验收是树的职责、输入、身份和 Context 合理，而不是视觉适配完成。

### 11.1 画出三类节点

对 `ExpandableDescription`：

```text
Widget 配置：ExpandableDescription(text, key)
        │ create/update
StatefulElement（BuildContext，树位置）
        │ 持有
_ExpandableDescriptionState(expanded)
        │ build 返回
Column/Text/TextButton 等子 Widget
```

父节点以相同 type + key 更新时，Element/State 通常保留，`widget` 指向新配置；key 改变或节点被移除时，旧 State 会卸载。

## 12. 常见错误与定位

### 12.1 在 build 里请求

症状：一次页面操作触发多次接口，日志数量与预期不符。

首个证据：请求日志与 build 计数具有相关性，请求调用栈位于 build。

修复：把副作用移动到明确生命周期/事件或状态层；保持 build 只描述已有状态。修复后重复相同操作，比较调用次数。

### 12.2 Context 位于提供者上方

症状：`Theme.of` 得到意外主题、`ProviderNotFound`、`Navigator.of` 找不到目标导航器等。

首个证据：Inspector 树与异常指出的 context 位置。画出提供者和消费者之间的祖先关系。

修复：移动调用位置、抽子 Widget 或在正确层级用 Builder；不要用全局 context 掩盖结构。

### 12.3 列表重排后本地状态跟错项

症状：展开 A 后排序，B 显示展开。

首个证据：兄弟节点同类型且无稳定 key，State 按位置被复用。

修复：用稳定业务 ID 的 `ValueKey`；重排并检查 State 跟随业务项。

### 12.4 用 UniqueKey 试图修复所有问题

症状：输入框、滚动或展开状态每次重建都丢失。

原因：每个 UniqueKey 都不同，框架认为旧节点被移除。

修复：确定真正业务身份，使用稳定 key；如果状态本就不应保留，则显式说明。

### 12.5 修改 Widget 字段

症状：编译器提示 final 不可赋值，或可变输入原地变化但 UI 不更新。

修复：产生新配置，通过 State/上层状态触发重建；集合使用不可变更新。Widget 是描述，不是可命令修改的控件实例。

## 13. DevTools Inspector 实验

在可用 Flutter 目标运行本章骨架：

1. 打开 Inspector，选中 `WorkOrderHeader` 与 `Text`；
2. 记录 Widget 层级和它对应的 Element/RenderObject 信息；
3. 开启受控 rebuild 观察；
4. 点击展开按钮，记录哪些节点重建；
5. 只改静态文字并 hot reload，观察 State 是否保留；
6. hot restart，观察展开状态是否丢失；
7. 把列表项无 key 重排，复现状态错位；再加 `ValueKey` 重跑。

设备与 Inspector 输出因版本不同，仓库离线验证不能替代此步骤。保存：Flutter 版本、device ID、操作序列、树截图、控制台日志和结论限制。

## 14. Widget 测试的第一步

Widget 测试可在测试环境中挂载小树：

```dart
testWidgets('shows work order code and status', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: WorkOrderPage(),
    ),
  );

  expect(find.text('WO-20260724-001'), findsOneWidget);
  expect(find.text('处理中'), findsOneWidget);
});
```

它验证当前树能找到预期文本，不自动证明视觉布局、可访问语义、真实设备和后端集成。测试名称要写可观察行为，失败时能看出哪份合同被破坏。

可给展开行为写测试：先断言“展开”存在，tap 后 `pump`，再断言“收起”。如果有动画，使用有界 `pump`/`pumpAndSettle`，避免无限动画让测试挂起。

## 15. 自测与参考答案

1. **Widget 是屏幕上的持久对象吗？** 不是，它是不可变配置；Element 提供树位置和协调身份，RenderObject 参与布局绘制。
2. **StatelessWidget 会不会重建？** 会。它只是没有独立 State；父更新或 Inherited 依赖变化都可触发 build。
3. **StatefulWidget 的可变数据放在哪？** 关联 State 对象，而 Widget 配置仍不可变。
4. **BuildContext 表示什么？** 当前 Element 在树中的位置和可向上查找的环境，不是全局服务定位器。
5. **为什么 build 中不能请求接口？** build 可被重复调用，副作用会重复且时序不可控。
6. **Key 的主要用途是什么？** 在同一父节点的兄弟协调中补充稳定身份，尤其是重排列表。
7. **每次用 UniqueKey 会怎样？** 框架认为是新节点，旧 State 被丢弃。
8. **为什么常量 Widget 仍可显示变化的上层主题？** const 复用配置对象不冻结整个 Element/Inherited 依赖树。
9. **何时用 Builder？** 需要获得某个新祖先之下的 context 时；前提是画清祖先关系。
10. **本章越界反例？** 在此详细实现网络取消、复杂响应式布局或选定全局状态管理库。

## 16. 章节验收

- [ ] 能从 `main`、`runApp`、MaterialApp 到页面画出 Widget 树。
- [ ] 能解释 Widget 不可变及新配置如何更新既有 Element。
- [ ] 能区分 StatelessWidget、StatefulWidget 与 State。
- [ ] 能用职责和输入合同拆分工单详情的小 Widget。
- [ ] 能解释 Widget、Element、BuildContext、State、RenderObject 的入门关系。
- [ ] 能根据稳定业务身份选择 ValueKey，并复现无 key 的状态错位。
- [ ] 能画出 `of(context)` 的祖先查找路径，修复错误 Context。
- [ ] 能指出 build 中的副作用并迁移到明确边界。
- [ ] 能运行最小 Widget 测试；若未连接真实设备，明确写未验证。

## 17. 官方资料与更新检查

- Flutter architectural overview：<https://docs.flutter.dev/resources/architectural-overview>
- Introduction to widgets：<https://docs.flutter.dev/ui/widgets-intro>
- BuildContext API：<https://api.flutter.dev/flutter/widgets/BuildContext-class.html>
- Widget API：<https://api.flutter.dev/flutter/widgets/Widget-class.html>
- Keys：<https://api.flutter.dev/flutter/foundation/Key-class.html>
- Inspector：<https://docs.flutter.dev/tools/devtools/inspector>

资料核对日期：2026-07-24。API 细节、Material 默认表现和 DevTools 界面会随 Flutter stable 变化；不可变配置、树位置、协调身份、纯描述 build 与证据边界是应长期掌握的核心模型。
