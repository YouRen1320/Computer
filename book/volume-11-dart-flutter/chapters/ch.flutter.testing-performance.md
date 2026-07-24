---
schema_version: 2
edition: 2026.2-draft
id: ch.flutter.testing-performance
title: Widget/集成/Golden 测试、性能与内存分析
responsibility: 组合 Dart 单元、Widget、集成和 Golden 测试保护行为，用 DevTools 定位重建、掉帧和内存保留，控制 Golden 与设备差异。
volume: '11'
order: 18
level: L3
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.flutter.testing-performance.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.dart.testing-lints
- ch.flutter.architecture-state
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
  text: 在 120 秒内解释“Widget/集成/Golden 测试、性能与内存分析”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - flutter-test-levels
  - flutter-performance-memory
  covers_topics:
  - flutter.widget-test
  - flutter.integration-test
  - flutter.golden-test
  - flutter.finder-semantics
  - flutter.pump-settle-boundary
  - flutter.frame-timeline
  - flutter.rebuild-profile
  - flutter.memory-snapshot
  - flutter.image-cache-budget
  - flutter.performance-regression
  uses_capabilities:
  - mobile.dart-language
  - mobile.flutter-layout-lifecycle
  - web.accessibility
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为工单关键路径建立测试金字塔并修复一个可复现掉帧或内存保留问题；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - flutter-test-levels
  - flutter-performance-memory
  covers_topics:
  - flutter.widget-test
  - flutter.integration-test
  - flutter.golden-test
  - flutter.finder-semantics
  - flutter.pump-settle-boundary
  - flutter.frame-timeline
  - flutter.rebuild-profile
  - flutter.memory-snapshot
  - flutter.image-cache-budget
  - flutter.performance-regression
  uses_capabilities:
  - mobile.dart-language
  - mobile.flutter-layout-lifecycle
  - web.accessibility
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: widget-integration-golden-frame-profile-memory-leak-fixture
- id: diagnose
  kind: fault-diagnosis
  text: 面对“pumpAndSettle 永不结束、Golden 环境漂移、无 Key 查找或 controller/图片缓存泄漏”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - flutter-test-levels
  - flutter-performance-memory
  covers_topics:
  - flutter.widget-test
  - flutter.integration-test
  - flutter.golden-test
  - flutter.finder-semantics
  - flutter.pump-settle-boundary
  - flutter.frame-timeline
  - flutter.rebuild-profile
  - flutter.memory-snapshot
  - flutter.image-cache-budget
  - flutter.performance-regression
  uses_capabilities:
  - mobile.dart-language
  - mobile.flutter-layout-lifecycle
  - web.accessibility
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# Widget/集成/Golden 测试、性能与内存分析

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Dart test、断言、Mock、lint 与包质量》](ch.dart.testing-lints.md)：Widget/集成测试仍依赖可信预言、断言、替身和质量门禁。
- [《状态管理、模块边界与依赖方向》](ch.flutter.architecture-state.md)：可替换依赖和确定状态转换使测试与性能诊断可控。
<!-- END GENERATED LEARNING PREREQUISITES -->

> Flutter 应用“能点通”不代表可发布：异步状态可能偶发错序，动画可能让测试永远等待，Golden 可能因字体和 SDK 漂移而误报，debug 模式中的卡顿也不能代表 release。可靠证据需要把测试层级、预言、运行环境和性能基线同时写清。本章不追求测试数量，而是让每个高风险行为拥有最小、稳定、可解释的保护。

## 1. 先从风险选择测试层级

Flutter 官方把自动化测试分为 unit、widget 与 integration。单元测试隔离一个函数、类或用例，速度快、依赖少；Widget 测试在简化的 Flutter 测试环境中构建组件、执行布局、交互与生命周期；集成测试在模拟器或真实设备上运行整个应用或大部分应用，覆盖真实插件和系统组合，成本最高。Golden 是对渲染图像的比较，可作为 Widget/集成策略的一部分，不是独立替代所有行为断言的第四层。

选择层级要从故障是否能在该环境出现开始：工单状态转换用纯 Dart 单元测试；加载/空/失败画面和按钮交互用 Widget 测试；真实路由、持久化、插件注册与后端组合用集成测试；颜色、间距和溢出回归可用 Golden；真实权限弹窗、相机和商店环境仍需原生 UI 工具或人工真机路径。

一个常见反模式是“全部写集成测试”，结果慢、脆弱、首证据离根因很远；另一个是“单元测试覆盖率 90% 就够”，却从未证明 Widget 订阅状态、语义标签和页面销毁。健康的组合通常有大量单元和 Widget 测试，以及足够覆盖关键用例的少量集成测试。具体比例不是 KPI，风险覆盖和失败可诊断性才是判据。

## 2. 测试由输入、动作、Oracle 和证据组成

“测试跑绿”只有在 Oracle 可信时有意义。每个测试至少回答：前置输入是什么；执行什么动作；哪个可观察事实决定对错；失败时保存哪条首证据。Oracle 不能来自被测实现本身，例如业务函数和测试都调用同一个错误的 `calculateExpected()`，两者会一起错而保持绿。

FactoryCare 的“关闭工单”Widget 测试可规定：输入是 assigned 工单和有权限用户；动作是点击带稳定语义的关闭按钮并确认；Oracle 是先出现 submitting，再出现 closed 且按钮消失；失败路径是 repository 返回 conflict 后旧工单仍显示并出现冲突恢复入口。不要只断言某个私有字段变成 true。

好的失败消息包含场景与期望，例如 `expected conflict action to remain available after 409`，而不是只有 `false is not true`。测试名称表达行为和条件，Arrange/Act/Assert 保持可读。一次测试可以有多个相关断言，但若失败后无法判断阶段，应拆成更小场景。

## 3. 纯 Dart 单元测试保护领域与状态转换

Flutter 项目仍应把可独立的领域规则、application 用例、DTO 映射和状态持有者尽量写成纯 Dart。这样无需 Widget binding 就能快速覆盖空集合、边界值、异常、取消、冲突与竞态。Fake repository 比深层 mock 更能表达真实合同：它返回领域结果、记录调用并允许控制 Future 完成顺序。

测试状态持有者时，不要依赖真实时间和网络。注入 clock、ID generator、scheduler 或受控 `Completer`；明确初始状态和每次转移。对于两个并发请求，测试应先启动 A、再启动 B、让 B 先完成、最后完成 A，断言 A 的迟到结果不覆盖 B。这比仅等待一次成功更接近生产故障。

单元测试的边界同样重要：它不能证明 Widget rebuild、`BuildContext` 使用、焦点、语义树、图片渲染、平台 channel 或真实 SQLite。测试报告中应写明“纯 Dart 合同绿”，而不是笼统说“Flutter 功能已验证”。

## 4. Widget 测试创建一个受控 Flutter 世界

`testWidgets` 提供 `WidgetTester` 和测试 binding。`pumpWidget` 把根 Widget 安装到测试环境；`pump` 推进一帧并处理相应 microtask/动画；`tap`、`enterText`、`drag` 等模拟输入。测试仍应通过构造器或 composition root 注入 Fake，不要让页面在构建时访问真实 HTTP、插件或全局单例。

一个页面往往依赖主题、`MediaQuery`、本地化、Navigator 与 Scaffold。可以建立小型 `TestApp` 包装器，但不要把生产 `main()` 整个搬入每个 Widget 测试。包装器只提供该组件合同需要的环境，并允许控制屏幕尺寸、文本缩放、平台亮度和导航观察器。

```dart
await tester.pumpWidget(
  MaterialApp(
    home: WorkOrderPage(repository: fakeRepository),
  ),
);
expect(find.text('加载中'), findsOneWidget);
fakeRepository.completeWith([order]);
await tester.pump();
expect(find.byKey(const Key('work-order-WO-1')), findsOneWidget);
```

这段示意强调“由测试决定异步何时完成”。实际 API 需按锁定 Flutter 版本编译确认。若页面内部偷偷从全局 service locator 取 repository，测试会难以隔离，这通常也是架构反馈。

## 5. Finder 应面向语义与稳定身份

`find.text` 适合用户可见的稳定文本，但本地化或同名文本会造成歧义；`find.byType` 对组件重构敏感；Key 可以标识列表项和动作；语义 finder 能按辅助技术实际看到的节点查找。优先级不是绝对规则，而是根据用户行为选择最稳定、最有意义的观察点。

关键操作应同时拥有可访问语义和稳定测试定位，而不是为了测试给整个页面堆随机 Key。列表项 Key 通常基于稳定业务 ID，不用数组下标；按钮的语义 label 描述动作，不描述图标颜色。测试至少覆盖屏幕阅读器可识别名称、禁用状态和错误提示，不只断言像素。

无 Key 查找常导致 `find.byType(ElevatedButton).at(3)`；新增一个按钮就点错目标。首证据是测试依赖树位置而非用户语义。修复应给业务节点稳定身份或语义，并让生产可访问性受益，而不是把测试改成新的脆弱下标。

## 6. `pump` 与 `pumpAndSettle` 的边界

`pumpAndSettle` 会反复 pump，直到不再有计划帧，并至少执行一次以清空可能安排新帧的 microtask。Flutter API 文档说明：若存在无限动画，例如不确定进度指示器，它会等待到 timeout 后抛错；官方还建议尽可能知道每一帧为何存在，精确 pump，并可断言 pump 次数以发现动画延迟回归。

因此不要把每个 Widget 测试结尾都写成 `await tester.pumpAndSettle()`。持续闪烁光标、循环 loading 动画、定时刷新都会让“settle”不存在。更确定的做法是：触发动作；`pump()` 处理提交帧；控制 Fake Future 完成；`pump()` 处理完成状态；对有限动画 `pump(const Duration(...))`；只在路由转场等确实应收敛的路径使用带合理超时的 settle。

当测试超时时，先查看正在安排帧的动画、Timer、Stream 和状态循环；不要把 timeout 从十秒改成十分钟。修复后还要确认真实行为没有停掉必要动画。公共练习应让错误稳定暴露，而不是在 CI 中随机卡住。

## 7. 异步测试要控制时间和顺序

真实 `Future.delayed`、系统时钟和网络重试会让测试慢且偶发。注入 clock 和 scheduler，让测试显式推进虚拟时间；对 debouncing、backoff 和 timeout，断言调用时刻或次数，而不是 `sleep`。`fake_async` 等工具是否使用取决于项目版本，但原则是生产代码不能把不可替换时间散落各处。

Stream 测试要管理订阅和关闭：先注册期望，再发事件；完成后取消；断言错误与 done；避免测试结束后仍有未处理事件。页面销毁路径要验证 controller、focus node、animation controller、stream subscription 和 listener 的 dispose/cancel 被调用。

并发测试至少包含迟到成功、迟到失败、取消后完成和重复动作。若只测顺序完成，竞态会在用户快速点击或网络抖动时才出现。保存事件 trace 是很好的首证据：`start:A > start:B > success:B > ignored:A` 比截图更能说明状态所有权。

## 8. Golden 测试保护视觉合同，但环境必须冻结

`matchesGoldenFile` 会把渲染图像与基准图比较。Flutter API 文档明确提醒：不同平台、字体，甚至同平台不同 Flutter 版本都可能导致差异。默认本地比较器通常逐像素比较，`flutter test --update-goldens` 会更新基准。因此更新 Golden 是修改测试 Oracle，必须经过人工审查，不能在 CI 失败时自动接受。

稳定 Golden 环境应固定：Flutter/Dart 版本、OS 或容器镜像、字体文件与加载方式、locale、文本缩放、surface 尺寸、device pixel ratio、主题、时区、动画状态、网络图片替身。选择明确的 `RepaintBoundary` 截取目标区域，减少无关像素。若业务支持多主题和大字体，应把它们作为有意的变体，而不是一次随机环境。

Golden 擅长发现间距、颜色、溢出和图标变化，却不证明按钮能点击、语义正确、网络成功或路由可返回。它应与行为和语义断言并存。允许像素容差会降低噪声，也可能掩盖真实退化；采用容差时必须记录算法、阈值和为何不会吞掉关键差异。

## 9. Golden 漂移如何审查

当 Golden 失败，先比较环境清单，再看差异图和变更意图。若 Flutter patch、字体或 OS 变化，先在旧冻结环境重跑；若只有开发机失败而固定 runner 绿，说明环境不一致；若固定 runner 也失败，定位到具体 Widget 变更。

更新流程应保存 before、actual、diff、测试名称、SDK/字体摘要、审查人和变更理由。批量 `--update-goldens` 后只看“文件变了”不够，尤其不能让 AI 自动批准数百张图片。对安全提示、金额、状态徽章等关键区域，可以再加文本/语义断言，防止容差或截图裁剪漏掉信息。

Golden 环境漂移的首证据通常是基准元数据不同，而不是业务代码。修复是统一 runner 或重新生成有意基线；不能把 comparator 改成永远 true。残余风险包括 GPU/字体栈和平台渲染差异，因此跨平台视觉仍需目标设备 smoke。

## 10. 集成测试验证系统组合

Flutter SDK 的 `integration_test` 能在目标设备运行完整应用，复用 `flutter_test` API，并可用于性能追踪。集成测试适合验证启动、登录替身、导航、HTTP mock server、持久化重启、深链和关键业务路径。它比 Widget 测试更接近真实运行，但仍需要可控服务与独立测试数据。

一条集成路径不应依赖生产租户和公网服务。建立隔离后端或 mock server，固定 seed，使用唯一测试 ID，并在结束后清理。失败时保存设备、系统、应用版本、网络响应、屏幕与日志。测试之间不得共享登录、缓存和数据库状态，除非场景明确验证升级或恢复。

官方测试概览指出，`integration_test` 不能直接操控所有原生平台 UI，例如系统权限弹窗、通知或 platform view。需要原生交互时，可选择支持原生 UI 的测试框架，或把两侧分别做原生单元/插件测试并补人工设备路径。不能因为 Flutter 集成用例绿就宣称权限弹窗已验证。

## 11. 测试金字塔映射到 FactoryCare

| 风险 | 最小测试 | 主要 Oracle | 仍需更高层证据 |
| --- | --- | --- | --- |
| 工单状态转换 | Dart unit | 合法/非法转移 | 服务端合同测试 |
| Repository 映射 | contract unit | DTO、错误码、分页 | mock server 集成 |
| 页面加载/空/失败 | Widget | 语义、动作、状态 | 真实主题/设备 smoke |
| 表单校验与焦点 | Widget | 错误、focus、提交次数 | 键盘/辅助技术 smoke |
| 离线重启与重放 | integration | 持久队列、幂等键 | 真后端/冲突演练 |
| 相机权限 | Fake + plugin tests | 映射矩阵 | 原生 UI/真机 |
| 视觉溢出 | Golden | 冻结像素差异 | 多设备人工检查 |
| 掉帧 | profile integration | frame timeline | 代表性真机重复采样 |
| 内存保留 | leak fixture + DevTools | snapshot/retaining path | 长时真机 soak |

这张表避免“一个绿勾覆盖所有风险”。每份交付说明应标出已验证层级和未验证层级，尤其是性能、权限和平台行为。

## 12. 性能只能在合适构建模式与设备上判断

Flutter 官方 DevTools Performance 文档要求使用 profile build 分析性能，因为 debug 模式的帧时间不能代表 release。debug 带断言、service extension 和 JIT/调试开销；release 又缺少部分分析能力。通常先用 profile 复现和定位，再用 release 做最终用户路径 smoke。

设备刷新率决定帧预算。60Hz 显示约每 16.67ms 一帧，120Hz 约每 8.33ms；不能把“16ms”当所有设备固定常量。Flutter frames chart 分开显示 UI 与 raster 工作，红色慢帧表示错过相应预算。一次冷启动 shader、持续列表滚动和普通静态页面的指标也不能混在同一基线。

性能结论至少记录：设备型号、系统、刷新率/模式、温度与电量条件、profile/release、commit、Flutter/Engine、场景脚本、预热次数、样本量、统计量和 trace 文件。只截一张“这帧很快”不能证明没有回归。

## 13. UI 线程与 Raster 线程分别找原因

UI 线程执行 Dart 和 framework 工作，构建 layer tree；raster 线程把 layer tree 交给图形系统显示。UI 慢可能来自同步 JSON、大列表排序、昂贵 build/layout、重复状态计算；raster 慢可能来自复杂 clipping、阴影、透明叠加、`saveLayer`、大图像和绘制工作。

先选中慢帧，查看 Frame analysis 与 timeline。若 UI bar 超预算，沿 Dart timeline 找长任务；若 raster 慢，检查图层、绘制和图片。不要看到页面卡就立刻“多加 const”或把所有代码放 isolate。`const` 能减少部分对象/重建工作，但不会修复无界图片、同步 I/O 或错误状态范围；isolate 也有消息复制和调度成本。

使用 `dart:developer` 的 Timeline/TimelineTask 可以为业务阶段添加可关联事件，但标签不能包含敏感工单正文。自定义事件帮助区分“API 解析”“状态归并”“列表构建”，仍需结合官方 trace，而不是替代帧数据。

## 14. 建立可重复的性能实验

性能优化顺序是：定义用户可见问题；固定复现脚本；采集基线；提出一个假设；只改一类变量；同条件重跑；比较统计；运行行为和语义回归；记录残余风险。先改后测会把偶然波动当成收益。

例如工单列表滚动掉帧：固定 1000 条合成工单、同一设备、相同滚动手势、profile 模式；预热一次；采集五次 timeline；记录慢帧比例、UI/raster 高分位和重建次数。假设是“父级监听导致整页重建”，于是缩小状态订阅范围；重跑相同脚本。若帧改善但状态徽章不更新，优化不能接受。

平均值会掩盖少数严重卡顿，至少观察高分位、最大慢帧和慢帧比例。样本太少时不要宣称百分比提升；设备温控、后台进程和首帧缓存都会影响结果。自动回归门应留有合理噪声预算，并保存 trace 供人工诊断。

## 15. 重建分析与状态范围

Widget rebuild 本身不是错误；声明式 UI 本来会重建。问题是高频状态变化让巨大子树做昂贵 work。DevTools 可跟踪 Widget builds、layout 和 paints。先测哪些节点、频率和耗时，再决定缩小监听、拆组件、缓存派生值或减少布局。

常见问题包括：在 `build()` 中排序大列表；父页面订阅每秒倒计时导致所有行重建；为每行创建未释放 controller；Key 不稳定导致 element 被当成新节点；状态持有者每次发出内容相同的新快照；图片没有尺寸约束。修复要保持单一事实源，不能为了少 rebuild 引入手工 mutable UI 缓存。

测试可用计数器或 profile fixture证明重建次数下降，但计数器本身不要进入生产逻辑。行为测试仍需确认空、失败、刷新与无障碍语义未回退。性能是约束之一，不是绕过正确性的理由。

## 16. 内存增长不等于内存泄漏

Dart 堆会分配对象，GC 在需要时回收；缓存也可能有意保留对象。观察到 RSS 或 heap 上升一次，不能立刻说泄漏。真正问题是某类对象在用户离开功能、执行 GC 和重复稳定操作后仍被不应存在的引用保留，或缓存没有预算持续增长。

DevTools Memory view 可以观察内存时间线、类实例、快照差异和 retaining path。一个基本实验是：基线快照；进入工单详情并执行动作；退出并释放；触发适当 GC/等待稳定；再拍快照；重复多轮。若 `WorkOrderPageState`、controller、图片字节或订阅数量每轮单调增长，沿 retaining path 找谁仍持有它。

不要以调用 `System.gc` 或清空所有缓存作为“修复”。应删除错误监听、取消订阅、dispose controller、限制缓存或修正全局引用。修复后重跑相同循环，并确认功能与性能没有变差。

## 17. 常见保留源与释放责任

`AnimationController`、`TextEditingController`、`FocusNode`、`ScrollController`、Stream subscription、Timer、ChangeNotifier listener、平台 controller 和原生 callback 都有明确所有者。创建者通常负责释放，除非 API 合同明确转移所有权。匿名闭包捕获 `BuildContext` 或大对象并存入长生命周期单例，也会让整个页面树被保留。

为每种资源建立表：在哪里创建；谁拥有；何时释放；重复进入是否新建；失败初始化是否清理；测试如何观察。`dispose()` 内按合同取消/释放，并避免释放后再次通知。异步结果返回时还要比较 generation；只释放 UI controller 不会自动取消底层网络或平台工作。

实验性 leak testing API 可能随 Flutter 版本变化，因此 `stable_core: false`。可以使用它作为附加信号，但最终仍需清楚的生命周期合同、快照差异和 retaining path。第三方库声称“自动管理”也要按其锁定版本验证。

## 18. 图片缓存必须有预算和场景

工单照片容易造成内存峰值。压缩文件大小不等于解码内存小：一张大分辨率图片解码后可能占据宽×高×每像素字节。列表缩略图不应无界解码原图；提供目标尺寸、分页和占位，避免同时预取全部附件。

Flutter 有图片缓存机制，但项目仍需定义预算、清理时机和监控。随意把全局 `maximumSizeBytes` 设为极小会导致反复解码、网络和卡顿；设为无限则可能被大量设备图耗尽。用代表性数据测命中、峰值、GC 和滚动帧，再选择上限。

安全方面，缓存中也可能包含敏感照片。内存缓存、磁盘缓存与安全存储的生命周期不同；登出、租户切换和附件权限撤销需要清理相应副本。性能优化不能违反数据隔离。

## 19. 自动性能回归的可接受边界

集成测试可以收集 timeline 和性能数据，但 CI 模拟器噪声很大。可靠门禁最好在固定物理设备或受控设备池运行，固定模式和场景。轻量 PR 门可以检查同步重活、资源大小和关键 microbenchmark；夜间或发布候选再跑真实设备 profile 回归。

门槛要基于历史分布和用户体验，而非拍脑袋一个绝对数。记录基线版本、窗口、允许波动、失败重试规则和谁审查 trace。不能通过自动重跑直到绿来掩盖真实偶发卡顿；重跑次数本身也应成为证据。

性能回归必须和功能回归绑定。若优化把列表分页改坏、删除语义节点或降低图片可读性，即使帧更快也不通过。完成条件是指标改善且单元、Widget、集成、Golden/语义中相关保护仍绿。

## 20. 可访问性是测试 Oracle 的一部分

Flutter 测试库提供语义 finder 与点击目标、对比度等 accessibility guideline。自动检查能发现无标签动作、过小触控区域和部分对比问题，但不能替代 TalkBack/VoiceOver、键盘、Switch Control、大字体和认知可用性的真人/真机验证。

工单页面的 Widget 测试可以断言“关闭工单”是 button、禁用时状态可感知、错误与字段关联、加载状态不会无限重复朗读。Golden 在大字体和窄屏变体中发现溢出。集成 smoke 检查焦点顺序和返回后位置。最终发布证据再补屏幕阅读器和键盘操作。

不要为了测试稳定关闭 semantics，或只用 Key 绕过用户可见名称。一个行为能被语义 finder 稳定找到，往往同时改善可访问性与测试可维护性。

## 21. 四类故障的首证据与修复

### 21.1 `pumpAndSettle` 永不结束

首证据是 timeout、仍计划帧的动画/Timer 和测试执行点。修复为控制 Fake、精确 pump 或对确应停止的动画修生命周期；不能只延长 timeout。重跑原测试并断言预期帧数或状态。

### 21.2 Golden 环境漂移

首证据是 Flutter、OS、字体、locale、surface 元数据差异和 diff 图。修复冻结环境或审查有意更新；不能提高容差到吞掉全部变化。重跑固定 runner 与一项行为/语义断言。

### 21.3 无 Key/语义导致点错

首证据是 finder 依赖 `.at(n)` 或同类型节点数量。修复为稳定业务 Key 或语义身份，并删除结构下标。重跑新增相邻按钮的回归，确认仍点中正确动作。

### 21.4 controller 或图片缓存泄漏

首证据是重复进出后的实例增量和 retaining path。修复所有权、dispose/listener、缓存预算；同脚本重测快照和帧。不能只在测试末尾清空全局对象制造绿。残余风险需要长时间真机 soak。

## 22. AI 协作边界

AI 可以从确认的状态表生成测试组合、写 Fake 骨架、解释 finder 失败、比较 trace 摘要、列出可能的 retaining path、审查资源是否成对释放。AI 也可以帮助把一次手工复现变成确定脚本。

开发者必须确定 Oracle、测试层级、性能场景、设备与样本、Golden 更新是否有意、指标阈值、隐私脱敏和残余风险。AI 不能仅凭源码宣称“没有内存泄漏”，不能伪造 DevTools trace、profile 数据、真机截图或屏幕阅读器结果。

审查 AI 测试时重点找：断言是否来自被测实现；是否 catch 后无条件通过；是否滥用 settle/sleep；是否更新了 expected 来迎合 bug；是否只查私有结构；是否把 mock 行为误当真实插件；是否删除性能和语义回归。

## 23. 本章动手路线

### 23.1 Example：分层 Oracle

运行 `examples/encyclopedia/ch.flutter.testing-performance/verify.sh`。它用纯 Dart 建模单元、Widget 合同、集成合同和 Golden 环境指纹，验证每个风险选择正确层级。它不是实际 `flutter_test`。

### 23.2 Lab：帧与内存样本诊断

运行 `labs/encyclopedia/ch.flutter.testing-performance/verify.sh`。Lab 读取合成 frame timeline 与两次 heap snapshot，计算慢帧、重建和保留对象差异，并验证修复后的指标与行为 Oracle。运行前预测：平均帧很快但一个严重慢帧，能否判定通过？

### 23.3 Exercise：稳定预期红

运行 `exercises/encyclopedia/ch.flutter.testing-performance/verify.sh`。初始配置故意用无限 settle、未冻结 Golden 指纹并遗漏 controller 释放；验证器必须非零。任务是修合同而非删除检查。私有 solution 展示同一 Oracle 的绿版本。

### 23.4 120 秒讲回

解释 unit/widget/integration/Golden 各证明什么；为什么 settle 可能永不结束；Golden 为什么要冻结字体和 SDK；性能为何用 profile；UI/raster 怎么分；heap 增长为何不等于泄漏；什么是 retaining path；Fake 绿不能证明哪些平台事实。

## 24. 已验证、未验证与明确不做

随附脚本验证的是离线、纯 Dart/文本模型中的测试层级、环境指纹、帧预算、重建计数、快照差异和资源释放 Oracle。它们不会启动 Flutter engine 或 DevTools，也不会生成真实 PNG、timeline、heap snapshot 或设备集成报告。

本章**没有验证**本机 Flutter 3.44.x/Dart 3.12.x、`flutter_test` API 编译、任何 Widget/Golden/integration 测试、真实字体渲染、模拟器、物理设备、profile/release 性能、120Hz、Impeller、图片缓存、内存 retaining path、TalkBack/VoiceOver 或原生权限 UI。真实项目需在锁定 SDK 后补 `flutter analyze`、`flutter test`、固定 Golden runner、集成设备、DevTools trace 和人工无障碍证据。

本章明确不设虚假覆盖率 KPI，不选择第三方测试框架，不改业务架构，不批量更新 Golden，不宣称消除所有泄漏，不把合成数据当用户设备数据，也不修改学习进度。

## 25. 官方资料与版本边界

以下资料于 2026-07-24 核对，官方页面当时属于 Flutter 3.44 文档家族；项目使用其他 stable patch、测试 API 或 DevTools 时要重新核对：

- [Flutter：Testing overview](https://docs.flutter.dev/testing/overview)
- [Flutter：Integration testing](https://docs.flutter.dev/testing/integration-tests)
- [Flutter：Testing plugins](https://docs.flutter.dev/testing/testing-plugins)
- [Flutter API：WidgetTester.pumpAndSettle](https://api.flutter.dev/flutter/flutter_test/WidgetTester/pumpAndSettle.html)
- [Flutter API：matchesGoldenFile](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html)
- [Flutter：Use the Performance view](https://docs.flutter.dev/tools/devtools/performance)
- [Flutter：Use the Memory view](https://docs.flutter.dev/tools/devtools/memory)
- [Flutter：Performance profiling](https://docs.flutter.dev/perf/ui-performance)
- [Flutter：Performance best practices](https://docs.flutter.dev/perf/best-practices)
- [Flutter stable SDK archive](https://docs.flutter.dev/install/archive)

测试类型和测量原则相对稳定，具体 finder、实验性 leak API、DevTools UI、渲染器、Golden 像素和集成命令会变化。这正是本章保留 `stable_core: false`、并要求版本与环境指纹成为证据的原因。
