# 示例：enum、record 与 sealed 观察台

示例用完整十二状态 `WorkOrderStatus` 约束词表，用带紧凑构造校验的 `EquipmentCoordinate` 表达坐标值，再用三个 record 实现 sealed 命令接口，并通过无 default 的 pattern switch 生成固定摘要。

~~~bash
cd examples/encyclopedia/ch.java-oop.enum-record-sealed
./verify.sh
~~~

运行前预测 enum 解析、record 身份/值相等和三个命令输出。验证器还要求字符串状态拼错与数组 record 真实运行失败，并要求新增 permitted 类型但漏掉 case 时 javac 真实报告非穷尽。成功末行是 `EXAMPLE PASS`。
