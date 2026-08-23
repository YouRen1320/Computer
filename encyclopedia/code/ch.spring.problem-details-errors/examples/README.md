# ProblemDetail 错误边界观察台

本工程用真实 Spring MVC advice 验证 FactoryCare 的 validation 400、not-found 404、conflict 409、unknown 500 以及正常 200/201。测试同时检查 RFC 9457 五字段、稳定扩展、problem 媒体类型、不泄露 SQL/类名/堆栈，以及服务端 reporter 保留 trace 和 cause。

运行 `./verify.sh` 前先预测九个测试结果。standalone MockMvc 不证明 Boot 自动配置顺序、filter、容器 `/error`、代理或 committed response。

验证器要求 JDK 25、Maven 3.9.16，并完全离线运行。
