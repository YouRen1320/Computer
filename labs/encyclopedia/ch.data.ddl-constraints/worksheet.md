# Worksheet

| case | 预计约束/结果 | 实际 | 第一处可信证据 |
| --- | --- | --- | --- |
| 合法 device |  |  |  |
| 合法 work_order |  |  |  |
| D-99 孤儿工单 |  |  |  |
| 重复 SN-001 |  |  |  |
| device BROKEN |  |  |  |
| order UNKNOWN |  |  |  |
| summary NULL |  |  |  |
| 外键反向 |  |  |  |
| 存量 D-legacy 后 ADD CHECK |  |  |  |
| NOT VALID 后新写 BROKEN |  |  |  |

负例一次只破坏一个不变量，记录约束名和失败后行数。重建失败时必须证明旧结构仍在、半成品不存在。
