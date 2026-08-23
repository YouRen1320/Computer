# P1R 课程目录编译器与迁移账本完成审计

> 审计日期：2026-07-16
> 范围：P1R canonical curriculum specs、目录编译器、2026.1 → 2026.2 迁移账本和只读/临时副本验证。
> 结论：本范围 **PASS**；真实工作区迁移尚未执行，P2 schema/site 收口不属于本结论。

## 1. 冻结规模与迁移拓扑

- edition：`2026.2-draft`。
- volumes：16。
- chapters：255。
- capabilities：94。
- topics：1,893。
- accelerated modules：48。
- FactoryCare stages：8。
- legacy IDs：170。
- 独立审计连通分量：151。
- 精确章节边：275。
- 分类：preserve 84、split 43、merge 0、repartition 17、new 7。

`curriculum/migrations/2026.1-to-2026.2.yml` 使用 `chapter_edges` 保存章节级拓扑，并由 `P1R-migration-ledger-audit.md` 独立校验。`section_overrides` 为空；章节边没有被冒充为逐 section 人工复核结果。

60 个 split/repartition 分量使用 `regenerate-from-frozen-source-inventory`。来源候选保持：

```yaml
candidate_statuses: [unreviewed]
automatic_promotion: false
```

## 2. 冻结来源全量重建

规范输入：

- Note commit：`72b27e3bad732fa86d5fd9d9c990c6d5ecaf9f96`。
- Java-Note commit：`3c4928bf78b24d6550538ea388240fe3b4ce407e`。
- source inventory builder SHA-256：`0dcbb64e53f8aadb05a1758787f1d7debc1370f162de81f5ae7183d7fb5015fa`。
- v2 catalog 语义投影 SHA-256：`2e78f80cd4dc4db6c5686464844843316911e0b3dff20df2271bd1d0db652102`。

实际执行命令：

```bash
ruby scripts/build-source-inventory.rb \
  --note-repo /tmp/factorycare-note-audit.SOGSxV/Note \
  --java-note-repo /tmp/factorycare-note-audit.SOGSxV/Java-Note \
  --note-commit 72b27e3bad732fa86d5fd9d9c990c6d5ecaf9f96 \
  --java-note-commit 3c4928bf78b24d6550538ea388240fe3b4ce407e \
  --catalog /tmp/p1r-source-rebuild/input/catalog-current.yml \
  --output /tmp/p1r-source-rebuild/output

ruby scripts/build-source-inventory.rb \
  --note-repo /tmp/factorycare-note-audit.SOGSxV/Note \
  --java-note-repo /tmp/factorycare-note-audit.SOGSxV/Java-Note \
  --note-commit 72b27e3bad732fa86d5fd9d9c990c6d5ecaf9f96 \
  --java-note-commit 3c4928bf78b24d6550538ea388240fe3b4ce407e \
  --catalog /tmp/p1r-source-rebuild/input/catalog-current.yml \
  --output /tmp/p1r-source-rebuild/output \
  --check
```

结果：

- files：3,424。
- Markdown：443。
- PDF：14。
- mappings：9,174。
- rows with chapter candidates：8,361。
- chapter references：91,912。
- distinct semantic candidate IDs：158。
- legacy chapter references：0。
- reviewed / unreviewed：0 / 9,174。
- 独立复跑耗时：约 8.15 秒。

六个确定性输出逐字节匹配：

| 输出 | SHA-256 |
| --- | --- |
| `catalog.yml` | `85fb9914877d6ac0f99419639a69a4e87bcbdf4adba2b5e16ccacd8c6e8cddd1` |
| `files.csv` | `a326a7b5808f8044a58e49597eefc1566bc02167116940444cba26435ef1799f` |
| `mappings.csv` | `4a9e5aca39e66fbc4c954f1e1760553fd721e8cc7c12922d8be4ff8d3072fd92` |
| `README.md` | `2ca96461bc1265133297f3560b2eca1f8562a595ed509b734b3491a87fe62e8a` |
| `migration-policy.md` | `99f3d1b892a0495b087e10e87a78ee561fb5d41ea4a60e37f61218ef0ec7c6c0` |
| `ADVERSARIAL-REVIEW.md` | `84f0a129ae3269636418f7f14e51c5d78a5c8b2c7756b346b26ad9de5505d06f` |

## 3. Plan、写入与幂等证据

真实工作区只执行 `--plan`：

```text
CREATE=255
UPDATE=24
DELETE=170
CONFLICT=0
E_=0
W_=0
```

在明确打印 PWD 的临时副本 `/tmp/factorycare-p1r-final.cG0qrf/workspace` 中执行：

```bash
ruby scripts/generate-curriculum.rb --plan
ruby scripts/generate-curriculum.rb --write
ruby scripts/generate-curriculum.rb --check
ruby scripts/generate-curriculum.rb --plan
```

四步均返回 0。迁移后 legacy chapters 为 0，semantic placeholders 为 255；第二次 plan 为 `UNCHANGED=279`，其余动作均为 0。

## 4. 异常回滚证据

临时副本 `/tmp/factorycare-p1r-rollback.5VD1JY/workspace` 在第 200 个写入动作注入异常。回滚后：

- `book/` 与写入前快照 `diff -qr` 为 0。
- `curriculum/routes/` 与写入前快照 `diff -qr` 为 0。
- 四个 core generated files 字节一致。
- legacy chapters 恢复为 170。
- semantic placeholders 恢复为 0。
- 删除文件的原始 mode 与字节由单元测试验证恢复。

因此当前保证是：单文件原子 rename，以及 Ruby 普通异常下的整批反向回滚。

## 5. 真实工作区恢复与冻结核验

最终真实工作区状态：

- frozen legacy manifest：194 个文件，其中 generated output 24、legacy chapter 170。
- 194 个当前文件与冻结 SHA-256 比较：mismatch 0。
- legacy chapters：170。
- semantic placeholders：0。
- `PROGRESS.md`：无 diff。
- 未保留任何真实工作区 `--write` 结果。

## 6. 自动验证

```text
curriculum tests: 21 runs, 68 assertions, 0 failures, 0 errors
migration audit: 151 components, 275 edges, 170 old IDs, 255 new IDs
generator plan: rc 0, E_=0, W_=0, conflicts=0
git diff --check: PASS
```

路径与所有权负例覆盖：unknown route fields、错误 route identity、`../../`、NUL/控制字符、FactoryCare evidence 根目录逃逸、伪造 generated marker、首次 frozen output adoption，以及 delete rollback/mode restoration。

## 7. 明确边界与非目标

- 9,174 条来源映射仍是机器候选，不是逐条人工采用决定，也不证明教材正文已完成。
- 本实现不承诺进程被强杀或断电时的跨文件 crash-atomic；只能声称单文件原子和普通异常回滚。
- 真实工作区迁移必须由总任务在 P2 schema、validator、site/build 全部收口后统一执行。
- 本审计不宣称 P2、站点构建或最终几十万字正文已经完成。
- 没有保留 legacy alias、redirect、shadow placeholder 或双 ID 运行时兼容层。
