# 公开练习：Pydantic 外部输入合同

编辑 `exercise.py` 的 `WorkOrderContract`，让边界满足：

- strict 模式拒绝字符串到整数的隐式转换；
- `extra="forbid"` 拒绝拼错的额外字段；
- 输入、JSON 输出和 JSON Schema 使用 `workOrderId`；
- `work_order_id > 0`、priority 范围为 1–5；
- priority 为 5 时必须提供非空 `escalation_reason`。

依赖锁定为 Pydantic `2.13.4`。初始 `./verify.sh` 返回 `41`，修复后返回 `0`；
语法、导入或基础设施异常返回 `43`。
