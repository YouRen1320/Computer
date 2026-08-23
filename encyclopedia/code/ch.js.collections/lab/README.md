# ch.js.collections 实验

目标是按状态分组、按 ID 去重并保护输入所有权。`src/collection-contract.mjs` 是绿灯基线；`faults/` 隔离注入 `DUPLICATE_KEY_LOSS_OVERWROTE_FIRST`、`REFERENCE_ALIASING_NESTED_PATH`、`INPUT_MUTATION_SORT_CHANGED_CALLER`。运行 `./verify.sh`；通过要求基线 stdout 精确匹配，三个故障都非零退出并包含各自标记。

| 案例 | 长度/顺序 | 唯一性 | 引用 |
| --- | --- | --- | --- |
| 空 | 0 个组 | 0 个唯一项 | 返回新数组 |
| 重复 | CREATED 含 2 条 | WO-1 保留第一次 | 输入不变 |
| 缺失 | UNSPECIFIED 组 | ID 仍参与 Set | 新记录 |
| 更新 | WO-2 进入 IN_PROGRESS | 规则不变 | 新 metadata |
