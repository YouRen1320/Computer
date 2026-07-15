# 第25周：Dart/Flutter复健与可维护应用架构

## 本周定位

本周不重新刷一遍Flutter入门课程，而是利用你已有App经验做能力体检，并把现场技师App重建为可解释、可测试、能继续扩展的架构。目标是理解状态、生命周期、依赖和数据流，而不是追逐状态管理库。

## 前置条件

- 通过Week 24，Java公共API和认证契约已经稳定；
- 能运行或找到以前的Flutter App源码；
- 按[TECH_STACK.md](../TECH_STACK.md)安装当前Flutter stable，并完成`flutter doctor`；
- 选定一个主验证端：Android或iOS。另一端只保证架构兼容，不要求本周发布。

## 本周目标

- 恢复Dart空安全、类型、异步、Stream和错误处理；
- 理解Flutter Widget、Element、RenderObject的职责层次，不钻源码；
- 理解`BuildContext`、生命周期、Key、重建和资源释放；
- 比较局部状态、共享状态、服务端状态和持久状态；
- 采用UI层/数据层分离的应用架构；
- 为FactoryCare技师App建立可测试骨架。

## 必须理解的概念

### Dart

- sound null safety、`?`、`!`、`late`及其风险；
- class、abstract class、mixin、extension、enum、sealed class；
- 泛型、record、pattern matching和不可变对象；
- `Future`、`async/await`、`Stream`、取消和异常传播；
- event loop与isolate的概念边界；
- package、pubspec、语义化版本和代码生成；
- JSON序列化、值相等和复制更新。

### Flutter

- Widget是配置，Element维持树关系，RenderObject负责布局/绘制的概念；
- Stateless/Stateful Widget和`State`生命周期；
- `BuildContext`属于树位置，不能无边界跨异步保存；
- Key在列表重排和状态识别中的作用；
- `build`应保持可重复，不在其中执行不可控副作用；
- 路由、深链和认证重定向；
- 临时UI状态、应用状态、服务端状态和离线状态；
- Provider、Riverpod、BLoC的思想和代价，本项目选择Riverpod候选实现；
- Flutter官方应用架构中的View、ViewModel、Repository、Service职责；
- 依赖反转、错误对象和加载/空/错误/成功状态。

## 时间与任务（15—18小时）

下方120分钟无AI训练计入任务7，不在总时长之外重复增加。

### 任务1：旧App能力体检（2小时）

- 拉起旧App，记录SDK、依赖、构建失败和过期API；
- 画出旧App的数据流、状态管理和网络层；
- 列出三项做得好的地方、三项现在会重构的地方；
- 不立即整库升级，只创建风险清单。

### 任务2：Dart复健实验（3小时）

- 用sealed class表达`Result<T>`或明确错误类型；
- 用record/pattern处理一个工单摘要；
- 对Future和Stream分别构造成功、异常、取消/停止订阅；
- 比较主isolate异步IO与CPU重任务使用isolate的区别；
- 为值对象和JSON映射写测试。

### 任务3：Flutter机制实验（3小时）

- 构造列表无Key/有Key重排实验；
- 构造组件卸载后异步回调的错误与修复；
- 使用DevTools观察一次不必要重建；
- 写一页说明Widget/Element/RenderObject、Context和生命周期。

### 任务4：架构决策（2小时）

比较至少三种结构：简单feature目录、MVVM式UI/数据分层、Clean Architecture重分层。按实施成本、迁移成本、测试、AI生成一致性和长期维护比较。

推荐目标：package-by-feature，每个feature内部使用presentation/application/data边界；不为个人项目建立十几层抽象。记录ADR。

### 任务5：技师App骨架（4—5小时）

- 建立环境配置、路由和认证守卫；
- 建立共享网络/错误/日志基础；
- 建立`work_orders` feature的repository和view model接口；
- 使用假repository完成待办列表、详情和加载/错误/空状态；
- 写一个view model单测和一个Widget测试。

### 任务6：复盘与求职（1小时）

- 更新Flutter项目描述，不声称新项目已上架；
- 采样3—5个Flutter/移动端岗位，记录是否要求原生、上架、推送、支付或小程序；
- 准备3分钟讲解旧App与新架构的差异。

### 任务7：无AI训练（2小时）

执行下方无AI页面状态任务并记录测试、数据流与卡点。

## FactoryCare项目增量

- `technician_app`骨架；
- 登录恢复和路由守卫的假实现；
- 待办列表、详情和明确状态模型；
- 架构ADR与旧App复盘；
- 可运行的单元/Widget测试。

本周不连接真实API和离线数据库，先固定UI/数据边界。

## AI协作边界

可以让AI：

- 将旧Dart语法映射到当前稳定语法；
- 比较Riverpod/BLoC/Provider并指出项目代价；
- 审查生命周期、Context和资源释放；
- 生成少量重复JSON映射代码和测试清单。

不能让AI：

- 一次生成整个App；
- 未经选择引入完整Clean Architecture模板；
- 用大量`!`和`late`掩盖空安全；
- 只因库流行就替换状态管理；
- 升级旧App全部依赖而不读迁移说明。

## 无AI训练（120分钟）

实现一个“技师筛选自己的高优先级待办”页面状态：输入假repository，输出加载、成功、空和错误UI；切换筛选不能重复订阅；组件销毁后无泄漏。写一个view model测试。

## 求职动作

- 更新R2/R3简历的多端一行，强调已有Flutter App与本周架构复健；
- 不把个人项目写成Flutter商业年限；
- 模拟回答：为什么已有uni-app仍需要Flutter？什么场景不该选Flutter？

## 交付物

- [ ] Flutter/Dart版本与`flutter doctor`记录；
- [ ] 旧App复盘；
- [ ] Dart异步、Stream和空安全实验；
- [ ] 技师App架构ADR；
- [ ] 假数据待办垂直切片；
- [ ] 至少一个单元和一个Widget测试；
- [ ] 无AI任务结果和周复盘。

## 验收标准

- 能解释Widget、Element、RenderObject而不混为一谈；
- 能解释`BuildContext`、Key、生命周期和副作用边界；
- 能区分Future、Stream、isolate和线程概念；
- 状态管理选择有约束和取舍，不是“Riverpod最好”；
- 代码可以测试，UI不直接依赖HTTP实现；
- `flutter analyze`和测试通过。

## 本周明确不做

- 完整离线同步、推送和应用商店发布；
- 自定义原生插件；
- 同时支持所有桌面/Web平台；
- 过度Clean Architecture；
- 复制Web管理后台。

## 官方资料

- [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide)
- [Flutter state management](https://docs.flutter.dev/data-and-backend/state-mgmt/intro)
- [Flutter testing](https://docs.flutter.dev/testing/overview)
- [Dart language](https://dart.dev/language)
- [Dart concurrency](https://dart.dev/language/concurrency)
