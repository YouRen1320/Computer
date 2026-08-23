# 外部配置优先级练习
+
## 同一验证入口的状态合同

只修改 README 指定的 `src/main` 可编辑 starter，测试、POM 与验证器保持不变，然后每次都运行 `./verify.sh`。

- `0` + `EXERCISE_GREEN`：登记的测试数量全部通过，状态为 `completed`；
- `41` + `EXPECTED_RED`：测试数量、唯一失败数和本章 sentinel 精确匹配公开 starter；
- `43`：编译、依赖、测试数量、失败形状或工具环境不在上述两种已知状态，必须先读日志诊断。

离线绿灯只覆盖本练习登记的合同；涉及 PostgreSQL/Testcontainers 的章节仍需正文或 lab 明示的真实环境证据。

初始代码把默认值属性源排在模拟环境变量属性源之前，因此两者都提供 `factorycare.api-base-url` 时，解析器错误地返回默认端点。

先运行 `./verify.sh`。初始状态应稳定输出 `state=expected-red`，哨兵为 `EXPECTED_ENVIRONMENT_PRECEDENCE`。只修改 `src/main` 下的 `EndpointPriorityExercise.java`，不要改测试、POM 或验证器。

完成标准：

- 没有环境变量时返回默认端点；
- canonical 环境变量 `FACTORYCARE_APIBASEURL` 能映射到 `factorycare.api-base-url`；
- `FACTORYCARE_API_BASE_URL` 只作为当前 Boot relaxed-binding alias 单独验证，不能写成 canonical 合同；
- 未登记的 `FACTORYCARE_API_ENDPOINT` 不能覆盖默认值；
- 环境变量与默认值同时存在时，环境变量获胜；
- `./verify.sh` 转为 `state=completed`。

修复时只调整属性源优先级，不硬编码测试端点，也不读取真实主机环境。验证器固定使用 Spring Boot 4.1.0、JDK 25、Maven 3.9.16，并以离线模式执行。
