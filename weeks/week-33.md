# 第33周：Java、Python、Web、App、小程序全链路与契约联调

## 本周定位

本周不新增大功能，把此前分阶段完成的服务和客户端连接成一个可重复的真实业务闭环。重点是契约、身份、租户、错误、流、事件、版本和可追踪性，而不是手工改字段直到“看起来能跑”。

## 前置条件

- G3—G6核心阶段通过；
- Java核心、三个客户端和Python AI都有独立测试；
- OpenAPI、事件schema和流事件协议存在；
- 有可重置的演示租户、用户、设备、文档和工单数据。

## 本周目标

- 固定公共API、内部API、事件和SSE契约；
- 使用OpenAPI生成/校验TypeScript和Dart客户端；
- 完成认证、租户和traceId跨端链路；
- 完成扫码报修→分诊→派单→离线处理→验证→知识沉淀；
- 处理部分失败、重复、取消、超时和版本冲突；
- 建立端到端自动化与可重复演示数据；
- 删除重复实现和临时绕过，不做机会性重构。

## 必须理解的概念

- API contract、consumer/provider和schema evolution；
- backward compatible新增与breaking change；
- DTO版本、错误码、枚举扩展和未知值；
- OpenAPI生成物、手写扩展层和CI漂移检查；
- correlation/trace ID跨HTTP、SSE、事件和后台任务；
- timeout budget和级联超时；
- client retry与server idempotency配合；
- event delivery至少一次、consumer幂等和顺序假设；
- eventual consistency和UI中间状态；
- SSE事件ID、断线、重连、重复和最终状态；
- demo seed、fixture、clock和确定性；
- contract/integration/E2E测试各自发现什么；
- feature flag、兼容窗口、部署顺序和回滚。

## 时间与任务（15—18小时）

下方120分钟无AI训练计入任务2的契约兼容实现，不在总时长之外重复增加。

### 任务1：契约盘点（2小时）

- 列出公共REST、内部Python、SSE和事件契约；
- 删除或标记未使用端点；
- 统一时间、ID、分页、错误和枚举策略；
- 为breaking change写迁移和客户端影响；
- 锁定发布候选`v1`，后续只接受bug修复。

### 任务2：OpenAPI与客户端（3小时）

- 生成TypeScript和Dart客户端；
- 建立生成物不手改规则和自定义wrapper；
- CI比较schema/生成物；
- uni-app、Vue和Flutter处理相同错误码；
- 测试新增未知枚举或可选字段的兼容行为。

### 任务3：主业务全链路（4小时）

完成并录制：

1. Web登记设备/手册并生成二维码；
2. 小程序扫码报修并上传图片；
3. Python给分诊建议，调度员人工确认派单；
4. Flutter技师接单、离线检查、恢复同步；
5. 诊断助手检索手册/案例并带引用；
6. 技师提交解决，报修人确认；
7. 关闭事件生成知识草稿，管理员审核发布；
8. 新知识进入检索，审计/报表更新。

每一步保存traceId和可观察状态。

### 任务4：失败链路（3小时）

- 小程序重复提交；
- 两个调度员同时派单；
- Flutter离线版本冲突；
- Python超时/关闭AI feature；
- 文档入库部分失败和重复事件；
- SSE中途断开；
- 跨租户ID和撤回文档；
- 对象存储失败。

确认失败不会破坏核心状态，并能从日志解释。

### 任务5：自动化和种子数据（2—3小时）

- 一条跨Java/Python的contract/integration test；
- 一条Vue主流程Playwright；
- Flutter/uni-app保留可重复真机脚本或能自动化的关键段；
- 创建一键重置演示数据命令；
- 时间/SLA和模型结果使用可控fake用于确定性E2E。

### 任务6：范围清理和复盘（1小时）

- 列出临时绕过、TODO、未验证平台和已知限制；
- 只修阻塞发布的问题；
- 机会性重构进入单独清单，不混进联调。

## FactoryCare项目增量

- 发布候选API/事件/SSE契约；
- 三端生成客户端和契约CI；
- 完整主链路与失败链路；
- 演示种子数据和一键重置；
- 全链路trace与联调报告。

## AI协作边界

AI可以分析契约差异、生成测试矩阵和定位日志，但任何API/数据/事件变更都属于重大变更：必须先写影响、客户端迁移、部署顺序和回滚，不能让AI顺手统一字段。

## 无AI训练（120分钟）

处理一个契约变化：工单优先级新增未知值。确保Java、OpenAPI、Vue、uni-app、Flutter和Python不会静默崩溃；写兼容策略、测试和部署顺序。

## 求职动作

- 进行一次10分钟全链路演示；
- 邀请他人只看README启动核心服务，记录卡点；
- 每周投递10—15个最匹配岗位，使用R2/R3/R4版本对照结果。

## 交付物

- [ ] 契约清单和变更策略；
- [ ] OpenAPI生成与CI检查；
- [ ] 主链路演示记录；
- [ ] 至少8类失败验证；
- [ ] 一键演示数据；
- [ ] 全链路trace样例；
- [ ] 联调问题/已知限制清单；
- [ ] 无AI任务和周复盘。

## 验收标准

- 第三人按说明可运行核心演示；
- 三端不直连Python/数据库/私有存储；
- 失败路径不会造成越权、重复写或静默覆盖；
- Python不可用时工单主流程可降级；
- 契约漂移能被CI发现；
- 主链路每步可由traceId定位。

## 本周明确不做

- 新增大型业务模块；
- 重新设计全部UI；
- 顺手拆微服务；
- 为兼容保留两套永久API；
- 手工修改生成客户端；
- 掩盖未验证平台和失败。

## 官方资料

- [OpenAPI Specification](https://spec.openapis.org/oas/latest.html)
- [Spring REST API documentation concepts](https://docs.spring.io/spring-restdocs/docs/current/reference/htmlsingle/)
- [Spring Modulith events](https://docs.spring.io/spring-modulith/reference/events.html)
- [OpenTelemetry context](https://opentelemetry.io/docs/concepts/context-propagation/)
