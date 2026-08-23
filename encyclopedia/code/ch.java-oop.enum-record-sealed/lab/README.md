# 实验：FactoryCare 状态、坐标与受限命令

实验冻结 FactoryCare 十二状态词表，但不实现完整状态转换。`EquipmentCoordinate` 在紧凑构造器中规范化并拒绝非法位置；Assign、Start、Resolve 三个 record 是 sealed 命令叶子，由无 default switch 穷尽生成摘要。

~~~bash
cd labs/encyclopedia/ch.java-oop.enum-record-sealed
./verify.sh
~~~

验收包含十七个正常断言，以及未知状态、可变数组 record、未许可实现和新增叶子非穷尽四类固定失败。需求变更：增加 `RequestApprovalCommand(reason)`，先保存全部编译影响点，再补 case 和空白 reason 校验；不实现权限或数据库迁移。
