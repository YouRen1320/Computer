# Week 00—48 兼容路线契约

`legacy-weeks.yml` 不再把一整章粗略塞进某一周，而是使用稳定的
`chapter-id#outcome-id` 引用，把同一章的解释、构建和诊断 outcome 分配到真正需要它的周次。

四个 section 的角色是固定契约：

- `required`：本周首次承担的解释 outcome，角色为 `primary`；
- `practice_diagnosis`：本周首次承担的构建或诊断 outcome，角色为 `primary`；
- `review`：已经在更早周次成为 primary 的间隔复习，角色为 `refresh`；
- `support`：完成本周任务时按需回看的已学前置，角色为 `support`。

所有 255 章的 765 个 catalog outcome 必须且只能有一个 primary owner；`review` 和
`support` 可以重复，但不能冒充新的掌握证据。Week 00 的预算为 8—12 小时，Week
01—48 为 15—18 小时。预算是本周所有 outcome 可被共同实验覆盖后的总投入，不等于
“条目数 × 固定小时”。

章节 `level` 表示百科正文的参考深度，周路线的 `required_mastery` 表示学习者本次必须
达到的能力深度，二者不可互相覆盖。尤其是机器学习路线必达 `L1-L2`，AI 应用路线必达
`L2+`；即使相关百科章节保留 `L3` 参考内容，也不要求在这条 48 周路线中一次掌握到 L3。

校验与生成命令：

```bash
ruby scripts/sync-legacy-learning-entry.rb --check
ruby scripts/sync-legacy-learning-entry.rb --write
```

Schema 位于 `schemas/legacy-week-slices.schema.json`。生成命令只更新 `weeks/` 和 Week
00—08 的 `learning-kits/**/concepts.md`，不会修改 `PROGRESS.md`。
