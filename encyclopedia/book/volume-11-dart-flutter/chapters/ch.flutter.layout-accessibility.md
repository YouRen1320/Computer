---
schema_version: 2
edition: 2026.2-draft
id: ch.flutter.layout-accessibility
title: 约束布局、响应式、渲染与无障碍
responsibility: 按 constraints-down/sizes-up 建立 Row/Column/Flex/Stack/滚动布局，适配尺寸和文本缩放，并落实语义、键盘/触控与减少动效。
volume: '11'
order: 12
level: L2
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.flutter.layout-accessibility.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.flutter.widget-tree
- ch.web.accessibility-interaction
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
  text: 在 120 秒内解释“约束布局、响应式、渲染与无障碍”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - flutter-constraint-layout
  - flutter-responsive-a11y
  covers_topics:
  - flutter.box-constraints
  - flutter.row-column-flex
  - flutter.stack-positioned
  - flutter.scrollable-layout
  - flutter.layout-overflow
  - flutter.mediaquery-layoutbuilder
  - flutter.text-scaling
  - flutter.semantics
  - flutter.focus-traversal
  - flutter.touch-target
  uses_capabilities:
  - mobile.flutter-tooling-widget
  - web.accessibility
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现可适配窄屏、长文本和放大字体的可访问工单详情布局；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - flutter-constraint-layout
  - flutter-responsive-a11y
  covers_topics:
  - flutter.box-constraints
  - flutter.row-column-flex
  - flutter.stack-positioned
  - flutter.scrollable-layout
  - flutter.layout-overflow
  - flutter.mediaquery-layoutbuilder
  - flutter.text-scaling
  - flutter.semantics
  - flutter.focus-traversal
  - flutter.touch-target
  uses_capabilities:
  - mobile.flutter-tooling-widget
  - web.accessibility
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: constraint-case-matrix-semantics-inspection-golden-baseline-intro
- id: diagnose
  kind: fault-diagnosis
  text: 面对“unbounded constraint、Row 溢出或缺失 Semantics 导致的布局与无障碍失败”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - flutter-constraint-layout
  - flutter-responsive-a11y
  covers_topics:
  - flutter.box-constraints
  - flutter.row-column-flex
  - flutter.stack-positioned
  - flutter.scrollable-layout
  - flutter.layout-overflow
  - flutter.mediaquery-layoutbuilder
  - flutter.text-scaling
  - flutter.semantics
  - flutter.focus-traversal
  - flutter.touch-target
  uses_capabilities:
  - mobile.flutter-tooling-widget
  - web.accessibility
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# 约束布局、响应式、渲染与无障碍

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《MaterialApp、基础 Widget、Widget 树与 BuildContext》](ch.flutter.widget-tree.md)：布局 Widget 和语义节点必须位于可解释的 Widget/Element/Context 树中。
- [《无障碍、键盘、焦点与屏幕阅读器》](../../volume-07-web-platform/chapters/ch.web.accessibility-interaction.md)：键盘、焦点、可访问名称和减少动效原则可迁移到 Flutter 平台实现。
<!-- END GENERATED LEARNING PREREQUISITES -->

> Flutter 布局的核心不是记住每个 Widget 参数，而是沿树追踪合同：父节点把约束传给子节点，子节点在约束内选择尺寸，父节点决定子节点位置。布局“看起来没问题”也不等于可用；窄屏、长文本、文本放大、RTL、键盘、触控和读屏语义都必须进入验收矩阵。

## 1. BoxConstraints：先问“允许多大”

Flutter 常见盒模型用 `BoxConstraints` 表达宽高范围：

```text
minWidth  ≤ width  ≤ maxWidth
minHeight ≤ height ≤ maxHeight
```

紧约束（tight）要求某个确定尺寸，例如 `minWidth == maxWidth`。松约束（loose）允许从零到上限。无界（unbounded）表示某方向上限为无穷，并不表示所有子节点都能选择无穷尺寸。

官方入门规则可以概括为：

1. Constraints go down：父把允许范围向下传；
2. Sizes go up：子在范围内选尺寸并向上报告；
3. Parent sets position：父根据布局算法摆放子节点。

这三句解释了很多“我给 Container 写 width 为什么不生效”：`width` 只是子节点想要的尺寸，还要受父约束限制。屏幕根节点通常把接近屏幕大小的紧约束传下；若外层要求铺满，内层写 100 也可能被迫铺满。

### 1.1 约束、尺寸和位置不要混为一谈

- 约束是允许范围，由父传给子；
- 尺寸是子在范围内选择后报告的结果；
- 位置是父决定的偏移；
- 绘制可以超出尺寸，但通常会产生裁剪、命中和语义问题，不能用来绕过布局。

Inspector 中查看 RenderObject 的 constraints 与 size，比反复猜 `width` 更可靠。

### 1.2 ConstrainedBox、SizedBox 与约束交集

`SizedBox(width: 200)` 常尝试给子节点紧宽度 200，但上层若只允许最大 120，最终仍须满足上层。`ConstrainedBox` 增加约束，框架会把它与父约束合并。

```dart
ConstrainedBox(
  constraints: const BoxConstraints(
    minWidth: 120,
    maxWidth: 320,
  ),
  child: const Text('工单摘要'),
)
```

不能通过内部约束突破父上限。若需求确实要更大，应改变上层布局（例如可滚动、换行或响应式重排），而不是继续嵌套 SizedBox。

## 2. Row、Column 与 Flex 的两阶段思维

`Row` 在水平方向排列子节点，`Column` 在垂直方向排列。它们都是 Flex 家族，涉及主轴与交叉轴：

- Row 主轴水平，Column 主轴垂直；
- `mainAxisAlignment` 分配主轴剩余空间；
- `crossAxisAlignment` 控制交叉轴对齐；
- `mainAxisSize` 决定主轴尽量大或尽量小。

### 2.1 为什么 Row 容易溢出

Row 的非 flex 子节点可能先按较宽的自然尺寸布局。两个长文本加固定按钮总宽超过屏幕时，出现黄黑溢出提示。它是开发期的可靠证据，不应通过隐藏 debug 条纹假装修复。

错误倾向：

```dart
Row(
  children: [
    Text(order.longDeviceName),
    const Text('处理中'),
  ],
)
```

给主要文本明确剩余空间合同：

```dart
Row(
  children: [
    Expanded(
      child: Text(
        order.longDeviceName,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    const SizedBox(width: 8),
    StatusBadge(label: order.statusLabel),
  ],
)
```

但省略号不是默认正确答案。设备名称若是关键识别信息，放大字体下截断可能造成误操作，应考虑允许两行、把状态移到下一行，或在窄宽断点改 Column。

### 2.2 Expanded 与 Flexible

`Expanded` 相当于 `Flexible(fit: FlexFit.tight)`，要求占用分配到的主轴空间。`Flexible` 的 loose fit 允许子节点比份额更小。

它们必须位于合适的 Flex 祖先下。把 Expanded 放进非 Flex 父级或隔着不兼容 ParentDataWidget 会得到明确异常。读错误里 “Incorrect use of ParentDataWidget” 和祖先链，不要只删 Expanded。

### 2.3 Flex 与无界主轴

Column 放进垂直滚动区域时，主轴可能无界；其中再放 Expanded，意思变成“占满无限剩余高度”，无法求解，常出现 “non-zero flex but incoming height constraints are unbounded”。

修复需要明确需求：

- 内容自然增长并由外层滚动：移除 Expanded，让子按内容尺寸；
- 某区域要占满视口：通过 `LayoutBuilder`、`ConstrainedBox` 等提供有限最小/最大合同；
- 固定头部、列表填满剩余：不要把整个 Column 放 SingleChildScrollView，改用 Column + Expanded(ListView)；
- 复杂滚动组合：使用 CustomScrollView/sliver。

不能把 `shrinkWrap: true` 当通用补丁；它会改变测量成本，长列表可能每次计算更多子项。

## 3. Stack 与 Positioned

`Stack` 适合重叠，如图片上的状态角标；`Positioned` 让子节点相对 Stack 边界定位。

```dart
Stack(
  children: [
    const DeviceImage(),
    PositionedDirectional(
      top: 8,
      end: 8,
      child: StatusBadge(label: order.statusLabel),
    ),
  ],
)
```

优先 `PositionedDirectional(start/end)` 而不是只用 left/right，以适配 RTL。Stack 不是普通表单布局工具；绝对位置遇到文本放大、翻译变长和屏幕变化很容易重叠。

Stack 的非 positioned 子节点参与决定尺寸；positioned 子节点受对应边约束。若 Stack 自身没有有限尺寸，定位结果可能不符合预期。先查 Stack 获得的 constraints/size，再查 child。

## 4. 滚动布局：只有一个明确的滚动所有者

内容可能超出视口时，需要滚动策略。

### 4.1 SingleChildScrollView

适合子内容整体不长、通常能放下、偶尔因小屏/键盘/文本放大需要滚动的页面。它会布局整个 child，不适合成百上千项。

```dart
SafeArea(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: WorkOrderDetails(order: order),
  ),
)
```

### 4.2 ListView

适合列表，builder 构造可见附近项：

```dart
ListView.builder(
  itemCount: orders.length,
  itemBuilder: (context, index) {
    final order = orders[index];
    return WorkOrderCard(
      key: ValueKey(order.id),
      order: order,
    );
  },
)
```

不要把一个不可滚动的长 ListView 随便塞进另一个滚动视图，再靠 `shrinkWrap` 和禁用滚动拼起来。小数据可能可用，但复杂页面应明确由谁滚动，必要时用 sliver 组合头部和列表。

### 4.3 键盘与底部遮挡

表单打开软键盘后可用视口变化。Scaffold 的 inset 行为、滚动容器、焦点目标和底部按钮需要一起测试。不要用固定屏幕高度计算；读取 MediaQuery 的 viewInsets 也要理解上下文与目标窗口。

## 5. SafeArea、Padding 与系统边界

刘海、状态栏、圆角、手势区域会占用安全区域。`SafeArea` 使用 MediaQuery padding 避免内容进入系统遮挡区。

它不是所有页面最外层无脑包裹：AppBar/Scaffold 已处理部分区域，沉浸式背景可能应延伸到边缘而内容仍需 inset。要分清背景和交互内容。

Padding 表达设计间距，不应通过空 Text、重复 SizedBox 随意堆出布局。集中使用设计 token，例如 4/8/12/16/24 的间距尺度，有助于一致性和响应式调整。

## 6. 响应式不是按设备型号写 if

“iPhone 用 A，Android 用 B”不是可靠布局策略。窗口可以分屏、旋转、桌面缩放，设备型号也不会告诉你当前可用宽度。

### 6.1 MediaQuery 与 LayoutBuilder

`MediaQuery` 提供当前视图的尺寸、文本缩放、系统 padding、亮度、减少动画等环境信息。`LayoutBuilder` 提供父节点在此位置传下来的 constraints。

选择原则：

- 页面级布局关注整个窗口，可读 MediaQuery；
- 可复用组件应根据自己实际获得的约束响应，优先 LayoutBuilder；
- 不要在很多深层节点重复读取全屏宽度后做互相矛盾的断点。

```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth >= 720) {
      return WorkOrderTwoPane(order: order);
    }
    return WorkOrderSingleColumn(order: order);
  },
)
```

断点 720 不是宇宙常数。它来自内容何时无法舒适展示，需要用长文、放大字体和目标窗口实验决定。记录断点理由，避免全项目散落魔法数。

### 6.2 响应式与自适应

- responsive：同一设计根据可用空间重排、伸缩；
- adaptive：根据平台能力/惯例选择不同交互或组件。

两者可组合，但平台判断不能代替空间判断。桌面窄窗口可能需要单列，平板分屏也可能很窄。

## 7. 文本缩放与长文本

用户可能把系统字体放大。不要通过固定 `textScaleFactor: 1` 禁用可访问设置。Flutter 新版本围绕 `TextScaler` 演进，代码应以当前 API 为准，但验收原则稳定：关键信息在目标缩放范围内可读、可操作、不遮挡。

检查：

- 标题是否换行而非裁掉关键编号；
- 按钮高度是否能容纳放大文字；
- Row 是否应切为 Column/Wrap；
- 固定高度 Card 是否溢出；
- 状态是否只靠颜色；
- 文本缩放后焦点顺序和滚动是否仍可达。

长中文、英文、德文等语言长度不同；工单描述还可能包含无空格的编号。至少用真实极端 fixture，不要只测“测试设备”。

```dart
const stressOrder = WorkOrderViewData(
  code: 'WO-20260724-EXTREMELY-LONG-000001',
  statusLabel: '等待供应商提供备件后继续处理',
  deviceName: '北区污水处理站一号高压循环泵及备用控制柜',
  description: '这里放多段真实长度的故障描述……',
);
```

## 8. RTL 与 Directionality

阿拉伯语、希伯来语等从右向左。使用方向感知 API：

- `EdgeInsetsDirectional.only(start: …, end: …)`；
- `AlignmentDirectional`；
- `PositionedDirectional`；
- start/end，而非到处写 left/right。

图标是否镜像取决于语义，例如返回箭头通常应随方向，品牌标识不一定。RTL 测试不能只把文本换成阿拉伯语，还要检查排列、焦点、手势和图标。

## 9. Semantics：让辅助技术理解界面

Flutter 构建 Semantics 树，向 Android/iOS/Web 等平台的无障碍服务描述标签、值、状态、角色与操作。许多 Material Widget 自带合理语义，但自定义组合、Canvas 绘制、仅图标按钮仍需检查。

### 9.1 可访问名称

仅图标按钮要有 tooltip/semantic label：

```dart
IconButton(
  tooltip: '刷新工单',
  onPressed: onRefresh,
  icon: const Icon(Icons.refresh),
)
```

不要把文件名、内部 enum 或视觉位置当名称。名称应说明目的，例如“关闭工单详情”，而非“右上角叉号”。

### 9.2 合并与排除语义

一个工单卡可能包含多段文本。读屏逐个读所有装饰节点会冗余，可以使用 `MergeSemantics` 或一个明确 Semantics 容器组合；装饰图片可 `ExcludeSemantics`，但不能排除承载信息的内容。

```dart
Semantics(
  container: true,
  label: '工单 ${order.code}',
  value: '${order.deviceName}，状态 ${order.statusLabel}',
  button: true,
  onTap: onOpen,
  child: ExcludeSemantics(
    child: WorkOrderCardVisual(order: order),
  ),
)
```

这里把整个卡当按钮前提是整卡确实可点击。不要为了让检查通过而声明虚假 `button` 或 `onTap`。语义树必须与真实交互一致。

### 9.3 不要重复朗读

外层 Semantics 写完整 label，内层文字又被读屏读取，可能重复。用 Semantics Debugger/Inspector 检查实际树并在 TalkBack/VoiceOver 上走一遍。自动测试只能覆盖部分节点属性，不能完全替代真实辅助技术。

## 10. 焦点、键盘与遍历顺序

Flutter 桌面、Web、外接键盘、无障碍开关控制都需要焦点。原生按钮通常可聚焦；GestureDetector 包住 Container 可能只有点击手势，没有正确语义、键盘激活和焦点反馈。

优先使用语义完整的 Button、IconButton、ListTile 等。自定义控件需考虑：

- 能否获得焦点；
- Enter/Space 是否激活；
- 是否有可见焦点指示；
- Tab/方向键顺序是否符合阅读顺序；
- disabled 状态是否可感知；
- 焦点是否会进入不可见/遮挡区域。

`FocusTraversalGroup`、排序策略等可以调整复杂区域，但默认先让源码顺序、视觉顺序与语义顺序一致。滥用显式 order 会形成难维护的另一棵顺序树。

弹窗打开时焦点应进入弹窗，关闭后回到触发点；这需要在导航与表单章继续实践。

## 11. 触控目标与手势冲突

可见图标 18×18 不代表可点击区域只能 18×18。交互目标要足够大并留出间距。Material 组件通常提供最小交互尺寸，但自定义 `GestureDetector` 不会自动保证。

验收时检查：

- 目标尺寸；
- 相邻按钮是否太近；
- 放大字体是否压缩目标；
- 单击、双击、长按是否冲突；
- 滑动列表与横向手势是否争夺；
- disabled 是否仍拦截点击。

具体平台指南数值会变化，遵循当前 Material/Apple/Android 指南并保存版本。比死背数字更重要的是用 inspector/测试测量实际语义与命中区域。

## 12. 颜色、对比度与非颜色线索

状态不能只靠红/绿。为“逾期”“正常”提供文字、图标或形状，并验证颜色对比。Flutter 主题的默认组合通常考虑对比，但自定义 ColorScheme 或在图片背景上放字仍需检测。

错误示例：两张无文字的圆点只用颜色区分。改为：图标 + 明确状态文字 + 合理颜色。高对比模式、深色主题和 OLED/阳光环境也应在目标矩阵考虑。

## 13. 减少动效与动画边界

部分用户会开启“减少动态效果”。读取当前平台/MediaQuery 暴露的可访问特性，减少非必要大幅移动、视差和闪烁。不要简单关闭所有反馈：状态变化仍需可理解，可以用淡入、即时切换或较短动画替代。

动画不能成为唯一信息通道。加载中要有语义状态；完成后读屏能收到合理更新。闪烁内容还涉及健康风险，遵守平台和 WCAG 相关要求。

## 14. Golden、Widget 与语义测试各证明什么

### 14.1 Widget 测试

用固定 surface size 和文本缩放挂载页面，检查找不到溢出异常、关键内容存在、操作可达。可以读取 tester 异常：

```dart
await tester.binding.setSurfaceSize(const Size(320, 640));
await tester.pumpWidget(buildTestApp(textScaler: const TextScaler.linear(2)));
expect(tester.takeException(), isNull);
```

测试结束恢复 surface size，避免污染后续测试。API 以当前 Flutter 版本为准。

### 14.2 Semantics 测试

启用 semantics handle 后，断言关键节点具有 label、button/enabled 等正确属性。不要只断言“存在一个 Semantics”；要核对名称、角色、状态和操作。

### 14.3 Golden 测试

Golden 把渲染与基线图片比较，适合发现像素变化。它可能受字体、平台、渲染器和版本影响，需要固定环境与审查更新。Golden 通过不证明语义正确，像素差异也不一定是缺陷。

三者与真机/读屏互补：

| 证据 | 擅长 | 不能单独证明 |
| --- | --- | --- |
| Widget 测试 | 树、交互、异常 | 真实平台体验 |
| Semantics 测试 | 标签/角色/状态合同 | TalkBack/VoiceOver 完整行为 |
| Golden | 视觉回归 | 语义和业务正确 |
| 真机矩阵 | 实际布局与输入 | 所有未来设备 |
| 读屏人工走查 | 朗读、顺序、操作 | 自动持续回归 |

## 15. FactoryCare 响应式可访问工单页

页面策略：

- 窄宽：单列，标题/状态允许重排，页面整体滚动；
- 中宽：设备信息与工单元数据可双列；
- 宽屏：列表/详情双 pane，但焦点与语义顺序仍合理；
- 文本放大：不依赖固定卡片高度；关键编号、设备名和操作不截断；
- RTL：使用 Directional spacing；
- 交互：IconButton 有 tooltip，主按钮支持键盘和读屏。

```dart
class ResponsiveWorkOrderDetails extends StatelessWidget {
  const ResponsiveWorkOrderDetails({
    super.key,
    required this.order,
  });

  final WorkOrderViewData order;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final content = wide
            ? WorkOrderTwoColumn(order: order)
            : WorkOrderSingleColumn(order: order);

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: content,
            ),
          ),
        );
      },
    );
  }
}
```

注意：若父宽大于 1120，`ConstrainedBox` 只限制内容宽，仍需用 Align/Center 决定位置；否则父最终位置可能不是期望。每层都按约束—尺寸—位置分析。

## 16. 故障诊断

### 16.1 RenderFlex overflow

症状：黄黑条，日志指出 overflow 像素与方向。

首个证据：错误中的 RenderFlex 方向和树路径；Inspector 查看父约束与每个 child size。

错误修复：随便包 SingleChildScrollView 或缩小字体。正确修复取决于信息优先级：Expanded、Wrap、允许换行、响应式重排或滚动。

重跑：320/600/1024 宽、长文本、2× 文本缩放、RTL。

### 16.2 unbounded constraint + Expanded

症状：Flex 在无界主轴有非零 flex。

首个证据：异常文本和滚动祖先。画出外层 scroll 在主轴提供无界约束，Expanded 又要求填满剩余。

修复：选择明确滚动所有者，移除不合理 flex 或提供有限视口合同。重跑长/短内容。

### 16.3 语义缺失

症状：读屏只说“按钮”或完全跳过自定义控件；自动 semantics 树没有名称/操作。

首个证据：Semantics Inspector 和读屏焦点实际输出。

修复：优先语义完整组件；自定义时声明真实 label/value/role/action，去除重复。重跑自动语义断言与真机读屏。

### 16.4 固定高度在大字体下溢出

症状：文字被裁或按钮不可见。

首个证据：固定 height 与文本实际布局；在系统大字体复现。

修复：移除不必要固定高度，使用最小约束、padding 和自然增长；必要时响应式重排。不能禁用文本缩放。

### 16.5 视觉顺序和焦点顺序不一致

症状：Tab/读屏在页面上来回跳。

首个证据：记录焦点序列并与树/视觉布局对照。Stack、源码重排或显式 traversal order 常是原因。

修复：优先统一源码、视觉与语义顺序；复杂场景再用 traversal group。重跑键盘和读屏。

## 17. 实验矩阵

对同一工单详情执行：

| 场景 | 最小输入 | 期望证据 |
| --- | --- | --- |
| 窄屏 | 320×640 | 无 overflow，主操作可达 |
| 常规手机 | 390×844 | 单列信息完整 |
| 平板/桌面 | 1024×768 | 断点重排，无过宽文字 |
| 长中文 | 设备名 30+ 字 | 关键信息不误截断 |
| 文本缩放 | 1.0、1.5、2.0 | 无固定高度裁剪 |
| RTL | Directionality.rtl | start/end 与焦点合理 |
| 键盘 | Tab/Shift+Tab/Enter | 顺序、激活、焦点可见 |
| 读屏 | TalkBack/VoiceOver | 名称、角色、状态、操作正确 |
| 减少动效 | 系统设置开启 | 非必要大幅动效减少 |

每个场景保存自动测试结果和人工验证状态。没有真实读屏就写 `unverified`，不要因为 semantics 单测绿而写“无障碍通过”。

## 18. 自测与参考答案

1. **Flutter 布局三句规则？** 父约束向下，子尺寸向上，父决定位置。
2. **为什么给子节点 width 200 可能无效？** 父约束优先，子只能在允许范围选尺寸。
3. **为什么 scroll 中 Column + Expanded 常失败？** 滚动主轴可能无界，Expanded 要填满无限剩余空间。
4. **Row 溢出一定用 ellipsis 吗？** 不一定；关键内容可能需要换行或响应式重排。
5. **LayoutBuilder 与 MediaQuery 区别？** 前者看当前位置父约束，后者看视图/系统环境。
6. **为什么不能锁死文本缩放？** 会剥夺用户可访问设置并掩盖布局缺陷。
7. **Semantics label 写了就算无障碍完成吗？** 不算，还要角色、状态、操作、顺序、触控和真实辅助技术验证。
8. **Golden 通过证明什么？** 固定环境像素接近基线，不证明语义或业务正确。
9. **为何优先 Directional API？** 让 start/end 随 RTL 方向适配。
10. **本章越界反例？** 选择完整状态管理架构或实现网络缓存；它们不是布局/无障碍职责。

## 19. 章节验收清单

- [ ] 能沿树说明每层 constraints、size 和 position。
- [ ] 能正确使用 Row/Column/Flex/Expanded，并诊断无界主轴。
- [ ] 能为短内容、长列表和复杂滚动选择明确的滚动所有者。
- [ ] 能用 LayoutBuilder/MediaQuery 建立有理由的断点。
- [ ] 能在窄/宽、长文本、文本放大和 RTL 下无溢出。
- [ ] 能检查 Semantics 名称、角色、状态、操作和重复朗读。
- [ ] 能用键盘完成主流程，焦点顺序与指示合理。
- [ ] 能测量触控目标并避免只靠颜色传递状态。
- [ ] 能区分 Widget、Semantics、Golden、真机与读屏证据范围。
- [ ] 未执行的真实平台和辅助技术检查明确标记 `unverified`。

## 20. 官方资料与更新检查

- Understanding constraints：<https://docs.flutter.dev/ui/layout/constraints>
- Layouts in Flutter：<https://docs.flutter.dev/ui/layout>
- Accessibility UI design：<https://docs.flutter.dev/ui/accessibility/ui-design-and-styling>
- Accessibility testing：<https://docs.flutter.dev/ui/accessibility/accessibility-testing>
- Semantics API：<https://api.flutter.dev/flutter/widgets/Semantics-class.html>
- Focus and keyboard：<https://docs.flutter.dev/ui/interactivity/focus>

资料核对日期：2026-07-24。Flutter stable、TextScaler/测试 API、Material 默认尺寸和平台无障碍桥接会变化；约束传递、内容驱动断点、真实语义与分层证据是稳定核心。
