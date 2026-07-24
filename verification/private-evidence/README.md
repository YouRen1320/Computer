# Internal-only evidence

`last-run/evidence.json` 由 `scripts/run-private-verification.rb` 原子生成并被 Git 忽略。
这里的证据只用于本地私有答案核验，不得复制到公共 D5 evidence、站点、书籍或发布包。
每次成功证据记录执行 Runner 的 Ruby engine/version/patchlevel/platform/description、实际
单命令 timeout 与进程组终止宽限期，并对 13 项内部控制面逐文件记录相对路径、字节数和
SHA-256，再汇总集合摘要。控制面包含公开输入闭包的严格 schema 与 255 章完整清单。
每章证据只保存私有/公开输入计数和集合摘要，不保存闭包文件路径或输入内容；它也不披露
私有答案路径、私有文件名或命令原始输出，不把本机通过解释为跨平台通过。
