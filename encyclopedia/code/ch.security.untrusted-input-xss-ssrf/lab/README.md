# XSS、CSRF 与 SSRF 故障实验

实验使用合成 HTML 字符串、来源、URL 与 fake DNS 地址分类，验证跨站写入、输出 sink 和服务器出站三个独立边界。

```bash
./verify.sh
```

基线通过后重放六个命名故障：

- `CSRF_DISABLED`：缺 Token 的 cross-site 状态变更被接受；
- `RAW_HTML`：普通文本直接进入 raw HTML sink；
- `EVENT_ATTRIBUTE`：允许 `onerror` 属性；
- `LOOPBACK_ALLOWED`：允许 loopback 目标；
- `REDIRECT_UNCHECKED`：只检查重定向第一跳；
- `DNS_REBINDING`：验证与连接地址分类改变仍放行。

每个故障必须非零退出并命中稳定 marker。程序不会打开浏览器、解析 DNS 或建立网络连接；fault branch 只用于证明预言有效。
