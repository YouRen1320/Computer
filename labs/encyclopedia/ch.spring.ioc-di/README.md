# IoC 依赖图与启动故障实验

本实验把对象图当成可检查的数据，而不是“Spring 自动帮我 new”。先画出 WorkOrderService 的两个出边，再运行 ./verify.sh：

1. 用反射检查唯一构造器的参数与 final 字段；
2. 不启动容器，用两个小替身完成纯单元测试；
3. 启动 AnnotationConfigApplicationContext 做装配烟雾测试；
4. 从 BeanFactory 读取两个协作者边；由 @Bean 工厂方法创建时，容器还会报告配置对象这个调用所有者；
5. 分别观察缺 Bean、同类型歧义和构造器循环的根因类型；
6. 对比字段注入对象被手工 new 与被容器管理时的差异。

FieldInjectedService 是故意保留的反例。它在容器内“能运行”，但零参数构造器没有公开必需依赖，手工 new 后会稳定触发 NullPointerException；这正是构造器注入改善可理解性与可测试性的理由。

验证器固定使用 JDK 25、Maven 3.9.16、Spring Framework 7.0.7，并以离线模式执行。

## 证据边界

实验只证明当前显式配置的对象图与错误分类，不讨论 Bean 作用域、自动配置、组件扫描、AOP 或循环依赖规避技巧。循环的正确改法通常是重新划分职责，而不是隐藏图上的环。
