# Servlet Filter 链练习
+
## 同一验证入口的状态合同

只修改 README 指定的 `src/main` 可编辑 starter，测试、POM 与验证器保持不变，然后每次都运行 `./verify.sh`。

- `0` + `EXERCISE_GREEN`：登记的测试数量全部通过，状态为 `completed`；
- `41` + `EXPECTED_RED`：测试数量、唯一失败数和本章 sentinel 精确匹配公开 starter；
- `43`：编译、依赖、测试数量、失败形状或工具环境不在上述两种已知状态，必须先读日志诊断。

离线绿灯只覆盖本练习登记的合同；涉及 PostgreSQL/Testcontainers 的章节仍需正文或 lab 明示的真实环境证据。

目标：修复 EquipmentGuardFilter，使有效的 equipmentId 恰好继续一次 FilterChain；缺失或空白值仍要返回已经提交的 400，而且不得调用目标。

先运行 ./verify.sh。初始代码应得到稳定的 expected-red 结果，哨兵是 EXPECTED_CHAIN_CONTINUATION。只修改 src/main 下的实现，不要改测试、POM 或验证器。完成后再次运行同一命令，应转为 state=completed。

思考顺序：

1. 哪个分支已经构造了完整响应并应立即 return？
2. 哪个分支尚未把控制权交给下游？
3. 为什么不能在拒绝响应写完后还调用 chain？

验证器固定要求 JDK 25、Maven 3.9.16、Jakarta Servlet 6.1，并离线执行。

## 完成标准与边界

三个测试全部通过：有效值继续一次，null 和空白值都返回 400 且不继续。练习不启动真实 Servlet 容器，也不验证 URL 映射、线程池或 Spring MVC。
