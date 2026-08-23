# uni-app：运行模型、页面、组件与网络

## 1. uni-app 是“同一份源码编译到不同宿主”的方案

```text
Vue/uni-app 源码
  → uni-app 编译工具
  ├── 微信小程序产物 → 微信基础库运行
  ├── App 产物       → 原生容器/WebView/平台能力
  └── H5 产物        → 浏览器运行
```

源码相似不代表每个平台运行机制完全相同。API、组件、权限、生命周期、网络限制和审核规则都可能不同。

学习时始终问三件事：代码何时被编译、最终由谁运行、该宿主实际支持什么。

## 2. 小程序不是普通浏览器页面

小程序宿主通常把逻辑执行与视图渲染分开，并提供自己的组件、页面栈和平台 API。不能默认存在完整 `window`、`document` 或任意 DOM 操作。

```text
逻辑层：JavaScript 状态和业务逻辑
  ↕ 数据/事件桥接
视图层：宿主组件渲染
```

跨层传递大对象和高频更新有成本。依赖浏览器 DOM 的 Vue 插件在 H5 可用，也可能在小程序目标失败。

## 3. 宿主版本、基础库版本和源码依赖版本不同

需要分别记录：

- uni-app 编译器/CLI 与依赖版本；
- Vue、Vite 和插件版本；
- 目标小程序基础库版本；
- 微信/支付宝等客户端版本；
- 开发者工具版本；
- App 原生 SDK/系统版本。

“我微信是最新版”不能证明某项基础库 API 可用；开发工具模拟通过也不能证明真机系统权限正常。

## 4. 冷启动、热启动和前后台影响生命周期

```text
冷启动：进程/应用从未运行状态创建
热启动：已有进程从后台恢复
页面显示：当前页面重新可见
```

不要把每次 `onShow` 都当首次初始化，也不要只在首次 `onLoad` 拉取永远不会变化的数据。

认证恢复、草稿恢复和数据刷新应按生命周期语义设计，并防止多次进入重复注册监听器。

## 5. 项目结构同时包含应用、页面和平台配置

常见职责：

```text
main.ts        创建 Vue/uni-app 应用
App.vue        应用级生命周期和全局样式
pages.json     页面清单、导航与页面样式
manifest.json  应用标识、能力和平台构建配置
pages/         页面 SFC
components/    可复用组件
services/      API 和平台适配
stores/        明确的共享客户端状态
```

具体目录会随 CLI 模板和版本变化。关键是每项配置有一个权威入口，不能同时在多个文件维护互相冲突的页面或环境清单。

## 6. 页面文件只有注册后才成为可导航页面

创建 `pages/report/index.vue` 不一定自动注册。页面需要在 `pages.json` 等当前工具链清单中声明。

```text
源码文件存在
  ≠ 编译器已包含
  ≠ 宿主已注册
  ≠ 路由可以到达
```

白屏时先看构建产物和页面配置，不要直接在模板中随机加代码。

## 7. uni-app 路由不是 Vue Router

常见页面动作概念：

- navigateTo：打开普通新页面，入栈；
- redirectTo：替换当前普通页面；
- navigateBack：返回已有页面；
- switchTab：切换 tab 页面；
- reLaunch：清理并重建页面栈。

它们对页面栈和生命周期影响不同。不能把浏览器 history 或 Vue Router guard 的经验原样套用。

具体 API 限制、栈深和 tab 规则需按目标平台最新文档核对。

## 8. 路由参数始终是外部字符串输入

```ts
onLoad(query => {
  const deviceCode = String(query?.deviceCode ?? '')
  // 格式校验后再使用
})
```

参数可被用户、二维码或其他页面构造。不能把其中 tenantId、role 或设备主键当可信权限事实。

敏感对象仍由后端根据认证主体和业务码解析；页面参数只用于表达导航意图。

## 9. App 生命周期不适合成为全局垃圾桶

App 级入口可做：

- 初始化不含用户秘密的配置；
- 建立日志/监控基础；
- 恢复认证状态机；
- 处理前后台切换；
- 注册确实全局的宿主事件。

不应把所有页面数据、DOM 假设和无限监听器放在 App 实例。全局状态要有所有者、清理和租户/用户隔离。

## 10. 页面生命周期要区分创建、可见、就绪和卸载

常见概念：

```text
onLoad      页面实例建立，接收参数
onShow      页面每次变为可见
onReady     首次渲染就绪
onHide      被其他页面覆盖/进后台
onUnload    页面从栈中移除
```

网络刷新可在 onShow，但要做缓存和并发控制；只需一次的参数解析在 onLoad；资源在 onUnload 清理。不同平台具体顺序和组合要以真机证据为准。

## 11. 模板语法像 Vue，但渲染的是跨端组件

```vue
<template>
  <view class="page">
    <text>{{ title }}</text>
    <button @tap="submit">提交</button>
  </view>
</template>
```

`view`、`text`、`button` 等是跨端/宿主组件，不是简单换名字的 HTML。默认样式、事件 payload、可访问能力和嵌套规则可能不同。

不要因为 H5 能渲染任意 HTML 标签就认为小程序端同样支持。

## 12. 绑定、条件和列表仍遵循 Vue 数据流

```vue
<view v-if="status === 'loading'">加载中</view>
<report-row
  v-for="report in reports"
  :key="report.id"
  :report="report"
/>
```

使用稳定 key；派生列表放 computed；不要在模板执行昂贵转换。跨逻辑/视图层传输的数据应小而可序列化，避免把复杂类实例和函数放进状态。

## 13. 事件字段按组件合同读取

```ts
function handleInput(event: UniInputEvent) {
  title.value = event.detail.value
}
```

不要凭 Web 经验猜 `event.target.value`，也不要把不同组件的 detail 结构当一样。点击、触摸、输入、picker 等各有目标平台合同。

事件成功回调也不代表业务值合法，仍需解析、规范化和校验。

## 14. Props 向下，事件向上

```vue
<device-picker
  :selected-id="form.deviceId"
  @select="form.deviceId = $event"
/>
```

子组件不直接修改父 prop；需要改变时报告稳定业务事件。组件 `v-model` 也是值 prop 和更新事件组成，具体声明方式与 Vue/uni-app 版本相关。

跨端组件接口应只暴露可序列化数据，避免依赖 DOM Element 或浏览器 Event 类型。

## 15. 表单的 UI 值、领域值和请求值应分开

picker 返回索引或字符串，输入框返回文本；业务可能需要 DeviceId、整数或枚举。

```text
UI value：'3' / picker index
  → 解析与验证
Domain draft：affectedUsers=3
  → 映射请求
API input：{ affectedUsers: 3 }
```

不要把字符串 `'0'` 用 truthy 判断，也不要把显示 label 当服务端枚举值。

## 16. 表单状态不只是一组字段

```text
idle
editing
validating
submitting
success
error(field/global/unknown-result)
```

提交中防重复、失败保留草稿、字段错误定位、成功后明确跳转/重置。若请求超时，服务端可能已创建，界面不能直接允许无幂等地再次提交。

## 17. rpx 是适配单位，不是物理像素保证

rpx 根据设计宽度映射目标屏幕，适合横向尺寸比例。它不能保证所有设备视觉完全一致，也不应让文字、触控目标和安全区域只靠固定 rpx。

需要考虑：

- 不同屏幕长宽和像素密度；
- 系统字体放大；
- 刘海/安全区域；
- 横屏；
- 不同宿主默认组件样式。

真机和无障碍设置下验证比“设计稿 750 宽”更重要。

## 18. 样式作用域和选择器受目标平台限制

`scoped` 能减少组件样式泄漏，但编译后的实现和小程序组件隔离有关。复杂后代、伪元素、动态 class 和全局主题在不同端可能有差异。

优先使用简单 class、明确 token 和跨端支持属性。遇到差异先查目标产物与平台支持，不用层层 `!important`。

## 19. 网络请求经过平台和服务端两道边界

```text
页面
  → API client
  → uni.request
  → 平台域名/TLS/网络策略
  → 网关/Spring API
  → 认证、授权、业务
```

小程序平台可能要求配置合法域名和 HTTPS。白名单只表示宿主允许发请求，不表示服务端允许当前用户访问。

## 20. uni.request 的成功回调不等于 HTTP 业务成功

传输成功后仍可能是 400、401、403、409、500：

```ts
uni.request({
  url,
  success(response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // 运行时校验 response.data
    } else {
      // 映射稳定 API 错误
    }
  },
  fail(error) {
    // DNS、TLS、断网、取消等传输失败
  },
})
```

项目可封装 Promise API，但必须保留状态码、错误类型和取消能力。

## 21. 响应 data 仍是不可信输入

TypeScript 类型不会检查运行时响应。跨端 API 层应验证：

- 对象/数组结构；
- 必填字段；
- enum 状态；
- 数字范围；
- 时间格式；
- null/缺失；
- schema version。

错误响应也要有稳定 code，不能靠中文 message 判断登录过期或字段位置。

## 22. 认证要按客户端类型定义合同

可能模式：

- 小程序平台登录 code → 后端换取/建立 FactoryCare Session；
- 后端发短期 Access Token + 安全刷新机制；
- App 使用系统安全存储保护刷新凭据；
- H5 使用 HttpOnly Cookie/BFF。

同一 uni-app 源码不代表各端能用同样凭据存储。不要把小程序 code 当用户身份直接信任，后端必须向平台验证并绑定内部账号。

## 23. 认证恢复要成为单次协调状态机

```text
unknown
  → restoring
  ├── authenticated
  ├── anonymous
  └── temporary-error
```

多个请求同时收到 401 时，不应各自刷新 Token。使用一个共享 refresh Promise，成功后有限重放，失败统一清理并回登录。

401 与断网不同；断网时删除有效登录状态会破坏离线体验。

## 24. 本地存储不是安全保险箱

`uni.setStorage` 等适合：

- 非敏感偏好；
- 版本化草稿；
- 可丢弃缓存；
- 离线队列的必要最小数据。

不适合明文保存密码、长期 Token、完整敏感工单和平台秘密。不同目标端存储保护不同，App 高敏凭据应使用受审查的系统安全存储能力。

## 25. 持久化值需要版本信封

```json
{
  "schemaVersion": 2,
  "userId": "user-17",
  "tenantId": "tenant-A",
  "savedAt": "2026-07-29T10:00:00Z",
  "data": {}
}
```

读取时检查版本、所属用户/租户、过期时间和字段结构。解析失败应清理/迁移并安全回退，不能让损坏缓存导致永久白屏。

登出和切租户时清理对应命名空间。

## 26. 多环境配置是允许列表，不是用户可编辑服务器

```text
dev  → 开发 API
test → 测试 API
prod → 生产 API
```

构建时明确选择，并在产物中记录环境标识。不要从 query/storage 接收任意 base URL，否则可能把认证凭据发送给攻击服务器。

编译进客户端的环境变量都可被提取，不是秘密。密钥留在服务端。

## 27. API 客户端分层减少每页重复处理

```text
transport：uni.request、timeout、取消
  → protocol：status、JSON、错误结构
  → auth：凭据附加、单次恢复
  → domain API：createReport、loadWorkOrder
  → page/composable：loading、错误和呈现
```

网络层不应知道 Toast 文案；页面不应到处复制 Authorization header 和状态码 switch。

## 28. 取消只说明客户端不再等待

离开页面或发起新搜索时取消 RequestTask，避免旧结果写回。但 POST 已到服务器后，取消不能撤回事务。

写操作需要幂等键、最终状态查询和明确未知结果。读取请求还应用 sequence/key 防止旧回调覆盖新页面。

## 29. 扫码报修的首段数据流

```text
用户点击扫码
  → 宿主返回原始码
  → 客户端校验格式
  → 后端解析业务码并检查租户/设备
  → 返回最小设备摘要
  → 用户填写故障表单
  → 提交带幂等键的创建请求
```

二维码只是输入载体，不应直接包含可长期信任的内部主键、角色或权限。

扫码失败/拒绝时，手工输入设备码是正式降级路径，不是临时补丁。

## 30. 白屏诊断按源码到宿主管线进行

1. Node、包管理器、CLI 是否正确；
2. lockfile 安装是否成功；
3. 页面/manifest 配置是否可解析；
4. 目标构建是否成功；
5. 产物是否生成到预期目录；
6. 开发工具加载的是不是新产物；
7. 页面路径和栈是否正确；
8. 宿主运行日志第一条项目错误；
9. 真机能力/域名/权限是否不同。

不要从最后的“白屏”倒猜是 CSS。

## 31. 这篇的整体地图

```text
uni-app 源码
  → 编译到具体目标产物
  → 小程序/App/H5 宿主运行
  → 页面清单 + 页面栈管理导航
  → Vue 数据流驱动跨端组件
  → UI 字符串解析成领域/请求值
  → API 客户端经过平台网络和后端安全边界
  → 认证恢复、存储和环境各有明确合同
```

必须掌握：小程序不是普通 DOM；页面文件需注册；uni-app 路由不是 Vue Router；事件 payload 看组件合同；`uni.request success` 不等于 2xx；客户端配置不是秘密；本地存储不是凭据保险箱；扫码值不等于可信设备身份。

各平台组件差异、生命周期细节和 API 参数属于“需要时查询”，真正开发时同时查 uni-app 与目标宿主官方文档，并用真机复核。
