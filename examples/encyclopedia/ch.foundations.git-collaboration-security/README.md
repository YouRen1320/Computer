# 示例：一次性仓库中的 Git 状态与安全边界

本示例不要求你在当前教材仓库执行任何 Git 写操作。固定验证器会在系统临时目录新建一个没有 remote 的仓库，设置教学作者与固定时间，然后观察：

- 未跟踪→暂存→提交；
- add 后继续编辑产生 `MM`；
- 两条本地分支产生预期合并冲突并保留双方规则；
- 已跟踪 `local.env` 加入 `.gitignore` 后仍被报告；
- `git rm --cached` 让下一提交停止跟踪但保留工作树文件；
- 最新提交删除占位符后，旧提交仍可读取；
- 凭据响应只记录“模拟撤销先于清理”，从不创建真实秘密。

先预测每个 status、diff 与退出状态，再执行：

```text
/bin/zsh -f verify.sh
```

最后一行必须是 `git collaboration example: PASS`。验证器固定调用 `/usr/bin/git` 与 `/usr/bin/ruby`，禁用系统/全局 Git 配置和 hooks，清空继承环境，不联网、不读取个人凭据、不访问本目录之外的仓库。

输出中的 merge、ignore、old-history 三项是被精确断言的预期失败，不是验证器故障。占位符 `TRAINING_REVOKED_PLACEHOLDER` 明确无效，只存在一次性仓库；不要替换成任何真实或仿真高相似度 Token。
