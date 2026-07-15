# 第 12 周：SQL 语法、查询、聚合、JOIN 与数据修改

## 定位

本周把 SQL 作为独立语言系统学习，而不是等 MyBatis 生成查询。目标是能从业务问题写出、解释和验证 SQL，并理解声明式查询、NULL 与逻辑处理顺序。先用 PostgreSQL 练习通用 SQL，建模/索引/事务分别在 Week 13—14 深入。

时间预算：15—18 小时。所有查询必须在可重置数据集上执行，并核对结果而不是只看语法通过。

## 前置

- Spring Web/API 和测试基础已建立；
- 能启动 PostgreSQL 容器或本地实例，使用 `psql`/数据库客户端；
- 了解表、行、列的直觉概念，但不假设掌握关系模型；
- FactoryCare 有一份最小设备/工单练习数据。

## 目标

- 使用 DDL/DML 建表、插入、更新和删除练习数据；
- 写 `SELECT`、表达式、别名、过滤、排序、分页和去重；
- 正确处理 NULL 与三值逻辑；
- 使用 INNER/LEFT JOIN 并识别重复行与错误连接；
- 使用聚合、`GROUP BY`、`HAVING` 和条件聚合；
- 理解子查询、`EXISTS`、CTE、集合运算和窗口函数；
- 使用参数而不是拼接避免 SQL 注入；
- 根据结果集、行数和测试证明查询符合业务问题。

## 完整概念清单

### 关系与 SQL 基础

- database/schema/table/row/column/type；
- SQL 是声明式语言，描述结果而不是逐行执行算法；
- 标识符、关键字、字符串/数字/日期/布尔字面量；
- DDL、DML、DQL、DCL/TCL 的高层分类；
- 语句结束符、注释、格式化和事务客户端行为；
- PostgreSQL 大小写折叠与带引号标识符陷阱。

### 查询与表达式

- `SELECT` 列、表达式、`AS` 别名；生产查询避免无边界 `SELECT *`；
- `FROM`、`WHERE`、比较、`BETWEEN`、`IN`、`LIKE/ILIKE`；
- `AND/OR/NOT` 优先级和括号；
- `CASE`、`COALESCE`、`NULLIF`、类型转换；
- `DISTINCT` 的语义与掩盖错误 JOIN 的风险；
- `ORDER BY` 多列、NULL 排序、稳定分页；
- `LIMIT/OFFSET` 和大偏移问题只建立概念，游标分页后续实现。

### NULL 与三值逻辑

- NULL 表示未知/缺失，不等于 0 或空字符串；
- `= NULL` 不成立，使用 `IS NULL/IS NOT NULL`；
- TRUE/FALSE/UNKNOWN 对 `WHERE` 的影响；
- 聚合通常忽略 NULL，`COUNT(*)` 与 `COUNT(column)` 不同；
- `NOT IN` 遇到 NULL 的陷阱，必要时使用 `NOT EXISTS`；
- 是否允许 NULL 应由业务与约束决定，不靠默认习惯。

### JOIN

- INNER、LEFT、RIGHT/FULL 了解、CROSS；
- 主表/被连接表只是阅读视角，不改变关系语义；
- `ON` 与 `WHERE` 对外连接结果的差异；
- 一对多导致行数扩张，不应随便 `DISTINCT`；
- 多列连接、别名、自连接；
- 漏写条件导致笛卡尔积，连接到非唯一列导致重复；
- 先预测基数，再执行并统计行数。

### 聚合与逻辑顺序

- `COUNT/SUM/AVG/MIN/MAX`；
- `GROUP BY` 决定结果粒度；
- `WHERE` 过滤行，`HAVING` 过滤分组；
- 条件聚合 `COUNT(*) FILTER (WHERE ...)` 或 `CASE`；
- 逻辑处理顺序：`FROM/JOIN → WHERE → GROUP BY → HAVING → SELECT → DISTINCT → ORDER BY → LIMIT`；
- 别名能否在不同子句使用取决于处理阶段和数据库实现；
- 分组列与非聚合选择列必须语义一致。

### 子查询、CTE、集合与窗口

- scalar/list/correlated subquery 的高层概念；
- `EXISTS/NOT EXISTS` 表达存在性；
- CTE 用于分步表达，不自动更快；
- `UNION` 去重、`UNION ALL` 保留，INTERSECT/EXCEPT 概念；
- 窗口函数不压缩行：`OVER(PARTITION BY ... ORDER BY ...)`；
- `row_number`、`rank/dense_rank`、分组累计和前一行 `lag`；
- 复杂查询优先先保证语义正确，再到 Week 14 分析性能。

### 数据修改与安全

- `INSERT` 多行、`RETURNING`；
- `UPDATE/DELETE` 必须先用相同 `WHERE` 做 SELECT 预览；
- 忘记 WHERE 的灾难与事务/备份边界；
- 参数化查询与 SQL 注入；
- 唯一/外键/检查约束在 Week 13 系统建立；
- 批量、upsert、MERGE 只做基础实验，不替代清晰业务规则。

## 时间与任务

| 任务 | 时间 | 产出 |
| --- | ---: | --- |
| SELECT/NULL | 2—3h | 20 个小查询和结果预测 |
| JOIN/基数 | 3h | 一对多、LEFT JOIN 和错误连接实验 |
| 聚合/HAVING | 2—3h | 工单分类、技师负载与状态统计 |
| 子查询/CTE/窗口 | 2—3h | 最新事件、排名、累计和存在性查询 |
| DML/参数安全 | 2h | 可回滚更新删除和注入反例 |
| FactoryCare SQL 包 | 3—4h | 15 条命名查询、数据集和结果断言 |

## FactoryCare 查询清单

- 查询启用设备并按创建时间倒序；
- 统计每个分类的启用设备，筛选至少 3 台；
- 查询每个技师未关闭工单数；
- 找出没有任何工单的设备；
- 找出每个设备最新工单；
- 按月和类别统计关闭工单与平均处理时长；
- 找出超过 SLA 且仍未关闭的工单；
- 为状态/时间/技师组合建立稳定排序分页结果；
- 至少一个错误 JOIN、错误 NULL 判断和错误 HAVING 的红灯用例。

## 无 AI 任务（120 分钟）

给定表结构与种子数据，完成 8 条查询：2 条过滤排序、2 条 JOIN、2 条聚合/HAVING、1 条 `NOT EXISTS`、1 条窗口函数。提交 SQL、每条业务问题、预期行数/关键值和实际结果；不得只提交截图。

## 验收

- 能口述逻辑查询顺序并解释为何 SELECT 别名不能随处使用；
- 能区分 `COUNT(*)`、`COUNT(column)` 与 NULL；
- 能预测 INNER/LEFT JOIN 的行数变化；
- 能判断 `WHERE` 与 `HAVING` 的责任；
- 能安全演示 UPDATE/DELETE 的预览与回滚；
- 15 条 FactoryCare SQL 在可重置数据集上结果正确。

## 非目标

- 不深入索引、查询计划、锁或 ORM；
- 不背 PostgreSQL 全部函数；
- 不同时兼容 MySQL/PostgreSQL 两套生产 SQL；
- 不通过 AI 生成 SQL 后只看是否执行成功。
