# DTO、JSON 与内容协商观察台

本工程用 FactoryCare 工单创建接口演示请求 DTO、响应 DTO 与领域对象的分离。九个断言覆盖 JSON 往返、响应字段白名单、严格未知字段策略，以及 `Content-Type`/`Accept` 导致的 400、415、406 和成功 201。

先预测每个请求是否会进入用例，再运行 `./verify.sh`。MockMvc 只证明 Spring MVC 消息转换和协商边界，不证明真实端口、代理、TLS、统一错误体或外部客户端兼容性。

验证器要求 JDK 25、Maven 3.9.16，并完全离线运行。
