# 第 28 周：Nuxt 4 渲染、Hydration、数据获取、认证与部署

> 建议投入：16 小时（可在 15—18 小时内调整）

## 1. 本周定位

本周学习 Nuxt 4 不是因为南昌每个 Vue 岗都要求 Nuxt，而是补齐 SSR/SSG、同构执行和内容型产品交付能力。FactoryCare 的 Nuxt 端承担 **公开设备服务/知识入口和客户查询门户**，不会重做第 27 周的企业管理后台。

每条路由按业务选择 CSR、SSR 或 SSG，不把“默认 SSR”当成性能保证。认证页面采用服务端可读的 HttpOnly Cookie/Session 与 Nuxt Server 代理思路；路由中间件只改善导航体验，Spring 后端仍负责最终授权。

## 2. 前置条件

- 第 27 周 Vue3 管理端可构建、可联调，理解 Router、Pinia 与服务端状态边界。
- 能解释 HTTP Cookie、缓存头、代理、Node 服务和静态托管的区别。
- FactoryCare 后端已有稳定 Session 认证与公开/受保护接口边界。
- 新建独立 Nuxt 4 应用前先写用途和非目标，避免复制管理端。

## 3. 学习目标

- 能解释 CSR、SSR、SSG/Prerender、SWR/ISR 和混合渲染的请求与部署差异。
- 能描述服务端渲染、Payload 传输和客户端 Hydration 的完整过程。
- 能正确选择 `$fetch`、`useFetch`、`useAsyncData`，避免首屏双重请求。
- 能排查时间、随机数、浏览器 API、共享状态和 HTML 结构造成的 Hydration mismatch。
- 能设计 Nuxt Server/BFF 与 Spring Session 的认证转发边界。
- 能构建并部署 Node Server 与静态 Prerender 两种产物，说明各自限制。

## 4. 完整概念清单

### 4.1 Nuxt 4 目录与运行时

- `app/` 下 pages、layouts、components、composables、middleware、plugins。
- `server/` 下 API、routes、middleware；Nitro 与 Vue 应用运行时的边界。
- 自动导入、文件路由、动态路由、错误页、SEO Meta 和 Runtime Config。
- `runtimeConfig` 的 private/public 区分；客户端可见 public 配置仍不是秘密。
- Server/Client 两套环境中的 `window`、`document`、Cookie、Header 和全局变量差异。

### 4.2 CSR、SSR、SSG 与混合渲染

- CSR：浏览器取数据并渲染，适合强交互、认证后后台；首屏与 SEO 有取舍。
- Universal SSR：每个请求服务端生成 HTML，再在浏览器 Hydrate；需要 Node/边缘运行时。
- SSG/Prerender：构建时生成 HTML，适合稳定公开内容；构建后没有动态 Server API。
- `routeRules` 为不同路由设置 prerender、SSR/CSR、SWR/ISR 和缓存。
- 页面是否个性化、更新频率、SEO、首屏、部署成本与缓存泄露共同决定渲染方式。
- 认证/租户数据不能进入跨用户共享的公共页面缓存。

### 4.3 Hydration

- 服务端 HTML、Nuxt Payload、客户端创建 Vue 应用并绑定事件。
- 不一致来源：`Date.now()`、`Math.random()`、时区/Locale、浏览器专属 API、无效 HTML、异步条件差异。
- 服务端跨请求共享 `ref/reactive` 可能泄露用户状态；使用请求级状态和 `useState`。
- `ClientOnly` 是明确的客户端边界，不应掩盖可修复的不确定渲染。
- 使用稳定输入、服务端传值、挂载后读取浏览器信息，必要时提供一致占位。

### 4.4 数据获取

- `$fetch` 适合事件处理或明确的单次请求；在页面 setup 中直接使用可能 SSR/客户端各请求一次。
- `useFetch` 是 SSR 友好的 `$fetch` 包装，将结果放入 Payload 供 Hydration 复用。
- `useAsyncData` 适合自定义异步逻辑；Key、`pick`、`transform`、`lazy`、`server`、`dedupe`。
- 响应式参数会触发重新获取；搜索条件需要防抖和明确 watch 策略。
- 缓存键与租户/用户、Header、Cookie 的关系；不得错误共享私有响应。
- 写操作使用 `$fetch`，成功后刷新/清除对应数据，不在 setup 中制造副作用。

### 4.5 认证与部署

- Nuxt Route Middleware 不在每次服务端 API 请求上执行，不能当安全网关。
- HttpOnly Session Cookie 服务端可读；SSR 请求需安全转发 Cookie/CSRF 到 Spring。
- 推荐 Nuxt Server 作为窄 BFF/同源代理，白名单转发必要 Header，不做任意开放代理。
- 防止 SSRF、Cookie 泄露和缓存跨用户污染；服务端日志不记录凭据。
- `nuxt build` 产生可运行 Server 产物，`nuxt generate`/prerender 产生静态文件。
- Nitro preset、Node 进程、反向代理、健康检查、环境变量与优雅停止。

## 5. 任务分配

| 任务 | 时间 | 结果 |
| --- | ---: | --- |
| Nuxt 4 目录和渲染实验 | 3h | CSR/SSR/SSG 请求对比 |
| Hydration 与数据获取实验 | 3h | mismatch 故障笔记 |
| FactoryCare 门户实现 | 4.5h | 不重复后台的 Nuxt 页面 |
| Session/BFF 与部署验证 | 2.5h | 安全代理和两种产物 |
| 无 AI 训练 | 2h | Hydration排错 |
| 求职与定位动作 | 1.5h | Nuxt 边界表述和投递 |

总计 16.5 小时。若有 18 小时，增加缓存头与性能测量；不要扩展成第二套完整后台。

## 6. FactoryCare 项目增量

- 新建 `factorycare-portal`（Nuxt 4），README 明确它服务公开内容/客户查询，不复制管理端工单调度功能。
- 首页、服务说明和帮助文档使用 Prerender/SSG；公开设备服务页使用 SSR/SWR；认证后的“我的报修”保持逐用户动态渲染，禁止共享缓存。
- 使用 `routeRules` 明确每类路由策略，并写出选择依据。
- 公开页面通过 `useFetch` 获取内容，提交查询/报修动作使用 `$fetch`；证明首屏没有重复请求。
- 增加一个窄 Nuxt Server API 代理，将允许的 Cookie、CSRF 和关联 ID 转发到 Spring；目标地址来自私有 Runtime Config。
- 登录恢复与受保护导航在服务端/客户端均有一致状态；后端继续独立验证 Session、权限与租户。
- 故意制造并修复 3 类 Hydration mismatch：时间、浏览器 API、跨请求共享状态。
- 分别验证 Node Server 部署和公开静态页面 Prerender；记录动态认证功能为何不能只用静态托管。
- 编写 `ADR-021-nuxt-rendering.md`，包含路由矩阵、缓存/认证风险、部署与回滚方案。

## 7. AI 协作边界

AI 可以：

- 根据页面属性生成渲染模式决策表并审查遗漏。
- 分析 Hydration 警告、请求瀑布和 Nuxt Payload。
- 生成类型安全 `useFetch`/Server Route 骨架和测试场景。
- 比较 Node、静态、边缘部署，但结论必须结合实际产物验证。

AI 不可以：

- 把所有页面改为 SSR 或所有页面改为 CSR 作为统一“修复”。
- 让 Nuxt Server 接受客户端提供任意上游 URL，或转发全部 Header/Cookie。
- 把认证/租户响应放入公共缓存，或把私密 Runtime Config 暴露为 public。
- 用 `ClientOnly` 掩盖所有 Hydration mismatch。

AI 修改后必须检查页面 HTML、Network、Server 日志和不同用户缓存，不只看浏览器视觉结果。

## 8. 无 AI 训练

关闭 AI 120 分钟，修复一个Nuxt页面中的Hydration mismatch与重复请求：

- 页面服务端使用当前时间格式化，客户端时区不同；先定位两端输出差异。
- setup 中错误使用 `$fetch` 导致服务端/客户端各请求一次；改为合适的 `useFetch`。
- 使用浏览器 API 的组件要建立明确客户端边界并提供一致占位。
- 写出修复前后请求次数、HTML 差异和为何不使用 `ssr:false` 一刀切。

## 9. 求职动作（恢复求职后启用）

- 采样南昌及可接受远程的 Vue 岗各 5 个，记录 Nuxt/SSR/SEO 是否真实出现；若本地样本仍少，Nuxt 只作为交付加分项，不改求职主标签。
- 简历表述：`使用 Nuxt 4 按路由组合 SSR/SSG/CSR，解决 Hydration 与重复取数，并通过窄 BFF 安全转发 Spring Session`。
- 准备 5 分钟回答：为什么企业管理后台通常不需要为 SEO 全站 SSR？
- 本周继续至少 5 次 Vue/Java 全栈投递；不要因为 Nuxt 岗位关键词少而暂停已有 Vue3 路线。

## 10. 本周交付物

- Nuxt 4 FactoryCare 门户与渲染路由矩阵。
- 公开 SSG、动态 SSR 和认证动态页面的可运行示例。
- Session/BFF 代理、三类 Hydration 修复记录和请求证据。
- `ADR-021-nuxt-rendering.md`。
- Node Server 与静态 Prerender 部署说明、无 AI 排错记录。

## 11. 验收标准

- 能在白板上画出 CSR、SSR、SSG 和 Hydration 请求/执行流程。
- 每条路由有业务依据，不缓存跨用户的认证/租户数据。
- 首屏 `useFetch` 不重复请求，Hydration 控制台无未解释警告。
- BFF 只代理允许路径/Header，目标地址不可由用户控制，日志不泄露 Cookie。
- Node 产物可运行；静态产物限制有明确验证，不声称静态部署支持动态 Server API。
- 无 AI 能定位时间、浏览器 API和重复请求问题。
- 能解释 Nuxt 对本地求职是补充能力，而不是替代 Vue3 企业后台证据。

## 12. 明确不做

- 不用 Nuxt 重写第 27 周完整管理后台。
- 不学习边缘运行时内部原理、Nuxt 模块开发或复杂 Content CMS。
- 不把 Route Middleware 当作后端授权。
- 不全站强制 SSR，也不靠 `ssr:false` 规避所有问题。
- 不把私有 Session 数据放进公共 SWR/ISR 缓存。

## 13. 官方资料

- [Nuxt 4 Guide](https://nuxt.com/docs/4.x/guide)
- [Nuxt Rendering Modes](https://nuxt.com/docs/4.x/guide/concepts/rendering)
- [Nuxt Data Fetching](https://nuxt.com/docs/4.x/getting-started/data-fetching)
- [Nuxt useFetch](https://nuxt.com/docs/4.x/api/composables/use-fetch)
- [Nuxt and Hydration](https://nuxt.com/docs/4.x/guide/best-practices/hydration)
- [Nuxt Sessions and Authentication](https://nuxt.com/docs/4.x/guide/recipes/sessions-and-authentication)
- [Nuxt Runtime Config](https://nuxt.com/docs/4.x/guide/going-further/runtime-config)
- [Nuxt Deployment](https://nuxt.com/docs/4.x/getting-started/deployment)
