# Spring AOP 代理观察台

工件直接使用 Spring Framework 7 `ProxyFactory`、注解切点和 `MethodInterceptor`。确定性时钟证明匹配一次、不匹配零次、返回/异常透明，以及 outer→this.inner 自调用不再次进入代理。

唯一入口 `./verify.sh` 完全离线运行；它不代表完整 Boot auto-proxy、AspectJ weaving 或生产计时开销。
