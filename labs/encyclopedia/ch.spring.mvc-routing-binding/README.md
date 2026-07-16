# FactoryCare MVC 入站契约实验

实验将详情、分页、类型转换、必填 header、未知路由、错误 method 和歧义登记变成十二个可重放断言。`InMemoryWorkOrderQuery` 的调用计数用于区分“方法调用前绑定失败”和“调用后资源不存在”。

先写请求矩阵，再运行 `./verify.sh`。MockMvc 不证明真实 socket、代理、TLS 或最终 JSON DTO，只证明本章的 Servlet MVC 边界。

验证器要求 JDK 25、Maven 3.9.16，并完全离线运行。
