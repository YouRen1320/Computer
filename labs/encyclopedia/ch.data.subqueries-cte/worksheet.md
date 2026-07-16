# Worksheet

| 检查 | 先写预测 | 运行后观察 | 第一处可信证据 |
| --- | --- | --- | --- |
| IN 空子集 |  |  |  |
| NOT IN 空子集 |  |  |  |
| 标量子查询遇 D-01 两行 |  |  |  |
| EXISTS 遇多匹配是否复制外层行 |  |  |  |
| NOT IN 右集合含 NULL |  |  |  |
| NOT EXISTS 右集合含 NULL |  |  |  |
| w.device_id=w.device_id |  |  |  |
| 正确 unfinished_devices |  |  |  |
| DONE 版 unfinished_devices |  |  |  |
| category_counts |  |  |  |
| 扁平版与 CTE 版 |  |  |  |

诊断顺序：先单独核对 `unfinished_devices`，再核对 `category_counts`，最后才看最终筛选。不要从最终空结果反猜全部原因。
