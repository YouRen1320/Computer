# 路线规范输入

本目录只保存路线意图；章节列表和支撑闭包由 `scripts/generate-curriculum.rb` 从分卷章节、能力教师和硬前置图确定性生成。

- `accelerated-48.yml` 固定 `m01..m48` 的能力身份和 anchor。生成器按零基础拓扑序，以相邻模块 anchor 的边界分配每章唯一 primary owner，再把硬前置闭包加入 support；最后一个模块接收末尾未分配章节。
- `factorycare-project.yml` 固定八个业务阶段的交付物、能力目标、primary anchors、负向场景和 gate 合同。它的 `artifact_policy` 明确规定项目工件归学习者所有、只在学习阶段产生且禁止课程预填；`evidence/factorycare/**` 在对应阶段开始前不存在是正确状态。生成器只增加 supporting closure，不得重复 primary ownership。
- `gates.yml` 以 capability 教师章和其硬前置闭包生成 `required_chapter_ids`，不再按固定卷号硬编码章节。`G8` 显式覆盖全部 active 章节。

三个计划都必须使用语义稳定章节 ID 和 `capabilities.yml` 中的 capability ID。路线计划不能提供 legacy alias，也不能把 soft reading order 当作能力授权。
