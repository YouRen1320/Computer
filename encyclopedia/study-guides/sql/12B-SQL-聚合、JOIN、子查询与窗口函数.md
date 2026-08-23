# SQL：聚合、JOIN、子查询与窗口函数

## 1. 这些功能都在重新组织行集合

基础 `SELECT` 从一张表过滤和选择行。真实报表会提出更复杂的问题：

- 每种状态有多少张工单；
- 每张工单对应哪台设备；
- 哪些设备从未有过工单；
- 哪些工单的优先级高于全部平均值；
- 每台设备最新的三张工单是哪些。

它们分别需要分组聚合、表连接、存在性判断、子查询和窗口函数。不要把它们记成独立语法展示；每个功能都是在回答“输入行怎样变成输出行”。

## 2. 聚合函数把多行缩成一个结果

常见聚合函数：

```sql
SELECT count(*) AS order_count,
       min(priority) AS min_priority,
       max(priority) AS max_priority,
       avg(priority) AS average_priority,
       sum(labor_hours) AS total_labor_hours
FROM work_order;
```

如果没有 `GROUP BY`，整个输入行集合就是一组，因此结果通常只有一行。

### 2.1 count(*) 和 count(column) 不完全相同

- `count(*)` 计算行数；
- `count(assignee_id)` 只计算 `assignee_id` 不是 `NULL` 的行；
- `count(DISTINCT assignee_id)` 计算不同非 `NULL` 值数量。

假设有 10 张工单，3 张未指派，其余由 2 名技师处理：

```text
count(*)                      = 10
count(assignee_id)            = 7
count(DISTINCT assignee_id)   = 2
```

不先明确要数“行”还是“有值的字段”，就容易产生看似合理的错数。

### 2.2 大部分聚合函数会忽略 NULL

`sum(hours)` 和 `avg(hours)` 通常忽略 `NULL` 行，它们不会自动把缺失值当作 0。是否应当将缺失解释为 0，必须由业务语义决定。

空输入集上，`count(*)` 返回 0，而很多其他聚合返回 `NULL`。这也是统计 API 需要明确空集语义的原因。

## 3. GROUP BY 先分组，再对每组聚合

按工单状态统计：

```sql
SELECT status, count(*) AS order_count
FROM work_order
GROUP BY status
ORDER BY status;
```

执行概念：

```text
所有工单行
  ↓ 按 status 分组
OPEN 组      ASSIGNED 组      COMPLETED 组
  ↓ count      ↓ count          ↓ count
每组产生一行结果
```

分组查询的 `SELECT` 中，普通列必须能由当前组唯一决定，一般需要出现在 `GROUP BY` 中；其他输出应通过聚合函数产生。

```sql
-- title 在一个 status 组内可能有很多个值，不能随便挑一个
SELECT status, title, count(*)
FROM work_order
GROUP BY status;
```

数据库拒绝这种模糊选择，是在迫使查询说清结果的基数。

## 4. WHERE 过滤原始行，HAVING 过滤聚合后的组

查看今年且工单数至少 10 张的设备：

```sql
SELECT device_id, count(*) AS order_count
FROM work_order
WHERE created_at >= date_trunc('year', current_date)
GROUP BY device_id
HAVING count(*) >= 10;
```

- `WHERE` 在分组前删掉不属于今年的工单行；
- `HAVING` 在每台设备已统计后，删掉数量小于 10 的组。

可以在 `WHERE` 完成的原始行条件，不要都塞到 `HAVING`。这不仅语义更清楚，也能在聚合前减少需处理的行。

## 5. JOIN 根据条件组合两个行集合

查询工单和设备名称：

```sql
SELECT wo.id,
       wo.status,
       d.code AS device_code,
       d.name AS device_name
FROM work_order AS wo
JOIN device AS d ON d.id = wo.device_id;
```

`wo` 和 `d` 是表别名。两张表有同名列时，`wo.id` 明确表示工单 ID，`d.id` 明确表示设备 ID。

JOIN 最需要关注的不是关键字，而是组合后的行数。对工单的每一行，有多少设备行能匹配？

```text
工单一行 × 匹配的设备行数 = JOIN 产生的行数
```

如果用本应唯一却没有唯一约束的设备编码连接，一张工单可能匹配多台设备，结果就被复制。`DISTINCT` 可能暂时遮住重复，却不会修复错误的连接基数。

## 6. INNER JOIN 只保留两边能匹配的行

`JOIN` 不写其他修饰时，通常就是 `INNER JOIN`：

```text
左边有且右边也有 → 保留
任何一边没匹配       → 不保留
```

如果外键不允许 `NULL` 且参照完整性正常，每张工单都应匹配一台设备。若连接后工单变少，可能是 JOIN 条件错了，或数据约束未真正保证模型。

## 7. LEFT JOIN 保留左边的每一行

查看所有设备，包括没有工单的设备：

```sql
SELECT d.id, d.code, wo.id AS work_order_id
FROM device AS d
LEFT JOIN work_order AS wo ON wo.device_id = d.id;
```

当某台设备没有匹配工单时，它的行仍被保留，右边 `wo.*` 的列用 `NULL` 表示没有匹配。

查找没有工单的设备：

```sql
SELECT d.id, d.code
FROM device AS d
LEFT JOIN work_order AS wo ON wo.device_id = d.id
WHERE wo.id IS NULL;
```

### 7.1 ON 和 WHERE 的位置会改变外连接含义

想保留所有设备，但只连接未完成工单：

```sql
SELECT d.id, wo.id
FROM device AS d
LEFT JOIN work_order AS wo
  ON wo.device_id = d.id
 AND wo.status <> 'COMPLETED';
```

如果把右表条件移到 `WHERE`：

```sql
...
LEFT JOIN work_order AS wo ON wo.device_id = d.id
WHERE wo.status <> 'COMPLETED';
```

没有匹配的设备行上，`wo.status` 是 `NULL`，比较结果是 unknown，会被 `WHERE` 过滤。这就丧失了“保留所有左表行”的效果。

## 8. 多对多关系通过中间表连接

一张工单可有多个标签，一个标签也属于多张工单：

```text
work_order ──< work_order_tag >── tag
```

中间表每行表达一次“这张工单有这个标签”的关系：

```sql
SELECT wo.id, t.name
FROM work_order AS wo
JOIN work_order_tag AS wot ON wot.work_order_id = wo.id
JOIN tag AS t ON t.id = wot.tag_id;
```

中间表通常需要限制 `(work_order_id, tag_id)` 唯一，防止同一关系被重复记录。如果关系本身还有添加人、添加时间等属性，它就更明显地是一类独立事实。

## 9. 自连接用同一张表的不同角色建立关系

员工表中的 `manager_id` 可指向另一个员工：

```sql
SELECT employee.name AS employee_name,
       manager.name AS manager_name
FROM employee
LEFT JOIN employee AS manager ON manager.id = employee.manager_id;
```

同一张表在查询中出现两次，必须用别名表达两个角色。这不代表数据库将表物理复制了一份。

## 10. 子查询是放在另一条 SQL 中的查询

查找优先级高于全局平均值的工单：

```sql
SELECT id, priority
FROM work_order
WHERE priority > (
    SELECT avg(priority)
    FROM work_order
);
```

内层查询产生一个平均值，外层每行再与它比较。只返回一行一列的子查询可当作一个值，叫**标量子查询**。如果它意外返回多行，用 `=` 比较就会失败。

子查询不只能放在 `WHERE`，也可以作为 `FROM` 中的行集合或 `SELECT` 中的标量表达式。选择 JOIN 还是子查询时，先以语义清楚为主，性能要看优化后的真实执行计划。

## 11. EXISTS 关心是否至少有一行

查找至少有一张开放工单的设备：

```sql
SELECT d.id, d.code
FROM device AS d
WHERE EXISTS (
    SELECT 1
    FROM work_order AS wo
    WHERE wo.device_id = d.id
      AND wo.status = 'OPEN'
);
```

内层查询引用了外层的 `d.id`，这叫**关联子查询**。`EXISTS` 只关心有没有行，`SELECT 1` 中的 1 不会成为最终结果。

查找没有工单的设备：

```sql
SELECT d.id, d.code
FROM device AS d
WHERE NOT EXISTS (
    SELECT 1
    FROM work_order AS wo
    WHERE wo.device_id = d.id
);
```

`NOT EXISTS` 往往比 `NOT IN (subquery)` 更容易正确处理 `NULL`。如果 `NOT IN` 的集合中出现 `NULL`，三值逻辑可能让所有比较都无法得到 true。

## 12. CTE 给复杂查询的中间行集合起名

CTE 用 `WITH` 声明：

```sql
WITH open_orders AS (
    SELECT id, device_id, priority
    FROM work_order
    WHERE status = 'OPEN'
),
device_summary AS (
    SELECT device_id,
           count(*) AS open_count,
           max(priority) AS max_priority
    FROM open_orders
    GROUP BY device_id
)
SELECT d.code, s.open_count, s.max_priority
FROM device_summary AS s
JOIN device AS d ON d.id = s.device_id;
```

CTE 的首要价值是把查询拆成有名字的概念步骤，让每步的输出行语义更清楚。

它不是必然的性能优化。现代 PostgreSQL 可以在条件允许时将 CTE 合并进外层优化，某些情况也会物化它。需要时查当前版本文档和执行计划，不要使用旧版本的一句规则套用所有 CTE。

## 13. 集合运算组合两个相容查询结果

```sql
SELECT device_id AS entity_id, 'DEVICE' AS entity_type
FROM device
UNION ALL
SELECT technician_id AS entity_id, 'TECHNICIAN' AS entity_type
FROM technician;
```

两个查询必须产生相同数量、类型相容的列。列是按位置对应，不是按别名自动配对。

- `UNION` 会去重；
- `UNION ALL` 保留重复，通常也更省去重成本；
- `INTERSECT` 保留两边共有的行；
- `EXCEPT` 保留左边有、右边没有的行。

业务上允许重复时，不要为了“结果干净”下意识用 `UNION`。去重会改变结果含义。

## 14. 窗口函数计算相关行，但不把它们合并成一行

`GROUP BY` 会将每组多行缩成一行。窗口函数保留原始每一行，同时为它计算一个基于相关行集合的值。

为每张工单同时显示该设备的工单数：

```sql
SELECT id,
       device_id,
       status,
       count(*) OVER (PARTITION BY device_id) AS device_order_count
FROM work_order;
```

```text
GROUP BY device_id
  → 每台设备一行

count(*) OVER (PARTITION BY device_id)
  → 每张工单仍有一行，但多一列设备工单数
```

`OVER (...)` 就是它成为窗口函数的关键。

## 15. PARTITION BY 分窗口，ORDER BY 定义窗口内顺序

给每台设备的工单按创建时间编号：

```sql
SELECT id,
       device_id,
       created_at,
       row_number() OVER (
           PARTITION BY device_id
           ORDER BY created_at DESC, id DESC
       ) AS position
FROM work_order;
```

- `PARTITION BY device_id`：每台设备开始一个新分区；
- `ORDER BY created_at DESC, id DESC`：定义分区内先后顺序；
- `row_number()`：按该顺序给每行唯一序号。

不加唯一的次排序键时，相同时间的两行谁先谁后可能不稳定。

### 15.1 row_number、rank 和 dense_rank

并列成绩可以用不同排名语义：

```text
值        100  90  90  80
row_number    1   2   3   4
rank          1   2   2   4
dense_rank    1   2   2   3
```

- `row_number()` 每行都不同；
- `rank()` 并列后会跳号；
- `dense_rank()` 并列后不跳号。

不是哪个函数更好，而是业务如何定义并列。

## 16. 用窗口函数取每组前 N 条

窗口函数的结果通常需要在外层再过滤：

```sql
WITH ranked_orders AS (
    SELECT id,
           device_id,
           created_at,
           row_number() OVER (
               PARTITION BY device_id
               ORDER BY created_at DESC, id DESC
           ) AS position
    FROM work_order
)
SELECT id, device_id, created_at
FROM ranked_orders
WHERE position <= 3;
```

这取得每台设备最新三张工单。如果直接在同层 `WHERE position <= 3`，按 SQL 逻辑顺序，`WHERE` 处理时该窗口结果尚未产生。CTE 或子查询为窗口计算和后续过滤建立了两层。

## 17. 窗口框架决定当前行看到哪些同窗口行

计算运行累计值：

```sql
SELECT occurred_at,
       cost_cents,
       sum(cost_cents) OVER (
           ORDER BY occurred_at, id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_total_cents
FROM maintenance_cost;
```

这个 frame 表示从分区开头到当前行。滑动平均可以定义只看当前行与前几行。

有 `ORDER BY` 的窗口聚合会涉及默认 frame，而 `ROWS`、`RANGE` 对排序值相同的 peer rows 可有不同语义。当结果依赖精确边界时，应显式写 frame，不要依赖没理解的默认值。

## 18. lag 和 lead 访问前后行

计算相邻状态事件的时间间隔：

```sql
SELECT work_order_id,
       occurred_at,
       occurred_at - lag(occurred_at) OVER (
           PARTITION BY work_order_id
           ORDER BY occurred_at, id
       ) AS elapsed_since_previous
FROM work_order_event;
```

`lag` 取按窗口顺序的前一行，`lead` 取后一行。分区第一行没有前一行，`lag` 通常返回 `NULL`。

这类函数很适合时序事件差值、状态变化和同比/环比计算。

## 19. 复杂 SQL 应先写清每一步的行语义

遇到大查询时，不要一次把 JOIN、GROUP BY、子查询和窗口全堆起来。可以先用自然语言说清：

1. 起始一行代表什么；
2. 连接后一行又代表什么；
3. 每一次连接可能把行扩张多少；
4. 哪些条件过滤原始行，哪些条件过滤聚合结果；
5. 是要把一组压成一行，还是保留每一行并附加统计；
6. 最终的唯一性和排序是什么。

每增加一层就暂时查看少量行、关键键和计数，比最后发现总额翻了十倍后再猜更可靠。

## 20. 这篇的概念地图

```text
输入行集合
  ├── JOIN：根据关系组合行，要审查基数
  ├── GROUP BY + 聚合：每组多行压成一行
  ├── 子查询 / EXISTS：用另一个结果做值或存在性判断
  ├── CTE：给中间行集合起名并分步表达
  ├── 集合运算：纵向组合相容结果
  └── 窗口函数：保留原始行，附加组内计算
```

必须掌握的边界是：JOIN 可以放大行数；`WHERE` 和 `HAVING` 过滤的阶段不同；`GROUP BY` 会改变结果行数，窗口函数不会；任何需要稳定顺序的排名和分页都应有可打破平局的唯一排序键。
