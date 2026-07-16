# 窗口函数独立练习（红色 starter）

修复 `answer.sql`：

- 每个分析窗口都按技师分区；
- 每个窗口顺序都使用 `created_at, work_order_id` 稳定全序；
- 保留每张工单并计算组内 row_number、前后间隔；
- 累计完成数显式使用从分区开头到当前行的 ROWS frame；
- 最终展示也按技师、时间、工单 ID 排序。

`./verify.sh` 只有在 starter 被预期拒绝，且第一处诊断明确指向缺 PARTITION 时才成功。
