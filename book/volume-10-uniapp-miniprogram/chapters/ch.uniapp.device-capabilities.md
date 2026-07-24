---
schema_version: 2
edition: 2026.2-draft
id: ch.uniapp.device-capabilities
title: 上传、扫码、定位、权限与失败路径
responsibility: 把上传、扫码和定位封装为显式权限与取消合同，处理拒绝、永久拒绝、不可用和恢复，不把授权弹窗等同于业务同意。
volume: '10'
order: 6
level: L2+
status: drafting
path: book/volume-10-uniapp-miniprogram/chapters/ch.uniapp.device-capabilities.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.uniapp.network-auth-storage
- ch.uniapp.platform-conditional
version_surfaces:
- uni-app
- wechat-miniprogram
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“上传、扫码、定位、权限与失败路径”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - uniapp-device-apis
  - uniapp-permission-state
  covers_topics:
  - uniapp.file-upload
  - uniapp.scan-code
  - uniapp.geolocation
  - uniapp.device-api-result
  - mobile.permission-request
  - mobile.permission-denied
  - mobile.permission-permanent-denied
  - mobile.settings-recovery
  - mobile.capability-unavailable
  uses_capabilities:
  - mobile.uniapp-platform
  - security.authentication
  - security.web-threat
  - mobile.uniapp-device-permissions
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现扫码填单、图片上传和可选定位并保存权限状态机与真机/Mock 证据；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - uniapp-device-apis
  - uniapp-permission-state
  covers_topics:
  - uniapp.file-upload
  - uniapp.scan-code
  - uniapp.geolocation
  - uniapp.device-api-result
  - mobile.permission-request
  - mobile.permission-denied
  - mobile.permission-permanent-denied
  - mobile.settings-recovery
  - mobile.capability-unavailable
  uses_capabilities:
  - mobile.uniapp-platform
  - security.authentication
  - security.web-threat
  - mobile.uniapp-device-permissions
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: permission-state-matrix-device-mock-upload-fault-injection
- id: diagnose
  kind: fault-diagnosis
  text: 面对“把拒绝当空数据、重复请求权限或上传成功但业务提交失败”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - uniapp-device-apis
  - uniapp-permission-state
  covers_topics:
  - uniapp.file-upload
  - uniapp.scan-code
  - uniapp.geolocation
  - uniapp.device-api-result
  - mobile.permission-request
  - mobile.permission-denied
  - mobile.permission-permanent-denied
  - mobile.settings-recovery
  - mobile.capability-unavailable
  uses_capabilities:
  - mobile.uniapp-platform
  - security.authentication
  - security.web-threat
  - mobile.uniapp-device-permissions
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 上传、扫码、定位、权限与失败路径

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《网络、认证、存储与多环境配置》](ch.uniapp.network-auth-storage.md)：上传和定位上报同时涉及 HTTP、认证和敏感数据边界。
- [《平台 API、条件编译与能力检测》](ch.uniapp.platform-conditional.md)：设备 API 和权限模型存在平台差异，必须先有适配与降级机制。
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。配套代码通过可注入设备端口、权限夹具和假上传服务器验证状态矩阵，不会读取真实相机、相册、定位、系统设置或微信小程序授权，也不会上传真实文件。真机权限提示、平台隐私声明、临时路径、上传域名、TLS、后台定位和审核规则仍需目标版本实测。

设备能力最容易产生“开发工具能用，真机不能用”的错觉。原因不是一个 API 难调用，而是一次用户操作横跨了能力存在、系统权限、宿主授权、用户取消、临时文件、网络上传、服务端校验和业务提交。任何一步都可能失败，而且前一步成功不能推出后一步成功。本章用扫码填单、图片上传和可选定位建立一套确定合同。

## 1. 完成定义、入口与非目标

完成本章后，你应能：

1. 把扫码、图片选择、上传和定位封装成可替换端口；
2. 区分能力不可用、首次询问、已允许、拒绝、需要设置恢复、取消和调用失败；
3. 解释权限弹窗为何不是业务同意，也不是服务端授权；
4. 映射 `uni.scanCode` 的成功、取消和失败，不把取消当系统错误；
5. 处理图片临时路径、大小/类型校验、上传进度、取消与服务端响应；
6. 区分附件上传成功和工单提交成功，处理部分成功；
7. 把定位设为最小化、可选、带用途说明和坐标语义的数据；
8. 用权限状态矩阵、设备 Mock 和上传故障注入保存证据。

配套入口：

- [设备能力状态机示例](../../../examples/encyclopedia/ch.uniapp.device-capabilities/README.md)
- [拒绝循环、空数据和部分提交实验](../../../labs/encyclopedia/ch.uniapp.device-capabilities/README.md)
- [公开独立练习](../../../exercises/encyclopedia/ch.uniapp.device-capabilities/README.md)

本章不实现持续后台定位、不选择真实地图供应商、不保存生物识别数据、不绕过平台隐私声明、不把客户端 MIME/坐标校验当作服务端安全边界，也不证明某个应用已经通过微信审核。

## 2. 一次“扫码报修”真正经过哪些状态

```text
用户点击扫码
  ↓
能力是否存在？──否──→ UNSUPPORTED → 手工输入
  │是
  ↓
是否需要权限/声明？──未决──→ 解释用途 → REQUESTING
  │
  ├─允许→ INVOKING_DEVICE
  ├─拒绝→ DENIED → 保留页面，可手工输入
  └─需设置→ SETTINGS_REQUIRED → 用户主动打开设置
                    ↓
设备调用：成功 / 取消 / 识别失败
                    ↓
解析扫码内容并做业务格式校验
                    ↓
填入设备编号，仍由服务端确认设备和租户权限
```

这张图里没有 `undefined` 状态。页面加载时必须有确定初态，例如 `idle`；查询权限时是 `checking`；设备 API 调用中是 `invoking`。如果用三个互不约束的布尔值 `loading/denied/error`，就可能同时出现“正在加载且已拒绝”。判别联合或枚举状态能排除非法组合。

## 3. 建模权限，而不是猜错误字符串

跨平台权限词汇不完全相同，先建立领域层状态：

```ts
type PermissionState =
  | { kind: 'not-required' }
  | { kind: 'unknown' }
  | { kind: 'requestable' }
  | { kind: 'requesting' }
  | { kind: 'granted' }
  | { kind: 'denied'; canAskAgain: true }
  | { kind: 'settings-required'; canAskAgain: false }
  | { kind: 'unavailable'; reason: string }
```

“永久拒绝”不是所有平台都使用同一字段或同一术语。领域层的 `settings-required` 表达的是：应用内再次弹询问已经不能恢复，用户必须主动进入系统/宿主设置，或者该能力根本无法恢复。适配器根据目标平台当前官方合同映射，页面不依赖某句本地化错误文本。

### 3.1 初次请求需要用户动作

不要在页面 `onLoad` 里同时请求相机、相册和位置。用户尚未表达意图，连续弹窗会降低信任，也可能违反平台体验/审核规则。更稳妥的顺序：

1. 页面说明能力用途与可选性；
2. 用户点击明确按钮；
3. 查询当前状态；
4. 若可请求，发起与当前动作直接相关的一个权限；
5. 按结果继续、降级或展示设置恢复。

这叫“情境式请求”。解释页不是法律同意的替代品，系统弹窗也不是收集敏感数据的无限授权。

### 3.2 拒绝后不能循环弹窗

错误做法是每次页面显示都发现“没有权限”，于是再次调用授权 API。结果可能是反复失败、反复提示或诱导授权。正确做法是保存本次流程的确定状态：拒绝后显示替代路径；只有用户再次主动触发并且平台仍允许询问时才请求。若必须去设置，按钮文案应明确“前往设置”，返回页面后重新查询，而不是假设已经允许。

### 3.3 `mounted`、页面存活与权限无关

Vue/uni-app 页面是否仍挂载只能决定能否继续更新当前 UI，不能授予权限、不能取消系统弹窗，也不能自动终止上传。设备任务和网络任务需要各自的取消/忽略旧结果机制。页面卸载后若回调到达，使用操作 id 或 active flag 丢弃旧结果；对支持 `abort` 的上传任务，还应主动中止。

## 4. 设备 API 统一结果

扫码、选择图片、定位虽然返回内容不同，却可共享外层结果：

```ts
type DeviceResult<T> =
  | { kind: 'ok'; value: T }
  | { kind: 'cancelled' }
  | { kind: 'denied'; recovery: 'retry' | 'settings' }
  | { kind: 'unsupported'; fallback: string }
  | { kind: 'failed'; code: string; retryable: boolean }
```

这个类型强迫调用方处理五类结果。它故意没有 `{ kind: 'ok', value: null }` 来表示拒绝，因为那会把“用户拒绝定位”误解为“经纬度为空但业务成功”。错误诊断中的 code 是内部稳定枚举，例如 `DEVICE_BUSY`、`UPLOAD_TIMEOUT`，不可把完整宿主错误、文件路径、token 或坐标写进遥测。

## 5. 扫码：成功回调也要验证内容

uni-app 官方文档说明 `uni.scanCode` 调起扫码界面；不同平台支持情况和参数不同，H5 并非统一支持目标；用户从扫码界面返回等情况会进入失败回调。适配器必须先判断能力，再把取消与真正失败分开。

```ts
type ScannedDevice = { deviceCode: string }

function parseDeviceCode(raw: string): ScannedDevice {
  const normalized = raw.trim().toUpperCase()
  if (!/^DEV-[A-Z0-9]{6,20}$/.test(normalized)) {
    throw new Error('INVALID_DEVICE_CODE')
  }
  return { deviceCode: normalized }
}
```

扫描得到字符串并不代表设备存在，更不代表当前用户有权创建该设备的工单。客户端只做格式和长度限制；服务端根据租户、设备状态和成员权限解析。不要直接把任意二维码当 URL 跳转，尤其不能允许 `javascript:`、外部 scheme 或未授权内部路径。

### 5.1 手工输入是正式降级

扫码不可用、用户取消或摄像头故障时，页面应允许手工输入设备编号，并复用相同的 `parseDeviceCode` 和服务端验证。手工输入不是“低级备用”，而是可访问性、无摄像头环境和现场损坏二维码的可靠路径。

## 6. 图片选择：临时文件不是永久附件

官方图片 API 文档说明，选择得到的本地路径通常具有临时生命周期；需要跨启动使用时要遵循平台的持久文件机制。对报修流程，最安全的首期做法是把临时文件只当作本次上传输入，不把路径写进长期业务记录。

选择后立即建立本地描述：

```ts
type LocalAttachment = {
  localId: string
  tempPath: string
  declaredSize: number
  declaredType: string | null
  state: 'selected' | 'uploading' | 'uploaded' | 'failed' | 'cancelled'
}
```

`declaredSize` 和 `declaredType` 来自客户端，只用于尽早反馈，不能作为安全事实。服务端必须重新检测真实字节、大小、类型、恶意内容和解码风险，并生成自己的 attachment id。文件名不可直接成为存储路径。

### 6.1 选择与上传分开

用户选择成功不代表上传成功。保留两个动作有助于明确状态：

```text
selected(tempPath)
  ↓ 用户确认提交
uploading(progress, operationId)
  ├─ uploaded(serverAttachmentId)
  ├─ failed(code, retryable)
  └─ cancelled
```

页面预览可使用临时路径，但业务提交只能引用服务端签发的 attachment id。若页面恢复时临时文件已失效，应提示重新选择，而不是无限重试旧路径。

## 7. `uni.uploadFile`：传输成功不等于附件可用

官方文档说明 `uni.uploadFile` 使用 `multipart/form-data` 向开发者服务器上传本地资源；小程序网络 API 需要相应域名配置；返回中有 HTTP `statusCode` 和字符串数据；在提供回调的调用形式中可获得 UploadTask，并可监听进度或 `abort`。平台对多文件与状态码类型存在差异，因此跨端实现应归一化。

上传流水线至少分五层：

1. 客户端选择与预校验；
2. 宿主/域名/TLS/网络传输；
3. HTTP 状态与响应体解析；
4. 服务端文件安全校验和附件记录；
5. 工单创建/更新引用附件。

```ts
type UploadedAttachment = {
  attachmentId: string
  checksum: string
}

interface UploadPort {
  upload(
    file: LocalAttachment,
    context: { operationId: string; workOrderDraftId: string }
  ): {
    result: Promise<DeviceResult<UploadedAttachment>>
    cancel(): void
    onProgress(listener: (percent: number) => void): () => void
  }
}
```

`operationId` 用来拒绝旧回调，`workOrderDraftId` 让服务端能把临时附件绑定到明确草稿/主体。进度仅是体验信息，不应驱动业务成功；进度到 100% 也可能仍在等待服务端校验。

### 7.1 状态码和响应必须归一化

不同宿主可能把状态码暴露为数字或字符串。适配器先转成受控整数，再按 2xx/4xx/5xx 和运行时 schema 分类。`success` 回调不代表 2xx，更不代表 JSON 可用。响应体可能是字符串，需要安全解析、大小限制和 schema 验证。

### 7.2 上传取消的边界

`abort` 请求客户端终止任务，但不能证明服务器没有收到部分或全部字节。服务端应把未绑定附件视作临时资源并按 TTL 清理；若上传完成但 UI 丢失结果，可通过 operation id 查询或安全重试。不能因为用户关闭页面就假设服务端没有对象。

## 8. 部分成功：上传完成但工单提交失败

这是最常被遗漏的失败路径：

```text
图片上传成功 → attachmentId=A-123
工单 POST 失败/超时/409
```

如果客户端直接显示“提交失败，请重新选择图片”，会重复上传；如果假装工单成功，会产生孤儿附件或错误确认。可选策略：

- **草稿绑定**：先创建/获得服务端草稿 id，附件始终绑定草稿；提交失败可重试；
- **上传会话**：服务端签发 upload session，工单提交原子地消费附件；
- **孤儿清理**：未被业务记录引用的附件按 TTL 删除；
- **查询确认**：超时时用幂等键查询最终工单结果，而不是盲目重复 POST。

FactoryCare 首期推荐“在线创建草稿上下文 + 幂等提交 + 服务端清理”。具体 API 合同由后续集成章定义。本章夹具只证明状态机不会把附件成功误报为工单成功。

## 9. 定位：可选、最小、带坐标语义

官方 `uni.getLocation` 文档说明返回经纬度、精度等字段，并区分 `wgs84`、`gcj02` 等类型；平台、地图供应商、HTTPS、SDK/key、系统位置服务和权限都会影响结果。地图组件与定位结果还可能要求明确坐标系。不能只存两个浮点数而丢掉来源和语义。

```ts
type CapturedLocation = {
  latitude: number
  longitude: number
  coordinateSystem: 'wgs84' | 'gcj02'
  accuracyMeters: number | null
  capturedAt: string
  source: 'device'
}
```

边界校验至少包括纬度 `[-90, 90]`、经度 `[-180, 180]`、有限数值、合理精度和捕获时间。位置不能从日志、错误上报或分析事件中泄露。服务端仍要判断字段是否允许、是否过期、是否与业务目的相符。

### 9.1 位置是敏感数据，不是默认必填

报修的核心是设备和问题描述。若位置只用于帮助到场，应清楚解释用途，允许跳过，并仅在用户主动选择时获取一次。不要后台持续采集，不要因定位拒绝阻止手工填写设备；不要为了“以后可能有用”保存高精度轨迹。

### 9.2 授权和业务同意是两层

系统允许位置只说明操作系统/宿主当前允许 API；产品仍要满足隐私告知、目的限制、最小化、保留期和删除规则。反过来，用户在页面勾选“附加位置”也不能绕过系统权限。两层都满足才调用。

## 10. 权限状态机的事件与转移

建议把副作用与纯转移分开：

```ts
type PermissionEvent =
  | { type: 'CHECK'; capabilityAvailable: boolean; current: 'granted' | 'prompt' | 'blocked' }
  | { type: 'REQUEST' }
  | { type: 'GRANTED' }
  | { type: 'DENIED'; canAskAgain: boolean }
  | { type: 'RETURNED_FROM_SETTINGS'; current: 'granted' | 'blocked' }
```

纯 reducer 接收旧状态和事件，返回新状态；适配器在外层执行 `getSetting/authorize/openSetting` 等平台操作。这样可以验证：

- 首次 `prompt` 进入 `requestable`；
- 用户点击后才进入 `requesting`；
- 拒绝且可重问进入 `denied`，不会自动再次请求；
- 不可重问进入 `settings-required`；
- 从设置返回必须重新查询；
- 能力不存在直接进入 `unavailable`。

不能用定时器猜用户是否已在设置中授权。系统设置可能被取消、应用可能恢复或重新创建，唯一可信证据是返回后重新读取当前状态。

## 11. 三类端口及依赖所有权

```ts
interface ScanPort {
  scanDevice(): Promise<DeviceResult<{ raw: string }>>
}

interface LocationPort {
  captureOnce(): Promise<DeviceResult<CapturedLocation>>
}

interface MediaPort {
  chooseRepairImages(limit: number): Promise<DeviceResult<LocalAttachment[]>>
}
```

页面组合流程，端口拥有平台 API 映射。上传端口另行负责网络任务。测试注入脚本化假对象：第一次返回拒绝、第二次不应被自动调用；扫码返回取消；定位能力不存在；上传 100% 后 HTTP 422；附件成功而工单提交超时。若所有逻辑都写在 Vue 方法里，就只能靠手点覆盖这些组合。

## 12. UI 合同：每个状态都要能看见

| 状态 | 推荐界面 | 禁止做法 |
|---|---|---|
| `idle` | 展示用途和触发按钮 | 页面加载自动弹三项权限 |
| `requesting` | 禁用重复点击、说明等待 | 连续发起相同请求 |
| `denied` | 显示替代输入、可再次主动尝试 | 把空值当成功 |
| `settings-required` | 明确“前往设置”及替代路径 | 无限循环授权弹窗 |
| `unsupported` | 手工输入/不附位置 | 隐藏全部报修功能 |
| `cancelled` | 保留已填数据 | 显示“系统错误”并清空表单 |
| `uploading` | 文件级进度和取消 | 把 100% 当业务完成 |
| `failed` | 文件级原因和安全重试 | 重传所有已成功附件 |
| `uploaded` | 显示服务端附件状态 | 仅保存临时路径 |

可访问性同样重要：错误不能只靠颜色；按钮有明确文本；状态变化可被辅助技术感知；扫码始终有键盘输入替代；定位不是完成核心任务的唯一入口。

## 13. 失败分类与首个可信证据

### 13.1 “拒绝后得到空数据”

若页面把 `fail` 转成 `resolve(null)`，后续可能提交 `location: null` 并显示成功。首个证据是设备适配器的原始分类与状态转移，而不是后端数据库。修复为判别联合后，拒绝必须进入 `denied`，页面选择跳过或引导恢复。

### 13.2 “每次进入页面都请求权限”

首个证据是页面生命周期日志与权限端口调用次数。若 `onShow` 每次都执行 request，说明查询状态和用户触发没有分开。修复后 `onShow` 最多重新查询，从不自动弹窗；测试断言拒绝场景 request 调用次数保持为一。

### 13.3 “上传成功，提交失败”

首个证据不是上传进度条，而是服务端 attachment id、工单请求的 idempotency key、HTTP/业务响应和查询结果。修复应保留已上传 id，安全重试工单提交或恢复草稿，且不重复上传同一文件。

### 13.4 “开发工具可以，真机不行”

依次确认真实目标产物、宿主/基础库、隐私声明与权限、上传域名/TLS、设备系统设置、API/参数兼容性、真机网络和服务端日志。不要第一步就清缓存重装；那会破坏证据。

## 14. 测试矩阵

### 14.1 权限矩阵

每项能力至少覆盖：

- 能力不存在；
- 第一次可请求并允许；
- 第一次拒绝且可再次主动询问；
- 已阻止，需要设置恢复；
- 用户取消；
- 设置返回后仍拒绝；
- 设置返回后已允许；
- 页面卸载后旧结果到达。

### 14.2 上传矩阵

- 允许的图片、大小边界；
- 超大文件、伪造 MIME、损坏图片；
- 域名/TLS/超时等传输失败；
- HTTP 401、413、415、422、500；
- 2xx 但响应不是合法 schema；
- 用户取消；
- 旧操作回调晚到；
- 附件成功、工单失败；
- 工单超时后查询为已成功；
- 重试不重复产生附件/工单。

### 14.3 真机矩阵

离线 Mock 无法替代至少一台目标真机。保存应用版本、构建 commit、宿主/基础库、设备/OS、权限初态、操作步骤、预期/实际、脱敏日志和截图/录屏。为了测试首次询问，需要可重复清理授权状态的流程，但清理动作也要记录。

## 15. 安全与隐私检查

1. token 不进入上传 URL、文件名或日志；
2. 服务端重新认证、租户隔离和授权；
3. 文件按真实内容、大小和解码结果验证；
4. 原始文件名不作为对象存储键；
5. 下载使用受控授权，不公开永久 URL；
6. 位置只在明确用途下收集，允许跳过；
7. 坐标、临时路径、扫码原文和错误体默认不进遥测；
8. 临时/孤儿附件有清理策略；
9. 扫码结果当不可信输入，不直接导航或执行；
10. 平台隐私声明、权限文案和实际行为保持一致。

## 16. 实验：三种故障的红—绿证据

### 16.1 把拒绝当空数据

故障夹具返回 `denied`，错误实现却产生 `{ kind: 'ok', value: null }`。验证器应报告 `DENIAL_COLLAPSED_TO_EMPTY`。修复后 UI 呈现拒绝与手工路径，不发起定位上报。

### 16.2 重复请求权限

夹具记录 request 次数。首次拒绝后模拟页面再次显示，错误实现计数变为 2；正确实现只做 check，request 仍为 1。证据是调用记录，不是肉眼“好像只弹了一次”。

### 16.3 部分上传提交

假服务器先返回 attachment id，再让工单提交失败。错误实现清空附件或显示完成；正确实现进入 `commit-failed`，保留 attachment id 和同一 idempotency key，重试只提交工单。

## 17. 120 秒复述模板

设备能力不是一个布尔值。先检测当前平台/版本是否有能力，再由用户动作触发权限请求。权限状态至少区分未知、可请求、请求中、已允许、拒绝、需要设置和不可用；拒绝后不能自动循环请求。扫码、定位和文件选择都返回统一判别结果，取消不是错误，拒绝不是空数据。临时文件只用于本次上传，上传成功还要经过 HTTP、服务端文件校验和工单提交；附件成功不能冒充工单成功。定位是可选敏感数据，要记录坐标系、精度和时间并最小化收集。验证同时需要权限矩阵、设备 Mock、上传故障注入和真机证据。

越界反例：“页面打开就请求位置和相机，任何 fail 都返回 null；上传进度 100% 后直接提示报修成功。”它会循环权限、吞掉拒绝、混淆传输与业务提交，并产生错误确认。

## 18. 速查表

| 场景 | 领域结果/状态 | 恢复路径 | 第一证据 |
|---|---|---|---|
| 宿主无扫码 | `unsupported` | 手工输入 | 能力快照 |
| 用户返回扫码页 | `cancelled` | 保留表单、可重试 | 设备回调映射 |
| 首次位置拒绝 | `denied` | 跳过或主动再试 | 权限状态转移 |
| 不可再询问 | `settings-required` | 前往设置后重查 | 设置前后快照 |
| 临时文件失效 | `failed/non-retryable` | 重新选择 | 文件访问错误 |
| 上传超时 | `failed/retryable` | 查状态/安全重试 | operation id + 服务端日志 |
| HTTP 413 | 文件被拒 | 压缩/重选 | statusCode + 问题详情 |
| 附件成功、工单失败 | `commit-failed` | 保留 id 幂等重试 | 两阶段服务端结果 |
| 旧回调晚到 | ignored | 无 UI 覆盖 | operation id 不匹配 |

## 19. 事实来源与未验证范围

本章易变事实于 2026-07-24 对照下列 uni-app 官方页面。它们明确描述了 multipart 上传、UploadTask、进度/取消、扫码平台差异与取消回调、定位坐标/精度/平台配置、临时图片和授权表面。兼容表、权限 scope、隐私声明和宿主行为会变化，实施时必须重新核对目标版本。

直接来源：

- DCloud，[`uni.uploadFile`](https://uniapp.dcloud.net.cn/api/request/network-file)：multipart 上传、HTTP 状态、UploadTask、进度与取消。
- DCloud，[`uni.scanCode`](https://uniapp.dcloud.net.cn/api/system/barcode)：平台兼容、成功结果以及识别失败/用户取消进入失败回调的合同。
- DCloud，[`uni.getLocation`](https://uniapp.dcloud.net.cn/api/location/location)：坐标、精度、坐标系、平台配置与权限差异。
- DCloud，[图片 API](https://uniapp.dcloud.net.cn/api/media/image)：选择图片结果与临时文件生命周期。
- DCloud，[`uni.authorize`](https://uniapp.dcloud.net.cn/api/other/authorize.html)：小程序 scope、拒绝后的失败回调以及与设置 API 的协作。

当前未验证：真实微信授权与设置页、H5 浏览器权限、Android/iOS 系统权限、相机/相册/扫码硬件、地图 key 与坐标转换、上传域名/TLS、真实文件安全扫描、附件草稿协议、后台清理和 FactoryCare 真服务。配套绿灯仅是离线合同证据。
