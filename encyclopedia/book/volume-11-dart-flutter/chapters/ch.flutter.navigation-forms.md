---
schema_version: 2
edition: 2026.2-draft
id: ch.flutter.navigation-forms
title: 导航、路由、表单与页面契约
responsibility: 建立页面路由、参数、返回结果、表单状态和校验合同，处理深链接与返回栈，不在本章选择全局状态库。
volume: '11'
order: 14
level: L2
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.flutter.navigation-forms.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.flutter.state-lifecycle
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
  text: 在 120 秒内解释“导航、路由、表单与页面契约”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - flutter-navigation
  - flutter-forms
  covers_topics:
  - flutter.navigator-route
  - flutter.route-arguments-result
  - flutter.deep-link-intro
  - flutter.back-stack
  - flutter.route-restoration
  - flutter.form-key
  - flutter.text-form-field
  - flutter.form-validation
  - flutter.controller-focus-dispose
  - flutter.unsaved-change
  uses_capabilities:
  - mobile.flutter-layout-lifecycle
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现工单列表到编辑页的参数/返回结果导航和可恢复表单；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - flutter-navigation
  - flutter-forms
  covers_topics:
  - flutter.navigator-route
  - flutter.route-arguments-result
  - flutter.deep-link-intro
  - flutter.back-stack
  - flutter.route-restoration
  - flutter.form-key
  - flutter.text-form-field
  - flutter.form-validation
  - flutter.controller-focus-dispose
  - flutter.unsaved-change
  uses_capabilities:
  - mobile.flutter-layout-lifecycle
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: navigation-matrix-form-state-test-back-stack-trace
- id: diagnose
  kind: fault-diagnosis
  text: 面对“错误 Context 导航、controller 未释放或路由参数/返回值漂移”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - flutter-navigation
  - flutter-forms
  covers_topics:
  - flutter.navigator-route
  - flutter.route-arguments-result
  - flutter.deep-link-intro
  - flutter.back-stack
  - flutter.route-restoration
  - flutter.form-key
  - flutter.text-form-field
  - flutter.form-validation
  - flutter.controller-focus-dispose
  - flutter.unsaved-change
  uses_capabilities:
  - mobile.flutter-layout-lifecycle
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 导航、路由、表单与页面契约

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《状态、生命周期、mounted、Key 与异步更新》](ch.flutter.state-lifecycle.md)：路由进入/退出、controller 清理和表单状态身份依赖生命周期与 Key。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 页面不是互相随意跳转的 Widget 集合。路由有可输入参数、可返回结果、返回栈与恢复语义；表单有草稿、校验、提交、放弃和资源清理语义。本章先建立这些合同，不选择全局状态管理品牌，也不把深链接可达误写成已完成系统配置。

## 1. 页面契约先于导航 API

打开“编辑工单”页之前先写清四件事：输入是工单 ID 还是整个可变对象；页面可能返回保存、取消还是删除；非法 ID 如何显示；返回后列表依据什么刷新。只有合同明确，`Navigator.push`、Router 或路由包才是实现工具。

推荐输入稳定标识和少量展示提示，不直接传 repository 中的可变实体。详情页用 ID 重新读取权威数据，可以处理缓存过期、权限变化和深链接冷启动。若传整个对象，返回栈中的旧实例可能与服务端或其他页面不一致。

```dart
final class EditOrderArgs {
  final String orderId;
  final String? source;
  const EditOrderArgs({required this.orderId, this.source});
}

sealed class EditOrderResult {
  const EditOrderResult();
}
final class OrderSaved extends EditOrderResult {
  final String orderId;
  const OrderSaved(this.orderId);
}
final class EditCancelled extends EditOrderResult {
  const EditCancelled();
}
```

参数和结果都应有类型，不要用 `Map<String, dynamic>` 与魔法字符串在页面间交换。类型能防止字段拼写漂移，但不能证明 ID 存在、用户有权限或返回结果符合业务状态，仍需边界测试。

## 2. Navigator 是 Route 栈

Flutter 的 Navigator 管理 Route 栈。`push` 把新 Route 放到顶部，`pop` 移除顶部 Route；用户看到的是顶部页面。Material 应用通常用 `MaterialPageRoute<T>` 指定返回类型。

```dart
Future<void> openEditor(BuildContext context, String id) async {
  final result = await Navigator.of(context).push<EditOrderResult>(
    MaterialPageRoute<EditOrderResult>(
      builder: (_) => EditOrderScreen(args: EditOrderArgs(orderId: id)),
    ),
  );

  if (!context.mounted) return;
  if (result case OrderSaved(:final orderId)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存 $orderId')),
    );
  }
}
```

`await` 之后原 Context 所属 Element 可能已经卸载，所以在继续查找 Navigator、Messenger 或 setState 前检查 `context.mounted`。它只能阻止销毁后更新 UI，不会取消编辑页工作或网络请求。

编辑页完成时：

```dart
Navigator.of(context).pop<EditOrderResult>(OrderSaved(order.id));
```

系统返回或用户点取消可能得到 null，也可能由页面明确返回 `EditCancelled`。团队必须选择一个合同并统一测试，不能让调用者猜测 null 是取消、异常还是页面忘记返回。

## 3. 错误 Context 与嵌套 Navigator

`Navigator.of(context)` 查找 Context 祖先中的最近 Navigator。如果 Context 位于 Navigator 之上会找不到；如果页面存在 Tab、Shell 或对话框自己的嵌套 Navigator，最近的也可能不是根 Navigator。

典型错误是同一个 build 方法创建 Navigator，又用它外层的 context 立即查找新 Navigator。解决方法不是到处使用 global navigator key，而是把操作放到 Navigator 子树内的 Widget、Builder 或回调中，并明确希望操作 root 还是局部栈。

嵌套栈的合同需要画图：根栈负责登录/主壳；每个 tab 可有局部历史；模态路由属于哪个栈；登出应清空哪些栈。`rootNavigator: true` 是具体选择，不是默认补丁。

首个可信证据通常是异常中 “Navigator operation requested with a context...” 或栈观察器轨迹，而不是用户说“按钮没反应”。测试要记录操作前后 route 名称与深度。

## 4. push、replace、remove 与返回栈不变量

常见操作语义：`push` 保留当前页；`pushReplacement` 用新页替换顶部；`popUntil` 回退到谓词匹配；`pushAndRemoveUntil` 加入新页并按谓词删除旧页。登录成功替换登录页、登出清理受保护栈、普通编辑进入并返回，规则不同。

不要用“多 pop 几次”修复重复页面。应先写栈矩阵：

| 场景 | 初始栈 | 操作 | 期望栈 |
| --- | --- | --- | --- |
| 列表打开详情 | root/list | push detail | root/list/detail |
| 详情打开编辑 | .../detail | push edit | .../detail/edit |
| 保存编辑 | .../edit | pop saved | .../detail |
| 登录成功 | root/login | replace home | root/home |
| 登出 | 任意受保护栈 | 重建/清理 | root/login |

返回栈是用户体验与权限边界的一部分。登出后仍能 back 回受保护页面是安全缺口；保存后误删列表页是导航合同错误。

## 5. 命令式 Navigator 与 Router

小型应用、局部临时页面和简单 push/pop 可直接使用 Navigator。需要 Web URL、复杂深链接、多 Navigator 或外部 RouteInformation 同步时，应使用 Router 配置或成熟路由包。Flutter 3.44 官方导航指南明确：大多数应用不推荐依赖传统 named routes，复杂场景推荐 go_router 等 Router 方案。

这里不把某个路由包 API 当长期稳定核心。稳定合同是：路径能够解析成类型化配置；配置能生成确定页面栈；页面状态改变可更新 URL；系统 back 与应用栈一致；非法路径有明确 404/拒绝页。

```dart
sealed class AppRoute {
  const AppRoute();
}
final class OrderListRoute extends AppRoute {
  const OrderListRoute();
}
final class OrderDetailRoute extends AppRoute {
  final String id;
  const OrderDetailRoute(this.id);
}
final class UnknownRoute extends AppRoute {
  final Uri uri;
  const UnknownRoute(this.uri);
}
```

纯函数 `parseRoute(Uri)` 可以在不启动 Flutter 的情况下验证路径矩阵；真正 Page/Route 创建、浏览器 history 和平台分发仍需 Widget/集成测试。

## 6. 深链接是外部不可信输入

`factorycare://orders/WO-101` 或 HTTPS app link 能直接绕过首页进入深层页面，因此路径、query、fragment 都是不可信输入。解析后还要经过格式校验、认证恢复和授权判断。

```dart
AppRoute parseRoute(Uri uri) {
  final segments = uri.pathSegments;
  if (segments case ['orders']) return const OrderListRoute();
  if (segments case ['orders', final id]
      when RegExp(r'^WO-[0-9]+$').hasMatch(id)) {
    return OrderDetailRoute(id);
  }
  return UnknownRoute(uri);
}
```

深链接可解析不代表设备已配置。Android App Links 需要 manifest、域名 assetlinks 与签名；iOS Universal Links 需要 associated domains 与 AASA；Web 需要服务器 fallback。还要验证冷启动、后台恢复、已登录、未登录、权限不足、链接过期与重复点击。

未登录时可保存一个经过校验的 intended route，认证成功再恢复；不能保存任意原始 URL 后无校验跳转。授权必须在数据/服务端边界再次执行，路由 guard 只改善体验。

## 7. 页面参数与返回结果的演进

路由参数是跨模块合同。新增 optional 字段较容易兼容，重命名路径、改变 ID 格式或结果类型会影响深链接、通知和旧版本客户端。把路径 schema、解析器和构建器放在同一模块，建立往返测试：`route -> uri -> route`。

结果不应携带整份更新实体作为唯一真相。编辑页可以返回 `OrderSaved(id)`，调用者让 repository 刷新；若为了即时 UI 返回 snapshot，也要带 revision 并允许 repository 覆盖。

避免：`Navigator.pop(context, true)`。布尔值无法说明保存了谁、删除还是修改，也无法扩展冲突结果。sealed result 能让 switch 对新增分支给出 analyzer 反馈。

## 8. Route restoration 不是业务持久化

Flutter state restoration 可以恢复 Route 栈和 RestorableProperty。Navigator 的 page-based route 需要 Page restorationId；经典 `push` 创建的 route 不可自动恢复，restorablePush 等 API 才参与恢复链。Router 配置 restorationScopeId 后可序列化当前配置。

恢复机制适合进程被系统回收后的 UI 连续性，不替代数据库或服务端保存。表单草稿是否要跨卸载、重启、升级保留是产品决策。敏感字段不能因为“可恢复”就写入普通 restoration bucket。

RestorableProperty 必须注册并随 State dispose。恢复 ID 在作用域内唯一。验证至少包括杀进程恢复工具流程，而不是热重载；本章纯 Dart 资产只验证恢复快照 schema，不声称执行过系统回收。

## 9. Form 与 GlobalKey<FormState>

Form 聚合多个 FormField 的保存、重置和校验状态。GlobalKey 应作为 State 字段创建一次，不能每次 build 新建，否则 FormState 身份丢失、校验提示和草稿可能重置。

```dart
class _EditOrderScreenState extends State<EditOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            validator: validateTitle,
            onSaved: (value) { /* 保存到局部草稿 */ },
          ),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
```

`validate()` 会调用每个 validator，返回 null 表示字段有效，返回 String 表示错误。validator 应是同步、快速、确定的本地规则；唯一性或权限等服务端规则在提交阶段处理并映射到页面错误状态。

## 10. 校验、规范化与提交分层

输入处理分三步：保留用户草稿；本地校验可解释错误；提交时规范化并调用用例。不要每次键入都 trim controller.text，可能改变光标与输入法 composing region。展示草稿和提交命令可以是两个对象。

```dart
String? validateTitle(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) return '请输入故障描述';
  if (normalized.length > 200) return '最多 200 个字符';
  return null;
}
```

错误文案要与字段关联、对读屏可见，不能只用红色。第一次提交失败后可把 autovalidateMode 调为 onUserInteraction，但不要页面一打开就展示所有红错。

提交必须防重复：保存中禁用按钮或使命令幂等；成功后只 pop 一次；失败保留草稿并显示可重试错误。mounted 只保护 UI 更新，不提供请求取消或幂等。

## 11. TextEditingController 与 FocusNode 生命周期

需要读取、设置文本或控制 selection 时使用 TextEditingController；只需 onChanged/onSaved 时不一定需要 controller。controller 与 initialValue 通常不能同时为 TextFormField 提供两套来源。

在 State.initState 创建 controller 与 FocusNode，在 didUpdateWidget 处理外部参数真正变化，在 dispose 中释放：

```dart
late final TextEditingController _titleController;
final _titleFocus = FocusNode();

@override
void initState() {
  super.initState();
  _titleController = TextEditingController(text: widget.initialTitle);
}

@override
void dispose() {
  _titleController.dispose();
  _titleFocus.dispose();
  super.dispose();
}
```

不要在 build 创建 controller，否则每次重建丢选择与草稿并泄漏监听。controller listener 中再写 controller.text 可能产生循环和输入法 composing 冲突；即时格式优先 TextInputFormatter，批量设置 text 与 selection 时设置完整 value。

## 12. 未保存退出与 PopScope

脏状态不是“字段非空”，而是当前规范化草稿与基线 snapshot 不同。保存成功后更新基线，用户改回原值后应恢复 clean。

Flutter 当前使用 `PopScope<T>` 管理系统 back。`canPop: false` 预先阻止 pop，`onPopInvokedWithResult` 在尝试处理后回调；回调时已不能阻止已经发生的 pop，应依据 didPop 决定是否弹确认并在确认后主动 pop。

```dart
PopScope<EditOrderResult>(
  canPop: !isDirty,
  onPopInvokedWithResult: (didPop, result) async {
    if (didPop || !isDirty) return;
    final leave = await showDiscardDialog(context);
    if (!context.mounted || !leave) return;
    Navigator.of(context).pop(const EditCancelled());
  },
  child: form,
)
```

Android predictive back、iOS Cupertino 手势和程序化 pop 的回调细节不同，必须在目标平台验证。对 Form 也可使用相应 canPop/onPopInvokedWithResult。确认框本身属于 pageless route，复杂 Router 栈变更会影响它的生命周期。

## 13. FactoryCare 页面流程

目标流程：列表 push 详情；详情 push 编辑并传 ID；编辑从 repository 加载基线；本地草稿通过 Form 管理；保存返回类型化结果；详情刷新；未保存退出确认；深链接可直接建立 list/detail 栈。

页面状态至少区分 loading、ready(draft, dirty, fieldErrors)、submitting、submitFailure。导航结果只表达页面最终动作，不把 loading/error 混入 Route result。

导航矩阵应覆盖：正常进入；非法 ID；深链接冷启动；未登录 intended route；编辑取消；有效保存；非法表单；保存失败；连续点击保存；脏表单 back 拒绝/确认；进程恢复。每一行记录初始栈、输入、操作、结果和最终栈。

## 14. 三类故障与诊断

错误 Context：先看异常和 NavigatorObserver 轨迹，确认最近祖先 Navigator 与目标栈。不要先加 root key。

controller 未释放：Widget 测试重复 pump/remove 后仍收到监听，或 DevTools 显示对象增长。修复创建/释放对称，并验证 didUpdateWidget 不覆盖用户草稿。本章无真实内存 profile，只提供生命周期模型。

参数/结果漂移：调用者期待 EditOrderResult，页面返回 bool/dynamic。analyzer 能捕获一部分泛型错误；路由包动态 extras 仍需 runtime decode。修复为集中 codec、sealed 类型与往返测试。

表单状态丢失：GlobalKey/build/controller 身份错误，或 route replacement 误删页面。首个证据是输入后触发 rebuild/恢复，草稿与基线断言不一致。

## 15. AI 协作边界

AI 可以生成 Route 类、Form 字段和矩阵骨架，但人必须决定：页面参数权威来源；结果类型；栈不变量；深链接认证授权；恢复哪些状态；草稿敏感性；validator 与服务端错误边界；controller/focus owner；未保存退出规则。

审查 AI 导航代码：是否用 dynamic Map；是否把整个可变实体当参数；await 后未检查 mounted；到处 root navigator key；传统 named route 用于复杂深链；深链未校验；登出栈未清理；GlobalKey 在 build 创建；controller 无 dispose；validator 发网络；PopScope 回调误以为能事后阻止 pop。

必须把“源代码看起来正确”与“Android/iOS/Web 深链已验证”分开。后者需要签名域配置、真实启动方式、平台 back 与浏览器 history 证据。

## 16. 练习、复习与验收

基础练习：定义 EditOrderArgs/EditOrderResult；写纯函数 parseRoute；列出五种 Navigator 操作的栈变化；写 title validator；说明 GlobalKey、controller、FocusNode 各自 owner。

综合练习：实现列表→详情→编辑，保存返回 ID、取消返回明确类型；Form 校验 title/priority；脏表单 PopScope；恢复 snapshot codec。保存导航矩阵与 Widget 测试结果。

故障练习：让页面返回 bool，观察调用方类型/运行失败；把 GlobalKey/controller 移入 build，复现草稿丢失；故意使用错误 Context；修复后重跑原矩阵并说明深链平台配置仍未验证。

120 秒复述必须包含：Route 栈、参数/结果、Navigator/Router 选择、深链接信任边界、restoration 与业务持久化差别、Form/validator、controller/focus dispose、dirty/PopScope，以及一个不该由全局状态库解决的反例。

## 17. 本章验证范围与未验证项

配套资产以纯 Dart 模型验证类型化 route、返回栈、URI 解析、表单草稿与恢复 snapshot；公开 exercise 保留返回结果漂移并预期失败。未启动 Flutter Widget 树，未验证 BuildContext 查找、Navigator API、PopScope 手势、GlobalKey/FormState、controller 真正 dispose、深链接平台配置、浏览器 history 或系统进程恢复。

官方资料于 2026-07-24 核对，站点当前反映 Flutter 3.44.7；Dart stable 为 3.12.x。本机 Flutter 3.35.7/Dart 3.9.2 仅运行兼容的纯 Dart 合同资产，不作为 Flutter 3.44 真机证据。

## 18. 官方资料

- [Flutter Navigation and routing](https://docs.flutter.dev/ui/navigation)
- [Flutter Deep linking](https://docs.flutter.dev/ui/navigation/deep-linking)
- [Navigator API](https://api.flutter.dev/flutter/widgets/Navigator-class.html)
- [Build a form with validation](https://docs.flutter.dev/cookbook/forms/validation)
- [TextEditingController API](https://api.flutter.dev/flutter/widgets/TextEditingController-class.html)
- [PopScope API](https://api.flutter.dev/flutter/widgets/PopScope-class.html)
- [RestorationMixin API](https://api.flutter.dev/flutter/widgets/RestorationMixin-mixin.html)
- [Flutter SDK archive](https://docs.flutter.dev/install/archive)

资料核对日期：2026-07-24。patch 版本与路由 API 会变化，升级前重新核对 SDK archive、迁移说明和目标平台集成文档。
