# 路线规范输入

本目录只保存路线意图；章节列表和支撑闭包由 `scripts/generate-curriculum.rb` 从分卷章节、能力教师和硬前置图确定性生成。

- `accelerated-48.yml` 固定 `m01..m48` 的能力身份和 anchor。生成器按零基础拓扑序，以相邻模块 anchor 的边界分配每章唯一 primary owner，再把硬前置闭包加入 support；最后一个模块接收末尾未分配章节。每个模块必须显式声明 `required_mastery` 与精确匹配的 `evidence_requirements`；禁止从全局默认值隐式继承掌握度。
- `factorycare-project.yml` 只固定八个业务阶段的交付物、能力目标、primary anchors 和 `gate_id`；独立的 [`../factorycare-stage-gates.yml`](../factorycare-stage-gates.yml) 才是阶段门禁、93 个验收编号归属、负向场景、证据种类与工件路径的唯一来源。路线的 `artifact_policy` 明确规定项目工件归学习者所有、只在学习阶段产生且禁止课程预填；`evidence/factorycare/**` 在对应阶段开始前不存在是正确状态。生成器只增加 supporting closure，不得重复 primary ownership，也不得在路线计划中复制门禁合同。
- `gates.yml` 以 capability 教师章和其硬前置闭包生成 `required_chapter_ids`，不再按固定卷号硬编码章节。`G8` 显式覆盖全部 active 章节。

三个路线计划都必须使用语义稳定章节 ID 和 `capabilities.yml` 中的 capability ID。路线计划不能提供 legacy alias，也不能把 soft reading order 当作能力授权。FactoryCare 门禁注册表中的每个 `FC-*` 验收编号必须来自权威验收目录、恰好有一个 primary 阶段；缺失、重复、孤立门禁、非法证据种类或越界工件路径都会 fail-closed。

## 参考深度与路线必达是两条轴

- 章节 `level` 表示百科参考内容的深度；一章保留 L3 内容，不意味着每条路线都要求学习者在当前阶段达到 L3。
- 模块 `required_mastery` 是离开该模块时的最低可验证掌握度，由固定 evidence profile 约束。
- `m37..m39` 的 ML/数学/PyTorch 路线必达为 L1–L2；`m40..m44` 的 LLM/RAG/Agent 必达为 L2+。这不删除任何 L3 参考章节，只改变当前路线的退出证据。
- 掌握度缺失、非法、固定领域分配被改写，或 evidence 与 profile 不精确匹配时，编译器 fail-closed，不回退到更宽松的全局默认值。
