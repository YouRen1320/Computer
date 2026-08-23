# P3-R1B-L：课程生命周期状态门禁评审

## 评审状态

- 批次：P3-R1B-L（R1-B 的生命周期子批）
- 基线：`7f720da`（P3-R1A 出版计划与安全门）
- 评审日期：2026-07-16
- 当前结论：**PASS**
- 生命周期影响：edition 仍为 `authoring`，251 章为 `planned`、4 章为 `drafting`；本记录不是章节晋升或学习完成证据，不修改 `PROGRESS.md`

## 目标、范围与完成标准

本批关闭集成审计 M1，并为后续统一 Runner 提供不可自我放宽的生命周期边界：

1. `edition.status` 只接受 `architecture`、`authoring`、`release-candidate`、`published`；
2. chapter `status` 只接受 `planned`、`drafting`、`review`、`verified`；
3. 四个 phase 与四个 chapter status 的 16 种组合由编译器固定矩阵校验；
4. 缺失、空值、错误类型和未知 phase 在规范加载阶段 fail-closed，并定位到 `curriculum/edition.yml /status`；
5. 未知 phase 不级联产生 255 条章级 phase 错误，非法 chapter status 仍独立失败；
6. 被校验的 edition 输入不能声明或放宽自己的状态策略；
7. 当前 authoring 基线、课程派生输出、P2 五文件与 R1A sidecar 均重新校验；
8. 不改写已应用迁移的历史 receipt，不修改章节正文、状态证据或学习进度。

## 固定状态矩阵

| edition phase | 允许的 chapter status |
|---|---|
| `architecture` | `planned` |
| `authoring` | `planned`、`drafting`、`review`、`verified` |
| `release-candidate` | `review`、`verified` |
| `published` | `verified` |

规则位于 `Curriculum::EDITION_PHASE_STATUSES`，chapter 枚举位于 `Curriculum::CHAPTER_STATUSES`。未知 phase 查表得到空结果时只跳过章级组合诊断；顶层 `E_SCHEMA` 已保证整个 `SpecSet#load!` 失败，不存在允许全部状态的 fallback。

## 实现审查

| 完成标准 | 证据 | 结论 |
|---|---|---|
| phase 精确枚举 | `SpecSet#validate_top_level!` 对 `/status` 做 compiler-owned key 检查 | PASS |
| chapter 精确枚举 | `validate_chapters!` 使用冻结的 `CHAPTER_STATUSES` | PASS |
| 16 种组合 | 独立测试字面矩阵覆盖 4×4；测试先断言生产常量逐项相等，再验证每种行为 | PASS |
| 无自授权 | edition 顶层允许键删除 `allowed_statuses` 与 `architecture_allowed_statuses`；旧键成为 unknown fields | PASS |
| 无错误风暴 | 未知 phase 只有稳定 `/status` schema 诊断，不生成每章 `E_STATUS_PHASE` | PASS |
| 入口级负例 | 完整 validator 分别覆盖未知 `released` 和 `published + review`，无 `KeyError` 泄漏 | PASS |
| authoring 基线 | 真实规范仍为 251 planned / 4 drafting，完整 validator 通过 | PASS |
| 迁移历史 | application receipt 和 migration ledger 均无差异；applied 后 authoring fixture 显式切回 authoring 再测试 | PASS |
| 派生链 | curriculum、P2 五文件和 R1A sidecar 均按当前规范字节重建并通过 check | PASS |

## 派生输出与当前快照

- 规范摘要由 `b66d0db489d799880e76a4d8bc3d193e7ddec882388ac5f00345f28c107a90f4` 更新为 `1adff05e7cbcc13298fe7df0e5b4277a60078aaf5f4bd5d6cd192e20721ad333`；
- 课程仍为 255 章、16 卷、94 个 capability、48 个 accelerated module 和 8 个 FactoryCare stage；
- P2 输出仍是精确五文件，输入摘要更新为 `eb6808c7f06d7975bad0f7ac8b8bf2b2ba5684ee2347ccd2c2e9ce6933f31430`；文件名、schema 和现有摘要算法未迁移；
- 当前本地 R1A sidecar 计划 SHA-256 为 `432f290e5e80466e90c709677f43e3324411ebf24b63640c09a612cc947c0557`，仍为 4 章、72 项输入、0 个私有路径；
- `PROGRESS.md`、migration ledger 和 application receipt 无差异。

R1A 评审记录中的旧计划摘要是当时提交基线的历史事实，不应回写。当前 sidecar 摘要随 canonical catalog 和 P2 manifest 的合法字节变化而变化，并已由 `--check` 重新绑定。

## 测试与回归证据

机器检查：

| 命令 | 结果 |
|---|---|
| `ruby scripts/generate-curriculum.rb --check` | 255 chapters / 16 volumes / 94 capabilities / 48 modules；全部 `UNCHANGED` |
| `ruby scripts/validate-encyclopedia.rb` | VALID；251 planned / 4 drafting / 0 review / 0 verified |
| `ruby scripts/build-book.rb --check` | `BOOK BUILD CHECK OK`；files=5 |
| `ruby scripts/build-publication-plan.rb --profile publication/profiles/p3-gold.yml --check` | 4 chapters / 72 inputs；当前计划字节一致 |
| `git diff --check` | 通过 |

全仓 7 个测试文件均执行。安全文件先完整执行当时的 42 个方法，再对审查后新增且此前不存在的 1 个 CLI phase/status 方法定向执行；两组互斥且合计覆盖当前 43 个方法。合并统计为 **131 runs / 1002 assertions / 0 failures / 0 errors / 1 skip**：

- curriculum compiler：32 / 151；
- P2 build-book：6 / 64；
- encyclopedia security：42 / 270 + 1 / 5 = 43 / 275；
- source inventory：26 / 399；
- publication：24 / 113。

唯一 skip 为 `test_actual_pinned_repositories_complete_a_full_build_when_available`，原因是本机没有可选的 P1 固定审计仓；其余来源清单攻击测试均执行并通过。

## 独立审查与关闭项

独立审查确认生产逻辑没有 fail-open，并在提交前发现一项测试设计问题：最初的 16 组合测试曾使用生产矩阵本身作为预期 oracle，错误放宽生产常量时测试可能同步放宽。关闭动作：

1. 测试改用独立字面矩阵，并先断言它与生产常量完全相等；
2. 由独立字面矩阵驱动全部 16 种行为断言；
3. 新增完整 validator 的 `published + review` 负例，稳定得到 `E_STATUS_PHASE`；
4. curriculum 全量回归重新执行为 32 / 151，新增 CLI 负例单独执行为 1 / 5，均为零失败。

修复后独立复核未发现新的阻塞项。

## 兼容影响、迁移与回滚

### 有意的破坏性输入变更

`allowed_statuses` 与 `architecture_allowed_statuses` 不再受支持，也没有 deprecated 过渡期；携带旧键的 edition 输入现在会以 unknown fields 失败。这是刻意的无向后兼容变更，因为保留、忽略或继续读取这些键都会留下“实例可以修改验证策略”的错误接口。仓库根 edition 已同步删除旧键。

### 已保留的兼容折中

本批继续保留 P2 的五个文件名、schema 和递归输入/单摘要语义，只刷新由规范变化引起的字节与摘要；D8 所要求的显式公共输入与内容/安全双摘要迁移仍留给独立 P2 migration 批次。该兼容外壳降低当前 R1-B 回滚成本，但不表示 D8 风险已经关闭。

### 历史证据

既有 application receipt 是已应用迁移的一次性历史证明，本批不重写 receipt、迁移账本或其中的历史投影摘要。applied 后的 authoring 维护由现有生命周期支持，不能为了让当前摘要看起来一致而篡改历史证据。

### 回滚

完整回滚必须在同一 revert 中恢复：

1. 编译器中的旧 edition 允许键和旧状态读取逻辑；
2. `curriculum/edition.yml` 的两个旧字段；
3. 课程 catalog、routes、gates、concept graph 的旧派生摘要；
4. P2 五文件的旧输入/输出摘要；
5. 本批测试和评审记录。

不能只恢复 YAML，否则 compiler、生成物和 sidecar 会互相漂移。回滚后应重新运行 curriculum、P2 和 publication plan 构建/check；历史 receipt 仍不应修改。

## 明确非目标

- 不实现 verification manifest、统一 Runner 或 Runner evidence；
- 不生成 canonical Pandoc AST、HTML、EPUB、打印 HTML 或 PDF；
- 不迁移 P2 的公共输入模型和摘要语义；
- 不晋升四个黄金样章，不补写章节评审 evidence；
- 不修改 `PROGRESS.md`，不把课程建设当作用户学习完成；
- 不提供历史 phase 状态机或跨提交“只前进不后退”账本；
- 不提供 OS 级网络/文件系统沙箱。

## 下一子批

P3-R1B-V 将实现四章 verification manifest 与干净临时目录统一 Runner，固定解释器/argv、工具版本、退出码、测试数量、预期失败、输入漂移和未声明输出，并在自己的独立 review 中完成全仓回归。
