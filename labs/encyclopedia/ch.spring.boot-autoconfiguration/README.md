# Starter、Profile、条件与覆盖实验

实验用十一组离线断言检查 imports 发布合同、类路径条件、布尔配置三态、用户实现 back-off、条件报告、互斥 Profile、构造器循环失败和资源销毁。

先写出每组期望的 Bean 类型与数量，再运行 `./verify.sh`。`ApplicationContextRunner` 证明装配切片，不证明真实服务器或第三方 starter 的生产兼容性。

验证器要求 JDK 25、Maven 3.9.16，并完全离线运行。
