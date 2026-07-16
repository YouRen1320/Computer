# 聚合独立练习（红色 starter）

修复 `answer.sql`：只选择分组键与 aggregate；WHERE 只过滤 enabled 行；HAVING 过滤至少两台不同设备的组；同时输出事件数、不同设备数、非 NULL 时长数、总和与平均值。

`./verify.sh` 在 starter 被预期拒绝时成功。完成后运行 `ruby oracle.rb answer.sql`。
