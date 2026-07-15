# P0 基线冻结记录

## 目标与范围

P0 冻结百科重建前的可回滚基线，记录验证结果，并把后续大规模目录与内容迁移隔离在独立分支。P0 不编写课程正文，也不改变学习进度。

## 冻结点

| 项目 | 值 |
|---|---|
| 基线提交 | `6aa8e2358f25f126eeb29ba5920f971f7e28a549` |
| 基线说明 | `docs: expand curriculum to 48-week foundations` |
| 回滚标签 | `pre-encyclopedia-2026-07-16` |
| 实施分支 | `codex/encyclopedia-rebuild` |
| 冻结日期 | 2026-07-16，Asia/Shanghai |
| 冻结时工作区 | 干净；新增百科文件前无未提交改动 |

标签是带注释标签，解析后的目标提交必须是上表的基线提交。检查命令：

```bash
git rev-list -n 1 pre-encyclopedia-2026-07-16
git merge-base --is-ancestor pre-encyclopedia-2026-07-16 HEAD
```

## 基线验证

冻结后、实施前执行：

```bash
ruby scripts/validate-learning-assets.rb
```

已验证结果：

- 扫描 152 个 Markdown 文件，共 1,379 项检查；
- FactoryCare 设计校验通过 1,360 项检查；
- 6 个 JSON Schema 和 2 个 OpenAPI 文件通过；
- 岗位快照 84 行通过；
- 学习教练 Skill 校验通过；
- 当前进度识别为 Week 00，无警告和错误；
- 最终标志为 `VALIDATION_OK`。

以上是冻结时的已验证结果，不代表新百科文件已经通过后续验证。

## 迁移与回滚

理想目标态是以新百科目录、规范化元数据和可运行示例取代重复、版本混杂的旧静态讲义。迁移期间采用并行入口，P9 才切换默认入口。

回滚前先保护当前工作，不能在含有未提交或未跟踪成果的工作树中直接切换分支：

1. 停止在 `codex/encyclopedia-rebuild` 上继续写入并执行 `git status --porcelain`；
2. 将完整原子批次提交到实施分支；若批次尚不能提交，则用 `git diff --binary HEAD > /workspace-outside/recovery.patch` 把已暂存与未暂存的已跟踪修改导出到当前工作树之外，并单独归档未跟踪文件清单与内容；
3. 推荐在另一目录执行 `git worktree add <recovery-path> -b <recovery-branch> pre-encyclopedia-2026-07-16`，从冻结标签建立干净恢复工作树；
4. 不使用 `git reset --hard` 或清理命令覆盖用户工作；需要保留的成果通过选择性提交或经过检查的补丁迁移；
5. 在恢复工作树重新执行基线验证命令。

已提交到实施分支的证据不会因建立恢复 worktree 而消失。未提交内容只有在完成第 2 步的保护后才能视为已保留；P0 治理文件自身必须先形成可审计提交，才能宣告本阶段完成。

## 明确不做

- 不修改 `PROGRESS.md` 的完成状态、时长或分数；
- 不把课程生成视为用户已掌握知识；
- 不在 P0 删除旧课程、旧路由或现有学习工具；
- 不直接发布到远程仓库或公共网站；
- 不把未执行的代码、测试或文档构建标记为通过。
