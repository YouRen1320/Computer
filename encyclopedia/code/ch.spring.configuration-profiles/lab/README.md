# 外部配置与 Profile 边界实验

本实验把 Spring Boot 的配置链变成十个可重放断言：基础文件绑定、Profile 增量覆盖、环境变量与命令行优先级、基础设施适配器选择、缺失/越界/未知配置的快速失败，以及秘密脱敏。

先阅读 `src/main/resources` 的两份配置，再运行 `./verify.sh`。注意环境变量使用 Spring Boot 的规范映射：去掉短横线、点号改下划线并转大写，例如 `factorycare.api-base-url` 对应 `FACTORYCARE_APIBASEURL`。

实验不启动端口，不依赖真实环境变量，也不会把测试秘密打印到验证器输出。Profile 只表达部署环境差异，不替代业务规则建模。

验证器要求 JDK 25、Maven 3.9.16，并完全离线运行。
