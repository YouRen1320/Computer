# Flutter：架构、网络、离线、设备与发布

## 1. 一个可维护 Flutter 功能有 UI、应用、领域和数据边界

```text
Presentation：Widget、页面状态、用户事件
Application：Controller/ViewModel、用例编排
Domain：实体、值、规则、Repository 接口
Data/Infrastructure：HTTP、JSON、数据库、插件实现
```

不必为小项目复制四层文件夹，但依赖方向要清楚：业务规则不依赖 BuildContext，UI 不直接解析任意 JSON，插件类型不扩散到所有层。

## 2. 按功能组织比全局技术文件夹更容易维护

```text
features/
  work_orders/
    domain/
    application/
    data/
    presentation/
  auth/
  devices/
```

共享基础设施放 core，但不要变成包含所有杂项的 `utils/`。每项数据和业务规则有模块所有者。

## 3. DTO、领域对象和 UI Model 不应是同一个万能类

```text
API JSON → WorkOrderDto → WorkOrder（领域）→ WorkOrderViewData
```

DTO 处理字段缺失/版本/序列化；领域对象保证不变量；UI Model 提供格式化 label 和显示状态。

复用可减少映射，但会让后端字段、数据库缓存和 UI 一起耦合。关键边界值得显式映射。

## 4. HTTP Client 层负责传输，不负责所有业务决定

职责：

- base URL 和环境；
- timeout 与取消能力；
- headers/认证附加；
- HTTP status 和 body 读取；
- request ID、脱敏日志；
- TLS/代理配置边界。

Repository 将协议结果映射为领域结果。Widget 不应对 401、409、JSON 键和 Token 刷新逐页 switch。

## 5. 每个响应都要检查状态和运行时结构

```dart
final response = await client.get(uri);
if (response.statusCode < 200 || response.statusCode >= 300) {
  throw mapApiError(response);
}
final Object? raw = jsonDecode(response.body);
return WorkOrderDto.fromJson(raw).toDomain();
```

代码生成可减少 JSON 样板，但生成器只按声明解析；声明是否匹配后端、未知 enum、null 和 schema 漂移仍需合同测试。

## 6. 认证凭据按平台安全存储能力处理

普通 SharedPreferences/文件不是高敏凭据保险箱。移动端长期刷新凭据使用经过审查的 Keychain/Keystore 安全存储插件，并理解：

- 设备备份和迁移；
- 生物识别/设备锁；
- rooted/jailbroken 风险；
- Web 目标存储差异；
- 登出/撤销；
- 插件实现与版本。

客户端包中的 API secret 可被提取，真正秘密留服务端。

## 7. Token 刷新要单次协调

多个请求同时 401：

```text
第一个请求启动 refresh
其他请求等待同一个 Future
  → 成功：有限重放
  → 失败：统一清理认证并通知状态层
```

不能每个请求各刷新导致旧 Refresh Token 重用和竞态。重放前确认 body 可重发、写请求有幂等键。

401、403、断网和服务器错误不能都触发刷新。

## 8. 取消协议要贯穿 UI 到传输

用户离开详情或搜索条件变化：

```text
Controller 取消当前 operation
  → HTTP client 尝试取消
  → 解析/状态更新检查 token/generation
  → 旧结果不再写入
```

Future 没有通用强制取消；使用具体客户端 cancel token 或协作标记。即使网络不可取消，状态所有权检查仍必要。

## 9. Timeout 不表示服务器没有执行

POST 在客户端超时，服务端可能已经创建工单。写入应携带稳定 Idempotency-Key，UI 显示结果未知并可查询/安全重试。

读取可有限重试；写请求只有在协议和服务端明确幂等时自动重试。

## 10. 缓存要定义来源、过期和冲突

```text
Memory cache：当前进程快速副本
Disk cache：重启后可恢复副本
Server：权威事实
```

每项缓存需要 key（含用户/租户）、schema version、updatedAt/TTL、失效和容量。登出/切账号清理敏感数据。

离线页面显示“最后同步时间”，不能让用户误以为旧状态实时。

## 11. Offline-first 不是把每个失败请求无限排队

先决定哪些操作可离线：

- 保存报修草稿：通常可以；
- 创建工单：可用幂等命令队列；
- 关闭工单：可能因状态/权限变化需冲突处理；
- 管理员删除：高风险，通常要求在线确认。

离线队列保存业务命令、稳定幂等键和最小 payload，不保存过期 Token 和任意 URL。

## 12. 本地队列要有显式状态机

```text
pending → sending
  ├── succeeded
  ├── retryWait
  ├── blockedAuth
  ├── conflict
  └── deadLetter
```

应用重启恢复 `sending` 的不确定命令时，使用同一幂等键重放。调度器有互斥、退避、顺序/公平和网络/认证条件。

## 13. 冲突不能统一“最后写入覆盖”

服务端 409/version 冲突时：

- 读取最新实体；
- 保留本地草稿；
- 根据字段/操作显示差异；
- 可安全合并则明确合并；
- 状态机动作让用户重新决定；
- 新提交带最新 version。

图片附件、评论追加可能容易合并；工单分派/关闭不能盲目覆盖。

## 14. 本地数据库迁移和加密要有边界

SQLite/对象数据库 schema 会随 App 版本升级。需要：

- versioned migrations；
- 失败回退/备份策略；
- 测试从支持的旧版本升级；
- 不降级读取不兼容新库；
- 敏感字段最小化/加密；
- 密钥不与密文同样裸存；
- 删除与登出清理。

加密数据库不解决屏幕、日志、备份和已解锁进程中的泄露。

## 15. 设备 API 通过接口隔离插件

```dart
abstract interface class Scanner {
  Future<ScanResult> scan();
}
```

presentation/controller 依赖 ScanResult；Android/iOS/Web 插件实现适配。这样能在测试提供 fake，也能统一 denied/cancelled/unavailable/failed。

不要让插件错误码和平台对象扩散到所有页面。

## 16. 相机和扫码需要权限前说明与降级

用户点击“扫码”后说明用途并请求权限。结果：

- granted：打开并验证扫描值；
- cancelled：回到页面，不报故障；
- denied：说明影响，允许手输；
- permanently denied：提供打开设置入口；
- unavailable：设备不支持，显示替代。

不能在每次 build/initState 反复请求权限。

## 17. 选择图片、压缩、上传和绑定是多步流程

```text
选择/拍摄本地临时文件
  → 校验尺寸、类型和数量
  → 可选压缩/旋转（大图处理可用 isolate/原生能力）
  → 上传取得 attachmentId
  → 创建/更新工单绑定
```

临时路径可能被系统清理；需离线保留时复制到受控应用目录并记录生命周期。EXIF 可能含位置隐私，可按需求清理。

## 18. 定位包含权限、服务状态、精度和坐标系

定位失败可能是：拒绝、系统定位关闭、超时、室内无信号、平台不支持。结果模型应含精度/时间/坐标语义。

最小化采集，非必要不后台持续定位。iOS/Android 权限说明文案、manifest 和商店隐私声明必须与实际用途一致。

## 19. Platform Channel 连接 Dart 与原生代码

插件通常封装 MethodChannel/EventChannel 等通信：

```text
Dart 调用方法/订阅事件
  ↔ 编码消息
Android Kotlin/Java 或 iOS Swift/Obj-C
```

要定义方法名、参数 schema、错误码、线程、生命周期和取消。大数据高频过桥有成本。

能用成熟维护插件优先插件；引入前审查平台支持、权限、隐私、发布活跃度和 breaking changes。

## 20. App Lifecycle 和页面生命周期不同

应用进入 inactive/paused/detached 等状态时，网络、相机、计时器和草稿可能需要暂停/保存。

不能保证收到所有终止回调：系统可直接杀进程。因此关键状态及时持久化，恢复时校验版本和身份。

页面仍在导航栈不代表 App 可见；摄像头/定位应在后台按平台规则释放或暂停。

## 21. Unit Test 验证纯规则和 Controller

适合：

- JSON 映射和领域不变量；
- 重试/错误分类；
- 离线 reducer；
- Controller 状态转移；
- 幂等 key 稳定；
- 权限结果映射。

用 fake Repository、Clock 和设备端口。断言状态序列和副作用调用，不验证私有字段。

## 22. Widget Test 在受控 Flutter 环境操作 UI

```dart
await tester.pumpWidget(testApp(child: page));
await tester.tap(find.text('提交'));
await tester.pump();
expect(find.text('提交中'), findsOneWidget);
```

`pump` 推进一帧，`pumpAndSettle` 等到没有安排帧；无限动画会让 settle 超时。最好等待特定状态并控制 Future/Clock，不盲目 settle。

通过语义/文字/key 查找，少依赖 Widget 私有树形细节。

## 23. Integration Test 覆盖真应用和平台边界

适合关键流程：登录、扫码/手输降级、上传、离线恢复、深链和权限拒绝。

平台权限对话框、相机和后台恢复可能需要真机/平台测试或受控测试设备，不能完全在 Widget Test Mock 后宣称已验证。

测试数据、账号、租户和后端环境要隔离。

## 24. Golden Test 检测像素输出回归

固定设备、字体、语言、主题、像素比和数据后比较图片。适合设计系统和关键状态。

它不验证点击、语义和不同真实 GPU/字体平台。差异需要人工判断是回归还是批准改版。

多平台 golden 若不稳定，应缩小组件范围而不是不断更新基准掩盖问题。

## 25. 可访问性需要 Semantics 与真实设备验证

Widget 测试可检查部分 semantics；还需：

- TalkBack/VoiceOver；
- 键盘和 Switch/外部输入；
- 大字体；
- 高对比/深色；
- 减少动效；
- 横屏与小屏；
- 焦点恢复和错误提示。

自定义 Canvas 图表/控件要提供语义替代和操作入口。

## 26. Flutter 性能看帧预算和流水线

UI 需要在刷新周期内完成：

- Dart build/layout 等 UI 工作；
- raster 绘制/合成；
- 图片解码和 shader 等。

卡顿可能来自长 build、过大图片、昂贵绘制、同步 I/O 或 CPU 解析。用 profile mode 的 DevTools Performance view 区分 UI 和 raster，不凭肉眼猜。

## 27. 减少无意义重建，但先测量

可：

- 拆小监听范围；
- 使用 const Widget；
- 状态只通知真正依赖者；
- 避免 build 创建昂贵对象/发请求；
- 保持 List key；
- 长列表使用 builder；
- 大型不可变数据减少深复制。

build 本身设计为可频繁调用。不要为避免任何 build 创建全局缓存和复杂手动更新。

## 28. 图片和内存是移动端常见瓶颈

高分辨率图片解码后占用宽×高×像素字节，远大于压缩文件。列表应请求/解码缩略尺寸，限制缓存和并发。

Memory DevTools 看 heap、图片、对象保留；dispose Controller 并不会自动清空无上限全局 cache。

大图处理放 worker isolate 或平台优化能力，并在低内存设备真测。

## 29. 构建 Flavor 隔离环境但客户端配置不是秘密

dev/staging/prod 可有不同：

- application/bundle ID；
- app 名称/图标；
- API base allowlist；
- 日志级别；
- 推送/地图配置；
- 签名与发布渠道。

产物中所有值可被提取。服务端密钥不编译进 App。CI 明确 flavor、commit 和依赖，不从开发者本机隐藏文件随意取生产配置。

## 30. Android 与 iOS 签名是发布身份

签名密钥/证书用于证明后续版本由同一发布者。丢失、泄露或到期会阻断更新或造成安全事故。

- 密钥进入受控 secret manager；
- CI 最小权限取用；
- 不提交仓库/聊天；
- 有备份、轮换和负责人；
- 区分开发/生产；
- 记录商店托管密钥边界。

具体 Play/App Store 签名流程以当前官方平台文档为准。

## 31. 版本包含用户版本和递增构建号

```text
versionName / CFBundleShortVersionString：用户看到
versionCode / CFBundleVersion：平台判断构建顺序
```

Flutter pubspec 可提供版本来源，但平台打包和 CI 可能覆盖。每个崩溃关联 app version、build、commit、flavor、平台和符号文件。

## 32. Obfuscation 不等于保护秘密

Dart 符号混淆可增加逆向难度/缩小部分符号，但客户端逻辑、端点和嵌入值仍可分析。不要在 App 保存服务端 secret 或把安全授权放客户端。

混淆后崩溃堆栈需要匹配的 symbols 反解。符号是发布制品，必须安全归档并关联 build。

## 33. 崩溃和错误监控要在发布前接好

捕获：

- Flutter framework error；
- 平台 dispatcher 未处理错误；
- isolate 错误；
- 原生崩溃；
- 关键 API/离线同步失败；
- app version/build/device 大类。

脱敏：不发送 Token、位置、照片、表单正文和敏感路径。监控 SDK 自身也是第三方数据流，需要隐私声明与同意策略。

## 34. Source Map/Symbol 必须与具体产物匹配

不同平台/ABI/构建产生不同符号。上传错版本会把堆栈映成错误源码。

发布流水线原子保存：

```text
APK/AAB/IPA
  + symbols/source maps
  + commit/lockfile/SDK versions
  + build configuration
  + mapping/upload receipt
```

## 35. 灰度与回滚受商店分发限制

可用内部测试、TestFlight、分阶段发布等降低风险，但：

- 用户升级有延迟；
- 已安装客户端不能全部瞬时回滚；
- 数据库和 API 必须向后兼容；
- 远程配置/feature flag 需要安全默认和审计；
- 严重问题可能先服务端禁用功能，再发布修复。

回滚计划应在发布前写清客户端、后端、配置和数据各自方案。

## 36. 发布验收是多端矩阵

至少覆盖：

- 支持的最低/代表/最新 Android、iOS；
- 冷启动、升级安装、登出/登录；
- 深链接和推送入口；
- 权限首次、拒绝、设置后恢复；
- 相机、扫码、定位、上传；
- 弱网/断网/切网；
- 后台/前台、进程被杀恢复；
- 大字体、屏幕阅读器；
- release build 性能；
- 隐私说明和商店元数据。

模拟器不代表相机、性能、系统权限和签名安装。

## 37. 这篇的整体地图

```text
UI → Controller/ViewModel → Domain → Repository
  → HTTP/JSON、安全存储、本地数据库、设备插件

在线：取消、认证恢复、运行时 schema、错误映射
离线：业务命令 + 稳定幂等 + 分类重试 + 冲突
设备：能力 + 权限 + 降级 + 生命周期
验证：unit → widget → integration/golden → 真机矩阵
发布：flavor → 签名 → 制品/符号 → 灰度 → 监控/回退
```

必须掌握：插件类型要隔离；Token 刷新要单次协调；超时/取消不撤回服务端写入；离线只排队经过设计的命令；权限拒绝必须有降级；Flutter 性能在 profile 真机测；签名和 symbols 都是关键制品；客户端无法保证即时回滚。

具体网络库、数据库、路由/状态库和应用商店流程属于“需要时查询”，真正实施时按当前 Flutter、Android 与 Apple 官方文档复核。
