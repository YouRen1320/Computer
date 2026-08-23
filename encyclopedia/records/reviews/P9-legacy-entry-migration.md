# P9 旧课程入口迁移记录

## 目标与范围

把 2026.2 百科章节设为唯一权威教材，同时保留用户已经开始使用的 Week 00—48 进度编号、阶段门、实践、考核与证据。迁移只处理教材入口和重复讲义；不修改 `PROGRESS.md`，不推送远端，不发布公共站点，也不把任何章节晋升为 `verified`。

## 迁移前问题

- 根 README 把旧 48 周长页排在百科之前，学习教练也默认从重复周正文授课。
- `weeks/` 与百科章节同时维护概念清单，后续修订会产生两个真相来源。
- Week 00—08 的 `concepts.md` 再复制一份讲义；但 assessment、answers、interview 和分步 lab 具有独立用途，不能与重复正文一起粗暴删除。
- `PROGRESS.md` 已记录 Week 00 进行中，直接把周号改成新的能力模块会篡改既有证据语义。

## 已采用方案

采用长期维护优先的薄适配方案：

1. `book/`、`curriculum/catalog.yml` 与 `curriculum/gates.yml` 成为内容权威；
2. `curriculum/compatibility/legacy-weeks.yml` 显式保存 Week 00—48 到 canonical chapter ID 的映射；
3. `scripts/sync-legacy-learning-entry.rb` 确定性生成 49 个周入口和索引；
4. Week 00—08 的 `concepts.md` 只保留权威章节链接，labs、assessment、answers、interview 继续保留；
5. 学习教练先读真实进度与周适配页，再加载本次任务所需的 canonical chapter；
6. 根入口首先指向百科和零基础/加速路线，旧周计划明确标为兼容层。

## 影响与兼容

- 旧 `weeks/week-NN.md` 不再包含独立长讲义；依赖其中段落锚点的外部链接会失效。
- Week 编号、标题、`PROGRESS.md` 行、阶段门和 Week 00—08 考核入口保留。
- 有意保留的兼容折中是 labs、assessment、answers 与 interview；它们不是百科正文副本，删除会损害既有训练和考试流程。
- 旧页面可从 Git 标签 `pre-encyclopedia-2026-07-16` 读取，但旧正文不得与 2026.2 章节混合编辑。

## 迁移与回滚

迁移源是 `curriculum/compatibility/legacy-weeks.yml`。修改映射后运行：

```bash
ruby scripts/sync-legacy-learning-entry.rb --write
ruby scripts/sync-legacy-learning-entry.rb --check
ruby tests/curriculum/test_legacy_learning_entry.rb
```

回滚有两种完整方式：

1. 在本提交形成后使用 `git revert` 恢复入口、生成器、映射与教练路由；
2. 需要读取冻结长页时使用 `git show pre-encyclopedia-2026-07-16:weeks/week-NN.md`。不要只恢复单个旧页面，否则会重新产生双正文漂移。

## 已验证

- 映射精确包含 Week 00—48，共 49 项，所有 chapter ID 都存在；
- 49 个周页面、1 个周索引、9 个概念适配页可由同一输入重复生成，`--check` 无漂移；
- 本地 Markdown 链接解析测试通过；
- 冻结回滚标签可解析；
- 学习教练 Skill 通过 `quick_validate.py`，只读进度检查仍识别 Week 00 为进行中；
- `PROGRESS.md` 未被生成器读取为写入目标，也未被本迁移修改。

## 未验证与非目标

- 没有执行真实学习者点击和试读，不能声称迁移后的导航对所有零基础读者都无卡点；
- 没有验证第三方保存的旧段落锚点；它们属于已披露的破坏性影响；
- 没有更改真实小时、分数、完成日期或周状态；
- 没有创建公共仓库、发布站点或删除 Git 历史。
