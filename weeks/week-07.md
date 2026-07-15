# 第 7 周：Maven 与 Spring Core、DI、配置

## 定位

本周把此前“能运行的 Maven 工程”升级为可解释、可诊断的构建，并用 Spring Core 接管应用对象的创建与装配。重点是依赖方向和构造器注入，不是背注解或依赖容器魔法。

时间预算：15—18 小时。先使用不带 Spring Boot 的 `ApplicationContext` 看清 IoC/DI，再进入第 8 周的自动配置。

## 前置

- JDK 25、Maven 3.9.16 和 `JAVA_HOME` 一致。
- FactoryCare 的纯 Java 领域、仓储接口、内存实现和应用服务测试通过。
- 能解释接口依赖和手工构造对象的组合根。
- 已完成并发阶段，知道容器管理对象不等于对象自动线程安全。

## 目标

- 理解 Maven POM、坐标、生命周期、依赖、插件和版本管理。
- 能使用 `dependency:tree`、`help:effective-pom` 定位依赖问题。
- 固定 Java `release=25`，建立可重复的 Maven Wrapper 和验证命令。
- 理解 IoC、DI、Bean、ApplicationContext 和配置元数据。
- 使用构造器注入、`@Configuration/@Bean` 与组件扫描装配对象。
- 使用环境/Profile 表达可替换配置，但不把 Profile 当密钥仓库。
- 将 FactoryCare 的内存适配器装配迁入 Spring Core，领域模型保持普通 Java。

## 完整概念清单

### Maven 项目模型

- POM、`groupId/artifactId/version/packaging` 坐标。
- 标准目录：`src/main/java`、`src/main/resources`、`src/test/java`。
- Maven 约定优于配置，但目录约定不等于业务架构。
- `validate`、`compile`、`test`、`package`、`verify`、`install`、`deploy` 生命周期阶段。
- phase 与 plugin goal 的区别；执行后续阶段会包含前置阶段。
- 本地仓库、远程仓库和缓存；不随意删除整个本地仓库解决问题。

### 依赖与版本

- compile、runtime、test、provided 等 scope 的传递影响。
- 直接依赖、传递依赖、依赖冲突和 nearest definition 的高层规则。
- `dependencyManagement` 管版本但不自动添加依赖。
- BOM import、parent POM 与普通依赖的区别。
- exclusions 只在理解冲突后使用，不作为清理依赖树的习惯动作。
- 锁定稳定版本；不在同一 POM 为 Spring 管理的库随意覆盖版本。
- `mvn dependency:tree` 和 `mvn help:effective-pom`。

### 插件与可复现构建

- build plugin 与普通库依赖职责不同。
- compiler、Surefire、Failsafe 的高层职责。
- `maven.compiler.release=25` 限定语言和 API 目标。
- Maven Wrapper 让项目固定 Maven 版本；全局 Maven 仍用于理解和初始化。
- `.mvn/maven.config` 每行参数规则和项目级配置。
- Toolchains 能分离运行 Maven 的 JDK 与编译 JDK；当前只有 JDK 25 时不额外引入复杂度。
- `mvn verify` 作为本地和 CI 的统一入口。
- profile 只用于确有差异的构建环境，不复制整套依赖树。

### IoC 与 DI

- IoC：对象不再自己查找/创建所有协作者。
- DI：依赖通过构造器、工厂方法或属性提供。
- `BeanFactory` 与 `ApplicationContext` 的高层关系。
- Bean definition、Bean name、Bean instance、容器生命周期。
- 领域对象通常由业务代码创建，不把每个 WorkOrder 注册为 Bean。
- 构造器注入使必需依赖明确、可测试、可保持 final。
- 字段注入隐藏依赖并妨碍测试，新代码不使用。
- setter 注入只适用于真正可选或可重配置依赖。

### Java 配置与组件扫描

- `@Configuration`、`@Bean`、`@Import`。
- `@Component`、`@Service`、`@Repository` 是候选组件语义标记。
- `@ComponentScan` 的包范围；启动类位置影响扫描。
- 显式 `@Bean` 适合第三方类和基础设施适配器。
- 组件扫描适合稳定应用组件，但不能让依赖来源不可见。
- 同类型多个 Bean 时的歧义；优先调整接口和边界，再考虑 qualifier/primary。

### Bean scope 与生命周期

- singleton 是每个容器一个实例，不是 GoF 全局单例。
- prototype、request、session scope 只了解边界；非 Web 阶段主要使用 singleton。
- singleton Bean 中共享可变字段的并发风险。
- 创建、依赖注入、初始化、销毁的高层顺序。
- `@PostConstruct/@PreDestroy` 只用于资源生命周期，不执行复杂业务。
- 循环依赖通常是设计信号，不通过字段注入绕过。

### 配置与环境

- `Environment`、property source、Profile 的用途。
- 环境差异属于配置，业务规则不应由散落的 `if (profile)` 控制。
- 本地、测试配置和生产配置的边界。
- 配置默认值、必填校验和启动失败优于运行时晚失败。
- 密钥不提交 Git，不写入测试快照或 AI 对话。

## 任务分配

| 模块 | 时间 | 任务 |
| --- | ---: | --- |
| Maven 模型 | 3h | 生命周期、scope、BOM、插件、依赖树和 effective POM |
| 构建固定 | 1.5h | Wrapper、release 25、统一 verify 命令 |
| Spring IoC/DI | 3h | 手工装配与容器装配对照、构造器注入 |
| 配置方式 | 2h | `@Configuration/@Bean`、扫描、Profile、生命周期 |
| FactoryCare | 3—4h | 将应用服务和内存适配器装配进 Spring Core |
| 无 AI 训练 | 2h | 依赖冲突与Bean歧义排查 |
| 求职动作 | 1h | Maven/Spring Core 口述与投递 |

## FactoryCare项目增量

保留现有 domain/application/infrastructure 边界，用 Spring Core 只装配应用级对象：

- `WorkOrderRepository` 仍是应用依赖的接口。
- `InMemoryWorkOrderRepository` 通过显式 `@Bean` 或组件扫描注册。
- `WorkOrderApplicationService` 使用构造器注入，不直接 `new` 仓储实现。
- `Clock` 作为 Bean 注入，测试使用固定 Clock。
- 建立 `LocalConfig` 与 `TestConfig`，仅替换边界依赖，不复制业务服务。
- 编写容器启动测试：关键 Bean 存在、依赖可解析、无循环依赖。

保留一份纯手工组合根测试，与 Spring 装配对照：Spring 降低装配成本，不应让领域和应用逻辑依赖容器 API。

## AI协作边界

可以让 AI：

- 解释 Maven 依赖树、effective POM 和 Bean 创建失败日志。
- 根据现有接口生成 `@Configuration/@Bean` 样板。
- 审查字段注入、循环依赖、过宽扫描和共享可变 Bean。
- 给出冲突排查步骤，但不直接随机升级/降级依赖。

必须由你完成：

- 决定模块依赖方向、哪些对象由 Spring 管理。
- 阅读 POM 中每个直接依赖，说明用途和 scope。
- 用日志确定缺少/重复 Bean 或版本冲突根因。
- 能移除 Spring 配置后手工装配核心用例，证明业务未与容器耦合。

## 无AI训练

本周从求职/复盘时段预留45—60分钟完成并记录：二叉树遍历题；比较递归与显式栈。

关闭 AI，限时120分钟：

1. 新增 `NotificationPort` 和两个候选实现，故意制造同类型 Bean 歧义。
2. 阅读启动错误，采用明确业务命名或配置选择解决，不使用字段注入。
3. 使用 `dependency:tree` 找出一个测试依赖的来源。
4. 解释 parent、BOM、dependencyManagement、直接依赖和插件的区别。
5. 运行 `./mvnw verify` 并说明每个主要阶段做了什么。

## 求职动作

- 准备 Maven 生命周期、scope、依赖冲突、BOM、IoC/DI、Bean scope、构造器注入、循环依赖的回答。
- 用 FactoryCare 从“手工装配”到“Spring 装配”的变化解释 DI 价值。
- 检查 10 个目标岗位使用 Spring Boot 2/3/4 的情况；只记录差异，不为旧版本重做项目。
- 定向投递至少 5 个 Vue+Java 或 Java 应用岗位，记录对商业 Java 年限的真实要求。

## 交付物

- 固定 Maven 3.9.16 的 Wrapper 与可执行 `verify` 构建。
- 清晰的 POM、依赖树和构建说明。
- Spring Core 配置、应用服务和内存适配器装配。
- 容器启动测试和手工组合根对照测试。
- Maven/Bean 故障排查记录。

## 验收标准

- 能解释 Maven 生命周期、goal、scope、BOM、parent、plugin 和 Wrapper。
- `mvn -v`、`./mvnw -v`、compiler release 和 IDE 均使用预期版本。
- 能使用 dependency tree/effective POM 找到依赖来源。
- FactoryCare 使用构造器注入，无字段注入、无循环依赖和无不必要容器 API。
- 能说明哪些对象是 Bean、哪些领域对象不是 Bean，以及理由。
- 测试可替换 Clock/Repository，不依赖生产配置。
- 无 AI 解决 Bean 歧义和一个 Maven 依赖来源问题。

## 明确不做

- 不使用 Spring Boot 自动配置；第 8 周再学。
- 不学习 XML Bean 配置细节、BeanPostProcessor 源码、AOP 代理源码。
- 不拆 Maven 多模块，不引入 Spring Modulith。
- 不使用字段注入、Service Locator 或全局静态容器访问。
- 不连接数据库、Web 服务、Security 或消息队列。

## 官方资料

- [Maven 3.9.16 Reference](https://maven.apache.org/ref/3.9.16/)
- [Maven Lifecycle](https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html)
- [Maven Dependency Mechanism](https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html)
- [Maven Toolchains](https://maven.apache.org/guides/mini/guide-using-toolchains.html)
- [Maven Compiler release](https://maven.apache.org/plugins/maven-compiler-plugin/examples/set-compiler-release.html)
- [Spring Framework Core](https://docs.spring.io/spring-framework/reference/core.html)
- [Spring IoC Container](https://docs.spring.io/spring-framework/reference/core/beans.html)
- [Spring Java Configuration](https://docs.spring.io/spring-framework/reference/core/beans/java.html)
