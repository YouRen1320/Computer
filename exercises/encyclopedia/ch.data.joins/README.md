# JOIN 独立练习（红色 starter）

修复 `answer.sql`：

- 用显式 JOIN ... ON 连接设备与工单；
- OPEN 条件放在 LEFT JOIN 的 ON 中以保留无匹配设备；
- 技师计数使用 COUNT(w.work_order_id)；
- 输出全体技师计数，并用 HAVING >=2 输出高负载组。

`./verify.sh` 在 starter 被按预期拒绝时成功。
