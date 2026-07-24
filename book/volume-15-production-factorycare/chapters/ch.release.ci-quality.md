---
schema_version: 2
edition: 2026.2-draft
id: ch.release.ci-quality
title: CI 流水线、测试门禁与失败证据
responsibility: 把格式、静态检查、单元/集成/安全测试和构建组织为可重复 CI 门禁，保存失败证据且禁止失败后继续发布。
volume: '15'
order: 6
level: L3
status: drafting
path: book/volume-15-production-factorycare/chapters/ch.release.ci-quality.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.foundations.git-collaboration-security
- ch.foundations.dependencies-build-packages
version_surfaces:
- ci
- git
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“CI 流水线、测试门禁与失败证据”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - release-ci-pipeline
  - release-quality-gate
  covers_topics:
  - release.ci-trigger
  - release.ci-job-stage
  - release.ci-cache
  - release.ci-concurrency
  - release.required-check
  - release.test-report
  - release.coverage-boundary
  - release.failure-artifact
  uses_capabilities:
  - foundation.git-security
  - foundation.toolchain-env-build
  - foundation.verification-debug-test
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 围绕“CI 流水线、测试门禁与失败证据”构建可运行程序与测试：为 Java、Vue 和 Python 子项目定义并行 CI，锁定工具链，发布 JUnit/覆盖率/浏览器报告并设置必需检查；独立保存可复现工件与判断结果
  covers_topic_groups:
  - release-ci-pipeline
  - release-quality-gate
  covers_topics:
  - release.ci-trigger
  - release.ci-job-stage
  - release.ci-cache
  - release.ci-concurrency
  - release.required-check
  - release.test-report
  - release.coverage-boundary
  - release.failure-artifact
  uses_capabilities:
  - foundation.git-security
  - foundation.toolchain-env-build
  - foundation.verification-debug-test
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: ci-matrix-run-intentional-failure-artifact-retention-check
- id: diagnose
  kind: fault-diagnosis
  text: 面对“缓存键忽略锁文件、测试失败仍执行发布、只保留绿色日志或 PR 可读取生产密钥”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - release-ci-pipeline
  - release-quality-gate
  covers_topics:
  - release.ci-trigger
  - release.ci-job-stage
  - release.ci-cache
  - release.ci-concurrency
  - release.required-check
  - release.test-report
  - release.coverage-boundary
  - release.failure-artifact
  uses_capabilities:
  - foundation.git-security
  - foundation.toolchain-env-build
  - foundation.verification-debug-test
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# CI 流水线、测试门禁与失败证据

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《Git 状态模型、远程协作、冲突与凭据处置》](../../volume-00-computer-foundations/chapters/ch.foundations.git-collaboration-security.md)：CI 触发、提交身份、分支保护和凭据边界依赖 Git 安全能力。
- [《依赖、包管理、构建生命周期与可重复性》](../../volume-00-computer-foundations/chapters/ch.foundations.dependencies-build-packages.md)：可复现安装、锁文件和构建产物是 CI 的输入合同。
<!-- END GENERATED LEARNING PREREQUISITES -->

持续集成（Continuous Integration，CI）把每次候选变更放进一致环境，自动执行格式、静态检查、编译、测试、安全检查与构建，并把结果反馈给团队。它的价值不是出现一个绿色图标，而是让“什么代码允许合并、失败在哪里、用什么证据判断、同一提交能否重现”成为公开合同。

本章用 GitHub Actions 作为 2026 版示例表面，但稳定核心适用于其他 CI：触发器选定源码快照，job 组成有依赖的执行图，门禁只接受所有必需条件，缓存只能优化，制品与报告用于传递和审计，失败必须阻止发布并保留证据。平台权限、工作流语法、官方 action 版本和 runner 镜像会变化，必须查当前官方文档。

本章只构建 CI 与质量门禁，不负责制品晋级、部署和数据库迁移。即使工作流能执行发布命令，也要等后续章节定义制品身份、环境审批和回滚合同。

## 1. CI 到底验证哪个对象

CI验证的不是“开发者电脑上的代码”，而是某个 Git 提交、合并候选或引用解析出的源码快照，加上工作流、依赖锁文件、工具链、外部服务和运行环境。报告必须能关联到 commit SHA；否则绿色结果可能属于前一个提交。PR 页面上的检查通常还涉及平台生成的合并提交，要明确分支保护要求验证 head 还是 merge结果。

输入合同至少包含：源码提交、仓库子模块或大文件版本、JDK/Node/Python版本、Maven/pnpm/uv锁定信息、操作系统/runner标签、环境变量名称、测试夹具和服务镜像身份。CI从网络下载未锁定依赖时，同一提交隔天可能得到不同结果；这不是“偶尔坏”，而是输入没有闭合。

一次 workflow run、一个 job 和一个 step 不是同义词。workflow由事件触发；job在独立runner上下文执行，可并行或通过 `needs` 建立依赖；step在同一job中顺序运行，共享工作目录和部分环境。另一个job默认不能看到当前job生成的文件，需重新构建或用artifact传递。

### 1.1 CI 与本地验证

本地快速反馈和CI互补。本地开发可以只跑受影响测试，CI门禁则必须按团队合同覆盖完整必需集合。命令最好相同，例如 Java都运行 `./mvnw -B test`，Vue都用锁文件安装后执行统一脚本，Python都通过 `uv sync --locked` 和 `uv run pytest`。若CI藏着只有平台能运行的神秘脚本，故障很难复现。

“我本地通过”只证明本地输入；“CI通过”也只证明工作流声明的条件。两边不同首先比较版本、锁文件、环境、时区、文件系统大小写、并发和外部服务，不要立即把问题叫作CI抽风。

## 2. 触发器决定你验证什么风险

常见事件包括 `pull_request`、向特定分支 `push`、手工 `workflow_dispatch`、定时 `schedule` 和被其他工作流调用。PR验证代码是否适合合并；main push可验证真实落地主线提交；定时任务可发现依赖或外部兼容漂移；手工执行适合明确参数和审批的运维流程。不能用一个触发器替代所有目的。

路径过滤能减少无关任务，但也会产生门禁缺失：如果必需检查因为路径过滤没有创建，分支保护可能一直等待或被绕过。monorepo应建立总调度检查，可靠判断哪些子项目受影响，并让最终统一gate总是产生确定结论。路径规则还要覆盖共享脚本、锁文件、Dockerfile和工作流本身。

### 2.1 不可信PR

来自fork的PR包含攻击者控制的代码。运行测试就等于在runner上执行它，不能同时给生产密钥、云写权限或可污染受信缓存。`pull_request_target` 等高权限触发语义尤其需要谨慎：如果在基础仓库权限下检出并执行PR代码，会形成直接供应链入口。安全原则是低信任代码使用最小只读Token、不注入生产secret、不连接生产网络、不复用高信任持久runner。

PR测试需要的数据库应是一次性夹具，凭据只对本次作业有效。需要人工审批的外部贡献流程，可以先跑无密钥检查，再由受信维护者决定是否进入隔离的后续验证；审批不是让攻击者代码自动获取生产权限。

## 3. 从串行脚本到job依赖图

最简单流程把所有命令放一个job：安装全部工具，依次测试Java、Vue、Python，最后构建。它容易开始，但任一早期失败会阻止后续独立证据，耗时也长。合理拆分为 `java-test`、`web-test`、`python-test`、`security` 和 `build`，独立job并行；构建或release gate通过 `needs` 等待所有必需结果。

拆分不是越细越好。每个job都有排队、拉取源码和安装成本，跨job状态传递更复杂。决策维度包括：能否独立失败、是否使用不同工具链、是否需要不同权限、耗时、证据类型和是否能并行。格式与静态检查很快，可以单独早失败；浏览器E2E需要服务拓扑，通常独立保留报告。

### 3.1 `needs` 是门禁边，不是装饰

默认情况下job可并行。发布job若没有显式依赖全部必需检查，可能在测试仍运行甚至失败时执行。最终gate应列出完整必需集合，并只在它们成功时继续。动态矩阵要汇总为稳定检查名，否则分支保护配置容易漂移。

不要用 `if: always()` 放宽发布。`always()`适合上传失败日志、清理和通知；发布必须要求上游结论全为成功。某个非关键观测任务允许失败，应在政策中显式标为非阻塞，并说明为何不影响质量，不要随手 `continue-on-error: true`。

## 4. 可复现工具链与依赖

CI runner通常是一次性环境。工作流必须安装或选择明确JDK、Node、pnpm、Python、uv版本，校验输出，并用项目锁文件安装。`ubuntu-latest` 是移动标签，适合希望跟随平台升级的兼容任务，但关键发布需要明确基线并通过计划升级。即使固定 `ubuntu-26.04`，平台镜像内预装工具也会更新；关键工具仍应显式选择并记录。

Java使用 Maven Wrapper时，wrapper脚本和配置属于仓库输入，JDK要与 `maven.compiler.release`、测试和运行基线一致。Vue使用pnpm时，`pnpm-lock.yaml`必须提交，CI用冻结锁模式；Python使用uv时，`uv.lock`与Python版本共同决定环境，`uv sync --locked` 遇到漂移应失败，而不是偷偷重写锁。

### 4.1 安装成功不是测试成功

依赖恢复、编译、单元测试、集成测试和构建是不同阶段。日志应能显示失败发生在哪。一个 `npm test && npm build` step虽可阻止后续，但平台只显示整个step失败，证据不细；可拆为命名step，并始终上传对应报告。拆分后仍要保证任何失败使job非零。

Shell脚本需要 `set -euo pipefail` 或等价明确错误处理，不能让管道前半失败被最后一个命令的0覆盖。每种构建工具也有“跳过测试”选项，生产构建不能无意使用。测试和构建之间若重复编译，要权衡速度与同一制品原则。

## 5. 多技术栈的FactoryCare CI

Java API job最少执行格式/静态检查、编译、单元测试和需要的集成测试，输出Surefire/Failsafe XML、覆盖率和构建日志。数据库集成测试使用隔离实例和确定迁移，不能连接共享开发库。最终JAR应由已通过门禁的同一源码生成，记录摘要。

Vue Web job先冻结锁安装，执行TypeScript类型检查、lint、单元/组件测试和构建。浏览器E2E需要明确浏览器版本、服务URL、seed数据、截图/trace/video保留策略。只跑Vite build不能证明交互正确，E2E全绿也不能替代快速单元测试。

Python AI job验证格式、类型/静态分析、pytest和数据/模型合同。测试使用小型确定夹具，不下载未固定大模型。Python只能生成可重建派生结果，CI不得把模型输出直接写为Java业务事实。若有模型制品，评估门槛和数据版本要独立记录。

### 5.1 矩阵何时使用

矩阵适合验证多个支持版本、操作系统或浏览器，但组合会快速膨胀。先定义支持合同：例如Java只支持JDK25，便不需为了“看起来全面”测试任意旧版；Vue可能只在一个Node LTS构建，但浏览器关键路径测试多个目标。矩阵每一格都应回答风险问题。

允许某个未来版本实验性失败时，标为非阻塞并单独命名；不要让红灯长期存在导致团队习惯忽略。正式支持版本全部必须进入gate。

## 6. 缓存不是制品

缓存保存可重新下载或生成、且频繁复用的内容，例如Maven本地仓库、pnpm store或uv下载缓存。它的目标是加速，命中与否不能改变正确结果。cache key至少包含操作系统/架构、工具链和相关锁文件摘要；锁文件变化而key不变会恢复不兼容内容。

artifact保存本次运行产生、需要在job间传递或事后查看的文件，例如测试XML、覆盖率、浏览器trace、JAR、静态站点和失败日志。artifact与commit/run关联，应有保留期限、访问控制和摘要。不能把缓存当发布制品，因为缓存可被淘汰、部分匹配、覆盖策略与来源语义不同。

### 6.1 缓存安全

恢复缓存等于使用外部字节。低信任PR可能读取某些缓存，也可能尝试污染后续上下文；缓存中绝不能放Token、证书、`.env`和生产配置。构建缓存若包含可执行文件，要考虑投毒。高信任发布应重新验证输入和制品，而不是盲信一次命中。

调试缓存问题时先禁用缓存重跑。若无缓存绿、有缓存红，比较key、restore key、锁文件和实际恢复路径。修复不是永久删除所有缓存，而是让缓存身份包含所有影响内容，或只缓存下载而不缓存未经验证的最终产物。

## 7. 质量门禁与required checks

质量门禁是布尔政策：所有必需检查都成功，候选才允许合并或晋级。报告则提供连续或详细信息，例如覆盖率82%、三条warning、测试耗时。不是所有报告数字都必须设硬阈值，但门禁必须说明输入和判据。

GitHub分支保护/规则集可以要求特定检查。检查名是外部合同，随意改job名可能让保护规则等待旧名或失去约束。工作流变更要与仓库设置一起审查。管理员绕过也应有审计和事后补验，不应成为赶时间常规。

### 7.1 覆盖率边界

代码覆盖率说明测试执行过哪些语句/分支，不证明断言正确、需求完整或边界安全。追求100%可能产生无意义测试；过低和突然下降则是风险信号。可设置“总量不低于基线”和“变更代码最低覆盖”作为辅助门槛，同时审查关键领域状态机、权限和错误路径。

变异测试、契约测试和故障注入能补充覆盖率，但也不产生绝对正确。FactoryCare应优先保证Java业务状态机、鉴权、并发和数据库约束的高价值测试，客户端验证映射和交互，Python验证派生算法与重建边界。

### 7.2 flaky测试不能直接重跑到绿

偶发失败说明环境、时间、并发、随机性或代码有未控制因素。自动重跑可收集统计或暂时降低噪声，但最终报告必须显示首次失败和重试次数。把“重跑三次取一次成功”当门禁会系统性隐藏缺陷。修复应固定时钟/seed、隔离数据、等待条件而非sleep，并删除测试间共享状态。

## 8. 失败证据为什么必须 `always()` 保存

CI最需要证据的时刻正是失败时。如果上传报告step默认只在前面成功时运行，红灯只剩一句“exit 1”。上传测试XML、日志、截图、trace和诊断摘要可使用失败后仍执行的条件，但上传失败不能反向把测试结论改成成功。

证据至少标明commit、job、尝试次数、工具版本、测试名称、时间和环境。JUnit XML让平台呈现测试；浏览器trace可重放交互；应用日志与数据库容器日志需按关联ID和时间范围保存。保留期限按敏感性和审计需要设置，报告中不得含Token和用户数据。

### 8.1 日志不是唯一artifact

控制台日志常被截断，颜色和并发输出不利于机器解析。测试框架的结构化报告更稳定。构建失败时可保存编译诊断而非半成品JAR；E2E失败保存截图、trace和服务日志；依赖错误保存锁文件摘要和解析器输出。成功运行也可保存摘要，但高体积调试制品可只在失败上传。

“只保留绿色日志”会让CI无法诊断。注入故障验收要证明失败job仍产生可下载证据，且release未执行。真实平台需用run URL和artifact摘要作为证据，本地静态扫描不能替代。

## 9. 并发、取消与过期结果

每次push都触发CI时，同一PR可能并发多个旧提交。对纯验证可按workflow和PR/ref设置concurrency，`cancel-in-progress`取消过期运行，节省资源并避免旧结果晚于新结果出现。取消不是成功，最终gate必须对应最新commit。

部署不能随便套同一取消策略。一个正在执行数据库变更的发布被强行取消可能留下半状态；部署并发要按环境串行，使用可恢复步骤和明确锁。GitHub Actions当前官方文档还区分并发组、取消与排队语义，具体设置必须按平台当前版本核验。

并发组表达式要避免不同工作流意外同名互相取消，也要防大小写或ref差异。复用工作流中，调用者和被调用者使用相同组可能自我取消，官方文档对此有明确提醒。测试要模拟两个快速提交和两个不同PR。

## 10. Token、权限和第三方Action

工作流应显式声明最小 `permissions`。只读测试通常只需 `contents: read`，发布包、写检查、OIDC换取云凭据再对特定job添加必要权限。声明某些权限后，未声明权限通常会变成none，但具体可用权限名称随平台扩展，应查当前语法参考。

第三方action就是在runner中执行的供应链代码。GitHub官方安全文档建议固定完整commit SHA，完整SHA是当前不可变使用方式；标签和主版本标记可以移动。固定SHA仍需确认来源仓库和审查更新，依赖更新机器人提出新SHA后由测试与审查批准。教材夹具中的40位重复数字只是静态格式示范，不是真实可下载action身份。

### 10.1 Secret生命周期

secret只注入确实需要的job和step，不放全局env，不回显，不写缓存/artifact。优先短期OIDC凭据而非长期云密钥，但OIDC也要限制仓库、分支、环境和audience。PR工作流默认不应获得生产secret；自托管runner需隔离低信任代码，避免读取宿主残留。

日志脱敏不是绝对保护。把secret变形、编码或分片后可能逃过遮罩。最佳控制是攻击者代码根本拿不到值。发现泄露立即撤销/轮换，再清理日志和调查范围，不能只删除输出。

## 11. 一个可读的工作流骨架

下面只展示结构，`uses`后必须替换为从官方仓库核验的真实完整SHA：

```yaml
name: factorycare-ci
on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  java-test:
    runs-on: ubuntu-26.04
    steps:
      - uses: actions/checkout@<verified-full-sha>
      - run: ./mvnw -B test
      - if: always()
        uses: actions/upload-artifact@<verified-full-sha>

  web-test:
    runs-on: ubuntu-26.04
    steps:
      - uses: actions/checkout@<verified-full-sha>
      - run: pnpm install --frozen-lockfile
      - run: pnpm test

  release-gate:
    needs: [java-test, web-test, python-test, security, build]
    runs-on: ubuntu-26.04
    steps:
      - run: echo "all required jobs succeeded"
```

真正工作流还要为Python、报告参数、超时、缓存key、服务容器、制品和安全检查补齐合同。不要复制占位SHA运行；它故意不是有效action提交。工作流YAML解析也有平台语义，使用平台检查与一次PR运行验证。

## 12. 四类故障注入

### 12.1 缓存键忽略锁文件

修改依赖锁文件但缓存key不变，恢复旧依赖后出现编译或测试异常。首个可信证据是key输入未包含锁摘要及恢复日志。修复key后分别跑cache miss和hit，两者结果应一致。残余风险是宽泛restore key仍恢复不兼容层。

### 12.2 测试失败仍发布

让一个确定单测失败，观察release job仍开始。首证据是依赖图/条件不包含该测试或使用了错误的 `always()`。修复后同一失败必须阻止发布，同时保留报告；恢复测试后才允许gate通过。不要用人工停止替代结构门禁。

### 12.3 只保留绿色日志

注入E2E失败，artifact上传step被跳过。首证据是step默认success条件或路径错误。修复为失败也执行，并让“报告不存在”本身产生可诊断失败。验证下载、解压和关联commit，不只看上传step绿。

### 12.4 PR读取生产密钥

不应拿真实密钥做实验。静态检查工作流触发器、环境与permissions，并用哨兵值在隔离仓库证明不可信PR拿不到。若发现真实泄露，先撤销轮换。修复包括拆分高低信任workflow、环境审批和最小权限，不能依赖贡献者善意。

## 13. 失败阶段与首个可信位置

工作流未创建，先看事件和路径过滤；job排队，检查runner、并发和权限；setup失败，检查工具版本与下载；依赖失败，看锁与registry；compile失败，先看编译器第一条项目错误；test失败，读测试名、expected/actual和报告；artifact失败，不覆盖原测试结论；gate错误，检查needs和结论；发布被错误执行，立即停止下游并审计影响。

平台总结常只显示最后失败step，真正原因可能更早。保留每阶段退出码和结构化报告，用故障注入建立已知样本。不要一看到红灯就重跑；先保存run ID、commit和证据。重跑会改变缓存、时序和外部状态。

## 14. 本章可运行资产

示例用纯Python模拟五个required jobs，只有全部存在、成功且有证据才允许release。实验静态扫描受控GitHub Actions夹具，检查只读权限、concurrency、完整SHA格式、Java/Vue/Pythonjob、完整needs、失败artifact和锁定安装。公开练习故意用 `any`，一个job成功便错误放行；私有解答使用非空required集合上的 `all`。

这些资产没有访问GitHub API、没有创建workflow run、没有验证仓库required-check设置、没有下载action、没有读取secret，也没有上传artifact。夹具中的SHA是合成占位。绿色只能证明静态合同和门禁函数，不能声称云CI已部署。

完整实验在测试仓库执行：创建成功PR；分别注入Java编译、单测、浏览器和依赖失败；确认对应stage最早失败、其他独立job仍收集证据、release gate不运行、失败artifact可下载；恢复后同一commit或新commit全部绿。保存run URL、commit、workflow digest和artifact摘要。

## 15. FactoryCare完成判据

成功提交必须让Java、Vue、Python和安全/构建必需job全部通过；每个工具链版本可见；依赖按锁文件；最终gate与分支保护一致；测试/覆盖率/浏览器失败报告可获取；制品关联commit与摘要；不可信PR无生产权限；旧commit运行可取消但不会把取消当成功。

分别注入编译、单测、E2E和依赖错误时，流水线在对应阶段停止且不发布。缓存关闭/命中结果一致。故障修复后重跑原判据。任何未在真实平台验证的required-check、artifact、权限和并发语义都列为未验证，不能用本地解析代替。

还应建立“工作流自身变更”的审查门槛：修改触发器、权限、`needs`、secret、runner或发布条件时，由另一名维护者检查影响，并先在隔离分支执行。业务代码评审不能默认工作流只是普通文本，因为一行权限或条件变化就可能绕过全部质量门禁。合并后再核对主分支规则中的必需检查名，避免YAML已经更名而平台仍等待旧检查，或旧保护规则静默失去作用。

## 16. 官方资料入口

- GitHub Actions工作流语法：<https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax>
- GitHub Actions安全使用参考：<https://docs.github.com/en/actions/reference/security/secure-use>
- 并发概念：<https://docs.github.com/en/actions/concepts/workflows-and-actions/concurrency>
- workflow artifacts与cache区别：<https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts>
- dependency cache安全与行为：<https://docs.github.com/en/actions/concepts/workflows-and-actions/dependency-caching>

平台文档会更新，因此章节不固定某个action标签或runner预装版本。采用时记录核验日期和真实完整SHA；升级通过依赖PR、审查和故障注入门禁完成，而不是把教程占位值复制到生产。
