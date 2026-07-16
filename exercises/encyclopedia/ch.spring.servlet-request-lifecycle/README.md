# Servlet Filter 链练习

目标：修复 EquipmentGuardFilter，使有效的 equipmentId 恰好继续一次 FilterChain；缺失或空白值仍要返回已经提交的 400，而且不得调用目标。

先运行 ./verify.sh。初始代码应得到稳定的 expected-red 结果，哨兵是 EXPECTED_CHAIN_CONTINUATION。只修改 src/main 下的实现，不要改测试、POM 或验证器。完成后再次运行同一命令，应转为 state=completed。

思考顺序：

1. 哪个分支已经构造了完整响应并应立即 return？
2. 哪个分支尚未把控制权交给下游？
3. 为什么不能在拒绝响应写完后还调用 chain？

验证器固定要求 JDK 25、Maven 3.9.16、Jakarta Servlet 6.1，并离线执行。

## 完成标准与边界

三个测试全部通过：有效值继续一次，null 和空白值都返回 400 且不继续。练习不启动真实 Servlet 容器，也不验证 URL 映射、线程池或 Spring MVC。
