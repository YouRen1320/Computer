---
schema_version: 2
edition: 2026.2-draft
id: ch.flutter.device-apis
title: 相机、扫码、定位、权限与平台通道
responsibility: 通过插件与平台通道使用相机、扫码和定位，显式建模授权、拒绝、取消和不可用路径，不把平台异常泄漏为任意字符串。
volume: '11'
order: 17
level: L3
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.flutter.device-apis.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.flutter.network-storage-offline
- ch.security.untrusted-input-xss-ssrf
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
  text: 在 120 秒内解释“相机、扫码、定位、权限与平台通道”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - flutter-device-permission
  - flutter-platform-channel
  covers_topics:
  - flutter.camera-scan
  - flutter.geolocation
  - flutter.permission-state
  - flutter.settings-recovery
  - flutter.device-capability-fallback
  - flutter.method-channel
  - flutter.platform-exception
  - flutter.codec-boundary
  - flutter.plugin-lifecycle
  - flutter.native-thread-boundary
  uses_capabilities:
  - mobile.flutter-device-permissions
  - mobile.flutter-network-offline
  - mobile.flutter-layout-lifecycle
  - mobile.dart-future-cancellation
  - security.web-threat
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现可替换平台接口的扫码、拍照和定位流程并保存权限矩阵及真机证据；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - flutter-device-permission
  - flutter-platform-channel
  covers_topics:
  - flutter.camera-scan
  - flutter.geolocation
  - flutter.permission-state
  - flutter.settings-recovery
  - flutter.device-capability-fallback
  - flutter.method-channel
  - flutter.platform-exception
  - flutter.codec-boundary
  - flutter.plugin-lifecycle
  - flutter.native-thread-boundary
  uses_capabilities:
  - mobile.flutter-device-permissions
  - mobile.flutter-network-offline
  - mobile.flutter-layout-lifecycle
  - mobile.dart-future-cancellation
  - security.web-threat
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: platform-interface-fake-permission-matrix-device-smoke
- id: diagnose
  kind: fault-diagnosis
  text: 面对“权限结果当空值、插件回调在销毁后更新或平台异常未映射”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - flutter-device-permission
  - flutter-platform-channel
  covers_topics:
  - flutter.camera-scan
  - flutter.geolocation
  - flutter.permission-state
  - flutter.settings-recovery
  - flutter.device-capability-fallback
  - flutter.method-channel
  - flutter.platform-exception
  - flutter.codec-boundary
  - flutter.plugin-lifecycle
  - flutter.native-thread-boundary
  uses_capabilities:
  - mobile.flutter-device-permissions
  - mobile.flutter-network-offline
  - mobile.flutter-layout-lifecycle
  - mobile.dart-future-cancellation
  - security.web-threat
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
generated_by: scripts/generate-curriculum.rb
generated_spec_digest: 1cac3c66efb06a255e6f9c2478f1c998ae0828cd63f132727c63025f29a7c554
---
# 相机、扫码、定位、权限与平台通道

> 手机摄像头、扫码器和定位服务并不是普通函数。它们跨过 Dart、Flutter 引擎、插件、原生系统、硬件和人的授权决定等多条边界。一次调用可能成功，也可能被拒绝、被永久拒绝、被用户取消、被系统中断、遇到没有该硬件的设备，或者在页面已经销毁后才返回。本章的目标不是记住某个插件的调用语法，而是建立一套可替换、可测试、不会泄露平台异常的设备能力合同。

## 1. 先从用户动作开始，而不是从“启动时申请全部权限”开始

FactoryCare 的维修人员打开工单详情时，应用可能提供“扫描设备码”“拍摄故障照片”和“记录当前位置”三个动作。正确流程是用户明确点击某个动作，界面先说明目的和数据用途，再请求完成该动作所需的最小权限。应用启动就连续弹出相机、定位、相册和通知授权，既缺乏上下文，也会让用户无法判断为什么需要这些数据。

设备能力流程至少包含六个参与者：用户意图、表现层状态、应用用例、平台能力端口、插件或 `MethodChannel` 适配器、Android/iOS 与硬件。表现层不应直接捕获任意 `PlatformException` 后显示 `exception.toString()`；领域和应用层也不应 import 某个相机插件的具体控制器。应用层只需要知道“请求一次扫码”的业务结果，data/platform 层负责吸收插件差异。

把整个过程画成一条链会更清楚：

```text
用户点击
  -> UI 进入检查中
  -> 查询设备能力与服务状态
  -> 查询当前授权状态
  -> 必要时展示用途说明并请求授权
  -> 打开设备资源
  -> 用户完成或取消
  -> 校验与最小化结果
  -> 关闭设备资源
  -> UI 映射为确定状态
```

任何一步都可能失败，而且失败类型决定下一步。没有摄像头应走手工输入；临时拒绝可以解释后再次由用户触发；永久拒绝只能提供“打开系统设置”的恢复入口；用户取消扫描不是系统错误；定位服务关闭与定位权限拒绝也不是一回事。

## 2. 设备权限不是 `bool?`

初学实现常把权限结果写成 `bool? allowed`：`true` 表示允许，`false` 表示拒绝，`null` 表示还不知道。这个模型无法表达“未询问”“系统限制”“永久拒绝”“服务关闭”“平台不支持”和“请求正在进行”，随后代码只能靠字符串和空值猜测。

更可靠的应用合同可以显式枚举：

```dart
enum PermissionState {
  notRequested,
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unavailable,
}

enum DeviceServiceState { enabled, disabled, unavailable }
```

不同插件和平台的原始枚举未必完全一致，适配器必须做保守映射。无法确认的原始值不能默认当成 `granted`；更不能把 `null` 当“用户允许但暂无数据”。新增平台状态时，编译器能通过穷尽 `switch` 提醒映射缺口，这正是显式类型的价值。

权限状态和能力结果还要分开。拥有相机权限不代表设备真的有可用摄像头；拥有定位权限不代表系统定位服务已打开；扫码成功也不代表字符串符合 FactoryCare 的设备编号格式。授权只表示系统允许尝试访问某类资源，不为硬件、数据质量或业务真实性背书。

## 3. Android 与 Apple 平台上的稳定原则

Android 对危险权限采用运行时请求。应用需要先在清单中声明，再在有业务上下文时请求；系统可能建议展示用途说明，用户也能拒绝或以后在设置中改变决定。不能用一个固定请求次数推断“永久拒绝”，应以当前平台 API 或插件明确给出的状态和可恢复动作处理。

Apple 平台要求在 `Info.plist` 中提供相机、麦克风或定位等用途说明。缺少所需用途键可能让请求立即失败；用途文本必须真实说明当前功能，不应写含糊的“为了提供更好服务”。定位的“使用期间”和“始终允许”具有不同隐私、耗电与审核影响，前台打卡通常不应为了方便直接请求后台持续定位。

稳定原则有四条：最小权限、接近使用时请求、允许用户拒绝、重新进入前重新查询。平台的精确清单键、最低系统版本、插件 API 和商店政策属于变化面；发布前必须按目标 Flutter stable、插件版本、Android target SDK 与 Xcode/iOS 版本复核，而不是照抄教材中的旧配置。

## 4. 权限状态机决定 UI，而不是反复弹窗

一个可解释的权限状态机可以这样设计：

```text
idle -> checking
checking -> ready                 已授权且能力可用
checking -> rationale             尚未授权，可解释后请求
checking -> settingsRequired      永久拒绝或平台不再弹窗
checking -> restricted            家长控制、企业策略等系统限制
checking -> capabilityUnavailable 没有硬件或服务关闭
rationale -> requesting
requesting -> ready | denied | settingsRequired | restricted
ready -> active -> completed | cancelled | failed
```

“拒绝”页面必须可停留，不要在 `build()`、`didChangeDependencies()` 或每次恢复前台时自动再次请求。用户点击“继续”才发起系统授权；点击“暂不”则回到可使用其他功能的页面。`settingsRequired` 可以展示设置入口，但进入系统设置不代表授权一定改变，返回应用时必须重新查询。

同时只允许一个同类请求在进行。双击扫码按钮时，第二个动作可以被忽略、排队或返回 `busy`，但不能叠加两个相机控制器和两次系统授权。UI 通过 `requestId` 或状态持有者保证当前动作唯一，平台适配器也应防止重入。

## 5. 相机与扫码是有生命周期的资源

Flutter 官方维护的 `camera` 插件能预览、拍照、录像和读取图像流，但插件文档明确把生命周期处理责任交给应用。应用进入 inactive、页面离开、系统抢占相机或控制器初始化失败时，需要释放或重建资源。只在 `dispose()` 调一次 `controller.dispose()`，不一定覆盖前后台切换和初始化中断。

一个安全的资源所有者应满足：创建和释放成对；初始化失败也会清理半成品；同一时刻只有一个活动会话；回调带会话代号；旧会话结果不会覆盖新会话；日志只记录诊断码，不记录完整图片或扫码正文。`CameraController` 等具体类型应留在适配器内，应用合同可以只暴露 `startScan`、`capturePhoto` 与 `closeSession`。

扫码通常建立在相机图像流和识别库之上。每帧都做识别会造成 CPU、发热与掉帧；可以限制并发，只处理上一帧完成后的下一帧，或按时间采样。一旦识别到候选值，应停止重复提交，再做长度、字符集、校验位和业务存在性验证。二维码是外部输入，可能包含超长文本、URL、控制字符或伪造设备编号，不能因为来自摄像头就信任。

## 6. 设计统一的扫码结果，而不是返回任意字符串

应用层可以使用封闭结果类型：

```dart
sealed class ScanResult {
  const ScanResult();
}

final class ScanSucceeded extends ScanResult {
  final String deviceCode;
  const ScanSucceeded(this.deviceCode);
}

final class ScanCancelled extends ScanResult {
  const ScanCancelled();
}

final class ScanUnavailable extends ScanResult {
  final DeviceFallback fallback;
  const ScanUnavailable(this.fallback);
}

final class ScanDenied extends ScanResult {
  final PermissionState permission;
  const ScanDenied(this.permission);
}

final class ScanFailed extends ScanResult {
  final DeviceFailureCode code;
  const ScanFailed(this.code);
}
```

`ScanCancelled` 是用户做出的正常选择，不应进入崩溃监控；`ScanDenied` 需要权限恢复 UI；`ScanUnavailable` 应附带手工输入、从已绑定设备选择等回退；`ScanFailed` 才是可观察的技术失败。原始插件 code、message、details 可以进入受控诊断事件，但不应穿过应用合同成为用户文本。

扫码结果还应在信任边界处标准化。例如去掉明确允许的首尾空白、限制 UTF-8 字节长度、只接受项目定义的设备码格式，并把原始值与标准化值的日志策略分开。错误做法是对任意 URL 直接发请求，或把码中路径拼接进文件系统与 API URL；这会把扫码入口变成 SSRF、路径穿越或租户越权入口。

## 7. 拍照结果是文件句柄，不是可永久保存的业务记录

相机插件返回的临时文件路径通常只是捕获结果。应用要区分临时捕获文件、待上传附件和服务端已确认附件。用户取消、压缩失败、上传失败、进程重启与工单提交成功后，它们的保留规则不同。

推荐流程是：捕获到临时文件；检查 MIME/签名、大小和像素上限；必要时在受控隔离工作中压缩或纠正方向；复制到应用拥有的待上传目录；建立带本地 ID 的附件记录；由离线队列上传；服务器返回附件 ID 后再关联工单；最终按保留政策清理临时文件。不要只依据扩展名信任图片，也不要把完整本地路径传给服务器。

照片可能包含人脸、工牌、屏幕内容、GPS EXIF 等敏感信息。产品必须定义是否保留 EXIF、最大留存时间、谁能查看、是否允许导出与何时删除。调试日志不得写入图片字节或公开下载 URL。权限获批并不等于用户同意无限用途的数据处理。

## 8. 定位要同时检查服务、权限、精度和时效

定位流程至少回答四个问题：设备是否提供定位能力；系统定位服务是否打开；应用拥有什么授权；返回位置是否足够新且精度符合当前用途。把经纬度不为空当成功，会接受几小时前的缓存点或误差数公里的位置。

应用侧可以定义：

```dart
final class PositionFix {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime measuredAt;
  const PositionFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.measuredAt,
  });
}
```

然后由用例按照场景判断，例如维修到场只接受五分钟内且精度小于一百米的点；不满足时显示“位置精度不足，可重试或说明原因”，而不是伪装为精确地址。纬度必须在 `[-90, 90]`、经度在 `[-180, 180]`，数值必须有限；服务端仍需重新校验，不信任客户端时间和坐标。

定位请求还要有超时与取消语义。用户离开页面或取消动作后，即使底层系统最终返回位置，也不能再更新已销毁 UI 或提交业务命令。若插件只能停止监听而不能取消一次性 Future，合同应诚实记录“停止接收结果”，并用请求代号丢弃迟到值。

## 9. 能力检测和回退是产品功能，不是异常兜底

模拟器可能没有摄像头，桌面或 Web 平台可能不支持某插件，低端设备可能无法使用指定分辨率，企业策略也可能限制硬件。可靠应用要在用户进入动作前检测能力，并准备等价或受控降级：扫码不可用时允许输入设备编号；相机不可用时允许从受控文件选择器添加附件；定位不可用时允许用户选择站点并填写原因。

回退不能绕过安全规则。手工输入仍要校验租户和设备码；文件选择仍要验证内容、大小与访问范围；手工站点不能伪装成 GPS 证据。数据模型要记录来源，例如 `capturedCamera`、`selectedFile`、`manualEntry`、`deviceLocation`，让审计和服务端规则知道证据强度。

“当前平台不支持”应是正常状态，而不是 catch 所有异常后统一显示。平台支持矩阵至少包含目标平台、最低系统版本、插件实现、硬件要求、清单配置、模拟器能力和已经验证的真实设备型号。矩阵是发布证据的一部分，不能靠开发机一次成功推断所有设备。

## 10. 用端口隔离插件与 UI

应用层端口可以保持业务语义：

```dart
abstract interface class DeviceEvidencePort {
  Future<ScanResult> scanDeviceCode(DeviceRequest request);
  Future<PhotoResult> captureFaultPhoto(DeviceRequest request);
  Future<LocationResult> readCurrentLocation(DeviceRequest request);
  Future<void> cancel(String requestId);
}
```

`DeviceRequest` 包含请求 ID、动作、截止时间和允许的用途，不包含 `BuildContext`。真实 Flutter 适配器组合权限插件、camera、定位插件或平台通道；Fake 适配器从测试脚本返回预设结果。页面只观察应用状态，因此换扫码库时不需要重写 UI 状态机。

端口也让“首次拒绝”“永久拒绝”“没有硬件”“用户取消”“成功但数据非法”成为普通测试输入。若接口只返回 `Future<String?>`，Fake 也只能返回字符串或空值，无法验证真正的风险。这说明接口形状本身决定可测试性。

不要把平台端口做成全局静态单例。相机控制器、订阅和请求代号都有生命周期；通过 feature scope 或页面上层的 composition root 注入更容易在退出时释放，也能为不同测试创建互不污染的实例。

## 11. `MethodChannel` 是消息协议，不是魔法函数调用

当现有插件不能满足需求时，可以使用平台通道调用 Kotlin、Swift 等原生代码。Flutter 官方架构说明：Dart 端和宿主端通过相同的 channel 名、method 名和 codec 约定异步传递消息。`MethodChannel('com.factorycare/device')` 的字符串、`scanCode` 方法名、参数 Map 的键和值类型，构成一个跨语言协议。

协议必须版本化和验证：

```dart
const _channel = MethodChannel('com.factorycare/device/v1');

Future<Map<String, Object?>> invokeScan(String requestId) async {
  final raw = await _channel.invokeMapMethod<String, Object?>(
    'scanCode',
    <String, Object?>{'requestId': requestId, 'schema': 1},
  );
  if (raw == null) throw const DeviceProtocolFailure('EMPTY_RESPONSE');
  return raw;
}
```

不要直接写 `as String` 假设宿主永远返回正确类型。校验 schema、必填字段、未知枚举、长度和数值范围；未知字段可以按兼容策略忽略，未知必需语义必须失败关闭。原生端也要验证 Dart 参数，不能把 Map 中路径、URL 或命令直接交给系统 API。

Flutter 官方文档还强调 channel 调用涉及平台线程约束。Dart 侧调用虽是异步，平台实现注册、回调和 UI API 通常必须遵守主线程规则；耗时图像处理不能阻塞平台主线程，也不能在任意后台线程直接回调 UI。具体线程 API按 Android/iOS 官方规则实现并在真机上验证。

## 12. Codec 边界与类型安全

标准消息 codec 支持 null、布尔、数字、字符串、字节数组、列表和 Map 等有限类型。Dart 的 `int`、Kotlin 数字和 Swift 数字桥接时仍要检查范围；日期应传明确格式或 epoch 单位并注明时区；枚举应传稳定 code 而非本地化展示文案；二进制大对象应考虑文件、流或专用传输，而不是把巨大图片塞进普通消息。

手写 Map 的风险是双方字段漂移。Pigeon 等代码生成工具可以生成类型化消息接口，减少方法名和字段拼写错误，但它不会替你决定权限状态、错误码、兼容策略和隐私规则。生成代码是协议实现，schema 设计仍由团队负责。

合同演进可遵循：新增可选字段保持向后兼容；改变字段含义要升版本；删除字段先观察旧客户端；平台实现无法识别 method 时返回明确 `notImplemented`；Dart 映射为 `capabilityUnavailable`，而不是显示原生栈。发布前要用旧 Dart/新原生和新 Dart/旧原生组合测试升级路径。

## 13. 平台异常必须在适配器内归一化

`PlatformException` 可能包含 `code`、`message`、`details` 和 stack trace。它是基础设施诊断，不是稳定业务合同。不同插件会使用不同 code，同一平台升级也可能改变 message。适配器应按照明确表格映射到内部错误：

| 原始类别 | 内部结果 | 用户动作 | 是否上报 |
| --- | --- | --- | --- |
| 已拒绝 | `permissionDenied` | 解释后由用户重试 | 聚合计数，不报崩溃 |
| 永久拒绝/不再弹窗 | `settingsRequired` | 打开设置、返回后重查 | 聚合计数 |
| 系统限制 | `restricted` | 告知不可在应用内恢复 | 需要时记录设备策略类别 |
| 没有硬件/未实现 | `unavailable` | 提供回退 | 兼容性指标 |
| 用户取消 | `cancelled` | 返回原页面 | 通常不报错 |
| 协议字段错误 | `protocolViolation` | 安全失败，可重试 | 高优先级诊断 |
| 未知平台故障 | `platformFailure` | 安全提示与重试 | 脱敏上报 |

日志可保存内部 code、应用版本、平台版本、插件版本、请求阶段和相关 ID；不得默认保存扫码全文、精确坐标、图片路径、权限说明中的用户数据或原始 `details`。对未知异常使用白名单式提取，而不是把 `toString()` 整段上传。

## 14. 异步回调、页面销毁与会话代号

`mounted` 只能阻止已销毁 `State` 调用 `setState`，不能取消相机初始化、定位查询或原生回调。只写 `if (!mounted) return` 会减少 UI 异常，但资源仍可能占用，旧结果仍可能修改 repository 或发出上传命令。

更完整的做法是应用状态持有者为每次设备动作生成单调递增的 generation 或唯一 `requestId`。新动作开始时取消旧端口；任何结果返回时比较当前 ID；不匹配就丢弃且释放结果资源；页面销毁时调用端口 cancel/close，并让状态持有者停止通知。即使底层不可真正取消，迟到结果也不能成为当前事实。

```dart
Future<void> scan() async {
  final id = _nextRequestId();
  _activeRequestId = id;
  emit(DeviceUiState.scanning(id));
  final result = await _port.scanDeviceCode(DeviceRequest(id));
  if (_activeRequestId != id || _closed) return;
  emit(mapScanResult(result));
}
```

还要处理异常路径的资源释放。用 `try/finally` 关闭会话，确保初始化部分成功后也能释放；不要只在成功分支 dispose。若结果包含临时文件，丢弃迟到结果时也要调用明确清理函数，否则不会更新 UI但会泄漏磁盘。

## 15. UI 状态要让每条路径都有确定画面

页面状态可以分成 `idle`、`checking`、`explaining`、`requesting`、`active`、`success`、`cancelled`、`denied`、`settingsRequired`、`unavailable` 与 `failure`。其中 `cancelled` 可立即回到 idle 或展示轻提示，`denied` 允许再次由用户触发，`settingsRequired` 显示设置按钮，`unavailable` 显示回退入口。

不要同时维护 `loading=true`、`permissionDenied=true`、`result!=null` 三个互相矛盾的布尔值。封闭状态能在 `switch` 中得到穷尽检查，也方便 Widget 测试为每个状态断言文本、按钮与语义标签。显示设置按钮时，还要告诉用户返回后会重新检查，而不是宣称“已经授权”。

可访问性同样属于设备流程：相机预览需要文字说明和退出动作；扫码成功不能只靠颜色或震动；授权说明可由屏幕阅读器读出；按钮有稳定语义标签；旋转、系统字体和键盘输入不能阻断手工回退。系统权限弹窗属于原生 UI，普通 Flutter `integration_test` 无法直接操控所有原生对话框，因此需要真机手工或支持原生 UI 的额外测试方案。

## 16. FactoryCare 设备证据用例

以“扫码绑定设备并附加到维修工单”为例，完整合同可以是：

1. UI 发出 `StartDeviceScan(workOrderId)`，应用层先确认当前用户对工单有访问权。
2. 端口查询扫码能力与权限；永久拒绝时返回设置恢复，不自动循环请求。
3. 相机会话只识别一个候选后立即停止重复识别。
4. 应用校验设备码格式，再调用 Java 后端查询；客户端结果不直接建立绑定。
5. 服务端依据租户、权限和设备状态确认，返回公开 DTO。
6. 页面展示设备名称供用户二次确认；确认动作使用幂等键提交。
7. 取消、离线与冲突按既有网络/离线合同处理，不让设备插件负责重试业务命令。
8. 审计只记录设备 ID、动作结果和关联 ID，不记录原始二维码全部内容。

拍照和定位也遵循同一分层：设备端口采集最小证据，应用用例判断是否满足工单规则，网络/离线层负责可靠上传，Java 服务端最终授权和保存。Python/AI 可以以后分析已授权的附件，但不能绕过 Java 的业务事实与访问控制。

## 17. Fake、合同测试与权限矩阵

单元和 Widget 测试不应真的打开相机。Fake 平台端口按脚本返回结果，并记录调用次数、请求 ID 和 cancel。至少覆盖：已授权成功；首次未授权后允许；拒绝；永久拒绝；系统限制；用户取消；没有设备；服务关闭；协议异常；页面销毁后迟到；快速发起第二次请求。

权限矩阵不是十个随意测试名，而是输入、期望状态和允许动作的表：

| 权限/能力 | 端口结果 | UI | 可执行动作 |
| --- | --- | --- | --- |
| granted + available | active/success | 预览或结果确认 | 取消、确认 |
| denied | denied | 用途说明 | 暂不、再次触发 |
| permanentlyDenied | settingsRequired | 设置恢复说明 | 打开设置、返回 |
| restricted | restricted | 系统限制说明 | 手工回退 |
| granted + noCamera | unavailable | 无摄像头 | 手工输入 |
| userCancelled | cancelled/idle | 不显示错误 | 再次开始 |
| protocolViolation | failure | 安全错误码 | 重试、反馈 |

Fake 绿只证明 Dart 状态机和映射。真实插件注册、清单、权限弹窗、相机方向、内存、定位精度、后台切换和不同厂商设备仍需设备 smoke。两类证据不能互相替代。

## 18. 真机 smoke 的证据格式

真机验证至少记录：commit、Flutter/Dart、插件锁文件摘要、应用版本、目标平台与系统版本、设备型号、安装方式、权限初始状态、操作步骤、预期、实际、日志位置、截图或录屏、清理步骤和退出码。不得只写“我手机可以”。

每次权限路径需要可重置前置状态。Android 可通过设置页或受控测试设备重置；iOS 的授权状态与系统弹窗策略不同，应记录卸载重装或设置恢复步骤。不要在个人常用手机上随意清除数据；测试设备也不得包含真实客户工单或敏感照片。

设备 smoke 至少包括前台成功、用户取消、临时拒绝、永久拒绝/设置恢复、无服务或能力回退、快速切后台再恢复、页面退出后的迟到结果。扫码要验证错误格式和超长输入；定位要记录精度和时间；拍照要验证旋转、临时文件清理与上传前大小限制。

本章仓库资产没有运行这些真机步骤，因为当前环境没有经确认的目标 Android/iOS 工具链、授权状态和测试设备。教材提供矩阵和离线 Fake，不把它包装成真机证据。

## 19. 三类典型故障的诊断顺序

### 19.1 把权限结果当空值

症状是拒绝后页面一直 loading，或 `null` 被当成“无扫描结果”。先看状态转换日志中“permission checked”后的内部枚举，再看适配器映射，不先改 UI 文案。若原始 `deniedForever` 被映射成 null，修复映射并加权限矩阵回归；残余风险是其他平台新枚举仍未知，应失败关闭并上报诊断码。

### 19.2 页面销毁后插件回调更新

症状可能是 `setState() called after dispose()`，也可能没有报错但旧扫描覆盖新页面。首证据是请求 ID、页面 lifecycle 和回调时间线。修复包括释放控制器、取消可取消工作、关闭通知并比较 generation；仅加 mounted 不是完整修复。重跑“进入—开始—立即退出—再次进入”的原测试，并检查资源数量。

### 19.3 平台异常未映射

症状是用户看到原生英文栈、监控出现大量正常拒绝，或日志泄露坐标和路径。首证据是适配器出口类型和日志 payload。修复为白名单映射、脱敏诊断与稳定内部 code；对未知 code 安全失败。再注入未知 `PlatformException`，确认 UI 不显示 message/details、日志仍能关联版本与阶段。

诊断通则是：先确定失败阶段，再找第一条指向本项目边界的可信证据；修复最小职责；重跑原路径和相邻路径；最后记录未验证平台。不能把 catch 范围扩大到 `catch (_) { return null; }` 来制造假绿。

## 20. 安全、隐私与合规清单

相机、位置、文件和平台消息都是不可信输入。客户端校验用于体验和早期拒绝，服务端仍必须按身份、租户、资源与操作重新授权。精确坐标和照片属于高敏感数据时，应定义采集目的、最小范围、传输加密、静态保护、访问审计、保留期限和删除流程。

清单至少包含：用途文案与真实功能一致；不在启动时批量索权；拒绝后仍可使用无关功能；不把授权状态当业务权限；不记录完整扫码值、精确位置和图片；不向未知主机上传；文件校验签名和大小；平台 channel 校验类型；未知错误失败关闭；设置恢复返回后重查；退出时释放资源；测试数据为合成数据；监控遵循脱敏采样。

打开系统设置也是外部动作。应用只能导航到自己的设置页或平台允许的入口，不能承诺用户一定能开启；回来后重新读取状态。不要以“功能必须”为由不停弹窗、阻止退出或诱导授权，这会破坏用户控制权并可能违反平台政策。

## 21. 与 Vue/Web 的类比和差异

浏览器的 `getUserMedia`、Geolocation 与 Flutter 插件都跨设备权限边界；Vue 组件卸载后的 Promise 结果也可能成为陈旧响应。可以把平台端口类比成封装浏览器 API 的 composable/service，把封闭 UI state 类比成 discriminated union，把 requestId 类比成防竞态 token。

差异在于移动应用还包含原生清单、代码签名、插件注册、Activity/ViewController 生命周期、设备厂商差异和商店审核。浏览器页面关闭通常释放更多资源，移动应用前后台切换不等于销毁；权限也由系统设置长期保存。不能把 Web 中一个 `navigator.permissions` 的心智模型机械搬到 Android/iOS。

## 22. AI 协作边界

AI 可以：根据已确定的权限状态机生成 Dart sealed 类型；生成 Fake 场景矩阵；审查 `PlatformException` 是否全部在适配器映射；扫描日志字段中的路径、坐标和扫码正文；为 Android/iOS 配置列出待人工核对项；依据真机日志帮助定位生命周期时序。

开发者必须决定并验证：为什么采集；请求哪一级权限；拒绝后的产品路径；插件维护与平台支持；原生清单和用途文本；文件/位置保留政策；服务端授权；目标真机矩阵；线程和生命周期；商店隐私声明。AI 生成一段 camera 示例不能证明真实设备、权限弹窗或插件版本可用。

禁止让 AI 为了“跑通”把所有权限写入清单、吞掉未知平台异常、在日志输出原始数据、把权限拒绝映射成空列表、伪造真机截图或宣称已经过商店审核。代码审查要问“哪个边界拥有这项决定、哪个状态未覆盖、真实证据在哪”，而不只看调用语法。

## 23. 本章动手路线

### 23.1 Example：权限结果与能力回退

运行 `examples/encyclopedia/ch.flutter.device-apis/verify.sh`。它用纯 Dart 模型覆盖 granted、denied、permanentlyDenied、restricted、cancelled 和 unavailable，证明应用结果不依赖具体插件。运行前预测：永久拒绝时 UI 应出现“再次请求”还是“设置恢复”？

### 23.2 Lab：平台 Fake、请求代号与迟到回调

运行 `labs/encyclopedia/ch.flutter.device-apis/verify.sh`。Lab 注入 Fake 平台响应，验证新请求取代旧请求、页面关闭后迟到结果被丢弃、未知平台错误映射成内部诊断码，并保存权限矩阵输出。它没有打开真实相机或定位。

### 23.3 Exercise：稳定预期红

运行 `exercises/encyclopedia/ch.flutter.device-apis/verify.sh`。初始实现故意把永久拒绝映射成普通 denied，并泄露原始平台 message；验证器应稳定非零。任务是修正状态映射和脱敏边界，不得删除断言或把脚本改成无条件成功。完成尝试后再与私有解对照。

### 23.4 120 秒讲回

不看正文解释：为什么权限不是 bool；权限、服务和设备能力有什么区别；永久拒绝如何恢复；mounted 为什么不等于取消；平台异常在哪层映射；MethodChannel 的三个合同元素；扫码值为何仍不可信；Fake 绿与真机 smoke 各证明什么。说不清哪项就回到对应小节，而不是从头背代码。

## 24. 已验证、未验证与明确不做

本章随附脚本只验证纯 Dart 的权限状态、能力回退、请求代号、迟到结果和异常脱敏合同。它们使用临时目录，不修改真实 Flutter 项目，不访问相机、位置、相册、系统设置、推送或网络，也不请求任何真实权限。

本章**没有验证** Flutter 3.44.x 在本机实际运行、Dart 3.12.x 编译、camera/geolocator/扫码插件真实版本、AndroidManifest、Info.plist、MethodChannel 的 Kotlin/Swift 实现、主线程切换、模拟器、真机、后台行为、定位精度、图片方向、商店隐私审核或无障碍屏幕阅读器。真实项目必须补齐锁定依赖后的 `flutter analyze/test`、平台构建、插件合同测试和真机矩阵。

本章明确不选择通用权限插件品牌，不实现后台持续定位，不实现人脸识别，不把二维码当可信身份，不上传真实附件，不改 FactoryCare 业务 API，也不修改学习进度。平台配置和隐私政策是发布工作，不能由离线样例替代。

## 25. 官方资料与版本边界

以下资料于 2026-07-24 核对。Flutter 官方页面当时属于 3.44 文档家族，SDK Archive 的 stable 为 3.44.x、配套 Dart 为 3.12.x；插件 patch 和平台政策变化更快，实施当天必须重新确认：

- [Flutter：Writing custom platform-specific code](https://docs.flutter.dev/platform-integration/platform-channels)
- [Flutter：Architectural overview—platform channels](https://docs.flutter.dev/resources/architectural-overview#platform-channels)
- [Flutter：Developing packages and plugins](https://docs.flutter.dev/packages-and-plugins/developing-packages)
- [Flutter：Testing plugins](https://docs.flutter.dev/testing/testing-plugins)
- [Flutter 官方 camera package](https://pub.dev/packages/camera)
- [Android Developers：Request runtime permissions](https://developer.android.com/training/permissions/requesting)
- [Apple Developer：Requesting authorization to use location services](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)
- [Dart：Asynchronous programming](https://dart.dev/language/async)
- [Flutter stable SDK archive](https://docs.flutter.dev/install/archive)

这些来源能确认通道、权限和插件生命周期的基础合同，却不能确认 FactoryCare 已在任何真机上通过。`stable_core: false` 表示平台 API、插件、最低系统版本、权限政策和工具命令仍是变化面；不表示可以忽略版本锁定和发布前复核。
