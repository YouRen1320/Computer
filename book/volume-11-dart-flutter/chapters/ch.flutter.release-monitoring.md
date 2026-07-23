---
schema_version: 2
edition: 2026.2-draft
id: ch.flutter.release-monitoring
title: 构建、签名、发布、符号与崩溃监控
responsibility: 生成可追溯 Android/iOS 制品，管理签名与环境配置，保存符号并验证崩溃监控和回退，不在本章教授通用 CI。
volume: '11'
order: 19
level: L3
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.flutter.release-monitoring.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.flutter.testing-performance
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
  text: 在 120 秒内解释“构建、签名、发布、符号与崩溃监控”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - flutter-build-sign-release
  - flutter-symbol-crash-monitor
  covers_topics:
  - flutter.build-flavor
  - flutter.signing-secret
  - flutter.version-metadata
  - flutter.release-artifact
  - flutter.store-rollout
  - flutter.obfuscation-symbol
  - flutter.crash-symbolication
  - flutter.release-correlation
  - flutter.monitoring-privacy
  - flutter.rollback-plan
  uses_capabilities:
  - mobile.flutter-tooling-widget
  - mobile.flutter-layout-lifecycle
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 生成带版本、签名、符号和崩溃监控证据的 Flutter 发布候选包；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - flutter-build-sign-release
  - flutter-symbol-crash-monitor
  covers_topics:
  - flutter.build-flavor
  - flutter.signing-secret
  - flutter.version-metadata
  - flutter.release-artifact
  - flutter.store-rollout
  - flutter.obfuscation-symbol
  - flutter.crash-symbolication
  - flutter.release-correlation
  - flutter.monitoring-privacy
  - flutter.rollback-plan
  uses_capabilities:
  - mobile.flutter-tooling-widget
  - mobile.flutter-layout-lifecycle
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: release-build-signature-check-symbolication-drill
- id: diagnose
  kind: fault-diagnosis
  text: 面对“签名环境串线、符号未归档或崩溃事件无法关联版本”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - flutter-build-sign-release
  - flutter-symbol-crash-monitor
  covers_topics:
  - flutter.build-flavor
  - flutter.signing-secret
  - flutter.version-metadata
  - flutter.release-artifact
  - flutter.store-rollout
  - flutter.obfuscation-symbol
  - flutter.crash-symbolication
  - flutter.release-correlation
  - flutter.monitoring-privacy
  - flutter.rollback-plan
  uses_capabilities:
  - mobile.flutter-tooling-widget
  - mobile.flutter-layout-lifecycle
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
generated_by: scripts/generate-curriculum.rb
generated_spec_digest: 8970e035634a75ff13a1733841a85374a8177974f1e1d70c0504b25c81c796e0
---
# 构建、签名、发布、符号与崩溃监控

> 发布不是执行一次 `flutter build`，也不是在商店后台点“提交”。一个可负责的发布必须回答：制品来自哪个 commit、使用什么 SDK 与依赖、面向哪个环境、由什么身份签名、如何找到对应符号、崩溃能否关联到该版本、出现问题怎样停止扩散和恢复。本章建立 Android/iOS 发布候选的证据链；它不伪造证书、商店账号、真机制品或监控平台结果。

## 1. 从发布候选的“身份证”开始

同名 `app-release.aab` 无法说明内容。每个 release candidate（RC）至少要有不可混淆身份：应用 ID/Bundle ID、flavor、用户可见版本、单调构建号、commit SHA、源码是否干净、Flutter/Dart、锁文件摘要、构建模式、目标平台、签名身份摘要、制品 SHA-256、符号目录摘要和构建时间。

可以把它们写入机器可读 manifest：

```json
{
  "application": "factorycare-mobile",
  "flavor": "production",
  "version": "1.4.0",
  "buildNumber": "10402",
  "commit": "8f2c...",
  "sourceDirty": false,
  "flutter": "3.44.x",
  "dart": "3.12.x",
  "artifact": "factorycare-1.4.0+10402-production.aab",
  "artifactSha256": "...",
  "symbolsSha256": "..."
}
```

manifest 只是证据索引，不应包含 keystore 密码、私钥、App Store API 私钥、服务账号 JSON 或监控 DSN 的秘密部分。签名身份保存证书指纹、别名或团队 ID等非秘密元数据；真正秘密放在受控密钥系统中。

## 2. Debug、profile 与 release 的职责不同

debug 面向开发，包含断言、调试服务和热重载能力；profile 保留性能分析能力并更接近发布性能；release 面向用户，采用发布编译与优化。用 debug 包测帧不能得出发布性能结论，用 profile 包也不能替代最终签名 release smoke。

发布候选必须由明确命令和干净输入生成。命令、环境变量名称、Flutter 版本、依赖解析与输出路径都要记录。禁止把开发 IDE 当前配置当唯一构建说明；IDE 能成功不代表另一台机器可重建。

“release 模式”也不自动等于“生产环境”。若代码仍指向 staging API、使用测试租户、开启详细敏感日志或带调试证书，它仍不是 production RC。构建模式、flavor、服务环境与签名身份是四个独立维度。

## 3. 版本名、构建号和提交要能一一关联

Flutter 项目通常在 `pubspec.yaml` 使用 `version: 1.4.0+10402`。用户可见版本用于表达产品发布，构建号用于区分商店上传和具体制品。Android 与 iOS 对版本字段的映射和限制不同，官方构建命令也允许通过 `--build-name` 与 `--build-number` 覆盖；团队必须选一个权威来源，避免 pubspec、Gradle、Xcode 和 CI 四处各写一份。

构建号必须单调且不可复用到不同内容。若同一个 `1.4.0+10402` 先后生成两个 SHA 不同的包，崩溃和商店记录会无法唯一关联。修复代码应产生新构建号，即使用户可见版本不变。commit 和 dirty 状态也要写入 manifest；不从带未提交修改的目录发布，除非有明确、可审计的例外流程。

不要让客户端版本决定业务权限。后端可以根据最低支持版本拒绝过旧协议，但仍要验证用户、租户与数据；客户端显示版本只是发布相关元数据，不是可信授权凭证。

## 4. Flavor 隔离环境，而不是只换图标

Flutter flavor 通常映射到 Android product flavor 和 iOS scheme/configuration。它可以决定应用 ID 后缀、显示名、图标、API origin、日志级别、监控项目和功能开关。官方 Android flavor 文档也把 app name、icon、API key、feature flag、logging level 列为常见差异。

关键原则是环境组合必须有效且不可串线：production 包只能使用 production API allowlist、production 监控项目和 production 签名；staging 包应有不同包名/图标，避免测试人员误操作真实数据。构建前校验矩阵比运行后猜测可靠。

```text
flavor=production
applicationId=com.factorycare.mobile
apiOrigin=https://api.factorycare.example
monitoringProject=factorycare-mobile-prod
signingIdentity=prod-release
```

端点和公开项目 ID可以是配置，密码和私钥不是。`--dart-define` 会被编译进客户端，不能用于隐藏秘密；移动应用最终运行在用户控制的设备上，任何随包分发的值都应视为可提取。真正服务端秘密只能留在服务端。

## 5. 配置与签名秘密要分开管理

签名材料包括 Android keystore/private key 与密码、Apple distribution certificate/private key、provisioning profile 与相关账号/API key。它们不能提交 Git、写入 Markdown、输出到构建日志或打包到普通 artifact。秘密系统应限制读取主体、记录审计、支持轮换与吊销。

构建脚本只读取约定变量或临时文件路径，失败时不能 echo 内容。临时密钥文件要使用最小权限，任务结束清理；日志对变量值做掩码。Pull Request 来自不可信 fork 时不得注入 production secret。开发机手工复制密钥也要有回收与离职流程。

签名证书有生命周期。团队需要记录所有者、用途、到期、备份、恢复和轮换演练。只有密码没有 keystore 无法更新应用；只有证书没有私钥也无法签名。备份必须加密并实际验证可恢复，而不是只相信文件存在。

## 6. Android 发布签名与制品

Android 发布通常面向 Play Store 生成 Android App Bundle（AAB）；Flutter 官方 Android 发布指南说明 `flutter build appbundle` 生成 release bundle，APK 可用于特定分发或测试，`--split-per-abi` 能生成按 ABI 拆分的 APK。精确输出路径与 Gradle 配置会随版本变化，应以当前官方文档和本项目构建日志为准。

Android 签名涉及 upload key、可能由 Google Play 管理的 app signing key，以及本地 Gradle signing config。团队必须知道当前模式，不能把 debug keystore 当 release。验证不仅看命令退出 0，还要检查包名、版本、签名证书指纹、目标环境、支持 ABI 和 artifact hash。

签名配置文件只引用外部秘密，不把密码写进版本控制。若构建输出提示使用 debug signing，production job 应立即失败。不同 flavor 使用不同应用 ID时，也要确认商店记录和签名关系，不能通过改包名绕开已丢失的正式签名。

本章不提供实际 keystore 命令，因为密钥生成、Play App Signing 与组织政策属于目标项目决策；真实执行前要按 Android Developers 和 Flutter 当前指南确认影响、备份与轮换。

## 7. iOS 签名、归档与 IPA

iOS 发布需要 Bundle ID、Apple Developer team、证书、entitlements 与 provisioning profile 形成一致身份。Flutter 官方 iOS 发布指南要求在 Xcode 检查 Runner 的 Display Name、Bundle Identifier、Signing & Capabilities、Team 和 deployment target；`flutter build ipa` 可生成 `.xcarchive` 与 `.ipa`，再验证和上传 App Store Connect/TestFlight。

自动管理签名适合部分团队，本地/CI 手工管理适合需要严格可控的场景。无论哪种方式，证据都应包含实际使用的 team、profile UUID/名称、证书指纹、entitlements、Bundle ID 和过期时间。看到 Xcode “Succeeded”不代表包发往正确账号。

App Store 上传构建号必须唯一，发布前还要核对隐私清单、权限用途文本、图标、最低 iOS、第三方 SDK与 export compliance。教材不能替代 Apple 当日政策。没有完整 Xcode、开发者账号和分发证书时，不能声称生成或验证 iOS release。

## 8. “同一 commit 可追溯”不等于字节级可复现

理想状态是冻结所有输入后可以重建相同内容，但移动构建包含工具链、原生依赖、签名时间戳和平台打包元数据，未必天然达到 bit-for-bit 相同。不要把两次成功构建自动称为“可复现构建”。

本课程最低要求是可追溯重建：源码 commit、lockfile、Flutter SDK、Java/Gradle/Android SDK或 Xcode/CocoaPods、构建参数、flavor、依赖源和签名身份明确；输出 hash 被保存。若组织要求字节级复现，需要单独定义哪些时间戳/签名差异可归一化，并用二次构建比较证明。

依赖锁定同样重要。`pubspec.lock`、原生 lockfile 与插件平台实现决定产物；构建当天临时升级依赖会让测试证据失效。升级 Flutter、Xcode、Gradle、CocoaPods 或插件后，应重新跑测试、构建、符号和设备 smoke，不能沿用旧 RC 报告。

## 9. Artifact manifest 与哈希链

发布目录可包含：AAB/IPA；manifest；测试报告索引；SBOM或依赖清单；签名验证输出；符号目录；隐私/权限矩阵；回退清单。每个文件计算 SHA-256，manifest 自身再由受控流程保存或签名。商店上传前后记录商店识别出的版本和处理结果。

哈希能证明文件字节未变，不能证明文件安全、正确签名或来自可信源码。它必须与受控构建身份、签名和审查结合。上传一个恶意包后记录 hash 仍然是恶意包。

制品命名应包含应用、flavor、版本和构建号，但安全判断不能只解析文件名。验证器读取包内元数据和签名，再与 manifest 比较。发布人员不能手工把 staging AAB 重命名成 production 后上传。

## 10. 构建前后的门禁

构建前门禁包括：工作树干净；commit 已审查；目标 SDK 与 lockfile 固定；单元/Widget/集成/Golden和必要性能结果满足策略；production 配置矩阵有效；秘密可用但未泄露；版本号唯一；隐私与权限声明已审查。

构建后门禁包括：命令退出 0；制品存在且非空；包 ID、版本、flavor、API allowlist正确；签名验证通过；hash 已记录；符号目录存在并关联相同 build；安装到目标测试设备成功；启动、登录替身、关键工单路径和升级/冷启动 smoke 通过；监控测试事件可关联。

任一门禁失败都生成失败证据并停止，不自动换成更宽松配置。尤其不能在签名失败时回退 debug signing，也不能在符号丢失时先发布后补，因为后续崩溃可能永远无法还原。

## 11. 混淆不是加密，符号必须与制品成对归档

Flutter 官方支持在构建时使用 `--obfuscate` 与 `--split-debug-info=<directory>` 混淆 Dart 符号并输出用于还原栈的信息。混淆提高逆向成本，不会隐藏随客户端分发的 API key、URL、业务规则或用户数据，也不能替代服务端授权。

每个 RC 的 symbols 目录必须和 artifact 一起归档，记录 Flutter 版本、目标架构、build ID和 hash。不能复用另一个构建号的符号，也不能在发布后重新构建一份“差不多”的 symbols。源码、制品和符号三者通过 commit/buildNumber/hash 关联。

符号目录可能包含有助于理解代码的信息，应限制访问；但不能为了保密而删除。保留期限至少覆盖该版本仍在用户设备上和可能上报崩溃的周期。归档系统要验证读取和恢复，不只检查目录存在。

## 12. 崩溃捕获要覆盖不同错误入口

Flutter framework 回调中的错误通常流向 `FlutterError.onError`；不在 Flutter callback 栈中的异步错误可由 `PlatformDispatcher.instance.onError` 等入口处理。Isolate、原生 Android/iOS 崩溃、OOM/进程杀死和 ANR 还需要对应平台或监控 SDK能力。一个 Dart handler 不能捕获所有失败。

错误捕获入口应在应用启动早期配置，但监控初始化失败不能让应用无限重启。先保留平台默认处理/输出，再将脱敏事件发送到监控；避免 handler 自身抛错形成递归。测试错误使用明确标记和专用环境，不污染生产 crash-free 指标。

“捕获”不等于“恢复”。严重不一致后继续运行可能破坏数据。应用要区分可展示错误页、可重试操作和必须终止/重启的失败；后端写操作依然依赖幂等与事务，不因客户端 catch 就安全。

## 13. 崩溃事件必须关联发布身份

最小事件字段包括：内部事件 ID、UTC 时间、应用 ID、flavor、version/build、commit或 release ID、平台/系统、设备类别、Flutter/Engine、错误类别、脱敏栈、当前功能阶段、关联 ID和采样状态。不得把完整工单正文、token、精确位置、照片路径或用户输入塞入 breadcrumb。

监控 SDK通常使用 `release`、`dist` 或自定义 tag；团队必须保证值与 artifact manifest完全一致。若客户端上报 `1.4.0` 而没有 build number，两个热修复会混在一起；若 staging 与 production 共用项目，测试崩溃会污染指标。

服务端关联 ID可以连接一次 API 失败，但不能成为全局用户标识。使用随机请求/会话标识并控制保留；需要用户关联时使用内部脱敏 ID和访问控制。监控平台本身也是外部数据处理者，要纳入隐私和安全审查。

## 14. 符号化演练才证明链路可用

“symbols 已上传”只是动作。真正 Oracle 是对该 RC 注入一个已知测试崩溃，监控收到同一 release/build 事件，并把混淆栈还原到预期源码函数/行范围。保存原始栈、符号化栈、事件 ID、制品/symbol hash和时间。

测试崩溃入口必须只在内部测试构建或受保护菜单启用，不能让普通用户触发。演练覆盖 Dart exception，发布策略还应按风险覆盖原生崩溃和未处理异步错误。若平台受限导致无法自动化，记录人工步骤和证据。

符号化失败先查 release/build/架构是否匹配、symbols 是否来自同一构建、上传是否完成、监控配置是否指向正确项目，再查 SDK。不要直接重新上传“最新 symbols”，这可能让错误变得更难追踪。

## 15. 监控隐私、采样与告警

监控目标是发现影响用户的失败，不是复制用户数据。定义字段白名单、脱敏、采样、访问角色、留存和删除。URL 要去掉 token/query 敏感值；HTTP body默认不采集；截图和 session replay 对工单照片、位置与人员信息风险很高，未经过专项评审不要启用。

告警应基于版本、影响用户数、错误率和关键路径，而不是每个异常发一封邮件。首次出现、发布后突增、登录/提交工单等高价值路径优先。正常权限拒绝和用户取消不是 crash，应作为产品指标单独聚合，避免警报疲劳。

监控不可用时，应用核心功能应按策略降级，不把崩溃上报放在业务成功前。上报失败也不能把事件无限写入无界本地队列；定义容量、过期和删除。

## 16. 分阶段发布降低爆炸半径

发布通常依次经历内部测试、封闭测试、灰度/分阶段和全量。每阶段定义进入条件、观察窗口、核心指标、停止条件和负责人。不能因为商店允许分阶段就没有内部 smoke，也不能看到总崩溃率正常就忽略“提交工单”特定版本错误。

指标至少按 version/build、平台、系统和设备类别切分：启动成功、关键 API 错误、崩溃用户、ANR、工单提交成功、离线重放冲突和性能高分位。样本很小时不做过度统计结论，但严重数据损坏和安全故障即使一个也需停止。

商店审核、传播和用户自动更新都有延迟。按下“暂停发布”不能撤回已经安装的版本，因此服务端兼容、功能开关和数据迁移策略必须提前准备。

## 17. 回退不是简单上传旧包

移动商店通常不能让所有用户立即降级到旧二进制，iOS/Android 对版本号也有约束。实际恢复手段可能是暂停 rollout、发布新构建号的修复包、关闭服务端功能开关、恢复兼容 API、禁用危险写操作或展示维护提示。

数据 schema 是最大风险。新客户端已经写入的新格式不能靠旧客户端自动理解；破坏性迁移需要 forward/backward compatibility、双读写或明确最低版本。离线队列中旧命令也可能在回退后重放，服务端必须保持幂等和版本合同。

回退清单要在发布前写：触发阈值、决定人、商店操作、开关、后端兼容、用户沟通、监控查询、数据校验与恢复结束条件。演练使用 staging/内部轨道，不能首次在真实事故中发现没有权限暂停。

## 18. 三类高风险故障的诊断

### 18.1 签名环境串线

症状是 production 包指向 staging、使用 debug证书，或 Bundle ID 与 profile 不匹配。首证据是包内 ID/endpoint、签名指纹、flavor manifest 与构建日志。修复配置矩阵和 fail-closed 门禁，重新生成新构建号 RC；不能重命名旧包。残余风险是密钥系统或手工 Xcode 配置仍可能漂移。

### 18.2 符号未归档

症状是混淆崩溃只有不可读地址，artifact 有 hash 但 symbols 缺失或不匹配。首证据是 RC manifest 中 symbol hash/路径和归档系统。若同一构建原始 symbols 已丢失，通常无法可靠靠重建恢复；应停止该 RC，修复“构建后符号必需”门禁，生成新 RC并演练。

### 18.3 崩溃无法关联版本

症状是监控只有 `1.4.0`、没有 build/flavor/commit，或事件进入错误项目。首证据是应用运行时 release tag与 manifest对比。修复启动配置和监控项目隔离，注入测试崩溃并确认符号化；历史事件可能仍无法区分，要明确数据缺口。

诊断时先读第一条指向本制品/配置的证据，不以最终“upload failed”猜测。修复后必须重跑原构建、签名检查或符号化演练，并生成新的证据链。

## 19. FactoryCare 发布候选清单

FactoryCare 客户端提交和离线重放会改变服务端业务事实，因此发布前需额外确认：Java API仍兼容旧客户端；12 个工单状态与错误 code不漂移；离线命令 schema和幂等键升级可迁移；租户切换会清缓存；production API allowlist唯一；相机/定位隐私声明与实际使用一致。

候选流程可以是：冻结 commit和 lockfile；跑单元/Widget/集成/Golden/性能策略；生成 production AAB/IPA；验证 ID、版本、签名和 endpoint；计算 artifact/symbol hash；在隔离设备安装；执行登录、设备扫码 Fake/真机计划、工单加载、离线提交与恢复；注入测试崩溃并符号化；完成回退演练；批准分阶段发布。

每一步的“未执行”都必须保留未验证状态。没有 Apple账号就只完成 iOS 配置合同，不能勾选 IPA签名；没有物理 Android 就不能把模拟器安装写成真机 smoke。

## 20. CI 的边界

通用 CI/CD、runner加固、供应链证明和多环境部署在后续生产化卷系统学习。本章只定义 Flutter 发布 job 的输入、门禁和输出合同。无论使用 GitHub Actions、GitLab、Jenkins 或托管移动平台，合同不变：受审源码进入，秘密最小暴露，测试和构建有证据，artifact/symbol成对归档，批准后才发布。

CI 不能从任意分支访问 production签名；production job应固定受保护 ref、审批和权限。第三方 action/插件也是供应链依赖，需要锁定版本和审查。runner日志、缓存和 artifact保留都要避免泄密。

本章不会提供可直接复制的云流水线，因为用户尚未选择平台、账号、签名政策和发布轨道。提前编造 YAML 只会制造虚假可用性。

## 21. AI 协作边界

AI 可以生成 manifest schema、核对配置矩阵、解析签名验证输出、比较 artifact和symbol索引、为发布清单补缺项、归类脱敏崩溃、草拟回退演练。AI 可以帮助检查命令，但不得接收真实私钥和完整 secret。

开发者必须控制账号、密钥、证书、商店审批、隐私声明、构建环境、符号归档、测试设备、监控查询和 rollout决策。AI 看到 `BUILD SUCCESSFUL` 不能宣称签名正确或商店通过；看到源码 handler也不能宣称崩溃已经上报并符号化。

禁止让 AI 在日志输出 secret排查问题、生成伪造签名/商店截图、用 debug包充 release、补写不存在的真机结果、自动接受 Golden、删除 symbols减小存储，或把“可能已上传”写成 verified。

## 22. 本章动手路线

### 22.1 Example：发布 manifest 合同

运行 `examples/encyclopedia/ch.flutter.release-monitoring/verify.sh`。它在临时目录生成合成 artifact、symbols和 release manifest，计算 hash并验证 production flavor、版本、commit、签名指纹元数据与监控 release 一致。它没有生成 AAB/IPA或签名。

### 22.2 Lab：串线、缺符号与版本关联

运行 `labs/encyclopedia/ch.flutter.release-monitoring/verify.sh`。Lab 对合成 RC执行门禁，先验证正确链，再注入 staging endpoint、缺 symbol索引与错误 release tag，确保首证据确定。运行前预测：artifact hash正确能否弥补错误签名环境？

### 22.3 Exercise：稳定预期红

运行 `exercises/encyclopedia/ch.flutter.release-monitoring/verify.sh`。初始 manifest故意没有 symbols hash，并把监控 release 只写成用户版本；验证器稳定非零。任务是补齐可关联字段和成对归档，不得删除检查。私有解展示同一合同的绿版本。

### 22.4 120 秒讲回

解释 flavor、build mode、服务环境和签名身份为何独立；版本名与构建号各做什么；客户端配置为何不能藏 secret；AAB/IPA是什么；混淆为何不是加密；symbols为何必须与制品成对；崩溃如何关联 release；为什么暂停 rollout不等于所有用户回退。

## 23. 已验证、未验证与明确不做

随附脚本只验证合成文本 artifact 的 manifest、SHA-256、环境矩阵、符号索引和监控 release关联。它们不调用 Flutter、Gradle、Xcode、codesign、jarsigner、商店 API或任何监控服务，不读取真实密钥，也不产生可安装包。

本章**没有验证**本机 Flutter 3.44.x/Dart 3.12.x、Android SDK/Gradle/JDK、完整 Xcode/CocoaPods、真实 AAB/APK/IPA、Android/iOS签名、证书/profile、物理设备安装、App Store/Play上传审核、TestFlight/内部轨道、混淆符号、真实崩溃上报、原生 crash/ANR、隐私清单或回退权限。任何这些项都必须在真实项目和账号中另行取证。

本章明确不创建或轮换密钥，不上传商店，不启用监控 SDK，不选择 CI品牌，不实施通用供应链平台，不变更 FactoryCare服务端，不把离线 hash验证冒充签名验证，也不修改学习进度。

## 24. 官方资料与版本边界

以下资料于 2026-07-24 核对，Flutter官方页面当时属于 3.44 文档家族；Android、Apple、商店、Xcode、Gradle、插件和监控政策变化快，真实发布当天必须重新确认：

- [Flutter：Build and release an Android app](https://docs.flutter.dev/deployment/android)
- [Flutter：Build and release an iOS app](https://docs.flutter.dev/deployment/ios)
- [Flutter：Set up Flutter flavors for Android](https://docs.flutter.dev/deployment/flavors)
- [Flutter：Set up Flutter flavors for iOS and macOS](https://docs.flutter.dev/deployment/flavors-ios)
- [Flutter：Obfuscate Dart code](https://docs.flutter.dev/deployment/obfuscate)
- [Flutter：Handling errors](https://docs.flutter.dev/testing/errors)
- [Flutter：Continuous delivery](https://docs.flutter.dev/deployment/cd)
- [Flutter stable SDK archive](https://docs.flutter.dev/install/archive)
- [Android Developers：Sign your app](https://developer.android.com/studio/publish/app-signing)
- [Apple Developer：Code signing](https://developer.apple.com/support/code-signing/)

发布身份、最小秘密、制品—符号—事件关联和分阶段回退属于长期稳定原则；具体命令、输出目录、签名模型、商店字段、最低平台和监控 SDK 属于变化面。因此本章 `stable_core: false`，所有真实结论都必须绑定当次版本和可追溯证据。
