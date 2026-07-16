# Boot 4.1 运行契约实验

实验启动真实 Spring Boot 4.1.0 HTTP server，由 springdoc-openapi 3.0.3 生成 `/v3/api-docs`。测试比较运行中的 `getWorkOrder` 成功/Problem 响应、生成 schema/example 和只读基线摘要，再证明删除 required 会被阻断而可选扩展通过。

先预热 Maven 依赖，再运行 `./verify.sh`。固定结果为 10 个测试全绿；实验只实现一个教学切片，不修改 FactoryCare 设计契约。
