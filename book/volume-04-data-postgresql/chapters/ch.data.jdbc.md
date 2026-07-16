---
schema_version: 2
edition: 2026.2-draft
id: ch.data.jdbc
title: DataSource、PreparedStatement、ResultSet 与 JDBC 事务边界
responsibility: 教授 Java 直接访问关系数据库的资源和参数边界，不在本章引入连接池框架或 ORM
volume: '04'
order: 16
level: L2
status: drafting
path: book/volume-04-data-postgresql/chapters/ch.data.jdbc.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.java-engineering.maven-reproducible-builds
- ch.java-engineering.io-resource-lifecycle
- ch.data.transactions-locking
version_surfaces:
- jdk-25
- maven-3
- jdbc
- postgresql-18
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释DataSource、PreparedStatement、ResultSet 与 JDBC 事务边界的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - jdbc-query-resource
  - jdbc-transaction-error
  covers_topics:
  - jdbc.datasource-connection
  - jdbc.prepared-statement
  - jdbc.result-set-mapping
  - jdbc.parameter-binding
  - jdbc.transaction-boundary
  - jdbc.sql-exception-translation
  uses_capabilities:
  - data.relational-schema
  - data.sql-query
  - data.transactions-locks
  - java.exceptions-resources
  - java.build-testing
  - data.persistence-access
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：用 DataSource/PreparedStatement 查询并更新工单，显式绑定参数、映射 ResultSet、关闭资源和控制事务提交
  covers_topic_groups:
  - jdbc-query-resource
  - jdbc-transaction-error
  covers_topics:
  - jdbc.datasource-connection
  - jdbc.prepared-statement
  - jdbc.result-set-mapping
  - jdbc.parameter-binding
  - jdbc.transaction-boundary
  - jdbc.sql-exception-translation
  uses_capabilities:
  - data.relational-schema
  - data.sql-query
  - data.transactions-locks
  - java.exceptions-resources
  - java.build-testing
  - data.persistence-access
  evidence_kind: integration-artifact-and-tests
  verification_mode: framework-or-container-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入字符串拼 SQL、漏 close、列类型映射错和异常后未 rollback，利用日志/数据库状态修复
  covers_topic_groups:
  - jdbc-query-resource
  - jdbc-transaction-error
  covers_topics:
  - jdbc.datasource-connection
  - jdbc.prepared-statement
  - jdbc.result-set-mapping
  - jdbc.parameter-binding
  - jdbc.transaction-boundary
  - jdbc.sql-exception-translation
  uses_capabilities:
  - data.relational-schema
  - data.sql-query
  - data.transactions-locks
  - java.exceptions-resources
  - java.build-testing
  - data.persistence-access
  evidence_kind: integration-failure-fix-rerun
  verification_mode: integration-fault-rerun
---
# DataSource、PreparedStatement、ResultSet 与 JDBC 事务边界

> 本章状态为 `drafting`。稳定核心是资源所有权、参数与 SQL 结构分离、显式映射和事务失败边界；JDK **25** JDBC API、当前 pgJDBC 文档及 PostgreSQL **18** SQLSTATE 于 **2026-07-17** 核对。本机未运行 Java/pgJDBC/PostgreSQL 集成，资产以接口合同和离线状态机验证。离线 PASS 不证明驱动类型转换、网络、资源归还或数据库事务已真实发生。

## 1. JDBC 是 Java 与数据库之间的显式协议

JDBC 不替你生成领域模型，也不隐藏 SQL。它提供一组接口，让 Java 程序完成：

```text
DataSource 获取 Connection
Connection 创建 PreparedStatement
PreparedStatement 绑定参数并执行
ResultSet 游标逐行读取
Connection 提交或回滚
所有资源按所有权关闭
SQLException 提供 SQLState 等诊断证据
```

本章故意不引入连接池框架、Spring JDBC、MyBatis 或 ORM。先看清最小边界，后续框架才能被验证，而不是成为魔法。

### 完成标准

学习者应能：

- 解释 `DataSource`、`Connection`、`PreparedStatement`、`ResultSet` 各自职责；
- 通过构造器注入 `DataSource`，不把 URL/密码散落在 repository；
- 用 `?` 占位符绑定不可信值，证明注入字符不能改变 SQL 结构；
- 知道参数只能代表值，不能替代列名、表名或排序方向；
- 显式选择 Java/SQL 类型和 NULL 绑定方式；
- 正确移动 ResultSet 游标并把 SQL NULL 映射到可空 Java 类型；
- 用 `Optional.empty()` 表示按唯一键无结果；
- 用 try-with-resources 关闭 ResultSet、Statement、Connection；
- 关闭 auto-commit 后明确 commit/rollback；
- 检查 `executeUpdate` 影响行数；
- 根据 SQLState 分类约束冲突、死锁和序列化失败并保留 cause；
- 注入 SQL 拼接、资源泄漏、错类型和漏 rollback 后定位第一证据。

## 2. 四个对象，一条所有权链

### 2.1 DataSource：连接工厂

JDK 25 API 将 `DataSource` 描述为连接到物理数据源的连接工厂，并把它列为相对 `DriverManager` 的首选方式。业务 repository 只依赖接口：

```java
public final class JdbcWorkOrderRepository {
    private final DataSource dataSource;

    public JdbcWorkOrderRepository(DataSource dataSource) {
        this.dataSource = Objects.requireNonNull(dataSource);
    }
}
```

这样测试或启动代码决定具体数据源，repository 不知道密码来源、主机切换或将来是否有池。`DataSource` 不自动等于连接池：实现可以是基础物理连接、池参与者或分布式事务实现。本章只使用基础语义。

启动边界可配置 pgJDBC 的 `PGSimpleDataSource`，但凭据来自环境/秘密管理，不写进 Git：

```java
var ds = new PGSimpleDataSource();
ds.setServerNames(new String[] {host});
ds.setPortNumbers(new int[] {port});
ds.setDatabaseName(database);
ds.setUser(user);
ds.setPassword(password);
```

具体 pgJDBC 类属于驱动适配层；repository 字段仍声明为 `javax.sql.DataSource`。

### 2.2 Connection：数据库会话与事务控制面

`Connection` 代表一条数据库连接。它携带 auto-commit、隔离级别、只读、schema 等会话状态，并创建 statement。Connection 不是线程安全共享的全局单例；一个业务事务的语句必须使用同一个 Connection。

### 2.3 PreparedStatement：固定 SQL 结构与参数槽

```sql
SELECT work_order_id, status, assigned_to, created_at, version
FROM factorycare.work_order
WHERE work_order_id = ?
```

SQL 结构固定，参数 1 在执行前绑定。PreparedStatement 不保证驱动一定提前在服务器编译；其关键合同是参数化执行与类型绑定，不能把“prepared”简单等同于性能缓存。

### 2.4 ResultSet：位于当前行之前的游标

ResultSet 初始游标在第一行之前。必须先调用 `next()`；返回 false 表示没有更多行。默认 ResultSet 通常只读、向前移动。读取列后映射成 Java 值，不应把 ResultSet 逃逸到已关闭 Connection 之外。

## 3. 固定 FactoryCare 映射合同

数据库列：

```sql
CREATE TABLE factorycare.work_order (
  work_order_id bigint PRIMARY KEY,
  status text NOT NULL,
  assigned_to bigint,
  created_at timestamptz NOT NULL,
  version bigint NOT NULL
);
```

Java 值：

```java
public record WorkOrderRow(
        long workOrderId,
        String status,
        Long assignedTo,
        OffsetDateTime createdAt,
        long version) {
}
```

`assigned_to` 可为 SQL NULL，所以使用 `Long`，不是无法区分 NULL 与 0 的 `long`。`timestamptz` 映射为带偏移语义的 `OffsetDateTime`，避免用本地时区不明的字符串或丢偏移的类型。

## 4. 一个资源安全的唯一键查询

```java
private static final String FIND_BY_ID = """
        SELECT work_order_id,
               status,
               assigned_to,
               created_at,
               version
        FROM factorycare.work_order
        WHERE work_order_id = ?
        """;

public Optional<WorkOrderRow> findById(long id) throws SQLException {
    try (Connection connection = dataSource.getConnection();
         PreparedStatement statement = connection.prepareStatement(FIND_BY_ID)) {

        statement.setLong(1, id);

        try (ResultSet result = statement.executeQuery()) {
            if (!result.next()) {
                return Optional.empty();
            }

            WorkOrderRow row = mapRow(result);
            if (result.next()) {
                throw new SQLException("work_order_id returned more than one row");
            }
            return Optional.of(row);
        }
    }
}
```

这里的证据：

- Connection、PreparedStatement、ResultSet 都在 try-with-resources；
- 关闭顺序与创建顺序相反；
- 参数索引从 1 开始；
- 空结果显式为 `Optional.empty()`；
- 唯一键意外返回多行不会静默取第一行；
- Java 方法不返回仍依赖已关闭资源的 ResultSet。

## 5. PreparedStatement 防的是“值改变结构”

危险代码：

```java
String sql = "SELECT ... WHERE status = '" + userStatus + "'";
try (Statement statement = connection.createStatement();
     ResultSet result = statement.executeQuery(sql)) {
    // ...
}
```

输入：

```text
OPEN' OR '1'='1
```

拼接后引号和 OR 变成 SQL 语法，查询结构被改变。正确：

```java
String sql = "SELECT ... WHERE status = ?";
try (PreparedStatement statement = connection.prepareStatement(sql)) {
    statement.setString(1, userStatus);
}
```

驱动把输入当一个值发送；其中引号不再成为 SQL 结构。测试不仅断言“没有异常”，还要断言恶意字符串返回 0 行且 SQL 模板仍只有一个参数槽。

### 5.1 不能绑定标识符

下面不是动态列名：

```sql
ORDER BY ?
```

参数槽代表值，不代表 SQL 标识符或关键字。动态排序应使用封闭枚举映射：

```java
String orderBy = switch (sort) {
    case CREATED_AT_DESC -> "created_at DESC, work_order_id DESC";
    case PRIORITY_ASC -> "priority ASC, work_order_id ASC";
};
String sql = BASE_QUERY + " ORDER BY " + orderBy;
```

拼接的是程序内固定片段，不是原始用户文本。表名、列名、ASC/DESC 也采用同样 allowlist。

## 6. 参数绑定：值、类型、NULL 三件事

常见绑定：

```java
statement.setLong(1, workOrderId);
statement.setString(2, status);
statement.setObject(3, commandId);          // UUID
statement.setObject(4, createdAt);          // OffsetDateTime, JDBC 4.2/pgJDBC
statement.setNull(5, Types.BIGINT);          // 明确 SQL NULL 类型
```

规则：

1. 参数编号严格对应 SQL 中 `?` 的出现顺序，从 1 开始；
2. 选择与列语义匹配的 setter，不把所有值都转字符串；
3. NULL 要有目标 SQL 类型，避免驱动无法推断；
4. BigDecimal 处理金额，不用 double；
5. 时间类型明确 instant/offset/local 语义；
6. UUID 使用驱动支持的对象映射，不自己拼引号和 cast；
7. 参数日志记录类型和脱敏摘要，不记录密码或敏感全文。

### 6.1 类型转换失败是边界证据

把 `status` 用 `setInt` 绑定，或把非法 UUID 字符串绑定到 uuid 列，可能在驱动或服务器层失败。捕获异常时要保存 operation、参数类型、SQLState 与 cause，不能只记录“查询失败”。

## 7. ResultSet 映射必须逐列声明

```java
private static WorkOrderRow mapRow(ResultSet result) throws SQLException {
    return new WorkOrderRow(
            result.getLong("work_order_id"),
            result.getString("status"),
            result.getObject("assigned_to", Long.class),
            result.getObject("created_at", OffsetDateTime.class),
            result.getLong("version"));
}
```

使用显式列名/alias 能降低 SELECT 调整后位置错配。不要 `SELECT *` 再靠列序号映射；schema 增列、连接同名列或顺序变化会使代码脆弱。

### 7.1 SQL NULL 与 Java primitive

某些 primitive getter 在 SQL NULL 时返回 Java 默认值，例如 `getLong` 返回 0；必须紧接着 `wasNull()` 才能区分：

```java
long raw = result.getLong("assigned_to");
Long assignedTo = result.wasNull() ? null : raw;
```

若驱动支持目标类型，可用 `getObject(label, Long.class)` 直接得到可空包装类型。无论方式，映射测试必须包含 NULL 行。

### 7.2 空结果不是异常，也不是 null repository 返回值

按 ID 查询无行是正常业务分支：`Optional.empty()`。返回 null 会把“无行”与“repository bug”混在一起；直接 `result.next(); result.getLong(...)` 而不检查 boolean 会在空结果上失败。

### 7.3 一行、多行合同

- `findById`：0 或 1 行；多行表示约束或 SQL 合同错误；
- `findOpen`：0..N 行，循环 `while (result.next())`；
- 聚合 `count(*)`：正常应有一行，但仍检查 `next()`；
- 大结果集：需要 fetch size、事务和流式行为的驱动验证，本章不展开。

## 8. 写操作要检查影响行数

```java
private static final String ASSIGN = """
        UPDATE factorycare.work_order
        SET status = ?, assigned_to = ?, version = version + 1
        WHERE work_order_id = ?
          AND version = ?
        """;

int changed = statement.executeUpdate();
if (changed != 1) {
    throw new ConcurrentModificationException(
            "expected one work order, changed=" + changed);
}
```

`executeUpdate` 返回 DML 影响行数。0 可能是不存在或 version 冲突；大于 1 表示 WHERE 条件错误。只看“SQL 没抛异常”会把无效更新当成功。

查询用 `executeQuery`，更新用 `executeUpdate`，比通用 `execute` 更清晰。需要生成键时显式请求并读取 generated keys；本章 FactoryCare 主例使用已有 ID，不扩展。

## 9. JDBC 的默认 auto-commit 会拆散多语句业务

JDK 25 `Connection` 文档规定新连接默认 auto-commit=true：每条语句完成时作为独立事务提交。若工单 UPDATE 成功后 history INSERT 失败，第一条不能由第二条的 rollback 撤销。

显式事务：

```java
public void assign(AssignCommand command) throws SQLException {
    try (Connection connection = dataSource.getConnection()) {
        connection.setAutoCommit(false);
        try {
            updateWorkOrder(connection, command);
            insertHistory(connection, command);
            connection.commit();
        } catch (SQLException failure) {
            try {
                connection.rollback();
            } catch (SQLException rollbackFailure) {
                failure.addSuppressed(rollbackFailure);
            }
            throw failure;
        }
    }
}
```

关键点：

- 两个 helper 接收同一个 Connection；内部不能另取连接；
- `setAutoCommit(false)` 在第一条业务 SQL 前；
- 成功只在末尾 commit；
- 任一 SQLException 都尝试 rollback；
- rollback 自己失败时作为 suppressed exception 保留，不能遮蔽原始失败；
- try-with-resources 最终关闭 Connection。

JDBC 官方文档强烈建议在 close 前显式 commit 或 rollback；关闭仍有活动事务时结果由实现决定。不能把 `close()` 当可移植的 rollback API。

### 9.1 不要用 SQL 文本改变 JDBC 已有配置接口

如果 JDBC 有 `setAutoCommit`、`setTransactionIsolation`、`setReadOnly`，使用接口而不是发送 `SET` 后假设驱动状态同步。隔离级别要在事务工作开始前设置。

### 9.2 `setAutoCommit(true)` 可能提交

官方语义指出，在活动事务中改变 auto-commit 模式会提交事务。因此“finally 里无条件 setAutoCommit(true)”不是安全 rollback。先明确 commit/rollback，再做连接状态清理。基础 DataSource 关闭物理连接即可；连接池归还前的完整复位留后续框架章节，但原则不变。

## 10. 异常翻译：分类而不是吞掉数据库事实

`SQLException` 提供：

- `getSQLState()`：标准/数据库定义的五字符状态；
- `getErrorCode()`：厂商代码；
- `getNextException()`：异常链；
- cause 与 suppressed exceptions。

FactoryCare 最小分类：

| SQLState | PostgreSQL 条件 | 应用方向 |
| --- | --- | --- |
| 23505 | unique_violation | 重复 command/id，翻译冲突或查已有结果 |
| 23503 | foreign_key_violation | 被引用对象不存在/删除冲突 |
| 23514 | check_violation | 输入或状态不满足数据库不变量 |
| 40001 | serialization_failure | rollback 后从事务开头有界重试 |
| 40P01 | deadlock_detected | rollback 后从事务开头有界重试 |
| 08006 等 08 类 | connection failure | 提交结果可能未知，不能盲目重做非幂等操作 |

不要按错误消息文本匹配“duplicate key”，因为本地化和版本可能变化。翻译后的应用异常应保留原 SQLException 为 cause，并记录脱敏 operation、SQLState、attempt、commandId；不要把 SQL、参数和凭据无差别打印。

### 10.1 重试层在事务外

```text
attempt 1:
  get fresh connection
  begin JDBC transaction
  reread current state
  execute all statements
  40P01 → rollback/close
attempt 2:
  get fresh connection
  run whole transaction again
```

不能在已失败 Connection 中只重跑最后一条 statement。重试次数有上限与退避，业务命令使用稳定 commandId 防重复。连接中断时先判断结果未知边界。

## 11. 四类故障注入

### 故障 A：字符串拼 SQL

输入 `OPEN' OR '1'='1` 让查询返回所有状态。第一证据是最终 SQL 结构包含输入，而不是参数槽。修复 PreparedStatement，并断言恶意输入只作为一个值、返回 0 行。

### 故障 B：漏 close

只关闭 Connection 或依赖 GC，循环查询后打开资源计数持续增长，最终耗尽连接/游标。修复嵌套 try-with-resources。测试用可观察 DataSource/代理记录 Connection、PreparedStatement、ResultSet 的 close 次数；真实验收再看数据库连接状态。

### 故障 C：列类型映射错误

把 nullable `assigned_to` 用 primitive long 映射，SQL NULL 变 0；或把 `timestamptz` 转无时区字符串。第一证据是固定 NULL/带偏移行的 expected 与 actual。修复包装类型/`wasNull` 和 OffsetDateTime 映射。

### 故障 D：异常后未 rollback

关闭 auto-commit，UPDATE 后 history INSERT 失败，catch 直接抛出且未 rollback。Connection close 对活动事务行为不可作为可移植合同；池环境还可能把脏状态归还。修复 catch 中 rollback，保留 rollback failure，并断言数据库状态未改变、Connection 已关闭。

## 12. 诊断顺序

1. **operation 与 SQLState**：失败属于连接、语法、类型、约束还是事务回滚？
2. **SQL 模板**：是否固定占位符？是否拼入不可信值/标识符？
3. **绑定清单**：参数个数、顺序、Java 类型、SQL 类型、NULL？
4. **ResultSet 合同**：是否调用 next，列 label/type 是否匹配，NULL 怎么处理？
5. **影响行数**：更新 0/1/N 各代表什么？
6. **Connection 身份**：多语句是否确实同一连接？
7. **autoCommit/隔离**：第一条语句前是什么状态？
8. **commit/rollback**：异常路径是否显式 rollback？rollback 是否也失败？
9. **资源关闭**：ResultSet、Statement、Connection 是否都关闭且仅一次？
10. **数据库最终状态**：工单/history 是否一起提交或回滚？

日志应让你定位第一处边界偏差，而不是只得到堆栈最后一行。

## 13. 测试矩阵

| 用例 | 输入 | 必须证明 |
| --- | --- | --- |
| 正常查询 | 已存在 ID | 字段和类型完整映射，资源关闭 |
| 空查询 | 不存在 ID | `Optional.empty()`，不是 null/异常 |
| nullable 列 | OPEN 工单 | assignedTo 为 null，不是 0 |
| 注入字符 | `OPEN' OR '1'='1` | SQL 结构不变，0 行 |
| 乐观更新成功 | 正确 version | changed=1，commit |
| 乐观冲突 | 旧 version | changed=0，显式冲突 |
| history 失败 | 重复 commandId | rollback，工单未改变 |
| rollback 失败 | 双重故障夹具 | 原异常保留，rollback 为 suppressed |
| 死锁/序列化 | 40P01/40001 | 新连接整事务有界重试 |

纯单元模型能验证控制流；真实 T3 接受标准需要 JDK 25、pgJDBC 和 PostgreSQL 18 集成测试，确认 SQLState、类型映射、资源和数据库最终状态。

## 14. 配套资产与独立构建

- `examples/encyclopedia/ch.data.jdbc/`：查询模板、绑定、映射、空结果与事务控制流合同；
- `labs/encyclopedia/ch.data.jdbc/`：注入、泄漏、错映射、漏 rollback 故障；
- `exercises/encyclopedia/ch.data.jdbc/`：拼 SQL且漏 rollback 的红灯 starter；
- `solutions-private/encyclopedia/ch.data.jdbc/`：参数化、资源闭合、显式回滚与 SQLState 分类私有解。

独立报告记录：

```text
jdk/driver/database-version:
input-and-operation:
sql-template-and-parameter-types:
expected/actual-row-mapping:
affected-row-count:
autoCommit/isolation:
commit-or-rollback:
resource-close-evidence:
SQLState/vendor-code/cause-chain:
database-final-state:
```

## 15. 120 秒讲回

不看笔记回答：

1. 为什么业务代码依赖 DataSource 而不是到处 DriverManager？
2. PreparedStatement 能绑定什么，不能绑定什么？
3. ResultSet 为什么必须先 `next()`？
4. SQL NULL 怎样避免变成 primitive 默认值？
5. 默认 auto-commit 如何破坏多语句原子性？
6. 为什么 close 不能代替显式 rollback？
7. 怎样从 SQLState 决定冲突、重试或未知结果？

## 16. 官方来源

- [JDK 25 DataSource](https://docs.oracle.com/en/java/javase/25/docs/api/java.sql/javax/sql/DataSource.html)；
- [JDK 25 Connection](https://docs.oracle.com/en/java/javase/25/docs/api/java.sql/java/sql/Connection.html)：auto-commit、commit、rollback、close；
- [JDK 25 PreparedStatement](https://docs.oracle.com/en/java/javase/25/docs/api/java.sql/java/sql/PreparedStatement.html)；
- [JDK 25 ResultSet](https://docs.oracle.com/en/java/javase/25/docs/api/java.sql/java/sql/ResultSet.html)：游标、getter、`wasNull`；
- [JDK 25 SQLException](https://docs.oracle.com/en/java/javase/25/docs/api/java.sql/java/sql/SQLException.html)；
- [pgJDBC Query and Result processing](https://jdbc.postgresql.org/documentation/query/)：Java time 等 PostgreSQL 驱动映射；
- [PostgreSQL 18 Error Codes](https://www.postgresql.org/docs/18/errcodes-appendix.html)。

稳定核心是参数化、显式映射、资源所有权与事务失败边界；版本相关面是 JDK 25 API、pgJDBC 类型支持和 PostgreSQL 18 SQLSTATE。真实集成仍未验证。
