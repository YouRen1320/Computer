# Spring：MyBatis、Flyway 与事务边界

## 1. 持久化是从业务对象到数据库的完整边界

应用要保存工单，不是只需要“写一条 SQL”。完整路径包括：

```text
Application Service
  ↓ 调用业务端口
WorkOrderRepository
  ↓ 转换业务对象和数据行
MyBatis Mapper
  ↓ 绑定参数、执行 SQL、映射结果
JDBC
  ↓ 通过连接和数据库协议交互
PostgreSQL
```

每层负责不同问题：

- Repository 表达业务需要的持久化能力；
- MyBatis 让 SQL 和映射可被明确编写；
- JDBC 是 Java 与关系数据库交互的标准 API；
- DataSource 和连接池管理数据库连接；
- Spring 事务将一个用例中的多次数据访问放在共同提交边界；
- Flyway 保证代码所期待的 schema 有可追踪演进历史。

了解这些分层，是为了在错误时知道哪一层的契约被破坏，不是为了给一次 CRUD 强行堆很多类。

## 2. JDBC 是 Java 数据访问的底层共同模型

JDBC 中最重要的对象链：

```text
DataSource
  ↓ getConnection()
Connection
  ↓ prepareStatement(sql)
PreparedStatement
  ↓ executeQuery() / executeUpdate()
ResultSet 或影响行数
```

MyBatis、Spring JDBC 和大部分 Java 关系数据访问库最终都建立在这个模型上。即使代码里不直接出现 JDBC 类，理解连接、语句、结果集和事务属于谁，仍然能帮助定位连接泄漏和事务错位。

## 3. DataSource 提供连接，Connection 代表一个数据库会话

`DataSource` 是获取数据库连接的抽象。它可以在内部创建物理连接，也可以从连接池借出一个。

`Connection` 不只是一根网络线的引用。它承载当前数据库会话和事务状态：

- 是否自动提交；
- 当前事务隔离级别；
- 已执行但尚未提交的变更；
- session 级配置、临时表和某些服务器状态。

同一事务内的所有 SQL 必须参与同一个事务资源。如果方法内每条 SQL 都自己新建连接并自动提交，它们不会因为在同一个 Java 方法里就自动成为一个数据库事务。

## 4. PreparedStatement 将 SQL 结构和数据参数分开

```java
String sql = """
        SELECT id, status, priority
        FROM work_order
        WHERE tenant_id = ? AND id = ?
        """;

try (PreparedStatement statement = connection.prepareStatement(sql)) {
    statement.setLong(1, tenantId);
    statement.setLong(2, workOrderId);
    // execute...
}
```

`?` 只代表一个数据值，不代表表名、列名、SQL 关键字或整个条件片段。用类型匹配的 setter 绑定值，驱动再按数据库协议传输。

这避免外部值逃出字符串边界改变 SQL 结构，也减少日期、布尔和数字的手工格式化错误。

动态排序列不能用 `?` 绑定，需要把外部值映射到已知白名单：

```text
"createdAt" → "created_at"
"priority"  → "priority"
其他值     → 拒绝
```

只能在白名单产生的固定 SQL 片段中选择，不要直接拼接客户端字符串。

## 5. ResultSet 是带有游标位置的查询结果

```java
try (ResultSet resultSet = statement.executeQuery()) {
    while (resultSet.next()) {
        long id = resultSet.getLong("id");
        String status = resultSet.getString("status");
    }
}
```

`ResultSet` 初始位置在第一行之前，需要先调用 `next()` 移到一行。查单条时也不能直接读列：

```java
if (!resultSet.next()) {
    return Optional.empty();
}
```

SQL `NULL` 与 Java 基本类型映射要特别注意。例如 `getLong()` 在 SQL `NULL` 时可返回 0，需要配合 `wasNull()` 或选用可表达缺失的目标类型。否则“未指派”可能被静默映射成技师 ID 0。

## 6. 资源关闭是所有权责任

JDBC 的 `ResultSet`、`Statement` 和 `Connection` 都需要关闭。直接 JDBC 代码常用 try-with-resources：

```java
try (Connection connection = dataSource.getConnection();
     PreparedStatement statement = connection.prepareStatement(sql)) {
    // ...
}
```

但在 Spring 事务内，当前线程可能由事务管理器绑定一个 Connection，MyBatis/Spring 集成负责参与它。如果业务代码手工关闭、提交或另外开一个无关连接，就可能破坏 Spring 管理的边界。

“谁获得资源，谁负责释放”需要结合框架所有权：应用使用 Spring 管理的 Mapper 时，不要越过集成层自己操作 SqlSession 生命周期。

## 7. JDBC 事务的底层形状

不使用 Spring 时，JDBC 事务大致是：

```java
Connection connection = dataSource.getConnection();
try {
    connection.setAutoCommit(false);
    // 多条 SQL 共用 connection
    connection.commit();
} catch (Exception exception) {
    connection.rollback();
    throw exception;
} finally {
    connection.close();
}
```

默认 auto-commit 模式下，每条语句完成后自动提交。想让多条 SQL 共同成功，必须在同一 Connection 上关闭 auto-commit，并在失败时 rollback。

这段底层模型解释了为什么 Spring `@Transactional` 需要事务管理器、DataSource 和当前调用上下文的协作，而不是一个只改注解状态的标签。

## 8. 连接池复用昂贵的物理连接

建立数据库连接需要 TCP、TLS/认证和服务器 session 资源。每条 SQL 都新建并销毁物理连接，成本高且会压垮数据库。

连接池维护一组可复用连接：

```text
请求线程 ──借──▶ 连接池 ──选一个可用连接──▶ PostgreSQL
            ◀─还──
```

对池化 Connection 调用 `close()` 通常表示归还池，而不是立即关闭底层物理连接。所以“不 close 可以复用”恰好是错误想法：不归还会让池逐渐耗尽。

## 9. 连接池不是越大越快

如果应用实例有 10 个，每个连接池最大 50，数据库可能面对 500 个连接。每个连接占用服务器资源，大量并发 SQL 也会争抢 CPU、内存和 I/O。

池大小需要结合：

- 应用实例数；
- 数据库可承担连接和并发查询数；
- 每个请求持有连接的时间；
- 流量峰值与允许的等待时间；
- 后台任务、迁移和管理工具的连接需求。

常用观测信号：活跃连接、空闲连接、等待者数、获取耗时、获取超时、连接最长持有时间。池耗尽可能由 SQL 慢、锁等待、长事务或连接泄漏引起，不要只把最大连接数调大。

## 10. MyBatis 是 SQL Mapper，不是将 SQL 隐藏掉的全自动 ORM

MyBatis 让开发者显式编写 SQL，然后将 Java 参数绑定进 SQL，再将查询列映射为 Java 对象。

Mapper 接口：

```java
interface WorkOrderMapper {
    WorkOrderRow findByTenantAndId(long tenantId, long id);
}
```

XML 映射示意：

```xml
<select id="findByTenantAndId" resultMap="workOrderRowMap">
    SELECT id, tenant_id, device_id, status, priority, version
    FROM work_order
    WHERE tenant_id = #{tenantId}
      AND id = #{id}
</select>
```

MyBatis 不会替你决定 JOIN 是否放大行数、索引是否合适、租户条件是否遗漏，或事务应该从哪里开始。它主要解决“明确 SQL 如何与 Java 方法和对象对应”。

## 11. `#{}` 和 `${}` 的区别是安全边界

```xml
WHERE status = #{status}
```

`#{status}` 会使用 PreparedStatement 参数绑定，值不会变成 SQL 结构。

```xml
ORDER BY ${sortColumn}
```

`${sortColumn}` 是原始文本替换。如果值来自用户，可以改写 SQL，造成注入。它只能用于不能参数化的结构位置，且替换值必须在进入 Mapper 前已映射成程序内部的可信白名单。

简单记法：

```text
#{...} → 字段值，默认选择
${...} → SQL 文本片段，高风险且必须信任来源
```

## 12. 多参数方法要有稳定名称

Java 字节码中的参数名是否保留受编译配置影响。为了让 Mapper SQL 中参数名清楚稳定，可显式命名：

```java
WorkOrderRow findByTenantAndId(
        @Param("tenantId") long tenantId,
        @Param("id") long id
);
```

或使用一个有名输入对象承载多个条件。这比在 XML 中依赖 `param1`、`param2` 更容易维护。

参数占位符拼写错误通常在语句被执行时才暴露，因此关键 Mapper 需要与真实数据库进行集成测试。

## 13. 结果映射要明确列名与 Java 属性的关系

列名和属性名不同时，可使用别名：

```sql
SELECT created_at AS createdAt
FROM work_order
```

或定义 `resultMap`：

```xml
<resultMap id="workOrderRowMap" type="WorkOrderRow">
    <id property="id" column="id"/>
    <result property="tenantId" column="tenant_id"/>
    <result property="createdAt" column="created_at"/>
</resultMap>
```

`resultMap` 能明确 ID、普通列、构造参数和嵌套结果。但要警惕将一个巨大 JOIN 的重复行映射成复杂对象图：如果一张工单连接 5 条事件和 4 个标签，结果可能先扩张成 20 行，然后才在 Java 中折叠。

这时需要重新审查查询语义，而不是只修改映射注解。

## 14. 动态 SQL 组装可选条件

```xml
<select id="search" resultMap="workOrderRowMap">
    SELECT id, tenant_id, status, priority, created_at
    FROM work_order
    <where>
        tenant_id = #{tenantId}
        <if test="status != null">
            AND status = #{status}
        </if>
        <if test="minimumPriority != null">
            AND priority &gt;= #{minimumPriority}
        </if>
    </where>
    ORDER BY created_at DESC, id DESC
</select>
```

`<where>` 会在内部有条件时添加 `WHERE`，并帮助处理开头多余 `AND/OR`。`<set>` 对动态 `UPDATE` 列有类似作用。

动态 SQL 的风险是参数组合会增加路径。每个 `<if>` 单独看都正确，组合后可能产生空 `IN ()`、遗漏租户条件或无界全表查询。测试应覆盖有意义的条件组合和空集语义，不用机械枚举所有布尔组合。

## 15. 批量查询与 N+1 问题

先查到 100 张工单，再在循环中为每张查设备：

```text
1 条工单列表查询
+ 100 条设备查询
= 101 条 SQL
```

这就是常说的 N+1 查询问题。在开发样例只有 3 行时不明显，数据增长后网络往返、查询解析和连接占用会成为瓶颈。

常见解法：

- 在合适基数下用 JOIN 一次查取；
- 先收集不同 ID，用 `IN`/数组参数批量查询，再在内存组合；
- 为特定列表页建立直接返回所需字段的查询 DTO；
- 不在不需要详细信息的路径加载整个关联图。

解法需要同时检查 JOIN 是否放大行数。从 101 条 SQL 改成一条返回百万重复行的 SQL，不是真正优化。

## 16. Repository 用业务语言隔离持久化细节

领域或应用层定义需要的端口：

```java
public interface WorkOrderRepository {
    Optional<WorkOrder> findById(TenantId tenantId, WorkOrderId id);
    void insert(WorkOrder workOrder);
    boolean updateIfVersionMatches(WorkOrder workOrder);
}
```

MyBatis 适配器实现它：

```text
WorkOrderRepository 业务端口
       ↑ 实现
MyBatisWorkOrderRepository
       ↓
WorkOrderMapper + WorkOrderRow
```

这使上层不需要知道 MyBatis `resultMap`、表名和数据库异常。Repository 方法应围绕用例需要，而不是机械将每条 SQL 暴露成一个通用 CRUD 方法。

### 16.1 数据行对象与领域对象可以分开

`WorkOrderRow` 反映查询列和可空性，`WorkOrder` 反映业务不变条件和行为。适配器在两者之间转换。

不是每个项目都必须为每张表复制一对类。当数据结构和业务模型很简单且稳定时，可以减少层次。但不要让 MyBatis DTO 直接流进所有业务层和 API，否则一个列改名会同时变成数据、业务和 HTTP 契约变更。

## 17. 租户和权限条件必须在查询边界强制

多租户系统查工单：

```sql
SELECT ...
FROM work_order
WHERE tenant_id = #{tenantId}
  AND id = #{id}
```

不应只用 ID 查到对象后，再在 Java 中检查租户，因为届时越权数据已经被加载，也容易有某个新调用者忘记二次检查。

同时，不要依赖开发者在每条 Mapper SQL 中人工记住增加条件。后续安全章会展开统一查询模式、组合键、PostgreSQL RLS 等多层防护。这里先牢记：数据访问端口必须带足身份和范围上下文。

## 18. 异常需要跨边界转换，但不能丢 cause

数据库可能报告唯一冲突、外键冲突、超时、死锁、连接失败等。上层不应依赖 PostgreSQL 驱动的具体异常类，Spring 的数据访问异常转换会提供更稳定的类别。

适配器还可以将确定约束冲突映射为应用错误：

```text
uk_device_tenant_code 冲突
  → DeviceCodeAlreadyExists
  → Web 层映射 409 Problem Details
```

但不要只根据数据库英文 message 的一段文字做脆弱匹配。优先使用 SQLState、约束名和结构化信息。包装异常时保留 cause，否则诊断链会在最需要的地方中断。

## 19. Flyway 必须在应用使用 schema 前完成迁移

应用代码期待 `work_order.version` 存在，但数据库还没执行对应迁移，第一个请求就会失败。启动顺序应明确：

```text
创建 DataSource
  ↓
Flyway 连接数据库并 validate/migrate
  ↓
schema 达到代码期待版本
  ↓
MyBatis Mapper / Repository 开始对外提供数据访问
  ↓
应用 readiness 表示可接收流量
```

迁移和应用使用的 DataSource 应指向同一目标数据库和 schema。如果 Flyway 在数据库 A 成功，应用却连数据库 B，日志中的“迁移成功”不能证明应用目标已就绪。

## 20. Spring 声明式事务依赖代理边界

```java
@Service
class WorkOrderApplicationService {

    @Transactional
    public WorkOrderId create(CreateWorkOrderCommand command) {
        // 创建工单
        // 保存初始事件
        return id;
    }
}
```

外部通过 Spring 代理调用 `create()` 时，代理可以：

```text
方法前：获取/加入事务，将资源绑定到当前执行上下文
方法成功：提交
方法抛出符合回滚规则的异常：回滚
最后：释放/归还资源
```

如果对象是自己 `new` 的、方法不能被当前代理方式拦截，或调用是同类内部自调用，只写 `@Transactional` 不代表事务一定生效。

## 21. 事务通常应放在完整应用用例边界

如果每个 Repository 方法各自开一个事务：

```text
repository.insertWorkOrder()    → 已提交
repository.insertAuditEvent()   → 失败回滚自己
```

工单仍然留下，用例不变条件被破坏。更合适的边界是 Application Service 的“创建工单”用例，它包住所有必须共同提交的 Repository 调用。

Controller 上开事务可能让 JSON 序列化、远程调用和其他协议逻辑都处于连接和锁持有时间中。用例服务通常是更清晰的事务入口。

## 22. self-invocation 会绕过事务代理

```java
@Service
class ImportService {

    public void importAll(List<Item> items) {
        for (Item item : items) {
            importOne(item); // 目标对象内部直接调用
        }
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void importOne(Item item) {
        // ...
    }
}
```

`importAll()` 内调用 `importOne()` 没有再经过外层 Spring 代理，因此 `REQUIRES_NEW` 可能不生效。

更可理解的设计是把“每项独立事务”放在另一个 Bean，由批量编排器外部调用它。这同时使事务语义和类责任更清楚。

## 23. 传播行为决定内层方法怎样处理已有事务

### 23.1 REQUIRED

默认且最常用：当前已有事务就加入，没有就创建新事务。

```text
外层事务 T1 → 内层 REQUIRED 仍参与 T1
```

内层将共同事务标记为 rollback-only 后，外层即使捕获了异常，最终提交仍可能失败。捕获 Java 异常不会自动恢复已被标记回滚的数据库事务。

### 23.2 REQUIRES_NEW

暂停外层事务，为内层开一个独立事务：

```text
外层 T1 暂停
    └── 内层 T2 独立提交或回滚
恢复 T1
```

它会需要另一个事务连接，小连接池和高并发下可能互相等连接。更重要的是，T2 一旦提交，T1 后来回滚也不会撤销 T2。只在业务真的允许独立提交时使用，不要用来“修好事务注解没生效”。

### 23.3 NESTED

在支持的事务管理器与资源上，常通过 savepoint 表达局部回滚。它仍处于外层物理事务中，不等于另一个已独立提交的事务。

其他传播选项需要时查官方文档。实际项目中大部分用例使用 REQUIRED，少量场景才需要明确的新事务或 savepoint 语义。

## 24. 默认回滚规则不是“所有 Exception 都回滚”

Spring 声明式事务默认通常对 `RuntimeException` 和 `Error` 回滚，对普通受检异常不自动回滚。

如果业务方法用受检异常表示必须撤销的失败，需要显式配置：

```java
@Transactional(rollbackFor = ImportException.class)
```

更重要的是统一异常策略：哪些是可恢复业务冲突，哪些是基础设施失败，哪些必须回滚。不要在每个方法上随机堆 `rollbackFor = Exception.class`，否则会掩盖异常语义不清。

### 24.1 吞掉异常可能让事务被当成成功

```java
@Transactional
public void create(...) {
    try {
        repository.insert(...);
    } catch (RuntimeException exception) {
        log.error("insert failed", exception);
        // 方法正常返回
    }
}
```

如果异常没有继续抛出，代理可能看到方法正常结束并尝试提交。如果失败已使事务 rollback-only，最后则可能以意外回滚异常结束。记录日志不等于处理了失败。

## 25. isolation、readOnly 和 timeout 都是事务语义的一部分

```java
@Transactional(
        isolation = Isolation.REPEATABLE_READ,
        readOnly = true,
        timeout = 5
)
```

- `isolation` 描述并发可见性和冲突边界；
- `readOnly` 是只读意图和可用的优化/保护提示，具体强制程度与数据库和驱动有关；
- `timeout` 限制事务可以执行多久。

不要只因为查询方法叫 `find...` 就认定整个调用链无写入。也不要为了解决某个并发 bug 就全局调高隔离级别。先定义当前用例需要保护的不变条件，再选择原子更新、乐观版本、显式锁或隔离。

## 26. 数据库提交不能原子撤回外部副作用

下面的时序很危险：

```text
1. 向邮件服务发送“工单已指派”
2. 数据库 UPDATE 失败并回滚
```

用户收到邮件，数据库却没有指派记录。把发邮件放到事务方法中，不会让远程服务参与 PostgreSQL 回滚。

可以在提交后执行只有成功后才应发生的操作，但还有一个窗口：数据库已提交，进程在发消息前崩溃。要可靠保证最终发送，后面会使用 Outbox：业务数据和待发事件在同一数据库事务写入，再由独立发布器重试外部发送。

## 27. 持久化错误的分层定位

```text
应用启动失败
  → DataSource 连接、凭据、Flyway 迁移、Bean 组装

Mapper 方法第一次执行失败
  → SQL 语法、表/列版本、参数名、类型、resultMap

更新无异常但业务未改
  → WHERE 条件、租户/ID/版本、影响行数是否被忽略

部分数据已提交
  → 事务边界、代理/self-invocation、传播、手工新连接

压力下请求卡住
  → 连接池等待、慢 SQL、锁等待、长事务、泄漏
```

打开 SQL 日志可以帮助看语句和耗时，但生产中不应无限记录完整敏感参数。数据库侧的活动查询、锁和执行计划，需要与应用 trace/request ID 对齐。

## 28. 集成测试要验证真实边界

使用真实 PostgreSQL Testcontainer 的持久化测试应关注：

- Flyway 能从空库执行；
- PostgreSQL 特有类型、约束和 SQL 正确；
- MyBatis 参数和结果映射正确；
- 租户条件和软删除等必需谓词没遗漏；
- 乐观锁更新会检查影响行数；
- 唯一和外键冲突被映射为预期错误；
- 用例中途失败时，必须共同提交的数据全部回滚；
- 需要 after-commit 的行为不会在测试自动回滚中被假象遮蔽。

只 mock Mapper 只能证明 Service 按预期调用了一个 Java 接口，不能证明 SQL、迁移、约束和事务真正正确。

## 29. 当前技术版本的名称要说准确

本学习路线当前的 MyBatis 核心版本仍属于 3.5.x 系列；与 Spring Boot 4.x 对应的 MyBatis Spring Boot Starter 和 MyBatis-Spring 集成层可以是 4.x。“Starter 4.x”不等于“MyBatis 核心已经变成 4.x”。

这类版本会变化的信息在真正进入 Week 15 或升级项目时，要根据 Spring Boot 的依赖管理、MyBatis 官方文档和兼容表重新确认，不要从旧博客随机复制版本组合。

## 30. 这篇的整体地图

```text
Flyway 先将 schema 迁移到代码期待版本
  ↓
DataSource / 连接池提供受控数据库连接
  ↓
Spring 事务代理在用例边界绑定资源
  ↓
Repository 以业务语言提供持久化端口
  ↓
MyBatis Mapper 使用 #{} 参数、显式 SQL 和 resultMap
  ↓
JDBC 在当前 Connection/事务中执行
  ↓
PostgreSQL 用类型、约束、锁和 MVCC 保护数据
```

必须牢固掌握的边界：

1. `#{}` 是值绑定，`${}` 是高风险文本替换；
2. Repository 不应将 MyBatis 和数据表结构泄露到所有上层；
3. 事务边界应对齐一个必须共同成功的应用用例；
4. `@Transactional` 常依赖代理，自调用、异常吞掉和传播选择都会改变结果；
5. 数据库事务无法撤回已发出的邮件或网络请求，外部副作用需要另外的可靠传递设计。
