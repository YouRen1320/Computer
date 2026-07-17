# 练习：修复控制流的三类边界

公开练习按设计保持红灯。不要修改 `verify.sh` 或预期文件：

1. 用精确整数/范围表达式接受合法 `retryCount=0`，不要用 truthiness 判断有效性；
2. 为 switch 补齐 P2→expedited 分支并正确 break；
3. 把计数循环修成精确执行 `retryCount` 次，而不是多一次。

初始稳定标记为 `CONTROL_FLOW_EXERCISE_RED: TRUTHINESS_REJECTS_ZERO`。修复前先写零、一次、多次和非法输入边界表。
