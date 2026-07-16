# 不可信数据与危险 sink 示例

这个纯 JDK 25 示例把 XSS/SSRF 防护拆成可观察的离线决策：

- 普通业务文本在 HTML text context 编码，不进入 raw HTML sink；
- 属性名来自固定安全集合，`onerror` 被拒绝；
- cross-site 状态变更缺少合成 CSRF Token 时拒绝；
- 服务器目标只允许精确 `.example.test` HTTPS origin，并检查预先给定的地址分类；
- 重定向每跳重验，连接时的地址绑定不得从 global-unicast 变成 loopback。

```bash
./verify.sh
```

程序不执行 HTML、不查询 DNS、不创建 Socket、不发 HTTP 请求。`AddressClass` 是 fake resolver 的合成结果；通过只证明决策函数，不证明生产 URL parser、DNS、代理和 egress 防火墙。
