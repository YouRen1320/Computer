# P9 AI 补救记录：卷 00—05（2026-07-24）

> **actor: AI（Codex）**
> **remediation_kind: AI-assisted implementation and machine verification, not human review**
> **attestation_effect: none**
> 本记录只说明对 AI 预审发现所做的代码、教材和公开练习合同修复。它不是独立真人复核、零基础学习者试读、事实来源签署、无障碍人工验收或 release validation；不能创建、替代或关闭任何真人 attestation，也不能据此把章节晋升为 `review/verified`。

## 1. 范围与完成标准

依据 [`P9-AI-pre-review-volumes-00-05-2026-07-24.md`](./P9-AI-pre-review-volumes-00-05-2026-07-24.md) 修复卷 00—05 中可由教材或代码消除的 finding。公开 exercise 的统一完成标准是：

- 原始 starter：同一个 `./verify.sh` 精确识别登记的预期红，退出 `41` 并输出 `EXPECTED_RED`；
- 已知正确实现：同一个 `./verify.sh` 退出 `0` 并输出 `EXERCISE_GREEN`；
- 部分修复、测试数量/故障形状漂移、编译错误或工具链异常：退出 `43` 并输出 `UNKNOWN_STATE`；
- exercise 必须保留可编辑 starter；验证器不得用固定 heredoc 或永久红逻辑代替学习者实现；
- 私有解答只允许在操作系统临时副本中作为 green oracle 使用，不复制到公开目录。

明确不在本轮完成：真人批准、attestation、release validation、`PROGRESS.md`、卷 06—15、endpoint/DoD schema、manifest 和生成器脚本变更。

## 2. Finding 补救结果

| Finding | AI 补救状态 | 修复结果 | 仍需外部证据 |
| --- | --- | --- | --- |
| F-00-01 | 已完成可执行合同修复 | 卷 00 的 15 个 exercise 均新增可编辑 `submission.md` 模板；README 说明五段证据合同、`0/41/43`；验证器区分完整占位 starter、完整填写和部分填写，并继续明确 green 只证明结构完整、语义必须人工批改。 | 15 份学习证据的教师/真人语义批改。 |
| F-02-01 | 已完成 | `business-value-types`、`exceptions-failure-contracts`、`object-contracts` 均改为同一入口三态；完成态仍要求独立故障 fixture 保持有效。修正 `business-value-types` 的十进制文本及时区 starter，使任务本身可解。 | 真人可学性复核。 |
| F-03-01 | 已完成权威字段一致性修复 | 注解章责任改为“只用窄反射探针验证运行时可见性，不教授通用成员扫描、类加载或代理”；chapter front matter 与 `curriculum/chapters/volume-03.yml` 已同步。 | 真人内容复核；生成派生物应由主流程统一写入，本轮未写。 |
| F-03-02 | 已完成 | 五个 Java 工程 exercise 均支持 `41/0/43`；独立负例在 green 状态仍必须成立。`executors-virtual-threads` 增加真正可编辑的 cause、timeout、cancel、virtual-thread 与 executor lifecycle starter 支架。 | 真人可学性复核。 |
| F-03-03 | 部分完成 | `logging-jvm-diagnostics` 的同一 `./verify.sh` 已成为精确完成命令，支持 starter、solved 与未知态；README 不再要求读者猜 `javac/java` 参数。 | **未执行真实 `jcmd` 线程转储或 JFR**；该 build outcome 仍为真实待办。 |
| F-04-01 | 已完成 | 卷 04 的 17 个 exercise 全部把公开 Ruby oracle 接入同一 `./verify.sh`；正确答案不再被当作 starter-unexpected。 | PostgreSQL 18 实机路径见 F-04-03。 |
| F-04-02 | 已完成 | `postgresql-psql`、`relational-model` 及同卷 README 统一说明 `0=solved`、`41=精确 starter`、`43=未知/基础设施`，删除“expected-red 退出 0”的过时说明。 | 无代码待办。 |
| F-04-03 | 未关闭（外部环境） | 离线 oracle 的边界说明保留，未把其包装成 PostgreSQL 实机证据。 | **未执行真实 PostgreSQL 18、psql、pgJDBC、MyBatis、迁移、锁或计划矩阵**。 |
| F-05-01 | 已完成 | 卷 05 全部 18 个 exercise 统一为 Maven 离线三态入口：精确全绿摘要为 `0`，唯一登记 starter failure 为 `41`，其他状态为 `43`。 | 真实 PostgreSQL/Testcontainers 路径见 F-05-03。 |
| F-05-02 | 已完成 | canonical 属性保持 `factorycare.api-base-url`，canonical 环境变量保持 `FACTORYCARE_APIBASEURL`；当前 Spring Boot relaxed-binding alias `FACTORYCARE_API_BASE_URL` 被明确标为 alias，不再冒充 canonical；新增 canonical、alias、未知键和优先级四项独立测试。 | Spring Boot 后续版本升级时复核 relaxed binding。 |
| F-05-03 | 未关闭（外部环境） | 离线 Maven green 与真实数据库 green 在 README 中明确分层；Docker 不可用时继续显式 `UNVERIFIED`，没有静默降级。 | **未执行真实 Docker + PostgreSQL/Testcontainers 路径**，也未关闭 PostgreSQL 专属锁、隔离和方言证据。 |

### 补充一致性修复

全局扫描还发现 `ch.java-engineering.testing-test-doubles` 虽能通过直接运行 Maven 获得 green，但公开 `./verify.sh` 仍把 solved 当作异常，README 要求完成后绕过公开入口。现已同步改为同一入口：精确 starter 为 `41`，fake 与 spy 完成且 5 次测试全绿为 `0`，只完成其中一处或其他异常为 `43`。这不改变预审对正文技术内容的判断，只消除了入口体验的不一致。

## 3. 三态实现边界

- 卷 00 使用五个精确占位符区分未开始、完整填写和部分填写；机器结果只声明结构完成，未声称内容正确。
- 卷 04 对可编辑 `answer.sql`、`answer.json` 或会话计划计算精确 starter 指纹；公开 oracle 成功才允许 green。
- OOP、Java 工程和 Spring exercise 对可编辑源码树计算精确 starter 指纹。只有“指纹一致 + 登记故障形状一致”才返回 `41`；同样故障下的任意修改不会被误报为 starter，而会返回 `43`。
- green 分支不依赖 starter 指纹，因此学习者的正确实现可由同一入口自然到达；独立 fixture、测试总数和精确成功摘要仍受检查。
- 指纹只登记公开 starter 字节，不包含或推导私有答案。

## 4. 定向机器验证

以下结果均在 2026-07-24 当前工作树执行；正确实现只覆盖到操作系统临时副本，未写入公开 exercise。

| 验证组 | starter | 已知正确实现 | 未知/部分状态 |
| --- | ---: | ---: | ---: |
| 卷 00 证据模板（15） | 15/15 返回 41 | 15/15 返回 0 | 15/15 部分填写返回 43 |
| OOP 阻断项（3） | 3/3 返回 41 | 3/3 返回 0 | 3/3 返回 43 |
| Java 工程原五项（5） | 5/5 返回 41 | 5/5 返回 0 | 5/5 返回 43 |
| JVM 诊断（1） | 1/1 返回 41 | 1/1 返回 0 | 1/1 返回 43 |
| test doubles 补充项（1） | 1/1 返回 41 | 1/1 返回 0 | 只完成 fake 时返回 43 |
| 卷 04 数据（17） | 17/17 返回 41 | 17/17 返回 0 | 17/17 损坏输入返回 43 |
| 卷 05 Spring（18） | 18/18 返回 41 | 18/18 返回 0 | 18/18 非 starter 修改返回 43 |

补充结果：

- 受影响的 61 个章节，其 example/lab 共 122 个入口全部退出 `0`；`ch.spring.testing-testcontainers` lab 仍保留 1 个有意的 `UNVERIFIED` 真实环境标记，不能把该静态/离线路径解释为 Docker/PostgreSQL 已运行。
- 私有 executor、configuration-profiles 和 testing-test-doubles verifier 均退出 `0`；它们只用于确认 oracle 契约，没有把解答复制到公开目录。
- `ruby scripts/generate-curriculum.rb --plan` 退出 `0`，注解章 canonical responsibility 与 front matter 不再冲突；本轮没有执行 `--write`，也没有修改全局生成派生物。
- 所有本轮涉及的 shell verifier 已通过 `bash -n`。

代表性命令：

```bash
(cd exercises/encyclopedia/<chapter-id> && ./verify.sh)
ruby scripts/generate-curriculum.rb --plan
bash -n exercises/encyclopedia/<chapter-id>/verify.sh
git diff --check
```

## 5. 未关闭项与非目标

1. F-03-03 的真实线程转储/JFR、F-04-03 的 PostgreSQL 18 矩阵、F-05-03 的 Docker/Testcontainers/PostgreSQL 路径仍未运行；它们需要真实环境和独立证据，不能由离线代码修改安全代替。
2. 卷 00 submission 的文字质量、所有章节事实准确性、零基础可学性、来源蕴含、无障碍和版式仍需不同 actor 的真人复核。
3. 本轮没有创建真人 attestation、没有 release validation、没有修改 `PROGRESS.md`，也没有把 AI 补救记录当作发布批准。
4. 没有为了向后兼容保留旧的 red-only 或“solved 请绕过 verifier”入口；公开练习统一采用长期可维护的单入口三态合同。
5. 没有修改卷 06—15、manifest、endpoint/DoD schema 或生成器脚本；课程派生物留给主流程按统一生成步骤更新。
