# 第 23 周：uni-app Vue 3 小程序基础、平台约束与扫码报修

> 建议投入：16 小时（可在 15—18 小时内调整）

## 1. 本周定位

本周把 Vue 3 能力迁移到 uni-app，但目标不是证明“一套代码完美运行所有平台”，而是交付一个微信小程序方向的 FactoryCare 员工报修端。它只承担扫码、快速报修和进度查询，与 Vue 管理端的调度功能、Flutter 技师端的离线巡检职责不同。

先在微信开发者工具完成主流程，第 24 周再进行真机、上传、权限和发布。H5 只能作为快速预览，不能替代小程序运行时验证。

## 2. 前置条件

- 第 19—22 周 Vue3、TypeScript、状态边界、测试和错误恢复已通过。
- FactoryCare 后端已有租户、用户、设备、工单、幂等和权限接口。
- 已准备微信小程序测试号或开发 AppID；若暂时没有，先使用工具测试环境，但必须记录第 24 周真机阻塞。
- 创建项目时选择当前稳定 uni-app Vue3 + Vite 组合并锁定依赖，不使用 alpha/RC。

## 3. 学习目标

- 能解释 uni-app 编译到小程序的模型，以及它与普通浏览器 Vue SPA 的运行时差异。
- 能使用 `pages.json`、`manifest.json`、页面/应用生命周期和 `uni.*` API。
- 能识别 DOM、网络域名、包体、样式、路由、组件和权限的平台约束。
- 能实现小程序登录码交换与 FactoryCare 内部用户/租户映射，不信任客户端身份字段。
- 能使用 `uni.scanCode` 安全解析设备二维码并由后端验证权限与设备状态。
- 能完成“扫码—确认设备—填写报修—幂等提交—查看进度”的垂直闭环。

## 4. 完整概念清单

### 4.1 项目与运行时

- uni-app Vue3 SFC、Vite 构建、TypeScript 和目标平台编译。
- `pages.json` 页面、导航栏、TabBar、分包；`manifest.json` 应用/平台配置；`uni.scss` 主题变量。
- App、Page、Component 生命周期与 Vue 生命周期的交集和差异。
- 页面栈、`navigateTo/redirectTo/reLaunch/switchTab/navigateBack` 的限制。
- `rpx`、安全区域、状态栏、触摸目标和不同屏幕适配。
- 小程序不是浏览器：不能假定 DOM、`window`、任意 npm 包和浏览器 API 可用。

### 4.2 跨平台与条件编译

- `#ifdef MP-WEIXIN`、平台目录和条件编译的使用边界。
- 优先使用统一 API，平台差异隔离在 adapter/composable，而不是散落页面。
- `uni.canIUse`、基础库版本、平台特有组件和降级提示。
- H5、小程序、App 的 Cookie、网络、存储、授权和组件行为不同。
- 本项目只验收微信小程序；不宣称未经测试的平台兼容。

### 4.3 网络、状态与错误

- `uni.request` 与浏览器 fetch 差异；HTTPS 合法域名、超时、证书和开发工具“不校验域名”陷阱。
- 统一请求层处理关联 ID、移动会话、业务错误码、401、429、网络离线和超时。
- 页面局部状态、Pinia 会话状态、URL/Page 参数和服务端状态边界。
- 加载、空、失败、离线和重复提交反馈；不能只在控制台打印错误。
- 小程序包体、分包与资源体积；不要把 Web 管理端组件库搬进小程序。

### 4.4 小程序认证

- `uni.login` 返回短期、单次使用的登录 `code`，它不是用户身份和 Access Token。
- 后端持有平台 Secret，与平台交换外部用户标识；Secret 绝不能进入小程序包。
- 外部身份映射 FactoryCare 内部用户、租户、角色；不存在或停用用户应拒绝。
- 本项目选择服务端存储的短期不透明移动会话 Token，Scope 最小化；不因“流行”强制自制 JWT。
- 客户端存储不可视为可信，所有租户、权限和资源归属仍由后端校验。
- 开发测试 Provider 与真实微信 Provider 使用同一接口；测试身份必须有明显环境隔离，生产构建不得启用。

### 4.5 扫码报修安全

- `uni.scanCode` 的成功、取消、权限拒绝、无法识别和多种码类型。
- 二维码只携带不透明设备标识/签名短链接，不包含数据库结构、租户或敏感数据。
- 客户端解析只是导航提示，后端必须重新校验签名、有效期、租户、设备状态和用户权限。
- 防止替换设备 ID、重复扫码、过期码、跨租户码和恶意 URL。
- 扫码失败允许手工输入设备编码，并经过同样的后端验证。

## 5. 任务分配

| 任务 | 时间 | 结果 |
| --- | ---: | --- |
| uni-app 运行时与配置实验 | 2.5h | 生命周期/平台差异笔记 |
| 请求层与小程序认证边界 | 3h | 可测试登录和错误处理 |
| 扫码与设备确认 | 3h | 安全扫码流程 |
| 报修/进度项目闭环 | 4h | 可运行微信开发者工具版本 |
| 无 AI 训练 | 2h | 独立页面切片 |
| 南昌岗位与简历动作 | 2h | uni-app 技能证据矩阵 |

总计 16.5 小时。若只有 15 小时，减少视觉打磨；不能删除登录码交换、扫码后端校验和幂等提交。

## 6. FactoryCare 项目增量

- 新建 `factorycare-miniapp`，README 明确目标平台、角色、开发命令和未经验证的平台。
- 页面限定为：登录/绑定提示、首页扫码、设备确认、报修表单、我的报修、报修详情。
- 建立小型请求 adapter 和会话 Store；每个模块写明数据来源、映射和认证副作用。
- 后端增加移动登录 Provider 接口：测试环境使用固定受控账号，真实环境交换微信 code；生产配置禁止测试 Provider。
- 后端签发短期不透明移动会话，映射内部用户/租户/权限；复用现有数据权限与审计。
- 使用 `uni.scanCode` 读取设备码；后端 `resolve-asset-code` 校验签名/租户/权限后返回最小设备 DTO。
- 报修表单包含故障分类、描述、紧急程度和联系方式；附件上传留到第 24 周。
- 创建工单使用第 16 周 `Idempotency-Key`，连续点击或网络重试只创建一次。
- 我的报修/详情只显示当前用户可见数据，状态使用和后端一致的稳定映射。
- 编写 `ADR-023-miniapp-boundaries.md`：平台目标、认证、二维码格式、测试 Provider 隔离和跨端非目标。

## 7. AI 协作边界

AI 可以：

- 把已有 Vue Composable 按 uni-app 运行时约束提出迁移方案。
- 生成平台差异、扫码失败和网络错误测试清单。
- 审查页面是否使用浏览器专属 API、二维码是否泄露信息。
- 帮助解释编译错误，但必须在微信开发者工具复验。

AI 不可以：

- 宣称 H5 跑通就等于小程序兼容。
- 把 AppID Secret、真实 Token、用户数据或二维码密钥写进前端代码/提示词。
- 信任客户端传入的 `tenantId/userId/assetId`，或绕过后端数据权限。
- 用大量条件编译复制两套业务逻辑。

AI 生成的跨端 API 必须逐项查官方平台支持表，并在目标小程序环境运行，不能只依赖类型检查。

## 8. 无 AI 训练

关闭 AI 120 分钟，实现“手工输入设备编码报修”的降级路径：

- 设备编码前端做基础格式提示，后端执行真实租户/权限验证。
- 处理不存在、跨租户、停用设备、429 和网络超时。
- 用户修正编码后保留已填写的故障描述。
- 提交复用幂等键，重复点击不能创建两个工单。
- 不使用 DOM/browser API，并在微信开发者工具验证。

## 9. 求职动作

- 采样 10 个南昌 uni-app/小程序/Vue 岗位，记录 Vue3、原生小程序、真机、扫码、上传、支付、上架等真实要求。
- 建立“会用 uni-app”证据矩阵：开发工具运行、平台约束、登录、请求、扫码、幂等、真机/发布（第 24 周补齐）。
- 简历暂写：`使用 uni-app Vue3 实现微信小程序扫码报修，二维码只作导航、后端执行租户/设备校验并以幂等键防重复创建`。
- 本周完成至少 8 次 Vue/uni-app/全栈定向投递，并记录企业是否更重视原生小程序经验或多端数量。

## 10. 本周交付物

- 可在微信开发者工具运行的 `factorycare-miniapp`。
- 移动登录/受控测试 Provider、请求层和会话恢复。
- 扫码/手工输入、设备确认、报修提交、列表和详情闭环。
- `ADR-023-miniapp-boundaries.md` 与平台差异清单。
- 无 AI 降级页面、岗位证据矩阵和更新后的项目描述。

## 11. 验收标准

- 能解释 uni-app 与浏览器 Vue 的运行时、生命周期、路由、网络和存储差异。
- 微信开发者工具冷启动后能登录、扫码/手输、创建工单并查看进度。
- 登录 code 只发往后端，平台 Secret 不在客户端；生产构建无法启用测试 Provider。
- 篡改二维码中的设备标识、tenantId 或 userId 不能越权。
- 连续点击、请求超时重试只创建一个工单。
- 目标平台限制和未经验证平台写进 README，不声称“一次开发全端无差异”。
- 无 AI 120 分钟完成降级路径并能解释每个错误状态。

## 12. 明确不做

- 不同时适配微信、支付宝、抖音小程序和 App。
- 不复制 Vue 管理后台，不引入重型 Web UI 组件库。
- 不把 H5 预览当真机/小程序验收。
- 不在客户端保存平台 Secret、信任身份字段或解析二维码后直接操作设备。
- 不实现附件上传、推送、支付和正式发布；这些属于第 24 周或只学概念。

## 13. 官方资料

- [uni-app 官方文档](https://uniapp.dcloud.net.cn/)
- [uni-app Vue3](https://uniapp.dcloud.net.cn/tutorial/vue3-basics.html)
- [pages.json 页面路由](https://uniapp.dcloud.net.cn/collocation/pages.html)
- [uni-app 条件编译](https://uniapp.dcloud.net.cn/tutorial/platform.html)
- [uni-app 生命周期](https://uniapp.dcloud.net.cn/tutorial/page.html#lifecycle)
- [uni.login](https://uniapp.dcloud.net.cn/api/plugins/login.html)
- [uni.scanCode](https://uniapp.dcloud.net.cn/api/system/barcode.html)
- [微信小程序登录](https://developers.weixin.qq.com/miniprogram/dev/framework/open-ability/login.html)
- [微信小程序网络](https://developers.weixin.qq.com/miniprogram/dev/framework/ability/network.html)
