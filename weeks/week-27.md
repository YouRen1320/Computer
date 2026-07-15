# 第 27 周：Vite、Router、Pinia、服务端状态与 Element Plus 企业后台

> 建议投入：17 小时（可在 15—18 小时内调整）

## 1. 本周定位

本周把第 26 周的 Vue 基础切片升级为可交付的 FactoryCare 企业管理端。重点是工程构建、路由与权限、客户端/服务端状态边界、复杂表单表格和真实后端联调，这些比再背一遍组件 API 更贴近南昌 Java + Vue 全栈岗位。

状态分工采用：**组件局部状态留在组件/Composable；会话与全局 UI 状态放 Pinia；服务端数据由查询缓存层或清晰的请求 Composable 管理。** 本周推荐使用 TanStack Query for Vue 学习失效与缓存语义，但不把它包装成南昌岗位的必备关键词。

## 2. 前置条件

- 第 26 周类型检查、组件/Composable 测试和无 AI 训练通过。
- FactoryCare 后端认证、权限、分页、工单状态命令和错误码稳定。
- 能读懂浏览器 Network、Cookie、CORS/CSRF 和 HTTP 缓存信息。
- 已确定本周只使用 Element Plus 一个后台 UI 库。

## 3. 学习目标

- 能配置 Vite 环境变量、代理、构建、懒加载、静态资源和类型检查流程。
- 能以 Vue Router 实现路由元信息、嵌套路由、懒加载、登录恢复和授权导航。
- 能说明局部状态、Pinia 客户端状态、URL 状态和服务端状态的边界。
- 能实现服务端分页、排序、筛选、缓存、重新获取和写后失效。
- 能使用 Element Plus 完成可维护的复杂表单、表格和权限动作。
- 能处理加载、空、失败、冲突、校验错误、无权限和会话过期。

## 4. 完整概念清单

### 4.1 Vite 工程化

- 开发服务器、原生 ESM、依赖预构建、生产 Rollup 构建。
- `import.meta.env`、`VITE_` 暴露规则、模式与运行时配置边界；前端变量都不是秘密。
- 开发代理只解决本地联调，不等同于生产反向代理和 CORS 策略。
- 路径别名、静态资源、CSS 预处理、按路由动态导入和 chunk 分析。
- `vite build` 不执行完整 TypeScript 类型检查；CI 同时运行 `vue-tsc` 与构建。
- source map、错误监控和敏感源码暴露取舍。

### 4.2 Router 与权限导航

- 嵌套布局、动态参数、Query 作为可分享筛选状态、404 和重定向。
- Route Meta 表达页面所需权限；全局守卫负责登录恢复与导航体验。
- 路由守卫不是后端安全边界，不能替代接口授权。
- 动态路由/静态路由 + 权限过滤的取舍；避免由后端返回任意组件文件路径。
- 导航竞态、重复跳转、登录后返回原页面和会话过期处理。
- 页面组件懒加载与预加载，不把所有页面打进首屏。

### 4.3 Pinia 与服务端状态

- Pinia 保存当前用户、权限、导航偏好等客户端共享状态。
- Store 的 state/getter/action、`storeToRefs`、组合式 Store 和生命周期风险。
- 服务端状态具有缓存、陈旧、去重、重试、分页、失效和后台刷新语义。
- Query Key 必须包含租户可见筛选、分页与排序；写操作成功后精确失效。
- 不把接口响应复制到 Pinia 后长期与服务器保持“双份真相”。
- URL 保存可分享筛选，表单草稿留局部，权限以服务端 `/me` 为源。

### 4.4 Element Plus 复杂业务 UI

- `el-form` Model/Rules、同步/异步校验、动态数组项、提交状态和服务端字段错误映射。
- `el-table` 服务端分页、排序、筛选、固定列、选择、空状态和加载状态。
- 大表格性能、稳定 row key、虚拟化触发条件；先测量再优化。
- Dialog/Drawer 生命周期、关闭确认、表单重置和重复提交。
- 按钮权限、禁用原因、二次确认和 409 冲突后的刷新/重试。
- 可访问性：标签、键盘焦点、错误提示、颜色之外的状态表达。

## 5. 任务分配

| 任务 | 时间 | 结果 |
| --- | ---: | --- |
| Vite 与项目脚本完善 | 2h | 可重复开发/构建/检查流程 |
| Router、会话和权限导航 | 3h | 管理端路由骨架 |
| Pinia/服务端状态边界 | 3h | 用户 Store 与查询缓存 |
| 企业页面与后端联调 | 5h | 组织角色、资产、工单、知识和SLA最小闭环 |
| 无 AI 训练 | 2h | 独立页面切片 |
| 求职与作品集动作 | 2h | Vue 全栈证据和投递 |

总计 17 小时。若只有 15 小时，缩减视觉打磨；不能删除错误状态、权限检查和真实后端联调。

## 6. FactoryCare 项目增量

- 完善 `factorycare-web` 的 `dev/typecheck/test/build` 脚本、环境类型、代理、路由懒加载和生产配置说明。
- 建立主布局、登录页、403、404、组织/成员角色、设备、工单、知识版本和SLA看板路由。
- `auth` Store仅保存当前用户、权限和初始化状态；刷新页面通过`/api/v1/auth/me`恢复，不持久化敏感凭据。
- Route Meta 过滤导航与动作显示；任何隐藏按钮对应的 API 仍由后端授权测试保护。
- 工单列表实现服务端分页、状态/关键字/超时筛选、排序，并把可分享条件同步到 URL。
- 工单详情按唯一状态词表提供分诊、派单、接单、开始处理、等待配件/审批、解决、验证、关闭与重开等角色可见命令；依据权限和当前状态显示可用动作。
- 组织/权限只完成成员列表、角色绑定与权限矩阵查看；所有更改仍由后端验证租户和授权。
- 知识页完成文档登记、授权上传、版本绑定、私有下载、审核、发布和撤回；Java生成受租户/用户/大小/MIME约束的上传意图与短时下载URL，不在前端伪造解析/索引成功状态。
- SLA看板只展示`reporting`只读接口的超时、待接单和按状态统计，并用一个最小ECharts图或表证明真实数据映射。
- 表单展示客户端校验、服务端字段错误、409 版本冲突、403、Session 过期和网络失败。
- 查询层按稳定 Query Key 缓存详情/列表，命令成功后精确失效；禁止把整份列表复制进 Pinia。
- 增加至少 8 条测试或可自动验证用例，覆盖登录恢复、权限路由、筛选映射、表单错误和冲突恢复。
- 写 `frontend-state-boundaries.md`，说明局部/URL/Pinia/服务端四类状态归属。

## 7. AI 协作边界

AI 可以：

- 根据 API 契约生成类型安全客户端或请求函数初稿。
- 审查路由、Store 和 Query Key，寻找权限与缓存边界错误。
- 生成 Element Plus 表单/表格骨架和失败状态清单。
- 根据 bundle 分析结果建议懒加载位置，而不是凭感觉优化。

AI 不可以：

- 让后端返回任意前端组件路径并在运行时动态导入。
- 把所有接口数据、弹窗开关和表单字段塞进一个 Pinia Store。
- 用隐藏按钮替代后端权限，或在前端保存 Session/Token 秘密。
- 为了快速通过类型检查使用大面积 `any` 或关闭严格模式。

每个 AI 生成页面必须人工验证键盘操作、失败状态、权限和 409 冲突，不以“截图看起来正确”作为完成标准。

## 8. 无 AI 训练

关闭 AI 120 分钟，实现“设备列表 + 编辑设备名称”垂直切片：

- 路由 Query 保存分页与关键字。
- 使用服务端状态查询，不把列表复制到 Pinia。
- Element Plus 表单具有必填/长度校验、提交中状态和服务端错误。
- 更新携带版本，409 时保留用户输入并提示刷新比较。
- 无权限用户看不到操作入口，直接调接口仍由后端拒绝。
- 完成后运行类型检查、测试和生产构建。

## 9. 求职动作（恢复求职后启用）

- 采样 10 个南昌 Vue3/Java 全栈/工业信息化岗位，将 Vue3、TS、Vite、Pinia、Router、Element Plus、权限、ECharts 要求映射到当前项目。
- 更新简历：`完成 Vue3/TS 企业管理端，区分 Pinia 客户端状态与服务端查询缓存，覆盖权限路由、复杂表单、分页筛选和乐观锁冲突恢复`。
- 录制 5 分钟 Web 端演示，必须展示一次 403/409/网络失败，而不只展示成功路径。
- 本周至少完成 8 次 Vue/全栈定向投递；根据沟通率调整简历首屏是“2 年 Vue”还是“Java + Vue 全栈”。

## 10. 本周交付物

- 可构建的 FactoryCare Vue3 管理端与工程脚本。
- 登录恢复、组织/角色、资产、工单、知识文件/版本、SLA只读看板、复杂表单和错误恢复。
- `frontend-state-boundaries.md`。
- 不少于 8 条前端自动验证用例与无 AI 页面切片。
- 5 分钟演示和更新后的 Vue/全栈简历条目。

## 11. 验收标准

- `pnpm typecheck`、测试和生产构建全部通过，Vite 环境中不包含秘密。
- 刷新任意受保护页面能恢复会话；匿名、403、404 和过期会话行为明确。
- 工单筛选可分享/刷新，分页、排序与服务端查询一致。
- Pinia 不保存整份服务器列表，写后失效和冲突恢复可解释。
- 每个业务动作同时受前端体验控制和后端安全控制。
- 复杂表单覆盖客户端/服务端校验、重复提交和版本冲突。
- 成员角色、知识授权上传/私有下载/发布撤回和SLA看板至少各有一条成功及一条失败/无权限验证。
- 无 AI 120 分钟切片通过类型检查、测试和构建。

## 12. 明确不做

- 不引入多个 UI 库、Vuex、微前端或低代码平台。
- 不把服务端数据全部放进 Pinia，不实现自制全功能查询缓存库。
- 不做只有静态 Mock 数据的“后台模板换皮”。
- 不把前端动态菜单当作后端授权来源。
- 不做大屏、地图或装饰性图表；只实现来自`reporting`真实只读指标的最小SLA图表。

## 13. 官方资料

- [Vite Guide](https://vite.dev/guide/)
- [Vite Env Variables and Modes](https://vite.dev/guide/env-and-mode.html)
- [Vue Router Guide](https://router.vuejs.org/guide/)
- [Vue Router Navigation Guards](https://router.vuejs.org/guide/advanced/navigation-guards.html)
- [Pinia Core Concepts](https://pinia.vuejs.org/core-concepts/)
- [TanStack Query for Vue](https://tanstack.com/query/latest/docs/framework/vue/overview)
- [Element Plus Form](https://element-plus.org/en-US/component/form.html)
- [Element Plus Table](https://element-plus.org/en-US/component/table.html)
- [Vue Production Deployment](https://vuejs.org/guide/best-practices/production-deployment.html)
