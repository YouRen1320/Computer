# 子查询与 CTE 独立练习（红色 starter）

修复 `answer.sql`：

- 用外层 `d.device_id` 修正相关谓词；
- 把错误的 DONE 条件改成 OPEN/IN_PROGRESS 未完成集合；
- 保留 `unfinished_devices` 与 `category_counts` 两个可单独检查的 CTE；
- 最终只输出设备数至少 2 的类别；
- 不用 NOT IN 处理可能含 NULL 的排除集合。

`./verify.sh` 只有在 starter 被 oracle 按预期拒绝、且第一处诊断明确指向相关层级时才成功。
