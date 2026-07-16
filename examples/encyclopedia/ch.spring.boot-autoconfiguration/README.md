# Boot 自动配置观察台

工程用 Spring Boot 4.1.0 的 `@AutoConfiguration`、imports 元数据和条件注解装配 FactoryCare 审计 sink。八个断言覆盖候选发现、缺省/false/true、condition report、用户 Bean back-off、受管销毁、Profile 和真实非 Web `SpringApplication` 启动。

运行 `./verify.sh` 前先预测每个 context 的 `AuditSink` 数量与来源。自动配置只选择技术适配器，不承载工单业务规则。

验证器要求 JDK 25、Maven 3.9.16，并完全离线运行。
