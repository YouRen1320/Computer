---
schema_version: 2
edition: 2026.2-draft
id: ch.flutter.toolchain-project
title: Flutter SDK、项目结构、run、hot reload 与 DevTools
responsibility: 建立 Flutter SDK、项目目录、目标设备、run/build、hot reload/restart 与 DevTools 观察链，不在本章教授 Widget 组合。
volume: '11'
order: 10
level: L2
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.flutter.toolchain-project.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.dart.oop-generics
version_surfaces:
- flutter-stable
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
  text: 在 120 秒内解释“Flutter SDK、项目结构、run、hot reload 与 DevTools”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - flutter-sdk-project
  - flutter-dev-loop
  covers_topics:
  - flutter.sdk-resolution
  - flutter.project-layout
  - flutter.target-device
  - flutter.run-build
  - flutter.hot-reload-restart
  - flutter.devtools-connect
  - flutter.framework-log
  - flutter.generated-platform-boundary
  uses_capabilities:
  - mobile.dart-language
  - foundation.toolchain-env-build
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 从空目录创建 Flutter 应用并保存 SDK、设备、run/build、reload/restart 对照证据；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - flutter-sdk-project
  - flutter-dev-loop
  covers_topics:
  - flutter.sdk-resolution
  - flutter.project-layout
  - flutter.target-device
  - flutter.run-build
  - flutter.hot-reload-restart
  - flutter.devtools-connect
  - flutter.framework-log
  - flutter.generated-platform-boundary
  uses_capabilities:
  - mobile.dart-language
  - foundation.toolchain-env-build
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: flutter-doctor-evidence-device-run-reload-restart-contrast
- id: diagnose
  kind: fault-diagnosis
  text: 面对“Flutter/Dart SDK 漂移、目标设备错误或误用 hot reload 掩盖初始化问题”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - flutter-sdk-project
  - flutter-dev-loop
  covers_topics:
  - flutter.sdk-resolution
  - flutter.project-layout
  - flutter.target-device
  - flutter.run-build
  - flutter.hot-reload-restart
  - flutter.devtools-connect
  - flutter.framework-log
  - flutter.generated-platform-boundary
  uses_capabilities:
  - mobile.dart-language
  - foundation.toolchain-env-build
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---

# Flutter SDK、项目结构、run、hot reload 与 DevTools

> 本章建立的是一条可重复的开发链：你能回答“正在使用哪套 Flutter/Dart、代码在哪个平台运行、一次命令经过了哪些阶段、改动后为什么该 reload、restart 或完整重建、出现故障先看哪份证据”。Widget 如何组合留到下一章。

## 1. 先把 Flutter 看成一条工具链

Flutter 不是一个单独的命令，也不只是一个 UI 依赖。一次 `flutter run` 至少涉及以下角色：

1. shell 根据 `PATH` 找到 `flutter` 可执行文件；
2. Flutter SDK 自带并选择一套兼容的 Dart SDK；
3. Flutter 工具读取 `pubspec.yaml`、解析依赖并生成必要文件；
4. 平台工具链编译宿主部分，例如 Android Gradle/JDK、Xcode 或浏览器工具；
5. Dart/Flutter 编译器处理应用代码；
6. 工具发现并连接目标设备，把制品安装或加载进去；
7. 调试服务建立连接，终端、IDE 与 DevTools 才能观察运行中的 VM、Widget、渲染和性能信息。

因此，“IDE 里能看到代码”并不等于环境正确，“`flutter --version` 能输出”也不等于某个平台能构建。工具链诊断要逐层取证，不能一遇到错误就删除缓存、重装所有软件。

### 1.1 2026.2 教材版本边界

本版以 Flutter stable 3.44.x 和它捆绑的 Dart 3.12.x 为讲解表面。Flutter 官方归档在 2026 年 6 月列出了 3.44 系列；具体补丁会继续变化，所以项目记录主次版本、实际补丁、渠道与 SDK 路径，而不是把“最新”写成永久事实。

执行下面的命令保存现场：

```bash
type -a flutter dart
flutter --version
dart --version
flutter channel
flutter doctor -v
```

这里要分别读懂：

- `type -a` 说明 shell 有哪些同名命令以及解析顺序；
- `flutter --version` 说明 Flutter、Engine、捆绑 Dart 与渠道；
- 单独的 `dart --version` 可能来自另一套 Dart，不能据此断定 Flutter 会用它；
- `flutter doctor -v` 是能力清单，不是简单的“总分”。只开发 Web 时，Android/Xcode 缺失可以是当前明确接受的限制；要交付移动端时就必须补齐。

版本证据至少包含命令、完整输出、日期、机器架构与项目提交。只写“我的 Flutter 是稳定版”无法复现。

### 1.2 SDK 解析与 PATH

macOS 的 shell、IDE、桌面启动器可能拥有不同环境。终端通过启动文件配置 `PATH`，从 Dock 打开的 IDE 未必继承同一份 shell 环境。常见症状是：终端显示新 SDK，IDE 却仍用旧 SDK；或者 `flutter` 来自 Homebrew，`dart` 来自另一个手动安装目录。

诊断顺序如下：

```bash
echo "$SHELL"
echo "$PATH"
command -v flutter
ls -l "$(command -v flutter)"
flutter --version
flutter doctor -v
```

如果使用版本管理器，还要查看项目钉住文件和版本管理器解析结果。关键不是采用哪一种安装方式，而是做到：一个项目有明确版本；终端、IDE、CI 使用同一版本合同；升级是一次有记录、可回滚的变更。

不要把 Flutter 自带的 Dart 与全局 Dart 强行拆开升级。Flutter 对其 Dart 版本有绑定关系；Flutter 项目优先用 `flutter pub`、`flutter test` 等入口，让工具选择兼容环境。

## 2. 从空目录创建项目

先查看创建命令的当前选项，再创建一个最小应用：

```bash
flutter create --help
flutter create --org com.factorycare --project-name factorycare_mobile factorycare_mobile
cd factorycare_mobile
flutter pub get
flutter analyze
```

`--org` 通常参与 Android application ID、Apple bundle identifier 等平台标识的初始生成。它不是随便的展示文字。上线后修改包标识会影响签名、商店记录、深链、推送和后端配置，所以练习项目也要养成使用反向域名的习惯。

项目名使用小写加下划线，是 Dart 包名；面向用户的 App 名称属于平台元数据，可以不同。目录名、包名、应用标识和展示名是四个概念。

### 2.1 核心目录

一个跨平台应用通常包含：

```text
factorycare_mobile/
├── lib/                 # Dart/Flutter 业务源码，默认入口 lib/main.dart
├── test/                # 快速 Widget/单元测试
├── integration_test/    # 端到端或设备集成测试（按需建立）
├── assets/              # 项目自行建立并在 pubspec 声明的静态资源
├── android/             # Android 宿主工程与生成脚手架
├── ios/                 # iOS 宿主工程与生成脚手架
├── macos/ linux/ windows/
├── web/                 # Web 宿主入口与图标等
├── pubspec.yaml         # 包、SDK、依赖、资源、字体等声明
├── pubspec.lock         # 应用项目的解析结果，应提交版本库
└── analysis_options.yaml
```

不是每次创建都会包含所有平台，取决于已启用平台与参数。可以查看：

```bash
flutter config
flutter create --platforms=android,ios,web .
```

第二条命令会在当前项目补平台脚手架，但它属于需要审查的生成变更。先提交现状或建立干净分支，再生成并检查差异；不要看到平台目录报错就盲目反复执行，覆盖团队手工维护的原生配置。

### 2.2 哪些文件可以改，哪些要谨慎

日常主要改 `lib/`、`test/`、`pubspec.yaml` 和资源。平台目录不是“永远不能改”，而是宿主边界：权限、签名、渠道、原生插件初始化、最低系统版本等确实要在里面配置。

将平台文件分为三类更安全：

- Flutter 工具可再生且团队未定制的脚手架；
- 项目必须维护的原生配置，如权限说明、签名占位、URL scheme；
- 构建产物和机器本地文件，如 `build/`、`.dart_tool/`、IDE 缓存。

第三类不应提交。前两类通常需要提交并在升级时审查。判断依据不是“目录由工具创建”，而是它是否属于可复现输入。

### 2.3 `pubspec.yaml` 的缩进是语义

YAML 用缩进表达层级。资源声明示例：

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
```

`assets` 若缩进到错误层级，可能解析失败或构建时找不到资源。修改后运行：

```bash
flutter pub get
flutter analyze
```

依赖写入 `dependencies`，仅开发/测试使用的工具写入 `dev_dependencies`。应用项目提交 `pubspec.lock`，使团队与 CI 复用已解析版本；升级依赖时把清单与锁文件变化一起审查。

## 3. 目标设备不是一个模糊的“模拟器”

Flutter 可以面向 Android、iOS、Web 和桌面，但每个目标都有自己的宿主工具链。先枚举证据：

```bash
flutter devices
flutter emulators
flutter doctor -v
```

`flutter devices` 给出设备名称、设备 ID、目标平台和状态。命令里使用稳定的设备 ID：

```bash
flutter run -d chrome
flutter run -d macos
flutter run -d <device-id>
```

如果同时有多个设备却没指定 `-d`，工具会询问或选取目标；自动脚本不能依赖交互式选择。Web 能运行也不能证明 Android 权限、iOS 签名或原生插件正常，因为它们经过不同编译链。

### 3.1 真机、模拟器和浏览器分别证明什么

- 浏览器适合快速验证通用 Dart、Widget 基本行为和 Web 表面；不能证明移动平台插件、权限、后台行为。
- 模拟器适合可重复的系统版本、屏幕和导航测试；传感器、推送、相机、功耗等与真机仍有差异。
- 真机可以验证真实性能、权限、生命周期和硬件集成；设备型号与系统版本差异仍要覆盖。

因此“在 Chrome 跑通”是一条有边界的证据，不是“Flutter App 已验证”。教材离线资产只能检查源码和合同；设备验收必须由学习者保存真实运行证据。

### 3.2 连接失败的分层诊断

目标不可见时按层查：

1. `flutter doctor -v` 是否认为平台工具链完整；
2. 平台自身工具是否看见设备，例如 Android 的 `adb devices`；
3. 设备是否授权、解锁，开发者模式是否开启；
4. 项目最低/目标平台是否兼容；
5. 是否选错 device ID；
6. 代理、防火墙、无线调试或 USB 是否影响连接。

保留首个失败输出。不要先清缓存，因为缓存并不能让未授权设备变成已授权。

## 4. `run`、`build`、`analyze` 与 `test`

这些命令回答不同问题：

| 命令 | 主要问题 | 不足以证明 |
| --- | --- | --- |
| `flutter analyze` | 静态分析与 lint 是否通过 | 运行行为、平台构建、UI 正确 |
| `flutter test` | 测试代码及其断言是否通过 | 真机插件和完整用户流程 |
| `flutter run -d …` | 指定目标能否调试运行 | release 优化、签名、商店包 |
| `flutter build <target>` | 指定模式能否产出制品 | 制品安装后的业务正确性 |
| `flutter doctor -v` | 当前机器工具链能力 | 某个项目一定构建成功 |

日常最小反馈环可以是：格式化、分析、测试、目标 smoke。发布前还需要 release 构建、签名、安装、平台测试和监控方案，后续发布章再展开。

### 4.1 调试、profile 与 release

Flutter 构建模式的目标不同：

- debug 支持断言、调试服务和 hot reload，性能不代表发布表现；
- profile 用于接近发布环境的性能分析，保留必要的观测能力；
- release 面向交付，启用优化并移除调试能力。

不要在 debug 模式下得出帧率、包体和启动时间结论。也不要因为 release 能编译，就认为授权和业务正确；那仍需测试。

常见命令需要先用 `--help` 确认当前版本参数：

```bash
flutter run --profile -d <device-id>
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
flutter build web --release
```

iOS release 通常还涉及 macOS、完整 Xcode、证书与签名。Android 涉及 JDK、Gradle、Android SDK、keystore 和渠道配置。工具报错时先确认失败阶段：依赖解析、Dart 编译、原生编译、签名、安装还是运行。

## 5. hot reload、hot restart 与完整 restart

这是 Flutter 初学者最容易形成错误直觉的地方。

### 5.1 hot reload

hot reload 将更新后的 Dart 代码注入正在运行的 Dart VM，框架重建 Widget 树，同时保留应用现有状态。官方说明中特别重要的一点是：它不会重新执行 `main()` 和 `initState()`。

适合：

- 修改 `build` 中的颜色、文字和大部分布局；
- 调整普通 Dart 方法；
- 在保留当前导航和输入状态时快速看 UI 变化。

不适合用来验证初始化是否重新执行。若把配置读取、依赖创建或初始字段计算写在 `initState`，改了相关代码再 reload，旧状态仍可能留着。你看到“没有变化”并不一定是代码错误，而可能是选择了错误的刷新方式。

### 5.2 hot restart

hot restart 重新启动 Dart 应用，丢失当前 Dart 状态，并重新运行 `main()`。它通常比完整平台重建快，适合验证 Dart 侧初始化、全局依赖和入口变化。

它仍不等于重新编译/安装所有原生宿主配置。如果修改 Android manifest、Gradle、iOS plist、原生插件注册或宿主代码，应停止并完整运行/构建。

### 5.3 full restart / rebuild

完整 restart 停止应用，重新编译必要的 Dart 与平台代码并重新安装或加载。下列变化通常需要它：

- 添加或修改含原生实现的插件；
- Android/iOS 权限、签名、最低系统版本等配置变化；
- 原生 Kotlin/Java/Swift/Objective-C 代码变化；
- 生成的插件注册或宿主入口变化；
- reload/restart 无法迁移的类型结构变化。

### 5.4 用实验建立判断力

建立一个字段分别在顶层、`main`、`initState` 和 `build` 打印带序号的日志。依次：

1. 首次 `flutter run`；
2. 只改 `build` 文案，hot reload；
3. 改 `initState` 的初值，hot reload；
4. hot restart；
5. 改平台配置后完整 restart。

记录哪些日志重新出现、页面状态是否保留、耗时与终端提示。不要背“按 r / 按 R”就结束；真正目标是根据变化层级选择最小但足够的重启方式。

## 6. framework 日志与首个可信证据

`print`/`debugPrint` 可以帮助学习，但生产日志需要结构化、分级、脱敏和关联 ID。开发阶段至少区分：

- Flutter 工具日志：构建、设备、安装、调试服务；
- framework 异常：红屏、断言、布局溢出、生命周期错误；
- 应用业务日志：请求开始/结果、状态迁移；
- 平台日志：Android logcat、Xcode console、浏览器 console。

同一个故障可能产生大量后续错误。先找最早发生且最接近根因的一条，而不是只看最后的 “build failed”。例如：

```text
pub get -> Dart compile -> Gradle compile -> package/sign -> install -> app runtime
```

若在 `pub get` 失败，后面的设备操作尚未发生；若安装成功后 runtime exception，删除 Gradle 缓存通常无关。

日志里禁止输出 token、密码、完整 cookie、身份证号、定位轨迹等敏感信息。调试便利不能覆盖安全边界。

## 7. DevTools 是观察工具，不是自动结论

运行 debug/profile 应用后，IDE 通常提供 “Open DevTools”；也可按当前 CLI 帮助启动。DevTools 能连接到运行中的 Dart VM，常用页面包括：

- Inspector：查看 Widget/Element/RenderObject 关系、约束和属性；
- Performance：查看帧时间线、CPU 与卡顿线索；
- Memory：观察分配、堆、快照与潜在保留；
- Network：在支持的请求栈/平台上观察网络；
- Debugger/Logging：断点、变量、异常和日志；
- App Size：分析构建产物组成，通常基于合适的 release 分析文件。

不同 Flutter/DevTools 版本和平台的页面会变化，应以当前官方文档和实际 UI 为准。

### 7.1 连接链

DevTools 能展示数据的前提是：应用以支持的模式启动、VM service 可达、选择的是本次进程。若页面空白：

1. 确认应用仍在运行；
2. 确认模式支持相应能力；
3. 从本次 `flutter run`/IDE 会话打开连接；
4. 检查是否连到旧进程或旧端口；
5. 重现一次有时间戳的操作再观察。

不能仅凭一张某时刻内存图断言“没有泄漏”。需要可重复操作、基线、垃圾回收后的保留趋势和对象引用路径。性能与内存章会继续建立证据方法。

### 7.2 Inspector 与本章边界

此处只学会连接、选取节点、读取属性和保存截图。Widget/Element/RenderObject 的身份关系在下一章解释，约束和渲染在再下一章解释。工具能展示结构，但如果没有概念模型，很容易把某个 Widget 对象当成屏幕上的持久节点。

## 8. IDE、CLI 与 CI 的一致性

IDE 是方便入口，CLI 是可记录合同。团队不能只说“点击绿色三角能跑”。把关键动作写成命令和验证脚本，CI 才能复现。

IDE 中至少核对：

- Flutter SDK path；
- Project SDK/Java 用于 Android 构建的选择；
- 目标设备；
- Run configuration 的入口、flavor、额外参数；
- IDE 插件版本与项目 Flutter 版本是否兼容。

CI 不需要启动 IDE，而是安装/缓存明确 SDK、执行 `flutter pub get`、`flutter analyze`、`flutter test` 和目标构建。缓存只是加速；锁文件和 SDK 约束才是可重复输入。缓存键至少应考虑 Flutter 版本、平台、锁文件和相关构建配置。

## 9. 生成平台目录的边界与升级

`flutter create` 生成的平台文件会随模板演进。升级 Flutter 后，旧项目不会神奇地变成新模板，也不应把整个宿主工程无审查覆盖。

推荐做法：

1. 阅读目标版本迁移/破坏性变更说明；
2. 确保工作区干净并建立升级分支；
3. 在临时目录用新版本创建同参数的对照项目；
4. 比较 Gradle、manifest、plist、入口与最低版本；
5. 只迁移理解过的必要变化；
6. 分平台执行 clean build、安装和 smoke；
7. 保存回滚点。

`flutter clean` 删除可再生构建产物，适合证明从干净状态可重建或处理确有缓存证据的问题。它不是每个错误的标准前置动作。无差别清理会丢失增量反馈并掩盖真正的输入漂移。

## 10. FactoryCare 最小开发合同

为后续移动端章节建立如下记录：

```text
项目：factorycare_mobile
Flutter：3.44.x stable（记录实际 patch/revision）
Dart：Flutter 捆绑 3.12.x（记录实际 patch）
入口：lib/main.dart
目标：本地先选一个可用目标；移动交付前另做 Android/iOS 验收
命令：flutter pub get / analyze / test / run -d ...
证据：toolchain.txt、devices.txt、run.log、reload-restart.md、DevTools 截图
限制：未在某平台运行就明确写“未验证”，不能写“兼容”
```

Java 后端仍是 FactoryCare 业务事实与公开 API 的所有者。Flutter 只是客户端；不要在移动项目里复制一套可独立演化的工单状态真相。当前章也不接真实 API，只确保客户端工具链可复现。

## 11. 故障案例

### 11.1 Flutter 与 Dart 版本看似矛盾

现象：`dart --version` 是 A，`flutter --version` 显示捆绑 Dart B。

解释：shell 的独立 `dart` 与 Flutter SDK 内部 Dart 可能来自不同目录。Flutter 项目命令通常使用自身捆绑版本。

证据与修复：保存 `type -a flutter dart`、符号链接和两份版本输出；统一 IDE Flutter SDK，项目操作使用 Flutter 入口。不要为了让文本相同而替换 Flutter 内部 SDK。

### 11.2 选错目标设备

现象：代码修改后浏览器有变化，手机没有；或者构建提示某插件不支持 Web。

定位：检查当前 run 会话顶部/终端的 device ID 与平台。使用 `flutter devices` 后明确 `-d` 重跑。

残余风险：一个平台通过不能外推到其他平台；需要平台矩阵。

### 11.3 hot reload 掩盖初始化变化

现象：修改 `initState` 中默认状态后界面不变，开发者误判代码未编译。

定位：终端显示 reload 成功，但旧 State 被保留，`initState` 日志未重现。

修复：执行 hot restart，若涉及原生配置则完整 restart；重跑同一观察表。

### 11.4 `pubspec.yaml` 或资源失败

现象：解析错误、资源找不到。

定位：从 `flutter pub get`/build 的第一条 YAML 路径或 asset key 错误读行列；对照实际大小写与声明缩进。

修复：最小修改后重跑 `pub get`、`analyze` 和目标测试。macOS 默认文件系统可能弱化大小写问题，CI/Linux 仍可能失败，所以路径大小写必须精确。

## 12. 实验：建立可重复 run/build/reload 证据

本章实验不要求你现在补齐所有移动平台。先选一个 `flutter doctor -v` 显示可用的目标完成闭环，再把未验证平台列为限制。

### 12.1 输入

```bash
mkdir -p evidence/flutter-toolchain
{
  date -Iseconds
  uname -m
  command -v flutter
  flutter --version
  flutter doctor -v
  flutter devices
} > evidence/flutter-toolchain/environment.txt 2>&1
```

然后创建应用、格式化、分析、测试并 run。不要把含用户名、设备序列号或敏感路径的原始证据直接公开；提交前脱敏。

### 12.2 reload/restart 对照表

| 改动 | 预测 | 实际 | 状态是否保留 | 日志证据 |
| --- | --- | --- | --- | --- |
| `build` 文案 | reload 可见 | 待填 | 是 | 待填 |
| `initState` 初值 | reload 不重新初始化 | 待填 | 是 | 待填 |
| 同上后 hot restart | 新初值生效 | 待填 | 否 | 待填 |
| 平台元数据 | full restart/build | 待填 | 否 | 待填 |

“待填”必须由真实运行替换。教材不能替你制造设备证据。

### 12.3 故障注入

至少选择一个安全故障：

- 临时让 IDE 指向另一 SDK，然后证明版本漂移并恢复；
- 在练习分支破坏 `pubspec.yaml` 缩进，记录解析阶段和行列；
- 选一个不存在的 device ID，证明失败发生在目标选择而非业务代码；
- 修改初始化值只做 reload，观察旧状态，再 restart 验证。

故障必须在隔离练习中完成，保存“失败—定位—修复—重跑”四段证据。

## 13. 自测与参考答案

1. **为什么 `flutter doctor` 全绿仍不能证明项目正确？**  它主要证明机器能力；项目依赖、源码、目标配置和业务测试仍可能失败。
2. **为什么全局 `dart --version` 和 Flutter 的 Dart 可以不同？**  它们可能来自不同 SDK；Flutter 使用与框架匹配的捆绑 Dart。
3. **改 `initState` 后应该先选什么？** 需要重新验证初始化时选 hot restart；若还改了原生配置则完整 restart。
4. **Chrome 跑通证明了什么？** 证明当前 Web 目标的有限开发闭环；不证明 Android/iOS 插件、权限、签名和真实性能。
5. **DevTools 内存图能直接证明没有泄漏吗？** 不能，需要可重复操作、基线、GC 后趋势和引用路径。
6. **为什么应用项目提交 `pubspec.lock`？** 固定依赖解析结果，使团队与 CI 更可复现。
7. **何时使用 `flutter clean`？** 当要验证干净重建或证据明确指向构建缓存；不是通用修复按钮。
8. **本章的越界反例是什么？** 例如详细讲 `BuildContext` 查找或复杂布局；它们属于后续 Widget/布局章节。

## 14. 章节验收清单

- [ ] 能指出终端与 IDE 实际使用的 Flutter SDK 路径、版本、渠道和捆绑 Dart。
- [ ] 能解释项目核心目录以及平台生成目录的维护边界。
- [ ] 能明确选择目标 device ID，并说明该目标不能证明哪些平台能力。
- [ ] 能区分 `analyze`、`test`、`run`、`build` 与 `doctor` 的证据范围。
- [ ] 能根据改动选择 hot reload、hot restart 或完整 rebuild。
- [ ] 能连接本次运行进程的 DevTools，并说明观察结果的限制。
- [ ] 能从第一条可信日志判断依赖、编译、平台、安装或运行阶段。
- [ ] 能完成一次故障注入、修复和原命令重跑。
- [ ] 对没有真实运行的平台明确写“未验证”。

## 15. 官方资料与更新检查

- Flutter SDK archive：<https://docs.flutter.dev/install/archive>
- 安装与 `flutter doctor`：<https://docs.flutter.dev/get-started/install>
- Flutter CLI：<https://docs.flutter.dev/reference/flutter-cli>
- Hot reload：<https://docs.flutter.dev/tools/hot-reload>
- DevTools：<https://docs.flutter.dev/tools/devtools>
- 项目配置与 `pubspec`：<https://docs.flutter.dev/tools/pubspec>

资料核对日期：2026-07-24。版本、命令选项与 DevTools 页面属于可变化表面；运行前以项目版本的官方文档和 `--help` 为准。概念边界——分层取证、锁定输入、区分 reload/restart/rebuild、未运行即未验证——是本章希望长期保留的稳定能力。
