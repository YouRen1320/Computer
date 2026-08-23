# PostgreSQL：建模、约束、类型与迁移

## 1. 建表的目标是保存业务事实和规则

数据库建模不是把 Java 类或页面表单机械复制成表。应先用业务语言说清系统中有哪些事实：

- 设备有稳定身份、编码和名称；
- 工单针对一台设备创建；
- 一张工单有状态、优先级和创建时间；
- 技师可以被指派处理多张工单；
- 工单状态变化需要审计历史。

再把这些事实转成表、键和约束：

```text
device 1 ──< work_order >── 0..1 technician
                     │
                     └──< work_order_event
```

好模型要同时支持三件事：

1. 合法业务事实能被准确保存；
2. 明显不合法的数据在尽可能靠近数据的地方被拒绝；
3. 常用查询和变更能以可控成本进行。

## 2. DDL 改变数据库结构

DDL 是 **Data Definition Language**，也就是定义表、列、约束、索引等数据库结构的 SQL。常见命令包括：

- `CREATE`：创建对象；
- `ALTER`：修改已有对象；
- `DROP`：删除对象；
- `TRUNCATE`：快速清空表内行，但保留表本身。

一个简化工单表：

```sql
CREATE TABLE work_order (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    device_id bigint NOT NULL,
    title text NOT NULL,
    status text NOT NULL,
    priority smallint NOT NULL,
    created_at timestamptz NOT NULL DEFAULT current_timestamp
);
```

DDL 往往会影响现有数据、锁和正在运行的应用，因此它不只是开发环境里的表设计，也是一个发布和兼容性问题。

## 3. 主键、唯一约束与业务身份

主键是数据库选定的行身份：

```sql
id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY
```

`IDENTITY` 可让数据库生成递增数字。内部主键稳定，但它不会自动防止两台设备拥有同一业务编码：

```sql
CREATE TABLE device (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code text NOT NULL UNIQUE,
    name text NOT NULL
);
```

`code` 是业务上不允许重复的候选键，所以还需要 `UNIQUE`。仅在 Java Service 中先查“不存在”再插入，两个并发请求仍可能同时通过查询。最终唯一性必须由数据库约束作为最后防线。

如果唯一性由多列共同决定，可定义复合约束：

```sql
CONSTRAINT uk_work_order_tenant_number
    UNIQUE (tenant_id, order_number)
```

这表示工单号只需在各自租户内唯一，不是全平台唯一。

## 4. NOT NULL 与 DEFAULT 解决不同问题

```sql
status text NOT NULL DEFAULT 'OPEN'
```

- `NOT NULL` 表示最终存储的值不能是 SQL `NULL`；
- `DEFAULT 'OPEN'` 表示插入时没有为该列提供值，就使用 `'OPEN'`。

默认值不会在客户端明确插入 `NULL` 时自动替换它；`NOT NULL` 会拒绝该行。

默认值应有清楚业务含义。不要为了逃避 `NULL` 就给未知日期填 `1970-01-01`，或给未指派技师填一个假 ID。虚假值会参与统计和关联，比明确缺失更难处理。

## 5. CHECK 约束保护单行内可表达的规则

```sql
priority smallint NOT NULL,
CONSTRAINT ck_work_order_priority
    CHECK (priority BETWEEN 1 AND 5)
```

跨列规则也可以表达：

```sql
CONSTRAINT ck_work_order_completion
CHECK (
    (status = 'COMPLETED' AND completed_at IS NOT NULL)
    OR
    (status <> 'COMPLETED' AND completed_at IS NULL)
)
```

CHECK 适合根据当前行数据判定、且数据库不应允许任何写入路径违反的规则。

不要用 CHECK 隐藏依赖其他表当前数据的复杂业务查询。跨行、跨表不变条件通常需要外键、唯一约束、更合适的模型、事务或专门机制。

## 6. 外键要同时设计删除语义

```sql
CONSTRAINT fk_work_order_device
FOREIGN KEY (device_id)
REFERENCES device(id)
ON DELETE RESTRICT
```

常见删除策略：

- `RESTRICT` / `NO ACTION`：存在引用时拒绝删除被引用行；
- `CASCADE`：被引用行删除时，连带删除引用行；
- `SET NULL`：将外键设为 `NULL`，前提是列允许 `NULL`。

这不是技术喜好。删除设备时，历史工单是应被阻止、一起删除，还是保留但断开关联？三种都可能有业务影响。对审计数据使用 `CASCADE` 尤其要谨慎。

为约束起稳定名字会让数据库错误更容易映射到业务错误，也方便迁移中明确删除或替换对象。

## 7. 基数是一端能对应多少个另一端

常见关系：

```text
一对一：一张工单最多一份关闭报告
一对多：一台设备有多张工单
多对多：工单和标签彼此都可对应多个
```

一对一通常通过外键加唯一约束实现：

```sql
work_order_id bigint NOT NULL UNIQUE
    REFERENCES work_order(id)
```

多对多通过中间表实现：

```sql
CREATE TABLE work_order_tag (
    work_order_id bigint NOT NULL REFERENCES work_order(id),
    tag_id bigint NOT NULL REFERENCES tag(id),
    PRIMARY KEY (work_order_id, tag_id)
);
```

不要用逗号分隔字符串保存多对多 ID。数据库无法对其中每个 ID 施加外键，查询、更新和去重也都会变脆弱。

## 8. 宽表为什么会产生数据异常

假设把设备、工单和技师全部放在一张表：

```text
work_order_id | device_id | device_name | technician_id | technician_phone | ...
```

同一台设备每有一张工单，设备名称就重复一次。同一技师的电话也会在多行重复。这会引出：

- **更新异常**：技师电话需要修改多行，改不全就互相矛盾；
- **插入异常**：没有工单时，可能无法单独登记一个技师；
- **删除异常**：删掉技师唯一的工单，技师自身资料也被意外删掉。

根本原因是一张表同时保存多种独立事实。

## 9. 函数依赖帮助找出事实的键和边界

如果在一个关系中，属性 X 的值能唯一决定属性 Y，可写作：

```text
X → Y
```

例如：

```text
device_id → device_code, device_name
technician_id → technician_name, technician_phone
work_order_id → device_id, status, priority, created_at
```

“能决定”指业务规则，不是当前样例数据恰好没重复。两个设备当前恰好同名，不代表设备名能决定设备身份。

候选键是能唯一决定一行所有属性、且不含多余属性的最小属性组。主键是从候选键中选出的一个。

## 10. 规范化是根据依赖拆分事实

规范化不是“表越多越好”。它用函数依赖判断一张表中是否混入了多个不同的事实，然后将它们拆到各自合理的关系中。

### 10.1 第一范式（1NF）

在当前关系模型中，每个列位置存放一个当前类型可理解的值，不把“电话1,电话2,电话3”或逗号列表塞在一列。原子性取决于使用方式：一个完整邮箱地址可以是一个值，而需要独立查询的多个标签通常是多个事实。

### 10.2 第二范式（2NF）

在复合候选键的表中，非键属性不应只依赖键的一部分。

例如中间表键是 `(work_order_id, tag_id)`，如果还放入 `tag_name`，它只由 `tag_id` 决定，应属于 `tag` 表。

### 10.3 第三范式（3NF）

非键属性不应再通过另一个非键属性间接依赖于键。

例如：

```text
work_order_id → technician_id → technician_phone
```

`technician_phone` 是技师的事实，不是工单的事实，应放在 `technician`。

对业务系统，能清楚解释到 3NF 通常已能解决大量常见设计错误。更高范式需要时查询，不用在初次建模时机械背诵。

## 11. 拆分后要保证能无损还原事实

一个宽表被拆分后，通过键连接应能重建原本的合法事实，且不产生凭空的组合。这叫**无损连接**。

同时，重要业务依赖最好能在分解后的局部表中通过键或约束维护，这叫**依赖保持**。

如果为了规范化拆出一批无法用清晰业务概念命名、每次校验都需要大量连接的表，应回到函数依赖和业务事实重新检查，而不是追求表数量。

## 12. 反规范化是有证据的权衡

为了性能、历史快照或查询简化，有时会有意重复一些数据。这叫**反规范化（denormalization）**。

例如工单创建时保存一份“当时的设备显示名称”，可能是为了保留历史语义，而不是偶然复制。但需要明确：

- 哪份数据是权威来源；
- 重复值何时更新，还是永不更新；
- 可接受多久的不一致；
- 用什么指标证明重复值真的必要。

反规范化应是基于瓶颈证据的显式决策，不是因为 JOIN 看起来麻烦就提前复制一切。

## 13. PostgreSQL 数值类型要符合范围和语义

常见整数类型有 `smallint`、`integer`、`bigint`。金额可以根据契约选择：

- 用 `bigint` 保存最小货币单位，例如分，并与 Java `long` 一致；
- 用 `numeric(precision, scale)` 保存固定精度小数。

不要用二进制浮点类型保存需要精确对账的金额。但“所有金额都用 numeric”也不是脱离应用契约的绝对规则：需要一致考虑单位、范围、四舍五入和语言映射。

## 14. text、varchar 和长度规则

PostgreSQL 中 `text` 与不限长的 `varchar` 在存储能力和性能上通常没有需要为日常业务设计纠结的差别。`varchar(50)` 的主要意义是增加最大长度约束。

如果“最多 50 个字符”是真实业务规则，可以明确约束。如果 50 只是当前 UI 宽度或随意数字，就不应让数据层被假规则锁住。

`char(n)` 会补空格，一般不是保存普通业务字符串的默认选择。

## 15. 时间类型需要区分“时刻”和“墙上时间”

- `date`：一个日历日期；
- `time`：一天中的时间；
- `timestamp without time zone`：一个没有时区解释的本地日期时间；
- `timestamp with time zone` / `timestamptz`：表达时间线上的一个确定时刻。

工单创建于哪个时刻，通常使用 `timestamptz`。每天当地时间 08:30 执行保养，则需要另外保留地区时区规则，只存一个 UTC 时刻不能表达未来每天的本地时间计划。

`timestamptz` 存储的是时刻，查询显示时会按当前 session 时区表示。同一时刻显示成不同当地时间，不代表数据被改了。

## 16. UUID 在分布生成和对外 ID 中很常见

UUID 是 128 位标识符，可以在不中央分配递增数字的情况下生成。PostgreSQL 有原生 `uuid` 类型，应优先用它，而不是用 `text` 保存 UUID 字符串。

与递增 `bigint` 相比：

- UUID 便于多端或多服务独立生成，不容易直接猜测数量；
- 随机 UUID 对 B-tree 写入局部性和索引体积不如窄而递增的整数；
- UUID 更大，作为外键会被多次存储；
- 递增 ID 不是权限机制，换成 UUID 也不会自动防止越权。

PostgreSQL 18 提供了时间有序 UUIDv7 的原生生成支持，它在保留 UUID 分布生成优势的同时，能改善与时间相关的排序和索引局部性。这是版本相关能力，在实际项目基线上需要查当前官方文档。

## 17. enum、CHECK 和查找表各有边界

工单状态可能有几种存储方式：

```text
text + CHECK        值简单，迁移和约束直接
PostgreSQL enum     数据库类型本身限制值集
status 查找表      状态还有显示名、顺序、配置等数据
```

PostgreSQL enum 能强类型限制，但添加、改名和特别是删除枚举值需要谨慎迁移。如果状态值频繁可配置，或它们自身有许多属性，查找表更合适。

无论选哪种，业务状态转换不会只靠“当前值在允许集合中”就被完整保护。从 `COMPLETED` 是否能回到 `OPEN` 是状态机规则，会在领域模型和事务边界中处理。

## 18. JSONB 适合可扩展属性，不是免建模通行证

`jsonb` 可以保存结构化 JSON，并支持查询和索引。它适合：

- 不同设备类型拥有不同、且低频访问的扩展属性；
- 保留外部系统输入的原始快照；
- 结构可变但仍需要数据库内查询的附加信息。

不适合随意放进 JSONB 的数据：

- 需要外键保证的关联 ID；
- 频繁过滤、排序、聚合的核心字段；
- 有明确非空、唯一、范围规则的业务属性；
- 独立生命周的子实体列表。

JSONB 内的 JSON `null`、键缺失和 SQL `NULL` 是不同状态。如果不定义契约，查询很容同时面对三种“没值”。

## 19. 数组类型适合整体附属于一行的值集合

PostgreSQL 数组可保存同类型多个值：

```sql
tags text[] NOT NULL DEFAULT '{}'
```

它适合数量有界、整体随父行生命周期变化、不需要每个元素有外键或独立属性的值。

如果标签有独立 ID、颜色、权限，或需要查询“所有使用该标签的工单”并维护参照完整性，中间表往往更清晰。

“PostgreSQL 支持数组”不代表所有一对多关系都应塞进一行。

## 20. domain 用来复用数据库值规则

PostgreSQL domain 可以在基础类型上增加名称和约束：

```sql
CREATE DOMAIN priority_level AS smallint
CHECK (VALUE BETWEEN 1 AND 5);
```

后续多张表可共用 `priority_level`。它适合在数据库内多处真正共享的值语义，不要为每个列都建一个仅改名、却没有共享规则的 domain。

使用 ORM/MyBatis 和数据库驱动时，还需要确认自定义类型的 JDBC 映射和迁移支持。

## 21. ALTER 表时必须考虑存量数据

在已有数据的表上增加必填列：

```sql
ALTER TABLE work_order
ADD COLUMN tenant_id bigint NOT NULL;
```

如果表中已经有行，这些行没有 `tenant_id`，迁移会失败，或在某些变体下需要危险的伪默认值。

更安全的渐进过程：

```text
1. Expand：先增加可空列，新代码开始写入
2. Backfill：分批为旧行回填真实 tenant_id
3. Verify：确认不再有 NULL，新旧程序都可工作
4. Contract：增加 NOT NULL/外键，后续再删旧结构
```

这叫 **expand–backfill–contract**。它的价值是让数据结构和应用代码可以分阶段兼容，而不是要求所有服务、数据和约束在一个无限快的瞬间一起改完。

## 22. 迁移脚本把 schema 变更变成版本历史

只在本地数据库工具里手动点击改表，团队不知道变更顺序，新环境也无法从空库重建。迁移工具将每一次变更写成进入版本管理的脚本：

```text
V1__create_device.sql
V2__create_work_order.sql
V3__add_work_order_priority.sql
```

它们组成从空库到当前结构的可执行历史。

版本迁移的基本语义是：每个版本按顺序执行一次，执行结果、时间和 checksum 记录在 schema history 中。

## 23. 已发布迁移不应被原地改写

假设 V2 已在测试和生产环境执行，后来直接修改 V2：

```text
新建环境：执行修改后的 V2
已有环境：历史中仍是旧 V2
```

两种环境从此不再拥有同一段历史。Flyway 用 checksum 检测这类变化。正常解法是增加 V3 做向前修正，而不是消除历史证据。

`repair` 可以修复 schema history 的某些状态或对齐 checksum，但它不是“迁移冲突后总是点一下”的常规命令。使用它前必须理解哪个环境实际执行过什么，否则只是把检测器的记录改到不再报错。

## 24. 版本迁移、可重复迁移与 baseline

- **Versioned migration**：有唯一版本，按顺序执行一次，适合表、列、数据修正等历史变更；
- **Repeatable migration**：没有数字版本，内容 checksum 变化时重新执行，常用于可重建的视图或函数；
- **Baseline**：对已存在且不能从最早历史重跑的数据库，建立一个开始受迁移管理的已知版本。

Baseline 不是忽略当前 schema 是否正确，也不是将新建数据库的完整测试取消。它是将存量数据库纳入迁移管理的显式起点。

## 25. 迁移必须验证两条路径

```text
空库路径：无任何表 → 执行全部迁移 → 当前 schema

升级路径：上一个已发布版本 + 真实旧数据
          → 执行本次新迁移
          → 新代码可用且数据保留
```

只在空库成功，不能证明 `ALTER` 和回填对生产数据安全。只在一个开发库升级成功，也不能证明新环境可以从零建立。

大表回填需要考虑批次、锁、WAL、复制延迟、失败后继续位置和新旧代码兼容。这些是发布设计的一部分，不只是 SQL 语法。

## 26. 向前修复与应用回滚要分开设计

应用 JAR 可以切回上一版，数据库变更却可能已经修改了真实数据，不适合简单反向执行。

主流策略是：

- 迁移尽量使用扩展式、向后兼容的步骤；
- 上线错误时先决定是回滚应用，还是发布新迁移向前修复；
- 危险的删列、改含义和数据清理延后到确认旧代码已退出后再做；
- 破坏性变更前有备份、恢复演练和可检查的回滚条件。

“迁移工具能执行 SQL”不等于“迁移工具会替你判断业务数据是否可以恢复”。

## 27. 这篇的整体地图

```text
业务事实与基数
  ↓
表、主键、外键与唯一约束
  ↓
用 NOT NULL / CHECK / 类型关闭非法状态
  ↓
用函数依赖和规范化分离不同事实
  ↓
根据语义选择 UUID、时间、JSONB、数组等 PostgreSQL 类型
  ↓
用版本迁移将结构从旧状态演进到新状态
  ↓
在空库和真实升级路径上验证
```

必须掌握的原则是：数据库约束是所有写入路径共享的最后防线；规范化的目标是分离事实和减少异常，不是追求表数；已发布迁移是历史，新问题用新迁移向前修复。
