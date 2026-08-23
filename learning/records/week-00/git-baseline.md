# Week 00 Git 基线

- 验证日期：2026-07-15
- 仓库根目录：`/Users/youren/Desktop/Study/Computer`
- 分支：`main`
- 远程：`origin/main`

## 提交证据

- 初始提交：`da5cacb init`
- 忽略规则清理：`bb043d9 chore: add repository ignore rules`
- 清理后状态：本地 `main` 与 `origin/main` 一致，工作区干净。

## 忽略与清理

- 根 `.gitignore` 忽略 macOS、IntelliJ IDEA、Java/Maven、Node/Vue/Nuxt、Python、Flutter、环境变量、常见密钥、日志和临时文件；
- 已跟踪的 `.DS_Store` 与 `.idea/` 通过 `git rm --cached` 从索引移除；
- 本地文件保留，IDEA 配置没有从磁盘删除；
- 清理提交未改写历史，可通过普通 `git revert bb043d9` 创建反向提交；是否真的回滚需先审查影响。

## 可复用规则

- `.gitignore` 只防止未跟踪文件在未来被加入，不能自动取消已经跟踪的文件；
- `git rm --cached` 从索引移除文件，但保留工作区文件；
- 密钥一旦推送，第一优先级是撤销/轮换；删除文件或改写 Git 历史不能让已经泄露的密钥自动失效；
- Git 能回滚仓库内容，不能回滚 Homebrew 安装、系统 JDK 或 IDE 全局设置。

## 有意不做

- 不改写初始提交历史；
- 不搬迁目录；
- 不清理本机已安装工具；
- 不新增其他远程仓库。
