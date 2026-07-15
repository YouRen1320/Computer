# 第 34 周：Flutter Widget、布局、导航、表单与状态

## 定位

Dart 语言基础已在 Week 32—33 完成。本周只学习 Flutter UI 运行模型与应用状态：Widget/Element/RenderObject、约束布局、生命周期、BuildContext、导航、表单和状态管理。网络、离线、设备能力和发布在 Week 35。

时间预算：15—18 小时。复用旧 App 经验做迁移审计，但新骨架从明确结构和测试开始。

## 前置

- 纯 Dart 类型、OOP、Future、Stream、取消和测试通过；
- Flutter stable/目标平台工具链在本周开始时重新核对；
- 至少一个模拟器/真机或明确记录暂时只能使用的目标；
- FactoryCare OpenAPI/设计稿已有客户端边界。

## 目标

- 理解 Widget 不可变配置、Element 持有位置/状态、RenderObject 负责布局绘制的高层关系；
- 正确使用 Stateless/StatefulWidget 和 State 生命周期；
- 理解“constraints go down, sizes go up, parents set positions”；
- 使用常见布局、滚动、列表、Key 和响应式适配；
- 正确使用 BuildContext、InheritedWidget/Theme/MediaQuery；
- 完成 Navigator/Router 的基础导航、参数、返回和深链概念；
- 构建表单、验证、焦点、键盘和可访问性反馈；
- 区分局部 UI 状态、应用状态、服务端状态和持久状态；
- 选择一种主状态管理方式并说明不选其他方案的理由；
- 建立 Widget 和状态单元测试。

## 完整概念清单

### Flutter 树与构建

- Widget 是不可变描述，可频繁重建；
- Element 维持树中身份并连接 Widget/RenderObject；
- State 与 StatefulWidget 分离；
- `build` 应尽量纯，不发请求/写存储/重复订阅；
- setState 标记需要重建，不会自动取消网络或保证业务正确；
- rebuild、layout、paint 是不同工作；
- const widget 的作用与边界；
- DevTools inspector/rebuild/profile 基础。

### 生命周期与资源

- createState、initState、didChangeDependencies、build、didUpdateWidget、deactivate、dispose；
- constructor/initState 不能依赖尚未可用的 inherited context；
- controller/focus/subscription/timer 在 owner dispose；
- `mounted` 从 State 创建后到 dispose 前为布尔状态；
- mounted 只防止销毁后更新 UI，不取消请求、不防重复调用；
- await 后检查 mounted 只能处理 UI 更新合法性；
- 请求/订阅取消需要 client、subscription 或显式 token；
- 不在 dispose 中调用 setState。

### 约束与布局

- constraints、size、position；
- Row/Column/Flex、Expanded/Flexible/Spacer；
- Stack/Positioned、Align/Center、Padding/SizedBox/ConstrainedBox；
- ListView/GridView/CustomScrollView/Sliver 高层选择；
- unbounded constraint、overflow、nested scroll 常见错误；
- LayoutBuilder/MediaQuery、安全区、键盘 inset；
- 逻辑像素、文本缩放和触控目标；
- 不用固定屏幕尺寸假设完成所有布局。

### BuildContext、Key 与导航

- BuildContext 是 Element 位置句柄，不是全局容器；
- 查找 Theme/Navigator/Inherited 依赖于 context 位置；
- async gap 后 context 可能失效；
- ValueKey/ObjectKey/UniqueKey/GlobalKey 的用途与成本；
- 列表重排没有稳定 key 会错配 state；
- Navigator push/pop、arguments/result；
- declarative Router/deep link/auth redirect 概念；
- 不把路由当全局状态存储。

### 表单、交互与可访问性

- Form/FormField/TextFormField、controller 与 initialValue 边界；
- validation、提交、server error 映射；
- focus node、keyboard action、dismiss；
- button/gesture 的语义，优先 Material/Cupertino 可访问组件；
- loading/empty/error/success 和防重复提交；
- Snackbar/Dialog/BottomSheet 选择与 context；
- Semantics、text scale、contrast、reduced motion 基础；
- 图片/列表性能和缓存只建立 UI 侧概念。

### 状态管理

- ephemeral UI、application/domain、server/cache、persistent state；
- lifting state、callback/value、ChangeNotifier/ValueNotifier 基础；
- Provider/Riverpod/BLoC 等按项目选一个，学习共同原则而非多个框架；
- state 应可预测、不可变/受控更新、可测试；
- effect 与 reducer/state 变换分离；
- 避免 BuildContext 穿透领域层；
- loading flag 需和请求身份/取消协调；
- Repository/API 在 Week 35 接入，本周用 fake。

## 时间与任务

| 任务 | 时间 | 产出 |
| --- | ---: | --- |
| 树/生命周期 | 2—3h | rebuild、mounted、dispose 和资源实验 |
| 约束布局 | 3h | 手机/平板布局与 overflow 故障 |
| 导航/Key | 2h | 列表重排、详情、返回和 deep link 草案 |
| 表单/可访问性 | 3h | 检查记录表单和错误状态 |
| 状态方案 | 2—3h | ADR、fake repository 和状态单测 |
| FactoryCare/复盘 | 3—4h | 技师 App UI 骨架和 Widget 测试 |

## FactoryCare 增量

- 登录占位、今日工单、工单详情、处理表单和设置五个最小页面；
- fake repository 提供成功、空、延迟、错误数据；
- 列表与筛选状态可预测，快速切换不会被旧 future 覆盖；
- 表单包含检查项、工时、备件和解决说明；
- 订阅/controller/focus/timer 全部由 owner 释放；
- 至少 3 个 Widget 测试：状态渲染、表单错误、导航结果；
- 记录选择的状态管理方案、替代方案、迁移和回滚成本。

## 无 AI 任务（120—150 分钟）

实现“今日工单列表 → 详情 → 接单确认”纯 fake 流程：覆盖 loading/empty/error/success、稳定 key、页面销毁后不更新 UI、重复点击防护、一个 Widget 测试和一个状态单测。故意删除 dispose 中的取消/释放并用证据恢复。

## 验收

- 能解释 Widget/Element/RenderObject 和 rebuild/layout/paint；
- 能说明 mounted 能做什么、不能做什么；
- 能用约束模型定位 overflow/unbounded；
- 能说明 BuildContext 生命周期和 Key 选择；
- 状态方案有边界，不在 build 发请求；
- Widget/状态测试从命令行通过；
- 能独立新增一个表单字段并更新验证、状态和测试。

## 非目标

- 不接真实 API、数据库、相机/扫码或推送；
- 不同时学习多套状态框架；
- 不追求完整视觉设计；
- 不把 mounted 当取消或防重复方案。
