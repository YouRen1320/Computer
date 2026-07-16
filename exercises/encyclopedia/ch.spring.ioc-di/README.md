# 构造器注入与可替换依赖练习

初始 WorkOrderService 会在类内部创建具体仓库和通知器。业务结果看似正确，但对象图被藏在服务内部：调用者无法知道它需要什么，测试也无法替换两个出站端口。

先运行 ./verify.sh。初始状态应稳定输出 expected-red，哨兵是 EXPECTED_EXPLICIT_CONSTRUCTOR_GRAPH。只修改 src/main 下的 WorkOrderExercise，不要改测试、POM 或验证器。

完成标准：

- WorkOrderService 的唯一构造器显式接收 WorkOrderRepository 与 NotificationPort；
- 两个依赖保存在对应接口类型的 final 字段中；
- open 真正调用传入的两个对象，而不是内部新建替代品；
- 空白校验与 opened: 前缀保持不变；
- ./verify.sh 转为 state=completed。

这道题不要求启动 Spring 容器。构造器注入首先是普通 Java 的对象设计；容器只是读取同一个依赖图并替调用者装配。

验证器固定使用 JDK 25、Maven 3.9.16、Spring Framework 7.0.7，并以离线模式执行。
