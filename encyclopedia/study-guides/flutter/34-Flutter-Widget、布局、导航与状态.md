# Flutter：Widget、布局、导航与状态

## 1. Flutter 用 Widget 树声明当前界面

```dart
class WorkOrderPage extends StatelessWidget {
  const WorkOrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('FactoryCare')),
    );
  }
}
```

Widget 是不可变配置，描述“当前状态下界面应该是什么”。状态变化后框架再次调用 build，比较新旧配置并更新底层 Element/RenderObject。

不要把 Widget 当屏幕上的可变 DOM 节点；更新通常是产生新 Widget 配置。

## 2. 三棵树分别承担配置、身份和渲染

简化：

```text
Widget tree：不可变配置，build 可频繁重建
Element tree：Widget 实例与生命周期/位置的关联
RenderObject tree：布局、绘制、命中测试
```

多数业务只写 Widget 和 State，但理解分层能解释：为什么新 Widget 不等于完全重建像素、为什么 Key 影响 State 复用、为什么 BuildContext 绑定 Element 位置。

## 3. Flutter 工具链要区分 debug、profile 和 release

```text
flutter doctor
flutter create
flutter run
flutter analyze
flutter test
flutter build ...
```

- debug：断言、调试和 hot reload，性能不代表生产；
- profile：接近生产优化并保留性能分析；
- release：面向发布，无调试服务。

性能必须在 profile/release 真机测，不用 debug 卡顿直接下结论。

## 4. Hot reload、hot restart 和完整重启不同

- hot reload：注入新代码并保留大部分 State，再 build；
- hot restart：重启 Dart isolate，应用状态重建；
- full restart/reinstall：原生层、插件、manifest 等变化可能需要。

修改构造器/全局初始化后，保留的旧 State 可能让 hot reload 表现与冷启动不同。排查初始化问题要做完整重启。

## 5. MaterialApp 建立应用级导航和主题环境

```dart
MaterialApp(
  title: 'FactoryCare',
  theme: ThemeData(...),
  home: const WorkOrderListPage(),
)
```

它提供 Navigator、Theme、MediaQuery、Localizations 等常用祖先。Cupertino/自定义应用可用其他结构。

不要在每个页面重复创建 MaterialApp，会产生嵌套导航、主题和 MediaQuery 边界。

## 6. StatelessWidget 表示没有自己可变生命周期状态

它仍会因父参数、Inherited 依赖或全局状态变化重建：

```dart
class PriorityBadge extends StatelessWidget {
  const PriorityBadge({required this.priority, super.key});
  final int priority;

  @override
  Widget build(BuildContext context) => Text('P$priority');
}
```

“Stateless”不等于永远 build 一次，而是该 Widget 没有配套 State 对象保存跨 build 可变字段。

## 7. StatefulWidget 的可变状态放在 State

```dart
class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  var count = 0;

  void increment() {
    setState(() => count += 1);
  }

  @override
  Widget build(BuildContext context) => Text('$count');
}
```

Widget 配置可被替换，State 在相同位置/类型/key 下保留。业务对象不应长期藏在页面 State 而无数据层所有权。

## 8. setState 告诉框架“这个 State 的输出可能变了”

`setState` 回调应同步修改状态，框架安排重建。不要在回调内执行 async：

```dart
final result = await repository.load();
if (!mounted) return;
setState(() => order = result);
```

setState 不会立即同步绘制，也不应包住网络等待。修改了影响 UI 的本地字段却不调用它，界面不会更新。

## 9. State 生命周期定义资源初始化和清理

常见顺序：

```text
createState
  → initState
  → didChangeDependencies
  → build（多次）
  → didUpdateWidget（父配置变化）
  → deactivate（可能暂时移除）
  → dispose（永久结束）
```

每个订阅、Controller、FocusNode、AnimationController、Timer 都要有所有者，并在 dispose 释放。

## 10. initState 只执行一次，不能依赖尚未完整可用的 Context 内容

适合：

- 创建 Controller/FocusNode；
- 订阅与 Widget 初始参数相关的外部源；
- 启动不需 inherited dependency 的初始化。

需要 Theme、Locale 或依赖会变化的 inherited value，使用 `didChangeDependencies`。首帧后聚焦/测量可用 post-frame callback，但要防组件已销毁和重复注册。

## 11. didUpdateWidget 处理父传配置变化

如果 State 订阅 `widget.workOrderId` 对应 Stream，父换了 id：

```text
取消旧 id 订阅
建立新 id 订阅
更新本地状态
```

仅在 initState 订阅会继续收到旧对象事件。比较 oldWidget 与 widget 的相关字段，只有变化才重建资源。

## 12. mounted 说明 State 是否仍在树中

异步完成后：

```dart
final data = await load();
if (!mounted) return;
setState(() => value = data);
```

它防止 dispose 后 setState，但不能解决响应竞态：页面仍 mounted，id 已从 A 变 B，A 旧响应仍可能覆盖。还要用请求 generation、取消或比较当前 id。

## 13. dispose 是资源生命周期的最终边界

```dart
@override
void dispose() {
  subscription.cancel();
  controller.dispose();
  focusNode.dispose();
  super.dispose();
}
```

不要在 dispose 发必须完成的网络请求；应用/进程可能直接终止。关键草稿应在变化时按策略持久化。

## 14. BuildContext 表示 Widget 在树中的位置

通过 context 向祖先查找 Theme、Navigator、MediaQuery、Provider 等。

```dart
final theme = Theme.of(context);
```

同一 build 中某个 context 只能看到它上方的祖先。刚创建 Scaffold 后用外层 context 查 ScaffoldMessenger/Navigator 可能得到不同范围，可用 Builder 或拆子组件获得正确位置。

不要把 BuildContext 长期存到单例或异步服务。

## 15. 异步跨 await 使用 Context 要确认仍有效

```dart
await save();
if (!context.mounted) return;
Navigator.of(context).pop();
```

用户可能在等待时离开页面。即使 mounted，还要确认当前动作仍属于该页面和最新请求。

Service/Repository 不应接收 BuildContext 决定错误文案或导航，保持 UI 与数据层边界。

## 16. Key 帮框架识别同级 Widget 身份

无 key 时主要按类型和位置复用；列表重排时，State 可能跟位置而不是业务项移动。

```dart
WorkOrderRow(
  key: ValueKey(order.id),
  order: order,
)
```

使用稳定唯一业务 ID。`UniqueKey()` 每次 build 都新建会强迫销毁/重建；GlobalKey 功能强、成本和耦合高，只在确需跨位置身份/访问 State 等少数场景使用。

## 17. Flutter 布局核心是“约束向下，尺寸向上，位置由父决定”

```text
父 RenderObject 给子约束：最小/最大宽高
  → 子在约束内选择尺寸并返回
  → 父决定子的位置
```

很多 overflow 不是“屏幕太小”，而是某个父给了无界约束、某个子要求过大或 Row 子项没有弹性。

DevTools Layout Explorer 和错误信息中的 constraints 是第一证据。

## 18. Row 和 Column 沿主轴排列

```dart
Row(
  children: [
    const Icon(Icons.build),
    const SizedBox(width: 8),
    Expanded(child: Text(order.title)),
  ],
)
```

Row 给非 flex 子项的水平约束可能较宽，长 Text 会 overflow；Expanded/Flexible 让它使用剩余空间并换行/截断。

Column 放在滚动容器中时主轴高度可能无界，不可随意使用 Expanded。

## 19. Expanded 和 Flexible 表达剩余空间策略

- Expanded：必须占分配到的剩余空间；
- Flexible：可小于分配空间；
- flex 数值分配比例。

它们只能作为 Flex（Row/Column）直接子级。错误父级会触发 ParentData 错误。

不要把所有子项都 Expanded 来消除 overflow，先定义谁固定、谁伸缩、谁可换行。

## 20. Stack 用于叠放，不用于普通页面排版

```dart
Stack(
  children: [
    content,
    Positioned(top: 8, right: 8, child: badge),
  ],
)
```

适合徽标、浮层和叠图。大量 Positioned 固定坐标在不同屏幕、文字放大和本地化时容易崩坏。

普通流式内容用 Row/Column/Wrap/Grid/List。

## 21. ListView.builder 惰性构建长列表

```dart
ListView.builder(
  itemCount: orders.length,
  itemBuilder: (context, index) => WorkOrderRow(
    key: ValueKey(orders[index].id),
    order: orders[index],
  ),
)
```

只构建视口附近内容。不要在 SingleChildScrollView 内放一个 shrinkWrap 的巨大 ListView 来绕过约束，可能失去惰性并增加布局成本。

复杂滚动组合使用 CustomScrollView/Sliver，需要时查询。

## 22. 响应式与适配从可用空间和输入方式出发

使用 LayoutBuilder 读取局部 constraints，MediaQuery 获取屏幕、安全区域、文字缩放、平台亮度等。

```text
窄空间：单列详情
宽空间：列表 + 详情双栏
```

不要仅按“手机/平板”硬编码；窗口可调整、折叠屏和桌面都有中间尺寸。触摸、鼠标、键盘焦点也要分别支持。

## 23. SafeArea 避免系统遮挡，但不是全局万能 Padding

刘海、状态栏、手势区域会占空间。SafeArea 根据 MediaQuery 插入必要 padding。

图片背景可能需要延伸到边缘，而按钮/文本需要安全区。按区域使用，不要层层嵌套造成重复空白。

键盘弹出还会改变 viewInsets，表单要能滚动并让当前字段可见。

## 24. Text 缩放和本地化会改变布局

固定高度卡片可能在系统字体放大后截断。应允许换行、动态高度和滚动，限制 maxLines 时提供完整内容入口。

中文、英文和长德语文案宽度不同。不要用空格手工对齐，也不要把每个按钮固定成只能放两个汉字。

## 25. Semantics 让辅助技术理解界面

原生 Material 控件已有大量语义。自定义绘制/组合时可补：

```dart
Semantics(
  button: true,
  label: '关闭工单 WO-42',
  child: customControl,
)
```

不要重复 label 造成朗读两次，也不要只靠颜色表示严重状态。使用 Semantics Debugger、屏幕阅读器、键盘和大字验证。

## 26. 焦点和键盘是桌面/Web/辅助技术核心路径

FocusNode 有生命周期，表单提交失败后可聚焦第一个错误。快捷键用 Shortcuts/Actions 等框架能力，并不覆盖系统常用组合。

自定义手势区域必须有足够触控尺寸和键盘等价操作。`GestureDetector` 不自动拥有 Button 全部语义/焦点/视觉反馈，能用原生控件优先原生。

## 27. Navigator 管理页面 Route 栈

命令式基本模型：

```dart
final result = await Navigator.of(context).push<String>(
  MaterialPageRoute(builder: (_) => const EditPage()),
);
```

`push` 入栈，`pop` 返回并可带结果。小应用可直接使用；深链接、Web URL、认证重定向和复杂嵌套导航更适合声明式 Router/路由包。

## 28. 导航参数应该是明确页面合同

```dart
class WorkOrderDetailPage extends StatelessWidget {
  const WorkOrderDetailPage({required this.workOrderId, super.key});
  final String workOrderId;
}
```

传稳定 ID，页面通过 Repository 加载，避免传巨大可变对象导致列表和详情两份状态分叉。

Deep link 参数是不可信字符串；后端仍检查身份、租户和资源权限。

## 29. 返回结果只适合短期页面协作

编辑页 pop 返回更新结果，列表可刷新。但若应用被系统杀死、深链接进入或多设备修改，Navigator 返回值不是数据事实。

服务端成功响应、持久化和 query invalidation 才是长期状态。导航结果可作为立即 UI 提示。

## 30. 表单使用 Form、FormField 和 Controller

```dart
final formKey = GlobalKey<FormState>();
final titleController = TextEditingController();
```

提交：

```dart
if (formKey.currentState?.validate() != true) return;
```

Controller 和 FocusNode 在 dispose 释放。Validator 适合同步字段体验；跨字段/服务端唯一性和权限仍在业务/API 边界。

不要每次 build 新建 controller，会丢输入和泄漏资源。

## 31. UI State 与 App State 所有权不同

- Ephemeral/UI state：当前 tab、输入焦点、局部展开；
- App/business state：认证用户、工单列表、编辑流程、缓存。

局部 State 保持局部；多页面共享或需要持久化的状态放到明确状态对象/Controller/Store。不是所有值都上全局，也不是所有业务都留在 Widget。

## 32. 声明式状态流是“状态 → UI，事件 → Action”

```text
Repository 提供数据/命令
  → Controller/ViewModel 管理 LoadState
  → Widget 监听并 build
  → 用户事件调用 Controller action
  → 新 State 发出
```

状态可用 sealed union：idle/loading/success/error，排除矛盾 boolean。Widget 不直接拼 URL、解析 JSON、处理 Token 刷新。

## 33. 状态管理工具是传播机制，不替代模型设计

ChangeNotifier、ValueNotifier、Provider、Riverpod、Bloc 等都能通知 UI。选择维度：

- 状态所有权和生命周期；
- 依赖注入；
- 异步/取消；
- 可测试性；
- 团队熟悉度；
- 编译期安全与代码生成；
- SSR/Web/导航集成（若适用）。

先定义状态和 action，再选工具，不以 Store 数量衡量架构。

## 34. Repository 隔离数据来源

```dart
abstract interface class WorkOrderRepository {
  Future<WorkOrder> load(WorkOrderId id);
  Future<WorkOrder> assign(AssignCommand command);
}
```

实现可组合 HTTP、缓存和离线。UI 依赖接口/Controller，不依赖 JSON Map 和具体插件。

Repository 不应返回含 BuildContext 的对象，也不负责 SnackBar 文案。

## 35. 依赖从应用组合根注入

```text
main/bootstrap
  → 创建配置、HTTP client、Repository
  → 创建 Controller/Provider
  → Widget 消费抽象
```

测试可提供内存实现。全局 service locator 方便但隐藏依赖、易跨测试泄漏；若使用要有清楚 scope 和 reset。

## 36. 这篇的整体地图

```text
Widget 配置树
  → Element 保持位置与 State 身份
  → RenderObject 执行约束布局和绘制
  → setState/状态管理产生新 UI 配置

约束向下 → 尺寸向上 → 父定位
Navigator 管 Route 栈
Form 管输入体验
Repository + Controller 管业务数据和动作
生命周期负责订阅、异步检查和资源清理
```

必须掌握：Widget 不可变且 build 可多次；State 身份受位置/类型/key 影响；async 后检查 mounted 仍不等于解决竞态；约束布局是 Flutter 排错核心；Controller/FocusNode/Subscription 必须 dispose；路由参数不可信；状态管理工具不替代所有权。

Sliver、自定义 RenderObject、Navigator 2.0 全细节和具体第三方状态库 API 属于“需要时查询”。
