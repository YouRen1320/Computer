# 应用服务边界观察台

`AssignWorkOrderService` 使用可替换端口执行 load→aggregate.assign→save→audit→outbox。领域对象不认识 HTTP、Spring 或 SQL；Controller 只把协议数据映射成 command/result。

唯一入口 `./verify.sh` 要求 JDK 25、Maven 3.9.16 并完全离线执行。这里证明编排，不声称 fake ports 具有数据库事务语义。
