# P0–P9 教材与学习路线对齐审计（2026-07-24）

## 结论

**就当前机器可验证的目录、前置、归属、导航和执行合同而言，教材没有脱离学习路线。**

`book/`、`curriculum/catalog.yml` 与分卷 chapter spec 是唯一正文权威。零基础路线、
48 模块加速路线、参考路线、FactoryCare 项目路线，以及 Week 00–48 兼容入口，都是对
同一组 255 章和 765 个 `explain/build/diagnose` outcome 的不同导航视图；它们没有维护
第二套概念正文。Week 00–08 的 `learning-kits/week-NN/concepts.md` 也是生成适配页，
而 `labs.md`、`assessment.md`、`answers.md`、`interview.md` 只承担训练或考核职责。

机器侧已经覆盖全部 255 章：255 份 executable manifest 和与当前字节绑定的成功
Runner evidence 共执行 765 个 recipe。这个结果证明当前机器合同可执行，**不等于**
255 章已经通过独立真人教学审查，也不等于学习者已经掌握。DoD v2 当前仍为
`human-review-required`：独立真人批准为 0，四项全局发行门通过数为 0。

## 权威边界与四条路线

| 入口 | 当前合同 | 与教材的关系 |
| --- | --- | --- |
| 零基础路线 | `complete`，255/255 章 | 按前置关系提供完整顺序，不删减基础概念 |
| 48 模块加速路线 | `complete-with-support-repetition`，`m01`–`m48`，255/255 章 | 每章恰有一个 primary module；support 可重复，掌握度和证据要求由模块另行声明 |
| 参考路线 | `generated-complete`，255/255 章 | 按主题、能力和版本面检索同一 canonical 章节，不形成独立正文 |
| FactoryCare 项目路线 | `selective`，206/255 章 | 8 个业务阶段按能力展开 primary、support 与硬前置；未选的 49 章仍在三条完整路线中，不是孤立内容 |

所谓“没有脱节”具体指：路线中的章节 ID 都能解析到 catalog；需要的 capability teacher
出现在本章或硬前置闭包中；FactoryCare acceptance 具有唯一 primary 阶段；所有完整路线
都覆盖 255 章。它不表示四条路线必须具有相同顺序或相同重复次数。

48 周学习主程与兼容入口也需要区分：加速路线本身固定为 48 个模块；旧学习入口保留
Week 00 作为起步与环境前置，再提供 Week 01–48，共 49 个页面。765 个主 outcome 在
49 个兼容周的 `required + practice_diagnosis` 中各出现一次，`review` 与 `support` 只做
复习或补前置。因此从周计划进入、从零基础路线逐章进入、从参考索引查阅，或在
FactoryCare 项目阶段回到支撑章，最终都落到相同正文和相同 outcome。

## 当前可复现结果

| 检查 | 当前结果 | 结论边界 |
| --- | --- | --- |
| 目录与 outcome | 255 个唯一章节；每章 3 个 outcome，共 765 个 | 证明目录与学习结果结构完整 |
| 周兼容层 | Week 00–48 共 49 页；765 个主 outcome 唯一归属；9 个 `concepts.md` 适配页 | 证明旧入口仍能导航到 canonical 教材 |
| 48 模块 | `m01`–`m48` 连续；255 个 primary chapter 唯一归属 | support 重复是有意的教学补给，不是重复正文 |
| 四条路线 | 零基础、加速、参考均 255/255；项目路线 206/255 且声明为 selective | 项目差集仍由完整路线覆盖 |
| 硬前置图 | 394 条边、4 个根、255 个拓扑节点；未知边、自环、环均为 0 | 证明导航依赖可排序 |
| capability | 94 个 capability；teacher-before-use 违规为 0 | 证明能力使用不会越过声明的教学来源 |
| AI/ML 掌握度 | `m37`–`m39 = L1-L2`，`m40`–`m44 = L2+`；正文仍保留 L3 参考深度 | 路线降掌握目标不等于删除参考内容 |
| 学习资产 | 1,424 个 Markdown 文件、9,892 项检查通过 | 包含本地链接、围栏、适配层、Skill、设计与进度检测 |
| 机器执行合同 | 255/255 manifests、765 recipes，当前 Runner evidence 成功 | 只属于机器执行证据，不是独立真人批准 |
| P3 黄金样章 | 4 章；62 个 content inputs、93 个总 inputs；9 个实际输出 | 冻结的内部黄金样章候选，不是整书 |
| P8 内部整书 | 255 章、16 卷、4,205 个 companions、4,479 个 inputs；345 个计划路径、344 个 manifest 实体 | `internal-complete` 内部候选，禁止据此公开发行 |
| 真实学习进度 | Week 00、`进行中`、49 行、0 warning；`PROGRESS.md` 无差异 | 构建和审计没有冒充学习者进度 |

P3 的 10 个计划路径包含 output manifest 自身，manifest 为避免自引用只记录其余 9 个
实体。P8 同理：345 个计划路径包含 output manifest，最终 manifest 记录 344 个实体。
两者的数字不能混用，也不能用 P3 四章样章代表 P8 全书覆盖。

## 本轮重放与观察

以下只读或确定性命令在仓库根目录重放：

```bash
ruby scripts/audit-curriculum-global.rb --output /tmp/route-audit-current.json --pretty
ruby scripts/validate-learning-assets.rb
ruby scripts/run-verification.rb --check --require-complete
ruby scripts/check-publication-output.rb
ruby scripts/build-complete-publication-plan.rb --check
ruby scripts/build-complete-publication.rb --check
```

观察结果：全局课程审计通过并报告 394 条硬前置、四条路线无非法 ID；学习资产验证
通过；公共验证合同为 255 manifests / 765 recipes；P3 现有完整输出通过独立检查；P8
plan 与完整输出均为 canonical/valid。P3 的 plan-only `--check` 只适用于尚未渲染、仅含
`publication-plan.json` 的 sidecar 树；完整 P3 树应使用 `check-publication-output.rb`，
不能把两个检查门混为一个。

`PROGRESS.md` 的 staged 与 unstaged diff 均为空。本审计没有写入学习时长、成绩、完成
日期、求职活动或章节状态。

## 为什么机器覆盖仍不等于“零基础一定能学会”

机器已经能证明：章节存在，前置无环，路线引用正确，训练入口能执行，出版候选能按
当前合同构建，链接与无障碍机器审计能绑定到当前产物。机器不能替代以下真实观察：

1. 零基础学习者能否在不依赖答案的情况下找到入口、理解术语并完成首次构建；
2. 学习者能否修改需求、制造并定位故障、复述边界，并在延迟后通过新变体复测；
3. 项目路线在真实实现中是否需要调整节奏、补充支撑章或降低认知负担；
4. HTML、EPUB、PDF 在键盘、焦点、缩放、重排、VoiceOver 和目标设备上的真实体验；
5. 独立执行方能否按声明环境重建，以及最终路线、阅读顺序和版式是否获得人工批准。

因此当前状态允许开始学习和开展试学，但不允许把 `drafting: 255` 批量改成
`verified`，也不允许把机器绿灯写成“适合所有零基础读者”或“已经可以公开出版”。

## 建议的实际使用顺序

- 真正从零开始或需要系统补基础：先走 `zero-base`，以章节 outcome 和阶段 gate 判断
  是否前进；Week 00–48 页面只作为兼容排期入口。
- 已有开发经验、希望压缩节奏：走 `accelerated-48`，只有诊断和规定证据通过时才豁免
  教学步骤，不能仅凭“看过”跳章。
- 工作中查概念或排障：走 `reference`，查到章节后仍沿硬前置回补缺口。
- 做 FactoryCare：走 8 阶段 `factorycare-project`；selective 只表示项目所需子集，遇到
  能力缺口时回到零基础/加速路线，而不是把项目路线冒充整套教材。

这四种入口共享同一 catalog、章节正文、outcome 和证据边界，所以可以在学习、复习、
查阅和项目实践之间切换，而不会产生两套互相冲突的教程。

## 仍保持开放的人工与发行门

- 255 章独立真人 review attestation；
- 真实零基础学习者试学、卡点记录、修订与复测；
- 键盘、焦点、阅读顺序、VoiceOver/读屏和目标设备矩阵；
- 独立 clean-platform 构建复现；
- 外部来源对正文断言的蕴含判断；
- 全局路线、阅读顺序、版式与公开发行批准。

在这些证据真实产生前，不创建占位的 `verification/release-validation.yml`，不自动晋升
章节，不公开发布 HTML/EPUB/PDF，也不把机器 evidence 合并进学习者进度。
