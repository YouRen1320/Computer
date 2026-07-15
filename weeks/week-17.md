# 第 17 周：RBAC、多租户、数据权限与审计

> 建议投入：16.5 小时（可在 15—18 小时内调整）

## 1. 本周定位

登录只证明“你是谁”，企业系统还必须回答“你能对哪些数据做什么”。本周建立 FactoryCare 的授权纵深：接口权限、方法权限、租户隔离、组织数据范围和审计追踪同时存在，任何一层都不能只靠前端隐藏按钮。

项目选择 **共享数据库、共享 Schema、业务表强制携带 `tenant_id`** 的轻量多租户方案，适合作品集和中小型企业应用；同时学习独立 Schema、独立数据库的取舍，但不实现三套方案。

## 2. 前置条件

- 第 16 周 Session 登录、当前用户接口与安全测试已通过。
- 已有用户、设备、工单等表，并能编写 MyBatis 查询和集成测试。
- 能解释数据库唯一约束、事务和索引的基本作用。
- 已明确 FactoryCare 当前不是 SaaS 计费平台，多租户只验证隔离设计。

## 3. 学习目标

- 能区分 RBAC、资源所有权、数据范围和 ABAC，并组合使用。
- 能设计用户—角色—权限关系及稳定的权限编码。
- 能从认证主体取得可信 `tenant_id`，而不是相信请求体或普通请求头。
- 能让所有关键查询、更新、唯一约束和缓存键遵守租户边界。
- 能实现可检索、可脱敏、不可被普通用户修改的审计记录。
- 能用负向测试证明跨租户和越权访问失败。

## 4. 完整概念清单

### 4.1 授权模型

- RBAC：租户成员、角色、权限、角色权限、成员角色；角色绑定到`membership`，避免全局用户角色越过租户边界。
- 权限编码采用业务动作，如 `workorder:assign`、`asset:update`，不绑定页面路径。
- 粗粒度 URL 授权与细粒度方法授权；默认拒绝、最小权限。
- 资源所有权、组织层级和数据范围：本人、本班组、本部门及下级、全租户。
- RBAC 与 ABAC 的边界；不要把所有条件都塞进角色数量爆炸的 RBAC。
- 前端菜单/按钮权限只改善体验，后端才是安全判定源。
- 401、403、404 的信息泄露权衡；敏感资源可对越权访问隐藏存在性。

### 4.2 多租户设计

- 独立数据库、独立 Schema、共享表三种模式的隔离强度、成本和迁移难度。
- `tenant_id` 的来源：登录主体或可信系统上下文；禁止由客户端任意指定。
- Request/Thread Context 的创建、使用和清理；异步任务中上下文不能自动假定存在。
- 查询、更新、删除必须同时限制业务主键与 `tenant_id`。
- 唯一约束应包含租户维度，例如 `(tenant_id, asset_code)`。
- 分页、聚合、导出、批量操作、缓存、搜索和审计也必须租户化。
- MyBatis 拦截器可做辅助防护，但不能替代显式仓储契约和集成测试。
- PostgreSQL Row-Level Security 的能力与运维复杂度；本周只做对照实验，不把它当作唯一防线。

### 4.3 审计与追踪

- 安全审计与普通业务日志的差异。
- 审计字段：租户、操作者、动作、对象类型与 ID、时间、结果、来源 IP、关联 ID。
- 对关键变更保存必要的前后差异或摘要；密码、Token、隐私字段必须脱敏。
- 登录成功/失败、角色变更、越权拒绝、工单分配与状态变更属于高价值审计事件。
- 审计写入失败的策略、事务边界和性能取舍。
- 审计表只追加，由受限接口查询；普通业务用户不能修改或删除。
- 关联 ID 串联 HTTP 请求、业务日志和审计事件。

### 4.4 常见攻击与缺陷

- IDOR/BOLA：只校验“已登录”，却未校验资源归属。
- Mass Assignment：DTO 接受 `tenantId`、`role` 等不该由用户修改的字段。
- 批量接口、导出接口、统计接口最容易遗漏数据范围。
- 超级管理员万能角色、硬编码角色名和散落的权限表达式导致维护失控。

## 5. 任务分配

| 任务 | 时间 | 结果 |
| --- | ---: | --- |
| 授权与租户方案设计 | 3h | 权限矩阵、数据范围和 ADR |
| RBAC 与方法授权实现 | 3.5h | 后端权限闭环 |
| 租户隔离与审计实现 | 5h | 租户化查询和审计记录 |
| 越权/跨租户集成测试 | 2h | 负向测试证据 |
| 无 AI 训练 | 2h | 越权漏洞修复 |
| 求职采样与项目表达 | 1.5h | JD 矩阵与面试答案 |

总计 17 小时。时间不足时减少 RLS 对照实验，不能删除跨租户测试。

## 6. FactoryCare 项目增量

- 建立 `permission`、`role`、`role_permission`、`membership_role` 等最小关系；`membership_role`在租户成员关系上绑定角色，避免把菜单表或全局用户角色直接当权限来源。
- 为设备、工单、用户组织关系和审计表增加 `tenant_id`，并建立组合索引/唯一约束。
- 当前用户上下文从认证主体读取 `userId`、`tenantId` 和权限集合。
- 为工单查看、创建、分配、更新、关闭建立权限矩阵，并在方法边界执行授权。
- 数据范围至少实现“本人/班组/全租户”三档；仓储方法显式接收租户和范围条件。
- DTO 不接受客户端传入的 `tenantId`、审计操作者、系统角色等敏感字段。
- 增加只读审计查询：支持按操作者、对象、动作、时间筛选；普通用户不可修改审计记录。
- 编写 `ADR-014-authorization-and-tenancy.md`，记录共享表方案、失败模式、未来迁移条件和回滚方式。
- 至少 10 条负向测试：跨租户读/写、无权限分配、越权批量查询、伪造 tenantId、审计不可改等。

## 7. AI 协作边界

AI 可以：

- 根据业务动作生成权限矩阵初稿和威胁清单。
- 审查 MyBatis SQL 是否漏掉租户条件，并生成负向测试骨架。
- 比较三种多租户存储模式的成本、风险和迁移方式。
- 帮助把散落的权限判断收敛到清晰的策略接口。

AI 不可以：

- 根据前端按钮或路由自动推断最终后端权限。
- 将客户端传入的 `tenantId` 当可信来源。
- 用一个全局 MyBatis 拦截器取代所有显式边界和测试。
- 生成或接触真实用户、企业和审计数据。

接受 AI 生成 SQL 前，必须手工检查 `SELECT/UPDATE/DELETE/COUNT/EXPORT` 五类路径的租户约束。

## 8. 无 AI 训练

本周从求职/复盘时段预留45—60分钟完成并记录：Top K变体；比较排序、堆和桶思路。

关闭 AI 120 分钟：给定一个“按工单ID更新负责人”的接口，其中只校验了登录状态。完成：

1. 找出 IDOR、跨租户写入和 Mass Assignment 风险。
2. 修改服务和 SQL，使更新同时校验租户、权限与版本条件。
3. 补一条合法测试和三条越权测试。
4. 口述为什么前端隐藏按钮、URL 拦截器和数据库主键都不足以单独保证数据权限。

## 9. 求职动作（恢复求职后启用）

- 采样 8 个南昌 Java/全栈/政企信息化岗位，记录“RBAC、数据权限、组织权限、审计、单点登录、多租户”等关键词。
- 将项目简历描述更新为：`设计租户级 RBAC 与本人/班组/全租户数据范围，以负向集成测试验证跨租户隔离`。
- 准备一张 A4 权限矩阵，在模拟面试中用 5 分钟解释接口权限和数据权限的区别。
- 继续投递 Vue/Java 全栈岗位；对要求若依、Spring Security 或政企权限模型的 JD 做定制投递。

## 10. 本周交付物

- 权限矩阵、租户数据模型图和 `ADR-014-authorization-and-tenancy.md`。
- RBAC、数据范围、租户隔离与只读审计实现。
- 不少于 10 条负向安全测试和测试报告。
- 一份越权漏洞无 AI 修复记录。
- 更新后的项目简历条目与岗位关键词矩阵。

## 11. 验收标准

- 能区分 RBAC、ABAC、资源所有权、数据范围和多租户。
- 新建租户 A、B 后，A 无法通过详情、列表、统计、更新或批量接口观察或修改 B 的数据。
- `tenant_id` 来自认证上下文，不从普通请求 DTO 读取。
- 权限判断同时存在于后端方法/领域边界，前端显示控制不承担安全责任。
- 审计记录包含谁、何时、对什么做了什么、结果如何和关联 ID，敏感字段已脱敏。
- 关键越权路径有自动化测试，测试失败时能定位到授权、业务或 SQL 层。
- 能在 5 分钟内向面试官说明共享表租户方案的风险、替代方案和迁移条件。

## 12. 明确不做

- 不实现完整 SaaS 计费、租户自助开通和跨区域数据驻留。
- 不同时实现独立数据库、独立 Schema 和共享表三套方案。
- 不把角色名硬编码到每个 Controller，不创建“万能管理员绕过一切”的隐式后门。
- 不只依赖前端、MyBatis 插件或 PostgreSQL RLS 中的任意单层防护。
- 不保存密码、Token、附件正文等不必要的审计数据。

## 13. 官方资料

- [Spring Security Authorization](https://docs.spring.io/spring-security/reference/servlet/authorization/index.html)
- [Spring Security Method Security](https://docs.spring.io/spring-security/reference/servlet/authorization/method-security.html)
- [Spring Security 多租户 Resource Server 参考](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/multitenancy.html)
- [Spring Boot Actuator Auditing](https://docs.spring.io/spring-boot/reference/actuator/auditing.html)
- [PostgreSQL Row Security Policies](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)
- [OWASP API1: Broken Object Level Authorization](https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/)
