# 实验：状态转换、冲突、ignore 与凭据处置

本实验的验证器会自己在全新系统临时目录创建仓库。你只编辑本目录的 `worksheet.md` 和 `git-evidence.txt`，不得在当前教材仓库执行 add、commit、branch、merge、rm、remote 或历史命令。

## 操作顺序

1. 在 `worksheet.md` 预测未跟踪、暂存、add 后再编辑、冲突、ignore 与取消跟踪的精确状态；
2. 阅读 `verify.rb`，确认 Git 路径、临时目录、无 remote、无 hooks、固定身份和无效占位符边界；
3. 首次执行 `/bin/zsh -f verify.sh`，观察证据占位符导致的非零预期失败；
4. 根据自己的模型填写 `git-evidence.txt`，不要靠追加 `|| true` 掩盖失败；
5. 复跑到最后一行 `git collaboration lab: PASS`；
6. 用 120 秒解释每个字段对应工作树、index、HEAD、分支、ignore 或安全响应中的哪一层。

固定场景中的 merge 非零、已跟踪文件仍出现、旧提交仍含教学占位符，都是被验证器接受的预期失败。占位符不能授权任何服务；禁止替换成真实 Token、密码、SSH 私钥或真实 remote URL。

自动通过证明固定状态与填写结果一致，不证明你获得了远端发布授权，也不证明真实凭据事故已经处置。真实事故必须有提供方撤销/轮换和组织响应证据。
