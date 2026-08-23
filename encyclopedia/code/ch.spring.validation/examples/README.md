# Bean Validation 边界观察台

本工程用 FactoryCare 工单创建 DTO 演示字段约束、类级跨字段约束、稳定属性路径和 MVC 入站校验。八个断言区分合法请求、字段错误、截止时间冲突、缺失值和 JSON 绑定失败，并用调用计数证明非法输入未进入用例。

先预测 violation path，再运行 `./verify.sh`。它不证明授权、数据库唯一性、事务、真实端口或公开错误体，只验证 Jakarta Validation 与 Spring MVC 的本章边界。

验证器要求 JDK 25、Maven 3.9.16，并完全离线运行。
