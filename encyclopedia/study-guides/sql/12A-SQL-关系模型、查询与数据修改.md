# SQL：关系模型、查询与数据修改

## 1. 数据库不是一堆电子表格

在关系数据库中，数据被组织成一组关系。实际使用时，一个关系通常表现为一张表：

```text
work_order
┌────────┬──────────┬────────────┐
│ id     │ device_id │ status     │
├────────┼──────────┼────────────┤
│ WO-1   │ DEV-8     │ OPEN       │
│ WO-2   │ DEV-8     │ COMPLETED  │
└────────┴──────────┴────────────┘
```

通俗地说：

- 表描述某一类事实；
- 一行是其中一个事实；
- 一列是每个事实共有的一项属性；
- 列的类型和约束规定什么数据可以进入。

但关系模型比电子表格严格：表不依赖“第几行”表达身份，行的默认顺序也没有契约意义。要识别一行需要键，要得到稳定顺序需要 `ORDER BY`。

SQL 是声明式语言：你主要说明“要什么结果”，数据库优化器再选择“怎样获得结果”。

## 2. 主键让每个事实可被稳定识别

主键（primary key）用来唯一识别表中的一行。它必须唯一，也不能是 `NULL`。

```sql
CREATE TABLE work_order (
    id bigint PRIMARY KEY,
    title text NOT NULL
);
```

主键不是单纯为了“查询快”。它先表达身份：后续表才能用外键指向这个事实，应用也才能明确更新哪一行。

一个表可能还有其他唯一标识，例如设备编码。它们可以用 `UNIQUE` 约束表达，但只有一组被选为主键。

## 3. 外键表达两类事实之间的引用

一张工单属于某台设备，可用 `device_id` 指向 `device.id`：

```text
device             work_order
id ◀────────── device_id
```

数据库的外键约束能保证：如果 `work_order.device_id` 有值，被指向的设备行必须存在。这叫**参照完整性**。

外键的方向由业务事实决定。通常是“多”的一端保存指向“一”的一端的外键：一台设备有多张工单，因此工单行保存 `device_id`。

数据表设计会在后面专篇展开。这里先建立一个原则：先用业务句子说清关系和数量，再决定键放在哪里。

## 4. psql 是与 PostgreSQL 交互的客户端

PostgreSQL 数据库服务器和 `psql` 是两个东西：

```text
psql 客户端 ──连接──▶ PostgreSQL 服务器 ──读写──▶ 数据库文件
```

`psql` 可以发送 SQL，也提供一些以反斜杠开头的客户端命令：

```text
\l          列出数据库
\c name     连接数据库
\dt         列出可见表
\d table    查看表结构
\i file.sql 执行 SQL 文件
\q          退出 psql
```

`\dt` 不是 SQL，离开 `psql` 不一定能用。而 `SELECT ...` 是发给数据库服务器的 SQL。

连接时需要明确主机、端口、数据库、用户和认证方式。“数据库运行了”不代表“当前用户连到了正确数据库和 schema”。

## 5. schema 是数据库内的名称空间

同一个 PostgreSQL 数据库里可以有多个 schema，不同 schema 里可有同名表：

```text
factorycare database
  ├── public.work_order
  └── audit.work_order
```

完全名称是 `schema.table`。只写 `work_order` 时，PostgreSQL 会按 `search_path` 查找。如果查到了意外的同名对象，不要只怀疑数据“丢了”，先确认当前数据库、schema 和 `search_path`。

## 6. SELECT 从行集合中产生新结果

最小查询：

```sql
SELECT id, status
FROM work_order;
```

`FROM` 提供原始行集合，`SELECT` 选择结果中要出现的列或表达式。这个动作叫**投影（projection）**。

```sql
SELECT id,
       status,
       labor_hours * hourly_rate_cents AS labor_cost_cents
FROM work_order;
```

`AS` 给结果列起别名，不会修改表的真实列名。

在应用查询中尽量明确列名，而不是长期依赖 `SELECT *`。表新增列后，`*` 会改变结果形状、增加网络传输，也可能意外取出敏感数据。

## 7. WHERE 只保留条件为 true 的行

```sql
SELECT id, status
FROM work_order
WHERE status = 'OPEN';
```

`WHERE` 是对原始行集合做过滤。多个条件可以用 `AND`、`OR`、`NOT` 组合：

```sql
SELECT id, priority
FROM work_order
WHERE status = 'OPEN'
  AND (priority >= 4 OR machine_stopped = true);
```

`AND` 和 `OR` 有运算优先级，但业务条件一旦混合二者，使用括号明确意图通常更安全。

匹配范围：

```sql
WHERE priority BETWEEN 3 AND 5
```

`BETWEEN` 的两端通常都包含。匹配集合：

```sql
WHERE status IN ('OPEN', 'ASSIGNED')
```

模式匹配：

```sql
WHERE title LIKE 'Pump%'
```

`%` 表示任意长度字符，`_` 表示一个字符。它们不是正则表达式的全部语法。

## 8. NULL 表示缺失或未知，不是普通值

SQL 中的 `NULL` 不等于 `0`、空字符串或字符串 `'null'`。它表示当前没有这个值，或该值未知。

不能用普通相等比较它：

```sql
-- 错误思路
WHERE assignee_id = NULL

-- 正确表达
WHERE assignee_id IS NULL
```

SQL 逻辑中除了 `TRUE` 和 `FALSE`，还有 `UNKNOWN`。例如 `NULL = 3` 不是 false，而是 unknown。`WHERE` 只保留结果为 true 的行，false 和 unknown 都会被过滤。

这叫**三值逻辑**。它对 `NOT IN`、否定条件和外连接影响很大。

### 8.1 COALESCE 选择第一个非 NULL 值

```sql
SELECT id,
       COALESCE(assignee_id, 'UNASSIGNED') AS assignee
FROM work_order;
```

`COALESCE` 可用于输出显示或有明确默认语义的计算。但不要随意把所有 `NULL` 都替换为空字符串或 0，因为这可能把“未知”伪装成一个真实值。

## 9. SQL 的书写顺序和逻辑处理顺序不同

查询通常按这个顺序书写：

```sql
SELECT ...
FROM ...
WHERE ...
GROUP BY ...
HAVING ...
ORDER BY ...
LIMIT ...;
```

理解名称和可用范围时，可以用这个简化的逻辑顺序：

```text
FROM / JOIN     准备行
WHERE           过滤原始行
GROUP BY        分组
HAVING          过滤组
SELECT          计算输出列
ORDER BY        排序
LIMIT/OFFSET    取其中一段
```

这不是数据库引擎必须按物理步骤逐个执行，优化器可以改变执行策略。它是用来理解 SQL 语义的心智模型。

## 10. 标量函数对每行产生一个值

字符串处理：

```sql
SELECT upper(status), length(title)
FROM work_order;
```

时间处理：

```sql
SELECT id,
       created_at,
       created_at + interval '4 hours' AS due_at
FROM work_order;
```

条件计算：

```sql
SELECT id,
       CASE
           WHEN priority = 5 THEN 'CRITICAL'
           WHEN priority >= 3 THEN 'ATTENTION'
           ELSE 'NORMAL'
       END AS priority_label
FROM work_order;
```

`CASE` 是 SQL 表达式，不是 Java 那样包住整个语句块的控制流。它会为当前行计算一个结果值。

函数和表达式可以放在 `SELECT`、`WHERE`、`ORDER BY` 等位置，但在被索引列外面包函数可能影响普通索引的使用。性能问题要用执行计划验证，不要只凭函数名猜。

## 11. ORDER BY 才给结果一份顺序契约

```sql
SELECT id, priority, created_at
FROM work_order
ORDER BY priority DESC, created_at ASC, id ASC;
```

- `ASC`：升序，也是默认方向；
- `DESC`：降序；
- 前一个排序键相同时，才看下一个键。

没有 `ORDER BY` 时，即使当前查询连续十次都显示相同顺序，数据库也没有承诺下一次仍然相同。索引、统计信息、并行计划或数据变化都可以改变返回顺序。

分页时排序尤其要稳定，最后常加一个唯一键打破平局。

## 12. LIMIT/OFFSET 只取结果的一段

```sql
SELECT id, created_at
FROM work_order
ORDER BY created_at DESC, id DESC
LIMIT 20 OFFSET 40;
```

这表示在完整排序结果中跳过 40 行，再取 20 行。它简单直观，但 offset 很大时，数据库仍往往要找到并跳过前面大量行。

基于上一页最后排序键的 keyset/cursor 分页可能更稳定高效：

```sql
SELECT id, created_at
FROM work_order
WHERE (created_at, id) < (:lastCreatedAt, :lastId)
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

两种方式的选择取决于是否需要跳页、数据变化频率和数据量。

## 13. INSERT 创建新行

```sql
INSERT INTO device (id, code, name)
VALUES (101, 'PUMP-01', 'Cooling Pump');
```

明确写列名比依赖表当前列顺序更安全。批量插入可以在一条语句中提供多组值。

PostgreSQL 的 `RETURNING` 能直接返回本次写入后的列：

```sql
INSERT INTO work_order (device_id, title, status)
VALUES (101, 'Inspect cooling pump', 'OPEN')
RETURNING id, created_at;
```

这能取得数据库生成的 ID、时间或默认值，不需要再用一条模糊条件查回。

## 14. UPDATE 修改选中的行

```sql
UPDATE work_order
SET status = 'COMPLETED',
    completed_at = current_timestamp
WHERE id = 9001
  AND status = 'IN_PROGRESS'
RETURNING id, status, completed_at;
```

`WHERE` 决定哪些行被改动。遗漏 `WHERE` 会修改全表。因此在手工操作重要数据前，常先用同样条件 `SELECT` 查看目标行，并在事务中执行与确认。

上面的条件不只用 ID，还要求当前状态是 `IN_PROGRESS`。如果影响行数是 0，可能表示工单不存在，也可能表示状态已被其他操作改变。应用必须正确解释影响行数，不能只看 SQL 没抛异常就认定更新成功。

## 15. DELETE 也必须有明确范围

```sql
DELETE FROM work_order
WHERE id = 9001
RETURNING id;
```

遗漏 `WHERE` 会删除全表所有行。实际业务中还要决定：

- 记录是否真的允许物理删除；
- 是否要保留审计和法律记录；
- 关联外键应阻止、级联，还是转为 `NULL`；
- 软删除后所有查询是否都正确过滤。

“增加 `deleted` 字段”不是零成本方案。它会影响唯一约束、索引、每个查询和数据保留规则。

## 16. UPSERT 在唯一冲突时选择更新

PostgreSQL 可使用 `ON CONFLICT`：

```sql
INSERT INTO device (code, name)
VALUES ('PUMP-01', 'Cooling Pump')
ON CONFLICT (code)
DO UPDATE SET name = EXCLUDED.name
RETURNING id, code, name;
```

`EXCLUDED.name` 表示本来尝试插入的新值。UPSERT 需要一个可判定冲突的唯一约束或索引。

不要把所有字段都无条件覆盖。例如数据库已有的创建时间、内部状态或所有者可能是不应由这个写入边界更改的字段。

UPSERT 解决的是一条写入在唯一冲突下的原子选择，不会自动解决业务幂等的所有问题。

## 17. 参数不应通过字符串拼接进入 SQL

应用需要把用户输入交给 SQL 时，应使用参数绑定：

```sql
SELECT id, title
FROM work_order
WHERE status = ?;
```

不要将原始输入拼进语句：

```text
"SELECT ... WHERE status = '" + userInput + "'"
```

参数绑定会把 SQL 结构和数据值分开，能防止输入逃出字符串并改写查询结构。这是防止 SQL 注入的基本边界。

表名、列名和 `ASC/DESC` 等 SQL 结构通常不能当作普通值参数绑定。对外部传入的排序字段应用白名单映射到固定 SQL 片段，不是改回字符串拼接。

## 18. 这篇的整体地图

```text
关系表达一类事实
  ├── 主键：识别一行
  └── 外键：连接两类事实

SELECT 产生行集合
  ├── FROM：数据来源
  ├── WHERE：只保留 true 的行
  ├── SELECT：选择或计算列
  ├── ORDER BY：建立顺序契约
  └── LIMIT/OFFSET：取一段结果

INSERT / UPDATE / DELETE / UPSERT 修改数据
  ├── 参数绑定保护 SQL 结构
  ├── WHERE 和约束界定范围
  └── affected rows / RETURNING 证明真实结果
```

必须牢固理解：`NULL` 有三值逻辑；没有 `ORDER BY` 就没有顺序保证；写操作没抛错不等于真的修改了预期行。
