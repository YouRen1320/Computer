# P3-R1A：出版计划与安全边界批次评审

## 评审状态

- 批次：P3-R1A
- 基线：`690a54f`（P3-R0 决策冻结后的工作树）
- 评审日期：2026-07-16
- 当前结论：**PASS**
- 生命周期影响：四个黄金样章仍为 `drafting`；本记录不是章节晋升证据，也不修改 `PROGRESS.md`

## 目标、范围与完成标准

本批只建立可独立验证的出版控制面：

1. 以严格 schema 固定 P3 四章 `internal-preview` profile、工具观察、逐章公共工件和计划输出；
2. 用四份显式 manifest 完整列举公共 examples、labs、exercises，并拒绝额外、缺失、越界、隐藏、生成或符号链接输入；
3. 生成不嵌入正文、确定且可摘要的 `publication-plan.json`；
4. 将内容摘要与 publisher-contract 摘要分开，并保证一次计划组装只使用同一组冻结输入字节；
5. 只在被忽略的 `build/publication/p3-gold/` 做完整树替换，失败时恢复旧树或保留恢复材料；
6. 保持 P2 `site/generated` 五文件逐字节不变，保持课程状态和学习进度不变；
7. 用正反测试覆盖 `planned`、`drafting`、`review`、`verified`、P3 allowlist、工具篡改、私有 canary、路径、symlink、额外文件、确定性、原子替换和 rollback。

R1-A 明确不包含 verification manifest/统一 Runner、HTML/EPUB/PDF 实体、无障碍合规、P2 输入摘要迁移或章节状态晋升。原始 R1 审计项 M1（`edition.status` 枚举与 phase/status 合法组合）已明确归入 R1-B，未因拆批丢失。

## 实现审查

| 完成标准 | 证据 | 结论 |
|---|---|---|
| profile 与内部不可分发边界 | `publication/profiles/p3-gold.yml`；schema v1 固定 `internal-preview`、`internal`、`distribution_allowed: false`、`noindex,nofollow` | PASS |
| 四章显式公共工件 | 四份 `publication/manifests/public-artifacts/*.yml`；生产计划统计 47 个工件 | PASS |
| 精确目录封闭 | `PlanBuilder#validate_manifest_inventory!` 比较 managed roots 实际集合与 manifest 声明集合 | PASS |
| 固定工具策略 | 13 个工具 ID、命令、阶段和状态由 Ruby allowlist 固定；YAML 只能提供受限版本前缀与说明 | PASS |
| 状态门 | exact P3 gold allowlist；`drafting/review` 可进入内部预览，`planned/verified` 被拒绝；drafting allowlist 必须精确一致 | PASS |
| 输入一致性 | 首次读取冻结字节；各项 SHA、size 和三组 digest 使用同一快照；提交前逐项重读 | PASS_WITH_LIMIT |
| 计划确定性 | canonical JSON、无运行时间/用户名/主机名；连续生成与两次 `--check` 得到同一 SHA-256 | PASS |
| 私有与路径门 | 严格相对路径、所有组件拒绝 symlink、私有路径/已知 canary/当前仓库绝对路径扫描 | PASS_WITH_LIMIT |
| 完整树写入 | sibling stage、精确 staged file set、rename promote、目录 fsync、旧树恢复、恢复失败保留 stage/backup | PASS_WITH_LIMIT |
| P2 隔离 | sidecar 输出被 `.gitignore` 的 `build/` 规则命中；P2 builder 仍只认五文件 | PASS |

`PASS_WITH_LIMIT` 不降低本批结论：冻结快照不是仓库锁或 OS 文件系统快照，不能抵抗恶意同用户并发进程；目录双 rename 不是断电级 crash-atomic；不支持目录 `fsync` 的平台只能 best effort。这些能力从未被本批声明为已实现，并已在 `publication/README.md` 明示。

## 生产计划证据

生产入口：

```text
ruby scripts/build-publication-plan.rb --profile publication/profiles/p3-gold.yml
ruby scripts/build-publication-plan.rb --profile publication/profiles/p3-gold.yml --check
```

观察结果：

- 计划 SHA-256：`11d65dbab49041ad82c97c5aa6fec23429f700a24d94b3119bc69afc6f1e8ec5`；生成后连续两次 `--check` 未改变字节；
- 章节：4；公共工件：47；计划输出：10；
- 内容输入：51（4 章正文 + 47 工件）；publisher-contract 输入：21；无重复并集：72；
- `publication_mode=internal-preview`、`visibility=internal`、`distribution_allowed=false`；
- private path、private canary、absolute repository path、symlink input 四项计数均为 0；
- 通知同时投影到标题、正文开头和元数据，robots 为 `noindex,nofollow`。

## 测试与回归证据

R1-A 定向门：

| 命令 | 结果 |
|---|---|
| `ruby tests/publication/test_publication_plan.rb` | 11 runs / 47 assertions / 0 failures / 0 errors |
| `ruby tests/publication/test_publication_security.rb` | 7 runs / 32 assertions / 0 failures / 0 errors |
| `ruby tests/publication/test_atomic_tree_writer.rb` | 6 runs / 34 assertions / 0 failures / 0 errors |

P2/P3 基线：

| 命令 | 结果 |
|---|---|
| `ruby scripts/generate-curriculum.rb --check` | 255 chapters / 16 volumes / 94 capabilities / 48 modules；全部 `UNCHANGED` |
| `ruby scripts/validate-encyclopedia.rb` | VALID；251 planned / 4 drafting / 0 review / 0 verified |
| `ruby scripts/build-book.rb --check` | `BOOK BUILD CHECK OK`；files=5 |
| `git diff --exit-code -- PROGRESS.md site/generated` | 无差异 |

全仓 7 个真实测试文件按文件执行；其中单个百科安全文件因包含 41 个重型攻击夹具，按方法名首字母拆成互斥且穷尽的 `a-f`、`g-p`、`q-z` 三组，以避免长会话被界面续轮终止。合并统计为 **126 runs / 938 assertions / 0 failures / 0 errors / 1 skip**：

- curriculum：29 / 97；
- P2 build-book：6 / 64；
- encyclopedia security：15 / 88 + 8 / 75 + 18 / 102 = 41 / 265；
- source inventory：26 / 399；
- publication：24 / 113。

唯一 skip 是 `test_actual_pinned_repositories_complete_a_full_build_when_available`，明确原因为本地没有 P1 固定审计仓；该测试名本身声明 `when_available`，不属于 R1-A 输入，也没有被写成通过。其余来源清单攻击测试全部执行并通过。

## 审查中发现并关闭的问题

本批不是一次写完即通过。实现和多轮审查先后发现并关闭：

1. managed-root pattern 与单文件 pattern 职责混用；
2. 非 ASCII 计划内容比较的编码不一致；
3. 新树 durable sync 前过早删除 backup；
4. YAML 曾可表达任意工具命令/版本正则；现改为 Ruby exact allowlist + 前缀；
5. schema 的 repository/output path 约束不足；
6. schema v1 曾同时暗示 release/public 与内部 noindex 语义；现只允许 internal preview；
7. notice 和 repository metadata 未完整进入 canary/计划投影；
8. 同一构建多次读取可能形成混合摘要；现冻结首次字节并在提交前复读；
9. executable mode 曾被误当构建输入；现由未来 Runner 的显式解释器/argv 决定；
10. CLI 与异常诊断可能回显不可信参数或绝对路径；现对用户值和不安全路径脱敏；
11. 生命周期测试缺少 `review` 接受与 `verified` 拒绝；现补齐四状态覆盖。

这些修复均发生在 R1-A 原子提交前，不保留旧行为兼容入口。

## 兼容、限制与明确非目标

### 兼容折中

唯一有意的迁移期兼容是继续保留 P2 五文件及其旧摘要语义，同时让新 publisher 使用隔离 sidecar。这样降低 R1—R3 回滚成本，但暂时保留了 P2 递归公共输入与学习状态耦合摘要；它们必须在四章进入 `review` 前按 D8 单独迁移，不能把 R1-A 当成风险已全局关闭。

### 明确非目标

- 不生成 canonical Pandoc AST、HTML、EPUB、打印 HTML 或 PDF；
- 不生成 verification manifest 或执行章节命令；
- 不提供 OS 级网络/文件系统沙箱，也不声称 hostile-concurrency 或 crash-atomic；
- 不证明 WCAG、EPUB Accessibility、PDF/UA 或可复现构建；
- 不把 `publication-output-manifest.schema.json` 的前置骨架冒充 R2 实例或完整语义验证；
- 不迁移 P2、私有 Git 历史、远端权限或公开发行仓；
- 不修改 catalog/front matter 状态、evidence 或用户学习进度。

## 回滚

R1-A 将以单一提交冻结。回滚时优先 `git revert <R1-A-commit>`；被忽略的 `build/publication/p3-gold/` 可单独删除。该回滚不会也不需要回滚 P2 migration，因为本批没有实施它；若以后 R1-B/R2 已建立在本契约之上，应按提交依赖逆序回滚，不能只删 schema 留下 Runner 或产物。

## 下一批

R1-B 必须完成：

1. verification manifest 严格 schema 和四章完整声明；
2. 干净临时目录统一 Runner，固定解释器/argv、工具版本、退出码、测试数量、预期失败与未声明输出；
3. Runner 复核 plan 中的输入摘要，拒绝计划生成后的漂移；
4. `edition.status` 枚举与 phase/status 合法组合负向门；
5. R1-B 自身独立 review 和全仓回归。
