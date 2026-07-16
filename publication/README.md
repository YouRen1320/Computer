# P3 sidecar 出版管线

本目录实现 P3-R0 已确认的隔离出版控制面。R1—R3 只在被 Git 忽略的
`build/publication/<profile-id>/` 生成内部工件，不修改 `site/generated` 的
P2 五文件契约，也不自动修改章节状态或 `PROGRESS.md`。

## 权威边界

- `profiles/` 只用显式章节 ID 选择内容，不接受 glob、卷查询或自由输出路径；
- schema v1 只支持当前 P3 `internal-preview`；`release/public` 必须在未来以新 schema 版本完整建模，不能复用内部 `noindex` 通知和内部输出枚举；
- `manifests/public-artifacts/` 逐文件声明四个黄金样章的公开工件；
- `toolchain.yml` 区分当前观察值与仍待 R3 固定的工具，不把本机观察冒充长期或跨平台支持；
- 工具 ID、命令、启用阶段和观察/延期状态由 Ruby allowlist 固定；YAML 只能记录安全的版本前缀和说明，不能注入任意命令或正则；
- `schemas/publication-*.schema.json` 与 `schemas/public-artifact-manifest.schema.json`
  是独立 schema v1；它们不借用 P2 runtime schema v2；
- 输出目录由合法 `profile_id` 推导，配置不能把 sidecar 指向 `site/generated`；
- 章节 Markdown 由 canonical catalog 选择，不在公共工件清单中重复登记。

R1-A 的入口是：

```bash
ruby scripts/build-publication-plan.rb --profile publication/profiles/p3-gold.yml
ruby scripts/build-publication-plan.rb --profile publication/profiles/p3-gold.yml --check
```

生成的 `publication-plan.json` 只含规范相对路径、摘要、字节数、状态投影和
计划输出，不嵌入正文，不包含运行时生成时间、主机时间、用户名、主机名或绝对
工作目录。`source_date_epoch` 是 profile 固定的可复现构建输入，不是本次运行时间。

三个摘要的集合语义固定如下：

- `content_input_digest`：4 个章节正文 + 47 个显式公共工件，共 51 项；
- `publisher_input_digest`：schema、builder/profile/toolchain/catalog、P2 基线 manifest、4 份逐章 manifest 和 4 个显式 `.gitignore`，共 21 项；
- `build_input_digest`：上述两组的无重复并集，共 72 项。

三者都使用 `sha256(path + NUL + bytes + NUL)` 的有序集合算法；都不是 D8 将来
要求的 repository safety/audit digest，也不证明仓库其他文件安全。

计划生成时每个输入的首次读取会冻结为内存字节快照；逐项 SHA、字节数和三个集合
摘要都只基于这份快照，提交前再逐项重读，发现变化即失败。该机制防止一次构建形成
自相矛盾的混合摘要，但不是仓库锁、文件系统快照或针对恶意同用户并发进程的 OS 级
隔离。Unix executable 位不属于本摘要：R1-B Runner 必须用 manifest 中的显式 argv
和固定解释器运行脚本，不能信任文件模式决定执行方式。

R1-A 的回归测试可以独立运行：

```bash
ruby tests/publication/test_publication_plan.rb
ruby tests/publication/test_publication_security.rb
ruby tests/publication/test_atomic_tree_writer.rb
```

## 当前能证明与不能证明的事

R1-A 可以证明 profile/status allowlist、文件所有权、普通文件与 symlink 边界、
显式文件集合、确定性 plan、可捕获进程内失败时的完整树回滚和 P2 byte-exact
隔离。这里的完整树替换不是断电级 crash-atomic：两次目录 rename 之间进程若被
强制终止，可能需要根据保留的 stage/backup 人工恢复；目录 `fsync` 在不支持的
平台上也是 best effort。它不能证明：

- HTML、EPUB、PDF 已经生成；
- 命令在 OS 级文件系统或网络沙箱中运行；
- WCAG、EPUB Accessibility 或 PDF/UA 合规；
- P2 的递归公共输入风险已经迁移；
- 四个 `drafting` 章节已经达到 `review`。

`publication-output-manifest.schema.json` 是 R2 输出契约的前置定义；R1-A 尚未生成
该 manifest。它明确记录 `network_policy: forbidden` 只是策略，同时要求
`network_isolation: not-os-enforced`，避免把无网络调用冒充 OS 级断网沙箱。

这些边界分别留给 R1-B、R2、R3、独立 P2 migration 与 R4。

此外，集成审计 M1 记录的 `edition.status` 枚举与 phase/status 合法组合门纳入
R1-B；R1-A 只校验当前 sidecar profile 的章节状态投影，不能替代 canonical
curriculum lifecycle 的拼写错误与非法组合门。
