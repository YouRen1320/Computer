---
schema_version: 2
edition: 2026.2-draft
id: ch.data.mybatis-core
title: MyBatis 映射、参数绑定、结果映射与动态 SQL
responsibility: 教授 SQL 主导的 Java 映射层，不在本章加入 Spring Repository 或事务代理
volume: '04'
order: 17
level: L2
status: drafting
path: book/volume-04-data-postgresql/chapters/ch.data.mybatis-core.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.data.jdbc
- ch.java-engineering.generics-type-safety
version_surfaces:
- jdk-25
- maven-3
- mybatis
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
  text: 在 120 秒内解释MyBatis 映射、参数绑定、结果映射与动态 SQL的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - mybatis-mapping
  - mybatis-dynamic-sql
  covers_topics:
  - mybatis.mapper-statement
  - mybatis.parameter-binding
  - mybatis.result-mapping
  - mybatis.dynamic-sql
  - mybatis.n-plus-one-boundary
  - mybatis.mapping-failure
  uses_capabilities:
  - data.persistence-access
  - data.sql-query
  - java.inheritance-polymorphism
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 为 WorkOrder 编写 Mapper 接口/XML，验证参数绑定、record 结果映射和可选条件动态 SQL
  covers_topic_groups:
  - mybatis-mapping
  - mybatis-dynamic-sql
  covers_topics:
  - mybatis.mapper-statement
  - mybatis.parameter-binding
  - mybatis.result-mapping
  - mybatis.dynamic-sql
  - mybatis.n-plus-one-boundary
  - mybatis.mapping-failure
  uses_capabilities:
  - data.persistence-access
  - data.sql-query
  - java.inheritance-polymorphism
  evidence_kind: integration-artifact-and-tests
  verification_mode: framework-or-container-test
- id: diagnose
  kind: fault-diagnosis
  text: 注入 MyBatis 参数占位符错名、resultMap 列错配和 if 条件生成非法 SQL，读取 mapper/SQL 日志后修复
  covers_topic_groups:
  - mybatis-mapping
  - mybatis-dynamic-sql
  covers_topics:
  - mybatis.mapper-statement
  - mybatis.parameter-binding
  - mybatis.result-mapping
  - mybatis.dynamic-sql
  - mybatis.n-plus-one-boundary
  - mybatis.mapping-failure
  uses_capabilities:
  - data.persistence-access
  - data.sql-query
  - java.inheritance-polymorphism
  evidence_kind: integration-failure-fix-rerun
  verification_mode: integration-fault-rerun
---
# MyBatis 映射、参数绑定、结果映射与动态 SQL

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《DataSource、PreparedStatement、ResultSet 与 JDBC 事务边界》](ch.data.jdbc.md)：独立完成映射与绑定、动态 SQL 边界前，必须先具备「DataSource、PreparedStatement、ResultSet 与 JDBC 事务边界」已经验证的知识与失败边界
- [《泛型、类型参数、边界与通配符》](../../volume-03-java-engineering/chapters/ch.java-engineering.generics-type-safety.md)：独立完成映射与绑定、动态 SQL 边界前，必须先具备「泛型、类型参数、边界与通配符」已经验证的知识与失败边界
<!-- END GENERATED LEARNING PREREQUISITES -->

> 本章状态为 `drafting`。稳定核心是“SQL 由开发者掌控，值通过参数绑定，查询结果按显式合同映射，动态结构由有限分支生成”。版本事实于 **2026-07-17** 核对：Spring Boot 4 集成线使用 MyBatis Spring Boot Starter **4.1.0** 和 MyBatis-Spring **4.1.0**，底层 SQL mapper 核心仍是 MyBatis **3.5.19**，不是所谓“core MyBatis 4”。本机没有运行 MyBatis/PostgreSQL 集成测试；随章资产验证的是映射合同和故障状态机，不把离线 PASS 冒充真实框架执行。

## 1. 先建立心智模型：MyBatis 是 SQL mapper，不是 SQL 消除器

使用 JDBC 时，开发者亲自创建 `PreparedStatement`、绑定参数、遍历 `ResultSet` 并构造 Java 对象。MyBatis 保留 SQL 的主导权，把其中重复而易错的协议工作抽成映射层：

```text
Java 调用 Mapper 接口方法
  → 代理根据 namespace + statement id 找到 MappedStatement
  → SQL 源解析静态片段和动态标签
  → 生成 BoundSql：最终 SQL 文本 + 有序参数映射
  → ParameterHandler 把值绑定到 PreparedStatement
  → JDBC 驱动访问 PostgreSQL
  → ResultSetHandler 按 resultMap/resultType 构造返回对象
```

这条链有三个必须分别验证的合同：

1. **定位合同**：接口、XML namespace、方法名和 statement `id` 能定位到同一条语句；
2. **输入合同**：Java 参数名、动态表达式和 `#{...}` 属性路径一致；
3. **输出合同**：SQL 返回的列标签、NULL、Java 类型与构造器/属性映射一致。

MyBatis 不会判断 SQL 是否满足业务语义，不会自动替你选择索引，也不会阻止一次搜索返回百万行。它能把值安全绑定到占位符，却不能让用户任意提供表名或排序表达式。它可以建立嵌套对象，却可能因嵌套查询制造 N+1。它能加入 Spring 事务，但本章的唯一职责是 mapper 层；事务代理、Repository 抽象和服务层编排留给后续章节。

### 完成标准

学完后应能独立证明：

- `WorkOrderMapper.search` 的接口方法和 XML statement 一一对应；
- 普通值、引号和注入字符串都只成为参数，不改变 SQL 结构；
- 空结果、单结果和多结果按方法返回类型得到预期结果；
- `work_order_no`、`assignee_id`、`created_at` 能稳定映射到 record 组件；
- 所有筛选条件都缺席时，动态 SQL 仍是合法查询；
- 空集合不会生成非法 `IN ()`，排序字段来自受控白名单；
- 列表页不会因逐行嵌套查询变成 N+1；
- 失败证据能定位到“statement 定位、参数绑定、SQL、结果映射”中的首个错误层。

## 2. 版本名最容易先教错：4.x 是集成层，不是核心 mapper 主版本

“项目使用 MyBatis 4”这句话不够精确。至少要区分三个 artifact：

| 层 | 当前稳定线（核对日） | 职责 |
| --- | --- | --- |
| `org.mybatis.spring.boot:mybatis-spring-boot-starter` | 4.1.0 | 面向 Spring Boot 4.1 的自动配置入口 |
| `org.mybatis:mybatis-spring` | 4.1.0 | `SqlSessionFactoryBean`、`SqlSessionTemplate`、mapper 与 Spring 的桥接 |
| `org.mybatis:mybatis` | 3.5.19 | mapper statement、参数、动态 SQL、resultMap 等核心 |

所以官方核心文档路径仍是 `/mybatis-3/`，XML 仍使用 `mybatis-3-mapper.dtd`。Starter 4.1.0 发布说明显示它更新到 Spring Boot 4.1.0 与 MyBatis-Spring 4.1.0；MyBatis-Spring 的兼容表也明确 4.x 集成层依赖 MyBatis core 3.5+。版本号相同不代表模块同代，更不能凭 Starter 的 `4` 猜核心 API 已全面换代。

项目应由 Boot 依赖管理或明确的 dependency management 锁定一套已验证组合，不在业务模块分别随意覆盖 core、spring bridge 和 starter。JDK 25 是 FactoryCare 的项目基线；Starter 的最低 Java 要求只是兼容下限，不代表课程要降回最低版本。升级时至少复跑 mapper 加载、参数绑定、结果映射、动态 SQL 和 PostgreSQL 容器测试。

## 3. 最小词汇表：读错误日志前先知道名字指什么

### 3.1 Mapper 接口

普通 Java 接口，声明数据库操作的输入和输出。运行时由 MyBatis 创建代理，不需要手写实现类。接口不是领域服务：一个方法应表达一项持久化查询或写入，不负责跨多个业务步骤编排。

### 3.2 Mapper XML

以 `<mapper>` 为根的资源文件，包含 `select/insert/update/delete`、`resultMap`、SQL 片段和动态标签。XML 的 `namespace` 通常写 mapper 接口全限定名，statement 的 `id` 通常等于方法名。

### 3.3 MappedStatement

MyBatis 启动解析后形成的语句定义。它的唯一键近似：

```text
com.factorycare.workorder.persistence.WorkOrderMapper.search
```

异常日志出现这个全限定 statement id 时，先围绕它查 XML 是否加载、namespace 是否拼错、`id` 是否存在，而不是先怀疑 PostgreSQL。

### 3.4 参数对象与 `@Param`

mapper 方法接收的 Java 值。单一筛选对象可直接暴露其属性；多个参数应使用 `@Param` 给出稳定名字。不要依赖编译器是否保留参数名来猜 XML 中该写 `status`、`arg0` 还是 `param1`。

### 3.5 `resultType` 与 `resultMap`

`resultType` 让 MyBatis 按约定自动映射一个类型；`resultMap` 明确列到属性或构造器参数的对应关系。两者在同一 statement 上二选一。简单且列别名完全可控时可以使用 `resultType`，领域边界、record、JOIN、NULL 或重命名较多时优先显式 `resultMap`。

### 3.6 BoundSql

动态标签求值后的最终 SQL 和参数映射。排查时真正要问的是：最终 SQL 有几个 `?`，参数按什么顺序绑定，哪些分支被保留。XML 看起来正确并不等于某组输入产生的 BoundSql 正确。

## 4. Boot 4 集成只负责装配，不改变 mapper 的基本合同

官方 Starter 会发现已有 `DataSource`，创建 `SqlSessionFactory`，创建 `SqlSessionTemplate`，扫描 mapper 并把代理注册到 Spring 容器。一个典型依赖入口是：

```xml
<dependency>
  <groupId>org.mybatis.spring.boot</groupId>
  <artifactId>mybatis-spring-boot-starter</artifactId>
  <version>4.1.0</version>
</dependency>
```

课程示例可以在 mapper 接口上使用 `@Mapper`，或在配置边界集中使用 `@MapperScan`，但不要两套扫描策略到处混用。XML 资源路径也要窄而明确，不能用会把第三方 JAR 中任意 XML 都吞进来的过宽通配符。

```yaml
mybatis:
  mapper-locations: classpath:/mybatis/*Mapper.xml
  configuration:
    map-underscore-to-camel-case: false
    auto-mapping-unknown-column-behavior: failing
```

这里故意关闭下划线自动转换并让未知自动映射失败，是教学期的“把隐含合同显式化”策略，不是所有生产项目唯一正确配置。关键是团队知道默认值和影响，并用测试固定选择。官方 core 配置的默认 `mapUnderscoreToCamelCase` 是 `false`、`autoMappingBehavior` 是 `PARTIAL`、未知列行为是 `NONE`；若依赖自动映射却没写测试，列重命名可能悄悄产生 null 或默认值。

本章不在 mapper 上添加 `@Transactional`，也不手动调用 Spring 管理的 `SqlSession.commit/rollback/close`。MyBatis-Spring 会让 mapper 参与已有 Spring 事务，但事务应由业务用例边界决定。mapper 的可验证职责是“执行哪条 SQL、怎样绑定、怎样映射”。

## 5. FactoryCare 映射骨架：接口、参数和 XML 必须形成闭环

### 5.1 返回 record

FactoryCare 列表页只需要持久化投影，不必加载完整领域聚合：

```java
package com.factorycare.workorder.persistence;

import java.time.OffsetDateTime;

public record WorkOrderRow(
    Long id,
    String number,
    String title,
    WorkOrderStatus status,
    Long assigneeId,
    OffsetDateTime createdAt
) {}
```

使用 `Long` 而不是 `long` 表达 `assigneeId` 可为 SQL NULL。若用基本类型，NULL 可能被迫表现成 `0`，随后业务层无法区分“未指派”和“错误地指派给 0”。时间列沿用 JDBC 章节的类型合同：PostgreSQL `timestamptz` 用能表达偏移/瞬时语义的 Java time 类型，并由真实 pgJDBC 测试确认。

### 5.2 搜索参数对象

```java
package com.factorycare.workorder.persistence;

import java.time.OffsetDateTime;
import java.util.List;

public record WorkOrderFilter(
    WorkOrderStatus status,
    Long assigneeId,
    String keyword,
    OffsetDateTime createdFrom,
    List<Long> ids,
    WorkOrderSort sort
) {}
```

用具名 record 优于无类型含义的 `Map<String, Object>`：编译器能检查属性，XML 路径更稳定，调用方也看得懂哪些条件可选。若需求加入 `siteId`，应修改 record、SQL 和用例，而不是往 Map 塞一个只有运行时才知道的键。

### 5.3 Mapper 接口

```java
package com.factorycare.workorder.persistence;

import java.util.List;
import java.util.Optional;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface WorkOrderMapper {
  Optional<WorkOrderRow> findById(@Param("id") long id);

  List<WorkOrderRow> search(@Param("filter") WorkOrderFilter filter);
}
```

`findById` 的数据库合同是零或一行，`search` 是零到多行。唯一键查询若错误返回两行，应在集成测试中暴露而不是随便取第一行。列表查询用 `List`，空结果是空列表而不是 null。是否让 mapper 直接返回 `Optional` 要由当前 MyBatis 版本的真实测试固定；若团队选择返回可空对象，则应在 mapper 适配边界立即转换，不能让 null 漫游整个服务层。

### 5.4 XML 的定位合同

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE mapper
  PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN"
  "https://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="com.factorycare.workorder.persistence.WorkOrderMapper">
  <!-- statements -->
</mapper>
```

`namespace` 必须等于接口全限定名；`<select id="search">` 必须对应 `search` 方法。XML 文件名相同只是可读性约定，真正定位依靠 namespace 与 id。以下错误属于加载/定位层：

- `Invalid bound statement (not found)`：statement 未注册，常见于资源没打包、namespace/id 不匹配；
- `Mapped Statements collection already contains key`：同一全限定 id 被重复注册；
- XML 构建异常：DTD、标签顺序、属性或表达式在启动阶段失败。

这些错误尚未把 SQL 发给 PostgreSQL，不能靠改索引解决。

## 6. 参数绑定：`#{}` 是值，`${}` 是原样文本

### 6.1 `#{}` 的语义

```xml
<select id="findById" resultMap="workOrderRowMap">
  SELECT id, work_order_no, title, status, assignee_id, created_at
  FROM work_order
  WHERE id = #{id}
</select>
```

`#{id}` 最终成为 JDBC `?`，值通过 PreparedStatement 绑定。输入 `42`、`O'Reilly` 或 `CREATED' OR '1'='1` 只会占据一个参数位置，不会成为 SQL 关键字。类型处理器负责 Java/JDBC 类型转换；可空写入参数必要时显式给出 `jdbcType`：

```xml
#{assigneeId,jdbcType=BIGINT}
```

`jdbcType` 不是消毒器，它用于 NULL 等类型合同。输入安全来自结构和值分离。

### 6.2 `${}` 的语义与危险

```xml
ORDER BY ${filter.sort}
```

`${}` 把字符串原样替换进 SQL，不产生参数槽。若值来自 HTTP 查询参数，攻击者可以提供表达式、额外关键字甚至注释。PreparedStatement 也不能把表名、列名或 `ASC/DESC` 当作普通值绑定；正确办法不是换一种占位符，而是把外部枚举映射到开发者写死的 SQL 片段。

```xml
<choose>
  <when test="filter.sort != null and filter.sort.name() == 'CREATED_ASC'">
    ORDER BY created_at ASC, id ASC
  </when>
  <otherwise>
    ORDER BY created_at DESC, id DESC
  </otherwise>
</choose>
```

更稳的边界是在 Java 请求解析层把字符串转换为 `WorkOrderSort` 枚举，未知值直接校验失败。XML 只在有限枚举分支中选择固定字面量。本章示例对用户输入保持“零 `${}`”规则；只有经过严格白名单且确实属于标识符的内部元数据才有资格讨论文本替换。

### 6.3 多参数为什么要 `@Param`

```java
int updateStatus(
    @Param("id") long id,
    @Param("expectedStatus") WorkOrderStatus expectedStatus,
    @Param("nextStatus") WorkOrderStatus nextStatus
);
```

```xml
UPDATE work_order
SET status = #{nextStatus}
WHERE id = #{id}
  AND status = #{expectedStatus}
```

若 XML 写成 `#{status}`，MyBatis 会在参数集合中找不到该名字并抛绑定异常。日志通常列出可用参数；诊断应把接口注解与 XML 路径并排比较。不要改成 `${status}`“让它能跑”，那只是把命名错误升级为注入风险。

## 7. resultMap：把列标签当成公开合同

### 7.1 显式 constructor mapping

record 没有无参构造器和 setter，适合用构造器映射：

```xml
<resultMap id="workOrderRowMap"
           type="com.factorycare.workorder.persistence.WorkOrderRow"
           autoMapping="false">
  <constructor>
    <idArg name="id" column="id" javaType="java.lang.Long"/>
    <arg name="number" column="work_order_no" javaType="java.lang.String"/>
    <arg name="title" column="title" javaType="java.lang.String"/>
    <arg name="status" column="status"
         javaType="com.factorycare.workorder.persistence.WorkOrderStatus"/>
    <arg name="assigneeId" column="assignee_id" javaType="java.lang.Long"/>
    <arg name="createdAt" column="created_at"
         javaType="java.time.OffsetDateTime"/>
  </constructor>
</resultMap>
```

`autoMapping="false"` 让此投影的列变更显式失败或在测试中显现。`<idArg>` 不只是文档，它标出标识字段，可帮助嵌套结果去重。参数名和顺序仍应通过真实框架测试确认，尤其在 JDK、编译器参数和 MyBatis 补丁升级后。

### 7.2 SQL 列名与列标签

MyBatis 读取的通常是结果集列标签。JOIN 时必须使用稳定别名，避免多个表都有 `id`、`status`：

```sql
SELECT
  wo.id            AS wo_id,
  wo.work_order_no AS wo_number,
  wo.status        AS wo_status,
  u.id             AS assignee_id,
  u.display_name   AS assignee_name
FROM work_order wo
LEFT JOIN app_user u ON u.id = wo.assignee_id
```

然后 resultMap 明确映射 `wo_id`、`wo_status`。如果 SQL 把 `assignee_id` 改名为 `assigned_user_id` 而 resultMap 没更新，可能出现构造失败，也可能得到 null；哪种表现取决于类型、自动映射和构造器解析，不能只靠肉眼推断。

### 7.3 自动映射的边界

自动映射适合非常简单且已用列别名对齐 Java 名称的查询：

```sql
SELECT work_order_no AS number, created_at AS createdAt
FROM work_order
```

但 JOIN、同名列、嵌套结构和长期演进的报表投影应显式映射。官方文档提醒 `FULL` 自动映射在 JOIN 中可能把父表的 `id` 错映射进子对象。教学项目宁可多写几行 resultMap，也不要让数据串位而测试仍只断言“对象非 null”。

### 7.4 空、单、多三种基数

每个 mapper 方法都应先声明行数合同：

| 合同 | 返回类型示例 | 必测情况 |
| --- | --- | --- |
| 0..1 | `Optional<WorkOrderRow>` | 0 行为空，1 行有值，2 行必须暴露唯一性错误 |
| 0..N | `List<WorkOrderRow>` | 0 行空列表，1 行一项，多行顺序稳定 |
| 写入 | `int` | 0 表示未命中/并发冲突，1 表示成功，>1 通常违反预期 |

“查询执行成功”不是充分断言。至少核对 id、状态、可空处理人、时间类型与排序；映射错列往往仍会返回对象。

## 8. 动态 SQL：动态的是受控结构，参数仍然绑定

### 8.1 `<if>` 与 OGNL

`<if test="filter.status != null">` 判断是否加入一个由开发者写好的 SQL 片段。`test` 是表达式，片段里的值仍用 `#{filter.status}`。条件名和绑定路径应来自同一个参数对象，避免一个写 `filter.status`、另一个写 `status`。

字符串条件要先定义空串语义。若空 keyword 代表“不筛选”，可以在 Java 边界规范化为空值；不要让 XML 同时处理 null、空串、全空格和转义。LIKE 示例可用 `<bind>` 生成值，再绑定它：

```xml
<if test="filter.keyword != null">
  <bind name="keywordPattern" value="'%' + filter.keyword + '%'"/>
  AND (work_order_no ILIKE #{keywordPattern}
       OR title ILIKE #{keywordPattern})
</if>
```

这不会自动处理 `%`、`_` 的字面量需求；产品若要求“按字面包含”，还需定义转义规则并加 `ESCAPE` 测试。

### 8.2 `<where>` 解决悬空 WHERE 和前导 AND

错误写法：

```xml
WHERE
<if test="filter.status != null">
  status = #{filter.status}
</if>
```

当条件缺席时得到 `WHERE`；若第一个条件片段以 `AND` 开头则得到 `WHERE AND ...`。`<where>` 只在有内容时插入 WHERE，并去掉合适的前导 `AND/OR`：

```xml
<where>
  <if test="filter.status != null">
    AND status = #{filter.status}
  </if>
  <if test="filter.assigneeId != null">
    AND assignee_id = #{filter.assigneeId}
  </if>
  <if test="filter.createdFrom != null">
    AND created_at &gt;= #{filter.createdFrom}
  </if>
</where>
```

必须测试“全缺席、只有第一项、只有中间项、全部存在”四类组合。动态 SQL 的 bug 往往藏在分支组合，而不是常用 happy path。

### 8.3 `<choose>` 表达互斥分支

若筛选优先级是“给了 id 就按 id，否则按工单号，否则拒绝”，用 `<choose>/<when>/<otherwise>` 比多个可同时成立的 `<if>` 更准确。`otherwise` 可以生成安全默认条件，也可以由 Java 层提前拒绝。不要默认在没有任何限制时返回全表，尤其是管理后台搜索接口。

### 8.4 `<foreach>` 与空集合

```xml
<if test="filter.ids != null and !filter.ids.isEmpty()">
  AND id IN
  <foreach collection="filter.ids" item="id" open="(" separator="," close=")">
    #{id}
  </foreach>
</if>
```

每个元素都产生参数槽，不使用字符串拼接。真正困难的是空集合语义：

- null 可能表示“不按 id 筛选”；
- 空列表可能表示“没有任何候选，因此应返回 0 行”；
- 若直接跳过条件，空列表会意外变成全量查询。

FactoryCare 在 Java 查询边界规定：显式空 `ids` 直接返回空列表，不调用 mapper；null 才表示未启用该条件。这个决定必须有测试，而不是由 XML 标签的偶然行为决定。

### 8.5 `<set>` 与局部更新

`<set>` 可在有字段时加入 SET 并移除尾随逗号，但所有字段都缺席会生成非法更新。局部更新必须先验证至少一项改变，并限制哪些字段可改。更重要的是，工单状态迁移不是任意 patch：它还应带期望旧状态或版本条件，让更新行数成为并发证据。

## 9. 一份完整的 FactoryCare 搜索 statement

```xml
<select id="search" resultMap="workOrderRowMap">
  SELECT id, work_order_no, title, status, assignee_id, created_at
  FROM work_order
  <where>
    <if test="filter.status != null">
      AND status = #{filter.status}
    </if>
    <if test="filter.assigneeId != null">
      AND assignee_id = #{filter.assigneeId}
    </if>
    <if test="filter.createdFrom != null">
      AND created_at &gt;= #{filter.createdFrom}
    </if>
    <if test="filter.keyword != null">
      <bind name="pattern" value="'%' + filter.keyword + '%'"/>
      AND (work_order_no ILIKE #{pattern} OR title ILIKE #{pattern})
    </if>
    <if test="filter.ids != null and !filter.ids.isEmpty()">
      AND id IN
      <foreach collection="filter.ids" item="id"
               open="(" separator="," close=")">
        #{id}
      </foreach>
    </if>
  </where>
  <choose>
    <when test="filter.sort != null and filter.sort.name() == 'CREATED_ASC'">
      ORDER BY created_at ASC, id ASC
    </when>
    <otherwise>
      ORDER BY created_at DESC, id DESC
    </otherwise>
  </choose>
</select>
```

复核这段代码时按生成结果而不是按标签数量检查：

1. 无筛选：没有 WHERE，ORDER BY 合法；
2. 只有状态：一个 `?`，值为状态，SQL 没有多余 AND；
3. 状态加处理人：两个 `?`，顺序与参数日志一致；
4. keyword 含引号：SQL 结构不变，pattern 是参数值；
5. ids 三项：产生三个参数槽；
6. 排序非法字符串：在进入 mapper 前已被枚举校验拒绝；
7. 多行相同 `created_at`：以 id 作为次排序键，分页顺序稳定。

“XML 能启动”只能证明语法的一部分，不能替代上述输入矩阵。

## 10. N+1 边界：映射便利不等于查询成本免费

MyBatis 允许在 `<association select="findAssignee">` 或 `<collection select="...">` 中为每个父行执行嵌套查询。列表先查一次 100 条工单，再为每条查询处理人，就是 1+100 次。官方 resultMap 文档明确称其为 N+1 Selects Problem；即使启用 lazy load，只要序列化或循环访问了所有属性，查询仍会发生。

FactoryCare 列表页有三种可选策略：

1. **JOIN 一次查询**：适合每个工单至多一个处理人，使用列别名和嵌套 resultMap；
2. **两段批量查询**：先查工单，再用去重后的 assignee ids 做一次 `IN` 查询，在 Java 中组装；
3. **嵌套 select**：只在结果极小、访问确实稀疏且有查询计数证据时使用。

默认推荐 JOIN 或批量两段式。测试不仅断言对象图，还应设置查询预算，例如 50 条工单最多 2 次查询。分页 JOIN 一对多时要格外小心：数据库分页作用于行，重复父行可能让“每页 20 个工单”失真。可先分页取父 id，再批量加载子项。

二级缓存也不是 N+1 的通用修复。它改变一致性和失效边界，且首次访问仍可能产生大量查询。先改查询形状，再讨论缓存。

## 11. 四类典型故障与证据链

### 11.1 参数占位符错名

**注入：** 接口是 `@Param("filter")`，XML 写 `#{status}`。

**现象：** MyBatis 绑定阶段报找不到参数，并列出可用名字；数据库通常没收到 SQL。

**诊断：** 记录全限定 statement id、方法签名、`@Param` 和 XML 路径。把 `#{status}` 改为 `#{filter.status}`，重跑有值与 null 两组用例。

### 11.2 resultMap 列错配

**注入：** SQL 返回 `assignee_id`，resultMap 写 `column="assignee"`。

**现象：** 可能构造异常，也可能 `assigneeId` 变 null；若测试只断言列表大小，错误会漏过。

**诊断：** 比较实际列标签与 resultMap，不先开自动映射掩盖问题。修复后断言未指派行为和有处理人行为各一例。

### 11.3 `<if>` 组合生成非法 SQL

**注入：** 手写固定 `WHERE`，所有条件缺席。

**现象：** PostgreSQL SQLSTATE `42601`（语法错误），日志中的最终 SQL 以孤立 WHERE 结尾。

**诊断：** 以同一输入重建 BoundSql，改用 `<where>` 或 `<trim>`；必须重跑全缺席和单条件分支，不能只重跑常用多条件路径。

### 11.4 `${}` 导致结构注入

**注入：** `ORDER BY ${sort}`，输入 `created_at DESC NULLS LAST, id` 或带注释的恶意片段。

**现象：** SQL 结构随输入变化；即使数据库拒绝某个 payload，合同也已失败。

**诊断：** 在最终 SQL 中确认用户文本被直接展开；改为枚举白名单与 `<choose>` 固定片段。负向测试断言未知 sort 被请求校验拒绝，且 mapper XML 不包含用户值替换。

### 11.5 N+1 不是“查询正确”就算通过

**注入：** 列表 resultMap 对 assignee 使用嵌套 select。

**现象：** 返回 50 条数据且内容全对，但 statement 计数是 51，延迟随行数线性增长。

**诊断：** 给 mapper/statement logger 加计数或使用数据源代理；改为 JOIN 或批量加载后，重新断言数据与查询预算。

## 12. 从日志定位首个失败层

官方日志支持按 mapper 全限定名、namespace 或完整 statement id 开启。开发环境可对目标 mapper 使用 DEBUG 查看 SQL，必要时 TRACE 看结果；生产环境不能无界打印敏感参数和整批结果。

建议按下列顺序收集证据：

```text
1. 调用的是哪个 Mapper 方法？输入对象是什么（已脱敏）？
2. 完整 statement id 是否存在？XML 是否真的被加载？
3. 最终 SQL 长什么样？有几个参数槽？
4. 参数名字、顺序、Java/JDBC 类型是什么？
5. PostgreSQL 是否执行？SQLSTATE 是什么？
6. 返回哪些列标签和行数？
7. resultMap 如何把列映射到构造器/属性？
8. 修复后是否用原失败输入重跑？
```

层级判断：

- 启动时 XML parse/duplicate key：配置加载层；
- `Invalid bound statement`：mapper 定位层；
- `BindingException: Parameter ... not found`：参数解析层；
- PostgreSQL SQLSTATE `42601/42703/23505`：SQL/数据库层；
- 查询成功但字段错误、构造失败：结果映射层；
- 内容正确但查询数爆炸：查询形状/性能层。

修复必须保留异常原因和 statement id。不要把所有异常捕获成“数据库错误”，否则定位信息被抹平。

## 13. 测试策略：XML 解析通过只是最内层

### 13.1 纯合同测试

快速检查 namespace、statement id、禁止 `${}`、要求 `<where>`、列清单和 resultMap。随章离线资产属于这一层，适合证明教材规则，但不运行 OGNL、TypeHandler、JDBC 驱动或 PostgreSQL。

### 13.2 MyBatis 上下文测试

启动真实 `SqlSessionFactory`，确认 XML 被加载、接口方法能绑定 statement、record 构造成功。若使用 Boot 4 slice 测试，应确保加载的是本项目实际自动配置和 mapper 资源，而不是手工搭了另一套行为。

### 13.3 PostgreSQL 18 集成测试

使用迁移创建真实 schema，准备：

- 一条未指派工单；
- 一条已指派工单；
- 多条相同时间、不同 id 的工单；
- 含引号、百分号、下划线的标题；
- 不同状态和时间边界；
- 违反唯一约束或列不存在的负向场景。

验证空/单/多、NULL、枚举、`timestamptz`、ILIKE、排序、分页和 SQLSTATE。H2 不能证明 PostgreSQL 特有语义。

### 13.4 故障重跑

验收证据应记录：原输入、失败日志、首个失败层、最小修复、相同输入重跑结果。只展示最终绿灯不能证明会诊断。

## 14. 独立构建任务

为 FactoryCare 完成一套 `WorkOrderMapper`：

1. 定义 `WorkOrderFilter` 与 `WorkOrderRow` record；
2. 定义 `findById` 和 `search` 方法，给参数稳定命名；
3. XML namespace/id 与接口闭合；
4. 用 constructor resultMap 显式映射六个列；
5. 用 `<where>/<if>/<foreach>/<choose>` 生成可选筛选和固定排序；
6. 用户值全部 `#{}` 绑定，排序使用枚举白名单；
7. 定义 null 与空 ids 的不同语义；
8. 列表的 assignee 采用 JOIN 或批量查询，给出查询预算；
9. 在 PostgreSQL 18 测空、单、多、注入字符串和全部条件缺席；
10. 注入错参数名、错列名和悬空 WHERE，保存修复前后证据。

提交报告格式：

```text
环境与版本：JDK / Boot / Starter / MyBatis-Spring / core / pgJDBC / PostgreSQL
输入数据：迁移版本、fixture、过滤器
操作：调用的 Mapper 方法和 statement id
预期：SQL 结构、参数槽、行数、映射、查询预算
实际：脱敏 SQL/参数摘要、结果、SQLSTATE/异常链
故障：注入内容、首个失败层、修复
重跑：同一输入的结果
仍未验证：并发、超大数据、生产日志、缓存等
```

## 15. 复习与口述检查

### 15.1 120 秒讲清

回答应包含：MyBatis 保留 SQL 控制权；mapper 接口通过 namespace/id 定位 statement；`#{}` 绑定值而 `${}` 替换文本；resultMap 是列到对象的显式合同；动态标签生成有限 SQL 结构；嵌套 select 可能 N+1；Starter/MyBatis-Spring 4.x 不等于 core MyBatis 4。

### 15.2 必须能预测

- `@Param("filter")` 配 `#{status}` 会在哪一层失败？
- 所有 `<if>` 都为 false 时，固定 WHERE 会生成什么？
- `${sort}` 输入变化时 SQL 结构是否变化？
- SQL 返回 `assigned_user_id`，resultMap 仍读 `assignee_id` 会怎样？
- 100 条父记录逐条嵌套查询最多会执行多少次？
- 空 ids 是“忽略筛选”还是“零结果”，决定应该放在哪里？

### 15.3 修改能力

新增“仅看逾期工单”时，先在过滤器定义明确布尔/时间语义，再添加固定 SQL 分支和无条件/单条件/组合测试；不要为了省事接收任意 SQL 片段。新增排序字段时修改枚举与 `<choose>` 白名单，并验证稳定次排序键。

## 16. 官方资料与核对边界

- [MyBatis Spring Boot Starter 4.1.0 release](https://github.com/mybatis/spring-boot-starter/releases/tag/mybatis-spring-boot-4.1.0)：2026-07-16 发布并更新到 Boot 4.1.0、MyBatis-Spring 4.1.0；
- [MyBatis Spring Boot Starter Introduction](https://mybatis.org/spring-boot-starter/mybatis-spring-boot-autoconfigure/)：DataSource、SqlSessionFactory、SqlSessionTemplate 与 mapper 扫描；
- [MyBatis-Spring requirements](https://mybatis.org/spring/)：4.x 集成层仍要求 core MyBatis 3.5+；
- [MyBatis 3.5.19 Mapper XML](https://mybatis.org/mybatis-3/sqlmap-xml.html)：mapped statement、`#{}`/`${}`、resultMap、嵌套查询与 N+1；
- [MyBatis 3.5.19 Dynamic SQL](https://mybatis.org/mybatis-3/dynamic-sql.html)：`if/choose/where/trim/set/foreach`；
- [MyBatis 3.5.19 Configuration](https://mybatis.org/mybatis-3/configuration)：自动映射、未知列、下划线转换和缓存等默认行为；
- [MyBatis 3.5.19 Logging](https://mybatis.org/mybatis-3/logging.html)：按 mapper/namespace/statement 开启日志；
- [MyBatis-Spring Transactions](https://mybatis.org/spring/transactions.html)：事务由 Spring 边界管理；本章只用于划清非目标；
- [PostgreSQL 18 Error Codes](https://www.postgresql.org/docs/18/errcodes-appendix.html)：诊断 SQLSTATE。

版本补丁、Starter 自动配置细节和 pgJDBC 行为会演进；开始真实项目任务时应重新查看依赖锁和官方发布页。映射合同、参数与结构分离、基数、查询预算和分层诊断属于稳定核心。
