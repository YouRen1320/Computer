# 第 10 周：PostgreSQL 18 数据建模与 SQL

## 定位

第9周已首次启动真实PostgreSQL容器，但只做连接烟雾测试；本周正式进入业务建模与SQL。目标不是会使用数据库GUI，而是把FactoryCare的业务事实、约束和查询需求转化为PostgreSQL 18.4关系模型与可验证SQL。Java持久化接入留到第12周，先让数据库设计独立正确。

时间预算：15—18小时。复用第9周已验证的固定版本容器，从本周开始创建业务schema和种子数据，不在本机同时维护多个数据库安装来源。

## 前置

- FactoryCare API、领域模型和测试体系可用。
- Testcontainers/Docker smoke test 已能启动 PostgreSQL 18.4。
- 能描述设备、工单、组织和用户之间的业务关系。
- 能区分 Java/JSON 类型与数据库类型，不假设自动一一对应。

## 目标

- 理解关系、行、列、键、约束、NULL 和规范化的实际价值。
- 为 FactoryCare 建立组织、用户、设备、工单的 PostgreSQL 18 模型。
- 正确选择 UUID、text、numeric、boolean、date/timestamptz、jsonb 等类型。
- 使用 DDL/DML 和约束保证关键数据有效。
- 编写 SELECT、JOIN、聚合、子查询、CTE 和基础窗口查询。
- 使用种子数据验证常见查询与边界。
- 建立 SQL 脚本和数据字典，为 Flyway 迁移做准备。

## 完整概念清单

### 关系模型

- database、schema、table、row、column、relation 的基本含义。
- SQL 查询结果通常按 bag/multiset 处理，不能假设天然去重或有序。
- 主键、候选键、自然键、业务 ID、代理键。
- 外键表达引用完整性，应用层检查不能替代数据库约束。
- 一对一、一对多、多对多及连接表。
- 实体、关系和属性从业务语言映射到表结构。
- 数据库 schema 与 Java package、JSON schema 不是一回事。

### 规范化与边界

- 第一、第二、第三范式的实用直觉：原子字段、完整依赖、减少传递依赖。
- 重复字段带来更新、插入和删除异常。
- 规范化是默认起点，反规范化必须有可测量查询理由。
- 状态显示文案与稳定状态码分离。
- 不为每个 enum 建表，也不把全部业务数据塞 JSONB。
- 历史快照与当前事实的差异；本周只建当前核心模型。

### PostgreSQL 18 类型

- `uuid` 与 identity/bigint 的取舍；FactoryCare 使用应用可生成的 UUID 业务 ID。
- `text` 与 `varchar(n)`；长度业务规则通过合适约束表达。
- `integer/bigint`、`numeric`、浮点类型的精度边界。
- `boolean` 不用 0/1/字符串替代。
- `date`、`timestamp`、`timestamptz`；审计时刻优先 `timestamptz`。
- `interval` 的用途；SLA 时长也可在应用配置中表达。
- `jsonb` 只用于真正半结构化、查询需求明确的扩展数据。
- array、range、PostgreSQL enum 了解存在；没有业务证据不引入。
- collations 和大小写只了解对唯一性/排序的影响。

### NULL 与三值逻辑

- NULL 表示未知/缺失，不等于空字符串、0 或 false。
- 使用 `IS NULL/IS NOT NULL`，不能用 `= NULL`。
- AND/OR/NOT 在 UNKNOWN 下的行为。
- aggregate 通常忽略 NULL；`count(*)` 与 `count(column)` 不同。
- `COALESCE` 只在明确后备语义时使用，不能掩盖错误数据。
- 能用 NOT NULL 表达必需就不要允许 NULL。

### 约束

- `PRIMARY KEY`、`FOREIGN KEY`、`UNIQUE`、`NOT NULL`、`CHECK`、`DEFAULT`。
- 唯一约束的业务范围，例如 `(organization_id, equipment_code)`。
- 外键更新/删除动作必须明确，不默认级联删除业务历史。
- CHECK 适合行内可验证规则；跨行复杂规则留给事务/应用设计。
- 约束名称应可读，便于错误映射和排查。
- default 是插入默认，不是修复既有 NULL。

### DDL 与 DML

- `CREATE/ALTER/DROP` 与 schema 变更风险。
- `INSERT/UPDATE/DELETE/RETURNING`。
- `INSERT ... ON CONFLICT` 的高层用途；不滥用 upsert 掩盖业务冲突。
- `UPDATE/DELETE` 必须先确认 WHERE；学习环境也养成事务和备份意识。
- DDL 脚本可重复执行与正式版本迁移是两回事；Flyway 第 12 周处理。

### SELECT 与查询

- SQL 逻辑处理顺序：FROM/JOIN、WHERE、GROUP BY、HAVING、SELECT、ORDER BY、LIMIT 的直觉。
- 明确列名，不用 `SELECT *` 作为稳定应用契约。
- alias、表达式、CASE、字符串/时间函数适量使用。
- INNER/LEFT JOIN；错误过滤条件如何把 LEFT JOIN 变成 INNER 效果。
- CROSS/RIGHT/FULL JOIN 了解用途，不为使用而使用。
- `DISTINCT` 不是修复错误 join 的默认手段。
- `GROUP BY`、聚合、HAVING。
- scalar/correlated subquery 与 `EXISTS/NOT EXISTS`。
- CTE 提升可读性；不假设一定更快。
- `UNION/UNION ALL` 的去重成本差异。
- 窗口函数 `row_number/rank/count over` 的基本用途。
- ORDER BY 必须稳定，分页追加唯一键排序。

### 数据操作与工具

- 使用 `psql` 执行脚本、查看表、描述结构和事务。
- 容器卷、临时测试数据库和本地学习数据的区别。
- SQL 文件使用 UTF-8，示例数据脱敏。
- 不把生产 dump、真实客户信息和密码交给 AI。

## 任务分配

| 模块 | 时间 | 任务 |
| --- | ---: | --- |
| 关系建模 | 3h | 业务词汇、关系、键、规范化和数据字典 |
| 类型与约束 | 2.5h | PostgreSQL 类型、NULL、PK/FK/UNIQUE/CHECK |
| SQL 基础 | 3h | DDL、INSERT/UPDATE/DELETE/RETURNING、SELECT/JOIN |
| 查询进阶 | 2.5h | 聚合、EXISTS、CTE、窗口函数和稳定分页 |
| FactoryCare | 3—4h | 建表、种子数据和业务查询脚本 |
| 无 AI 训练 | 2h | 从需求独立写SQL与修复约束 |
| 求职动作 | 1h | SQL 面试题和投递 |

## FactoryCare项目增量

设计并创建至少以下表：

- `organization`：组织业务 ID、名称、创建时间。
- `user_account`：所属组织、登录标识、显示名、启用状态；认证细节第 13 周处理。
- `equipment`：所属组织、设备业务 ID、组织内唯一编码、名称、状态、创建时间。
- `work_order`：所属组织、设备、故障描述、优先级、状态、创建/更新时间、版本号。

约束要求：

- 所有权范围明确，设备编码在组织内唯一。
- 工单必须引用同一组织的设备；可通过复合唯一键/外键或后续事务设计保证，需记录选型。
- 优先级和状态只能取稳定业务码。
- 关键字段 NOT NULL；版本号非负；更新时间不早于创建时间。
- 删除组织/设备不能静默级联抹掉工单历史。

编写不少于 12 个真实查询：工单详情、按状态筛选、设备未关闭数、组织工单统计、超期候选、重复故障设备、最近一单、无工单设备、按月趋势和稳定分页等。

## AI协作边界

可以让 AI：

- 根据你的业务规则提出候选 ER 模型和反例。
- 审查字段类型、NULL、唯一性和外键删除行为。
- 为你已写的查询生成边界数据。
- 解释 SQL 错误，但不能用删除约束作为默认修复。

必须由你完成：

- 先写业务事实、唯一性和生命周期，再决定表。
- 解释每个主键、外键、NOT NULL、UNIQUE 和 CHECK 的业务意义。
- 独立写至少一半核心查询，并验证结果集。
- 检查 AI SQL 是否存在错误 join、遗漏组织范围、`SELECT *` 或危险无 WHERE 修改。

## 无AI训练

本周从求职/复盘时段预留45—60分钟完成并记录：滑动窗口题；写出窗口不变量和收缩条件。

关闭 AI，限时 120 分钟：

1. 从空数据库创建简化 organization/equipment/work_order 三表。
2. 插入能够暴露 NULL、重复编码、孤儿外键和跨组织引用问题的数据。
3. 用约束拒绝非法数据，不在 SQL 脚本里静默清洗。
4. 写“每个组织未关闭工单最多的三台设备”查询。
5. 解释 JOIN、GROUP BY、HAVING、窗口函数和稳定排序。

## 求职动作

- 准备主键/外键/唯一键、范式、NULL、JOIN、WHERE/HAVING、子查询/CTE、窗口函数的口述。
- 每道题使用 FactoryCare schema 举例，并能现场写基础 SQL。
- 完成至少 6 个 Java/全栈岗位定向投递，记录数据库是 MySQL 还是 PostgreSQL；语法差异后续补，不更换主库。
- 简历可写“PostgreSQL 18 关系建模与 SQL 实践”，不写生产 DBA 或性能调优经验。

## 交付物

- FactoryCare ER 图或关系说明、数据字典和约束清单。
- PostgreSQL 18.4 建表、清理和种子数据脚本。
- 不少于 12 个业务查询及预期结果说明。
- 非法数据约束验证记录。
- 无 AI SQL 训练和复盘。

## 验收标准

- 能从业务规则推导键、关系、NULL 和约束，而不是只画表。
- PostgreSQL 18.4 容器可从空环境建立 schema 和种子数据。
- 重复设备编码、孤儿引用、非法状态、空关键字段等被数据库拒绝。
- 能解释主要 PostgreSQL 类型选择和 JSONB 的限制。
- 能独立写 JOIN、聚合、EXISTS、CTE、窗口函数和稳定分页查询。
- 查询结果与手算样例一致，无依赖天然顺序和 `SELECT *` 的稳定契约。
- 无 AI 完成简化建模、约束和复杂查询。

## 明确不做

- 不接 MyBatis/JPA/JDBC 应用代码；第 12 周再接。
- 不深入索引、EXPLAIN、MVCC、隔离级别和锁；第 11 周专门处理。
- 不设计完整认证、RBAC、多租户隔离和审计；后续周次处理。
- 不使用触发器、存储过程、分区、复制、分库分表或数据库 enum。
- 不同时安装 MySQL、Oracle、SQL Server 做横向比较。

## 官方资料

- [PostgreSQL 18.4 Documentation](https://www.postgresql.org/docs/18/)
- [Data Definition](https://www.postgresql.org/docs/18/ddl.html)
- [Data Types](https://www.postgresql.org/docs/18/datatype.html)
- [Queries](https://www.postgresql.org/docs/18/queries.html)
- [Functions and Operators](https://www.postgresql.org/docs/18/functions.html)
- [PostgreSQL Tutorial](https://www.postgresql.org/docs/18/tutorial.html)
