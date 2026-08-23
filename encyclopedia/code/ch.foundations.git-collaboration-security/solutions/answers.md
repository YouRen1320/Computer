# 隔离解析：Git 协作与安全

完成公开实验并保留第一版预测后再阅读。本文件不能作为无 AI 证据。

## 实验证据

`git-evidence.txt` 的固定答案：

```text
untracked=?? work-order.txt
after_add=A  work-order.txt
after_second_edit=MM work-order.txt
merge_exit=1
merge_status=UU work-order.txt
resolved_rules=priority=urgent;safety=always-urgent;fallback=high
tracked_after_ignore= M local.env
after_rm_cached=D  local.env
worktree_copy=present
old_history_contains_placeholder=yes
credential_first_action=simulate-revoke-or-rotate
remote_count=0
```

手动填入公开证据，不要让答案脚本覆盖学习结果。前导空格是 porcelain 第二列状态的一部分。

## A—C

创建只改工作树；add 把当时内容写入 index；再次编辑只改工作树，因此 `MM` 表示 index 和工作树都有相对差异；commit 从 index 创建新快照并移动当前分支。普通 diff 看工作树对 index，cached diff 看 index 对 HEAD。混合 staged 变更应先保留工作树，按显式路径取消无关暂存；生成物与个人配置按政策忽略，真实 `local.env` 必须立即进入凭据响应而非只做 Git 整理。

## D—F

main 与 feature 从 B 分叉且双方有新提交，需要共同祖先参与三方合并。冲突最终应包含 `priority=urgent`、`safety=always-urgent` 与经需求确认的回退规则，并分别测试普通工单与安全告警。remote 是配置别名，`origin/main` 是上次 fetch 后的本地记录，本地 main 独立移动；pull 是获取再整合，不能当成无副作用刷新。

## G—I

ignore 不影响已跟踪路径，所以修改仍显示 ` M`。`rm --cached` 在 index 安排删除、保留工作树；下一提交停止跟踪，旧提交仍可读取。若值真实，第一动作是提供方撤销/轮换，随后评估仓库、日志、fork、缓存等范围。历史重写改变提交 ID 并影响所有协作者，必须在旧凭据失效、范围与授权明确、沟通和备份完成后由管理员协调，且不能收回已复制值。

## J—K

需求变更应让两个业务规则同时可测试；是否一个提交取决于它们是否构成同一完整合同。自动文本合并不能发现跨文件语义矛盾。AI 的全量 add、递归取消跟踪、强推和环境输出都扩大影响面；先 status/diff/路径分类与权限确认，再执行最小动作，remote 和日志必须脱敏。
