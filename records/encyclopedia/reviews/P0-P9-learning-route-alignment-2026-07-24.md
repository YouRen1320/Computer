# P0–P9 教材与学习路线对齐审计（2026-07-24）

## 结论

**就机器可验证的结构、归属和导航合同而言，当前学习路线没有脱离百科教材。**

`book/` 与 canonical curriculum spec 仍是教学内容权威；零基础路线、48 模块加速路线、
参考路线和 Week 00–48 兼容入口都只引用这 255 章。49 个周页面不是第二套教材，
Week 00–08 的 `concepts.md` 也只是生成适配页；其余 `labs.md`、`assessment.md`、
`answers.md`、`interview.md` 是训练与考核资产，不承担百科正文权威。

这个结论不是人工教学通过。此次审计没有进行零基础学习者试读、课堂观察、知识保持度
测量或逐章事实复核，因此不能据此声称“任何零基础学习者一定学会”、教材已经出版就绪，
或所有章节已经达到人工 `verified` 状态。

## 审计范围与权威边界

- canonical 内容：`curriculum/chapters/volume-00.yml` 至 `volume-15.yml`、
  `curriculum/catalog.yml` 与对应 `book/volume-*/chapters/ch.*.md`。
- canonical 路线输入：`curriculum/route-plans/`。
- 生成路线：`curriculum/routes/`。
- 旧周兼容输入：`curriculum/compatibility/legacy-weeks.yml`。
- 生成兼容入口：`weeks/week-00.md` 至 `week-48.md`，以及 Week 00–08 的
  `learning-kits/week-NN/concepts.md`。
- 真实学习状态：`PROGRESS.md`；生成器和本次审计均无权推断小时、分数或通过状态。

## 可复现结果

| 检查 | 结果 | 机器证据 |
| --- | --- | --- |
| 章节与 outcome | 通过 | 255 个唯一章节；每章固定 `explain/build/diagnose`，共 765 个 outcome |
| 49 周主归属 | 通过 | Week 00–48 恰好 49 周；765 个 canonical outcome 在 `required + practice_diagnosis` 中各出现一次 |
| 复习与支撑引用 | 通过 | `review`、`support` 没有未知 outcome；生成页显式标为 `refresh`、`support` |
| 48 模块主归属 | 通过 | `m01`–`m48` 连续；255 章在 `primary_chapter_ids` 中各出现一次；完整路线无孤立章节 |
| FactoryCare | 通过 | 8 个固定业务阶段；93 个 acceptance ID 具有唯一 primary 阶段归属；项目路线按设计是 205/255 章的 selective 路线 |
| 硬前置图 | 通过 | 393 条边、4 个根、255 个拓扑节点；未知边、自环、环均为 0 |
| capability teacher | 通过 | 94 个 capability；章节独立使用 capability 时，其唯一 teacher 在本章或硬前置闭包中；违规数 0 |
| 路线目标与参考深度 | 通过 | `chapter.level` 保持百科参考深度；48 模块另有显式 `required_mastery` 与固定 evidence profile |
| AI/ML 掌握度 | 通过 | `m37`–`m39 = L1-L2`；`m40`–`m44 = L2+`；两组仍引用 L3 百科章节，没有删除或降写正文 |
| 掌握度分布 | 通过 | L1-L2×3、L2×5、L2+×12、L3×28；缺字段、证据错配和 AI/ML 降级均有 fail-closed 测试 |
| 生成适配层 | 通过 | 49/49 周页面及 9/9 `concepts.md` 都带确定性生成标记并链接 canonical 章节 |
| 本地学习资产 | 通过 | 1,377 个 Markdown 文件进入检查；共 9,794 项检查通过，包括本地链接、围栏、学习 Skill 和进度检测 |
| 真实进度 | 未改动 | `git diff --quiet -- PROGRESS.md` 退出码为 0；只读检测仍为 Week 00、`进行中`、49 行且无警告 |

三条完整路线的章节覆盖均为 255/255：`zero-base`、`accelerated-48`、`reference`。
`factorycare-project` 的 50 个未覆盖章节是已声明的 selective 差集，不是孤立教材；这些章节仍被三条完整路线覆盖。

## 执行命令与观察结果

以下命令均在仓库根目录执行：

```bash
ruby scripts/generate-curriculum.rb --write
ruby curriculum/validate_catalog.rb
```

观察结果：最终生成完成；随后 `CURRICULUM CHECK OK`、`CATALOG VALID`，报告
255 章、16 卷、94 capability、48 模块、8 个 FactoryCare 阶段，所有受管生成输出均为
`UNCHANGED`。

```bash
ruby scripts/audit-curriculum-global.rb \
  --output /tmp/p6-global-audit-final.json --pretty
ruby -Itest tests/encyclopedia/test_global_curriculum_audit.rb
```

观察结果：`GLOBAL CURRICULUM AUDIT PASSED`；专项测试为
`4 runs, 31 assertions, 0 failures, 0 errors, 0 skips`。报告同时确认三条完整路线
无缺失/未知 ID，FactoryCare selective 路线无未知 ID，章节正文没有跨章完全重复的长段落组。

```bash
ruby -Itest tests/curriculum/test_validate_catalog.rb
ruby -Itest tests/curriculum/test_legacy_learning_entry.rb
```

观察结果：分别为 `42 runs, 237 assertions` 和 `10 runs, 2390 assertions`，均为
0 failures、0 errors、0 skips。前者覆盖 schema、硬前置、capability、FactoryCare gate、
参考深度/路线掌握度分离及负向变异；后者覆盖 49 周预算、765 个 primary outcome 唯一归属、
刷新顺序、未知/重复/缺失引用和生成适配页。

```bash
ruby scripts/sync-legacy-learning-entry.rb --check
ruby scripts/sync-chapter-prerequisites.rb --check
ruby scripts/validate-learning-assets.rb
```

观察结果：

- `weeks=49 chapters=255 primary_outcomes=765 concept-adapters=9`；
- `chapters=255 roots=4 edges=393 changed=0`；
- 学习资产验证 `VALIDATION_OK`，1,377 个 Markdown、9,794 项检查通过；
- 学习教练 Skill、FactoryCare 设计、岗位快照和只读进度检测同时通过。

```bash
git diff --quiet -- PROGRESS.md
```

观察结果：退出码 0。

## 审计中发现并修复的真实缺陷

`scripts/validate-learning-assets.rb` 仍读取已经从 legacy schema 删除的 `chapter_ids`，
导致总验证器在 Week 00 直接抛出 `KeyError`。它现已按四类 outcome slice 校验：

- `required`、`practice_diagnosis` → `primary`；
- `review` → `refresh`；
- `support` → `support`；
- 每个引用必须解析到 canonical `chapter#outcome`，并以正确角色出现在生成页。

修复后 9,794 项学习资产检查全部通过。Week 47 的 `required` 为空是合法设计，因为该周
12 小时主工作量全部属于 `practice_diagnosis`；验证器检查的是两者合并后的 primary 非空，
没有强迫每周机械复制一条解释任务。

## Fail-closed 集成边界

```bash
ruby scripts/validate-encyclopedia.rb --check-generated
```

生成漂移已经清零，但当前命令仍按设计失败于：

```text
E_INPUT_UNTRACKED curriculum/compatibility/README.md: P2 inputs must be Git tracked
```

原因是本轮明确要求“不提交”，而 P2 v3 输入合同禁止用未进入 Git index 的新增 canonical
输入生成权威发布物。此失败不表示路线引用错误，也不能通过放宽校验绕过；在最终提交把
新增 schema、兼容层源码、实验和本审计记录原子纳入版本控制后，必须重新执行该命令。

版本注册表 v2 另以以下只读命令复核：

```bash
ruby scripts/audit-version-sources.rb --checked-at 2026-07-24 --workers 8 \
  --output /tmp/p6-version-source-audit.json --pretty
ruby tests/encyclopedia/test_version_source_audit.rb
ruby tests/encyclopedia/test_encyclopedia_security.rb --name '/registry/'
```

结果为 71 个注册条目、93 个 `sources[]`，93/93 在审计日返回 HTTP 200/206；来源专项
`11 runs, 45 assertions`、注册表安全专项 `9 runs, 58 assertions`，均为 0 failures、
0 errors、0 skips。课程引用扫描覆盖 273 个 canonical/catalog/reference/book 文件且
`unknown_refs=0`。可达性只证明 URL 在指定日期可访问，不证明来源内容蕴含教材断言，
也不允许自动把 conceptual/provisional 条目晋升为 verified。

## 明确未验证与非目标

- 未进行人工逐章试读、课堂观察、用户访谈或学习保持度实验；不能声明人类可学性已通过。
- 未以文件数量、字数或生成成功推断掌握；真正通过仍需 outcome 要求的解释、构建、诊断和复测证据。
- 未核实每条外部来源对相邻教材句子的蕴含关系；全局审计只确认来源存在和结构合同。
- 未修改 `PROGRESS.md`、小时、分数、完成日期、求职数据或章节状态。
- 未提交、推送、发布站点、生成正式无障碍认证或把 FactoryCare selective 路线冒充完整教材路线。
- P7 及后续人工 review 不在本审计范围。

## 最终重放顺序

新增文件进入同一 Git 变更集后，按以下顺序重放：

```bash
ruby curriculum/validate_catalog.rb
ruby scripts/sync-legacy-learning-entry.rb --check
ruby scripts/sync-chapter-prerequisites.rb --check
ruby scripts/validate-learning-assets.rb
ruby scripts/audit-curriculum-global.rb --pretty
ruby scripts/validate-encyclopedia.rb --check-generated
```

只有这些机器合同再次通过，并补充真实学习者证据后，才能把“结构未脱离教程”进一步提升为
“这套路线对目标学习者确实可学、可用、可就业验证”。
