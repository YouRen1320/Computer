# 第 0 周：学习准备、环境统一与求职基线

## 定位

本周不是“把所有软件都安装一遍”，而是建立一套可复现、可解释、不会互相污染的开发环境。后续 Java 主线统一使用 **JDK 25 LTS + Maven 3.9.16**；Node、Python、Flutter、Docker和服务型依赖只记录现状与目标版本，进入对应阶段时再安装或升级。

当前执行决定（2026-07-15）：求职与简历任务按用户决定延期，不阻塞技术准入；已有环境命令、JUnit红绿测试、受控JDK冲突与恢复记录替代单独的工具链背诵考试。详见[当前执行方案](../STUDY_EXECUTION.md)与[Week 00复盘](../records/week-00/retrospective.md)。

时间预算：8—12 小时，可分散在正式开始前完成。完成环境验收后即可提前结束，不用为了凑时长反复重装。

## 前置

- 一台可正常使用终端和浏览器的 macOS 电脑。
- 能查看并修改自己的 shell 配置，但修改前要保留备份。
- 知道当前工作区为 `/Users/youren/Desktop/Study/Computer`。
- 已安装的工具先检查、记录和复用，不默认卸载或覆盖。
- 若公司设备存在管理策略，先遵守公司软件安装和密钥管理要求。

## 目标

- 命令行、IDE 和 Maven 都使用 JDK 25 LTS。
- 固定 Maven 3.9.16，并能解释 `JAVA_HOME`、`PATH` 和 Maven 所用 JDK 的关系。
- 记录 Node.js、pnpm、Python、uv 与 Flutter 的现状，并写明进入对应阶段时的目标稳定版本。
- 只有近期确实需要运行旧项目时才提前升级相应工具，否则按学习阶段安装。
- 建立环境基线、岗位样本和每周复盘模板。
- 完成Java、SQL、Vue/TypeScript、Python和Flutter五项能力基线，并建立可回滚Git起点；两版事实型简历仅在恢复求职时要求。
- 能独立诊断“终端 Java 是 25，但 Maven/IDE 使用了另一个 JDK”这类常见问题。

截至 2026-07-11 的统一基线如下；以后只跟进同一稳定大版本的安全/维护补丁，不在学习中途追 preview 或 RC：

| 工具 | 本路线基线 | 说明 |
| --- | --- | --- |
| JDK | Temurin 25.0.3 LTS | JDK 25 为 LTS 主线；项目不使用 preview API |
| Maven | 3.9.16 | Maven 4 仍不是本路线的 GA 基线 |
| Node.js | 24.18.0 LTS | 用于后续 Vue/uni-app 工具链 |
| pnpm | 11.10.x | 项目后续通过 `packageManager` 锁定精确版本 |
| Python | 3.14.6 | 使用默认 GIL 构建；AI 科学计算依赖后续逐项验证 |
| uv | 当前稳定版 | 与 Python 3.14 配合，项目后续提交 lockfile |
| Flutter | 3.44.5 stable / Dart 3.12.2 | 截至 2026-07-11 的稳定补丁；实际安装前重新核对 stable archive |

## 完整概念清单

### 版本与支持周期

- LTS、Current、stable、preview、RC、snapshot 的区别。
- 运行时版本、编译目标版本、依赖版本和工具版本不是一回事。
- 全局默认版本与项目固定版本的区别。
- 为什么学习项目选择 JDK 25 LTS，而不追逐每个短周期 JDK。
- 为什么 Spring Boot 使用稳定的 4.1.x，不使用 snapshot 或 milestone。

### shell 与环境变量

- shell、终端、登录 shell 和交互 shell的关系。
- `PATH` 的查找顺序；`which`、`type -a` 和绝对路径。
- `JAVA_HOME` 的作用，以及它与 `java` 命令来源可能不一致的原因。
- macOS 的 `/usr/libexec/java_home -V` 和 `/usr/libexec/java_home -v 25`。
- 修改 `~/.zshrc`、`~/.zprofile` 前为什么要确认加载时机并备份。
- 同一种语言只选一个主要版本管理方案，避免 Homebrew、SDKMAN、nvm、fnm、pyenv 相互覆盖。

### Java 与 Maven

- JDK、JRE、JVM、`javac`、`java` 的职责。
- Maven 安装目录、本地仓库和 `settings.xml` 的基本位置。
- `mvn -v` 输出中的 Maven 版本、Java 版本和 Java home。
- Maven Wrapper 的用途；本周先固定全局 Maven 3.9.16，第 7 周再系统学习 Wrapper 和构建模型。

### 前端、Python 与跨端工具

- Node.js 24 LTS 与包管理器 pnpm 的职责边界。
- `package.json`、lockfile 和全局 CLI 的区别；不全局安装项目依赖。
- Python 解释器、虚拟环境、uv 与项目依赖的关系。
- Flutter SDK、Dart SDK、stable channel、Xcode/Android 工具链之间的关系。
- Flutter“按需安装”的含义：本周没有运行任务时，只记录安装方案，不下载模拟器和完整移动端工具链。

### 可复现与安全

- 版本输出、安装来源、配置变更和验证命令都要记录。
- 不把 token、密码、私有仓库凭据写入 Markdown、shell 历史或 Git。
- AI 给出的安装命令必须理解下载来源、写入位置和回滚方式后再执行。
- 数据库、Redis、消息队列、模型运行时等服务依赖按周引入，不在本周一次装完。

## 任务分配

| 模块 | 时间 | 任务 |
| --- | ---: | --- |
| 现状盘点 | 0.75h | 记录系统、CPU架构、shell、IDE和已装工具版本，不做清理 |
| Java/Maven与烟雾项目 | 2—2.5h | 统一JDK/Maven，并建立一个非Spring的最小Maven+JUnit测试项目 |
| 后续运行时盘点 | 0.5h | 记录Node/pnpm、Python/uv、Flutter、Docker现状和对应安装周次，不提前补齐 |
| 五项能力基线 | 1.5h | 限时完成Java、SQL、Vue/TS、Python、Flutter小测；未安装工具的项用口述/旧项目审查并标未运行 |
| 工作区与Git | 0.75h | 初始化Git、加入忽略规则，建立日志/错题/岗位记录并完成首次可回滚提交 |
| 求职采样与简历 | 2.5—4h | 收集40个岗位、统计关键词，建立Vue/全栈版与Java/AI应用版事实简历基线 |
| 无 AI 验收 | 1—1.5h | 关闭 AI，完成版本冲突诊断和环境口述 |

建议验证命令：

```bash
uname -m
echo "$SHELL"
type -a java javac mvn node pnpm python3 uv flutter
/usr/libexec/java_home -V
java -version
javac -version
mvn -v
node --version
pnpm --version
python3 --version
uv --version
flutter --version
flutter doctor -v
```

Node、pnpm、Python、uv或Flutter尚未按需安装，或者尚未升级到目标大版本时，允许命令不存在或版本暂不一致，但必须在环境基线中记录现状、触发安装的周次和验证方法。

## FactoryCare项目增量

FactoryCare 是后续持续建设的“工业设备运维与智能工单平台”。本周只建立项目准备材料，不生成 Spring、Vue、数据库或 AI 脚手架。

- 写出一句话业务目标：谁在什么场景下，用它解决什么问题。
- 列出三类首批用户：报修人、维修人员、运维管理员。
- 列出最小业务词汇：设备、故障、工单、优先级、处理人、状态、SLA。
- 建立决策记录：为什么选择 JDK 25、Spring Boot 4.1、PostgreSQL 18，以及为什么当前不拆微服务。
- 只规划目录和命名，不提前创建数据库、Redis、前后端服务。

## AI协作边界

可以让 AI：

- 根据你的机器现状解释版本冲突。
- 比较一个版本管理器的安装方案和回滚方式。
- 审查你准备执行的命令是否会覆盖已有环境。
- 根据命令输出生成排查清单。

必须由你完成：

- 决定安装来源和主要版本管理方案。
- 阅读命令，确认是否包含删除、覆盖、远程脚本执行或 shell 配置写入。
- 执行后重新打开终端，逐项验证实际生效版本。
- 保存变更前状态和回滚方法。

禁止：

- 不理解就执行 `curl ... | sh`、带 `sudo` 的远程安装脚本或批量删除命令。
- 把密钥、完整环境变量、私有路径内容直接发给外部模型。
- AI 说“安装成功”就跳过本地验证。

## 无AI训练

关闭 AI，限时 60—90 分钟完成：

1. 画出终端执行 `mvn test` 时，shell、`PATH`、`mvn`、`JAVA_HOME`、JDK 的关系。
2. 人为打开一个未加载正确配置的新 shell，使用 `type -a`、`echo "$JAVA_HOME"`、`java -version`、`mvn -v` 定位不一致来源。
3. 不看笔记解释为什么 `java -version` 正确不代表 Maven 和 IDE 一定正确。
4. 写出恢复旧 shell 配置和切回旧 JDK 的回滚步骤，不实际破坏环境。

## 求职动作

- 收集至少 40 个南昌及可接受周边地区岗位：Java 16 个、Java+Vue/全栈 10 个、Vue/uni-app 8 个、AI 应用或 Python 6 个。
- 记录公司、岗位链接、发布日期、薪资、经验、学历、必选技能、加分技能和行业。
- 将“明确要求”和“职位描述顺手罗列”分开统计。
- 形成第一版关键词频次，不因单个岗位立刻改变路线。
- 建立两版简历标题草案：Vue/全栈版、Java/AI 应用版；本周不伪造新增技能熟练度。

## 交付物

- 环境基线记录：安装来源、版本、路径、验证结果、回滚方式。
- 一份脱敏岗位样本表和关键词统计。
- 五项能力基线结果与缺口清单；无法运行的项目明确标记原因。
- 一个可由`mvn test`运行的非Spring Java烟雾项目。
- Vue/全栈版与Java/AI应用版两份事实型简历基线（恢复求职时交付）。
- Git仓库、忽略规则和第一次可回滚提交。
- FactoryCare 一页业务说明与首份技术决策记录。
- 一份个人学习规则：AI 可以做什么、本人必须验收什么。
- 第 0 周复盘：已确认、仍未确认、下一周阻塞项。

## 验收标准

- `java -version` 与 `javac -version` 都显示 JDK 25 系列。
- `mvn -v` 显示 Maven 3.9.16，且其 Java version/Java home 指向 JDK 25。
- Node/pnpm已安装时记录实际版本；最迟在Week 19升级到当期Node LTS与目标pnpm并完成验证。
- Python/uv已安装时记录实际版本；最迟在Week 27固定Python 3.14当前patch与uv并完成验证。
- Flutter 若安装，必须是 stable 且 `flutter doctor -v` 的必要目标平台无阻塞；若不安装，记录了触发安装的条件。
- 能解释 `PATH` 与 `JAVA_HOME`，并独立定位一个模拟版本冲突。
- 最小Java烟雾项目可通过`mvn test`；五项能力基线均有分数/证据或明确“未运行”。
- 恢复求职后，两版简历只重排真实事实，不把后续计划写成已掌握；当前Git首次提交可以回滚。
- 没有安装 PostgreSQL、Redis、Kafka、Kubernetes、LangChain 等尚未使用的服务或框架。
- 岗位样本可追溯到链接和日期，统计与主观判断分开。

## 明确不做

- 不卸载用户已有工具，除非已确认冲突、影响和回滚方案。
- 不同时使用多个 Node、Python 或 Java 版本管理器。
- 不安装数据库、Redis、MQ、Kubernetes、本地大模型和整套 AI 框架。
- 不初始化 Spring Boot、Vue、Flutter 和 uni-app 全家桶。
- 不优化终端主题、IDE 插件和无关效率工具。
- 不把“所有命令能找到”误认为环境已经一致。

## 官方资料

- [JDK 25 文档](https://docs.oracle.com/en/java/javase/25/)
- [JDK 25 安装指南](https://docs.oracle.com/en/java/javase/25/install/)
- [Apache Maven 3.9.16 发布说明](https://maven.apache.org/docs/3.9.16/release-notes.html)
- [Apache Maven 安装说明](https://maven.apache.org/install.html)
- [Eclipse Temurin 支持周期](https://adoptium.net/support/)
- [Node.js 发布状态](https://nodejs.org/en/about/previous-releases)
- [Node.js 24.18.0 LTS 发布说明](https://nodejs.org/en/blog/release/v24.18.0)
- [pnpm 安装文档](https://pnpm.io/installation)
- [Python 3.14 文档](https://docs.python.org/3.14/)
- [uv 官方文档](https://docs.astral.sh/uv/)
- [Flutter 安装文档](https://docs.flutter.dev/get-started/install)
- [Flutter stable SDK Archive](https://docs.flutter.dev/install/archive)
