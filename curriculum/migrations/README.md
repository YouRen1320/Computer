# 课程迁移账本

迁移账本是 2026.1 旧位置型 ID 到 2026.2 语义稳定 ID 的一次性审计合同。运行时不保留 alias、redirect、双写 route 或 shadow placeholder；回滚只恢复迁移前完整快照。

## 文件

- `migration.schema.json`：账本结构约束。
- `application-receipt.schema.json`：一次性迁移实际执行后的不可变回执约束。
- `2026.1-to-2026.2.yml`：本次 170 个旧 ID 到 255 个 active ID 的 applied 账本；151 个分量与 275 条章节边由独立审计逐项核对，来源候选仍保持 `unreviewed`。
- `receipts/catalog-2026.1-to-2026.2-semantic-ids.yml`：2026-07-15T23:10:56Z 实际迁移的应用回执，记录完整计划、写后输出清单、严格检查与后置条件。

## 动作

- `preserve`：语义相同，一对一更换为稳定 ID。
- `replace`：语义实质调整，一对一新 ID。
- `split`：一个旧章拆成多个新章。
- `merge`：多个旧章合并为一个新章。
- `repartition`：多个旧章重新划分为多个新章。
- `remove`：旧章删除且无替代。
- `new`：全新章节，没有旧来源。

每个旧 ID 必须在全部 entry 的 `from` 中恰好出现一次；每个 active 新 ID 必须在 `to` 中恰好出现一次。`split` 和 `repartition` 允许两种审计策略：

- `manual-section-override`：逐 section 人工指定去向，并记录 `section_overrides`。
- `regenerate-from-frozen-source-inventory`：从冻结的双仓库 commits 和原始 section inventory 出发，按新 catalog 全量重建；entry 通过 `source_rebuild_id` 引用 `source_rebuilds`。该策略不要求为每个 section 手写 override，但在账本进入 `ready` 前必须固化双仓库 commits、构建器 digest、catalog 投影 digest、source inventory digest、build digest 和 candidate manifest digest。

两种策略都禁止把旧 section 盲目复制到所有目标章。重建候选只能保持 `unreviewed` 或 `manual-review-required`，`automatic_promotion` 必须为 `false`，不得因生成成功而自动升级为已审核。

## 完成门禁

1. `expected_legacy_id_count` 与冻结旧 catalog 中的唯一 ID 数一致。
2. `expected_active_id_count` 与新 edition 目标一致。
3. `status: ready` 时，`manual-section-override` 路径不得存在 `manual-review-required` override；`regenerate-from-frozen-source-inventory` 路径必须有可核对的 source build/commit/digest 证据，但不要求 `section_overrides`。
4. 新 catalog、routes、gates、README 和 placeholder 中不得出现旧 ID。
5. `sources/mappings.csv` 的实际迁移属于后续显式迁移步骤；本骨架和生成器不会静默修改 sources。

## `ready` 到 `applied`

`ready` 只证明迁移输入和预期计划已冻结，并不代表文件已经迁移。此状态会继续锁定 source rebuild 记录的 catalog 投影；`drafting` 和 `ready` 都禁止携带 application receipt。

实际迁移必须使用显式的两阶段证据流程，普通 `generate-curriculum.rb` 不会生成回执：

1. 在 `ready` 文件树上运行 `ruby scripts/capture-curriculum-migration-plan.rb --output /安全位置/plan.yml`，冻结 migration ID、ready catalog 投影与完整 create/update/delete 计划。
2. 人工审阅计划后，显式运行 `ruby scripts/generate-curriculum.rb --write`；保存退出码，不得用一次后续成功覆盖一次失败。
3. 写入成功后运行 `ruby scripts/finalize-curriculum-migration.rb --plan-evidence /安全位置/plan.yml --output curriculum/migrations/receipts/<name>.yml --write-exit 0 --applied-at <UTC时间> --applied-by <执行者>`。finalize 会重新执行 strict check，要求旧章节数为 0、新语义章节数为 255，并写入一个此前不存在的回执文件。
4. 审阅回执及其 sha256 后，才可在同一次人工变更中把 `application_receipt_path`、`application_receipt_digest` 加到账本，并将 `status` 从 `ready` 改为 `applied`。

回执冻结迁移 ID、ready catalog 投影、legacy manifest 与 mapping audit digest、完整计划及 action counts、写后 output manifest、write/check 退出码、postconditions、`applied_at` 和 `applied_by`。只修改枚举为 `applied`、篡改回执字节或伪造不一致的语义字段都会校验失败。合法回执验证通过后，历史 ready 投影锁才会解除，后续正常章节创作无需改写历史迁移证据。

若任一步失败，账本必须保持 `ready`。回滚方式是恢复迁移前完整快照；不要创建 alias、redirect、双写 route 或 shadow placeholder 来掩盖一次未完成的迁移。
