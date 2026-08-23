# 练习：用绑定与顺序满足 stdout 预言

公开练习故意保持红灯。不要修改 `verify.sh` 或 `expected.stdout`；完成三个 TODO：

1. 工单 ID 在本次追踪中不变，应使用 `const`；
2. 当前状态会被有意更新，应使用 `let`；
3. `after` 输出必须位于赋值之后。

运行 `./verify.sh`。初始稳定失败标记为 `STATEMENTS_VARIABLES_EXERCISE_RED: WORK_ORDER_ID_MUST_BE_CONST`。修复前请先手写逐行状态表和三行 stdout。
