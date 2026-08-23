# Java：Maven 与可重复构建

## 1. Maven 到底在解决什么问题

一个 Java 项目不只有源代码。它还要回答这些问题：

- 源代码和测试代码放在哪里；
- 用哪个 Java 版本编译；
- 需要哪些第三方库，又应该使用哪个版本；
- 先编译、先测试，还是先打包；
- 最后产生 JAR 还是 WAR；
- 在自己电脑和 CI 服务器上，能否得到相同结果。

Maven 把这些约定放进一个可版本管理的项目模型中，再按固定生命周期执行构建。它的主要价值不是“少打几条命令”，而是让项目拥有一套可交流、可自动化、可重复的构建方法。

在 IntelliJ IDEA 里点击“运行”可以编译并启动某个类，但这只是 IDE 帮你执行了一组操作。团队不能只依赖某个人的 IDE 设置。`mvn verify` 这样的命令才能在本地、别人的电脑和 CI 中共用。

专业上，Maven 既是**构建工具**，也负责**依赖管理**和**项目模型**。

## 2. Maven 项目的标准目录

Maven 默认认识这套目录：

```text
project/
├── pom.xml
└── src/
    ├── main/
    │   ├── java/          Java 正式代码
    │   └── resources/     正式资源和配置
    └── test/
        ├── java/          测试代码
        └── resources/     测试资源
```

构建后会出现 `target/`：

```text
target/
├── classes/          正式代码编译后的 .class
├── test-classes/     测试代码编译后的 .class
├── surefire-reports/ 单元测试报告
└── xxx.jar           打包结果
```

`target/` 是可以根据源码重新生成的构建产物，通常不提交到 Git。如果删掉 `target/` 就无法恢复项目，说明某些必要源文件被错放进了构建目录。

标准目录的好处是“约定优于配置”：大部分项目不需要逐项告诉 Maven 源文件在哪里。这叫 **Convention over Configuration**。

## 3. pom.xml：项目的构建说明书

`pom.xml` 是 Maven 读取的主要文件。POM 是 **Project Object Model**，也就是“项目对象模型”。

一个最小化示例大致如下：

```xml
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                             https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.factorycare</groupId>
    <artifactId>work-order-service</artifactId>
    <version>1.0.0-SNAPSHOT</version>

    <properties>
        <maven.compiler.release>25</maven.compiler.release>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
</project>
```

其中三项共同标识一个 Maven 制品：

- `groupId`：组织或项目群，经常使用倒置域名；
- `artifactId`：当前模块或制品名；
- `version`：该制品的版本。

这三项合称**坐标（coordinates）**。依赖另一个库时，本质上就是请 Maven 按坐标找到那个制品。

`SNAPSHOT` 表示开发中的可变版本。已正式发布的版本应被视为不可变：同一坐标不应今天和明天指向不同内容。

## 4. 生命周：一条有顺序的构建流程

Maven 预先定义了一系列阶段（phase）。常用的默认生命周可以简化为：

```text
validate
   ↓
compile
   ↓
test
   ↓
package
   ↓
verify
   ↓
install
   ↓
deploy
```

运行后面的阶段时，前面的阶段也会按顺序执行。例如：

```bash
mvn package
```

不是只把现成 `.class` 压成 JAR，它会先执行必要的资源处理、编译、测试编译和测试，然后才打包。

常用阶段的含义：

| 阶段 | 通俗理解 |
| --- | --- |
| `compile` | 编译正式代码 |
| `test` | 编译并执行单元测试 |
| `package` | 生成 JAR/WAR 等制品 |
| `verify` | 运行打包后才能完成的检查 |
| `install` | 把制品放入本机 Maven 仓库 |
| `deploy` | 把制品发布到团队远程仓库 |

Maven 另有 `clean` 生命周。`mvn clean` 会删除上次的 `target/`，常与默认生命周一起使用：

```bash
./mvnw clean verify
```

这条命令表示：不借用上次留下的产物，从干净状态做完整验证。

## 5. 阶段和插件目标不是同一件事

Maven 的生命周只规定“什么时候做什么类型的事”。具体工作由**插件（plugin）**执行。

例如：

- Compiler Plugin 执行 Java 编译；
- Surefire Plugin 执行单元测试；
- JAR Plugin 生成 JAR；
- Failsafe Plugin 常用于集成测试。

插件内部的一个可执行动作叫**目标（goal）**。例如：

```bash
mvn dependency:tree
```

这里 `dependency` 是插件前缀，`tree` 是插件目标。这是直接调用某个目标，而 `mvn test` 是请 Maven 走到生命周的 `test` 阶段。

一个 goal 可以绑定到某个 phase。这样当生命周走到该阶段时，对应 goal 会自动执行。

这一区分很重要：

- 依赖是项目运行或编译时要使用的库；
- 插件是构建过程中帮 Maven 干活的工具。

把 Compiler Plugin 写在 `<dependencies>` 中，不会因此配置好编译。

## 6. 依赖：项目需要的外部能力

依赖通常写在 `<dependencies>` 中：

```xml
<dependencies>
    <dependency>
        <groupId>org.junit.jupiter</groupId>
        <artifactId>junit-jupiter</artifactId>
        <version>...</version>
        <scope>test</scope>
    </dependency>
</dependencies>
```

Maven 会从仓库下载制品，放入本地仓库，然后在对应阶段加入 classpath。默认本地仓库常在用户目录下的 `.m2/repository`。

本地仓库是缓存和制品存储，不是项目源码的一部分。手动改里面的 JAR 会让本机出现别人无法复现的结果。

### 6.1 直接依赖和传递依赖

项目明确声明 A，A 又需要 B，那么：

- A 是项目的**直接依赖**；
- B 是通过 A 带进来的**传递依赖**。

```text
当前项目 → A → B
```

传递依赖很方便，但不应被当成隐形承诺。如果你的源码直接使用 B 的 API，通常应明确声明 B，否则 A 内部升级并移除 B 后，你的项目会突然无法编译。

### 6.2 版本冲突不是“两份都用”

假设 A 需要 C 1.0，B 需要 C 2.0：

```text
当前项目 → A → C 1.0
          └→ B → C 2.0
```

Maven 会按依赖调解规则选出一个版本进入最终 classpath，并不保证它正好符合你的业务预期。所以出现 `NoSuchMethodError` 或类冲突时，先看：

```bash
./mvnw dependency:tree
```

这个树比“反复换版本试试”更能说明真正的依赖路径。

## 7. scope：依赖在什么范围有效

`scope` 不是给依赖贴一个说明标签，它会真正影响编译、测试、运行和传递性。

| scope | 正式代码编译 | 测试 | 最终运行时 | 常见用途 |
| --- | --- | --- | --- | --- |
| `compile` | 有 | 有 | 有 | 大部分正式依赖，也是默认值 |
| `runtime` | 无 | 有 | 有 | 只在运行时需要的实现，如某些 JDBC 驱动 |
| `test` | 无 | 有 | 无 | JUnit、测试工具 |
| `provided` | 有 | 有 | 由外部环境提供 | 容器或平台已提供的 API |

如果把 JUnit 放在默认 `compile` scope，生产 classpath 会被不必要的测试库污染。如果把正式代码依赖错设成 `test`，可能出现“测试环境看似正常，打包后却启动失败”。

## 8. 统一版本：dependencyManagement 和 BOM

`dependencyManagement` 用来统一规定依赖版本，但它本身不等于“已经引入了这个库”。

```xml
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>com.example</groupId>
            <artifactId>example-library</artifactId>
            <version>2.4.0</version>
        </dependency>
    </dependencies>
</dependencyManagement>
```

子模块或后面的 `<dependencies>` 仍然要声明需要 `example-library`，只是可以不再重复写版本。

当一组库必须使用相互兼容的版本时，它们的维护者往往提供 BOM。BOM 是 **Bill of Materials**，可以理解成“这套组件的版本清单”。Spring Boot 的依赖管理就会统一大量常用库的兼容版本。

使用 BOM 的目标是减少随意拼装的版本组合，不是让人忽略升级影响。一旦要手动覆盖 BOM 中的某个版本，就要确认该组合被框架支持并经过验证。

## 9. 可重复构建不只是“我这里能跑”

可重复构建指的是：在相同源码、锁定的工具与依赖下，不同时间、不同机器应得到等价构建结果。要接近这个目标，需要同时管理：

1. Maven 版本；
2. JDK 版本；
3. 直接和传递依赖版本；
4. 插件版本；
5. 仓库来源和校验；
6. 时区、编码、文件顺序等环境差异；
7. 构建过程中是否暗中访问未固定的网络内容。

### 9.1 Maven Wrapper

Wrapper 把项目期望的 Maven 发行版记录在项目中。团队使用：

```bash
./mvnw clean verify
```

而不是默认每个人全局安装的 `mvn` 都一样。Wrapper 不会自动锁定 JDK，这是另一条维度。

### 9.2 JDK release 与 toolchain

Compiler Plugin 的 `release` 选项约束编译目标：

```xml
<maven.compiler.release>25</maven.compiler.release>
```

它不等于“任意 JDK 都可以构建”。Maven 本身由哪个 JDK 启动，可通过下面命令确认：

```bash
./mvnw -version
```

多 JDK 环境可用 Maven Toolchains 明确选择编译工具链，避免 IDE 用 JDK A、终端 Maven 用 JDK B、CI 又用 JDK C。

### 9.3 插件版本也要可控

Maven 核心版本与插件版本彼此独立。即使锁定 Maven，如果关键插件版本依赖默认推断，构建行为仍可能在环境改变后漂移。

## 10. Profile：选择构建变体，不是隐藏混乱

Maven Profile 可以在特定条件下增加或覆盖一部分构建配置：

```bash
./mvnw verify -Pproduction
```

它适合明确的构建变体，例如是否生成特定类型的文档。但如果每个开发者都必须记住一串不同 Profile 才能构建，项目的默认路径就已经不再可预期。

不要用 Profile 把生产密码写进 POM。构建变体和运行时敏感配置是两个问题，后者应从环境或专用秘密系统注入。

## 11. 多模块项目和 reactor

当系统拆成多个 Maven 模块时，顶层 POM 可以列出模块：

```xml
<packaging>pom</packaging>

<modules>
    <module>factorycare-domain</module>
    <module>factorycare-application</module>
    <module>factorycare-web</module>
</modules>
```

Maven reactor 会收集本次构建的模块，根据模块间依赖确定顺序，然后在一次构建中传递制品。

`parent` 和 `modules` 不是同一个关系：

- 父 POM 表示继承配置；
- aggregator POM 表示这次要一起构建哪些模块。

一个 POM 常常同时承担两种角色，但概念上要分清。这能帮助理解为什么“在顶层构建”和“进入某子模块单独构建”可能产生不同结果。

## 12. 怎样读 Maven 失败日志

Maven 日志很长，但不要只看最后的 `BUILD FAILURE`。它只说明构建失败，不说明原因。

可以按这个顺序定位：

1. 看失败发生在哪个插件和阶段；
2. 向上找第一条具体、可操作的错误；
3. 区分依赖解析、正式代码编译、测试编译、测试执行和打包错误；
4. 再根据错误查相关文件，不要一开始就删缓存或随机升级。

常见信号：

| 日志位置 | 通常说明 |
| --- | --- |
| `...:compile` | 正式源码无法编译 |
| `...:testCompile` | 测试源码无法编译 |
| `...:test` | 测试已启动，断言失败或出现异常 |
| `Could not resolve dependencies` | 依赖坐标、仓库、网络或认证有问题 |
| `UnsupportedClassVersionError` | 编译和运行 JDK 版本边界不一致 |
| `NoSuchMethodError` | 编译期和运行期看到的库版本可能不一致 |

`-e` 可显示异常堆栈，`-X` 会输出大量调试信息。它们是进一步取证用的，不是每次失败都必须打开。

## 13. 把 Maven 放回 FactoryCare 的位置

Maven 不负责决定工单如何计算、Spring 如何注入对象或 SQL 怎样查询。它负责让这些代码和其所需工具能以统一方式被编译、测试和打包。

在 FactoryCare 中可以这样理解整体关系：

```text
pom.xml
  ├── 声明 JDK 和依赖版本
  ├── 配置构建插件
  └── 约定编译、测试、打包和验证流程
            ↓
      产生可部署制品
```

以后看到 `mvn test` 或 `./mvnw verify`，不要把它理解成一道需要机械反复执行的仪式。它的意义是使用项目共识的流程快速确认修改没有破坏已知行为。平时学习时可以由 AI 生成样板或命令，但你需要看懂它改了哪个构建边界，以及失败时去哪一层找证据。

## 14. 阅读完成后应形成的概念地图

这篇不要记成一堆 XML 标签。最重要的关系是：

```text
POM 描述项目
  ├── 项目坐标
  ├── 依赖与 scope
  ├── 插件与版本
  └── 模块和构建配置
           ↓
生命周规定顺序
           ↓
插件 goal 执行具体工作
           ↓
产生通过验证的制品
```

需要牢固区分四对概念：

- 阶段与插件目标；
- 项目依赖与构建插件；
- 直接依赖与传递依赖；
- “本机构建成功”与“构建可重复”。

这些概念会直接支撑后面的 Spring Boot Starter、数据库驱动、测试容器和部署制品。
