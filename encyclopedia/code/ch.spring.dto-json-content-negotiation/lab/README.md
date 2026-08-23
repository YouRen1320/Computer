# FactoryCare DTO 与媒体类型实验

实验把请求/响应 wire shape、缺失值与显式 `null`、领域敏感字段隔离、未知字段、非法枚举、错误 JSON、415 和 406 变成十一条可重放断言。`RecordingUseCase` 的计数用于判断失败是否发生在业务调用之前。

先列出请求矩阵和预期响应，再运行 `./verify.sh`。本实验不定义 Bean Validation 规则，也不证明真实网络、代理配置或公开错误响应格式。

验证器要求 JDK 25、Maven 3.9.16，并完全离线运行。
