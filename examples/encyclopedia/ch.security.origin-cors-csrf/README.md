# Origin、CORS 与 CSRF 离线示例

这个纯 JDK 25 模型用 `.example.test` 合成来源和固定 Session/Token 元数据构造请求—响应矩阵，不启动 HTTP 服务：

- origin 由 scheme、host、port 三元组精确比较；
- CORS 只给精确允许来源返回授权响应头，预检 `OPTIONS` 不依赖 Session Cookie；
- 携带 Cookie 的跨源响应使用精确 `Access-Control-Allow-Origin`、`Access-Control-Allow-Credentials: true` 与 `Vary: Origin`；
- 状态变更同时要求有效 Session、受信来源和 CSRF Token；
- cross-site 表单、缺 Token 请求以及“通配来源 + 凭据”配置均被拒绝；
- `GET` 只读且不产生副作用。

```bash
./verify.sh
```

输出只包含状态码和布尔不变量，不打印合成 Cookie/Token。这里的响应对象只是离线数据结构，不代表浏览器、代理或 Spring Security 的完整实现。
