# 外部配置与 Profile 示例

这个 Spring Boot 4.1.0 工程演示 `application.properties` 默认值、`application-dev.properties` 的增量覆盖、环境变量与命令行优先级，以及 `@ConfigurationProperties` 的类型绑定和启动期校验。

运行 `./verify.sh` 前先预测七组结果：默认绑定、dev 覆盖、环境覆盖文件、命令行覆盖环境、缺少必填秘密时报错、数值越界时报错、诊断文本脱敏。

Profile 只选择基础设施适配器；它不承载价格、权限等任意业务分支。测试秘密仅由命令行或模拟环境注入，源码与输出都不保存真实凭据。

验证器要求 JDK 25、Maven 3.9.16，并完全离线运行。
