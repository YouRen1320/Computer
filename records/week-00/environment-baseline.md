# Week 00 环境基线

- 记录日期：2026-07-12
- 机器：macOS 26.5.2（Build 25F84），Apple Silicon `arm64`
- Shell：`/bin/zsh`
- 记录原则：只记录已验证事实；未来阶段需要时再升级，不因命令存在就视为环境一致。

## 当前工具

| 工具 | 当前实际版本 | 当前实际路径/来源 | 验证结果 | 后续处理 |
| --- | --- | --- | --- | --- |
| JDK | Temurin 25.0.3 LTS | `$HOME` 外的系统 JDK 目录；Homebrew Cask `temurin@25` | `java`、`javac`、Maven、IDEA 测试运行器均已验证使用 JDK 25 | Week 00 主线；保留 Oracle 21 和 Homebrew 26，不卸载 |
| Maven | 3.9.16 | `/opt/homebrew/bin/mvn`；Homebrew formula | `mvn -v` 显示 Temurin 25；`mvn clean test` 成功 | Week 09 再系统学习 Wrapper 与构建模型 |
| IntelliJ IDEA | 2026.1.4 | `/Applications/IntelliJ IDEA.app` | Project SDK 与 JUnit 运行日志均指向 Temurin 25 | Java 后端主 IDE；VS Code 继续用于前端/Python |
| Node.js | 22.14.0（当前命令） | `$HOME/.nvm/versions/node/v22.14.0/bin/node`；NVM | `type -a` 还发现 `/usr/local/bin/node` 与 `/opt/homebrew/bin/node`；Homebrew 另装有 24.9.0、25.9.0 | Week 23 前选择唯一主方案并升级到当期 Node LTS patch |
| pnpm | 10.18.0 | `$HOME/Library/pnpm/pnpm`；用户目录独立二进制 | 当前命令可运行 | Week 23 前升级到当期稳定主版本，并由项目 `packageManager` 锁定精确版本 |
| Python | 3.14.3（当前命令） | `/Library/Frameworks/Python.framework/Versions/3.14/bin/python3`；Python.org Framework | `type -a` 还发现 Homebrew 3.12 与系统 Python | Week 36 固定当时的 Python 3.14 最新补丁并建立 uv 项目环境 |
| uv | 0.11.15 | `$HOME/.local/bin/uv`；用户目录独立二进制 | 当前命令可运行 | Week 36 与 Python 项目一起复验并生成 lockfile |
| Flutter / Dart | Flutter 3.35.7 stable / Dart 3.9.2 | `/opt/homebrew/bin/flutter` 指向 Homebrew Cask | Web/Chrome 可用；Android 缺 cmdline-tools/Android Studio；iOS/macOS 缺完整 Xcode | Week 32 升级 stable 并先验证纯 Dart；Week 34 再按目标平台补齐工具链 |
| Docker CLI | 28.4.0 | `/usr/local/bin/docker` 指向 `/Applications/Docker.app` | 只验证 CLI 版本，未验证 daemon 或容器运行 | 实际需要容器的周次再启动和验证 |

## Java 配置与关系

当前登录 Shell 通过 `~/.zprofile` 设置：

```bash
export JAVA_HOME="$(/usr/libexec/java_home -v 25)"
export PATH="$JAVA_HOME/bin:$PATH"
```

已验证的规则：

- Shell 根据 `PATH` 查找 `java`；
- Homebrew Maven 启动脚本会主动读取 `JAVA_HOME`；
- IDEA 的 Project SDK、Maven Runner 和测试 Runner 是独立配置面，不能只靠终端版本推断；
- `java -version` 正确不代表 Maven 与 IDE 一定正确。

## 已知缺口

- `PATH` 中存在重复目录和多个 Node/Python/Java 候选；当前只记录，不做无关清理。
- Flutter 的 Android、iOS、macOS 原生工具链不完整；当前没有 App 开发任务，不构成 Week 00 阻塞。
- Docker 仅验证 CLI，没有验证 Docker Desktop daemon。
- Node、pnpm、Python、Flutter 尚未升级到课程后续阶段目标版本；按触发周次处理。

## 回滚

- Java 配置修改前备份：`$HOME/.zprofile.factorycare-backup-20260711-192426`。
- 如需回滚 Java Shell 配置，先比较当前 `~/.zprofile` 与备份，再恢复备份内容并新开终端复验。
- Oracle JDK 21、Temurin JDK 25、Homebrew OpenJDK 26 均保留，因此无需重新下载旧版本。
- 本周没有修改 Node、pnpm、Python、uv、Flutter 或 Docker 配置，不存在相应回滚操作。

## 验证命令

```bash
type -a java javac mvn node pnpm python3 uv flutter docker
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
docker --version
```
