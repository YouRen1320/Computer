# IoC、构造器注入与依赖反转：可运行示例

这个离线 Maven 工程先手工 new 出同一对象图，再交给 Spring Framework 7 的 AnnotationConfigApplicationContext 装配。AppConfig 使用 proxyBeanMethods=false；每个 @Bean 方法只创建自己的对象，依赖通过方法参数显式表达。

运行 ./verify.sh 前，先画出三节点对象图：

- WorkOrderService 指向 WorkOrderRepository；
- WorkOrderService 指向 NotificationPort；
- 两个端口都不反向依赖 WorkOrderService。

七个测试覆盖手工装配、容器 Bean 定义、构造器注入后的纯单元测试替换、TestReplacementConfig 替换通知实现，以及三种确定性启动失败：缺 Bean、同类型两个候选、构造器循环依赖。

验证器固定要求 JDK 25、Maven 3.9.16，并离线使用 Spring Framework 7.0.7。该补丁版本位于登记的 Spring Framework 7.x 版本面内，并与本地缓存一致。

## 证据边界

通过结果证明当前小对象图的装配和故障分类；不涉及 Spring Boot 自动配置、Bean 作用域、AOP、Web 容器、数据库或生产配置扫描。
