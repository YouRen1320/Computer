# MVC 路由与参数绑定观察台

本工程使用 Spring Framework 7.0.8 的真实 MockMvc 调度链，验证 FactoryCare 详情与列表 Controller 的 method/path 选择、path/query/header 绑定，以及 200、400、404、405 状态合同。Spring Framework 版本由 Spring Boot 4.1.0 BOM 管理。

运行 `./verify.sh` 前先预测十个请求结果。响应采用简单文本，刻意不把默认序列化行为写成 JSON 兼容证据；不启动真实端口。

验证器要求 JDK 25、Maven 3.9.16，并完全离线运行。
