# Bean 生命周期与作用域示例

工程使用 Spring Framework 7.0.8 的真实 ApplicationContext、BeanPostProcessor、singleton/prototype 以及 request/session scope，不启动端口。

运行 ./verify.sh 前先预测六组结果：依赖填充与初始化顺序、singleton/prototype 身份、prototype 被 singleton 捕获、prototype 销毁所有权、request 隔离和 session 复用。

Web scope 测试显式注册 Spring 官方 RequestScope/SessionScope，并绑定 MockHttpServletRequest。它证明 scope 身份，不冒充 DispatcherServlet 或真实容器集成。

验证器要求 JDK 25、Maven 3.9.16，并完全离线运行。
