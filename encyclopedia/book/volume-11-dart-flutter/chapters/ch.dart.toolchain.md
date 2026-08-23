---
schema_version: 2
edition: 2026.2-draft
id: ch.dart.toolchain
title: Dart SDK、CLI、pubspec 与包工具
responsibility: 建立 Dart SDK、dart CLI、pubspec、依赖锁定和源码入口的可重复运行链，不在本章教授语言类型或 Flutter。
volume: '11'
order: 1
level: L1
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.dart.toolchain.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.foundations.dependencies-build-packages
version_surfaces:
- dart-stable
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“Dart SDK、CLI、pubspec 与包工具”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - dart-sdk-cli
  - dart-pub-package
  covers_topics:
  - dart.sdk-resolution
  - dart.cli-run
  - dart.cli-analyze
  - dart.cli-format
  - dart.pubspec
  - dart.pub-dependency
  - dart.package-layout
  - dart.lockfile
  uses_capabilities:
  - foundation.shell-command-stream
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“Dart SDK、CLI、pubspec 与包工具”构建可运行程序与测试：从空目录建立可重复 analyze/run 的 Dart 包并记录 SDK 与锁文件证据；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - dart-sdk-cli
  - dart-pub-package
  covers_topics:
  - dart.sdk-resolution
  - dart.cli-run
  - dart.cli-analyze
  - dart.cli-format
  - dart.pubspec
  - dart.pub-dependency
  - dart.package-layout
  - dart.lockfile
  uses_capabilities:
  - foundation.shell-command-stream
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: version-evidence-dart-run-exit-code
- id: diagnose
  kind: fault-diagnosis
  text: 面对“PATH 解析到错误 SDK、pubspec 缩进或包导入路径错误”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - dart-sdk-cli
  - dart-pub-package
  covers_topics:
  - dart.sdk-resolution
  - dart.cli-run
  - dart.cli-analyze
  - dart.cli-format
  - dart.pubspec
  - dart.pub-dependency
  - dart.package-layout
  - dart.lockfile
  uses_capabilities:
  - foundation.shell-command-stream
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# Dart SDK、CLI、pubspec 与包工具

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《依赖、包管理、构建生命周期与可重复性》](../../volume-00-computer-foundations/chapters/ch.foundations.dependencies-build-packages.md)：pubspec、锁文件与包解析必须建立在可复现依赖和构建制品合同上。
<!-- END GENERATED LEARNING PREREQUISITES -->

第一次写 Dart 时，最容易把“编辑器没有红线”“终端能执行 `dart`”“Flutter 能启动”当成同一件事。它们不是同一件事。编辑器可能连接一个 SDK，终端的 `PATH` 可能命中另一个 SDK，Flutter 又自带一份 Dart；旧缓存还可能让缺少声明的依赖暂时可用。于是同一份源码在甲的电脑运行、乙的电脑分析失败，CI 又解析到不同版本。

本章先建立一条可复现工具链：**解析实际工具 → 记录 SDK 版本 → 读取 pubspec → 解析依赖 → 检查格式 → 静态分析 → 运行入口 → 保存退出码和输出**。后续类型、集合、面向对象和 Flutter 都依赖这条链。此处不讲语言类型细节，也不把 Flutter 工程、Android Studio、Xcode 混进纯 Dart 起步实验。

## 1. 先画清职责边界

### 1.1 Dart SDK 是工具集合

Dart SDK 不只是一个运行程序。它包含 Dart 虚拟机、核心库、分析器、格式化器、编译相关工具和统一命令入口。你在终端输入 `dart`，实际启动的是某个文件系统路径中的可执行文件；这个文件所属的 SDK 决定可用的语言版本和工具行为。

“安装了 Dart”至少还缺三条证据：

1. 当前 shell 解析到哪个 `dart`；
2. 该可执行文件报告什么版本、通道和平台；
3. 项目 `pubspec.yaml` 的 SDK 约束是否接受该版本。

### 1.2 `dart` CLI 是统一入口

常用命令可以按职责分组：

| 命令 | 回答的问题 | 不证明什么 |
| --- | --- | --- |
| `dart --version` | 当前可执行文件报告的版本与平台 | 不证明 IDE、Flutter 或 CI 使用同一份 SDK |
| `dart create` | 按模板创建项目文件 | 不证明业务需求正确 |
| `dart pub get` | 解析并取得符合约束的依赖 | 不证明源码能分析或测试通过 |
| `dart format` | 按格式器规则重写或检查源码 | 不证明类型和业务逻辑正确 |
| `dart analyze` | 运行静态分析器 | 不执行运行时分支 |
| `dart run` | 解析包上下文并运行入口 | 一次成功不代表所有输入都正确 |

命令能执行只证明到达对应阶段。完整验证必须看命令、工作目录、输入文件、退出码和关键输出。

### 1.3 pub 与 pubspec 的边界

pub 是 Dart 的包管理工具；`pubspec.yaml` 是包的声明清单。清单描述包名、SDK 约束、依赖与元数据，pub 根据清单、锁文件、缓存和包源完成解析。清单不是下载目录，锁文件也不是源码入口。

### 1.4 本章明确不做

- 不解释 `String`、`int`、nullable 等类型语义；下一章负责。
- 不介绍 `if`、循环、函数合同；控制流章节负责。
- 不创建 Flutter 工程，不安装模拟器，不处理 iOS/Android 构建。
- 不用全局缓存命中冒充冷机器可复现。
- 不把 `dart run` 成功冒充单元测试通过。

## 2. 版本事实：官方稳定与本机运行要分开

本章资料核对日期为 **2026-07-24**。Dart 官方稳定档案接口在该日返回：稳定版 **3.12.2**，归档日期 2026-06-09，revision 为 `d684a576a6aa954ae107a03b2b4e1d61c3bebe93`；dart.dev 当前页面也声明文档默认反映 Dart 3.12.2。本机实际运行验证使用的是 **Dart 3.9.2 stable / macOS arm64**，来自现有 Flutter 安装链。

这两组事实不能合并：

- “官方稳定 3.12.2”是会随补丁更新的**版本表面**；
- “本机 3.9.2”是本次资产验证的**运行证据**；
- 包布局、退出码、清单/锁文件职责是跨补丁稳定的**核心概念**；
- Dart 3.10 的 `dart install`、3.11 的 workspace glob、3.12 的私有命名参数等属于版本特性，不能倒推为 3.9 已支持。

学习者无需为了阅读本章立即升级全局 Flutter。进入正式 Dart 周时再统一 SDK，并在升级前记录旧版本与回滚位置。示例把 SDK 下界设置为 3.9，只使用两版本共同支持的稳定语义；它们通过本机 3.9.2 验证，不声称已经由 3.12.2 再跑一次。

## 3. shell 怎样找到 `dart`

在 zsh 中，命令名通常按 `PATH` 从左向右查找，但 alias、shell function、哈希缓存和绝对路径也会影响结果。建议按下面顺序取得证据：

```bash
echo "$SHELL"
type -a dart
command -v dart
dart --version
```

`type -a` 会展示所有候选或说明命令其实是 alias/function；`command -v` 给出当前会执行的候选；版本输出确认该候选自报身份。若要追踪符号链接，再使用平台合适的 `ls -l` 或 `readlink`，不要仅凭 `/opt/homebrew/bin/dart` 这样的表面路径推断最终 SDK 根目录。

### 3.1 Flutter 自带 Dart

Flutter SDK 包含与该 Flutter 版本配套的 Dart SDK。安装 Flutter 后，PATH 中的 `dart` 很可能来自 Flutter 目录；这不是错误，但必须记录。纯 Dart 项目可以使用它，只要包的 SDK 约束兼容。问题出在团队成员有人用 Flutter 内置 Dart、有人用独立 Dart，且没有约束、版本证据和 CI 基线。

检查时并排记录：

```bash
command -v dart
dart --version
command -v flutter
flutter --version
```

不要从 `flutter --version` 中只抄 Flutter 版本而漏掉其 Dart 版本，也不要认为两条命令路径相邻就一定属于同一安装；以实际输出和解析路径为准。

### 3.2 临时 PATH 实验

如果把一个伪造的 `dart` 放在 PATH 最前面：

```bash
PATH="/tmp/fake-bin:$PATH" command -v dart
```

子命令会优先解析临时目录。这个实验说明环境变量只影响相应进程及其子进程，父 shell 不会被子进程反向修改。诊断版本冲突时，应先观察解析结果，再修改配置；不要一上来删除某个 SDK。

### 3.3 shell 与 IDE 可能不同

从 Dock 启动的 IDE、从终端启动的 IDE、登录 shell 和非登录脚本可能读取不同配置。IDE 还可能在设置中显式选择 SDK。因此终端证据不能自动替代 IDE 证据。后续 Flutter 章节会单独校验 IDE/Flutter/平台工具，本章只保证 CLI 包链。

## 4. 从空目录建立最小 Dart 包

官方工具可以创建控制台项目：

```bash
mkdir -p practice
cd practice
dart create -t console factorycare_dart_smoke
cd factorycare_dart_smoke
```

模板内容会随 SDK 版本变化，因此教材不把某一版生成文件列表当永恒合同。你也可以手工建立最小应用包：

```text
factorycare_dart_smoke/
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
├── bin/
│   └── main.dart
└── lib/
    └── work_order_label.dart
```

`pubspec.yaml` 位于包根；`bin/` 放可执行入口；`lib/` 放其他包能够通过 `package:` URI 引用的公开库；`pubspec.lock` 记录应用的一次解析结果；`.dart_tool/` 是工具生成的本地状态，通常不提交。

## 5. 逐行读懂 `pubspec.yaml`

一个无外部依赖的教学应用可以写成：

```yaml
name: factorycare_dart_smoke
description: FactoryCare pure Dart smoke package.
version: 1.0.0
publish_to: none

environment:
  sdk: ">=3.9.0 <4.0.0"
```

### 5.1 `name`

包名参与 `package:` 导入，例如：

```dart
import 'package:factorycare_dart_smoke/work_order_label.dart';
```

目录名可以不同，但随意不同会增加认知成本。包名应符合 pub 命名规则；修改名称后，旧导入不会自动成为新名称。

### 5.2 `environment.sdk`

SDK 约束表达可接受的语言/工具范围。`>=3.9.0 <4.0.0` 表示 3.9.0 及以上、4.0.0 以前。它不是“自动安装 3.9”，也不锁定精确补丁。若源码使用 3.12 才有的语言特性，下界仍写 3.9，就是合同撒谎；CI 应覆盖声明的下界或收紧约束。

### 5.3 `publish_to: none`

私有应用不准备发布到 pub.dev 时可明确禁止误发布。它不提供访问控制，也不保护源码秘密，只是发布工具的配置。

### 5.4 `dependencies` 与 `dev_dependencies`

运行时或库 API 需要的直接依赖放 `dependencies`；只用于测试、分析、代码生成等开发阶段的工具通常放 `dev_dependencies`。是否进入最终产物由平台与构建方式决定，不能只凭字段名猜包体。

```yaml
dependencies:
  some_runtime_package: ^1.2.0

dev_dependencies:
  some_test_package: ^2.0.0
```

示例不写真实包名，避免把虚构版本当官方建议。添加依赖前，应查官方包页面、维护状态、平台支持、许可证和版本约束，再运行 `dart pub get` 审查锁文件差异。

### 5.5 YAML 缩进就是语法

YAML 用缩进表达层级，Tab、错层、重复键都可能让解析失败或产生不同结构：

```yaml
environment:
sdk: ">=3.9.0 <4.0.0" # 错：sdk 没有位于 environment 下
```

遇到 pubspec 错误，先看 pub 输出指出的行列，再查看原始文件，不要因 IDE 自动折叠而猜测。修复后重跑同一条 `dart pub get`，而不是改用另一条绕过命令。

## 6. 包目录与导入规则

### 6.1 `bin/`：应用入口

命令行应用通常从 `bin/*.dart` 启动：

```bash
dart run bin/main.dart
```

入口必须有顶层 `main()`。`dart run` 在包上下文中解析依赖和 `package:` URI。直接把某个文件交给不同工具运行，得到的包解析环境可能不同；学习证据要固定命令和工作目录。

### 6.2 `lib/`：可导入库

只有 `lib/` 下的内容属于包的库表面。常见约定是公开入口放 `lib/package_name.dart` 或若干公开库文件，内部实现放 `lib/src/`。外部包通常不应直接导入别人的 `lib/src/`，因为那表示依赖未承诺的内部结构。

### 6.3 `test/` 与 `example/`

`test/` 放自动化测试，`example/` 放展示包用法的示例。测试框架、断言和覆盖率在 Dart 测试章节系统学习。本章的验证资产使用进程退出码和确定输出，不提前把测试库当工具链必需项。

### 6.4 `package:` 与相对导入

包内跨公开边界优先使用 `package:包名/路径.dart`，这样含义稳定且明确依赖哪个包。紧邻的内部实现有时可用相对导入，但项目应形成一致规则。下面的错误不是“忘了安装 Dart”：

```dart
import 'package:factorycare_dart_smoke/does_not_exist.dart';
```

如果文件不存在，分析器会在 URI 上报告问题。首个可信位置是导入声明和诊断代码，不应先清空全部缓存。

## 7. `dart pub get` 到底生成了什么

执行：

```bash
dart pub get
```

pub 读取清单和现有锁文件，解析直接与传递依赖，从允许来源或缓存取得包，写入/更新 `pubspec.lock`，并在 `.dart_tool/package_config.json` 中建立包名到位置的映射。源码中的 `package:` 导入依赖这份解析结果。

### 7.1 `get` 与 `upgrade`

官方文档说明：存在锁文件时，`dart pub get` 会尽量使用已锁版本；`dart pub upgrade` 则尝试在约束内选择较新的版本并更新锁。日常恢复项目用 `get`，主动升级才用 `upgrade` 并审查差异。把两者随意互换会让“只是安装依赖”变成隐式升级。

### 7.2 应用包与普通库的锁文件策略

官方建议：**应用包提交 `pubspec.lock`**，让开发者与部署使用相同解析；**可复用普通包通常不提交自己的锁文件**，以便持续验证支持的依赖范围。判断依据是分发形态，不是目录是否叫 app。FactoryCare 移动客户端属于应用，应审查并提交锁文件。

### 7.3 `.dart_tool/` 不等于锁文件

`.dart_tool/` 保存本机生成的工具状态和包映射，通常加入 `.gitignore`；锁文件是需要审查的解析证据。删除 `.dart_tool/` 后可用清单与锁重新生成，但删锁会改变下一次可选择空间。不要把二者一起粗暴归类为“缓存”。

### 7.4 离线与冷缓存

`dart pub get --offline` 只使用本机 pub 缓存。它通过说明当前缓存足够，不证明新机器可以联网取得所有包；它失败也不证明版本约束必然错误，可能只是缓存缺失。冷环境验证需要隔离缓存或 CI，且应记录网络/镜像条件。本章资产没有第三方依赖，因此离线解析仍可运行。

### 7.5 生产恢复可使用锁文件强制模式

官方当前文档提供 `dart pub get --enforce-lockfile`：当锁文件不能精确满足清单或内容哈希不一致时失败。它适合 CI/部署恢复；是否在项目中启用需结合 SDK 基线和依赖来源验证，不能只写进 README 而从未运行。

## 8. 格式、分析与运行是三个门

### 8.1 格式门

`dart format .` 默认会改写 Dart 文件。CI 更适合只检查：

```bash
dart format --output=none --set-exit-if-changed .
```

官方文档说明，若存在需要格式化的文件，该模式返回 1；无需改变则返回 0。格式通过只证明代码符合当前格式器，不证明能通过分析。

### 8.2 静态分析门

```bash
dart analyze --fatal-infos
```

分析器检查语法、类型和已配置的 lint。`--fatal-infos` 让 info 级问题也影响退出码，适合严格教学门禁。具体 lint 集应在测试与 lint 章节配置；当前 `analysis_options.yaml` 只启用严格语言检查，避免依赖外部规则包。

### 8.3 运行门

```bash
dart run bin/main.dart
```

运行证明入口在这组环境和输入下完成。要让输出成为预言，验证脚本必须比较确定字符串，而不只是“没有崩溃”。例如预期：

```text
DART_TOOLCHAIN_EXAMPLE_PASS label=WO-1001:CREATED
```

如果程序输出别的文本但退出 0，未经比较仍可能是假绿。

### 8.4 建议顺序

```text
解析工具 → pub get → format check → analyze → run → 比较输出
```

前一阶段失败就停止。格式问题先修复可减少噪声；分析失败时不应继续把运行结果当通过。调试时可以单独运行某阶段，但最终必须重跑原始完整链。

## 9. 一份可审计验证脚本

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

DART_BIN="$(command -v dart)"
printf 'dart_bin=%s\n' "$DART_BIN"
dart --version
dart pub get --offline
test -f .dart_tool/package_config.json
test -f pubspec.lock
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
actual="$(dart run bin/main.dart)"
test "$actual" = 'EXPECTED_OUTPUT'
```

`set -e` 让失败命令停止，`-u` 把未定义变量视为错误，`pipefail` 防止管道前段失败被末段掩盖。`cd` 固定工作目录。脚本还应只清理自己生成的 `.dart_tool/` 或临时目录，不能删除用户全局 pub 缓存。

证据至少记录：

```text
checked_at: 2026-07-24
working_directory: .../ch.dart.toolchain
dart_bin: /实际/路径/dart
dart_version: 3.x.y stable ...
pub_get_exit: 0
format_exit: 0
analyze_exit: 0
run_exit: 0
run_stdout: ...
lockfile_present: true
```

路径可能含用户名，不适合公开时要脱敏，但不能把“路径已脱敏”写成“未记录”。

## 10. 按阶段诊断三类故障

### 10.1 PATH 命中错误 SDK

**现象**：语法在 IDE 可用，终端报告不支持；或包 SDK 约束拒绝当前版本。

**顺序**：

1. 保存失败命令和完整第一段错误；
2. 执行 `type -a dart`、`command -v dart`、`dart --version`；
3. 查看 IDE/Flutter 的 SDK 设置，而不是先修改；
4. 在当前 shell 临时使用期望路径复现；
5. 决定是否修改配置，记录回滚；
6. 新开 shell，再跑完整门禁。

首个可信证据通常是解析路径与版本输出。仅凭错误里出现“language version”不能断定要升级所有工具。

### 10.2 pubspec 解析或约束失败

**现象**：`dart pub get` 在运行源码前失败。

先看 pub 指出的行列、字段和约束冲突，检查 YAML 缩进、包名、SDK 范围、依赖来源。不要把它归为 analyzer Failure，因为分析阶段尚未开始。修复后再次执行 `dart pub get`，审查锁文件是否出现非预期升级，再执行后续门禁。

### 10.3 包导入路径错误

**现象**：pub get 已成功，但 analyzer 报 URI 不存在或符号找不到。

检查 `pubspec.yaml` 的 `name`、目标文件是否位于 `lib/`、文件大小写和 import URI。macOS 常用文件系统可能对大小写宽容，Linux CI 可能严格，因此大小写差异要在代码审查中消除。不要以“本机能运行”替代跨平台路径验证。

### 10.4 缓存造成假绿

热缓存下解析成功，但干净 CI 失败，说明本机存在未被项目完整声明的输入。先在隔离环境复现，不要清空用户全部缓存；保存 lock、package_config、源配置和命令输出，再判断是缺少声明、私有源认证还是内容不可得。

## 11. FactoryCare 场景：移动端仓库的工具链证据

FactoryCare 后续 Flutter 客户端会读取工单、扫码、上传图片并处理离线队列。业务越复杂，越不能把 SDK 漂移留到发布日。纯 Dart 阶段先建立以下合同：

1. 应用包在 `pubspec.yaml` 声明真实 SDK 范围；
2. 团队记录 Flutter 与其绑定 Dart 版本；
3. 应用提交 lockfile，依赖升级走显式差异；
4. CI 依次执行格式、分析、测试和构建；
5. 失败日志保留阶段和首个可信位置；
6. 发布证据记录实际 runner 版本，而不是只抄计划版本。

若后端 API 变更导致 Dart 模型生成失败，那是合同/代码生成阶段问题；若 Android 权限错误，那是平台集成问题；若 `dart` 路径漂移，则是本章工具解析问题。清楚边界能避免所有失败都被叫作“Flutter 环境坏了”。

## 12. 练习资产怎么使用

本章配有四类资产：

- `examples/encyclopedia/ch.dart.toolchain/`：最小绿色链，记录路径、版本、包配置、锁和运行输出；
- `labs/encyclopedia/ch.dart.toolchain/`：注入错误 PATH、坏 pubspec、坏 import，并在恢复后重跑；
- `exercises/encyclopedia/ch.dart.toolchain/`：公开脚本故意缺少三个门，`verify.sh` 预期红；
- `solutions-private/encyclopedia/ch.dart.toolchain/`：完整门禁，仅在独立尝试后对照。

推荐练习顺序：先预测每个故障停在哪个阶段，再运行；圈出首个可信证据；只做一个修复；重跑同一命令；最后用 120 秒解释各工具职责。只复制私有答案不能作为独立构建证据。

## 13. AI 协作边界

AI 适合：

- 根据脱敏的 `type -a`、版本和错误日志列出假设；
- 解释 pubspec 字段、生成最小门禁脚本草案；
- 对比 lockfile 差异并标出直接/传递升级；
- 设计不会触碰全局缓存的故障注入。

学习者必须亲自确认：

- 终端实际执行哪一份 `dart`；
- 命令写入哪些目录、是否联网、如何回滚；
- 锁文件为何变化；
- 红色发生在哪个阶段，修复后原门是否转绿；
- 示例只证明了哪些平台和版本。

禁止把包含 token 的私有源配置、完整环境变量或企业仓库 URL 交给外部模型。也不要执行未经理解的升级/清缓存命令。AI 说“版本正确”不是证据，终端输出和项目约束才是。

## 14. 复习清单与自测

不看正文，回答：

1. Dart SDK、`dart` CLI、pub、pubspec、lockfile 各自负责什么？
2. 为什么 `dart --version` 正确仍不能证明 IDE 和 Flutter 使用同一 SDK？
3. `dart pub get` 与 `dart pub upgrade` 的意图有何不同？
4. 应用包为什么通常提交 lockfile，而普通包通常不提交？
5. `.dart_tool/package_config.json` 与 `pubspec.lock` 有何区别？
6. 格式、分析、运行分别能发现什么，不能发现什么？
7. pubspec 缩进错、package URI 错分别最先在哪个阶段暴露？
8. 热缓存离线通过为什么不能证明冷机器可复现？
9. 怎样用退出码和输出建立可审计预言？
10. 举一个不应由本章解决的失败，例如 Android 相机权限拒绝。

达标不是背出命令，而是能从空目录建立包、保存版本与 lock 证据、制造一个故障、按阶段修复并重跑。

## 15. 官方资料、核对日期与未验证边界

本章仅使用 Dart 官方一手资料，核对日期均为 **2026-07-24**：

- [Get the Dart SDK](https://dart.dev/get-dart)：stable 通道与发布节奏；
- [Dart SDK archive](https://dart.dev/get-dart/archive)：稳定版本归档；
- [Dart changelog](https://dart.dev/changelog)：3.12 及工具变化；
- [The pubspec file](https://dart.dev/tools/pub/pubspec)：pubspec 字段；
- [Package layout conventions](https://dart.dev/tools/pub/package-layout)：目录和锁文件约定；
- [`dart pub get`](https://dart.dev/tools/pub/cmd/pub-get)：解析、package_config、锁与离线模式；
- [What not to commit](https://dart.dev/tools/pub/private-files)：`.dart_tool` 与应用/普通包锁策略；
- [`dart format`](https://dart.dev/tools/dart-format)：只检查与退出码；
- [`dart analyze`](https://dart.dev/tools/dart-analyze)：分析范围和 fatal 选项。

**已实际验证**：本章四类资产在 macOS arm64、本机 Dart 3.9.2 上的 pub get、格式、分析、运行和故障预言。**未验证**：Dart 3.12.2 二进制实际运行、Windows/Linux shell 差异、代理/私有 pub 源、冷缓存联网恢复、IDE SDK 选择、Flutter/Android/iOS 构建、发布到 pub.dev。上述未验证项不能由本章绿色脚本推断为通过。
