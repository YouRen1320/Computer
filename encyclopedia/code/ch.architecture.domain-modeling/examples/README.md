# WorkOrder 领域模型观察台

本纯 Java 工程用十一条断言演示 WorkOrderId 身份、AssetCode/TeamId 值语义、合法创建、主路径命令和非法转换前后快照不变。示例保留 FactoryCare 精确 12 状态集合，但只实现本章主路径。

先预测状态与 version，再运行 `./verify.sh`。它不证明数据库、事务、并发、授权、ORM 或分布式事件。

验证器要求 JDK 25、Maven 3.9.16，并完全离线运行。
