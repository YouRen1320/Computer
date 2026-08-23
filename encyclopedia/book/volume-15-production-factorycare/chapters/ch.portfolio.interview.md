---
schema_version: 2
edition: 2026.2-draft
id: ch.portfolio.interview
title: 作品集、技术表达、岗位映射与面试复盘
responsibility: 把真实可验证的学习和项目证据整理为作品集、岗位匹配叙事与面试复盘，准确区分本人贡献、AI 辅助和未验证部分，不包装虚假经历。
volume: '15'
order: 17
level: L3
status: drafting
path: book/volume-15-production-factorycare/chapters/ch.portfolio.interview.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.release.factorycare-acceptance
- ch.foundations.ai-assisted-verification
- ch.foundations.learning-evidence
version_surfaces:
- git
route_tags:
- zero-base
- accelerated-48
- reference
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“作品集、技术表达、岗位映射与面试复盘”的职责、边界、关键证据与一个越界反例
  covers_topic_groups:
  - portfolio-evidence-story
  - portfolio-job-interview
  covers_topics:
  - portfolio.case-study
  - portfolio.architecture-decision
  - portfolio.failure-recovery-story
  - portfolio.ai-assistance-disclosure
  - portfolio.job-requirement-mapping
  - portfolio.resume-claim-evidence
  - portfolio.interview-teachback
  - portfolio.retrospective-loop
  uses_capabilities:
  - foundation.learning-evidence
  - foundation.git-security
  - foundation.verification-debug-test
  - ops.recovery-deployment
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 生成 FactoryCare 双语项目案例、证据索引、岗位 JD 能力矩阵、三段故障故事和一场录制模拟面试，逐条链接可验证工件；独立保存可复现工件与判断结果
  covers_topic_groups:
  - portfolio-evidence-story
  - portfolio-job-interview
  covers_topics:
  - portfolio.case-study
  - portfolio.architecture-decision
  - portfolio.failure-recovery-story
  - portfolio.ai-assistance-disclosure
  - portfolio.job-requirement-mapping
  - portfolio.resume-claim-evidence
  - portfolio.interview-teachback
  - portfolio.retrospective-loop
  uses_capabilities:
  - foundation.learning-evidence
  - foundation.git-security
  - foundation.verification-debug-test
  - ops.recovery-deployment
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: claim-evidence-audit-timed-mock-interview-jd-gap-review
- id: diagnose
  kind: fault-diagnosis
  text: 面对“简历声称未做过的三年经验、只展示成功截图、无法解释 AI 生成代码或把团队/工具贡献全部写成本人独立完成”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - portfolio-evidence-story
  - portfolio-job-interview
  covers_topics:
  - portfolio.case-study
  - portfolio.architecture-decision
  - portfolio.failure-recovery-story
  - portfolio.ai-assistance-disclosure
  - portfolio.job-requirement-mapping
  - portfolio.resume-claim-evidence
  - portfolio.interview-teachback
  - portfolio.retrospective-loop
  uses_capabilities:
  - foundation.learning-evidence
  - foundation.git-security
  - foundation.verification-debug-test
  - ops.recovery-deployment
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
---
# 作品集、技术表达、岗位映射与面试复盘

<!-- BEGIN GENERATED LEARNING PREREQUISITES -->
## 学习前检查

以下章节是本章的硬前置。开始前，请先完成并验证对应能力：

- [《FactoryCare 端到端验收与可回滚发布》](ch.release.factorycare-acceptance.md)：作品集中的架构、安全、AI 和发布主张必须由完整验收证据支撑。
- [《AI 协作、隐私、补丁审查与可证伪验证》](../../volume-00-computer-foundations/chapters/ch.foundations.ai-assisted-verification.md)：AI 生成内容必须经过预测、验证、故障注入和本人复述后才能作为能力主张。
- [《学习证据、掌握标准与间隔复习》](../../volume-00-computer-foundations/chapters/ch.foundations.learning-evidence.md)：简历与面试主张必须回链到按日保存的预测、命令、失败、修复和复述证据。
<!-- END GENERATED LEARNING PREREQUISITES -->

作品集不是把项目截图排列得漂亮，也不是把技术名词堆满简历。它是一组可验证的能力主张：你解决了什么问题，负责哪一段边界，为什么选择这种设计，遇到什么失败，怎样定位和修复，最后用什么证据证明结果。面试则是对这些主张进行限时复述和追问验证。两者的共同底层是证据，而不是包装。

AI 时代，写出代码的成本下降，理解和负责结果的门槛反而更清晰。候选人可以使用 Codex、Claude 或其他工具，但必须能说明输入约束、审查过程、失败注入、测试判据和本人决策。说“全部是 AI 写的”既没有解释能力，也不能证明工程结果；说“全部由本人独立完成”而隐藏工具和团队贡献同样不准确。更有价值的表达是：AI 生成了哪些候选实现，本人如何限定边界、验证、发现错误、修改并承担最终结论。

本章把 FactoryCare 的真实学习和工程工件整理成双语案例、证据索引、岗位能力矩阵、故障故事和模拟面试。它不会教你虚构三年经历，也不会把两个月项目改写成三年在职。虚假时间线可能在社保、背景核验、深入追问或入职交付中暴露，而且会让真正可证明的能力失去可信度。更稳健的策略是准确写明工作、试用、个人项目和学习项目的性质，用深度证据提升项目含金量。

## 1. 从“我会”改为“我能证明”

“熟悉 Java”“精通 Vue”“了解 AI”都难以核验。把它们改写成可观察主张：实现了带租户隔离和状态机的工单 API；用并发测试证明过期版本更新被拒绝；三个客户端共享 OpenAPI 合同；模型服务停机时核心流程继续；通过 release manifest 和恢复演练证明候选可回滚。主张越具体，越容易准备证据，也越容易知道自己的缺口。

一条合格主张至少有五部分：对象、动作、约束、结果、证据。例如：“在 FactoryCare Java API 中，为工单状态迁移增加服务端授权和乐观锁；双会话冲突测试中只有一个更新提交，失败方收到 409；证据为提交、JUnit 报告和故障修复记录。”若没有真实测量，不写“性能提升 80%”；可以写“建立了 p95 延迟基线与负载脚本，尚未在生产流量验证”。

证据强度有层次。口头陈述最弱；代码片段比口头强；可复现提交、测试和失败日志更强；在明确环境由他人复跑、带制品身份和评审记录更强。截图可以辅助，但没有命令、版本和判据的绿色截图很容易误解。作品集首页不需要塞入所有原始日志，应提供证据索引，让重要主张能一跳到对应工件。

## 2. 真实经历、项目经历与学习经历

简历时间线必须区分正式工作、试用期、外包/兼职、个人项目和课程项目。公司、日期、职位、合同性质和职责按可核验事实写。若一段试用期只有两个月，就写两个月；可以通过说明交付范围、技术难点和验证结果展示密度，但不能延长日期。个人项目可以很深，深度不需要伪造成公司年限才有价值。

工作经历描述组织背景和本人职责，项目案例描述技术问题。二者可以关联，却不应互相伪造。某项目由团队完成时，先写系统整体，再明确“本人负责”；使用现成后台模板、AI、开源框架或同事代码时，说明自己的选择、改造和验证。没有参与的架构决策不要写成自己主导，可以说“在复盘中重新设计并以个人实验验证”。

如果早期项目证据丢失，不要补造 commit。可保留当时可核验的合同、工资、社保、发布记录或同事证明，并把技术细节标为回忆；另做一个现代复现项目，清楚写“复现”而非“当时上线”。准确边界不会削弱可信度，反而让面试官知道哪些结论可以深入追问。

## 3. FactoryCare 案例研究的结构

案例首页先解决读者的定位问题：FactoryCare 是什么，服务谁，核心工作流是什么，你负责什么，系统现在处于何种验证等级。用一段话说明：“FactoryCare 是多租户设备维修平台；Java API 持有业务事实，Vue/uni-app/Flutter 是客户端，Python 提供可降级 RAG/Agent；项目以合成数据在本地验收，真实云部署、微信审核和生产用户负载未验证。”这比一句“全栈 AI 项目”信息量更大。

第二部分展示需求与约束。列出角色、租户、设备、工单状态、移动权限、AI 引用、发布恢复目标。说明为什么选择模块化单体而不是微服务：团队规模、部署成本、事务一致性和学习目标更适合单体；模块边界仍清晰，未来在压力和组织边界成立时再拆。技术选型要从问题推导，不要反过来为了写简历而硬塞中间件。

第三部分展示架构图和数据流，但图必须与代码一致。标出 Nginx、三个客户端、Java 模块、PostgreSQL、Python 派生服务、模型/MCP、观测与发布链。箭头标协议和信任边界；写入路径只到 Java；Python 不直连业务库。每个框旁写责任和非责任，避免把“用过 Docker”误写成系统设计。

第四部分选择三到五个有深度的工程问题，例如租户隔离、工单状态事务、客户端合同、RAG 引用/拒答、可回滚发布。每个问题使用“背景—约束—方案—替代项—验证—残余风险”结构。不要按文件顺序讲实现，也不要逐行贴代码。读者需要看到你的判断过程。

第五部分给出结果和边界。列真实测试数量、门禁、故障案例和本地环境；性能数字附负载模型；未执行真机、真实 TLS、云 registry 或生产灾备就明确列出。项目状态可以是“学习版验收完成，生产外部条件未验证”，不写“已商业落地”除非确有证据。

## 4. 架构决策记录（ADR）

ADR 用来保存当时为什么这样做，而不是事后把所有选择说成唯一正确。每条包含状态、日期、背景、决策、候选方案、权衡、后果和复审条件。例如“Java 为业务权威、Python 只做派生 AI”可比较三种方案：Python 直接写库、通过 Java API 提案、只读离线建议。选择后两者的原因是授权、状态机、事务和审计只有一个入口。

另一个 ADR 可以解释模块化单体。实现成本低、迁移成本可控、跨模块事务明确、调试简单；代价是必须维护模块边界，不能把所有类放进共享包。何时重新评估：团队独立部署需求、热点负载隔离、发布节奏冲突或故障域证明拆分收益。这样的表达比“微服务太复杂所以没用”更完整。

ADR 还要记录被否决方案的价值。技术决策不是找“最先进”，而是在当前约束下选择。面试追问“为什么不用 Kafka/Redis/Kubernetes”时，可以从一致性、流量、运维、成本和回滚说明现阶段没有证据需要，而不是说自己不会。若未来指标触发，再制定迁移计划。

## 5. 三段故障与恢复故事

成功功能很容易由教程或 AI 生成，故障故事更能体现理解。准备至少三段：编译/依赖或环境错误；业务/安全错误；发布/恢复错误。每段不背 STAR 套话，而是保存真实时间线：预测、命令、首个可信错误、错误假设、定位、最小修复、原验证重跑和残余风险。

第一段可以使用 Java/Maven 学习中的 package 不一致。`compile` 通过而 `testCompile` 报测试类找不到业务类时，说明主代码已经编译，测试源码的包或引用错误；修复后再看 Surefire 的 `Tests run`。重点不是记命令，而是区分 Maven 生命周期阶段、Failures 和 Errors，知道 `BUILD SUCCESS` 必须结合测试数量解释。

第二段可用跨租户缓存泄漏。症状是租户乙查询同 ID 得到甲的缓存结果。首个证据来自响应中的 source/tenant 对照和 cache key，而非数据库。根因是键只包含资源 ID；修复加入租户和影响授权的主体/角色，并重跑列表、详情、RAG 和并发测试。残余风险是其他缓存与异步任务也要审计。

第三段可用错误发布。候选健康检查通过但版本端点显示旧 digest，说明 smoke 命中错误上游或 tag 漂移。通过 release manifest、Compose 解析结果和 Nginx 日志定位；改为 digest 部署并断言响应身份；注入失败后演练回滚。若没有真实 daemon 或 registry，只能把合成 fixture 故事标为实验，不能冒充线上事故。

故障故事最忌讳神化。可以诚实写“最初误以为是依赖未下载，后来从阶段日志发现是 testCompile package 错误”。错误假设后的修正恰恰显示诊断能力。不要把 AI 给出的答案改写成自己瞬间想到；说明你怎样验证它。

## 6. AI 辅助工作的准确披露

AI 使用可以按四层记录：规划与解释；生成初稿；修改现有代码；自主执行工具。每层风险不同。项目证据为关键提交保存提示目标或任务说明、AI 提议、人工修改、测试、故障注入和复述结果。不需要公开全部对话，也不能泄漏秘密，但要能说明哪些决策由你承担。

推荐的表达是：“使用 Codex 生成初始 JUnit 用例和候选实现；我定义状态不变量与租户边界，审查包结构和事务，注入错误期望值与跨租户数据，读取 Maven 阶段日志并修复，最后独立复述。”这比“AI 都会写，工作时 vibe coding 就行”更接近真实工程责任。工具能加速语法和机械修改，不能替你承担生产数据、安全和恢复结论。

面试官可能让你关闭 AI 解释一段代码。准备从输入、状态、分支、异常、资源、并发、测试和边界逐层讲。你不必默写整个框架 API，但必须读懂自己提交的业务路径，能预测修改后的行为。若一段代码无法解释，就暂时不要把它作为能力证据；先缩小范围、实验、补测试和复述。

## 7. 证据索引与 claim ledger

建立 `claims.yml` 或表格，每行包含 claim ID、简历文案、项目、本人角色、证据链接、环境、验证日期、验证等级、未验证项和是否可公开。例如 `FC-TENANT-01` 对应“双租户查询零泄漏”，链接到提交、测试报告和失败注入。若证据移动，索引校验应失败，而不是留下死链接。

证据索引还应检查敏感信息。公开前扫描 Token、私钥、真实手机号、邮箱、数据库地址和客户数据；发现秘密先撤销/轮换。`.gitignore` 只能阻止未来未跟踪文件，不能删除历史中的秘密。作品集最好使用合成 fixture，必要日志做不可逆脱敏。

主张的状态可以是 `verified-local`、`reviewed`、`unverified-external`、`superseded`。本地单元测试不能升级成生产验证；模拟器不能升级成真机；静态 Compose config 不能升级成 daemon 运行。状态精确能防止自己在简历浓缩时无意夸大。

## 8. 从岗位 JD 建立能力矩阵

不要凭感觉说“南京/南昌都要 Java”。在准备求职时采集一段固定时间内、目标城市、目标级别的真实 JD 样本，去重后提取技术、职责、行业、经验和学历要求。记录采集日期和来源，因为市场会变化。把关键词归并为能力，而不是按工具计数：Java/Spring/SQL 属于后端交付；Vue/uni-app 属于客户端；Docker/Linux/CI 属于生产交付；沟通与故障处理也要单列。

矩阵每行写需求、样本频率、自己的证据、证据等级、差距和下一动作。`会 Java` 不算证据；`Spring Boot API + 事务/安全/测试提交`才是。若 JD 要三年正式经验而你没有，矩阵标为硬差距；可以选择接受更低级别、强调可验证作品、寻找重项目岗位或积累真实经历，不能把时间线改长。

将差距分为三类。硬门槛是无法短期改变的学历/年限/资格；核心能力是岗位每天使用且必须补的；加分项是有帮助但不应挤占核心的。学习顺序优先“高频核心且证据薄弱”，而不是看到新框架就学。每两周或一个求职周期更新一次，避免每天被单个 JD 拉走路线。

岗位匹配是双向选择。若岗位要求维护 Java 单体、SQL 和部署，而你的证据覆盖这些，即使不会某个次要库也可投；准备说明迁移类比。若岗位核心是大型分布式系统、生产 Kubernetes 和高并发，而你只有本地学习项目，就准确写差距，不用术语伪装。

## 9. 简历主张如何写

一条项目 bullet 采用“动作 + 关键约束 + 可验证结果”。例如：“设计 FactoryCare 工单状态机与双租户授权，Java 服务统一三客户端写入合同；以冲突、越权和跨租户故障用例验证，关键回归在本地候选环境通过。”如果数字来自合成负载，写明规模与环境；如果没有生产用户，不写“支撑百万用户”。

技术栈可以列，但要按职责组织：Java/Spring Boot/PostgreSQL 是权威后端，Vue/uni-app/Flutter 是客户端，Python/RAG/Agent 是可降级派生能力，Docker/Nginx/CI 是交付。这样读者看得到系统边界，而不是一长串 logo。只碰过一次的工具放到“接触”或不写，避免追问时失去可信度。

工作经历 bullet 只写当时真实发生的贡献。后来在个人项目中补学的 Spring、测试或运维，放在个人项目，不回填到过去公司。工资、社保和离职原因通常不放项目描述，但时间、公司和职位应能与真实材料一致。

中文简历和英文案例不是逐字翻译。技术身份、数字和边界必须一致；英文使用清晰动词与上下文，不堆华丽形容词。每种版本仍共享同一 claim ledger，避免中文写“主导上线”、英文却写“personal prototype”。

## 10. 作品集页面与仓库导航

读者可能只有几分钟。仓库首页先给运行边界、架构图、核心能力、快速验证命令和证据链接。不要要求面试官安装十套环境才能理解。提供短路径：阅读案例；查看三条代表提交；运行本地无外部依赖验证；查看真实外部环境未验证列表。

目录把教材、业务代码、实验、公开练习、私有答案和生成物分开。`PROGRESS.md` 只记录真实学习进度，不能因为生成了教材就自动标完成。公开仓库不提交私有答案、真实秘密和大体积数据库。生成文件说明来源，避免评审者把自动生成内容当手写能力。

演示视频最多证明当时画面。配套写 release ID、commit、环境和脚本。视频流程以用户问题为主：登录、创建、分派、移动处理、AI 引用与降级、故障/恢复；不要在 IDE 文件树中漫游十分钟。出现未验证功能时直接说明，不现场假装。

## 11. 面试的三种表达深度

准备 30 秒、2 分钟和 10 分钟版本。30 秒说明项目、职责和最强证据；2 分钟加入架构边界与一个取舍；10 分钟按问题深入到事务、安全、测试或发布。不是背三篇稿，而是同一事实的不同压缩率。

技术讲解采用“定义—为什么—如何—证据—边界”。例如解释 `mounted`：它是 Flutter State 是否仍挂在树上的布尔属性；异步完成后在 `setState` 前检查可防止销毁后更新 UI；它不能取消网络请求，也不能防止重复调用；取消需要客户端/请求层机制；用页面销毁测试验证。这种回答比背一句“mounted 防内存泄漏”准确。

遇到不会的问题先界定。可以说“我没有在真实生产用过这个组件；我理解它解决 X，与我做过的 Y 相似；我会先核对版本文档并用最小夹具验证 Z。”不要编造线上经验，也不要只说不知道。区分稳定原理和当前 API，面试官能看到学习方法。

现场代码允许使用 AI 时，先复述需求、列边界和验收，再让工具生成小步修改；检查 diff，运行测试，读错误，故障注入。禁止使用时，同样先写最小例子。速度不是唯一指标，能控制范围和解释结果更重要。

## 12. 模拟面试的可执行方式

一场 45 分钟模拟可分为：5 分钟自我介绍与项目；15 分钟 FactoryCare 深挖；10 分钟故障日志；10 分钟小设计/代码；5 分钟反问与复盘。录音或录像前取得参与者同意；个人练习可本地保存。准备评分表而不是只凭感觉。

评分维度包括事实准确、结构、边界、证据、诊断、取舍、沟通和时间。每项用行为锚点：能否说出实际命令和测试数量；是否把未验证说成已上线；是否先找首个可信错误；是否说明替代方案成本；是否在两分钟内结束。总分不如具体改进项重要。

模拟面试必须有追问。说“用 JWT 做权限”，追问认证与授权区别、租户从何而来、Token 撤销、服务端检查；说“用了 RAG”，追问跨租户候选何时过滤、引用如何核验、模型停机怎样降级；说“可回滚”，追问数据库迁移和 RTO/RPO 证据。回答不出来就回到实验，而不是补背话术。

## 13. 复盘闭环

面试后尽快记录问题原文、自己的回答、证据缺口、正确方向和下一实验。把问题分为知识缺口、表达缺口、证据缺口、岗位不匹配和紧张/时间管理。只有知识缺口需要补教材；表达缺口靠限时复述；证据缺口要做实验；岗位不匹配可能无需改变路线。

每个改进行动要可完成。例如“复习数据库”太大；“用两个事务复现 READ COMMITTED 丢失更新风险，写测试并在两分钟解释乐观锁”可执行。完成后更新 claim ledger 和故事，再做一次不同追问的复测。不要在没有新证据时反复背同一答案。

被拒并不自动说明技术差，也可能是经验、薪资、岗位取消或竞争。区分已知反馈与推测。统计多个面试的重复信号再调整路线，不因一个面试官没问 Maven 就删除基础；基础是为了工作诊断，不是猜题。

## 14. 四种常见失败及修复

### 14.1 虚构三年经验

失败不是措辞问题，而是 claim 与事实不一致。首个可信位置是时间线、合同/社保/工资/项目记录及深入追问之间的矛盾。修复是恢复真实日期和性质，把竞争力转移到可验证项目深度、复现能力和学习速度。不能用“市场都这样”把未发生经历变成事实。

### 14.2 只展示成功截图

截图没有输入、版本、退出码和失败对照。修复为每个核心主张补预测、自动验证、至少一个故障注入、修复提交和原命令重跑。页面截图保留为辅助，不再作为唯一证据。

### 14.3 无法解释 AI 代码

首个证据是在修改条件、异常或并发后无法预测行为。修复不是隐藏 AI，而是缩小模块，逐行走读，画数据流，写 characterization test，再注入错误。能在无 AI 情况下解释并修复后，才升级为自己的能力主张。

### 14.4 把团队与工具贡献写成独立完成

修复时拆分“系统成果、本人贡献、协作/工具”。例如系统由两人和 AI 完成，本人负责 Java 工单模块、合同测试和发布夹具；Vue 模板来自开源项目并做了适配。清晰归属不会减少价值，反而让深挖范围准确。

## 15. 本章实验与验收

第一步完成 FactoryCare 双语案例。中文面向本地岗位，英文面向代码读者；两者共用架构身份、数字和未验证清单。为每个重点章节写一个 ADR 和一个证据链接，不要求把整本教材复制进案例。

第二步生成 claim ledger。随附实验夹具会拒绝没有证据、夸大验证等级、归属不清或虚假经验的主张。先运行绿色示例，再修改一条为“生产验证”却只链接本地测试，观察失败，修复为准确状态。

第三步采集目标岗位 JD 并做能力矩阵。样本必须记录日期和来源，去重后按能力聚类。输出“已有强证据、需要补证据、需要学习、硬差距、非目标”五类，不让单个冷门关键词打乱主线。

第四步准备三段真实故障故事和一场录制模拟面试。评分后只选三个最高价值改进，做实验并复测。录制本身不自动算通过；需要评分、追问、证据链接和第二次改善结果。

`examples/encyclopedia/ch.portfolio.interview/` 展示 claim-evidence 审计；`labs/` 提供合成简历/案例矩阵；`exercises/` 故意把所有 AI 生成和团队成果标为本人独立完成，公开测试稳定失败；`solutions-private/` 给出参考修复。资产只验证文档字段与链接逻辑，不替代真人面试、背景核验或真实求职结果。

## 16. 按技术栈建立问题树

问题树不是收集几百道八股答案，而是让每项能力回到项目。Java 分支从语言基础、集合、异常、泛型、并发与 JVM 进入 Spring 的依赖注入、Web、校验、事务、安全和测试，再落到工单状态迁移；SQL 分支从查询、聚合、连接、索引和事务进入租户过滤、并发更新与恢复；每个节点准备定义、FactoryCare 用途、一个失败和一项证据。只会定义而无法落到代码，标为“知识”；能实现但讲不清，标为“表达”；两者都能且有测试才是强证据。

前端分支区分浏览器与 Vue。HTML/CSS/JavaScript/TypeScript 的事件循环、请求、取消、状态和类型是基础；Vue 的响应式、组件、路由、Pinia、composable、测试和构建是框架。用工单筛选页解释为什么旧请求不能在新请求之后覆盖结果，`AbortController` 取消什么，`finally` 为什么要判断当前 controller。不要只背“防抖节流”，要能写出竞态测试。

移动端分支分别保留平台边界。uni-app 要讲小程序登录、权限、分包、真机和发布；Flutter 要讲 Widget/State、生命周期、异步、`mounted`、路由、状态管理、网络取消、权限与测试。准确表述 `mounted` 只能防止销毁后更新 UI，不能取消请求或阻止重复调用。若暂时不开发 App，可以把 Android/iOS 工具链标为后续验证，但不能把 Web 构建当真机经验。

AI 分支先讲 Python 数据处理和模型基本概念，再讲检索评估、RAG 引用、结构化输出、工具调用、LangChain/LangGraph 与 MCP 边界。面试重点不是背框架类名，而是说明评估集、租户过滤、提示注入、超时取消、人工批准和 Java 权威写入。模型效果数字必须有冻结数据集和参数；只用 mock 的部分明确说 mock。

运维分支从 Linux、网络、Docker、Compose、Nginx、CI、制品、secret、观测、备份和事故恢复串成发布路径。准备读一段真实日志，先判断 compile、testCompile、test failure、连接、TLS 还是上游阶段。能说出“首个可信证据”比泛泛说重启服务更重要。没有真实生产权限时，可以展示合成故障与本地验证，同时说明还缺 daemon、云 registry、证书或恢复演练。

每周从问题树选一条纵向路径做闭环，而不是横向背完所有概念。例如“创建工单”可以同时复习 Vue 表单、HTTP 校验、Spring Controller/Service、事务、SQL 约束、JUnit、Docker 发布和日志追踪。闭环结束生成一个两分钟讲解、一个失败实验和一个证据链接。这样知识会围绕真实调用链连接起来，也更适合 AI 辅助开发后的人工验收。

## 17. 演示与追问的控制

正式演示前准备离线兜底：固定 commit、合成数据、短视频和测试报告。现场网络、模型或 Docker 不可用时，先说明失败边界，再展示可复查证据；不要为救演示临时关闭 TLS、授权或测试。演示脚本每一步写预期与最长时间，超时就切换证据，避免把全部交流时间花在安装依赖。

面对追问时先确认层级。例如“为什么接口慢”可能涉及浏览器等待、Nginx、连接池、SQL、模型或设备网络。先画路径和已有证据，再提出下一条探针。不要因为最近学过索引就立刻回答“加索引”。若面试官改变前提，明确原设计是否仍成立，以及迁移成本、风险和回滚。

反问也用于核对岗位：日常 Java 与前端比例、代码评审、测试门禁、AI 工具政策、部署责任、值班与培养方式。问题用于判断工作是否匹配，不是表演术语。招聘信息和口头承诺存在差异时，以可确认的职责为准，并保存自己的判断。

## 18. 120 秒复述模板

可以这样回答：我的作品集不是技术清单，而是 claim ledger。每条主张说明对象、约束、本人贡献、AI/团队边界、验证环境和证据。FactoryCare 案例用 Java 作为业务权威，三客户端共享合同，Python/AI 可降级；我选择租户隔离、并发事务、RAG 引用和可回滚发布作为深挖问题，并保留故障修复记录。岗位准备通过真实 JD 样本做能力矩阵，优先补高频核心缺口。面试后把知识、表达和证据问题分开，完成小实验再复测。工作日期和项目性质按事实写，本地 fixture、模拟器和未连接的生产能力不会写成线上经验。

一个越界反例是把 2026 年两段短试用经历延长到 2023 年，再把 AI 生成的全栈代码描述为三年独立生产经验。即使技术名词正确，这条主张也没有真实时间线和责任证据，不能进入作品集。

## 19. 有意保留的未完成项

教材与随附资产不会替你生成真实工作证明、企业生产指标、同事评审、微信审核、应用商店发布或目标城市最新 JD 数据。它们也不宣称完成本章就一定获得岗位。实际求职前要重新采集当期岗位、选择公开范围、核对个人材料并由本人演练。

本章的通过条件是：每条技术主张能回到提交、测试、验收或明确的人工评审；能在限时内解释一个架构取舍和三段失败；AI、团队和本人贡献可区分；真实经历、项目性质和验证等级不矛盾。若证据不足，就缩小主张或补实验，而不是扩大措辞。

## 20. 官方资料与时效边界

资料链接复核日期：**2026-07-24**。

- [GitHub Docs：About READMEs](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes)：核对仓库 README 的用途、常见内容与相对链接行为；
- [GitHub Docs：About your profile](https://docs.github.com/en/account-and-profile/concepts/personal-profile)：核对 profile README、贡献记录和 pinned items 的公开展示边界；
- [GitHub Docs：Removing sensitive data from a repository](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)：核对作品集误提交敏感信息后的撤销、历史清理与协作影响。

这些资料只支持 GitHub 展示与安全操作，不支持任何个人能力、任职时间或求职成功率主张。岗位市场与招聘平台会变化；实际求职前必须按目标城市、日期和岗位重新采样，且不能把教材生成记录当成学习完成或工作经历。
