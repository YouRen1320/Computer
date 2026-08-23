# 练习：修复函数合同链

公开练习按设计保持红灯。不要修改 verifier、断言消息或 `expected.stdout`；依次修复：

1. `formatWorkOrder` 调用的实参顺序；
2. `totalMinutes` 的缺失返回值；
3. `formatPriority` 对模块级共享计数的意外修改。

初始稳定失败消息为 `PARAMETER_ORDER_EXERCISE`。修复前先填写输入、返回、副作用、调用次数四格合同。
