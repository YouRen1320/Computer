# Week 00 系统讲义

## 1. 环境不是“装好了”，而是一组可验证关系

开发环境至少包含四层：

1. **终端与 shell**：终端是窗口程序，shell 是读取并执行命令的进程；
2. **命令解析**：shell 根据 alias、function、builtin 和 `PATH` 找到可执行文件；
3. **工具自身配置**：Maven、IDE、版本管理器可以选择与 shell 不同的 JDK；
4. **项目约束**：构建文件、wrapper、lockfile、CI 镜像决定项目实际使用什么。

所以，“我输入 `java -version` 是 25”只能证明当前 shell 找到的 `java` 是 25，不能证明：

- `javac` 来自同一个 JDK；
- `mvn` 启动时使用同一个 Java home；
- IDE 的 Project SDK、Maven Runner 和测试 Runner 都是 25；
- CI 或另一台机器也使用相同版本。

### TypeScript/Vue 类比

可以把 `java` 与项目 JDK 的差异类比为：全局 `node --version` 正确，并不代表某个项目使用的 pnpm、lockfile、CI Node 镜像都正确。这个类比有助于理解“全局工具”和“项目工具”的区别。

类比失效处：Java 编译产物、字节码版本和 JVM 运行时有明确兼容约束；前端工具链的转译、bundle 和浏览器运行环境是另一套兼容模型，不能把 `target`、JDK 和浏览器 target 机械对应。

## 2. 版本语义与支持周期

### 常见标签

| 标签 | 含义 | 学习项目策略 |
| --- | --- | --- |
| GA/stable | 正式稳定发布 | 可以作为基线 |
| LTS | 获得较长期维护的正式版本 | Java 主线优先 |
| Current | 当前功能线，支持期可能短 | 只在有明确收益时采用 |
| preview | 需要显式启用、未来可能变化 | 本项目不使用 |
| RC | 发布候选，仍可能变化 | 不作为主线 |
| milestone/beta | 里程碑或测试版 | 不作为主线 |
| snapshot/nightly | 持续构建，复现性弱 | 禁止作为主线 |

本路线在 2026-07-11 锁定 JDK 25 LTS 和 Maven 3.9.16。锁定的是**大版本和本阶段的精确基线**，不是永远拒绝安全补丁。升级必须回答：为什么升、兼容风险、验证命令、回滚方式。

### 四种容易混淆的版本

- **运行时版本**：真正执行程序的 JVM/Node/Python；
- **编译目标**：生成产物允许在哪个目标运行时运行；
- **构建工具版本**：Maven、pnpm、uv 等；
- **依赖版本**：JUnit、Spring、Vue 等库。

它们互相关联但不是同一个旋钮。看到“项目使用 Java 25”时，要继续问：开发 JDK、编译 release、CI JDK 和生产 JVM 是否一致？

## 3. shell、登录方式与环境变量

### 终端、shell、登录 shell、交互 shell

- Terminal/iTerm/Codex terminal 是承载输入输出的应用；
- zsh/bash 是解释命令的 shell；
- 登录 shell 与交互 shell加载的配置文件可能不同；
- IDE 从 Dock 启动时，继承的环境可能与终端启动不同。

这解释了“终端正确，IDE 错误”或“旧窗口错误，新窗口正确”。修改 `~/.zshrc` 后，旧进程不会自动忘记旧环境。

### 命令查找

建议按以下顺序取证：

```bash
type -a java javac mvn
which java
echo "$PATH"
echo "$JAVA_HOME"
/usr/libexec/java_home -V
java -version
javac -version
mvn -v
```

`type -a` 比单独 `which` 更有信息量，因为它能显示多个候选、alias 或 function。`PATH` 从左到右查找；同名可执行文件靠前者胜出。

### `JAVA_HOME` 与 `PATH`

- `JAVA_HOME` 通常指向一个 JDK 根目录；
- `PATH` 中的 `$JAVA_HOME/bin` 决定 shell 优先找到哪些 Java 命令；
- 二者可以不一致，例如 `PATH` 先命中 Homebrew 链接，但 `JAVA_HOME` 指向 Temurin；
- Maven 的 `mvn -v` 会报告它实际使用的 Java version 与 Java home，这是最终证据之一。

一个可读的配置思路是先求出 JDK 路径，再把其 `bin` 放到 `PATH` 前部。实际写入哪个配置文件，要根据 shell 的启动方式确认，不能无脑复制。

## 4. JDK、JRE、JVM 与工具链

### 职责边界

- **JVM**：加载并执行字节码，管理运行时内存和线程等；
- **JRE**：运行 Java 程序所需的 JVM 与标准运行库概念集合；
- **JDK**：包含开发工具，如 `javac`、`java`、`javadoc`、`jar`；
- **`javac`**：把 `.java` 源码编译为 `.class` 字节码；
- **`java`**：启动 JVM 并运行主类、模块或 jar。

本阶段不钻研 JVM 实现，只建立一条可复述链路：

```text
源码 .java → javac 编译 → 字节码 .class → java 启动 JVM → 类加载与执行
```

### JDK 发行版

Java 规范和 OpenJDK 实现生态中存在 Temurin 等发行版。学习项目选择一种可信发行版并记录来源即可，不要把“发行版选择”变成无限比较。最重要的是支持周期、CPU 架构、来源、校验和团队一致性。

## 5. Maven 的最小心智模型

Week 00 只需要知道：

- Maven 读取 `pom.xml`；
- 依赖通常下载到本地仓库；
- 插件负责编译、测试、打包等构建动作；
- `mvn test` 会经过若干生命周期阶段并运行测试；
- `mvn -v` 报告 Maven 自身版本及其启动 JVM；
- `settings.xml` 可能影响镜像、代理、仓库与认证，不能随意公开；
- Maven Wrapper 可以把项目构建工具版本项目化，但系统学习放在 Week 09。

### 与 pnpm 的类比及失效

`pom.xml` 类似 `package.json`，本地仓库有点像包缓存，插件有点像 scripts/构建插件。类比只能帮助入门。

失效处：Maven 生命周期、依赖 scope、Java 编译/测试插件模型与 npm scripts 不同；Maven 本地仓库也不是项目 `node_modules` 的等价物。不要据此猜 Maven 行为。

## 6. IDE 可能有多套 JDK

常见选择点包括：

- IDE 自身运行时；
- Project SDK；
- Module SDK；
- Maven importer/runner JDK；
- JUnit test runner；
- 终端内 shell 的 JDK。

无需强求 IDE 自身运行时也改成项目 JDK，但**编译、Maven 和测试**必须与项目基线一致。验证应以 IDE 设置、构建日志和实际运行结果为证据，不以界面看起来“选中了”作为唯一证据。

## 7. Node、Python、Flutter 为什么按需安装

### Node 与 pnpm

Node 是 JavaScript 运行时；pnpm 是包管理器。项目最终应通过 `packageManager` 字段和 lockfile 锁定包管理器与依赖。全局 CLI 不应替代项目依赖。

### Python 与 uv

Python 解释器、虚拟环境和项目依赖是三层。uv 可以管理项目环境和锁文件，但不意味着系统 Python 应被覆盖。AI 阶段才验证科学计算依赖对 Python 3.14 的真实支持。

### Flutter 与 Dart

Flutter SDK 包含配套 Dart SDK，但真机构建还依赖 Xcode/Android 工具链。`flutter doctor -v` 报告的是目标平台的完整链路；若本周不开发移动端，只记录现状与 Week 34 的安装触发条件。

一次安装所有工具的代价是：冲突面扩大、磁盘与维护成本上升、错误无法归因。按需安装不是拖延，而是让每次变更都有真实用例和验收。

## 8. 可复现、可回滚与 Git 起点

每次环境变更至少记录：

- 变更前版本与路径；
- 安装来源和 CPU 架构；
- 执行的命令；
- 修改的配置文件；
- 新终端、Maven、IDE 的验证结果；
- 如何恢复旧配置或切回旧版本。

Git 能回滚工作区文件，不能自动回滚 Homebrew 包、系统配置或 IDE 设置。因此环境记录不能只写“已经提交 Git”。

`.gitignore` 应排除 IDE 临时文件、构建产物和本地密钥，但不要用宽泛规则误排学习证据。提交前使用 `git status` 和 `git diff --staged` 人工确认。

## 9. 基线不是考试成绩包装

Java、SQL、Vue/TS、Python、Flutter 五项基线的目的，是确认起点：

- **可运行**：保存命令、测试或截图证据；
- **未运行**：明确缺少环境或时间，不猜分；
- **可解释**：记录口述能否完成；
- **缺口**：写下一步行动，不写人格评价。

岗位采样也必须区分“职位明确必选”“加分项”“招聘模板顺手罗列”。40 条样本用于降低单个 JD 的噪声，不代表样本已能证明整个市场。

## 10. AI 使用安全

安装命令的风险常来自：

- `curl ... | sh` 未检查远程脚本；
- `sudo` 扩大权限；
- `rm -rf` 或覆盖式重定向不可逆；
- 修改 shell 配置却没有备份；
- 把 token、代理、私有仓库凭据贴入模型或仓库；
- AI 根据过期文档给出不存在的版本或参数。

安全流程是：先读官方资料，理解下载源和写入位置，写回滚，再执行小步变更，最后本地取证。AI 的“成功”陈述不是机器状态证据。

## 常见错误清单

- 只看 `java -version`，不看 `javac -version` 和 `mvn -v`；
- 在 `.zshrc`、`.zprofile`、IDE 和版本管理器里重复设置；
- 同时使用 Homebrew、SDKMAN 和手工软链接管理同一 JDK；
- 修改配置后只在旧终端验证；
- 把 `settings.xml`、`.env`、token 或完整内部路径提交仓库；
- 把“命令不存在”一律当错误，而不看是否到达安装周次；
- 为了显得环境完整提前安装数据库与 AI 框架；
- 用一两个岗位决定改学另一整套技术栈；
- 在简历中把学习计划写成已经掌握。

## 官方资料

- [JDK 25 文档](https://docs.oracle.com/en/java/javase/25/)
- [JDK 25 安装指南](https://docs.oracle.com/en/java/javase/25/install/)
- [Temurin 支持周期](https://adoptium.net/support/)
- [Maven 3.9.16 发布说明](https://maven.apache.org/docs/3.9.16/release-notes.html)
- [Maven 安装](https://maven.apache.org/install.html)
- [Node.js 发布状态](https://nodejs.org/en/about/previous-releases)
- [pnpm 安装](https://pnpm.io/installation)
- [Python 3.14 文档](https://docs.python.org/3.14/)
- [uv 文档](https://docs.astral.sh/uv/)
- [Flutter 安装](https://docs.flutter.dev/get-started/install)
- [Git 文档](https://git-scm.com/docs)

完成讲义后去做[实验](./labs.md)，不要先看[答案册](./answers.md)。
