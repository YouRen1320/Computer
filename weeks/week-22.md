# 第 22 周：Vitest、Vue Testing Library、Playwright、SSE 与错误恢复

> 建议投入：17 小时（可在 15—18 小时内调整）

## 1. 本周定位

本周为 Vue/Nuxt 阶段建立可回归的质量闭环，并让 FactoryCare 管理端实时接收工单事件。测试按风险分层：纯逻辑用 Vitest，用户可见组件行为用 Vue Testing Library，少量关键跨系统流程用 Playwright。

SSE 用于工单状态/通知的单向实时更新；它不是“更简单的 WebSocket”口号。必须处理认证、断线、重复事件、页面卸载、服务重启和降级轮询。

## 2. 前置条件

- Vue3 管理端、Nuxt 门户和 Spring 后端可在本地联合启动。
- 前端已有稳定 API 边界、Session Cookie、关联 ID 和业务错误码。
- 后端第 17 周已有版本化工单事件/通知边界，可作为 SSE 数据来源。
- 能使用浏览器 DevTools、假定时器和测试替身，不把 E2E 当作所有测试的替代品。

## 3. 学习目标

- 能建立单元、组件、集成、E2E 测试金字塔，并按风险选择层级。
- 能用 Vitest 测纯函数、Composable、时间和异步竞态。
- 能用 Vue Testing Library 按用户角色/标签/文本测试公开行为。
- 能用 Playwright 验证登录、权限、表单、冲突和跨端主路径。
- 能解释 SSE 协议、Event ID、重连、心跳、代理缓冲和认证限制。
- 能实现可恢复的 SSE 客户端状态机和轮询降级，并证明没有重复更新或资源泄漏。

## 4. 完整概念清单

### 4.1 测试策略

- 单元测试：状态机映射、SLA 格式、权限判断、Query Key、错误归一化。
- 组件测试：以用户可见行为和无障碍语义为入口，不断言私有 ref/方法。
- 集成测试：Router、Pinia、查询层与 Mock Server/真实后端边界。
- E2E：少而关键，覆盖登录—列表—详情—业务命令—结果；测试数据可重复建立/清理。
- 测试替身边界：Mock 网络/时间/浏览器 API，不 Mock 被测组件内部实现。
- 确定性：固定时钟、稳定选择器、等待可见状态而非固定 sleep。
- 覆盖率用于发现盲区，不追求无意义 100%；优先权限和错误路径。

### 4.2 Vitest 与 Vue Testing Library

- Vitest 配置、环境、Setup、Mock、Spy、Fake Timers、参数化测试。
- Composable 在组件生命周期/Effect Scope 中测试，确认清理行为。
- Vue Testing Library 的 `getByRole/getByLabelText/findBy...` 和用户事件。
- 查询优先级与可访问性；`data-testid` 作为最后逃生口。
- 测加载、空、错误、权限、禁用、提交中和冲突，不只测快照。
- 测试运行隔离、全局状态重置和未处理 Promise。

### 4.3 Playwright

- Browser/Context/Page、Locator、自动等待、Web-first Assertions。
- Storage State 与测试账号隔离；不能让测试共享可变工单。
- API 准备测试数据，UI 验证用户流程；失败保留 trace、截图和视频。
- 禁止固定 `waitForTimeout` 解决竞态；用可观察业务状态等待。
- CI 并行、重试只用于识别偶发问题，不能掩盖稳定失败。

### 4.4 SSE 与恢复

- `text/event-stream`、`data/event/id/retry`、空行分隔、UTF-8 和心跳注释。
- EventSource 单向、浏览器自动重连；原生 EventSource 不便设置自定义 Authorization Header。
- 同源 Session Cookie 适合本项目；跨域需同时考虑 CORS、凭据和代理。
- `Last-Event-ID`、服务端短期事件保留、断点续传和重复事件去重。
- 连接状态：connecting、open、retrying、offline、fallback、closed。
- 后端/反向代理超时、缓冲、最大连接、心跳和资源释放。
- 认证过期、403/401、网络离线、标签页隐藏和组件卸载。
- 无法恢复时回退短轮询，并在连接恢复后停止轮询。

## 5. 任务分配

| 任务 | 时间 | 结果 |
| --- | ---: | --- |
| 测试策略与 Vitest 单元测试 | 3h | 核心逻辑/Composable 测试 |
| Vue Testing Library 组件测试 | 3h | 用户行为与错误路径测试 |
| Playwright 关键 E2E | 3h | 3 条跨系统流程 |
| SSE 服务端/客户端与恢复 | 4.5h | 实时更新可靠闭环 |
| 无 AI 训练 | 2h | 流式故障排查 |
| 求职与作品集动作 | 1.5h | 测试报告和演示证据 |

总计 17 小时。若只有 15 小时，减少非关键 E2E 数量；不能删除 SSE 断线/重复/卸载测试。

## 6. FactoryCare 项目增量

- 建立测试矩阵，标明哪些风险由后端集成测试、Vitest、组件测试和 E2E 覆盖，避免重复堆测试。
- 为 SLA、权限映射、筛选序列化、错误归一化和 SSE 去重编写 Vitest。
- 为登录表单、工单命令面板、403/409 提示和列表筛选编写 Vue Testing Library 测试。
- 为成员角色、知识发布/撤回和SLA看板各补至少一个关键组件或E2E验证，确保G4范围不是只有页面截图。
- 编写 3 条 Playwright E2E：登录并查看工单；主管分配工单；两个页面触发版本冲突并恢复。
- Spring 后端增加租户/用户作用域的 SSE 订阅端点，只发送当前用户有权看到的最小事件摘要。
- 每个事件包含稳定 ID、类型、租户/资源标识、版本和时间；客户端按 ID 去重并精确失效查询。
- 编写 `useWorkOrderEvents`：显式连接状态、心跳超时、重连、Last-Event-ID、卸载关闭和轮询降级。
- 配置 Nginx/本地代理关闭不当缓冲并延长合理超时；记录连接数和断线次数。
- 故障实验：网络断开、服务重启、重复事件、Session 过期、组件卸载；结果进入 `frontend-recovery-report.md`。

## 7. AI 协作边界

AI 可以：

- 根据风险矩阵生成测试用例候选和边界条件。
- 分析 Playwright trace、SSE Network 和前后端关联日志。
- 生成小型测试骨架或故障注入脚本。
- 审查测试是否过度耦合实现、SSE 是否清理资源。

AI 不可以：

- 为追求覆盖率复制无意义断言或大面积 Snapshot。
- 用固定 sleep、无限重试或跳过测试掩盖不稳定性。
- 根据一次通过就判断 SSE 恢复可靠。
- 让 SSE 端点绕过现有 Session、租户和数据权限。

AI 修复 flaky test 前，必须先给出可验证的竞态假设；修复后至少重复运行相关测试 10 次。

## 8. 无 AI 训练

关闭 AI 120 分钟，排查“页面离开后仍不断发请求，回来又收到重复工单更新”：

- 使用 Network/日志确认旧 EventSource 未关闭且重连定时器重复创建。
- 在 Composable 生命周期中清理连接、定时器和轮询。
- 按事件 ID 去重，并在连接恢复后停止降级轮询。
- 用 Fake Timers 与组件卸载测试复现，再重复运行 10 次。
- 口述原生 EventSource 的认证/Header 限制以及为何本项目选择同源 Session。

## 9. 求职动作

- 采样 8 个南昌 Vue/Java 全栈岗位，记录单测、E2E、SSE/WebSocket、性能和故障排查是否出现；岗位未写测试也要把它作为交付证据。
- 生成一页测试报告：风险、测试层、用例数、失败路径、SSE 故障实验和 CI 结果，而不是只给覆盖率百分比。
- 录制 5 分钟演示：主管分配工单，另一页面实时刷新；断网后降级并恢复，不重复事件。
- 简历表述：`以 Vitest/Vue Testing Library/Playwright 覆盖核心链路，并实现带断点恢复、去重和轮询降级的 SSE 工单更新`。

## 10. 本周交付物

- 前后端测试矩阵和可运行测试套件。
- Vitest/组件测试、3 条 Playwright E2E 及 CI 产物。
- SSE 服务端、`useWorkOrderEvents` 和 Nginx/代理配置。
- `frontend-recovery-report.md` 与五类故障实验。
- 一页测试报告和 5 分钟实时恢复演示。

## 11. 验收标准

- 类型检查、单元、组件、后端集成和 E2E 在干净环境可重复运行。
- 测试以公开行为为主，无固定 sleep；关键 E2E 失败能产出 trace。
- SSE 仅发送有权数据，事件不包含敏感内容；跨租户订阅测试失败。
- 网络断开/服务重启后可续接或降级；重复事件不会重复更新，离开页面释放连接。
- Session 过期有明确登录恢复，而不是无限重连。
- 相关 flaky 场景连续运行 10 次通过，无 AI 训练能够独立解释修复。
- 测试报告展示风险与证据，不把覆盖率当作质量结论。

## 12. 明确不做

- 不用 E2E 覆盖所有细节，不追求无意义 100% 覆盖率。
- 不用 Snapshot 替代业务断言，不用固定 sleep 修复竞态。
- 不把 SSE 改造成双向命令通道；写操作继续走受保护 HTTP API。
- 不实现大规模连接压测、Kafka 实时流或复杂 WebSocket 集群。
- 不允许 SSE 绕过认证、租户和数据权限。

## 13. 官方资料

- [Vitest Guide](https://vitest.dev/guide/)
- [Vitest Mocking](https://vitest.dev/guide/mocking.html)
- [Vue Testing Library](https://testing-library.com/docs/vue-testing-library/intro/)
- [Vue 官方测试指南](https://vuejs.org/guide/scaling-up/testing.html)
- [Playwright Best Practices](https://playwright.dev/docs/best-practices)
- [Playwright Trace Viewer](https://playwright.dev/docs/trace-viewer)
- [MDN Server-sent Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events)
- [Spring MVC Streaming / SseEmitter](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-ann-async.html)
