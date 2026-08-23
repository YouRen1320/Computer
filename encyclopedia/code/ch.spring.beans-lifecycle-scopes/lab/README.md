# Bean scope 与线程安全实验

八个离线测试把定义、实例和所有权分开观察：生命周期顺序、per-container singleton、prototype 创建/手工释放、prototype 捕获、Web scope 注册、active request、request/session 身份，以及 singleton 丢失更新。

UnsafeCounter 用 barrier 强制两个线程读取同一旧值，因此最终 1 是确定性反例，不是碰运气压测。request/session 只用 Spring 官方 scope 与 mock request，不证明真实容器行为。

运行 ./verify.sh；要求 JDK 25、Maven 3.9.16、Spring Framework 7.0.8 和完全离线模式。
