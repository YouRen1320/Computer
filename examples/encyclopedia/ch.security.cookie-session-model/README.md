# Cookie 作用域与 Session 轮换示例

这个纯 JDK 25 示例使用 `.example.test` 主机、固定时钟和显式 `SYNTHETIC` ID，演示：

- host-only、`Path=/`、`Secure`、`HttpOnly`、显式 `SameSite=Lax` 的 Cookie 策略；
- HTTPS/HTTP、精确主机、子域和 cross-site subresource 的发送矩阵；
- 登录把匿名 ID 换成新认证 ID并撤销旧 ID；
- 登出由服务端撤销；idle 到期由服务端拒绝。

```bash
./verify.sh
```

输出只包含布尔不变量，不打印合成 ID。`FACTORYCARE_SESSION` 与公共设计契约一致；这里没有 `Set-Cookie` 真实网络响应，也没有修改契约为 `__Host-` 前缀。

## 边界

模型没有实现浏览器 Cookie jar 的所有 RFC 算法、反向代理、Servlet、并发请求或多节点存储。通过仅证明示例中的属性和生命周期断言。生产 ID 应由框架/CSPRNG 生成，不能使用 `TestOnlyIdSource`。
