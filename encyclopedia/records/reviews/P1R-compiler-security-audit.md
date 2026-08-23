# P1R curriculum compiler / generator 安全审查

审查日期：2026-07-16
审查对象：`scripts/lib/curriculum_compiler.rb`、严格 YAML/JSON 辅助实现、迁移 schema 与账本、生成器 CLI、当前 curriculum 测试
审查方式：静态审查、只读对抗探针、确定性双编译、现有测试及全仓 validator；未执行 `--write`

## 1. 结论

当前编译器已经具备较强的规范输入闭环、确定性生成、冻结迁移清单、输出所有权保护和普通异常回滚能力。审查期间发现的以下高风险问题已经在当前实现中修复并复验：

- ready 迁移的旧 generated output 在 commit 二次校验中被错误拒绝；
- Markdown/YAML generated output 所有权标记过宽，可能误覆盖人工内容；
- FactoryCare artifact path 可携带 `../`；
- route plan 的未知字段和错误 route identity 被静默忽略；
- 迁移 rebuild evidence 只检查摘要形状，不核对文件字节；
- contract path 对控制字符处理不完整；
- 删除后异常回滚不保留原文件 mode；
- drafting 时把“尚未审核”误报成“与冻结 manifest 不一致”。

但是，本审查快照仍不批准执行迁移写入，原因如下：

1. migration 已标记为 `ready`，`--plan` 会执行 255 个创建、170 个删除和 24 个更新，但测试套件当前为红色；
2. 当前事务只能宣称“单文件原子、普通 Ruby 异常下尽力回滚”，不能宣称整套目录具有 crash-atomic 性；
3. 若干设计文件承诺的语义治理断言尚未实现或尚无测试；
4. P2 全仓 validator / build / site 迁移仍未闭环。

因此，当前状态适合继续做受控迁移演练和补测试，不适合把 `--write` 视为已通过发布门禁。

## 2. 严重度定义

- **S0 / Blocker**：当前即可导致错误迁移、数据损失或发布门禁失效；完成前不得执行 `--write`。
- **S1 / High**：关键安全或治理合同未实现，或已有声明明显强于实际保证。
- **S2 / Medium**：不会立即破坏当前 255 章输入，但会造成未来 fail-open、陈旧状态或审计误判。
- **S3 / Low**：诊断、测试可维护性或文档精度问题。

## 3. 当前未解决问题

### S0-1：migration 已 ready，但测试套件为红色

当前只读计划结果：

```text
RC=0
CREATE 255
DELETE 170
UPDATE 24
```

这意味着 `--write` 已越过 migration readiness 和 conflict 门禁，会进行大规模破坏性目录迁移。

但当前测试结果为：

```text
13 runs, 43 assertions, 1 failures, 0 errors, 0 skips
```

失败项：

```text
CurriculumCompilerTest#test_missing_volume_specs_fail_closed_without_legacy_catalog_fallback
Expected: ["E_VOLUME_SPEC_SET"]
Actual:   ["E_INPUT_TYPE"]
```

初步原因是测试 fixture 的 canonical input 复制清单没有同步新增的 migration audit / rebuild evidence 输入，导致测试在目标断言之前失败。

复现：

```bash
ruby -Itests tests/curriculum/test_validate_catalog.rb
ruby scripts/generate-curriculum.rb --plan
```

修复建议：

1. 先修复 fixture，使测试确实到达“缺失 volume specs”断言；
2. 加入 ready migration 的完整临时工作区测试；
3. 在测试全绿之前，禁止执行 `ruby scripts/generate-curriculum.rb --write`；
4. CI 将“migration ready 且测试失败”设为硬阻断。

### S1-1：不可宣称整套输出 crash-atomic

当前实现具备：

- 每个 create/update 使用同目录临时文件、`fsync` 和 `rename`；
- delete 后同步父目录；
- commit 前校验 target/input 快照；
- 进程内异常时按相反顺序恢复文件字节和 mode；
- 通过进程间 `flock` 避免两个合作生成器同时写入。

这些保证足以描述为：

> 单文件原子；在同一 Ruby 进程捕获到普通异常时，执行反向快照回滚。

它们不足以描述为：

> 255 个创建、170 个删除、24 个更新构成一个 crash-atomic 的整套事务。

下列事件仍可能留下半套目录：

- `SIGKILL`；
- 机器断电或内核崩溃；
- 进程在若干 rename/delete 完成后被强制终止；
- 回滚期间再次遇到 I/O 错误；
- 非合作进程绕过生成器锁修改目录。

修复选项：

1. **推荐的完整方案**：生成版本化完整目录树，经全量验证后用单一指针/目录交换发布；
2. **可恢复方案**：持久化 write-ahead journal，记录事务 ID、全部旧摘要、目标摘要和 applied 序号，启动时自动恢复或完成；
3. **明确降级**：保留当前实现，但把设计和交付说明改为“per-file atomic + exception rollback”，禁止使用“整套原子替换”“失败绝不留下半套目录”等表述。

无论选择哪种方案，都应加入独立子进程被强杀后的恢复测试。普通 `commit_hook` 抛异常测试不能证明 crash-atomic。

### S1-2：治理设计中的标题/topic alias 与 T0–T4 规则尚未闭环

治理设计要求：

- 标题中的规范 topic 必须映射到 `topic_groups`；
- 术语别名来自 `topics.yml`；
- JUnit、Vitest/Playwright、pytest、Mock、集成/容器测试必须服从 T0–T4 的教师章和先修规则；
- outcome 的 verification level 不能只是任意字符串；
- broad `synthesis|review|project` 章节必须说明为何属于综合章。

当前实现仍主要完成了：

- topic 显式注册与先教后用；
- outcome group/topic 覆盖；
- chapter 级 `verification_mode.test_level` 枚举；
- 普通章/综合章 topic group 数量限制。

尚未看到可执行的：

- title alias registry 与标题声明审计；
- 框架术语到教师 capability / prerequisite 的 T-level 规则；
- outcome `verification_mode` 的受控值或与 chapter test level 的一致性；
- broad role 的“为何综合”字段及断言。

风险：规范输入可以在结构上通过，但标题或 outcome 提前要求尚未教授的测试框架；设计文档声称的零基础保证强于实际 validator。

修复建议：

1. 将 `topics.yml` 升级为带 canonical ID、aliases、testing-level 的对象注册表；
2. 为标题提取建立确定性的 alias→topic 映射，不依赖临时字符串特判；
3. 将 framework capability 与 T-level 规则写入规范输入，并由 validator 执行；
4. outcome 使用枚举或结构化 verification contract；
5. 为每条规则提供正例、精确负例和 exception fixture。

### S1-3：P1R 设计文档与实际 schema 仍有命名和数量漂移

本次审查发现的文档/实现差异包括：

- 文档 `kind`，实现 `role`；
- 文档 `prerequisite_reasons`，实现 `prerequisite_rationales`；
- 文档 `later_teacher`，实现 `later_teacher_chapter_id`；
- 文档顶层 `teaches_capabilities` / `uses_capabilities`，实现嵌套 `capabilities.teaches` / `capabilities.uses`；
- 文档 `created_in`，实现 `introduced_in`；
- 文档中的 chapter ID domain regex 不接受当前大量合法 domain；
- 部分标题和完成标准仍写 80 capabilities，当前 edition 冻结值为 94；
- 文档承诺可嵌入 `book/volume-*/INTRO.md`，生成器目前没有加载该输入。

风险：P2 schema、front matter、教材作者和后续 agent 会依据错误合同继续实现，形成第二套事实源。

修复建议：

1. 选定实现中的真实字段名，统一更新设计、schema 示例和 P2 计划；
2. chapter regex 直接引用 edition 的 canonical pattern，或建立显式 domain registry；
3. 数量表述使用“edition 声明值（当前 94）”，避免跨 edition 硬编码；
4. 对 INTRO 支持作出明确决策：实现严格快照输入，或删除/延期该承诺。

### S2-1：scope exception 的“后续 edition”校验仍不充分

当前逻辑只拒绝：

- `never|none|n/a|permanent`；
- 与当前 edition 完全相同的值。

因此，`expires_in_edition: 2020.1` 或 `expires_in_edition: banana` 仍可通过“必须在后续 edition 过期”的检查。

同时，无 scope violation 的章节也可携带 exception，容易形成永久遗留配置。

修复建议：

- 定义 edition ID schema 并做可比较的版本解析；
- 强制 `expires_in_edition > current edition`；
- 拒绝未被实际 scope violation 使用的 exception，或为预先批准建立单独、可审计的状态。

### S2-2：human chapter front matter 仍是子集一致性，不是完整 catalog 等价

当前 human chapter 检查已经覆盖 schema version、edition、ID、title、responsibility、volume/order、level/status、path、catalog、prerequisites、version surfaces 和 route tags，明显强于早期实现。

但它仍允许额外陈旧字段，并且没有把 role、topic groups、outcomes、capability contract 纳入同一个精确 key set。

风险：章节正文进入 drafting/review 后，部分 pedagogical contract 可与 canonical catalog 漂移，而 P1 generator 本身不报错。

修复建议：

- 定义唯一的 chapter-frontmatter v2 schema；
- placeholder 和 human chapter 共享同一个基础 contract；
- 精确拒绝未知/陈旧字段；
- P2 validator 逐字段比较 catalog/front matter，并保留正文质量断言。

### S2-3：未发现完整 managed-output 清单对陈旧生成物做闭包扫描

当前 generator 会检查：

- 279 个期望输出；
- orphan planned placeholders；
- `v*.md` legacy chapters。

但没有通用的 managed-output manifest 去发现任意额外的旧 route、旧 generated README 或改名后遗留文件。

风险：一个不再属于期望集合的 generated file 可能继续存在，`--check` 仍只比较当前已知集合。

修复建议：

- 生成并验证 managed-output manifest；
- manifest 精确列出 path、kind、digest 和 owner；
- `--check` 扫描受管根目录，额外生成物必须 DELETE 或 CONFLICT；
- 非生成文件保持不可触碰。

### S2-4：测试矩阵仍远小于治理设计要求

当前测试文件只有 13 个 test。即使修复当前红灯，仍缺少至少以下公开端到端测试：

- 完整有效 synthetic fixture；
- migration drafting / ready / applied 三态；
- preserve/replace/split/merge/repartition/remove/new cardinality；
- frozen generated-output adoption 的 plan→write→check→plan no-op；
- create/update/delete 三种异常回滚及 mode 恢复；
- 子进程强杀后的明确行为；
- generated Markdown/YAML 所有权伪造；
- canonical input、output target、父目录和 orphan 的 symlink；
- target/input 并发变更；
- route plan unknown key、错误 identity、非法 artifact path；
- title/topic alias、T-level、scope exception；
- stale managed output；
- 两次独立 render 的文件集合和字节一致；
- 所有生成 YAML aliases-disabled 严格读取；
- human chapter 精确 front matter。

治理设计要求“每条断言至少有正例、精确负例和 exception fixture”，当前尚未达到。

### S2-5：P2 全仓闭环仍未通过

当前执行：

```bash
ruby scripts/validate-encyclopedia.rb
```

返回码为 1。可见问题包括：

- generated outputs 尚未与 v2 canonical specs 对齐；
- legacy 章节仍使用旧 front matter / ID；
- `versions/registry.yml` 为 `2026.2-draft`，旧 catalog/site 仍为 `2026.1-draft`。

这是 P2 计划已经明确的工作，不应在 P1 编译器中临时加兼容层，但必须作为整体发布门禁保留。

## 4. 审查期间已修复并复验的问题

### 4.1 ready adoption 的 commit 二次校验

早期问题：plan 接受 frozen legacy generated output 为 `UPDATE`，commit 却只接受新 marker，导致 ready 迁移必然报 `E_OUTPUT_OWNERSHIP`。

当前实现已经把 `spec` 传入 target snapshot revalidation，并允许：

```text
safe_owned_generated_output? OR adoptable_legacy_file?
```

当前只读复验：

```text
legacy_generated_adoption_revalidation=pass
```

仍需补正式端到端测试，避免未来 plan/commit 所有权谓词再次分叉。

### 4.2 generated output 所有权收紧

早期误判：

- Markdown 在正文中任意提及 marker 即被视为可覆盖；
- YAML 只有 `generated: true` 与 `generated_by` 即被视为可覆盖。

当前实现：

- Markdown 要求 marker 位于文件开头；
- YAML 按具体输出路径要求精确顶层 key set、schema version、owner、edition 和合法 digest。

当前对抗复验：

```text
md_owned=false
yaml_owned=false
```

### 4.3 route plan 与 FactoryCare path

早期 route identity / unknown key 被静默忽略，`../../secrets/` 可进入 FactoryCare project artifact。

当前对抗复验会产生 `E_SCHEMA` 与 `E_FACTORYCARE_PATH`，相关问题已修复。

### 4.4 contract path

当前行为：

```text
"evidence/x/" = true
"evidence/x"  = true
"../x"        = false
"/abs"        = false
"x/./y"       = false
"x\nq"       = false
"x\u0000q"   = false
```

目录 trailing slash 可合法保留，绝对路径、点段、控制字符和 NUL 被拒绝。

### 4.5 migration evidence

当前 ready validation 会：

- 冻结 Note / Java-Note commit；
- 加载 source inventory、source build、candidate manifest；
- 对真实字节核对 SHA-256；
- 将证据文件纳入 canonical input snapshot；
- 拒绝不安全 evidence path；
- 禁止 automatic promotion。

### 4.6 普通异常回滚的 mode 恢复

snapshot 现在保存 `{body, mode}`，delete 后异常恢复会显式还原原 mode。该项代码路径已修复，但仍需新增 delete rollback 测试。

## 5. 已验证结果

以下结果来自当前工作区的只读命令：

### 5.1 语法与确定性

```text
ruby -w -c scripts/lib/curriculum_compiler.rb
Syntax OK
```

两次独立加载和渲染：

```text
outputs=279
deterministic=true
yaml_bad=0
placeholders=255
ownership_bad=0
```

即：

- 输出数为 279；
- 两次内存渲染文件集合与字节完全相同；
- 所有生成 YAML 均可在 aliases 禁用的严格模式读取；
- 255 个 placeholder 均通过当前严格 ownership/body-shape 检查。

### 5.2 路线和索引

此前同一实现路径已验证：

- accelerated route 为 48 modules；
- 255 个 primary chapter IDs 恰好覆盖且无重复；
- reference index 精确覆盖 255 章；
- FactoryCare 为 8 stages、26 个不重复 primary anchors。

### 5.3 严格输入

代码与已有测试覆盖：

- YAML 顶层和嵌套重复 key；
- YAML aliases / merge key；
- 非字符串 mapping key；
- JSON duplicate member；
- migration JSON Schema 的未知 keyword 和本地 ref；
- canonical input 缺失、类型错误和 symlink ancestor；
- output target / parent symlink；
- target/input SHA snapshot 二次校验。

### 5.4 当前迁移计划

```text
edition=2026.2-draft
chapters=255
volumes=16
capabilities=94
modules=48
factorycare_stages=8
CREATE=255
DELETE=170
UPDATE=24
CONFLICT=0
```

该结果只证明 plan 可生成且无 conflict，不证明写入后全仓可发布，也不证明 crash-atomic。

## 6. 未验证事项

本次没有验证或不能由当前测试证明：

- 实际执行 `--write` 后的文件系统结果；
- write 后 `--check` 和第二次 plan 是否为 no-op；
- `SIGKILL`、断电、磁盘满、只读文件系统等故障恢复；
- rollback 自身再次失败时能否恢复其余文件；
- 非合作外部进程在 revalidation 与 rename 之间修改输入/目标；
- 所有 source mapping section 的人工语义正确性；
- 255 章的教学内容、事实、版权和来源质量；
- P2 site/build/source inventory 的最终确定性；
- 两个来源仓库的所有内容是否已经被逐节人工审核；
- 当前 130 个 redundant prerequisite warning 是否已经全部完成语义取舍（计数可能由并行修订继续变化）。

## 7. 非目标

本审查没有：

- 执行 `--write`；
- 修改 compiler/generator/P2 validator；
- 自动批准 migration ledger 的人工语义映射；
- 把 placeholder 当作教材正文；
- 把生成成功当作学习者掌握；
- 为旧 ID 增加 alias、redirect 或兼容层；
- 编写几十万字教材正文；
- 修改 `PROGRESS.md`；
- 审核求职材料或其他不相关文件。

## 8. 建议的放行顺序

1. 修复当前失败测试，并确保所有测试全绿；
2. 增加 ready adoption 的临时工作区端到端测试；
3. 决定并记录 crash-atomic 方案，或降低文档承诺；
4. 补齐 generated ownership、symlink、并发、delete rollback 与 stale-output 对抗测试；
5. 完成 title/topic alias、T-level、scope exception 和 human front matter 合同；
6. 统一 P1R 设计文档中的字段名、ID regex 和 capability 数量；
7. 在隔离副本中演练 plan→write→check→plan no-op；
8. 完成 P2 schema/validator/build/site/source mapping 回归；
9. 运行全仓测试、两次完整 build 和独立安全审查；
10. 只有所有门禁通过后，才在正式工作树执行迁移。

## 9. 最终声明

当前实现可以宣称：

> canonical inputs 严格加载；279 个目标输出确定性渲染；单文件原子替换；普通进程内异常下按快照回滚；旧 generated outputs 只有在 ready ledger 和冻结 SHA 匹配时才可采用。

当前实现不能宣称：

> 整套 449 个文件变更在进程被杀或断电时具有 crash-atomic 保证。

在测试恢复全绿、完成隔离迁移演练和 P2 全仓闭环之前，本审查结论为：**有条件不通过，不执行正式 `--write`**。
