# 外部配置优先级练习

初始代码把默认值属性源排在模拟环境变量属性源之前，因此两者都提供 `factorycare.api-base-url` 时，解析器错误地返回默认端点。

先运行 `./verify.sh`。初始状态应稳定输出 `state=expected-red`，哨兵为 `EXPECTED_ENVIRONMENT_PRECEDENCE`。只修改 `src/main` 下的 `EndpointPriorityExercise.java`，不要改测试、POM 或验证器。

完成标准：

- 没有环境变量时返回默认端点；
- `FACTORYCARE_API_BASE_URL` 能映射到 `factorycare.api-base-url`；
- 环境变量与默认值同时存在时，环境变量获胜；
- `./verify.sh` 转为 `state=completed`。

修复时只调整属性源优先级，不硬编码测试端点，也不读取真实主机环境。验证器固定使用 Spring Boot 4.1.0、JDK 25、Maven 3.9.16，并以离线模式执行。
