# Spring：IoC、Bean、配置与 AOP

## 1. Spring 首先解决的是对象组装问题

一个真实后端服务往往由很多对象协作：

```text
Controller
    ↓
WorkOrderService
    ├── WorkOrderRepository
    └── NotificationPort
```

没有框架时，可以手动创建它们：

```java
WorkOrderRepository repository = new InMemoryWorkOrderRepository();
NotificationPort notification = new EmailNotificationAdapter();
WorkOrderService service = new WorkOrderService(repository, notification);
WorkOrderController controller = new WorkOrderController(service);
```

这段代码没有错，甚至是理解 Spring 的最好起点。问题是当对象数量增加、环境不同、实现需要替换、还有一些对象需要初始化和销毁时，组装代码会分散在应用的各个角落。

Spring 容器接管的就是这件事：

1. 知道系统有哪些对象；
2. 知道每个对象依赖什么；
3. 按依赖关系创建并连接它们；
4. 管理它们的生命周和作用域；
5. 在需要时用代理为调用增加通用行为。

所以 Spring 不是“不需要 `new`”。对象仍然会被创建，只是对象图的组装责任从业务代码移到了容器和配置中。

## 2. IoC：谁控制对象的创建和连接

手动组装时，应用代码自己决定创建什么实现：

```java
class WorkOrderService {
    private final WorkOrderRepository repository =
            new PostgresWorkOrderRepository();
}
```

这使业务服务直接绑定 PostgreSQL 实现。想在测试中换成内存实现，就要修改类本身。

更好的写法是只声明需要什么：

```java
class WorkOrderService {
    private final WorkOrderRepository repository;

    WorkOrderService(WorkOrderRepository repository) {
        this.repository = repository;
    }
}
```

`WorkOrderService` 不再自己创建 repository，而是由外部提供。“控制权从业务对象移到外部组装者”就是**控制反转（Inversion of Control，IoC）**。

IoC 是较大的设计概念；**依赖注入（Dependency Injection，DI）**是实现它的常用方式。“注入”不是把代码塞进对象，而是把该对象已经声明的依赖交给它。

### 2.1 依赖反转与 IoC 不完全相同

依赖反转原则关心的是：高层业务规则不要直接依赖低层技术细节，两者通过抽象连接。

```text
不理想：WorkOrderService → PostgresWorkOrderRepository

更清晰：WorkOrderService → WorkOrderRepository ← MyBatisWorkOrderRepository
```

Spring 容器能帮忙组装后一种结构，但“使用了 Spring”不代表依赖方向自动正确。如果 Service 里到处直接依赖 HTTP、SQL 和框架类，即使它们都由 Spring 注入，边界仍然混乱。

## 3. Bean 和 ApplicationContext

由 Spring 容器创建或注册、并由容器管理的对象叫 **Bean**。普通 `new` 出来的对象仍是 Java 对象，但它不会仅因为位于 Spring 项目中就自动成为 Bean。

`ApplicationContext` 是 Spring 应用中最常见的容器接口。它保存的不只是对象，还包括 Bean 定义、配置环境、事件机制、资源加载等能力。

一个常见过程是：

```text
读取配置和类信息
        ↓
形成 Bean 定义
        ↓
创建所需对象
        ↓
解析并注入依赖
        ↓
执行初始化回调
        ↓
应用开始对外服务
```

不要在业务代码中到处调用 `applicationContext.getBean(...)`。这会把依赖隐藏在方法内，让类又主动回到容器里找东西。这种写法叫 **Service Locator** 风格，通常不如构造器明确。

## 4. 两种常见的 Bean 注册方式

### 4.1 在配置类中明确组装

```java
@Configuration
class WorkOrderConfiguration {

    @Bean
    WorkOrderService workOrderService(
            WorkOrderRepository repository,
            NotificationPort notificationPort
    ) {
        return new WorkOrderService(repository, notificationPort);
    }
}
```

`@Configuration` 表示这是一个配置类，`@Bean` 方法的返回对象交给容器管理。方法参数是容器需要先解析的依赖。

这种方式的优点是组装关系集中且明确，也适合注册无法修改源码的第三方类。

### 4.2 组件扫描

```java
@Service
class WorkOrderService {
    private final WorkOrderRepository repository;

    WorkOrderService(WorkOrderRepository repository) {
        this.repository = repository;
    }
}
```

`@Component`、`@Service`、`@Repository`、`@Controller` 等注解可以让组件扫描发现类并注册 Bean。后三者在“能被扫描”这件事上都是组件，但语义上说明了它们的职责。

扫描范围不正确时，类上即使写了 `@Service` 也可能不会成为 Bean。Spring Boot 常从启动类所在包向下扫描，因此启动类通常放在应用包结构的上层。

### 4.3 不必把所有对象都变成 Bean

领域实体、DTO、值对象和一次请求中临时创建的计算结果，通常不需要变成 Spring Bean。容器适合管理稳定的服务、适配器、配置与基础设施对象，不是要取代 Java 正常的对象创建。

## 5. 为什么优先使用构造器注入

构造器注入会把必需依赖写在类的创建条件中：

```java
@Service
class WorkOrderService {
    private final WorkOrderRepository repository;
    private final Clock clock;

    WorkOrderService(WorkOrderRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }
}
```

它有几个直接好处：

- 类无法在缺少必需依赖的情况下被正常创建；
- 依赖一眼可见；
- 字段可以是 `final`；
- 普通单元测试可以直接 `new`，不需要启动 Spring；
- 构造器参数过多会明确暴露该类职责可能过重。

字段注入将依赖隐藏在反射处理中：

```java
@Autowired
private WorkOrderRepository repository;
```

类似代码短，但对象可先被构造成一个依赖尚未设置的状态，也使离开容器的测试更别扭。所以新代码通常优先构造器注入。

## 6. 容器怎样在多个候选者中选择

如果容器中只有一个 `NotificationPort` Bean，Spring 可以按类型注入。如果同时有邮件和短信两个实现，单看类型就不足以决定：

```text
NotificationPort
  ├── EmailNotificationAdapter
  └── SmsNotificationAdapter
```

常见方法有：

- 根据真正的业务需求只注册一个；
- 用 `@Qualifier` 明确指定候选者；
- 用 `@Primary` 指定默认候选者；
- 需要一组实现时，注入 `List<NotificationPort>` 或映射。

`@Primary` 并不是让其他 Bean 失效，它只在单值注入出现多个候选者时给出优先选择。

启动时发现候选者歧义是一个好的“快速失败”。它比容器随便挑一个、然后在生产中发错短信要安全得多。

## 7. 循环依赖是设计信号

假如 A 的构造器需要 B，B 的构造器又需要 A：

```text
A → B → A
```

容器无法先完整创建任何一个。强行用延迟注入或其他技巧打破环，可能让应用启动，却没有解决责任纠缠。

循环依赖通常提醒：

- 两个类的责任边界可能分错了；
- 其中一个方向应该改成事件或返回值；
- 两者共同需要的能力可能应抽到第三个对象；
- 上下层依赖方向可能被颠倒了。

所以循环依赖应先当作模型问题审查，而不是当作一个需要用注解绕过的框架错误。

## 8. Bean 的生命周

一个 Bean 的常见生命周可以简化为：

```text
实例化
  ↓
设置依赖和属性
  ↓
Bean 后置处理器的初始化前处理
  ↓
初始化回调
  ↓
Bean 后置处理器的初始化后处理
  ↓
对外可用
  ↓
容器关闭时执行销毁回调
```

`@PostConstruct` 或 `@Bean(initMethod = ...)` 可用于初始化，`@PreDestroy` 或 `destroyMethod` 可用于释放对象拥有的资源。

不要把耗时很长、容易失败的全部业务工作都塞进构造器。构造器负责建立对象的基本有效状态；容器初始化也应有清晰的超时、失败和关闭语义。

Spring 中很多 AOP 能力依赖 Bean 后置处理器包装对象。因此在构造器和部分早期初始化阶段，代理尚未完整生效。

## 9. 作用域：容器何时复用或新建 Bean

常用作用域包括：

- `singleton`：在一个 ApplicationContext 中通常只有一个实例；
- `prototype`：每次向容器获取时创建新实例；
- `request`：每个 HTTP 请求一个实例；
- `session`：每个 HTTP Session 一个实例。

Spring 的 `singleton` 指一个容器中的单实例，不是 Java 语言层面、跨 JVM 的绝对唯一对象。

### 9.1 singleton 不代表线程安全

Web 应用中的多个请求可能并发调用同一个 singleton Service。因此它通常应保持无请求状态：

```java
@Service
class WorkOrderService {
    private final WorkOrderRepository repository; // 稳定依赖

    // 不要把 currentUserId、currentRequest 等写进可变字段
}
```

某次请求的参数应通过方法参数、局部变量或受管理的请求上下文传递，不要存进共享 Service 字段。

### 9.2 长作用域捕获短作用域

如果 singleton 在创建时直接拿到一个 prototype，它往往会一直保存初次注入的那个实例，而不是每次方法调用都自动获得新对象。作用域不会穿透普通 Java 字段引用。

这种情况需要重新审视为什么需要短作用域，或使用容器提供的 provider/代理机制在正确时机取值。

## 10. 配置是外部输入，不是代码常量

数据库地址、超时、功能开关等会随环境变化，应从外部配置进入应用，而不是硬编码在 Java 类中。

Spring Boot 可从配置文件、环境变量、系统属性和命令行参数等来源读取配置。当同一属性出现在多个来源中时，会按明确的优先级覆盖。

学习时不必死记完整优先级表，但要有这个模型：

```text
默认配置
   被更具体的环境配置覆盖
   又可被更高优先级的显式输入覆盖
```

出现“我明明改了配置却没生效”时，要查实际有效值的来源，而不是只看某个 YAML 文件。

### 10.1 类型安全的配置

相关配置可以映射为一个类型：

```java
@ConfigurationProperties("factorycare.notification")
public record NotificationProperties(
        boolean enabled,
        Duration timeout,
        URI endpoint
) {}
```

这比在各处用字符串 key 分别读取更清晰：配置有名称空间、类型和统一校验点。不合法的 URI 或时长可以在启动时失败，而不是第一个真实请求到来后才暴露。

### 10.2 Profile 是一组环境选择

Spring Profile 可以让某组 Bean 或配置只在特定环境生效。它常用于开发、测试或特定部署环境，但不应演变成大量相互覆盖、无人知道最终结果的隐藏分支。

敏感值不应进入 Git，无论它是放在默认文件还是 `application-prod.yml`。“用了 prod Profile”不会把明文密码变安全。

## 11. Spring Boot 做了哪些事

Spring Framework 提供 IoC、AOP、Web、数据访问等基础能力。Spring Boot 在其上提供一套常用组合、默认配置、应用启动和运行约定，让人不必从空白处把所有组件手动拼起来。

### 11.1 Starter 是经过组织的依赖入口

例如 Web Starter 会带入构建 Web 应用常用的一组依赖。Starter 主要解决“一般需要哪些库”，它不是一个神秘的运行引擎。

### 11.2 自动配置是有条件的默认组装

自动配置会根据 classpath、已有 Bean、配置属性等条件，提供合理默认值。可以把它理解成：

```text
如果存在某个库
并且用户没有自己定义对应 Bean
并且相关配置允许
那么提供一个默认 Bean
```

它不是“Spring 猜中了你的代码”，而是一组可检查的条件配置。当自动配置未生效时，应看条件评估报告和启动错误，而不是根据注解名称猜测。

### 11.3 用户配置与默认配置的关系

很多自动配置会在用户自己提供对应 Bean 后“后退”。这让默认值方便，同时保留显式定制能力。但定义了同类型 Bean 却不理解自动配置的条件，可能意外替换整套默认行为。

## 12. 从 HTTP 请求看容器与线程边界

传统 Servlet Web 应用中，一个请求大致经过：

```text
客户端
  ↓
Web 服务器接收请求
  ↓
Filter 链
  ↓
Spring MVC 的 DispatcherServlet
  ↓
Controller → Service → Repository
  ↓
生成响应并返回
```

容器会将请求分配给执行线程。对于一般同步 Servlet 代码，这条线程在方法返回前为该请求执行代码。但 singleton Controller 和 Service 会被多条请求线程共享。

`HttpServletRequest` 等请求对象的有效性受请求生命周约束。不要将它保存到 singleton 字段，也不要在请求已完成后由另一个线程随意继续读取。

Filter 中如果不调用后续链，请求就会在当前 Filter 终止；这可以是认证拒绝的有意行为，也可以是遗漏调用造成的错误。

## 13. AOP：给一批方法调用加上通用行为

事务、授权、计时、重试等能力往往需要包围一个方法调用：

```text
调用前：开始计时
  ↓
执行业务方法
  ↓
调用后：记录耗时或错误
```

如果每个 Service 方法都手写一遍，通用逻辑会与业务逻辑交错。**面向切面编程（AOP）**允许将横跨多个业务对象的行为集中表达。

主要术语：

- **切面（aspect）**：一组横切行为的定义；
- **通知（advice）**：在目标调用之前、之后或环绕它执行的代码；
- **连接点（join point）**：可被介入的程序执行点，Spring AOP 主要关注方法调用；
- **切点（pointcut）**：选择哪些调用应该被介入的规则。

这些术语的核心只是两个问题：“选中哪些方法调用”，以及“在调用周围做什么”。

## 14. Spring AOP 的代理模型

Spring AOP 常通过代理完成：外部拿到的 Bean 引用实际上指向一个代理对象，代理先执行通用逻辑，再调用真正的目标对象。

```text
外部调用者
    ↓
Spring 代理
    ├── 通知：开启事务/授权/计时
    ↓
目标对象的业务方法
    ↓
Spring 代理
    └── 通知：提交、回滚或记录结果
```

因为调用需要经过代理，所以会出现重要边界。

### 14.1 同类自调用可能绕过代理

```java
class WorkOrderService {
    void outer() {
        inner();
    }

    @SomeAspectAnnotation
    void inner() {
        // ...
    }
}
```

外部通过代理调用 `outer()` 后，`outer()` 内的 `inner()` 是目标对象对自己的直接调用，没有再经过外层代理。因此只标在 `inner()` 上的事务、重试或其他代理通知可能不生效。这叫 **self-invocation（自调用）**边界。

通常的根本解法是调整用例边界，把需要独立代理语义的行为放到另一个 Bean，而不是让对象从容器中反向获取自己的代理。

### 14.2 private、final 和代理方式

代理必须有机会拦截调用。私有方法不是对外调用边界；基于子类的代理也无法覆盖 `final` 方法。所以不能只看注解是否写上，还要看这次调用是否真正经过代理。

### 14.3 不要吞掉业务异常

环绕通知必须正确返回目标方法结果，也应在记录后将原有异常继续抛出。如果通知捕获异常后返回 `null`，上层可能以为业务正常完成，事务回滚和错误映射也可能被破坏。

## 15. 常见错误应该从哪里看

### 15.1 找不到 Bean

先看：

- 类是否真的被注册；
- 组件扫描是否覆盖该包；
- 配置类是否进入当前上下文；
- Profile 或条件是否使它未生效；
- 需要的是否是错误的类型或泛型。

### 15.2 同类型 Bean 太多

不要随便加 `@Primary` 平息错误。先确认两个实现是否都应同时注册，然后再根据业务含义选择 qualifier、集合注入或条件配置。

### 15.3 注解写了但行为没出现

先问当前对象是不是容器管理的 Bean，调用是否经过代理，方法可见性和代理方式是否允许拦截。这比反复重启 IDE 更接近真正原因。

## 16. 把整篇连成一张图

```text
应用启动
  ↓
Spring Boot 读取环境和配置
  ↓
Starter + 自动配置 + 用户配置
  ↓
ApplicationContext 建立 Bean 定义
  ↓
创建 Bean、构造器注入、生命周处理
  ↓
需要横切能力的 Bean 被包装成代理
  ↓
应用接收 HTTP 请求
  ↓
多条请求线程共同调用无请求状态的 singleton Bean
```

这里最重要的不是背注解，而是保持四个心智模型：

1. Spring 是在组装 Java 对象，不是取代 Java 对象模型；
2. 依赖应对外明确，构造器注入是默认好选择；
3. Bean 作用域决定实例共享方式，不自动带来线程安全；
4. Spring AOP 常经过代理生效，所以必须理解外部调用、自调用和方法边界。

后面的 Spring MVC、事务、安全和缓存都会继续使用这些底层模型。
