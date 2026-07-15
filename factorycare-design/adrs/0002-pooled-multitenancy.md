# ADR-0002：共享schema的行级多租户

- 状态：Accepted（设计基线）
- 日期：2026-07-11

## 上下文与目标

FactoryCare需要真实演示租户隔离、组织数据范围、唯一约束和AI隔离，但学习项目无法承担每租户独立数据库的运维。租户数量和合规等级未知，不能虚构物理隔离需求。

## 选项比较

| 选项 | 实现成本 | 迁移成本 | 风险 | 回滚难度 | 长期维护 |
| --- | --- | --- | --- | --- | --- |
| 每租户独立数据库 | 高 | 新租户/迁移/报表复杂 | 运维爆炸，学习环境不现实 | 高 | 强隔离但成本随租户增长 |
| 每租户独立schema | 中—高 | migration需对全部schema执行 | schema漂移与连接管理 | 高 | 中等租户数仍繁琐 |
| **共享schema + 每行业务`tenant_id`** | 中 | 未来拆分需导出单租户 | 查询漏过滤是P0风险 | 中 | 最适合当前规模，需系统性防线 |

## 决定

`core`使用共享schema，所有租户业务表显式保存非空`tenant_id`。唯一键和跨表关系在可行处使用`(tenant_id, business_key)`与复合外键，避免关联到另一租户。可信tenant来自服务端认证成员上下文，应用服务与Repository API要求tenant作用域；原始ID不能单独构成授权。

PostgreSQL RLS可作为后续纵深防御实验，但在连接池上下文、后台任务和迁移策略验证前不作为唯一防线。AI使用独立`ai` schema和数据库角色；向量/chunk仍带tenant与source version，Python不能读`core`。

catalog采用显式`scope=GLOBAL|TENANT`。`GLOBAL`项（平台固定七角色、permission、role-permission和embedding model catalog）是只读平台发布物，只能由独立受控管理流程变更；租户只用`membership_role`绑定固定角色。若以后引入真正`TENANT`自定义catalog，其行必须持有非空`tenant_id`。数据库约束校验scope和tenant组合，不使用`tenant_id=NULL`隐式代表全局，也不将普通“全租户”数据范围等同于`GLOBAL`。

organization下显式建模team。`membership.team_id`可空；但`data_scope=TEAM`时必须引用同tenant、同organization且已启用的team。assignment保存team_id，技师若存在也必须落在该team范围。

## 后果

- 查询、缓存键、事件、对象元数据、幂等键和审计必须带tenant；
- 全局catalog必须明确`scope=GLOBAL`并仅允许平台发布流程改写；租户管理员不因其角色获得GLOBAL变更权；
- team增加一层组织内数据范围；所有资源查询与派单/转派都要同时校验tenant、organization和team，不仅比对teamId；
- 跨租户运维查询只能经受审计的专用管理通道，普通角色不存在“全部租户”范围；
- 单元测试不足以证明隔离，必须用双租户数据库集成与AI安全评估。

## 迁移与回滚

初始migration即建立tenant非空、复合约束与catalog scope check。若从旧的空tenant全局行迁移，先建显式scope字段/独立catalog、核对代码和引用，再禁止旧写法；回滚期可双读，不得恢复“空值就是全局”语义。若真实客户要求物理隔离，按tenant导出、校验行数/哈希/对象manifest、冻结写入、切换连接路由；切流后新写入必须回放才能回滚。

## 验证与非目标

- `FC-TEN-001/002`和权限矩阵负向测试全部通过；Schema检查不得出现无解释的租户业务表缺少tenant；
- `FC-RBAC-004/006`覆盖伪造GLOBAL、TENANT缺tenant、租户改固定role/permission catalog和普通数据范围越界；`FC-TEAM-001/002`覆盖team父组织与TEAM scope必填匹配teamId；
- Repository架构规则禁止无作用域的通用`findById`用于业务端口；
- 本ADR不声称达到监管级物理隔离，不允许用URL参数作为可信tenant。
