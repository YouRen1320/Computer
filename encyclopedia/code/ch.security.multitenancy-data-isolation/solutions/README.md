# 租户隔离边界练习：私有参考答案

这是 `exercises/encyclopedia/ch.security.multitenancy-data-isolation` 的参考实现。它保留全部正负断言，并提供七个纯函数的最小安全实现。

```bash
./verify.sh
```

参考答案验证的是本地边界契约，不替代真实 Spring Security、MyBatis、PostgreSQL RLS、缓存集群或消息消费者的集成测试。
